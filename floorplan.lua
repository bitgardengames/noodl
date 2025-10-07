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
        rocks = 3,
        saws = 1,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.22,
        sawSpeedMult = 1.05,
        sawSpinMult = 1.0,
        sawStall = 0.95,
    },
    [2] = {
        fruitGoal = 7,
        rocks = 4,
        saws = 1,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.24,
        sawSpeedMult = 1.08,
        sawSpinMult = 1.02,
        sawStall = 0.9,
    },
    [3] = {
        fruitGoal = 8,
        rocks = 5,
        saws = 1,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.26,
        sawSpeedMult = 1.12,
        sawSpinMult = 1.08,
        sawStall = 0.84,
    },
    [4] = {
        fruitGoal = 9,
        rocks = 6,
        saws = 2,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.3,
        sawSpeedMult = 1.18,
        sawSpinMult = 1.14,
        sawStall = 0.78,
    },
    [5] = {
        fruitGoal = 10,
        rocks = 6,
        saws = 2,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.32,
        sawSpeedMult = 1.24,
        sawSpinMult = 1.18,
        sawStall = 0.72,
    },
    [6] = {
        fruitGoal = 11,
        rocks = 7,
        saws = 3,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.35,
        sawSpeedMult = 1.3,
        sawSpinMult = 1.24,
        sawStall = 0.66,
    },
    [7] = {
        fruitGoal = 11,
        rocks = 8,
        saws = 3,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.36,
        sawSpeedMult = 1.34,
        sawSpinMult = 1.26,
        sawStall = 0.62,
    },
    [8] = {
        fruitGoal = 12,
        rocks = 9,
        saws = 3,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.38,
        sawSpeedMult = 1.38,
        sawSpinMult = 1.3,
        sawStall = 0.58,
    },
    [9] = {
        fruitGoal = 13,
        rocks = 10,
        saws = 4,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.41,
        sawSpeedMult = 1.42,
        sawSpinMult = 1.34,
        sawStall = 0.54,
    },
    [10] = {
        fruitGoal = 14,
        rocks = 11,
        saws = 4,
        laserCount = 0,
        dartCount = 1,
        rockSpawnChance = 0.44,
        sawSpeedMult = 1.48,
        sawSpinMult = 1.4,
        sawStall = 0.5,
    },
    [11] = {
        fruitGoal = 15,
        rocks = 12,
        saws = 5,
        laserCount = 0,
        dartCount = 1,
        rockSpawnChance = 0.47,
        sawSpeedMult = 1.54,
        sawSpinMult = 1.46,
        sawStall = 0.46,
    },
    [12] = {
        fruitGoal = 16,
        rocks = 13,
        saws = 5,
        laserCount = 0,
        dartCount = 1,
        rockSpawnChance = 0.5,
        sawSpeedMult = 1.6,
        sawSpinMult = 1.5,
        sawStall = 0.42,
    },
    [13] = {
        fruitGoal = 17,
        rocks = 14,
        saws = 6,
        laserCount = 1,
        dartCount = 2,
        rockSpawnChance = 0.52,
        sawSpeedMult = 1.66,
        sawSpinMult = 1.56,
        sawStall = 0.38,
    },
    [14] = {
        fruitGoal = 10,
        rocks = 6,
        saws = 2,
        laserCount = 0,
        dartCount = 0,
        rockSpawnChance = 0.3,
        sawSpeedMult = 1.2,
        sawSpinMult = 1.12,
        sawStall = 0.9,
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
