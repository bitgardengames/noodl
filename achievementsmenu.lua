local Audio = require("audio")
local Achievements = require("achievements")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local SnakeDraw = require("snakedraw")
local SnakeUtils = require("snakeutils")
local Face = require("face")
local Shaders = require("shaders")
local SnakeCosmetics = require("snakecosmetics")

local floor = math.floor
local max = math.max
local min = math.min

local AchievementsMenu = {
    transitionDuration = 0.3,
}

local buttonList = ButtonList.new()
local iconCache = {}
local displayBlocks = {}
local achievementRewardText = {}

local START_Y = 180
local SUMMARY_SPACING_TEXT_PROGRESS = 32
local SUMMARY_PROGRESS_BAR_HEIGHT = 12
local SUMMARY_PANEL_TOP_PADDING_MIN = 12
local SUMMARY_PANEL_BOTTOM_PADDING_MIN = 24
local SUMMARY_PANEL_GAP_MIN = 24
local SUMMARY_HIGHLIGHT_INSET = 16
local CARD_SPACING = 140
local CARD_WIDTH = 600
local CARD_HEIGHT = 118
local CATEGORY_SPACING = 40
-- Allow extra headroom in the scroll scissor so the category headers drawn
-- slightly above the first card remain visible when at the top of the list.
local SCROLL_SCISSOR_TOP_PADDING = 64
local SCROLL_SPEED = 60
local BASE_PANEL_PADDING_X = 48
local BASE_PANEL_PADDING_Y = 56
local MIN_SCROLLBAR_INSET = 16
local SCROLLBAR_TRACK_WIDTH = (SnakeUtils.SEGMENT_SIZE or 24) + 12

local DPAD_REPEAT_INITIAL_DELAY = 0.3
local DPAD_REPEAT_INTERVAL = 0.1
local ANALOG_DEADZONE = 0.3

local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0
local DPAD_SCROLL_AMOUNT = CARD_SPACING

local heldDpadButton = nil
local heldDpadAction = nil
local heldDpadTimer = 0
local heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local analogAxisDirections = {horizontal = nil, vertical = nil}

local BACKGROUND_EFFECT_TYPE = "afterglowPulse"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function copyColor(color)
        if not color then
                return {0, 0, 0, 1}
        end

        return {
                color[1] or 0,
                color[2] or 0,
                color[3] or 0,
                color[4] == nil and 1 or color[4],
        }
end

local function lightenColor(color, factor)
        factor = factor or 0.35
        local r = color[1] or 1
        local g = color[2] or 1
        local b = color[3] or 1
        local a = color[4] == nil and 1 or color[4]
        return {
                r + (1 - r) * factor,
                g + (1 - g) * factor,
                b + (1 - b) * factor,
                a * (0.65 + factor * 0.35),
        }
end

local function darkenColor(color, factor)
        factor = factor or 0.35
        local r = color[1] or 1
        local g = color[2] or 1
        local b = color[3] or 1
        local a = color[4] == nil and 1 or color[4]
        return {
                r * (1 - factor),
                g * (1 - factor),
                b * (1 - factor),
                a,
        }
end

local function withAlpha(color, alpha)
        local r = color[1] or 1
        local g = color[2] or 1
        local b = color[3] or 1
        local a = color[4] == nil and 1 or color[4]
        return {r, g, b, a * alpha}
end

local function configureBackgroundEffect()
        local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
        if not effect then
                backgroundEffect = nil
                return
        end

        local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
        local baseColor = copyColor(Theme.bgColor or {0.12, 0.12, 0.14, 1})
        local coolAccent = Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
        local accentColor = lightenColor(copyColor(coolAccent), 0.18)
        accentColor[4] = 1

        local pulseColor = lightenColor(copyColor(Theme.panelBorder or Theme.progressColor or accentColor), 0.26)
        pulseColor[4] = 1

        baseColor = darkenColor(baseColor, 0.15)
        baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

        local vignette = {
                color = withAlpha(lightenColor(copyColor(coolAccent), 0.05), 0.28),
                alpha = 0.28,
                steps = 3,
                thickness = nil,
        }

        effect.backdropIntensity = max(0.48, (defaultBackdrop or effect.backdropIntensity or 0.62) * 0.92)

        Shaders.configure(effect, {
                bgColor = baseColor,
                accentColor = accentColor,
                pulseColor = pulseColor,
        })

        effect.vignetteOverlay = vignette
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

local function clamp01(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function lightenColor(color, amount)
	if not color then
		return {1, 1, 1, 1}
	end

	amount = clamp01(amount or 0)
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] or 1

	return {
		r + (1 - r) * amount,
		g + (1 - g) * amount,
		b + (1 - b) * amount,
		a,
	}
end

local function darkenColor(color, amount)
	if not color then
		return {0, 0, 0, 1}
	end

	amount = clamp01(amount or 0)
	local factor = 1 - amount
	local a = color[4] or 1

	return {
		(color[1] or 0) * factor,
		(color[2] or 0) * factor,
		(color[3] or 0) * factor,
		a,
	}
end

local function withAlpha(color, alpha)
	if not color then
		return {1, 1, 1, alpha or 1}
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		alpha or (color[4] or 1),
	}
end

local function setColor(color, alphaOverride)
	if not color then
		love.graphics.setColor(1, 1, 1, alphaOverride or 1)
		return
	end

	love.graphics.setColor(
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		alphaOverride or color[4] or 1
	)
end

local function joinWithConjunction(items)
	local count = #items
	if count == 0 then
		return ""
	elseif count == 1 then
		return items[1]
	elseif count == 2 then
		local conj = Localization:get("common.and")
		if conj == "common.and" then
			conj = "and"
		end
		return string.format("%s %s %s", items[1], conj, items[2])
	end

	local conj = Localization:get("common.and")
	if conj == "common.and" then
		conj = "and"
	end

	local buffer = {}
	for index = 1, count - 1 do
		buffer[index] = items[index]
	end

	return string.format("%s, %s %s", table.concat(buffer, ", "), conj, items[count])
end

local function resolveBackButtonY(sw, sh, layout)
        local menuLayout = UI.getMenuLayout(sw, sh)
        local buttonHeight = UI.spacing.buttonHeight or 0
        local marginBottom = menuLayout.marginBottom or 0
        local bottomY = menuLayout.bottomY or (sh - marginBottom)
        local y = bottomY - buttonHeight

        if layout and layout.viewportBottom then
                local spacing = UI.spacing.buttonSpacing or UI.spacing.sectionSpacing or 0
                y = max(y, layout.viewportBottom + spacing * 0.5)
        end

        local maxY = sh - buttonHeight - marginBottom
        if y > maxY then
                y = maxY
        end

        return y
end

local function applyBackButtonLayout(layout, sw, sh)
	if not buttonList then
		return
	end

	local buttonWidth = UI.spacing.buttonWidth or 0
	local buttonHeight = UI.spacing.buttonHeight or 0
	local x = sw / 2 - buttonWidth / 2
	local y = resolveBackButtonY(sw, sh, layout)

	for _, btn in buttonList:iter() do
		if btn.id == "achievementsBack" then
			btn.x = x
			btn.y = y
			btn.w = buttonWidth
			btn.h = buttonHeight
			break
		end
	end
end

local function formatAchievementRewards(rewards)
	local formatted = {}
	for _, reward in ipairs(rewards or {}) do
		if reward.type == "cosmetic" then
			local label = Localization:get("achievements.rewards.cosmetic_skin", {name = reward.name})
			if label == "achievements.rewards.cosmetic_skin" then
				label = string.format("%s snake skin", reward.name or Localization:get("common.unknown"))
			end
			formatted[#formatted + 1] = label
		elseif reward.label then
			formatted[#formatted + 1] = reward.label
		elseif reward.name then
			formatted[#formatted + 1] = reward.name
		end
	end

	if #formatted == 0 then
		return nil
	end

	local headingKey = (#formatted > 1) and "achievements.rewards.multiple" or "achievements.rewards.single"
	local heading = Localization:get(headingKey)
	if heading == headingKey then
		heading = (#formatted > 1) and "Rewards" or "Reward"
	end

	return string.format("%s: %s", heading, joinWithConjunction(formatted))
end

local function rebuildAchievementRewards()
	achievementRewardText = {}

	if not SnakeCosmetics or not SnakeCosmetics.getSkins then
		return
	end

	local ok, skins = pcall(SnakeCosmetics.getSkins, SnakeCosmetics)
	if not ok then
		print("[achievementsmenu] failed to query cosmetics:", skins)
		return
	end

	local grouped = {}
	for _, skin in ipairs(skins or {}) do
		local unlock = skin.unlock or {}
		if unlock.achievement and skin.name then
			local list = grouped[unlock.achievement]
			if not list then
				list = {}
				grouped[unlock.achievement] = list
			end
			list[#list + 1] = {type = "cosmetic", name = skin.name}
		end
	end

	for id, rewards in pairs(grouped) do
		local label = formatAchievementRewards(rewards)
		if label then
			achievementRewardText[id] = label
		end
	end
end

local function getAchievementRewardLabel(achievement)
	if not achievement then
		return nil
	end

	return achievementRewardText[achievement.id]
end

local function toPercent(value)
	value = clamp01(value or 0)
	return floor(value * 100 + 0.5)
end

local function buildThumbSnakeTrail(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight)
	local segmentSize = SnakeUtils.SEGMENT_SIZE
	local halfSegment = segmentSize * 0.5
	local trackCenterX = trackX + trackWidth * 0.5
	local trackTop = trackY + halfSegment
	local trackBottom = trackY + trackHeight - halfSegment
	local topY = max(trackTop, min(trackBottom, thumbY + halfSegment))
	local bottomY = min(trackBottom, max(trackTop, thumbY + thumbHeight - halfSegment))

	if bottomY < topY then
		local midpoint = (topY + bottomY) * 0.5
		bottomY = midpoint
		topY = midpoint
	end

	local trail = {}
	trail[#trail + 1] = {x = trackCenterX, y = bottomY}

	local spacing = SnakeUtils.SEGMENT_SPACING or segmentSize
	local y = bottomY - spacing
	while y > topY do
		trail[#trail + 1] = {x = trackCenterX, y = y}
		y = y - spacing
	end

	trail[#trail + 1] = {x = trackCenterX, y = topY}

	return trail, segmentSize
end

local function computeLayout(sw, sh)
	local layout = {}
	local menuLayout = UI.getMenuLayout(sw, sh)

	local edgeMarginX = max(menuLayout.marginHorizontal or 32, sw * 0.05)
	local basePanelWidth = CARD_WIDTH + BASE_PANEL_PADDING_X * 2
	local availableWidth = sw - edgeMarginX * 2
	local fallbackWidth = sw * 0.9
	local targetWidth = max(availableWidth, fallbackWidth)
	targetWidth = min(targetWidth, sw - 24)
	local maxPanelWidth = max(0, min(basePanelWidth, targetWidth))
	local widthScale
	if maxPanelWidth <= 0 then
		widthScale = 1
	else
		widthScale = min(1, maxPanelWidth / basePanelWidth)
	end

	layout.widthScale = widthScale
	layout.cardWidth = CARD_WIDTH * widthScale
	layout.panelPaddingX = BASE_PANEL_PADDING_X * widthScale
	layout.panelWidth = basePanelWidth * widthScale

	local panelPaddingX = layout.panelPaddingX
	local scrollbarGap = max(MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
	local maxTotalWidth = sw - 24
	local totalWidth = layout.panelWidth + scrollbarGap + SCROLLBAR_TRACK_WIDTH
	if totalWidth > maxTotalWidth and basePanelWidth > 0 then
		local availableForPanel = max(0, maxTotalWidth - scrollbarGap - SCROLLBAR_TRACK_WIDTH)
		if availableForPanel < layout.panelWidth then
			local adjustedScale = availableForPanel / basePanelWidth
			if adjustedScale < widthScale then
				widthScale = max(0.5, adjustedScale)
				layout.widthScale = widthScale
				layout.cardWidth = CARD_WIDTH * widthScale
				layout.panelPaddingX = BASE_PANEL_PADDING_X * widthScale
				layout.panelWidth = basePanelWidth * widthScale
				panelPaddingX = layout.panelPaddingX
				scrollbarGap = max(MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
				totalWidth = layout.panelWidth + scrollbarGap + SCROLLBAR_TRACK_WIDTH
			end
		end
	end

	local panelX = (sw - totalWidth) * 0.5
	local maxPanelX = sw - totalWidth - 12
	panelX = max(12, min(panelX, maxPanelX))
	layout.panelX = panelX
	layout.listX = panelX + panelPaddingX

	local titleFont = UI.fonts.title
	local titleFontHeight = titleFont:getHeight()
	local titleY = UI.getHeaderY(sw, sh)
	layout.titleY = titleY

	local topSpacing = menuLayout.sectionSpacing or max(28, sh * 0.045)
	local desiredPanelTop = titleY + titleFontHeight + topSpacing
	local panelAnchor = menuLayout.bodyTop or menuLayout.stackTop or desiredPanelTop
	local containerTop = max(panelAnchor, min(START_Y, desiredPanelTop))

	layout.panelPaddingY = BASE_PANEL_PADDING_Y

	local panelPaddingY = layout.panelPaddingY
	local summaryInsetX = max(28, panelPaddingX)
	layout.summaryInsetX = summaryInsetX

	local summaryVerticalPadding = max(SUMMARY_PANEL_TOP_PADDING_MIN, panelPaddingY * 0.35)
	local summaryTopPadding = summaryVerticalPadding
	local summaryBottomPadding = max(SUMMARY_PANEL_BOTTOM_PADDING_MIN, summaryVerticalPadding)

	local summaryPanel = {
		x = panelX,
		y = containerTop,
		width = layout.panelWidth,
		topPadding = summaryTopPadding,
		bottomPadding = summaryBottomPadding,
	}

	local progressHeight = SUMMARY_PROGRESS_BAR_HEIGHT
	local summaryLineHeight = UI.fonts.achieve:getHeight()
	local summaryProgressSpacing = SUMMARY_SPACING_TEXT_PROGRESS

	layout.summaryLineHeight = summaryLineHeight
	layout.summaryProgressHeight = progressHeight

	local summaryContentHeight = summaryLineHeight + summaryProgressSpacing + progressHeight
	local summaryHeight = summaryTopPadding + summaryContentHeight + summaryBottomPadding

	summaryPanel.height = summaryHeight
	layout.summaryPanel = summaryPanel

	layout.summaryTextX = panelX + summaryInsetX
	layout.summaryTextWidth = layout.panelWidth - summaryInsetX * 2
	layout.summaryTextY = summaryPanel.y + summaryTopPadding
	layout.summaryProgressY = layout.summaryTextY + summaryLineHeight + summaryProgressSpacing

	local highlightInsetX = max(SUMMARY_HIGHLIGHT_INSET, summaryInsetX * 0.6)
	local highlightInsetY = max(SUMMARY_HIGHLIGHT_INSET, min(summaryTopPadding, summaryBottomPadding) * 0.75)
	layout.summaryHighlightInset = {x = highlightInsetX, y = highlightInsetY}

	local titleClearance = titleY + titleFontHeight + max(24, sh * 0.03)
	local summaryTop = summaryPanel.y - summaryTopPadding
	if summaryTop < titleClearance then
		local adjustment = titleClearance - summaryTop
		summaryPanel.y = summaryPanel.y + adjustment
		layout.summaryTextY = layout.summaryTextY + adjustment
		layout.summaryProgressY = layout.summaryProgressY + adjustment
	end

	local panelGap = max(SUMMARY_PANEL_GAP_MIN, max(panelPaddingY * 0.35, (menuLayout.sectionSpacing or panelPaddingY)))
	layout.panelGap = panelGap

	local listPanelY = summaryPanel.y + summaryPanel.height + panelGap
	layout.panelY = listPanelY

	local buttonHeight = UI.spacing.buttonHeight or 0
	local buttonSpacing = UI.spacing.buttonSpacing or (menuLayout.sectionSpacing or panelPaddingY)
	local footerSpacing = menuLayout.footerSpacing or buttonSpacing
	layout.footerSpacing = footerSpacing

	local scaledReserve = (UI.scaled and UI.scaled(48, 32)) or 48
	local footerReserve = buttonHeight + buttonSpacing + scaledReserve
	local marginBottom = menuLayout.marginBottom or 0
	local baseBottomMargin = marginBottom + footerSpacing + buttonHeight
	local bottomMargin = max(baseBottomMargin, footerReserve)
	layout.bottomMargin = bottomMargin

	local viewportBottom = sh - bottomMargin
	local bottomY = menuLayout.bottomY or (sh - marginBottom)
	local backButtonY = bottomY - footerSpacing - buttonHeight
	layout.backButtonY = backButtonY

	if backButtonY then
		viewportBottom = min(viewportBottom, backButtonY - buttonSpacing * 0.5)
	end

	layout.startY = listPanelY + panelPaddingY
	layout.viewportBottom = max(layout.startY, viewportBottom)
	layout.viewportHeight = max(0, layout.viewportBottom - layout.startY)

	layout.panelHeight = layout.viewportHeight + panelPaddingY * 2
	layout.scissorTop = max(menuLayout.marginTop or 0, layout.startY - SCROLL_SCISSOR_TOP_PADDING)
	layout.scissorBottom = layout.viewportBottom
	layout.scissorHeight = max(0, layout.scissorBottom - layout.scissorTop)

	return layout
end

local function drawThumbSnake(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight, isHovered, isThumbHovered)
	local trail, segmentSize = buildThumbSnakeTrail(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight)
	if #trail < 2 then
		return
	end

	local snakeR, snakeG, snakeB = unpack(Theme.snakeDefault)
	local highlightColor = Theme.highlightColor or {1, 1, 1, 0.1}
	local trackBase = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
	local trackColor = lightenColor(trackBase, isHovered and 0.45 or 0.35)
	local trackAlpha = (trackColor[4] or 1) * (isHovered and 0.75 or 0.55)

	love.graphics.push("all")

	local trackRadius = max(8, segmentSize * 0.55)
	love.graphics.setColor(trackColor[1], trackColor[2], trackColor[3], trackAlpha)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, trackHeight, trackRadius)

	local trackOutline = Theme.panelBorder or Theme.borderColor or {0.5, 0.6, 0.75, 1}
	local outlineAlpha = (trackOutline[4] or 1) * (isHovered and 0.9 or 0.55)
	love.graphics.setColor(trackOutline[1], trackOutline[2], trackOutline[3], outlineAlpha)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", trackX, trackY, trackWidth, trackHeight, trackRadius)

	local thumbHighlight = highlightColor
	if isThumbHovered then
		thumbHighlight = lightenColor(highlightColor, 0.35)
	elseif isHovered then
		thumbHighlight = lightenColor(highlightColor, 0.18)
	end

	local hr = thumbHighlight[1] or snakeR
	local hg = thumbHighlight[2] or snakeG
	local hb = thumbHighlight[3] or snakeB
	local ha = thumbHighlight[4] or 0.12
	if isThumbHovered then
		ha = min(1, ha + 0.28)
	elseif isHovered then
		ha = min(1, ha + 0.15)
	end

	local highlightInsetX = max(4, (trackWidth - segmentSize) * 0.35)
	local highlightInsetY = max(6, segmentSize * 0.45)
	local highlightX = trackX + highlightInsetX
	local highlightY = thumbY + highlightInsetY
	local highlightW = max(0, trackWidth - highlightInsetX * 2)
	local highlightH = max(0, thumbHeight - highlightInsetY * 2)
	love.graphics.setColor(hr, hg, hb, ha)
	love.graphics.rectangle("fill", highlightX, highlightY, highlightW, highlightH, segmentSize * 0.45)

	local outlinePad = max(10, segmentSize)
	local scissorX = trackX - outlinePad
	local scissorY = trackY - outlinePad
	local scissorW = trackWidth + outlinePad * 2
	local scissorH = trackHeight + outlinePad * 2
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)

	love.graphics.setColor(1, 1, 1, 1)
	SnakeDraw.run(trail, #trail, segmentSize, nil, nil, nil, nil, nil)

	local head = trail[#trail]
	if head then
		local headRadius = segmentSize * 0.32
		local eyeOffset = headRadius * 0.55
		local eyeRadius = max(1, headRadius * 0.22)

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

local function updateScrollBounds(sw, sh, layout)
	layout = layout or computeLayout(sw, sh)

	viewportHeight = layout.viewportHeight

	local y = layout.startY
	local maxBottom = layout.startY

	if displayBlocks then
		for _, block in ipairs(displayBlocks) do
			if block.achievements then
				for _ in ipairs(block.achievements) do
					maxBottom = max(maxBottom, y + CARD_HEIGHT)
					y = y + CARD_SPACING
				end
			end
			y = y + CATEGORY_SPACING
		end
	end

	contentHeight = max(0, maxBottom - layout.startY)
	minScrollOffset = min(0, viewportHeight - contentHeight)

	if scrollOffset < minScrollOffset then
		scrollOffset = minScrollOffset
	elseif scrollOffset > 0 then
		scrollOffset = 0
	end

	return layout
end

local function scrollBy(amount)
	if amount == 0 then
		return
	end

	scrollOffset = scrollOffset + amount

	local sw, sh = Screen:get()
	updateScrollBounds(sw, sh)
end

local function dpadScrollUp()
	scrollBy(DPAD_SCROLL_AMOUNT)
	buttonList:moveFocus(-1)
end

local function dpadScrollDown()
	scrollBy(-DPAD_SCROLL_AMOUNT)
	buttonList:moveFocus(1)
end

local analogDirections = {
	dpup = {id = "analog_dpup", repeatable = true, action = dpadScrollUp},
	dpdown = {id = "analog_dpdown", repeatable = true, action = dpadScrollDown},
	dpleft = {
		id = "analog_dpleft",
		repeatable = false,
		action = function()
			buttonList:moveFocus(-1)
		end,
	},
	dpright = {
		id = "analog_dpright",
		repeatable = false,
		action = function()
			buttonList:moveFocus(1)
		end,
	},
}

local analogAxisMap = {
	leftx = {slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright},
	rightx = {slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright},
	lefty = {slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown},
	righty = {slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown},
	[1] = {slot = "horizontal", negative = analogDirections.dpleft, positive = analogDirections.dpright},
	[2] = {slot = "vertical", negative = analogDirections.dpup, positive = analogDirections.dpdown},
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

function AchievementsMenu:enter()
	Screen:update()
	UI.clearButtons()

	local sw, sh = Screen:get()

	configureBackgroundEffect()

	scrollOffset = 0
	minScrollOffset = 0
	resetAnalogDirections()

	Face:set("idle")

	iconCache = {}
	displayBlocks = Achievements:getDisplayOrder()
	rebuildAchievementRewards()

	local layout = computeLayout(sw, sh)
	local backButtonY = resolveBackButtonY(sw, sh, layout)

	buttonList:reset({
		{
			id = "achievementsBack",
			x = sw / 2 - UI.spacing.buttonWidth / 2,
			y = backButtonY,
			w = UI.spacing.buttonWidth,
			h = UI.spacing.buttonHeight,
			textKey = "achievements.back_to_menu",
			text = Localization:get("achievements.back_to_menu"),
			action = "menu",
		},
	})

	applyBackButtonLayout(layout, sw, sh)

	resetHeldDpad()

	local function loadIcon(path)
		local ok, image = pcall(love.graphics.newImage, path)
		if ok then
			return image
		end
		return nil
	end

	iconCache.__default = loadIcon("Assets/Achievements/Default.png")

	updateScrollBounds(sw, sh)

	for _, block in ipairs(displayBlocks) do
		for _, ach in ipairs(block.achievements) do
			local iconName = ach.icon or "Default"
			local path = string.format("Assets/Achievements/%s.png", iconName)
			if not love.filesystem.getInfo(path) then
				path = "Assets/Achievements/Default.png"
			end
			if not iconCache[ach.id] then
				iconCache[ach.id] = loadIcon(path)
			end
		end
	end
end

function AchievementsMenu:update(dt)
        local mx, my = UI.refreshCursor()
        buttonList:updateHover(mx, my)
        Face:update(dt)
        updateHeldDpad(dt)
end

function AchievementsMenu:draw()
        local sw, sh = Screen:get()
        drawBackground(sw, sh)

        if not displayBlocks or #displayBlocks == 0 then
                displayBlocks = Achievements:getDisplayOrder()
        end

        UI.refreshCursor()

        local layout = computeLayout(sw, sh)
        layout = updateScrollBounds(sw, sh, layout)

	applyBackButtonLayout(layout, sw, sh)

	local titleFont = UI.fonts.title
	love.graphics.setFont(titleFont)
	local colors = UI.colors or {}
	local titleColor = colors.text or Theme.textColor or {1, 1, 1, 1}
	local subtleTextColor = colors.subtleText or withAlpha(titleColor, (titleColor[4] or 1) * 0.8)
	setColor(titleColor)
	love.graphics.printf(Localization:get("achievements.title"), 0, layout.titleY, sw, "center")

	local startY = layout.startY
	local spacing = CARD_SPACING
	local cardWidth = layout.cardWidth
	local cardHeight = CARD_HEIGHT
	local categorySpacing = CATEGORY_SPACING

	local listX = layout.listX
	local panelPaddingX = layout.panelPaddingX
	local panelPaddingY = layout.panelPaddingY
	local panelX = layout.panelX
	local panelY = layout.panelY
	local panelWidth = layout.panelWidth
	local panelHeight = layout.panelHeight
	local panelColor = colors.panel or Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
	local panelBorder = colors.panelBorder or colors.border or Theme.panelBorder or Theme.borderColor or {0.5, 0.6, 0.75, 1}
	local shadowColor = colors.shadow or Theme.shadowColor or {0, 0, 0, 0.35}
	local highlightColor = colors.highlight or Theme.highlightColor or {1, 1, 1, 0.06}
	local progressColor = colors.progress or Theme.progressColor or {0.6, 0.9, 0.4, 1}
	local summaryPanel = layout.summaryPanel
	local summaryTextX = layout.summaryTextX
	local summaryTextY = layout.summaryTextY
	local summaryTextWidth = layout.summaryTextWidth
	local summaryProgressHeight = layout.summaryProgressHeight
	local summaryLineHeight = layout.summaryLineHeight or UI.fonts.achieve:getHeight()

	love.graphics.push("all")
	UI.drawPanel(summaryPanel.x, summaryPanel.y, summaryPanel.width, summaryPanel.height, {
		radius = 24,
		fill = panelColor,
		alpha = 0.95,
		borderColor = panelBorder,
		borderWidth = 2,
		highlightColor = highlightColor,
		highlightAlpha = 1,
		shadowColor = withAlpha(shadowColor, (shadowColor[4] or 0.35) * 0.85),
	})

        love.graphics.pop()

        local totals = Achievements:getTotals()
	local unlockedLabel = Localization:get("achievements.summary.unlocked", {
		unlocked = totals.unlocked,
		total = totals.total,
	})
	local completionPercent = toPercent(totals.completion)
	local completionLabel = Localization:get("achievements.summary.completion", {
		percent = completionPercent,
	})
	local achieveFont = UI.fonts.achieve

	love.graphics.setFont(achieveFont)
	setColor(titleColor)
	love.graphics.printf(unlockedLabel, summaryTextX, summaryTextY, summaryTextWidth, "left")
	love.graphics.printf(completionLabel, summaryTextX, summaryTextY, summaryTextWidth, "right")

	local progressBarY = layout.summaryProgressY
	setColor(darkenColor(panelColor, 0.4))
	love.graphics.rectangle("fill", summaryTextX, progressBarY, summaryTextWidth, summaryProgressHeight, 6, 6)

	setColor(progressColor)
	love.graphics.rectangle("fill", summaryTextX, progressBarY, summaryTextWidth * clamp01(totals.completion), summaryProgressHeight, 6, 6)

	love.graphics.push("all")
	UI.drawPanel(panelX, panelY, panelWidth, panelHeight, {
		radius = 28,
		fill = panelColor,
		alpha = 0.95,
		borderColor = panelBorder,
		borderWidth = 2,
		highlightColor = highlightColor,
		highlightAlpha = 1,
		shadowColor = withAlpha(shadowColor, (shadowColor[4] or 0.35) * 0.9),
	})
	love.graphics.pop()

	local scissorTop = layout.scissorTop
	local scissorBottom = layout.scissorBottom
	local scissorHeight = layout.scissorHeight
	love.graphics.setScissor(0, scissorTop, sw, scissorHeight)

	love.graphics.push()
	love.graphics.translate(0, scrollOffset)

	local y = startY
	for _, block in ipairs(displayBlocks) do
		local categoryLabel = Localization:get("achievements.categories." .. block.id)
		love.graphics.setFont(UI.fonts.heading or UI.fonts.button)
		setColor(withAlpha(subtleTextColor, (subtleTextColor[4] or 1) * 0.85))
		love.graphics.printf(categoryLabel, 0, y - 32, sw, "center")

		for _, ach in ipairs(block.achievements) do
			local unlocked = ach.unlocked
			local goal = ach.goal or 0
			local hiddenLocked = ach.hidden and not unlocked
			local hasProgress = (not hiddenLocked) and goal > 0
			local icon = hiddenLocked and iconCache.__default or iconCache[ach.id]
			if not icon then
				icon = iconCache.__default
			end
			local x = listX
			local barW = max(0, cardWidth - 120)
			local cardY = y

			local cardBase = unlocked and lightenColor(panelColor, 0.18) or darkenColor(panelColor, 0.08)
			if hiddenLocked then
				cardBase = darkenColor(panelColor, 0.2)
			end

                        local borderTint = {0, 0, 0, 1}

			love.graphics.push("all")
			UI.drawPanel(x, cardY, cardWidth, cardHeight, {
				radius = 18,
				fill = cardBase,
				borderColor = borderTint,
				borderWidth = 2,
				highlightColor = highlightColor,
				highlightAlpha = unlocked and 1 or 0.8,
				shadowColor = withAlpha(shadowColor, (shadowColor[4] or 0.3) * 0.9),
			})
			love.graphics.pop()

			if icon then
				local iconX, iconY = x + 16, cardY + 18
				local scaleX = 56 / icon:getWidth()
				local scaleY = 56 / icon:getHeight()
				local tint = unlocked and 1 or 0.55
				love.graphics.setColor(tint, tint, tint, 1)
				love.graphics.draw(icon, iconX, iconY, 0, scaleX, scaleY)

				local iconBorder = hiddenLocked and darkenColor(borderTint, 0.35) or borderTint
				setColor(iconBorder)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", iconX - 2, iconY - 2, 60, 60, 8)
			end

			local textX = x + 96

			local titleText
			local descriptionText
			if hiddenLocked then
				titleText = Localization:get("achievements.hidden.title")
				descriptionText = Localization:get("achievements.hidden.description")
			else
				titleText = Localization:get(ach.titleKey)
				descriptionText = Localization:get(ach.descriptionKey)
			end

			love.graphics.setFont(UI.fonts.achieve)
			setColor(titleColor)
			love.graphics.printf(titleText, textX, cardY + 10, cardWidth - 110, "left")

			love.graphics.setFont(UI.fonts.body)
			setColor(subtleTextColor)
			local textWidth = cardWidth - 110
			love.graphics.printf(descriptionText, textX, cardY + 38, textWidth, "left")

			local rewardText = nil
			if not hiddenLocked then
				rewardText = getAchievementRewardLabel(ach)
			end

			local barH = 12
			local barX = textX
			local barY = cardY + cardHeight - 24

			if rewardText and rewardText ~= "" then
				love.graphics.setFont(UI.fonts.small)
				setColor(withAlpha(subtleTextColor, (subtleTextColor[4] or 1) * 0.85))
				local rewardY = barY - (hasProgress and 36 or 24)
				love.graphics.printf(rewardText, textX, rewardY, textWidth, "left")
			end

			if hasProgress then
				local ratio = Achievements:getProgressRatio(ach)

				setColor(darkenColor(cardBase, 0.45))
				love.graphics.rectangle("fill", barX, barY, barW, barH, 6)

				setColor(progressColor)
				love.graphics.rectangle("fill", barX, barY, barW * ratio, barH, 6)

				local progressLabel = Achievements:getProgressLabel(ach)
				if progressLabel then
					love.graphics.setFont(UI.fonts.small)
					setColor(withAlpha(titleColor, (titleColor[4] or 1) * 0.9))
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
		local trackWidth = SCROLLBAR_TRACK_WIDTH
		local trackInset = max(MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
		local trackX = panelX + panelWidth + trackInset
		local trackY = startY
		local trackHeight = viewportHeight

		local scrollRange = -minScrollOffset
		local scrollProgress = scrollRange > 0 and (-scrollOffset / scrollRange) or 0

		local minThumbHeight = 36
		local thumbHeight = max(minThumbHeight, viewportHeight * (viewportHeight / contentHeight))
		thumbHeight = min(thumbHeight, trackHeight)
		local thumbY = trackY + (trackHeight - thumbHeight) * scrollProgress

                local mx, my = UI.getCursorPosition()
                local isOverScrollbar = mx >= trackX and mx <= trackX + trackWidth and my >= trackY and my <= trackY + trackHeight
                local isOverThumb = isOverScrollbar and my >= thumbY and my <= thumbY + thumbHeight

                drawThumbSnake(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight, isOverScrollbar, isOverThumb)
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

	scrollBy(dy * SCROLL_SPEED)
end

function AchievementsMenu:keypressed(key)
	if key == "up" then
		scrollBy(DPAD_SCROLL_AMOUNT)
		buttonList:moveFocus(-1)
	elseif key == "down" then
		scrollBy(-DPAD_SCROLL_AMOUNT)
		buttonList:moveFocus(1)
	elseif key == "left" then
		buttonList:moveFocus(-1)
	elseif key == "right" then
		buttonList:moveFocus(1)
	elseif key == "pageup" then
		local pageStep = DPAD_SCROLL_AMOUNT * max(1, floor(viewportHeight / CARD_SPACING))
		scrollBy(pageStep)
	elseif key == "pagedown" then
		local pageStep = DPAD_SCROLL_AMOUNT * max(1, floor(viewportHeight / CARD_SPACING))
		scrollBy(-pageStep)
	elseif key == "home" then
		scrollBy(-scrollOffset)
	elseif key == "end" then
		scrollBy(minScrollOffset - scrollOffset)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		local action = buttonList:activateFocused()
		if action then
			Audio:playSound("click")
		end
		return action
	elseif key == "escape" or key == "backspace" then
		local action = buttonList:activateFocused() or "menu"
		if action then
			Audio:playSound("click")
		end
		return action
	end
end

function AchievementsMenu:gamepadpressed(_, button)
	if button == "dpup" then
		dpadScrollUp()
		startHeldDpad(button, dpadScrollUp)
	elseif button == "dpleft" then
		buttonList:moveFocus(-1)
	elseif button == "dpdown" then
		dpadScrollDown()
		startHeldDpad(button, dpadScrollDown)
	elseif button == "dpright" then
		buttonList:moveFocus(1)
	elseif button == "leftshoulder" then
		scrollBy(DPAD_SCROLL_AMOUNT * max(1, floor(viewportHeight / CARD_SPACING)))
	elseif button == "rightshoulder" then
		scrollBy(-DPAD_SCROLL_AMOUNT * max(1, floor(viewportHeight / CARD_SPACING)))
	elseif button == "a" or button == "start" or button == "b" then
		local action = buttonList:activateFocused()
		if action then
			Audio:playSound("click")
		end
		return action
	end
end

AchievementsMenu.joystickpressed = AchievementsMenu.gamepadpressed

function AchievementsMenu:gamepadaxis(_, axis, value)
	handleGamepadAxis(axis, value)
end

AchievementsMenu.joystickaxis = AchievementsMenu.gamepadaxis

function AchievementsMenu:gamepadreleased(_, button)
	if button == "dpup" or button == "dpdown" then
		stopHeldDpad(button)
	end
end

AchievementsMenu.joystickreleased = AchievementsMenu.gamepadreleased

return AchievementsMenu
