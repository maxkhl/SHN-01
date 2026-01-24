--[[
    SHN-01 boot file
        This file contains the core functions of the SHN-01 system
        It is loaded by the main file and provides the basic functionality of the system.
        It is not meant to be modified by the user.
]] --

-- Returns the given component by name
function getComponent(name)
    for a, c in pairs(component.list(name)) do return component.proxy(a), a end
end

inject("tools.lua")
inject("crypto.lua")
inject("colorTools.lua")

-- Create global events so systems can dock onto them already
inject("globalEvents.lua")

-- Load keyboard handler
inject("keyboard.lua")

inject("database.lua")

inject("minify.lua")

-- Initialize the screen
screen = new("screen", 1, 1, screenWidth, screenHeight)
globalEvents.onSystemReady:subscribe(function()
  screen:start()
end)

-- Initialize the console and load it into the screen
console = new("console", screen)
screen:setView(console)
screen.mainview = console -- Always return to console

inject("glitch.lua")

-- uncomment to get glitches in console
-- glitch.enable()

inject("clipboard.lua")

inject("clientFlash.lua")

inject("timer.lua")


-- Overrides the default print function to use the console
function print(msg)
    console:log(msg)
end

-- Overrides the default error function to use the console
function error(msg, depth, prefix)
    depth = depth or 0
    local info = debug.getinfo(3 + depth, "Sl") -- Get info about the *caller*
    console:logError((info.short_src or "unknown") ..
    ":" .. (info.currentline or "unknown") .. "<c=0xFF00FF>></c>" .. msg, prefix)
end

inject("splash.lua")

-- Load further libraries
inject("commands.lua")

-- Startup hive server when system is ready
globalEvents.onSystemReady:subscribe(function()
    include("../hive/hive.lua")
end)


-- Autostart systems and programs
inject("autostart.lua")

-- This will keep the system running and handle events/timing
inject("mainLoop.lua")
