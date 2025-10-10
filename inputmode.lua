local InputMode = {
	lastDevice = nil,
}

local function isMouseSupported()
	if not love or not love.mouse then
		return false
	end

	local supported = true
	if love.mouse.isCursorSupported then
		supported = love.mouse.isCursorSupported()
	end

	if supported == nil then
		supported = true
	end

	return supported and love.mouse.setVisible ~= nil
end

function InputMode:noteMouse()
	if isMouseSupported() then
		self.lastDevice = "mouse"
	end
end

function InputMode:noteKeyboard()
	self.lastDevice = "keyboard"
end

function InputMode:noteGamepad()
	self.lastDevice = "gamepad"
end

function InputMode:noteGamepadAxis(value)
	if math.abs(value or 0) > 0.25 then
		self:noteGamepad()
	end
end

function InputMode:isMouseActive()
	return self.lastDevice == "mouse" and isMouseSupported()
end

return InputMode
