local internet = require("internet")
local thread = require("thread")

local Queue = require("external.Queue")
local logger = require("Logger")
local encodingHelper = require("Encoding")

local STATUS_GOOD_RESPONSE = "READY"
local STATUS_ENDPOINT = "http://localhost:56795/status"
local STREAM_ENDPOINT = "http://localhost:56795/stream"
local MAX_IMAGES = 10
local BACKOFF_TIME = 1

local handle
local images = Queue:new()

local Receiver = {
    connected = false,
}

function Receiver.hasImageAvailable()
    return not images:isEmpty()
end

function Receiver.getNextImage()
    return images:dequeue()
end

local function readyToIngestImage()
    if not Receiver.connected then
        logger.log("Receiver is not connected, cannot ingest image")
        return false
    end
    if images:length() > MAX_IMAGES then
        logger.log("Image buffer is full, cannot ingest new image")
        return false
    end
    return true
end

local function attemptConnection()
    logger.log("Waiting for connection to server")
    handle = internet.request(STATUS_ENDPOINT)
    for chunk in handle do
        if chunk == STATUS_GOOD_RESPONSE then
            Receiver.connected = true
            logger.log("Connected to server")
            break
        end
    end
end

local function receiverLogic()
    attemptConnection()

    while Receiver.connected do
        while not readyToIngestImage() do
            os.sleep(BACKOFF_TIME)
        end
        logger.log("Requesting stream data from server")
        handle = internet.request(STREAM_ENDPOINT)
        logger.log("Received a response")
        images:enqueue(encodingHelper.readPixelData(handle))
        logger.log("Finished loading image into memory")
    end
end

thread.create(function()
  while true do
      local success, reason = pcall(receiverLogic)
      if not success then
          Receiver.connected = false
          images:clear()
          logger.log("Failed receiverLogic loop: " .. reason)
          os.sleep(1)
      end
  end
end)

return Receiver