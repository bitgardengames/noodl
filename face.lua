local Timer = require("timer")
local max = math.max

local Face = {}

local FACE_WIDTH = 14
local FACE_HEIGHT = 11
local LEFT_EYE_CENTER_X = 2.5
local RIGHT_EYE_CENTER_X = 11.5
local EYE_CENTER_Y = 1.5
local EYE_RADIUS = 2
local EYELID_WIDTH = 4
local EYELID_HEIGHT = 1

local currentEyeScale = 1

local PI = math.pi

local shapeDrawers = {}
local shapeDefinitions = {}
local SHAPE_CANVAS_SIZE = 32
local SHAPE_CANVAS_SCALE = 4
local FACE_CANVAS_OFFSET_X = (SHAPE_CANVAS_SIZE - FACE_WIDTH) / 2
local FACE_CANVAS_OFFSET_Y = (SHAPE_CANVAS_SIZE - FACE_HEIGHT) / 2
local shapeCacheBuilt = false
local rebuildShapeCache

local function drawSadArc(cx, drop)
	local radius = EYE_RADIUS * currentEyeScale
	love.graphics.arc("line", cx, EYE_CENTER_Y + drop, radius, 0, PI)
end

local function drawAngryEye(cx, isLeft)
	local sizeScale = currentEyeScale
	local slitWidth = (EYELID_WIDTH + 2) * sizeScale
	local slitHeight = (EYELID_HEIGHT + 1.2) * sizeScale
	local slitTop = EYE_CENTER_Y - slitHeight / 2
	local slitLeft = cx - slitWidth / 2

	love.graphics.rectangle("fill", slitLeft, slitTop, slitWidth, slitHeight)

	local browHeight = EYE_RADIUS * 1.6 * sizeScale
	local browTop = slitTop - browHeight
	local browOuter = browTop
	local browInner = browTop + browHeight * 0.35

	if isLeft then
		love.graphics.polygon(
			"fill",
			slitLeft - 1, slitTop,
			slitLeft + slitWidth + 1, slitTop + slitHeight * 0.45,
			slitLeft + slitWidth + 1, browInner,
			slitLeft - 1, browOuter
		)
	else
		love.graphics.polygon(
			"fill",
			slitLeft - 1, slitTop + slitHeight * 0.45,
			slitLeft + slitWidth + 1, slitTop,
			slitLeft + slitWidth + 1, browOuter,
			slitLeft - 1, browInner
		)
	end
end

local function registerDrawer(name, drawer, options)
	shapeDefinitions[name] = function()
		if not (options and options.skipColor) then
			love.graphics.setColor(0, 0, 0, 1)
		end
		drawer()
	end

	if shapeCacheBuilt and rebuildShapeCache then
		rebuildShapeCache()
	end
end

local function buildShapeCache()
	if shapeCacheBuilt then
		return
	end

	for name, definition in pairs(shapeDefinitions) do
		local canvasWidth = SHAPE_CANVAS_SIZE * SHAPE_CANVAS_SCALE
		local canvasHeight = SHAPE_CANVAS_SIZE * SHAPE_CANVAS_SCALE
		local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)

		love.graphics.push("all")
		love.graphics.setCanvas(canvas)
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.origin()
		love.graphics.scale(SHAPE_CANVAS_SCALE, SHAPE_CANVAS_SCALE)
		love.graphics.translate(FACE_CANVAS_OFFSET_X, FACE_CANVAS_OFFSET_Y)

		currentEyeScale = 1
		definition()
		currentEyeScale = 1

		love.graphics.pop()

		local imageData = canvas:newImageData()
		local image = love.graphics.newImage(imageData)
		image:setFilter("linear", "linear")

		canvas:release()

		shapeDrawers[name] = {
			image = image,
			originX = canvasWidth / 2,
			originY = canvasHeight / 2,
			scale = 1 / SHAPE_CANVAS_SCALE
		}
	end

	shapeCacheBuilt = true
end

rebuildShapeCache = function()
	if not shapeCacheBuilt then
		return
	end

	for _, entry in pairs(shapeDrawers) do
		if entry.image then
			entry.image:release()
		end
	end

	shapeDrawers = {}
	shapeCacheBuilt = false

	buildShapeCache()
end

local function ensureShapeCache()
	if not shapeCacheBuilt then
		buildShapeCache()
	end
end

registerDrawer("idle", function()
	local circleSegments = 24
	local radius = EYE_RADIUS * currentEyeScale
love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, radius, circleSegments)
love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, radius, circleSegments)
end)

registerDrawer("blink", function()
	local width = EYELID_WIDTH * currentEyeScale
	local height = EYELID_HEIGHT * currentEyeScale
	local leftX = LEFT_EYE_CENTER_X - width / 2
	local rightX = RIGHT_EYE_CENTER_X - width / 2
	local top = EYE_CENTER_Y - height / 2
love.graphics.rectangle("fill", leftX, top, width, height)
love.graphics.rectangle("fill", rightX, top, width, height)
end)

registerDrawer("happy", function()
	local radius = EYE_RADIUS * currentEyeScale
	local lineWidth = radius * 0.9

love.graphics.setColor(0, 0, 0, 1)
love.graphics.setLineWidth(lineWidth)
love.graphics.setLineJoin("bevel")
love.graphics.setLineStyle("smooth")

local function drawCuteArc(cx)
	local w = radius * 1.6
	local h = radius * 1.1
	local y = EYE_CENTER_Y + 1

	local curve = love.math.newBezierCurve({
	cx - w * 0.5, y,
	cx - w * 0.25, y - h,
	cx + w * 0.25, y - h,
	cx + w * 0.5, y
})

love.graphics.line(curve:render(16))
	end

drawCuteArc(LEFT_EYE_CENTER_X)
drawCuteArc(RIGHT_EYE_CENTER_X)
end)

registerDrawer("veryHappy", function()
	local radius = EYE_RADIUS * currentEyeScale
	local lineWidth = radius * 0.9

love.graphics.setColor(0, 0, 0, 1)
love.graphics.setLineWidth(lineWidth)
love.graphics.setLineJoin("bevel")
love.graphics.setLineStyle("smooth")

local function drawCuteArc(cx)
	local w = radius * 1.8
	local h = radius * 1.3
	local y = EYE_CENTER_Y + 1

	local curve = love.math.newBezierCurve({
	cx - w * 0.5, y,
	cx - w * 0.25, y - h,
	cx + w * 0.25, y - h,
	cx + w * 0.5, y
})

love.graphics.line(curve:render(16))
	end

drawCuteArc(LEFT_EYE_CENTER_X)
drawCuteArc(RIGHT_EYE_CENTER_X)
end)

registerDrawer("sad", function()
love.graphics.setLineWidth(EYE_RADIUS * currentEyeScale * 0.9)
love.graphics.setLineJoin("bevel")
drawSadArc(LEFT_EYE_CENTER_X, 0.2)
drawSadArc(RIGHT_EYE_CENTER_X, 0.2)
end)

registerDrawer("angry", function()
drawAngryEye(LEFT_EYE_CENTER_X, true)
drawAngryEye(RIGHT_EYE_CENTER_X, false)
end)

registerDrawer("blank", function()
	local radius = EYE_RADIUS * currentEyeScale
	local halfWidth = radius * 0.9
	local lineWidth = radius * 0.55

love.graphics.setLineWidth(lineWidth)
	love.graphics.line(
	LEFT_EYE_CENTER_X - halfWidth,
	EYE_CENTER_Y,
	LEFT_EYE_CENTER_X + halfWidth,
	EYE_CENTER_Y
)
	love.graphics.line(
	RIGHT_EYE_CENTER_X - halfWidth,
	EYE_CENTER_Y,
	RIGHT_EYE_CENTER_X + halfWidth,
	EYE_CENTER_Y
)
end)

-- xx
registerDrawer("shocked", function()
	local crossSize = EYE_RADIUS * currentEyeScale * 1.6
	local crossLineWidth = EYE_RADIUS * currentEyeScale

love.graphics.setColor(0, 0, 0, 1)
love.graphics.setLineWidth(crossLineWidth)
love.graphics.setLineJoin("miter")
love.graphics.setLineStyle("smooth")

local function drawCross(cx)
	love.graphics.line(
	cx - crossSize * 0.5,
	EYE_CENTER_Y - crossSize * 0.5,
	cx + crossSize * 0.5,
	EYE_CENTER_Y + crossSize * 0.5
)
	love.graphics.line(
	cx - crossSize * 0.5,
	EYE_CENTER_Y + crossSize * 0.5,
	cx + crossSize * 0.5,
	EYE_CENTER_Y - crossSize * 0.5
)
	end

drawCross(LEFT_EYE_CENTER_X)
drawCross(RIGHT_EYE_CENTER_X)
end)

Face.state = "idle"
Face.timer = 0

-- for passive blinking
Face.blinkCooldown = 0
Face.savedState = "idle"
Face.restoreState = nil

function Face:override(state, duration)
	local previous = {
		state = self.state,
		timer = self.timer,
		restoreState = self.restoreState,
	}

	self.restoreState = previous
	self.state = state or "idle"
	self.timer = duration or 0
end

function Face:set(state, duration)
	self.state = state or "idle"
	self.timer = duration or 0
	self.restoreState = nil
end

function Face:update(dt)
	-- if in a timed state (happy/sad/angry OR blink)
	if self.timer > 0 then
		self.timer = self.timer - dt
		if self.timer <= 0 then
			local restore = self.restoreState
			self.restoreState = restore and restore.restoreState or nil
			-- if blinking, restore the previous state
			if self.state == "blink" then
				self.state = self.savedState
				self.timer = 0
			elseif restore then
				self.state = restore.state or "idle"
				self.timer = restore.timer or 0
				if self.timer <= 0 and not self.restoreState then
					self.state = self.state or "idle"
				end
			else
				self.state = "idle"
				self.timer = 0
			end
		end
		return
	end

	-- passive blinking trigger
	self.blinkCooldown = self.blinkCooldown - dt
	if self.blinkCooldown <= 0 then
		-- start blink
		self.savedState = self.state
		self.state = "blink"
		self.timer = 0.1   -- keep blink visible for 0.1s
		self.restoreState = nil
		self.blinkCooldown = love.math.random(3.5, 5.5)
	end
end

function Face:draw(x, y, scale, options)
	ensureShapeCache()

	scale = scale or 1

	local eyeScale = 1
	local highlight = 0
	local time = Timer.getTime()
	if options then
		eyeScale = max(0.4, options.eyeScale or eyeScale)
		highlight = max(0, options.highlight or highlight)
		time = options.time or time
	end

	local entry = shapeDrawers[self.state] or shapeDrawers.idle
	if not entry then
		return
	end

	local finalScale = scale * eyeScale

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 1)
	local imageScale = finalScale * (entry.scale or 1)
	love.graphics.draw(entry.image, x, y, 0, imageScale, imageScale, entry.originX, entry.originY)

	if highlight > 0 then
		local baseRadius = EYE_RADIUS
		local glowRadius = baseRadius * (1.35 + 0.35 * highlight)
		local pulse = 0.82 + 0.18 * math.sin(time * 6)
		local alpha = (0.16 + 0.22 * highlight) * pulse

		love.graphics.translate(x, y)
		love.graphics.scale(finalScale)
		love.graphics.translate(-FACE_WIDTH / 2, -FACE_HEIGHT / 2)

		love.graphics.setBlendMode("add")
		love.graphics.setColor(1.0, 0.72, 0.28, alpha)
		love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, glowRadius)
		love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, glowRadius)
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.pop()
end

return Face
