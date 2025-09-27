--[[
    Blooming spike hazard composed of simple primitives with a consistent
    3 px outline. The plate is a rounded square inset with a rotated diamond
    telegraph, while the spikes themselves are grouped triangles that rise
    up from the floor in stages so the silhouette reads clearly at gameplay
    scale.
]]

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

local function getSpikeColor()
    local c = Theme.appleColor or {0.85, 0.4, 0.45, 1}
    return c[1] or 0.85, c[2] or 0.4, c[3] or 0.45, c[4] == nil and 1 or c[4]
end

local function setOccupied(col, row)
    if col and row then
        SnakeUtils.setOccupied(col, row, true)
    end
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

    setOccupied(col, row)

    local tile = Arena.tileSize or 24
    local spike = {
        x = x,
        y = y,
        col = col,
        row = row,
        baseSize = tile * 0.9,
        spikeHeight = tile * 1.1,
        state = "idle",
        timer = love.math.random() * 0.4,
        idleDuration = love.math.random(1.0, 1.8),
        warnDuration = 0.55,
        emergeDuration = 0.22,
        activeDuration = 0.6,
        retractDuration = 0.32,
        spikeProgress = 0,
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

    local r, g, b = getSpikeColor()
    Particles:spawnBurst(spike.x, spike.y, {
        count = 10,
        speed = 65,
        speedVariance = 40,
        life = 0.35,
        size = 3,
        color = {r, g, b, 1},
        gravity = 220,
        spread = math.pi * 2,
        angleJitter = math.pi * 0.6,
        drag = 2.8,
        scaleMin = 0.4,
        scaleVariance = 0.6,
        fadeTo = 0,
    })
end

function Spikes:bounce(spike)
    if not spike then return end

    spike.state = "retract"
    spike.timer = 0
    spike.isDangerous = false
end

function Spikes:update(dt)
    if dt <= 0 or #active == 0 then
        return
    end

    for _, spike in ipairs(active) do
        spike.timer = spike.timer + dt

        if spike.state == "idle" then
            spike.spikeProgress = 0
            spike.isDangerous = false
            spike.warningPulse = 0
            spike.didBurst = false

            if spike.timer >= spike.idleDuration then
                spike.state = "warn"
                spike.timer = 0
            end

        elseif spike.state == "warn" then
            local t = clamp01(spike.timer / spike.warnDuration)
            spike.spikeProgress = math.sin(t * math.pi) * 0.15
            spike.warningPulse = 0.35 + 0.65 * math.sin(love.timer.getTime() * 10)
            spike.isDangerous = false

            if spike.timer >= spike.warnDuration then
                spike.state = "emerge"
                spike.timer = 0
                spike.warningPulse = 1
            end

        elseif spike.state == "emerge" then
            local t = clamp01(spike.timer / spike.emergeDuration)
            local eased = easeOutQuad(t)
            spike.spikeProgress = eased
            spike.isDangerous = eased > 0.35

            if spike.timer >= spike.emergeDuration then
                spike.state = "active"
                spike.timer = 0
                spike.spikeProgress = 1
                spike.isDangerous = true
                spawnBurst(spike)
            end

        elseif spike.state == "active" then
            spike.spikeProgress = 1
            spike.isDangerous = true

            if spike.timer >= spike.activeDuration then
                spike.state = "retract"
                spike.timer = 0
                spike.isDangerous = false
            end

        elseif spike.state == "retract" then
            local t = clamp01(spike.timer / spike.retractDuration)
            local eased = easeInQuad(t)
            spike.spikeProgress = 1 - eased
            spike.isDangerous = false

            if spike.timer >= spike.retractDuration then
                spike.state = "idle"
                spike.timer = 0
                spike.spikeProgress = 0
                spike.idleDuration = love.math.random(1.0, 1.8)
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

local function drawPlate(spike)
    local r, g, b = getSpikeColor()
    local baseSize = spike.baseSize
    local alpha = 0.16

    if spike.state == "warn" then
        alpha = 0.22 + 0.12 * math.abs(spike.warningPulse or 0)
    elseif spike.state == "emerge" or spike.state == "active" then
        alpha = 0.3
    elseif spike.state == "retract" then
        alpha = 0.2
    end

    love.graphics.setColor(r * 0.8, g * 0.5, b * 0.5, alpha)
    drawOutlinedRect("fill", spike.x - baseSize / 2, spike.y - baseSize / 2, baseSize, baseSize, 6, 6)

    love.graphics.push()
    love.graphics.translate(spike.x, spike.y)
    love.graphics.rotate(math.pi / 4)
    love.graphics.setColor(r, g * 0.7, b, alpha * 0.9)
    drawOutlinedRect("fill", -baseSize * 0.32, -baseSize * 0.32, baseSize * 0.64, baseSize * 0.64, 4, 4)
    love.graphics.pop()
end

local function drawSpikes(spike)
    local progress = clamp01(spike.spikeProgress)
    if progress <= 0 then
        return
    end

    local tile = Arena.tileSize or 24
    local r, g, b = getSpikeColor()
    local baseY = spike.y + tile * 0.22
    local height = spike.spikeHeight * progress
    local tipOffset = tile * 0.1 * (1 - progress)
    local spikeWidth = spike.baseSize * 0.22
    local spacing = spike.baseSize * 0.28

    love.graphics.setLineWidth(3)

    for i = -1, 1 do
        local cx = spike.x + i * spacing
        local points = {
            cx, baseY - height - tipOffset,
            cx - spikeWidth, baseY,
            cx + spikeWidth, baseY,
        }

        love.graphics.setColor(r * 0.9, g * 0.6, b * 0.8, 0.95)
        love.graphics.polygon("fill", points)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line", points)
    end

    local rimWidth = spike.baseSize * 0.55
    love.graphics.setColor(r * 0.5, g * 0.35, b * 0.35, 0.8)
    drawOutlinedRect("fill", spike.x - rimWidth / 2, baseY - tile * 0.12, rimWidth, tile * 0.24, 6, 6)
end

function Spikes:draw()
    if #active == 0 then
        return
    end

    for _, spike in ipairs(active) do
        drawPlate(spike)
        drawSpikes(spike)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function intersects(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Spikes:checkCollision(x, y, w, h)
    local test = { x = x, y = y, w = w, h = h }

    for _, spike in ipairs(active) do
        if spike.isDangerous then
            local tile = Arena.tileSize or 24
            local baseY = spike.y + tile * 0.22
            local height = spike.spikeHeight * clamp01(spike.spikeProgress)
            local hitbox = {
                x = spike.x - spike.baseSize * 0.33,
                y = baseY - height - tile * 0.05,
                w = spike.baseSize * 0.66,
                h = height + tile * 0.12,
            }

            if intersects(test, hitbox) then
                return spike
            end
        end
    end

    return nil
end

return Spikes
