local Theme = require("theme")
local Arena = require("arena")
local Particles = require("particles")
local SnakeUtils = require("snakeutils")

local Spikes = {}
local active = {}

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

local function getMetalColor()
    local c = Theme.sawColor or {0.8, 0.82, 0.86, 1}
    return c[1] or 0.8, c[2] or 0.82, c[3] or 0.86, c[4] or 1
end

local function getWarningColor()
    local c = Theme.progressColor or {0.9, 0.6, 0.35, 1}
    return c[1] or 0.9, c[2] or 0.6, c[3] or 0.35, c[4] or 1
end

local function drawOutlinedRect(mode, x, y, w, h, rx, ry)
    love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, rx, ry)
end

local function drawOutlinedPolygon(points)
    love.graphics.polygon("fill", points)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", points)
end

function Spikes:reset()
    active = {}
end

function Spikes:getAll()
    return active
end

function Spikes:spawn(x, y, opts)
    opts = opts or {}
    local col, row = opts.col, opts.row

    if not col or not row then
        col, row = Arena:getTileFromWorld(x, y)
    end

    SnakeUtils.setOccupied(col, row, true)

    local tile = Arena.tileSize or SnakeUtils.SEGMENT_SIZE or 24

    local spike = {
        x = x,
        y = y,
        col = col,
        row = row,
        baseSize = tile * 0.9,
        spikeHeight = tile * 1.05,
        currentHeight = 0,
        state = "idle",
        timer = love.math.random() * 0.4,
        idleDuration = love.math.random(1.2, 1.9),
        warnDuration = 0.55,
        extendDuration = 0.18,
        holdDuration = love.math.random(0.35, 0.5),
        retractDuration = 0.25,
        warningPulse = 0,
        isDangerous = false,
        didBurst = false,
    }

    active[#active + 1] = spike
    return spike
end

local function spawnBurst(spike)
    if spike.didBurst then
        return
    end

    spike.didBurst = true

    local r, g, b = getMetalColor()
    Particles:spawnBurst(spike.x, spike.y - spike.spikeHeight * 0.85, {
        count = 6,
        speed = 80,
        life = 0.35,
        size = 3,
        color = {r, g, b, 1},
        gravity = 220,
        spread = math.pi * 0.75,
        angleJitter = 0.4,
    })
end

function Spikes:shatter(spike)
    if not spike then
        return
    end

    local r, g, b = getMetalColor()
    Particles:spawnBurst(spike.x, spike.y - math.max(spike.currentHeight, 8) * 0.6, {
        count = 8,
        speed = 70,
        life = 0.32,
        size = 3,
        color = {r, g, b, 1},
        gravity = 200,
        spread = math.pi * 0.8,
    })

    spike.state = "idle"
    spike.timer = 0
    spike.currentHeight = 0
    spike.isDangerous = false
    spike.warningPulse = 0
    spike.didBurst = true
    spike.idleDuration = love.math.random(1.1, 1.6)
end

function Spikes:update(dt)
    if dt <= 0 or #active == 0 then
        return
    end

    for _, spike in ipairs(active) do
        spike.timer = spike.timer + dt

        if spike.state == "idle" then
            spike.currentHeight = 0
            spike.isDangerous = false
            spike.warningPulse = 0
            spike.didBurst = false

            if spike.timer >= spike.idleDuration then
                spike.state = "warn"
                spike.timer = 0
            end

        elseif spike.state == "warn" then
            local t = clamp01(spike.timer / spike.warnDuration)
            spike.warningPulse = math.sin(love.timer.getTime() * 12)
            spike.currentHeight = math.sin(t * math.pi * 4) * 4
            spike.isDangerous = false

            if spike.timer >= spike.warnDuration then
                spike.state = "extend"
                spike.timer = 0
            end

        elseif spike.state == "extend" then
            local t = clamp01(spike.timer / spike.extendDuration)
            local eased = easeInQuad(t)
            spike.currentHeight = spike.spikeHeight * eased
            spike.isDangerous = spike.currentHeight > spike.spikeHeight * 0.45

            if spike.timer >= spike.extendDuration then
                spike.state = "hold"
                spike.timer = 0
                spike.currentHeight = spike.spikeHeight
                spike.isDangerous = true
                spawnBurst(spike)
            end

        elseif spike.state == "hold" then
            spike.currentHeight = spike.spikeHeight
            spike.isDangerous = true
            spawnBurst(spike)

            if spike.timer >= spike.holdDuration then
                spike.state = "retract"
                spike.timer = 0
            end

        elseif spike.state == "retract" then
            local t = clamp01(spike.timer / spike.retractDuration)
            local eased = easeOutQuad(t)
            spike.currentHeight = spike.spikeHeight * (1 - eased)
            spike.isDangerous = spike.currentHeight > spike.spikeHeight * 0.2

            if spike.timer >= spike.retractDuration then
                spike.state = "idle"
                spike.timer = 0
                spike.currentHeight = 0
                spike.isDangerous = false
                spike.idleDuration = love.math.random(1.2, 1.9)
            end
        end
    end
end

local function drawWarningFloor(spike)
    local baseSize = spike.baseSize
    local r, g, b = getMetalColor()

    local alpha = 0.16
    if spike.state == "warn" then
        alpha = 0.18 + 0.12 * math.abs(spike.warningPulse or 0)
    elseif spike.state == "extend" then
        alpha = 0.28
    elseif spike.state == "hold" then
        alpha = 0.24
    end

    love.graphics.setColor(r, g, b, alpha)
    drawOutlinedRect("fill", spike.x - baseSize / 2, spike.y - baseSize / 2, baseSize, baseSize, 6, 6)

    love.graphics.push()
    love.graphics.translate(spike.x, spike.y)
    love.graphics.rotate(math.pi / 4)
    love.graphics.setColor(r, g, b, alpha * 0.8)
    drawOutlinedRect("fill", -baseSize * 0.32, -baseSize * 0.32, baseSize * 0.64, baseSize * 0.64, 4, 4)
    love.graphics.pop()
end

local function drawBase(spike)
    local baseWidth = spike.baseSize * 0.82
    local baseHeight = spike.baseSize * 0.42
    local x = spike.x - baseWidth / 2
    local y = spike.y - baseHeight / 2
    local r, g, b = getMetalColor()

    love.graphics.setColor(r * 0.7, g * 0.7, b * 0.75, 1)
    drawOutlinedRect("fill", x, y, baseWidth, baseHeight, 6, 6)

    love.graphics.setColor(r * 0.55, g * 0.55, b * 0.6, 1)
    drawOutlinedRect("fill", spike.x - baseWidth * 0.35, y + baseHeight * 0.35, baseWidth * 0.7, baseHeight * 0.4, 4, 4)
end

local function drawSpikes(spike)
    if spike.currentHeight <= 2 then
        return
    end

    local baseTop = spike.y - spike.baseSize / 2
    local tipHeight = spike.currentHeight
    local spikeWidth = spike.baseSize * 0.32
    local offsets = { -spike.baseSize * 0.28, 0, spike.baseSize * 0.28 }
    local r, g, b = getMetalColor()
    local wr, wg, wb = getWarningColor()

    for index, offset in ipairs(offsets) do
        local cx = spike.x + offset
        local tipY = baseTop - tipHeight
        local baseY = baseTop
        local blend = 0.35 + 0.25 * index
        local fillR = r * (1 - blend) + wr * blend
        local fillG = g * (1 - blend) + wg * blend
        local fillB = b * (1 - blend) + wb * blend

        local dangerAlpha = spike.isDangerous and 1 or 0.65
        love.graphics.setColor(fillR, fillG, fillB, dangerAlpha)
        drawOutlinedPolygon({
            cx, tipY,
            cx - spikeWidth / 2, baseY,
            cx + spikeWidth / 2, baseY,
        })
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Spikes:draw()
    if #active == 0 then
        return
    end

    for _, spike in ipairs(active) do
        drawWarningFloor(spike)
        drawSpikes(spike)
        drawBase(spike)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function intersects(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Spikes:checkCollision(x, y, w, h)
    if #active == 0 then
        return nil
    end

    local test = { x = x, y = y, w = w, h = h }

    for _, spike in ipairs(active) do
        if spike.isDangerous and spike.currentHeight > 6 then
            local width = spike.baseSize * 0.6
            local baseTop = spike.y - spike.baseSize / 2
            local hitbox = {
                x = spike.x - width / 2,
                y = baseTop - spike.currentHeight,
                w = width,
                h = spike.currentHeight,
            }

            if intersects(test, hitbox) then
                return spike
            end
        end
    end

    return nil
end

return Spikes
