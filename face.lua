local Face = {}

local FACE_WIDTH = 14
local FACE_HEIGHT = 11

local LEFT_EYE_CENTER_X = 1.5
local RIGHT_EYE_CENTER_X = 11.5
local EYE_CENTER_Y = 1.5
local EYE_RADIUS = 2
local EYELID_WIDTH = 4
local EYELID_HEIGHT = 1

local shapeDrawers = {}

local PI = math.pi

local function drawHappyArc(cx, lift)
    love.graphics.arc("line", cx, EYE_CENTER_Y + lift, EYE_RADIUS, PI, 2 * PI)
end

local function drawSadArc(cx, drop)
    love.graphics.arc("line", cx, EYE_CENTER_Y + drop, EYE_RADIUS, 0, PI)
end

local function drawAngryEye(cx, isLeft)
    local slitWidth = EYELID_WIDTH + 2
    local slitHeight = EYELID_HEIGHT + 1.2
    local slitTop = EYE_CENTER_Y - slitHeight / 2
    local slitLeft = cx - slitWidth / 2

    love.graphics.rectangle("fill", slitLeft, slitTop, slitWidth, slitHeight)

    local browHeight = EYE_RADIUS * 1.6
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

shapeDrawers.idle = function()
    love.graphics.setColor(0, 0, 0, 1)
    -- Explicitly provide a generous segment count so the filled circles stay
    -- visually round even after any scaling applied to the snake sprite.
    local circleSegments = 24
    love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, circleSegments)
    love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, circleSegments)
end

shapeDrawers.blink = function()
    love.graphics.setColor(0, 0, 0, 1)
    local leftX = LEFT_EYE_CENTER_X - EYELID_WIDTH / 2
    local rightX = RIGHT_EYE_CENTER_X - EYELID_WIDTH / 2
    local top = EYE_CENTER_Y - EYELID_HEIGHT / 2
    love.graphics.rectangle("fill", leftX, top, EYELID_WIDTH, EYELID_HEIGHT)
    love.graphics.rectangle("fill", rightX, top, EYELID_WIDTH, EYELID_HEIGHT)
end

shapeDrawers.happy = function()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(EYE_RADIUS * 1.1)
    love.graphics.setLineJoin("bevel")
    drawHappyArc(LEFT_EYE_CENTER_X, 1.0)
    drawHappyArc(RIGHT_EYE_CENTER_X, 1.0)
end

shapeDrawers.veryHappy = function()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(EYE_RADIUS * 1.3)
    love.graphics.setLineJoin("bevel")
    drawHappyArc(LEFT_EYE_CENTER_X, 1.3)
    drawHappyArc(RIGHT_EYE_CENTER_X, 1.3)
end

shapeDrawers.sad = function()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(EYE_RADIUS * 0.9)
    love.graphics.setLineJoin("bevel")
    drawSadArc(LEFT_EYE_CENTER_X, 0.2)
    drawSadArc(RIGHT_EYE_CENTER_X, 0.2)
end

shapeDrawers.angry = function()
    love.graphics.setColor(0, 0, 0, 1)
    drawAngryEye(LEFT_EYE_CENTER_X, true)
    drawAngryEye(RIGHT_EYE_CENTER_X, false)
end

shapeDrawers.blank = function()
    -- intentionally empty: blank face has no visible eyes
end

local shapeDrawers = {}

shapeDrawers.idle = function()
    love.graphics.setColor(0, 0, 0, 1)
    local circleSegments = 24
    love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, circleSegments)
    love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS, circleSegments)
end

shapeDrawers.blink = function()
    love.graphics.setColor(0, 0, 0, 1)
    local leftX = LEFT_EYE_CENTER_X - EYELID_WIDTH / 2
    local rightX = RIGHT_EYE_CENTER_X - EYELID_WIDTH / 2
    local top = EYE_CENTER_Y - EYELID_HEIGHT / 2
    love.graphics.rectangle("fill", leftX, top, EYELID_WIDTH, EYELID_HEIGHT)
    love.graphics.rectangle("fill", rightX, top, EYELID_WIDTH, EYELID_HEIGHT)
end

Face.state = "idle"
Face.timer = 0

-- for passive blinking
Face.blinkCooldown = 0
Face.savedState = "idle"

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
                self.state = self.savedState
            else
                self.state = "idle"
            end
            self.timer = 0
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
        self.blinkCooldown = love.math.random(2, 4)
    end
end

function Face:draw(x, y, scale)
    scale = scale or 1

    local drawer = shapeDrawers[self.state] or shapeDrawers.idle

    love.graphics.push("all")
    love.graphics.translate(x, y)
    love.graphics.scale(scale)
    love.graphics.translate(-FACE_WIDTH / 2, -FACE_HEIGHT / 2)

    drawer()

    love.graphics.pop()
end

return Face
