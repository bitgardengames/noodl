local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Audio = require("audio")

local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local sin = math.sin
local random = love.math.random

local Darts = {}

local emitters = {}
local stallTimer = 0

local DARTS_ENABLED = true

local DEFAULT_TELEGRAPH_DURATION = 1.0
local DEFAULT_COOLDOWN_MIN = 3.8
local DEFAULT_COOLDOWN_MAX = 6.2
local DEFAULT_DART_SPEED = 360
local DEFAULT_DART_LENGTH = 26
local DEFAULT_DART_THICKNESS = 12
local BASE_EMITTER_SIZE = 18
local FLASH_DECAY = 3.5
local IMPACT_FLASH_DURATION = 0.32

local BASE_EMITTER_COLOR = {0.32, 0.34, 0.38, 0.95}
local BASE_ACCENT_COLOR = {0.46, 0.56, 0.62, 1.0}
local TELEGRAPH_COLOR = {0.64, 0.74, 0.82, 0.85}
local DART_BODY_COLOR = {0.70, 0.68, 0.60, 1.0}
local DART_TIP_COLOR = {0.82, 0.86, 0.90, 1.0}
local DART_TAIL_COLOR = {0.42, 0.68, 0.64, 1.0}

local function clamp01(value)
        if value <= 0 then
                return 0
        end
        if value >= 1 then
                return 1
        end
        return value
end

local function releaseOccupancy(emitter)
        if not emitter then
                return
        end

        if emitter.col and emitter.row then
                SnakeUtils.setOccupied(emitter.col, emitter.row, false)
        end
end

local function scaleColor(color, factor, alphaFactor)
        if not color then
                return {1, 1, 1, 1}
        end

        local r = clamp01((color[1] or 0) * factor)
        local g = clamp01((color[2] or 0) * factor)
        local b = clamp01((color[3] or 0) * factor)
        local a = clamp01((color[4] or 1) * (alphaFactor or 1))
        return {r, g, b, a}
end

local function getEmitterColors()
        local body = Theme.dartBaseColor or BASE_EMITTER_COLOR
        local accent = Theme.dartAccentColor or BASE_ACCENT_COLOR
        local telegraph = Theme.dartTelegraphColor or TELEGRAPH_COLOR
        local dartBody = Theme.dartBodyColor or DART_BODY_COLOR
        local dartTip = Theme.dartTipColor or DART_TIP_COLOR
        local dartTail = Theme.dartTailColor or DART_TAIL_COLOR
        return body, accent, telegraph, dartBody, dartTip, dartTail
end

local function computeShotTargets(emitter)
        if not emitter then
                return
        end

        local tileSize = Arena.tileSize or 24
        local facing = emitter.facing or 1
        local inset = max(4, tileSize * 0.48)
        local startX = emitter.x or 0
        local startY = emitter.y or 0
        local endX, endY

        if emitter.dir == "horizontal" then
                startX = startX + facing * inset
                endY = startY
                if facing > 0 then
                        endX = (Arena.x or 0) + (Arena.width or 0) - inset
                else
                        endX = (Arena.x or 0) + inset
                end
        else
                startY = startY + facing * inset
                endX = startX
                if facing > 0 then
                        endY = (Arena.y or 0) + (Arena.height or 0) - inset
                else
                        endY = (Arena.y or 0) + inset
                end
        end

        emitter.startX = startX
        emitter.startY = startY
        emitter.endX = endX or startX
        emitter.endY = endY or startY

        local dx = emitter.endX - emitter.startX
        local dy = emitter.endY - emitter.startY
        emitter.travelDistance = sqrt(dx * dx + dy * dy)
        if emitter.travelDistance <= 1e-3 then
                emitter.travelDistance = tileSize
        end

        local desired = emitter.baseFireDuration or nil
        if desired and desired > 0 then
                emitter.fireDuration = desired
                emitter.dartSpeed = emitter.travelDistance / desired
        else
                local speed = emitter.dartSpeed or DEFAULT_DART_SPEED
                if speed <= 0 then
                        speed = DEFAULT_DART_SPEED
                end
                emitter.fireDuration = emitter.travelDistance / speed
        end

        emitter.fireDuration = max(0.28, emitter.fireDuration or 0.28)
        emitter.dartSpeed = emitter.travelDistance / emitter.fireDuration
end

local function randomCooldownDuration(emitter)
        local minCooldown = emitter.fireCooldownMin or DEFAULT_COOLDOWN_MIN
        local maxCooldown = emitter.fireCooldownMax or DEFAULT_COOLDOWN_MAX
        if maxCooldown < minCooldown then
                maxCooldown = minCooldown
        end

        return minCooldown + (maxCooldown - minCooldown) * random()
end

local function enterCooldown(emitter, initial)
        emitter.state = "cooldown"
        emitter.cooldownTimer = randomCooldownDuration(emitter)
        emitter.telegraphTimer = nil
        emitter.fireTimer = nil
        emitter.dartProgress = 0
        emitter.telegraphStrength = initial and 0 or emitter.telegraphStrength or 0
        emitter.shotRect = nil
        emitter.dartX = nil
        emitter.dartY = nil
end

local function enterTelegraph(emitter)
        emitter.state = "telegraph"
        emitter.telegraphTimer = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
        emitter.telegraphStrength = 0
end

local function enterFiring(emitter)
        emitter.state = "firing"
        emitter.fireTimer = emitter.fireDuration or 0.4
        emitter.dartProgress = 0
        emitter.dartX = emitter.startX
        emitter.dartY = emitter.startY
        emitter.shotRect = nil
        emitter.impactTimer = IMPACT_FLASH_DURATION
        if Audio and Audio.playSound then
                Audio:playSound("laser_charge")
        end
end

local function updateShotRect(emitter)
        local thickness = emitter.dartThickness or DEFAULT_DART_THICKNESS
        local length = emitter.dartLength or DEFAULT_DART_LENGTH
        if emitter.dir == "vertical" then
                emitter.shotRect = {
                        (emitter.dartX or emitter.startX or 0) - thickness * 0.5,
                        (emitter.dartY or emitter.startY or 0) - length * 0.5,
                        thickness,
                        length,
                }
        else
                emitter.shotRect = {
                        (emitter.dartX or emitter.startX or 0) - length * 0.5,
                        (emitter.dartY or emitter.startY or 0) - thickness * 0.5,
                        length,
                        thickness,
                }
        end
end

local function updateEmitter(emitter, dt)
        if emitter.state == "cooldown" then
                emitter.cooldownTimer = max(0, (emitter.cooldownTimer or 0) - dt)
                if stallTimer and stallTimer > 0 then
                        return
                end
                if emitter.cooldownTimer <= 0 then
                        enterTelegraph(emitter)
                end
                return
        end

        if emitter.state == "telegraph" then
                if emitter.telegraphTimer == nil then
                        emitter.telegraphTimer = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
                end

                emitter.telegraphTimer = emitter.telegraphTimer - dt
                local duration = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
                local progress = clamp01(1 - (emitter.telegraphTimer or 0) / max(duration, 0.01))
                emitter.telegraphStrength = progress * progress

                if emitter.telegraphTimer <= 0 then
                        enterFiring(emitter)
                end
                return
        end

        if emitter.state == "firing" then
                emitter.fireTimer = (emitter.fireTimer or emitter.fireDuration) - dt
                local duration = emitter.fireDuration or 0.01
                local progress = clamp01(1 - (emitter.fireTimer or 0) / max(duration, 0.01))
                emitter.dartProgress = progress

                emitter.dartX = emitter.startX + (emitter.endX - emitter.startX) * progress
                emitter.dartY = emitter.startY + (emitter.endY - emitter.startY) * progress

                updateShotRect(emitter)

                if emitter.fireTimer <= 0 then
                        emitter.flashTimer = max(emitter.flashTimer or 0, 1)
                        enterCooldown(emitter, false)
                        emitter.lastImpactX = emitter.endX
                        emitter.lastImpactY = emitter.endY
                end
        end

        if emitter.flashTimer and emitter.flashTimer > 0 then
                emitter.flashTimer = max(0, emitter.flashTimer - dt * FLASH_DECAY)
        end

        if emitter.impactTimer and emitter.impactTimer > 0 then
                emitter.impactTimer = emitter.impactTimer - dt
        end
end

function Darts:load()
end

function Darts:reset()
        for _, emitter in ipairs(emitters) do
                releaseOccupancy(emitter)
        end

        for i = #emitters, 1, -1 do
                emitters[i] = nil
        end

        stallTimer = 0
end

function Darts:spawn(x, y, dir, options)
        if not DARTS_ENABLED then
                return nil
        end

        if not (x and y and dir) then
                return nil
        end

        local emitter = {
                x = x,
                y = y,
                dir = dir,
                facing = options and options.facing or 1,
                telegraphDuration = max(0.2, options and options.telegraphDuration or DEFAULT_TELEGRAPH_DURATION),
                dartSpeed = options and options.dartSpeed or DEFAULT_DART_SPEED,
                dartLength = options and options.dartLength or DEFAULT_DART_LENGTH,
                dartThickness = options and options.dartThickness or DEFAULT_DART_THICKNESS,
                baseFireDuration = options and options.fireDuration or nil,
                fireCooldownMin = options and options.fireCooldownMin or DEFAULT_COOLDOWN_MIN,
                fireCooldownMax = options and options.fireCooldownMax or DEFAULT_COOLDOWN_MAX,
                flashTimer = 0,
                telegraphStrength = 0,
                randomOffset = love.math.random() * 1000,
        }

        emitter.col, emitter.row = Arena:getTileFromWorld(x, y)
        SnakeUtils.setOccupied(emitter.col, emitter.row, true)

        computeShotTargets(emitter)
        enterCooldown(emitter, true)

        emitters[#emitters + 1] = emitter
        return emitter
end

function Darts:getEmitters()
        local copies = {}
        for index, emitter in ipairs(emitters) do
                copies[index] = emitter
        end
        return copies
end

function Darts:getEmitterCount()
        return #emitters
end

function Darts:iterateEmitters(callback)
        if type(callback) ~= "function" then
                return
        end

        for index = 1, #emitters do
                local result = callback(emitters[index], index)
                if result ~= nil then
                        return result
                end
        end
end

function Darts:iterateShots(callback)
        if type(callback) ~= "function" then
                return
        end

        for index = 1, #emitters do
                local emitter = emitters[index]
                if emitter and emitter.state == "firing" and emitter.shotRect then
                        local result = callback(emitter, emitter.shotRect, index)
                        if result ~= nil then
                                return result
                        end
                end
        end
end

function Darts:stall(duration)
        if not duration or duration <= 0 then
                return
        end

        stallTimer = (stallTimer or 0) + duration
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
        return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function baseBounds(emitter)
        if not emitter then
                return
        end

        local size = Arena.tileSize or BASE_EMITTER_SIZE
        local half = size * 0.5
        local inset = max(2, size * 0.25)
        if inset > half then
                inset = half
        end

        local width = size - inset * 2
        local height = width
        return (emitter.x or 0) - width * 0.5, (emitter.y or 0) - height * 0.5, width, height
end

function Darts:checkCollision(x, y, w, h)
        if not DARTS_ENABLED then
                return nil
        end

        if not (x and y and w and h) then
                return nil
        end

        local snakeW = max(0, w)
        local snakeH = max(0, h)
        if snakeW <= 0 or snakeH <= 0 then
                return nil
        end

        local halfW = snakeW * 0.5
        local halfH = snakeH * 0.5
        local snakeX = x - halfW
        local snakeY = y - halfH

        for _, emitter in ipairs(emitters) do
                local bx, by, bw, bh = baseBounds(emitter)
                if bx and rectsOverlap(bx, by, bw, bh, snakeX, snakeY, snakeW, snakeH) then
                        emitter.flashTimer = max(emitter.flashTimer or 0, 1)
                        return emitter
                end

                if emitter.state == "firing" and emitter.shotRect then
                        local rx, ry, rw, rh = emitter.shotRect[1], emitter.shotRect[2], emitter.shotRect[3], emitter.shotRect[4]
                        if rw and rh and rw > 0 and rh > 0 and rectsOverlap(rx, ry, rw, rh, snakeX, snakeY, snakeW, snakeH) then
                                emitter.flashTimer = max(emitter.flashTimer or 0, 1)
                                return emitter
                        end
                end
        end

        return nil
end

function Darts:onShieldedHit(emitter)
        if not emitter then
                return
        end

        emitter.flashTimer = max(emitter.flashTimer or 0, 1)
end

function Darts:update(dt)
        if not DARTS_ENABLED then
                return
        end

        dt = dt or 0

        local stall = stallTimer or 0
        if stall > 0 then
                if dt <= stall then
                        stallTimer = max(0, stall - dt)
                        return
                end

                dt = dt - stall
                stallTimer = 0
        end

        for index = 1, #emitters do
                updateEmitter(emitters[index], dt)
        end
end

local function drawEmitter(emitter)
        local bodyColor, accentColor, telegraphColor = getEmitterColors()
        local size = BASE_EMITTER_SIZE
        local half = size * 0.5
        local baseX = (emitter.x or 0) - half
        local baseY = (emitter.y or 0) - half

        love.graphics.push("all")

        local housingColor = bodyColor
        local insetColor = scaleColor(bodyColor, 0.78, 1)
        love.graphics.setColor(housingColor)
        love.graphics.rectangle("fill", baseX, baseY, size, size, 4, 4)

        love.graphics.setColor(insetColor)
        love.graphics.rectangle("fill", baseX + 2, baseY + 2, size - 4, size - 4, 3, 3)

        local strapColor = scaleColor(accentColor, 0.85, 0.9)
        local strapShadow = scaleColor(accentColor, 0.6, 0.8)
        love.graphics.setColor(strapShadow)
        if emitter.dir == "horizontal" then
                love.graphics.rectangle("fill", baseX - 2, baseY + half + 1, size + 4, 5, 2, 2)
        else
                love.graphics.rectangle("fill", baseX + half + 1, baseY - 2, 5, size + 4, 2, 2)
        end

        love.graphics.setColor(strapColor)
        if emitter.dir == "horizontal" then
                love.graphics.rectangle("fill", baseX - 2, baseY + half - 4, size + 4, 6, 2, 2)
        else
                love.graphics.rectangle("fill", baseX + half - 4, baseY - 2, 6, size + 4, 2, 2)
        end

        local flash = emitter.flashTimer or 0
        if flash > 0 then
                local pulse = clamp01(flash)
                love.graphics.setColor(1, 1, 1, 0.45 * pulse)
                love.graphics.rectangle("line", baseX - 4, baseY - 4, size + 8, size + 8, 8, 8)
        end

        local strength = emitter.telegraphStrength or 0
        if strength > 0 then
                local alpha = clamp01((telegraphColor[4] or 1) * (0.25 + 0.5 * strength))
                love.graphics.setColor(telegraphColor[1], telegraphColor[2], telegraphColor[3], alpha)
                if emitter.dir == "horizontal" then
                        love.graphics.rectangle("fill", (emitter.x or 0) - half - 7, baseY + half - 5, size + 14, 10, 4, 4)
                else
                        love.graphics.rectangle("fill", baseX + half - 5, (emitter.y or 0) - half - 7, 10, size + 14, 4, 4)
                end
        end

        love.graphics.setColor(accentColor)
        love.graphics.rectangle("line", baseX + 1, baseY + 1, size - 2, size - 2, 3, 3)
        love.graphics.rectangle("line", baseX + 3, baseY + 3, size - 6, size - 6, 3, 3)

        local rivetColor = scaleColor(accentColor, 0.55, 1)
        love.graphics.setColor(rivetColor)
        love.graphics.rectangle("fill", baseX + size * 0.2, baseY + size * 0.2, 2, 2)
        love.graphics.rectangle("fill", baseX + size * 0.72, baseY + size * 0.28, 2, 2)
        love.graphics.rectangle("fill", baseX + size * 0.28, baseY + size * 0.72, 2, 2)
        love.graphics.rectangle("fill", baseX + size * 0.75, baseY + size * 0.75, 2, 2)

        love.graphics.pop()
end

local function drawTelegraphPath(emitter)
        if not (emitter and emitter.state == "telegraph") then
                return
        end

        local _, accentColor, telegraphColor = getEmitterColors()
        local strength = emitter.telegraphStrength or 0
        if strength <= 0 then
                return
        end

        local travel = emitter.travelDistance or 0
        if travel <= 0.01 then
                return
        end

        love.graphics.push("all")
        local dx = emitter.endX - emitter.startX
        local dy = emitter.endY - emitter.startY

        local dashSpacing = 16
        local dashLength = 7 + strength * 3
        local offset = ((emitter.randomOffset or 0) * 0.5) % dashSpacing
        local teleAlpha = clamp01((telegraphColor[4] or 1) * (0.35 + 0.45 * strength))
        love.graphics.setColor(telegraphColor[1], telegraphColor[2], telegraphColor[3], teleAlpha)
        for distance = offset, travel, dashSpacing do
                local progress = distance / travel
                local px = emitter.startX + dx * progress
                local py = emitter.startY + dy * progress
                if emitter.dir == "horizontal" then
                        love.graphics.rectangle("fill", px - dashLength * 0.5, py - 1, dashLength, 2, 1, 1)
                else
                        love.graphics.rectangle("fill", px - 1, py - dashLength * 0.5, 2, dashLength, 1, 1)
                end
        end

        local accentAlpha = clamp01((accentColor[4] or 1) * (0.25 + 0.5 * strength))
        love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentAlpha)
        if emitter.dir == "horizontal" then
                for distance = offset + dashSpacing * 0.5, travel, dashSpacing do
                        local progress = distance / travel
                        local px = emitter.startX + dx * progress
                        love.graphics.rectangle("fill", px - 1, emitter.startY - 4, 2, 8, 1, 1)
                end
                local facing = emitter.facing or 1
                love.graphics.rectangle("fill", emitter.endX - facing * 4, emitter.endY - 6, 3, 12, 1, 1)
        else
                for distance = offset + dashSpacing * 0.5, travel, dashSpacing do
                        local progress = distance / travel
                        local py = emitter.startY + dy * progress
                        love.graphics.rectangle("fill", emitter.startX - 4, py - 1, 8, 2, 1, 1)
                end
                local facing = emitter.facing or 1
                love.graphics.rectangle("fill", emitter.endX - 6, emitter.endY - facing * 4, 12, 3, 1, 1)
        end

        love.graphics.pop()
end

local function drawDart(emitter)
        if not (emitter and emitter.state == "firing" and emitter.shotRect) then
                return
        end

        local _, _, _, bodyColor, tipColor, tailColor = getEmitterColors()
        local rx, ry, rw, rh = emitter.shotRect[1], emitter.shotRect[2], emitter.shotRect[3], emitter.shotRect[4]
        if not (rx and ry and rw and rh) then
                return
        end

        love.graphics.push("all")

        if emitter.dir == "horizontal" then
                local shaftHeight = rh * 0.34
                local shaftY = ry + (rh - shaftHeight) * 0.5
                local facing = emitter.facing or 1
                local tipX = (emitter.dartX or emitter.startX or 0) + facing * (rw * 0.5)
                local tailX = (emitter.dartX or emitter.startX or 0) - facing * (rw * 0.5)
                local tipLength = 8
                local tailInset = 6
                local shaftStart = tailX + facing * tailInset
                local shaftEnd = tipX - facing * tipLength
                local shaftX = min(shaftStart, shaftEnd)
                local shaftWidth = abs(shaftEnd - shaftStart)

                love.graphics.setColor(bodyColor)
                love.graphics.rectangle("fill", shaftX, shaftY, shaftWidth, shaftHeight, 3, 3)

                local highlight = scaleColor(bodyColor, 1.12, 0.9)
                love.graphics.setColor(highlight)
                love.graphics.rectangle("fill", shaftX, shaftY + shaftHeight * 0.18, shaftWidth, shaftHeight * 0.32, 3, 3)

                local shadow = scaleColor(bodyColor, 0.7, 1)
                love.graphics.setColor(shadow)
                love.graphics.rectangle("fill", shaftX, shaftY + shaftHeight * 0.58, shaftWidth, shaftHeight * 0.34, 3, 3)

                local baseY = ry + rh * 0.5
                local fletchInner = tailX + facing * (tailInset * 0.35)
                local fletchOuter = tailX - facing * (tailInset * 1.4 + 4)
                love.graphics.setColor(tailColor)
                love.graphics.polygon("fill",
                        fletchOuter, baseY,
                        fletchInner, baseY - rh * 0.55,
                        tailX + facing * 2, baseY - rh * 0.22)
                love.graphics.polygon("fill",
                        fletchOuter, baseY,
                        fletchInner, baseY + rh * 0.55,
                        tailX + facing * 2, baseY + rh * 0.22)

                love.graphics.setColor(tipColor)
                love.graphics.polygon("fill",
                        tipX, baseY,
                        shaftEnd, baseY - shaftHeight * 1.05,
                        shaftEnd, baseY + shaftHeight * 1.05)
        else
                local shaftWidth = rw * 0.34
                local shaftX = rx + (rw - shaftWidth) * 0.5
                local facing = emitter.facing or 1
                local tipY = (emitter.dartY or emitter.startY or 0) + facing * (rh * 0.5)
                local tailY = (emitter.dartY or emitter.startY or 0) - facing * (rh * 0.5)
                local tipLength = 8
                local tailInset = 6
                local shaftStart = tailY + facing * tailInset
                local shaftEnd = tipY - facing * tipLength
                local shaftY = min(shaftStart, shaftEnd)
                local shaftHeight = abs(shaftEnd - shaftStart)

                love.graphics.setColor(bodyColor)
                love.graphics.rectangle("fill", shaftX, shaftY, shaftWidth, shaftHeight, 3, 3)

                local highlight = scaleColor(bodyColor, 1.12, 0.9)
                love.graphics.setColor(highlight)
                love.graphics.rectangle("fill", shaftX + shaftWidth * 0.18, shaftY, shaftWidth * 0.32, shaftHeight, 3, 3)

                local shadow = scaleColor(bodyColor, 0.7, 1)
                love.graphics.setColor(shadow)
                love.graphics.rectangle("fill", shaftX + shaftWidth * 0.58, shaftY, shaftWidth * 0.34, shaftHeight, 3, 3)

                local baseX = rx + rw * 0.5
                local fletchInner = tailY + facing * (tailInset * 0.35)
                local fletchOuter = tailY - facing * (tailInset * 1.4 + 4)
                love.graphics.setColor(tailColor)
                love.graphics.polygon("fill",
                        baseX, fletchOuter,
                        baseX - rw * 0.55, fletchInner,
                        baseX - rw * 0.22, tailY + facing * 2)
                love.graphics.polygon("fill",
                        baseX, fletchOuter,
                        baseX + rw * 0.55, fletchInner,
                        baseX + rw * 0.22, tailY + facing * 2)

                love.graphics.setColor(tipColor)
                love.graphics.polygon("fill",
                        baseX, tipY,
                        baseX - shaftWidth * 1.05, shaftEnd,
                        baseX + shaftWidth * 1.05, shaftEnd)
        end

        love.graphics.pop()

        if emitter.impactTimer and emitter.impactTimer > 0 then
                local age = clamp01(1 - emitter.impactTimer / IMPACT_FLASH_DURATION)
                local radius = 10 + age * 20
                local alpha = clamp01(emitter.impactTimer / IMPACT_FLASH_DURATION)
                love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], 0.4 * alpha)
                love.graphics.circle("line", emitter.dartX or emitter.endX, emitter.dartY or emitter.endY, radius, 16)
        end
end

function Darts:draw()
        if not DARTS_ENABLED then
                return
        end

        for index = 1, #emitters do
                local emitter = emitters[index]
                drawEmitter(emitter)
                drawTelegraphPath(emitter)
                drawDart(emitter)
        end
end

return Darts
