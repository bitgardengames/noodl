local InputMode = {
	LastDevice = nil,
}

local function IsMouseSupported()
	local supported = love.mouse.isCursorSupported()

	if supported == nil then
		supported = true
	end

	return supported
end

function InputMode:NoteMouse()
	if IsMouseSupported() then
		self.LastDevice = "mouse"
	end
end

function InputMode:NoteKeyboard()
	self.LastDevice = "keyboard"
end

function InputMode:NoteGamepad()
	self.LastDevice = "gamepad"
end

function InputMode:NoteGamepadAxis(value)
	if math.abs(value or 0) > 0.25 then
		self:NoteGamepad()
	end
end

function InputMode:IsMouseActive()
	return self.LastDevice == "mouse" and IsMouseSupported()
end

return InputMode
