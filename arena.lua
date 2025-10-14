local Theme = require("theme")
local Audio = require("audio")
local Shaders = require("shaders")

local EXIT_SAFE_ATTEMPTS = 180
local MIN_HEAD_DISTANCE_TILES = 2

local ABS_MIN_COLS = 23
local ABS_MAX_COLS = 33
local ABS_MIN_ROWS = 19
local ABS_MAX_ROWS = 25
local DEFAULT_MIN_AREA = 25 * 19

local DEFAULT_LAYOUT_GUIDELINES = {
        minCols = 25,
        maxCols = ABS_MAX_COLS,
        minRows = 19,
        maxRows = ABS_MAX_ROWS,
        minArea = DEFAULT_MIN_AREA,
}


local function getModule(name)
	local loaded = package.loaded[name]
	if loaded ~= nil then
		if loaded == true then
			return nil
		end
		return loaded
	end

	local ok, result = pcall(require, name)
	if ok then
		return result
	end

	return nil
end

local function distanceSquared(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return dx * dx + dy * dy
end

local function clampIndex(value, minIndex, maxIndex)
        if value < minIndex then
                return minIndex
        elseif value > maxIndex then
                return maxIndex
        end
        return value
end

local function toOddIndexRange(minValue, maxValue, absMin, absMax)
        local lower = math.max(absMin or 1, math.floor(minValue or absMin or 1))
        local upper = math.min(absMax or lower, math.floor(maxValue or absMax or lower))

        if lower > upper then
                lower, upper = upper, lower
        end

        local minIndex = math.ceil((lower - 1) / 2)
        local maxIndex = math.floor((upper - 1) / 2)

        if minIndex > maxIndex then
                minIndex = math.ceil((absMin - 1) / 2)
                maxIndex = math.floor((absMax - 1) / 2)
        end

        if minIndex > maxIndex then
                minIndex = maxIndex
        end

        return minIndex, maxIndex
end

local function indexToOdd(index)
        return index * 2 + 1
end

local function requiredOddIndexForValue(value)
        value = math.max(1, value or 1)
        return math.ceil((value - 1) / 2)
end

local function resolveLayoutGuidelines(floorNum, floorData)
        local overrides = (type(floorData) == "table" and floorData.arenaLayout) or nil
        local guidelines = {
                minCols = DEFAULT_LAYOUT_GUIDELINES.minCols,
                maxCols = DEFAULT_LAYOUT_GUIDELINES.maxCols,
                minRows = DEFAULT_LAYOUT_GUIDELINES.minRows,
                maxRows = DEFAULT_LAYOUT_GUIDELINES.maxRows,
                minArea = DEFAULT_LAYOUT_GUIDELINES.minArea,
        }

        if type(overrides) == "table" then
                if overrides.minCols ~= nil then
                        guidelines.minCols = overrides.minCols
                end
                if overrides.maxCols ~= nil then
                        guidelines.maxCols = overrides.maxCols
                end
                if overrides.minRows ~= nil then
                        guidelines.minRows = overrides.minRows
                end
                if overrides.maxRows ~= nil then
                        guidelines.maxRows = overrides.maxRows
                end
                if overrides.minArea ~= nil then
                        guidelines.minArea = overrides.minArea
                end
        end

        local floorIndex = math.max(1, math.floor(floorNum or 1))
        local depth = math.max(0, floorIndex - 1)
        if depth > 0 then
                local shrinkCols = math.min(4, math.floor(depth / 4))
                local shrinkRows = math.min(3, math.floor(depth / 5))

                if shrinkCols > 0 then
                        local newMinCols = math.max(ABS_MIN_COLS, math.floor(guidelines.minCols - shrinkCols))
                        local newMaxCols = math.max(newMinCols, math.floor(guidelines.maxCols - math.floor(shrinkCols / 2)))
                        guidelines.minCols = newMinCols
                        guidelines.maxCols = newMaxCols
                end

                if shrinkRows > 0 then
                        local newMinRows = math.max(ABS_MIN_ROWS, math.floor(guidelines.minRows - shrinkRows))
                        local newMaxRows = math.max(newMinRows, math.floor(guidelines.maxRows - math.floor(shrinkRows / 2)))
                        guidelines.minRows = newMinRows
                        guidelines.maxRows = newMaxRows
                end
        end

        local colMinIndex, colMaxIndex = toOddIndexRange(guidelines.minCols, guidelines.maxCols, ABS_MIN_COLS, ABS_MAX_COLS)
        local rowMinIndex, rowMaxIndex = toOddIndexRange(guidelines.minRows, guidelines.maxRows, ABS_MIN_ROWS, ABS_MAX_ROWS)

        guidelines.minCols = indexToOdd(colMinIndex)
        guidelines.maxCols = indexToOdd(colMaxIndex)
        guidelines.minRows = indexToOdd(rowMinIndex)
        guidelines.maxRows = indexToOdd(rowMaxIndex)

        local desiredMinArea = math.floor(guidelines.minArea or DEFAULT_MIN_AREA)
        desiredMinArea = math.max(DEFAULT_MIN_AREA, desiredMinArea)
        local minimumPossibleArea = guidelines.minCols * guidelines.minRows
        local maximumPossibleArea = guidelines.maxCols * guidelines.maxRows

        desiredMinArea = math.max(desiredMinArea, minimumPossibleArea)
        if desiredMinArea > maximumPossibleArea then
                desiredMinArea = maximumPossibleArea
        end

        guidelines.minArea = desiredMinArea
        guidelines._colMinIndex = colMinIndex
        guidelines._colMaxIndex = colMaxIndex
        guidelines._rowMinIndex = rowMinIndex
        guidelines._rowMaxIndex = rowMaxIndex

        return guidelines
end

local function generateLayoutFromGuidelines(guidelines)
        if not guidelines then
                return nil
        end

        local colMinIndex = guidelines._colMinIndex or math.ceil((ABS_MIN_COLS - 1) / 2)
        local colMaxIndex = guidelines._colMaxIndex or math.floor((ABS_MAX_COLS - 1) / 2)
        local rowMinIndex = guidelines._rowMinIndex or math.ceil((ABS_MIN_ROWS - 1) / 2)
        local rowMaxIndex = guidelines._rowMaxIndex or math.floor((ABS_MAX_ROWS - 1) / 2)

        if colMinIndex > colMaxIndex then
                colMinIndex, colMaxIndex = colMaxIndex, colMinIndex
        end
        if rowMinIndex > rowMaxIndex then
                rowMinIndex, rowMaxIndex = rowMaxIndex, rowMinIndex
        end

        local random = (love and love.math and love.math.random) or math.random

        local colIndex = random(colMinIndex, colMaxIndex)
        local rowIndex = random(rowMinIndex, rowMaxIndex)
        local cols = indexToOdd(colIndex)
        local rows = indexToOdd(rowIndex)
        local minArea = guidelines.minArea or DEFAULT_MIN_AREA

        if cols * rows < minArea then
                local requiredColsIndex = requiredOddIndexForValue(math.ceil(minArea / rows))
                colIndex = clampIndex(requiredColsIndex, colMinIndex, colMaxIndex)
                cols = indexToOdd(colIndex)
        end

        if cols * rows < minArea then
                local requiredRowsIndex = requiredOddIndexForValue(math.ceil(minArea / cols))
                rowIndex = clampIndex(requiredRowsIndex, rowMinIndex, rowMaxIndex)
                rows = indexToOdd(rowIndex)
        end

        if cols * rows < minArea then
                colIndex = colMaxIndex
                rowIndex = rowMaxIndex
                cols = indexToOdd(colIndex)
                rows = indexToOdd(rowIndex)
        end

        return {
                cols = cols,
                rows = rows,
                colIndex = colIndex,
                rowIndex = rowIndex,
                minCols = indexToOdd(colMinIndex),
                maxCols = indexToOdd(colMaxIndex),
                minRows = indexToOdd(rowMinIndex),
                maxRows = indexToOdd(rowMaxIndex),
                minArea = minArea,
                guidelines = guidelines,
        }
end

local function getHighlightColor(color)
        color = color or {1, 1, 1, 1}

        local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75

	return {r, g, b, a}
end

local function normalizeCellCoordinate(value)
	if value == nil then
		return nil
	end

	return math.floor(value + 0.5)
end

local function drawSpawnDebugOverlay(self)
	local debugData = self._spawnDebugData
	if not debugData then
		return
	end

	local Snake = getModule("snake")
	if not (Snake and Snake.isDeveloperAssistEnabled and Snake:isDeveloperAssistEnabled()) then
		return
	end

	local function drawCells(cells, fillColor, outlineColor)
		if not (cells and #cells > 0) then
			return
		end

		local tileSize = self.tileSize or 24
		local radius = math.min(8, tileSize * 0.35)

		if fillColor then
			love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.22)
			for _, cell in ipairs(cells) do
				local col = normalizeCellCoordinate(cell[1])
				local row = normalizeCellCoordinate(cell[2])
				if col and row and col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
					local x, y = self:getTilePosition(col, row)
					love.graphics.rectangle("fill", x, y, tileSize, tileSize, radius, radius)
				end
			end
		end

		if outlineColor then
			love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 0.4)
			for _, cell in ipairs(cells) do
				local col = normalizeCellCoordinate(cell[1])
				local row = normalizeCellCoordinate(cell[2])
				if col and row and col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
					local x, y = self:getTilePosition(col, row)
					love.graphics.rectangle("line", x + 1, y + 1, tileSize - 2, tileSize - 2, radius, radius)
				end
			end
		end
	end

	love.graphics.push("all")
	love.graphics.setLineWidth(1.25)
	love.graphics.setBlendMode("alpha")

	drawCells(debugData.spawnSafeCells, {0.95, 0.34, 0.32, 0.24})
	drawCells(debugData.spawnBuffer, {1.0, 0.64, 0.26, 0.28})
	drawCells(debugData.safeZone, {0.22, 0.68, 1.0, 0.35}, {0.92, 0.98, 1.0, 0.75})
	drawCells(debugData.rockSafeZone, {0.64, 0.36, 0.88, 0.2})
	drawCells(debugData.reservedCells, nil, {1.0, 1.0, 1.0, 0.35})
	drawCells(debugData.reservedSpawnBuffer, nil, {1.0, 0.86, 0.38, 0.45})

	love.graphics.pop()
end

local function mixChannel(base, target, amount)
	return base + (target - base) * amount
end

local function isTileInSafeZone(safeZone, col, row)
	if not safeZone then return false end

	for _, cell in ipairs(safeZone) do
		if cell[1] == col and cell[2] == row then
			return true
		end
	end

	return false
end

local Arena = {
        x = 0, y = 0,
        width = 792,
        height = 600,
        tileSize = 24,
        cols = math.floor(792 / 24),
        rows = math.floor(600 / 24),
        screenWidth = nil,
        screenHeight = nil,
        _layout = nil,
        _layoutFloor = nil,
                exit = nil,
                activeBackgroundEffect = nil,
        borderFlare = 0,
        borderFlareStrength = 0,
        borderFlareTimer = 0,
	borderFlareDuration = 1.05,
}

function Arena:setSpawnDebugData(data)
	if not data then
		self._spawnDebugData = nil
		return
	end

	self._spawnDebugData = {
		safeZone = data.safeZone,
		rockSafeZone = data.rockSafeZone,
		spawnBuffer = data.spawnBuffer,
		spawnSafeCells = data.spawnSafeCells,
		reservedCells = data.reservedCells,
		reservedSafeZone = data.reservedSafeZone,
		reservedSpawnBuffer = data.reservedSpawnBuffer,
	}
end

function Arena:clearSpawnDebugData()
	self._spawnDebugData = nil
end

function Arena:updateScreenBounds(sw, sh)
        if sw == nil or sh == nil then
                if love and love.graphics and love.graphics.getDimensions then
                        sw, sh = love.graphics.getDimensions()
                else
                        sw, sh = self.screenWidth or 0, self.screenHeight or 0
                end
        end

        self.screenWidth = sw
        self.screenHeight = sh

        self.x = math.floor((sw - self.width) / 2)
        self.y = math.floor((sh - self.height) / 2)

        -- snap x,y to nearest tile boundary so centers align
        self.x = self.x - (self.x % self.tileSize)
        self.y = self.y - (self.y % self.tileSize)

        self.cols = math.max(1, math.floor(self.width / self.tileSize))
        self.rows = math.max(1, math.floor(self.height / self.tileSize))

        if self._layout then
                self.cols = self._layout.cols or self.cols
                self.rows = self._layout.rows or self.rows
        end
end

function Arena:getTilePosition(col, row)
	return self.x + (col - 1) * self.tileSize,
			self.y + (row - 1) * self.tileSize
end

function Arena:getCenterOfTile(col, row)
	local x, y = self:getTilePosition(col, row)
	return x + self.tileSize / 2, y + self.tileSize / 2
end

function Arena:getTileFromWorld(x, y)
        local col = math.floor((x - self.x) / self.tileSize) + 1
        local row = math.floor((y - self.y) / self.tileSize) + 1

        -- clamp inside arena grid
        col = math.max(1, math.min(self.cols, col))
        row = math.max(1, math.min(self.rows, row))

        return col, row
end

function Arena:prepareLayout(floorNum, floorData, screenWidth, screenHeight, options)
        options = options or {}
        local regenerate = options.force or (self._layout == nil) or (self._layoutFloor ~= floorNum)

        if regenerate then
                local guidelines = resolveLayoutGuidelines(floorNum, floorData)
                local layout = generateLayoutFromGuidelines(guidelines)

                if layout then
                        layout.guidelines = guidelines
                        layout.floor = floorNum
                        self._layout = layout
                        self._layoutFloor = floorNum
                        self.width = layout.cols * self.tileSize
                        self.height = layout.rows * self.tileSize
                        self.cols = layout.cols
                        self.rows = layout.rows
                end
        end

        if self._layout then
                self.width = self._layout.cols * self.tileSize
                self.height = self._layout.rows * self.tileSize
        end

        local sw = screenWidth or self.screenWidth
        local sh = screenHeight or self.screenHeight

        if (not sw or not sh) and love and love.graphics and love.graphics.getDimensions then
                sw, sh = love.graphics.getDimensions()
        end

        if sw and sh then
                self:updateScreenBounds(sw, sh)
                if self._layout then
                        self.cols = self._layout.cols or self.cols
                        self.rows = self._layout.rows or self.rows
                end
        end

        return self._layout
end

function Arena:getCurrentLayout()
        return self._layout
end

function Arena:isInside(x, y)
	local inset = self.tileSize / 2

	return x >= (self.x + inset) and
			x <= (self.x + self.width  - inset) and
			y >= (self.y + inset) and
			y <= (self.y + self.height - inset)
end

function Arena:getRandomTile()
	local cols = math.max(1, self.cols or math.floor((self.width or 0) / (self.tileSize or 1)))
	local rows = math.max(1, self.rows or math.floor((self.height or 0) / (self.tileSize or 1)))

	local random = (love and love.math and love.math.random) or math.random

	local colMin = math.min(cols, 2)
	local colMax = math.max(colMin, cols - 1)
	if colMax < colMin then
		local fallback = math.max(1, math.floor(cols / 2 + 0.5))
		colMin, colMax = fallback, fallback
	end

	local rowMin = math.min(rows, 2)
	local rowMax = math.max(rowMin, rows - 1)
	if rowMax < rowMin then
		local fallback = math.max(1, math.floor(rows / 2 + 0.5))
		rowMin, rowMax = fallback, fallback
	end

	local col = random(colMin, colMax)
	local row = random(rowMin, rowMax)

	return col, row
end

function Arena:getBounds()
	return self.x, self.y, self.width, self.height
end

function Arena:setBackgroundEffect(effectData, palette)
	local effectType
	local overrides

	if type(effectData) == "string" then
		effectType = effectData
	elseif type(effectData) == "table" then
		effectType = effectData.type or effectData.name
		overrides = effectData
	end

	self._backgroundEffects = self._backgroundEffects or {}

	if not effectType or not Shaders.has(effectType) then
		self.activeBackgroundEffect = nil
		return
	end

	local effect = Shaders.ensure(self._backgroundEffects, effectType)
	if not effect then
		self.activeBackgroundEffect = nil
		return
	end

	local defaultBackdrop, defaultArena = Shaders.getDefaultIntensities(effect)

	effect.backdropIntensity = defaultBackdrop
	effect.arenaIntensity = defaultArena

	if overrides then
		if overrides.backdropIntensity then
			effect.backdropIntensity = overrides.backdropIntensity
		end

		if overrides.arenaIntensity then
			effect.arenaIntensity = overrides.arenaIntensity
		end
	end

	effect._lastEffectData = overrides

	Shaders.configure(effect, palette, overrides)

	self.activeBackgroundEffect = effect
end

function Arena:drawBackgroundEffect(x, y, w, h, intensity)
	local effect = self.activeBackgroundEffect
	if not effect then
		return false
	end

	local drawIntensity = intensity or effect.backdropIntensity or select(1, Shaders.getDefaultIntensities(effect))
	return Shaders.draw(effect, x, y, w, h, drawIntensity)
end

function Arena:drawBackdrop(sw, sh)
	love.graphics.setColor(Theme.bgColor)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	local drawn = false
	local effect = self.activeBackgroundEffect
	if effect then
		local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
		local intensity = effect.backdropIntensity or defaultBackdrop
		drawn = Shaders.draw(effect, 0, 0, sw, sh, intensity) or false
	end

	love.graphics.setColor(1, 1, 1, 1)
	return drawn
end

-- Draws the playfield with a solid fill + simple border
function Arena:drawBackground()
	local ax, ay, aw, ah = self:getBounds()

	if self.activeBackgroundEffect then
		local defaultBackdrop, defaultArena = Shaders.getDefaultIntensities(self.activeBackgroundEffect)
		local intensity = self.activeBackgroundEffect.arenaIntensity or defaultArena
		Shaders.draw(self.activeBackgroundEffect, ax, ay, aw, ah, intensity)
	end

	-- Solid fill (rendered on top of shader-driven effects so gameplay remains clear)
	love.graphics.setColor(Theme.arenaBG)
	love.graphics.rectangle("fill", ax, ay, aw, ah)

	drawSpawnDebugOverlay(self)

	love.graphics.setColor(1, 1, 1, 1)
end

-- Draws border
function Arena:drawBorder()
	local ax, ay, aw, ah = self:getBounds()

	-- Match snake style
	local thickness    = 20       -- border thickness
	local outlineSize  = 6        -- black outline thickness
	local shadowOffset = 3
	local radius       = thickness / 2

	-- Expand the border rect outward so it doesn’t bleed inside
	local correction = (thickness / 2) + 3   -- negative = pull inward, positive = push outward
	local ox = correction
	local oy = correction
	local bx, by = ax - ox, ay - oy
	local bw, bh = aw + ox * 2, ah + oy * 2

	local borderFlare = math.max(0, math.min(1.2, self.borderFlare or 0))
	local flarePulse = 0
	if borderFlare > 0 then
		flarePulse = (math.sin((self.borderFlareTimer or 0) * 9.0) + 1) * 0.5
	end

	-- Create/reuse MSAA canvas
	if not self.borderCanvas or
		self.borderCanvas:getWidth() ~= love.graphics.getWidth() or
		self.borderCanvas:getHeight() ~= love.graphics.getHeight() then
		self.borderCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {msaa = 8})
	end

	love.graphics.setCanvas(self.borderCanvas)
	love.graphics.clear(0,0,0,0)

	love.graphics.setLineStyle("smooth")

	-- Outline pass
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.setLineWidth(thickness + outlineSize)
	love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

	-- Fill (arena border color)
	local borderColor = Theme.arenaBorder
	if borderFlare > 0 and borderColor then
		local mixAmount = math.min(0.45, 0.32 * borderFlare + 0.18 * flarePulse * borderFlare)
		local r = mixChannel(borderColor[1] or 1, 0.96, mixAmount)
		local g = mixChannel(borderColor[2] or 1, 0.24, mixAmount * 1.05)
		local b = mixChannel(borderColor[3] or 1, 0.18, mixAmount * 1.1)
		love.graphics.setColor(r, g, b, borderColor[4] or 1)
	else
		if borderColor then
			love.graphics.setColor(borderColor)
		else
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
	love.graphics.setLineWidth(thickness)
	love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

	-- Highlight pass for the top + left edges
	local highlightShift = 3
	local function appendArcPoints(points, cx, cy, radius, startAngle, endAngle, segments, skipFirst)
		if segments < 1 then
			segments = 1
		end

		for i = 0, segments do
			if not (skipFirst and i == 0) then
				local t = i / segments
				local angle = startAngle + (endAngle - startAngle) * t
				points[#points + 1] = cx + math.cos(angle) * radius - highlightShift
				points[#points + 1] = cy + math.sin(angle) * radius - highlightShift
			end
		end
	end

	local highlight = getHighlightColor(Theme.arenaBorder)
	-- Disable the glossy highlight along the top-left edge.
	highlight[4] = 0
	if borderFlare > 0 then
		-- Ease the flare towards a softer pastel tint instead of a harsh glow.
		-- This keeps the pickup celebration visible while avoiding a sharp contrast.
		highlight[1] = math.min(1, mixChannel(highlight[1], 0.97, 0.35 * borderFlare))
		highlight[2] = math.max(0, mixChannel(highlight[2], 0.3, 0.48 * borderFlare))
		highlight[3] = math.max(0, mixChannel(highlight[3], 0.25, 0.52 * borderFlare))
		highlight[4] = math.min(1, highlight[4] * (1 + 0.45 * borderFlare))
	end

	local highlightAlpha = highlight[4] or 0
	local highlightOffset = 2
	if highlightAlpha > 0 then
		local highlightWidth = math.max(1.5, thickness * (0.26 + 0.12 * borderFlare))
		local cornerOffsetX = 3
		local cornerOffsetY = 3
		local scissorX = math.floor(bx - highlightWidth - highlightOffset - highlightShift)
		local scissorY = math.floor(by - highlightWidth - highlightOffset - highlightShift)
		local scissorW = math.ceil(bw + highlightWidth * 2 + highlightOffset + highlightShift * 2)
		local scissorH = math.ceil(bh + highlightWidth * 2 + highlightOffset + highlightShift * 2)
		local outerRadius = radius + highlightOffset
		local arcSegments = math.max(6, math.floor(outerRadius * 0.75))

		local topPoints = {}
		topPoints[#topPoints + 1] = bx + bw - radius - highlightShift
		topPoints[#topPoints + 1] = by - highlightOffset - highlightShift
		topPoints[#topPoints + 1] = bx + radius - highlightShift
		topPoints[#topPoints + 1] = by - highlightOffset - highlightShift
		local cornerStartIndex = #topPoints + 1
		appendArcPoints(topPoints, bx + radius - highlightShift, by + radius - highlightShift, outerRadius, -math.pi / 2, -math.pi, arcSegments, true)
		for i = cornerStartIndex, #topPoints, 2 do
			topPoints[i] = topPoints[i] + cornerOffsetX
			topPoints[i + 1] = topPoints[i + 1] + cornerOffsetY
		end

		local leftPoints = {}
		leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
		leftPoints[#leftPoints + 1] = by + radius - highlightShift
		leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
		leftPoints[#leftPoints + 1] = by + bh - radius - highlightShift

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
		local prevLineWidth = love.graphics.getLineWidth()
		local prevLineStyle = love.graphics.getLineStyle()
		local prevLineJoin = love.graphics.getLineJoin()
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineJoin("bevel")
		love.graphics.setLineWidth(highlightWidth)

		-- Top edge highlight
		love.graphics.setScissor(scissorX, scissorY, scissorW, math.ceil(highlightWidth * 2.4 + cornerOffsetY))
		love.graphics.line(topPoints)

		-- Left edge highlight
		love.graphics.setScissor(scissorX, scissorY, math.ceil(highlightWidth * 2.4), scissorH)
		love.graphics.line(leftPoints)

		love.graphics.setScissor()
		love.graphics.setLineWidth(prevLineWidth)
		love.graphics.setLineStyle(prevLineStyle)
		love.graphics.setLineJoin(prevLineJoin)
	end

	if borderFlare > 0.01 then
		local glowStrength = borderFlare
		local glowAlpha = 0.28 * glowStrength + 0.16 * flarePulse * glowStrength
		local emberAlpha = 0.18 * glowStrength

		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		love.graphics.setLineWidth(thickness + outlineSize * (1.05 + 0.25 * glowStrength))
		love.graphics.setColor(0.96, 0.32, 0.24, glowAlpha)
		love.graphics.rectangle("line", bx, by, bw, bh, radius + 4 + glowStrength * 3.0, radius + 4 + glowStrength * 3.0)
		love.graphics.setLineWidth(math.max(2, thickness * 0.55))
		love.graphics.setColor(0.55, 0.08, 0.06, emberAlpha)
		love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)
		love.graphics.pop()
	end

	-- Soft caps for highlight ends
	local topCapX = bx + bw - radius - highlightShift
	local topCapY = by - highlightOffset - highlightShift
	local leftCapX = bx - highlightOffset - highlightShift
	local leftCapY = by + bh - radius - highlightShift

	if highlightAlpha > 0 then
		local highlightWidth = math.max(1.5, thickness * (0.26 + 0.12 * borderFlare))
		local capRadius = highlightWidth * 0.7
		local featherRadius = capRadius * (1.9 + 0.35 * borderFlare)
		local capAlpha = highlightAlpha * (0.4 + 0.22 * borderFlare)
		local featherAlpha = highlightAlpha * (0.18 + 0.16 * borderFlare)

		local function drawHighlightCap(cx, cy)
			if capAlpha > 0 then
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], capAlpha)
				love.graphics.circle("fill", cx, cy, capRadius)
			end

			if featherAlpha > 0 then
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], featherAlpha)
				love.graphics.circle("fill", cx, cy, featherRadius)
			end
		end

		drawHighlightCap(topCapX, topCapY)
		drawHighlightCap(leftCapX, leftCapY)

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
	end

	love.graphics.setCanvas()

	-- Shadow pass
	love.graphics.setColor(0, 0, 0, 0.25)
	love.graphics.draw(self.borderCanvas, shadowOffset, shadowOffset)

	-- Final draw
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.borderCanvas, 0, 0)
end

-- Spawn an exit at a random valid tile
function Arena:spawnExit()
	if self.exit then return end

	local SnakeUtils = getModule("snakeutils")
	local Fruit = getModule("fruit")
	local fruitCol, fruitRow = nil, nil
	if Fruit and Fruit.getTile then
		fruitCol, fruitRow = Fruit:getTile()
	end

	local Rocks = getModule("rocks")
	local rockList = (Rocks and Rocks.getAll and Rocks:getAll()) or {}

	local Snake = getModule("snake")
	local snakeSegments = nil
	local snakeSafeZone = nil
	local headX, headY = nil, nil
	if Snake then
		if Snake.getSegments then
			snakeSegments = Snake:getSegments()
		end
		if Snake.getSafeZone then
			snakeSafeZone = Snake:getSafeZone(3)
		end
		if Snake.getHead then
			headX, headY = Snake:getHead()
		end
	end

	local threshold = (SnakeUtils and SnakeUtils.SEGMENT_SIZE) or self.tileSize
	local halfThreshold = threshold * 0.5
	local minHeadDistance = self.tileSize * MIN_HEAD_DISTANCE_TILES
	local minHeadDistanceSq = minHeadDistance * minHeadDistance

	local function tileIsSafe(col, row)
		local cx, cy = self:getCenterOfTile(col, row)

		if SnakeUtils and SnakeUtils.isOccupied and SnakeUtils.isOccupied(col, row) then
			return false
		end

		if fruitCol and fruitRow and fruitCol == col and fruitRow == row then
			return false
		end

		for _, rock in ipairs(rockList) do
			local rcol, rrow = self:getTileFromWorld(rock.x or cx, rock.y or cy)
			if rcol == col and rrow == row then
				return false
			end
		end

		if snakeSafeZone and isTileInSafeZone(snakeSafeZone, col, row) then
			return false
		end

		if snakeSegments then
			for _, seg in ipairs(snakeSegments) do
				local dx = math.abs((seg.drawX or 0) - cx)
				local dy = math.abs((seg.drawY or 0) - cy)
				if dx < halfThreshold and dy < halfThreshold then
					return false
				end
			end
		end

		if headX and headY then
			if distanceSquared(cx, cy, headX, headY) < minHeadDistanceSq then
				return false
			end
		end

		return true
	end

	local chosenCol, chosenRow
	for _ = 1, EXIT_SAFE_ATTEMPTS do
		local col, row = self:getRandomTile()
		if tileIsSafe(col, row) then
			chosenCol, chosenRow = col, row
			break
		end
	end

	if not (chosenCol and chosenRow) then
		for row = 2, self.rows - 1 do
			for col = 2, self.cols - 1 do
				if tileIsSafe(col, row) then
					chosenCol, chosenRow = col, row
					break
				end
			end
			if chosenCol then break end
		end
	end

	chosenCol = chosenCol or math.floor(self.cols / 2)
	chosenRow = chosenRow or math.floor(self.rows / 2)

	if SnakeUtils and SnakeUtils.setOccupied then
		SnakeUtils.setOccupied(chosenCol, chosenRow, true)
	end

	local x, y = self:getCenterOfTile(chosenCol, chosenRow)
	local size = self.tileSize * 0.75
	self.exit = {
		x = x, y = y,
		size = size,
		anim = 0,                -- 0 = closed, 1 = fully open
		animTime = 0.4,          -- seconds to open
		col = chosenCol,
		row = chosenRow,
		time = 0,
	}
	Audio:playSound("exit_spawn")
end

function Arena:getExitCenter()
	if not self.exit then return nil, nil, 0 end
	local r = self.exit.size * 0.5
	return self.exit.x, self.exit.y, r
end

function Arena:hasExit()
	return self.exit ~= nil
end

function Arena:update(dt)
	if dt and dt > 0 then
		local baseStrength = self.borderFlareStrength

		if not (baseStrength and baseStrength > 0) then
			baseStrength = self.borderFlare or 0
			if baseStrength > 0 then
				self.borderFlareStrength = baseStrength
			end
		end

		if baseStrength and baseStrength > 0 then
			local duration = math.max(0.35, self.borderFlareDuration or 1.05)
			local timer = math.min(duration, (self.borderFlareTimer or 0) + dt)
			local progress = math.min(1, timer / duration)
			local fade = 1 - (progress * progress * (3 - 2 * progress))

			self.borderFlare = math.max(0, baseStrength * fade)
			self.borderFlareTimer = timer

			if progress >= 1 then
				self.borderFlare = 0
				self.borderFlareStrength = 0
				self.borderFlareTimer = 0
			end
		else
			self.borderFlare = 0
			self.borderFlareStrength = 0
			self.borderFlareTimer = 0
		end
	end

	if not self.exit then
		return
	end

	if self.exit.anim < 1 then
		self.exit.anim = math.min(1, self.exit.anim + dt / self.exit.animTime)
	end

	self.exit.time = (self.exit.time or 0) + dt
end

-- Reset/clear exit when moving to next floor
function Arena:resetExit()
	if self.exit then
		local SnakeUtils = getModule("snakeutils")
		if SnakeUtils and SnakeUtils.setOccupied and self.exit.col and self.exit.row then
			SnakeUtils.setOccupied(self.exit.col, self.exit.row, false)
		end
	end

	self.exit = nil
end

-- Check if snake head collides with the exit
function Arena:checkExitCollision(snakeX, snakeY)
	if not self.exit then return false end
	local dx, dy = snakeX - self.exit.x, snakeY - self.exit.y
	local distSq = dx * dx + dy * dy
	local r = self.exit.size * 0.5
	return distSq <= (r * r)
end

-- Draw the exit (if active)
function Arena:drawExit()
	if not self.exit then return end

	local exit = self.exit
	local t = exit.anim
	local eased = 1 - (1 - t) * (1 - t)
	local radius = (exit.size / 1.5) * eased
	local cx, cy = exit.x, exit.y
	local time = exit.time or 0

	local rimRadius = radius * (1.05 + 0.03 * math.sin(time * 1.3))
	love.graphics.setColor(0.16, 0.15, 0.19, 1)
	love.graphics.circle("fill", cx, cy, rimRadius, 48)

	love.graphics.setColor(0.10, 0.09, 0.12, 1)
	love.graphics.circle("fill", cx, cy, radius * 0.94, 48)

	love.graphics.setColor(0.06, 0.05, 0.07, 1)
	love.graphics.circle("fill", cx, cy, radius * (0.78 + 0.05 * math.sin(time * 2.1)), 48)

	love.graphics.setColor(0.0, 0.0, 0.0, 1)
	love.graphics.circle("fill", cx, cy, radius * (0.58 + 0.04 * math.sin(time * 1.7)), 48)

	love.graphics.setColor(0.22, 0.20, 0.24, 0.85 * eased)
	love.graphics.arc("fill", cx, cy, radius * 0.98, -math.pi * 0.65, -math.pi * 0.05, 32)

	love.graphics.setColor(0, 0, 0, 0.45 * eased)
	love.graphics.arc("fill", cx, cy, radius * 0.72, math.pi * 0.2, math.pi * 1.05, 32)

	love.graphics.setColor(0.04, 0.04, 0.05, 0.9 * eased)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", cx, cy, radius * 0.96, 48)
	love.graphics.setLineWidth(1)
end

function Arena:triggerBorderFlare(strength, duration)
	local amount = math.max(0, strength or 0)
	if amount <= 0 then
		return
	end

	local existing = self.borderFlare or 0
	local newStrength = math.min(1.2, existing + amount)
	self.borderFlare = newStrength
	self.borderFlareStrength = newStrength
	self.borderFlareTimer = 0

	if duration and duration > 0 then
		self.borderFlareDuration = duration
	elseif not self.borderFlareDuration or self.borderFlareDuration <= 0 then
		self.borderFlareDuration = 1.05
	end
end

return Arena
