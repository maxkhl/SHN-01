-- Server-side debug sequence function
-- This function is called to create the coroutine for handling debug messages
return function(hive, protocol)
    return function(message)
        -- Server-side debug sequence logic
        -- Message format: "debug", command (INFO/WARN), message_text
        local command = message.data[2]
        local debugMessage = message.data[3] or ""
        
        -- Get node ID if available
        local nodeId = "unknown"
        if hive.nodes[message.remoteAddress] then
            nodeId = hive.nodes[message.remoteAddress].id
        end
        
        if command == "INFO" or string.upper(tostring(command)) == "INFO" then
            print("<c=0x00FF00>[INFO]</c> <c=0xFFFF00>[" .. nodeId .. "]</c> " .. tostring(debugMessage))
        elseif command == "WARN" or string.upper(tostring(command)) == "WARN" then
            print("<c=0xFFFF00>[WARN]</c> <c=0xFFFF00>[" .. nodeId .. "]</c> " .. tostring(debugMessage))
        elseif command == "ERROR" or string.upper(tostring(command)) == "ERROR" then
            error("<c=0xFF0000>[ERROR]</c> <c=0xFFFF00>[" .. nodeId .. "]</c> " .. tostring(debugMessage))
        else
            print("<c=0xFFFF00>[DEBUG]</c> <c=0xFFFF00>[" .. nodeId .. "]</c> " .. tostring(command) .. " " .. tostring(debugMessage))
        end
        
        -- No response needed for debug messages
        return {}
    end
end
