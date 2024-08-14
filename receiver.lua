local color = dofile("external/Color.lua")
local screen = dofile("external/Screen.lua")
local image = dofile("external/Image.lua")
local logger = require("Logger")
local functions = require("Functions")

local component = require("component")
local gpu = component.gpu
local internet = require("internet")
local handle

local request = 'r'

function mainLoop()
    if not handle then
        handle = internet.open("127.0.0.1", 54321)
        -- handle:setTimeout(1)
    end

    while true do
        handle:write(request)
        local signature, encodingMethod, width, height = functions.readMetadata(handle)
        local picture = functions.readPixelData(handle, encodingMethod, width, height)
        screen.drawImage(0, 0, picture, false)
        screen.update()
    end
end

logger.enableLogging()
screen.setGPUAddress(gpu.address)

while true do
    local success, reason = pcall(mainLoop)
    if not success then
        logger.log("Failed logic loop: " .. reason)
        os.sleep(1)
    end
end

handle:close()
logger.close()