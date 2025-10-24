local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local DrawWord = require("drawword")
local RenderLayers = require("renderlayers")
local Face = require("face")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")
local PlayerStats = require("playerstats")
local SawActor = require("sawactor")
local Tooltip = require("tooltip")

local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin

local Menu = {
	transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local buttonList = ButtonList.new()
local buttons = {}
local t = 0
local dailyChallenge = nil
local dailyChallengeAnim = 0
local DAILY_BAR_CELEBRATION_DURATION = 6
local DAILY_BAR_CELEBRATION_FADE_WINDOW = 0.85
local DAILY_BAR_CELEBRATION_MAX_SPARKLE_DURATION = 1
local DAILY_BAR_CELEBRATION_SPAWN_WINDOW = max(0, DAILY_BAR_CELEBRATION_DURATION - DAILY_BAR_CELEBRATION_MAX_SPARKLE_DURATION)

local streakLineArgs = {streak = 0, unit = nil}
local bestLineArgs = {best = 0, unit = nil}
local resetTooltipArgs = {time = nil}
local DAILY_PANEL_OUTLINE_COLOR = {0, 0, 0, 1}

local dailyBarCelebration = {
	active = false,
	time = 0,
	spawnTimer = 0,
	sparkles = {},
	finished = false,
}
local analogAxisDirections = {horizontal = nil, vertical = nil}
local titleSaw = SawActor.new()

local random = (love.math and love.math.random) or math.random

local BACKGROUND_EFFECT_TYPE = "afterglowPulse"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function copyColor(color)
        if not color then
                return {0, 0, 0, 1}
        end

        return {
                color[1] or 0,
                color[2] or 0,
                color[3] or 0,
                color[4] == nil and 1 or color[4],
        }
end

local function lightenColor(color, factor)
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

local function darkenColor(color, factor)
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

local function withAlpha(color, alpha)
        local r = color[1] or 1
        local g = color[2] or 1
        local b = color[3] or 1
        local a = color[4] == nil and 1 or color[4]
        return {r, g, b, a * alpha}
end

local function configureBackgroundEffect()
        local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
        if not effect then
                backgroundEffect = nil
                return
        end

        local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
        local baseColor = copyColor(Theme.bgColor or {0.12, 0.12, 0.14, 1})
        local coolAccent = Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
        local accent = lightenColor(copyColor(coolAccent), 0.18)
        accent[4] = 1

        local pulse = lightenColor(copyColor(Theme.panelBorder or Theme.progressColor or accent), 0.26)
        pulse[4] = 1

        baseColor = darkenColor(baseColor, 0.15)
        baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

        local vignette = {
                color = withAlpha(lightenColor(copyColor(coolAccent), 0.05), 0.28),
                alpha = 0.28,
                steps = 3,
                thickness = nil,
        }

        effect.backdropIntensity = max(0.48, (defaultBackdrop or effect.backdropIntensity or 0.62) * 0.92)

        Shaders.configure(effect, {
                bgColor = baseColor,
                accentColor = accent,
                pulseColor = pulse,
        })

        effect.vignetteOverlay = vignette
        backgroundEffect = effect
end

local function drawBackground(sw, sh)
        love.graphics.setColor(Theme.bgColor)
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

local function resetDailyBarCelebration()
	dailyBarCelebration.active = false
	dailyBarCelebration.time = 0
	dailyBarCelebration.spawnTimer = 0
	dailyBarCelebration.sparkles = {}
	dailyBarCelebration.finished = false
end

local function spawnDailyBarSparkle()
	local sparkle = {
		x = random(),
		duration = 0.6 + random() * 0.4,
		life = 0,
		lift = 6 + random() * 6,
	}
	table.insert(dailyBarCelebration.sparkles, sparkle)
end

local function updateDailyBarCelebration(dt, shouldCelebrate)
	if shouldCelebrate then
		if not dailyBarCelebration.active and not dailyBarCelebration.finished then
			dailyBarCelebration.active = true
			dailyBarCelebration.time = 0
			dailyBarCelebration.spawnTimer = 0
			dailyBarCelebration.sparkles = {}
		end

                if dailyBarCelebration.active then
                        dailyBarCelebration.time = dailyBarCelebration.time + dt

                        if dailyBarCelebration.time < DAILY_BAR_CELEBRATION_DURATION then
                                if dailyBarCelebration.time < DAILY_BAR_CELEBRATION_SPAWN_WINDOW then
                                        dailyBarCelebration.spawnTimer = dailyBarCelebration.spawnTimer - dt

                                        local spawnInterval = 0.12
                                        while dailyBarCelebration.spawnTimer <= 0 do
                                                spawnDailyBarSparkle()
                                                dailyBarCelebration.spawnTimer = dailyBarCelebration.spawnTimer + spawnInterval

                                                if dailyBarCelebration.time >= DAILY_BAR_CELEBRATION_SPAWN_WINDOW then
                                                        break
                                                end
                                        end
                                else
                                        dailyBarCelebration.spawnTimer = 0
                                end
                        else
                                dailyBarCelebration.active = false
                                dailyBarCelebration.finished = true
                                dailyBarCelebration.spawnTimer = 0
                                dailyBarCelebration.time = DAILY_BAR_CELEBRATION_DURATION
                        end
                end
        elseif dailyBarCelebration.active or dailyBarCelebration.finished then
                resetDailyBarCelebration()
        end

        if dailyBarCelebration.active or dailyBarCelebration.finished then
                for i = #dailyBarCelebration.sparkles, 1, -1 do
                        local sparkle = dailyBarCelebration.sparkles[i]
                        sparkle.life = sparkle.life + dt
                        if sparkle.life >= sparkle.duration then
                                table.remove(dailyBarCelebration.sparkles, i)
			end
		end
	end
end

local function prepareStartAction(action)
        if type(action) ~= "string" then
                return action
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

function Menu:enter()
	t = 0
	UI.clearButtons()

	Audio:playMusic("menu")
	Screen:update()

	dailyChallenge = DailyChallenges:getDailyChallenge()
	dailyChallengeAnim = 0
	resetDailyBarCelebration()
	resetAnalogAxis()

	configureBackgroundEffect()

	local sw, sh = Screen:get()
        local centerX = sw / 2
        local menuLayout = UI.getMenuLayout(sw, sh)

	local labels = {
                {key = "menu.start_game",   action = "game"},
                {key = "menu.achievements", action = "achievementsmenu"},
                {key = "menu.progression",  action = "metaprogression"},
                {key = "menu.settings",     action = "settings"},
                {key = "menu.quit",         action = "quit"},
	}

        local totalButtonHeight = #labels * UI.spacing.buttonHeight + max(0, #labels - 1) * UI.spacing.buttonSpacing
        local stackBase = (menuLayout.bodyTop or menuLayout.stackTop or (sh * 0.2))
        local footerGuard = menuLayout.footerSpacing or UI.spacing.sectionSpacing or 24
        local lowerBound = (menuLayout.bottomY or (sh - (menuLayout.marginBottom or sh * 0.12))) - footerGuard
        local availableHeight = max(0, lowerBound - stackBase)
        local startY = stackBase + max(0, (availableHeight - totalButtonHeight) * 0.5)
        if startY + totalButtonHeight > lowerBound then
                startY = max(stackBase, lowerBound - totalButtonHeight)
        end

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
	Tooltip:update(dt, mx, my)

	if dailyChallenge then
		dailyChallengeAnim = min(dailyChallengeAnim + dt * 2, 1)
	end

	updateDailyBarCelebration(dt, shouldCelebrateDailyChallenge())

	for i, btn in ipairs(buttons) do
		if btn.hovered then
			btn.scale = min((btn.scale or 1) + dt * 5, 1.1)
		else
			btn.scale = max((btn.scale or 1) - dt * 5, 1.0)
		end

		local appearDelay = (i - 1) * 0.08
		local appearTime = min((t - appearDelay) * 3, 1)
		btn.alpha = max(0, min(appearTime, 1))
		btn.offsetY = (1 - btn.alpha) * 50
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
        local wordScale = 1.5

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
        local oy = baseOy + additionalOffset

	if titleSaw then
		local sawRadius = titleSaw.radius or 1
		local wordHeight = cellSize * 3
		local sawScale = wordHeight / (2 * sawRadius)
		if sawScale <= 0 then
			sawScale = 1
		end

		local desiredTrackLengthWorld = wordWidth + cellSize
		local shortenedTrackLengthWorld = max(2 * sawRadius * sawScale, desiredTrackLengthWorld - 90)
		local targetTrackLengthBase = shortenedTrackLengthWorld / sawScale
		if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
			titleSaw.trackLength = targetTrackLengthBase
		end

		local trackLengthWorld = (titleSaw.trackLength or targetTrackLengthBase) * sawScale
		local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
		local slotThicknessWorld = slotThicknessBase * sawScale

		local targetLeft = ox - 15
		local targetBottom = oy - 30

		local sawX = targetLeft + trackLengthWorld / 2
		local sawY = targetBottom - slotThicknessWorld / 2

		titleSaw:draw(sawX, sawY, sawScale)
	end

	local trail = DrawWord.draw(word, ox, oy, cellSize, spacing)

	RenderLayers:present()

	if trail and #trail > 0 then
		local head = trail[#trail]
		Face:draw(head.x, head.y, wordScale)
	end

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

        local versionFont = UI.fonts.small
        love.graphics.setFont(versionFont)
        love.graphics.setColor(Theme.textColor)
        local footerSpacing = menuLayout.footerSpacing or 24
        local versionHeight = versionFont and versionFont:getHeight() or 0
        local versionY = (menuLayout.bottomY or (sh - (menuLayout.marginBottom or footerSpacing))) - footerSpacing - versionHeight
        love.graphics.print(Localization:get("menu.version"), menuLayout.marginHorizontal or 16, versionY)

	if dailyChallenge and dailyChallengeAnim > 0 then
		local alpha = min(1, dailyChallengeAnim)
		local eased = alpha * alpha
                local panelWidth = min(menuLayout.panelMaxWidth or 420, max(280, menuLayout.contentWidth or (sw - 72)))
                local padding = UI.spacing.panelPadding or 16
                local panelX = sw - panelWidth - (menuLayout.marginHorizontal or 36)
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
		local streakText = nil
		local streakHeight = 0

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
		if dailyChallenge.xpReward and dailyChallenge.xpReward > 0 then
			headerText = string.format("%s · +%d XP", headerText, dailyChallenge.xpReward)
		end

		local currentStreak = max(0, PlayerStats:get("dailyChallengeStreak") or 0)
		local bestStreak = max(currentStreak, PlayerStats:get("dailyChallengeBestStreak") or 0)

		if currentStreak > 0 then
			streakLineArgs.streak = currentStreak
			streakLineArgs.unit = getDayUnit(currentStreak)
			local streakLine = Localization:get("menu.daily_panel_streak", streakLineArgs)

			bestLineArgs.best = bestStreak
			bestLineArgs.unit = getDayUnit(bestStreak)
			local bestLine = Localization:get("menu.daily_panel_best", bestLineArgs)

			local messageKey = dailyChallenge.completed and "menu.daily_panel_complete_message" or "menu.daily_panel_keep_alive"
			local messageLine = Localization:get(messageKey)

			streakText = string.format("%s (%s) - %s", streakLine, bestLine, messageLine)
		else
			streakText = Localization:get("menu.daily_panel_start")
		end

		if streakText then
			local _, streakLinesWrapped = progressFont:getWrap(streakText, panelWidth - padding * 2)
			local lineCount = max(1, #streakLinesWrapped)
			streakHeight = lineCount * progressFont:getHeight()
		end

                local panelHeight = padding * 2
                + headerFont:getHeight()
                + 6
                + titleFont:getHeight()
		+ 10
		+ descHeight
		+ statusBarHeight

		if streakText then
			panelHeight = panelHeight + 8 + streakHeight
		end

                local panelY = max(menuLayout.marginTop or 36, (menuLayout.bottomY or (sh - (menuLayout.marginBottom or 36))) - panelHeight)

		local mx, my = love.mouse.getPosition()
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
                        })
		else
			Tooltip:hide("dailyChallengeReset")
		end

                setColorWithAlpha(Theme.shadowColor, eased * 0.7)
                love.graphics.rectangle("fill", panelX + 5, panelY + 5, panelWidth, panelHeight, 14, 14)

		setColorWithAlpha(Theme.panelColor, alpha)
		UI.drawRoundedRect(panelX, panelY, panelWidth, panelHeight, 14)

                setColorWithAlpha(DAILY_PANEL_OUTLINE_COLOR, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 14, 14)
                love.graphics.setLineWidth(1)

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

		if streakText then
			textY = textY + 8
			love.graphics.setFont(progressFont)
			if currentStreak > 0 and not dailyChallenge.completed then
				setColorWithAlpha(Theme.warningColor or Theme.accentTextColor, alpha)
			else
				setColorWithAlpha(Theme.textColor, alpha)
			end
			love.graphics.printf(streakText, textX, textY, panelWidth - padding * 2)
			textY = textY + streakHeight
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

                        local celebrationVisible = ratio >= 0.999 and (dailyBarCelebration.active or #dailyBarCelebration.sparkles > 0)
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

                                local shimmerWidth = max(barWidth * 0.3, barHeight)
                                local shimmerProgress = (sin(timer * 2.2) * 0.5) + 0.5
                                local shimmerX = textX + shimmerProgress * (barWidth - shimmerWidth)
                                local shimmerAlpha = (0.35 + 0.25 * sin(timer * 3.1)) * fadeAlpha

                                if shimmerAlpha > 0 then
                                        setColorWithAlpha({1, 1, 1, shimmerAlpha}, alpha)
                                        UI.drawRoundedRect(shimmerX, textY, shimmerWidth, barHeight, 8)
                                end

                                for _, sparkle in ipairs(dailyBarCelebration.sparkles) do
                                        local progress = min(1, sparkle.life / sparkle.duration)
                                        local sparkleAlpha = (1 - progress) * alpha
                                        if sparkleAlpha > 0 then
                                                local sparkleX = textX + sparkle.x * barWidth
                                                local baseY = textY + barHeight / 2
						local offset = (0.5 - progress) * (barHeight + sparkle.lift)
						local sparkleY = baseY + offset
						local size = 2 + (1 - progress) * 3

						love.graphics.setColor(1, 1, 1, sparkleAlpha)
						love.graphics.setLineWidth(1.2)
						love.graphics.line(sparkleX - size, sparkleY, sparkleX + size, sparkleY)
						love.graphics.line(sparkleX, sparkleY - size, sparkleX, sparkleY + size)
					end
				end

				love.graphics.setColor(1, 1, 1, 1)
			end

			setColorWithAlpha(Theme.panelBorder, alpha)
			love.graphics.setLineWidth(1.5)
			love.graphics.rectangle("line", textX, textY, barWidth, barHeight, 8, 8)

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
