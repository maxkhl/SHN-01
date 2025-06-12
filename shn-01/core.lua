--[[
    SHN-01 core file
        This file contains the core functions of the SHN-01 system
        It is loaded by the main file and provides the basic functionality of the system.
        It is not meant to be modified by the user.
]] --

-- Returns the given component by name
function getComponent(name)
    for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

inject("tools.lua")
inject("colorTools.lua")

-- Create global events so systems can dock onto them already

inject("globalEvents.lua")

inject("glitch.lua")

inject("clipboard.lua")

-- Loads the console
local console = require("/systems/console.lua")

inject("clientFlash.lua")


-- Overrides the default print function to use the console
function print(msg)
    console:log(msg)
end

-- Overrides the default error function to use the console
function error(msg, depth)
    depth = depth or 0
    local info = debug.getinfo(3 + depth, "Sl") -- Get info about the *caller*
    console:logError((info.short_src or "unknown") ..
    ":" .. (info.currentline or "unknown") .. "<c=0xFF00FF>></c>" .. msg)
end

inject("splash.lua")

-- Load further libraries
inject("commands.lua")

-- Main server startup
inject("autostart.lua")

-- This will keep the system running and handle events/timing
inject("mainLoop.lua")
