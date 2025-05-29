local clientFlash = {}

local console = require("systems/console")
local minify = require("systems/minify")

console:addCommand("FLASH.SIZETEST", "Tests the compression on the client file", function(cons, compressionLevel)
    local fileContent = nil
    if compressionLevel then compressionLevel = compressionLevel:upper() end

    if not compressionLevel or compressionLevel == "LOW" then
        fileContent = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parseVeryCheap)
    elseif compressionLevel == "MEDIUM" then
        fileContent = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parseCheap)
    elseif compressionLevel == "HIGH" then
        fileContent = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", minify.parse)
    else
        fileContent = file.readWithIncludesMinified("/shn-01/data/clientFlashScriptTemplate.lua", function(code) return code end)
    end
    local sizeCompressed = #fileContent --#minify.parse(file)
    cons:log("File size: " .. sizeCompressed .. " bytes")
    cons:log("Bytes left: " .. (4096 - sizeCompressed) .. " bytes")
    cons:log("Bytes used: " .. (sizeCompressed / 4096) * 100 .. " %")
    if sizeCompressed > 4096 then
        cons:logError("File is too large for the client flash script!")
    else
        cons:log("File is within the size limit.")
    end
end)