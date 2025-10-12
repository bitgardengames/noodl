local Screen = require("screen")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")

local GameOver = { isVictory = false }

local unpack = unpack

local ANALOG_DEADZONE = 0.35

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
local fontSmall
local fontBadge
local fontProgressTitle
local fontProgressValue
local fontProgressSmall
local stats = {}
local buttonList = ButtonList.new()
local analogAxisDirections = { horizontal = nil, vertical = nil }

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

local function getStatCardHeight()
	return (UI.scaled and UI.scaled(96, 72)) or 96
end

local function getStatCardSpacing()
	return (UI.scaled and UI.scaled(18, 12)) or 18
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

local BACKGROUND_EFFECT_TYPE = "afterglowPulse"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function configureBackgroundEffect()
	local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		backgroundEffect = nil
		return
	end

	local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
	if GameOver.isVictory then
		effect.backdropIntensity = 0.72
	else
		effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.62
	end

	local accent = Theme.warningColor
	local pulse = Theme.progressColor

	if GameOver.isVictory then
		accent = Theme.progressColor
		pulse = Theme.accentTextColor or Theme.progressColor
	end

	Shaders.configure(effect, {
		bgColor = Theme.bgColor,
		accentColor = accent,
		pulseColor = pulse,
	})

	backgroundEffect = effect
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

local function copyColor(color)
	if type(color) ~= "table" then
		return { 1, 1, 1, 1 }
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
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
	return { r, g, b, a * alpha }
end

local function randomRange(minimum, maximum)
	return minimum + (maximum - minimum) * love.math.random()
end

local function approachExp(current, target, dt, speed)
	if speed <= 0 then
		return target
	end

	local factor = 1 - math.exp(-speed * dt)
	return current + (target - current) * factor
end

local function spawnFruitAnimation(anim)
	if not anim or not anim.barMetrics then
		return false
	end

	local metrics = anim.barMetrics
	local palette = anim.fruitPalette or { Theme.appleColor }
	local color = copyColor(palette[love.math.random(#palette)] or Theme.appleColor)

	local fruit
	if metrics.style == "radial" then
		local centerX = metrics.centerX or 0
		local centerY = metrics.centerY or 0
		local radius = metrics.outerRadius or metrics.radius or 56
		local launchOffsetX = randomRange(-radius * 0.6, radius * 0.6)
		local launchLift = math.max(radius * 0.8, 54)
		local launchX = centerX + launchOffsetX
		local launchY = centerY - radius - launchLift
		local controlX = (launchX + centerX) / 2 + randomRange(-radius * 0.25, radius * 0.25)
		local controlY = math.min(launchY, centerY) - math.max(radius * 0.75, 48)

		fruit = {
			timer = 0,
			duration = randomRange(0.55, 0.85),
			startX = launchX,
			startY = launchY,
			controlX = controlX,
			controlY = controlY,
			endX = centerX,
			endY = centerY,
			scaleStart = randomRange(0.42, 0.52),
			scalePeak = randomRange(0.68, 0.82),
			scaleEnd = randomRange(0.50, 0.64),
			wobbleSeed = love.math.random() * math.pi * 2,
			wobbleSpeed = randomRange(4.5, 6.5),
			color = color,
			splashAngle = clamp(anim.visualPercent or 0, 0, 1),
		}
	else
		local launchX = metrics.x + metrics.width * 0.5
		local launchY = metrics.y - math.max(metrics.height * 2.2, 72)

		local endX = metrics.x + metrics.width * 0.5
		local endY = metrics.y + metrics.height * 0.5
		local apexLift = math.max(metrics.height * 1.35, 64)
		local controlX = (launchX + endX) / 2
		local controlY = math.min(launchY, endY) - apexLift

		fruit = {
			timer = 0,
			duration = randomRange(0.55, 0.85),
			startX = launchX,
			startY = launchY,
			controlX = controlX,
			controlY = controlY,
			endX = endX,
			endY = endY,
			scaleStart = randomRange(0.42, 0.52),
			scalePeak = randomRange(0.68, 0.82),
			scaleEnd = randomRange(0.50, 0.64),
			wobbleSeed = love.math.random() * math.pi * 2,
			wobbleSpeed = randomRange(4.5, 6.5),
			color = color,
		}
	end

	anim.fruitAnimations = anim.fruitAnimations or {}
	table.insert(anim.fruitAnimations, fruit)
	anim.fruitRemaining = math.max(0, (anim.fruitRemaining or 0) - 1)

	return true
end

local function updateFruitAnimations(anim, dt)
	if not anim or (anim.fruitTotal or 0) <= 0 then
		return
	end

	anim.fruitSpawnTimer = (anim.fruitSpawnTimer or 0) + dt
	local interval = anim.fruitSpawnInterval or 0.08

	local metrics = anim.barMetrics

	if metrics then
		while (anim.fruitRemaining or 0) > 0 and anim.fruitSpawnTimer >= interval do
			if not spawnFruitAnimation(anim) then
				break
			end
			anim.fruitSpawnTimer = anim.fruitSpawnTimer - interval
			interval = anim.fruitSpawnInterval or interval
		end
	end

	local active = anim.fruitAnimations or {}
	for index = #active, 1, -1 do
		local fruit = active[index]
		fruit.timer = (fruit.timer or 0) + dt
		local duration = fruit.duration or 0.6
		if duration <= 0 then
			table.remove(active, index)
		else
			local progress = clamp(fruit.timer / duration, 0, 1)
			fruit.progress = progress

			if progress >= 1 then
				if not fruit.landed then
					fruit.landed = true
					fruit.fade = 0
					fruit.landingTimer = 0
					fruit.splashTimer = 0
					fruit.splashDuration = fruit.splashDuration or 0.35

					local xpPer = anim.fruitXpPer or 0
					if xpPer > 0 then
						local pending = anim.pendingFruitXp or 0
						local delivered = anim.fruitDelivered or 0
						local remaining = math.max(0, (anim.fruitPoints or 0) - delivered - pending)
						local grant = math.min(remaining, xpPer)
						anim.pendingFruitXp = pending + grant
					end

					anim.barPulse = math.min(1.5, (anim.barPulse or 0) + 0.45)
				end

				fruit.landingTimer = (fruit.landingTimer or 0) + dt
				fruit.splashTimer = (fruit.splashTimer or 0) + dt
				fruit.fade = (fruit.fade or 0) + dt

				if fruit.fade >= 0.35 then
					table.remove(active, index)
				end
			end
		end
	end

end

local function drawFruitAnimations(anim)
	local fruits = anim and anim.fruitAnimations
	if not fruits or #fruits == 0 then
		return
	end

	for _, fruit in ipairs(fruits) do
		local progress = clamp(fruit.progress or 0, 0, 1)
		local eased = easeOutQuad(progress)
		local inv = 1 - eased
		local pathX = inv * inv * (fruit.startX or 0)
			+ 2 * inv * eased * (fruit.controlX or 0)
			+ eased * eased * (fruit.endX or 0)
		local pathY = inv * inv * (fruit.startY or 0)
			+ 2 * inv * eased * (fruit.controlY or 0)
			+ eased * eased * (fruit.endY or 0)

		local wobble = math.sin((fruit.wobbleSeed or 0) + (fruit.wobbleSpeed or 5.2) * eased)
		local wobbleMul = 0.95 + wobble * 0.04

		local scaleStart = fruit.scaleStart or 0.5
		local scalePeak = fruit.scalePeak or (scaleStart * 1.35)
		local scaleEnd = fruit.scaleEnd or (scaleStart * 0.95)
		local scale
		if progress < 0.5 then
			local t = clamp(progress / 0.5, 0, 1)
			scale = scaleStart + (scalePeak - scaleStart) * easeOutBack(t)
		else
			local t = clamp((progress - 0.5) / 0.5, 0, 1)
			scale = scalePeak + (scaleEnd - scalePeak) * easeOutQuad(t)
		end

		local radius = 12 * scale * wobbleMul
		local fadeMul = 1
		if fruit.fade then
			fadeMul = clamp(1 - fruit.fade / 0.35, 0, 1)
		end

		local color = fruit.color or Theme.appleColor
		local highlight = lightenColor(color, 0.42)

		local drawFruit = not fruit.landed or (fruit.splashTimer or 0) < 0.08
		if drawFruit and fadeMul > 0 then
			love.graphics.setColor(0, 0, 0, 0.25 * fadeMul)
			love.graphics.ellipse("fill", pathX + 3, pathY + 3 + wobble * 3, radius * 1.05, radius * 0.9, 30)

			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * fadeMul)
			love.graphics.circle("fill", pathX, pathY + wobble * 2, radius, 30)

			love.graphics.setColor(0, 0, 0, 0.85 * fadeMul)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", pathX, pathY + wobble * 2, radius, 30)

			love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.7) * fadeMul)
			love.graphics.circle("fill", pathX - radius * 0.35, pathY + wobble * 2 - radius * 0.45, radius * 0.45, 24)
		end

		love.graphics.setLineWidth(1)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function drawBackground(sw, sh)
	local baseColor = (UI.colors and UI.colors.background) or Theme.bgColor
	love.graphics.setColor(baseColor)
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

-- All button definitions in one place
local buttonDefs = {
	{ id = "goPlay", textKey = "gameover.play_again", action = "game" },
	{ id = "goMenu", textKey = "gameover.quit_to_menu", action = "menu" },
}

local function calculateStatLayout(contentWidth, padding, count)
	local totalCards = math.max(0, count or 0)
	local availableWidth = math.max(0, contentWidth - padding * 2)
	local maxColumns = math.min(totalCards, 3)
	local columns = math.max(1, maxColumns)
	local statCardSpacing = getStatCardSpacing()
	local statCardMinWidth = getStatCardMinWidth()
	local statCardHeight = getStatCardHeight()

	if totalCards == 0 then
		return {
			columns = 0,
			rows = 0,
			cardWidth = 0,
			height = 0,
			spacing = statCardSpacing,
			availableWidth = availableWidth,
		}
	end

	while columns > 1 do
		local tentativeWidth = (availableWidth - statCardSpacing * (columns - 1)) / columns
		if tentativeWidth >= statCardMinWidth then
			break
		end
		columns = columns - 1
	end

	local cardWidth
	if columns <= 1 then
		columns = 1
		cardWidth = availableWidth
	else
		cardWidth = (availableWidth - statCardSpacing * (columns - 1)) / columns
	end

	cardWidth = math.max(0, cardWidth)

	local rows = math.ceil(totalCards / columns)
	local height = rows * statCardHeight + math.max(0, rows - 1) * statCardSpacing

	return {
		columns = columns,
		rows = rows,
		cardWidth = cardWidth,
		height = height,
		spacing = statCardSpacing,
		availableWidth = availableWidth,
	}
end

local function calculateAchievementsLayout(achievements, panelWidth, sectionPadding, innerSpacing, smallSpacing)
	local list = achievements or {}
	if not list or #list == 0 or (panelWidth or 0) <= 0 then
		return nil
	end

	local headerHeight = fontProgressSmall:getHeight()
	local textWidth = math.max(0, panelWidth - sectionPadding * 2)
	local totalHeight = headerHeight
	local entries = {}

	for index, achievement in ipairs(list) do
		totalHeight = totalHeight + innerSpacing
		totalHeight = totalHeight + fontSmall:getHeight()

		local description = achievement.description or ""
		local descriptionLines = 0
		if description ~= "" then
			if textWidth > 0 then
				local _, wrapped = fontProgressSmall:getWrap(description, textWidth)
				if wrapped and #wrapped > 0 then
					descriptionLines = #wrapped
				else
					descriptionLines = 1
				end
			else
				descriptionLines = 1
			end
		end

		totalHeight = totalHeight + descriptionLines * fontProgressSmall:getHeight()

		entries[#entries + 1] = {
			title = achievement.title or "",
			description = description,
			descriptionLines = descriptionLines,
		}

		if index < #list then
			totalHeight = totalHeight + smallSpacing
		end
	end

	local panelHeight = sectionPadding * 2 + totalHeight
	panelHeight = math.floor(panelHeight + 0.5)

	return {
		entries = entries,
		height = panelHeight,
		headerHeight = headerHeight,
		textWidth = textWidth,
	}
end

local function defaultButtonLayout(sw, sh, defs, startY)
	local list = {}
	local buttonWidth, buttonHeight, buttonSpacing = getButtonMetrics()
	local centerX = sw / 2 - buttonWidth / 2

	for i, def in ipairs(defs) do
		local y = startY + (i - 1) * (buttonHeight + buttonSpacing)
		list[#list + 1] = {
			id = def.id,
			textKey = def.textKey,
			text = def.text,
			action = def.action,
			x = centerX,
			y = y,
			w = buttonWidth,
			h = buttonHeight,
		}
	end

	return list
end

local function drawCenteredPanel(x, y, width, height, radius)
	UI.drawPanel(x, y, width, height, {
		radius = radius,
		shadowOffset = UI.spacing.shadowOffset,
		fill = Theme.panelColor,
		borderColor = Theme.panelBorder,
		borderWidth = 2,
	})
end

local function drawInsetPanel(x, y, width, height, options)
	if width <= 0 or height <= 0 then
		return
	end

	options = options or {}
	local radius = options.radius or 16
	local lightenFactor = options.lighten or 0.12
	local baseAlpha = options.alpha or 0.88
	local borderAlpha = options.borderAlpha or 0.65
	local borderWidth = options.borderWidth or 1

	local baseColor = Theme.panelColor or { 0.18, 0.18, 0.22, 1 }
	local fillColor = withAlpha(lightenColor(baseColor, lightenFactor), baseAlpha)
	local borderColor = withAlpha(Theme.panelBorder or { 0.35, 0.3, 0.5, 1 }, borderAlpha)

	UI.drawPanel(x, y, width, height, {
		radius = radius,
		shadowOffset = 0,
		fill = fillColor,
		borderColor = borderColor,
		borderWidth = borderWidth,
	})
end

local function handleButtonAction(_, action)
	return action
end

function GameOver:updateLayoutMetrics()
	if not fontSmall or not fontScore then
		return false
	end

	local sw = select(1, Screen:get())
	local padding = 24
	local margin = 24
	local maxAllowed = math.max(40, sw - margin)
	local safeMaxWidth = math.max(80, sw - margin * 2)
	safeMaxWidth = math.min(safeMaxWidth, maxAllowed)
	local preferredWidth = math.min(sw * 0.72, 640)
	local minWidth = math.min(320, safeMaxWidth)
	local contentWidth = math.max(minWidth, math.min(preferredWidth, safeMaxWidth))
	local innerWidth = contentWidth - padding * 2

	local sectionPadding = getSectionPadding()
	local sectionSpacing = getSectionSpacing()
	local innerSpacing = getSectionInnerSpacing()
	local smallSpacing = getSectionSmallSpacing()
	local headerSpacing = getSectionHeaderSpacing()

	local wrapLimit = math.max(0, innerWidth - sectionPadding * 2)

	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
	local messageLines = math.max(1, #wrappedMessage)
	local messageHeight = messageLines * fontSmall:getHeight()
	local messagePanelHeight = math.floor(messageHeight + sectionPadding * 2 + 0.5)

	local headerFont = UI.fonts.heading or fontSmall
	local headerHeight = headerFont:getHeight()

	local scoreHeaderHeight = fontProgressSmall:getHeight()
	local scoreNumberHeight = fontScore:getHeight()
	local badgeHeight = 0
	if self.isNewHighScore then
		badgeHeight = fontBadge:getHeight() + smallSpacing
	end
	local scorePanelHeight = sectionPadding * 2 + scoreHeaderHeight + innerSpacing + scoreNumberHeight + badgeHeight
	scorePanelHeight = math.floor(scorePanelHeight + 0.5)

	local statCards = 2
	local achievementsList = self.achievementsEarned or {}

	local xpPanelHeight = 0
	if self.progressionAnimation then
		local celebrations = (self.progressionAnimation.celebrations and #self.progressionAnimation.celebrations) or 0
		local baseHeight = self.baseXpSectionHeight or self.xpSectionHeight or 0
		local celebrationSpacing = getCelebrationEntrySpacing()
		local targetHeight = baseHeight + celebrations * celebrationSpacing
		local xpContentHeight = math.max(160, baseHeight, targetHeight)
		xpPanelHeight = math.floor(xpContentHeight + 0.5)
	end

	local minColumnWidth = math.max(getStatCardMinWidth() + sectionPadding * 2, 260)
	local columnSpacing = sectionSpacing

	local function buildLayout(columnCount)
		columnCount = math.max(1, columnCount or 1)

		local availableWidth = math.max(0, innerWidth - sectionPadding * 2)
		if availableWidth <= 0 then
			return {
				columnCount = 1,
				columnWidth = 0,
				entries = {},
				columnsHeight = 0,
				sectionInfo = {},
			}
		end

		local width
		if columnCount <= 1 then
			columnCount = 1
			width = availableWidth
		else
			width = (availableWidth - columnSpacing * (columnCount - 1)) / columnCount
			if width < minColumnWidth then
				return nil
			end
		end

		if width <= 0 then
			return nil
		end

		local sections = {}
		local sectionInfo = {}

		if scorePanelHeight > 0 then
			sections[#sections + 1] = { id = "score", height = scorePanelHeight }
			sectionInfo.score = { height = scorePanelHeight }
		end

		local statLayout = calculateStatLayout(width, sectionPadding, statCards)
		local statHeight = sectionPadding * 2 + fontProgressSmall:getHeight()
		if (statLayout.height or 0) > 0 then
			statHeight = statHeight + innerSpacing + statLayout.height
		end
		statHeight = math.floor(statHeight + 0.5)
		if statHeight > 0 then
			sections[#sections + 1] = { id = "stats", height = statHeight, layoutData = statLayout }
			sectionInfo.stats = { height = statHeight, layout = statLayout }
		end

		local achievementsLayout = calculateAchievementsLayout(achievementsList, width, sectionPadding, innerSpacing, smallSpacing)
		if achievementsLayout and achievementsLayout.height > 0 then
			sections[#sections + 1] = {
				id = "achievements",
				height = achievementsLayout.height,
				layoutData = achievementsLayout,
			}
			sectionInfo.achievements = { height = achievementsLayout.height, layout = achievementsLayout }
		end

		if xpPanelHeight > 0 then
			sections[#sections + 1] = { id = "xp", height = xpPanelHeight }
			sectionInfo.xp = { height = xpPanelHeight }
		end

		if #sections == 0 then
			return {
				columnCount = columnCount,
				columnWidth = width,
				entries = {},
				columnsHeight = 0,
				sectionInfo = sectionInfo,
			}
		end

		local columnHeights = {}
		for i = 1, columnCount do
			columnHeights[i] = 0
		end

		local entries = {}
		for _, section in ipairs(sections) do
			local targetColumn = 1
			for i = 2, columnCount do
				if columnHeights[i] < columnHeights[targetColumn] - 0.01 then
					targetColumn = i
				end
			end

			local offsetY = columnHeights[targetColumn]
			entries[#entries + 1] = {
				id = section.id,
				column = targetColumn,
				x = (targetColumn - 1) * (width + (columnCount > 1 and columnSpacing or 0)),
				y = offsetY,
				width = width,
				height = section.height,
				layoutData = section.layoutData,
			}

			columnHeights[targetColumn] = columnHeights[targetColumn] + section.height + sectionSpacing
		end

		local maxColumnHeight = 0
		for i = 1, columnCount do
			local h = columnHeights[i]
			if h > 0 then
				h = h - sectionSpacing
			end
			if h > maxColumnHeight then
				maxColumnHeight = h
			end
		end

		return {
			columnCount = columnCount,
			columnWidth = width,
			entries = entries,
			columnsHeight = maxColumnHeight,
			sectionInfo = sectionInfo,
		}
	end

	local layoutOptions = { buildLayout(2), buildLayout(1) }
	local bestLayout = nil
	local baseHeight = padding * 2 + headerHeight + headerSpacing + messagePanelHeight

	for _, option in ipairs(layoutOptions) do
		if option then
			local entryCount = #(option.entries or {})
			local totalHeight = baseHeight
			if entryCount > 0 and (option.columnsHeight or 0) > 0 then
				totalHeight = totalHeight + sectionSpacing + option.columnsHeight
			elseif entryCount > 0 then
				totalHeight = totalHeight + sectionSpacing
			end
			option.totalHeight = totalHeight
			if not bestLayout or totalHeight < (bestLayout.totalHeight or math.huge) then
				bestLayout = option
			end
		end
	end

	if not bestLayout then
		bestLayout = {
			columnCount = 1,
			columnWidth = innerWidth - sectionPadding * 2,
			entries = {},
			columnsHeight = 0,
			sectionInfo = {},
			totalHeight = baseHeight,
		}
	end

	local summaryPanelHeight = math.floor((bestLayout.totalHeight or baseHeight) + 0.5)
	contentWidth = math.floor(contentWidth + 0.5)
	wrapLimit = math.floor(wrapLimit + 0.5)

	local layoutChanged = false
	if not self.summaryPanelHeight or math.abs(self.summaryPanelHeight - summaryPanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.contentWidth or math.abs(self.contentWidth - contentWidth) >= 1 then
		layoutChanged = true
	end
	if not self.wrapLimit or math.abs(self.wrapLimit - wrapLimit) >= 1 then
		layoutChanged = true
	end

	local previousLayout = self.summarySectionLayout or {}
	local previousEntries = previousLayout.entries or {}
	local newEntries = bestLayout.entries or {}
	if (previousLayout.columnCount or 0) ~= (bestLayout.columnCount or 0)
		or #previousEntries ~= #newEntries
		or math.abs((previousLayout.columnsHeight or 0) - (bestLayout.columnsHeight or 0)) >= 1 then
		layoutChanged = true
	else
		for index, entry in ipairs(newEntries) do
			local prev = previousEntries[index]
			if not prev
				or prev.id ~= entry.id
				or prev.column ~= entry.column
				or math.abs((prev.x or 0) - (entry.x or 0)) >= 1
				or math.abs((prev.y or 0) - (entry.y or 0)) >= 1
				or math.abs((prev.width or 0) - (entry.width or 0)) >= 1 then
				layoutChanged = true
				break
			end
		end
	end

	local statsInfo = bestLayout.sectionInfo.stats or {}
	local achievementsInfo = bestLayout.sectionInfo.achievements or {}
	local xpInfo = bestLayout.sectionInfo.xp or {}

	if not self.messagePanelHeight or math.abs(self.messagePanelHeight - messagePanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.scorePanelHeight or math.abs(self.scorePanelHeight - scorePanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.statPanelHeight or math.abs(self.statPanelHeight - (statsInfo.height or 0)) >= 1 then
		layoutChanged = true
	end
	if not self.achievementsPanelHeight or math.abs(self.achievementsPanelHeight - (achievementsInfo.height or 0)) >= 1 then
		layoutChanged = true
	end
	if not self.xpPanelHeight or math.abs(self.xpPanelHeight - (xpInfo.height or 0)) >= 1 then
		layoutChanged = true
	end

	self.summaryPanelHeight = summaryPanelHeight
	self.contentWidth = contentWidth
	self.contentPadding = padding
	self.wrapLimit = wrapLimit
	self.messageLines = messageLines
	self.messagePanelHeight = messagePanelHeight
	self.scorePanelHeight = scorePanelHeight
	self.statPanelHeight = statsInfo.height or 0
	self.xpPanelHeight = xpInfo.height or 0
	self.sectionPaddingValue = sectionPadding
	self.sectionSpacingValue = sectionSpacing
	self.sectionInnerSpacingValue = innerSpacing
	self.sectionSmallSpacingValue = smallSpacing
	self.sectionHeaderSpacingValue = headerSpacing
	self.innerContentWidth = innerWidth
	self.statLayout = statsInfo.layout
	self.achievementsPanelHeight = achievementsInfo.height or 0
	self.achievementsLayout = achievementsInfo.layout
	self.summarySectionLayout = bestLayout

	return layoutChanged
end

function GameOver:updateButtonLayout()
	local sw, sh = Screen:get()
	local _, buttonHeight, buttonSpacing = getButtonMetrics()
	local totalButtonHeight = #buttonDefs * buttonHeight + (#buttonDefs - 1) * buttonSpacing
	local panelY = 120
	local panelHeight = self.summaryPanelHeight or 0
	local contentBottom = panelY + panelHeight + 60
	local defaultStartY = math.max(math.floor(sh * 0.66), math.floor(sh - totalButtonHeight - 50))
	local startY = math.max(defaultStartY, math.floor(contentBottom))
	startY = math.min(startY, math.floor(sh - totalButtonHeight - 40))
	local defs = defaultButtonLayout(sw, sh, buttonDefs, startY)

	buttonList:reset(defs)
end

local function addCelebration(anim, entry)
	if not anim or not entry then
		return
	end

	anim.celebrations = anim.celebrations or {}
	entry.timer = 0
	entry.duration = entry.duration or 4.5
	table.insert(anim.celebrations, entry)

	local maxVisible = 3
	while #anim.celebrations > maxVisible do
		table.remove(anim.celebrations, 1)
	end
end

function GameOver:enter(data)
	UI.clearButtons()
	resetAnalogAxis()

	data = data or {cause = "unknown"}

	self.isVictory = data.won == true
	self.customTitle = type(data.storyTitle) == "string" and data.storyTitle or nil
	GameOver.isVictory = self.isVictory

	Audio:playMusic("scorescreen")
	Screen:update()

	local cause = data.cause or "unknown"
	if self.isVictory then
		local defaultVictory = Localization:get("gameover.victory_message")
		if defaultVictory == "gameover.victory_message" then
			defaultVictory = "Noodl wriggles home with a belly full of snacks."
		end
		self.deathMessage = data.endingMessage or defaultVictory
	else
		self.deathMessage = pickDeathMessage(cause)
	end
	self.summaryMessage = self.deathMessage

	configureBackgroundEffect()

	fontTitle = UI.fonts.display or UI.fonts.title
	fontScore = UI.fonts.title or UI.fonts.display
	fontSmall = UI.fonts.caption or UI.fonts.body
	fontBadge = UI.fonts.badge or UI.fonts.button
	fontProgressTitle = UI.fonts.heading or UI.fonts.subtitle
	fontProgressValue = UI.fonts.display or UI.fonts.title
	fontProgressSmall = UI.fonts.caption or UI.fonts.body

	-- Merge default stats with provided stats
	stats = {
		score       = 0,
		highScore   = 0,
		apples      = SessionStats:get("applesEaten"),
		totalApples = "?",
	}
	for k, v in pairs(data.stats or {}) do
		stats[k] = v
	end
	if data.score then stats.score = data.score end
	if data.highScore then stats.highScore = data.highScore end
	if data.apples then stats.apples = data.apples end
	if data.totalApples then stats.totalApples = data.totalApples end

	stats.highScore = stats.highScore or 0
	stats.totalApples = stats.totalApples or stats.apples or 0
	self.isNewHighScore = (stats.score or 0) > 0 and (stats.score or 0) >= (stats.highScore or 0)

	self.achievementsEarned = {}
	local runAchievements = SessionStats:get("runAchievements")
	if type(runAchievements) == "table" then
		for _, achievementId in ipairs(runAchievements) do
			local def = Achievements:getDefinition(achievementId)
			if def then
				self.achievementsEarned[#self.achievementsEarned + 1] = {
					id = achievementId,
					title = Localization:get(def.titleKey),
					description = Localization:get(def.descriptionKey),
				}
			end
		end
	end

	self.dailyChallengeResult = DailyChallenges:applyRunResults(SessionStats)
	local challengeBonusXP = 0
	if self.dailyChallengeResult then
		challengeBonusXP = math.max(0, self.dailyChallengeResult.xpAwarded or 0)
	end

	self.dailyStreakMessage = nil
	self.dailyStreakColor = nil
	if self.dailyChallengeResult and self.dailyChallengeResult.streakInfo then
		local info = self.dailyChallengeResult.streakInfo
		local streak = math.max(0, info.current or 0)
		local best = math.max(streak, info.best or 0)

		if streak > 0 then
			local replacements = {
				streak = streak,
				unit = getDayUnit(streak),
				best = best,
				bestUnit = getDayUnit(best),
			}

			local messageKey
			if self.dailyChallengeResult.completedNow then
				if info.wasNewBest then
					messageKey = "gameover.daily_streak_new_best"
				else
					messageKey = "gameover.daily_streak_extended"
				end
			elseif info.alreadyCompleted then
				messageKey = "gameover.daily_streak_already_complete"
			elseif info.needsCompletion then
				messageKey = "gameover.daily_streak_needs_completion"
			else
				messageKey = "gameover.daily_streak_status"
			end

			self.dailyStreakMessage = Localization:get(messageKey, replacements)

			if self.dailyChallengeResult.completedNow then
				if info.wasNewBest then
					self.dailyStreakColor = Theme.accentTextColor or UI.colors.accentText or UI.colors.highlight
				else
					self.dailyStreakColor = Theme.progressColor or UI.colors.progress or UI.colors.highlight
				end
			elseif info.alreadyCompleted then
				self.dailyStreakColor = UI.colors.mutedText or Theme.mutedTextColor or UI.colors.text
			elseif info.needsCompletion then
				self.dailyStreakColor = Theme.warningColor or UI.colors.warning or UI.colors.highlight
			else
				self.dailyStreakColor = UI.colors.highlight or UI.colors.text
			end
		end
	end

	self.progression = MetaProgression:grantRunPoints({
		apples = stats.apples or 0,
		score = stats.score or 0,
		bonusXP = challengeBonusXP,
	})

	self.xpSectionHeight = 0
	self.progressionAnimation = nil

	if self.progression then
		local startSnapshot = self.progression.start or { total = 0, level = 1, xpIntoLevel = 0, xpForNext = MetaProgression:getXpForLevel(1) }
		local resultSnapshot = self.progression.result or startSnapshot
		local baseHeight = 220
		if challengeBonusXP > 0 then
			baseHeight = baseHeight + 28
		end
		self.baseXpSectionHeight = baseHeight
		self.xpSectionHeight = baseHeight

		local fillSpeed = math.max(60, (self.progression.gained or 0) / 1.2)
		self.progressionAnimation = {
			displayedTotal = startSnapshot.total or 0,
			targetTotal = resultSnapshot.total or (startSnapshot.total or 0),
			displayedLevel = startSnapshot.level or 1,
			xpIntoLevel = startSnapshot.xpIntoLevel or 0,
			xpForLevel = startSnapshot.xpForNext or MetaProgression:getXpForLevel(startSnapshot.level or 1),
			displayedGained = 0,
			fillSpeed = fillSpeed,
			levelFlash = 0,
			celebrations = {},
			pendingMilestones = {},
			levelUnlocks = {},
			bonusXP = challengeBonusXP,
			barPulse = 0,
			pendingFruitXp = 0,
			fruitDelivered = 0,
			fillEaseSpeed = clamp(fillSpeed / 12, 6, 16),
		}

		local applesCollected = math.max(0, stats.apples or 0)
		local fruitPoints = 0
		if self.progression and self.progression.breakdown then
			fruitPoints = math.max(0, self.progression.breakdown.fruitPoints or 0)
		end
		local xpPerFruit = 0
		if applesCollected > 0 and fruitPoints > 0 then
			xpPerFruit = fruitPoints / applesCollected
		end
		local spawnInterval = 0.08
		if xpPerFruit > 0 and fillSpeed > 0 then
			spawnInterval = clamp(xpPerFruit / fillSpeed, 0.03, 0.16)
		end

		self.progressionAnimation.fruitTotal = applesCollected
		self.progressionAnimation.fruitRemaining = applesCollected
		self.progressionAnimation.fruitAnimations = {}
		self.progressionAnimation.fruitSpawnTimer = 0
		self.progressionAnimation.fruitSpawnInterval = spawnInterval
		self.progressionAnimation.fruitPalette = {
			Theme.appleColor,
			Theme.bananaColor,
			Theme.blueberryColor,
			Theme.goldenPearColor,
			Theme.dragonfruitColor,
		}
		self.progressionAnimation.fruitXpPer = xpPerFruit
		self.progressionAnimation.fruitPoints = fruitPoints

		if (self.progressionAnimation.xpForLevel or 0) > 0 then
			self.progressionAnimation.visualPercent = clamp((self.progressionAnimation.xpIntoLevel or 0) / self.progressionAnimation.xpForLevel, 0, 1)
		else
			self.progressionAnimation.visualPercent = 0
		end

		if type(self.progression.milestones) == "table" then
			for _, milestone in ipairs(self.progression.milestones) do
				self.progressionAnimation.pendingMilestones[#self.progressionAnimation.pendingMilestones + 1] = {
					threshold = milestone.threshold,
					triggered = false,
				}
			end
		end

		if type(self.progression.unlocks) == "table" then
			for _, unlock in ipairs(self.progression.unlocks) do
				local level = unlock.level
				self.progressionAnimation.levelUnlocks[level] = self.progressionAnimation.levelUnlocks[level] or {}
				table.insert(self.progressionAnimation.levelUnlocks[level], {
					name = unlock.name,
					description = unlock.description,
				})
			end
		end
	end

	self:updateLayoutMetrics()
	self:updateButtonLayout()

end

local function getLocalizedOrFallback(key, fallback)
	local value = Localization:get(key)
	if value == key then
		return fallback
	end
	return value
end

local function drawStatPill(x, y, width, height, label, value)
	UI.drawPanel(x, y, width, height, {
		radius = 18,
		shadowOffset = 0,
		fill = { Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], (Theme.panelColor[4] or 1) * 0.7 },
		borderColor = UI.colors.border or Theme.panelBorder,
		borderWidth = 2,
	})

	UI.drawLabel(label, x + 8, y + 12, width - 16, "center", {
		font = fontProgressSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	local displayFont = fontProgressValue
	if displayFont:getWidth(value) > width - 32 then
		displayFont = fontBadge
		if displayFont:getWidth(value) > width - 32 then
			displayFont = fontSmall
		end
	end

	local valueY = y + height / 2 - displayFont:getHeight() / 2 + 6
	UI.drawLabel(value, x + 8, valueY, width - 16, "center", {
		font = displayFont,
		color = UI.colors.text,
	})
end

local function drawCelebrationsList(anim, x, startY, width)
	local events = anim and anim.celebrations or {}
	if not events or #events == 0 then
		return startY
	end

	local y = startY
	local cardWidth = width - 32
	local now = love.timer.getTime()

	local celebrationHeight = getCelebrationEntryHeight()
	local celebrationSpacing = getCelebrationEntrySpacing()
	local outerRadius = (UI.scaled and UI.scaled(16, 12)) or 16
	local innerRadius = (UI.scaled and UI.scaled(12, 8)) or 12

	for index, event in ipairs(events) do
		local timer = math.max(0, event.timer or 0)
		local appear = math.min(1, timer / 0.35)
		local appearEase = easeOutBack(appear)
		local fadeAlpha = 1
		local duration = event.duration or 4.5
		if duration > 0 then
			local fadeStart = math.max(0, duration - 0.65)
			if timer > fadeStart then
				local fadeProgress = math.min(1, (timer - fadeStart) / 0.65)
				fadeAlpha = 1 - fadeProgress
			end
		end

		local alpha = math.max(0, fadeAlpha)

		if alpha > 0.01 then
			local cardX = x + 16
			local cardY = y
			local wobble = math.sin(now * 4.2 + index * 0.8) * 2 * alpha

			love.graphics.push()
			love.graphics.translate(cardX + cardWidth / 2, cardY + celebrationHeight / 2 + wobble)
			love.graphics.scale(0.92 + 0.08 * appearEase, 0.92 + 0.08 * appearEase)
			love.graphics.translate(-(cardX + cardWidth / 2), -(cardY + celebrationHeight / 2 + wobble))

			love.graphics.setColor(0, 0, 0, 0.35 * alpha)
			love.graphics.rectangle("fill", cardX + 5, cardY + 6, cardWidth, celebrationHeight, outerRadius, outerRadius)

			local accent = event.color or Theme.progressColor or { 1, 1, 1, 1 }
			love.graphics.setColor(accent[1], accent[2], accent[3], 0.22 * alpha)
			love.graphics.rectangle("fill", cardX, cardY, cardWidth, celebrationHeight, outerRadius, outerRadius)

			love.graphics.setColor(accent[1], accent[2], accent[3], 0.55 * alpha)
			love.graphics.setLineWidth(2)
			love.graphics.rectangle("line", cardX, cardY, cardWidth, celebrationHeight, outerRadius, outerRadius)

			local shimmer = 0.45 + 0.25 * math.sin(now * 6 + index)
			love.graphics.setColor(accent[1], accent[2], accent[3], shimmer * 0.18 * alpha)
			love.graphics.rectangle("line", cardX + 3, cardY + 3, cardWidth - 6, celebrationHeight - 6, innerRadius, innerRadius)

			UI.drawLabel(event.title or "", cardX + 18, cardY + 12, cardWidth - 36, "left", {
				font = fontProgressSmall,
				color = { UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], alpha },
			})

			if event.subtitle and event.subtitle ~= "" then
				UI.drawLabel(event.subtitle, cardX + 18, cardY + 32, cardWidth - 36, "left", {
					font = fontSmall,
					color = { UI.colors.mutedText[1], UI.colors.mutedText[2], UI.colors.mutedText[3], alpha },
				})
			end

			love.graphics.pop()
		end

		y = y + celebrationSpacing
	end

	love.graphics.setLineWidth(1)
	return y
end

local function drawXpSection(self, x, y, width)
	local anim = self.progressionAnimation
	if not anim then
		return
	end

	local baseHeight = self.baseXpSectionHeight or 220
	local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local celebrationSpacing = getCelebrationEntrySpacing()
	local targetHeight = baseHeight + celebrationCount * celebrationSpacing
	local height = math.max(160, self.xpSectionHeight or targetHeight, targetHeight)
	UI.drawPanel(x, y, width, height, {
		radius = 18,
		shadowOffset = 0,
		fill = { Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], (Theme.panelColor[4] or 1) * 0.65 },
		borderColor = UI.colors.border or Theme.panelBorder,
		borderWidth = 2,
	})

	local headerY = y + 18
	UI.drawLabel(getLocalizedOrFallback("gameover.meta_progress_title", "Experience"), x, headerY, width, "center", {
		font = fontProgressTitle,
		color = UI.colors.text,
	})

	local levelColor = Theme.progressColor or UI.colors.progress or UI.colors.text
	local flash = math.max(0, math.min(1, anim.levelFlash or 0))
	local levelText = Localization:get("gameover.meta_progress_level_label", { level = anim.displayedLevel or 1 })
	local levelY = headerY + fontProgressTitle:getHeight() + 12
	UI.drawLabel(levelText, x, levelY, width, "center", {
		font = fontProgressValue,
		color = { levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.78 + 0.2 * flash },
	})

	if flash > 0.01 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		local centerX = x + width / 2
		local centerY = levelY + fontProgressValue:getHeight() / 2
		love.graphics.setColor(levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.24 * flash)
		love.graphics.circle("fill", centerX, centerY, 48 + flash * 26, 48)
		love.graphics.setColor(1, 1, 1, 0.12 * flash)
		love.graphics.circle("line", centerX, centerY, 48 + flash * 18, 48)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	local gained = math.max(0, math.floor((anim.displayedGained or 0) + 0.5))
	local gainedText = Localization:get("gameover.meta_progress_gain_short", { points = gained })
	local gainedY = levelY + fontProgressValue:getHeight() + 6
	UI.drawLabel(gainedText, x, gainedY, width, "center", {
		font = fontProgressSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	local ringTop = gainedY + fontProgressSmall:getHeight() + 18
	local centerX = x + width / 2
	local maxRadius = math.max(48, math.min(74, (width / 2) - 24))
	local ringThickness = math.max(14, math.min(24, maxRadius * 0.42))
	local ringRadius = maxRadius - ringThickness * 0.25
	local innerRadius = math.max(32, ringRadius - ringThickness * 0.6)
	local outerRadius = ringRadius + ringThickness * 0.45
	local centerY = ringTop + ringRadius
	local percent = clamp(anim.visualPercent or 0, 0, 1)
	local pulse = clamp(anim.barPulse or 0, 0, 1)

	anim.barMetrics = anim.barMetrics or {}
	anim.barMetrics.style = "radial"
	anim.barMetrics.centerX = centerX
	anim.barMetrics.centerY = centerY
	anim.barMetrics.radius = ringRadius
	anim.barMetrics.innerRadius = innerRadius
	anim.barMetrics.outerRadius = outerRadius
	anim.barMetrics.thickness = ringThickness

	local panelColor = Theme.panelColor or { 0.18, 0.18, 0.22, 1 }
	local trackColor = withAlpha(darkenColor(panelColor, 0.2), 0.85)
	local ringColor = { levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.9 }

	love.graphics.setColor(trackColor)
	love.graphics.circle("fill", centerX, centerY, outerRadius)

	local startAngle = -math.pi / 2
	love.graphics.setColor(withAlpha(lightenColor(panelColor, 0.12), 0.88))
	love.graphics.setLineWidth(ringThickness)
	love.graphics.arc("line", "open", centerX, centerY, ringRadius, startAngle, startAngle + math.pi * 2, 96)

	if percent > 0 then
		local endAngle = startAngle + percent * math.pi * 2
		local scale = 1 + pulse * 0.04
		local widthMul = 1 + pulse * 0.45

		love.graphics.setColor(ringColor)
		love.graphics.setLineWidth(ringThickness * widthMul)
		love.graphics.arc("line", "open", centerX, centerY, ringRadius * scale, startAngle, endAngle, 96)

		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], 0.24 + 0.18 * flash)
		love.graphics.arc("line", "open", centerX, centerY, ringRadius * (scale + 0.08 + pulse * 0.06), startAngle, endAngle, 96)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	love.graphics.setColor(withAlpha(lightenColor(panelColor, 0.18), 0.94))
	love.graphics.circle("fill", centerX, centerY, innerRadius)

	drawFruitAnimations(anim)

	love.graphics.setColor(withAlpha(Theme.panelBorder or { 0.35, 0.3, 0.5, 1 }, 0.85))
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", centerX, centerY, innerRadius, 96)
	love.graphics.setLineWidth(1)

	if flash > 0.01 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], 0.26 * flash)
		love.graphics.circle("line", centerX, centerY, outerRadius + flash * 22, 96)
		love.graphics.setColor(1, 1, 1, 0.14 * flash)
		love.graphics.circle("fill", centerX, centerY, innerRadius + flash * 14, 96)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	love.graphics.setFont(fontProgressValue)
	love.graphics.setColor(Theme.textColor or UI.colors.text)
	local levelValue = tostring(anim.displayedLevel or 1)
	love.graphics.printf(levelValue, centerX - innerRadius, centerY - fontProgressValue:getHeight() / 2 - 4, innerRadius * 2, "center")

	local totalLabel = Localization:get("gameover.meta_progress_total_label", {
		total = math.floor((anim.displayedTotal or 0) + 0.5),
	})

	local remainingLabel
	if (anim.xpForLevel or 0) <= 0 then
		remainingLabel = Localization:get("gameover.meta_progress_max_level")
	else
		local remaining = math.max(0, math.ceil((anim.xpForLevel or 0) - (anim.xpIntoLevel or 0)))
		remainingLabel = Localization:get("gameover.meta_progress_next", { remaining = remaining })
	end

	local labelY = centerY + outerRadius + 18
	local breakdown = self.progression and self.progression.breakdown or {}
	local bonusXP = math.max(0, math.floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
	if bonusXP > 0 then
		local bonusText = Localization:get("gameover.meta_progress_bonus", { bonus = bonusXP })
		UI.drawLabel(bonusText, x, labelY, width, "center", {
			font = fontProgressSmall,
			color = UI.colors.highlight or UI.colors.text,
		})
		labelY = labelY + fontProgressSmall:getHeight() + 6
	end

	if self.dailyStreakMessage then
		UI.drawLabel(self.dailyStreakMessage, x, labelY, width, "center", {
			font = fontProgressSmall,
			color = self.dailyStreakColor or UI.colors.highlight or UI.colors.text,
		})
		labelY = labelY + fontProgressSmall:getHeight() + 6
	end

	UI.drawLabel(totalLabel, x, labelY, width, "center", {
		font = fontProgressSmall,
		color = UI.colors.text,
	})

	labelY = labelY + fontProgressSmall:getHeight() + 4
	UI.drawLabel(remainingLabel, x, labelY, width, "center", {
		font = fontProgressSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	local celebrationStart = labelY + fontProgressSmall:getHeight() + 16
	drawCelebrationsList(anim, x, celebrationStart, width)
end

local function drawScorePanel(self, x, y, width, height, sectionPadding, innerSpacing, smallSpacing)
	if (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	drawInsetPanel(x, y, width, height, { radius = 18 })

	local scoreLabel = getLocalizedOrFallback("gameover.score_label", "Score")
	local labelY = y + sectionPadding
	UI.drawLabel(scoreLabel, x + sectionPadding, labelY, width - sectionPadding * 2, "center", {
		font = fontProgressSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	local valueY = labelY + fontProgressSmall:getHeight() + innerSpacing
	local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
	UI.drawLabel(tostring(stats.score or 0), x, valueY, width, "center", {
		font = fontScore,
		color = { progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92 },
	})

	if self.isNewHighScore then
		local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
		local badgeY = valueY + fontScore:getHeight() + smallSpacing
		UI.drawLabel(Localization:get("gameover.high_score_badge"), x + sectionPadding, badgeY, width - sectionPadding * 2, "center", {
			font = fontBadge,
			color = { badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9 },
		})
	end
end

local function drawStatsPanel(self, x, y, width, height, sectionPadding, innerSpacing, layoutData)
	if (height or 0) <= 0 or (width or 0) <= 0 then
		return
	end

	drawInsetPanel(x, y, width, height, { radius = 18 })

	local statsHeader = getLocalizedOrFallback("gameover.stats_header", "Highlights")
	local statsY = y + sectionPadding
	UI.drawLabel(statsHeader, x + sectionPadding, statsY, width - sectionPadding * 2, "left", {
		font = fontProgressSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	statsY = statsY + fontProgressSmall:getHeight() + innerSpacing

	local bestLabel = getLocalizedOrFallback("gameover.stats_best_label", "Best")
	local applesLabel = getLocalizedOrFallback("gameover.stats_apples_label", "Apples")
	local statCards = {
		{ label = bestLabel, value = tostring(stats.highScore or 0) },
		{ label = applesLabel, value = tostring(stats.apples or 0) },
	}

	local statLayout = layoutData or calculateStatLayout(width, sectionPadding, #statCards)
	local availableWidth = (statLayout and statLayout.availableWidth) or (width - sectionPadding * 2)
	local statSpacing = (statLayout and statLayout.spacing) or getStatCardSpacing()
	local statCardHeight = getStatCardHeight()
	local cardIndex = 1
	local rows = math.max(1, (statLayout and statLayout.rows) or 1)
	local columns = math.max(1, (statLayout and statLayout.columns) or 1)

	for row = 1, rows do
		local itemsInRow = math.min(columns, #statCards - (row - 1) * columns)
		if itemsInRow <= 0 then
			break
		end

		local rowWidth = itemsInRow * (statLayout.cardWidth or 0) + math.max(0, itemsInRow - 1) * statSpacing
		local rowOffset = math.max(0, (availableWidth - rowWidth) / 2)
		local baseX = x + sectionPadding + rowOffset
		local rowY = statsY + (row - 1) * (statCardHeight + statSpacing)

		for col = 0, itemsInRow - 1 do
			local card = statCards[cardIndex]
			if not card then
				break
			end

			local cardX = baseX + col * ((statLayout.cardWidth or 0) + statSpacing)
			drawStatPill(cardX, rowY, statLayout.cardWidth or 0, statCardHeight, card.label, card.value)
			cardIndex = cardIndex + 1
		end
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

	drawInsetPanel(x, y, width, height, { radius = 18 })

	local achievementsLabel = getLocalizedOrFallback("gameover.achievements_header", "Achievements")
	local headerText = string.format("%s (%d)", achievementsLabel, #entries)
	local textX = x + sectionPadding
	local textWidth = layoutData.textWidth or (width - sectionPadding * 2)
	local entryY = y + sectionPadding

	UI.drawLabel(headerText, textX, entryY, textWidth, "left", {
		font = fontProgressSmall,
		color = UI.colors.text,
	})

	entryY = entryY + fontProgressSmall:getHeight() + innerSpacing

	for index, entry in ipairs(entries) do
		UI.drawLabel(entry.title or "", textX, entryY, textWidth, "left", {
			font = fontSmall,
			color = UI.colors.highlight or UI.colors.text,
		})
		entryY = entryY + fontSmall:getHeight()

		if entry.description and entry.description ~= "" then
			UI.drawLabel(entry.description, textX, entryY, textWidth, "left", {
				font = fontProgressSmall,
				color = UI.colors.mutedText or UI.colors.text,
			})
			entryY = entryY + (entry.descriptionLines or 0) * fontProgressSmall:getHeight()
		end

		if index < #entries then
			entryY = entryY + smallSpacing
		end
	end
end

local function drawCombinedPanel(self, contentWidth, contentX, padding)
	local panelHeight = self.summaryPanelHeight or 0
	local panelY = 120
	drawCenteredPanel(contentX, panelY, contentWidth, panelHeight, 20)

	local innerWidth = self.innerContentWidth or (contentWidth - padding * 2)
	local innerX = contentX + padding

	local sectionPadding = self.sectionPaddingValue or getSectionPadding()
	local sectionSpacing = self.sectionSpacingValue or getSectionSpacing()
	local innerSpacing = self.sectionInnerSpacingValue or getSectionInnerSpacing()
	local smallSpacing = self.sectionSmallSpacingValue or getSectionSmallSpacing()
	local headerSpacing = self.sectionHeaderSpacingValue or getSectionHeaderSpacing()

	local headerFont = UI.fonts.heading or fontSmall
	local titleY = panelY + padding
	UI.drawLabel(getLocalizedOrFallback("gameover.run_summary_title", "Run Summary"), contentX, titleY, contentWidth, "center", {
		font = headerFont,
		color = UI.colors.text,
	})

	local currentY = titleY + headerFont:getHeight() + headerSpacing

	local wrapLimit = self.wrapLimit or math.max(0, innerWidth - sectionPadding * 2)
	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local messagePanelHeight = self.messagePanelHeight or 0
	if messagePanelHeight > 0 then
		drawInsetPanel(innerX, currentY, innerWidth, messagePanelHeight)
		UI.drawLabel(messageText, innerX + sectionPadding, currentY + sectionPadding, wrapLimit, "center", {
			font = fontSmall,
			color = UI.colors.mutedText or UI.colors.text,
		})
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
			elseif entry.id == "stats" then
				drawStatsPanel(self, entryX, entryY, entryWidth, entryHeight, sectionPadding, innerSpacing, entry.layoutData or self.statLayout)
			elseif entry.id == "achievements" then
				drawAchievementsPanel(self, entryX, entryY, entryWidth, entryHeight, sectionPadding, innerSpacing, smallSpacing, entry.layoutData or self.achievementsLayout)
			elseif entry.id == "xp" then
				drawXpSection(self, entryX, entryY, entryWidth)
			end
		end

		currentY = currentY + (layout.columnsHeight or 0)
	end
end

function GameOver:draw()
	local sw, sh = Screen:get()
	local layoutChanged = self:updateLayoutMetrics()
	if layoutChanged then
		self:updateButtonLayout()
	end
	drawBackground(sw, sh)

	local margin = 24
	local fallbackMaxAllowed = math.max(40, sw - margin)
	local fallbackSafe = math.max(80, sw - margin * 2)
	fallbackSafe = math.min(fallbackSafe, fallbackMaxAllowed)
	local fallbackPreferred = math.min(sw * 0.72, 640)
	local fallbackMin = math.min(320, fallbackSafe)
	local computedWidth = math.max(fallbackMin, math.min(fallbackPreferred, fallbackSafe))
	local contentWidth = self.contentWidth or computedWidth
	local contentX = (sw - contentWidth) / 2
	local padding = self.contentPadding or 24

	local titleKey = self.isVictory and "gameover.victory_title" or "gameover.title"
	local fallbackTitle = self.isVictory and "Noodl's Grand Feast" or "Game Over"
	local titleText = self.customTitle or getLocalizedOrFallback(titleKey, fallbackTitle)

	UI.drawLabel(titleText, 0, 48, sw, "center", {
		font = fontTitle,
		color = UI.colors.text,
	})

	drawCombinedPanel(self, contentWidth, contentX, padding)

	for _, btn in buttonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	buttonList:draw()
end

function GameOver:update(dt)
	local anim = self.progressionAnimation
	if not anim then
		local layoutChanged = self:updateLayoutMetrics()
		if layoutChanged then
			self:updateButtonLayout()
		end
		return
	end

	local targetTotal = anim.targetTotal or anim.displayedTotal or 0
	local startTotal = 0
	if self.progression and self.progression.start then
		startTotal = self.progression.start.total or 0
	end

	local previousTotal = anim.displayedTotal or startTotal
	local fruitPoints = math.max(0, anim.fruitPoints or 0)
	local deliveredFruit = math.max(0, anim.fruitDelivered or 0)
	local pendingFruit = math.max(0, anim.pendingFruitXp or 0)
	local allowedTarget = targetTotal

	if fruitPoints > 0 and deliveredFruit < fruitPoints then
		local gatedTarget = startTotal + math.min(fruitPoints, deliveredFruit + pendingFruit)
		allowedTarget = math.min(allowedTarget, gatedTarget)
	end

	local newTotal = previousTotal
	if previousTotal < allowedTarget then
		local increment = math.min(anim.fillSpeed * dt, allowedTarget - previousTotal)
		newTotal = previousTotal + increment

		if fruitPoints > 0 and deliveredFruit < fruitPoints then
			local newDelivered = math.min(fruitPoints, deliveredFruit + increment)
			local used = newDelivered - deliveredFruit
			anim.fruitDelivered = newDelivered
			anim.pendingFruitXp = math.max(0, pendingFruit - used)
		end
	elseif previousTotal < targetTotal then
		newTotal = math.min(targetTotal, previousTotal)
	else
		newTotal = targetTotal
	end

	anim.displayedTotal = newTotal
	if newTotal >= targetTotal - 1e-6 then
		anim.displayedTotal = targetTotal
		anim.displayedGained = (self.progression and self.progression.gained) or 0
		anim.pendingFruitXp = 0
		anim.fruitDelivered = fruitPoints
	else
		anim.displayedGained = math.min((self.progression and self.progression.gained) or 0, newTotal - startTotal)
	end

	local previousLevel = anim.displayedLevel or 1
	local level, xpIntoLevel, xpForNext = MetaProgression:getProgressForTotal(anim.displayedTotal)
	if level > previousLevel then
		for levelReached = previousLevel + 1, level do
			anim.levelFlash = 0.9
			addCelebration(anim, {
				type = "level",
				title = Localization:get("gameover.meta_progress_level_up", { level = levelReached }),
				subtitle = Localization:get("gameover.meta_progress_level_up_subtitle"),
				color = Theme.progressColor or { 1, 1, 1, 1 },
				duration = 5.5,
			})
			Audio:playSound("goal_reached")

			local unlockList = anim.levelUnlocks[levelReached]
			if unlockList then
				for _, unlock in ipairs(unlockList) do
					addCelebration(anim, {
						type = "unlock",
						title = Localization:get("gameover.meta_progress_unlock_header", { name = unlock.name or "???" }),
						subtitle = unlock.description or "",
						color = Theme.achieveColor or { 1, 1, 1, 1 },
						duration = 6,
					})
				end
			end
		end
	end

	anim.displayedLevel = level
	anim.xpIntoLevel = xpIntoLevel
	anim.xpForLevel = xpForNext

	local targetPercent = 0
	if (anim.xpForLevel or 0) > 0 then
		targetPercent = clamp((anim.xpIntoLevel or 0) / anim.xpForLevel, 0, 1)
	end
	local easeSpeed = anim.fillEaseSpeed or 9
	if not anim.visualPercent then
		anim.visualPercent = targetPercent
	else
		anim.visualPercent = approachExp(anim.visualPercent, targetPercent, dt, easeSpeed)
	end

	if anim.levelFlash then
		anim.levelFlash = math.max(0, anim.levelFlash - dt)
	end

	if anim.pendingMilestones then
		for _, milestone in ipairs(anim.pendingMilestones) do
			if not milestone.triggered and (anim.displayedTotal or 0) >= (milestone.threshold or 0) then
				milestone.triggered = true
				addCelebration(anim, {
					type = "milestone",
					title = Localization:get("gameover.meta_progress_milestone_header"),
					subtitle = Localization:get("gameover.meta_progress_milestone", { threshold = milestone.threshold }),
					color = Theme.achieveColor or { 1, 1, 1, 1 },
					duration = 6.5,
				})
				Audio:playSound("achievement")
			end
		end
	end

	if anim.celebrations then
		for index = #anim.celebrations, 1, -1 do
			local event = anim.celebrations[index]
			event.timer = (event.timer or 0) + dt
			if event.timer >= (event.duration or 4.5) then
				table.remove(anim.celebrations, index)
			end
		end
	end

	updateFruitAnimations(anim, dt)

	if anim.barPulse then
		anim.barPulse = math.max(0, anim.barPulse - dt * 2.4)
	end

	local baseHeight = self.baseXpSectionHeight or 220
	local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local celebrationSpacing = getCelebrationEntrySpacing()
	local targetHeight = baseHeight + celebrationCount * celebrationSpacing
	self.xpSectionHeight = self.xpSectionHeight or baseHeight
	local smoothing = math.min(dt * 6, 1)
	self.xpSectionHeight = self.xpSectionHeight + (targetHeight - self.xpSectionHeight) * smoothing

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
