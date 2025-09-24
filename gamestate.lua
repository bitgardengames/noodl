local GameState = {}

GameState.states = {}
GameState.current = nil
GameState.next = nil
GameState.transitionTime = 0
GameState.transitionDuration = 0.6
GameState.transitioning = false
GameState.transitionDirection = 1 -- 1 = fade out, -1 = fade in
GameState.pendingData = nil

-- Easing function: cubic ease-in-out (t in [0,1])
local function easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        return 1 - math.pow(-2 * t + 2, 3) / 2
    end
end

-- Returns alpha from 0 to 1 based on eased time
local function getTransitionAlpha(t, direction)
    t = math.min(math.max(t, 0), 1)
    if direction == 1 then
        return easeInOutCubic(t)
    else
        return easeInOutCubic(1 - t)
    end
end

function GameState:switch(stateName, data)
    if self.current and self.states[self.current].leave then
        self.states[self.current]:leave()
    end

    self.next = stateName
    self.pendingData = data
    self.transitioning = true
    self.transitionDirection = 1
    self.transitionTime = 0
end

local handleAction = function(result)
	if type(result) == "string" then
		GameState:switch(result)
	elseif type(result) == "table" and result.state then
		GameState:switch(result.state, result.data)
	end
end

function GameState:update(dt)
    if self.transitioning then
        self.transitionTime = self.transitionTime + dt / self.transitionDuration

        if self.transitionDirection == 1 and self.transitionTime >= 1 then
            -- Switch state at peak
            self.transitionDirection = -1
            self.transitionTime = 0
            self.current = self.next
            self.next = nil

            if self.states[self.current] and self.states[self.current].enter then
                self.states[self.current]:enter(self.pendingData)
            end

            self.pendingData = nil
        elseif self.transitionDirection == -1 and self.transitionTime >= 1 then
            self.transitioning = false
            self.transitionTime = 0
        end

        return
    end

    if self.current and self.states[self.current].update then
        local result = self.states[self.current]:update(dt)

		handleAction(result)
    end
end

function GameState:draw()
    if self.current and self.states[self.current].draw then
        self.states[self.current]:draw()
    end

    -- Fade overlay with easing
    if self.transitioning then
        local alpha = getTransitionAlpha(self.transitionTime, self.transitionDirection)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function GameState:mousepressed(x, y, button)
    if self.transitioning then return end
    if self.current and self.states[self.current].mousepressed then
        return self.states[self.current]:mousepressed(x, y, button)
    end
end

function GameState:mousereleased(x, y, button)
    if self.transitioning then return end
    if self.current and self.states[self.current].mousereleased then
        return self.states[self.current]:mousereleased(x, y, button)
    end
end

function GameState:keypressed(key)
    if self.transitioning then return end
    if self.current and self.states[self.current].keypressed then
        local result = self.states[self.current]:keypressed(key)

		handleAction(result)
    end
end

function GameState:gamepadpressed(joystick, button)
    if self.transitioning then return end
    if self.current and self.states[self.current].gamepadpressed then
        local result = self.states[self.current]:gamepadpressed(joystick, button)

		handleAction(result)

        return result
    end
end

function GameState:gamepadreleased(joystick, button)
    if self.transitioning then return end
    if self.current and self.states[self.current].gamepadreleased then
        return self.states[self.current]:gamepadreleased(joystick, button)
    end
end

return GameState