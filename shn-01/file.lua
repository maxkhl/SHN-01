file = {}

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