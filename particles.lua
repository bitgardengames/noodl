local Settings = require("settings")

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local Particles = {}
Particles.list = {}

local ANGLE_JITTER = 0.2
local SPEED_VARIANCE = 20
local SCALE_MIN = 0.6
local SCALE_VARIANCE = 0.8

local function NormalizeDirection(dx, dy)
	local length = math.sqrt((dx or 0) * (dx or 0) + (dy or 0) * (dy or 0))
	if not length or length < 1e-4 then
		return 0, -1
	end

	return (dx or 0) / length, (dy or 0) / length
end

local function CopyColor(color)
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

function Particles:SpawnBurst(x, y, options)
	options = options or {}

	local list = self.list
	local count = math.max(0, options.count or 6)
	local speed = options.speed or 60
	local life = options.life or 0.4
	local BaseSize = options.size or 4
	local BaseColor = CopyColor(options.color)
	local StartAlpha = BaseColor[4]
	local spread = options.spread or math.pi * 2
	local AngleJitter = options.angleJitter or ANGLE_JITTER
	local SpeedVariance = math.max(0, options.speedVariance or SPEED_VARIANCE)
	local ScaleMin = math.max(0, options.scaleMin or SCALE_MIN)
	local ScaleVariance = math.max(0, options.scaleVariance or SCALE_VARIANCE)
	local drag = options.drag or 0
	local gravity = options.gravity or 0
	local FadeTo = options.fadeTo
	local random = love.math.random
	local cos = math.cos
	local sin = math.sin
	local AngleOffset = options.angleOffset or 0

	if count == 0 then
		return
	end

	for i = 1, count do
		local angle = AngleOffset + spread * ((i - 0.5) / count) + (random() - 0.5) * AngleJitter
		local velocity = speed + random() * SpeedVariance
		local vx = cos(angle) * velocity
		local vy = sin(angle) * velocity
		local scale = ScaleMin + random() * ScaleVariance

		list[#list + 1] = {
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			BaseSize = BaseSize * scale,
			life = life,
			age = 0,
			color = CopyColor(BaseColor),
			drag = drag,
			gravity = gravity,
			FadeTo = FadeTo,
			StartAlpha = StartAlpha,
		}
	end
end

function Particles:update(dt)
	if dt <= 0 or #self.list == 0 then
		return
	end

	for i = #self.list, 1, -1 do
		local p = self.list[i]
		p.age = p.age + dt

		if p.age >= p.life then
			table.remove(self.list, i)
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt

			if p.drag and p.drag > 0 then
				local DragFactor = math.max(0, 1 - dt * p.drag)
				p.vx = p.vx * DragFactor
				p.vy = p.vy * DragFactor
			end

			if p.gravity and p.gravity ~= 0 then
				p.vy = p.vy + p.gravity * dt
			end

			local t = 1 - (p.age / p.life)
			local EndAlpha = p.fadeTo
			if EndAlpha == nil then
				p.color[4] = t
			else
				local start = p.startAlpha
				if start == nil then
					start = 1
				end

				p.color[4] = start * t + EndAlpha * (1 - t)
			end
		end
	end
end

function Particles:draw()
	for _, p in ipairs(self.list) do
		local t = p.age / p.life
		local CurrentSize = p.baseSize * (0.8 + t * 0.6)
		love.graphics.setColor(p.color)
		love.graphics.circle("fill", p.x, p.y, CurrentSize)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function Particles:reset()
	self.list = {}
end

function Particles:SpawnBlood(x, y, options)
	if not (x and y) then
		return
	end

	if Settings and Settings.BloodEnabled == false then
		return
	end

	options = options or {}

	local DirX, DirY = NormalizeDirection(options.dirX or 0, options.dirY or -1)
	local BaseAngle = atan2(DirY, DirX)
	local SpraySpread = options.spread or (math.pi * 0.55)
	local SprayCount = math.max(0, options.count or 14)

	if SprayCount > 0 then
		self:SpawnBurst(x, y, {
			count = SprayCount,
			speed = options.speed or 160,
			SpeedVariance = options.speedVariance or 70,
			life = options.life or 0.52,
			size = options.size or 3.4,
			color = options.color or {0.8, 0.08, 0.12, 1},
			spread = SpraySpread,
			AngleOffset = BaseAngle - SpraySpread * 0.5,
			AngleJitter = options.angleJitter or (math.pi * 0.35),
			drag = options.drag or 2.1,
			gravity = options.gravity or 280,
			FadeTo = options.fadeTo or 0.1,
		})
	end

	local DropletCount = math.max(0, options.dropletCount or 8)
	if DropletCount > 0 then
		self:SpawnBurst(x, y, {
			count = DropletCount,
			speed = options.dropletSpeed or 70,
			SpeedVariance = options.dropletVariance or 50,
			life = options.dropletLife or 0.62,
			size = options.dropletSize or 2.3,
			color = options.dropletColor or {0.62, 0.05, 0.08, 0.85},
			spread = math.pi * 2,
			AngleOffset = 0,
			AngleJitter = options.dropletAngleJitter or math.pi,
			drag = options.dropletDrag or 3.4,
			gravity = options.dropletGravity or 340,
			FadeTo = options.dropletFadeTo or 0,
		})
	end
end

return Particles
