local Particles = {}
Particles.list = {}

local ANGLE_JITTER = 0.2
local SPEED_VARIANCE = 20
local SCALE_MIN = 0.6
local SCALE_VARIANCE = 0.8

local function copyColor(color)
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

function Particles:spawnBurst(x, y, options)
    options = options or {}

    local list = self.list
    local count = math.max(0, options.count or 6)
    local speed = options.speed or 60
    local life = options.life or 0.4
    local baseSize = options.size or 4
    local baseColor = copyColor(options.color)
    local startAlpha = baseColor[4]
    local spread = options.spread or math.pi * 2
    local angleJitter = options.angleJitter or ANGLE_JITTER
    local speedVariance = math.max(0, options.speedVariance or SPEED_VARIANCE)
    local scaleMin = math.max(0, options.scaleMin or SCALE_MIN)
    local scaleVariance = math.max(0, options.scaleVariance or SCALE_VARIANCE)
    local drag = options.drag or 0
    local gravity = options.gravity or 0
    local fadeTo = options.fadeTo

    if count == 0 then
        return
    end

    for i = 1, count do
        local angle = spread * (i / count) + (love.math.random() - 0.5) * angleJitter
        local velocity = speed + love.math.random() * speedVariance
        local vx = math.cos(angle) * velocity
        local vy = math.sin(angle) * velocity
        local scale = scaleMin + love.math.random() * scaleVariance

        table.insert(list, {
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            baseSize = baseSize * scale,
            life = life,
            age = 0,
            color = copyColor(baseColor),
            drag = drag,
            gravity = gravity,
            fadeTo = fadeTo,
            startAlpha = startAlpha,
        })
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
    for _, p in ipairs(self.list) do
        local t = p.age / p.life
        local currentSize = p.baseSize * (0.8 + t * 0.6)
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, currentSize)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Particles:reset()
    self.list = {}
end

function Particles:isEmpty()
    return #self.list == 0
end

function Particles:count()
    return #self.list
end

return Particles
