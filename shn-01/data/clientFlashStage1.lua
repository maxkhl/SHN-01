-- Stage 1 EEPROM - Minimal bootstrap loader
-- This script handles handshake and Stage 2 download only
-- All advanced features are loaded in Stage 2

-- Hive and node identification (replaced during flash)
hive = { id = "__HIVEID__", address = nil }
node = { id = "__NODEID__", address = nil }

adler32 = include("/shn-01/adler32.lua")

-- Ports for communication
gatePort = 2011  -- GATE protocol (handshake)
filePort = 2031  -- FILE protocol (transmit)
corePort = 2015  -- FILE protocol (transmit)

-- Component discovery helper
function getComp(name)
  for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

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

-- Initialize modem
mdm, node.address = getComp("modem")
while mdm == nil do
  computer.beep(2000, 0.5)  -- Critical beep if no modem
  sleep(1)
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
  send(corePort, "ERROR", nil, tostring(msg))
  print("Critical Error: " .. tostring(msg))
  sleep(2)
  computer.shutdown(true)  -- Reboot
end

-- Handshake function
function handshake()
  mdm.broadcast(gatePort, "handshake", nil, node.id, hive.id)
  print("Sent handshake broadcast")
end

-- Process transmit packet
function handleTransmitPacket(sequence, sessionid,seqNum, totalPackets, checksum, data)
  -- Initialize buffer on first packet
  if seqNum == 1 then
    stage2Buffer = {}
    stage2Total = totalPackets
  end
  
  if adler32.run(data) ~= checksum then
    print("Packet " .. seqNum .. " checksum mismatch! Expected: " .. checksum .. ", Got: " .. adler32.run(data))
    -- Don't ACK corrupted packets - server will retransmit
    return
  end

  -- Store packet
  stage2Buffer[seqNum] = data
  
  -- Send ACK
  send(filePort, sequence, sessionid, "TRANSMIT_ACK", seqNum)
end

-- Process transmit complete
function handleTransmitComplete(sequence, sessionid, totalPackets, checksumExpected)
  -- Reassemble and clear buffer
  local content = table.concat(stage2Buffer, "", 1, totalPackets)
  stage2Buffer, stage2Total, stage2Retries = {}, 0, 0
  
  -- Load and execute Stage 2
  local stage2Func, err = load(content, "stage2", "t", _G)
  if not stage2Func then
    criticalError("Stage 2 compile failed: " .. tostring(err))
  end
  
  print("Stage 2 compiled successfully, executing...")
  local success, result = pcall(stage2Func)
  if not success then
    criticalError("Stage 2 execution failed: " .. tostring(result))
  end
  
  return true
end

-- Connection state
local connected = false
local lastHandshake = 0

lastHandshake = -9999999  -- Force immediate handshake on start
-- Main loop
while true do

    local events = sleep(1.0)

    -- Send handshake if not connected (throttled to avoid spam)
    if not connected then
        local now = computer.uptime()
        if now - lastHandshake >= 20 then
            handshake()
            lastHandshake = now
        end
    end

    for _, event in ipairs(events) do
        if event[1] == "modem_message" then
            local _, locAddr, remAddr, port, dist, sequence, sessionid, command, d0, d1, d2, d3 = table.unpack(event)
            command = string.upper(command or "")
            
            -- Ignore messages from self and only process messages from the hive (after connection)
            if remAddr == node.address then
                goto continue
            end
            
            -- After connection, only accept messages from the hive
            if connected and hive.address and remAddr ~= hive.address then
                goto continue
            end
            
            if command == "HANDSHAKE_ACK" and d0 == node.id and d1 == hive.id then
                -- Handshake successful
                hive.address = remAddr
                connected = true
                print("Connected!")
                print("Requesting Stage 2...")
                computer.beep(600, 0.1)
                computer.beep(900, 0.1)
                computer.beep(1200, 0.2)
                -- Server will now send Stage 2                
                send(port, sequence, sessionid, "STAGE2_REQUEST")
                
            elseif command == "TRANSMIT_PACKET" then
                -- Receiving Stage 2 file packet
                local seqNum = d0
                local totalPackets = d1
                local checksum = d2
                local data = d3
                print("Received packet " .. seqNum .. " of " .. totalPackets)
                handleTransmitPacket(sequence, sessionid, seqNum, totalPackets, checksum, data)
                
            elseif command == "TRANSMIT_COMPLETE" then
                -- Stage 2 transmission complete
                local totalPackets = d0
                local checksum = d1
                if handleTransmitComplete(totalPackets, checksum) then
                  -- Stage 2 loaded successfully, it takes over from here
                  print("Starting Stage 2...")
                  break
                end
                
            elseif command == "RESTART" and d0 == node.id then
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
