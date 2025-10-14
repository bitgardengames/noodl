local Easing = require("easing")

local GameState = {}

GameState.states = {}
GameState.current = nil
GameState.next = nil
GameState.transitionFrom = nil
GameState.transitionTime = 0
GameState.defaultTransitionDuration = 1.0
GameState.transitionDuration = GameState.defaultTransitionDuration
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
	joystickaxis = true,
	gamepadpressed = true,
	gamepadreleased = true,
	gamepadaxis = true,
}

local clamp01 = Easing.clamp01
local getTransitionAlpha = Easing.getTransitionAlpha

local function parseDuration(value)
	if type(value) == "number" and value >= 0 then
		return value
	end
end

local function resolveStateDurationPreference(state, direction, otherStateName)
	if not state then
		return nil
	end

	local handler = state.getTransitionDuration
	if handler then
		local value = handler(state, direction, otherStateName)
		local parsed = parseDuration(value)
		if parsed ~= nil then
			return parsed
		end
	end

	if direction == "in" then
		local value = parseDuration(state.transitionDurationIn)
		if value ~= nil then
			return value
		end
	elseif direction == "out" then
		local value = parseDuration(state.transitionDurationOut)
		if value ~= nil then
			return value
		end
	end

	return parseDuration(state.transitionDuration)
end

local function resolveTransitionDuration(self, fromName, toName)
	local toState = toName and self.states[toName]
	local fromState = fromName and self.states[fromName]

	local duration = resolveStateDurationPreference(toState, "in", fromName)
		or resolveStateDurationPreference(fromState, "out", toName)

	if duration ~= nil then
		return duration
	end

	return self.defaultTransitionDuration or 0
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
		context.alpha = getTransitionAlpha(progress, context.direction)
	else
		context.alpha = 0
	end

	context.from = data.from
	context.to = data.to

	return context
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

function GameState:switch(stateName, data)
	if self.transitioning then
		self.queuedState = stateName
		self.queuedData = data
		return
	end

	self.transitionDuration = resolveTransitionDuration(self, self.current, stateName)

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
	callCurrentState(self, "draw")

	if not self.transitioning then
		return
	end

	local context = self.transitionContext
	local progress = math.min(math.max(self.transitionTime, 0), 1)
	local alpha = (context and context.alpha) or getTransitionAlpha(progress, self.transitionDirection)

	if alpha <= 0 then
		return
	end

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setColor(1, 1, 1, 1)
end

function GameState:dispatch(eventName, ...)
	if self.transitioning and transitionBlockedEvents[eventName] then
		return
	end

	return callCurrentState(self, eventName, ...)
end

return GameState
