timer = {}

-- contains timers for scheduling function calls
timer.timers = {}

-- Adds a new timer
-- Delay is the time in seconds (no decimals) it takes for callback to be called
--   Seconds is relative here. It will rarely be exact seconds as processing time is added on top. So if another callback is called during delay-time and it takes x seconds to process you can add that to your wait time
-- Callback is the callback function
-- Reset is the amount that should be set for delay once delay is over (no decimals)
function timer.add(delay, callback, reset)
  for _, timer in ipairs(timer.timers) do
      if timer.callback == callback then
          return nil -- Callback already exists; don't add it again
      end
  end
  table.insert(timer.timers, {
      delay = math.ceil(delay),
      callback = callback,
      reset = reset and math.ceil(reset) or nil
  })
  return #timer.timers
end

-- Removes a timer to a certain callback function
function timer.remove(callback)
  if callback then
    for i, dat in pairs(timer.timers) do
      if datimer.callback == callback then
        timer.timers[i] = nil
      end
    end
  end
end

timer.delayedFunctions = {}
-- Delays a function to the next update loop.
function timer.delay(callback)
  if type(callback) ~= "function" then
    error("TIMER.DELAY: Callback must be a function")
    return false
  end
  table.insert(timer.delayedFunctions, callback)
end


-- Update loop
timer.oldTime = computer.uptime()
function timer.update()
  local passedTime = computer.uptime() - timer.oldTime
  timer.oldTime = computer.uptime()
  for key, timer in pairs(timer.timers) do
    if timer.delay > 0 then
      timer.delay = timer.delay - passedTime
    end
    if timer.delay <= 0 then
      local success, reason = pcall(timer.callback)
      if not success then error(reason) end
      if timer.reset then
        timer.delay = timer.reset
      else
        timer.timers[key] = nil
      end
    end
  end

  -- Handle delayed functions
  for id, callback in pairs(timer.delayedFunctions) do
    local success, reason = pcall(callback)
    if not success then
      error("TIMER.DELAY: Error in delayed function: " .. tostring(reason))
    end
    timer.delayedFunctions[id] = nil -- Remove after execution
  end
end
globalEvents.onTick:subscribe(timer.update)



console:addCommand("TIMER.LIST", "Lists currently running timers", function()
  for key, timer in pairs(timer.timers) do
    print(tostring(key) .. ' - ' .. tostring(timer.delay) .. ' - ' .. tostring(timer.callback) .. ' - ' .. tostring(timer.reset))
  end
end)
