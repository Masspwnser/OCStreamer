local color = dofile("external/Color.lua")
local screen = dofile("external/Screen.lua")
local image = dofile("external/Image.lua")

local bit32 = require("bit32")
local string = require("string")
local component = require "component"
local gpu = component.gpu
local internet = require("internet")
local handle

local function bytesToInt(bytes)
  if bytes == nil then
    return 0
  end
  return bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 1) , 0xFF) , 24), bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 2) , 0xFF) , 16), bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 3) , 0xFF) , 8), bit32.band(string.byte(bytes, 4) , 0xFF))));
end

while true do

  if not handle then
    handle = internet.open("127.0.0.1", 54321)
  end

  -- Experimental image reading
  local picture, failure = image.readPixelData(handle, 7, 160, 50)
  if picture then
    screen.drawImage(0, 0, picture, false)
  else
    print(failure)
    os.sleep(5)
  end
  -- End experimental crap

  local frameSize = handle:read(4)
  local frameBytes = bytesToInt(frameSize)

  local width = 160

  local x = 1
  local y = 1

  for i = 1,frameBytes,3 do
    local b = string.byte(handle:read(1), 1)
    local g = string.byte(handle:read(1), 1)
    local r = string.byte(handle:read(1), 1)
    --print(x..', '..y..': '..r..', '..g..', '..b)

    gpu.setForeground(color.RGBToInteger(r,g,b))
    gpu.fill(x, y, 1, 1, "▓")

    x = x + 1
    if x > width then
      x = 1
      y = y + 1
    end
  end

  handle:write(string.char(0xF1))
end
handle:close()
