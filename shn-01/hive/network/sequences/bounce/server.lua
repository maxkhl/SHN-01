-- Server-side bounce sequence function
-- This function is called to create the coroutine for handling bounce messages
return function(hive, protocol)
    return function(message)
        -- Server-side bounce logic
        -- Message format: "HEARTBEAT", nodeId or "RELAY", targetNodeId, relayMessage
        local command = message.data[2]
        
        if command == "HEARTBEAT" then
            -- Update last seen timestamp for heartbeat tracking
            local nodeId = message.data[3]
            
            local node = hive.nodes[message.remoteAddress]
            if node then
                node.lastSeen = computer.uptime()
                -- Echo heartbeat back
                local response = class("../../messages/outbound"):new(
                    node,
                    protocol,
                    message.distance,
                    false,
                    "HEARTBEAT_ACK",
                    nodeId
                )
                return {response}
            end
            
        elseif command == "RELAY" then
            -- Relay message to another node
            local targetNodeId = message.data[3]
            local relayMessage = message.data[4]
            local sourceNodeId = message.data[5]
            
            print("Relay request from " .. tostring(sourceNodeId) .. " to " .. tostring(targetNodeId))
            
            -- Find target node address by iterating connected nodes
            local targetNode = nil
            for address, nodeData in pairs(hive.nodes) do
                if nodeData.id == targetNodeId then
                    targetNode = nodeData
                    break
                end
            end
            
            if targetNode then
                -- Forward message to target node
                local response = class("messages/outbound"):new(
                    targetNode,
                    protocol,
                    message.distance,
                    false,
                    "RELAY_MSG",
                    sourceNodeId,
                    relayMessage
                )
                print("  Relaying to " .. targetNode.address)
                return {response}
            else
                print("  Target node not connected: " .. tostring(targetNodeId))
            end
        end
        
        return {}
    end
end
