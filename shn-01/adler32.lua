-- Adler-32 checksum implementation in Lua
-- A compact version suitable for embedded use
adler32 = {}
function adler32.run(s)
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
return adler32