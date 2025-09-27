--[[
    Flamethrower floor hazard that fits the "basic shapes + bold outline" style.
    Each unit idles with a gentle pilot glow, then hums to life before
    blasting a vertical plume of fire. Telegraph pulses animate around the
    nozzle so players get a readable warning.
]]

local Theme = require("theme")
local Arena = require("arena")
local Particles = require("particles")
local SnakeUtils = require("snakeutils")

local Flamethrowers = {}
local active = {}

local defaultTiming = {
    idleMin = 1.2,
    idleMax = 2.2,
    warmup = 0.55,
    fire = 0.85,
    cooldown = 0.45,
}

local function cloneTiming(source)
    return {
        idleMin = source.idleMin,
        idleMax = source.idleMax,
        warmup = source.warmup,
        fire = source.fire,
        cooldown = source.cooldown,
    }
end

local function ensureTiming(self)
    if not self.timing then
        self.timing = cloneTiming(defaultTiming)
    end
    return self.timing
end

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function easeInQuad(t)
    return t * t
end

local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getFirePalette()
    local apple = Theme.appleColor or {0.95, 0.45, 0.3, 1}
    local ember = {0.95, 0.55, 0.2, 1}
    local core = {1.0, 0.9, 0.55, 1}

    return apple, ember, core
end

local function setOccupied(col, row)
    if col and row then
        SnakeUtils.setOccupied(col, row, true)
    end
end

function Flamethrowers:reset()
    active = {}
    self.timing = cloneTiming(defaultTiming)
end

function Flamethrowers:getAll()
    return active
end

function Flamethrowers:getTiming()
    local timing = ensureTiming(self)
    return {
        idleMin = timing.idleMin,
        idleMax = timing.idleMax,
        warmup = timing.warmup,
        fire = timing.fire,
        cooldown = timing.cooldown,
    }
end

function Flamethrowers:setTiming(opts)
    if not opts then
        self.timing = cloneTiming(defaultTiming)
        return
    end

    local timing = ensureTiming(self)

    local idleMin = opts.idleMin or timing.idleMin or defaultTiming.idleMin
    idleMin = math.max(0.4, idleMin)

    local idleMax = opts.idleMax or opts.idleMin or timing.idleMax or defaultTiming.idleMax
    idleMax = math.max(idleMin + 0.1, idleMax)

    timing.idleMin = idleMin
    timing.idleMax = idleMax
    timing.warmup = math.max(0.2, opts.warmup or timing.warmup or defaultTiming.warmup)
    timing.fire = math.max(0.3, opts.fire or timing.fire or defaultTiming.fire)
    timing.cooldown = math.max(0.2, opts.cooldown or timing.cooldown or defaultTiming.cooldown)
end

function Flamethrowers:spawn(x, y, opts)
    opts = opts or {}

    local col, row = opts.col, opts.row
    if not col or not row then
        col, row = Arena:getTileFromWorld(x, y)
    end

    setOccupied(col, row)

    local tile = Arena.tileSize or 24
    local timing = ensureTiming(self)
    local idleMin = timing.idleMin or defaultTiming.idleMin
    local idleMax = timing.idleMax or defaultTiming.idleMax
    if idleMax < idleMin then
        idleMax = idleMin
    end

    local unit = {
        x = x,
        y = y,
        col = col,
        row = row,
        baseSize = tile * 0.92,
        baseHeight = tile * 0.48,
        nozzleWidth = tile * 0.42,
        nozzleHeight = tile * 0.3,
        flameLength = tile * 1.7,
        flameWidth = tile * 0.78,
        state = "idle",
        timer = love.math.random() * 0.5,
        idleDuration = love.math.random(idleMin, idleMax),
        warmupDuration = timing.warmup or defaultTiming.warmup,
        fireDuration = timing.fire or defaultTiming.fire,
        cooldownDuration = timing.cooldown or defaultTiming.cooldown,
        flameProgress = 0,
        warningPulse = 0,
        isDangerous = false,
    }

    active[#active + 1] = unit
    return unit
end

local function spawnIgnitionBurst(unit)
    local apple, ember = getFirePalette()
    Particles:spawnBurst(unit.x, unit.y - (Arena.tileSize or 24) * 0.6, {
        count = 14,
        speed = 85,
        speedVariance = 55,
        life = 0.4,
        size = 3,
        color = {apple[1], apple[2], apple[3], 1},
        gravity = 120,
        spread = math.pi * 2,
        angleJitter = math.pi * 0.7,
        drag = 2.4,
        scaleMin = 0.45,
        scaleVariance = 0.7,
        fadeTo = 0,
    })

    Particles:spawnBurst(unit.x, unit.y - (Arena.tileSize or 24) * 0.3, {
        count = 10,
        speed = 50,
        speedVariance = 35,
        life = 0.36,
        size = 2,
        color = {ember[1], ember[2], ember[3], 0.8},
        gravity = 160,
        spread = math.pi * 2,
        angleJitter = math.pi * 0.5,
        drag = 2.8,
        scaleMin = 0.4,
        scaleVariance = 0.6,
        fadeTo = 0,
    })
end

local function spawnSputter(unit)
    local apple = Theme.appleColor or {0.95, 0.45, 0.3, 1}
    Particles:spawnBurst(unit.x, unit.y - (Arena.tileSize or 24) * 0.25, {
        count = 8,
        speed = 40,
        speedVariance = 28,
        life = 0.35,
        size = 2,
        color = {apple[1] * 0.9, apple[2] * 0.7, apple[3] * 0.6, 0.9},
        gravity = 150,
        spread = math.pi * 2,
        angleJitter = math.pi * 0.4,
        drag = 2.6,
        scaleMin = 0.5,
        scaleVariance = 0.4,
        fadeTo = 0,
    })
end

function Flamethrowers:bounce(unit)
    if not unit then return end

    unit.state = "cooldown"
    unit.timer = 0
    unit.isDangerous = false
    unit.flameProgress = 0.35

    spawnSputter(unit)
end

function Flamethrowers:update(dt)
    if dt <= 0 or #active == 0 then
        return
    end

    for _, unit in ipairs(active) do
        unit.timer = unit.timer + dt

        if unit.state == "idle" then
            unit.flameProgress = 0
            unit.isDangerous = false
            unit.warningPulse = 0

            if unit.timer >= unit.idleDuration then
                unit.state = "warmup"
                unit.timer = 0
            end

        elseif unit.state == "warmup" then
            local t = clamp01(unit.timer / unit.warmupDuration)
            unit.flameProgress = t * 0.5
            unit.warningPulse = 0.4 + 0.6 * math.sin(love.timer.getTime() * 12)
            unit.isDangerous = false

            if unit.timer >= unit.warmupDuration then
                unit.state = "fire"
                unit.timer = 0
                unit.warningPulse = 1
                unit.flameProgress = 0.7
                unit.isDangerous = true
                spawnIgnitionBurst(unit)
            end

        elseif unit.state == "fire" then
            local t = clamp01(unit.timer / unit.fireDuration)
            local eased = easeOutQuad(t)
            unit.flameProgress = 0.7 + 0.3 * eased
            unit.isDangerous = true

            if unit.timer >= unit.fireDuration then
                unit.state = "cooldown"
                unit.timer = 0
                unit.isDangerous = false
            end

        elseif unit.state == "cooldown" then
            local t = clamp01(unit.timer / unit.cooldownDuration)
            local eased = easeInQuad(t)
            unit.flameProgress = lerp(unit.flameProgress, 0, eased)
            unit.isDangerous = false

            if unit.timer >= unit.cooldownDuration then
                unit.state = "idle"
                unit.timer = 0
                unit.flameProgress = 0
                unit.idleDuration = love.math.random(1.1, 2.1)
            end
        end
    end
end

local function drawOutlinedRect(mode, x, y, w, h, rx, ry)
    love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, rx, ry)
end

local function drawBase(unit)
    local apple = Theme.appleColor or {0.95, 0.45, 0.3, 1}
    local baseWidth = unit.baseSize
    local baseHeight = unit.baseHeight
    local baseX = unit.x - baseWidth / 2
    local baseY = unit.y - baseHeight * 0.3

    love.graphics.setColor(apple[1] * 0.5, apple[2] * 0.4, apple[3] * 0.4, 0.75)
    drawOutlinedRect("fill", baseX, baseY, baseWidth, baseHeight, 6, 6)

    love.graphics.push()
    love.graphics.translate(unit.x, baseY + baseHeight * 0.4)
    love.graphics.setColor(apple[1] * 0.35, apple[2] * 0.3, apple[3] * 0.28, 0.8)
    love.graphics.rectangle("fill", -baseWidth * 0.45, -baseHeight * 0.22, baseWidth * 0.9, baseHeight * 0.44, 5, 5)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -baseWidth * 0.45, -baseHeight * 0.22, baseWidth * 0.9, baseHeight * 0.44, 5, 5)
    love.graphics.pop()

    if unit.state == "warmup" then
        local pulse = 0.2 + 0.12 * math.abs(unit.warningPulse or 0)
        love.graphics.setColor(apple[1], apple[2] * 0.7, apple[3] * 0.5, pulse)
        love.graphics.circle("fill", unit.x, baseY + baseHeight * 0.15, unit.nozzleWidth * 0.7)
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", unit.x, baseY + baseHeight * 0.15, unit.nozzleWidth * 0.7)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

local function drawNozzle(unit)
    local apple = Theme.appleColor or {0.95, 0.45, 0.3, 1}
    local nozzleWidth = unit.nozzleWidth
    local nozzleHeight = unit.nozzleHeight
    local topY = unit.y - unit.baseHeight * 0.65

    love.graphics.setColor(apple[1] * 0.35, apple[2] * 0.3, apple[3] * 0.28, 0.95)
    drawOutlinedRect("fill", unit.x - nozzleWidth / 2, topY, nozzleWidth, nozzleHeight, 4, 4)

    love.graphics.setColor(apple[1] * 0.25, apple[2] * 0.22, apple[3] * 0.2, 0.9)
    drawOutlinedRect("fill", unit.x - nozzleWidth * 0.65 / 2, topY - nozzleHeight * 0.4, nozzleWidth * 0.65, nozzleHeight * 0.8, 4, 4)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

local function drawFlame(unit)
    local progress = clamp01(unit.flameProgress)
    if progress <= 0 then
        return
    end

    local baseY = unit.y - unit.baseHeight * 0.65
    local length = unit.flameLength * progress
    local width = unit.flameWidth * (0.82 + 0.18 * math.sin(love.timer.getTime() * 8))
    local tipY = baseY - length

    local apple, ember, core = getFirePalette()

    love.graphics.setLineWidth(3)

    love.graphics.setColor(apple[1], apple[2], apple[3], 0.85)
    love.graphics.polygon("fill", {
        unit.x, tipY,
        unit.x - width * 0.55, baseY - length * 0.35,
        unit.x - width * 0.7, baseY,
        unit.x + width * 0.7, baseY,
        unit.x + width * 0.55, baseY - length * 0.35,
    })
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.polygon("line", {
        unit.x, tipY,
        unit.x - width * 0.55, baseY - length * 0.35,
        unit.x - width * 0.7, baseY,
        unit.x + width * 0.7, baseY,
        unit.x + width * 0.55, baseY - length * 0.35,
    })

    love.graphics.setColor(ember[1], ember[2], ember[3], 0.9)
    love.graphics.polygon("fill", {
        unit.x, tipY + length * 0.2,
        unit.x - width * 0.38, baseY - length * 0.25,
        unit.x - width * 0.45, baseY - length * 0.05,
        unit.x + width * 0.45, baseY - length * 0.05,
        unit.x + width * 0.38, baseY - length * 0.25,
    })

    love.graphics.setColor(core[1], core[2], core[3], 0.95)
    love.graphics.polygon("fill", {
        unit.x, tipY + length * 0.45,
        unit.x - width * 0.22, baseY - length * 0.25,
        unit.x - width * 0.28, baseY - length * 0.12,
        unit.x + width * 0.28, baseY - length * 0.12,
        unit.x + width * 0.22, baseY - length * 0.25,
    })

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Flamethrowers:draw()
    if #active == 0 then
        return
    end

    for _, unit in ipairs(active) do
        drawBase(unit)
        drawNozzle(unit)
        drawFlame(unit)
    end
end

local function intersects(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Flamethrowers:checkCollision(x, y, w, h)
    local test = { x = x, y = y, w = w, h = h }

    for _, unit in ipairs(active) do
        if unit.isDangerous then
            local tile = Arena.tileSize or 24
            local baseY = unit.y - unit.baseHeight * 0.65
            local length = unit.flameLength * clamp01(unit.flameProgress)
            local width = unit.flameWidth * 0.95
            local hitbox = {
                x = unit.x - width / 2,
                y = baseY - length,
                w = width,
                h = length + tile * 0.2,
            }

            if intersects(test, hitbox) then
                return unit
            end
        end
    end

    return nil
end

return Flamethrowers
