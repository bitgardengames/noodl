local Settings = require("settings")

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
  self.shakeTime = 0.4        -- duration in seconds
  self.shakeIntensity = 8     -- pixels of max shake

  -- trigger a quick red flash overlay
  self.flashTime = self.flashDuration
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
    local intensity = self.shakeIntensity * (self.shakeTime / 0.4) -- fade out
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

function Death:drawFlash(width, height)
  if self.flashTime <= 0 then return end

  local t = self.flashTime / self.flashDuration
  local alpha = (t * t) * self.flashMaxAlpha
  love.graphics.setColor(1, 0.25, 0.2, alpha)
  love.graphics.rectangle("fill", 0, 0, width, height)
  love.graphics.setColor(1, 1, 1, 1)
end

function Death:isFinished()
  return #self.particles == 0 and self.shakeTime <= 0 and self.flashTime <= 0
end

return Death
