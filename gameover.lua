local Screen = require("screen")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local Upgrades = require("upgrades")
local Shop = require("shop")
local Timer = require("timer")
local Color = require("color")

local abs = math.abs
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin
local insert = table.insert
local remove = table.remove

local GameOver = {isVictory = false}

local buttonDefs = {}

local ANALOG_DEADZONE = 0.3
local BUTTON_VERTICAL_OFFSET = 30
local TEXT_SHADOW_OFFSET = 2
local TITLE_SHADOW_OFFSET = 3

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

local function cloneArray(source)
	if type(source) ~= "table" then
		return nil
	end

	local copy = {}
	for i, value in ipairs(source) do
		copy[i] = value
	end

	return copy
end

local function getDayUnit(count)
	if count == 1 then
		return Localization:get("common.day_unit_singular")
	end

	return Localization:get("common.day_unit_plural")
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
-- Layout constants
local function getButtonMetrics()
	local spacing = UI.spacing or {}
	return spacing.buttonWidth or 260, spacing.buttonHeight or 56, spacing.buttonSpacing or 24
end

local function getCelebrationEntryHeight()
	return (UI.scaled and UI.scaled(64, 48)) or 64
end

local function getCelebrationEntrySpacing()
	local gap = (UI.scaled and UI.scaled(10, 6)) or 10
	return getCelebrationEntryHeight() + gap
end

local function getStatCardMinWidth()
	return (UI.scaled and UI.scaled(160, 120)) or 160
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

local function getSectionSmallSpacing()
	return (UI.scaled and UI.scaled(8, 5)) or 8
end

local function getSectionHeaderSpacing()
	return (UI.scaled and UI.scaled(18, 14)) or 18
end


local backgroundStyle = nil

local copyColor = function(color)
	return Color.copy(color, {default = Color.white})
end

local lightenColor = function(color, factor)
	return Color.lighten(color, factor)
end

local darkenColor = function(color, factor)
	return Color.darken(color, factor)
end

local desaturateColor = function(color, amount)
	return Color.desaturate(color, amount)
end

local withAlpha = function(color, alpha)
	return Color.withAlpha(color, alpha)
end

local function rebuildBackgroundStyle()
	local baseColor = copyColor(Theme.bgColor or {0.12, 0.12, 0.14, 1})
	local pulse = copyColor(Theme.progressColor or {0.55, 0.75, 0.55, 1})
	local overlayColor
	local coreColor

	if GameOver.isVictory then
		pulse = lightenColor(copyColor(Theme.progressColor or pulse), 0.4)
		pulse[4] = 1

		baseColor = darkenColor(baseColor, 0.08)
		baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

		coreColor = lightenColor(copyColor(Theme.goldenPearColor or Theme.progressColor or pulse), 0.26)
		coreColor = desaturateColor(coreColor, 0.22)
		coreColor[4] = 0.58

		local overlay = lightenColor(copyColor(Theme.goldenPearColor or Theme.accentTextColor or pulse), 0.2)
		overlay = desaturateColor(overlay, 0.4)
		overlayColor = withAlpha(overlay, 0.22)
	else
		local coolAccent = Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}

		pulse = lightenColor(copyColor(Theme.panelBorder or pulse), 0.26)
		pulse[4] = 1

		baseColor = darkenColor(baseColor, 0.22)
		baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

		coreColor = lightenColor(copyColor(coolAccent), 0.14)
		coreColor = desaturateColor(coreColor, 0.38)
		coreColor[4] = 0.52

		local overlay = lightenColor(copyColor(coolAccent), 0.04)
		overlay = desaturateColor(overlay, 0.45)
		overlayColor = withAlpha(overlay, 0.18)
	end

        backgroundStyle = {
                fillColor = baseColor,
                overlayColor = overlayColor,
	}
end

local function easeOutBack(t)
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

local function easeOutQuad(t)
        local inv = 1 - t
        return 1 - inv * inv
end

local function ensureFonts()
        fontTitle = UI.fonts.title or love.graphics.getFont()
        fontScore = UI.fonts.heading or love.graphics.getFont()
        fontScoreValue = UI.fonts.display or fontScore
        fontSmall = UI.fonts.body or love.graphics.getFont()
        fontMessage = UI.fonts.body or love.graphics.getFont()
        fontBadge = UI.fonts.badge or UI.fonts.small or fontSmall
        fontProgressTitle = UI.fonts.subtitle or fontScore
        fontProgressValue = UI.fonts.display or fontScoreValue
        fontProgressSmall = UI.fonts.small or fontSmall
        fontProgressLabel = UI.fonts.caption or fontProgressSmall
end

local function randomRange(minimum, maximum)
        return minimum + (maximum - minimum) * love.math.random()
end

local function handleButtonAction(_, action)
        return action
end

local function drawScorePanel(self, x, y, width, height, sectionPadding, innerSpacing, smallSpacing)
	if (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	drawSummaryPanelBackground(x, y, width, height, {radius = 18})

	local scoreLabel = getLocalizedOrFallback("gameover.score_label", "Score")
	local bestLabel = getLocalizedOrFallback("gameover.stats_best_label", "Best")
	local applesLabel = getLocalizedOrFallback("gameover.stats_apples_label", "Fruit")

	local entries = {
		{
			label = scoreLabel,
			value = tostring(stats.score or 0),
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

	local availableWidth = max(0, width - sectionPadding * 2)
	local columnSpacing = 0
	local columnCount = #entries
	local columnWidth = columnCount > 0 and (availableWidth - columnSpacing * max(0, columnCount - 1)) / columnCount or availableWidth
	columnWidth = max(0, columnWidth)

	local labelFont = fontProgressLabel or fontProgressSmall
	local valueFont = fontScoreValue or fontScore
	local labelY = y + sectionPadding
	local valueY = labelY + labelFont:getHeight() + innerSpacing

	local mutedColor = UI.colors.mutedText or UI.colors.text
	local baseValueColor = UI.colors.text or {1, 1, 1, 1}
	local highlightColor = Theme.progressColor or UI.colors.highlight or baseValueColor

	for index, entry in ipairs(entries) do
		local entryX = x + sectionPadding + (index - 1) * (columnWidth + columnSpacing)
		UI.drawLabel(entry.label or "", entryX, labelY, columnWidth, "center", {
			font = labelFont,
			color = mutedColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)

		local valueText = entry.value or "0"
		local displayFont = valueFont
		if columnWidth > 0 and displayFont:getWidth(valueText) > columnWidth then
			displayFont = fontProgressTitle or displayFont
			if displayFont:getWidth(valueText) > columnWidth then
				displayFont = fontProgressSmall
			end
		end

		local color = baseValueColor
		if entry.highlight then
			color = {
				highlightColor[1] or baseValueColor[1],
				highlightColor[2] or baseValueColor[2],
				highlightColor[3] or baseValueColor[3],
				(highlightColor[4] or baseValueColor[4] or 1) * 0.95,
			}
		end

		UI.drawLabel(valueText, entryX, valueY, columnWidth, "center", {
			font = displayFont,
			color = color,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)
	end
end

local function drawAchievementsPanel(self, x, y, width, height, sectionPadding, innerSpacing, smallSpacing, layoutData)
	if not layoutData or (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	local entries = layoutData.entries or {}
	if #entries == 0 then
		return
	end

	drawInsetPanel(x, y, width, height, {radius = 18})

	local achievementsLabel = getLocalizedOrFallback("gameover.achievements_header", "Achievements")
	local headerText = string.format("%s (%d)", achievementsLabel, #entries)
	local headerWidth = layoutData.headerWidth or (width - sectionPadding * 2)
	local textWidth = layoutData.textWidth or (width - sectionPadding * 2)
	local textOffset = layoutData.textOffset or 0
	local iconSize = layoutData.iconSize or 14
	local entryY = y + sectionPadding

	UI.drawLabel(headerText, x + sectionPadding, entryY, headerWidth, "left", {
		font = fontProgressSmall,
		color = UI.colors.text,
		shadow = true,
		shadowOffset = TEXT_SHADOW_OFFSET,
		}
	)

	entryY = entryY + fontProgressSmall:getHeight() + innerSpacing

	for index, entry in ipairs(entries) do
		local iconX = x + sectionPadding
		local iconCenterY = entryY + fontSmall:getHeight() / 2
		local badgeColor = entry.badgeColor or Theme.achieveColor or UI.colors.highlight or UI.colors.text

		local badgeShadow = withAlpha(darkenColor(badgeColor, 0.55), 0.65)
		love.graphics.setColor(badgeShadow[1], badgeShadow[2], badgeShadow[3], badgeShadow[4])
		love.graphics.circle("fill", iconX + iconSize / 2 + 1, iconCenterY + 1, iconSize * 0.48, 20)

		love.graphics.push()
		love.graphics.translate(iconX + iconSize / 2, iconCenterY)
		love.graphics.rotate(pi / 4)

		local diamond = iconSize * 0.72
		love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], (badgeColor[4] or 1) * 0.95)
		love.graphics.rectangle("fill", -diamond / 2, -diamond / 2, diamond, diamond, iconSize * 0.18, iconSize * 0.18)

		local gleam = withAlpha(lightenColor(badgeColor, 0.38), 0.85)
		love.graphics.setColor(gleam[1], gleam[2], gleam[3], gleam[4])
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", -diamond / 2, -diamond / 2, diamond, diamond, iconSize * 0.18, iconSize * 0.18)
		love.graphics.setLineWidth(1)
		love.graphics.pop()

		local sparkle = withAlpha(lightenColor(badgeColor, 0.6), 0.9)
		love.graphics.setColor(sparkle[1], sparkle[2], sparkle[3], sparkle[4])
		love.graphics.setLineWidth(1.2)
		love.graphics.line(iconX + iconSize / 2, iconCenterY - iconSize * 0.34, iconX + iconSize / 2, iconCenterY + iconSize * 0.34)
		love.graphics.line(iconX + iconSize / 2 - iconSize * 0.34, iconCenterY, iconX + iconSize / 2 + iconSize * 0.34, iconCenterY)
		love.graphics.setLineWidth(1)
		love.graphics.setColor(1, 1, 1, 1)

		local textX = x + sectionPadding + textOffset
		UI.drawLabel(entry.title or "", textX, entryY, textWidth, "left", {
			font = fontSmall,
			color = UI.colors.highlight or UI.colors.text,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)
		entryY = entryY + fontSmall:getHeight()

		if entry.description and entry.description ~= "" then
			UI.drawLabel(entry.description, textX, entryY, textWidth, "left", {
				font = fontProgressSmall,
				color = UI.colors.mutedText or UI.colors.text,
				shadow = true,
				shadowOffset = TEXT_SHADOW_OFFSET,
				}
			)
			entryY = entryY + (entry.descriptionLines or 0) * fontProgressSmall:getHeight()
		end

		if index < #entries then
			entryY = entryY + smallSpacing
		end
	end
end

local function drawCombinedPanel(self, contentWidth, contentX, padding, panelY)
	local panelHeight = self.summaryPanelHeight or 0
	panelY = panelY or 120
	drawCenteredPanel(contentX, panelY, contentWidth, panelHeight, 20)

	local innerWidth = self.innerContentWidth or (contentWidth - padding * 2)
	local innerX = contentX + padding

	local sectionPadding = self.sectionPaddingValue or getSectionPadding()
	local sectionSpacing = self.sectionSpacingValue or getSectionSpacing()
	local innerSpacing = self.sectionInnerSpacingValue or getSectionInnerSpacing()
	local smallSpacing = self.sectionSmallSpacingValue or getSectionSmallSpacing()
	local primaryWidth = self.primaryPanelWidth or max(0, innerWidth - sectionPadding * 2)
	local primaryOffset = self.primaryPanelOffset or sectionPadding
	local primaryX = innerX + primaryOffset
	local currentY = panelY + padding

	local wrapLimit = self.wrapLimit or max(0, innerWidth - sectionPadding * 2)
	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local messagePanelHeight = self.messagePanelHeight or 0
	if messagePanelHeight > 0 then
		drawSummaryPanelBackground(primaryX, currentY, primaryWidth, messagePanelHeight)
		UI.drawLabel(messageText, primaryX, currentY + sectionPadding, wrapLimit, "center", {
			font = fontMessage,
			color = UI.colors.mutedText or UI.colors.text,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
			}
		)
		currentY = currentY + messagePanelHeight
	end

	local layout = self.summarySectionLayout or {}
	local entries = layout.entries or {}

	if #entries > 0 then
		currentY = currentY + sectionSpacing
		local baseX = innerX + sectionPadding

		for _, entry in ipairs(entries) do
			local entryWidth = entry.width or (innerWidth - sectionPadding * 2)
			local entryHeight = entry.height or 0
			local entryX = baseX + (entry.x or 0)
			local entryY = currentY + (entry.y or 0)

			if entry.id == "score" then
				drawScorePanel(self, entryX, entryY, entryWidth, entryHeight, sectionPadding, innerSpacing, smallSpacing)
			elseif entry.id == "achievements" then
				drawAchievementsPanel(self, entryX, entryY, entryWidth, entryHeight, sectionPadding, innerSpacing, smallSpacing, entry.layoutData or self.achievementsLayout)
			end
		end

		currentY = currentY + (layout.columnsHeight or 0)
        end

end

function GameOver:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)
        local contentHeight = self.summaryPanelHeight or 0
        local padding = self.contentPadding or 24
        local buttonGap = buttonSpacing or 0

        local topMargin = padding * 1.5
        local bottomMargin = padding * 2

        local availableHeight = max(0, sh - topMargin - bottomMargin)
        local totalStackHeight = contentHeight + buttonGap + totalButtonHeight
        local panelY = topMargin

        if totalStackHeight < availableHeight then
                panelY = topMargin + (availableHeight - totalStackHeight) * 0.3
        end

        local buttonY = panelY + contentHeight + buttonGap

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
        local smallSpacing = getSectionSmallSpacing()

        local innerWidth = max(0, contentWidth - padding * 2)
        local wrapLimit = max(0, innerWidth - sectionPadding * 2)
        local messageText = self.deathMessage or Localization:get("gameover.default_message")

        local _, lineCount = fontMessage:getWrap(messageText or "", wrapLimit)
        local messageHeight = (fontMessage:getHeight() or 0) * (lineCount or 1)
        local messagePanelHeight = sectionPadding * 2 + messageHeight

        local labelFont = fontProgressLabel or fontProgressSmall
        local valueFont = fontScoreValue or fontScore or fontProgressValue
        local scorePanelHeight = sectionPadding * 2
        scorePanelHeight = scorePanelHeight + (labelFont and labelFont:getHeight() or 0)
        scorePanelHeight = scorePanelHeight + innerSpacing + (valueFont and valueFont:getHeight() or 0)

        local layout = {
                entries = {
                        {
                                id = "score",
                                width = max(0, innerWidth - sectionPadding * 2),
                                height = scorePanelHeight,
                                x = 0,
                                y = 0,
                        },
                },
                columnsHeight = scorePanelHeight,
        }

        local primaryWidth = max(0, innerWidth - sectionPadding * 2)
        local primaryOffset = sectionPadding
        local panelHeight = padding + messagePanelHeight + sectionSpacing + layout.columnsHeight + padding

        self.contentWidth = contentWidth
        self.innerContentWidth = innerWidth
        self.wrapLimit = wrapLimit
        self.sectionPaddingValue = sectionPadding
        self.sectionSpacingValue = sectionSpacing
        self.sectionInnerSpacingValue = innerSpacing
        self.sectionSmallSpacingValue = smallSpacing
        self.primaryPanelWidth = primaryWidth
        self.primaryPanelOffset = primaryOffset
        self.messagePanelHeight = messagePanelHeight
        self.summaryPanelHeight = panelHeight
        self.summarySectionLayout = layout

        return changed
end

function GameOver:updateButtonLayout()
        local sw, sh = Screen:get()
        local buttonWidth, buttonHeight, buttonSpacing = getButtonMetrics()
        local totalButtonHeight = #buttonDefs * buttonHeight + max(0, (#buttonDefs - 1) * buttonSpacing)
        local panelY, buttonStartY = self:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)

        local x = (sw - buttonWidth) / 2
        local defs = {}

        for i, entry in ipairs(buttonDefs) do
                defs[i] = {
                        id = entry.id or ("button" .. i),
                        x = x,
                        y = buttonStartY + (i - 1) * (buttonHeight + buttonSpacing),
                        w = buttonWidth,
                        h = buttonHeight,
                        textKey = entry.textKey,
                        text = entry.textKey and Localization:get(entry.textKey) or entry.text,
                        action = entry.action,
                }
        end

        buttonList:reset(defs)
        self._panelY = panelY
end

function GameOver:enter(data)
        data = data or {}

        UI.clearButtons()
        ensureFonts()
        resetAnalogAxis()

        stats.score = data.score or 0
        stats.highScore = data.highScore or stats.score or 0
        stats.apples = data.apples or 0
        stats.totalApples = data.totalApples or 0

        self.isVictory = not not data.won
        self.deathCause = data.cause or "unknown"
        self.deathMessage = data.endingMessage or pickDeathMessage(self.deathCause)
        self.customTitle = data.storyTitle

        buttonDefs = {
                {id = "playAgain", textKey = "gameover.play_again", action = "game"},
                {id = "quitToMenu", textKey = "gameover.quit_to_menu", action = "menu"},
        }

        self._cachedWidth, self._cachedHeight = nil, nil
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

	local headerY = UI.getHeaderY(sw, sh)
	UI.drawLabel(titleText, 0, headerY, sw, "center", {
		font = fontTitle,
		color = UI.colors.text,
		shadow = true,
		shadowOffset = TITLE_SHADOW_OFFSET,
		}
	)

	drawCombinedPanel(self, contentWidth, contentX, padding, panelY)

	for _, btn in buttonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	buttonList:draw()

end

function GameOver:update(dt)
        local layoutChanged = self:updateLayoutMetrics()
        if layoutChanged then
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
	if self:_consumeUnlockOverlayInput() then
		return
	end

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
	if self.activeUnlockOverlay then
		return
	end

	handleAnalogAxis(axis, value)
end

GameOver.joystickaxis = GameOver.gamepadaxis

return GameOver
