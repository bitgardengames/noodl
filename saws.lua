local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Particles = require("particles")
local Theme = require("theme")
local RenderLayers = require("renderlayers")

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
local SHADOW_OFFSET = 6
local SHADOW_ALPHA = 0.35

local function copyColor(color)
	if not color then
		return { 1, 1, 1, 1 }
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
	}
end

local function getHighlightColor(color)
	color = color or {1, 1, 1, 1}
	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.7
	return {r, g, b, a}
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

	return math.max(1, math.min(Arena.rows, row))
end

local function clampCol(col)
	if not Arena or (Arena.cols or 0) <= 0 then
		return col
	end

	return math.max(1, math.min(Arena.cols, col))
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
	target[#target + 1] = { col, row }
end

local function buildCollisionCellsForSaw(saw)
	if not saw then
		return nil
	end

	local trackCells = SnakeUtils.getSawTrackCells(saw.x, saw.y, saw.dir) or {}
	if #trackCells == 0 then
		return nil
	end

	local cells = {}
	local seen = {}

	-- Limit collision coverage to the track cell and the adjacent cell the blade
	-- actually occupies so the hazard doesn't spill into neighboring tiles.
	if saw.dir == "horizontal" then
		for _, cell in ipairs(trackCells) do
			local col, row = cell[1], cell[2]
			addCell(cells, seen, col, row)
			addCell(cells, seen, col, row + 1)
		end
	else
		local offsetDir = (saw.side == "left") and -1 or 1

		for _, cell in ipairs(trackCells) do
			local col, row = cell[1], cell[2]
			addCell(cells, seen, col, row)
			addCell(cells, seen, col + offsetDir, row)
		end
	end

	return cells
end

local function overlapsCollisionCell(saw, x, y, w, h)
	local cells = saw and saw.collisionCells
	if not (cells and #cells > 0) then
		return true
	end

	if not (Arena and Arena.getTilePosition) then
		return true
	end

	local tileSize = getTileSize()

	for _, cell in ipairs(cells) do
		local col, row = cell[1], cell[2]
		local cellX, cellY = Arena:getTilePosition(col, row)
		if x < cellX + tileSize and x + w > cellX and y < cellY + tileSize and y + h > cellY then
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

	return overlapsCollisionCell(saw, x, y, w, h)
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

	table.insert(slots, slot)
	return slot
end

local function getSawCenter(saw)
	if not saw then
		return nil, nil
	end

	if saw.dir == "horizontal" then
		local minX = saw.x - TRACK_LENGTH/2 + saw.radius
		local maxX = saw.x + TRACK_LENGTH/2 - saw.radius
		local px = minX + (maxX - minX) * saw.progress
		return px, saw.y
	end

	local minY = saw.y - TRACK_LENGTH/2 + saw.radius
	local maxY = saw.y + TRACK_LENGTH/2 - saw.radius
	local py = minY + (maxY - minY) * saw.progress

	-- Vertical saws should sit centered in their track just like horizontal ones.
	-- Previously the hub was offset vertically, which made the blade appear to
	-- jut too far into the arena. Keep the center aligned with the track so both
	-- orientations look consistent.
	return saw.x, py
end

local function getSawCollisionCenter(saw)
	local px, py = getSawCenter(saw)
	if not (px and py) then
		return px, py
	end

	local sinkOffset = SINK_OFFSET + (saw.sinkProgress or 0) * SINK_DISTANCE
	if saw.dir == "horizontal" then
		py = py + sinkOffset
	else
		local sinkDir = (saw.side == "left") and -1 or 1
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
			local px, py = getSawCenter(saw)
			local sawColor = Theme.sawColor or {0.85, 0.8, 0.75, 1}
			local primary = copyColor(sawColor)
			primary[4] = 1
			local highlight = getHighlightColor(sawColor)

			Particles:spawnBurst(px or saw.x, py or saw.y, {
				count = 12,
				speed = 82,
				speedVariance = 68,
				life = 0.35,
				size = 2.3,
				color = {primary[1], primary[2], primary[3], primary[4]},
				spread = math.pi * 2,
				angleJitter = math.pi,
				drag = 3.5,
				gravity = 260,
				scaleMin = 0.45,
				scaleVariance = 0.5,
				fadeTo = 0.04,
			})

			Particles:spawnBurst(px or saw.x, py or saw.y, {
				count = love.math.random(4, 6),
				speed = 132,
				speedVariance = 72,
				life = 0.26,
				size = 1.8,
				color = {1.0, 0.94, 0.52, highlight[4] or 1},
				spread = math.pi * 2,
				angleJitter = math.pi,
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
function Saws:spawn(x, y, radius, teeth, dir, side)
	local slot = getOrCreateSlot(x, y, dir)

	table.insert(current, {
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
		collisionCells = nil,
		hitFlashTimer = 0,
	})

	local saw = current[#current]
	saw.collisionCells = buildCollisionCellsForSaw(saw)
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
		stallTimer = math.max(0, stallTimer - dt)
	end

	if sinkAutoRaise and sinkTimer > 0 then
		sinkTimer = math.max(0, sinkTimer - dt)
		if sinkTimer <= 0 then
			self:unsink()
		end
	end

	for _, saw in ipairs(current) do
		if not saw.collisionCells then
			saw.collisionCells = buildCollisionCellsForSaw(saw)
		end

		saw.collisionRadius = (saw.radius or SAW_RADIUS) * COLLISION_RADIUS_MULT

		saw.timer = saw.timer + dt
		saw.rotation = (saw.rotation + dt * 5 * (self.spinMult or 1)) % (math.pi * 2)

		local sinkDirection = (saw.sinkTarget or 0) > 0 and 1 or -1
		saw.sinkProgress = saw.sinkProgress + sinkDirection * dt * SINK_SPEED
		if saw.sinkProgress < 0 then
			saw.sinkProgress = 0
		elseif saw.sinkProgress > 1 then
			saw.sinkProgress = 1
		end

		saw.hitFlashTimer = math.max(0, (saw.hitFlashTimer or 0) - dt)

		if saw.phase == "drop" then
			local progress = math.min(saw.timer / SPAWN_DURATION, 1)
			saw.offsetY = -40 * (1 - progress)
			saw.scaleY = progress
			saw.scaleX = progress

			if progress >= 1 then
				saw.phase = "squash"
				saw.timer = 0
			end

		elseif saw.phase == "squash" then
			local progress = math.min(saw.timer / SQUASH_DURATION, 1)
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
			if stallTimer <= 0 then
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
	end
end

function Saws:draw()
	if #slots > 0 then
		love.graphics.setColor(0, 0, 0, 1)
		for _, slot in ipairs(slots) do
			if slot.dir == "horizontal" then
				love.graphics.rectangle("fill", slot.x - TRACK_LENGTH/2, slot.y - 5, TRACK_LENGTH, 10, 6, 6)
			else
				love.graphics.rectangle("fill", slot.x - 5, slot.y - TRACK_LENGTH/2, 10, TRACK_LENGTH, 6, 6)
			end
		end
	end

	for _, saw in ipairs(current) do
		local px, py = getSawCenter(saw)
		local sinkProgress = math.max(0, math.min(1, saw.sinkProgress or 0))
		local sinkOffset = sinkProgress * SINK_DISTANCE
		local occlusionDepth = SINK_OFFSET + sinkOffset
		local offsetX, offsetY = 0, 0
		local sinkDir = 1

		if saw.dir == "horizontal" then
			offsetY = occlusionDepth
		else
			sinkDir = (saw.side == "left") and -1 or 1
			offsetX = sinkDir * occlusionDepth
		end

		local sinkScale = 1 - 0.1 * sinkProgress
		local rotation = saw.rotation or 0
		local teeth = saw.teeth or 8
		local outer = saw.radius or SAW_RADIUS
		local inner = outer * 0.8
		local step = math.pi / math.max(1, teeth)
		local points = {}

		for i = 0, (teeth * 2) - 1 do
			local r = (i % 2 == 0) and outer or inner
			local angle = i * step
			points[#points + 1] = math.cos(angle) * r
			points[#points + 1] = math.sin(angle) * r
		end

		if #points >= 6 then
			RenderLayers:withLayer("shadows", function()
				love.graphics.push()

				local shadowOffsetX = offsetX
				local shadowOffsetY = offsetY

				if saw.dir == "horizontal" then
					shadowOffsetX = shadowOffsetX + SHADOW_OFFSET * 0.4
					shadowOffsetY = shadowOffsetY + SHADOW_OFFSET
				else
					local shadowDirX = sinkDir
					if saw.side == "left" then
						shadowDirX = 1
					end
					shadowOffsetX = shadowOffsetX + SHADOW_OFFSET * shadowDirX
					shadowOffsetY = shadowOffsetY + SHADOW_OFFSET * 0.5
				end

				love.graphics.translate((px or saw.x) + shadowOffsetX, (py or saw.y) + shadowOffsetY)
				love.graphics.rotate(rotation)
				love.graphics.scale(sinkScale, sinkScale)

				local alpha = SHADOW_ALPHA * (1 - 0.4 * sinkProgress)
				love.graphics.setColor(0, 0, 0, alpha)
				love.graphics.polygon("fill", points)

				love.graphics.pop()
			end)
		end

		-- Stencil: clip saw into the track (adjust direction for left/right mounted saws)
		love.graphics.stencil(function()
			if saw.dir == "horizontal" then
				love.graphics.rectangle("fill",
				saw.x - TRACK_LENGTH/2 - saw.radius,
				saw.y - 999 + SINK_OFFSET,
				TRACK_LENGTH + saw.radius * 2,
				999)
			else
				-- For vertical saws, choose stencil side based on saw.side
				local height = TRACK_LENGTH + saw.radius * 2
				local top = saw.y - TRACK_LENGTH/2 - saw.radius
				if saw.side == "left" then
					-- allow rightwards area (blade peeking into arena)
					love.graphics.rectangle("fill",
					saw.x,
					top,
					999,
					height)
				elseif saw.side == "right" then
					-- allow leftwards area (default)
					love.graphics.rectangle("fill",
					saw.x - 999,
					top,
					999,
					height)
				else
					-- centered/default: cover left side as before (keeps backward compatibility)
					love.graphics.rectangle("fill",
					saw.x - 999,
					top,
					999,
					height)
				end
			end
		end, "replace", 1)

		love.graphics.setStencilTest("equal", 1)

		-- Saw blade
		love.graphics.push()
		love.graphics.translate((px or saw.x) + offsetX, (py or saw.y) + offsetY)

		-- apply spinning rotation
		love.graphics.rotate(rotation)

		love.graphics.scale(sinkScale, sinkScale)

		-- Fill
		local baseColor = Theme.sawColor or {0.8, 0.8, 0.8, 1}
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
				local occlusionRatio = math.min(1, math.max(0, occlusionDepth / highlightRadius))
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
					positions[#positions + 1] = { cx, cy }
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
		sinkTimer = math.max(sinkTimer, duration)
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
		self:stall(duration, { cause = "fruit" })
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
			local closestX = math.max(x, math.min(px, x + w))
			local closestY = math.max(y, math.min(py, y + h))
			local dx = px - closestX
			local dy = py - closestY
			local collisionRadius = saw.collisionRadius or saw.radius
			if dx * dx + dy * dy < collisionRadius * collisionRadius then
				saw.hitFlashTimer = math.max(saw.hitFlashTimer or 0, HIT_FLASH_DURATION)
				return saw
			end
		end
	end
	return nil
end

return Saws
