local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")
local Localization = require("localization")
local Shaders = require("shaders")
local Display = require("display")

local SettingsScreen = {
	TransitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local SCROLL_SPEED = 60

local function ApplyAudioVolumes()
	Audio:ApplyVolumes()
end

local function ApplyDisplaySettings()
	Display.apply(Settings)
end

local options = {
	{ type = "header", LabelKey = "settings.section_display" },
	{ type = "cycle", LabelKey = "settings.display_mode", setting = "DisplayMode" },
	{ type = "cycle", LabelKey = "settings.windowed_resolution", setting = "resolution" },
	{ type = "toggle", LabelKey = "settings.toggle_vsync", toggle = "vsync", OnChanged = ApplyDisplaySettings },

	{ type = "header", LabelKey = "settings.section_audio" },
	{ type = "toggle", LabelKey = "settings.toggle_music", toggle = "MuteMusic", OnChanged = ApplyAudioVolumes, InvertStateLabel = true },
	{ type = "toggle", LabelKey = "settings.toggle_sfx", toggle = "MuteSFX", OnChanged = ApplyAudioVolumes, InvertStateLabel = true },
	{ type = "slider", LabelKey = "settings.music_volume", slider = "MusicVolume", OnChanged = ApplyAudioVolumes },
	{ type = "slider", LabelKey = "settings.sfx_volume", slider = "SfxVolume", OnChanged = ApplyAudioVolumes },

	{ type = "header", LabelKey = "settings.section_gameplay" },
	{ type = "toggle", LabelKey = "settings.toggle_screen_shake", toggle = "ScreenShake" },
	{ type = "toggle", LabelKey = "settings.toggle_blood", toggle = "BloodEnabled" },

	{ type = "header", LabelKey = "settings.section_interface" },
	{ type = "toggle", LabelKey = "settings.toggle_fps_counter", toggle = "ShowFPS" },
	{ type = "cycle", LabelKey = "settings.language", setting = "language" },

	{ type = "action", LabelKey = "settings.back", action = "menu" }
}

local buttons = {}
local HoveredIndex = nil
local SliderDragging = nil
local FocusedIndex = 1
local FocusSource = nil
local LastNonMouseFocusIndex = nil
local ScrollOffset = 0
local MinScrollOffset = 0
local ViewportHeight = 0
local ContentHeight = 0
local layout = {
	panel = { x = 0, y = 0, w = 0, h = 0 },
	title = { y = 0, height = 0 },
	margins = { top = 0, bottom = 0 },
}

local function IsButtonFocusable(btn)
	return btn and btn.focusable ~= false
end

local function FindFirstFocusableIndex()
	for index, btn in ipairs(buttons) do
		if IsButtonFocusable(btn) then
			return index
		end
	end
	return nil
end

local BACKGROUND_EFFECT_TYPE = "SettingsBlueprint"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local DisplayModeLabels = {
	fullscreen = "settings.display_mode_fullscreen",
	windowed = "settings.display_mode_windowed",
}

local function GetDisplayModeLabel()
	local mode = Settings.DisplayMode == "windowed" and "windowed" or "fullscreen"
	local key = DisplayModeLabels[mode] or DisplayModeLabels.fullscreen
	return Localization:get(key)
end

local function GetResolutionLabel()
	return Display.GetResolutionLabel(Localization, Settings.resolution)
end

local function GetCycleStateLabel(setting)
	if setting == "language" then
		local current = Settings.language or Localization:GetCurrentLanguage()
		return Localization:GetLanguageName(current)
	elseif setting == "DisplayMode" then
		return GetDisplayModeLabel()
	elseif setting == "resolution" then
		return GetResolutionLabel()
	end
end

local function CycleLanguage(delta)
	local languages = Localization:GetAvailableLanguages()
	if #languages == 0 then
		return Settings.language or Localization:GetCurrentLanguage()
	end

	local current = Settings.language or Localization:GetCurrentLanguage()
	local index = 1
	for i, code in ipairs(languages) do
		if code == current then
			index = i
			break
		end
	end

	local count = #languages
	local step = delta or 1
	local NewIndex = ((index - 1 + step) % count) + 1
	return languages[NewIndex]
end

local function RefreshLayout(self)
	local PrevButton = FocusedIndex and buttons[FocusedIndex]
	local PrevId = PrevButton and PrevButton.id
	local PrevScroll = ScrollOffset
	local PrevFocusSource = FocusSource
	local PrevLastNonMouse = LastNonMouseFocusIndex
	Screen:update(0, true)
	self:enter()
	LastNonMouseFocusIndex = PrevLastNonMouse
	if LastNonMouseFocusIndex and (LastNonMouseFocusIndex < 1 or LastNonMouseFocusIndex > #buttons) then
		LastNonMouseFocusIndex = nil
	end
	self:SetScroll(PrevScroll)
	if PrevId then
		for index, btn in ipairs(buttons) do
			if btn.id == PrevId and btn.focusable ~= false then
				if PrevFocusSource == "mouse" then
					self:SetFocus(index, nil, "mouse", true)
				else
					self:SetFocus(index)
				end
				return
			end
		end
	end
end

local function ClampScroll(offset)
	if offset < MinScrollOffset then
		return MinScrollOffset
	elseif offset > 0 then
		return 0
	end

	return offset
end

function SettingsScreen:UpdateButtonPositions()
	local offset = ScrollOffset
	for _, btn in ipairs(buttons) do
		local BaseY = btn.baseY or btn.y or 0
		btn.y = BaseY + offset
		if btn.sliderTrack and btn.sliderTrack.baseY then
			btn.sliderTrack.y = btn.sliderTrack.baseY + offset
		end
	end
end

function SettingsScreen:UpdateScrollBounds()
	local panel = layout.panel
	local PanelPadding = UI.spacing.PanelPadding
	ViewportHeight = math.max(0, (panel and panel.h or 0) - PanelPadding * 2)
	MinScrollOffset = math.min(0, ViewportHeight - ContentHeight)
	ScrollOffset = ClampScroll(ScrollOffset)
	self:UpdateButtonPositions()
end

function SettingsScreen:SetScroll(offset)
	local NewOffset = ClampScroll(offset)
	if math.abs(NewOffset - ScrollOffset) > 1e-4 then
		ScrollOffset = NewOffset
		self:UpdateButtonPositions()
	end
end

function SettingsScreen:ScrollBy(amount)
	if not amount or amount == 0 then return end
	self:SetScroll(ScrollOffset + amount)
end

function SettingsScreen:IsOptionVisible(btn)
	local panel = layout.panel
	if not panel then
		return true
	end

	if ViewportHeight <= 0 then
		return true
	end

	local PanelPadding = UI.spacing.PanelPadding
	local ViewportTop = panel.y + PanelPadding
	local ViewportBottom = ViewportTop + ViewportHeight

	local top = btn.y or 0
	local bottom = top + (btn.h or 0)
	if btn.option and btn.option.type == "slider" and btn.sliderTrack then
		local TrackTop = btn.sliderTrack.y or top
		local TrackBottom = TrackTop + (btn.sliderTrack.h or 0)
		if btn.sliderTrack.handleRadius then
			TrackTop = TrackTop - btn.sliderTrack.handleRadius
			TrackBottom = TrackBottom + btn.sliderTrack.handleRadius
		end
		top = math.min(top, TrackTop)
		bottom = math.max(bottom, TrackBottom)
	end

	return bottom > ViewportTop and top < ViewportBottom
end

function SettingsScreen:EnsureFocusVisible()
	if not FocusedIndex then return end
	local panel = layout.panel
	if not panel or ViewportHeight <= 0 then return end

	self:UpdateButtonPositions()

	local btn = buttons[FocusedIndex]
	if not btn then return end

	local PanelPadding = UI.spacing.PanelPadding
	local ViewportTop = panel.y + PanelPadding
	local ViewportBottom = ViewportTop + ViewportHeight

	local top = btn.y
	local bottom = top + btn.h

	if top < ViewportTop then
		self:SetScroll(ScrollOffset + (ViewportTop - top))
	elseif bottom > ViewportBottom then
		self:SetScroll(ScrollOffset - (bottom - ViewportBottom))
	end
end

local function GetBaseColor()
	return (UI.colors and UI.colors.background) or Theme.BgColor
end

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.5

	Shaders.configure(effect, {
		BgColor = GetBaseColor(),
		AccentColor = Theme.BorderColor,
		LineColor = Theme.HighlightColor,
	})

	BackgroundEffect = effect
end

local function DrawBackground(sw, sh)
	local BaseColor = GetBaseColor()
	love.graphics.setColor(BaseColor)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	if not BackgroundEffect then
		ConfigureBackgroundEffect()
	end

	if BackgroundEffect then
		local intensity = BackgroundEffect.backdropIntensity or select(1, Shaders.GetDefaultIntensities(BackgroundEffect))
		Shaders.draw(BackgroundEffect, 0, 0, sw, sh, intensity)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local AnalogAxisActions = {
	horizontal = {
		negative = function(self)
			self:AdjustFocused(-1)
		end,
		positive = function(self)
			self:AdjustFocused(1)
		end,
	},
	vertical = {
		negative = function(self)
			self:MoveFocus(-1)
		end,
		positive = function(self)
			self:MoveFocus(1)
		end,
	},
}

local AnalogAxisMap = {
	leftx = { slot = "horizontal" },
	rightx = { slot = "horizontal" },
	lefty = { slot = "vertical" },
	righty = { slot = "vertical" },
	[1] = { slot = "horizontal" },
	[2] = { slot = "vertical" },
}

local function ResetAnalogAxis()
	AnalogAxisDirections.horizontal = nil
	AnalogAxisDirections.vertical = nil
end

local function HandleAnalogAxis(self, axis, value)
	local mapping = AnalogAxisMap[axis]
	if not mapping then
		return
	end

	local direction
	if value >= ANALOG_DEADZONE then
		direction = "positive"
	elseif value <= -ANALOG_DEADZONE then
		direction = "negative"
	end

	if AnalogAxisDirections[mapping.slot] == direction then
		return
	end

	AnalogAxisDirections[mapping.slot] = direction

	if direction then
		local actions = AnalogAxisActions[mapping.slot]
		local action = actions and actions[direction]
		if action then
			action(self)
		end
	end
end

function SettingsScreen:enter()
	Screen:update()
	ConfigureBackgroundEffect()
	local sw, sh = Screen:get()
	local CenterX = sw / 2

	ResetAnalogAxis()

	local spacing = UI.spacing.ButtonSpacing
	local HeaderHeight = UI.spacing.SectionHeaderHeight
	local HeaderSpacing = UI.spacing.SectionHeaderSpacing
	local TitleFont = UI.fonts.title
	local TitleHeight = (TitleFont and TitleFont:getHeight()) or 0
	local TotalHeight = 0
	for index, opt in ipairs(options) do
		local height
		local SpacingAfter = spacing

		if opt.type == "slider" then
			height = UI.spacing.SliderHeight
		elseif opt.type == "header" then
			height = HeaderHeight
			SpacingAfter = HeaderSpacing
		else
			height = UI.spacing.ButtonHeight
		end

		TotalHeight = TotalHeight + height
		if index < #options then
			TotalHeight = TotalHeight + SpacingAfter
		end
	end

	local PanelPadding = UI.spacing.PanelPadding
	local BaseSelectionWidth = UI.spacing.ButtonWidth
	local AvailableWidth = sw - UI.spacing.SectionSpacing * 2 - PanelPadding * 2
	local SelectionWidth = BaseSelectionWidth

	if AvailableWidth > BaseSelectionWidth then
		SelectionWidth = math.min(BaseSelectionWidth * 1.35, AvailableWidth)
	elseif AvailableWidth > 0 then
		SelectionWidth = AvailableWidth
	end

	local PanelWidth = SelectionWidth + PanelPadding * 2
	local PanelHeight = TotalHeight + PanelPadding * 2
	local MinPanelHeight = PanelPadding * 2 + UI.spacing.ButtonHeight
	local DesiredTopMargin = UI.spacing.SectionSpacing + TitleHeight + UI.spacing.SectionSpacing
	local DesiredBottomMargin = UI.spacing.SectionSpacing + UI.spacing.ButtonHeight + UI.spacing.SectionSpacing
	local DesiredMaxPanelHeight = sh - DesiredTopMargin - DesiredBottomMargin
	local GeneralMaxPanelHeight = sh - UI.spacing.SectionSpacing * 2

	local SafeDesiredMax = math.max(0, DesiredMaxPanelHeight)
	local SafeGeneralMax = math.max(0, GeneralMaxPanelHeight)
	local MaxPanelHeight = math.min(PanelHeight, SafeDesiredMax, SafeGeneralMax)
	if MaxPanelHeight < MinPanelHeight then
		if SafeGeneralMax >= MinPanelHeight then
			MaxPanelHeight = MinPanelHeight
		elseif SafeGeneralMax > 0 then
			MaxPanelHeight = SafeGeneralMax
		else
			MaxPanelHeight = MinPanelHeight
		end
	end

	PanelHeight = MaxPanelHeight

	local PanelX = CenterX - PanelWidth / 2

	local MinPanelY = DesiredTopMargin
	local MaxPanelY = sh - DesiredBottomMargin - PanelHeight
	local PanelY
	if MaxPanelY >= MinPanelY then
		PanelY = MinPanelY + (MaxPanelY - MinPanelY) * 0.5
	else
		local CenteredY = sh / 2 - PanelHeight / 2
		local MinAllowedY = UI.spacing.SectionSpacing
		local MaxAllowedY = sh - PanelHeight - UI.spacing.SectionSpacing
		if MaxAllowedY < MinAllowedY then
			MaxAllowedY = MinAllowedY
		end
		if CenteredY < MinAllowedY then
			PanelY = MinAllowedY
		elseif CenteredY > MaxAllowedY then
			PanelY = MaxAllowedY
		else
			PanelY = CenteredY
		end
	end

	layout.panel = { x = PanelX, y = PanelY, w = PanelWidth, h = PanelHeight }
	layout.title = {
		height = TitleHeight,
		y = math.max(UI.spacing.SectionSpacing, PanelY - UI.spacing.SectionSpacing - TitleHeight * 0.25),
	}
	layout.margins = {
		top = PanelY,
		bottom = sh - (PanelY + PanelHeight),
	}
	ContentHeight = TotalHeight

	local StartY = PanelY + PanelPadding

	-- reset UI.buttons so we don’t keep stale hitboxes
	UI.ClearButtons()
	buttons = {}
	ScrollOffset = 0
	MinScrollOffset = 0
	FocusSource = nil
	LastNonMouseFocusIndex = nil

	for i, opt in ipairs(options) do
		local x = PanelX + PanelPadding
		local y = StartY
		local w = SelectionWidth
		local SpacingAfter = spacing
		local h

		if opt.type == "slider" then
			h = UI.spacing.SliderHeight
		elseif opt.type == "header" then
			h = HeaderHeight
			SpacingAfter = HeaderSpacing
		else
			h = UI.spacing.ButtonHeight
		end

		local id = "SettingsOption" .. i

		table.insert(buttons, {
			id = id,
			x = x,
			y = y,
			w = w,
			h = h,
			option = opt,
			hovered = false,
			SliderTrack = nil,
			BaseY = y,
			focusable = opt.type ~= "header",
		})

		local entry = buttons[#buttons]

		if opt.type == "slider" then
			local TrackHeight = UI.spacing.SliderTrackHeight
			local padding = UI.spacing.SliderPadding
			entry.sliderTrack = {
				x = x + padding,
				y = y + h - padding - TrackHeight,
				w = w - padding * 2,
				h = TrackHeight,
				HandleRadius = UI.spacing.SliderHandleRadius,
				BaseY = y + h - padding - TrackHeight,
			}
		end

		-- register for clickable items (skip sliders and static headers)
		if opt.type ~= "slider" and opt.type ~= "header" then
			UI.RegisterButton(id, x, y, w, h, Localization:get(opt.labelKey))
		end

		StartY = StartY + h
		if i < #options then
			StartY = StartY + SpacingAfter
		end
	end

	ContentHeight = TotalHeight
	self:UpdateScrollBounds()

	if #buttons == 0 then
		self:ClearFocus()
	else
		local InitialIndex = FocusedIndex
		if not InitialIndex or not buttons[InitialIndex] then
			InitialIndex = FindFirstFocusableIndex()
		end
		self:SetFocus(InitialIndex, nil, nil, true)
	end

	self:UpdateFocusVisuals()
end

function SettingsScreen:leave()
	SliderDragging = nil
end

function SettingsScreen:update(dt)
	local mx, my = love.mouse.getPosition()
	HoveredIndex = nil

	self:UpdateButtonPositions()

	for i, btn in ipairs(buttons) do
		local opt = btn.option
		local visible = self:IsOptionVisible(btn)
		local hovered = false
		local CanHover = btn.focusable ~= false
		if visible and CanHover then
			hovered = UI.IsHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
		end

		btn.hovered = hovered
		if hovered and CanHover then
			HoveredIndex = i
		end

		if SliderDragging and opt.slider == SliderDragging then
			local track = btn.sliderTrack
			local rel
			if track then
				rel = (mx - track.x) / track.w
			else
				rel = (mx - btn.x) / btn.w
			end
			Settings[SliderDragging] = math.min(1, math.max(0, rel))
			Settings:save()
			if opt.onChanged then
				opt.onChanged(Settings, opt)
			end
		end
	end

	if HoveredIndex then
		self:SetFocus(HoveredIndex, nil, "mouse", true)
	else
		if FocusSource == "mouse" then
			if LastNonMouseFocusIndex and buttons[LastNonMouseFocusIndex] and IsButtonFocusable(buttons[LastNonMouseFocusIndex]) then
				self:SetFocus(LastNonMouseFocusIndex)
			else
				self:ClearFocus()
			end
		else
			self:UpdateFocusVisuals()
		end
	end
end

function SettingsScreen:draw()
	local sw, sh = Screen:get()
	DrawBackground(sw, sh)

	local panel = layout.panel
	UI.DrawPanel(panel.x, panel.y, panel.w, panel.h)

	local TitleText = Localization:get("settings.title")
	local TitleLayout = layout.title or {}
	local TitleY = TitleLayout.y or math.max(UI.spacing.SectionSpacing, panel.y - UI.spacing.SectionSpacing - (TitleLayout.height or 0) * 0.25)
	UI.DrawLabel(TitleText, 0, TitleY, sw, "center", { FontKey = "title" })

	self:UpdateButtonPositions()

	local PanelPadding = UI.spacing.PanelPadding
	local ViewportX = panel.x + PanelPadding
	local ViewportY = panel.y + PanelPadding
	local ViewportW = panel.w - PanelPadding * 2
	local ViewportH = math.max(0, ViewportHeight)

	local PrevScissorX, PrevScissorY, PrevScissorW, PrevScissorH = love.graphics.getScissor()
	local AppliedScissor = false
	if ViewportW > 0 and ViewportH > 0 then
		love.graphics.setScissor(ViewportX, ViewportY, ViewportW, ViewportH)
		AppliedScissor = true
	end

	for index, btn in ipairs(buttons) do
		local opt = btn.option
		local label = Localization:get(opt.labelKey)
		local IsFocused = (FocusedIndex == index)
		local visible = self:IsOptionVisible(btn)

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
				UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.SetButtonFocus(btn.id, IsFocused)
				UI.DrawButton(btn.id)
			end

		elseif opt.type == "slider" and opt.slider then
			local value = math.min(1, math.max(0, Settings[opt.slider] or 0))
			if visible then
				local TrackX, TrackY, TrackW, TrackH, HandleRadius = UI.DrawSlider(nil, btn.x, btn.y, btn.w, value, {
					label = label,
					focused = IsFocused,
					hovered = btn.hovered,
					register = false,
				})

				btn.sliderTrack = btn.sliderTrack or {}
				btn.sliderTrack.x = TrackX
				btn.sliderTrack.y = TrackY
				btn.sliderTrack.w = TrackW
				btn.sliderTrack.h = TrackH
				btn.sliderTrack.handleRadius = HandleRadius
				btn.sliderTrack.baseY = TrackY - ScrollOffset
			else
				local track = btn.sliderTrack
				if track and track.baseY then
					track.y = track.baseY + ScrollOffset
				end
			end

		elseif opt.type == "header" then
			if visible then
				local font = UI.fonts.heading
				local FontHeight = font and font:getHeight() or 0
				local TextY = btn.y + math.max(0, (btn.h - FontHeight) * 0.5)
				UI.DrawLabel(label, btn.x, TextY, btn.w, "left", {
					font = font,
					color = UI.colors.SubtleText,
				})

				if FontHeight > 0 then
					local LineY = math.min(btn.y + btn.h - 3, TextY + FontHeight + 4)
					local LineColor = UI.colors.highlight or {1, 1, 1, 0.4}
					love.graphics.setColor(LineColor[1] or 1, LineColor[2] or 1, LineColor[3] or 1, (LineColor[4] or 1) * 0.45)
					love.graphics.rectangle("fill", btn.x, LineY, btn.w, 2)
					love.graphics.setColor(1, 1, 1, 1)
				end
			end

		elseif opt.type == "cycle" and opt.setting then
			local state = GetCycleStateLabel(opt.setting)
			if state then
				label = string.format("%s: %s", label, state)
			end
			if visible then
				UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.SetButtonFocus(btn.id, IsFocused)
				UI.DrawButton(btn.id)
			end

		else
			if visible then
				UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
				UI.SetButtonFocus(btn.id, IsFocused)
				UI.DrawButton(btn.id)
			end
		end
	end

	if AppliedScissor then
		if PrevScissorX then
			love.graphics.setScissor(PrevScissorX, PrevScissorY, PrevScissorW, PrevScissorH)
		else
			love.graphics.setScissor()
		end
	end

	if ContentHeight > ViewportHeight and ViewportHeight > 0 then
		local TrackWidth = 6
		local TrackRadius = TrackWidth / 2
		local TrackX = panel.x + panel.w - TrackWidth - PanelPadding * 0.5
		local TrackY = ViewportY
		local TrackHeight = ViewportHeight

		local ScrollRange = ContentHeight - ViewportHeight
		local ScrollProgress = ScrollRange > 0 and (-ScrollOffset / ScrollRange) or 0
		ScrollProgress = math.max(0, math.min(1, ScrollProgress))

		local MinThumbHeight = 32
		local ThumbHeight = math.max(MinThumbHeight, TrackHeight * (ViewportHeight / ContentHeight))
		ThumbHeight = math.min(ThumbHeight, TrackHeight)
		local ThumbY = TrackY + (TrackHeight - ThumbHeight) * ScrollProgress

		local TrackColor = Theme.PanelBorder or UI.colors.PanelBorder or {1, 1, 1, 0.4}
		local ThumbColor = Theme.HighlightColor or UI.colors.highlight or {1, 1, 1, 0.8}

		love.graphics.setColor(TrackColor[1] or 1, TrackColor[2] or 1, TrackColor[3] or 1, (TrackColor[4] or 1) * 0.4)
		love.graphics.rectangle("fill", TrackX, TrackY, TrackWidth, TrackHeight, TrackRadius)

		local ThumbAlpha = math.min(1, (ThumbColor[4] or 1) * 1.2)
		love.graphics.setColor(ThumbColor[1] or 1, ThumbColor[2] or 1, ThumbColor[3] or 1, ThumbAlpha)
		love.graphics.rectangle("fill", TrackX, ThumbY, TrackWidth, ThumbHeight, TrackRadius)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function SettingsScreen:UpdateFocusVisuals()
	for index, btn in ipairs(buttons) do
		local focused = (FocusedIndex == index)
		btn.focused = focused
		if btn.focusable ~= false and (not btn.option or btn.option.type ~= "slider") then
			UI.SetButtonFocus(btn.id, focused)
		elseif btn.id and btn.option and btn.option.type ~= "slider" then
			UI.SetButtonFocus(btn.id, false)
		end
	end
end

function SettingsScreen:FindNextFocusable(StartIndex, delta)
	if #buttons == 0 then return nil end

	local count = #buttons
	local step = delta or 1
	if step == 0 then
		return StartIndex
	end

	local index = StartIndex or 0
	for _ = 1, count do
		index = index + step
		if index < 1 then
			index = count
		elseif index > count then
			index = 1
		end

		local btn = buttons[index]
		if IsButtonFocusable(btn) then
			return index
		end
	end

	return nil
end

function SettingsScreen:ClearFocus()
	FocusedIndex = nil
	FocusSource = nil
	LastNonMouseFocusIndex = nil
	self:UpdateFocusVisuals()
end

function SettingsScreen:SetFocus(index, direction, source, SkipNonMouseHistory)
	if #buttons == 0 then
		self:ClearFocus()
		return
	end

	local count = #buttons
	if not index then
		index = FindFirstFocusableIndex()
		if not index then
			self:ClearFocus()
			return
		end
	else
		index = math.max(1, math.min(index, count))
	end

	if not IsButtonFocusable(buttons[index]) then
		local SearchDir = direction
		if not SearchDir then
			if FocusedIndex and index < FocusedIndex then
				SearchDir = -1
			else
				SearchDir = 1
			end
		end

		local NextIndex = self:FindNextFocusable(index, SearchDir)
		if not NextIndex then
			NextIndex = self:FindNextFocusable(index, -(SearchDir or 1))
		end

		if not NextIndex then
			self:ClearFocus()
			return
		end

		index = NextIndex
	end

	FocusedIndex = index
	FocusSource = source or "programmatic"
	if FocusSource ~= "mouse" and not SkipNonMouseHistory then
		LastNonMouseFocusIndex = index
	end
	self:EnsureFocusVisible()
	self:UpdateFocusVisuals()
end

function SettingsScreen:MoveFocus(delta)
	if #buttons == 0 then return end

	if not FocusedIndex then
		local first = FindFirstFocusableIndex()
		if first then
			self:SetFocus(first)
		end
		return
	end

	local NextIndex = self:FindNextFocusable(FocusedIndex, delta)
	if NextIndex then
		self:SetFocus(NextIndex, delta)
	end
end

function SettingsScreen:GetFocusedOption()
	if not FocusedIndex then return nil end
	return buttons[FocusedIndex]
end

function SettingsScreen:CycleSetting(setting, delta)
	delta = delta or 1

	if setting == "language" then
		local NextLang = CycleLanguage(delta)
		Settings.language = NextLang
		Settings:save()
		Localization:SetLanguage(NextLang)
		Audio:PlaySound("click")
		RefreshLayout(self)
	elseif setting == "DisplayMode" then
		local NextMode = Display.CycleDisplayMode(Settings.DisplayMode, delta)
		if NextMode ~= Settings.DisplayMode then
			Settings.DisplayMode = NextMode
			Settings:save()
			Display.apply(Settings)
			Audio:PlaySound("click")
			RefreshLayout(self)
		end
	elseif setting == "resolution" then
		local NextResolution = Display.CycleResolution(Settings.resolution, delta)
		if NextResolution ~= Settings.resolution then
			Settings.resolution = NextResolution
			Settings:save()
			if Settings.DisplayMode == "windowed" then
				Display.apply(Settings)
			end
			Audio:PlaySound("click")
			RefreshLayout(self)
		end
	end
end

function SettingsScreen:AdjustFocused(delta)
	local btn = self:GetFocusedOption()
	if not btn or delta == 0 then return end

	local opt = btn.option
	if opt.type == "slider" and opt.slider then
		local step = 0.05 * delta
		local value = Settings[opt.slider] or 0
		local NewValue = math.min(1, math.max(0, value + step))
		if math.abs(NewValue - value) > 1e-4 then
			Settings[opt.slider] = NewValue
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
			Audio:PlaySound("click")
		end
	elseif opt.type == "cycle" and opt.setting then
		self:CycleSetting(opt.setting, delta)
	end
end

function SettingsScreen:ActivateFocused()
	local btn = self:GetFocusedOption()
	if not btn then return nil end

	local opt = btn.option
	if opt.type == "toggle" and opt.toggle then
		Settings[opt.toggle] = not Settings[opt.toggle]
		Settings:save()
		if opt.onChanged then
			opt.onChanged(Settings, opt)
		end
		Audio:PlaySound("click")
		return nil
	elseif opt.type == "action" then
		Audio:PlaySound("click")
		if type(opt.action) == "function" then
			opt.action()
			return nil
		else
			return opt.action
		end
	elseif opt.type == "cycle" and opt.setting then
		self:CycleSetting(opt.setting, 1)
	end

	return nil
end

function SettingsScreen:mousepressed(x, y, button)
	self:UpdateButtonPositions()
	local id = UI:mousepressed(x, y, button)

	for i, btn in ipairs(buttons) do
		local opt = btn.option
		local visible = self:IsOptionVisible(btn)
		local CanHover = btn.focusable ~= false

		if not visible then
			goto continue
		end

		if CanHover and btn.id and btn.id == id then
			self:SetFocus(i, nil, "mouse", true)

			if opt.type == "cycle" and opt.setting then
				self:CycleSetting(opt.setting, 1)
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
			local HoveredSlider
			if track then
				HoveredSlider = x >= track.x and x <= track.x + track.w and
									y >= track.y - (track.h * 0.75) and y <= track.y + track.h * 1.75
			else
				HoveredSlider = x >= btn.x and x <= btn.x + btn.w and
									y >= btn.y and y <= btn.y + btn.h
			end
			if HoveredSlider then
				SliderDragging = opt.slider
				local rel
				if track then
					rel = (x - track.x) / track.w
				else
					rel = (x - btn.x) / btn.w
				end
				Settings[SliderDragging] = math.min(1, math.max(0, rel))
				Settings:save()
				if opt.onChanged then
					opt.onChanged(Settings, opt)
				end
				self:SetFocus(i, nil, "mouse", true)
			end
		end

		::continue::
	end
end

function SettingsScreen:mousereleased(x, y, button)
	UI:mousereleased(x, y, button)
	SliderDragging = nil
end

function SettingsScreen:keypressed(key)
	if key == "up" then
		self:MoveFocus(-1)
	elseif key == "down" then
		self:MoveFocus(1)
	elseif key == "left" then
		self:AdjustFocused(-1)
	elseif key == "right" then
		self:AdjustFocused(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return self:ActivateFocused()
	elseif key == "escape" or key == "backspace" then
		return "menu"
	end
end

function SettingsScreen:gamepadpressed(_, button)
	if button == "dpup" then
		self:MoveFocus(-1)
	elseif button == "dpdown" then
		self:MoveFocus(1)
	elseif button == "dpleft" then
		self:AdjustFocused(-1)
	elseif button == "dpright" then
		self:AdjustFocused(1)
	elseif button == "a" or button == "start" then
		return self:ActivateFocused()
	elseif button == "b" then
		return "menu"
	end
end

SettingsScreen.joystickpressed = SettingsScreen.gamepadpressed

function SettingsScreen:gamepadaxis(_, axis, value)
	HandleAnalogAxis(self, axis, value)
end

SettingsScreen.joystickaxis = SettingsScreen.gamepadaxis

function SettingsScreen:wheelmoved(_, dy)
	if dy == 0 then
		return
	end

	self:ScrollBy(dy * SCROLL_SPEED)
end

return SettingsScreen
