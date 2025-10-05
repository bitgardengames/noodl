local Snake = require("snake")
local Score = require("score")
local Rocks = require("rocks")

local TalentTree = {}

local SAVE_FILE = "talenttree_state.lua"

local DEFAULT_STATE = {
    selections = {},
}

local tiers = {
    {
        id = "foundation",
        name = "Tier I — Foundation",
        description = "Set your baseline defenses and scoring expectations.",
        options = {
            {
                id = "balanced_protocol",
                name = "Balanced Protocol",
                description = "Maintain the classic noodl experience with no modifiers.",
                bonuses = { "Run behaves exactly as classic" },
                penalties = {},
                effects = {},
                default = true,
            },
            {
                id = "adaptive_plating",
                name = "Adaptive Plating",
                description = "Lean into survivability by thickening your hull.",
                bonuses = { "+1 max health" },
                penalties = { "Fruit bonus -0.4" },
                effects = {
                    maxHealthBonus = 1,
                    fruitBonus = -0.4,
                },
            },
            {
                id = "glass_cannon",
                name = "Glass Cannon",
                description = "Strip armor for a higher scoring ceiling.",
                bonuses = { "+1.5 fruit bonus" },
                penalties = { "-1 max health" },
                effects = {
                    maxHealthBonus = -1,
                    fruitBonus = 1.5,
                },
            },
        },
    },
    {
        id = "mobility",
        name = "Tier II — Mobility",
        description = "Tune how aggressively your snake moves across the arena.",
        options = {
            {
                id = "baseline_flow",
                name = "Baseline Flow",
                description = "Keep your acceleration curve identical to classic noodl.",
                bonuses = { "No change to movement" },
                penalties = {},
                effects = {},
                default = true,
            },
            {
                id = "velocity_drive",
                name = "Velocity Drive",
                description = "Hit the throttle and weave between hazards.",
                bonuses = { "Snake speed x1.18" },
                penalties = { "Rock spawns x1.25" },
                effects = {
                    snakeSpeedMultiplier = 1.18,
                    rockSpawnMultiplier = 1.25,
                },
            },
            {
                id = "shield_dash",
                name = "Shield Dash",
                description = "Start with an extra shield and a slight pace boost.",
                bonuses = { "+1 crash shield", "Snake speed x1.05" },
                penalties = { "Fruit bonus -0.2" },
                effects = {
                    startingCrashShields = 1,
                    snakeSpeedMultiplier = 1.05,
                    fruitBonus = -0.2,
                },
            },
        },
    },
    {
        id = "control",
        name = "Tier III — Control",
        description = "Decide how you want hazards and combos to scale.",
        options = {
            {
                id = "stabilizers",
                name = "Field Stabilizers",
                description = "Preserve the baseline hazard cadence from classic runs.",
                bonuses = { "No change to hazard pacing" },
                penalties = {},
                effects = {},
                default = true,
            },
            {
                id = "hazard_training",
                name = "Hazard Training",
                description = "Invite more danger to learn faster reactions.",
                bonuses = { "+1 crash shield" },
                penalties = { "Rock spawns x1.35" },
                effects = {
                    startingCrashShields = 1,
                    rockSpawnMultiplier = 1.35,
                },
            },
            {
                id = "precision_combo",
                name = "Precision Combo",
                description = "Chase big combo bonuses by tightening execution.",
                bonuses = { "Combo multiplier x1.35" },
                penalties = { "Snake speed x0.96" },
                effects = {
                    comboMultiplier = 1.35,
                    snakeSpeedMultiplier = 0.96,
                },
            },
        },
    },
    {
        id = "harvest",
        name = "Tier IV — Harvest",
        description = "Shape long-term growth and resource flow.",
        options = {
            {
                id = "balanced_harvest",
                name = "Balanced Harvest",
                description = "Maintain the familiar balance between growth and scoring.",
                bonuses = { "No change to fruit rewards" },
                penalties = {},
                effects = {},
                default = true,
            },
            {
                id = "lean_frame",
                name = "Lean Frame",
                description = "Stay trim for sharper dodges at the cost of points.",
                bonuses = { "Extra growth -1" },
                penalties = { "Fruit bonus -0.3" },
                effects = {
                    extraGrowth = -1,
                    fruitBonus = -0.3,
                },
            },
            {
                id = "score_pipeline",
                name = "Score Pipeline",
                description = "Sacrifice resilience for explosive scoring runs.",
                bonuses = { "Combo multiplier x1.45", "Fruit bonus +0.6" },
                penalties = { "-1 max health" },
                effects = {
                    comboMultiplier = 1.45,
                    fruitBonus = 0.6,
                    maxHealthBonus = -1,
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

    if Rocks and effects.rockSpawnMultiplier and not approximatelyEqual(effects.rockSpawnMultiplier, 1) then
        local multiplier = effects.rockSpawnMultiplier
        if multiplier < 0 then
            multiplier = 0
        end
        Rocks.spawnChance = clamp((Rocks.spawnChance or 0.25) * multiplier, 0)
    end

    return effects
end

return TalentTree
