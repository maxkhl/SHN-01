-- This script is injected into client nodes to allow communication with the hive
-- It is minified and compressed before being flashed to an EEPROM

-- This identifies the hive that flashed this node
local hive = { id = "SHN-NEXUS-CEB7", address = nil }
-- This identifies the node to the hive
local node = { id = "SHN-NEXUS-CEB7-SOLAR", address = nil }
-- The port to use for broadcasting
local broadcastPort = 2011
-- The port to use for bounced messages
local bouncePort = 2022
-- Update frequency in seconds
local uFreq = 1.0
-- Bootstrap mode flag. Indicates if the node is in initial setup phase
local bootstrap = true

-- Global function to load components without any hassle
function getComp(name)
  for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

-- Audible sequences for status reporting on any type of hardware (see beepSeq(sequence))
local bSeq = {
  success = { -- "Up then confirm" (3 notes → 2 tones)
    {1600, 0.15}, {20, 0.1}, 
    {1200, 0.3}  -- High start resolves lower
  },
  err = { -- "Error blurt" (2 tones)
    {420, 0.25}, {220, 0.5}  -- Dissonant minor 9th interval
  },
  warn = { -- "Slow pulse" (1 tone modulated)
    {580, 0.4}, {580, 0.3}  -- Same freq, varied duration
  },
  conn = { -- "Stepped climb" (3 tones)
    {600, 0.1}, {20, 0.05},
    {900, 0.1}, {20, 0.05},
    {1200, 0.2}  -- Bigger jumps than original
  },
  disc = { -- "Falling crash" (3 tones)
    {1000, 0.1}, {20, 0.07},
    {650, 0.15}, {20, 0.07},
    {300, 0.4}  -- Deeper fall endpoint
  },
  crit = { -- "Alert then rumble" (4 notes)
    {2000, 0.08},  -- High attention grab
    {180, 0.3}, {180, 0.3}, 
    {80, 0.6}  -- Sub-bass endpoint
  }
}
-- beeps in the given sequence (list with freq and time) - see sequences (f.e. beepSequence(sequences.success))
function beepSeq(sequence)
  for i, v in pairs(sequence) do computer.beep(v[1], v[2]) end
end

-- Keep beeping until someone adds a modem
mdm, node.address = getComp("modem")
while mdm == nil do
  beepSeq(bSeq.critical)
  mdm, node.address = getComp("modem")
end

if not mdm.isOpen(broadcastPort) then mdm.open(broadcastPort) end

-- Runs the given code in the provided environment
function run(code, environment)
    local data, err = load(injected, nil, nil, environment)
    if not data then
        error("Failed to compile " .. string.sub(code, 1, 20) .. ": " .. tostring(err))
    end

    if data then
        return data()
    end
end

function callHive()
  -- Try to find the hive by broadcasting a handshake
  mdm.broadcast(broadcastPort, "handshake", node.id, hive.id)
end

-- Handles critical errors by beeping and sending an error message to the hive
function error(msg)
  -- Beep critical error sequence
  beepSeq(bSeq.crit)
  -- Send error message to hive
  send(bouncePort, "ERROR", tostring(msg))
end

-- Sends debug info to the hive
function debug(msg)
  -- Send debug info to hive
  send(bouncePort, "INFO", tostring(msg))
end

-- Sends a message to the hive
function send(port, comm, ...)
  if hive.address then
    if not mdm.send(hive.address, port, comm, d0, d1, d2, d3) then
      error("Send:" .. comm .. d0)
    end
  end
end

function handShake()
    -- Placeholder for handshake logic
end

-- Sleeps until the time is over and collects all signals during this time
local function sleep(sec)
  local evts, deadline = {}, computer.uptime() + (sec or 0)
  repeat
    local left = deadline - computer.uptime()
    if left <= 0 then break end
    local e = {computer.pullSignal(left)}
    if e[1] then evts[#evts+1] = e end
  until computer.uptime() >= deadline
  return evts
end

-- The main update loop
while true do
  -- Placeholder for main loop logic  
  if not b.serverAdr then mdm.broadcast(b.prot.net.port, b.com.H, b.name) end
  for _, e in ipairs(sleep(uFreq)) do
    local signal, locAddr, remAddr, port, dist, command, d0, d1, d2, d3 = table.unpack(e)
    if signal == "modem_message" and remAddr ~= node.address then
      if bootstrap then
        if command == "handshake_ack" and d0 == node.id and d1 == hive.id then
          hive.address = remAddr
          bootstrap = false
          beepSeq(bSeq.conn)
        end
      else
        -- Handle other messages when not in bootstrap mode
      end

    end
  end
end