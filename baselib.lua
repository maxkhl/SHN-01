--[[#####################BASELIB#####################]]--
-- Base library providing include, inject, class, new, require and file handling functionalities

--[[#####################INCLUDE/INJECT#####################]]
-- Loads a lua file, executes it and returns the result (works with relative paths)
function include(relativePath, origin, env)
    origin = origin or baseDir


    local code, fullPath = file.read(relativePath, origin)

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

--[[#####################FILE#####################]]--
file = {}

-- Returns the file system the os is running on
function fileSystem()
    return component.proxy(computer.getBootAddress())
end

-- Reads a file and returns its content
function file.read(relativePath, origin)
    if not relativePath then error("No file path given") return end
    local fileSystem = fileSystem()
    local path = getAbsolutePath(relativePath, origin)
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

-- Normalizes path by resolving "." and ".."
function file.normalizePath(path)
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

-- Joins two paths (base + relative) and returns a normalized absolute path
function file.joinPath(basePath, relativePath)
    assert(relativePath, "No relative path given to joinPath")
    -- If the relativePath is already absolute, just normalize and return it
    if relativePath:sub(1,1) == "/" then
        return file.normalizePath(relativePath)
    end

    basePath = basePath or ""
    -- Ensure basePath ends with a slash if it's non-empty and doesn't already
    if basePath:sub(-1) ~= "/" and basePath ~= "" then
        basePath = basePath .. "/"
    end

    return file.normalizePath(basePath .. relativePath)
end

-- Returns the absolute file path of a given relative path
function getAbsolutePath(relativePath, origin)
    assert(relativePath, "No relative path given (origin: " .. tostring(origin) .. ")")
    assert(type(relativePath) == "string", "Invalid relative path, expected string but got " .. type(relativePath) .. " (origin: " .. tostring(origin) .. ")")
    origin = origin or baseDir
    if relativePath:sub(1, 1) == "/" then
        return file.normalizePath(relativePath)
    end
    return file.normalizePath(origin .. "/" .. relativePath)
end

-- Reads a file and returns its content as a table of lines
function file.readLines(absolutePath)
    if not absolutePath then error("No file path given") end
    local fileSystem = fileSystem()
    local stream, reason = fileSystem.open(absolutePath, "r")
    if not stream then error("Failed to open " .. absolutePath .. ": " .. tostring(reason)) end

    local chunks = {}
    local newChunk = fileSystem.read(stream, 4096)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, 4096)
    end
    fileSystem:close(stream)

    local content = table.concat(chunks)
    local lines = {}

    -- Split by line breaks (handles both \n and \r\n)
    for line in content:gmatch("([^\r\n]+)") do
        table.insert(lines, line)
    end

    return lines
end

-- Returns a files extension
function file.getExtension(path)
    local name = path:match("([^/\\]+)$")  -- Get the filename only (handles Unix and Windows separators)
    if name:match("^%.[^%.]*$") then return nil end  -- Ignore hidden files like `.bashrc`
    return name:match("^.+%.([^.]+)$")
end

-- Returns a directory path from a given file path
function file.getDir(path)
  -- Extract directory from a path
  return path:match("^(.*[\\/])") or ""
end


-- Reads a file and expands any include calls recursively
-- @param path: file path to read
-- @param minify: optional minification function
-- @param wrap: if false, returns raw code without function wrapper (for EEPROM code)
-- @param seen: internal parameter for circular include detection
-- @param sub: internal parameter to track if this is a sub-include
function file.readWithIncludesMinified(path, minify, wrap, seen, sub)
  seen = seen or {}
  if wrap == nil then wrap = false end  -- Default to wrapping for backward compatibility

  path = file.normalizePath(path)
  if seen[path] then
    error("Circular include detected: " .. path)
  end
  seen[path] = true

  local baseDir = file.getDir(path)
  local source = file.read(path)
  if not source then
    error("Could not read file: " .. path)
  end

  local localBuffer = {}

  for line in source:gmatch("[^\r\n]+") do
    -- Check if this is a standalone include line
    local standaloneInclude = line:match('^%s*include%s*%(?%s*["\']([^"\']+)["\']%s*%)?%s*$')
    if standaloneInclude then
      -- Replace entire line with included content
      local resolved = file.joinPath(baseDir, standaloneInclude)
      local includedContent = file.readWithIncludesMinified(resolved, minify, false, seen, true)
      table.insert(localBuffer, includedContent)
    else
      -- Check for inline include() calls like: var = include("file")
      local includePath = line:match('include%s*%(%s*["\']([^"\']+)["\']%s*%)')
      if includePath then
        -- Read the file first (outside pattern matching to avoid yield issues)
        local resolved = file.joinPath(baseDir, includePath)
        local includedContent = file.readWithIncludesMinified(resolved, minify, false, seen, true)
        -- Find the include statement and replace it with IIFE
        local includePattern = 'include%s*%(%s*["\']' .. includePath:gsub('[%-%.]', '%%%1') .. '["\']%s*%)'
        local startPos, endPos = line:find(includePattern)
        if startPos then
          local modifiedLine = line:sub(1, startPos - 1) .. "(function() " .. includedContent .. " end)()" .. line:sub(endPos + 1)
          table.insert(localBuffer, modifiedLine)
        else
          table.insert(localBuffer, line)
        end
      else
        table.insert(localBuffer, line)
      end
    end
  end

  if not sub then
    local combined = table.concat(localBuffer, "\n")
    local sizeuncompressed = #combined
    local minified = minify and minify(combined) or combined
    if wrap then
      return "return (function()\n" .. minified .. "\nend)()", sizeuncompressed
    else
      return minified, sizeuncompressed
    end
  else
    return table.concat(localBuffer, "\n")
  end

  -- Wrap this file in a return (function() ... end)() expression
end

--[[#####################OBJECT ORIENTATION#####################]]--
-- Object oriented programming in Lua
function newClass(base)
    local cls = {}
    cls.__index = cls

    function cls:new(...)
        local instance = setmetatable({}, {
            __index = cls,
            __tostring = function(self)
                if type(self.__tostring) == "function" then
                    return self:__tostring()
                else
                    return "<" .. tostring(cls) .. " instance>"
                end
            end
        })
        if instance.constructor then
            instance:constructor(...)
        end
        return instance
    end

    if base then
        setmetatable(cls, { __index = base })
        cls.base = base
    end

    return cls
end

-- Checks if an object is an instance of a given class (supports inheritance)
function isInstanceOf(obj, classRef)
    if type(obj) ~= "table" then return false end
    local mt = getmetatable(obj)
    if not mt or type(mt.__index) ~= "table" then return false end
    local cls = mt.__index
    while cls do
        if cls == classRef then return true end
        cls = cls.base
    end
    return false
end

-- Contains all loaded classes
classBuffer = {}


-- Creates a new instance of the given class lua file (needs to return a table with a new function)
function new(path, ...)
    if not path then error("No class path given") return end
    local extension = file.getExtension(path)
    if extension and extension ~= "class" then
        error("Invalid class path: " .. path .. ", expected .class")
        return
    elseif not extension then
        path = path .. ".class"
    end
    if not baseDir then
        error("No base directory set")
        return
    end

    local fullPath = getAbsolutePath(path, baseDir)
    if classBuffer[fullPath] and classBuffer[fullPath].new then
        return classBuffer[fullPath]:new(...)
    end

    local result = include(path)

    classBuffer[fullPath] = result

    if not result then
        error("Failed to load class " .. path)
        return
    end
    if not result.new then
        error("Class " .. path .. " does not have a new function")
        return
    end

    return result:new(...)
end


classBuffer = {}

-- Returns the given class 
function class(path)
    if not path then error("No class path given") return end

    local extension = file.getExtension(path)
    if extension and extension ~= "class" then
        error("Invalid class path: " .. path .. " extension " .. extension .. ", expected .class")
    elseif not extension then
        path = path .. ".class"
    end    
    if not baseDir then
        error("No base directory set")
    end
    local fullPath = getAbsolutePath(path, baseDir)
    if classBuffer[fullPath] then
        return classBuffer[fullPath]
    else
        local result = include(path)
        if not result then
            error("Failed to load class " .. path)
            return
        end
        if not result.new then
            error("Class " .. path .. " does not have a new function")
            return
        end
        classBuffer[fullPath] = result
        return result
    end
end

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
    
    local result = include(path)
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