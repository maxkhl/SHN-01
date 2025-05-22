local server = {}

local modem = getComponent("modem")

modem.open(20)

print("Server runnning")
globalEvents.onNetMessageReceived:subscribe(function(receiver, sender, port, distance, ...)
local args = {...}
for i=1, #args do
    print(tostring(args[i]))
end
end)

return server