# Configuration Reference

Complete reference for SHN-01 configuration, including database keys, port assignments, file conventions, and tuning parameters.

## Table of Contents

- [Database Keys](#database-keys)
- [Port Assignments](#port-assignments)
- [File Naming Conventions](#file-naming-conventions)
- [Path Resolution](#path-resolution)
- [Performance Tuning](#performance-tuning)
- [Debug Settings](#debug-settings)
- [EEPROM Constraints](#eeprom-constraints)
- [Color Schemes](#color-schemes)
- [Network Configuration](#network-configuration)

## Database Keys

The database stores configuration and state in `/shn-01/data/<app>/` directories.

### `shn01` Namespace (Hive System)

#### `shn01.hiveId`

**Type:** `string`  
**Default:** Generated on first boot  
**Description:** Unique hive identifier (e.g., `"HV-A3F2"`)

**Example:**
```lua
local hiveId = database:getKey("shn01", "hiveId")
```

**Reset:**
```
HIVE.ID.RESET
```

#### `shn01.nodes`

**Type:** `table` (array)  
**Default:** `{}`  
**Description:** Node registry with node data

**Structure:**
```lua
{
    {id = "12AB", script = "SOLAR", defective = false},
    {id = "34CD", script = "REACTOR", defective = false},
    {id = "56EF", script = "STORAGE", defective = true, lastError = "timeout"}
}
```

**Example:**
```lua
local nodes = database:getKey("shn01", "nodes")
for i, nodeData in ipairs(nodes) do
    print(nodeData.id, nodeData.script)
end
```

#### `shn01.queueRateLimit`

**Type:** `number`  
**Default:** `10`  
**Description:** Maximum outbound messages per second

**Range:** 1-100 (recommended: 5-20)

**Example:**
```lua
-- Increase rate limit to 20 msg/sec
database:setKey("shn01", "queueRateLimit", 20)
```

**Considerations:**
- Higher values: More throughput but risk network congestion
- Lower values: More stable but slower response
- OpenComputers network relays have built-in limits

#### `shn01.hiveDebug`

**Type:** `number`  
**Default:** `0`  
**Description:** Debug verbosity level

**Levels:**
- `0` - No debug output
- `1` - Info (important events)
- `2` - Verbose (detailed operations)
- `3` - Very verbose (all operations)

**Example:**
```lua
database:setKey("shn01", "hiveDebug", 2)
```

**Console command:**
```
HIVE.DEBUG 2
```

#### `shn01.persistentId`

**Type:** `number`  
**Default:** `0`  
**Description:** Counter for `crypto.uniqueID()` generation

**Note:** Auto-incremented by system. Do not modify manually.

### `console` Namespace (UI Settings)

#### `console.commandHistory`

**Type:** `table` (array)  
**Default:** `{}`  
**Description:** Command history (up to 100 entries)

**Example:**
```lua
local history = database:getKey("console", "commandHistory")
```

#### `console.background`

**Type:** `number`  
**Default:** `0x000000`  
**Description:** Console background color (RGB hex)

**Example:**
```lua
database:setKey("console", "background", 0x1E1E1E)
```

#### `console.foreground`

**Type:** `number`  
**Default:** `0xFFFFFF`  
**Description:** Console foreground color (RGB hex)

**Example:**
```lua
database:setKey("console", "foreground", 0xCCCCCC)
```

## Port Assignments

OpenComputers modem ports used by SHN-01 protocols.

### Reserved Ports

| Port | Protocol | Sequences | Description |
|------|----------|-----------|-------------|
| 2011 | GATE | handshake, disconnect, bounce | Gateway protocol for connection management |
| 2015 | CORE | debug, error | Core protocol for system messages |
| 2022 | ECHO | heartbeat | Heartbeat monitoring |
| 2031 | FILE | transmit | File transmission |

### Legacy/Unused Ports

| Port | Status | Notes |
|------|--------|-------|
| 20 | Unused | Legacy reference, not actively used |

### Custom Protocol Ports

**Recommendation:** Use ports 2050 and higher for custom protocols.

**Example:**
```lua
-- Custom protocol
instance.port = 2050
```

**Guidelines:**
- Check existing ports before assigning
- Document custom ports in comments
- Update this file when adding new protocols

## File Naming Conventions

### Class Files

**Extension:** `.class`  
**Location:** Any (typically in protocol/network directories)  
**Purpose:** OOP class definitions  
**Pattern:** Must return a table with metatable and `:new()` method

**Example:** `node.class`, `protocol.class`, `outbound.class`

### Manifest Files

**Filename:** `manifest.lua`  
**Location:** Program and sequence directories  
**Purpose:** Metadata and initialization  
**Pattern:** Returns a table with `name`, `version`, etc.

**Example:** `programs/nano/manifest.lua`, `sequences/handshake/manifest.lua`

### Node Scripts

**Extension:** `.lua`  
**Location:** `shn-01/hive/node-scripts/`  
**Naming:** UPPERCASE (e.g., `SOLAR.lua`, `REACTOR.lua`)  
**Purpose:** Code executed on client nodes

### Core Modules

**Extension:** `.lua`  
**Location:** `shn-01/core/`  
**Naming:** lowercase (e.g., `tools.lua`, `database.lua`)  
**Purpose:** Core subsystems loaded via `inject()`

## Path Resolution

### Absolute Paths

Paths starting with `/` are absolute.

**Example:**
```lua
file.read("/home/config.txt")
```

### Relative Paths

Paths without leading `/` are resolved relative to `baseDir`.

**Example:**
```lua
-- If baseDir = "/home/app/"
include("config.lua")  -- Resolves to "/home/app/config.lua"
```

### Path Normalization

The `file.normalizePath()` function resolves `.` and `..`.

**Rules:**
- `.` - Current directory (removed)
- `..` - Parent directory (resolves upward)

**Example:**
```lua
file.normalizePath("/home/app/../config.txt")
-- Returns: "/home/config.txt"
```

### `baseDir` Behavior

The global `baseDir` variable tracks the current directory for relative includes.

**Automatically updated during:**
- `include(path)` - Sets to directory of included file
- `inject(path)` - Sets to directory of injected file
- Restored after include/inject completes

**Manual access:**
```lua
print(baseDir)  -- Current directory
```

### Helper Functions

#### `getAbsolutePath(relativePath, origin)`

**Parameters:**
- `relativePath` - Path to resolve
- `origin` - Base directory (defaults to `baseDir`)

**Returns:** Absolute path

**Example:**
```lua
local abs = getAbsolutePath("config.lua", "/home/app/")
-- Returns: "/home/app/config.lua"
```

## Performance Tuning

### Message Queue Rate Limiting

**Key:** `shn01.queueRateLimit`  
**Default:** 10 msg/sec  
**Range:** 1-100

**Tuning guidelines:**

| Node Count | Recommended Rate | Notes |
|------------|------------------|-------|
| 1-5 | 10 msg/sec | Default is fine |
| 6-15 | 15-20 msg/sec | Increase for more nodes |
| 16+ | 20+ msg/sec | Monitor for dropped packets |

**Symptoms of too-low rate:**
- High queue depth (visible in title bar)
- Slow response times
- Messages delayed

**Symptoms of too-high rate:**
- Dropped packets
- Network unreliability
- Relay overload messages

### TPS (Ticks Per Second)

**Target:** 20 TPS  
**Monitoring:** Title bar shows current TPS

**Factors affecting TPS:**
- Number of active nodes
- Event handler complexity
- Disk I/O frequency
- Network traffic

**Optimization tips:**
1. Reduce heartbeat frequency (edit heartbeat sequence)
2. Minimize disk writes (batch database saves)
3. Use `timer.delay()` for expensive operations
4. Profile event handlers (add timing logs)

### Memory Usage

**Monitoring:** Title bar shows current memory usage

**Typical usage:**
- Boot: ~500KB
- Idle: ~1MB
- Active (10 nodes): ~2-3MB

**Memory optimization:**
1. Clear old sessions regularly
2. Limit message buffer size (console)
3. Remove unused classes from `classBuffer`
4. Avoid large global tables

## Debug Settings

### Debug Levels

Set with `HIVE.DEBUG <level>` or `database:setKey("shn01", "hiveDebug", level)`.

#### Level 0: Off

No debug output. Recommended for production.

#### Level 1: Info

Important events:
- Node connections
- Session creation/completion
- Protocol initialization
- Errors

#### Level 2: Verbose

Detailed operations:
- Message processing
- Session state changes
- Queue operations
- Component detection

#### Level 3: Very Verbose

All operations:
- Every message received/sent
- Coroutine yields/resumes
- Database reads/writes
- Timer events

### Debug Output Format

**With node context:**
```
[HV-A3F2-ND-12AB-SOLAR] Message text
```

**Without node context:**
```
[System] Message text
```

### Debug Best Practices

1. **Development:** Use level 2 or 3
2. **Testing:** Use level 1
3. **Production:** Use level 0
4. **Troubleshooting:** Temporarily increase to level 2 or 3

## EEPROM Constraints

### Size Limit

**Maximum:** 4096 bytes  
**Actual limit:** ~4090 bytes (some overhead)

### Stage 1 Client Code

**File:** `shn-01/data/clientFlashStage1.lua`  
**Target size:** < 4096 bytes after minification

**Size testing:**
```
FLASH.SIZETEST
```

**Output:**
```
Stage 1 size: 3847 bytes (247 bytes remaining)
```

### Minification Strategies

Use `file.readWithIncludesMinified()` with appropriate minifier:

#### `minify.parse()` - Full minification
- **Compression:** Maximum (~60-70% reduction)
- **Speed:** Slowest
- **Use case:** Production EEPROM flashing

#### `minify.parseCheap()` - Medium minification
- **Compression:** Moderate (~40-50% reduction)
- **Speed:** Medium
- **Use case:** Development testing

#### `minify.parseVeryCheap()` - Light minification
- **Compression:** Minimal (~20-30% reduction)
- **Speed:** Fastest
- **Use case:** Debugging (preserves readability)

### Size Optimization Tips

1. **Remove comments** - Comments add significant size
2. **Shorten variable names** - Use single letters where possible
3. **Remove debug code** - No `print()` in production
4. **Inline small functions** - Reduce function call overhead
5. **Use local variables** - Faster and smaller
6. **Avoid string concatenation** - Use `table.concat()` for large strings

### Testing EEPROM Size

```lua
local code = file.readWithIncludesMinified(
    "shn-01/data/clientFlashStage1.lua",
    minify.parse,
    true
)

print("Size: " .. #code .. " bytes")
print("Remaining: " .. (4096 - #code) .. " bytes")
```

## Color Schemes

### Console Color Markup

Use `<c=0xRRGGBB>text</c>` for colored console output.

### Predefined Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Red | 0xFF0000 | Errors |
| Green | 0x00FF00 | Success |
| Yellow | 0xFFFF00 | Warnings |
| Cyan | 0x00FFFF | Info |
| Magenta | 0xFF00FF | Highlights |
| White | 0xFFFFFF | Normal text |
| Gray | 0x808080 | Secondary text |

### Example Usage

```lua
console:log("<c=0xFF0000>Error:</c> Operation failed")
console:log("<c=0x00FF00>Success:</c> Node connected")
console:log("<c=0xFFFF00>Warning:</c> Low memory")
console:log("<c=0x00FFFF>Info:</c> System ready")
```

### Custom Color Schemes

Modify console background/foreground in database:

```lua
-- Dark theme (default)
database:setKey("console", "background", 0x000000)
database:setKey("console", "foreground", 0xFFFFFF)

-- Light theme
database:setKey("console", "background", 0xFFFFFF)
database:setKey("console", "foreground", 0x000000)

-- Solarized Dark
database:setKey("console", "background", 0x002B36)
database:setKey("console", "foreground", 0x839496)
```

## Network Configuration

### Modem Configuration

Modems are opened automatically by protocols. Manual configuration is not required.

**Check open ports:**
```lua
local modem = getComponent("modem")
for i = 1, 65535 do
    if modem.isOpen(i) then
        print("Port " .. i .. " is open")
    end
end
```

### Broadcast vs. Direct Messages

**Broadcast:**
```lua
modem.broadcast(port, ...)
```
- Reaches all nodes on network
- Used for most hive→node communication
- Simple, no addressing needed

**Direct (send):**
```lua
modem.send(address, port, ...)
```
- Reaches specific node
- More efficient for large networks
- Requires node address

**SHN-01 default:** Uses broadcast for simplicity.

### Network Distance

OpenComputers network signals have range limits:

| Network Card Tier | Range |
|-------------------|-------|
| Tier 1 | 16 blocks |
| Tier 2 | 400 blocks |
| Tier 3 | 400 blocks |

**Network relays** extend range by repeating signals.

**Tip:** Monitor `distance` parameter in `onNetMessageReceived` to detect range issues.

### Network Relay Limits

Network relays have built-in rate limiting:
- **Default:** ~20 packets/sec
- **Exceeded:** Packets dropped silently

**SHN-01 solution:** Outbound message queue with rate limiting (`queueRateLimit`).

### Wireless vs. Wired

**Wireless network cards:**
- Unlimited connections
- Range-limited
- Subject to relay limits

**Wired network:**
- Cable-connected
- No range limit
- Higher reliability

**Recommendation:** Use wired for hive server, wireless for nodes.

## Configuration Best Practices

### Development

```lua
database:setKey("shn01", "hiveDebug", 3)
database:setKey("shn01", "queueRateLimit", 5)
```

### Testing

```lua
database:setKey("shn01", "hiveDebug", 1)
database:setKey("shn01", "queueRateLimit", 10)
```

### Production

```lua
database:setKey("shn01", "hiveDebug", 0)
database:setKey("shn01", "queueRateLimit", 15)
```

### Backup Strategy

**Critical files:**
- `/shn-01/data/` - All database state
- `/shn-01/hive/node-scripts/` - Custom node scripts
- `/programs/` - Custom programs

**Backup command (in-game):**
```lua
-- Create backup directory
filesystem.makeDirectory("/home/backup")

-- Copy database
filesystem.copy("/shn-01/data/", "/home/backup/data/")
```

### Restore Strategy

1. Copy backup to `/home/backup/`
2. Stop hive (`COMPUTER.SHUTDOWN`)
3. Replace `/shn-01/data/` with backup
4. Start hive

## Troubleshooting Configuration Issues

### Issue: Nodes won't connect

**Check:**
1. Port 2011 is open (GATE protocol)
2. Network cards are same tier or compatible
3. Hive and nodes on same network
4. Debug level: `HIVE.DEBUG 2`

### Issue: Slow response times

**Check:**
1. Queue rate limit (try increasing)
2. TPS (should be ~20)
3. Network relay limits
4. Number of active nodes

### Issue: High memory usage

**Check:**
1. Number of active sessions
2. Message buffer size (console)
3. Command history size
4. Unused classes in `classBuffer`

### Issue: EEPROM won't flash

**Check:**
1. Code size: `FLASH.SIZETEST`
2. Target node has EEPROM component
3. Network connectivity
4. Debug output: `HIVE.DEBUG 2`

## Next Steps

- **[API Reference](api-reference.md)** - Detailed API documentation
- **[Development Guide](development-guide.md)** - Creating custom components
- **[Getting Started](getting-started.md)** - Installation and basic operations
