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
}
local tierMetrics = {}
local tierLayout = {}

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

local function moveFocusHorizontal(delta)
    if not delta or delta == 0 then
        return
    end

    local current = buttons[focusedIndex]
    if not current then
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

    if current.type == "back" then
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
        end
        return
    end

    local targetTierIndex = current.tierIndex + delta
    if targetTierIndex < 1 then
        return
    end

    if targetTierIndex > #tiers then
        for index, button in ipairs(buttons) do
            if button.type == "back" then
                setFocus(index)
                return
            end
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
    layout.contentX = layout.panelX + PANEL_PADDING
    layout.contentY = layout.panelY + PANEL_PADDING
    layout.contentW = layout.panelW - PANEL_PADDING * 2

    viewportHeight = math.max(0, layout.panelH - PANEL_PADDING * 2)

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

    local backButton = buttons[#buttons]
    if backButton and backButton.type == "back" then
        backButton.w = math.min(UI.spacing.buttonWidth * 1.4, layout.panelW - PANEL_PADDING * 2)
        backButton.h = UI.spacing.buttonHeight
        backButton.x = layout.panelX + (layout.panelW - backButton.w) / 2
        backButton.y = layout.panelY + layout.panelH - PANEL_PADDING - backButton.h
        UI.registerButton(backButton.id, backButton.x, backButton.y, backButton.w, backButton.h, backButton.label)
        UI.setButtonFocus(backButton.id, focusedIndex == #buttons)
    end
end

local function formatSignedLine(label, value, fmt, suffix)
    local amount = value or 0
    if math.abs(amount) <= 0.01 then
        return nil
    end

    local format = fmt or "%+g"
    local formatted = string.format(format, amount)
    if suffix and suffix ~= "" then
        formatted = formatted .. suffix
    end

    return string.format("%s %s", label, formatted)
end

local function formatMultiplierLine(label, multiplier, moreDescriptor, lessDescriptor)
    multiplier = multiplier or 1
    if math.abs(multiplier - 1) <= 0.01 then
        return nil
    end

    local descriptor
    if multiplier > 1 then
        descriptor = moreDescriptor or "higher"
    else
        descriptor = lessDescriptor or "lower"
    end

    return string.format("%s x%.2f (%s)", label, multiplier, descriptor)
end

local function appendLine(lines, text)
    if text and text ~= "" then
        lines[#lines + 1] = text
    end
end

local function getSummaryLines()
    local effects = TalentTree:calculateEffects(selections)
    local lines = {}

    appendLine(lines, formatSignedLine("Max health", effects.maxHealthBonus))
    appendLine(lines, formatSignedLine("Crash shields", effects.startingCrashShields))
    appendLine(lines, formatSignedLine("Fruit bonus", effects.fruitBonus, "%+0.1f"))
    appendLine(lines, formatMultiplierLine("Combo multiplier", effects.comboMultiplier, "stronger", "weaker"))
    appendLine(lines, formatMultiplierLine("Snake speed", effects.snakeSpeedMultiplier, "faster", "slower"))
    appendLine(lines, formatSignedLine("Extra growth", effects.extraGrowth, "%+0.1f"))
    appendLine(lines, formatMultiplierLine("Rock spawn", effects.rockSpawnMultiplier, "more frequent", "less frequent"))
    appendLine(lines, formatMultiplierLine("Saw speed", effects.sawSpeedMultiplier, "faster", "slower"))
    appendLine(lines, formatMultiplierLine("Laser cooldown", effects.laserCooldownMultiplier, "longer cycle", "faster cycle"))
    appendLine(lines, formatMultiplierLine("Laser charge", effects.laserChargeMultiplier, "longer telegraph", "quicker telegraph"))
    appendLine(lines, formatSignedLine("Saw stall on fruit", effects.sawStallOnFruit, "%+0.1f", "s"))

    if math.abs(effects.extraShopChoices or 0) > 0.01 then
        local raw = effects.extraShopChoices
        local rounded = raw >= 0 and math.floor(raw + 0.0001) or math.ceil(raw - 0.0001)
        if rounded ~= 0 then
            appendLine(lines, string.format("Shop choices %+d", rounded))
        else
            appendLine(lines, string.format("Shop choices %+0.1f", raw))
        end
    end

    return lines
end

local function drawOptionCard(button)
    local option = button.option
    local tier = button.tier
    local selected = selections[tier.id] == option.id

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
    elseif button.type == "option" then
        local tierId = button.tier.id
        if selections[tierId] ~= button.option.id then
            selections[tierId] = button.option.id
            TalentTree:setSelection(tierId, button.option.id)
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
        elseif button.type == "back" then
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

    local summaryLines = getSummaryLines()
    if #summaryLines > 0 then
        local summaryY = layout.panelY + 12
        local summaryX = layout.panelX + PANEL_PADDING
        UI.drawLabel(Localization:get("talents.loadout") ~= "talents.loadout" and Localization:get("talents.loadout") or "Active loadout:", summaryX, summaryY, layout.panelW - PANEL_PADDING * 2, "left", {
            fontKey = "prompt",
            color = Theme.accentTextColor,
        })
        summaryY = summaryY + UI.fonts.prompt:getHeight() + 4
        for _, line in ipairs(summaryLines) do
            UI.drawLabel("• " .. line, summaryX, summaryY, layout.panelW - PANEL_PADDING * 2, "left", {
                fontKey = "body",
                color = Theme.textColor,
            })
            summaryY = summaryY + UI.fonts.body:getHeight() + 2
        end
    else
        UI.drawLabel(Localization:get("talents.loadout_empty") ~= "talents.loadout_empty" and Localization:get("talents.loadout_empty") or "Active loadout: balanced.", layout.panelX + PANEL_PADDING, layout.panelY + 12, layout.panelW - PANEL_PADDING * 2, "left", {
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

    local backButton = buttons[#buttons]
    if backButton and backButton.type == "back" then
        UI.registerButton(backButton.id, backButton.x, backButton.y, backButton.w, backButton.h, backButton.label)
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
        elseif button.type == "back" then
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
