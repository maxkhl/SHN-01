-- Server-side debug sequence function
-- This function is called to create the coroutine for handling debug messages
return function(hive, protocol)
    return function(node, data)
        -- Server-side debug sequence logic
        -- Message format: "debug", command (INFO/WARN), message_text
        local command = string.upper(data[1] or "")
        local debugMessage = data[2] or ""
                
        local nodePrefix = node and node.shortName and ("<c=0xFFFFFF>[" .. node.shortName .. "]</c>") or ""
        
        if command == "INFO" or string.upper(tostring(command)) == "INFO" then
            print(nodePrefix .. "<c=0x00FF00>[INFO]</c> " .. tostring(debugMessage))
        elseif command == "WARN" or string.upper(tostring(command)) == "WARN" then
            print(nodePrefix .. "<c=0xFFFF00>[WARN]</c> " .. tostring(debugMessage))
        elseif command == "ERROR" or string.upper(tostring(command)) == "ERROR" then
            print(nodePrefix .. "<c=0xFF0000>[ERROR]</c> " .. tostring(debugMessage))
        else
            print(nodePrefix .. "<c=0xFFFF00>[DEBUG]</c> " .. tostring(command) .. " " .. tostring(debugMessage))
        end
        
        -- No response needed for debug messages
        return {}
    end
end
