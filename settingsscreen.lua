local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")
local MenuScene = require("menuscene")
local Display = require("display")
local SnakeCosmetics = require("snakecosmetics")
local Color = require("color")

local abs = math.abs
local max = math.max
local min = math.min

local SettingsScreen = {
	transitionDuration = 0.4,
	transitionStyle = "menuSlide",
}

local ANALOG_DEADZONE = 0.3
local SCROLL_SPEED = 60

local ACHIEVEMENT_CARD_WIDTH = 600
local ACHIEVEMENT_PANEL_PADDING_X = 48
local ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH = 28
local ACHIEVEMENT_MIN_SCROLLBAR_INSET = 16
local BACK_BUTTON_ID = "settingsBackButton"
local BUTTON_CONTENT_INSET = 8

local function applyAudioVolumes()
	Audio:applyVolumes()
end

local function applyDisplaySettings()
	Display.apply(Settings)
end

local backButtonOption = {type = "action", labelKey = "settings.back", action = "menu"}

local options = {
	{type = "header", labelKey = "settings.section_display"},
	{type = "cycle", labelKey = "settings.display_mode", setting = "displayMode"},
	{type = "cycle", labelKey = "settings.windowed_resolution", setting = "resolution"},
	{type = "toggle", labelKey = "settings.toggle_vsync", toggle = "vsync", onChanged = applyDisplaySettings},
	{type = "cycle", labelKey = "settings.msaa_samples", setting = "msaaSamples"},

	{type = "header", labelKey = "settings.section_audio"},
	{type = "toggle", labelKey = "settings.toggle_music", toggle = "muteMusic", onChanged = applyAudioVolumes, invertStateLabel = true},
	{type = "toggle", labelKey = "settings.toggle_sfx", toggle = "muteSFX", onChanged = applyAudioVolumes, invertStateLabel = true},
	{type = "slider", labelKey = "settings.music_volume", slider = "musicVolume", onChanged = applyAudioVolumes},
	{type = "slider", labelKey = "settings.sfx_volume", slider = "sfxVolume", onChanged = applyAudioVolumes},

	{type = "header", labelKey = "settings.section_gameplay"},
	{type = "toggle", labelKey = "settings.toggle_screen_shake", toggle = "screenShake"},
	{type = "toggle", labelKey = "settings.toggle_blood", toggle = "bloodEnabled"},

	{type = "header", labelKey = "settings.section_interface"},
	{type = "toggle", labelKey = "settings.toggle_fps_counter", toggle = "showFPS"},
	{type = "cycle", labelKey = "settings.language", setting = "language"},
}

local buttons = {}
local hoveredIndex = nil
local sliderDragging = nil
local focusedIndex = 1
local focusSource = nil
local lastNonMouseFocusIndex = nil
local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0
local layout = {
	panel = {x = 0, y = 0, w = 0, h = 0},
	title = {y = 0, height = 0},
	margins = {top = 0, bottom = 0},
}

local function isButtonFocusable(btn)
	return btn and btn.focusable ~= false
end

local function findFirstFocusableIndex()
	for index, btn in ipairs(buttons) do
		if isButtonFocusable(btn) then
			return index
		end
	end
	return nil
end

local copyColor = Color.copy
local lightenColor = function(color, factor)
	return Color.lighten(color, factor)
end
local darkenColor = function(color, factor)
	return Color.darken(color, factor)
end
local withAlpha = function(color, alpha)
	return Color.withAlpha(color, alpha)
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

local displayModeLabels = {
	fullscreen = "settings.display_mode_fullscreen",
	windowed = "settings.display_mode_windowed",
}

local function getDisplayModeLabel()
	local mode = Settings.displayMode == "windowed" and "windowed" or "fullscreen"
	local key = displayModeLabels[mode] or displayModeLabels.fullscreen
	return Localization:get(key)
end

local function getResolutionLabel()
	return Display.getResolutionLabel(Localization, Settings.resolution)
end

local function getCycleStateLabel(setting)
	if setting == "language" then
		local current = Settings.language or Localization:getCurrentLanguage()
		return Localization:getLanguageName(current)
	elseif setting == "displayMode" then
		return getDisplayModeLabel()
	elseif setting == "resolution" then
		return getResolutionLabel()
	elseif setting == "msaaSamples" then
		local samples = Settings.msaaSamples or 0
		if samples >= 2 then
			return string.format("%dx", samples)
		end

		local offLabel = Localization:get("settings.msaa_samples_off")
		if not offLabel or offLabel == "" then
			return "0x"
		end

		return offLabel
	end
end

local function cycleLanguage(delta)
	local languages = Localization:getAvailableLanguages()
	if #languages == 0 then
		return Settings.language or Localization:getCurrentLanguage()
	end

	local current = Settings.language or Localization:getCurrentLanguage()
	local index = 1
	for i, code in ipairs(languages) do
		if code == current then
			index = i
			break
		end
	end

	local count = #languages
	local step = delta or 1
	local newIndex = ((index - 1 + step) % count) + 1
	return languages[newIndex]
end

local function resolveSettingsPanelWidth(sw, sh, menuLayout)
	menuLayout = menuLayout or UI.getMenuLayout(sw, sh)

	local basePanelWidth = ACHIEVEMENT_CARD_WIDTH + ACHIEVEMENT_PANEL_PADDING_X * 2
	local edgeMarginX = max(menuLayout.marginHorizontal or 32, sw * 0.05)
	local availableWidth = sw - edgeMarginX * 2
	local fallbackWidth = sw * 0.9
	local targetWidth = max(availableWidth, fallbackWidth)
	local maxPanelWidth = max(0, min(basePanelWidth, targetWidth))
	local widthScale

	if maxPanelWidth <= 0 then
		widthScale = 1
	else
		widthScale = min(1, maxPanelWidth / basePanelWidth)
	end

	local panelWidth = basePanelWidth * widthScale
	local panelPaddingX = ACHIEVEMENT_PANEL_PADDING_X * widthScale
	local scrollbarGap = max(ACHIEVEMENT_MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
	local maxTotalWidth = sw - 24
	local totalWidth = panelWidth + scrollbarGap + ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH

	if totalWidth > maxTotalWidth and basePanelWidth > 0 then
		local availableForPanel = max(0, maxTotalWidth - scrollbarGap - ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH)
		if availableForPanel < panelWidth then
			local adjustedScale = availableForPanel / basePanelWidth
			if adjustedScale < widthScale then
				widthScale = max(0.5, adjustedScale)
				panelWidth = basePanelWidth * widthScale
				panelPaddingX = ACHIEVEMENT_PANEL_PADDING_X * widthScale
				scrollbarGap = max(ACHIEVEMENT_MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
				totalWidth = panelWidth + scrollbarGap + ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH
			end
		end
	end

	return panelWidth, widthScale, panelPaddingX, scrollbarGap, totalWidth
end

local function resolveBackButtonY(sw, sh, currentLayout)
	local menuLayout = UI.getMenuLayout(sw, sh)
	local buttonHeight = UI.spacing.buttonHeight or 0
	local spacing = UI.spacing.buttonSpacing or UI.spacing.sectionSpacing or 0
	local marginBottom = menuLayout.marginBottom or 0

	local y = sh - buttonHeight - spacing
	local safeBottom = (menuLayout.bottomY or (sh - marginBottom)) - buttonHeight
	if safeBottom then
		y = max(y, safeBottom)
	end

	if currentLayout then
		local panelBottom
		if currentLayout.panelY and currentLayout.panelHeight then
			panelBottom = currentLayout.panelY + currentLayout.panelHeight
		elseif currentLayout.viewportBottom then
			panelBottom = currentLayout.viewportBottom
		end

		if panelBottom then
			y = max(y, panelBottom + spacing)
		end
	end

	local maxY = sh - buttonHeight
	if y > maxY then
		y = maxY
	end

	if currentLayout then
		currentLayout.backButtonY = y
	end

	return y
end

local function buildBackButtonLayout(sw, sh, currentLayout)
	local buttonWidth = UI.spacing.buttonWidth or 0
	local buttonHeight = UI.spacing.buttonHeight or 0
	local x = sw / 2 - buttonWidth / 2
	local y = resolveBackButtonY(sw, sh, currentLayout)

	return {
		x = x,
		y = y,
		w = buttonWidth,
		h = buttonHeight,
	}
end

local function refreshLayout(self)
	local prevButton = focusedIndex and buttons[focusedIndex]
	local prevId = prevButton and prevButton.id
	local prevScroll = scrollOffset
	local prevFocusSource = focusSource
	local prevLastNonMouse = lastNonMouseFocusIndex
	Screen:update(0, true)
	self:enter()
	lastNonMouseFocusIndex = prevLastNonMouse
	if lastNonMouseFocusIndex and (lastNonMouseFocusIndex < 1 or lastNonMouseFocusIndex > #buttons) then
		lastNonMouseFocusIndex = nil
	end
	self:setScroll(prevScroll)
	if prevId then
		for index, btn in ipairs(buttons) do
			if btn.id == prevId and btn.focusable ~= false then
				if prevFocusSource == "mouse" then
					self:setFocus(index, nil, "mouse", true)
				else
					self:setFocus(index)
				end
				return
			end
		end
	end
end

local function clampScroll(offset)
	if offset < minScrollOffset then
		return minScrollOffset
	elseif offset > 0 then
		return 0
	end

	return offset
end

function SettingsScreen:updateButtonPositions()
	local offset = scrollOffset
	for _, btn in ipairs(buttons) do
		local baseY = btn.baseY or btn.y or 0
		if btn.scrollable == false then
			btn.y = baseY
			if btn.sliderTrack and btn.sliderTrack.baseY then
				btn.sliderTrack.y = btn.sliderTrack.baseY
			end
		else
			btn.y = baseY + offset
			if btn.sliderTrack and btn.sliderTrack.baseY then
				btn.sliderTrack.y = btn.sliderTrack.baseY + offset
			end
		end
	end
end

function SettingsScreen:updateScrollBounds()
	local panel = layout.panel
	local panelPaddingY = layout.panelPaddingY or UI.spacing.panelPadding
	viewportHeight = layout.viewportHeight or max(0, (panel and panel.h or 0) - panelPaddingY * 2)
	minScrollOffset = min(0, viewportHeight - contentHeight)
	scrollOffset = clampScroll(scrollOffset)
	self:updateButtonPositions()
end

function SettingsScreen:setScroll(offset)
	local newOffset = clampScroll(offset)
	if abs(newOffset - scrollOffset) > 1e-4 then
		scrollOffset = newOffset
		self:updateButtonPositions()
	end
end

function SettingsScreen:scrollBy(amount)
	if not amount or amount == 0 then return end
	self:setScroll(scrollOffset + amount)
end

function SettingsScreen:isOptionVisible(btn)
	local panel = layout.panel
	if not panel then
		return true
	end

	if viewportHeight <= 0 then
		return true
	end

	if btn.scrollable == false then
		return true
	end

	local panelPaddingY = layout.panelPaddingY or UI.spacing.panelPadding
	local viewportTop = panel.y + panelPaddingY
	local viewportBottom = viewportTop + viewportHeight

	local top = btn.y or 0
	local bottom = top + (btn.h or 0)
	if btn.option and btn.option.type == "slider" and btn.sliderTrack then
		local trackTop = btn.sliderTrack.y or top
		local trackBottom = trackTop + (btn.sliderTrack.h or 0)
		if btn.sliderTrack.handleRadius then
			trackTop = trackTop - btn.sliderTrack.handleRadius
			trackBottom = trackBottom + btn.sliderTrack.handleRadius
		end
		top = min(top, trackTop)
		bottom = max(bottom, trackBottom)
	end

	return bottom > viewportTop and top < viewportBottom
end

function SettingsScreen:ensureFocusVisible()
	if not focusedIndex then return end
	local panel = layout.panel
	if not panel or viewportHeight <= 0 then return end

	self:updateButtonPositions()

	local btn = buttons[focusedIndex]
	if not btn or btn.scrollable == false then return end

	local panelPaddingY = layout.panelPaddingY or UI.spacing.panelPadding
	local viewportTop = panel.y + panelPaddingY
	local viewportBottom = viewportTop + viewportHeight

	local top = btn.y
	local bottom = top + btn.h

	if top < viewportTop then
		self:setScroll(scrollOffset + (viewportTop - top))
	elseif bottom > viewportBottom then
		self:setScroll(scrollOffset - (bottom - viewportBottom))
	end
end

local function getBaseColor()
	return (UI.colors and UI.colors.background) or Theme.bgColor
end

function SettingsScreen:getMenuBackgroundOptions()
	return MenuScene.getPlainBackgroundOptions(nil, getBaseColor())
end

local function drawBackground(sw, sh)
	if not MenuScene.shouldDrawBackground() then
		return
	end

	MenuScene.drawBackground(sw, sh, SettingsScreen:getMenuBackgroundOptions())
end

local analogAxisDirections = {horizontal = nil, vertical = nil}

local analogAxisActions = {
	horizontal = {
		negative = function(self)
			self:adjustFocused(-1)
		end,
		positive = function(self)
			self:adjustFocused(1)
		end,
	},
	vertical = {
		negative = function(self)
			self:moveFocus(-1)
		end,
		positive = function(self)
			self:moveFocus(1)
		end,
	},
}

local analogAxisMap = {
	leftx = {slot = "horizontal"},
	rightx = {slot = "horizontal"},
	lefty = {slot = "vertical"},
	righty = {slot = "vertical"},
	[1] = {slot = "horizontal"},
	[2] = {slot = "vertical"},
}

local function resetAnalogAxis()
	analogAxisDirections.horizontal = nil
	analogAxisDirections.vertical = nil
end

local function handleAnalogAxis(self, axis, value)
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
		local actions = analogAxisActions[mapping.slot]
		local action = actions and actions[direction]
		if action then
			action(self)
		end
	end
end

function SettingsScreen:enter()
	Screen:update()
	MenuScene.prepareBackground(self:getMenuBackgroundOptions())
	local sw, sh = Screen:get()
	local menuLayout = UI.getMenuLayout(sw, sh)
	local headerY = UI.getHeaderY(sw, sh)
	local centerX = sw / 2

	resetAnalogAxis()

	local spacing = UI.spacing.buttonSpacing
	local headerHeight = UI.spacing.sectionHeaderHeight
	local headerSpacing = UI.spacing.sectionHeaderSpacing
	local titleFont = UI.fonts.title
	local titleHeight = (titleFont and titleFont:getHeight()) or 0
	local totalHeight = 0
	for index, opt in ipairs(options) do
		local height
		local spacingAfter = spacing

		if opt.type == "slider" then
			height = UI.spacing.sliderHeight
		elseif opt.type == "header" then
			height = headerHeight
			spacingAfter = headerSpacing
		else
			height = UI.spacing.buttonHeight
		end

		totalHeight = totalHeight + height
		if index < #options then
			totalHeight = totalHeight + spacingAfter
		end
	end

	local basePanelPadding = UI.spacing.panelPadding
	local baseSelectionWidth = UI.spacing.buttonWidth
	local panelWidth, _, resolvedPaddingX, resolvedScrollbarGap, resolvedTotalWidth = resolveSettingsPanelWidth(sw, sh, menuLayout)
	local panelPaddingY = basePanelPadding
	local panelPaddingX = resolvedPaddingX or basePanelPadding
	local scrollbarGap = resolvedScrollbarGap
	local totalWidth = resolvedTotalWidth
	local selectionWidth

	if not panelWidth or panelWidth <= 0 then
		local horizontalMargin = menuLayout.marginHorizontal or UI.spacing.sectionSpacing
		local availableWidth = sw - horizontalMargin * 2 - panelPaddingX * 2
		selectionWidth = baseSelectionWidth

		if availableWidth > baseSelectionWidth then
			selectionWidth = min(baseSelectionWidth * 1.35, availableWidth)
		elseif availableWidth > 0 then
			selectionWidth = availableWidth
		end

		panelWidth = selectionWidth + panelPaddingX * 2
		scrollbarGap = max(ACHIEVEMENT_MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
		totalWidth = panelWidth + scrollbarGap + ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH
	else
		selectionWidth = max(0, panelWidth - panelPaddingX * 2)
		if selectionWidth <= 0 then
			selectionWidth = baseSelectionWidth
			panelWidth = selectionWidth + panelPaddingX * 2
		end

		scrollbarGap = scrollbarGap or max(ACHIEVEMENT_MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
		totalWidth = totalWidth or (panelWidth + scrollbarGap + ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH)
	end
	local panelHeight = totalHeight + panelPaddingY * 2
	local minPanelHeight = panelPaddingY * 2 + UI.spacing.buttonHeight
	local spacingGuard = menuLayout.sectionSpacing or UI.spacing.sectionSpacing
	local desiredTopMargin = headerY + titleHeight + spacingGuard
	local desiredBottomMargin = (menuLayout.marginBottom or spacingGuard) + UI.spacing.buttonHeight + spacingGuard
	local desiredMaxPanelHeight = sh - desiredTopMargin - desiredBottomMargin
	local generalMaxPanelHeight = sh - (menuLayout.marginTop or spacingGuard) - (menuLayout.marginBottom or spacingGuard)

	local safeDesiredMax = max(0, desiredMaxPanelHeight)
	local safeGeneralMax = max(0, generalMaxPanelHeight)
	local maxPanelHeight = min(panelHeight, safeDesiredMax, safeGeneralMax)
	if maxPanelHeight < minPanelHeight then
		if safeGeneralMax >= minPanelHeight then
			maxPanelHeight = minPanelHeight
		elseif safeGeneralMax > 0 then
			maxPanelHeight = safeGeneralMax
		else
			maxPanelHeight = minPanelHeight
		end
	end

	panelHeight = maxPanelHeight

	local panelX = (sw - totalWidth) * 0.5
	local maxPanelX = sw - totalWidth - 12
	if maxPanelX < 12 then
		maxPanelX = 12
	end
	panelX = max(12, min(panelX, maxPanelX))

	local minPanelY = desiredTopMargin
	local maxPanelY = sh - desiredBottomMargin - panelHeight
	local panelY
	if maxPanelY >= minPanelY then
		panelY = minPanelY + (maxPanelY - minPanelY) * 0.5
	else
		local centeredY = sh / 2 - panelHeight / 2
		local minAllowedY = max(desiredTopMargin, menuLayout.marginTop or spacingGuard)
		local maxAllowedY = sh - panelHeight - (menuLayout.marginBottom or spacingGuard)
		if maxAllowedY < minAllowedY then
			maxAllowedY = minAllowedY
		end
		if centeredY < minAllowedY then
			panelY = minAllowedY
		elseif centeredY > maxAllowedY then
			panelY = maxAllowedY
		else
			panelY = centeredY
		end
	end

	local scrollbarX = panelX + panelWidth + scrollbarGap

	local viewportHeight = max(0, panelHeight - panelPaddingY * 2)
	local viewportTop = panelY + panelPaddingY

	layout.panel = {x = panelX, y = panelY, w = panelWidth, h = panelHeight}
	layout.panelX = panelX
	layout.panelY = panelY
	layout.panelWidth = panelWidth
	layout.panelHeight = panelHeight
	layout.panelPaddingX = panelPaddingX
	layout.panelPaddingY = panelPaddingY
	layout.viewportHeight = viewportHeight
	layout.viewportTop = viewportTop
	layout.scrollbarGap = scrollbarGap
	layout.scrollbarTrackWidth = ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH
	layout.scrollbar = {
		x = scrollbarX,
		y = viewportTop,
		width = ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH,
		height = viewportHeight,
	}
	layout.totalWidth = totalWidth
	layout.viewportBottom = panelY + panelHeight
	layout.title = {
		height = titleHeight,
		y = headerY,
	}
	layout.margins = {
		top = panelY,
		bottom = sh - (panelY + panelHeight),
	}
	layout.backButton = buildBackButtonLayout(sw, sh, layout)
	contentHeight = totalHeight

	local startY = panelY + panelPaddingY

	-- reset UI.buttons so we don’t keep stale hitboxes
	UI.clearButtons()
	buttons = {}
	scrollOffset = 0
	minScrollOffset = 0
	focusSource = nil
	lastNonMouseFocusIndex = nil

	for i, opt in ipairs(options) do
		local x = panelX + panelPaddingX + BUTTON_CONTENT_INSET
		local y = startY
		local w = max(0, selectionWidth - BUTTON_CONTENT_INSET * 2)
		local spacingAfter = spacing
		local h

		if opt.type == "slider" then
			h = UI.spacing.sliderHeight
		elseif opt.type == "header" then
			h = headerHeight
			spacingAfter = headerSpacing
		else
			h = UI.spacing.buttonHeight
		end

		local id = "settingsOption" .. i

		table.insert(buttons, {
			id = id,
			x = x,
			y = y,
			w = w,
			h = h,
			option = opt,
			hovered = false,
			sliderTrack = nil,
			baseY = y,
			focusable = opt.type ~= "header",
		})

		local entry = buttons[#buttons]

		if opt.type == "slider" then
			local trackHeight = UI.spacing.sliderTrackHeight
			local padding = UI.spacing.sliderPadding
			entry.sliderTrack = {
				x = x + padding,
				y = y + h - padding - trackHeight,
				w = w - padding * 2,
				h = trackHeight,
				handleRadius = UI.spacing.sliderHandleRadius,
				baseY = y + h - padding - trackHeight,
			}
		end

		-- register for clickable items (skip sliders and static headers)
		if opt.type ~= "slider" and opt.type ~= "header" then
			UI.registerButton(id, x, y, w, h, Localization:get(opt.labelKey))
		end

		startY = startY + h
		if i < #options then
			startY = startY + spacingAfter
		end
	end

	if layout.backButton then
		local backBtn = {
			id = BACK_BUTTON_ID,
			x = layout.backButton.x,
			y = layout.backButton.y,
			w = layout.backButton.w,
			h = layout.backButton.h,
			baseY = layout.backButton.y,
			option = backButtonOption,
			hovered = false,
			focusable = true,
			scrollable = false,
		}
		table.insert(buttons, backBtn)
	end

	contentHeight = totalHeight
	self:updateScrollBounds()

	if #buttons == 0 then
		self:clearFocus()
	else
		local initialIndex = focusedIndex
		if not initialIndex or not buttons[initialIndex] then
			initialIndex = findFirstFocusableIndex()
		end
		self:setFocus(initialIndex, nil, nil, true)
	end

	self:updateFocusVisuals()
end

function SettingsScreen:leave()
	sliderDragging = nil
end

function SettingsScreen:update(dt)
	local mx, my = UI.refreshCursor()
	hoveredIndex = nil

	self:updateButtonPositions()

	for i, btn in ipairs(buttons) do
		local opt = btn.option
		local visible = self:isOptionVisible(btn)
		local hovered = false
		local canHover = btn.focusable ~= false
		if visible and canHover then
			hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
		end

		btn.hovered = hovered
		if hovered and canHover then
			hoveredIndex = i
		end

		if sliderDragging and opt.slider == sliderDragging then
			local track = btn.sliderTrack
			local rel
			if track then
				rel = (mx - track.x) / track.w
			else
				rel = (mx - btn.x) / btn.w
			end
			Settings[sliderDragging] = min(1, max(0, rel))
			Settings:save()
			if opt.onChanged then
				opt.onChanged(Settings, opt)
			end
		end
	end

	if hoveredIndex then
		self:setFocus(hoveredIndex, nil, "mouse", true)
	else
		if focusSource == "mouse" then
			if lastNonMouseFocusIndex and buttons[lastNonMouseFocusIndex] and isButtonFocusable(buttons[lastNonMouseFocusIndex]) then
				self:setFocus(lastNonMouseFocusIndex)
			else
				self:clearFocus()
			end
		else
			self:updateFocusVisuals()
		end
	end
end

local function drawSettingsScrollbar(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight, isHovered, isThumbHovered)
	love.graphics.push("all")

	local panelColor = Theme.panelColor or (UI.colors and UI.colors.panelColor)
	local baseTrackColor = panelColor or {0.18, 0.18, 0.22, 0.9}
	local snakeBodyColor = Theme.snakeDefault or Theme.progressColor or {0.45, 0.85, 0.70, 1}
	local baseAlpha = baseTrackColor[4] == nil and 1 or baseTrackColor[4]
	local baseLighten = isHovered and 0.18 or 0.12
	local trackColor = lightenColor(baseTrackColor, baseLighten)
	trackColor[4] = baseAlpha

	local trackRadius = max(8, trackWidth * 0.65)
	local trackOutlineColor = darkenColor(baseTrackColor, 0.45)
	trackOutlineColor[4] = baseAlpha

	setColor(trackColor)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, trackHeight, trackRadius)

	local outlineAlpha = (trackOutlineColor[4] or 1) * 0.95
	local outlineWidth = 3
	setColor(withAlpha(trackOutlineColor, outlineAlpha))
	love.graphics.setLineWidth(outlineWidth)
	local inset = outlineWidth * 0.5
	love.graphics.rectangle(
		"line",
		trackX + inset,
		trackY + inset,
		trackWidth - outlineWidth,
		trackHeight - outlineWidth,
	max(0, trackRadius - inset)
	)

	local thumbPadding = 2
	local thumbWidth = max(6, trackWidth - thumbPadding * 2 + 2)
	local thumbOffsetX = -1
	local thumbX = trackX + thumbPadding + thumbOffsetX
	local hoverBoost = 0

	if isThumbHovered then
		hoverBoost = 0.25
	elseif isHovered then
		hoverBoost = 0.15
	end

	local function adjustHover(color, factor)
		if not color then
			return nil
		end
		local alpha = color[4] == nil and 1 or color[4]
		if not factor or factor <= 0 then
			local copy = copyColor(color)
			copy[4] = alpha
			return copy
		end
		local adjusted = lightenColor(color, factor)
		adjusted[4] = alpha
		return adjusted
	end

	local snakePalette = SnakeCosmetics:getPaletteForSkin()
	local baseBodyColor = (snakePalette and snakePalette.body) or snakeBodyColor
	local bodyColor = adjustHover(baseBodyColor, hoverBoost)

	local paletteOverride
	if snakePalette then
		paletteOverride = {
			body = bodyColor,
			outline = adjustHover(snakePalette.outline, hoverBoost * 0.5),
			glow = adjustHover(snakePalette.glow, hoverBoost * 0.35),
		}
	elseif hoverBoost > 0 then
		paletteOverride = {body = bodyColor}
	end

	local shadowColor = withAlpha(darkenColor(bodyColor or snakeBodyColor, 0.55), 0.45)
	setColor(shadowColor)
	love.graphics.rectangle("fill", thumbX + 1, thumbY + 3, thumbWidth, thumbHeight, thumbWidth * 0.5)

	local snakeDrawn = UI.drawSnakeScrollbarThumb(thumbX, thumbY, thumbWidth, thumbHeight, {
		amplitude = 0,
		frequency = 1.2,
		segmentCount = 18,
		segmentScale = 0.95,
		falloff = 0.4,
		lengthScale = 1,
		paletteOverride = paletteOverride,
		flipVertical = true,
		drawFace = true,
		faceAtBottom = true,
	})

	if not snakeDrawn then
		love.graphics.push()
		love.graphics.translate(0, 2 * thumbY + thumbHeight)
		love.graphics.scale(1, -1)

		local headHeight = min(thumbWidth * 0.9, thumbHeight * 0.42)
		local tailHeight = min(thumbWidth * 0.55, thumbHeight * 0.28)
		local headCenterY = thumbY + headHeight * 0.45
		local tailStartY = thumbY + thumbHeight - tailHeight * 0.6
		local bodyTop = thumbY + headHeight * 0.55
		local bodyBottom = max(bodyTop, tailStartY)
		local bodyHeight = max(0, bodyBottom - bodyTop)

		setColor(bodyColor)
		love.graphics.ellipse("fill", thumbX + thumbWidth * 0.5, headCenterY, thumbWidth * 0.5, headHeight * 0.5)
		if bodyHeight > 0 then
			love.graphics.rectangle("fill", thumbX, bodyTop, thumbWidth, bodyHeight, thumbWidth * 0.45)
		end
		love.graphics.polygon(
			"fill",
			thumbX + thumbWidth * 0.15,
			bodyBottom,
			thumbX + thumbWidth * 0.85,
			bodyBottom,
			thumbX + thumbWidth * 0.5,
		min(thumbY + thumbHeight, bodyBottom + tailHeight)
		)

		local bellyWidth = thumbWidth * 0.6
		local bellyX = thumbX + (thumbWidth - bellyWidth) * 0.5
		local bellyTop = bodyTop + 4
		local bellyBottom = min(bodyBottom - 2, thumbY + thumbHeight - tailHeight * 0.3)
		if bellyBottom > bellyTop then
			setColor(withAlpha(lightenColor(bodyColor, 0.45), 0.9))
			love.graphics.rectangle("fill", bellyX, bellyTop, bellyWidth, bellyBottom - bellyTop, bellyWidth * 0.45)

			local stripeColor = withAlpha(darkenColor(bodyColor, 0.35), 0.55)
			local stripeSpacing = 9
			local stripeInset = bellyWidth * 0.12
			for y = bellyTop + 3, bellyBottom - 3, stripeSpacing do
				setColor(stripeColor)
				love.graphics.rectangle(
					"fill",
					bellyX + stripeInset,
					y,
					bellyWidth - stripeInset * 2,
					2,
					bellyWidth * 0.35
				)
			end
		end

		local eyeColor = Theme.textColor or {0.88, 0.88, 0.92, 1}
		local pupilColor = Theme.bgColor or {0.12, 0.12, 0.14, 1}
		local eyeRadius = max(1.2, thumbWidth * 0.08)
		local pupilRadius = eyeRadius * 0.45
		local eyeOffsetX = thumbWidth * 0.28
		local eyeY = headCenterY - headHeight * 0.15
		setColor(eyeColor)
		love.graphics.circle("fill", thumbX + thumbWidth * 0.5 - eyeOffsetX, eyeY, eyeRadius)
		love.graphics.circle("fill", thumbX + thumbWidth * 0.5 + eyeOffsetX, eyeY, eyeRadius)
		setColor(pupilColor)
		love.graphics.circle("fill", thumbX + thumbWidth * 0.5 - eyeOffsetX, eyeY, pupilRadius)
		love.graphics.circle("fill", thumbX + thumbWidth * 0.5 + eyeOffsetX, eyeY, pupilRadius)

		love.graphics.pop()
	end

	love.graphics.pop()
end

function SettingsScreen:draw()
	local sw, sh = Screen:get()
	drawBackground(sw, sh)

	local panel = layout.panel
	local panelShadowOffset = max(0, (UI.shadowOffset or 0) - 2)
	UI.drawPanel(panel.x, panel.y, panel.w, panel.h, {
		shadowOffset = panelShadowOffset,
	})

	local titleText = Localization:get("settings.title")
	local headerY = UI.getHeaderY(sw, sh)
	UI.drawLabel(titleText, 0, headerY, sw, "center", {
		fontKey = "title",
		shadow = true,
		shadowOffsetX = 1,
		shadowOffsetY = 1,
	})

	self:updateButtonPositions()

	local panelPaddingX = layout.panelPaddingX or UI.spacing.panelPadding
	local panelPaddingY = layout.panelPaddingY or UI.spacing.panelPadding
	local viewportX = panel.x + panelPaddingX
	local viewportY = panel.y + panelPaddingY
	local viewportW = panel.w - panelPaddingX * 2
	local viewportH = max(0, viewportHeight)

	local prevScissorX, prevScissorY, prevScissorW, prevScissorH = love.graphics.getScissor()
	local appliedScissor = false
	if viewportW > 0 and viewportH > 0 then
		love.graphics.setScissor(viewportX, viewportY, viewportW, viewportH)
		appliedScissor = true
	end

	UI.refreshCursor()

	local footerButtons = {}

	for index, btn in ipairs(buttons) do
		if btn.scrollable == false then
			footerButtons[#footerButtons + 1] = {index = index, button = btn}
			goto continue
		end

		local opt = btn.option
		local label = Localization:get(opt.labelKey)
		local isFocused = (focusedIndex == index)
		local visible = self:isOptionVisible(btn)

		if not visible then
			local state = UI.buttons[btn.id]
			if state then
				state.bounds = nil
			end
		end

		if opt.type == "toggle" and opt.toggle then
			local enabled = not not Settings[opt.toggle]
			if opt.invertStateLabel then
				enabled = not enabled
			end
			local state = enabled and Localization:get("common.on") or Localization:get("common.off")
			label = string.format("%s: %s", label, state)
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id)
			end

		elseif opt.type == "slider" and opt.slider then
			local value = min(1, max(0, Settings[opt.slider] or 0))
			if visible then
				local trackX, trackY, trackW, trackH, handleRadius = UI.drawSlider(nil, btn.x, btn.y, btn.w, value, {
					label = label,
					focused = isFocused,
					hovered = btn.hovered,
					register = false,
					labelShadow = true,
					labelShadowOffsetX = 1,
					labelShadowOffsetY = 1,
					valueShadow = true,
					valueShadowOffsetX = 1,
					valueShadowOffsetY = 1,
				})

				btn.sliderTrack = btn.sliderTrack or {}
				btn.sliderTrack.x = trackX
				btn.sliderTrack.y = trackY
				btn.sliderTrack.w = trackW
				btn.sliderTrack.h = trackH
				btn.sliderTrack.handleRadius = handleRadius
				btn.sliderTrack.baseY = trackY - scrollOffset
			else
				local track = btn.sliderTrack
				if track and track.baseY then
					track.y = track.baseY + scrollOffset
				end
			end

		elseif opt.type == "header" then
			if visible then
				local font = UI.fonts.heading
				local fontHeight = font and font:getHeight() or 0
				local textY = btn.y + max(0, (btn.h - fontHeight) * 0.5)
				local headerColor = UI.colors.subtleText
				if headerColor then
					headerColor = {headerColor[1] or 1, headerColor[2] or 1, headerColor[3] or 1, 1}
				else
					headerColor = {1, 1, 1, 1}
				end
				UI.drawLabel(label, btn.x, textY, btn.w, "left", {
					font = font,
					color = headerColor,
					shadow = true,
					shadowOffsetX = 1,
					shadowOffsetY = 1,
				})

				-- Decorative line removed for cleaner section headers
			end

		elseif opt.type == "cycle" and opt.setting then
			local state = getCycleStateLabel(opt.setting)
			if state then
				label = string.format("%s: %s", label, state)
			end
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id)
			end

		else
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id)
			end
		end

		::continue::
	end

	if appliedScissor then
		if prevScissorX then
			love.graphics.setScissor(prevScissorX, prevScissorY, prevScissorW, prevScissorH)
		else
			love.graphics.setScissor()
		end
	end

	for _, entry in ipairs(footerButtons) do
		local index = entry.index
		local btn = entry.button
		local opt = btn.option
		local label = Localization:get(opt.labelKey)
		local isFocused = (focusedIndex == index)

		UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
		UI.setButtonFocus(btn.id, isFocused)
		UI.drawButton(btn.id)
	end

	if contentHeight > viewportHeight and viewportHeight > 0 then
		local panelPaddingX = layout.panelPaddingX or UI.spacing.panelPadding
		local panelPaddingY = layout.panelPaddingY or UI.spacing.panelPadding
		local trackWidth = layout.scrollbarTrackWidth or ACHIEVEMENT_SCROLLBAR_TRACK_WIDTH
		local scrollbarGap = layout.scrollbarGap or max(ACHIEVEMENT_MIN_SCROLLBAR_INSET, panelPaddingX * 0.5)
		local trackX = (layout.scrollbar and layout.scrollbar.x) or (panel.x + panel.w + scrollbarGap)
		local trackY = layout.viewportTop or (panel.y + panelPaddingY)
		local trackHeight = layout.viewportHeight or max(0, panel.h - panelPaddingY * 2)

		local scrollRange = contentHeight - viewportHeight
		local scrollProgress = scrollRange > 0 and (-scrollOffset / scrollRange) or 0
		scrollProgress = max(0, min(1, scrollProgress))

		local minThumbHeight = 36
		local thumbHeight = max(minThumbHeight, viewportHeight * (viewportHeight / contentHeight))
		thumbHeight = min(thumbHeight, trackHeight)
		local thumbTravel = max(0, trackHeight - thumbHeight)
		local thumbY = trackY + thumbTravel * scrollProgress

		local mx, my = UI.getCursorPosition()
		local isOverScrollbar = mx >= trackX and mx <= trackX + trackWidth and my >= trackY and my <= trackY + trackHeight
		local isOverThumb = isOverScrollbar and my >= thumbY and my <= thumbY + thumbHeight

		drawSettingsScrollbar(trackX, trackY, trackWidth, trackHeight, thumbY, thumbHeight, isOverScrollbar, isOverThumb)

		layout.scrollbar = layout.scrollbar or {}
		layout.scrollbar.x = trackX
		layout.scrollbar.y = trackY
		layout.scrollbar.width = trackWidth
		layout.scrollbar.height = trackHeight
		layout.scrollbar.thumbY = thumbY
		layout.scrollbar.thumbHeight = thumbHeight
	elseif layout.scrollbar then
		layout.scrollbar.thumbHeight = 0
	end
end

function SettingsScreen:updateFocusVisuals()
	for index, btn in ipairs(buttons) do
		local focused = (focusedIndex == index)
		btn.focused = focused
		if btn.focusable ~= false and (not btn.option or btn.option.type ~= "slider") then
			UI.setButtonFocus(btn.id, focused)
		elseif btn.id and btn.option and btn.option.type ~= "slider" then
			UI.setButtonFocus(btn.id, false)
		end
	end
end

function SettingsScreen:findNextFocusable(startIndex, delta)
	if #buttons == 0 then return nil end

	local count = #buttons
	local step = delta or 1
	if step == 0 then
		return startIndex
	end

	local index = startIndex or 0
	for _ = 1, count do
		index = index + step
		if index < 1 then
			index = count
		elseif index > count then
			index = 1
		end

		local btn = buttons[index]
		if isButtonFocusable(btn) then
			return index
		end
	end

	return nil
end

function SettingsScreen:clearFocus()
	focusedIndex = nil
	focusSource = nil
	lastNonMouseFocusIndex = nil
	self:updateFocusVisuals()
end

function SettingsScreen:setFocus(index, direction, source, skipNonMouseHistory)
	if #buttons == 0 then
		self:clearFocus()
		return
	end

	local count = #buttons
	if not index then
		index = findFirstFocusableIndex()
		if not index then
			self:clearFocus()
			return
		end
	else
		index = max(1, min(index, count))
	end

	if not isButtonFocusable(buttons[index]) then
		local searchDir = direction
		if not searchDir then
			if focusedIndex and index < focusedIndex then
				searchDir = -1
			else
				searchDir = 1
			end
		end

		local nextIndex = self:findNextFocusable(index, searchDir)
		if not nextIndex then
			nextIndex = self:findNextFocusable(index, -(searchDir or 1))
		end

		if not nextIndex then
			self:clearFocus()
			return
		end

		index = nextIndex
	end

	focusedIndex = index
	focusSource = source or "programmatic"
	if focusSource ~= "mouse" and not skipNonMouseHistory then
		lastNonMouseFocusIndex = index
	end
	self:ensureFocusVisible()
	self:updateFocusVisuals()
end

function SettingsScreen:moveFocus(delta)
	if #buttons == 0 then return end

	if not focusedIndex then
		local first = findFirstFocusableIndex()
		if first then
			self:setFocus(first)
		end
		return
	end

	local nextIndex = self:findNextFocusable(focusedIndex, delta)
	if nextIndex then
		self:setFocus(nextIndex, delta)
	end
end

function SettingsScreen:getFocusedOption()
	if not focusedIndex then return nil end
	return buttons[focusedIndex]
end

function SettingsScreen:cycleSetting(setting, delta)
	delta = delta or 1

	if setting == "language" then
		local nextLang = cycleLanguage(delta)
		Settings.language = nextLang
		Settings:save()
		Localization:setLanguage(nextLang)
		Audio:playSound("click")
		refreshLayout(self)
	elseif setting == "displayMode" then
		local nextMode = Display.cycleDisplayMode(Settings.displayMode, delta)
		if nextMode ~= Settings.displayMode then
			Settings.displayMode = nextMode
			Settings:save()
			Display.apply(Settings)
			Audio:playSound("click")
			refreshLayout(self)
		end
	elseif setting == "resolution" then
		local nextResolution = Display.cycleResolution(Settings.resolution, delta)
		if nextResolution ~= Settings.resolution then
			Settings.resolution = nextResolution
			Settings:save()
			if Settings.displayMode == "windowed" then
				Display.apply(Settings)
			end
			Audio:playSound("click")
			refreshLayout(self)
		end
	elseif setting == "msaaSamples" then
		local nextSamples = Display.cycleMSAASamples(Settings.msaaSamples, delta)
		if nextSamples ~= Settings.msaaSamples then
			Settings.msaaSamples = nextSamples
			Display.apply(Settings)
			Settings:save()
			Audio:playSound("click")
			refreshLayout(self)
		end
	end
end

function SettingsScreen:adjustFocused(delta)
	local btn = self:getFocusedOption()
	if not btn or delta == 0 then return end

	local opt = btn.option
	if opt.type == "slider" and opt.slider then
		local step = 0.05 * delta
		local value = Settings[opt.slider] or 0
		local newValue = min(1, max(0, value + step))
		if abs(newValue - value) > 1e-4 then
			Settings[opt.slider] = newValue
			Settings:save()
			if opt.onChanged then
				opt.onChanged(Settings, opt)
			end
		end
	elseif opt.type == "toggle" and opt.toggle then
		local current = not not Settings[opt.toggle]
		local target
		if delta < 0 then
			target = false
		elseif delta > 0 then
			target = true
		else
			target = current
		end

		if target ~= current then
			Settings[opt.toggle] = target
			Settings:save()
			if opt.onChanged then
				opt.onChanged(Settings, opt)
			end
			Audio:playSound("click")
		end
	elseif opt.type == "cycle" and opt.setting then
		self:cycleSetting(opt.setting, delta)
	end
end

function SettingsScreen:activateFocused()
	local btn = self:getFocusedOption()
	if not btn then return nil end

	local opt = btn.option
	if opt.type == "toggle" and opt.toggle then
		Settings[opt.toggle] = not Settings[opt.toggle]
		Settings:save()
		if opt.onChanged then
			opt.onChanged(Settings, opt)
		end
		Audio:playSound("click")
		return nil
	elseif opt.type == "action" then
		Audio:playSound("click")
		if type(opt.action) == "function" then
			opt.action()
			return nil
		else
			return opt.action
		end
	elseif opt.type == "cycle" and opt.setting then
		self:cycleSetting(opt.setting, 1)
	end

	return nil
end

function SettingsScreen:mousepressed(x, y, button)
	self:updateButtonPositions()
	local id = UI:mousepressed(x, y, button)

	for i, btn in ipairs(buttons) do
		local opt = btn.option
		local visible = self:isOptionVisible(btn)
		local canHover = btn.focusable ~= false

		if not visible then
			goto continue
		end

		if canHover and btn.id and btn.id == id then
			self:setFocus(i, nil, "mouse", true)

			if opt.type == "cycle" and opt.setting then
				self:cycleSetting(opt.setting, 1)
				return nil
			elseif opt.action then
				if type(opt.action) == "function" then
					opt.action()
				else
					return opt.action
				end
			elseif opt.toggle then
				Settings[opt.toggle] = not Settings[opt.toggle]
				Settings:save()
				if opt.onChanged then
					opt.onChanged(Settings, opt)
				end
			end
		end

		if opt.slider then
			local track = btn.sliderTrack
			local hoveredSlider
			if track then
				hoveredSlider = x >= track.x and x <= track.x + track.w and
				y >= track.y - (track.h * 0.75) and y <= track.y + track.h * 1.75
			else
				hoveredSlider = x >= btn.x and x <= btn.x + btn.w and
				y >= btn.y and y <= btn.y + btn.h
			end
			if hoveredSlider then
				sliderDragging = opt.slider
				local rel
				if track then
					rel = (x - track.x) / track.w
				else
					rel = (x - btn.x) / btn.w
				end
				Settings[sliderDragging] = min(1, max(0, rel))
				Settings:save()
				if opt.onChanged then
					opt.onChanged(Settings, opt)
				end
				self:setFocus(i, nil, "mouse", true)
			end
		end

		::continue::
	end
end

function SettingsScreen:mousereleased(x, y, button)
	UI:mousereleased(x, y, button)
	sliderDragging = nil
end

function SettingsScreen:keypressed(key)
	if key == "up" then
		self:moveFocus(-1)
	elseif key == "down" then
		self:moveFocus(1)
	elseif key == "left" then
		self:adjustFocused(-1)
	elseif key == "right" then
		self:adjustFocused(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return self:activateFocused()
	elseif key == "escape" or key == "backspace" then
		return "menu"
	end
end

function SettingsScreen:gamepadpressed(_, button)
	if button == "dpup" then
		self:moveFocus(-1)
	elseif button == "dpdown" then
		self:moveFocus(1)
	elseif button == "dpleft" then
		self:adjustFocused(-1)
	elseif button == "dpright" then
		self:adjustFocused(1)
	elseif button == "a" or button == "start" then
		return self:activateFocused()
	elseif button == "b" then
		return "menu"
	end
end

SettingsScreen.joystickpressed = SettingsScreen.gamepadpressed

function SettingsScreen:gamepadaxis(_, axis, value)
	handleAnalogAxis(self, axis, value)
end

SettingsScreen.joystickaxis = SettingsScreen.gamepadaxis

function SettingsScreen:wheelmoved(_, dy)
	if dy == 0 then
		return
	end

	self:scrollBy(dy * SCROLL_SPEED)
end

return SettingsScreen
