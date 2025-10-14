local Floors = require("floors")

local FloorPlan = {}

local FINAL_FLOOR = #Floors
local BASE_LASER_CAP = 3
local BASE_DART_CAP = 4
local MAX_LASER_COUNT = 5
local LASER_GROWTH_SPAN = 8
local LASER_GROWTH_EXPONENT = 1.35
local EXTRA_FLOOR_FRUIT_STEP = 2

local function clamp(value, minValue, maxValue)
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return value
end

local function cloneTable(value)
        if type(value) ~= "table" then
                return value
        end

        local result = {}
        for key, entry in pairs(value) do
                result[key] = cloneTable(entry)
        end
        return result
end

local function cloneSequence(sequence)
        if type(sequence) ~= "table" then
                return sequence
        end

        local copy = {}
        for index, value in ipairs(sequence) do
                if type(value) == "table" then
                        copy[index] = cloneTable(value)
                else
                        copy[index] = value
                end
        end

        return copy
end

local function normalizeDensityRange(range, fallback)
        fallback = fallback or { min = 0.05, max = 0.11 }

        if type(range) == "number" then
                local value = clamp(range, 0, 0.45)
                return value, value
        end

        if type(range) ~= "table" then
                return fallback.min, fallback.max
        end

        local minValue
        local maxValue

        if range.min or range.max then
                minValue = range.min or range.max or fallback.min
                maxValue = range.max or range.min or fallback.max
        else
                minValue = range[1] or fallback.min
                maxValue = range[2] or minValue or fallback.max
        end

        minValue = clamp(minValue, 0, 0.45)
        maxValue = clamp(maxValue, 0, 0.45)

        if maxValue < minValue then
                minValue, maxValue = maxValue, minValue
        end

        return minValue, maxValue
end

local DEFAULT_LAYOUT_CONFIG = {
        densityRange = { min = 0.05, max = 0.11 },
        templates = {
                { name = "stone_corner", weight = 1.0 },
                { name = "stone_patch", weight = 1.1 },
                { name = "stone_bar", weight = 0.95 },
                { name = "stone_cross", weight = 0.9 },
                { name = "stone_spur", weight = 0.92 },
                { name = "stone_table", weight = 0.72 },
                { name = "pillar", weight = 0.45 },
                { name = "pillar_pair", weight = 0.35 },
        },
        hazardExclusions = { lasers = true, darts = true },
        keepSpawnRing = 2,
        seedOffset = 0,
}

local LAYOUT_PRESETS = {
        botanical = {
                templates = {
                        { name = "foliage_tuft", weight = 1.35 },
                        { name = "foliage_patch", weight = 1.2 },
                        { name = "foliage_cluster", weight = 0.95 },
                        { name = "foliage_line", weight = 0.85 },
                        { name = "stone_corner", weight = 0.75 },
                        { name = "stone_patch", weight = 0.7 },
                },
                densityRange = { min = 0.045, max = 0.095 },
        },
        cavern = {
                templates = {
                        { name = "stone_corner", weight = 1.2 },
                        { name = "stone_patch", weight = 1.2 },
                        { name = "stone_bar", weight = 1.05 },
                        { name = "stone_spur", weight = 1.0 },
                        { name = "pillar", weight = 0.55 },
                        { name = "pillar_pair", weight = 0.45 },
                },
                densityRange = { min = 0.05, max = 0.1 },
        },
        arctic = {
                templates = {
                        { name = "stone_cross", weight = 1.15 },
                        { name = "stone_bar", weight = 1.1 },
                        { name = "stone_patch", weight = 1.05 },
                        { name = "stone_table", weight = 0.72 },
                        { name = "pillar", weight = 0.6 },
                },
                densityRange = { min = 0.052, max = 0.105 },
        },
        machine = {
                templates = {
                        { name = "stone_patch", weight = 1.25 },
                        { name = "stone_bar", weight = 1.15 },
                        { name = "stone_table", weight = 0.9 },
                        { name = "stone_cross", weight = 1.1 },
                        { name = "pillar", weight = 0.75 },
                        { name = "pillar_pair", weight = 0.55 },
                },
                densityRange = { min = 0.055, max = 0.11 },
                keepSpawnRing = 3,
        },
        desert = {
                templates = {
                        { name = "stone_corner", weight = 1.1 },
                        { name = "stone_bar", weight = 1.15 },
                        { name = "stone_patch", weight = 1.1 },
                        { name = "stone_spur", weight = 1.05 },
                        { name = "pillar", weight = 0.6 },
                },
                densityRange = { min = 0.055, max = 0.115 },
        },
        volcanic = {
                templates = {
                        { name = "stone_patch", weight = 1.3 },
                        { name = "stone_cross", weight = 1.2 },
                        { name = "stone_bar", weight = 1.1 },
                        { name = "stone_table", weight = 0.85 },
                        { name = "pillar", weight = 0.65 },
                },
                densityRange = { min = 0.06, max = 0.12 },
                keepSpawnRing = 3,
        },
}

local FLOOR_LAYOUT_OVERRIDES = {
        [1] = {
                preset = "botanical",
                densityRange = { min = 0.045, max = 0.085 },
                seedOffset = 11,
                variants = {
                        {
                                id = "clearings",
                                name = "Clearings",
                                densityRange = { min = 0.04, max = 0.07 },
                                templates = {
                                        { name = "foliage_tuft", weight = 1.6 },
                                        { name = "foliage_patch", weight = 1.35 },
                                        { name = "foliage_line", weight = 1.1 },
                                        { name = "stone_single", weight = 0.4 },
                                },
                        },
                        {
                                id = "root_maze",
                                name = "Root Maze",
                                densityRange = { min = 0.048, max = 0.082 },
                                templates = {
                                        { name = "stone_corner", weight = 1.1 },
                                        { name = "stone_spur", weight = 1.15 },
                                        { name = "stone_table", weight = 0.7 },
                                        { name = "foliage_tuft", weight = 0.85 },
                                },
                        },
                        {
                                id = "pillar_grove",
                                name = "Pillar Grove",
                                densityRange = { min = 0.045, max = 0.08 },
                                templates = {
                                        { name = "pillar", weight = 0.82 },
                                        { name = "pillar_pair", weight = 0.65 },
                                        { name = "stone_corner", weight = 0.92 },
                                        { name = "foliage_cluster", weight = 1.05 },
                                },
                                keepSpawnRing = 3,
                        },
                },
        },
        [2] = {
                preset = "cavern",
                densityRange = { min = 0.05, max = 0.088 },
                seedOffset = 23,
                variants = {
                        {
                                id = "ledge_pools",
                                name = "Ledge Pools",
                                templates = {
                                        { name = "stone_table", weight = 0.85 },
                                        { name = "stone_corner", weight = 1.25 },
                                        { name = "stone_bar", weight = 1.15 },
                                        { name = "pillar", weight = 0.55 },
                                },
                        },
                        {
                                id = "stalagmites",
                                name = "Stalagmites",
                                templates = {
                                        { name = "pillar", weight = 0.8 },
                                        { name = "pillar_pair", weight = 0.7 },
                                        { name = "stone_spur", weight = 1.05 },
                                        { name = "stone_patch", weight = 1.1 },
                                },
                                keepSpawnRing = 3,
                        },
                },
        },
        [3] = { preset = "botanical", densityRange = { min = 0.05, max = 0.094 }, seedOffset = 37 },
        [4] = { preset = "cavern", densityRange = { min = 0.052, max = 0.1 }, seedOffset = 41 },
        [5] = {
                preset = "machine",
                densityRange = { min = 0.055, max = 0.105 },
                seedOffset = 53,
                variants = {
                        {
                                id = "gantry",
                                name = "Gantry",
                                templates = {
                                        { name = "stone_table", weight = 1.2 },
                                        { name = "stone_bar", weight = 1.25 },
                                        { name = "pillar_pair", weight = 0.7 },
                                        { name = "stone_corner", weight = 0.9 },
                                },
                        },
                        {
                                id = "crates",
                                name = "Crates",
                                templates = {
                                        { name = "stone_patch", weight = 1.35 },
                                        { name = "stone_spur", weight = 1.0 },
                                        { name = "stone_single", weight = 0.6 },
                                        { name = "pillar", weight = 0.6 },
                                },
                        },
                },
        },
        [6] = { preset = "arctic", densityRange = { min = 0.056, max = 0.108 }, seedOffset = 67 },
        [7] = { preset = "botanical", densityRange = { min = 0.057, max = 0.11 }, seedOffset = 71 },
        [8] = { preset = "arctic", densityRange = { min = 0.058, max = 0.115 }, seedOffset = 83 },
        [9] = {
                preset = "desert",
                densityRange = { min = 0.06, max = 0.12 },
                seedOffset = 97,
                variants = {
                        {
                                id = "dunes",
                                name = "Dunes",
                                densityRange = { min = 0.058, max = 0.115 },
                                templates = {
                                        { name = "stone_spur", weight = 1.2 },
                                        { name = "stone_table", weight = 0.85 },
                                        { name = "stone_corner", weight = 1.05 },
                                        { name = "pillar", weight = 0.6 },
                                },
                        },
                        {
                                id = "market_stalls",
                                name = "Market Stalls",
                                templates = {
                                        { name = "stone_bar", weight = 1.25 },
                                        { name = "stone_patch", weight = 1.2 },
                                        { name = "pillar_pair", weight = 0.75 },
                                        { name = "stone_single", weight = 0.55 },
                                },
                                keepSpawnRing = 3,
                        },
                },
        },
        [10] = { preset = "volcanic", densityRange = { min = 0.062, max = 0.125 }, seedOffset = 103 },
        [11] = { preset = "volcanic", densityRange = { min = 0.064, max = 0.13 }, seedOffset = 109 },
        [12] = { preset = "volcanic", densityRange = { min = 0.066, max = 0.135 }, seedOffset = 127 },
        [13] = { preset = "machine", densityRange = { min = 0.068, max = 0.14 }, seedOffset = 139, keepSpawnRing = 3 },
        [14] = { preset = "machine", densityRange = { min = 0.07, max = 0.145 }, seedOffset = 151, keepSpawnRing = 3 },
        [15] = { preset = "volcanic", densityRange = { min = 0.072, max = 0.15 }, seedOffset = 163, keepSpawnRing = 3 },
}

local THEME_PRESET_MAP = {
        botanical = "botanical",
        cavern = "cavern",
        fungal = "botanical",
        oceanic = "cavern",
        arctic = "arctic",
        machine = "machine",
        desert = "desert",
        volcanic = "volcanic",
        lava = "volcanic",
}

local function mergeLayoutConfig(base, override)
        local result = cloneTable(base)

        if not override then
                return result
        end

        for key, value in pairs(override) do
                if key == "templates" then
                        result.templates = cloneSequence(value)
                elseif key == "variants" then
                        result.variants = cloneSequence(value)
                elseif key == "hazardExclusions" then
                        result.hazardExclusions = result.hazardExclusions or {}
                        for flag, enabled in pairs(value) do
                                result.hazardExclusions[flag] = enabled and true or false
                        end
                elseif key == "densityRange" then
                        result.densityRange = cloneTable(value)
                else
                        result[key] = cloneTable(value)
                end
        end

        return result
end

local function chooseLayoutVariant(config, floorIndex, plan)
        if not config then
                return nil, nil
        end

        local variants = config.variants
        if not variants or #variants == 0 then
                return nil, nil
        end

        local seedBase = (config.variantSeedOffset or config.seedOffset or 0) + floorIndex * 977

        if plan then
                seedBase = seedBase + math.floor((plan.rocks or 0) * 31)
                seedBase = seedBase + math.floor((plan.saws or 0) * 43)
                seedBase = seedBase + math.floor((plan.laserCount or 0) * 23)
                seedBase = seedBase + math.floor((plan.dartCount or 0) * 17)
        end

        local index
        if love and love.math and love.math.newRandomGenerator then
                local rng = love.math.newRandomGenerator(seedBase)
                index = rng:random(1, #variants)
        else
                index = ((seedBase % #variants) + 1)
        end

        return variants[index], index
end

local function getArenaLayoutConfig(floorIndex, plan)
        floorIndex = math.max(1, floorIndex or 1)

        local config = cloneTable(DEFAULT_LAYOUT_CONFIG)
        local override = FLOOR_LAYOUT_OVERRIDES[floorIndex]
        local floorData = Floors[floorIndex]

        local presetName = override and override.preset
        if not presetName and floorData then
                local theme = floorData.backgroundVariant or floorData.backgroundTheme
                if theme then
                        presetName = THEME_PRESET_MAP[theme]
                end
        end

        if presetName and LAYOUT_PRESETS[presetName] then
                config = mergeLayoutConfig(config, LAYOUT_PRESETS[presetName])
        end

        if override then
                config = mergeLayoutConfig(config, override)
        end

        local selectedVariant, variantIndex = chooseLayoutVariant(config, floorIndex, plan)
        if selectedVariant then
                local variantId = selectedVariant.id or selectedVariant.name or selectedVariant.label
                config = mergeLayoutConfig(config, selectedVariant)
                config.variantIndex = variantIndex
                config.variantId = variantId or variantIndex
                config.variantName = selectedVariant.name or selectedVariant.label or variantId
        end

        config.variants = nil

        if not config.templates or #config.templates == 0 then
                config.templates = cloneSequence(DEFAULT_LAYOUT_CONFIG.templates)
        end

        local minDensity, maxDensity = normalizeDensityRange(config.densityRange or config.density, DEFAULT_LAYOUT_CONFIG.densityRange)
        local progression = math.max(0, floorIndex - 1) * 0.0035
        minDensity = clamp(minDensity + progression * 0.6, 0.035, 0.32)
        maxDensity = clamp(maxDensity + progression, minDensity + 0.01, 0.36)
        config.densityRange = { min = minDensity, max = maxDensity }
        config.density = nil

        config.hazardExclusions = config.hazardExclusions or {}
        if plan then
                if (plan.laserCount or 0) > 0 then
                        config.hazardExclusions.lasers = true
                end

                if (plan.dartCount or 0) > 0 then
                        config.hazardExclusions.darts = true
                end

                if (plan.saws or 0) >= 3 then
                        config.hazardExclusions.saws = true
                end
        end

        config.keepSpawnRing = config.keepSpawnRing or 2

        local seedOffset = config.seedOffset or 0
        config.seed = seedOffset + floorIndex * 211 + math.floor(((plan and plan.saws) or 0) * 13) + math.floor(((config.variantIndex or 0) * 503))

        return config
end

local function computeLaserProgression(baseLaser, extraFloors, maxLasers)
	baseLaser = baseLaser or 0
	extraFloors = math.max(0, extraFloors or 0)
	maxLasers = maxLasers or MAX_LASER_COUNT

	local available = math.max(0, maxLasers - baseLaser)
	if available <= 0 then
		return math.min(maxLasers, baseLaser)
	end

	local maxFloors = available * LASER_GROWTH_SPAN
	if maxFloors <= 0 then
		return math.min(maxLasers, baseLaser)
	end

	local normalized = math.min(1, extraFloors / maxFloors)
	local eased = normalized ^ LASER_GROWTH_EXPONENT
	local additional = math.floor(eased * available + 1e-6)

	return math.min(maxLasers, baseLaser + additional)
end

local function getLaserCap(floorIndex)
	floorIndex = floorIndex or 1

	if FINAL_FLOOR > 0 and floorIndex < FINAL_FLOOR then
		return BASE_LASER_CAP
	end

	return nil
end

local function getDartCap(floorIndex)
	floorIndex = floorIndex or 1

	if FINAL_FLOOR > 0 and floorIndex < FINAL_FLOOR then
		return BASE_DART_CAP
	end

	return nil
end

local function applyLaserCap(context)
	if not context then
		return
	end

	local cap = getLaserCap(context.floor)
	if cap and context.laserCount ~= nil then
		context.laserCount = math.min(cap, context.laserCount)
	end
end

local function applyDartCap(context)
	if not context then
		return
	end

	local cap = getDartCap(context.floor)
	if cap and context.dartCount ~= nil then
		context.dartCount = math.min(cap, context.dartCount)
	end
end

local BASELINE_PLAN = {
	[1] = {
		fruitGoal = 10,
		rocks = 4,
		saws = 1,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.24,
		sawSpeedMult = 1.08,
		sawSpinMult = 1.0,
		sawStall = 0,
	},
	[2] = {
		fruitGoal = 13,
		rocks = 5,
		saws = 1,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.26,
		sawSpeedMult = 1.14,
		sawSpinMult = 1.06,
		sawStall = 0,
	},
	[3] = {
		fruitGoal = 16,
		rocks = 6,
		saws = 2,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.28,
		sawSpeedMult = 1.2,
		sawSpinMult = 1.12,
		sawStall = 0,
	},
	[4] = {
		fruitGoal = 19,
		rocks = 7,
		saws = 2,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.3,
		sawSpeedMult = 1.26,
		sawSpinMult = 1.18,
		sawStall = 0,
	},
	[5] = {
		fruitGoal = 22,
		rocks = 8,
		saws = 3,
		laserCount = 1,
		dartCount = 0,
		rockSpawnChance = 0.33,
		sawSpeedMult = 1.32,
		sawSpinMult = 1.24,
		sawStall = 0,
	},
	[6] = {
		fruitGoal = 25,
		rocks = 9,
		saws = 3,
		laserCount = 1,
		dartCount = 0,
		rockSpawnChance = 0.36,
		sawSpeedMult = 1.38,
		sawSpinMult = 1.3,
		sawStall = 0,
	},
	[7] = {
		fruitGoal = 28,
		rocks = 10,
		saws = 4,
		laserCount = 1,
		dartCount = 1,
		rockSpawnChance = 0.39,
		sawSpeedMult = 1.44,
		sawSpinMult = 1.36,
		sawStall = 0,
	},
	[8] = {
		fruitGoal = 31,
		rocks = 11,
		saws = 4,
		laserCount = 1,
		dartCount = 1,
		rockSpawnChance = 0.42,
		sawSpeedMult = 1.5,
		sawSpinMult = 1.42,
		sawStall = 0,
	},
	[9] = {
		fruitGoal = 34,
		rocks = 12,
		saws = 4,
		laserCount = 1,
		dartCount = 1,
		rockSpawnChance = 0.45,
		sawSpeedMult = 1.56,
		sawSpinMult = 1.48,
		sawStall = 0,
	},
	[10] = {
		fruitGoal = 37,
		rocks = 13,
		saws = 5,
		laserCount = 2,
		dartCount = 1,
		rockSpawnChance = 0.48,
		sawSpeedMult = 1.62,
		sawSpinMult = 1.54,
		sawStall = 0,
	},
	[11] = {
		fruitGoal = 40,
		rocks = 14,
		saws = 5,
		laserCount = 2,
		dartCount = 1,
		rockSpawnChance = 0.5,
		sawSpeedMult = 1.68,
		sawSpinMult = 1.6,
		sawStall = 0,
	},
	[12] = {
		fruitGoal = 43,
		rocks = 15,
		saws = 6,
		laserCount = 2,
		dartCount = 2,
		rockSpawnChance = 0.52,
		sawSpeedMult = 1.74,
		sawSpinMult = 1.66,
		sawStall = 0,
	},
	[13] = {
		fruitGoal = 46,
		rocks = 16,
		saws = 6,
		laserCount = 2,
		dartCount = 2,
		rockSpawnChance = 0.54,
		sawSpeedMult = 1.8,
		sawSpinMult = 1.72,
		sawStall = 0,
	},
	[14] = {
		fruitGoal = 49,
		rocks = 17,
		saws = 7,
		laserCount = 2,
		dartCount = 2,
		rockSpawnChance = 0.56,
		sawSpeedMult = 1.84,
		sawSpinMult = 1.76,
		sawStall = 0,
	},
	[15] = {
		fruitGoal = 52,
		rocks = 19,
		saws = 7,
		laserCount = 3,
		dartCount = 2,
		rockSpawnChance = 0.58,
		sawSpeedMult = 1.88,
		sawSpinMult = 1.8,
		sawStall = 0,
	},
}

function FloorPlan.getBaselinePlan()
	return BASELINE_PLAN
end

function FloorPlan.getBaselinePlanForFloor(floorIndex)
	floorIndex = math.max(1, floorIndex or 1)
	return BASELINE_PLAN[floorIndex]
end

function FloorPlan.buildBaselineFloorContext(floorNum)
	local floorIndex = math.max(1, floorNum or 1)
	local plan = FloorPlan.getBaselinePlanForFloor(floorIndex)

        if plan then
                local context = { floor = floorIndex }
                for key, value in pairs(plan) do
                        context[key] = value
                end
                applyLaserCap(context)
                applyDartCap(context)
                context.arenaLayout = getArenaLayoutConfig(floorIndex, context)
                if context.arenaLayout then
                        context.layoutSeed = context.arenaLayout.seed
                        context.layoutVariantId = context.arenaLayout.variantId
                        context.layoutVariantName = context.arenaLayout.variantName
                        context.layoutVariantIndex = context.arenaLayout.variantIndex
                end
                return context
        end

	local baselinePlan = FloorPlan.getBaselinePlan()
	local lastIndex = #baselinePlan
	local lastPlan = baselinePlan[lastIndex]
	local extraFloors = floorIndex - lastIndex
	local context = { floor = floorIndex }

	for key, value in pairs(lastPlan) do
		context[key] = value
	end

	local lastFruitGoal = lastPlan.fruitGoal or (EXTRA_FLOOR_FRUIT_STEP * lastIndex)
	context.fruitGoal = math.max(context.fruitGoal or 1, lastFruitGoal + extraFloors * EXTRA_FLOOR_FRUIT_STEP)
	context.rocks = math.max(0, math.min(40, (lastPlan.rocks or 19) + extraFloors))
	context.saws = math.max(1, math.min(8, (lastPlan.saws or 7) + math.floor(extraFloors / 3)))
	local baseLaser = lastPlan.laserCount or 0
	context.laserCount = computeLaserProgression(baseLaser, extraFloors, MAX_LASER_COUNT)
	local baseDarts = math.min(2, lastPlan.dartCount or 0)
	context.dartCount = baseDarts
	applyLaserCap(context)
	applyDartCap(context)
	context.rockSpawnChance = math.min(0.68, (lastPlan.rockSpawnChance or 0.58) + extraFloors * 0.015)
	context.sawSpeedMult = math.min(1.95, (lastPlan.sawSpeedMult or 1.88) + extraFloors * 0.03)
        context.sawSpinMult = math.min(1.88, (lastPlan.sawSpinMult or 1.8) + extraFloors * 0.025)
        context.sawStall = 0

        context.arenaLayout = getArenaLayoutConfig(floorIndex, context)
        if context.arenaLayout then
                context.layoutSeed = context.arenaLayout.seed
                context.layoutVariantId = context.arenaLayout.variantId
                context.layoutVariantName = context.arenaLayout.variantName
                context.layoutVariantIndex = context.arenaLayout.variantIndex
        end

        return context
end

FloorPlan.getLaserCap = getLaserCap
FloorPlan.getDartCap = getDartCap
FloorPlan.getArenaLayoutConfig = getArenaLayoutConfig

return FloorPlan
