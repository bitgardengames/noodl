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
local analogAxisDirections = { horizontal = nil, vertical = nil }
local titleSaw = SawActor.new()

local BACKGROUND_EFFECT_TYPE = "menuConstellation"
local backgroundEffectCache = {}
local backgroundEffect = nil

local BACKDROP_BOX_WIDTH = 920
local BACKDROP_BOX_HEIGHT = 430
local BACKDROP_BOX_LINE_WIDTH = 12

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

local function drawBackground(sw, sh)
        love.graphics.setColor(Theme.bgColor)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        if not backgroundEffect then
                configureBackgroundEffect()
        end

        local boxX = (sw - BACKDROP_BOX_WIDTH) / 2
        local boxY = (sh - BACKDROP_BOX_HEIGHT) / 2

        if backgroundEffect then
                local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
                Shaders.draw(backgroundEffect, boxX, boxY, BACKDROP_BOX_WIDTH, BACKDROP_BOX_HEIGHT, intensity)
        end

        if BACKDROP_BOX_LINE_WIDTH > 0 then
                local halfLineWidth = BACKDROP_BOX_LINE_WIDTH / 2
                love.graphics.setColor(Theme.buttonHover)
                love.graphics.setLineWidth(BACKDROP_BOX_LINE_WIDTH)
                love.graphics.rectangle(
                        "line",
                        boxX - halfLineWidth,
                        boxY - halfLineWidth,
                        BACKDROP_BOX_WIDTH + BACKDROP_BOX_LINE_WIDTH,
                        BACKDROP_BOX_HEIGHT + BACKDROP_BOX_LINE_WIDTH
                )
                love.graphics.setLineWidth(1)
        end

        love.graphics.setColor(1, 1, 1, 1)
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

	dailyChallenge = DailyChallenges:getDailyChallenge()
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

	if dailyChallenge then
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

        local baseCellSize = 20
        local baseSpacing = 10
        local wordScale = 3 * 0.9

        local cellSize = baseCellSize * wordScale
        local word = Localization:get("menu.title_word")
        local spacing = baseSpacing * wordScale
        local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
        local ox = (sw - wordWidth) / 2

        local bounds = drawWord.getBounds and drawWord.getBounds(word)
        local minRow = bounds and bounds.minY or 0
        local maxRow = bounds and bounds.maxY or 3
        local wordHeight = math.max((maxRow - minRow) * cellSize, cellSize)
        local backdropCenterY = sh / 2
        local targetTop = backdropCenterY - wordHeight / 2
        local oy = targetTop - minRow * cellSize

        if titleSaw then
                local sawRadius = titleSaw.radius or 1
                local sawScale = wordHeight / (2 * sawRadius)
                if sawScale <= 0 then
                        sawScale = 1
                end
                sawScale = sawScale * 0.9

                local desiredTrackLengthWorld = wordWidth + cellSize
                local shortenedTrackLengthWorld = math.max(2 * sawRadius * sawScale, desiredTrackLengthWorld - 90)
                local targetTrackLengthBase = shortenedTrackLengthWorld / sawScale
                if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
                        titleSaw.trackLength = targetTrackLengthBase
                end

                local trackLengthWorld = (titleSaw.trackLength or targetTrackLengthBase) * sawScale
                local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
                local slotThicknessWorld = slotThicknessBase * sawScale

                local targetLeft = ox - 15
                local gapAboveWord = math.max(8, slotThicknessWorld * 0.35)
                local targetBottom = oy - gapAboveWord

                local sawX = targetLeft + trackLengthWorld / 2
                local sawY = targetBottom - slotThicknessWorld / 2

                titleSaw:draw(sawX, sawY, sawScale)
        end

        local trail = drawWord(word, ox, oy, cellSize, spacing)

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

	love.graphics.setFont(UI.fonts.small)
	love.graphics.setColor(Theme.textColor)
	love.graphics.print(Localization:get("menu.version"), 10, sh - 24)

        if dailyChallenge and dailyChallengeAnim > 0 then
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
