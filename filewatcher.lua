-- Monitors files and calles events on changes
local fw = {}

local iot = require("max.util.iotools")

local event = require("event")
local cEvent = require("max.util.event") -- custom event objects to subscribe/unsubscribe to

local component = require("component")

-- Files that are being watched currently
-- Contains key file string, fileSize int, event max.event
fw.watchedFiles = {}

-- Adds a function to filewatch. Takes a filePath and a callback function. Every change to the file will trigger callback. Callback receives the filePath and the new size (0 if it does not exist anymore)
-- Returns a message if something failed
function fw.Add(filePath, callback)
    if not filePath then
        error("No file provided")
    end

    if not iot.FileExists(filePath) then
        error("File " .. filePath .. " does not exist")
    end

    if not fw.watchedFiles[filePath] then
        fw.watchedFiles[filePath] = {
            size = iot.FileSize(filePath),
            event = cEvent.New()
        }
    end
    
    fw.watchedFiles[filePath].event.Subscribe(callback)
    
    if not fw.fileWatchTimerId then
        -- Ensure we don't pass an empty interval into the event.timer call
        if not fw.fileWatchInterval then fw.fileWatchInterval = 20 end
        fw.fileWatchTimerId = event.timer(fw.fileWatchInterval, fw.ListenLoop, fw.fileWatchInterval)
    end
end

-- Removes a callback from a watched file
function fw.Remove(filePath, callback)
    local data = fw.watchedFiles[filePath]
    if data then
        data.event.Unsubscribe(callback)
        if not data.event.HasSubscribers() then
            fw.watchedFiles[filePath] = nil
            if not fw.IsWatchingFiles() and fw.fileWatchTimerId then
                event.cancel(fw.fileWatchTimerId)
                fw.fileWatchTimerId = nil
            end
        end
    end
end

-- Interval that files are checked for changes in seconds
fw.fileWatchInterval = 20

-- Timer id to start/stop checking in on files
fw.fileWatchTimerId = nil

-- Loop that gets called by the event system and checks in on files and if they've changed
function fw.ListenLoop()
    for filePath, data in pairs(fw.watchedFiles) do
        local newSize
        if iot.FileExists(filePath) then
            newSize = iot.FileSize(filePath)
        else
            newSize = 0
        end

        if newSize ~= data.size then
            data.size = newSize
            data.event.FireSafe(filePath, data.size)
        end
    end
end

-- Returns true if the filewatcher is watching any files right now
function fw.IsWatchingFiles()
    for _, _ in pairs(fw.watchedFiles) do
        return true
    end
    return false
end

return fw