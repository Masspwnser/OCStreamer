local screen = dofile("external/Screen.lua")
local logger = require("Logger")
local encodingHelper = require("Encoding")

local component = require("component")
local gpu = component.gpu
local internet = require("internet")
local handle
local connected

local STATUS_GOOD_RESPONSE = "READY"
local STATUS_ENDPOINT = "http://localhost:56795/status"
local STREAM_ENDPOINT = "http://localhost:56795/stream"

local function attemptConnection()
    logger.log("Waiting for connection to server")
    handle = internet.request(STATUS_ENDPOINT)
    for chunk in handle do
        if chunk == STATUS_GOOD_RESPONSE then
            connected = true
            break
        end
    end
    logger.log("Connected to server")
end

local function mainLoop()
    attemptConnection()

    while connected do
        logger.log("Requesting stream data from server")
        handle = internet.request(STREAM_ENDPOINT)
        logger.log("Received a response")
        local picture = encodingHelper.readPixelData(handle)
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
        connected = false
        logger.log("Failed logic loop: " .. reason)
        os.sleep(1)
    end
end
