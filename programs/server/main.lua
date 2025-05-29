server = {}

local modem = getComponent("modem")

modem.open(20)

print("Server runnning")
globalEvents.onNetMessageReceived:subscribe(function(receiver, sender, port, distance, ...)
    local args = {...}
    for i=1, #args do
        print(tostring(args[i]))
    end
end)

server.protocols = {}

-- Initialize protocols
local fileSystem = fileSystem()
for k, v in pairs(fileSystem.list(getAbsolutePath("network/protocols"))) do
    if v:sub(-6) == ".class" then
        local protocol = new(getAbsolutePath("network/protocols/" .. v))
        if not protocol then
            error("Failed to load protocol: " .. v)
        else
            server.protocols[protocol.name] = protocol
            protocol:start()
        end
    end
end
