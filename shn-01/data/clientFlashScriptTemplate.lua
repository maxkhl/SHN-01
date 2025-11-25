-- This script is injected into client nodes to allow communication with the hive
-- It is minified and compressed before being flashed to an EEPROM

-- This identifies the hive that flashed this node
local hiveId = "<--HIVEID-->"
-- This identifies the node to the hive
local nodeId = "<--NODEID-->"

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
while mdm == nil do
  beepSeq(bSeq.critical)
  mdm = getComp("modem")
end

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

function findHive()
  -- Try to find the hive by broadcasting a handshake
  mdm.broadcast(prot.port, "handshake", nodeId, hiveId)
end

-- Sends a message to the hive
function b.Send(port, comm, ...)
  if b.serverAdr then
    if not mdm.send(b.serverAdr, prot.port, comm, d0, d1, d2, d3) then
      b.Error("Send:" .. comm .. d0)
    end
  end
end

function handShake()
    -- Placeholder for handshake logic
end