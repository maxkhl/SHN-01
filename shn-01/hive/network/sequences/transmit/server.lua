-- Server-side transmit sequence function
-- This function is called to create the coroutine for handling file transmit messages
return function(hive, protocol)

    local minify = require("/systems/minify")
    local adler32 = require("/shn-01/adler32")
    local timer = require("/systems/timer")
    return function(node, args)
        
        -- Server-side file transmit logic
        -- Message format: "transmit_start", filePath or "transmit_ack", seqNum
        local command = string.upper(args[1])
        local param = args[2]
        
        -- Initialize session state for ACK management
        if not node.transmitState then
            node.transmitState = {
                filePath = nil,
                fileContent = nil,
                pendingAcks = {},
                retryCount = 0,
                maxRetries = 3,
                totalPackets = 0,
                startTime = nil,
                overallTimeout = 30 -- 30 seconds total timeout
            }
        end
        local sessionState = node.transmitState
        
        if command == "TRANSMIT_START" then
            -- Client requests file transmission
            local filePath = param
            
            debugPrint("Transmit request for file: <c=0xFFFFFF>" .. tostring(filePath) .. "</c>", node)
            
            -- Store filepath for potential retry
            sessionState.filePath = filePath
            
            -- Read file content (or use cached content for retry)
            local fileContent = sessionState.fileContent
            if not fileContent then
                local fs = fileSystem()
                local fullPath = getAbsolutePath(filePath)
                
                if not fs.exists(fullPath) then
                    debugPrint("File not found: " .. fullPath, node)
                    return {}
                end
                
                
                fileContent = file.readWithIncludesMinified(fullPath, minify.parseCheap)
                if not fileContent then
                    debugPrint("Failed to read file: " .. fullPath, node)
                    return {}
                end
                
                -- Cache file content for potential retries
                sessionState.fileContent = fileContent
            end
            
            local fileSize = #fileContent
            local packetSize = 512
            local totalPackets = math.ceil(fileSize / packetSize)
            
            debugPrint("File size: <c=0xFFFFFF>" .. fileSize .. "</c> bytes, <c=0xFFFFFF>" .. totalPackets .. "</c> packets", node)
            
            -- Initialize transmission state
            sessionState.totalPackets = totalPackets
            sessionState.startTime = computer.uptime()
            sessionState.fileSize = fileSize
            sessionState.packetSize = packetSize
            
            -- Mark all packets as pending ACK
            for seqNum = 1, totalPackets do
                sessionState.pendingAcks[seqNum] = true
            end
            
            -- Send all packets with per-packet checksums
            local responses = {}
            for seqNum = 1, totalPackets do
                local startPos = (seqNum - 1) * packetSize + 1
                local endPos = math.min(seqNum * packetSize, fileSize)
                local packetData = fileContent:sub(startPos, endPos)
                local packetChecksum = adler32.run(packetData)
                
                local response = class("../../messages/outbound"):new(
                    node,
                    protocol,
                    nil,
                    false,
                    "TRANSMIT_PACKET",
                    seqNum,
                    totalPackets,
                    packetChecksum,
                    packetData
                )
                table.insert(responses, response)
            end
            
            debugPrint("File transmission initiated: <c=0xFFFFFF>" .. totalPackets .. "</c> packets sent", node)
            
            -- Yield to send initial packets
            node, args = coroutine.yield(responses)
            
            -- Now loop and wait for ACKs with timeout and retry logic
            local retryInterval = 5 -- seconds between retry checks
            local lastRetryTime = computer.uptime()
            
            while true do
                -- Check for overall timeout first
                if computer.uptime() - sessionState.startTime > sessionState.overallTimeout then
                    debugPrint("Transmission timeout after " .. sessionState.overallTimeout .. " seconds", node)
                    node.transmitState = nil
                    return {}
                end
                
                -- Process received message (could be ACK) BEFORE retry logic
                if args and args[1] == "TRANSMIT_ACK" then
                    local seqNum = tonumber(args[2])
                    if seqNum and sessionState.pendingAcks[seqNum] then
                        sessionState.pendingAcks[seqNum] = nil
                        --debugPrint("Received ACK for packet " .. seqNum, node)
                    end
                end
                
                -- Check if all packets acknowledged
                local pendingCount = 0
                for _ in pairs(sessionState.pendingAcks) do
                    pendingCount = pendingCount + 1
                end
                
                if pendingCount == 0 then
                    -- All ACKs received, send completion
                    local completion = class("../../messages/outbound"):new(
                        node,
                        protocol,
                        nil,
                        false,
                        "TRANSMIT_COMPLETE",
                        sessionState.totalPackets
                    )
                    debugPrint("All packets acknowledged, transmission complete", node)
                    node.transmitState = nil
                    return {completion}
                end
                
                -- Check if we need to retry (every 5 seconds)
                if computer.uptime() - lastRetryTime >= retryInterval then
                    lastRetryTime = computer.uptime()
                    
                    debugPrint("Retry check: " .. pendingCount .. " pending ACKs, retry count: " .. sessionState.retryCount .. "/" .. sessionState.maxRetries, node)
                    
                    -- Check retry limit
                    if sessionState.retryCount >= sessionState.maxRetries then
                        debugPrint("Max retries reached, <c=0xFFFFFF>" .. pendingCount .. "</c> packets unacknowledged", node)
                        node.transmitState = nil
                        return {}
                    end
                    
                    -- Retransmit missing packets with checksums
                    sessionState.retryCount = sessionState.retryCount + 1
                    debugPrint("Retry #" .. sessionState.retryCount .. ": retransmitting <c=0xFFFFFF>" .. pendingCount .. "</c> packets", node)
                    
                    local retransmitResponses = {}
                    for seqNum in pairs(sessionState.pendingAcks) do
                        local startPos = (seqNum - 1) * sessionState.packetSize + 1
                        local endPos = math.min(seqNum * sessionState.packetSize, sessionState.fileSize)
                        local packetData = sessionState.fileContent:sub(startPos, endPos)
                        local packetChecksum = adler32.run(packetData)
                        
                        local response = class("../../messages/outbound"):new(
                            node,
                            protocol,
                            nil,
                            false,
                            "TRANSMIT_PACKET",
                            seqNum,
                            sessionState.totalPackets,
                            packetChecksum,
                            packetData
                        )
                        table.insert(retransmitResponses, response)
                    end
                    
                    -- Yield to send retransmit packets
                    node, args = coroutine.yield(retransmitResponses)
                else
                    -- Yield empty to wait for next message (ACK)
                    node, args = coroutine.yield({})
                end
            end
            
        elseif command == "TRANSMIT_ACK" then
            -- Client acknowledges packet receipt
            local seqNum = tonumber(param)
            if seqNum and sessionState.pendingAcks[seqNum] then
                sessionState.pendingAcks[seqNum] = nil
                --debugPrint("Received ACK for packet " .. seqNum, node)
                
                -- Check if all packets acknowledged
                local allAcked = true
                for _ in pairs(sessionState.pendingAcks) do
                    allAcked = false
                    break
                end
                
                if allAcked and sessionState.totalPackets > 0 then
                    -- Send completion message
                    local completion = class("../../messages/outbound"):new(
                        node,
                        protocol,
                        nil,
                        false,
                        "TRANSMIT_COMPLETE",
                        sessionState.totalPackets,
                        sessionState.checksum,
                        ""
                    )
                    debugPrint("All packets acknowledged, transmission complete", node)
                    node.transmitState = nil
                    return {completion}
                end
            end
            return {}
            
        elseif command == "TRANSMIT_REQUEST" then
            -- Client requests specific packet retransmission
            -- Handle retransmission logic here if needed
            return {}
        end
        
        return {}
    end
end
