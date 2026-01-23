-- Server-side heartbeat sequence function
-- This function is called to create the coroutine for handling heartbeat messages
return function(hive, protocol)
    return function(node, data)
        -- Server-side heartbeat logic - runs in continuous loop
        -- Get node ID from the connected node object        
        local nodeId = node.id
        local nodeShortName = node.shortName
        
        debugPrint("Heartbeat session started", node)
        
        local heartbeatCount = 0
        
        -- Continuous heartbeat loop
        while true do
            heartbeatCount = heartbeatCount + 1
            
            -- Check if node still connected
            if hive.nodes[node.address] then

                local oldLastSeen = node.lastSeen
                node:updateHeartbeat()
                
                debugPrint("Heartbeat <c=0xFFFFFF>#" .. heartbeatCount .. "</c> (lastSeen: <c=0xFFFFFF>" .. string.format("%.1f", oldLastSeen) .. "</c> -> <c=0xFFFFFF>" .. string.format("%.1f", node.lastSeen) .. "</c>)", node)
                
                -- Send heartbeat acknowledgment
                local ackResponse = class("../../messages/outbound"):new(
                    node,
                    protocol,
                    nil,
                    true,
                    "HEARTBEAT_ACK"
                )
                
                -- Return responses and wait for next heartbeat message
                node, data = coroutine.yield({ackResponse})
            else
                debugPrint("Heartbeat session ended (disconnected after <c=0xFFFFFF>" .. heartbeatCount .. "</c> heartbeats)", {shortName = nodeShortName})
                return {}
            end
        end
    end
end
