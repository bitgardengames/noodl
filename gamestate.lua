local Theme = require("theme")

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
GameState.transitionContext = nil

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

local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end

    return value
end

local function updateTransitionContext(self, data)
    local context = self.transitionContext
    if not context then
        context = {}
        self.transitionContext = context
    end

    context.transitioning = data.transitioning or false
    context.direction = data.direction or 0

    if context.transitioning then
        if context.direction == 1 then
            context.directionName = "out"
        elseif context.direction == -1 then
            context.directionName = "in"
        else
            context.directionName = nil
        end
    else
        context.directionName = nil
    end

    local progress = data.progress
    if progress == nil then
        progress = context.transitioning and 0 or 1
    end
    progress = clamp01(progress)

    context.progress = progress
    context.duration = data.duration or self.transitionDuration or 0
    context.time = data.time or (progress * context.duration)

    if context.direction ~= 0 and context.transitioning then
        context.eased = easeInOutCubic(progress)
        context.alpha = getTransitionAlpha(progress, context.direction)
    else
        context.eased = progress
        context.alpha = 0
    end

    context.from = data.from
    context.to = data.to

    return context
end

local function getTransitionFillColor(state, directionName, context)
    if not state then
        return nil
    end

    if state.getTransitionFillColor then
        local color = state:getTransitionFillColor(directionName, context)
        if color then
            return color
        end
    end

    if state.getBackgroundColor then
        local color = state:getBackgroundColor()
        if color then
            return color
        end
    end

    if state.backgroundColor then
        return state.backgroundColor
    end

    return Theme and Theme.bgColor
end

local function unpackColor(color)
    if type(color) == "table" then
        if color.r then
            return color.r, color.g, color.b, color.a or 1
        else
            return color[1], color[2], color[3], color[4] or 1
        end
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

        updateTransitionContext(self, {
            transitioning = false,
            direction = 0,
            progress = 1,
            duration = self.transitionDuration,
            time = 0,
            from = nil,
            to = self.current,
        })

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

    updateTransitionContext(self, {
        transitioning = true,
        direction = 1,
        progress = 0,
        duration = self.transitionDuration,
        time = 0,
        from = self.current,
        to = self.next,
    })
end

function GameState:update(dt)
    if self.transitioning then
        self.transitionTime = math.min(1, self.transitionTime + dt / self.transitionDuration)

        local context

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
            context = updateTransitionContext(self, {
                transitioning = true,
                direction = self.transitionDirection,
                progress = self.transitionTime,
                duration = self.transitionDuration,
                time = 0,
                from = self.transitionFrom,
                to = self.current,
            })
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
            context = updateTransitionContext(self, {
                transitioning = false,
                direction = self.transitionDirection,
                progress = self.transitionTime,
                duration = self.transitionDuration,
                time = 0,
                from = nil,
                to = self.current,
            })
        else
            local fromName, toName
            if self.transitionDirection == 1 then
                fromName = self.current
                toName = self.next
            else
                fromName = self.transitionFrom
                toName = self.current
            end

            context = updateTransitionContext(self, {
                transitioning = true,
                direction = self.transitionDirection,
                progress = self.transitionTime,
                duration = self.transitionDuration,
                time = self.transitionTime * self.transitionDuration,
                from = fromName,
                to = toName,
            })
        end

        return callCurrentState(self, "transitionUpdate", dt, self.transitionDirection, self.transitionTime, context)
    end

    updateTransitionContext(self, {
        transitioning = false,
        direction = 0,
        progress = 1,
        duration = self.transitionDuration,
        time = 0,
        from = nil,
        to = self.current,
    })

    return callCurrentState(self, "update", dt)
end

function GameState:draw()
    local handledTransitionDraw = false
    local skipOverlay = false
    local context = self.transitionContext

    if self.transitioning then
        local directionName = (context and context.directionName) or (self.transitionDirection == 1 and "out" or "in")
        local stateName = self.transitionDirection == 1 and self.transitionFrom or self.current
        local state = stateName and self.states[stateName]

        if state then
            local progress = (context and context.progress) or math.min(math.max(self.transitionTime, 0), 1)
            local eased = (context and context.eased) or easeInOutCubic(progress)
            local alpha = (context and context.alpha) or getTransitionAlpha(progress, self.transitionDirection)

            if state.drawStateTransition then
                local override = state:drawStateTransition(directionName, progress, eased, alpha, context)

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
                local centerX, centerY = width / 2, height / 2

                local wobble = math.sin(progress * math.pi * 6) * 0.02
                local scale
                local rotation
                local travel

                if self.transitionDirection == 1 then
                    scale = 1 + eased * 0.18 + wobble
                    rotation = eased * 0.12
                    travel = eased * 48
                else
                    local inv = 1 - eased
                    scale = 0.88 + eased * 0.12 + wobble
                    rotation = inv * -0.1
                    travel = inv * -36
                end

                love.graphics.push()
                love.graphics.translate(centerX, centerY + travel)
                love.graphics.rotate(rotation)
                love.graphics.scale(scale, scale)
                love.graphics.translate(-centerX, -centerY)

                state:draw()

                love.graphics.pop()
            end
        end
    end

    if not handledTransitionDraw then
        callCurrentState(self, "draw")
    end

    -- Stylized overlay with state-driven accent colour and streaks
    if self.transitioning and not skipOverlay then
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local alpha = (context and context.alpha) or getTransitionAlpha(self.transitionTime, self.transitionDirection)
        local directionName = (context and context.directionName) or (self.transitionDirection == 1 and "out" or "in")

        local accentState
        if self.transitionDirection == 1 then
            accentState = self.transitionFrom and self.states[self.transitionFrom]
        else
            accentState = self.current and self.states[self.current]
        end

        local accentColor = getTransitionFillColor(accentState, directionName, context)
        local r, g, b, a = unpackColor(accentColor)
        r, g, b, a = r or 0.15, g or 0.08, b or 0.2, a or 1

        love.graphics.setColor(r, g, b, alpha * 0.65)
        love.graphics.rectangle("fill", 0, 0, width, height)

        love.graphics.setBlendMode("add")

        local pulse = 0.2 + 0.2 * math.sin((context and context.time or self.transitionTime) * math.pi * 2)
        love.graphics.setColor(r, g, b, alpha * (0.3 + pulse))
        local radius = math.sqrt(width * width + height * height) * (0.5 + 0.2 * alpha)
        love.graphics.circle("fill", width / 2, height / 2, radius, 64)

        love.graphics.setColor(1, 1, 1, alpha * 0.18)
        local streakSpacing = 96
        local streakWidth = 42 + 18 * alpha
        local streakOffset = (context and context.time or self.transitionTime) * 240
        for i = -2, math.ceil(width / streakSpacing) + 2 do
            local x = (i * streakSpacing + streakOffset) % (width + streakSpacing) - streakSpacing
            love.graphics.rectangle("fill", x, -32, streakWidth, height + 64)
        end

        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function GameState:getTransitionContext()
    if not self.transitionContext then
        local fromName, toName
        if self.transitionDirection == 1 then
            fromName = self.current
            toName = self.next
        else
            fromName = self.transitionFrom
            toName = self.current
        end

        updateTransitionContext(self, {
            transitioning = self.transitioning,
            direction = self.transitionDirection,
            progress = self.transitioning and self.transitionTime or 1,
            duration = self.transitionDuration,
            time = self.transitioning and (self.transitionTime * self.transitionDuration) or 0,
            from = fromName,
            to = toName,
        })
    end

    return self.transitionContext
end

function GameState:isTransitioning()
    return self.transitioning == true
end

function GameState:getTransitionProgress()
    local context = self:getTransitionContext()
    return context and context.progress or 1
end

function GameState:getTransitionAlpha()
    local context = self:getTransitionContext()
    return context and context.alpha or 0
end

function GameState:dispatch(eventName, ...)
    if self.transitioning and shouldBlockDuringTransition(eventName) then
        return
    end

    return callCurrentState(self, eventName, ...)
end

return GameState
