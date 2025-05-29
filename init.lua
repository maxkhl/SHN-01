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

-- STARTING WITH NECESSARY FUNCTIONS TO BOOTSTRAP THE SYSTEM
baseDir = ""

-- Returns the given component by name
function getComponent(name)
    for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

local printCnt = 1
function print(msg)
  local gpu = getComponent("gpu")
  gpu.set(1, printCnt, tostring(msg))
  printCnt = printCnt + 1
end

-- Returns the file system the os is running on
function fileSystem()
    return component.proxy(computer.getBootAddress())
end

-- Reads a file and returns its content
file = {}
function file.read(absolutePath)
    if not absolutePath then error("No file path given") return end
    local fileSystem = fileSystem()
    local stream, reason = fileSystem.open(absolutePath, "r")
    if not stream then error("Failed to open " .. absolutePath .. ": " .. tostring(reason)) end

    local chunks = {}
    local newChunk = fileSystem.read(stream, 4096)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, 4096)
    end
    fileSystem:close(stream)
    return table.concat(chunks), absolutePath
end

-- Loads a lua file, executes it and returns the result
function includeCore(absolutePath)
    local code, path = file.read(absolutePath)
    local chunk, err = load(tostring(code), "=" .. path, nil, _G)
    if not chunk then error("Failed to compile " .. path .. ": " .. tostring(err)) end
    return chunk()
end

-- Loads the core system files
includeCore("/shn-01/core.lua")
