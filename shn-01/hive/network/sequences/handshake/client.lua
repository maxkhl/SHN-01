-- Client-side handshake sequence function
-- This function is called to create the coroutine for handling handshake messages
return function()
    return function(message)
        -- Client-side handshake logic
        -- This code will run on the node after receiving handshake_ack
        -- Message format: "handshake_ack", nodeId, hiveId
        local command = message.data[1]
        local nodeId = message.data[2]
        local receivedHiveId = message.data[3]
        
        if command == "handshake_ack" and nodeId == node.id and receivedHiveId == hive.id then
            -- Handshake acknowledged by server
            hive.address = message.remoteAddress
            bootstrap = false  -- Will be set to true by bootstrap sequence
            beepSeq(bSeq.conn)
            print("Handshake successful with hive at " .. tostring(hive.address))
            
            -- Initiate bootstrap request
            -- This will be handled by bootstrap sequence
        else
            print("Handshake response mismatch")
        end
    end
end

