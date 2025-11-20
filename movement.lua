local Snake = require("snake")
local Audio = require("audio")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Arena = require("arena")
local Particles = require("particles")
local Upgrades = require("upgrades")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")

local abs = math.abs
local max = math.max
local min = math.min
local pi = math.pi
local sqrt = math.sqrt

local Movement = {}

local MAX_SNAKE_TIME_STEP = 1 / 60

local function isDeveloperGodMode()
	return Snake.isDeveloperGodMode and Snake:isDeveloperGodMode()
end

local cachedRockCandidates = {}
local cachedRockHeadCol
local cachedRockHeadRow
local cachedRockRevision

function Movement:applyForcedDirection(dirX, dirY)
	dirX = dirX or 0
	dirY = dirY or 0

	if dirX == 0 and dirY == 0 then
		return
	end

	Snake:setDirectionVector(dirX, dirY)
end

local SEGMENT_SIZE = 24 -- same size as rocks and snake
local ROCK_COLLISION_INSET = 2 -- shrink collision boxes slightly to avoid premature hits
local DAMAGE_GRACE = 0.35
local WALL_GRACE = 0.25

-- Reused particle option tables to avoid recreating identical bursts every frame.
local PORTAL_ENTRY_BURST_OPTIONS = {
	count = 18,
	speed = 120,
	speedVariance = 80,
	life = 0.5,
	size = 5,
	color = {0.9, 0.75, 0.3, 1},
	spread = pi * 2,
	fadeTo = 0.1,
}

local PORTAL_EXIT_BURST_OPTIONS = {
	count = 22,
	speed = 150,
	speedVariance = 90,
	life = 0.55,
	size = 5,
	color = {1.0, 0.88, 0.4, 1},
	spread = pi * 2,
	fadeTo = 0.05,
}

local WALL_SHIELD_BURST_OPTIONS = {
	count = 12,
	speed = 70,
	speedVariance = 55,
	life = 0.45,
	size = 4,
	color = {0.55, 0.85, 1, 1},
	spread = pi * 2,
	angleJitter = pi * 0.75,
	drag = 3.2,
	gravity = 180,
	scaleMin = 0.5,
	scaleVariance = 0.75,
	fadeTo = 0,
}

local ROCK_DASH_BURST_OPTIONS = {
	count = 10,
	speed = 120,
	speedVariance = 70,
	life = 0.35,
	size = 4,
	color = {1.0, 0.78, 0.32, 1},
	spread = pi * 2,
	angleJitter = pi * 0.6,
	drag = 3.0,
	gravity = 180,
	scaleMin = 0.5,
	scaleVariance = 0.6,
	fadeTo = 0.05,
}

local ROCK_SHIELD_BURST_OPTIONS = {
	count = 8,
	speed = 40,
	speedVariance = 36,
	life = 0.4,
	size = 3,
	color = {0.9, 0.8, 0.5, 1},
	spread = pi * 2,
	angleJitter = pi * 0.8,
	drag = 2.8,
	gravity = 210,
	scaleMin = 0.55,
	scaleVariance = 0.5,
	fadeTo = 0.05,
}

local SAW_SHIELD_BURST_OPTIONS = {
	count = 8,
	speed = 48,
	speedVariance = 36,
	life = 0.32,
	size = 2.2,
	color = {1.0, 0.9, 0.45, 1},
	spread = pi * 2,
	angleJitter = pi * 0.9,
	drag = 3.2,
	gravity = 240,
	scaleMin = 0.4,
	scaleVariance = 0.45,
	fadeTo = 0.05,
}

local LASER_SHIELD_BURST_OPTIONS = {
	count = 10,
	speed = 80,
	speedVariance = 30,
	life = 0.25,
	size = 2.5,
	color = {1.0, 0.55, 0.25, 1},
	spread = pi * 2,
	angleJitter = pi,
	drag = 3.4,
	gravity = 120,
	scaleMin = 0.45,
	scaleVariance = 0.4,
	fadeTo = 0,
}

local DART_SHIELD_BURST_OPTIONS = {
	count = 9,
	speed = 95,
	speedVariance = 40,
	life = 0.28,
	size = 2.9,
	color = {1.0, 0.74, 0.28, 1},
	spread = pi * 2,
	angleJitter = pi * 0.85,
	drag = 3.6,
	gravity = 140,
	scaleMin = 0.5,
	scaleVariance = 0.35,
	fadeTo = 0.04,
}

local shieldStatMap = {
	wall = {
		lifetime = "shieldWallBounces",
		run = "runShieldWallBounces",
	},
	rock = {
		lifetime = "shieldRockBreaks",
		run = "runShieldRockBreaks",
	},
	saw = {
		lifetime = "shieldSawParries",
		run = "runShieldSawParries",
	},
	laser = {
		lifetime = "shieldSawParries",
		run = "runShieldSawParries",
	},
	dart = {
		lifetime = "shieldSawParries",
		run = "runShieldSawParries",
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
end

-- AABB collision check
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and ax + aw > bx and
	ay < by + bh and ay + ah > by
end

local function computeFallbackAxisDirection(component, clampedValue, centerValue)
	if component and component ~= 0 then
		return component > 0 and 1 or -1
	end

	if clampedValue <= centerValue then
		return 1
	end

	return -1
end

local function rerouteAlongWall(headX, headY, left, right, top, bottom)
	local centerX, centerY
	if left and right and top and bottom then
		centerX = (left + right) / 2
		centerY = (top + bottom) / 2
	else
		local ax, ay, aw, ah = Arena:getBounds()
		local inset = Arena.tileSize / 2
		left = ax + inset
		right = ax + aw - inset
		top = ay + inset
		bottom = ay + ah - inset
		centerX = ax + aw / 2
		centerY = ay + ah / 2
	end

	local clampedX = max(left, min(right, headX or left))
	local clampedY = max(top, min(bottom, headY or top))

	local hitLeft = (headX or clampedX) <= left
	local hitRight = (headX or clampedX) >= right
	local hitTop = (headY or clampedY) <= top
	local hitBottom = (headY or clampedY) >= bottom

	local dir = Snake:getDirection() or {x = 0, y = 0}
	local newDirX, newDirY = dir.x or 0, dir.y or 0

	local fallbackVerticalDir = computeFallbackAxisDirection(dir.y, clampedY, centerY)
	local fallbackHorizontalDir = computeFallbackAxisDirection(dir.x, clampedX, centerX)

	local collidedHorizontal = hitLeft or hitRight
	local collidedVertical = hitTop or hitBottom
	local horizontalDominant = abs(dir.x or 0) >= abs(dir.y or 0)

	if collidedHorizontal and collidedVertical then
		if horizontalDominant then
			newDirX = 0
			local slide = fallbackVerticalDir
			if hitTop and slide < 0 then
				slide = 1
			elseif hitBottom and slide > 0 then
				slide = -1
			end
			newDirY = slide
		else
			newDirY = 0
			local slide = fallbackHorizontalDir
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
			local slide = fallbackVerticalDir
			if hitTop and slide < 0 then
				slide = 1
			elseif hitBottom and slide > 0 then
				slide = -1
			end
			newDirY = slide
		end

		if collidedVertical then
			newDirY = 0
			local slide = fallbackHorizontalDir
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

	local useGrid = Arena.getTileFromWorld and Arena.getCenterOfTile and Arena.cols and Arena.rows
	if useGrid then
		local col, row = Arena:getTileFromWorld(clampedX, clampedY)
		if col and row then
			local centerX, centerY = Arena:getCenterOfTile(col, row)
			if centerX and centerY then
				clampedX, clampedY = centerX, centerY
			end
		end
	end

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

	local useGrid = Arena.getTileFromWorld and Arena.getCenterOfTile and Arena.cols and Arena.rows
	local entryPortalX, entryPortalY = entryX, entryY
	local exitX, exitY

	if useGrid then
		local entryCol, entryRow = Arena:getTileFromWorld(entryX, entryY)
		if entryCol and entryRow then
			if horizontalDist >= verticalDist then
				local exitCol = outLeft and Arena.cols or 1
				local exitRow = entryRow
				exitX, exitY = Arena:getCenterOfTile(exitCol, exitRow)
			else
				local exitCol = entryCol
				local exitRow = outTop and Arena.rows or 1
				exitX, exitY = Arena:getCenterOfTile(exitCol, exitRow)
			end
		end
	end

	if not (exitX and exitY) then
		local margin = max(4, math.floor(Arena.tileSize * 0.3))
		if horizontalDist >= verticalDist then
			if outLeft then
				exitX = clamp(right - margin, left + margin, right - margin)
			else
				exitX = clamp(left + margin, left + margin, right - margin)
			end
			exitY = clamp(headY, top + margin, bottom - margin)
		else
			if outTop then
				exitY = clamp(bottom - margin, top + margin, bottom - margin)
			else
				exitY = clamp(top + margin, top + margin, bottom - margin)
			end
			exitX = clamp(headX, left + margin, right - margin)
		end

		entryPortalX, entryPortalY = entryX, entryY
	end

	local dx = (exitX or headX) - headX
	local dy = (exitY or headY) - headY

	if dx == 0 and dy == 0 then
		return nil, nil
	end

	local newHeadX, newHeadY
	local portalDuration = 0.3
	if Snake.beginPortalWarp then
		local started = Snake:beginPortalWarp({
			entryX = entryPortalX,
			entryY = entryPortalY,
			exitX = headX + dx,
			exitY = headY + dy,
			duration = portalDuration,
			dx = dx,
			dy = dy,
			}
		)
		if started then
			newHeadX, newHeadY = Snake:getHead()
		end
	end

	if not (newHeadX and newHeadY) then
		if Snake.translate then
			Snake:translate(dx, dy, {resetMoveProgress = true})
			if Snake.resetMovementProgress then
				Snake:resetMovementProgress()
			end
		else
			local targetX = headX + dx
			local targetY = headY + dy
			Snake:setHeadPosition(targetX, targetY)
			if Snake.resetMovementProgress then
				Snake:resetMovementProgress()
			end
		end
		newHeadX, newHeadY = Snake:getHead()
	end

	if Particles then
		Particles:spawnBurst(entryPortalX, entryPortalY, PORTAL_ENTRY_BURST_OPTIONS)
		Particles:spawnBurst(newHeadX, newHeadY, PORTAL_EXIT_BURST_OPTIONS)
	end

	return newHeadX, newHeadY
end

local function relocateHead(headX, headY, targetX, targetY)
	if not (targetX and targetY) then
		return headX, headY
	end

	local deltaX = 0
	local deltaY = 0
	if headX and headY then
		deltaX = targetX - headX
		deltaY = targetY - headY
	end

	local moved = false
	if Snake.translate and (deltaX ~= 0 or deltaY ~= 0) then
		Snake:translate(deltaX, deltaY, {resetMoveProgress = true})
		moved = true
	elseif Snake.setHeadPosition then
		Snake:setHeadPosition(targetX, targetY)
		moved = true
	end

	if Snake.resetMovementProgress then
		Snake:resetMovementProgress()
	end

	if moved then
		local newHeadX, newHeadY = Snake:getHead()
		headX = newHeadX or targetX
		headY = newHeadY or targetY
	end

	return headX, headY
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

	if not Snake:consumeShield() then
		local safeX = clamp(headX, left, right)
		local safeY = clamp(headY, top, bottom)
		local reroutedX, reroutedY = rerouteAlongWall(safeX, safeY, left, right, top, bottom)
		local clampedX = reroutedX or safeX
		local clampedY = reroutedY or safeY
		headX, headY = relocateHead(headX, headY, clampedX, clampedY)
		clampedX, clampedY = headX, headY
		local dir = Snake.getDirection and Snake:getDirection() or {x = 0, y = 0}

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

	local reroutedX, reroutedY = rerouteAlongWall(headX, headY, left, right, top, bottom)
	local clampedX = reroutedX or clamp(headX, left, right)
	local clampedY = reroutedY or clamp(headY, top, bottom)
	headX, headY = relocateHead(headX, headY, clampedX, clampedY)

	Particles:spawnBurst(headX, headY, WALL_SHIELD_BURST_OPTIONS)

	Audio:playSound("shield_wall")

	if Snake.onShieldConsumed then
		Snake:onShieldConsumed(headX, headY, "wall")
	end

	recordShieldEvent("wall")

	return headX, headY
end

local function handleRockCollision(headX, headY, headCol, headRow, rockRevision)
	local headSize = max(0, SEGMENT_SIZE - ROCK_COLLISION_INSET * 2)
	local halfHeadSize = headSize / 2
	local headLeft = headX - halfHeadSize
	local headTop = headY - halfHeadSize
	local allRocks = Rocks.getAll and Rocks:getAll() or nil

	if not allRocks or #allRocks == 0 then
		return
	end

	local candidates = allRocks
	local hasLookup = Rocks.hasCellLookup and Rocks:hasCellLookup()

	if hasLookup and Rocks.getNearby and headCol and headRow then
		local revision = rockRevision or (Rocks.getRevision and Rocks:getRevision()) or nil

		if revision and cachedRockRevision == revision and cachedRockHeadCol == headCol and cachedRockHeadRow == headRow then
			candidates = cachedRockCandidates
		else
			cachedRockRevision = revision
			cachedRockHeadCol = headCol
			cachedRockHeadRow = headRow

			for i = #cachedRockCandidates, 1, -1 do
				cachedRockCandidates[i] = nil
			end

			local nearby = Rocks:getNearby(headCol, headRow, 1)
			if nearby and #nearby > 0 then
				for i = 1, #nearby do
					cachedRockCandidates[i] = nearby[i]
				end
			end

			candidates = cachedRockCandidates
		end

		if not candidates or #candidates == 0 then
			candidates = allRocks
		end
	end

	for _, rock in ipairs(candidates or {}) do
		local rockCenterX = rock and (rock.renderX or rock.x) or 0
		local rockCenterY = rock and (rock.renderY or rock.y) or 0
		local rockWidth = max(0, (rock and rock.w or SEGMENT_SIZE) - ROCK_COLLISION_INSET * 2)
		local rockHeight = max(0, (rock and rock.h or SEGMENT_SIZE) - ROCK_COLLISION_INSET * 2)
		local rockLeft = rockCenterX - rockWidth / 2
		local rockTop = rockCenterY - rockHeight / 2

		if aabb(headLeft, headTop, headSize, headSize, rockLeft, rockTop, rockWidth, rockHeight) then
			local centerX = rockLeft + rockWidth / 2
			local centerY = rockTop + rockHeight / 2

			if Snake.isDashActive and Snake:isDashActive() then
				Rocks:destroy(rock)
				if Rocks.recordRockBreak then
					Rocks:recordRockBreak()
				end
				Particles:spawnBurst(centerX, centerY, ROCK_DASH_BURST_OPTIONS)
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

				local shielded = Snake:consumeShield()

				if not shielded then
					Rocks:triggerHitFlash(rock)
					return "hit", "rock", context
				end

				Rocks:destroy(rock)
				context.damage = 0

				Particles:spawnBurst(centerX, centerY, ROCK_SHIELD_BURST_OPTIONS)
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

local function handleSawCollision(headX, headY, hazardGraceActive)
	if hazardGraceActive then
		return
	end

	local sawHit = Saws:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
	if not sawHit then
		return
	end

	local shielded = Snake:consumeShield()
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
				local dist = sqrt(dx * dx + dy * dy)
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
				}
			)
		end

		return "hit", "saw", {
			pushX = pushX,
			pushY = pushY,
			grace = DAMAGE_GRACE,
			shake = 0.4,
		}
	end

	Saws:destroy(sawHit)

	Particles:spawnBurst(headX, headY, SAW_SHIELD_BURST_OPTIONS)
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

local function handleLaserCollision(headX, headY, hazardGraceActive)
	if not Lasers or not Lasers.checkCollision then
		return
	end

	if hazardGraceActive then
		return
	end

	local laserHit = Lasers:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
	if not laserHit then
		return
	end

	local shielded = Snake:consumeShield()
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
			local dist = sqrt(dx * dx + dy * dy)
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

	Particles:spawnBurst(headX, headY, LASER_SHIELD_BURST_OPTIONS)

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

local function handleDartCollision(headX, headY, hazardGraceActive)
	if not Darts or not Darts.checkCollision then
		return
	end

	if hazardGraceActive then
		return
	end

	local dartHit = Darts:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)
	if not dartHit then
		return
	end

	local shielded = Snake:consumeShield()
	local survived = shielded

	if not survived and Snake.consumeStoneSkinSawGrace then
		survived = Snake:consumeStoneSkinSawGrace()
	end

	local impactX = dartHit.dartX or dartHit.lastImpactX or dartHit.endX or headX
	local impactY = dartHit.dartY or dartHit.lastImpactY or dartHit.endY or headY

	if not survived then
		local pushX, pushY = 0, 0
		local dx = (headX or impactX) - impactX
		local dy = (headY or impactY) - impactY
		local dist = sqrt(dx * dx + dy * dy)
		local pushDist = SEGMENT_SIZE * 0.85
		if dist > 1e-4 then
			pushX = (dx / dist) * pushDist
			pushY = (dy / dist) * pushDist
		else
			if dartHit.dir == "horizontal" then
				pushX = -(dartHit.facing or 1) * pushDist
			else
				pushY = -(dartHit.facing or 1) * pushDist
			end
		end

		if Darts and Darts.onSnakeImpact then
			Darts:onSnakeImpact(dartHit, impactX, impactY)
		end

		return "hit", "dart", {
			pushX = pushX,
			pushY = pushY,
			grace = DAMAGE_GRACE,
			shake = 0.28,
		}
	end

	Darts:onShieldedHit(dartHit, impactX, impactY)

	Particles:spawnBurst(headX, headY, DART_SHIELD_BURST_OPTIONS)

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
	if not dt or dt <= 0 then
		return
	end

	local remaining = dt
	local maxStep = MAX_SNAKE_TIME_STEP

	while remaining > 0 do
		local step = min(remaining, maxStep)
		if step <= 0 then
			break
		end
		remaining = remaining - step

		local developerGodMode = isDeveloperGodMode()

		local alive, cause, context = Snake:update(step)
		if not alive then
			if not developerGodMode then
				if context and context.fatal then
					return "dead", cause or "self", context
				end
				return "hit", cause or "self", context
			end
		end

		local headX, headY = Snake:getHead()
		local hazardGraceActive = Snake.isHazardGraceActive and Snake:isHazardGraceActive() or false

		local laserEmitterCount = 0
		local dartEmitterCount = 0
		local sawCount = 0
		if not hazardGraceActive then
			if Lasers and Lasers.getEmitterCount then
				laserEmitterCount = Lasers:getEmitterCount() or 0
			end

			if Darts and Darts.getEmitterCount then
				dartEmitterCount = Darts:getEmitterCount() or 0
			end

			if Saws and Saws.getAll then
				local allSaws = Saws:getAll()
				if allSaws then
					sawCount = #allSaws
				end
			end
		end

		local wallCause, wallContext
		headX, headY, wallCause, wallContext = handleWallCollision(headX, headY)
		if wallCause and not developerGodMode then
			return "hit", wallCause, wallContext
		end

		local headCol, headRow
		if Arena and Arena.getTileFromWorld then
			headCol, headRow = Arena:getTileFromWorld(headX, headY)
		end

		local rockRevision = Rocks.getRevision and Rocks:getRevision() or nil
		local state, stateCause, stateContext = handleRockCollision(headX, headY, headCol, headRow, rockRevision)
		if state and not developerGodMode then
			return state, stateCause, stateContext
		end

		if not hazardGraceActive and laserEmitterCount > 0 then
			local laserState, laserCause, laserContext = handleLaserCollision(headX, headY, hazardGraceActive)
			if laserState and not developerGodMode then
				return laserState, laserCause, laserContext
			end
		end

		if not hazardGraceActive and dartEmitterCount > 0 then
			local dartState, dartCause, dartContext = handleDartCollision(headX, headY, hazardGraceActive)
			if dartState and not developerGodMode then
				return dartState, dartCause, dartContext
			end
		end

		if not hazardGraceActive and sawCount > 0 then
			local sawState, sawCause, sawContext = handleSawCollision(headX, headY, hazardGraceActive)
			if sawState and not developerGodMode then
				return sawState, sawCause, sawContext
			end
		end

		if Snake.checkLaserBodyCollision and not hazardGraceActive and laserEmitterCount > 0 then
			Snake:checkLaserBodyCollision()
		end

		if Snake.checkDartBodyCollision and not hazardGraceActive and dartEmitterCount > 0 then
			Snake:checkDartBodyCollision()
		end

		if Snake.checkSawBodyCollision and not hazardGraceActive and sawCount > 0 then
			Snake:checkSawBodyCollision()
		end

		if Fruit:checkCollisionWith(headX, headY) then
			return "scored"
		end
	end
end

return Movement
