local GameState = {}

GameState.states = {}
GameState.current = nil
GameState.next = nil
GameState.transitionTime = 0
GameState.transitionDuration = 1.2
GameState.transitioning = false
GameState.transitionDirection = 1 -- 1 = fade out, -1 = fade in
GameState.pendingData = nil

local transitionBlockedEvents = {
    mousepressed = true,
    mousereleased = true,
    keypressed = true,
    joystickpressed = true,
    joystickreleased = true,
    gamepadpressed = true,
    gamepadreleased = true,
}

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

local function getCurrentState(self)
    return self.states[self.current]
end

local function callCurrentState(self, methodName, ...)
    local state = getCurrentState(self)
    if state then
        local handler = state[methodName]
        if handler then
            return handler(state, ...)
        end
    end
end

local function shouldBlockDuringTransition(eventName)
    return transitionBlockedEvents[eventName]
end

function GameState:switch(stateName, data)
    local currentState = getCurrentState(self)
    if currentState and currentState.leave then
        currentState:leave()
    end

    self.next = stateName
    self.pendingData = data
    self.transitioning = true
    self.transitionDirection = 1
    self.transitionTime = 0
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

            local nextState = getCurrentState(self)
            if nextState and nextState.enter then
                nextState:enter(self.pendingData)
            end

            self.pendingData = nil
        elseif self.transitionDirection == -1 and self.transitionTime >= 1 then
            self.transitioning = false
            self.transitionTime = 0
        end

        return
    end

    return callCurrentState(self, "update", dt)
end

function GameState:draw()
    callCurrentState(self, "draw")

    -- Fade overlay with easing
    if self.transitioning then
        local alpha = getTransitionAlpha(self.transitionTime, self.transitionDirection)
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function GameState:dispatch(eventName, ...)
    if self.transitioning and shouldBlockDuringTransition(eventName) then
        return
    end

    return callCurrentState(self, eventName, ...)
end

return GameState
