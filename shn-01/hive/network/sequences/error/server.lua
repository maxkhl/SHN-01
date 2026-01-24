-- Server-side error sequence function
-- This function is called to create the coroutine for handling error messages
return function(hive, protocol)
    return function(message)
        -- Server-side error sequence logic
        -- Message format: "error", errorMessage, stackTrace
        local errorMessage = message.data[2] or "Unknown error"
        local stackTrace = message.data[3] or ""
        
        -- Get node ID if available
        local nodeId = "unknown"
        local node = hive.nodes[message.remoteAddress]
        if node then
            nodeId = node.id
        end
        
        -- Log error to console with node ID prefix
        local nodePrefix = node and ("<c=0xFFFFFF>[" .. node.shortName .. "]</c>") or ""
        print(nodePrefix .. "<c=0xFF0000>[ERROR]</c> " .. tostring(errorMessage))
        if stackTrace and stackTrace ~= "" then
            print("<c=0xFF0000>[STACK]</c> " .. tostring(stackTrace))
        end
        
        -- Update lastError in database if node is known
        if node then
            -- Save error to database
            local nodes = database:getKey("shn01", "nodes") or {}
            
            for i, dbNode in ipairs(nodes) do
                if dbNode.id == nodeId then
                    nodes[i].lastError = errorMessage
                    database:setKey("shn01", "nodes", nodes, true)
                    break
                end
            end
        end
        
        -- No response needed for error messages
        return {}
    end
end
