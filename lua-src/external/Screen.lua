local component = require("component")
local unicode = require("unicode")
local gpu = component.gpu

-- Cache more functions and remove logger dependency
local componentInvoke = component.invoke
local unicodeWlen = unicode.wlen
local tableConcat = table.concat
local gpuSet = gpu.set
local gpuSetBackground = gpu.setBackground
local gpuSetForeground = gpu.setForeground

-- Pre-allocate common strings
local SPACE = " "

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

local function drawImage(x, y, image, blendForeground)
    local imageWidth, imageHeight = image.width, image.height
    local clippedImageWidth, clippedImageHeight = imageWidth, imageHeight
    
    -- Clipping calculations
    if x < drawLimitX1 then
        local temp = drawLimitX1 - x
        clippedImageWidth = clippedImageWidth - temp
        x = drawLimitX1
    end
    
    if x + clippedImageWidth - 1 > drawLimitX2 then
        clippedImageWidth = drawLimitX2 - x + 1
    end
    
    if y < drawLimitY1 then
        local temp = drawLimitY1 - y
        clippedImageHeight = clippedImageHeight - temp
        y = drawLimitY1
    end
    
    if y + clippedImageHeight - 1 > drawLimitY2 then
        clippedImageHeight = drawLimitY2 - y + 1
    end
    
    local screenIndex = bufferWidth * (y - 1) + x
    local screenIndexStep = bufferWidth - clippedImageWidth
    
    for py = 1, clippedImageHeight do
        for px = 1, clippedImageWidth do
            local bg, fg, char = image:getPixel(px, py)
            newFrameBackgrounds[screenIndex] = bg
            newFrameForegrounds[screenIndex] = fg
            newFrameChars[screenIndex] = char
            screenIndex = screenIndex + 1
        end
        screenIndex = screenIndex + screenIndexStep
    end
end

local function update(force)
    local index = bufferWidth * (drawLimitY1 - 1) + drawLimitX1
    local indexStep = bufferWidth - drawLimitX2 + drawLimitX1 - 1
    local changes = {}
    local currentForeground
    local lastBackground, lastForeground

    -- Pre-declare variables used in loops
    local x, currentBg, currentFg, currentChar, newBg, newFg, newChar
    local changesCurrentBg, changesBgFg, equalChars, equalCharsIndex

    for y = drawLimitY1, drawLimitY2 do
        x = drawLimitX1
        while x <= drawLimitX2 do
            currentBg, currentFg, currentChar = currentFrameBackgrounds[index], currentFrameForegrounds[index], currentFrameChars[index]
            newBg, newFg, newChar = newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index]

            if currentBg ~= newBg or currentFg ~= newFg or currentChar ~= newChar or force then
                -- Update frame buffers immediately
                currentFrameBackgrounds[index] = newBg
                currentFrameForegrounds[index] = newFg
                currentFrameChars[index] = newChar

                -- Get or create changes table for this background color
                changesCurrentBg = changes[newBg]
                if not changesCurrentBg then
                    changesCurrentBg = {}
                    changes[newBg] = changesCurrentBg
                end

                -- Get or create changes table for this foreground color
                changesBgFg = changesCurrentBg[newFg]
                if not changesBgFg then
                    changesBgFg = {index = 1}
                    changesCurrentBg[newFg] = changesBgFg
                end

                -- Store changes
                local idx = changesBgFg.index
                changesBgFg[idx] = x
                changesBgFg[idx + 1] = y
                changesBgFg[idx + 2] = newChar
                changesBgFg.index = idx + 3
            end
            
            x = x + 1
            index = index + 1
        end
        index = index + indexStep
    end

    -- Apply changes with minimal GPU state changes
    for background, foregrounds in pairs(changes) do
        gpuSetBackground(background)
        
        for foreground, pixels in pairs(foregrounds) do
            if currentForeground ~= foreground then
                gpuSetForeground(foreground)
                currentForeground = foreground
            end
            
            -- Draw in batches of same color
            local i = 1
            while i < pixels.index do
                gpuSet(pixels[i], pixels[i + 1], pixels[i + 2])
                i = i + 3
            end
        end
    end
end

return {
    setGPUAddress = setGPUAddress,
    drawImage = drawImage,
    update = update
}
