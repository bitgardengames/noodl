local Screen = require("screen")
local Audio = require("audio")
local Theme = require("theme")
local MenuScene = require("menuscene")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local Easing = require("easing")

local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min

local GameOver = {isVictory = false}

local buttonDefs = {}

local ANALOG_DEADZONE = 0.3
local TEXT_SHADOW_OFFSET = 2
local TITLE_SHADOW_OFFSET = 3
local CONTENT_ANIM_DURATION = 0.65
local BUTTON_ANIM_DURATION = 0.5

local function getLocalizedOrFallback(key, fallback)
	if not key then
		return fallback
	end

	local localized = Localization:get(key)
	if localized == nil or localized == "" or localized == key then
		return fallback
	end

	return localized
end

local function getBackgroundColor()
	return (UI.colors and UI.colors.background) or Theme.bgColor
end

local function withAlpha(color, alpha)
	alpha = alpha or 1
	if not color then
		return {1, 1, 1, alpha}
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		(color[4] or 1) * alpha,
	}
end

local function formatTime(seconds)
	if not seconds or seconds <= 0 then
		return "0:00"
	end

	local totalSeconds = floor(seconds + 0.5)
	local minutes = floor(totalSeconds / 60)
	local remaining = totalSeconds % 60

	return string.format("%d:%02d", minutes, remaining)
end

function GameOver:getMenuBackgroundOptions()
	return MenuScene.getPlainBackgroundOptions(nil, getBackgroundColor())
end

local function drawBackground(sw, sh)
	if not MenuScene.shouldDrawBackground() then
		return
	end

	MenuScene.drawBackground(sw, sh, GameOver:getMenuBackgroundOptions())
end

local function pickDeathMessage(cause)
	local deathTable = Localization:getTable("gameover.deaths") or {}
	local entries = deathTable[cause] or deathTable.unknown or {}
	if #entries == 0 then
		return Localization:get("gameover.default_message")
	end

	return entries[love.math.random(#entries)]
end

local fontTitle
local fontScore
local fontScoreValue
local fontSmall
local fontMessage
local fontBadge
local fontProgressTitle
local fontProgressValue
local fontProgressSmall
local fontProgressLabel
local stats = {}
local buttonList = ButtonList.new()
local analogAxisDirections = {horizontal = nil, vertical = nil}

local analogAxisActions = {
	horizontal = {
		negative = function()
			buttonList:moveFocus(-1)
		end,
		positive = function()
			buttonList:moveFocus(1)
		end,
	},
	vertical = {
		negative = function()
			buttonList:moveFocus(-1)
		end,
		positive = function()
			buttonList:moveFocus(1)
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

local function handleAnalogAxis(axis, value)
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
			action()
		end
	end
end
local function getButtonMetrics()
	local spacing = UI.spacing or {}
	return spacing.buttonWidth or 260, spacing.buttonHeight or 56, spacing.buttonSpacing or 24
end

local function getSectionPadding()
	return (UI.scaled and UI.scaled(20, 14)) or 20
end

local function getSectionSpacing()
	return (UI.scaled and UI.scaled(22, 16)) or 22
end

local function getSectionInnerSpacing()
	return (UI.scaled and UI.scaled(12, 8)) or 12
end

local function getButtonAnimationOffset(self)
	local _, buttonHeight = getButtonMetrics()
	local distance = (buttonHeight or 56) * 1.1
	local progress = Easing.clamp01((self.buttonAnim or 0) / BUTTON_ANIM_DURATION)
	local eased = Easing.easeOutCubic(progress)
	return (1 - eased) * distance
end

local function getContentAnimationProgress(self)
	local progress = Easing.clamp01((self.contentAnim or 0) / CONTENT_ANIM_DURATION)
	return Easing.easeOutCubic(progress)
end

local function getStaggeredAlpha(progress, delay, duration)
	local adjusted = Easing.clamp01((progress - (delay or 0)) / (duration or 1))
	return Easing.easeOutCubic(adjusted)
end

local function ensureFonts()
	fontTitle = UI.fonts.title or love.graphics.getFont()
	fontScore = UI.fonts.heading or love.graphics.getFont()
	fontScoreValue = UI.fonts.display or fontScore
	fontSmall = UI.fonts.body or love.graphics.getFont()
	fontMessage = UI.fonts.body or love.graphics.getFont()
	fontProgressValue = UI.fonts.subtitle or fontScore
	fontProgressSmall = UI.fonts.small or fontSmall
	fontProgressLabel = UI.fonts.caption or fontProgressSmall
end

local function handleButtonAction(_, action)
	return action
end

local function getHighlightStats(self, animProgress)
	local scoreLabel = getLocalizedOrFallback("gameover.score_label", "Score")
	local bestLabel = getLocalizedOrFallback("gameover.stats_best_label", "Best")
	local applesLabel = getLocalizedOrFallback("gameover.stats_apples_label", "Fruit")

	local scoreValue = stats.score or 0
	if self.isNewHighScore and scoreValue > 0 then
		local eased = Easing.easeOutBack(animProgress or 0)
		scoreValue = floor(scoreValue * eased + 0.5)
	end

	return {
		{
			label = scoreLabel,
			value = tostring(scoreValue),
			highlight = self.isNewHighScore,
		},
		{
			label = bestLabel,
			value = tostring(stats.highScore or 0),
		},
		{
			label = applesLabel,
			value = tostring(stats.apples or 0),
		},
	}
end

local function getDetailedStats()
	local timeLabel = getLocalizedOrFallback("gameover.stats_time_label", "Time Alive")
	local floorsLabel = getLocalizedOrFallback("gameover.stats_floors_label", "Floors")
	local combosLabel = getLocalizedOrFallback("gameover.stats_combos_label", "Combos")
	local comboBestLabel = getLocalizedOrFallback("gameover.stats_best_combo_label", "Best Combo")

	return {
		{label = timeLabel, value = formatTime(stats.timeAlive)},
		{label = floorsLabel, value = tostring(stats.floorsCleared or 0)},
		{label = combosLabel, value = tostring(stats.combosTriggered or 0)},
		{label = comboBestLabel, value = tostring(stats.bestComboStreak or 0)},
	}
end

local function getDetailColumns(entryCount)
	if not entryCount or entryCount <= 0 then
		return 0
	end

	if entryCount <= 4 then
		return 2
	end

	return 3
end

local function drawHighlightStats(self, entries, x, y, width, sectionPadding, innerSpacing, alpha)
	if not entries or #entries == 0 then
		return
	end

	local availableWidth = max(0, width - sectionPadding * 2)
	local columnWidth = availableWidth / #entries

	local labelFont = fontProgressLabel or fontProgressSmall
	local valueFont = fontScoreValue or fontScore
	local labelY = y + sectionPadding
	local valueY = labelY + labelFont:getHeight() + innerSpacing

	local mutedColor = withAlpha(UI.colors.mutedText or UI.colors.text, alpha)
	local baseValueColor = withAlpha(UI.colors.text or {1, 1, 1, 1}, alpha)
	local highlightColor = Theme.progressColor or UI.colors.highlight or baseValueColor

	for index, entry in ipairs(entries) do
		local entryX = x + sectionPadding + (index - 1) * columnWidth
		UI.drawLabel(entry.label or "", entryX, labelY, columnWidth, "center", {
			font = labelFont,
			color = mutedColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)

		local valueText = entry.value or "0"
		local color = baseValueColor
		if entry.highlight then
			color = withAlpha(highlightColor, alpha)
		end

		UI.drawLabel(valueText, entryX, valueY, columnWidth, "center", {
			font = valueFont,
			color = color,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)
	end
end

local function drawDetailedStats(entries, x, y, width, sectionPadding, innerSpacing, alpha, columnCount)
	if not entries or #entries == 0 then
		return 0
	end

	local availableWidth = max(0, width - sectionPadding * 2)
	local columns = columnCount or getDetailColumns(#entries)
	local columnWidth = availableWidth / columns
	local labelFont = fontProgressLabel or fontProgressSmall
	local valueFont = fontProgressValue or fontSmall
	local rowHeight = (labelFont:getHeight() or 0) + innerSpacing + (valueFont:getHeight() or 0)
	local rows = ceil(#entries / columns)
	local mutedColor = withAlpha(UI.colors.mutedText or UI.colors.text, alpha)
	local valueColor = withAlpha(UI.colors.text or {1, 1, 1, 1}, alpha)

	for index, entry in ipairs(entries) do
		local column = (index - 1) % columns
		local row = floor((index - 1) / columns)
		local entryX = x + sectionPadding + column * columnWidth
		local entryY = y + sectionPadding + row * (rowHeight + innerSpacing)

		UI.drawLabel(entry.label or "", entryX, entryY, columnWidth, "center", {
			font = labelFont,
			color = mutedColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)

		local valueText = entry.value or "0"
		UI.drawLabel(valueText, entryX, entryY + labelFont:getHeight() + innerSpacing, columnWidth, "center", {
			font = valueFont,
			color = valueColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)
	end

	return sectionPadding * 2 + rows * rowHeight + max(0, (rows - 1) * innerSpacing)
end

function GameOver:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)
	local contentHeight = self.summaryPanelHeight or 0
	local padding = self.contentPadding or 24
	local buttonGap = buttonSpacing or 0

	local layout = UI.getMenuLayout(sw, sh) or {}
	local topMargin = layout.bodyTop or layout.stackTop or padding * 1.5
	local bottomMargin = layout.marginBottom or padding * 2
	local buttonStartY = (layout.bottomY or (sh - bottomMargin)) - totalButtonHeight

	buttonStartY = max(buttonStartY, topMargin + contentHeight + buttonGap)

	local availableHeight = max(0, buttonStartY - topMargin - buttonGap)
	local panelY = topMargin

	if contentHeight < availableHeight then
		panelY = topMargin + (availableHeight - contentHeight) * 0.2
	end

	local buttonY = buttonStartY

	return panelY, buttonY
end

function GameOver:updateLayoutMetrics()
	ensureFonts()

	local sw, sh = Screen:get()
	if not sw or not sh then
		return false
	end

	local changed = (self._cachedWidth ~= sw) or (self._cachedHeight ~= sh)
	self._cachedWidth, self._cachedHeight = sw, sh

	local margin = 24
	local fallbackMaxAllowed = max(40, sw - margin)
	local fallbackSafe = max(80, sw - margin * 2)
	fallbackSafe = min(fallbackSafe, fallbackMaxAllowed)
	local fallbackPreferred = min(sw * 0.72, 640)
	local fallbackMin = min(320, fallbackSafe)
	local contentWidth = max(fallbackMin, min(fallbackPreferred, fallbackSafe))

	local padding = self.contentPadding or 24
	local sectionPadding = getSectionPadding()
	local sectionSpacing = getSectionSpacing()
	local innerSpacing = getSectionInnerSpacing()

	local innerWidth = max(0, contentWidth - padding * 2)
	local wrapLimit = max(0, innerWidth - sectionPadding * 2)
	local messageText = self.deathMessage or Localization:get("gameover.default_message")

	local _, wrappedLines = fontMessage:getWrap(messageText or "", wrapLimit)
	local linesHeight = max(1, #(wrappedLines or {}))
	local messageHeight = (fontMessage:getHeight() or 0) * linesHeight
	local messagePanelHeight = sectionPadding * 2 + messageHeight

	local labelFont = fontProgressLabel or fontProgressSmall
	local valueFont = fontScoreValue or fontScore
	local scorePanelHeight = sectionPadding * 2
	scorePanelHeight = scorePanelHeight + (labelFont and labelFont:getHeight() or 0)
	scorePanelHeight = scorePanelHeight + innerSpacing + (valueFont and valueFont:getHeight() or 0)

	local detailEntries = getDetailedStats()
	local detailValueFont = fontProgressValue or fontProgressSmall
	local detailLabelHeight = labelFont and labelFont:getHeight() or 0
	local detailValueHeight = detailValueFont and detailValueFont:getHeight() or 0
	local detailRowHeight = detailLabelHeight + innerSpacing + detailValueHeight
	local detailColumns = getDetailColumns(detailEntries and #detailEntries or 0)
	local detailRows = (detailEntries and #detailEntries or 0) > 0 and ceil(#detailEntries / max(1, detailColumns)) or 0
	local detailPanelHeight = 0
	if detailRows > 0 then
		detailPanelHeight = sectionPadding * 2 + detailRows * detailRowHeight + max(0, (detailRows - 1) * innerSpacing)
	end

	local panelHeight = padding + messagePanelHeight + sectionSpacing + scorePanelHeight
	if detailPanelHeight > 0 then
		panelHeight = panelHeight + sectionSpacing + detailPanelHeight
	end
	panelHeight = panelHeight + padding

	self.contentWidth = contentWidth
	self.innerContentWidth = innerWidth
	self.wrapLimit = wrapLimit
	self.sectionPaddingValue = sectionPadding
	self.sectionSpacingValue = sectionSpacing
	self.sectionInnerSpacingValue = innerSpacing
	self.messagePanelHeight = messagePanelHeight
	self.scorePanelHeight = scorePanelHeight
	self.detailPanelHeight = detailPanelHeight
	self.detailColumns = detailColumns
	self.summaryPanelHeight = panelHeight

	return changed
end

function GameOver:updateButtonLayout()
	local sw, sh = Screen:get()
	local buttonWidth, buttonHeight, buttonSpacing = getButtonMetrics()
	local totalButtonHeight = #buttonDefs * buttonHeight + max(0, (#buttonDefs - 1) * buttonSpacing)
	local panelY, buttonStartY = self:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)
	local animOffset = getButtonAnimationOffset(self)

	local x = (sw - buttonWidth) / 2
	local defs = {}

	for i, entry in ipairs(buttonDefs) do
		defs[i] = {
			id = entry.id or ("button" .. i),
			x = x,
			y = buttonStartY + (i - 1) * (buttonHeight + buttonSpacing) + animOffset,
			w = buttonWidth,
			h = buttonHeight,
			textKey = entry.textKey,
			text = entry.textKey and Localization:get(entry.textKey) or entry.text,
			action = entry.action,
		}
	end

	buttonList:reset(defs)
	self._panelY = panelY
	self._lastButtonAnimOffset = animOffset
end

function GameOver:enter(data)
	data = data or {}

	UI.clearButtons()
	ensureFonts()
	resetAnalogAxis()

	for key in pairs(stats) do
		stats[key] = nil
	end

	stats.score = data.score or 0
	stats.highScore = data.highScore or stats.score or 0
	stats.apples = data.apples or 0
	stats.timeAlive = (data.stats and data.stats.timeAlive) or 0
	stats.tilesTravelled = (data.stats and data.stats.tilesTravelled) or 0
	stats.combosTriggered = (data.stats and data.stats.combosTriggered) or 0
	stats.bestComboStreak = (data.stats and data.stats.bestComboStreak) or 0
	stats.floorsCleared = (data.stats and data.stats.floorsCleared) or 0
	stats.deepestFloor = (data.stats and data.stats.deepestFloor) or 0
	stats.dragonfruit = (data.stats and data.stats.dragonfruit) or 0

	self.isNewHighScore = not not data.isHighScore
	if data.isHighScore == nil then
		self.isNewHighScore = (stats.score or 0) > 0 and (stats.score or 0) >= (stats.highScore or 0)
	end

	self.isVictory = not not data.won
	self.deathCause = data.cause or "unknown"
	self.deathMessage = data.endingMessage or pickDeathMessage(self.deathCause)
	self.customTitle = data.storyTitle

	buttonDefs = {
		{id = "playAgain", textKey = "gameover.play_again", action = "game"},
		{id = "quitToMenu", textKey = "gameover.quit_to_menu", action = "menu"},
	}

	self._cachedWidth, self._cachedHeight = nil, nil
	self.contentAnim = 0
	self.buttonAnim = 0
	self._lastButtonAnimOffset = nil
	self:updateLayoutMetrics()
	self:updateButtonLayout()
end

function GameOver:draw()
	local sw, sh = Screen:get()
	local layoutChanged = self:updateLayoutMetrics()
	if layoutChanged then
		self:updateButtonLayout()
	end
	drawBackground(sw, sh)

	local _, buttonHeight, buttonSpacing = getButtonMetrics()
	local totalButtonHeight = 0
	if #buttonDefs > 0 then
		totalButtonHeight = #buttonDefs * buttonHeight + max(0, (#buttonDefs - 1) * buttonSpacing)
	end
	local panelY = select(1, self:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing))

	local margin = 24
	local fallbackMaxAllowed = max(40, sw - margin)
	local fallbackSafe = max(80, sw - margin * 2)
	fallbackSafe = min(fallbackSafe, fallbackMaxAllowed)
	local fallbackPreferred = min(sw * 0.72, 640)
	local fallbackMin = min(320, fallbackSafe)
	local computedWidth = max(fallbackMin, min(fallbackPreferred, fallbackSafe))
	local contentWidth = self.contentWidth or computedWidth
	local contentX = (sw - contentWidth) / 2
	local padding = self.contentPadding or 24

	local titleKey = self.isVictory and "gameover.victory_title" or "gameover.title"
	local fallbackTitle = self.isVictory and "Noodl's Grand Feast" or "Game Over"
	local titleText = self.customTitle or getLocalizedOrFallback(titleKey, fallbackTitle)

	local contentProgress = getContentAnimationProgress(self)
	local contentAlpha = contentProgress
	local panelOffset = (1 - contentProgress) * ((UI.scaled and UI.scaled(26, 14)) or 18)
	local messageAlpha = getStaggeredAlpha(contentProgress, 0, 0.4) * contentAlpha
	local statsAlpha = getStaggeredAlpha(contentProgress, 0.1, 0.4) * contentAlpha
	local detailsAlpha = getStaggeredAlpha(contentProgress, 0.2, 0.4) * contentAlpha
	local messageOffset = (1 - messageAlpha) * ((UI.scaled and UI.scaled(10, 6)) or 8)
	local statsOffset = (1 - statsAlpha) * ((UI.scaled and UI.scaled(8, 4)) or 6)
	local detailsOffset = (1 - detailsAlpha) * ((UI.scaled and UI.scaled(8, 4)) or 6)
	local highlightEntries = getHighlightStats(self, contentProgress)
	local detailEntries = getDetailedStats()

	local headerY = UI.getHeaderY(sw, sh)
	UI.drawLabel(titleText, 0, headerY, sw, "center", {
		font = fontTitle,
		color = UI.colors.text,
		shadow = true,
		shadowOffset = TITLE_SHADOW_OFFSET,
		alpha = contentAlpha,
		}
	)

	local panelHeight = self.summaryPanelHeight or 0
	local sectionPadding = self.sectionPaddingValue or getSectionPadding()
	local sectionSpacing = self.sectionSpacingValue or getSectionSpacing()
	local innerSpacing = self.sectionInnerSpacingValue or getSectionInnerSpacing()
	local innerWidth = max(0, contentWidth - padding * 2)
	local messageText = self.deathMessage or Localization:get("gameover.default_message")

	love.graphics.push()
	love.graphics.translate(0, panelOffset)

	UI.drawPanel(contentX, panelY, contentWidth, panelHeight, {
		radius = UI.spacing and UI.spacing.panelRadius,
		shadowColor = UI.colors.shadow,
		alpha = statsAlpha,
		}
	)

	local messageWidth = max(0, innerWidth - sectionPadding * 2)
	local messageY = panelY + padding + sectionPadding + messageOffset
	UI.drawLabel(messageText, contentX + padding + sectionPadding, messageY, messageWidth, "center", {
		font = fontMessage,
		color = withAlpha(UI.colors.text or {1, 1, 1, 1}, messageAlpha),
		shadow = true,
		shadowOffset = TEXT_SHADOW_OFFSET,
		}
	)

	local statsY = panelY + padding + (self.messagePanelHeight or 0) + sectionSpacing
	drawHighlightStats(self, highlightEntries, contentX + padding, statsY + statsOffset, innerWidth, sectionPadding, innerSpacing, statsAlpha)

	local detailY = statsY + (self.scorePanelHeight or 0) + sectionSpacing
	drawDetailedStats(detailEntries, contentX + padding, detailY + detailsOffset, innerWidth, sectionPadding, innerSpacing, detailsAlpha, self.detailColumns)

	love.graphics.pop()

	for _, btn in buttonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	buttonList:draw(contentAlpha)

end

function GameOver:update(dt)
	self.contentAnim = min(CONTENT_ANIM_DURATION, (self.contentAnim or 0) + dt)
	self.buttonAnim = min(BUTTON_ANIM_DURATION, (self.buttonAnim or 0) + dt)
	local layoutChanged = self:updateLayoutMetrics()
	if layoutChanged or getButtonAnimationOffset(self) ~= self._lastButtonAnimOffset then
		self:updateButtonLayout()
	end
end

function GameOver:mousepressed(x, y, button)
	buttonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
	local action = buttonList:mousereleased(x, y, button)
	return handleButtonAction(self, action)
end

function GameOver:keypressed(key)
	if key == "up" or key == "left" then
		buttonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		buttonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		local action = buttonList:activateFocused()
		local resolved = handleButtonAction(self, action)
		if resolved then
			Audio:playSound("click")
		end
		return resolved
	elseif key == "escape" or key == "backspace" then
		Audio:playSound("click")
		return "menu"
	end
end

function GameOver:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		buttonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		buttonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		local action = buttonList:activateFocused()
		local resolved = handleButtonAction(self, action)
		if resolved then
			Audio:playSound("click")
		end
		return resolved
	elseif button == "b" then
		Audio:playSound("click")
		return "menu"
	end
end

GameOver.joystickpressed = GameOver.gamepadpressed

function GameOver:gamepadaxis(_, axis, value)
	handleAnalogAxis(axis, value)
end

GameOver.joystickaxis = GameOver.gamepadaxis

return GameOver
