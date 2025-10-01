local FloorPlan = {}

local BASELINE_PLAN = {
    [1] = {
        fruitGoal = 6,
        rocks = 4,
        saws = 1,
        conveyors = 1,
        rockSpawnChance = 0.24,
        sawSpeedMult = 1.08,
        sawSpinMult = 1.0,
        sawStall = 0.9,
    },
    [2] = {
        fruitGoal = 7,
        rocks = 5,
        saws = 1,
        conveyors = 0,
        rockSpawnChance = 0.27,
        sawSpeedMult = 1.15,
        sawSpinMult = 1.08,
        sawStall = 0.8,
    },
    [3] = {
        fruitGoal = 9,
        rocks = 6,
        saws = 2,
        conveyors = 0,
        rockSpawnChance = 0.3,
        sawSpeedMult = 1.22,
        sawSpinMult = 1.16,
        sawStall = 0.7,
    },
    [4] = {
        fruitGoal = 10,
        rocks = 7,
        saws = 2,
        conveyors = 1,
        rockSpawnChance = 0.34,
        sawSpeedMult = 1.3,
        sawSpinMult = 1.23,
        sawStall = 0.62,
    },
    [5] = {
        fruitGoal = 11,
        rocks = 9,
        saws = 3,
        conveyors = 1,
        rockSpawnChance = 0.38,
        sawSpeedMult = 1.38,
        sawSpinMult = 1.3,
        sawStall = 0.55,
    },
    [6] = {
        fruitGoal = 12,
        rocks = 10,
        saws = 3,
        conveyors = 2,
        rockSpawnChance = 0.42,
        sawSpeedMult = 1.46,
        sawSpinMult = 1.36,
        sawStall = 0.48,
    },
    [7] = {
        fruitGoal = 13,
        rocks = 12,
        saws = 4,
        conveyors = 2,
        rockSpawnChance = 0.46,
        sawSpeedMult = 1.54,
        sawSpinMult = 1.42,
        sawStall = 0.42,
    },
    [8] = {
        fruitGoal = 14,
        rocks = 13,
        saws = 4,
        conveyors = 3,
        rockSpawnChance = 0.5,
        sawSpeedMult = 1.62,
        sawSpinMult = 1.48,
        sawStall = 0.37,
    },
    [9] = {
        fruitGoal = 15,
        rocks = 15,
        saws = 5,
        conveyors = 3,
        rockSpawnChance = 0.55,
        sawSpeedMult = 1.7,
        sawSpinMult = 1.54,
        sawStall = 0.32,
    },
    [10] = {
        fruitGoal = 17,
        rocks = 16,
        saws = 5,
        conveyors = 4,
        rockSpawnChance = 0.6,
        sawSpeedMult = 1.78,
        sawSpinMult = 1.6,
        sawStall = 0.27,
    },
    [11] = {
        fruitGoal = 18,
        rocks = 18,
        saws = 6,
        conveyors = 4,
        rockSpawnChance = 0.64,
        sawSpeedMult = 1.85,
        sawSpinMult = 1.66,
        sawStall = 0.23,
    },
    [12] = {
        fruitGoal = 19,
        rocks = 19,
        saws = 6,
        conveyors = 5,
        rockSpawnChance = 0.67,
        sawSpeedMult = 1.88,
        sawSpinMult = 1.72,
        sawStall = 0.2,
    },
    [13] = {
        fruitGoal = 21,
        rocks = 21,
        saws = 7,
        conveyors = 5,
        rockSpawnChance = 0.69,
        sawSpeedMult = 1.9,
        sawSpinMult = 1.78,
        sawStall = 0.17,
    },
    [14] = {
        fruitGoal = 22,
        rocks = 23,
        saws = 7,
        conveyors = 6,
        rockSpawnChance = 0.7,
        sawSpeedMult = 1.9,
        sawSpinMult = 1.82,
        sawStall = 0.15,
    },
    [15] = {
        fruitGoal = 24,
        rocks = 24,
        saws = 7,
        conveyors = 6,
        rockSpawnChance = 0.7,
        sawSpeedMult = 1.9,
        sawSpinMult = 1.85,
        sawStall = 0.13,
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
