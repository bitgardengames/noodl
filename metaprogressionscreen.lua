local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local SnakeCosmetics = require("snakecosmetics")
local Achievements = require("achievements")
local PlayerStats = require("playerstats")
local Audio = require("audio")
local Shaders = require("shaders")

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
local COSMETIC_CARD_HEIGHT = 148
local COSMETIC_CARD_SPACING = 24
local COSMETIC_PREVIEW_WIDTH = 128
local COSMETIC_PREVIEW_HEIGHT = 40
local SCROLL_SPEED = 48
local DPAD_REPEAT_INITIAL_DELAY = 0.3
local DPAD_REPEAT_INTERVAL = 0.1
local ANALOG_DEADZONE = 0.35
local TAB_WIDTH = 220
local TAB_HEIGHT = 52
local TAB_SPACING = 16
local TAB_Y = 120 - TAB_HEIGHT - 16

local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0

local heldDpadButton = nil
local heldDpadAction = nil
local heldDpadTimer = 0
local heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local analogAxisDirections = { horizontal = nil, vertical = nil }

local trackEntries = {}
local statsEntries = {}
local cosmeticsEntries = {}
local progressionState = nil
local activeTab = "experience"
local cosmeticsFocusIndex = nil
local hoveredCosmeticIndex = nil
local pressedCosmeticIndex = nil

local tabs = {
    {
        id = "experience",
        action = "tab_experience",
        labelKey = "metaprogression.tabs.experience",
    },
    {
        id = "cosmetics",
        action = "tab_cosmetics",
        labelKey = "metaprogression.tabs.cosmetics",
    },
    {
        id = "stats",
        action = "tab_stats",
        labelKey = "metaprogression.tabs.stats",
    },
}

local BACKGROUND_EFFECT_TYPE = "metaFlux"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function configureBackgroundEffect()
    local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
    if not effect then
        backgroundEffect = nil
        return
    end

    local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
    effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.6

    Shaders.configure(effect, {
        bgColor = Theme.bgColor,
        primaryColor = Theme.progressColor,
        secondaryColor = Theme.accentTextColor,
    })

    backgroundEffect = effect
end

local function drawBackground(sw, sh)
    love.graphics.setColor(Theme.bgColor or {0, 0, 0, 1})
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if not backgroundEffect then
        configureBackgroundEffect()
    end

    if backgroundEffect then
        local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
        Shaders.draw(backgroundEffect, 0, 0, sw, sh, intensity)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function resetHeldDpad()
    heldDpadButton = nil
    heldDpadAction = nil
    heldDpadTimer = 0
    heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
end

local function startHeldDpad(button, action)
    heldDpadButton = button
    heldDpadAction = action
    heldDpadTimer = 0
    heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
end

local function stopHeldDpad(button)
    if heldDpadButton ~= button then
        return
    end

    resetHeldDpad()
end

local function updateHeldDpad(dt)
    if not heldDpadAction then
        return
    end

    heldDpadTimer = heldDpadTimer + dt

    local interval = heldDpadInterval
    while heldDpadTimer >= interval do
        heldDpadTimer = heldDpadTimer - interval
        heldDpadAction()
        heldDpadInterval = DPAD_REPEAT_INTERVAL
        interval = heldDpadInterval
        if interval <= 0 then
            break
        end
    end
end

local function getActiveList()
    if activeTab == "cosmetics" then
        return cosmeticsEntries, COSMETIC_CARD_HEIGHT, COSMETIC_CARD_SPACING
    end

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

local statFormatters = {
    totalTimeAlive = formatDuration,
    longestRunDuration = formatDuration,
    bestFloorClearTime = formatDuration,
    longestFloorClearTime = formatDuration,
}

local hiddenStats = {
    averageFloorClearTime = true,
    bestFruitPerMinute = true,
    averageFruitPerMinute = true,
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
        if not hiddenStats[key] then
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
    end

    for key, value in pairs(PlayerStats.data or {}) do
        if not seen[key] and not hiddenStats[key] then
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

local function clampColorComponent(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function lightenColor(color, amount)
    if type(color) ~= "table" then
        return {1, 1, 1, 1}
    end

    amount = clampColorComponent(amount or 0)

    local r = clampColorComponent((color[1] or 0) + (1 - (color[1] or 0)) * amount)
    local g = clampColorComponent((color[2] or 0) + (1 - (color[2] or 0)) * amount)
    local b = clampColorComponent((color[3] or 0) + (1 - (color[3] or 0)) * amount)
    local a = clampColorComponent(color[4] or 1)

    return {r, g, b, a}
end

local function darkenColor(color, amount)
    if type(color) ~= "table" then
        return {0, 0, 0, 1}
    end

    amount = clampColorComponent(amount or 0)

    local scale = 1 - amount
    local r = clampColorComponent((color[1] or 0) * scale)
    local g = clampColorComponent((color[2] or 0) * scale)
    local b = clampColorComponent((color[3] or 0) * scale)
    local a = clampColorComponent(color[4] or 1)

    return {r, g, b, a}
end

local function resolveAchievementName(id)
    if not id or not Achievements or not Achievements.getDefinition then
        return prettifyKey(id)
    end

    local definition = Achievements:getDefinition(id)
    if not definition then
        return prettifyKey(id)
    end

    if definition.titleKey then
        local title = Localization:get(definition.titleKey)
        if title and title ~= definition.titleKey then
            return title
        end
    end

    if definition.title and definition.title ~= "" then
        return definition.title
    end

    if definition.nameKey then
        local name = Localization:get(definition.nameKey)
        if name and name ~= definition.nameKey then
            return name
        end
    end

    if definition.name and definition.name ~= "" then
        return definition.name
    end

    return prettifyKey(id)
end

local function getSkinRequirementText(skin)
    local unlock = skin and skin.unlock or {}

    if unlock.level then
        return Localization:get("metaprogression.cosmetics.locked_level", { level = unlock.level })
    elseif unlock.achievement then
        local achievementName = resolveAchievementName(unlock.achievement)
        return Localization:get("metaprogression.cosmetics.locked_achievement", {
            name = achievementName,
        })
    end

    return Localization:get("metaprogression.cosmetics.locked_generic")
end

local function resolveSkinStatus(skin)
    if not skin then
        return "", "", Theme.textColor
    end

    if skin.selected then
        return Localization:get("metaprogression.cosmetics.equipped"), nil, Theme.accentTextColor or Theme.textColor
    end

    if skin.unlocked then
        return Localization:get("metaprogression.status_unlocked"), Localization:get("metaprogression.cosmetics.equip_hint"), Theme.progressColor or Theme.textColor
    end

    return Localization:get("metaprogression.cosmetics.locked_label"), getSkinRequirementText(skin), Theme.lockedCardColor or Theme.warningColor or Theme.textColor
end

local function buildCosmeticsEntries()
    cosmeticsEntries = {}
    hoveredCosmeticIndex = nil
    pressedCosmeticIndex = nil
    cosmeticsFocusIndex = nil

    if not (SnakeCosmetics and SnakeCosmetics.getSkins) then
        return
    end

    local skins = SnakeCosmetics:getSkins() or {}
    local selectedIndex

    for _, skin in ipairs(skins) do
        local entry = {
            id = skin.id,
            skin = skin,
        }
        entry.statusLabel, entry.detailText, entry.statusColor = resolveSkinStatus(skin)
        cosmeticsEntries[#cosmeticsEntries + 1] = entry

        if skin.selected then
            selectedIndex = #cosmeticsEntries
        end
    end

    if selectedIndex then
        cosmeticsFocusIndex = selectedIndex
    elseif #cosmeticsEntries > 0 then
        cosmeticsFocusIndex = 1
    end
end

local function updateCosmeticsLayout(sw)
    if not sw then
        sw = select(1, Screen:get())
    end

    if not sw then
        return
    end

    local listX = (sw - CARD_WIDTH) / 2

    for index, entry in ipairs(cosmeticsEntries) do
        local y = START_Y + scrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
        entry.bounds = {
            x = listX,
            y = y,
            w = CARD_WIDTH,
            h = COSMETIC_CARD_HEIGHT,
        }
    end
end

local function ensureCosmeticVisible(index)
    if activeTab ~= "cosmetics" or not index then
        return
    end

    if viewportHeight <= 0 then
        return
    end

    local itemHeight = COSMETIC_CARD_HEIGHT
    local spacing = COSMETIC_CARD_SPACING
    local top = START_Y + scrollOffset + (index - 1) * (itemHeight + spacing)
    local bottom = top + itemHeight
    local viewportTop = START_Y
    local viewportBottom = START_Y + viewportHeight

    if top < viewportTop then
        scrollOffset = scrollOffset + (viewportTop - top)
    elseif bottom > viewportBottom then
        scrollOffset = scrollOffset - (bottom - viewportBottom)
    end

    if scrollOffset < minScrollOffset then
        scrollOffset = minScrollOffset
    elseif scrollOffset > 0 then
        scrollOffset = 0
    end

    updateCosmeticsLayout()
end

local function setCosmeticsFocus(index, playSound)
    if not index or not cosmeticsEntries[index] then
        return
    end

    if cosmeticsFocusIndex ~= index and playSound then
        Audio:playSound("hover")
    end

    cosmeticsFocusIndex = index
    ensureCosmeticVisible(index)
end

local function moveCosmeticsFocus(delta)
    if not delta or delta == 0 or #cosmeticsEntries == 0 then
        return
    end

    local index = cosmeticsFocusIndex or 1
    index = math.max(1, math.min(#cosmeticsEntries, index + delta))
    setCosmeticsFocus(index, true)
end

local function activateCosmetic(index)
    local entry = index and cosmeticsEntries[index]
    if not entry or not entry.skin then
        return false
    end

    if not entry.skin.unlocked then
        return false
    end

    if not SnakeCosmetics or not SnakeCosmetics.setActiveSkin then
        return false
    end

    local skinId = entry.skin.id
    local changed = SnakeCosmetics:setActiveSkin(skinId)
    if changed then
        buildCosmeticsEntries()
        local newIndex
        for idx, cosmetic in ipairs(cosmeticsEntries) do
            if cosmetic.skin and cosmetic.skin.id == skinId then
                newIndex = idx
                break
            end
        end
        if newIndex then
            setCosmeticsFocus(newIndex)
        end
        local sw, sh = Screen:get()
        if sw and sh then
            updateScrollBounds(sw, sh)
        end
    end

    return changed
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
    elseif tabId == "cosmetics" then
        buildCosmeticsEntries()
    else
        hoveredCosmeticIndex = nil
        pressedCosmeticIndex = nil
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

    if tabId == "cosmetics" and cosmeticsFocusIndex then
        ensureCosmeticVisible(cosmeticsFocusIndex)
    end
end

local function applyFocusedTab(button)
    if not button then
        return
    end

    local action = button.action or button.id
    if action == "tab_experience" or action == "progressionTab_experience" then
        setActiveTab("experience")
    elseif action == "tab_cosmetics" or action == "progressionTab_cosmetics" then
        setActiveTab("cosmetics")
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

local function dpadScrollUp()
    if activeTab == "cosmetics" then
        moveCosmeticsFocus(-1)
    else
        scrollBy(SCROLL_SPEED)
        applyFocusedTab(buttonList:moveFocus(-1))
    end
end

local function dpadScrollDown()
    if activeTab == "cosmetics" then
        moveCosmeticsFocus(1)
    else
        scrollBy(-SCROLL_SPEED)
        applyFocusedTab(buttonList:moveFocus(1))
    end
end

local analogDirections = {
    dpup = { id = "analog_dpup", repeatable = true, action = dpadScrollUp },
    dpdown = { id = "analog_dpdown", repeatable = true, action = dpadScrollDown },
    dpleft = {
        id = "analog_dpleft",
        repeatable = false,
        action = function()
            applyFocusedTab(buttonList:moveFocus(-1))
        end,
    },
    dpright = {
        id = "analog_dpright",
        repeatable = false,
        action = function()
            applyFocusedTab(buttonList:moveFocus(1))
        end,
    },
}

local analogAxisMap = {
    leftx = { slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright },
    rightx = { slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright },
    lefty = { slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown },
    righty = { slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown },
    [1] = { slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright },
    [2] = { slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown },
}

local function activateAnalogDirection(direction)
    if not direction then
        return
    end

    direction.action()

    if direction.repeatable then
        startHeldDpad(direction.id, direction.action)
    end
end

local function resetAnalogDirections()
    for slot, direction in pairs(analogAxisDirections) do
        if direction and direction.repeatable then
            stopHeldDpad(direction.id)
        end
        analogAxisDirections[slot] = nil
    end
end

local function handleGamepadAxis(axis, value)
    local mapping = analogAxisMap[axis]
    if not mapping then
        return
    end

    local previous = analogAxisDirections[mapping.slot]
    local direction

    if value >= ANALOG_DEADZONE then
        direction = mapping.positive
    elseif value <= -ANALOG_DEADZONE then
        direction = mapping.negative
    end

    if previous == direction then
        return
    end

    if previous and previous.repeatable then
        stopHeldDpad(previous.id)
    end

    analogAxisDirections[mapping.slot] = direction or nil

    activateAnalogDirection(direction)
end

function ProgressionScreen:enter()
    Screen:update()
    UI.clearButtons()

    configureBackgroundEffect()

    trackEntries = MetaProgression:getUnlockTrack() or {}
    progressionState = MetaProgression:getState()
    buildStatsEntries()

    if SnakeCosmetics and SnakeCosmetics.load then
        local metaLevel = progressionState and progressionState.level or nil
        local ok, err = pcall(function()
            SnakeCosmetics:load({ metaLevel = metaLevel })
        end)
        if not ok then
            print("[metaprogressionscreen] failed to load cosmetics:", err)
        end
    end

    buildCosmeticsEntries()

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
    resetHeldDpad()
    resetAnalogDirections()
end

function ProgressionScreen:leave()
    UI.clearButtons()
    resetHeldDpad()
    resetAnalogDirections()
end

function ProgressionScreen:update(dt)
    local mx, my = love.mouse.getPosition()
    buttonList:updateHover(mx, my)

    if activeTab == "cosmetics" then
        local sw = select(1, Screen:get())
        updateCosmeticsLayout(sw)

        hoveredCosmeticIndex = nil
        for index, entry in ipairs(cosmeticsEntries) do
            local bounds = entry.bounds
            if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, mx, my) then
                hoveredCosmeticIndex = index
                break
            end
        end

        if hoveredCosmeticIndex and hoveredCosmeticIndex ~= cosmeticsFocusIndex then
            cosmeticsFocusIndex = hoveredCosmeticIndex
        end
    end

    updateHeldDpad(dt)
end

local function handleConfirm()
    local action = buttonList:activateFocused()
    if action then
        Audio:playSound("click")
        if action == "tab_experience" then
            setActiveTab("experience")
        elseif action == "tab_cosmetics" then
            setActiveTab("cosmetics")
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

local function drawCosmeticsHeader(sw)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(Localization:get("metaprogression.cosmetics.header"), 0, 150, sw, "center")
end

local function drawCosmeticsList(sw, sh)
    local clipY = START_Y
    local clipH = viewportHeight

    if clipH <= 0 then
        return
    end

    updateCosmeticsLayout(sw)

    local listX = (sw - CARD_WIDTH) / 2

    love.graphics.push()
    love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

    for index, entry in ipairs(cosmeticsEntries) do
        local y = START_Y + scrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
        entry.bounds = entry.bounds or {}
        entry.bounds.x = listX
        entry.bounds.y = y
        entry.bounds.w = CARD_WIDTH
        entry.bounds.h = COSMETIC_CARD_HEIGHT

        if y + COSMETIC_CARD_HEIGHT >= clipY - COSMETIC_CARD_HEIGHT and y <= clipY + clipH + COSMETIC_CARD_HEIGHT then
            local skin = entry.skin or {}
            local unlocked = skin.unlocked
            local selected = skin.selected
            local isFocused = (index == cosmeticsFocusIndex)
            local isHovered = (index == hoveredCosmeticIndex)

            local basePanel = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
            local fillColor
            if selected then
                fillColor = lightenColor(basePanel, 0.28)
            elseif unlocked then
                fillColor = lightenColor(basePanel, 0.14)
            else
                fillColor = darkenColor(basePanel, 0.25)
            end

            if isFocused or isHovered then
                fillColor = lightenColor(fillColor, 0.06)
            end

            love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.92)
            UI.drawRoundedRect(listX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14)

            local borderColor = Theme.panelBorder or {0.35, 0.30, 0.50, 1.0}
            if selected then
                borderColor = Theme.accentTextColor or borderColor
            elseif unlocked then
                borderColor = Theme.progressColor or borderColor
            elseif Theme.lockedCardColor then
                borderColor = Theme.lockedCardColor
            end

            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            love.graphics.setLineWidth(isFocused and 3 or 2)
            love.graphics.rectangle("line", listX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14, 14)

            if isFocused then
                local highlight = Theme.highlightColor or {1, 1, 1, 0.08}
                love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.08) + 0.04)
                UI.drawRoundedRect(listX + 6, y + 6, CARD_WIDTH - 12, COSMETIC_CARD_HEIGHT - 12, 12)
            end

            local skinColors = skin.colors or {}
            local bodyColor = skinColors.body or Theme.snakeDefault or {0.45, 0.85, 0.70, 1}
            local outlineColor = skinColors.outline or {0.05, 0.15, 0.12, 1}
            local glowColor = skinColors.glow or Theme.accentTextColor or {0.95, 0.76, 0.48, 1}

            local previewX = listX + 28
            local previewY = y + (COSMETIC_CARD_HEIGHT - COSMETIC_PREVIEW_HEIGHT) / 2
            local previewW = COSMETIC_PREVIEW_WIDTH
            local previewH = COSMETIC_PREVIEW_HEIGHT

            if unlocked then
                love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], (glowColor[4] or 1) * 0.45)
                love.graphics.setLineWidth(6)
                love.graphics.rectangle("line", previewX - 6, previewY - 6, previewW + 12, previewH + 12, previewH / 2 + 6, previewH / 2 + 6)
            end

            love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], bodyColor[4] or 1)
            UI.drawRoundedRect(previewX, previewY, previewW, previewH, previewH / 2)

            love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4] or 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", previewX, previewY, previewW, previewH, previewH / 2, previewH / 2)

            love.graphics.setLineWidth(1)

            local textX = previewX + previewW + 24
            local textWidth = CARD_WIDTH - (textX - listX) - 28

            love.graphics.setFont(UI.fonts.button)
            love.graphics.setColor(Theme.textColor)
            love.graphics.printf(skin.name or skin.id or "", textX, y + 20, textWidth, "left")

            love.graphics.setFont(UI.fonts.body)
            love.graphics.setColor(Theme.mutedTextColor or Theme.textColor)
            love.graphics.printf(skin.description or "", textX, y + 52, textWidth, "left")

            local statusColor = entry.statusColor or Theme.textColor
            love.graphics.setFont(UI.fonts.caption)
            love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], statusColor[4] or 1)
            love.graphics.printf(entry.statusLabel or "", textX, y + COSMETIC_CARD_HEIGHT - 40, textWidth, "left")

            if entry.detailText and entry.detailText ~= "" then
                love.graphics.setFont(UI.fonts.small)
                love.graphics.setColor(Theme.mutedTextColor or Theme.textColor)
                love.graphics.printf(entry.detailText, textX, y + COSMETIC_CARD_HEIGHT - 24, textWidth, "left")
            end
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

    drawBackground(sw, sh)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(Localization:get("metaprogression.title"), 0, 48, sw, "center")

    if activeTab == "experience" then
        drawSummaryPanel(sw)
        drawTrack(sw, sh)
    elseif activeTab == "cosmetics" then
        drawCosmeticsHeader(sw)
        drawCosmeticsList(sw, sh)
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

    if activeTab == "cosmetics" and button == 1 then
        local sw = select(1, Screen:get())
        updateCosmeticsLayout(sw)

        pressedCosmeticIndex = nil
        for index, entry in ipairs(cosmeticsEntries) do
            local bounds = entry.bounds
            if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
                pressedCosmeticIndex = index
                setCosmeticsFocus(index)
                break
            end
        end
    end
end

function ProgressionScreen:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    if action then
        Audio:playSound("click")
        if action == "tab_experience" then
            setActiveTab("experience")
        elseif action == "tab_cosmetics" then
            setActiveTab("cosmetics")
        elseif action == "tab_stats" then
            setActiveTab("stats")
        else
            return action
        end
        return
    end

    if activeTab ~= "cosmetics" or button ~= 1 then
        pressedCosmeticIndex = nil
        return
    end

    local sw = select(1, Screen:get())
    updateCosmeticsLayout(sw)

    local releasedIndex
    for index, entry in ipairs(cosmeticsEntries) do
        local bounds = entry.bounds
        if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
            releasedIndex = index
            break
        end
    end

    if releasedIndex and releasedIndex == pressedCosmeticIndex then
        setCosmeticsFocus(releasedIndex)
        local changed = activateCosmetic(releasedIndex)
        Audio:playSound(changed and "click" or "hover")
    end

    pressedCosmeticIndex = nil
end

function ProgressionScreen:wheelmoved(_, dy)
    scrollBy(dy * SCROLL_SPEED)
end

function ProgressionScreen:keypressed(key)
    if activeTab == "cosmetics" then
        if key == "up" then
            moveCosmeticsFocus(-1)
            return
        elseif key == "down" then
            moveCosmeticsFocus(1)
            return
        end
    end

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
        if activeTab == "cosmetics" and cosmeticsFocusIndex then
            local changed = activateCosmetic(cosmeticsFocusIndex)
            Audio:playSound(changed and "click" or "hover")
            return
        end
        return handleConfirm()
    end
end

function ProgressionScreen:gamepadpressed(_, button)
    if button == "dpup" then
        dpadScrollUp()
        startHeldDpad(button, dpadScrollUp)
    elseif button == "dpleft" then
        applyFocusedTab(buttonList:moveFocus(-1))
    elseif button == "dpdown" then
        dpadScrollDown()
        startHeldDpad(button, dpadScrollDown)
    elseif button == "dpright" then
        applyFocusedTab(buttonList:moveFocus(1))
    elseif button == "a" or button == "start" then
        if activeTab == "cosmetics" and cosmeticsFocusIndex then
            local changed = activateCosmetic(cosmeticsFocusIndex)
            Audio:playSound(changed and "click" or "hover")
            return
        end
        return handleConfirm()
    elseif button == "b" then
        Audio:playSound("click")
        return "menu"
    end
end

ProgressionScreen.joystickpressed = ProgressionScreen.gamepadpressed

function ProgressionScreen:gamepadaxis(_, axis, value)
    handleGamepadAxis(axis, value)
end

ProgressionScreen.joystickaxis = ProgressionScreen.gamepadaxis

function ProgressionScreen:gamepadreleased(_, button)
    if button == "dpup" or button == "dpdown" then
        stopHeldDpad(button)
    end
end

ProgressionScreen.joystickreleased = ProgressionScreen.gamepadreleased

function ProgressionScreen:resize()
    local sw, sh = Screen:get()
    updateScrollBounds(sw, sh)
end

return ProgressionScreen
