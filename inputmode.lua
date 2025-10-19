local InputMode = {
    lastDevice = nil,
}

local function isMouseSupported()
    local supported = love.mouse.isCursorSupported()

    if supported == nil then
        supported = true
    end

    return supported
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
