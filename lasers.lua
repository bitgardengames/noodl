local Theme = require("theme")
local SnakeUtils = require("snakeutils")

local Lasers = {}

local beams = {}

local TRACK_LENGTH = 120
local DEFAULT_THICKNESS = 18
local DEFAULT_SWEEP_RANGE = 42
local DEFAULT_SWEEP_SPEED = 1.35 -- radians per second for sweep oscillation
local FLASH_DECAY = 3.8

local function copyColor(color, alpha)
    local r = 1
    local g = 0.38
    local b = 0.18
    local a = alpha or 1

    if type(color) == "table" then
        r = color[1] or r
        g = color[2] or g
        b = color[3] or b
        a = color[4] or a
    end

    return { r, g, b, a }
end

local function getPalette()
    local accent = Theme.laserColor or Theme.sawColor or {1, 0.38, 0.18, 0.9}
    local glow = copyColor(accent, (accent[4] or 1) * 0.45)
    local core = copyColor(accent, 0.9)
    local rim = copyColor(accent, 1.0)
    rim[1] = math.min(1, rim[1] * 1.15 + 0.05)
    rim[2] = math.min(1, rim[2] * 1.1 + 0.03)
    rim[3] = math.min(1, rim[3] * 1.05 + 0.02)
    rim[4] = 0.95

    return {
        glow = glow,
        core = core,
        rim = rim,
    }
end

local function calculateBounds(beam)
    if not beam then
        return
    end

    local offset = beam.offset or 0
    local halfLength = (beam.length or TRACK_LENGTH) * 0.5
    local thickness = math.max(6, beam.thickness or DEFAULT_THICKNESS)

    if beam.dir == "vertical" then
        local cx = (beam.x or 0) + offset
        local cy = beam.y or 0
        return cx - thickness * 0.5, cy - halfLength, thickness, halfLength * 2
    end

    local cx = beam.x or 0
    local cy = (beam.y or 0) + offset
    return cx - halfLength, cy - thickness * 0.5, halfLength * 2, thickness
end

local function updateOffset(beam, dt)
    beam.timer = (beam.timer or 0) + dt * (beam.speed or DEFAULT_SWEEP_SPEED)
    local phase = beam.phase or 0
    local range = beam.sweepRange or DEFAULT_SWEEP_RANGE
    beam.offset = math.sin(beam.timer + phase) * range
end

local function getTrackLength(length)
    if length and length > 0 then
        return length
    end
    return TRACK_LENGTH
end

function Lasers:reset()
    beams = {}
end

function Lasers:getAll()
    return beams
end

function Lasers:spawn(x, y, dir, length, options)
    dir = dir or "horizontal"
    options = options or {}

    local beam = {
        x = x,
        y = y,
        dir = dir,
        length = getTrackLength(length),
        thickness = options.thickness or DEFAULT_THICKNESS,
        sweepRange = options.sweepRange or DEFAULT_SWEEP_RANGE,
        speed = options.speed or DEFAULT_SWEEP_SPEED,
        phase = options.phase or love.math.random() * math.pi * 2,
        offset = 0,
        timer = 0,
        flashTimer = 0,
    }

    SnakeUtils.occupyTrack(x, y, dir, beam.length)
    beams[#beams + 1] = beam
    return beam
end

function Lasers:update(dt)
    if dt <= 0 then
        return
    end

    for _, beam in ipairs(beams) do
        updateOffset(beam, dt)

        if beam.flashTimer and beam.flashTimer > 0 then
            beam.flashTimer = math.max(0, beam.flashTimer - dt * FLASH_DECAY)
        end
    end
end

function Lasers:onShieldedHit(beam)
    if not beam then
        return
    end

    beam.flashTimer = math.max(beam.flashTimer or 0, 1)
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Lasers:checkCollision(x, y, w, h)
    if not (x and y and w and h) then
        return nil
    end

    for _, beam in ipairs(beams) do
        local bx, by, bw, bh = calculateBounds(beam)
        if bx and rectsOverlap(bx, by, bw, bh, x, y, w, h) then
            beam.flashTimer = math.max(beam.flashTimer or 0, 1)
            return beam
        end
    end

    return nil
end

function Lasers:getBounds(beam)
    return calculateBounds(beam)
end

function Lasers:draw()
    if #beams == 0 then
        return
    end

    local palette = getPalette()
    love.graphics.push("all")
    love.graphics.setLineWidth(2)

    for _, beam in ipairs(beams) do
        local bx, by, bw, bh = calculateBounds(beam)
        if bx then
            local flash = math.min(1, beam.flashTimer or 0)
            local glowAlpha = (palette.glow[4] or 0.4) + flash * 0.35
            love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], glowAlpha)
            love.graphics.rectangle("fill", bx - 6, by - 6, bw + 12, bh + 12, 6, 6)

            local coreAlpha = (palette.core[4] or 0.9) + flash * 0.1
            love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], coreAlpha)
            love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)

            local rimAlpha = (palette.rim[4] or 0.95) + flash * 0.05
            love.graphics.setColor(palette.rim[1], palette.rim[2], palette.rim[3], rimAlpha)
            love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)
        end
    end

    love.graphics.pop()
end

return Lasers
