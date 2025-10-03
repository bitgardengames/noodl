local InputMode = {
    lastDevice = nil,
    mouseLastUsedTime = nil,
}

local MOUSE_ACTIVE_TIMEOUT = 2.5

local function getTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end

    return os.clock and os.clock() or 0
end

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

function InputMode:isMouseSupported()
    return isMouseSupported()
end

function InputMode:noteMouse()
    if isMouseSupported() then
        self.lastDevice = "mouse"
        self.mouseLastUsedTime = getTime()
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
    if not isMouseSupported() then
        return false
    end

    if self.lastDevice == "mouse" then
        return true
    end

    if not self.mouseLastUsedTime then
        return false
    end

    local elapsed = getTime() - self.mouseLastUsedTime
    return elapsed <= MOUSE_ACTIVE_TIMEOUT
end

return InputMode
