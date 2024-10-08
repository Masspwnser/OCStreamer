local component = require("component")
local unicode = require("unicode")

--------------------------------------------------------------------------------

local
	componentInvoke,

	mathCeil,
	mathFloor,
	mathAbs,
	mathMin,
	mathMax,

	tableInsert,
	tableConcat,

	unicodeLen,
	unicodeSub,
	unicodeWlen,
	unicodeWlenCache,

	bufferWidth,
	bufferHeight,

	currentFrameBackgrounds,
	currentFrameForegrounds,
	currentFrameChars,
	newFrameBackgrounds,
	newFrameForegrounds,
	newFrameChars,

	drawLimitX1,
	drawLimitX2,
	drawLimitY1,
	drawLimitY2,

	GPUAddress =

	component.invoke,

	math.ceil,
	math.floor,
	math.abs,
	math.min,
	math.max,

	table.insert,
	table.concat,

	unicode.len,
	unicode.sub,
	unicode.wlen,
	{};

--------------------------------------------------------------------------------

local function getIndex(x, y)
	return bufferWidth * (y - 1) + x
end

local function getCurrentFrameTables()
	return currentFrameBackgrounds, currentFrameForegrounds, currentFrameChars
end

local function getNewFrameTables()
	return newFrameBackgrounds, newFrameForegrounds, newFrameChars
end

--------------------------------------------------------------------------------

local function setDrawLimit(x1, y1, x2, y2)
	drawLimitX1, drawLimitY1, drawLimitX2, drawLimitY2 = x1, y1, x2, y2
end

local function resetDrawLimit()
	drawLimitX1, drawLimitY1, drawLimitX2, drawLimitY2 = 1, 1, bufferWidth, bufferHeight
end

local function getDrawLimit()
	return drawLimitX1, drawLimitY1, drawLimitX2, drawLimitY2
end

--------------------------------------------------------------------------------

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

local function getGPUAddress()
	return GPUAddress
end

local function setGPUAddress(address)
	GPUAddress = address

	flush()
end

local function getScreenAddress()
	return componentInvoke(GPUAddress, "getScreen")
end

local function getMaxResolution()
	return componentInvoke(GPUAddress, "maxResolution")
end

local function setResolution(width, height)
	componentInvoke(GPUAddress, "setResolution", width, height)
	
	flush(width, height)
end

local function getColorDepth()
	return componentInvoke(GPUAddress, "getDepth")
end

local function setColorDepth(...)
	return componentInvoke(GPUAddress, "setDepth", ...)
end

local function getMaxColorDepth(...)
	return componentInvoke(GPUAddress, "maxDepth")
end

local function getScreenAspectRatio()
	return componentInvoke(getScreenAddress(), "getAspectRatio")
end

local function getResolution()
	return bufferWidth, bufferHeight
end

local function getWidth()
	return bufferWidth
end

local function getHeight()
	return bufferHeight
end

local function setScreenAddress(address, reset)
	local success, reason = componentInvoke(GPUAddress, "bind", address, reset)

	if success then
		if reset then
			setResolution(getMaxResolution())
		else
			setResolution(bufferWidth, bufferHeight)
		end
	else
		return success, reason
	end
end

local function getScaledResolution(scale)
	if not scale or scale > 1 then
		scale = 1
	elseif scale < 0.1 then
		scale = 0.1
	end
	
	local aspectWidth, aspectHeight = getScreenAspectRatio()
	local maxWidth, maxHeight = getMaxResolution()
	local proportion = 2 * (16 * aspectWidth - 4.5) / (16 * aspectHeight - 4.5)
	 
	local height = scale * mathMin(
		maxWidth / proportion,
		maxWidth,
		math.sqrt(maxWidth * maxHeight / proportion)
	)

	return math.floor(height * proportion), math.floor(height)
end

--------------------------------------------------------------------------------

local function rawSet(index, background, foreground, char)
	newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = background, foreground, char
end

local function rawGet(index)
	return newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index]
end

local function get(x, y)
	if x >= 1 and y >= 1 and x <= bufferWidth and y <= bufferHeight then
		local index = bufferWidth * (y - 1) + x
		
		return newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index]
	else
		return 0x000000, 0x000000, " "
	end
end

local function set(x, y, background, foreground, char)
	if x < drawLimitX1 or y < drawLimitY1 or x > drawLimitX2 or y > drawLimitY2 then
		return
	end

	local
		index,
		charWlen =
			bufferWidth * (y - 1) + x,
			unicodeWlenCache[char]
				
	if not charWlen then
		charWlen = unicodeWlen(char)
		unicodeWlenCache[char] = charWlen
	end

	newFrameBackgrounds[index],
	newFrameForegrounds[index],
	newFrameChars[index] =
		background,
		foreground,
		char

	index = index + 1

	for i = 2, charWlen do
		newFrameBackgrounds[index],
		newFrameForegrounds[index],
		newFrameChars[index] =
			background,
			foreground,
			" "

		index = index + 1
	end
end

local function clear(color, transparency)
	drawRectangle(1, 1, bufferWidth, bufferHeight, color or 0x0, 0x000000, " ", transparency)
end

local function rasterizeLine(x1, y1, x2, y2, method)
	local inLoopValueFrom, inLoopValueTo, outLoopValueFrom, outLoopValueTo, isReversed, inLoopValueDelta, outLoopValueDelta = x1, x2, y1, y2, false, mathAbs(x2 - x1), mathAbs(y2 - y1)
	if inLoopValueDelta < outLoopValueDelta then
		inLoopValueFrom, inLoopValueTo, outLoopValueFrom, outLoopValueTo, isReversed, inLoopValueDelta, outLoopValueDelta = y1, y2, x1, x2, true, outLoopValueDelta, inLoopValueDelta
	end

	if outLoopValueFrom > outLoopValueTo then
		outLoopValueFrom, outLoopValueTo = outLoopValueTo, outLoopValueFrom
		inLoopValueFrom, inLoopValueTo = inLoopValueTo, inLoopValueFrom
	end

	local outLoopValue, outLoopValueCounter, outLoopValueTriggerIncrement = outLoopValueFrom, 1, inLoopValueDelta / outLoopValueDelta
	local outLoopValueTrigger = outLoopValueTriggerIncrement
	
	for inLoopValue = inLoopValueFrom, inLoopValueTo, inLoopValueFrom < inLoopValueTo and 1 or -1 do
		if isReversed then
			method(outLoopValue, inLoopValue)
		else
			method(inLoopValue, outLoopValue)
		end

		outLoopValueCounter = outLoopValueCounter + 1
		if outLoopValueCounter > outLoopValueTrigger then
			outLoopValue, outLoopValueTrigger = outLoopValue + 1, outLoopValueTrigger + outLoopValueTriggerIncrement
		end
	end
end

local function rasterizeEllipse(centerX, centerY, radiusX, radiusY, method)
	local function rasterizeEllipsePoints(XP, YP)
		method(centerX + XP, centerY + YP)
		method(centerX - XP, centerY + YP)
		method(centerX - XP, centerY - YP)
		method(centerX + XP, centerY - YP) 
	end

	local x, y, changeX, changeY, ellipseError, twoASquare, twoBSquare = radiusX, 0, radiusY * radiusY * (1 - 2 * radiusX), radiusX * radiusX, 0, 2 * radiusX * radiusX, 2 * radiusY * radiusY
	local stoppingX, stoppingY = twoBSquare * radiusX, 0

	while stoppingX >= stoppingY do
		rasterizeEllipsePoints(x, y)
		
		y, stoppingY, ellipseError = y + 1, stoppingY + twoASquare, ellipseError + changeY
		changeY = changeY + twoASquare

		if (2 * ellipseError + changeX) > 0 then
			x, stoppingX, ellipseError = x - 1, stoppingX - twoBSquare, ellipseError + changeX
			changeX = changeX + twoBSquare
		end
	end

	x, y, changeX, changeY, ellipseError, stoppingX, stoppingY = 0, radiusY, radiusY * radiusY, radiusX * radiusX * (1 - 2 * radiusY), 0, 0, twoASquare * radiusY

	while stoppingX <= stoppingY do 
		rasterizeEllipsePoints(x, y)
		
		x, stoppingX, ellipseError = x + 1, stoppingX + twoBSquare, ellipseError + changeX
		changeX = changeX + twoBSquare
		
		if (2 * ellipseError + changeY) > 0 then
			y, stoppingY, ellipseError = y - 1, stoppingY - twoASquare, ellipseError + changeY
			changeY = changeY + twoASquare
		end
	end
end

local function rasterizePolygon(centerX, centerY, startX, startY, countOfEdges, method)
	local degreeStep = 360 / countOfEdges

	local deltaX, deltaY = startX - centerX, startY - centerY
	local radius = math.sqrt(deltaX ^ 2 + deltaY ^ 2)
	local halfRadius = radius / 2
	local startDegree = math.deg(math.asin(deltaX / radius))

	local function round(num) 
		if num >= 0 then
			return math.floor(num + 0.5) 
		else
			return math.ceil(num - 0.5)
		end
	end

	local function calculatePosition(degree)
		local radDegree = math.rad(degree)
		local deltaX2 = math.sin(radDegree) * radius
		local deltaY2 = math.cos(radDegree) * radius
		
		return round(centerX + deltaX2), round(centerY + (deltaY >= 0 and deltaY2 or -deltaY2))
	end

	local xOld, yOld, xNew, yNew = calculatePosition(startDegree)

	for degree = (startDegree + degreeStep - 1), (startDegree + 360), degreeStep do
		xNew, yNew = calculatePosition(degree)
		rasterizeLine(xOld, yOld, xNew, yNew, method)
		xOld, yOld = xNew, yNew
	end
end

local function drawLine(x1, y1, x2, y2, background, foreground, char)
	rasterizeLine(x1, y1, x2, y2, function(x, y)
		set(x, y, background, foreground, char)
	end)
end

local function drawEllipse(centerX, centerY, radiusX, radiusY, background, foreground, char)
	rasterizeEllipse(centerX, centerY, radiusX, radiusY, function(x, y)
		set(x, y, background, foreground, char)
	end)
end

local function drawPolygon(centerX, centerY, radiusX, radiusY, background, foreground, countOfEdges, char)
	rasterizePolygon(centerX, centerY, radiusX, radiusY, countOfEdges, function(x, y)
		set(x, y, background, foreground, char)
	end)
end

local function drawImage(x, y, picture, blendForeground)
	local imageWidth, imageHeight, pictureIndex, temp = picture[1], picture[2], 3
	local clippedImageWidth, clippedImageHeight = imageWidth, imageHeight

	-- Clipping left
	if x < drawLimitX1 then
		temp = drawLimitX1 - x
		clippedImageWidth, x, pictureIndex = clippedImageWidth - temp, drawLimitX1, pictureIndex + temp * 3
	end

	-- Right
	temp = x + clippedImageWidth - 1
	
	if temp > drawLimitX2 then
		clippedImageWidth = clippedImageWidth - temp + drawLimitX2
	end

	-- Top
	if y < drawLimitY1 then
		temp = drawLimitY1 - y
		clippedImageHeight, y, pictureIndex = clippedImageHeight - temp, drawLimitY1, pictureIndex + temp * imageWidth * 3
	end

	-- Bottom
	temp = y + clippedImageHeight - 1
	
	if temp > drawLimitY2 then
		clippedImageHeight = clippedImageHeight - temp + drawLimitY2
	end

	local
		screenIndex,
		screenIndexStep,
		pictureIndexStep,
		background,
		foreground,
		char = bufferWidth * (y - 1) + x, bufferWidth - clippedImageWidth, (imageWidth - clippedImageWidth) * 3

	for j = 1, clippedImageHeight do
		for i = 1, clippedImageWidth do
			newFrameBackgrounds[screenIndex], newFrameForegrounds[screenIndex] = picture[pictureIndex], picture[pictureIndex + 1]

			newFrameChars[screenIndex] = picture[pictureIndex + 2]

			screenIndex, pictureIndex = screenIndex + 1, pictureIndex + 3
		end

		screenIndex, pictureIndex = screenIndex + screenIndexStep, pictureIndex + pictureIndexStep
	end
end

local function drawFrame(x, y, width, height, color)
	local stringUp, stringDown, x2 = "┌" .. string.rep("─", width - 2) .. "┐", "└" .. string.rep("─", width - 2) .. "┘", x + width - 1
	
	drawText(x, y, color, stringUp); y = y + 1
	
	for i = 1, height - 2 do
		drawText(x, y, color, "│")
		drawText(x2, y, color, "│")
		
		y = y + 1
	end

	drawText(x, y, color, stringDown)
end

--------------------------------------------------------------------------------

local function semiPixelRawSet(index, color, yPercentTwoEqualsZero)
	local upperPixel, lowerPixel, bothPixel = "▀", "▄", " "
	local background, foreground, char = newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index]

	if yPercentTwoEqualsZero then
		if char == upperPixel then
			if color == foreground then
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = color, foreground, bothPixel
			else
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = color, foreground, char
			end
		elseif char == bothPixel then
			if color ~= background then
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = background, color, lowerPixel
			end
		else
			newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = background, color, lowerPixel
		end
	else
		if char == lowerPixel then
			if color == foreground then
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = color, foreground, bothPixel
			else
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = color, foreground, char
			end
		elseif char == bothPixel then
			if color ~= background then
				newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = background, color, upperPixel
			end
		else
			newFrameBackgrounds[index], newFrameForegrounds[index], newFrameChars[index] = background, color, upperPixel
		end
	end
end

local function semiPixelSet(x, y, color)
	local yFixed = mathCeil(y / 2)
	if x >= drawLimitX1 and yFixed >= drawLimitY1 and x <= drawLimitX2 and yFixed <= drawLimitY2 then
		semiPixelRawSet(bufferWidth * (yFixed - 1) + x, color, y % 2 == 0)
	end
end

local function drawSemiPixelRectangle(x, y, width, height, color)
	local index, evenYIndexStep, oddYIndexStep, realY, evenY =
		bufferWidth * (mathCeil(y / 2) - 1) + x,
		(bufferWidth - width),
		width

	for pseudoY = y, y + height - 1 do
		realY = mathCeil(pseudoY / 2)

		if realY >= drawLimitY1 and realY <= drawLimitY2 then
			evenY = pseudoY % 2 == 0
			
			for pseudoX = x, x + width - 1 do
				if pseudoX >= drawLimitX1 and pseudoX <= drawLimitX2 then
					semiPixelRawSet(index, color, evenY)
				end

				index = index + 1
			end
		else
			index = index + width
		end

		if evenY then
			index = index + evenYIndexStep
		else
			index = index - oddYIndexStep
		end
	end
end

local function drawSemiPixelLine(x1, y1, x2, y2, color)
	rasterizeLine(x1, y1, x2, y2, function(x, y)
		semiPixelSet(x, y, color)
	end)
end

local function drawSemiPixelEllipse(centerX, centerY, radiusX, radiusY, color)
	rasterizeEllipse(centerX, centerY, radiusX, radiusY, function(x, y)
		semiPixelSet(x, y, color)
	end)
end

--------------------------------------------------------------------------------

local function getPointTimedPosition(firstPoint, secondPoint, time)
	return {
		x = firstPoint.x + (secondPoint.x - firstPoint.x) * time,
		y = firstPoint.y + (secondPoint.y - firstPoint.y) * time
	}
end

local function getConnectionPoints(points, time)
	local connectionPoints = {}
	
	for point = 1, #points - 1 do
		tableInsert(connectionPoints, getPointTimedPosition(points[point], points[point + 1], time))
	end

	return connectionPoints
end

local function getMainPointPosition(points, time)
	if #points > 1 then
		return getMainPointPosition(getConnectionPoints(points, time), time)
	else
		return points[1]
	end
end

local function drawSemiPixelCurve(points, color, precision)
	local linePoints = {}
	
	for time = 0, 1, precision or 0.01 do
		tableInsert(linePoints, getMainPointPosition(points, time))
	end
	
	for point = 1, #linePoints - 1 do
		drawSemiPixelLine(mathFloor(linePoints[point].x), mathFloor(linePoints[point].y), mathFloor(linePoints[point + 1].x), mathFloor(linePoints[point + 1].y), color)
	end
end

--------------------------------------------------------------------------------

local function update(force)
	local
		index,
		indexStepOnEveryLine,
		changes,

		x,

		charX,
		charIndex,
		charWlen,
		
		equalChars,
		equalCharsIndex,

		currentFrameBackground,
		currentFrameForeground,
		currentFrameChar,
		newFrameChar,
		newFrameForeground,
		newFrameBackground,

		changesCurrentFrameBackground,
		changesCurrentFrameBackgroundCurrentFrameForeground,
		changesCurrentFrameBackgroundCurrentFrameForegroundIndex,

		currentForeground =
			bufferWidth * (drawLimitY1 - 1) + drawLimitX1,
			(bufferWidth - drawLimitX2 + drawLimitX1 - 1),
			{}

	for y = drawLimitY1, drawLimitY2 do
		x = drawLimitX1

		while x <= drawLimitX2 do
			-- Determine if some pixel data was changed (or if <force> argument was passed)
			currentFrameBackground,
			currentFrameForeground,
			currentFrameChar =
				currentFrameBackgrounds[index],
				currentFrameForegrounds[index],
				currentFrameChars[index]
			
			newFrameBackground,
			newFrameForeground,
			newFrameChar =
				newFrameBackgrounds[index],
				newFrameForegrounds[index],
				newFrameChars[index]

			if
				currentFrameBackground ~= newFrameBackground or
				currentFrameForeground ~= newFrameForeground or
				currentFrameChar ~= newFrameChar or
				force
			then
				-- Make pixel at both frames equal
				currentFrameBackgrounds[index],
				currentFrameForegrounds[index],
				currentFrameChars[index],

				currentFrameBackground,
				currentFrameForeground,
				currentFrameChar =
					newFrameBackground,
					newFrameForeground,
					newFrameChar,

					newFrameBackground,
					newFrameForeground,
					newFrameChar

				-- Look for pixels with equal chars from right of current pixel
				charWlen = unicodeWlenCache[currentFrameChar]
				
				if not charWlen then
					charWlen = unicodeWlen(currentFrameChar)
					unicodeWlenCache[currentFrameChar] = charWlen
				end

				charX,
				charIndex,
				equalChars,
				equalCharsIndex =
					x + 1,
					index + 1,
					{ currentFrameChar },
					2

				for i = 2, charWlen do
					currentFrameBackgrounds[charIndex],
					currentFrameForegrounds[charIndex],
					currentFrameChars[charIndex],

					charX,
					charIndex =
						newFrameBackground,
						newFrameForeground,
						" ",

						charX + 1,
						charIndex + 1
				end
				
				while charX <= drawLimitX2 do
					newFrameBackground,
					newFrameForeground,
					newFrameChar =
						newFrameBackgrounds[charIndex],
						newFrameForegrounds[charIndex],
						newFrameChars[charIndex]

					-- Pixels becomes equal only if they have same background and (whitespace char or same foreground)
					if	
						newFrameBackground == currentFrameBackground
						and (
							newFrameForeground == currentFrameForeground
							or newFrameChar == " "
						)
					then
						charWlen = unicodeWlenCache[newFrameChar]
						
						if not charWlen then
							charWlen = unicodeWlen(newFrameChar)
							unicodeWlenCache[newFrameChar] = charWlen
						end

						currentFrameBackgrounds[charIndex],
						currentFrameForegrounds[charIndex],
						currentFrameChars[charIndex],

						charX,
						charIndex,

						equalChars[equalCharsIndex],
						equalCharsIndex =
							newFrameBackground,
							newFrameForeground,
							newFrameChar,

							charX + 1,
							charIndex + 1,

							newFrameChar,
							equalCharsIndex + 1

						for i = 2, charWlen do
							currentFrameBackgrounds[charIndex],
							currentFrameForegrounds[charIndex],
							currentFrameChars[charIndex],

							charX,
							charIndex =
								newFrameBackground,
								newFrameForeground,
								" ",
								
								charX + 1,
								charIndex + 1
						end
					else
						break
					end
				end

				-- Group pixels that need to be drawn by background and foreground
				changesCurrentFrameBackground = changes[currentFrameBackground] or {}
				changes[currentFrameBackground] = changesCurrentFrameBackground
				changesCurrentFrameBackgroundCurrentFrameForeground = changesCurrentFrameBackground[currentFrameForeground] or {index = 1}
				changesCurrentFrameBackground[currentFrameForeground] = changesCurrentFrameBackgroundCurrentFrameForeground

				changesCurrentFrameBackgroundCurrentFrameForegroundIndex = changesCurrentFrameBackgroundCurrentFrameForeground.index
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = x, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = y, changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				changesCurrentFrameBackgroundCurrentFrameForeground[changesCurrentFrameBackgroundCurrentFrameForegroundIndex], changesCurrentFrameBackgroundCurrentFrameForegroundIndex = tableConcat(equalChars), changesCurrentFrameBackgroundCurrentFrameForegroundIndex + 1
				
				x, index, changesCurrentFrameBackgroundCurrentFrameForeground.index = x + equalCharsIndex - 2, index + equalCharsIndex - 2, changesCurrentFrameBackgroundCurrentFrameForegroundIndex
			end

			x, index = x + 1, index + 1
		end

		index = index + indexStepOnEveryLine
	end
	
	-- Draw grouped pixels on screen
	for background, foregrounds in pairs(changes) do
		componentInvoke(GPUAddress, "setBackground", background)

		for foreground, pixels in pairs(foregrounds) do
			if currentForeground ~= foreground then
				componentInvoke(GPUAddress, "setForeground", foreground)
				currentForeground = foreground
			end

			for i = 1, #pixels, 3 do
				componentInvoke(GPUAddress, "set", pixels[i], pixels[i + 1], pixels[i + 2])
			end
		end
	end

	changes = nil
end

--------------------------------------------------------------------------------
-- Evan's Additions
local buttons = {}
local selectedTab = "oldMonitor"

local function center(text, leftBound, rightBound)
	if not leftBound then
		leftBound = 1
	end
	if not rightBound then
		rightBound = getWidth()
	end
	local centerPoint = ((rightBound - leftBound) / 2) + leftBound
    local textLength = string.len(text)
    return math.floor(math.abs(centerPoint - (textLength / 2)))
end

-- Height must be an even number to preserve centering
local function makeButton(x, y, width, height, background, foreground, text, id, tabSelection)
	if not id or not x or not y then
		Logger.log("Incomplete params on the button")
	end
	if not background then
		background = 0x000000;
	end
	if not foreground then
		foreground = 0xFFFFFF;
	end
	drawSemiPixelRectangle(x, y, width, height, background)
	-- drawRectangle(x, y, width, height, background, 0x000000, " ", 0)
	if text and text ~= "" then
		local xpos = center(text, x, x+width)
		local ypos = math.floor((y/2) + (height/4))
	    drawText(xpos, ypos, foreground, text, 0)
	end
	buttons[id] = {
		id = id,
		x = x,
		y = y,
		width = width,
		height = height,
		selectedTab = tabSelection
	}
end

local function processTouch(x, y)
	y = y * 2 -- adjust for double-pixel
	for index, button in pairs(buttons) do
		if x >= button.x and x <= ((button.x - 1) + button.width) and
		y >= button.y and y <= ((button.y - 1) + button.height) then
			Logger.log("Button was selected, id: \"" .. button.id .. "\" (" .. button.x .. ", " .. button.y .. ") w: " .. button.width .. " h: " .. button.height)
			selectedTab = button.selectedTab
			return true
		end
	end
	return false
end

local function getSelectedTab()
	return selectedTab
end

--------------------------------------------------------------------------------

return {
	getIndex = getIndex,
	setDrawLimit = setDrawLimit,
	resetDrawLimit = resetDrawLimit,
	getDrawLimit = getDrawLimit,
	flush = flush,
	
	setResolution = setResolution,
	getMaxResolution = getMaxResolution,

	setGPUAddress = setGPUAddress,
	getGPUAddress = getGPUAddress,
	setScreenAddress = setScreenAddress,
	
	getColorDepth = getColorDepth,
	setColorDepth = setColorDepth,
	getMaxColorDepth = getMaxColorDepth,

	getScaledResolution = getScaledResolution,
	getResolution = getResolution,
	getWidth = getWidth,
	getHeight = getHeight,
	getCurrentFrameTables = getCurrentFrameTables,
	getNewFrameTables = getNewFrameTables,

	getScreenAspectRatio = getScreenAspectRatio,
	getScreenAddress = getScreenAddress,

	rawSet = rawSet,
	rawGet = rawGet,
	get = get,
	set = set,
	clear = clear,
	copy = copy,
	paste = paste,
	rasterizeLine = rasterizeLine,
	rasterizeEllipse = rasterizeEllipse,
	rasterizePolygon = rasterizePolygon,
	semiPixelRawSet = semiPixelRawSet,
	semiPixelSet = semiPixelSet,
	update = update,

	drawRectangle = drawRectangle,
	drawLine = drawLine,
	drawEllipse = drawEllipse,
	drawPolygon = drawPolygon,
	drawText = drawText,
	drawImage = drawImage,
	drawFrame = drawFrame,
	blur = blur,

	drawSemiPixelRectangle = drawSemiPixelRectangle,
	drawSemiPixelLine = drawSemiPixelLine,
	drawSemiPixelEllipse = drawSemiPixelEllipse,
	drawSemiPixelCurve = drawSemiPixelCurve,

	-- Evan's Additions
	makeButton = makeButton,
	processTouch = processTouch,
	center = center,
	getSelectedTab = getSelectedTab,
}
