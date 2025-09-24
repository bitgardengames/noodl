local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local drawSnake = require("snakedraw")
local drawWord = require("drawword")
local Face = require("face")

local Menu = {}

local buttons = {}
local hoveredButton = nil
local t = 0

local function lerpColor(c1, c2, t)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
        (c1[4] or 1) + ((c2[4] or 1) - (c1[4] or 1)) * t
    }
end

local SEGMENT_SIZE = 24

function Menu:enter()
    t = 0

	UI.buttons = {}

    Audio:playMusic("menu")
    Screen:update()

    local sw, sh = Screen:get()
    local centerX = sw / 2
    local startY = sh / 2 - ((UI.spacing.buttonHeight + UI.spacing.buttonSpacing) * 2.5)

    local labels = {
        { text = "Start Game",       action = "modeselect" },
        { text = "Settings",         action = "settings" },
        { text = "Achievements",     action = "achievementsmenu" },
        { text = "Quit",             action = "quit" },
    }

    buttons = {}

    for i, entry in ipairs(labels) do
        local x = centerX - UI.spacing.buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)
        local w = UI.spacing.buttonWidth
        local h = UI.spacing.buttonHeight
        local id = "menuButton" .. i

        table.insert(buttons, {
            id = id,
            x = x,
            y = y,
            w = w,
            h = h,
            text = entry.text,
            action = entry.action,
            hovered = false,
            scale = 1,
            alpha = 0,
            offsetY = 50,
        })
    end
end

function Menu:update(dt)
    t = t + dt

    local mx, my = love.mouse.getPosition()
    hoveredButton = nil

    for i, btn in ipairs(buttons) do
        btn.hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)

        -- smooth hover scale
        if btn.hovered then
            btn.scale = math.min((btn.scale or 1) + dt * 5, 1.1)
            hoveredButton = btn
        else
            btn.scale = math.max((btn.scale or 1) - dt * 5, 1.0)
        end

        -- entry animation
        local appearDelay = (i - 1) * 0.08
        local appearTime = math.min((t - appearDelay) * 3, 1)
        btn.alpha = math.max(0, math.min(appearTime, 1))
        btn.offsetY = (1 - btn.alpha) * 50
    end

    -- update snake face (for passive blinking)
    Face:update(dt)
end


function Menu:draw()
    local sw, sh = Screen:get()

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- center position for the noodl logo
    local cellSize = 20
    local word = "noodl"
    local spacing = 10
    local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
    local ox = (sw - wordWidth) / 2
    local oy = sh * 0.2 -- push up (20% down the screen instead of 33%)

    -- draw the snake "noodl"
    local trail = drawWord(word, ox, oy, cellSize, spacing)

    -- draw snake face at last point (snake "head")
    if trail and #trail > 0 then
        local head = trail[#trail]
        local faceTex = Face:getTexture()
        local fw, fh = faceTex:getWidth(), faceTex:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(faceTex, head.x - fw/2, head.y - fh/2)
    end

    -- buttons
    for _, btn in ipairs(buttons) do
        if btn.alpha > 0 then
            -- register button with updated system
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)

            love.graphics.push()
            love.graphics.translate(btn.x + btn.w / 2, btn.y + btn.h / 2 + btn.offsetY)
            love.graphics.scale(btn.scale)
            love.graphics.translate(-(btn.x + btn.w / 2), -(btn.y + btn.h / 2))

            UI.drawButton(btn.id)

            love.graphics.pop()
        end
    end

    -- version
    love.graphics.setFont(UI.fonts.small)
    love.graphics.setColor(Theme.textColor)
    love.graphics.print("v1.0.0", 10, sh - 24)
end

function Menu:mousepressed(x, y, button)
    UI:mousepressed(x, y, button)
end

function Menu:mousereleased(x, y, button)
    local id = UI:mousereleased(x, y, button)
    if id then
        for _, btn in ipairs(buttons) do
            if btn.id == id then
                return btn.action
            end
        end
    end
end

return Menu