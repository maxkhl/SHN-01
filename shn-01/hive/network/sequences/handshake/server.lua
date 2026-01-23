-- Server-side handshake sequence function
-- This function is called to create the coroutine for handling handshake messages
return function(hive, protocol)
    return function(node, data)
        -- Server-side handshake logic
        -- Message format: "handshake", nodeId, hiveId
        local nodeId = data[1]
        local receivedHiveId = data[2]
        
        
        node:authorize()
        
        -- Return handshake_ack and initiate Stage 2 transfer
        local ackResponse = class("../../messages/outbound"):new(
            node,
            protocol,
            nil,
            true,
            "handshake_ack",
            node.id,
            getHiveId()
        )
        node, data = coroutine.yield({ackResponse})

        if data[1] == "STAGE2_REQUEST" then
            debugPrint("Client requested Stage 2 transfer", node)
            hive.protocols["FILE"].sequences["TRANSMIT"]:createSession(node, {"TRANSMIT_START", "/shn-01/data/clientStage2.lua"})
        else
            debugPrint("Unexpected response after handshake: " .. tostring(data[1]), node)
        end

        
        return 
    end
end
