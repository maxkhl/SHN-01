
crypto = {}

-- Adler-32 checksum implementation in Lua
-- A compact version suitable for embedded use
function crypto.adler32(s)
    local prime = 65521
    local s1, s2 = 1, 0
    for i = 1, #s do
        s1 = s1 + s:byte(i)
        s2 = s2 + s1
    end
    s1 = s1 % prime
    s2 = s2 % prime
    return (s2 << 16) + s1
end

-- Generates a persistent ID that is guaranteed to be unique across reboots
function crypto.uniqueID()
  local counter = database:getKey("shn01", "persistentId")
  if type(counter) ~= "number" then counter = 0 end
  
  counter = counter + 1
  database:setKey("shn01", "persistentId", counter, true)
  
  -- Linear congruential generator: produces pseudo-random but deterministic sequence
  -- Using parameters that cover all 16-bit space (a=25173, c=13849, m=2^16)
  local id = (25173 * counter + 13849) % 65536
  return string.format("%04X", id)
end