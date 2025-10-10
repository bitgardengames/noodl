local Particles = require("particles")
local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Audio = require("audio")

local Rocks = {}
local current = {}

Rocks.spawnChance = 0.25
Rocks.shatterOnFruit = 0
Rocks.shatterProgress = 0

local ROCK_SIZE = 24
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SHADOW_OFFSET = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}

-- smoother, rounder “stone” generator
local function generateRockShape(size, seed)
	local rng
	if seed then
		rng = love.math.newRandomGenerator(seed)
	else
		rng = love.math.newRandomGenerator(love.timer.getTime() * 1000)
	end

	local points = {}
	local sides = rng:random(12, 16) -- more segments = rounder
	local step = (math.pi * 2) / sides
	local baseRadius = size * 0.45

	for i = 1, sides do
		local angle = step * i
		-- slight wobble so it’s lumpy, but no sharp spikes
		local r = baseRadius * (0.9 + rng:random() * 0.2)
		table.insert(points, math.cos(angle) * r)
		table.insert(points, math.sin(angle) * r)
	end

	return points
end

local function copyColor(color)
	if not color then
		return { 1, 1, 1, 1 }
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
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
				local scale = math.max(0, (len - inset) / len)
				highlight[i] = cx + dx * scale
				highlight[i + 1] = cy + dy * scale
			end
		end
	end

	return highlight
end

function Rocks:spawn(x, y)
	local col, row = Arena:getTileFromWorld(x, y)
	table.insert(current, {
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
end

function Rocks:getAll()
	return current
end

local function releaseOccupancy(rock)
	if not rock then return end
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
	self.spawnChance = 0.25
	self.shatterOnFruit = 0
	self.shatterProgress = 0
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
		spread = math.pi * 2,
		angleJitter = math.pi * 0.9,
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
		spread = math.pi * 2,
		angleJitter = math.pi,
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
			removeRockAt(index, spawnFX)
			return
		end
	end
end

function Rocks:triggerHitFlash(target)
	if not target then
		return
	end

	target.hitFlashTimer = math.max(target.hitFlashTimer or 0, HIT_FLASH_DURATION)
end

function Rocks:shatterNearest(x, y, count)
	count = count or 1
	if count <= 0 or #current == 0 then return end

	for _ = 1, count do
		if #current == 0 then break end

		local bestIndex, bestDist = nil, math.huge
		for i, rock in ipairs(current) do
			local dx = (rock.x or x) - x
			local dy = (rock.y or y) - y
			local dist = dx * dx + dy * dy
			if dist < bestDist then
				bestDist = dist
				bestIndex = i
			end
		end

		if not bestIndex then break end

		removeRockAt(bestIndex, true)
		Audio:playSound("rock_shatter")
	end
end

function Rocks:addShatterOnFruit(count)
	if not count or count <= 0 then return end
	self.shatterOnFruit = (self.shatterOnFruit or 0) + count
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

function Rocks:getShatterProgress()
	return self.shatterProgress or 0
end

function Rocks:getShatterRate()
	return self.shatterOnFruit or 0
end

function Rocks:update(dt)
	for _, rock in ipairs(current) do
		rock.timer = rock.timer + dt

		if rock.hitFlashTimer and rock.hitFlashTimer > 0 then
			rock.hitFlashTimer = math.max(0, rock.hitFlashTimer - dt)
		end

		if rock.phase == "drop" then
			local progress = math.min(rock.timer / SPAWN_DURATION, 1)
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
					spread = math.pi * 2,
					angleJitter = math.pi * 0.85,
					drag = 2.2,
					gravity = 160,
					scaleMin = 0.6,
					scaleVariance = 0.5,
					fadeTo = 0.1,
				})
			end

		elseif rock.phase == "squash" then
			local progress = math.min(rock.timer / SQUASH_DURATION, 1)
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

function Rocks:draw()
	for _, rock in ipairs(current) do
		love.graphics.push()
		love.graphics.translate(rock.x, rock.y + rock.offsetY)
		love.graphics.scale(rock.scaleX, rock.scaleY)

		-- shadow (slightly offset behind rock, scaled up so it feels bigger than outline)
		love.graphics.setColor(0, 0, 0, 0.4)
		love.graphics.push()
		love.graphics.translate(SHADOW_OFFSET, SHADOW_OFFSET)
		love.graphics.scale(1.1, 1.1) -- make shadow a bit larger
		love.graphics.polygon("fill", rock.shape)
		love.graphics.pop()

		-- main rock fill
		local baseColor = Theme.rock
		if rock.hitFlashTimer and rock.hitFlashTimer > 0 then
			baseColor = HIT_FLASH_COLOR
		end

		love.graphics.setColor(baseColor)
		love.graphics.polygon("fill", rock.shape)

		-- highlight
		if rock.highlightShape then
			local highlight = getHighlightColor(baseColor)
			love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
			love.graphics.polygon("fill", rock.highlightShape)
		end

		-- outline
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.setLineWidth(3)
		love.graphics.polygon("line", rock.shape)

		love.graphics.pop()
	end
end

function Rocks:getSpawnChance()
	return self.spawnChance or 0.25
end

return Rocks
