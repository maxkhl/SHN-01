-- Returns the visual length of a string (luas # returns bytes - doesnt work with multi-byte characters)
function visualLength(s)
  local _, count = tostring(s):gsub("[%z\1-\127\194-\244][\128-\191]*", "")
  return count
end

-- Stops the computer entirely without any way of coming back
function computer.stop()
  print("Computer stopped!")
  while true do computer.pullSignal() end
end

crypto = {}

-- Generates a unique ID based on the current time, uptime, and a random number
function crypto.sessionID()
  local nano = computer.uptime() -- floating point uptime
  math.randomseed(os.time() + computer.uptime() * 1000)
  local rand = math.random(100000, 999999)
  -- Convert to integers to avoid format issues
  local nanoInt = math.floor(nano * 1000)
  return string.format("s%x%x", nanoInt, rand)
end

-- Generates a persistent ID that is guaranteed to be unique across reboots
function crypto.uniqueID()
  local database = require("/systems/database.lua")
  local counter = database:getKey("shn01", "persistentId")
  if type(counter) ~= "number" then counter = 0 end
  
  counter = counter + 1
  database:setKey("shn01", "persistentId", counter, true)
  
  -- Linear congruential generator: produces pseudo-random but deterministic sequence
  -- Using parameters that cover all 16-bit space (a=25173, c=13849, m=2^16)
  local id = (25173 * counter + 13849) % 65536
  return string.format("%04X", id)
end

function math.levenshtein(s, t)
  local d = {}
  local len_s, len_t = #s, #t

  for i = 0, len_s do d[i] = { [0] = i } end
  for j = 0, len_t do d[0][j] = j end

  for i = 1, len_s do
    for j = 1, len_t do
      local cost = (s:sub(i, i) == t:sub(j, j)) and 0 or 1
      d[i][j] = math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost
      )
    end
  end

  return d[len_s][len_t]
end

-- Returns the gpu tier as number
function computer.gpuTier()
  local gpu = getComponent("gpu")
  if not gpu then
    error("No gpu in this computer")
    return
  end

  local maxWidth, maxHeight = gpu.maxResolution()

  if maxWidth == 160 and maxHeight == 50 then
    return 1
  elseif maxWidth == 160 and maxHeight == 100 then
    return 2
  elseif maxWidth == 320 and maxHeight == 200 then
    return 3
  else
    return nil
  end
end

-- Returns the gpus maximum amount of buffers
function computer.gpuMaxBuffer()
  local tier = computer.gpuTier()
  if tier == 1 then
    return 1
  elseif tier == 2 then
    return 2
  elseif tier == 3 then
    return 4
  end
end



--[[function debug.printCallStack()
  local level = 4
  for i = 0, 4 do
    local status, info = pcall(debug.getinfo, level, "nSl")
    if not status then
      print("[!!] Corrupted frame at level:", level)
      break  -- Critical breakpoint here
    end
    if not info then
      break
    end
    if i == 3 then print("WDQDWQDWQ") end
    print(string.format(
      "#%d: %s:%d in function '%s'",
      level,
      info.short_src or "?", 
      info.currentline or -1,
      info.name or "<anonymous>"
    ))

    level = level + 1
  end
computer.stop()
end]]--