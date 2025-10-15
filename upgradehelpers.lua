local Snake = require("snake")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local Localization = require("localization")
local UpgradeVisuals = require("upgradevisuals")

local UpgradeHelpers = {}

function UpgradeHelpers.GetUpgradeString(id, field)
	if not id or not field then return nil end
	return Localization:get("upgrades." .. id .. "." .. field)
end

UpgradeHelpers.rarities = {
	common = {
		weight = 46,
		LabelKey = "upgrades.rarities.common",
		color = {0.75, 0.82, 0.88, 1},
	},
	uncommon = {
		weight = 30,
		LabelKey = "upgrades.rarities.uncommon",
		color = {0.55, 0.78, 0.58, 1},
	},
	rare = {
		weight = 16,
		LabelKey = "upgrades.rarities.rare",
		color = {0.54, 0.72, 0.96, 1},
	},
	epic = {
		weight = 5.2,
		LabelKey = "upgrades.rarities.epic",
		color = {0.76, 0.56, 0.88, 1},
	},
	legendary = {
		weight = 1.4,
		LabelKey = "upgrades.rarities.legendary",
		color = {1, 0.66, 0.32, 1},
	},
}

local function deepcopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepcopy(v)
	end
	return copy
end

UpgradeHelpers.deepcopy = deepcopy

UpgradeHelpers.DefaultEffects = {
	SawSpeedMult = 1,
	SawSpinMult = 1,
	SawStall = 0,
	SawSinkDuration = 0,
	RockSpawnMult = 1,
	RockSpawnFlat = 0,
	RockShatter = 0,
	LaserChargeMult = 1,
	LaserChargeFlat = 0,
	LaserFireMult = 1,
	LaserFireFlat = 0,
	LaserCooldownMult = 1,
	LaserCooldownFlat = 0,
	ComboBonusMult = 1,
	FruitGoalDelta = 0,
	RockSpawnBonus = 0,
	SawSpawnBonus = 0,
	LaserSpawnBonus = 0,
	adrenaline = nil,
	AdrenalineDurationBonus = 0,
	AdrenalineBoostBonus = 0,
	ComboWindowBonus = 0,
	ComboBonusFlat = 0,
	ShopSlots = 0,
	WallPortal = false,
	dash = nil,
	TimeSlow = nil,
}

local function GetEventPosition(data)
	if data and data.x and data.y then
		return data.x, data.y
	end

	if Snake.GetHead then
		local hx, hy = Snake:GetHead()
		if hx and hy then
			return hx, hy
		end
	end

	return nil, nil
end

UpgradeHelpers.GetEventPosition = GetEventPosition

function UpgradeHelpers.CelebrateUpgrade(label, data, options)
	options = options or {}

	local fx = options.x
	local fy = options.y
	if not fx or not fy then
		fx, fy = GetEventPosition(data)
	end

	if fx and fy and label and not options.skipText and FloatingText then
		local TextColor = options.textColor or options.color or {1, 1, 1, 1}
		local TextOffset = options.textOffset or 44
		local TextScale = options.textScale or 1.05
		local TextLife = options.textLife or 56
		FloatingText:add(label, fx, fy - TextOffset, TextColor, TextScale, TextLife)
	end

	if fx and fy and not options.skipVisuals and UpgradeVisuals then
		local VisualOptions
		if options.visual then
			VisualOptions = deepcopy(options.visual)
		else
			VisualOptions = {}
			VisualOptions.outerRadius = options.visualRadius or VisualOptions.outerRadius
			VisualOptions.innerRadius = options.visualInnerRadius or VisualOptions.innerRadius
			VisualOptions.ringCount = options.visualRings or VisualOptions.ringCount
			VisualOptions.ringSpacing = options.visualRingSpacing or VisualOptions.ringSpacing
			VisualOptions.life = options.visualLife or VisualOptions.life
		end

		if VisualOptions then
			if options.visualBadge and VisualOptions.badge == nil then
				VisualOptions.badge = options.visualBadge
			end
			if options.visualVariant and VisualOptions.variant == nil then
				VisualOptions.variant = options.visualVariant
			end
			if options.visualAddBlend ~= nil and VisualOptions.addBlend == nil then
				VisualOptions.addBlend = options.visualAddBlend
			end
			if options.visualGlowAlpha and VisualOptions.glowAlpha == nil then
				VisualOptions.glowAlpha = options.visualGlowAlpha
			end
			if options.visualHaloAlpha and VisualOptions.haloAlpha == nil then
				VisualOptions.haloAlpha = options.visualHaloAlpha
			end

			local VisualColor = VisualOptions.color or options.visualColor or options.color or options.textColor
			if not VisualColor then
				VisualColor = { 1, 1, 1, 1 }
			end

			VisualOptions.color = VisualColor
			VisualOptions.outerRadius = VisualOptions.outerRadius or 44
			VisualOptions.innerRadius = VisualOptions.innerRadius or 12
			VisualOptions.ringCount = VisualOptions.ringCount or 2
			VisualOptions.life = VisualOptions.life or 0.72

			UpgradeVisuals:spawn(fx, fy, VisualOptions)
		end
	end

	if fx and fy and not options.skipParticles and Particles then
		local ParticleOptions
		if options.particles then
			ParticleOptions = deepcopy(options.particles)
		else
			ParticleOptions = {
				count = options.particleCount or 12,
				speed = options.particleSpeed or 110,
				life = options.particleLife or 0.45,
				size = options.particleSize or 4,
				spread = options.particleSpread or math.pi * 2,
				AngleJitter = options.particleAngleJitter,
				SpeedVariance = options.particleSpeedVariance,
				ScaleMin = options.particleScaleMin,
				ScaleVariance = options.particleScaleVariance,
				drag = options.particleDrag,
				gravity = options.particleGravity,
				FadeTo = options.particleFadeTo,
			}
		end

		ParticleOptions = ParticleOptions or {}
		if ParticleOptions.count == nil then
			ParticleOptions.count = 12
		end
		if ParticleOptions.color == nil then
			ParticleOptions.color = options.particleColor or options.color
		end

		Particles:SpawnBurst(fx, fy, ParticleOptions)
	end
end

return UpgradeHelpers
