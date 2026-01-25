# Architecture Overview

This document explains the internal architecture of SHN-01, including the boot process, core subsystems, network layer, and client system.

## System Architecture

SHN-01 is organized into three main layers:

1. **Boot & Core Layer** - Minimal runtime and subsystems
2. **Hive Layer** - Network server and node management
3. **Client Layer** - EEPROM-based node code

## Boot Sequence

### Phase 1: Bootstrap (`init.lua`)

The entry point loads the absolute minimum code needed to start the system:

1. **Manual file loading**
   - Reads `shn-01/core/boot/file.lua` (file I/O primitives)
   - Reads `shn-01/core/boot/include.lua` (dynamic loader)
   - Reads `shn-01/core/boot/oop.lua` (class system)
   - Reads `shn-01/core/boot/require.lua` (module caching)

2. **Environment setup**
   - Executes each boot file in `_G` (global environment)
   - Establishes `baseDir` for path resolution
   - Creates `include()`, `inject()`, `class()`, `new()` functions

3. **Hand-off to core**
   - Calls `inject("shn-01/core/boot.lua")`
   - Bootstrap complete

### Phase 2: Core Initialization (`shn-01/core/boot.lua`)

Loads all core subsystems into the global environment:

```lua
inject("shn-01/core/timer.lua")           -- Scheduled callbacks
inject("shn-01/core/database.lua")        -- Persistence layer
inject("shn-01/core/tools.lua")           -- Utility functions
inject("shn-01/core/crypto.lua")          -- Hashing, ID generation
inject("shn-01/core/md5.lua")             -- MD5 implementation
inject("shn-01/core/minify.lua")          -- Code compression
inject("shn-01/core/globalEvents.lua")    -- Event system
inject("shn-01/core/glitch.lua")          -- Screen effects
inject("shn-01/core/colorTools.lua")      -- Color utilities
inject("shn-01/core/keyboard.lua")        -- Input handling
inject("shn-01/core/clipboard.lua")       -- Clipboard support
inject("shn-01/core/console.lua")         -- Terminal UI
inject("shn-01/core/clientFlash.lua")     -- EEPROM flashing
inject("shn-01/core/commands.lua")        -- Built-in commands
inject("shn-01/hive/hive.lua")            -- Hive server
inject("shn-01/core/autostart.lua")       -- Program loader
inject("shn-01/core/mainLoop.lua")        -- Event loop
```

After all injections, the system fires `globalEvents.onSystemReady`.

### Phase 3: Hive Startup (`shn-01/hive/hive.lua`)

The hive server initializes:

1. **Generate or load Hive ID**
   - Checks database for `shn01.hiveId`
   - If missing, generates new ID (e.g., `HV-A3F2`)
   - Stores in database

2. **Initialize node registry**
   - Loads `shn01.nodes` from database
   - Creates `server.nodes` table (address → node object)

3. **Load network protocols**
   - Scans `shn-01/hive/network/protocols/` for `.class` files
   - Instantiates each protocol with `new()`
   - Calls `protocol:start()` to open ports and register sequences
   - Stores in `server.protocols` table

4. **Create outbound message queue**
   - Instantiates `outboundQueue` (rate-limited, dual-priority)
   - Subscribes to `globalEvents.onTick` for processing

5. **Register hive commands**
   - `HIVE.ID.SHOW`, `HIVE.ID.RESET`
   - Adds node creation function to global scope

6. **Broadcast server restart**
   - Sends `SERVER_RESTART` message to all known nodes
   - Nodes will re-authenticate

### Phase 4: Program Loading (`shn-01/core/autostart.lua`)

1. Scans `/programs/*/manifest.lua`
2. Calls `manifest.init()` for each program
3. Programs register console commands

### Phase 5: Main Loop (`shn-01/core/mainLoop.lua`)

Enters the main event loop:

1. Polls `computer.pullSignal(0.05)` for events
2. Dispatches events to `globalEvents` subscribers
3. Updates title bar stats (TPS, memory, net msg/sec)
4. Repeats indefinitely

## Core Subsystems

### File System (`shn-01/core/boot/file.lua`)

Provides file I/O and path resolution:

- `file.read(path)` - Read entire file as string
- `file.write(path, content)` - Write string to file
- `file.exists(path)` - Check if file exists
- `file.delete(path)` - Remove file
- `file.list(path)` - List directory contents
- `getAbsolutePath(relative, origin)` - Resolve relative paths
- `file.normalizePath(path)` - Resolve `.` and `..`

**Path resolution rules:**
- Paths starting with `/` are absolute
- Relative paths use `baseDir` as anchor
- `baseDir` changes during `include()`/`inject()` calls

### Module Loader (`shn-01/core/boot/include.lua`)

Two loading strategies:

**`include(path)`** - Load in isolated environment
- Creates new environment table
- Loads and compiles file
- Executes in isolated environment
- Returns result
- Updates `baseDir` for nested includes

**`inject(path)`** - Load in current environment
- Loads and compiles file
- Executes in `_G` (global scope)
- No return value
- Updates `baseDir` for nested includes

**`file.readWithIncludesMinified(path, minifyFunc, wrap)`**
- Recursively resolves `include()` calls
- Replaces with inline IIFEs: `(function() ... end)()`
- Applies minification function
- Used for EEPROM code generation

### Class System (`shn-01/core/boot/oop.lua`)

Object-oriented programming support:

**`class(path, parent)`** - Define a class
- Loads class file (`.class` convention)
- Returns table with `new` function
- Supports single inheritance
- Caches class definitions

**`new(path, ...)`** - Instantiate a class
- Looks up class in `classBuffer` cache
- Calls `class:new(...)` constructor
- Returns instance

**`getClass(path)`** - Get class definition without instantiating

**`isInstanceOf(obj, classRef)`** - Check inheritance

Example class file structure:
```lua
local MyClass = {}
MyClass.__index = MyClass

function MyClass:new(arg1, arg2)
    local instance = setmetatable({}, MyClass)
    instance.arg1 = arg1
    instance.arg2 = arg2
    return instance
end

function MyClass:method()
    -- instance method
end

return MyClass
```

### Event System (`shn-01/core/globalEvents.lua`)

Publish-subscribe pattern with 9 global events:

- `onTick` - Fires every tick (~0.05s)
- `onKeyDown` - Keyboard key pressed
- `onKeyUp` - Keyboard key released
- `onNetMessageReceived` - Network message received
- `onSignal` - Raw OpenComputers signal
- `onTouch` - Screen touched
- `onDrag` - Touch drag
- `onDrop` - Touch released
- `onScroll` - Mouse scroll
- `onSystemReady` - Fired once after boot

**Usage:**
```lua
-- Subscribe
globalEvents.onTick:subscribe(function()
    -- called every tick
end)

-- Fire (typically internal use)
globalEvents.onTick:fire()
```

### Database (`shn-01/core/database.lua`)

Persistent key-value store with application namespacing:

**Storage format:**
- Location: `/shn-01/data/<app>`
- Format: `key:type=value␞` (␞ = UTF-8 record separator U+001E)
- Supports: string, number, boolean, table (serialized)

**API:**
```lua
database:setKey("app", "key", value, doSave)
local value = database:getKey("app", "key")
```

**Application namespaces:**
- `shn01` - Hive system data (hiveId, nodes, queueRateLimit, etc.)
- `console` - Console settings (commandHistory, colors)

### Console (`shn-01/core/console.lua`)

Terminal UI with command system:

**Features:**
- Color markup: `<c=0xRRGGBB>text</c>`
- Command registration and execution
- Command history (up/down arrows)
- Message buffer (last 100 messages)
- Scrolling support
- Auto-complete (partial implementation)

**Command registration:**
```lua
console:addCommand("MY.COMMAND", "Description", function(args)
    console:log("Command executed with args: " .. table.concat(args, ", "))
end)
```

**Dot notation hierarchy:**
- Commands use dots to indicate categories
- Example: `HIVE.ID.SHOW`, `COMPUTER.INFO`, `FLASH.NODE`

### Timer (`shn-01/core/timer.lua`)

Scheduled callback system:

```lua
-- Schedule once
timer.add(5.0, function()
    print("Executed after 5 seconds")
end, false)

-- Schedule repeating
timer.add(1.0, function()
    print("Executed every second")
end, true)

-- Defer to next tick
timer.delay(function()
    print("Executed next tick")
end)
```

### Crypto (`shn-01/core/crypto.lua`)

Hashing and ID generation:

**`crypto.adler32(str)`** - Checksum
- Fast, simple hash for integrity checks
- Returns 32-bit integer
- Used in file transmission (transmit sequence)

**`crypto.uniqueID()`** - Persistent ID generation
- Generates 4-digit hex IDs (e.g., `A3F2`)
- Uses database counter + LCG (linear congruential generator)
- Persists counter to database (`shn01.persistentId`)

### Minification (`shn-01/core/minify.lua`)

Code compression for EEPROM constraints:

**`minify.parse(code)`** - Full minification
- Uses luaminify parser
- Removes whitespace, comments, renames locals
- Maximum compression (slowest)

**`minify.parseCheap(code)`** - Medium compression
- Removes comments and excess whitespace
- Preserves variable names
- Faster than full minification

**`minify.parseVeryCheap(code)`** - Light compression
- Only removes line comments (`--`)
- Preserves block comments
- Fastest option

**Why minification matters:**
- EEPROM size limit: **4096 bytes**
- Stage 1 client code must fit in EEPROM
- `FLASH.SIZETEST` command validates size

## Network Architecture

### Three-Layer Model

```
┌─────────────────────────────────────────┐
│ Protocols (port owners)                 │
│  - GATE (2011)  - ECHO (2022)           │
│  - CORE (2015)  - FILE (2031)           │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│ Sequences (message handlers)            │
│  - handshake    - heartbeat             │
│  - transmit     - disconnect            │
│  - debug        - error                 │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│ Sessions (coroutine instances)          │
│  - One per node per sequence            │
│  - Stateful, multi-step dialogues       │
└─────────────────────────────────────────┘
```

### Protocols

Protocols own modem ports and contain multiple sequences.

**Protocol class structure:**
```lua
local Protocol = {}
Protocol.__index = Protocol

function Protocol:new()
    local instance = setmetatable({}, Protocol)
    instance.name = "GATE"
    instance.port = 2011
    instance.description = "Gateway protocol"
    instance.sequences = {}
    return instance
end

function Protocol:start()
    -- Open modem port
    getComponent("modem"):open(self.port)
    
    -- Load sequences from manifests
    local seq = sequenceClass.create(hive, self, "shn-01/hive/network/sequences/handshake")
    self.sequences[seq.name] = seq
    
    -- Subscribe to network messages
    globalEvents.onNetMessageReceived:subscribe(function(...)
        self:onMessage(...)
    end)
end
```

**Available protocols:**
- **GATE** (2011) - Connection management (handshake, disconnect, bounce)
- **FILE** (2031) - File transmission (transmit)
- **ECHO** (2022) - Heartbeat monitoring
- **CORE** (2015) - Debug and error reporting

### Sequences

Sequences define message handling logic as coroutines.

**Sequence manifest structure:**
```lua
-- sequences/handshake/manifest.lua
return {
    name = "handshake",
    version = "1.0",
    server = "server.lua",           -- Server-side handler
    client = "client.lua",            -- Client-side handler (optional)
    timeout = 60,                     -- Session timeout (seconds)
    sequence = true,                  -- true = stateful, false = one-shot
    description = "Initial connection handshake"
}
```

**Sequence server implementation pattern:**
```lua
-- sequences/handshake/server.lua
return function(hive, protocol)
    return function(node, args)
        -- Coroutine function - handles one session
        
        -- Step 1: Receive initial message
        local clientHiveId = args[1]
        local nodeId = args[2]
        
        -- Validate and process
        if clientHiveId ~= getHiveId() then
            -- Send error response
            local err = outboundClass:new(node, protocol, nil, true, "HANDSHAKE_ERROR", "Wrong hive")
            node, args = coroutine.yield({err})
            return
        end
        
        -- Step 2: Authorize node
        node:authorize()
        
        -- Step 3: Send confirmation
        local response = outboundClass:new(node, protocol, nil, true, "HANDSHAKE_OK")
        node, args = coroutine.yield({response})
        
        -- Step 4: Trigger Stage 2 download
        -- (transmit sequence handles actual file transfer)
        
        -- Sequence complete
    end
end
```

**Key sequence patterns:**
- Each `yield` sends messages and waits for response
- Yielded value is array of `outbound` message objects
- `coroutine.yield()` returns `(node, args)` on next message
- Sequences can run indefinitely (e.g., heartbeat infinite loop)
- Timeout enforced by sequence handler

### Sessions

Sessions are coroutine instances for specific node+sequence pairs.

**Session object structure:**
```lua
{
    id = "12AB",                      -- Unique session ID (per node)
    routine = coroutine.create(func), -- Coroutine instance
    startTime = os.time(),            -- Creation timestamp
    node = nodeObject,                -- Associated node
    result = nil                      -- Return value (when complete)
}
```

**Session lifecycle:**
1. **Creation** - First message arrives for sequence
2. **Processing** - Coroutine resumes with each message
3. **Timeout check** - Sessions older than `timeout` are removed
4. **Completion** - Coroutine returns (not yields)
5. **Cleanup** - Session removed from `sequence.sessions`

**Session ID generation:**
- Counter per node (starts at 0)
- `node:newSessionId()` increments and returns hex string
- Format: 4-digit hex (e.g., `0000`, `0001`, ..., `FFFF`)

### Message Flow

1. **Incoming message** arrives on protocol port
2. **Protocol** extracts sequence name and session ID
3. **Sequence** looks up or creates session
4. **Coroutine** resumes with message data
5. **Outbound messages** returned via yield
6. **Queue** enqueues messages (rate-limited)
7. **Queue processor** sends messages (high priority first)

**Message format:**
```lua
modem.broadcast(port, sequenceName, sessionId, arg1, arg2, ...)
```

Example:
```lua
modem.broadcast(2011, "HANDSHAKE", nil, "HV-A3F2", "HV-A3F2-ND-12AB")
```

### Message Queue & Rate Limiting

**Why rate limiting?**
- OpenComputers network relays have message limits
- Too many messages cause dropped packets
- Queue smooths burst traffic

**Outbound queue features:**
- Dual-priority queues (high/low)
- Token bucket algorithm
- Configurable rate (default: 10 msg/sec)
- Max capacity: 1000 messages
- Drops oldest on overflow

**Priority rules:**
- High priority: handshake, error, disconnect
- Low priority: heartbeat, debug, data

**Configuration:**
```lua
database:setKey("shn01", "queueRateLimit", 20)  -- 20 msg/sec
```

## Client System (Node Architecture)

Nodes run a 2-stage bootstrap system to minimize EEPROM usage.

### Stage 1: EEPROM Bootstrap

**File:** `shn-01/data/clientFlashStage1.lua`

**Constraints:**
- Must fit in 4096 bytes (EEPROM limit)
- Heavily minified
- No external dependencies

**Responsibilities:**
1. Extract hardcoded Hive ID and Node ID
2. Find modem and GPU components
3. Send handshake to hive (port 2011)
4. Receive Stage 2 code via transmit sequence
5. Validate checksum (Adler-32)
6. Compile and execute Stage 2

**Injected values (during flashing):**
```lua
local hiveId = "{{HIVE_ID}}"     -- Replaced with actual ID
local nodeId = "{{NODE_ID}}"     -- Replaced with actual ID
```

### Stage 2: Full Client Runtime

**File:** `shn-01/data/clientStage2.lua`

**Features:**
- Full boot system (include, inject, class, new)
- Network protocol stack (ECHO, CORE)
- Heartbeat every 30 seconds
- Error handling and auto-restart
- Node script execution

**Startup sequence:**
1. Initialize boot system
2. Open ECHO (2022) and CORE (2015) ports
3. Load node script from database
4. Execute node script once
5. Enter idle mode (heartbeat loop)

**Heartbeat loop:**
```lua
while true do
    -- Send heartbeat
    modem.broadcast(2022, "HEARTBEAT", sessionId, nodeId)
    
    -- Wait 30 seconds
    os.sleep(30)
    
    -- Check for hive messages
    -- Process any pending tasks
end
```

**Error handling:**
- Catches all errors in node script
- Sends error report to hive (port 2015)
- Tracks error count (3 errors in 30s = restart)
- Auto-restart clears error counter

### Node Scripts

Node scripts are simple Lua files executed once on startup.

**Location:** `shn-01/hive/node-scripts/<name>.lua`

**Execution context:**
- Full Lua 5.3 environment
- OpenComputers component API
- Boot system (include, inject, class, new)
- Network messaging (via protocol APIs)

**Example script:**
```lua
-- SOLAR.lua - Solar panel monitor
local solarPanel = component.proxy(component.list("gt_machine")())

while true do
    local output = solarPanel.getSensorInformation()[4]
    print("Solar output: " .. output .. " EU/t")
    os.sleep(60)
end
```

**Deployment:**
- Script name specified during `FLASH.NODE` command
- Stored in database `nodeData.script`
- Sent to node during handshake (transmit sequence)

## Node Management

### Node Object Structure

**Properties:**
- `id` - Short ID (4-digit hex, e.g., `12AB`)
- `address` - Full network card address
- `shortName` - Last component of full name (e.g., `SOLAR`)
- `lastSeen` - Timestamp of last heartbeat
- `authorized` - Boolean (false until handshake complete)
- `defective` - Boolean (marked after errors)
- `sessions` - Table of active sessions
- `script` - Assigned node script name

**Methods:**
- `node:newSessionId()` - Generate unique session ID
- `node:authorize()` - Mark node as authorized
- `node:updateHeartbeat()` - Update `lastSeen`
- `node:isStale(timeout)` - Check if heartbeat timed out
- `node:markDefective(error)` - Flag as broken
- `node:clearSessions()` - Remove all sessions
- `node:debugPrint(msg)` - Debug logging

### Node Registry

Nodes are stored in the database:

**Database structure:**
```lua
database:getKey("shn01", "nodes")
-- Returns array:
{
    {id = "12AB", script = "SOLAR", defective = false},
    {id = "34CD", script = "REACTOR", defective = false},
    {id = "56EF", script = "STORAGE", defective = true, lastError = "timeout"}
}
```

**Runtime structure:**
```lua
server.nodes = {
    ["a1b2c3d4-..."] = nodeObject,
    ["e5f6g7h8-..."] = nodeObject
}
```

Nodes are added to runtime table during handshake.

### Node Lifecycle

1. **Flash** - Hive writes EEPROM to target computer
2. **Boot** - Node executes Stage 1
3. **Handshake** - Node sends connection request
4. **Authorization** - Hive validates and authorizes
5. **Stage 2 download** - Node receives full runtime via transmit
6. **Script execution** - Node runs assigned script
7. **Idle mode** - Node sends heartbeat every 30s
8. **Defective** - Node marked broken after errors
9. **Disconnect** - Node sends graceful shutdown (optional)

## Summary

SHN-01 is a layered system:
- **Boot layer** provides minimal runtime (file, include, class, require)
- **Core layer** adds subsystems (console, database, events, timer, crypto)
- **Hive layer** implements network server (protocols, sequences, sessions)
- **Client layer** runs 2-stage bootstrap (EEPROM → Stage 2)

Key architectural decisions:
- **Coroutine-based sequences** enable stateful dialogues without callbacks
- **Rate-limited message queue** prevents network overload
- **2-stage client bootstrap** overcomes EEPROM size constraint
- **Dynamic loading** (inject, include) enables modularity
- **Event system** decouples components
- **Class system** provides OOP patterns in Lua

Next: See [Development Guide](development-guide.md) for creating custom protocols and sequences.
