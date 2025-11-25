local clientFlash = {}

local minify = require("../systems/minify")

console:addCommand("FLASH.SIZETEST", "Tests the compression on the client file \nParameters:\n1 Compression rate LOW/MEDIUM/HIGH\n2 Output Code TRUE/FALSE", function(compressionLevel, outputCode)
    local fileContent = nil
    local uncompressedSize = nil
    if compressionLevel then compressionLevel = compressionLevel:upper() end

    if not compressionLevel or compressionLevel == "LOW" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parseVeryCheap)
    elseif compressionLevel == "MEDIUM" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parseCheap)
    elseif compressionLevel == "HIGH" then
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parse)
    else
        fileContent, uncompressedSize = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua",
            function(code) return code end)
    end
    local sizeCompressed = #fileContent --#minify.parse(file)
    console:log("Uncompressed size: " .. uncompressedSize .. " bytes")
    console:log("Compressed size: " .. sizeCompressed .. " bytes")
    console:log("Compression rate: " .. math.floor((1 - (sizeCompressed / uncompressedSize)) * 100) .. " %")
    console:log("Bytes left: " .. (4096 - sizeCompressed) .. " bytes")
    console:log("Bytes used: " .. (sizeCompressed / 4096) * 100 .. " %")
    if sizeCompressed > 4096 then
        console:logError("File is too large for the client flash script!")
    else
        console:log("File is within the size limit.")
    end
    if outputCode and outputCode:upper() == "TRUE" then
        console:log("Output Code:\n" .. fileContent)
    end
end)
