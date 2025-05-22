
-- Normalizes path by resolving "." and ".."
local function normalizePath(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    return "/" .. table.concat(parts, "/")
end

-- Returns the absolute file path of a given relative path
function getAbsoluteFilePath(relativePath, origin)
    if relativePath:sub(1, 1) == "/" then
        return normalizePath(relativePath)
    end
    return normalizePath(origin .. "/" .. relativePath)
end

-- Reads a file and returns its content
local function readFileRelative(relativePath, origin)
    if not relativePath then error("No file path given") return end
    local fileSystem = fileSystem()
    local path = getAbsoluteFilePath(relativePath, origin)
    local stream, reason = fileSystem.open(path, "r")
    if not stream then error("Failed to open " .. path .. ": " .. tostring(reason)) end

    local chunks = {}
    local newChunk = fileSystem.read(stream, 4096)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, 4096)
    end
    fileSystem:close(stream)
    return table.concat(chunks), path
end

local function dirname(path)
    return path:match("^(.*)/") or "."
end

-- Loads a lua file, executes it and returns the result (works with relative paths)
function include(relativePath, origin)
    origin = origin or baseDir
    local env = setmetatable({}, { __index = _G })

    local code, fullPath = readFileRelative(relativePath, origin)

    -- Setup env.include for nested scripts to use current directory
    local newOrigin = dirname(fullPath)
    env.baseDir = newOrigin

    env.include = function(relativePathSub)
        include(relativePathSub, env.baseDir)
    end

    local chunk, err = load(tostring(code), "=" .. fullPath, nil, env)
    if not chunk then
        error("Failed to compile " .. fullPath .. ": " .. tostring(err))
    end

    return chunk()
end

-- Buffer containing required lua files results
requireBuffer = {}

-- Loads a lua file, executes it exactly once and returns the result (watch out for nested requires)
function require(path, test)
    local fullPath = getAbsoluteFilePath(path, baseDir)
    if requireBuffer[fullPath] then
        return requireBuffer[fullPath]
    end
    
    local result = include(path)
    if fullPath then
        requireBuffer[fullPath] = result
    end
    return result
end

-- Contains all loaded classes
classBuffer = {}

-- Creates a new instance of the given class lua file (needs to return a table with a new function)
function new(path, ...)
    local fullPath = getAbsoluteFilePath(path, baseDir)
    if classBuffer[fullPath] and classBuffer[fullPath].new then
        return classBuffer[fullPath].new(...)
    end

    local result = include(path)

    classBuffer[fullPath] = result
    if result and result.new then
      return result.new(...)
    else
      return nil
    end
end