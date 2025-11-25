local t = {}

-- contains timers for scheduling function calls
t.timers = {}

-- Adds a new timer
-- Delay is the time in seconds (no decimals) it takes for callback to be called
--   Seconds is relative here. It will rarely be exact seconds as processing time is added on top. So if another callback is called during delay-time and it takes x seconds to process you can add that to your wait time
-- Callback is the callback function
-- Reset is the amount that should be set for delay once delay is over (no decimals)
function t.add(delay, callback, reset)
  for _, timer in ipairs(t.timers) do
      if timer.callback == callback then
          return nil -- Callback already exists; don't add it again
      end
  end
  table.insert(t.timers, {
      delay = math.ceil(delay),
      callback = callback,
      reset = reset and math.ceil(reset) or nil
  })
  return #t.timers
end

-- Removes a timer to a certain callback function
function t.remove(callback)
  if callback then
    for i, dat in pairs(t.timers) do
      if dat.callback == callback then
        t.timers[i] = nil
      end
    end
  end
end

t.delayedFunctions = {}
-- Delays a function to the next update loop.
function t.delay(callback)
  if type(callback) ~= "function" then
    error("TIMER.DELAY: Callback must be a function")
    return false
  end
  table.insert(t.delayedFunctions, callback)
end


-- Update loop
t.oldTime = computer.uptime()
function t.update()
  local passedTime = computer.uptime() - t.oldTime
  t.oldTime = computer.uptime()
  for key, timer in pairs(t.timers) do
    if timer.delay > 0 then
      timer.delay = timer.delay - passedTime
    end
    if timer.delay <= 0 then
      local success, reason = pcall(timer.callback)
      if not success then error(reason) end
      if timer.reset then
        timer.delay = timer.reset
      else
        t.timers[key] = nil
      end
    end
  end

  -- Handle delayed functions
  for id, callback in pairs(t.delayedFunctions) do
    local success, reason = pcall(callback)
    if not success then
      error("TIMER.DELAY: Error in delayed function: " .. tostring(reason))
    end
    t.delayedFunctions[id] = nil -- Remove after execution
  end
end
globalEvents.onTick:subscribe(t.update)



console:addCommand("TIMER.LIST", "Lists currently running timers", function()
  for key, timer in pairs(t.timers) do
    print(tostring(key) .. ' - ' .. tostring(timer.delay) .. ' - ' .. tostring(timer.callback) .. ' - ' .. tostring(timer.reset))
  end
end)

return t