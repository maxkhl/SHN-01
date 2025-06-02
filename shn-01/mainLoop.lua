--[[    
    SHN-01 core file
        This file contains the core functions of the SHN-01 system
        It is loaded by the main file and provides the basic functionality of the system.
        It is not meant to be modified by the user.
]]--

local tps = 0
local tpsCount = 0
local tpsSecond = 0
local netMsgCount = 0
local netMsgPerSecond = 0

local console = require("/systems/console.lua")

-- The main update loop
while true do
  local e = {computer.pullSignal(0.05)}

  
  if e[1] then
    if e[1] == "interrupted" then
      print("Interrupted")
    elseif e[1] == "key_down" then
      globalEvents.onKeyDown:fire(e[3], e[4])
    elseif e[1] == "key_up" then
      globalEvents.onKeyUp:fire(e[3], e[4])
    elseif e[1] == "modem_message" then
      netMsgCount = netMsgCount + 1
      globalEvents.onNetMessageReceived:fire(table.unpack(e, 2))
    elseif e[1] == "touch" then
      globalEvents.onTouch:fire(table.unpack(e, 2))
    elseif e[1] == "drag" then
      globalEvents.onDrag:fire(table.unpack(e, 2))
    elseif e[1] == "drop" then
      globalEvents.onDrop:fire(table.unpack(e, 2))
    elseif e[1] == "scroll" then
      globalEvents.onScroll:fire(table.unpack(e, 2))

    else
      globalEvents.onSignal:fire(table.unpack(e))
    end
  end

  globalEvents.onTick:fire()

  tpsCount = tpsCount + 1
  if computer.uptime() - tpsSecond >= 1 then
    tps = tpsCount
    tpsCount = 0
    netMsgPerSecond = netMsgCount
    netMsgCount = 0
    tpsSecond = computer.uptime()
    if console then
      local totalMemory = computer.totalMemory()
      local freeMemory = computer.freeMemory()
      local memory = (totalMemory - freeMemory) / totalMemory * 100

      local t = os.time() % 24000
      local h, m = math.floor(t / 1000 + 6) % 24, math.floor((t % 1000) / 1000 * 60)

      console:setTitle("" .. 
      "TPS:" .. tostring(tps) .. 
      " Mem:" .. string.format("%.2f", memory) .. "%" .. 
      " Time:" .. string.format("%02d:%02d", h, m) .. 
      " Net:" .. tostring(netMsgPerSecond) .. "msg/s")

    end
  end
end




-- Sleeps until the time is over and collects all signals during this time
local function Sleep(sec)
  local evts, deadline = {}, computer.uptime() + (sec or 0)
  repeat
    local left = deadline - computer.uptime()
    if left <= 0 then break end
    local e = {computer.pullSignal(left)}
    if e[1] then evts[#evts+1] = e end
  until computer.uptime() >= deadline
  return evts
end