local gpu = getComponent("gpu")
clipboard = ""
local mark = {}
local oldPoints = {}

-- Save original characters so we can restore
local function saveChar(x, y)
    local char, fg, bg = gpu.get(x, y)
    if not char or char == "" then char = " " end
    oldPoints[x .. "," .. y] = {char = char, fg = fg, bg = bg}
end

-- Restore previously saved characters
local function restoreOldPoints()
    for key, data in pairs(oldPoints) do
        local x, y = key:match("([^,]+),([^,]+)")
        x, y = tonumber(x), tonumber(y)
        gpu.setForeground(data.fg)
        gpu.setBackground(data.bg)
        gpu.set(x, y, data.char)
    end
    oldPoints = {}
end

-- Invert the color of a single character
local function invertPoint(x, y)
    saveChar(x, y)
    local char, fg, bg = gpu.get(x, y)
    gpu.setForeground(bg)
    gpu.setBackground(fg)
    gpu.set(x, y, char or " ")
    gpu.setForeground(fg)
    gpu.setBackground(bg)
end

-- Draw just the start and end markers
local function drawDragEndpoints()
    restoreOldPoints()
    if mark.start then
        invertPoint(mark.start.x, mark.start.y)
    end
    if mark.ending and (mark.ending.x ~= mark.start.x or mark.ending.y ~= mark.start.y) then
        invertPoint(mark.ending.x, mark.ending.y)
    end
end

-- Draw the full selection (only one line)
local function drawFullSelection()
    restoreOldPoints()
    if not (mark.start and mark.ending) then return end
    if mark.start.y ~= mark.ending.y then return end

    local y = mark.start.y
    local x1 = math.min(mark.start.x, mark.ending.x)
    local x2 = math.max(mark.start.x, mark.ending.x)

    for x = x1, x2 do
        invertPoint(x, y)
    end
end

-- Copy characters into clipboard, then clear visual mark
local function copyToClipboard()
    if not (mark.start and mark.ending) then return end
    if mark.start.y ~= mark.ending.y then return end

    local y = mark.start.y
    local x1 = math.min(mark.start.x, mark.ending.x)
    local x2 = math.max(mark.start.x, mark.ending.x)

    clipboard = ""
    for x = x1, x2 do
        local char = gpu.get(x, y)
        clipboard = clipboard .. (char or " ")
    end

    -- Remove mark from screen
    restoreOldPoints()
    mark = {}
end

-- Paste clipboard at a position
local function pasteClipboard(x, y)
    if clipboard ~= "" then
        gpu.set(x, y, clipboard)
    end
end

-- Event bindings
globalEvents.onTouch:subscribe(function(screen, x, y)
    restoreOldPoints()
    mark.start = {x = x, y = y}
    mark.ending = nil
    drawDragEndpoints()
end)

globalEvents.onDrag:subscribe(function(screen, x, y)
    if not mark.start then return end
    mark.ending = {x = x, y = mark.start.y} -- Clamp y to start line
    drawDragEndpoints()
end)

globalEvents.onDrop:subscribe(function(screen, x, y)
    if not mark.start then return end
    mark.ending = {x = x, y = mark.start.y} -- Clamp y to start line
    drawFullSelection()
end)

local keyboard = require("systems/keyboard.lua")
globalEvents.onKeyDown:subscribe(function(char, code)
    if code == keyboard.keys.c and keyboard.isControlDown() and mark.start and mark.ending then
        copyToClipboard()
        print("Copied to clipboard: " .. clipboard)
    end
end)