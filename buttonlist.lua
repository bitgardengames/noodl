local UI = require("ui")

local ButtonList = {}
ButtonList.__index = ButtonList

function ButtonList.new()
    return setmetatable({buttons = {}}, ButtonList)
end

function ButtonList:reset(definitions)
    self.buttons = {}

    for index, definition in ipairs(definitions or {}) do
        local button = {}
        for key, value in pairs(definition) do
            button[key] = value
        end

        button.id = button.id or button.action or button.text or button.label or ("button" .. index)
        button.text = button.text or button.label or button.id
        button.w = button.w or UI.spacing.buttonWidth
        button.h = button.h or UI.spacing.buttonHeight
        button.x = button.x or 0
        button.y = button.y or 0

        self.buttons[#self.buttons + 1] = button
    end

    return self.buttons
end

function ButtonList:iter()
    return ipairs(self.buttons)
end

function ButtonList:syncUI()
    for _, button in ipairs(self.buttons) do
        UI.registerButton(button.id, button.x, button.y, button.w, button.h, button.text)
    end
end

function ButtonList:draw()
    self:syncUI()
    for _, button in ipairs(self.buttons) do
        UI.drawButton(button.id)
    end
end

function ButtonList:updateHover(mx, my)
    local hovered
    for _, button in ipairs(self.buttons) do
        button.hovered = UI.isHovered(button.x, button.y, button.w, button.h, mx, my)
        if button.hovered then
            hovered = button
        end
    end
    return hovered
end

function ButtonList:mousepressed(x, y, button)
    return UI:mousepressed(x, y, button)
end

function ButtonList:mousereleased(x, y, button)
    local id = UI:mousereleased(x, y, button)
    if not id then return end

    for _, entry in ipairs(self.buttons) do
        if entry.id == id then
            return entry.action or entry.id, entry
        end
    end
end

return ButtonList
