local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local PlayerStats = require("playerstats")
local Audio = require("audio")

local ProgressionScreen = {
    transitionDuration = 0.45,
}

local buttonList = ButtonList.new()

local START_Y = 220
local CARD_WIDTH = 640
local CARD_HEIGHT = 108
local CARD_SPACING = 24
local STAT_CARD_HEIGHT = 72
local STAT_CARD_SPACING = 16
local SCROLL_SPEED = 48
local TAB_WIDTH = 220
local TAB_HEIGHT = 52
local TAB_SPACING = 16
local TAB_Y = 120 - TAB_HEIGHT - 16

local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0

local trackEntries = {}
local statsEntries = {}
local progressionState = nil
local activeTab = "experience"

local tabs = {
    {
        id = "experience",
        action = "tab_experience",
        labelKey = "metaprogression.tabs.experience",
    },
    {
        id = "stats",
        action = "tab_stats",
        labelKey = "metaprogression.tabs.stats",
    },
}

local function getActiveList()
    if activeTab == "stats" then
        return statsEntries, STAT_CARD_HEIGHT, STAT_CARD_SPACING
    end

    return trackEntries, CARD_HEIGHT, CARD_SPACING
end

local function updateScrollBounds(sw, sh)
    local viewportBottom = sh - 140
    viewportHeight = math.max(0, viewportBottom - START_Y)

    local entries, itemHeight, spacing = getActiveList()
    local count = #entries
    if count > 0 then
        contentHeight = count * itemHeight + math.max(0, count - 1) * spacing
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

local function formatInteger(value)
    local rounded = math.floor((value or 0) + 0.5)
    local sign = rounded < 0 and "-" or ""
    local digits = tostring(math.abs(rounded))
    local formatted = digits
    local count

    while true do
        formatted, count = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if count == 0 then
            break
        end
    end

    return sign .. formatted
end

local function formatStatValue(value)
    if type(value) == "number" then
        if math.abs(value - math.floor(value + 0.5)) < 0.0001 then
            return formatInteger(value)
        end

        return string.format("%.2f", value)
    end

    if value == nil then
        return "0"
    end

    return tostring(value)
end

local function formatDuration(seconds)
    local totalSeconds = math.floor((seconds or 0) + 0.5)
    if totalSeconds < 0 then
        totalSeconds = 0
    end

    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local secs = totalSeconds % 60

    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, secs)
    end

    return string.format("%ds", secs)
end

local function formatPerMinute(value)
    local amount = tonumber(value) or 0
    if amount < 0 then
        amount = 0
    end

    return string.format("%.2f / min", amount)
end

local statFormatters = {
    totalTimeAlive = formatDuration,
    longestRunDuration = formatDuration,
    bestFloorClearTime = formatDuration,
    longestFloorClearTime = formatDuration,
    averageFloorClearTime = formatDuration,
    bestFruitPerMinute = formatPerMinute,
    averageFruitPerMinute = formatPerMinute,
}

local function prettifyKey(key)
    if not key or key == "" then
        return ""
    end

    local label = key:gsub("(%l)(%u)", "%1 %2")
    label = label:gsub("_", " ")
    label = label:gsub("%s+", " ")
    label = label:gsub("^%l", string.upper)
    return label
end

local function buildStatsEntries()
    statsEntries = {}

    local labelTable = Localization:getTable("metaprogression.stat_labels") or {}
    local seen = {}

    for key, label in pairs(labelTable) do
        local value = PlayerStats:get(key)
        local formatter = statFormatters[key]
        statsEntries[#statsEntries + 1] = {
            id = key,
            label = label,
            value = value,
            valueText = formatter and formatter(value) or formatStatValue(value),
        }
        seen[key] = true
    end

    for key, value in pairs(PlayerStats.data or {}) do
        if not seen[key] then
            local label = prettifyKey(key)
            local formatter = statFormatters[key]
            statsEntries[#statsEntries + 1] = {
                id = key,
                label = label,
                value = value,
                valueText = formatter and formatter(value) or formatStatValue(value),
            }
        end
    end

    table.sort(statsEntries, function(a, b)
        if a.label == b.label then
            return a.id < b.id
        end
        return a.label < b.label
    end)
end

local function findTab(targetId)
    for index, tab in ipairs(tabs) do
        if tab.id == targetId then
            return tab, index
        end
    end

    return nil, nil
end

local function setActiveTab(tabId)
    if activeTab == tabId then
        return
    end

    activeTab = tabId

    if tabId == "stats" then
        buildStatsEntries()
    end

    scrollOffset = 0
    local sw, sh = Screen:get()
    if sw and sh then
        updateScrollBounds(sw, sh)
    end

    local _, buttonIndex = findTab(tabId)
    if buttonIndex then
        buttonList:setFocus(buttonIndex)
    end
end

local function applyFocusedTab(button)
    if not button then
        return
    end

    local action = button.action or button.id
    if action == "tab_experience" or action == "progressionTab_experience" then
        setActiveTab("experience")
    elseif action == "tab_stats" or action == "progressionTab_stats" then
        setActiveTab("stats")
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
    buildStatsEntries()

    local sw, sh = Screen:get()

    local buttons = {}
    local tabCount = #tabs
    local totalTabWidth = tabCount * TAB_WIDTH + math.max(0, tabCount - 1) * TAB_SPACING
    local startX = sw / 2 - totalTabWidth / 2

    for index, tab in ipairs(tabs) do
        local buttonId = "progressionTab_" .. tab.id
        tab.buttonId = buttonId
        local x = startX + (index - 1) * (TAB_WIDTH + TAB_SPACING)

        buttons[#buttons + 1] = {
            id = buttonId,
            x = x,
            y = TAB_Y,
            w = TAB_WIDTH,
            h = TAB_HEIGHT,
            text = Localization:get(tab.labelKey),
            action = tab.action,
        }
    end

    local backButtonY = sh - 90

    buttons[#buttons + 1] = {
        id = "progressionBack",
        x = sw / 2 - UI.spacing.buttonWidth / 2,
        y = backButtonY,
        w = UI.spacing.buttonWidth,
        h = UI.spacing.buttonHeight,
        textKey = "metaprogression.back_to_menu",
        text = Localization:get("metaprogression.back_to_menu"),
        action = "menu",
    }

    buttonList:reset(buttons)

    local _, activeIndex = findTab(activeTab)
    if activeIndex then
        buttonList:setFocus(activeIndex)
    end

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
        if action == "tab_experience" then
            setActiveTab("experience")
        elseif action == "tab_stats" then
            setActiveTab("stats")
        else
            return action
        end
    end
end

local function drawSummaryPanel(sw)
    if not progressionState then
        return
    end

    local panelWidth = CARD_WIDTH
    local panelHeight = 160
    local panelX = (sw - panelWidth) / 2
    local panelY = 120
    local padding = 24

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
    love.graphics.print(totalText, panelX + padding, panelY + padding + 34)
    love.graphics.print(progressLabel, panelX + padding, panelY + padding + 60)

    local barX = panelX + padding
    local barY = panelY + panelHeight - padding - 24
    local barWidth = panelWidth - padding * 2
    local barHeight = 18

    love.graphics.setColor(0, 0, 0, 0.35)
    UI.drawRoundedRect(barX, barY, barWidth, barHeight, 9)

    love.graphics.setColor(Theme.progressColor or {0.55, 0.75, 0.55, 1})
    UI.drawRoundedRect(barX, barY, barWidth * progressRatio, barHeight, 9)

    love.graphics.setColor(border)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 9, 9)
end

local function drawTrack(sw, sh)
    local listX = (sw - CARD_WIDTH) / 2
    local clipY = START_Y
    local clipH = viewportHeight

    if clipH <= 0 then
        return
    end

    love.graphics.push()
    love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

    for index, entry in ipairs(trackEntries) do
        local y = START_Y + scrollOffset + (index - 1) * (CARD_HEIGHT + CARD_SPACING)
        if y + CARD_HEIGHT >= clipY - CARD_HEIGHT and y <= clipY + clipH + CARD_HEIGHT then
            local unlocked = entry.unlocked
            local panelColor = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
            local fillAlpha = unlocked and 0.9 or 0.7

            love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], fillAlpha)
            UI.drawRoundedRect(listX, y, CARD_WIDTH, CARD_HEIGHT, 12)

            local borderColor = unlocked and (Theme.achieveColor or {0.55, 0.75, 0.55, 1}) or (Theme.lockedCardColor or {0.5, 0.35, 0.4, 1})
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", listX, y, CARD_WIDTH, CARD_HEIGHT, 12, 12)

            local textX = listX + 24
            local textY = y + 20

            love.graphics.setFont(UI.fonts.button)
            love.graphics.setColor(Theme.textColor)
            local header = Localization:get("metaprogression.card_level", { level = entry.level or 0 })
            love.graphics.print(header, textX, textY)

            love.graphics.setFont(UI.fonts.body)
            love.graphics.print(entry.name or "", textX, textY + 30)

            local desc = entry.description or ""
            local wrapWidth = CARD_WIDTH - 48
            love.graphics.printf(desc, textX, textY + 58, wrapWidth)

            local statusY = y + CARD_HEIGHT - 32
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

local function drawStatsHeader(sw)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(Localization:get("metaprogression.stats_header"), 0, 150, sw, "center")
end

local function drawStatsList(sw, sh)
    local clipY = START_Y
    local clipH = viewportHeight

    if clipH <= 0 then
        return
    end

    local listX = (sw - CARD_WIDTH) / 2

    love.graphics.push()
    love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

    if #statsEntries == 0 then
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(Theme.textColor)
        love.graphics.printf(Localization:get("metaprogression.stats_empty"), listX, clipY + viewportHeight / 2 - 12, CARD_WIDTH, "center")
    else
        for index, entry in ipairs(statsEntries) do
            local y = START_Y + scrollOffset + (index - 1) * (STAT_CARD_HEIGHT + STAT_CARD_SPACING)
            if y + STAT_CARD_HEIGHT >= clipY - STAT_CARD_HEIGHT and y <= clipY + clipH + STAT_CARD_HEIGHT then
                local panelColor = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
                love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], 0.82)
                UI.drawRoundedRect(listX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12)

                local borderColor = Theme.panelBorder or {0.35, 0.3, 0.5, 1}
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", listX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12, 12)

                love.graphics.setColor(Theme.textColor)
                love.graphics.setFont(UI.fonts.body)
                love.graphics.print(entry.label, listX + 24, y + 16)

                love.graphics.setFont(UI.fonts.button)
                love.graphics.printf(entry.valueText, listX + 24, y + STAT_CARD_HEIGHT - 40, CARD_WIDTH - 48, "right")
            end
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

    if activeTab == "experience" then
        drawSummaryPanel(sw)
        drawTrack(sw, sh)
    else
        drawStatsHeader(sw)
        drawStatsList(sw, sh)
    end

    buttonList:syncUI()

    for _, tab in ipairs(tabs) do
        local id = tab.buttonId
        if id then
            local button = UI.buttons[id]
            if button then
                button.pressed = (activeTab == tab.id)
            end
        end
    end

    for _, button in buttonList:iter() do
        UI.drawButton(button.id)
    end
end

function ProgressionScreen:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function ProgressionScreen:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    if action then
        Audio:playSound("click")
        if action == "tab_experience" then
            setActiveTab("experience")
        elseif action == "tab_stats" then
            setActiveTab("stats")
        else
            return action
        end
    end
end

function ProgressionScreen:wheelmoved(_, dy)
    scrollBy(dy * SCROLL_SPEED)
end

function ProgressionScreen:keypressed(key)
    if key == "up" then
        scrollBy(SCROLL_SPEED)
        applyFocusedTab(buttonList:moveFocus(-1))
    elseif key == "down" then
        scrollBy(-SCROLL_SPEED)
        applyFocusedTab(buttonList:moveFocus(1))
    elseif key == "left" then
        applyFocusedTab(buttonList:moveFocus(-1))
    elseif key == "right" then
        applyFocusedTab(buttonList:moveFocus(1))
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
        applyFocusedTab(buttonList:moveFocus(-1))
    elseif button == "dpleft" then
        applyFocusedTab(buttonList:moveFocus(-1))
    elseif button == "dpdown" then
        scrollBy(-SCROLL_SPEED)
        applyFocusedTab(buttonList:moveFocus(1))
    elseif button == "dpright" then
        applyFocusedTab(buttonList:moveFocus(1))
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
