local Audio = require("audio")
local Settings = require("settings")
local Localization = require("localization")
local UI = require("ui")
local Theme = require("theme")

local PauseMenu = {}

local alpha = 0
local fadeSpeed = 4

local ButtonList = require("buttonlist")
local panelBounds = { x = 0, y = 0, w = 0, h = 0 }

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
    UI.clearButtons()

    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    local buttonWidth = UI.spacing.buttonWidth
    local buttonHeight = UI.spacing.buttonHeight
    local spacing = UI.spacing.buttonSpacing
    local count = #baseButtons

    local titleHeight = UI.fonts.subtitle:getHeight()
    local headerSpacing = UI.spacing.sectionSpacing * 0.5
    local buttonArea = count * buttonHeight + math.max(0, count - 1) * spacing
    local panelPadding = UI.spacing.panelPadding
    local panelWidth = buttonWidth + panelPadding * 2
    local panelHeight = panelPadding + titleHeight + headerSpacing + buttonArea + panelPadding

    local panelX = centerX - panelWidth / 2
    local panelY = centerY - panelHeight / 2

    panelBounds = { x = panelX, y = panelY, w = panelWidth, h = panelHeight }

    local defs = {}

    local startY = panelY + panelPadding + titleHeight + headerSpacing

    for index, btn in ipairs(baseButtons) do
        defs[#defs + 1] = {
            id = btn.id,
            baseText = btn.textKey and Localization:get(btn.textKey) or "",
            text = getToggleLabel(btn.id) or baseText,
            action = btn.action,
            x = panelX + panelPadding,
            y = startY + (index - 1) * (buttonHeight + spacing),
            w = buttonWidth,
            h = buttonHeight,
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

    love.graphics.setColor(0, 0, 0, 0.55 * alpha)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local panel = panelBounds
    if panel and panel.w > 0 and panel.h > 0 then
        local panelFill = { Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], (Theme.panelColor[4] or 1) * alpha }
        local panelBorder = { Theme.panelBorder[1], Theme.panelBorder[2], Theme.panelBorder[3], (Theme.panelBorder[4] or 1) * alpha }

        UI.drawPanel(panel.x, panel.y, panel.w, panel.h, {
            fill = panelFill,
            borderColor = panelBorder,
            shadowAlpha = alpha,
        })

        UI.drawLabel(Localization:get("pause.title"), panel.x, panel.y + UI.spacing.panelPadding, panel.w, "center", {
            fontKey = "subtitle",
            alpha = alpha,
        })
    end

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
