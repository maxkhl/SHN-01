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

    local result = include(path, nil, nil, 1)

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