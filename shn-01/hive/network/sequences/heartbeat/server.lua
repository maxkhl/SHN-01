-- Server-side heartbeat sequence function
-- This function is called to create the coroutine for handling heartbeat messages
return function(hive, protocol)
    return function(message)
        -- Server-side heartbeat logic - runs in continuous loop
        -- Get node ID from the connected node object
        local nodeAddress = message.remoteAddress
        local node = hive.nodes[nodeAddress]
        
        if not node then
            debugPrint("Heartbeat received from unconnected address <c=0x888888>" .. tostring(nodeAddress) .. "</c>")
            return {}
        end
        
        local nodeId = node.id
        
        debugPrint("Heartbeat session started for node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c>")
        
        local heartbeatCount = 0
        
        -- Continuous heartbeat loop
        while true do
            heartbeatCount = heartbeatCount + 1
            
            -- Update last seen timestamp
            local node = hive.nodes[nodeAddress]
            if node then
                local oldLastSeen = node.lastSeen
                node:updateHeartbeat()
                
                debugPrint("Heartbeat <c=0xFFFFFF>#" .. heartbeatCount .. "</c> from <c=0xFFFFFF>" .. nodeId .. "</c> (lastSeen: <c=0xFFFFFF>" .. string.format("%.1f", oldLastSeen) .. "</c> -> <c=0xFFFFFF>" .. string.format("%.1f", node.lastSeen) .. "</c>)")
                
                -- Send heartbeat acknowledgment
                local response = class("../../messages/outbound"):new(
                    node,
                    protocol,
                    message.distance,
                    "HEARTBEAT_ACK",
                    nodeId
                )
                
                -- Return responses and wait for next heartbeat message
                message = coroutine.yield({response})
                
                -- Check if node still connected
                if not hive.nodes[nodeAddress] then
                    debugPrint("Heartbeat session ended for node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> (disconnected after <c=0xFFFFFF>" .. heartbeatCount .. "</c> heartbeats)")
                    return {}
                end
            else
                -- Node was removed, end session
                debugPrint("Heartbeat session ended for node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> (not found after <c=0xFFFFFF>" .. heartbeatCount .. "</c> heartbeats)")
                return {}
            end
        end
    end
end
