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
        local drag = options.drag or 0
        local gravity = options.gravity or 0
        local fadeTo = options.fadeTo

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
                        color = {unpack(color)},
                        drag = drag,
                        gravity = gravity,
                        fadeTo = fadeTo,
                        startAlpha = color[4] or 1
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

                        if p.drag and p.drag > 0 then
                                local dragFactor = math.max(0, 1 - dt * p.drag)
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
                                p.color[4] = (p.startAlpha or 1) * t + endAlpha * (1 - t)
                        end
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