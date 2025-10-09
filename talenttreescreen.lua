local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Localization = require("localization")
local TalentTree = require("talenttree")
local Audio = require("audio")
local Shaders = require("shaders")

local TalentTreeScreen = {
    transitionDuration = 0.35,
}

local unpack = table.unpack or unpack

local CARD_WIDTH = 340
local CARD_MIN_HEIGHT = 212
local CARD_SPACING = 26
local CARD_PADDING = 20
local CARD_HEADING_SPACING = 6
local CARD_DESC_LIST_SPACING = 10
local CARD_LIST_SECTION_SPACING = 8
local CARD_LIST_ITEM_SPACING = 6
local CARD_TAG_OFFSET = 6
local HEADER_SPACING = 6
local OPTION_FOOTER_SPACING = 36
local TIER_SPACING = 68
local PANEL_PADDING = 38
local PANEL_WIDTH = 1140
local PANEL_TOP = 136
local PANEL_BOTTOM_MARGIN = 110
local CONTENT_TOP_PADDING = 12
local SCROLL_SPEED = 60
local DPAD_REPEAT_INITIAL_DELAY = 0.3
local DPAD_REPEAT_INTERVAL = 0.12
local ANALOG_DEADZONE = 0.35
local FOOTER_BUTTON_SPACING = 18
local SUMMARY_COLUMN_MIN_WIDTH = 260
local SUMMARY_COLUMN_GAP = 28
local SUMMARY_TWO_COLUMN_MIN_WIDTH = SUMMARY_COLUMN_MIN_WIDTH * 2 + SUMMARY_COLUMN_GAP
local SUMMARY_SECTION_SPACING = 10
local SUMMARY_LINE_SPACING = 2
local SUMMARY_HEADING_SPACING = 6
local SUMMARY_BOTTOM_SPACING = 18

local tiers = {}
local selections = {}
local buttons = {}
local focusedIndex = nil
local hoveredIndex = nil
local pressedButtonId = nil
local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0
local layout = {
    panelX = 0,
    panelY = 0,
    panelW = 0,
    panelH = 0,
    contentX = 0,
    contentY = 0,
    contentW = 0,
    summaryHeight = 0,
    summaryOffset = 0,
}
local tierMetrics = {}
local tierLayout = {}
local summaryLayout = {
    height = 0,
    hasContent = false,
    lines = {},
    picks = {},
    twoColumn = false,
    columnWidth = 0,
    headingHeight = 0,
    contentHeight = 0,
    lineHeight = 0,
}

local refreshSummaryLayout

local function selectionsMatchDefaults()
    if not tiers or #tiers == 0 then
        return true
    end

    local defaults = TalentTree:getDefaultSelections() or {}
    for _, tier in ipairs(tiers) do
        local defaultId = defaults[tier.id]
        if selections[tier.id] ~= defaultId then
            return false
        end
    end

    return true
end

local heldDpadButton = nil
local heldDpadAction = nil
local heldDpadTimer = 0
local heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local analogAxisDirections = { horizontal = nil, vertical = nil }

local backgroundEffectType = "metaFlux"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function configureBackgroundEffect()
    local effect = Shaders.ensure(backgroundEffectCache, backgroundEffectType)
    if not effect then
        backgroundEffect = nil
        return
    end

    local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
    effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.55

    Shaders.configure(effect, {
        bgColor = Theme.bgColor,
        primaryColor = Theme.progressColor,
        secondaryColor = Theme.accentTextColor,
    })

    backgroundEffect = effect
end

local function drawBackground(sw, sh)
    love.graphics.setColor(Theme.bgColor)
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

local function measureOptionMetrics(option)
    option = option or {}

    local headingFont = UI.fonts.heading
    local bodyFont = UI.fonts.body
    local captionFont = UI.fonts.caption
    local availableWidth = CARD_WIDTH - CARD_PADDING * 2

    local headingHeight = headingFont:getHeight()
    local totalHeight = CARD_PADDING + headingHeight

    local description = option.description or ""
    local descHeight = 0
    if description ~= "" then
        local _, wrapped = bodyFont:getWrap(description, availableWidth)
        local lines = math.max(1, #wrapped)
        descHeight = lines * bodyFont:getHeight()
        totalHeight = totalHeight + CARD_HEADING_SPACING + descHeight
    end

    local bonusHeights = {}
    local penaltyHeights = {}
    local hasBonuses = option.bonuses and #option.bonuses > 0
    local hasPenalties = option.penalties and #option.penalties > 0
    local listSpacing = 0

    if hasBonuses or hasPenalties then
        if descHeight > 0 then
            listSpacing = CARD_DESC_LIST_SPACING
        else
            listSpacing = CARD_LIST_SECTION_SPACING
        end
        totalHeight = totalHeight + listSpacing
    end

    if hasBonuses then
        for index, bonus in ipairs(option.bonuses) do
            local text = "• " .. bonus
            local _, wrapped = bodyFont:getWrap(text, availableWidth)
            local lines = math.max(1, #wrapped)
            local height = lines * bodyFont:getHeight()
            bonusHeights[index] = height
            totalHeight = totalHeight + height
            if index < #option.bonuses then
                totalHeight = totalHeight + CARD_LIST_ITEM_SPACING
            end
        end
    end

    if hasPenalties then
        if hasBonuses then
            totalHeight = totalHeight + CARD_LIST_SECTION_SPACING
        end

        for index, penalty in ipairs(option.penalties) do
            local text = "• " .. penalty
            local _, wrapped = bodyFont:getWrap(text, availableWidth)
            local lines = math.max(1, #wrapped)
            local height = lines * bodyFont:getHeight()
            penaltyHeights[index] = height
            totalHeight = totalHeight + height
            if index < #option.penalties then
                totalHeight = totalHeight + CARD_LIST_ITEM_SPACING
            end
        end
    end

    totalHeight = totalHeight + CARD_PADDING + captionFont:getHeight() + CARD_TAG_OFFSET

    local metrics = {
        height = math.max(totalHeight, CARD_MIN_HEIGHT),
        descHeight = descHeight,
        bonusHeights = bonusHeights,
        penaltyHeights = penaltyHeights,
        hasBonuses = hasBonuses,
        hasPenalties = hasPenalties,
        listStartSpacing = listSpacing,
        availableWidth = availableWidth,
    }

    return metrics
end

local function rebuildTierMetrics()
    tierMetrics = {}

    for tierIndex, tier in ipairs(tiers) do
        local metrics = { options = {}, cardHeight = CARD_MIN_HEIGHT }
        for optionIndex, option in ipairs(tier.options or {}) do
            local optionMetrics = measureOptionMetrics(option)
            metrics.options[optionIndex] = optionMetrics
            if optionMetrics.height > (metrics.cardHeight or CARD_MIN_HEIGHT) then
                metrics.cardHeight = optionMetrics.height
            end
        end
        tierMetrics[tierIndex] = metrics
    end
end

local function getTierHeaderHeight(tier, contentWidth)
    local headingHeight = UI.fonts.heading:getHeight()
    local height = headingHeight

    local description = tier and tier.description or ""
    if description ~= "" and contentWidth > 0 then
        local _, wrapped = UI.fonts.body:getWrap(description, contentWidth)
        local lines = math.max(1, #wrapped)
        height = height + HEADER_SPACING + lines * UI.fonts.body:getHeight()
    end

    return height
end

local function updateFocusVisuals()
    for index, button in ipairs(buttons) do
        local focused = (focusedIndex == index)
        button.focused = focused
        UI.setButtonFocus(button.id, focused)
    end
end

local function clampScroll()
    if scrollOffset < minScrollOffset then
        scrollOffset = minScrollOffset
    elseif scrollOffset > 0 then
        scrollOffset = 0
    end
end

local function ensureFocusVisible(button)
    if not button or button.type ~= "option" then
        return
    end

    local padding = 32
    local top = button.contentY + scrollOffset
    local bottom = button.contentBottom + scrollOffset

    if top < padding then
        scrollOffset = math.min(0, scrollOffset + (padding - top))
    elseif bottom > viewportHeight - padding then
        scrollOffset = math.max(minScrollOffset, scrollOffset - (bottom - (viewportHeight - padding)))
    end

    clampScroll()
end

local function setFocus(index, opts)
    if not index or not buttons[index] then
        return
    end

    focusedIndex = index
    updateFocusVisuals()

    if not (opts and opts.skipScroll) then
        ensureFocusVisible(buttons[index])
    end

    return buttons[index]
end

local function focusFirstSelectable()
    if #buttons == 0 then
        focusedIndex = nil
        return
    end

    for index, button in ipairs(buttons) do
        if button.type ~= "spacer" then
            return setFocus(index, { skipScroll = true })
        end
    end

    setFocus(1, { skipScroll = true })
end

local function findOptionButton(tierIndex, optionIndex)
    for index, button in ipairs(buttons) do
        if button.type == "option" and button.tierIndex == tierIndex and button.optionIndex == optionIndex then
            return button, index
        end
    end
end

local function findButtonByType(buttonType)
    for index, button in ipairs(buttons) do
        if button.type == buttonType then
            return button, index
        end
    end
end

local function moveFocusHorizontal(delta)
    if not delta or delta == 0 then
        return
    end

    local current = buttons[focusedIndex]
    if not current then
        return
    end

    if current.type == "back" or current.type == "reset" then
        local targetType
        if delta > 0 and current.type == "reset" then
            targetType = "back"
        elseif delta < 0 and current.type == "back" then
            targetType = "reset"
        end

        if targetType then
            local _, index = findButtonByType(targetType)
            if index then
                setFocus(index, { skipScroll = true })
            end
        end

        return
    end

    if current.type ~= "option" then
        return
    end

    local tier = tiers[current.tierIndex]
    if not tier then
        return
    end

    local count = #tier.options
    if count <= 1 then
        return
    end

    local targetOption = current.optionIndex + delta
    if targetOption < 1 then
        targetOption = 1
    elseif targetOption > count then
        targetOption = count
    end

    local _, index = findOptionButton(current.tierIndex, targetOption)
    if index then
        setFocus(index)
    end
end

local function moveFocusVertical(delta)
    if not delta or delta == 0 then
        return
    end

    local current = buttons[focusedIndex]
    if not current then
        return
    end

    if current.type == "back" or current.type == "reset" then
        if delta < 0 then
            local lastTier = #tiers
            if lastTier > 0 then
                local targetTier = lastTier
                local targetOption = selections[tiers[targetTier].id]
                local tier = tiers[targetTier]
                local optionIndex = 1
                if targetOption then
                    for idx, opt in ipairs(tier.options) do
                        if opt.id == targetOption then
                            optionIndex = idx
                            break
                        end
                    end
                end
                local _, index = findOptionButton(targetTier, optionIndex)
                if index then
                    setFocus(index)
                end
            end
        elseif delta > 0 and current.type == "reset" then
            local _, backIndex = findButtonByType("back")
            if backIndex then
                setFocus(backIndex, { skipScroll = true })
            end
        end
        return
    end

    local targetTierIndex = current.tierIndex + delta
    if targetTierIndex < 1 then
        return
    end

    if targetTierIndex > #tiers then
        local _, resetIndex = findButtonByType("reset")
        if resetIndex then
            setFocus(resetIndex, { skipScroll = true })
            return
        end

        local _, backIndex = findButtonByType("back")
        if backIndex then
            setFocus(backIndex, { skipScroll = true })
            return
        end
        return
    end

    local tier = tiers[targetTierIndex]
    if not tier then
        return
    end

    local preferredOption = current.optionIndex
    if tier.options[preferredOption] == nil then
        preferredOption = math.min(preferredOption, #tier.options)
        if preferredOption <= 0 then
            preferredOption = 1
        end
    end

    local _, index = findOptionButton(targetTierIndex, preferredOption)
    if index then
        setFocus(index)
    end
end

local function addScroll(delta)
    if not delta or delta == 0 then
        return
    end

    scrollOffset = scrollOffset + delta
    clampScroll()
end

local function rebuildButtons()
    tiers = TalentTree:getTiers() or {}
    selections = TalentTree:getSelections() or {}
    buttons = {}
    tierLayout = {}

    for tierIndex, tier in ipairs(tiers) do
        for optionIndex, option in ipairs(tier.options or {}) do
            buttons[#buttons + 1] = {
                id = string.format("talent_option_%s_%s", tier.id, option.id),
                type = "option",
                tier = tier,
                option = option,
                tierIndex = tierIndex,
                optionIndex = optionIndex,
                x = 0,
                y = 0,
                w = CARD_WIDTH,
                h = CARD_MIN_HEIGHT,
                contentY = 0,
                contentBottom = 0,
            }
        end
    end

    local resetLabel = Localization:get("talents.reset")
    if resetLabel == "talents.reset" then
        resetLabel = "Reset to defaults"
    end

    buttons[#buttons + 1] = {
        id = "talent_reset",
        type = "reset",
        label = resetLabel,
        baseLabel = resetLabel,
        x = 0,
        y = 0,
        w = UI.spacing.buttonWidth,
        h = UI.spacing.buttonHeight,
    }

    local backLabel = Localization:get("talents.back")
    if backLabel == "talents.back" then
        backLabel = Localization:get("common.back_to_menu")
    end

    buttons[#buttons + 1] = {
        id = "talent_back",
        type = "back",
        label = backLabel,
        x = 0,
        y = 0,
        w = UI.spacing.buttonWidth,
        h = UI.spacing.buttonHeight,
    }

    rebuildTierMetrics()
    focusFirstSelectable()
end

local function updateLayout()
    local sw, sh = Screen:get()

    layout.panelW = math.min(PANEL_WIDTH, sw - 120)
    layout.panelX = math.floor((sw - layout.panelW) / 2)
    layout.panelY = PANEL_TOP
    layout.panelH = math.max(420, sh - PANEL_TOP - PANEL_BOTTOM_MARGIN)
    refreshSummaryLayout()

    layout.summaryHeight = summaryLayout.height or 0
    if layout.summaryHeight < 0 then
        layout.summaryHeight = 0
    end

    layout.summaryOffset = layout.summaryHeight > 0 and (layout.summaryHeight + SUMMARY_BOTTOM_SPACING) or 0
    layout.contentX = layout.panelX + PANEL_PADDING
    layout.contentY = layout.panelY + PANEL_PADDING + layout.summaryOffset
    layout.contentW = layout.panelW - PANEL_PADDING * 2

    viewportHeight = math.max(0, layout.panelH - PANEL_PADDING * 2 - layout.summaryOffset)

    local yCursor = CONTENT_TOP_PADDING
    for tierIndex, tier in ipairs(tiers) do
        local tierMetric = tierMetrics[tierIndex] or { cardHeight = CARD_MIN_HEIGHT, options = {} }
        local headerHeight = getTierHeaderHeight(tier, layout.contentW)
        local cardHeight = tierMetric.cardHeight or CARD_MIN_HEIGHT
        local optionStart = yCursor + headerHeight
        local tierHeight = headerHeight + cardHeight + OPTION_FOOTER_SPACING

        tierLayout[tierIndex] = {
            top = yCursor,
            headerHeight = headerHeight,
            optionStart = optionStart,
            cardHeight = cardHeight,
        }

        local optionCount = #tier.options
        local totalWidth = optionCount * CARD_WIDTH + math.max(0, optionCount - 1) * CARD_SPACING
        local startX = layout.contentX + math.max(0, (layout.contentW - totalWidth) / 2)

        for optionIndex = 1, optionCount do
            local button, index = findOptionButton(tierIndex, optionIndex)
            if button and index then
                local optionMetrics = tierMetric.options and tierMetric.options[optionIndex] or nil
                button.w = CARD_WIDTH
                button.h = cardHeight
                button.contentY = optionStart
                button.contentBottom = optionStart + cardHeight
                button.metrics = optionMetrics
                button.x = startX + (optionIndex - 1) * (CARD_WIDTH + CARD_SPACING)
                button.y = layout.contentY + scrollOffset + optionStart
                button.visible = button.y + button.h >= layout.contentY and button.y <= layout.contentY + viewportHeight
                UI.registerButton(button.id, button.x, button.y, button.w, button.h, button.option.name)
            end
        end

        yCursor = yCursor + tierHeight + TIER_SPACING
    end

    for idx = #tiers + 1, #tierLayout do
        tierLayout[idx] = nil
    end

    if #tiers > 0 then
        yCursor = yCursor - TIER_SPACING
    end

    contentHeight = yCursor
    minScrollOffset = math.min(0, viewportHeight - contentHeight)
    clampScroll()

    local resetButton, resetIndex = findButtonByType("reset")
    local backButton, backIndex = findButtonByType("back")
    local footerBottom = layout.panelY + layout.panelH - PANEL_PADDING
    local buttonHeight = UI.spacing.buttonHeight

    if resetButton and backButton then
        local availableWidth = layout.panelW - PANEL_PADDING * 2
        local spacing = FOOTER_BUTTON_SPACING
        local buttonWidth = math.min(UI.spacing.buttonWidth * 1.2, (availableWidth - spacing) / 2)

        resetButton.w = buttonWidth
        resetButton.h = buttonHeight
        resetButton.x = layout.panelX + PANEL_PADDING
        resetButton.y = footerBottom - buttonHeight

        backButton.w = buttonWidth
        backButton.h = buttonHeight
        backButton.x = layout.panelX + layout.panelW - PANEL_PADDING - buttonWidth
        backButton.y = resetButton.y
    elseif resetButton then
        local buttonWidth = math.min(UI.spacing.buttonWidth * 1.4, layout.panelW - PANEL_PADDING * 2)
        resetButton.w = buttonWidth
        resetButton.h = buttonHeight
        resetButton.x = layout.panelX + (layout.panelW - buttonWidth) / 2
        resetButton.y = footerBottom - buttonHeight
    elseif backButton then
        local buttonWidth = math.min(UI.spacing.buttonWidth * 1.4, layout.panelW - PANEL_PADDING * 2)
        backButton.w = buttonWidth
        backButton.h = buttonHeight
        backButton.x = layout.panelX + (layout.panelW - buttonWidth) / 2
        backButton.y = footerBottom - buttonHeight
    end

    if resetButton then
        local usingDefaults = selectionsMatchDefaults()
        resetButton.disabled = usingDefaults or nil
        local baseLabel = resetButton.baseLabel or resetButton.label
        local appliedLabel = Localization:get("talents.reset_applied")
        if appliedLabel == "talents.reset_applied" then
            appliedLabel = "Defaults applied"
        end
        local displayLabel = usingDefaults and appliedLabel or baseLabel
        resetButton.label = displayLabel
        UI.registerButton(resetButton.id, resetButton.x, resetButton.y, resetButton.w, resetButton.h, displayLabel)
        if resetIndex then
            UI.setButtonFocus(resetButton.id, focusedIndex == resetIndex)
        end
    end

    if backButton then
        UI.registerButton(backButton.id, backButton.x, backButton.y, backButton.w, backButton.h, backButton.label)
        if backIndex then
            UI.setButtonFocus(backButton.id, focusedIndex == backIndex)
        end
    end
end

local function buildLine(text, color)
    if not text or text == "" then
        return nil
    end

    return { text = text, color = color }
end

local function getOrientationColor(amount, orientation)
    orientation = orientation or 1
    if orientation < 0 then
        if amount <= 0 then
            return Theme.progressColor
        else
            return Theme.warningColor
        end
    end

    if amount >= 0 then
        return Theme.progressColor
    else
        return Theme.warningColor
    end
end

local function formatSignedLine(label, value, opts)
    opts = opts or {}
    local amount = value or 0
    local epsilon = opts.epsilon or 0.01
    if math.abs(amount) <= epsilon then
        return nil
    end

    local format = opts.format or "%+g"
    local formatted = string.format(format, amount)
    local suffix = opts.suffix
    if suffix and suffix ~= "" then
        formatted = formatted .. suffix
    end

    local color = getOrientationColor(amount, opts.orientation)
    return buildLine(string.format("%s %s", label, formatted), color)
end

local function formatMultiplierLine(label, multiplier, opts)
    opts = opts or {}
    multiplier = multiplier or 1
    local epsilon = opts.epsilon or 0.01
    if math.abs(multiplier - 1) <= epsilon then
        return nil
    end

    local descriptor
    if multiplier > 1 then
        descriptor = opts.moreDescriptor or "higher"
    else
        descriptor = opts.lessDescriptor or "lower"
    end

    local color = getOrientationColor(multiplier - 1, opts.orientation)
    local format = opts.format or "x%.2f"
    local multiplierText = string.format(format, multiplier)
    local text = string.format("%s %s (%s)", label, multiplierText, descriptor)
    return buildLine(text, color)
end

local function appendLine(lines, entry)
    if entry then
        lines[#lines + 1] = entry
    end
end

local function getSummaryLines()
    local effects = TalentTree:calculateEffects(selections)
    local lines = {}

    appendLine(lines, formatSignedLine("Crash shields", effects.crashShieldBonus))
    appendLine(lines, formatSignedLine("Fruit bonus", effects.fruitBonus, { format = "%+0.1f" }))
    appendLine(lines, formatMultiplierLine("Combo multiplier", effects.comboMultiplier, {
        moreDescriptor = "stronger",
        lessDescriptor = "weaker",
    }))
    appendLine(lines, formatMultiplierLine("Snake speed", effects.snakeSpeedMultiplier, {
        moreDescriptor = "faster",
        lessDescriptor = "slower",
    }))
    appendLine(lines, formatSignedLine("Extra growth", effects.extraGrowth, { format = "%+0.1f" }))
    appendLine(lines, formatMultiplierLine("Rock spawn", effects.rockSpawnMultiplier, {
        moreDescriptor = "more frequent",
        lessDescriptor = "less frequent",
        orientation = -1,
    }))
    appendLine(lines, formatMultiplierLine("Saw speed", effects.sawSpeedMultiplier, {
        moreDescriptor = "faster",
        lessDescriptor = "slower",
        orientation = -1,
    }))
    appendLine(lines, formatMultiplierLine("Laser cooldown", effects.laserCooldownMultiplier, {
        moreDescriptor = "longer cycle",
        lessDescriptor = "faster cycle",
    }))
    appendLine(lines, formatMultiplierLine("Laser charge", effects.laserChargeMultiplier, {
        moreDescriptor = "longer telegraph",
        lessDescriptor = "quicker telegraph",
    }))
    appendLine(lines, formatSignedLine("Saw stall on fruit", effects.sawStallOnFruit, {
        format = "%+0.1f",
        suffix = "s",
    }))

    if math.abs(effects.extraShopChoices or 0) > 0.01 then
        local raw = effects.extraShopChoices
        local rounded = raw >= 0 and math.floor(raw + 0.0001) or math.ceil(raw - 0.0001)
        if rounded ~= 0 then
            appendLine(lines, buildLine(string.format("Shop choices %+d", rounded), getOrientationColor(raw, 1)))
        else
            appendLine(lines, buildLine(string.format("Shop choices %+0.1f", raw), getOrientationColor(raw, 1)))
        end
    end

    return lines
end

local function getSelectionSummaryLines()
    local lines = {}
    if not tiers or #tiers == 0 then
        return lines
    end

    local defaults = TalentTree:getDefaultSelections() or {}
    local defaultShort = Localization:get("talents.default_short")
    if defaultShort == "talents.default_short" then
        defaultShort = "Default"
    end

    local customShort = Localization:get("talents.custom_short")
    if customShort == "talents.custom_short" then
        customShort = "Custom pick"
    end

    local noneSelected = Localization:get("talents.none_selected")
    if noneSelected == "talents.none_selected" then
        noneSelected = "Not selected"
    end

    for _, tier in ipairs(tiers) do
        local selectionId = selections and selections[tier.id] or nil
        local optionName
        if tier.options then
            for _, option in ipairs(tier.options) do
                if option.id == selectionId then
                    optionName = option.name
                    break
                end
            end
        end

        local defaultId = defaults[tier.id]
        local isDefault = (selectionId == defaultId)

        if not optionName then
            if tier.options then
                for _, option in ipairs(tier.options) do
                    if option.id == defaultId then
                        optionName = option.name
                        isDefault = true
                        break
                    end
                end
            end
        end

        optionName = optionName or noneSelected

        local tierName = tier.name or tier.id or "Tier"
        local descriptor = isDefault and defaultShort or customShort
        local text = string.format("%s (%s, %s)", optionName, tierName, descriptor)
        local color = isDefault and UI.colors.subtleText or Theme.accentTextColor
        lines[#lines + 1] = buildLine(text, color)
    end

    return lines
end

refreshSummaryLayout = function()
    local loadoutLines = getSummaryLines()
    local picks = getSelectionSummaryLines()

    if #loadoutLines == 0 then
        local fallback = Localization:get("talents.no_modifiers")
        if fallback == "talents.no_modifiers" then
            fallback = "No stat modifiers active."
        end
        loadoutLines[#loadoutLines + 1] = buildLine(fallback, UI.colors.subtleText)
    end

    summaryLayout.lines = loadoutLines
    summaryLayout.picks = picks
    summaryLayout.hasContent = (#loadoutLines > 0 or #picks > 0)
    summaryLayout.headingHeight = UI.fonts.prompt:getHeight()
    summaryLayout.lineHeight = UI.fonts.body:getHeight()
    summaryLayout.lineSpacing = SUMMARY_LINE_SPACING
    summaryLayout.headingSpacing = SUMMARY_HEADING_SPACING

    local availableWidth = layout.panelW - PANEL_PADDING * 2
    if availableWidth < 0 then
        availableWidth = 0
    end

    if not summaryLayout.hasContent then
        summaryLayout.twoColumn = false
        summaryLayout.columnWidth = availableWidth
        summaryLayout.contentHeight = 0
        summaryLayout.height = summaryLayout.headingHeight
        return
    end

    local function columnHeight(count)
        if count <= 0 then
            return 0
        end
        return count * (summaryLayout.lineHeight + summaryLayout.lineSpacing)
    end

    local leftHeight = columnHeight(#summaryLayout.lines)
    local rightHeight = columnHeight(#summaryLayout.picks)

    if (#summaryLayout.lines > 0 and #summaryLayout.picks > 0 and availableWidth >= SUMMARY_TWO_COLUMN_MIN_WIDTH) then
        summaryLayout.twoColumn = true
        local columnWidth = math.floor((availableWidth - SUMMARY_COLUMN_GAP) / 2)
        columnWidth = math.max(SUMMARY_COLUMN_MIN_WIDTH, columnWidth)
        summaryLayout.columnWidth = columnWidth
        summaryLayout.contentHeight = math.max(leftHeight, rightHeight)
    else
        summaryLayout.twoColumn = false
        summaryLayout.columnWidth = availableWidth
        summaryLayout.contentHeight = leftHeight + rightHeight
        if #summaryLayout.lines > 0 and #summaryLayout.picks > 0 then
            summaryLayout.contentHeight = summaryLayout.contentHeight + SUMMARY_SECTION_SPACING
        end
    end

    summaryLayout.height = summaryLayout.headingHeight
    if summaryLayout.contentHeight > 0 then
        summaryLayout.height = summaryLayout.height + summaryLayout.headingSpacing + summaryLayout.contentHeight
    end
end

local function drawOptionCard(button)
    local option = button.option
    local tier = button.tier
    local selected = selections[tier.id] == option.id
    local isDefaultOption = option.default

    local fill = UI.colors.panel
    if selected then
        fill = { Theme.progressColor[1], Theme.progressColor[2], Theme.progressColor[3], 0.24 }
    end

    local borderColor = UI.colors.panelBorder
    if selected then
        borderColor = Theme.progressColor
    end

    UI.registerButton(button.id, button.x, button.y, button.w, button.h, option.name)

    UI.drawPanel(button.x, button.y, button.w, button.h, {
        fill = fill,
        borderColor = borderColor,
        focused = button.focused,
        focusColor = Theme.accentTextColor,
        shadowOffset = 6,
    })

    local padding = CARD_PADDING
    local metrics = button.metrics or measureOptionMetrics(option)
    local contentWidth = button.w - padding * 2
    local headingHeight = UI.fonts.heading:getHeight()

    UI.drawLabel(option.name, button.x + padding, button.y + padding, contentWidth, "left", {
        fontKey = "heading",
        color = Theme.textColor,
    })

    local description = option.description or ""
    local listY
    if description ~= "" then
        local descY = button.y + padding + headingHeight + CARD_HEADING_SPACING
        UI.drawLabel(description, button.x + padding, descY, contentWidth, "left", {
            fontKey = "body",
            color = UI.colors.subtleText,
        })
        listY = descY + (metrics and metrics.descHeight or UI.fonts.body:getHeight())
    else
        listY = button.y + padding + headingHeight
    end

    if metrics and (metrics.hasBonuses or metrics.hasPenalties) then
        listY = listY + (metrics.listStartSpacing or 0)
    end

    if option.bonuses and #option.bonuses > 0 then
        for index, bonus in ipairs(option.bonuses) do
            UI.drawLabel("• " .. bonus, button.x + padding, listY, contentWidth, "left", {
                fontKey = "body",
                color = Theme.progressColor,
            })
            local lineHeight = metrics and metrics.bonusHeights and metrics.bonusHeights[index] or UI.fonts.body:getHeight()
            listY = listY + lineHeight
            if index < #option.bonuses then
                listY = listY + CARD_LIST_ITEM_SPACING
            end
        end
    end

    if option.penalties and #option.penalties > 0 then
        if option.bonuses and #option.bonuses > 0 then
            listY = listY + CARD_LIST_SECTION_SPACING
        end

        for index, penalty in ipairs(option.penalties) do
            UI.drawLabel("• " .. penalty, button.x + padding, listY, contentWidth, "left", {
                fontKey = "body",
                color = Theme.warningColor,
            })
            local lineHeight = metrics and metrics.penaltyHeights and metrics.penaltyHeights[index] or UI.fonts.body:getHeight()
            listY = listY + lineHeight
            if index < #option.penalties then
                listY = listY + CARD_LIST_ITEM_SPACING
            end
        end
    end

    if selected then
        local tagText = Localization:get("talents.selected")
        if tagText == "talents.selected" then
            tagText = "Selected"
        end
        if isDefaultOption then
            local defaultShort = Localization:get("talents.default_short")
            if defaultShort == "talents.default_short" then
                defaultShort = "Default"
            end
            tagText = string.format("%s • %s", tagText, defaultShort)
        end

        local tagWidth = UI.fonts.caption:getWidth(tagText) + 16
        local tagHeight = UI.fonts.caption:getHeight() + 6
        local tagX = button.x + button.w - tagWidth - padding
        local tagY = button.y + button.h - tagHeight - padding + CARD_TAG_OFFSET
        UI.drawPanel(tagX, tagY, tagWidth, tagHeight, {
            fill = { Theme.progressColor[1], Theme.progressColor[2], Theme.progressColor[3], 0.4 },
            borderColor = Theme.progressColor,
            shadowOffset = 0,
            radius = 10,
        })
        UI.drawLabel(tagText, tagX, tagY + 3, tagWidth, "center", {
            fontKey = "caption",
            color = Theme.textColor,
        })
    elseif isDefaultOption then
        local defaultText = Localization:get("talents.default")
        if defaultText == "talents.default" then
            defaultText = "Default pick"
        end
        local tagWidth = UI.fonts.caption:getWidth(defaultText) + 14
        local tagHeight = UI.fonts.caption:getHeight() + 4
        local tagX = button.x + button.w - tagWidth - padding
        local tagY = button.y + padding
        UI.drawPanel(tagX, tagY, tagWidth, tagHeight, {
            fill = { Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.12 },
            borderColor = { Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.28 },
            shadowOffset = 0,
            radius = 10,
        })
        UI.drawLabel(defaultText, tagX, tagY + 2, tagWidth, "center", {
            fontKey = "caption",
            color = UI.colors.subtleText,
        })
    end
end

local function drawTier(tierIndex, tier)
    local info = tierLayout[tierIndex]
    local tierTop = layout.contentY + scrollOffset + (info and info.top or CONTENT_TOP_PADDING)
    local titleY = tierTop
    UI.drawLabel(tier.name, layout.contentX, titleY, layout.contentW, "left", {
        fontKey = "heading",
        color = Theme.accentTextColor,
    })

    local description = tier.description or ""
    if description ~= "" then
        local descY = titleY + UI.fonts.heading:getHeight() + HEADER_SPACING
        UI.drawLabel(description, layout.contentX, descY, layout.contentW, "left", {
            fontKey = "body",
            color = UI.colors.subtleText,
        })
    end

    for optionIndex = 1, #tier.options do
        local button = select(1, findOptionButton(tierIndex, optionIndex))
        if button then
            button.y = layout.contentY + scrollOffset + button.contentY
            drawOptionCard(button)
        end
    end
end

local function activateButton(button)
    if not button then
        return nil
    end

    if button.type == "back" then
        Audio:playSound("click")
        return { state = "menu" }
    elseif button.type == "reset" then
        if button.disabled then
            return nil
        end
        Audio:playSound("click")
        selections = TalentTree:resetToDefaults() or selections
        updateFocusVisuals()
        updateLayout()
        return nil
    elseif button.type == "option" then
        local tierId = button.tier.id
        if selections[tierId] ~= button.option.id then
            selections[tierId] = button.option.id
            TalentTree:setSelection(tierId, button.option.id)
            updateLayout()
        end
        Audio:playSound("click")
        return nil
    end

    return nil
end

function TalentTreeScreen:enter()
    UI.clearButtons()
    scrollOffset = 0
    minScrollOffset = 0
    viewportHeight = 0
    contentHeight = 0
    focusedIndex = nil
    hoveredIndex = nil
    pressedButtonId = nil
    resetHeldDpad()
    analogAxisDirections.horizontal = nil
    analogAxisDirections.vertical = nil

    rebuildButtons()
    updateLayout()
end

function TalentTreeScreen:leave()
    resetHeldDpad()
end

function TalentTreeScreen:update(dt)
    updateLayout()
    updateHeldDpad(dt)

    local mx, my = love.mouse.getPosition()
    hoveredIndex = nil

    for index, button in ipairs(buttons) do
        if button.type == "option" then
            button.y = layout.contentY + scrollOffset + button.contentY
            if UI.isHovered(button.x, button.y, button.w, button.h, mx, my) then
                hoveredIndex = index
            end
        elseif button.type == "back" or button.type == "reset" then
            if UI.isHovered(button.x, button.y, button.w, button.h, mx, my) then
                hoveredIndex = index
            end
        end
    end

    if hoveredIndex then
        setFocus(hoveredIndex)
    else
        updateFocusVisuals()
    end
end

function TalentTreeScreen:draw()
    updateLayout()

    local sw, sh = Screen:get()
    drawBackground(sw, sh)

    UI.drawPanel(layout.panelX, layout.panelY, layout.panelW, layout.panelH, {
        fill = Theme.panelColor,
        borderColor = Theme.panelBorder,
        shadowOffset = 18,
    })

    local title = Localization:get("talents.title")
    if title == "talents.title" then
        title = "Talent Forge"
    end

    local subtitle = Localization:get("talents.subtitle")
    if subtitle == "talents.subtitle" then
        subtitle = "Choose one talent per tier to shape your run."
    end

    UI.drawLabel(title, 0, layout.panelY - 88, sw, "center", {
        fontKey = "title",
        color = Theme.textColor,
    })

    UI.drawLabel(subtitle, layout.panelX, layout.panelY - 36, layout.panelW, "center", {
        fontKey = "body",
        color = UI.colors.subtleText,
    })

    local summaryHeading = Localization:get("talents.loadout")
    if summaryHeading == "talents.loadout" then
        summaryHeading = "Active loadout:"
    end

    local summaryX = layout.panelX + PANEL_PADDING
    local summaryY = layout.panelY + PANEL_PADDING
    local summaryWidth = layout.panelW - PANEL_PADDING * 2

    if summaryLayout.hasContent then
        UI.drawLabel(summaryHeading, summaryX, summaryY, summaryWidth, "left", {
            fontKey = "prompt",
            color = Theme.accentTextColor,
        })

        if summaryLayout.contentHeight > 0 then
            local contentY = summaryY + summaryLayout.headingHeight + summaryLayout.headingSpacing
            local lineHeight = summaryLayout.lineHeight
            local lineSpacing = summaryLayout.lineSpacing

            if summaryLayout.twoColumn then
                local columnWidth = summaryLayout.columnWidth
                local leftY = contentY
                for _, line in ipairs(summaryLayout.lines or {}) do
                    if line and line.text and line.text ~= "" then
                        UI.drawLabel("• " .. line.text, summaryX, leftY, columnWidth, "left", {
                            fontKey = "body",
                            color = line.color or Theme.textColor,
                        })
                        leftY = leftY + lineHeight + lineSpacing
                    end
                end

                local rightX = summaryX + columnWidth + SUMMARY_COLUMN_GAP
                local rightY = contentY
                for _, line in ipairs(summaryLayout.picks or {}) do
                    if line and line.text and line.text ~= "" then
                        UI.drawLabel("• " .. line.text, rightX, rightY, columnWidth, "left", {
                            fontKey = "body",
                            color = line.color or Theme.textColor,
                        })
                        rightY = rightY + lineHeight + lineSpacing
                    end
                end
            else
                local columnWidth = summaryLayout.columnWidth
                local columnY = contentY

                for _, line in ipairs(summaryLayout.lines or {}) do
                    if line and line.text and line.text ~= "" then
                        UI.drawLabel("• " .. line.text, summaryX, columnY, columnWidth, "left", {
                            fontKey = "body",
                            color = line.color or Theme.textColor,
                        })
                        columnY = columnY + lineHeight + lineSpacing
                    end
                end

                if (#summaryLayout.lines or 0) > 0 and (#summaryLayout.picks or 0) > 0 then
                    columnY = columnY + SUMMARY_SECTION_SPACING
                end

                for _, line in ipairs(summaryLayout.picks or {}) do
                    if line and line.text and line.text ~= "" then
                        UI.drawLabel("• " .. line.text, summaryX, columnY, columnWidth, "left", {
                            fontKey = "body",
                            color = line.color or Theme.textColor,
                        })
                        columnY = columnY + lineHeight + lineSpacing
                    end
                end
            end
        end
    else
        local fallback = Localization:get("talents.loadout_empty")
        if fallback == "talents.loadout_empty" then
            fallback = "Active loadout: balanced."
        end
        UI.drawLabel(fallback, summaryX, summaryY, summaryWidth, "left", {
            fontKey = "prompt",
            color = Theme.accentTextColor,
        })
    end

    local viewportX = layout.contentX
    local viewportY = layout.contentY
    local viewportW = layout.contentW
    local viewportH = viewportHeight

    local prevScissor = { love.graphics.getScissor() }
    if viewportW > 0 and viewportH > 0 then
        love.graphics.setScissor(viewportX, viewportY, viewportW, viewportH)
    end

    for tierIndex, tier in ipairs(tiers) do
        drawTier(tierIndex, tier)
    end

    if viewportW > 0 and viewportH > 0 then
        love.graphics.setScissor(unpack(prevScissor))
    end

    local hint = Localization:get("talents.hint")
    if hint == "talents.hint" then
        hint = "Use arrows, mouse, or gamepad to navigate. Enter/A selects, Esc/B returns."
    end

    UI.drawLabel(hint, layout.panelX, layout.panelY + layout.panelH + 16, layout.panelW, "center", {
        fontKey = "caption",
        color = UI.colors.subtleText,
    })

    local resetButton = select(1, findButtonByType("reset"))
    if resetButton then
        UI.drawButton(resetButton.id)
    end

    local backButton = select(1, findButtonByType("back"))
    if backButton then
        UI.drawButton(backButton.id)
    end
end

function TalentTreeScreen:keypressed(key)
    if key == "escape" then
        Audio:playSound("click")
        return { state = "menu" }
    elseif key == "return" or key == "kpenter" or key == "space" then
        return activateButton(buttons[focusedIndex])
    elseif key == "up" then
        moveFocusVertical(-1)
    elseif key == "down" then
        moveFocusVertical(1)
    elseif key == "left" then
        moveFocusHorizontal(-1)
    elseif key == "right" then
        moveFocusHorizontal(1)
    elseif key == "pageup" then
        addScroll(SCROLL_SPEED * 3)
    elseif key == "pagedown" then
        addScroll(-SCROLL_SPEED * 3)
    end
end

local function handleGamepadButton(button, pressed)
    if not pressed then
        stopHeldDpad(button)
        return
    end

    if button == "dpup" then
        startHeldDpad(button, function()
            moveFocusVertical(-1)
        end)
        moveFocusVertical(-1)
    elseif button == "dpdown" then
        startHeldDpad(button, function()
            moveFocusVertical(1)
        end)
        moveFocusVertical(1)
    elseif button == "dpleft" then
        startHeldDpad(button, function()
            moveFocusHorizontal(-1)
        end)
        moveFocusHorizontal(-1)
    elseif button == "dpright" then
        startHeldDpad(button, function()
            moveFocusHorizontal(1)
        end)
        moveFocusHorizontal(1)
    elseif button == "a" then
        return activateButton(buttons[focusedIndex])
    elseif button == "b" then
        Audio:playSound("click")
        return { state = "menu" }
    elseif button == "leftshoulder" then
        addScroll(SCROLL_SPEED * 2)
    elseif button == "rightshoulder" then
        addScroll(-SCROLL_SPEED * 2)
    end

    return nil
end

function TalentTreeScreen:gamepadpressed(_, button)
    return handleGamepadButton(button, true)
end

function TalentTreeScreen:gamepadreleased(_, button)
    stopHeldDpad(button)
end

local analogAxisMap = {
    leftx = { slot = "horizontal" },
    rightx = { slot = "horizontal" },
    lefty = { slot = "vertical" },
    righty = { slot = "vertical" },
    [1] = { slot = "horizontal" },
    [2] = { slot = "vertical" },
}

local analogActions = {
    horizontal = {
        negative = function()
            moveFocusHorizontal(-1)
        end,
        positive = function()
            moveFocusHorizontal(1)
        end,
    },
    vertical = {
        negative = function()
            moveFocusVertical(-1)
        end,
        positive = function()
            moveFocusVertical(1)
        end,
    },
}

local function handleAnalog(axis, value)
    local mapping = analogAxisMap[axis]
    if not mapping then
        return
    end

    local direction
    if value >= ANALOG_DEADZONE then
        direction = "positive"
    elseif value <= -ANALOG_DEADZONE then
        direction = "negative"
    end

    if analogAxisDirections[mapping.slot] == direction then
        return
    end

    analogAxisDirections[mapping.slot] = direction

    if direction then
        local action = analogActions[mapping.slot]
        if action and action[direction] then
            action[direction]()
        end
    end
end

function TalentTreeScreen:gamepadaxis(_, axis, value)
    handleAnalog(axis, value)
end

function TalentTreeScreen:joystickaxis(_, axis, value)
    handleAnalog(axis, value)
end

function TalentTreeScreen:joystickpressed(_, button)
    return handleGamepadButton(button, true)
end

function TalentTreeScreen:joystickreleased(_, button)
    stopHeldDpad(button)
end

function TalentTreeScreen:mousemoved(x, y)
    hoveredIndex = nil
    for index, button in ipairs(buttons) do
        if button.type == "option" then
            if UI.isHovered(button.x, button.y, button.w, button.h, x, y) then
                hoveredIndex = index
            end
        elseif button.type == "back" or button.type == "reset" then
            if UI.isHovered(button.x, button.y, button.w, button.h, x, y) then
                hoveredIndex = index
            end
        end
    end

    if hoveredIndex then
        setFocus(hoveredIndex)
    end
end

function TalentTreeScreen:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local id = UI:mousepressed(x, y, button)
    if id then
        pressedButtonId = id
        for index, entry in ipairs(buttons) do
            if entry.id == id then
                setFocus(index)
                break
            end
        end
    end
end

function TalentTreeScreen:mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    local id = UI:mousereleased(x, y, button)
    if id and pressedButtonId == id then
        pressedButtonId = nil
        for index, entry in ipairs(buttons) do
            if entry.id == id then
                setFocus(index)
                local result = activateButton(entry)
                if result then
                    return result
                end
                break
            end
        end
    else
        pressedButtonId = nil
    end
end

function TalentTreeScreen:wheelmoved(_, y)
    if not y or y == 0 then
        return
    end

    addScroll(y * SCROLL_SPEED)
end

return TalentTreeScreen
