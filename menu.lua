local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local DrawWord = require("drawword")
local Face = require("face")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")
local PlayerStats = require("playerstats")
local SawActor = require("sawactor")

local Menu = {
	TransitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local ButtonList = ButtonList.new()
local buttons = {}
local t = 0
local DailyChallenge = nil
local DailyChallengeAnim = 0
local AnalogAxisDirections = { horizontal = nil, vertical = nil }
local TitleSaw = SawActor.new()

local BACKGROUND_EFFECT_TYPE = "MenuConstellation"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.58

	Shaders.configure(effect, {
		BgColor = Theme.BgColor,
		AccentColor = Theme.ButtonHover,
		HighlightColor = Theme.AccentTextColor,
	})

	BackgroundEffect = effect
end

local function DrawBackground(sw, sh)
	love.graphics.setColor(Theme.BgColor)
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

local function GetDayUnit(count)
	if count == 1 then
		return Localization:get("common.day_unit_singular")
	end

	return Localization:get("common.day_unit_plural")
end

local AnalogAxisActions = {
	horizontal = {
		negative = function()
			ButtonList:moveFocus(-1)
		end,
		positive = function()
			ButtonList:moveFocus(1)
		end,
	},
	vertical = {
		negative = function()
			ButtonList:moveFocus(-1)
		end,
		positive = function()
			ButtonList:moveFocus(1)
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

local function PrepareStartAction(action)
	if type(action) ~= "string" then
		return action
	end

	if action ~= "game" then
		return action
	end

	local deepest = PlayerStats:get("DeepestFloorReached") or 0
	if deepest <= 1 then
		return action
	end

	return {
		state = "floorselect",
		data = {
			HighestFloor = deepest,
			DefaultFloor = deepest,
		},
	}
end

local function HandleAnalogAxis(axis, value)
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
			action()
		end
	end
end

local function SetColorWithAlpha(color, alpha)
	local r, g, b, a = 1, 1, 1, alpha or 1
	if color then
		r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
		a = (color[4] or 1) * (alpha or 1)
	end
	love.graphics.setColor(r, g, b, a)
end

function Menu:enter()
	t = 0
	UI.ClearButtons()

	Audio:PlayMusic("menu")
	Screen:update()

	DailyChallenge = DailyChallenges:GetDailyChallenge()
	DailyChallengeAnim = 0
	ResetAnalogAxis()

	ConfigureBackgroundEffect()

	local sw, sh = Screen:get()
	local CenterX = sw / 2

	local labels = {
		{ key = "menu.start_game",   action = "game" },
		{ key = "menu.achievements", action = "achievementsmenu" },
		{ key = "menu.progression",  action = "metaprogression" },
		{ key = "menu.dev_page",     action = "dev" },
		{ key = "menu.settings",     action = "settings" },
		{ key = "menu.quit",         action = "quit" },
	}

	local TotalButtonHeight = #labels * UI.spacing.ButtonHeight + math.max(0, #labels - 1) * UI.spacing.ButtonSpacing
	-- Shift the buttons down a bit so the title has breathing room.
	local StartY = sh / 2 - TotalButtonHeight / 2 + sh * 0.08

	local defs = {}

	for i, entry in ipairs(labels) do
		local x = CenterX - UI.spacing.ButtonWidth / 2
		local y = StartY + (i - 1) * (UI.spacing.ButtonHeight + UI.spacing.ButtonSpacing)

		defs[#defs + 1] = {
			id = "MenuButton" .. i,
			x = x,
			y = y,
			w = UI.spacing.ButtonWidth,
			h = UI.spacing.ButtonHeight,
			LabelKey = entry.key,
			text = Localization:get(entry.key),
			action = entry.action,
			hovered = false,
			scale = 1,
			alpha = 0,
			OffsetY = 50,
		}
	end

	buttons = ButtonList:reset(defs)
end

function Menu:update(dt)
	t = t + dt

	local mx, my = love.mouse.getPosition()
	ButtonList:updateHover(mx, my)

	if DailyChallenge then
		DailyChallengeAnim = math.min(DailyChallengeAnim + dt * 2, 1)
	end

	for i, btn in ipairs(buttons) do
		if btn.hovered then
			btn.scale = math.min((btn.scale or 1) + dt * 5, 1.1)
		else
			btn.scale = math.max((btn.scale or 1) - dt * 5, 1.0)
		end

		local AppearDelay = (i - 1) * 0.08
		local AppearTime = math.min((t - AppearDelay) * 3, 1)
		btn.alpha = math.max(0, math.min(AppearTime, 1))
		btn.offsetY = (1 - btn.alpha) * 50
	end

	if TitleSaw then
		TitleSaw:update(dt)
	end

	Face:update(dt)
end

function Menu:draw()
	local sw, sh = Screen:get()

	DrawBackground(sw, sh)

	local BaseCellSize = 20
	local BaseSpacing = 10
	local WordScale = 1.5

	local CellSize = BaseCellSize * WordScale
	local word = Localization:get("menu.title_word")
	local spacing = BaseSpacing * WordScale
	local WordWidth = (#word * (3 * CellSize + spacing)) - spacing - (CellSize * 3)
	local ox = (sw - WordWidth) / 2
	local oy = sh * 0.2

	if TitleSaw then
		local SawRadius = TitleSaw.radius or 1
		local WordHeight = CellSize * 3
		local SawScale = WordHeight / (2 * SawRadius)
		if SawScale <= 0 then
			SawScale = 1
		end

		local DesiredTrackLengthWorld = WordWidth + CellSize
		local ShortenedTrackLengthWorld = math.max(2 * SawRadius * SawScale, DesiredTrackLengthWorld - 90)
		local TargetTrackLengthBase = ShortenedTrackLengthWorld / SawScale
		if not TitleSaw.trackLength or math.abs(TitleSaw.trackLength - TargetTrackLengthBase) > 0.001 then
			TitleSaw.trackLength = TargetTrackLengthBase
		end

		local TrackLengthWorld = (TitleSaw.trackLength or TargetTrackLengthBase) * SawScale
		local SlotThicknessBase = TitleSaw.getSlotThickness and TitleSaw:getSlotThickness() or 10
		local SlotThicknessWorld = SlotThicknessBase * SawScale

		local TargetLeft = ox - 15
		local TargetBottom = oy - 30

		local SawX = TargetLeft + TrackLengthWorld / 2
		local SawY = TargetBottom - SlotThicknessWorld / 2

		TitleSaw:draw(SawX, SawY, SawScale)
	end

	local trail = DrawWord.draw(word, ox, oy, CellSize, spacing)

	if trail and #trail > 0 then
		local head = trail[#trail]
		Face:draw(head.x, head.y, WordScale)
	end

	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey)
		end

		if btn.alpha > 0 then
			UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)

			love.graphics.push()
			love.graphics.translate(btn.x + btn.w / 2, btn.y + btn.h / 2 + btn.offsetY)
			love.graphics.scale(btn.scale)
			love.graphics.translate(-(btn.x + btn.w / 2), -(btn.y + btn.h / 2))

			UI.DrawButton(btn.id)

			love.graphics.pop()
		end
	end

	love.graphics.setFont(UI.fonts.small)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.print(Localization:get("menu.version"), 10, sh - 24)

	if DailyChallenge and DailyChallengeAnim > 0 then
		local alpha = math.min(1, DailyChallengeAnim)
		local eased = alpha * alpha
		local PanelWidth = math.min(420, sw - 72)
		local padding = UI.spacing.PanelPadding or 16
		local PanelX = sw - PanelWidth - 36
		local HeaderFont = UI.fonts.small
		local TitleFont = UI.fonts.button
		local BodyFont = UI.fonts.body
		local ProgressFont = UI.fonts.small

		local HeaderText = Localization:get("menu.daily_panel_header")
		local TitleText = Localization:get(DailyChallenge.titleKey, DailyChallenge.descriptionReplacements)
		local DescriptionText = Localization:get(DailyChallenge.descriptionKey, DailyChallenge.descriptionReplacements)

		local _, DescLines = BodyFont:getWrap(DescriptionText, PanelWidth - padding * 2)
		local DescHeight = #DescLines * BodyFont:getHeight()

		local StatusBar = DailyChallenge.statusBar
		local ratio = 0
		local ProgressText = nil
		local StatusBarHeight = 0
		local BonusText = nil
		local StreakLines = {}

		if StatusBar then
			ratio = math.max(0, math.min(StatusBar.ratio or 0, 1))
			if StatusBar.textKey then
				ProgressText = Localization:get(StatusBar.textKey, StatusBar.replacements)
			end
			StatusBarHeight = 10 + 14
			if ProgressText then
				StatusBarHeight = StatusBarHeight + ProgressFont:getHeight() + 6
			end
		end

		if DailyChallenge.xpReward and DailyChallenge.xpReward > 0 then
			BonusText = Localization:get("menu.daily_panel_bonus", { xp = DailyChallenge.xpReward })
		end

		local CurrentStreak = math.max(0, PlayerStats:get("DailyChallengeStreak") or 0)
		local BestStreak = math.max(CurrentStreak, PlayerStats:get("DailyChallengeBestStreak") or 0)

		if CurrentStreak > 0 then
			StreakLines[#StreakLines + 1] = Localization:get("menu.daily_panel_streak", {
				streak = CurrentStreak,
				unit = GetDayUnit(CurrentStreak),
			})

			StreakLines[#StreakLines + 1] = Localization:get("menu.daily_panel_best", {
				best = BestStreak,
				unit = GetDayUnit(BestStreak),
			})

			local MessageKey = DailyChallenge.completed and "menu.daily_panel_complete_message" or "menu.daily_panel_keep_alive"
			StreakLines[#StreakLines + 1] = Localization:get(MessageKey)
		else
			StreakLines[#StreakLines + 1] = Localization:get("menu.daily_panel_start")
		end

		local PanelHeight = padding * 2
			+ HeaderFont:getHeight()
			+ 6
			+ TitleFont:getHeight()
			+ 10
			+ DescHeight
			+ (BonusText and (ProgressFont:getHeight() + 10) or 0)
			+ StatusBarHeight

		if #StreakLines > 0 then
			PanelHeight = PanelHeight + 8
			for i = 1, #StreakLines do
				PanelHeight = PanelHeight + ProgressFont:getHeight()
				if i < #StreakLines then
					PanelHeight = PanelHeight + 4
				end
			end
		end

		local PanelY = math.max(36, sh - PanelHeight - 36)

		SetColorWithAlpha(Theme.ShadowColor, eased * 0.7)
		love.graphics.rectangle("fill", PanelX + 6, PanelY + 8, PanelWidth, PanelHeight, 14, 14)

		SetColorWithAlpha(Theme.PanelColor, alpha)
		UI.DrawRoundedRect(PanelX, PanelY, PanelWidth, PanelHeight, 14)

		SetColorWithAlpha(Theme.PanelBorder, alpha)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", PanelX, PanelY, PanelWidth, PanelHeight, 14, 14)

		local TextX = PanelX + padding
		local TextY = PanelY + padding

		love.graphics.setFont(HeaderFont)
		SetColorWithAlpha(Theme.ShadowColor, alpha)
		love.graphics.print(HeaderText, TextX + 2, TextY + 2)
		SetColorWithAlpha(Theme.TextColor, alpha)
		love.graphics.print(HeaderText, TextX, TextY)

		TextY = TextY + HeaderFont:getHeight() + 6

		love.graphics.setFont(TitleFont)
		love.graphics.print(TitleText, TextX, TextY)

		TextY = TextY + TitleFont:getHeight() + 10

		love.graphics.setFont(BodyFont)
		love.graphics.printf(DescriptionText, TextX, TextY, PanelWidth - padding * 2)

		TextY = TextY + DescHeight

		if BonusText then
			TextY = TextY + 8
			love.graphics.setFont(ProgressFont)
			love.graphics.print(BonusText, TextX, TextY)
			TextY = TextY + ProgressFont:getHeight()
		end

		if #StreakLines > 0 then
			TextY = TextY + 8
			love.graphics.setFont(ProgressFont)
			for i, line in ipairs(StreakLines) do
				if i == #StreakLines and not DailyChallenge.completed then
					SetColorWithAlpha(Theme.WarningColor or Theme.AccentTextColor, alpha)
				else
					SetColorWithAlpha(Theme.TextColor, alpha)
				end
				love.graphics.print(line, TextX, TextY)
				TextY = TextY + ProgressFont:getHeight()
				if i < #StreakLines then
					TextY = TextY + 4
				end
			end
			SetColorWithAlpha(Theme.TextColor, alpha)
		end

		if StatusBar then
			TextY = TextY + 10
			love.graphics.setFont(ProgressFont)

			if ProgressText then
				love.graphics.print(ProgressText, TextX, TextY)
				TextY = TextY + ProgressFont:getHeight() + 6
			end

			local BarHeight = 14
			local BarWidth = PanelWidth - padding * 2

			SetColorWithAlpha({0, 0, 0, 0.35}, alpha)
			UI.DrawRoundedRect(TextX, TextY, BarWidth, BarHeight, 8)

			local FillWidth = BarWidth * ratio
			if FillWidth > 0 then
				SetColorWithAlpha(Theme.ProgressColor, alpha)
				UI.DrawRoundedRect(TextX, TextY, FillWidth, BarHeight, 8)
			end

			SetColorWithAlpha(Theme.PanelBorder, alpha)
			love.graphics.setLineWidth(1.5)
			love.graphics.rectangle("line", TextX, TextY, BarWidth, BarHeight, 8, 8)

			TextY = TextY + BarHeight
		end
	end
end

function Menu:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function Menu:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
	if action then
		return PrepareStartAction(action)
	end
end

local function HandleMenuConfirm()
	local action = ButtonList:activateFocused()
	if action then
		Audio:PlaySound("click")
		return PrepareStartAction(action)
	end
end

function Menu:keypressed(key)
	if key == "up" or key == "left" then
		ButtonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		ButtonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return HandleMenuConfirm()
	elseif key == "escape" or key == "backspace" then
		return "quit"
	end
end

function Menu:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return HandleMenuConfirm()
	elseif button == "b" then
		return "quit"
	end
end

Menu.joystickpressed = Menu.gamepadpressed

function Menu:gamepadaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

Menu.joystickaxis = Menu.gamepadaxis

return Menu
