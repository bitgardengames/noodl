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
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local BACKGROUND_EFFECT_TYPE = "ShopGlimmer"
local BackgroundEffectCache = {}
local CARD_HOLOGRAM_TYPE = "CardHologram"
local CardHologramCache = {}
local BackgroundEffect = nil

local function GetColorChannels(color, fallback)
        local reference = color or fallback
        if not reference then
                return 0, 0, 0, 1
        end

        return reference[1] or 0, reference[2] or 0, reference[3] or 0, reference[4] or 1
end

local function ConfigureBackgroundEffect(palette)
        local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
        if not effect then
                BackgroundEffect = nil
                return
        end

        local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
        effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.54

        local NeedsConfigure = (effect._appliedPalette ~= palette) or not effect._appliedPaletteConfigured

        if NeedsConfigure then
                local BgColor = (palette and palette.bgColor) or Theme.BgColor
                local AccentColor = (palette and (palette.arenaBorder or palette.snake)) or Theme.ButtonHover
                local HighlightColor = (palette and (palette.highlightColor or palette.snake or palette.arenaBorder))
                        or Theme.AccentTextColor
                        or Theme.HighlightColor

                Shaders.configure(effect, {
                        BgColor = BgColor,
                        AccentColor = AccentColor,
                        GlowColor = HighlightColor,
                        HighlightColor = HighlightColor,
                })

                effect._appliedPalette = palette
                effect._appliedPaletteConfigured = true
        end

        BackgroundEffect = effect
end

local function DrawBackground(ScreenW, ScreenH, palette)
        local BgColor = (palette and palette.bgColor) or Theme.BgColor
        local BaseR, BaseG, BaseB, BaseA = GetColorChannels(BgColor)
        love.graphics.setColor(BaseR * 0.92, BaseG * 0.92, BaseB * 0.92, BaseA)
        love.graphics.rectangle("fill", 0, 0, ScreenW, ScreenH)

        if not BackgroundEffect or BackgroundEffect._appliedPalette ~= palette then
                ConfigureBackgroundEffect(palette)
        end

        if BackgroundEffect then
                local intensity = BackgroundEffect.backdropIntensity or select(1, Shaders.GetDefaultIntensities(BackgroundEffect))
                Shaders.draw(BackgroundEffect, 0, 0, ScreenW, ScreenH, intensity)
        end

        local OverlayR, OverlayG, OverlayB = GetColorChannels(BgColor)
        love.graphics.setColor(OverlayR, OverlayG, OverlayB, 0.28)
        love.graphics.rectangle("fill", 0, 0, ScreenW, ScreenH)
        love.graphics.setColor(1, 1, 1, 1)
end

local function MoveFocusAnalog(self, delta)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end
	if self.selected then return end

	self.InputMode = "gamepad"
	self:MoveFocus(delta)
end

local AnalogAxisActions = {
	horizontal = {
		negative = function(self)
			MoveFocusAnalog(self, -1)
		end,
		positive = function(self)
			MoveFocusAnalog(self, 1)
		end,
	},
	vertical = {
		negative = function(self)
			MoveFocusAnalog(self, -1)
		end,
		positive = function(self)
			MoveFocusAnalog(self, 1)
		end,
	},
}

local AnalogAxisMap = {
	leftx = { slot = "horizontal" },
	rightx = { slot = "horizontal" },
	lefty = { slot = "vertical" },
	righty = { slot = "vertical" },
	[1] = { slot = "horizontal" },
	[2] = { slot = "vertical" },
}

local function ResetAnalogAxis()
	AnalogAxisDirections.horizontal = nil
	AnalogAxisDirections.vertical = nil
end

local function HandleAnalogAxis(self, axis, value)
	local mapping = AnalogAxisMap[axis]
	if not mapping then
		return
	end

	local direction
	if value >= ANALOG_DEADZONE then
		direction = "positive"
	elseif value <= -ANALOG_DEADZONE then
		direction = "negative"
	end

	if AnalogAxisDirections[mapping.slot] == direction then
		return
	end

	AnalogAxisDirections[mapping.slot] = direction

	if direction then
		local actions = AnalogAxisActions[mapping.slot]
		local action = actions and actions[direction]
		if action then
			action(self)
		end
	end
end

function Shop:start(CurrentFloor)
        self.floor = CurrentFloor or 1
        local FloorData = Floors[self.floor]
        self.FloorPalette = FloorData and FloorData.palette or nil
        self.ShopkeeperLine = nil
        self.ShopkeeperSubline = nil
        self.SelectionHoldDuration = 1.85
        self.InputMode = nil
        self.time = 0
        ConfigureBackgroundEffect(self.FloorPalette)
        self:RefreshCards()
end

function Shop:RefreshCards(options)
	options = options or {}
	local InitialDelay = options.initialDelay or 0

	self.restocking = nil
	local BaseChoices = 3
	local UpgradeBonus = 0
	if Upgrades.GetEffect then
		UpgradeBonus = math.max(0, math.floor(Upgrades:GetEffect("ShopSlots") or 0))
	end

	local MetaBonus = 0
	if MetaProgression and MetaProgression.GetShopBonusSlots then
		MetaBonus = math.max(0, MetaProgression:GetShopBonusSlots() or 0)
	end

	local ExtraChoices = UpgradeBonus + MetaBonus

	self.BaseChoices = BaseChoices
	self.UpgradeBonusChoices = UpgradeBonus
	self.MetaBonusChoices = MetaBonus
	self.ExtraChoices = ExtraChoices

	local CardCount = BaseChoices + ExtraChoices
	self.TotalChoices = CardCount
	self.cards = Upgrades:GetRandom(CardCount, { floor = self.floor }) or {}
	self.CardStates = {}
	self.selected = nil
	self.SelectedIndex = nil
	self.SelectionProgress = 0
	self.SelectionTimer = 0
	self.SelectionComplete = false
	self.time = 0
	self.FocusIndex = nil

	if #self.cards > 0 then
		self:SetFocus(1)
	end

	ResetAnalogAxis()

	for i = 1, #self.cards do
		self.CardStates[i] = {
			progress = 0,
			delay = InitialDelay + (i - 1) * 0.08,
			selection = 0,
			SelectionClock = 0,
			hover = 0,
			focus = 0,
			FadeOut = 0,
			SelectionFlash = nil,
			RevealSoundPlayed = false,
			SelectSoundPlayed = false,
			DiscardActive = false,
			discard = nil,
		}
	end
end

function Shop:BeginRestock()
	if self.restocking then return end

	self.restocking = {
		phase = "FadeOut",
		timer = 0,
		FadeDuration = 0.35,
		DelayAfterFade = 0.12,
		RevealDelay = 0.1,
	}

	self.selected = nil
	self.SelectedIndex = nil
	self.SelectionTimer = 0
	self.SelectionComplete = false
	self.FocusIndex = nil

	local random = love.math.random
	if self.CardStates then
		local count = #self.CardStates
		local CenterIndex = (count + 1) / 2
		for index, state in ipairs(self.CardStates) do
			state.discardActive = true
			local spread = index - CenterIndex
			local direction = spread >= 0 and 1 or -1
			local HorizontalDistance = spread * 44 + (random() * 12 - 6)
			local rotation = spread * 0.16 + (random() * 0.18 - 0.09)
			local DropDistance = 220 + random() * 90
			local ArcHeight = 26 + random() * 18
			local SwayMagnitude = 12 + random() * 10
			local SwaySpeed = 2.8 + random() * 0.8
			state.discard = {
				direction = direction,
				HorizontalDistance = HorizontalDistance,
				DropDistance = DropDistance,
				ArcHeight = ArcHeight,
				rotation = rotation,
				SwayMagnitude = SwayMagnitude,
				SwaySpeed = SwaySpeed,
				duration = 0.65 + random() * 0.15,
				clock = 0,
			}
		end
	end
end

function Shop:SetFocus(index)
	if self.restocking then return end
	if not self.cards or not index then return end
	if index < 1 or index > #self.cards then return end
	local previous = self.FocusIndex
	if previous and previous ~= index then
		Audio:PlaySound("shop_focus")
	end
	self.FocusIndex = index
	return self.cards[index]
end

function Shop:MoveFocus(delta)
	if self.restocking then return end
	if not delta or delta == 0 then return end
	if not self.cards or #self.cards == 0 then return end

	local count = #self.cards
	local index = self.FocusIndex or 1
	index = ((index - 1 + delta) % count) + 1
	return self:SetFocus(index)
end

function Shop:update(dt)
	if not dt then return end
	self.time = (self.time or 0) + dt
	if not self.CardStates then return end

	local restock = self.restocking
	local RestockProgress = nil
	if restock then
		restock.timer = (restock.timer or 0) + dt
		if restock.phase == "FadeOut" then
			local duration = restock.fadeDuration or 0.35
			if duration <= 0 then
				restock.progress = 1
			else
				restock.progress = math.min(1, restock.timer / duration)
			end
			RestockProgress = restock.progress
			if restock.progress >= 1 then
				restock.phase = "waiting"
				restock.timer = 0
			end
		elseif restock.phase == "waiting" then
			RestockProgress = 1
			local delay = restock.delayAfterFade or 0
			if restock.timer >= delay then
				local RevealDelay = restock.revealDelay or 0
				self.restocking = nil
				self:RefreshCards({ InitialDelay = RevealDelay })
				return
			end
		end
	end

	self.SelectionProgress = self.SelectionProgress or 0
	if self.selected then
		self.SelectionProgress = math.min(1, self.SelectionProgress + dt * 2.4)
	else
		self.SelectionProgress = math.max(0, self.SelectionProgress - dt * 3)
	end

	for i, state in ipairs(self.CardStates) do
		if self.time >= state.delay and state.progress < 1 then
			state.progress = math.min(1, state.progress + dt * 3.2)
		end

		if not state.revealSoundPlayed and self.time >= state.delay then
			state.revealSoundPlayed = true
			Audio:PlaySound("shop_card_deal")
		end

		if state.discardActive and state.discard then
			state.discard.clock = (state.discard.clock or 0) + dt
		end

		local card = self.cards and self.cards[i]
		local IsSelected = card and self.selected == card
		local IsFocused = (self.FocusIndex == i) and not self.selected
		if IsSelected then
			state.selection = math.min(1, (state.selection or 0) + dt * 4)
			state.selectionClock = (state.selectionClock or 0) + dt
			state.focus = math.min(1, (state.focus or 0) + dt * 3)
			state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 4)
			state.hover = math.max(0, (state.hover or 0) - dt * 6)
			if not state.selectSoundPlayed then
				state.selectSoundPlayed = true
				Audio:PlaySound("shop_card_select")
			end
		else
			state.selection = math.max(0, (state.selection or 0) - dt * 3)
			if state.selection <= 0.001 then
				state.selectionClock = 0
			else
				state.selectionClock = (state.selectionClock or 0) + dt
			end
			if IsFocused and not restock then
				state.hover = math.min(1, (state.hover or 0) + dt * 6)
			else
				state.hover = math.max(0, (state.hover or 0) - dt * 4)
			end
			if restock then
				local FadeTarget = RestockProgress or 0
				state.fadeOut = math.max(FadeTarget, math.min(1, (state.fadeOut or 0) + dt * 3.2))
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
			local FlashDuration = 0.75
			state.selectionFlash = state.selectionFlash + dt
			if state.selectionFlash >= FlashDuration then
				state.selectionFlash = nil
			end
		end
	end

	if self.selected then
		self.SelectionTimer = (self.SelectionTimer or 0) + dt
		if not self.SelectionComplete then
			local hold = self.SelectionHoldDuration or 0
			local state = self.SelectedIndex and self.CardStates and self.CardStates[self.SelectedIndex] or nil
			local FlashDone = not (state and state.selectionFlash)
			if self.SelectionTimer >= hold and FlashDone then
				self.SelectionComplete = true
				Audio:PlaySound("shop_purchase")
			end
		end
	else
		self.SelectionTimer = 0
		self.SelectionComplete = false
		self.SelectedIndex = nil
	end
end

local RarityBorderAlpha = 0.85

local RarityStyles = {
	common = {
		base = {0.20, 0.23, 0.28, 1},
		ShadowAlpha = 0.18,
		aura = {
			color = {0.52, 0.62, 0.78, 0.22},
			radius = 0.72,
			y = 0.42,
		},
		OuterGlow = {
			color = {0.62, 0.74, 0.92, 1},
			min = 0.04,
			max = 0.14,
			speed = 1.4,
			expand = 5,
			width = 6,
		},
		InnerGlow = {
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
		ShadowAlpha = 0.24,
		aura = {
			color = {0.46, 0.78, 0.56, 0.28},
			radius = 0.76,
			y = 0.40,
		},
		OuterGlow = {
			color = {0.52, 0.92, 0.64, 1},
			min = 0.08,
			max = 0.24,
			speed = 1.6,
			expand = 6,
			width = 6,
		},
		InnerGlow = {
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
		ShadowAlpha = 0.30,
		aura = {
			color = {0.40, 0.60, 0.92, 0.32},
			radius = 0.82,
			y = 0.36,
		},
		OuterGlow = {
			color = {0.48, 0.72, 1.0, 1},
			min = 0.14,
			max = 0.32,
			speed = 1.9,
			expand = 7,
			width = 7,
		},
		InnerGlow = {
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
		ShadowAlpha = 0.36,
		aura = {
			color = {0.86, 0.56, 0.98, 0.42},
			radius = 0.9,
			y = 0.34,
		},
		OuterGlow = {
			color = {0.92, 0.74, 1.0, 1},
			min = 0.2,
			max = 0.46,
			speed = 2.4,
			expand = 9,
			width = 8,
		},
		InnerGlow = {
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
		ShadowAlpha = 0.46,
		OuterGlow = {
			color = {1.0, 0.82, 0.34, 1},
			min = 0.26,
			max = 0.56,
			speed = 2.6,
			expand = 10,
			width = 10,
		},
		InnerGlow = {
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
		BorderWidth = 5,
	},
}

local function CloneColor(color)
	if not color then
		return nil
	end

	return { color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1 }
end

local HologramRarityPalettes = {}
do
	local HologramRarities = { "rare", "epic", "legendary" }
	for _, rarity in ipairs(HologramRarities) do
		local style = RarityStyles[rarity]
		if style then
			local primary = CloneColor((style.innerGlow and style.innerGlow.color) or (style.outerGlow and style.outerGlow.color))
				or CloneColor(style.base)
			local sparkle = CloneColor(style.sparkles and style.sparkles.color)
				or CloneColor((style.outerGlow and style.outerGlow.color))
				or CloneColor((style.innerGlow and style.innerGlow.color))
				or primary
			local rim = CloneColor((style.outerGlow and style.outerGlow.color))
				or CloneColor((style.innerGlow and style.innerGlow.color))
				or primary

			HologramRarityPalettes[rarity] = {
				BaseColor = CloneColor(style.base) or primary,
				AccentColor = primary,
				SparkleColor = sparkle or primary,
				RimColor = rim or primary,
			}
		end
	end
end

local function ApplyColor(SetColorFn, color, OverrideAlpha)
	if not color then return end
	SetColorFn(color[1], color[2], color[3], OverrideAlpha or color[4] or 1)
end

local function WithTransformedScissor(x, y, w, h, fn)
	if not fn then return end

	local sx1, sy1 = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)

	local ScissorX = math.min(sx1, sx2)
	local ScissorY = math.min(sy1, sy2)
	local ScissorW = math.abs(sx2 - sx1)
	local ScissorH = math.abs(sy2 - sy1)

	if ScissorW <= 0 or ScissorH <= 0 then
		fn()
		return
	end

	local previous = { love.graphics.getScissor() }
	love.graphics.setScissor(ScissorX, ScissorY, ScissorW, ScissorH)
	fn()
	if previous[1] then
		love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
	else
		love.graphics.setScissor()
	end
end

local function GetAnimatedAlpha(def, time)
	if not def then return nil end
	local MinAlpha = def.min or def.alpha or 0
	local MaxAlpha = def.max or def.alpha or MinAlpha
	if not def.speed or MaxAlpha == MinAlpha then
		return MaxAlpha
	end
	local phase = def.phase or 0
	local wave = math.sin(time * def.speed + phase) * 0.5 + 0.5
	return MinAlpha + (MaxAlpha - MinAlpha) * wave
end

local function DrawCard(card, x, y, w, h, hovered, index, AnimationState, IsSelected, AppearanceAlpha)
        local FadeAlpha = AppearanceAlpha or 1
        local function SetColor(r, g, b, a)
                love.graphics.setColor(r, g, b, (a or 1) * FadeAlpha)
        end

	local style = RarityStyles[card.rarity or "common"] or RarityStyles.common
	local BorderColor = card.rarityColor or {1, 1, 1, RarityBorderAlpha}

        if IsSelected then
                local GlowClock = love.timer.getTime()
		local pulse = 0.35 + 0.25 * (math.sin(GlowClock * 5) * 0.5 + 0.5)
		SetColor(1, 0.9, 0.45, pulse)
		love.graphics.setLineWidth(10)
		love.graphics.rectangle("line", x - 14, y - 14, w + 28, h + 28, 18, 18)
		love.graphics.setLineWidth(4)
	end

        if style.shadowAlpha and style.shadowAlpha > 0 then
                SetColor(0, 0, 0, style.shadowAlpha)
                love.graphics.rectangle("fill", x + 6, y + 10, w, h, 18, 18)
        end

        ApplyColor(SetColor, style.base)
        love.graphics.rectangle("fill", x, y, w, h, 12, 12)

        local CurrentTime = love.timer.getTime()

        if style.aura then
		WithTransformedScissor(x, y, w, h, function()
			ApplyColor(SetColor, style.aura.color)
			local radius = math.max(w, h) * (style.aura.radius or 0.72)
			local CenterY = y + h * (style.aura.y or 0.4)
			love.graphics.circle("fill", x + w * 0.5, CenterY, radius)
		end)
	end

	if style.outerGlow then
		local GlowAlpha = GetAnimatedAlpha(style.outerGlow, CurrentTime)
		if GlowAlpha and GlowAlpha > 0 then
			ApplyColor(SetColor, style.outerGlow.color or BorderColor, GlowAlpha)
			love.graphics.setLineWidth(style.outerGlow.width or 6)
			local expand = style.outerGlow.expand or 6
			love.graphics.rectangle("line", x - expand, y - expand, w + expand * 2, h + expand * 2, 18, 18)
		end
	end
	if style.flare then
		WithTransformedScissor(x, y, w, h, function()
			ApplyColor(SetColor, style.flare.color)
			local radius = math.min(w, h) * (style.flare.radius or 0.36)
			love.graphics.circle("fill", x + w * 0.5, y + h * 0.32, radius)
		end)
	end

	if style.stripes then
		WithTransformedScissor(x, y, w, h, function()
			love.graphics.push()
			love.graphics.translate(x + w / 2, y + h / 2)
			love.graphics.rotate(style.stripes.angle or -math.pi / 6)
			local diag = math.sqrt(w * w + h * h)
			local spacing = style.stripes.spacing or 34
			local width = style.stripes.width or 22
			ApplyColor(SetColor, style.stripes.color)
			local StripeCount = math.ceil((diag * 2) / spacing) + 2
			for i = -StripeCount, StripeCount do
				local pos = i * spacing
				love.graphics.rectangle("fill", -diag, pos - width / 2, diag * 2, width)
			end
			love.graphics.pop()
		end)
	end

	if style.sparkles and style.sparkles.positions then
		WithTransformedScissor(x, y, w, h, function()
                        local time = love.timer.getTime()
			for i, pos in ipairs(style.sparkles.positions) do
				local px, py, scale = pos[1], pos[2], pos[3] or 1
				local pulse = 0.6 + 0.4 * math.sin(time * (style.sparkles.speed or 1.8) + i * 0.9)
				local radius = (style.sparkles.radius or 9) * scale * pulse
				local SparkleColor = style.sparkles.color or BorderColor
				local SparkleAlpha = (SparkleColor[4] or 1) * pulse
				ApplyColor(SetColor, SparkleColor, SparkleAlpha)
				love.graphics.circle("fill", x + px * w, y + py * h, radius)
			end
		end)
	end

	if style.glow and style.glow > 0 then
		ApplyColor(SetColor, BorderColor, style.glow)
		love.graphics.setLineWidth(6)
		love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, 16, 16)
	end

	ApplyColor(SetColor, BorderColor, RarityBorderAlpha)
	local HologramPalette = HologramRarityPalettes[card.rarity or ""]
	if HologramPalette then
		local effect = Shaders.ensure(CardHologramCache, CARD_HOLOGRAM_TYPE)
		if effect then
			local HoverValue = (AnimationState and AnimationState.hover) or 0
			if hovered then
				HoverValue = math.max(HoverValue, 1)
			end
			local FocusValue = (AnimationState and AnimationState.focus) or 0
			local SelectionValue = (AnimationState and AnimationState.selection) or 0
			if IsSelected then
				SelectionValue = math.max(SelectionValue, 1)
			end

			local function ease(t)
				t = math.max(0, math.min(1, t))
				return t * t * (3 - 2 * t)
			end

			local HoverEase = ease(HoverValue)
			local FocusEase = ease(FocusValue)
			local SelectionEase = ease(SelectionValue)

			local intensity = 0.55 + 0.3 * HoverEase + 0.2 * FocusEase + 0.45 * SelectionEase
			intensity = math.max(0, math.min(intensity * FadeAlpha, 1.35))

			local EffectData = {
				parallax = (HoverEase * 0.4 + SelectionEase * 0.9) * FadeAlpha,
				ScanOffset = ((AnimationState and AnimationState.selectionClock) or 0) * 0.12,
			}

			Shaders.configure(effect, HologramPalette, EffectData)

			WithTransformedScissor(x, y, w, h, function()
				love.graphics.setColor(1, 1, 1, FadeAlpha)
				Shaders.draw(effect, x, y, w, h, intensity)
				love.graphics.setColor(1, 1, 1, 1)
			end)
		end
	end

	ApplyColor(SetColor, BorderColor, RarityBorderAlpha)
	love.graphics.setLineWidth(style.borderWidth or 4)
	love.graphics.rectangle("line", x, y, w, h, 12, 12)

        local HoverGlowAlpha
        if style.innerGlow then
                HoverGlowAlpha = GetAnimatedAlpha(style.innerGlow, CurrentTime)
	end

	if hovered or IsSelected then
		local FocusAlpha = hovered and 0.6 or 0.4
		HoverGlowAlpha = math.max(HoverGlowAlpha or 0, FocusAlpha)
	end

	if HoverGlowAlpha and HoverGlowAlpha > 0 then
		local InnerColor = (style.innerGlow and style.innerGlow.color) or BorderColor
		local inset = (style.innerGlow and style.innerGlow.inset) or 6
		love.graphics.setLineWidth((style.innerGlow and style.innerGlow.width) or 2)
		ApplyColor(SetColor, InnerColor, HoverGlowAlpha)
		love.graphics.rectangle("line", x + inset, y + inset, w - inset * 2, h - inset * 2, 10, 10)
	elseif hovered or IsSelected then
		local GlowAlpha = hovered and 0.55 or 0.35
		ApplyColor(SetColor, BorderColor, GlowAlpha)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12, 10, 10)
	end

	love.graphics.setLineWidth(4)

	SetColor(1, 1, 1, 1)
	local TitleFont = UI.fonts.button
	love.graphics.setFont(TitleFont)
	local TitleWidth = w - 28
	local TitleY = y + 24
	love.graphics.printf(card.name, x + 14, TitleY, TitleWidth, "center")

	local _, TitleLines = TitleFont:getWrap(card.name or "", TitleWidth)
	local TitleLineCount = math.max(1, #TitleLines)
	local TitleHeight = TitleLineCount * TitleFont:getHeight() * TitleFont:getLineHeight()
	local ContentTop = TitleY + TitleHeight

	local DescStart
	if card.rarityLabel then
		local RarityFont = UI.fonts.body
		love.graphics.setFont(RarityFont)
		SetColor(BorderColor[1], BorderColor[2], BorderColor[3], 0.9)
		local RarityY = ContentTop + 10
		love.graphics.printf(card.rarityLabel, x + 14, RarityY, TitleWidth, "center")

		SetColor(1, 1, 1, 0.3)
		love.graphics.setLineWidth(2)
		local RarityHeight = RarityFont:getHeight() * RarityFont:getLineHeight()
		local DividerY = RarityY + RarityHeight + 8
		love.graphics.line(x + 24, DividerY, x + w - 24, DividerY)
		DescStart = DividerY + 16
	else
		SetColor(1, 1, 1, 0.3)
		love.graphics.setLineWidth(2)
		local DividerY = ContentTop + 14
		love.graphics.line(x + 24, DividerY, x + w - 24, DividerY)
		DescStart = DividerY + 16
	end

	love.graphics.setFont(UI.fonts.body)
	SetColor(0.92, 0.92, 0.92, 1)
	local DescY = DescStart
	if card.upgrade and card.upgrade.tags and #card.upgrade.tags > 0 then
		love.graphics.setFont(UI.fonts.small)
		SetColor(0.8, 0.85, 0.9, 0.9)
		love.graphics.printf(table.concat(card.upgrade.tags, " • "), x + 18, DescY, w - 36, "center")
		DescY = DescY + 22
		love.graphics.setFont(UI.fonts.body)
		SetColor(0.92, 0.92, 0.92, 1)
	end
	love.graphics.printf(card.desc or "", x + 18, DescY, w - 36, "center")
end

function Shop:draw(ScreenW, ScreenH)
        DrawBackground(ScreenW, ScreenH, self.FloorPalette)
	local TextAreaWidth = ScreenW * 0.8
	local TextAreaX = (ScreenW - TextAreaWidth) / 2
	local CurrentY = ScreenH * 0.12

	love.graphics.setFont(UI.fonts.title)
	local TitleText = Localization:get("shop.title")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(TitleText, TextAreaX, CurrentY, TextAreaWidth, "center")

	local function AdvanceY(text, font, spacing)
		if not text or text == "" then
			return 0
		end
		local WrapWidth = TextAreaWidth
		local _, lines = font:getWrap(text, WrapWidth)
		local LineCount = math.max(1, #lines)
		return LineCount * font:getHeight() * font:getLineHeight() + (spacing or 0)
	end

	CurrentY = CurrentY + AdvanceY(TitleText, UI.fonts.title, 16)

	if self.ShopkeeperLine and self.ShopkeeperLine ~= "" then
		love.graphics.setFont(UI.fonts.body)
		love.graphics.setColor(1, 0.92, 0.8, 1)
		love.graphics.printf(self.ShopkeeperLine, TextAreaX, CurrentY, TextAreaWidth, "center")
		CurrentY = CurrentY + AdvanceY(self.ShopkeeperLine, UI.fonts.body, 10)
	end

	if self.ShopkeeperSubline and self.ShopkeeperSubline ~= "" then
		love.graphics.setFont(UI.fonts.small)
		love.graphics.setColor(1, 1, 1, 0.7)
		love.graphics.printf(self.ShopkeeperSubline, TextAreaX, CurrentY, TextAreaWidth, "center")
		CurrentY = CurrentY + AdvanceY(self.ShopkeeperSubline, UI.fonts.small, 18)
	end

	love.graphics.setColor(1, 1, 1, 1)
	local HeaderBottom = CurrentY

	local SelectionOverlay = self.SelectionProgress or 0
	if SelectionOverlay > 0 then
		local OverlayEase = SelectionOverlay * SelectionOverlay * (3 - 2 * SelectionOverlay)
		love.graphics.setColor(0, 0, 0, 0.35 * OverlayEase)
		love.graphics.rectangle("fill", 0, 0, ScreenW, ScreenH)
		love.graphics.setColor(1, 1, 1, 1)
	end

	local CardCount = #self.cards
	local CardWidth, CardHeight = 264, 344
	local BaseSpacing = 48
	local MinSpacing = 28
	local MarginX = math.max(60, ScreenW * 0.05)
	local AvailableWidth = math.max(CardWidth, ScreenW - MarginX * 2)
	local columns = math.min(CardCount, math.max(1, math.floor((AvailableWidth + MinSpacing) / (CardWidth + MinSpacing))))

	while columns > 1 do
		local WidthNeeded = columns * CardWidth + (columns - 1) * MinSpacing
		if WidthNeeded <= AvailableWidth then
			break
		end
		columns = columns - 1
	end

	columns = math.max(1, columns)
	local rows = math.max(1, math.ceil(CardCount / columns))

	local spacing = 0
	if columns > 1 then
		local calculated = (AvailableWidth - columns * CardWidth) / (columns - 1)
		spacing = math.max(MinSpacing, math.min(BaseSpacing, calculated))
	end

	local TotalWidth = columns * CardWidth + math.max(0, (columns - 1)) * spacing
	local StartX = (ScreenW - TotalWidth) / 2

	local RowSpacing = 72
	local MinRowSpacing = 40
	local BottomPadding = ScreenH * 0.12
	local MinTopPadding = ScreenH * 0.24
	local TopPadding = math.max(MinTopPadding, HeaderBottom + 24)
	local AvailableHeight = ScreenH - TopPadding - BottomPadding
	if AvailableHeight < 0 then
		local reduction = math.min(TopPadding - MinTopPadding, -AvailableHeight)
		if reduction > 0 then
			TopPadding = TopPadding - reduction
		end
		AvailableHeight = math.max(0, ScreenH - TopPadding - BottomPadding)
	end
	local TotalHeight = rows * CardHeight + math.max(0, (rows - 1)) * RowSpacing
	if rows > 1 and TotalHeight > AvailableHeight then
		local AdjustableRows = rows - 1
		if AdjustableRows > 0 then
			local excess = TotalHeight - AvailableHeight
			local reduction = excess / AdjustableRows
			RowSpacing = math.max(MinRowSpacing, RowSpacing - reduction)
			TotalHeight = rows * CardHeight + math.max(0, (rows - 1)) * RowSpacing
		end
	end

	local PreferredTop = ScreenH * 0.34
	local CenteredTop = (ScreenH - TotalHeight) / 2
	local StartY = math.max(TopPadding, math.min(PreferredTop, CenteredTop))
	local LayoutCenterY = StartY + TotalHeight / 2

	local mx, my = love.mouse.getPosition()

	local function RenderCard(i, card)
		local ColumnIndex = ((i - 1) % columns)
		local RowIndex = math.floor((i - 1) / columns)
		local BaseX = StartX + ColumnIndex * (CardWidth + spacing)
		local BaseY = StartY + RowIndex * (CardHeight + RowSpacing)
		local alpha = 1
		local scale = 1
		local YOffset = 0
		local state = self.CardStates and self.CardStates[i]
		if state then
			local progress = state.progress or 0
			local eased = progress * progress * (3 - 2 * progress)
			alpha = eased
			YOffset = (1 - eased) * 48

			-- Start cards a touch smaller and ease them up to full size so
			-- the reveal animation feels like a gentle pop rather than a flat fade.
			local AppearScaleMin = 0.94
			local AppearScaleMax = 1.0
			scale = AppearScaleMin + (AppearScaleMax - AppearScaleMin) * eased

			local hover = state.hover or 0
			if hover > 0 and not self.selected then
				local HoverEase = hover * hover * (3 - 2 * hover)
				scale = scale * (1 + 0.07 * HoverEase)
				YOffset = YOffset - 8 * HoverEase
			end

			local selection = state.selection or 0
			if selection > 0 then
				local pulse = 1 + 0.05 * math.sin((state.selectionClock or 0) * 8)
				scale = scale * (1 + 0.08 * selection) * pulse
				alpha = math.min(1, alpha * (1 + 0.2 * selection))
			end
		end

		local focus = state and state.focus or 0
		local FadeOut = state and state.fadeOut or 0
		local FocusEase = focus * focus * (3 - 2 * focus)
		local FadeEase = FadeOut * FadeOut * (3 - 2 * FadeOut)
		local DiscardData = (state and state.discardActive and state.discard and self.restocking) and state.discard or nil
		local DiscardOffsetX, DiscardOffsetY, DiscardRotation = 0, 0, 0
		if DiscardData then
			local FadeT = math.max(0, math.min(1, FadeOut))
			local time = DiscardData.duration and DiscardData.duration > 0 and math.min(1, (DiscardData.clock or 0) / DiscardData.duration) or FadeT
			local DiscardEase = FadeT * FadeT * (3 - 2 * FadeT)
			local MotionEase = time * time * (3 - 2 * time)
			local DropEase = DiscardEase * DiscardEase
			local SwayClock = (DiscardData.clock or 0) * (DiscardData.swaySpeed or 3.2)
			local sway = math.sin(SwayClock) * (DiscardData.swayMagnitude or 14) * (1 - MotionEase)
			DiscardOffsetX = ((DiscardData.horizontalDistance or 0) * MotionEase) + sway * (DiscardData.direction or 1)
			local DropDistance = DiscardData.dropDistance or 0
			local ArcHeight = DiscardData.arcHeight or 0
			DiscardOffsetY = DropDistance * DropEase - ArcHeight * (1 - MotionEase)
			DiscardRotation = (DiscardData.rotation or 0) * DropEase
			scale = scale * (1 - 0.12 * DiscardEase)
			alpha = alpha * (1 - 0.7 * DiscardEase)
		end

		if card == self.selected then
			YOffset = YOffset + 46 * FocusEase
			scale = scale * (1 + 0.35 * FocusEase)
			alpha = math.min(1, alpha * (1 + 0.6 * FocusEase))
			-- Make sure the selected card renders at full opacity while it
			-- animates toward the center. Without this clamp the focus easing
			-- could leave it slightly translucent until the animation fully
			-- completes, which felt like a bug. Forcing alpha to 1 keeps the
			-- spotlighted card crisp for the whole animation.
			alpha = 1
		else
			if DiscardData then
				scale = scale * (1 - 0.05 * FadeEase)
				alpha = alpha * (1 - 0.55 * FadeEase)
			else
				YOffset = YOffset - 32 * FadeEase
				scale = scale * (1 - 0.2 * FadeEase)
				alpha = alpha * (1 - 0.9 * FadeEase)
			end
		end

		alpha = math.max(0, math.min(alpha, 1))

		local CenterX = BaseX + CardWidth / 2
		local CenterY = BaseY + CardHeight / 2 - YOffset
		local OriginalCenterX, OriginalCenterY = CenterX, CenterY

		if card == self.selected then
			CenterX = CenterX + (ScreenW / 2 - CenterX) * FocusEase
			local TargetY = LayoutCenterY
			CenterY = CenterY + (TargetY - CenterY) * FocusEase
		else
			if DiscardData then
				CenterX = CenterX + DiscardOffsetX
				CenterY = CenterY + DiscardOffsetY
			else
				CenterY = CenterY + 28 * FadeEase
			end
		end

		local DrawWidth = CardWidth * scale
		local DrawHeight = CardHeight * scale
		local DrawX = CenterX - DrawWidth / 2
		local DrawY = CenterY - DrawHeight / 2

		local UsingFocusNavigation = self.InputMode == "gamepad" or self.InputMode == "keyboard"
		local MouseHover = mx >= DrawX and mx <= DrawX + DrawWidth
			and my >= DrawY and my <= DrawY + DrawHeight
		if not self.selected and MouseHover and not UsingFocusNavigation then
			self:SetFocus(i)
		end

		local hovered = not self.selected and (
			(UsingFocusNavigation and self.FocusIndex == i) or
			(not UsingFocusNavigation and MouseHover)
		)

		love.graphics.push()
		love.graphics.translate(CenterX, CenterY)
		if DiscardRotation ~= 0 then
			love.graphics.rotate(DiscardRotation)
		end
		love.graphics.scale(scale, scale)
		love.graphics.translate(-CardWidth / 2, -CardHeight / 2)
		local AppearanceAlpha = self.selected == card and 1 or alpha
                DrawCard(card, 0, 0, CardWidth, CardHeight, hovered, i, state, self.selected == card, AppearanceAlpha)
		love.graphics.pop()
		card.bounds = { x = DrawX, y = DrawY, w = DrawWidth, h = DrawHeight }

		if state and state.selectionFlash then
			local FlashDuration = 0.75
			local t = math.max(0, math.min(1, state.selectionFlash / FlashDuration))
			local ease = 1 - ((1 - t) * (1 - t))
			local RingAlpha = (1 - ease) * 0.8
			local BurstAlpha = (1 - ease) * 0.45
			local RadiusBase = math.max(CardWidth, CardHeight) * 0.42
			local radius = RadiusBase + ease * 180

			love.graphics.setLineWidth(6)
			love.graphics.setColor(1, 0.88, 0.45, RingAlpha)
			love.graphics.circle("line", CenterX, CenterY, radius)

			local BurstRadius = RadiusBase * (1 + ease * 0.5)
			love.graphics.setColor(1, 0.72, 0.32, BurstAlpha)
			love.graphics.circle("fill", CenterX, CenterY, BurstRadius)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end

	local SelectedIndex
	for i, card in ipairs(self.cards) do
		if card == self.selected then
			SelectedIndex = i
		else
			RenderCard(i, card)
		end
	end

	if SelectedIndex then
		RenderCard(SelectedIndex, self.cards[SelectedIndex])
	end

	if self.selected then
		love.graphics.setFont(UI.fonts.button)
		love.graphics.setColor(1, 0.88, 0.6, 0.9)
		love.graphics.printf(
			string.format("%s claimed", self.selected.name or "Relic"),
			0,
			ScreenH * 0.87,
			ScreenW,
			"center"
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function PickIndexFromKey(key)
	if key == "1" or key == "kp1" then return 1 end
	if key == "2" or key == "kp2" then return 2 end
	if key == "3" or key == "kp3" then return 3 end
	if key == "4" or key == "kp4" then return 4 end
	if key == "5" or key == "kp5" then return 5 end
end

function Shop:keypressed(key)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	local index = PickIndexFromKey(key)
	if index then
		self.InputMode = "keyboard"
		return self:pick(index)
	end

	if self.selected then return end

	if key == "left" or key == "up" then
		self.InputMode = "keyboard"
		self:MoveFocus(-1)
		return true
	elseif key == "right" or key == "down" then
		self.InputMode = "keyboard"
		self:MoveFocus(1)
		return true
	elseif key == "return" or key == "kpenter" or key == "enter" then
		self.InputMode = "keyboard"
		local FocusIndex = self.FocusIndex or 1
		return self:pick(FocusIndex)
	end
end

function Shop:mousepressed(x, y, button)
	if self.restocking then return end
	if button ~= 1 then return end
	self.InputMode = "mouse"
	for i, card in ipairs(self.cards) do
		local b = card.bounds
		if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
			self:SetFocus(i)
			return self:pick(i)
		end
	end
end

function Shop:gamepadpressed(_, button)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	self.InputMode = "gamepad"

	if self.selected then return end

	if button == "dpup" or button == "dpleft" then
		self:MoveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		self:MoveFocus(1)
	elseif button == "a" or button == "start" then
		local index = self.FocusIndex or 1
		return self:pick(index)
	end
end

Shop.joystickpressed = Shop.gamepadpressed

function Shop:gamepadaxis(_, axis, value)
	if self.restocking then return end
	if not self.cards or #self.cards == 0 then return end

	HandleAnalogAxis(self, axis, value)
end

Shop.joystickaxis = Shop.gamepadaxis

function Shop:pick(i)
	if self.restocking then return false end
	if self.selected then return false end
	local card = self.cards[i]
	if not card then return false end

	if card.restockShop then
		Audio:PlaySound("shop_card_select")
		self:BeginRestock()
		return true
	end

	Upgrades:acquire(card, { floor = self.floor })
	self.selected = card
	self.SelectedIndex = i
	self.SelectionTimer = 0
	self.SelectionComplete = false

	local state = self.CardStates and self.CardStates[i]
	if state then
		state.selectionFlash = 0
		state.selectSoundPlayed = true
	end
	Audio:PlaySound("shop_card_select")
	return true
end

function Shop:IsSelectionComplete()
	return self.selected ~= nil and self.SelectionComplete == true
end

return Shop
