local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Particles = require("particles")
local Theme = require("theme")
local RenderLayers = require("renderlayers")
local Easing = require("easing")

local max = math.max
local min = math.min
local pi = math.pi
local cos = math.cos
local sin = math.sin
local insert = table.insert

local Saws = {}
local current = {}
local slots = {}
local nextSlotId = 0

local SAW_RADIUS = 24
local COLLISION_RADIUS_MULT = 0.7 -- keep the visual size but ease up on collision tightness
local SAW_TEETH = 12
local HUB_HOLE_RADIUS = 4
local HUB_HIGHLIGHT_PADDING = 3
local TRACK_LENGTH = 120 -- how far the saw moves on its track
local MOVE_SPEED = 60    -- units per second along the track
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SINK_OFFSET = 2
local SINK_DISTANCE = 28
local SINK_SPEED = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}
local SHADOW_OFFSET = 3
local SHADOW_ALPHA = 0.35
local STENCIL_EXTENT = 999

local sawStencilState = {
	dir = nil,
	side = nil,
	x = 0,
	y = 0,
	radius = 0,
	sinkOffset = SINK_OFFSET,
}

local function drawSawStencil()
	if sawStencilState.dir == "horizontal" then
		love.graphics.rectangle(
		"fill",
		sawStencilState.x - TRACK_LENGTH / 2 - sawStencilState.radius,
		sawStencilState.y - STENCIL_EXTENT + sawStencilState.sinkOffset,
		TRACK_LENGTH + sawStencilState.radius * 2,
		STENCIL_EXTENT
		)
		return
	end

	local height = TRACK_LENGTH + sawStencilState.radius * 2
	local top = sawStencilState.y - TRACK_LENGTH / 2 - sawStencilState.radius
	if sawStencilState.side == "left" then
		love.graphics.rectangle("fill", sawStencilState.x, top, STENCIL_EXTENT, height)
	elseif sawStencilState.side == "right" then
		love.graphics.rectangle("fill", sawStencilState.x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
	else
		love.graphics.rectangle("fill", sawStencilState.x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
	end
end

local function copyColor(color)
	if not color then
		return {1, 1, 1, 1}
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
	}
end

local highlightCache = setmetatable({}, { __mode = "k" })
local highlightDefault = {1, 1, 1, 1}

local emptyPoints = {}

local function updateHighlightColor(out, color)
	local r = min(1, color[1] * 1.2 + 0.08)
	local g = min(1, color[2] * 1.2 + 0.08)
	local b = min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.7
	out[1], out[2], out[3], out[4] = r, g, b, a
	return out
end

local function getHighlightColor(color)
	color = color or highlightDefault
	local cached = highlightCache[color]
	if not cached then
		cached = {0, 0, 0, 0}
		highlightCache[color] = cached
	end
	return updateHighlightColor(cached, color)
end

local function invalidateSawPointCache(saw)
	if not saw then
		return
	end

	local cache = saw._pointCache
	if cache then
		cache.radius = nil
		cache.teeth = nil
	end
end

local function getSawPoints(saw)
	if not saw then
		return emptyPoints
	end

	local radius = saw.radius or SAW_RADIUS
	local teeth = saw.teeth or 8
	local cache = saw._pointCache

	if cache and cache.radius == radius and cache.teeth == teeth and cache.points then
		return cache.points
	end

	cache = cache or {}
	local points = cache.points

	if points then
		for i = #points, 1, -1 do
			points[i] = nil
		end
	else
		points = {}
		cache.points = points
	end

	local inner = radius * 0.8
	local step = pi / max(1, teeth)

	for i = 0, (teeth * 2) - 1 do
		local r = (i % 2 == 0) and radius or inner
		local angle = i * step
		points[#points + 1] = cos(angle) * r
		points[#points + 1] = sin(angle) * r
	end

	cache.radius = radius
	cache.teeth = teeth
	saw._pointCache = cache

	return points
end

-- modifiers
Saws.speedMult = 1.0
Saws.spinMult = 1.0
Saws.stallOnFruit = 0

local stallTimer = 0
local sinkTimer = 0
local sinkAutoRaise = false
local sinkActive = false

local function getTileSize()
	return Arena and Arena.tileSize or SnakeUtils.SEGMENT_SIZE or 24
end

local function clampRow(row)
	if not Arena or (Arena.rows or 0) <= 0 then
		return row
	end

	return max(1, min(Arena.rows, row))
end

local function clampCol(col)
	if not Arena or (Arena.cols or 0) <= 0 then
		return col
	end

	return max(1, min(Arena.cols, col))
end

local function addCell(target, seen, col, row)
	if not (col and row) then
		return
	end

	col = clampCol(col)
	row = clampRow(row)

	local key = tostring(col) .. ":" .. tostring(row)
	if seen[key] then
		return
	end

	seen[key] = true
	target[#target + 1] = {col, row}
end

local function clearTrackBounds(target)
	if not target then
		return
	end

	target.trackMinX = nil
	target.trackMaxX = nil
	target.trackMinY = nil
	target.trackMaxY = nil
end

local function buildCollisionCellsForSaw(saw)
	if not saw then
		return nil
	end

	local trackCells = SnakeUtils.getSawTrackCells(saw.x, saw.y, saw.dir) or {}
	if #trackCells == 0 then
		clearTrackBounds(saw)
		return nil
	end

	local cells = {}
	local seen = {}
	local trackMinX
	local trackMaxX
	local trackMinY
	local trackMaxY

	if Arena and Arena.getTilePosition then
		local tileSize = getTileSize()

		for _, cell in ipairs(trackCells) do
			local col, row = cell[1], cell[2]
			local cellX, cellY = Arena:getTilePosition(col, row)
			if cellX and cellY then
				local right = cellX + tileSize
				local bottom = cellY + tileSize
				trackMinX = (trackMinX and min(trackMinX, cellX)) or cellX
				trackMaxX = (trackMaxX and max(trackMaxX, right)) or right
				trackMinY = (trackMinY and min(trackMinY, cellY)) or cellY
				trackMaxY = (trackMaxY and max(trackMaxY, bottom)) or bottom
			end
		end
	else
		clearTrackBounds(saw)
	end

	-- Limit collision coverage to the track cell and the adjacent cell the blade
	-- actually occupies so the hazard doesn't spill into neighboring tiles.
	if saw.dir == "horizontal" then
		for _, cell in ipairs(trackCells) do
			local col, row = cell[1], cell[2]
			addCell(cells, seen, col, row)
			addCell(cells, seen, col, row + 1)
		end
	else
		local offsetDir

		if saw.side == "left" then
			offsetDir = 1
		elseif saw.side == "right" then
			offsetDir = -1
		else
			offsetDir = 1
		end

		for _, cell in ipairs(trackCells) do
			local col, row = cell[1], cell[2]
			addCell(cells, seen, col, row)
			addCell(cells, seen, col + offsetDir, row)
		end
	end

	if Arena and Arena.getTilePosition then
		local tileSize = getTileSize()

		for _, cell in ipairs(cells) do
			local col, row = cell[1], cell[2]
			local cellX, cellY = Arena:getTilePosition(col, row)
			if cellX and cellY then
				local right = cellX + tileSize
				local bottom = cellY + tileSize
				cell.minX = cellX
				cell.maxX = right
				cell.minY = cellY
				cell.maxY = bottom
			else
				cell.minX = nil
				cell.maxX = nil
				cell.minY = nil
				cell.maxY = nil
			end
		end
	else
		for _, cell in ipairs(cells) do
			cell.minX = nil
			cell.maxX = nil
			cell.minY = nil
			cell.maxY = nil
		end
	end

	if trackMinX and trackMaxX and trackMinY and trackMaxY then
		saw.trackMinX = trackMinX
		saw.trackMaxX = trackMaxX
		saw.trackMinY = trackMinY
		saw.trackMaxY = trackMaxY
	else
		clearTrackBounds(saw)
	end

	return cells
end

local function overlapsCollisionCell(saw, x, y, w, h)
	local cells = saw and saw.collisionCells
	if not (cells and #cells > 0) then
		return true
	end

	local tileSizeCache

	for _, cell in ipairs(cells) do
		local minX = cell.minX
		local maxX = cell.maxX
		local minY = cell.minY
		local maxY = cell.maxY

		if minX and maxX and minY and maxY then
			if x < maxX and x + w > minX and y < maxY and y + h > minY then
				return true
			end
		elseif Arena and Arena.getTilePosition then
			tileSizeCache = tileSizeCache or getTileSize()
			local col, row = cell[1], cell[2]
			local cellX, cellY = Arena:getTilePosition(col, row)
			if cellX and cellY then
				local right = cellX + tileSizeCache
				local bottom = cellY + tileSizeCache
				cell.minX = cellX
				cell.maxX = right
				cell.minY = cellY
				cell.maxY = bottom

				if x < right and x + w > cellX and y < bottom and y + h > cellY then
					return true
				end
			else
				cell.minX = nil
				cell.maxX = nil
				cell.minY = nil
				cell.maxY = nil
			end
		else
			return true
		end
	end

	return false
end

local function isCollisionCandidate(saw, x, y, w, h)
	if not (saw and x and y and w and h) then
		return false
	end

	if (saw.sinkProgress or 0) > 0 or (saw.sinkTarget or 0) > 0 then
		return false
	end

	local trackMinX = saw.trackMinX
	local trackMaxX = saw.trackMaxX
	local trackMinY = saw.trackMinY
	local trackMaxY = saw.trackMaxY

	if trackMinX and trackMaxX and trackMinY and trackMaxY then
		local padding = SINK_OFFSET + SINK_DISTANCE
		local queryMinX = x
		local queryMaxX = x + w
		local queryMinY = y
		local queryMaxY = y + h
		local paddedMinX = trackMinX - padding
		local paddedMaxX = trackMaxX + padding
		local paddedMinY = trackMinY - padding
		local paddedMaxY = trackMaxY + padding

		if queryMaxX < paddedMinX or queryMinX > paddedMaxX or queryMaxY < paddedMinY or queryMinY > paddedMaxY then
			return false
		end
	end

	return overlapsCollisionCell(saw, x, y, w, h)
end

local function updateSlotSlide(slot, dt)
	local duration = slot and slot.tremorSlideDuration
	if not (duration and duration > 0) then
		return
	end

	local timer = math.min((slot.tremorSlideTimer or 0) + (dt or 0), duration)
	slot.tremorSlideTimer = timer

	local progress = Easing.easeOutCubic(Easing.clamp01(duration <= 0 and 1 or timer / duration))
	local startX = slot.tremorSlideStartX or slot.x
	local startY = slot.tremorSlideStartY or slot.y
	local targetX = slot.tremorSlideTargetX or slot.x
	local targetY = slot.tremorSlideTargetY or slot.y

	slot.renderX = Easing.lerp(startX, targetX, progress)
	slot.renderY = Easing.lerp(startY, targetY, progress)

	if timer >= duration then
		slot.tremorSlideTimer = nil
		slot.tremorSlideDuration = nil
		slot.tremorSlideStartX = nil
		slot.tremorSlideStartY = nil
		slot.tremorSlideTargetX = nil
		slot.tremorSlideTargetY = nil
		slot.renderX = nil
		slot.renderY = nil
	end
end

local function updateSawSlide(saw, dt)
	local duration = saw and saw.tremorSlideDuration
	if not (duration and duration > 0) then
		return false
	end

	local timer = math.min((saw.tremorSlideTimer or 0) + (dt or 0), duration)
	saw.tremorSlideTimer = timer

	local progress = Easing.easeOutCubic(Easing.clamp01(duration <= 0 and 1 or timer / duration))
	local startX = saw.tremorSlideStartX or saw.x
	local startY = saw.tremorSlideStartY or saw.y
	local targetX = saw.tremorSlideTargetX or saw.x
	local targetY = saw.tremorSlideTargetY or saw.y

	saw.renderX = Easing.lerp(startX, targetX, progress)
	saw.renderY = Easing.lerp(startY, targetY, progress)

	if timer >= duration then
		saw.tremorSlideTimer = nil
		saw.tremorSlideDuration = nil
		saw.tremorSlideStartX = nil
		saw.tremorSlideStartY = nil
		saw.tremorSlideTargetX = nil
		saw.tremorSlideTargetY = nil
		saw.renderX = nil
		saw.renderY = nil
	end

	return true
end

local function updateSawProgressNudge(saw, dt)
	local duration = saw and saw.tremorNudgeDuration
	if not (duration and duration > 0) then
		return false
	end

	local timer = math.min((saw.tremorNudgeTimer or 0) + (dt or 0), duration)
	saw.tremorNudgeTimer = timer

	local startProgress = saw.tremorNudgeStart
	if startProgress == nil then
		startProgress = saw.progress or 0
	end
	local targetProgress = saw.tremorNudgeTarget or startProgress
	local progress = Easing.easeOutCubic(Easing.clamp01(duration <= 0 and 1 or timer / duration))
	saw.progress = startProgress + (targetProgress - startProgress) * progress

	if timer >= duration then
		saw.progress = targetProgress
		saw.tremorNudgeTimer = nil
		saw.tremorNudgeDuration = nil
		saw.tremorNudgeStart = nil
		saw.tremorNudgeTarget = nil
	end

	return true
end

local function getMoveSpeed()
	return MOVE_SPEED * (Saws.speedMult or 1)
end

local function getOrCreateSlot(x, y, dir)
	dir = dir or "horizontal"

	for _, slot in ipairs(slots) do
		if slot.x == x and slot.y == y and slot.dir == dir then
			return slot
		end
	end

	nextSlotId = nextSlotId + 1
	local slot = {
		id = nextSlotId,
		x = x,
		y = y,
		dir = dir,
	}

	insert(slots, slot)
	return slot
end

local function getSlotById(id)
	if not id then
		return nil
	end

	for _, slot in ipairs(slots) do
		if slot.id == id then
			return slot
		end
	end

	return nil
end

local function getSawAnchor(saw)
	if not saw then
		return nil, nil
	end

	local anchorX = saw.renderX or saw.x
	local anchorY = saw.renderY or saw.y
	return anchorX, anchorY
end

local function getSawCenterForProgress(saw, progress)
	if not saw then
		return nil, nil
	end

	local anchorX, anchorY = getSawAnchor(saw)
	if not (anchorX and anchorY) then
		return anchorX, anchorY
	end

	local radius = saw.radius or SAW_RADIUS
	local clamped = max(0, min(1, progress or 0))

	if saw.dir == "horizontal" then
		local minX
		local maxX
		local trackMinX = saw.trackMinX
		local trackMaxX = saw.trackMaxX

		if trackMinX and trackMaxX then
			local tileSize = getTileSize()
			local halfStep = (tileSize or 0) * 0.5
			if halfStep <= 0 then
				halfStep = radius
			end

			minX = trackMinX + halfStep
			maxX = trackMaxX - halfStep

			if minX > maxX then
				minX = anchorX - TRACK_LENGTH/2 + radius
				maxX = anchorX + TRACK_LENGTH/2 - radius
			end
		else
			minX = anchorX - TRACK_LENGTH/2 + radius
			maxX = anchorX + TRACK_LENGTH/2 - radius
		end

		local px = minX + (maxX - minX) * clamped
		return px, anchorY
	end

	local minY
	local maxY
	local trackMinY = saw.trackMinY
	local trackMaxY = saw.trackMaxY

	if trackMinY and trackMaxY then
		local tileSize = getTileSize()
		local halfStep = (tileSize or 0) * 0.5
		if halfStep <= 0 then
			halfStep = radius
		end

		minY = trackMinY + halfStep
		maxY = trackMaxY - halfStep

		if minY > maxY then
			minY = anchorY - TRACK_LENGTH/2 + radius
			maxY = anchorY + TRACK_LENGTH/2 - radius
		end
	else
		minY = anchorY - TRACK_LENGTH/2 + radius
		maxY = anchorY + TRACK_LENGTH/2 - radius
	end

	local py = minY + (maxY - minY) * clamped

	return anchorX, py
end

local function getSawCenter(saw)
	return getSawCenterForProgress(saw, saw and saw.progress)
end

local function getVerticalSinkDirection(saw)
	if not saw then
		return 1
	end

	if saw.side == "left" then
		return -1
	elseif saw.side == "right" then
		return 1
	end

	return 1
end

local function getSawCollisionCenter(saw)
	local px, py = getSawCenter(saw)
	if not (px and py) then
		return px, py
	end

	local sinkProgress = saw.sinkVisualProgress or saw.sinkProgress or 0
	local sinkOffset = SINK_OFFSET + sinkProgress * SINK_DISTANCE
	if saw.dir == "horizontal" then
		py = py + sinkOffset
	else
		local sinkDir = getVerticalSinkDirection(saw)
		px = px + sinkDir * sinkOffset
	end

	return px, py
end

local function removeSaw(target)
	if not target then
		return
	end

	for index, saw in ipairs(current) do
		if saw == target or index == target then
			local anchorX = saw.renderX or saw.x
			local anchorY = saw.renderY or saw.y
			local px, py = getSawCenter(saw)
			local sawColor = Theme.sawColor or {0.85, 0.8, 0.75, 1}
			local primary = copyColor(sawColor)
			primary[4] = 1
			local highlight = getHighlightColor(sawColor)

			Particles:spawnBurst(px or anchorX, py or anchorY, {
				count = 12,
				speed = 82,
				speedVariance = 68,
				life = 0.35,
				size = 2.3,
				color = {primary[1], primary[2], primary[3], primary[4]},
				spread = pi * 2,
				angleJitter = pi,
				drag = 3.5,
				gravity = 260,
				scaleMin = 0.45,
				scaleVariance = 0.5,
				fadeTo = 0.04,
			})

			Particles:spawnBurst(px or anchorX, py or anchorY, {
				count = love.math.random(4, 6),
				speed = 132,
				speedVariance = 72,
				life = 0.26,
				size = 1.8,
				color = {1.0, 0.94, 0.52, highlight[4] or 1},
				spread = pi * 2,
				angleJitter = pi,
				drag = 1.4,
				gravity = 200,
				scaleMin = 0.34,
				scaleVariance = 0.28,
				fadeTo = 0.02,
			})

			table.remove(current, index)
			break
		end
	end
end

-- Easing similar to Rocks
-- Spawn a saw on a track
function Saws:spawn(x, y, radius, teeth, dir, side, options)
	local slot = getOrCreateSlot(x, y, dir)

	insert(current, {
		x = x,
		y = y,
		radius = radius or SAW_RADIUS,
		collisionRadius = (radius or SAW_RADIUS) * COLLISION_RADIUS_MULT,
		teeth = teeth or SAW_TEETH,
		rotation = 0,
		timer = 0,
		phase = "drop",
		scaleX = 1,
		scaleY = 0,
		offsetY = -40,

		-- movement
		dir = dir or "horizontal",
		side = side,
		progress = 0,
		direction = 1,
		slotId = slot and slot.id or nil,

		sinkProgress = sinkActive and 1 or 0,
		sinkTarget = sinkActive and 1 or 0,
		sinkVisualProgress = Easing.easeInOutCubic(sinkActive and 1 or 0),
		collisionCells = nil,
		hitFlashTimer = 0,
	})

	local saw = current[#current]
	invalidateSawPointCache(saw)
	saw.collisionCells = buildCollisionCellsForSaw(saw)
	options = options or {}
	saw.color = options.color or saw.color
	saw.gilded = options.gilded or false
	saw.ember = options.ember or false
	saw.emberTrailColor = options.emberTrailColor
	saw.emberGlowColor = options.emberGlowColor
	if saw.ember then
		saw.emberTrailPhase = love.math.random()
	else
		saw.emberTrailPhase = nil
	end
end

function Saws:getAll()
	return current
end

function Saws:getCollisionCenter(saw)
	return getSawCollisionCenter(saw)
end

function Saws:reset()
	current = {}
	slots = {}
	nextSlotId = 0
	self.speedMult = 1.0
	self.spinMult = 1.0
	self.stallOnFruit = 0
	stallTimer = 0
	sinkTimer = 0
	sinkAutoRaise = false
	sinkActive = false
end

function Saws:destroy(target)
	removeSaw(target)
end

function Saws:update(dt)
	if stallTimer > 0 then
		stallTimer = max(0, stallTimer - dt)
	end

	if sinkAutoRaise and sinkTimer > 0 then
		sinkTimer = max(0, sinkTimer - dt)
		if sinkTimer <= 0 then
			self:unsink()
		end
	end

	for _, slot in ipairs(slots) do
		updateSlotSlide(slot, dt)
	end

	for _, saw in ipairs(current) do
		if not saw.collisionCells then
			saw.collisionCells = buildCollisionCellsForSaw(saw)
		end

		saw.collisionRadius = (saw.radius or SAW_RADIUS) * COLLISION_RADIUS_MULT

		if saw._pointCache then
			local cache = saw._pointCache
			local radius = saw.radius or SAW_RADIUS
			local teeth = saw.teeth or 8
			if cache.radius and (cache.radius ~= radius or cache.teeth ~= teeth) then
				invalidateSawPointCache(saw)
			end
		end

		saw.timer = saw.timer + dt
		saw.rotation = (saw.rotation + dt * 5 * (self.spinMult or 1)) % (pi * 2)

		updateSawSlide(saw, dt)

		local sinkDirection = (saw.sinkTarget or 0) > 0 and 1 or -1
		saw.sinkProgress = (saw.sinkProgress or 0) + sinkDirection * dt * SINK_SPEED
		if saw.sinkProgress < 0 then
			saw.sinkProgress = 0
		elseif saw.sinkProgress > 1 then
			saw.sinkProgress = 1
		end

		saw.sinkVisualProgress = Easing.easeInOutCubic(saw.sinkProgress)

		saw.hitFlashTimer = max(0, (saw.hitFlashTimer or 0) - dt)

		if saw.phase == "drop" then
			local progress = min(saw.timer / SPAWN_DURATION, 1)
			saw.offsetY = -40 * (1 - progress)
			saw.scaleY = progress
			saw.scaleX = progress

			if progress >= 1 then
				saw.phase = "squash"
				saw.timer = 0
			end

		elseif saw.phase == "squash" then
			local progress = min(saw.timer / SQUASH_DURATION, 1)
			saw.scaleX = 1 + 0.3 * (1 - progress)
			saw.scaleY = 1 - 0.3 * (1 - progress)
			saw.offsetY = 0

			if progress >= 1 then
				saw.phase = "done"
				saw.scaleX = 1
				saw.scaleY = 1
				saw.offsetY = 0
			end
		elseif saw.phase == "done" then
			local nudging = updateSawProgressNudge(saw, dt)

			if not nudging and stallTimer <= 0 then
				-- Move along the track
				local delta = (getMoveSpeed() * dt) / TRACK_LENGTH
				saw.progress = saw.progress + delta * saw.direction

				if saw.progress > 1 then
					saw.progress = 1
					saw.direction = -1
				elseif saw.progress < 0 then
					saw.progress = 0
					saw.direction = 1
				end
			end
		end

		if saw.ember then
			saw.emberTrailPhase = (saw.emberTrailPhase or 0) + dt
		end
	end
end

function Saws:draw()
	if #slots > 0 then
		love.graphics.setColor(0, 0, 0, 1)
		for _, slot in ipairs(slots) do
			local slotX = slot.renderX or slot.x
			local slotY = slot.renderY or slot.y
			if slot.dir == "horizontal" then
				love.graphics.rectangle("fill", slotX - TRACK_LENGTH/2, slotY - 5, TRACK_LENGTH, 10, 6, 6)
			else
				love.graphics.rectangle("fill", slotX - 5, slotY - TRACK_LENGTH/2, 10, TRACK_LENGTH, 6, 6)
			end
		end
	end

	for _, saw in ipairs(current) do
		local anchorX = saw.renderX or saw.x
		local anchorY = saw.renderY or saw.y
		local px, py = getSawCenter(saw)
		local sinkProgress = max(0, min(1, saw.sinkProgress or 0))
		local sinkVisualProgress = max(0, min(1, saw.sinkVisualProgress or sinkProgress))
		local sinkOffset = sinkVisualProgress * SINK_DISTANCE
		local occlusionDepth = SINK_OFFSET + sinkOffset
		local offsetX, offsetY = 0, 0
		local sinkDir = 1

		if saw.dir == "horizontal" then
			offsetY = occlusionDepth
		else
			sinkDir = getVerticalSinkDirection(saw)
			offsetX = sinkDir * occlusionDepth
		end

		local sinkScale = 1 - 0.1 * sinkVisualProgress
		local rotation = saw.rotation or 0
		local outer = saw.radius or SAW_RADIUS
		local points = getSawPoints(saw)

		local isBladeHidden = sinkVisualProgress >= 0.999
		if (saw.scaleX ~= nil and saw.scaleX <= 0) or (saw.scaleY ~= nil and saw.scaleY <= 0) then
			isBladeHidden = true
		end
		if not isBladeHidden and #points >= 6 then
			RenderLayers:withLayer("shadows", function()
				love.graphics.push()

				local shadowBaseX = (px or anchorX)
				local shadowBaseY = (py or anchorY)
				local shadowSinkOffset = offsetY
				local applyShadowClip = false

				if saw.dir == "horizontal" then
					-- When the saw sinks into the track, the shadow should shrink upwards
					-- instead of following the blade down. Move the base upward based on the
					-- sink progress so the clipped result visually tightens towards the slot.
					shadowSinkOffset = SINK_OFFSET - sinkOffset
					local trackTop = anchorY - 5
					local trackWidth = TRACK_LENGTH + outer * 2

					love.graphics.stencil(function()
						love.graphics.rectangle(
						"fill",
						anchorX - TRACK_LENGTH / 2 - outer,
						trackTop,
						trackWidth,
						STENCIL_EXTENT
						)
					end, "replace", 1)
					love.graphics.setStencilTest("equal", 1)
					applyShadowClip = true
				else
					if offsetX > 0 then
						shadowBaseX = shadowBaseX + offsetX
					end
				end

				if shadowSinkOffset and shadowSinkOffset ~= 0 then
					shadowBaseY = shadowBaseY + shadowSinkOffset
				end

				local shadowOffsetX = SHADOW_OFFSET
				local shadowOffsetY = SHADOW_OFFSET

				love.graphics.translate(shadowBaseX + shadowOffsetX, shadowBaseY + shadowOffsetY)
				love.graphics.rotate(rotation)
				love.graphics.scale(sinkScale, sinkScale)

				local alpha = SHADOW_ALPHA * (1 - 0.4 * sinkVisualProgress)
				love.graphics.setColor(0, 0, 0, alpha)
				love.graphics.polygon("fill", points)

				if applyShadowClip then
					love.graphics.setStencilTest()
				end

				love.graphics.pop()
			end)
		end

		-- Stencil: clip saw into the track (adjust direction for left/right mounted saws)
		sawStencilState.dir = saw.dir
		sawStencilState.side = saw.side
		sawStencilState.x = anchorX
		sawStencilState.y = anchorY
		sawStencilState.radius = saw.radius or SAW_RADIUS
		sawStencilState.sinkOffset = SINK_OFFSET
		love.graphics.stencil(drawSawStencil, "replace", 1)

		love.graphics.setStencilTest("equal", 1)

		-- Saw blade
		love.graphics.push()
		love.graphics.translate((px or anchorX) + offsetX, (py or anchorY) + offsetY)

		-- apply spinning rotation
		love.graphics.rotate(rotation)

		love.graphics.scale(sinkScale, sinkScale)

		-- Fill
		local baseColor = saw.color or Theme.sawColor or {0.8, 0.8, 0.8, 1}
		if saw.hitFlashTimer and saw.hitFlashTimer > 0 then
			baseColor = HIT_FLASH_COLOR
		end

		love.graphics.setColor(baseColor)
		love.graphics.polygon("fill", points)

		-- Determine how the hub highlight should appear. When the saw is mounted
		-- in a wall (vertical with an explicit side) the hub sits mostly inside
		-- the track. The stencil clips part of the hub which previously removed
		-- the highlight entirely. Keep rendering it, but fade the highlight based
		-- on how deep the hub is occluded so it matches the horizontal saws while
		-- avoiding a harsh seam at the edge of the track.
		local highlightRadius = HUB_HOLE_RADIUS + HUB_HIGHLIGHT_PADDING - 1
		local hideHubHighlight = false
		local highlightAlphaMult = 1

		if saw.dir == "vertical" and (saw.side == "left" or saw.side == "right") then
			-- Wall-mounted vertical saws rest partially inside their track. The
			-- hub highlight would normally be clipped by the stencil which makes
			-- the center disappear entirely. Keep drawing it, but fade the effect
			-- based on how deep the hub is occluded so the exposed portion still
			-- reads well without leaving a harsh seam.
			if occlusionDepth <= 0 then
				hideHubHighlight = true
			else
				local occlusionRatio = min(1, max(0, occlusionDepth / highlightRadius))
				highlightAlphaMult = 0.4 + 0.6 * occlusionRatio
			end
		elseif occlusionDepth > highlightRadius then
			hideHubHighlight = true
		end

		if not hideHubHighlight then
			local highlight = getHighlightColor(baseColor)
			love.graphics.setColor(
			highlight[1],
			highlight[2],
			highlight[3],
			(highlight[4] or 1) * highlightAlphaMult
			)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", 0, 0, highlightRadius)
		end

		-- Outline
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.setLineWidth(3)
		love.graphics.polygon("line", points)

		if not hideHubHighlight then
			-- Hub hole
			love.graphics.circle("fill", 0, 0, HUB_HOLE_RADIUS)
		end

		love.graphics.pop()

		-- Reset stencil
		love.graphics.setStencilTest()

		if saw.ember then
			local glowX = (px or anchorX) + offsetX
			local glowY = (py or anchorY) + offsetY
			local radius = (saw.radius or SAW_RADIUS)
			local phase = saw.emberTrailPhase or 0
			local trailLength = TRACK_LENGTH * 0.55
			local trailColor = saw.emberTrailColor or {1.0, 0.32, 0.08, 0.2}
			local glowColor = saw.emberGlowColor or {1.0, 0.62, 0.22, 0.4}
			local pulse = 0.9 + 0.08 * math.sin(phase * 3.1)

			RenderLayers:withLayer("effects", function()
				local trailAlpha = (trailColor[4] or 1)
				love.graphics.setColor(trailColor[1], trailColor[2], trailColor[3], trailAlpha)
				if saw.dir == "horizontal" then
					local height = radius * (0.95 + 0.18 * math.sin(phase * 2.6))
					love.graphics.rectangle("fill", glowX - trailLength * 0.5, glowY - height * 0.5, trailLength, height)
				else
					local width = radius * (0.95 + 0.18 * math.cos(phase * 2.4))
					love.graphics.rectangle("fill", glowX - width * 0.5, glowY - trailLength * 0.5, width, trailLength)
				end

				local outerAlpha = (glowColor[4] or 1) * 0.6
				love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], outerAlpha)
				love.graphics.setLineWidth(2)
				love.graphics.circle("line", glowX, glowY, radius * (1.18 + 0.12 * pulse))

				love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], outerAlpha * 0.6)
				love.graphics.circle("line", glowX, glowY, radius * (0.88 + 0.1 * math.sin(phase * 4.4 + 0.8)))
				love.graphics.setLineWidth(1)
			end)
		end

		if saw.gilded then
			local glowX = (px or anchorX) + offsetX
			local glowY = (py or anchorY) + offsetY
			local glowRadius = (saw.radius or SAW_RADIUS) * 1.4
			RenderLayers:withLayer("effects", function()
				love.graphics.setColor(1.0, 0.82, 0.32, 0.28)
				love.graphics.circle("fill", glowX, glowY, glowRadius)
				love.graphics.setColor(1.0, 0.95, 0.72, 0.55)
				love.graphics.setLineWidth(2)
				love.graphics.circle("line", glowX, glowY, glowRadius * 0.75)
			end)
		end

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(1)
	end
end

function Saws:stall(duration, options)
	if not duration or duration <= 0 then
		return
	end

	stallTimer = (stallTimer or 0) + duration

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		local event = {
			duration = duration,
			total = stallTimer,
			cause = options and options.cause or nil,
			source = options and options.source or nil,
		}

		local positions = {}
		local sawDetails = {}
		local limit = (options and options.positionLimit) or 4

		for _, saw in ipairs(current) do
			if saw then
				local cx, cy = getSawCenter(saw)
				if cx and cy then
					positions[#positions + 1] = {cx, cy}
					sawDetails[#sawDetails + 1] = {
						x = cx,
						y = cy,
						dir = saw.dir,
						side = saw.side,
					}

					if limit and limit > 0 and #positions >= limit then
						break
					end
				end
			end
		end

		if #positions > 0 then
			event.positions = positions
			event.positionCount = #positions
		end

		if #sawDetails > 0 then
			event.saws = sawDetails
			event.sawCount = #sawDetails
		end

		Upgrades:notify("sawsStalled", event)
	end
end

function Saws:sink(duration)
	for _, saw in ipairs(self:getAll()) do
		saw.sinkTarget = 1
	end

	sinkActive = true

	if duration and duration > 0 then
		sinkTimer = max(sinkTimer, duration)
		sinkAutoRaise = true
	else
		sinkTimer = 0
		sinkAutoRaise = false
	end
end

function Saws:unsink()
	for _, saw in ipairs(self:getAll()) do
		saw.sinkTarget = 0
	end

	sinkTimer = 0
	sinkAutoRaise = false
	sinkActive = false
end

function Saws:setStallOnFruit(duration)
	self.stallOnFruit = duration or 0
end

function Saws:getStallOnFruit()
	return self.stallOnFruit or 0
end

function Saws:onFruitCollected()
	local duration = self:getStallOnFruit()
	if duration > 0 then
		self:stall(duration, {cause = "fruit"})
	end
end

function Saws:isCollisionCandidate(saw, x, y, w, h)
	return isCollisionCandidate(saw, x, y, w, h)
end

function Saws:checkCollision(x, y, w, h)
	for _, saw in ipairs(self:getAll()) do
		if isCollisionCandidate(saw, x, y, w, h) then
			local px, py = getSawCollisionCenter(saw)

			-- Circle vs AABB
			local closestX = max(x, min(px, x + w))
			local closestY = max(y, min(py, y + h))
			local dx = px - closestX
			local dy = py - closestY
			local collisionRadius = saw.collisionRadius or saw.radius
			if saw.dir == "horizontal" then
				local trackMinX = saw.trackMinX
				local trackMaxX = saw.trackMaxX
				if trackMinX and trackMaxX then
					local limit = min(px - trackMinX, trackMaxX - px)
					if limit and limit < collisionRadius then
						collisionRadius = max(limit, 0)
					end
				end
			else
				local trackMinY = saw.trackMinY
				local trackMaxY = saw.trackMaxY
				if trackMinY and trackMaxY then
					local limit = min(py - trackMinY, trackMaxY - py)
					if limit and limit < collisionRadius then
						collisionRadius = max(limit, 0)
					end
				end
			end
			if dx * dx + dy * dy < collisionRadius * collisionRadius then
				saw.hitFlashTimer = max(saw.hitFlashTimer or 0, HIT_FLASH_DURATION)
				return saw
			end
		end
	end
	return nil
end

function Saws:beginTrackSlide(saw, startX, startY, targetX, targetY, options)
	if not saw then
		return
	end

	options = options or {}
	local duration = options.duration or 0.26

	saw.tremorSlideDuration = duration
	saw.tremorSlideTimer = 0
	saw.tremorSlideStartX = startX or saw.x
	saw.tremorSlideStartY = startY or saw.y
	saw.tremorSlideTargetX = targetX or saw.x
	saw.tremorSlideTargetY = targetY or saw.y
	saw.renderX = saw.tremorSlideStartX
	saw.renderY = saw.tremorSlideStartY

	saw.x = targetX or saw.x
	saw.y = targetY or saw.y
	saw.collisionCells = nil
	clearTrackBounds(saw)

	if saw.slotId then
		local slot = getSlotById(saw.slotId)
		if slot then
			slot.tremorSlideDuration = duration
			slot.tremorSlideTimer = 0
			slot.tremorSlideStartX = startX or slot.x
			slot.tremorSlideStartY = startY or slot.y
			slot.tremorSlideTargetX = targetX or slot.x
			slot.tremorSlideTargetY = targetY or slot.y
			slot.renderX = slot.tremorSlideStartX
			slot.renderY = slot.tremorSlideStartY
			slot.x = targetX or slot.x
			slot.y = targetY or slot.y
		end
	end
end

function Saws:beginProgressNudge(saw, startProgress, targetProgress, options)
	if not saw then
		return
	end

	options = options or {}
	saw.tremorNudgeDuration = options.duration or 0.28
	saw.tremorNudgeTimer = 0
	saw.tremorNudgeStart = startProgress or saw.progress or 0
	saw.tremorNudgeTarget = targetProgress or saw.tremorNudgeStart
	saw.progress = saw.tremorNudgeStart
end

function Saws:getCenterForProgress(saw, progress)
	return getSawCenterForProgress(saw, progress)
end

return Saws