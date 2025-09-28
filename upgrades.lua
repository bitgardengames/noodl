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
    },
    epic = {
        weight = 2,
        label = "Epic",
        color = {1, 0.52, 0.28, 1},
    },
    legendary = {
        weight = 0.35,
        label = "Legendary",
        color = {1, 0.84, 0.2, 1},
    },
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
    sawSinkDuration = 0,
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
    shopSlots = 0,
    wallPortal = false,
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

local function celebrateUpgrade(label, data, options)
    options = options or {}

    local fx = options.x
    local fy = options.y
    if not fx or not fy then
        fx, fy = getEventPosition(data)
    end

    if fx and fy and label and not options.skipText and FloatingText then
        local textColor = options.textColor or options.color or {1, 1, 1, 1}
        local textOffset = options.textOffset or 44
        local textScale = options.textScale or 1.05
        local textLife = options.textLife or 56
        FloatingText:add(label, fx, fy - textOffset, textColor, textScale, textLife)
    end

    if fx and fy and not options.skipParticles and Particles then
        local particleOptions
        if options.particles then
            particleOptions = deepcopy(options.particles)
        else
            particleOptions = {
                count = options.particleCount or 12,
                speed = options.particleSpeed or 110,
                life = options.particleLife or 0.45,
                size = options.particleSize or 4,
                spread = options.particleSpread or math.pi * 2,
                angleJitter = options.particleAngleJitter,
                speedVariance = options.particleSpeedVariance,
                scaleMin = options.particleScaleMin,
                scaleVariance = options.particleScaleVariance,
                drag = options.particleDrag,
                gravity = options.particleGravity,
                fadeTo = options.particleFadeTo,
            }
        end

        particleOptions = particleOptions or {}
        if particleOptions.count == nil then
            particleOptions.count = 12
        end
        if particleOptions.color == nil then
            particleOptions.color = options.particleColor or options.color
        end

        Particles:spawnBurst(fx, fy, particleOptions)
    end
end

local function stoneSkinShieldHandler(data, state)
    if not state then return end
    if (state.takenSet and (state.takenSet["stone_skin"] or 0) <= 0) then return end
    if not data or data.cause ~= "rock" then return end
    if not Rocks or not Rocks.shatterNearest then return end

    local fx, fy = getEventPosition(data)
    celebrateUpgrade("Stone Skin!", nil, {
        x = fx,
        y = fy,
        color = {0.75, 0.82, 0.88, 1},
        particleCount = 16,
        particleSpeed = 100,
        particleLife = 0.42,
        textOffset = 52,
        textScale = 1.08,
    })
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

local function countUpgradesWithTag(state, tag)
    if not state or not tag then return 0 end

    local total = 0
    if not state.takenSet then return total end

    for id, count in pairs(state.takenSet) do
        local upgrade = poolById[id]
        if upgrade and upgrade.tags then
            for _, upgradeTag in ipairs(upgrade.tags) do
                if upgradeTag == tag then
                    total = total + (count or 0)
                    break
                end
            end
        end
    end

    return total
end

local function updateResonantShellBonus(state)
    if not state then return end

    local perBonus = state.counters and state.counters.resonantShellPerBonus or 0
    if perBonus <= 0 then return end

    local previous = state.counters.resonantShellBonus or 0
    local defenseCount = countUpgradesWithTag(state, "defense")
    local newBonus = perBonus * defenseCount
    state.counters.resonantShellBonus = newBonus
    state.effects.sawStall = (state.effects.sawStall or 0) - previous + newBonus
end

local function updateLinkedHydraulics(state)
    if not state then return end

    local perStack = state.counters and state.counters.linkedHydraulicsPerStack or 0
    local perStall = state.counters and state.counters.linkedHydraulicsPerStall or 0
    if perStack <= 0 and perStall <= 0 then return end

    local stacks = 0
    if state.takenSet then
        stacks = state.takenSet.hydraulic_tracks or 0
    end

    local stall = 0
    if state.effects then
        stall = state.effects.sawStall or 0
    end

    local previous = state.counters.linkedHydraulicsBonus or 0
    local newBonus = stacks * perStack + stall * perStall
    state.counters.linkedHydraulicsBonus = newBonus
    state.effects.sawSinkDuration = (state.effects.sawSinkDuration or 0) - previous + newBonus
end

local function updateGuildLedger(state)
    if not state then return end

    local perSlot = state.counters and state.counters.guildLedgerFlatPerSlot or 0
    if perSlot == 0 then return end

    local slots = 0
    if state.effects then
        slots = state.effects.shopSlots or 0
    end

    local previous = state.counters.guildLedgerBonus or 0
    local newBonus = -(perSlot * slots)
    state.counters.guildLedgerBonus = newBonus
    state.effects.rockSpawnFlat = (state.effects.rockSpawnFlat or 0) - previous + newBonus
end

local function updateComboHarmonizer(state)
    if not state then return end

    local perCombo = state.counters and state.counters.comboHarmonizerPerTag or 0
    if perCombo == 0 then return end

    local previous = state.counters.comboHarmonizerBonus or 0
    local comboCount = countUpgradesWithTag(state, "combo")
    local newBonus = perCombo * comboCount
    state.counters.comboHarmonizerBonus = newBonus
    state.effects.comboWindowBonus = (state.effects.comboWindowBonus or 0) - previous + newBonus
end

local function updateStoneCensus(state)
    if not state then return end

    local perEconomy = state.counters and state.counters.stoneCensusReduction or 0
    if perEconomy == 0 then return end

    local previous = state.counters.stoneCensusMult or 1
    if previous <= 0 then previous = 1 end

    local effects = state.effects or {}
    effects.rockSpawnMult = effects.rockSpawnMult or 1
    effects.rockSpawnMult = effects.rockSpawnMult / previous

    local economyCount = countUpgradesWithTag(state, "economy")
    local newMult = math.max(0.2, 1 - perEconomy * economyCount)

    state.counters.stoneCensusMult = newMult
    effects.rockSpawnMult = effects.rockSpawnMult * newMult
    state.effects = effects
end

local function handleBulwarkChorusFloorStart(_, state)
    if not state or not state.counters then return end
    if not state.takenSet or (state.takenSet.wardens_chorus or 0) <= 0 then return end

    local perDefense = state.counters.bulwarkChorusPerDefense or 0
    if perDefense <= 0 then return end

    local defenseCount = countUpgradesWithTag(state, "defense")
    if defenseCount <= 0 then return end

    local progress = (state.counters.bulwarkChorusProgress or 0) + perDefense * defenseCount
    local shields = math.floor(progress)
    state.counters.bulwarkChorusProgress = progress - shields

    if shields > 0 and Snake.addCrashShields then
        Snake:addCrashShields(shields)
        celebrateUpgrade("Warden's Chorus", nil, {
            color = {0.7, 0.9, 1.0, 1},
            skipParticles = true,
            textScale = 1.0,
            textLife = 44,
        })
    end
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
            celebrateUpgrade("Quick Fangs", nil, {
                color = {1, 0.63, 0.42, 1},
                particleCount = 18,
                particleSpeed = 150,
                particleLife = 0.38,
                textOffset = 46,
                textScale = 1.18,
            })
            if not state.counters.quickFangsHandlerRegistered then
                state.counters.quickFangsHandlerRegistered = true
                Upgrades:addEventHandler("fruitCollected", function(data, runState)
                    local fx, fy = getEventPosition(data)
                    if not fx or not fy then return end

                    local stacks = (runState.takenSet and runState.takenSet.quick_fangs) or 1
                    if Particles then
                        Particles:spawnBurst(fx, fy, {
                            count = math.min(6 + stacks * 3, 24),
                            speed = 140 + stacks * 12,
                            life = 0.32,
                            size = 3,
                            color = {1, 0.55, 0.35, 1},
                            spread = math.pi * 1.2,
                            angleJitter = 0.4,
                            speedVariance = 50,
                        })
                    end

                    runState.counters.quickFangsCombo = (runState.counters.quickFangsCombo or 0) + 1
                    local threshold = math.max(1, 4 - stacks)
                    if runState.counters.quickFangsCombo >= threshold then
                        runState.counters.quickFangsCombo = 0
                        celebrateUpgrade("Fang Rush", nil, {
                            x = fx,
                            y = fy,
                            color = {1, 0.7, 0.45, 1},
                            skipParticles = true,
                            textOffset = 36,
                            textScale = 1 + 0.02 * stacks,
                            textLife = 48,
                        })
                    end
                end)
            end
        end,
    }),
    register({
        id = "stone_skin",
        name = "Stone Skin",
        desc = "Gain a crash shield that shatters rocks and shrugs off a saw clip.",
        rarity = "uncommon",
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
            celebrateUpgrade("Stone Skin", nil, {
                color = {0.75, 0.82, 0.88, 1},
                particleCount = 14,
                particleSpeed = 90,
                particleLife = 0.45,
                textOffset = 50,
                textScale = 1.12,
            })
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
            celebrateUpgrade("Saw Grease", nil, {
                color = {0.96, 0.78, 0.4, 1},
                particleCount = 12,
                particleSpeed = 80,
                particleLife = 0.4,
                textOffset = 40,
                textScale = 1.08,
            })
        end,
    }),
    register({
        id = "hydraulic_tracks",
        name = "Hydraulic Tracks",
        desc = "Fruit retracts saws for 1.5s (+1.5s per stack).",
        rarity = "uncommon",
        allowDuplicates = true,
        maxStacks = 3,
        onAcquire = function(state)
            local durationPerStack = 1.5
            state.effects.sawSinkDuration = (state.effects.sawSinkDuration or 0) + durationPerStack

            if not state.counters.hydraulicTracksHandlerRegistered then
                state.counters.hydraulicTracksHandlerRegistered = true
                Upgrades:addEventHandler("fruitCollected", function(data, runState)
                    local sinkDuration = (runState.effects and runState.effects.sawSinkDuration) or 0
                    if sinkDuration and sinkDuration > 0 and Saws and Saws.sink then
                        Saws:sink(sinkDuration)
                        celebrateUpgrade(nil, data, {
                            skipText = true,
                            color = {0.68, 0.84, 1, 1},
                            particleCount = 12,
                            particleSpeed = 90,
                            particleLife = 0.36,
                            particleSize = 3,
                            particleSpread = math.pi * 2,
                        })
                    end
                end)
            end

            celebrateUpgrade("Hydraulic Tracks", nil, {
                color = {0.68, 0.84, 1, 1},
                particleCount = 14,
                particleSpeed = 95,
                particleLife = 0.42,
                textOffset = 44,
                textScale = 1.1,
            })
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
            celebrateUpgrade("Early Exit", nil, {
                color = {1, 0.86, 0.36, 1},
                particleCount = 10,
                particleSpeed = 70,
                particleLife = 0.38,
                textOffset = 38,
                textScale = 1.04,
            })
        end,
    }),
    register({
        id = "metronome_totem",
        name = "Metronome Totem",
        desc = "Fruit adds +0.35s to the combo timer.",
        rarity = "common",
        tags = {"combo"},
        handlers = {
            fruitCollected = function(data)
                local FruitEvents = require("fruitevents")
                if FruitEvents.boostComboTimer then
                    FruitEvents.boostComboTimer(0.35)
                end
                if data and (data.combo or 0) >= 1 then
                    celebrateUpgrade("+0.35s", data, {
                        color = {0.55, 0.78, 0.58, 1},
                        particleCount = 8,
                        particleSpeed = 70,
                        particleLife = 0.35,
                        textOffset = 32,
                        textScale = 0.95,
                        textLife = 42,
                    })
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
            state.counters.adrenalineFruitCount = state.counters.adrenalineFruitCount or 0
            if not state.counters.adrenalineHandlerRegistered then
                state.counters.adrenalineHandlerRegistered = true
                Upgrades:addEventHandler("fruitCollected", function(data, runState)
                    runState.counters.adrenalineFruitCount = (runState.counters.adrenalineFruitCount or 0) + 1
                    local fx, fy = getEventPosition(data)
                    celebrateUpgrade(runState.counters.adrenalineFruitCount % 2 == 1 and "Adrenaline!" or nil, nil, {
                        x = fx,
                        y = fy,
                        color = {1, 0.42, 0.42, 1},
                        particleCount = 16,
                        particleSpeed = 150,
                        particleLife = 0.34,
                        particleSpread = math.pi * 2,
                        textOffset = 34,
                        textScale = 1.06,
                        textLife = 46,
                    })
                end)
            end
            celebrateUpgrade("Adrenaline Surge", nil, {
                color = {1, 0.42, 0.42, 1},
                particleCount = 20,
                particleSpeed = 160,
                particleLife = 0.36,
                textOffset = 42,
                textScale = 1.16,
            })
        end,
    }),
    register({
        id = "stone_whisperer",
        name = "Stone Whisperer",
        desc = "Rocks appear far less often after you snack.",
        rarity = "rare",
        onAcquire = function(state)
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.6
        end,
    }),
    register({
        id = "tail_trainer",
        name = "Tail Trainer",
        desc = "Gain an extra segment each time you grow and move 4% faster.",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 3,
        tags = {"speed"},
        onAcquire = function(state)
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
            Snake:addSpeedMultiplier(1.04)
        end,
    }),
    register({
        id = "pocket_springs",
        name = "Pocket Springs",
        desc = "Every 4 fruits forge a crash shield charge.",
        rarity = "rare",
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.pocketSprings = state.counters.pocketSprings or 0
        end,
        handlers = {
            fruitCollected = function(data, state)
                state.counters.pocketSprings = (state.counters.pocketSprings or 0) + 1
                if state.counters.pocketSprings >= 4 then
                    state.counters.pocketSprings = state.counters.pocketSprings - 4
                    Snake:addCrashShields(1)
                    local fx, fy = getEventPosition(data)
                    if FloatingText and fx and fy then
                        FloatingText:add("Pocket Springs", fx, fy - 44, {0.65, 0.92, 1, 1}, 1.0, 52)
                    end
                    if Particles and fx and fy then
                        Particles:spawnBurst(fx, fy, {
                            count = 10,
                            speed = 95,
                            life = 0.5,
                            size = 4,
                            color = {0.6, 0.9, 1, 1},
                            spread = math.pi * 2,
                        })
                    end
                end
            end,
        },
    }),
    register({
        id = "mapmakers_compass",
        name = "Mapmaker's Compass",
        desc = "Exit unlocks one fruit earlier but rocks spawn 15% more often.",
        rarity = "uncommon",
        tags = {"economy", "risk"},
        onAcquire = function(state)
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 1.15
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(-1)
            end
        end,
    }),
    register({
        id = "linked_hydraulics",
        name = "Linked Hydraulics",
        desc = "Hydraulic Tracks gain +0.75s sink time per stack and +0.25s per second of saw stall.",
        rarity = "rare",
        condition = function(state)
            return state and state.takenSet and (state.takenSet.hydraulic_tracks or 0) > 0
        end,
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.linkedHydraulicsPerStack = 0.75
            state.counters.linkedHydraulicsPerStall = 0.25
            updateLinkedHydraulics(state)

            if not state.counters.linkedHydraulicsHandlerRegistered then
                state.counters.linkedHydraulicsHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.linked_hydraulics or 0) <= 0 then return end
                    updateLinkedHydraulics(runState)
                end)
            end

            celebrateUpgrade("Linked Hydraulics", nil, {
                color = {0.62, 0.84, 1, 1},
                particleCount = 20,
                particleSpeed = 140,
                particleLife = 0.46,
                textOffset = 44,
                textScale = 1.14,
            })
        end,
    }),
    register({
        id = "twilight_parade",
        name = "Twilight Parade",
        desc = "Fruit at 4+ combo grant +2 bonus score and stall saws 0.8s.",
        rarity = "rare",
        tags = {"combo", "defense", "economy"},
        handlers = {
            fruitCollected = function(data)
                if not data or (data.combo or 0) < 4 then return end
                if Score.addBonus then
                    Score:addBonus(2)
                end
                if Saws and Saws.stall then
                    Saws:stall(0.8)
                end
                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Twilight Parade +2", fx, fy - 40, {0.85, 0.8, 1, 1}, 1.1, 52)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 14,
                        speed = 110,
                        life = 0.55,
                        size = 4,
                        color = {0.78, 0.72, 1, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
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
            state.effects.sawStall = (state.effects.sawStall or 0) + 2
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
        rarity = "rare",
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
                Snake.shieldBurst.stall = (Snake.shieldBurst.stall or 0) + 1.5
            end
        end,
    }),
    register({
        id = "resonant_shell",
        name = "Resonant Shell",
        desc = "Gain +0.35s saw stall for every Defense upgrade you've taken.",
        rarity = "rare",
        requiresTags = {"defense"},
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.resonantShellPerBonus = 0.35
            updateResonantShellBonus(state)

            if not state.counters.resonantShellHandlerRegistered then
                state.counters.resonantShellHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.resonant_shell or 0) <= 0 then return end
                    updateResonantShellBonus(runState)
                end)
            end

            celebrateUpgrade("Resonant Shell", nil, {
                color = {0.8, 0.88, 1, 1},
                particleCount = 18,
                particleSpeed = 120,
                particleLife = 0.48,
                textOffset = 48,
                textScale = 1.12,
            })
        end,
    }),
    register({
        id = "wardens_chorus",
        name = "Warden's Chorus",
        desc = "Floor starts build crash shield progress from each Defense upgrade.",
        rarity = "rare",
        requiresTags = {"defense"},
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.bulwarkChorusPerDefense = 0.33
            state.counters.bulwarkChorusProgress = state.counters.bulwarkChorusProgress or 0

            if not state.counters.bulwarkChorusHandlerRegistered then
                state.counters.bulwarkChorusHandlerRegistered = true
                Upgrades:addEventHandler("floorStart", handleBulwarkChorusFloorStart)
            end

            celebrateUpgrade("Warden's Chorus", nil, {
                color = {0.66, 0.88, 1, 1},
                particleCount = 18,
                particleSpeed = 120,
                particleLife = 0.46,
                textOffset = 46,
                textScale = 1.1,
            })
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
        id = "stone_census",
        name = "Stone Census",
        desc = "Each Economy upgrade cuts rock spawn chance by 7% (min 20%).",
        rarity = "rare",
        requiresTags = {"economy"},
        tags = {"economy", "defense"},
        onAcquire = function(state)
            state.counters.stoneCensusReduction = 0.07
            state.counters.stoneCensusMult = state.counters.stoneCensusMult or 1
            updateStoneCensus(state)

            if not state.counters.stoneCensusHandlerRegistered then
                state.counters.stoneCensusHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.stone_census or 0) <= 0 then return end
                    updateStoneCensus(runState)
                end)
            end

            celebrateUpgrade("Stone Census", nil, {
                color = {0.85, 0.92, 1, 1},
                particleCount = 16,
                particleSpeed = 110,
                particleLife = 0.4,
                textOffset = 44,
                textScale = 1.08,
            })
        end,
    }),
    register({
        id = "guild_ledger",
        name = "Guild Ledger",
        desc = "Each shop slot cuts rock spawn chance by 1.5%.",
        rarity = "rare",
        requiresTags = {"economy"},
        tags = {"economy", "defense"},
        onAcquire = function(state)
            state.counters.guildLedgerFlatPerSlot = 0.015
            updateGuildLedger(state)

            if not state.counters.guildLedgerHandlerRegistered then
                state.counters.guildLedgerHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.guild_ledger or 0) <= 0 then return end
                    updateGuildLedger(runState)
                end)
            end

            celebrateUpgrade("Guild Ledger", nil, {
                color = {1, 0.86, 0.46, 1},
                particleCount = 16,
                particleSpeed = 120,
                particleLife = 0.42,
                textOffset = 42,
                textScale = 1.1,
            })
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
        id = "combo_harmonizer",
        name = "Combo Harmonizer",
        desc = "Combo window extends 0.12s for every Combo upgrade you own.",
        rarity = "rare",
        requiresTags = {"combo"},
        tags = {"combo"},
        onAcquire = function(state)
            state.counters.comboHarmonizerPerTag = 0.12
            updateComboHarmonizer(state)

            if not state.counters.comboHarmonizerHandlerRegistered then
                state.counters.comboHarmonizerHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.combo_harmonizer or 0) <= 0 then return end
                    updateComboHarmonizer(runState)
                end)
            end

            celebrateUpgrade("Combo Harmonizer", nil, {
                color = {0.82, 0.78, 1, 1},
                particleCount = 18,
                particleSpeed = 115,
                particleLife = 0.45,
                textOffset = 44,
                textScale = 1.12,
            })
        end,
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
            state.effects.sawStall = (state.effects.sawStall or 0) + 1.5
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
        id = "tempest_nectar",
        name = "Tempest Nectar",
        desc = "Fruit grant +1 bonus score and stall saws for 0.6s.",
        rarity = "rare",
        tags = {"economy", "defense"},
        handlers = {
            fruitCollected = function(data)
                if Saws and Saws.stall then
                    Saws:stall(0.6)
                end
                if Score.addBonus then
                    Score:addBonus(1)
                end
                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Tempest Nectar +1", fx, fy - 40, {0.8, 0.95, 1, 1}, 1.0, 52)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 10,
                        speed = 90,
                        life = 0.45,
                        size = 4,
                        color = {0.55, 0.82, 1, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
    }),
    register({
        id = "spectral_harvest",
        name = "Spectral Harvest",
        desc = "Once per floor, echoes collect the next fruit instantly after you do.",
        rarity = "epic",
        tags = {"economy", "combo"},
        onAcquire = function(state)
            state.counters.spectralHarvestReady = true
        end,
        handlers = {
            floorStart = function(_, state)
                state.counters.spectralHarvestReady = true
            end,
            fruitCollected = function(_, state)
                if not state.counters.spectralHarvestReady then return end
                state.counters.spectralHarvestReady = false

                local Fruit = require("fruit")
                local FruitEvents = require("fruitevents")
                if not (Fruit and FruitEvents and FruitEvents.handleConsumption) then return end

                local fx, fy = Fruit:getPosition()
                if not (fx and fy) then return end

                celebrateUpgrade("Spectral Harvest", nil, {
                    x = fx,
                    y = fy,
                    color = {0.76, 0.9, 1, 1},
                    particleCount = 18,
                    particleSpeed = 120,
                    particleLife = 0.55,
                    textOffset = 56,
                    textScale = 1.14,
                })

                FruitEvents.handleConsumption(fx, fy)
            end,
        },
    }),
    register({
        id = "solar_reservoir",
        name = "Solar Reservoir",
        desc = "First fruit each floor stalls saws 2s and grants +4 bonus score.",
        rarity = "epic",
        tags = {"economy", "defense"},
        onAcquire = function(state)
            state.counters.solarReservoirReady = false
        end,
        handlers = {
            floorStart = function(_, state)
                state.counters.solarReservoirReady = true
            end,
            fruitCollected = function(data, state)
                if not state.counters.solarReservoirReady then return end
                state.counters.solarReservoirReady = false
                if Saws and Saws.stall then
                    Saws:stall(2)
                end
                if Score.addBonus then
                    Score:addBonus(4)
                end
                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Solar Reservoir +4", fx, fy - 52, {1, 0.86, 0.32, 1}, 1.2, 62)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 16,
                        speed = 130,
                        life = 0.65,
                        size = 5,
                        color = {1, 0.74, 0.28, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
    }),
    register({
        id = "crystal_cache",
        name = "Crystal Cache",
        desc = "Crash shields burst into motes worth +2 bonus score.",
        rarity = "rare",
        tags = {"economy", "defense"},
        handlers = {
            shieldConsumed = function(data)
                if Score.addBonus then
                    Score:addBonus(2)
                end
                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add("Crystal Cache +2", fx, fy - 60, {0.86, 0.96, 1, 1}, 1.1, 60)
                end
                if Particles and fx and fy then
                    Particles:spawnBurst(fx, fy, {
                        count = 12,
                        speed = 115,
                        life = 0.55,
                        size = 5,
                        color = {0.72, 0.92, 1, 1},
                        spread = math.pi * 2,
                    })
                end
            end,
        },
    }),
    register({
        id = "tectonic_resolve",
        name = "Tectonic Resolve",
        desc = "Rock spawns -15%. Begin each floor with +1 crash shield.",
        rarity = "rare",
        tags = {"defense"},
        onAcquire = function(state)
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.85
            Snake:addCrashShields(1)
        end,
        handlers = {
            floorStart = function()
                Snake:addCrashShields(1)
            end,
        },
    }),
    register({
        id = "titanblood_pact",
        name = "Titanblood Pact",
        desc = "Gain +3 crash shields and saw stall +2s, but grow by +5 and gain +1 extra growth.",
        rarity = "epic",
        tags = {"defense", "risk"},
        weight = 1,
        onAcquire = function(state)
            Snake:addCrashShields(3)
            state.effects.sawStall = (state.effects.sawStall or 0) + 2
            for _ = 1, 5 do
                Snake:grow()
            end
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
        end,
    }),
    register({
        id = "chronospiral_core",
        name = "Chronospiral Core",
        desc = "Saws slow by 25% and spin 40% slower, combo rewards +60%, but grow by +4 and gain +1 extra growth.",
        rarity = "epic",
        tags = {"combo", "defense", "risk"},
        weight = 1,
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 0.75
            state.effects.sawSpinMult = (state.effects.sawSpinMult or 1) * 0.6
            state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.6
            for _ = 1, 4 do
                Snake:grow()
            end
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
        end,
    }),
    register({
        id = "phoenix_echo",
        name = "Phoenix Echo",
        desc = "Once per run, a fatal crash rewinds the floor instead of ending the run.",
        rarity = "epic",
        tags = {"defense", "risk"},
        onAcquire = function(state)
            state.counters.phoenixEchoCharges = (state.counters.phoenixEchoCharges or 0) + 1
        end,
    }),
    register({
        id = "event_horizon",
        name = "Event Horizon",
        desc = "Legendary: Colliding with a wall opens a portal that ejects you from the opposite side of the arena.",
        rarity = "legendary",
        tags = {"defense", "mobility"},
        allowDuplicates = false,
        weight = 1,
        onAcquire = function(state)
            state.effects.wallPortal = true
            celebrateUpgrade("Event Horizon", nil, {
                color = {1, 0.86, 0.34, 1},
                particleCount = 32,
                particleSpeed = 160,
                particleLife = 0.6,
                particleSize = 5,
                particleSpread = math.pi * 2,
                particleSpeedVariance = 90,
            })
        end,
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

    return bonus, breakdown
end

function Upgrades:tryFloorReplay(game, cause)
    if not game then return false end

    local state = self.runState
    if not state or not state.counters then return false end

    local charges = state.counters.phoenixEchoCharges or 0
    if charges <= 0 then return false end

    state.counters.phoenixEchoCharges = charges - 1
    state.counters.phoenixEchoUsed = (state.counters.phoenixEchoUsed or 0) + 1
    state.counters.phoenixEchoLastCause = cause

    game.transitionPhase = nil
    game.transitionTimer = 0
    game.transitionDuration = 0
    game.shopCloseRequested = nil

    game:setupFloor(game.floor)
    game.state = "playing"
    game.deathCause = nil

    local hx, hy = Snake:getHead()
    celebrateUpgrade("Phoenix Echo", nil, {
        x = hx,
        y = hy,
        color = {1, 0.62, 0.32, 1},
        particleCount = 24,
        particleSpeed = 170,
        particleLife = 0.6,
        textOffset = 60,
        textScale = 1.22,
    })

    return true
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
    local stallValue = stallBase + stallBonus
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

    self:notify("upgradeAcquired", { id = upgrade.id, upgrade = upgrade, context = context })
    self:applyPersistentEffects(false)
end

return Upgrades
