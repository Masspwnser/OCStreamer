local screen = dofile("external/Screen.lua")
local logger = require("Logger")
local functions = require("Functions")

local component = require("component")
local gpu = component.gpu
local internet = require("internet")
local handle
local connected

local TEST_RESPONSE = "READY"
local TEST_ENDPOINT = "http://localhost:8008/test"
local STREAM_ENDPOINT = "http://localhost:8008/stream"

function mainLoop()
    logger.log("Waiting for connection to server")
    while not connected do
        handle = internet.request(TEST_ENDPOINT)
        for chunk in handle do
            if chunk == TEST_RESPONSE then
                connected = true
                break
            end
        end
        os.sleep(1)
    end
    logger.log("Connected to server")

    while true do
        logger.log("Requesting stream data from server")
        handle = internet.request(STREAM_ENDPOINT)
        logger.log("Received a response")
        local picture = functions.readPixelData(handle)
        logger.log("Finished loading image into memory")
        screen.drawImage(0, 0, picture, false)
        logger.log("Finished drawing")
        screen.update()
        logger.log("Finished rendering")
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