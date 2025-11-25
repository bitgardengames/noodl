local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local DrawWord = require("drawword")
local RenderLayers = require("renderlayers")
local Face = require("face")
local Easing = require("easing")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local MenuScene = require("menuscene")
local PlayerStats = require("playerstats")
local DailyProgress = require("dailyprogress")
local SawActor = require("sawactor")
local Tooltip = require("tooltip")

local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin

local Menu = {
	transitionDuration = 0.4,
	transitionStyle = "menuSlide",
}

local ANALOG_DEADZONE = 0.3
local buttonList = ButtonList.new()
local buttons = {}
local buttonLocaleRevision = nil
local t = 0
local dailyChallenge = nil
local dailyChallengeAnim = 0
local dailyChallengeAppearDelay = 0
local DAILY_BAR_CELEBRATION_DURATION = 6
local DAILY_BAR_CELEBRATION_FADE_WINDOW = 0.85
local DAILY_BAR_CELEBRATION_SHIMMER_SPEED = 0.55
local DAILY_PANEL_ANIM_SPEED = 2
local DAILY_PANEL_EXTRA_DELAY = 0.18
local DAILY_BAR_PROGRESS_SPEED = 0.85

local streakLineArgs = {streak = 0, unit = nil}
local bestLineArgs = {best = 0, unit = nil}
local resetTooltipArgs = {time = nil}
local DAILY_PANEL_OUTLINE_COLOR = {0, 0, 0, 1}
local EDGE_PROXIMITY_FACTOR = 0.765
local BUTTON_STACK_OFFSET = 80
local BUTTON_VERTICAL_SHIFT = 40
local BUTTON_EXTRA_SPACING = 2
local BUTTON_APPEAR_DURATION = 0.45
local INLINE_BUTTON_GAP = 18
local LOGO_VERTICAL_LIFT = 80
local dailyPanelCache = {}
local dailyChallengeAnimationKey = nil
local dailyChallengeAnimationSeenKey = nil
local dailyBarAnimationProgress = 0
local dailyBarAnimationTarget = 0
local dailyBarAnimationIdentifier = nil
local dailyBarAnimationDayValue = nil
local dailyBarAnimationSeenProgress = 0

local dailyBarCelebration = {
        active = false,
        time = 0,
        shimmerPhase = 0,
        finished = false,
}
local analogAxisDirections = {horizontal = nil, vertical = nil}
local titleSaw = SawActor.new()
local modeButtonsVisible = false
local modeButtonsAppearTime = 0
local JOURNEY_BUTTON_ID = "journeyMode"
local CLASSIC_BUTTON_ID = "classicMode"

local random = (love.math and love.math.random) or math.random

function Menu:getMenuBackgroundOptions()
	return MenuScene.getPlainBackgroundOptions()
end

local function drawBackground(sw, sh)
	if not MenuScene.shouldDrawBackground() then
		return
	end

	MenuScene.drawBackground(sw, sh, Menu:getMenuBackgroundOptions())
end

local function getDayUnit(count)
	if count == 1 then
		return Localization:get("common.day_unit_singular")
	end

	return Localization:get("common.day_unit_plural")
end

local function formatResetCountdown(seconds)
	if not seconds then
		return nil
	end

	seconds = max(0, floor(seconds))

	local hours = floor(seconds / 3600)
	local minutes = floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end

	return string.format("%d:%02d", minutes, secs)
end

local function stringifyValue(value)
	local valueType = type(value)
	if valueType == "table" then
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = tostring(key)
		end
		table.sort(keys)

		local parts = {}
		for i = 1, #keys do
			local key = keys[i]
			parts[#parts + 1] = key .. "=" .. stringifyValue(value[key])
		end

		return "{" .. table.concat(parts, ",") .. "}"
	end

	if valueType == "boolean" then
		return value and "true" or "false"
	end

	return tostring(value)
end

local function buildReplacementsSignature(replacements)
	if not replacements then
		return "__none"
	end

	local keys = {}
	for key in pairs(replacements) do
		keys[#keys + 1] = tostring(key)
	end

	table.sort(keys)

	local parts = {}
	for i = 1, #keys do
		local key = keys[i]
		parts[#parts + 1] = key .. "=" .. stringifyValue(replacements[key])
	end

	return table.concat(parts, "|")
end

local function buildStatusBarSignature(statusBar)
	if not statusBar then
		return "__none"
	end

	local parts = {
		tostring(statusBar.textKey or ""),
		tostring(statusBar.ratio or 0),
		buildReplacementsSignature(statusBar.replacements),
	}

	return table.concat(parts, "|")
end

local function buildChallengeSignature(challenge)
	if not challenge then
		return "__none"
	end

	local parts = {
		tostring(challenge.titleKey or ""),
		tostring(challenge.descriptionKey or ""),
		buildReplacementsSignature(challenge.descriptionReplacements),
		challenge.completed and "1" or "0",
	}

	local statusBar = challenge.statusBar
	if statusBar then
		parts[#parts + 1] = tostring(statusBar.textKey or "")
		parts[#parts + 1] = buildReplacementsSignature(statusBar.replacements)
	else
		parts[#parts + 1] = "__no_status"
	end

	return table.concat(parts, "|")
end

local function getDailyPanelCacheEntry(challenge, panelWidth, padding, bodyFont, progressFont)
	if not challenge or not panelWidth or panelWidth <= 0 then
		return nil
	end

	local localeRevision = Localization:getRevision()
	local challengeId = tostring(challenge.id or "__no_id")
	local statusBar = challenge.statusBar

	local streak = DailyProgress:getStreak()
	local currentStreak = max(0, streak and streak.current or 0)
	local bestStreak = max(currentStreak, streak and streak.best or 0)

	local statusSignature = buildStatusBarSignature(statusBar)
	local cacheKey = table.concat({challengeId, tostring(panelWidth), tostring(currentStreak), tostring(bestStreak), statusSignature}, "|")

	local challengeSignature = buildChallengeSignature(challenge)

	local entry = dailyPanelCache[cacheKey]
	if entry and entry.localeRevision == localeRevision and entry.challengeSignature == challengeSignature then
		return entry
	end

	local headerText = Localization:get("menu.daily_panel_header")

	local titleText = Localization:get(challenge.titleKey, challenge.descriptionReplacements)
	local descriptionText = Localization:get(challenge.descriptionKey, challenge.descriptionReplacements)

	local usableWidth = panelWidth - padding * 2
	local _, descLines = bodyFont:getWrap(descriptionText, usableWidth)
	local descLineCount = #descLines
	local descHeight = descLineCount * bodyFont:getHeight()

	local ratio = 0
	local progressText = nil
	local statusBarHeight = 0

	if statusBar then
		ratio = max(0, min(statusBar.ratio or 0, 1))
		if statusBar.textKey then
			progressText = Localization:get(statusBar.textKey, statusBar.replacements)
		end
		statusBarHeight = 10 + 14
		if progressText then
			statusBarHeight = statusBarHeight + progressFont:getHeight() + 6
		end
	end

	local streakText
	local streakLineCount = 0
	local streakHeight = 0

	if currentStreak > 0 then
		streakLineArgs.streak = currentStreak
		streakLineArgs.unit = getDayUnit(currentStreak)
		local streakLine = Localization:get("menu.daily_panel_streak", streakLineArgs)

		bestLineArgs.best = bestStreak
		bestLineArgs.unit = getDayUnit(bestStreak)
		local bestLine = Localization:get("menu.daily_panel_best", bestLineArgs)

		local messageKey = challenge.completed and "menu.daily_panel_complete_message" or "menu.daily_panel_keep_alive"
		local messageLine = Localization:get(messageKey)

		streakText = string.format("%s (%s) - %s", streakLine, bestLine, messageLine)
	else
		streakText = Localization:get("menu.daily_panel_start")
	end

	if streakText then
		local _, streakLinesWrapped = progressFont:getWrap(streakText, usableWidth)
		streakLineCount = max(1, #streakLinesWrapped)
		streakHeight = streakLineCount * progressFont:getHeight()
	end

	entry = {
		localeRevision = localeRevision,
		challengeSignature = challengeSignature,
		cacheKey = cacheKey,
		headerText = headerText,
		titleText = titleText,
		descriptionText = descriptionText,
		descriptionHeight = descHeight,
		descriptionLineCount = descLineCount,
		statusBarHeight = statusBarHeight,
		progressText = progressText,
		streakText = streakText,
		streakHeight = streakHeight,
		streakLineCount = streakLineCount,
		ratio = ratio,
		hasStatusBar = statusBar ~= nil,
		currentStreak = currentStreak,
		bestStreak = bestStreak,
	}

	dailyPanelCache[cacheKey] = entry

	return entry
end

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

local function getDailyDayValue()
        local date = DailyChallenges._sessionDate or os.date("*t")
        local dayValue = (date.year or 0) * 512 + (date.yday or 0)

        return dayValue
end

local function getDailyChallengeIdentifier(challenge)
        if not challenge then
                return "daily"
        end

        return tostring(challenge.id or challenge.titleKey or "daily")
end

local function getDailyAnimationKey(challenge)
        if not challenge then
                return nil
        end

        local dayValue = getDailyDayValue()
        local identifier = getDailyChallengeIdentifier(challenge)

        return string.format("%s:%d", identifier, dayValue)
end

local function resetDailyBarCelebration()
        dailyBarCelebration.active = false
        dailyBarCelebration.time = 0
        dailyBarCelebration.shimmerPhase = 0
        dailyBarCelebration.finished = false
end

local function resetDailyBarAnimation()
        dailyBarAnimationProgress = 0
        dailyBarAnimationTarget = 0
        dailyBarAnimationIdentifier = nil
        dailyBarAnimationDayValue = nil
        dailyBarAnimationSeenProgress = 0
end

local function initializeDailyBarAnimation(challenge)
        resetDailyBarAnimation()

        if not challenge or not challenge.statusBar then
                return
        end

        local ratio = max(0, min(challenge.statusBar.ratio or 0, 1))
        local identifier = getDailyChallengeIdentifier(challenge)
        local dayValue = getDailyDayValue()
        local seenProgress = DailyProgress:getMenuAnimationProgress(identifier, dayValue) or 0

        dailyBarAnimationTarget = ratio
        dailyBarAnimationIdentifier = identifier
        dailyBarAnimationDayValue = dayValue
        dailyBarAnimationSeenProgress = max(0, min(seenProgress, ratio))
        dailyBarAnimationProgress = dailyBarAnimationSeenProgress

        if ratio <= dailyBarAnimationSeenProgress then
                dailyBarAnimationProgress = ratio
        end
end

local function recordDailyBarAnimationProgress()
        if not dailyBarAnimationIdentifier or not dailyBarAnimationDayValue then
                return
        end

        if dailyBarAnimationTarget <= dailyBarAnimationSeenProgress then
                return
        end

        DailyProgress:setMenuAnimationProgress(dailyBarAnimationIdentifier, dailyBarAnimationDayValue, dailyBarAnimationTarget)
        dailyBarAnimationSeenProgress = dailyBarAnimationTarget
end

local function updateDailyBarCelebration(dt, shouldCelebrate)
        if shouldCelebrate then
                if not dailyBarCelebration.active and not dailyBarCelebration.finished then
                        dailyBarCelebration.active = true
                        dailyBarCelebration.time = 0
                        dailyBarCelebration.shimmerPhase = 0
                end

                if dailyBarCelebration.active then
                        dailyBarCelebration.time = dailyBarCelebration.time + dt
                        dailyBarCelebration.shimmerPhase = (dailyBarCelebration.shimmerPhase or 0) + dt * DAILY_BAR_CELEBRATION_SHIMMER_SPEED

                        if dailyBarCelebration.time < DAILY_BAR_CELEBRATION_DURATION then
                                -- continue running
                        else
                                dailyBarCelebration.active = false
                                dailyBarCelebration.finished = true
                                dailyBarCelebration.time = DAILY_BAR_CELEBRATION_DURATION
                        end
                end
        elseif dailyBarCelebration.active or dailyBarCelebration.finished then
                resetDailyBarCelebration()
        end
end

local function prepareStartAction(action)
        if type(action) ~= "string" then
                return action
        end

        if action == "start_modes" then
                if not modeButtonsVisible then
                        modeButtonsVisible = true
                        modeButtonsAppearTime = t
                        rebuildMenuButtons(modeButtonsAppearTime)
                        focusButtonById(JOURNEY_BUTTON_ID)
                else
                        focusButtonById(JOURNEY_BUTTON_ID)
                end

                return
        elseif action == "game_classic" then
                return {state = "game", data = {mode = "classic"}}
        elseif action == "game_journey" or action == "game" then
                return {state = "game", data = {mode = "journey"}}
        end

        return action
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

local function updateButtonTexts(revision)
	local currentRevision = revision or Localization:getRevision()

	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey)
		end
	end

	buttonLocaleRevision = currentRevision
end

local function setColorWithAlpha(color, alpha)
	local r, g, b, a = 1, 1, 1, alpha or 1
	if color then
		r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
		a = (color[4] or 1) * (alpha or 1)
	end
	love.graphics.setColor(r, g, b, a)
end

local function shouldCelebrateDailyChallenge()
        if not dailyChallenge then
                return false
	end

	local statusBar = dailyChallenge.statusBar
	if not statusBar then
		return false
	end

        local ratio = max(0, min(statusBar.ratio or 0, 1))
        return dailyChallenge.completed or ratio >= 0.999
end

local function focusButtonById(targetId)
        if not targetId then
                return
        end

        for index, btn in ipairs(buttons) do
                if btn.id == targetId then
                        buttonList:setFocus(index)
                        return
                end
        end
end

local function rebuildMenuButtons(modeAppearStart)
        local sw, sh = Screen:get()
        local centerX = sw / 2
        local menuLayout = UI.getMenuLayout(sw, sh)
        local buttonWidth = UI.spacing.buttonWidth
        local buttonHeight = UI.spacing.buttonHeight

        local rows = {
                {type = "single", entry = {id = "menuButton1", key = "menu.start_game", action = "start_modes"}},
        }

        if modeButtonsVisible then
                rows[#rows + 1] = {
                        type = "inline",
                        entries = {
                                {id = JOURNEY_BUTTON_ID, key = "menu.journey_mode", action = {state = "game", data = {mode = "journey"}}, appearStart = modeAppearStart or modeButtonsAppearTime or 0},
                                {id = CLASSIC_BUTTON_ID, key = "menu.classic_mode", action = {state = "game", data = {mode = "classic"}}, appearStart = modeAppearStart or modeButtonsAppearTime or 0},
                        },
                }
        end

        rows[#rows + 1] = {type = "single", entry = {id = "menuButton2", key = "menu.achievements", action = "achievementsmenu"}}
        rows[#rows + 1] = {type = "single", entry = {id = "menuButton3", key = "menu.settings", action = "settings"}}
        rows[#rows + 1] = {type = "single", entry = {id = "menuButton4", key = "menu.quit", action = "quit"}}

        local effectiveSpacing = (UI.spacing.buttonSpacing or 0) + BUTTON_EXTRA_SPACING
        local totalButtonHeight = #rows * buttonHeight + max(0, #rows - 1) * effectiveSpacing
        local stackBase = (menuLayout.bodyTop or menuLayout.stackTop or (sh * 0.2))
        local footerGuard = menuLayout.footerSpacing or UI.spacing.sectionSpacing or 24
        local lowerBound = (menuLayout.bottomY or (sh - (menuLayout.marginBottom or sh * 0.12))) - footerGuard
        local availableHeight = max(0, lowerBound - stackBase)
        local startY = stackBase + max(0, (availableHeight - totalButtonHeight) * 0.5) + BUTTON_STACK_OFFSET + BUTTON_VERTICAL_SHIFT
        local minStart = stackBase + BUTTON_STACK_OFFSET + BUTTON_VERTICAL_SHIFT
        local maxStart = lowerBound - totalButtonHeight

        if maxStart < minStart then
                startY = maxStart
        else
                if startY > maxStart then
                        startY = maxStart
                end
                if startY < minStart then
                        startY = minStart
                end
        end

        local defs = {}
        local appearIndex = 0

        for rowIndex, row in ipairs(rows) do
                local y = startY + (rowIndex - 1) * (buttonHeight + effectiveSpacing)

                if row.type == "inline" and row.entries then
                        local gap = INLINE_BUTTON_GAP
                        local inlineCount = #row.entries
                        local inlineWidth = buttonWidth
                        if inlineCount and inlineCount > 1 then
                                inlineWidth = (buttonWidth - gap * (inlineCount - 1)) / inlineCount
                        end

                        local totalWidth = inlineWidth * inlineCount + gap * max(0, inlineCount - 1)
                        local startX = centerX - totalWidth / 2

                        for entryIndex, entry in ipairs(row.entries) do
                                appearIndex = appearIndex + 1
                                defs[#defs + 1] = {
                                        id = entry.id or ("menuButton" .. appearIndex),
                                        x = startX + (entryIndex - 1) * (inlineWidth + gap),
                                        y = y,
                                        w = inlineWidth,
                                        h = buttonHeight,
                                        labelKey = entry.key,
                                        action = entry.action,
                                        hovered = false,
                                        scale = entry.scale or 0.94,
                                        alpha = entry.alpha or 0,
                                        offsetY = entry.offsetY or 55,
                                        appearDelay = (appearIndex - 1) * 0.06,
                                        appearStart = entry.appearStart or 0,
                                }
                        end
                elseif row.entry then
                        appearIndex = appearIndex + 1
                        defs[#defs + 1] = {
                                id = row.entry.id or ("menuButton" .. appearIndex),
                                x = centerX - buttonWidth / 2,
                                y = y,
                                w = buttonWidth,
                                h = buttonHeight,
                                labelKey = row.entry.key,
                                action = row.entry.action,
                                hovered = false,
                                scale = row.entry.scale or 0.94,
                                alpha = row.entry.alpha or 0,
                                offsetY = row.entry.offsetY or 55,
                                appearDelay = (appearIndex - 1) * 0.06,
                                appearStart = row.entry.appearStart or 0,
                        }
                end
        end

        buttons = buttonList:reset(defs)
        local lastButtonDelay = (#buttons > 0 and (#buttons - 1) * 0.06) or 0
        dailyChallengeAppearDelay = lastButtonDelay + BUTTON_APPEAR_DURATION + DAILY_PANEL_EXTRA_DELAY
        updateButtonTexts(Localization:getRevision())
end

function Menu:enter()
        t = 0
        UI.clearButtons()

        Audio:playMusic("menu")
        Screen:update()
        Face:set("happy", love.math.random(3, 4))

        DailyProgress:load()
        dailyPanelCache = {}

        dailyChallenge = DailyChallenges:getDailyChallenge()
        dailyChallengeAnimationKey = getDailyAnimationKey(dailyChallenge)

        if dailyChallengeAnimationKey and dailyChallengeAnimationSeenKey == dailyChallengeAnimationKey then
                dailyChallengeAnim = 1
        else
                dailyChallengeAnim = 0
        end

        dailyChallengeAppearDelay = 0
        resetDailyBarCelebration()
        initializeDailyBarAnimation(dailyChallenge)
        resetAnalogAxis()

        MenuScene.prepareBackground(self:getMenuBackgroundOptions())

        modeButtonsVisible = false
        modeButtonsAppearTime = 0

        rebuildMenuButtons(0)
end

function Menu:update(dt)
	t = t + dt

        local mx, my = UI.refreshCursor()
        buttonList:updateHover(mx, my)
        Tooltip:update(dt, mx, my)

        if dailyChallenge then
                if dailyChallengeAnimationKey and dailyChallengeAnimationSeenKey == dailyChallengeAnimationKey then
                        dailyChallengeAnim = 1
                elseif t >= dailyChallengeAppearDelay then
                        dailyChallengeAnim = min(dailyChallengeAnim + dt * DAILY_PANEL_ANIM_SPEED, 1)
                        if dailyChallengeAnim >= 1 and dailyChallengeAnimationKey then
                                dailyChallengeAnimationSeenKey = dailyChallengeAnimationKey
                        end
                else
                        dailyChallengeAnim = 0
                end
        end

        if dailyBarAnimationTarget and dailyBarAnimationProgress < dailyBarAnimationTarget then
                local nextProgress = dailyBarAnimationProgress + dt * DAILY_BAR_PROGRESS_SPEED
                if nextProgress >= dailyBarAnimationTarget then
                        dailyBarAnimationProgress = dailyBarAnimationTarget
                        recordDailyBarAnimationProgress()
                else
                        dailyBarAnimationProgress = nextProgress
                end
        elseif dailyBarAnimationTarget and dailyBarAnimationProgress > dailyBarAnimationTarget then
                dailyBarAnimationProgress = dailyBarAnimationTarget
        end

        updateDailyBarCelebration(dt, shouldCelebrateDailyChallenge())

	local currentRevision = Localization:getRevision()
	if buttonLocaleRevision ~= currentRevision then
		updateButtonTexts(currentRevision)
	end

        for i, btn in ipairs(buttons) do
                local appearDelay = btn.appearDelay or ((i - 1) * 0.06)
                local appearStart = btn.appearStart or 0
                local linearAppear = (t - appearStart - appearDelay) / BUTTON_APPEAR_DURATION
                local appearProgress = Easing.clamp01(linearAppear)
                local easedAlpha = Easing.easeOutCubic(appearProgress)
                local liftedProgress = Easing.easeOutBack(appearProgress)

                btn.alpha = easedAlpha
                btn.offsetY = (1 - liftedProgress) * 55

                local baseScale = Easing.lerp(0.94, 1.02, liftedProgress)
                local hoverTarget = btn.hovered and 1.08 or 1.0
                local targetScale = baseScale * hoverTarget
                local currentScale = btn.scale or targetScale
                btn.scale = currentScale + (targetScale - currentScale) * min(dt * 10, 1)
        end

	if titleSaw then
		titleSaw:update(dt)
	end

	Face:update(dt)
end

function Menu:draw()
	local sw, sh = Screen:get()
	local menuLayout = UI.getMenuLayout(sw, sh)

	RenderLayers:begin(sw, sh)

	drawBackground(sw, sh)

	local baseCellSize = 20
	local baseSpacing = 10
	local wordScale = 2
	local sawScale = 2
	local sawRadius = titleSaw.radius or 24

	local cellSize = baseCellSize * wordScale
	local word = Localization:get("menu.title_word")
	local spacing = baseSpacing * wordScale
	local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
	local ox = (sw - wordWidth) / 2

	local baseOy = menuLayout.titleY or (sh * 0.2)
	local buttonTop = buttons[1] and buttons[1].y or (menuLayout.bodyTop or menuLayout.stackTop or (sh * 0.2))
	local desiredSpacing = (UI.spacing.buttonSpacing or 0) + (UI.spacing.buttonHeight or 0) * 0.25 + cellSize * 0.5
	local wordHeightForSpacing = cellSize * 2
	local targetBottom = buttonTop - desiredSpacing
	local currentBottom = baseOy + wordHeightForSpacing
	local additionalOffset = max(0, targetBottom - currentBottom)
	local oy = max(0, baseOy + additionalOffset - LOGO_VERTICAL_LIFT)

	if titleSaw and sawScale and sawRadius then
		local desiredTrackLengthWorld = wordWidth + cellSize
		local shortenedTrackLengthWorld = max(2 * sawRadius * sawScale, desiredTrackLengthWorld - 126)
		local adjustedTrackLengthWorld = shortenedTrackLengthWorld + 4
		local targetTrackLengthBase = adjustedTrackLengthWorld / sawScale
		if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
			titleSaw.trackLength = targetTrackLengthBase
		end

		local trackLengthWorld = (titleSaw.trackLength or targetTrackLengthBase) * sawScale
		local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
		local slotThicknessWorld = slotThicknessBase * sawScale

		local targetLeft = ox - 15
		local targetBottom = oy - 41

		local sawX = targetLeft + trackLengthWorld / 2 - 4
		local sawY = targetBottom - slotThicknessWorld / 2

		titleSaw:draw(sawX, sawY, sawScale)
	end

	local trail = DrawWord.draw(word, ox, oy, cellSize, spacing)

	RenderLayers:present()

	if trail and #trail > 0 then
		local head = trail[#trail]
		Face:draw(head.x, head.y, wordScale)
	end

	UI.refreshCursor()

	for _, btn in ipairs(buttons) do
		if btn.alpha > 0 then
			UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)

			love.graphics.push()
			love.graphics.translate(btn.x + btn.w / 2, btn.y + btn.h / 2 + btn.offsetY)
			love.graphics.scale(btn.scale)
			love.graphics.translate(-(btn.x + btn.w / 2), -(btn.y + btn.h / 2))

			UI.drawButton(btn.id)

			love.graphics.pop()
		end
	end

        if dailyChallenge and dailyChallengeAnim > 0 then
                local appearProgress = min(1, dailyChallengeAnim)
                local eased = Easing.easeInOutSine(appearProgress)
                local liftProgress = Easing.easeOutBack(appearProgress)
                local settleProgress = Easing.easeOutCubic(appearProgress)
                local alpha = eased
                local panelWidth = min(menuLayout.panelMaxWidth or 420, max(280, menuLayout.contentWidth or (sw - 72)))
                local padding = UI.spacing.panelPadding or 16
                local panelMargin = (menuLayout.marginHorizontal or 36) * EDGE_PROXIMITY_FACTOR
                local basePanelOffsetX = 25
                local basePanelOffsetY = 25
                local animatedOffsetX = basePanelOffsetX + (1 - settleProgress) * 26
                local animatedOffsetY = basePanelOffsetY + (1 - liftProgress) * 24
                local panelX = sw - panelWidth - panelMargin + animatedOffsetX
                local headerFont = UI.fonts.small
                local titleFont = UI.fonts.button
                local bodyFont = UI.fonts.body
                local progressFont = UI.fonts.small

		local dailyPanelEntry = getDailyPanelCacheEntry(dailyChallenge, panelWidth, padding, bodyFont, progressFont)
		local headerText = dailyPanelEntry and dailyPanelEntry.headerText or ""
		local titleText = dailyPanelEntry and dailyPanelEntry.titleText or ""
		local descriptionText = dailyPanelEntry and dailyPanelEntry.descriptionText or ""
		local descHeight = dailyPanelEntry and dailyPanelEntry.descriptionHeight or 0
                local statusBarHeight = dailyPanelEntry and dailyPanelEntry.statusBarHeight or 0
                local streakText = dailyPanelEntry and dailyPanelEntry.streakText or nil
                local streakHeight = dailyPanelEntry and dailyPanelEntry.streakHeight or 0
                local progressText = dailyPanelEntry and dailyPanelEntry.progressText or nil
                local ratio = dailyPanelEntry and dailyPanelEntry.ratio or 0
                local displayRatio = ratio

                local panelHeight = padding * 2 + headerFont:getHeight() + 6 + titleFont:getHeight() + 10 + descHeight + statusBarHeight

		if streakText then
			panelHeight = panelHeight + 8 + streakHeight
		end

                local panelY = max(menuLayout.marginTop or 36, (menuLayout.bottomY or (sh - (menuLayout.marginBottom or 36))) - panelHeight) + animatedOffsetY

		local mx, my = UI.getCursorPosition()
		local hovered = mx >= panelX and mx <= (panelX + panelWidth) and my >= panelY and my <= (panelY + panelHeight)
		if hovered then
			local timeRemaining = DailyChallenges:getTimeUntilReset()
			local tooltipText
			if timeRemaining and timeRemaining > 0 then
				local countdown = formatResetCountdown(timeRemaining)
				resetTooltipArgs.time = countdown
				tooltipText = Localization:get("menu.daily_panel_reset_tooltip", resetTooltipArgs)
			else
				resetTooltipArgs.time = nil
				tooltipText = Localization:get("menu.daily_panel_reset_tooltip_soon")
			end
			Tooltip:show(tooltipText, {
				id = "dailyChallengeReset",
				x = panelX + panelWidth / 2,
				y = panelY,
				placement = "above",
				maxWidth = panelWidth,
				offset = menuLayout.tooltipOffset or 14,
				delay = 0.12,
				}
			)
		else
			Tooltip:hide("dailyChallengeReset")
		end

                setColorWithAlpha(Theme.shadowColor, eased * 0.7)
                love.graphics.rectangle("fill", panelX + 5, panelY + 5, panelWidth, panelHeight, 14, 14)

                local panelFillColor = Theme.panelColor
                setColorWithAlpha(panelFillColor, alpha)
                love.graphics.push()
                love.graphics.translate(panelX + panelWidth / 2, panelY + panelHeight / 2)
                love.graphics.scale(Easing.lerp(0.96, 1.0, liftProgress))
                love.graphics.translate(-(panelX + panelWidth / 2), -(panelY + panelHeight / 2))
                UI.drawRoundedRect(panelX, panelY, panelWidth, panelHeight, 14)
                love.graphics.pop()

		setColorWithAlpha(DAILY_PANEL_OUTLINE_COLOR, alpha)
		love.graphics.setLineWidth(3)
		love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 14, 14)
		love.graphics.setLineWidth(1)

		local textX = panelX + padding
		local textY = panelY + padding

		love.graphics.setFont(headerFont)
		setColorWithAlpha(Theme.shadowColor, alpha)
		love.graphics.print(headerText, textX + 1, textY + 1)
		setColorWithAlpha(Theme.textColor, alpha)
		love.graphics.print(headerText, textX, textY)

		textY = textY + headerFont:getHeight() + 6

		love.graphics.setFont(titleFont)
		setColorWithAlpha(Theme.shadowColor, alpha)
		love.graphics.print(titleText, textX + 1, textY + 1)
		setColorWithAlpha(Theme.textColor, alpha)
		love.graphics.print(titleText, textX, textY)

		textY = textY + titleFont:getHeight() + 10

		love.graphics.setFont(bodyFont)
		setColorWithAlpha(Theme.shadowColor, alpha)
		love.graphics.printf(descriptionText, textX + 1, textY + 1, panelWidth - padding * 2)
		setColorWithAlpha(Theme.textColor, alpha)
		love.graphics.printf(descriptionText, textX, textY, panelWidth - padding * 2)

		textY = textY + descHeight

		if streakText then
			textY = textY + 8
			love.graphics.setFont(progressFont)
			local streakColor = Theme.textColor
			if dailyPanelEntry and dailyPanelEntry.currentStreak > 0 and not dailyChallenge.completed then
				streakColor = Theme.warningColor or Theme.accentTextColor or Theme.textColor
			end
			setColorWithAlpha(Theme.shadowColor, alpha)
			love.graphics.printf(streakText, textX + 1, textY + 1, panelWidth - padding * 2)
			setColorWithAlpha(streakColor, alpha)
			love.graphics.printf(streakText, textX, textY, panelWidth - padding * 2)
			textY = textY + streakHeight
			setColorWithAlpha(Theme.textColor, alpha)
		end

		if dailyPanelEntry and dailyPanelEntry.hasStatusBar then
			textY = textY + 10
			love.graphics.setFont(progressFont)

			if progressText then
				setColorWithAlpha(Theme.shadowColor, alpha)
				love.graphics.print(progressText, textX + 1, textY + 1)
				setColorWithAlpha(Theme.textColor, alpha)
				love.graphics.print(progressText, textX, textY)
				textY = textY + progressFont:getHeight() + 6
			end

                        local barHeight = 14
                        local barWidth = panelWidth - padding * 2
                        local barRadius = 8

                        setColorWithAlpha({0, 0, 0, 0.35}, alpha)
                        UI.drawRoundedRect(textX, textY, barWidth, barHeight, barRadius)

                        displayRatio = max(0, min(displayRatio, ratio))
                        if dailyBarAnimationTarget and dailyBarAnimationTarget > 0 then
                                displayRatio = min(displayRatio, max(0, dailyBarAnimationProgress))
                        end

                        local fillWidth = barWidth * displayRatio
                        if fillWidth > 0 then
                                setColorWithAlpha(Theme.progressColor, alpha)
                                UI.drawRoundedRect(textX, textY, fillWidth, barHeight, barRadius)
                        end

                        local celebrationVisible = ratio >= 0.999 and (dailyBarCelebration.active or dailyBarCelebration.finished)
                        if celebrationVisible then
                                local timer = dailyBarCelebration.time or 0
                                local fadeAlpha = 1

                                if dailyBarCelebration.active then
                                        local fadeStart = max(0, DAILY_BAR_CELEBRATION_DURATION - DAILY_BAR_CELEBRATION_FADE_WINDOW)
                                        if timer > fadeStart then
                                                local fadeProgress = (timer - fadeStart) / DAILY_BAR_CELEBRATION_FADE_WINDOW
                                                fadeAlpha = max(0, min(1, 1 - fadeProgress))
                                        end
                                else
                                        fadeAlpha = 0
                                end

                                local sheenWidth = max(barWidth * 0.24, barHeight * 1.4)
                                local shimmerPhase = (dailyBarCelebration.shimmerPhase or 0) % 1
                                local shimmerX = textX - sheenWidth + shimmerPhase * (barWidth + sheenWidth * 2)
                                local shimmerAlpha = (0.26 + 0.14 * sin(timer * 1.6)) * fadeAlpha

                                if shimmerAlpha > 0 then
                                        local prevStencilMode, prevStencilValue = love.graphics.getStencilTest()
                                        love.graphics.stencil(function()
                                                UI.drawRoundedRect(textX, textY, barWidth, barHeight, barRadius)
                                        end, "replace", 1)
                                        love.graphics.setStencilTest("greater", 0)

                                        setColorWithAlpha({1, 1, 1, shimmerAlpha}, alpha)
                                        UI.drawRoundedRect(shimmerX, textY, sheenWidth, barHeight, barRadius)

                                        if prevStencilMode then
                                                love.graphics.setStencilTest(prevStencilMode, prevStencilValue)
                                        else
                                                love.graphics.setStencilTest()
                                        end
                                end

                                love.graphics.setColor(1, 1, 1, 1)
                        end

                        setColorWithAlpha(Theme.panelBorder, alpha)
                        love.graphics.setLineWidth(1.5)
                        love.graphics.rectangle("line", textX, textY, barWidth, barHeight, barRadius, barRadius)

			textY = textY + barHeight
		end
	else
		Tooltip:hide("dailyChallengeReset")
	end

	Tooltip:draw()
end

function Menu:mousepressed(x, y, button)
	buttonList:mousepressed(x, y, button)
end

function Menu:mousereleased(x, y, button)
	local action = buttonList:mousereleased(x, y, button)
	if action then
		return prepareStartAction(action)
	end
end

local function handleMenuConfirm()
	local action = buttonList:activateFocused()
	if action then
		Audio:playSound("click")
		return prepareStartAction(action)
	end
end

function Menu:keypressed(key)
	if key == "up" or key == "left" then
		buttonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		buttonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return handleMenuConfirm()
	elseif key == "escape" or key == "backspace" then
		return "quit"
	end
end

function Menu:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		buttonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		buttonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return handleMenuConfirm()
	elseif button == "b" then
		return "quit"
	end
end

Menu.joystickpressed = Menu.gamepadpressed

function Menu:gamepadaxis(_, axis, value)
	handleAnalogAxis(axis, value)
end

Menu.joystickaxis = Menu.gamepadaxis

return Menu