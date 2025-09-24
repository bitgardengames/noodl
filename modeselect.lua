local GameModes = require("gamemodes")
local Screen = require("screen")
local Score = require("score")
local UI = require("ui")
local Theme = require("theme")

local ModeSelect = {}

local buttons = {}
local hoveredButton = nil

function ModeSelect:enter()
    Screen:update()

	UI.buttons = {}

    local sw, sh = Screen:get()
    local centerX = sw / 2

    local buttonWidth = math.min(600, sw - 100)
    local buttonHeight = 90
    local spacing = 20
    local x = centerX - buttonWidth / 2
    local y = 160

    buttons = {}

    for i, key in ipairs(GameModes.modeList) do
        local mode = GameModes.available[key]
        local isUnlocked = mode.unlocked == true
        local desc = isUnlocked and mode.description or ("Locked — " .. (mode.unlockDescription or "???"))
        local score = Score:getHighScore(key)
        local id = "mode_" .. key

        -- create local button entry
        table.insert(buttons, {
            id = id,
            x = x,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
            text = mode.label,
            description = desc,
            score = score,
            modeKey = key,
            hovered = false,
            unlocked = isUnlocked,
        })

        -- register with UI so hitboxes exist immediately
        UI.registerButton(id, x, y, buttonWidth, buttonHeight)

        y = y + buttonHeight + spacing
    end

    -- Back button
    local backId = "modeBack"
    local backY = y + 10

    table.insert(buttons, {
        id = backId,
        x = x,
        y = backY,
        w = 220,
        h = 44,
        text = "Back to Menu",
        description = "",
        modeKey = "back",
        hovered = false,
        unlocked = true,
    })
    UI.registerButton(backId, x, backY, 220, 44)
end

function ModeSelect:update(dt)
    local mx, my = love.mouse.getPosition()
    hoveredButton = nil

    for _, btn in ipairs(buttons) do
        btn.hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
        if btn.hovered then hoveredButton = btn end
    end
end

function ModeSelect:draw()
    local sw, sh = Screen:get()

    -- Background
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Title
    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf("Select Game Mode", 0, 40, sw, "center")

    -- Buttons
    for _, btn in ipairs(buttons) do
        -- Register + draw the button
        UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
        UI.drawButton(btn.id)

        -- Description
        if btn.description and btn.description ~= "" then
            love.graphics.setFont(UI.fonts.body)
            local descColor = btn.unlocked and Theme.textColor or Theme.lockedCardColor
            love.graphics.setColor(descColor)
            love.graphics.printf(btn.description, btn.x + 20, btn.y + btn.h - 32, btn.w - 40, "left")
        end

        -- Score display
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
    UI:mousepressed(x, y, button)
end

function ModeSelect:mousereleased(x, y, button)
    local id = UI:mousereleased(x, y, button)
    if not id then return end

    for _, btn in ipairs(buttons) do
        if btn.id == id then
            if btn.modeKey == "back" then
                return "menu"
            elseif btn.unlocked then
                GameModes:set(btn.modeKey)
                return "game"
            end
        end
    end
end

return ModeSelect