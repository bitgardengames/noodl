local Rocks = require("rocks")
local Saws = require("saws")
local FruitEvents = require("fruitevents")
local FloorPlan = require("floorplan")

local FloorTraits = {}

local traits = {
    lushGrowth = {
        name = "Lush Growth",
        desc = "Fruit goal reduced by 2 and one fewer rock at start.",
        apply = function(ctx)
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal - 2)
            end
            if ctx.rocks then
                ctx.rocks = math.max(0, ctx.rocks - 1)
            end
        end
    },
    sunlitSanctuary = {
        name = "Sunlit Sanctuary",
        desc = "Sunlight keeps growth gentle, easing new rockfalls a touch.",
        apply = function(_ctx)
            local chance = Rocks:getSpawnChance() or 0.25
            Rocks.spawnChance = math.max(0.1, chance * 0.8)
        end
    },
    restlessEarth = {
        name = "Restless Earth",
        desc = "More rocks rumble in; they also fall more often after fruit.",
        apply = function(ctx)
            if ctx.rocks then
                ctx.rocks = math.min(40, math.floor((ctx.rocks * 1.3) + 0.5))
            end
            local chance = Rocks:getSpawnChance()
            Rocks.spawnChance = math.min(0.85, chance + 0.15)
        end
    },
    glowingSpores = {
        name = "Glowing Spores",
        desc = "Saws stall for 1.2s after each fruit.",
        apply = function()
            local current = Saws:getStallOnFruit()
            Saws:setStallOnFruit(math.max(current, 1.2))
        end
    },
    ancientMachinery = {
        name = "Ancient Machinery",
        desc = "One extra saw awakens to guard the ruins.",
        apply = function(ctx)
            if ctx.saws then
                ctx.saws = math.min(8, ctx.saws + 1)
            end
            ctx.laserCount = math.max(0, (ctx.laserCount or 0) + 1)
            Saws.spinMult = (Saws.spinMult or 1) * 1.1
        end
    },
    crystallineResonance = {
        name = "Crystalline Resonance",
        desc = "Saws move 15% slower and one fewer spawns.",
        apply = function(ctx)
            if ctx.saws then
                ctx.saws = math.max(0, ctx.saws - 1)
            end
            Saws.speedMult = (Saws.speedMult or 1) * 0.85
            Saws.spinMult = (Saws.spinMult or 1) * 0.9
        end
    },
    echoingStillness = {
        name = "Echoing Stillness",
        desc = "Combo timer lasts 1 second longer.",
        apply = function()
            local base = FruitEvents:getDefaultComboWindow()
            FruitEvents:setComboWindow(base + 1)
        end
    },
    infernalPressure = {
        name = "Infernal Pressure",
        desc = "An extra saw joins the hunt and blades move 15% faster.",
        apply = function(ctx)
            if ctx.saws then
                ctx.saws = math.min(8, ctx.saws + 1)
            end
            Saws.speedMult = (Saws.speedMult or 1) * 1.15
        end
    },
    ashenTithe = {
        name = "Ashen Tithe",
        desc = "Fruit goal +3 but fruits shatter a nearby rock.",
        apply = function(ctx)
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal + 3)
            end
            Rocks:addShatterOnFruit(1)
        end
    },
    waterloggedCatacombs = {
        name = "Waterlogged Passages",
        desc = "Flooding slows saws, reduces rocks, and stalls blades on fruit.",
        apply = function(ctx)
            if ctx.rocks then
                ctx.rocks = math.max(0, math.floor((ctx.rocks * 0.7) + 0.5))
            end

            local chance = Rocks:getSpawnChance() or 0.25
            Rocks.spawnChance = math.max(0.05, chance * 0.6)

            Saws.speedMult = (Saws.speedMult or 1) * 0.85
            local currentStall = Saws:getStallOnFruit()
            Saws:setStallOnFruit(math.max(currentStall, 0.8))
        end
    },
    boneHarvest = {
        name = "Bone Harvest",
        desc = "More bones litter the arena, but fruits grind them to dust.",
        apply = function(ctx)
            if ctx.rocks then
                ctx.rocks = math.min(40, math.floor((ctx.rocks * 1.2) + 0.5))
            end
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal + 1)
            end

            Rocks:addShatterOnFruit(0.75)
        end
    },
    obsidianResonance = {
        name = "Obsidian Resonance",
        desc = "Saw blades surge faster and an extra guardian awakens.",
        apply = function(ctx)
            if ctx.saws then
                ctx.saws = math.min(8, ctx.saws + 1)
            end

            Saws.speedMult = (Saws.speedMult or 1) * 1.2
            Saws.spinMult = (Saws.spinMult or 1) * 1.3
        end
    },
    cleansingNodes = {
        name = "Cleansing Nodes",
        desc = "Fruit pulses shatter extra rocks while slowing saws.",
        apply = function(ctx)
            if ctx.saws then
                ctx.saws = math.max(0, ctx.saws - 1)
            end

            Rocks:addShatterOnFruit(1)

            Saws.speedMult = (Saws.speedMult or 1) * 0.9
        end
    },
    spectralEchoes = {
        name = "Spectral Echoes",
        desc = "Combo window extends while phantoms thin the stone.",
        apply = function(ctx)
            if ctx.rocks then
                ctx.rocks = math.max(0, math.floor((ctx.rocks * 0.6) + 0.5))
            end

            local chance = Rocks:getSpawnChance() or 0.25
            Rocks.spawnChance = math.max(0.05, chance * 0.7)

            local base = FruitEvents:getDefaultComboWindow()
            FruitEvents:setComboWindow(base + 0.5)
        end
    },
    divineAscent = {
        name = "Trial of Light",
        desc = "Fruit goal rises, but saws pause longer after each feast.",
        apply = function(ctx)
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal + 4)
            end
            if ctx.saws then
                ctx.saws = math.max(0, ctx.saws - 1)
            end

            local chance = Rocks:getSpawnChance() or 0.25
            Rocks.spawnChance = math.max(0.05, chance * 0.75)

            local currentStall = Saws:getStallOnFruit()
            Saws:setStallOnFruit(math.max(currentStall, 1.0))
        end
    },
    guardianConvergence = {
        name = "Guardian Convergence",
        desc = "Twin sentinels awaken, flooding the arena with blades and darts.",
        apply = function(ctx)
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal + 2)
            end

            if ctx.saws then
                ctx.saws = math.min(8, (ctx.saws or 0) + 2)
            end

            ctx.dartCount = math.max(0, (ctx.dartCount or 0) + 2)
            ctx.laserCount = math.max(0, (ctx.laserCount or 0) + 1)

            local chance = Rocks:getSpawnChance() or 0.25
            Rocks.spawnChance = math.max(0.12, chance * 0.75)

            Saws.speedMult = (Saws.speedMult or 1) * 1.15
            Saws.spinMult = (Saws.spinMult or 1) * 1.2
        end
    },
    blightOvermind = {
        name = "Blight Overmind",
        desc = "The heart of the blight summons searing beams and relentless saws.",
        apply = function(ctx)
            if ctx.fruitGoal then
                ctx.fruitGoal = math.max(1, ctx.fruitGoal + 3)
            end

            if ctx.saws then
                ctx.saws = math.min(8, (ctx.saws or 0) + 1)
            end

            ctx.laserCount = math.max(0, (ctx.laserCount or 0) + 2)
            ctx.dartCount = math.max(0, (ctx.dartCount or 0) + 1)

            Rocks:addShatterOnFruit(1.25)

            Saws.speedMult = (Saws.speedMult or 1) * 1.2
            Saws.spinMult = (Saws.spinMult or 1) * 1.25

            local currentStall = Saws:getStallOnFruit()
            Saws:setStallOnFruit(math.max(currentStall, 0.6))
        end
    },
}

function FloorTraits:apply(list, context)
    local applied = {}
    local ctx = context or {}

    if type(list) ~= "table" then
        return ctx, applied
    end

    for _, id in ipairs(list) do
        local trait = traits[id]
        if trait then
            if trait.apply then
                trait.apply(ctx)
            end
            table.insert(applied, { name = trait.name, desc = trait.desc })
        end
    end

    if ctx.rocks then
        ctx.rocks = math.max(0, math.min(40, math.floor(ctx.rocks + 0.5)))
    end
    if ctx.saws then
        ctx.saws = math.max(0, math.min(8, math.floor(ctx.saws + 0.5)))
    end
    if ctx.laserCount ~= nil then
        local cap = FloorPlan.getLaserCap and FloorPlan.getLaserCap(ctx.floor)
        local maxLasers = cap or 6
        ctx.laserCount = math.max(0, math.min(maxLasers, math.floor(ctx.laserCount + 0.5)))
    end
    if ctx.dartCount ~= nil then
        local cap = FloorPlan.getDartCap and FloorPlan.getDartCap(ctx.floor)
        local maxDarts = cap or 6
        ctx.dartCount = math.max(0, math.min(maxDarts, math.floor(ctx.dartCount + 0.5)))
    end
    if ctx.fruitGoal then
        ctx.fruitGoal = math.max(1, math.floor(ctx.fruitGoal + 0.5))
    end

    return ctx, applied
end

return FloorTraits
