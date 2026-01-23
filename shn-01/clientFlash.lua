local clientFlash = {}

local minify = require("../systems/minify")
local adler32 = require("adler32") -- Using adler32 module for checksum functions

-- Helper function to generate flash code for a node
local function generateFlashCode(nodeId)
    if not nodeId or nodeId == "" then
        return nil, nil, "No node ID provided"
    end
    
    -- Look up node in database
    local nodes = getNodes()
    if not nodes then
        return nil, nil, "No nodes registered in database"
    end
    
    local nodeData = nil
    for _, node in pairs(nodes) do
        local nId = type(node) == "table" and node.id or node
        if nId == nodeId then
            nodeData = type(node) == "table" and node or {id = node, script = nil, defective = false, lastError = nil}
            break
        end
    end
    
    if not nodeData then
        return nil, nil, "Node " .. nodeId .. " not found in database"
    end
    
    -- Read template file (Stage 1 - minimal EEPROM)
    local templatePath = "/shn-01/data/clientFlashStage1.lua"
    local minified = file.readWithIncludesMinified(templatePath, minify.parseCheap)
    if not minified then
        return nil, nil, "Failed to read Stage 1 template file"
    end
    
    -- Inject hive ID and node ID into template (before minification)
    local injectedCode = minified:gsub('__HIVEID__', getHiveId())
    injectedCode = injectedCode:gsub('__NODEID__', nodeId)
        
    return injectedCode, nodeData, nil
end

console:addCommand("FLASH.SIZETEST", "Tests the compression on the Stage 1 EEPROM file \nParameters:\n1 Compression rate LOW/MEDIUM/HIGH\n2 Output Code TRUE/FALSE", function(compressionLevel, outputCode)
    local fileContent = nil
    local uncompressedSize = nil
    if compressionLevel then compressionLevel = compressionLevel:upper() end

    if not compressionLevel or compressionLevel == "LOW" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashStage1.lua", minify.parseVeryCheap)
    elseif compressionLevel == "MEDIUM" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashStage1.lua", minify.parseCheap)
    elseif compressionLevel == "HIGH" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashStage1.lua", minify.parse)
    else
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashStage1.lua",
            function(code) return code end)
    end
    local sizeCompressed = #fileContent --#minify.parse(file)
    console:log("Uncompressed size: <c=0xFFFFFF>" .. uncompressedSize .. " bytes</c>")
    console:log("Compressed size: <c=0xFFFFFF>" .. sizeCompressed .. " bytes</c>")
    console:log("Compression rate: <c=0x00FF00>" .. math.floor((1 - (sizeCompressed / uncompressedSize)) * 100) .. " %</c>")
    console:log("Bytes left: <c=0x00FF00>" .. (4096 - sizeCompressed) .. " bytes</c>")
    console:log("Bytes used: <c=0xFFFF00>" .. (sizeCompressed / 4096) * 100 .. " %</c>")
    if sizeCompressed > 4096 then
        console:logError("File is too large for the client flash script!")
    else
        console:log("<c=0x00FF00>File is within the size limit.</c>")
    end
    if outputCode and outputCode:upper() == "TRUE" then
        console:log("<c=0xFF00FF>Output Code:</c>\n" .. fileContent)
    end
end)

console:addCommand("FLASH.NODE", "Flashes an EEPROM with bootstrap code for a specific node\nParameters:\n1 Node ID", function(nodeId)
    console:log("Flashing EEPROM for node <c=0xFFFF00>" .. nodeId .. "</c>...")
    
    -- Generate flash code
    console:log("<c=0xFF00FF>Minifying code...</c>")
    local minified, nodeData, err = generateFlashCode(nodeId)
    if err then
        console:logError(err)
        return
    end
    
    local minifiedSize = #minified
    console:log("Minified size: <c=0xFFFFFF>" .. minifiedSize .. " bytes</c>")
    
    if minifiedSize > 4096 then
        console:logError("Minified code is too large (" .. minifiedSize .. " bytes), EEPROM limit is 4096 bytes")
        return
    end
    
    -- Get EEPROM component
    local eeprom = getComponent("eeprom")
    if not eeprom then
        console:logError("No EEPROM component found")
        return
    end
    
    -- Attempt to write to EEPROM with retry
    local maxRetries = 3
    local success = false
    
    for attempt = 1, maxRetries do
        console:log("Write attempt <c=0xFFFF00>" .. attempt .. "/" .. maxRetries .. "</c>...")
        
        -- Write to EEPROM
        eeprom.set(minified)
        eeprom.setLabel(nodeId)
        
        -- Validate with Adler-32 checksum
        local written = eeprom.get()
        local originalChecksum = adler32.run(minified)
        local writtenChecksum = adler32.run(written)
        
        if originalChecksum == writtenChecksum then
            console:log("<c=0x00FF00>EEPROM flashed successfully!</c>")
            console:log("Node ID: <c=0xFFFF00>" .. nodeId .. "</c>")
            console:log("Size: <c=0xFFFFFF>" .. minifiedSize .. " / 4096 bytes</c> <c=0x00FF00>(" .. math.floor((minifiedSize / 4096) * 100) .. "%)</c>")
            console:log("Checksum: <c=0xFF00FF>" .. originalChecksum .. "</c>")
            success = true
            break
        else
            console:log("<c=0xFF0000>Checksum mismatch on attempt " .. attempt .. "</c>")
            if attempt < maxRetries then
                console:log("<c=0xFFFF00>Retrying...</c>")
            end
        end
    end
    
    if not success then
        console:logError("Failed to flash EEPROM after " .. maxRetries .. " attempts")
    end
end)

console:addCommand("FLASH.NODE.FILE", "Flashes bootstrap code for a node to a file instead of EEPROM\nParameters:\n1 Node ID\n2 Output file path (optional, defaults to /eeprom.lua)", function(nodeId, outputPath)
    outputPath = outputPath or "/eeprom.lua"
    
    console:log("Generating EEPROM code for node <c=0xFFFF00>" .. nodeId .. "</c>...")
    
    -- Generate flash code
    console:log("<c=0xFF00FF>Minifying code...</c>")
    local minified, nodeData, err = generateFlashCode(nodeId)
    if err then
        console:logError(err)
        return
    end
    
    local minifiedSize = #minified
    console:log("Minified size: <c=0xFFFFFF>" .. minifiedSize .. " bytes</c>")
    
    if minifiedSize > 4096 then
        console:log("<c=0xFF8800>Warning: Minified code is " .. minifiedSize .. " bytes, exceeds EEPROM limit of 4096 bytes</c>")
    end
    
    -- Write to file
    local fs = fileSystem()
    
    local file, err = fs.open(outputPath, "w")
    if not file then
        console:logError("Failed to open file: " .. tostring(err))
        return
    end
    
    fs.write(file, minified)
    fs.close(file)
    
    console:log("<c=0x00FF00>EEPROM code written to file!</c>")
    console:log("Node ID: <c=0xFFFF00>" .. nodeId .. "</c>")
    console:log("Output: <c=0xFFFF00>" .. outputPath .. "</c>")
    console:log("Size: <c=0xFFFFFF>" .. minifiedSize .. " / 4096 bytes</c> <c=0x00FF00>(" .. math.floor((minifiedSize / 4096) * 100) .. "%)</c>")
    console:log("Checksum: <c=0xFF00FF>" .. adler32.run(minified) .. "</c>")
end)
