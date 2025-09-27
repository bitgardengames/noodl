local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")

local SettingsScreen = {}

local options = {
    { type = "action", labelKey = "settings.toggle_fullscreen", action = function()
        love.window.setFullscreen(not love.window.getFullscreen())
        Settings:save()
    end },
    { type = "toggle", labelKey = "settings.toggle_music", toggle = "muteMusic" },
    { type = "toggle", labelKey = "settings.toggle_sfx", toggle = "muteSFX" },
    { type = "slider", labelKey = "settings.music_volume", slider = "musicVolume" },
    { type = "slider", labelKey = "settings.sfx_volume", slider = "sfxVolume" },
    { type = "cycle", labelKey = "settings.language", setting = "language" },
    { type = "action", labelKey = "settings.back", action = "menu" }
}

local buttons = {}
local hoveredIndex = nil
local sliderDragging = nil
local focusedIndex = 1
local panelBounds = nil

function SettingsScreen:enter()
    Screen:update()
    local sw, sh = Screen:get()
    local safe = UI.layout.safeMargin
    local centerX = sw / 2
    local totalHeight = (#options) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing) - UI.spacing.buttonSpacing
    local buttonWidth = math.min(420, sw - safe.x * 2)
    local alignedTop = safe.y + UI.fonts.title:getHeight() + 48
    local centeredTop = sh / 2 - totalHeight / 2
    local startY = math.max(alignedTop, centeredTop)

    -- reset UI.buttons so we don’t keep stale hitboxes
    UI.clearButtons()
    buttons = {}

    for i, opt in ipairs(options) do
        local x = centerX - buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)
        local w = buttonWidth
        local h = UI.spacing.buttonHeight
        local id = "settingsOption" .. i

        table.insert(buttons, {
            id = id,
            x = x,
            y = y,
            w = w,
            h = h,
            option = opt,
            hovered = false,
        })

        -- register for clickable items (skip sliders, those are custom)
        if opt.type ~= "slider" then
            UI.registerButton(id, x, y, w, h, Localization:get(opt.labelKey))
        end
    end

    if #buttons == 0 then
        focusedIndex = nil
    else
        if not focusedIndex or focusedIndex > #buttons then
            focusedIndex = 1
        end
    end

    self:updateFocusVisuals()

    if #buttons > 0 then
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge

        for _, btn in ipairs(buttons) do
            minX = math.min(minX, btn.x)
            minY = math.min(minY, btn.y)
            maxX = math.max(maxX, btn.x + btn.w)
            maxY = math.max(maxY, btn.y + btn.h)
        end

        local padding = UI.spacing.panelPadding * 1.5
        panelBounds = {
            x = minX - padding,
            y = minY - padding,
            w = (maxX - minX) + padding * 2,
            h = (maxY - minY) + padding * 2,
        }
    else
        panelBounds = nil
    end
end

function SettingsScreen:leave()
    sliderDragging = nil
end

function SettingsScreen:update(dt)
    local mx, my = love.mouse.getPosition()
    hoveredIndex = nil

    for i, btn in ipairs(buttons) do
        local opt = btn.option
        btn.hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
        if btn.hovered then
            hoveredIndex = i
        end

        if sliderDragging and opt.slider == sliderDragging then
            local padding = UI.spacing.panelPadding
            local trackX = btn.x + padding
            local trackW = math.max(1, btn.w - padding * 2)
            local rel = (mx - trackX) / trackW
            Settings[sliderDragging] = math.min(1, math.max(0, rel))
            Settings:save()
            Audio:applyVolumes()
        end
    end

    if hoveredIndex then
        self:setFocus(hoveredIndex)
    else
        self:updateFocusVisuals()
    end
end

function SettingsScreen:draw()
    local sw, sh = Screen:get()
    local safe = UI.layout.safeMargin
    love.graphics.clear(Theme.bgColor)

    UI.printf(Localization:get("settings.title"), safe.x, safe.y, sw - safe.x * 2, "center", { font = "title" })

    if panelBounds then
        UI.drawPanel(panelBounds.x, panelBounds.y, panelBounds.w, panelBounds.h, {
            radius = UI.spacing.buttonRadius + 6,
        })
    end

    for index, btn in ipairs(buttons) do
        local opt = btn.option
        local label = Localization:get(opt.labelKey)
        local isFocused = (focusedIndex == index)

        if opt.type == "toggle" and opt.toggle then
            local isMuted = Settings[opt.toggle]
            local state = isMuted and Localization:get("common.off") or Localization:get("common.on")
            label = string.format("%s: %s", label, state)
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.setButtonTextAlign(btn.id, "left", 28)
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)

        elseif opt.type == "slider" and opt.slider then
            UI.drawPanel(btn.x, btn.y, btn.w, btn.h, {
                color = Theme.panelColor,
                borderColor = Theme.panelBorder,
                shadowOffset = UI.spacing.panelShadow,
                radius = UI.spacing.buttonRadius,
            })

            local padding = UI.spacing.panelPadding
            local labelY = btn.y + padding - 4
            local value = Settings[opt.slider]
            local percentText = string.format("%.0f%%", value * 100)

            UI.printf(label, btn.x + padding, labelY, btn.w - padding * 2 - 80, "left", { font = "body" })
            UI.printf(percentText, btn.x + btn.w - padding - 80, labelY, 80, "right", { font = "body", color = Theme.progressColor })

            local trackX = btn.x + padding
            local trackW = math.max(0, btn.w - padding * 2)
            local trackY = btn.y + btn.h - padding - 10
            local trackH = 6

            local shadowColor = Theme.shadowColor or {0, 0, 0, 0.4}
            love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], 0.4)
            love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, 3, 3)

            love.graphics.setColor(Theme.progressColor)
            love.graphics.rectangle("fill", trackX, trackY, trackW * value, trackH, 3, 3)

            local handleX = trackX + trackW * value
            local handleY = trackY + trackH / 2
            love.graphics.setColor(Theme.textColor)
            love.graphics.circle("fill", handleX, handleY, 10)
            love.graphics.setColor(Theme.borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", handleX, handleY, 10)
            love.graphics.setLineWidth(1)

            if isFocused then
                local highlight = Theme.highlightColor or {1, 1, 1, 0.2}
                love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.2) + 0.1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", btn.x - 6, btn.y - 6, btn.w + 12, btn.h + 12, UI.spacing.buttonRadius + 4, UI.spacing.buttonRadius + 4)
                love.graphics.setLineWidth(1)
            end

        elseif opt.type == "cycle" and opt.setting == "language" then
            local current = Settings.language or Localization:getCurrentLanguage()
            local state = Localization:getLanguageName(current)
            label = string.format("%s: %s", label, state)
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.setButtonTextAlign(btn.id, "left", 28)
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)

        else
            -- plain button
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            if opt.action == "menu" then
                UI.setButtonTextAlign(btn.id, "center", 0)
            else
                UI.setButtonTextAlign(btn.id, "left", 28)
            end
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)
        end
    end
end

function SettingsScreen:updateFocusVisuals()
    for index, btn in ipairs(buttons) do
        local focused = (focusedIndex == index)
        btn.focused = focused
        UI.setButtonFocus(btn.id, focused)
    end
end

function SettingsScreen:setFocus(index)
    if #buttons == 0 then
        focusedIndex = nil
        return
    end

    local count = #buttons
    index = math.max(1, math.min(index or focusedIndex or 1, count))
    focusedIndex = index
    self:updateFocusVisuals()
end

function SettingsScreen:moveFocus(delta)
    if not focusedIndex or #buttons == 0 then return end

    local count = #buttons
    local index = ((focusedIndex - 1 + delta) % count) + 1
    self:setFocus(index)
end

function SettingsScreen:getFocusedOption()
    if not focusedIndex then return nil end
    return buttons[focusedIndex]
end

function SettingsScreen:adjustFocused(delta)
    local btn = self:getFocusedOption()
    if not btn or delta == 0 then return end

    local opt = btn.option
    if opt.type == "slider" and opt.slider then
        local step = 0.05 * delta
        local value = Settings[opt.slider] or 0
        local newValue = math.min(1, math.max(0, value + step))
        if math.abs(newValue - value) > 1e-4 then
            Settings[opt.slider] = newValue
            Settings:save()
            Audio:applyVolumes()
        end
    elseif opt.type == "cycle" and opt.setting == "language" then
        local prevIndex = focusedIndex
        local nextLang = Localization:cycleLanguage(Settings.language)
        Settings.language = nextLang
        Settings:save()
        Localization:setLanguage(nextLang)
        Audio:playSound("click")
        self:enter()
        self:setFocus(prevIndex)
    end
end

function SettingsScreen:activateFocused()
    local btn = self:getFocusedOption()
    if not btn then return nil end

    local opt = btn.option
    if opt.type == "toggle" and opt.toggle then
        Settings[opt.toggle] = not Settings[opt.toggle]
        Settings:save()
        Audio:applyVolumes()
        Audio:playSound("click")
        return nil
    elseif opt.type == "action" then
        Audio:playSound("click")
        if type(opt.action) == "function" then
            opt.action()
            return nil
        else
            return opt.action
        end
    elseif opt.type == "cycle" and opt.setting == "language" then
        local prevIndex = focusedIndex
        local nextLang = Localization:cycleLanguage(Settings.language)
        Settings.language = nextLang
        Settings:save()
        Localization:setLanguage(nextLang)
        Audio:playSound("click")
        self:enter()
        self:setFocus(prevIndex)
    end

    return nil
end

function SettingsScreen:mousepressed(x, y, button)
    local id = UI:mousepressed(x, y, button)

    for i, btn in ipairs(buttons) do
        local opt = btn.option

        if btn.id and btn.id == id then
            self:setFocus(i)

            if opt.type == "cycle" and opt.setting == "language" then
                local prevIndex = i
                local nextLang = Localization:cycleLanguage(Settings.language)
                Settings.language = nextLang
                Settings:save()
                Localization:setLanguage(nextLang)
                self:enter()
                self:setFocus(prevIndex)
                return nil
            elseif opt.action then
                if type(opt.action) == "function" then
                    opt.action()
                else
                    return opt.action
                end
            elseif opt.toggle then
                Settings[opt.toggle] = not Settings[opt.toggle]
                Settings:save()
                Audio:applyVolumes()
            end
        end

        if opt.slider then
            local padding = UI.spacing.panelPadding
            local trackX = btn.x + padding
            local trackW = math.max(1, btn.w - padding * 2)
            local trackY = btn.y + btn.h - padding - 10
            local trackH = 6
            local hitRadius = 12
            local hoveredSlider = x >= trackX - hitRadius and x <= trackX + trackW + hitRadius and
                                  y >= trackY - hitRadius and y <= trackY + trackH + hitRadius
            if hoveredSlider then
                sliderDragging = opt.slider
                local rel = (x - trackX) / trackW
                Settings[sliderDragging] = math.min(1, math.max(0, rel))
                Settings:save()
                Audio:applyVolumes()
                self:setFocus(i)
            end
        end
    end
end

function SettingsScreen:mousereleased(x, y, button)
    UI:mousereleased(x, y, button)
    sliderDragging = nil
end

function SettingsScreen:gamepadpressed(_, button)
    if button == "dpup" then
        self:moveFocus(-1)
    elseif button == "dpdown" then
        self:moveFocus(1)
    elseif button == "dpleft" then
        self:adjustFocused(-1)
    elseif button == "dpright" then
        self:adjustFocused(1)
    elseif button == "a" or button == "start" then
        return self:activateFocused()
    elseif button == "b" then
        return "menu"
    end
end

SettingsScreen.joystickpressed = SettingsScreen.gamepadpressed

return SettingsScreen
