local Screen = require("screen")
local Audio = require("audio")
local Theme = require("theme")
local MenuScene = require("menuscene")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")

local max = math.max
local min = math.min

local GameOver = {isVictory = false}

local buttonDefs = {}

local ANALOG_DEADZONE = 0.3
local TEXT_SHADOW_OFFSET = 2
local TITLE_SHADOW_OFFSET = 3

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

local function ensureFonts()
        fontTitle = UI.fonts.title or love.graphics.getFont()
        fontScore = UI.fonts.heading or love.graphics.getFont()
        fontScoreValue = UI.fonts.display or fontScore
        fontSmall = UI.fonts.body or love.graphics.getFont()
        fontMessage = UI.fonts.body or love.graphics.getFont()
        fontProgressSmall = UI.fonts.small or fontSmall
        fontProgressLabel = UI.fonts.caption or fontProgressSmall
end

local function handleButtonAction(_, action)
        return action
end

local function drawStatsPanel(self, x, y, width, sectionPadding, innerSpacing)
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
        local columnCount = #entries
        local columnWidth = columnCount > 0 and availableWidth / columnCount or availableWidth

        local labelFont = fontProgressLabel or fontProgressSmall
        local valueFont = fontScoreValue or fontScore
        local labelY = y + sectionPadding
        local valueY = labelY + labelFont:getHeight() + innerSpacing

        local mutedColor = UI.colors.mutedText or UI.colors.text
        local baseValueColor = UI.colors.text or {1, 1, 1, 1}
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
                        color = {
                                highlightColor[1] or baseValueColor[1],
                                highlightColor[2] or baseValueColor[2],
                                highlightColor[3] or baseValueColor[3],
                                (highlightColor[4] or baseValueColor[4] or 1) * 0.95,
                        }
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

        local panelHeight = padding + messagePanelHeight + sectionSpacing + scorePanelHeight + padding

        self.contentWidth = contentWidth
        self.innerContentWidth = innerWidth
        self.wrapLimit = wrapLimit
        self.sectionPaddingValue = sectionPadding
        self.sectionSpacingValue = sectionSpacing
        self.sectionInnerSpacingValue = innerSpacing
        self.messagePanelHeight = messagePanelHeight
        self.scorePanelHeight = scorePanelHeight
        self.summaryPanelHeight = panelHeight

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

        local panelHeight = self.summaryPanelHeight or 0
        local sectionPadding = self.sectionPaddingValue or getSectionPadding()
        local sectionSpacing = self.sectionSpacingValue or getSectionSpacing()
        local innerSpacing = self.sectionInnerSpacingValue or getSectionInnerSpacing()
        local innerWidth = max(0, contentWidth - padding * 2)
        local messageText = self.deathMessage or Localization:get("gameover.default_message")

        UI.drawPanel(contentX, panelY, contentWidth, panelHeight, {
                radius = UI.spacing and UI.spacing.panelRadius,
                shadowColor = UI.colors.shadow,
        })

        local messageWidth = max(0, innerWidth - sectionPadding * 2)
        local messageY = panelY + padding + sectionPadding
        UI.drawLabel(messageText, contentX + padding + sectionPadding, messageY, messageWidth, "center", {
                font = fontMessage,
                color = UI.colors.mutedText or UI.colors.text,
                shadow = true,
                shadowOffset = TEXT_SHADOW_OFFSET,
        })

        local statsY = panelY + padding + (self.messagePanelHeight or 0) + sectionSpacing
        drawStatsPanel(self, contentX + padding, statsY, innerWidth, sectionPadding, innerSpacing)

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
