server = {}
server.nodes = {}

local database = require("/systems/database.lua")

-- Helper function to check if debug mode is enabled
function getDebugLevel()
    return database:getKey("shn01", "hiveDebug") or 0
end

-- Debug print that only shows when debug mode is on
function debugPrint(msg, node, level)
    if level == nil then level = 1 end
    if getDebugLevel() >= level then
        local nodePrefix = node and node.shortName and ("<c=0xFFFFFF>[" .. node.shortName .. "]</c>") or ""
        print(nodePrefix .. "<c=0xFFFF00>[DEBUG]</c> " .. tostring(msg))
    end
end

function server:connectNode(nodeId, address)
    assert(nodeId, "No node ID given")
    assert(address, "No remote address given")
    
    -- Load node data from database using global helper
    local nodes = getNodes()
    local databaseData = nil
    
    if nodes then
        for _, dbNode in ipairs(nodes) do
            if type(dbNode) == "table" and dbNode.id == nodeId then
                databaseData = dbNode
                break
            elseif type(dbNode) == "string" and dbNode == nodeId then
                -- Support old string format - convert to table
                databaseData = {
                    id = dbNode,
                    script = nil,
                    defective = false,
                    lastError = nil
                }
                break
            end
        end
    end
    
    if not databaseData then
        debugPrint("Node " .. nodeId .. " not found in database")
        return nil
    end
    
    -- Check if node is defective
    if databaseData.defective then
        debugPrint("Node " .. nodeId .. " is marked as defective")
        return nil
    end
    
    -- Check for duplicate connection (same node, different address)
    for addr, existingNode in pairs(self.nodes) do
        if existingNode.id == nodeId and addr ~= address then
            debugPrint("Node " .. nodeId .. " already connected at different address")
            return nil
        end
    end
    
    -- Create and store node object
    local nodeObj = new(getAbsolutePath("network/node.class"), address, nodeId, databaseData)
    self.nodes[address] = nodeObj
    print("<c=0xFFFFFF>[" .. nodeObj.shortName .. "]</c> <c=0x00AAFF>Connected</c> as <c=0xFFFFFF>" .. nodeId .. "</c> from <c=0xFFFFFF>" .. address .. "</c>")
    
    return nodeObj
end

local modem = getComponent("modem")

modem.open(20)

server.protocols = {}
print("<c=0xFF00FF>Initializing subsystems...</c>")

-- Makes sure we have a valid hiveId and provides commands around it
local hiveId = database:getKey("shn01", "hiveId")
server.id = hiveId

-- Generates a readable, cyberpunk-themed UID with semantic components
-- Format: SHN-[HANDLE]#[NODE] (e.g., SHN-NEXUS#u00000001)
local function generateHiveId()
    local prefixes = {"NEXUS", "APEX", "PRIME", "SHADOW", "RAVEN", "VORTEX", "SYNTH", "NEON", "PULSE", "CIPHER"}
    local handle = prefixes[math.random(#prefixes)]
    
    -- Generate random 8-char hex node ID
    local node = ""
    for i = 1, 8 do
        node = node .. string.format("%x", math.random(0, 15))
    end
    
    return "SHN-" .. handle .. "#" .. node
end

if not hiveId then
    hiveId = generateHiveId()
    database:setKey("shn01", "hiveId", hiveId, true)
    console:log("<c=0xFF00FF>Generated new Hive ID:</c> <c=0xFFFFFF>" .. hiveId .. "</c>")
else
    console:log("<c=0xFF00FF>Hive ID:</c> <c=0xFFFFFF>" .. hiveId .. "</c>")
end

-- Global function to get hive ID
function getHiveId()
    return hiveId
end

-- Node management

function getNodes()
    return database:getKey("shn01", "nodes")
end

-- Broadcast server restart to all nodes
local nodes = getNodes()
if nodes and #nodes > 0 then
    print("<c=0xFF00FF>Broadcasting server restart to all registered nodes...</c>")
    for _, nodeData in pairs(nodes) do
        local nodeId = type(nodeData) == "table" and nodeData.id or nodeData
        -- Broadcast on GATE port (2011) to trigger node restarts
        modem.broadcast(2011, "SERVER_RESTART", getHiveId())
    end
end

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

local function listNodes()
    local nodes = getNodes()
    for _, nodeData in pairs(nodes or {}) do
        local nodeId = type(nodeData) == "table" and nodeData.id or nodeData
        console:log("<c=0xFF00FF>></c><c=0xFFFF00>" .. nodeId .. "</c>")
    end
end

console:log("<c=0xFF00FF>Restoring nodes...</c>")
listNodes()

console:addCommand("HIVE.NODE.LIST", "Lists all nodes in the hive", function()
    listNodes()
end)

console:addCommand("HIVE.NODE.REMOVE", "Removes a node from the hive (Node ID as a parameter)", function(nodeId)
    local nodes = getNodes()
    if not nodes then
        console:log("<c=0xFF0000>No nodes to remove from</c>")
        return
    end
    if nodeId == nil or nodeId == "" then
        console:log("<c=0xFF0000>No node ID provided</c>")
        return
    end
    console:log("Removing node <c=0xFFFF00>" .. nodeId .. "</c>...")
    local found = false
    for index, existingNode in pairs(nodes) do
        local existingId = type(existingNode) == "table" and existingNode.id or existingNode
        if existingId == nodeId then
            table.remove(nodes, index)
            found = true
            break
        end
    end
    if found then
        database:setKey("shn01", "nodes", nodes, true)
        console:log("Node <c=0xFFFF00>" .. nodeId .. "</c> removed successfully")
    else
        console:log("<c=0xFF0000>Node </c><c=0xFFFF00>" .. nodeId .. "</c><c=0xFF0000> not found</c>")
    end
end)

console:addCommand("HIVE.NODE.WIPE", "Removes all nodes from the hive", function()
    database:setKey("shn01", "nodes", {}, true)
    console:log("All nodes wiped")
end)

console:addCommand("HIVE.QUEUE.SETRATE", "Set the outbound message queue rate limit (messages per second)", function(rate)
    if not rate or rate == "" then
        local currentRate = database:getKey("shn01", "queueRateLimit") or 10
        console:log("Current queue rate limit: <c=0xFFFF00>" .. currentRate .. "</c> messages/second")
        return
    end
    
    local rateNum = tonumber(rate)
    if not rateNum or rateNum < 1 or rateNum > 1000 then
        console:logError("Invalid rate limit. Must be between 1 and 1000 messages/second")
        return
    end
    
    database:setKey("shn01", "queueRateLimit", rateNum, true)
    console:log("<c=0x00FF00>Queue rate limit set to <c=0xFFFF00>" .. rateNum .. "</c> messages/second</c>")
end)

console:addCommand("HIVE.QUEUE.STATUS", "Show outbound message queue status", function()
    local outboundQueue = require("network/messages/outboundQueue")
    local highCount = #outboundQueue.highPriorityQueue
    local lowCount = #outboundQueue.lowPriorityQueue
    local totalCount = highCount + lowCount
    local rateLimit = database:getKey("shn01", "queueRateLimit") or 10
    local droppedCount = outboundQueue.droppedCount
    
    console:log("<c=0xFF00FF>========== QUEUE STATUS ==========</c>")
    console:log("Rate limit: <c=0xFFFF00>" .. rateLimit .. "</c> messages/second")
    console:log("Queue capacity: <c=0xFFFF00>" .. outboundQueue.maxCapacity .. "</c> messages")
    console:log("")
    console:log("High priority queue: <c=0xFFFF00>" .. highCount .. "</c> messages")
    console:log("Low priority queue: <c=0xFFFF00>" .. lowCount .. "</c> messages")
    console:log("Total queued: <c=0xFFFF00>" .. totalCount .. "</c> / <c=0xFFFF00>" .. outboundQueue.maxCapacity .. "</c>")
    console:log("")
    
    if droppedCount > 0 then
        console:log("Dropped messages: <c=0xFF0000>" .. droppedCount .. "</c>")
    else
        console:log("Dropped messages: <c=0x00FF00>0</c>")
    end
    
    local utilization = (totalCount / outboundQueue.maxCapacity) * 100
    local statusColor = "0x00FF00"
    if utilization > 75 then
        statusColor = "0xFF0000"
    elseif utilization > 50 then
        statusColor = "0xFFFF00"
    end
    console:log("Capacity utilization: <c=" .. statusColor .. ">" .. string.format("%.1f", utilization) .. "%</c>")
end)


-- Generates a node UID for secondary nodes
-- Format: [HIVEID]-[UNIQUEID] (e.g., SHN-u00000001)
local function nodeUID()
  return string.format("%s-%s", getHiveId(), crypto.uniqueID())
end

console:addCommand("HIVE.NODE.ADD", "Adds a new node to the hive\nParameters:\n1 Node name\n2 Script filename (in node-scripts/ folder)", function(name, scriptFilename)
    local nodes = getNodes()
    if not nodes then
        nodes = {}
    end
    
    local nodeId
    if name == nil or name == "" then
        nodeId = nodeUID()
        console:log("<c=0xFFFF00>No node name provided, generated: " .. nodeId .. "</c>")
    else
        -- Check for invalid characters
        if string.match(name, "[^A-Za-z0-9%-]") then
            console:log("<c=0xFF0000>Invalid characters in node name. Only letters, numbers, and minus (-) allowed.</c>")
            return
        end
        -- Uppercase and format
        name = string.upper(name)
        nodeId = string.format("%s-%s", getHiveId(), name)
    end
    
    -- Validate script file exists if provided
    if scriptFilename and scriptFilename ~= "" then
        local scriptPath = getAbsolutePath("node-scripts/" .. scriptFilename)
        local fs = fileSystem()
        if not fs.exists(scriptPath) then
            console:log("<c=0xFF0000>Script file not found: " .. scriptPath .. "</c>")
            return
        end
    end
    
    console:log("Spawning node <c=0xFFFF00>" .. nodeId .. "</c>...")
    
    -- Check if node already exists
    for _, existingNode in pairs(nodes) do
        local existingId = type(existingNode) == "table" and existingNode.id or existingNode
        if existingId == nodeId then
            console:log("<c=0xFF0000>Node </c><c=0xFFFF00>" .. nodeId .. "</c><c=0xFF0000> already exists</c>")
            return
        end
    end
    
    -- Create node entry with new table structure
    local nodeEntry = {
        id = nodeId,
        script = scriptFilename,
        defective = false,
        lastError = nil
    }
    
    table.insert(nodes, nodeEntry)
    database:setKey("shn01", "nodes", nodes, true)
    
    if scriptFilename then
        console:log("Node <c=0x00FF00>" .. nodeId .. "</c> created successfully with script <c=0xFFFF00>" .. scriptFilename .. "</c>")
    else
        console:log("Node <c=0x00FF00>" .. nodeId .. "</c> created successfully (no script)")
    end
end)

console:addCommand("HIVE.NODE.RESTART", "Restarts a specific node (Node ID as parameter)", function(nodeId)
    if not nodeId or nodeId == "" then
        console:logError("No node ID provided")
        return
    end
    
    -- Find node in connected nodes
    local nodeFound = false
    for address, node in pairs(server.nodes) do
        if node.id == nodeId then
            nodeFound = true
            console:log("Sending restart command to node <c=0xFFFF00>" .. nodeId .. "</c> at " .. address .. "...")
            
            -- Send fire-and-forget restart message via GATE protocol (port 2011)
            local modem = getComponent("modem")
            modem.send(address, 2011, "RESTART", nodeId)
            
            console:log("Restart command sent")
            return
        end
    end
    
    if not nodeFound then
        console:log("<c=0xFF0000>Node " .. nodeId .. " is not currently connected</c>")
    end
end)

-- Helper function to check if a node is connected
function server:isNodeConnected(remoteAddress)
    return self.nodes[remoteAddress] ~= nil
end

-- Global function to check node connection by ID
function isNodeConnectedById(nodeId)
    for address, node in pairs(server.nodes) do
        if node.id == nodeId then
            return true, address
        end
    end
    return false, nil
end

console:addCommand("HIVE.DEBUG", "Set debug level (0=off, 1=basic, 2=advanced)", function(mode)
    if not mode or mode == "" then
        local current = database:getKey("shn01", "hiveDebug") or 0
        console:log("Current debug level: " .. tostring(current))
        return
    end
    
    local level = tonumber(mode)
    if level == nil or level < 0 or level > 2 then
        console:logError("Invalid debug level. Use 0 (off), 1 (basic), or 2 (advanced)")
        return
    end
    
    database:setKey("shn01", "hiveDebug", level, true)
    local levelNames = {[0] = "disabled", [1] = "basic", [2] = "advanced"}
    console:log("<c=0x00FF00>Debug level set to " .. level .. " (" .. levelNames[level] .. ")</c>")
end)

console:addCommand("HIVE.NODE.STATUS", "Shows detailed status of all nodes", function()
    local nodes = getNodes()
    if not nodes or #nodes == 0 then
        console:log("<c=0xFF0000>No nodes registered</c>")
        return
    end
    
    console:log("<c=0xFF00FF>========== NODE STATUS ==========</c>")
    
    for _, nodeData in pairs(nodes) do
        local nodeId = type(nodeData) == "table" and nodeData.id or nodeData
        local script = type(nodeData) == "table" and nodeData.script or nil
        local defective = type(nodeData) == "table" and nodeData.defective or false
        local lastError = type(nodeData) == "table" and nodeData.lastError or nil
        
        -- Check if node is connected
        local connected = false
        local address = nil
        local lastSeen = nil
        local bootstrapped = false
        local bootstrapTime = nil
        
        for addr, node in pairs(server.nodes) do
            if node.id == nodeId then
                connected = true
                address = addr
                lastSeen = node.lastSeen
                bootstrapped = node.bootstrapped
                bootstrapTime = node.bootstrapTime
                break
            end
        end
        
        -- Display node info
        console:log("<c=0xFFFF00>" .. nodeId .. "</c>")
        
        if connected then
            console:log("  Status: <c=0x00FF00>(connected)</c>")
            console:log("  Address: " .. tostring(address))
            if lastSeen then
                local timeSince = computer.uptime() - lastSeen
                console:log("  Last seen: " .. timeSince .. "s ago")
            end
            if bootstrapped and bootstrapTime then
                console:log("  Bootstrapped: " .. os.date("%Y-%m-%d %H:%M:%S", bootstrapTime))
            elseif bootstrapped then
                console:log("  Bootstrapped: yes")
            else
                console:log("  Bootstrapped: <c=0xFFFF00>pending</c>")
            end
        elseif defective then
            console:log("  Status: <c=0xFF0000>(defective)</c>")
        else
            console:log("  Status: <c=0xFF0000>(disconnected)</c>")
        end
        
        if script then
            console:log("  Script: " .. script)
        end
        
        if lastError then
            console:log("  Last error: <c=0xFF0000>" .. lastError .. "</c>")
        end
        
        console:log("")
    end
    
    console:log("<c=0xFF00FF>Total: " .. #nodes .. " nodes (" .. 
        #server.nodes .. " connected)</c>")
end)

console:addCommand("HIVE.NODE.RESET.DEFECTIVE", "Clears the defective flag for a node, allowing it to reconnect\nParameters:\n1 Node ID", function(nodeId)
    if not nodeId or nodeId == "" then
        console:logError("No node ID provided")
        return
    end
    
    -- Load nodes from database
    local nodes = getNodes()
    if not nodes or #nodes == 0 then
        console:logError("No nodes registered in database")
        return
    end
    
    -- Find node in database
    local nodeFound = false
    for i, nodeData in ipairs(nodes) do
        local nId = type(nodeData) == "table" and nodeData.id or nodeData
        if nId == nodeId then
            nodeFound = true
            
            -- Check if node is defective
            if type(nodeData) == "table" and nodeData.defective then
                -- Clear defective flag
                nodeData.defective = false
                nodeData.lastError = nil
                
                -- Save updated node list to database
                database:setKey("shn01", "nodes", nodes, true)
                
                console:log("<c=0x00FF00>Node " .. nodeId .. " defective flag cleared</c>")
                console:log("Node can now reconnect to the hive")
            else
                console:log("<c=0xFFFF00>Node " .. nodeId .. " is not marked as defective</c>")
            end
            break
        end
    end
    
    if not nodeFound then
        console:logError("Node " .. nodeId .. " not found in database")
    end
end)

-- Periodic cleanup of stale node connections
local lastCleanup = computer.uptime()
globalEvents.onTick:subscribe(function()
    if computer.uptime() - lastCleanup >= 30 then
        lastCleanup = computer.uptime()
        local staleNodes = {}
        
        local nodeCount = 0
        for _ in pairs(server.nodes) do nodeCount = nodeCount + 1 end
        debugPrint("Checking <c=0xFFFFFF>" .. tostring(nodeCount) .. "</c> connected nodes for timeout...")
        
        -- Check all sessions for timeouts across all protocols and sequences
        if server and server.protocols then
            for _, protocol in pairs(server.protocols) do
                for _, sequence in pairs(protocol.sequences) do
                    sequence:checkTimeouts()
                end
            end
        end
        
        for address, node in pairs(server.nodes) do
            local timeSinceLastSeen = computer.uptime() - node.lastSeen
            debugPrint("Last seen <c=0xFFFFFF>" .. string.format("%.1f", timeSinceLastSeen) .. "s</c> ago (timeout at <c=0xFFFFFF>90s</c>)", node)
            
            if node:isStale(90) then
                table.insert(staleNodes, node)
            end
        end
        
        for _, stale in ipairs(staleNodes) do
            console:log("<c=0xFFFFFF>[" .. stale.shortName .. "]</c> <c=0xFF0000>Disconnected</c> <c=0xFF0000>(timeout)</c>")
            -- Notify the node about timeout so it can reconnect
            local modem = getComponent("modem")
            if modem then
                modem.send(stale.address, 2011, "timeout", stale.id)
            end
            -- Use node:remove() to clean up (this will also clear all sessions)
            local node = server.nodes[stale.address]
            if node then
                node:remove()
            end
        end
    end
end)


return server