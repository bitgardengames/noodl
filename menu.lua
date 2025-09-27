local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local drawWord = require("drawword")
local Face = require("face")
local ButtonList = require("buttonlist")
local Localization = require("localization")

local Menu = {}

local buttonList = ButtonList.new()
local buttons = {}
local t = 0
local buttonArea = nil

function Menu:enter()
    t = 0
    UI.clearButtons()

    Audio:playMusic("menu")
    Screen:update()

    local labels = {
        { key = "menu.start_game",   action = "modeselect" },
        { key = "menu.achievements", action = "achievementsmenu" },
        { key = "menu.settings",     action = "settings" },
        { key = "menu.quit",         action = "quit" },
    }

    local sw, sh = Screen:get()
    local safe = UI.layout.safeMargin
    local centerX = sw / 2

    local buttonWidth = math.min(UI.spacing.buttonWidth, sw - safe.x * 2)
    local totalHeight = (#labels) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing) - UI.spacing.buttonSpacing
    local alignedTop = safe.y + UI.fonts.title:getHeight() + 60
    local centeredTop = sh / 2 - totalHeight / 2
    local startY = math.max(alignedTop, centeredTop)

    local defs = {}

    for i, entry in ipairs(labels) do
        local x = centerX - buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)

        defs[#defs + 1] = {
            id = "menuButton" .. i,
            x = x,
            y = y,
            w = buttonWidth,
            h = UI.spacing.buttonHeight,
            labelKey = entry.key,
            text = Localization:get(entry.key),
            action = entry.action,
            hovered = false,
            scale = 1,
            alpha = 0,
            offsetY = 50,
        }
    end

    buttons = buttonList:reset(defs)

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
        buttonArea = {
            x = minX - padding,
            y = minY - padding,
            w = (maxX - minX) + padding * 2,
            h = (maxY - minY) + padding * 2,
        }
    else
        buttonArea = nil
    end
end

function Menu:update(dt)
    t = t + dt

    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)

    for i, btn in ipairs(buttons) do
        if btn.hovered then
            btn.scale = math.min((btn.scale or 1) + dt * 5, 1.1)
        else
            btn.scale = math.max((btn.scale or 1) - dt * 5, 1.0)
        end

        local appearDelay = (i - 1) * 0.08
        local appearTime = math.min((t - appearDelay) * 3, 1)
        btn.alpha = math.max(0, math.min(appearTime, 1))
        btn.offsetY = (1 - btn.alpha) * 50
    end

    Face:update(dt)
end

function Menu:draw()
    local sw, sh = Screen:get()

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local baseCellSize = 20
    local baseSpacing = 10
    local wordScale = 1.5

    local cellSize = baseCellSize * wordScale
    local word = Localization:get("menu.title_word")
    local spacing = baseSpacing * wordScale
    local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
    local ox = (sw - wordWidth) / 2
    local oy = sh * 0.2

    local trail = drawWord(word, ox, oy, cellSize, spacing)

    if trail and #trail > 0 then
        local head = trail[#trail]
        Face:draw(head.x, head.y, wordScale)
    end

    if buttonArea then
        UI.drawPanel(buttonArea.x, buttonArea.y, buttonArea.w, buttonArea.h, {
            radius = UI.spacing.buttonRadius + 4,
        })
    end

    for _, btn in ipairs(buttons) do
        if btn.labelKey then
            btn.text = Localization:get(btn.labelKey)
        end

        if btn.alpha > 0 then
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)

            love.graphics.push()
            love.graphics.translate(btn.x + btn.w / 2, btn.y + btn.h / 2 + btn.offsetY)
            love.graphics.scale(btn.scale)
            love.graphics.translate(-(btn.x + btn.w / 2), -(btn.y + btn.h / 2))

            UI.drawButton(btn.id)

            love.graphics.pop()
        end
    end

    local safe = UI.layout.safeMargin
    UI.print(Localization:get("menu.version"), safe.x, sh - safe.y, { font = "small" })
end

function Menu:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function Menu:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    if action then
        return action
    end
end

local function handleMenuConfirm()
    local action = buttonList:activateFocused()
    if action then
        Audio:playSound("click")
    end
    return action
end

function Menu:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        return handleMenuConfirm()
    elseif button == "b" then
        return "quit"
    end
end

Menu.joystickpressed = Menu.gamepadpressed

return Menu
