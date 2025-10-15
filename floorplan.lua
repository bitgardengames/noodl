local Floors = require("floors")

local FloorPlan = {}

local FINAL_FLOOR = #Floors
local BASE_LASER_CAP = 3
local BASE_DART_CAP = 4
local MAX_LASER_COUNT = 5
local LASER_GROWTH_SPAN = 8
local LASER_GROWTH_EXPONENT = 1.35
local EXTRA_FLOOR_FRUIT_STEP = 2

local function ComputeLaserProgression(BaseLaser, ExtraFloors, MaxLasers)
	BaseLaser = BaseLaser or 0
	ExtraFloors = math.max(0, ExtraFloors or 0)
	MaxLasers = MaxLasers or MAX_LASER_COUNT

	local available = math.max(0, MaxLasers - BaseLaser)
	if available <= 0 then
		return math.min(MaxLasers, BaseLaser)
	end

	local MaxFloors = available * LASER_GROWTH_SPAN
	if MaxFloors <= 0 then
		return math.min(MaxLasers, BaseLaser)
	end

	local normalized = math.min(1, ExtraFloors / MaxFloors)
	local eased = normalized ^ LASER_GROWTH_EXPONENT
	local additional = math.floor(eased * available + 1e-6)

	return math.min(MaxLasers, BaseLaser + additional)
end

local function GetLaserCap(FloorIndex)
	FloorIndex = FloorIndex or 1

	if FINAL_FLOOR > 0 and FloorIndex < FINAL_FLOOR then
		return BASE_LASER_CAP
	end

	return nil
end

local function GetDartCap(FloorIndex)
	FloorIndex = FloorIndex or 1

	if FINAL_FLOOR > 0 and FloorIndex < FINAL_FLOOR then
		return BASE_DART_CAP
	end

	return nil
end

local function ApplyLaserCap(context)
	if not context then
		return
	end

	local cap = GetLaserCap(context.floor)
	if cap and context.laserCount ~= nil then
		context.laserCount = math.min(cap, context.laserCount)
	end
end

local function ApplyDartCap(context)
	if not context then
		return
	end

	local cap = GetDartCap(context.floor)
	if cap and context.dartCount ~= nil then
		context.dartCount = math.min(cap, context.dartCount)
	end
end

local BASELINE_PLAN = {
	[1] = {
		FruitGoal = 10,
		rocks = 4,
		saws = 1,
		LaserCount = 0,
		DartCount = 0,
		RockSpawnChance = 0.24,
		SawSpeedMult = 1.08,
		SawSpinMult = 1.0,
		SawStall = 0,
	},
	[2] = {
		FruitGoal = 13,
		rocks = 5,
		saws = 1,
		LaserCount = 0,
		DartCount = 0,
		RockSpawnChance = 0.26,
		SawSpeedMult = 1.14,
		SawSpinMult = 1.06,
		SawStall = 0,
	},
	[3] = {
		FruitGoal = 16,
		rocks = 6,
		saws = 2,
		LaserCount = 0,
		DartCount = 0,
		RockSpawnChance = 0.28,
		SawSpeedMult = 1.2,
		SawSpinMult = 1.12,
		SawStall = 0,
	},
	[4] = {
		FruitGoal = 19,
		rocks = 7,
		saws = 2,
		LaserCount = 0,
		DartCount = 0,
		RockSpawnChance = 0.3,
		SawSpeedMult = 1.26,
		SawSpinMult = 1.18,
		SawStall = 0,
	},
	[5] = {
		FruitGoal = 22,
		rocks = 8,
		saws = 3,
		LaserCount = 1,
		DartCount = 0,
		RockSpawnChance = 0.33,
		SawSpeedMult = 1.32,
		SawSpinMult = 1.24,
		SawStall = 0,
	},
	[6] = {
		FruitGoal = 25,
		rocks = 9,
		saws = 3,
		LaserCount = 1,
		DartCount = 0,
		RockSpawnChance = 0.36,
		SawSpeedMult = 1.38,
		SawSpinMult = 1.3,
		SawStall = 0,
	},
	[7] = {
		FruitGoal = 28,
		rocks = 10,
		saws = 4,
		LaserCount = 1,
		DartCount = 1,
		RockSpawnChance = 0.39,
		SawSpeedMult = 1.44,
		SawSpinMult = 1.36,
		SawStall = 0,
	},
	[8] = {
		FruitGoal = 31,
		rocks = 11,
		saws = 4,
		LaserCount = 1,
		DartCount = 1,
		RockSpawnChance = 0.42,
		SawSpeedMult = 1.5,
		SawSpinMult = 1.42,
		SawStall = 0,
	},
	[9] = {
		FruitGoal = 34,
		rocks = 12,
		saws = 4,
		LaserCount = 1,
		DartCount = 1,
		RockSpawnChance = 0.45,
		SawSpeedMult = 1.56,
		SawSpinMult = 1.48,
		SawStall = 0,
	},
	[10] = {
		FruitGoal = 37,
		rocks = 13,
		saws = 5,
		LaserCount = 2,
		DartCount = 1,
		RockSpawnChance = 0.48,
		SawSpeedMult = 1.62,
		SawSpinMult = 1.54,
		SawStall = 0,
	},
	[11] = {
		FruitGoal = 40,
		rocks = 14,
		saws = 5,
		LaserCount = 2,
		DartCount = 1,
		RockSpawnChance = 0.5,
		SawSpeedMult = 1.68,
		SawSpinMult = 1.6,
		SawStall = 0,
	},
	[12] = {
		FruitGoal = 43,
		rocks = 15,
		saws = 6,
		LaserCount = 2,
		DartCount = 2,
		RockSpawnChance = 0.52,
		SawSpeedMult = 1.74,
		SawSpinMult = 1.66,
		SawStall = 0,
	},
	[13] = {
		FruitGoal = 46,
		rocks = 16,
		saws = 6,
		LaserCount = 2,
		DartCount = 2,
		RockSpawnChance = 0.54,
		SawSpeedMult = 1.8,
		SawSpinMult = 1.72,
		SawStall = 0,
	},
	[14] = {
		FruitGoal = 49,
		rocks = 17,
		saws = 7,
		LaserCount = 2,
		DartCount = 2,
		RockSpawnChance = 0.56,
		SawSpeedMult = 1.84,
		SawSpinMult = 1.76,
		SawStall = 0,
	},
	[15] = {
		FruitGoal = 52,
		rocks = 19,
		saws = 7,
		LaserCount = 3,
		DartCount = 2,
		RockSpawnChance = 0.58,
		SawSpeedMult = 1.88,
		SawSpinMult = 1.8,
		SawStall = 0,
	},
}

function FloorPlan.GetBaselinePlan()
	return BASELINE_PLAN
end

function FloorPlan.GetBaselinePlanForFloor(FloorIndex)
	FloorIndex = math.max(1, FloorIndex or 1)
	return BASELINE_PLAN[FloorIndex]
end

function FloorPlan.BuildBaselineFloorContext(FloorNum)
	local FloorIndex = math.max(1, FloorNum or 1)
	local plan = FloorPlan.GetBaselinePlanForFloor(FloorIndex)

	if plan then
		local context = { floor = FloorIndex }
		for key, value in pairs(plan) do
			context[key] = value
		end
		ApplyLaserCap(context)
		ApplyDartCap(context)
		return context
	end

	local BaselinePlan = FloorPlan.GetBaselinePlan()
	local LastIndex = #BaselinePlan
	local LastPlan = BaselinePlan[LastIndex]
	local ExtraFloors = FloorIndex - LastIndex
	local context = { floor = FloorIndex }

	for key, value in pairs(LastPlan) do
		context[key] = value
	end

	local LastFruitGoal = LastPlan.fruitGoal or (EXTRA_FLOOR_FRUIT_STEP * LastIndex)
	context.fruitGoal = math.max(context.fruitGoal or 1, LastFruitGoal + ExtraFloors * EXTRA_FLOOR_FRUIT_STEP)
	context.rocks = math.max(0, math.min(40, (LastPlan.rocks or 19) + ExtraFloors))
	context.saws = math.max(1, math.min(8, (LastPlan.saws or 7) + math.floor(ExtraFloors / 3)))
	local BaseLaser = LastPlan.laserCount or 0
	context.laserCount = ComputeLaserProgression(BaseLaser, ExtraFloors, MAX_LASER_COUNT)
	local BaseDarts = math.min(2, LastPlan.dartCount or 0)
	context.dartCount = BaseDarts
	ApplyLaserCap(context)
	ApplyDartCap(context)
	context.rockSpawnChance = math.min(0.68, (LastPlan.rockSpawnChance or 0.58) + ExtraFloors * 0.015)
	context.sawSpeedMult = math.min(1.95, (LastPlan.sawSpeedMult or 1.88) + ExtraFloors * 0.03)
	context.sawSpinMult = math.min(1.88, (LastPlan.sawSpinMult or 1.8) + ExtraFloors * 0.025)
	context.sawStall = 0

	return context
end

FloorPlan.GetLaserCap = GetLaserCap
FloorPlan.GetDartCap = GetDartCap

return FloorPlan
