--[[    
    AutismOS core file
        This file contains the core functions of the autismOS system
        It is loaded by the main file and provides the basic functionality of the system.
        It is not meant to be modified by the user.
]]--

local console = require("/systems/console.lua")
console:addCommand("COMPUTER.REBOOT", "Restarts the computer", function()
    computer.shutdown(true)
end)

console:addCommand("COMPUTER.SHUTDOWN", "Shuts down the computer", function()
    computer.shutdown(false)
end)
console:addCommand("COMPUTER.INFO", "Lists basic informations about the computer", function()
    console:log("Architecture: " .. computer.getArchitecture())
    console:log("Total memory: " .. computer.totalMemory())
    console:log("Address: " .. computer.address())
end)

console:addCommand("COMPUTER.INFO.DEVICES","Returns the computers device infos",function(self)
  for k, v in pairs(computer.getDeviceInfo()) do
      self:log(v.product)
      self:log(v.class)
      self:log(v.description)
      self:log(v.vendor)
      self:log("")
  end
end)

console:addCommand("HDD.SPACE", "Returns space information about the OS hard drive", function(self)
  local fileSystem = fileSystem()
  local spaceTotal = fileSystem.spaceTotal()
  local spaceUsed = fileSystem.spaceUsed()
  print("Total: " .. tostring(spaceTotal) .. " bytes")
  print("Used: " .. tostring(spaceUsed) .. " bytes")
  self:horizontalGraph(spaceUsed, spaceTotal)
  print("Free: " .. tostring(spaceTotal - spaceUsed) .. " bytes")
  self:horizontalGraph(spaceTotal - spaceUsed, spaceTotal)

end)

console:addCommand("COMPONENT.LIST","Returns the computers components (use parameter as name filter)",function(self, filter)
  for k, v in pairs(component.list(filter)) do
      self:log(v .. ": " .. k)
  end
end)
console:addCommand("COMPONENT.FIELDS","Returns the components fields. Expects an address",function(self, address)
    for k, v in pairs(component.proxy(address)) do
        self:log(k .. ": " .. tostring(v))
    end
end)

console:addCommand("GLOBALS", "Shows all current global attributes and fields", function(self)
    for k, v in pairs(_G) do
        self:log(k .. ": " .. tostring(v))
    end
end)

console:addCommand("BUFFER.REQUIRE", "Shows the content of the require buffer", function(self)
    for k, v in pairs(requireBuffer) do
        self:log(k .. ": " .. tostring(v))
    end
end)

-- 2a3d5ae9-4db4-497f-a016-4576b4a9b6d0