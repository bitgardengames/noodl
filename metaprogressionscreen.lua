local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local SnakeCosmetics = require("snakecosmetics")
local Achievements = require("achievements")
local PlayerStats = require("playerstats")
local Audio = require("audio")
local Shaders = require("shaders")

local ProgressionScreen = {
	TransitionDuration = 0.45,
}

local ButtonList = ButtonList.new()

local CARD_WIDTH = 640
local CARD_SPACING = 24
local TRACK_CARD_MIN_HEIGHT = 188
local STAT_CARD_HEIGHT = 72
local STAT_CARD_SPACING = 16
local STAT_CARD_SHADOW_OFFSET = 6
local STATS_SUMMARY_CARD_WIDTH = 216
local STATS_SUMMARY_CARD_HEIGHT = 96
local STATS_SUMMARY_CARD_SPACING = 20
local STATS_SUMMARY_SHADOW_OFFSET = 6
local STATS_SUMMARY_SPACING = 32
local COSMETIC_CARD_HEIGHT = 148
local COSMETIC_CARD_SPACING = 24
local COSMETIC_PREVIEW_WIDTH = 128
local COSMETIC_PREVIEW_HEIGHT = 40
local SCROLL_SPEED = 48
local DPAD_REPEAT_INITIAL_DELAY = 0.3
local DPAD_REPEAT_INTERVAL = 0.1
local ANALOG_DEADZONE = 0.35
local TAB_WIDTH = 220
local TAB_HEIGHT = 52
local TAB_SPACING = 16
local TAB_Y = 160
local TAB_BOTTOM = TAB_Y + TAB_HEIGHT
local TAB_CONTENT_GAP = 48
local DEFAULT_LIST_TOP = TAB_BOTTOM + TAB_CONTENT_GAP
local SUMMARY_CONTENT_HEIGHT = 160
local EXPERIENCE_SUMMARY_TOP = DEFAULT_LIST_TOP
local EXPERIENCE_LIST_GAP = 24
local WINDOW_CORNER_RADIUS = 18
local WINDOW_SHADOW_OFFSET = 10
local WINDOW_PADDING_X = 28
local WINDOW_PADDING_Y = 24
local EXPERIENCE_LIST_TOP = EXPERIENCE_SUMMARY_TOP + SUMMARY_CONTENT_HEIGHT + WINDOW_PADDING_Y + EXPERIENCE_LIST_GAP
local WINDOW_ACCENT_HEIGHT = 8

local ScrollOffset = 0
local MinScrollOffset = 0
local ViewportTop = DEFAULT_LIST_TOP
local ViewportHeight = 0
local ContentHeight = 0

local HeldDpadButton = nil
local HeldDpadAction = nil
local HeldDpadTimer = 0
local HeldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local TrackEntries = {}
local TrackContentHeight = 0
local StatsEntries = {}
local StatsHighlights = {}
local StatsSummaryHeight = 0
local CosmeticsEntries = {}
local CosmeticsSummary = { unlocked = 0, total = 0, NewUnlocks = 0 }
local ProgressionState = nil
local ActiveTab = "experience"
local CosmeticsFocusIndex = nil
local HoveredCosmeticIndex = nil
local PressedCosmeticIndex = nil

local tabs = {
	{
		id = "experience",
		action = "tab_experience",
		LabelKey = "metaprogression.tabs.experience",
	},
	{
		id = "cosmetics",
		action = "tab_cosmetics",
		LabelKey = "metaprogression.tabs.cosmetics",
	},
	{
		id = "stats",
		action = "tab_stats",
		LabelKey = "metaprogression.tabs.stats",
	},
}

local BACKGROUND_EFFECT_TYPE = "MetaFlux"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.6

	Shaders.configure(effect, {
		BgColor = Theme.BgColor,
		PrimaryColor = Theme.ProgressColor,
		SecondaryColor = Theme.AccentTextColor,
	})

	BackgroundEffect = effect
end

local function DrawBackground(sw, sh)
	love.graphics.setColor(Theme.BgColor or {0, 0, 0, 1})
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

local function GetListTop(tab)
	tab = tab or ActiveTab
	if tab == "experience" then
		return EXPERIENCE_LIST_TOP
	end

	return DEFAULT_LIST_TOP
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

local function GetActiveList()
	if ActiveTab == "cosmetics" then
		return CosmeticsEntries, COSMETIC_CARD_HEIGHT, COSMETIC_CARD_SPACING
	end

	if ActiveTab == "stats" then
		return StatsEntries, STAT_CARD_HEIGHT, STAT_CARD_SPACING
	end

	return TrackEntries, TRACK_CARD_MIN_HEIGHT, CARD_SPACING
end

local function GetScrollPadding()
	if ActiveTab == "cosmetics" then
		return COSMETIC_CARD_SPACING
	end

	return 0
end

local function UpdateScrollBounds(sw, sh)
	local ViewportBottom = sh - 140
	local TopOffset = 0
	if ActiveTab == "stats" then
		TopOffset = StatsSummaryHeight
		if TopOffset > 0 then
			TopOffset = TopOffset + STATS_SUMMARY_SPACING
		end
	end

	local BaseTop = GetListTop()
	ViewportTop = BaseTop + TopOffset
	ViewportHeight = math.max(0, ViewportBottom - ViewportTop)

	if ActiveTab == "experience" then
		ContentHeight = TrackContentHeight
	else
		local entries, ItemHeight, spacing = GetActiveList()
		local count = #entries
		if count > 0 then
			ContentHeight = count * ItemHeight + math.max(0, count - 1) * spacing
		else
			ContentHeight = 0
		end
	end

	local BottomPadding = GetScrollPadding()
	if BottomPadding > 0 and ContentHeight > 0 then
		ContentHeight = ContentHeight + BottomPadding
	end

	MinScrollOffset = math.min(0, ViewportHeight - ContentHeight)

	if ScrollOffset < MinScrollOffset then
		ScrollOffset = MinScrollOffset
	elseif ScrollOffset > 0 then
		ScrollOffset = 0
	end
end

local function FormatInteger(value)
	local rounded = math.floor((value or 0) + 0.5)
	local sign = rounded < 0 and "-" or ""
	local digits = tostring(math.abs(rounded))
	local formatted = digits
	local count

	while true do
		formatted, count = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if count == 0 then
			break
		end
	end

	return sign .. formatted
end

local function FormatStatValue(value)
	if type(value) == "number" then
		if math.abs(value - math.floor(value + 0.5)) < 0.0001 then
			return FormatInteger(value)
		end

		return string.format("%.2f", value)
	end

	if value == nil then
		return "0"
	end

	return tostring(value)
end

local function FormatDuration(seconds)
	local TotalSeconds = math.floor((seconds or 0) + 0.5)
	if TotalSeconds < 0 then
		TotalSeconds = 0
	end

	local hours = math.floor(TotalSeconds / 3600)
	local minutes = math.floor((TotalSeconds % 3600) / 60)
	local secs = TotalSeconds % 60

	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end

	return string.format("%ds", secs)
end

local StatFormatters = {
	TotalTimeAlive = FormatDuration,
	LongestRunDuration = FormatDuration,
	BestFloorClearTime = FormatDuration,
	LongestFloorClearTime = FormatDuration,
}

local HiddenStats = {
	AverageFloorClearTime = true,
	BestFruitPerMinute = true,
	AverageFruitPerMinute = true,
	DailyChallengesCompleted = true,
	MostUpgradesInRun = true,
}

local function IsHiddenStat(key)
	if not key or key == "" then
		return true
	end

	if HiddenStats[key] then
		return true
	end

	if type(key) ~= "string" then
		return true
	end

	if key:find("^DailyChallenge:") or key:find("^FunChallenge:") then
		return true
	end

	return false
end

local HighlightStatOrder = {
	"SnakeScore",
	"FloorsCleared",
	"TotalApplesEaten",
	"TotalTimeAlive",
}

local function PrettifyKey(key)
	if not key or key == "" then
		return ""
	end

	local label = key:gsub("(%l)(%u)", "%1 %2")
	label = label:gsub("_", " ")
	label = label:gsub("%s+", " ")
	label = label:gsub("^%l", string.upper)
	return label
end

local function BuildStatsEntries()
	StatsEntries = {}

	local LabelTable = Localization:GetTable("metaprogression.stat_labels") or {}
	local seen = {}

	for key, label in pairs(LabelTable) do
		if not IsHiddenStat(key) then
			local value = PlayerStats:get(key)
			local formatter = StatFormatters[key]
			StatsEntries[#StatsEntries + 1] = {
				id = key,
				label = label,
				value = value,
				ValueText = formatter and formatter(value) or FormatStatValue(value),
			}
			seen[key] = true
		end
	end

	for key, value in pairs(PlayerStats.data or {}) do
		if not seen[key] and not IsHiddenStat(key) then
			local label = PrettifyKey(key)
			local formatter = StatFormatters[key]
			StatsEntries[#StatsEntries + 1] = {
				id = key,
				label = label,
				value = value,
				ValueText = formatter and formatter(value) or FormatStatValue(value),
			}
		end
	end

	table.sort(StatsEntries, function(a, b)
		if a.label == b.label then
			return a.id < b.id
		end
		return a.label < b.label
	end)

	local function BuildStatsHighlights()
		StatsHighlights = {}
		StatsSummaryHeight = 0

		if #StatsEntries == 0 then
			return
		end

		local used = {}

		for _, StatId in ipairs(HighlightStatOrder) do
			for _, entry in ipairs(StatsEntries) do
				if entry.id == StatId and not used[entry] then
					StatsHighlights[#StatsHighlights + 1] = entry
					used[entry] = true
					break
				end
			end
		end

		local desired = math.min(4, #StatsEntries)
		local index = 1
		while #StatsHighlights < desired and index <= #StatsEntries do
			local candidate = StatsEntries[index]
			if not used[candidate] then
				StatsHighlights[#StatsHighlights + 1] = candidate
				used[candidate] = true
			end
			index = index + 1
		end

		if #StatsHighlights > 0 then
			StatsSummaryHeight = STATS_SUMMARY_CARD_HEIGHT + STATS_SUMMARY_SHADOW_OFFSET
		end
	end

	BuildStatsHighlights()
end

local function ClampColorComponent(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function LightenColor(color, amount)
	if type(color) ~= "table" then
		return {1, 1, 1, 1}
	end

	amount = ClampColorComponent(amount or 0)

	local r = ClampColorComponent((color[1] or 0) + (1 - (color[1] or 0)) * amount)
	local g = ClampColorComponent((color[2] or 0) + (1 - (color[2] or 0)) * amount)
	local b = ClampColorComponent((color[3] or 0) + (1 - (color[3] or 0)) * amount)
	local a = ClampColorComponent(color[4] or 1)

	return {r, g, b, a}
end

local function DarkenColor(color, amount)
	if type(color) ~= "table" then
		return {0, 0, 0, 1}
	end

	amount = ClampColorComponent(amount or 0)

	local scale = 1 - amount
	local r = ClampColorComponent((color[1] or 0) * scale)
	local g = ClampColorComponent((color[2] or 0) * scale)
	local b = ClampColorComponent((color[3] or 0) * scale)
	local a = ClampColorComponent(color[4] or 1)

	return {r, g, b, a}
end

local function WithAlpha(color, alpha)
	if type(color) ~= "table" then
		return {1, 1, 1, ClampColorComponent(alpha or 1)}
	end

	return {
		ClampColorComponent(color[1] or 1),
		ClampColorComponent(color[2] or 1),
		ClampColorComponent(color[3] or 1),
		ClampColorComponent(alpha or color[4] or 1),
	}
end

local function DrawWindowFrame(x, y, width, height, options)
	options = options or {}

	if not width or not height or width <= 0 or height <= 0 then
		return
	end

	local PanelColor = options.baseColor or Theme.PanelColor or {0.18, 0.18, 0.22, 0.92}
	local BorderColor = options.borderColor or Theme.PanelBorder or {0.35, 0.3, 0.5, 1}
	local AccentColor = options.accentColor or Theme.ProgressColor or Theme.AccentTextColor or Theme.TextColor or {1, 1, 1, 1}
	local ShadowColor = options.shadowColor or (UI.colors and UI.colors.shadow) or Theme.ShadowColor or {0, 0, 0, 0.45}
	local ShadowAlpha = options.shadowAlpha
	local BaseAlpha = options.baseAlpha or 0.94
	local BorderAlpha = options.borderAlpha or 0.85
	local AccentAlpha = options.accentAlpha or 0.28
	local AccentHeight = options.accentHeight or WINDOW_ACCENT_HEIGHT
	local AccentInsetX = options.accentInsetX or (WINDOW_PADDING_X * 0.6)
	local AccentInsetY = options.accentInsetY or (WINDOW_PADDING_Y * 0.35)

	local ShadowOffset = options.shadowOffset
	if ShadowOffset == nil then
		ShadowOffset = (UI.spacing and UI.spacing.ShadowOffset) or WINDOW_SHADOW_OFFSET
	end

	if ShadowOffset and ShadowOffset ~= 0 then
		love.graphics.setColor(WithAlpha(ShadowColor, ShadowAlpha))
		UI.DrawRoundedRect(x + ShadowOffset, y + ShadowOffset, width, height, WINDOW_CORNER_RADIUS + 2)
	end

	local fill = WithAlpha(PanelColor, BaseAlpha)
	love.graphics.setColor(fill)
	UI.DrawRoundedRect(x, y, width, height, WINDOW_CORNER_RADIUS)

	if AccentHeight and AccentHeight > 0 then
		local AccentWidth = math.max(0, width - AccentInsetX * 2)
		if AccentWidth > 0 and height - AccentInsetY * 2 > 0 then
			local AccentY = y + AccentInsetY
			local AccentX = x + AccentInsetX
			love.graphics.setColor(WithAlpha(AccentColor, AccentAlpha))
			UI.DrawRoundedRect(AccentX, AccentY, AccentWidth, math.min(AccentHeight, height - AccentInsetY * 2), math.max(4, AccentHeight / 2))
		end
	end

	love.graphics.setColor(WithAlpha(BorderColor, BorderAlpha))
	love.graphics.setLineWidth(options.borderWidth or 2)
	love.graphics.rectangle("line", x, y, width, height, WINDOW_CORNER_RADIUS, WINDOW_CORNER_RADIUS)
	love.graphics.setLineWidth(1)

	if options.overlay then
		options.overlay(x, y, width, height)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function RoundNearest(value)
	value = value or 0
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

local function FormatShopChoice(amount)
	if not amount or amount == 0 then
		return nil
	end

	local label = Localization:get("metaprogression.rewards.shop_extra_choice", { count = amount })
	if label == "metaprogression.rewards.shop_extra_choice" then
		local rounded = RoundNearest(amount)
		local noun = (math.abs(rounded) == 1) and "shop card option" or "shop card options"
		label = string.format("%+d %s", rounded, noun)
	end
	return label
end

local function DescribeUnlockTag(tag)
	if not tag then
		return nil
	end

	local NameKey = "metaprogression.rewards.unlock_tag_" .. tag
	local name = Localization:get(NameKey)
	if name == NameKey then
		name = tag:gsub("_", " ")
		name = name:gsub("^%l", string.upper)
	end

	local label = Localization:get("metaprogression.rewards.unlock_tag", { name = name })
	if label == "metaprogression.rewards.unlock_tag" then
		label = string.format("Unlocks %s", name)
	end
	return label
end

local function AnnotateTrackEntry(entry)
	if not entry then
		return
	end

	local rewards = {}
	local effects = entry.effects or {}
	if effects.shopExtraChoices and effects.shopExtraChoices ~= 0 then
		local reward = FormatShopChoice(effects.shopExtraChoices)
		if reward then
			rewards[#rewards + 1] = reward
		end
	end

	if type(entry.unlockTags) == "table" then
		for _, tag in ipairs(entry.unlockTags) do
			local reward = DescribeUnlockTag(tag)
			if reward then
				rewards[#rewards + 1] = reward
			end
		end
	end

	entry.rewards = rewards
end

local function MeasureTrackEntryHeight(entry)
	if not entry then
		return TRACK_CARD_MIN_HEIGHT
	end

	local WrapWidth = CARD_WIDTH - 48
	local desc = entry.description or ""
	local BodyFont = UI.fonts.body
	local DescHeight = 0
	if desc ~= "" then
		local _, wrapped = BodyFont:getWrap(desc, WrapWidth)
		local LineCount = math.max(1, #wrapped)
		DescHeight = LineCount * BodyFont:getHeight()
	end

	local rewards = entry.rewards or {}
	local RewardBlockHeight = 0
	if #rewards > 0 then
		local SmallFont = UI.fonts.small
		RewardBlockHeight = 6 + #rewards * SmallFont:getHeight()
	end

	local TextY = 20
	local DescY = TextY + 58

	local YCursor = DescY + DescHeight + RewardBlockHeight
	local RequiredHeight = YCursor + 12

	return math.max(TRACK_CARD_MIN_HEIGHT, math.ceil(RequiredHeight))
end

local function RecalculateTrackLayout()
	local offset = 0
	TrackContentHeight = 0

	for _, entry in ipairs(TrackEntries or {}) do
		local height = MeasureTrackEntryHeight(entry)
		entry.cardHeight = height
		entry.offset = offset
		offset = offset + height + CARD_SPACING
	end

	if offset > 0 then
		TrackContentHeight = offset - CARD_SPACING
	end
end

local function AnnotateTrackEntries()
	for _, entry in ipairs(TrackEntries or {}) do
		AnnotateTrackEntry(entry)
	end

	RecalculateTrackLayout()
end

local function ResolveAchievementName(id)
	if not id or not Achievements or not Achievements.GetDefinition then
		return PrettifyKey(id)
	end

	local definition = Achievements:GetDefinition(id)
	if not definition then
		return PrettifyKey(id)
	end

	if definition.titleKey then
		local title = Localization:get(definition.titleKey)
		if title and title ~= definition.titleKey then
			return title
		end
	end

	if definition.title and definition.title ~= "" then
		return definition.title
	end

	if definition.nameKey then
		local name = Localization:get(definition.nameKey)
		if name and name ~= definition.nameKey then
			return name
		end
	end

	if definition.name and definition.name ~= "" then
		return definition.name
	end

	return PrettifyKey(id)
end

local function GetSkinRequirementText(skin)
	local unlock = skin and skin.unlock or {}

	if unlock.level then
		return Localization:get("metaprogression.cosmetics.locked_level", { level = unlock.level })
	elseif unlock.achievement then
		local AchievementName = ResolveAchievementName(unlock.achievement)
		return Localization:get("metaprogression.cosmetics.locked_achievement", {
			name = AchievementName,
		})
	end

	return Localization:get("metaprogression.cosmetics.locked_generic")
end

local function ResolveSkinStatus(skin)
	if not skin then
		return "", "", Theme.TextColor
	end

	if skin.selected then
		return Localization:get("metaprogression.cosmetics.equipped"), nil, Theme.AccentTextColor or Theme.TextColor
	end

	if skin.unlocked then
		return Localization:get("metaprogression.status_unlocked"), Localization:get("metaprogression.cosmetics.equip_hint"), Theme.ProgressColor or Theme.TextColor
	end

	return Localization:get("metaprogression.cosmetics.locked_label"), GetSkinRequirementText(skin), Theme.LockedCardColor or Theme.WarningColor or Theme.TextColor
end

local function BuildCosmeticsEntries()
	CosmeticsEntries = {}
	HoveredCosmeticIndex = nil
	PressedCosmeticIndex = nil
	CosmeticsFocusIndex = nil
	CosmeticsSummary.unlocked = 0
	CosmeticsSummary.total = 0
	CosmeticsSummary.newUnlocks = 0

	if not (SnakeCosmetics and SnakeCosmetics.GetSkins) then
		return
	end

	local skins = SnakeCosmetics:GetSkins() or {}
	local SelectedIndex
	local RecentlyUnlockedIds = {}

	for _, skin in ipairs(skins) do
		CosmeticsSummary.total = CosmeticsSummary.total + 1
		if skin.unlocked then
			CosmeticsSummary.unlocked = CosmeticsSummary.unlocked + 1
		end
		if skin.justUnlocked then
			CosmeticsSummary.newUnlocks = CosmeticsSummary.newUnlocks + 1
			RecentlyUnlockedIds[#RecentlyUnlockedIds + 1] = skin.id
		end

		local entry = {
			id = skin.id,
			skin = skin,
			JustUnlocked = skin.justUnlocked,
		}
		entry.statusLabel, entry.detailText, entry.statusColor = ResolveSkinStatus(skin)
		CosmeticsEntries[#CosmeticsEntries + 1] = entry

		if skin.selected then
			SelectedIndex = #CosmeticsEntries
		end
	end

	if CosmeticsSummary.newUnlocks > 0 and SnakeCosmetics and SnakeCosmetics.ClearRecentUnlocks then
		SnakeCosmetics:ClearRecentUnlocks(RecentlyUnlockedIds)
	end

	if SelectedIndex then
		CosmeticsFocusIndex = SelectedIndex
	elseif #CosmeticsEntries > 0 then
		CosmeticsFocusIndex = 1
	end
end

local function UpdateCosmeticsLayout(sw)
	if not sw then
		sw = select(1, Screen:get())
	end

	if not sw then
		return
	end

	local ListX = (sw - CARD_WIDTH) / 2
	local ListTop = GetListTop("cosmetics")

	for index, entry in ipairs(CosmeticsEntries) do
		local y = ListTop + ScrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
		entry.bounds = {
			x = ListX,
			y = y,
			w = CARD_WIDTH,
			h = COSMETIC_CARD_HEIGHT,
		}
	end
end

local function EnsureCosmeticVisible(index)
	if ActiveTab ~= "cosmetics" or not index then
		return
	end

	if ViewportHeight <= 0 then
		return
	end

	local ItemHeight = COSMETIC_CARD_HEIGHT
	local spacing = COSMETIC_CARD_SPACING
	local ListTop = GetListTop("cosmetics")
	local top = ListTop + ScrollOffset + (index - 1) * (ItemHeight + spacing)
	local bottom = top + ItemHeight
	local ViewportTop = GetListTop("cosmetics")
	local BottomPadding = GetScrollPadding()
	local ViewportBottom = ViewportTop + math.max(0, ViewportHeight - BottomPadding)

	if top < ViewportTop then
		ScrollOffset = ScrollOffset + (ViewportTop - top)
	elseif bottom > ViewportBottom then
		ScrollOffset = ScrollOffset - (bottom - ViewportBottom)
	end

	if ScrollOffset < MinScrollOffset then
		ScrollOffset = MinScrollOffset
	elseif ScrollOffset > 0 then
		ScrollOffset = 0
	end

	UpdateCosmeticsLayout()
end

local function SetCosmeticsFocus(index, PlaySound)
	if not index or not CosmeticsEntries[index] then
		return
	end

	if CosmeticsFocusIndex ~= index and PlaySound then
		Audio:PlaySound("hover")
	end

	CosmeticsFocusIndex = index
	EnsureCosmeticVisible(index)
end

local function MoveCosmeticsFocus(delta)
	if not delta or delta == 0 or #CosmeticsEntries == 0 then
		return
	end

	local index = CosmeticsFocusIndex or 1
	index = math.max(1, math.min(#CosmeticsEntries, index + delta))
	SetCosmeticsFocus(index, true)
end

local function ActivateCosmetic(index)
	local entry = index and CosmeticsEntries[index]
	if not entry or not entry.skin then
		return false
	end

	if not entry.skin.unlocked then
		return false
	end

	if not SnakeCosmetics or not SnakeCosmetics.SetActiveSkin then
		return false
	end

	local SkinId = entry.skin.id
	local changed = SnakeCosmetics:SetActiveSkin(SkinId)
	if changed then
		BuildCosmeticsEntries()
		local NewIndex
		for idx, cosmetic in ipairs(CosmeticsEntries) do
			if cosmetic.skin and cosmetic.skin.id == SkinId then
				NewIndex = idx
				break
			end
		end
		if NewIndex then
			SetCosmeticsFocus(NewIndex)
		end
		local sw, sh = Screen:get()
		if sw and sh then
			UpdateScrollBounds(sw, sh)
		end
	end

	return changed
end

local function FindTab(TargetId)
	for index, tab in ipairs(tabs) do
		if tab.id == TargetId then
			return tab, index
		end
	end

	return nil, nil
end

local function SetActiveTab(TabId, FocusOptions)
	if ActiveTab == TabId then
		return
	end

	ActiveTab = TabId

	if TabId == "stats" then
		BuildStatsEntries()
	elseif TabId == "cosmetics" then
		BuildCosmeticsEntries()
	else
		HoveredCosmeticIndex = nil
		PressedCosmeticIndex = nil
	end

	ScrollOffset = 0
	local sw, sh = Screen:get()
	if sw and sh then
		UpdateScrollBounds(sw, sh)
	end

	local _, ButtonIndex = FindTab(TabId)
	if ButtonIndex then
		local FocusSource = FocusOptions and FocusOptions.focusSource
		local SkipHistory = FocusOptions and FocusOptions.skipFocusHistory
		ButtonList:setFocus(ButtonIndex, FocusSource, SkipHistory)
	end

	if TabId == "cosmetics" and CosmeticsFocusIndex then
		EnsureCosmeticVisible(CosmeticsFocusIndex)
	end
end

local function ApplyFocusedTab(button)
	if not button then
		return
	end

	local action = button.action or button.id
	if action == "tab_experience" or action == "progressionTab_experience" then
		SetActiveTab("experience")
	elseif action == "tab_cosmetics" or action == "progressionTab_cosmetics" then
		SetActiveTab("cosmetics")
	elseif action == "tab_stats" or action == "progressionTab_stats" then
		SetActiveTab("stats")
	end
end

local function ScrollBy(amount)
	if amount == 0 then
		return
	end

	if ContentHeight <= ViewportHeight then
		ScrollOffset = 0
		return
	end

	ScrollOffset = ScrollOffset + amount
	if ScrollOffset < MinScrollOffset then
		ScrollOffset = MinScrollOffset
	elseif ScrollOffset > 0 then
		ScrollOffset = 0
	end
end

local function DpadScrollUp()
	if ActiveTab == "cosmetics" then
		MoveCosmeticsFocus(-1)
	else
		ScrollBy(SCROLL_SPEED)
		ApplyFocusedTab(ButtonList:moveFocus(-1))
	end
end

local function DpadScrollDown()
	if ActiveTab == "cosmetics" then
		MoveCosmeticsFocus(1)
	else
		ScrollBy(-SCROLL_SPEED)
		ApplyFocusedTab(ButtonList:moveFocus(1))
	end
end

local AnalogDirections = {
	dpup = { id = "analog_dpup", repeatable = true, action = DpadScrollUp },
	dpdown = { id = "analog_dpdown", repeatable = true, action = DpadScrollDown },
	dpleft = {
		id = "analog_dpleft",
		repeatable = false,
		action = function()
			ApplyFocusedTab(ButtonList:moveFocus(-1))
		end,
	},
	dpright = {
		id = "analog_dpright",
		repeatable = false,
		action = function()
			ApplyFocusedTab(ButtonList:moveFocus(1))
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

function ProgressionScreen:enter()
	Screen:update()
	UI.ClearButtons()

	ConfigureBackgroundEffect()

	TrackEntries = MetaProgression:GetUnlockTrack() or {}
	AnnotateTrackEntries()
	ProgressionState = MetaProgression:GetState()
	BuildStatsEntries()

	if SnakeCosmetics and SnakeCosmetics.load then
		local MetaLevel = ProgressionState and ProgressionState.level or nil
		local ok, err = pcall(function()
			SnakeCosmetics:load({ MetaLevel = MetaLevel })
		end)
		if not ok then
			print("[metaprogressionscreen] failed to load cosmetics:", err)
		end
	end

	BuildCosmeticsEntries()

	local sw, sh = Screen:get()

	local buttons = {}
	local TabCount = #tabs
	local TotalTabWidth = TabCount * TAB_WIDTH + math.max(0, TabCount - 1) * TAB_SPACING
	local StartX = sw / 2 - TotalTabWidth / 2

	for index, tab in ipairs(tabs) do
		local ButtonId = "progressionTab_" .. tab.id
		tab.buttonId = ButtonId
		local x = StartX + (index - 1) * (TAB_WIDTH + TAB_SPACING)

		buttons[#buttons + 1] = {
			id = ButtonId,
			x = x,
			y = TAB_Y,
			w = TAB_WIDTH,
			h = TAB_HEIGHT,
			text = Localization:get(tab.labelKey),
			action = tab.action,
		}
	end

	local BackButtonY = sh - 90

	buttons[#buttons + 1] = {
		id = "ProgressionBack",
		x = sw / 2 - UI.spacing.ButtonWidth / 2,
		y = BackButtonY,
		w = UI.spacing.ButtonWidth,
		h = UI.spacing.ButtonHeight,
		TextKey = "metaprogression.back_to_menu",
		text = Localization:get("metaprogression.back_to_menu"),
		action = "menu",
	}

	ButtonList:reset(buttons)

	local _, ActiveIndex = FindTab(ActiveTab)
	if ActiveIndex then
		ButtonList:setFocus(ActiveIndex, nil, true)
	end

	ScrollOffset = 0
	UpdateScrollBounds(sw, sh)
	ResetHeldDpad()
	ResetAnalogDirections()
end

function ProgressionScreen:leave()
	UI.ClearButtons()
	ResetHeldDpad()
	ResetAnalogDirections()
end

function ProgressionScreen:update(dt)
	local mx, my = love.mouse.getPosition()
	ButtonList:updateHover(mx, my)

	if ActiveTab == "cosmetics" then
		local sw = select(1, Screen:get())
		UpdateCosmeticsLayout(sw)

		HoveredCosmeticIndex = nil
		for index, entry in ipairs(CosmeticsEntries) do
			local bounds = entry.bounds
			if bounds and UI.IsHovered(bounds.x, bounds.y, bounds.w, bounds.h, mx, my) then
				HoveredCosmeticIndex = index
				break
			end
		end

		if HoveredCosmeticIndex and HoveredCosmeticIndex ~= CosmeticsFocusIndex then
			CosmeticsFocusIndex = HoveredCosmeticIndex
		end
	end

	UpdateHeldDpad(dt)
end

local function HandleConfirm()
	local action = ButtonList:activateFocused()
	if action then
		Audio:PlaySound("click")
		if action == "tab_experience" then
			SetActiveTab("experience")
		elseif action == "tab_cosmetics" then
			SetActiveTab("cosmetics")
		elseif action == "tab_stats" then
			SetActiveTab("stats")
		else
			return action
		end
	end
end

local function DrawSummaryPanel(sw)
	if not ProgressionState then
		return
	end

	local ContentWidth = CARD_WIDTH
	local ContentHeight = SUMMARY_CONTENT_HEIGHT
	local FrameWidth = ContentWidth + WINDOW_PADDING_X * 2
	local FrameHeight = ContentHeight + WINDOW_PADDING_Y * 2
	local FrameX = (sw - FrameWidth) / 2
	local FrameY = EXPERIENCE_SUMMARY_TOP - WINDOW_PADDING_Y
	local PanelX = FrameX + WINDOW_PADDING_X
	local PanelY = EXPERIENCE_SUMMARY_TOP
	local padding = 24
	local border = Theme.PanelBorder or {0.35, 0.3, 0.5, 1}
	local AccentColor = Theme.ProgressColor or Theme.AccentTextColor or {0.6, 0.8, 0.6, 1}
	local MutedColor = WithAlpha(Theme.MutedTextColor or Theme.TextColor, 0.85)

	DrawWindowFrame(FrameX, FrameY, FrameWidth, FrameHeight, {
		AccentHeight = 0,
		AccentInsetY = WINDOW_PADDING_Y * 0.5,
		AccentAlpha = 0.32,
	})

	local glow = WithAlpha(LightenColor(AccentColor, 0.45), 0.22)

	local LevelText = Localization:get("metaprogression.level_label", { level = ProgressionState.level or 1 })
	local TotalText = Localization:get("metaprogression.total_xp", { total = ProgressionState.totalExperience or 0 })

	local ProgressLabel
	local XpIntoLevel = ProgressionState.xpIntoLevel or 0
	local XpForNext = ProgressionState.xpForNext or 0
	local ProgressRatio = 1

	if XpForNext <= 0 then
		ProgressLabel = Localization:get("metaprogression.max_level")
		ProgressRatio = 1
	else
		local remaining = math.max(0, XpForNext - XpIntoLevel)
		ProgressLabel = Localization:get("metaprogression.next_unlock", { remaining = remaining })
		if XpForNext > 0 then
			ProgressRatio = math.min(1, math.max(0, XpIntoLevel / XpForNext))
		else
			ProgressRatio = 0
		end
	end

	local CircleRadius = 52
	local CircleCenterX = PanelX + padding + CircleRadius
	local CircleCenterY = PanelY + ContentHeight / 2
	local OuterRadius = CircleRadius + 8

	love.graphics.setColor(WithAlpha(DarkenColor(Theme.PanelColor or {0.18, 0.18, 0.22, 1}, 0.15), 0.92))
	love.graphics.circle("fill", CircleCenterX, CircleCenterY, OuterRadius)

	local ArcEndAngle = -math.pi / 2 + (math.pi * 2) * ProgressRatio

	love.graphics.setColor(WithAlpha(glow, 1))
	love.graphics.setLineWidth(8)
	love.graphics.arc("line", "open", CircleCenterX, CircleCenterY, OuterRadius, -math.pi / 2, ArcEndAngle)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(WithAlpha(LightenColor(Theme.PanelColor or {0.18, 0.18, 0.22, 1}, 0.18), 0.96))
	love.graphics.circle("fill", CircleCenterX, CircleCenterY, CircleRadius)

	love.graphics.setColor(WithAlpha(border, 0.85))
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", CircleCenterX, CircleCenterY, CircleRadius)
	love.graphics.setLineWidth(1)

	local LevelValue = FormatInteger(ProgressionState.level or 1)
	love.graphics.setFont(UI.fonts.timer)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.printf(LevelValue, CircleCenterX - CircleRadius, CircleCenterY - UI.fonts.timer:GetHeight() / 2 - 4, CircleRadius * 2, "center")

	local InfoX = CircleCenterX + CircleRadius + padding
	local InfoY = PanelY + padding

	love.graphics.setFont(UI.fonts.button)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.print(LevelText, InfoX, InfoY)
	InfoY = InfoY + UI.fonts.button:GetHeight() + 6

	love.graphics.setFont(UI.fonts.heading)
	love.graphics.setColor(WithAlpha(Theme.TextColor, 0.95))
	love.graphics.print(TotalText, InfoX, InfoY)
	InfoY = InfoY + UI.fonts.heading:GetHeight() + 4

	love.graphics.setFont(UI.fonts.body)
	love.graphics.setColor(WithAlpha(AccentColor, 0.95))
	love.graphics.print(ProgressLabel, InfoX, InfoY)
	InfoY = InfoY + UI.fonts.body:GetHeight() + 6

	if XpForNext > 0 then
		local ProgressText = string.format("%s / %s XP", FormatInteger(XpIntoLevel), FormatInteger(XpForNext))
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(MutedColor)
		love.graphics.print(ProgressText, InfoX, InfoY)
	else
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(MutedColor)
		love.graphics.print(Localization:get("metaprogression.max_level"), InfoX, InfoY)
	end

	local BarX = InfoX
	local BarY = PanelY + ContentHeight - padding - 24
	local BarWidth = ContentWidth - (BarX - PanelX) - padding
	local BarHeight = 18
	local BarRadius = math.min(9, BarHeight / 2)

	local function DrawRoundedSegment(x, y, width, height, radius)
		if width <= 0 or height <= 0 then
			return
		end

		local ClampedRadius = math.min(radius or 0, width / 2, height / 2)
		UI.DrawRoundedRect(x, y, width, height, ClampedRadius)
	end

	love.graphics.setColor(WithAlpha(DarkenColor(Theme.PanelColor or {0.18, 0.18, 0.22, 1}, 0.35), 0.92))
	DrawRoundedSegment(BarX, BarY, BarWidth, BarHeight, BarRadius)

	local FillWidth = math.max(0, BarWidth * ProgressRatio)
	if FillWidth > 0 then
		local FillColor = WithAlpha(LightenColor(AccentColor, 0.2), 0.95)
		love.graphics.setColor(FillColor)
		DrawRoundedSegment(BarX, BarY, FillWidth, BarHeight, BarRadius)

		love.graphics.setColor(WithAlpha(LightenColor(FillColor, 0.25), 0.55))
		DrawRoundedSegment(BarX, BarY, FillWidth, BarHeight * 0.55, BarRadius)
	end

	love.graphics.setColor(WithAlpha(border, 0.9))
	love.graphics.setLineWidth(1.6)
	love.graphics.rectangle("line", BarX, BarY, BarWidth, BarHeight, BarRadius, BarRadius)
	love.graphics.setLineWidth(1)

	if XpForNext > 0 then
		local percent = math.floor(ProgressRatio * 100 + 0.5)
		local BadgeText = string.format("%d%%", percent)
		love.graphics.setFont(UI.fonts.caption)
		local BadgePaddingX = 12
		local BadgePaddingY = 6
		local BadgeWidth = UI.fonts.caption:GetWidth(BadgeText) + BadgePaddingX * 2
		local BadgeHeight = UI.fonts.caption:GetHeight() + BadgePaddingY * 2
		local BadgeX = BarX + BarWidth - BadgeWidth
		local BadgeY = BarY - BadgeHeight - 6

		love.graphics.setColor(WithAlpha(LightenColor(Theme.PanelColor or {0.18, 0.18, 0.22, 1}, 0.12), 0.9))
		UI.DrawRoundedRect(BadgeX, BadgeY, BadgeWidth, BadgeHeight, BadgeHeight / 2)

		love.graphics.setColor(WithAlpha(AccentColor, 0.95))
		love.graphics.printf(BadgeText, BadgeX, BadgeY + BadgePaddingY - 2, BadgeWidth, "center")

		love.graphics.setColor(WithAlpha(glow, 0.7))
		love.graphics.circle("fill", BadgeX + BadgeWidth * 0.25, BadgeY + BadgeHeight * 0.35, 3)
		love.graphics.circle("fill", BadgeX + BadgeWidth * 0.72, BadgeY + BadgeHeight * 0.65, 2)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function DrawTrack(sw, sh)
	local ListX = (sw - CARD_WIDTH) / 2
	local ClipY = GetListTop("experience")
	local ClipH = ViewportHeight

	if ClipH <= 0 then
		return
	end

	local FrameX = ListX - WINDOW_PADDING_X
	local FrameY = ClipY - WINDOW_PADDING_Y
	local FrameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local FrameHeight = ClipH + WINDOW_PADDING_Y * 2
	DrawWindowFrame(FrameX, FrameY, FrameWidth, FrameHeight, {
		AccentHeight = 0,
		AccentInsetY = WINDOW_PADDING_Y * 0.5,
		AccentAlpha = 0.18,
	})

	love.graphics.push()
	love.graphics.setScissor(ListX - 20, ClipY - 10, CARD_WIDTH + 40, ClipH + 20)

	for index, entry in ipairs(TrackEntries) do
		local CardHeight = entry.cardHeight or TRACK_CARD_MIN_HEIGHT
		local offset = entry.offset or ((index - 1) * (TRACK_CARD_MIN_HEIGHT + CARD_SPACING))
		local y = ClipY + ScrollOffset + offset
		local VisibleThreshold = math.max(CardHeight, TRACK_CARD_MIN_HEIGHT)
		if y + CardHeight >= ClipY - VisibleThreshold and y <= ClipY + ClipH + VisibleThreshold then
			local unlocked = entry.unlocked
			local PanelColor = Theme.PanelColor or {0.18, 0.18, 0.22, 0.9}
			local FillAlpha = unlocked and 0.9 or 0.7

			love.graphics.setColor(PanelColor[1], PanelColor[2], PanelColor[3], FillAlpha)
			UI.DrawRoundedRect(ListX, y, CARD_WIDTH, CardHeight, 12)

			local BorderColor = unlocked and (Theme.AchieveColor or {0.55, 0.75, 0.55, 1}) or (Theme.LockedCardColor or {0.5, 0.35, 0.4, 1})
			love.graphics.setColor(BorderColor)
			love.graphics.setLineWidth(2)
			love.graphics.rectangle("line", ListX, y, CARD_WIDTH, CardHeight, 12, 12)

			local TextX = ListX + 24
			local TextY = y + 20

			love.graphics.setFont(UI.fonts.button)
			love.graphics.setColor(Theme.TextColor)
			local header = Localization:get("metaprogression.card_level", { level = entry.level or 0 })
			love.graphics.print(header, TextX, TextY)

			love.graphics.setFont(UI.fonts.body)
			love.graphics.print(entry.name or "", TextX, TextY + 30)

			local WrapWidth = CARD_WIDTH - 48
			love.graphics.setColor(Theme.TextColor)

			local desc = entry.description or ""
			local DescY = TextY + 58
			local DescHeight = 0
			if desc ~= "" then
				local _, wrapped = UI.fonts.body:GetWrap(desc, WrapWidth)
				local LineCount = math.max(1, #wrapped)
				DescHeight = LineCount * UI.fonts.body:GetHeight()
				love.graphics.setColor(Theme.TextColor)
				love.graphics.setFont(UI.fonts.body)
				love.graphics.printf(desc, TextX, DescY, WrapWidth)
			end

			local InfoY = DescY + DescHeight
			local rewards = entry.rewards or {}
			local SmallFont = UI.fonts.small
			local LineHeight = SmallFont:getHeight()

			if #rewards > 0 then
				InfoY = InfoY + 6
				love.graphics.setFont(SmallFont)
				local RewardColor = Theme.ProgressColor or Theme.TextColor
				love.graphics.setColor(WithAlpha(RewardColor, 0.9))
				for _, line in ipairs(rewards) do
					love.graphics.printf("• " .. line, TextX, InfoY, WrapWidth, "left")
					InfoY = InfoY + LineHeight
				end
			end

		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

local function DrawCosmeticsHeader(sw)
	local HeaderY = TAB_BOTTOM + 28
	love.graphics.setFont(UI.fonts.button)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.printf(Localization:get("metaprogression.cosmetics.header"), 0, HeaderY, sw, "center")

	if CosmeticsSummary.total > 0 then
		local SummaryText = Localization:get("metaprogression.cosmetics.progress", {
			unlocked = CosmeticsSummary.unlocked or 0,
			total = CosmeticsSummary.total or 0,
		})
		local muted = Theme.MutedTextColor or {Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], (Theme.TextColor[4] or 1) * 0.75}
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
		love.graphics.printf(SummaryText, 0, HeaderY + 38, sw, "center")

		if CosmeticsSummary.newUnlocks and CosmeticsSummary.newUnlocks > 0 then
			local key = (CosmeticsSummary.newUnlocks == 1) and "metaprogression.cosmetics.new_summary_single" or "metaprogression.cosmetics.new_summary_multiple"
			local accent = Theme.ProgressColor or Theme.AccentTextColor or Theme.TextColor
			love.graphics.setFont(UI.fonts.small)
			love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.92)
			love.graphics.printf(Localization:get(key, { count = CosmeticsSummary.newUnlocks }), 0, HeaderY + 60, sw, "center")
		end
	end
end

local function DrawCosmeticsList(sw, sh)
	local ClipY = GetListTop("cosmetics")
	local ClipH = ViewportHeight

	if ClipH <= 0 then
		return
	end

	UpdateCosmeticsLayout(sw)

	local ListX = (sw - CARD_WIDTH) / 2

	local FrameX = ListX - WINDOW_PADDING_X
	local FrameY = ClipY - WINDOW_PADDING_Y
	local FrameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local FrameHeight = ClipH + WINDOW_PADDING_Y * 2
	DrawWindowFrame(FrameX, FrameY, FrameWidth, FrameHeight, {
		AccentHeight = 0,
		AccentInsetY = WINDOW_PADDING_Y * 0.5,
		AccentAlpha = 0.24,
	})

	love.graphics.push()
	love.graphics.setScissor(ListX - 20, ClipY - 10, CARD_WIDTH + 40, ClipH + 20)

	local ListTop = ClipY

	for index, entry in ipairs(CosmeticsEntries) do
		local y = ListTop + ScrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
		entry.bounds = entry.bounds or {}
		entry.bounds.x = ListX
		entry.bounds.y = y
		entry.bounds.w = CARD_WIDTH
		entry.bounds.h = COSMETIC_CARD_HEIGHT

		if y + COSMETIC_CARD_HEIGHT >= ClipY - COSMETIC_CARD_HEIGHT and y <= ClipY + ClipH + COSMETIC_CARD_HEIGHT then
			local skin = entry.skin or {}
			local unlocked = skin.unlocked
			local selected = skin.selected
			local IsFocused = (index == CosmeticsFocusIndex)
			local IsHovered = (index == HoveredCosmeticIndex)
			local IsNew = entry.justUnlocked

			local BasePanel = Theme.PanelColor or {0.18, 0.18, 0.22, 0.9}
			local FillColor
			if selected then
				FillColor = LightenColor(BasePanel, 0.28)
			elseif unlocked then
				FillColor = LightenColor(BasePanel, 0.14)
			else
				FillColor = DarkenColor(BasePanel, 0.25)
			end

			if IsFocused or IsHovered then
				FillColor = LightenColor(FillColor, 0.06)
			end

			if IsNew then
				FillColor = LightenColor(FillColor, 0.08)
			end

			love.graphics.setColor(FillColor[1], FillColor[2], FillColor[3], FillColor[4] or 0.92)
			UI.DrawRoundedRect(ListX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14)

			local BorderColor = Theme.PanelBorder or {0.35, 0.30, 0.50, 1.0}
			if selected then
				BorderColor = Theme.AccentTextColor or BorderColor
			elseif unlocked then
				BorderColor = Theme.ProgressColor or BorderColor
			elseif Theme.LockedCardColor then
				BorderColor = Theme.LockedCardColor
			end

			if IsNew then
				BorderColor = LightenColor(BorderColor, 0.12)
			end

			love.graphics.setColor(BorderColor[1], BorderColor[2], BorderColor[3], BorderColor[4] or 1)
			love.graphics.setLineWidth(IsFocused and 3 or 2)
			love.graphics.rectangle("line", ListX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14, 14)

			if IsFocused then
				local highlight = Theme.HighlightColor or {1, 1, 1, 0.08}
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.08) + 0.04)
				UI.DrawRoundedRect(ListX + 6, y + 6, CARD_WIDTH - 12, COSMETIC_CARD_HEIGHT - 12, 12)
			end

			local SkinColors = skin.colors or {}
			local BodyColor = SkinColors.body or Theme.SnakeDefault or {0.45, 0.85, 0.70, 1}
			local OutlineColor = SkinColors.outline or {0.05, 0.15, 0.12, 1}
			local GlowColor = SkinColors.glow or Theme.AccentTextColor or {0.95, 0.76, 0.48, 1}

			if not unlocked then
				BodyColor = DarkenColor(BodyColor, 0.25)
				OutlineColor = DarkenColor(OutlineColor, 0.2)
				GlowColor = DarkenColor(GlowColor, 0.3)
			end

			local PreviewX = ListX + 28
			local PreviewY = y + (COSMETIC_CARD_HEIGHT - COSMETIC_PREVIEW_HEIGHT) / 2
			local PreviewW = COSMETIC_PREVIEW_WIDTH
			local PreviewH = COSMETIC_PREVIEW_HEIGHT

			if unlocked then
				love.graphics.setColor(GlowColor[1], GlowColor[2], GlowColor[3], (GlowColor[4] or 1) * 0.45)
				love.graphics.setLineWidth(6)
				love.graphics.rectangle("line", PreviewX - 6, PreviewY - 6, PreviewW + 12, PreviewH + 12, PreviewH / 2 + 6, PreviewH / 2 + 6)
			end

			love.graphics.setColor(BodyColor[1], BodyColor[2], BodyColor[3], BodyColor[4] or 1)
			UI.DrawRoundedRect(PreviewX, PreviewY, PreviewW, PreviewH, PreviewH / 2)

			love.graphics.setColor(OutlineColor[1], OutlineColor[2], OutlineColor[3], OutlineColor[4] or 1)
			love.graphics.setLineWidth(3)
			love.graphics.rectangle("line", PreviewX, PreviewY, PreviewW, PreviewH, PreviewH / 2, PreviewH / 2)

			love.graphics.setLineWidth(1)

			if not unlocked then
				local OverlayColor = WithAlpha(Theme.BgColor or {0, 0, 0, 1}, 0.25)
				love.graphics.setColor(OverlayColor[1], OverlayColor[2], OverlayColor[3], OverlayColor[4] or 1)
				UI.DrawRoundedRect(PreviewX, PreviewY, PreviewW, PreviewH, PreviewH / 2)

				local LockColor = Theme.LockedCardColor or {0.5, 0.35, 0.4, 1}
				local ShackleColor = LightenColor(LockColor, 0.1)
				local BodyColor = DarkenColor(LockColor, 0.12)
				local LockWidth = math.min(60, PreviewW * 0.78)
				local LockHeight = math.max(30, PreviewH * 0.74)
				local LockBodyHeight = LockHeight + 10
				local LockX = PreviewX + (PreviewW - LockWidth) / 2
				local LockY = PreviewY + (PreviewH - LockHeight) / 2 + 2
				local ShackleWidth = LockWidth * 0.68
				local PostWidth = math.max(3, LockWidth * 0.16)
				local PostHeight = math.max(LockHeight * 0.75, LockHeight - 3)
				local ShackleX = PreviewX + (PreviewW - ShackleWidth) / 2
				local PostY = LockY - PostHeight
				local TopCenterY = PostY
				local TopRectX = ShackleX + PostWidth / 2
				local TopRectWidth = ShackleWidth - PostWidth
				local TopRectY = TopCenterY - PostWidth / 2

				-- subtle drop shadow behind the lock to make it pop from the overlay
				local ShadowOffsetX, ShadowOffsetY = 3, 4
				local ShadowColor = WithAlpha(Theme.ShadowColor or {0, 0, 0, 1}, 0.28)
				love.graphics.setColor(ShadowColor[1], ShadowColor[2], ShadowColor[3], ShadowColor[4] or 1)
				UI.DrawRoundedRect(LockX + ShadowOffsetX, LockY + ShadowOffsetY, LockWidth, LockBodyHeight, 4)
				love.graphics.rectangle("fill", ShackleX + ShadowOffsetX, PostY + ShadowOffsetY, PostWidth, PostHeight)
				love.graphics.rectangle("fill", ShackleX + ShackleWidth - PostWidth + ShadowOffsetX, PostY + ShadowOffsetY, PostWidth, PostHeight)
				love.graphics.rectangle("fill", TopRectX + ShadowOffsetX, TopRectY + ShadowOffsetY, TopRectWidth, PostWidth)
				love.graphics.circle("fill", TopRectX + ShadowOffsetX, TopCenterY + ShadowOffsetY, PostWidth / 2)
				love.graphics.circle("fill", TopRectX + TopRectWidth + ShadowOffsetX, TopCenterY + ShadowOffsetY, PostWidth / 2)

				love.graphics.setColor(BodyColor[1], BodyColor[2], BodyColor[3], (BodyColor[4] or 1) * 0.9)
				UI.DrawRoundedRect(LockX, LockY, LockWidth, LockBodyHeight, 4)

				-- vertical posts
				love.graphics.setColor(ShackleColor[1], ShackleColor[2], ShackleColor[3], ShackleColor[4] or 1)
				love.graphics.rectangle("fill", ShackleX, PostY, PostWidth, PostHeight)
				love.graphics.rectangle("fill", ShackleX + ShackleWidth - PostWidth, PostY, PostWidth, PostHeight)

				-- straight top bar with rounded corners similar to the snake styling
				love.graphics.rectangle("fill", TopRectX, TopRectY, TopRectWidth, PostWidth)
				love.graphics.circle("fill", TopRectX, TopCenterY, PostWidth / 2)
				love.graphics.circle("fill", TopRectX + TopRectWidth, TopCenterY, PostWidth / 2)

				local KeyholeWidth = math.max(5, LockWidth * 0.16 - 4)
				local KeyholeHeight = math.max(9, LockHeight * 0.44)
				local KeyholeX = PreviewX + PreviewW / 2 - KeyholeWidth / 2
				local KeyholeY = LockY + LockHeight / 2 - KeyholeHeight / 2
				local KeyholeColor = Theme.BgColor or {0, 0, 0, 1}
				love.graphics.setColor(KeyholeColor[1], KeyholeColor[2], KeyholeColor[3], (KeyholeColor[4] or 1) * 0.9)
				love.graphics.rectangle("fill", KeyholeX, KeyholeY, KeyholeWidth, KeyholeHeight, 2, 2)
			end

			if IsNew then
				local BadgeText = Localization:get("metaprogression.cosmetics.new_badge")
				local BadgeFont = UI.fonts.caption
				love.graphics.setFont(BadgeFont)
				local TextWidth = BadgeFont:getWidth(BadgeText)
				local PaddingX = 18
				local PaddingY = 6
				local BadgeWidth = TextWidth + PaddingX
				local BadgeHeight = BadgeFont:getHeight() + PaddingY
				local BadgeX = ListX + CARD_WIDTH - BadgeWidth - 24
				local BadgeY = y - BadgeHeight / 2
				local accent = Theme.ProgressColor or Theme.AccentTextColor or {1, 1, 1, 1}
				love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.95)
				UI.DrawRoundedRect(BadgeX, BadgeY, BadgeWidth, BadgeHeight, BadgeHeight / 2)

				local BadgeTextColor = Theme.BgColor or {0, 0, 0, 1}
				love.graphics.setColor(BadgeTextColor[1], BadgeTextColor[2], BadgeTextColor[3], BadgeTextColor[4] or 1)
				love.graphics.printf(BadgeText, BadgeX, BadgeY + PaddingY / 2, BadgeWidth, "center")
			end

			local TextX = PreviewX + PreviewW + 24
			local TextWidth = CARD_WIDTH - (TextX - ListX) - 28

			love.graphics.setFont(UI.fonts.button)
			love.graphics.setColor(Theme.TextColor)
			love.graphics.printf(skin.name or skin.id or "", TextX, y + 20, TextWidth, "left")

			love.graphics.setFont(UI.fonts.body)
			love.graphics.setColor(Theme.MutedTextColor or Theme.TextColor)
			love.graphics.printf(skin.description or "", TextX, y + 52, TextWidth, "left")

			local StatusColor = entry.statusColor or Theme.TextColor
			love.graphics.setFont(UI.fonts.caption)
			love.graphics.setColor(StatusColor[1], StatusColor[2], StatusColor[3], StatusColor[4] or 1)
			love.graphics.printf(entry.statusLabel or "", TextX, y + COSMETIC_CARD_HEIGHT - 40, TextWidth, "left")

			if entry.detailText and entry.detailText ~= "" then
				love.graphics.setFont(UI.fonts.small)
				love.graphics.setColor(Theme.MutedTextColor or Theme.TextColor)
				love.graphics.printf(entry.detailText, TextX, y + COSMETIC_CARD_HEIGHT - 24, TextWidth, "left")
			end
		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

local function DrawStatsHeader(sw)
	-- Intentionally left blank: the stats header and subheader have been removed.
end

local function DrawStatsSummary(sw)
	if #StatsHighlights == 0 then
		return
	end

	local TotalWidth = #StatsHighlights * STATS_SUMMARY_CARD_WIDTH + math.max(0, #StatsHighlights - 1) * STATS_SUMMARY_CARD_SPACING
	local FrameWidth = TotalWidth + WINDOW_PADDING_X * 2
	local FrameHeight = STATS_SUMMARY_CARD_HEIGHT + WINDOW_PADDING_Y * 2
	local FrameX = sw / 2 - FrameWidth / 2
	local FrameY = ViewportTop - WINDOW_PADDING_Y
	DrawWindowFrame(FrameX, FrameY, FrameWidth, FrameHeight, {
		AccentHeight = 0,
		AccentInsetY = WINDOW_PADDING_Y * 0.35,
		AccentAlpha = 0.26,
	})

	local StartX = FrameX + WINDOW_PADDING_X
	local CardY = FrameY + WINDOW_PADDING_Y
	local BasePanel = Theme.PanelColor or {0.18, 0.18, 0.22, 0.92}
	local accent = Theme.ProgressColor or Theme.AccentTextColor or Theme.TextColor or {1, 1, 1, 1}
	local muted = Theme.MutedTextColor or {Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], (Theme.TextColor[4] or 1) * 0.8}

	for index, entry in ipairs(StatsHighlights) do
		local CardX = StartX + (index - 1) * (STATS_SUMMARY_CARD_WIDTH + STATS_SUMMARY_CARD_SPACING)
		local FillColor = LightenColor(BasePanel, 0.20 + 0.05 * ((index - 1) % 2))

		love.graphics.setColor(0, 0, 0, 0.28)
		UI.DrawRoundedRect(CardX + 4, CardY + STATS_SUMMARY_SHADOW_OFFSET, STATS_SUMMARY_CARD_WIDTH, STATS_SUMMARY_CARD_HEIGHT, 14)

		love.graphics.setColor(FillColor[1], FillColor[2], FillColor[3], FillColor[4] or 0.96)
		UI.DrawRoundedRect(CardX, CardY, STATS_SUMMARY_CARD_WIDTH, STATS_SUMMARY_CARD_HEIGHT, 14)

		love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.22)
		love.graphics.rectangle("fill", CardX, CardY, STATS_SUMMARY_CARD_WIDTH, 6, 14, 14)

		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
		love.graphics.printf(entry.label or "", CardX + 20, CardY + 18, STATS_SUMMARY_CARD_WIDTH - 40, "left")

		love.graphics.setFont(UI.fonts.heading)
		love.graphics.setColor(Theme.TextColor)
		love.graphics.printf(entry.valueText or "0", CardX + 20, CardY + 42, STATS_SUMMARY_CARD_WIDTH - 40, "left")
	end
end

local function DrawStatsList(sw, sh)
	local ClipY = ViewportTop
	local ClipH = ViewportHeight

	if ClipH <= 0 then
		return
	end

	local ListX = (sw - CARD_WIDTH) / 2

	local FrameX = ListX - WINDOW_PADDING_X
	local FrameY = ClipY - WINDOW_PADDING_Y
	local FrameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local FrameHeight = ClipH + WINDOW_PADDING_Y * 2
	DrawWindowFrame(FrameX, FrameY, FrameWidth, FrameHeight, {
		AccentHeight = 0,
		AccentInsetY = WINDOW_PADDING_Y * 0.5,
		AccentAlpha = 0.18,
	})

	love.graphics.push()
	love.graphics.setScissor(ListX - 20, ClipY - 10, CARD_WIDTH + 40, ClipH + 20)

	if #StatsEntries == 0 then
		love.graphics.setFont(UI.fonts.body)
		love.graphics.setColor(Theme.TextColor)
		love.graphics.printf(Localization:get("metaprogression.stats_empty"), ListX, ClipY + ViewportHeight / 2 - 12, CARD_WIDTH, "center")
	else
		local accent = Theme.ProgressColor or Theme.AccentTextColor or Theme.TextColor or {1, 1, 1, 1}
		local muted = Theme.MutedTextColor or {Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], (Theme.TextColor[4] or 1) * 0.8}

		for index, entry in ipairs(StatsEntries) do
			local y = ViewportTop + ScrollOffset + (index - 1) * (STAT_CARD_HEIGHT + STAT_CARD_SPACING)
			if y + STAT_CARD_HEIGHT >= ClipY - STAT_CARD_HEIGHT and y <= ClipY + ClipH + STAT_CARD_HEIGHT then
				local BasePanel = Theme.PanelColor or {0.18, 0.18, 0.22, 0.92}
				local TintOffset = ((index % 2) == 0) and 0.08 or 0.04
				local FillColor = LightenColor(BasePanel, 0.16 + TintOffset)

				love.graphics.setColor(0, 0, 0, 0.26)
				UI.DrawRoundedRect(ListX + 4, y + STAT_CARD_SHADOW_OFFSET, CARD_WIDTH, STAT_CARD_HEIGHT, 12)

				love.graphics.setColor(FillColor[1], FillColor[2], FillColor[3], FillColor[4] or 0.95)
				UI.DrawRoundedRect(ListX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12)

				local BorderColor = Theme.PanelBorder or {0.35, 0.30, 0.50, 1.0}
				love.graphics.setColor(BorderColor[1], BorderColor[2], BorderColor[3], (BorderColor[4] or 1) * 0.8)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", ListX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12, 12)
				love.graphics.setLineWidth(1)

				love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.18)
				love.graphics.rectangle("fill", ListX + 20, y + STAT_CARD_HEIGHT - 8, CARD_WIDTH - 40, 4, 2, 2)

				local LabelX = ListX + 32
				local ValueAreaX = ListX + CARD_WIDTH * 0.55
				local ValueAreaWidth = CARD_WIDTH - (ValueAreaX - ListX) - 32
				local LabelWidth = ValueAreaX - LabelX - 16

				love.graphics.setFont(UI.fonts.caption)
				love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
				love.graphics.printf(entry.label, LabelX, y + 12, LabelWidth, "left")

				love.graphics.setFont(UI.fonts.subtitle)
				love.graphics.setColor(Theme.TextColor)
				love.graphics.printf(entry.valueText, ValueAreaX, y + 26, ValueAreaWidth, "right")
			end
		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

function ProgressionScreen:draw()
	local sw, sh = Screen:get()

	DrawBackground(sw, sh)

	love.graphics.setFont(UI.fonts.title)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.printf(Localization:get("metaprogression.title"), 0, 48, sw, "center")

	if ActiveTab == "experience" then
		DrawSummaryPanel(sw)
		DrawTrack(sw, sh)
	elseif ActiveTab == "cosmetics" then
		DrawCosmeticsHeader(sw)
		DrawCosmeticsList(sw, sh)
	else
		DrawStatsHeader(sw)
		DrawStatsSummary(sw)
		DrawStatsList(sw, sh)
	end

	ButtonList:syncUI()

	for _, tab in ipairs(tabs) do
		local id = tab.buttonId
		if id then
			local button = UI.buttons[id]
			if button then
				button.toggled = (ActiveTab == tab.id) or nil
			end
		end
	end

	for _, button in ButtonList:iter() do
		UI.DrawButton(button.id)
	end
end

function ProgressionScreen:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)

	if ActiveTab == "cosmetics" and button == 1 then
		local sw = select(1, Screen:get())
		UpdateCosmeticsLayout(sw)

		PressedCosmeticIndex = nil
		for index, entry in ipairs(CosmeticsEntries) do
			local bounds = entry.bounds
			if bounds and UI.IsHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
				PressedCosmeticIndex = index
				SetCosmeticsFocus(index)
				break
			end
		end
	end
end

function ProgressionScreen:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
	if action then
		Audio:PlaySound("click")
		if action == "tab_experience" then
			SetActiveTab("experience", { FocusSource = "mouse", SkipFocusHistory = true })
		elseif action == "tab_cosmetics" then
			SetActiveTab("cosmetics", { FocusSource = "mouse", SkipFocusHistory = true })
		elseif action == "tab_stats" then
			SetActiveTab("stats", { FocusSource = "mouse", SkipFocusHistory = true })
		else
			return action
		end
		return
	end


	if ActiveTab ~= "cosmetics" or button ~= 1 then
		PressedCosmeticIndex = nil
		return
	end

	local sw = select(1, Screen:get())
	UpdateCosmeticsLayout(sw)

	local ReleasedIndex
	for index, entry in ipairs(CosmeticsEntries) do
		local bounds = entry.bounds
		if bounds and UI.IsHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
			ReleasedIndex = index
			break
		end
	end

	if ReleasedIndex and ReleasedIndex == PressedCosmeticIndex then
		SetCosmeticsFocus(ReleasedIndex)
		local changed = ActivateCosmetic(ReleasedIndex)
		Audio:PlaySound(changed and "click" or "hover")
	end

	PressedCosmeticIndex = nil
end

function ProgressionScreen:wheelmoved(_, dy)
	ScrollBy(dy * SCROLL_SPEED)
end

function ProgressionScreen:keypressed(key)
	if ActiveTab == "cosmetics" then
		if key == "up" then
			MoveCosmeticsFocus(-1)
			return
		elseif key == "down" then
			MoveCosmeticsFocus(1)
			return
		end
	end

	if key == "up" then
		ScrollBy(SCROLL_SPEED)
		ApplyFocusedTab(ButtonList:moveFocus(-1))
	elseif key == "down" then
		ScrollBy(-SCROLL_SPEED)
		ApplyFocusedTab(ButtonList:moveFocus(1))
	elseif key == "left" then
		ApplyFocusedTab(ButtonList:moveFocus(-1))
	elseif key == "right" then
		ApplyFocusedTab(ButtonList:moveFocus(1))
	elseif key == "pageup" then
		ScrollBy(ViewportHeight)
	elseif key == "pagedown" then
		ScrollBy(-ViewportHeight)
	elseif key == "escape" or key == "backspace" then
		Audio:PlaySound("click")
		return "menu"
	elseif key == "return" or key == "kpenter" or key == "space" then
		if ActiveTab == "cosmetics" and CosmeticsFocusIndex then
			local changed = ActivateCosmetic(CosmeticsFocusIndex)
			Audio:PlaySound(changed and "click" or "hover")
			return
		end
		return HandleConfirm()
	end
end

function ProgressionScreen:gamepadpressed(_, button)
	if button == "dpup" then
		DpadScrollUp()
		StartHeldDpad(button, DpadScrollUp)
	elseif button == "dpleft" then
		ApplyFocusedTab(ButtonList:moveFocus(-1))
	elseif button == "dpdown" then
		DpadScrollDown()
		StartHeldDpad(button, DpadScrollDown)
	elseif button == "dpright" then
		ApplyFocusedTab(ButtonList:moveFocus(1))
	elseif button == "a" or button == "start" then
		if ActiveTab == "cosmetics" and CosmeticsFocusIndex then
			local changed = ActivateCosmetic(CosmeticsFocusIndex)
			Audio:PlaySound(changed and "click" or "hover")
			return
		end
		return HandleConfirm()
	elseif button == "b" then
		Audio:PlaySound("click")
		return "menu"
	end
end

ProgressionScreen.joystickpressed = ProgressionScreen.gamepadpressed

function ProgressionScreen:gamepadaxis(_, axis, value)
	HandleGamepadAxis(axis, value)
end

ProgressionScreen.joystickaxis = ProgressionScreen.gamepadaxis

function ProgressionScreen:gamepadreleased(_, button)
	if button == "dpup" or button == "dpdown" then
		StopHeldDpad(button)
	end
end

ProgressionScreen.joystickreleased = ProgressionScreen.gamepadreleased

function ProgressionScreen:resize()
	local sw, sh = Screen:get()
	UpdateScrollBounds(sw, sh)
end

return ProgressionScreen
