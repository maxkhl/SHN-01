server = {}
server.nodes = {}

local database = require("/systems/database.lua")

function server:connectNode(node)
    assert(node, "No node object given")
    self.nodes[node.address] = node
    print("New node registered: " .. tostring(node.address))
end

local modem = getComponent("modem")

modem.open(20)

server.protocols = {}
print("<c=0xFF00FF>Initializing subsystems...</c>")
-- Initialize protocols
local fileSystem = fileSystem()
for k, v in pairs(fileSystem.list(getAbsolutePath("network/protocols"))) do
    if v:sub(-6) == ".class" then
        local protocol = new(getAbsolutePath("network/protocols/" .. v), server)
        if not protocol then
            error("Failed to load protocol: " .. v)
        else
            server.protocols[protocol.name] = protocol
            protocol:start()
        end
    end
end



-- Makes sure we have a valid hiveId and provides commands around it
local hiveId = database:getKey("shn01", "hiveId")

-- Generates a readable, cyberpunk-themed UID with semantic components
-- Format: SHN-[HANDLE]#[NODE] (e.g., SHN-NEXUS#u00000001)
local function mainNodeUID(customHandle)
  local handles = {
    "NEXUS", "CIPHER", "VECTOR", "ARC", "VISION", "PRISM",
    "CORE", "SIGNAL", "GRID", "NODE", "SHIFT", "LINK",
    "SYNC", "PULSE", "SURGE", "REACT", "TRACE", "NOVA",
    "ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA",
    "ETA", "THETA", "IOTA", "KAPPA", "LAMBDA", "MU",
    "NU", "XI", "OMICRON", "PI", "RHO", "SIGMA", "GATE",
    "ZERO", "MESH"
  }
  
  local handle
  if customHandle then
    handle = customHandle
  else
    -- Pick random handle
    math.randomseed(os.time() + computer.uptime() * 1000 + math.random())
    handle = handles[math.random(#handles)]
  end
  
  -- Generate hex node ID
  local node = crypto.uniqueID()
  
  return string.format("SHN-%s-%s", handle, node)
end

local function resetHiveId(customHandle)
    hiveId = mainNodeUID(customHandle)
    database:setKey("shn01", "hiveId", hiveId, true)
    console:log("New Hive ID generated: <c=0xFFFF00>" .. hiveId .. "</c>")
end

if hiveId == nil then
    resetHiveId()
else
    console:log("Hive <c=0xFFFF00>" .. hiveId .. "</c> initialized")
end

console:addCommand("HIVE.ID.SHOW", "Shows the current hive ID", function()
    console:log("Current Hive ID: <c=0xFFFF00>" .. hiveId .. "</c>")
end)

console:addCommand("HIVE.ID.RESET", "Resets the current hive ID (optional custom name parameter)", function(name)
    local nodes = getNodes()
    if nodes and #nodes > 0 then
        console:log("<c=0xFF0000>Cannot reset Hive ID while nodes are connected. Please remove all nodes first.</c>")
        return
    end
    local customHandle = nil
    if name and name ~= "" then
        -- Check for invalid characters (only letters and numbers allowed)
        if string.match(name, "[^A-Za-z0-9]") then
            console:log("<c=0xFF0000>Invalid characters in hive name. Only letters and numbers allowed.</c>")
            return
        end
        customHandle = string.upper(name)
    end
    resetHiveId(customHandle)
end)

-- Global function to get hive ID
function getHiveId()
    return hiveId
end

-- Node management

function getNodes()
    return database:getKey("shn01", "nodes")
end

local function listNodes()
    local nodes = getNodes()
    for _, nodeName in pairs(nodes or {}) do
        console:log("<c=0xFF00FF>></c><c=0xFFFF00>" .. nodeName .. "</c>")
    end
end

console:log("<c=0xFF00FF>Restoring nodes...</c>")
listNodes()

console:addCommand("HIVE.NODE.LIST", "Lists all nodes in the hive", function()
    listNodes()
end)

console:addCommand("HIVE.NODE.REMOVE", "Removes a node from the hive (Node name as a parameter)", function(name)
    local nodes = getNodes()
    if not nodes then
        console:log("<c=0xFF0000>No nodes to remove from</c>")
        return
    end
    if name == nil or name == "" then
        console:log("<c=0xFF0000>No node name provided</c>")
        return
    end
    console:log("Removing node <c=0xFFFF00>" .. name .. "</c>...")
    local found = false
    for index, existingNode in pairs(nodes) do
        if existingNode == name then
            table.remove(nodes, index)
            found = true
            break
        end
    end
    if found then
        database:setKey("shn01", "nodes", nodes, true)
        console:log("Node <c=0xFFFF00>" .. name .. "</c> removed successfully")
    else
        console:log("<c=0xFF0000>Node </c><c=0xFFFF00>" .. name .. "</c><c=0xFF0000> not found</c>")
    end
end)

console:addCommand("HIVE.NODE.WIPE", "Removes all nodes from the hive", function()
    database:setKey("shn01", "nodes", {}, true)
    console:log("All nodes wiped")
end)


-- Generates a node UID for secondary nodes
-- Format: [HIVEID]-[UNIQUEID] (e.g., SHN-u00000001)
local function nodeUID()
  return string.format("%s-%s", getHiveId(), crypto.uniqueID())
end

console:addCommand("HIVE.NODE.ADD", "Adds a new node to the hive (Node name as a parameter)", function(name)
    local nodes = getNodes()
    if not nodes then
        nodes = {}
    end
    if name == nil or name == "" then
        name = nodeUID()
        console:log("<c=0xFF0000>No node name provided</c>")
    else
        -- Check for invalid characters
        if string.match(name, "[^A-Za-z0-9%-]") then
            console:log("<c=0xFF0000>Invalid characters in node name. Only letters, numbers, and minus (-) allowed.</c>")
            return
        end
        -- Uppercase and format
        name = string.upper(name)
        name = string.format("%s-%s", getHiveId(), name)
    end
    console:log("Spawning node <c=0xFFFF00>" .. name .. "</c>...")
    for _, existingNode in pairs(nodes) do
        if existingNode == name then
            console:log("<c=0xFF0000>Node </c><c=0xFFFF00>" .. name .. "</c><c=0xFF0000> already exists</c>")
            return
        end
    end
    
    table.insert(nodes, name)
    database:setKey("shn01", "nodes", nodes, true)
    console:log("Node <c=0x00FF00>" .. name .. "</c> created successfully")

end)


return server