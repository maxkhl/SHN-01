-- Client-side disconnect sequence function
-- This function is called to create the coroutine for handling disconnect messages
return function()
    return function(message)
        -- Client-side disconnect logic
        -- This sends a disconnect message to the hive before shutdown
        -- Usage: send message with command "disconnect" and node.id
        
        print("Sending disconnect to hive...")
        
        -- The actual sending happens via the protocol
        -- This function is called when receiving confirmation (if any)
    end
end
