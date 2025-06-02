
--[[    
    SHN-01 core file
        This file contains the core functions of the SHN-01 system
        It is loaded by the main file and provides the basic functionality of the system.
        It is not meant to be modified by the user.
]]--

includeCore("/shn-01/tools.lua")
includeCore("/shn-01/file.lua")
includeCore("/shn-01/include.lua")
includeCore("/shn-01/colorTools.lua")

-- Create global events so systems can dock onto them already

includeCore("/shn-01/oop.lua")
includeCore("/shn-01/globalEvents.lua")

includeCore("/shn-01/glitch.lua")
includeCore("/shn-01/splash.lua")

includeCore("/shn-01/clipboard.lua")

-- Give it a bit so we can see the splash screen
for i=1, 10 do glitch.random() end

-- Loads the console
local console = require("/systems/console.lua")

includeCore("/shn-01/clientFlash.lua")


-- Overrides the default print function to use the console
function print(msg)
    console:log(msg)
end

-- Overrides the default error function to use the console
function error(msg)
    console:logError(msg)
end

-- Load further libraries
includeCore("/shn-01/commands.lua")

-- Main server startup
includeCore("/shn-01/autostart.lua")

-- This will keep the system running and handle events/timing
includeCore("/shn-01/mainLoop.lua")