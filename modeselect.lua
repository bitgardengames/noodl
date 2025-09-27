local Audio = require("audio")
local GameModes = require("gamemodes")
local Screen = require("screen")
local Score = require("score")
local UI = require("ui")
local Theme = require("theme")
local ButtonList = require("buttonlist")
local Localization = require("localization")

local ModeSelect = {}

local buttonList = ButtonList.new()
local contentArea = nil

function ModeSelect:enter()
    Screen:update()
    UI.clearButtons()

    local sw, sh = Screen:get()
    local safe = UI.layout.safeMargin
    local centerX = sw / 2

    local buttonWidth = math.min(UI.layout.columnWidth, sw - safe.x * 2)
    local buttonHeight = 90
    local spacing = 20
    local x = centerX - buttonWidth / 2
    local y = safe.y + UI.fonts.title:getHeight() + 48

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
            textAlign = "left",
            textPadding = 28,
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
        textAlign = "center",
        textPadding = 0,
    }

    local buttons = buttonList:reset(defs)

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
        contentArea = {
            x = minX - padding,
            y = minY - padding,
            w = (maxX - minX) + padding * 2,
            h = (maxY - minY) + padding * 2,
        }
    else
        contentArea = nil
    end
end

function ModeSelect:update(dt)
    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)
end

function ModeSelect:draw()
    local sw, sh = Screen:get()
    local safe = UI.layout.safeMargin

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    UI.printf(Localization:get("modeselect.title"), safe.x, safe.y, sw - safe.x * 2, "center", { font = "title" })

    if contentArea then
        UI.drawPanel(contentArea.x, contentArea.y, contentArea.w, contentArea.h, {
            radius = UI.spacing.buttonRadius + 6,
        })
    end

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
            local descColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
            UI.printf(btn.description, btn.x + 28, btn.y + btn.h - 40, btn.w - 56, "left", { font = "body", color = descColor })
        end

        if btn.unlocked and btn.score and btn.modeKey ~= "back" then
            local scoreText = Localization:get("modeselect.high_score", { score = tostring(btn.score) })
            UI.printf(scoreText, btn.x + btn.w - 200, btn.y + 16, 180, "right", { font = "body", color = Theme.progressColor })
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

return ModeSelect
