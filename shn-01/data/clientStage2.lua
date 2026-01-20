-- Stage 2 Client - Full networking capabilities
-- This script is downloaded to RAM after Stage 1 handshake completes
-- Provides heartbeat, session management, error handling, and bootstrap

-- Audible sequences for status reporting
local bSeq = {
  success = { {1600, 0.15}, {20, 0.1}, {1200, 0.3} },
  err = { {420, 0.25}, {220, 0.5} },
  warn = { {580, 0.4}, {580, 0.3} },
  conn = { {600, 0.1}, {20, 0.05}, {900, 0.1}, {20, 0.05}, {1200, 0.2} },
  disc = { {1000, 0.1}, {20, 0.07}, {650, 0.15}, {20, 0.07}, {300, 0.4} },
  crit = { {2000, 0.08}, {180, 0.3}, {180, 0.3}, {80, 0.6} }
}

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
function error(msg)
  beepSeq(bSeq.crit)
  send(corePort, "ERROR", tostring(msg))
  
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
  send(corePort, "INFO", tostring(msg))
end

-- Runs code in the provided environment
function run(code, environment)
  local data, err = load(code, nil, nil, environment)
  if not data then
    error("Failed to compile " .. string.sub(code, 1, 20) .. ": " .. tostring(err))
  end
  if data then
    return data()
  end
end


-- Bootstrap request trigger
function requestBootstrap()
  send(corePort, "bootstrap", node.id)
end

-- Request bootstrap immediately
beepSeq(bSeq.success)
requestBootstrap()
debug("Testing SESSION_CREATED handling")  -- Placeholder

-- Main heartbeat and message handling loop
while true do
  -- Send heartbeat if connected
  if hive.address then
    local now = computer.uptime()
    if now - lastHeartbeat >= heartbeatInterval then
      if heartbeatSessionId then
        mdm.send(hive.address, heartbeatPort, heartbeatSessionId, "HEARTBEAT", node.id)
      else
        mdm.send(hive.address, heartbeatPort, "heartbeat", "HEARTBEAT", node.id)
      end
      lastHeartbeat = now
    end
  end
  
  for _, e in ipairs(sleep(1.0)) do
    local signal, locAddr, remAddr, port, dist, command, d0, d1, d2, d3 = table.unpack(e)
    
    if signal == "modem_message" and remAddr ~= node.address then
      -- Handle various server commands
      if command == "SESSION_CREATED" then
        -- Track session ID
        local sessionId = d0
        local sequenceName = d1
        if sequenceName == "heartbeat" then
          heartbeatSessionId = sessionId
        end
        if sequenceName then
          sessionRegistry[sequenceName] = sessionId
        end
        
      elseif command == "server_restart" and d0 == hive.id then
        -- Server restarting, reset connection
        beepSeq(bSeq.disc)
        hive.address = nil
        heartbeatSessionId = nil
        sessionRegistry = {}
        computer.shutdown(true)  -- Reboot to re-download Stage 2
        
      elseif command == "restart" and d0 == node.id then
        -- Direct restart command
        beepSeq(bSeq.disc)
        computer.shutdown(true)
        
      elseif command == "timeout" and d0 == node.id then
        -- Server timed us out, reboot to reconnect
        beepSeq(bSeq.warn)
        computer.shutdown(true)
        
      elseif command == "HEARTBEAT_ACK" and d0 == node.id then
        -- Heartbeat acknowledged, connection healthy
        
      elseif command == "run" and d0 == node.id then
        -- Execute code sent from server
        local code = d1
        local success, result = pcall(run, code, _G)
        if not success then
          error("Run failed: " .. tostring(result))
        end
      end
    end
  end
end
