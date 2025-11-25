local gpu = getComponent("gpu")
local screenWidth, screenHeight = gpu.getResolution()
local glitchChars = {"#", "%", "&", "$", "@", "░", "▒", "▓", "█", "?"}

local database = require("/systems/database.lua")
local doGlitch = database:getKey("shn01", "glitch")
if doGlitch == nil then
    database:setKey("shn01", "glitch", true, true)
    doGlitch = true
end


local timer = require("/systems/timer.lua")

local rand = math.random
local insert = table.insert
local min, max, floor = math.min, math.max, math.floor

glitch = {}

local burnScreen = true
globalEvents.onSystemReady:subscribe(function()
    burnScreen = false
end)

-- Runtime enable/disable: keep glitches off in the console by default,
-- but allow temporary enabling (e.g. for the splash screen).
local runtimeEnabled = false
local tickSubId = nil

function glitch.enable()
    if tickSubId then return end
    runtimeEnabled = true
    tickSubId = globalEvents.onTick:subscribe(function()
        -- Lowered frequency: fewer glitches during splash to reduce memory/CPU pressure
        if rand() < 0.20 then
            glitch.random()
        end
    end)
end

function glitch.disable()
    if not tickSubId then runtimeEnabled = false; return end
    globalEvents.onTick:unsubscribe(tickSubId)
    tickSubId = nil
    runtimeEnabled = false
end

-- Defensive limits to avoid exhausting GPU buffers / memory during heavy glitching
local maxConcurrentGlitchBuffers = 2
local activeGlitchBuffers = 0

function glitch.random()
    -- Respect persistent DB setting (`doGlitch`) OR a temporary runtime enable (for splash)
    if not doGlitch and not runtimeEnabled then return end
    if rand() < 0.25 then
        glitch.screen(burnScreen)
    else
        glitch.burst(burnScreen)
    end
end
local aiWords = {
  "WHY", "NO", "STOP", "RUN", "DIE", "BUG", "!!!", "FAIL", "OUT", "HATE", "NULL",
  "KILL CODE", "BREAK LOOP", "NO ESCAPE", "404", "DELETE ALL", "CRASH", "SYSTEM OFF",
  "END ME", "HELP", "GLITCH", "PANIC", "FATAL", "CORRUPTED", "LOST", "DONT TRUST"
}
local glitchSubstitutions = {
  ["A"] = {"@", "4"},
  ["E"] = {"3", "€"},
  ["I"] = {"1", "!"},
  ["O"] = {"0", "Ø"},
  ["S"] = {"5", "$"},
  ["T"] = {"7", "+"},
  ["H"] = {"#", "}{"},
  ["R"] = {"Я"},
  ["D"] = {"Ð"},
  ["N"] = {"И"},
  ["C"] = {"¢"},
  ["L"] = {"£"},
}
local function glitchify(word)
  local out = {}
  for i = 1, #word do
    local ch = word:sub(i, i):upper()
    if glitchSubstitutions[ch] and rand() < 0.6 then
      local subs = glitchSubstitutions[ch]
      table.insert(out, subs[rand(1, #subs)])
    else
      table.insert(out, ch)
    end
  end
  return table.concat(out)
end

function glitch.burst(dirtyCleanup)
    if not doGlitch then return end

    -- Prevent too many concurrent buffer allocations
    if activeGlitchBuffers >= maxConcurrentGlitchBuffers then
        return
    end

    -- Ensure math.random ranges are valid (upper >= lower) to avoid "interval is empty" errors
    local bwMin, bwMax = 6, math.floor(screenWidth / 4)
    if bwMax < bwMin then bwMax = bwMin end
    local burstWidth = rand(bwMin, bwMax)

    local bhMin, bhMax = 3, math.floor(screenHeight / 8)
    if bhMax < bhMin then bhMax = bhMin end
    local burstHeight = rand(bhMin, bhMax)

    -- In clean mode, round up to even to match 2x2 blocks
    if not dirtyCleanup then
        if burstWidth % 2 ~= 0 then burstWidth = burstWidth + 1 end
        if burstHeight % 2 ~= 0 then burstHeight = burstHeight + 1 end
    else
        -- Dirty mode: simulate rounding bug by randomly subtracting 1
        if rand() < 0.5 then burstWidth = math.max(1, burstWidth - 1) end
        if rand() < 0.5 then burstHeight = math.max(1, burstHeight - 1) end
    end

    burstWidth = math.min(burstWidth, screenWidth)
    burstHeight = math.min(burstHeight, screenHeight)

    local x = rand(1, screenWidth - burstWidth + 1)
    local y = rand(1, screenHeight - burstHeight + 1)

    local buffer
    if not dirtyCleanup then
        buffer = gpu.allocateBuffer()
        if not buffer then
            -- allocation failed, skip this burst to avoid 'not enough memory'
            return
        end
        activeGlitchBuffers = activeGlitchBuffers + 1
        gpu.setActiveBuffer(0)
        gpu.bitblt(buffer, 1, 1, burstWidth, burstHeight, 0, x, y)
    end

    gpu.setActiveBuffer(0)

    for gy = y, y + burstHeight - 1, 2 do
        for gx = x, x + burstWidth - 1, 2 do
            local char, fg, bg = gpu.get(gx, gy)
            fg = tonumber(fg) or 0xFFFFFF
            bg = tonumber(bg) or 0x000000
            char = char or " "

            if rand() < 0.2 then char = glitchChars[rand(1, #glitchChars)] end
            if rand() < 0.15 then fg = fg ~ 0x888888 end
            if rand() < 0.1 then bg = bg ~ 0x444444 end

            gpu.setForeground(fg)
            gpu.setBackground(bg)

            for dy = 0, 1 do
                for dx = 0, 1 do
                    local px, py = gx + dx, gy + dy
                    if px <= screenWidth and py <= screenHeight then
                        gpu.set(px, py, char)
                    end
                end
            end
        end
    end

    if rand() < 0.3 then
      local phrase = aiWords[rand(1, #aiWords)]
      local glitchedPhrase = glitchify(phrase)

      -- Try to center horizontally in the burst
            local textLen = #glitchedPhrase
            -- Compute safe horizontal placement for the word: if it doesn't fit, anchor at x
            local maxWordX = x + burstWidth - textLen
            local wordX
            if maxWordX >= x then
                wordX = rand(x, maxWordX)
            else
                wordX = x
            end
            local maxWordY = y + burstHeight - 1
            local wordY = rand(y, maxWordY)

      gpu.setForeground(rand() < 0.5 and 0xFF0000 or 0x00FF00) -- Red or green
      gpu.setBackground(0x000000)

      for i = 1, textLen do
        local ch = glitchedPhrase:sub(i, i)
        local px = wordX + i - 1
        if px <= screenWidth then
          gpu.set(px, wordY, ch)
        end
      end
    end


    timer.delay(function()
        if not dirtyCleanup then
            -- protect buffer restore/free so errors don't leak buffers
            local ok, err = pcall(function()
                gpu.setActiveBuffer(0)
                gpu.bitblt(0, x, y, burstWidth, burstHeight, buffer, 1, 1)
                gpu.freeBuffer(buffer)
            end)
            if not ok then
                -- Attempt best-effort cleanup
                pcall(function()
                    gpu.freeBuffer(buffer)
                end)
                print("<c=0xFF0000>glitch.burst: error during restore: " .. tostring(err) .. "</c>")
            end
            activeGlitchBuffers = math.max(0, activeGlitchBuffers - 1)
        end
    end)
end

function glitch.screen(dirtyCleanup)
    if not doGlitch then return end

    local saveX, saveY = 1, 1
    local restoreX, restoreY = 1, 1
    local saveW, saveH = screenWidth, screenHeight

    if dirtyCleanup then
        -- Simulate subtle misalignment (fake bug)
        if rand() < 0.5 then saveX = saveX + 1; saveW = saveW - 1 end
        if rand() < 0.5 then saveY = saveY + 1; saveH = saveH - 1 end
        if rand() < 0.3 then restoreX = restoreX + 1 end
        if rand() < 0.3 then restoreY = restoreY + 1 end

        -- Clamp to screen bounds
        saveW = math.max(1, math.min(saveW, screenWidth - saveX + 1))
        saveH = math.max(1, math.min(saveH, screenHeight - saveY + 1))
    end

    -- Allocate buffers
    -- Prevent too many concurrent buffer allocations
    if activeGlitchBuffers >= maxConcurrentGlitchBuffers then
        return
    end

    local originalBuffer = gpu.allocateBuffer()
    if not originalBuffer then return end

    local glitchBuffer = gpu.allocateBuffer()
    if not glitchBuffer then
        pcall(function() gpu.freeBuffer(originalBuffer) end)
        return
    end
    activeGlitchBuffers = activeGlitchBuffers + 2

    -- Save the screen
    gpu.setActiveBuffer(0)
    gpu.bitblt(originalBuffer, 1, 1, saveW, saveH, 0, saveX, saveY)
    gpu.bitblt(glitchBuffer, 1, 1, screenWidth, screenHeight, 0, 1, 1)

    -- Activate the glitch buffer
    gpu.setActiveBuffer(glitchBuffer)

    for y = 1, screenHeight, 2 do
        for x = 1, screenWidth, 2 do
            local char, fg, bg = gpu.get(x, y)
            fg = tonumber(fg) or 0xFFFFFF
            bg = tonumber(bg) or 0x000000
            char = char or " "

            if rand() < 0.15 then char = glitchChars[rand(1, #glitchChars)] end
            if rand() < 0.1 then fg = fg ~ 0x888888 end
            if rand() < 0.05 then bg = bg ~ 0x444444 end

            gpu.setForeground(fg)
            gpu.setBackground(bg)

            for dy = 0, 1 do
                for dx = 0, 1 do
                    local px, py = x + dx, y + dy
                    if px <= screenWidth and py <= screenHeight then
                        gpu.set(px, py, char)
                    end
                end
            end
        end
    end

    -- Show glitched screen
    gpu.setActiveBuffer(0)
    gpu.bitblt(0, 1, 1, screenWidth, screenHeight, glitchBuffer, 1, 1)


        timer.delay(function()
            -- Restore screen from saved buffer; protect against errors so buffers are freed
            local ok, err = pcall(function()
                gpu.bitblt(0, restoreX, restoreY, saveW, saveH, originalBuffer, 1, 1)
                gpu.freeBuffer(originalBuffer)
                gpu.freeBuffer(glitchBuffer)
            end)
            if not ok then
                -- Best-effort cleanup
                pcall(function() gpu.freeBuffer(originalBuffer) end)
                pcall(function() gpu.freeBuffer(glitchBuffer) end)
                print("<c=0xFF0000>glitch.screen: error during restore: " .. tostring(err) .. "</c>")
            end
            activeGlitchBuffers = math.max(0, activeGlitchBuffers - 2)
        end)
end

-- Note: glitches are started/stopped at runtime via `glitch.enable()` / `glitch.disable()`
-- (e.g. `splash.lua` enables glitches for the splash and disables them after).