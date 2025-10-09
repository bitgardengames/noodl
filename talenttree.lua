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
        name = "Tier I — Pace",
        description = "Pick how fast the arena ticks.",
        options = {
            {
                id = "phase_clutch",
                name = "Quick Coils",
                description = "Lean into raw velocity at the cost of a little stability.",
                bonuses = { "+12% snake speed" },
                penalties = { "+10% rock spawn" },
                effects = {
                    snakeSpeedMultiplier = 1.12,
                    rockSpawnMultiplier = 1.10,
                },
                default = true,
            },
            {
                id = "flux_overdrive",
                name = "Hot Lasers",
                description = "Push your beam output harder and more often.",
                bonuses = { "-18% laser cooldown" },
                penalties = { "-0.2 fruit per pickup" },
                effects = {
                    laserCooldownMultiplier = 0.82,
                    fruitBonus = -0.2,
                },
            },
            {
                id = "cryo_stabilizers",
                name = "Calm Rocks",
                description = "Tamp down hazard density to buy thinking room.",
                bonuses = { "20% fewer rocks" },
                penalties = { "-8% snake speed" },
                effects = {
                    rockSpawnMultiplier = 0.80,
                    snakeSpeedMultiplier = 0.92,
                },
            },
        },
    },
    {
        id = "protocols",
        name = "Tier II — Hazards",
        description = "Choose your safety net.",
        options = {
            {
                id = "harmonic_deflector",
                name = "Slow Saws",
                description = "Dial down the grinder to keep hazards predictable.",
                bonuses = { "-20% saw speed" },
                effects = {
                    sawSpeedMultiplier = 0.80,
                },
                default = true,
            },
            {
                id = "pulse_scrambler",
                name = "Fruit Stall",
                description = "Fruit pickups jam the machinery for a moment.",
                bonuses = { "Fruit pauses saws 2.5s" },
                effects = {
                    sawStallOnFruit = 2.5,
                },
            },
            {
                id = "lockstep_matrix",
                name = "Hazard Sync",
                description = "Even out arena noise while keeping pace steady.",
                bonuses = { "-10% saw speed", "-10% laser cooldown" },
                penalties = { "+10% rock spawn" },
                effects = {
                    sawSpeedMultiplier = 0.90,
                    laserCooldownMultiplier = 0.90,
                    rockSpawnMultiplier = 1.10,
                },
            },
        },
    },
    {
        id = "logistics",
        name = "Tier III — Support",
        description = "Boost your economy.",
        options = {
            {
                id = "relay_crates",
                name = "Fruit Bonus",
                description = "Steady income keeps momentum alive.",
                bonuses = { "+0.6 fruit per pickup" },
                effects = {
                    fruitBonus = 0.6,
                },
                default = true,
            },
            {
                id = "smugglers_map",
                name = "Shop Scout",
                description = "Peek another card to sculpt the perfect loadout.",
                bonuses = { "+1 shop card" },
                penalties = { "-0.2 fruit per pickup" },
                effects = {
                    extraShopChoices = 1,
                    fruitBonus = -0.2,
                },
            },
            {
                id = "salvage_network",
                name = "Saw Sink",
                description = "Channel spare scrap into hazard dampening.",
                bonuses = { "-15% saw speed" },
                penalties = { "-1 shop card" },
                effects = {
                    sawSpeedMultiplier = 0.85,
                    extraShopChoices = -1,
                },
            },
            {
                id = "gravity_broker",
                name = "Rock Market",
                description = "Buy peace by making rocks rarer, but growth slows.",
                bonuses = { "30% fewer rocks" },
                penalties = { "-1 growth" },
                effects = {
                    rockSpawnMultiplier = 0.70,
                    extraGrowth = -1,
                },
            },
        },
    },
    {
        id = "momentum",
        name = "Tier IV — Momentum",
        description = "Dial in scoring.",
        options = {
            {
                id = "momentum_battery",
                name = "Combo Boost",
                description = "Supercharge streak payouts while hazards stay brisk.",
                bonuses = { "+25% combo multiplier" },
                penalties = { "+10% saw speed" },
                effects = {
                    comboMultiplier = 1.25,
                    sawSpeedMultiplier = 1.10,
                },
                default = true,
            },
            {
                id = "combo_reactor",
                name = "Fruit Reactor",
                description = "Fruit yields surge, but so does arena pressure.",
                bonuses = { "+0.7 fruit per pickup" },
                penalties = { "+15% rock spawn" },
                effects = {
                    fruitBonus = 0.7,
                    rockSpawnMultiplier = 1.15,
                },
            },
            {
                id = "hazard_ward",
                name = "Laser Break",
                description = "Ease off the beam cadence to free up routing time.",
                bonuses = { "+40% laser cooldown" },
                penalties = { "-10% snake speed" },
                effects = {
                    laserCooldownMultiplier = 1.40,
                    snakeSpeedMultiplier = 0.90,
                },
            },
            {
                id = "charge_swap",
                name = "Charge Swap",
                description = "Trade beam downtime for faster charging bursts.",
                bonuses = { "-25% laser cooldown", "-20% laser charge" },
                penalties = { "-0.3 fruit per pickup" },
                effects = {
                    laserCooldownMultiplier = 0.75,
                    laserChargeMultiplier = 0.80,
                    fruitBonus = -0.3,
                },
            },
        },
    },
    {
        id = "safeguards",
        name = "Tier V — Safety",
        description = "Lock in survivability.",
        options = {
            {
                id = "reinforced_scales",
                name = "Thick Scales",
                description = "Stack plating to survive mistakes, even if it slows you down.",
                bonuses = { "+1 crash shield" },
                penalties = { "-6% snake speed" },
                effects = {
                    crashShieldBonus = 1,
                    snakeSpeedMultiplier = 0.94,
                },
                default = true,
            },
            {
                id = "phase_inductor",
                name = "Phase Dash",
                description = "Warp between lanes with a responsive beam cycle.",
                bonuses = { "+10% snake speed", "-20% laser charge" },
                penalties = { "-12% laser cooldown" },
                effects = {
                    snakeSpeedMultiplier = 1.10,
                    laserChargeMultiplier = 0.80,
                    laserCooldownMultiplier = 0.88,
                },
            },
            {
                id = "resupply_manifest",
                name = "Deep Stores",
                description = "Stockpile supplies but commit to a bulkier frame.",
                bonuses = { "+0.5 fruit per pickup", "+1 growth" },
                penalties = { "-1 shop card", "+8% saw speed" },
                effects = {
                    fruitBonus = 0.5,
                    extraGrowth = 1,
                    extraShopChoices = -1,
                    sawSpeedMultiplier = 1.08,
                },
            },
            {
                id = "last_resort",
                name = "Last Resort",
                description = "Burn the future for an extra life and faster markets right now.",
                bonuses = { "+1 crash shield", "+1 shop card" },
                penalties = { "-0.4 fruit per pickup" },
                effects = {
                    crashShieldBonus = 1,
                    extraShopChoices = 1,
                    fruitBonus = -0.4,
                },
            },
        },
    },
    {
        id = "tempo",
        name = "Tier VI — Tempo",
        description = "Bend the run's rhythm to your liking.",
        options = {
            {
                id = "reactive_pulse",
                name = "Reactive Pulse",
                description = "Reward patience with bigger harvests while beams rest longer.",
                bonuses = { "+0.5 fruit per pickup", "-10% saw speed" },
                penalties = { "+10% laser cooldown" },
                effects = {
                    fruitBonus = 0.5,
                    sawSpeedMultiplier = 0.90,
                    laserCooldownMultiplier = 1.10,
                },
                default = true,
            },
            {
                id = "blinkshift",
                name = "Blinkshift",
                description = "Aggressive routing trades calmer floors for raw pace.",
                bonuses = { "+15% snake speed", "+1 growth" },
                penalties = { "+15% rock spawn" },
                effects = {
                    snakeSpeedMultiplier = 1.15,
                    extraGrowth = 1,
                    rockSpawnMultiplier = 1.15,
                },
            },
            {
                id = "market_rush",
                name = "Market Rush",
                description = "Shops open wider while you ease off the throttle.",
                bonuses = { "+1 shop card", "+0.3 fruit per pickup" },
                penalties = { "-10% snake speed" },
                effects = {
                    extraShopChoices = 1,
                    fruitBonus = 0.3,
                    snakeSpeedMultiplier = 0.90,
                },
            },
        },
    },
    {
        id = "mastery",
        name = "Tier VII — Mastery",
        description = "Lock in your signature playstyle.",
        options = {
            {
                id = "stalwart_core",
                name = "Stalwart Core",
                description = "Tank through chaos with heavy plating and tighter combos.",
                bonuses = { "+1 crash shield", "-15% saw speed" },
                penalties = { "+10% laser cooldown" },
                effects = {
                    crashShieldBonus = 1,
                    sawSpeedMultiplier = 0.85,
                    laserCooldownMultiplier = 1.10,
                },
                default = true,
            },
            {
                id = "focus_array",
                name = "Focus Array",
                description = "Fire beams constantly and move like lightning, but fruits dry up.",
                bonuses = { "-25% laser cooldown", "+10% snake speed" },
                penalties = { "-0.4 fruit per pickup" },
                effects = {
                    laserCooldownMultiplier = 0.75,
                    snakeSpeedMultiplier = 1.10,
                    fruitBonus = -0.4,
                },
            },
            {
                id = "ration_cycle",
                name = "Ration Cycle",
                description = "Stretch every fruit and reroll, but streaks soften.",
                bonuses = { "+0.8 fruit per pickup", "+1 shop card" },
                penalties = { "-10% combo multiplier" },
                effects = {
                    fruitBonus = 0.8,
                    extraShopChoices = 1,
                    comboMultiplier = 0.90,
                },
            },
            {
                id = "hazard_bond",
                name = "Hazard Bond",
                description = "Invite danger for explosive scoring potential.",
                bonuses = { "+35% combo multiplier", "-15% laser charge" },
                penalties = { "+20% rock spawn", "+15% saw speed" },
                effects = {
                    comboMultiplier = 1.35,
                    laserChargeMultiplier = 0.85,
                    rockSpawnMultiplier = 1.20,
                    sawSpeedMultiplier = 1.15,
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

local function findDefaultOptionId(tier)
    if not tier or not tier.options then
        return nil
    end

    for _, option in ipairs(tier.options) do
        if option.default then
            return option.id
        end
    end

    if tier.options[1] then
        return tier.options[1].id
    end

    return nil
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

        local fallback = findDefaultOptionId(tier)

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
    self._lastAppliedEffects = nil
    self:_save()
    return true
end

function TalentTree:getTier(tierId)
    return findTier(tierId)
end

function TalentTree:getOption(tierId, optionId)
    local tier = findTier(tierId)
    return findOption(tier, optionId)
end

function TalentTree:getDefaultSelections()
    local defaults = {}

    for _, tier in ipairs(tiers) do
        local fallback = findDefaultOptionId(tier)
        if fallback then
            defaults[tier.id] = fallback
        end
    end

    return defaults
end

function TalentTree:isDefaultSelection(tierId, optionId)
    if not tierId or not optionId then
        return false
    end

    local tier = findTier(tierId)
    if not tier then
        return false
    end

    local defaultId = findDefaultOptionId(tier)
    return defaultId == optionId
end

function TalentTree:resetToDefaults()
    self:_ensureLoaded()

    local defaults = self:getDefaultSelections()
    self.state.selections = copyTable(defaults)
    ensureDefaults(self.state)
    self._lastAppliedEffects = nil
    self:_save()

    return copyTable(self.state.selections)
end

local function createEffectAccumulator()
    return {
        crashShieldBonus = 0,
        fruitBonus = 0,
        snakeSpeedMultiplier = 1,
        comboMultiplier = 1,
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

    if effects.crashShieldBonus then
        accumulator.crashShieldBonus = (accumulator.crashShieldBonus or 0) + effects.crashShieldBonus
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
    end

    local shieldBonus = effects.crashShieldBonus or 0
    if shieldBonus > 0 and Snake and Snake.addCrashShields then
        Snake:addCrashShields(shieldBonus)
    end

    if Snake and Snake.addSpeedMultiplier and not approximatelyEqual(effects.snakeSpeedMultiplier, 1) then
        if effects.snakeSpeedMultiplier > 0 then
            Snake:addSpeedMultiplier(effects.snakeSpeedMultiplier)
        end
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
