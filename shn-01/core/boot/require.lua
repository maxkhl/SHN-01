
--[[#####################REQUIRE#####################]]--
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
    
    local result = include(path, nil, nil, 1)
    if fullPath then
        requireBuffer[fullPath] = result
    end
    return result
end

-- frees a required path
function requireFree(path)
    if not path then error("No path given") return end
    local fullPath = getAbsoluteFilePath(path, baseDir)
    if requireBuffer[fullPath] then
        requireBuffer[fullPath] = nil
        return true
    end
    return false
end