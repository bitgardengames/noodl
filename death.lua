local Settings = require("settings")

local Death = {
	particles = {},
	ShakeTime = 0,
	ShakeIntensity = 0,
	FlashTime = 0,
	FlashDuration = 0.3,
	FlashMaxAlpha = 0.45
}

function Death:SpawnFromSnake(trail, SEGMENT_SIZE)
	for i = 1, #trail do
	local p = trail[i]
	if p.drawX and p.drawY then
		local angle = love.math.random() * math.pi * 2
		local speed = love.math.random(60, 180)
		table.insert(self.particles, {
		x = p.drawX,
		y = p.drawY,
		dx = math.cos(angle) * speed,
		dy = math.sin(angle) * speed,
		life = 1.0,
		size = SEGMENT_SIZE * 0.75
		})
	end
	end

	-- add screen shake on death spawn
	self.ShakeTime = 0.4        -- duration in seconds
	self.ShakeIntensity = 8     -- pixels of max shake

	-- trigger a quick red flash overlay
	self.FlashTime = self.FlashDuration
end

function Death:update(dt)
	-- update particles
	for i = #self.particles, 1, -1 do
	local part = self.particles[i]
	part.x = part.x + part.dx * dt
	part.y = part.y + part.dy * dt
	part.life = part.life - dt
	part.size = part.size * 0.97
	part.dx = part.dx * 0.95
	part.dy = part.dy * 0.95

	if part.life <= 0 then
		table.remove(self.particles, i)
	end
	end

	-- update shake
	if self.ShakeTime > 0 then
	self.ShakeTime = self.ShakeTime - dt
	if self.ShakeTime < 0 then self.ShakeTime = 0 end
	end

	-- update flash timer
	if self.FlashTime > 0 then
	self.FlashTime = self.FlashTime - dt
	if self.FlashTime < 0 then self.FlashTime = 0 end
	end
end

-- call this before drawing game elements
function Death:ApplyShake()
	if Settings.ScreenShake == false then
	return
	end

	if self.ShakeTime > 0 then
	local intensity = self.ShakeIntensity * (self.ShakeTime / 0.4) -- fade out
	local dx = love.math.random(-intensity, intensity)
	local dy = love.math.random(-intensity, intensity)
	love.graphics.translate(dx, dy)
	end
end

function Death:draw()
	for i = 1, #self.particles do
	local part = self.particles[i]
	local alpha = part.life
	love.graphics.setColor(60/255, 185/255, 168/255, alpha)
	love.graphics.circle("fill", part.x, part.y, part.size * 0.5)
	end
	love.graphics.setColor(1, 1, 1, 1) -- reset
end

function Death:DrawFlash(width, height)
	if self.FlashTime <= 0 then return end

	local t = self.FlashTime / self.FlashDuration
	local alpha = (t * t) * self.FlashMaxAlpha
	love.graphics.setColor(1, 0.25, 0.2, alpha)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setColor(1, 1, 1, 1)
end

function Death:IsFinished()
	return #self.particles == 0 and self.ShakeTime <= 0 and self.FlashTime <= 0
end

return Death
