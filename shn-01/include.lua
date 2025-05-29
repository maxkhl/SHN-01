

local function dirname(path)
    return path:match("^(.*)/") or "."
end

-- Loads a lua file, executes it and returns the result (works with relative paths)
function include(relativePath, origin, env)
    origin = origin or baseDir

    local code, fullPath = file.readRelative(relativePath, origin)

    -- Setup env.include for nested scripts to use current directory
    local newOrigin = dirname(fullPath)

    if not env then
        local localEnv = {}
        localEnv.baseDir = newOrigin

        localEnv.include = function(relativePathSub)
            return include(relativePathSub, env.baseDir)
        end
        localEnv.getAbsolutePath = function(relativePathSub, originSub)
            local originSub = originSub or env.baseDir
            return getAbsolutePath(relativePathSub, originSub)
        end

        localEnv.new = function(path, ...)
            return new(getAbsolutePath(path, env.baseDir), ...)
        end
        localEnv.class = function(path)
            return class(getAbsolutePath(path, env.baseDir))
        end
        localEnv.require = function(path)
            return require(getAbsolutePath(path, env.baseDir))
        end

        env = setmetatable(localEnv, { __index = _G })
    end

    --print("Including " .. fullPath .. " - " .. code)
    local chunk, err = load(tostring(code), "=" .. fullPath, nil, env)
    if not chunk then
        error("Failed to compile " .. fullPath .. ": " .. tostring(err))
    end
    return chunk()
end

-- Buffer containing required lua files results
requireBuffer = {}

-- Loads a lua file, executes it exactly once and returns the result (watch out for nested requires)
function require(path)
    if not path then error("No path given") return end
    local extension = file.getExtension(path)
    if extension and extension ~= "lua" then
        error("Invalid script path: " .. path .. ", expected .lua")
    elseif not extension then
        path = path .. ".lua"
    end
    if not baseDir then
        error("No base directory set")
    end

    local fullPath = getAbsolutePath(path, baseDir)
    if requireBuffer[fullPath] then
        return requireBuffer[fullPath]
    end
    
    local result = include(path)
    if fullPath then
        requireBuffer[fullPath] = result
    end
    return result
end

function requireFree(path)
    if not path then error("No path given") return end
    local fullPath = getAbsoluteFilePath(path, baseDir)
    if requireBuffer[fullPath] then
        requireBuffer[fullPath] = nil
        return true
    end
    return false
end