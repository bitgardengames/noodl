local Snake = require("snake")
local Audio = require("audio")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Arena = require("arena")
local Particles = require("particles")
local Upgrades = require("upgrades")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")

local Movement = {}

local SEGMENT_SIZE = 24 -- same size as rocks and snake

local shieldStatMap = {
        wall = {
                lifetime = "shieldWallBounces",
                run = "runShieldWallBounces",
                achievements = { "wallRicochet" },
        },
        rock = {
                lifetime = "shieldRockBreaks",
                run = "runShieldRockBreaks",
                achievements = { "rockShatter" },
        },
        saw = {
                lifetime = "shieldSawParries",
                run = "runShieldSawParries",
                achievements = { "sawParry" },
        },
        laser = {
                lifetime = "shieldSawParries",
                run = "runShieldSawParries",
                achievements = { "sawParry" },
        },
}

local function recordShieldEvent(cause)
        local info = shieldStatMap[cause]
        if not info then
                return
        end

        if info.run then
                SessionStats:add(info.run, 1)
        end

        if info.lifetime then
                PlayerStats:add(info.lifetime, 1)
        end

        if info.achievements then
                for _, achievementId in ipairs(info.achievements) do
                        Achievements:check(achievementId)
                end
        end

        Achievements:check("shieldTriad")
end

-- AABB collision check
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
        return ax < bx + bw and ax + aw > bx and
                   ay < by + bh and ay + ah > by
end

local function rerouteAlongWall(headX, headY)
        local ax, ay, aw, ah = Arena:getBounds()
        local inset = Arena.tileSize / 2
        local left = ax + inset
        local right = ax + aw - inset
        local top = ay + inset
        local bottom = ay + ah - inset

        local clampedX = math.max(left + 1, math.min(right - 1, headX or left))
        local clampedY = math.max(top + 1, math.min(bottom - 1, headY or top))

        local distances = {
                left = math.abs((headX or clampedX) - left),
                right = math.abs((headX or clampedX) - right),
                top = math.abs((headY or clampedY) - top),
                bottom = math.abs((headY or clampedY) - bottom),
        }

        local side = "left"
        local minDist = distances.left
        for key, value in pairs(distances) do
                if value < minDist then
                        minDist = value
                        side = key
                end
        end

        local dir = Snake:getDirection() or { x = 0, y = 0 }
        local newDirX, newDirY = dir.x or 0, dir.y or 0
        local centerX = ax + aw / 2
        local centerY = ay + ah / 2

        local function towardCenter(delta)
                if delta < 0 then return 1 end
                if delta > 0 then return -1 end
                return 1
        end

        if side == "left" or side == "right" then
                newDirX = 0
                if newDirY == 0 then
                        newDirY = towardCenter(clampedY - centerY)
                else
                        newDirY = newDirY > 0 and 1 or -1
                end
        else
                newDirY = 0
                if newDirX == 0 then
                        newDirX = towardCenter(clampedX - centerX)
                else
                        newDirX = newDirX > 0 and 1 or -1
                end
        end

        Snake:setHeadPosition(clampedX, clampedY)
        Snake:setDirectionVector(newDirX, newDirY)

        return Snake:getHead()
end

local function clamp(value, min, max)
        if min and value < min then
                return min
        end
        if max and value > max then
                return max
        end
        return value
end

local function portalThroughWall(headX, headY)
        if not (Upgrades and Upgrades.getEffect and Upgrades:getEffect("wallPortal")) then
                return nil, nil
        end

        local ax, ay, aw, ah = Arena:getBounds()
        local inset = Arena.tileSize / 2
        local left = ax + inset
        local right = ax + aw - inset
        local top = ay + inset
        local bottom = ay + ah - inset

        local outLeft = headX < left
        local outRight = headX > right
        local outTop = headY < top
        local outBottom = headY > bottom

        if not (outLeft or outRight or outTop or outBottom) then
                return nil, nil
        end

        local horizontalDist = 0
        if outLeft then
                horizontalDist = left - headX
        elseif outRight then
                horizontalDist = headX - right
        end

        local verticalDist = 0
        if outTop then
                verticalDist = top - headY
        elseif outBottom then
                verticalDist = headY - bottom
        end

        local entryX = clamp(headX, left, right)
        local entryY = clamp(headY, top, bottom)

        local margin = math.max(4, math.floor(Arena.tileSize * 0.3))
        local function insideX(x)
                return clamp(x, left + margin, right - margin)
        end

        local function insideY(y)
                return clamp(y, top + margin, bottom - margin)
        end

        local exitX, exitY
        if horizontalDist >= verticalDist then
                if outLeft then
                        exitX = insideX(right - margin)
                else
                        exitX = insideX(left + margin)
                end
                exitY = insideY(headY)
        else
                if outTop then
                        exitY = insideY(bottom - margin)
                else
                        exitY = insideY(top + margin)
                end
                exitX = insideX(headX)
        end

        local dx = (exitX or headX) - headX
        local dy = (exitY or headY) - headY

        if dx == 0 and dy == 0 then
                return nil, nil
        end

        if Snake.translate then
                Snake:translate(dx, dy)
        else
                Snake:setHeadPosition(headX + dx, headY + dy)
        end

        local newHeadX, newHeadY = Snake:getHead()

        if Particles then
                Particles:spawnBurst(entryX, entryY, {
                        count = 18,
                        speed = 120,
                        speedVariance = 80,
                        life = 0.5,
                        size = 5,
                        color = {0.9, 0.75, 0.3, 1},
                        spread = math.pi * 2,
                        fadeTo = 0.1,
                })
                Particles:spawnBurst(newHeadX, newHeadY, {
                        count = 22,
                        speed = 150,
                        speedVariance = 90,
                        life = 0.55,
                        size = 5,
                        color = {1.0, 0.88, 0.4, 1},
                        spread = math.pi * 2,
                        fadeTo = 0.05,
                })
        end

        return newHeadX, newHeadY
end

local function handleWallCollision(headX, headY)
        if Arena:isInside(headX, headY) then
                return headX, headY
        end

        local portalX, portalY = portalThroughWall(headX, headY)
        if portalX and portalY then
                Audio:playSound("wall_portal")
                return portalX, portalY
        end

        if not Snake:consumeCrashShield() then
                return headX, headY, "wall"
        end

        local reroutedX, reroutedY = rerouteAlongWall(headX, headY)
        headX = reroutedX or headX
        headY = reroutedY or headY

        Particles:spawnBurst(headX, headY, {
                count = 12,
                speed = 70,
                speedVariance = 55,
                life = 0.45,
                size = 4,
                color = {0.55, 0.85, 1, 1},
                spread = math.pi * 2,
                angleJitter = math.pi * 0.75,
                drag = 3.2,
                gravity = 180,
                scaleMin = 0.5,
                scaleVariance = 0.75,
                fadeTo = 0,
        })

        Audio:playSound("shield_wall")

        if Snake.onShieldConsumed then
                Snake:onShieldConsumed(headX, headY, "wall")
        end

        recordShieldEvent("wall")

        return headX, headY
end

local function handleRockCollision(headX, headY)
        for _, rock in ipairs(Rocks:getAll()) do
                if aabb(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE, rock.x, rock.y, rock.w, rock.h) then
                        local centerX = rock.x + rock.w / 2
                        local centerY = rock.y + rock.h / 2

                        if Snake.isDashActive and Snake:isDashActive() then
                                Rocks:destroy(rock)
                                Particles:spawnBurst(centerX, centerY, {
                                        count = 10,
                                        speed = 120,
                                        speedVariance = 70,
                                        life = 0.35,
                                        size = 4,
                                        color = {1.0, 0.78, 0.32, 1},
                                        spread = math.pi * 2,
                                        angleJitter = math.pi * 0.6,
                                        drag = 3.0,
                                        gravity = 180,
                                        scaleMin = 0.5,
                                        scaleVariance = 0.6,
                                        fadeTo = 0.05,
                                })
                                Audio:playSound("shield_rock")
                                if Snake.onDashBreakRock then
                                        Snake:onDashBreakRock(centerX, centerY)
                                end
                        else
                                if not Snake:consumeCrashShield() then
                                        return "dead", "rock"
                                end

                                Particles:spawnBurst(centerX, centerY, {
                                        count = 8,
                                        speed = 40,
                                        speedVariance = 36,
                                        life = 0.4,
                                        size = 3,
                                        color = {0.9, 0.8, 0.5, 1},
                                        spread = math.pi * 2,
                                        angleJitter = math.pi * 0.8,
                                        drag = 2.8,
                                        gravity = 210,
                                        scaleMin = 0.55,
                                        scaleVariance = 0.5,
                                        fadeTo = 0.05,
                                })
                                Audio:playSound("shield_rock")
                                Rocks:destroy(rock, { spawnFX = false })

                                if Snake.onShieldConsumed then
                                        Snake:onShieldConsumed(centerX, centerY, "rock")
                                end

                                recordShieldEvent("rock")
                        end

                        break
                end
        end
end

local function handleSawCollision(headX, headY)
        local sawHit = Saws:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
        if not sawHit then
                return
        end

        local shielded = Snake:consumeCrashShield()
        local survivedSaw = shielded

        if not survivedSaw and Snake.consumeStoneSkinSawGrace then
                survivedSaw = Snake:consumeStoneSkinSawGrace()
        end

        if not survivedSaw then
                return "dead", "saw"
        end

        Saws:destroy(sawHit)

        Particles:spawnBurst(headX, headY, {
                count = 8,
                speed = 40,
                speedVariance = 34,
                life = 0.35,
                size = 3,
                color = {0.9, 0.7, 0.3, 1},
                spread = math.pi * 2,
                angleJitter = math.pi * 0.9,
                drag = 3.0,
                gravity = 240,
                scaleMin = 0.5,
                scaleVariance = 0.6,
                fadeTo = 0,
        })
        Audio:playSound("shield_saw")

        if Snake.onShieldConsumed then
                Snake:onShieldConsumed(headX, headY, "saw")
        end

        if Snake.chopTailBySaw then
                Snake:chopTailBySaw()
        end

        if shielded then
                recordShieldEvent("saw")
        end

        return
end

local function handleLaserCollision(headX, headY)
        if not Lasers or not Lasers.checkCollision then
                return
        end

        local laserHit = Lasers:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
        if not laserHit then
                return
        end

        local shielded = Snake:consumeCrashShield()
        local survived = shielded

        if not survived and Snake.consumeStoneSkinSawGrace then
                survived = Snake:consumeStoneSkinSawGrace()
        end

        if not survived then
                return "dead", "laser"
        end

        Lasers:onShieldedHit(laserHit)

        Particles:spawnBurst(headX, headY, {
                count = 10,
                speed = 80,
                speedVariance = 30,
                life = 0.25,
                size = 2.5,
                color = {1.0, 0.55, 0.25, 1},
                spread = math.pi * 2,
                angleJitter = math.pi,
                drag = 3.4,
                gravity = 120,
                scaleMin = 0.45,
                scaleVariance = 0.4,
                fadeTo = 0,
        })

        Audio:playSound("shield_saw")

        if Snake.onShieldConsumed then
                Snake:onShieldConsumed(headX, headY, "laser")
        end

        if shielded then
                recordShieldEvent("laser")
        end

        return
end

function Movement:reset()
        Snake:resetPosition()
end

function Movement:update(dt)
        local alive, cause = Snake:update(dt)
        if not alive then
                return "dead", cause or "self"
        end

        local headX, headY = Snake:getHead()

        local wallCause
        headX, headY, wallCause = handleWallCollision(headX, headY)
        if wallCause then
                return "dead", wallCause
        end

        local state, stateCause = handleRockCollision(headX, headY)
        if state then
                return state, stateCause
        end

        local laserState, laserCause = handleLaserCollision(headX, headY)
        if laserState then
                return laserState, laserCause
        end

        local sawState, sawCause = handleSawCollision(headX, headY)
        if sawState then
                return sawState, sawCause
        end

        if Snake.checkSawBodyCollision then
                Snake:checkSawBodyCollision()
        end

        if Fruit:checkCollisionWith(headX, headY) then
                return "scored"
        end
end

return Movement
