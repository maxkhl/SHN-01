-- Returns the visual length of a string (luas # returns bytes - doesnt work with multi-byte characters)
function visualLength(s)
    local _, count = tostring(s):gsub("[%z\1-\127\194-\244][\128-\191]*", "")
    return count
end

-- Stops the computer entirely without any way of coming back
function computer.stop()
    while true do computer.pullSignal() end
end