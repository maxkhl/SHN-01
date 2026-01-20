-- Client-side bounce sequence function
-- This function is called to create the coroutine for handling bounce messages
return function()
    return function(message)
        -- Client-side bounce logic
        -- Message format: "HEARTBEAT_ACK", nodeId or "RELAY_MSG", sourceNodeId, relayMessage
        local command = message.data[1]
        
        if command == "HEARTBEAT_ACK" then
            -- Heartbeat acknowledged by server
            -- Optional: track last heartbeat time
            
        elseif command == "RELAY_MSG" then
            -- Received relayed message from another node
            local sourceNodeId = message.data[2]
            local relayMessage = message.data[3]
            
            print("Relay message from " .. tostring(sourceNodeId) .. ": " .. tostring(relayMessage))
            
            -- Process relayed message (application-specific handling)
            -- This is where node-to-node communication logic would go
        end
    end
end

-- Helper function to send heartbeat (called periodically from main loop)
function sendHeartbeat()
    if hive.address and not bootstrap then
        mdm.send(hive.address, 2022, "bounce", "HEARTBEAT", node.id)
    end
end

-- Helper function to relay message to another node
function relayToNode(targetNodeId, message)
    if hive.address and not bootstrap then
        mdm.send(hive.address, 2022, "bounce", "RELAY", targetNodeId, message, node.id)
    end
end

