local Theme = require("theme")
local Audio = require("audio")
local Shaders = require("shaders")
local RenderLayers = require("renderlayers")
local SharedCanvas = require("sharedcanvas")

local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin

local EXIT_SAFE_ATTEMPTS = 180
local MIN_HEAD_DISTANCE_TILES = 2

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

local function getHighlightColor(color)
	color = color or {1, 1, 1, 1}

	local r = min(1, color[1] * 1.2 + 0.08)
	local g = min(1, color[2] * 1.2 + 0.08)
	local b = min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75

	return {r, g, b, a}
end

local function normalizeCellCoordinate(value)
	if value == nil then
		return nil
	end

	return floor(value + 0.5)
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
		local radius = min(8, tileSize * 0.35)

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

local function clamp01(value)
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function copyColor(color, defaultAlpha)
	if not color then
		return {0, 0, 0, defaultAlpha or 1}
	end

	return {
		color[1] or 0,
		color[2] or 0,
		color[3] or 0,
		color[4] or defaultAlpha or 1,
	}
end

local function getPaletteColor(palette, key, fallback, defaultAlpha)
	local value = fallback
	if palette and palette[key] then
		value = palette[key]
	end
	return copyColor(value, defaultAlpha)
end

local function mixColorTowards(baseColor, targetColor, amount, alphaOverride)
	local color = {}
	for i = 1, 3 do
		color[i] = clamp01(mixChannel(baseColor[i] or 0, targetColor[i] or 0, amount))
	end

	if alphaOverride ~= nil then
		color[4] = alphaOverride
	else
		local baseAlpha = baseColor[4] or 1
		local targetAlpha = targetColor[4] or 1
		color[4] = clamp01(mixChannel(baseAlpha, targetAlpha, amount))
	end

	return color
end

local THEME_TINTS = {
	botanical   = {0.28, 0.42, 0.24, 1},
	cavern      = {0.26, 0.3, 0.46, 1},
	oceanic     = {0.2, 0.36, 0.52, 1},
	machine     = {0.42, 0.34, 0.24, 1},
	arctic      = {0.34, 0.5, 0.64, 1},
	desert      = {0.5, 0.4, 0.22, 1},
	laboratory  = {0.42, 0.38, 0.56, 1},
	urban       = {0.3, 0.36, 0.44, 1},
}

local VARIANT_TINTS = {
	fungal = {0.34, 0.28, 0.5, 1},
}

local function hashString(value)
	if not value or value == "" then
		return 0
	end

	local hash = 0
	for i = 1, #value do
		hash = (hash * 131 + string.byte(value, i)) % 2147483647
	end

	return hash
end

local function hashColor(color)
	if not color then
		return 0
	end

	local hash = 0
	for i = 1, 4 do
		local channel = floor(((color[i] or 0) * 255) + 0.5)
		hash = (hash * 131 + channel) % 2147483647
	end

	return hash
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
	cols = 0,
	rows = 0,
	exit = nil,
	activeBackgroundEffect = nil,
	borderFlare = 0,
	borderFlareStrength = 0,
	borderFlareTimer = 0,
	borderFlareDuration = 1.05,
	borderDirty = true,
	_borderLastCanvasWidth = 0,
	_borderLastCanvasHeight = 0,
	_borderLastColorHash = nil,
	_borderLastBounds = nil,
	_borderGeometry = nil,
	_tileDecorations = nil,
	_decorationConfig = nil,
	_arenaInsetMesh = nil,
	_arenaNoiseTexture = nil,
	_arenaNoiseQuad = nil,
	_arenaOverlayBounds = nil,
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
	self.x = floor((sw - self.width) / 2)
	self.y = floor((sh - self.height) / 2)

	-- snap x,y to nearest tile boundary so centers align
	self.x = self.x - (self.x % self.tileSize)
	self.y = self.y - (self.y % self.tileSize)

	self.cols = floor(self.width / self.tileSize)
	self.rows = floor(self.height / self.tileSize)

	if self.rebuildTileDecorations then
		self:rebuildTileDecorations()
	end

	self.borderDirty = true
	self._borderLastBounds = nil
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
	local epsilon = 1e-9
	local tileSize = self.tileSize
	if not tileSize or tileSize == 0 then
		tileSize = 1
	end
	local normalizedCol = ((x - self.x) / tileSize) + epsilon
	local normalizedRow = ((y - self.y) / tileSize) + epsilon
	local col = floor(normalizedCol) + 1
	local row = floor(normalizedRow) + 1

	-- clamp inside arena grid
	col = max(1, min(self.cols, col))
	row = max(1, min(self.rows, row))

	return col, row
end

function Arena:isInside(x, y)
	local inset = self.tileSize / 2

	return x >= (self.x + inset) and
	x <= (self.x + self.width  - inset) and
	y >= (self.y + inset) and
	y <= (self.y + self.height - inset)
end

function Arena:setFloorDecorations(floorNum, floorData)
	if not floorNum and not floorData then
		self._decorationConfig = nil
		self._tileDecorations = nil
		return
	end

	local seed = os.time()
	seed = seed + floor(love.timer.getTime() * 1000)

	self._decorationConfig = {
		floor = floorNum or 0,
		palette = floorData and floorData.palette,
		theme = floorData and floorData.backgroundTheme,
		variant = floorData and floorData.backgroundVariant,
		seed = seed,
	}

	self:rebuildTileDecorations()
end

local directions = {
	{1, 0},
	{-1, 0},
	{0, 1},
	{0, -1},
}

local DECORATION_PATTERN_WIDTH = 800
local DECORATION_PATTERN_HEIGHT = 600
local DECORATION_PATTERN_FILENAME = "generated/arena_floor_pattern.png"

function Arena:rebuildTileDecorations()
	local config = self._decorationConfig
	if not config then
		self._tileDecorations = nil
		return
	end

	local cols = self.cols or 0
	local rows = self.rows or 0
	if cols <= 0 or rows <= 0 then
		self._tileDecorations = nil
		return
	end

	local palette = config.palette
	local baseColor = getPaletteColor(palette, "arenaBG", Theme.arenaBG, 1)
	local highlightTarget = getPaletteColor(palette, "highlightColor", Theme.highlightColor, 1)
	local shadowTarget = getPaletteColor(palette, "shadowColor", Theme.shadowColor, 1)
	local accentTarget = getPaletteColor(palette, "arenaBorder", Theme.arenaBorder, 1)
	if palette and palette.rock then
		accentTarget = copyColor(palette.rock, 1)
	elseif Theme.rock then
		accentTarget = copyColor(Theme.rock, 1)
	end

	local theme = config.theme
	local variant = config.variant

	local function averagePaletteColors(a, b)
		if not a and not b then
			return nil
		end

		if not a then
			return copyColor(b, 1)
		end

		if not b then
			return copyColor(a, 1)
		end

		return {
			clamp01(((a[1] or 0) + (b[1] or 0)) * 0.5),
			clamp01(((a[2] or 0) + (b[2] or 0)) * 0.5),
			clamp01(((a[3] or 0) + (b[3] or 0)) * 0.5),
			1,
		}
	end

	local function resolveThemeTint()
		local tint = VARIANT_TINTS[variant] or THEME_TINTS[theme]
		if tint then
			return copyColor(tint, 1)
		end

		if palette then
			local snakeColor = palette.snake and copyColor(palette.snake, 1)
			local rockColor = palette.rock and copyColor(palette.rock, 1)
			local fruitColor = palette.fruit and copyColor(palette.fruit, 1)

			return averagePaletteColors(averagePaletteColors(snakeColor, rockColor), fruitColor)
		end

		return nil
	end

	local themeTint = resolveThemeTint()

	local baseSeed = (config.seed or os.time()) % 2147483647
	baseSeed = baseSeed + (config.floor or 0) * 131071 + hashString(theme) * 17 + hashString(variant) * 31
	local rng = love.math.newRandomGenerator(baseSeed)

	local tileSize = self.tileSize or 24
	local clusterChance = 0.01
	local minClusterSize = 2
	local maxClusterSize = 4
	local colorJitter = 0.005

	if theme == "botanical" then
		clusterChance = clusterChance + 0.02
		maxClusterSize = maxClusterSize + 1
	elseif theme == "machine" then
		clusterChance = max(0.06, clusterChance - 0.02)
		colorJitter = 0.015
	elseif theme == "oceanic" then
		clusterChance = clusterChance + 0.01
	elseif theme == "cavern" then
		clusterChance = clusterChance - 0.005
	end

	clusterChance = clusterChance * (0.85 + rng:random() * 0.35)
	clusterChance = max(0, min(0.25, clusterChance))

	local decorations = {}
	local occupied = {}
	local safeZone = self._spawnDebugData and self._spawnDebugData.safeZone

	local function cellKey(col, row)
		return (row - 1) * cols + col
	end

	local function isOccupied(col, row)
		return occupied[cellKey(col, row)] == true
	end

	local function occupy(col, row)
		occupied[cellKey(col, row)] = true
	end

	local function makeClusterColor()
		local lighten = rng:random() < 0.45
		local target = lighten and highlightTarget or shadowTarget
		local amount = lighten and (0.1 + rng:random() * 0.06) or (0.12 + rng:random() * 0.04)
		local alpha = lighten and (0.18 + rng:random() * 0.05) or (0.22 + rng:random() * 0.05)
		local color = mixColorTowards(baseColor, target, amount, alpha)

		if rng:random() < 0.35 then
			local accentMix = 0.24 + rng:random() * 0.14
			local accentAlpha = clamp01((color[4] or 1) * (0.9 + rng:random() * 0.1))
			color = mixColorTowards(color, accentTarget, accentMix, accentAlpha)
		end

		if themeTint then
			local tintMix = 0.1 + rng:random() * 0.08
			local tintAlpha = clamp01((color[4] or 1) * (0.9 + rng:random() * 0.1))
			color = mixColorTowards(color, themeTint, tintMix, tintAlpha)
		end

		return color
	end

	local function jitterColor(color)
		local jittered = copyColor(color)
		for i = 1, 3 do
			jittered[i] = clamp01(jittered[i] + (rng:random() * 2 - 1) * colorJitter)
		end
		jittered[4] = clamp01((jittered[4] or 1) * (0.92 + rng:random() * 0.08))
		return jittered
	end

	local function addRoundedSquare(col, row, size, radius, color)
		local baseAlpha = color[4] or 1
		local fadeAmplitude = 0.05 + rng:random() * 0.08
		local fadeSpeed = 0.2 + rng:random() * 0.45
		decorations[#decorations + 1] = {
			col = col,
			row = row,
			x = (tileSize - size) * 0.5,
			y = (tileSize - size) * 0.5,
			w = size,
			h = size,
			radius = radius,
			color = {color[1], color[2], color[3], baseAlpha},
			fade = {
				base = baseAlpha,
				amplitude = fadeAmplitude,
				speed = fadeSpeed,
				offset = rng:random() * pi * 2,
			},
		}
	end

	for row = 1, rows do
		for col = 1, cols do
			if not isOccupied(col, row) and rng:random() < clusterChance then
				if safeZone and isTileInSafeZone(safeZone, col, row) then
					occupy(col, row)
				else
					local clusterColor = makeClusterColor()
					local clusterSize = rng:random(minClusterSize, maxClusterSize)
					local clusterCells = {{col = col, row = row}}
					occupy(col, row)

					local attempts = 0
					while #clusterCells < clusterSize and attempts < clusterSize * 6 do
						attempts = attempts + 1
						local baseIndex = rng:random(1, #clusterCells)
						local baseCell = clusterCells[baseIndex]
						local dir = directions[rng:random(1, #directions)]
						local nextCol = baseCell.col + dir[1]
						local nextRow = baseCell.row + dir[2]

						if nextCol >= 1 and nextCol <= cols and nextRow >= 1 and nextRow <= rows then
							if not isOccupied(nextCol, nextRow) and not (safeZone and isTileInSafeZone(safeZone, nextCol, nextRow)) then
								occupy(nextCol, nextRow)
								clusterCells[#clusterCells + 1] = {col = nextCol, row = nextRow}
							end
						end
					end

					local size = min(tileSize * (0.48 + rng:random() * 0.18), tileSize)
					local radius = size * (0.18 + rng:random() * 0.14)

					for i = 1, #clusterCells do
						local cell = clusterCells[i]
						addRoundedSquare(cell.col, cell.row, size, radius, jitterColor(clusterColor))
					end
				end
			end
		end
	end

	self._tileDecorations = decorations

	self:_buildDecorationPattern(decorations)
end

function Arena:drawTileDecorations()
	local decorations = self._tileDecorations
	if not decorations or #decorations == 0 then
		return
	end

	love.graphics.push("all")
	love.graphics.setBlendMode("alpha")

	for i = 1, #decorations do
		local deco = decorations[i]
		local color = deco.color
		local width = deco.w or 0
		local height = deco.h or 0
		if color and width > 0 and height > 0 then
			local tileX, tileY = self:getTilePosition(deco.col, deco.row)
			local drawX = tileX + (deco.x or 0)
			local drawY = tileY + (deco.y or 0)
			local alpha = color[4] or 1
			local fade = deco.fade
			if fade and fade.amplitude and fade.amplitude > 0 then
				local time = love.timer.getTime()
				local oscillation = sin(time * (fade.speed or 1) + (fade.offset or 0))
				local factor = 1 + oscillation * fade.amplitude
				alpha = clamp01((fade.base or alpha) * factor)
			end

			love.graphics.setColor(color[1], color[2], color[3], alpha)
			love.graphics.rectangle("fill", drawX, drawY, width, height, deco.radius or 0, deco.radius or 0)
		end
	end

	love.graphics.pop()
end

function Arena:_buildDecorationPattern(decorations)
	if not decorations or #decorations == 0 then
		self._decorationPatternTexture = nil
		self._decorationPatternSignature = nil
		self._decorationPatternPath = nil
		return
	end

	local config = self._decorationConfig or {}
	local floor = config.floor or 0
	local theme = config.theme or ""
	local variant = config.variant or ""
	local seed = config.seed or 0
	local tileSize = self.tileSize or 24

	local signature = table.concat({
		floor,
		theme,
		variant,
		seed,
		#decorations,
		tileSize,
		DECORATION_PATTERN_WIDTH,
		DECORATION_PATTERN_HEIGHT,
	}, ":")

	if self._decorationPatternSignature == signature then
		return
	end

	local canvasWidth = DECORATION_PATTERN_WIDTH
	local canvasHeight = DECORATION_PATTERN_HEIGHT
	local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)

	local hasDecorations = false

	for i = 1, #decorations do
		local deco = decorations[i]
		local w = deco.w or 0
		local h = deco.h or deco.w or 0
		if w > 0 and h > 0 then
			hasDecorations = true
		end
	end

	if not hasDecorations then
		love.graphics.setCanvas()
		love.graphics.pop()
		canvas:release()
		self._decorationPatternTexture = nil
		self._decorationPatternSignature = nil
		self._decorationPatternPath = nil
		return
	end

	local cols = self.cols or 0
	local rows = self.rows or 0
	local layoutWidth = cols * tileSize
	local layoutHeight = rows * tileSize

	if layoutWidth <= 0 or layoutHeight <= 0 then
		love.graphics.setCanvas()
		love.graphics.pop()
		canvas:release()
		self._decorationPatternTexture = nil
		self._decorationPatternSignature = nil
		self._decorationPatternPath = nil
		return
	end

	local offsetX = max(0, (canvasWidth - layoutWidth) * 0.5)
	local offsetY = max(0, (canvasHeight - layoutHeight) * 0.5)

	for i = 1, #decorations do
		local deco = decorations[i]
		local w = deco.w or 0
		local h = deco.h or deco.w or 0
		if w > 0 and h > 0 then
			local baseX = (deco.col - 1) * tileSize + (deco.x or 0)
			local baseY = (deco.row - 1) * tileSize + (deco.y or 0)
			local x = offsetX + baseX
			local y = offsetY + baseY
			local radius = deco.radius or 0

			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.rectangle("fill", x, y, w, h, radius, radius)
		end
	end

	love.graphics.setCanvas()
	love.graphics.pop()

	local imageData = canvas:newImageData()

	love.filesystem.createDirectory("generated")
	imageData:encode("png", DECORATION_PATTERN_FILENAME)

	local texture = love.graphics.newImage(imageData)
	texture:setFilter("linear", "linear")
	texture:setWrap("repeat", "repeat")

	self._decorationPatternTexture = texture
	self._decorationPatternSignature = signature
	self._decorationPatternPath = DECORATION_PATTERN_FILENAME

	canvas:release()
end

function Arena:_ensureArenaNoiseTexture()
	if self._arenaNoiseTexture then
		return
	end

	local size = 128
	local imageData = love.image.newImageData(size, size)
	local rng = love.math.newRandomGenerator(os.time() % 2147483647)

	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local value = rng:random()
			local shade = clamp01(0.5 + (value - 0.5) * 0.08)
			imageData:setPixel(x, y, shade, shade, shade, 1)
		end
	end

	local texture = love.graphics.newImage(imageData)
	texture:setFilter("linear", "linear")
	texture:setWrap("repeat", "repeat")

	self._arenaNoiseTexture = texture
end

function Arena:_rebuildArenaInsetMesh(ax, ay, aw, ah)
	local inset = max(10, floor(min(aw, ah) * 0.04))
	local innerX = ax + inset
	local innerY = ay + inset
	local innerW = max(0, aw - inset * 2)
	local innerH = max(0, ah - inset * 2)

	local borderColor = Theme.arenaBorder or {0.2, 0.2, 0.25, 1}
	local r = mixChannel(borderColor[1] or 0.2, 0.0, 0.7)
	local g = mixChannel(borderColor[2] or 0.2, 0.0, 0.7)
	local b = mixChannel(borderColor[3] or 0.25, 0.0, 0.7)
	local outerAlpha = 0.16

	local vertices = {
		{ax, ay, 0, 0, r, g, b, outerAlpha},
		{ax + aw, ay, 1, 0, r, g, b, outerAlpha},
		{ax + aw, ay + ah, 1, 1, r, g, b, outerAlpha},
		{ax, ay + ah, 0, 1, r, g, b, outerAlpha},
		{innerX, innerY, 0, 0, r, g, b, 0},
		{innerX + innerW, innerY, 1, 0, r, g, b, 0},
		{innerX + innerW, innerY + innerH, 1, 1, r, g, b, 0},
		{innerX, innerY + innerH, 0, 1, r, g, b, 0},
	}

	local mesh = love.graphics.newMesh(vertices, "triangles", "static")
	mesh:setVertexMap({
		1, 5, 2,
		2, 5, 6,
		2, 6, 3,
		3, 6, 7,
		3, 7, 4,
		4, 7, 8,
		4, 8, 1,
		1, 8, 5,
	})

	self._arenaInsetMesh = mesh
end

function Arena:_updateArenaOverlayBounds(ax, ay, aw, ah)
	self:_ensureArenaNoiseTexture()

	local bounds = self._arenaOverlayBounds
	local changed = not bounds
	if bounds and (bounds.x ~= ax or bounds.y ~= ay or bounds.w ~= aw or bounds.h ~= ah) then
		changed = true
	end

	if not changed then
		return
	end

	self:_rebuildArenaInsetMesh(ax, ay, aw, ah)

	if self._arenaNoiseTexture then
		local textureW, textureH = self._arenaNoiseTexture:getDimensions()
		local offsetX = love.math.random() * textureW
		local offsetY = love.math.random() * textureH
		self._arenaNoiseQuad = love.graphics.newQuad(offsetX, offsetY, aw, ah, textureW, textureH)
	end

	self._arenaOverlayBounds = {x = ax, y = ay, w = aw, h = ah}
end

function Arena:_drawArenaInlay()
	if not self._arenaOverlayBounds then
		return
	end

	if self._arenaInsetMesh then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(self._arenaInsetMesh)
		love.graphics.pop()
	end

	if self._arenaNoiseTexture and self._arenaNoiseQuad then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha")
		local tint = Theme.arenaBG or {0.18, 0.18, 0.22, 1}
		local tintStrength = 0.05
		local r = mixChannel(tint[1] or 0.18, 1, 0.18)
		local g = mixChannel(tint[2] or 0.18, 1, 0.18)
		local b = mixChannel(tint[3] or 0.22, 1, 0.18)
		love.graphics.setColor(r, g, b, tintStrength)
		love.graphics.draw(self._arenaNoiseTexture, self._arenaNoiseQuad, self._arenaOverlayBounds.x, self._arenaOverlayBounds.y)
		love.graphics.pop()
	end
end

function Arena:getRandomTile()
	local col = love.math.random(2, self.cols - 1)
	local row = love.math.random(2, self.rows - 1)
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

	self:_updateArenaOverlayBounds(ax, ay, aw, ah)

	if self.drawTileDecorations then
		self:drawTileDecorations()
	end

	self:_drawArenaInlay()

	drawSpawnDebugOverlay(self)

	love.graphics.setColor(1, 1, 1, 1)
end

-- Draws border
function Arena:drawBorder()
	local ax, ay, aw, ah = self:getBounds()
	local thickness    = 20 -- border thickness
	local outlineSize  = 6 -- black outline thickness
	local shadowOffset = 3
	local radius       = thickness / 2

	-- Expand the border rect outward so it doesn’t bleed inside
	local correction = (thickness / 2) + 3   -- negative = pull inward, positive = push outward
	local ox = correction
	local oy = correction
	local bx, by = ax - ox, ay - oy
	local bw, bh = aw + ox * 2, ah + oy * 2
	local highlightShift = 3
	local highlightOffset = 2
	local cornerOffsetX = 3
	local cornerOffsetY = 3

	local borderFlare = max(0, min(1.2, self.borderFlare or 0))
	local flarePulse = 0
	if borderFlare > 0 then
		flarePulse = (sin((self.borderFlareTimer or 0) * 9.0) + 1) * 0.5
	end

        local borderColor = Theme.arenaBorder
        local colorHash = hashColor(borderColor)
        local canvasWidth = love.graphics.getWidth()
        local canvasHeight = love.graphics.getHeight()
        local useCanvas = SharedCanvas.isMSAAEnabled()

        local borderCanvas = nil
        if useCanvas then
                local canvas, replaced, samples = SharedCanvas.ensureCanvas(self.borderCanvas, canvasWidth, canvasHeight)
                if SharedCanvas.isMSAAEnabled() then
                        if canvas ~= self.borderCanvas then
                                self.borderCanvas = canvas
                        end
                        borderCanvas = canvas
                        self._borderCanvasSamples = samples
                        if replaced then
                                self.borderDirty = true
                        end
                else
                        useCanvas = false
                        borderCanvas = nil
                end
        end

        if not useCanvas then
                if self.borderCanvas then
                        self.borderCanvas = nil
                        self._borderCanvasSamples = nil
                        self.borderDirty = true
                end
        end

        self._borderLastCanvasWidth = canvasWidth
        self._borderLastCanvasHeight = canvasHeight

        local bounds = self._borderLastBounds
        local needsRebuild = self.borderDirty
        if not bounds or bounds[1] ~= bx or bounds[2] ~= by or bounds[3] ~= bw or bounds[4] ~= bh then
                needsRebuild = true
        end

        if (self._borderLastColorHash or 0) ~= colorHash then
                needsRebuild = true
        end

        if not self._borderGeometry then
                needsRebuild = true
        end

        local function drawBorderShape(outlineColor, fillColor)
                local prevLineWidth = love.graphics.getLineWidth()
                local prevLineStyle = love.graphics.getLineStyle()

                love.graphics.setLineStyle("smooth")

                local outline = outlineColor or {0, 0, 0, 1}
                love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
                love.graphics.setLineWidth(thickness + outlineSize)
                love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

                local fill = fillColor or borderColor or {1, 1, 1, 1}
                love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1)
                love.graphics.setLineWidth(thickness)
                love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

                love.graphics.setLineWidth(prevLineWidth)
                love.graphics.setLineStyle(prevLineStyle)
        end

        if needsRebuild then
                if borderCanvas then
                        local previousCanvas = {love.graphics.getCanvas()}
                        love.graphics.push("all")
                        love.graphics.setCanvas(borderCanvas)
                        love.graphics.clear(0, 0, 0, 0)
                        drawBorderShape({0, 0, 0, 1}, borderColor)
                        love.graphics.pop()

                        if #previousCanvas > 0 then
                                local unpack = table.unpack or unpack
                                love.graphics.setCanvas(unpack(previousCanvas))
                        else
                                love.graphics.setCanvas()
                        end
                end

                if not bounds then
                        bounds = {}
                        self._borderLastBounds = bounds
                end
                bounds[1], bounds[2], bounds[3], bounds[4] = bx, by, bw, bh
                self._borderLastColorHash = colorHash

                local outerRadius = radius + highlightOffset
                local arcSegments = max(6, floor(outerRadius * 0.75))
                local topPoints = {}
                topPoints[#topPoints + 1] = bx + bw - radius - highlightShift
                topPoints[#topPoints + 1] = by - highlightOffset - highlightShift
                topPoints[#topPoints + 1] = bx + radius - highlightShift
                topPoints[#topPoints + 1] = by - highlightOffset - highlightShift

                local function appendArcPoints(points, cx, cy, arcRadius, startAngle, endAngle, segments, skipFirst)
                        if segments < 1 then
                                segments = 1
                        end

                        for i = 0, segments do
                                if not (skipFirst and i == 0) then
                                        local t = i / segments
                                        local angle = startAngle + (endAngle - startAngle) * t
                                        points[#points + 1] = cx + math.cos(angle) * arcRadius - highlightShift
                                        points[#points + 1] = cy + sin(angle) * arcRadius - highlightShift
                                end
                        end
                end

                local cornerStartIndex = #topPoints + 1
                appendArcPoints(topPoints, bx + radius - highlightShift, by + radius - highlightShift, outerRadius, -pi / 2, -pi, arcSegments, true)
                for i = cornerStartIndex, #topPoints, 2 do
                        topPoints[i] = topPoints[i] + cornerOffsetX
                        topPoints[i + 1] = topPoints[i + 1] + cornerOffsetY
                end

                local leftPoints = {}
                leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
                leftPoints[#leftPoints + 1] = by + radius - highlightShift
                leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
                leftPoints[#leftPoints + 1] = by + bh - radius - highlightShift

                self._borderGeometry = {
                        bx = bx,
                        by = by,
                        bw = bw,
                        bh = bh,
                        radius = radius,
                        thickness = thickness,
                        outlineSize = outlineSize,
                        highlightShift = highlightShift,
                        highlightOffset = highlightOffset,
                        cornerOffsetX = cornerOffsetX,
                        cornerOffsetY = cornerOffsetY,
                        highlightTopPoints = topPoints,
                        highlightLeftPoints = leftPoints,
                        topCapX = bx + bw - radius - highlightShift,
                        topCapY = by - highlightOffset - highlightShift,
                        leftCapX = bx - highlightOffset - highlightShift,
                        leftCapY = by + bh - radius - highlightShift,
                }

                self.borderDirty = false
        end

        local geometry = self._borderGeometry

        RenderLayers:withLayer("shadows", function()
                if borderCanvas then
                        love.graphics.setColor(0, 0, 0, 0.25)
                        love.graphics.draw(borderCanvas, shadowOffset, shadowOffset)
                else
                        love.graphics.push("all")
                        love.graphics.translate(shadowOffset, shadowOffset)
                        drawBorderShape({0, 0, 0, 0.25}, {0, 0, 0, 0.25})
                        love.graphics.pop()
                end
        end)

        if borderCanvas then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(borderCanvas, 0, 0)
        else
                love.graphics.push("all")
                drawBorderShape({0, 0, 0, 1}, borderColor)
                love.graphics.pop()
        end

	if not geometry then
		love.graphics.setColor(1, 1, 1, 1)
		return
	end

	if borderFlare > 0 and borderColor then
		local mixAmount = min(0.45, 0.32 * borderFlare + 0.18 * flarePulse * borderFlare)
		local r = mixChannel(borderColor[1] or 1, 0.96, mixAmount)
		local g = mixChannel(borderColor[2] or 1, 0.24, mixAmount * 1.05)
		local b = mixChannel(borderColor[3] or 1, 0.18, mixAmount * 1.1)
		love.graphics.setColor(r, g, b, borderColor[4] or 1)
		local prevLineWidth = love.graphics.getLineWidth()
		local prevLineStyle = love.graphics.getLineStyle()
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineWidth(geometry.thickness)
		love.graphics.rectangle("line", geometry.bx, geometry.by, geometry.bw, geometry.bh, geometry.radius, geometry.radius)
		love.graphics.setLineWidth(prevLineWidth)
		love.graphics.setLineStyle(prevLineStyle)
	end
	local highlight = getHighlightColor(Theme.arenaBorder)
	-- Disable the glossy highlight along the top-left edge.
	highlight[4] = 0
	if borderFlare > 0 then
		-- Ease the flare towards a softer pastel tint instead of a harsh glow.
		-- This keeps the pickup celebration visible while avoiding a sharp contrast.
		highlight[1] = min(1, mixChannel(highlight[1], 0.97, 0.35 * borderFlare))
		highlight[2] = max(0, mixChannel(highlight[2], 0.3, 0.48 * borderFlare))
		highlight[3] = max(0, mixChannel(highlight[3], 0.25, 0.52 * borderFlare))
		highlight[4] = min(1, highlight[4] * (1 + 0.45 * borderFlare))
	end

	local highlightAlpha = highlight[4] or 0
	local highlightWidth
	if highlightAlpha > 0 then
		highlightWidth = max(1.5, geometry.thickness * (0.26 + 0.12 * borderFlare))
		local scissorX = floor(geometry.bx - highlightWidth - geometry.highlightOffset - geometry.highlightShift)
		local scissorY = floor(geometry.by - highlightWidth - geometry.highlightOffset - geometry.highlightShift)
		local scissorW = ceil(geometry.bw + highlightWidth * 2 + geometry.highlightOffset + geometry.highlightShift * 2)
		local scissorH = ceil(geometry.bh + highlightWidth * 2 + geometry.highlightOffset + geometry.highlightShift * 2)

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
		local prevLineWidth = love.graphics.getLineWidth()
		local prevLineStyle = love.graphics.getLineStyle()
		local prevLineJoin = love.graphics.getLineJoin()
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineJoin("bevel")
		love.graphics.setLineWidth(highlightWidth)

		-- Top edge highlight
		love.graphics.setScissor(scissorX, scissorY, scissorW, ceil(highlightWidth * 2.4 + geometry.cornerOffsetY))
		love.graphics.line(geometry.highlightTopPoints)

		-- Left edge highlight
		love.graphics.setScissor(scissorX, scissorY, ceil(highlightWidth * 2.4), scissorH)
		love.graphics.line(geometry.highlightLeftPoints)

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
		love.graphics.setLineWidth(geometry.thickness + geometry.outlineSize * (1.05 + 0.25 * glowStrength))
		love.graphics.setColor(0.96, 0.32, 0.24, glowAlpha)
		love.graphics.rectangle("line", geometry.bx, geometry.by, geometry.bw, geometry.bh, geometry.radius + 4 + glowStrength * 3.0, geometry.radius + 4 + glowStrength * 3.0)
		love.graphics.setLineWidth(max(2, geometry.thickness * 0.55))
		love.graphics.setColor(0.55, 0.08, 0.06, emberAlpha)
				love.graphics.rectangle("line", geometry.bx, geometry.by, geometry.bw, geometry.bh, geometry.radius, geometry.radius)
		love.graphics.pop()
	end

	if highlightAlpha > 0 then
		highlightWidth = highlightWidth or max(1.5, geometry.thickness * (0.26 + 0.12 * borderFlare))
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

		local topCapX, topCapY = geometry.topCapX, geometry.topCapY
		local leftCapX, leftCapY = geometry.leftCapX, geometry.leftCapY
		drawHighlightCap(topCapX, topCapY)
		drawHighlightCap(leftCapX, leftCapY)

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
	end

	love.graphics.setColor(1, 1, 1, 1)
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
				local dx = abs((seg.drawX or 0) - cx)
				local dy = abs((seg.drawY or 0) - cy)
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

	chosenCol = chosenCol or floor(self.cols / 2)
	chosenRow = chosenRow or floor(self.rows / 2)

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
			local duration = max(0.35, self.borderFlareDuration or 1.05)
			local timer = min(duration, (self.borderFlareTimer or 0) + dt)
			local progress = min(1, timer / duration)
			local fade = 1 - (progress * progress * (3 - 2 * progress))

			self.borderFlare = max(0, baseStrength * fade)
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
		self.exit.anim = min(1, self.exit.anim + dt / self.exit.animTime)
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

	RenderLayers:withLayer("overlay", function()
		local exit = self.exit
		local t = exit.anim
		local eased = 1 - (1 - t) * (1 - t)
		local radius = (exit.size / 1.5) * eased
		local cx, cy = exit.x, exit.y
		local time = exit.time or 0

		local rimRadius = radius * (1.05 + 0.03 * sin(time * 1.3))
		love.graphics.setColor(0.16, 0.15, 0.19, 1)
		love.graphics.circle("fill", cx, cy, rimRadius, 48)

		love.graphics.setColor(0.10, 0.09, 0.12, 1)
		love.graphics.circle("fill", cx, cy, radius * 0.94, 48)

		love.graphics.setColor(0.06, 0.05, 0.07, 1)
		love.graphics.circle("fill", cx, cy, radius * (0.78 + 0.05 * sin(time * 2.1)), 48)

		love.graphics.setColor(0.0, 0.0, 0.0, 1)
		love.graphics.circle("fill", cx, cy, radius * (0.58 + 0.04 * sin(time * 1.7)), 48)

		love.graphics.setColor(0.22, 0.20, 0.24, 0.85 * eased)
		love.graphics.arc("fill", cx, cy, radius * 0.98, -pi * 0.65, -pi * 0.05, 32)

		love.graphics.setColor(0, 0, 0, 0.45 * eased)
		love.graphics.arc("fill", cx, cy, radius * 0.72, pi * 0.2, pi * 1.05, 32)

		love.graphics.setColor(0.04, 0.04, 0.05, 0.9 * eased)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", cx, cy, radius * 0.96, 48)
		love.graphics.setLineWidth(1)
	end)
end

function Arena:triggerBorderFlare(strength, duration)
	local amount = max(0, strength or 0)
	if amount <= 0 then
		return
	end

	local existing = self.borderFlare or 0
	local newStrength = min(1.2, existing + amount)
	self.borderFlare = newStrength
	self.borderFlareStrength = newStrength
	self.borderFlareTimer = 0
	self.borderDirty = true

	if duration and duration > 0 then
		self.borderFlareDuration = duration
	elseif not self.borderFlareDuration or self.borderFlareDuration <= 0 then
		self.borderFlareDuration = 1.05
	end
end

return Arena