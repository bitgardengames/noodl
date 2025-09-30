local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")

local SettingsScreen = {
    transitionDuration = 0.45,
}

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
local layout = {
    panel = { x = 0, y = 0, w = 0, h = 0 },
}

function SettingsScreen:enter()
    Screen:update()
    local sw, sh = Screen:get()
    local centerX = sw / 2

    local spacing = UI.spacing.buttonSpacing
    local totalHeight = 0
    for index, opt in ipairs(options) do
        if index > 1 then
            totalHeight = totalHeight + spacing
        end
        if opt.type == "slider" then
            totalHeight = totalHeight + UI.spacing.sliderHeight
        else
            totalHeight = totalHeight + UI.spacing.buttonHeight
        end
    end

    local panelPadding = UI.spacing.panelPadding
    local panelWidth = UI.spacing.buttonWidth + panelPadding * 2
    local panelHeight = totalHeight + panelPadding * 2
    local panelX = centerX - panelWidth / 2
    local panelY = sh / 2 - panelHeight / 2

    layout.panel = { x = panelX, y = panelY, w = panelWidth, h = panelHeight }

    local startY = panelY + panelPadding

    -- reset UI.buttons so we don’t keep stale hitboxes
    UI.clearButtons()
    buttons = {}

    for i, opt in ipairs(options) do
        local x = panelX + panelPadding
        local y = startY
        local w = UI.spacing.buttonWidth
        local h = (opt.type == "slider") and UI.spacing.sliderHeight or UI.spacing.buttonHeight
        local id = "settingsOption" .. i

        table.insert(buttons, {
            id = id,
            x = x,
            y = y,
            w = w,
            h = h,
            option = opt,
            hovered = false,
            sliderTrack = nil,
        })

        local entry = buttons[#buttons]

        if opt.type == "slider" then
            local trackHeight = UI.spacing.sliderTrackHeight
            local padding = UI.spacing.sliderPadding
            entry.sliderTrack = {
                x = x + padding,
                y = y + h - padding - trackHeight,
                w = w - padding * 2,
                h = trackHeight,
                handleRadius = UI.spacing.sliderHandleRadius,
            }
        end

        -- register for clickable items (skip sliders, those are custom)
        if opt.type ~= "slider" then
            UI.registerButton(id, x, y, w, h, Localization:get(opt.labelKey))
        end

        startY = startY + h + spacing
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
            local track = btn.sliderTrack
            local rel
            if track then
                rel = (mx - track.x) / track.w
            else
                rel = (mx - btn.x) / btn.w
            end
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
    love.graphics.clear(UI.colors.background or Theme.bgColor)

    local panel = layout.panel
    UI.drawPanel(panel.x, panel.y, panel.w, panel.h)

    local titleText = Localization:get("settings.title")
    local titleHeight = UI.fonts.title:getHeight()
    local titleY = math.max(UI.spacing.sectionSpacing, panel.y - UI.spacing.sectionSpacing - titleHeight * 0.25)
    UI.drawLabel(titleText, 0, titleY, sw, "center", { fontKey = "title" })

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
            local value = math.min(1, math.max(0, Settings[opt.slider] or 0))
            local trackX, trackY, trackW, trackH, handleRadius = UI.drawSlider(nil, btn.x, btn.y, btn.w, value, {
                label = label,
                focused = isFocused,
                hovered = btn.hovered,
                register = false,
            })

            btn.sliderTrack = {
                x = trackX,
                y = trackY,
                w = trackW,
                h = trackH,
                handleRadius = handleRadius,
            }

        elseif opt.type == "cycle" and opt.setting == "language" then
            local current = Settings.language or Localization:getCurrentLanguage()
            local state = Localization:getLanguageName(current)
            label = string.format("%s: %s", label, state)
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.setButtonFocus(btn.id, isFocused)
            UI.drawButton(btn.id)

        else
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
        if not btn.option or btn.option.type ~= "slider" then
            UI.setButtonFocus(btn.id, focused)
        end
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
            local track = btn.sliderTrack
            local hoveredSlider
            if track then
                hoveredSlider = x >= track.x and x <= track.x + track.w and
                                 y >= track.y - (track.h * 0.75) and y <= track.y + track.h * 1.75
            else
                hoveredSlider = x >= btn.x and x <= btn.x + btn.w and
                                 y >= btn.y and y <= btn.y + btn.h
            end
            if hoveredSlider then
                sliderDragging = opt.slider
                local rel
                if track then
                    rel = (x - track.x) / track.w
                else
                    rel = (x - btn.x) / btn.w
                end
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

function SettingsScreen:keypressed(key)
    if key == "up" then
        self:moveFocus(-1)
    elseif key == "down" then
        self:moveFocus(1)
    elseif key == "left" then
        self:adjustFocused(-1)
    elseif key == "right" then
        self:adjustFocused(1)
    elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
        return self:activateFocused()
    elseif key == "escape" or key == "backspace" then
        return "menu"
    end
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
