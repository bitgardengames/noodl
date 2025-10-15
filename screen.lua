local UI = require("ui")

local Screen = {
	width = nil,
	height = nil,
	TargetWidth = nil,
	TargetHeight = nil,
	SmoothingSpeed = 12,
	SnapThreshold = 0,
}

local function UpdateCenter(self)
	self.cx = self.width * 0.5
	self.cy = self.height * 0.5
end

local function ShouldSnapImmediately(self, dt, instant)
	if instant == true then
		return true
	end

	if self.width == nil or self.height == nil then
		return true
	end

	if dt == nil or dt <= 0 then
		return true
	end

	if self.SmoothingSpeed <= 0 then
		return true
	end

	return false
end

function Screen:update(dt, instant)
	local ActualWidth, ActualHeight = love.graphics.getDimensions()
	self.TargetWidth, self.TargetHeight = ActualWidth, ActualHeight

	if UI and UI.RefreshLayout then
		UI.RefreshLayout(ActualWidth, ActualHeight)
	end

	if ShouldSnapImmediately(self, dt, instant) then
		self.width, self.height = ActualWidth, ActualHeight
		UpdateCenter(self)
		return self.width, self.height
	end

	local DeltaWidth = ActualWidth - self.width
	local DeltaHeight = ActualHeight - self.height
	local SnapThreshold = self.SnapThreshold

	if SnapThreshold and SnapThreshold > 0 then
		if math.abs(DeltaWidth) > SnapThreshold or math.abs(DeltaHeight) > SnapThreshold then
			self.width, self.height = ActualWidth, ActualHeight
			UpdateCenter(self)
			return self.width, self.height
		end
	end

	local alpha = 1 - math.exp(-self.SmoothingSpeed * dt)
	self.width = self.width + DeltaWidth * alpha
	self.height = self.height + DeltaHeight * alpha

	UpdateCenter(self)

	return self.width, self.height
end

function Screen:get()
	return self.width, self.height
end

function Screen:GetWidth()
	return self.width
end

function Screen:GetHeight()
	return self.height
end

return Screen
