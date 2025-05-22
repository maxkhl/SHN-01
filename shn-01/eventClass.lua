-- Custom event handling
local event = {}
event.__index = event

-- Creates a new event with the given name
function event.new()
    local self = setmetatable({}, event)

    -- contains all listening functions
    self.listener = {}

    -- Internal counter for IDs
    self.nextListenerId = 1
    return self
end

-- Fires this event, calls all listeners with pcall and logs any errors
function event:fire(...)
    for i, listener in pairs(self.listener) do
        local ok, err = pcall(listener, ...)
        if not ok then
            error("Listener Error:" .. tostring(err))
        end
    end
end

-- Adds a function as a listener
function event:subscribe(callback)
    -- Prevent duplicate subscriptions
    for id, listener in pairs(self.listener) do
        if listener == callback then
            return id -- Already subscribed
        end
    end

    local id = self.nextListenerId
    self.listener[id] = callback
    self.nextListenerId = self.nextListenerId + 1
    return id
end

-- Removes a function from the listeners
-- returns true if successfully unsubscribed
function event:unsubscribe(id)
    if self.listener[id] then
        self.listener[id] = nil
        return true
    end
    return false
end

-- Returns true if this event has any subscribers
function event:hasSubscribers()
    for _, _ in pairs(self.listener) do
        return true
    end
    return false
end

return event