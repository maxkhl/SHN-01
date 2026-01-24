--[[
    SHN-01 Outbound Message Queue Manager
    Provides rate-limited dual-priority message queuing to prevent overwhelming OpenComputers relays.
    
    Features:
    - High/Low priority queues with high priority processed first
    - Configurable messages-per-second rate limit (default: 10)
    - 1000 message total capacity (drop oldest on overflow)
    - Token bucket rate limiting via globalEvents.onTick
]]

local outboundQueue = {}

-- Queue state
outboundQueue.highPriorityQueue = {}
outboundQueue.lowPriorityQueue = {}
outboundQueue.maxCapacity = 1000
outboundQueue.droppedCount = 0

-- Rate limiting state (token bucket)
outboundQueue.tokensAvailable = 0
outboundQueue.lastTickTime = computer.uptime()

-- Get current rate limit from database (messages per second)
function outboundQueue:getRateLimit()
    return database:getKey("shn01", "queueRateLimit") or 10
end

-- Get total message count across both queues
function outboundQueue:getTotalCount()
    return #self.highPriorityQueue + #self.lowPriorityQueue
end

-- Enqueue a message into appropriate priority queue
function outboundQueue:enqueue(outboundMessage)
    assert(outboundMessage, "No message provided to enqueue")
    
    -- Check if we're at capacity
    if self:getTotalCount() >= self.maxCapacity then
        -- Drop oldest message (check low priority first, then high priority)
        local dropped = nil
        if #self.lowPriorityQueue > 0 then
            dropped = table.remove(self.lowPriorityQueue, 1)
        elseif #self.highPriorityQueue > 0 then
            dropped = table.remove(self.highPriorityQueue, 1)
        end
        
        if dropped then
            self.droppedCount = self.droppedCount + 1
            local nodeStr = dropped.node and dropped.node.shortName or "unknown"
            local protocolStr = dropped.protocol and dropped.protocol.name or "unknown"
            console:logError("Queue overflow: dropped message from [" .. nodeStr .. "] on protocol " .. protocolStr .. " (total dropped: " .. self.droppedCount .. ")")
        end
    end
    
    -- Add to appropriate queue based on priority
    if outboundMessage.highPriority then
        table.insert(self.highPriorityQueue, outboundMessage)
    else
        table.insert(self.lowPriorityQueue, outboundMessage)
    end
end

-- Process queues and send messages respecting rate limit
function outboundQueue:tick()
    local currentTime = computer.uptime()
    local deltaTime = currentTime - self.lastTickTime
    self.lastTickTime = currentTime
    
    -- Add tokens based on rate limit (tokens = messages per second * time elapsed)
    local rateLimit = self:getRateLimit()
    self.tokensAvailable = self.tokensAvailable + (rateLimit * deltaTime)
    
    -- Cap tokens at rate limit (don't accumulate more than 1 second worth)
    if self.tokensAvailable > rateLimit then
        self.tokensAvailable = rateLimit
    end
    
    -- Process messages while we have tokens
    while self.tokensAvailable >= 1 do
        local message = nil
        
        -- Try high priority queue first
        if #self.highPriorityQueue > 0 then
            message = table.remove(self.highPriorityQueue, 1)
        elseif #self.lowPriorityQueue > 0 then
            message = table.remove(self.lowPriorityQueue, 1)
        else
            -- No messages to send
            break
        end
        
        -- Send the message directly via modem
        if message then
            local modem = getComponent("modem")
            if modem then
                local dataStr = table.concat(message.data, ", "):gsub("[\n\r]", " ")
                debugPrint("Sending message on protocol <c=0xFFFFFF>" .. message.protocol.name .. "</c>: " .. (#dataStr > 100 and (dataStr:sub(1, 100) .. "...") or dataStr), message.node, 2)
                modem.send(message.remoteAddress, message.protocol.port, table.unpack(message.data))
                
                -- Consume one token
                self.tokensAvailable = self.tokensAvailable - 1
            else
                console:logError("Queue: modem component not available")
                break
            end
        end
    end
end

-- Subscribe to tick event for processing
globalEvents.onTick:subscribe(function()
    outboundQueue:tick()
end)

-- Initialize default rate limit if not set
if not database:getKey("shn01", "queueRateLimit") then
    database:setKey("shn01", "queueRateLimit", 10, true)
end

return outboundQueue
