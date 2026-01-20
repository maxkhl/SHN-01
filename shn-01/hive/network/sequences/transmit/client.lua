-- Client-side transmit sequence function
-- This function is called to create the coroutine for handling transmit messages
return function()
    return function(message)
        -- Client-side file receive logic
        -- Message format: "transmit_packet", seqNum, totalPackets, data or "transmit_complete", totalPackets, failedPackets
        local command = message.data[1]
        local param1 = message.data[2]
        local param2 = message.data[3]
        local param3 = message.data[4]
        
        if command == "transmit_packet" then
            -- Receive packet
            local seqNum = param1
            local totalPackets = param2
            local packetData = param3
            
            -- Store packet in buffer (global table for this transmission)
            if not _G.transmitBuffer then
                _G.transmitBuffer = {}
                _G.transmitTotal = totalPackets
            end
            
            _G.transmitBuffer[seqNum] = packetData
            
            print("Received packet " .. seqNum .. "/" .. totalPackets)
            
            -- Send ACK back to server
            -- In client template, this would use modem.send
            mdm.send(message.remoteAddress, message.protocol.port, "transmit_ack", seqNum)
            
        elseif command == "transmit_complete" then
            -- Transmission complete, check for missing packets
            local totalPackets = param1
            local checksumExpected = param2
            local failedPackets = param3 or ""
            
            local missingPackets = {}
            for i = 1, totalPackets do
                if not _G.transmitBuffer[i] then
                    table.insert(missingPackets, i)
                end
            end
            
            if #missingPackets > 0 then
                print("Missing packets: " .. table.concat(missingPackets, ","))
                -- Request retransmission of missing packets
                for _, seqNum in ipairs(missingPackets) do
                    mdm.send(message.remoteAddress, message.protocol.port, "transmit_request", seqNum)
                end
            else
                -- Reassemble file
                local fileContent = ""
                for i = 1, totalPackets do
                    fileContent = fileContent .. (_G.transmitBuffer[i] or "")
                end
                
                -- Validate MD5 checksum
                local actualChecksum = md5.sumhexa(fileContent)
                if actualChecksum ~= checksumExpected then
                    print("Checksum mismatch! Expected: " .. tostring(checksumExpected) .. ", Got: " .. actualChecksum)
                    -- Clear buffer and request retransmission
                    _G.transmitBuffer = nil
                    _G.transmitTotal = nil
                    mdm.send(message.remoteAddress, message.protocol.port, "CHECKSUM_FAIL")
                    beepSeq(bSeq.err)
                    return
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