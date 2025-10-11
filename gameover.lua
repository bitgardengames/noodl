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

	local launchX = metrics.x + metrics.width * 0.5
	local launchY = metrics.y - math.max(metrics.height * 2.2, 72)

	local endX = metrics.x + metrics.width * 0.5
	local endY = metrics.y + metrics.height * 0.5
	local apexLift = math.max(metrics.height * 1.35, 64)
	local controlX = (launchX + endX) / 2
	local controlY = math.min(launchY, endY) - apexLift

	local fruit = {
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

	if anim.barMetrics then
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
					anim.barSplashes = anim.barSplashes or {}
					anim.barSplashes[#anim.barSplashes + 1] = {
						x = fruit.endX,
						color = fruit.color,
						timer = 0,
						duration = 0.35,
					}
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

	local splashes = anim.barSplashes or {}
	for index = #splashes, 1, -1 do
		local splash = splashes[index]
		splash.timer = (splash.timer or 0) + dt
		if splash.timer >= (splash.duration or 0.35) then
			table.remove(splashes, index)
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
	local wrapLimit = math.max(0, contentWidth - padding * 2)

	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
	local messageLines = math.max(1, #wrappedMessage)
	local messageHeight = messageLines * fontSmall:getHeight()

	local headerFont = UI.fonts.heading or fontSmall
	local headerHeight = headerFont:getHeight()
	local scoreHeight = fontScore:getHeight()
	local badgeHeight = self.isNewHighScore and (fontBadge:getHeight() + 18) or 0
	local achievementsHeight = (#(self.achievementsEarned or {}) > 0) and (fontSmall:getHeight() + 12) or 0

	local statCards = 3
	local statLayout = calculateStatLayout(contentWidth, padding, statCards)

	local xpHeight = 0
	if self.progressionAnimation then
		local celebrations = (self.progressionAnimation.celebrations and #self.progressionAnimation.celebrations) or 0
		local baseHeight = self.baseXpSectionHeight or self.xpSectionHeight or 0
		local celebrationSpacing = getCelebrationEntrySpacing()
		local targetHeight = baseHeight + celebrations * celebrationSpacing
		local xpContentHeight = math.max(160, baseHeight, targetHeight)
		xpHeight = xpContentHeight + 12
	end

	local summaryPanelHeight = padding * 2
		+ headerHeight + 12
		+ messageHeight + 28
		+ scoreHeight + 16
		+ badgeHeight
		+ statLayout.height + 12
		+ achievementsHeight
		+ xpHeight

	summaryPanelHeight = math.floor(summaryPanelHeight + 0.5)
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

	if not self.statLayout
		or self.statLayout.columns ~= statLayout.columns
		or self.statLayout.rows ~= statLayout.rows
		or math.abs((self.statLayout.cardWidth or 0) - (statLayout.cardWidth or 0)) >= 1
	then
		layoutChanged = true
	end

	self.summaryPanelHeight = summaryPanelHeight
	self.contentWidth = contentWidth
	self.contentPadding = padding
	self.wrapLimit = wrapLimit
	self.messageLines = messageLines
	self.statLayout = statLayout

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
                        barSplashes = {},
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

	local barY = gainedY + fontProgressSmall:getHeight() + 16
	local barHeight = 26
        local barWidth = width - 48
        local barX = x + 24
        anim.barMetrics = anim.barMetrics or {}
        anim.barMetrics.x = barX
        anim.barMetrics.y = barY
        anim.barMetrics.width = barWidth
        anim.barMetrics.height = barHeight
        local percent = math.min(1, math.max(0, anim.visualPercent or 0))

        local shadowColor = UI.colors.shadow or { 0, 0, 0, 0.4 }
        local trackColor = { shadowColor[1], shadowColor[2], shadowColor[3], 0.35 }
        love.graphics.setColor(trackColor)
	love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 12, 12)

	local progressColor = { levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.92 }
	local fillWidth = barWidth * percent
	local pulse = clamp(anim.barPulse or 0, 0, 1)
	local pulseExpand = pulse * 6

	if fillWidth > 0 then
		local prevScissor = { love.graphics.getScissor() }
		if pulse > 0 then
			love.graphics.setScissor(barX, barY - pulseExpand / 2, fillWidth, barHeight + pulseExpand)
		end
		love.graphics.setColor(progressColor)
		love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 12, 12)
		if pulse > 0 then
			love.graphics.setScissor(unpack(prevScissor))
		end
	end

	if percent > 0 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(progressColor[1], progressColor[2], progressColor[3], 0.22 + 0.18 * flash)
		love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 12, 12)

		if pulse > 0 then
			local prevScissor = { love.graphics.getScissor() }
			love.graphics.setScissor(barX, barY, fillWidth, barHeight)
			love.graphics.setColor(1, 1, 1, 0.16 * pulse)
			love.graphics.rectangle("fill", barX - pulseExpand / 2, barY - pulseExpand / 2, fillWidth + pulseExpand, barHeight + pulseExpand, 10, 10)
			love.graphics.setScissor(unpack(prevScissor))
		end

		local sweepWidth = 28
		local sweepPos = (love.timer.getTime() * 80) % (barWidth + sweepWidth) - sweepWidth
		local prevScissor = { love.graphics.getScissor() }
		love.graphics.setScissor(barX, barY, fillWidth, barHeight)
		love.graphics.setColor(1, 1, 1, 0.22 * (0.5 + 0.5 * math.sin(love.timer.getTime() * 4 + percent * math.pi)))
		love.graphics.rectangle("fill", barX + sweepPos, barY - 4, sweepWidth, barHeight + 8, 10, 10)
		love.graphics.setScissor(unpack(prevScissor))
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	local splashes = anim.barSplashes or {}
	if anim.barMetrics and splashes and #splashes > 0 then
		local prevScissor = { love.graphics.getScissor() }
		love.graphics.setScissor(barX, barY, barWidth, barHeight)
		for _, splash in ipairs(splashes) do
			local splashProgress = clamp((splash.timer or 0) / (splash.duration or 0.35), 0, 1)
			local splashFade = clamp(1 - splashProgress, 0, 1)
			if splashFade > 0.01 then
				local splashColor = splash.color or progressColor
				local splashHighlight = lightenColor(splashColor, 0.45)
				local centerX = clamp(splash.x or (barX + fillWidth), barX + 8, barX + barWidth - 8)
				local centerY = barY + barHeight / 2
				local radiusX = (barHeight / 2) * (1.05 + splashProgress * 0.9)
				local radiusY = (barHeight / 2) * (0.42 + splashProgress * 0.4)

				love.graphics.setColor(splashColor[1], splashColor[2], splashColor[3], 0.32 * splashFade)
				love.graphics.ellipse("fill", centerX, centerY, radiusX, radiusY, 32)

				love.graphics.setColor(splashHighlight[1], splashHighlight[2], splashHighlight[3], 0.55 * splashFade)
				love.graphics.setLineWidth(2)
				love.graphics.ellipse("line", centerX, centerY, radiusX, radiusY, 32)
			end
		end
		love.graphics.setScissor(unpack(prevScissor))
	end

	local outlineSource = UI.colors.highlight or UI.colors.border or { 1, 1, 1, 0.6 }
	love.graphics.setColor(outlineSource[1], outlineSource[2], outlineSource[3], 0.6)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 12, 12)
	love.graphics.setLineWidth(1)

	drawFruitAnimations(anim)

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

	local labelY = barY + barHeight + 14
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

local function drawCombinedPanel(self, contentWidth, contentX, padding)
	local panelHeight = self.summaryPanelHeight or 0
	local panelY = 120
	drawCenteredPanel(contentX, panelY, contentWidth, panelHeight, 20)

	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local wrapLimit = self.wrapLimit or (contentWidth - padding * 2)
	local lineHeight = fontSmall:getHeight()
	local messageLines = math.max(1, self.messageLines or 1)
	local headerFont = UI.fonts.heading or fontSmall

	local textY = panelY + padding
	UI.drawLabel(getLocalizedOrFallback("gameover.run_summary_title", "Run Summary"), contentX, textY, contentWidth, "center", {
		font = headerFont,
		color = UI.colors.text,
	})

	textY = textY + headerFont:getHeight() + 12
	UI.drawLabel(messageText, contentX + padding, textY, wrapLimit, "center", {
		font = fontSmall,
		color = UI.colors.mutedText or UI.colors.text,
	})

	textY = textY + messageLines * lineHeight + 28
	local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
	UI.drawLabel(tostring(stats.score or 0), contentX, textY, contentWidth, "center", {
		font = fontScore,
		color = { progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92 },
	})

	textY = textY + fontScore:getHeight() + 16
	if self.isNewHighScore then
		local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
		UI.drawLabel(Localization:get("gameover.high_score_badge"), contentX + padding, textY, contentWidth - padding * 2, "center", {
			font = fontBadge,
			color = { badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9 },
		})
		textY = textY + fontBadge:getHeight() + 18
	end

	local cardY = textY
	local bestLabel = getLocalizedOrFallback("gameover.stats_best_label", "Best")
	local applesLabel = getLocalizedOrFallback("gameover.stats_apples_label", "Apples")
	local totalLabel = getLocalizedOrFallback("gameover.stats_total_label", "Lifetime Apples")
	local statLayout = self.statLayout or calculateStatLayout(contentWidth, padding, 3)
	local availableWidth = statLayout.availableWidth or (contentWidth - padding * 2)
	local cardIndex = 1
	local statCards = {
		{ label = bestLabel, value = tostring(stats.highScore or 0) },
		{ label = applesLabel, value = tostring(stats.apples or 0) },
		{ label = totalLabel, value = tostring(stats.totalApples or 0) },
	}

	local statSpacing = statLayout.spacing or getStatCardSpacing()
	local statCardHeight = getStatCardHeight()

	for row = 1, math.max(1, statLayout.rows or 1) do
		local itemsInRow = math.min(statLayout.columns or 1, #statCards - (row - 1) * (statLayout.columns or 1))
		if itemsInRow <= 0 then
			break
		end

		local rowWidth = itemsInRow * (statLayout.cardWidth or 0) + math.max(0, itemsInRow - 1) * statSpacing
		local rowOffset = math.max(0, (availableWidth - rowWidth) / 2)
		local baseX = contentX + padding + rowOffset
		local rowY = cardY + (row - 1) * (statCardHeight + statSpacing)

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

	textY = textY + (statLayout.height or statCardHeight) + 12

	local achievementsList = self.achievementsEarned or {}
	if #achievementsList > 0 then
		local achievementsLabel = getLocalizedOrFallback("gameover.achievements_header", "Achievements")
		local achievementsText = string.format("%s: %d", achievementsLabel, #achievementsList)
		UI.drawLabel(achievementsText, contentX + padding, textY, wrapLimit, "center", {
			font = fontSmall,
			color = UI.colors.mutedText or UI.colors.text,
		})
		textY = textY + lineHeight + 12
	end

	if self.progressionAnimation then
		drawXpSection(self, contentX + padding, textY, contentWidth - padding * 2)
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
