local Theme = require("theme")
local Audio = require("audio")
local Shaders = require("shaders")

local EXIT_SAFE_ATTEMPTS = 180
local MIN_HEAD_DISTANCE_TILES = 2


local function GetModule(name)
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

local function DistanceSquared(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return dx * dx + dy * dy
end

local function GetHighlightColor(color)
	color = color or {1, 1, 1, 1}

	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75

	return {r, g, b, a}
end

local function NormalizeCellCoordinate(value)
	if value == nil then
		return nil
	end

	return math.floor(value + 0.5)
end

local function DrawSpawnDebugOverlay(self)
	local DebugData = self._spawnDebugData
	if not DebugData then
		return
	end

	local Snake = GetModule("snake")
	if not (Snake and Snake.IsDeveloperAssistEnabled and Snake:IsDeveloperAssistEnabled()) then
		return
	end

	local function DrawCells(cells, FillColor, OutlineColor)
		if not (cells and #cells > 0) then
			return
		end

		local TileSize = self.TileSize or 24
		local radius = math.min(8, TileSize * 0.35)

		if FillColor then
			love.graphics.setColor(FillColor[1], FillColor[2], FillColor[3], FillColor[4] or 0.22)
			for _, cell in ipairs(cells) do
				local col = NormalizeCellCoordinate(cell[1])
				local row = NormalizeCellCoordinate(cell[2])
				if col and row and col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
					local x, y = self:GetTilePosition(col, row)
					love.graphics.rectangle("fill", x, y, TileSize, TileSize, radius, radius)
				end
			end
		end

		if OutlineColor then
			love.graphics.setColor(OutlineColor[1], OutlineColor[2], OutlineColor[3], OutlineColor[4] or 0.4)
			for _, cell in ipairs(cells) do
				local col = NormalizeCellCoordinate(cell[1])
				local row = NormalizeCellCoordinate(cell[2])
				if col and row and col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
					local x, y = self:GetTilePosition(col, row)
					love.graphics.rectangle("line", x + 1, y + 1, TileSize - 2, TileSize - 2, radius, radius)
				end
			end
		end
	end

	love.graphics.push("all")
	love.graphics.setLineWidth(1.25)
	love.graphics.setBlendMode("alpha")

	DrawCells(DebugData.spawnSafeCells, {0.95, 0.34, 0.32, 0.24})
	DrawCells(DebugData.spawnBuffer, {1.0, 0.64, 0.26, 0.28})
	DrawCells(DebugData.safeZone, {0.22, 0.68, 1.0, 0.35}, {0.92, 0.98, 1.0, 0.75})
	DrawCells(DebugData.rockSafeZone, {0.64, 0.36, 0.88, 0.2})
	DrawCells(DebugData.reservedCells, nil, {1.0, 1.0, 1.0, 0.35})
	DrawCells(DebugData.reservedSpawnBuffer, nil, {1.0, 0.86, 0.38, 0.45})

	love.graphics.pop()
end

local function MixChannel(base, target, amount)
	return base + (target - base) * amount
end

local function IsTileInSafeZone(SafeZone, col, row)
	if not SafeZone then return false end

	for _, cell in ipairs(SafeZone) do
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
	TileSize = 24,
	cols = 0,
	rows = 0,
		exit = nil,
		ActiveBackgroundEffect = nil,
	BorderFlare = 0,
	BorderFlareStrength = 0,
	BorderFlareTimer = 0,
	BorderFlareDuration = 1.05,
}

function Arena:SetSpawnDebugData(data)
	if not data then
		self._spawnDebugData = nil
		return
	end

	self._spawnDebugData = {
		SafeZone = data.safeZone,
		RockSafeZone = data.rockSafeZone,
		SpawnBuffer = data.spawnBuffer,
		SpawnSafeCells = data.spawnSafeCells,
		ReservedCells = data.reservedCells,
		ReservedSafeZone = data.reservedSafeZone,
		ReservedSpawnBuffer = data.reservedSpawnBuffer,
	}
end

function Arena:ClearSpawnDebugData()
	self._spawnDebugData = nil
end

function Arena:UpdateScreenBounds(sw, sh)
	self.x = math.floor((sw - self.width) / 2)
	self.y = math.floor((sh - self.height) / 2)

	-- snap x,y to nearest tile boundary so centers align
	self.x = self.x - (self.x % self.TileSize)
	self.y = self.y - (self.y % self.TileSize)

	self.cols = math.floor(self.width / self.TileSize)
	self.rows = math.floor(self.height / self.TileSize)
end

function Arena:GetTilePosition(col, row)
	return self.x + (col - 1) * self.TileSize,
			self.y + (row - 1) * self.TileSize
end

function Arena:GetCenterOfTile(col, row)
	local x, y = self:GetTilePosition(col, row)
	return x + self.TileSize / 2, y + self.TileSize / 2
end

function Arena:GetTileFromWorld(x, y)
	local col = math.floor((x - self.x) / self.TileSize) + 1
	local row = math.floor((y - self.y) / self.TileSize) + 1

	-- clamp inside arena grid
	col = math.max(1, math.min(self.cols, col))
	row = math.max(1, math.min(self.rows, row))

	return col, row
end

function Arena:IsInside(x, y)
	local inset = self.TileSize / 2

	return x >= (self.x + inset) and
			x <= (self.x + self.width  - inset) and
			y >= (self.y + inset) and
			y <= (self.y + self.height - inset)
end

function Arena:GetRandomTile()
	local col = love.math.random(2, self.cols - 1)
	local row = love.math.random(2, self.rows - 1)
	return col, row
end

function Arena:GetBounds()
	return self.x, self.y, self.width, self.height
end

function Arena:SetBackgroundEffect(EffectData, palette)
	local EffectType
	local overrides

	if type(EffectData) == "string" then
		EffectType = EffectData
	elseif type(EffectData) == "table" then
		EffectType = EffectData.type or EffectData.name
		overrides = EffectData
	end

	self._backgroundEffects = self._backgroundEffects or {}

	if not EffectType or not Shaders.has(EffectType) then
		self.ActiveBackgroundEffect = nil
		return
	end

	local effect = Shaders.ensure(self._backgroundEffects, EffectType)
	if not effect then
		self.ActiveBackgroundEffect = nil
		return
	end

	local DefaultBackdrop, DefaultArena = Shaders.GetDefaultIntensities(effect)

	effect.backdropIntensity = DefaultBackdrop
	effect.arenaIntensity = DefaultArena

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

	self.ActiveBackgroundEffect = effect
end

function Arena:DrawBackgroundEffect(x, y, w, h, intensity)
	local effect = self.ActiveBackgroundEffect
	if not effect then
		return false
	end

	local DrawIntensity = intensity or effect.backdropIntensity or select(1, Shaders.GetDefaultIntensities(effect))
	return Shaders.draw(effect, x, y, w, h, DrawIntensity)
end

function Arena:DrawBackdrop(sw, sh)
	love.graphics.setColor(Theme.BgColor)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	local drawn = false
	local effect = self.ActiveBackgroundEffect
	if effect then
		local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
		local intensity = effect.backdropIntensity or DefaultBackdrop
		drawn = Shaders.draw(effect, 0, 0, sw, sh, intensity) or false
	end

	love.graphics.setColor(1, 1, 1, 1)
	return drawn
end

-- Draws the playfield with a solid fill + simple border
function Arena:DrawBackground()
	local ax, ay, aw, ah = self:GetBounds()

	if self.ActiveBackgroundEffect then
		local DefaultBackdrop, DefaultArena = Shaders.GetDefaultIntensities(self.ActiveBackgroundEffect)
		local intensity = self.ActiveBackgroundEffect.ArenaIntensity or DefaultArena
		Shaders.draw(self.ActiveBackgroundEffect, ax, ay, aw, ah, intensity)
	end

	-- Solid fill (rendered on top of shader-driven effects so gameplay remains clear)
	love.graphics.setColor(Theme.ArenaBG)
	love.graphics.rectangle("fill", ax, ay, aw, ah)

	DrawSpawnDebugOverlay(self)

	love.graphics.setColor(1, 1, 1, 1)
end

-- Draws border
function Arena:DrawBorder()
	local ax, ay, aw, ah = self:GetBounds()

	-- Match snake style
	local thickness    = 20       -- border thickness
	local OutlineSize  = 6        -- black outline thickness
	local ShadowOffset = 3
	local radius       = thickness / 2

	-- Expand the border rect outward so it doesn’t bleed inside
	local correction = (thickness / 2) + 3   -- negative = pull inward, positive = push outward
	local ox = correction
	local oy = correction
	local bx, by = ax - ox, ay - oy
	local bw, bh = aw + ox * 2, ah + oy * 2

	local BorderFlare = math.max(0, math.min(1.2, self.BorderFlare or 0))
	local FlarePulse = 0
	if BorderFlare > 0 then
		FlarePulse = (math.sin((self.BorderFlareTimer or 0) * 9.0) + 1) * 0.5
	end

	-- Create/reuse MSAA canvas
	if not self.BorderCanvas or
		self.BorderCanvas:GetWidth() ~= love.graphics.getWidth() or
		self.BorderCanvas:GetHeight() ~= love.graphics.getHeight() then
		self.BorderCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {msaa = 8})
	end

	love.graphics.setCanvas(self.BorderCanvas)
	love.graphics.clear(0,0,0,0)

	love.graphics.setLineStyle("smooth")

	-- Outline pass
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.setLineWidth(thickness + OutlineSize)
	love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

	-- Fill (arena border color)
	local BorderColor = Theme.ArenaBorder
	if BorderFlare > 0 and BorderColor then
		local MixAmount = math.min(0.45, 0.32 * BorderFlare + 0.18 * FlarePulse * BorderFlare)
		local r = MixChannel(BorderColor[1] or 1, 0.96, MixAmount)
		local g = MixChannel(BorderColor[2] or 1, 0.24, MixAmount * 1.05)
		local b = MixChannel(BorderColor[3] or 1, 0.18, MixAmount * 1.1)
		love.graphics.setColor(r, g, b, BorderColor[4] or 1)
	else
		if BorderColor then
			love.graphics.setColor(BorderColor)
		else
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
	love.graphics.setLineWidth(thickness)
	love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

	-- Highlight pass for the top + left edges
	local HighlightShift = 3
	local function AppendArcPoints(points, cx, cy, radius, StartAngle, EndAngle, segments, SkipFirst)
		if segments < 1 then
			segments = 1
		end

		for i = 0, segments do
			if not (SkipFirst and i == 0) then
				local t = i / segments
				local angle = StartAngle + (EndAngle - StartAngle) * t
				points[#points + 1] = cx + math.cos(angle) * radius - HighlightShift
				points[#points + 1] = cy + math.sin(angle) * radius - HighlightShift
			end
		end
	end

	local highlight = GetHighlightColor(Theme.ArenaBorder)
	-- Disable the glossy highlight along the top-left edge.
	highlight[4] = 0
	if BorderFlare > 0 then
		-- Ease the flare towards a softer pastel tint instead of a harsh glow.
		-- This keeps the pickup celebration visible while avoiding a sharp contrast.
		highlight[1] = math.min(1, MixChannel(highlight[1], 0.97, 0.35 * BorderFlare))
		highlight[2] = math.max(0, MixChannel(highlight[2], 0.3, 0.48 * BorderFlare))
		highlight[3] = math.max(0, MixChannel(highlight[3], 0.25, 0.52 * BorderFlare))
		highlight[4] = math.min(1, highlight[4] * (1 + 0.45 * BorderFlare))
	end

	local HighlightAlpha = highlight[4] or 0
	local HighlightOffset = 2
	if HighlightAlpha > 0 then
		local HighlightWidth = math.max(1.5, thickness * (0.26 + 0.12 * BorderFlare))
		local CornerOffsetX = 3
		local CornerOffsetY = 3
		local ScissorX = math.floor(bx - HighlightWidth - HighlightOffset - HighlightShift)
		local ScissorY = math.floor(by - HighlightWidth - HighlightOffset - HighlightShift)
		local ScissorW = math.ceil(bw + HighlightWidth * 2 + HighlightOffset + HighlightShift * 2)
		local ScissorH = math.ceil(bh + HighlightWidth * 2 + HighlightOffset + HighlightShift * 2)
		local OuterRadius = radius + HighlightOffset
		local ArcSegments = math.max(6, math.floor(OuterRadius * 0.75))

		local TopPoints = {}
		TopPoints[#TopPoints + 1] = bx + bw - radius - HighlightShift
		TopPoints[#TopPoints + 1] = by - HighlightOffset - HighlightShift
		TopPoints[#TopPoints + 1] = bx + radius - HighlightShift
		TopPoints[#TopPoints + 1] = by - HighlightOffset - HighlightShift
		local CornerStartIndex = #TopPoints + 1
		AppendArcPoints(TopPoints, bx + radius - HighlightShift, by + radius - HighlightShift, OuterRadius, -math.pi / 2, -math.pi, ArcSegments, true)
		for i = CornerStartIndex, #TopPoints, 2 do
			TopPoints[i] = TopPoints[i] + CornerOffsetX
			TopPoints[i + 1] = TopPoints[i + 1] + CornerOffsetY
		end

		local LeftPoints = {}
		LeftPoints[#LeftPoints + 1] = bx - HighlightOffset - HighlightShift
		LeftPoints[#LeftPoints + 1] = by + radius - HighlightShift
		LeftPoints[#LeftPoints + 1] = bx - HighlightOffset - HighlightShift
		LeftPoints[#LeftPoints + 1] = by + bh - radius - HighlightShift

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], HighlightAlpha)
		local PrevLineWidth = love.graphics.getLineWidth()
		local PrevLineStyle = love.graphics.getLineStyle()
		local PrevLineJoin = love.graphics.getLineJoin()
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineJoin("bevel")
		love.graphics.setLineWidth(HighlightWidth)

		-- Top edge highlight
		love.graphics.setScissor(ScissorX, ScissorY, ScissorW, math.ceil(HighlightWidth * 2.4 + CornerOffsetY))
		love.graphics.line(TopPoints)

		-- Left edge highlight
		love.graphics.setScissor(ScissorX, ScissorY, math.ceil(HighlightWidth * 2.4), ScissorH)
		love.graphics.line(LeftPoints)

		love.graphics.setScissor()
		love.graphics.setLineWidth(PrevLineWidth)
		love.graphics.setLineStyle(PrevLineStyle)
		love.graphics.setLineJoin(PrevLineJoin)
	end

	if BorderFlare > 0.01 then
		local GlowStrength = BorderFlare
		local GlowAlpha = 0.28 * GlowStrength + 0.16 * FlarePulse * GlowStrength
		local EmberAlpha = 0.18 * GlowStrength

		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		love.graphics.setLineWidth(thickness + OutlineSize * (1.05 + 0.25 * GlowStrength))
		love.graphics.setColor(0.96, 0.32, 0.24, GlowAlpha)
		love.graphics.rectangle("line", bx, by, bw, bh, radius + 4 + GlowStrength * 3.0, radius + 4 + GlowStrength * 3.0)
		love.graphics.setLineWidth(math.max(2, thickness * 0.55))
		love.graphics.setColor(0.55, 0.08, 0.06, EmberAlpha)
		love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)
		love.graphics.pop()
	end

	-- Soft caps for highlight ends
	local TopCapX = bx + bw - radius - HighlightShift
	local TopCapY = by - HighlightOffset - HighlightShift
	local LeftCapX = bx - HighlightOffset - HighlightShift
	local LeftCapY = by + bh - radius - HighlightShift

	if HighlightAlpha > 0 then
		local HighlightWidth = math.max(1.5, thickness * (0.26 + 0.12 * BorderFlare))
		local CapRadius = HighlightWidth * 0.7
		local FeatherRadius = CapRadius * (1.9 + 0.35 * BorderFlare)
		local CapAlpha = HighlightAlpha * (0.4 + 0.22 * BorderFlare)
		local FeatherAlpha = HighlightAlpha * (0.18 + 0.16 * BorderFlare)

		local function DrawHighlightCap(cx, cy)
			if CapAlpha > 0 then
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], CapAlpha)
				love.graphics.circle("fill", cx, cy, CapRadius)
			end

			if FeatherAlpha > 0 then
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], FeatherAlpha)
				love.graphics.circle("fill", cx, cy, FeatherRadius)
			end
		end

		DrawHighlightCap(TopCapX, TopCapY)
		DrawHighlightCap(LeftCapX, LeftCapY)

		love.graphics.setColor(highlight[1], highlight[2], highlight[3], HighlightAlpha)
	end

	love.graphics.setCanvas()

	-- Shadow pass
	love.graphics.setColor(0, 0, 0, 0.25)
	love.graphics.draw(self.BorderCanvas, ShadowOffset, ShadowOffset)

	-- Final draw
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.BorderCanvas, 0, 0)
end

-- Spawn an exit at a random valid tile
function Arena:SpawnExit()
	if self.exit then return end

	local SnakeUtils = GetModule("snakeutils")
	local Fruit = GetModule("fruit")
	local FruitCol, FruitRow = nil, nil
	if Fruit and Fruit.GetTile then
		FruitCol, FruitRow = Fruit:GetTile()
	end

	local Rocks = GetModule("rocks")
	local RockList = (Rocks and Rocks.GetAll and Rocks:GetAll()) or {}

	local Snake = GetModule("snake")
	local SnakeSegments = nil
	local SnakeSafeZone = nil
	local HeadX, HeadY = nil, nil
	if Snake then
		if Snake.GetSegments then
			SnakeSegments = Snake:GetSegments()
		end
		if Snake.GetSafeZone then
			SnakeSafeZone = Snake:GetSafeZone(3)
		end
		if Snake.GetHead then
			HeadX, HeadY = Snake:GetHead()
		end
	end

	local threshold = (SnakeUtils and SnakeUtils.SEGMENT_SIZE) or self.TileSize
	local HalfThreshold = threshold * 0.5
	local MinHeadDistance = self.TileSize * MIN_HEAD_DISTANCE_TILES
	local MinHeadDistanceSq = MinHeadDistance * MinHeadDistance

	local function TileIsSafe(col, row)
		local cx, cy = self:GetCenterOfTile(col, row)

		if SnakeUtils and SnakeUtils.IsOccupied and SnakeUtils.IsOccupied(col, row) then
			return false
		end

		if FruitCol and FruitRow and FruitCol == col and FruitRow == row then
			return false
		end

		for _, rock in ipairs(RockList) do
			local rcol, rrow = self:GetTileFromWorld(rock.x or cx, rock.y or cy)
			if rcol == col and rrow == row then
				return false
			end
		end

		if SnakeSafeZone and IsTileInSafeZone(SnakeSafeZone, col, row) then
			return false
		end

		if SnakeSegments then
			for _, seg in ipairs(SnakeSegments) do
				local dx = math.abs((seg.drawX or 0) - cx)
				local dy = math.abs((seg.drawY or 0) - cy)
				if dx < HalfThreshold and dy < HalfThreshold then
					return false
				end
			end
		end

		if HeadX and HeadY then
			if DistanceSquared(cx, cy, HeadX, HeadY) < MinHeadDistanceSq then
				return false
			end
		end

		return true
	end

	local ChosenCol, ChosenRow
	for _ = 1, EXIT_SAFE_ATTEMPTS do
		local col, row = self:GetRandomTile()
		if TileIsSafe(col, row) then
			ChosenCol, ChosenRow = col, row
			break
		end
	end

	if not (ChosenCol and ChosenRow) then
		for row = 2, self.rows - 1 do
			for col = 2, self.cols - 1 do
				if TileIsSafe(col, row) then
					ChosenCol, ChosenRow = col, row
					break
				end
			end
			if ChosenCol then break end
		end
	end

	ChosenCol = ChosenCol or math.floor(self.cols / 2)
	ChosenRow = ChosenRow or math.floor(self.rows / 2)

	if SnakeUtils and SnakeUtils.SetOccupied then
		SnakeUtils.SetOccupied(ChosenCol, ChosenRow, true)
	end

	local x, y = self:GetCenterOfTile(ChosenCol, ChosenRow)
	local size = self.TileSize * 0.75
	self.exit = {
		x = x, y = y,
		size = size,
		anim = 0,                -- 0 = closed, 1 = fully open
		AnimTime = 0.4,          -- seconds to open
		col = ChosenCol,
		row = ChosenRow,
		time = 0,
	}
	Audio:PlaySound("exit_spawn")
end

function Arena:GetExitCenter()
	if not self.exit then return nil, nil, 0 end
	local r = self.exit.size * 0.5
	return self.exit.x, self.exit.y, r
end

function Arena:HasExit()
	return self.exit ~= nil
end

function Arena:update(dt)
	if dt and dt > 0 then
		local BaseStrength = self.BorderFlareStrength

		if not (BaseStrength and BaseStrength > 0) then
			BaseStrength = self.BorderFlare or 0
			if BaseStrength > 0 then
				self.BorderFlareStrength = BaseStrength
			end
		end

		if BaseStrength and BaseStrength > 0 then
			local duration = math.max(0.35, self.BorderFlareDuration or 1.05)
			local timer = math.min(duration, (self.BorderFlareTimer or 0) + dt)
			local progress = math.min(1, timer / duration)
			local fade = 1 - (progress * progress * (3 - 2 * progress))

			self.BorderFlare = math.max(0, BaseStrength * fade)
			self.BorderFlareTimer = timer

			if progress >= 1 then
				self.BorderFlare = 0
				self.BorderFlareStrength = 0
				self.BorderFlareTimer = 0
			end
		else
			self.BorderFlare = 0
			self.BorderFlareStrength = 0
			self.BorderFlareTimer = 0
		end
	end

	if not self.exit then
		return
	end

	if self.exit.anim < 1 then
		self.exit.anim = math.min(1, self.exit.anim + dt / self.exit.AnimTime)
	end

	self.exit.time = (self.exit.time or 0) + dt
end

-- Reset/clear exit when moving to next floor
function Arena:ResetExit()
	if self.exit then
		local SnakeUtils = GetModule("snakeutils")
		if SnakeUtils and SnakeUtils.SetOccupied and self.exit.col and self.exit.row then
			SnakeUtils.SetOccupied(self.exit.col, self.exit.row, false)
		end
	end

	self.exit = nil
end

-- Check if snake head collides with the exit
function Arena:CheckExitCollision(SnakeX, SnakeY)
	if not self.exit then return false end
	local dx, dy = SnakeX - self.exit.x, SnakeY - self.exit.y
	local DistSq = dx * dx + dy * dy
	local r = self.exit.size * 0.5
	return DistSq <= (r * r)
end

-- Draw the exit (if active)
function Arena:DrawExit()
	if not self.exit then return end

	local exit = self.exit
	local t = exit.anim
	local eased = 1 - (1 - t) * (1 - t)
	local radius = (exit.size / 1.5) * eased
	local cx, cy = exit.x, exit.y
	local time = exit.time or 0

	local RimRadius = radius * (1.05 + 0.03 * math.sin(time * 1.3))
	love.graphics.setColor(0.16, 0.15, 0.19, 1)
	love.graphics.circle("fill", cx, cy, RimRadius, 48)

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

function Arena:TriggerBorderFlare(strength, duration)
	local amount = math.max(0, strength or 0)
	if amount <= 0 then
		return
	end

	local existing = self.BorderFlare or 0
	local NewStrength = math.min(1.2, existing + amount)
	self.BorderFlare = NewStrength
	self.BorderFlareStrength = NewStrength
	self.BorderFlareTimer = 0

	if duration and duration > 0 then
		self.BorderFlareDuration = duration
	elseif not self.BorderFlareDuration or self.BorderFlareDuration <= 0 then
		self.BorderFlareDuration = 1.05
	end
end

return Arena
