local Face = require("face")
local SnakeCosmetics = require("snakecosmetics")
local ModuleUtil = require("moduleutil")
local RenderLayers = require("renderlayers")
local Timer = require("timer")

local abs = math.abs
local atan = math.atan
local atan2 = math.atan2
local cos = math.cos
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local tau = math.pi * 2
local sin = math.sin
local sqrt = math.sqrt

local SnakeDraw = ModuleUtil.create("SnakeDraw")

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 3
local FRUIT_BULGE_SCALE = 1.25
local defaultTailFlashColor = {1, 0, 0}

local glowSprite = nil
local glowSpriteResolution = 128

local zephyrPoints = {}
local zephyrPointCapacity = 0
local stormBolt = {}
local stormBoltCapacity = 0
local stormBoltCenters = {}
local stormBoltCenterCapacity = 0

local function ensureBufferCapacity(buffer, capacity, needed)
	if capacity < needed then
		for i = capacity + 1, needed do
			buffer[i] = 0
		end
		capacity = needed
	end
	return capacity
end

local function trimBuffer(buffer, used, capacity)
	if used < capacity then
		for i = used + 1, capacity do
			buffer[i] = nil
		end
	end
end

local drawTrailSegmentToCanvas

local function rebuildGlowSprite()
	local size = max(8, glowSpriteResolution)
	local imageData = love.image.newImageData(size, size)
	local center = (size - 1) * 0.5
	local radius = max(center, 1)

	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local dx = (x - center) / radius
			local dy = (y - center) / radius
			local dist = sqrt(dx * dx + dy * dy)
			local fade = 0

			if dist < 1 then
				local falloff = 1 - dist
				fade = falloff * falloff
			end

			imageData:setPixel(x, y, fade, fade, fade, fade)
		end
	end

	local sprite = love.graphics.newImage(imageData)
	sprite:setFilter("linear", "linear")
	glowSprite = sprite
end

local function ensureGlowSprite()
	if not glowSprite then
		rebuildGlowSprite()
	end

	return glowSprite
end


local shadowPalette = {
	body = {0, 0, 0, 0.25},
	outline = {0, 0, 0, 0.25},
	singlePass = true,
	blendMode = "replace",
}



-- helper: prefer drawX/drawY, fallback to x/y
local function ptXY(p)
	if not p then return nil, nil end
	return (p.drawX or p.x), (p.drawY or p.y)
end

local drawSoftGlow

-- coordinate buffer cache so we can reuse allocations per trail
local coordsCache = setmetatable({}, { __mode = "k" })
local coordsCacheFrame = setmetatable({}, { __mode = "k" })
local currentCoordsFrame = 0
local emptyCoords = {}

local segmentVectorCache = setmetatable({}, { __mode = "k" })
local segmentVectorFrame = setmetatable({}, { __mode = "k" })

local function buildSegmentVectors(trail)
	if not trail then
		return nil
	end

	local cached = segmentVectorCache[trail]
	if currentCoordsFrame > 0 and segmentVectorFrame[trail] == currentCoordsFrame and cached then
		return cached
	end

	local data = cached or {
		posX = {},
		posY = {},
		dirX = {},
		dirY = {},
		perpX = {},
		perpY = {},
		len = {},
		_lastCount = 0,
	}

	local posX = data.posX
	local posY = data.posY
	local dirX = data.dirX
	local dirY = data.dirY
	local perpX = data.perpX
	local perpY = data.perpY
	local len = data.len

	local count = #trail
	for i = 1, count do
		local x, y = ptXY(trail[i])
		posX[i] = x
		posY[i] = y
	end

	for i = 1, count - 1 do
		local x1, y1 = posX[i], posY[i]
		local x2, y2 = posX[i + 1], posY[i + 1]
		if x1 and y1 and x2 and y2 then
			local dx = x2 - x1
			local dy = y2 - y1
			local segLen = sqrt(dx * dx + dy * dy)
			len[i] = segLen
			if segLen > 1e-6 then
				local nx = dx / segLen
				local ny = dy / segLen
				dirX[i] = nx
				dirY[i] = ny
				perpX[i] = -ny
				perpY[i] = nx
			else
				dirX[i], dirY[i], perpX[i], perpY[i] = 0, 0, 0, 0
			end
		else
			len[i] = 0
			dirX[i], dirY[i], perpX[i], perpY[i] = 0, 0, 0, 0
		end
	end

	local previousCount = data._lastCount or 0
	for i = count + 1, previousCount do
		posX[i], posY[i], dirX[i], dirY[i], perpX[i], perpY[i], len[i] = nil, nil, nil, nil, nil, nil, nil
	end

	if count >= 1 then
		dirX[count], dirY[count], perpX[count], perpY[count], len[count] = nil, nil, nil, nil, nil
	end

	data._lastCount = count
	segmentVectorCache[trail] = data
	segmentVectorFrame[trail] = currentCoordsFrame

	return data
end

local function resolveSegmentSpan(trail, vectors, startIndex, endIndex)
	if not (trail and startIndex and endIndex) then
		return nil
	end

	if endIndex < startIndex then
		startIndex, endIndex = endIndex, startIndex
	end

	local posX, posY
	if vectors then
		posX = vectors.posX
		posY = vectors.posY
	end

	local x1 = posX and posX[startIndex]
	local y1 = posY and posY[startIndex]
	local x2 = posX and posX[endIndex]
	local y2 = posY and posY[endIndex]

	if not (x1 and y1) then
		local seg = trail[startIndex]
		x1, y1 = ptXY(seg)
	end

	if not (x2 and y2) then
		local seg = trail[endIndex]
		x2, y2 = ptXY(seg)
	end

	if not (x1 and y1 and x2 and y2) then
		return nil
	end

	if endIndex <= startIndex then
		return x1, y1, x2, y2, 0, 0, 0, 0, 0
	end

	local dirX, dirY, perpX, perpY, length = 0, 0, 0, 0, 0

	if vectors then
		if endIndex == startIndex + 1 then
			dirX = vectors.dirX[startIndex] or 0
			dirY = vectors.dirY[startIndex] or 0
			perpX = vectors.perpX[startIndex] or 0
			perpY = vectors.perpY[startIndex] or 0
			length = vectors.len[startIndex] or 0
		else
			local totalX, totalY = 0, 0
			for i = startIndex, endIndex - 1 do
				local segLen = vectors.len[i]
				if segLen and segLen > 0 then
					local nx = vectors.dirX[i] or 0
					local ny = vectors.dirY[i] or 0
					totalX = totalX + nx * segLen
					totalY = totalY + ny * segLen
				end
			end
			length = sqrt(totalX * totalX + totalY * totalY)
			if length > 1e-6 then
				dirX = totalX / length
				dirY = totalY / length
				perpX = -dirY
				perpY = dirX
			end
		end
	end

	if length <= 0 then
		local dx = x2 - x1
		local dy = y2 - y1
		length = sqrt(dx * dx + dy * dy)
		if length > 1e-6 then
			dirX = dx / length
			dirY = dy / length
			perpX = -dirY
			perpY = dirX
		end
	elseif (perpX == 0 and perpY == 0) and (dirX ~= 0 or dirY ~= 0) then
		perpX = -dirY
		perpY = dirX
	end

	return x1, y1, x2, y2, dirX, dirY, perpX, perpY, length
end

-- polyline coords {x1,y1,x2,y2,...}
local function buildCoords(trail)
	if not trail then
		return emptyCoords
	end

	local cached = coordsCache[trail]
	if currentCoordsFrame > 0 and coordsCacheFrame[trail] == currentCoordsFrame and cached then
		return cached
	end

	local coords = cached or {}
	local previousCount = coords._used or 0
	local count = 0
	local lastx, lasty

	for i = 1, #trail do
		local x, y = ptXY(trail[i])
		if x and y then
			if not (lastx and lasty and x == lastx and y == lasty) then
				local writeIndex = count + 1
				local writeNext = writeIndex + 1

				if coords[writeIndex] ~= x then
					coords[writeIndex] = x
				end
				if coords[writeNext] ~= y then
					coords[writeNext] = y
				end

				count = writeNext
				lastx, lasty = x, y
			end
		end
	end

	if count < previousCount then
		for i = count + 1, previousCount do
			coords[i] = nil
		end
	end

	coords._used = count
	coordsCache[trail] = coords
	coordsCacheFrame[trail] = currentCoordsFrame

	return coords
end

local fruitMarkerCoords = {}
local fruitMarkerCount = 0

local function collectFruitMarkers(trail)
	local count = 0

	if trail then
		for i = 1, #trail do
			local seg = trail[i]
			if seg and seg.fruitMarker then
				local x = seg.fruitMarkerX or seg.drawX or seg.x
				local y = seg.fruitMarkerY or seg.drawY or seg.y

				if x and y then
					count = count + 1
					local idx = count * 2 - 1
					fruitMarkerCoords[idx] = x
					fruitMarkerCoords[idx + 1] = y
				end
			end
		end
	end

	local used = count * 2
	local previousUsed = fruitMarkerCount * 2
	if used < previousUsed then
		for i = used + 1, previousUsed do
			fruitMarkerCoords[i] = nil
		end
	end

	fruitMarkerCount = count

	return fruitMarkerCoords, fruitMarkerCount
end

local function drawFruitBulges(markerCoords, markerCount, radius)
	if not markerCoords or radius <= 0 or markerCount <= 0 then return end

	for i = 1, markerCount do
		local idx = (i - 1) * 2
		local x = markerCoords[idx + 1]
		local y = markerCoords[idx + 2]

		if x and y then
			love.graphics.circle("fill", x, y, radius)
		end
	end
end

local function drawCornerCaps(path, radius)
	if not path or radius <= 0 then
		return
	end

	local coordCount = #path
	if coordCount < 6 then
		return
	end

	local pointCount = floor(coordCount / 2)
	if pointCount < 3 then
		return
	end

	for pointIndex = 2, pointCount - 1 do
		local px = path[(pointIndex - 1) * 2 - 1]
		local py = path[(pointIndex - 1) * 2]
		local x = path[pointIndex * 2 - 1]
		local y = path[pointIndex * 2]
		local nx = path[(pointIndex + 1) * 2 - 1]
		local ny = path[(pointIndex + 1) * 2]

		if px and py and x and y and nx and ny then
			local dx1 = x - px
			local dy1 = y - py
			local dx2 = nx - x
			local dy2 = ny - y

			local len1 = sqrt(dx1 * dx1 + dy1 * dy1)
			local len2 = sqrt(dx2 * dx2 + dy2 * dy2)

			if len1 > 1e-6 and len2 > 1e-6 then
				local dot = (dx1 * dx2 + dy1 * dy2) / (len1 * len2)
				if dot > 1 then dot = 1 end
				if dot < -1 then dot = -1 end

				if abs(dot - 1) > 1e-3 then
					love.graphics.circle("fill", x, y, radius)
				end
			end
		end
	end
end

local function drawSnakeStroke(path, radius, options)
	if not path or radius <= 0 or #path < 2 then
		return
	end

	if #path == 2 then
		if options and options.sharpCorners then
			local x, y = path[1], path[2]
			love.graphics.rectangle("fill", x - radius, y - radius, radius * 2, radius * 2)
		else
			local skipStartCap = options and options.flatStartCap
			local skipEndCap = options and options.flatEndCap
			if not (skipStartCap or skipEndCap) then
				love.graphics.circle("fill", path[1], path[2], radius)
			end
		end
		return
	end

	love.graphics.setLineWidth(radius * 2)
	love.graphics.line(path)

	local firstX, firstY = path[1], path[2]
	local lastX, lastY = path[#path - 1], path[#path]

	local useRoundCaps = not (options and options.sharpCorners)
	local skipStartCap = options and options.flatStartCap
	local skipEndCap = options and options.flatEndCap

	if firstX and firstY and useRoundCaps and not skipStartCap then
		love.graphics.circle("fill", firstX, firstY, radius)
	end

	if lastX and lastY and useRoundCaps and not skipEndCap then
		love.graphics.circle("fill", lastX, lastY, radius)
	end

	drawCornerCaps(path, radius)
end

local function renderSnakeToCanvas(trail, coords, head, half, options, palette)
	local paletteBody = palette and palette.body
	local paletteOutline = palette and palette.outline

	local bodyColor = paletteBody or SnakeCosmetics:getBodyColor()
	local outlineColor = paletteOutline or SnakeCosmetics:getOutlineColor()
	local bodyR, bodyG, bodyB, bodyA = bodyColor[1] or 0, bodyColor[2] or 0, bodyColor[3] or 0, bodyColor[4] or 1
	local outlineR, outlineG, outlineB, outlineA = outlineColor[1] or 0, outlineColor[2] or 0, outlineColor[3] or 0, outlineColor[4] or 1

	local tailFlashIntensity = options and options.tailHitFlash
	if tailFlashIntensity and tailFlashIntensity > 0 then
		local blend = min(1, max(0, tailFlashIntensity))
		local tailFlashColor = (options and options.tailHitFlashColor) or defaultTailFlashColor
		local flashR = tailFlashColor[1] or 1
		local flashG = tailFlashColor[2] or 0
		local flashB = tailFlashColor[3] or 0

		bodyR = bodyR + (flashR - bodyR) * blend
		bodyG = bodyG + (flashG - bodyG) * blend
		bodyB = bodyB + (flashB - bodyB) * blend

		outlineR = outlineR + (flashR - outlineR) * blend
		outlineG = outlineG + (flashG - outlineG) * blend
		outlineB = outlineB + (flashB - outlineB) * blend
	end
	local bulgeRadius = half * FRUIT_BULGE_SCALE

	local sharpCorners = options and options.sharpCorners

	local outlineCoords = coords
	local bodyCoords = coords

	love.graphics.push("all")

	if palette and palette.blendMode then
		if palette.blendAlphaMode then
			love.graphics.setBlendMode(palette.blendMode, palette.blendAlphaMode)
		else
			love.graphics.setBlendMode(palette.blendMode)
		end
	end

	if sharpCorners then
		love.graphics.setLineStyle("rough")
		love.graphics.setLineJoin("miter")
	else
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineJoin("bevel")
	end

	local fruitMarkers, fruitMarkerCount = collectFruitMarkers(trail)

	if palette and palette.singlePass then
		local fillR, fillG, fillB, fillA = bodyR, bodyG, bodyB, bodyA
		if outlineA and outlineA > fillA then
			fillR, fillG, fillB, fillA = outlineR, outlineG, outlineB, outlineA
		end
		love.graphics.setColor(fillR, fillG, fillB, fillA)
		drawSnakeStroke(outlineCoords, half + OUTLINE_SIZE, options)
		drawFruitBulges(fruitMarkers, fruitMarkerCount, bulgeRadius + OUTLINE_SIZE)
	else
		love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
		drawSnakeStroke(outlineCoords, half + OUTLINE_SIZE, options)
		drawFruitBulges(fruitMarkers, fruitMarkerCount, bulgeRadius + OUTLINE_SIZE)

		love.graphics.setColor(bodyR, bodyG, bodyB, bodyA)
		drawSnakeStroke(bodyCoords, half, options)
		drawFruitBulges(fruitMarkers, fruitMarkerCount, bulgeRadius)
	end

	love.graphics.pop()

end

drawSoftGlow = function(x, y, radius, r, g, b, a, blendMode)
	if radius <= 0 then return end

	local sprite = ensureGlowSprite()
	if not sprite then return end

	local colorR = r or 0
	local colorG = g or 0
	local colorB = b or 0
	local colorA = a or 1
	local mode = blendMode or "add"

	local previousBlendMode, previousAlphaMode = love.graphics.getBlendMode()
	local previousR, previousG, previousB, previousA = love.graphics.getColor()

	local targetBlendMode, targetAlphaMode
	if mode == "alpha" then
		targetBlendMode, targetAlphaMode = "alpha", "premultiplied"
	else
		targetBlendMode, targetAlphaMode = "add", nil
	end

	if previousBlendMode ~= targetBlendMode or previousAlphaMode ~= targetAlphaMode then
		if targetAlphaMode then
			love.graphics.setBlendMode(targetBlendMode, targetAlphaMode)
		else
			love.graphics.setBlendMode(targetBlendMode)
		end
	end

	if mode == "alpha" then
		love.graphics.setColor(colorR * colorA, colorG * colorA, colorB * colorA, colorA)
	else
		love.graphics.setColor(colorR, colorG, colorB, colorA)
	end

	local spriteWidth, spriteHeight = sprite:getWidth(), sprite:getHeight()
	local scaleX = (radius * 2) / spriteWidth
	local scaleY = (radius * 2) / spriteHeight
	love.graphics.draw(sprite, x, y, 0, scaleX, scaleY, spriteWidth * 0.5, spriteHeight * 0.5)

	love.graphics.setColor(previousR, previousG, previousB, previousA)

	if previousBlendMode ~= targetBlendMode or previousAlphaMode ~= targetAlphaMode then
		if previousAlphaMode then
			love.graphics.setBlendMode(previousBlendMode, previousAlphaMode)
		else
			love.graphics.setBlendMode(previousBlendMode)
		end
	end
end

local function drawPortalHole(hole, isExit)
	if not hole then
		return
	end

	local visibility = hole.visibility or 0
	if visibility <= 1e-3 then
		return
	end

	local x = hole.x or 0
	local y = hole.y or 0
	local radius = hole.radius or 0
	if radius <= 1e-3 then
		return
	end

	local open = hole.open or 0
	local spin = hole.spin or 0
	local fillAlpha = (isExit and (0.45 + 0.25 * open) or (0.6 + 0.3 * open)) * visibility

	local accentR, accentG, accentB
	if isExit then
		accentR, accentG, accentB = 1.0, 0.88, 0.4
	else
		accentR, accentG, accentB = 0.45, 0.78, 1.0
	end

	love.graphics.push("all")
	love.graphics.setBlendMode("alpha", "premultiplied")

	love.graphics.setColor(0, 0, 0, fillAlpha)
	love.graphics.circle("fill", x, y, radius)

	local depthLayers = 3
	for i = 1, depthLayers do
		local t = (i - 0.5) / depthLayers
		local depthRadius = radius * (0.45 + 0.38 * t * (1 + 0.25 * open))
		local depthAlpha = fillAlpha * (0.22 + 0.55 * (1 - t))

		if isExit then
			love.graphics.setColor(0.12, 0.09, 0.02, depthAlpha)
		else
			love.graphics.setColor(0.05, 0.1, 0.18, depthAlpha)
		end

		love.graphics.circle("fill", x, y, depthRadius)
	end

	local rimRadius = radius * (1.05 + 0.15 * open)
	local rimAlpha = (0.35 + 0.4 * open) * visibility
	love.graphics.setLineWidth(2 + 2 * open)
	love.graphics.setColor(accentR, accentG, accentB, rimAlpha)
	love.graphics.circle("line", x, y, rimRadius)

	local arcRadius = radius * (0.68 + 0.12 * open)
	local arcAlpha = (0.28 + 0.32 * open) * visibility
	local arcSpan = pi * (0.75 + 0.35 * open)
	love.graphics.setColor(accentR, accentG, accentB, arcAlpha)
	love.graphics.arc("line", x, y, arcRadius, spin, spin + arcSpan)
	love.graphics.arc("line", x, y, arcRadius * 0.74, spin + pi * 0.92, spin + pi * 0.92 + arcSpan * 0.6)

	local swirlAlpha = (0.14 + 0.3 * open) * visibility
	if swirlAlpha > 1e-3 then
		love.graphics.setLineWidth(1.5 + 1.5 * open)
		love.graphics.setColor(accentR, accentG, accentB, swirlAlpha)

		local pulse = hole.pulse or 0
		local swirlLayers = 2
		for i = 1, swirlLayers do
			local layerRadius = radius * (0.42 + 0.16 * i + 0.08 * open)
			local layerSpan = pi * (0.42 + 0.18 * open)
			local offset = (i % 2 == 0) and (pi * 0.65) or 0
			local startAngle = spin * (0.85 + 0.2 * i) + pulse * (0.5 + 0.15 * i) + offset
			love.graphics.arc("line", x, y, layerRadius, startAngle, startAngle + layerSpan)
		end
	end

	local sparkleAlpha = (0.18 + 0.22 * open) * visibility
	if sparkleAlpha > 1e-3 then
		love.graphics.setLineWidth(1)
		local pulse = hole.pulse or 0
		local sparkleCount = isExit and 4 or 3
		for i = 1, sparkleCount do
			local angle = spin * (0.6 + 0.18 * i) + pulse * (0.9 + 0.25 * i) + (i - 1) * tau / sparkleCount
			local distance = radius * (0.32 + 0.22 * open)
			local sx = x + cos(angle) * distance
			local sy = y + sin(angle) * distance
			local sparkleRadius = radius * (0.08 + 0.04 * open)
			love.graphics.setColor(accentR, accentG, accentB, sparkleAlpha)
			love.graphics.circle("fill", sx, sy, sparkleRadius)
			love.graphics.setColor(1, 1, 1, sparkleAlpha * 0.55)
			love.graphics.circle("fill", sx, sy, sparkleRadius * 0.55)
		end
	end

	love.graphics.setLineWidth(1)
	love.graphics.pop()
end

local function fadePalette(palette, alphaScale)
	local scale = alphaScale or 1
	local baseBody = (palette and palette.body) or SnakeCosmetics:getBodyColor()
	local baseOutline = (palette and palette.outline) or SnakeCosmetics:getOutlineColor()

	local faded = {
		body = {
			baseBody[1] or 1,
			baseBody[2] or 1,
			baseBody[3] or 1,
			(baseBody[4] or 1) * scale,
		},
		outline = {
			baseOutline[1] or 0,
			baseOutline[2] or 0,
			baseOutline[3] or 0,
			(baseOutline[4] or 1) * scale,
		},
	}

	return faded
end

drawTrailSegmentToCanvas = function(trail, half, options, paletteOverride, coordsOverride)
	if not trail or #trail == 0 then
		return
	end

	local coords = coordsOverride or buildCoords(trail)
	local head = trail[1]

	if #coords >= 4 then
		renderSnakeToCanvas(trail, coords, head, half, options, paletteOverride)
		return
	end

	local hx = head and (head.drawX or head.x)
	local hy = head and (head.drawY or head.y)
	if not (hx and hy) then
		return
	end

	local palette = paletteOverride or {}
	local bodyColor = palette.body or SnakeCosmetics:getBodyColor()
	local outlineColor = palette.outline or SnakeCosmetics:getOutlineColor()
	local singlePass = palette.singlePass

	love.graphics.push("all")

	if paletteOverride then
		local blendMode = paletteOverride.blendMode
		local blendAlphaMode = paletteOverride.blendAlphaMode
		if blendMode then
			if blendAlphaMode then
				love.graphics.setBlendMode(blendMode, blendAlphaMode)
			else
				love.graphics.setBlendMode(blendMode)
			end
		end
	end
	local skipStartCap = options and options.flatStartCap
	local skipEndCap = options and options.flatEndCap

	if singlePass then
		local fillR = bodyColor[1] or 1
		local fillG = bodyColor[2] or 1
		local fillB = bodyColor[3] or 1
		local fillA = bodyColor[4] or 1
		local outlineA = outlineColor[4] or 0
		if outlineA > fillA then
			fillR = outlineColor[1] or fillR
			fillG = outlineColor[2] or fillG
			fillB = outlineColor[3] or fillB
			fillA = outlineA
		end
		love.graphics.setColor(fillR, fillG, fillB, fillA)
		if not (skipStartCap or skipEndCap) then
			love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
		end
	else
		love.graphics.setColor(outlineColor[1] or 0, outlineColor[2] or 0, outlineColor[3] or 0, outlineColor[4] or 1)
		if not (skipStartCap or skipEndCap) then
			love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
		end
		love.graphics.setColor(bodyColor[1] or 1, bodyColor[2] or 1, bodyColor[3] or 1, bodyColor[4] or 1)
		if not (skipStartCap or skipEndCap) then
			love.graphics.circle("fill", hx, hy, half)
		end
	end
	love.graphics.pop()
end

local function drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)
        local hasShield = shieldCount and shieldCount > 0
        if not hasShield and not (shieldFlashTimer and shieldFlashTimer > 0) then
                return
        end

	local baseRadius = SEGMENT_SIZE * (0.95 + 0.06 * max(0, (shieldCount or 1) - 1))
	local time = Timer.getTime()

	local pulse = 1 + 0.08 * sin(time * 6)
	local alpha = 0.35 + 0.1 * sin(time * 5)

	if shieldFlashTimer and shieldFlashTimer > 0 then
		local flash = min(1, shieldFlashTimer / 0.3)
		pulse = pulse + flash * 0.25
		alpha = alpha + flash * 0.4
	end

	love.graphics.setLineWidth(4)
	local lineAlpha = alpha + (hasShield and 0.25 or 0.45)
	love.graphics.setColor(0.45, 0.85, 1, lineAlpha)
	love.graphics.circle("line", hx, hy, baseRadius * pulse)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
end

local function drawMomentumCoilsAura(trail, SEGMENT_SIZE, data)
        if not trail or not data then return end
        local head = trail[1]
        if not head then return end

        local hx, hy = head.drawX, head.drawY
        if not (hx and hy) then return end

        local stacks = max(0, data.stacks or 0)
        if stacks <= 0 then return end

        local intensity = max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local time = data.time or 0
        local target = max(0, data.target or 0)
        local coilCount = min(3, max(1, floor(stacks + 0.25)))
        local baseRadius = SEGMENT_SIZE * (0.92 + 0.08 * min(stacks, 4))
        local sweep = 0.9 + 0.25 * intensity
        local width = SEGMENT_SIZE * (0.12 + 0.02 * intensity)
        local accentColor = {0.62, 0.5, 0.96, 0.42 + 0.35 * intensity}
        local baseColor = {0.86, 0.74, 1.0, 0.28 + 0.28 * (intensity + target)}

        drawSoftGlow(hx, hy, baseRadius * (1.2 + 0.18 * intensity), 0.86, 0.74, 1.0, 0.16 + 0.24 * intensity, "add")

        love.graphics.setLineWidth(width)
        for i = 1, coilCount do
                local offset = (i - 0.5) / coilCount
                local angle = time * (1.5 + 0.35 * intensity) + offset * pi * 1.3
                local wobble = sin(time * 1.4 + i) * 0.25
                local radius = baseRadius * (0.9 + 0.12 * i + 0.08 * wobble)
                local fade = max(0, 1 - (i - 1) * 0.22)

                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] * fade)
                love.graphics.arc("line", "open", hx, hy, radius, angle - sweep, angle + sweep, 22)

                local secondaryRadius = radius * (0.86 + 0.04 * sin(time * 2 + i))
                love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentColor[4] * fade)
                love.graphics.arc("line", "open", hx, hy, secondaryRadius, angle + pi * 0.45 - sweep * 0.8, angle + pi * 0.45 + sweep * 0.8, 18)
        end

        local highlightSegments = min(#trail, 4)
        for i = 1, highlightSegments do
                local seg = trail[i]
                if seg then
                        local scale = 0.55 + 0.08 * stacks + 0.04 * i
                        local alpha = (0.16 + 0.24 * intensity) * (1 - (i - 1) * 0.18)
                        drawSoftGlow(seg.drawX, seg.drawY, SEGMENT_SIZE * scale, 0.86, 0.74, 1.0, alpha, "add")
                end
        end

        love.graphics.setLineWidth(1)
end

local function drawswiftFangsAura(hx, hy, SEGMENT_SIZE, data)
        if not data then return end

        local stacks = data.stacks
        local intensity = data.intensity
	local flash = data.flash
	local target = data.target

	if type(data[1]) == "table" then
		local combinedStacks = 0
		local combinedIntensity = 0
		local combinedFlash = 0
		local combinedTarget = 0

		for _, entry in ipairs(data) do
			combinedStacks = combinedStacks + (entry.stacks or 0)
			combinedIntensity = max(combinedIntensity, entry.intensity or 0)
			combinedFlash = max(combinedFlash, entry.flash or 0)
			combinedTarget = max(combinedTarget, entry.target or 0)
		end

		stacks = combinedStacks
		intensity = combinedIntensity
		flash = combinedFlash
		target = combinedTarget
	end

	stacks = stacks or 0
	if stacks <= 0 then return end

	intensity = max(0, intensity or 0)
	if intensity <= 0.01 then return end

	flash = max(0, flash or 0)
	target = max(0, target or 0)

	local highlight = min(1, intensity * 0.85 + flash * 0.6)

	local headRadius = SEGMENT_SIZE * 0.4
	local rawStacks = max(0, stacks)
	local baseStacks = min(rawStacks, 4)
	local overflowStacks = max(0, rawStacks - 4)
	local visualStacks = baseStacks + overflowStacks * 1.35
	local activityScale = 1 + target * 0.35
	local stackFactor = visualStacks * activityScale

	-- Always draw a single mirrored pair of fangs; stacks only change their size.
	local fangLength = headRadius * (0.75 + 0.12 * stackFactor)
	local fangWidth = headRadius * (0.35 + 0.05 * stackFactor)
	local spacing = headRadius * (0.35 + 0.02 * stackFactor)
	local mouthDrop = headRadius * (0.4 + 0.03 * stackFactor)

	local outlineR = 0
	local outlineG = 0
	local outlineB = 0
	local outlineA = 0.75 + 0.25 * highlight

	local fillAlpha = 0.55 + 0.35 * highlight
	local fillR = 1.0
	local fillG = 0.96 + 0.04 * highlight
	local fillB = 0.88 + 0.08 * highlight

	love.graphics.push("all")

	if palette and palette.blendMode then
		if palette.blendAlphaMode then
			love.graphics.setBlendMode(palette.blendMode, palette.blendAlphaMode)
		else
			love.graphics.setBlendMode(palette.blendMode)
		end
	end
	love.graphics.translate(hx, hy + mouthDrop)

	for side = -1, 1, 2 do
		local baseX = side * spacing
		local topLeftX = baseX - fangWidth * 0.5
		local topRightX = baseX + fangWidth * 0.5
		local tipX = baseX
		local tipY = fangLength

		love.graphics.setColor(fillR, fillG, fillB, fillAlpha)
		love.graphics.polygon("fill", topLeftX, 0, topRightX, 0, tipX, tipY)

		love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
		love.graphics.setLineWidth(1.4)
		love.graphics.polygon("line", topLeftX, 0, topRightX, 0, tipX, tipY)
	end

	love.graphics.pop()
end

local function drawSpeedMotionArcs(trail, SEGMENT_SIZE, data)
	-- Motion streaks intentionally disabled to remove speed lines.
	return
end

local function drawDiffractionBarrierSunglasses(hx, hy, SEGMENT_SIZE, data)
	if not (hx and hy and SEGMENT_SIZE and data) then return end

	local intensity = max(0, min(1, data.intensity or 0))
	local flash = max(0, min(1, data.flash or 0))
	if intensity <= 0.01 and flash <= 0.01 then return end

	local time = data.time or Timer.getTime()
	local baseSize = SEGMENT_SIZE
	local drop = baseSize * 0.08
	local lensWidth = baseSize * (0.5 + 0.1 * intensity)
	local lensHeight = baseSize * (0.24 + 0.04 * intensity)
	local lensRadius = lensHeight * 0.55
	local spacing = baseSize * (0.16 + 0.04 * intensity)
	local frameThickness = max(1.2, baseSize * 0.055)
	local bridgeWidth = spacing * 0.7
	local armLength = baseSize * (0.34 + 0.06 * intensity)
	local armLift = baseSize * (0.22 + 0.05 * intensity)
	local wobble = 0.02 * sin(time * 3.2) * (flash * 0.7 + intensity * 0.2)
	local pulse = 1 + 0.04 * sin(time * 5.4) * (flash * 0.6 + 0.2)

	love.graphics.push("all")
	love.graphics.translate(hx, hy - drop)
	love.graphics.rotate(wobble)
	love.graphics.scale(pulse * (1 + 0.05 * flash), pulse * (1 + 0.02 * flash))

	local lensHalfWidth = lensWidth * 0.5
	local spacingHalf = spacing * 0.5
	local leftCenterX = -(lensHalfWidth + spacingHalf)
	local rightCenterX = lensHalfWidth + spacingHalf
	local top = -lensHeight * 0.5

	local lensAlpha = 0.62 * intensity + 0.32 * flash
	love.graphics.setColor(0.06, 0.08, 0.1, lensAlpha)
	love.graphics.rectangle("fill", leftCenterX - lensHalfWidth, top, lensWidth, lensHeight, lensRadius, lensRadius)
	love.graphics.rectangle("fill", rightCenterX - lensHalfWidth, top, lensWidth, lensHeight, lensRadius, lensRadius)

	love.graphics.setColor(0.02, 0.02, 0.04, lensAlpha * 0.65 + 0.18 * intensity)
	love.graphics.rectangle("fill", leftCenterX - lensHalfWidth, top - lensHeight * 0.2, lensWidth, lensHeight * 0.55, lensRadius, lensRadius)
	love.graphics.rectangle("fill", rightCenterX - lensHalfWidth, top - lensHeight * 0.2, lensWidth, lensHeight * 0.55, lensRadius, lensRadius)

	local frameAlpha = 0.85 * intensity + 0.25 * flash
	love.graphics.setColor(0.01, 0.01, 0.015, frameAlpha)
	love.graphics.setLineWidth(frameThickness)
	love.graphics.rectangle("line", leftCenterX - lensHalfWidth, top, lensWidth, lensHeight, lensRadius, lensRadius)
	love.graphics.rectangle("line", rightCenterX - lensHalfWidth, top, lensWidth, lensHeight, lensRadius, lensRadius)
	love.graphics.rectangle("fill", -bridgeWidth * 0.5, -lensHeight * 0.18, bridgeWidth, lensHeight * 0.36, lensRadius * 0.35, lensRadius * 0.35)

	local leftOuter = leftCenterX - lensHalfWidth
	local rightOuter = rightCenterX + lensHalfWidth
	love.graphics.setLineWidth(frameThickness * 0.85)
	love.graphics.line(leftOuter, -lensHeight * 0.1, leftOuter - armLength, -armLift)
	love.graphics.line(rightOuter, -lensHeight * 0.1, rightOuter + armLength, -armLift)

	local highlight = min(1, flash + intensity * 0.4)
	if highlight > 0.01 then
		love.graphics.setBlendMode("add")
		local highlightAlpha = (0.18 + 0.32 * flash) * (0.6 + 0.4 * intensity)
		love.graphics.setColor(0.82, 0.96, 1.0, highlightAlpha)
		love.graphics.polygon("fill",
			leftCenterX - lensHalfWidth * 0.6, top + lensHeight * 0.2,
			leftCenterX - lensHalfWidth * 0.2, top,
			leftCenterX + lensHalfWidth * 0.2, top + lensHeight * 0.45,
			leftCenterX - lensHalfWidth * 0.15, top + lensHeight * 0.6
		)
		love.graphics.polygon("fill",
			rightCenterX + lensHalfWidth * 0.6, top + lensHeight * 0.2,
			rightCenterX + lensHalfWidth * 0.2, top,
			rightCenterX - lensHalfWidth * 0.2, top + lensHeight * 0.45,
			rightCenterX + lensHalfWidth * 0.15, top + lensHeight * 0.6
		)
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.pop()
end

local function drawZephyrSlipstream(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	if data.hasBody == false then return end

	local stacks = max(1, data.stacks or 1)
	local time = data.time or Timer.getTime()
	local stride = max(1, floor(#trail / (4 + stacks * 2)))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	local steps = 6
	local requiredPoints = (steps + 1) * 2
	zephyrPointCapacity = ensureBufferCapacity(zephyrPoints, zephyrPointCapacity, requiredPoints)

	local segmentVectors = buildSegmentVectors(trail)

	for i = 1, #trail - stride do
		local nextIndex = i + stride
		local x1, y1, x2, y2, dirX, dirY, perpX, perpY, length = resolveSegmentSpan(trail, segmentVectors, i, nextIndex)
		if x1 and y1 and x2 and y2 then
			if not dirX or not dirY or length < 1e-4 then
				dirX, dirY = 0, -1
				perpX, perpY = 1, 0
			elseif not (perpX and perpY) then
				perpX, perpY = -dirY, dirX
			end

			local progress = (i - 1) / max(#trail - stride, 1)
			local sway = sin(time * (4.8 + stacks * 0.4) + i * 0.7) * SEGMENT_SIZE * (0.22 + 0.12 * intensity)
			local crest = sin(time * 2.6 + i) * SEGMENT_SIZE * 0.1
			local ctrlX = (x1 + x2) * 0.5 + perpX * sway
			local ctrlY = (y1 + y2) * 0.5 + perpY * sway

			local points = zephyrPoints
			local pointIndex = 1
			for step = 0, steps do
				local t = step / steps
				local inv = 1 - t
				local bx = inv * inv * x1 + 2 * inv * t * ctrlX + t * t * x2
				local by = inv * inv * y1 + 2 * inv * t * ctrlY + t * t * y2
				local peak = 1 - abs(0.5 - t) * 2
				bx = bx + perpX * crest * peak * 0.8
				by = by + perpY * crest * peak * 0.8
				points[pointIndex] = bx
				points[pointIndex + 1] = by
				pointIndex = pointIndex + 2
			end

			local pointCount = pointIndex - 1
			local sanitizedPointCount = pointCount - (pointCount % 2)
			if sanitizedPointCount ~= pointCount then
				points[sanitizedPointCount + 1] = nil
			end
			pointCount = sanitizedPointCount

			local fade = 1 - progress * 0.7
			if pointCount >= 4 then
				trimBuffer(points, pointCount, zephyrPointCapacity)

				love.graphics.setColor(0.62, 0.88, 1.0, (0.14 + 0.24 * intensity) * fade)
				love.graphics.setLineWidth(1.5 + intensity * 1.2)
				love.graphics.line(points, 1, pointCount)
			end

			love.graphics.setColor(0.92, 0.98, 1.0, (0.08 + 0.18 * intensity) * fade)
			love.graphics.circle("fill", x2, y2, SEGMENT_SIZE * 0.14, 12)
		end
	end

	local ratio = data.ratio
	if not ratio or ratio <= 0 then
		ratio = 1 + 0.2 * min(1, max(0, intensity))
	end

	drawSpeedMotionArcs(trail, SEGMENT_SIZE, {
		intensity = intensity,
		ratio = ratio,
		time = time,
		}
	)

	love.graphics.pop()
end

local function drawEventHorizonSheath(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 1 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local time = data.time or Timer.getTime()
	local spin = data.spin or 0
	local segmentCount = min(#trail, 10)

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, segmentCount do
		local seg = trail[i]
		local px, py = ptXY(seg)
		if px and py then
			local progress = (i - 1) / max(segmentCount - 1, 1)
			local fade = 1 - progress * 0.65
			local radius = SEGMENT_SIZE * (0.7 + 0.28 * intensity + 0.16 * fade)
			local swirl = spin * 1.3 + time * 0.6 + progress * pi * 1.2

			love.graphics.setColor(0.04, 0.08, 0.16, (0.18 + 0.22 * intensity) * fade)
			love.graphics.circle("fill", px, py, radius * 1.05)

			love.graphics.setColor(0.78, 0.88, 1.0, (0.14 + 0.25 * intensity) * fade)
			love.graphics.setLineWidth(SEGMENT_SIZE * (0.08 + 0.05 * intensity) * fade)
			love.graphics.circle("line", px, py, radius)

		end
	end

	local headSeg = trail[1]
	local hx, hy = ptXY(headSeg)
	if hx and hy then
		drawSoftGlow(hx, hy, SEGMENT_SIZE * (2.15 + 0.65 * intensity), 0.7, 0.84, 1.0, 0.18 + 0.24 * intensity)
	end

	love.graphics.pop()
end

local function drawStormchaserCurrent(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local primed = data.primed or false
	local time = data.time or Timer.getTime()
	local stride = max(1, floor(#trail / (6 + intensity * 6)))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	local segments = 3
	local boltPoints = (segments + 2) * 2
	stormBoltCapacity = ensureBufferCapacity(stormBolt, stormBoltCapacity, boltPoints)

	local segmentVectors = buildSegmentVectors(trail)

	local centers = stormBoltCenters
	local centerCount = 0
	local previousCenterCapacity = stormBoltCenterCapacity

	local boltLineWidth = 2.2 + intensity * 1.2
	local boltColorR, boltColorG, boltColorB, boltAlpha = 0.32, 0.68, 1.0, 0.2 + 0.32 * intensity
	local flareColorR, flareColorG, flareColorB, flareAlpha = 0.9, 0.96, 1.0, 0.16 + 0.26 * intensity
	local flareRadius = SEGMENT_SIZE * (0.16 + 0.08 * intensity)

	love.graphics.setColor(boltColorR, boltColorG, boltColorB, boltAlpha)
	love.graphics.setLineWidth(boltLineWidth)

	for i = 1, #trail - stride, stride do
		local nextIndex = i + stride
		local x1, y1, x2, y2, dirX, dirY, perpX, perpY, length = resolveSegmentSpan(trail, segmentVectors, i, nextIndex)
		if x1 and y1 and x2 and y2 then
			if not dirX or not dirY or length < 1e-4 then
				dirX, dirY = 0, 1
				perpX, perpY = -1, 0
				length = 0
			elseif not (perpX and perpY) then
				perpX, perpY = -dirY, dirX
			end

			local bolt = stormBolt
			local boltCount = 2
			bolt[1] = x1
			bolt[2] = y1
			for segIdx = 1, segments do
				local t = segIdx / (segments + 1)
				local offset = sin(time * 8 + i * 0.45 + segIdx * 1.2) * SEGMENT_SIZE * 0.3 * intensity
				local px = x1 + dirX * length * t + perpX * offset
				local py = y1 + dirY * length * t + perpY * offset
				boltCount = boltCount + 2
				bolt[boltCount - 1] = px
				bolt[boltCount] = py
			end
			boltCount = boltCount + 2
			bolt[boltCount - 1] = x2
			bolt[boltCount] = y2

			trimBuffer(bolt, boltCount, stormBoltCapacity)

			love.graphics.line(bolt, 1, boltCount)

			local cx = (x1 + x2) * 0.5
			local cy = (y1 + y2) * 0.5
			centerCount = centerCount + 1
			centers[centerCount] = cx
			centerCount = centerCount + 1
			centers[centerCount] = cy
		end
	end

	for idx = centerCount + 1, previousCenterCapacity do
		centers[idx] = nil
	end
	stormBoltCenterCapacity = centerCount

	if centerCount >= 2 then
		love.graphics.setColor(flareColorR, flareColorG, flareColorB, flareAlpha)
		for idx = 1, centerCount, 2 do
			local cx = centers[idx]
			local cy = centers[idx + 1]
			if cx and cy then
				love.graphics.circle("fill", cx, cy, flareRadius)
			end
		end
	end

	if primed then
		local headSeg = trail[1]
		local hx, hy = ptXY(headSeg)
		if hx and hy then
			love.graphics.setColor(0.38, 0.74, 1.0, 0.24 + 0.34 * intensity)
			love.graphics.setLineWidth(2.4)
			love.graphics.circle("line", hx, hy, SEGMENT_SIZE * (1.4 + 0.32 * intensity))
		end
	end

	love.graphics.pop()
end

local function drawPhoenixEchoTrail(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	local charges = max(0, data.charges or 0)
	local flare = max(0, data.flare or 0)
	local heat = min(1.2, intensity * 0.7 + charges * 0.18 + flare * 0.6)
	if heat <= 0.02 then return end

	local time = data.time or Timer.getTime()

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	local segmentVectors = buildSegmentVectors(trail)

	local wingSegments = min(#trail - 1, 8 + charges * 3)
	for i = 1, wingSegments do
		local nextIndex = i + 1
		local x1, y1, x2, y2, dirX, dirY, perpX, perpY, length = resolveSegmentSpan(trail, segmentVectors, i, nextIndex)
		if x1 and y1 and x2 and y2 then
			if not dirX or not dirY or length < 1e-4 then
				dirX, dirY = 0, 1
				perpX, perpY = -1, 0
			elseif not (perpX and perpY) then
				perpX, perpY = -dirY, dirX
			end
			local progress = (i - 1) / max(1, wingSegments - 1)
			local fade = 1 - progress * 0.6
			local width = SEGMENT_SIZE * (0.32 + 0.14 * heat + 0.06 * charges)
			local lengthScale = SEGMENT_SIZE * (0.7 + 0.25 * heat + 0.1 * charges)
			local flutter = sin(time * 7 + i * 0.55) * width * 0.35
			local baseX = x1 - dirX * SEGMENT_SIZE * 0.25 + perpX * flutter
			local baseY = y1 - dirY * SEGMENT_SIZE * 0.25 + perpY * flutter
			local tipX = baseX + dirX * lengthScale
			local tipY = baseY + dirY * lengthScale
			local leftX = baseX + perpX * width
			local leftY = baseY + perpY * width
			local rightX = baseX - perpX * width
			local rightY = baseY - perpY * width

			love.graphics.setColor(1.0, 0.58, 0.22, (0.18 + 0.3 * heat) * fade)
			love.graphics.polygon("fill", leftX, leftY, tipX, tipY, rightX, rightY)
			love.graphics.setColor(1.0, 0.82, 0.32, (0.12 + 0.22 * heat) * fade)
			love.graphics.polygon("line", leftX, leftY, tipX, tipY, rightX, rightY)
			love.graphics.setColor(1.0, 0.42, 0.12, (0.16 + 0.28 * heat) * fade)
			love.graphics.circle("fill", tipX, tipY, SEGMENT_SIZE * (0.15 + 0.08 * heat))
		end
	end

	local emberCount = min(32, (#trail - 2) * 2 + charges * 4)
	for i = 1, emberCount do
		local progress = (i - 0.5) / emberCount
		local idxFloat = 1 + progress * max(#trail - 2, 1)
		local index = floor(idxFloat)
		local frac = idxFloat - index
		local nextIndex = min(#trail, index + 1)
		local x1, y1, x2, y2, dirX, dirY, perpX, perpY, length = resolveSegmentSpan(trail, segmentVectors, index, nextIndex)
		if x1 and y1 and x2 and y2 then
			if not dirX or not dirY or length < 1e-4 then
				dirX, dirY = 0, 1
				perpX, perpY = -1, 0
			elseif not (perpX and perpY) then
				perpX, perpY = -dirY, dirX
			end
			local x = x1 + (x2 - x1) * frac
			local y = y1 + (y2 - y1) * frac
			local sway = sin(time * 5.2 + i) * SEGMENT_SIZE * 0.22 * heat
			local lift = cos(time * 3.4 + i * 0.8) * SEGMENT_SIZE * 0.28
			local fx = x + perpX * sway + dirX * lift * 0.25
			local fy = y + perpY * sway + dirY * lift
			local fade = 0.5 + 0.5 * (1 - progress)

			love.graphics.setColor(1.0, 0.5, 0.16, (0.12 + 0.2 * heat) * fade)
			love.graphics.circle("fill", fx, fy, SEGMENT_SIZE * (0.1 + 0.05 * heat * fade))
			love.graphics.setColor(1.0, 0.86, 0.42, (0.08 + 0.16 * heat) * fade)
			love.graphics.circle("line", fx, fy, SEGMENT_SIZE * (0.14 + 0.06 * heat))
		end
	end

	local headSeg = trail[1]
	local hx, hy = ptXY(headSeg)
	if hx and hy then
		drawSoftGlow(hx, hy, SEGMENT_SIZE * (1.35 + 0.35 * (charges + heat)), 1.0, 0.62, 0.26, 0.3 + 0.35 * heat)
	end

	love.graphics.pop()
end

local function drawChronoWardPulse(hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local intensity = max(data.intensity or 0, data.active and 0.3 or 0)
	if intensity <= 0 then return end

	local now = Timer.getTime()
	local baseRadius = SEGMENT_SIZE * (1.05 + 0.35 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.45, 0.58, 0.86, 1.0, 0.18 + 0.28 * intensity)

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, 3 do
		local phase = (now * 1.6 + i * 0.42) % 1
		local radius = baseRadius * (1.0 + phase * 0.7)
		local alpha = (0.16 + 0.32 * intensity) * (1 - phase)
		if alpha > 0 then
			love.graphics.setColor(0.62, 0.9, 1.0, alpha)
			love.graphics.circle("line", hx, hy, radius)
		end
	end

	love.graphics.setColor(0.84, 0.96, 1.0, 0.12 + 0.2 * intensity)
	love.graphics.circle("fill", hx, hy, baseRadius * 0.45)

	love.graphics.pop()
end

local function drawTimeDilationAura(hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local cooldownTimer = max(0, data.cooldownTimer or 0)

	local readiness
	if cooldown > 0 then
		readiness = 1 - min(1, cooldownTimer / max(0.0001, cooldown))
	else
		readiness = data.active and 1 or 0.6
	end

	local intensity = readiness * 0.35
	if data.active then
		intensity = max(intensity, 0.45) + 0.45 * min(1, timer / duration)
	end

	if intensity <= 0 then return end

	local time = Timer.getTime()

	local baseRadius = SEGMENT_SIZE * (0.95 + 0.35 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.55, 0.45, 0.9, 1, 0.3 + 0.45 * intensity)

	love.graphics.push("all")

	love.graphics.setBlendMode("add")
	for i = 1, 3 do
		local ringT = (i - 1) / 2
		local wobble = sin(time * (1.6 + ringT * 0.8)) * SEGMENT_SIZE * 0.06
		love.graphics.setColor(0.32, 0.74, 1, (0.15 + 0.25 * intensity) * (1 - ringT * 0.35))
		love.graphics.setLineWidth(1.6 + (3 - i) * 0.9)
		love.graphics.circle("line", hx, hy, baseRadius * (1.05 + ringT * 0.25) + wobble)
	end

	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(0.4, 0.8, 1, 0.25 + 0.4 * intensity)
	love.graphics.setLineWidth(2)
	local wobble = 1 + 0.08 * sin(time * 2.2)
	love.graphics.circle("line", hx, hy, baseRadius * wobble)

	local dialRotation = time * (data.active and 1.8 or 0.9)
	love.graphics.setColor(0.26, 0.62, 0.95, 0.2 + 0.25 * intensity)
	love.graphics.setLineWidth(2.4)
	for i = 1, 3 do
		local offset = dialRotation + (i - 1) * (pi * 2 / 3)
		love.graphics.arc("line", "open", hx, hy, baseRadius * 0.75, offset, offset + pi / 4)
	end

	local tickCount = 6
	local spin = time * (data.active and -1.2 or -0.6)
	love.graphics.setColor(0.6, 0.95, 1, 0.2 + 0.35 * intensity)
	for i = 1, tickCount do
		local angle = spin + (i / tickCount) * pi * 2
		local inner = baseRadius * 0.55
		local outer = baseRadius * (1.25 + 0.1 * sin(time * 3 + i))
		love.graphics.line(
			hx + cos(angle) * inner,
			hy + sin(angle) * inner,
			hx + cos(angle) * outer,
			hy + sin(angle) * outer
		)
	end

	love.graphics.pop()
end

local function drawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, data)
	if not (data and hx and hy) then return end

	local intensity = max(0, data.intensity or 0)
	local readiness = max(0, min(1, data.ready or 0))
	if intensity <= 0.01 and readiness <= 0.01 then return end

	local time = data.time or Timer.getTime()
	local sizeScale = 0.82
	local baseRadius = SEGMENT_SIZE * sizeScale * (1.05 + 0.28 * readiness + 0.22 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.2, 0.52, 0.78, 1.0, 0.18 + 0.28 * (intensity + readiness * 0.5))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	love.graphics.setColor(0.46, 0.8, 1.0, 0.18 + 0.32 * (intensity + readiness * 0.6))
	love.graphics.setLineWidth((2 + 1.2 * intensity) * sizeScale)
	love.graphics.circle("line", hx, hy, baseRadius)

	local orbitCount = 4
	for i = 1, orbitCount do
		local angle = time * (1.0 + 0.4 * intensity) + (i - 1) * (pi * 2 / orbitCount)
		local inner = baseRadius * 0.58
		local outer = baseRadius * (0.92 + 0.18 * readiness)
		love.graphics.setColor(0.68, 0.9, 1.0, (0.16 + 0.26 * readiness) * (0.6 + 0.4 * intensity))
		love.graphics.setLineWidth(2.4 * sizeScale)
		love.graphics.line(
			hx + cos(angle) * inner,
			hy + sin(angle) * inner,
			hx + cos(angle) * outer,
			hy + sin(angle) * outer
		)
	end

	local sweep = pi * 0.35
	local rotation = time * (1.4 + 0.6 * readiness)
	love.graphics.setColor(0.38, 0.7, 1.0, 0.16 + 0.28 * intensity)
	love.graphics.setLineWidth(1.8 * sizeScale)
	love.graphics.arc("line", "open", hx, hy, baseRadius * 0.78, rotation, rotation + sweep)
	love.graphics.arc("line", "open", hx, hy, baseRadius * 0.78, rotation + pi, rotation + pi + sweep * 0.85)

	love.graphics.setBlendMode("alpha")

	local triangleHeight = baseRadius * (0.5 + 0.25 * readiness)
	local triangleWidth = baseRadius * 0.38
	local topBaseY = hy - triangleHeight
	local bottomBaseY = hy + triangleHeight

	love.graphics.setColor(0.72, 0.88, 1.0, 0.18 + 0.28 * (intensity + readiness * 0.5))
	love.graphics.setLineWidth(2.2 * sizeScale)
	love.graphics.polygon("line",
		hx, hy,
		hx - triangleWidth, topBaseY,
		hx + triangleWidth, topBaseY
	)
	love.graphics.polygon("line",
		hx, hy,
		hx - triangleWidth, bottomBaseY,
		hx + triangleWidth, bottomBaseY
	)

	local inset = triangleHeight * 0.12
	love.graphics.setColor(0.52, 0.78, 1.0, 0.12 + 0.22 * (intensity + readiness * 0.6))
	love.graphics.polygon("fill",
		hx, hy,
		hx - triangleWidth * 0.75, topBaseY + inset,
		hx + triangleWidth * 0.75, topBaseY + inset
	)
	love.graphics.polygon("fill",
		hx, hy,
		hx - triangleWidth * 0.75, bottomBaseY - inset,
		hx + triangleWidth * 0.75, bottomBaseY - inset
	)

	love.graphics.pop()
end

local function drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, data)
	if not data or not data.active then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end
	local timer = data.timer or 0
	if timer < 0 then timer = 0 end
	local intensity = min(1, timer / duration)

	local time = Timer.getTime()

	local pulse = 0.9 + 0.1 * sin(time * 6)
	local radius = SEGMENT_SIZE * (0.6 + 0.35 * intensity) * pulse

	drawSoftGlow(hx, hy, radius * 1.4, 1, 0.68 + 0.2 * intensity, 0.25, 0.4 + 0.5 * intensity)

	love.graphics.setColor(1, 0.6 + 0.25 * intensity, 0.2, 0.35 + 0.4 * intensity)
	love.graphics.circle("fill", hx, hy, radius)

	love.graphics.setColor(1, 0.52 + 0.3 * intensity, 0.18, 0.2 + 0.25 * intensity)
	love.graphics.circle("line", hx, hy, radius * 1.1)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function drawDashStreaks(trail, SEGMENT_SIZE, data)
	-- Dash streaks intentionally disabled to remove motion lines.
	return
end

local function drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local cooldownTimer = max(0, data.cooldownTimer or 0)

	local readiness
	if data.active then
		readiness = min(1, timer / duration)
	elseif cooldown > 0 then
		readiness = 1 - min(1, cooldownTimer / max(0.0001, cooldown))
	else
		readiness = 1
	end

	readiness = max(0, min(1, readiness))
	local intensity = readiness
	if data.active then
		intensity = max(intensity, 0.75)
	end

	if intensity <= 0 then return end

	local time = Timer.getTime()

	local baseRadius = SEGMENT_SIZE * (0.85 + 0.3 * intensity)
	drawSoftGlow(hx, hy, baseRadius * (1.35 + 0.25 * intensity), 1, 0.78, 0.32, 0.25 + 0.35 * intensity)

	local dirX, dirY = 0, -1
	local head = trail and trail[1]
	if head and (head.dirX or head.dirY) then
		dirX = head.dirX or dirX
		dirY = head.dirY or dirY
	end

	local segmentVectors = buildSegmentVectors(trail)
	local nextIndex = trail and #trail >= 2 and 2 or 1
	local length
	if head and nextIndex and nextIndex > 0 then
		local hx1, hy1, hx2, hy2, cachedDirX, cachedDirY, _, _, segLen = resolveSegmentSpan(trail, segmentVectors, 1, nextIndex)
		if hx1 and hy1 and hx2 and hy2 then
			if cachedDirX and cachedDirY and segLen and segLen > 1e-4 then
				dirX, dirY = cachedDirX, cachedDirY
				length = segLen
			else
				local dx, dy = hx2 - hx1, hy2 - hy1
				if dx ~= 0 or dy ~= 0 then
					local len = sqrt(dx * dx + dy * dy)
					if len > 1e-4 then
						dirX, dirY = dx / len, dy / len
						length = len
					end
				end
			end
		end
	end

	if not length then
		local norm = sqrt(dirX * dirX + dirY * dirY)
		if norm > 1e-4 then
			dirX, dirY = dirX / norm, dirY / norm
		end
	end

	local angle
	if atan2 then
		angle = atan2(dirY, dirX)
	else
		angle = atan(dirY, dirX)
	end

	love.graphics.push("all")
	love.graphics.translate(hx, hy)
	love.graphics.rotate(angle)

	love.graphics.setColor(1, 0.78, 0.26, 0.3 + 0.4 * intensity)
	love.graphics.setLineWidth(2 + intensity * 2)
	love.graphics.arc("line", "open", 0, 0, baseRadius, -pi * 0.65, pi * 0.65)

	love.graphics.setBlendMode("add")
	local flareRadius = baseRadius * (1.18 + 0.08 * sin(time * 5))
	love.graphics.setColor(1, 0.86, 0.42, 0.22 + 0.35 * intensity)
	love.graphics.arc("fill", 0, 0, flareRadius, -pi * 0.28, pi * 0.28)

	if not data.active then
		local sweep = readiness * pi * 2
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 0.62, 0.18, 0.35 + 0.4 * intensity)
		love.graphics.setLineWidth(3)
		love.graphics.arc("line", "open", 0, 0, baseRadius * 0.85, -pi / 2, -pi / 2 + sweep)
	else
		local pulse = 0.75 + 0.25 * sin(time * 10)
		love.graphics.setColor(1, 0.95, 0.55, 0.5)
		love.graphics.polygon("fill",
			baseRadius * 0.75, 0,
			baseRadius * (1.35 + 0.15 * pulse), -SEGMENT_SIZE * 0.34 * pulse,
			baseRadius * (1.35 + 0.15 * pulse), SEGMENT_SIZE * 0.34 * pulse
		)
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.setColor(1, 0.68, 0.2, 0.22 + 0.4 * intensity)
	local sparks = 6
	love.graphics.setLineWidth(1.25)
	for i = 1, sparks do
		local offset = time * (data.active and 7 or 3.5) + (i / sparks) * pi * 2
		local inner = baseRadius * 0.5
		local outer = baseRadius * (1.1 + 0.1 * sin(time * 4 + i))
		love.graphics.line(cos(offset) * inner, sin(offset) * inner, cos(offset) * outer, sin(offset) * outer)
	end

	love.graphics.pop()
end

function SnakeDraw.run(trail, segmentCount, SEGMENT_SIZE, popTimer, getHead, shieldCount, shieldFlashTimer, upgradeVisuals, drawFace)
	currentCoordsFrame = currentCoordsFrame + 1

	-- upgradeVisuals must be treated as read-only; the table is reused each frame by Snake.collectUpgradeVisuals.
	local options
	if type(drawFace) == "table" then
		options = drawFace
		drawFace = options.drawFace
	end

	if drawFace == nil then
		drawFace = true
	end

	if not trail or #trail == 0 then return end

	local thickness = SEGMENT_SIZE * 0.8
	local half      = thickness / 2

	local palette
	if options then
		if options.paletteOverride then
			palette = options.paletteOverride
		elseif options.skinOverride then
			palette = SnakeCosmetics:getPaletteForSkin(options.skinOverride)
		end
	end
	local head = trail[1]

	love.graphics.setLineStyle("smooth")
	love.graphics.setLineJoin("bevel") -- or "bevel" if you prefer fewer spikes

	local hx, hy
	if getHead then
		hx, hy = getHead()
	end
	if not (hx and hy) then
		hx, hy = ptXY(head)
	end

	local faceAtBottom = options and options.faceAtBottom
	if faceAtBottom then
		local bottomX, bottomY = hx, hy
		if trail then
			for i = 1, segmentCount do
				local point = trail[i]
				if point then
					local px, py = ptXY(point)
					if px and py then
						if not bottomY or py > bottomY then
							bottomX, bottomY = px, py
						end
					end
				end
			end
		end

		if bottomX and bottomY then
			hx, hy = bottomX, bottomY
		end
	end

	local portalInfo = options and options.portalAnimation
	if portalInfo then
		local exitTrail = portalInfo.exitTrail
		if not (exitTrail and #exitTrail > 0) then
			exitTrail = trail
		end

		local entryTrail = portalInfo.entryTrail
		local entryHole = portalInfo.entryHole
		local exitHole = portalInfo.exitHole
		local exitHead = exitTrail and exitTrail[1]
		if exitHead then
			local ex = exitHead.drawX or exitHead.x
			local ey = exitHead.drawY or exitHead.y
			if ex and ey then
				hx, hy = ex, ey
			end
		else
			hx = portalInfo.exitX or hx
			hy = portalInfo.exitY or hy
		end

		local exitCoords = buildCoords(exitTrail)

		local entryCoords
		if entryTrail and #entryTrail > 0 then
			entryCoords = buildCoords(entryTrail)
		end

		local entryPalette
		if entryTrail and #entryTrail > 0 then
			entryPalette = fadePalette(palette, 0.55)
		end

		RenderLayers:withLayer("main", function()
			love.graphics.push("all"
		)

			love.graphics.translate(SHADOW_OFFSET, SHADOW_OFFSET
		)
			if exitTrail and #exitTrail > 0 then
			drawTrailSegmentToCanvas(exitTrail, half, options, shadowPalette, exitCoords
		)
			end
			if entryTrail and #entryTrail > 0 then
			drawTrailSegmentToCanvas(entryTrail, half, options, shadowPalette, entryCoords
		)
			end

			love.graphics.origin(
		)
			if exitTrail and #exitTrail > 0 then
			drawTrailSegmentToCanvas(exitTrail, half, options, palette, exitCoords
		)
			end
			if entryTrail and #entryTrail > 0 and entryPalette then
			drawTrailSegmentToCanvas(entryTrail, half, options, entryPalette, entryCoords
		)
			end

			love.graphics.pop(
		)
			end
		)

		if exitHole then
			drawPortalHole(exitHole, true)
		end

		if entryHole then
			drawPortalHole(entryHole, false)
		end

		local entryX = (entryHole and entryHole.x) or portalInfo.entryX
		local entryY = (entryHole and entryHole.y) or portalInfo.entryY
		if not entryX or not entryY then
			local entryHead = entryTrail and entryTrail[1]
			if entryHead then
				entryX = entryHead.drawX or entryHead.x or entryX
				entryY = entryHead.drawY or entryHead.y or entryY
			end
		end

		local exitX = (exitHole and exitHole.x) or portalInfo.exitX or hx
		local exitY = (exitHole and exitHole.y) or portalInfo.exitY or hy
		local progress = portalInfo.progress or 0
		local clampedProgress = min(1, max(0, progress))

		if entryX and entryY then
			local entryAlpha
			local entryRadius
			if entryHole then
				entryRadius = (entryHole.radius or (SEGMENT_SIZE * 0.7)) * 1.35
				entryAlpha = (0.5 + 0.35 * (entryHole.open or 0)) * (entryHole.visibility or 0)
			else
				entryRadius = SEGMENT_SIZE * 1.3
				entryAlpha = 0.75 * (1 - clampedProgress * 0.7)
			end
			if entryAlpha and entryAlpha > 1e-3 then
				drawSoftGlow(entryX, entryY, entryRadius, 0.45, 0.78, 1.0, entryAlpha)
			end
		end

		if exitX and exitY then
			local exitAlpha
			local exitRadius
			if exitHole then
				exitRadius = (exitHole.radius or (SEGMENT_SIZE * 0.75)) * 1.45
				exitAlpha = (0.35 + 0.5 * (exitHole.open or 0)) * (exitHole.visibility or 0)
			else
				exitRadius = SEGMENT_SIZE * 1.4
				exitAlpha = 0.55 + 0.45 * clampedProgress
			end
			if exitAlpha and exitAlpha > 1e-3 then
				drawSoftGlow(exitX, exitY, exitRadius, 1.0, 0.88, 0.4, exitAlpha)
			end
		end
	else
		local coords = buildCoords(trail)

		RenderLayers:withLayer("main", function()
			love.graphics.push("all"
		)

			love.graphics.translate(SHADOW_OFFSET, SHADOW_OFFSET
		)
			drawTrailSegmentToCanvas(trail, half, options, shadowPalette, coords
		)

			love.graphics.origin(
		)
			drawTrailSegmentToCanvas(trail, half, options, palette, coords
		)

			love.graphics.pop(
		)
			end
		)
	end

	local shouldDrawOverlay = (hx and hy and drawFace ~= false) or (popTimer and popTimer > 0 and hx and hy)
	if shouldDrawOverlay then
		RenderLayers:withLayer("overlay", function()
			if hx and hy and drawFace ~= false then
			if upgradeVisuals and upgradeVisuals.temporalAnchor then
			drawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, upgradeVisuals.temporalAnchor
		)
			end

			if upgradeVisuals and upgradeVisuals.chronoWard then
			drawChronoWardPulse(hx, hy, SEGMENT_SIZE, upgradeVisuals.chronoWard
		)
			end

			if upgradeVisuals and upgradeVisuals.timeDilation then
			drawTimeDilationAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.timeDilation
		)
			end

			if upgradeVisuals and upgradeVisuals.adrenaline then
			drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.adrenaline
		)
			end

                        if upgradeVisuals and upgradeVisuals.swiftFangs then
                        drawswiftFangsAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.swiftFangs
                )
                        end

                        if upgradeVisuals and upgradeVisuals.momentumCoils then
                        drawMomentumCoilsAura(trail, SEGMENT_SIZE, upgradeVisuals.momentumCoils
                )
                        end

                        if upgradeVisuals and upgradeVisuals.zephyrCoils then
                        drawZephyrSlipstream(trail, SEGMENT_SIZE, upgradeVisuals.zephyrCoils
                )
                        end

			if upgradeVisuals and upgradeVisuals.dash then
			drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.dash
		)
			end

			if upgradeVisuals and upgradeVisuals.speedArcs then
			drawSpeedMotionArcs(trail, SEGMENT_SIZE, upgradeVisuals.speedArcs
		)
			end

			local faceScale = 1
			local faceOptions = upgradeVisuals and upgradeVisuals.face or nil
			Face:draw(hx, hy, faceScale, faceOptions
		)

			if upgradeVisuals and upgradeVisuals.diffractionBarrier then
			drawDiffractionBarrierSunglasses(hx, hy, SEGMENT_SIZE, upgradeVisuals.diffractionBarrier
		)
			end

			drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer
		)

			if upgradeVisuals and upgradeVisuals.dash then
			drawDashStreaks(trail, SEGMENT_SIZE, upgradeVisuals.dash
		)
			end

			if upgradeVisuals and upgradeVisuals.eventHorizon then
			drawEventHorizonSheath(trail, SEGMENT_SIZE, upgradeVisuals.eventHorizon
		)
			end

			if upgradeVisuals and upgradeVisuals.stormchaser then
			drawStormchaserCurrent(trail, SEGMENT_SIZE, upgradeVisuals.stormchaser
		)
			end


			if upgradeVisuals and upgradeVisuals.phoenixEcho then
			drawPhoenixEchoTrail(trail, SEGMENT_SIZE, upgradeVisuals.phoenixEcho
		)
			end
			end

			if popTimer and popTimer > 0 and hx and hy then
			local t = 1 - (popTimer / POP_DURATION
		)
			if t < 1 then
			local pulse = 0.8 + 0.4 * sin(t * pi
		)
			love.graphics.setColor(1, 1, 1, 0.4
		)
			love.graphics.circle("fill", hx, hy, thickness * 0.6 * pulse
		)
			end
			end
			end
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function SnakeDraw.setGlowSpriteResolution(resolution)
	if not resolution then return end

	local target = max(8, floor(resolution))
	if target ~= glowSpriteResolution then
		glowSpriteResolution = target
		glowSprite = nil
	end
end

return SnakeDraw
