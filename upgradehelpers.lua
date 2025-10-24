local Snake = require("snake")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local Localization = require("localization")

local UpgradeHelpers = {}

function UpgradeHelpers.getUpgradeString(id, field)
	if not id or not field then return nil end
	return Localization:get("upgrades." .. id .. "." .. field)
end

UpgradeHelpers.rarities = {
	common = {
		weight = 46,
		labelKey = "upgrades.rarities.common",
		color = {0.75, 0.82, 0.88, 1},
	},
	uncommon = {
		weight = 30,
		labelKey = "upgrades.rarities.uncommon",
		color = {0.55, 0.78, 0.58, 1},
	},
	rare = {
		weight = 16,
		labelKey = "upgrades.rarities.rare",
		color = {0.54, 0.72, 0.96, 1},
	},
	epic = {
		weight = 5.2,
		labelKey = "upgrades.rarities.epic",
		color = {0.76, 0.56, 0.88, 1},
	},
	legendary = {
		weight = 1.4,
		labelKey = "upgrades.rarities.legendary",
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

UpgradeHelpers.defaultEffects = {
	sawSpeedMult = 1,
	sawSpinMult = 1,
	sawStall = 0,
	sawSinkDuration = 0,
	rockSpawnMult = 1,
	rockSpawnFlat = 0,
	rockShatter = 0,
        laserChargeMult = 1,
        laserChargeFlat = 0,
        laserFireMult = 1,
        laserFireFlat = 0,
        laserCooldownMult = 1,
        laserCooldownFlat = 0,
        comboBonusMult = 1,
        fruitValueMult = 1,
        fruitGoalDelta = 0,
        rockSpawnBonus = 0,
        sawSpawnBonus = 0,
        laserSpawnBonus = 0,
        adrenaline = nil,
        adrenalineDurationBonus = 0,
        adrenalineBoostBonus = 0,
        comboWindowBonus = 0,
        comboBonusFlat = 0,
        shopSlots = 0,
        shopGuaranteedRare = false,
        shopMinimumRarity = nil,
        wallPortal = false,
        dash = nil,
        timeSlow = nil,
        gluttonsWake = false,
}

local function getEventPosition(data)
	if data and data.x and data.y then
		return data.x, data.y
	end

	if Snake.getHead then
		local hx, hy = Snake:getHead()
		if hx and hy then
			return hx, hy
		end
	end

	return nil, nil
end

UpgradeHelpers.getEventPosition = getEventPosition

function UpgradeHelpers.celebrateUpgrade(label, data, options)
	options = options or {}

	local fx = options.x
	local fy = options.y
	if not fx or not fy then
		fx, fy = getEventPosition(data)
	end

	if fx and fy and label and not options.skipText and FloatingText then
		local textColor = options.textColor or options.color or {1, 1, 1, 1}
		local textOffset = options.textOffset or 44
		local textScale = options.textScale or 1.05
		local textLife = options.textLife or 56
		FloatingText:add(label, fx, fy - textOffset, textColor, textScale, textLife)
	end

	if fx and fy and not options.skipParticles and Particles then
		local particleOptions
		if options.particles then
			particleOptions = deepcopy(options.particles)
		else
			particleOptions = {
				count = options.particleCount or 12,
				speed = options.particleSpeed or 110,
				life = options.particleLife or 0.45,
				size = options.particleSize or 4,
				spread = options.particleSpread or math.pi * 2,
				angleJitter = options.particleAngleJitter,
				speedVariance = options.particleSpeedVariance,
				scaleMin = options.particleScaleMin,
				scaleVariance = options.particleScaleVariance,
				drag = options.particleDrag,
				gravity = options.particleGravity,
				fadeTo = options.particleFadeTo,
			}
		end

		particleOptions = particleOptions or {}
		if particleOptions.count == nil then
			particleOptions.count = 12
		end
		if particleOptions.color == nil then
			particleOptions.color = options.particleColor or options.color
		end

		Particles:spawnBurst(fx, fy, particleOptions)
	end
end

return UpgradeHelpers
