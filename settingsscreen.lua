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

function SettingsScreen:enter()
    Screen:update()
    local sw, sh = Screen:get()
    local centerX = sw / 2
    local totalHeight = (#options) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing) - UI.spacing.buttonSpacing
    local startY = sh / 2 - totalHeight / 2

    -- reset UI.buttons so we don’t keep stale hitboxes
    UI.clearButtons()
    buttons = {}

    for i, opt in ipairs(options) do
        local x = centerX - UI.spacing.buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)
        local w = UI.spacing.buttonWidth
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
            local rel = (mx - btn.x) / btn.w
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
    local sw, _ = Screen:get()
    love.graphics.clear(Theme.bgColor)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(Localization:get("settings.title"), 0, 80, sw, "center")

    love.graphics.setFont(UI.fonts.body)

    for index, btn in ipairs(buttons) do
        local opt = btn.option
        local label = Localization:get(opt.labelKey)
        local isFocused = (focusedIndex == index)

        if opt.type == "toggle" and opt.toggle then
            local isMuted = Settings[opt.toggle]
            local state = isMuted and Localization:get("common.off") or Localization:get("common.on")
            label = string.format("%s: %s", label, state)
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)

        elseif opt.type == "slider" and opt.slider then
            -- slider UI
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(label, btn.x, btn.y - 20, btn.w, "center")

            local trackY = btn.y + btn.h / 2 - 4
            local trackH = 8

            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", btn.x, trackY, btn.w, trackH, 4, 4)

            local value = Settings[opt.slider]
            love.graphics.setColor(0.6, 0.8, 1.0)
            love.graphics.rectangle("fill", btn.x, trackY, btn.w * value, trackH, 4, 4)

            local handleX = btn.x + btn.w * value
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", handleX, trackY + trackH / 2, 10)

            local percentText = string.format("%.0f%%", value * 100)
            love.graphics.printf(percentText, btn.x + btn.w + 10, btn.y + btn.h / 2 - 8, 50, "left")

            if isFocused then
                love.graphics.setColor(0.6, 0.8, 1.0, 0.6)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", btn.x - 8, trackY - 24, btn.w + 16, trackH + 48, 8, 8)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1)
            end

        elseif opt.type == "cycle" and opt.setting == "language" then
            local current = Settings.language or Localization:getCurrentLanguage()
            local state = Localization:getLanguageName(current)
            label = string.format("%s: %s", label, state)
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)

        else
            -- plain button
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
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
            local trackY = btn.y + btn.h / 2 - 4
            local trackH = 8
            local hoveredSlider = x >= btn.x and x <= btn.x + btn.w and
                                  y >= trackY and y <= trackY + trackH
            if hoveredSlider then
                sliderDragging = opt.slider
                local rel = (x - btn.x) / btn.w
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
