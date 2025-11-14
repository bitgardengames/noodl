local Particles = require("particles")
local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Audio = require("audio")
local RenderLayers = require("renderlayers")
local Easing = require("easing")
local Timer = require("timer")

local max = math.max
local min = math.min
local pi = math.pi
local insert = table.insert
local sin = math.sin
local abs = math.abs

local rockRng = love.math.newRandomGenerator()
local nearbyScratch = {}

local function clearArray(array)
	for i = #array, 1, -1 do
		array[i] = nil
	end
end

local Rocks = {}
local current = {}
local rockLookup = {}
local lookupHasEntries = false
local revision = 0

local function bumpRevision()
	revision = revision + 1
end

Rocks.spawnChance = 0.25
Rocks.shatterOnFruit = 0
Rocks.shatterProgress = 0

local Color = require("color")

local ROCK_SIZE = 24
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SHADOW_OFFSET = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}

local function generateRockShape(size, seed)
	rockRng:setSeed(seed or Timer.getTime() * 1000)
	local points = {}
	local sides = rockRng:random(12, 16) -- more segments = rounder
	local step = (pi * 2) / sides
	local baseRadius = size * 0.45

	for i = 1, sides do
		local angle = step * i
		-- slight wobble so it’s lumpy, but no sharp spikes
		local r = baseRadius * (0.9 + rockRng:random() * 0.2)
		insert(points, math.cos(angle) * r)
		insert(points, math.sin(angle) * r)
	end

	return points
end

local function copyColor(color)
        return Color.copy(color, {default = Color.white})
end

local highlightCache = setmetatable({}, { __mode = "k" })
local highlightDefault = {1, 1, 1, 1}

local function updateHighlightColor(out, color)
	local baseR = color[1] or 1
	local baseG = color[2] or 1
	local baseB = color[3] or 1
	local baseA = color[4]
	if baseA == nil then
		baseA = 1
	end

	local r = min(1, baseR * 1.2 + 0.08)
	local g = min(1, baseG * 1.2 + 0.08)
	local b = min(1, baseB * 1.2 + 0.08)
	local a = baseA * 0.75
	out[1], out[2], out[3], out[4] = r, g, b, a
	return out
end

local function getHighlightColor(color)
	color = color or highlightDefault
	local cached = highlightCache[color]
	if not cached then
		cached = {
			highlight = {0, 0, 0, 0},
			_lastR = nil,
			_lastG = nil,
			_lastB = nil,
			_lastA = nil,
		}
		highlightCache[color] = cached
	end

	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4]
	if a == nil then
		a = 1
	end

	if cached._lastR == r and cached._lastG == g and cached._lastB == b and cached._lastA == a then
		return cached.highlight
	end

	cached._lastR, cached._lastG, cached._lastB, cached._lastA = r, g, b, a
	updateHighlightColor(cached.highlight, color)
	return cached.highlight
end

local function buildRockHighlight(points)
	if not points then return nil end

	local highlight = {}
	local scaleX, scaleY = 0.78, 0.66
	local offsetX, offsetY = -ROCK_SIZE * 0.12 + 2, -ROCK_SIZE * 0.18 + 2

	for i = 1, #points, 2 do
		local x = points[i] * scaleX + offsetX
		local y = points[i + 1] * scaleY + offsetY
		highlight[#highlight + 1] = x
		highlight[#highlight + 1] = y
	end

	local inset = 2
	if inset > 0 then
		local count = #highlight / 2
		if count <= 0 then
			return highlight
		end

		local cx, cy = 0, 0

		for i = 1, #highlight, 2 do
			cx = cx + highlight[i]
			cy = cy + highlight[i + 1]
		end

		cx = cx / count
		cy = cy / count

		for i = 1, #highlight, 2 do
			local x = highlight[i]
			local y = highlight[i + 1]
			local dx = x - cx
			local dy = y - cy
			local len = math.sqrt(dx * dx + dy * dy)

			if len > 0 then
				local scale = max(0, (len - inset) / len)
				highlight[i] = cx + dx * scale
				highlight[i + 1] = cy + dy * scale
			end
		end
	end

	return highlight
end

local function getUpgradesModule()
	return package.loaded["upgrades"]
end

local function ensureLookupEntry(rock, col, row)
	if not (rock and col and row) then
		return
	end

	local column = rockLookup[col]
	if not column then
		column = {}
		rockLookup[col] = column
	end

	column[row] = rock
	lookupHasEntries = true
end

local function removeLookupEntry(rock)
	if not rock then
		return
	end

	local col, row = rock.col, rock.row
	if not (col and row) then
		return
	end

	local column = rockLookup[col]
	if not column then
		return
	end

	if column[row] == rock then
		column[row] = nil

		if not next(column) then
			rockLookup[col] = nil
		end

		if not next(rockLookup) then
			lookupHasEntries = false
		end
	end
end

function Rocks:spawn(x, y)
	local col, row = Arena:getTileFromWorld(x, y)
	insert(current, {
		x = x,
		y = y,
		w = ROCK_SIZE,
		h = ROCK_SIZE,
		timer = 0,
		phase = "drop",
		scaleX = 1,
		scaleY = 0,
		offsetY = -40,
		shape = nil,
		col = col,
		row = row,
	})
	local rock = current[#current]
	rock.shape = generateRockShape(ROCK_SIZE, love.math.random(1, 999999))
	rock.highlightShape = buildRockHighlight(rock.shape)

	ensureLookupEntry(rock, col, row)
	bumpRevision()
end

function Rocks:getAll()
	return current
end

local function releaseOccupancy(rock)
	if not rock then return end
	removeLookupEntry(rock)
	local col, row = rock.col, rock.row
	if not col or not row then
		col, row = Arena:getTileFromWorld(rock.x or 0, rock.y or 0)
	end
	if col and row then
		SnakeUtils.setOccupied(col, row, false)
	end
end

function Rocks:reset()
	for _, rock in ipairs(current) do
		releaseOccupancy(rock)
	end
	current = {}
	rockLookup = {}
	lookupHasEntries = false
	self.spawnChance = 0.25
	self.shatterOnFruit = 0
	self.shatterProgress = 0
	bumpRevision()
end

local function spawnShatterFX(x, y)
	local rockColor = Theme.rock or {0.85, 0.75, 0.6, 1}
	local primary = copyColor(rockColor)
	primary[4] = 1
	local highlight = getHighlightColor(rockColor)

	Particles:spawnBurst(x, y, {
		count = love.math.random(8, 12),
		speed = 72,
		speedVariance = 58,
		life = 0.45,
		size = 3.8,
		color = primary,
		spread = pi * 2,
		angleJitter = pi * 0.9,
		drag = 3.1,
		gravity = 240,
		scaleMin = 0.54,
		scaleVariance = 0.72,
		fadeTo = 0.06,
	})

	Particles:spawnBurst(x, y, {
		count = love.math.random(3, 5),
		speed = 112,
		speedVariance = 60,
		life = 0.32,
		size = 2.4,
		color = highlight,
		spread = pi * 2,
		angleJitter = pi,
		drag = 1.5,
		gravity = 190,
		scaleMin = 0.38,
		scaleVariance = 0.3,
		fadeTo = 0,
	})
end

local function removeRockAt(index, spawnFX)
	if not index then return nil end

	local rock = table.remove(current, index)
	if not rock then return nil end

	releaseOccupancy(rock)

	if spawnFX ~= false then
		spawnShatterFX(rock.x, rock.y)
	end

	return rock
end

function Rocks:updateCell(rock, col, row)
	if not rock then
		return
	end

	removeLookupEntry(rock)

	rock.col = col
	rock.row = row

	ensureLookupEntry(rock, col, row)
	bumpRevision()
end

function Rocks:hasCellLookup()
	return lookupHasEntries
end

function Rocks:getNearby(col, row, radius)
	local results = nearbyScratch
	clearArray(results)

	if not (col and row) then
		return results
	end

	radius = radius or 1

	if not lookupHasEntries then
		for _, rock in ipairs(current) do
			local rockCol, rockRow = rock.col, rock.row
			if rockCol and rockRow then
				if abs(rockCol - col) <= radius and abs(rockRow - row) <= radius then
					results[#results + 1] = rock
				end
			end
		end
		return results
	end

	for c = col - radius, col + radius do
		local column = rockLookup[c]
		if column then
			for r = row - radius, row + radius do
				local rock = column[r]
				if rock then
					results[#results + 1] = rock
				end
			end
		end
	end

	-- NOTE: this table is reused internally; treat it as a transient buffer.
	return results
end

function Rocks:destroy(target, opts)
	if not target then return end

	opts = opts or {}
	local spawnFX = opts.spawnFX
	if spawnFX == nil then
		spawnFX = true
	end

	for index, rock in ipairs(current) do
		if rock == target then
			local removed = removeRockAt(index, spawnFX)
			if removed then
				bumpRevision()
			end
			return
		end
	end
end

function Rocks:triggerHitFlash(target)
	if not target then
		return
	end

	target.hitFlashTimer = max(target.hitFlashTimer or 0, HIT_FLASH_DURATION)
end

function Rocks:shatterNearest(x, y, count)
	count = count or 1
	if count <= 0 or #current == 0 then return end

	for _ = 1, count do
		if #current == 0 then break end

		local bestIndex, bestDist = nil, math.huge
		for i, rock in ipairs(current) do
			local phase = rock.phase
			if not phase or phase == "done" then
				local dx = (rock.x or x) - x
				local dy = (rock.y or y) - y
				local dist = dx * dx + dy * dy
				if dist < bestDist then
					bestDist = dist
					bestIndex = i
				end
			end
		end

		if not bestIndex then break end

		local shattered = removeRockAt(bestIndex, true)
		if shattered then
			bumpRevision()
			Audio:playSound("rock_shatter")

			local Upgrades = getUpgradesModule()
			if Upgrades and Upgrades.notify then
				local fx = shattered.x or x
				local fy = shattered.y or y
				Upgrades:notify("rockShattered", {
					x = fx,
					y = fy,
					sourceX = x,
					sourceY = y,
					rock = shattered,
				})
			end
		end
	end
end

function Rocks:onFruitCollected(x, y)
	local rate = self.shatterOnFruit or 0
	if rate <= 0 then
		self.shatterProgress = 0
		return
	end

	self.shatterProgress = (self.shatterProgress or 0) + rate
	local count = math.floor(self.shatterProgress or 0)
	if count <= 0 then return end

	self.shatterProgress = (self.shatterProgress or 0) - count
	if self.shatterProgress < 0 then
		self.shatterProgress = 0
	end

	self:shatterNearest(x or 0, y or 0, count)
end

local function updateTremorSlide(rock, dt)
	local duration = rock.tremorSlideDuration
	if not (duration and duration > 0) then
		return
	end

	local timer = (rock.tremorSlideTimer or 0) + (dt or 0)
	if timer >= duration then
		timer = duration
	end

	rock.tremorSlideTimer = timer

	local progress = Easing.easeOutCubic(Easing.clamp01(timer / duration))
	local startX = rock.tremorSlideStartX or rock.x
	local startY = rock.tremorSlideStartY or rock.y
	local targetX = rock.tremorSlideTargetX or rock.x
	local targetY = rock.tremorSlideTargetY or rock.y

	rock.renderX = Easing.lerp(startX, targetX, progress)
	rock.renderY = Easing.lerp(startY, targetY, progress)

	local lift = rock.tremorSlideLift or 0
	if lift ~= 0 then
		rock.tremorSlideOffset = -sin(progress * pi) * lift
	else
		rock.tremorSlideOffset = nil
	end

	if timer >= duration then
		rock.tremorSlideTimer = nil
		rock.tremorSlideDuration = nil
		rock.tremorSlideStartX = nil
		rock.tremorSlideStartY = nil
		rock.tremorSlideTargetX = nil
		rock.tremorSlideTargetY = nil
		rock.tremorSlideLift = nil
		rock.tremorSlideOffset = nil
		rock.renderX = nil
		rock.renderY = nil
	end
end

function Rocks:update(dt)
	for _, rock in ipairs(current) do
		rock.timer = rock.timer + dt

		updateTremorSlide(rock, dt)

		if rock.hitFlashTimer and rock.hitFlashTimer > 0 then
			rock.hitFlashTimer = max(0, rock.hitFlashTimer - dt)
		end

		if rock.phase == "drop" then
			local progress = min(rock.timer / SPAWN_DURATION, 1)
			rock.offsetY = -40 * (1 - progress)
			rock.scaleY = progress
			rock.scaleX = progress

			if progress >= 1 then
				rock.phase = "squash"
				rock.timer = 0
				Particles:spawnBurst(rock.x, rock.y, {
					count = love.math.random(6, 10),
					speed = 40,
					speedVariance = 34,
					life = 0.4,
					size = 3,
					color = {0.6, 0.5, 0.4, 1},
					spread = pi * 2,
					angleJitter = pi * 0.85,
					drag = 2.2,
					gravity = 160,
					scaleMin = 0.6,
					scaleVariance = 0.5,
					fadeTo = 0.1,
				})
			end

		elseif rock.phase == "squash" then
			local progress = min(rock.timer / SQUASH_DURATION, 1)
			rock.scaleX = 1 + 0.3 * (1 - progress)
			rock.scaleY = 1 - 0.3 * (1 - progress)
			rock.offsetY = 0

			if progress >= 1 then
				rock.phase = "done"
				rock.scaleX = 1
				rock.scaleY = 1
				rock.offsetY = 0
			end
		end
	end
end

local function withRockTransform(rock, fn)
	love.graphics.push()

	local drawX = rock.renderX or rock.x
	local drawY = rock.renderY or rock.y
	local offsetY = (rock.offsetY or 0) + (rock.tremorSlideOffset or 0)

	love.graphics.translate(drawX, drawY + offsetY)
	love.graphics.scale(rock.scaleX, rock.scaleY)
	fn()
	love.graphics.pop()
end

local function drawRockShadow(rock)
	withRockTransform(rock, function()
		love.graphics.setColor(0, 0, 0, 0.4)
		love.graphics.push()
		love.graphics.translate(SHADOW_OFFSET, SHADOW_OFFSET)
		love.graphics.scale(1.1, 1.1)
		love.graphics.polygon("fill", rock.shape)
		love.graphics.pop()
	end)
end

local function drawRockBody(rock)
	withRockTransform(rock, function()
		local baseColor = Theme.rock
		if rock.hitFlashTimer and rock.hitFlashTimer > 0 then
			baseColor = HIT_FLASH_COLOR
		end

		love.graphics.setColor(baseColor)
		love.graphics.polygon("fill", rock.shape)

		if rock.highlightShape then
			local highlight = getHighlightColor(baseColor)
			love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
			love.graphics.polygon("fill", rock.highlightShape)
		end

		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.setLineWidth(3)
		love.graphics.polygon("line", rock.shape)
	end)
end

function Rocks:draw()
	if #current == 0 then
		return
	end

	RenderLayers:withLayer("shadows", function()
		for _, rock in ipairs(current) do
			drawRockShadow(rock)
		end
	end)

	RenderLayers:withLayer("main", function()
		for _, rock in ipairs(current) do
			drawRockBody(rock)
		end
	end)
end

function Rocks:getSpawnChance()
	return self.spawnChance or 0.25
end

function Rocks:beginSlide(rock, startX, startY, targetX, targetY, options)
	if not rock then
		return
	end

	options = options or {}
	rock.tremorSlideDuration = options.duration or 0.28
	rock.tremorSlideTimer = 0
	rock.tremorSlideStartX = startX or rock.x
	rock.tremorSlideStartY = startY or rock.y
	rock.tremorSlideTargetX = targetX or rock.x
	rock.tremorSlideTargetY = targetY or rock.y
	rock.tremorSlideLift = options.lift or 10
	rock.renderX = rock.tremorSlideStartX
	rock.renderY = rock.tremorSlideStartY
end

function Rocks:getRevision()
	return revision
end

return Rocks