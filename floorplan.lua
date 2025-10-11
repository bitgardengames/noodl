local Floors = require("floors")

local FloorPlan = {}

local FINAL_FLOOR = #Floors
local BASE_LASER_CAP = 3
local BASE_DART_CAP = 4
local MAX_LASER_COUNT = 5
local LASER_GROWTH_SPAN = 8
local LASER_GROWTH_EXPONENT = 1.35
local EXTRA_FLOOR_FRUIT_STEP = 3

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
                fruitGoal = 12,
		rocks = 4,
		saws = 1,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.24,
		sawSpeedMult = 1.08,
		sawSpinMult = 1.0,
		sawStall = 0.9,
	},
        [2] = {
                fruitGoal = 16,
		rocks = 5,
		saws = 1,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.26,
		sawSpeedMult = 1.14,
		sawSpinMult = 1.06,
		sawStall = 0.84,
	},
        [3] = {
                fruitGoal = 20,
		rocks = 6,
		saws = 2,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.28,
		sawSpeedMult = 1.2,
		sawSpinMult = 1.12,
		sawStall = 0.78,
	},
        [4] = {
                fruitGoal = 24,
		rocks = 7,
		saws = 2,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.3,
		sawSpeedMult = 1.26,
		sawSpinMult = 1.18,
		sawStall = 0.72,
	},
        [5] = {
                fruitGoal = 28,
		rocks = 8,
		saws = 3,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.33,
		sawSpeedMult = 1.32,
		sawSpinMult = 1.24,
		sawStall = 0.66,
	},
        [6] = {
                fruitGoal = 32,
		rocks = 9,
		saws = 3,
		laserCount = 0,
		dartCount = 0,
		rockSpawnChance = 0.36,
		sawSpeedMult = 1.38,
		sawSpinMult = 1.3,
		sawStall = 0.6,
	},
        [7] = {
                fruitGoal = 35,
		rocks = 10,
		saws = 4,
		laserCount = 0,
		dartCount = 1,
		rockSpawnChance = 0.39,
		sawSpeedMult = 1.44,
		sawSpinMult = 1.36,
		sawStall = 0.54,
	},
        [8] = {
                fruitGoal = 38,
		rocks = 11,
		saws = 4,
		laserCount = 0,
		dartCount = 1,
		rockSpawnChance = 0.42,
		sawSpeedMult = 1.5,
		sawSpinMult = 1.42,
		sawStall = 0.48,
	},
        [9] = {
                fruitGoal = 41,
		rocks = 12,
		saws = 4,
		laserCount = 0,
		dartCount = 1,
		rockSpawnChance = 0.45,
		sawSpeedMult = 1.56,
		sawSpinMult = 1.48,
		sawStall = 0.44,
	},
        [10] = {
                fruitGoal = 44,
		rocks = 13,
		saws = 5,
		laserCount = 0,
		dartCount = 1,
		rockSpawnChance = 0.48,
		sawSpeedMult = 1.62,
		sawSpinMult = 1.54,
		sawStall = 0.4,
	},
        [11] = {
                fruitGoal = 47,
		rocks = 14,
		saws = 5,
		laserCount = 0,
		dartCount = 1,
		rockSpawnChance = 0.5,
		sawSpeedMult = 1.68,
		sawSpinMult = 1.6,
		sawStall = 0.36,
	},
        [12] = {
                fruitGoal = 50,
		rocks = 15,
		saws = 6,
		laserCount = 0,
		dartCount = 2,
		rockSpawnChance = 0.52,
		sawSpeedMult = 1.74,
		sawSpinMult = 1.66,
		sawStall = 0.32,
	},
        [13] = {
                fruitGoal = 52,
		rocks = 16,
		saws = 6,
		laserCount = 1,
		dartCount = 2,
		rockSpawnChance = 0.54,
		sawSpeedMult = 1.8,
		sawSpinMult = 1.72,
		sawStall = 0.28,
	},
        [14] = {
                fruitGoal = 54,
		rocks = 17,
		saws = 7,
		laserCount = 1,
		dartCount = 2,
		rockSpawnChance = 0.56,
		sawSpeedMult = 1.84,
		sawSpinMult = 1.76,
		sawStall = 0.24,
	},
        [15] = {
                fruitGoal = 56,
		rocks = 19,
		saws = 7,
		laserCount = 2,
		dartCount = 2,
		rockSpawnChance = 0.58,
		sawSpeedMult = 1.88,
		sawSpinMult = 1.8,
		sawStall = 0.2,
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
	context.sawStall = math.max(0.14, (lastPlan.sawStall or 0.2) - extraFloors * 0.02)

	return context
end

FloorPlan.getLaserCap = getLaserCap
FloorPlan.getDartCap = getDartCap

return FloorPlan
