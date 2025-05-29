-- Returns the visual length of a string (luas # returns bytes - doesnt work with multi-byte characters)
function visualLength(s)
    local _, count = tostring(s):gsub("[%z\1-\127\194-\244][\128-\191]*", "")
    return count
end

-- Stops the computer entirely without any way of coming back
function computer.stop()
    while true do computer.pullSignal() end
end

crypto = {}

-- Generates a unique ID based on the current time, uptime, and a random number
math.randomseed(os.time() + computer.uptime() * 1000)
function crypto.sessionID()
  local nano = computer.uptime()    -- floating point uptime
  local rand = math.random(100000, 999999)
  return string.format("s%x%x", nano * 1000, rand)
end

-- Generates a persistent ID that is guaranteed to be unique across reboots
function crypto.uniqueID()
    local database = require("/shn-01/database.lua")
    local id = database:get("persistentID")
    if type(id) ~= "number" then id = nil end
    if not id then
        id = 1
    else
        id = id + 1
    end
    database:set("persistentID", id)
    return string.format("u%08x", id)
end

function math.levenshtein(s, t)
  local d = {}
  local len_s, len_t = #s, #t

  for i = 0, len_s do d[i] = {[0] = i} end
  for j = 0, len_t do d[0][j] = j end

  for i = 1, len_s do
    for j = 1, len_t do
      local cost = (s:sub(i, i) == t:sub(j, j)) and 0 or 1
      d[i][j] = math.min(
        d[i - 1][j    ] + 1,
        d[i    ][j - 1] + 1,
        d[i - 1][j - 1] + cost
      )
    end
  end

  return d[len_s][len_t]
end