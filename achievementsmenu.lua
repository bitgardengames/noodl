local Audio = require("audio")
local Achievements = require("achievements")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local drawSnake = require("snakedraw")

local AchievementsMenu = {}

local buttonList = ButtonList.new()
local iconCache = {}
local displayBlocks = {}

local START_Y = 180
local CARD_SPACING = 120
local CARD_WIDTH = 600
local CARD_HEIGHT = 100
local CATEGORY_SPACING = 40
local SCROLL_SPEED = 60

local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0

local thumbSnakePattern = {
    {0.5, 1.0},
    {0.82, 0.82},
    {0.2, 0.66},
    {0.82, 0.5},
    {0.18, 0.34},
    {0.74, 0.18},
    {0.5, 0.0},
}

local function buildThumbSnakeTrail(trackX, thumbY, trackWidth, thumbHeight)
    local marginX = math.max(1, trackWidth * 0.18)
    local marginY = math.max(2, thumbHeight * 0.18)
    local usableWidth = trackWidth - marginX * 2
    local usableHeight = thumbHeight - marginY * 2
    if usableWidth <= 0 or usableHeight <= 0 then
        return {}, marginX, marginY, usableWidth, usableHeight
    end

    local trail = {}
    for _, pt in ipairs(thumbSnakePattern) do
        local px = trackX + marginX + pt[1] * usableWidth
        local py = thumbY + marginY + pt[2] * usableHeight
        trail[#trail + 1] = { x = px, y = py }
    end

    return trail, marginX, marginY, usableWidth, usableHeight
end

local function drawThumbSnake(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight)
    local trail, marginX, marginY, _, usableHeight = buildThumbSnakeTrail(trackX, thumbY, trackWidth, thumbHeight)
    if #trail < 2 then
        return
    end

    local snakeR, snakeG, snakeB = unpack(Theme.snakeDefault)

    love.graphics.push("all")

    local highlightX = trackX + marginX * 0.35
    local highlightY = thumbY + marginY * 0.3
    local highlightW = math.max(0, trackWidth - marginX * 0.7)
    local highlightH = math.max(0, thumbHeight - marginY * 0.6)
    love.graphics.setColor(snakeR, snakeG, snakeB, 0.22)
    love.graphics.rectangle("fill", highlightX, highlightY, highlightW, highlightH, trackWidth * 0.35)

    local scissorX = trackX - 2
    local scissorY = trackY - 2
    local scissorW = trackWidth + 4
    local scissorH = trackHeight + 4
    love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)

    local segmentSize = math.max(4, math.min(trackWidth * 0.9, math.max(1, usableHeight) * 0.55))
    drawSnake(trail, #trail, segmentSize, nil, nil, nil, nil, nil, false)

    local head = trail[#trail]
    if head then
        local headRadius = segmentSize * 0.32
        local eyeOffset = headRadius * 0.55
        local eyeRadius = math.max(1, headRadius * 0.22)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", head.x - eyeOffset, head.y - eyeRadius * 0.4, eyeRadius)
        love.graphics.circle("fill", head.x + eyeOffset, head.y - eyeRadius * 0.4, eyeRadius)

        love.graphics.setColor(0.05, 0.05, 0.05, 0.85)
        love.graphics.circle("fill", head.x - eyeOffset, head.y - eyeRadius * 0.3, eyeRadius * 0.45)
        love.graphics.circle("fill", head.x + eyeOffset, head.y - eyeRadius * 0.3, eyeRadius * 0.45)
    end

    love.graphics.setScissor()
    love.graphics.pop()
end

local function updateScrollBounds(sw, sh)
    local viewportBottom = sh - 120
    viewportHeight = math.max(0, viewportBottom - START_Y)

    local y = START_Y
    local maxBottom = START_Y

    if displayBlocks then
        for _, block in ipairs(displayBlocks) do
            if block.achievements then
                for _ in ipairs(block.achievements) do
                    maxBottom = math.max(maxBottom, y + CARD_HEIGHT)
                    y = y + CARD_SPACING
                end
            end
            y = y + CATEGORY_SPACING
        end
    end

    contentHeight = math.max(0, maxBottom - START_Y)
    minScrollOffset = math.min(0, viewportHeight - contentHeight)

    if scrollOffset < minScrollOffset then
        scrollOffset = minScrollOffset
    elseif scrollOffset > 0 then
        scrollOffset = 0
    end
end

function AchievementsMenu:enter()
    Screen:update()
    UI.clearButtons()

    local sw, sh = Screen:get()

    scrollOffset = 0
    minScrollOffset = 0

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

    updateScrollBounds(sw, sh)

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

    updateScrollBounds(sw, sh)

    local startY = START_Y
    local spacing = CARD_SPACING
    local cardWidth = CARD_WIDTH
    local cardHeight = CARD_HEIGHT
    local xCenter = sw / 2
    local lockedCardColor = Theme.lockedCardColor or {0.12, 0.12, 0.15}
    local categorySpacing = CATEGORY_SPACING

    local scissorTop = START_Y - 80
    local scissorBottom = sh - 120
    local scissorHeight = math.max(0, scissorBottom - scissorTop)
    love.graphics.setScissor(0, scissorTop, sw, scissorHeight)

    love.graphics.push()
    love.graphics.translate(0, scrollOffset)

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

    love.graphics.pop()
    love.graphics.setScissor()

    if contentHeight > viewportHeight then
        local trackX = sw - 52
        local trackWidth = 12
        local trackY = scissorTop
        local trackHeight = viewportHeight

        local scrollRange = -minScrollOffset
        local scrollProgress = scrollRange > 0 and (-scrollOffset / scrollRange) or 0

        local minThumbHeight = 36
        local thumbHeight = math.max(minThumbHeight, viewportHeight * (viewportHeight / contentHeight))
        thumbHeight = math.min(thumbHeight, trackHeight)
        local thumbY = trackY + (trackHeight - thumbHeight) * scrollProgress

        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", trackX - 2, trackY, trackWidth + 4, trackHeight, 6)

        love.graphics.setColor(0.15, 0.18, 0.22, 0.9)
        love.graphics.rectangle("fill", trackX, trackY, trackWidth, trackHeight, 6)

        drawThumbSnake(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight)
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

function AchievementsMenu:wheelmoved(dx, dy)
    -- The colon syntax implicitly passes `self` as the first argument.
    -- The previous signature treated that implicit parameter as the
    -- horizontal scroll delta, so `dy` was always zero and scrolling
    -- never occurred. Accept the real horizontal delta explicitly and
    -- ignore it instead.
    if dy == 0 then
        return
    end

    scrollOffset = scrollOffset + dy * SCROLL_SPEED
    local sw, sh = Screen:get()
    updateScrollBounds(sw, sh)
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
