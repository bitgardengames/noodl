local PauseMenu = {}

local fontLarge = love.graphics.newFont(32)
local alpha = 0
local fadeSpeed = 4

local UI = require("ui")

local buttonLayout = {
    { text = "Resume",       id = "pauseResume", action = "resume" },
    { text = "Quit to Menu", id = "pauseQuit",   action = "menu" }
}

function PauseMenu:load(screenWidth, screenHeight)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    local spacing = 60

    for i, btn in ipairs(buttonLayout) do
        btn.x = centerX - 100
        btn.y = centerY - 40 + (i - 1) * spacing
        btn.w = 200
        btn.h = 40
    end

    alpha = 0
end

function PauseMenu:update(dt, isPaused)
    if isPaused then
        alpha = math.min(alpha + dt * fadeSpeed, 1)
    else
        alpha = math.max(alpha - dt * fadeSpeed, 0)
    end

    if alpha > 0 then
        local mx, my = love.mouse.getPosition()
        for _, btn in ipairs(buttonLayout) do
            btn.hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
        end
    end
end

function PauseMenu:draw(screenWidth, screenHeight)
    if alpha <= 0 then return end

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("Paused", 0, 120, screenWidth, "center")

    -- Buttons
    for _, btn in ipairs(buttonLayout) do
        -- Register first (this sets position, size, text each frame)
        UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
        -- Then draw by ID
        UI.drawButton(btn.id)
    end
end

function PauseMenu:mousepressed(x, y, button)
    UI:mousepressed(x, y, button)
end

function PauseMenu:mousereleased(x, y, button)
    local id = UI:mousereleased(x, y, button)

    if id then
        for _, btn in ipairs(buttonLayout) do
            if btn.id == id then
                return btn.action
            end
        end
    end
end

function PauseMenu:getAlpha()
    return alpha
end

return PauseMenu