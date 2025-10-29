local Theme = require("theme")

local abs = math.abs
local max = math.max
local min = math.min
local pi = math.pi

local SawActor = {}
SawActor.__index = SawActor

local DEFAULT_RADIUS = 24
local DEFAULT_TEETH = 12
local HUB_HOLE_RADIUS = 4
local HUB_HIGHLIGHT_PADDING = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}
local DEFAULT_SPIN_SPEED = 5
local DEFAULT_TRACK_LENGTH = 120
local DEFAULT_MOVE_SPEED = 60
local DEFAULT_DIRECTION = 1
local DEFAULT_ORIENTATION = "horizontal"
local TRACK_SLOT_THICKNESS = 10
local TRACK_SLOT_RADIUS = 6
local STENCIL_EXTENT = 999
local SINK_OFFSET = 2
local SINK_DISTANCE = 28
local SHADOW_OFFSET = 3
local SHADOW_ALPHA = 0.35

local sawStencilState = {
	dir = nil,
	side = nil,
	x = 0,
	y = 0,
	trackLength = 0,
	radius = 0,
	sinkOffset = 0,
}

local function drawSawStencil()
	if sawStencilState.dir == "vertical" then
		local height = sawStencilState.trackLength + sawStencilState.radius * 2
		local top = sawStencilState.y - sawStencilState.trackLength / 2 - sawStencilState.radius
		if sawStencilState.side == "left" then
			love.graphics.rectangle("fill", sawStencilState.x, top, STENCIL_EXTENT, height)
		elseif sawStencilState.side == "right" then
			love.graphics.rectangle("fill", sawStencilState.x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
		else
			love.graphics.rectangle("fill", sawStencilState.x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
		end
	else
		love.graphics.rectangle(
		"fill",
		sawStencilState.x - sawStencilState.trackLength / 2 - sawStencilState.radius,
		sawStencilState.y - STENCIL_EXTENT + sawStencilState.sinkOffset,
		sawStencilState.trackLength + sawStencilState.radius * 2,
		STENCIL_EXTENT
		)
	end
end

local highlightCache = setmetatable({}, { __mode = "k" })
local highlightDefault = {1, 1, 1, 1}

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

function SawActor.new(options)
	local actor = setmetatable({}, SawActor)
	options = options or {}

	actor.radius = options.radius or DEFAULT_RADIUS
	actor.teeth = options.teeth or DEFAULT_TEETH
	actor.rotation = options.rotation or 0
	actor.spinSpeed = options.spinSpeed or DEFAULT_SPIN_SPEED
	actor.trackLength = options.trackLength or DEFAULT_TRACK_LENGTH
	actor.moveSpeed = options.moveSpeed or DEFAULT_MOVE_SPEED
	actor.dir = options.dir or DEFAULT_ORIENTATION
	actor.side = options.side
	actor.progress = max(0, min(1, options.progress or 0))
	actor.moveDirection = options.moveDirection or DEFAULT_DIRECTION
	actor.sinkProgress = max(0, min(1, options.sinkProgress or 0))
	actor.sinkOffset = options.sinkOffset or SINK_OFFSET
	actor.sinkDistance = options.sinkDistance or SINK_DISTANCE
	actor.hitFlashTimer = 0

	return actor
end

function SawActor:update(dt)
	if not dt then
		return
	end

	self.rotation = (self.rotation + dt * self.spinSpeed) % (pi * 2)

	local trackLength = max(0.0001, self.trackLength or DEFAULT_TRACK_LENGTH)
	if self.moveSpeed ~= 0 then
		local direction = self.moveDirection or DEFAULT_DIRECTION
		local delta = (dt * self.moveSpeed) / trackLength
		local progress = (self.progress or 0) + delta * direction

		while progress > 1 or progress < 0 do
			if progress > 1 then
				progress = 2 - progress
				direction = -abs(direction)
			else
				progress = -progress
				direction = abs(direction)
			end
		end

		self.progress = max(0, min(1, progress))
		self.moveDirection = direction
	end

	if self.hitFlashTimer > 0 then
		self.hitFlashTimer = max(0, self.hitFlashTimer - dt)
	end
end

function SawActor:triggerHitFlash(duration)
	if duration and duration > 0 then
		self.hitFlashTimer = duration
	else
		self.hitFlashTimer = HIT_FLASH_DURATION
	end
end

local function clampProgress(value)
	return max(0, min(1, value or 0))
end

local function getSawCenter(actor, x, y, radius, trackLength)
	if actor.dir == "vertical" then
		local minY = y - trackLength / 2 + radius
		local maxY = y + trackLength / 2 - radius
		local py = minY + (maxY - minY) * clampProgress(actor.progress)
		return x, py
	end

	local minX = x - trackLength / 2 + radius
	local maxX = x + trackLength / 2 - radius
	local px = minX + (maxX - minX) * clampProgress(actor.progress)
	return px, y
end

function SawActor:draw(x, y, scale)
	if not (x and y) then
		return
	end

	local drawScale = scale or 1
	local radius = (self.radius or DEFAULT_RADIUS) * drawScale
	local trackLength = (self.trackLength or DEFAULT_TRACK_LENGTH) * drawScale
	local slotThickness = TRACK_SLOT_THICKNESS * drawScale
	local slotRadius = TRACK_SLOT_RADIUS * drawScale

	love.graphics.setColor(0, 0, 0, 1)
	if self.dir == "vertical" then
		love.graphics.rectangle("fill", x - slotThickness / 2, y - trackLength / 2, slotThickness, trackLength, slotRadius, slotRadius)
	else
		love.graphics.rectangle("fill", x - trackLength / 2, y - slotThickness / 2, trackLength, slotThickness, slotRadius, slotRadius)
	end

	sawStencilState.dir = self.dir
	sawStencilState.side = self.side
	sawStencilState.x = x
	sawStencilState.y = y
	sawStencilState.trackLength = trackLength
	sawStencilState.radius = radius
	sawStencilState.sinkOffset = (self.sinkOffset or SINK_OFFSET) * drawScale
	love.graphics.stencil(drawSawStencil, "replace", 1)

	love.graphics.setStencilTest("equal", 1)

	local px, py = getSawCenter(self, x, y, radius, trackLength)
	local sinkProgress = clampProgress(self.sinkProgress)
	local sinkDistance = (self.sinkDistance or SINK_DISTANCE) * drawScale
	local sinkBase = (self.sinkOffset or SINK_OFFSET) * drawScale
	local sinkOffset = sinkBase + sinkDistance * sinkProgress
	local offsetX, offsetY = 0, 0

	if self.dir == "vertical" then
		local sinkDir = (self.side == "left") and -1 or 1
		offsetX = sinkDir * sinkOffset
	else
		offsetY = sinkOffset
	end

	local sinkScale = 1 - 0.1 * sinkProgress
	local overallScale = drawScale * sinkScale
	local rotation = self.rotation or 0

	local points = {}
	local teeth = self.teeth or DEFAULT_TEETH
	local outer = self.radius or DEFAULT_RADIUS
	local inner = outer * 0.8
	local step = pi / teeth

	for i = 0, (teeth * 2) - 1 do
		local r = (i % 2 == 0) and outer or inner
		local angle = i * step
		points[#points + 1] = math.cos(angle) * r
		points[#points + 1] = math.sin(angle) * r
	end

	local triangles = nil
	if teeth and teeth >= 3 then
		triangles = love.math.triangulate(points)
	end

	local function fillSaw()
		if triangles and #triangles > 0 then
			for _, triangle in ipairs(triangles) do
				love.graphics.polygon("fill", triangle)
			end
		else
			love.graphics.polygon("fill", points)
		end
	end

	love.graphics.push()
	love.graphics.translate(
	(px or x) + SHADOW_OFFSET * drawScale - offsetX,
	(py or y) + SHADOW_OFFSET * drawScale - offsetY
	)
	love.graphics.rotate(rotation)
	love.graphics.scale(overallScale, overallScale)

	local shadowAlpha = SHADOW_ALPHA * (1 - 0.4 * sinkProgress)
	love.graphics.setColor(0, 0, 0, shadowAlpha)
	fillSaw()
	love.graphics.pop()

	love.graphics.push()
	love.graphics.translate((px or x) + offsetX, (py or y) + offsetY)
	love.graphics.rotate(rotation)
	love.graphics.scale(overallScale, overallScale)

	local baseColor = Theme.sawColor or {0.8, 0.8, 0.8, 1}
	if self.hitFlashTimer and self.hitFlashTimer > 0 then
		baseColor = HIT_FLASH_COLOR
	end

	love.graphics.setColor(baseColor)
	fillSaw()

	local highlightRadiusLocal = HUB_HOLE_RADIUS + HUB_HIGHLIGHT_PADDING - 1
	local highlightRadiusWorld = highlightRadiusLocal * drawScale * sinkScale
	local hideHubHighlight = false
	local highlightAlphaMult = 1
	local occlusionDepth = sinkOffset

	if self.dir == "vertical" and (self.side == "left" or self.side == "right") then
		if occlusionDepth <= 0 then
			hideHubHighlight = true
		else
			local occlusionRatio = min(1, max(0, occlusionDepth / highlightRadiusWorld))
			highlightAlphaMult = 0.4 + 0.6 * occlusionRatio
		end
	elseif occlusionDepth >= highlightRadiusWorld then
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
		love.graphics.circle("line", 0, 0, highlightRadiusLocal)
	end

	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.setLineWidth(3)
	love.graphics.polygon("line", points)

	if not hideHubHighlight then
		love.graphics.circle("fill", 0, 0, HUB_HOLE_RADIUS)
	end

	love.graphics.pop()

	love.graphics.setStencilTest()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

function SawActor:getSlotThickness()
	return TRACK_SLOT_THICKNESS
end

return SawActor