local Face = {}

local FACE_WIDTH = 14
local FACE_HEIGHT = 11

local LEFT_EYE_CENTER_X = 1.5
local RIGHT_EYE_CENTER_X = 11.5
local EYE_CENTER_Y = 1.5
local EYE_RADIUS = 2
local EYELID_WIDTH = 4
local EYELID_HEIGHT = 1

local textures = {
    happy = love.graphics.newImage("Assets/FaceHappy.png"),
    sad   = love.graphics.newImage("Assets/FaceSad.png"),
    angry = love.graphics.newImage("Assets/FaceAngry.png"),
}

local shapeDrawers = {}

shapeDrawers.idle = function()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", LEFT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS)
    love.graphics.circle("fill", RIGHT_EYE_CENTER_X, EYE_CENTER_Y, EYE_RADIUS)
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

    local drawer = shapeDrawers[self.state]

    if drawer then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(scale)
        love.graphics.translate(-FACE_WIDTH / 2, -FACE_HEIGHT / 2)

        drawer()

        love.graphics.pop()
    else
        local texture = textures[self.state]
        if not texture then
            drawer = shapeDrawers.idle
        end

        if texture then
            local ox = texture:getWidth() / 2
            local oy = texture:getHeight() / 2
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(texture, x, y, 0, scale, scale, ox, oy)
        elseif drawer then
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(scale)
            love.graphics.translate(-FACE_WIDTH / 2, -FACE_HEIGHT / 2)

            drawer()

            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Face
