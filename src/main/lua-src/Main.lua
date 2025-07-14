local component = require("component")

local screen = dofile("external/Screen.lua")
local logger = require("Logger")
local receiver = require("Receiver")

local RECOVERY_TIME = 0.1

local function mainLogic()
    while receiver.connected do
        while not receiver.hasImageAvailable() do
            os.sleep(RECOVERY_TIME)
        end
        screen.drawImage(0, 0, receiver.getNextImage(), false)
        logger.log("Finished drawing")
        screen.update()
        logger.log("Finished rendering")
    end
end

logger.enableLogging()
screen.setGPUAddress(component.gpu.address)

while true do
    local success, reason = pcall(mainLogic)
    if not success then
        logger.log("Failed mainLogic loop: " .. reason)
        os.sleep(1)
    end
end
