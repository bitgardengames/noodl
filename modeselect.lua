local Audio = require("audio")
local GameModes = require("gamemodes")
local Screen = require("screen")
local Score = require("score")
local UI = require("ui")
local Theme = require("theme")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local Backdrop = require("backdrop")

local ModeSelect = {}

local buttonList = ButtonList.new()

function ModeSelect:enter()
    Screen:update()
    UI.clearButtons()

    local sw, sh = Screen:get()
    Backdrop:resize(sw, sh)
    Backdrop:onPaletteChanged()
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
    local sw, sh = Screen:get()
    Backdrop:update(dt, sw, sh)

    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)
end

function ModeSelect:draw()
    local sw, sh = Screen:get()
    local bg = Theme.bgColor or {0, 0, 0, 1}
    love.graphics.clear(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 1)

    Backdrop:drawBase(sw, sh)

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

    Backdrop:drawVignette(sw, sh)
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
