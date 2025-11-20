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
local BASELINE_PLAN

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

local function chance(p)
	return love.math.random() < p
end

function generateFloorPlan()
	local Lasers = love.math.random(0, 1)

	return {
		[1] = {
			fruitGoal = 12,
			rocks = 6 + (chance(0.5) and 1 or 0),
			saws = 2,
			laserCount = 0,
			dartCount = 0,
			rockSpawnChance = 0.22,
			sawSpeedMult = 1.02,
			sawSpinMult = 0.96,
		},
		[2] = {
			fruitGoal = 15,
			rocks = 7 + (chance(0.5) and 1 or 0),
			saws = 2,
			laserCount = 0,
			dartCount = love.math.random(0, 1),
			rockSpawnChance = 0.26,
			sawSpeedMult = 1.1,
			sawSpinMult = 1.02,
		},
		[3] = {
			fruitGoal = 18,
			rocks = 8 + (chance(0.5) and 1 or 0),
			saws = 3,
			laserCount = 0,
			dartCount = 1,
			rockSpawnChance = 0.29,
			sawSpeedMult = 1.18,
			sawSpinMult = 1.08,
		},
		[4] = {
			fruitGoal = 21,
			rocks = 9 + (chance(0.5) and 1 or 0),
			saws = 3,
			laserCount = 0,
			dartCount = 1,
			rockSpawnChance = 0.31,
			sawSpeedMult = 1.26,
			sawSpinMult = 1.14,
		},
		[5] = {
			fruitGoal = 24,
			rocks = 10 + (chance(0.5) and 1 or 0),
			saws = 3,
			laserCount = Lasers,
			dartCount = (Lasers == 0) and 1 or 0,
			rockSpawnChance = 0.34,
			sawSpeedMult = 1.34,
			sawSpinMult = 1.22,
		},
		[6] = {
			fruitGoal = 27,
			rocks = 11 + (chance(0.5) and 1 or 0),
			saws = 4,
			laserCount = 1,
			dartCount = 0,
			rockSpawnChance = 0.37,
			sawSpeedMult = 1.42,
			sawSpinMult = 1.28,
		},
		[7] = {
			fruitGoal = 30,
			rocks = 12 + (chance(0.5) and 1 or 0),
			saws = 4,
			laserCount = (chance(0.2) and 2 or 1),
			dartCount = 0,
			rockSpawnChance = 0.4,
			sawSpeedMult = 1.48,
			sawSpinMult = 1.34,
		},
		[8] = {
			fruitGoal = 33,
			rocks = 13 + (chance(0.5) and 1 or 0),
			saws = 4,
			laserCount = 2,
			dartCount = 0,
			rockSpawnChance = 0.43,
			sawSpeedMult = 1.56,
			sawSpinMult = 1.42,
		},
	}
end

-- Now you can call FloorPlan.getBaselinePlan(os.time()) for fresh chaos, or FloorPlan.getBaselinePlan(12345) for deterministic daily-seeded runs.
function FloorPlan.getBaselinePlan(seed)
	if seed then love.math.setRandomSeed(seed) end
	BASELINE_PLAN = generateFloorPlan()
	return BASELINE_PLAN
end

function FloorPlan.getBaselinePlanForFloor(floorIndex)
	if not BASELINE_PLAN then
		FloorPlan.getBaselinePlan()
	end

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
	context.dartCount = 0

	return context
end

FloorPlan.getLaserCap = getLaserCap

return FloorPlan