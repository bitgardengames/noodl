local Screen = require("screen")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")

local GameOver = { IsVictory = false }

local unpack = unpack

local ANALOG_DEADZONE = 0.35

local function PickDeathMessage(cause)
	local DeathTable = Localization:GetTable("gameover.deaths") or {}
	local entries = DeathTable[cause] or DeathTable.unknown or {}
	if #entries == 0 then
		return Localization:get("gameover.default_message")
	end

	return entries[love.math.random(#entries)]
end

local FontTitle
local FontScore
local FontSmall
local FontBadge
local FontProgressTitle
local FontProgressValue
local FontProgressSmall
local stats = {}
local ButtonList = ButtonList.new()
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

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

local function GetDayUnit(count)
	if count == 1 then
		return Localization:get("common.day_unit_singular")
	end

	return Localization:get("common.day_unit_plural")
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
-- Layout constants
local function GetButtonMetrics()
	local spacing = UI.spacing or {}
	return spacing.buttonWidth or 260, spacing.buttonHeight or 56, spacing.buttonSpacing or 24
end

local function GetCelebrationEntryHeight()
	return (UI.scaled and UI.scaled(64, 48)) or 64
end

local function GetCelebrationEntrySpacing()
	local gap = (UI.scaled and UI.scaled(10, 6)) or 10
	return GetCelebrationEntryHeight() + gap
end

local function GetStatCardHeight()
	return (UI.scaled and UI.scaled(96, 72)) or 96
end

local function GetStatCardSpacing()
	return (UI.scaled and UI.scaled(18, 12)) or 18
end

local function GetStatCardMinWidth()
	return (UI.scaled and UI.scaled(160, 120)) or 160
end

local function GetSectionPadding()
	return (UI.scaled and UI.scaled(20, 14)) or 20
end

local function GetSectionSpacing()
	return (UI.scaled and UI.scaled(22, 16)) or 22
end

local function GetSectionInnerSpacing()
	return (UI.scaled and UI.scaled(12, 8)) or 12
end

local function GetSectionSmallSpacing()
	return (UI.scaled and UI.scaled(8, 5)) or 8
end

local function GetSectionHeaderSpacing()
	return (UI.scaled and UI.scaled(18, 14)) or 18
end

local function MeasureXpPanelHeight(self, width, CelebrationCount)
	if not self or not self.ProgressionAnimation then
		return 0
	end

	width = math.max(0, width or 0)
	if width <= 0 then
		return 0
	end

	local TitleHeight = FontProgressTitle and FontProgressTitle:getHeight() or 0
	local LevelHeight = FontProgressValue and FontProgressValue:getHeight() or 0
	local SmallHeight = FontProgressSmall and FontProgressSmall:getHeight() or 0

	local height = 18
	height = height + TitleHeight
	height = height + 12 + LevelHeight
	height = height + 6 + SmallHeight
	height = height + 18

	local MaxRadius = math.max(48, math.min(74, (width / 2) - 24))
	local RingThickness = math.max(14, math.min(24, MaxRadius * 0.42))
	local RingRadius = math.max(32, MaxRadius - RingThickness * 0.25)
	local OuterRadius = RingRadius + RingThickness * 0.45

	height = height + RingRadius + OuterRadius
	height = height + 18

	local breakdown = (self.progression and self.progression.breakdown) or {}
	local BonusXP = math.max(0, math.floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
	if BonusXP > 0 then
		height = height + SmallHeight + 6
	end

	if self.DailyStreakMessage then
		height = height + SmallHeight + 6
	end

	height = height + SmallHeight
	height = height + 4
	height = height + SmallHeight
	height = height + 16

	local count = math.max(0, CelebrationCount or 0)
	if count > 0 then
		height = height + count * GetCelebrationEntrySpacing()
	end

	return math.max(160, height)
end

local BACKGROUND_EFFECT_TYPE = "AfterglowPulse"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	if GameOver.IsVictory then
		effect.backdropIntensity = 0.72
	else
		effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.62
	end

	local accent = Theme.WarningColor
	local pulse = Theme.ProgressColor

	if GameOver.IsVictory then
		accent = Theme.ProgressColor
		pulse = Theme.AccentTextColor or Theme.ProgressColor
	end

	Shaders.configure(effect, {
		BgColor = Theme.BgColor,
		AccentColor = accent,
		PulseColor = pulse,
	})

	BackgroundEffect = effect
end

local function EaseOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	local progress = t - 1
	return 1 + c3 * (progress * progress * progress) + c1 * (progress * progress)
end

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

local function EaseOutQuad(t)
	local inv = 1 - t
	return 1 - inv * inv
end

local function CopyColor(color)
	if type(color) ~= "table" then
		return { 1, 1, 1, 1 }
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
	}
end

local function LightenColor(color, factor)
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

local function DarkenColor(color, factor)
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

local function WithAlpha(color, alpha)
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] == nil and 1 or color[4]
	return { r, g, b, a * alpha }
end

local function RandomRange(minimum, maximum)
	return minimum + (maximum - minimum) * love.math.random()
end

local function ApproachExp(current, target, dt, speed)
	if speed <= 0 then
		return target
	end

	local factor = 1 - math.exp(-speed * dt)
	return current + (target - current) * factor
end

local function SpawnFruitAnimation(anim)
	if not anim or not anim.barMetrics then
		return false
	end

	local metrics = anim.barMetrics
	local palette = anim.fruitPalette or { Theme.AppleColor }
	local color = CopyColor(palette[love.math.random(#palette)] or Theme.AppleColor)

	local fruit
	if metrics.style == "radial" then
		local CenterX = metrics.centerX or 0
		local CenterY = metrics.centerY or 0
		local radius = metrics.outerRadius or metrics.radius or 56
		local LaunchOffsetX = RandomRange(-radius * 0.6, radius * 0.6)
		local LaunchLift = math.max(radius * 0.8, 54)
		local LaunchX = CenterX + LaunchOffsetX
		local LaunchY = CenterY - radius - LaunchLift
		local ControlX = (LaunchX + CenterX) / 2 + RandomRange(-radius * 0.25, radius * 0.25)
		local ControlY = math.min(LaunchY, CenterY) - math.max(radius * 0.75, 48)

		fruit = {
			timer = 0,
			duration = RandomRange(0.55, 0.85),
			StartX = LaunchX,
			StartY = LaunchY,
			ControlX = ControlX,
			ControlY = ControlY,
			EndX = CenterX,
			EndY = CenterY,
			ScaleStart = RandomRange(0.42, 0.52),
			ScalePeak = RandomRange(0.68, 0.82),
			ScaleEnd = RandomRange(0.50, 0.64),
			WobbleSeed = love.math.random() * math.pi * 2,
			WobbleSpeed = RandomRange(4.5, 6.5),
			color = color,
			SplashAngle = clamp(anim.visualPercent or 0, 0, 1),
		}
	else
		local LaunchX = metrics.x + metrics.width * 0.5
		local LaunchY = metrics.y - math.max(metrics.height * 2.2, 72)

		local EndX = metrics.x + metrics.width * 0.5
		local EndY = metrics.y + metrics.height * 0.5
		local ApexLift = math.max(metrics.height * 1.35, 64)
		local ControlX = (LaunchX + EndX) / 2
		local ControlY = math.min(LaunchY, EndY) - ApexLift

		fruit = {
			timer = 0,
			duration = RandomRange(0.55, 0.85),
			StartX = LaunchX,
			StartY = LaunchY,
			ControlX = ControlX,
			ControlY = ControlY,
			EndX = EndX,
			EndY = EndY,
			ScaleStart = RandomRange(0.42, 0.52),
			ScalePeak = RandomRange(0.68, 0.82),
			ScaleEnd = RandomRange(0.50, 0.64),
			WobbleSeed = love.math.random() * math.pi * 2,
			WobbleSpeed = RandomRange(4.5, 6.5),
			color = color,
		}
	end

	anim.fruitAnimations = anim.fruitAnimations or {}
	table.insert(anim.fruitAnimations, fruit)
	anim.fruitRemaining = math.max(0, (anim.fruitRemaining or 0) - 1)

	return true
end

local function UpdateFruitAnimations(anim, dt)
	if not anim or (anim.fruitTotal or 0) <= 0 then
		return
	end

	anim.fruitSpawnTimer = (anim.fruitSpawnTimer or 0) + dt
	local interval = anim.fruitSpawnInterval or 0.08

	local metrics = anim.barMetrics

	if metrics then
		while (anim.fruitRemaining or 0) > 0 and anim.fruitSpawnTimer >= interval do
			if not SpawnFruitAnimation(anim) then
				break
			end
			anim.fruitSpawnTimer = anim.fruitSpawnTimer - interval
			interval = anim.fruitSpawnInterval or interval
		end
	end

	local active = anim.fruitAnimations or {}
	for index = #active, 1, -1 do
		local fruit = active[index]
		fruit.timer = (fruit.timer or 0) + dt
		local duration = fruit.duration or 0.6
		if duration <= 0 then
			table.remove(active, index)
		else
			local progress = clamp(fruit.timer / duration, 0, 1)
			fruit.progress = progress

			if progress >= 1 then
				if not fruit.landed then
					fruit.landed = true
					fruit.fade = 0
					fruit.landingTimer = 0
					fruit.splashTimer = 0
					fruit.splashDuration = fruit.splashDuration or 0.35

					local XpPer = anim.fruitXpPer or 0
					if XpPer > 0 then
						local pending = anim.pendingFruitXp or 0
						local delivered = anim.fruitDelivered or 0
						local remaining = math.max(0, (anim.fruitPoints or 0) - delivered - pending)
						local grant = math.min(remaining, XpPer)
						anim.pendingFruitXp = pending + grant
					end

					anim.barPulse = math.min(1.5, (anim.barPulse or 0) + 0.45)
				end

				fruit.landingTimer = (fruit.landingTimer or 0) + dt
				fruit.splashTimer = (fruit.splashTimer or 0) + dt
				fruit.fade = (fruit.fade or 0) + dt

				if fruit.fade >= 0.35 then
					table.remove(active, index)
				end
			end
		end
	end

end

local function DrawFruitAnimations(anim)
	local fruits = anim and anim.fruitAnimations
	if not fruits or #fruits == 0 then
		return
	end

	for _, fruit in ipairs(fruits) do
		local progress = clamp(fruit.progress or 0, 0, 1)
		local eased = EaseOutQuad(progress)
		local inv = 1 - eased
		local PathX = inv * inv * (fruit.startX or 0)
			+ 2 * inv * eased * (fruit.controlX or 0)
			+ eased * eased * (fruit.endX or 0)
		local PathY = inv * inv * (fruit.startY or 0)
			+ 2 * inv * eased * (fruit.controlY or 0)
			+ eased * eased * (fruit.endY or 0)

		local wobble = math.sin((fruit.wobbleSeed or 0) + (fruit.wobbleSpeed or 5.2) * eased)
		local WobbleMul = 0.95 + wobble * 0.04

		local ScaleStart = fruit.scaleStart or 0.5
		local ScalePeak = fruit.scalePeak or (ScaleStart * 1.35)
		local ScaleEnd = fruit.scaleEnd or (ScaleStart * 0.95)
		local scale
		if progress < 0.5 then
			local t = clamp(progress / 0.5, 0, 1)
			scale = ScaleStart + (ScalePeak - ScaleStart) * EaseOutBack(t)
		else
			local t = clamp((progress - 0.5) / 0.5, 0, 1)
			scale = ScalePeak + (ScaleEnd - ScalePeak) * EaseOutQuad(t)
		end

		local radius = 12 * scale * WobbleMul
		local FadeMul = 1
		if fruit.fade then
			FadeMul = clamp(1 - fruit.fade / 0.35, 0, 1)
		end

		local color = fruit.color or Theme.AppleColor
		local highlight = LightenColor(color, 0.42)

		local DrawFruit = not fruit.landed or (fruit.splashTimer or 0) < 0.08
		if DrawFruit and FadeMul > 0 then
			love.graphics.setColor(0, 0, 0, 0.25 * FadeMul)
			love.graphics.ellipse("fill", PathX + 3, PathY + 3 + wobble * 3, radius * 1.05, radius * 0.9, 30)

			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * FadeMul)
			love.graphics.circle("fill", PathX, PathY + wobble * 2, radius, 30)

			love.graphics.setColor(0, 0, 0, 0.85 * FadeMul)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", PathX, PathY + wobble * 2, radius, 30)

			love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.7) * FadeMul)
			love.graphics.circle("fill", PathX - radius * 0.35, PathY + wobble * 2 - radius * 0.45, radius * 0.45, 24)
		end

		love.graphics.setLineWidth(1)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function DrawBackground(sw, sh)
	local BaseColor = (UI.colors and UI.colors.background) or Theme.BgColor
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

-- All button definitions in one place
local ButtonDefs = {
	{ id = "GoPlay", TextKey = "gameover.play_again", action = "game" },
	{ id = "GoMenu", TextKey = "gameover.quit_to_menu", action = "menu" },
}

local function CalculateStatLayout(ContentWidth, padding, count)
	local TotalCards = math.max(0, count or 0)
	local AvailableWidth = math.max(0, ContentWidth - padding * 2)
	local MaxColumns = math.min(TotalCards, 3)
	local columns = math.max(1, MaxColumns)
	local StatCardSpacing = GetStatCardSpacing()
	local StatCardMinWidth = GetStatCardMinWidth()
	local StatCardHeight = GetStatCardHeight()

	if TotalCards == 0 then
		return {
			columns = 0,
			rows = 0,
			CardWidth = 0,
			height = 0,
			spacing = StatCardSpacing,
			AvailableWidth = AvailableWidth,
		}
	end

	while columns > 1 do
		local TentativeWidth = (AvailableWidth - StatCardSpacing * (columns - 1)) / columns
		if TentativeWidth >= StatCardMinWidth then
			break
		end
		columns = columns - 1
	end

	local CardWidth
	if columns <= 1 then
		columns = 1
		CardWidth = AvailableWidth
	else
		CardWidth = (AvailableWidth - StatCardSpacing * (columns - 1)) / columns
	end

	CardWidth = math.max(0, CardWidth)

	local rows = math.ceil(TotalCards / columns)
	local height = rows * StatCardHeight + math.max(0, rows - 1) * StatCardSpacing

	return {
		columns = columns,
		rows = rows,
		CardWidth = CardWidth,
		height = height,
		spacing = StatCardSpacing,
		AvailableWidth = AvailableWidth,
	}
end

local function CalculateAchievementsLayout(achievements, PanelWidth, SectionPadding, InnerSpacing, SmallSpacing)
	local list = achievements or {}
	if not list or #list == 0 or (PanelWidth or 0) <= 0 then
		return nil
	end

	local HeaderHeight = FontProgressSmall:getHeight()
	local TextWidth = math.max(0, PanelWidth - SectionPadding * 2)
	local TotalHeight = HeaderHeight
	local entries = {}

	for index, achievement in ipairs(list) do
		TotalHeight = TotalHeight + InnerSpacing
		TotalHeight = TotalHeight + FontSmall:getHeight()

		local description = achievement.description or ""
		local DescriptionLines = 0
		if description ~= "" then
			if TextWidth > 0 then
				local _, wrapped = FontProgressSmall:getWrap(description, TextWidth)
				if wrapped and #wrapped > 0 then
					DescriptionLines = #wrapped
				else
					DescriptionLines = 1
				end
			else
				DescriptionLines = 1
			end
		end

		TotalHeight = TotalHeight + DescriptionLines * FontProgressSmall:getHeight()

		entries[#entries + 1] = {
			title = achievement.title or "",
			description = description,
			DescriptionLines = DescriptionLines,
		}

		if index < #list then
			TotalHeight = TotalHeight + SmallSpacing
		end
	end

	local PanelHeight = SectionPadding * 2 + TotalHeight
	PanelHeight = math.floor(PanelHeight + 0.5)

	return {
		entries = entries,
		height = PanelHeight,
		HeaderHeight = HeaderHeight,
		TextWidth = TextWidth,
	}
end

local function DefaultButtonLayout(sw, sh, defs, StartY)
	local list = {}
	local ButtonWidth, ButtonHeight, ButtonSpacing = GetButtonMetrics()
	local CenterX = sw / 2 - ButtonWidth / 2

	for i, def in ipairs(defs) do
		local y = StartY + (i - 1) * (ButtonHeight + ButtonSpacing)
		list[#list + 1] = {
			id = def.id,
			TextKey = def.textKey,
			text = def.text,
			action = def.action,
			x = CenterX,
			y = y,
			w = ButtonWidth,
			h = ButtonHeight,
		}
	end

	return list
end

local function DrawCenteredPanel(x, y, width, height, radius)
	UI.DrawPanel(x, y, width, height, {
		radius = radius,
		ShadowOffset = UI.spacing.ShadowOffset,
		fill = Theme.PanelColor,
		BorderColor = Theme.PanelBorder,
		BorderWidth = 2,
	})
end

local function DrawInsetPanel(x, y, width, height, options)
	if width <= 0 or height <= 0 then
		return
	end

	options = options or {}
	local radius = options.radius or 16
	local LightenFactor = options.lighten or 0.12
	local BaseAlpha = options.alpha or 0.88
	local BorderAlpha = options.borderAlpha or 0.65
	local BorderWidth = options.borderWidth or 1

	local BaseColor = Theme.PanelColor or { 0.18, 0.18, 0.22, 1 }
	local FillColor = WithAlpha(LightenColor(BaseColor, LightenFactor), BaseAlpha)
	local BorderColor = WithAlpha(Theme.PanelBorder or { 0.35, 0.3, 0.5, 1 }, BorderAlpha)

	UI.DrawPanel(x, y, width, height, {
		radius = radius,
		ShadowOffset = 0,
		fill = FillColor,
		BorderColor = BorderColor,
		BorderWidth = BorderWidth,
	})
end

local function HandleButtonAction(_, action)
	return action
end

function GameOver:UpdateLayoutMetrics()
	if not FontSmall or not FontScore then
		return false
	end

	local sw = select(1, Screen:get())
	local padding = 24
	local margin = 24
	local MaxAllowed = math.max(40, sw - margin)
	local SafeMaxWidth = math.max(80, sw - margin * 2)
	SafeMaxWidth = math.min(SafeMaxWidth, MaxAllowed)
	local PreferredWidth = math.min(sw * 0.72, 640)
	local MinWidth = math.min(320, SafeMaxWidth)
	local ContentWidth = math.max(MinWidth, math.min(PreferredWidth, SafeMaxWidth))
	local InnerWidth = ContentWidth - padding * 2

	local SectionPadding = GetSectionPadding()
	local SectionSpacing = GetSectionSpacing()
	local InnerSpacing = GetSectionInnerSpacing()
	local SmallSpacing = GetSectionSmallSpacing()
	local HeaderSpacing = GetSectionHeaderSpacing()

	local WrapLimit = math.max(0, InnerWidth - SectionPadding * 2)

	local MessageText = self.DeathMessage or Localization:get("gameover.default_message")
	local _, WrappedMessage = FontSmall:getWrap(MessageText, WrapLimit)
	local MessageLines = math.max(1, #WrappedMessage)
	local MessageHeight = MessageLines * FontSmall:getHeight()
	local MessagePanelHeight = math.floor(MessageHeight + SectionPadding * 2 + 0.5)

	local HeaderFont = UI.fonts.heading or FontSmall
	local HeaderHeight = HeaderFont:getHeight()

	local ScoreHeaderHeight = FontProgressSmall:getHeight()
	local ScoreNumberHeight = FontScore:getHeight()
	local BadgeHeight = 0
	if self.IsNewHighScore then
		BadgeHeight = FontBadge:getHeight() + SmallSpacing
	end
	local ScorePanelHeight = SectionPadding * 2 + ScoreHeaderHeight + InnerSpacing + ScoreNumberHeight + BadgeHeight
	ScorePanelHeight = math.floor(ScorePanelHeight + 0.5)

	local StatCards = 2
	local AchievementsList = self.AchievementsEarned or {}

	local XpPanelHeight = 0
	local XpLayout = nil
	if self.ProgressionAnimation then
		local AvailableWidth = math.max(0, InnerWidth - SectionPadding * 2)
		if AvailableWidth > 0 then
			local PreferredWidth = AvailableWidth * 0.85
			local MaxWidth = math.min(560, AvailableWidth)
			local MinWidth = math.min(AvailableWidth, math.max(320, InnerWidth * 0.45))
			local XpWidth = math.max(MinWidth, math.min(MaxWidth, PreferredWidth))
			XpWidth = math.floor(XpWidth + 0.5)
			local offset = math.floor(math.max(0, (AvailableWidth - XpWidth) / 2) + 0.5)

			local celebrations = (self.ProgressionAnimation.celebrations and #self.ProgressionAnimation.celebrations) or 0
			local BaseHeight = MeasureXpPanelHeight(self, XpWidth, 0)
			local TargetHeight = MeasureXpPanelHeight(self, XpWidth, celebrations)

			XpLayout = {
				width = XpWidth,
				offset = offset,
			}

			self.BaseXpSectionHeight = BaseHeight
			if not self.XpSectionHeight then
				self.XpSectionHeight = BaseHeight
			else
				self.XpSectionHeight = math.max(self.XpSectionHeight, BaseHeight)
			end

			local AnimatedHeight = self.XpSectionHeight or TargetHeight
			XpPanelHeight = math.floor(math.max(TargetHeight, AnimatedHeight) + 0.5)
		end
	end

	local MinColumnWidth = math.max(GetStatCardMinWidth() + SectionPadding * 2, 260)
	local ColumnSpacing = SectionSpacing

	local function BuildLayout(ColumnCount)
		ColumnCount = math.max(1, ColumnCount or 1)

		local AvailableWidth = math.max(0, InnerWidth - SectionPadding * 2)
		if AvailableWidth <= 0 then
			return {
				ColumnCount = 1,
				ColumnWidth = 0,
				entries = {},
				ColumnsHeight = 0,
				SectionInfo = {},
			}
		end

		local width
		if ColumnCount <= 1 then
			ColumnCount = 1
			width = AvailableWidth
		else
			width = (AvailableWidth - ColumnSpacing * (ColumnCount - 1)) / ColumnCount
			if width < MinColumnWidth then
				return nil
			end
		end

		if width <= 0 then
			return nil
		end

		local sections = {}
		local SectionInfo = {}

		if ScorePanelHeight > 0 then
			sections[#sections + 1] = { id = "score", height = ScorePanelHeight }
			SectionInfo.score = { height = ScorePanelHeight }
		end

		local StatLayout = CalculateStatLayout(width, SectionPadding, StatCards)
		local StatHeight = SectionPadding * 2 + FontProgressSmall:getHeight()
		if (StatLayout.height or 0) > 0 then
			StatHeight = StatHeight + InnerSpacing + StatLayout.height
		end
		StatHeight = math.floor(StatHeight + 0.5)
		if StatHeight > 0 then
			sections[#sections + 1] = { id = "stats", height = StatHeight, LayoutData = StatLayout }
			SectionInfo.stats = { height = StatHeight, layout = StatLayout }
		end

		local AchievementsLayout = CalculateAchievementsLayout(AchievementsList, width, SectionPadding, InnerSpacing, SmallSpacing)
		if AchievementsLayout and AchievementsLayout.height > 0 then
			sections[#sections + 1] = {
				id = "achievements",
				height = AchievementsLayout.height,
				LayoutData = AchievementsLayout,
			}
			SectionInfo.achievements = { height = AchievementsLayout.height, layout = AchievementsLayout }
		end

		if #sections == 0 then
			return {
				ColumnCount = ColumnCount,
				ColumnWidth = width,
				entries = {},
				ColumnsHeight = 0,
				SectionInfo = SectionInfo,
			}
		end

		local ColumnHeights = {}
		for i = 1, ColumnCount do
			ColumnHeights[i] = 0
		end

		local entries = {}
		for _, section in ipairs(sections) do
			local TargetColumn = 1
			for i = 2, ColumnCount do
				if ColumnHeights[i] < ColumnHeights[TargetColumn] - 0.01 then
					TargetColumn = i
				end
			end

			local OffsetY = ColumnHeights[TargetColumn]
			entries[#entries + 1] = {
				id = section.id,
				column = TargetColumn,
				x = (TargetColumn - 1) * (width + (ColumnCount > 1 and ColumnSpacing or 0)),
				y = OffsetY,
				width = width,
				height = section.height,
				LayoutData = section.layoutData,
			}

			ColumnHeights[TargetColumn] = ColumnHeights[TargetColumn] + section.height + SectionSpacing
		end

		local MaxColumnHeight = 0
		for i = 1, ColumnCount do
			local h = ColumnHeights[i]
			if h > 0 then
				h = h - SectionSpacing
			end
			if h > MaxColumnHeight then
				MaxColumnHeight = h
			end
		end

		return {
			ColumnCount = ColumnCount,
			ColumnWidth = width,
			entries = entries,
			ColumnsHeight = MaxColumnHeight,
			SectionInfo = SectionInfo,
		}
	end

	local LayoutOptions = { BuildLayout(2), BuildLayout(1) }
	local BestLayout = nil
	local BaseHeight = padding * 2 + HeaderHeight + HeaderSpacing + MessagePanelHeight
	local HasXpSection = XpPanelHeight > 0

	for _, option in ipairs(LayoutOptions) do
		if option then
			local EntryCount = #(option.entries or {})
			local TotalHeight = BaseHeight
			if HasXpSection then
				TotalHeight = TotalHeight + SectionSpacing + XpPanelHeight
			end
			if EntryCount > 0 then
				TotalHeight = TotalHeight + SectionSpacing
				if (option.columnsHeight or 0) > 0 then
					TotalHeight = TotalHeight + option.columnsHeight
				end
			end
			option.totalHeight = TotalHeight
			if not BestLayout or TotalHeight < (BestLayout.totalHeight or math.huge) then
				BestLayout = option
			end
		end
	end

	if not BestLayout then
		BestLayout = {
			ColumnCount = 1,
			ColumnWidth = InnerWidth - SectionPadding * 2,
			entries = {},
			ColumnsHeight = 0,
			SectionInfo = {},
			TotalHeight = HasXpSection and (BaseHeight + SectionSpacing + XpPanelHeight) or BaseHeight,
		}
	end

	local SummaryPanelHeight = math.floor((BestLayout.totalHeight or BaseHeight) + 0.5)
	ContentWidth = math.floor(ContentWidth + 0.5)
	WrapLimit = math.floor(WrapLimit + 0.5)

	local LayoutChanged = false
	if not self.SummaryPanelHeight or math.abs(self.SummaryPanelHeight - SummaryPanelHeight) >= 1 then
		LayoutChanged = true
	end
	if not self.ContentWidth or math.abs(self.ContentWidth - ContentWidth) >= 1 then
		LayoutChanged = true
	end
	if not self.WrapLimit or math.abs(self.WrapLimit - WrapLimit) >= 1 then
		LayoutChanged = true
	end

	local PreviousLayout = self.SummarySectionLayout or {}
	local PreviousEntries = PreviousLayout.entries or {}
	local NewEntries = BestLayout.entries or {}
	if (PreviousLayout.columnCount or 0) ~= (BestLayout.columnCount or 0)
		or #PreviousEntries ~= #NewEntries
		or math.abs((PreviousLayout.columnsHeight or 0) - (BestLayout.columnsHeight or 0)) >= 1 then
		LayoutChanged = true
	else
		for index, entry in ipairs(NewEntries) do
			local prev = PreviousEntries[index]
			if not prev
				or prev.id ~= entry.id
				or prev.column ~= entry.column
				or math.abs((prev.x or 0) - (entry.x or 0)) >= 1
				or math.abs((prev.y or 0) - (entry.y or 0)) >= 1
				or math.abs((prev.width or 0) - (entry.width or 0)) >= 1 then
				LayoutChanged = true
				break
			end
		end
	end

	local StatsInfo = BestLayout.sectionInfo.stats or {}
	local AchievementsInfo = BestLayout.sectionInfo.achievements or {}

	if not self.MessagePanelHeight or math.abs(self.MessagePanelHeight - MessagePanelHeight) >= 1 then
		LayoutChanged = true
	end
	if not self.ScorePanelHeight or math.abs(self.ScorePanelHeight - ScorePanelHeight) >= 1 then
		LayoutChanged = true
	end
	if not self.StatPanelHeight or math.abs(self.StatPanelHeight - (StatsInfo.height or 0)) >= 1 then
		LayoutChanged = true
	end
	if not self.AchievementsPanelHeight or math.abs(self.AchievementsPanelHeight - (AchievementsInfo.height or 0)) >= 1 then
		LayoutChanged = true
	end
	if not self.XpPanelHeight or math.abs(self.XpPanelHeight - XpPanelHeight) >= 1 then
		LayoutChanged = true
	end

	local PreviousXpLayout = self.XpLayout or {}
	local NewXpLayout = XpLayout or {}
	if math.abs((PreviousXpLayout.width or 0) - (NewXpLayout.width or 0)) >= 1
		or math.abs((PreviousXpLayout.offset or 0) - (NewXpLayout.offset or 0)) >= 1 then
		LayoutChanged = true
	end

	self.SummaryPanelHeight = SummaryPanelHeight
	self.ContentWidth = ContentWidth
	self.ContentPadding = padding
	self.WrapLimit = WrapLimit
	self.MessageLines = MessageLines
	self.MessagePanelHeight = MessagePanelHeight
	self.ScorePanelHeight = ScorePanelHeight
	self.StatPanelHeight = StatsInfo.height or 0
	self.SectionPaddingValue = SectionPadding
	self.SectionSpacingValue = SectionSpacing
	self.SectionInnerSpacingValue = InnerSpacing
	self.SectionSmallSpacingValue = SmallSpacing
	self.SectionHeaderSpacingValue = HeaderSpacing
	self.InnerContentWidth = InnerWidth
	self.StatLayout = StatsInfo.layout
	self.AchievementsPanelHeight = AchievementsInfo.height or 0
	self.AchievementsLayout = AchievementsInfo.layout
	self.SummarySectionLayout = BestLayout
	self.XpPanelHeight = XpPanelHeight
	self.XpLayout = XpLayout

	return LayoutChanged
end

function GameOver:ComputeAnchors(sw, sh, TotalButtonHeight, ButtonSpacing)
	TotalButtonHeight = math.max(0, TotalButtonHeight or 0)
	ButtonSpacing = math.max(0, ButtonSpacing or 0)

	local PanelHeight = math.max(0, self.SummaryPanelHeight or 0)
	local TitleTop = 48
	local TitleHeight = FontTitle and FontTitle:getHeight() or 0
	local PanelTopMin = TitleTop + TitleHeight + 24
	local BottomMargin = 40
	local ButtonAreaTop = sh - BottomMargin - TotalButtonHeight
	local SpacingBetween = math.max(48, ButtonSpacing)
	local PanelBottomMax = ButtonAreaTop - SpacingBetween

	if PanelBottomMax < PanelTopMin then
		PanelBottomMax = PanelTopMin
	end

	local AvailableSpace = math.max(0, PanelBottomMax - PanelTopMin)
	local PanelY = PanelTopMin

	if AvailableSpace > PanelHeight then
		PanelY = PanelTopMin + (AvailableSpace - PanelHeight) / 2
	elseif PanelHeight > AvailableSpace then
		PanelY = math.max(PanelTopMin, PanelBottomMax - PanelHeight)
	end

	PanelY = math.floor(PanelY + 0.5)

	local ButtonStartY = math.max(ButtonAreaTop, PanelY + PanelHeight + SpacingBetween)
	ButtonStartY = math.min(ButtonStartY, sh - BottomMargin - TotalButtonHeight)
	ButtonStartY = math.floor(ButtonStartY + 0.5)

	self.SummaryPanelY = PanelY
	self.ButtonStartY = ButtonStartY

	return PanelY, ButtonStartY
end

function GameOver:UpdateButtonLayout()
	local sw, sh = Screen:get()
	local _, ButtonHeight, ButtonSpacing = GetButtonMetrics()
	local TotalButtonHeight = 0
	if #ButtonDefs > 0 then
		TotalButtonHeight = #ButtonDefs * ButtonHeight + math.max(0, (#ButtonDefs - 1) * ButtonSpacing)
	end

	local _, StartY = self:ComputeAnchors(sw, sh, TotalButtonHeight, ButtonSpacing)
	local defs = DefaultButtonLayout(sw, sh, ButtonDefs, StartY)

	ButtonList:reset(defs)
end

local function AddCelebration(anim, entry)
	if not anim or not entry then
		return
	end

	anim.celebrations = anim.celebrations or {}
	entry.timer = 0
	entry.duration = entry.duration or 4.5
	table.insert(anim.celebrations, entry)

	local MaxVisible = 3
	while #anim.celebrations > MaxVisible do
		table.remove(anim.celebrations, 1)
	end
end

function GameOver:enter(data)
	UI.ClearButtons()
	ResetAnalogAxis()

	data = data or {cause = "unknown"}

	self.IsVictory = data.won == true
	self.CustomTitle = type(data.storyTitle) == "string" and data.storyTitle or nil
	GameOver.IsVictory = self.IsVictory

	Audio:PlayMusic("scorescreen")
	Screen:update()

	local cause = data.cause or "unknown"
	if self.IsVictory then
		local DefaultVictory = Localization:get("gameover.victory_message")
		if DefaultVictory == "gameover.victory_message" then
			DefaultVictory = "Noodl wriggles home with a belly full of snacks."
		end
		self.DeathMessage = data.endingMessage or DefaultVictory
	else
		self.DeathMessage = PickDeathMessage(cause)
	end
	self.SummaryMessage = self.DeathMessage

	ConfigureBackgroundEffect()

	FontTitle = UI.fonts.display or UI.fonts.title
	FontScore = UI.fonts.title or UI.fonts.display
	FontSmall = UI.fonts.caption or UI.fonts.body
	FontBadge = UI.fonts.badge or UI.fonts.button
	FontProgressTitle = UI.fonts.heading or UI.fonts.subtitle
	FontProgressValue = UI.fonts.display or UI.fonts.title
	FontProgressSmall = UI.fonts.caption or UI.fonts.body

	-- Merge default stats with provided stats
	stats = {
		score       = 0,
		HighScore   = 0,
		apples      = SessionStats:get("ApplesEaten"),
		TotalApples = "?",
	}
	for k, v in pairs(data.stats or {}) do
		stats[k] = v
	end
	if data.score then stats.score = data.score end
	if data.highScore then stats.highScore = data.highScore end
	if data.apples then stats.apples = data.apples end
	if data.totalApples then stats.totalApples = data.totalApples end

	stats.highScore = stats.highScore or 0
	stats.totalApples = stats.totalApples or stats.apples or 0
	self.IsNewHighScore = (stats.score or 0) > 0 and (stats.score or 0) >= (stats.highScore or 0)

	self.AchievementsEarned = {}
	local RunAchievements = SessionStats:get("RunAchievements")
	if type(RunAchievements) == "table" then
		for _, AchievementId in ipairs(RunAchievements) do
			local def = Achievements:GetDefinition(AchievementId)
			if def then
				self.AchievementsEarned[#self.AchievementsEarned + 1] = {
					id = AchievementId,
					title = Localization:get(def.titleKey),
					description = Localization:get(def.descriptionKey),
				}
			end
		end
	end

	self.DailyChallengeResult = DailyChallenges:ApplyRunResults(SessionStats)
	local ChallengeBonusXP = 0
	if self.DailyChallengeResult then
		ChallengeBonusXP = math.max(0, self.DailyChallengeResult.XpAwarded or 0)
	end

	self.DailyStreakMessage = nil
	self.DailyStreakColor = nil
	if self.DailyChallengeResult and self.DailyChallengeResult.StreakInfo then
		local info = self.DailyChallengeResult.StreakInfo
		local streak = math.max(0, info.current or 0)
		local best = math.max(streak, info.best or 0)

		if streak > 0 then
			local replacements = {
				streak = streak,
				unit = GetDayUnit(streak),
				best = best,
				BestUnit = GetDayUnit(best),
			}

			local MessageKey
			if self.DailyChallengeResult.CompletedNow then
				if info.wasNewBest then
					MessageKey = "gameover.daily_streak_new_best"
				else
					MessageKey = "gameover.daily_streak_extended"
				end
			elseif info.alreadyCompleted then
				MessageKey = "gameover.daily_streak_already_complete"
			elseif info.needsCompletion then
				MessageKey = "gameover.daily_streak_needs_completion"
			else
				MessageKey = "gameover.daily_streak_status"
			end

			self.DailyStreakMessage = Localization:get(MessageKey, replacements)

			if self.DailyChallengeResult.CompletedNow then
				if info.wasNewBest then
					self.DailyStreakColor = Theme.AccentTextColor or UI.colors.AccentText or UI.colors.highlight
				else
					self.DailyStreakColor = Theme.ProgressColor or UI.colors.progress or UI.colors.highlight
				end
			elseif info.alreadyCompleted then
				self.DailyStreakColor = UI.colors.MutedText or Theme.MutedTextColor or UI.colors.text
			elseif info.needsCompletion then
				self.DailyStreakColor = Theme.WarningColor or UI.colors.warning or UI.colors.highlight
			else
				self.DailyStreakColor = UI.colors.highlight or UI.colors.text
			end
		end
	end

	self.progression = MetaProgression:GrantRunPoints({
		apples = stats.apples or 0,
		score = stats.score or 0,
		BonusXP = ChallengeBonusXP,
	})

	self.XpSectionHeight = nil
	self.BaseXpSectionHeight = nil
	self.ProgressionAnimation = nil

	if self.progression then
		local StartSnapshot = self.progression.start or { total = 0, level = 1, XpIntoLevel = 0, XpForNext = MetaProgression:GetXpForLevel(1) }
		local ResultSnapshot = self.progression.result or StartSnapshot

		local FillSpeed = math.max(60, (self.progression.gained or 0) / 1.2)
		self.ProgressionAnimation = {
			DisplayedTotal = StartSnapshot.total or 0,
			TargetTotal = ResultSnapshot.total or (StartSnapshot.total or 0),
			DisplayedLevel = StartSnapshot.level or 1,
			XpIntoLevel = StartSnapshot.xpIntoLevel or 0,
			XpForLevel = StartSnapshot.xpForNext or MetaProgression:GetXpForLevel(StartSnapshot.level or 1),
			DisplayedGained = 0,
                        FillSpeed = FillSpeed,
                        LevelFlash = 0,
                        LevelPopDuration = 0.65,
                        LevelPopTimer = 0.65,
                        celebrations = {},
			PendingMilestones = {},
			LevelUnlocks = {},
			BonusXP = ChallengeBonusXP,
			BarPulse = 0,
			PendingFruitXp = 0,
			FruitDelivered = 0,
			FillEaseSpeed = clamp(FillSpeed / 12, 6, 16),
		}

		local ApplesCollected = math.max(0, stats.apples or 0)
		local FruitPoints = 0
		if self.progression and self.progression.breakdown then
			FruitPoints = math.max(0, self.progression.breakdown.FruitPoints or 0)
		end
		local XpPerFruit = 0
		if ApplesCollected > 0 and FruitPoints > 0 then
			XpPerFruit = FruitPoints / ApplesCollected
		end
		local SpawnInterval = 0.08
		if XpPerFruit > 0 and FillSpeed > 0 then
			SpawnInterval = clamp(XpPerFruit / FillSpeed, 0.03, 0.16)
		end

		self.ProgressionAnimation.FruitTotal = ApplesCollected
		self.ProgressionAnimation.FruitRemaining = ApplesCollected
		self.ProgressionAnimation.FruitAnimations = {}
		self.ProgressionAnimation.FruitSpawnTimer = 0
		self.ProgressionAnimation.FruitSpawnInterval = SpawnInterval
		self.ProgressionAnimation.FruitPalette = {
			Theme.AppleColor,
			Theme.BananaColor,
			Theme.BlueberryColor,
			Theme.GoldenPearColor,
			Theme.DragonfruitColor,
		}
		self.ProgressionAnimation.FruitXpPer = XpPerFruit
		self.ProgressionAnimation.FruitPoints = FruitPoints

		local StartLevel = self.ProgressionAnimation.DisplayedLevel or StartSnapshot.level or 1
		if (self.ProgressionAnimation.XpForLevel or 0) > 0 then
			self.ProgressionAnimation.VisualPercent = clamp((self.ProgressionAnimation.XpIntoLevel or 0) / self.ProgressionAnimation.XpForLevel, 0, 1)
		else
			self.ProgressionAnimation.VisualPercent = 0
		end
		self.ProgressionAnimation.VisualProgress = math.max(0, (StartLevel - 1) + (self.ProgressionAnimation.VisualPercent or 0))

		if type(self.progression.milestones) == "table" then
			for _, milestone in ipairs(self.progression.milestones) do
				self.ProgressionAnimation.PendingMilestones[#self.ProgressionAnimation.PendingMilestones + 1] = {
					threshold = milestone.threshold,
					triggered = false,
				}
			end
		end

		if type(self.progression.unlocks) == "table" then
			for _, unlock in ipairs(self.progression.unlocks) do
				local level = unlock.level
				self.ProgressionAnimation.LevelUnlocks[level] = self.ProgressionAnimation.LevelUnlocks[level] or {}
				table.insert(self.ProgressionAnimation.LevelUnlocks[level], {
					name = unlock.name,
					description = unlock.description,
				})
			end
		end
	end

	self:UpdateLayoutMetrics()
	self:UpdateButtonLayout()

end

local function GetLocalizedOrFallback(key, fallback)
	local value = Localization:get(key)
	if value == key then
		return fallback
	end
	return value
end

local function DrawStatPill(x, y, width, height, label, value)
	UI.DrawPanel(x, y, width, height, {
		radius = 18,
		ShadowOffset = 0,
		fill = { Theme.PanelColor[1], Theme.PanelColor[2], Theme.PanelColor[3], (Theme.PanelColor[4] or 1) * 0.7 },
		BorderColor = UI.colors.border or Theme.PanelBorder,
		BorderWidth = 2,
	})

	UI.DrawLabel(label, x + 8, y + 12, width - 16, "center", {
		font = FontProgressSmall,
		color = UI.colors.MutedText or UI.colors.text,
	})

	local DisplayFont = FontProgressValue
	if DisplayFont:getWidth(value) > width - 32 then
		DisplayFont = FontBadge
		if DisplayFont:getWidth(value) > width - 32 then
			DisplayFont = FontSmall
		end
	end

	local ValueY = y + height / 2 - DisplayFont:getHeight() / 2 + 6
	UI.DrawLabel(value, x + 8, ValueY, width - 16, "center", {
		font = DisplayFont,
		color = UI.colors.text,
	})
end

local function DrawCelebrationsList(anim, x, StartY, width)
	local events = anim and anim.celebrations or {}
	if not events or #events == 0 then
		return StartY
	end

	local y = StartY
	local CardWidth = width - 32
	local now = love.timer.getTime()

	local CelebrationHeight = GetCelebrationEntryHeight()
	local CelebrationSpacing = GetCelebrationEntrySpacing()
	local OuterRadius = (UI.scaled and UI.scaled(16, 12)) or 16
	local InnerRadius = (UI.scaled and UI.scaled(12, 8)) or 12

	for index, event in ipairs(events) do
		local timer = math.max(0, event.timer or 0)
		local appear = math.min(1, timer / 0.35)
		local AppearEase = EaseOutBack(appear)
		local FadeAlpha = 1
		local duration = event.duration or 4.5
		if duration > 0 then
			local FadeStart = math.max(0, duration - 0.65)
			if timer > FadeStart then
				local FadeProgress = math.min(1, (timer - FadeStart) / 0.65)
				FadeAlpha = 1 - FadeProgress
			end
		end

		local alpha = math.max(0, FadeAlpha)

		if alpha > 0.01 then
			local CardX = x + 16
			local CardY = y
			local wobble = math.sin(now * 4.2 + index * 0.8) * 2 * alpha

			love.graphics.push()
			love.graphics.translate(CardX + CardWidth / 2, CardY + CelebrationHeight / 2 + wobble)
			love.graphics.scale(0.92 + 0.08 * AppearEase, 0.92 + 0.08 * AppearEase)
			love.graphics.translate(-(CardX + CardWidth / 2), -(CardY + CelebrationHeight / 2 + wobble))

			love.graphics.setColor(0, 0, 0, 0.35 * alpha)
			love.graphics.rectangle("fill", CardX + 5, CardY + 6, CardWidth, CelebrationHeight, OuterRadius, OuterRadius)

			local accent = event.color or Theme.ProgressColor or { 1, 1, 1, 1 }
			love.graphics.setColor(accent[1], accent[2], accent[3], 0.22 * alpha)
			love.graphics.rectangle("fill", CardX, CardY, CardWidth, CelebrationHeight, OuterRadius, OuterRadius)

			love.graphics.setColor(accent[1], accent[2], accent[3], 0.55 * alpha)
			love.graphics.setLineWidth(2)
			love.graphics.rectangle("line", CardX, CardY, CardWidth, CelebrationHeight, OuterRadius, OuterRadius)

			local shimmer = 0.45 + 0.25 * math.sin(now * 6 + index)
			love.graphics.setColor(accent[1], accent[2], accent[3], shimmer * 0.18 * alpha)
			love.graphics.rectangle("line", CardX + 3, CardY + 3, CardWidth - 6, CelebrationHeight - 6, InnerRadius, InnerRadius)

			UI.DrawLabel(event.title or "", CardX + 18, CardY + 12, CardWidth - 36, "left", {
				font = FontProgressSmall,
				color = { UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], alpha },
			})

			if event.subtitle and event.subtitle ~= "" then
				UI.DrawLabel(event.subtitle, CardX + 18, CardY + 32, CardWidth - 36, "left", {
					font = FontSmall,
					color = { UI.colors.MutedText[1], UI.colors.MutedText[2], UI.colors.MutedText[3], alpha },
				})
			end

			love.graphics.pop()
		end

		y = y + CelebrationSpacing
	end

	love.graphics.setLineWidth(1)
	return y
end

local function DrawXpSection(self, x, y, width)
	local anim = self.ProgressionAnimation
	if not anim then
		return
	end

	local CelebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local BaseHeight = self.BaseXpSectionHeight or MeasureXpPanelHeight(self, width, 0)
	local TargetHeight = MeasureXpPanelHeight(self, width, CelebrationCount)
	self.BaseXpSectionHeight = self.BaseXpSectionHeight or BaseHeight
	local AnimatedHeight = self.XpSectionHeight or TargetHeight
	local height = math.max(160, BaseHeight, TargetHeight, AnimatedHeight)
	UI.DrawPanel(x, y, width, height, {
		radius = 18,
		ShadowOffset = 0,
		fill = { Theme.PanelColor[1], Theme.PanelColor[2], Theme.PanelColor[3], (Theme.PanelColor[4] or 1) * 0.65 },
		BorderColor = UI.colors.border or Theme.PanelBorder,
		BorderWidth = 2,
	})

	local HeaderY = y + 18
	UI.DrawLabel(GetLocalizedOrFallback("gameover.meta_progress_title", "Experience"), x, HeaderY, width, "center", {
		font = FontProgressTitle,
		color = UI.colors.text,
	})

	local LevelColor = Theme.ProgressColor or UI.colors.progress or UI.colors.text
	local flash = math.max(0, math.min(1, anim.levelFlash or 0))
        local LevelText = Localization:get("gameover.meta_progress_level_label", { level = anim.displayedLevel or 1 })
        local LevelY = HeaderY + FontProgressTitle:getHeight() + 16
	UI.DrawLabel(LevelText, x, LevelY, width, "center", {
		font = FontProgressValue,
		color = { LevelColor[1] or 1, LevelColor[2] or 1, LevelColor[3] or 1, 0.78 + 0.2 * flash },
	})

	if flash > 0.01 then
		local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		local CenterX = x + width / 2
		local CenterY = LevelY + FontProgressValue:getHeight() / 2
		love.graphics.setColor(LevelColor[1] or 1, LevelColor[2] or 1, LevelColor[3] or 1, 0.24 * flash)
		love.graphics.circle("fill", CenterX, CenterY, 48 + flash * 26, 48)
		love.graphics.setColor(1, 1, 1, 0.12 * flash)
		love.graphics.circle("line", CenterX, CenterY, 48 + flash * 18, 48)
		love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
	end

	local gained = math.max(0, math.floor((anim.displayedGained or 0) + 0.5))
	local GainedText = Localization:get("gameover.meta_progress_gain_short", { points = gained })
	local GainedY = LevelY + FontProgressValue:getHeight() + 6
	UI.DrawLabel(GainedText, x, GainedY, width, "center", {
		font = FontProgressSmall,
		color = UI.colors.MutedText or UI.colors.text,
	})

	local RingTop = GainedY + FontProgressSmall:getHeight() + 18
	local CenterX = x + width / 2
	local MaxRadius = math.max(48, math.min(74, (width / 2) - 24))
	local RingThickness = math.max(14, math.min(24, MaxRadius * 0.42))
	local RingRadius = MaxRadius - RingThickness * 0.25
	local InnerRadius = math.max(32, RingRadius - RingThickness * 0.6)
	local OuterRadius = RingRadius + RingThickness * 0.45
	local CenterY = RingTop + RingRadius
	local percent = clamp(anim.visualPercent or 0, 0, 1)
	local pulse = clamp(anim.barPulse or 0, 0, 1)

	anim.barMetrics = anim.barMetrics or {}
	anim.barMetrics.style = "radial"
	anim.barMetrics.centerX = CenterX
	anim.barMetrics.centerY = CenterY
	anim.barMetrics.radius = RingRadius
	anim.barMetrics.innerRadius = InnerRadius
	anim.barMetrics.outerRadius = OuterRadius
	anim.barMetrics.thickness = RingThickness

	local PanelColor = Theme.PanelColor or { 0.18, 0.18, 0.22, 1 }
	local TrackColor = WithAlpha(DarkenColor(PanelColor, 0.2), 0.85)
	local RingColor = { LevelColor[1] or 1, LevelColor[2] or 1, LevelColor[3] or 1, 0.9 }

	love.graphics.setColor(TrackColor)
	love.graphics.circle("fill", CenterX, CenterY, OuterRadius)

	local StartAngle = -math.pi / 2
	love.graphics.setColor(WithAlpha(LightenColor(PanelColor, 0.12), 0.88))
	love.graphics.setLineWidth(RingThickness)
	love.graphics.arc("line", "open", CenterX, CenterY, RingRadius, StartAngle, StartAngle + math.pi * 2, 96)

	if percent > 0 then
		local EndAngle = StartAngle + percent * math.pi * 2
		local scale = 1 + pulse * 0.04
		local WidthMul = 1 + pulse * 0.45

		love.graphics.setColor(RingColor)
		love.graphics.setLineWidth(RingThickness * WidthMul)
		love.graphics.arc("line", "open", CenterX, CenterY, RingRadius * scale, StartAngle, EndAngle, 96)

		local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(RingColor[1], RingColor[2], RingColor[3], 0.24 + 0.18 * flash)
		love.graphics.arc("line", "open", CenterX, CenterY, RingRadius * (scale + 0.08 + pulse * 0.06), StartAngle, EndAngle, 96)
		love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
	end

	love.graphics.setColor(WithAlpha(LightenColor(PanelColor, 0.18), 0.94))
	love.graphics.circle("fill", CenterX, CenterY, InnerRadius)

	DrawFruitAnimations(anim)

	love.graphics.setColor(WithAlpha(Theme.PanelBorder or { 0.35, 0.3, 0.5, 1 }, 0.85))
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", CenterX, CenterY, InnerRadius, 96)
	love.graphics.setLineWidth(1)

	if flash > 0.01 then
		local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(RingColor[1], RingColor[2], RingColor[3], 0.26 * flash)
		love.graphics.circle("line", CenterX, CenterY, OuterRadius + flash * 22, 96)
		love.graphics.setColor(1, 1, 1, 0.14 * flash)
		love.graphics.circle("fill", CenterX, CenterY, InnerRadius + flash * 14, 96)
		love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
	end

        love.graphics.setFont(FontProgressValue)
        love.graphics.setColor(Theme.TextColor or UI.colors.text)
        local LevelValue = tostring(anim.displayedLevel or 1)
        local PopDuration = anim.levelPopDuration or 0.65
        local PopTimer = clamp(anim.levelPopTimer or PopDuration, 0, PopDuration)
        local PopProgress = 1
        if PopDuration > 1e-6 then
                PopProgress = clamp(PopTimer / PopDuration, 0, 1)
        end
        local PopScale = 1
        if PopProgress < 1 then
                local pop = clamp(1 - PopProgress, 0, 1)
                PopScale = 1 + EaseOutBack(pop) * 0.3
        end

        love.graphics.push()
        love.graphics.translate(CenterX, CenterY)
        love.graphics.scale(PopScale, PopScale)
        love.graphics.printf(LevelValue, -InnerRadius, -FontProgressValue:getHeight() / 2 + 2, InnerRadius * 2, "center")
        love.graphics.pop()

	local TotalLabel = Localization:get("gameover.meta_progress_total_label", {
		total = math.floor((anim.displayedTotal or 0) + 0.5),
	})

	local RemainingLabel
	if (anim.xpForLevel or 0) <= 0 then
		RemainingLabel = Localization:get("gameover.meta_progress_max_level")
	else
		local remaining = math.max(0, math.ceil((anim.xpForLevel or 0) - (anim.xpIntoLevel or 0)))
		RemainingLabel = Localization:get("gameover.meta_progress_next", { remaining = remaining })
	end

	local LabelY = CenterY + OuterRadius + 18
	local breakdown = self.progression and self.progression.breakdown or {}
	local BonusXP = math.max(0, math.floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
	if BonusXP > 0 then
		local BonusText = Localization:get("gameover.meta_progress_bonus", { bonus = BonusXP })
		UI.DrawLabel(BonusText, x, LabelY, width, "center", {
			font = FontProgressSmall,
			color = UI.colors.highlight or UI.colors.text,
		})
		LabelY = LabelY + FontProgressSmall:getHeight() + 6
	end

	if self.DailyStreakMessage then
		UI.DrawLabel(self.DailyStreakMessage, x, LabelY, width, "center", {
			font = FontProgressSmall,
			color = self.DailyStreakColor or UI.colors.highlight or UI.colors.text,
		})
		LabelY = LabelY + FontProgressSmall:getHeight() + 6
	end

	UI.DrawLabel(TotalLabel, x, LabelY, width, "center", {
		font = FontProgressSmall,
		color = UI.colors.text,
	})

	LabelY = LabelY + FontProgressSmall:getHeight() + 4
	UI.DrawLabel(RemainingLabel, x, LabelY, width, "center", {
		font = FontProgressSmall,
		color = UI.colors.MutedText or UI.colors.text,
	})

	local CelebrationStart = LabelY + FontProgressSmall:getHeight() + 16
	DrawCelebrationsList(anim, x, CelebrationStart, width)
end

local function DrawScorePanel(self, x, y, width, height, SectionPadding, InnerSpacing, SmallSpacing)
	if (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	DrawInsetPanel(x, y, width, height, { radius = 18 })

	local ScoreLabel = GetLocalizedOrFallback("gameover.score_label", "Score")
	local LabelY = y + SectionPadding
	UI.DrawLabel(ScoreLabel, x + SectionPadding, LabelY, width - SectionPadding * 2, "center", {
		font = FontProgressSmall,
		color = UI.colors.MutedText or UI.colors.text,
	})

	local ValueY = LabelY + FontProgressSmall:getHeight() + InnerSpacing
	local ProgressColor = Theme.ProgressColor or { 1, 1, 1, 1 }
	UI.DrawLabel(tostring(stats.score or 0), x, ValueY, width, "center", {
		font = FontScore,
		color = { ProgressColor[1] or 1, ProgressColor[2] or 1, ProgressColor[3] or 1, 0.92 },
	})

	if self.IsNewHighScore then
		local BadgeColor = Theme.AchieveColor or { 1, 1, 1, 1 }
		local BadgeY = ValueY + FontScore:getHeight() + SmallSpacing
		UI.DrawLabel(Localization:get("gameover.high_score_badge"), x + SectionPadding, BadgeY, width - SectionPadding * 2, "center", {
			font = FontBadge,
			color = { BadgeColor[1] or 1, BadgeColor[2] or 1, BadgeColor[3] or 1, 0.9 },
		})
	end
end

local function DrawStatsPanel(self, x, y, width, height, SectionPadding, InnerSpacing, LayoutData)
	if (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	DrawInsetPanel(x, y, width, height, { radius = 18 })

	local StatsHeader = GetLocalizedOrFallback("gameover.stats_header", "Highlights")
	local StatsY = y + SectionPadding
	UI.DrawLabel(StatsHeader, x + SectionPadding, StatsY, width - SectionPadding * 2, "left", {
		font = FontProgressSmall,
		color = UI.colors.MutedText or UI.colors.text,
	})

	StatsY = StatsY + FontProgressSmall:getHeight() + InnerSpacing

	local BestLabel = GetLocalizedOrFallback("gameover.stats_best_label", "Best")
	local ApplesLabel = GetLocalizedOrFallback("gameover.stats_apples_label", "Apples")
	local StatCards = {
		{ label = BestLabel, value = tostring(stats.highScore or 0) },
		{ label = ApplesLabel, value = tostring(stats.apples or 0) },
	}

	local StatLayout = LayoutData or CalculateStatLayout(width, SectionPadding, #StatCards)
	local AvailableWidth = (StatLayout and StatLayout.availableWidth) or (width - SectionPadding * 2)
	local StatSpacing = (StatLayout and StatLayout.spacing) or GetStatCardSpacing()
	local StatCardHeight = GetStatCardHeight()
	local CardIndex = 1
	local rows = math.max(1, (StatLayout and StatLayout.rows) or 1)
	local columns = math.max(1, (StatLayout and StatLayout.columns) or 1)

	for row = 1, rows do
		local ItemsInRow = math.min(columns, #StatCards - (row - 1) * columns)
		if ItemsInRow <= 0 then
			break
		end

		local RowWidth = ItemsInRow * (StatLayout.cardWidth or 0) + math.max(0, ItemsInRow - 1) * StatSpacing
		local RowOffset = math.max(0, (AvailableWidth - RowWidth) / 2)
		local BaseX = x + SectionPadding + RowOffset
		local RowY = StatsY + (row - 1) * (StatCardHeight + StatSpacing)

		for col = 0, ItemsInRow - 1 do
			local card = StatCards[CardIndex]
			if not card then
				break
			end

			local CardX = BaseX + col * ((StatLayout.cardWidth or 0) + StatSpacing)
			DrawStatPill(CardX, RowY, StatLayout.cardWidth or 0, StatCardHeight, card.label, card.value)
			CardIndex = CardIndex + 1
		end
	end
end

local function DrawAchievementsPanel(self, x, y, width, height, SectionPadding, InnerSpacing, SmallSpacing, LayoutData)
	if not LayoutData or (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	local entries = LayoutData.entries or {}
	if #entries == 0 then
		return
	end

	DrawInsetPanel(x, y, width, height, { radius = 18 })

	local AchievementsLabel = GetLocalizedOrFallback("gameover.achievements_header", "Achievements")
	local HeaderText = string.format("%s (%d)", AchievementsLabel, #entries)
	local TextX = x + SectionPadding
	local TextWidth = LayoutData.textWidth or (width - SectionPadding * 2)
	local EntryY = y + SectionPadding

	UI.DrawLabel(HeaderText, TextX, EntryY, TextWidth, "left", {
		font = FontProgressSmall,
		color = UI.colors.text,
	})

	EntryY = EntryY + FontProgressSmall:getHeight() + InnerSpacing

	for index, entry in ipairs(entries) do
		UI.DrawLabel(entry.title or "", TextX, EntryY, TextWidth, "left", {
			font = FontSmall,
			color = UI.colors.highlight or UI.colors.text,
		})
		EntryY = EntryY + FontSmall:getHeight()

		if entry.description and entry.description ~= "" then
			UI.DrawLabel(entry.description, TextX, EntryY, TextWidth, "left", {
				font = FontProgressSmall,
				color = UI.colors.MutedText or UI.colors.text,
			})
			EntryY = EntryY + (entry.descriptionLines or 0) * FontProgressSmall:getHeight()
		end

		if index < #entries then
			EntryY = EntryY + SmallSpacing
		end
	end
end

local function DrawCombinedPanel(self, ContentWidth, ContentX, padding, PanelY)
	local PanelHeight = self.SummaryPanelHeight or 0
	PanelY = PanelY or 120
	DrawCenteredPanel(ContentX, PanelY, ContentWidth, PanelHeight, 20)

	local InnerWidth = self.InnerContentWidth or (ContentWidth - padding * 2)
	local InnerX = ContentX + padding

	local SectionPadding = self.SectionPaddingValue or GetSectionPadding()
	local SectionSpacing = self.SectionSpacingValue or GetSectionSpacing()
	local InnerSpacing = self.SectionInnerSpacingValue or GetSectionInnerSpacing()
	local SmallSpacing = self.SectionSmallSpacingValue or GetSectionSmallSpacing()
	local HeaderSpacing = self.SectionHeaderSpacingValue or GetSectionHeaderSpacing()

	local HeaderFont = UI.fonts.heading or FontSmall
	local TitleY = PanelY + padding
	UI.DrawLabel(GetLocalizedOrFallback("gameover.run_summary_title", "Run Summary"), ContentX, TitleY, ContentWidth, "center", {
		font = HeaderFont,
		color = UI.colors.text,
	})

	local CurrentY = TitleY + HeaderFont:getHeight() + HeaderSpacing

	local WrapLimit = self.WrapLimit or math.max(0, InnerWidth - SectionPadding * 2)
	local MessageText = self.DeathMessage or Localization:get("gameover.default_message")
	local MessagePanelHeight = self.MessagePanelHeight or 0
	if MessagePanelHeight > 0 then
		DrawInsetPanel(InnerX, CurrentY, InnerWidth, MessagePanelHeight)
		UI.DrawLabel(MessageText, InnerX + SectionPadding, CurrentY + SectionPadding, WrapLimit, "center", {
			font = FontSmall,
			color = UI.colors.MutedText or UI.colors.text,
		})
		CurrentY = CurrentY + MessagePanelHeight
	end

	local XpHeight = self.XpPanelHeight or 0
	local XpLayout = self.XpLayout or {}

	if XpHeight > 0 then
		CurrentY = CurrentY + SectionSpacing
		local AvailableWidth = math.max(0, InnerWidth - SectionPadding * 2)
		local XpWidth = math.max(0, math.min(AvailableWidth, XpLayout.width or AvailableWidth))
		local offset = XpLayout.offset or math.max(0, (AvailableWidth - XpWidth) / 2)
		local XpX = InnerX + SectionPadding + offset
		DrawXpSection(self, XpX, CurrentY, XpWidth)
		CurrentY = CurrentY + XpHeight
	end

	local layout = self.SummarySectionLayout or {}
	local entries = layout.entries or {}

	if #entries > 0 then
		CurrentY = CurrentY + SectionSpacing
		local BaseX = InnerX + SectionPadding

		for _, entry in ipairs(entries) do
			local EntryWidth = entry.width or (InnerWidth - SectionPadding * 2)
			local EntryHeight = entry.height or 0
			local EntryX = BaseX + (entry.x or 0)
			local EntryY = CurrentY + (entry.y or 0)

			if entry.id == "score" then
				DrawScorePanel(self, EntryX, EntryY, EntryWidth, EntryHeight, SectionPadding, InnerSpacing, SmallSpacing)
			elseif entry.id == "stats" then
				DrawStatsPanel(self, EntryX, EntryY, EntryWidth, EntryHeight, SectionPadding, InnerSpacing, entry.layoutData or self.StatLayout)
			elseif entry.id == "achievements" then
				DrawAchievementsPanel(self, EntryX, EntryY, EntryWidth, EntryHeight, SectionPadding, InnerSpacing, SmallSpacing, entry.layoutData or self.AchievementsLayout)
			end
		end

		CurrentY = CurrentY + (layout.columnsHeight or 0)
	end
end

function GameOver:draw()
	local sw, sh = Screen:get()
	local LayoutChanged = self:UpdateLayoutMetrics()
	if LayoutChanged then
		self:UpdateButtonLayout()
	end
	DrawBackground(sw, sh)

	local _, ButtonHeight, ButtonSpacing = GetButtonMetrics()
	local TotalButtonHeight = 0
	if #ButtonDefs > 0 then
		TotalButtonHeight = #ButtonDefs * ButtonHeight + math.max(0, (#ButtonDefs - 1) * ButtonSpacing)
	end
	local PanelY = select(1, self:ComputeAnchors(sw, sh, TotalButtonHeight, ButtonSpacing))

	local margin = 24
	local FallbackMaxAllowed = math.max(40, sw - margin)
	local FallbackSafe = math.max(80, sw - margin * 2)
	FallbackSafe = math.min(FallbackSafe, FallbackMaxAllowed)
	local FallbackPreferred = math.min(sw * 0.72, 640)
	local FallbackMin = math.min(320, FallbackSafe)
	local ComputedWidth = math.max(FallbackMin, math.min(FallbackPreferred, FallbackSafe))
	local ContentWidth = self.ContentWidth or ComputedWidth
	local ContentX = (sw - ContentWidth) / 2
	local padding = self.ContentPadding or 24

	local TitleKey = self.IsVictory and "gameover.victory_title" or "gameover.title"
	local FallbackTitle = self.IsVictory and "Noodl's Grand Feast" or "Game Over"
	local TitleText = self.CustomTitle or GetLocalizedOrFallback(TitleKey, FallbackTitle)

	UI.DrawLabel(TitleText, 0, 48, sw, "center", {
		font = FontTitle,
		color = UI.colors.text,
	})

	DrawCombinedPanel(self, ContentWidth, ContentX, padding, PanelY)

	for _, btn in ButtonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	ButtonList:draw()
end

function GameOver:update(dt)
	local anim = self.ProgressionAnimation
	if not anim then
		local LayoutChanged = self:UpdateLayoutMetrics()
		if LayoutChanged then
			self:UpdateButtonLayout()
		end
		return
	end

	local TargetTotal = anim.targetTotal or anim.displayedTotal or 0
	local StartTotal = 0
	if self.progression and self.progression.start then
		StartTotal = self.progression.start.total or 0
	end

	local PreviousTotal = anim.displayedTotal or StartTotal
	local FruitPoints = math.max(0, anim.fruitPoints or 0)
	local DeliveredFruit = math.max(0, anim.fruitDelivered or 0)
	local PendingFruit = math.max(0, anim.pendingFruitXp or 0)
	local AllowedTarget = TargetTotal

	if FruitPoints > 0 and DeliveredFruit < FruitPoints then
		local GatedTarget = StartTotal + math.min(FruitPoints, DeliveredFruit + PendingFruit)
		AllowedTarget = math.min(AllowedTarget, GatedTarget)
	end

	local NewTotal = PreviousTotal
	if PreviousTotal < AllowedTarget then
		local increment = math.min(anim.fillSpeed * dt, AllowedTarget - PreviousTotal)
		NewTotal = PreviousTotal + increment

		if FruitPoints > 0 and DeliveredFruit < FruitPoints then
			local NewDelivered = math.min(FruitPoints, DeliveredFruit + increment)
			local used = NewDelivered - DeliveredFruit
			anim.fruitDelivered = NewDelivered
			anim.pendingFruitXp = math.max(0, PendingFruit - used)
		end
	elseif PreviousTotal < TargetTotal then
		NewTotal = math.min(TargetTotal, PreviousTotal)
	else
		NewTotal = TargetTotal
	end

	anim.displayedTotal = NewTotal
	if NewTotal >= TargetTotal - 1e-6 then
		anim.displayedTotal = TargetTotal
		anim.displayedGained = (self.progression and self.progression.gained) or 0
		anim.pendingFruitXp = 0
		anim.fruitDelivered = FruitPoints
	else
		anim.displayedGained = math.min((self.progression and self.progression.gained) or 0, NewTotal - StartTotal)
	end

	local PreviousLevel = anim.displayedLevel or 1
	local level, XpIntoLevel, XpForNext = MetaProgression:GetProgressForTotal(anim.displayedTotal)
        if level > PreviousLevel then
                anim.levelPopDuration = anim.levelPopDuration or 0.65
                anim.levelPopTimer = 0
                for LevelReached = PreviousLevel + 1, level do
                        anim.levelFlash = 0.9
			AddCelebration(anim, {
				type = "level",
				title = Localization:get("gameover.meta_progress_level_up", { level = LevelReached }),
				subtitle = Localization:get("gameover.meta_progress_level_up_subtitle"),
				color = Theme.ProgressColor or { 1, 1, 1, 1 },
				duration = 5.5,
			})
			Audio:PlaySound("goal_reached")

			local UnlockList = anim.levelUnlocks[LevelReached]
			if UnlockList then
				for _, unlock in ipairs(UnlockList) do
					AddCelebration(anim, {
						type = "unlock",
						title = Localization:get("gameover.meta_progress_unlock_header", { name = unlock.name or "???" }),
						subtitle = unlock.description or "",
						color = Theme.AchieveColor or { 1, 1, 1, 1 },
						duration = 6,
					})
				end
			end
		end
	end

	anim.displayedLevel = level
	anim.xpIntoLevel = XpIntoLevel
	anim.xpForLevel = XpForNext

	local XpForLevel = anim.xpForLevel or 0
	local TargetPercent = 0
	if XpForLevel > 0 then
		TargetPercent = clamp((anim.xpIntoLevel or 0) / XpForLevel, 0, 1)
	end

	local EaseSpeed = anim.fillEaseSpeed or 9
	if XpForLevel <= 0 then
		anim.visualProgress = math.max(0, (level - 1))
		anim.visualPercent = TargetPercent
	else
		local TargetProgress = math.max(0, (level - 1) + TargetPercent)
		if not anim.visualProgress then
			local BasePercent = anim.visualPercent or TargetPercent
			anim.visualProgress = math.max(0, (PreviousLevel - 1) + BasePercent)
		end

		local CurrentProgress = anim.visualProgress or 0
		TargetProgress = math.max(TargetProgress, CurrentProgress)
		anim.visualProgress = ApproachExp(CurrentProgress, TargetProgress, dt, EaseSpeed)

		local loops = math.floor(math.max(0, anim.visualProgress))
		local fraction = anim.visualProgress - loops
		anim.visualPercent = clamp(fraction, 0, 1)
	end

        if anim.levelFlash then
                anim.levelFlash = math.max(0, anim.levelFlash - dt)
        end

        local PopDuration = anim.levelPopDuration or 0.65
        if PopDuration > 0 then
                local timer = anim.levelPopTimer or PopDuration
                anim.levelPopTimer = math.min(PopDuration, timer + dt)
        else
                anim.levelPopTimer = 0
        end

	if anim.pendingMilestones then
		for _, milestone in ipairs(anim.pendingMilestones) do
			if not milestone.triggered and (anim.displayedTotal or 0) >= (milestone.threshold or 0) then
				milestone.triggered = true
				AddCelebration(anim, {
					type = "milestone",
					title = Localization:get("gameover.meta_progress_milestone_header"),
					subtitle = Localization:get("gameover.meta_progress_milestone", { threshold = milestone.threshold }),
					color = Theme.AchieveColor or { 1, 1, 1, 1 },
					duration = 6.5,
				})
				Audio:PlaySound("achievement")
			end
		end
	end

	if anim.celebrations then
		for index = #anim.celebrations, 1, -1 do
			local event = anim.celebrations[index]
			event.timer = (event.timer or 0) + dt
			if event.timer >= (event.duration or 4.5) then
				table.remove(anim.celebrations, index)
			end
		end
	end

	UpdateFruitAnimations(anim, dt)

	if anim.barPulse then
		anim.barPulse = math.max(0, anim.barPulse - dt * 2.4)
	end

	local CelebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local XpWidth = (self.XpLayout and self.XpLayout.width) or 0
	if XpWidth <= 0 then
		local InnerWidth = self.InnerContentWidth or 0
		local SectionPadding = self.SectionPaddingValue or GetSectionPadding()
		XpWidth = math.max(0, InnerWidth - SectionPadding * 2)
	end

	local BaseHeight = MeasureXpPanelHeight(self, XpWidth, 0)
	local TargetHeight = MeasureXpPanelHeight(self, XpWidth, CelebrationCount)
	self.BaseXpSectionHeight = BaseHeight
	self.XpSectionHeight = self.XpSectionHeight or BaseHeight
	local smoothing = math.min(dt * 6, 1)
	self.XpSectionHeight = self.XpSectionHeight + (TargetHeight - self.XpSectionHeight) * smoothing

	local LayoutChanged = self:UpdateLayoutMetrics()
	if LayoutChanged then
		self:UpdateButtonLayout()
	end
end

function GameOver:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
	return HandleButtonAction(self, action)
end

function GameOver:keypressed(key)
	if key == "up" or key == "left" then
		ButtonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		ButtonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		local action = ButtonList:activateFocused()
		local resolved = HandleButtonAction(self, action)
		if resolved then
			Audio:PlaySound("click")
		end
		return resolved
	elseif key == "escape" or key == "backspace" then
		Audio:PlaySound("click")
		return "menu"
	end
end

function GameOver:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		local action = ButtonList:activateFocused()
		local resolved = HandleButtonAction(self, action)
		if resolved then
			Audio:PlaySound("click")
		end
		return resolved
	elseif button == "b" then
		Audio:PlaySound("click")
		return "menu"
	end
end

GameOver.joystickpressed = GameOver.gamepadpressed

function GameOver:gamepadaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

GameOver.joystickaxis = GameOver.gamepadaxis

return GameOver
