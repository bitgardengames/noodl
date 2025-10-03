local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")

local Lasers = {}

local emitters = {}

local FLASH_DECAY = 3.8
local DEFAULT_FIRE_COLOR = {1, 0.16, 0.16, 1}
local DEFAULT_BEAM_THICKNESS = 6
local DEFAULT_FIRE_DURATION = 1.2
local DEFAULT_CHARGE_DURATION = 0.9
local BURN_FADE_RATE = 0.55
local WALL_INSET = 6
local BEAM_PULSE_SPEED = 7.2
local BEAM_GLOW_EXPANSION = 8
local BASE_GLOW_RADIUS = 18
local IMPACT_RING_SPEED = 1.85
local IMPACT_RING_RANGE = 16
local IMPACT_FLARE_RADIUS = 12

local function getTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return 0
end

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

local function getFirePalette(color)
    local base = copyColor(color or DEFAULT_FIRE_COLOR)
    local glow = copyColor(base, (base[4] or 1) * 0.65)
    local core = copyColor(base, 0.95)
    local rim = copyColor(base, 1.0)

    rim[1] = math.min(1, rim[1] * 1.1)
    rim[2] = math.min(1, rim[2] * 0.7)
    rim[3] = math.min(1, rim[3] * 0.7)
    rim[4] = 1.0

    return {
        glow = glow,
        core = core,
        rim = rim,
    }
end

local function getEmitterColors()
    local body = Theme.laserBaseColor or {0.18, 0.19, 0.24, 0.95}
    local accent = copyColor(Theme.laserColor or {1, 0.32, 0.26, 1})
    accent[4] = 0.85
    return body, accent
end

local function releaseOccupancy(beam)
    if not beam then
        return
    end

    if beam.col and beam.row then
        SnakeUtils.setOccupied(beam.col, beam.row, false)
    end
end

local function getFacingFromPosition(dir, col, row)
    if dir == "vertical" then
        local midpoint = math.floor((Arena.rows or 1) / 2)
        if row and row > midpoint then
            return -1
        end
    else
        local midpoint = math.floor((Arena.cols or 1) / 2)
        if col and col > midpoint then
            return -1
        end
    end

    return 1
end

local function clamp(value, minimum, maximum)
    if minimum and value < minimum then
        return minimum
    end
    if maximum and value > maximum then
        return maximum
    end
    return value
end

local function computeBeamTarget(beam)
    local tileSize = Arena.tileSize or 24
    local facing = beam.facing or 1
    local inset = math.max(2, tileSize * 0.5 - 4)
    local startX = beam.x or 0
    local startY = beam.y or 0
    local endX, endY
    local rocks = Rocks:getAll() or {}
    local bestDistance = math.huge
    local hitRock

    if beam.dir == "horizontal" then
        startX = startX + facing * inset
        endY = startY

        local wallX
        if facing > 0 then
            wallX = (Arena.x or 0) + (Arena.width or 0) - WALL_INSET
        else
            wallX = (Arena.x or 0) + WALL_INSET
        end

        endX = wallX

        for _, rock in ipairs(rocks) do
            if rock.row == beam.row then
                local delta = (rock.x - (beam.x or 0)) * facing
                if delta and delta > 0 and delta < bestDistance then
                    bestDistance = delta
                    hitRock = rock
                end
            end
        end

        if hitRock then
            local edge = tileSize * 0.5 - 2
            endX = hitRock.x - facing * edge
        end
    else
        startY = startY + facing * inset
        endX = startX

        local wallY
        if facing > 0 then
            wallY = (Arena.y or 0) + (Arena.height or 0) - WALL_INSET
        else
            wallY = (Arena.y or 0) + WALL_INSET
        end

        endY = wallY

        for _, rock in ipairs(rocks) do
            if rock.col == beam.col then
                local delta = (rock.y - (beam.y or 0)) * facing
                if delta and delta > 0 and delta < bestDistance then
                    bestDistance = delta
                    hitRock = rock
                end
            end
        end

        if hitRock then
            local edge = tileSize * 0.5 - 2
            endY = hitRock.y - facing * edge
        end
    end

    if beam.dir == "horizontal" then
        local minX = math.min(startX, endX)
        local width = math.max(0, math.abs(endX - startX))
        local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
        beam.beamRect = {minX, startY - thickness * 0.5, width, thickness}
    else
        local minY = math.min(startY, endY)
        local height = math.max(0, math.abs(endY - startY))
        local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
        beam.beamRect = {startX - thickness * 0.5, minY, thickness, height}
    end

    beam.beamStartX = startX
    beam.beamStartY = startY
    beam.beamEndX = endX
    beam.beamEndY = endY or startY
    beam.impactX = endX
    beam.impactY = endY or startY
    beam.targetRock = hitRock
end

function Lasers:reset()
    for _, beam in ipairs(emitters) do
        releaseOccupancy(beam)
    end
    emitters = {}
end

function Lasers:getAll()
    return emitters
end

function Lasers:spawn(x, y, dir, length, options)
    dir = dir or "horizontal"
    options = options or {}

    local col, row = Arena:getTileFromWorld(x, y)
    local facing = options.facing
    if facing == nil then
        facing = getFacingFromPosition(dir, col, row)
    end

    facing = (facing >= 0) and 1 or -1

    local fireDuration = math.max(0.2, options.fireDuration or DEFAULT_FIRE_DURATION)
    local chargeDuration = math.max(0.25, options.chargeDuration or DEFAULT_CHARGE_DURATION)
    local minCooldown = options.fireCooldownMin or 3.5
    local maxCooldown = options.fireCooldownMax or (minCooldown + 3.0)
    if maxCooldown < minCooldown then
        maxCooldown = minCooldown
    end

    local beam = {
        x = x,
        y = y,
        col = col,
        row = row,
        dir = dir,
        facing = facing,
        beamThickness = options.beamThickness or DEFAULT_BEAM_THICKNESS,
        fireDuration = fireDuration,
        chargeDuration = chargeDuration,
        fireCooldownMin = minCooldown,
        fireCooldownMax = maxCooldown,
        firePalette = options.firePalette or getFirePalette(options.fireColor),
        state = "cooldown",
        isFiring = false,
        flashTimer = 0,
        burnAlpha = 0,
        randomOffset = love.math.random() * math.pi * 2,
    }

    beam.fireCooldown = love.math.random() * (maxCooldown - minCooldown) + minCooldown

    SnakeUtils.setOccupied(col, row, true)

    computeBeamTarget(beam)
    emitters[#emitters + 1] = beam
    return beam
end

function Lasers:update(dt)
    if dt <= 0 then
        return
    end

    for _, beam in ipairs(emitters) do
        computeBeamTarget(beam)

        if beam.state == "charging" then
            beam.chargeTimer = (beam.chargeTimer or beam.chargeDuration) - dt
            if beam.chargeTimer <= 0 then
                beam.state = "firing"
                beam.isFiring = true
                beam.fireTimer = beam.fireDuration
                beam.chargeTimer = nil
                beam.flashTimer = math.max(beam.flashTimer or 0, 0.75)
                beam.burnAlpha = 0.92
            end
        elseif beam.state == "firing" then
            beam.fireTimer = (beam.fireTimer or beam.fireDuration) - dt
            beam.burnAlpha = 0.92
            if beam.fireTimer <= 0 then
                beam.state = "cooldown"
                beam.isFiring = false
                local minCooldown = beam.fireCooldownMin or 0
                local maxCooldown = beam.fireCooldownMax or minCooldown
                if maxCooldown < minCooldown then
                    maxCooldown = minCooldown
                end
                beam.fireCooldown = love.math.random() * (maxCooldown - minCooldown) + minCooldown
                beam.fireTimer = nil
            end
        else
            if beam.fireCooldown then
                beam.fireCooldown = beam.fireCooldown - dt
                if beam.fireCooldown <= 0 then
                    beam.state = "charging"
                    beam.chargeTimer = beam.chargeDuration
                    beam.fireCooldown = nil
                end
            else
                beam.state = "charging"
                beam.chargeTimer = beam.chargeDuration
            end
        end

        if beam.state ~= "firing" then
            beam.burnAlpha = math.max(0, (beam.burnAlpha or 0) - dt * BURN_FADE_RATE)
        end

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

local function baseBounds(beam)
    if not beam then
        return
    end

    local size = Arena.tileSize or 24
    local half = size * 0.5
    local bx = (beam.x or 0) - half
    local by = (beam.y or 0) - half
    return bx, by, size, size
end

function Lasers:checkCollision(x, y, w, h)
    if not (x and y and w and h) then
        return nil
    end

    for _, beam in ipairs(emitters) do
        local bx, by, bw, bh = baseBounds(beam)
        if bx and rectsOverlap(bx, by, bw, bh, x, y, w, h) then
            beam.flashTimer = math.max(beam.flashTimer or 0, 1)
            return beam
        end

        if beam.state == "firing" and beam.beamRect then
            local rx, ry, rw, rh = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
            if rw and rh and rw > 0 and rh > 0 and rectsOverlap(rx, ry, rw, rh, x, y, w, h) then
                beam.flashTimer = math.max(beam.flashTimer or 0, 1)
                return beam
            end
        end
    end

    return nil
end

function Lasers:getBounds(beam)
    return baseBounds(beam)
end

local function drawBurnMark(beam)
    if not (beam and beam.impactX and beam.impactY) then
        return
    end

    local alpha = clamp(beam.burnAlpha or 0, 0, 1)
    if alpha <= 0 then
        return
    end

    local radius = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8)
    love.graphics.setColor(0, 0, 0, 0.5 * alpha)
    love.graphics.circle("fill", beam.impactX, beam.impactY, radius)
    love.graphics.setColor(0.1, 0.05, 0.05, 0.7 * alpha)
    love.graphics.circle("fill", beam.impactX, beam.impactY, radius * 0.55)
    love.graphics.setColor(0.95, 0.25, 0.2, 0.18 * alpha)
    love.graphics.circle("line", beam.impactX, beam.impactY, radius * 0.9)
end

local function drawBeam(beam)
    if not beam.beamRect then
        return
    end

    local palette = beam.firePalette or getFirePalette(DEFAULT_FIRE_COLOR)
    local x, y, w, h = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
    if not (x and y and w and h) then
        return
    end

    local t = getTime()
    local facingSign = beam.facing or 1

    if beam.state == "firing" then
        local flicker = 0.82 + 0.18 * math.sin(t * 11 + (beam.beamStartX or 0) * 0.05 + (beam.beamStartY or 0) * 0.05)
        local glowAlpha = (palette.glow[4] or 0.5) * flicker
        love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], glowAlpha)
        love.graphics.rectangle("fill", x - BEAM_GLOW_EXPANSION, y - BEAM_GLOW_EXPANSION, w + BEAM_GLOW_EXPANSION * 2, h + BEAM_GLOW_EXPANSION * 2, 7, 7)

        local innerGlowAlpha = math.min(1, (palette.core[4] or 0.9) * (0.85 + 0.15 * flicker))
        love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], innerGlowAlpha)
        love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 6, 6)

        local rim = palette.rim or palette.core
        love.graphics.setColor(rim[1], rim[2], rim[3], (rim[4] or 1))
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)

        local highlightThickness = math.max(1.5, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.35)
        love.graphics.setColor(1, 0.97, 0.75, 0.55)
        if beam.dir == "horizontal" then
            local centerY = y + h * 0.5
            love.graphics.rectangle("fill", x, centerY - highlightThickness * 0.5, w, highlightThickness, 3, 3)
        else
            local centerX = x + w * 0.5
            love.graphics.rectangle("fill", centerX - highlightThickness * 0.5, y, highlightThickness, h, 3, 3)
        end

        local edgeThickness = math.max(1, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.22)
        love.graphics.setColor(1, 0.65, 0.45, 0.35 + 0.25 * flicker)
        if beam.dir == "horizontal" then
            love.graphics.rectangle("fill", x, y + h - edgeThickness, w, edgeThickness, 3, 3)
            love.graphics.rectangle("fill", x, y, w, edgeThickness, 3, 3)
        else
            love.graphics.rectangle("fill", x + w - edgeThickness, y, edgeThickness, h, 3, 3)
            love.graphics.rectangle("fill", x, y, edgeThickness, h, 3, 3)
        end

        local length = (beam.dir == "horizontal") and w or h
        local pulseSpacing = math.max(24, length / 6)
        local pulseSize = pulseSpacing * 0.55
        local travel = (t * BEAM_PULSE_SPEED * 45 * facingSign) % pulseSpacing
        love.graphics.setColor(1, 0.8, 0.45, 0.25 + 0.35 * flicker)
        if beam.dir == "horizontal" then
            for start = -travel, w, pulseSpacing do
                local segmentStart = math.max(0, start)
                local segmentEnd = math.min(w, start + pulseSize)
                if segmentEnd > segmentStart then
                    love.graphics.rectangle("fill", x + segmentStart, y + h * 0.15, segmentEnd - segmentStart, h * 0.7, 3, 3)
                end
            end

            local sparkCount = math.max(2, math.floor(w / 96))
            love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
            for i = 0, sparkCount do
                local offset = (i / math.max(1, sparkCount)) * w
                local sway = math.sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (h * 0.12)
                local sparkWidth = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
                love.graphics.rectangle("fill", x + offset - sparkWidth * 0.5, y + h * 0.5 + sway - edgeThickness, sparkWidth, edgeThickness * 2, 3, 3)
            end
        else
            for start = -travel, h, pulseSpacing do
                local segmentStart = math.max(0, start)
                local segmentEnd = math.min(h, start + pulseSize)
                if segmentEnd > segmentStart then
                    love.graphics.rectangle("fill", x + w * 0.15, y + segmentStart, w * 0.7, segmentEnd - segmentStart, 3, 3)
                end
            end

            local sparkCount = math.max(2, math.floor(h / 96))
            love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
            for i = 0, sparkCount do
                local offset = (i / math.max(1, sparkCount)) * h
                local sway = math.sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (w * 0.12)
                local sparkHeight = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
                love.graphics.rectangle("fill", x + w * 0.5 + sway - edgeThickness, y + offset - sparkHeight * 0.5, edgeThickness * 2, sparkHeight, 3, 3)
            end
        end
    elseif beam.state == "charging" then
        local duration = beam.chargeDuration or DEFAULT_CHARGE_DURATION
        local remaining = clamp(beam.chargeTimer or 0, 0, duration)
        local progress = (duration <= 0) and 1 or (1 - remaining / duration)
        local alpha = 0.15 + 0.45 * progress
        love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], alpha * 0.45)
        love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 6, 6)
        love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], alpha * 0.85)
        love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 4, 4)

        love.graphics.setColor(1, 0.95, 0.65, 0.25 + 0.35 * progress)
        if beam.dir == "horizontal" then
            local bandHeight = math.max(1.2, h * 0.25)
            love.graphics.rectangle("fill", x, y + h * 0.5 - bandHeight * 0.5, w, bandHeight, 2, 2)
        else
            local bandWidth = math.max(1.2, w * 0.25)
            love.graphics.rectangle("fill", x + w * 0.5 - bandWidth * 0.5, y, bandWidth, h, 2, 2)
        end

        local stripes = 4
        local rim = palette.rim or palette.core
        for i = 0, stripes - 1 do
            local offset = (progress + i / stripes) % 1
            local stripeAlpha = math.max(0, (0.55 - i * 0.08) * (0.35 + progress * 0.65))
            if beam.dir == "horizontal" then
                local stripeX = x + (w - 6) * offset
                love.graphics.setColor(rim[1], rim[2], rim[3], stripeAlpha)
                love.graphics.rectangle("fill", stripeX, y + 1, 6, h - 2, 2, 2)
            else
                local stripeY = y + (h - 6) * offset
                love.graphics.setColor(rim[1], rim[2], rim[3], stripeAlpha)
                love.graphics.rectangle("fill", x + 1, stripeY, w - 2, 6, 2, 2)
            end
        end

        local resonance = math.sin(t * 4 + (beam.randomOffset or 0)) * 0.5 + 0.5
        local shimmer = 0.2 + 0.4 * progress
        love.graphics.setColor(rim[1], rim[2], rim[3], shimmer * (0.3 + resonance * 0.5))
        if beam.dir == "horizontal" then
            love.graphics.rectangle("fill", x, y + h * 0.3, w, h * 0.1, 2, 2)
            love.graphics.rectangle("fill", x, y + h * 0.6, w, h * 0.1, 2, 2)
        else
            love.graphics.rectangle("fill", x + w * 0.3, y, w * 0.1, h, 2, 2)
            love.graphics.rectangle("fill", x + w * 0.6, y, w * 0.1, h, 2, 2)
        end
    end
end

local function drawImpactEffect(beam)
    if beam.state ~= "firing" then
        return
    end

    if not (beam.impactX and beam.impactY) then
        return
    end

    local palette = beam.firePalette or getFirePalette(DEFAULT_FIRE_COLOR)
    local core = palette.core or DEFAULT_FIRE_COLOR
    local rim = palette.rim or core
    local t = getTime()
    local offset = beam.randomOffset or 0
    local flicker = 0.75 + 0.25 * math.sin(t * 10 + offset)
    local baseRadius = (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8

    love.graphics.setColor(core[1], core[2], core[3], 0.35 + 0.4 * flicker)
    love.graphics.circle("fill", beam.impactX, beam.impactY, baseRadius + math.sin(t * 8 + offset) * 1.5)

    local pulse = math.fmod(t * IMPACT_RING_SPEED + offset, 1)
    if pulse < 0 then
        pulse = pulse + 1
    end

    local pulseRadius = IMPACT_FLARE_RADIUS + pulse * IMPACT_RING_RANGE
    local pulseAlpha = math.max(0, 0.55 * (1 - pulse))
    love.graphics.setColor(rim[1], rim[2], rim[3], pulseAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", beam.impactX, beam.impactY, pulseRadius)

    love.graphics.setColor(1, 0.95, 0.75, 0.45 * flicker)
    local sparkLength = IMPACT_FLARE_RADIUS * 1.3
    local spokes = 6
    for i = 0, spokes - 1 do
        local angle = offset + (i / spokes) * (math.pi * 2)
        local dx = math.cos(angle) * sparkLength
        local dy = math.sin(angle) * sparkLength
        love.graphics.line(beam.impactX - dx * 0.35, beam.impactY - dy * 0.35, beam.impactX + dx, beam.impactY + dy)
    end
end

local function drawEmitterBase(beam)
    local baseColor, accentColor = getEmitterColors()
    local tileSize = Arena.tileSize or 24
    local half = tileSize * 0.5
    local bx = (beam.x or 0) - half
    local by = (beam.y or 0) - half
    local flash = clamp(beam.flashTimer or 0, 0, 1)
    local highlightBoost = (beam.state == "firing") and 0.25 or ((beam.state == "charging") and 0.15 or 0)

    local t = getTime()
    local pulse = 0.25 + 0.25 * math.sin(t * 5.5 + (beam.x or 0) * 0.03 + (beam.y or 0) * 0.03)
    local glowAlpha = 0.35 + flash * 0.45 + highlightBoost * 0.6 + pulse * 0.4
    love.graphics.setColor(1, 0.32, 0.25, math.min(0.75, glowAlpha))
    love.graphics.circle("fill", beam.x or 0, beam.y or 0, BASE_GLOW_RADIUS + tileSize * 0.15)

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], (baseColor[4] or 1) + flash * 0.1)
    love.graphics.rectangle("fill", bx, by, tileSize, tileSize, 6, 6)

    love.graphics.setColor(0, 0, 0, 0.45 + flash * 0.25)
    love.graphics.rectangle("line", bx, by, tileSize, tileSize, 6, 6)

    local accentAlpha = (accentColor[4] or 0.8) + flash * 0.2 + highlightBoost
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], math.min(1, accentAlpha))
    love.graphics.rectangle("line", bx + 2, by + 2, tileSize - 4, tileSize - 4, 4, 4)

    love.graphics.setColor(1, 1, 1, 0.18 + highlightBoost * 0.4 + flash * 0.2)
    love.graphics.rectangle("fill", bx + 3, by + 3, tileSize - 6, tileSize * 0.2, 3, 3)

    local slitLength = tileSize * 0.55
    local slitThickness = math.max(3, tileSize * 0.18)
    local cx = beam.x or 0
    local cy = beam.y or 0
    local spin = (t * 2.5 + (beam.randomOffset or 0)) % (math.pi * 2)
    local ringRadius = tileSize * 0.45 + math.sin(t * 3.5 + (beam.randomOffset or 0)) * (tileSize * 0.05)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.3 + flash * 0.4 + highlightBoost * 0.3)
    for i = 0, 2 do
        local angle = spin + i * (math.pi * 2 / 3)
        love.graphics.arc("line", "open", cx, cy, ringRadius, angle - 0.35, angle + 0.35, 16)
    end

    if beam.state == "charging" then
        local chargeLift = (math.sin(t * 6 + (beam.randomOffset or 0)) * 0.5 + 0.5) * tileSize * 0.08
        love.graphics.setColor(1, 0.4, 0.32, 0.45 + flash * 0.4)
        love.graphics.circle("line", cx, cy, ringRadius * 0.65 + chargeLift)
    elseif beam.state == "firing" then
        love.graphics.setColor(1, 0.55, 0.4, 0.35 + flash * 0.45)
        love.graphics.circle("line", cx, cy, ringRadius * 0.8)
    end
    if beam.dir == "horizontal" then
        local dir = beam.facing or 1
        local front = cx + dir * (tileSize * 0.32)
        love.graphics.rectangle("fill", front - slitThickness * 0.5, cy - slitLength * 0.5, slitThickness, slitLength, 3, 3)
    else
        local dir = beam.facing or 1
        local front = cy + dir * (tileSize * 0.32)
        love.graphics.rectangle("fill", cx - slitLength * 0.5, front - slitThickness * 0.5, slitLength, slitThickness, 3, 3)
    end
end

function Lasers:draw()
    if #emitters == 0 then
        return
    end

    love.graphics.push("all")
    love.graphics.setLineWidth(2)

    for _, beam in ipairs(emitters) do
        drawBurnMark(beam)
    end

    for _, beam in ipairs(emitters) do
        drawBeam(beam)
    end

    for _, beam in ipairs(emitters) do
        drawImpactEffect(beam)
    end

    for _, beam in ipairs(emitters) do
        drawEmitterBase(beam)
    end

    love.graphics.pop()
end

return Lasers
