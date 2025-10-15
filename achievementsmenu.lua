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

local AchievementsMenu = {
	TransitionDuration = 0.45,
}

local ButtonList = ButtonList.new()
local IconCache = {}
local DisplayBlocks = {}
local AchievementRewardText = {}

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
local ANALOG_DEADZONE = 0.35

local ScrollOffset = 0
local MinScrollOffset = 0
local ViewportHeight = 0
local ContentHeight = 0
local DPAD_SCROLL_AMOUNT = CARD_SPACING

local HeldDpadButton = nil
local HeldDpadAction = nil
local HeldDpadTimer = 0
local HeldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local BACKGROUND_EFFECT_TYPE = "AchievementRadiance"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.56

	Shaders.configure(effect, {
		BgColor = Theme.BgColor,
		AccentColor = Theme.AchieveColor,
		SparkleColor = Theme.AccentTextColor,
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

local function ResetHeldDpad()
	HeldDpadButton = nil
	HeldDpadAction = nil
	HeldDpadTimer = 0
	HeldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
end

local function StartHeldDpad(button, action)
	HeldDpadButton = button
	HeldDpadAction = action
	HeldDpadTimer = 0
	HeldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
end

local function StopHeldDpad(button)
	if HeldDpadButton ~= button then
		return
	end

	ResetHeldDpad()
end

local function UpdateHeldDpad(dt)
	if not HeldDpadAction then
		return
	end

	HeldDpadTimer = HeldDpadTimer + dt

	local interval = HeldDpadInterval
	while HeldDpadTimer >= interval do
		HeldDpadTimer = HeldDpadTimer - interval
		HeldDpadAction()
		HeldDpadInterval = DPAD_REPEAT_INTERVAL
		interval = HeldDpadInterval
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

local function LightenColor(color, amount)
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

local function DarkenColor(color, amount)
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

local function WithAlpha(color, alpha)
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

local function JoinWithConjunction(items)
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

local function FormatAchievementRewards(rewards)
	local formatted = {}
	for _, reward in ipairs(rewards or {}) do
		if reward.type == "cosmetic" then
			local label = Localization:get("achievements.rewards.cosmetic_skin", { name = reward.name })
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

	local HeadingKey = (#formatted > 1) and "achievements.rewards.multiple" or "achievements.rewards.single"
	local heading = Localization:get(HeadingKey)
	if heading == HeadingKey then
		heading = (#formatted > 1) and "Rewards" or "Reward"
	end

	return string.format("%s: %s", heading, JoinWithConjunction(formatted))
end

local function RebuildAchievementRewards()
	AchievementRewardText = {}

	if not SnakeCosmetics or not SnakeCosmetics.GetSkins then
		return
	end

	local ok, skins = pcall(SnakeCosmetics.GetSkins, SnakeCosmetics)
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
			list[#list + 1] = { type = "cosmetic", name = skin.name }
		end
	end

	for id, rewards in pairs(grouped) do
		local label = FormatAchievementRewards(rewards)
		if label then
			AchievementRewardText[id] = label
		end
	end
end

local function GetAchievementRewardLabel(achievement)
	if not achievement then
		return nil
	end

	return AchievementRewardText[achievement.id]
end

local function ToPercent(value)
	value = clamp01(value or 0)
	return math.floor(value * 100 + 0.5)
end

local function BuildThumbSnakeTrail(TrackX, TrackY, TrackWidth, TrackHeight, ThumbY, ThumbHeight)
	local SegmentSize = SnakeUtils.SEGMENT_SIZE
	local HalfSegment = SegmentSize * 0.5
	local TrackCenterX = TrackX + TrackWidth * 0.5
	local TrackTop = TrackY + HalfSegment
	local TrackBottom = TrackY + TrackHeight - HalfSegment
	local TopY = math.max(TrackTop, math.min(TrackBottom, ThumbY + HalfSegment))
	local BottomY = math.min(TrackBottom, math.max(TrackTop, ThumbY + ThumbHeight - HalfSegment))

	if BottomY < TopY then
		local midpoint = (TopY + BottomY) * 0.5
		BottomY = midpoint
		TopY = midpoint
	end

	local trail = {}
	trail[#trail + 1] = { x = TrackCenterX, y = BottomY }

	local spacing = SnakeUtils.SEGMENT_SPACING or SegmentSize
	local y = BottomY - spacing
	while y > TopY do
		trail[#trail + 1] = { x = TrackCenterX, y = y }
		y = y - spacing
	end

	trail[#trail + 1] = { x = TrackCenterX, y = TopY }

	return trail, SegmentSize
end

local function ComputeLayout(sw, sh)
	local layout = {}

	local EdgeMarginX = math.max(32, sw * 0.05)
	local BasePanelWidth = CARD_WIDTH + BASE_PANEL_PADDING_X * 2
	local AvailableWidth = sw - EdgeMarginX * 2
	local FallbackWidth = sw * 0.9
	local TargetWidth = math.max(AvailableWidth, FallbackWidth)
	TargetWidth = math.min(TargetWidth, sw - 24)
	local MaxPanelWidth = math.max(0, math.min(BasePanelWidth, TargetWidth))
	local WidthScale
	if MaxPanelWidth <= 0 then
		WidthScale = 1
	else
		WidthScale = math.min(1, MaxPanelWidth / BasePanelWidth)
	end

	layout.widthScale = WidthScale
	layout.cardWidth = CARD_WIDTH * WidthScale
	layout.panelPaddingX = BASE_PANEL_PADDING_X * WidthScale
	layout.panelWidth = BasePanelWidth * WidthScale

	local PanelPaddingX = layout.panelPaddingX
	local ScrollbarGap = math.max(MIN_SCROLLBAR_INSET, PanelPaddingX * 0.5)
	local MaxTotalWidth = sw - 24
	local TotalWidth = layout.panelWidth + ScrollbarGap + SCROLLBAR_TRACK_WIDTH
	if TotalWidth > MaxTotalWidth and BasePanelWidth > 0 then
		local AvailableForPanel = math.max(0, MaxTotalWidth - ScrollbarGap - SCROLLBAR_TRACK_WIDTH)
		if AvailableForPanel < layout.panelWidth then
			local AdjustedScale = AvailableForPanel / BasePanelWidth
			if AdjustedScale < WidthScale then
				WidthScale = math.max(0.5, AdjustedScale)
				layout.widthScale = WidthScale
				layout.cardWidth = CARD_WIDTH * WidthScale
				layout.panelPaddingX = BASE_PANEL_PADDING_X * WidthScale
				layout.panelWidth = BasePanelWidth * WidthScale
				PanelPaddingX = layout.panelPaddingX
				ScrollbarGap = math.max(MIN_SCROLLBAR_INSET, PanelPaddingX * 0.5)
				TotalWidth = layout.panelWidth + ScrollbarGap + SCROLLBAR_TRACK_WIDTH
			end
		end
	end

	local PanelX = (sw - TotalWidth) * 0.5
	local MaxPanelX = sw - TotalWidth - 12
	PanelX = math.max(12, math.min(PanelX, MaxPanelX))
	layout.panelX = PanelX
	layout.listX = PanelX + PanelPaddingX

	local TitleFont = UI.fonts.title
	local TitleFontHeight = TitleFont:getHeight()
	local TitleY = math.max(60, math.min(90, sh * 0.08))
	layout.titleY = TitleY

	local TopSpacing = math.max(28, sh * 0.045)
	local DesiredPanelTop = TitleY + TitleFontHeight + TopSpacing
	local ContainerTop = math.max(96, math.min(START_Y, DesiredPanelTop))

	layout.panelPaddingY = BASE_PANEL_PADDING_Y

	local PanelPaddingY = layout.panelPaddingY
	local SummaryInsetX = math.max(28, PanelPaddingX)
	layout.summaryInsetX = SummaryInsetX

	local SummaryVerticalPadding = math.max(SUMMARY_PANEL_TOP_PADDING_MIN, PanelPaddingY * 0.35)
	local SummaryTopPadding = SummaryVerticalPadding
	local SummaryBottomPadding = math.max(SUMMARY_PANEL_BOTTOM_PADDING_MIN, SummaryVerticalPadding)

	local SummaryPanel = {
		x = PanelX,
		y = ContainerTop,
		width = layout.panelWidth,
		TopPadding = SummaryTopPadding,
		BottomPadding = SummaryBottomPadding,
	}

	local ProgressHeight = SUMMARY_PROGRESS_BAR_HEIGHT
	local SummaryLineHeight = UI.fonts.achieve:GetHeight()
	local SummaryProgressSpacing = SUMMARY_SPACING_TEXT_PROGRESS

	layout.summaryLineHeight = SummaryLineHeight
	layout.summaryProgressHeight = ProgressHeight

	local SummaryContentHeight = SummaryLineHeight + SummaryProgressSpacing + ProgressHeight
	local SummaryHeight = SummaryTopPadding + SummaryContentHeight + SummaryBottomPadding

	SummaryPanel.height = SummaryHeight
	layout.summaryPanel = SummaryPanel

	layout.summaryTextX = PanelX + SummaryInsetX
	layout.summaryTextWidth = layout.panelWidth - SummaryInsetX * 2
	layout.summaryTextY = SummaryPanel.y + SummaryTopPadding
	layout.summaryProgressY = layout.summaryTextY + SummaryLineHeight + SummaryProgressSpacing

	local HighlightInsetX = math.max(SUMMARY_HIGHLIGHT_INSET, SummaryInsetX * 0.6)
	local HighlightInsetY = math.max(SUMMARY_HIGHLIGHT_INSET, math.min(SummaryTopPadding, SummaryBottomPadding) * 0.75)
	layout.summaryHighlightInset = { x = HighlightInsetX, y = HighlightInsetY }

	local TitleClearance = TitleY + TitleFontHeight + math.max(24, sh * 0.03)
	local SummaryTop = SummaryPanel.y - SummaryTopPadding
	if SummaryTop < TitleClearance then
		local adjustment = TitleClearance - SummaryTop
		SummaryPanel.y = SummaryPanel.y + adjustment
		layout.summaryTextY = layout.summaryTextY + adjustment
		layout.summaryProgressY = layout.summaryProgressY + adjustment
	end

	local PanelGap = math.max(SUMMARY_PANEL_GAP_MIN, PanelPaddingY * 0.35)
	layout.panelGap = PanelGap

	local ListPanelY = SummaryPanel.y + SummaryPanel.height + PanelGap
	layout.panelY = ListPanelY

	local FooterReserve = (UI.spacing.ButtonHeight or 0) + (UI.spacing.ButtonSpacing or 0) + ((UI.scaled and UI.scaled(48, 32)) or 48)
	local BottomMargin = math.max(80, math.min(120, sh * 0.16))
	BottomMargin = math.max(BottomMargin, FooterReserve)
	layout.bottomMargin = BottomMargin

	layout.viewportBottom = sh - BottomMargin
	layout.startY = ListPanelY + PanelPaddingY
	layout.viewportHeight = math.max(0, layout.viewportBottom - layout.startY)

	layout.panelHeight = layout.viewportHeight + PanelPaddingY * 2
	layout.scissorTop = math.max(0, layout.startY - SCROLL_SCISSOR_TOP_PADDING)
	layout.scissorBottom = layout.viewportBottom
	layout.scissorHeight = math.max(0, layout.scissorBottom - layout.scissorTop)

	return layout
end

local function DrawThumbSnake(TrackX, TrackY, TrackWidth, TrackHeight, ThumbY, ThumbHeight, IsHovered, IsThumbHovered)
	local trail, SegmentSize = BuildThumbSnakeTrail(TrackX, TrackY, TrackWidth, TrackHeight, ThumbY, ThumbHeight)
	if #trail < 2 then
		return
	end

	local SnakeR, SnakeG, SnakeB = unpack(Theme.SnakeDefault)
	local HighlightColor = Theme.HighlightColor or {1, 1, 1, 0.1}
	local TrackBase = Theme.PanelColor or {0.18, 0.18, 0.22, 0.9}
	local TrackColor = LightenColor(TrackBase, IsHovered and 0.45 or 0.35)
	local TrackAlpha = (TrackColor[4] or 1) * (IsHovered and 0.75 or 0.55)

	love.graphics.push("all")

	local TrackRadius = math.max(8, SegmentSize * 0.55)
	love.graphics.setColor(TrackColor[1], TrackColor[2], TrackColor[3], TrackAlpha)
	love.graphics.rectangle("fill", TrackX, TrackY, TrackWidth, TrackHeight, TrackRadius)

	local TrackOutline = Theme.PanelBorder or Theme.BorderColor or {0.5, 0.6, 0.75, 1}
	local OutlineAlpha = (TrackOutline[4] or 1) * (IsHovered and 0.9 or 0.55)
	love.graphics.setColor(TrackOutline[1], TrackOutline[2], TrackOutline[3], OutlineAlpha)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", TrackX, TrackY, TrackWidth, TrackHeight, TrackRadius)

	local ThumbHighlight = HighlightColor
	if IsThumbHovered then
		ThumbHighlight = LightenColor(HighlightColor, 0.35)
	elseif IsHovered then
		ThumbHighlight = LightenColor(HighlightColor, 0.18)
	end

	local hr = ThumbHighlight[1] or SnakeR
	local hg = ThumbHighlight[2] or SnakeG
	local hb = ThumbHighlight[3] or SnakeB
	local ha = ThumbHighlight[4] or 0.12
	if IsThumbHovered then
		ha = math.min(1, ha + 0.28)
	elseif IsHovered then
		ha = math.min(1, ha + 0.15)
	end

	local HighlightInsetX = math.max(4, (TrackWidth - SegmentSize) * 0.35)
	local HighlightInsetY = math.max(6, SegmentSize * 0.45)
	local HighlightX = TrackX + HighlightInsetX
	local HighlightY = ThumbY + HighlightInsetY
	local HighlightW = math.max(0, TrackWidth - HighlightInsetX * 2)
	local HighlightH = math.max(0, ThumbHeight - HighlightInsetY * 2)
	love.graphics.setColor(hr, hg, hb, ha)
	love.graphics.rectangle("fill", HighlightX, HighlightY, HighlightW, HighlightH, SegmentSize * 0.45)

	local OutlinePad = math.max(10, SegmentSize)
	local ScissorX = TrackX - OutlinePad
	local ScissorY = TrackY - OutlinePad
	local ScissorW = TrackWidth + OutlinePad * 2
	local ScissorH = TrackHeight + OutlinePad * 2
	love.graphics.setScissor(ScissorX, ScissorY, ScissorW, ScissorH)

	love.graphics.setColor(1, 1, 1, 1)
	SnakeDraw.run(trail, #trail, SegmentSize, nil, nil, nil, nil, nil)

	local head = trail[#trail]
	if head then
		local HeadRadius = SegmentSize * 0.32
		local EyeOffset = HeadRadius * 0.55
		local EyeRadius = math.max(1, HeadRadius * 0.22)

		love.graphics.setColor(1, 1, 1, 0.9)
		love.graphics.circle("fill", head.x - EyeOffset, head.y - EyeRadius * 0.4, EyeRadius)
		love.graphics.circle("fill", head.x + EyeOffset, head.y - EyeRadius * 0.4, EyeRadius)

		love.graphics.setColor(0.05, 0.05, 0.05, 0.85)
		love.graphics.circle("fill", head.x - EyeOffset, head.y - EyeRadius * 0.3, EyeRadius * 0.45)
		love.graphics.circle("fill", head.x + EyeOffset, head.y - EyeRadius * 0.3, EyeRadius * 0.45)
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

local function UpdateScrollBounds(sw, sh, layout)
	layout = layout or ComputeLayout(sw, sh)

	ViewportHeight = layout.viewportHeight

	local y = layout.startY
	local MaxBottom = layout.startY

	if DisplayBlocks then
		for _, block in ipairs(DisplayBlocks) do
			if block.achievements then
				for _ in ipairs(block.achievements) do
					MaxBottom = math.max(MaxBottom, y + CARD_HEIGHT)
					y = y + CARD_SPACING
				end
			end
			y = y + CATEGORY_SPACING
		end
	end

	ContentHeight = math.max(0, MaxBottom - layout.startY)
	MinScrollOffset = math.min(0, ViewportHeight - ContentHeight)

	if ScrollOffset < MinScrollOffset then
		ScrollOffset = MinScrollOffset
	elseif ScrollOffset > 0 then
		ScrollOffset = 0
	end

	return layout
end

local function ScrollBy(amount)
	if amount == 0 then
		return
	end

	ScrollOffset = ScrollOffset + amount

	local sw, sh = Screen:get()
	UpdateScrollBounds(sw, sh)
end

local function DpadScrollUp()
	ScrollBy(DPAD_SCROLL_AMOUNT)
	ButtonList:moveFocus(-1)
end

local function DpadScrollDown()
	ScrollBy(-DPAD_SCROLL_AMOUNT)
	ButtonList:moveFocus(1)
end

local AnalogDirections = {
	dpup = { id = "analog_dpup", repeatable = true, action = DpadScrollUp },
	dpdown = { id = "analog_dpdown", repeatable = true, action = DpadScrollDown },
	dpleft = {
		id = "analog_dpleft",
		repeatable = false,
		action = function()
			ButtonList:moveFocus(-1)
		end,
	},
	dpright = {
		id = "analog_dpright",
		repeatable = false,
		action = function()
			ButtonList:moveFocus(1)
		end,
	},
}

local AnalogAxisMap = {
	leftx = { slot = "horizontal", negative = AnalogDirections.dpleft, positive = AnalogDirections.dpright },
	rightx = { slot = "horizontal", negative = AnalogDirections.dpleft, positive = AnalogDirections.dpright },
	lefty = { slot = "vertical", negative = AnalogDirections.dpup, positive = AnalogDirections.dpdown },
	righty = { slot = "vertical", negative = AnalogDirections.dpup, positive = AnalogDirections.dpdown },
	[1] = { slot = "horizontal", negative = AnalogDirections.dpleft, positive = AnalogDirections.dpright },
	[2] = { slot = "vertical", negative = AnalogDirections.dpup, positive = AnalogDirections.dpdown },
}

local function ActivateAnalogDirection(direction)
	if not direction then
		return
	end

	direction.action()

	if direction.repeatable then
		StartHeldDpad(direction.id, direction.action)
	end
end

local function ResetAnalogDirections()
	for slot, direction in pairs(AnalogAxisDirections) do
		if direction and direction.repeatable then
			StopHeldDpad(direction.id)
		end
		AnalogAxisDirections[slot] = nil
	end
end

local function HandleGamepadAxis(axis, value)
	local mapping = AnalogAxisMap[axis]
	if not mapping then
		return
	end

	local previous = AnalogAxisDirections[mapping.slot]
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
		StopHeldDpad(previous.id)
	end

	AnalogAxisDirections[mapping.slot] = direction or nil

	ActivateAnalogDirection(direction)
end

function AchievementsMenu:enter()
	Screen:update()
	UI.ClearButtons()

	local sw, sh = Screen:get()

	ConfigureBackgroundEffect()

	ScrollOffset = 0
	MinScrollOffset = 0
	ResetAnalogDirections()

	Face:set("idle")

	ButtonList:reset({
		{
			id = "AchievementsBack",
			x = sw / 2 - UI.spacing.ButtonWidth / 2,
			y = sh - 80,
			w = UI.spacing.ButtonWidth,
			h = UI.spacing.ButtonHeight,
			TextKey = "achievements.back_to_menu",
			text = Localization:get("achievements.back_to_menu"),
			action = "menu",
		},
	})

	IconCache = {}
	DisplayBlocks = Achievements:GetDisplayOrder()
	RebuildAchievementRewards()

	ResetHeldDpad()

	local function LoadIcon(path)
		local ok, image = pcall(love.graphics.newImage, path)
		if ok then
			return image
		end
		return nil
	end

	IconCache.__default = LoadIcon("Assets/Achievements/Default.png")

	UpdateScrollBounds(sw, sh)

	for _, block in ipairs(DisplayBlocks) do
		for _, ach in ipairs(block.achievements) do
			local IconName = ach.icon or "Default"
			local path = string.format("Assets/Achievements/%s.png", IconName)
			if not love.filesystem.getInfo(path) then
				path = "Assets/Achievements/Default.png"
			end
			if not IconCache[ach.id] then
				IconCache[ach.id] = LoadIcon(path)
			end
		end
	end
end

function AchievementsMenu:update(dt)
	local mx, my = love.mouse.getPosition()
	ButtonList:updateHover(mx, my)
	Face:update(dt)
	UpdateHeldDpad(dt)
end

function AchievementsMenu:draw()
	local sw, sh = Screen:get()
	DrawBackground(sw, sh)

	if not DisplayBlocks or #DisplayBlocks == 0 then
		DisplayBlocks = Achievements:GetDisplayOrder()
	end

	local layout = ComputeLayout(sw, sh)
	layout = UpdateScrollBounds(sw, sh, layout)

	local TitleFont = UI.fonts.title
	love.graphics.setFont(TitleFont)
	local TitleColor = Theme.TextColor or {1, 1, 1, 1}
	love.graphics.setColor(TitleColor)
	love.graphics.printf(Localization:get("achievements.title"), 0, layout.titleY, sw, "center")

	local StartY = layout.startY
	local spacing = CARD_SPACING
	local CardWidth = layout.cardWidth
	local CardHeight = CARD_HEIGHT
	local CategorySpacing = CATEGORY_SPACING

	local ListX = layout.listX
	local PanelPaddingX = layout.panelPaddingX
	local PanelPaddingY = layout.panelPaddingY
	local PanelX = layout.panelX
	local PanelY = layout.panelY
	local PanelWidth = layout.panelWidth
	local PanelHeight = layout.panelHeight
	local PanelColor = Theme.PanelColor or {0.18, 0.18, 0.22, 0.9}
	local PanelBorder = Theme.PanelBorder or Theme.BorderColor or {0.5, 0.6, 0.75, 1}
	local ShadowColor = Theme.ShadowColor or {0, 0, 0, 0.35}
	local HighlightColor = Theme.HighlightColor or {1, 1, 1, 0.06}
	local SummaryPanel = layout.summaryPanel
	local SummaryTextX = layout.summaryTextX
	local SummaryTextY = layout.summaryTextY
	local SummaryTextWidth = layout.summaryTextWidth
	local SummaryProgressHeight = layout.summaryProgressHeight
	local SummaryLineHeight = layout.summaryLineHeight or UI.fonts.achieve:GetHeight()

	love.graphics.push("all")
	UI.DrawPanel(SummaryPanel.x, SummaryPanel.y, SummaryPanel.width, SummaryPanel.height, {
		radius = 24,
		fill = PanelColor,
		alpha = 0.95,
		BorderColor = PanelBorder,
		BorderWidth = 2,
		highlight = false,
		ShadowColor = WithAlpha(ShadowColor, (ShadowColor[4] or 0.35) * 0.85),
	})

	local HighlightInset = layout.summaryHighlightInset or { x = SUMMARY_HIGHLIGHT_INSET, y = SUMMARY_HIGHLIGHT_INSET }
	local HighlightInsetX = math.min(SummaryPanel.width * 0.25, HighlightInset.x or SUMMARY_HIGHLIGHT_INSET)
	local HighlightInsetY = HighlightInset.y or SUMMARY_HIGHLIGHT_INSET
	local MaxHighlightInsetX = math.max(0, (SummaryPanel.width - 2) * 0.5)
	local MaxHighlightInsetY = math.max(0, (SummaryPanel.height - 2) * 0.5)
	HighlightInsetX = math.max(0, math.min(HighlightInsetX, MaxHighlightInsetX))
	HighlightInsetY = math.max(0, math.min(HighlightInsetY, MaxHighlightInsetY))
	local HighlightX = SummaryPanel.x + HighlightInsetX
	local HighlightY = SummaryPanel.y + HighlightInsetY
	local HighlightW = math.max(0, SummaryPanel.width - HighlightInsetX * 2)
	local HighlightH = math.max(0, SummaryPanel.height - HighlightInsetY * 2)
	if HighlightW > 0 and HighlightH > 0 then
		love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], (HighlightColor[4] or 0.08) * 1.1)
		love.graphics.rectangle("fill", HighlightX, HighlightY, HighlightW, HighlightH, 18, 18)
	end
	love.graphics.pop()

	local totals = Achievements:GetTotals()
	local UnlockedLabel = Localization:get("achievements.summary.unlocked", {
		unlocked = totals.unlocked,
		total = totals.total,
	})
	local CompletionPercent = ToPercent(totals.completion)
	local CompletionLabel = Localization:get("achievements.summary.completion", {
		percent = CompletionPercent,
	})
	local AchieveFont = UI.fonts.achieve

	love.graphics.setFont(AchieveFont)
	love.graphics.setColor(TitleColor)
	love.graphics.printf(UnlockedLabel, SummaryTextX, SummaryTextY, SummaryTextWidth, "left")
	love.graphics.printf(CompletionLabel, SummaryTextX, SummaryTextY, SummaryTextWidth, "right")

	local ProgressBarY = layout.summaryProgressY
	love.graphics.setColor(DarkenColor(PanelColor, 0.4))
	love.graphics.rectangle("fill", SummaryTextX, ProgressBarY, SummaryTextWidth, SummaryProgressHeight, 6, 6)

	love.graphics.setColor(Theme.ProgressColor or {0.6, 0.9, 0.4, 1})
	love.graphics.rectangle("fill", SummaryTextX, ProgressBarY, SummaryTextWidth * clamp01(totals.completion), SummaryProgressHeight, 6, 6)

	love.graphics.push("all")
	UI.DrawPanel(PanelX, PanelY, PanelWidth, PanelHeight, {
		radius = 28,
		fill = PanelColor,
		alpha = 0.95,
		BorderColor = PanelBorder,
		BorderWidth = 2,
		highlight = false,
		ShadowColor = WithAlpha(ShadowColor, (ShadowColor[4] or 0.35) * 0.9),
	})
	love.graphics.pop()

	local ScissorTop = layout.scissorTop
	local ScissorBottom = layout.scissorBottom
	local ScissorHeight = layout.scissorHeight
	love.graphics.setScissor(0, ScissorTop, sw, ScissorHeight)

	love.graphics.push()
	love.graphics.translate(0, ScrollOffset)

	local y = StartY
	for _, block in ipairs(DisplayBlocks) do
		local CategoryLabel = Localization:get("achievements.categories." .. block.id)
		love.graphics.setFont(UI.fonts.button)
		love.graphics.setColor(TitleColor[1], TitleColor[2], TitleColor[3], (TitleColor[4] or 1) * 0.85)
		love.graphics.printf(CategoryLabel, 0, y - 32, sw, "center")

		for _, ach in ipairs(block.achievements) do
			local unlocked = ach.unlocked
			local goal = ach.goal or 0
			local HiddenLocked = ach.hidden and not unlocked
			local HasProgress = (not HiddenLocked) and goal > 0
			local icon = HiddenLocked and IconCache.__default or IconCache[ach.id]
			if not icon then
				icon = IconCache.__default
			end
			local x = ListX
			local BarW = math.max(0, CardWidth - 120)
			local CardY = y

			local CardBase = unlocked and LightenColor(PanelColor, 0.18) or DarkenColor(PanelColor, 0.08)
			if HiddenLocked then
				CardBase = DarkenColor(PanelColor, 0.2)
			end

			local AccentBorder = Theme.BorderColor or PanelBorder
			local BorderTint
			if unlocked then
				BorderTint = LightenColor(AccentBorder, 0.2)
			elseif HiddenLocked then
				BorderTint = DarkenColor(PanelBorder, 0.15)
			else
				BorderTint = Theme.PanelBorder or AccentBorder
			end

			love.graphics.push("all")
			UI.DrawPanel(x, CardY, CardWidth, CardHeight, {
				radius = 18,
				fill = CardBase,
				BorderColor = BorderTint,
				BorderWidth = 2,
				highlight = false,
				ShadowColor = WithAlpha(ShadowColor, (ShadowColor[4] or 0.3) * 0.9),
			})
			love.graphics.pop()

			if icon then
				local IconX, IconY = x + 16, CardY + 18
				local ScaleX = 56 / icon:getWidth()
				local ScaleY = 56 / icon:getHeight()
				local tint = unlocked and 1 or 0.55
				love.graphics.setColor(tint, tint, tint, 1)
				love.graphics.draw(icon, IconX, IconY, 0, ScaleX, ScaleY)

				local IconBorder = HiddenLocked and DarkenColor(BorderTint, 0.35) or BorderTint
				love.graphics.setColor(IconBorder)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", IconX - 2, IconY - 2, 60, 60, 8)
			end

			local TextX = x + 96

			local TitleText
			local DescriptionText
			if HiddenLocked then
				TitleText = Localization:get("achievements.hidden.title")
				DescriptionText = Localization:get("achievements.hidden.description")
			else
				TitleText = Localization:get(ach.titleKey)
				DescriptionText = Localization:get(ach.descriptionKey)
			end

			love.graphics.setFont(UI.fonts.achieve)
			love.graphics.setColor(TitleColor)
			love.graphics.printf(TitleText, TextX, CardY + 10, CardWidth - 110, "left")

			love.graphics.setFont(UI.fonts.body)
			local BodyColor = WithAlpha(TitleColor, (TitleColor[4] or 1) * 0.8)
			love.graphics.setColor(BodyColor)
			local TextWidth = CardWidth - 110
			love.graphics.printf(DescriptionText, TextX, CardY + 38, TextWidth, "left")

			local RewardText = nil
			if not HiddenLocked then
				RewardText = GetAchievementRewardLabel(ach)
			end

			local BarH = 12
			local BarX = TextX
			local BarY = CardY + CardHeight - 24

			if RewardText and RewardText ~= "" then
				love.graphics.setFont(UI.fonts.small)
				love.graphics.setColor(WithAlpha(TitleColor, (TitleColor[4] or 1) * 0.72))
				local RewardY = BarY - (HasProgress and 36 or 24)
				love.graphics.printf(RewardText, TextX, RewardY, TextWidth, "left")
			end

			if HasProgress then
				local ratio = Achievements:GetProgressRatio(ach)

				love.graphics.setColor(DarkenColor(CardBase, 0.45))
				love.graphics.rectangle("fill", BarX, BarY, BarW, BarH, 6)

				love.graphics.setColor(Theme.ProgressColor)
				love.graphics.rectangle("fill", BarX, BarY, BarW * ratio, BarH, 6)

				local ProgressLabel = Achievements:GetProgressLabel(ach)
				if ProgressLabel then
					love.graphics.setFont(UI.fonts.small)
					love.graphics.setColor(WithAlpha(TitleColor, (TitleColor[4] or 1) * 0.9))
					love.graphics.printf(ProgressLabel, BarX, BarY - 18, BarW, "right")
				end
			end

			y = y + spacing
		end

		y = y + CategorySpacing
	end

	love.graphics.pop()
	love.graphics.setScissor()

	if ContentHeight > ViewportHeight then
		local TrackWidth = SCROLLBAR_TRACK_WIDTH
		local TrackInset = math.max(MIN_SCROLLBAR_INSET, PanelPaddingX * 0.5)
		local TrackX = PanelX + PanelWidth + TrackInset
		local TrackY = StartY
		local TrackHeight = ViewportHeight

		local ScrollRange = -MinScrollOffset
		local ScrollProgress = ScrollRange > 0 and (-ScrollOffset / ScrollRange) or 0

		local MinThumbHeight = 36
		local ThumbHeight = math.max(MinThumbHeight, ViewportHeight * (ViewportHeight / ContentHeight))
		ThumbHeight = math.min(ThumbHeight, TrackHeight)
		local ThumbY = TrackY + (TrackHeight - ThumbHeight) * ScrollProgress

		local mx, my = love.mouse.getPosition()
		local IsOverScrollbar = mx >= TrackX and mx <= TrackX + TrackWidth and my >= TrackY and my <= TrackY + TrackHeight
		local IsOverThumb = IsOverScrollbar and my >= ThumbY and my <= ThumbY + ThumbHeight

		DrawThumbSnake(TrackX, TrackY, TrackWidth, TrackHeight, ThumbY, ThumbHeight, IsOverScrollbar, IsOverThumb)
	end

	for _, btn in ButtonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	ButtonList:draw()
end

function AchievementsMenu:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function AchievementsMenu:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
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

	ScrollBy(dy * SCROLL_SPEED)
end

function AchievementsMenu:keypressed(key)
	if key == "up" then
		ScrollBy(DPAD_SCROLL_AMOUNT)
		ButtonList:moveFocus(-1)
	elseif key == "down" then
		ScrollBy(-DPAD_SCROLL_AMOUNT)
		ButtonList:moveFocus(1)
	elseif key == "left" then
		ButtonList:moveFocus(-1)
	elseif key == "right" then
		ButtonList:moveFocus(1)
	elseif key == "pageup" then
		local PageStep = DPAD_SCROLL_AMOUNT * math.max(1, math.floor(ViewportHeight / CARD_SPACING))
		ScrollBy(PageStep)
	elseif key == "pagedown" then
		local PageStep = DPAD_SCROLL_AMOUNT * math.max(1, math.floor(ViewportHeight / CARD_SPACING))
		ScrollBy(-PageStep)
	elseif key == "home" then
		ScrollBy(-ScrollOffset)
	elseif key == "end" then
		ScrollBy(MinScrollOffset - ScrollOffset)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		local action = ButtonList:activateFocused()
		if action then
			Audio:PlaySound("click")
		end
		return action
	elseif key == "escape" or key == "backspace" then
		local action = ButtonList:activateFocused() or "menu"
		if action then
			Audio:PlaySound("click")
		end
		return action
	end
end

function AchievementsMenu:gamepadpressed(_, button)
	if button == "dpup" then
		DpadScrollUp()
		StartHeldDpad(button, DpadScrollUp)
	elseif button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" then
		DpadScrollDown()
		StartHeldDpad(button, DpadScrollDown)
	elseif button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "leftshoulder" then
		ScrollBy(DPAD_SCROLL_AMOUNT * math.max(1, math.floor(ViewportHeight / CARD_SPACING)))
	elseif button == "rightshoulder" then
		ScrollBy(-DPAD_SCROLL_AMOUNT * math.max(1, math.floor(ViewportHeight / CARD_SPACING)))
	elseif button == "a" or button == "start" or button == "b" then
		local action = ButtonList:activateFocused()
		if action then
			Audio:PlaySound("click")
		end
		return action
	end
end

AchievementsMenu.joystickpressed = AchievementsMenu.gamepadpressed

function AchievementsMenu:gamepadaxis(_, axis, value)
	HandleGamepadAxis(axis, value)
end

AchievementsMenu.joystickaxis = AchievementsMenu.gamepadaxis

function AchievementsMenu:gamepadreleased(_, button)
	if button == "dpup" or button == "dpdown" then
		StopHeldDpad(button)
	end
end

AchievementsMenu.joystickreleased = AchievementsMenu.gamepadreleased

return AchievementsMenu
