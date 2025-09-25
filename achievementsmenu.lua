local Audio = require("audio")
local Achievements = require("achievements")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")

local AchievementsMenu = {}

local buttonList = ButtonList.new()
local iconCache = {}
local displayBlocks = {}

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
    displayBlocks = Achievements:getDisplayOrder()

    for _, block in ipairs(displayBlocks) do
        for _, ach in ipairs(block.achievements) do
            local iconName = ach.icon or "Default"
            local path = string.format("Assets/Achievements/%s.png", iconName)
            if not love.filesystem.getInfo(path) then
                path = "Assets/Achievements/Default.png"
            end
            if not iconCache[ach.id] then
                local ok, image = pcall(love.graphics.newImage, path)
                iconCache[ach.id] = ok and image or nil
            end
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

    if not displayBlocks or #displayBlocks == 0 then
        displayBlocks = Achievements:getDisplayOrder()
    end

    local startY = 180
    local spacing = 120
    local cardWidth = 600
    local cardHeight = 100
    local xCenter = sw / 2
    local lockedCardColor = Theme.lockedCardColor or {0.12, 0.12, 0.15}
    local categorySpacing = 40

    local y = startY
    for _, block in ipairs(displayBlocks) do
        local categoryLabel = Localization:get("achievements.categories." .. block.id)
        love.graphics.setFont(UI.fonts.button)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(categoryLabel, 0, y - 32, sw, "center")

        for _, ach in ipairs(block.achievements) do
            local unlocked = ach.unlocked
            local progress = ach.progress or 0
            local goal = ach.goal or 0
            local hasProgress = goal > 0
            local icon = iconCache[ach.id]
            local x = xCenter - cardWidth / 2
            local barW = cardWidth - 120
            local cardY = y

            love.graphics.setColor(Theme.shadowColor)
            UI.drawRoundedRect(x + 4, cardY + 4, cardWidth, cardHeight, 14)

            love.graphics.setColor(unlocked and Theme.achieveColor or lockedCardColor)
            UI.drawRoundedRect(x, cardY, cardWidth, cardHeight, 14)

            love.graphics.setColor(Theme.borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, cardY, cardWidth, cardHeight, 14)

            if icon then
                local iconX, iconY = x + 16, cardY + 18
                local scaleX = 56 / icon:getWidth()
                local scaleY = 56 / icon:getHeight()
                local tint = unlocked and 1 or 0.55
                love.graphics.setColor(tint, tint, tint, 1)
                love.graphics.draw(icon, iconX, iconY, 0, scaleX, scaleY)

                local r, g, b = unpack(Theme.borderColor)
                love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", iconX - 2, iconY - 2, 60, 60, 8)
            end

            local textX = x + 96

            love.graphics.setFont(UI.fonts.achieve)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(Localization:get(ach.titleKey), textX, cardY + 10, cardWidth - 110, "left")

            love.graphics.setFont(UI.fonts.body)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf(Localization:get(ach.descriptionKey), textX, cardY + 38, cardWidth - 110, "left")

            if hasProgress then
                local ratio = Achievements:getProgressRatio(ach)
                local barH = 12
                local barX = textX
                local barY = cardY + cardHeight - 24

                love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
                love.graphics.rectangle("fill", barX, barY, barW, barH, 6)

                love.graphics.setColor(Theme.progressColor)
                love.graphics.rectangle("fill", barX, barY, barW * ratio, barH, 6)

                local progressLabel = Achievements:getProgressLabel(ach)
                if progressLabel then
                    love.graphics.setFont(UI.fonts.small)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.printf(progressLabel, barX, barY - 18, barW, "right")
                end
            end

            y = y + spacing
        end

        y = y + categorySpacing
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

function AchievementsMenu:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" or button == "b" then
        local action = buttonList:activateFocused()
        if action then
            Audio:playSound("click")
        end
        return action
    end
end

AchievementsMenu.joystickpressed = AchievementsMenu.gamepadpressed

return AchievementsMenu
