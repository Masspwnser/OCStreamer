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

local function readUnicodeChar(file)
	local byteArray = {string.byte(file:read(1))}

	local nullBitPosition = 0
	for i = 1, 7 do
		if bit32.band(bit32.rshift(byteArray[1], 8 - i), 0x1) == 0x0 then
			nullBitPosition = i
			break
		end
	end

	for i = 1, nullBitPosition - 2 do
		table.insert(byteArray, string.byte(file:read(1)))
	end

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

	for i = 1, width * height do
		table.insert(picture, color.to24Bit(string.byte(file:read(1))))
		table.insert(picture, color.to24Bit(string.byte(file:read(1))))
		table.insert(picture, string.byte(file:read(1)) / 255)
		table.insert(picture, readUnicodeChar(file))
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