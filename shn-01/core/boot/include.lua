--[[#####################INCLUDE/INJECT#####################]]
-- Loads a lua file, executes it and returns the result (works with relative paths)
function include(relativePath, origin, env, errorDepth)
    origin = origin or baseDir


    local code, fullPath = file.read(relativePath, origin, (errorDepth or 0) + 1)
    local newOrigin = fullPath:match("^(.*)/") or "."

    if not env then      
        env = setmetatable({}, { __index = _G })
    end

    local injected = ([[
    local baseDir, include, inject, new, class, require, getAbsolutePath = ...
    %s
    ]]):format(code)


    local chunk, err = load(injected, "=" .. fullPath, nil, env)
    if not chunk then
        error("Failed to compile " .. fullPath .. ": " .. tostring(err))
    end

    if chunk then
        return chunk( 
            newOrigin,
            function(path) return include(path, newOrigin, env) end,
            function(path) return inject(path, newOrigin) end,
            function(path, ...) return new(getAbsolutePath(path, newOrigin), ...) end,
            function(path) return class(getAbsolutePath(path, newOrigin)) end,
            function(path) return require(getAbsolutePath(path, newOrigin)) end,
            function(path, originSub) return getAbsolutePath(path, originSub or newOrigin) end
        )
    end
end

-- Injects a lua file in the local environment
function inject(relativePath, origin)
  include(relativePath, origin, _G)
end