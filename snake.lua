local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local DrawSnake = require("snakedraw")
local Rocks = require("rocks")
local Saws = require("saws")
local UI = require("ui")
local Fruit = require("fruit")
local UpgradeVisuals = require("upgradevisuals")
local Particles = require("particles")
local SessionStats = require("sessionstats")
local Score = require("score")
local SnakeCosmetics = require("snakecosmetics")

local Snake = {}

local unpack = table.unpack or unpack

local DEBUG_DRAW_COLLISION_SPACE = false

local screenW, screenH
local direction = { x = 1, y = 0 }
local pendingDir = { x = 1, y = 0 }
local trail = {}
local descendingHole = nil
local segmentCount = 1
local reverseControls = false
local popTimer = 0
local isDead = false
local fruitsSinceLastTurn = 0
local severedPieces = {}

local SEVERED_TAIL_LIFE = 0.9

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
-- distance travelled since last grid snap (in world units)
local moveProgress = 0
local POP_DURATION = SnakeUtils.POP_DURATION
local SHIELD_FLASH_DURATION = 0.3
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
-- movement baseline + modifiers
Snake.baseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.speedMult   = 1.0 -- stackable multiplier (upgrade-friendly)
Snake.crashShields = 0 -- crash protection: number of hits the snake can absorb
Snake.extraGrowth = 0
Snake.shieldBurst = nil
Snake.shieldFlashTimer = 0
Snake.stonebreakerStacks = 0
Snake.stoneSkinSawGrace = 0
Snake.dash = nil
Snake.timeDilation = nil

local function resolveTimeDilationScale(ability)
    if ability and ability.active then
        local scale = ability.timeScale or 1
        if not (scale and scale > 0) then
            scale = 0.05
        end
        return scale
    end

    return 1
end

-- getters / mutators (safe API for upgrades)
function Snake:getSpeed()
    local speed = (self.baseSpeed or 1) * (self.speedMult or 1)
    local scale = resolveTimeDilationScale(self.timeDilation)
    if scale ~= 1 then
        speed = speed * scale
    end

    return speed
end

function Snake:addSpeedMultiplier(mult)
    self.speedMult = (self.speedMult or 1) * (mult or 1)
end

function Snake:addCrashShields(n)
    n = n or 1
    local previous = self.crashShields or 0
    local updated = previous + n
    if updated < 0 then
        updated = 0
    end
    self.crashShields = updated

    if n ~= 0 then
        UI:setCrashShields(self.crashShields)
    end

    if n and n > 0 then
        local headX, headY = self:getHead()
        if headX and headY then
            local extra = math.max(0, math.floor(n - 1))
            UpgradeVisuals:spawn(headX, headY, {
                color = {0.68, 0.88, 1.0, 1},
                badge = "shield",
                ringCount = math.min(4, 2 + extra),
                outerRadius = 46 + math.min(18, extra * 6),
                innerRadius = 14,
                life = 0.78 + math.min(0.3, extra * 0.08),
                badgeScale = 1 + math.min(0.35, extra * 0.12),
                glowAlpha = 0.28,
                haloAlpha = 0.18,
            })
        end
    end
end

function Snake:consumeCrashShield()
    if (self.crashShields or 0) > 0 then
        self.crashShields = self.crashShields - 1
        self.shieldFlashTimer = SHIELD_FLASH_DURATION
        UI:setCrashShields(self.crashShields)
        local headX, headY = self:getHead()
        if headX and headY then
            UpgradeVisuals:spawn(headX, headY, {
                color = {1, 0.66, 0.4, 1},
                badge = "shield",
                ringCount = 3,
                outerRadius = 44,
                innerRadius = 12,
                life = 0.62,
                badgeScale = 0.95,
                glowAlpha = 0.24,
                haloAlpha = 0.18,
            })
        end
        SessionStats:add("crashShieldsSaved", 1)
        return true
    end
    return false
end

function Snake:resetModifiers()
    self.speedMult    = 1.0
    self.crashShields = 0
    self.extraGrowth  = 0
    self.shieldBurst  = nil
    self.shieldFlashTimer = 0
    self.stonebreakerStacks = 0
    self.stoneSkinSawGrace = 0
    self.dash = nil
    self.timeDilation = nil
    self.adrenaline = nil
    UI:setCrashShields(self.crashShields or 0, { silent = true, immediate = true })
end

function Snake:setStonebreakerStacks(count)
    count = count or 0
    if count < 0 then count = 0 end
    self.stonebreakerStacks = count
end

function Snake:addShieldBurst(config)
    config = config or {}
    self.shieldBurst = self.shieldBurst or { rocks = 0, stall = 0 }
    local rocks = config.rocks or 0
    local stall = config.stall or 0
    if rocks ~= 0 then
        self.shieldBurst.rocks = (self.shieldBurst.rocks or 0) + rocks
    end
    if stall ~= 0 then
        self.shieldBurst.stall = (self.shieldBurst.stall or 0) + stall
    end
end

function Snake:onShieldConsumed(x, y, cause)
    local burstTriggered = false
    local burstRocks = 0
    local burstStall = 0

    if self.shieldBurst then
        local rocksToBreak = math.floor(self.shieldBurst.rocks or 0)
        if rocksToBreak > 0 and Rocks and Rocks.shatterNearest then
            Rocks:shatterNearest(x or 0, y or 0, rocksToBreak)
            burstTriggered = true
            burstRocks = rocksToBreak
        end

        local stallDuration = self.shieldBurst.stall or 0
        if stallDuration > 0 and Saws and Saws.stall then
            Saws:stall(stallDuration)
            burstTriggered = true
            burstStall = stallDuration
        end
    end

    if burstTriggered and (not x or not y) and self.getHead then
        x, y = self:getHead()
    end

    local Upgrades = package.loaded["upgrades"]
    if Upgrades and Upgrades.notify then
        Upgrades:notify("shieldConsumed", {
            x = x,
            y = y,
            cause = cause or "unknown",
            burstTriggered = burstTriggered,
            burst = burstTriggered and {
                rocks = burstRocks,
                stall = burstStall,
            } or nil,
        })
    elseif burstTriggered and x and y then
        UpgradeVisuals:spawn(x, y, {
            color = {0.72, 0.9, 1, 1},
            glowColor = {0.58, 0.78, 1, 1},
            haloColor = {0.46, 0.66, 1, 0.22},
            badge = "burst",
            badgeScale = 1.08,
            ringCount = 4,
            ringSpacing = 14,
            ringWidth = 5,
            innerRadius = 18,
            outerRadius = 86,
            life = 0.58,
            glowAlpha = 0.28,
            haloAlpha = 0.2,
        })

        if Particles and Particles.spawnBurst then
            Particles:spawnBurst(x, y, {
                count = 22,
                speed = 140,
                speedVariance = 70,
                life = 0.52,
                size = 7,
                color = {0.58, 0.82, 1, 0.9},
                drag = 3.2,
                fadeTo = 0,
            })
        end
    end
end

function Snake:addStoneSkinSawGrace(n)
    n = n or 1
    if n <= 0 then return end
    self.stoneSkinSawGrace = (self.stoneSkinSawGrace or 0) + n
end

function Snake:consumeStoneSkinSawGrace()
    if (self.stoneSkinSawGrace or 0) > 0 then
        self.stoneSkinSawGrace = self.stoneSkinSawGrace - 1
        self.shieldFlashTimer = SHIELD_FLASH_DURATION
        return true
    end
    return false
end

-- >>> Small integration note:
-- Inside your snake:update(dt) where you compute movement, replace any hard-coded speed use with:
-- local speed = Snake:getSpeed()
-- and then use `speed` for position updates. This gives upgrades an immediate effect.

-- helpers
local function snapToCenter(v)
    return (math.floor(v / SEGMENT_SPACING) + 0.5) * SEGMENT_SPACING
end

local function toCell(x, y)
    return math.floor(x / SEGMENT_SPACING + 0.5), math.floor(y / SEGMENT_SPACING + 0.5)
end

local function findCircleIntersection(px, py, qx, qy, cx, cy, radius)
    local dx = qx - px
    local dy = qy - py
    local fx = px - cx
    local fy = py - cy

    local a = dx * dx + dy * dy
    if a == 0 then
        return nil, nil
    end

    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - radius * radius
    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return nil, nil
    end

    discriminant = math.sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    local t
    if t1 >= 0 and t1 <= 1 then
        t = t1
    elseif t2 >= 0 and t2 <= 1 then
        t = t2
    end

    if not t then
        return nil, nil
    end

    return px + t * dx, py + t * dy
end

local function normalizeDirection(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0
    end
    return dx / len, dy / len
end

local function closestPointOnSegment(px, py, ax, ay, bx, by)
    if not (px and py and ax and ay and bx and by) then
        return nil, nil, math.huge, 0
    end

    local abx = bx - ax
    local aby = by - ay
    local abLenSq = abx * abx + aby * aby
    if abLenSq <= 1e-6 then
        local dx = px - ax
        local dy = py - ay
        return ax, ay, dx * dx + dy * dy, 0
    end

    local apx = px - ax
    local apy = py - ay
    local t = (apx * abx + apy * aby) / abLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local cx = ax + abx * t
    local cy = ay + aby * t
    local dx = px - cx
    local dy = py - cy

    return cx, cy, dx * dx + dy * dy, t
end

local function copySegmentData(segment)
    if not segment then
        return nil
    end

    local copy = {}
    for key, value in pairs(segment) do
        copy[key] = value
    end

    return copy
end

local function trimHoleSegments(hole)
    if not hole or not trail or #trail == 0 then
        return
    end

    local hx, hy = hole.x, hole.y
    local radius = hole.radius or 0
    if radius <= 0 then
        return
    end

    local workingTrail = {}
    for i = 1, #trail do
        local seg = trail[i]
        if not seg then break end
        workingTrail[i] = {
            drawX = seg.drawX,
            drawY = seg.drawY,
            dirX = seg.dirX,
            dirY = seg.dirY,
        }
    end

    local radiusSq = radius * radius
    local consumed = 0
    local lastInside = nil
    local removedAny = false
    local i = 1

    while i <= #workingTrail do
        local seg = workingTrail[i]
        local x = seg and seg.drawX
        local y = seg and seg.drawY

        if not (x and y) then
            break
        end

        local dx = x - hx
        local dy = y - hy
        if dx * dx + dy * dy <= radiusSq then
            removedAny = true
            lastInside = { x = x, y = y, dirX = seg.dirX, dirY = seg.dirY }

            local nextSeg = workingTrail[i + 1]
            if nextSeg then
                local nx, ny = nextSeg.drawX, nextSeg.drawY
                if nx and ny then
                    local segDx = nx - x
                    local segDy = ny - y
                    consumed = consumed + math.sqrt(segDx * segDx + segDy * segDy)
                end
            end

            table.remove(workingTrail, i)
        else
            break
        end
    end

    local newHead = workingTrail[1]
    if removedAny and newHead and lastInside then
        local oldDx = newHead.drawX - lastInside.x
        local oldDy = newHead.drawY - lastInside.y
        local oldLen = math.sqrt(oldDx * oldDx + oldDy * oldDy)
        if oldLen > 0 then
            consumed = consumed - oldLen
        end

        local ix, iy = findCircleIntersection(lastInside.x, lastInside.y, newHead.drawX, newHead.drawY, hx, hy, radius)
        if ix and iy then
            local newDx = ix - lastInside.x
            local newDy = iy - lastInside.y
            local newLen = math.sqrt(newDx * newDx + newDy * newDy)
            consumed = consumed + newLen
            newHead.drawX = ix
            newHead.drawY = iy
        else
            -- fallback: if no intersection, clamp head to previous inside point
            newHead.drawX = lastInside.x
            newHead.drawY = lastInside.y
        end
    end

    hole.consumedLength = consumed

    if newHead and newHead.drawX and newHead.drawY then
        hole.entryPointX = newHead.drawX
        hole.entryPointY = newHead.drawY
    elseif lastInside then
        hole.entryPointX = lastInside.x
        hole.entryPointY = lastInside.y
    end

    if lastInside and lastInside.dirX and lastInside.dirY then
        hole.entryDirX, hole.entryDirY = normalizeDirection(lastInside.dirX, lastInside.dirY)
    end
end

local function debugDrawCollisionSpace(trailData, headX, headY)
    if not DEBUG_DRAW_COLLISION_SPACE then
        return
    end

    if not (love and love.graphics) then
        return
    end

    love.graphics.push("all")

    if headX and headY then
        love.graphics.setColor(1, 0, 0, 0.12)
        love.graphics.rectangle("fill", headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
        love.graphics.setColor(1, 0, 0, 0.45)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
    end

    if trailData and #trailData > 1 then
        local guardDistance = SEGMENT_SPACING * 0.9
        local traveled = 0
        local coords = {}

        local first = trailData[1]
        local prevX = first and (first.drawX or first.x)
        local prevY = first and (first.drawY or first.y)

        if prevX and prevY then
            for index = 2, #trailData do
                local segment = trailData[index]
                local currX = segment and (segment.drawX or segment.x)
                local currY = segment and (segment.drawY or segment.y)

                if not (currX and currY) then
                    break
                end

                local dx = currX - prevX
                local dy = currY - prevY
                local segLen = math.sqrt(dx * dx + dy * dy)

                if segLen > 1e-6 then
                    local remainingGuard = guardDistance - traveled
                    if remainingGuard < 0 then
                        remainingGuard = 0
                    end

                    if remainingGuard < segLen then
                        local startT = remainingGuard / segLen
                        local startX = prevX + dx * startT
                        local startY = prevY + dy * startT

                        if #coords == 0 then
                            coords[#coords + 1] = startX
                            coords[#coords + 1] = startY
                        elseif startT > 0 then
                            coords[#coords + 1] = startX
                            coords[#coords + 1] = startY
                        end

                        coords[#coords + 1] = currX
                        coords[#coords + 1] = currY
                    end

                    traveled = traveled + segLen
                else
                    traveled = traveled + segLen
                end

                prevX, prevY = currX, currY
            end
        end

        if #coords >= 4 then
            love.graphics.setLineCap("round")
            love.graphics.setLineJoin("round")

            love.graphics.setColor(1, 0, 0, 0.12)
            love.graphics.setLineWidth(SEGMENT_SIZE)
            love.graphics.line(unpack(coords))

            love.graphics.setColor(1, 0, 0, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.line(unpack(coords))
        end
    end

    love.graphics.pop()
end

local function trimTrailToSegmentLimit()
    if not trail or #trail == 0 then
        return
    end

    local consumedLength = (descendingHole and descendingHole.consumedLength) or 0
    local maxLen = math.max(0, segmentCount * SEGMENT_SPACING - consumedLength)

    if maxLen <= 0 then
        local head = trail[1]
        trail = {}
        if head then
            trail[1] = {
                drawX = head.drawX,
                drawY = head.drawY,
                dirX = head.dirX,
                dirY = head.dirY,
            }
        end
        return
    end

    local traveled = 0
    local i = 2
    while i <= #trail do
        local prev = trail[i - 1]
        local seg = trail[i]
        local px, py = prev and (prev.drawX or prev.x), prev and (prev.drawY or prev.y)
        local sx, sy = seg and (seg.drawX or seg.x), seg and (seg.drawY or seg.y)

        if not (px and py and sx and sy) then
            for j = #trail, i, -1 do
                table.remove(trail, j)
            end
            break
        end

        local dx = px - sx
        local dy = py - sy
        local segLen = math.sqrt(dx * dx + dy * dy)

        if segLen <= 0 then
            table.remove(trail, i)
        else
            if traveled + segLen > maxLen then
                local excess = traveled + segLen - maxLen
                local t = 1 - (excess / segLen)
                local tailX = px - dx * t
                local tailY = py - dy * t

                for j = #trail, i + 1, -1 do
                    table.remove(trail, j)
                end

                seg.drawX = tailX
                seg.drawY = tailY
                if not seg.dirX or not seg.dirY then
                    seg.dirX = direction.x
                    seg.dirY = direction.y
                end
                break
            else
                traveled = traveled + segLen
                i = i + 1
            end
        end
    end
end

local function drawDescendingIntoHole(hole)
    if not hole then
        return
    end

    local consumed = hole.consumedLength or 0
    local depth = hole.renderDepth or 0
    if consumed <= 0 and depth <= 0 then
        return
    end

    local hx = hole.x or 0
    local hy = hole.y or 0
    local entryX = hole.entryPointX or hx
    local entryY = hole.entryPointY or hy

    local dirX, dirY = hole.entryDirX or 0, hole.entryDirY or 0
    local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
    if dirLen <= 1e-4 then
        dirX = hx - entryX
        dirY = hy - entryY
        dirLen = math.sqrt(dirX * dirX + dirY * dirY)
    end

    if dirLen <= 1e-4 then
        dirX, dirY = 0, -1
    else
        dirX, dirY = dirX / dirLen, dirY / dirLen
    end

    local toCenterX = hx - entryX
    local toCenterY = hy - entryY
    if toCenterX * dirX + toCenterY * dirY < 0 then
        dirX, dirY = -dirX, -dirY
    end

    local bodyColor = SnakeCosmetics:getBodyColor() or { 1, 1, 1, 1 }
    local r = bodyColor[1] or 1
    local g = bodyColor[2] or 1
    local b = bodyColor[3] or 1
    local a = bodyColor[4] or 1

    local baseRadius = SEGMENT_SIZE * 0.5
    local steps = math.max(1, math.min(5, math.floor((consumed + SEGMENT_SPACING * 0.25) / (SEGMENT_SPACING * 0.7)) + 1))

    local perpX, perpY = -dirY, dirX
    local wobble = 0
    if hole.time then
        wobble = math.sin(hole.time * 4.6) * 0.35
    end

    love.graphics.setLineWidth(2)

    for layer = 0, steps - 1 do
        local layerT = math.min(1, depth + layer * 0.12)
        local fade = 1 - layerT
        local radius = baseRadius * (1 - 0.25 * layer) * (0.7 + 0.3 * fade)
        radius = math.max(baseRadius * 0.25, radius)

        local lateral = wobble * (0.45 + 0.3 * layer) * fade
        local px = entryX + (hx - entryX) * layerT + perpX * radius * lateral
        local py = entryY + (hy - entryY) * layerT + perpY * radius * lateral

        local alpha = a * (0.85 - 0.12 * layer) * (0.65 + 0.35 * fade)
        love.graphics.setColor(r, g, b, math.max(0, math.min(1, alpha)))
        love.graphics.circle("fill", px, py, radius)

        local outlineAlpha = 0.25 + 0.35 * (1 - fade)
        love.graphics.setColor(0, 0, 0, math.max(0, math.min(1, outlineAlpha)))
        love.graphics.circle("line", px, py, radius)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

local function collectUpgradeVisuals(self)
    local visuals = nil

    if (self.stonebreakerStacks or 0) > 0 then
        visuals = visuals or {}
        local progress = 0
        if Rocks.getShatterProgress then
            progress = Rocks:getShatterProgress()
        end
        local rate = 0
        if Rocks.getShatterRate then
            rate = Rocks:getShatterRate()
        else
            rate = Rocks.shatterOnFruit or 0
        end
        visuals.stonebreaker = {
            stacks = self.stonebreakerStacks or 0,
            progress = progress,
            rate = rate,
        }
    end

    if self.adrenaline and self.adrenaline.active then
        visuals = visuals or {}
        visuals.adrenaline = {
            active = true,
            timer = self.adrenaline.timer or 0,
            duration = self.adrenaline.duration or 0,
        }
    end

    if self.timeDilation then
        visuals = visuals or {}
        visuals.timeDilation = {
            active = self.timeDilation.active or false,
            timer = self.timeDilation.timer or 0,
            duration = self.timeDilation.duration or 0,
            cooldown = self.timeDilation.cooldown or 0,
            cooldownTimer = self.timeDilation.cooldownTimer or 0,
        }
    end

    if self.dash then
        visuals = visuals or {}
        visuals.dash = {
            active = self.dash.active or false,
            timer = self.dash.timer or 0,
            duration = self.dash.duration or 0,
            cooldown = self.dash.cooldown or 0,
            cooldownTimer = self.dash.cooldownTimer or 0,
        }
    end

    return visuals
end

-- Build initial trail aligned to CELL CENTERS
local function buildInitialTrail()
    local t = {}
    local midCol = math.floor(Arena.cols / 2)
    local midRow = math.floor(Arena.rows / 2)
    local startX, startY = Arena:getCenterOfTile(midCol, midRow)

    for i = 0, segmentCount - 1 do
        local cx = startX - i * SEGMENT_SPACING * direction.x
        local cy = startY - i * SEGMENT_SPACING * direction.y
        table.insert(t, {
            drawX = cx, drawY = cy,
            dirX = direction.x, dirY = direction.y
        })
    end
    return t
end

function Snake:load(w, h)
    screenW, screenH = w, h
    direction = { x = 1, y = 0 }
    pendingDir = { x = 1, y = 0 }
    segmentCount = 1
    reverseControls = false
    popTimer = 0
    moveProgress = 0
    isDead = false
    self.reverseState = false
    self.shieldFlashTimer = 0
    trail = buildInitialTrail()
    descendingHole = nil
    fruitsSinceLastTurn = 0
    severedPieces = {}
end

local function getUpgradesModule()
    return package.loaded["upgrades"]
end

function Snake:setReverseControls(state)
    reverseControls = state
end

function Snake:setDirection(name)
    if not isDead then
        pendingDir = SnakeUtils.calculateDirection(direction, name, reverseControls)
    end
end

function Snake:getDirection()
    return direction
end

function Snake:getHead()
    local head = trail[1]
    if not head then
        return nil, nil
    end
    return head.drawX, head.drawY
end

function Snake:setHeadPosition(x, y)
    local head = trail[1]
    if not head then
        return
    end

    head.drawX = x
    head.drawY = y
end

function Snake:translate(dx, dy)
    dx = dx or 0
    dy = dy or 0
    if dx == 0 and dy == 0 then
        return
    end

    for i = 1, #trail do
        local seg = trail[i]
        if seg then
            seg.drawX = seg.drawX + dx
            seg.drawY = seg.drawY + dy
        end
    end

    if descendingHole then
        descendingHole.x = (descendingHole.x or 0) + dx
        descendingHole.y = (descendingHole.y or 0) + dy
        if descendingHole.entryPointX then
            descendingHole.entryPointX = descendingHole.entryPointX + dx
        end
        if descendingHole.entryPointY then
            descendingHole.entryPointY = descendingHole.entryPointY + dy
        end
    end
end

function Snake:setDirectionVector(dx, dy)
    if isDead then return end

    dx = dx or 0
    dy = dy or 0

    local nx, ny = normalizeDirection(dx, dy)
    if nx == 0 and ny == 0 then
        return
    end

    local prevX, prevY = direction.x, direction.y
    direction = { x = nx, y = ny }
    pendingDir = { x = nx, y = ny }
    if prevX ~= direction.x or prevY ~= direction.y then
        fruitsSinceLastTurn = 0
    end
end

function Snake:getHeadCell()
    local hx, hy = self:getHead()
    if not (hx and hy) then
        return nil, nil
    end
    return toCell(hx, hy)
end

local function addSafeCellUnique(cells, seen, col, row)
    local key = col .. "," .. row
    if not seen[key] then
        seen[key] = true
        cells[#cells + 1] = {col, row}
    end
end

function Snake:getSafeZone(lookahead)
    local hx, hy = self:getHeadCell()
    if not (hx and hy) then
        return {}
    end

    local dir = self:getDirection()
    local cells = {}
    local seen = {}

    for i = 1, lookahead do
        local cx = hx + dir.x * i
        local cy = hy + dir.y * i
        addSafeCellUnique(cells, seen, cx, cy)
    end

    local pending = pendingDir
    if pending and (pending.x ~= dir.x or pending.y ~= dir.y) then
        -- Immediate turn path (if the queued direction snaps before the next tile)
        local px, py = hx, hy
        for i = 1, lookahead do
            px = px + pending.x
            py = py + pending.y
            addSafeCellUnique(cells, seen, px, py)
        end

        -- Typical turn path: advance one tile forward, then apply the queued turn
        local turnCol = hx + dir.x
        local turnRow = hy + dir.y
        px, py = turnCol, turnRow
        for i = 2, lookahead do
            px = px + pending.x
            py = py + pending.y
            addSafeCellUnique(cells, seen, px, py)
        end
    end

    return cells
end

function Snake:drawClipped(hx, hy, hr)
    if not trail or #trail == 0 then
        return
    end

    local headX, headY = self:getHead()
    local clipRadius = hr or 0
    local renderTrail = trail

    if clipRadius > 0 then
        local radiusSq = clipRadius * clipRadius
        local startIndex = 1

        while startIndex <= #trail do
            local seg = trail[startIndex]
            local x = seg and (seg.drawX or seg.x)
            local y = seg and (seg.drawY or seg.y)

            if not (x and y) then
                break
            end

            local dx = x - hx
            local dy = y - hy
            if dx * dx + dy * dy > radiusSq then
                break
            end

            startIndex = startIndex + 1
        end

        if startIndex == 1 then
            -- Head is still outside the clip region; render entire trail
            renderTrail = trail
        elseif startIndex > #trail then
            -- Entire snake is within the clip; nothing to draw outside
            renderTrail = {}
        else
            local trimmed = {}
            local prev = trail[startIndex - 1]
            local curr = trail[startIndex]
            local px = prev and (prev.drawX or prev.x)
            local py = prev and (prev.drawY or prev.y)
            local cx = curr and (curr.drawX or curr.x)
            local cy = curr and (curr.drawY or curr.y)
            local ix, iy

            if px and py and cx and cy then
                ix, iy = findCircleIntersection(px, py, cx, cy, hx, hy, clipRadius)
            end

            if not (ix and iy) then
                if descendingHole and math.abs((descendingHole.x or 0) - hx) < 1e-3 and math.abs((descendingHole.y or 0) - hy) < 1e-3 then
                    ix = descendingHole.entryPointX or px
                    iy = descendingHole.entryPointY or py
                else
                    ix, iy = px, py
                end
            end

            if ix and iy then
                trimmed[#trimmed + 1] = { drawX = ix, drawY = iy }
            end

            for i = startIndex, #trail do
                trimmed[#trimmed + 1] = trail[i]
            end

            renderTrail = trimmed
        end
    end

    love.graphics.push("all")
    local upgradeVisuals = collectUpgradeVisuals(self)

    if clipRadius > 0 then
        love.graphics.stencil(function()
            love.graphics.circle("fill", hx, hy, clipRadius)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 0)
    end

    local shouldDrawFace = descendingHole == nil

    DrawSnake(renderTrail, SEGMENT_SIZE, popTimer, function()
        if headX and headY and clipRadius > 0 then
            local dx = headX - hx
            local dy = headY - hy
            if dx * dx + dy * dy < clipRadius * clipRadius then
                return nil, nil
            end
        end
        return headX, headY
    end, self.crashShields or 0, self.shieldFlashTimer or 0, upgradeVisuals, shouldDrawFace)

    debugDrawCollisionSpace(trail, headX, headY)

    if clipRadius > 0 and descendingHole and math.abs((descendingHole.x or 0) - hx) < 1e-3 and math.abs((descendingHole.y or 0) - hy) < 1e-3 then
        love.graphics.setStencilTest("equal", 1)
        drawDescendingIntoHole(descendingHole)
    end

    love.graphics.setStencilTest()
    love.graphics.pop()
end

function Snake:startDescending(hx, hy, hr)
    descendingHole = {
        x = hx,
        y = hy,
        radius = hr or 0,
        consumedLength = 0,
        renderDepth = 0,
        time = 0,
    }

    local headX, headY = self:getHead()
    if headX and headY then
        descendingHole.entryPointX = headX
        descendingHole.entryPointY = headY
        local dirX, dirY = normalizeDirection((hx or headX) - headX, (hy or headY) - headY)
        descendingHole.entryDirX = dirX
        descendingHole.entryDirY = dirY
    end
end

function Snake:finishDescending()
    descendingHole = nil
end

function Snake:update(dt)
    if isDead then return false end

    -- base speed with upgrades/modifiers
    local head = trail[1]
    local speed = self:getSpeed()

    local hole = descendingHole
    if hole then
        hole.time = (hole.time or 0) + dt

        if head and head.drawX and head.drawY then
            hole.entryPointX = head.drawX
            hole.entryPointY = head.drawY

            local dirX, dirY = normalizeDirection((hole.x or head.drawX) - head.drawX, (hole.y or head.drawY) - head.drawY)
            if dirX ~= 0 or dirY ~= 0 then
                hole.entryDirX = dirX
                hole.entryDirY = dirY
            end
        end

        local consumed = hole.consumedLength or 0
        local totalDepth = math.max(SEGMENT_SPACING * 0.5, (hole.radius or 0) + SEGMENT_SPACING)
        local targetDepth = math.min(1, consumed / totalDepth)
        local currentDepth = hole.renderDepth or 0
        local blend = math.min(1, dt * 10)
        currentDepth = currentDepth + (targetDepth - currentDepth) * blend
        hole.renderDepth = currentDepth
    end

    if self.dash then
        if self.dash.cooldownTimer and self.dash.cooldownTimer > 0 then
            self.dash.cooldownTimer = math.max(0, (self.dash.cooldownTimer or 0) - dt)
        end

        if self.dash.active then
            speed = speed * (self.dash.speedMult or 1)
            self.dash.timer = (self.dash.timer or 0) - dt
            if self.dash.timer <= 0 then
                self.dash.active = false
                self.dash.timer = 0
            end
        end
    end

    if self.timeDilation then
        if self.timeDilation.cooldownTimer and self.timeDilation.cooldownTimer > 0 then
            self.timeDilation.cooldownTimer = math.max(0, (self.timeDilation.cooldownTimer or 0) - dt)
        end

        if self.timeDilation.active then
            self.timeDilation.timer = (self.timeDilation.timer or 0) - dt
            if self.timeDilation.timer <= 0 then
                self.timeDilation.active = false
                self.timeDilation.timer = 0
            end
        end
    end

    hole = descendingHole
    if hole and head then
        local dx = hole.x - head.drawX
        local dy = hole.y - head.drawY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 1e-4 then
            local nx, ny = dx / dist, dy / dist
            local prevX, prevY = direction.x, direction.y
            direction = { x = nx, y = ny }
            pendingDir = { x = nx, y = ny }
            if prevX ~= direction.x or prevY ~= direction.y then
                fruitsSinceLastTurn = 0
            end
        end
    end

    -- adrenaline boost check
    if self.adrenaline and self.adrenaline.active then
        speed = speed * self.adrenaline.boost
        self.adrenaline.timer = self.adrenaline.timer - dt
        if self.adrenaline.timer <= 0 then
            self.adrenaline.active = false
        end
    end

    local stepX = direction.x * speed * dt
    local stepY = direction.y * speed * dt
    local newX = head.drawX + stepX
    local newY = head.drawY + stepY

    -- advance cell clock, maybe snap & commit queued direction
    local snappedThisTick = false
    if hole then
        moveProgress = 0
    else
        local stepDistance = speed * dt
        moveProgress = moveProgress + stepDistance
        local snaps = 0
        local segmentLength = SEGMENT_SPACING
        while moveProgress >= segmentLength do
            moveProgress = moveProgress - segmentLength
            snaps = snaps + 1
        end
        if snaps > 0 then
            SessionStats:add("tilesTravelled", snaps)
        end
        if snaps > 0 then
            -- snap to the nearest grid center
            newX = snapToCenter(newX)
            newY = snapToCenter(newY)
            -- commit queued direction
            local prevX, prevY = direction.x, direction.y
            direction = { x = pendingDir.x, y = pendingDir.y }
            if prevX ~= direction.x or prevY ~= direction.y then
                fruitsSinceLastTurn = 0
            end
            snappedThisTick = true
        end
    end

    -- spatially uniform sampling along the motion path
    local dx = newX - head.drawX
    local dy = newY - head.drawY
    local dist = math.sqrt(dx*dx + dy*dy)

    local nx, ny = 0, 0
    if dist > 0 then
        nx, ny = dx / dist, dy / dist
    end

    local remaining = dist
    local prevX, prevY = head.drawX, head.drawY

    while remaining >= SAMPLE_STEP do
        prevX = prevX + nx * SAMPLE_STEP
        prevY = prevY + ny * SAMPLE_STEP
        table.insert(trail, 1, {
            drawX = prevX,
            drawY = prevY,
            dirX  = direction.x,
            dirY  = direction.y
        })
        remaining = remaining - SAMPLE_STEP
    end

    -- final correction: put true head at exact new position
    if trail[1] then
        trail[1].drawX = newX
        trail[1].drawY = newY
    end

    if hole then
        trimHoleSegments(hole)
        head = trail[1]
        if head then
            newX, newY = head.drawX, head.drawY
        end
    end

    -- tail trimming
    local tailBeforeX, tailBeforeY = nil, nil
    local len = #trail
    if len > 0 then
        tailBeforeX, tailBeforeY = trail[len].drawX, trail[len].drawY
    end
    local tailBeforeCol, tailBeforeRow
    if tailBeforeX and tailBeforeY then
        tailBeforeCol, tailBeforeRow = toCell(tailBeforeX, tailBeforeY)
    end

    local consumedLength = (hole and hole.consumedLength) or 0
    local maxLen = math.max(0, segmentCount * SEGMENT_SPACING - consumedLength)

    if maxLen == 0 then
        trail = {}
        len = 0
    end

    local traveled = 0
    for i = 2, #trail do
        local dx = trail[i-1].drawX - trail[i].drawX
        local dy = trail[i-1].drawY - trail[i].drawY
        local segLen = math.sqrt(dx*dx + dy*dy)

        if traveled + segLen > maxLen then
            local excess = traveled + segLen - maxLen
            local t = 1 - (excess / segLen)
            local tailX = trail[i-1].drawX - dx * t
            local tailY = trail[i-1].drawY - dy * t

            for j = #trail, i+1, -1 do
                table.remove(trail, j)
            end

            trail[i].drawX, trail[i].drawY = tailX, tailY
            break
        else
            traveled = traveled + segLen
        end
    end

    -- collision with self (grid-cell based, only at snap ticks)
        if snappedThisTick then
                local hx, hy = trail[1].drawX, trail[1].drawY
                local headCol, headRow = toCell(hx, hy)

		-- Don’t check the first ~1 segment of body behind the head (neck).
		-- Compute by *distance*, not “skip N nodes”.
		local guardDist = SEGMENT_SPACING * 1.05  -- about one full cell
		local walked = 0

		local function seglen(i)
			local dx = trail[i-1].drawX - trail[i].drawX
			local dy = trail[i-1].drawY - trail[i].drawY
			return math.sqrt(dx*dx + dy*dy)
		end

		-- advance 'walked' until we’re past the neck
		local startIndex = 2
		while startIndex < #trail and walked < guardDist do
			walked = walked + seglen(startIndex)
			startIndex = startIndex + 1
		end

		-- If tail vacated the head cell this tick, don’t count that as a hit
		local tailBeforeCol, tailBeforeRow = nil, nil
		do
			local len = #trail
			if len >= 1 then
				local tbx, tby = trail[len].drawX, trail[len].drawY
				if tbx and tby then
					tailBeforeCol, tailBeforeRow = toCell(tbx, tby)
				end
			end
		end

		for i = startIndex, #trail do
			local cx, cy = toCell(trail[i].drawX, trail[i].drawY)

			-- allow stepping into the tail cell if the tail moved off this tick
			local tailVacated =
				(i == #trail) and (tailBeforeCol == headCol and tailBeforeRow == headRow)

			if not tailVacated and cx == headCol and cy == headRow then
                                if self:consumeCrashShield() then
                                        -- survived; optional FX here
                                        self:onShieldConsumed(hx, hy, "self")
                                else
                                        isDead = true
                                        return false, "self"
                                end
			end
		end
	end

    -- update timers
    if popTimer > 0 then
        popTimer = math.max(0, popTimer - dt)
    end

    if self.shieldFlashTimer and self.shieldFlashTimer > 0 then
        self.shieldFlashTimer = math.max(0, self.shieldFlashTimer - dt)
    end

    if severedPieces and #severedPieces > 0 then
        for index = #severedPieces, 1, -1 do
            local piece = severedPieces[index]
            if piece then
                piece.timer = (piece.timer or 0) - dt
                if piece.timer <= 0 then
                    table.remove(severedPieces, index)
                end
            end
        end
    end

    return true
end

function Snake:activateDash()
    local dash = self.dash
    if not dash or dash.active then
        return false
    end

    if (dash.cooldownTimer or 0) > 0 then
        return false
    end

    dash.active = true
    dash.timer = dash.duration or 0
    dash.cooldownTimer = dash.cooldown or 0

    if dash.timer <= 0 then
        dash.active = false
    end

    local hx, hy = self:getHead()
    local Upgrades = getUpgradesModule()
    if Upgrades and Upgrades.notify then
        Upgrades:notify("dashActivated", {
            x = hx,
            y = hy,
        })
    end

    return dash.active
end

function Snake:isDashActive()
    return self.dash and self.dash.active or false
end

function Snake:getDashState()
    if not self.dash then
        return nil
    end

    return {
        active = self.dash.active or false,
        timer = self.dash.timer or 0,
        duration = self.dash.duration or 0,
        cooldown = self.dash.cooldown or 0,
        cooldownTimer = self.dash.cooldownTimer or 0,
    }
end

function Snake:onDashBreakRock(x, y)
    local dash = self.dash
    if not dash then return end

    local Upgrades = getUpgradesModule()
    if Upgrades and Upgrades.notify then
        Upgrades:notify("dashBreakRock", {
            x = x,
            y = y,
        })
    end
end

function Snake:activateTimeDilation()
    local ability = self.timeDilation
    if not ability or ability.active then
        return false
    end

    if (ability.cooldownTimer or 0) > 0 then
        return false
    end

    local charges = ability.floorCharges
    if charges == nil and ability.maxFloorUses then
        charges = ability.maxFloorUses
        ability.floorCharges = charges
    end
    if charges ~= nil and charges <= 0 then
        return false
    end

    ability.active = true
    ability.timer = ability.duration or 0
    ability.cooldownTimer = ability.cooldown or 0

    if ability.timer <= 0 then
        ability.active = false
    end

    if ability.active and charges ~= nil then
        ability.floorCharges = math.max(0, charges - 1)
    end

    local hx, hy = self:getHead()
    local Upgrades = getUpgradesModule()
    if Upgrades and Upgrades.notify then
        Upgrades:notify("timeDilationActivated", {
            x = hx,
            y = hy,
        })
    end

    return ability.active
end

function Snake:isTimeDilationActive()
    return self.timeDilation and self.timeDilation.active or false
end

function Snake:getTimeDilationState()
    local ability = self.timeDilation
    if not ability then
        return nil
    end

    return {
        active = ability.active or false,
        timer = ability.timer or 0,
        duration = ability.duration or 0,
        cooldown = ability.cooldown or 0,
        cooldownTimer = ability.cooldownTimer or 0,
        timeScale = resolveTimeDilationScale(ability),
        floorCharges = ability.floorCharges,
        maxFloorUses = ability.maxFloorUses,
    }
end

function Snake:getTimeScale()
    return resolveTimeDilationScale(self.timeDilation)
end

function Snake:updateReverseState(reversed)
    if reversed ~= self.reverseState then
        self:setReverseControls(reversed)
        self.reverseState = reversed
    end
end

function Snake:grow()
    local bonus = self.extraGrowth or 0
    segmentCount = segmentCount + 1 + bonus
    popTimer = POP_DURATION
end

function Snake:getSegmentCount()
    return segmentCount
end

function Snake:loseSegments(count, options)
    count = math.floor(count or 0)
    if count <= 0 then
        return 0
    end

    local available = math.max(0, (segmentCount or 1) - 1)
    local trimmed = math.min(count, available)
    if trimmed <= 0 then
        return 0
    end

    local exitWasOpen = Arena and Arena.hasExit and Arena:hasExit()
    segmentCount = segmentCount - trimmed
    popTimer = 0

    local shouldTrimTrail = true
    if options and options.trimTrail == false then
        shouldTrimTrail = false
    end

    if shouldTrimTrail then
        trimTrailToSegmentLimit()
    end

    local tail = trail[#trail]
    local tailX = tail and tail.drawX
    local tailY = tail and tail.drawY

    if (not options) or options.updateFruit ~= false then
        if UI and UI.removeFruit then
            UI:removeFruit(trimmed)
        elseif UI then
            UI.fruitCollected = math.max(0, (UI.fruitCollected or 0) - trimmed)
            if type(UI.fruitSockets) == "table" then
                for _ = 1, math.min(trimmed, #UI.fruitSockets) do
                    table.remove(UI.fruitSockets)
                end
            end
        end
    end

    local fruitGoalLost = false
    if UI then
        local collected = UI.fruitCollected or 0
        local required = UI.fruitRequired or 0
        fruitGoalLost = required > 0 and collected < required
    end

    if exitWasOpen and fruitGoalLost and Arena and Arena.resetExit then
        Arena:resetExit()
        if Fruit and Fruit.spawn then
            Fruit:spawn(self:getSegments(), Rocks, self:getSafeZone(3))
        end
    end

    if SessionStats and SessionStats.get and SessionStats.set then
        local apples = SessionStats:get("applesEaten") or 0
        apples = math.max(0, apples - trimmed)
        SessionStats:set("applesEaten", apples)
    end

    if Score and Score.addBonus and Score.get then
        local currentScore = Score:get() or 0
        local deduction = math.min(currentScore, trimmed)
        if deduction > 0 then
            Score:addBonus(-deduction)
        end
    end

    if (not options) or options.spawnParticles ~= false then
        local burstColor = {1, 0.8, 0.4, 1}
        if options and options.cause == "saw" then
            burstColor = {1, 0.6, 0.3, 1}
        end

        if Particles and Particles.spawnBurst and tailX and tailY then
            Particles:spawnBurst(tailX, tailY, {
                count = math.min(10, 4 + trimmed),
                speed = 120,
                speedVariance = 46,
                life = 0.42,
                size = 4,
                color = burstColor,
                spread = math.pi * 2,
                drag = 3.1,
                gravity = 220,
                fadeTo = 0,
            })
        end
    end

    return trimmed
end

local function chopTailLossAmount()
    local available = math.max(0, (segmentCount or 1) - 1)
    if available <= 0 then
        return 0
    end

    local loss = math.floor(math.max(1, available * 0.2))
    return math.min(loss, available)
end

function Snake:chopTailByHazard(cause)
    local loss = chopTailLossAmount()
    if loss <= 0 then
        return 0
    end

    return self:loseSegments(loss, { cause = cause or "saw" })
end

function Snake:chopTailBySaw()
    return self:chopTailByHazard("saw")
end

local function isSawActive(saw)
    if not saw then
        return false
    end

    return not ((saw.sinkProgress or 0) > 0 or (saw.sinkTarget or 0) > 0)
end

local function getSawCenterPosition(saw)
    if not (Saws and Saws.getCollisionCenter) then
        return nil, nil
    end

    return Saws:getCollisionCenter(saw)
end

local function isSawCutPointExposed(saw, sx, sy, px, py)
    if not (saw and sx and sy and px and py) then
        return true
    end

    local tolerance = 1.0
    local nx, ny

    if saw.dir == "horizontal" then
        -- Horizontal saws sit in the floor and only the top half (negative Y)
        -- should be able to slice the snake.
        nx, ny = 0, -1
    else
        -- For vertical saws, the exposed side depends on which wall the blade
        -- is mounted to. The sink direction indicates which side is hidden in
        -- the track, so flip it to get the exposed normal.
        local sinkDir = (saw.side == "left") and -1 or 1
        nx, ny = -sinkDir, 0
    end

    local dx = px - sx
    local dy = py - sy
    local projection = dx * nx + dy * ny

    return projection >= -tolerance
end

local function addSeveredTrail(pieceTrail, segmentEstimate)
    if not pieceTrail or #pieceTrail <= 1 then
        return
    end

    severedPieces = severedPieces or {}
    table.insert(severedPieces, {
        trail = pieceTrail,
        timer = SEVERED_TAIL_LIFE,
        segmentCount = math.max(1, segmentEstimate or #pieceTrail),
    })
end

local function spawnSawCutParticles(x, y, count)
    if not (Particles and Particles.spawnBurst and x and y) then
        return
    end

    Particles:spawnBurst(x, y, {
        count = math.min(12, 5 + (count or 0)),
        speed = 120,
        speedVariance = 60,
        life = 0.42,
        size = 4,
        color = {1, 0.6, 0.3, 1},
        spread = math.pi * 2,
        drag = 3.0,
        gravity = 220,
        fadeTo = 0,
    })
end

function Snake:handleSawBodyCut(context)
    if not context then
        return false
    end

    local available = math.max(0, (segmentCount or 1) - 1)
    if available <= 0 then
        return false
    end

    local index = context.index or 2
    if index <= 1 or index > #trail then
        return false
    end

    local previousIndex = index - 1
    local previousSegment = trail[previousIndex]
    if not previousSegment then
        return false
    end

    local cutX = context.cutX
    local cutY = context.cutY
    if not (cutX and cutY) then
        return false
    end

    local totalLength = (segmentCount or 1) * SEGMENT_SPACING
    local cutDistance = math.max(0, context.cutDistance or 0)
    if cutDistance <= SEGMENT_SPACING then
        return false
    end

    local tailDistance = 0
    do
        local prevCutX, prevCutY = cutX, cutY
        for i = index, #trail do
            local seg = trail[i]
            local sx = seg and (seg.drawX or seg.x)
            local sy = seg and (seg.drawY or seg.y)
            if sx and sy and prevCutX and prevCutY then
                local ddx = sx - prevCutX
                local ddy = sy - prevCutY
                tailDistance = tailDistance + math.sqrt(ddx * ddx + ddy * ddy)
                prevCutX, prevCutY = sx, sy
            end
        end
    end

    local rawSegments = tailDistance / SEGMENT_SPACING
    local lostSegments = math.max(1, math.floor(rawSegments + 0.25))
    if lostSegments > available then
        lostSegments = available
    end
    if lostSegments <= 0 then
        return false
    end

    if (totalLength - lostSegments * SEGMENT_SPACING) < cutDistance and lostSegments > 1 then
        local adjusted = totalLength - (lostSegments - 1) * SEGMENT_SPACING
        if adjusted >= cutDistance then
            lostSegments = lostSegments - 1
        end
    end

    local newTail = copySegmentData(previousSegment) or {}
    newTail.drawX = cutX
    newTail.drawY = cutY
    if previousSegment.x and previousSegment.y then
        newTail.x = cutX
        newTail.y = cutY
    end

    local dirX, dirY = normalizeDirection(cutX - (previousSegment.drawX or previousSegment.x or cutX), cutY - (previousSegment.drawY or previousSegment.y or cutY))
    if (dirX == 0 and dirY == 0) and previousSegment then
        dirX = previousSegment.dirX or 0
        dirY = previousSegment.dirY or 0
    end
    newTail.dirX = dirX
    newTail.dirY = dirY
    newTail.fruitMarker = nil
    newTail.fruitMarkerX = nil
    newTail.fruitMarkerY = nil

    local severedTrail = {}
    severedTrail[1] = copySegmentData(newTail)

    for i = index, #trail do
        local segCopy = copySegmentData(trail[i])
        if segCopy then
            table.insert(severedTrail, segCopy)
        end
    end

    for i = #trail, previousIndex + 1, -1 do
        table.remove(trail, i)
    end

    table.insert(trail, newTail)

    addSeveredTrail(severedTrail, lostSegments + 1)
    spawnSawCutParticles(cutX, cutY, lostSegments)

    self:loseSegments(lostSegments, { cause = "saw", trimTrail = false })

    return true
end

function Snake:checkSawBodyCollision()
    if isDead then
        return false
    end

    if not (trail and #trail > 2) then
        return false
    end

    if not (Saws and Saws.getAll) then
        return false
    end

    local saws = Saws:getAll()
    if not (saws and #saws > 0) then
        return false
    end

    local head = trail[1]
    local headX = head and (head.drawX or head.x)
    local headY = head and (head.drawY or head.y)
    if not (headX and headY) then
        return false
    end

    local guardDistance = SEGMENT_SPACING * 0.9
    local bodyRadius = SEGMENT_SIZE * 0.5

    for _, saw in ipairs(saws) do
        if isSawActive(saw) then
            local sx, sy = getSawCenterPosition(saw)
            if sx and sy then
                local sawRadius = (saw.collisionRadius or saw.radius or 0)
                local travelled = 0
                local prevX, prevY = headX, headY

                for index = 2, #trail do
                    local segment = trail[index]
                    local cx = segment and (segment.drawX or segment.x)
                    local cy = segment and (segment.drawY or segment.y)
                    if cx and cy then
                        local dx = cx - prevX
                        local dy = cy - prevY
                        local segLen = math.sqrt(dx * dx + dy * dy)
                        local minX = math.min(prevX, cx) - bodyRadius
                        local minY = math.min(prevY, cy) - bodyRadius
                        local maxX = math.max(prevX, cx) + bodyRadius
                        local maxY = math.max(prevY, cy) + bodyRadius
                        local width = maxX - minX
                        local height = maxY - minY

                        if segLen > 1e-6 and (not (Saws and Saws.isCollisionCandidate) or Saws:isCollisionCandidate(saw, minX, minY, width, height)) then
                            local closestX, closestY, distSq, t = closestPointOnSegment(sx, sy, prevX, prevY, cx, cy)
                            local along = travelled + segLen * (t or 0)
                            if along > guardDistance then
                                local combined = sawRadius + bodyRadius
                                if distSq <= combined * combined and isSawCutPointExposed(saw, sx, sy, closestX, closestY) then
                                    local handled = self:handleSawBodyCut({
                                        index = index,
                                        cutX = closestX,
                                        cutY = closestY,
                                        cutDistance = along,
                                    })
                                    if handled then
                                        return true
                                    end
                                end
                            end
                        end

                        travelled = travelled + segLen
                        prevX, prevY = cx, cy
                    end
                end
            end
        end
    end

    return false
end

function Snake:onFruitCollected()
    fruitsSinceLastTurn = (fruitsSinceLastTurn or 0) + 1
    SessionStats:updateMax("fruitWithoutTurning", fruitsSinceLastTurn)
end

function Snake:markFruitSegment(fruitX, fruitY)
    if not trail or #trail == 0 then
        return
    end

    local targetIndex = 1

    if fruitX and fruitY then
        local bestDistSq = math.huge
        for i = 1, #trail do
            local seg = trail[i]
            local sx = seg and (seg.drawX or seg.x)
            local sy = seg and (seg.drawY or seg.y)
            if sx and sy then
                local dx = fruitX - sx
                local dy = fruitY - sy
                local distSq = dx * dx + dy * dy
                if distSq < bestDistSq then
                    bestDistSq = distSq
                    targetIndex = i
                    if distSq <= 1 then
                        break
                    end
                end
            end
        end
    end

    local segment = trail[targetIndex]
    if segment then
        segment.fruitMarker = true
        if fruitX and fruitY then
            segment.fruitMarkerX = fruitX
            segment.fruitMarkerY = fruitY
        else
            segment.fruitMarkerX = nil
            segment.fruitMarkerY = nil
        end
    end
end

function Snake:draw()
    if not isDead then
        local upgradeVisuals = collectUpgradeVisuals(self)

        if severedPieces and #severedPieces > 0 then
            for _, piece in ipairs(severedPieces) do
                local trailData = piece and piece.trail
                if trailData and #trailData > 1 then
                    local function getPieceHead()
                        local headSeg = trailData[1]
                        if not headSeg then
                            return nil, nil
                        end
                        return headSeg.drawX or headSeg.x, headSeg.drawY or headSeg.y
                    end

                    DrawSnake(trailData, SEGMENT_SIZE, 0, getPieceHead, 0, 0, nil, false)
                end
            end
        end

        local shouldDrawFace = descendingHole == nil

        DrawSnake(trail, SEGMENT_SIZE, popTimer, function()
            return self:getHead()
        end, self.crashShields or 0, self.shieldFlashTimer or 0, upgradeVisuals, shouldDrawFace)

        local headX, headY = self:getHead()
        debugDrawCollisionSpace(trail, headX, headY)
    end
end

function Snake:resetPosition()
    self:load(screenW, screenH)
end

function Snake:getSegments()
    local copy = {}
    for i = 1, #trail do
        local seg = trail[i]
        copy[i] = {
            drawX = seg.drawX,
            drawY = seg.drawY,
            dirX = seg.dirX,
            dirY = seg.dirY
        }
    end
    return copy
end

function Snake:isDead()
    return isDead
end

function Snake:getLength()
    return segmentCount
end

return Snake
