-- Client-side bootstrap sequence function
-- This function is called to create the coroutine for handling bootstrap messages
return function()
    return function(message)
        -- Client-side bootstrap logic
        -- Message format: "bootstrap_start", fileCount, nodeId
        local command = message.data[1]
        local param1 = message.data[2]
        local param2 = message.data[3]
        
        if command == "bootstrap_start" then
            -- Receive file list and prepare for file transfers
            local fileCount = param1
            local nodeIdReceived = param2
            
            print("Bootstrap started, expecting " .. fileCount .. " files")
            
            -- Initialize bootstrap state
            _G.bootstrapFiles = {}
            _G.bootstrapTotal = fileCount
            _G.bootstrapReceived = 0
            
            -- Files will be received via transmit sequence
            -- Each file will be compiled and stored
            
        elseif command == "bootstrap_file_ready" then
            -- A file has been received via transmit
            local fileName = param1
            local fileContent = _G.lastReceivedFile
            
            if not fileContent then
                print("Error: No file content available")
                send(hive.address, 2015, "error", "Bootstrap file missing", "No content for " .. fileName)
                return
            end
            
            print("Processing bootstrap file: " .. fileName)
            
            -- Compile protocol files
            if fileName ~= "node_script" then
                -- This is a network protocol
                local success, compiledOrError = pcall(load, fileContent)
                
                if success and compiledOrError then
                    -- Store compiled protocol
                    if not _G.protocols then
                        _G.protocols = {}
                    end
                    _G.protocols[fileName] = compiledOrError
                    print("  Protocol " .. fileName .. " loaded")
                else
                    print("  Failed to compile " .. fileName)
                    send(hive.address, 2015, "error", "Bootstrap compilation failed", tostring(compiledOrError))
                    mdm.send(hive.address, 2015, "bootstrap_ack", node.id, false)
                    return
                end
            else
                -- This is the node-specific script
                print("  Executing node script...")
                local success, errorMsg = pcall(function()
                    local scriptFunc, compileError = load(fileContent)
                    if not scriptFunc then
                        error("Script compilation failed: " .. tostring(compileError))
                    end
                    scriptFunc()
                end)
                
                if not success then
                    print("  Node script execution failed")
                    send(hive.address, 2015, "error", "Node script execution failed", tostring(errorMsg))
                    mdm.send(hive.address, 2015, "bootstrap_ack", node.id, false)
                    return
                end
                print("  Node script executed successfully")
            end
            
            _G.bootstrapReceived = _G.bootstrapReceived + 1
            
            -- Check if all files received
            if _G.bootstrapReceived >= _G.bootstrapTotal then
                print("Bootstrap complete!")
                bootstrap = false
                
                -- Send success acknowledgment
                mdm.send(hive.address, 2015, "bootstrap_ack", node.id, true)
                beepSeq(bSeq.success)
            end
        end
    end
end
