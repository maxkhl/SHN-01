return {
    name = "nano",
    version = "1.0.0",
    init = function()
        console:addCommand("NANO", "File editor\nParameters:\n1 File path to open", function(filePath)
            if not filePath then
                error("Please provide a file path to open.")
                return
            end
            
            local editor = new("nano", filePath)

            if editor.error then
                return
            end

            screen:setView(editor)
        end)
    end,
    dependencies = {}
}