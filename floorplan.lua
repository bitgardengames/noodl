local Floors = require("floors")

local floor = math.floor
local max = math.max
local min = math.min

local FloorPlan = {}

local FINAL_FLOOR = #Floors
local BASE_LASER_CAP = 3
local MAX_LASER_COUNT = 5
local LASER_GROWTH_SPAN = 8
local LASER_GROWTH_EXPONENT = 1.35
local EXTRA_FLOOR_FRUIT_STEP = 2

local function computeLaserProgression(baseLaser, extraFloors, maxLasers)
	baseLaser = baseLaser or 0
	extraFloors = max(0, extraFloors or 0)
	maxLasers = maxLasers or MAX_LASER_COUNT

	local available = max(0, maxLasers - baseLaser)
	if available <= 0 then
		return min(maxLasers, baseLaser)
	end

	local maxFloors = available * LASER_GROWTH_SPAN
	if maxFloors <= 0 then
		return min(maxLasers, baseLaser)
	end

	local normalized = min(1, extraFloors / maxFloors)
	local eased = normalized ^ LASER_GROWTH_EXPONENT
	local additional = floor(eased * available + 1e-6)

	return min(maxLasers, baseLaser + additional)
end

local function getLaserCap(floorIndex)
	floorIndex = floorIndex or 1

	if FINAL_FLOOR > 0 and floorIndex < FINAL_FLOOR then
		return BASE_LASER_CAP
	end

	return nil
end

local function applyLaserCap(context)
	if not context then
		return
	end

	local cap = getLaserCap(context.floor)
	if cap and context.laserCount ~= nil then
		context.laserCount = min(cap, context.laserCount)
	end
end

local BASELINE_PLAN = {
        [1] = {
                fruitGoal = 12,
                rocks = 4,
                saws = 1,
                laserCount = 0,
                rockSpawnChance = 0.24,
                sawSpeedMult = 1.08,
                sawSpinMult = 1.0,
                sawStall = 0,
        },
        [2] = {
                fruitGoal = 15,
                rocks = 5,
                saws = 1,
                laserCount = 0,
                rockSpawnChance = 0.26,
                sawSpeedMult = 1.14,
                sawSpinMult = 1.06,
                sawStall = 0,
        },
        [3] = {
                fruitGoal = 18,
                rocks = 6,
                saws = 2,
                laserCount = 0,
                rockSpawnChance = 0.28,
                sawSpeedMult = 1.2,
                sawSpinMult = 1.12,
                sawStall = 0,
        },
        [4] = {
                fruitGoal = 21,
                rocks = 7,
                saws = 2,
                laserCount = 0,
                rockSpawnChance = 0.3,
                sawSpeedMult = 1.26,
                sawSpinMult = 1.18,
                sawStall = 0,
        },
        [5] = {
                fruitGoal = 24,
                rocks = 8,
                saws = 3,
                laserCount = 1,
                rockSpawnChance = 0.33,
                sawSpeedMult = 1.32,
                sawSpinMult = 1.24,
                sawStall = 0,
        },
        [6] = {
                fruitGoal = 27,
                rocks = 9,
                saws = 3,
                laserCount = 1,
                rockSpawnChance = 0.36,
                sawSpeedMult = 1.38,
                sawSpinMult = 1.3,
                sawStall = 0,
        },
        [7] = {
                fruitGoal = 30,
                rocks = 10,
                saws = 4,
                laserCount = 1,
                rockSpawnChance = 0.39,
                sawSpeedMult = 1.44,
                sawSpinMult = 1.36,
                sawStall = 0,
        },
        [8] = {
                fruitGoal = 33,
                rocks = 11,
                saws = 4,
                laserCount = 1,
                rockSpawnChance = 0.42,
                sawSpeedMult = 1.5,
                sawSpinMult = 1.42,
                sawStall = 0,
        },
        [9] = {
                fruitGoal = 35,
		rocks = 12,
		saws = 4,
		laserCount = 1,
		rockSpawnChance = 0.45,
		sawSpeedMult = 1.56,
		sawSpinMult = 1.48,
		sawStall = 0,
	},
        [10] = {
                fruitGoal = 38,
		rocks = 13,
		saws = 5,
		laserCount = 2,
		rockSpawnChance = 0.48,
		sawSpeedMult = 1.62,
		sawSpinMult = 1.54,
		sawStall = 0,
	},
        [11] = {
                fruitGoal = 41,
		rocks = 14,
		saws = 5,
		laserCount = 2,
		rockSpawnChance = 0.5,
		sawSpeedMult = 1.68,
		sawSpinMult = 1.6,
		sawStall = 0,
	},
        [12] = {
                fruitGoal = 44,
		rocks = 15,
		saws = 6,
		laserCount = 2,
		rockSpawnChance = 0.52,
		sawSpeedMult = 1.74,
		sawSpinMult = 1.66,
		sawStall = 0,
	},
        [13] = {
                fruitGoal = 47,
		rocks = 16,
		saws = 6,
		laserCount = 2,
		rockSpawnChance = 0.54,
		sawSpeedMult = 1.8,
		sawSpinMult = 1.72,
		sawStall = 0,
	},
        [14] = {
                fruitGoal = 50,
		rocks = 17,
		saws = 7,
		laserCount = 2,
		rockSpawnChance = 0.56,
		sawSpeedMult = 1.84,
		sawSpinMult = 1.76,
		sawStall = 0,
	},
        [15] = {
                fruitGoal = 53,
		rocks = 19,
		saws = 7,
		laserCount = 3,
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
	floorIndex = max(1, floorIndex or 1)
	return BASELINE_PLAN[floorIndex]
end

function FloorPlan.buildBaselineFloorContext(floorNum)
	local floorIndex = max(1, floorNum or 1)
	local plan = FloorPlan.getBaselinePlanForFloor(floorIndex)

	if plan then
		local context = {floor = floorIndex}
		for key, value in pairs(plan) do
			context[key] = value
		end
                applyLaserCap(context)
                return context
        end

	local baselinePlan = FloorPlan.getBaselinePlan()
	local lastIndex = #baselinePlan
	local lastPlan = baselinePlan[lastIndex]
	local extraFloors = floorIndex - lastIndex
	local context = {floor = floorIndex}

	for key, value in pairs(lastPlan) do
		context[key] = value
	end

	local lastFruitGoal = lastPlan.fruitGoal or (EXTRA_FLOOR_FRUIT_STEP * lastIndex)
	context.fruitGoal = max(context.fruitGoal or 1, lastFruitGoal + extraFloors * EXTRA_FLOOR_FRUIT_STEP)
	context.rocks = max(0, min(40, (lastPlan.rocks or 19) + extraFloors))
	context.saws = max(1, min(8, (lastPlan.saws or 7) + floor(extraFloors / 3)))
	local baseLaser = lastPlan.laserCount or 0
        context.laserCount = computeLaserProgression(baseLaser, extraFloors, MAX_LASER_COUNT)
        applyLaserCap(context)
	context.rockSpawnChance = min(0.68, (lastPlan.rockSpawnChance or 0.58) + extraFloors * 0.015)
	context.sawSpeedMult = min(1.95, (lastPlan.sawSpeedMult or 1.88) + extraFloors * 0.03)
	context.sawSpinMult = min(1.88, (lastPlan.sawSpinMult or 1.8) + extraFloors * 0.025)
	context.sawStall = 0

	return context
end

FloorPlan.getLaserCap = getLaserCap

return FloorPlan
