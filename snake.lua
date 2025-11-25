local Arena = require("arena")
local MovementContext = require("movementcontext")
local SnakeUtils = require("snakeutils")
local SnakeDraw = require("snakedraw")
local SnakeRender = require("snake_render")
local SnakeUpgrades = require("snakeupgrades")
local SnakeUpgradesState = require("snake_upgrades_state")
local SnakeDamage = require("snake_damage")
local SnakeLifecycle = require("snake_lifecycle")
local SnakeCollisions = require("snake_collisions")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local UI = require("ui")
local Fruit = require("fruit")
local Particles = require("particles")
local SessionStats = require("sessionstats")
local Score = require("score")
local SnakeCosmetics = require("snakecosmetics")
local SnakeTrail = require("snake_trail")
local SnakeOccupancyHelper = require("snake_occupancy")
local SnakeAbilities = require("snake_abilities")
local FloatingText = require("floatingtext")
local Face = require("face")
local SnakeOccupancy = require("snakeoccupancy")

local abs = math.abs
local floor = math.floor
local huge = math.huge
local min = math.min
local pi = math.pi
local insert = table.insert
local remove = table.remove
local Snake = {}
local sqrt = math.sqrt
local max = math.max
local EMPTY_TABLE = {}
local spawnGluttonsWakeRock
local crystallizeGluttonsWakeSegments

local CTX_PUSH_X = MovementContext.PUSH_X
local CTX_PUSH_Y = MovementContext.PUSH_Y
local CTX_SNAP_X = MovementContext.SNAP_X
local CTX_SNAP_Y = MovementContext.SNAP_Y
local CTX_DIR_X = MovementContext.DIR_X
local CTX_DIR_Y = MovementContext.DIR_Y
local CTX_GRACE = MovementContext.GRACE
local CTX_SHAKE = MovementContext.SHAKE
local CTX_DAMAGE = MovementContext.DAMAGE
local CTX_INFLICTED_DAMAGE = MovementContext.INFLICTED_DAMAGE

local function wipeTable(t)
	if not t then
		return
	end

	for key in pairs(t) do
		t[key] = nil
	end
end

local screenW, screenH
local DIR_X, DIR_Y = 1, 2

local direction = {1, 0}
local pendingDir = {1, 0}
local trail = {}
local descendingHole = nil
local segmentCount = 1
local popTimer = 0
local isDead = false

local severedPieces = {}
local portalAnimation = nil

-- Reused ability state tables to avoid allocations every HUD refresh.
local DASH_STATE_ACTIVE = SnakeAbilities.DASH_STATE_ACTIVE
local DASH_STATE_TIMER = SnakeAbilities.DASH_STATE_TIMER
local DASH_STATE_DURATION = SnakeAbilities.DASH_STATE_DURATION
local DASH_STATE_COOLDOWN = SnakeAbilities.DASH_STATE_COOLDOWN
local DASH_STATE_COOLDOWN_TIMER = SnakeAbilities.DASH_STATE_COOLDOWN_TIMER

Snake.DASH_STATE_ACTIVE = DASH_STATE_ACTIVE
Snake.DASH_STATE_TIMER = DASH_STATE_TIMER
Snake.DASH_STATE_DURATION = DASH_STATE_DURATION
Snake.DASH_STATE_COOLDOWN = DASH_STATE_COOLDOWN
Snake.DASH_STATE_COOLDOWN_TIMER = DASH_STATE_COOLDOWN_TIMER

local TIME_STATE_ACTIVE = SnakeAbilities.TIME_STATE_ACTIVE
local TIME_STATE_TIMER = SnakeAbilities.TIME_STATE_TIMER
local TIME_STATE_DURATION = SnakeAbilities.TIME_STATE_DURATION
local TIME_STATE_COOLDOWN = SnakeAbilities.TIME_STATE_COOLDOWN
local TIME_STATE_COOLDOWN_TIMER = SnakeAbilities.TIME_STATE_COOLDOWN_TIMER
local TIME_STATE_SCALE = SnakeAbilities.TIME_STATE_SCALE
local TIME_STATE_FLOOR_CHARGES = SnakeAbilities.TIME_STATE_FLOOR_CHARGES
local TIME_STATE_MAX_FLOOR_USES = SnakeAbilities.TIME_STATE_MAX_FLOOR_USES

Snake.TIME_STATE_ACTIVE = TIME_STATE_ACTIVE
Snake.TIME_STATE_TIMER = TIME_STATE_TIMER
Snake.TIME_STATE_DURATION = TIME_STATE_DURATION
Snake.TIME_STATE_COOLDOWN = TIME_STATE_COOLDOWN
Snake.TIME_STATE_COOLDOWN_TIMER = TIME_STATE_COOLDOWN_TIMER
Snake.TIME_STATE_SCALE = TIME_STATE_SCALE
Snake.TIME_STATE_FLOOR_CHARGES = TIME_STATE_FLOOR_CHARGES
Snake.TIME_STATE_MAX_FLOOR_USES = TIME_STATE_MAX_FLOOR_USES

local segmentPoolState = SnakeTrail.newPoolState()

local segmentSnapshot = {}
local segmentSnapshotPool = {}
local segmentSnapshotPoolCount = 0
local SEGMENT_SNAPSHOT_DRAW_X = 1
local SEGMENT_SNAPSHOT_DRAW_Y = 2
local SEGMENT_SNAPSHOT_DIR_X = 3
local SEGMENT_SNAPSHOT_DIR_Y = 4
-- Snapshot entries are packed arrays: {drawX, drawY, dirX, dirY}.

local newHeadSegments = {}
local newHeadSegmentsMax = 0

local renderState = SnakeRender.newState()

local occupancyState = SnakeOccupancyHelper.newState()
local headCellBuffer = occupancyState.headCellBuffer
local toCell

local TILE_COORD_EPSILON = SnakeOccupancy.TILE_COORD_EPSILON

local clearRecentlyVacatedCells = SnakeOccupancy.clearRecentlyVacatedCells
local markRecentlyVacatedCell = SnakeOccupancy.markRecentlyVacatedCell
local wasRecentlyVacated = SnakeOccupancy.wasRecentlyVacated
local clearSnakeBodySpatialIndex = SnakeOccupancy.clearSnakeBodySpatialIndex
local clearSnakeBodyOccupancy = SnakeOccupancy.clearSnakeBodyOccupancy
local resetTrackedSnakeCells = SnakeOccupancy.resetTrackedSnakeCells
local clearSnakeOccupiedCells = SnakeOccupancy.clearSnakeOccupiedCells
local recordSnakeOccupiedCell = SnakeOccupancy.recordSnakeOccupiedCell
local getSnakeTailCell = SnakeOccupancy.getSnakeTailCell
local popSnakeTailCell = SnakeOccupancy.popSnakeTailCell
local getSnakeHeadCell = SnakeOccupancy.getSnakeHeadCell
local moduleResetSnakeOccupancyGrid = SnakeOccupancy.resetSnakeOccupancyGrid
local addSnakeBodyOccupancy = SnakeOccupancy.addSnakeBodyOccupancy
local removeSnakeBodyOccupancy = SnakeOccupancy.removeSnakeBodyOccupancy
local isCellOccupiedBySnakeBody = SnakeOccupancy.isCellOccupiedBySnakeBody
local addSnakeBodySpatialEntry = SnakeOccupancy.addSnakeBodySpatialEntry
local removeSnakeBodySpatialEntry = SnakeOccupancy.removeSnakeBodySpatialEntry
local rebuildSnakeBodySpatialIndex = SnakeOccupancy.rebuildSnakeBodySpatialIndex
local syncSnakeHeadSegments = SnakeOccupancy.syncSnakeHeadSegments
local syncSnakeTailSegment = SnakeOccupancy.syncSnakeTailSegment
local collectSnakeSegmentCandidatesForRect = SnakeOccupancy.collectSnakeSegmentCandidatesForRect
local collectSnakeSegmentCandidatesForCircle = SnakeOccupancy.collectSnakeSegmentCandidatesForCircle

segmentPoolState.removeSnakeBodySpatialEntry = removeSnakeBodySpatialEntry

local function resetSnakeOccupancyGrid()
        SnakeOccupancyHelper.resetGrid(occupancyState)
end

local function ensureOccupancyGrid()
        return SnakeOccupancyHelper.ensureGrid(occupancyState)
end

function Snake:needsStencil()
	local hole = descendingHole
	if hole then
		local radius = hole.radius or 0
		local depth = hole.renderDepth or 0
		if (radius > 0 or depth > 0) and not hole.fullyConsumed then
			return true
		end
	end

	return false
end

local trailLength = 0

local function acquireSegment()
        return SnakeTrail.acquireSegment(segmentPoolState)
end

local function releaseSegment(segment)
        SnakeTrail.releaseSegment(segmentPoolState, removeSnakeBodySpatialEntry, segment)
end

local function releaseSegmentRange(buffer, startIndex)
        SnakeTrail.releaseSegmentRange(segmentPoolState, buffer, startIndex, removeSnakeBodySpatialEntry)
end

local function ensureHeadLength()
        trailLength = SnakeTrail.ensureHeadLength(trail, trailLength)
end

local function updateSegmentLengthAt(index)
        trailLength = SnakeTrail.updateSegmentLengthAt(trail, trailLength, index)
end

local function recalcSegmentLengthsRange(startIndex, endIndex)
        trailLength = SnakeTrail.recalcSegmentLengthsRange(trail, trailLength, startIndex, endIndex)
end

local function syncTrailLength()
        trailLength = SnakeTrail.syncTrailLength(trail, trailLength)
        return trailLength
end

local function recycleTrail(buffer)
        trailLength = SnakeTrail.recycleTrail(segmentPoolState, trail, trailLength, buffer, removeSnakeBodySpatialEntry)
end

local function clearPortalAnimation(state)
	if not state then
		return
	end

	recycleTrail(state.entrySourceTrail)
	recycleTrail(state.entryTrail)
	recycleTrail(state.exitTrail)
	state.entrySourceTrail = nil
	state.entryTrail = nil
	state.exitTrail = nil
	state.entryHole = nil
	state.exitHole = nil
end

local function assignDirection(target, x, y)
if not target then
return
end

target[DIR_X] = x
target[DIR_Y] = y
end

-- Shared burst configuration to avoid allocations when trimming segments.
local LOSE_SEGMENTS_DEFAULT_BURST_COLOR = {1, 0.8, 0.4, 1}
local LOSE_SEGMENTS_SAW_BURST_COLOR = {1, 0.6, 0.3, 1}
local LOSE_SEGMENTS_BURST_OPTIONS = {
	count = 0,
	speed = 1,
	speedVariance = 46,
	life = 0.42,
	size = 4,
	color = LOSE_SEGMENTS_DEFAULT_BURST_COLOR,
	spread = pi * 2,
	drag = 3.1,
	gravity = 220,
	fadeTo = 0,
}

local SHIELD_BREAK_PARTICLE_OPTIONS = {
	count = 16,
	speed = 1,
	speedVariance = 90,
	life = 0.48,
	size = 5,
	color = {1, 0.46, 0.32, 1},
	spread = pi * 2,
	angleJitter = pi,
	drag = 3.2,
	gravity = 280,
	fadeTo = 0.05,
}

local SHIELD_BLOOD_PARTICLE_OPTIONS = {
	dirX = 0,
	dirY = -1,
	spread = pi * 0.65,
	count = 10,
	dropletCount = 6,
	speed = 210,
	speedVariance = 80,
	life = 0.5,
	size = 3.6,
	gravity = 340,
	fadeTo = 0.06,
}

local SEVERED_TAIL_LIFE = 0.9
local SEVERED_TAIL_FADE_DURATION = 0.35

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
-- distance travelled since last grid snap (in world units)
local moveProgress = 0

local lifecycle = SnakeLifecycle.new({
Arena = Arena,
SEGMENT_SPACING = SEGMENT_SPACING,
acquireSegment = acquireSegment,
assignDirection = assignDirection,
SnakeRender = SnakeRender,
renderState = renderState,
recycleTrail = recycleTrail,
clearPortalAnimation = clearPortalAnimation,
SnakeUtils = SnakeUtils,
Rocks = Rocks,
DIR_X = DIR_X,
DIR_Y = DIR_Y,
resetSnakeOccupancyGrid = resetSnakeOccupancyGrid,
clearSnakeBodyOccupancy = clearSnakeBodyOccupancy,
})
local POP_DURATION = SnakeUtils.POP_DURATION
local HAZARD_GRACE_DURATION = SnakeUpgrades.HAZARD_GRACE_DURATION -- brief invulnerability window after surviving certain hazards
local TAIL_HIT_FLASH_DURATION = 0.18
local TAIL_HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
local SELF_COLLISION_RADIUS = SEGMENT_SPACING * 0.48
local SELF_COLLISION_RADIUS_SQ = SELF_COLLISION_RADIUS * SELF_COLLISION_RADIUS
-- movement baseline + modifiers
Snake.baseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.speedMult   = 1 -- stackable multiplier (upgrade-friendly)
Snake.shields = 0 -- shield protection: number of hits the snake can absorb
Snake.extraGrowth = 0
Snake.shieldFlashTimer = 0
Snake.tailHitFlashTimer = 0
Snake.stoneSkinSawGrace = 0
Snake.dash = nil
Snake.timeDilation = nil
Snake.chronoWard = nil
Snake.hazardGraceTimer = 0
Snake.phoenixEcho = nil
Snake.eventHorizon = nil
Snake.stormchaser = nil
Snake.temporalAnchor = nil
Snake.swiftFangs = nil

-- getters / mutators (safe API for upgrades)
Snake.getSpeed = SnakeUpgradesState.getSpeed
Snake.addSpeedMultiplier = SnakeUpgradesState.addSpeedMultiplier
Snake.addShields = SnakeUpgradesState.addShields
Snake.consumeShield = SnakeUpgradesState.consumeShield
Snake.resetModifiers = SnakeUpgradesState.resetModifiers
Snake.setSwiftFangsStacks = SnakeUpgradesState.setSwiftFangsStacks
Snake.setSerpentsReflexStacks = SnakeUpgradesState.setSerpentsReflexStacks
Snake.setDeliberateCoilStacks = SnakeUpgradesState.setDeliberateCoilStacks
Snake.setMomentumCoilsStacks = SnakeUpgradesState.setMomentumCoilsStacks
Snake.setDiffractionBarrierActive = SnakeUpgradesState.setDiffractionBarrierActive
Snake.setPhoenixEchoCharges = SnakeUpgradesState.setPhoenixEchoCharges
Snake.setEventHorizonActive = SnakeUpgradesState.setEventHorizonActive
Snake.onShieldConsumed = SnakeUpgradesState.onShieldConsumed
Snake.addStoneSkinSawGrace = SnakeUpgradesState.addStoneSkinSawGrace
Snake.consumeStoneSkinSawGrace = SnakeUpgradesState.consumeStoneSkinSawGrace
Snake.isHazardGraceActive = SnakeUpgradesState.isHazardGraceActive
Snake.beginHazardGrace = SnakeUpgradesState.beginHazardGrace

function Snake:onDamageTaken(cause, info)
        SnakeDamage.onDamageTaken(self, cause, info, direction)
end

-- >>> Small integration note:
-- Inside your snake:update(dt) where you compute movement, replace any hard-coded speed use with:
-- local speed = Snake:getSpeed()
-- and then use `speed` for position updates. This gives upgrades an immediate effect.

toCell = function(x, y)
	if not (x and y) then
		return nil, nil
	end

	if Arena and Arena.getTileFromWorld then
		return Arena:getTileFromWorld(x, y)
	end

	local tileSize = Arena and Arena.tileSize or SEGMENT_SPACING or 1
	if tileSize == 0 then
		tileSize = 1
	end

	local offsetX = (Arena and Arena.x) or 0
	local offsetY = (Arena and Arena.y) or 0
	local normalizedCol = ((x - offsetX) / tileSize) + TILE_COORD_EPSILON
	local normalizedRow = ((y - offsetY) / tileSize) + TILE_COORD_EPSILON
	local col = floor(normalizedCol) + 1
	local row = floor(normalizedRow) + 1

	if Arena then
		local cols = Arena.cols or col
		local rows = Arena.rows or row
		col = max(1, min(cols, col))
		row = max(1, min(rows, row))
	end

	return col, row
end

SnakeOccupancyHelper.setToCell(occupancyState, toCell)

local function rebuildOccupancyFromTrail(headColOverride, headRowOverride)
        SnakeOccupancyHelper.rebuildFromTrail(occupancyState, trail, headColOverride, headRowOverride)
end

local function applySnakeOccupancyDelta(headCells, headCellCount, overrideCol, overrideRow, tailMoved, tailAfterCol, tailAfterRow)
        occupancyState.newHeadSegmentsMax = newHeadSegmentsMax
        SnakeOccupancyHelper.applyDelta(
                occupancyState,
                trail,
                headCellCount,
                overrideCol,
                overrideRow,
                tailMoved,
                tailAfterCol,
                tailAfterRow
        )
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

	discriminant = sqrt(discriminant)
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
	local len = sqrt(dx * dx + dy * dy)
	if len == 0 then
		return 0, 0
	end
	return dx / len, dy / len
end

local function closestPointOnSegment(px, py, ax, ay, bx, by)
	if not (px and py and ax and ay and bx and by) then
		return nil, nil, huge, 0
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

local function cross2d(ax, ay, bx, by)
	return ax * by - ay * bx
end

local function segmentDistanceSq(ax, ay, bx, by, cx, cy, dx, dy)
	if not (ax and ay and bx and by and cx and cy and dx and dy) then
		return huge
	end

	local rX = bx - ax
	local rY = by - ay
	local sX = dx - cx
	local sY = dy - cy
	local denom = cross2d(rX, rY, sX, sY)
	local qX = cx - ax
	local qY = cy - ay

	if abs(denom) > 1e-6 then
		local t = cross2d(qX, qY, sX, sY) / denom
		local u = cross2d(qX, qY, rX, rY) / denom
		if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
			return 0
		end
	end

	local minDistSq = huge
	local _, _, distSq = closestPointOnSegment(ax, ay, cx, cy, dx, dy)
	minDistSq = min(minDistSq, distSq)
	_, _, distSq = closestPointOnSegment(bx, by, cx, cy, dx, dy)
	minDistSq = min(minDistSq, distSq)
	_, _, distSq = closestPointOnSegment(cx, cy, ax, ay, bx, by)
	minDistSq = min(minDistSq, distSq)
	_, _, distSq = closestPointOnSegment(dx, dy, ax, ay, bx, by)
	minDistSq = min(minDistSq, distSq)

	return minDistSq
end

local function segmentRectIntersection(ax, ay, bx, by, rx, ry, rw, rh)
	if not (ax and ay and bx and by and rx and ry and rw and rh) then
		return false
	end

	if rw <= 0 or rh <= 0 then
		return false
	end

	local rMaxX = rx + rw
	local rMaxY = ry + rh

	local minX = min(ax, bx)
	local maxX = max(ax, bx)
	local minY = min(ay, by)
	local maxY = max(ay, by)

	if maxX < rx or minX > rMaxX or maxY < ry or minY > rMaxY then
		return false
	end

	local dx = bx - ax
	local dy = by - ay
	local t0 = 0
	local t1 = 1

	local function clip(p, q)
		if abs(p) < 1e-6 then
			if q < 0 then
				return false
			end
			return true
		end

		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			if r > t0 then
				t0 = r
			end
		else
			if r < t0 then
				return false
			end
			if r < t1 then
				t1 = r
			end
		end

		return true
	end

	if clip(-dx, ax - rx) and clip(dx, rMaxX - ax) and clip(-dy, ay - ry) and clip(dy, rMaxY - ay) then
		local t = t0
		if t < 0 or t > 1 then
			t = t1
		end

		t = max(0, min(1, t or 0))
		local ix = ax + dx * t
		local iy = ay + dy * t
		return true, ix, iy, t
	end

	return false
end

local function isSelfCollisionAlongPath(startX, startY, endX, endY)
	if not (startX and startY and endX and endY) then
		return false
	end

	local bodyCount = trail and #trail or 0
	if bodyCount <= 3 then
		return false
	end

	local radiusSq = SELF_COLLISION_RADIUS_SQ

	for i = 3, bodyCount do
		local seg = trail[i]
		local nextSeg = trail[i + 1]
		local sx = seg and seg.drawX
		local sy = seg and seg.drawY
		local ex = nextSeg and nextSeg.drawX or sx
		local ey = nextSeg and nextSeg.drawY or sy

		if sx and sy and ex and ey then
			local distSq = segmentDistanceSq(startX, startY, endX, endY, sx, sy, ex, ey)
			if distSq <= radiusSq then
				return true
			end
		end
	end

	return false
end

local function copySegmentData(segment)
	if not segment then
		return nil
	end

        local copy = acquireSegment()
        copy.drawX = segment.drawX
        copy.drawY = segment.drawY
        copy.dirX = segment.dirX
        copy.dirY = segment.dirY
        copy.x = segment.x
        copy.y = segment.y
        copy.fruitMarker = segment.fruitMarker
        copy.fruitMarkerX = segment.fruitMarkerX
        copy.fruitMarkerY = segment.fruitMarkerY
        copy.fruitScore = segment.fruitScore
        copy.lengthToPrev = segment.lengthToPrev
        copy.cellCol = segment.cellCol
        copy.cellRow = segment.cellRow

        return copy
end

local function computeTrailLength(trailData)
	if not trailData then
		return 0
	end

	local total = 0
	for i = 2, #trailData do
		local prev = trailData[i - 1]
		local curr = trailData[i]
		local ax, ay = prev and prev.drawX, prev and prev.drawY
		local bx, by = curr and curr.drawX, curr and curr.drawY
		if ax and ay and bx and by then
			local dx = bx - ax
			local dy = by - ay
			total = total + sqrt(dx * dx + dy * dy)
		end
	end

	return total
end

local function applyTrailLengthLimit(maxLen, gluttonsWakeActive)
	if not trail then
		trailLength = 0
		return
	end

	if not maxLen then
		return
	end

	if maxLen <= 0 then
		recycleTrail(trail)
		trail = {}
		trailLength = 0
		return
	end

	if #trail == 0 or trailLength <= maxLen then
		return
	end

	local remaining = trailLength - maxLen
	local removeStartIndex = nil
	local shortenIndex = nil
	local newTailX, newTailY = nil, nil

	local index = #trail
	while index >= 2 and remaining > 0 do
		local segment = trail[index]
		if not segment then
			break
		end

		local length = segment.lengthToPrev or 0
		if length <= 0 then
			removeStartIndex = index
			index = index - 1
		elseif length <= remaining + 1e-6 then
			remaining = remaining - length
			removeStartIndex = index
			index = index - 1
		else
			shortenIndex = index
			local prev = trail[index - 1]
			if prev and prev.drawX and prev.drawY and segment.drawX and segment.drawY then
				local dx = segment.drawX - prev.drawX
				local dy = segment.drawY - prev.drawY
				local ratio = (length - remaining) / length
				if ratio < 0 then
					ratio = 0
				elseif ratio > 1 then
					ratio = 1
				end
				newTailX = prev.drawX + dx * ratio
				newTailY = prev.drawY + dy * ratio
			end
			remaining = 0
			break
		end
	end

	if removeStartIndex then
		crystallizeGluttonsWakeSegments(trail, removeStartIndex, #trail, gluttonsWakeActive)
		for i = removeStartIndex, #trail do
			local seg = trail[i]
			if seg then
				local segLen = seg.lengthToPrev or 0
				if segLen ~= 0 then
					trailLength = trailLength - segLen
				end
			end
		end
		releaseSegmentRange(trail, removeStartIndex)
	end

	if shortenIndex then
		if removeStartIndex and shortenIndex >= removeStartIndex then
			shortenIndex = removeStartIndex - 1
		end
		if shortenIndex and shortenIndex >= 2 then
			local segment = trail[shortenIndex]
			if segment then
				if newTailX and newTailY then
					segment.drawX = newTailX
					segment.drawY = newTailY
				end
				updateSegmentLengthAt(shortenIndex)
			end
		end
	end

	if trailLength > maxLen + 1e-4 then
		syncTrailLength()
	end

	if trailLength < 0 then
		trailLength = 0
	end
end

local function sliceTrailByLength(sourceTrail, maxLength, destination)
	local result = destination or {}
	local previousCount = #result
	local count = 0

	if not sourceTrail or #sourceTrail == 0 then
		releaseSegmentRange(result, 1)
		return result
	end

	if previousCount >= 1 then
		local existing = result[1]
		if existing then
			releaseSegment(existing)
		end
	end
	local first = copySegmentData(sourceTrail[1]) or acquireSegment()
	count = 1
	result[count] = first

	if not (maxLength and maxLength > 0) then
		releaseSegmentRange(result, count + 1)
		return result
	end

	local accumulated = 0
	for i = 2, #sourceTrail do
		local prev = sourceTrail[i - 1]
		local curr = sourceTrail[i]
		local px, py = prev and prev.drawX, prev and prev.drawY
		local cx, cy = curr and curr.drawX, curr and curr.drawY
		if not (px and py and cx and cy) then
			break
		end

		local dx = cx - px
		local dy = cy - py
		local segLen = sqrt(dx * dx + dy * dy)

		if segLen <= 1e-6 then
			count = count + 1
			if count <= previousCount then
				local existing = result[count]
				if existing then
					releaseSegment(existing)
				end
			end
			result[count] = copySegmentData(curr)
		else
			if accumulated + segLen >= maxLength then
				local remaining = maxLength - accumulated
				local t = remaining / segLen
				if t < 0 then
					t = 0
				elseif t > 1 then
					t = 1
				end
				local x = px + dx * t
				local y = py + dy * t
				if count + 1 <= previousCount then
					local existing = result[count + 1]
					if existing then
						releaseSegment(existing)
					end
				end
				local segCopy = copySegmentData(curr) or acquireSegment()
				segCopy.drawX = x
				segCopy.drawY = y
				count = count + 1
				result[count] = segCopy
				releaseSegmentRange(result, count + 1)
				return result
			end

			accumulated = accumulated + segLen
			count = count + 1
			if count <= previousCount then
				local existing = result[count]
				if existing then
					releaseSegment(existing)
				end
			end
			result[count] = copySegmentData(curr)
		end
	end

	releaseSegmentRange(result, count + 1)

	return result
end

local function cloneTailFromIndex(startIndex, entryX, entryY)
	if not trail or #trail == 0 then
		return {}
	end

	local index = max(1, min(startIndex or 1, #trail))
	local clone = {}

	for i = index, #trail do
		local segCopy = copySegmentData(trail[i]) or {}
		if i == index then
			segCopy.drawX = entryX or segCopy.drawX
			segCopy.drawY = entryY or segCopy.drawY
		end
		clone[#clone + 1] = segCopy
	end

	return clone
end

local function findPortalEntryIndex(entryX, entryY)
	if not trail or #trail == 0 then
		return 1
	end

	local bestIndex = 1
	local bestDist = huge

	for i = 1, #trail - 1 do
		local segA = trail[i]
		local segB = trail[i + 1]
		local ax, ay = segA and segA.drawX, segA and segA.drawY
		local bx, by = segB and segB.drawX, segB and segB.drawY
		if ax and ay and bx and by then
			local _, _, distSq = closestPointOnSegment(entryX, entryY, ax, ay, bx, by)
			if distSq < bestDist then
				bestDist = distSq
				bestIndex = i + 1
			end
		end
	end

	if bestIndex > #trail then
		bestIndex = #trail
	end

	return bestIndex
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
	local lastInsideX, lastInsideY = nil, nil
	local lastInsideDirX, lastInsideDirY = nil, nil
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
			lastInsideX = x
			lastInsideY = y
			lastInsideDirX = seg.dirX
			lastInsideDirY = seg.dirY

			local nextSeg = workingTrail[i + 1]
			if nextSeg then
				local nx, ny = nextSeg.drawX, nextSeg.drawY
				if nx and ny then
					local segDx = nx - x
					local segDy = ny - y
					consumed = consumed + sqrt(segDx * segDx + segDy * segDy)
				end
			end

			remove(workingTrail, i)
		else
			break
		end
	end

	local newHead = workingTrail[1]
	if removedAny and newHead and lastInsideX and lastInsideY then
		local oldDx = newHead.drawX - lastInsideX
		local oldDy = newHead.drawY - lastInsideY
		local oldLen = sqrt(oldDx * oldDx + oldDy * oldDy)
		if oldLen > 0 then
			consumed = consumed - oldLen
		end

		local ix, iy = findCircleIntersection(lastInsideX, lastInsideY, newHead.drawX, newHead.drawY, hx, hy, radius)
		if ix and iy then
			local newDx = ix - lastInsideX
			local newDy = iy - lastInsideY
			local newLen = sqrt(newDx * newDx + newDy * newDy)
			consumed = consumed + newLen
			newHead.drawX = ix
			newHead.drawY = iy
		else
			-- fallback: if no intersection, clamp head to previous inside point
			newHead.drawX = lastInsideX
			newHead.drawY = lastInsideY
		end
	end

	hole.consumedLength = consumed

	local totalLength = max(0, (segmentCount or 0) * SEGMENT_SPACING)
	if totalLength <= 1e-4 then
		hole.fullyConsumed = true
	else
		local epsilon = SEGMENT_SPACING * 0.1
		if consumed >= totalLength - epsilon then
			hole.fullyConsumed = true
		else
			hole.fullyConsumed = false
		end
	end

	if newHead and newHead.drawX and newHead.drawY then
		hole.entryPointX = newHead.drawX
		hole.entryPointY = newHead.drawY
	elseif lastInsideX and lastInsideY then
		hole.entryPointX = lastInsideX
		hole.entryPointY = lastInsideY
	end

	if lastInsideDirX and lastInsideDirY then
		hole.entryDirX, hole.entryDirY = normalizeDirection(lastInsideDirX, lastInsideDirY)
	end
end

local isGluttonsWakeActive

local function trimTrailToSegmentLimit()
	if not trail or #trail == 0 then
		trailLength = 0
		return
	end

	local consumedLength = (descendingHole and descendingHole.consumedLength) or 0
	local maxLen = max(0, segmentCount * SEGMENT_SPACING - consumedLength)

	local gluttonsWakeActive = isGluttonsWakeActive()
	applyTrailLengthLimit(maxLen, gluttonsWakeActive)

	local i = 2
	while i <= #trail do
		local seg = trail[i]
		if not seg then
			break
		end

		local segLen = seg.lengthToPrev or 0
		if segLen <= 1e-6 then
			local removed = remove(trail, i)
			if removed then
				if gluttonsWakeActive then
					spawnGluttonsWakeRock(removed)
				end
				if removed.lengthToPrev and removed.lengthToPrev ~= 0 then
					trailLength = trailLength - removed.lengthToPrev
				end
				releaseSegment(removed)
			end
			if i <= #trail then
				updateSegmentLengthAt(i)
			end
		else
			i = i + 1
		end
	end

	if trailLength < 0 then
		trailLength = 0
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
	local dirLen = sqrt(dirX * dirX + dirY * dirY)
	if dirLen <= 1e-4 then
		dirX = hx - entryX
		dirY = hy - entryY
		dirLen = sqrt(dirX * dirX + dirY * dirY)
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

	local bodyColor = SnakeCosmetics:getBodyColor() or {1, 1, 1, 1}
	local r = bodyColor[1] or 1
	local g = bodyColor[2] or 1
	local b = bodyColor[3] or 1
	local a = bodyColor[4] or 1

	local baseRadius = SEGMENT_SIZE * 0.5
	local holeRadius = max(baseRadius, hole.radius or baseRadius * 1.6)
	local depthTarget = min(1, consumed / (holeRadius + SEGMENT_SPACING * 0.75))
	local renderDepth = max(depth, depthTarget)

	local steps = max(2, min(7, floor((consumed + SEGMENT_SPACING * 0.4) / (SEGMENT_SPACING * 0.55)) + 2))

	local totalLength = (segmentCount or 0) * SEGMENT_SPACING
	local completion = 0
	if totalLength > 1e-4 then
		completion = min(1, consumed / totalLength)
	end
	local globalVisibility = max(0, 1 - completion)

	local perpX, perpY = -dirY, dirX
	local wobble = 0
	if hole.time then
		wobble = math.sin(hole.time * 4.6) * 0.35
	end

	love.graphics.setLineWidth(2)

	for layer = 0, steps - 1 do
		local layerFrac = (layer + 0.6) / steps
		local layerDepth = min(1, renderDepth * (0.35 + 0.65 * layerFrac))
		local depthFade = 1 - layerDepth
		local visibility = depthFade * depthFade * globalVisibility

		if visibility <= 1e-3 then
			break
		end

		local radius = baseRadius * (0.9 - 0.55 * layerDepth)
		radius = max(baseRadius * 0.2, radius)

		local sink = holeRadius * 0.35 * layerDepth
		local lateral = wobble * (0.4 + 0.25 * layerFrac) * depthFade
		local px = entryX + (hx - entryX) * layerDepth + dirX * sink + perpX * radius * lateral
		local py = entryY + (hy - entryY) * layerDepth + dirY * sink + perpY * radius * lateral

		local shade = 0.25 + 0.7 * visibility
		local shadeR = r * shade
		local shadeG = g * shade
		local shadeB = b * shade
		local alpha = a * (0.2 + 0.8 * visibility)
		love.graphics.setColor(shadeR, shadeG, shadeB, max(0, min(1, alpha)))
		love.graphics.circle("fill", px, py, radius)

		local outlineAlpha = 0.15 + 0.5 * visibility
		love.graphics.setColor(0, 0, 0, max(0, min(1, outlineAlpha)))
		love.graphics.circle("line", px, py, radius)

		if layer == 0 then
			local highlight = 0.45 * min(1, depthFade * 1.1) * globalVisibility
			if highlight > 0 then
				love.graphics.setColor(r, g, b, highlight)
				love.graphics.circle("line", px, py, radius * 0.75)
			end
		end
	end
	local coverAlpha = max(depth, renderDepth) * 0.55
	love.graphics.setColor(0, 0, 0, coverAlpha)
	love.graphics.circle("fill", hx, hy, holeRadius * (0.38 + 0.22 * renderDepth))

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function collectUpgradeVisuals(self)
	local visuals = self._upgradeVisualBuffer
	-- The returned table is reused every frame; treat it as read-only outside this function.
	if visuals then
		wipeTable(visuals)
	else
		visuals = {}
		self._upgradeVisualBuffer = visuals
	end

	local pool = self._upgradeVisualPool
	if not pool then
		pool = {}
		self._upgradeVisualPool = pool
	end

	local hasAny = false

	local function acquireEntry(key)
		local entry = pool[key]
		if not entry then
			entry = {}
			pool[key] = entry
		else
			wipeTable(entry)
		end

		visuals[key] = entry
		hasAny = true

		return entry
	end

	local adrenaline = self.adrenaline
	if adrenaline and adrenaline.active and not adrenaline.suppressVisuals then
		local entry = acquireEntry("adrenaline")
		entry.active = true
		entry.timer = adrenaline.timer or 0
		entry.duration = adrenaline.duration or 0
	end

        local speedVisual = self.speedVisual
        if speedVisual and (((speedVisual.intensity or 0) > 0.01) or (speedVisual.target or 0) > 0) then
                local entry = acquireEntry("speedArcs")
                entry.intensity = speedVisual.intensity or 0
                entry.ratio = speedVisual.ratio or 0
                entry.time = speedVisual.time or 0
        end

        local reflex = self.serpentsReflex
        if reflex and (((reflex.intensity or 0) > 0.01) or (reflex.stacks or 0) > 0 or (reflex.flash or 0) > 0) then
                local entry = acquireEntry("serpentsReflex")
                entry.stacks = reflex.stacks or 0
                entry.intensity = reflex.intensity or 0
                entry.time = reflex.time or 0
                entry.flash = reflex.flash or 0
        end

        local swiftFangs = self.swiftFangs
        if swiftFangs and (((swiftFangs.intensity or 0) > 0.01) or (swiftFangs.stacks or 0) > 0) then
                local entry = acquireEntry("swiftFangs")
                entry.stacks = swiftFangs.stacks or 0
		entry.intensity = swiftFangs.intensity or 0
		entry.target = swiftFangs.target or 0
		entry.speedRatio = swiftFangs.speedRatio or 1
		entry.active = swiftFangs.active or false
		entry.time = swiftFangs.time or 0
		entry.flash = swiftFangs.flash or 0
	end

        local zephyr = self.zephyrCoils
        if zephyr and (((zephyr.intensity or 0) > 0.01) or (zephyr.stacks or 0) > 0 or (zephyr.target or 0) > 0) then
                local entry = acquireEntry("zephyrCoils")
                entry.stacks = zephyr.stacks or 0
                entry.intensity = zephyr.intensity or 0
                entry.time = zephyr.time or 0
                entry.ratio = zephyr.speedRatio or (1 + 0.2 * min(1, max(0, zephyr.intensity or 0)))
                entry.hasBody = (segmentCount or 0) > 1
        end

        local momentum = self.momentumCoils
        if momentum and (((momentum.intensity or 0) > 0.01) or (momentum.stacks or 0) > 0) then
                local entry = acquireEntry("momentumCoils")
                entry.stacks = momentum.stacks or 0
                entry.intensity = momentum.intensity or 0
                entry.target = momentum.target or 0
                entry.time = momentum.time or 0
        end

        local deliberate = self.deliberateCoil
        if deliberate and (((deliberate.intensity or 0) > 0.01) or (deliberate.stacks or 0) > 0) then
                local entry = acquireEntry("deliberateCoil")
                entry.stacks = deliberate.stacks or 0
                entry.intensity = deliberate.intensity or 0
                entry.time = deliberate.time or 0
        end

	local timeDilation = self.timeDilation
	if timeDilation then
		local entry = acquireEntry("timeDilation")
		entry.active = timeDilation.active or false
		entry.timer = timeDilation.timer or 0
		entry.duration = timeDilation.duration or 0
		entry.cooldown = timeDilation.cooldown or 0
		entry.cooldownTimer = timeDilation.cooldownTimer or 0
	end

	local chronoWard = self.chronoWard
	if chronoWard and (((chronoWard.intensity or 0) > 1e-3) or chronoWard.active) then
		local entry = acquireEntry("chronoWard")
		entry.active = chronoWard.active or false
		entry.intensity = chronoWard.intensity or 0
		entry.time = chronoWard.time or 0
	end

	local temporalAnchor = self.temporalAnchor
	if temporalAnchor and (((temporalAnchor.intensity or 0) > 1e-3) or (temporalAnchor.target or 0) > 0) then
		local entry = acquireEntry("temporalAnchor")
		entry.intensity = temporalAnchor.intensity or 0
		entry.ready = temporalAnchor.ready or 0
		entry.active = temporalAnchor.active or false
		entry.time = temporalAnchor.time or 0
	end

	local dash = self.dash
	if dash then
		local entry = acquireEntry("dash")
		entry.active = dash.active or false
		entry.timer = dash.timer or 0
		entry.duration = dash.duration or 0
		entry.cooldown = dash.cooldown or 0
		entry.cooldownTimer = dash.cooldownTimer or 0
	end

	local stormchaser = self.stormchaser
	if stormchaser and ((stormchaser.intensity or 0) > 1e-3 or (stormchaser.target or 0) > 0) then
		local entry = acquireEntry("stormchaser")
		entry.intensity = stormchaser.intensity or 0
		entry.primed = stormchaser.primed or false
		entry.time = stormchaser.time or 0
	end

	local eventHorizon = self.eventHorizon
	if eventHorizon and ((eventHorizon.intensity or 0) > 1e-3 or (eventHorizon.target or 0) > 0) then
		local entry = acquireEntry("eventHorizon")
		entry.intensity = eventHorizon.intensity or 0
		entry.spin = eventHorizon.spin or 0
		entry.time = eventHorizon.time or 0
	end

	local phoenix = self.phoenixEcho
	if phoenix and (((phoenix.intensity or 0) > 1e-3) or (phoenix.charges or 0) > 0 or (phoenix.flareTimer or 0) > 0) then
		local entry = acquireEntry("phoenixEcho")
		local flare = 0
		local flareDuration = phoenix.flareDuration or 1.2
		if flareDuration > 0 and (phoenix.flareTimer or 0) > 0 then
			flare = min(1, phoenix.flareTimer / flareDuration)
		end
		entry.intensity = phoenix.intensity or 0
		entry.charges = phoenix.charges or 0
		entry.flare = flare
		entry.time = phoenix.time or 0
	end

	local stoneSkin = self.stoneSkinVisual
	if stoneSkin and (((stoneSkin.intensity or 0) > 0.01) or (stoneSkin.flash or 0) > 0 or (stoneSkin.charges or 0) > 0) then
		local entry = acquireEntry("stoneSkin")
		entry.intensity = stoneSkin.intensity or 0
		entry.flash = stoneSkin.flash or 0
		entry.charges = stoneSkin.charges or 0
		entry.time = stoneSkin.time or 0
	end

	local diffraction = self.diffractionBarrier
	if diffraction then
		local intensity = diffraction.intensity or 0
		local flash = diffraction.flash or 0
		if intensity > 0.001 or flash > 0.001 or diffraction.active then
			local entry = acquireEntry("diffractionBarrier")
			entry.intensity = intensity
			entry.flash = flash
			entry.time = diffraction.time or 0
		end
	end

	if hasAny then
		return visuals
	end

	return nil
end

-- Build initial trail aligned to CELL CENTERS
local function buildInitialTrail()
        local newTrail, length = lifecycle.buildInitialTrail(segmentCount, direction)
        trailLength = length
        return newTrail
end

local function applyLoadResult(state)
        screenW = state.screenW
        screenH = state.screenH
        segmentCount = state.segmentCount
        popTimer = state.popTimer
        moveProgress = state.moveProgress
        isDead = state.isDead
        trail = state.trail
        trailLength = state.trailLength
        descendingHole = state.descendingHole
        severedPieces = state.severedPieces
        portalAnimation = state.portalAnimation
        cellKeyStride = state.cellKeyStride
end

function Snake:load(w, h)
        local state = lifecycle.load(self, {
                w = w,
                h = h,
                direction = direction,
                pendingDir = pendingDir,
                trail = trail,
                severedPieces = severedPieces,
                portalAnimation = portalAnimation,
                buildInitialTrail = buildInitialTrail,
        })

        applyLoadResult(state)
        syncTrailLength()
        rebuildOccupancyFromTrail()
end

spawnGluttonsWakeRock = lifecycle.spawnGluttonsWakeRock
crystallizeGluttonsWakeSegments = lifecycle.crystallizeGluttonsWakeSegments
isGluttonsWakeActive = lifecycle.isGluttonsWakeActive

function Snake:setDirection(name)
        lifecycle.setDirection(name, isDead, direction, pendingDir)
end

function Snake:setDead(state)
        isDead = lifecycle.setDead(state, rebuildOccupancyFromTrail)
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
	syncSnakeHeadSegments(trail, 0, newHeadSegmentsMax)
	local count = trail and #trail or 0
	if count > 0 then
		recalcSegmentLengthsRange(1, min(count, 2))
	end
end

function Snake:resetMovementProgress()
	moveProgress = 0
end

function Snake:translate(dx, dy, options)
	dx = dx or 0
	dy = dy or 0
	if dx == 0 and dy == 0 then
		return
	end

	options = options or EMPTY_TABLE

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

	rebuildOccupancyFromTrail()

	if options.resetMoveProgress then
		moveProgress = 0
	end
end

function Snake:beginPortalWarp(params)
	if type(params) ~= "table" then
		return false
	end

	local entryX = params.entryX
	local entryY = params.entryY
	local exitX = params.exitX
	local exitY = params.exitY
	local duration = params.duration
	local dx = params.dx
	local dy = params.dy

	if not (entryX and entryY and exitX and exitY) then
		return false
	end

	local headSeg = trail and trail[1]
	if headSeg then
		local hx = headSeg.drawX or headSeg.x or 0
		local hy = headSeg.drawY or headSeg.y or 0
		if dx == nil then dx = (exitX or hx) - hx end
		if dy == nil then dy = (exitY or hy) - hy end
	else
		dx = dx or 0
		dy = dy or 0
	end

	local entryIndex = findPortalEntryIndex(entryX, entryY)
	local entryClone = cloneTailFromIndex(entryIndex, entryX, entryY)
	if not entryClone or #entryClone == 0 then
		return false
	end

	local totalLength = computeTrailLength(entryClone)
	if totalLength <= 0 then
		totalLength = SEGMENT_SPACING
	end

	local warpDuration = duration or 0.3
	if warpDuration < 0.05 then
		warpDuration = 0.05
	end

	if (abs(dx or 0) > 0) or (abs(dy or 0) > 0) then
		self:translate(dx or 0, dy or 0, {resetMoveProgress = true})
	else
		self:resetMovementProgress()
	end

	local head = trail and trail[1]
	if head then
		head.drawX = exitX
		head.drawY = exitY
		local count = trail and #trail or 0
		if count > 0 then
			recalcSegmentLengthsRange(1, min(count, 2))
		end
	end

	local entrySource = {}
	for i = 1, #entryClone do
		entrySource[i] = copySegmentData(entryClone[i]) or {}
	end
	recycleTrail(entryClone)

	clearPortalAnimation(portalAnimation)
	portalAnimation = {
		timer = 0,
		duration = warpDuration,
		entryIndex = entryIndex,
		entryX = entryX,
		entryY = entryY,
		exitX = exitX,
		exitY = exitY,
		totalLength = totalLength,
		entrySourceTrail = entrySource,
		entryTrail = sliceTrailByLength(entrySource, totalLength),
		exitTrail = {},
		progress = 0,
		entryHole = {
			x = entryX,
			y = entryY,
			baseRadius = SEGMENT_SIZE * 0.7,
			radius = SEGMENT_SIZE * 0.7,
			open = 0,
			visibility = 0,
			spin = 0,
			time = 0,
		},
		exitHole = {
			x = exitX,
			y = exitY,
			baseRadius = SEGMENT_SIZE * 0.75,
			radius = SEGMENT_SIZE * 0.75,
			open = 0,
			visibility = 0,
			spin = 0,
			time = 0,
		},
	}

	return true
end

function Snake:setDirectionVector(dx, dy)
	if isDead then return end

	dx = dx or 0
	dy = dy or 0

	local nx, ny = normalizeDirection(dx, dy)
	if nx == 0 and ny == 0 then
		return
	end

	assignDirection(direction, nx, ny)
	assignDirection(pendingDir, nx, ny)

	local head = trail and trail[1]
	if head then
		head.dirX = nx
		head.dirY = ny
	end

end

function Snake:getHeadCell()
	local hx, hy = self:getHead()
	if not (hx and hy) then
		return nil, nil
	end
	return toCell(hx, hy)
end

local SAFE_ZONE_SEEN_RESET = 10000000

local safeZoneCellsBuffer = {}
local safeZoneSeen = {}
local safeZoneSeenGen = 0

local function clearExcessSafeCells(cells, count)
	for i = count + 1, #cells do
		cells[i] = nil
	end
end

local function addSafeCellUnique(cells, seen, gen, count, col, row)
	local stride = cellKeyStride
	if stride <= 0 then
		stride = (Arena and Arena.rows or 0) + 16
		if stride <= 0 then
			stride = 64
		end
		cellKeyStride = stride
	end

	local key = col * stride + row
	if seen[key] ~= gen then
		seen[key] = gen
		count = count + 1
		local cell = cells[count]
		if cell then
			cell[1] = col
			cell[2] = row
		else
			cells[count] = {col, row}
		end
	end

	return count
end

function Snake:getSafeZone(lookahead)
	local cells = safeZoneCellsBuffer
	local seen = safeZoneSeen

	safeZoneSeenGen = safeZoneSeenGen + 1
	if safeZoneSeenGen >= SAFE_ZONE_SEEN_RESET then
		safeZoneSeenGen = 1
		for key in pairs(seen) do
			seen[key] = 0
		end
	end

	local gen = safeZoneSeenGen

	local count = 0

	local hx, hy = self:getHeadCell()
	if not (hx and hy) then
		clearExcessSafeCells(cells, count)
		return cells
	end

local dir = self:getDirection()

for i = 1, lookahead do
local cx = hx + dir[DIR_X] * i
local cy = hy + dir[DIR_Y] * i
count = addSafeCellUnique(cells, seen, gen, count, cx, cy)
end

local pending = pendingDir
if pending and (pending[DIR_X] ~= dir[DIR_X] or pending[DIR_Y] ~= dir[DIR_Y]) then
-- Immediate turn path (if the queued direction snaps before the next tile)
local px, py = hx, hy
for i = 1, lookahead do
px = px + pending[DIR_X]
py = py + pending[DIR_Y]
count = addSafeCellUnique(cells, seen, gen, count, px, py)
end

-- Typical turn path: advance one tile forward, then apply the queued turn
local turnCol = hx + dir[DIR_X]
local turnRow = hy + dir[DIR_Y]
px, py = turnCol, turnRow
for i = 2, lookahead do
px = px + pending[DIR_X]
py = py + pending[DIR_Y]
count = addSafeCellUnique(cells, seen, gen, count, px, py)
end
	end

	clearExcessSafeCells(cells, count)

	return cells
end

function Snake:drawClipped(hx, hy, hr)
        SnakeRender.drawClipped(renderState, {
                snake = self,
                trail = trail,
                segmentCount = segmentCount,
                segmentSize = SEGMENT_SIZE,
                popTimer = popTimer,
                clipX = hx,
                clipY = hy,
                clipRadius = hr,
                headX = select(1, self:getHead()),
                headY = select(2, self:getHead()),
                descendingHole = descendingHole,
                collectUpgradeVisuals = collectUpgradeVisuals,
                shields = self.shields,
                shieldFlashTimer = self.shieldFlashTimer,
                findCircleIntersection = findCircleIntersection,
                drawDescendingIntoHole = drawDescendingIntoHole,
        })
end

function Snake:startDescending(hx, hy, hr)
	descendingHole = {
		x = hx,
		y = hy,
		radius = hr or 0,
		consumedLength = 0,
		renderDepth = 0,
		time = 0,
		fullyConsumed = false,
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
	if isDead then return false, "dead", {fatal = true} end

	if self.phoenixEcho then
		local state = self.phoenixEcho
		state.time = (state.time or 0) + dt
		state.flareDuration = state.flareDuration or 1.2
		if state.flareTimer then
			state.flareTimer = max(0, state.flareTimer - dt)
		end
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 4.2)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if (state.charges or 0) <= 0 and target <= 0 and intensity < 0.01 and (state.flareTimer or 0) <= 0 then
			self.phoenixEcho = nil
		end
	end

	if self.eventHorizon then
		local state = self.eventHorizon
		state.time = (state.time or 0) + dt
		state.spin = (state.spin or 0) + dt * (0.7 + 0.9 * (state.intensity or 0))
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * (state.active and 3.2 or 2.0))
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if not state.active and target <= 0 and intensity < 0.01 then
			self.eventHorizon = nil
		end
	end

	if self.stormchaser then
		local state = self.stormchaser
		state.time = (state.time or 0) + dt
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * (state.primed and 6.5 or 4.2))
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if not state.primed and target <= 0 and intensity < 0.02 then
			self.stormchaser = nil
		end
	end

	if self.diffractionBarrier then
		local state = self.diffractionBarrier
		state.time = (state.time or 0) + dt
		local target
		if state.active then
			target = 1
		else
			target = state.target or 0
		end

		state.target = target
		local blend = min(1, dt * 5.2)
		local current = state.intensity or 0
		state.intensity = current + (target - current) * blend
		state.flash = max(0, (state.flash or 0) - dt * 2.8)

		if not state.active and target <= 0 and state.intensity <= 0.02 and state.flash <= 0.02 then
			self.diffractionBarrier = nil
		end
	end

	local zephyr = self.zephyrCoils
	if zephyr then
		zephyr.time = (zephyr.time or 0) + dt
		local stacks = zephyr.stacks or 0
		local target = zephyr.target or (stacks > 0 and min(1, 0.45 + 0.2 * min(stacks, 3)) or 0)
		zephyr.target = target
		local blend = min(1, dt * 3.6)
		local intensity = (zephyr.intensity or 0) + (target - (zephyr.intensity or 0)) * blend
		zephyr.intensity = intensity
		if stacks <= 0 and intensity <= 0.01 then
			self.zephyrCoils = nil
		end
	end

        local stoneSkin = self.stoneSkinVisual
        if stoneSkin then
                stoneSkin.time = (stoneSkin.time or 0) + dt
                local charges = self.stoneSkinSawGrace or 0
		stoneSkin.charges = charges
		local target = stoneSkin.target or (charges > 0 and min(1, 0.45 + 0.18 * min(charges, 4)) or 0)
		stoneSkin.target = target
		local blend = min(1, dt * 5.2)
		local current = stoneSkin.intensity or 0
		stoneSkin.intensity = current + (target - current) * blend
                stoneSkin.flash = max(0, (stoneSkin.flash or 0) - dt * 2.6)
                if charges <= 0 and stoneSkin.intensity <= 0.02 and stoneSkin.flash <= 0.02 then
                        self.stoneSkinVisual = nil
                end
        end

        local reflex = self.serpentsReflex
        if reflex then
                reflex.time = (reflex.time or 0) + dt
                local target = reflex.target or 0
                local blend = min(1, dt * 4.4)
                local current = reflex.intensity or 0
                reflex.intensity = current + (target - current) * blend
                reflex.flash = max(0, (reflex.flash or 0) - dt * 3.2)
                if (reflex.stacks or 0) <= 0 and reflex.intensity <= 0.02 and reflex.flash <= 0.02 then
                        self.serpentsReflex = nil
                end
        end

        local deliberate = self.deliberateCoil
        if deliberate then
                deliberate.time = (deliberate.time or 0) + dt
                local target = deliberate.target or 0
                local blend = min(1, dt * 3.6)
                local current = deliberate.intensity or 0
                deliberate.intensity = current + (target - current) * blend
                if (deliberate.stacks or 0) <= 0 and deliberate.intensity <= 0.02 then
                        self.deliberateCoil = nil
                end
        end

	-- base speed with upgrades/modifiers
	local head = trail[1]
	local previousHeadX, previousHeadY = head and head.drawX, head and head.drawY
	local speed = self:getSpeed()
	local baselineSpeed = speed

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
		local totalDepth = max(SEGMENT_SPACING * 0.5, (hole.radius or 0) + SEGMENT_SPACING)
		local targetDepth = min(1, consumed / totalDepth)
		local currentDepth = hole.renderDepth or 0
		local blend = min(1, dt * 10)
		currentDepth = currentDepth + (targetDepth - currentDepth) * blend
		hole.renderDepth = currentDepth
	end

	if self.dash then
		if self.dash.cooldownTimer and self.dash.cooldownTimer > 0 then
			self.dash.cooldownTimer = max(0, (self.dash.cooldownTimer or 0) - dt)
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
			self.timeDilation.cooldownTimer = max(0, (self.timeDilation.cooldownTimer or 0) - dt)
		end

		if self.timeDilation.active then
			self.timeDilation.timer = (self.timeDilation.timer or 0) - dt
			if self.timeDilation.timer <= 0 then
				self.timeDilation.active = false
				self.timeDilation.timer = 0
			end
		end
	end

	if self.chronoWard then
		local ward = self.chronoWard
		ward.time = (ward.time or 0) + dt

		if ward.active then
			ward.timer = (ward.timer or 0) - dt
			if ward.timer <= 0 then
				ward.active = false
				ward.timer = 0
			end
		end

		local target = ward.active and 1 or 0
		ward.target = target
		local blend = min(1, dt * 6.0)
		local currentIntensity = ward.intensity or 0
		ward.intensity = currentIntensity + (target - currentIntensity) * blend

		if not ward.active and (ward.intensity or 0) <= 0.01 then
			self.chronoWard = nil
		end
	end

	local dilation = self.timeDilation
	if dilation and dilation.source == "temporal_anchor" then
		local state = self.temporalAnchor
		if not state then
			state = {intensity = 0, target = 0, ready = 0, time = 0}
			self.temporalAnchor = state
		end
		state.time = (state.time or 0) + dt
		state.active = dilation.active or false
		local cooldown = dilation.cooldown or 0
		local cooldownTimer = dilation.cooldownTimer or 0
		local readiness
		if dilation.active then
			readiness = 1
		elseif cooldown and cooldown > 0 then
			readiness = 1 - min(1, cooldownTimer / cooldown)
		else
			readiness = (cooldownTimer <= 0) and 1 or 0
		end
		state.ready = max(0, min(1, readiness))
		if dilation.active then
			state.target = 1
		else
			state.target = max(0.2, 0.3 + state.ready * 0.5)
		end
	elseif self.temporalAnchor then
		local state = self.temporalAnchor
		state.time = (state.time or 0) + dt
		state.active = false
		state.ready = 0
		state.target = 0
	end

	if self.temporalAnchor then
		local state = self.temporalAnchor
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 5.0)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if intensity < 0.01 and target <= 0 then
			self.temporalAnchor = nil
		end
	end

	hole = descendingHole
	if hole and head then
		local dx = hole.x - head.drawX
		local dy = hole.y - head.drawY
		local dist = sqrt(dx * dx + dy * dy)
		if dist > 1e-4 then
			local nx, ny = dx / dist, dy / dist
			assignDirection(direction, nx, ny)
			assignDirection(pendingDir, nx, ny)
		end
	end

	-- adrenaline boost check
	if self.adrenaline and self.adrenaline.active then
		speed = speed * self.adrenaline.boost
		self.adrenaline.timer = self.adrenaline.timer - dt
		if self.adrenaline.timer <= 0 then
			self.adrenaline.active = false
			self.adrenaline.suppressVisuals = nil
		end
	end

	do
		local reference = self.baseSpeed or baselineSpeed
		if not (reference and reference > 1e-3) then
			reference = baselineSpeed
		end

		local ratio
		if reference and reference > 1e-3 then
			ratio = speed / reference
		else
			ratio = 1
		end
		if ratio < 0 then
			ratio = 0
		end

		local state = self.speedVisual or {intensity = 0, time = 0, ratio = 1}
		local target = max(0, min(1, (ratio - 1) / 0.8))
		local blend = min(1, dt * 5.5)
		local current = state.intensity or 0
		current = current + (target - current) * blend
		state.intensity = current
		state.target = target

		local ratioBlend = min(1, dt * 6.0)
		local prevRatio = state.ratio or ratio
		prevRatio = prevRatio + (ratio - prevRatio) * ratioBlend
		if prevRatio < 0 then prevRatio = 0 end
		state.ratio = prevRatio

		if self.zephyrCoils then
			self.zephyrCoils.speedRatio = prevRatio
		end

		local timeAdvance = 2.4 + prevRatio * 1.3 + target * 0.8
		state.time = (state.time or 0) + dt * timeAdvance

		if current > 0.01 or target > 0 then
			self.speedVisual = state
		else
			self.speedVisual = nil
		end
	end

        if self.swiftFangs then
                local state = self.swiftFangs
                state.time = (state.time or 0) + dt * (1.4 + min(1.8, (speed / max(1, self.baseSpeed or 1))))
                state.flash = max(0, (state.flash or 0) - dt * 1.8)

		local baseTarget = state.baseTarget or 0
		local baseSpeed = self.baseSpeed or 1
		if not baseSpeed or baseSpeed <= 0 then
			baseSpeed = 1
		end

		local ratio = speed / baseSpeed
		if ratio < 0 then ratio = 0 end
		state.speedRatio = ratio

		local bonus = max(0, ratio - 1)
		local dynamic = min(0.35, bonus * 0.4)
		local flashBonus = (state.flash or 0) * 0.35
		local target = min(1, max(0, baseTarget + dynamic + flashBonus))
		state.target = target

		local intensity = state.intensity or 0
		local blend = min(1, dt * 6.0)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		state.active = (target > baseTarget + 0.02) or (ratio > 15) or ((state.flash or 0) > 0.05)

		if (state.stacks or 0) <= 0 and target <= 0 and intensity < 0.02 then
                        self.swiftFangs = nil
                end
        end

        if self.momentumCoils then
                local state = self.momentumCoils
                local blend = min(1, dt * 2.8)
                local target = max(0, state.target or 0)
                local current = max(0, state.intensity or 0)

                current = current + (target - current) * blend
                state.intensity = current
                state.target = target
                state.time = (state.time or 0) + dt * (1.6 + current * 1.1)

                if current <= 0.01 and target <= 0 and (state.stacks or 0) <= 0 then
                        self.momentumCoils = nil
                end
        end

	local newX, newY
	local headCells = headCellBuffer
	local headCellCount = 0

	-- advance cell clock, maybe snap & commit queued direction
if hole then
moveProgress = 0
local stepX = direction[DIR_X] * speed * dt
local stepY = direction[DIR_Y] * speed * dt
newX = head.drawX + stepX
newY = head.drawY + stepY
else
local remaining = speed * dt
local currentDirX, currentDirY = direction[DIR_X], direction[DIR_Y]
		local currX, currY = head.drawX, head.drawY
		local snaps = 0
		local segmentLength = SEGMENT_SPACING

		while remaining > 0 do
			local available = segmentLength - moveProgress
			if available <= 0 then
				available = segmentLength
				moveProgress = 0
			end

			if remaining < available then
				currX = currX + currentDirX * remaining
				currY = currY + currentDirY * remaining
				moveProgress = moveProgress + remaining
				remaining = 0
			else
				currX = currX + currentDirX * available
				currY = currY + currentDirY * available
				remaining = remaining - available
				moveProgress = 0
				snaps = snaps + 1

				local snapCol, snapRow = toCell(currX, currY)
				if snapCol and snapRow then
					headCellCount = headCellCount + 1
					local cell = headCells[headCellCount]
					if cell then
						cell[1] = snapCol
						cell[2] = snapRow
						cell[3] = currX
						cell[4] = currY
					else
						headCells[headCellCount] = {snapCol, snapRow, currX, currY}
					end
				end

assignDirection(direction, pendingDir[DIR_X], pendingDir[DIR_Y])
currentDirX, currentDirY = direction[DIR_X], direction[DIR_Y]
end
end

		if snaps > 0 then
			SessionStats:add("tilesTravelled", snaps)
		end

		newX, newY = currX, currY
	end

	-- spatially uniform sampling along the motion path
	local dx = newX - head.drawX
	local dy = newY - head.drawY
	local dist = sqrt(dx * dx + dy * dy)

	local nx, ny = 0, 0
	if dist > 0 then
		nx, ny = dx / dist, dy / dist
	end

	local remaining = dist
	local prevX, prevY = head.drawX, head.drawY
	local buffer = newHeadSegments
	local bufferCount = 0

while remaining >= SAMPLE_STEP do
prevX = prevX + nx * SAMPLE_STEP
prevY = prevY + ny * SAMPLE_STEP
local segment = acquireSegment()
segment.drawX = prevX
segment.drawY = prevY
segment.dirX = direction[DIR_X]
segment.dirY = direction[DIR_Y]
                segment.fruitMarker = nil
                segment.fruitMarkerX = nil
                segment.fruitMarkerY = nil
                segment.fruitScore = nil
                segment.lengthToPrev = nil
                bufferCount = bufferCount + 1
                buffer[bufferCount] = segment
		remaining = remaining - SAMPLE_STEP
	end

	if bufferCount > 0 then
		local existingCount = #trail
		if existingCount > 0 then
			table.move(trail, 1, existingCount, bufferCount + 1)
		end

		if bufferCount > 1 then
			local half = floor(bufferCount * 0.5)
			for i = 1, half do
				local j = bufferCount - i + 1
				buffer[i], buffer[j] = buffer[j], buffer[i]
			end
		end

		table.move(buffer, 1, bufferCount, 1, trail)

		head = trail[1]
	end

	do
		local previousMax = newHeadSegmentsMax
                if bufferCount > previousMax then
                        newHeadSegmentsMax = bufferCount
                else
                        for i = bufferCount + 1, previousMax do
                                buffer[i] = nil
                        end
                        newHeadSegmentsMax = bufferCount
                end
                occupancyState.newHeadSegmentsMax = newHeadSegmentsMax
        end

	-- final correction: put true head at exact new position
	if trail[1] then
		trail[1].drawX = newX
		trail[1].drawY = newY
	end

	if bufferCount == 0 then
		recalcSegmentLengthsRange(1, min(#trail, 2))
	else
		recalcSegmentLengthsRange(1, min(#trail, bufferCount + 1))
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

	local tailAfterCol, tailAfterRow

	local consumedLength = (hole and hole.consumedLength) or 0
	local maxLen = max(0, segmentCount * SEGMENT_SPACING - consumedLength)

	applyTrailLengthLimit(maxLen, isGluttonsWakeActive())

	local lenAfterTrim = #trail
	do
		lenAfterTrim = #trail
		if lenAfterTrim >= 1 then
			local tailX, tailY = trail[lenAfterTrim].drawX, trail[lenAfterTrim].drawY
			if tailX and tailY then
				tailAfterCol, tailAfterRow = toCell(tailX, tailY)
			end
		end
	end

	local tailMoved = false
	if lenAfterTrim == 0 then
		tailMoved = true
	elseif tailBeforeCol and tailBeforeRow then
		if not tailAfterCol or not tailAfterRow then
			tailMoved = true
		else
			tailMoved = tailBeforeCol ~= tailAfterCol or tailBeforeRow ~= tailAfterRow
		end
	end

	if headCellCount > 0 or tailMoved then
		local overrideCol, overrideRow = nil, nil

                if headCellCount > 0 then
                        local latest = headCells[headCellCount]
                        if latest then
                                overrideCol = latest[1]
                                overrideRow = latest[2]
                        end
                else
                        overrideCol = occupancyState.headOccupancyCol
                        overrideRow = occupancyState.headOccupancyRow
                end

		if (not overrideCol) or (not overrideRow) then
			local headSeg = trail and trail[1]
			if headSeg then
				overrideCol, overrideRow = toCell(headSeg.drawX, headSeg.drawY)
			end
		end

		applySnakeOccupancyDelta(headCells, headCellCount, overrideCol, overrideRow, tailMoved, tailAfterCol, tailAfterRow)
	end

	-- collision with self (grid-cell based, only at snap ticks)
	if headCellCount > 0 and not self:isHazardGraceActive() then
		local hx, hy = trail[1].drawX, trail[1].drawY
		local lastCheckedCol, lastCheckedRow = nil, nil
		local segmentStartX = previousHeadX or hx
		local segmentStartY = previousHeadY or hy

		for i = 1, headCellCount do
			local cell = headCells[i]
			local headCol, headRow = cell and cell[1], cell and cell[2]
			local headSnapX, headSnapY = cell and cell[3], cell and cell[4]
			local targetX = headSnapX or hx
			local targetY = headSnapY or hy
			if headCol and headRow then
				if lastCheckedCol == headCol and lastCheckedRow == headRow then
					segmentStartX, segmentStartY = targetX, targetY
					goto continue
				end
				lastCheckedCol, lastCheckedRow = headCol, headRow

				local tailVacated = false
				if i == 1 and tailBeforeCol and tailBeforeRow then
					if tailBeforeCol == headCol and tailBeforeRow == headRow then
						if not (tailAfterCol == headCol and tailAfterRow == headRow) then
							tailVacated = true
						end
					end
				end

				if not tailVacated and isCellOccupiedBySnakeBody(headCol, headRow) then
					if wasRecentlyVacated(headCol, headRow) then
						segmentStartX, segmentStartY = targetX, targetY
						goto continue
					end
					local gridOccupied = SnakeUtils and SnakeUtils.isOccupied and SnakeUtils.isOccupied(headCol, headRow)
					if gridOccupied then
						if not isSelfCollisionAlongPath(segmentStartX, segmentStartY, targetX, targetY) then
							segmentStartX, segmentStartY = targetX, targetY
							goto continue
						end
						if self:consumeShield() then
							self:onShieldConsumed(hx, hy, "self")
							self:beginHazardGrace()
							segmentStartX, segmentStartY = targetX, targetY
							break
						else
local pushX = -(direction[DIR_X] or 0) * SEGMENT_SPACING
local pushY = -(direction[DIR_Y] or 0) * SEGMENT_SPACING
local context = {
pushX = pushX,
pushY = pushY,
dirX = -(direction[DIR_X] or 0),
dirY = -(direction[DIR_Y] or 0),
grace = HAZARD_GRACE_DURATION * 2,
shake = 0.28,
}
							return false, "self", context
						end
					end
				end
				segmentStartX, segmentStartY = targetX, targetY
				::continue::
			end
		end
	end

        if portalAnimation then
                local state = portalAnimation
                local duration = state.duration or 0.3
                if not duration or duration <= 1e-4 then
                        duration = 1e-4
                end
                state.duration = duration

                local completed = SnakeRender.updatePortalAnimation(state, dt)

                local totalLength = state.totalLength
                if not totalLength or totalLength <= 0 then
                        totalLength = computeTrailLength(state.entrySourceTrail)
                        if totalLength <= 0 then
                                totalLength = SEGMENT_SPACING
                        end
                        state.totalLength = totalLength
                end

                local entryLength = totalLength * (1 - (state.progress or 0))
                local exitLength = totalLength * (state.progress or 0)

                state.entryTrail = sliceTrailByLength(state.entrySourceTrail, entryLength, state.entryTrail)
                state.exitTrail = sliceTrailByLength(trail, exitLength, state.exitTrail)

                local entryHole = state.entryHole
                if entryHole then
                        entryHole.x = state.entryX
                        entryHole.y = state.entryY
                        entryHole.time = (entryHole.time or 0) + dt

                        local entryOpen = entryHole.open or 0
                        entryHole.closing = 1 - entryHole.visibility
                        local baseRadius = entryHole.baseRadius or (SEGMENT_SIZE * 0.7)
                        entryHole.radius = baseRadius * (0.55 + 0.65 * entryOpen)
                        entryHole.spin = (entryHole.spin or 0) + dt * (2.4 + 2.1 * entryOpen)
                        entryHole.pulse = (entryHole.pulse or 0) + dt
                end

                local exitHole = state.exitHole
                if exitHole then
                        exitHole.x = state.exitX
                        exitHole.y = state.exitY
                        exitHole.time = (exitHole.time or 0) + dt

                        local exitOpen = exitHole.open or 0
                        exitHole.closing = 1 - exitHole.visibility
                        local baseRadius = exitHole.baseRadius or (SEGMENT_SIZE * 0.75)
                        exitHole.radius = baseRadius * (0.5 + 0.6 * exitOpen)
                        exitHole.spin = (exitHole.spin or 0) + dt * (2.0 + 2.2 * exitOpen)
                        exitHole.pulse = (exitHole.pulse or 0) + dt
                end

                if completed then
                        clearPortalAnimation(state)
                        portalAnimation = nil
                end
        end

	-- update timers
	if popTimer > 0 then
		popTimer = max(0, popTimer - dt)
	end

	if self.shieldFlashTimer and self.shieldFlashTimer > 0 then
		self.shieldFlashTimer = max(0, self.shieldFlashTimer - dt)
	end

	if self.hazardGraceTimer and self.hazardGraceTimer > 0 then
		self.hazardGraceTimer = max(0, self.hazardGraceTimer - dt)
	end

	if self.damageFlashTimer and self.damageFlashTimer > 0 then
		self.damageFlashTimer = max(0, self.damageFlashTimer - dt)
	end

	if self.tailHitFlashTimer and self.tailHitFlashTimer > 0 then
		self.tailHitFlashTimer = max(0, self.tailHitFlashTimer - dt)
	end

	if severedPieces and #severedPieces > 0 then
		for index = #severedPieces, 1, -1 do
			local piece = severedPieces[index]
			if piece then
				piece.timer = (piece.timer or 0) - dt
				if piece.timer <= 0 then
					if piece.trail then
						recycleTrail(piece.trail)
						piece.trail = nil
					end
					remove(severedPieces, index)
				end
			end
		end
	end

	return true
end

function Snake:activateDash()
        return SnakeAbilities.activateDash(self)
end

function Snake:isDashActive()
        return SnakeAbilities.isDashActive(self)
end

function Snake:getDashState()
        return SnakeAbilities.getDashState(self)
end

function Snake:onDashBreakRock(x, y)
        return SnakeAbilities.onDashBreakRock(self, x, y)
end

function Snake:activateTimeDilation()
        return SnakeAbilities.activateTimeDilation(self)
end

function Snake:triggerChronoWard(duration, scale)
        return SnakeAbilities.triggerChronoWard(self, duration, scale)
end

function Snake:getTimeDilationState()
        return SnakeAbilities.getTimeDilationState(self)
end

function Snake:getTimeScale()
        return SnakeAbilities.getTimeScale(self)
end

function Snake:grow()
        local bonus = self.extraGrowth or 0
        segmentCount = segmentCount + 1 + bonus
        popTimer = POP_DURATION
end

local function computeFruitScoreLoss(segmentBuffer, amount)
        if not segmentBuffer or not amount or amount <= 0 then
                return 0
        end

        local remaining = amount
        local scoreLost = 0
        local index = #segmentBuffer

        while index >= 1 and remaining > 0 do
                local segment = segmentBuffer[index]
                if segment and segment.fruitMarker and segment.fruitScore then
                        scoreLost = scoreLost + segment.fruitScore
                end
                index = index - 1
                remaining = remaining - 1
        end

        return scoreLost
end

function Snake:loseSegments(count, options)
        count = floor(count or 0)
        if count <= 0 then
                return 0
        end

        local available = max(0, (segmentCount or 1) - 1)
        local trimmed = min(count, available)
        if trimmed <= 0 then
                return 0
        end

        local fruitScoreLost = computeFruitScoreLoss(trail, trimmed)

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
			UI.fruitCollected = max(0, (UI.fruitCollected or 0) - trimmed)
			if type(UI.fruitSockets) == "table" then
				for _ = 1, min(trimmed, #UI.fruitSockets) do
					remove(UI.fruitSockets)
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

        local apples = SessionStats:get("fruitEaten") or 0
        apples = max(0, apples - trimmed)
        SessionStats:set("fruitEaten", apples)

        if Score and Score.addBonus and Score.get then
                local currentScore = Score:get() or 0
                local deduction = min(currentScore, fruitScoreLost)
                if deduction > 0 then
                        Score:addBonus(-deduction)
                end
        end

	if (not options) or options.spawnParticles ~= false then
		local burstColor = LOSE_SEGMENTS_DEFAULT_BURST_COLOR
		if options and (options.cause == "saw" or options.cause == "laser" or options.cause == "dart") then
			burstColor = LOSE_SEGMENTS_SAW_BURST_COLOR
		end

		if Particles and Particles.spawnBurst and tailX and tailY then
			local burstOptions = LOSE_SEGMENTS_BURST_OPTIONS
			burstOptions.count = min(10, 4 + trimmed)
			burstOptions.color = burstColor
			Particles:spawnBurst(tailX, tailY, burstOptions)
		end
	end

	if trimmed > 0 then
		local remaining = self.tailHitFlashTimer or 0
		local refresh = max(remaining, TAIL_HIT_FLASH_DURATION)
		self.tailHitFlashTimer = refresh
	end

	return trimmed
end

local function chopTailLossAmount()
        local available = max(0, (segmentCount or 1) - 1)
        if available <= 0 then
                return 0
        end

        local loss = floor(max(1, available * 0.2))
        return min(loss, available)
end

function Snake:chopTailByHazard(cause)
        local loss = chopTailLossAmount()
        if loss <= 0 then
                return 0
        end

	local hazardCause = cause or "saw"
	local trimmed = self:loseSegments(loss, {cause = hazardCause})

	if trimmed > 0 then
		local tailSegment = trail[#trail]
		local chopX = tailSegment and tailSegment.drawX
		local chopY = tailSegment and tailSegment.drawY

		if Face then
			local shockDuration = 1.3
			local activeState = Face.state
			if activeState == "blink" then
				activeState = Face.savedState or activeState
			end

			if activeState == "shocked" then
				Face.timer = max(Face.timer or 0, shockDuration)
			elseif Face.override then
				Face:override("shocked", shockDuration)
			else
				Face:set("shocked", shockDuration)
			end
		end

		local Game = package.loaded["game"]
		if Game then
			if Game.triggerTailChopFeedback then
				Game:triggerTailChopFeedback(hazardCause, chopX, chopY)
			elseif Game.triggerTailChopShake then
				Game:triggerTailChopShake(hazardCause)
			elseif Game.triggerScreenShake then
				Game:triggerScreenShake(0.16)
			end
		end
	end

	return trimmed
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

        local tolerance = 1
        local nx, ny

        if saw.dir == "horizontal" then
                local minX = saw.trackMinX
                local maxX = saw.trackMaxX
                if minX and maxX then
                        local lateralTolerance = tolerance
                        if px < minX - lateralTolerance or px > maxX + lateralTolerance then
                                return false
                        end
                end

                -- Horizontal saws sit in the floor and only the top half (negative Y)
                -- should be able to slice the snake.
                nx, ny = 0, -1
        else
                local minY = saw.trackMinY
                local maxY = saw.trackMaxY
                if minY and maxY then
                        local lateralTolerance = tolerance
                        if py < minY - lateralTolerance or py > maxY + lateralTolerance then
                                return false
                        end
                end

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

local collisionHandlers = SnakeCollisions.new({
        SEGMENT_SPACING = SEGMENT_SPACING,
        SEGMENT_SIZE = SEGMENT_SIZE,
        collectSnakeSegmentCandidatesForRect = collectSnakeSegmentCandidatesForRect,
        collectSnakeSegmentCandidatesForCircle = collectSnakeSegmentCandidatesForCircle,
        segmentRectIntersection = segmentRectIntersection,
        closestPointOnSegment = closestPointOnSegment,
        isSawCutPointExposed = isSawCutPointExposed,
        getSawCenterPosition = getSawCenterPosition,
        isSawActive = isSawActive,
        Lasers = Lasers,
        Darts = Darts,
        Saws = Saws,
})

local function addSeveredTrail(pieceTrail, segmentEstimate)
	if not pieceTrail or #pieceTrail <= 1 then
		return
	end

	severedPieces = severedPieces or {}
	local fadeDuration = min(SEVERED_TAIL_LIFE, SEVERED_TAIL_FADE_DURATION)
	insert(severedPieces, {
		trail = pieceTrail,
		timer = SEVERED_TAIL_LIFE,
		life = SEVERED_TAIL_LIFE,
		fadeDuration = fadeDuration,
		segmentCount = max(1, segmentEstimate or #pieceTrail),
		}
	)
end

local function spawnSawCutParticles(x, y, count)
	if not (Particles and Particles.spawnBurst and x and y) then
		return
	end

	Particles:spawnBurst(x, y, {
		count = min(12, 5 + (count or 0)),
		speed = 1,
		speedVariance = 60,
		life = 0.42,
		size = 4,
		color = {1, 0.6, 0.3, 1},
		spread = pi * 2,
		drag = 3.0,
		gravity = 220,
		fadeTo = 0,
		}
	)
end

function Snake:handleSawBodyCut(context)
	if not context then
		return false
	end

	local cause = context.cause or "saw"

	local available = max(0, (segmentCount or 1) - 1)
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
	local cutDistance = max(0, context.cutDistance or 0)
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
				tailDistance = tailDistance + sqrt(ddx * ddx + ddy * ddy)
				prevCutX, prevCutY = sx, sy
			end
		end
	end

	local rawSegments = tailDistance / SEGMENT_SPACING
	local lostSegments = max(1, floor(rawSegments + 0.25))
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
        newTail.fruitScore = nil

	local severedTrail = {}
	severedTrail[1] = copySegmentData(newTail)

	for i = index, #trail do
		local segCopy = copySegmentData(trail[i])
		if segCopy then
			severedTrail[#severedTrail + 1] = segCopy
		end
	end

	for i = #trail, previousIndex + 1, -1 do
		local removed = trail[i]
		trail[i] = nil
		if removed then
			local lenToPrev = removed.lengthToPrev or 0
			if lenToPrev ~= 0 then
				trailLength = trailLength - lenToPrev
			end
			releaseSegment(removed)
		end
	end

	newTail.lengthToPrev = nil
	trail[#trail + 1] = newTail
	updateSegmentLengthAt(#trail)

	addSeveredTrail(severedTrail, lostSegments + 1)
	spawnSawCutParticles(cutX, cutY, lostSegments)

	self:loseSegments(lostSegments, {cause = cause, trimTrail = false})

	return true
end

function Snake:checkLaserBodyCollision()
	return collisionHandlers.checkLaserBodyCollision(self, {
		isDead = isDead,
		trail = trail,
	})
end

function Snake:checkDartBodyCollision()
	return collisionHandlers.checkDartBodyCollision(self, {
		isDead = isDead,
		trail = trail,
	})
end

function Snake:checkSawBodyCollision()
	return collisionHandlers.checkSawBodyCollision(self, {
		isDead = isDead,
		trail = trail,
	})
end

function Snake:markFruitSegment(fruitX, fruitY, fruitScore)
        if not trail or #trail == 0 then
                return
        end

	local targetIndex = 1

	if fruitX and fruitY then
		local bestDistSq = huge
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
                segment.fruitScore = fruitScore
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
        SnakeRender.draw(renderState, {
                snake = self,
                trail = trail,
                segmentCount = segmentCount,
                segmentSize = SEGMENT_SIZE,
                popTimer = popTimer,
                descendingHole = descendingHole,
                portalAnimation = portalAnimation,
                tailHitFlashTimer = self.tailHitFlashTimer,
                tailHitFlashDuration = TAIL_HIT_FLASH_DURATION,
                tailHitFlashColor = TAIL_HIT_FLASH_COLOR,
                severedPieces = severedPieces,
                severedLife = SEVERED_TAIL_LIFE,
                severedFadeDuration = SEVERED_TAIL_FADE_DURATION,
                shields = self.shields,
                shieldFlashTimer = self.shieldFlashTimer,
                isDead = isDead,
                collectUpgradeVisuals = collectUpgradeVisuals,
        })
end

function Snake:resetPosition()
	self:load(screenW, screenH)
end

-- Returns a reusable snapshot of the snake trail. Callers must treat the
-- returned data as read-only until the next frame.
function Snake:getSegments()
	local snapshot = segmentSnapshot
	local previousCount = #snapshot
	local count = #trail

	for i = 1, count do
		local seg = trail[i]
		local entry = snapshot[i]
		if not entry then
			if segmentSnapshotPoolCount > 0 then
				entry = segmentSnapshotPool[segmentSnapshotPoolCount]
				segmentSnapshotPool[segmentSnapshotPoolCount] = nil
				segmentSnapshotPoolCount = segmentSnapshotPoolCount - 1
			else
				entry = {}
			end
			snapshot[i] = entry
		end

		entry[SEGMENT_SNAPSHOT_DRAW_X] = seg.drawX
		entry[SEGMENT_SNAPSHOT_DRAW_Y] = seg.drawY
		entry[SEGMENT_SNAPSHOT_DIR_X] = seg.dirX
		entry[SEGMENT_SNAPSHOT_DIR_Y] = seg.dirY
	end

	for i = count + 1, previousCount do
		local entry = snapshot[i]
		if entry then
			entry[SEGMENT_SNAPSHOT_DRAW_X] = nil
			entry[SEGMENT_SNAPSHOT_DRAW_Y] = nil
			entry[SEGMENT_SNAPSHOT_DIR_X] = nil
			entry[SEGMENT_SNAPSHOT_DIR_Y] = nil
			segmentSnapshotPoolCount = segmentSnapshotPoolCount + 1
			segmentSnapshotPool[segmentSnapshotPoolCount] = entry
			snapshot[i] = nil
		end
	end

	return snapshot
end

function Snake:getTail()
	local tail = trail[#trail]
	if not tail then
		return nil, nil, nil
	end

	return tail.drawX, tail.drawY, tail
end

return Snake
