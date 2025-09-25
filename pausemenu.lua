local Audio = require("audio")
local Settings = require("settings")

local PauseMenu = {}

local fontLarge = love.graphics.newFont(32)
local alpha = 0
local fadeSpeed = 4

local ButtonList = require("buttonlist")

local function toggleMusic()
    Audio:playSound("click")
    Settings.muteMusic = not Settings.muteMusic
    Settings:save()
    Audio:applyVolumes()
end

local function toggleSFX()
    Audio:playSound("click")
    Settings.muteSFX = not Settings.muteSFX
    Settings:save()
    Audio:applyVolumes()
end

local baseButtons = {
    { text = "Resume",       id = "pauseResume", action = "resume" },
    { text = "",             id = "pauseToggleMusic", action = toggleMusic },
    { text = "",             id = "pauseToggleSFX",   action = toggleSFX },
    { text = "Quit to Menu", id = "pauseQuit",   action = "menu" },
}

local buttonList = ButtonList.new()

local function getToggleLabel(id)
    if id == "pauseToggleMusic" then
        return "Music: " .. (Settings.muteMusic and "Off" or "On")
    elseif id == "pauseToggleSFX" then
        return "Sound FX: " .. (Settings.muteSFX and "Off" or "On")
    end

    return nil
end

function PauseMenu:updateButtonLabels()
    for _, button in buttonList:iter() do
        local label = getToggleLabel(button.id)
        if label then
            button.text = label
        end
    end
end

function PauseMenu:load(screenWidth, screenHeight)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    local spacing = 60

    local defs = {}

    for i, btn in ipairs(baseButtons) do
        defs[#defs + 1] = {
            id = btn.id,
            text = getToggleLabel(btn.id) or btn.text,
            action = btn.action,
            x = centerX - 100,
            y = centerY - 40 + (i - 1) * spacing,
            w = 200,
            h = 40,
        }
    end

    buttonList:reset(defs)
    self:updateButtonLabels()
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
        buttonList:updateHover(mx, my)
    end

    self:updateButtonLabels()
end

function PauseMenu:draw(screenWidth, screenHeight)
    if alpha <= 0 then return end

    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("Paused", 0, 120, screenWidth, "center")

    buttonList:draw()
end

function PauseMenu:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function PauseMenu:mousereleased(x, y, button)
    local action, entry = buttonList:mousereleased(x, y, button)

    if type(action) == "function" then
        action()
        self:updateButtonLabels()
        return nil
    end

    if entry and getToggleLabel(entry.id) then
        self:updateButtonLabels()
    end

    return action
end

function PauseMenu:getAlpha()
    return alpha
end

return PauseMenu
