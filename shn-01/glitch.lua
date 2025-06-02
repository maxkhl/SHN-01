local gpu = getComponent("gpu")

local screenWidth, screenHeight = gpu.getResolution()
local glitchChars = {"#", "%", "&", "$", "@", "░", "▒", "▓", "█", "?"}


local database = require("/systems/database.lua")
local doGlitch = database:getKey("shn01", "glitch")
if doGlitch == nil then
    database:setKey("shn01", "glitch", true, true)
    doGlitch = true
end

glitch = {}
function glitch.random()
    if not doGlitch then return end
    local mode = math.random(1, 20)
    if mode == 1 then
        glitch.screen()
    elseif mode >= 2 then
        glitch.burst()
    end
end

function glitch.burst()
    if not doGlitch then return end
  local width = math.random(3, math.floor(screenWidth / 6))
  local height = math.random(1, math.floor(screenHeight / 10))
  local x = math.random(1, screenWidth - width)
  local y = math.random(1, screenHeight - height)

  local original = {}
  local smearPool = {}

  -- Step 1: Save original area (characters + colors)
  for dy = 0, height - 1 do
    for dx = 0, width - 1 do
      local gx = x + dx
      local gy = y + dy
      local char, fg, bg = gpu.get(gx, gy)

      -- Always provide defaults
      table.insert(original, {
        x = gx,
        y = gy,
        char = char or " ",
        fg = tonumber(fg) or 0xFFFFFF,
        bg = tonumber(bg) or 0x000000
      })

      -- Add to smear pool
      table.insert(smearPool, {
        char = char or " ",
        fg = tonumber(fg) or 0xFFFFFF,
        bg = tonumber(bg) or 0x000000
      })
    end
  end

  -- Step 2: Apply glitch
  for _, cell in ipairs(original) do
    local smear = smearPool[math.random(#smearPool)]
    local useGlitch = math.random() < 0.2
    local char

    if useGlitch then
      char = glitchChars[math.random(#glitchChars)]
    elseif math.random() < 0.5 then
      char = smear.char -- smear from pool
    else
      char = cell.char -- keep original
    end

    local fg = math.random() < 0.2 and smear.fg or cell.fg
    local bg = math.random() < 0.2 and smear.bg or cell.bg

    gpu.setForeground(fg)
    gpu.setBackground(bg)
    gpu.set(cell.x, cell.y, char)
  end

  -- Step 3: Display glitch briefly
  computer.pullSignal(0.1)

  -- Step 4: Restore original content
  for _, cell in ipairs(original) do
    gpu.setForeground(cell.fg)
    gpu.setBackground(cell.bg)
    gpu.set(cell.x, cell.y, cell.char)
  end
end

function glitch.screen()
    if not doGlitch then return end
  -- Try to allocate both buffers
  local originalBuffer = gpu.allocateBuffer()
  if not originalBuffer then return end

  local glitchBuffer = gpu.allocateBuffer()
  if not glitchBuffer then
    gpu.freeBuffer(originalBuffer)
    return
  end

  -- Copy screen into both buffers
  gpu.bitblt(originalBuffer, 0, 0, screenWidth, screenHeight, 0, 0, 0)
  gpu.bitblt(glitchBuffer, 0, 0, screenWidth, screenHeight, 0, 0, 0)

  -- Activate glitchBuffer and glitch it
  gpu.setActiveBuffer(glitchBuffer)

  for y = 1, screenHeight do
    for x = 1, screenWidth do
      local char, fg, bg = gpu.get(x, y)
      char = char or " "
      fg = tonumber(fg) or 0xFFFFFF
      bg = tonumber(bg) or 0x000000

      local mode = math.random()
      if mode < 0.05 then
        char = glitchChars[math.random(#glitchChars)]
      elseif mode < 0.3 then
        local dx = math.random(-1, 1)
        local dy = math.random(-1, 1)
        local sx = math.max(1, math.min(screenWidth, x + dx))
        local sy = math.max(1, math.min(screenHeight, y + dy))
        local smearChar = gpu.get(sx, sy)
        char = smearChar or char
      end

      if math.random() < 0.1 then fg = fg ~ 0xFFFFFF end
      if math.random() < 0.05 then bg = bg ~ 0xFFFFFF end

      gpu.setForeground(fg)
      gpu.setBackground(bg)
      gpu.set(x, y, char)
    end
  end

  -- Blit glitched buffer to screen
  gpu.bitblt(0, 0, 0, screenWidth, screenHeight, glitchBuffer, 0, 0)

  -- Wait briefly
  computer.pullSignal(0.05)

  -- Restore original screen
  gpu.bitblt(0, 0, 0, screenWidth, screenHeight, originalBuffer, 0, 0)

  -- Cleanup
  gpu.freeBuffer(originalBuffer)
  gpu.freeBuffer(glitchBuffer)
end

if doGlitch then
    globalEvents.onTick:subscribe(function()
        if math.random() < 0.05 then
            glitch.random()
        end
    end)
end