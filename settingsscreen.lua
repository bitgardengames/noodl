local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")
local Shaders = require("shaders")
local Display = require("display")

local SettingsScreen = {
	transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local SCROLL_SPEED = 60

local function applyAudioVolumes()
	Audio:applyVolumes()
end

local function applyDisplaySettings()
	Display.apply(Settings)
end

local options = {
	{ type = "header", labelKey = "settings.section_display" },
	{ type = "cycle", labelKey = "settings.display_mode", setting = "displayMode", descriptionKey = "settings.descriptions.display_mode" },
	{ type = "cycle", labelKey = "settings.windowed_resolution", setting = "resolution", descriptionKey = "settings.descriptions.windowed_resolution" },
	{ type = "toggle", labelKey = "settings.toggle_vsync", toggle = "vsync", onChanged = applyDisplaySettings, descriptionKey = "settings.descriptions.toggle_vsync" },

	{ type = "header", labelKey = "settings.section_audio" },
	{ type = "toggle", labelKey = "settings.toggle_music", toggle = "muteMusic", onChanged = applyAudioVolumes, invertStateLabel = true, descriptionKey = "settings.descriptions.toggle_music" },
	{ type = "toggle", labelKey = "settings.toggle_sfx", toggle = "muteSFX", onChanged = applyAudioVolumes, invertStateLabel = true, descriptionKey = "settings.descriptions.toggle_sfx" },
	{ type = "slider", labelKey = "settings.music_volume", slider = "musicVolume", onChanged = applyAudioVolumes, descriptionKey = "settings.descriptions.music_volume" },
	{ type = "slider", labelKey = "settings.sfx_volume", slider = "sfxVolume", onChanged = applyAudioVolumes, descriptionKey = "settings.descriptions.sfx_volume" },

	{ type = "header", labelKey = "settings.section_gameplay" },
	{ type = "toggle", labelKey = "settings.toggle_screen_shake", toggle = "screenShake", descriptionKey = "settings.descriptions.toggle_screen_shake" },
	{ type = "toggle", labelKey = "settings.toggle_blood", toggle = "bloodEnabled", descriptionKey = "settings.descriptions.toggle_blood" },

	{ type = "header", labelKey = "settings.section_interface" },
	{ type = "toggle", labelKey = "settings.toggle_fps_counter", toggle = "showFPS", descriptionKey = "settings.descriptions.toggle_fps_counter" },
	{ type = "cycle", labelKey = "settings.language", setting = "language", descriptionKey = "settings.descriptions.language" },

	{ type = "action", labelKey = "settings.back", action = "menu" }
}

local buttons = {}
local hoveredIndex = nil
local sliderDragging = nil
local focusedIndex = 1
local scrollOffset = 0
local minScrollOffset = 0
local viewportHeight = 0
local contentHeight = 0
local layout = {
        panel = { x = 0, y = 0, w = 0, h = 0 },
        title = { y = 0, height = 0 },
        margins = { top = 0, bottom = 0 },
}

local function getOptionDescription(opt)
        if not opt or not opt.descriptionKey then
                return nil
        end

        local text = Localization:get(opt.descriptionKey)
        if text and text ~= opt.descriptionKey then
                return text
        end

        return nil
end

local function getOptionHeight(opt)
        local spacing = UI.spacing
        local baseHeight

        if opt.type == "slider" then
                baseHeight = spacing.sliderHeight
        elseif opt.type == "header" then
                baseHeight = spacing.sectionHeaderHeight
        else
                baseHeight = spacing.buttonHeight
        end

        if opt.descriptionKey then
                local descFont = UI.fonts.small
                local descHeight = (descFont and descFont:getHeight()) or 0
                local extraPadding = math.max(6, math.floor((spacing.buttonSpacing or 12) * 0.35))
                baseHeight = baseHeight + descHeight + extraPadding
        end

        return baseHeight
end

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

local BACKGROUND_EFFECT_TYPE = "settingsBlueprint"
local backgroundEffectCache = {}
local backgroundEffect = nil

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

local function refreshLayout(self)
	local prevButton = focusedIndex and buttons[focusedIndex]
	local prevId = prevButton and prevButton.id
	local prevScroll = scrollOffset
	Screen:update(0, true)
	self:enter()
	self:setScroll(prevScroll)
	if prevId then
		for index, btn in ipairs(buttons) do
			if btn.id == prevId and btn.focusable ~= false then
				self:setFocus(index)
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
		btn.y = baseY + offset
		if btn.sliderTrack and btn.sliderTrack.baseY then
			btn.sliderTrack.y = btn.sliderTrack.baseY + offset
		end
	end
end

function SettingsScreen:updateScrollBounds()
	local panel = layout.panel
	local panelPadding = UI.spacing.panelPadding
	viewportHeight = math.max(0, (panel and panel.h or 0) - panelPadding * 2)
	minScrollOffset = math.min(0, viewportHeight - contentHeight)
	scrollOffset = clampScroll(scrollOffset)
	self:updateButtonPositions()
end

function SettingsScreen:setScroll(offset)
	local newOffset = clampScroll(offset)
	if math.abs(newOffset - scrollOffset) > 1e-4 then
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

	local panelPadding = UI.spacing.panelPadding
	local viewportTop = panel.y + panelPadding
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
		top = math.min(top, trackTop)
		bottom = math.max(bottom, trackBottom)
	end

	return bottom > viewportTop and top < viewportBottom
end

function SettingsScreen:ensureFocusVisible()
	if not focusedIndex then return end
	local panel = layout.panel
	if not panel or viewportHeight <= 0 then return end

	self:updateButtonPositions()

	local btn = buttons[focusedIndex]
	if not btn then return end

	local panelPadding = UI.spacing.panelPadding
	local viewportTop = panel.y + panelPadding
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

	local function configureBackgroundEffect()
	local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		backgroundEffect = nil
		return
	end

	local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
	effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.5

	Shaders.configure(effect, {
		bgColor = getBaseColor(),
		accentColor = Theme.borderColor,
		lineColor = Theme.highlightColor,
	})

	backgroundEffect = effect
	end

	local function drawBackground(sw, sh)
	local baseColor = getBaseColor()
	love.graphics.setColor(baseColor)
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

	local analogAxisDirections = { horizontal = nil, vertical = nil }

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
	leftx = { slot = "horizontal" },
	rightx = { slot = "horizontal" },
	lefty = { slot = "vertical" },
	righty = { slot = "vertical" },
	[1] = { slot = "horizontal" },
	[2] = { slot = "vertical" },
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
	configureBackgroundEffect()
	local sw, sh = Screen:get()
	local centerX = sw / 2

	resetAnalogAxis()

	local spacing = UI.spacing.buttonSpacing
	local headerHeight = UI.spacing.sectionHeaderHeight
	local headerSpacing = UI.spacing.sectionHeaderSpacing
	local titleFont = UI.fonts.title
	local titleHeight = (titleFont and titleFont:getHeight()) or 0
	local subtitleText = Localization:get("settings.subtitle")
	local subtitleFont = UI.fonts.subtitle
	local subtitleHeight = (subtitleFont and subtitleFont:getHeight()) or 0
	local hasSubtitle = subtitleText and subtitleText ~= "" and subtitleText ~= "settings.subtitle"
	if not hasSubtitle then
	subtitleHeight = 0
	end
	local subtitleSpacing = hasSubtitle and math.max(8, math.floor((UI.spacing.sectionHeaderSpacing or 12) * 0.75)) or 0

	local totalHeight = 0
	for index, opt in ipairs(options) do
	local height = getOptionHeight(opt)
	local spacingAfter = spacing
	if opt.type == "header" then
	spacingAfter = headerSpacing
	end

	totalHeight = totalHeight + height
	if index < #options then
	totalHeight = totalHeight + spacingAfter
	end
	end

	local panelPadding = UI.spacing.panelPadding
	local panelWidth = UI.spacing.buttonWidth + panelPadding * 2
	local panelHeight = totalHeight + panelPadding * 2
	local minPanelHeight = panelPadding * 2 + UI.spacing.buttonHeight
	local desiredTopMargin = UI.spacing.sectionSpacing + titleHeight + subtitleSpacing + subtitleHeight + UI.spacing.sectionSpacing
	local desiredBottomMargin = UI.spacing.sectionSpacing + UI.spacing.buttonHeight + UI.spacing.sectionSpacing
	local desiredMaxPanelHeight = sh - desiredTopMargin - desiredBottomMargin
	local generalMaxPanelHeight = sh - UI.spacing.sectionSpacing * 2

	local safeDesiredMax = math.max(0, desiredMaxPanelHeight)
	local safeGeneralMax = math.max(0, generalMaxPanelHeight)
	local maxPanelHeight = math.min(panelHeight, safeDesiredMax, safeGeneralMax)
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

	local panelX = centerX - panelWidth / 2

	local minPanelY = desiredTopMargin
	local maxPanelY = sh - desiredBottomMargin - panelHeight
	local panelY
	if maxPanelY >= minPanelY then
		panelY = minPanelY + (maxPanelY - minPanelY) * 0.5
	else
		local centeredY = sh / 2 - panelHeight / 2
		local minAllowedY = UI.spacing.sectionSpacing
		local maxAllowedY = sh - panelHeight - UI.spacing.sectionSpacing
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

	layout.panel = { x = panelX, y = panelY, w = panelWidth, h = panelHeight }
	layout.title = {
		height = titleHeight,
		y = math.max(UI.spacing.sectionSpacing, panelY - UI.spacing.sectionSpacing - titleHeight * 0.25),
		subtitleHeight = subtitleHeight,
		subtitleSpacing = subtitleSpacing,
	}
	if hasSubtitle then
		layout.subtitle = {
			height = subtitleHeight,
			spacing = subtitleSpacing,
		}
	else
		layout.subtitle = nil
	end
	layout.margins = {
		top = panelY,
		bottom = sh - (panelY + panelHeight),
	}
	contentHeight = totalHeight

	local startY = panelY + panelPadding

	-- reset UI.buttons so we don't keep stale hitboxes
	UI.clearButtons()
	buttons = {}
	scrollOffset = 0
	minScrollOffset = 0

	for i, opt in ipairs(options) do
		local x = panelX + panelPadding
		local y = startY
		local w = UI.spacing.buttonWidth
		local spacingAfter = spacing
		local h = getOptionHeight(opt)

		if opt.type == "header" then
			spacingAfter = headerSpacing
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

	contentHeight = totalHeight
	self:updateScrollBounds()

	if #buttons == 0 then
		focusedIndex = nil
	else
		local initialIndex = focusedIndex
		if not initialIndex or not buttons[initialIndex] then
			initialIndex = findFirstFocusableIndex()
		end
		self:setFocus(initialIndex)
	end

	self:updateFocusVisuals()
end

function SettingsScreen:leave()
	sliderDragging = nil
end

function SettingsScreen:update(dt)
	local mx, my = love.mouse.getPosition()
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
			Settings[sliderDragging] = math.min(1, math.max(0, rel))
			Settings:save()
			if opt.onChanged then
				opt.onChanged(Settings, opt)
			end
		end
	end

	if hoveredIndex then
		self:setFocus(hoveredIndex)
	else
		self:updateFocusVisuals()
	end
end

function SettingsScreen:draw()
	local sw, sh = Screen:get()
	drawBackground(sw, sh)

	local panel = layout.panel
	UI.drawPanel(panel.x, panel.y, panel.w, panel.h)

	local titleText = Localization:get("settings.title")
	local titleLayout = layout.title or {}
	local titleY = titleLayout.y or math.max(UI.spacing.sectionSpacing, panel.y - UI.spacing.sectionSpacing - (titleLayout.height or 0) * 0.25)
	UI.drawLabel(titleText, 0, titleY, sw, "center", { fontKey = "title" })

	local subtitleText = Localization:get("settings.subtitle")
	if subtitleText and subtitleText ~= "" and subtitleText ~= "settings.subtitle" then
		local subtitleLayout = layout.subtitle or {}
		local subtitleSpacing = subtitleLayout.spacing or math.max(8, math.floor((UI.spacing.sectionHeaderSpacing or 12) * 0.5))
		local subtitleY = titleY + (titleLayout.height or 0) + subtitleSpacing
		UI.drawLabel(subtitleText, 0, subtitleY, sw, "center", {
			fontKey = "subtitle",
			color = UI.colors.subtleText,
		})
	end

	self:updateButtonPositions()

	local panelPadding = UI.spacing.panelPadding
	local viewportX = panel.x + panelPadding
	local viewportY = panel.y + panelPadding
	local viewportW = panel.w - panelPadding * 2
	local viewportH = math.max(0, viewportHeight)

	local prevScissorX, prevScissorY, prevScissorW, prevScissorH = love.graphics.getScissor()
	local appliedScissor = false
	if viewportW > 0 and viewportH > 0 then
		love.graphics.setScissor(viewportX, viewportY, viewportW, viewportH)
		appliedScissor = true
	end

	for index, btn in ipairs(buttons) do
		local opt = btn.option
		local baseLabel = Localization:get(opt.labelKey)
		local description = getOptionDescription(opt)
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
			local stateText = enabled and Localization:get("common.on") or Localization:get("common.off")
			local accessibleLabel = string.format("%s: %s", baseLabel, stateText)
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, accessibleLabel)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id, {
					style = "settingsOption",
					label = baseLabel,
					state = stateText,
					description = description,
					stateColor = enabled and (UI.colors.accentText or UI.colors.highlight or UI.colors.text) or (UI.colors.subtleText or UI.colors.text),
				})
			end

		elseif opt.type == "slider" and opt.slider then
			local value = math.min(1, math.max(0, Settings[opt.slider] or 0))
			if visible then
				local trackX, trackY, trackW, trackH, handleRadius = UI.drawSlider(nil, btn.x, btn.y, btn.w, value, {
					label = baseLabel,
					focused = isFocused,
					hovered = btn.hovered,
					register = false,
					description = description,
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
				local textY = btn.y + math.max(0, (btn.h - fontHeight) * 0.5)
				UI.drawLabel(baseLabel, btn.x, textY, btn.w, "left", {
					font = font,
					color = UI.colors.subtleText,
				})

				if fontHeight > 0 then
					local lineY = math.min(btn.y + btn.h - 3, textY + fontHeight + 4)
					local lineColor = UI.colors.highlight or {1, 1, 1, 0.4}
					love.graphics.setColor(lineColor[1] or 1, lineColor[2] or 1, lineColor[3] or 1, (lineColor[4] or 1) * 0.45)
					love.graphics.rectangle("fill", btn.x, lineY, btn.w, 2)
					love.graphics.setColor(1, 1, 1, 1)
				end
			end

		elseif opt.type == "cycle" and opt.setting then
			local state = getCycleStateLabel(opt.setting)
			local accessibleLabel = baseLabel
			if state then
				accessibleLabel = string.format("%s: %s", baseLabel, state)
			end
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, accessibleLabel)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id, {
					style = "settingsOption",
					label = baseLabel,
					state = state,
					description = description,
					stateColor = UI.colors.accentText or UI.colors.highlight or UI.colors.text,
					showCycleHint = true,
				})
			end

		else
			if visible then
				UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, baseLabel)
				UI.setButtonFocus(btn.id, isFocused)
				UI.drawButton(btn.id)
			end
		end
	end

	if appliedScissor then
		if prevScissorX then
			love.graphics.setScissor(prevScissorX, prevScissorY, prevScissorW, prevScissorH)
		else
			love.graphics.setScissor()
		end
	end

	if contentHeight > viewportHeight and viewportHeight > 0 then
		local trackWidth = 6
		local trackRadius = trackWidth / 2
		local trackX = panel.x + panel.w - trackWidth - panelPadding * 0.5
		local trackY = viewportY
		local trackHeight = viewportHeight

		local scrollRange = contentHeight - viewportHeight
		local scrollProgress = scrollRange > 0 and (-scrollOffset / scrollRange) or 0
		scrollProgress = math.max(0, math.min(1, scrollProgress))

		local minThumbHeight = 32
		local thumbHeight = math.max(minThumbHeight, trackHeight * (viewportHeight / contentHeight))
		thumbHeight = math.min(thumbHeight, trackHeight)
		local thumbY = trackY + (trackHeight - thumbHeight) * scrollProgress

		local trackColor = Theme.panelBorder or UI.colors.panelBorder or {1, 1, 1, 0.4}
		local thumbColor = Theme.highlightColor or UI.colors.highlight or {1, 1, 1, 0.8}

		love.graphics.setColor(trackColor[1] or 1, trackColor[2] or 1, trackColor[3] or 1, (trackColor[4] or 1) * 0.4)
		love.graphics.rectangle("fill", trackX, trackY, trackWidth, trackHeight, trackRadius)

		local thumbAlpha = math.min(1, (thumbColor[4] or 1) * 1.2)
		love.graphics.setColor(thumbColor[1] or 1, thumbColor[2] or 1, thumbColor[3] or 1, thumbAlpha)
		love.graphics.rectangle("fill", trackX, thumbY, trackWidth, thumbHeight, trackRadius)
		love.graphics.setColor(1, 1, 1, 1)
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

function SettingsScreen:setFocus(index, direction)
	if #buttons == 0 then
		focusedIndex = nil
		return
	end

	local count = #buttons
	if not index then
		index = findFirstFocusableIndex()
		if not index then
			focusedIndex = nil
			self:updateFocusVisuals()
			return
		end
	else
		index = math.max(1, math.min(index, count))
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
			nextIndex = self:findNextFocusable(index, -searchDir)
		end

		if not nextIndex then
			focusedIndex = nil
			self:updateFocusVisuals()
			return
		end

		index = nextIndex
	end

	focusedIndex = index
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
	end
end

function SettingsScreen:adjustFocused(delta)
	local btn = self:getFocusedOption()
	if not btn or delta == 0 then return end

	local opt = btn.option
	if opt.type == "slider" and opt.slider then
		local step = 0.05 * delta
		local value = Settings[opt.slider] or 0
		local newValue = math.min(1, math.max(0, value + step))
		if math.abs(newValue - value) > 1e-4 then
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
			self:setFocus(i)

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
				Settings[sliderDragging] = math.min(1, math.max(0, rel))
				Settings:save()
				if opt.onChanged then
					opt.onChanged(Settings, opt)
				end
				self:setFocus(i)
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
