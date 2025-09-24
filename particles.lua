local Particles = {}
Particles.list = {}

function Particles:spawnBurst(x, y, options)
	local list = self.list
	local count = options.count or 6
	local speed = options.speed or 60
	local life = options.life or 0.4
	local baseSize = options.size or 4
	local color = options.color or {1, 1, 1, 1}
	local spread = options.spread or math.pi * 2

	for i = 1, count do
		local angle = spread * (i / count) + (love.math.random() - 0.5) * 0.2
		local velocity = speed + love.math.random() * 20
		local vx = math.cos(angle) * velocity
		local vy = math.sin(angle) * velocity
		local scale = 0.6 + love.math.random() * 0.8

		table.insert(list, {
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			baseSize = baseSize * scale,
			life = life,
			age = 0,
			color = {unpack(color)}
		})
	end
end

function Particles:update(dt)
	for i = #self.list, 1, -1 do
		local p = self.list[i]
		p.age = p.age + dt
		if p.age >= p.life then
			table.remove(self.list, i)
		else
			p.x = p.x + p.vx * dt
			p.y = p.y + p.vy * dt

			local t = 1 - (p.age / p.life)
			p.color[4] = t
		end
	end
end

function Particles:draw()
	for _, p in ipairs(self.list) do
		local t = p.age / p.life
		local currentSize = p.baseSize * (0.8 + t * 0.6)
		love.graphics.setColor(p.color)
		love.graphics.circle("fill", p.x, p.y, currentSize)
	end
end

function Particles:reset()
	self.list = {}
end

return Particles