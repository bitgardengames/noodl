local Rocks = require("rocks")
local Saws = require("saws")
local FruitEvents = require("fruitevents")
local Score = require("score")
local Upgrades = require("upgrades")

local DepthMutations = {}

local appliedState = {
    fruitBonus = 0,
}

local function getEffect(name)
    if Upgrades and Upgrades.getEffect then
        return Upgrades:getEffect(name) or 0
    end
    return 0
end

local function clamp(value, min, max)
    if min and value < min then return min end
    if max and value > max then return max end
    return value
end

local function round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor(value * mult + 0.5) / mult
end

local function applyFruitBonus(bonus)
    bonus = math.max(0, math.floor(bonus + 0.5))
    if bonus == appliedState.fruitBonus then
        return bonus
    end

    local delta = bonus - (appliedState.fruitBonus or 0)
    if delta ~= 0 then
        Score:addFruitBonus(delta)
    end
    appliedState.fruitBonus = bonus
    return bonus
end

local milestones

local function getSections()
    if milestones then return milestones end

    milestones = {
        {
            id = "creeping_hunger",
            floor = 3,
            name = "Creeping Hunger",
            apply = function(context)
                local ctx = context or {}
                local mitigation = clamp(getEffect("depthMitigation"), 0, 2)
                local boonMult = 1 + clamp(getEffect("depthBoon"), 0, 3)

                local fruitPenalty = 1 * (1 - mitigation)
                fruitPenalty = math.max(0, math.floor(fruitPenalty + 0.5))
                if ctx.fruitGoal then
                    ctx.fruitGoal = math.max(1, ctx.fruitGoal + fruitPenalty)
                end

                local currentStall = Saws:getStallOnFruit()
                local stallBonus = round(0.35 * boonMult, 2)
                if stallBonus > 0 then
                    Saws:setStallOnFruit(currentStall + stallBonus)
                end

                local parts = {}
                if fruitPenalty > 0 then
                    table.insert(parts, string.format("Fruit goal +%d", fruitPenalty))
                else
                    table.insert(parts, "Fruit goal steady")
                end
                table.insert(parts, string.format("Saws stall +%.1fs", stallBonus))

                return ctx, {
                    name = "Creeping Hunger",
                    desc = table.concat(parts, ", ") .. ".",
                }
            end,
        },
        {
            id = "shifting_strata",
            floor = 6,
            name = "Shifting Strata",
            apply = function(context)
                local ctx = context or {}
                local mitigation = clamp(getEffect("depthMitigation"), 0, 2)
                local boonMult = 1 + clamp(getEffect("depthBoon"), 0, 3)

                local sawPenalty = 1 * (1 - mitigation)
                sawPenalty = math.max(0, math.floor(sawPenalty + 0.5))
                if ctx.saws then
                    ctx.saws = math.max(0, ctx.saws + sawPenalty)
                end

                local speedPenalty = round(0.08 * (1 - clamp(mitigation, 0, 1)), 2)
                if speedPenalty > 0 then
                    Saws.speedMult = (Saws.speedMult or 1) * (1 + speedPenalty)
                end

                local chance = Rocks:getSpawnChance() or 0.25
                local reduction = round(0.1 * boonMult, 2)
                local newChance = clamp(chance - reduction, 0.05, 0.95)
                Rocks.spawnChance = newChance

                local parts = {}
                if sawPenalty > 0 then
                    table.insert(parts, string.format("+%d saw", sawPenalty))
                else
                    table.insert(parts, "No extra saws")
                end
                if speedPenalty > 0 then
                    table.insert(parts, string.format("saws %.0f%% faster", speedPenalty * 100))
                else
                    table.insert(parts, "blade speed steady")
                end
                local percent = math.max(0, round((chance - newChance) * 100, 1))
                table.insert(parts, string.format("rock spawn -%.1f%%", percent))

                return ctx, {
                    name = "Shifting Strata",
                    desc = table.concat(parts, ", ") .. ".",
                }
            end,
        },
        {
            id = "abyssal_tribute",
            floor = 9,
            name = "Abyssal Tribute",
            apply = function(context)
                local ctx = context or {}
                local mitigation = clamp(getEffect("depthMitigation"), 0, 2)
                local boonMult = 1 + clamp(getEffect("depthBoon"), 0, 3)

                local chance = Rocks:getSpawnChance() or 0.25
                local rockPenalty = round(0.08 * (1 - mitigation), 3)
                local newChance = clamp(chance + rockPenalty, 0.05, 0.95)
                Rocks.spawnChance = newChance

                local currentWindow = FruitEvents:getComboWindow()
                local comboPenalty = round(0.3 * (1 - mitigation), 2)
                local newWindow = math.max(0.75, currentWindow - comboPenalty)
                FruitEvents:setComboWindow(newWindow)

                local fruitBonus = math.max(0, round(1 * boonMult, 1))
                local applied = applyFruitBonus(fruitBonus)

                local parts = {}
                local rockPercent = math.max(0, round((newChance - chance) * 100, 1))
                if rockPercent > 0 then
                    table.insert(parts, string.format("rock spawn +%.1f%%", rockPercent))
                else
                    table.insert(parts, "rocks unchanged")
                end
                if comboPenalty > 0 then
                    table.insert(parts, string.format("combo window -%.1fs", comboPenalty))
                else
                    table.insert(parts, "combo window steady")
                end
                if applied > 0 then
                    table.insert(parts, string.format("fruit +%d bonus", applied))
                else
                    table.insert(parts, "fruit reward unchanged")
                end

                return ctx, {
                    name = "Abyssal Tribute",
                    desc = table.concat(parts, ", ") .. ".",
                }
            end,
        },
    }

    return milestones
end

function DepthMutations:reset()
    appliedState.fruitBonus = 0
end

function DepthMutations:getActive(floor)
    local active = {}
    local sections = getSections()
    for _, milestone in ipairs(sections) do
        if floor >= milestone.floor then
            table.insert(active, milestone)
        end
    end
    return active
end

function DepthMutations:apply(floor, context)
    local ctx = context or {}
    local applied = {}

    for _, milestone in ipairs(self:getActive(floor)) do
        local resultCtx, descriptor = milestone.apply(ctx)
        ctx = resultCtx or ctx
        if descriptor then
            table.insert(applied, descriptor)
        end
    end

    return ctx, applied
end

return DepthMutations
