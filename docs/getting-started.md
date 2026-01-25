# Getting Started with SHN-01

This guide walks you through installing, configuring, and running SHN-01 for the first time.

## Prerequisites

- **OpenComputers mod** installed in Minecraft
- A computer (Tier 1 or higher) for the hive server
- At least one additional computer (Tier 1 minimum) for a node
- Network cards in all computers
- Hard drives with sufficient space

## Installation

### 1. Prepare the Hive Server

The hive server is your central control system. It manages all connected nodes.

1. **Copy files to the server**
   - Copy the entire SHN-01 repository to your OpenComputers computer
   - Recommended location: `/home/shn-01/`

2. **Boot the system**
   - Run `/home/shn-01/init.lua` to start the hive
   - The system will:
     - Initialize the boot system
     - Load core subsystems
     - Generate a unique Hive ID
     - Start network protocols
     - Display the console interface

3. **Verify installation**
   - You should see the SHN-01 console with a command prompt
   - Check the title bar for system stats (TPS, memory, network)
   - Run `HIVE.ID.SHOW` to display your Hive ID (e.g., `HV-A3F2`)

### 2. First Boot Walkthrough

When SHN-01 boots for the first time:

1. **Bootstrap phase** (`init.lua`)
   - Loads minimal file system utilities
   - Sets up `include()` and `inject()` functions
   - Establishes class system
   - Loads core boot files

2. **Core initialization** (`shn-01/core/boot.lua`)
   - Injects all core subsystems:
     - Console (terminal UI)
     - Database (persistence)
     - Events (pub/sub system)
     - Timer (scheduled callbacks)
     - Commands (built-in commands)
     - Crypto (ID generation)

3. **Hive startup** (`shn-01/hive/hive.lua`)
   - Generates or loads Hive ID
   - Initializes node registry
   - Loads network protocols (GATE, FILE, ECHO, CORE)
   - Opens modem ports (2011, 2022, 2015, 2031)
   - Broadcasts `SERVER_RESTART` to notify existing nodes

4. **Autostart** (`shn-01/core/autostart.lua`)
   - Scans `/programs/` for installed programs
   - Registers program commands

5. **Main loop** (`shn-01/core/mainLoop.lua`)
   - Enters event loop
   - Polls OpenComputers signals
   - Dispatches to `globalEvents`
   - Updates screen title bar

## Flashing Your First Node

Nodes are remote computers that connect to your hive. They run client code stored in EEPROM.

### Prepare the Node Computer

1. **Install EEPROM and network card**
   - Node needs an EEPROM component
   - Node needs a network card (same network as hive)

2. **Note the node's address**
   - Power on the node briefly
   - Run `component.list()` on the hive to see network cards
   - Identify the node's network card address (e.g., `a1b2c3d4-...`)

### Flash the Node from Hive Console

1. **Run the flash command**
   ```
   FLASH.NODE <node-address> <script-name>
   ```
   Example:
   ```
   FLASH.NODE a1b2c3d4-e5f6-7890-abcd-ef1234567890 SOLAR
   ```

2. **What happens during flashing:**
   - Hive generates a unique Node ID (e.g., `HV-A3F2-ND-12AB`)
   - Client code (Stage 1) is minified to fit in EEPROM (4096 bytes)
   - Hive ID and Node ID are injected into the code
   - EEPROM is written to the target node
   - Node automatically reboots with new code

3. **Verify flashing:**
   - Node should broadcast a handshake on port 2011
   - Hive responds and authorizes the node
   - Node downloads Stage 2 code via the `transmit` sequence
   - Node joins the hive and appears in the node registry

### Check Node Connection

1. **View connected nodes**
   ```
   HIVE.NODES.LIST
   ```
   Output shows:
   - Node ID
   - Full name (e.g., `HV-A3F2-ND-12AB-SOLAR`)
   - Last seen timestamp
   - Authorized status

2. **Monitor heartbeats**
   - Nodes send heartbeat messages every 30 seconds
   - Check debug output with `HIVE.DEBUG 1`

## Running Node Scripts

Node scripts are Lua programs that run on client nodes. They have access to local components and can communicate with the hive.

### Deploy a Script

Node scripts are specified during the flashing process:

```
FLASH.NODE <address> <script-name>
```

The script name corresponds to a file in `shn-01/hive/node-scripts/`:
- `SOLAR` → `shn-01/hive/node-scripts/SOLAR.lua`

### Available Node APIs (Stage 2)

Nodes running Stage 2 have access to:

- **Standard Lua 5.3** - All built-in functions
- **OpenComputers components** - `component.proxy()`, `component.list()`
- **Network messaging** - Send/receive via protocols
- **Boot system** - `include()`, `inject()`, class system
- **Timer system** - Schedule callbacks
- **Error handling** - Auto-restart after repeated errors

### Example Node Script

Create `shn-01/hive/node-scripts/EXAMPLE.lua`:

```lua
-- Simple node script that prints component count
local componentCount = 0
for address in component.list() do
    componentCount = componentCount + 1
end

print("Node initialized with " .. componentCount .. " components")

-- Node script runs once, then node enters idle mode
-- Idle mode: heartbeat every 30s, process hive messages
```

### Script Execution Flow

1. Node completes handshake and downloads Stage 2
2. Stage 2 loads the assigned script (from database `nodeData.script`)
3. Script executes once
4. Node enters idle mode (heartbeat loop)

## Basic Console Commands

### System Commands

- `COMPUTER.INFO` - Show system information
- `COMPUTER.REBOOT` - Reboot the hive server
- `COMPUTER.SHUTDOWN` - Shut down the hive server
- `HDD.SPACE` - Display storage usage
- `COMPONENT.LIST` - List all components
- `GLOBALS` - Show global variables

### Hive Commands

- `HIVE.ID.SHOW` - Display Hive ID
- `HIVE.ID.RESET` - Generate new Hive ID (disconnects all nodes)
- `HIVE.NODES.LIST` - List connected nodes
- `HIVE.DEBUG <level>` - Set debug verbosity (0-3)

### Flash Commands

- `FLASH.NODE <address> <script>` - Flash EEPROM on target node
- `FLASH.SIZETEST` - Test client code size (must fit in 4096 bytes)

### Program Commands

- `NANO <filepath>` - Edit a file (nano text editor)

### Command History

- **Up/Down arrows** - Navigate command history
- History is persisted to database (`console.commandHistory`)

## Troubleshooting

### Hive won't start

- **Check Lua version**: OpenComputers uses Lua 5.3
- **Verify file paths**: Ensure `init.lua` is in the root directory
- **Check components**: Hive needs screen, GPU, keyboard, network card

### Node won't connect

- **Network card**: Node and hive must be on same network
- **EEPROM size**: Stage 1 must fit in 4096 bytes (run `FLASH.SIZETEST`)
- **Port conflicts**: Ensure no other software is using ports 2011, 2022, 2015, 2031
- **Check debug logs**: Run `HIVE.DEBUG 3` for verbose output

### Node marked defective

Nodes are marked defective after errors. Check:
- `HIVE.NODES.LIST` to see defective status
- Node's last error message (stored in database)
- Node may need re-flashing if code is corrupted

### Low TPS (ticks per second)

- **Too many nodes**: Each node sends heartbeat every 30s
- **Queue overload**: Check message queue stats in title bar
- **Rate limiting**: Adjust with database key `shn01.queueRateLimit`

## Next Steps

- **[Architecture Overview](architecture.md)** - Understand how SHN-01 works internally
- **[Development Guide](development-guide.md)** - Create custom protocols and sequences
- **[API Reference](api-reference.md)** - Detailed API documentation
- **[Configuration](configuration.md)** - Tune settings for your network

## Tips

- **Start small**: Test with one node before scaling to many
- **Use debug mode**: `HIVE.DEBUG 1` provides useful connection info
- **Monitor resources**: Watch memory usage in title bar
- **Backup database**: `/shn-01/data/` contains all persistent state
- **Test EEPROM size**: Always run `FLASH.SIZETEST` before flashing if you modify client code
