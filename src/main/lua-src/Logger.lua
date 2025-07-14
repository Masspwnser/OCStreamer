local os = require("os")

local Logger = {
    enabled = false,
    file = nil,
    fileName = "/tmp/log.txt"
}

function Logger.enableLogging()
    if Logger.enabled then
        Logger.log("Logger already enabled, not taking action.")
        return
    end
    Logger.file = io.open(Logger.fileName, "w")
    if not Logger.file then
        print("Error loading logger, Logger.file not created at: " .. Logger.fileName)
    else
        Logger.enabled = true
    end
end

function Logger.log(text)
    if Logger.enabled then
        Logger.file:write(string.format("%.9f", os.clock()) .. ":\t" .. text .. "\n")
        Logger.file:flush()
    end
end

function Logger.dumpLogs()
    local readFile = io.open(Logger.fileName, "r")
    if readFile then
        return readFile:read("*a")
    end
    return "Failure to read log Logger.file"
end

function Logger.close()
    if Logger.enabled then
        Logger.file:close()
    end
end

return Logger