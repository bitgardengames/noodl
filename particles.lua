local Settings = require("settings")
local RenderLayers = require("renderlayers")

local max = math.max
local pi = math.pi
local sqrt = math.sqrt

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local Particles = {}
Particles.count = 0
Particles.x = {}
Particles.y = {}
Particles.vx = {}
Particles.vy = {}
Particles.baseSize = {}
Particles.life = {}
Particles.age = {}
Particles.invLife = {}
Particles.t = {}
Particles.normAge = {}
Particles.drag = {}
Particles.gravity = {}
Particles.fadeTo = {}
Particles.startAlpha = {}
Particles.r = {}
Particles.g = {}
Particles.b = {}
Particles.alpha = {}

local ANGLE_JITTER = 0.2
local SPEED_VARIANCE = 20
local SCALE_MIN = 0.6
local SCALE_VARIANCE = 0.8

local particleSprite
local particleSpriteHalfSize = 0.5

local function ensureParticleSprite()
        if particleSprite then
                return particleSprite
        end

        local size = 32
        local halfSize = (size - 1) * 0.5
        local imageData = love.image.newImageData(size, size)

        for y = 0, size - 1 do
                for x = 0, size - 1 do
                        local dx = (x - halfSize) / halfSize
                        local dy = (y - halfSize) / halfSize
                        local distance = sqrt(dx * dx + dy * dy)
                        local alpha = max(0, 1 - distance)
                        imageData:setPixel(x, y, 1, 1, 1, alpha)
                end
        end

        particleSprite = love.graphics.newImage(imageData)
        particleSprite:setFilter("linear", "linear")
        particleSpriteHalfSize = particleSprite:getWidth() * 0.5

        return particleSprite
end

local function drawParticleBatch(particles)
        local count = particles.count
        if count == 0 then
                return
        end

        local sprite = ensureParticleSprite()
        local spriteWidth = particleSpriteHalfSize * 2
        for i = 1, count do
                local normAge = particles.normAge[i]
                if normAge == nil then
                        local currentT = particles.t[i] or 1
                        normAge = 1 - currentT
                end

                local currentSize = particles.baseSize[i] * (0.8 + normAge * 0.6)
                love.graphics.setColor(particles.r[i], particles.g[i], particles.b[i], particles.alpha[i])
                local scale = (currentSize * 2) / spriteWidth
                love.graphics.draw(sprite, particles.x[i], particles.y[i], 0, scale, scale, particleSpriteHalfSize, particleSpriteHalfSize)
        end

        love.graphics.setColor(1, 1, 1, 1)
end

local function normalizeDirection(dx, dy)
	local length = math.sqrt((dx or 0) * (dx or 0) + (dy or 0) * (dy or 0))
	if not length or length < 1e-4 then
		return 0, -1
	end

	return (dx or 0) / length, (dy or 0) / length
end

local function acquireParticle(self)
        local index = self.count + 1
        self.count = index

        return index
end

local function releaseParticle(self, index)
        local count = self.count
        local lastIndex = count

        if index ~= lastIndex then
                self.x[index] = self.x[lastIndex]
                self.y[index] = self.y[lastIndex]
                self.vx[index] = self.vx[lastIndex]
                self.vy[index] = self.vy[lastIndex]
                self.baseSize[index] = self.baseSize[lastIndex]
                self.life[index] = self.life[lastIndex]
                self.age[index] = self.age[lastIndex]
                self.invLife[index] = self.invLife[lastIndex]
                self.t[index] = self.t[lastIndex]
                self.normAge[index] = self.normAge[lastIndex]
                self.drag[index] = self.drag[lastIndex]
                self.gravity[index] = self.gravity[lastIndex]
                self.fadeTo[index] = self.fadeTo[lastIndex]
                self.startAlpha[index] = self.startAlpha[lastIndex]
                self.r[index] = self.r[lastIndex]
                self.g[index] = self.g[lastIndex]
                self.b[index] = self.b[lastIndex]
                self.alpha[index] = self.alpha[lastIndex]
        end

        self.x[lastIndex] = nil
        self.y[lastIndex] = nil
        self.vx[lastIndex] = nil
        self.vy[lastIndex] = nil
        self.baseSize[lastIndex] = nil
        self.life[lastIndex] = nil
        self.age[lastIndex] = nil
        self.invLife[lastIndex] = nil
        self.t[lastIndex] = nil
        self.normAge[lastIndex] = nil
        self.drag[lastIndex] = nil
        self.gravity[lastIndex] = nil
        self.fadeTo[lastIndex] = nil
        self.startAlpha[lastIndex] = nil
        self.r[lastIndex] = nil
        self.g[lastIndex] = nil
        self.b[lastIndex] = nil
        self.alpha[lastIndex] = nil

        self.count = count - 1
end

function Particles:spawnBurst(x, y, options)
	options = options or {}

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

                local index = acquireParticle(self)
                self.x[index] = x
                self.y[index] = y
                self.vx[index] = vx
                self.vy[index] = vy
                self.baseSize[index] = baseSize * scale
                self.life[index] = life
                self.age[index] = 0
                self.invLife[index] = (life > 0) and (1 / life) or math.huge
                self.t[index] = 1
                self.normAge[index] = 0
                self.drag[index] = drag
                self.gravity[index] = gravity
                self.fadeTo[index] = fadeTo
                self.startAlpha[index] = startAlpha

                self.r[index] = baseR
                self.g[index] = baseG
                self.b[index] = baseB
                self.alpha[index] = startAlpha
        end
end

function Particles:update(dt)
        local count = self.count
        if dt <= 0 or count == 0 then
                return
        end

        for i = count, 1, -1 do
                local invLife = self.invLife[i] or 0
                local t = (self.t[i] or 0) - dt * invLife
                if t <= 0 then
                        releaseParticle(self, i)
                else
                        self.t[i] = t
                        local normAge = 1 - t
                        self.normAge[i] = normAge

                        local life = self.life[i]
                        if life ~= nil then
                                self.age[i] = life * normAge
                        end

                        local vx = self.vx[i] or 0
                        local vy = self.vy[i] or 0
                        self.x[i] = (self.x[i] or 0) + vx * dt
                        self.y[i] = (self.y[i] or 0) + vy * dt

                        local drag = self.drag[i]
                        if drag and drag > 0 then
                                local dragFactor = max(0, 1 - dt * drag)
                                vx = vx * dragFactor
                                vy = vy * dragFactor
                        end

                        local gravity = self.gravity[i]
                        if gravity and gravity ~= 0 then
                                vy = vy + gravity * dt
                        end

                        self.vx[i] = vx
                        self.vy[i] = vy

                        local endAlpha = self.fadeTo[i]
                        if endAlpha == nil then
                                self.alpha[i] = t
                        else
                                local start = self.startAlpha[i]
                                if start == nil then
                                        start = 1
                                end

                                self.alpha[i] = start * t + endAlpha * (1 - t)
                        end
                end
        end
end


function Particles:draw()
        local count = self.count
        if count == 0 then
                return
        end

        RenderLayers:queue("overlay", RenderLayers:acquireCommand(drawParticleBatch, self))
end

function Particles:reset()
        self.count = 0
        self.x = {}
        self.y = {}
        self.vx = {}
        self.vy = {}
        self.baseSize = {}
        self.life = {}
        self.age = {}
        self.invLife = {}
        self.t = {}
        self.normAge = {}
        self.drag = {}
        self.gravity = {}
        self.fadeTo = {}
        self.startAlpha = {}
        self.r = {}
        self.g = {}
        self.b = {}
        self.alpha = {}
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
