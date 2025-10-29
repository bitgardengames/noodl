local UI = require("ui")

local abs = math.abs

local Screen = {
	width = nil,
	height = nil,
	smoothingSpeed = 12,
	snapThreshold = 0,
}

local function updateCenter(self)
	self.cx = self.width * 0.5
	self.cy = self.height * 0.5
end

local function shouldSnapImmediately(self, dt, instant)
	if instant == true then
		return true
	end

	if self.width == nil or self.height == nil then
		return true
	end

	if dt == nil or dt <= 0 then
		return true
	end

	if self.smoothingSpeed <= 0 then
		return true
	end

	return false
end

function Screen:update(dt, instant)
	local actualWidth, actualHeight = love.graphics.getDimensions()

	if UI and UI.refreshLayout then
		UI.refreshLayout(actualWidth, actualHeight)
	end

	if shouldSnapImmediately(self, dt, instant) then
		self.width, self.height = actualWidth, actualHeight
		updateCenter(self)
		return self.width, self.height
	end

	local deltaWidth = actualWidth - self.width
	local deltaHeight = actualHeight - self.height
	local snapThreshold = self.snapThreshold

	if snapThreshold and snapThreshold > 0 then
		if abs(deltaWidth) > snapThreshold or abs(deltaHeight) > snapThreshold then
			self.width, self.height = actualWidth, actualHeight
			updateCenter(self)
			return self.width, self.height
		end
	end

	local alpha = 1 - math.exp(-self.smoothingSpeed * dt)
	self.width = self.width + deltaWidth * alpha
	self.height = self.height + deltaHeight * alpha

	updateCenter(self)

	return self.width, self.height
end

function Screen:get()
	return self.width, self.height
end

return Screen
