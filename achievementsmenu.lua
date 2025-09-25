local Achievements = require("achievements")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")

local AchievementsMenu = {}

local buttonList = ButtonList.new()
local iconCache = {}

function AchievementsMenu:enter()
    Screen:update()
    UI.clearButtons()

    local sw, sh = Screen:get()

    buttonList:reset({
        {
            id = "achievementsBack",
            x = sw / 2 - UI.spacing.buttonWidth / 2,
            y = sh - 80,
            w = UI.spacing.buttonWidth,
            h = UI.spacing.buttonHeight,
            textKey = "achievements.back_to_menu",
            text = Localization:get("achievements.back_to_menu"),
            action = "menu",
        },
    })

    iconCache = {}
    for key, ach in pairs(Achievements.definitions) do
        local iconPath = "Assets/Achievements/" .. (ach.icon or "Default.png")
        if love.filesystem.getInfo(iconPath) then
            iconCache[key] = love.graphics.newImage(iconPath)
        else
            iconCache[key] = love.graphics.newImage("Assets/Achievements/Default.png")
        end
    end
end

function AchievementsMenu:update(dt)
    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)
end

function AchievementsMenu:draw()
    local sw, sh = Screen:get()
    love.graphics.clear(Theme.bgColor)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(Localization:get("achievements.title"), 0, 80, sw, "center")

    local startY = 180
    local spacing = 110
    local cardWidth = 560
    local cardHeight = 90
    local xCenter = sw / 2
    local lockedCardColor = Theme.lockedCardColor or {0.12, 0.12, 0.15}

    local keys = {}
    for key in pairs(Achievements.definitions) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for index, key in ipairs(keys) do
        local ach = Achievements.definitions[key]
        local y = startY + (index - 1) * spacing
        local unlocked = ach.unlocked
        local progress = ach.progress or 0
        local goal = ach.goal or 0
        local hasProgress = goal > 0
        local icon = iconCache[key]
        local x = xCenter - cardWidth / 2

        love.graphics.setColor(Theme.shadowColor)
        UI.drawRoundedRect(x + 4, y + 4, cardWidth, cardHeight, 12)

        love.graphics.setColor(unlocked and Theme.achieveColor or lockedCardColor)
        UI.drawRoundedRect(x, y, cardWidth, cardHeight, 12)

        love.graphics.setColor(Theme.borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 12)

        if icon then
            local iconX, iconY = x + 10, y + 10
            local scaleX = 48 / icon:getWidth()
            local scaleY = 48 / icon:getHeight()
            love.graphics.setColor(unlocked and 1 or 0.5, unlocked and 1 or 0.5, unlocked and 1 or 0.5, 1)
            love.graphics.draw(icon, iconX, iconY, 0, scaleX, scaleY)

            local r, g, b = unpack(Theme.borderColor)
            love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", iconX - 1, iconY - 1, 50, 50, 6)
        end

        local textX = x + 70

        love.graphics.setFont(UI.fonts.achieve)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(Localization:get(ach.titleKey), textX, y + 8, cardWidth - 80, "left")

        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(Localization:get(ach.descriptionKey), textX, y + 32, cardWidth - 80, "left")

        if hasProgress then
            local barW = cardWidth - 80
            local barH = 10
            local barX = textX
            local barY = y + cardHeight - 18
            local ratio = math.min(progress / goal, 1)

            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.rectangle("fill", barX, barY, barW, barH, 4)

            love.graphics.setColor(Theme.progressColor)
            love.graphics.rectangle("fill", barX, barY, barW * ratio, barH, 4)
        end
    end

    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

    buttonList:draw()
end

function AchievementsMenu:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function AchievementsMenu:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    return action
end

return AchievementsMenu
