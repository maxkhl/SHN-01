--[[     Welcome to SHN-O1
  ███████╗██╗  ██╗███╗   ██╗       ██████╗  ██╗
  ██╔════╝██║  ██║████╗  ██║      ██╔═████╗███║
  ███████╗███████║██╔██╗ ██║█████╗██║██╔██║╚██║
  ╚════██║██╔══██║██║╚██╗██║╚════╝████╔╝██║ ██║
  ███████║██║  ██║██║ ╚████║      ╚██████╔╝ ██║
  ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝       ╚═════╝  ╚═╝
                                                                                    
  VERSION      : v0.1-dev
  LANGUAGE     : Lua 5.3 (OpenComputers)
  LICENSE      : MIT

  █ SHN-01 IS A MINIMALIST, TERMINAL-DRIVEN CONTROL SYSTEM FOR  
    MINECRAFT'S OPENCOMPUTERS, BUILT TO SERVE AS A CENTRAL COMMAND  
    HUB FOR A NETWORK OF DISTRIBUTED NODES EQUIPPED WITH LINKED EEPROMs.

  █ IT PROVIDES REMOTE FLASHING CAPABILITIES AND REAL-TIME CODE  
    EXECUTION ON EXTERNAL COMPUTERS, TRANSFORMING THEM INTO  
    PROGRAMMABLE, ADAPTABLE AGENTS WITHIN A UNIFIED AUTOMATION ECOSYSTEM.

  █ DESIGNED FOR HIGH PERFORMANCE AND MODULARITY WITHIN A SANDBOXED LUA  
    ENVIRONMENT, IT FOCUSES ON KEYBOARD-FIRST INTERACTION THROUGH A  
    RETRO-STYLE CONSOLE INTERFACE.

  █ SHN-01 ENABLES SEAMLESS ORCHESTRATION AND MANAGEMENT OF  
    COMPLEX FACTORY AUTOMATION SETUPS AND AUTONOMOUS DRONE SWARMS,  
    PROVIDING A SINGLE CONTROL LAYER FOR INTELLIGENT DEVICE SWARMS  
    WITH LIVE UPDATES AND TELEMETRY.
    
  █ REQUIRING ONLY MINIMAL RESOURCES, SHN-01 RUNS ENTIRELY ON TIER 1  
    HARDWARE, MAKING IT ACCESSIBLE, LIGHTWEIGHT, AND IDEAL FOR  
    DEPLOYMENT IN CONSTRAINED OR EARLY-GAME ENVIRONMENTS.

]]--

-- GLOBAL BASE DIRECTORY FOR RELATIVE INCLUDES/INJECTS
baseDir = ""

-- STARTING WITH BOOTSTRAPPING THE BASELIB
-- THIS WILL ENABLE THE SYSTEM TO LOAD FILES AND CLASSES PROPERLY
-- BASELIB CONTAINS ALL THE NECESSARY FUNCTIONS TO LOAD AND MANAGE THE SYSTEM

-- PARAMETERIZED FILE LOADER FOR BOOTSTRAP
local fileSystem = component.proxy(computer.getBootAddress())
local function loadAndExecuteFile(filePath, chunkSize)
    chunkSize = chunkSize or 4096
    local stream, reason = fileSystem.open(filePath, "r")
    if not stream then error("Failed to open " .. filePath .. ": " .. tostring(reason)) end
    local chunks = {}
    local newChunk = fileSystem.read(stream, chunkSize)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, chunkSize)
    end
    fileSystem.close(stream)
    local code = table.concat(chunks)
    local loaded, loadError = load(code, "=" .. filePath, nil, _G)
    if not loaded then
        error("Failed to load " .. filePath .. ": " .. tostring(loadError))
    end
    return loaded()
end

loadAndExecuteFile("/shn-01/core/boot/file.lua")
loadAndExecuteFile("/shn-01/core/boot/include.lua")
loadAndExecuteFile("/shn-01/core/boot/require.lua")
loadAndExecuteFile("/shn-01/core/boot/oop.lua")

-- INJECT THE CORE AND START SHN-01
inject("/shn-01/core/boot.lua")
