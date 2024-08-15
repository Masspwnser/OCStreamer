local color = require("external/Color")
local bit32 = require("bit32")
local string = require("string")
local OCIFSignature = "OCIF"

local Functions = {}

-- Consider putting this inline with main if slow

local function bytesToInt(bytes)
    return bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 1) , 0xFF) , 24), bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 2) , 0xFF) , 16), bit32.bor(bit32.lshift(bit32.band(string.byte(bytes, 3) , 0xFF) , 8), bit32.band(string.byte(bytes, 4) , 0xFF))));
end

local function bytesToShort(bytes)
    return bit32.bor(bit32.lshift(string.byte(bytes, 1), 8), string.byte(bytes, 2))
end

local function readUnicodeChar(byte)
	-- Shenannigans to convert bitpacked braille to unicode, so lua plays nice.
	-- TODO Implement custom 8-bit braille -> character decoding?
	local byteArray = {0xE2}
	byteArray[2] = 0xA0 + bit32.rshift(bit32.band(byte, 0xC0), 6)
	byteArray[3] = 0x80 + bit32.band(byte, 0x3F)
	return string.char(table.unpack(byteArray))
end

local function readMetadata(file)
	return
		bytesToShort(file:read(2)),
		bytesToShort(file:read(2))
end

local function readPixelData(file, picture, width, height)
	picture[1] = width
	picture[2] = height
	local numPixels = width * height;
	for i = 1, numPixels do
		table.insert(picture, color.to24Bit(string.byte(file:read(1))))
		table.insert(picture, color.to24Bit(string.byte(file:read(1))))
		table.insert(picture, readUnicodeChar(string.byte(file:read(1))))
	end
end

function Functions.readMetadata(file)
	local unwantedSignature = file:read(#OCIFSignature)

    local unwantedEncoding = file:read(1)

    local width, height = readMetadata(file, picture)

    return signature, encodingMethod, width, height
end

function Functions.readPixelData(file, encodingMethod, width, height)
	local picture = {} -- REALLY BAD DONT MAKE SO MANY TABLES
	local result, reason = readPixelData(file, picture, width, height)
    return picture
end

return Functions