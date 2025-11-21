local Settings = require("settings")
local SnakeUtils = require("snakeutils")

local lg = love.graphics
local random = love.math.random
local cos = math.cos
local sin = math.sin
local TWO_PI = math.pi * 2
local SIZE_DECAY = 0.97
local VELOCITY_DECAY = 0.95
local SHAKE_DURATION = 0.4

local Death = {
        particles = {},
        shakeTime = 0,
        shakeIntensity = 0,
	flashTime = 0,
	flashDuration = 0.3,
	flashMaxAlpha = 0.45
}

function Death:spawnFromSnake(trail, SEGMENT_SIZE)
        for i = 1, #trail do
                local p = trail[i]
                local x, y = SnakeUtils.getSegmentPosition(p)
                if x and y then
                        local angle = random() * TWO_PI
                        local speed = random(60, 180)
                        table.insert(self.particles, {
                                x = x,
                                y = y,
                                dx = cos(angle) * speed,
                                dy = sin(angle) * speed,
                                life = 1.0,
                                size = SEGMENT_SIZE * 0.75
                                }
                        )
                end
        end

        -- add screen shake on death spawn
        self.shakeTime = SHAKE_DURATION      -- duration in seconds
        self.shakeIntensity = 8     -- pixels of max shake

	-- trigger a quick red flash overlay
	self.flashTime = self.flashDuration
end

function Death:update(dt)
	-- update particles
	local particles = self.particles
	local writeIndex = 1

	for readIndex = 1, #particles do
		local part = particles[readIndex]
                part.x = part.x + part.dx * dt
                part.y = part.y + part.dy * dt
                part.life = part.life - dt
                part.size = part.size * SIZE_DECAY
                part.dx = part.dx * VELOCITY_DECAY
                part.dy = part.dy * VELOCITY_DECAY

		if part.life > 0 then
			if writeIndex ~= readIndex then
				particles[writeIndex] = part
			end
			writeIndex = writeIndex + 1
		end
	end

	for i = #particles, writeIndex, -1 do
		particles[i] = nil
	end

	-- update shake
        if self.shakeTime > 0 then
                self.shakeTime = self.shakeTime - dt
                if self.shakeTime < 0 then self.shakeTime = 0 end
        end

	-- update flash timer
	if self.flashTime > 0 then
		self.flashTime = self.flashTime - dt
		if self.flashTime < 0 then self.flashTime = 0 end
	end
end

-- call this before drawing game elements
function Death:applyShake()
        if Settings.screenShake == false then
                return
        end

        if self.shakeTime > 0 then
                local intensity = self.shakeIntensity * (self.shakeTime / SHAKE_DURATION) -- fade out
                local dx = random(-intensity, intensity)
                local dy = random(-intensity, intensity)
                lg.translate(dx, dy)
        end
end

function Death:draw()
        for i = 1, #self.particles do
                local part = self.particles[i]
                local alpha = part.life
                lg.setColor(60/255, 185/255, 168/255, alpha)
                lg.circle("fill", part.x, part.y, part.size * 0.5)
        end
        lg.setColor(1, 1, 1, 1) -- reset
end

function Death:drawFlash(width, height)
        if self.flashTime <= 0 then return end

        local t = self.flashTime / self.flashDuration
        local alpha = (t * t) * self.flashMaxAlpha
        lg.setColor(1, 0.25, 0.2, alpha)
        lg.rectangle("fill", 0, 0, width, height)
        lg.setColor(1, 1, 1, 1)
end

function Death:isFinished()
	return #self.particles == 0 and self.shakeTime <= 0 and self.flashTime <= 0
end

return Death
