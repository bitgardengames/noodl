local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local Audio = require("audio")

local ProgressionScreen = {
    transitionDuration = 0.45,
}

local buttonList = ButtonList.new()

local START_Y = 248
local CARD_WIDTH = 720
local CARD_HEIGHT = 120
local CARD_SPACING = 32
local SCROLL_SPEED = 48

local CONTENT_MARGIN = 80
local MIN_CARD_WIDTH = 360

local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0

local trackEntries = {}
local progressionState = nil

local function updateScrollBounds(sw, sh)
    local viewportBottom = sh - 140
    viewportHeight = math.max(0, viewportBottom - START_Y)

    local count = #trackEntries
    if count > 0 then
        contentHeight = count * CARD_HEIGHT + math.max(0, count - 1) * CARD_SPACING
    else
        contentHeight = 0
    end

    minScrollOffset = math.min(0, viewportHeight - contentHeight)

    if scrollOffset < minScrollOffset then
        scrollOffset = minScrollOffset
    elseif scrollOffset > 0 then
        scrollOffset = 0
    end
end

local function scrollBy(amount)
    if amount == 0 then
        return
    end

    if contentHeight <= viewportHeight then
        scrollOffset = 0
        return
    end

    scrollOffset = scrollOffset + amount
    if scrollOffset < minScrollOffset then
        scrollOffset = minScrollOffset
    elseif scrollOffset > 0 then
        scrollOffset = 0
    end
end

function ProgressionScreen:enter()
    Screen:update()
    UI.clearButtons()

    trackEntries = MetaProgression:getUnlockTrack() or {}
    progressionState = MetaProgression:getState()

    local sw, sh = Screen:get()

    buttonList:reset({
        {
            id = "progressionBack",
            x = sw / 2 - UI.spacing.buttonWidth / 2,
            y = sh - 90,
            w = UI.spacing.buttonWidth,
            h = UI.spacing.buttonHeight,
            textKey = "metaprogression.back_to_menu",
            text = Localization:get("metaprogression.back_to_menu"),
            action = "menu",
        },
    })

    scrollOffset = 0
    updateScrollBounds(sw, sh)
end

function ProgressionScreen:leave()
    UI.clearButtons()
end

function ProgressionScreen:update(dt)
    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)
end

local function handleConfirm()
    local action = buttonList:activateFocused()
    if action then
        Audio:playSound("click")
        return action
    end
end

local function getContentWidth(sw)
    local available = sw - CONTENT_MARGIN * 2
    if available <= 0 then
        return MIN_CARD_WIDTH
    end

    return math.max(MIN_CARD_WIDTH, math.min(CARD_WIDTH, available))
end

local function drawSummaryPanel(sw)
    if not progressionState then
        return
    end

    local panelWidth = getContentWidth(sw)
    local panelHeight = 176
    local panelX = (sw - panelWidth) / 2
    local panelY = 120
    local padding = 28

    local bg = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.96)
    UI.drawRoundedRect(panelX, panelY, panelWidth, panelHeight, 14)

    local border = Theme.panelBorder or {0.35, 0.3, 0.5, 1}
    love.graphics.setColor(border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 14, 14)

    local levelText = Localization:get("metaprogression.level_label", { level = progressionState.level or 1 })
    local totalText = Localization:get("metaprogression.total_xp", { total = progressionState.totalExperience or 0 })

    local progressLabel
    local xpIntoLevel = progressionState.xpIntoLevel or 0
    local xpForNext = progressionState.xpForNext or 0
    local progressRatio = 1

    if xpForNext <= 0 then
        progressLabel = Localization:get("metaprogression.max_level")
        progressRatio = 1
    else
        local remaining = math.max(0, xpForNext - xpIntoLevel)
        progressLabel = Localization:get("metaprogression.next_unlock", { remaining = remaining })
        if xpForNext > 0 then
            progressRatio = math.min(1, math.max(0, xpIntoLevel / xpForNext))
        else
            progressRatio = 0
        end
    end

    love.graphics.setFont(UI.fonts.button)
    love.graphics.setColor(Theme.textColor)
    love.graphics.print(levelText, panelX + padding, panelY + padding)

    love.graphics.setFont(UI.fonts.body)
    love.graphics.print(totalText, panelX + padding, panelY + padding + 36)
    love.graphics.print(progressLabel, panelX + padding, panelY + padding + 66)

    local barX = panelX + padding
    local barY = panelY + panelHeight - padding - 28
    local barWidth = panelWidth - padding * 2
    local barHeight = 20

    love.graphics.setColor(0, 0, 0, 0.35)
    UI.drawRoundedRect(barX, barY, barWidth, barHeight, 9)

    love.graphics.setColor(Theme.progressColor or {0.55, 0.75, 0.55, 1})
    UI.drawRoundedRect(barX, barY, barWidth * progressRatio, barHeight, 9)

    love.graphics.setColor(border)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 9, 9)
end

local function drawTrack(sw, sh)
    local cardWidth = getContentWidth(sw)
    local listX = (sw - cardWidth) / 2
    local clipY = START_Y
    local clipH = viewportHeight

    if clipH <= 0 then
        return
    end

    love.graphics.push()
    love.graphics.setScissor(listX - 24, clipY - 16, cardWidth + 48, clipH + 32)

    for index, entry in ipairs(trackEntries) do
        local y = START_Y + scrollOffset + (index - 1) * (CARD_HEIGHT + CARD_SPACING)
        if y + CARD_HEIGHT >= clipY - CARD_HEIGHT and y <= clipY + clipH + CARD_HEIGHT then
            local unlocked = entry.unlocked
            local panelColor = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
            local fillAlpha = unlocked and 0.9 or 0.7

            love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], fillAlpha)
            UI.drawRoundedRect(listX, y, cardWidth, CARD_HEIGHT, 12)

            local borderColor = unlocked and (Theme.achieveColor or {0.55, 0.75, 0.55, 1}) or (Theme.lockedCardColor or {0.5, 0.35, 0.4, 1})
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", listX, y, cardWidth, CARD_HEIGHT, 12, 12)

            local textX = listX + 32
            local textY = y + 22

            love.graphics.setFont(UI.fonts.button)
            love.graphics.setColor(Theme.textColor)
            local header = Localization:get("metaprogression.card_level", { level = entry.level or 0 })
            love.graphics.print(header, textX, textY)

            love.graphics.setFont(UI.fonts.body)
            love.graphics.print(entry.name or "", textX, textY + 32)

            local desc = entry.description or ""
            local wrapWidth = cardWidth - 64
            love.graphics.printf(desc, textX, textY + 60, wrapWidth)

            local statusY = y + CARD_HEIGHT - 34
            local statusText
            if unlocked then
                statusText = Localization:get("metaprogression.status_unlocked")
            else
                statusText = Localization:get("metaprogression.status_locked", { xp = entry.remainingXp or 0 })
            end

            love.graphics.setFont(UI.fonts.small)
            love.graphics.setColor(borderColor)
            love.graphics.print(statusText, textX, statusY)
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()
end

function ProgressionScreen:draw()
    local sw, sh = Screen:get()

    love.graphics.setColor(Theme.bgColor or {0, 0, 0, 1})
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(Localization:get("metaprogression.title"), 0, 48, sw, "center")

    drawSummaryPanel(sw)
    drawTrack(sw, sh)

    buttonList:draw()
end

function ProgressionScreen:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function ProgressionScreen:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    if action then
        Audio:playSound("click")
        return action
    end
end

function ProgressionScreen:wheelmoved(_, dy)
    scrollBy(dy * SCROLL_SPEED)
end

function ProgressionScreen:keypressed(key)
    if key == "up" then
        scrollBy(SCROLL_SPEED)
        buttonList:moveFocus(-1)
    elseif key == "down" then
        scrollBy(-SCROLL_SPEED)
        buttonList:moveFocus(1)
    elseif key == "left" then
        buttonList:moveFocus(-1)
    elseif key == "right" then
        buttonList:moveFocus(1)
    elseif key == "pageup" then
        scrollBy(viewportHeight)
    elseif key == "pagedown" then
        scrollBy(-viewportHeight)
    elseif key == "escape" or key == "backspace" then
        Audio:playSound("click")
        return "menu"
    elseif key == "return" or key == "kpenter" or key == "space" then
        return handleConfirm()
    end
end

function ProgressionScreen:gamepadpressed(_, button)
    if button == "dpup" then
        scrollBy(SCROLL_SPEED)
        buttonList:moveFocus(-1)
    elseif button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" then
        scrollBy(-SCROLL_SPEED)
        buttonList:moveFocus(1)
    elseif button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        return handleConfirm()
    elseif button == "b" then
        Audio:playSound("click")
        return "menu"
    end
end

ProgressionScreen.joystickpressed = ProgressionScreen.gamepadpressed

function ProgressionScreen:resize()
    local sw, sh = Screen:get()
    updateScrollBounds(sw, sh)
end

return ProgressionScreen
