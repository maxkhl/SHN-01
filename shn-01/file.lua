-- Reads a file and returns its content as a table of lines
function file.readLines(absolutePath)
    if not absolutePath then error("No file path given") end
    local fileSystem = fileSystem()
    local stream, reason = fileSystem.open(absolutePath, "r")
    if not stream then error("Failed to open " .. absolutePath .. ": " .. tostring(reason)) end

    local chunks = {}
    local newChunk = fileSystem.read(stream, 4096)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, 4096)
    end
    fileSystem:close(stream)

    local content = table.concat(chunks)
    local lines = {}

    -- Split by line breaks (handles both \n and \r\n)
    for line in content:gmatch("([^\r\n]+)") do
        table.insert(lines, line)
    end

    return lines
end

-- Returns a files extension
function file.getExtension(path)
    local name = path:match("([^/\\]+)$")  -- Get the filename only (handles Unix and Windows separators)
    if name:match("^%.[^%.]*$") then return nil end  -- Ignore hidden files like `.bashrc`
    return name:match("^.+%.([^.]+)$")
end


-- Normalizes path by resolving "." and ".."
function file.normalizePath(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    return "/" .. table.concat(parts, "/")
end

-- Joins two paths together, normalizing the result
function file.joinPath(base, relative)
  return file.normalizePath(base .. "/" .. relative)
end

-- Returns the absolute file path of a given relative path
function getAbsolutePath(relativePath, origin)
    assert(relativePath, "No relative path given (origin: " .. tostring(origin) .. ")")
    assert(type(relativePath) == "string", "Invalid relative path, expected string but got " .. type(relativePath) .. " (origin: " .. tostring(origin) .. ")")
    origin = origin or baseDir
    if relativePath:sub(1, 1) == "/" then
        return file.normalizePath(relativePath)
    end
    return file.normalizePath(origin .. "/" .. relativePath)
end

-- Reads a file and returns its content
function file.readRelative(relativePath, origin)
    if not relativePath then error("No file path given") return end
    local fileSystem = fileSystem()
    local path = getAbsolutePath(relativePath, origin)
    local stream, reason = fileSystem.open(path, "r")
    if not stream then error("Failed to open " .. path .. ": " .. tostring(reason)) end

    local chunks = {}
    local newChunk = fileSystem.read(stream, 4096)
    while newChunk do
        table.insert(chunks, newChunk)
        newChunk = fileSystem.read(stream, 4096)
    end
    fileSystem:close(stream)
    return table.concat(chunks), path
end

-- Returns a directory path from a given file path
function file.getDir(path)
  -- Extract directory from a path
  return path:match("^(.*[\\/])") or ""
end


-- Reads a file and expands any include calls recursively
function file.readWithIncludesMinified(path, minify, seen)
  seen = seen or {}

  path = file.normalizePath(path)
  if seen[path] then
    error("Circular include detected: " .. path)
  end
  seen[path] = true

  local baseDir = file.getDir(path)
  local source = file.read(path)
  if not source then
    error("Could not read file: " .. path)
  end

  local localBuffer = {}

  for line in source:gmatch("[^\r\n]+") do
    local includePath = line:match('^%s*include%s*%(?%s*["\']([^"\']+)["\']%s*%)?%s*$')
    if includePath then
      local resolved = file.joinPath(baseDir, includePath)
      local includedWrapped = file.readWithIncludesMinified(resolved, minify, seen)
      table.insert(localBuffer, includedWrapped)
    else
      table.insert(localBuffer, line)
    end
  end

  local combined = table.concat(localBuffer, "\n")
  local minified = minify and minify(combined) or combined

  -- Wrap this file in a return (function() ... end)() expression
  return "return (function()\n" .. minified .. "\nend)()"
end
