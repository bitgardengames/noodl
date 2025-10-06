local Snake = require("snake")
local Score = require("score")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")

local TalentTree = {}

local SAVE_FILE = "talenttree_state.lua"

local DEFAULT_STATE = {
    selections = {},
}

local tiers = {
    {
        id = "engine",
        name = "Tier I — Engine Tuning",
        description = "Choose how the snake's core pace trades against hazard cadence.",
        options = {
            {
                id = "phase_clutch",
                name = "Phase Clutch",
                description = "Let the coils slip just enough to keep the serpent moving briskly.",
                bonuses = { "Snake speed x1.10" },
                effects = {
                    snakeSpeedMultiplier = 1.10,
                },
                default = true,
            },
            {
                id = "flux_overdrive",
                name = "Flux Overdrive",
                description = "Push the throttle on arena emitters for quicker laser cycles.",
                bonuses = { "Laser cooldown x0.85" },
                effects = {
                    laserCooldownMultiplier = 0.85,
                },
            },
            {
                id = "cryo_stabilizers",
                name = "Cryo Stabilizers",
                description = "Dial back the feed to slow down fresh rock drops.",
                bonuses = { "Rock spawn x0.80" },
                effects = {
                    rockSpawnMultiplier = 0.80,
                },
            },
        },
    },
    {
        id = "protocols",
        name = "Tier II — Hazard Protocols",
        description = "Decide how you respond when arena threats spin up.",
        options = {
            {
                id = "harmonic_deflector",
                name = "Harmonic Deflector",
                description = "Retune the saw harmonics so blades glide more slowly.",
                bonuses = { "Saw speed x0.85" },
                effects = {
                    sawSpeedMultiplier = 0.85,
                },
                default = true,
            },
            {
                id = "pulse_scrambler",
                name = "Pulse Scrambler",
                description = "Harvest fruit to jam arena systems and earn breathing room.",
                bonuses = { "Fruit pickups stall saws for 2.0s" },
                effects = {
                    sawStallOnFruit = 2.0,
                },
            },
            {
                id = "danger_link",
                name = "Danger Link",
                description = "Link into hazard telemetry to receive a crash shield.",
                bonuses = { "+1 crash shield" },
                effects = {
                    startingCrashShields = 1,
                },
            },
        },
    },
    {
        id = "logistics",
        name = "Tier III — Supply Lines",
        description = "Shape how support flows between floors and hazards react.",
        options = {
            {
                id = "relay_crates",
                name = "Relay Crates",
                description = "Freight caches deliver richer produce for a bigger haul.",
                bonuses = { "Fruit bonus +0.5" },
                effects = {
                    fruitBonus = 0.5,
                },
                default = true,
            },
            {
                id = "smugglers_map",
                name = "Smuggler's Map",
                description = "Unlock an extra shop card for more purchase options.",
                bonuses = { "+1 shop choice" },
                effects = {
                    extraShopChoices = 1,
                },
            },
            {
                id = "salvage_network",
                name = "Salvage Network",
                description = "Convert hazard salvage into calmer saw patrols.",
                bonuses = { "Saw speed x0.90" },
                effects = {
                    sawSpeedMultiplier = 0.90,
                },
            },
        },
    },
    {
        id = "momentum",
        name = "Tier IV — Momentum Planning",
        description = "Define how your scoring engine trades with escalating hazards.",
        options = {
            {
                id = "momentum_battery",
                name = "Momentum Battery",
                description = "Bank surplus motion into a steady combo boost.",
                bonuses = { "Combo multiplier x1.20" },
                effects = {
                    comboMultiplier = 1.20,
                },
                default = true,
            },
            {
                id = "combo_reactor",
                name = "Combo Reactor",
                description = "Feed the reactor for explosive point output.",
                bonuses = { "Fruit bonus +0.6" },
                effects = {
                    fruitBonus = 0.6,
                },
            },
            {
                id = "hazard_ward",
                name = "Hazard Ward",
                description = "Slow the hazard pulse for longer breathing windows.",
                bonuses = { "Laser cooldown x1.35" },
                effects = {
                    laserCooldownMultiplier = 1.35,
                },
            },
        },
    },
}

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end

local function findTier(tierId)
    for _, tier in ipairs(tiers) do
        if tier.id == tierId then
            return tier
        end
    end
end

local function findOption(tier, optionId)
    if not (tier and tier.options) then
        return nil
    end

    for _, option in ipairs(tier.options) do
        if option.id == optionId then
            return option
        end
    end
end

local function ensureDefaults(state)
    state.selections = state.selections or {}

    for _, tier in ipairs(tiers) do
        local selection = state.selections[tier.id]
        if selection then
            local option = findOption(tier, selection)
            if option then
                goto continue
            end
        end

        local fallback
        for _, option in ipairs(tier.options) do
            if option.default then
                fallback = option.id
                break
            end
        end

        if not fallback and tier.options and tier.options[1] then
            fallback = tier.options[1].id
        end

        if fallback then
            state.selections[tier.id] = fallback
        end

        ::continue::
    end
end

function TalentTree:_ensureLoaded()
    if self._loaded then
        return
    end

    local data = copyTable(DEFAULT_STATE)

    if love.filesystem.getInfo(SAVE_FILE) then
        local ok, chunk = pcall(love.filesystem.load, SAVE_FILE)
        if ok and chunk then
            local success, saved = pcall(chunk)
            if success and type(saved) == "table" then
                if type(saved.selections) == "table" then
                    data.selections = copyTable(saved.selections)
                end
            end
        end
    end

    ensureDefaults(data)

    self.state = data
    self._loaded = true
end

local function serialize(value, indent)
    indent = indent or 0
    local valueType = type(value)

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "table" then
        local spacing = string.rep(" ", indent)
        local lines = { "{\n" }
        local nextIndent = indent + 4
        local entryIndent = string.rep(" ", nextIndent)
        for key, val in pairs(value) do
            local keyRepr = string.format("[%q]", tostring(key))
            table.insert(lines, string.format("%s%s = %s,\n", entryIndent, keyRepr, serialize(val, nextIndent)))
        end
        table.insert(lines, string.format("%s}", spacing))
        return table.concat(lines)
    end

    return "nil"
end

function TalentTree:_save()
    self:_ensureLoaded()
    local payload = {
        selections = copyTable(self.state.selections or {}),
    }
    local serialized = "return " .. serialize(payload, 0) .. "\n"
    love.filesystem.write(SAVE_FILE, serialized)
end

function TalentTree:getTiers()
    return tiers
end

function TalentTree:getSelections()
    self:_ensureLoaded()
    return copyTable(self.state.selections or {})
end

function TalentTree:getSelection(tierId)
    self:_ensureLoaded()
    return (self.state.selections or {})[tierId]
end

function TalentTree:setSelection(tierId, optionId)
    if not tierId or not optionId then
        return false
    end

    self:_ensureLoaded()

    local tier = findTier(tierId)
    if not tier then
        return false
    end

    local option = findOption(tier, optionId)
    if not option then
        return false
    end

    self.state.selections = self.state.selections or {}
    if self.state.selections[tierId] == optionId then
        return true
    end

    self.state.selections[tierId] = optionId
    ensureDefaults(self.state)
    self:_save()
    return true
end

local function createEffectAccumulator()
    return {
        maxHealthBonus = 0,
        fruitBonus = 0,
        snakeSpeedMultiplier = 1,
        comboMultiplier = 1,
        startingCrashShields = 0,
        extraGrowth = 0,
        rockSpawnMultiplier = 1,
        sawSpeedMultiplier = 1,
        laserCooldownMultiplier = 1,
        laserChargeMultiplier = 1,
        sawStallOnFruit = 0,
        extraShopChoices = 0,
    }
end

local function accumulateEffects(accumulator, effects)
    if type(effects) ~= "table" then
        return accumulator
    end

    if effects.maxHealthBonus then
        accumulator.maxHealthBonus = (accumulator.maxHealthBonus or 0) + effects.maxHealthBonus
    end

    if effects.fruitBonus then
        accumulator.fruitBonus = (accumulator.fruitBonus or 0) + effects.fruitBonus
    end

    if effects.snakeSpeedMultiplier then
        accumulator.snakeSpeedMultiplier = (accumulator.snakeSpeedMultiplier or 1) * effects.snakeSpeedMultiplier
    end

    if effects.comboMultiplier then
        accumulator.comboMultiplier = (accumulator.comboMultiplier or 1) * effects.comboMultiplier
    end

    if effects.startingCrashShields then
        accumulator.startingCrashShields = (accumulator.startingCrashShields or 0) + effects.startingCrashShields
    end

    if effects.extraGrowth then
        accumulator.extraGrowth = (accumulator.extraGrowth or 0) + effects.extraGrowth
    end

    if effects.rockSpawnMultiplier then
        accumulator.rockSpawnMultiplier = (accumulator.rockSpawnMultiplier or 1) * effects.rockSpawnMultiplier
    end

    if effects.sawSpeedMultiplier then
        accumulator.sawSpeedMultiplier = (accumulator.sawSpeedMultiplier or 1) * effects.sawSpeedMultiplier
    end

    if effects.laserCooldownMultiplier then
        accumulator.laserCooldownMultiplier = (accumulator.laserCooldownMultiplier or 1) * effects.laserCooldownMultiplier
    end

    if effects.laserChargeMultiplier then
        accumulator.laserChargeMultiplier = (accumulator.laserChargeMultiplier or 1) * effects.laserChargeMultiplier
    end

    if effects.sawStallOnFruit then
        accumulator.sawStallOnFruit = (accumulator.sawStallOnFruit or 0) + effects.sawStallOnFruit
    end

    if effects.extraShopChoices then
        accumulator.extraShopChoices = (accumulator.extraShopChoices or 0) + effects.extraShopChoices
    end

    return accumulator
end

function TalentTree:calculateEffects(selections)
    local accumulator = createEffectAccumulator()

    for _, tier in ipairs(tiers) do
        local chosen = selections and selections[tier.id]
        if chosen then
            local option = findOption(tier, chosen)
            if option then
                accumulateEffects(accumulator, option.effects)
            end
        end
    end

    return accumulator
end

function TalentTree:getAggregatedEffects()
    self:_ensureLoaded()
    return self:calculateEffects(self.state.selections)
end

local function clamp(value, minValue)
    if value == nil then
        return minValue
    end

    if value < minValue then
        return minValue
    end

    return value
end

local function approximatelyEqual(a, b, epsilon)
    epsilon = epsilon or 1e-3
    return math.abs((a or 0) - (b or 0)) <= epsilon
end

function TalentTree:applyRunModifiers(game, effects)
    effects = effects or self:getAggregatedEffects()

    if not effects then
        return nil
    end

    self._lastAppliedEffects = copyTable(effects)

    if game then
        game.talentEffects = copyTable(effects)
        game.health = game.maxHealth
        if game.healthSystem and game.healthSystem.setMax then
            game.healthSystem:setMax(game.maxHealth)
            if game.healthSystem.setCurrent then
                game.healthSystem:setCurrent(game.maxHealth)
            end
        end
    end

    if Snake and Snake.addSpeedMultiplier and not approximatelyEqual(effects.snakeSpeedMultiplier, 1) then
        if effects.snakeSpeedMultiplier > 0 then
            Snake:addSpeedMultiplier(effects.snakeSpeedMultiplier)
        end
    end

    if Snake and effects.startingCrashShields and effects.startingCrashShields ~= 0 and Snake.addCrashShields then
        Snake:addCrashShields(effects.startingCrashShields)
    end

    if Snake then
        local extraGrowth = effects.extraGrowth or 0
        if extraGrowth ~= 0 then
            Snake.extraGrowth = (Snake.extraGrowth or 0) + extraGrowth
        end
    end

    if Score then
        local fruitBonus = effects.fruitBonus or 0
        if fruitBonus ~= 0 and Score.addFruitBonus then
            Score:addFruitBonus(fruitBonus)
        end

        if Score.getComboBonusMultiplier and Score.setComboBonusMultiplier and not approximatelyEqual(effects.comboMultiplier, 1) then
            local current = Score:getComboBonusMultiplier() or 1
            Score:setComboBonusMultiplier(current * effects.comboMultiplier)
        end
    end

    return effects
end

function TalentTree:applyFloorContextModifiers(traitContext, effects)
    effects = effects or self._lastAppliedEffects or self:getAggregatedEffects()
    if not effects then
        return traitContext
    end

    traitContext = traitContext or {}

    if Rocks then
        local current = traitContext.rockSpawnChance
        if current == nil then
            current = Rocks.spawnChance or 0.25
        end

        if not approximatelyEqual(effects.rockSpawnMultiplier, 1) then
            local multiplier = effects.rockSpawnMultiplier or 1
            if multiplier < 0 then
                multiplier = 0
            end
            current = clamp((current or 0.25) * multiplier, 0)
        end

        traitContext.rockSpawnChance = current
        Rocks.spawnChance = current
    end

    if Saws then
        local currentSpeed = traitContext.sawSpeedMult
        if currentSpeed == nil then
            currentSpeed = Saws.speedMult or 1
        end

        if not approximatelyEqual(effects.sawSpeedMultiplier, 1) then
            currentSpeed = (currentSpeed or 1) * effects.sawSpeedMultiplier
        end

        traitContext.sawSpeedMult = currentSpeed
        Saws.speedMult = currentSpeed

        local stall = traitContext.sawStall
        if stall == nil then
            if Saws.getStallOnFruit then
                stall = Saws:getStallOnFruit()
            else
                stall = Saws.stallOnFruit or 0
            end
        end

        if effects.sawStallOnFruit and effects.sawStallOnFruit ~= 0 then
            stall = (stall or 0) + effects.sawStallOnFruit
        end

        traitContext.sawStall = stall
        if Saws.setStallOnFruit then
            Saws:setStallOnFruit(stall)
        else
            Saws.stallOnFruit = stall
        end
    end

    if Lasers then
        local cooldown = traitContext.laserCooldownMult
        if cooldown == nil then
            cooldown = Lasers.cooldownMult or 1
        end

        if not approximatelyEqual(effects.laserCooldownMultiplier, 1) then
            cooldown = (cooldown or 1) * effects.laserCooldownMultiplier
        end

        traitContext.laserCooldownMult = cooldown
        Lasers.cooldownMult = cooldown

        local charge = traitContext.laserChargeMult
        if charge == nil then
            charge = Lasers.chargeDurationMult or 1
        end

        if not approximatelyEqual(effects.laserChargeMultiplier, 1) then
            charge = (charge or 1) * effects.laserChargeMultiplier
        end

        traitContext.laserChargeMult = charge
        Lasers.chargeDurationMult = charge
    end

    return traitContext
end

return TalentTree
