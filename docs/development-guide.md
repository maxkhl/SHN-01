# Development Guide

This guide covers how to extend SHN-01 with custom protocols, sequences, node scripts, and console commands.

## Table of Contents

- [Creating Custom Protocols](#creating-custom-protocols)
- [Creating Custom Sequences](#creating-custom-sequences)
- [Writing Node Scripts](#writing-node-scripts)
- [Adding Console Commands](#adding-console-commands)
- [Using the Class System](#using-the-class-system)
- [Working with Events](#working-with-events)
- [Best Practices](#best-practices)

## Creating Custom Protocols

Protocols own modem ports and contain multiple sequences. Create a protocol when you need a new category of network functionality.

### Step 1: Create Protocol Class File

Create `shn-01/hive/network/protocols/myprotocol.class`:

```lua
local Protocol = {}
Protocol.__index = Protocol

function Protocol:new()
    local instance = setmetatable({}, Protocol)
    
    -- Required properties
    instance.name = "MYPROTOCOL"
    instance.port = 2050  -- Choose unused port (see Configuration docs)
    instance.description = "Custom protocol for my feature"
    instance.sequences = {}
    
    return instance
end

function Protocol:start()
    local modem = getComponent("modem")
    
    -- Open modem port
    if not modem.isOpen(self.port) then
        modem.open(self.port)
        console:log("<c=0x00FF00>Protocol " .. self.name .. " opened port " .. self.port .. "</c>")
    end
    
    -- Load sequences from manifest
    local sequenceClass = getClass("shn-01/hive/network/sequence")
    
    -- Example: Load a custom sequence
    local mySeq = sequenceClass.create(
        server,  -- hive server object
        self,    -- protocol instance
        "shn-01/hive/network/sequences/mysequence"  -- manifest path
    )
    self.sequences[mySeq.name] = mySeq
    
    -- Subscribe to network messages
    globalEvents.onNetMessageReceived:subscribe(function(localAddress, remoteAddress, port, distance, ...)
        if port == self.port then
            self:onMessage(localAddress, remoteAddress, port, distance, ...)
        end
    end)
end

function Protocol:onMessage(localAddress, remoteAddress, port, distance, ...)
    local args = {...}
    local sequenceName = args[1]
    local sessionId = args[2]
    
    -- Remove sequence name and session ID from args
    table.remove(args, 1)
    table.remove(args, 1)
    
    -- Find node by address
    local node = server.nodes[remoteAddress]
    
    if not node then
        debugPrint("Received message from unknown node: " .. remoteAddress, nil, 2)
        return
    end
    
    -- Check if node is authorized (except for initial handshake)
    if not node.authorized and sequenceName ~= "INITIAL_CONNECT" then
        debugPrint("Rejected message from unauthorized node: " .. node.id, node, 2)
        return
    end
    
    -- Find sequence
    local sequence = self.sequences[sequenceName]
    if not sequence then
        debugPrint("Unknown sequence: " .. sequenceName, node, 2)
        return
    end
    
    -- Process message through sequence
    if sessionId then
        -- Resume existing session
        sequence:process(sessionId, args)
    else
        -- Create new session
        sequence:createSession(node, args)
    end
end

return Protocol
```

### Step 2: Protocol Auto-Discovery

The hive automatically loads all `.class` files from `shn-01/hive/network/protocols/`. No additional registration needed.

On startup, the hive:
1. Scans the protocols directory
2. Instantiates each protocol with `new()`
3. Calls `protocol:start()`
4. Stores in `server.protocols[name]`

### Port Allocation Guidelines

Choose a port number that doesn't conflict with existing protocols:

- 2011 - GATE (handshake, disconnect)
- 2015 - CORE (debug, error)
- 2022 - ECHO (heartbeat)
- 2031 - FILE (transmit)
- **2050+** - Available for custom protocols

Update [configuration.md](configuration.md) when adding new ports.

## Creating Custom Sequences

Sequences define the message handling logic for protocols. Each sequence is a coroutine that processes multi-step dialogues.

### Step 1: Create Sequence Directory

Create directory structure:
```
shn-01/hive/network/sequences/mysequence/
├── manifest.lua
├── server.lua
└── client.lua (optional, for node-side implementation)
```

### Step 2: Create Manifest

Create `shn-01/hive/network/sequences/mysequence/manifest.lua`:

```lua
return {
    name = "mysequence",           -- Sequence identifier (used in messages)
    version = "1.0",               -- Version number
    server = "server.lua",         -- Server-side handler
    client = "client.lua",         -- Client-side handler (optional)
    timeout = 60,                  -- Session timeout in seconds
    sequence = true,               -- true = multi-step, false = one-shot
    description = "Custom sequence for my feature"
}
```

**Manifest properties:**
- `name` - Unique identifier (used as first message arg)
- `version` - Semantic version string
- `server` - Filename of server-side handler
- `client` - Filename of client-side handler (optional, not used by server)
- `timeout` - Session timeout in seconds (sessions older than this are removed)
- `sequence` - `true` for stateful multi-step, `false` for one-shot handlers
- `description` - Human-readable description

### Step 3: Implement Server Handler

Create `shn-01/hive/network/sequences/mysequence/server.lua`:

```lua
-- Factory function receives hive and protocol references
return function(hive, protocol)
    -- Get message class for creating responses
    local outboundClass = getClass("shn-01/hive/network/messages/outbound")
    
    -- Return the coroutine function
    return function(node, args)
        -- This function runs as a coroutine for each session
        
        -- Step 1: Process initial message
        local clientData = args[1]
        local clientValue = args[2]
        
        debugPrint("Received: " .. clientData, node, 1)
        
        -- Validate input
        if not clientData then
            local errorMsg = outboundClass:new(
                node,      -- target node
                protocol,  -- protocol instance
                nil,       -- session ID (nil for new)
                true,      -- high priority
                "ERROR",   -- first arg
                "Missing data"  -- second arg
            )
            node, args = coroutine.yield({errorMsg})
            return  -- End sequence
        end
        
        -- Process data
        local result = processData(clientData)
        
        -- Step 2: Send response and wait for acknowledgment
        local response = outboundClass:new(
            node,
            protocol,
            nil,       -- session ID managed by sequence handler
            false,     -- low priority
            "RESULT",
            result
        )
        
        -- Yield sends messages and waits for next message
        node, args = coroutine.yield({response})
        
        -- Step 3: Process acknowledgment
        local ackType = args[1]
        
        if ackType == "ACK" then
            debugPrint("Sequence completed successfully", node, 1)
        else
            debugPrint("Sequence failed: no ACK", node, 2)
        end
        
        -- Sequence complete (coroutine returns)
    end
end

-- Helper function (local to this file)
function processData(data)
    return "Processed: " .. tostring(data)
end
```

**Key patterns:**

**Yielding messages:**
```lua
node, args = coroutine.yield({msg1, msg2, msg3})
```
- Yield an array of `outbound` message objects
- Messages are sent immediately (enqueued in priority queue)
- Coroutine suspends until next message arrives
- Returns `(node, args)` when resumed

**Creating outbound messages:**
```lua
local outboundClass = getClass("shn-01/hive/network/messages/outbound")

local msg = outboundClass:new(
    node,       -- target node object
    protocol,   -- protocol instance
    nil,        -- session ID (nil = auto-assigned)
    true,       -- high priority (true/false)
    arg1,       -- first message argument
    arg2,       -- second message argument
    ...         -- additional arguments
)
```

**Infinite loops (heartbeat pattern):**
```lua
return function(node, args)
    while true do
        -- Process heartbeat
        node:updateHeartbeat()
        
        -- Send acknowledgment
        local ack = outboundClass:new(node, protocol, nil, false, "HEARTBEAT_ACK")
        node, args = coroutine.yield({ack})
        
        -- Loop continues indefinitely
        -- Timeout handled by sequence manager
    end
end
```

**Error handling:**
```lua
return function(node, args)
    -- Validate early
    if not args[1] then
        local err = outboundClass:new(node, protocol, nil, true, "ERROR", "Invalid args")
        coroutine.yield({err})
        return  -- Exit sequence
    end
    
    -- Continue processing...
end
```

### Step 4: Test the Sequence

1. **Restart hive** to load new sequence
2. **Enable debug mode**: `HIVE.DEBUG 3`
3. **Send test message from node** (or use bounce protocol for testing)
4. **Monitor console output** for debug messages
5. **Check session creation/completion**

### Example: Complete Sequence

Here's a complete example of a data query sequence:

**manifest.lua:**
```lua
return {
    name = "query",
    version = "1.0",
    server = "server.lua",
    timeout = 30,
    sequence = true,
    description = "Query-response sequence"
}
```

**server.lua:**
```lua
return function(hive, protocol)
    local outboundClass = getClass("shn-01/hive/network/messages/outbound")
    
    return function(node, args)
        local queryType = args[1]
        local queryParams = args[2]
        
        -- Validate query
        if not queryType then
            local err = outboundClass:new(node, protocol, nil, true, "QUERY_ERROR", "No query type")
            node, args = coroutine.yield({err})
            return
        end
        
        -- Process query based on type
        local result
        if queryType == "STATUS" then
            result = {
                hiveId = getHiveId(),
                nodeCount = #server.nodes,
                uptime = os.time()
            }
        elseif queryType == "NODES" then
            result = {}
            for addr, n in pairs(server.nodes) do
                table.insert(result, {id = n.id, name = n.shortName})
            end
        else
            local err = outboundClass:new(node, protocol, nil, true, "QUERY_ERROR", "Unknown query type")
            node, args = coroutine.yield({err})
            return
        end
        
        -- Send result
        local response = outboundClass:new(node, protocol, nil, false, "QUERY_RESULT", result)
        node, args = coroutine.yield({response})
        
        debugPrint("Query completed: " .. queryType, node, 1)
    end
end
```

## Writing Node Scripts

Node scripts run on client nodes after Stage 2 bootstrap completes. They execute once, then the node enters idle mode (heartbeat loop).

### Step 1: Create Script File

Create `shn-01/hive/node-scripts/MYSCRIPT.lua`:

```lua
-- Node script example: Monitor component and report to hive

-- Available globals:
-- - component: OpenComputers component API
-- - computer: Computer API
-- - os: Operating system API
-- - include(), inject(): Module loading
-- - class(), new(): OOP system

-- Get component proxies
local modem = component.proxy(component.list("modem")())

-- You can also use component.get() for partial addresses
local gpu = component.proxy(component.get("abc"))  -- matches "abc..."

-- Example: Monitor energy storage
local energyStorage = component.proxy(component.list("gt_machine")())

if energyStorage then
    while true do
        local info = energyStorage.getSensorInformation()
        local stored = info[1]
        local capacity = info[2]
        local percentage = (stored / capacity) * 100
        
        -- Print to local screen (if available)
        print(string.format("Energy: %.1f%% (%d / %d EU)", percentage, stored, capacity))
        
        -- Send to hive via custom protocol
        -- (requires corresponding server-side sequence)
        modem.broadcast(2050, "ENERGY_REPORT", nil, stored, capacity)
        
        -- Wait 60 seconds
        os.sleep(60)
    end
else
    print("No energy storage found")
end

-- Script ends, node enters heartbeat mode
```

### Step 2: Deploy Script to Node

When flashing a node, specify the script name:

```
FLASH.NODE <node-address> MYSCRIPT
```

The script name (without `.lua`) is stored in the database and sent to the node during handshake.

### Available APIs on Nodes

**OpenComputers standard library:**
- `component` - Component access
- `computer` - Computer control (beep, shutdown, reboot, etc.)
- `os` - OS functions (time, sleep, clock, date)
- `string`, `table`, `math` - Standard Lua libraries

**SHN-01 boot system (Stage 2):**
- `include(path)` - Load module in isolated environment
- `inject(path)` - Load module in global environment
- `class(path, parent)` - Define class
- `new(path, ...)` - Instantiate class
- `getClass(path)` - Get class definition

**Network messaging:**
- `modem.broadcast(port, ...)` - Send broadcast message
- `modem.send(address, port, ...)` - Send direct message

**Limitations:**
- No database access (hive-only)
- No console access (hive-only)
- No direct access to other nodes
- Limited to local components

### Script Best Practices

1. **Check component availability**
   ```lua
   local componentAddress = component.list("gt_machine")()
   if not componentAddress then
       print("Required component not found")
       return
   end
   ```

2. **Handle errors gracefully**
   ```lua
   local success, result = pcall(function()
       -- risky operation
       return component.proxy(addr).someMethod()
   end)
   
   if not success then
       print("Error: " .. tostring(result))
   end
   ```

3. **Use appropriate sleep intervals**
   - Too short: wastes CPU
   - Too long: delays response
   - Recommended: 30-60 seconds for monitoring tasks

4. **Keep scripts simple**
   - Node resources are limited (Tier 1 = 192KB RAM)
   - Avoid large data structures
   - Minimize network traffic

5. **Consider infinite vs. finite scripts**
   - Infinite loop: Script never exits (like example above)
   - Finite: Script runs once and exits
   - After exit, node enters heartbeat-only mode

## Adding Console Commands

Console commands provide interactive control of the hive system.

### Basic Command Registration

```lua
console:addCommand("MY.COMMAND", "Description of my command", function(args)
    -- args is an array of space-separated arguments
    
    if #args == 0 then
        console:logError("Usage: MY.COMMAND <arg1> <arg2>")
        return
    end
    
    local arg1 = args[1]
    local arg2 = args[2]
    
    -- Do something
    console:log("Executed with: " .. arg1 .. ", " .. arg2)
end)
```

### Command Naming Convention

Use dot notation to create hierarchical command structure:

```lua
console:addCommand("SYSTEM.START", "Start system", function(args)
    -- ...
end)

console:addCommand("SYSTEM.STOP", "Stop system", function(args)
    -- ...
end)

console:addCommand("SYSTEM.STATUS", "Show status", function(args)
    -- ...
end)
```

Users can then type:
- `SYSTEM.START`
- `SYSTEM.STOP`
- `SYSTEM.STATUS`

### Color Output

Use color markup in console messages:

```lua
console:log("<c=0xFF0000>Error:</c> Something went wrong")
console:log("<c=0x00FF00>Success:</c> Operation completed")
console:log("<c=0xFFFF00>Warning:</c> Check configuration")
console:log("<c=0x00FFFF>Info:</c> Status update")
```

### Complex Command Example

```lua
console:addCommand("NODE.INFO", "Show detailed node information", function(args)
    if #args == 0 then
        console:logError("Usage: NODE.INFO <node-id>")
        console:log("Example: NODE.INFO 12AB")
        return
    end
    
    local nodeId = args[1]:upper()
    
    -- Find node by ID
    local foundNode = nil
    for addr, node in pairs(server.nodes) do
        if node.id == nodeId then
            foundNode = node
            break
        end
    end
    
    if not foundNode then
        console:logError("Node not found: " .. nodeId)
        return
    end
    
    -- Display node information
    console:log("<c=0x00FFFF>Node Information</c>")
    console:log("ID: " .. foundNode.id)
    console:log("Address: " .. foundNode.address)
    console:log("Name: " .. foundNode.shortName)
    console:log("Authorized: " .. tostring(foundNode.authorized))
    console:log("Defective: " .. tostring(foundNode.defective))
    console:log("Last seen: " .. os.date("%Y-%m-%d %H:%M:%S", foundNode.lastSeen))
    console:log("Script: " .. (foundNode.script or "none"))
    
    -- Show active sessions
    local sessionCount = 0
    for _ in pairs(foundNode.sessions) do
        sessionCount = sessionCount + 1
    end
    console:log("Active sessions: " .. sessionCount)
end)
```

### Commands in Programs

For larger features, create a program with a manifest:

**Structure:**
```
programs/myprogram/
├── manifest.lua
└── main.lua
```

**manifest.lua:**
```lua
return {
    name = "myprogram",
    version = "1.0",
    dependencies = {},
    
    init = function()
        -- Register commands
        console:addCommand("MYPROGRAM.RUN", "Run my program", function(args)
            -- Implementation
        end)
        
        console:addCommand("MYPROGRAM.CONFIG", "Configure program", function(args)
            -- Implementation
        end)
    end
}
```

Programs are auto-loaded during boot (autostart phase).

## Using the Class System

SHN-01 uses a Lua-based OOP system for code organization.

### Defining a Class

Create `myclass.class`:

```lua
local MyClass = {}
MyClass.__index = MyClass

-- Constructor
function MyClass:new(arg1, arg2)
    local instance = setmetatable({}, MyClass)
    instance.arg1 = arg1
    instance.arg2 = arg2
    instance.internalState = {}
    return instance
end

-- Instance method
function MyClass:doSomething()
    return self.arg1 .. " " .. self.arg2
end

-- Instance method with parameters
function MyClass:calculate(x, y)
    return x + y + self.arg1
end

return MyClass
```

### Instantiating a Class

```lua
-- Option 1: Using new() helper
local instance = new("path/to/myclass", "value1", "value2")

-- Option 2: Using getClass() and calling :new() directly
local MyClass = getClass("path/to/myclass")
local instance = MyClass:new("value1", "value2")
```

### Class Inheritance

```lua
-- Parent class
local Parent = {}
Parent.__index = Parent

function Parent:new(x)
    local instance = setmetatable({}, Parent)
    instance.x = x
    return instance
end

function Parent:parentMethod()
    return "Parent: " .. self.x
end

return Parent
```

```lua
-- Child class
local Parent = getClass("path/to/parent")

local Child = setmetatable({}, {__index = Parent})
Child.__index = Child

function Child:new(x, y)
    local instance = Parent:new(x)  -- Call parent constructor
    setmetatable(instance, Child)
    instance.y = y
    return instance
end

function Child:childMethod()
    return "Child: " .. self.x .. ", " .. self.y
end

function Child:parentMethod()
    -- Override parent method
    return "Child override: " .. self.x
end

return Child
```

### Checking Instance Type

```lua
local instance = new("path/to/child", 10, 20)

if isInstanceOf(instance, getClass("path/to/parent")) then
    print("Instance is a Parent")
end

if isInstanceOf(instance, getClass("path/to/child")) then
    print("Instance is a Child")
end
```

## Working with Events

The event system enables loose coupling between components.

### Available Global Events

- `globalEvents.onTick` - Fires every ~0.05 seconds
- `globalEvents.onKeyDown` - Keyboard key pressed
- `globalEvents.onKeyUp` - Keyboard key released
- `globalEvents.onNetMessageReceived` - Network message received
- `globalEvents.onSignal` - Raw OpenComputers signal
- `globalEvents.onTouch` - Screen touched
- `globalEvents.onDrag` - Touch drag
- `globalEvents.onDrop` - Touch released
- `globalEvents.onScroll` - Mouse scroll
- `globalEvents.onSystemReady` - Fired once after boot

### Subscribing to Events

```lua
-- Simple subscription
globalEvents.onTick:subscribe(function()
    -- Called every tick
end)

-- With parameters
globalEvents.onNetMessageReceived:subscribe(function(localAddress, remoteAddress, port, distance, ...)
    local args = {...}
    -- Handle network message
end)

-- Store subscription for later removal
local subscription = globalEvents.onKeyDown:subscribe(function(address, char, code, player)
    if char == 32 then  -- Space bar
        print("Space pressed")
    end
end)
```

### Firing Custom Events (Advanced)

While global events are pre-defined, you can create custom events using the same pattern:

```lua
-- Not recommended: modifying globalEvents
-- Instead, create local event objects for custom events
-- (Event class implementation not shown, but follows pub/sub pattern)
```

### Event Timing

- `onTick` fires approximately every 0.05 seconds (20 TPS target)
- `onSignal` fires for all OpenComputers signals
- Other events fire immediately when triggered

### Event Best Practices

1. **Keep handlers fast** - Events are synchronous
2. **Use timer.delay() for deferred work**
   ```lua
   globalEvents.onTick:subscribe(function()
       -- Quick check
       if shouldDoWork then
           timer.delay(function()
               -- Expensive operation
               doExpensiveWork()
           end)
       end
   end)
   ```

3. **Unsubscribe when done** - Prevent memory leaks (if subscription management is implemented)

## Best Practices

### General Guidelines

1. **Follow file naming conventions**
   - Classes: `.class` suffix
   - Manifests: `manifest.lua`
   - Scripts: descriptive names in UPPERCASE

2. **Use path resolution correctly**
   - Absolute paths start with `/`
   - Relative paths resolve from `baseDir`
   - `getAbsolutePath()` for manual resolution

3. **Validate inputs early**
   ```lua
   if not args[1] or args[1] == "" then
       return error("Invalid argument")
   end
   ```

4. **Use debug logging**
   ```lua
   debugPrint("Operation started", node, 1)  -- Level 1: info
   debugPrint("Details: " .. value, node, 2)  -- Level 2: verbose
   debugPrint("Debug info", node, 3)          -- Level 3: very verbose
   ```

5. **Handle errors gracefully**
   ```lua
   local success, result = pcall(function()
       return riskyOperation()
   end)
   
   if not success then
       console:logError("Operation failed: " .. tostring(result))
   end
   ```

### Protocol Development

1. **Choose unique port numbers** - Check existing ports first
2. **Validate node authorization** - Except for initial handshake sequences
3. **Use high priority for critical messages** - Error, disconnect, handshake
4. **Use low priority for routine messages** - Heartbeat, debug, periodic data

### Sequence Development

1. **Set appropriate timeouts** - Based on expected dialogue duration
2. **Always validate args** - Nodes may send malformed messages
3. **Use debug logging** - Track sequence execution
4. **Test timeout behavior** - Ensure sessions clean up properly
5. **Keep sequences focused** - One sequence = one dialogue type

### Node Script Development

1. **Check component availability** before use
2. **Use pcall() for risky operations**
3. **Keep scripts simple** - Limited resources on Tier 1 nodes
4. **Use appropriate sleep intervals** - Balance responsiveness and CPU usage
5. **Consider error recovery** - Stage 2 has auto-restart on repeated errors

### Testing

1. **Use debug mode** - `HIVE.DEBUG 3` for verbose output
2. **Test with one node first** - Scale after validation
3. **Monitor title bar stats** - TPS, memory, message rate
4. **Check queue depth** - High queue depth indicates bottleneck
5. **Test timeout scenarios** - Disconnect nodes during sequences

### Performance

1. **Minimize network traffic** - Batch data when possible
2. **Use rate limiting wisely** - Balance throughput and reliability
3. **Avoid tight loops** - Use timers or yield in coroutines
4. **Monitor memory usage** - Title bar shows current usage
5. **Clean up resources** - Remove unused sessions, close unused ports

### Security (OpenComputers Context)

1. **Validate all inputs** - Never trust node messages
2. **Use authorization checks** - Except for handshake
3. **Mark defective nodes** - Isolate misbehaving nodes
4. **Log security events** - Use debug logging for auditing

## Next Steps

- **[API Reference](api-reference.md)** - Detailed class and function documentation
- **[Configuration Reference](configuration.md)** - Settings and tuning parameters
- **[Architecture Overview](architecture.md)** - Understanding system internals

## Example Projects

### Example 1: Custom Monitoring Protocol

Create a protocol that collects statistics from all nodes:

1. Create `shn-01/hive/network/protocols/monitor.class`
2. Create `shn-01/hive/network/sequences/stats/` with manifest and server
3. Node scripts send stats via `modem.broadcast(monitorPort, "STATS", nil, cpuUsage, memUsage)`
4. Server aggregates and displays in console

### Example 2: Remote Command Execution

Create a sequence that sends Lua code to nodes for execution:

1. Add `exec` sequence to CORE protocol
2. Server sends code string to node
3. Node uses `load()` to compile and execute
4. Node returns result or error
5. Security: only allow on authorized nodes

### Example 3: Distributed Task Coordination

Create a protocol for distributing work across nodes:

1. Create `task` protocol with `assign` and `report` sequences
2. Server tracks available nodes and pending tasks
3. `assign` sequence sends task data to node
4. Node executes task asynchronously
5. `report` sequence sends results back
6. Server redistributes failed tasks

Each example demonstrates key concepts: protocols, sequences, node scripts, and console integration.
