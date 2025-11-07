local UI = require("ui")
local Localization = require("localization")
local Upgrades = require("upgrades")
local Audio = require("audio")
local MetaProgression = require("metaprogression")
local Theme = require("theme")
local Shaders = require("shaders")
local Floors = require("floors")
local Timer = require("timer")
local abs = math.abs
local ceil = math.ceil
local cos = math.cos
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local acos = math.acos
local sin = math.sin
local tan = math.tan
local sqrt = math.sqrt
local atan = math.atan
local atan2 = math.atan2
local unpack = unpack

local Shop = {}

local DEFAULT_CARD_WIDTH, DEFAULT_CARD_HEIGHT = 264, 344

Shop._backgroundCanvases = Shop._backgroundCanvases or {}

local getBackgroundCacheKey
local ensureBackgroundCanvas
local getBadgeStyleForCard

local rarityBorderAlpha
local rarityStyles

local applyColor
local withTransformedScissor

local function getLocalizationRevision()
	if Localization and Localization.getRevision then
		return Localization:getRevision()
	end

	return 0
end

local function ensureCardTextLayout(card, width)
	if not card then return nil end

	local revision = getLocalizationRevision()
	local name = card.name or ""
	local desc = card.desc or ""
	local cache = card._textLayoutCache

	if not cache or cache.revision ~= revision or cache.name ~= name or cache.desc ~= desc then
		cache = {
			revision = revision,
			name = name,
			desc = desc,
			byWidth = {},
		}
		card._textLayoutCache = cache
	end

	local w = width or DEFAULT_CARD_WIDTH
	local layout = cache.byWidth[w]
	if layout then
		return layout
	end

	local titleFont = UI.fonts.button or UI.fonts.body
	local bodyFont = UI.fonts.body or UI.fonts.caption

	if not titleFont or not bodyFont then
		layout = cache.byWidth[w]
		if not layout then
			layout = {
				titleLines = {},
				titleLineCount = 1,
				titleHeight = 0,
				titleWidth = w - 28,
				descLines = {},
				descLineCount = 1,
				descHeight = 0,
				descWidth = w - 36,
			}
			cache.byWidth[w] = layout
		end
		return layout
	end

	local titleWidth = w - 28
	local descWidth = w - 36

	local _, titleLines = titleFont:getWrap(name, titleWidth)
	local titleLineCount = max(1, #titleLines)
	local titleLineHeight = titleFont:getHeight() * titleFont:getLineHeight()
	local titleHeight = titleLineCount * titleLineHeight

	local _, descLines = bodyFont:getWrap(desc, descWidth)
	local descLineCount = max(1, #descLines)
	local descLineHeight = bodyFont:getHeight() * bodyFont:getLineHeight()
	local descHeight = descLineCount * descLineHeight

	layout = {
		titleLines = titleLines,
		titleLineCount = titleLineCount,
		titleHeight = titleHeight,
		titleWidth = titleWidth,
		descLines = descLines,
		descLineCount = descLineCount,
		descHeight = descHeight,
		descWidth = descWidth,
	}
	cache.byWidth[w] = layout

	return layout
end

local ANALOG_DEADZONE = 0.3
local analogAxisDirections = {horizontal = nil, vertical = nil}

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

local MYSTERY_REVEAL_EXTRA_HOLD = 1.6
local MYSTERY_REVEAL_EXTRA_POST_PAUSE = 1.6

local function updateMysteryReveal(self, card, state, dt)
	if not dt or dt <= 0 then return end
	if not card or not state then return end

	local upgrade = card.upgrade
	if not upgrade or upgrade.id ~= "mystery_card" then
		return
	end

	local pending = card.pendingRevealInfo
	local reveal = state.mysteryReveal

	if not pending and not reveal then
		return
	end

	if pending and not reveal then
		reveal = {
			phase = "approach",
			timer = 0,
			white = 0,
			shakeOffset = 0,
			shakeRotation = 0,
			applied = false,
			info = pending,
			approachDuration = pending.revealApproachDuration or pending.revealDelay or 0.55,
			shakeDuration = pending.revealShakeDuration or 0.5,
			flashInDuration = pending.revealFlashInDuration or 0.22,
			flashOutDuration = pending.revealFlashOutDuration or 0.45,
			shakeMagnitude = pending.revealShakeMagnitude or 9,
			shakeFrequency = pending.revealShakeFrequency or 26,
			applyThreshold = pending.revealApplyThreshold or 0.6,
			postPauseDuration = (pending.revealPostPauseDuration or pending.revealPostPauseDelay or 0) + MYSTERY_REVEAL_EXTRA_POST_PAUSE,
			postPauseTimer = 0,
			focusBoost = 0,
		}
		state.mysteryReveal = reveal
		state.revealHoldTimer = nil
	else
		reveal = state.mysteryReveal
	end

	if not reveal then return end

	reveal.info = reveal.info or pending
	local info = reveal.info
	if not info then
		reveal.phase = reveal.phase or "done"
		return
	end

	reveal.timer = (reveal.timer or 0) + dt

	if reveal.phase == "approach" then
		reveal.white = 0
		reveal.shakeOffset = 0
		reveal.shakeRotation = 0
		local duration = reveal.approachDuration or 0
		if duration <= 0 then
			reveal.focusBoost = 1
			reveal.phase = "shake"
			reveal.timer = 0
		else
			local progress = min(1, reveal.timer / duration)
			local ease = progress * progress * (3 - 2 * progress)
			reveal.focusBoost = ease
			if reveal.timer >= duration then
				reveal.focusBoost = 1
				reveal.phase = "shake"
				reveal.timer = 0
			end
		end
		return
	end

	if reveal.phase == "shake" then
		local duration = reveal.shakeDuration or 0
		if duration <= 0 then
			reveal.phase = "flashIn"
			reveal.timer = 0
			reveal.shakeOffset = 0
			reveal.shakeRotation = 0
			reveal.focusBoost = 1
		else
			local progress = min(1, reveal.timer / duration)
			local amplitude = (1 - progress) * (reveal.shakeMagnitude or 8)
			local frequency = reveal.shakeFrequency or 24
			reveal.shakeOffset = sin(reveal.timer * frequency) * amplitude
			reveal.shakeRotation = sin(reveal.timer * frequency * 0.55) * amplitude * 0.02
			if reveal.timer >= duration then
				reveal.phase = "flashIn"
				reveal.timer = 0
				reveal.shakeOffset = 0
				reveal.shakeRotation = 0
				reveal.focusBoost = 1
			end
		end
		return
	end

	if reveal.phase == "flashIn" then
		local duration = reveal.flashInDuration or 0
		local progress = duration <= 0 and 1 or min(1, reveal.timer / duration)
		reveal.white = progress
		reveal.focusBoost = 1
		if not reveal.applied and (duration <= 0 or reveal.timer >= duration * (reveal.applyThreshold or 0.6)) then
			Upgrades:applyCardReveal(card, info)
			reveal.applied = true
		end
		if duration <= 0 or reveal.timer >= duration then
			reveal.phase = "flashOut"
			reveal.timer = 0
		end
		return
	end

	if reveal.phase == "flashOut" then
		local duration = reveal.flashOutDuration or 0
		if duration <= 0 then
			reveal.white = 0
			reveal.focusBoost = 1
			if (reveal.postPauseDuration or 0) > 0 then
				reveal.phase = "postPause"
				reveal.timer = 0
				reveal.postPauseTimer = 0
			else
				reveal.phase = "done"
				reveal.timer = 0
			end
		else
			local progress = min(1, reveal.timer / duration)
			reveal.white = 1 - progress
			if reveal.timer >= duration then
				reveal.white = 0
				reveal.focusBoost = 1
				if (reveal.postPauseDuration or 0) > 0 then
					reveal.phase = "postPause"
					reveal.timer = 0
					reveal.postPauseTimer = 0
				else
					reveal.phase = "done"
					reveal.timer = 0
				end
			end
		end
		reveal.shakeOffset = 0
		reveal.shakeRotation = 0
		return
	end

	if reveal.phase == "postPause" then
		reveal.white = 0
		reveal.shakeOffset = 0
		reveal.shakeRotation = 0
		reveal.focusBoost = 1
		local duration = reveal.postPauseDuration or 0
		if duration <= 0 then
			reveal.phase = "done"
			reveal.timer = 0
			return
		end

		reveal.postPauseTimer = (reveal.postPauseTimer or 0) + dt
		if reveal.postPauseTimer >= duration then
			reveal.phase = "done"
			reveal.timer = 0
		end
		return
	end

	if reveal.phase == "done" then
		reveal.white = 0
		reveal.shakeOffset = 0
		reveal.shakeRotation = 0
		if reveal.focusBoost then
			reveal.focusBoost = max(0, reveal.focusBoost - dt * 2.6)
			if reveal.focusBoost <= 0.001 then
				reveal.focusBoost = 0
			end
		end
	end
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
		upgradeBonus = max(0, floor(Upgrades:getEffect("shopSlots") or 0))
	end

	local metaBonus = 0
	if MetaProgression and MetaProgression.getShopBonusSlots then
		metaBonus = max(0, MetaProgression:getShopBonusSlots() or 0)
	end

	local extraChoices = upgradeBonus + metaBonus

	self.baseChoices = baseChoices
	self.upgradeBonusChoices = upgradeBonus
	self.metaBonusChoices = metaBonus
	self.extraChoices = extraChoices

	local cardCount = baseChoices + extraChoices
	self.totalChoices = cardCount
	self.cards = Upgrades:getRandom(cardCount, {floor = self.floor}) or {}
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
		local card = self.cards[i]
		local style = rarityStyles[card.rarity or "common"] or rarityStyles.common
		local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
		local backgroundKey = getBackgroundCacheKey(card, style, borderColor, DEFAULT_CARD_WIDTH, DEFAULT_CARD_HEIGHT)
		ensureBackgroundCanvas(backgroundKey, style, borderColor, DEFAULT_CARD_WIDTH, DEFAULT_CARD_HEIGHT)
		ensureCardTextLayout(card, DEFAULT_CARD_WIDTH)

		-- Cache badge visuals here so `drawCard` can avoid recalculating them every frame.
		-- Any code that mutates a card's upgrade/tags must call `Shop:refreshCards` (or
		-- otherwise refresh this cache) before the card is rendered again.
		local badgeStyle = getBadgeStyleForCard(card)
		card._badgeStyle = badgeStyle

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
			mysteryReveal = nil,
			revealHoldTimer = nil,
			backgroundKey = backgroundKey,
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
				restock.progress = min(1, restock.timer / duration)
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
				self:refreshCards({initialDelay = revealDelay})
				return
			end
		end
	end

	self.selectionProgress = self.selectionProgress or 0
	if self.selected then
		self.selectionProgress = min(1, self.selectionProgress + dt * 2.4)
	else
		self.selectionProgress = max(0, self.selectionProgress - dt * 3)
	end

	for i, state in ipairs(self.cardStates) do
		if self.time >= state.delay and state.progress < 1 then
			state.progress = min(1, state.progress + dt * 3.2)
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
			state.selection = min(1, (state.selection or 0) + dt * 4)
			state.selectionClock = (state.selectionClock or 0) + dt
			state.focus = min(1, (state.focus or 0) + dt * 3)
			state.fadeOut = max(0, (state.fadeOut or 0) - dt * 4)
			state.hover = max(0, (state.hover or 0) - dt * 6)
			if not state.selectSoundPlayed then
				state.selectSoundPlayed = true
				Audio:playSound("shop_card_select")
			end
		else
			state.selection = max(0, (state.selection or 0) - dt * 3)
			if state.selection <= 0.001 then
				state.selectionClock = 0
			else
				state.selectionClock = (state.selectionClock or 0) + dt
			end
			if isFocused and not restock then
				state.hover = min(1, (state.hover or 0) + dt * 6)
			else
				state.hover = max(0, (state.hover or 0) - dt * 4)
			end
			if restock then
				local fadeTarget = restockProgress or 0
				state.fadeOut = max(fadeTarget, min(1, (state.fadeOut or 0) + dt * 3.2))
				state.focus = max(0, (state.focus or 0) - dt * 4)
			elseif self.selected then
				state.fadeOut = min(1, (state.fadeOut or 0) + dt * 3.2)
				state.focus = max(0, (state.focus or 0) - dt * 4)
			else
				state.fadeOut = max(0, (state.fadeOut or 0) - dt * 3)
				state.focus = max(0, (state.focus or 0) - dt * 3)
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

		if card and card.upgrade and card.upgrade.id == "mystery_card" then
			updateMysteryReveal(self, card, state, dt)
		end
	end

	if self.selected then
		self.selectionTimer = (self.selectionTimer or 0) + dt
		if not self.selectionComplete then
			local hold = self.selectionHoldDuration or 0
			local state = self.selectedIndex and self.cardStates and self.cardStates[self.selectedIndex] or nil
			local flashDone = not (state and state.selectionFlash)
			local revealDone = true
			if self.selected and self.selected.upgrade and self.selected.upgrade.id == "mystery_card" then
				local revealState = state and state.mysteryReveal or nil
				if self.selected.pendingRevealInfo then
					revealDone = false
					if state then
						state.revealHoldTimer = nil
					end
				elseif revealState then
					local phase = revealState.phase
					local overlayAlpha = revealState.white or 0
					if phase and phase ~= "done" then
						revealDone = false
						if state then
							state.revealHoldTimer = nil
						end
					elseif overlayAlpha > 0.001 then
						revealDone = false
						if state then
							state.revealHoldTimer = nil
						end
					else
						if state then
							state.revealHoldTimer = (state.revealHoldTimer or 0) + dt
							if state.revealHoldTimer < MYSTERY_REVEAL_EXTRA_HOLD then
								revealDone = false
							end
						end
					end
				elseif state then
					state.revealHoldTimer = nil
				end
			end
			if self.selectionTimer >= hold and flashDone and revealDone then
				self.selectionComplete = true
				Audio:playSound("shop_purchase")
			end
		end
	else
		if self.selectedIndex and self.cardStates then
			local previousState = self.cardStates[self.selectedIndex]
			if previousState then
				previousState.revealHoldTimer = nil
			end
		end
		self.selectionTimer = 0
		self.selectionComplete = false
		self.selectedIndex = nil
	end
end

rarityBorderAlpha = 0.85

rarityStyles = {
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
			color = {1.0, 0.92, 0.64, 0.22},
			radius = 9,
			speed = 1.8,
			driftSpeed = 0.08,
			driftMinY = 0.16,
			driftMaxY = 0.98,
			positions = {
				{0.22, 0.88, 1.05, 0.00},
				{0.52, 0.78, 0.85, 0.28},
				{0.72, 0.94, 1.15, 0.56},
				{0.36, 0.82, 0.9, 0.84},
			},
		},
		glow = 0.22,
		borderWidth = 5,
	},
}

local function clamp01(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end

	return value
end

local function wrap01(value)
	value = value - floor(value)
	if value < 0 then
		value = value + 1
	end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function scaleColor(color, factor, alphaFactor)
	if not color then
		return {1, 1, 1, alphaFactor or 1}
	end

	local alpha = (color[4] or 1) * (alphaFactor or 1)
	return {
		clamp01((color[1] or 0) * factor),
		clamp01((color[2] or 0) * factor),
		clamp01((color[3] or 0) * factor),
		alpha,
	}
end

local function formatColorKey(color)
	if not color then
		return "nil"
	end

	return string.format(
	"%.3f,%.3f,%.3f,%.3f",
	color[1] or 0,
	color[2] or 0,
	color[3] or 0,
	color[4] or 1
	)
end

getBackgroundCacheKey = function(card, style, borderColor, w, h)
	local rarity = card and (card.rarity or "common") or "common"
	local styleKey = style and tostring(style) or "default"
	local sizeKey = string.format("%sx%s", tostring(w or 0), tostring(h or 0))
	local colorKey = formatColorKey(borderColor)
	return table.concat({rarity, styleKey, sizeKey, colorKey}, "|")
end

local function drawStaticStyleLayers(style, borderColor, x, y, w, h, alphaMultiplier)
	if not style then return end

	local cardRadius = 12

	local function setColor(r, g, b, a)
		love.graphics.setColor(r, g, b, (a or 1) * (alphaMultiplier or 1))
	end

	local function drawGradientOverlay(def)
		if not def or not def.top or not def.bottom then
			return
		end

		local steps = max(1, def.steps or 16)
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, w, h, cardRadius, cardRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)
		local segmentHeight = h / steps
		local topAlpha = def.top[4] or 1
		local bottomAlpha = def.bottom[4] or 1
		for i = 0, steps - 1 do
			local t = steps == 1 and 0 or i / (steps - 1)
			local r = lerp(def.top[1] or 0, def.bottom[1] or 0, t)
			local g = lerp(def.top[2] or 0, def.bottom[2] or 0, t)
			local b = lerp(def.top[3] or 0, def.bottom[3] or 0, t)
			local a = lerp(topAlpha, bottomAlpha, t)
			setColor(r, g, b, a)
			love.graphics.rectangle("fill", x, y + i * segmentHeight, w, segmentHeight + 1)
		end
		love.graphics.setStencilTest()
		setColor(1, 1, 1, 1)
	end

	local function drawShineOverlay(def)
		if not def then
			return
		end

		local steps = max(1, def.steps or 18)
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, w, h, cardRadius, cardRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)
		love.graphics.push()
		love.graphics.translate(x + w * (def.offsetX or 0.5), y + h * (def.offsetY or 0.3))
		love.graphics.rotate(def.angle or -pi / 5)
		local shineWidth = w * (def.widthScale or 1.4)
		local shineHeight = h * (def.heightScale or 0.6)
		local stepWidth = shineWidth / steps
		for i = 0, steps - 1 do
			local center = -shineWidth / 2 + (i + 0.5) * stepWidth
			local normalized = (i + 0.5) / steps * 2 - 1
			local strength = max(0, 1 - normalized * normalized)
			if strength > 0 then
				setColor(1, 1, 1, (def.alpha or 0.24) * strength)
				love.graphics.rectangle("fill", center - stepWidth / 2, -shineHeight / 2, stepWidth + 1, shineHeight)
			end
		end
		love.graphics.pop()
		love.graphics.setStencilTest()
		setColor(1, 1, 1, 1)
	end

	drawGradientOverlay(style.gradient)
	drawShineOverlay(style.shine)

	if style.aura then
		withTransformedScissor(x, y, w, h, function()
			applyColor(setColor, style.aura.color)
			local radius = max(w, h) * (style.aura.radius or 0.72)
			local centerY = y + h * (style.aura.y or 0.4)
			love.graphics.circle("fill", x + w * 0.5, centerY, radius)
		end)
	end

	if style.flare then
		withTransformedScissor(x, y, w, h, function()
			applyColor(setColor, style.flare.color)
			local radius = min(w, h) * (style.flare.radius or 0.36)
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
			local stripeCount = ceil((diag * 2) / spacing) + 2
			for i = -stripeCount, stripeCount do
				local pos = i * spacing
				love.graphics.rectangle("fill", -diag, pos - width / 2, diag * 2, width)
			end
			love.graphics.pop()
		end)
	end

	if style.sparkles and style.sparkles.positions then
		withTransformedScissor(x, y, w, h, function()
			local driftSpeed = style.sparkles.driftSpeed or 0
			local driftMinY = style.sparkles.driftMinY or 0
			local driftMaxY = style.sparkles.driftMaxY or 1
			local driftSpan = max(0.0001, driftMaxY - driftMinY)
			for i, pos in ipairs(style.sparkles.positions) do
				local px = pos[1] or 0.5
				local py = pos[2] or 0.5
				local scale = pos[3] or 1
				local phase = pos[4] or (i - 1) * 0.31
				local pulse = 0.6 + 0.4 * sin(i * 0.9)
				local radius = (style.sparkles.radius or 9) * scale * pulse
				local sparkleColor = style.sparkles.color or borderColor
				local sparkleAlphaBase = style.sparkles.opacity or sparkleColor[4] or 1
				local sparkleAlpha = sparkleAlphaBase * pulse
				local sparkleX = x + px * w
				local sparkleY
				if driftSpeed ~= 0 then
					local normalized = wrap01(py - phase)
					sparkleY = y + (driftMinY + normalized * driftSpan) * h
				else
					sparkleY = y + py * h
				end
				applyColor(setColor, sparkleColor, sparkleAlpha)
				love.graphics.circle("fill", sparkleX, sparkleY, radius)
			end
		end)
	end

	setColor(1, 1, 1, 1)
end

ensureBackgroundCanvas = function(styleKey, style, borderColor, w, h)
	local cache = Shop._backgroundCanvases
	local entry = cache and cache[styleKey]
	if entry and entry.width == w and entry.height == h then
		return entry.canvas
	end

	if not cache then
		Shop._backgroundCanvases = {}
		cache = Shop._backgroundCanvases
	end

	if w <= 0 or h <= 0 then
		return nil
	end

	local canvas = love.graphics.newCanvas(w, h)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	drawStaticStyleLayers(style, borderColor, 0, 0, w, h)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.pop()

	cache[styleKey] = {canvas = canvas, width = w, height = h}
	return canvas
end

local function getBackgroundCanvas(styleKey)
	local cache = Shop._backgroundCanvases
	if not cache then return nil end
	local entry = cache[styleKey]
	return entry and entry.canvas or nil
end

local badgeDefinitions = {
	default = {
		label = "General",
		shape = "circle",
		fallback = {0.66, 0.72, 0.9, 1},
		outlineFactor = 0.52,
		shadowAlpha = 0.65,
	},
	economy = {
		label = "Economy",
		shape = "circle",
		colorKey = "goldenPearColor",
		fallback = {0.95, 0.80, 0.45, 1},
		outlineFactor = 0.42,
	},
	defense = {
		label = "Defense",
		shape = "diamond",
		colorKey = "snakeDefault",
		fallback = {0.45, 0.85, 0.70, 1},
		cornerRadiusScale = 0.18,
		cornerSegments = 4,
	},
	mobility = {
		label = "Mobility",
		shape = "triangle_up",
		colorKey = "blueberryColor",
		fallback = {0.55, 0.65, 0.95, 1},
		cornerRadiusScale = 0.15,
		cornerSegments = 3,
	},
	risk = {
		label = "Risk",
		shape = "triangle_down",
		colorKey = "warningColor",
		fallback = {0.92, 0.55, 0.40, 1},
		cornerRadiusScale = 0.15,
		cornerSegments = 3,
	},
	utility = {
		label = "Utility",
		shape = "square",
		colorKey = "panelBorder",
		fallback = {0.32, 0.50, 0.54, 1},
		cornerRadiusScale = 0.2,
		cornerSegments = 4,
	},
	hazard = {
		label = "Hazard",
		shape = "hexagon",
		colorKey = "appleColor",
		fallback = {0.90, 0.45, 0.55, 1},
		cornerRadiusScale = 0.12,
		cornerSegments = 5,
	},
}

local badgeTagAliases = {
	adrenaline = "mobility",
	speed = "mobility",
	rocks = "hazard",
	shop = "economy",
	progression = "economy",
	reward = "economy",
	combo = "risk",
	control = "utility",
}

local resolvedBadgeStyles = setmetatable({}, {__mode = "k"})

local function resolveBadgeDefinition(definition)
	if not definition then return nil end

	local resolved = resolvedBadgeStyles[definition]
	if not resolved then
		resolved = {color = {1, 1, 1, 1}}
		resolvedBadgeStyles[definition] = resolved
	end

	local colorSource
	if definition.colorKey and Theme[definition.colorKey] then
		colorSource = Theme[definition.colorKey]
	elseif definition.color then
		colorSource = definition.color
	end

	local fallback = definition.fallback or {1, 1, 1, 1}
	colorSource = colorSource or fallback

	local color = resolved.color
	color[1] = colorSource[1] or fallback[1] or 1
	color[2] = colorSource[2] or fallback[2] or 1
	color[3] = colorSource[3] or fallback[3] or 1
	color[4] = colorSource[4] or fallback[4] or 1

	resolved.shape = definition.shape or "circle"
	resolved.outlineFactor = definition.outlineFactor
	resolved.outline = definition.outline
	resolved.shadowOffset = definition.shadowOffset
	resolved.shadowAlpha = definition.shadowAlpha
	resolved.shadow = definition.shadow
	resolved.cornerRadius = definition.cornerRadius
	resolved.cornerRadiusScale = definition.cornerRadiusScale
	resolved.cornerSegments = definition.cornerSegments
	resolved.radiusScale = definition.radiusScale

	return resolved
end

getBadgeStyleForCard = function(card)
	if not card or not card.upgrade then
		return nil
	end

	local tags = card.upgrade.tags
	if type(tags) ~= "table" then
		return nil
	end

	local hasTag = false
	for _, tag in ipairs(tags) do
		hasTag = true
		local canonicalTag = badgeTagAliases[tag] or tag
		local definition = badgeDefinitions[canonicalTag]
		if definition then
			local style = resolveBadgeDefinition(definition)
			local label = definition.label or canonicalTag
			return style, label
		end
	end

	if hasTag and badgeDefinitions.default then
		local definition = badgeDefinitions.default
		local style = resolveBadgeDefinition(definition)
		local label = definition.label or "default"
		return style, label
	end

	return nil
end

local function drawRoundedRegularPolygon(mode, cx, cy, R, sides, cr, segs, rot)
    segs = math.max(2, segs or 4)
    rot  = rot or 0
    local pi, cos, sin, atan2 = math.pi, math.cos, math.sin, math.atan2
    local TWO_PI = 2 * pi

    -- Interior angle and half-angle for a regular n-gon
    local interior = pi - TWO_PI / sides
    local half     = interior / 2

    -- Distance from the vertex to the tangent point along each edge
    -- t = r * cot(α/2)  and  cot(x) = 1 / tan(x)
    local function cot(x) return 1 / math.tan(x) end
    local t = cr * cot(half)

    -- Distance from vertex inward along the angle bisector to the arc center
    -- m = r / sin(α/2)
    local m = cr / math.sin(half)

    -- Precompute the raw (unrounded) vertices
    local V = {}
    for i = 0, sides - 1 do
        local a = rot + (TWO_PI * i / sides) - pi/2 -- start with a vertex "up"
        V[i] = { cx + R * cos(a), cy + R * sin(a) }
    end

    -- Build the final flattened point list, walking CCW
    local points = {}
    local function norm(dx, dy)
        local len = math.sqrt(dx*dx + dy*dy)
        return dx/len, dy/len
    end

    for i = 0, sides - 1 do
        local vp   = V[(i - 1) % sides]
        local v    = V[i]
        local vn   = V[(i + 1) % sides]

        -- Unit directions from vertex toward prev/next vertices
        local dpx, dpy = norm(vp[1] - v[1], vp[2] - v[2])
        local dnx, dny = norm(vn[1] - v[1], vn[2] - v[2])

        -- Tangency points on each adjacent edge
        local T1x, T1y = v[1] + dpx * t, v[2] + dpy * t
        local T2x, T2y = v[1] + dnx * t, v[2] + dny * t

        -- Inward bisector (sum of unit directions), then normalize
        local bx, by = dpx + dnx, dpy + dny
        bx, by = norm(bx, by)

        -- Arc center is along the inward bisector
        local Cx, Cy = v[1] + bx * m, v[2] + by * m

        -- Arc angles from center to each tangency point
        local a1 = atan2(T1y - Cy, T1x - Cx)
        local a2 = atan2(T2y - Cy, T2x - Cx)

        -- Ensure we sweep the shorter CCW arc from a1 to a2
        -- (adjust for wrapping so it marches forward CCW)
        while a2 < a1 do a2 = a2 + TWO_PI end

        -- Add the first tangency point (connects from previous corner)
        table.insert(points, T1x); table.insert(points, T1y)

        -- Sample the rounded corner arc
        for s = 1, segs - 1 do
            local u = s / segs
            local aa = a1 + (a2 - a1) * u
            table.insert(points, Cx + cr * math.cos(aa))
            table.insert(points, Cy + cr * math.sin(aa))
        end

        -- The second tangency point will be added as the first point of the next corner
        -- (so we avoid duplicates); it will appear when i+1 is processed as T1.
        -- For the last corner, we'll close the polygon automatically.
        if i == sides - 1 then
            -- Close by explicitly adding the very last tangency point
            table.insert(points, T2x); table.insert(points, T2y)
        end
    end

    love.graphics.polygon(mode, points)
end

local badgeShapeDrawers = {
	circle = function(mode, cx, cy, size)
		love.graphics.circle(mode, cx, cy, size * 0.5, 32)
	end,
	square = function(mode, cx, cy, size, style)
		local R  = size * 0.50
		local cr = size * 0.08
		local segs = 4
		drawRoundedRegularPolygon(mode, cx, cy, R, 4, cr, segs, 0)
	end,
	diamond = function(mode, cx, cy, size, style)
		local R  = size * 0.50
		local cr = size * 0.08
		local segs = 4
		drawRoundedRegularPolygon(mode, cx, cy, R, 4, cr, segs, math.pi/4)
	end,
	triangle_up = function(mode, cx, cy, size, style)
		local R  = size * 0.52
		local cr = size * 0.08
		local segs = 4
		drawRoundedRegularPolygon(mode, cx, cy, R, 3, cr, segs, 0)
	end,
	triangle_down = function(mode, cx, cy, size, style)
		local R  = size * 0.52
		local cr = size * 0.08
		local segs = 4
		drawRoundedRegularPolygon(mode, cx, cy, R, 3, cr, segs, math.pi)
	end,
	hexagon = function(mode, cx, cy, size, style)
		local R  = size * 0.50
		local cr = size * 0.08
		local segs = 4
		drawRoundedRegularPolygon(mode, cx, cy, R, 6, cr, segs, 0)
	end,
}

local function drawBadgeShape(shape, mode, cx, cy, size, style)
	local drawer = badgeShapeDrawers[shape] or badgeShapeDrawers.circle
	drawer(mode, cx, cy, size, style)
end

local function drawBadge(setColorFn, style, cx, cy, size)
	if not style or not style.color then
		return
	end

	local shape = style.shape or "circle"
	local fill = style.color
	local badgeOpacity = 0.10
	setColorFn(fill[1], fill[2], fill[3], (fill[4] or 1) * badgeOpacity)
	drawBadgeShape(shape, "fill", cx, cy, size, style)

	local outlineColor = style.outline or scaleColor(fill, style.outlineFactor or 0.55)
	local previousWidth = love.graphics.getLineWidth()
	love.graphics.setLineWidth(style.outlineWidth or 2)
	setColorFn(outlineColor[1], outlineColor[2], outlineColor[3], (outlineColor[4] or 1) * badgeOpacity)
	drawBadgeShape(shape, "line", cx, cy, size, style)
	love.graphics.setLineWidth(previousWidth)

	setColorFn(1, 1, 1, 1)
end

function applyColor(setColorFn, color, overrideAlpha)
	if not color then return end
	setColorFn(color[1], color[2], color[3], overrideAlpha or color[4] or 1)
end

function withTransformedScissor(x, y, w, h, fn)
	if not fn then return end

	local sx1, sy1 = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)

	local scissorX = min(sx1, sx2)
	local scissorY = min(sy1, sy2)
	local scissorW = abs(sx2 - sx1)
	local scissorH = abs(sy2 - sy1)

	if scissorW <= 0 or scissorH <= 0 then
		fn()
		return
	end

	local previous = {love.graphics.getScissor()}
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
	local wave = sin(time * def.speed + phase) * 0.5 + 0.5
	return minAlpha + (maxAlpha - minAlpha) * wave
end

local function drawCard(card, x, y, w, h, hovered, index, animationState, isSelected, appearanceAlpha)
	local fadeAlpha = appearanceAlpha or 1
	local function setColor(r, g, b, a)
		love.graphics.setColor(r, g, b, (a or 1) * fadeAlpha)
	end

	local style = rarityStyles[card.rarity or "common"] or rarityStyles.common
	local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
	local cardRadius = 12

	-- Signature drop shadow to give cards lift against the background
	local shadowOffsetX, shadowOffsetY = 8, 10
	setColor(0, 0, 0, 0.38)
	love.graphics.rectangle("fill", x + shadowOffsetX, y + shadowOffsetY, w, h, 18, 18)

	-- Consistent black outline that hugs the exterior of the card frame
	local outlineWidth = 6
	local outlineRadius = 16
	setColor(0, 0, 0, 1)
	love.graphics.rectangle("fill", x - outlineWidth, y - outlineWidth, w + outlineWidth * 2, h + outlineWidth * 2, outlineRadius, outlineRadius)
	love.graphics.setLineWidth(4)

	if isSelected then
		local glowClock = Timer.getTime()
		local pulse = 0.35 + 0.25 * (sin(glowClock * 5) * 0.5 + 0.5)
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
	love.graphics.rectangle("fill", x, y, w, h, cardRadius, cardRadius)

	local backgroundKey = animationState and animationState.backgroundKey
	if not backgroundKey then
		backgroundKey = getBackgroundCacheKey(card, style, borderColor, w, h)
		if animationState then
			animationState.backgroundKey = backgroundKey
		end
	end

	local backgroundCanvas = backgroundKey and getBackgroundCanvas(backgroundKey)
	if not backgroundCanvas and backgroundKey then
		backgroundCanvas = ensureBackgroundCanvas(backgroundKey, style, borderColor, w, h)
	end

	if backgroundCanvas then
		setColor(1, 1, 1, 1)
		love.graphics.draw(backgroundCanvas, x, y)
	else
		drawStaticStyleLayers(style, borderColor, x, y, w, h, fadeAlpha)
	end

	local currentTime = Timer.getTime()

	if style.outerGlow then
		local glowAlpha = getAnimatedAlpha(style.outerGlow, currentTime)
		if glowAlpha and glowAlpha > 0 then
			applyColor(setColor, style.outerGlow.color or borderColor, glowAlpha)
			love.graphics.setLineWidth(style.outerGlow.width or 6)
			local expand = style.outerGlow.expand or 6
			love.graphics.rectangle("line", x - expand, y - expand, w + expand * 2, h + expand * 2, 18, 18)
		end
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
		hoverGlowAlpha = max(hoverGlowAlpha or 0, focusAlpha)
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

	local headerPadding = 16
	local headerInset = 18
	local badgeStyle = card and card._badgeStyle
	if not badgeStyle and card then
		badgeStyle = getBadgeStyleForCard(card)
		card._badgeStyle = card._badgeStyle or badgeStyle
	end
	local badgeLabelFont = UI.fonts.caption or UI.fonts.body
	local headerHeight = 0
	local headerTop = y + headerPadding
	local headerCenterY = headerTop

	local rarityLabel = card.rarityLabel
	local rarityFont = badgeLabelFont or UI.fonts.body
	local hasRarity = rarityLabel and rarityLabel ~= ""
	local rarityHeight = 0

	if hasRarity then
		love.graphics.setFont(rarityFont)
		rarityHeight = rarityFont:getHeight() * rarityFont:getLineHeight()
		headerHeight = max(headerHeight, rarityHeight)
	end

	if headerHeight > 0 then
		headerCenterY = headerTop + headerHeight * 0.5

		if hasRarity then
			love.graphics.setFont(rarityFont)
			setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
			local rarityWidth = rarityFont:getWidth(rarityLabel)
			local rarityX = x + w - headerInset - rarityWidth
			local minRarityX = x + headerInset
			rarityX = max(rarityX, minRarityX)
			local rarityY = headerCenterY - rarityHeight * 0.5
			love.graphics.print(rarityLabel, rarityX, rarityY)
		end
	end

	setColor(1, 1, 1, 1)
	local titleFont = UI.fonts.button
	love.graphics.setFont(titleFont)
	local textLayout = ensureCardTextLayout(card, w) or {}
	local titleWidth = textLayout.titleWidth or (w - 28)
	local headerBottom = headerTop + headerHeight
	local titleSpacing = headerHeight > 0 and 12 or 8
	local titleY = headerBottom + titleSpacing
	local titleX = x + 14
	setColor(0, 0, 0, 0.85)
	love.graphics.printf(card.name or "", titleX + 1, titleY + 1, titleWidth, "center")
	setColor(1, 1, 1, 1)
	love.graphics.printf(card.name or "", titleX, titleY, titleWidth, "center")

	local titleLineCount = textLayout.titleLineCount or 1
	local titleHeight = textLayout.titleHeight or (titleLineCount * titleFont:getHeight() * titleFont:getLineHeight())
	local contentTop = titleY + titleHeight

	setColor(1, 1, 1, 0.3)
	love.graphics.setLineWidth(1)
	local dividerY = contentTop + 18
	love.graphics.line(x + 24, dividerY, x + w - 24, dividerY)
	local descStart = dividerY + 16

	love.graphics.setFont(UI.fonts.body)
	local descX = x + 18
	local descWidth = textLayout.descWidth or (w - 36)
	setColor(0, 0, 0, 0.75)
	love.graphics.printf(card.desc or "", descX + 1, descStart + 1, descWidth, "center")
	setColor(0.92, 0.92, 0.92, 1)
	love.graphics.printf(card.desc or "", descX, descStart, descWidth, "center")

	if badgeStyle then
		local MIN_BADGE_SIZE = 136
		local badgeSize = max(MIN_BADGE_SIZE, badgeStyle.size or 0)
		local badgeCenterX = x + w * 0.5
		local badgeCenterY = y + h * (2 / 3) + h / 6 - 40
		drawBadge(setColor, badgeStyle, badgeCenterX, badgeCenterY, badgeSize)
	end

	local revealState = animationState and animationState.mysteryReveal or nil
	if revealState then
		local overlayAlpha = revealState.white or 0
		if overlayAlpha > 0 then
			setColor(1, 1, 1, overlayAlpha)
			love.graphics.rectangle("fill", x + 8, y + 8, w - 16, h - 16, 10, 10)
			setColor(1, 1, 1, 1)
		end
	end
end

function Shop:draw(screenW, screenH)
	drawBackground(screenW, screenH, self.floorPalette)
	local textAreaWidth = screenW * 0.8
	local textAreaX = (screenW - textAreaWidth) / 2
	local headerY = UI.getHeaderY(screenW, screenH)
	local currentY = headerY

	love.graphics.setFont(UI.fonts.title)
	local titleText = Localization:get("shop.title")
	local shadowOffset = 3
	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.printf(titleText, textAreaX + shadowOffset, headerY + shadowOffset, textAreaWidth, "center")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(titleText, textAreaX, headerY, textAreaWidth, "center")

	local function advanceY(text, font, spacing)
		if not text or text == "" then
			return 0
		end
		local wrapWidth = textAreaWidth
		local _, lines = font:getWrap(text, wrapWidth)
		local lineCount = max(1, #lines)
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
	local cardWidth, cardHeight = DEFAULT_CARD_WIDTH, DEFAULT_CARD_HEIGHT
	local baseSpacing = 48
	local minSpacing = 28
	local marginX = max(60, screenW * 0.05)
	local availableWidth = max(cardWidth, screenW - marginX * 2)
	local columns = min(cardCount, max(1, floor((availableWidth + minSpacing) / (cardWidth + minSpacing))))

	while columns > 1 do
		local widthNeeded = columns * cardWidth + (columns - 1) * minSpacing
		if widthNeeded <= availableWidth then
			break
		end
		columns = columns - 1
	end

	columns = max(1, columns)
	local rows = max(1, ceil(cardCount / columns))

	local spacing = 0
	if columns > 1 then
		local calculated = (availableWidth - columns * cardWidth) / (columns - 1)
		spacing = max(minSpacing, min(baseSpacing, calculated))
	end

	local totalWidth = columns * cardWidth + max(0, (columns - 1)) * spacing
	local startX = (screenW - totalWidth) / 2

	local rowSpacing = 72
	local minRowSpacing = 40
	local bottomPadding = screenH * 0.12
	local minTopPadding = screenH * 0.24
	local topPadding = max(minTopPadding, headerBottom + 24)
	local availableHeight = screenH - topPadding - bottomPadding
	if availableHeight < 0 then
		local reduction = min(topPadding - minTopPadding, -availableHeight)
		if reduction > 0 then
			topPadding = topPadding - reduction
		end
		availableHeight = max(0, screenH - topPadding - bottomPadding)
	end
	local totalHeight = rows * cardHeight + max(0, (rows - 1)) * rowSpacing
	if rows > 1 and totalHeight > availableHeight then
		local adjustableRows = rows - 1
		if adjustableRows > 0 then
			local excess = totalHeight - availableHeight
			local reduction = excess / adjustableRows
			rowSpacing = max(minRowSpacing, rowSpacing - reduction)
			totalHeight = rows * cardHeight + max(0, (rows - 1)) * rowSpacing
		end
	end

	local preferredTop = screenH * 0.34
	local centeredTop = (screenH - totalHeight) / 2
	local startY = max(topPadding, min(preferredTop, centeredTop))
	local layoutCenterY = startY + totalHeight / 2

	local mx, my = UI.refreshCursor()

	local function renderCard(i, card)
		local columnIndex = ((i - 1) % columns)
		local rowIndex = floor((i - 1) / columns)
		local baseX = startX + columnIndex * (cardWidth + spacing)
		local baseY = startY + rowIndex * (cardHeight + rowSpacing)
		local alpha = 1
		local scale = 1
		local yOffset = 0
		local state = self.cardStates and self.cardStates[i]
		local revealState = state and state.mysteryReveal or nil
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
				local pulse = 1 + 0.05 * sin((state.selectionClock or 0) * 8)
				scale = scale * (1 + 0.08 * selection) * pulse
				alpha = min(1, alpha * (1 + 0.2 * selection))
			end
		end

		local focus = state and state.focus or 0
		local fadeOut = state and state.fadeOut or 0
		local focusEase = focus * focus * (3 - 2 * focus)
		local revealFocus = 0
		if revealState then
			local boost = revealState.focusBoost or 0
			revealFocus = max(0, min(1, boost))
		end
		local combinedFocus = max(focusEase, revealFocus)
		local fadeEase = fadeOut * fadeOut * (3 - 2 * fadeOut)
		local discardData = (state and state.discardActive and state.discard and self.restocking) and state.discard or nil
		local discardOffsetX, discardOffsetY, discardRotation = 0, 0, 0
		if discardData then
			local fadeT = max(0, min(1, fadeOut))
			local time = discardData.duration and discardData.duration > 0 and min(1, (discardData.clock or 0) / discardData.duration) or fadeT
			local discardEase = fadeT * fadeT * (3 - 2 * fadeT)
			local motionEase = time * time * (3 - 2 * time)
			local dropEase = discardEase * discardEase
			local swayClock = (discardData.clock or 0) * (discardData.swaySpeed or 3.2)
			local sway = sin(swayClock) * (discardData.swayMagnitude or 14) * (1 - motionEase)
			discardOffsetX = ((discardData.horizontalDistance or 0) * motionEase) + sway * (discardData.direction or 1)
			local dropDistance = discardData.dropDistance or 0
			local arcHeight = discardData.arcHeight or 0
			discardOffsetY = dropDistance * dropEase - arcHeight * (1 - motionEase)
			discardRotation = (discardData.rotation or 0) * dropEase
			scale = scale * (1 - 0.12 * discardEase)
			alpha = alpha * (1 - 0.7 * discardEase)
		end

		local cardSelected = card == self.selected
		if cardSelected or combinedFocus > 0 then
			local focusAmount = combinedFocus
			yOffset = yOffset + 46 * focusAmount
			scale = scale * (1 + 0.35 * focusAmount)
			alpha = min(1, alpha * (1 + 0.6 * focusAmount))
			-- Make sure the selected card renders at full opacity while it
			-- animates toward the center. Without this clamp the focus easing
			-- could leave it slightly translucent until the animation fully
			-- completes, which felt like a bug. Forcing alpha to 1 keeps the
			-- spotlighted card crisp for the whole animation.
			if cardSelected or revealFocus > 0 then
				alpha = 1
			end
		end

		if not cardSelected and combinedFocus <= 0 then
			if discardData then
				scale = scale * (1 - 0.05 * fadeEase)
				alpha = alpha * (1 - 0.55 * fadeEase)
			else
				yOffset = yOffset - 32 * fadeEase
				scale = scale * (1 - 0.2 * fadeEase)
				alpha = alpha * (1 - 0.9 * fadeEase)
			end
		end

		alpha = max(0, min(alpha, 1))

		local shakeOffset = (revealState and revealState.shakeOffset) or 0
		local extraRotation = (revealState and revealState.shakeRotation) or 0

		local centerX = baseX + cardWidth / 2
		local centerY = baseY + cardHeight / 2 - yOffset
		if cardSelected or combinedFocus > 0 then
			local focusAmount = combinedFocus
			centerX = centerX + (screenW / 2 - centerX) * focusAmount
			local targetY = layoutCenterY
			centerY = centerY + (targetY - centerY) * focusAmount
		else
			if discardData then
				centerX = centerX + discardOffsetX
				centerY = centerY + discardOffsetY
			else
				centerY = centerY + 28 * fadeEase
			end
		end

		centerX = centerX + shakeOffset

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
		local totalRotation = discardRotation + extraRotation
		if totalRotation ~= 0 then
			love.graphics.rotate(totalRotation)
		end
		love.graphics.scale(scale, scale)
		love.graphics.translate(-cardWidth / 2, -cardHeight / 2)
		local appearanceAlpha = self.selected == card and 1 or alpha
		drawCard(card, 0, 0, cardWidth, cardHeight, hovered, i, state, self.selected == card, appearanceAlpha)
		love.graphics.pop()
		card.bounds = {x = drawX, y = drawY, w = drawWidth, h = drawHeight}

		if state and state.selectionFlash then
			local flashDuration = 0.75
			local t = max(0, min(1, state.selectionFlash / flashDuration))
			local ease = 1 - ((1 - t) * (1 - t))
			local ringAlpha = (1 - ease) * 0.8
			local burstAlpha = (1 - ease) * 0.45
			local radiusBase = max(cardWidth, cardHeight) * 0.42
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
	elseif button == "a" then
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

	Upgrades:acquire(card, {floor = self.floor})
	self.selected = card
	self.selectedIndex = i
	self.selectionTimer = 0
	self.selectionComplete = false

	local state = self.cardStates and self.cardStates[i]
	if state then
		state.selectionFlash = 0
		state.selectSoundPlayed = true
		state.revealHoldTimer = nil
	end
	Audio:playSound("shop_card_select")
	return true
end

function Shop:isSelectionComplete()
	return self.selected ~= nil and self.selectionComplete == true
end

function Shop.drawCardPreview(card, x, y, w, h, options)
	if not card then return end

	options = options or {}
	local hovered = options.hovered == true
	local index = options.index or 1
	local animationState = options.animationState or {}
	local isSelected = options.isSelected == true
	local appearanceAlpha = options.appearanceAlpha or 1

	drawCard(card, x, y, w, h, hovered, index, animationState, isSelected, appearanceAlpha)
end

return Shop