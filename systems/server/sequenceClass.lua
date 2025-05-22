-- Custom event handling
local sequence = {}
sequence.__index = sequence

-- Creates a new event with the given name
function sequence.new(protocol)
    local self = setmetatable({}, sequence)

    
    return self
end


return sequence
