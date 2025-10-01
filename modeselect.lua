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

    local buttonWidth = math.min(600, sw - 100)
    local buttonHeight = 90
    local spacing = 20
    local x = centerX - buttonWidth / 2
    local y = 160

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
            y = y,
            w = buttonWidth,
            h = buttonHeight,
            textKey = mode.labelKey,
            text = Localization:get(mode.labelKey),
            action = nil,
            descriptionKey = descKey,
            unlockDescriptionKey = unlockKey,
            description = Localization:get(descKey),
            score = score,
            modeKey = key,
            unlocked = isUnlocked,
        }

        y = y + buttonHeight + spacing
    end

    defs[#defs + 1] = {
        id = "modeBack",
        x = x,
        y = y + 10,
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

    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end

        if btn.modeKey ~= "back" then
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
        end
    end

    buttonList:draw()

    for _, btn in buttonList:iter() do
        if btn.description and btn.description ~= "" then
            love.graphics.setFont(UI.fonts.body)
            local descColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
            love.graphics.setColor(descColor)
            love.graphics.printf(btn.description, btn.x + 20, btn.y + btn.h - 32, btn.w - 40, "left")
        end

        if btn.unlocked and btn.score and btn.modeKey ~= "back" then
            local scoreText = Localization:get("modeselect.high_score", { score = tostring(btn.score) })
            love.graphics.setFont(UI.fonts.body)
            love.graphics.setColor(Theme.progressColor)
            local tw = UI.fonts.body:getWidth(scoreText)
            love.graphics.print(scoreText, btn.x + btn.w - tw - 20, btn.y + 12)
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
