local os = require("os")

local Logger = {}
local enabled = false
local file

function Logger.enableLogging()
    if enabled then
        return
    end
    local fileName = "/home/log.txt"
    file = io.open(fileName, "w")
    if not file then
        print("Error loading logger, file not created at: " .. fileName)
    else
        enabled = true
    end
end

function Logger.log(text)
    if enabled then
        file:write(string.format("%.9f", os.clock()) .. ":\t" .. text .. "\n")
        file:flush()
    end
end

function Logger.read(numLines)
    if enabled then
        file:seek("end", numLines * -1)
        return(file:read("*a"))
    end
    return("")
end

function Logger.close()
    if enabled then
        file:close()
    end
end

return Logger