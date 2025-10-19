local Settings = require("settings")
local RenderLayers = require("renderlayers")

local max = math.max
local pi = math.pi

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local Particles = {}
Particles.list = {}
Particles.pool = {}
Particles.colorPool = {}

local ANGLE_JITTER = 0.2
local SPEED_VARIANCE = 20
local SCALE_MIN = 0.6
local SCALE_VARIANCE = 0.8

local function normalizeDirection(dx, dy)
	local length = math.sqrt((dx or 0) * (dx or 0) + (dy or 0) * (dy or 0))
	if not length or length < 1e-4 then
		return 0, -1
	end

	return (dx or 0) / length, (dy or 0) / length
end

local function acquireParticle(self)
	local pool = self.pool
	local particle = pool[#pool]
	if particle then
		pool[#pool] = nil
	else
		particle = {}
	end

	local colorPool = self.colorPool
	local color = colorPool[#colorPool]
	if color then
		colorPool[#colorPool] = nil
	else
		color = {}
	end

	particle.color = color

	return particle
end

local function releaseParticle(self, index, particle)
	local list = self.list
	local lastIndex = #list
	if index ~= lastIndex then
		list[index] = list[lastIndex]
	end
	list[lastIndex] = nil

	local color = particle.color
	if color then
		self.colorPool[#self.colorPool + 1] = color
		particle.color = nil
	end

	self.pool[#self.pool + 1] = particle
end

function Particles:spawnBurst(x, y, options)
	options = options or {}

	local list = self.list
	local count = max(0, options.count or 6)
	local speed = options.speed or 60
	local life = options.life or 0.4
	local baseSize = options.size or 4
	local sourceColor = options.color
	local baseR = (sourceColor and sourceColor[1]) or 1
	local baseG = (sourceColor and sourceColor[2]) or 1
	local baseB = (sourceColor and sourceColor[3]) or 1
	local startAlpha = sourceColor and sourceColor[4]
	if startAlpha == nil then
		startAlpha = 1
	end
	local spread = options.spread or pi * 2
	local angleJitter = options.angleJitter or ANGLE_JITTER
	local speedVariance = max(0, options.speedVariance or SPEED_VARIANCE)
	local scaleMin = max(0, options.scaleMin or SCALE_MIN)
	local scaleVariance = max(0, options.scaleVariance or SCALE_VARIANCE)
	local drag = options.drag or 0
	local gravity = options.gravity or 0
	local fadeTo = options.fadeTo
	local random = love.math.random
	local cos = math.cos
	local sin = math.sin
	local angleOffset = options.angleOffset or 0

	if count == 0 then
		return
	end

	for i = 1, count do
		local angle = angleOffset + spread * ((i - 0.5) / count) + (random() - 0.5) * angleJitter
		local velocity = speed + random() * speedVariance
		local vx = cos(angle) * velocity
		local vy = sin(angle) * velocity
		local scale = scaleMin + random() * scaleVariance

		local particle = acquireParticle(self)
		particle.x = x
		particle.y = y
		particle.vx = vx
		particle.vy = vy
		particle.baseSize = baseSize * scale
		particle.life = life
		particle.age = 0
		particle.drag = drag
		particle.gravity = gravity
		particle.fadeTo = fadeTo
		particle.startAlpha = startAlpha

		local color = particle.color
		color[1] = baseR
		color[2] = baseG
		color[3] = baseB
		color[4] = startAlpha

		list[#list + 1] = particle
	end
end

function Particles:update(dt)
	if dt <= 0 or #self.list == 0 then
		return
	end

	local list = self.list
	for i = #list, 1, -1 do
		local p = list[i]
		p.age = p.age + dt

		if p.age >= p.life then
			releaseParticle(self, i, p)
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt

			if p.drag and p.drag > 0 then
				local dragFactor = max(0, 1 - dt * p.drag)
				p.vx = p.vx * dragFactor
				p.vy = p.vy * dragFactor
			end

			if p.gravity and p.gravity ~= 0 then
				p.vy = p.vy + p.gravity * dt
			end

			local t = 1 - (p.age / p.life)
			local endAlpha = p.fadeTo
			if endAlpha == nil then
				p.color[4] = t
			else
				local start = p.startAlpha
				if start == nil then
					start = 1
				end

				p.color[4] = start * t + endAlpha * (1 - t)
			end
		end
	end
end


function Particles:draw()
	local list = self.list
	if #list == 0 then
		return
	end

	RenderLayers:withLayer("overlay", function()
		for i = 1, #list do
			local p = list[i]
			local t = p.age / p.life
			local currentSize = p.baseSize * (0.8 + t * 0.6)
			love.graphics.setColor(p.color)
			love.graphics.circle("fill", p.x, p.y, currentSize)
		end

		love.graphics.setColor(1, 1, 1, 1)
	end)
end

function Particles:reset()
	local list = self.list
	local pool = self.pool
	local colorPool = self.colorPool
	for i = 1, #list do
		local p = list[i]
		local color = p.color
		if color then
			colorPool[#colorPool + 1] = color
			p.color = nil
		end
		pool[#pool + 1] = p
	end

	self.list = {}
end

function Particles:spawnBlood(x, y, options)
	if not (x and y) then
		return
	end

	if Settings and Settings.bloodEnabled == false then
		return
	end

	options = options or {}

	local dirX, dirY = normalizeDirection(options.dirX or 0, options.dirY or -1)
	local baseAngle = atan2(dirY, dirX)
	local spraySpread = options.spread or (pi * 0.55)
	local sprayCount = max(0, options.count or 14)

	if sprayCount > 0 then
		self:spawnBurst(x, y, {
			count = sprayCount,
			speed = options.speed or 160,
			speedVariance = options.speedVariance or 70,
			life = options.life or 0.52,
			size = options.size or 3.4,
			color = options.color or {0.8, 0.08, 0.12, 1},
			spread = spraySpread,
			angleOffset = baseAngle - spraySpread * 0.5,
			angleJitter = options.angleJitter or (pi * 0.35),
			drag = options.drag or 2.1,
			gravity = options.gravity or 280,
			fadeTo = options.fadeTo or 0.1,
		})
	end

	local dropletCount = max(0, options.dropletCount or 8)
	if dropletCount > 0 then
		self:spawnBurst(x, y, {
			count = dropletCount,
			speed = options.dropletSpeed or 70,
			speedVariance = options.dropletVariance or 50,
			life = options.dropletLife or 0.62,
			size = options.dropletSize or 2.3,
			color = options.dropletColor or {0.62, 0.05, 0.08, 0.85},
			spread = pi * 2,
			angleOffset = 0,
			angleJitter = options.dropletAngleJitter or pi,
			drag = options.dropletDrag or 3.4,
			gravity = options.dropletGravity or 340,
			fadeTo = options.dropletFadeTo or 0,
		})
	end
end

return Particles
