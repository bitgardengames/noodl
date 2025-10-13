local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local drawWord = require("drawword")
local Face = require("face")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")
local PlayerStats = require("playerstats")
local SawActor = require("sawactor")

local Menu = {
	transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local buttonList = ButtonList.new()
local buttons = {}
local SHOW_MENU_BUTTONS = false
local t = 0
local dailyChallenge = nil
local dailyChallengeAnim = 0
local SHOW_DAILY_CHALLENGE_CARD = false
local analogAxisDirections = { horizontal = nil, vertical = nil }
local titleSaw = SawActor.new()

local TITLE_SAW_SCALE_FACTOR = 0.729 -- make the title saw 10% smaller than before
local LOGO_EXPORT_KEY = "f6"

local BACKGROUND_EFFECT_TYPE = "menuConstellation"
local backgroundEffectCache = {}
local backgroundEffect = nil

local BACKDROP_RECT_WIDTH = 1280
local BACKDROP_RECT_HEIGHT = 720
local BACKDROP_RECT_LINE_WIDTH = 12
local BACKDROP_RECT_PADDING = 80

local DEFAULT_WORD_SCALE = 3 * 0.9
local TITLE_SCALE_MARGIN = 0.96
local MIN_WORD_SCALE = 0.1
local TITLE_WORD_VERTICAL_FRACTION = 1 / 3

local function configureBackgroundEffect()
	local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		backgroundEffect = nil
		return
	end

	local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
	effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.58

	Shaders.configure(effect, {
		bgColor = Theme.bgColor,
		accentColor = Theme.buttonHover,
		highlightColor = Theme.accentTextColor,
	})

	backgroundEffect = effect
end

local function getBackdropMetrics(sw, sh)
        local widthScale = math.min(1, sw / BACKDROP_RECT_WIDTH)
        local heightScale = math.min(1, sh / BACKDROP_RECT_HEIGHT)
        local scale = math.min(widthScale, heightScale)
        local rectWidth = BACKDROP_RECT_WIDTH * scale
        local rectHeight = BACKDROP_RECT_HEIGHT * scale

        return {
                centerX = sw * 0.5,
                centerY = sh * 0.5,
                width = rectWidth,
                height = rectHeight,
                halfWidth = rectWidth * 0.5,
                halfHeight = rectHeight * 0.5,
        }
end

local function computeRectSpanLimits(centerY, halfWidth, halfHeight, topY, bottomY)
        if not centerY or not halfWidth or not halfHeight or halfWidth <= 0 or halfHeight <= 0 then
                return 0, 0
        end

        local spanTop = math.min(topY, bottomY)
        local spanBottom = math.max(topY, bottomY)
        local rectTop = centerY - halfHeight
        local rectBottom = centerY + halfHeight

        if spanBottom <= rectTop or spanTop >= rectBottom then
                return 0, 0
        end

        local clampedTop = math.max(spanTop, rectTop)
        local clampedBottom = math.min(spanBottom, rectBottom)
        if clampedTop >= clampedBottom then
                return 0, 0
        end

        local width = math.max(halfWidth * 2, 0)
        return width, halfWidth
end

local function drawBackground(sw, sh)
        love.graphics.setColor(Theme.bgColor)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        if not backgroundEffect then
                configureBackgroundEffect()
        end

        local metrics = getBackdropMetrics(sw, sh)
        local centerX = metrics.centerX
        local centerY = metrics.centerY
        local halfWidth = metrics.halfWidth
        local halfHeight = metrics.halfHeight
        local rectX = centerX - halfWidth
        local rectY = centerY - halfHeight

        if backgroundEffect then
                love.graphics.stencil(function()
                        love.graphics.rectangle("fill", rectX, rectY, metrics.width, metrics.height)
                end, "replace", 1)
                love.graphics.setStencilTest("greater", 0)
                local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
                Shaders.draw(backgroundEffect, rectX, rectY, metrics.width, metrics.height, intensity)
                love.graphics.setStencilTest()
        end

        if BACKDROP_RECT_LINE_WIDTH > 0 then
                love.graphics.setColor(Theme.buttonHover)
                love.graphics.setLineWidth(BACKDROP_RECT_LINE_WIDTH)
                local halfLine = BACKDROP_RECT_LINE_WIDTH * 0.5
                love.graphics.rectangle(
                        "line",
                        rectX - halfLine,
                        rectY - halfLine,
                        metrics.width + BACKDROP_RECT_LINE_WIDTH,
                        metrics.height + BACKDROP_RECT_LINE_WIDTH
                )
                love.graphics.setLineWidth(1)
        end

        love.graphics.setColor(1, 1, 1, 1)
end

local function computeTitleLayout(sw, sh)
        local baseCellSize = 20
        local baseSpacing = 10
        local word = Localization:get("menu.title_word") or ""

        local letterCount = 0
        if drawWord.getBounds then
                for i = 1, #word do
                        local ch = word:sub(i, i):lower()
                        local charBounds = drawWord.getBounds(ch)
                        local charMin = charBounds and charBounds.minY or 0
                        local charMax = charBounds and charBounds.maxY or 0
                        if charMax ~= charMin then
                                letterCount = letterCount + 1
                        end
                end
        end

        if letterCount == 0 then
                letterCount = math.max(#word, 1)
        end

        local bounds = drawWord.getBounds and drawWord.getBounds(word)
        local minRow = bounds and bounds.minY or 0
        local maxRow = bounds and bounds.maxY or 3

        local baseWordWidth
        if letterCount <= 1 then
                baseWordWidth = 3 * baseCellSize
        else
                baseWordWidth = (letterCount * (3 * baseCellSize + baseSpacing)) - baseSpacing - (baseCellSize * 3)
        end
        baseWordWidth = math.max(baseWordWidth, 1)

        local baseWordHeight = math.max((maxRow - minRow) * baseCellSize, baseCellSize)

        local metrics = getBackdropMetrics(sw, sh)
        local backdropCenterX = metrics.centerX
        local backdropCenterY = metrics.centerY
        local backdropHalfWidth = metrics.halfWidth
        local backdropHalfHeight = metrics.halfHeight

        local innerHalfWidth = math.max(backdropHalfWidth - BACKDROP_RECT_PADDING, baseCellSize * 0.5)
        local innerHalfHeight = math.max(backdropHalfHeight - BACKDROP_RECT_PADDING, baseCellSize * 0.5)
        local availableWidth = math.max(innerHalfWidth * 2, baseCellSize)
        local availableHeight = math.max(innerHalfHeight * 2, baseCellSize)
        local backdropInnerLeft = backdropCenterX - availableWidth / 2
        local backdropInnerTop = backdropCenterY - availableHeight / 2
        local backdropInnerRight = backdropInnerLeft + availableWidth
        local backdropInnerBottom = backdropInnerTop + availableHeight

        local scaleWidth = availableWidth / baseWordWidth
        local scaleHeight = availableHeight / math.max(baseWordHeight, 1)
        local targetScale = math.min(scaleWidth, scaleHeight)

        local function finalizeLayout(wordScale)
                local scaleFactor = wordScale / (DEFAULT_WORD_SCALE ~= 0 and DEFAULT_WORD_SCALE or 1)
                local cellSize = baseCellSize * wordScale
                local spacing = baseSpacing * wordScale

                local wordWidth
                if letterCount <= 1 then
                        wordWidth = 3 * cellSize
                else
                        wordWidth = (letterCount * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
                end

                local ox = backdropInnerLeft + (availableWidth - wordWidth) / 2

                local wordHeight = math.max((maxRow - minRow) * cellSize, cellSize)
                local availableTop = backdropInnerTop
                local targetCenterY = availableTop + availableHeight * TITLE_WORD_VERTICAL_FRACTION
                local minCenterY = availableTop + wordHeight / 2
                local maxCenterY = availableTop + availableHeight - wordHeight / 2
                targetCenterY = math.max(minCenterY, math.min(targetCenterY, maxCenterY))

                local targetTop = targetCenterY - wordHeight / 2
                local oy = targetTop - minRow * cellSize

                return {
                        word = word,
                        letterCount = letterCount,
                        minRow = minRow,
                        maxRow = maxRow,
                        cellSize = cellSize,
                        spacing = spacing,
                        wordScale = wordScale,
                        scaleFactor = scaleFactor,
                        wordWidth = wordWidth,
                        wordHeight = wordHeight,
                        wordTop = targetTop,
                        wordBottom = targetTop + wordHeight,
                        availableWidth = availableWidth,
                        availableHeight = availableHeight,
                        backdropInnerLeft = backdropInnerLeft,
                        backdropInnerRight = backdropInnerRight,
                        backdropInnerTop = backdropInnerTop,
                        backdropInnerBottom = backdropInnerBottom,
                        backdropCenterX = backdropCenterX,
                        backdropCenterY = backdropCenterY,
                        innerHalfWidth = innerHalfWidth,
                        innerHalfHeight = innerHalfHeight,
                        ox = ox,
                        oy = oy,
                }
        end

        local initialScale = math.max(targetScale * TITLE_SCALE_MARGIN, MIN_WORD_SCALE)
        local layout = finalizeLayout(initialScale)

        local safeWidth, safeHalfWidth = computeRectSpanLimits(
                backdropCenterY,
                innerHalfWidth,
                innerHalfHeight,
                layout.wordTop,
                layout.wordBottom
        )

        if safeWidth > 0 and layout.wordWidth > safeWidth then
                local adjustedScale = layout.wordScale * safeWidth / layout.wordWidth
                layout = finalizeLayout(adjustedScale)

                safeWidth, safeHalfWidth = computeRectSpanLimits(
                        backdropCenterY,
                        innerHalfWidth,
                        innerHalfHeight,
                        layout.wordTop,
                        layout.wordBottom
                )

                if safeWidth > 0 and layout.wordWidth > safeWidth then
                        local fallbackScale = layout.wordScale
                        if safeHalfWidth and safeHalfWidth > 0 then
                                fallbackScale = math.max(
                                        MIN_WORD_SCALE,
                                        layout.wordScale * (safeHalfWidth * 2) / math.max(layout.wordWidth, 1)
                                )
                        end
                        layout = finalizeLayout(fallbackScale)
                end
        end

        return layout
end

local function drawTitleWord(layout)
	local trail = drawWord(layout.word, layout.ox, layout.oy, layout.cellSize, layout.spacing)
	if trail and #trail > 0 then
		local head = trail[#trail]
		Face:draw(head.x, head.y, layout.wordScale)
	end
	return trail
end

local function exportTitleLogo()
	local sw, sh = Screen:get()
	if not sw or not sh then
		sw, sh = love.graphics.getDimensions()
	end

	local layout = computeTitleLayout(sw, sh)
	if not layout or layout.word == "" then
		return
	end

	local marginX = math.ceil(math.max(layout.cellSize * 0.75, layout.wordScale * 8))
	local marginY = math.ceil(math.max(layout.cellSize * 0.75, layout.wordScale * 8))
	local canvasWidth = math.max(1, math.ceil(layout.wordWidth + marginX * 2))
	local canvasHeight = math.max(1, math.ceil(layout.wordHeight + marginY * 2))

	local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
	local previousCanvas = { love.graphics.getCanvas() }

	love.graphics.setCanvas(canvas)
	love.graphics.push("all")
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1, 1)

	local exportLayout = {
		word = layout.word,
		cellSize = layout.cellSize,
		spacing = layout.spacing,
		wordScale = layout.wordScale,
		ox = marginX,
		oy = marginY - layout.minRow * layout.cellSize,
	}
	drawTitleWord(exportLayout)

	love.graphics.pop()

	if previousCanvas[1] ~= nil then
		love.graphics.setCanvas(previousCanvas)
	else
		love.graphics.setCanvas()
	end

	local imageData = canvas:newImageData()
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = string.format("logo_%s.png", timestamp)
	imageData:encode("png", filename)

	canvas:release()

	print(("Saved logo screenshot to %s"):format(filename))
end

local function getDayUnit(count)
        if count == 1 then
                return Localization:get("common.day_unit_singular")
        end

        return Localization:get("common.day_unit_plural")
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
	leftx = { slot = "horizontal" },
	rightx = { slot = "horizontal" },
	lefty = { slot = "vertical" },
	righty = { slot = "vertical" },
	[1] = { slot = "horizontal" },
	[2] = { slot = "vertical" },
}

local function resetAnalogAxis()
	analogAxisDirections.horizontal = nil
	analogAxisDirections.vertical = nil
end

local function prepareStartAction(action)
        if type(action) ~= "string" then
                return action
        end

        if action ~= "game" then
                return action
        end

        local deepest = PlayerStats:get("deepestFloorReached") or 0
        if deepest <= 1 then
                return action
        end

        return {
                state = "floorselect",
                data = {
                        highestFloor = deepest,
                        defaultFloor = deepest,
                },
        }
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

local function setColorWithAlpha(color, alpha)
	local r, g, b, a = 1, 1, 1, alpha or 1
	if color then
		r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
		a = (color[4] or 1) * (alpha or 1)
	end
	love.graphics.setColor(r, g, b, a)
end

function Menu:enter()
        t = 0
        UI.clearButtons()

        Audio:playMusic("menu")
	Screen:update()

	if SHOW_DAILY_CHALLENGE_CARD then
		dailyChallenge = DailyChallenges:getDailyChallenge()
	else
		dailyChallenge = nil
	end
	dailyChallengeAnim = 0
        resetAnalogAxis()

        configureBackgroundEffect()

        buttons = buttonList:reset({})

        if not SHOW_MENU_BUTTONS then
                return
        end

        local sw, sh = Screen:get()
        local centerX = sw / 2

        local labels = {
                { key = "menu.start_game",   action = "game" },
		{ key = "menu.achievements", action = "achievementsmenu" },
		{ key = "menu.progression",  action = "metaprogression" },
		{ key = "menu.dev_page",     action = "dev" },
		{ key = "menu.settings",     action = "settings" },
		{ key = "menu.quit",         action = "quit" },
	}

	local totalButtonHeight = #labels * UI.spacing.buttonHeight + math.max(0, #labels - 1) * UI.spacing.buttonSpacing
	-- Shift the buttons down a bit so the title has breathing room.
	local startY = sh / 2 - totalButtonHeight / 2 + sh * 0.08

	local defs = {}

	for i, entry in ipairs(labels) do
		local x = centerX - UI.spacing.buttonWidth / 2
		local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)

		defs[#defs + 1] = {
			id = "menuButton" .. i,
			x = x,
			y = y,
			w = UI.spacing.buttonWidth,
			h = UI.spacing.buttonHeight,
			labelKey = entry.key,
			text = Localization:get(entry.key),
			action = entry.action,
			hovered = false,
			scale = 1,
			alpha = 0,
			offsetY = 50,
		}
	end

	buttons = buttonList:reset(defs)
end

function Menu:update(dt)
        t = t + dt

        local mx, my = love.mouse.getPosition()
        buttonList:updateHover(mx, my)

	if SHOW_DAILY_CHALLENGE_CARD and dailyChallenge then
		dailyChallengeAnim = math.min(dailyChallengeAnim + dt * 2, 1)
	end

        for i, btn in ipairs(buttons) do
                if btn.hovered then
                        btn.scale = math.min((btn.scale or 1) + dt * 5, 1.1)
                else
                        btn.scale = math.max((btn.scale or 1) - dt * 5, 1.0)
                end

                local appearDelay = (i - 1) * 0.08
                local appearTime = math.min((t - appearDelay) * 3, 1)
                btn.alpha = math.max(0, math.min(appearTime, 1))
                btn.offsetY = (1 - btn.alpha) * 50
        end

        if titleSaw then
                titleSaw:update(dt)
        end

        Face:update(dt)
end

function Menu:draw()
        local sw, sh = Screen:get()

        drawBackground(sw, sh)

        local layout = computeTitleLayout(sw, sh)
        local cellSize = layout.cellSize
        local wordScale = layout.wordScale
        local scaleFactor = layout.scaleFactor
        local wordWidth = layout.wordWidth
        local wordHeight = layout.wordHeight
        local availableWidth = layout.availableWidth
        local backdropInnerLeft = layout.backdropInnerLeft
        local backdropInnerRight = layout.backdropInnerRight
        local backdropInnerTop = layout.backdropInnerTop
        local backdropInnerBottom = layout.backdropInnerBottom
        local backdropCenterX = layout.backdropCenterX
        local backdropCenterY = layout.backdropCenterY
        local innerHalfWidth = layout.innerHalfWidth
        local innerHalfHeight = layout.innerHalfHeight
        local ox = layout.ox
        local oy = layout.oy

        if titleSaw then
                local sawRadius = titleSaw.radius or 1
                local sawScale = wordHeight / (2 * sawRadius)
                if sawScale <= 0 then
                        sawScale = 1
                end
                sawScale = sawScale * TITLE_SAW_SCALE_FACTOR

                local sawRadiusWorld = sawRadius * sawScale

                local desiredTrackLengthWorld = math.min(wordWidth + cellSize, availableWidth)
                local shortenedTrackLengthWorld = math.max(
                        2 * sawRadiusWorld,
                        desiredTrackLengthWorld - 90 * scaleFactor
                )
                local rightTrackShortening = 73 * scaleFactor
                shortenedTrackLengthWorld = math.max(2 * sawRadiusWorld, shortenedTrackLengthWorld - rightTrackShortening)

                local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
                local slotThicknessWorld = slotThicknessBase * sawScale

                local targetLeft = ox - 15 * scaleFactor
                local gapAboveWord = math.max(8 * scaleFactor, slotThicknessWorld * 0.35)
                local targetBottom = oy - gapAboveWord

                local minSawCenterY = backdropInnerTop + sawRadiusWorld
                local maxSawCenterY = backdropInnerBottom - sawRadiusWorld
                local sawY = targetBottom - slotThicknessWorld / 2 - 40 * scaleFactor
                if minSawCenterY and maxSawCenterY then
                        sawY = math.max(minSawCenterY, math.min(sawY, maxSawCenterY))
                end

                local sawTop = sawY - sawRadiusWorld
                local sawBottom = sawY + sawRadiusWorld
                local safeWidth, safeHalfWidth = computeRectSpanLimits(
                        backdropCenterY,
                        innerHalfWidth,
                        innerHalfHeight,
                        sawTop,
                        sawBottom
                )

                local maxTrackWorld = availableWidth
                if safeWidth and safeWidth > 0 then
                        maxTrackWorld = math.min(maxTrackWorld, safeWidth)
                end
                maxTrackWorld = math.max(maxTrackWorld, 2 * sawRadiusWorld)

                local targetTrackLengthWorld = math.min(shortenedTrackLengthWorld, maxTrackWorld)
                local targetTrackLengthBase = targetTrackLengthWorld / sawScale
                if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
                        titleSaw.trackLength = targetTrackLengthBase
                end

                local trackLengthWorld = math.min((titleSaw.trackLength or targetTrackLengthBase) * sawScale, maxTrackWorld)
                trackLengthWorld = math.max(trackLengthWorld, 2 * sawRadiusWorld)

                local targetTrackCenter = targetLeft + trackLengthWorld / 2
                local trackMin = backdropInnerLeft + trackLengthWorld / 2
                local trackMax = backdropInnerRight - trackLengthWorld / 2

                if safeHalfWidth and safeHalfWidth > 0 then
                        local allowedTrackOffset = math.max(0, safeHalfWidth - trackLengthWorld / 2)
                        local allowedSawOffset = math.max(0, safeHalfWidth - sawRadiusWorld)
                        trackMin = math.max(trackMin, backdropCenterX - allowedTrackOffset)
                        trackMax = math.min(trackMax, backdropCenterX + allowedTrackOffset)
                        trackMin = math.max(trackMin, backdropCenterX - allowedSawOffset + 8 * scaleFactor)
                        trackMax = math.min(trackMax, backdropCenterX + allowedSawOffset + 8 * scaleFactor)
                end

                if trackMin > trackMax then
                        local mid = (trackMin + trackMax) / 2
                        trackMin = mid
                        trackMax = mid
                end

                local clampedTrackCenter = math.max(trackMin, math.min(targetTrackCenter, trackMax))
                local clampedTrackLeft = clampedTrackCenter - trackLengthWorld / 2
                clampedTrackLeft = math.max(backdropInnerLeft, math.min(clampedTrackLeft, backdropInnerRight - trackLengthWorld))
                clampedTrackCenter = clampedTrackLeft + trackLengthWorld / 2

                local sawX = clampedTrackCenter - 8 * scaleFactor

                titleSaw:draw(sawX, sawY, sawScale)
        end

        drawTitleWord(layout)

	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey)
		end

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

	love.graphics.setFont(UI.fonts.small)
	love.graphics.setColor(Theme.textColor)
	love.graphics.print(Localization:get("menu.version"), 10, sh - 24)

	if SHOW_DAILY_CHALLENGE_CARD and dailyChallenge and dailyChallengeAnim > 0 then
                local alpha = math.min(1, dailyChallengeAnim)
                local eased = alpha * alpha
                local panelWidth = math.min(420, sw - 72)
                local padding = UI.spacing.panelPadding or 16
		local panelX = sw - panelWidth - 36
		local headerFont = UI.fonts.small
		local titleFont = UI.fonts.button
		local bodyFont = UI.fonts.body
		local progressFont = UI.fonts.small

		local headerText = Localization:get("menu.daily_panel_header")
		local titleText = Localization:get(dailyChallenge.titleKey, dailyChallenge.descriptionReplacements)
		local descriptionText = Localization:get(dailyChallenge.descriptionKey, dailyChallenge.descriptionReplacements)

		local _, descLines = bodyFont:getWrap(descriptionText, panelWidth - padding * 2)
		local descHeight = #descLines * bodyFont:getHeight()

		local statusBar = dailyChallenge.statusBar
		local ratio = 0
		local progressText = nil
		local statusBarHeight = 0
                local bonusText = nil
                local streakLines = {}

                if statusBar then
                        ratio = math.max(0, math.min(statusBar.ratio or 0, 1))
                        if statusBar.textKey then
                                progressText = Localization:get(statusBar.textKey, statusBar.replacements)
			end
			statusBarHeight = 10 + 14
			if progressText then
				statusBarHeight = statusBarHeight + progressFont:getHeight() + 6
			end
		end

                if dailyChallenge.xpReward and dailyChallenge.xpReward > 0 then
                        bonusText = Localization:get("menu.daily_panel_bonus", { xp = dailyChallenge.xpReward })
                end

                local currentStreak = math.max(0, PlayerStats:get("dailyChallengeStreak") or 0)
                local bestStreak = math.max(currentStreak, PlayerStats:get("dailyChallengeBestStreak") or 0)

                if currentStreak > 0 then
                        streakLines[#streakLines + 1] = Localization:get("menu.daily_panel_streak", {
                                streak = currentStreak,
                                unit = getDayUnit(currentStreak),
                        })

                        streakLines[#streakLines + 1] = Localization:get("menu.daily_panel_best", {
                                best = bestStreak,
                                unit = getDayUnit(bestStreak),
                        })

                        local messageKey = dailyChallenge.completed and "menu.daily_panel_complete_message" or "menu.daily_panel_keep_alive"
                        streakLines[#streakLines + 1] = Localization:get(messageKey)
                else
                        streakLines[#streakLines + 1] = Localization:get("menu.daily_panel_start")
                end

                local panelHeight = padding * 2
                        + headerFont:getHeight()
                        + 6
                        + titleFont:getHeight()
                        + 10
                        + descHeight
                        + (bonusText and (progressFont:getHeight() + 10) or 0)
                        + statusBarHeight

                if #streakLines > 0 then
                        panelHeight = panelHeight + 8
                        for i = 1, #streakLines do
                                panelHeight = panelHeight + progressFont:getHeight()
                                if i < #streakLines then
                                        panelHeight = panelHeight + 4
                                end
                        end
                end

                local panelY = math.max(36, sh - panelHeight - 36)

                setColorWithAlpha(Theme.shadowColor, eased * 0.7)
                love.graphics.rectangle("fill", panelX + 6, panelY + 8, panelWidth, panelHeight, 14, 14)

		setColorWithAlpha(Theme.panelColor, alpha)
		UI.drawRoundedRect(panelX, panelY, panelWidth, panelHeight, 14)

		setColorWithAlpha(Theme.panelBorder, alpha)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 14, 14)

		local textX = panelX + padding
		local textY = panelY + padding

		love.graphics.setFont(headerFont)
		setColorWithAlpha(Theme.shadowColor, alpha)
		love.graphics.print(headerText, textX + 2, textY + 2)
		setColorWithAlpha(Theme.textColor, alpha)
		love.graphics.print(headerText, textX, textY)

		textY = textY + headerFont:getHeight() + 6

		love.graphics.setFont(titleFont)
		love.graphics.print(titleText, textX, textY)

		textY = textY + titleFont:getHeight() + 10

		love.graphics.setFont(bodyFont)
		love.graphics.printf(descriptionText, textX, textY, panelWidth - padding * 2)

		textY = textY + descHeight

                if bonusText then
                        textY = textY + 8
                        love.graphics.setFont(progressFont)
                        love.graphics.print(bonusText, textX, textY)
                        textY = textY + progressFont:getHeight()
                end

                if #streakLines > 0 then
                        textY = textY + 8
                        love.graphics.setFont(progressFont)
                        for i, line in ipairs(streakLines) do
                                if i == #streakLines and not dailyChallenge.completed then
                                        setColorWithAlpha(Theme.warningColor or Theme.accentTextColor, alpha)
                                else
                                        setColorWithAlpha(Theme.textColor, alpha)
                                end
                                love.graphics.print(line, textX, textY)
                                textY = textY + progressFont:getHeight()
                                if i < #streakLines then
                                        textY = textY + 4
                                end
                        end
                        setColorWithAlpha(Theme.textColor, alpha)
                end

                if statusBar then
                        textY = textY + 10
                        love.graphics.setFont(progressFont)

                        if progressText then
				love.graphics.print(progressText, textX, textY)
				textY = textY + progressFont:getHeight() + 6
			end

			local barHeight = 14
			local barWidth = panelWidth - padding * 2

			setColorWithAlpha({0, 0, 0, 0.35}, alpha)
			UI.drawRoundedRect(textX, textY, barWidth, barHeight, 8)

			local fillWidth = barWidth * ratio
			if fillWidth > 0 then
				setColorWithAlpha(Theme.progressColor, alpha)
				UI.drawRoundedRect(textX, textY, fillWidth, barHeight, 8)
			end

			setColorWithAlpha(Theme.panelBorder, alpha)
			love.graphics.setLineWidth(1.5)
			love.graphics.rectangle("line", textX, textY, barWidth, barHeight, 8, 8)

			textY = textY + barHeight
		end
	end
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
	elseif key == LOGO_EXPORT_KEY then
		exportTitleLogo()
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
