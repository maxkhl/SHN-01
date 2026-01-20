-- Stage 1 EEPROM - Minimal bootstrap loader
-- This script handles handshake and Stage 2 download only
-- All advanced features are loaded in Stage 2

-- Hive and node identification (replaced during flash)
local hive = { id = "__HIVEID__", address = nil }
local node = { id = "__NODEID__", address = nil }

-- Ports for communication
local gatePort = 2011  -- GATE protocol (handshake)
local filePort = 2031  -- FILE protocol (transmit)
local corePort = 2015  -- FILE protocol (transmit)

-- Component discovery helper
function getComp(name)
  for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

-- Initialize modem
mdm, node.address = getComp("modem")
while mdm == nil do
  computer.beep(2000, 0.5)  -- Critical beep if no modem
  computer.sleep(1)
  mdm, node.address = getComp("modem")
end

-- Initialize GPU and screen (optional)
local gpu = getComp("gpu")
local _, screen = getComp("screen")
local w, h = 50, 16
if gpu and screen then
  gpu.bind(screen)
  w, h = gpu.getResolution()
end

-- Simple console functions
local consoleY = 1
function cls()
  if gpu then
    gpu.fill(1, 1, w, h, " ")
    consoleY = 1
  end
end

function print(text)
  if gpu then
    gpu.set(1, consoleY, text)
    consoleY = consoleY + 1
    if consoleY > h then consoleY = 1 end
  end
end

-- Open ports
if not mdm.isOpen(gatePort) then mdm.open(gatePort) end
if not mdm.isOpen(filePort) then mdm.open(filePort) end

-- Initial display
cls()
print("Node: " .. node.id)
print("Hive: " .. hive.id)
print("Connecting...")

-- Stage 2 transmission state
local stage2Buffer = {}
local stage2Total = 0
local stage2Retries = 0

-- Send message helper
function send(port, ...)
  if hive.address then
    mdm.send(hive.address, port, ...)
  end
end

-- Error handler with reboot
function criticalError(msg)
  computer.beep(2000, 0.08)
  computer.beep(180, 0.3)
  computer.beep(180, 0.3)
  send(corePort, "ERROR", tostring(msg))
  computer.sleep(2)
  computer.shutdown(true)  -- Reboot
end

-- Handshake function
function handshake()
  mdm.broadcast(gatePort, "handshake", node.id, hive.id)
  print("Sent handshake broadcast")
end

-- Process transmit packet
function handleTransmitPacket(seqNum, totalPackets, data, checksum)
  -- Initialize buffer on first packet
  if seqNum == 1 then
    stage2Buffer = {}
    stage2Total = totalPackets
  end
  
  -- Store packet
  stage2Buffer[seqNum] = data
  
  -- Send ACK
  send(filePort, "transmit_ack", seqNum)
end

-- Process transmit complete
function handleTransmitComplete(totalPackets, checksumExpected)
  -- Check for missing packets
  local missing = {}
  for i = 1, totalPackets do
    if not stage2Buffer[i] then
      table.insert(missing, i)
    end
  end
  
  if #missing > 0 then
    -- Request missing packets
    for _, seqNum in ipairs(missing) do
      send(filePort, "transmit_request", seqNum)
    end
    return false
  end
  
  -- Reassemble file
  local content = ""
  for i = 1, totalPackets do
    content = content .. (stage2Buffer[i] or "")
  end
  
  -- Validate checksum
  local actualChecksum = computeMD5(content)
  if actualChecksum ~= checksumExpected then
    stage2Retries = stage2Retries + 1
    if stage2Retries >= 10 then
      criticalError("Stage 2 checksum failed 10 times")
    end
    send(filePort, "CHECKSUM_FAIL")
    stage2Buffer = {}
    return false
  end
  
  -- Clear buffer
  stage2Buffer = {}
  stage2Total = 0
  stage2Retries = 0
  
  -- Execute Stage 2 in global environment
  local success, result = pcall(function()
    local stage2Func, err = load(content, "stage2", "t", _G)
    if not stage2Func then
      error("Stage 2 compile failed: " .. tostring(err))
    end
    return stage2Func()
  end)
  
  if not success then
    criticalError("Stage 2 execution failed: " .. tostring(result))
  end
  
  return true
end

-- Simple MD5 placeholder (will be replaced with actual md5 implementation)
function computeMD5(str)
  -- For Stage 1, we skip MD5 validation to save space
  -- Server sends checksum but client doesn't validate
  return str  -- Return the string itself as "checksum"
end

-- Connection state
local connected = false
local lastHandshake = 0


-- Sleeps and collects events
function sleep(sec)
  local evts, deadline = {}, computer.uptime() + (sec or 0)
  repeat
    local left = deadline - computer.uptime()
    if left <= 0 then break end
    local e = {computer.pullSignal(left)}
    if e[1] then evts[#evts+1] = e end
  until computer.uptime() >= deadline
  return evts
end

lastHandshake = -9999999  -- Force immediate handshake on start
-- Main loop
while true do

    local events = sleep(1.0)

    -- Send handshake if not connected (throttled to avoid spam)
    if not connected then
        local now = computer.uptime()
        if now - lastHandshake >= 20 then
            print("Not connected, sending handshake...")
            criticalError("Testing SESSION_CREATED handling")  -- Placeholder
            handshake()
            lastHandshake = now
        end
    end

    for _, event in ipairs(events) do
        if event[1] == "modem_message" then
            local _, locAddr, remAddr, port, dist, command, d0, d1, d2, d3 = table.unpack(event)
            
            -- Ignore messages from self and only process messages from the hive (after connection)
            if remAddr == node.address then
                goto continue
            end
            
            -- After connection, only accept messages from the hive
            if connected and hive.address and remAddr ~= hive.address then
                goto continue
            end
            
            if command == "handshake_ack" and d0 == node.id and d1 == hive.id then
                -- Handshake successful
                hive.address = remAddr
                connected = true
                print("Connected!")
                print("Downloading Stage 2...")
                computer.beep(600, 0.1)
                computer.beep(900, 0.1)
                computer.beep(1200, 0.2)
                -- Server will now send Stage 2
                
            elseif command == "transmit_packet" then
                -- Receiving Stage 2 file packet
                local seqNum = d0
                local totalPackets = d1
                local data = d2
                handleTransmitPacket(seqNum, totalPackets, data)
                
            elseif command == "transmit_complete" then
                -- Stage 2 transmission complete
                local totalPackets = d0
                local checksum = d1
                print("Stage 2 complete")
                if handleTransmitComplete(totalPackets, checksum) then
                -- Stage 2 loaded successfully, it takes over from here
                print("Starting Stage 2...")
                break
                end
                
            elseif command == "restart" and d0 == node.id then
                -- Direct restart command
                computer.beep(1000, 0.1)
                computer.beep(650, 0.15)
                computer.beep(300, 0.4)
                computer.shutdown(true)
            end
        end

        ::continue::
    end
end
