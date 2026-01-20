-- Server-side handshake sequence function
-- This function is called to create the coroutine for handling handshake messages
return function(hive, protocol)
    return function(message)
        -- Server-side handshake logic
        -- Message format: "handshake", nodeId, hiveId
        local nodeId = message.data[2]
        local receivedHiveId = message.data[3]
        
        debugPrint("Handshake initiated for node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> from <c=0x888888>" .. tostring(message.remoteAddress) .. "</c>")
        
        -- Verify hive ID matches
        if receivedHiveId ~= getHiveId() then
            print("<c=0xFF0000>● Connection failed:</c> <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> <c=0xFF0000>(hive ID mismatch)</c>")
            return {}
        end
        
        -- Connect the node (validation happens in connectNode)
        local nodeObj = hive:connectNode(nodeId, message.remoteAddress)
        
        if not nodeObj then
            -- Silent rejection - node not in database, defective, or duplicate connection
            debugPrint("Handshake rejected for <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> (not in database, defective, or duplicate)")
            return {}
        end
        
        -- Return handshake_ack and initiate Stage 2 transfer
        local ackResponse = class("../../messages/outbound"):new(
            nodeObj,
            protocol,
            message.distance,
            "handshake_ack",
            nodeId,
            getHiveId()
        )
        
        -- Read and transmit Stage 2 client script
        local stage2Path = "/shn-01/data/clientStage2.lua"
        local stage2Content = file.read(stage2Path)
        
        if not stage2Content then
            print("<c=0xFF0000>Error:</c> Failed to read Stage 2 client script at " .. stage2Path)
            return {ackResponse}
        end
        
        -- Calculate MD5 checksum (load md5 module with absolute path)
        local md5 = require("/shn-01/md5")
        local checksum = md5.sumhexa(stage2Content)
        
        -- Split Stage 2 content into 512-byte packets
        local packetSize = 512
        local totalPackets = math.ceil(#stage2Content / packetSize)
        local responses = {ackResponse}
        
        debugPrint("Sending Stage 2 to node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c>: " .. #stage2Content .. " bytes in " .. totalPackets .. " packets")
        
        -- Send all packets
        for seqNum = 1, totalPackets do
            local startPos = (seqNum - 1) * packetSize + 1
            local endPos = math.min(seqNum * packetSize, #stage2Content)
            local packetData = stage2Content:sub(startPos, endPos)
            
            local packetMsg = class("../../messages/outbound"):new(
                nodeObj,
                protocol,
                message.distance,
                "transmit_packet",
                seqNum,
                totalPackets,
                packetData
            )
            table.insert(responses, packetMsg)
        end
        
        -- Send completion with checksum
        local completionMsg = class("../../messages/outbound"):new(
            nodeObj,
            protocol,
            message.distance,
            "transmit_complete",
            totalPackets,
            checksum
        )
        table.insert(responses, completionMsg)
        
        return responses
    end
end
