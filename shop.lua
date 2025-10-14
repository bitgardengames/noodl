local UI = require("ui")
local Localization = require("localization")
local Upgrades = require("upgrades")
local Audio = require("audio")
local MetaProgression = require("metaprogression")
local Theme = require("theme")
local Shaders = require("shaders")
local Floors = require("floors")
local Shop = {}

local ANALOG_DEADZONE = 0.35
local analogAxisDirections = { horizontal = nil, vertical = nil }

local BACKGROUND_EFFECT_TYPE = "shopGlimmer"
local backgroundEffectCache = {}
local backgroundEffect = nil

local function getColorChannels(color, fallback)
        local reference = color or fallback
        if not reference then
                return 0, 0, 0, 1
        end

        return reference[1] or 0, reference[2] or 0, reference[3] or 0, reference[4] or 1
end

local function configureBackgroundEffect(palette)
        local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
        if not effect then
                backgroundEffect = nil
                return
        end

        local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
        effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.54

        local needsConfigure = (effect._appliedPalette ~= palette) or not effect._appliedPaletteConfigured

        if needsConfigure then
                local bgColor = (palette and palette.bgColor) or Theme.bgColor
                local accentColor = (palette and (palette.arenaBorder or palette.snake)) or Theme.buttonHover
                local highlightColor = (palette and (palette.highlightColor or palette.snake or palette.arenaBorder))
                        or Theme.accentTextColor
                        or Theme.highlightColor

                Shaders.configure(effect, {
                        bgColor = bgColor,
                        accentColor = accentColor,
                        glowColor = highlightColor,
                        highlightColor = highlightColor,
                })

                effect._appliedPalette = palette
                effect._appliedPaletteConfigured = true
        end

        backgroundEffect = effect
end

local function drawBackground(screenW, screenH, palette)
        local bgColor = (palette and palette.bgColor) or Theme.bgColor
        local baseR, baseG, baseB, baseA = getColorChannels(bgColor)
        love.graphics.setColor(baseR * 0.92, baseG * 0.92, baseB * 0.92, baseA)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        if not backgroundEffect or backgroundEffect._appliedPalette ~= palette then
                configureBackgroundEffect(palette)
        end

        if backgroundEffect then
                local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
                Shaders.draw(backgroundEffect, 0, 0, screenW, screenH, intensity)
        end

        local overlayR, overlayG, overlayB = getColorChannels(bgColor)
        love.graphics.setColor(overlayR, overlayG, overlayB, 0.28)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(1, 1, 1, 1)
end

local function moveFocusAnalog(self, delta)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end
	if self.selected then return end

	self.inputMode = "gamepad"
	self:moveFocus(delta)
end

local analogAxisActions = {
	horizontal = {
		negative = function(self)
			moveFocusAnalog(self, -1)
		end,
		positive = function(self)
			moveFocusAnalog(self, 1)
		end,
	},
	vertical = {
		negative = function(self)
			moveFocusAnalog(self, -1)
		end,
		positive = function(self)
			moveFocusAnalog(self, 1)
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

local function handleAnalogAxis(self, axis, value)
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
			action(self)
		end
	end
end

function Shop:start(currentFloor)
        self.floor = currentFloor or 1
        local floorData = Floors[self.floor]
        self.floorPalette = floorData and floorData.palette or nil
        self.shopkeeperLine = nil
        self.shopkeeperSubline = nil
        self.selectionHoldDuration = 1.85
        self.inputMode = nil
        self.time = 0
        configureBackgroundEffect(self.floorPalette)
        self:refreshCards()
end

function Shop:refreshCards(options)
	options = options or {}
	local initialDelay = options.initialDelay or 0

	self.restocking = nil
	local baseChoices = 3
	local upgradeBonus = 0
	if Upgrades.getEffect then
		upgradeBonus = math.max(0, math.floor(Upgrades:getEffect("shopSlots") or 0))
	end

	local metaBonus = 0
	if MetaProgression and MetaProgression.getShopBonusSlots then
		metaBonus = math.max(0, MetaProgression:getShopBonusSlots() or 0)
	end

	local extraChoices = upgradeBonus + metaBonus

	self.baseChoices = baseChoices
	self.upgradeBonusChoices = upgradeBonus
	self.metaBonusChoices = metaBonus
	self.extraChoices = extraChoices

	local cardCount = baseChoices + extraChoices
	self.totalChoices = cardCount
	self.cards = Upgrades:getRandom(cardCount, { floor = self.floor }) or {}
	self.cardStates = {}
	self.selected = nil
	self.selectedIndex = nil
	self.selectionProgress = 0
	self.selectionTimer = 0
	self.selectionComplete = false
	self.time = 0
	self.focusIndex = nil

	if #self.cards > 0 then
		self:setFocus(1)
	end

	resetAnalogAxis()

	for i = 1, #self.cards do
		self.cardStates[i] = {
			progress = 0,
			delay = initialDelay + (i - 1) * 0.08,
			selection = 0,
			selectionClock = 0,
			hover = 0,
			focus = 0,
			fadeOut = 0,
			selectionFlash = nil,
			revealSoundPlayed = false,
			selectSoundPlayed = false,
			discardActive = false,
			discard = nil,
		}
	end
end

function Shop:beginRestock()
	if self.restocking then return end

	self.restocking = {
		phase = "fadeOut",
		timer = 0,
		fadeDuration = 0.35,
		delayAfterFade = 0.12,
		revealDelay = 0.1,
	}

	self.selected = nil
	self.selectedIndex = nil
	self.selectionTimer = 0
	self.selectionComplete = false
	self.focusIndex = nil

	local random = love.math.random
	if self.cardStates then
		local count = #self.cardStates
		local centerIndex = (count + 1) / 2
		for index, state in ipairs(self.cardStates) do
			state.discardActive = true
			local spread = index - centerIndex
			local direction = spread >= 0 and 1 or -1
			local horizontalDistance = spread * 44 + (random() * 12 - 6)
			local rotation = spread * 0.16 + (random() * 0.18 - 0.09)
			local dropDistance = 220 + random() * 90
			local arcHeight = 26 + random() * 18
			local swayMagnitude = 12 + random() * 10
			local swaySpeed = 2.8 + random() * 0.8
			state.discard = {
				direction = direction,
				horizontalDistance = horizontalDistance,
				dropDistance = dropDistance,
				arcHeight = arcHeight,
				rotation = rotation,
				swayMagnitude = swayMagnitude,
				swaySpeed = swaySpeed,
				duration = 0.65 + random() * 0.15,
				clock = 0,
			}
		end
	end
end

function Shop:setFocus(index)
	if self.restocking then return end
	if not self.cards or not index then return end
	if index < 1 or index > #self.cards then return end
	local previous = self.focusIndex
	if previous and previous ~= index then
		Audio:playSound("shop_focus")
	end
	self.focusIndex = index
	return self.cards[index]
end

function Shop:moveFocus(delta)
	if self.restocking then return end
	if not delta or delta == 0 then return end
	if not self.cards or #self.cards == 0 then return end

	local count = #self.cards
	local index = self.focusIndex or 1
	index = ((index - 1 + delta) % count) + 1
	return self:setFocus(index)
end

function Shop:update(dt)
	if not dt then return end
	self.time = (self.time or 0) + dt
	if not self.cardStates then return end

	local restock = self.restocking
	local restockProgress = nil
	if restock then
		restock.timer = (restock.timer or 0) + dt
		if restock.phase == "fadeOut" then
			local duration = restock.fadeDuration or 0.35
			if duration <= 0 then
				restock.progress = 1
			else
				restock.progress = math.min(1, restock.timer / duration)
			end
			restockProgress = restock.progress
			if restock.progress >= 1 then
				restock.phase = "waiting"
				restock.timer = 0
			end
		elseif restock.phase == "waiting" then
			restockProgress = 1
			local delay = restock.delayAfterFade or 0
			if restock.timer >= delay then
				local revealDelay = restock.revealDelay or 0
				self.restocking = nil
				self:refreshCards({ initialDelay = revealDelay })
				return
			end
		end
	end

	self.selectionProgress = self.selectionProgress or 0
	if self.selected then
		self.selectionProgress = math.min(1, self.selectionProgress + dt * 2.4)
	else
		self.selectionProgress = math.max(0, self.selectionProgress - dt * 3)
	end

	for i, state in ipairs(self.cardStates) do
		if self.time >= state.delay and state.progress < 1 then
			state.progress = math.min(1, state.progress + dt * 3.2)
		end

		if not state.revealSoundPlayed and self.time >= state.delay then
			state.revealSoundPlayed = true
			Audio:playSound("shop_card_deal")
		end

		if state.discardActive and state.discard then
			state.discard.clock = (state.discard.clock or 0) + dt
		end

		local card = self.cards and self.cards[i]
		local isSelected = card and self.selected == card
		local isFocused = (self.focusIndex == i) and not self.selected
		if isSelected then
			state.selection = math.min(1, (state.selection or 0) + dt * 4)
			state.selectionClock = (state.selectionClock or 0) + dt
			state.focus = math.min(1, (state.focus or 0) + dt * 3)
			state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 4)
			state.hover = math.max(0, (state.hover or 0) - dt * 6)
			if not state.selectSoundPlayed then
				state.selectSoundPlayed = true
				Audio:playSound("shop_card_select")
			end
		else
			state.selection = math.max(0, (state.selection or 0) - dt * 3)
			if state.selection <= 0.001 then
				state.selectionClock = 0
			else
				state.selectionClock = (state.selectionClock or 0) + dt
			end
			if isFocused and not restock then
				state.hover = math.min(1, (state.hover or 0) + dt * 6)
			else
				state.hover = math.max(0, (state.hover or 0) - dt * 4)
			end
			if restock then
				local fadeTarget = restockProgress or 0
				state.fadeOut = math.max(fadeTarget, math.min(1, (state.fadeOut or 0) + dt * 3.2))
				state.focus = math.max(0, (state.focus or 0) - dt * 4)
			elseif self.selected then
				state.fadeOut = math.min(1, (state.fadeOut or 0) + dt * 3.2)
				state.focus = math.max(0, (state.focus or 0) - dt * 4)
			else
				state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 3)
				state.focus = math.max(0, (state.focus or 0) - dt * 3)
			end
			state.selectSoundPlayed = false
		end

		if state.selectionFlash then
			local flashDuration = 0.75
			state.selectionFlash = state.selectionFlash + dt
			if state.selectionFlash >= flashDuration then
				state.selectionFlash = nil
			end
		end
	end

	if self.selected then
		self.selectionTimer = (self.selectionTimer or 0) + dt
		if not self.selectionComplete then
			local hold = self.selectionHoldDuration or 0
			local state = self.selectedIndex and self.cardStates and self.cardStates[self.selectedIndex] or nil
			local flashDone = not (state and state.selectionFlash)
			if self.selectionTimer >= hold and flashDone then
				self.selectionComplete = true
				Audio:playSound("shop_purchase")
			end
		end
	else
		self.selectionTimer = 0
		self.selectionComplete = false
		self.selectedIndex = nil
	end
end

local rarityBorderAlpha = 0.85

local rarityStyles = {
	common = {
		base = {0.20, 0.23, 0.28, 1},
		shadowAlpha = 0.18,
		aura = {
			color = {0.52, 0.62, 0.78, 0.22},
			radius = 0.72,
			y = 0.42,
		},
		outerGlow = {
			color = {0.62, 0.74, 0.92, 1},
			min = 0.04,
			max = 0.14,
			speed = 1.4,
			expand = 5,
			width = 6,
		},
		innerGlow = {
			color = {0.82, 0.90, 1.0, 1},
			min = 0.06,
			max = 0.18,
			speed = 1.2,
			inset = 8,
			width = 2,
		},
	},
	uncommon = {
		base = {0.18, 0.28, 0.22, 1},
		shadowAlpha = 0.24,
		aura = {
			color = {0.46, 0.78, 0.56, 0.28},
			radius = 0.76,
			y = 0.40,
		},
		outerGlow = {
			color = {0.52, 0.92, 0.64, 1},
			min = 0.08,
			max = 0.24,
			speed = 1.6,
			expand = 6,
			width = 6,
		},
		innerGlow = {
			color = {0.68, 0.96, 0.78, 1},
			min = 0.10,
			max = 0.28,
			speed = 1.8,
			inset = 8,
			width = 3,
		},
	},
	rare = {
		base = {0.16, 0.24, 0.34, 1},
		shadowAlpha = 0.30,
		aura = {
			color = {0.40, 0.60, 0.92, 0.32},
			radius = 0.82,
			y = 0.36,
		},
		outerGlow = {
			color = {0.48, 0.72, 1.0, 1},
			min = 0.14,
			max = 0.32,
			speed = 1.9,
			expand = 7,
			width = 7,
		},
		innerGlow = {
			color = {0.64, 0.84, 1.0, 1},
			min = 0.16,
			max = 0.36,
			speed = 2.1,
			inset = 8,
			width = 3,
		},
	},
	epic = {
		base = {0.24, 0.12, 0.42, 1},
		shadowAlpha = 0.36,
		aura = {
			color = {0.86, 0.56, 0.98, 0.42},
			radius = 0.9,
			y = 0.34,
		},
		outerGlow = {
			color = {0.92, 0.74, 1.0, 1},
			min = 0.2,
			max = 0.46,
			speed = 2.4,
			expand = 9,
			width = 8,
		},
		innerGlow = {
			color = {0.98, 0.86, 1.0, 1},
			min = 0.26,
			max = 0.48,
			speed = 2.6,
			inset = 8,
			width = 3,
		},
		sparkles = {
			color = {0.98, 0.88, 1.0, 0.9},
			radius = 8,
			speed = 2.2,
			positions = {
				{0.24, 0.18, 1.0},
				{0.72, 0.32, 0.7},
				{0.38, 0.68, 0.8},
			},
		},
	},
	legendary = {
		base = {0.46, 0.28, 0.06, 1},
		shadowAlpha = 0.46,
		outerGlow = {
			color = {1.0, 0.82, 0.34, 1},
			min = 0.26,
			max = 0.56,
			speed = 2.6,
			expand = 10,
			width = 10,
		},
		innerGlow = {
			color = {1.0, 0.9, 0.6, 1},
			min = 0.32,
			max = 0.58,
			speed = 3.0,
			inset = 8,
			width = 3,
		},
		sparkles = {
			color = {1.0, 0.92, 0.64, 0.95},
			radius = 10,
			speed = 2.9,
			positions = {
				{0.18, 0.24, 1.1},
				{0.52, 0.16, 0.9},
				{0.72, 0.42, 1.2},
				{0.44, 0.74, 0.8},
			},
		},
		glow = 0.22,
		borderWidth = 5,
	},
}

local function applyColor(setColorFn, color, overrideAlpha)
	if not color then return end
	setColorFn(color[1], color[2], color[3], overrideAlpha or color[4] or 1)
end

local function withTransformedScissor(x, y, w, h, fn)
	if not fn then return end

	local sx1, sy1 = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)

	local scissorX = math.min(sx1, sx2)
	local scissorY = math.min(sy1, sy2)
	local scissorW = math.abs(sx2 - sx1)
	local scissorH = math.abs(sy2 - sy1)

	if scissorW <= 0 or scissorH <= 0 then
		fn()
		return
	end

	local previous = { love.graphics.getScissor() }
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
	fn()
	if previous[1] then
		love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
	else
		love.graphics.setScissor()
	end
end

local function getAnimatedAlpha(def, time)
	if not def then return nil end
	local minAlpha = def.min or def.alpha or 0
	local maxAlpha = def.max or def.alpha or minAlpha
	if not def.speed or maxAlpha == minAlpha then
		return maxAlpha
	end
	local phase = def.phase or 0
	local wave = math.sin(time * def.speed + phase) * 0.5 + 0.5
	return minAlpha + (maxAlpha - minAlpha) * wave
end

local function drawCard(card, x, y, w, h, hovered, index, _, isSelected, appearanceAlpha)
	local fadeAlpha = appearanceAlpha or 1
	local function setColor(r, g, b, a)
		love.graphics.setColor(r, g, b, (a or 1) * fadeAlpha)
	end

	local style = rarityStyles[card.rarity or "common"] or rarityStyles.common
	local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}

        if isSelected then
                local glowClock = love.timer.getTime()
		local pulse = 0.35 + 0.25 * (math.sin(glowClock * 5) * 0.5 + 0.5)
		setColor(1, 0.9, 0.45, pulse)
		love.graphics.setLineWidth(10)
		love.graphics.rectangle("line", x - 14, y - 14, w + 28, h + 28, 18, 18)
		love.graphics.setLineWidth(4)
	end

	if style.shadowAlpha and style.shadowAlpha > 0 then
		setColor(0, 0, 0, style.shadowAlpha)
		love.graphics.rectangle("fill", x + 6, y + 10, w, h, 18, 18)
	end

	applyColor(setColor, style.base)
	love.graphics.rectangle("fill", x, y, w, h, 12, 12)

        local currentTime = love.timer.getTime()

	if style.aura then
		withTransformedScissor(x, y, w, h, function()
			applyColor(setColor, style.aura.color)
			local radius = math.max(w, h) * (style.aura.radius or 0.72)
			local centerY = y + h * (style.aura.y or 0.4)
			love.graphics.circle("fill", x + w * 0.5, centerY, radius)
		end)
	end

	if style.outerGlow then
		local glowAlpha = getAnimatedAlpha(style.outerGlow, currentTime)
		if glowAlpha and glowAlpha > 0 then
			applyColor(setColor, style.outerGlow.color or borderColor, glowAlpha)
			love.graphics.setLineWidth(style.outerGlow.width or 6)
			local expand = style.outerGlow.expand or 6
			love.graphics.rectangle("line", x - expand, y - expand, w + expand * 2, h + expand * 2, 18, 18)
		end
	end
	if style.flare then
		withTransformedScissor(x, y, w, h, function()
			applyColor(setColor, style.flare.color)
			local radius = math.min(w, h) * (style.flare.radius or 0.36)
			love.graphics.circle("fill", x + w * 0.5, y + h * 0.32, radius)
		end)
	end

	if style.stripes then
		withTransformedScissor(x, y, w, h, function()
			love.graphics.push()
			love.graphics.translate(x + w / 2, y + h / 2)
			love.graphics.rotate(style.stripes.angle or -math.pi / 6)
			local diag = math.sqrt(w * w + h * h)
			local spacing = style.stripes.spacing or 34
			local width = style.stripes.width or 22
			applyColor(setColor, style.stripes.color)
			local stripeCount = math.ceil((diag * 2) / spacing) + 2
			for i = -stripeCount, stripeCount do
				local pos = i * spacing
				love.graphics.rectangle("fill", -diag, pos - width / 2, diag * 2, width)
			end
			love.graphics.pop()
		end)
	end

	if style.sparkles and style.sparkles.positions then
		withTransformedScissor(x, y, w, h, function()
                        local time = love.timer.getTime()
			for i, pos in ipairs(style.sparkles.positions) do
				local px, py, scale = pos[1], pos[2], pos[3] or 1
				local pulse = 0.6 + 0.4 * math.sin(time * (style.sparkles.speed or 1.8) + i * 0.9)
				local radius = (style.sparkles.radius or 9) * scale * pulse
				local sparkleColor = style.sparkles.color or borderColor
				local sparkleAlpha = (sparkleColor[4] or 1) * pulse
				applyColor(setColor, sparkleColor, sparkleAlpha)
				love.graphics.circle("fill", x + px * w, y + py * h, radius)
			end
		end)
	end

	if style.glow and style.glow > 0 then
		applyColor(setColor, borderColor, style.glow)
		love.graphics.setLineWidth(6)
		love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, 16, 16)
	end

	applyColor(setColor, borderColor, rarityBorderAlpha)
	love.graphics.setLineWidth(style.borderWidth or 4)
	love.graphics.rectangle("line", x, y, w, h, 12, 12)

	local hoverGlowAlpha
	if style.innerGlow then
		hoverGlowAlpha = getAnimatedAlpha(style.innerGlow, currentTime)
	end

	if hovered or isSelected then
		local focusAlpha = hovered and 0.6 or 0.4
		hoverGlowAlpha = math.max(hoverGlowAlpha or 0, focusAlpha)
	end

	if hoverGlowAlpha and hoverGlowAlpha > 0 then
		local innerColor = (style.innerGlow and style.innerGlow.color) or borderColor
		local inset = (style.innerGlow and style.innerGlow.inset) or 6
		love.graphics.setLineWidth((style.innerGlow and style.innerGlow.width) or 2)
		applyColor(setColor, innerColor, hoverGlowAlpha)
		love.graphics.rectangle("line", x + inset, y + inset, w - inset * 2, h - inset * 2, 10, 10)
	elseif hovered or isSelected then
		local glowAlpha = hovered and 0.55 or 0.35
		applyColor(setColor, borderColor, glowAlpha)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12, 10, 10)
	end

	love.graphics.setLineWidth(4)

	setColor(1, 1, 1, 1)
	local titleFont = UI.fonts.button
	love.graphics.setFont(titleFont)
	local titleWidth = w - 28
	local titleY = y + 24
	love.graphics.printf(card.name, x + 14, titleY, titleWidth, "center")

	local _, titleLines = titleFont:getWrap(card.name or "", titleWidth)
	local titleLineCount = math.max(1, #titleLines)
	local titleHeight = titleLineCount * titleFont:getHeight() * titleFont:getLineHeight()
	local contentTop = titleY + titleHeight

	local descStart
	if card.rarityLabel then
		local rarityFont = UI.fonts.body
		love.graphics.setFont(rarityFont)
		setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
		local rarityY = contentTop + 10
		love.graphics.printf(card.rarityLabel, x + 14, rarityY, titleWidth, "center")

		setColor(1, 1, 1, 0.3)
		love.graphics.setLineWidth(2)
		local rarityHeight = rarityFont:getHeight() * rarityFont:getLineHeight()
		local dividerY = rarityY + rarityHeight + 8
		love.graphics.line(x + 24, dividerY, x + w - 24, dividerY)
		descStart = dividerY + 16
	else
		setColor(1, 1, 1, 0.3)
		love.graphics.setLineWidth(2)
		local dividerY = contentTop + 14
		love.graphics.line(x + 24, dividerY, x + w - 24, dividerY)
		descStart = dividerY + 16
	end

	love.graphics.setFont(UI.fonts.body)
	setColor(0.92, 0.92, 0.92, 1)
	local descY = descStart
	if card.upgrade and card.upgrade.tags and #card.upgrade.tags > 0 then
		love.graphics.setFont(UI.fonts.small)
		setColor(0.8, 0.85, 0.9, 0.9)
		love.graphics.printf(table.concat(card.upgrade.tags, " • "), x + 18, descY, w - 36, "center")
		descY = descY + 22
		love.graphics.setFont(UI.fonts.body)
		setColor(0.92, 0.92, 0.92, 1)
	end
	love.graphics.printf(card.desc or "", x + 18, descY, w - 36, "center")
end

function Shop:draw(screenW, screenH)
        drawBackground(screenW, screenH, self.floorPalette)
	local textAreaWidth = screenW * 0.8
	local textAreaX = (screenW - textAreaWidth) / 2
	local currentY = screenH * 0.12

	love.graphics.setFont(UI.fonts.title)
	local titleText = Localization:get("shop.title")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(titleText, textAreaX, currentY, textAreaWidth, "center")

	local function advanceY(text, font, spacing)
		if not text or text == "" then
			return 0
		end
		local wrapWidth = textAreaWidth
		local _, lines = font:getWrap(text, wrapWidth)
		local lineCount = math.max(1, #lines)
		return lineCount * font:getHeight() * font:getLineHeight() + (spacing or 0)
	end

	currentY = currentY + advanceY(titleText, UI.fonts.title, 16)

	if self.shopkeeperLine and self.shopkeeperLine ~= "" then
		love.graphics.setFont(UI.fonts.body)
		love.graphics.setColor(1, 0.92, 0.8, 1)
		love.graphics.printf(self.shopkeeperLine, textAreaX, currentY, textAreaWidth, "center")
		currentY = currentY + advanceY(self.shopkeeperLine, UI.fonts.body, 10)
	end

	if self.shopkeeperSubline and self.shopkeeperSubline ~= "" then
		love.graphics.setFont(UI.fonts.small)
		love.graphics.setColor(1, 1, 1, 0.7)
		love.graphics.printf(self.shopkeeperSubline, textAreaX, currentY, textAreaWidth, "center")
		currentY = currentY + advanceY(self.shopkeeperSubline, UI.fonts.small, 18)
	end

	love.graphics.setColor(1, 1, 1, 1)
	local headerBottom = currentY

	local selectionOverlay = self.selectionProgress or 0
	if selectionOverlay > 0 then
		local overlayEase = selectionOverlay * selectionOverlay * (3 - 2 * selectionOverlay)
		love.graphics.setColor(0, 0, 0, 0.35 * overlayEase)
		love.graphics.rectangle("fill", 0, 0, screenW, screenH)
		love.graphics.setColor(1, 1, 1, 1)
	end

	local cardCount = #self.cards
	local cardWidth, cardHeight = 264, 344
	local baseSpacing = 48
	local minSpacing = 28
	local marginX = math.max(60, screenW * 0.05)
	local availableWidth = math.max(cardWidth, screenW - marginX * 2)
	local columns = math.min(cardCount, math.max(1, math.floor((availableWidth + minSpacing) / (cardWidth + minSpacing))))

	while columns > 1 do
		local widthNeeded = columns * cardWidth + (columns - 1) * minSpacing
		if widthNeeded <= availableWidth then
			break
		end
		columns = columns - 1
	end

	columns = math.max(1, columns)
	local rows = math.max(1, math.ceil(cardCount / columns))

	local spacing = 0
	if columns > 1 then
		local calculated = (availableWidth - columns * cardWidth) / (columns - 1)
		spacing = math.max(minSpacing, math.min(baseSpacing, calculated))
	end

	local totalWidth = columns * cardWidth + math.max(0, (columns - 1)) * spacing
	local startX = (screenW - totalWidth) / 2

	local rowSpacing = 72
	local minRowSpacing = 40
	local bottomPadding = screenH * 0.12
	local minTopPadding = screenH * 0.24
	local topPadding = math.max(minTopPadding, headerBottom + 24)
	local availableHeight = screenH - topPadding - bottomPadding
	if availableHeight < 0 then
		local reduction = math.min(topPadding - minTopPadding, -availableHeight)
		if reduction > 0 then
			topPadding = topPadding - reduction
		end
		availableHeight = math.max(0, screenH - topPadding - bottomPadding)
	end
	local totalHeight = rows * cardHeight + math.max(0, (rows - 1)) * rowSpacing
	if rows > 1 and totalHeight > availableHeight then
		local adjustableRows = rows - 1
		if adjustableRows > 0 then
			local excess = totalHeight - availableHeight
			local reduction = excess / adjustableRows
			rowSpacing = math.max(minRowSpacing, rowSpacing - reduction)
			totalHeight = rows * cardHeight + math.max(0, (rows - 1)) * rowSpacing
		end
	end

	local preferredTop = screenH * 0.34
	local centeredTop = (screenH - totalHeight) / 2
	local startY = math.max(topPadding, math.min(preferredTop, centeredTop))
	local layoutCenterY = startY + totalHeight / 2

	local mx, my = love.mouse.getPosition()

	local function renderCard(i, card)
		local columnIndex = ((i - 1) % columns)
		local rowIndex = math.floor((i - 1) / columns)
		local baseX = startX + columnIndex * (cardWidth + spacing)
		local baseY = startY + rowIndex * (cardHeight + rowSpacing)
		local alpha = 1
		local scale = 1
		local yOffset = 0
		local state = self.cardStates and self.cardStates[i]
		if state then
			local progress = state.progress or 0
			local eased = progress * progress * (3 - 2 * progress)
			alpha = eased
			yOffset = (1 - eased) * 48

			-- Start cards a touch smaller and ease them up to full size so
			-- the reveal animation feels like a gentle pop rather than a flat fade.
			local appearScaleMin = 0.94
			local appearScaleMax = 1.0
			scale = appearScaleMin + (appearScaleMax - appearScaleMin) * eased

			local hover = state.hover or 0
			if hover > 0 and not self.selected then
				local hoverEase = hover * hover * (3 - 2 * hover)
				scale = scale * (1 + 0.07 * hoverEase)
				yOffset = yOffset - 8 * hoverEase
			end

			local selection = state.selection or 0
			if selection > 0 then
				local pulse = 1 + 0.05 * math.sin((state.selectionClock or 0) * 8)
				scale = scale * (1 + 0.08 * selection) * pulse
				alpha = math.min(1, alpha * (1 + 0.2 * selection))
			end
		end

		local focus = state and state.focus or 0
		local fadeOut = state and state.fadeOut or 0
		local focusEase = focus * focus * (3 - 2 * focus)
		local fadeEase = fadeOut * fadeOut * (3 - 2 * fadeOut)
		local discardData = (state and state.discardActive and state.discard and self.restocking) and state.discard or nil
		local discardOffsetX, discardOffsetY, discardRotation = 0, 0, 0
		if discardData then
			local fadeT = math.max(0, math.min(1, fadeOut))
			local time = discardData.duration and discardData.duration > 0 and math.min(1, (discardData.clock or 0) / discardData.duration) or fadeT
			local discardEase = fadeT * fadeT * (3 - 2 * fadeT)
			local motionEase = time * time * (3 - 2 * time)
			local dropEase = discardEase * discardEase
			local swayClock = (discardData.clock or 0) * (discardData.swaySpeed or 3.2)
			local sway = math.sin(swayClock) * (discardData.swayMagnitude or 14) * (1 - motionEase)
			discardOffsetX = ((discardData.horizontalDistance or 0) * motionEase) + sway * (discardData.direction or 1)
			local dropDistance = discardData.dropDistance or 0
			local arcHeight = discardData.arcHeight or 0
			discardOffsetY = dropDistance * dropEase - arcHeight * (1 - motionEase)
			discardRotation = (discardData.rotation or 0) * dropEase
			scale = scale * (1 - 0.12 * discardEase)
			alpha = alpha * (1 - 0.7 * discardEase)
		end

		if card == self.selected then
			yOffset = yOffset + 46 * focusEase
			scale = scale * (1 + 0.35 * focusEase)
			alpha = math.min(1, alpha * (1 + 0.6 * focusEase))
			-- Make sure the selected card renders at full opacity while it
			-- animates toward the center. Without this clamp the focus easing
			-- could leave it slightly translucent until the animation fully
			-- completes, which felt like a bug. Forcing alpha to 1 keeps the
			-- spotlighted card crisp for the whole animation.
			alpha = 1
		else
			if discardData then
				scale = scale * (1 - 0.05 * fadeEase)
				alpha = alpha * (1 - 0.55 * fadeEase)
			else
				yOffset = yOffset - 32 * fadeEase
				scale = scale * (1 - 0.2 * fadeEase)
				alpha = alpha * (1 - 0.9 * fadeEase)
			end
		end

		alpha = math.max(0, math.min(alpha, 1))

		local centerX = baseX + cardWidth / 2
		local centerY = baseY + cardHeight / 2 - yOffset
		local originalCenterX, originalCenterY = centerX, centerY

		if card == self.selected then
			centerX = centerX + (screenW / 2 - centerX) * focusEase
			local targetY = layoutCenterY
			centerY = centerY + (targetY - centerY) * focusEase
		else
			if discardData then
				centerX = centerX + discardOffsetX
				centerY = centerY + discardOffsetY
			else
				centerY = centerY + 28 * fadeEase
			end
		end

		local drawWidth = cardWidth * scale
		local drawHeight = cardHeight * scale
		local drawX = centerX - drawWidth / 2
		local drawY = centerY - drawHeight / 2

		local usingFocusNavigation = self.inputMode == "gamepad" or self.inputMode == "keyboard"
		local mouseHover = mx >= drawX and mx <= drawX + drawWidth
			and my >= drawY and my <= drawY + drawHeight
		if not self.selected and mouseHover and not usingFocusNavigation then
			self:setFocus(i)
		end

		local hovered = not self.selected and (
			(usingFocusNavigation and self.focusIndex == i) or
			(not usingFocusNavigation and mouseHover)
		)

		love.graphics.push()
		love.graphics.translate(centerX, centerY)
		if discardRotation ~= 0 then
			love.graphics.rotate(discardRotation)
		end
		love.graphics.scale(scale, scale)
		love.graphics.translate(-cardWidth / 2, -cardHeight / 2)
		local appearanceAlpha = self.selected == card and 1 or alpha
		drawCard(card, 0, 0, cardWidth, cardHeight, hovered, i, nil, self.selected == card, appearanceAlpha)
		love.graphics.pop()
		card.bounds = { x = drawX, y = drawY, w = drawWidth, h = drawHeight }

		if state and state.selectionFlash then
			local flashDuration = 0.75
			local t = math.max(0, math.min(1, state.selectionFlash / flashDuration))
			local ease = 1 - ((1 - t) * (1 - t))
			local ringAlpha = (1 - ease) * 0.8
			local burstAlpha = (1 - ease) * 0.45
			local radiusBase = math.max(cardWidth, cardHeight) * 0.42
			local radius = radiusBase + ease * 180

			love.graphics.setLineWidth(6)
			love.graphics.setColor(1, 0.88, 0.45, ringAlpha)
			love.graphics.circle("line", centerX, centerY, radius)

			local burstRadius = radiusBase * (1 + ease * 0.5)
			love.graphics.setColor(1, 0.72, 0.32, burstAlpha)
			love.graphics.circle("fill", centerX, centerY, burstRadius)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end

	local selectedIndex
	for i, card in ipairs(self.cards) do
		if card == self.selected then
			selectedIndex = i
		else
			renderCard(i, card)
		end
	end

	if selectedIndex then
		renderCard(selectedIndex, self.cards[selectedIndex])
	end

	if self.selected then
		love.graphics.setFont(UI.fonts.button)
		love.graphics.setColor(1, 0.88, 0.6, 0.9)
		love.graphics.printf(
			string.format("%s claimed", self.selected.name or "Relic"),
			0,
			screenH * 0.87,
			screenW,
			"center"
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function pickIndexFromKey(key)
	if key == "1" or key == "kp1" then return 1 end
	if key == "2" or key == "kp2" then return 2 end
	if key == "3" or key == "kp3" then return 3 end
	if key == "4" or key == "kp4" then return 4 end
	if key == "5" or key == "kp5" then return 5 end
end

function Shop:keypressed(key)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	local index = pickIndexFromKey(key)
	if index then
		self.inputMode = "keyboard"
		return self:pick(index)
	end

	if self.selected then return end

	if key == "left" or key == "up" then
		self.inputMode = "keyboard"
		self:moveFocus(-1)
		return true
	elseif key == "right" or key == "down" then
		self.inputMode = "keyboard"
		self:moveFocus(1)
		return true
	elseif key == "return" or key == "kpenter" or key == "enter" then
		self.inputMode = "keyboard"
		local focusIndex = self.focusIndex or 1
		return self:pick(focusIndex)
	end
end

function Shop:mousepressed(x, y, button)
	if self.restocking then return end
	if button ~= 1 then return end
	self.inputMode = "mouse"
	for i, card in ipairs(self.cards) do
		local b = card.bounds
		if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
			self:setFocus(i)
			return self:pick(i)
		end
	end
end

function Shop:gamepadpressed(_, button)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	self.inputMode = "gamepad"

	if self.selected then return end

	if button == "dpup" or button == "dpleft" then
		self:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		self:moveFocus(1)
	elseif button == "a" or button == "start" then
		local index = self.focusIndex or 1
		return self:pick(index)
	end
end

Shop.joystickpressed = Shop.gamepadpressed

function Shop:gamepadaxis(_, axis, value)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	handleAnalogAxis(self, axis, value)
end

Shop.joystickaxis = Shop.gamepadaxis

function Shop:pick(i)
	if self.restocking then return false end
	if self.selected then return false end
	local card = self.cards[i]
	if not card then return false end

	if card.restockShop then
		Audio:playSound("shop_card_select")
		self:beginRestock()
		return true
	end

	Upgrades:acquire(card, { floor = self.floor })
	self.selected = card
	self.selectedIndex = i
	self.selectionTimer = 0
	self.selectionComplete = false

	local state = self.cardStates and self.cardStates[i]
	if state then
		state.selectionFlash = 0
		state.selectSoundPlayed = true
	end
	Audio:playSound("shop_card_select")
	return true
end

function Shop:isSelectionComplete()
	return self.selected ~= nil and self.selectionComplete == true
end

return Shop
