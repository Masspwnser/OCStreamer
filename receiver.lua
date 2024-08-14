local color = dofile("external/Color.lua")
local screen = dofile("external/Screen.lua")
local image = dofile("external/Image.lua")
local logger = require("Logger")
logger.enableLogging()

local bit32 = require("bit32")
local string = require("string")
local component = require("component")
local gpu = component.gpu
local internet = require("internet")
local handle

screen.setGPUAddress(gpu.address)

while true do

    if not handle then
        handle = internet.open("127.0.0.1", 54321)
        -- handle:setTimeout(0.05)
    end

    local signature, encodingMethod, widthOrReason, height = image.readMetadata(handle)
    if not signature then
        logger.log("Failed to read metadata: " .. encodingMethod)
        os.sleep(1)
    else
        logger.log("Got header! " .. signature .. " " .. encodingMethod .. " " .. widthOrReason .. " " .. height)

        local picture, failure = image.readPixelData(handle, encodingMethod, widthOrReason, height)
        if failure or not picture then
            logger.log("Failed to read image data, reason: " .. failure)
            os.sleep(1)
        else
            logger.log("Successfully read image data (but image may be incomplete) Image size: " .. picture[1] .. " " .. picture[2] .. " " .. #picture)
            local success, reason = pcall(screen.drawImage, 0, 0, picture, false)
            if not success then
                logger.log("Failed to display image, reason: " .. reason)
                os.sleep(1)
            else
                logger.log("Successfully displayed image")
            end
        end

    end
    screen.update()
    handle:write(string.char(0xF1))
end
handle:close()
logger.close()