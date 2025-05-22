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
end
globalEvents = require("systems/globalEvents.lua")
globalEvents.onTick:subscribe(t.update)


local console = require("systems/console.lua")
console:addCommand("TIMER.LIST", "Lists currently running timers", function(self)
  for key, timer in pairs(t.timers) do
    print(tostring(key) .. ' - ' .. tostring(timer.delay) .. ' - ' .. tostring(timer.callback) .. ' - ' .. tostring(timer.reset))
  end
end)

return t