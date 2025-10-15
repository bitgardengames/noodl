local Timer = {}
Timer.__index = Timer

local function SanitizeDuration(duration)
	if duration == nil then
		return 0
	end
	if duration < 0 then
		return 0
	end
	return duration
end

function Timer.new(duration, options)
	options = options or {}

	local instance = {
		duration = SanitizeDuration(duration or 0),
		elapsed = 0,
		loop = options.loop or false,
		paused = options.paused or false,
		active = options.autoStart or false,
	}

	if instance.active and instance.paused then
		instance.paused = false
	end

	return setmetatable(instance, Timer)
end

function Timer:clone()
	local copy = Timer.new(self.duration, {
		loop = self.loop,
		paused = self.paused,
		AutoStart = self.active,
	})
	copy.elapsed = self.elapsed
	return copy
end

function Timer:SetDuration(duration)
	self.duration = SanitizeDuration(duration or 0)
	if self.elapsed > self.duration then
		self.elapsed = self.duration
	end
	return self
end

function Timer:start(duration)
	if duration ~= nil then
		self:SetDuration(duration)
	end

	self.elapsed = 0
	self.active = true
	self.paused = false

	if self.duration <= 0 then
		self.active = false
	end
	return self
end

function Timer:restart(duration)
	return self:start(duration)
end

function Timer:stop()
	self.active = false
	return self
end

function Timer:reset()
	self.elapsed = 0
	self.paused = false
	return self
end

function Timer:SetLoop(loop)
	self.loop = not not loop
	return self
end

function Timer:SetPaused(paused)
	self.paused = not not paused
	return self
end

function Timer:IsPaused()
	return self.paused
end

function Timer:IsActive()
	return self.active and not self.paused
end

function Timer:GetElapsed()
	return self.elapsed
end

function Timer:GetDuration()
	return self.duration
end

function Timer:GetRemaining()
	if self.duration <= 0 then
		return 0
	end
	local remaining = self.duration - self.elapsed
	if remaining < 0 then
		remaining = 0
	end
	return remaining
end

function Timer:GetProgress()
	if self.duration <= 0 then
		return 1
	end
	local progress = self.elapsed / self.duration
	if progress < 0 then
		return 0
	elseif progress > 1 then
		return 1
	end
	return progress
end

function Timer:IsFinished()
	if self.duration <= 0 then
		return not self.active
	end

	return (not self.active) and (self.elapsed >= self.duration)
end

function Timer:update(dt)
	if not self.active or self.paused or dt == nil or dt <= 0 then
		return false
	end

	self.elapsed = self.elapsed + dt

	if self.duration > 0 and self.elapsed >= self.duration then
		if self.loop then
			self.elapsed = self.elapsed % self.duration
			return true
		end

		self.elapsed = self.duration
		self.active = false
		return true
	end

	return false
end

return Timer
