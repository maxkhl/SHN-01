
include("../network.lua")

-- The main update loop
while true do
    local e = {computer.pullSignal(0.05)}
    if e[1] then
        if e[1] == "modem_message" then
            
        end
    end
end