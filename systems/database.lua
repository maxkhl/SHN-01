local database = {}

database.buffer = {}
database.baseFolder = "/systems/database/"
local util = require("/systems/minify/util.lua")

function database:setKey(application, key, value, doSave)
    doSave = doSave or false

    if type(application) ~= "string" or type(key) ~= "string" then
        error("Invalid arguments: application and key must be strings (" .. application .. " " .. key .. ")")
        return false
    end
    if value ~= nil and type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" and type(value) ~= "table" then
        error("Invalid value type: must be nil, string, number, boolean or table (" .. application .. " " .. key .. ")")
        return false
    end

    if not self.buffer[application] then
        self.buffer[application] = {}
    end
    
    self.buffer[application][key] = value

    -- Delete application if no keys are left
    if next(self.buffer[application]) == nil then
        self.buffer[application] = nil
    end
    
    if doSave then
        return database:save(application)
    end
    return true
end

function database:save(application)
    local fs = fileSystem()

    if not fs.exists(database.baseFolder) then
        fs.makeDirectory(database.baseFolder)
    end
    if not fs.isDirectory(database.baseFolder) then
        print("Base folder is not a directory")
        return false
    end
    if not self.buffer[application] and fs.exists(self:GetApplicationPath(application)) then
        fs.remove(self:GetApplicationPath(application))
        return true
    end

    local file, error = fs.open(self:GetApplicationPath(application), "w")
    if not file then
        print("Failed to open file: " .. error)
        return false
    end

    for key, value in pairs(self.buffer[application]) do
        local vtype = type(value)
        local outVal = nil
        if vtype == "table" then
            outVal = util.PrintTable(value)
        else
            outVal = tostring(value)
        end
        local data = string.format("%s:%s=%s␞", key, vtype, outVal)
        fs.write(file, data)
    end

    fs.close(file)
    return true
end

function database:getKey(application, key)
    if not self.buffer[application] then
        self.buffer[application] = {}
    end

    if not self.buffer[application][key] then
        if database:load(application) then
            if self.buffer[application][key] == nil then
                return nil
            end
            return self.buffer[application][key]
        else
            return nil
        end
    end

    return self.buffer[application][key]
end

function database:loadOnce(application)
    if not self.buffer[application] then
        if not database:load(application) then
            return false
        end
    end
    return true
end

function database:load(application)
    local fs = fileSystem()
    local path = self:GetApplicationPath(application)

    if not fs.exists(path) then
        return false
    end

    local file, err = fs.open(path, "r")
    if not file then
        print("Failed to open file: " .. err)
        return false
    end

    self.buffer[application] = {}
    local buffer = ""

    while true do
        local chunk = fs.read(file, 64)
        if not chunk then break end

        buffer = buffer .. chunk

        while true do
            local sepIndex = buffer:find("␞", 1, true)
            if not sepIndex then break end

            local entry = buffer:sub(1, sepIndex - 1)
            buffer = buffer:sub(sepIndex + 3) -- skip 3 bytes for UTF-8 ␞
            
            local key, vtype, value = entry:match("^(.-):(%a+)=(.*)$")
            if key and vtype and value then
                if vtype == "number" then
                    value = tonumber(value)
                elseif vtype == "boolean" then
                    value = value == "true"
                elseif vtype == "table" then
                    local fn, err = load("return " .. value)
                    if fn then
                        local ok, res = pcall(fn)
                        if ok and type(res) == "table" then
                            value = res
                        else
                            value = nil
                        end
                    else
                        value = nil
                    end
                end
                self.buffer[application][key] = value
            end
        end
    end

    fs.close(file)
    return true
end

function database:GetApplicationPath(application)
    return database.baseFolder .. string.lower(application) .. ".dat"
end

return database