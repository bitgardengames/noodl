local GameState = {}

GameState.states = {}
GameState.current = nil
GameState.next = nil
GameState.transitionFrom = nil
GameState.transitionTime = 0
GameState.transitionDuration = 1.0
GameState.transitioning = false
GameState.transitionDirection = 1 -- 1 = fade out, -1 = fade in
GameState.pendingData = nil
GameState.queuedState = nil
GameState.queuedData = nil

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
    if self.transitioning then
        self.queuedState = stateName
        self.queuedData = data
        return
    end

    if self.current == nil or self.transitionDuration <= 0 then
        local previous = getCurrentState(self)
        if previous and previous.leave then
            previous:leave()
        end

        self.current = stateName
        self.transitionFrom = nil
        self.transitionTime = 0
        self.transitioning = false
        self.transitionDirection = -1
        self.pendingData = nil

        local nextState = getCurrentState(self)
        if nextState and nextState.enter then
            nextState:enter(data)
        end

        if nextState and nextState.onTransitionEnd then
            nextState:onTransitionEnd("in", nil)
        end

        return
    end

    self.next = stateName
    self.pendingData = data
    self.transitioning = true
    self.transitionDirection = 1
    self.transitionTime = 0
    self.transitionFrom = self.current

    local currentState = getCurrentState(self)
    if currentState and currentState.onTransitionStart then
        currentState:onTransitionStart("out", stateName)
    end
end

function GameState:update(dt)
    if self.transitioning then
        self.transitionTime = math.min(1, self.transitionTime + dt / self.transitionDuration)

        if self.transitionDirection == 1 and self.transitionTime >= 1 then
            local previousState = getCurrentState(self)
            if previousState and previousState.onTransitionEnd then
                previousState:onTransitionEnd("out", self.next)
            end
            if previousState and previousState.leave then
                previousState:leave()
            end

            self.current = self.next
            self.next = nil
            self.transitionDirection = -1
            self.transitionTime = 0

            local nextState = getCurrentState(self)
            if nextState and nextState.enter then
                nextState:enter(self.pendingData)
            end
            if nextState and nextState.onTransitionStart then
                nextState:onTransitionStart("in", self.transitionFrom)
            end

            self.pendingData = nil
        elseif self.transitionDirection == -1 and self.transitionTime >= 1 then
            local activeState = getCurrentState(self)
            if activeState and activeState.onTransitionEnd then
                activeState:onTransitionEnd("in", self.transitionFrom)
            end

            self.transitioning = false
            self.transitionTime = 0
            self.transitionFrom = nil

            if self.queuedState then
                local queuedState, queuedData = self.queuedState, self.queuedData
                self.queuedState, self.queuedData = nil, nil
                self:switch(queuedState, queuedData)
            end
        end

        return callCurrentState(self, "transitionUpdate", dt, self.transitionDirection, self.transitionTime)
    end

    return callCurrentState(self, "update", dt)
end

function GameState:draw()
    local handledTransitionDraw = false
    local skipOverlay = false

    if self.transitioning then
        local directionName = self.transitionDirection == 1 and "out" or "in"
        local stateName = self.transitionDirection == 1 and self.transitionFrom or self.current
        local state = stateName and self.states[stateName]

        if state then
            local progress = math.min(math.max(self.transitionTime, 0), 1)
            local eased = easeInOutCubic(progress)
            local alpha = getTransitionAlpha(progress, self.transitionDirection)

            if state.drawStateTransition then
                local override = state:drawStateTransition(directionName, progress, eased, alpha)

                if override ~= nil then
                    if type(override) == "table" then
                        skipOverlay = override.skipOverlay == true
                        handledTransitionDraw = override.handled ~= false
                    else
                        handledTransitionDraw = override and true or false
                    end
                end
            end

            if not handledTransitionDraw and state.draw then
                handledTransitionDraw = true

                local width = love.graphics.getWidth()
                local height = love.graphics.getHeight()
                local scale, offsetY

                if self.transitionDirection == 1 then
                    scale = 1 - 0.05 * eased
                    offsetY = 24 * eased
                else
                    local inv = 1 - eased
                    scale = 1 + 0.05 * inv
                    offsetY = 32 * inv
                end

                love.graphics.push()
                love.graphics.translate(width / 2, height / 2 + offsetY)
                love.graphics.scale(scale, scale)
                love.graphics.translate(-width / 2, -height / 2)
                state:draw()
                love.graphics.pop()
            end
        end
    end

    if not handledTransitionDraw then
        callCurrentState(self, "draw")
    end

    -- Fade overlay with easing and subtle bloom
    if self.transitioning and not skipOverlay then
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local alpha = getTransitionAlpha(self.transitionTime, self.transitionDirection)

        love.graphics.setColor(0, 0, 0, alpha * 0.85)
        love.graphics.rectangle("fill", 0, 0, width, height)

        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, alpha * 0.2)
        local radius = math.sqrt(width * width + height * height) * 0.75
        love.graphics.circle("fill", width / 2, height / 2, radius, 64)
        love.graphics.setBlendMode("alpha")
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
