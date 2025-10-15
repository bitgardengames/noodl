local Easing = require("easing")

local GameState = {}

GameState.states = {}
GameState.current = nil
GameState.next = nil
GameState.TransitionFrom = nil
GameState.TransitionTime = 0
GameState.DefaultTransitionDuration = 1.0
GameState.TransitionDuration = GameState.DefaultTransitionDuration
GameState.transitioning = false
GameState.TransitionDirection = 1 -- 1 = fade out, -1 = fade in
GameState.PendingData = nil
GameState.QueuedState = nil
GameState.QueuedData = nil
GameState.TransitionContext = nil

local TransitionBlockedEvents = {
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
local GetTransitionAlpha = Easing.GetTransitionAlpha

local function ParseDuration(value)
	if type(value) == "number" and value >= 0 then
		return value
	end
end

local function ResolveStateDurationPreference(state, direction, OtherStateName)
	if not state then
		return nil
	end

	local handler = state.getTransitionDuration
	if handler then
		local value = handler(state, direction, OtherStateName)
		local parsed = ParseDuration(value)
		if parsed ~= nil then
			return parsed
		end
	end

	if direction == "in" then
		local value = ParseDuration(state.transitionDurationIn)
		if value ~= nil then
			return value
		end
	elseif direction == "out" then
		local value = ParseDuration(state.transitionDurationOut)
		if value ~= nil then
			return value
		end
	end

	return ParseDuration(state.transitionDuration)
end

local function ResolveTransitionDuration(self, FromName, ToName)
	local ToState = ToName and self.states[ToName]
	local FromState = FromName and self.states[FromName]

	local duration = ResolveStateDurationPreference(ToState, "in", FromName)
		or ResolveStateDurationPreference(FromState, "out", ToName)

	if duration ~= nil then
		return duration
	end

	return self.DefaultTransitionDuration or 0
end

local function UpdateTransitionContext(self, data)
	local context = self.TransitionContext
	if not context then
		context = {}
		self.TransitionContext = context
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
	context.duration = data.duration or self.TransitionDuration or 0
	context.time = data.time or (progress * context.duration)

	if context.direction ~= 0 and context.transitioning then
		context.alpha = GetTransitionAlpha(progress, context.direction)
	else
		context.alpha = 0
	end

	context.from = data.from
	context.to = data.to

	return context
end

local function GetCurrentState(self)
	return self.states[self.current]
end

local function CallCurrentState(self, MethodName, ...)
	local state = GetCurrentState(self)
	if state then
		local handler = state[MethodName]
		if handler then
			return handler(state, ...)
		end
	end
end

function GameState:switch(StateName, data)
	if self.transitioning then
		self.QueuedState = StateName
		self.QueuedData = data
		return
	end

	self.TransitionDuration = ResolveTransitionDuration(self, self.current, StateName)

	if self.current == nil or self.TransitionDuration <= 0 then
		local previous = GetCurrentState(self)
		if previous and previous.leave then
			previous:leave()
		end

		self.current = StateName
		self.TransitionFrom = nil
		self.TransitionTime = 0
		self.transitioning = false
		self.TransitionDirection = -1
		self.PendingData = nil

		local NextState = GetCurrentState(self)
		if NextState and NextState.enter then
			NextState:enter(data)
		end

		if NextState and NextState.onTransitionEnd then
			NextState:onTransitionEnd("in", nil)
		end

		UpdateTransitionContext(self, {
			transitioning = false,
			direction = 0,
			progress = 1,
			duration = self.TransitionDuration,
			time = 0,
			from = nil,
			to = self.current,
		})

		return
	end

	self.next = StateName
	self.PendingData = data
	self.transitioning = true
	self.TransitionDirection = 1
	self.TransitionTime = 0
	self.TransitionFrom = self.current

	local CurrentState = GetCurrentState(self)
	if CurrentState and CurrentState.onTransitionStart then
		CurrentState:onTransitionStart("out", StateName)
	end

	UpdateTransitionContext(self, {
		transitioning = true,
		direction = 1,
		progress = 0,
		duration = self.TransitionDuration,
		time = 0,
		from = self.current,
		to = self.next,
	})
end

function GameState:update(dt)
	if self.transitioning then
		self.TransitionTime = math.min(1, self.TransitionTime + dt / self.TransitionDuration)

		local context

		if self.TransitionDirection == 1 and self.TransitionTime >= 1 then
			local PreviousState = GetCurrentState(self)
			if PreviousState and PreviousState.onTransitionEnd then
				PreviousState:onTransitionEnd("out", self.next)
			end
			if PreviousState and PreviousState.leave then
				PreviousState:leave()
			end

			self.current = self.next
			self.next = nil
			self.TransitionDirection = -1
			self.TransitionTime = 0

			local NextState = GetCurrentState(self)
			if NextState and NextState.enter then
				NextState:enter(self.PendingData)
			end
			if NextState and NextState.onTransitionStart then
				NextState:onTransitionStart("in", self.TransitionFrom)
			end

			self.PendingData = nil
			context = UpdateTransitionContext(self, {
				transitioning = true,
				direction = self.TransitionDirection,
				progress = self.TransitionTime,
				duration = self.TransitionDuration,
				time = 0,
				from = self.TransitionFrom,
				to = self.current,
			})
		elseif self.TransitionDirection == -1 and self.TransitionTime >= 1 then
			local ActiveState = GetCurrentState(self)
			if ActiveState and ActiveState.onTransitionEnd then
				ActiveState:onTransitionEnd("in", self.TransitionFrom)
			end

			self.transitioning = false
			self.TransitionTime = 0
			self.TransitionFrom = nil

			if self.QueuedState then
				local QueuedState, QueuedData = self.QueuedState, self.QueuedData
				self.QueuedState, self.QueuedData = nil, nil
				self:switch(QueuedState, QueuedData)
			end
			context = UpdateTransitionContext(self, {
				transitioning = false,
				direction = self.TransitionDirection,
				progress = self.TransitionTime,
				duration = self.TransitionDuration,
				time = 0,
				from = nil,
				to = self.current,
			})
		else
			local FromName, ToName
			if self.TransitionDirection == 1 then
				FromName = self.current
				ToName = self.next
			else
				FromName = self.TransitionFrom
				ToName = self.current
			end

			context = UpdateTransitionContext(self, {
				transitioning = true,
				direction = self.TransitionDirection,
				progress = self.TransitionTime,
				duration = self.TransitionDuration,
				time = self.TransitionTime * self.TransitionDuration,
				from = FromName,
				to = ToName,
			})
		end

		return CallCurrentState(self, "TransitionUpdate", dt, self.TransitionDirection, self.TransitionTime, context)
	end

	UpdateTransitionContext(self, {
		transitioning = false,
		direction = 0,
		progress = 1,
		duration = self.TransitionDuration,
		time = 0,
		from = nil,
		to = self.current,
	})

	return CallCurrentState(self, "update", dt)
end

function GameState:draw()
	CallCurrentState(self, "draw")

	if not self.transitioning then
		return
	end

	local context = self.TransitionContext
	local progress = math.min(math.max(self.TransitionTime, 0), 1)
	local alpha = (context and context.alpha) or GetTransitionAlpha(progress, self.TransitionDirection)

	if alpha <= 0 then
		return
	end

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.rectangle("fill", 0, 0, width, height)
	love.graphics.setColor(1, 1, 1, 1)
end

function GameState:dispatch(EventName, ...)
	if self.transitioning and TransitionBlockedEvents[EventName] then
		return
	end

	return CallCurrentState(self, EventName, ...)
end

return GameState
