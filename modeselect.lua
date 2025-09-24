local GameModes = require("gamemodes")
local Screen = require("screen")
local Score = require("score")
local UI = require("ui")
local Theme = require("theme")
local ButtonList = require("buttonlist")

local ModeSelect = {}

local buttonList = ButtonList.new()

function ModeSelect:enter()
    Screen:update()
    UI.clearButtons()

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
        local desc = isUnlocked and mode.description or ("Locked — " .. (mode.unlockDescription or "???"))
        local score = Score:getHighScore(key)

        defs[#defs + 1] = {
            id = "mode_" .. key,
            x = x,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
            text = mode.label,
            action = nil,
            description = desc,
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
        text = "Back to Menu",
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

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf("Select Game Mode", 0, 40, sw, "center")

    buttonList:draw()

    for _, btn in buttonList:iter() do
        if btn.description and btn.description ~= "" then
            love.graphics.setFont(UI.fonts.body)
            local descColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
            love.graphics.setColor(descColor)
            love.graphics.printf(btn.description, btn.x + 20, btn.y + btn.h - 32, btn.w - 40, "left")
        end

        if btn.unlocked and btn.score and btn.modeKey ~= "back" then
            local scoreText = "High Score: " .. tostring(btn.score)
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

return ModeSelect
