local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Score = require("score")
local UI = require("ui")
local FloatingText = require("floatingtext")
local Particles = require("particles")

local Upgrades = {}
local poolById = {}

local rarities = {
    common = {
        weight = 60,
        label = "Common",
        color = {0.75, 0.82, 0.88, 1},
    },
    uncommon = {
        weight = 28,
        label = "Uncommon",
        color = {0.55, 0.78, 0.58, 1},
    },
    rare = {
        weight = 12,
        label = "Rare",
        color = {0.76, 0.56, 0.88, 1},
    }
}

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepcopy(v)
    end
    return copy
end

local defaultEffects = {
    sawSpeedMult = 1,
    sawSpinMult = 1,
    sawStall = 0,
    rockSpawnMult = 1,
    rockSpawnFlat = 0,
    rockShatter = 0,
    comboBonusMult = 1,
    fruitGoalDelta = 0,
    rockSpawnBonus = 0,
    sawSpawnBonus = 0,
    adrenaline = nil,
    adrenalineDurationBonus = 0,
    adrenalineBoostBonus = 0,
    comboWindowBonus = 0,
    comboBonusFlat = 0,
    comboDepthScaler = 0,
    shopSlots = 0,
    depthMitigation = 0,
    depthBoon = 0,
}

local function getEventPosition(data)
    if data and data.x and data.y then
        return data.x, data.y
    end

    if Snake.getHead then
        local hx, hy = Snake:getHead()
        if hx and hy then
            return hx, hy
        end
    end

    return nil, nil
end

local function stoneSkinShieldHandler(data, state)
    if not state then return end
    if (state.takenSet and (state.takenSet["stone_skin"] or 0) <= 0) then return end
    if not data or data.cause ~= "rock" then return end
    if not Rocks or not Rocks.shatterNearest then return end

    local fx, fy = getEventPosition(data)
    Rocks:shatterNearest(fx or 0, fy or 0, 1)
end

local function newRunState()
    return {
        takenOrder = {},
        takenSet = {},
        tags = {},
        counters = {},
        handlers = {},
        effects = deepcopy(defaultEffects),
        baseline = {},
    }
end

Upgrades.runState = newRunState()

local function register(upgrade)
    upgrade.id = upgrade.id or upgrade.name
    upgrade.rarity = upgrade.rarity or "common"
    upgrade.weight = upgrade.weight or 1
    poolById[upgrade.id] = upgrade
    return upgrade
end

local pool = {
    register({
        id = "quick_fangs",
        name = "Quick Fangs",
        desc = "Snake moves 10% faster.",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 4,
        onAcquire = function(state)
            Snake:addSpeedMultiplier(1.10)
        end,
    }),
    register({
        id = "stone_skin",
        name = "Stone Skin",
        desc = "Gain a crash shield that shatters rocks and shrugs off a saw clip.",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 4,
        onAcquire = function(state)
            Snake:addCrashShields(1)
            if Snake.addStoneSkinSawGrace then
                Snake:addStoneSkinSawGrace(1)
            end
            if not state.counters.stoneSkinHandlerRegistered then
                state.counters.stoneSkinHandlerRegistered = true
                Upgrades:addEventHandler("shieldConsumed", stoneSkinShieldHandler)
            end
        end,
    }),
    register({
        id = "aegis_recycler",
        name = "Aegis Recycler",
        desc = "Every 2 broken shields forge a fresh one.",
        rarity = "common",
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.aegisRecycler = state.counters.aegisRecycler or 0
        end,
        handlers = {
            shieldConsumed = function(data, state)
                state.counters.aegisRecycler = (state.counters.aegisRecycler or 0) + 1
                if state.counters.aegisRecycler >= 2 then
                    state.counters.aegisRecycler = state.counters.aegisRecycler - 2
                    Snake:addCrashShields(1)
                    local fx, fy = getEventPosition(data)
                    if FloatingText and fx and fy then
                        FloatingText:add("Aegis Reforged", fx, fy - 52, {0.6, 0.85, 1, 1}, 1.1, 60)
                    end
                    if Particles and fx and fy then
                        Particles:spawnBurst(fx, fy, {
                            count = 10,
                            speed = 90,
                            life = 0.45,
                            size = 4,
                            color = {0.55, 0.8, 1, 1},
                            spread = math.pi * 2,
                        })
                    end
                end
            end,
        },
    }),
    register({
        id = "saw_grease",
        name = "Saw Grease",
        desc = "Saws move 20% slower.",
        rarity = "common",
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 0.8
        end,
    }),
    register({
        id = "extra_bite",
        name = "Extra Bite",
        desc = "Exit unlocks one fruit earlier.",
        rarity = "common",
        onAcquire = function(state)
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(-1)
            end
        end,
    }),
    register({
        id = "metronome_totem",
        name = "Metronome Totem",
        desc = "Fruit adds +0.35s to the combo timer.",
        rarity = "common",
        tags = {"combo"},
        handlers = {
            fruitCollected = function()
                local FruitEvents = require("fruitevents")
                if FruitEvents.boostComboTimer then
                    FruitEvents.boostComboTimer(0.35)
                end
            end,
        },
    }),
    register({
        id = "adrenaline_surge",
        name = "Adrenaline Surge",
        desc = "Snake gains a burst of speed after eating fruit.",
        rarity = "uncommon",
        tags = {"adrenaline"},
        onAcquire = function(state)
            state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
        end,
    }),
    register({
        id = "stone_whisperer",
        name = "Stone Whisperer",
        desc = "Rocks appear far less often after you snack.",
        rarity = "common",
        onAcquire = function(state)
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.6
        end,
    }),
    register({
        id = "tail_trainer",
        name = "Tail Trainer",
        desc = "Gain an extra segment each time you grow.",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 3,
        onAcquire = function(state)
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
        end,
    }),
    register({
        id = "lucky_bite",
        name = "Lucky Bite",
        desc = "+1 score every time you eat fruit.",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 3,
        onAcquire = function(state)
            if Score.addFruitBonus then
                Score:addFruitBonus(1)
            else
                Score.fruitBonus = (Score.fruitBonus or 0) + 1
            end
        end,
    }),
    register({
        id = "momentum_memory",
        name = "Momentum Memory",
        desc = "Adrenaline bursts last 2 seconds longer.",
        rarity = "uncommon",
        requiresTags = {"adrenaline"},
        onAcquire = function(state)
            state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
            state.effects.adrenalineDurationBonus = (state.effects.adrenalineDurationBonus or 0) + 2
        end,
    }),
    register({
        id = "molting_reflex",
        name = "Molting Reflex",
        desc = "Crash shields trigger a 60% adrenaline surge.",
        rarity = "uncommon",
        requiresTags = {"adrenaline"},
        tags = {"adrenaline", "defense"},
        handlers = {
            shieldConsumed = function(data)
                if not Snake.adrenaline then return end

                Snake.adrenaline.active = true
                local baseDuration = Snake.adrenaline.duration or 2.5
                local surgeDuration = baseDuration * 0.6
                if surgeDuration <= 0 then surgeDuration = 1 end
                local currentTimer = Snake.adrenaline.timer or 0
                Snake.adrenaline.timer = math.max(currentTimer, surgeDuration)

                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Molting Reflex", fx, fy - 44, {0.92, 0.98, 0.85, 1}, 1.0, 58)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 12,
                        speed = 120,
                        life = 0.5,
                        size = 4,
                        color = {1, 0.72, 0.28, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
    }),
    register({
        id = "circuit_breaker",
        name = "Circuit Breaker",
        desc = "Saw tracks freeze for 2s after each fruit.",
        rarity = "uncommon",
        onAcquire = function(state)
            state.effects.sawStall = math.max(state.effects.sawStall or 0, 2)
        end,
    }),
    register({
        id = "gem_maw",
        name = "Gem Maw",
        desc = "Fruits have a 12% chance to erupt into +5 bonus score.",
        rarity = "uncommon",
        onAcquire = function(state)
            if Score.addJackpotChance then
                Score:addJackpotChance(0.12, 5)
            else
                Score.jackpotChance = math.min(1, (Score.jackpotChance or 0) + 0.12)
                Score.jackpotReward = (Score.jackpotReward or 0) + 5
            end
        end,
    }),
    register({
        id = "stonebreaker_hymn",
        name = "Stonebreaker Hymn",
        desc = "Every other fruit shatters the nearest rock. Stacks to every fruit.",
        rarity = "uncommon",
        allowDuplicates = true,
        maxStacks = 2,
        onAcquire = function(state)
            state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.5
            state.counters.stonebreakerStacks = (state.counters.stonebreakerStacks or 0) + 1
            if Snake.setStonebreakerStacks then
                Snake:setStonebreakerStacks(state.counters.stonebreakerStacks)
            end
        end,
    }),
    register({
        id = "echo_aegis",
        name = "Echo Aegis",
        desc = "Crash shields unleash a shockwave that stalls saws.",
        rarity = "uncommon",
        onAcquire = function(state)
            if Snake.addShieldBurst then
                Snake:addShieldBurst({ rocks = 1, stall = 1.5 })
            else
                Snake.shieldBurst = Snake.shieldBurst or { rocks = 0, stall = 0 }
                Snake.shieldBurst.rocks = (Snake.shieldBurst.rocks or 0) + 1
                local current = Snake.shieldBurst.stall or 0
                Snake.shieldBurst.stall = math.max(current, 1.5)
            end
        end,
    }),
    register({
        id = "gilded_trail",
        name = "Gilded Trail",
        desc = "Every 5th fruit grants +3 bonus score.",
        rarity = "common",
        tags = {"economy"},
        onAcquire = function(state)
            state.counters.gildedTrail = state.counters.gildedTrail or 0
        end,
        handlers = {
            fruitCollected = function(data, state)
                state.counters.gildedTrail = (state.counters.gildedTrail or 0) + 1
                if state.counters.gildedTrail % 5 == 0 then
                    if Score.addBonus then
                        Score:addBonus(3)
                    end
                    if FloatingText and data and data.x and data.y then
                        FloatingText:add("Gilded Trail +3", data.x, data.y - 36, {1, 0.88, 0.35, 1}, 1.2, 55)
                    end
                end
            end,
        },
    }),
    register({
        id = "momentum_cache",
        name = "Momentum Cache",
        desc = "Combo finishers grant +1 bonus per link but saws move 5% faster.",
        rarity = "uncommon",
        tags = {"economy", "risk"},
        onAcquire = function(state)
            state.effects.comboBonusFlat = (state.effects.comboBonusFlat or 0) + 1
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.05
        end,
    }),
    register({
        id = "aurora_band",
        name = "Aurora Band",
        desc = "Combo window +0.35s but exit needs +1 fruit.",
        rarity = "uncommon",
        tags = {"combo", "risk"},
        onAcquire = function(state)
            state.effects.comboWindowBonus = (state.effects.comboWindowBonus or 0) + 0.35
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(1)
            end
        end,
    }),
    register({
        id = "caravan_contract",
        name = "Caravan Contract",
        desc = "Shops offer +1 card but an extra rock spawns.",
        rarity = "uncommon",
        tags = {"economy", "risk"},
        onAcquire = function(state)
            state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
            state.effects.rockSpawnBonus = (state.effects.rockSpawnBonus or 0) + 1
        end,
    }),
    register({
        id = "venomous_hunger",
        name = "Venomous Hunger",
        desc = "Combo rewards are 50% stronger but the exit needs +1 fruit.",
        rarity = "uncommon",
        tags = {"risk"},
        onAcquire = function(state)
            state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.5
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(1)
            end
        end,
    }),
    register({
        id = "predators_reflex",
        name = "Predator's Reflex",
        desc = "Adrenaline bursts are 25% stronger and trigger at floor start.",
        rarity = "rare",
        requiresTags = {"adrenaline"},
        onAcquire = function(state)
            state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
            state.effects.adrenalineBoostBonus = (state.effects.adrenalineBoostBonus or 0) + 0.25
        end,
        handlers = {
            floorStart = function()
                if Snake.adrenaline then
                    Snake.adrenaline.active = true
                    Snake.adrenaline.timer = (Snake.adrenaline.duration or 0) * 0.5
                end
            end,
        },
    }),
    register({
        id = "grim_reliquary",
        name = "Grim Reliquary",
        desc = "Begin each floor with +1 crash shield, but saws move 10% faster.",
        rarity = "rare",
        requiresTags = {"risk"},
        tags = {"defense"},
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.1
            Snake:addCrashShields(1)
        end,
        handlers = {
            floorStart = function()
                Snake:addCrashShields(1)
            end,
        },
    }),
    register({
        id = "relentless_pursuit",
        name = "Relentless Pursuit",
        desc = "Saws gain 15% speed but stall for +1.5s after fruit.",
        rarity = "rare",
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.15
            state.effects.sawStall = math.max(state.effects.sawStall or 0, 1.5)
        end,
    }),
    register({
        id = "ember_engine",
        name = "Ember Engine",
        desc = "First fruit each floor stalls saws for 3s and erupts sparks.",
        rarity = "rare",
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.ember_engine_ready = false
        end,
        handlers = {
            floorStart = function(_, state)
                state.counters.ember_engine_ready = true
            end,
            fruitCollected = function(data, state)
                if not state.counters.ember_engine_ready then return end
                state.counters.ember_engine_ready = false
                Saws:stall(3)
                if data and data.x and data.y then
                    FloatingText:add("Ember Engine", data.x, data.y - 48, {1, 0.58, 0.2, 1}, 1.2, 55)
                    Particles:spawnBurst(data.x, data.y, {
                        count = 14,
                        speed = 120,
                        life = 0.8,
                        size = 5,
                        color = {1, 0.55, 0.2, 1},
                        spread = math.pi * 2,
                        gravity = 20,
                    })
                end
            end,
        },
    }),
    register({
        id = "abyssal_anchor",
        name = "Abyssal Anchor",
        desc = "Depth penalties shrink by 40%.",
        rarity = "uncommon",
        tags = {"depth", "defense"},
        onAcquire = function(state)
            local current = state.effects.depthMitigation or 0
            state.effects.depthMitigation = math.min(2, current + 0.4)
        end,
    }),
    register({
        id = "void_lantern",
        name = "Void Lantern",
        desc = "Depth boons are 35% stronger. Descents grant +depth bonus score.",
        rarity = "rare",
        tags = {"depth", "economy"},
        onAcquire = function(state)
            state.effects.depthBoon = (state.effects.depthBoon or 0) + 0.35
        end,
        handlers = {
            floorStart = function(data, state)
                local depth = 1
                if data and data.floor then
                    depth = data.floor
                elseif state and state.counters and state.counters.depth then
                    depth = state.counters.depth
                end
                depth = math.max(1, math.floor(depth + 0.5))
                Score:addBonus(depth)
            end,
        },
    }),
    register({
        id = "depthsong_chime",
        name = "Depthsong Chime",
        desc = "Combo finishers grant +depth bonus but +1 rock spawns.",
        rarity = "rare",
        tags = {"economy"},
        onAcquire = function(state)
            state.effects.comboDepthScaler = (state.effects.comboDepthScaler or 0) + 1
            state.effects.rockSpawnBonus = (state.effects.rockSpawnBonus or 0) + 1
        end,
    }),
    register({
        id = "luminous_cache",
        name = "Luminous Cache",
        desc = "Broken shields scatter embers worth +depth score.",
        rarity = "rare",
        tags = {"economy", "defense"},
        handlers = {
            shieldConsumed = function(data, state)
                local depth = 1
                if state and state.counters then
                    depth = math.max(1, math.floor((state.counters.depth or 1) + 0.5))
                end

                if Score.addBonus then
                    Score:addBonus(depth)
                end

                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Luminous Cache +" .. tostring(depth), fx, fy - 60, {1, 0.84, 0.45, 1}, 1.2, 62)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 14,
                        speed = 110,
                        life = 0.55,
                        size = 5,
                        color = {1, 0.72, 0.35, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
    }),
}

local function getRarityInfo(rarity)
    return rarities[rarity or "common"] or rarities.common
end

function Upgrades:beginRun()
    self.runState = newRunState()
end

function Upgrades:getRunState()
    return self.runState
end

function Upgrades:getEffect(name)
    if not name then return nil end
    return self.runState.effects[name]
end

function Upgrades:getUpgradeById(id)
    if not id then return nil end
    return poolById[id]
end

function Upgrades:hasTag(tag)
    return tag and self.runState.tags[tag] or false
end

function Upgrades:addTag(tag)
    if not tag then return end
    self.runState.tags[tag] = true
end

function Upgrades:getTakenCount(id)
    if not id then return 0 end
    return self.runState.takenSet[id] or 0
end

function Upgrades:addEventHandler(event, handler)
    if not event or type(handler) ~= "function" then return end
    local handlers = self.runState.handlers[event]
    if not handlers then
        handlers = {}
        self.runState.handlers[event] = handlers
    end
    table.insert(handlers, handler)
end

function Upgrades:notify(event, data)
    if event == "floorStart" then
        local depth = (data and data.floor) or self.runState.counters.depth or 1
        self.runState.counters.depth = depth
    end
    local handlers = self.runState.handlers[event]
    if not handlers then return end
    for _, handler in ipairs(handlers) do
        handler(data, self.runState)
    end
end

local function clamp(value, min, max)
    if min and value < min then return min end
    if max and value > max then return max end
    return value
end

function Upgrades:modifyFloorContext(context)
    if not context then return context end

    local effects = self.runState.effects
    if effects.fruitGoalDelta and context.fruitGoal then
        local goal = context.fruitGoal + effects.fruitGoalDelta
        goal = math.floor(goal + 0.5)
        context.fruitGoal = clamp(goal, 1)
    end
    if effects.rockSpawnBonus and context.rocks then
        local rocks = context.rocks + effects.rockSpawnBonus
        rocks = math.floor(rocks + 0.5)
        context.rocks = clamp(rocks, 0)
    end
    if effects.sawSpawnBonus and context.saws then
        local saws = context.saws + effects.sawSpawnBonus
        saws = math.floor(saws + 0.5)
        context.saws = clamp(saws, 0)
    end

    return context
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    else
        return -math.floor(math.abs(value) + 0.5)
    end
end

function Upgrades:getComboBonus(comboCount)
    local bonus = 0
    local breakdown = {}

    if not comboCount or comboCount < 2 then
        return bonus, breakdown
    end

    local effects = self.runState.effects
    local flat = (effects.comboBonusFlat or 0) * (comboCount - 1)
    if flat ~= 0 then
        local amount = round(flat)
        if amount ~= 0 then
            bonus = bonus + amount
            table.insert(breakdown, { label = "Momentum", amount = amount })
        end
    end

    local depthScale = effects.comboDepthScaler or 0
    if depthScale ~= 0 then
        local depth = self.runState.counters.depth or 1
        local amount = round(depth * depthScale)
        if amount ~= 0 then
            bonus = bonus + amount
            local label = depthScale > 0 and "Depthsong" or "Depth Debt"
            table.insert(breakdown, { label = label, amount = amount })
        end
    end

    return bonus, breakdown
end

local function captureBaseline(state)
    local baseline = state.baseline
    baseline.sawSpeedMult = Saws.speedMult or 1
    baseline.sawSpinMult = Saws.spinMult or 1
    if Saws.getStallOnFruit then
        baseline.sawStall = Saws:getStallOnFruit()
    else
        baseline.sawStall = Saws.stallOnFruit or 0
    end
    if Rocks.getSpawnChance then
        baseline.rockSpawnChance = Rocks:getSpawnChance()
    else
        baseline.rockSpawnChance = Rocks.spawnChance or 0.25
    end
    baseline.rockShatter = Rocks.shatterOnFruit or 0
    if Score.getComboBonusMultiplier then
        baseline.comboBonusMult = Score:getComboBonusMultiplier()
    else
        baseline.comboBonusMult = Score.comboBonusMult or 1
    end
end

local function ensureBaseline(state)
    state.baseline = state.baseline or {}
    if not next(state.baseline) then
        captureBaseline(state)
    end
end

function Upgrades:applyPersistentEffects(rebaseline)
    local state = self.runState
    local effects = state.effects

    if rebaseline then
        state.baseline = {}
    end
    ensureBaseline(state)
    local base = state.baseline

    local sawSpeed = (base.sawSpeedMult or 1) * (effects.sawSpeedMult or 1)
    local sawSpin = (base.sawSpinMult or 1) * (effects.sawSpinMult or 1)
    Saws.speedMult = sawSpeed
    Saws.spinMult = sawSpin

    local stallBase = base.sawStall or 0
    local stallBonus = effects.sawStall or 0
    local stallValue = math.max(stallBase, stallBonus)
    if Saws.setStallOnFruit then
        Saws:setStallOnFruit(stallValue)
    else
        Saws.stallOnFruit = stallValue
    end

    local rockBase = base.rockSpawnChance or 0.25
    local rockChance = math.max(0.02, rockBase * (effects.rockSpawnMult or 1) + (effects.rockSpawnFlat or 0))
    Rocks.spawnChance = rockChance
    Rocks.shatterOnFruit = (base.rockShatter or 0) + (effects.rockShatter or 0)
    if Snake.setStonebreakerStacks then
        local stacks = 0
        if state and state.counters then
            stacks = state.counters.stonebreakerStacks or 0
        end
        if stacks <= 0 and effects.rockShatter then
            local perStack = 0.5
            stacks = math.floor(((effects.rockShatter or 0) / perStack) + 0.5)
        end
        Snake:setStonebreakerStacks(stacks)
    end

    local comboBase = base.comboBonusMult or 1
    local comboMult = comboBase * (effects.comboBonusMult or 1)
    if Score.setComboBonusMultiplier then
        Score:setComboBonusMultiplier(comboMult)
    else
        Score.comboBonusMult = comboMult
    end

    if effects.adrenaline then
        Snake.adrenaline = Snake.adrenaline or {}
        Snake.adrenaline.active = Snake.adrenaline.active or false
        Snake.adrenaline.timer = Snake.adrenaline.timer or 0
        local duration = (effects.adrenaline.duration or 3) + (effects.adrenalineDurationBonus or 0)
        Snake.adrenaline.duration = duration
        local boost = (effects.adrenaline.boost or 1.5) + (effects.adrenalineBoostBonus or 0)
        Snake.adrenaline.boost = boost
    end
end

local function calculateWeight(upgrade)
    local rarityInfo = getRarityInfo(upgrade.rarity)
    local rarityWeight = rarityInfo.weight or 1
    return rarityWeight * (upgrade.weight or 1)
end

function Upgrades:canOffer(upgrade, context, allowTaken)
    if not upgrade then return false end

    local count = self:getTakenCount(upgrade.id)
    if not allowTaken then
        if (count > 0 and not upgrade.allowDuplicates) then
            return false
        end
        if upgrade.maxStacks and count >= upgrade.maxStacks then
            return false
        end
    end

    if upgrade.requiresTags then
        for _, tag in ipairs(upgrade.requiresTags) do
            if not self:hasTag(tag) then
                return false
            end
        end
    end

    if upgrade.excludesTags then
        for _, tag in ipairs(upgrade.excludesTags) do
            if self:hasTag(tag) then
                return false
            end
        end
    end

    if upgrade.condition and not upgrade.condition(self.runState, context) then
        return false
    end

    return true
end

local function decorateCard(upgrade)
    local rarityInfo = getRarityInfo(upgrade.rarity)
    return {
        id = upgrade.id,
        name = upgrade.name,
        desc = upgrade.desc,
        rarity = upgrade.rarity,
        rarityColor = rarityInfo.color,
        rarityLabel = rarityInfo.label,
        upgrade = upgrade,
    }
end

function Upgrades:getRandom(n, context)
    local available = {}
    for _, upgrade in ipairs(pool) do
        if self:canOffer(upgrade, context, false) then
            table.insert(available, upgrade)
        end
    end

    if #available == 0 then
        for _, upgrade in ipairs(pool) do
            if self:canOffer(upgrade, context, true) then
                table.insert(available, upgrade)
            end
        end
    end

    local cards = {}
    n = math.min(n or 3, #available)
    for _ = 1, n do
        local totalWeight = 0
        local weights = {}
        for i, upgrade in ipairs(available) do
            local weight = calculateWeight(upgrade)
            totalWeight = totalWeight + weight
            weights[i] = weight
        end

        if totalWeight <= 0 then break end

        local roll = love.math.random() * totalWeight
        local cumulative = 0
        local chosenIndex = 1
        for i, weight in ipairs(weights) do
            cumulative = cumulative + weight
            if roll <= cumulative then
                chosenIndex = i
                break
            end
        end

        local choice = available[chosenIndex]
        table.insert(cards, decorateCard(choice))
        table.remove(available, chosenIndex)
        if #available == 0 then break end
    end

    return cards
end

function Upgrades:acquire(card, context)
    if not card or not card.upgrade then return end

    local upgrade = card.upgrade
    local state = self.runState

    state.takenSet[upgrade.id] = (state.takenSet[upgrade.id] or 0) + 1
    table.insert(state.takenOrder, upgrade.id)

    if upgrade.tags then
        for _, tag in ipairs(upgrade.tags) do
            self:addTag(tag)
        end
    end

    if upgrade.onAcquire then
        upgrade.onAcquire(state, context)
    end

    if upgrade.handlers then
        for event, handler in pairs(upgrade.handlers) do
            self:addEventHandler(event, handler)
        end
    end

    self:applyPersistentEffects(false)
end

return Upgrades
