local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Saws = require("saws")
local Particles = require("particles")

local min = math.min
local max = math.max
local floor = math.floor
local sin = math.sin
local pi = math.pi

local FUSE_DIR_X, FUSE_DIR_Y = 0, -1

local Bombs = {}

local bombs = {}

local FUSE_DURATION = 0.95
local PRE_FLASH_DURATION = 0.08
local EXPLOSION_DURATION = 0.32
local FADE_DURATION = 0.22
local SHOCK_DURATION = PRE_FLASH_DURATION + EXPLOSION_DURATION + FADE_DURATION
local EXPLOSION_RADIUS_TILES = 1.25
local SPARK_RATE = 22

local BASE_ORB_COLOR = {0.08, 0.08, 0.1, 1}
local FUSE_COLOR_A = {1.0, 0.92, 0.52, 1}
local FUSE_COLOR_B = {1.0, 0.76, 0.26, 1}
local FLICKER_COLOR = {0.45, 0.08, 0.12, 1}
local EXPLOSION_COLOR = {1.0, 0.42, 0.22, 0.4}
local EXPLOSION_EDGE_COLOR = {1.0, 0.64, 0.24, 0.7}
local SHOCK_COLOR = {1.0, 0.78, 0.36, 0.65}

local FUSE_SPARK_BURST = {
	count = 2,
	speed = 48,
	speedVariance = 14,
	life = 0.22,
	size = 1.6,
	spread = pi * 0.85,
	angle = -pi / 2,
	drag = 2.6,
	gravity = 90,
	color = FUSE_COLOR_A,
	fadeTo = 0.05,
}

local EXPLOSION_BURST_PRIMARY = {
	count = 12,
	speed = 160,
	speedVariance = 60,
	life = 0.32,
	size = 3.8,
	spread = pi * 2,
	drag = 4.2,
	gravity = 180,
	color = {1.0, 0.54, 0.28, 1.0},
	fadeTo = 0,
}

local EXPLOSION_BURST_SECONDARY = {
	count = 8,
	speed = 110,
	speedVariance = 40,
	life = 0.26,
	size = 2.4,
	spread = pi * 2,
	drag = 2.4,
	gravity = 90,
	color = {1.0, 0.84, 0.5, 0.85},
	fadeTo = 0,
}

local function getTileSize()
	return (Arena and Arena.tileSize) or SnakeUtils.SEGMENT_SIZE or 24
end

local function distanceSquared(ax, ay, bx, by)
	local dx = (ax or 0) - (bx or 0)
	local dy = (ay or 0) - (by or 0)
	return dx * dx + dy * dy
end

local function clamp01(value)
	if value <= 0 then return 0 end
	if value >= 1 then return 1 end
	return value
end

local function spawnFuseSparks(bomb)
	if not bomb then return end
	local tileSize = getTileSize()
	local fuseX = bomb.x + tileSize * 0.34
	local fuseY = bomb.y - tileSize * 0.55
	Particles:spawnBurst(fuseX, fuseY, FUSE_SPARK_BURST)
end

local function spawnExplosionFX(bomb, radius)
	if not bomb then return end
	local x, y = bomb.x, bomb.y
	Particles:spawnBurst(x, y, EXPLOSION_BURST_PRIMARY)
	Particles:spawnBurst(x, y, EXPLOSION_BURST_SECONDARY)
end

local function collectRocks(bomb, radius, hits)
	local col, row = bomb.col, bomb.row
	if not (col and row) then
		return
	end

	local tileRadius = max(1, floor(EXPLOSION_RADIUS_TILES + 0.5))
	local rocks = Rocks.getNearby and Rocks:getNearby(col, row, tileRadius)
	if not rocks then return end

	local radiusSq = radius * radius
	for _, rock in ipairs(rocks) do
		local rx, ry = rock.x, rock.y
		if rx and ry then
			if distanceSquared(rx, ry, bomb.x, bomb.y) <= radiusSq then
				Rocks:destroy(rock, {spawnFX = true})
				hits[#hits + 1] = {
					type = "rock",
					x = rx,
					y = ry,
					rock = rock,
				}
			end
		end
	end
end

local function collectSaws(bomb, radius, hits)
	local saws = Saws.getAll and Saws:getAll()
	if not saws then return end

	local radiusSq = radius * radius
	for _, saw in ipairs(saws) do
		local cx, cy = Saws.getCollisionCenter and Saws:getCollisionCenter(saw)
		if not (cx and cy) then
			cx, cy = saw and saw.x, saw and saw.y
		end

		if cx and cy then
			local sawRadius = (saw and saw.collisionRadius) or (getTileSize() * 0.55)
			local distSq = distanceSquared(cx, cy, bomb.x, bomb.y)
			if distSq <= (radius + sawRadius) * (radius + sawRadius) then
				Saws:destroy(saw)
				hits[#hits + 1] = {
					type = "saw",
					x = cx,
					y = cy,
					saw = saw,
				}
			end
		end
	end
end

local function handleExplosion(bomb)
	local tileSize = getTileSize()
	local radius = tileSize * EXPLOSION_RADIUS_TILES
	bomb.explosionRadius = radius

	local hits = {}
	collectRocks(bomb, radius, hits)
	collectSaws(bomb, radius, hits)

	if #hits > 0 then
		spawnExplosionFX(bomb, radius)
	end

	if Bombs._onExplosion then
		Bombs._onExplosion({
			x = bomb.x,
			y = bomb.y,
			col = bomb.col,
			row = bomb.row,
			hits = hits,
		})
	end
end

local function advanceBomb(bomb, dt)
	if bomb.state == "fuse" then
		bomb.timer = bomb.timer + dt
		bomb.sparkTimer = (bomb.sparkTimer or 0) + dt
		if bomb.sparkTimer >= 1 / SPARK_RATE then
			bomb.sparkTimer = bomb.sparkTimer - (1 / SPARK_RATE)
			spawnFuseSparks(bomb)
		end

		if bomb.timer >= FUSE_DURATION then
			bomb.timer = bomb.timer - FUSE_DURATION
			bomb.state = "preflash"
			bomb.flashTimer = PRE_FLASH_DURATION
			bomb.shockTimer = 0
			bomb.shockDuration = SHOCK_DURATION
		end
	elseif bomb.state == "preflash" then
		bomb.timer = bomb.timer + dt
		bomb.shockTimer = min((bomb.shockTimer or 0) + dt, bomb.shockDuration or SHOCK_DURATION)
		if bomb.timer >= bomb.flashTimer then
			bomb.state = "explode"
			bomb.timer = 0
			bomb.explosionTimer = 0
			bomb.explosionDuration = EXPLOSION_DURATION
			handleExplosion(bomb)
		end
	elseif bomb.state == "explode" then
		bomb.explosionTimer = (bomb.explosionTimer or 0) + dt
		bomb.shockTimer = min((bomb.shockTimer or 0) + dt, bomb.shockDuration or SHOCK_DURATION)
		if bomb.explosionTimer >= (bomb.explosionDuration or EXPLOSION_DURATION) then
			bomb.state = "fade"
			bomb.timer = 0
		end
	elseif bomb.state == "fade" then
		bomb.timer = bomb.timer + dt
		bomb.shockTimer = min((bomb.shockTimer or 0) + dt, bomb.shockDuration or SHOCK_DURATION)
		if bomb.timer >= FADE_DURATION then
			bomb.done = true
		end
	end
end

function Bombs:load()
	bombs = bombs or {}
	self.bombs = bombs
end

function Bombs:reset()
	bombs = {}
	self.bombs = bombs
end

function Bombs:getAll()
	return bombs
end

function Bombs:update(dt)
	if not dt or dt <= 0 then return end

	for i = #bombs, 1, -1 do
		local bomb = bombs[i]
		advanceBomb(bomb, dt)
		if bomb.done then
			table.remove(bombs, i)
		end
	end
end

local function drawFuse(bomb, tileSize)
	local fuseLength = tileSize * 0.65
	local baseX = bomb.x
	local baseY = bomb.y
	local flicker = sin((bomb.timer or 0) * 22)
	local colorIndex = floor(((bomb.timer or 0) * 20) % 2)
	local color = colorIndex == 0 and FUSE_COLOR_A or FUSE_COLOR_B

	love.graphics.setLineWidth(2)
	love.graphics.setColor(color[1], color[2], color[3], color[4])
	love.graphics.line(baseX, baseY - tileSize * 0.3, baseX + FUSE_DIR_X * fuseLength, baseY + FUSE_DIR_Y * fuseLength)

	local sparkRadius = tileSize * 0.11 * (1 + 0.25 * flicker)
	love.graphics.setColor(color[1], color[2], color[3], 0.85)
	love.graphics.circle("fill", baseX, baseY - tileSize * 0.55, sparkRadius)
end

local function drawOrb(bomb, tileSize)
	local baseRadius = tileSize * 0.28
	local flicker = 0.04 * sin((bomb.timer or 0) * 18 + bomb.x * 0.1)
	local radius = baseRadius * (1 + flicker)
	local colorIndex = floor(((bomb.timer or 0) * 16) % 2)
	local color = colorIndex == 0 and BASE_ORB_COLOR or FLICKER_COLOR

	if bomb.state ~= "fuse" then
		color = FLICKER_COLOR
	end

	love.graphics.setColor(color[1], color[2], color[3], color[4])
	love.graphics.circle("fill", bomb.x, bomb.y, radius)

	love.graphics.setColor(1, 1, 1, 0.2)
	love.graphics.circle("line", bomb.x, bomb.y, radius * 1.12)
end

local function drawShockRing(bomb, tileSize)
	if not bomb.shockTimer then return end
	local progress = clamp01((bomb.shockTimer or 0) / (bomb.shockDuration or SHOCK_DURATION))
	local maxRadius = (bomb.explosionRadius or (tileSize * EXPLOSION_RADIUS_TILES)) * 1.1
	local radius = maxRadius * progress
	local alpha = (1 - progress) * (SHOCK_COLOR[4] or 1)
	if alpha <= 0 then return end

	love.graphics.setLineWidth(tileSize * 0.12)
	love.graphics.setColor(SHOCK_COLOR[1], SHOCK_COLOR[2], SHOCK_COLOR[3], alpha)
	love.graphics.circle("line", bomb.x, bomb.y, radius)
end

local function drawExplosion(bomb, tileSize)
	if bomb.state ~= "explode" and bomb.state ~= "fade" then return end
	local duration = bomb.explosionDuration or EXPLOSION_DURATION
	local timer = bomb.state == "explode" and (bomb.explosionTimer or 0) or (bomb.timer or duration)
	local progress = clamp01(timer / duration)
	local radius = (bomb.explosionRadius or (tileSize * EXPLOSION_RADIUS_TILES)) * (0.6 + 0.6 * progress)
	local alpha = (1 - progress) * (EXPLOSION_COLOR[4] or 0.4)

	love.graphics.setColor(EXPLOSION_COLOR[1], EXPLOSION_COLOR[2], EXPLOSION_COLOR[3], alpha)
	love.graphics.circle("fill", bomb.x, bomb.y, radius)

	love.graphics.setLineWidth(tileSize * 0.18)
	love.graphics.setColor(EXPLOSION_EDGE_COLOR[1], EXPLOSION_EDGE_COLOR[2], EXPLOSION_EDGE_COLOR[3], alpha * 1.2)
	love.graphics.circle("line", bomb.x, bomb.y, radius)
end

local function drawPreflash(bomb, tileSize)
	if bomb.state ~= "preflash" then return end
	local progress = clamp01((bomb.timer or 0) / (bomb.flashTimer or PRE_FLASH_DURATION))
	local radius = tileSize * 0.36 * (1 + progress * 0.5)
	love.graphics.setColor(1, 1, 1, 0.9)
	love.graphics.circle("fill", bomb.x, bomb.y, radius)
end

function Bombs:draw()
	if not bombs or #bombs == 0 then return end

	local tileSize = getTileSize()
	love.graphics.push("all")
	love.graphics.setBlendMode("alpha")

	for i = 1, #bombs do
		local bomb = bombs[i]
		drawShockRing(bomb, tileSize)
		drawExplosion(bomb, tileSize)
		if bomb.state == "preflash" then
			drawPreflash(bomb, tileSize)
		elseif bomb.state == "fuse" then
			drawFuse(bomb, tileSize)
		end

		if bomb.state ~= "explode" then
			drawOrb(bomb, tileSize)
		end
	end

	love.graphics.pop()
end

function Bombs:spawnBomb(x, y, options)
	if not (x and y) then return nil end

	local col, row
	if Arena and Arena.getTileFromWorld then
		col, row = Arena:getTileFromWorld(x, y)
	end

	local centerX, centerY = x, y
	if Arena and Arena.getCenterOfTile and col and row then
		local cx, cy = Arena:getCenterOfTile(col, row)
		if cx and cy then
			centerX, centerY = cx, cy
		end
	end

	bombs[#bombs + 1] = {
		x = centerX,
		y = centerY,
		col = col,
		row = row,
		timer = 0,
		state = "fuse",
		sparkTimer = 0,
	}

	return bombs[#bombs]
end

function Bombs:setExplosionCallback(fn)
	self._onExplosion = fn
end

return Bombs