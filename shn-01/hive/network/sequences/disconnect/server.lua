-- Server-side disconnect sequence function
-- This function is called to create the coroutine for handling disconnect messages
return function(hive, protocol)
    return function(message)
        -- Server-side disconnect logic
        -- Message format: "disconnect", nodeId
        local nodeId = message.data[2]
        
        local node = hive.nodes[message.remoteAddress]
        debugPrint("Disconnect request from node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> at <c=0x888888>" .. tostring(message.remoteAddress) .. "</c>", node)
        
        -- Remove node from connected nodes
        local node = hive.nodes[message.remoteAddress]
        if node then
            local nodeShortName = node.shortName
            node:remove()
            print("<c=0xFFFFFF>[" .. nodeShortName .. "]</c> <c=0xFFAA00>● Node disconnected:</c> <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> <c=0xFFAA00>(graceful)</c>")
        else
            debugPrint("Node <c=0xFFFFFF>" .. tostring(nodeId) .. "</c> was not in connected list")
        end
        
        -- No response needed for disconnect
        return {}
    end
end
