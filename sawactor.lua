local Theme = require("theme")

local SawActor = {}
SawActor.__index = SawActor

local DEFAULT_RADIUS = 24
local DEFAULT_TEETH = 12
local HUB_HOLE_RADIUS = 4
local HUB_HIGHLIGHT_PADDING = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = { 0.95, 0.08, 0.12, 1 }
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

local function getHighlightColor(color)
	color = color or { 1, 1, 1, 1 }
	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.7
	return { r, g, b, a }
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
	actor.progress = math.max(0, math.min(1, options.progress or 0))
	actor.moveDirection = options.moveDirection or DEFAULT_DIRECTION
	actor.sinkProgress = math.max(0, math.min(1, options.sinkProgress or 0))
	actor.sinkOffset = options.sinkOffset or SINK_OFFSET
	actor.sinkDistance = options.sinkDistance or SINK_DISTANCE
	actor.hitFlashTimer = 0

	return actor
end

function SawActor:update(dt)
	if not dt then
		return
	end

	self.rotation = (self.rotation + dt * self.spinSpeed) % (math.pi * 2)

	local trackLength = math.max(0.0001, self.trackLength or DEFAULT_TRACK_LENGTH)
	if self.moveSpeed ~= 0 then
		local direction = self.moveDirection or DEFAULT_DIRECTION
		local delta = (dt * self.moveSpeed) / trackLength
		self.progress = (self.progress or 0) + delta * direction

		if self.progress >= 1 then
			self.progress = 1
			self.moveDirection = -math.abs(direction)
		elseif self.progress <= 0 then
			self.progress = 0
			self.moveDirection = math.abs(direction)
		end
	end

	if self.hitFlashTimer > 0 then
		self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
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
	return math.max(0, math.min(1, value or 0))
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

	love.graphics.stencil(function()
		if self.dir == "vertical" then
			local height = trackLength + radius * 2
			local top = y - trackLength / 2 - radius
			if self.side == "left" then
				love.graphics.rectangle("fill", x, top, STENCIL_EXTENT, height)
			elseif self.side == "right" then
				love.graphics.rectangle("fill", x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
			else
				love.graphics.rectangle("fill", x - STENCIL_EXTENT, top, STENCIL_EXTENT, height)
			end
		else
			love.graphics.rectangle("fill", x - trackLength / 2 - radius, y - STENCIL_EXTENT + (self.sinkOffset or SINK_OFFSET) * drawScale, trackLength + radius * 2, STENCIL_EXTENT)
		end
	end, "replace", 1)

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
	local step = math.pi / teeth

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
	love.graphics.setColor(0, 0, 0, 0.35)
	fillSaw()
	love.graphics.pop()

	love.graphics.push()
	love.graphics.translate((px or x) + offsetX, (py or y) + offsetY)
	love.graphics.rotate(rotation)
	love.graphics.scale(overallScale, overallScale)

	local baseColor = Theme.sawColor or { 0.8, 0.8, 0.8, 1 }
	if self.hitFlashTimer and self.hitFlashTimer > 0 then
		baseColor = HIT_FLASH_COLOR
	end

	love.graphics.setColor(baseColor)
	fillSaw()

	local highlightRadiusLocal = HUB_HOLE_RADIUS + HUB_HIGHLIGHT_PADDING - 1
	local highlightRadiusWorld = highlightRadiusLocal * drawScale * sinkScale
	local hideHubHighlight = false
	local occlusionDepth = sinkOffset

	-- When the saw is partially embedded in a wall/track the stencil clips the
	-- hub highlight, which leaves a thin grey arc poking past the blade edge.
	-- Hide the highlight (and hub hole) whenever the occlusion plane reaches
	-- or crosses the highlight radius so the sliver never appears.
	if self.dir == "vertical" and (self.side == "left" or self.side == "right") then
		if occlusionDepth >= highlightRadiusWorld then
			hideHubHighlight = true
		end
	elseif occlusionDepth >= highlightRadiusWorld then
		hideHubHighlight = true
	end

	if not hideHubHighlight then
		local highlight = getHighlightColor(baseColor)
		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
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

function SawActor:setSinkProgress(progress)
	self.sinkProgress = clampProgress(progress)
end

return SawActor
