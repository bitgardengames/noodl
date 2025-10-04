local Death = {
  particles = {}
}

function Death:spawnFromSnake(trail, SEGMENT_SIZE)
  self.particles = {}

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

function Death:isFinished()
  return #self.particles == 0
end

return Death
