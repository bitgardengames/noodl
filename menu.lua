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
local gridOffset = 0
local backgroundGradient
local gradientSize = { w = 0, h = 0 }
local backgroundOrbs = {}
local GRID_SPACING = 72

local function colorWithAlpha(color, alpha)
    return {
        color[1],
        color[2],
        color[3],
        (color[4] or 1) * alpha,
    }
end

local function lighten(color, amount)
    amount = math.min(math.max(amount or 0, 0), 1)
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
        color[4] or 1,
    }
end

local function rebuildGradient(sw, sh)
    local topColor = lighten(Theme.buttonColor, 0.55)
    topColor[4] = 0.65
    local bottomColor = Theme.bgColor

    backgroundGradient = love.graphics.newMesh({
        {0, 0, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4]},
        {1, 0, 1, 0, topColor[1], topColor[2], topColor[3], topColor[4]},
        {1, 1, 1, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4]},
        {0, 1, 0, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4]},
    }, "fan", "static")

    gradientSize.w = sw
    gradientSize.h = sh
end

local function refreshOrbs(sw, sh)
    backgroundOrbs = {}
    local count = 8 + math.floor(sw / 320)
    local baseColor = lighten(Theme.buttonColor, 0.4)
    baseColor[4] = 0.4

    for i = 1, count do
        backgroundOrbs[i] = {
            x = love.math.random() * sw,
            y = love.math.random() * sh,
            radius = love.math.random(80, 140),
            speed = love.math.random() * 0.3 + 0.25,
            drift = love.math.random(12, 36),
            phase = love.math.random() * math.pi * 2,
            color = {
                baseColor[1] + (love.math.random() - 0.5) * 0.1,
                baseColor[2] + (love.math.random() - 0.5) * 0.1,
                baseColor[3] + (love.math.random() - 0.5) * 0.1,
                baseColor[4],
            },
        }
    end
end

function Menu:enter()
    t = 0
    UI.clearButtons()

    Audio:playMusic("menu")
    Screen:update()

    local sw, sh = Screen:get()
    rebuildGradient(sw, sh)
    refreshOrbs(sw, sh)
    gridOffset = 0
    local centerX = sw / 2
    local startY = sh / 2 - ((UI.spacing.buttonHeight + UI.spacing.buttonSpacing) * 2.5)

    local labels = {
        { key = "menu.start_game",   action = "modeselect" },
        { key = "menu.settings",     action = "settings" },
        { key = "menu.achievements", action = "achievementsmenu" },
        { key = "menu.quit",         action = "quit" },
    }

    local defs = {}

    for i, entry in ipairs(labels) do
        local x = centerX - UI.spacing.buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)

        defs[#defs + 1] = {
            id = "menuButton" .. i,
            x = x,
            y = y,
            w = UI.spacing.buttonWidth,
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
end

function Menu:update(dt)
    t = t + dt
    gridOffset = (gridOffset + dt * 22) % GRID_SPACING

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

    if not backgroundGradient or gradientSize.w ~= sw or gradientSize.h ~= sh then
        rebuildGradient(sw, sh)
        refreshOrbs(sw, sh)
    end

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if backgroundGradient then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(backgroundGradient, 0, 0, 0, sw, sh)
    end

    local highlight = colorWithAlpha(Theme.highlightColor, 2.3)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])

    local offset = gridOffset
    for x = -GRID_SPACING, sw + GRID_SPACING, GRID_SPACING do
        love.graphics.line(x + offset, 0, x + offset, sh)
    end
    for y = -GRID_SPACING, sh + GRID_SPACING, GRID_SPACING do
        love.graphics.line(0, y + offset * 0.65, sw, y + offset * 0.65)
    end

    love.graphics.setBlendMode("add")
    for _, orb in ipairs(backgroundOrbs) do
        local wobbleX = math.cos((t * orb.speed) + orb.phase) * orb.drift
        local wobbleY = math.sin((t * orb.speed * 0.6) + orb.phase) * orb.drift * 0.6
        local alphaPulse = 0.4 + 0.3 * math.sin((t * orb.speed * 1.4) + orb.phase)
        local orbColor = colorWithAlpha(orb.color, alphaPulse)
        love.graphics.setColor(orbColor[1], orbColor[2], orbColor[3], orbColor[4])
        love.graphics.circle("fill", orb.x + wobbleX, orb.y + wobbleY, orb.radius)
    end
    love.graphics.setBlendMode("alpha")

    local cellSize = 20
    local word = Localization:get("menu.title_word")
    local spacing = 10
    local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
    local ox = (sw - wordWidth) / 2
    local oy = sh * 0.2

    local trail = drawWord(word, ox, oy, cellSize, spacing)

    local tagline = Localization:get("menu.tagline")
    if tagline and tagline ~= "menu.tagline" then
        local taglineColor = colorWithAlpha(Theme.textColor, 0.75)
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(taglineColor[1], taglineColor[2], taglineColor[3], taglineColor[4])
        love.graphics.printf(tagline, 0, oy + cellSize * 2.2, sw, "center")
    end

    if trail and #trail > 0 then
        local head = trail[#trail]
        local faceTex = Face:getTexture()
        local fw, fh = faceTex:getWidth(), faceTex:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(faceTex, head.x - fw / 2, head.y - fh / 2)
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

    love.graphics.setFont(UI.fonts.small)
    local versionColor = colorWithAlpha(Theme.textColor, 0.6)
    love.graphics.setColor(versionColor[1], versionColor[2], versionColor[3], versionColor[4])
    love.graphics.print(Localization:get("menu.version"), 10, sh - 24)
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
