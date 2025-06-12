local database = require("/systems/database.lua")
local skipSplash = database:getKey("shn01", "skipSplash")
if skipSplash == nil then
    database:setKey("shn01", "skipSplash", true, true)
    skipSplash = true
end

if skipSplash then
    local timer = require("/systems/timer.lua")
    timer.delay(function() globalEvents.onSystemReady:fire() end) -- Notify that the system is ready immediately
else
    local gpu = getComponent("gpu")

    local screenWidth, screenHeight = gpu.getResolution()


    local splashLogo = nil
    if screenHeight < 25 then -- reduced screen size so reduce splashLogo
        splashLogo = file.readLines("/shn-01/data/splashSmall.txt")
    else
        splashLogo = file.readLines("/shn-01/data/splash.txt")
    end

    gpu.fill(1, 1, screenWidth, screenHeight, " ")




    -- Find max line length
    local maxLineLength = 0
    for i = 1, #splashLogo do
        local length = visualLength(splashLogo[i])
        if length > maxLineLength then
            maxLineLength = length
        end
    end

    -- Compute top-left starting coordinates
    local startX = math.floor((screenWidth - maxLineLength) / 2)
    local startY = math.floor((screenHeight - #splashLogo) / 2)

    -- Draw each line using gpu.set
    for i = 1, #splashLogo do
        gpu.set(startX, startY + i, splashLogo[i])
    end


    local timer = require("/systems/timer.lua")
    timer.add(10, function()
        globalEvents.onSystemReady:fire() -- Notify that the system is ready after the splash screen
    end)
end
