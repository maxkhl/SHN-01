colorTools = {}

-- Convert hex to RGB (0–255)
function colorTools.hexToRGB(hex)
  local r = math.floor(hex / 0x10000) % 0x100
  local g = math.floor(hex / 0x100) % 0x100
  local b = hex % 0x100
  return r, g, b
end

-- Calculate relative luminance
function colorTools.luminance(r, g, b)
  local function channel(c)
    c = c / 255
    return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

-- Compute contrast ratio
function colorTools.contrastRatio(hex1, hex2)
  local r1, g1, b1 = colorTools.hexToRGB(hex1)
  local r2, g2, b2 = colorTools.hexToRGB(hex2)
  local l1 = colorTools.luminance(r1, g1, b1)
  local l2 = colorTools.luminance(r2, g2, b2)
  local lighter = math.max(l1, l2)
  local darker = math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
end

-- Adjust brightness (up or down)
function colorTools.adjustBrightness(hex, factor)
  local r, g, b = colorTools.hexToRGB(hex)
  local function clamp(x) return math.max(0, math.min(255, math.floor(x + 0.5))) end
  r = clamp(r * factor)
  g = clamp(g * factor)
  b = clamp(b * factor)
  return (r << 16) + (g << 8) + b
end

-- Main function: ensure contrast
function colorTools.ensureContrast(textColor, backgroundColor, targetRatio)
  targetRatio = targetRatio or 4.5 -- WCAG recommended for normal text

  if colorTools.contrastRatio(textColor, backgroundColor) >= targetRatio then
    return textColor
  end

  local factor = 1.1
  for i = 1, 20 do
    local brighter = colorTools.adjustBrightness(textColor, factor)
    if colorTools.contrastRatio(brighter, backgroundColor) >= targetRatio then
      return brighter
    end
    local darker = colorTools.adjustBrightness(textColor, 1 / factor)
    if colorTools.contrastRatio(darker, backgroundColor) >= targetRatio then
      return darker
    end
    factor = factor + 0.1
  end

  -- Fallback: return white or black depending on best contrast
  local contrastWhite = colorTools.contrastRatio(0xFFFFFF, backgroundColor)
  local contrastBlack = colorTools.contrastRatio(0x000000, backgroundColor)
  return contrastWhite > contrastBlack and 0xFFFFFF or 0x000000
end