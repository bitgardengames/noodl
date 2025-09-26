local Snake = require("snake")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Arena = require("arena")
local Particles = require("particles")
local Boss = require("boss")

local Movement = {}

local SEGMENT_SIZE = 24 -- same size as rocks and snake

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

function Movement:reset()
        Snake:resetPosition()
end

function Movement:update(dt)
	local alive, cause = Snake:update(dt)
	if not alive then
		return "dead", cause or "self"
	end

	local headX, headY = Snake:getHead()

        if not Arena:isInside(headX, headY) then
                if Snake:consumeCrashShield() then
                        local reroutedX, reroutedY = rerouteAlongWall(headX, headY)
                        headX = reroutedX or headX
                        headY = reroutedY or headY

                        Particles:spawnBurst(headX, headY, {
                                count = 12,
                                speed = 70,
                                life = 0.45,
                                size = 4,
                                color = {0.55, 0.85, 1, 1},
                                spread = math.pi * 2,
                        })

                        if Snake.onShieldConsumed then
                                Snake:onShieldConsumed(headX, headY, "wall")
                        end
                else
                        return "dead", "wall"
                end
        end

        for _, rock in ipairs(Rocks:getAll()) do
                if aabb(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE, rock.x, rock.y, rock.w, rock.h) then
                        if Snake:consumeCrashShield() then
                                -- shield absorbed the hit, play feedback and continue
                                Particles:spawnBurst(rock.x + rock.w/2, rock.y + rock.h/2, {
                                        count = 8, speed = 40, life = 0.4, size = 3,
                                        color = {0.9, 0.8, 0.5, 1}, spread = math.pi*2
                                })
                                Rocks:destroy(rock, { spawnFX = false })
                                -- clear the shattered rock so the next frame doesn't collide again
                                if Snake.onShieldConsumed then
                                        local centerX = rock.x + rock.w / 2
                                        local centerY = rock.y + rock.h / 2
                                        Snake:onShieldConsumed(centerX, centerY, "rock")
                                end
                        else
                                return "dead", "rock"
                        end
                        break
                end
        end

        local sawHit = Saws:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)

        if sawHit then
                local shielded = Snake:consumeCrashShield()
                local survivedSaw = shielded

                if not survivedSaw and Snake.consumeStoneSkinSawGrace then
                        survivedSaw = Snake:consumeStoneSkinSawGrace()
                end

                if survivedSaw then
                        Saws:destroy(sawHit)

                        Particles:spawnBurst(headX, headY, {
                                count = 8, speed = 40, life = 0.35, size = 3,
                                color = {0.9,0.7,0.3,1}, spread = math.pi*2
                        })
                        if Snake.onShieldConsumed then
                                Snake:onShieldConsumed(headX, headY, "saw")
                        end
                else
                        return "dead", "saw"
                end
        end

        if Boss:isActive() or Boss:isDefeated() then
                local hazard = Boss:checkCollision(headX, headY, SEGMENT_SIZE)
                if hazard == "core" then
                        Boss:onCoreEntered(headX, headY)
                elseif hazard == "ring" or hazard == "pulse" then
                        if Snake:consumeCrashShield() then
                                Boss:onShieldBlocked(headX, headY)
                                if Snake.onShieldConsumed then
                                        Snake:onShieldConsumed(headX, headY, "boss")
                                end
                        else
                                return "dead", "boss"
                        end
                end
        end

        if Fruit:checkCollisionWith(headX, headY) then
                return "scored"
        end
end

return Movement
