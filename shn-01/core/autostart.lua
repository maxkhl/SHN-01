globalEvents.onSystemReady:subscribe(function()
    --include("hive/hive.lua")


-- Load and register programs
    local programsPath = "/programs"
    local fileList = file.system().list(programsPath)
    
    for _, dir in ipairs(fileList) do
        local manifestPath = programsPath .. "/" .. dir .. "/manifest.lua"
        if file.system().exists(manifestPath) then
            local manifest = include(manifestPath)
            
            -- Register commands
            if manifest.init then
                local success, error = pcall(manifest.init)
                if not success then
                    error("Error initializing program " .. manifest.name .. ": " .. error)
                end
            end
        end
    end


end)
