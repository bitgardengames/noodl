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
local Upgrades = require("upgrades")
local Shop = require("shop")
local Timer = require("timer")
local MathUtil = require("mathutil")

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

local ANALOG_DEADZONE = 0.3
local XP_RING_SIZE_BOOST = 16
local XP_RING_VERTICAL_OFFSET = -40
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


local function formatXpValue(value)
	local number = tonumber(value)
	if not number then
		if value == nil then
			return "0"
		end
		return tostring(value)
	end

	local sign = ""
	if number < 0 then
		sign = "-"
		number = -number
	end

	local integer = floor(number + 0.5)
	local digits = tostring(integer)
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
	local formatted = reversed:reverse():gsub("^,", "")

	return sign .. formatted
end

local function measureXpPanelHeight(self, width, celebrationCount)
	if not self or not self.progressionAnimation then
		return 0
	end

	width = max(0, width or 0)
	if width <= 0 then
		return 0
	end

	local levelHeight = fontProgressValue and fontProgressValue:getHeight() or 0
	local smallHeight = fontProgressSmall and fontProgressSmall:getHeight() or 0
	local labelHeight = (fontProgressLabel and fontProgressLabel:getHeight()) or smallHeight

	local height = 18
	height = height + 16 + levelHeight
	height = height + 18

	local baseMaxRadius = max(52, min(84, (width / 2) - 18))
	local scaledMaxRadius = baseMaxRadius * 1.08
	local ringThickness = max(16, min(26, scaledMaxRadius * 0.42))
	local baseRingRadius = max(32, scaledMaxRadius - ringThickness * 0.24)
	local ringRadius = baseRingRadius + (XP_RING_SIZE_BOOST or 0)
	local outerRadius = ringRadius + ringThickness * 0.4

	height = height + ringRadius + outerRadius + (XP_RING_VERTICAL_OFFSET or 0)
	height = height + 18

	local breakdown = (self.progression and self.progression.breakdown) or {}
	local bonusXP = max(0, floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
	if bonusXP > 0 then
		height = height + smallHeight + 6
	end

	if self.dailyStreakMessage then
		height = height + smallHeight + 6
	end

	height = height + labelHeight
	height = height + 4
	height = height + labelHeight
	height = height + 16

	local count = max(0, celebrationCount or 0)
	if count > 0 then
		height = height + count * getCelebrationEntrySpacing()
	end

	return max(160, height)
end

local BACKGROUND_EFFECT_TYPE = "afterglowPulse"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function copyColor(color)
	if type(color) ~= "table" then
		return {1, 1, 1, 1}
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

local function desaturateColor(color, amount)
	amount = max(0, min(1, amount or 0.5))
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] == nil and 1 or color[4]
	local grey = (r * 0.299) + (g * 0.587) + (b * 0.114)
	return {
		r + (grey - r) * amount,
		g + (grey - g) * amount,
		b + (grey - b) * amount,
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
		GameOver.xpCoreColor = nil
		return
	end

	local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
	local baseColor = copyColor(Theme.bgColor or {0.12, 0.12, 0.14, 1})
	local accent = copyColor(Theme.warningColor or {0.92, 0.55, 0.4, 1})
	local pulse = copyColor(Theme.progressColor or {0.55, 0.75, 0.55, 1})
	local vignette
	local coreColor

	if GameOver.isVictory then
		effect.backdropIntensity = min(0.9, (defaultBackdrop or 0.72) + 0.08)

		accent = lightenColor(copyColor(Theme.goldenPearColor or Theme.progressColor or accent), 0.32)
		accent[4] = 1

		pulse = lightenColor(copyColor(Theme.progressColor or pulse), 0.4)
		pulse[4] = 1

		baseColor = darkenColor(baseColor, 0.08)
		baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

		coreColor = lightenColor(copyColor(Theme.goldenPearColor or Theme.progressColor or pulse), 0.26)
		coreColor = desaturateColor(coreColor, 0.22)
		coreColor[4] = 0.58

		local vignetteColor = lightenColor(copyColor(Theme.goldenPearColor or Theme.accentTextColor or pulse), 0.2)
		vignetteColor = desaturateColor(vignetteColor, 0.4)
		vignette = {
			color = withAlpha(vignetteColor, 0.22),
			alpha = 0.22,
			steps = 4,
			thickness = nil,
		}
	else
		effect.backdropIntensity = max(0.48, (defaultBackdrop or effect.backdropIntensity or 0.62) * 0.92)

		local coolAccent = Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
		accent = lightenColor(copyColor(coolAccent), 0.18)
		accent[4] = 1

		pulse = lightenColor(copyColor(Theme.panelBorder or pulse), 0.26)
		pulse[4] = 1

		baseColor = darkenColor(baseColor, 0.22)
		baseColor[4] = Theme.bgColor and Theme.bgColor[4] or 1

		coreColor = lightenColor(copyColor(coolAccent), 0.14)
		coreColor = desaturateColor(coreColor, 0.38)
		coreColor[4] = 0.52

		local vignetteColor = lightenColor(copyColor(coolAccent), 0.04)
		vignetteColor = desaturateColor(vignetteColor, 0.45)
		vignette = {
			color = withAlpha(vignetteColor, 0.28),
			alpha = 0.28,
			steps = 3,
			thickness = nil,
		}
	end

	Shaders.configure(effect, {
		bgColor = baseColor,
		accentColor = accent,
		pulseColor = pulse,
	})

	effect.vignetteOverlay = vignette
	GameOver.xpCoreColor = darkenColor(coreColor, 0.16) or copyColor(pulse)
	backgroundEffect = effect
end

local function easeOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	local progress = t - 1
	return 1 + c3 * (progress * progress * progress) + c1 * (progress * progress)
end

local clamp = MathUtil.clamp

local function easeOutQuad(t)
	local inv = 1 - t
	return 1 - inv * inv
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
	local palette = anim.fruitPalette or {Theme.appleColor}
	local color = copyColor(palette[love.math.random(#palette)] or Theme.appleColor)
	local streakColor = anim.streakColor

	if streakColor and love.math.random() < 0.35 then
		color = copyColor(streakColor)
	end

	local sparkleChance = 0
	if (anim.bonusXP or 0) > 0 then
		sparkleChance = sparkleChance + 0.2
	end
	if streakColor then
		sparkleChance = sparkleChance + 0.15
	end

	local sparkleColor
	if sparkleChance > 0 and love.math.random() < sparkleChance then
		color = lightenColor(color, 0.28)
		color[4] = (color[4] or 1)
		local tintSource = streakColor or color
		sparkleColor = withAlpha(lightenColor(copyColor(tintSource), 0.45), 0.9)
	end

	local fruit
	if metrics.style == "radial" then
		local centerX = metrics.centerX or 0
		local centerY = metrics.centerY or 0
		local radius = metrics.outerRadius or metrics.radius or 56
		local launchOffsetX = randomRange(-radius * 0.6, radius * 0.6)
		local launchLift = max(radius * 0.8, 54)
		local launchX = centerX + launchOffsetX
		local launchY = centerY - radius - launchLift
		local controlX = (launchX + centerX) / 2 + randomRange(-radius * 0.25, radius * 0.25)
		local controlY = min(launchY, centerY) - max(radius * 0.75, 48)

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
			wobbleSeed = love.math.random() * pi * 2,
			wobbleSpeed = randomRange(4.5, 6.5),
			color = color,
			splashAngle = clamp(anim.visualPercent or 0, 0, 1),
			sparkle = sparkleColor ~= nil,
			sparkleColor = sparkleColor,
			sparkleSpin = randomRange(2.4, 3.4),
			sparkleOffset = love.math.random() * pi * 2,
		}
	else
		local launchX = metrics.x + metrics.width * 0.5
		local launchY = metrics.y - max(metrics.height * 2.2, 72)

		local endX = metrics.x + metrics.width * 0.5
		local endY = metrics.y + metrics.height * 0.5
		local apexLift = max(metrics.height * 1.35, 64)
		local controlX = (launchX + endX) / 2
		local controlY = min(launchY, endY) - apexLift

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
			wobbleSeed = love.math.random() * pi * 2,
			wobbleSpeed = randomRange(4.5, 6.5),
			color = color,
			sparkle = sparkleColor ~= nil,
			sparkleColor = sparkleColor,
			sparkleSpin = randomRange(2.6, 3.8),
			sparkleOffset = love.math.random() * pi * 2,
		}
	end

	anim.fruitAnimations = anim.fruitAnimations or {}
	insert(anim.fruitAnimations, fruit)
	anim.fruitRemaining = max(0, (anim.fruitRemaining or 0) - 1)

	return true
end

local function updateFruitAnimations(anim, dt)
	if not anim or (anim.fruitTotal or 0) <= 0 then
		return
	end

	anim.fruitSpawnTimer = (anim.fruitSpawnTimer or 0) + dt

	local function computeInterval()
		local baseInterval = anim.fruitSpawnInterval or 0.08
		local cadence = 1

		if (anim.bonusXP or 0) > 0 then
			local ratio = min(1, (anim.bonusXP or 0) / max(1, anim.fruitTotal or 1))
			cadence = cadence * (0.92 - 0.18 * ratio)
		end

		if anim.streakColor then
			local delivered = max(0, anim.fruitDelivered or 0)
			local remaining = max(0, anim.fruitRemaining or 0)
			local wave = sin((delivered + remaining) * 0.32)
			cadence = cadence * (0.95 - 0.08 * wave)
		end

		return max(0.03, baseInterval * cadence)
	end

	local interval = computeInterval()

	local metrics = anim.barMetrics

	if metrics then
		while (anim.fruitRemaining or 0) > 0 and anim.fruitSpawnTimer >= interval do
			if not spawnFruitAnimation(anim) then
				break
			end
			anim.fruitSpawnTimer = anim.fruitSpawnTimer - interval
			interval = computeInterval()
		end
	end

	local active = anim.fruitAnimations or {}
	for index = #active, 1, -1 do
		local fruit = active[index]
		fruit.timer = (fruit.timer or 0) + dt
		local duration = fruit.duration or 0.6
		if duration <= 0 then
			remove(active, index)
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
						local remaining = max(0, (anim.fruitPoints or 0) - delivered - pending)
						local grant = min(remaining, xpPer)
						anim.pendingFruitXp = pending + grant
					end

					anim.barPulse = min(1.5, (anim.barPulse or 0) + 0.45)
				end

				fruit.landingTimer = (fruit.landingTimer or 0) + dt
				fruit.splashTimer = (fruit.splashTimer or 0) + dt
				fruit.fade = (fruit.fade or 0) + dt

				if fruit.fade >= 0.35 then
					remove(active, index)
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

		local wobble = sin((fruit.wobbleSeed or 0) + (fruit.wobbleSpeed or 5.2) * eased)
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

		if fruit.sparkle and fadeMul > 0 then
			local sparkleColor = fruit.sparkleColor or {1, 1, 1, 0.9}
			local shimmer = sin((fruit.timer or 0) * (fruit.sparkleSpin or 3.1) + (fruit.sparkleOffset or 0)) * 0.5 + 0.5
			local sparkleAlpha = (sparkleColor[4] or 1) * fadeMul * (0.6 + 0.4 * shimmer)
			if sparkleAlpha > 0.01 then
				local prevMode, prevAlphaMode = love.graphics.getBlendMode()
				love.graphics.setBlendMode("add", "alphamultiply")
				love.graphics.setColor(sparkleColor[1] or 1, sparkleColor[2] or 1, sparkleColor[3] or 1, sparkleAlpha)

				local rayCount = 4
				local rayLength = radius * (1.2 + shimmer * 0.4)
				love.graphics.setLineWidth(1.3)
				for ray = 0, rayCount - 1 do
					local angle = (ray / rayCount) * pi * 2 + (fruit.sparkleOffset or 0)
					local dx = math.cos(angle) * rayLength
					local dy = sin(angle) * rayLength
					love.graphics.line(pathX, pathY + wobble * 2, pathX + dx, pathY + wobble * 2 + dy)
				end
				love.graphics.setLineWidth(1)
				love.graphics.circle("fill", pathX, pathY + wobble * 2, radius * 0.35 * (0.8 + 0.4 * shimmer), 18)
				love.graphics.setBlendMode(prevMode, prevAlphaMode)
				love.graphics.setColor(1, 1, 1, 1)
			end
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
	{id = "goPlay", textKey = "gameover.play_again", action = "game"},
	{id = "goMenu", textKey = "gameover.quit_to_menu", action = "menu"},
}

local function calculateAchievementsLayout(achievements, panelWidth, sectionPadding, innerSpacing, smallSpacing)
	local list = achievements or {}
	if not list or #list == 0 or (panelWidth or 0) <= 0 then
		return nil
	end

	local headerHeight = fontProgressSmall:getHeight()
	local headerWidth = max(0, panelWidth - sectionPadding * 2)
	local iconSize = max(12, min(22, sectionPadding * 0.95))
	local iconSpacing = max(6, floor((innerSpacing or 8) * 0.9))
	local textOffset = iconSize + iconSpacing
	local textWidth = max(0, headerWidth - textOffset)
	local totalHeight = headerHeight
	local entries = {}

	local badgeBase = Theme.achieveColor or Theme.progressColor or Theme.accentTextColor or {0.8, 0.45, 0.65, 1}

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

		local badgeColor = lightenColor(copyColor(badgeBase), min(0.4, 0.12 * (index - 1)))
		badgeColor[4] = 1

		entries[#entries + 1] = {
			title = achievement.title or "",
			description = description,
			descriptionLines = descriptionLines,
			badgeColor = badgeColor,
		}

		if index < #list then
			totalHeight = totalHeight + smallSpacing
		end
	end

	local panelHeight = sectionPadding * 2 + totalHeight
	panelHeight = floor(panelHeight + 0.5)

	return {
		entries = entries,
		height = panelHeight,
		headerHeight = headerHeight,
		headerWidth = headerWidth,
		textWidth = textWidth,
		textOffset = textOffset,
		iconSize = iconSize,
		iconSpacing = iconSpacing,
	}
end

local function defaultButtonLayout(sw, sh, defs, startY)
	local list = {}
	local buttonWidth, buttonHeight, buttonSpacing = getButtonMetrics()
	if #defs == 2 then
		local totalWidth = buttonWidth * 2 + buttonSpacing
		local startX = (sw - totalWidth) / 2
		for i, def in ipairs(defs) do
			list[#list + 1] = {
				id = def.id,
				textKey = def.textKey,
				text = def.text,
				action = def.action,
				x = startX + (i - 1) * (buttonWidth + buttonSpacing),
				y = startY,
				w = buttonWidth,
				h = buttonHeight,
			}
		end
		return list
	end

	local centerX = (sw - buttonWidth) / 2

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

local function drawCenteredPanel()
	-- Background rectangles have been removed from the game over screen,
	-- so this helper now intentionally draws nothing.
	love.graphics.setColor(1, 1, 1, 1)
end

local function drawInsetPanel()
	-- Intentionally left blank; inset rectangle visuals have been removed.
	love.graphics.setColor(1, 1, 1, 1)
end

local function drawSummaryPanelBackground()
	-- The summary panels no longer use rectangular backdrops.
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function handleButtonAction(_, action)
	return action
end

function GameOver:updateLayoutMetrics()
	if not fontSmall or not fontScore or not fontMessage then
		return false
	end

	local sw = select(1, Screen:get())
	local padding = 24
	local margin = 24
	local maxAllowed = max(40, sw - margin)
	local safeMaxWidth = max(80, sw - margin * 2)
	safeMaxWidth = min(safeMaxWidth, maxAllowed)
	local preferredWidth = min(sw * 0.72, 640)
	local minWidth = min(320, safeMaxWidth)
	local contentWidth = max(minWidth, min(preferredWidth, safeMaxWidth))
	local innerWidth = contentWidth - padding * 2

	local sectionPadding = getSectionPadding()
	local sectionSpacing = getSectionSpacing()
	local innerSpacing = getSectionInnerSpacing()
	local smallSpacing = getSectionSmallSpacing()
	local headerSpacing = getSectionHeaderSpacing()

	local wrapLimit = max(0, innerWidth - sectionPadding * 2)
	local alignedPanelWidth = wrapLimit

	local messageText = self.deathMessage or Localization:get("gameover.default_message")
	local _, wrappedMessage = fontMessage:getWrap(messageText, wrapLimit)
	local messageLines = max(1, #wrappedMessage)
	local messageHeight = messageLines * fontMessage:getHeight()
	local messagePanelHeight = floor(messageHeight + sectionPadding * 2 + 0.5)

	local scoreLabelFont = fontProgressLabel or fontProgressSmall
	local scoreHeaderHeight = (scoreLabelFont and scoreLabelFont:getHeight()) or 0
	local scoreNumberHeight = (fontScoreValue or fontScore):getHeight()
	local scorePanelHeight = sectionPadding * 2 + scoreHeaderHeight + innerSpacing + scoreNumberHeight
	scorePanelHeight = floor(scorePanelHeight + 0.5)
	local achievementsList = self.achievementsEarned or {}

	local xpPanelHeight = 0
	local xpLayout = nil
	if self.progressionAnimation then
		local availableWidth = max(0, innerWidth - sectionPadding * 2)
		if availableWidth > 0 then
			local xpWidth = floor(availableWidth + 0.5)
			local celebrations = (self.progressionAnimation.celebrations and #self.progressionAnimation.celebrations) or 0
			local baseHeight = measureXpPanelHeight(self, xpWidth, 0)
			local targetHeight = measureXpPanelHeight(self, xpWidth, celebrations)
			local contentX = (sw - contentWidth) / 2
			local primaryX = contentX + padding + sectionPadding
			local centerOffset = 0
			if xpWidth > 0 then
				local desiredCenter = sw / 2
				local currentCenter = primaryX + xpWidth / 2
				centerOffset = floor(desiredCenter - currentCenter + 0.5)
			end

			xpLayout = {
				width = xpWidth,
				offset = centerOffset,
			}

			self.baseXpSectionHeight = baseHeight
			if not self.xpSectionHeight then
				self.xpSectionHeight = baseHeight
			else
				self.xpSectionHeight = max(self.xpSectionHeight, baseHeight)
			end

			local animatedHeight = self.xpSectionHeight or targetHeight
			xpPanelHeight = floor(max(targetHeight, animatedHeight) + 0.5)
		end
	end

	local minColumnWidth = max(getStatCardMinWidth() + sectionPadding * 2, 260)
	local columnSpacing = sectionSpacing

	local function buildLayout(columnCount)
		columnCount = max(1, columnCount or 1)

		local availableWidth = max(0, innerWidth - sectionPadding * 2)
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
			sections[#sections + 1] = {id = "score", height = scorePanelHeight}
			sectionInfo.score = {height = scorePanelHeight}
		end

		local achievementsLayout = calculateAchievementsLayout(achievementsList, width, sectionPadding, innerSpacing, smallSpacing)
		if achievementsLayout and achievementsLayout.height > 0 then
			sections[#sections + 1] = {
				id = "achievements",
				height = achievementsLayout.height,
				layoutData = achievementsLayout,
			}
			sectionInfo.achievements = {height = achievementsLayout.height, layout = achievementsLayout}
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
			if section.id == "score" and columnCount > 1 then
				local startY = 0
				for i = 1, columnCount do
					if columnHeights[i] > startY then
						startY = columnHeights[i]
					end
				end

				entries[#entries + 1] = {
					id = section.id,
					column = 1,
					x = 0,
					y = startY,
					width = availableWidth,
					height = section.height,
					layoutData = section.layoutData,
				}

				local newHeight = startY + section.height + sectionSpacing
				for i = 1, columnCount do
					columnHeights[i] = newHeight
				end
			else
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

	local layoutOptions = {buildLayout(2), buildLayout(1)}
	local bestLayout = nil
	local baseHeight = padding * 2 + messagePanelHeight
	local hasXpSection = xpPanelHeight > 0
	for _, option in ipairs(layoutOptions) do
		if option then
			local entryCount = #(option.entries or {})
			local totalHeight = baseHeight
			if entryCount > 0 then
				totalHeight = totalHeight + sectionSpacing
				if (option.columnsHeight or 0) > 0 then
					totalHeight = totalHeight + option.columnsHeight
				end
			end
			if hasXpSection then
				totalHeight = totalHeight + sectionSpacing + xpPanelHeight
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
			totalHeight = (function()
				local total = baseHeight
				if hasXpSection then
					total = total + sectionSpacing + xpPanelHeight
				end
				return total
			end)(),
		}
	end

	local summaryPanelHeight = floor((bestLayout.totalHeight or baseHeight) + 0.5)
	contentWidth = floor(contentWidth + 0.5)
	wrapLimit = floor(wrapLimit + 0.5)

	local layoutChanged = false
	if not self.summaryPanelHeight or abs(self.summaryPanelHeight - summaryPanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.contentWidth or abs(self.contentWidth - contentWidth) >= 1 then
		layoutChanged = true
	end
	if not self.wrapLimit or abs(self.wrapLimit - wrapLimit) >= 1 then
		layoutChanged = true
	end

	local previousLayout = self.summarySectionLayout or {}
	local previousEntries = previousLayout.entries or {}
	local newEntries = bestLayout.entries or {}
	if (previousLayout.columnCount or 0) ~= (bestLayout.columnCount or 0)
	or #previousEntries ~= #newEntries
	or abs((previousLayout.columnsHeight or 0) - (bestLayout.columnsHeight or 0)) >= 1 then
		layoutChanged = true
	else
		for index, entry in ipairs(newEntries) do
			local prev = previousEntries[index]
			if not prev
			or prev.id ~= entry.id
			or prev.column ~= entry.column
			or abs((prev.x or 0) - (entry.x or 0)) >= 1
			or abs((prev.y or 0) - (entry.y or 0)) >= 1
			or abs((prev.width or 0) - (entry.width or 0)) >= 1 then
				layoutChanged = true
				break
			end
		end
	end

	local statsInfo = bestLayout.sectionInfo.stats or {}
	local achievementsInfo = bestLayout.sectionInfo.achievements or {}

	if not self.messagePanelHeight or abs(self.messagePanelHeight - messagePanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.scorePanelHeight or abs(self.scorePanelHeight - scorePanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.statPanelHeight or abs(self.statPanelHeight - (statsInfo.height or 0)) >= 1 then
		layoutChanged = true
	end
	if not self.achievementsPanelHeight or abs(self.achievementsPanelHeight - (achievementsInfo.height or 0)) >= 1 then
		layoutChanged = true
	end
	if not self.xpPanelHeight or abs(self.xpPanelHeight - xpPanelHeight) >= 1 then
		layoutChanged = true
	end
	if not self.primaryPanelWidth or abs(self.primaryPanelWidth - alignedPanelWidth) >= 1 then
		layoutChanged = true
	end
	if not self.primaryPanelOffset or abs(self.primaryPanelOffset - sectionPadding) >= 1 then
		layoutChanged = true
	end

	local previousXpLayout = self.xpLayout or {}
	local newXpLayout = xpLayout or {}
	if abs((previousXpLayout.width or 0) - (newXpLayout.width or 0)) >= 1
	or abs((previousXpLayout.offset or 0) - (newXpLayout.offset or 0)) >= 1 then
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
	self.xpPanelHeight = xpPanelHeight
	self.xpLayout = xpLayout
	self.primaryPanelWidth = alignedPanelWidth
	self.primaryPanelOffset = sectionPadding
	self.upgradePanelHeight = 0
	self.upgradeCardsLayout = nil

	return layoutChanged
end

function GameOver:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)
	totalButtonHeight = max(0, totalButtonHeight or 0)
	buttonSpacing = max(0, buttonSpacing or 0)

	local panelHeight = max(0, self.summaryPanelHeight or 0)
	local titleTop = 78
	local titleHeight = fontTitle and fontTitle:getHeight() or 0
	local panelTopMin = titleTop + titleHeight + 16
	local bottomMargin = 40
	local buttonAreaTop = sh - bottomMargin - totalButtonHeight
	local spacingBetween = max(48, buttonSpacing)
	local panelBottomMax = buttonAreaTop - spacingBetween

	if panelBottomMax < panelTopMin then
		panelBottomMax = panelTopMin
	end

	local availableSpace = max(0, panelBottomMax - panelTopMin)
	local panelY = panelTopMin

	if availableSpace > panelHeight then
		panelY = panelTopMin + (availableSpace - panelHeight) / 2
	elseif panelHeight > availableSpace then
		panelY = max(panelTopMin, panelBottomMax - panelHeight)
	end

	panelY = floor(panelY + 0.5)

	local buttonStartY = max(buttonAreaTop, panelY + panelHeight + spacingBetween)
	buttonStartY = min(buttonStartY, sh - bottomMargin - totalButtonHeight)
	if BUTTON_VERTICAL_OFFSET and BUTTON_VERTICAL_OFFSET ~= 0 then
		buttonStartY = buttonStartY - BUTTON_VERTICAL_OFFSET
		buttonStartY = max(panelY + panelHeight + spacingBetween, buttonStartY)
	end
	buttonStartY = floor(buttonStartY + 0.5)

	self.summaryPanelY = panelY
	self.buttonStartY = buttonStartY

	return panelY, buttonStartY
end

function GameOver:updateButtonLayout()
	local sw, sh = Screen:get()
	local _, buttonHeight, buttonSpacing = getButtonMetrics()
	local totalButtonHeight = 0
	if #buttonDefs > 0 then
		if #buttonDefs == 2 then
			totalButtonHeight = buttonHeight
		else
			totalButtonHeight = #buttonDefs * buttonHeight + max(0, (#buttonDefs - 1) * buttonSpacing)
		end
	end

	local _, startY = self:computeAnchors(sw, sh, totalButtonHeight, buttonSpacing)
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
	insert(anim.celebrations, entry)

	local maxVisible = 3
	while #anim.celebrations > maxVisible do
		remove(anim.celebrations, 1)
	end
end

function GameOver:enter(data)
	UI.clearButtons()
	resetAnalogAxis()

	data = data or {cause = "unknown"}

	self.isVictory = data.won == true
	self.customTitle = type(data.storyTitle) == "string" and data.storyTitle or nil
	GameOver.isVictory = self.isVictory

	self.unlockOverlayQueue = {}
	self.activeUnlockOverlay = nil
	self.progressionComplete = false

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
	fontScore = UI.fonts.heading or UI.fonts.title or UI.fonts.display
	fontScoreValue = UI.fonts.heading or UI.fonts.title or UI.fonts.subtitle
	fontSmall = UI.fonts.caption or UI.fonts.body
	fontMessage = UI.fonts.body or UI.fonts.prompt or fontSmall
	fontBadge = UI.fonts.badge or UI.fonts.button
	fontProgressTitle = UI.fonts.heading or UI.fonts.subtitle
	fontProgressValue = UI.fonts.display or UI.fonts.title
	fontProgressSmall = UI.fonts.caption or UI.fonts.body
	fontProgressLabel = UI.fonts.prompt or UI.fonts.subtitle or fontProgressSmall

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
		challengeBonusXP = max(0, self.dailyChallengeResult.xpAwarded or 0)
	end

	self.dailyStreakMessage = nil
	self.dailyStreakColor = nil
	if self.dailyChallengeResult and self.dailyChallengeResult.streakInfo then
		local info = self.dailyChallengeResult.streakInfo
		local streak = max(0, info.current or 0)
		local best = max(streak, info.best or 0)

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
			elseif not info.needsCompletion then
				messageKey = "gameover.daily_streak_status"
			end

			if messageKey then
				self.dailyStreakMessage = Localization:get(messageKey, replacements)
			else
				self.dailyStreakMessage = nil
			end

			if not self.dailyStreakMessage then
				self.dailyStreakColor = nil
			elseif self.dailyChallengeResult.completedNow then
				if info.wasNewBest then
					self.dailyStreakColor = Theme.accentTextColor or UI.colors.accentText or UI.colors.highlight
				else
					self.dailyStreakColor = Theme.progressColor or UI.colors.progress or UI.colors.highlight
				end
			elseif info.alreadyCompleted then
				self.dailyStreakColor = UI.colors.mutedText or Theme.mutedTextColor or UI.colors.text
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

	self.xpSectionHeight = nil
	self.baseXpSectionHeight = nil
	self.progressionAnimation = nil

	if self.progression then
		local startSnapshot = self.progression.start or {total = 0, level = 1, xpIntoLevel = 0, xpForNext = MetaProgression:getXpForLevel(1)}
		local resultSnapshot = self.progression.result or startSnapshot

		local fillSpeed = max(60, (self.progression.gained or 0) / 1.2)
		self.progressionAnimation = {
			displayedTotal = startSnapshot.total or 0,
			targetTotal = resultSnapshot.total or (startSnapshot.total or 0),
			displayedLevel = startSnapshot.level or 1,
			xpIntoLevel = startSnapshot.xpIntoLevel or 0,
			xpForLevel = startSnapshot.xpForNext or MetaProgression:getXpForLevel(startSnapshot.level or 1),
			displayedGained = 0,
			fillSpeed = fillSpeed,
			levelFlash = 0,
			levelPopDuration = 0.65,
			levelPopTimer = 0.65,
			celebrations = {},
			pendingMilestones = {},
			levelUnlocks = {},
			bonusXP = challengeBonusXP,
			barPulse = 0,
			pendingFruitXp = 0,
			fruitDelivered = 0,
			fillEaseSpeed = clamp(fillSpeed / 12, 6, 16),
			streakColor = self.dailyStreakColor,
		}

		local applesCollected = max(0, stats.apples or 0)
		local fruitPoints = 0
		if self.progression and self.progression.breakdown then
			fruitPoints = max(0, self.progression.breakdown.fruitPoints or 0)
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

		local startLevel = self.progressionAnimation.displayedLevel or startSnapshot.level or 1
		if (self.progressionAnimation.xpForLevel or 0) > 0 then
			self.progressionAnimation.visualPercent = clamp((self.progressionAnimation.xpIntoLevel or 0) / self.progressionAnimation.xpForLevel, 0, 1)
		else
			self.progressionAnimation.visualPercent = 0
		end
		self.progressionAnimation.visualProgress = max(0, (startLevel - 1) + (self.progressionAnimation.visualPercent or 0))

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
				local entry = {
					name = unlock.name,
					description = unlock.description,
					level = unlock.level,
					id = unlock.id,
					unlockTags = cloneArray(unlock.unlockTags),
					previewUpgradeId = unlock.previewUpgradeId,
				}
				insert(self.progressionAnimation.levelUnlocks[level], entry)
			end
		end
	end

	self.progressionComplete = self.progressionAnimation == nil

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

local function drawCelebrationsList(anim, x, startY, width)
	local events = anim and anim.celebrations or {}
	if not events or #events == 0 then
		return startY
	end

	local y = startY
	local cardWidth = width - 32
	local now = Timer.getTime()

	local celebrationHeight = getCelebrationEntryHeight()
	local celebrationSpacing = getCelebrationEntrySpacing()
	local outerRadius = (UI.scaled and UI.scaled(16, 12)) or 16
	local innerRadius = (UI.scaled and UI.scaled(12, 8)) or 12

	for index, event in ipairs(events) do
		local timer = max(0, event.timer or 0)
		local appear = min(1, timer / 0.35)
		local appearEase = easeOutBack(appear)
		local fadeAlpha = 1
		local duration = event.duration or 4.5
		if duration > 0 then
			local fadeStart = max(0, duration - 0.65)
			if timer > fadeStart then
				local fadeProgress = min(1, (timer - fadeStart) / 0.65)
				fadeAlpha = 1 - fadeProgress
			end
		end

		local alpha = max(0, fadeAlpha)

		if alpha > 0.01 then
			local cardX = x + 16
			local cardY = y
			local wobble = sin(now * 4.2 + index * 0.8) * 2 * alpha

			love.graphics.push()
			love.graphics.translate(cardX + cardWidth / 2, cardY + celebrationHeight / 2 + wobble)
			love.graphics.scale(0.92 + 0.08 * appearEase, 0.92 + 0.08 * appearEase)
			love.graphics.translate(-(cardX + cardWidth / 2), -(cardY + celebrationHeight / 2 + wobble))

			UI.drawLabel(event.title or "", cardX + 18, cardY + 12, cardWidth - 36, "left", {
				font = fontProgressSmall,
				color = {UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], alpha},
				shadow = true,
				shadowOffset = TEXT_SHADOW_OFFSET,
			})

			if event.subtitle and event.subtitle ~= "" then
				UI.drawLabel(event.subtitle, cardX + 18, cardY + 32, cardWidth - 36, "left", {
					font = fontSmall,
					color = {UI.colors.mutedText[1], UI.colors.mutedText[2], UI.colors.mutedText[3], alpha},
					shadow = true,
					shadowOffset = TEXT_SHADOW_OFFSET,
				})
			end

			love.graphics.pop()
		end

		y = y + celebrationSpacing
	end

	return y
end

local function drawXpSection(self, x, y, width)
	local anim = self.progressionAnimation
	if not anim then
		return
	end

	local centerX = x + width / 2
	local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local baseHeight = self.baseXpSectionHeight or measureXpPanelHeight(self, width, 0)
	local targetHeight = measureXpPanelHeight(self, width, celebrationCount)
	self.baseXpSectionHeight = self.baseXpSectionHeight or baseHeight
	local animatedHeight = self.xpSectionHeight or targetHeight
	local height = max(160, baseHeight, targetHeight, animatedHeight)
	local headerY = y + 18

	local levelColor = Theme.progressColor or UI.colors.progress or UI.colors.text
	local flash = max(0, min(1, anim.levelFlash or 0))
	local levelY = headerY + 16

	if flash > 0.01 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		local centerY = levelY + fontProgressValue:getHeight() / 2
		love.graphics.setColor(levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.24 * flash)
		love.graphics.circle("fill", centerX, centerY, 48 + flash * 26, 48)
		love.graphics.setColor(1, 1, 1, 0.12 * flash)
		love.graphics.circle("line", centerX, centerY, 48 + flash * 18, 48)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	local ringTop = levelY + fontProgressValue:getHeight() + 18 + (XP_RING_VERTICAL_OFFSET or 0)
	local baseMaxRadius = max(52, min(84, (width / 2) - 18))
	local scaledMaxRadius = baseMaxRadius * 1.08
	local ringThickness = max(16, min(26, scaledMaxRadius * 0.42))
	local sizeBoost = XP_RING_SIZE_BOOST or 0
	local baseRingRadius = max(32, scaledMaxRadius - ringThickness * 0.24)
	local ringRadius = baseRingRadius + sizeBoost
	local innerRadius = max(28, baseRingRadius - ringThickness * 0.52) + sizeBoost
	local outerRadius = ringRadius + ringThickness * 0.4
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

	local panelColor = Theme.panelColor or {0.18, 0.18, 0.22, 1}
	local trackColor = withAlpha(darkenColor(panelColor, 0.2), 0.85)
	local ringColor = {levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.9}

	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle("fill", centerX, centerY, outerRadius + 5, 96)

	love.graphics.setColor(trackColor)
	love.graphics.circle("fill", centerX, centerY, outerRadius, 96)

	local startAngle = -pi / 2
	love.graphics.setColor(withAlpha(lightenColor(panelColor, 0.12), 0.88))
	love.graphics.setLineWidth(ringThickness)
	love.graphics.arc("line", "open", centerX, centerY, ringRadius, startAngle, startAngle + pi * 2, 96)

	if percent > 0 then
		local endAngle = startAngle + percent * pi * 2
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

	love.graphics.setColor(0, 0, 0, 0.94)
	love.graphics.circle("fill", centerX, centerY, innerRadius)

	local coreColor = GameOver.xpCoreColor or withAlpha(copyColor(levelColor), 0.55)
	love.graphics.setColor(coreColor[1] or 1, coreColor[2] or 1, coreColor[3] or 1, coreColor[4] or 1)
	love.graphics.circle("fill", centerX, centerY, innerRadius - 2, 64)

	drawFruitAnimations(anim)

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
	local textColor = Theme.textColor or UI.colors.text
	local shadowColor = UI.colors.shadow or Theme.shadowColor or {0, 0, 0, 0.7}
	local levelValue = tostring(anim.displayedLevel or 1)
	local popDuration = anim.levelPopDuration or 0.65
	local popTimer = clamp(anim.levelPopTimer or popDuration, 0, popDuration)
	local popProgress = 1
	if popDuration > 1e-6 then
		popProgress = clamp(popTimer / popDuration, 0, 1)
	end
	local popScale = 1
	if popProgress < 1 then
		local pop = clamp(1 - popProgress, 0, 1)
		popScale = 1 + easeOutBack(pop) * 0.3
	end

	local levelScale = 1.12
	love.graphics.push()
	love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
	love.graphics.translate(centerX + TEXT_SHADOW_OFFSET, centerY + TEXT_SHADOW_OFFSET)
	love.graphics.scale(popScale * levelScale, popScale * levelScale)
	love.graphics.printf(levelValue, -innerRadius, -fontProgressValue:getHeight() / 2 + 2, innerRadius * 2, "center")
	love.graphics.pop()

	love.graphics.push()
	love.graphics.setColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
	love.graphics.translate(centerX, centerY)
	love.graphics.scale(popScale * levelScale, popScale * levelScale)
	love.graphics.printf(levelValue, -innerRadius, -fontProgressValue:getHeight() / 2 + 2, innerRadius * 2, "center")
	love.graphics.pop()

	local labelY = centerY + outerRadius + 18
	local breakdown = self.progression and self.progression.breakdown or {}
	local bonusXP = max(0, floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
	if bonusXP > 0 then
		local bonusText = Localization:get("gameover.meta_progress_bonus", {bonus = formatXpValue(bonusXP)})
		UI.drawLabel(bonusText, x, labelY, width, "center", {
			font = fontProgressSmall,
			color = UI.colors.highlight or UI.colors.text,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
		})
		labelY = labelY + fontProgressSmall:getHeight() + 6
	end

	if self.dailyStreakMessage then
		UI.drawLabel(self.dailyStreakMessage, x, labelY, width, "center", {
			font = fontProgressSmall,
			color = self.dailyStreakColor or UI.colors.highlight or UI.colors.text,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
		})
		labelY = labelY + fontProgressSmall:getHeight() + 6
	end

	local totalValue = floor((anim.displayedTotal or 0) + 0.5)
	local totalLabel
	if (anim.xpForLevel or 0) <= 0 then
		totalLabel = Localization:get("gameover.meta_progress_total_summary_max", {
			total = formatXpValue(totalValue),
		})
	else
		local remaining = max(0, math.ceil((anim.xpForLevel or 0) - (anim.xpIntoLevel or 0)))
		totalLabel = Localization:get("gameover.meta_progress_total_summary_next", {
			total = formatXpValue(totalValue),
			remaining = formatXpValue(remaining),
		})
	end

	local xpLabelFont = fontProgressLabel or fontProgressSmall
	local xpLabelHeight = (xpLabelFont and xpLabelFont:getHeight()) or 0
	UI.drawLabel(totalLabel, x, labelY, width, "center", {
		font = xpLabelFont,
		color = UI.colors.text,
		shadow = true,
		shadowOffset = TEXT_SHADOW_OFFSET,
	})

	labelY = labelY + xpLabelHeight + 4
	local celebrationStart = labelY + xpLabelHeight + 16
	drawCelebrationsList(anim, x, celebrationStart, width)
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
		})

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
		})
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
	})

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
		})
		entryY = entryY + fontSmall:getHeight()

		if entry.description and entry.description ~= "" then
			UI.drawLabel(entry.description, textX, entryY, textWidth, "left", {
				font = fontProgressSmall,
				color = UI.colors.mutedText or UI.colors.text,
				shadow = true,
				shadowOffset = TEXT_SHADOW_OFFSET,
			})
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
			elseif entry.id == "achievements" then
				drawAchievementsPanel(self, entryX, entryY, entryWidth, entryHeight, sectionPadding, innerSpacing, smallSpacing, entry.layoutData or self.achievementsLayout)
			end
		end

		currentY = currentY + (layout.columnsHeight or 0)
	end

	local xpHeight = self.xpPanelHeight or 0
	local xpLayout = self.xpLayout or {}

	if xpHeight > 0 then
		currentY = currentY + sectionSpacing
		local xpWidth = max(0, min(primaryWidth, xpLayout.width or primaryWidth))
		local sw = select(1, Screen:get())
		local xpX = floor((sw - xpWidth) / 2 + 0.5)
		drawXpSection(self, xpX, currentY, xpWidth)
		currentY = currentY + xpHeight
	end

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
	})

	drawCombinedPanel(self, contentWidth, contentX, padding, panelY)

	for _, btn in buttonList:iter() do
		if btn.textKey then
			btn.text = Localization:get(btn.textKey)
		end
	end

	buttonList:draw()

	self:drawUnlockOverlay()
end

function GameOver:update(dt)
	local anim = self.progressionAnimation
	if not anim then
		local layoutChanged = self:updateLayoutMetrics()
		if layoutChanged then
			self:updateButtonLayout()
		end
		self:_updateUnlockOverlay(dt)
		return
	end

	local targetTotal = anim.targetTotal or anim.displayedTotal or 0
	local startTotal = 0
	if self.progression and self.progression.start then
		startTotal = self.progression.start.total or 0
	end

	local previousTotal = anim.displayedTotal or startTotal
	local fruitPoints = max(0, anim.fruitPoints or 0)
	local deliveredFruit = max(0, anim.fruitDelivered or 0)
	local pendingFruit = max(0, anim.pendingFruitXp or 0)
	local allowedTarget = targetTotal

	if fruitPoints > 0 and deliveredFruit < fruitPoints then
		local gatedTarget = startTotal + min(fruitPoints, deliveredFruit + pendingFruit)
		allowedTarget = min(allowedTarget, gatedTarget)
	end

	local newTotal = previousTotal
	if previousTotal < allowedTarget then
		local increment = min(anim.fillSpeed * dt, allowedTarget - previousTotal)
		newTotal = previousTotal + increment

		if fruitPoints > 0 and deliveredFruit < fruitPoints then
			local newDelivered = min(fruitPoints, deliveredFruit + increment)
			local used = newDelivered - deliveredFruit
			anim.fruitDelivered = newDelivered
			anim.pendingFruitXp = max(0, pendingFruit - used)
		end
	elseif previousTotal < targetTotal then
		newTotal = min(targetTotal, previousTotal)
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
		anim.displayedGained = min((self.progression and self.progression.gained) or 0, newTotal - startTotal)
	end

	local previousLevel = anim.displayedLevel or 1
	local level, xpIntoLevel, xpForNext = MetaProgression:getProgressForTotal(anim.displayedTotal)
	if level > previousLevel then
		anim.levelPopDuration = anim.levelPopDuration or 0.65
		anim.levelPopTimer = 0
		for levelReached = previousLevel + 1, level do
			anim.levelFlash = 0.9
			addCelebration(anim, {
				type = "level",
				title = Localization:get("gameover.meta_progress_level_up", {level = levelReached}),
				subtitle = Localization:get("gameover.meta_progress_level_up_subtitle"),
				color = Theme.progressColor or {1, 1, 1, 1},
				duration = 5.5,
			})
			Audio:playSound("goal_reached")

			local unlockList = anim.levelUnlocks[levelReached]
			if unlockList then
				for _, unlock in ipairs(unlockList) do
					addCelebration(anim, {
						type = "unlock",
						title = Localization:get("gameover.meta_progress_unlock_header", {name = unlock.name or "???"}),
						subtitle = unlock.description or "",
						color = Theme.achieveColor or {1, 1, 1, 1},
						duration = 6,
					})
					self:_queueUnlockOverlay(unlock)
				end
			end
		end
	end

	anim.displayedLevel = level
	anim.xpIntoLevel = xpIntoLevel
	anim.xpForLevel = xpForNext

	local xpForLevel = anim.xpForLevel or 0
	local targetPercent = 0
	if xpForLevel > 0 then
		targetPercent = clamp((anim.xpIntoLevel or 0) / xpForLevel, 0, 1)
	end

	local easeSpeed = anim.fillEaseSpeed or 9
	if xpForLevel <= 0 then
		anim.visualProgress = max(0, (level - 1))
		anim.visualPercent = targetPercent
	else
		local targetProgress = max(0, (level - 1) + targetPercent)
		if not anim.visualProgress then
			local basePercent = anim.visualPercent or targetPercent
			anim.visualProgress = max(0, (previousLevel - 1) + basePercent)
		end

		local currentProgress = anim.visualProgress or 0
		targetProgress = max(targetProgress, currentProgress)
		anim.visualProgress = approachExp(currentProgress, targetProgress, dt, easeSpeed)

		local loops = floor(max(0, anim.visualProgress))
		local fraction = anim.visualProgress - loops
		anim.visualPercent = clamp(fraction, 0, 1)
	end

	if anim.levelFlash then
		anim.levelFlash = max(0, anim.levelFlash - dt)
	end

	local popDuration = anim.levelPopDuration or 0.65
	if popDuration > 0 then
		local timer = anim.levelPopTimer or popDuration
		anim.levelPopTimer = min(popDuration, timer + dt)
	else
		anim.levelPopTimer = 0
	end

	if anim.pendingMilestones then
		for _, milestone in ipairs(anim.pendingMilestones) do
			if not milestone.triggered and (anim.displayedTotal or 0) >= (milestone.threshold or 0) then
				milestone.triggered = true
				addCelebration(anim, {
					type = "milestone",
					title = Localization:get("gameover.meta_progress_milestone_header"),
					subtitle = Localization:get("gameover.meta_progress_milestone", {threshold = milestone.threshold}),
					color = Theme.achieveColor or {1, 1, 1, 1},
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
				remove(anim.celebrations, index)
			end
		end
	end

	updateFruitAnimations(anim, dt)

	if anim.barPulse then
		anim.barPulse = max(0, anim.barPulse - dt * 2.4)
	end

	local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
	local xpWidth = (self.xpLayout and self.xpLayout.width) or 0
	if xpWidth <= 0 then
		local innerWidth = self.innerContentWidth or 0
		local sectionPadding = self.sectionPaddingValue or getSectionPadding()
		xpWidth = max(0, innerWidth - sectionPadding * 2)
	end

	local baseHeight = measureXpPanelHeight(self, xpWidth, 0)
	local targetHeight = measureXpPanelHeight(self, xpWidth, celebrationCount)
	self.baseXpSectionHeight = baseHeight
	self.xpSectionHeight = self.xpSectionHeight or baseHeight
	local smoothing = min(dt * 6, 1)
	self.xpSectionHeight = self.xpSectionHeight + (targetHeight - self.xpSectionHeight) * smoothing

	if not self.progressionComplete and self:_isProgressionFillComplete(anim) then
		self.progressionComplete = true
	end

	local layoutChanged = self:updateLayoutMetrics()
	if layoutChanged then
		self:updateButtonLayout()
	end

	self:_updateUnlockOverlay(dt)
end

function GameOver:_queueUnlockOverlay(unlock)
	if not unlock then
		return
	end

	if not self.unlockOverlayQueue then
		self.unlockOverlayQueue = {}
	end

	if not (Upgrades and Upgrades.getShowcaseCardForUnlock) then
		return
	end

	local card = Upgrades:getShowcaseCardForUnlock(unlock)
	if not card then
		return
	end

	local overlayTitle = getLocalizedOrFallback("gameover.meta_progress_unlock_overlay_title", "New upgrade unlocked!")
	local continueText = getLocalizedOrFallback("gameover.meta_progress_unlock_overlay_continue", "Press any key to continue")

	local entry = {
		unlock = unlock,
		card = card,
		title = overlayTitle,
		continueText = continueText,
		name = unlock.name,
		description = unlock.description,
		level = unlock.level,
		id = unlock.id,
		unlockTags = cloneArray(unlock.unlockTags),
		previewUpgradeId = unlock.previewUpgradeId,
		phase = "queued",
		timer = 0,
		alpha = 0,
		scale = 0.88,
		minHoldTime = 0.35,
		enterDuration = 0.35,
		exitDuration = 0.28,
		dismissRequested = false,
		ready = false,
		cardState = {hover = 0, focus = 0, selection = 0, fadeOut = 0},
	}

	self.unlockOverlayQueue[#self.unlockOverlayQueue + 1] = entry
end

function GameOver:_startUnlockOverlayExit()
	local overlay = self.activeUnlockOverlay
	if not overlay or overlay.phase == "exit" then
		return
	end

	overlay.phase = "exit"
	overlay.timer = 0
	overlay.dismissRequested = false
	overlay.ready = true
	Audio:playSound("click")
end

function GameOver:_updateUnlockOverlay(dt)
	dt = dt or 0

	if self.progressionComplete and (not self.activeUnlockOverlay) and self.unlockOverlayQueue and #self.unlockOverlayQueue > 0 then
		local overlay = remove(self.unlockOverlayQueue, 1)
		overlay.phase = "enter"
		overlay.timer = 0
		overlay.alpha = 0
		overlay.scale = overlay.scale or 1
		overlay.dismissRequested = false
		overlay.ready = false
		overlay.cardState = overlay.cardState or {hover = 0, focus = 0, selection = 0, fadeOut = 0}
		self.activeUnlockOverlay = overlay
	end

	local overlay = self.activeUnlockOverlay
	if not overlay then
		return
	end

	overlay.timer = (overlay.timer or 0) + dt

	if overlay.phase == "enter" then
		local duration = overlay.enterDuration or 0.35
		local progress = duration > 0 and clamp(overlay.timer / duration, 0, 1) or 1
		overlay.alpha = clamp(progress, 0, 1)
		overlay.scale = 1
		if progress >= 1 then
			overlay.phase = "hold"
			overlay.timer = 0
			overlay.alpha = 1
			overlay.scale = 1
			overlay.ready = (overlay.minHoldTime or 0) <= 0
			if overlay.ready and overlay.dismissRequested then
				self:_startUnlockOverlayExit()
			end
		end
	elseif overlay.phase == "hold" then
		local hold = overlay.minHoldTime or 0.3
		if not overlay.ready and overlay.timer >= hold then
			overlay.ready = true
			if overlay.dismissRequested then
				self:_startUnlockOverlayExit()
				return
			end
		end
		overlay.alpha = 1
		overlay.scale = 1
	elseif overlay.phase == "exit" then
		local duration = overlay.exitDuration or 0.28
		local progress = duration > 0 and clamp(overlay.timer / duration, 0, 1) or 1
		local eased = easeOutQuad(progress)
		overlay.alpha = max(0, 1 - eased)
		overlay.scale = 1
		if progress >= 1 then
			self.activeUnlockOverlay = nil
		end
	end
end

function GameOver:_consumeUnlockOverlayInput()
	if not self.progressionComplete then
		return false
	end

	if not self.activeUnlockOverlay and self.unlockOverlayQueue and #self.unlockOverlayQueue > 0 then
		self:_updateUnlockOverlay(0)
	end

	local overlay = self.activeUnlockOverlay
	if not overlay then
		return false
	end

	overlay.dismissRequested = true
	if overlay.phase == "exit" then
		return true
	end

	if overlay.phase == "hold" and overlay.ready then
		self:_startUnlockOverlayExit()
	end

	return true
end

function GameOver:_isProgressionFillComplete(anim)
	if not anim then
		return true
	end

	local target = anim.targetTotal or 0
	local displayed = anim.displayedTotal or 0
	if displayed + 1e-4 < target then
		return false
	end

	if (anim.pendingFruitXp or 0) > 0.01 then
		return false
	end

	if (anim.fruitRemaining or 0) > 0 then
		return false
	end

	local activeFruit = (anim.fruitAnimations and #anim.fruitAnimations or 0)
	if activeFruit > 0 then
		return false
	end

	local gainedTotal = (self.progression and self.progression.gained) or 0
	if gainedTotal > 0 and (anim.displayedGained or 0) + 0.01 < gainedTotal then
		return false
	end

	return true
end

function GameOver:drawUnlockOverlay()
	local overlay = self.activeUnlockOverlay
	if not overlay then
		return
	end

	local alpha = clamp(overlay.alpha or 0, 0, 1)
	if alpha <= 0 then
		return
	end

	local sw, sh = Screen:get()
	love.graphics.push("all")
	love.graphics.setColor(0, 0, 0, 0.75 * alpha)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	local card = overlay.card
	local titleText = overlay.title or getLocalizedOrFallback("gameover.meta_progress_unlock_overlay_title", "New upgrade unlocked!")
	local continueText = overlay.continueText or getLocalizedOrFallback("gameover.meta_progress_unlock_overlay_continue", "Press any key to continue")
	local nameText = overlay.name or ""
	local descText = overlay.description or ""

	local titleColor = withAlpha(UI.colors.text or {1, 1, 1, 1}, alpha)
	local mutedColor = withAlpha(UI.colors.mutedText or UI.colors.text or {0.7, 0.7, 0.7, 1}, alpha)
	local baseContinueColor = Theme.accentTextColor or UI.colors.highlight or UI.colors.text or {1, 1, 1, 1}
	local continueAlpha = alpha * (overlay.ready and 1 or 0.6)
	if overlay.ready then
		local pulse = 0.75 + 0.25 * (sin(Timer.getTime() * 3.4) * 0.5 + 0.5)
		continueAlpha = continueAlpha * pulse
	end
	local continueColor = withAlpha(baseContinueColor, continueAlpha)

	local baseWidth, baseHeight = 264, 344
	local widthMargin = 64
	local heightMargin = 160
	local availableWidth = max(0, sw - widthMargin)
	local availableHeight = max(0, sh - heightMargin)
	local scale = 1
	if baseWidth > availableWidth or baseHeight > availableHeight then
		local widthScale = availableWidth > 0 and (availableWidth / baseWidth) or 0
		local heightScale = availableHeight > 0 and (availableHeight / baseHeight) or 0
		local limit = min(widthScale, heightScale)
		scale = clamp(limit, 0, 1)
	end
	scale = scale * (overlay.scale or 1)
	local cardWidth = baseWidth * scale
	local cardHeight = baseHeight * scale
	local cardX = (sw - cardWidth) / 2
	local cardCenterY = sh * 0.48
	local cardY = cardCenterY - cardHeight / 2

	if card then
		local options = {
			appearanceAlpha = alpha,
			animationState = overlay.cardState,
			index = 1,
		}
		Shop.drawCardPreview(card, cardX, cardY, cardWidth, cardHeight, options)
	end

	local titleFont = fontProgressTitle or fontTitle
	local nameFont = fontProgressValue or fontTitle
	local smallFont = fontSmall or UI.fonts.body or fontTitle

	local titleY = max(48, cardY - 140)
	UI.drawLabel(titleText, 0, titleY, sw, "center", {
		font = titleFont,
		color = titleColor,
		shadow = true,
		shadowOffset = TITLE_SHADOW_OFFSET,
	})

	local nextY = cardY + cardHeight + 28
	if nameText and nameText ~= "" then
		UI.drawLabel(nameText, 0, nextY, sw, "center", {
			font = nameFont,
			color = titleColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
		})
		local nameHeight = (nameFont and nameFont:getHeight()) or 0
		nextY = nextY + nameHeight + 12
	end

	if descText and descText ~= "" then
		local descWidth = sw * 0.55
		local descX = (sw - descWidth) / 2
		UI.drawLabel(descText, descX, nextY, descWidth, "center", {
			font = smallFont,
			color = mutedColor,
			shadow = true,
			shadowOffset = TEXT_SHADOW_OFFSET,
		})
		local smallHeight = (smallFont and smallFont:getHeight() * smallFont:getLineHeight()) or 0
		nextY = nextY + max(32, smallHeight + 18)
	end

	local continueY = max(nextY + 24, cardY + cardHeight + 72)
	UI.drawLabel(continueText, 0, continueY, sw, "center", {
		font = smallFont,
		color = continueColor,
		shadow = true,
		shadowOffset = TEXT_SHADOW_OFFSET,
	})

	love.graphics.pop()
end

function GameOver:mousepressed(x, y, button)
	if self:_consumeUnlockOverlayInput() then
		return
	end

	buttonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
	if self.activeUnlockOverlay then
		return
	end

	local action = buttonList:mousereleased(x, y, button)
	return handleButtonAction(self, action)
end

function GameOver:keypressed(key)
	if self:_consumeUnlockOverlayInput() then
		return
	end

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