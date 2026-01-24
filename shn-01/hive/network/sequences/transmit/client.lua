-- Client-side transmit sequence function
-- This function is called to create the coroutine for handling transmit messages
return function()
    return function(message)
        -- Client-side file receive logic
        -- Message format: "transmit_packet", seqNum, totalPackets, checksum, data or "transmit_complete", totalPackets
        local command = message.data[1]
        local param1 = message.data[2]
        local param2 = message.data[3]
        local param3 = message.data[4]
        local param4 = message.data[5]
        
        if command == "transmit_packet" then
            -- Receive packet
            local seqNum = param1
            local totalPackets = param2
            local expectedChecksum = param3
            local packetData = param4
            
            -- Validate packet checksum
            local actualChecksum = crypto.adler32(packetData)
            
            if actualChecksum ~= expectedChecksum then
                print("Packet " .. seqNum .. " checksum mismatch! Expected: " .. expectedChecksum .. ", Got: " .. actualChecksum)
                -- Don't ACK corrupted packets - server will retransmit
                return
            end
            
            -- Store packet in buffer (global table for this transmission)
            if not _G.transmitBuffer then
                _G.transmitBuffer = {}
                _G.transmitTotal = totalPackets
            end
            
            _G.transmitBuffer[seqNum] = packetData
            
            print("Received packet " .. seqNum .. "/" .. totalPackets .. " (checksum OK)")
            
            -- Send ACK back to server for valid packet
            mdm.send(message.remoteAddress, message.protocol.port, "transmit_ack", seqNum)
            
        elseif command == "transmit_complete" then
            -- Transmission complete, check for missing packets
            local totalPackets = param1
            
            local missingPackets = {}
            for i = 1, totalPackets do
                if not _G.transmitBuffer[i] then
                    table.insert(missingPackets, i)
                end
            end
            
            if #missingPackets > 0 then
                print("Warning: Missing " .. #missingPackets .. " packets, server may retry")
                -- Server will retransmit un-ACKed packets automatically
            else
                -- Reassemble file
                local fileContent = ""
                for i = 1, totalPackets do
                    fileContent = fileContent .. (_G.transmitBuffer[i] or "")
                end
                
                print("File received successfully, " .. #fileContent .. " bytes")
                
                -- Store in global for bootstrap to use
                _G.lastReceivedFile = fileContent
                
                -- Clear buffer
                _G.transmitBuffer = nil
                _G.transmitTotal = nil
                
                beepSeq(bSeq.success)
            end
        end
    end
end