local FloorPlan = {}

local BASELINE_PLAN = {
    [1] = {
        fruitGoal = 6,
        rocks = 3,
        saws = 1,
        conveyors = 1,
        rockSpawnChance = 0.22,
        sawSpeedMult = 1.0,
        sawSpinMult = 0.95,
        sawStall = 1.0,
    },
    [2] = {
        fruitGoal = 7,
        rocks = 4,
        saws = 1,
        conveyors = 0,
        rockSpawnChance = 0.24,
        sawSpeedMult = 1.05,
        sawSpinMult = 1.0,
        sawStall = 0.85,
    },
    [3] = {
        fruitGoal = 8,
        rocks = 5,
        saws = 1,
        conveyors = 0,
        rockSpawnChance = 0.26,
        sawSpeedMult = 1.1,
        sawSpinMult = 1.05,
        sawStall = 0.75,
    },
    [4] = {
        fruitGoal = 9,
        rocks = 6,
        saws = 2,
        conveyors = 0,
        rockSpawnChance = 0.29,
        sawSpeedMult = 1.15,
        sawSpinMult = 1.1,
        sawStall = 0.68,
    },
    [5] = {
        fruitGoal = 10,
        rocks = 7,
        saws = 2,
        conveyors = 1,
        rockSpawnChance = 0.32,
        sawSpeedMult = 1.2,
        sawSpinMult = 1.15,
        sawStall = 0.62,
    },
    [6] = {
        fruitGoal = 11,
        rocks = 8,
        saws = 2,
        conveyors = 1,
        rockSpawnChance = 0.35,
        sawSpeedMult = 1.26,
        sawSpinMult = 1.2,
        sawStall = 0.56,
    },
    [7] = {
        fruitGoal = 12,
        rocks = 9,
        saws = 3,
        conveyors = 2,
        rockSpawnChance = 0.38,
        sawSpeedMult = 1.32,
        sawSpinMult = 1.25,
        sawStall = 0.48,
    },
    [8] = {
        fruitGoal = 13,
        rocks = 11,
        saws = 3,
        conveyors = 2,
        rockSpawnChance = 0.41,
        sawSpeedMult = 1.38,
        sawSpinMult = 1.3,
        sawStall = 0.43,
    },
    [9] = {
        fruitGoal = 14,
        rocks = 12,
        saws = 4,
        conveyors = 3,
        rockSpawnChance = 0.45,
        sawSpeedMult = 1.44,
        sawSpinMult = 1.35,
        sawStall = 0.38,
    },
    [10] = {
        fruitGoal = 15,
        rocks = 13,
        saws = 4,
        conveyors = 3,
        rockSpawnChance = 0.49,
        sawSpeedMult = 1.5,
        sawSpinMult = 1.4,
        sawStall = 0.33,
    },
    [11] = {
        fruitGoal = 16,
        rocks = 14,
        saws = 5,
        conveyors = 4,
        rockSpawnChance = 0.53,
        sawSpeedMult = 1.56,
        sawSpinMult = 1.45,
        sawStall = 0.28,
    },
    [12] = {
        fruitGoal = 17,
        rocks = 15,
        saws = 5,
        conveyors = 4,
        rockSpawnChance = 0.57,
        sawSpeedMult = 1.62,
        sawSpinMult = 1.5,
        sawStall = 0.24,
    },
    [13] = {
        fruitGoal = 18,
        rocks = 16,
        saws = 6,
        conveyors = 5,
        rockSpawnChance = 0.6,
        sawSpeedMult = 1.68,
        sawSpinMult = 1.55,
        sawStall = 0.21,
    },
    [14] = {
        fruitGoal = 19,
        rocks = 18,
        saws = 6,
        conveyors = 5,
        rockSpawnChance = 0.64,
        sawSpeedMult = 1.74,
        sawSpinMult = 1.6,
        sawStall = 0.18,
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

    context.fruitGoal = math.max(context.fruitGoal or 1, (lastPlan.fruitGoal or 18) + extraFloors)
    context.rocks = math.max(0, math.min(40, (lastPlan.rocks or 18) + extraFloors))
    context.saws = math.max(1, math.min(8, (lastPlan.saws or 6) + math.floor(extraFloors / 2)))
    context.conveyors = math.max(0, math.min(8, (lastPlan.conveyors or 5) + math.floor(extraFloors / 2)))
    context.rockSpawnChance = math.min(0.7, (lastPlan.rockSpawnChance or 0.56) + extraFloors * 0.02)
    context.sawSpeedMult = math.min(1.9, (lastPlan.sawSpeedMult or 1.6) + extraFloors * 0.04)
    context.sawSpinMult = math.min(1.85, (lastPlan.sawSpinMult or 1.55) + extraFloors * 0.035)
    context.sawStall = math.max(0.12, (lastPlan.sawStall or 0.21) - extraFloors * 0.03)

    return context
end

return FloorPlan
