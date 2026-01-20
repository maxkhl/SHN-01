-- Server-side transmit sequence function
-- This function is called to create the coroutine for handling file transmit messages
return function(hive, protocol)
    return function(message)
        -- Server-side file transmit logic
        -- Message format: "transmit_start", filePath or "transmit_ack", seqNum or "transmit_request", seqNum or "CHECKSUM_FAIL"
        local command = message.data[2]
        local param = message.data[3]
        
        -- Initialize session state for checksum tracking
        local sessionState = coroutine.yield({})
        if not sessionState.checksumFailures then
            sessionState.checksumFailures = 0
            sessionState.filePath = nil
            sessionState.fileContent = nil
        end
        
        if command == "CHECKSUM_FAIL" then
            -- Client reported checksum failure, increment counter
            sessionState.checksumFailures = sessionState.checksumFailures + 1
            print("Checksum failure #" .. sessionState.checksumFailures .. " for " .. tostring(sessionState.filePath))
            
            if sessionState.checksumFailures >= 10 then
                -- Mark node as defective after 10 checksum failures
                print("Node " .. message.node.id .. " marked defective: 10 checksum failures")
                message.node:markDefective("File transfer checksum failed 10 times")
                return {}
            end
            
            -- Retry transmission with stored file content
            command = "transmit_start"
            param = sessionState.filePath
            
        elseif command == "transmit_start" then
            -- Client requests file transmission
            local filePath = param
            
            print("Transmit request for file: " .. tostring(filePath))
            
            -- Store filepath for potential retry
            sessionState.filePath = filePath
            
            -- Read file content (or use cached content for retry)
            local fileContent = sessionState.fileContent
            if not fileContent then
                local fs = fileSystem()
                local fullPath = getAbsolutePath(filePath)
                
                if not fs.exists(fullPath) then
                    print("File not found: " .. fullPath)
                    return {}
                end
                
                local fileHandle = fs.open(fullPath, "r")
                if not fileHandle then
                    print("Failed to open file: " .. fullPath)
                    return {}
                end
                
                fileContent = fileHandle.readAll()
                fileHandle.close()
                
                -- Cache file content for potential retries
                sessionState.fileContent = fileContent
            end
            
            local fileSize = #fileContent
            local packetSize = 512
            local totalPackets = math.ceil(fileSize / packetSize)
            
            print("File size: " .. fileSize .. " bytes, " .. totalPackets .. " packets")
            
            -- Split into packets and send
            local responses = {}
            local failedPackets = {}
            
            for seqNum = 1, totalPackets do
                local startPos = (seqNum - 1) * packetSize + 1
                local endPos = math.min(seqNum * packetSize, fileSize)
                local packetData = fileContent:sub(startPos, endPos)
                
                local retries = 0
                local maxRetries = 3
                local ackReceived = false
                
                local node = hive.nodes[message.remoteAddress]
                if not node then
                    print("Node not found for transmit")
                    break
                end
                
                while retries < maxRetries and not ackReceived do
                    -- Send packet
                    local response = class("messages/outbound"):new(
                        node,
                        protocol,
                        message.distance,
                        "transmit_packet",
                        seqNum,
                        totalPackets,
                        packetData
                    )
                    table.insert(responses, response)
                    
                    -- Yield and wait for ACK (simplified - actual implementation would need timeout handling)
                    coroutine.yield("Waiting for ACK " .. seqNum .. "/" .. totalPackets)
                    
                    -- In actual implementation, check if ACK was received
                    -- For now, assume success after first try
                    ackReceived = true
                    retries = retries + 1
                end
                
                if not ackReceived then
                    table.insert(failedPackets, seqNum)
                end
            end
            
            -- Calculate MD5 checksum of file content
            local checksum = md5.sumhexa(fileContent)
            
            -- Send completion message with checksum
            local node = hive.nodes[message.remoteAddress]
            if node then
                local completion = class("../../messages/outbound"):new(
                    node,
                    protocol,
                    message.distance,
                    "transmit_complete",
                    totalPackets,
                    checksum,
                    #failedPackets > 0 and table.concat(failedPackets, ",") or ""
                )
                table.insert(responses, completion)
            end
            
            if #failedPackets == 0 then
                print("File transmitted successfully")
                return responses
            else
                print("File transmission completed with " .. #failedPackets .. " failed packets")
                return responses
            end
            
        elseif command == "transmit_ack" then
            -- Client acknowledges packet receipt
            local seqNum = param
            -- Mark packet as acknowledged (handled by session management)
            return {}
            
        elseif command == "transmit_request" then
            -- Client requests specific packet retransmission
            -- Handle retransmission logic here if needed
            return {}
        end
        
        return {}
    end
end
