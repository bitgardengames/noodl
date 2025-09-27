local Audio = require("audio")
local Settings = require("settings")
local Localization = require("localization")

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
    { textKey = "pause.resume",       id = "pauseResume", action = "resume" },
    { id = "pauseToggleMusic", action = toggleMusic },
    { id = "pauseToggleSFX",   action = toggleSFX },
    { textKey = "pause.quit", id = "pauseQuit",   action = "menu" },
}

local buttonList = ButtonList.new()

local function getToggleLabel(id)
    if id == "pauseToggleMusic" then
        local state = Settings.muteMusic and Localization:get("common.off") or Localization:get("common.on")
        return Localization:get("pause.toggle_music", { state = state })
    elseif id == "pauseToggleSFX" then
        local state = Settings.muteSFX and Localization:get("common.off") or Localization:get("common.on")
        return Localization:get("pause.toggle_sfx", { state = state })
    end

    return nil
end

function PauseMenu:updateButtonLabels()
    for _, button in buttonList:iter() do
        if button.textKey then
            button.text = Localization:get(button.textKey)
        end
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
            baseText = btn.textKey and Localization:get(btn.textKey) or "",
            text = getToggleLabel(btn.id) or baseText,
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
    love.graphics.printf(Localization:get("pause.title"), 0, 120, screenWidth, "center")

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

local function handleActionResult(action, entry)
    if type(action) == "function" then
        action()
        if entry then
            return nil, true
        end
        return nil, true
    end

    return action, entry and getToggleLabel(entry.id) ~= nil
end

function PauseMenu:activateFocused()
    local action, entry = buttonList:activateFocused()
    if not entry and not action then return nil end

    local resolved, requiresRefresh = handleActionResult(action, entry)
    if requiresRefresh then
        self:updateButtonLabels()
    end

    return resolved
end

function PauseMenu:keypressed(key)
    if key == "up" or key == "left" then
        buttonList:moveFocus(-1)
    elseif key == "down" or key == "right" then
        buttonList:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
        return self:activateFocused()
    elseif key == "escape" or key == "backspace" then
        return "resume"
    end
end

function PauseMenu:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        return self:activateFocused()
    elseif button == "b" then
        return "resume"
    end
end

PauseMenu.joystickpressed = PauseMenu.gamepadpressed

return PauseMenu
