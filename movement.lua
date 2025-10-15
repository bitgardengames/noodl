local Snake = require("snake")
local Audio = require("audio")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Arena = require("arena")
local Theme = require("theme")
local Particles = require("particles")
local Upgrades = require("upgrades")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")

local Movement = {}

function Movement:applyForcedDirection(dirX, dirY)
		if not (Snake and Snake.setDirectionVector) then
				return
		end

		dirX = dirX or 0
		dirY = dirY or 0

		if dirX == 0 and dirY == 0 then
				return
		end

		Snake:setDirectionVector(dirX, dirY)
end

local SEGMENT_SIZE = 24 -- same size as rocks and snake
local DAMAGE_GRACE = 0.35
local WALL_GRACE = 0.25

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
		dart = {
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

		local hitLeft = (headX or clampedX) <= left
		local hitRight = (headX or clampedX) >= right
		local hitTop = (headY or clampedY) <= top
		local hitBottom = (headY or clampedY) >= bottom

		local dir = Snake:getDirection() or { x = 0, y = 0 }
		local newDirX, newDirY = dir.x or 0, dir.y or 0

		local function fallbackVertical()
				if dir.y and dir.y ~= 0 then
						return dir.y > 0 and 1 or -1
				end
				local centerY = ay + ah / 2
				if clampedY <= centerY then
						return 1
				end
				return -1
		end

		local function fallbackHorizontal()
				if dir.x and dir.x ~= 0 then
						return dir.x > 0 and 1 or -1
				end
				local centerX = ax + aw / 2
				if clampedX <= centerX then
						return 1
				end
				return -1
		end

		local collidedHorizontal = hitLeft or hitRight
		local collidedVertical = hitTop or hitBottom
		local horizontalDominant = math.abs(dir.x or 0) >= math.abs(dir.y or 0)

		if collidedHorizontal and collidedVertical then
				if horizontalDominant then
						newDirX = 0
						local slide = fallbackVertical()
						if hitTop and slide < 0 then
								slide = 1
						elseif hitBottom and slide > 0 then
								slide = -1
						end
						newDirY = slide
				else
						newDirY = 0
						local slide = fallbackHorizontal()
						if hitLeft and slide < 0 then
								slide = 1
						elseif hitRight and slide > 0 then
								slide = -1
						end
						newDirX = slide
				end
		else
				if collidedHorizontal then
						newDirX = 0
						local slide = fallbackVertical()
						if hitTop and slide < 0 then
								slide = 1
						elseif hitBottom and slide > 0 then
								slide = -1
						end
						newDirY = slide
				end

				if collidedVertical then
						newDirY = 0
						local slide = fallbackHorizontal()
						if hitLeft and slide < 0 then
								slide = 1
						elseif hitRight and slide > 0 then
								slide = -1
						end
						newDirX = slide
				end
		end

		if newDirX == 0 and newDirY == 0 then
				if hitLeft and not hitRight then
						newDirX = 1
				elseif hitRight and not hitLeft then
						newDirX = -1
				elseif hitTop and not hitBottom then
						newDirY = 1
				elseif hitBottom and not hitTop then
						newDirY = -1
				else
						if dir.x and dir.x ~= 0 then
								newDirX = dir.x > 0 and 1 or -1
						elseif dir.y and dir.y ~= 0 then
								newDirY = dir.y > 0 and 1 or -1
						else
								newDirY = 1
						end
				end
		end

		Movement:applyForcedDirection(newDirX, newDirY)

		return clampedX, clampedY
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

		local ax, ay, aw, ah = Arena:getBounds()
		local inset = Arena.tileSize / 2
		local left = ax + inset
		local right = ax + aw - inset
		local top = ay + inset
		local bottom = ay + ah - inset

		if not Snake:consumeCrashShield() then
				local safeX = clamp(headX, left, right)
				local safeY = clamp(headY, top, bottom)
				local reroutedX, reroutedY = rerouteAlongWall(safeX, safeY)
				local clampedX = reroutedX or safeX
				local clampedY = reroutedY or safeY
				if Snake and Snake.setHeadPosition then
						Snake:setHeadPosition(clampedX, clampedY)
				end
				local dir = Snake.getDirection and Snake:getDirection() or { x = 0, y = 0 }

				return clampedX, clampedY, "wall", {
						pushX = 0,
						pushY = 0,
						snapX = clampedX,
						snapY = clampedY,
						dirX = dir.x or 0,
						dirY = dir.y or 0,
						grace = WALL_GRACE,
						shake = 0.2,
				}
		end

		local reroutedX, reroutedY = rerouteAlongWall(headX, headY)
		local clampedX = reroutedX or clamp(headX, left, right)
		local clampedY = reroutedY or clamp(headY, top, bottom)
		if Snake and Snake.setHeadPosition then
				Snake:setHeadPosition(clampedX, clampedY)
		end
		headX, headY = clampedX, clampedY

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
								local context = {
										pushX = 0,
										pushY = 0,
										grace = DAMAGE_GRACE,
										shake = 0.35,
								}

								local shielded = Snake:consumeCrashShield()

								if not shielded then
										Rocks:triggerHitFlash(rock)
										return "hit", "rock", context
								end

								Rocks:destroy(rock)
								context.damage = 0

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

								if Snake.onShieldConsumed then
										Snake:onShieldConsumed(centerX, centerY, "rock")
								end

								recordShieldEvent("rock")

								return "hit", "rock", context
						end

						break
				end
		end
end

local function handleSawCollision(headX, headY)
		if Snake:isHazardGraceActive() then
				return
		end

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
				local pushX, pushY = 0, 0
				local normalX, normalY = 0, -1
				if Saws.getCollisionCenter then
						local sx, sy = Saws:getCollisionCenter(sawHit)
						if sx and sy then
								local dx = (headX or sx) - sx
								local dy = (headY or sy) - sy
								local dist = math.sqrt(dx * dx + dy * dy)
								local pushDist = SEGMENT_SIZE
								if dist > 1e-4 then
										normalX = dx / dist
										normalY = dy / dist
										pushX = normalX * pushDist
										pushY = normalY * pushDist
								end
						end
				end

				if Particles and Particles.spawnBlood then
						Particles:spawnBlood(headX, headY, {
								dirX = normalX,
								dirY = normalY,
						})
				end

				return "hit", "saw", {
						pushX = pushX,
						pushY = pushY,
						grace = DAMAGE_GRACE,
						shake = 0.4,
				}
		end

		Saws:destroy(sawHit)

                Particles:spawnBurst(headX, headY, {
                                count = 8,
                                speed = 48,
                                speedVariance = 36,
                                life = 0.32,
                                size = 2.2,
                                color = {1.0, 0.9, 0.45, 1},
                                spread = math.pi * 2,
                                angleJitter = math.pi * 0.9,
                                drag = 3.2,
                                gravity = 240,
                                scaleMin = 0.4,
                                scaleVariance = 0.45,
                                fadeTo = 0.05,
                })
		Audio:playSound("shield_saw")

		if Snake.onShieldConsumed then
				Snake:onShieldConsumed(headX, headY, "saw")
		end

		Snake:beginHazardGrace()

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

		if Snake:isHazardGraceActive() then
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
				local pushX, pushY = 0, 0
				if laserHit then
						local lx = laserHit.impactX or laserHit.x or headX
						local ly = laserHit.impactY or laserHit.y or headY
						local dx = (headX or lx) - lx
						local dy = (headY or ly) - ly
						local dist = math.sqrt(dx * dx + dy * dy)
						local pushDist = SEGMENT_SIZE
						if dist > 1e-4 then
								pushX = (dx / dist) * pushDist
								pushY = (dy / dist) * pushDist
						end
				end

				return "hit", "laser", {
						pushX = pushX,
						pushY = pushY,
						grace = DAMAGE_GRACE,
						shake = 0.32,
				}
		end

		Lasers:onShieldedHit(laserHit, headX, headY)

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

		if Snake.chopTailByHazard then
				Snake:chopTailByHazard("laser")
		elseif Snake.chopTailBySaw then
				Snake:chopTailBySaw()
		end

		Snake:beginHazardGrace()

		if shielded then
				recordShieldEvent("laser")
		end

		return
end

local function handleDartCollision(headX, headY)
		if not Darts or not Darts.checkCollision then
				return
		end

		if Snake:isHazardGraceActive() then
				return
		end

		local dartHit = Darts:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
		if not dartHit then
				return
		end

		local shielded = Snake:consumeCrashShield()
		local survived = shielded

		if not survived and Snake.consumeStoneSkinSawGrace then
				survived = Snake:consumeStoneSkinSawGrace()
		end

		if not survived then
				if Particles and Particles.spawnBlood then
						local impactX = dartHit.x or headX
						local impactY = dartHit.y or headY
						Particles:spawnBlood(impactX, impactY, {
								dirX = dartHit.dirX or 0,
								dirY = dartHit.dirY or 0,
						})
				end

				local pushDist = SEGMENT_SIZE
				local pushX = -(dartHit.dirX or 0) * pushDist
				local pushY = -(dartHit.dirY or 0) * pushDist

				return "hit", "dart", {
						pushX = pushX,
						pushY = pushY,
						grace = DAMAGE_GRACE,
						shake = 0.3,
				}
		end

		Darts:onShieldedHit(dartHit, headX, headY)

		Particles:spawnBurst(headX, headY, {
				count = 9,
				speed = 88,
				speedVariance = 36,
				life = 0.28,
				size = 2.6,
				color = Theme and Theme.laserColor or {1.0, 0.5, 0.3, 1},
				spread = math.pi * 2,
				angleJitter = math.pi,
				drag = 3.1,
				gravity = 120,
				scaleMin = 0.42,
				scaleVariance = 0.36,
				fadeTo = 0,
		})

		Audio:playSound("shield_saw")

		if Snake.onShieldConsumed then
				Snake:onShieldConsumed(headX, headY, "dart")
		end

		if Snake.chopTailByHazard then
				Snake:chopTailByHazard("dart")
		elseif Snake.chopTailBySaw then
				Snake:chopTailBySaw()
		end

		Snake:beginHazardGrace()

		if shielded then
				recordShieldEvent("dart")
		end

		return
end

function Movement:reset()
		Snake:resetPosition()
end

function Movement:update(dt)
		local alive, cause, context = Snake:update(dt)
		if not alive then
				if context and context.fatal then
						return "dead", cause or "self", context
				end
				return "hit", cause or "self", context
		end

		local headX, headY = Snake:getHead()

		local wallCause, wallContext
		headX, headY, wallCause, wallContext = handleWallCollision(headX, headY)
		if wallCause then
				return "hit", wallCause, wallContext
		end

		local state, stateCause, stateContext = handleRockCollision(headX, headY)
		if state then
				return state, stateCause, stateContext
		end

		local laserState, laserCause, laserContext = handleLaserCollision(headX, headY)
		if laserState then
				return laserState, laserCause, laserContext
		end

		local dartState, dartCause, dartContext = handleDartCollision(headX, headY)
		if dartState then
				return dartState, dartCause, dartContext
		end

		local sawState, sawCause, sawContext = handleSawCollision(headX, headY)
		if sawState then
				return sawState, sawCause, sawContext
		end

		if Snake.checkSawBodyCollision then
				Snake:checkSawBodyCollision()
		end

		if Fruit:checkCollisionWith(headX, headY) then
				return "scored"
		end
end

return Movement
