-- Server-side bootstrap sequence function
-- This function is called to create the coroutine for handling bootstrap messages
return function(hive, protocol)
    return function(message)
        -- Server-side bootstrap logic
        -- Message format: "bootstrap_request", nodeId or "bootstrap_ack", success
        local command = message.data[2]
        local nodeId = message.data[3]
        
        local database = require("/systems/database.lua")
        local hiveDebug = database:getKey("shn01", "hiveDebug")
        
        if command == "bootstrap_request" then
            print("Bootstrap request from node " .. tostring(nodeId))
            
            -- Get node object from active connections
            local node = hive.nodes[message.remoteAddress]
            if not node then
                print("Bootstrap failed: node not connected")
                return {}
            end
            
            -- Collect all client-side protocol files
            local clientFiles = {}
            local fs = fileSystem()
            local sequencesPath = getAbsolutePath("../sequences")
            
            for _, seqFolder in pairs(fs.list(sequencesPath) or {}) do
                local manifestPath = sequencesPath .. "/" .. seqFolder .. "/manifest.lua"
                if fs.exists(manifestPath) then
                    local manifest = include(manifestPath)
                    if manifest and manifest.client then
                        local clientPath = "hive/network/sequences/" .. seqFolder .. "/" .. manifest.client
                        table.insert(clientFiles, {name = seqFolder, path = clientPath})
                        if hiveDebug then
                            print("  Added client protocol: " .. seqFolder)
                        end
                    end
                end
            end
            
            -- Add node-specific script if available
            local nodeScript = node:getScript()
            if nodeScript and nodeScript ~= "" then
                local scriptPath = "hive/node-scripts/" .. nodeScript
                table.insert(clientFiles, {name = "node_script", path = scriptPath})
                if hiveDebug then
                    print("  Added node script: " .. nodeScript)
                end
            end
            
            print("Bootstrap: sending " .. #clientFiles .. " files to node " .. nodeId)
            
            -- Send file list
            local fileListMsg = class("../../messages/outbound"):new(
                node,
                protocol,
                message.distance,
                "bootstrap_start",
                #clientFiles,
                nodeId
            )
            
            -- For now, return file list. Actual file transmission would be
            -- handled by transmit sequence in a coordinated manner
            -- This is a simplified version - full implementation would:
            -- 1. Send file list
            -- 2. For each file, initiate transmit sequence
            -- 3. Track success/failure per file
            -- 4. Retry failed files up to 5 times
            -- 5. Mark node defective if any file fails 5 times
            -- 6. Mark node as bootstrapped on success
            
            return {fileListMsg}
            
        elseif command == "bootstrap_ack" then
            -- Bootstrap completed
            local success = message.data[3]
            
            local node = hive.nodes[message.remoteAddress]
            if not node then
                return {}
            end
            
            if success then
                print("Bootstrap completed successfully for node " .. tostring(nodeId))
                node:markBootstrapped()
            else
                print("Bootstrap failed for node " .. tostring(nodeId))
                node:incrementBootstrapAttempt()
                
                if node.bootstrapAttempts >= 5 then
                    print("Node " .. tostring(nodeId) .. " marked as defective after 5 failed bootstrap attempts")
                    node:markDefective("Bootstrap failed after 5 attempts")
                end
            end
            
            return {}
        end
        
        return {}
    end
end
