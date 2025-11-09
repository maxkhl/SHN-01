server = {}
server.clients = {}

function server:addClient(client)
    assert(client, "No client object given")
    self.clients[client.address] = client
    print("New client registered: " .. tostring(client.address))
end

local modem = getComponent("modem")

modem.open(20)

globalEvents.onNetMessageReceived:subscribe(function(receiver, sender, port, distance, ...)
    local args = {...}
    for i=1, #args do
        print(tostring(args[i]))
    end
end)

server.protocols = {}
print("<c=0xFF00FF>Initializing hive subsystems...</c>")
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
