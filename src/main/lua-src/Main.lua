local component = require("component")
local thread = require("thread")

local screen = dofile("external/Screen.lua")
local logger = require("Logger")
local receiver = require("Receiver")

local IMAGE_NOT_AVAILABLE_BACKOFF = 0.1
local CONNECTION_CHECK_FREQUENCY = 1

logger.enableLogging()
screen.setGPUAddress(component.gpu.address)

while true do
    while not receiver.connected do
        os.sleep(CONNECTION_CHECK_FREQUENCY)
    end
    while receiver.connected do
        while not receiver.hasImageAvailable() do
            logger.log("Image not available at time of request, waiting...")
            os.sleep(IMAGE_NOT_AVAILABLE_BACKOFF)
        end
        logger.log("Image available, drawing to buffer")
        screen.drawImage(0, 0, receiver.getNextImage(), false)
        logger.log("Finished drawing to buffer. Rendering to screen")
        screen.update()
        logger.log("Finished rendering to screen")
    end
end
