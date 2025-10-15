local Face = {}

local FACE_WIDTH = 14
local FACE_HEIGHT = 11

local LEFT_EYE_CENTER_X = 2.5
local RIGHT_EYE_CENTER_X = 11.5
local EYE_CENTER_Y = 1.5
local EYE_RADIUS = 2
local EYELID_WIDTH = 4
local EYELID_HEIGHT = 1

local PI = math.pi

local ShapeDrawers = {}

local function DrawHappyArc(cx, lift)
	love.graphics.arc("line", cx, EYE_CENTER_Y + lift, EYE_RADIUS, PI, 2 * PI)
end

local function DrawSadArc(cx, drop)
	love.graphics.arc("line", cx, EYE_CENTER_Y + drop, EYE_RADIUS, 0, PI)
end

local function DrawAngryEye(cx, IsLeft)
	local SlitWidth = EYELID_WIDTH + 2
	local SlitHeight = EYELID_HEIGHT + 1.2
	local SlitTop = EYE_CENTER_Y - SlitHeight / 2
	local SlitLeft = cx - SlitWidth / 2

	love.graphics.rectangle("fill", SlitLeft, SlitTop, SlitWidth, SlitHeight)

	local BrowHeight = EYE_RADIUS * 1.6
	local BrowTop = SlitTop - BrowHeight
	local BrowOuter = BrowTop
	local BrowInner = BrowTop + BrowHeight * 0.35

	if IsLeft then
		love.graphics.polygon(
			"fill",
			SlitLeft - 1, SlitTop,
			SlitLeft + SlitWidth + 1, SlitTop + SlitHeight * 0.45,
			SlitLeft + SlitWidth + 1, BrowInner,
			SlitLeft - 1, BrowOuter
		)
	else
		love.graphics.polygon(
			"fill",
			SlitLeft - 1, SlitTop + SlitHeight * 0.45,
			SlitLeft + SlitWidth + 1, SlitTop,
			SlitLeft + SlitWidth + 1, BrowOuter,
			SlitLeft - 1, BrowInner
		)
	end
end

local function RegisterDrawer(name, drawer, options)
	ShapeDrawers[name] = function()
		if not (options and options.skipColor) then
			love.graphics.setColor(0, 0, 0, 1)
		end
		drawer()
	end
end

RegisterDrawer("idle", function()
	-- Explicitly provide a generous segment count so the filled circles stay
	-- visually round even after any scaling applied to the snake sprite.
	local CircleSegments = 24
	love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, CircleSegments)
	love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, CircleSegments)
end)

RegisterDrawer("blink", function()
	local LeftX = LEFT_EYE_CENTER_X - EYELID_WIDTH / 2
	local RightX = RIGHT_EYE_CENTER_X - EYELID_WIDTH / 2
	local top = EYE_CENTER_Y - EYELID_HEIGHT / 2
	love.graphics.rectangle("fill", LeftX, top, EYELID_WIDTH, EYELID_HEIGHT)
	love.graphics.rectangle("fill", RightX, top, EYELID_WIDTH, EYELID_HEIGHT)
end)

RegisterDrawer("happy", function()
	love.graphics.setLineWidth(EYE_RADIUS * 1.1)
	love.graphics.setLineJoin("bevel")
	DrawHappyArc(LEFT_EYE_CENTER_X, 1.0)
	DrawHappyArc(RIGHT_EYE_CENTER_X, 1.0)
end)

RegisterDrawer("VeryHappy", function()
	love.graphics.setLineWidth(EYE_RADIUS * 1.3)
	love.graphics.setLineJoin("bevel")
	DrawHappyArc(LEFT_EYE_CENTER_X, 1.3)
	DrawHappyArc(RIGHT_EYE_CENTER_X, 1.3)
end)

RegisterDrawer("sad", function()
	love.graphics.setLineWidth(EYE_RADIUS * 0.9)
	love.graphics.setLineJoin("bevel")
	DrawSadArc(LEFT_EYE_CENTER_X, 0.2)
	DrawSadArc(RIGHT_EYE_CENTER_X, 0.2)
end)

RegisterDrawer("angry", function()
	DrawAngryEye(LEFT_EYE_CENTER_X, true)
	DrawAngryEye(RIGHT_EYE_CENTER_X, false)
end)

RegisterDrawer("blank", function()
	-- intentionally empty: blank face has no visible eyes
end, { SkipColor = true })

Face.state = "idle"
Face.timer = 0

-- for passive blinking
Face.BlinkCooldown = 0
Face.SavedState = "idle"

function Face:set(state, duration)
	self.state = state or "idle"
	self.timer = duration or 0
end

function Face:update(dt)
	-- if in a timed state (happy/sad/angry OR blink)
	if self.timer > 0 then
		self.timer = self.timer - dt
		if self.timer <= 0 then
			-- if blinking, restore the previous state
			if self.state == "blink" then
				self.state = self.SavedState
			else
				self.state = "idle"
			end
			self.timer = 0
		end
		return
	end

	-- passive blinking trigger
	self.BlinkCooldown = self.BlinkCooldown - dt
	if self.BlinkCooldown <= 0 then
		-- start blink
		self.SavedState = self.state
		self.state = "blink"
		self.timer = 0.1   -- keep blink visible for 0.1s
		self.BlinkCooldown = love.math.random(2, 4)
	end
end

function Face:draw(x, y, scale)
	scale = scale or 1

	local drawer = ShapeDrawers[self.state] or ShapeDrawers.idle

	love.graphics.push("all")
	love.graphics.translate(x, y)
	love.graphics.scale(scale)
	love.graphics.translate(-FACE_WIDTH / 2, -FACE_HEIGHT / 2)

	drawer()

	love.graphics.pop()
end

return Face
