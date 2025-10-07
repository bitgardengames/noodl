local Floors = require("floors")

local FloorPlan = {}

local FINAL_FLOOR = #Floors
local BASE_LASER_CAP = 3
local BASE_DART_CAP = 4

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
        fruitGoal = 6,
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
        fruitGoal = 7,
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
        fruitGoal = 8,
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
        fruitGoal = 9,
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
        fruitGoal = 10,
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
        fruitGoal = 11,
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
        fruitGoal = 12,
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
        fruitGoal = 13,
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
        fruitGoal = 14,
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
        fruitGoal = 15,
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
        fruitGoal = 16,
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
        fruitGoal = 17,
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
        fruitGoal = 18,
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
        fruitGoal = 19,
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
        fruitGoal = 21,
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

    context.fruitGoal = math.max(context.fruitGoal or 1, (lastPlan.fruitGoal or 21) + extraFloors)
    context.rocks = math.max(0, math.min(40, (lastPlan.rocks or 19) + extraFloors))
    context.saws = math.max(1, math.min(8, (lastPlan.saws or 7) + math.floor(extraFloors / 3)))
    local baseLaser = lastPlan.laserCount or 0
    context.laserCount = math.max(0, math.min(5, baseLaser + math.floor(extraFloors / 6)))
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
