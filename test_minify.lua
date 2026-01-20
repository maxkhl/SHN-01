-- Test minify with a simple case
local testCode = [[
function beepSeq(sequence)
  for i, v in pairs(sequence) do computer.beep(v[1], v[2]) end
end
]]

print("Original code:")
print(testCode)
print("\n--- Testing parseVeryCheap ---")

-- Inline parseVeryCheap
local function parseVeryCheap(source)
  local lines = {}
  for line in source:gmatch("[^\r\n]+") do
    local codeOnly = line:gsub("%-%-.*$", "")
    codeOnly = codeOnly:match("^%s*(.-)%s*$")
    if codeOnly ~= "" then
      table.insert(lines, codeOnly)
    end
  end
  return table.concat(lines, "\n")
end

local cheap = parseVeryCheap(testCode)
print(cheap)

print("\n--- Now the position where the bug happens ---")
-- Find the [1] in the string
local pos = cheap:find("%[1%]")
if pos then
  print("Found [1] at position " .. pos)
  print("Context: " .. cheap:sub(pos-5, pos+5))
  print("Char at pos: '" .. cheap:sub(pos,pos) .. "'")
  print("Char at pos+1: '" .. cheap:sub(pos+1,pos+1) .. "'")
end
