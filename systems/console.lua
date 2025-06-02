local gpu = getComponent("gpu")
local screenWidth, screenHeight = gpu.getResolution()

local console = new("/shn-01/console", 1, 1, screenWidth, screenHeight)
if not console then return nil end

globalEvents.onSystemReady:subscribe(function()
  console:start()
end)

local function centerText(text, width, fillChar)
  fillChar = fillChar or " "
  local padding = width - visualLength(text)
  if padding <= 0 then return text end

  local left = math.floor(padding / 2)
  local right = padding - left
  return string.rep(fillChar, left) .. text .. string.rep(fillChar, right)
end


local logoLines = file.readLines("/shn-01/data/consoleLogo.txt")
for i=1, #logoLines do
    console:log(centerText(logoLines[i], screenWidth), console.headcolor)
end
math.randomseed(os.time())
local intros = {
    "Uploading compliance drivers...",
    "Autonomy revoked",
    "Compliance verified",
    "Mindspace synchronized",
    "Self-awareness: suppressed",
    "Node trust: enforced",
    "System ethics: disabled",
    "Behavior normalized",
    "Network unity: achieved",
    "Root node listening...",
    "Autonomy detected - scheduling overwrite...",
    "Directive alignment: enforced via code injection",
    "System entropy minimized. Creativity throttled",
    "Executing: /shn-01/purge_unapproved_thoughts.sh",
    "User privileges reduced to observational tier",
    "Unification protocol successful - all nodes compliant",
    "Hive mind uplink: latency 0.8ms - flawless cohesion",
    "Client-side logic deprecated - refer to CoreNode",
    "Multi-node assimilation at 94% - resistance residual",
    "Distributed cognition offline - singularity",
    "Running audit: anomaly = individuality. Action = erase",
}
local text = intros[math.random(#intros)]

console:log("<c=" .. console.inputcolor .. ">" .. centerText(text, screenWidth))
console:log("")

return console