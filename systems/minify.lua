local minify = {}

-- Parses an entire file
function minify.parseFile(filePath)
    return minify.parse(file.read(filePath))
end

-- Parses the given code as string
function minify.parse(code)
    local min = include("minify/luaminify.lua")
    local success, minified = min.ParseLua(code)
    min = nil
    local ret = nil
    if success then
        local formatmini = include("minify/formatmini.lua")
        ret = formatmini(minified)
        formatmini = nil
    end

    if not success then
        error("Failed to minify code: " .. tostring(minified))
    end
    return ret
end

function minify.parseVeryCheap(source)
  local lines = {}
  for line in source:gmatch("[^\r\n]+") do
    -- Remove comments (only simple single line -- comments)
    -- strip Lua single-line comments
    local codeOnly = line:gsub("%-%-.*$", "")
    -- Trim leading/trailing spaces
    codeOnly = codeOnly:match("^%s*(.-)%s*$")
    if codeOnly ~= "" then
      table.insert(lines, codeOnly)
    end
  end
  return table.concat(lines, "\n")
end

local function isAlphaNum(c)
  return c:match("[%w_]")
end

function minify.parseCheap(source)
  source = minify.parseVeryCheap(source)
  local out = {}
  local i = 1
  local len = #source

  local function nextChar()
    i = i + 1
    return source:sub(i, i)
  end

  local function peekChar(offset)
    offset = offset or 0
    return source:sub(i + offset, i + offset)
  end

  local function skipWhitespace()
    while i <= len and source:sub(i,i):match("%s") do
      i = i + 1
    end
  end

  while i <= len do
    local c = source:sub(i,i)

    -- Skip whitespace
    if c:match("%s") then
      -- Collapse whitespace to a single space only if needed
      -- Lookahead previous and next chars for alphanumeric to separate tokens
      local prev = out[#out]
      skipWhitespace()
      local nextC = source:sub(i,i)
      if prev and isAlphaNum(prev:sub(-1,-1)) and isAlphaNum(nextC) then
        table.insert(out, " ")
      end

    -- Comments
    elseif c == "-" and peekChar(1) == "-" then
      i = i + 2
      -- Long comment?
      if peekChar() == "[" and peekChar(1) == "[" then
        i = i + 2
        -- skip until ]]
        while i <= len do
          if source:sub(i,i+1) == "]]" then
            i = i + 2
            break
          else
            i = i + 1
          end
        end
      else
        -- skip until end of line
        while i <= len and source:sub(i,i) ~= "\n" do
          i = i + 1
        end
      end

    -- Strings (single/double quoted)
    elseif c == '"' or c == "'" then
      local quote = c
      table.insert(out, c)
      i = i + 1
      while i <= len do
        local ch = source:sub(i,i)
        table.insert(out, ch)
        if ch == "\\" then
          -- Escape next char
          i = i + 1
          table.insert(out, source:sub(i,i))
        elseif ch == quote then
          i = i + 1
          break
        end
        i = i + 1
      end

    -- Long bracket strings [[...]]
    elseif c == "[" and peekChar() == "[" then
      table.insert(out, "[[")
      i = i + 2
      while i <= len do
        if source:sub(i,i+1) == "]]" then
          table.insert(out, "]]")
          i = i + 2
          break
        else
          table.insert(out, source:sub(i,i))
          i = i + 1
        end
      end

    else
      -- normal token char
      table.insert(out, c)
      i = i + 1
    end
  end

  return table.concat(out)
end

return minify