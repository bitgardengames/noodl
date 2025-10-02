local Audio = require("audio")
local GameModes = require("gamemodes")
local Screen = require("screen")
local Score = require("score")
local UI = require("ui")
local Theme = require("theme")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local Shaders = require("shaders")

local ModeSelect = {
    transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local buttonList = ButtonList.new()
local analogAxisDirections = { horizontal = nil, vertical = nil }

local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function lighten(color, amount, alpha)
    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0
    local a = alpha or color[4] or 1

    amount = clamp01(amount or 0)

    return {
        clamp01(r + (1 - r) * amount),
        clamp01(g + (1 - g) * amount),
        clamp01(b + (1 - b) * amount),
        clamp01(a),
    }
end

local function darken(color, amount, alpha)
    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0
    local a = alpha or color[4] or 1

    amount = clamp01(amount or 0)

    return {
        clamp01(r * (1 - amount)),
        clamp01(g * (1 - amount)),
        clamp01(b * (1 - amount)),
        clamp01(a),
    }
end

local function withAlpha(color, alpha)
    return {
        color[1] or 0,
        color[2] or 0,
        color[3] or 0,
        (color[4] or 1) * (alpha or 1),
    }
end

local BACKGROUND_EFFECT_TYPE = "modeRibbon"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function configureBackgroundEffect()
    local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
    if not effect then
        backgroundEffect = nil
        return
    end

    local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
    effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.52

    Shaders.configure(effect, {
        bgColor = Theme.bgColor,
        accentColor = Theme.borderColor,
        edgeColor = Theme.progressColor,
    })

    backgroundEffect = effect
end

local function drawBackground(sw, sh)
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if not backgroundEffect then
        configureBackgroundEffect()
    end

    if backgroundEffect then
        local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
        Shaders.draw(backgroundEffect, 0, 0, sw, sh, intensity)
    end

    local softGlow = lighten(Theme.progressColor or {1, 1, 1, 1}, 0.35, 0.08)
    love.graphics.setColor(softGlow)
    love.graphics.circle("fill", sw * 0.22, sh * 0.18, sw * 0.35)
    love.graphics.circle("fill", sw * 0.78, sh * 0.72, sw * 0.42)

    love.graphics.setColor(1, 1, 1, 0.04)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(1, 1, 1, 1)
end

local analogAxisActions = {
    horizontal = {
        negative = function()
            buttonList:moveFocus(-1)
        end,
        positive = function()
            buttonList:moveFocus(1)
        end,
    },
    vertical = {
        negative = function()
            buttonList:moveFocus(-1)
        end,
        positive = function()
            buttonList:moveFocus(1)
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

local function handleAnalogAxis(axis, value)
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
            action()
        end
    end
end

function ModeSelect:enter()
    Screen:update()
    UI.clearButtons()
    resetAnalogAxis()

    configureBackgroundEffect()

    local sw, sh = Screen:get()
    local centerX = sw / 2

    local cardWidth = math.min(720, sw - 160)
    local buttonWidth = cardWidth - 64
    local buttonHeight = 72
    local cardPaddingX = 32
    local cardPaddingY = 32
    local extraContentHeight = 96
    local cardHeight = cardPaddingY * 2 + extraContentHeight + buttonHeight
    local spacing = 26
    local x = centerX - cardWidth / 2 + cardPaddingX
    local y = 180

    local defs = {}

    for i, key in ipairs(GameModes.modeList) do
        local mode = GameModes.available[key]
        local isUnlocked = mode.unlocked == true
        local descKey = mode.descriptionKey
        local unlockKey = mode.unlockDescriptionKey
        local score = Score:getHighScore(key)

        defs[#defs + 1] = {
            id = "mode_" .. key,
            x = x,
            y = y + cardHeight - cardPaddingY - buttonHeight,
            w = buttonWidth,
            h = buttonHeight,
            text = Localization:get("modeselect.launch_button", { mode = Localization:get(mode.labelKey) }),
            action = nil,
            descriptionKey = descKey,
            unlockDescriptionKey = unlockKey,
            description = Localization:get(descKey),
            score = score,
            modeKey = key,
            unlocked = isUnlocked,
            modeLabelKey = mode.labelKey,
            card = {
                x = centerX - cardWidth / 2,
                y = y,
                w = cardWidth,
                h = cardHeight,
                paddingX = cardPaddingX,
                paddingY = cardPaddingY,
                radius = 36,
            },
        }

        y = y + cardHeight + spacing
    end

    defs[#defs + 1] = {
        id = "modeBack",
        x = centerX - 110,
        y = y + 14,
        w = 220,
        h = 44,
        textKey = "modeselect.back_to_menu",
        text = Localization:get("modeselect.back_to_menu"),
        action = "menu",
        modeKey = "back",
        unlocked = true,
    }

    buttonList:reset(defs)
end

function ModeSelect:update(dt)
    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)
end

function ModeSelect:draw()
    local sw, sh = Screen:get()

    drawBackground(sw, sh)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(Localization:get("modeselect.title"), 0, 40, sw, "center")

    love.graphics.setFont(UI.fonts.subtitle)
    love.graphics.setColor(withAlpha(Theme.mutedTextColor or Theme.textColor, 0.8))
    love.graphics.printf(Localization:get("modeselect.tagline"), 0, 120, sw, "center")

    local softButtonColor = lighten(Theme.buttonColor, 0.30, 1)
    local softHoverColor = lighten(Theme.buttonHover or Theme.buttonColor, 0.38, 1)
    local softPressColor = darken(Theme.buttonPress or Theme.buttonColor, 0.20, 1)
    local softBorderColor = lighten(Theme.borderColor or Theme.buttonColor, 0.10, 1)

    for _, btn in buttonList:iter() do
        if btn.modeKey ~= "back" then
            local modeLabel = Localization:get(btn.modeLabelKey or btn.textKey)
            btn.modeTitle = modeLabel
            btn.text = Localization:get("modeselect.launch_button", { mode = modeLabel })

            if btn.unlocked and btn.descriptionKey then
                btn.description = Localization:get(btn.descriptionKey)
            else
                local unlockDescription
                if btn.unlockDescriptionKey then
                    unlockDescription = Localization:get(btn.unlockDescriptionKey)
                else
                    unlockDescription = Localization:get("common.unknown")
                end
                btn.description = Localization:get("modeselect.locked_prefix", { description = unlockDescription })
            end
        elseif btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

    local previousRadius = UI.spacing.buttonRadius
    local previousButtonColor = UI.colors.button
    local previousHoverColor = UI.colors.buttonHover
    local previousPressColor = UI.colors.buttonPress
    local previousBorderColor = UI.colors.border

    UI.spacing.buttonRadius = 24
    UI.colors.button = softButtonColor
    UI.colors.buttonHover = softHoverColor
    UI.colors.buttonPress = softPressColor
    UI.colors.border = softBorderColor

    local function drawModeCard(btn)
        local card = btn.card
        if not card then return end

        local x, y = card.x, card.y
        local w, h = card.w, card.h
        local radius = card.radius or 32

        love.graphics.setColor(0, 0, 0, 0.28)
        love.graphics.rectangle("fill", x, y + 6, w, h, radius + 6, radius + 6)

        local baseColor = lighten(Theme.panelColor or Theme.bgColor, 0.32, 0.96)
        love.graphics.setColor(baseColor)
        love.graphics.rectangle("fill", x, y, w, h, radius, radius)

        local highlightColor = withAlpha(lighten(baseColor, 0.35, baseColor[4] or 1), 0.35)
        love.graphics.setColor(highlightColor)
        love.graphics.rectangle("fill", x, y, w, h * 0.45, radius, radius)

        local accent = withAlpha(lighten(Theme.progressColor or {1, 1, 1, 1}, 0.15, 1), btn.focused and 0.22 or 0.15)
        love.graphics.setColor(accent)
        love.graphics.circle("fill", x + w - 96, y + 58, 132)
        love.graphics.circle("fill", x + 86, y + h - 74, 108)

        love.graphics.setColor(withAlpha(Theme.highlightColor or {1, 1, 1, 1}, 0.35))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, radius, radius)

        love.graphics.setLineWidth(1)
    end

    for _, btn in buttonList:iter() do
        if btn.modeKey ~= "back" then
            drawModeCard(btn)
        end
    end

    buttonList:draw()

    UI.colors.button = previousButtonColor
    UI.colors.buttonHover = previousHoverColor
    UI.colors.buttonPress = previousPressColor
    UI.colors.border = previousBorderColor
    UI.spacing.buttonRadius = previousRadius

    for _, btn in buttonList:iter() do
        if btn.modeKey ~= "back" and btn.card then
            local card = btn.card
            if btn.description and btn.description ~= "" then
                love.graphics.setFont(UI.fonts.heading)
                local titleColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
                love.graphics.setColor(titleColor)
                love.graphics.printf(btn.modeTitle or btn.text or "", card.x + card.paddingX, card.y + card.paddingY, card.w - card.paddingX * 2, "left")

                love.graphics.setFont(UI.fonts.body)
                local descColor = btn.unlocked and withAlpha(Theme.mutedTextColor or Theme.textColor, 0.85) or withAlpha(Theme.lockedCardColor, 0.9)
                love.graphics.setColor(descColor)
                love.graphics.printf(btn.description, card.x + card.paddingX, card.y + card.paddingY + 42, card.w - card.paddingX * 2, "left")
            end

            if btn.unlocked and btn.score then
                local scoreText = Localization:get("modeselect.high_score", { score = tostring(btn.score) })
                love.graphics.setFont(UI.fonts.body)
                love.graphics.setColor(withAlpha(Theme.progressColor, 0.95))
                local tw = UI.fonts.body:getWidth(scoreText)
                local scoreY = card.y + card.h - card.paddingY - btn.h - UI.fonts.body:getHeight() - 12
                love.graphics.print(scoreText, card.x + card.w - card.paddingX - tw, scoreY)
            end
        elseif btn.modeKey == "back" and btn.description and btn.description ~= "" then
            love.graphics.setFont(UI.fonts.body)
            local descColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
            love.graphics.setColor(descColor)
            love.graphics.printf(btn.description, btn.x + 20, btn.y + btn.h - 32, btn.w - 40, "left")
        end
    end
end

function ModeSelect:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function ModeSelect:mousereleased(x, y, button)
    local _, btn = buttonList:mousereleased(x, y, button)
    if not btn then return end

    if btn.modeKey == "back" then
        return "menu"
    elseif btn.unlocked then
        GameModes:set(btn.modeKey)
        return "game"
    end
end

function ModeSelect:keypressed(key)
    if key == "up" or key == "left" then
        buttonList:moveFocus(-1)
    elseif key == "down" or key == "right" then
        buttonList:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
        local _, btn = buttonList:activateFocused()
        if not btn then return end

        if btn.modeKey == "back" then
            Audio:playSound("click")
            return "menu"
        elseif btn.unlocked then
            Audio:playSound("click")
            GameModes:set(btn.modeKey)
            return "game"
        end
    elseif key == "escape" or key == "backspace" then
        Audio:playSound("click")
        return "menu"
    end
end

function ModeSelect:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        local _, btn = buttonList:activateFocused()
        if not btn then return end

        if btn.modeKey == "back" then
            Audio:playSound("click")
            return "menu"
        elseif btn.unlocked then
            Audio:playSound("click")
            GameModes:set(btn.modeKey)
            return "game"
        end
    elseif button == "b" then
        Audio:playSound("click")
        return "menu"
    end
end

ModeSelect.joystickpressed = ModeSelect.gamepadpressed

function ModeSelect:gamepadaxis(_, axis, value)
    handleAnalogAxis(axis, value)
end

ModeSelect.joystickaxis = ModeSelect.gamepadaxis

return ModeSelect
