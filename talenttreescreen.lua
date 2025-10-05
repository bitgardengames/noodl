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

local CARD_WIDTH = 300
local CARD_HEIGHT = 172
local CARD_SPACING = 26
local HEADER_HEIGHT = 60
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
                h = CARD_HEIGHT,
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
        local optionStart = yCursor + HEADER_HEIGHT
        local tierHeight = HEADER_HEIGHT + CARD_HEIGHT + OPTION_FOOTER_SPACING

        local optionCount = #tier.options
        local totalWidth = optionCount * CARD_WIDTH + math.max(0, optionCount - 1) * CARD_SPACING
        local startX = layout.contentX + math.max(0, (layout.contentW - totalWidth) / 2)

        for optionIndex = 1, optionCount do
            local button, index = findOptionButton(tierIndex, optionIndex)
            if button and index then
                button.w = CARD_WIDTH
                button.h = CARD_HEIGHT
                button.contentY = optionStart
                button.contentBottom = optionStart + CARD_HEIGHT
                button.x = startX + (optionIndex - 1) * (CARD_WIDTH + CARD_SPACING)
                button.y = layout.contentY + scrollOffset + optionStart
                button.visible = button.y + button.h >= layout.contentY and button.y <= layout.contentY + viewportHeight
                UI.registerButton(button.id, button.x, button.y, button.w, button.h, button.option.name)
            end
        end

        yCursor = yCursor + tierHeight + TIER_SPACING
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

local function getSummaryLines()
    local effects = TalentTree:calculateEffects(selections)
    local lines = {}

    if math.abs(effects.maxHealthBonus or 0) > 0.01 then
        lines[#lines + 1] = string.format("Max health %+g", effects.maxHealthBonus)
    end

    if math.abs(effects.startingCrashShields or 0) > 0.01 then
        lines[#lines + 1] = string.format("Crash shields %+g", effects.startingCrashShields)
    end

    if math.abs((effects.fruitBonus or 0)) > 0.01 then
        lines[#lines + 1] = string.format("Fruit bonus %+0.1f", effects.fruitBonus)
    end

    if math.abs((effects.comboMultiplier or 1) - 1) > 0.01 then
        lines[#lines + 1] = string.format("Combo multiplier x%.2f", effects.comboMultiplier)
    end

    if math.abs((effects.snakeSpeedMultiplier or 1) - 1) > 0.01 then
        lines[#lines + 1] = string.format("Snake speed x%.2f", effects.snakeSpeedMultiplier)
    end

    if math.abs((effects.extraGrowth or 0)) > 0.01 then
        lines[#lines + 1] = string.format("Extra growth %+0.1f", effects.extraGrowth)
    end

    if math.abs((effects.rockSpawnMultiplier or 1) - 1) > 0.01 then
        lines[#lines + 1] = string.format("Rock spawn x%.2f", effects.rockSpawnMultiplier)
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

    local padding = 18
    UI.drawLabel(option.name, button.x + padding, button.y + padding - 2, button.w - padding * 2, "left", {
        fontKey = "heading",
        color = Theme.textColor,
    })

    local descY = button.y + padding + UI.fonts.heading:getHeight() - 4
    UI.drawLabel(option.description or "", button.x + padding, descY, button.w - padding * 2, "left", {
        fontKey = "body",
        color = UI.colors.subtleText,
    })

    local listY = descY + UI.fonts.body:getHeight() + 8
    local listFont = UI.fonts.small

    if option.bonuses and #option.bonuses > 0 then
        for _, bonus in ipairs(option.bonuses) do
            UI.drawLabel("• " .. bonus, button.x + padding, listY, button.w - padding * 2, "left", {
                fontKey = "body",
                color = Theme.progressColor,
            })
            listY = listY + listFont:getHeight() + 4
        end
    end

    if option.penalties and #option.penalties > 0 then
        for _, penalty in ipairs(option.penalties) do
            UI.drawLabel("• " .. penalty, button.x + padding, listY, button.w - padding * 2, "left", {
                fontKey = "body",
                color = Theme.warningColor,
            })
            listY = listY + listFont:getHeight() + 4
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
        local tagY = button.y + button.h - tagHeight - padding + 6
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
    local tierTop = layout.contentY + scrollOffset + CONTENT_TOP_PADDING + (tierIndex - 1) * (HEADER_HEIGHT + CARD_HEIGHT + OPTION_FOOTER_SPACING + TIER_SPACING)
    local titleY = tierTop
    local descY = titleY + UI.fonts.heading:getHeight() + 4

    UI.drawLabel(tier.name, layout.contentX, titleY, layout.contentW, "left", {
        fontKey = "heading",
        color = Theme.accentTextColor,
    })

    UI.drawLabel(tier.description or "", layout.contentX, descY, layout.contentW, "left", {
        fontKey = "body",
        color = UI.colors.subtleText,
    })

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
