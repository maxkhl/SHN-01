# API Reference

Complete API reference for SHN-01 core classes, global functions, and utilities.

## Table of Contents

- [Core Classes](#core-classes)
  - [Node](#node)
  - [Protocol](#protocol)
  - [Sequence](#sequence)
  - [Message (Outbound)](#message-outbound)
- [Global Functions](#global-functions)
- [File System API](#file-system-api)
- [Module Loading](#module-loading)
- [Class System](#class-system)
- [Database API](#database-api)
- [Event System](#event-system)
- [Timer API](#timer-api)
- [Crypto Utilities](#crypto-utilities)
- [Console API](#console-api)
- [Utility Functions](#utility-functions)

## Core Classes

### Node

Represents a connected client node in the hive network.

**Location:** `shn-01/hive/network/node.class`

#### Properties

- `id` (string) - Short unique identifier (4-digit hex, e.g., `"12AB"`)
- `address` (string) - Full OpenComputers network card address
- `shortName` (string) - Last component of full name (e.g., `"SOLAR"`)
- `lastSeen` (number) - Timestamp of last heartbeat (from `os.time()`)
- `authorized` (boolean) - Whether node has completed handshake
- `defective` (boolean) - Whether node is marked as broken
- `sessions` (table) - Map of active session IDs to session counters
- `script` (string) - Assigned node script name

#### Methods

##### `node:newSessionId()`

Generates a unique session ID for this node.

**Returns:** `string` - 4-digit hex session ID (e.g., `"0001"`)

**Example:**
```lua
local sessionId = node:newSessionId()
-- sessionId = "0001", next call returns "0002", etc.
```

##### `node:authorize()`

Marks the node as authorized. Should be called after successful handshake.

**Returns:** None

**Example:**
```lua
node:authorize()
-- node.authorized is now true
```

##### `node:updateHeartbeat()`

Updates the `lastSeen` timestamp to current time.

**Returns:** None

**Example:**
```lua
node:updateHeartbeat()
-- node.lastSeen = os.time()
```

##### `node:isStale(timeout)`

Checks if the node's heartbeat has timed out.

**Parameters:**
- `timeout` (number) - Timeout duration in seconds

**Returns:** `boolean` - `true` if `(os.time() - lastSeen) > timeout`

**Example:**
```lua
if node:isStale(60) then
    console:log("Node " .. node.id .. " hasn't responded in 60 seconds")
end
```

##### `node:markDefective(errorMessage)`

Marks the node as defective and removes it from active connections.

**Parameters:**
- `errorMessage` (string) - Error description

**Returns:** None

**Side effects:**
- Sets `defective = true`
- Stores error in database
- Removes from `server.nodes`
- Clears all active sessions

**Example:**
```lua
node:markDefective("Timeout during handshake")
```

##### `node:clearSessions()`

Removes all active sessions for this node.

**Returns:** None

**Example:**
```lua
node:clearSessions()
-- node.sessions = {}
```

##### `node:debugPrint(message)`

Prints a debug message with node context.

**Parameters:**
- `message` (string) - Debug message

**Returns:** None

**Example:**
```lua
node:debugPrint("Processing request")
-- Output: [HV-A3F2-ND-12AB-SOLAR] Processing request
```

### Protocol

Base class for network protocols. Protocols own modem ports and contain sequences.

**Location:** `shn-01/hive/network/protocol.class`

#### Properties

- `name` (string) - Protocol identifier (e.g., `"GATE"`)
- `port` (number) - Modem port number (e.g., `2011`)
- `description` (string) - Human-readable description
- `sequences` (table) - Map of sequence name to sequence instance

#### Methods

##### `protocol:start()`

Initializes the protocol: opens modem port, loads sequences, subscribes to network messages.

**Returns:** None

**Example:**
```lua
local protocol = new("shn-01/hive/network/protocols/gate")
protocol:start()
-- Port opened, sequences loaded
```

##### `protocol:onMessage(localAddress, remoteAddress, port, distance, ...)`

Handles incoming network messages for this protocol.

**Parameters:**
- `localAddress` (string) - Local network card address
- `remoteAddress` (string) - Sender's network card address
- `port` (number) - Port number
- `distance` (number) - Signal distance
- `...` - Message arguments (first is sequence name, second is session ID)

**Returns:** None

**Note:** This method is called automatically by event subscription. Typically not called directly.

### Sequence

Manages coroutine-based message sequences for a protocol.

**Location:** `shn-01/hive/network/sequence.class`

#### Static Methods

##### `sequence.create(hive, protocol, manifestPath)`

Factory method that creates a sequence instance from a manifest.

**Parameters:**
- `hive` (table) - Hive server object
- `protocol` (object) - Protocol instance
- `manifestPath` (string) - Path to sequence manifest directory

**Returns:** `object` - Sequence instance

**Example:**
```lua
local sequenceClass = getClass("shn-01/hive/network/sequence")
local seq = sequenceClass.create(server, protocol, "shn-01/hive/network/sequences/handshake")
```

#### Properties

- `name` (string) - Sequence identifier
- `func` (function) - Coroutine factory function
- `timeout` (number) - Session timeout in seconds
- `sessions` (array) - Active session objects

#### Methods

##### `sequence:createSession(node, args)`

Creates a new session for a node and starts the sequence coroutine.

**Parameters:**
- `node` (object) - Node object
- `args` (table) - Initial message arguments

**Returns:** None

**Side effects:**
- Creates new session object
- Starts coroutine
- Sends `SESSION_CREATED` debug notification
- Executes coroutine with initial args

**Example:**
```lua
sequence:createSession(node, {"HANDSHAKE", "HV-A3F2", "HV-A3F2-ND-12AB"})
```

##### `sequence:process(sessionId, args)`

Resumes an existing session with new message data.

**Parameters:**
- `sessionId` (string) - Session identifier
- `args` (table) - Message arguments

**Returns:** None

**Example:**
```lua
sequence:process("0001", {"ACK", "OK"})
```

##### `sequence:executeAndSend(routine, node, args, sessionId)`

Executes a coroutine and sends yielded messages.

**Parameters:**
- `routine` (thread) - Coroutine to execute
- `node` (object) - Node object
- `args` (table) - Arguments to pass to coroutine
- `sessionId` (string) - Session identifier

**Returns:** None

**Side effects:**
- Resumes coroutine with `(node, args)`
- Validates yielded messages
- Enqueues messages to outbound queue
- Removes session if coroutine completes

##### `sequence:findSession(sessionId)`

Finds a session by ID.

**Parameters:**
- `sessionId` (string) - Session identifier

**Returns:** `object|nil` - Session object or `nil` if not found

**Example:**
```lua
local session = sequence:findSession("0001")
if session then
    print("Session found")
end
```

##### `sequence:removeSession(sessionId)`

Removes a session by ID.

**Parameters:**
- `sessionId` (string) - Session identifier

**Returns:** None

**Example:**
```lua
sequence:removeSession("0001")
```

### Message (Outbound)

Represents an outgoing network message.

**Location:** `shn-01/hive/network/messages/outbound.class`

#### Constructor

##### `outbound:new(node, protocol, sessionId, highPriority, ...)`

Creates a new outbound message.

**Parameters:**
- `node` (object) - Target node
- `protocol` (object) - Protocol instance
- `sessionId` (string|nil) - Session ID or `nil` for new session
- `highPriority` (boolean) - Priority flag
- `...` - Message arguments (sent after sequence name and session ID)

**Returns:** `object` - Outbound message instance

**Example:**
```lua
local outboundClass = getClass("shn-01/hive/network/messages/outbound")
local msg = outboundClass:new(
    node,
    protocol,
    "0001",
    true,
    "HANDSHAKE_OK",
    "Welcome"
)
```

#### Methods

##### `message:send()`

Enqueues the message to the outbound queue for sending.

**Returns:** None

**Example:**
```lua
message:send()
-- Message added to queue
```

##### `message:insertArg(position, value)`

Inserts an argument at a specific position in the message.

**Parameters:**
- `position` (number) - 1-based index
- `value` (any) - Value to insert

**Returns:** None

**Example:**
```lua
message:insertArg(1, "PRIORITY_FLAG")
-- Inserts at beginning of message args
```

## Global Functions

### Hive Functions

#### `getHiveId()`

Returns the current hive identifier.

**Returns:** `string` - Hive ID (e.g., `"HV-A3F2"`)

**Example:**
```lua
local hiveId = getHiveId()
console:log("Hive ID: " .. hiveId)
```

#### `getNodes()`

Returns the node registry from the database.

**Returns:** `table` - Array of node data objects

**Example:**
```lua
local nodes = getNodes()
for i, nodeData in ipairs(nodes) do
    print(nodeData.id, nodeData.script)
end
```

#### `debugPrint(message, node, level)`

Prints a debug message if debug level is sufficient.

**Parameters:**
- `message` (string) - Debug message
- `node` (object|nil) - Node context (optional)
- `level` (number) - Debug level (1-3)

**Returns:** None

**Debug levels:**
- 1 - Info: Important events
- 2 - Verbose: Detailed operations
- 3 - Very verbose: All operations

**Example:**
```lua
debugPrint("Sequence started", node, 1)
debugPrint("Processing message: " .. msg, node, 2)
debugPrint("Internal state: " .. state, node, 3)
```

#### `createNode(nodeId, address, script)`

Creates a new node object and adds it to the registry.

**Parameters:**
- `nodeId` (string) - Node ID (4-digit hex)
- `address` (string) - Network card address
- `script` (string) - Assigned script name

**Returns:** `object` - Node instance

**Example:**
```lua
local node = createNode("12AB", "a1b2c3d4-...", "SOLAR")
server.nodes[address] = node
```

### Component Helper

#### `getComponent(componentType)`

Gets the first available component of a specific type.

**Parameters:**
- `componentType` (string) - Component type name (e.g., `"modem"`, `"gpu"`)

**Returns:** `table` - Component proxy

**Throws:** Error if component not found

**Example:**
```lua
local modem = getComponent("modem")
local gpu = getComponent("gpu")
```

## File System API

All file system functions are in the global `file` table.

### `file.read(path)`

Reads entire file as a string.

**Parameters:**
- `path` (string) - File path (absolute or relative)

**Returns:** `string|nil` - File contents or `nil` if not found

**Example:**
```lua
local content = file.read("/home/config.txt")
```

### `file.write(path, content)`

Writes string to file, creating directories as needed.

**Parameters:**
- `path` (string) - File path
- `content` (string) - Content to write

**Returns:** `boolean` - Success status

**Example:**
```lua
file.write("/home/output.txt", "Hello, world!")
```

### `file.exists(path)`

Checks if a file exists.

**Parameters:**
- `path` (string) - File path

**Returns:** `boolean` - `true` if exists

**Example:**
```lua
if file.exists("/home/data.txt") then
    print("File found")
end
```

### `file.delete(path)`

Deletes a file.

**Parameters:**
- `path` (string) - File path

**Returns:** `boolean` - Success status

**Example:**
```lua
file.delete("/tmp/old.txt")
```

### `file.list(path)`

Lists directory contents.

**Parameters:**
- `path` (string) - Directory path

**Returns:** `table` - Array of filenames (directories end with `/`)

**Example:**
```lua
local files = file.list("/home/")
for _, filename in ipairs(files) do
    print(filename)
end
```

### `file.normalizePath(path)`

Normalizes a path by resolving `.` and `..`.

**Parameters:**
- `path` (string) - Path to normalize

**Returns:** `string` - Normalized path

**Example:**
```lua
local normalized = file.normalizePath("/home/../etc/./config")
-- Returns: "/etc/config"
```

### `getAbsolutePath(relativePath, origin)`

Resolves a relative path to absolute.

**Parameters:**
- `relativePath` (string) - Relative path
- `origin` (string|nil) - Origin directory (defaults to `baseDir`)

**Returns:** `string` - Absolute path

**Example:**
```lua
local abs = getAbsolutePath("config.lua", "/home/app/")
-- Returns: "/home/app/config.lua"
```

### `file.readWithIncludesMinified(path, minifyFunc, wrap)`

Reads a file and recursively resolves `include()` calls, then minifies.

**Parameters:**
- `path` (string) - Entry file path
- `minifyFunc` (function) - Minification function (e.g., `minify.parse`)
- `wrap` (boolean) - Whether to wrap includes in IIFEs

**Returns:** `string` - Minified code with includes resolved

**Example:**
```lua
local code = file.readWithIncludesMinified(
    "shn-01/data/clientStage1.lua",
    minify.parse,
    true
)
```

## Module Loading

### `include(path)`

Loads a module in an isolated environment and returns its result.

**Parameters:**
- `path` (string) - Module path (relative to `baseDir`)

**Returns:** `any` - Module return value

**Side effects:**
- Temporarily changes `baseDir` for nested includes
- Creates isolated environment table
- Compiles and executes module

**Example:**
```lua
local config = include("config.lua")
print(config.setting)
```

### `inject(path)`

Loads a module in the global environment.

**Parameters:**
- `path` (string) - Module path (relative to `baseDir`)

**Returns:** None

**Side effects:**
- Executes module in `_G`
- Temporarily changes `baseDir` for nested includes

**Example:**
```lua
inject("shn-01/core/tools.lua")
-- tools.lua functions now available globally
```

## Class System

### `class(path, parent)`

Defines or loads a class.

**Parameters:**
- `path` (string) - Class file path (typically `.class` suffix)
- `parent` (table|nil) - Parent class for inheritance (optional)

**Returns:** `table` - Class definition table

**Example:**
```lua
local MyClass = class("myclass")
-- MyClass.new() is now available
```

### `new(path, ...)`

Instantiates a class.

**Parameters:**
- `path` (string) - Class file path
- `...` - Constructor arguments

**Returns:** `object` - Class instance

**Example:**
```lua
local instance = new("shn-01/hive/network/node", "12AB", "a1b2c3d4-...")
```

### `getClass(path)`

Gets a class definition without instantiating.

**Parameters:**
- `path` (string) - Class file path

**Returns:** `table` - Class definition

**Example:**
```lua
local NodeClass = getClass("shn-01/hive/network/node")
local instance = NodeClass:new("12AB", "a1b2c3d4-...")
```

### `isInstanceOf(obj, classRef)`

Checks if an object is an instance of a class.

**Parameters:**
- `obj` (table) - Object to check
- `classRef` (table) - Class definition

**Returns:** `boolean` - `true` if `obj` is instance of `classRef`

**Example:**
```lua
local NodeClass = getClass("shn-01/hive/network/node")
local node = new("shn-01/hive/network/node", "12AB", "...")

if isInstanceOf(node, NodeClass) then
    print("node is a Node instance")
end
```

## Database API

The `database` object provides persistent key-value storage.

### `database:setKey(app, key, value, doSave)`

Sets a key-value pair in the database.

**Parameters:**
- `app` (string) - Application namespace
- `key` (string) - Key name
- `value` (any) - Value (string, number, boolean, or table)
- `doSave` (boolean|nil) - Whether to save immediately (default: `true`)

**Returns:** None

**Example:**
```lua
database:setKey("myapp", "setting", "value", true)
database:setKey("myapp", "count", 42)
database:setKey("myapp", "enabled", true)
database:setKey("myapp", "config", {x = 10, y = 20})
```

### `database:getKey(app, key)`

Gets a value from the database.

**Parameters:**
- `app` (string) - Application namespace
- `key` (string) - Key name

**Returns:** `any|nil` - Stored value or `nil` if not found

**Example:**
```lua
local setting = database:getKey("myapp", "setting")
local count = database:getKey("myapp", "count")
local config = database:getKey("myapp", "config")
```

### Storage Format

- **Location:** `/shn-01/data/<app>`
- **Format:** `key:type=value␞` (␞ = UTF-8 record separator U+001E)
- **Supported types:** `string`, `number`, `boolean`, `table`
- **Tables:** Serialized recursively

## Event System

The `globalEvents` object provides 9 pre-defined events.

### Event Objects

#### `globalEvents.onTick`

Fires every tick (~0.05 seconds).

**Example:**
```lua
globalEvents.onTick:subscribe(function()
    -- Called ~20 times per second
end)
```

#### `globalEvents.onKeyDown`

Fires when a keyboard key is pressed.

**Parameters:** `(address, char, code, player)`

**Example:**
```lua
globalEvents.onKeyDown:subscribe(function(address, char, code, player)
    if char == 32 then
        print("Space pressed")
    end
end)
```

#### `globalEvents.onKeyUp`

Fires when a keyboard key is released.

**Parameters:** `(address, char, code, player)`

#### `globalEvents.onNetMessageReceived`

Fires when a network message is received.

**Parameters:** `(localAddress, remoteAddress, port, distance, ...)`

**Example:**
```lua
globalEvents.onNetMessageReceived:subscribe(function(localAddr, remoteAddr, port, dist, ...)
    local args = {...}
    print("Message on port " .. port .. ": " .. table.concat(args, ", "))
end)
```

#### `globalEvents.onSignal`

Fires for all OpenComputers signals (raw event).

**Parameters:** `(signalType, ...)`

#### `globalEvents.onTouch`

Fires when screen is touched.

**Parameters:** `(address, x, y, button, player)`

#### `globalEvents.onDrag`

Fires when touch is dragged.

**Parameters:** `(address, x, y, button, player)`

#### `globalEvents.onDrop`

Fires when touch is released.

**Parameters:** `(address, x, y, button, player)`

#### `globalEvents.onScroll`

Fires when mouse wheel is scrolled.

**Parameters:** `(address, x, y, direction, player)`

#### `globalEvents.onSystemReady`

Fires once after boot completes.

**Example:**
```lua
globalEvents.onSystemReady:subscribe(function()
    print("System ready")
end)
```

### Event Methods

#### `event:subscribe(callback)`

Subscribes to an event.

**Parameters:**
- `callback` (function) - Function to call when event fires

**Returns:** None (or subscription object, if implemented)

**Example:**
```lua
globalEvents.onTick:subscribe(function()
    -- Handler
end)
```

#### `event:fire(...)`

Fires an event (internal use).

**Parameters:**
- `...` - Event arguments

**Returns:** None

## Timer API

The `timer` table provides scheduled callbacks.

### `timer.add(delay, callback, reset)`

Schedules a callback after a delay.

**Parameters:**
- `delay` (number) - Delay in seconds
- `callback` (function) - Function to call
- `reset` (boolean) - If `true`, repeats; if `false`, runs once

**Returns:** None

**Example:**
```lua
-- Run once after 5 seconds
timer.add(5.0, function()
    print("Delayed execution")
end, false)

-- Run every 2 seconds
timer.add(2.0, function()
    print("Repeating task")
end, true)
```

### `timer.delay(callback)`

Defers a callback to the next tick.

**Parameters:**
- `callback` (function) - Function to call

**Returns:** None

**Example:**
```lua
timer.delay(function()
    print("Executed on next tick")
end)
```

## Crypto Utilities

The `crypto` table provides hashing and ID generation.

### `crypto.adler32(str)`

Computes Adler-32 checksum.

**Parameters:**
- `str` (string) - Input string

**Returns:** `number` - 32-bit checksum

**Example:**
```lua
local checksum = crypto.adler32("Hello, world!")
print(string.format("Checksum: 0x%08X", checksum))
```

### `crypto.uniqueID()`

Generates a unique 4-digit hex ID.

**Returns:** `string` - Hex ID (e.g., `"A3F2"`)

**Details:**
- Uses database counter + LCG for uniqueness
- Persists counter to `shn01.persistentId`
- IDs are sequential but appear random

**Example:**
```lua
local id1 = crypto.uniqueID()  -- "A3F2"
local id2 = crypto.uniqueID()  -- "B4E1"
```

## Console API

The `console` object provides terminal UI and command management.

### `console:log(message)`

Prints a message to the console.

**Parameters:**
- `message` (string) - Message (supports color markup)

**Returns:** None

**Example:**
```lua
console:log("Normal message")
console:log("<c=0xFF0000>Red text</c>")
console:log("<c=0x00FF00>Green</c> and <c=0x0000FF>Blue</c>")
```

### `console:logError(message)`

Prints an error message to the console.

**Parameters:**
- `message` (string) - Error message

**Returns:** None

**Example:**
```lua
console:logError("Something went wrong")
```

### `console:addCommand(name, description, callback)`

Registers a console command.

**Parameters:**
- `name` (string) - Command name (use dots for hierarchy)
- `description` (string) - Command description
- `callback` (function) - Command handler `function(args)`

**Returns:** None

**Example:**
```lua
console:addCommand("MYCOMMAND", "Does something", function(args)
    if #args == 0 then
        console:logError("Usage: MYCOMMAND <arg>")
        return
    end
    console:log("Executed with: " .. args[1])
end)
```

### Color Markup

Use `<c=0xRRGGBB>text</c>` for colored text:

- `<c=0xFF0000>Red</c>`
- `<c=0x00FF00>Green</c>`
- `<c=0x0000FF>Blue</c>`
- `<c=0xFFFF00>Yellow</c>`
- `<c=0xFF00FF>Magenta</c>`
- `<c=0x00FFFF>Cyan</c>`
- `<c=0xFFFFFF>White</c>`

## Utility Functions

### `visualLength(str)`

Computes visual length of a string, correctly handling multi-byte UTF-8 characters.

**Parameters:**
- `str` (string) - Input string

**Returns:** `number` - Visual character count

**Example:**
```lua
local len = visualLength("Hello 世界")  -- 8, not 12
```

### `math.levenshtein(str1, str2)`

Computes Levenshtein distance (edit distance) between two strings.

**Parameters:**
- `str1` (string) - First string
- `str2` (string) - Second string

**Returns:** `number` - Edit distance

**Example:**
```lua
local distance = math.levenshtein("kitten", "sitting")  -- 3
```

### `computer.gpuTier()`

Detects GPU tier (1, 2, or 3).

**Returns:** `number` - GPU tier

**Example:**
```lua
local tier = computer.gpuTier()
if tier == 1 then
    print("Using Tier 1 GPU (50x16, 1 color)")
end
```

## Minification API

The `minify` table provides code compression functions.

### `minify.parse(code)`

Full minification (slowest, maximum compression).

**Parameters:**
- `code` (string) - Lua source code

**Returns:** `string` - Minified code

**Example:**
```lua
local minified = minify.parse([[
    -- This is a comment
    local function hello(name)
        return "Hello, " .. name
    end
]])
```

### `minify.parseCheap(code)`

Medium minification (removes comments and whitespace).

**Parameters:**
- `code` (string) - Lua source code

**Returns:** `string` - Minified code

### `minify.parseVeryCheap(code)`

Light minification (removes only line comments).

**Parameters:**
- `code` (string) - Lua source code

**Returns:** `string` - Minified code

## Next Steps

- **[Configuration Reference](configuration.md)** - Database keys, ports, and settings
- **[Development Guide](development-guide.md)** - Creating custom components
- **[Architecture Overview](architecture.md)** - Understanding the system
