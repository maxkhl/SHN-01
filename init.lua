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
local baseLibPath = "/baselib.lua"
local fileSystem = component.proxy(computer.getBootAddress())
local stream, reason = fileSystem.open(baseLibPath, "r")
if not stream then error("Failed to open " .. baseLibPath .. ": " .. tostring(reason)) end
local chunks = {}
local newChunk = fileSystem.read(stream, 4096)
while newChunk do
    table.insert(chunks, newChunk)
    newChunk = fileSystem.read(stream, 4096)
end
fileSystem:close(stream)
local baseLibCode = table.concat(chunks)
local baseLib = load(baseLibCode, "=" .. baseLibPath, nil, _G)
if not baseLib then
    error("Failed to load baselib from " .. baseLibPath)
end
baseLib()

-- INJECT THE CORE AND START SHN-01
inject("/shn-01/core.lua")
