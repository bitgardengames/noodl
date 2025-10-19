local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local SnakeCosmetics = require("snakecosmetics")
local SnakeDraw = require("snakedraw")
local SnakeUtils = require("snakeutils")
local Achievements = require("achievements")
local PlayerStats = require("playerstats")
local Audio = require("audio")
local Shaders = require("shaders")

local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin
local sort = table.sort

local ProgressionScreen = {
	transitionDuration = 0.45,
}

local buttonList = ButtonList.new()

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
local COSMETIC_SHOWCASE_TILE_WIDTH = 196
local COSMETIC_SHOWCASE_TILE_HEIGHT = 116
local COSMETIC_SHOWCASE_SPACING_X = 18
local COSMETIC_SHOWCASE_SPACING_Y = 16
local COSMETIC_SHOWCASE_TOP_OFFSET = 96
local COSMETIC_SHOWCASE_BOTTOM_PADDING = 28
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

local scrollOffset = 0
local minScrollOffset = 0
local viewportTop = DEFAULT_LIST_TOP
local viewportHeight = 0
local contentHeight = 0

local drawCosmeticSnakePreview

local function clampColorComponent(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function lightenColor(color, amount)
	if type(color) ~= "table" then
		return {1, 1, 1, 1}
	end

	amount = clampColorComponent(amount or 0)

	local r = clampColorComponent((color[1] or 0) + (1 - (color[1] or 0)) * amount)
	local g = clampColorComponent((color[2] or 0) + (1 - (color[2] or 0)) * amount)
	local b = clampColorComponent((color[3] or 0) + (1 - (color[3] or 0)) * amount)
	local a = clampColorComponent(color[4] or 1)

	return {r, g, b, a}
end

local function darkenColor(color, amount)
	if type(color) ~= "table" then
		return {0, 0, 0, 1}
	end

	amount = clampColorComponent(amount or 0)

	local scale = 1 - amount
	local r = clampColorComponent((color[1] or 0) * scale)
	local g = clampColorComponent((color[2] or 0) * scale)
	local b = clampColorComponent((color[3] or 0) * scale)
	local a = clampColorComponent(color[4] or 1)

	return {r, g, b, a}
end

local function shallowCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = v
	end
	return copy
end

local heldDpadButton = nil
local heldDpadAction = nil
local heldDpadTimer = 0
local heldDpadInterval = DPAD_REPEAT_INITIAL_DELAY
local analogAxisDirections = {horizontal = nil, vertical = nil}

local trackEntries = {}
local trackContentHeight = 0
local statsEntries = {}
local statsHighlights = {}
local statsSummaryHeight = 0
local cosmeticsEntries = {}
local cosmeticsSummary = {unlocked = 0, total = 0, newUnlocks = 0}
local cosmeticShaderShowcaseEntries = {}
local cosmeticShowcaseHeight = 0
local progressionState = nil
local activeTab = "experience"
local cosmeticsFocusIndex = nil

local function compareStatsEntries(a, b)
        if a.label == b.label then
                return a.id < b.id
        end
        return a.label < b.label
end

local function compareCosmeticShowcaseEntries(a, b)
        local nameA = a.displayName or ""
        local nameB = b.displayName or ""
        if nameA == nameB then
                return (a.skinName or "") < (b.skinName or "")
        end
        return nameA < nameB
end
local hoveredCosmeticIndex = nil
local pressedCosmeticIndex = nil

local cosmeticPreviewTrail = nil
local cosmeticPreviewBounds = nil

local function computeCosmeticShowcaseLayout(sw)
	if not cosmeticShaderShowcaseEntries or #cosmeticShaderShowcaseEntries == 0 then
		cosmeticShowcaseHeight = 0
		return nil
	end

	if not sw then
		sw = select(1, Screen:get())
	end

	if not sw then
		return nil
	end

	local tileWidth = COSMETIC_SHOWCASE_TILE_WIDTH
	local tileHeight = COSMETIC_SHOWCASE_TILE_HEIGHT
	local spacingX = COSMETIC_SHOWCASE_SPACING_X
	local spacingY = COSMETIC_SHOWCASE_SPACING_Y

	local maxColumns = max(1, floor((sw + spacingX) / (tileWidth + spacingX)))
	maxColumns = min(maxColumns, #cosmeticShaderShowcaseEntries)
	if maxColumns < 1 then
		maxColumns = 1
	end

	local rows = ceil(#cosmeticShaderShowcaseEntries / maxColumns)
	local contentWidth = maxColumns * tileWidth + (max(0, maxColumns - 1) * spacingX)
	local startX = (sw - contentWidth) * 0.5
	local startY = TAB_BOTTOM + COSMETIC_SHOWCASE_TOP_OFFSET
	local contentHeight = rows * tileHeight + max(0, rows - 1) * spacingY
	local contentBottom = startY + contentHeight
	local requiredListTop = contentBottom + COSMETIC_SHOWCASE_BOTTOM_PADDING

	cosmeticShowcaseHeight = max(0, requiredListTop - DEFAULT_LIST_TOP)

	return {
		startX = startX,
		startY = startY,
		tileWidth = tileWidth,
		tileHeight = tileHeight,
		spacingX = spacingX,
		spacingY = spacingY,
		columns = maxColumns,
	}
end

local function drawCosmeticShaderShowcase(sw)
	local layout = computeCosmeticShowcaseLayout(sw)
	if not layout then
		return
	end

	local basePanel = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
	local borderColor = Theme.panelBorder or {0.35, 0.30, 0.50, 1.0}
	local textColor = Theme.textColor or {1, 1, 1, 1}
	local mutedText = Theme.mutedTextColor or {textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * 0.8}

	local previewHeight = min(COSMETIC_PREVIEW_HEIGHT, layout.tileHeight - 48)
	local previewWidth = min(COSMETIC_PREVIEW_WIDTH, layout.tileWidth - 36)

	for index, entry in ipairs(cosmeticShaderShowcaseEntries) do
		local column = (index - 1) % layout.columns
		local row = floor((index - 1) / layout.columns)
		local tileX = layout.startX + column * (layout.tileWidth + layout.spacingX)
		local tileY = layout.startY + row * (layout.tileHeight + layout.spacingY)

		local unlocked = (entry.unlockedCount or 0) > 0

		local fillColor = unlocked and lightenColor(basePanel, 0.18) or darkenColor(basePanel, 0.08)
		love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], (fillColor[4] or 1) * 0.95)
		UI.drawRoundedRect(tileX, tileY, layout.tileWidth, layout.tileHeight, 12)

		local outline = unlocked and (Theme.progressColor or Theme.accentTextColor or borderColor) or borderColor
		love.graphics.setColor(outline[1], outline[2], outline[3], (outline[4] or 1))
		love.graphics.setLineWidth(unlocked and 2.4 or 2)
		love.graphics.rectangle("line", tileX, tileY, layout.tileWidth, layout.tileHeight, 12, 12)
		love.graphics.setLineWidth(1)

		local previewX = tileX + (layout.tileWidth - previewWidth) * 0.5
		local previewY = tileY + 14

		local palette = entry.palette or {}
		local bodyColor = palette.body or Theme.snakeDefault or {0.45, 0.85, 0.70, 1}
		local outlineColor = palette.outline or {0.05, 0.15, 0.12, 1}
		local glowColor = palette.glow or Theme.accentTextColor or {1, 0.78, 0.32, 1}
		local overlayEffect = palette.overlay or entry.overlay

		if not unlocked then
			bodyColor = darkenColor(bodyColor, 0.22)
			outlineColor = darkenColor(outlineColor, 0.16)
			glowColor = darkenColor(glowColor, 0.25)
			if overlayEffect then
				overlayEffect = shallowCopy(overlayEffect)
				if overlayEffect.opacity then
					overlayEffect.opacity = overlayEffect.opacity * 0.65
				end
				if overlayEffect.intensity then
					overlayEffect.intensity = overlayEffect.intensity * 0.6
				end
			end
		end

		local previewPalette = {
			body = bodyColor,
			outline = outlineColor,
			glow = glowColor,
			overlay = overlayEffect,
		}

		drawCosmeticSnakePreview(previewX, previewY, previewWidth, previewHeight, entry.primarySkin, previewPalette)

		local label = entry.displayName or entry.type or ""
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
		love.graphics.printf(label, tileX + 12, tileY + layout.tileHeight - 34, layout.tileWidth - 24, "center")

		local statusText
		if (entry.totalCount or 0) > 1 then
			statusText = string.format("%d / %d unlocked", entry.unlockedCount or 0, entry.totalCount or 0)
		elseif unlocked then
			statusText = Localization and Localization.get and Localization:get("metaprogression.status_unlocked") or "Unlocked"
		else
			statusText = Localization and Localization.get and Localization:get("metaprogression.cosmetics.locked_label") or "Locked"
		end

		love.graphics.setFont(UI.fonts.small)
		love.graphics.setColor(mutedText[1], mutedText[2], mutedText[3], mutedText[4] or 1)
		love.graphics.printf(statusText or "", tileX + 12, tileY + layout.tileHeight - 18, layout.tileWidth - 24, "center")
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local tabs = {
	{
		id = "experience",
		action = "tab_experience",
		labelKey = "metaprogression.tabs.experience",
	},
	{
		id = "cosmetics",
		action = "tab_cosmetics",
		labelKey = "metaprogression.tabs.cosmetics",
	},
	{
		id = "stats",
		action = "tab_stats",
		labelKey = "metaprogression.tabs.stats",
	},
}

local BACKGROUND_EFFECT_TYPE = "metaFlux"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function configureBackgroundEffect()
	local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		backgroundEffect = nil
		return
	end

	local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
	effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.6

	Shaders.configure(effect, {
		bgColor = Theme.bgColor,
		primaryColor = Theme.progressColor,
		secondaryColor = Theme.accentTextColor,
	})

	backgroundEffect = effect
end

local function drawBackground(sw, sh)
	love.graphics.setColor(Theme.bgColor or {0, 0, 0, 1})
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

local function getListTop(tab)
	tab = tab or activeTab
	if tab == "experience" then
		return EXPERIENCE_LIST_TOP
	end

	if tab == "cosmetics" then
		local sw = select(1, Screen:get())
		computeCosmeticShowcaseLayout(sw)
		return DEFAULT_LIST_TOP + (cosmeticShowcaseHeight or 0)
	end

	return DEFAULT_LIST_TOP
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

local function getActiveList()
	if activeTab == "cosmetics" then
		return cosmeticsEntries, COSMETIC_CARD_HEIGHT, COSMETIC_CARD_SPACING
	end

	if activeTab == "stats" then
		return statsEntries, STAT_CARD_HEIGHT, STAT_CARD_SPACING
	end

	return trackEntries, TRACK_CARD_MIN_HEIGHT, CARD_SPACING
end

local function getScrollPadding()
	if activeTab == "cosmetics" then
		return COSMETIC_CARD_SPACING
	end

	return 0
end

local function updateScrollBounds(sw, sh)
	local viewportBottom = sh - 140
	local topOffset = 0
	if activeTab == "stats" then
		topOffset = statsSummaryHeight
		if topOffset > 0 then
			topOffset = topOffset + STATS_SUMMARY_SPACING
		end
	end

	local baseTop = getListTop()
	viewportTop = baseTop + topOffset
	viewportHeight = max(0, viewportBottom - viewportTop)

	if activeTab == "experience" then
		contentHeight = trackContentHeight
	else
		local entries, itemHeight, spacing = getActiveList()
		local count = #entries
		if count > 0 then
			contentHeight = count * itemHeight + max(0, count - 1) * spacing
		else
			contentHeight = 0
		end
	end

	local bottomPadding = getScrollPadding()
	if bottomPadding > 0 and contentHeight > 0 then
		contentHeight = contentHeight + bottomPadding
	end

	minScrollOffset = min(0, viewportHeight - contentHeight)

	if scrollOffset < minScrollOffset then
		scrollOffset = minScrollOffset
	elseif scrollOffset > 0 then
		scrollOffset = 0
	end
end

local function formatInteger(value)
	local rounded = floor((value or 0) + 0.5)
	local sign = rounded < 0 and "-" or ""
	local digits = tostring(abs(rounded))
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

local function formatStatValue(value)
	if type(value) == "number" then
		if abs(value - floor(value + 0.5)) < 0.0001 then
			return formatInteger(value)
		end

		return string.format("%.2f", value)
	end

	if value == nil then
		return "0"
	end

	return tostring(value)
end

local function formatDuration(seconds)
	local totalSeconds = floor((seconds or 0) + 0.5)
	if totalSeconds < 0 then
		totalSeconds = 0
	end

	local hours = floor(totalSeconds / 3600)
	local minutes = floor((totalSeconds % 3600) / 60)
	local secs = totalSeconds % 60

	if hours > 0 then
		return string.format("%dh %02dm %02ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %02ds", minutes, secs)
	end

	return string.format("%ds", secs)
end

local statFormatters = {
	totalTimeAlive = formatDuration,
	longestRunDuration = formatDuration,
	bestFloorClearTime = formatDuration,
	longestFloorClearTime = formatDuration,
}

local hiddenStats = {
	averageFloorClearTime = true,
	bestFruitPerMinute = true,
	averageFruitPerMinute = true,
	dailyChallengesCompleted = true,
	mostUpgradesInRun = true,
}

local function isHiddenStat(key)
	if not key or key == "" then
		return true
	end

	if hiddenStats[key] then
		return true
	end

	if type(key) ~= "string" then
		return true
	end

	if key:find("^dailyChallenge:") or key:find("^funChallenge:") then
		return true
	end

	return false
end

local highlightStatOrder = {
	"snakeScore",
	"floorsCleared",
	"totalApplesEaten",
	"totalTimeAlive",
}

local function prettifyKey(key)
	if not key or key == "" then
		return ""
	end

	local label = key:gsub("(%l)(%u)", "%1 %2")
	label = label:gsub("_", " ")
	label = label:gsub("%s+", " ")
	label = label:gsub("^%l", string.upper)
	return label
end

local function buildStatsEntries()
	statsEntries = {}

	local labelTable = Localization:getTable("metaprogression.stat_labels") or {}
	local seen = {}

	for key, label in pairs(labelTable) do
		if not isHiddenStat(key) then
			local value = PlayerStats:get(key)
			local formatter = statFormatters[key]
			statsEntries[#statsEntries + 1] = {
				id = key,
				label = label,
				value = value,
				valueText = formatter and formatter(value) or formatStatValue(value),
			}
			seen[key] = true
		end
	end

	for key, value in pairs(PlayerStats.data or {}) do
		if not seen[key] and not isHiddenStat(key) then
			local label = prettifyKey(key)
			local formatter = statFormatters[key]
			statsEntries[#statsEntries + 1] = {
				id = key,
				label = label,
				value = value,
				valueText = formatter and formatter(value) or formatStatValue(value),
			}
		end
	end

        sort(statsEntries, compareStatsEntries)

	local function buildStatsHighlights()
		statsHighlights = {}
		statsSummaryHeight = 0

		if #statsEntries == 0 then
			return
		end

		local used = {}

		for _, statId in ipairs(highlightStatOrder) do
			for _, entry in ipairs(statsEntries) do
				if entry.id == statId and not used[entry] then
					statsHighlights[#statsHighlights + 1] = entry
					used[entry] = true
					break
				end
			end
		end

		local desired = min(4, #statsEntries)
		local index = 1
		while #statsHighlights < desired and index <= #statsEntries do
			local candidate = statsEntries[index]
			if not used[candidate] then
				statsHighlights[#statsHighlights + 1] = candidate
				used[candidate] = true
			end
			index = index + 1
		end

		if #statsHighlights > 0 then
			statsSummaryHeight = STATS_SUMMARY_CARD_HEIGHT + STATS_SUMMARY_SHADOW_OFFSET
		end
	end

	buildStatsHighlights()
end

local function formatShaderDisplayName(typeId)
	if typeId == nil then
		return ""
	end

	if type(typeId) ~= "string" then
		typeId = tostring(typeId)
	end

	local name = typeId:gsub("_", " ")
	name = name:gsub("([%l%d])([%u])", "%1 %2")
	name = name:gsub("(%u)(%u%l)", "%1 %2")

	name = name:gsub("^%l", string.upper)
	name = name:gsub("(%s)(%l)", function(space, letter)
		return space .. letter:upper()
	end)

	return name
end

local function withAlpha(color, alpha)
	if type(color) ~= "table" then
		return {1, 1, 1, clampColorComponent(alpha or 1)}
	end

	return {
		clampColorComponent(color[1] or 1),
		clampColorComponent(color[2] or 1),
		clampColorComponent(color[3] or 1),
		clampColorComponent(alpha or color[4] or 1),
	}
end

local function drawWindowFrame(x, y, width, height, options)
	options = options or {}

	if not width or not height or width <= 0 or height <= 0 then
		return
	end

	local panelColor = options.baseColor or Theme.panelColor or {0.18, 0.18, 0.22, 0.92}
	local borderColor = options.borderColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
	local accentColor = options.accentColor or Theme.progressColor or Theme.accentTextColor or Theme.textColor or {1, 1, 1, 1}
	local shadowColor = options.shadowColor or (UI.colors and UI.colors.shadow) or Theme.shadowColor or {0, 0, 0, 0.45}
	local shadowAlpha = options.shadowAlpha
	local baseAlpha = options.baseAlpha or 0.94
	local borderAlpha = options.borderAlpha or 0.85
	local accentAlpha = options.accentAlpha or 0.28
	local accentHeight = options.accentHeight or WINDOW_ACCENT_HEIGHT
	local accentInsetX = options.accentInsetX or (WINDOW_PADDING_X * 0.6)
	local accentInsetY = options.accentInsetY or (WINDOW_PADDING_Y * 0.35)

	local shadowOffset = options.shadowOffset
	if shadowOffset == nil then
		shadowOffset = (UI.spacing and UI.spacing.shadowOffset) or WINDOW_SHADOW_OFFSET
	end

	if shadowOffset and shadowOffset ~= 0 then
		love.graphics.setColor(withAlpha(shadowColor, shadowAlpha))
		UI.drawRoundedRect(x + shadowOffset, y + shadowOffset, width, height, WINDOW_CORNER_RADIUS + 2)
	end

	local fill = withAlpha(panelColor, baseAlpha)
	love.graphics.setColor(fill)
	UI.drawRoundedRect(x, y, width, height, WINDOW_CORNER_RADIUS)

	if accentHeight and accentHeight > 0 then
		local accentWidth = max(0, width - accentInsetX * 2)
		if accentWidth > 0 and height - accentInsetY * 2 > 0 then
			local accentY = y + accentInsetY
			local accentX = x + accentInsetX
			love.graphics.setColor(withAlpha(accentColor, accentAlpha))
			UI.drawRoundedRect(accentX, accentY, accentWidth, min(accentHeight, height - accentInsetY * 2), max(4, accentHeight / 2))
		end
	end

	love.graphics.setColor(withAlpha(borderColor, borderAlpha))
	love.graphics.setLineWidth(options.borderWidth or 2)
	love.graphics.rectangle("line", x, y, width, height, WINDOW_CORNER_RADIUS, WINDOW_CORNER_RADIUS)
	love.graphics.setLineWidth(1)

	if options.overlay then
		options.overlay(x, y, width, height)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function roundNearest(value)
	value = value or 0
	if value >= 0 then
		return floor(value + 0.5)
	end
	return ceil(value - 0.5)
end

local function formatShopChoice(amount)
	if not amount or amount == 0 then
		return nil
	end

	local label = Localization:get("metaprogression.rewards.shop_extra_choice", {count = amount})
	if label == "metaprogression.rewards.shop_extra_choice" then
		local rounded = roundNearest(amount)
		local noun = (abs(rounded) == 1) and "shop card option" or "shop card options"
		label = string.format("%+d %s", rounded, noun)
	end
	return label
end

local function describeUnlockTag(tag)
	if not tag then
		return nil
	end

	local nameKey = "metaprogression.rewards.unlock_tag_" .. tag
	local name = Localization:get(nameKey)
	if name == nameKey then
		name = tag:gsub("_", " ")
		name = name:gsub("^%l", string.upper)
	end

	local label = Localization:get("metaprogression.rewards.unlock_tag", {name = name})
	if label == "metaprogression.rewards.unlock_tag" then
		label = string.format("Unlocks %s", name)
	end
	return label
end

local function annotateTrackEntry(entry)
	if not entry then
		return
	end

	local rewards = {}
	local effects = entry.effects or {}
	if effects.shopExtraChoices and effects.shopExtraChoices ~= 0 then
		local reward = formatShopChoice(effects.shopExtraChoices)
		if reward then
			rewards[#rewards + 1] = reward
		end
	end

	if type(entry.unlockTags) == "table" then
		for _, tag in ipairs(entry.unlockTags) do
			local reward = describeUnlockTag(tag)
			if reward then
				rewards[#rewards + 1] = reward
			end
		end
	end

	entry.rewards = rewards
end

local function measureTrackEntryHeight(entry)
	if not entry then
		return TRACK_CARD_MIN_HEIGHT
	end

	local wrapWidth = CARD_WIDTH - 48
	local desc = entry.description or ""
	local bodyFont = UI.fonts.body
	local descHeight = 0
	if desc ~= "" then
		local _, wrapped = bodyFont:getWrap(desc, wrapWidth)
		local lineCount = max(1, #wrapped)
		descHeight = lineCount * bodyFont:getHeight()
	end

	local rewards = entry.rewards or {}
	local rewardBlockHeight = 0
	if #rewards > 0 then
		local smallFont = UI.fonts.small
		rewardBlockHeight = 6 + #rewards * smallFont:getHeight()
	end

	local textY = 20
	local descY = textY + 58

	local yCursor = descY + descHeight + rewardBlockHeight
	local requiredHeight = yCursor + 12

	return max(TRACK_CARD_MIN_HEIGHT, ceil(requiredHeight))
end

local function recalculateTrackLayout()
	local offset = 0
	trackContentHeight = 0

	for _, entry in ipairs(trackEntries or {}) do
		local height = measureTrackEntryHeight(entry)
		entry.cardHeight = height
		entry.offset = offset
		offset = offset + height + CARD_SPACING
	end

	if offset > 0 then
		trackContentHeight = offset - CARD_SPACING
	end
end

local function annotateTrackEntries()
	for _, entry in ipairs(trackEntries or {}) do
		annotateTrackEntry(entry)
	end

	recalculateTrackLayout()
end

local function resolveAchievementName(id)
	if not id or not Achievements or not Achievements.getDefinition then
		return prettifyKey(id)
	end

	local definition = Achievements:getDefinition(id)
	if not definition then
		return prettifyKey(id)
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

	return prettifyKey(id)
end

local function getSkinRequirementText(skin)
	local unlock = skin and skin.unlock or {}

	if unlock.level then
		return Localization:get("metaprogression.cosmetics.locked_level", {level = unlock.level})
	elseif unlock.achievement then
		local achievementName = resolveAchievementName(unlock.achievement)
		return Localization:get("metaprogression.cosmetics.locked_achievement", {
			name = achievementName,
		})
	end

	return Localization:get("metaprogression.cosmetics.locked_generic")
end

local function resolveSkinStatus(skin)
	if not skin then
		return "", "", Theme.textColor
	end

	if skin.selected then
		return Localization:get("metaprogression.cosmetics.equipped"), nil, Theme.accentTextColor or Theme.textColor
	end

	if skin.unlocked then
		return Localization:get("metaprogression.status_unlocked"), Localization:get("metaprogression.cosmetics.equip_hint"), Theme.progressColor or Theme.textColor
	end

	return Localization:get("metaprogression.cosmetics.locked_label"), getSkinRequirementText(skin), Theme.lockedCardColor or Theme.warningColor or Theme.textColor
end

local function buildCosmeticShaderShowcaseEntries(skins)
	cosmeticShaderShowcaseEntries = {}

	if type(skins) ~= "table" then
		cosmeticShowcaseHeight = 0
		return
	end

	local entriesByType = {}

	for _, skin in ipairs(skins) do
		local effects = skin.effects or {}
		local overlay = effects.overlay
		if overlay and overlay.type then
			local key = overlay.type
			local entry = entriesByType[key]
			if not entry then
				entry = {
					type = key,
					displayName = formatShaderDisplayName(key),
					totalCount = 0,
					unlockedCount = 0,
					primarySkin = nil,
				}
				entriesByType[key] = entry
				cosmeticShaderShowcaseEntries[#cosmeticShaderShowcaseEntries + 1] = entry
			end

			entry.totalCount = (entry.totalCount or 0) + 1

			if skin.unlocked then
				entry.unlockedCount = (entry.unlockedCount or 0) + 1
				if not entry.primarySkin or not entry.primarySkin.unlocked then
					entry.primarySkin = skin
				end
			elseif not entry.primarySkin then
				entry.primarySkin = skin
			end
		end
	end

	for _, entry in ipairs(cosmeticShaderShowcaseEntries) do
		if entry.primarySkin then
			entry.skinName = entry.primarySkin.name or entry.primarySkin.id
			entry.palette = SnakeCosmetics:getPaletteForSkin(entry.primarySkin)
			local effects = entry.primarySkin.effects or {}
			entry.overlay = shallowCopy(effects.overlay)
		else
			entry.skinName = nil
			entry.palette = nil
			entry.overlay = nil
		end
	end

        sort(cosmeticShaderShowcaseEntries, compareCosmeticShowcaseEntries)

	if #cosmeticShaderShowcaseEntries == 0 then
		cosmeticShowcaseHeight = 0
	end
end

local function buildCosmeticsEntries()
	cosmeticsEntries = {}
	hoveredCosmeticIndex = nil
	pressedCosmeticIndex = nil
	cosmeticsFocusIndex = nil
	cosmeticsSummary.unlocked = 0
	cosmeticsSummary.total = 0
	cosmeticsSummary.newUnlocks = 0

	if not (SnakeCosmetics and SnakeCosmetics.getSkins) then
		cosmeticShaderShowcaseEntries = {}
		cosmeticShowcaseHeight = 0
		return
	end

	local skins = SnakeCosmetics:getSkins() or {}
	buildCosmeticShaderShowcaseEntries(skins)
	local selectedIndex
	local recentlyUnlockedIds = {}

	for _, skin in ipairs(skins) do
		cosmeticsSummary.total = cosmeticsSummary.total + 1
		if skin.unlocked then
			cosmeticsSummary.unlocked = cosmeticsSummary.unlocked + 1
		end
		if skin.justUnlocked then
			cosmeticsSummary.newUnlocks = cosmeticsSummary.newUnlocks + 1
			recentlyUnlockedIds[#recentlyUnlockedIds + 1] = skin.id
		end

		local entry = {
			id = skin.id,
			skin = skin,
			justUnlocked = skin.justUnlocked,
		}
		entry.statusLabel, entry.detailText, entry.statusColor = resolveSkinStatus(skin)
		cosmeticsEntries[#cosmeticsEntries + 1] = entry

		if skin.selected then
			selectedIndex = #cosmeticsEntries
		end
	end

	if cosmeticsSummary.newUnlocks > 0 and SnakeCosmetics and SnakeCosmetics.clearRecentUnlocks then
		SnakeCosmetics:clearRecentUnlocks(recentlyUnlockedIds)
	end

	if selectedIndex then
		cosmeticsFocusIndex = selectedIndex
	elseif #cosmeticsEntries > 0 then
		cosmeticsFocusIndex = 1
	end
end

local function updateCosmeticsLayout(sw)
	if not sw then
		sw = select(1, Screen:get())
	end

	if not sw then
		return
	end

	local listX = (sw - CARD_WIDTH) / 2
	local listTop = getListTop("cosmetics")

	for index, entry in ipairs(cosmeticsEntries) do
		local y = listTop + scrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
		entry.bounds = {
			x = listX,
			y = y,
			w = CARD_WIDTH,
			h = COSMETIC_CARD_HEIGHT,
		}
	end
end

local function ensureCosmeticVisible(index)
	if activeTab ~= "cosmetics" or not index then
		return
	end

	if viewportHeight <= 0 then
		return
	end

	local itemHeight = COSMETIC_CARD_HEIGHT
	local spacing = COSMETIC_CARD_SPACING
	local listTop = getListTop("cosmetics")
	local top = listTop + scrollOffset + (index - 1) * (itemHeight + spacing)
	local bottom = top + itemHeight
	local viewportTop = getListTop("cosmetics")
	local bottomPadding = getScrollPadding()
	local viewportBottom = viewportTop + max(0, viewportHeight - bottomPadding)

	if top < viewportTop then
		scrollOffset = scrollOffset + (viewportTop - top)
	elseif bottom > viewportBottom then
		scrollOffset = scrollOffset - (bottom - viewportBottom)
	end

	if scrollOffset < minScrollOffset then
		scrollOffset = minScrollOffset
	elseif scrollOffset > 0 then
		scrollOffset = 0
	end

	updateCosmeticsLayout()
end

local function setCosmeticsFocus(index, playSound)
	if not index or not cosmeticsEntries[index] then
		return
	end

	if cosmeticsFocusIndex ~= index and playSound then
		Audio:playSound("hover")
	end

	cosmeticsFocusIndex = index
	ensureCosmeticVisible(index)
end

local function moveCosmeticsFocus(delta)
	if not delta or delta == 0 or #cosmeticsEntries == 0 then
		return
	end

	local index = cosmeticsFocusIndex or 1
	index = max(1, min(#cosmeticsEntries, index + delta))
	setCosmeticsFocus(index, true)
end

local function activateCosmetic(index)
	local entry = index and cosmeticsEntries[index]
	if not entry or not entry.skin then
		return false
	end

	if not entry.skin.unlocked then
		return false
	end

	if not SnakeCosmetics or not SnakeCosmetics.setActiveSkin then
		return false
	end

	local skinId = entry.skin.id
	local changed = SnakeCosmetics:setActiveSkin(skinId)
	if changed then
		buildCosmeticsEntries()
		local newIndex
		for idx, cosmetic in ipairs(cosmeticsEntries) do
			if cosmetic.skin and cosmetic.skin.id == skinId then
				newIndex = idx
				break
			end
		end
		if newIndex then
			setCosmeticsFocus(newIndex)
		end
		local sw, sh = Screen:get()
		if sw and sh then
			updateScrollBounds(sw, sh)
		end
	end

	return changed
end

local function findTab(targetId)
	for index, tab in ipairs(tabs) do
		if tab.id == targetId then
			return tab, index
		end
	end

	return nil, nil
end

local function setActiveTab(tabId, focusOptions)
	if activeTab == tabId then
		return
	end

	activeTab = tabId

	if tabId == "stats" then
		buildStatsEntries()
	elseif tabId == "cosmetics" then
		buildCosmeticsEntries()
	else
		hoveredCosmeticIndex = nil
		pressedCosmeticIndex = nil
	end

	scrollOffset = 0
	local sw, sh = Screen:get()
	if sw and sh then
		updateScrollBounds(sw, sh)
	end

	local _, buttonIndex = findTab(tabId)
	if buttonIndex then
		local focusSource = focusOptions and focusOptions.focusSource
		local skipHistory = focusOptions and focusOptions.skipFocusHistory
		buttonList:setFocus(buttonIndex, focusSource, skipHistory)
	end

	if tabId == "cosmetics" and cosmeticsFocusIndex then
		ensureCosmeticVisible(cosmeticsFocusIndex)
	end
end

local function applyFocusedTab(button)
	if not button then
		return
	end

	local action = button.action or button.id
	if action == "tab_experience" or action == "progressionTab_experience" then
		setActiveTab("experience")
	elseif action == "tab_cosmetics" or action == "progressionTab_cosmetics" then
		setActiveTab("cosmetics")
	elseif action == "tab_stats" or action == "progressionTab_stats" then
		setActiveTab("stats")
	end
end

local function scrollBy(amount)
	if amount == 0 then
		return
	end

	if contentHeight <= viewportHeight then
		scrollOffset = 0
		return
	end

	scrollOffset = scrollOffset + amount
	if scrollOffset < minScrollOffset then
		scrollOffset = minScrollOffset
	elseif scrollOffset > 0 then
		scrollOffset = 0
	end
end

local function dpadScrollUp()
	if activeTab == "cosmetics" then
		moveCosmeticsFocus(-1)
	else
		scrollBy(SCROLL_SPEED)
		applyFocusedTab(buttonList:moveFocus(-1))
	end
end

local function dpadScrollDown()
	if activeTab == "cosmetics" then
		moveCosmeticsFocus(1)
	else
		scrollBy(-SCROLL_SPEED)
		applyFocusedTab(buttonList:moveFocus(1))
	end
end

local analogDirections = {
	dpup = {id = "analog_dpup", repeatable = true, action = dpadScrollUp},
	dpdown = {id = "analog_dpdown", repeatable = true, action = dpadScrollDown},
	dpleft = {
		id = "analog_dpleft",
		repeatable = false,
		action = function()
			applyFocusedTab(buttonList:moveFocus(-1))
		end,
	},
	dpright = {
		id = "analog_dpright",
		repeatable = false,
		action = function()
			applyFocusedTab(buttonList:moveFocus(1))
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

function ProgressionScreen:enter()
	Screen:update()
	UI.clearButtons()

	configureBackgroundEffect()

	trackEntries = MetaProgression:getUnlockTrack() or {}
	annotateTrackEntries()
	progressionState = MetaProgression:getState()
	buildStatsEntries()

	if SnakeCosmetics and SnakeCosmetics.load then
		local metaLevel = progressionState and progressionState.level or nil
		local ok, err = pcall(function()
			SnakeCosmetics:load({metaLevel = metaLevel})
		end)
		if not ok then
			print("[metaprogressionscreen] failed to load cosmetics:", err)
		end
	end

	buildCosmeticsEntries()

	local sw, sh = Screen:get()

	local buttons = {}
	local tabCount = #tabs
	local totalTabWidth = tabCount * TAB_WIDTH + max(0, tabCount - 1) * TAB_SPACING
	local startX = sw / 2 - totalTabWidth / 2

	for index, tab in ipairs(tabs) do
		local buttonId = "progressionTab_" .. tab.id
		tab.buttonId = buttonId
		local x = startX + (index - 1) * (TAB_WIDTH + TAB_SPACING)

		buttons[#buttons + 1] = {
			id = buttonId,
			x = x,
			y = TAB_Y,
			w = TAB_WIDTH,
			h = TAB_HEIGHT,
			text = Localization:get(tab.labelKey),
			action = tab.action,
		}
	end

	local backButtonY = sh - 90

	buttons[#buttons + 1] = {
		id = "progressionBack",
		x = sw / 2 - UI.spacing.buttonWidth / 2,
		y = backButtonY,
		w = UI.spacing.buttonWidth,
		h = UI.spacing.buttonHeight,
		textKey = "metaprogression.back_to_menu",
		text = Localization:get("metaprogression.back_to_menu"),
		action = "menu",
	}

	buttonList:reset(buttons)

	local _, activeIndex = findTab(activeTab)
	if activeIndex then
		buttonList:setFocus(activeIndex, nil, true)
	end

	scrollOffset = 0
	updateScrollBounds(sw, sh)
	resetHeldDpad()
	resetAnalogDirections()
end

function ProgressionScreen:leave()
	UI.clearButtons()
	resetHeldDpad()
	resetAnalogDirections()
end

function ProgressionScreen:update(dt)
	local mx, my = love.mouse.getPosition()
	buttonList:updateHover(mx, my)

	if activeTab == "cosmetics" then
		local sw = select(1, Screen:get())
		updateCosmeticsLayout(sw)

		hoveredCosmeticIndex = nil
		for index, entry in ipairs(cosmeticsEntries) do
			local bounds = entry.bounds
			if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, mx, my) then
				hoveredCosmeticIndex = index
				break
			end
		end

		if hoveredCosmeticIndex and hoveredCosmeticIndex ~= cosmeticsFocusIndex then
			cosmeticsFocusIndex = hoveredCosmeticIndex
		end
	end

	updateHeldDpad(dt)
end

local function handleConfirm()
	local action = buttonList:activateFocused()
	if action then
		Audio:playSound("click")
		if action == "tab_experience" then
			setActiveTab("experience")
		elseif action == "tab_cosmetics" then
			setActiveTab("cosmetics")
		elseif action == "tab_stats" then
			setActiveTab("stats")
		else
			return action
		end
	end
end

local function drawSummaryPanel(sw)
	if not progressionState then
		return
	end

	local contentWidth = CARD_WIDTH
	local contentHeight = SUMMARY_CONTENT_HEIGHT
	local frameWidth = contentWidth + WINDOW_PADDING_X * 2
	local frameHeight = contentHeight + WINDOW_PADDING_Y * 2
	local frameX = (sw - frameWidth) / 2
	local frameY = EXPERIENCE_SUMMARY_TOP - WINDOW_PADDING_Y
	local panelX = frameX + WINDOW_PADDING_X
	local panelY = EXPERIENCE_SUMMARY_TOP
	local padding = 24
	local border = Theme.panelBorder or {0.35, 0.3, 0.5, 1}
	local accentColor = Theme.progressColor or Theme.accentTextColor or {0.6, 0.8, 0.6, 1}
	local mutedColor = withAlpha(Theme.mutedTextColor or Theme.textColor, 0.85)

	drawWindowFrame(frameX, frameY, frameWidth, frameHeight, {
		accentHeight = 0,
		accentInsetY = WINDOW_PADDING_Y * 0.5,
		accentAlpha = 0.32,
	})

	local glow = withAlpha(lightenColor(accentColor, 0.45), 0.22)

	local levelText = Localization:get("metaprogression.level_label", {level = progressionState.level or 1})
	local totalText = Localization:get("metaprogression.total_xp", {total = progressionState.totalExperience or 0})

	local progressLabel
	local xpIntoLevel = progressionState.xpIntoLevel or 0
	local xpForNext = progressionState.xpForNext or 0
	local progressRatio = 1

	if xpForNext <= 0 then
		progressLabel = Localization:get("metaprogression.max_level")
		progressRatio = 1
	else
		local remaining = max(0, xpForNext - xpIntoLevel)
		progressLabel = Localization:get("metaprogression.next_unlock", {remaining = remaining})
		if xpForNext > 0 then
			progressRatio = min(1, max(0, xpIntoLevel / xpForNext))
		else
			progressRatio = 0
		end
	end

	local circleRadius = 52
	local circleCenterX = panelX + padding + circleRadius
	local circleCenterY = panelY + contentHeight / 2
	local outerRadius = circleRadius + 8

	love.graphics.setColor(withAlpha(darkenColor(Theme.panelColor or {0.18, 0.18, 0.22, 1}, 0.15), 0.92))
	love.graphics.circle("fill", circleCenterX, circleCenterY, outerRadius)

	local arcEndAngle = -pi / 2 + (pi * 2) * progressRatio

	love.graphics.setColor(withAlpha(glow, 1))
	love.graphics.setLineWidth(8)
	love.graphics.arc("line", "open", circleCenterX, circleCenterY, outerRadius, -pi / 2, arcEndAngle)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(withAlpha(lightenColor(Theme.panelColor or {0.18, 0.18, 0.22, 1}, 0.18), 0.96))
	love.graphics.circle("fill", circleCenterX, circleCenterY, circleRadius)

	love.graphics.setColor(withAlpha(border, 0.85))
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", circleCenterX, circleCenterY, circleRadius)
	love.graphics.setLineWidth(1)

	local levelValue = formatInteger(progressionState.level or 1)
	love.graphics.setFont(UI.fonts.timer)
	love.graphics.setColor(Theme.textColor)
	love.graphics.printf(levelValue, circleCenterX - circleRadius, circleCenterY - UI.fonts.timer:getHeight() / 2 - 4, circleRadius * 2, "center")

	local infoX = circleCenterX + circleRadius + padding
	local infoY = panelY + padding

	love.graphics.setFont(UI.fonts.button)
	love.graphics.setColor(Theme.textColor)
	love.graphics.print(levelText, infoX, infoY)
	infoY = infoY + UI.fonts.button:getHeight() + 6

	love.graphics.setFont(UI.fonts.heading)
	love.graphics.setColor(withAlpha(Theme.textColor, 0.95))
	love.graphics.print(totalText, infoX, infoY)
	infoY = infoY + UI.fonts.heading:getHeight() + 4

	love.graphics.setFont(UI.fonts.body)
	love.graphics.setColor(withAlpha(accentColor, 0.95))
	love.graphics.print(progressLabel, infoX, infoY)
	infoY = infoY + UI.fonts.body:getHeight() + 6

	if xpForNext > 0 then
		local progressText = string.format("%s / %s XP", formatInteger(xpIntoLevel), formatInteger(xpForNext))
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(mutedColor)
		love.graphics.print(progressText, infoX, infoY)
	else
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(mutedColor)
		love.graphics.print(Localization:get("metaprogression.max_level"), infoX, infoY)
	end

	local barX = infoX
	local barY = panelY + contentHeight - padding - 24
	local barWidth = contentWidth - (barX - panelX) - padding
	local barHeight = 18
	local barRadius = min(9, barHeight / 2)

	local function drawRoundedSegment(x, y, width, height, radius)
		if width <= 0 or height <= 0 then
			return
		end

		local clampedRadius = min(radius or 0, width / 2, height / 2)
		UI.drawRoundedRect(x, y, width, height, clampedRadius)
	end

	love.graphics.setColor(withAlpha(darkenColor(Theme.panelColor or {0.18, 0.18, 0.22, 1}, 0.35), 0.92))
	drawRoundedSegment(barX, barY, barWidth, barHeight, barRadius)

	local fillWidth = max(0, barWidth * progressRatio)
	if fillWidth > 0 then
		local fillColor = withAlpha(lightenColor(accentColor, 0.2), 0.95)
		love.graphics.setColor(fillColor)
		drawRoundedSegment(barX, barY, fillWidth, barHeight, barRadius)

		love.graphics.setColor(withAlpha(lightenColor(fillColor, 0.25), 0.55))
		drawRoundedSegment(barX, barY, fillWidth, barHeight * 0.55, barRadius)
	end

	love.graphics.setColor(withAlpha(border, 0.9))
	love.graphics.setLineWidth(1.6)
	love.graphics.rectangle("line", barX, barY, barWidth, barHeight, barRadius, barRadius)
	love.graphics.setLineWidth(1)

	if xpForNext > 0 then
		local percent = floor(progressRatio * 100 + 0.5)
		local badgeText = string.format("%d%%", percent)
		love.graphics.setFont(UI.fonts.caption)
		local badgePaddingX = 12
		local badgePaddingY = 6
		local badgeWidth = UI.fonts.caption:getWidth(badgeText) + badgePaddingX * 2
		local badgeHeight = UI.fonts.caption:getHeight() + badgePaddingY * 2
		local badgeX = barX + barWidth - badgeWidth
		local badgeY = barY - badgeHeight - 6

		love.graphics.setColor(withAlpha(lightenColor(Theme.panelColor or {0.18, 0.18, 0.22, 1}, 0.12), 0.9))
		UI.drawRoundedRect(badgeX, badgeY, badgeWidth, badgeHeight, badgeHeight / 2)

		love.graphics.setColor(withAlpha(accentColor, 0.95))
		love.graphics.printf(badgeText, badgeX, badgeY + badgePaddingY - 2, badgeWidth, "center")

		love.graphics.setColor(withAlpha(glow, 0.7))
		love.graphics.circle("fill", badgeX + badgeWidth * 0.25, badgeY + badgeHeight * 0.35, 3)
		love.graphics.circle("fill", badgeX + badgeWidth * 0.72, badgeY + badgeHeight * 0.65, 2)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function drawTrack(sw, sh)
	local listX = (sw - CARD_WIDTH) / 2
	local clipY = getListTop("experience")
	local clipH = viewportHeight

	if clipH <= 0 then
		return
	end

	local frameX = listX - WINDOW_PADDING_X
	local frameY = clipY - WINDOW_PADDING_Y
	local frameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local frameHeight = clipH + WINDOW_PADDING_Y * 2
	drawWindowFrame(frameX, frameY, frameWidth, frameHeight, {
		accentHeight = 0,
		accentInsetY = WINDOW_PADDING_Y * 0.5,
		accentAlpha = 0.18,
	})

	love.graphics.push()
	love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

	for index, entry in ipairs(trackEntries) do
		local cardHeight = entry.cardHeight or TRACK_CARD_MIN_HEIGHT
		local offset = entry.offset or ((index - 1) * (TRACK_CARD_MIN_HEIGHT + CARD_SPACING))
		local y = clipY + scrollOffset + offset
		local visibleThreshold = max(cardHeight, TRACK_CARD_MIN_HEIGHT)
		if y + cardHeight >= clipY - visibleThreshold and y <= clipY + clipH + visibleThreshold then
			local unlocked = entry.unlocked
			local panelColor = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
			local fillAlpha = unlocked and 0.9 or 0.7

			love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], fillAlpha)
			UI.drawRoundedRect(listX, y, CARD_WIDTH, cardHeight, 12)

			local borderColor = unlocked and (Theme.achieveColor or {0.55, 0.75, 0.55, 1}) or (Theme.lockedCardColor or {0.5, 0.35, 0.4, 1})
			love.graphics.setColor(borderColor)
			love.graphics.setLineWidth(2)
			love.graphics.rectangle("line", listX, y, CARD_WIDTH, cardHeight, 12, 12)

			local textX = listX + 24
			local textY = y + 20

			love.graphics.setFont(UI.fonts.button)
			love.graphics.setColor(Theme.textColor)
			local header = Localization:get("metaprogression.card_level", {level = entry.level or 0})
			love.graphics.print(header, textX, textY)

			love.graphics.setFont(UI.fonts.body)
			love.graphics.print(entry.name or "", textX, textY + 30)

			local wrapWidth = CARD_WIDTH - 48
			love.graphics.setColor(Theme.textColor)

			local desc = entry.description or ""
			local descY = textY + 58
			local descHeight = 0
			if desc ~= "" then
				local _, wrapped = UI.fonts.body:getWrap(desc, wrapWidth)
				local lineCount = max(1, #wrapped)
				descHeight = lineCount * UI.fonts.body:getHeight()
				love.graphics.setColor(Theme.textColor)
				love.graphics.setFont(UI.fonts.body)
				love.graphics.printf(desc, textX, descY, wrapWidth)
			end

			local infoY = descY + descHeight
			local rewards = entry.rewards or {}
			local smallFont = UI.fonts.small
			local lineHeight = smallFont:getHeight()

			if #rewards > 0 then
				infoY = infoY + 6
				love.graphics.setFont(smallFont)
				local rewardColor = Theme.progressColor or Theme.textColor
				love.graphics.setColor(withAlpha(rewardColor, 0.9))
				for _, line in ipairs(rewards) do
					love.graphics.printf("• " .. line, textX, infoY, wrapWidth, "left")
					infoY = infoY + lineHeight
				end
			end

		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

local function ensureCosmeticPreviewTrail()
	if cosmeticPreviewTrail and cosmeticPreviewBounds then
		return cosmeticPreviewTrail, cosmeticPreviewBounds
	end

	local segmentSize = SnakeUtils.SEGMENT_SIZE or 24
	local step = segmentSize * 0.85
	local amplitude = segmentSize * 2.4
	local wobble = segmentSize * 0.35
	local sampleCount = 18

	local rawPoints = {}
	for i = 0, sampleCount - 1 do
		local t = (sampleCount <= 1) and 0 or (i / (sampleCount - 1))
		local x = i * step
		local primaryWave = sin(t * pi * 1.35 + pi * 0.25)
		local secondaryWave = sin(t * pi * 3.1)
		local y = primaryWave * amplitude + secondaryWave * wobble
		rawPoints[#rawPoints + 1] = {x = x, y = y}
	end

	local trail = {}
	for i = #rawPoints, 1, -1 do
		local point = rawPoints[i]
		trail[#trail + 1] = {x = point.x, y = point.y}
	end

	local minX, maxX, minY, maxY
	for i = 1, #trail do
		local point = trail[i]
		local px, py = point.x, point.y
		if minX == nil or px < minX then minX = px end
		if maxX == nil or px > maxX then maxX = px end
		if minY == nil or py < minY then minY = py end
		if maxY == nil or py > maxY then maxY = py end
	end

	cosmeticPreviewTrail = trail
	cosmeticPreviewBounds = {
		minX = minX or 0,
		maxX = maxX or 0,
		minY = minY or 0,
		maxY = maxY or 0,
	}

	cosmeticPreviewBounds.width = (cosmeticPreviewBounds.maxX or 0) - (cosmeticPreviewBounds.minX or 0)
	cosmeticPreviewBounds.height = (cosmeticPreviewBounds.maxY or 0) - (cosmeticPreviewBounds.minY or 0)
	cosmeticPreviewBounds.centerX = (cosmeticPreviewBounds.minX + cosmeticPreviewBounds.maxX) * 0.5
	cosmeticPreviewBounds.centerY = (cosmeticPreviewBounds.minY + cosmeticPreviewBounds.maxY) * 0.5

	return cosmeticPreviewTrail, cosmeticPreviewBounds
end

function drawCosmeticSnakePreview(previewX, previewY, previewW, previewH, skin, palette)
	if not previewW or not previewH or previewW <= 0 or previewH <= 0 then
		return
	end

	local trail, bounds = ensureCosmeticPreviewTrail()
	if not trail or not bounds then
		return
	end

	local width = bounds.width or 0
	local height = bounds.height or 0
	if width <= 0 or height <= 0 then
		return
	end

	local marginX = max(12, previewW * 0.12)
	local marginY = max(10, previewH * 0.3)
	local scale = min((previewW - marginX) / width, (previewH - marginY) / height)
	if not scale or scale <= 0 then
		return
	end

	local scissorPad = 14
	love.graphics.push("all")
	love.graphics.setScissor(previewX - scissorPad, previewY - scissorPad, previewW + scissorPad * 2, previewH + scissorPad * 2)
	love.graphics.translate(previewX + previewW / 2, previewY + previewH / 2 + previewH * 0.04)
	love.graphics.scale(scale * 0.95)
	love.graphics.translate(-(bounds.centerX or 0), -(bounds.centerY or 0))
	SnakeDraw.run(trail, #trail, SnakeUtils.SEGMENT_SIZE, nil, nil, nil, nil, nil, {
		drawFace = false,
		skinOverride = skin,
		paletteOverride = palette,
		overlayEffect = palette and palette.overlay,
	})
	love.graphics.pop()
end

local function drawCosmeticsHeader(sw)
	local headerY = TAB_BOTTOM + 28
	love.graphics.setFont(UI.fonts.button)
	love.graphics.setColor(Theme.textColor)
	love.graphics.printf(Localization:get("metaprogression.cosmetics.header"), 0, headerY, sw, "center")

	if cosmeticsSummary.total > 0 then
		local summaryText = Localization:get("metaprogression.cosmetics.progress", {
			unlocked = cosmeticsSummary.unlocked or 0,
			total = cosmeticsSummary.total or 0,
		})
		local muted = Theme.mutedTextColor or {Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], (Theme.textColor[4] or 1) * 0.75}
		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
		love.graphics.printf(summaryText, 0, headerY + 38, sw, "center")

		if cosmeticsSummary.newUnlocks and cosmeticsSummary.newUnlocks > 0 then
			local key = (cosmeticsSummary.newUnlocks == 1) and "metaprogression.cosmetics.new_summary_single" or "metaprogression.cosmetics.new_summary_multiple"
			local accent = Theme.progressColor or Theme.accentTextColor or Theme.textColor
			love.graphics.setFont(UI.fonts.small)
			love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.92)
			love.graphics.printf(Localization:get(key, {count = cosmeticsSummary.newUnlocks}), 0, headerY + 60, sw, "center")
		end
	end

	drawCosmeticShaderShowcase(sw)
end

local function drawCosmeticsList(sw, sh)
	local clipY = getListTop("cosmetics")
	local clipH = viewportHeight

	if clipH <= 0 then
		return
	end

	updateCosmeticsLayout(sw)

	local listX = (sw - CARD_WIDTH) / 2

	local frameX = listX - WINDOW_PADDING_X
	local frameY = clipY - WINDOW_PADDING_Y
	local frameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local frameHeight = clipH + WINDOW_PADDING_Y * 2
	drawWindowFrame(frameX, frameY, frameWidth, frameHeight, {
		accentHeight = 0,
		accentInsetY = WINDOW_PADDING_Y * 0.5,
		accentAlpha = 0.24,
	})

	love.graphics.push()
	love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

	local listTop = clipY

	for index, entry in ipairs(cosmeticsEntries) do
		local y = listTop + scrollOffset + (index - 1) * (COSMETIC_CARD_HEIGHT + COSMETIC_CARD_SPACING)
		entry.bounds = entry.bounds or {}
		entry.bounds.x = listX
		entry.bounds.y = y
		entry.bounds.w = CARD_WIDTH
		entry.bounds.h = COSMETIC_CARD_HEIGHT

		if y + COSMETIC_CARD_HEIGHT >= clipY - COSMETIC_CARD_HEIGHT and y <= clipY + clipH + COSMETIC_CARD_HEIGHT then
			local skin = entry.skin or {}
			local unlocked = skin.unlocked
			local selected = skin.selected
			local isFocused = (index == cosmeticsFocusIndex)
			local isHovered = (index == hoveredCosmeticIndex)
			local isNew = entry.justUnlocked

			local basePanel = Theme.panelColor or {0.18, 0.18, 0.22, 0.9}
			local fillColor
			if selected then
				fillColor = lightenColor(basePanel, 0.28)
			elseif unlocked then
				fillColor = lightenColor(basePanel, 0.14)
			else
				fillColor = darkenColor(basePanel, 0.25)
			end

			if isFocused or isHovered then
				fillColor = lightenColor(fillColor, 0.06)
			end

			if isNew then
				fillColor = lightenColor(fillColor, 0.08)
			end

			love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.92)
			UI.drawRoundedRect(listX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14)

			local borderColor = Theme.panelBorder or {0.35, 0.30, 0.50, 1.0}
			if selected then
				borderColor = Theme.accentTextColor or borderColor
			elseif unlocked then
				borderColor = Theme.progressColor or borderColor
			elseif Theme.lockedCardColor then
				borderColor = Theme.lockedCardColor
			end

			if isNew then
				borderColor = lightenColor(borderColor, 0.12)
			end

			love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
			love.graphics.setLineWidth(isFocused and 3 or 2)
			love.graphics.rectangle("line", listX, y, CARD_WIDTH, COSMETIC_CARD_HEIGHT, 14, 14)

			if isFocused then
				local highlight = Theme.highlightColor or {1, 1, 1, 0.08}
				love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.08) + 0.04)
				UI.drawRoundedRect(listX + 6, y + 6, CARD_WIDTH - 12, COSMETIC_CARD_HEIGHT - 12, 12)
			end

			local palette = SnakeCosmetics:getPaletteForSkin(skin)
			local bodyColor = (palette and palette.body) or Theme.snakeDefault or {0.45, 0.85, 0.70, 1}
			local outlineColor = (palette and palette.outline) or {0.05, 0.15, 0.12, 1}
			local glowColor = (palette and palette.glow) or Theme.accentTextColor or {0.95, 0.76, 0.48, 1}
			local overlayEffect = palette and palette.overlay

			if not unlocked then
				bodyColor = darkenColor(bodyColor, 0.25)
				outlineColor = darkenColor(outlineColor, 0.2)
				glowColor = darkenColor(glowColor, 0.3)
				if overlayEffect then
					overlayEffect = shallowCopy(overlayEffect)
					if overlayEffect.opacity then
						overlayEffect.opacity = overlayEffect.opacity * 0.65
					end
					if overlayEffect.intensity then
						overlayEffect.intensity = overlayEffect.intensity * 0.6
					end
				end
			end

			local previewX = listX + 28
			local previewY = y + (COSMETIC_CARD_HEIGHT - COSMETIC_PREVIEW_HEIGHT) / 2
			local previewW = COSMETIC_PREVIEW_WIDTH
			local previewH = COSMETIC_PREVIEW_HEIGHT
			local previewRadius = previewH / 2

			local previewBase = Theme.panelColor or {0.18, 0.18, 0.22, 0.92}
			if unlocked then
				previewBase = lightenColor(previewBase, 0.16)
			else
				previewBase = darkenColor(previewBase, 0.08)
			end

			love.graphics.setColor(previewBase[1], previewBase[2], previewBase[3], (previewBase[4] or 1) * 0.9)
			UI.drawRoundedRect(previewX, previewY, previewW, previewH, previewRadius)

			if unlocked then
				love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], (glowColor[4] or 1) * 0.45)
				love.graphics.setLineWidth(6)
				love.graphics.rectangle("line", previewX - 6, previewY - 6, previewW + 12, previewH + 12, previewRadius + 6, previewRadius + 6)
			end

			love.graphics.setLineWidth(1)
			love.graphics.setColor(1, 1, 1, 1)

			local previewPalette = {
				body = bodyColor,
				outline = outlineColor,
				glow = glowColor,
				overlay = overlayEffect,
			}

			drawCosmeticSnakePreview(previewX, previewY, previewW, previewH, skin, previewPalette)

			if not unlocked then
				local overlayColor = withAlpha(Theme.bgColor or {0, 0, 0, 1}, 0.25)
				love.graphics.setColor(overlayColor[1], overlayColor[2], overlayColor[3], overlayColor[4] or 1)
				UI.drawRoundedRect(previewX, previewY, previewW, previewH, previewH / 2)

				local lockColor = Theme.lockedCardColor or {0.5, 0.35, 0.4, 1}
				local shackleColor = lightenColor(lockColor, 0.1)
				local bodyColor = darkenColor(lockColor, 0.12)
				local lockWidth = min(60, previewW * 0.78)
				local lockHeight = max(30, previewH * 0.74)
				local lockBodyHeight = lockHeight + 10
				local lockX = previewX + (previewW - lockWidth) / 2
				local lockY = previewY + (previewH - lockHeight) / 2 + 2
				local shackleWidth = lockWidth * 0.68
				local postWidth = max(3, lockWidth * 0.16)
				local postHeight = max(lockHeight * 0.75, lockHeight - 3)
				local shackleX = previewX + (previewW - shackleWidth) / 2
				local postY = lockY - postHeight
				local topCenterY = postY
				local topRectX = shackleX + postWidth / 2
				local topRectWidth = shackleWidth - postWidth
				local topRectY = topCenterY - postWidth / 2

				-- subtle drop shadow behind the lock to make it pop from the overlay
				local shadowOffsetX, shadowOffsetY = 3, 4
				local shadowColor = withAlpha(Theme.shadowColor or {0, 0, 0, 1}, 0.28)
				love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
				UI.drawRoundedRect(lockX + shadowOffsetX, lockY + shadowOffsetY, lockWidth, lockBodyHeight, 4)
				love.graphics.rectangle("fill", shackleX + shadowOffsetX, postY + shadowOffsetY, postWidth, postHeight)
				love.graphics.rectangle("fill", shackleX + shackleWidth - postWidth + shadowOffsetX, postY + shadowOffsetY, postWidth, postHeight)
				love.graphics.rectangle("fill", topRectX + shadowOffsetX, topRectY + shadowOffsetY, topRectWidth, postWidth)
				love.graphics.circle("fill", topRectX + shadowOffsetX, topCenterY + shadowOffsetY, postWidth / 2)
				love.graphics.circle("fill", topRectX + topRectWidth + shadowOffsetX, topCenterY + shadowOffsetY, postWidth / 2)

				love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], (bodyColor[4] or 1) * 0.9)
				UI.drawRoundedRect(lockX, lockY, lockWidth, lockBodyHeight, 4)

				-- vertical posts
				love.graphics.setColor(shackleColor[1], shackleColor[2], shackleColor[3], shackleColor[4] or 1)
				love.graphics.rectangle("fill", shackleX, postY, postWidth, postHeight)
				love.graphics.rectangle("fill", shackleX + shackleWidth - postWidth, postY, postWidth, postHeight)

				-- straight top bar with rounded corners similar to the snake styling
				love.graphics.rectangle("fill", topRectX, topRectY, topRectWidth, postWidth)
				love.graphics.circle("fill", topRectX, topCenterY, postWidth / 2)
				love.graphics.circle("fill", topRectX + topRectWidth, topCenterY, postWidth / 2)

				local keyholeWidth = max(5, lockWidth * 0.16 - 4)
				local keyholeHeight = max(9, lockHeight * 0.44)
				local keyholeX = previewX + previewW / 2 - keyholeWidth / 2
				local keyholeY = lockY + lockHeight / 2 - keyholeHeight / 2
				local keyholeColor = Theme.bgColor or {0, 0, 0, 1}
				love.graphics.setColor(keyholeColor[1], keyholeColor[2], keyholeColor[3], (keyholeColor[4] or 1) * 0.9)
				love.graphics.rectangle("fill", keyholeX, keyholeY, keyholeWidth, keyholeHeight, 2, 2)
			end

			if isNew then
				local badgeText = Localization:get("metaprogression.cosmetics.new_badge")
				local badgeFont = UI.fonts.caption
				love.graphics.setFont(badgeFont)
				local textWidth = badgeFont:getWidth(badgeText)
				local paddingX = 18
				local paddingY = 6
				local badgeWidth = textWidth + paddingX
				local badgeHeight = badgeFont:getHeight() + paddingY
				local badgeX = listX + CARD_WIDTH - badgeWidth - 24
				local badgeY = y - badgeHeight / 2
				local accent = Theme.progressColor or Theme.accentTextColor or {1, 1, 1, 1}
				love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.95)
				UI.drawRoundedRect(badgeX, badgeY, badgeWidth, badgeHeight, badgeHeight / 2)

				local badgeTextColor = Theme.bgColor or {0, 0, 0, 1}
				love.graphics.setColor(badgeTextColor[1], badgeTextColor[2], badgeTextColor[3], badgeTextColor[4] or 1)
				love.graphics.printf(badgeText, badgeX, badgeY + paddingY / 2, badgeWidth, "center")
			end

			local textX = previewX + previewW + 24
			local textWidth = CARD_WIDTH - (textX - listX) - 28

			love.graphics.setFont(UI.fonts.button)
			love.graphics.setColor(Theme.textColor)
			love.graphics.printf(skin.name or skin.id or "", textX, y + 20, textWidth, "left")

			love.graphics.setFont(UI.fonts.body)
			love.graphics.setColor(Theme.mutedTextColor or Theme.textColor)
			love.graphics.printf(skin.description or "", textX, y + 52, textWidth, "left")

			local statusColor = entry.statusColor or Theme.textColor
			love.graphics.setFont(UI.fonts.caption)
			love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], statusColor[4] or 1)
			love.graphics.printf(entry.statusLabel or "", textX, y + COSMETIC_CARD_HEIGHT - 40, textWidth, "left")

			if entry.detailText and entry.detailText ~= "" then
				love.graphics.setFont(UI.fonts.small)
				love.graphics.setColor(Theme.mutedTextColor or Theme.textColor)
				love.graphics.printf(entry.detailText, textX, y + COSMETIC_CARD_HEIGHT - 24, textWidth, "left")
			end
		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

local function drawStatsHeader(sw)
	-- Intentionally left blank: the stats header and subheader have been removed.
end

local function drawStatsSummary(sw)
	if #statsHighlights == 0 then
		return
	end

	local totalWidth = #statsHighlights * STATS_SUMMARY_CARD_WIDTH + max(0, #statsHighlights - 1) * STATS_SUMMARY_CARD_SPACING
	local frameWidth = totalWidth + WINDOW_PADDING_X * 2
	local frameHeight = STATS_SUMMARY_CARD_HEIGHT + WINDOW_PADDING_Y * 2
	local frameX = sw / 2 - frameWidth / 2
	local frameY = viewportTop - WINDOW_PADDING_Y
	drawWindowFrame(frameX, frameY, frameWidth, frameHeight, {
		accentHeight = 0,
		accentInsetY = WINDOW_PADDING_Y * 0.35,
		accentAlpha = 0.26,
	})

	local startX = frameX + WINDOW_PADDING_X
	local cardY = frameY + WINDOW_PADDING_Y
	local basePanel = Theme.panelColor or {0.18, 0.18, 0.22, 0.92}
	local accent = Theme.progressColor or Theme.accentTextColor or Theme.textColor or {1, 1, 1, 1}
	local muted = Theme.mutedTextColor or {Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], (Theme.textColor[4] or 1) * 0.8}

	for index, entry in ipairs(statsHighlights) do
		local cardX = startX + (index - 1) * (STATS_SUMMARY_CARD_WIDTH + STATS_SUMMARY_CARD_SPACING)
		local fillColor = lightenColor(basePanel, 0.20 + 0.05 * ((index - 1) % 2))

		love.graphics.setColor(0, 0, 0, 0.28)
		UI.drawRoundedRect(cardX + 4, cardY + STATS_SUMMARY_SHADOW_OFFSET, STATS_SUMMARY_CARD_WIDTH, STATS_SUMMARY_CARD_HEIGHT, 14)

		love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.96)
		UI.drawRoundedRect(cardX, cardY, STATS_SUMMARY_CARD_WIDTH, STATS_SUMMARY_CARD_HEIGHT, 14)

		love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.22)
		love.graphics.rectangle("fill", cardX, cardY, STATS_SUMMARY_CARD_WIDTH, 6, 14, 14)

		love.graphics.setFont(UI.fonts.caption)
		love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
		love.graphics.printf(entry.label or "", cardX + 20, cardY + 18, STATS_SUMMARY_CARD_WIDTH - 40, "left")

		love.graphics.setFont(UI.fonts.heading)
		love.graphics.setColor(Theme.textColor)
		love.graphics.printf(entry.valueText or "0", cardX + 20, cardY + 42, STATS_SUMMARY_CARD_WIDTH - 40, "left")
	end
end

local function drawStatsList(sw, sh)
	local clipY = viewportTop
	local clipH = viewportHeight

	if clipH <= 0 then
		return
	end

	local listX = (sw - CARD_WIDTH) / 2

	local frameX = listX - WINDOW_PADDING_X
	local frameY = clipY - WINDOW_PADDING_Y
	local frameWidth = CARD_WIDTH + WINDOW_PADDING_X * 2
	local frameHeight = clipH + WINDOW_PADDING_Y * 2
	drawWindowFrame(frameX, frameY, frameWidth, frameHeight, {
		accentHeight = 0,
		accentInsetY = WINDOW_PADDING_Y * 0.5,
		accentAlpha = 0.18,
	})

	love.graphics.push()
	love.graphics.setScissor(listX - 20, clipY - 10, CARD_WIDTH + 40, clipH + 20)

	if #statsEntries == 0 then
		love.graphics.setFont(UI.fonts.body)
		love.graphics.setColor(Theme.textColor)
		love.graphics.printf(Localization:get("metaprogression.stats_empty"), listX, clipY + viewportHeight / 2 - 12, CARD_WIDTH, "center")
	else
		local accent = Theme.progressColor or Theme.accentTextColor or Theme.textColor or {1, 1, 1, 1}
		local muted = Theme.mutedTextColor or {Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], (Theme.textColor[4] or 1) * 0.8}

		for index, entry in ipairs(statsEntries) do
			local y = viewportTop + scrollOffset + (index - 1) * (STAT_CARD_HEIGHT + STAT_CARD_SPACING)
			if y + STAT_CARD_HEIGHT >= clipY - STAT_CARD_HEIGHT and y <= clipY + clipH + STAT_CARD_HEIGHT then
				local basePanel = Theme.panelColor or {0.18, 0.18, 0.22, 0.92}
				local tintOffset = ((index % 2) == 0) and 0.08 or 0.04
				local fillColor = lightenColor(basePanel, 0.16 + tintOffset)

				love.graphics.setColor(0, 0, 0, 0.26)
				UI.drawRoundedRect(listX + 4, y + STAT_CARD_SHADOW_OFFSET, CARD_WIDTH, STAT_CARD_HEIGHT, 12)

				love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.95)
				UI.drawRoundedRect(listX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12)

				local borderColor = Theme.panelBorder or {0.35, 0.30, 0.50, 1.0}
				love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * 0.8)
				love.graphics.setLineWidth(2)
				love.graphics.rectangle("line", listX, y, CARD_WIDTH, STAT_CARD_HEIGHT, 12, 12)
				love.graphics.setLineWidth(1)

				love.graphics.setColor(accent[1], accent[2], accent[3], (accent[4] or 1) * 0.18)
				love.graphics.rectangle("fill", listX + 20, y + STAT_CARD_HEIGHT - 8, CARD_WIDTH - 40, 4, 2, 2)

				local labelX = listX + 32
				local valueAreaX = listX + CARD_WIDTH * 0.55
				local valueAreaWidth = CARD_WIDTH - (valueAreaX - listX) - 32
				local labelWidth = valueAreaX - labelX - 16

				love.graphics.setFont(UI.fonts.caption)
				love.graphics.setColor(muted[1], muted[2], muted[3], muted[4] or 1)
				love.graphics.printf(entry.label, labelX, y + 12, labelWidth, "left")

				love.graphics.setFont(UI.fonts.subtitle)
				love.graphics.setColor(Theme.textColor)
				love.graphics.printf(entry.valueText, valueAreaX, y + 26, valueAreaWidth, "right")
			end
		end
	end

	love.graphics.setScissor()
	love.graphics.pop()
end

function ProgressionScreen:draw()
	local sw, sh = Screen:get()

	drawBackground(sw, sh)

	love.graphics.setFont(UI.fonts.title)
	love.graphics.setColor(Theme.textColor)
	love.graphics.printf(Localization:get("metaprogression.title"), 0, 48, sw, "center")

	if activeTab == "experience" then
		drawSummaryPanel(sw)
		drawTrack(sw, sh)
	elseif activeTab == "cosmetics" then
		drawCosmeticsHeader(sw)
		drawCosmeticsList(sw, sh)
	else
		drawStatsHeader(sw)
		drawStatsSummary(sw)
		drawStatsList(sw, sh)
	end

	buttonList:syncUI()

	for _, tab in ipairs(tabs) do
		local id = tab.buttonId
		if id then
			local button = UI.buttons[id]
			if button then
				button.toggled = (activeTab == tab.id) or nil
			end
		end
	end

	for _, button in buttonList:iter() do
		UI.drawButton(button.id)
	end
end

function ProgressionScreen:mousepressed(x, y, button)
	buttonList:mousepressed(x, y, button)

	if activeTab == "cosmetics" and button == 1 then
		local sw = select(1, Screen:get())
		updateCosmeticsLayout(sw)

		pressedCosmeticIndex = nil
		for index, entry in ipairs(cosmeticsEntries) do
			local bounds = entry.bounds
			if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
				pressedCosmeticIndex = index
				setCosmeticsFocus(index)
				break
			end
		end
	end
end

function ProgressionScreen:mousereleased(x, y, button)
	local action = buttonList:mousereleased(x, y, button)
	if action then
		Audio:playSound("click")
		if action == "tab_experience" then
			setActiveTab("experience", {focusSource = "mouse", skipFocusHistory = true})
		elseif action == "tab_cosmetics" then
			setActiveTab("cosmetics", {focusSource = "mouse", skipFocusHistory = true})
		elseif action == "tab_stats" then
			setActiveTab("stats", {focusSource = "mouse", skipFocusHistory = true})
		else
			return action
		end
		return
	end


	if activeTab ~= "cosmetics" or button ~= 1 then
		pressedCosmeticIndex = nil
		return
	end

	local sw = select(1, Screen:get())
	updateCosmeticsLayout(sw)

	local releasedIndex
	for index, entry in ipairs(cosmeticsEntries) do
		local bounds = entry.bounds
		if bounds and UI.isHovered(bounds.x, bounds.y, bounds.w, bounds.h, x, y) then
			releasedIndex = index
			break
		end
	end

	if releasedIndex and releasedIndex == pressedCosmeticIndex then
		setCosmeticsFocus(releasedIndex)
		local changed = activateCosmetic(releasedIndex)
		Audio:playSound(changed and "click" or "hover")
	end

	pressedCosmeticIndex = nil
end

function ProgressionScreen:wheelmoved(_, dy)
	scrollBy(dy * SCROLL_SPEED)
end

function ProgressionScreen:keypressed(key)
	if activeTab == "cosmetics" then
		if key == "up" then
			moveCosmeticsFocus(-1)
			return
		elseif key == "down" then
			moveCosmeticsFocus(1)
			return
		end
	end

	if key == "up" then
		scrollBy(SCROLL_SPEED)
		applyFocusedTab(buttonList:moveFocus(-1))
	elseif key == "down" then
		scrollBy(-SCROLL_SPEED)
		applyFocusedTab(buttonList:moveFocus(1))
	elseif key == "left" then
		applyFocusedTab(buttonList:moveFocus(-1))
	elseif key == "right" then
		applyFocusedTab(buttonList:moveFocus(1))
	elseif key == "pageup" then
		scrollBy(viewportHeight)
	elseif key == "pagedown" then
		scrollBy(-viewportHeight)
	elseif key == "escape" or key == "backspace" then
		Audio:playSound("click")
		return "menu"
	elseif key == "return" or key == "kpenter" or key == "space" then
		if activeTab == "cosmetics" and cosmeticsFocusIndex then
			local changed = activateCosmetic(cosmeticsFocusIndex)
			Audio:playSound(changed and "click" or "hover")
			return
		end
		return handleConfirm()
	end
end

function ProgressionScreen:gamepadpressed(_, button)
	if button == "dpup" then
		dpadScrollUp()
		startHeldDpad(button, dpadScrollUp)
	elseif button == "dpleft" then
		applyFocusedTab(buttonList:moveFocus(-1))
	elseif button == "dpdown" then
		dpadScrollDown()
		startHeldDpad(button, dpadScrollDown)
	elseif button == "dpright" then
		applyFocusedTab(buttonList:moveFocus(1))
	elseif button == "a" or button == "start" then
		if activeTab == "cosmetics" and cosmeticsFocusIndex then
			local changed = activateCosmetic(cosmeticsFocusIndex)
			Audio:playSound(changed and "click" or "hover")
			return
		end
		return handleConfirm()
	elseif button == "b" then
		Audio:playSound("click")
		return "menu"
	end
end

ProgressionScreen.joystickpressed = ProgressionScreen.gamepadpressed

function ProgressionScreen:gamepadaxis(_, axis, value)
	handleGamepadAxis(axis, value)
end

ProgressionScreen.joystickaxis = ProgressionScreen.gamepadaxis

function ProgressionScreen:gamepadreleased(_, button)
	if button == "dpup" or button == "dpdown" then
		stopHeldDpad(button)
	end
end

ProgressionScreen.joystickreleased = ProgressionScreen.gamepadreleased

function ProgressionScreen:resize()
	local sw, sh = Screen:get()
	updateScrollBounds(sw, sh)
end

return ProgressionScreen
