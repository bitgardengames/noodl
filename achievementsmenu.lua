local Achievements = require("achievements")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")

local AchievementsMenu = {}

local backButton = {}
local hovered = false
local pulse = 0

local iconCache = {}

function AchievementsMenu:enter()
    Screen:update()
    local sw, sh = Screen:get()

    backButton = {
        x = sw / 2 - UI.spacing.buttonWidth / 2,
        y = sh - 80,
        w = UI.spacing.buttonWidth,
        h = UI.spacing.buttonHeight,
    }

    -- Load icons
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
    hovered = UI.isHovered(backButton.x, backButton.y, backButton.w, backButton.h, mx, my)
    pulse = pulse + dt * 3
end

function AchievementsMenu:draw()
    local sw, sh = Screen:get()
    love.graphics.clear(Theme.bgColor)

    -- Title
    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Achievements", 0, 80, sw, "center")

    -- Draw achievement cards
    local startY = 180
    local spacing = 110
    local cardWidth = 560
    local cardHeight = 90
    local xCenter = sw / 2
    local i = 0
    local lockedCardColor = Theme.lockedCardColor or {0.12, 0.12, 0.15}
	local keys = {}

	for key in pairs(Achievements.definitions) do
		table.insert(keys, key)
	end

	table.sort(keys)

	for _, key in ipairs(keys) do
		local ach = Achievements.definitions[key]
        local y = startY + i * spacing
        local unlocked = ach.unlocked
        local progress = ach.progress or 0
        local goal = ach.goal or 0
        local hasProgress = goal > 0
        local icon = iconCache[key]

        local x = xCenter - cardWidth / 2

        -- Shadow behind card
        love.graphics.setColor(Theme.shadowColor)
        UI.drawRoundedRect(x + 4, y + 4, cardWidth, cardHeight, 12)

        -- Card background
        love.graphics.setColor(unlocked and Theme.achieveColor or lockedCardColor)
        UI.drawRoundedRect(x, y, cardWidth, cardHeight, 12)

        -- Border
        love.graphics.setColor(Theme.borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 12)

        -- Icon with border
        if icon then
            local iconX, iconY = x + 10, y + 10
            local scaleX = 48 / icon:getWidth()
            local scaleY = 48 / icon:getHeight()

			if unlocked then
				love.graphics.setColor(1, 1, 1, 1)
			else
				love.graphics.setColor(0.5, 0.5, 0.5, 1)
			end

            love.graphics.draw(icon, iconX, iconY, 0, scaleX, scaleY)

            -- Icon border
            local r, g, b = unpack(Theme.borderColor)
            love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", iconX - 1, iconY - 1, 48 + 2, 48 + 2, 6)
        end

        local textX = x + 70

        -- Title text color
		love.graphics.setFont(UI.fonts.achieve)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(ach.title, textX, y + 8, cardWidth - 80, "left")

        -- Description text color
		love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(ach.description, textX, y + 32, cardWidth - 80, "left")

        -- Progress bar
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

        i = i + 1
    end

    -- Back button using UI module
    UI.drawButton(backButton.x, backButton.y, backButton.w, backButton.h, "Back to Menu", hovered)
end

function AchievementsMenu:mousepressed(x, y, button)
    if button == 1 and hovered then
        return "menu"
    end
end

return AchievementsMenu