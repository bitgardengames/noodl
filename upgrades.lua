local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Score = require("score")
local UI = require("ui")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local PlayerStats = require("playerstats")
local UpgradeHelpers = require("upgradehelpers")

local Upgrades = {}
local poolById = {}
local getUpgradeString = UpgradeHelpers.getUpgradeString
local rarities = UpgradeHelpers.rarities
local deepcopy = UpgradeHelpers.deepcopy
local defaultEffects = UpgradeHelpers.defaultEffects
local celebrateUpgrade = UpgradeHelpers.celebrateUpgrade
local getEventPosition = UpgradeHelpers.getEventPosition

local function stoneSkinShieldHandler(data, state)
    if not state then return end
    if (state.takenSet and (state.takenSet["stone_skin"] or 0) <= 0) then return end
    if not data or data.cause ~= "rock" then return end
    if not Rocks or not Rocks.shatterNearest then return end

    local fx, fy = getEventPosition(data)
    celebrateUpgrade(getUpgradeString("stone_skin", "shield_text"), nil, {
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
    if upgrade.name and not upgrade.nameKey then
        upgrade.nameKey = upgrade.name
        upgrade.name = nil
    end
    if upgrade.desc and not upgrade.descKey then
        upgrade.descKey = upgrade.desc
        upgrade.desc = nil
    end
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
        celebrateUpgrade(getUpgradeString("wardens_chorus", "name"), nil, {
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
        nameKey = "upgrades.quick_fangs.name",
        descKey = "upgrades.quick_fangs.description",
        rarity = "uncommon",
        allowDuplicates = true,
        maxStacks = 4,
        onAcquire = function(state)
            Snake:addSpeedMultiplier(1.10)
            celebrateUpgrade(getUpgradeString("quick_fangs", "name"), nil, {
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
                        celebrateUpgrade(getUpgradeString("quick_fangs", "combo_celebration"), nil, {
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
        nameKey = "upgrades.stone_skin.name",
        descKey = "upgrades.stone_skin.description",
        rarity = "rare",
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
            celebrateUpgrade(getUpgradeString("stone_skin", "name"), nil, {
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
        nameKey = "upgrades.aegis_recycler.name",
        descKey = "upgrades.aegis_recycler.description",
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
                        FloatingText:add(getUpgradeString("aegis_recycler", "reforged"), fx, fy - 52, {0.6, 0.85, 1, 1}, 1.1, 60)
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
        nameKey = "upgrades.saw_grease.name",
        descKey = "upgrades.saw_grease.description",
        rarity = "common",
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 0.8
            celebrateUpgrade(getUpgradeString("saw_grease", "name"), nil, {
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
        nameKey = "upgrades.hydraulic_tracks.name",
        descKey = "upgrades.hydraulic_tracks.description",
        rarity = "uncommon",
        allowDuplicates = true,
        maxStacks = 3,
        onAcquire = function(state)
            local durationPerStack = 0.5
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

            celebrateUpgrade(getUpgradeString("hydraulic_tracks", "name"), nil, {
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
        nameKey = "upgrades.extra_bite.name",
        descKey = "upgrades.extra_bite.description",
        rarity = "common",
        onAcquire = function(state)
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(-1)
            end
            celebrateUpgrade(getUpgradeString("extra_bite", "celebration"), nil, {
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
        nameKey = "upgrades.metronome_totem.name",
        descKey = "upgrades.metronome_totem.description",
        rarity = "common",
        tags = {"combo"},
        handlers = {
            fruitCollected = function(data)
                local FruitEvents = require("fruitevents")
                if FruitEvents.boostComboTimer then
                    FruitEvents.boostComboTimer(0.35)
                end
                if data and (data.combo or 0) >= 1 then
                    celebrateUpgrade(getUpgradeString("metronome_totem", "timer_bonus"), data, {
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
        nameKey = "upgrades.adrenaline_surge.name",
        descKey = "upgrades.adrenaline_surge.description",
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
                    local shout = getUpgradeString("adrenaline_surge", "adrenaline_shout")
                    celebrateUpgrade(runState.counters.adrenalineFruitCount % 2 == 1 and shout or nil, nil, {
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
            celebrateUpgrade(getUpgradeString("adrenaline_surge", "name"), nil, {
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
        nameKey = "upgrades.stone_whisperer.name",
        descKey = "upgrades.stone_whisperer.description",
        rarity = "common",
        onAcquire = function(state)
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.6
        end,
    }),
    register({
        id = "tail_trainer",
        nameKey = "upgrades.tail_trainer.name",
        descKey = "upgrades.tail_trainer.description",
        rarity = "common",
        allowDuplicates = true,
        maxStacks = 3,
        tags = {"speed"},
        onAcquire = function(state)
            Snake:addSpeedMultiplier(1.04)
        end,
    }),
    register({
        id = "deliberate_coil",
        nameKey = "upgrades.deliberate_coil.name",
        descKey = "upgrades.deliberate_coil.description",
        rarity = "epic",
        tags = {"speed", "risk"},
        onAcquire = function(state)
            Snake:addSpeedMultiplier(0.85)
            state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1
            if UI.adjustFruitGoal then
                UI:adjustFruitGoal(1)
            end
            celebrateUpgrade(getUpgradeString("deliberate_coil", "name"), nil, {
                color = {0.76, 0.56, 0.88, 1},
                particleCount = 16,
                particleSpeed = 90,
                particleLife = 0.5,
                textOffset = 40,
                textScale = 1.08,
            })
        end,
    }),
    register({
        id = "pocket_springs",
        nameKey = "upgrades.pocket_springs.name",
        descKey = "upgrades.pocket_springs.description",
        rarity = "rare",
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.pocketSprings = state.counters.pocketSprings or 0
        end,
        handlers = {
            fruitCollected = function(data, state)
                if not state or not state.takenSet or (state.takenSet.pocket_springs or 0) <= 0 then
                    return
                end

                state.counters.pocketSprings = (state.counters.pocketSprings or 0) + 1
                if state.counters.pocketSprings >= 8 then
                    state.counters.pocketSprings = state.counters.pocketSprings - 8
                    Snake:addCrashShields(1)
                    local fx, fy = getEventPosition(data)
                    if FloatingText and fx and fy then
                        FloatingText:add(getUpgradeString("pocket_springs", "name"), fx, fy - 44, {0.65, 0.92, 1, 1}, 1.0, 52)
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
        nameKey = "upgrades.mapmakers_compass.name",
        descKey = "upgrades.mapmakers_compass.description",
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
        nameKey = "upgrades.linked_hydraulics.name",
        descKey = "upgrades.linked_hydraulics.description",
        rarity = "rare",
        condition = function(state)
            return state and state.takenSet and (state.takenSet.hydraulic_tracks or 0) > 0
        end,
        tags = {"defense"},
        onAcquire = function(state)
            state.counters.linkedHydraulicsPerStack = 1.5
            state.counters.linkedHydraulicsPerStall = 0.5
            updateLinkedHydraulics(state)

            if not state.counters.linkedHydraulicsHandlerRegistered then
                state.counters.linkedHydraulicsHandlerRegistered = true
                Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
                    if not runState then return end
                    if not runState.takenSet or (runState.takenSet.linked_hydraulics or 0) <= 0 then return end
                    updateLinkedHydraulics(runState)
                end)
            end

            celebrateUpgrade(getUpgradeString("linked_hydraulics", "name"), nil, {
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
        nameKey = "upgrades.twilight_parade.name",
        descKey = "upgrades.twilight_parade.description",
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
                    FloatingText:add(getUpgradeString("twilight_parade", "combo_bonus"), fx, fy - 40, {0.85, 0.8, 1, 1}, 1.1, 52)
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
        nameKey = "upgrades.lucky_bite.name",
        descKey = "upgrades.lucky_bite.description",
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
        nameKey = "upgrades.momentum_memory.name",
        descKey = "upgrades.momentum_memory.description",
        rarity = "uncommon",
        requiresTags = {"adrenaline"},
        onAcquire = function(state)
            state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
            state.effects.adrenalineDurationBonus = (state.effects.adrenalineDurationBonus or 0) + 2
        end,
    }),
    register({
        id = "molting_reflex",
        nameKey = "upgrades.molting_reflex.name",
        descKey = "upgrades.molting_reflex.description",
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
                    FloatingText:add(getUpgradeString("molting_reflex", "name"), fx, fy - 44, {0.92, 0.98, 0.85, 1}, 1.0, 58)
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
        nameKey = "upgrades.circuit_breaker.name",
        descKey = "upgrades.circuit_breaker.description",
        rarity = "uncommon",
        onAcquire = function(state)
            state.effects.sawStall = (state.effects.sawStall or 0) + 1
        end,
    }),
    register({
        id = "stonebreaker_hymn",
        nameKey = "upgrades.stonebreaker_hymn.name",
        descKey = "upgrades.stonebreaker_hymn.description",
        rarity = "rare",
        allowDuplicates = true,
        maxStacks = 2,
        onAcquire = function(state)
            state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
            state.counters.stonebreakerStacks = (state.counters.stonebreakerStacks or 0) + 1
            if Snake.setStonebreakerStacks then
                Snake:setStonebreakerStacks(state.counters.stonebreakerStacks)
            end
        end,
    }),
    register({
        id = "echo_aegis",
        nameKey = "upgrades.echo_aegis.name",
        descKey = "upgrades.echo_aegis.description",
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
        nameKey = "upgrades.resonant_shell.name",
        descKey = "upgrades.resonant_shell.description",
        rarity = "rare",
        requiresTags = {"defense"},
        tags = {"defense"},
        unlockTag = "specialist",
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

            celebrateUpgrade(getUpgradeString("resonant_shell", "name"), nil, {
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
        nameKey = "upgrades.wardens_chorus.name",
        descKey = "upgrades.wardens_chorus.description",
        rarity = "rare",
        requiresTags = {"defense"},
        tags = {"defense"},
        unlockTag = "specialist",
        onAcquire = function(state)
            state.counters.bulwarkChorusPerDefense = 0.33
            state.counters.bulwarkChorusProgress = state.counters.bulwarkChorusProgress or 0

            if not state.counters.bulwarkChorusHandlerRegistered then
                state.counters.bulwarkChorusHandlerRegistered = true
                Upgrades:addEventHandler("floorStart", handleBulwarkChorusFloorStart)
            end

            celebrateUpgrade(getUpgradeString("wardens_chorus", "name"), nil, {
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
        nameKey = "upgrades.gilded_trail.name",
        descKey = "upgrades.gilded_trail.description",
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
                        FloatingText:add(getUpgradeString("gilded_trail", "combo_bonus"), data.x, data.y - 36, {1, 0.88, 0.35, 1}, 1.2, 55)
                    end
                end
            end,
        },
    }),
    register({
        id = "momentum_cache",
        nameKey = "upgrades.momentum_cache.name",
        descKey = "upgrades.momentum_cache.description",
        rarity = "uncommon",
        tags = {"economy", "risk"},
        onAcquire = function(state)
            state.effects.comboBonusFlat = (state.effects.comboBonusFlat or 0) + 1
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.05
        end,
    }),
    register({
        id = "aurora_band",
        nameKey = "upgrades.aurora_band.name",
        descKey = "upgrades.aurora_band.description",
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
        nameKey = "upgrades.caravan_contract.name",
        descKey = "upgrades.caravan_contract.description",
        rarity = "uncommon",
        tags = {"economy", "risk"},
        onAcquire = function(state)
            state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
            state.effects.rockSpawnBonus = (state.effects.rockSpawnBonus or 0) + 1
        end,
    }),
    register({
        id = "fresh_supplies",
        nameKey = "upgrades.fresh_supplies.name",
        descKey = "upgrades.fresh_supplies.description",
        rarity = "common",
        tags = {"economy"},
        restockShop = true,
        allowDuplicates = true,
        weight = 0.6,
    }),
    register({
        id = "stone_census",
        nameKey = "upgrades.stone_census.name",
        descKey = "upgrades.stone_census.description",
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

            celebrateUpgrade(getUpgradeString("stone_census", "name"), nil, {
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
        nameKey = "upgrades.guild_ledger.name",
        descKey = "upgrades.guild_ledger.description",
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

            celebrateUpgrade(getUpgradeString("guild_ledger", "name"), nil, {
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
        nameKey = "upgrades.venomous_hunger.name",
        descKey = "upgrades.venomous_hunger.description",
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
        nameKey = "upgrades.predators_reflex.name",
        descKey = "upgrades.predators_reflex.description",
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
        nameKey = "upgrades.combo_harmonizer.name",
        descKey = "upgrades.combo_harmonizer.description",
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

            celebrateUpgrade(getUpgradeString("combo_harmonizer", "name"), nil, {
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
        nameKey = "upgrades.grim_reliquary.name",
        descKey = "upgrades.grim_reliquary.description",
        rarity = "rare",
        requiresTags = {"risk"},
        tags = {"defense"},
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.1
            state.effects.sawStall = (state.effects.sawStall or 0) + 0.6
        end,
    }),
    register({
        id = "relentless_pursuit",
        nameKey = "upgrades.relentless_pursuit.name",
        descKey = "upgrades.relentless_pursuit.description",
        rarity = "rare",
        onAcquire = function(state)
            state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 1.15
            state.effects.sawStall = (state.effects.sawStall or 0) + 1.5
        end,
    }),
    register({
        id = "ember_engine",
        nameKey = "upgrades.ember_engine.name",
        descKey = "upgrades.ember_engine.description",
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
                    FloatingText:add(getUpgradeString("ember_engine", "name"), data.x, data.y - 48, {1, 0.58, 0.2, 1}, 1.2, 55)
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
        nameKey = "upgrades.tempest_nectar.name",
        descKey = "upgrades.tempest_nectar.description",
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
                    FloatingText:add(getUpgradeString("tempest_nectar", "combo_bonus"), fx, fy - 40, {0.8, 0.95, 1, 1}, 1.0, 52)
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
        nameKey = "upgrades.spectral_harvest.name",
        descKey = "upgrades.spectral_harvest.description",
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

                celebrateUpgrade(getUpgradeString("spectral_harvest", "name"), nil, {
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
        nameKey = "upgrades.solar_reservoir.name",
        descKey = "upgrades.solar_reservoir.description",
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
                    FloatingText:add(getUpgradeString("solar_reservoir", "combo_bonus"), fx, fy - 52, {1, 0.86, 0.32, 1}, 1.2, 62)
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
        nameKey = "upgrades.crystal_cache.name",
        descKey = "upgrades.crystal_cache.description",
        rarity = "rare",
        tags = {"economy", "defense"},
        handlers = {
            shieldConsumed = function(data)
                if Score.addBonus then
                    Score:addBonus(2)
                end
                local fx, fy = getEventPosition(data)
                if FloatingText and fx and fy then
                    FloatingText:add(getUpgradeString("crystal_cache", "combo_bonus"), fx, fy - 60, {0.86, 0.96, 1, 1}, 1.1, 60)
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
        nameKey = "upgrades.tectonic_resolve.name",
        descKey = "upgrades.tectonic_resolve.description",
        rarity = "rare",
        tags = {"defense"},
        onAcquire = function(state)
            state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.85
            state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
        end,
    }),
    register({
        id = "titanblood_pact",
        nameKey = "upgrades.titanblood_pact.name",
        descKey = "upgrades.titanblood_pact.description",
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
        nameKey = "upgrades.chronospiral_core.name",
        descKey = "upgrades.chronospiral_core.description",
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
        nameKey = "upgrades.phoenix_echo.name",
        descKey = "upgrades.phoenix_echo.description",
        rarity = "epic",
        tags = {"defense", "risk"},
        onAcquire = function(state)
            state.counters.phoenixEchoCharges = (state.counters.phoenixEchoCharges or 0) + 1
        end,
    }),
    register({
        id = "thunder_dash",
        nameKey = "upgrades.thunder_dash.name",
        descKey = "upgrades.thunder_dash.description",
        rarity = "rare",
        tags = {"mobility"},
        allowDuplicates = false,
        unlockTag = "abilities",
        onAcquire = function(state)
            local dash = state.effects.dash or {}
            dash.duration = dash.duration or 0.35
            dash.cooldown = dash.cooldown or 6
            dash.speedMult = dash.speedMult or 2.4
            dash.breaksRocks = true
            state.effects.dash = dash

            if not state.counters.thunderDashHandlerRegistered then
                state.counters.thunderDashHandlerRegistered = true
                Upgrades:addEventHandler("dashActivated", function(data)
                    local label = getUpgradeString("thunder_dash", "activation_text")
                    celebrateUpgrade(label, data, {
                        color = {1.0, 0.78, 0.32, 1},
                        particleCount = 24,
                        particleSpeed = 160,
                        particleLife = 0.35,
                        particleSize = 4,
                        particleSpread = math.pi * 2,
                        particleSpeedVariance = 90,
                        textOffset = 52,
                        textScale = 1.14,
                    })
                end)
            end
        end,
    }),
    register({
        id = "temporal_anchor",
        nameKey = "upgrades.temporal_anchor.name",
        descKey = "upgrades.temporal_anchor.description",
        rarity = "rare",
        tags = {"utility", "defense"},
        allowDuplicates = false,
        unlockTag = "timekeeper",
        onAcquire = function(state)
            local ability = state.effects.timeSlow or {}
            ability.duration = ability.duration or 1.6
            ability.cooldown = ability.cooldown or 8
            ability.timeScale = ability.timeScale or 0.35
            state.effects.timeSlow = ability

            if not state.counters.temporalAnchorHandlerRegistered then
                state.counters.temporalAnchorHandlerRegistered = true
                Upgrades:addEventHandler("timeDilationActivated", function(data)
                    local label = getUpgradeString("temporal_anchor", "activation_text")
                    celebrateUpgrade(label, data, {
                        color = {0.62, 0.84, 1.0, 1},
                        particleCount = 26,
                        particleSpeed = 120,
                        particleLife = 0.5,
                        particleSize = 5,
                        particleSpread = math.pi * 2,
                        particleSpeedVariance = 70,
                        textOffset = 60,
                        textScale = 1.12,
                    })
                end)
            end
        end,
    }),
    register({
        id = "zephyr_coils",
        nameKey = "upgrades.zephyr_coils.name",
        descKey = "upgrades.zephyr_coils.description",
        rarity = "rare",
        tags = {"mobility", "risk"},
        onAcquire = function(state)
            Snake:addSpeedMultiplier(1.2)
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
        end,
    }),
    register({
        id = "event_horizon",
        nameKey = "upgrades.event_horizon.name",
        descKey = "upgrades.event_horizon.description",
        rarity = "legendary",
        tags = {"defense", "mobility"},
        allowDuplicates = false,
        weight = 1,
        unlockTag = "legendary",
        onAcquire = function(state)
            state.effects.wallPortal = true
            celebrateUpgrade(getUpgradeString("event_horizon", "name"), nil, {
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

local function hudText(key, replacements)
    return Localization:get("upgrades.hud." .. key, replacements)
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

function Upgrades:getHUDIndicators()
    local indicators = {}
    local state = self.runState
    if not state then
        return indicators
    end

    local function hasUpgrade(id)
        if not state.takenSet then return false end
        return (state.takenSet[id] or 0) > 0
    end

    local stoneStacks = state.counters and state.counters.stonebreakerStacks or 0
    if stoneStacks > 0 then
        local label = Localization:get("upgrades.stonebreaker_hymn.name")
        local current = 0
        if Rocks.getShatterProgress then
            current = Rocks:getShatterProgress() or 0
        end

        local rate = 0
        if Rocks.getShatterRate then
            rate = Rocks:getShatterRate() or 0
        else
            rate = Rocks.shatterOnFruit or 0
        end

        local progress = 0
        local isReady = false
        if rate and rate > 0 then
            if rate >= 1 then
                progress = 1
                isReady = true
            else
                progress = clamp(current / rate, 0, 1)
                if progress >= 0.999 then
                    isReady = true
                end
            end
        end

        local statusKey
        if not rate or rate <= 0 then
            statusKey = "depleted"
        elseif isReady then
            statusKey = "ready"
        else
            statusKey = "charging"
        end

        local chargeLabel
        if rate and rate > 0 then
            chargeLabel = hudText("percent", { percent = math.floor(progress * 100 + 0.5) })
        end

        table.insert(indicators, {
            id = "stonebreaker_hymn",
            label = label,
            accentColor = {1.0, 0.78, 0.36, 1},
            stackCount = stoneStacks,
            charge = progress,
            chargeLabel = chargeLabel,
            status = hudText(statusKey),
            icon = "pickaxe",
            showBar = true,
        })
    end

    local adrenalineTaken = hasUpgrade("adrenaline_surge")
    local adrenaline = Snake.adrenaline
    if adrenalineTaken or (adrenaline and adrenaline.active) then
        local label = Localization:get("upgrades.adrenaline_surge.name")
        local active = adrenaline and adrenaline.active
        local duration = (adrenaline and adrenaline.duration) or 0
        local timer = (adrenaline and math.max(adrenaline.timer or 0, 0)) or 0
        local charge
        local chargeLabel

        if active and duration > 0 then
            charge = clamp(timer / duration, 0, 1)
            chargeLabel = hudText("seconds", { seconds = string.format("%.1f", timer) })
        end

        local status = active and hudText("active") or hudText("ready")

        table.insert(indicators, {
            id = "adrenaline_surge",
            label = label,
            accentColor = {1.0, 0.45, 0.45, 1},
            stackCount = nil,
            charge = charge,
            chargeLabel = chargeLabel,
            status = status,
            icon = "bolt",
            showBar = active and charge ~= nil,
        })
    end

    local dashState = Snake.getDashState and Snake:getDashState()
    if dashState then
        local label = Localization:get("upgrades.thunder_dash.name")
        local accent = {1.0, 0.78, 0.32, 1}
        local status
        local charge
        local chargeLabel
        local showBar = false

        if dashState.active and dashState.duration > 0 then
            local remaining = math.max(dashState.timer or 0, 0)
            charge = clamp(remaining / dashState.duration, 0, 1)
            chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remaining) })
            status = hudText("active")
            showBar = true
        else
            local cooldown = dashState.cooldown or 0
            local remainingCooldown = math.max(dashState.cooldownTimer or 0, 0)
            if cooldown > 0 and remainingCooldown > 0 then
                local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
                charge = progress
                chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remainingCooldown) })
                status = hudText("charging")
                showBar = true
            else
                charge = 1
                status = hudText("ready")
            end
        end

        table.insert(indicators, {
            id = "thunder_dash",
            label = label,
            accentColor = accent,
            stackCount = nil,
            charge = charge,
            chargeLabel = chargeLabel,
            status = status,
            icon = "bolt",
            showBar = showBar,
        })
    end

    local timeState = Snake.getTimeDilationState and Snake:getTimeDilationState()
    if timeState then
        local label = Localization:get("upgrades.temporal_anchor.name")
        local accent = {0.62, 0.84, 1.0, 1}
        local status
        local charge
        local chargeLabel
        local showBar = false

        if timeState.active and timeState.duration > 0 then
            local remaining = math.max(timeState.timer or 0, 0)
            charge = clamp(remaining / timeState.duration, 0, 1)
            chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remaining) })
            status = hudText("active")
            showBar = true
        else
            local cooldown = timeState.cooldown or 0
            local remainingCooldown = math.max(timeState.cooldownTimer or 0, 0)
            if cooldown > 0 and remainingCooldown > 0 then
                local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
                charge = progress
                chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remainingCooldown) })
                status = hudText("charging")
                showBar = true
            else
                charge = 1
                status = hudText("ready")
            end
        end

        table.insert(indicators, {
            id = "temporal_anchor",
            label = label,
            accentColor = accent,
            stackCount = nil,
            charge = charge,
            chargeLabel = chargeLabel,
            status = status,
            icon = "hourglass",
            showBar = showBar,
        })
    end

    local phoenixCharges = 0
    if state.counters then
        phoenixCharges = state.counters.phoenixEchoCharges or 0
    end

    if phoenixCharges > 0 then
        local label = Localization:get("upgrades.phoenix_echo.name")
        table.insert(indicators, {
            id = "phoenix_echo",
            label = label,
            accentColor = {1.0, 0.62, 0.32, 1},
            stackCount = phoenixCharges,
            charge = nil,
            status = nil,
            icon = "phoenix",
            showBar = false,
        })
    end

    return indicators
end

function Upgrades:recordFloorReplaySnapshot(game)
    if not game then return end

    local state = self.runState
    if not state or not state.counters then return end

    -- The phoenix upgrade no longer tracks snake position, so we don't need to
    -- capture any state here.
    return
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
            table.insert(breakdown, { label = Localization:get("upgrades.momentum_label"), amount = amount })
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
    game.transitionResumePhase = nil
    game.transitionResumeFadeDuration = nil

    local restored = false
    Snake:resetPosition()
    restored = true

    game.state = "playing"
    game.deathCause = nil

    local hx, hy = Snake:getHead()
    celebrateUpgrade(getUpgradeString("phoenix_echo", "name"), nil, {
        x = hx,
        y = hy,
        color = {1, 0.62, 0.32, 1},
        particleCount = 24,
        particleSpeed = 170,
        particleLife = 0.6,
        textOffset = 60,
        textScale = 1.22,
    })

    return restored
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
            local perStack = 0.25
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

    if effects.dash then
        Snake.dash = Snake.dash or {}
        local dash = Snake.dash
        local firstSetup = not dash.configured
        dash.duration = effects.dash.duration or dash.duration or 0
        dash.cooldown = effects.dash.cooldown or dash.cooldown or 0
        dash.speedMult = effects.dash.speedMult or dash.speedMult or 1
        dash.breaksRocks = effects.dash.breaksRocks ~= false
        dash.configured = true
        dash.timer = dash.timer or 0
        dash.cooldownTimer = dash.cooldownTimer or 0
        dash.active = dash.active or false
        if firstSetup then
            dash.active = false
            dash.timer = 0
            dash.cooldownTimer = 0
        else
            if dash.cooldown and dash.cooldown > 0 then
                dash.cooldownTimer = math.min(dash.cooldownTimer or 0, dash.cooldown)
            else
                dash.cooldownTimer = 0
            end
        end
    else
        Snake.dash = nil
    end

    if effects.timeSlow then
        Snake.timeDilation = Snake.timeDilation or {}
        local ability = Snake.timeDilation
        local firstSetup = not ability.configured
        ability.duration = effects.timeSlow.duration or ability.duration or 0
        ability.cooldown = effects.timeSlow.cooldown or ability.cooldown or 0
        ability.timeScale = effects.timeSlow.timeScale or ability.timeScale or 1
        ability.configured = true
        ability.timer = ability.timer or 0
        ability.cooldownTimer = ability.cooldownTimer or 0
        ability.active = ability.active or false
        if firstSetup then
            ability.active = false
            ability.timer = 0
            ability.cooldownTimer = 0
        else
            if ability.cooldown and ability.cooldown > 0 then
                ability.cooldownTimer = math.min(ability.cooldownTimer or 0, ability.cooldown)
            else
                ability.cooldownTimer = 0
            end
        end
    else
        Snake.timeDilation = nil
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

    local combinedUnlockTags = nil
    if type(upgrade.unlockTags) == "table" then
        combinedUnlockTags = {}
        for _, tag in ipairs(upgrade.unlockTags) do
            combinedUnlockTags[#combinedUnlockTags + 1] = tag
        end
    end
    if upgrade.unlockTag then
        combinedUnlockTags = combinedUnlockTags or {}
        combinedUnlockTags[#combinedUnlockTags + 1] = upgrade.unlockTag
    end

    if combinedUnlockTags and MetaProgression and MetaProgression.isTagUnlocked then
        for _, tag in ipairs(combinedUnlockTags) do
            if tag and not MetaProgression:isTagUnlocked(tag) then
                return false
            end
        end
    elseif upgrade.unlockTag and MetaProgression and MetaProgression.isTagUnlocked then
        if not MetaProgression:isTagUnlocked(upgrade.unlockTag) then
            return false
        end
    end

    if upgrade.condition and not upgrade.condition(self.runState, context) then
        return false
    end

    return true
end

local function decorateCard(upgrade)
    local rarityInfo = getRarityInfo(upgrade.rarity)
    local name = upgrade.name
    local description = upgrade.desc
    local rarityLabel = rarityInfo and rarityInfo.label

    if upgrade.nameKey then
        name = Localization:get(upgrade.nameKey)
    end
    if upgrade.descKey then
        description = Localization:get(upgrade.descKey)
    end
    if rarityInfo and rarityInfo.labelKey then
        rarityLabel = Localization:get(rarityInfo.labelKey)
    end

    return {
        id = upgrade.id,
        name = name,
        desc = description,
        rarity = upgrade.rarity,
        rarityColor = rarityInfo.color,
        rarityLabel = rarityLabel,
        restockShop = upgrade.restockShop,
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

    PlayerStats:add("totalUpgradesPurchased", 1)
    PlayerStats:updateMax("mostUpgradesInRun", #state.takenOrder)

    if upgrade.rarity == "legendary" then
        PlayerStats:add("legendaryUpgradesPurchased", 1)
    end

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
