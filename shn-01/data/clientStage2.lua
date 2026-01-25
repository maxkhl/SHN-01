-- Stage 2 Client - Full networking capabilities
-- This script is downloaded to RAM after Stage 1 handshake completes
-- Provides heartbeat, session management, error handling, and bootstrap

print("Stage 2 Client initializing...")

-- Audible sequences for status reporting
local bSeq = {
  success = { {1600, 0.15}, {20, 0.1}, {1200, 0.3} },
  err = { {420, 0.25}, {220, 0.5} },
  warn = { {580, 0.4}, {580, 0.3} },
  conn = { {600, 0.1}, {20, 0.05}, {900, 0.1}, {20, 0.05}, {1200, 0.2} },
  disc = { {1000, 0.1}, {20, 0.07}, {650, 0.15}, {20, 0.07}, {300, 0.4} },
  crit = { {2000, 0.08}, {180, 0.3}, {180, 0.3}, {80, 0.6} }
}

include("../core/boot/file.lua")
include("../core/boot/include.lua")
include("../core/boot/oop.lua")

-- Beeps in the given sequence
function beepSeq(sequence)
  for i, v in pairs(sequence) do computer.beep(v[1], v[2]) end
end

-- Heartbeat configuration
local heartbeatPort = 2022  -- ECHO protocol
local corePort = 2015       -- CORE protocol
local heartbeatInterval = 30
local lastHeartbeat = 0
local heartbeatSessionId = nil
local sessionRegistry = {}

-- Error tracking for auto-restart
local errorCount = 0
local errorWindow = 30  -- 30 second window
local lastErrorTime = 0

-- Open heartbeat and core ports
if not mdm.isOpen(heartbeatPort) then mdm.open(heartbeatPort) end
if not mdm.isOpen(corePort) then mdm.open(corePort) end

-- Enhanced error handler with restart logic
function criticalError(msg)
  beepSeq(bSeq.crit)
  send(corePort, "ERROR", nil, tostring(msg))
  
  local now = computer.uptime()
  if now - lastErrorTime > errorWindow then
    errorCount = 1
  else
    errorCount = errorCount + 1
  end
  lastErrorTime = now
  
  -- Reboot after 3 errors in 30 seconds
  if errorCount >= 3 then
    computer.shutdown(true)
  end
end

-- Debug message sender
function debug(msg)
  send(corePort, "debug", nil, "info", tostring(msg))
end

-- Runs code in the provided environment
function run(code, environment)
  local data, err = load(code, nil, nil, environment)
  if not data then
    criticalError("Failed to compile " .. string.sub(code, 1, 20) .. ": " .. tostring(err))
  end
  if data then
    return data()
  end
end



beepSeq(bSeq.success)
debug("Node <c=0xFFFFFF>" .. tostring(node.id) .. "</c> operational.")

print("Stage 2 ready and taking over...")

local heartbeatSessionId = nil
-- Main heartbeat and message handling loop
while true do
  -- Send heartbeat if connected
  if hive.address then
    local now = computer.uptime()
    if now - lastHeartbeat >= heartbeatInterval then
      mdm.send(hive.address, heartbeatPort, "HEARTBEAT", heartbeatSessionId, node.id)
      lastHeartbeat = now
    end
  end
  
  local events = sleep(1.0)
  for _, event in ipairs(events) do
    if event[1] == "modem_message" then
      local _, locAddr, remAddr, port, dist, sequence, sessionid, command, d0, d1, d2, d3 = table.unpack(event)
      
      if remAddr ~= node.address then
        -- Handle various server commands
        if sequence == "SESSION_CREATED" then
          
        elseif sequence == "SERVER_RESTART" then
          -- Server restarting, reset connection
          beepSeq(bSeq.disc)
          computer.shutdown(true)  -- Reboot to re-download Stage 2
          
        elseif command == "RESTART" and d0 == node.id then
          -- Direct restart command
          beepSeq(bSeq.disc)
          computer.shutdown(true)
          
        elseif command == "TIMEOUT" and d0 == node.id then
          -- Server timed us out, reboot to reconnect
          beepSeq(bSeq.warn)
          computer.shutdown(true)
          
        elseif sequence == "HEARTBEAT" and command == "HEARTBEAT_ACK" then
          -- Heartbeat acknowledged, connection healthy
          heartbeatSessionId = sessionid
          
        elseif command == "run" and d0 == node.id then
          -- Execute code sent from server
          local code = d1
          local success, result = pcall(run, code, _G)
          if not success then
            criticalError("Run failed: " .. tostring(result))
          end
        else
          print("UknwCom port=" .. tostring(port) .. " seq=" .. tostring(sequence) .. " sid=" .. tostring(sessionid) .. " com=" .. tostring(command) .. " d0=" .. tostring(d0) .. " d1=" .. tostring(d1) .. " d2=" .. tostring(d2) .. " d3=" .. tostring(d3))
        end        
      end
    end
  end
end
