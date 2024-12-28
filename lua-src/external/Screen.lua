local component = require("component")
local unicode = require("unicode")
local logger = require("Logger")
local gpu = component.gpu

local componentInvoke = component.invoke
local unicodeWlen = unicode.wlen
local unicodeWlenCache = {}

local bufferWidth
local bufferHeight

local currentFrameBackgrounds
local currentFrameForegrounds
local currentFrameChars
local newFrameBackgrounds
local newFrameForegrounds
local newFrameChars

local drawLimitX1
local drawLimitX2
local drawLimitY1
local drawLimitY2

local GPUAddress

local function resetDrawLimit()
    drawLimitX1, drawLimitY1, drawLimitX2, drawLimitY2 = 1, 1, bufferWidth, bufferHeight
end

local function flush(width, height)
    if not width or not height then
        width, height = componentInvoke(GPUAddress, "getResolution")
    end

    currentFrameBackgrounds, currentFrameForegrounds, currentFrameChars, newFrameBackgrounds, newFrameForegrounds, newFrameChars = {}, {}, {}, {}, {}, {}
    bufferWidth = width
    bufferHeight = height

    resetDrawLimit()

    for i = 1, bufferWidth * bufferHeight do
        currentFrameBackgrounds[i] = 0x010101
        newFrameBackgrounds[i] = 0x010101
        currentFrameForegrounds[i] = 0xFEFEFE
        newFrameForegrounds[i] = 0xFEFEFE
        currentFrameChars[i] = " "
        newFrameChars[i] = " "
    end
end

local function setGPUAddress(address)
    GPUAddress = address
    gpu = component.gpu
    flush()
end

local function drawImage(x, y, picture, blendForeground)
    logger.log("Checkpoint 1")
    local imageWidth, imageHeight, pictureIndex, temp = picture[1], picture[2], 3
    local clippedImageWidth, clippedImageHeight = imageWidth, imageHeight

    -- Clipping left
    if (x < drawLimitX1) then
        temp = drawLimitX1 - x
        clippedImageWidth, x, pictureIndex = clippedImageWidth - temp, drawLimitX1, pictureIndex + temp * 3
    end

    -- Right
    temp = x + clippedImageWidth - 1

    if (temp > drawLimitX2) then
        clippedImageWidth = clippedImageWidth - temp + drawLimitX2
    end

    -- Top
    if (y < drawLimitY1) then
        temp = drawLimitY1 - y
        clippedImageHeight, y, pictureIndex = clippedImageHeight - temp, drawLimitY1, pictureIndex + temp * imageWidth * 3
    end

    -- Bottom
    temp = y + clippedImageHeight - 1

    if (temp > drawLimitY2) then
        clippedImageHeight = clippedImageHeight - temp + drawLimitY2
    end
    logger.log("Checkpoint 2")

    local screenIndex, screenIndexStep, pictureIndexStep, background, foreground, char = bufferWidth * (y - 1) + x, bufferWidth - clippedImageWidth, (imageWidth - clippedImageWidth) * 3

    for j = 1, clippedImageHeight do
        for i = 1, clippedImageWidth do
            newFrameBackgrounds[screenIndex], newFrameForegrounds[screenIndex] = picture[pictureIndex], picture[pictureIndex + 1]

            newFrameChars[screenIndex] = picture[pictureIndex + 2]

            screenIndex, pictureIndex = screenIndex + 1, pictureIndex + 3
        end

        screenIndex, pictureIndex = screenIndex + screenIndexStep, pictureIndex + pictureIndexStep
    end
    logger.log("Checkpoint 3")
end

local function update(force)
    logger.log("Checkpoint 4")
    local index, indexStepOnEveryLine, changes, x, charX, charIndex, charWlen, equalChars, equalCharsIndex, currentFrameBackground, currentFrameForeground, currentFrameChar, newFrameChar, newFrameForeground, newFrameBackground, changesCurrentFrameBackground, changesCurrentFrameBackgroundCurrentFrameForeground, changesCurrentFrameBackgroundCurrentFrameForegroundIndex, currentForeground = bufferWidth * (drawLimitY1 - 1) + drawLimitX1, (bufferWidth - drawLimitX2 + drawLimitX1 - 1), {}

    for y = drawLimitY1, drawLimitY2 do
        x = drawLimitX1

        while (x <= drawLimitX2) do
            currentFrameBackground, currentFrameForeground, currentFrameChar = currentFrameBackgrounds[index], currentFrameForegrounds[index], currentFrameChars[index]

            newFrameBackground, newFrameForeground, newFrameChar = newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index]

            if (currentFrameBackground ~= newFrameBackground or currentFrameForeground ~= newFrameForeground or currentFrameChar ~= newFrameChar or force) then
                currentFrameBackgrounds[index], currentFrameForegrounds[index], currentFrameChars[index], currentFrameBackground, currentFrameForeground, currentFrameChar = newFrameBackground, newFrameForeground, newFrameChar, newFrameBackground, newFrameForeground, newFrameChar

                charWlen = unicodeWlenCache[currentFrameChar]

                if (not charWlen) then
                    charWlen = unicodeWlen(currentFrameChar)
                    unicodeWlenCache[currentFrameChar] = charWlen
                end

                charX, charIndex, equalChars, equalCharsIndex = x + 1, index + 1, { currentFrameChar }, 2

                for i = 2, charWlen do
                    currentFrameBackgrounds[charIndex], currentFrameForegrounds[charIndex], currentFrameChars[charIndex], charX, charIndex = newFrameBackground, newFrameForeground, " ", charX + 1, charIndex + 1
                end

                while (charX <= drawLimitX2) do
                    newFrameBackground, newFrameForeground, newFrameChar = newFrameBackgrounds[charIndex], newFrameForegrounds[charIndex], newFrameChars[charIndex]

                    if (newFrameBackground == currentFrameBackground and (newFrameForeground == currentFrameForeground or newFrameChar == " ")) then
                        charWlen = unicodeWlenCache[newFrameChar]

                        if (not charWlen) then
                            charWlen = unicodeWlen(newFrameChar)
                            unicodeWlenCache[newFrameChar] = charWlen
                        end

                        currentFrameBackgrounds[charIndex], currentFrameForegrounds[charIndex], currentFrameChars[charIndex], charX, charIndex, equalChars[equalCharsIndex], equalCharsIndex = newFrameBackground, newFrameForeground, newFrameChar, charX + 1, charIndex + 1, newFrameChar, equalCharsIndex + 1

                        for i = 2, charWlen do
                            currentFrameBackgrounds[charIndex], currentFrameForegrounds[charIndex], currentFrameChars[charIndex], charX, charIndex = newFrameBackground, newFrameForeground, " ", charX + 1, charIndex + 1
                        end
                    else
                        break
                    end
                end

                changesCurrentFrameBackground = changes[currentFrameBackground] or {}
                changes[currentFrameBackground] = changesCurrentFrameBackground
                changesCurrentFrameBackgroundCurrentFrameForeground = changesCurrentFrameBackground[currentFrameForeground] or { index = 1 }
                changesCurrentFrameBackground[currentFrameForeground] = changesCurrentFrameBackgroundCurrentFrameForeground

                changesCurrentFrameBackgroundCurrentFrameForegroundIndex = changesCurrentFrameBackgroundCurrentFrameForeground.index
                changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = x, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
                changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = y, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
                changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = table.concat(equalChars), changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1

                x, index, changesCurrentFrameBackgroundCurrentFrameForeground.index = x + equalCharsIndex - 2, index + equalCharsIndex - 2, changesCurrentFrameBackgroundCurrentFrameForegroundIndex
            end

            x, index = x + 1, index + 1
        end

        index = index + indexStepOnEveryLine
    end
    logger.log("Checkpoint 5")

    for background, foregrounds in pairs(changes) do
        gpu.setBackground(background)

        for foreground, pixels in pairs(foregrounds) do
            if (currentForeground ~= foreground) then
                gpu.setForeground(foreground)
                currentForeground = foreground
            end

            for i = 1, #pixels, 3 do
                gpu.set(pixels[i], pixels[i + 1], pixels[i + 2])
            end
        end
    end
    logger.log("Checkpoint 6")

    changes = nil
end

return {
    setGPUAddress = setGPUAddress,
    drawImage = drawImage,
    update = update
}
