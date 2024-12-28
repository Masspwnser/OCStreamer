local os = require("os")

local Logger = {}
local file

function Logger.enableLogging()
    local fileName = "/tmp/log.txt"
    file = io.open(fileName, "w")
    if not file then
        print("Error loading logger, file not created at: " .. fileName)
    end
end

function Logger.log(text)
    if file then
        file:write(string.format("%.9f", os.clock()) .. ":\t" .. text .. "\n")
    end
end

function Logger.close()
    if file then
        file:close()
    end
end

return Logger