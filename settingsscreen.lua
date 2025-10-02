local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")
local Shaders = require("shaders")
local Display = require("display")

local SettingsScreen = {
    transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35

local function applyAudioVolumes()
    Audio:applyVolumes()
end

local function applyDisplaySettings()
    Display.apply(Settings)
end

local options = {
    { type = "cycle", labelKey = "settings.display_mode", setting = "displayMode" },
    { type = "cycle", labelKey = "settings.windowed_resolution", setting = "resolution" },
    { type = "toggle", labelKey = "settings.toggle_vsync", toggle = "vsync", onChanged = applyDisplaySettings },
    { type = "toggle", labelKey = "settings.toggle_music", toggle = "muteMusic", onChanged = applyAudioVolumes, invertStateLabel = true },
    { type = "toggle", labelKey = "settings.toggle_sfx", toggle = "muteSFX", onChanged = applyAudioVolumes, invertStateLabel = true },
    { type = "slider", labelKey = "settings.music_volume", slider = "musicVolume", onChanged = applyAudioVolumes },
    { type = "slider", labelKey = "settings.sfx_volume", slider = "sfxVolume", onChanged = applyAudioVolumes },
    { type = "toggle", labelKey = "settings.toggle_screen_shake", toggle = "screenShake" },
    { type = "toggle", labelKey = "settings.toggle_fps_counter", toggle = "showFPS" },
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

local BACKGROUND_EFFECT_TYPE = "settingsScan"
local backgroundEffectCache = {}
local backgroundEffect = nil

local displayModeLabels = {
    fullscreen = "settings.display_mode_fullscreen",
    windowed = "settings.display_mode_windowed",
}

local function getDisplayModeLabel()
    local mode = Settings.displayMode == "windowed" and "windowed" or "fullscreen"
    local key = displayModeLabels[mode] or displayModeLabels.fullscreen
    return Localization:get(key)
end

local function getResolutionLabel()
    return Display.getResolutionLabel(Localization, Settings.resolution)
end

local function getCycleStateLabel(setting)
    if setting == "language" then
        local current = Settings.language or Localization:getCurrentLanguage()
        return Localization:getLanguageName(current)
    elseif setting == "displayMode" then
        return getDisplayModeLabel()
    elseif setting == "resolution" then
        return getResolutionLabel()
    end
end

local function cycleLanguage(delta)
    local languages = Localization:getAvailableLanguages()
    if #languages == 0 then
        return Settings.language or Localization:getCurrentLanguage()
    end

    local current = Settings.language or Localization:getCurrentLanguage()
    local index = 1
    for i, code in ipairs(languages) do
        if code == current then
            index = i
            break
        end
    end

    local count = #languages
    local step = delta or 1
    local newIndex = ((index - 1 + step) % count) + 1
    return languages[newIndex]
end

local function refreshLayout(self)
    local prevIndex = focusedIndex
    Screen:update(0, true)
    self:enter()
    if prevIndex and buttons[prevIndex] then
        self:setFocus(prevIndex)
    end
end

local function getBaseColor()
    return (UI.colors and UI.colors.background) or Theme.bgColor
end

local function configureBackgroundEffect()
    local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
    if not effect then
        backgroundEffect = nil
        return
    end

    local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
    effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.5

    Shaders.configure(effect, {
        bgColor = getBaseColor(),
        accentColor = Theme.borderColor,
        lineColor = Theme.highlightColor,
    })

    backgroundEffect = effect
end

local function drawBackground(sw, sh)
    local baseColor = getBaseColor()
    love.graphics.setColor(baseColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if not backgroundEffect then
        configureBackgroundEffect()
    end

    if backgroundEffect then
        local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
        Shaders.draw(backgroundEffect, 0, 0, sw, sh, intensity)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local analogAxisDirections = { horizontal = nil, vertical = nil }

local analogAxisActions = {
    horizontal = {
        negative = function(self)
            self:adjustFocused(-1)
        end,
        positive = function(self)
            self:adjustFocused(1)
        end,
    },
    vertical = {
        negative = function(self)
            self:moveFocus(-1)
        end,
        positive = function(self)
            self:moveFocus(1)
        end,
    },
}

local analogAxisMap = {
    leftx = { slot = "horizontal" },
    rightx = { slot = "horizontal" },
    lefty = { slot = "vertical" },
    righty = { slot = "vertical" },
    [1] = { slot = "horizontal" },
    [2] = { slot = "vertical" },
}

local function resetAnalogAxis()
    analogAxisDirections.horizontal = nil
    analogAxisDirections.vertical = nil
end

local function handleAnalogAxis(self, axis, value)
    local mapping = analogAxisMap[axis]
    if not mapping then
        return
    end

    local direction
    if value >= ANALOG_DEADZONE then
        direction = "positive"
    elseif value <= -ANALOG_DEADZONE then
        direction = "negative"
    end

    if analogAxisDirections[mapping.slot] == direction then
        return
    end

    analogAxisDirections[mapping.slot] = direction

    if direction then
        local actions = analogAxisActions[mapping.slot]
        local action = actions and actions[direction]
        if action then
            action(self)
        end
    end
end

function SettingsScreen:enter()
    Screen:update()
    configureBackgroundEffect()
    local sw, sh = Screen:get()
    local centerX = sw / 2

    resetAnalogAxis()

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
            if opt.onChanged then
                opt.onChanged(Settings, opt)
            end
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
    drawBackground(sw, sh)

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
            local enabled = not not Settings[opt.toggle]
            if opt.invertStateLabel then
                enabled = not enabled
            end
            local state = enabled and Localization:get("common.on") or Localization:get("common.off")
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

        elseif opt.type == "cycle" and opt.setting then
            local state = getCycleStateLabel(opt.setting)
            if state then
                label = string.format("%s: %s", label, state)
            end
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

function SettingsScreen:cycleSetting(setting, delta)
    delta = delta or 1

    if setting == "language" then
        local nextLang = cycleLanguage(delta)
        Settings.language = nextLang
        Settings:save()
        Localization:setLanguage(nextLang)
        Audio:playSound("click")
        refreshLayout(self)
    elseif setting == "displayMode" then
        local nextMode = Display.cycleDisplayMode(Settings.displayMode, delta)
        if nextMode ~= Settings.displayMode then
            Settings.displayMode = nextMode
            Settings:save()
            Display.apply(Settings)
            Audio:playSound("click")
            refreshLayout(self)
        end
    elseif setting == "resolution" then
        local nextResolution = Display.cycleResolution(Settings.resolution, delta)
        if nextResolution ~= Settings.resolution then
            Settings.resolution = nextResolution
            Settings:save()
            if Settings.displayMode == "windowed" then
                Display.apply(Settings)
            end
            Audio:playSound("click")
            refreshLayout(self)
        end
    end
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
            if opt.onChanged then
                opt.onChanged(Settings, opt)
            end
        end
    elseif opt.type == "cycle" and opt.setting then
        self:cycleSetting(opt.setting, delta)
    end
end

function SettingsScreen:activateFocused()
    local btn = self:getFocusedOption()
    if not btn then return nil end

    local opt = btn.option
    if opt.type == "toggle" and opt.toggle then
        Settings[opt.toggle] = not Settings[opt.toggle]
        Settings:save()
        if opt.onChanged then
            opt.onChanged(Settings, opt)
        end
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
    elseif opt.type == "cycle" and opt.setting then
        self:cycleSetting(opt.setting, 1)
    end

    return nil
end

function SettingsScreen:mousepressed(x, y, button)
    local id = UI:mousepressed(x, y, button)

    for i, btn in ipairs(buttons) do
        local opt = btn.option

        if btn.id and btn.id == id then
            self:setFocus(i)

            if opt.type == "cycle" and opt.setting then
                self:cycleSetting(opt.setting, 1)
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
                if opt.onChanged then
                    opt.onChanged(Settings, opt)
                end
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
                if opt.onChanged then
                    opt.onChanged(Settings, opt)
                end
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

function SettingsScreen:gamepadaxis(_, axis, value)
    handleAnalogAxis(self, axis, value)
end

SettingsScreen.joystickaxis = SettingsScreen.gamepadaxis

return SettingsScreen
