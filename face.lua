local Face = {}

local textures = {
	idle  = love.graphics.newImage("Assets/FaceBlank.png"),
	happy = love.graphics.newImage("Assets/FaceHappy.png"),
	sad   = love.graphics.newImage("Assets/FaceSad.png"),
	angry = love.graphics.newImage("Assets/FaceAngry.png"),
	blink = love.graphics.newImage("Assets/FaceBlink.png"),
}

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

function Face:getTexture()
    return textures[self.state] or textures.idle
end

return Face