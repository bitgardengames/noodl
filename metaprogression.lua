local MetaProgression = {}

local saveFile = "metaprogression_state.lua"

local DEFAULT_DATA = {
    totalExperience = 0,
    level = 1,
    unlockHistory = {},
}

--[[
    Meta progression tuning notes

    The previous tuning handed out experience very slowly which made the
    early unlocks feel grindy. Doubling the fruit award while also widening
    the score bonus band keeps skilled runs feeling rewarding, and the
    updated level curve makes sure the later levels still ask for commitment
    without becoming an endless slog.
]]

local XP_PER_FRUIT = 2
local SCORE_BONUS_DIVISOR = 450
local SCORE_BONUS_MAX = 400

local BASE_XP_PER_LEVEL = 130
local LINEAR_XP_PER_LEVEL = 42
local XP_CURVE_SCALE = 20
local XP_CURVE_EXPONENT = 1.32

local unlockDefinitions = {
    [2] = {
        id = "shop_expansion_1",
        name = "Shop Expansion I",
        description = "Adds a third upgrade card to every visit.",
        effects = {
            shopExtraChoices = 1,
        },
    },
    [3] = {
        id = "specialist_pool",
        name = "Specialist Contracts",
        description = "Unlocks rare defensive specialists in the upgrade pool.",
        unlockTags = { "specialist" },
    },
    [4] = {
        id = "dash_prototype",
        name = "Thunder Dash Prototype",
        description = "Unlocks dash ability upgrades in the shop.",
        unlockTags = { "abilities" },
    },
    [5] = {
        id = "temporal_study",
        name = "Temporal Study",
        description = "Unlocks time-bending upgrades that slow the arena.",
        unlockTags = { "timekeeper" },
    },
    [6] = {
        id = "event_horizon",
        name = "Event Horizon",
        description = "Unlocks experimental portal tech—legendary upgrades included.",
        unlockTags = { "legendary" },
    },
}

local milestoneThresholds = {
    650,
    1300,
    2400,
    3800,
    5200,
    7800,
    10500,
}

local function copyTable(tbl)
    local result = {}
    if type(tbl) ~= "table" then
        return result
    end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            result[k] = copyTable(v)
        else
            result[k] = v
        end
    end
    return result
end

function MetaProgression:_ensureLoaded()
    if self._loaded then
        return
    end

    self.data = copyTable(DEFAULT_DATA)

    if love.filesystem.getInfo(saveFile) then
        local success, chunk = pcall(love.filesystem.load, saveFile)
        if success and chunk then
            local ok, saved = pcall(chunk)
            if ok and type(saved) == "table" then
                for k, v in pairs(saved) do
                    if type(DEFAULT_DATA[k]) ~= "table" then
                        self.data[k] = v
                    elseif type(v) == "table" then
                        self.data[k] = copyTable(v)
                    end
                end
            end
        end
    end

    if type(self.data.totalExperience) ~= "number" or self.data.totalExperience < 0 then
        self.data.totalExperience = 0
    end
    if type(self.data.level) ~= "number" or self.data.level < 1 then
        self.data.level = 1
    end
    if type(self.data.unlockHistory) ~= "table" then
        self.data.unlockHistory = {}
    end

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
        for k, v in pairs(value) do
            local key = string.format("[%q]", tostring(k))
            table.insert(lines, string.format("%s%s = %s,\n", entryIndent, key, serialize(v, nextIndent)))
        end
        table.insert(lines, string.format("%s}", spacing))
        return table.concat(lines)
    end

    return "nil"
end

function MetaProgression:_save()
    self:_ensureLoaded()
    local toSave = {
        totalExperience = self.data.totalExperience,
        level = self.data.level,
        unlockHistory = self.data.unlockHistory,
    }
    local serialized = "return " .. serialize(toSave, 0) .. "\n"
    love.filesystem.write(saveFile, serialized)
end

function MetaProgression:getXpForLevel(level)
    level = math.max(1, math.floor(level or 1))
    local levelIndex = level - 1
    local base = BASE_XP_PER_LEVEL
    local linear = LINEAR_XP_PER_LEVEL * levelIndex
    local curve = math.floor((levelIndex ^ XP_CURVE_EXPONENT) * XP_CURVE_SCALE)
    return base + linear + curve
end

function MetaProgression:getProgressForTotal(totalXP)
    self:_ensureLoaded()
    local level = 1
    local xpForNext = self:getXpForLevel(level)
    local remaining = math.max(0, totalXP or 0)

    while remaining >= xpForNext do
        remaining = remaining - xpForNext
        level = level + 1
        xpForNext = self:getXpForLevel(level)
    end

    return level, remaining, xpForNext
end

function MetaProgression:getTotalXpForLevel(level)
    level = math.max(1, math.floor(level or 1))
    local total = 0
    for lvl = 1, level - 1 do
        total = total + self:getXpForLevel(lvl)
    end
    return total
end

local CORE_UNLOCK_TAG = "core"

local function accumulateEffects(target, source)
    if type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(value) == "number" then
            target[key] = (target[key] or 0) + value
        else
            target[key] = value
        end
    end
end

function MetaProgression:_collectUnlockedEffects()
    self:_ensureLoaded()

    local effects = {
        shopExtraChoices = 0,
        tags = { [CORE_UNLOCK_TAG] = true },
    }

    local currentLevel = self.data.level or 1
    for level, definition in pairs(unlockDefinitions) do
        if level <= currentLevel then
            if definition.effects then
                accumulateEffects(effects, definition.effects)
            end
            if definition.unlockTags then
                for _, tag in ipairs(definition.unlockTags) do
                    if tag then
                        effects.tags[tag] = true
                    end
                end
            end
        end
    end

    return effects
end

function MetaProgression:getShopBonusSlots()
    local effects = self:_collectUnlockedEffects()
    return math.floor(effects.shopExtraChoices or 0)
end

function MetaProgression:getUnlockedTags()
    local effects = self:_collectUnlockedEffects()
    return effects.tags or {}
end

function MetaProgression:isTagUnlocked(tag)
    if not tag or tag == CORE_UNLOCK_TAG then
        return true
    end

    local unlocked = self:getUnlockedTags()
    return unlocked[tag] == true
end

function MetaProgression:getUnlockTrack()
    self:_ensureLoaded()

    local currentTotal = math.max(0, self.data.totalExperience or 0)
    local currentLevel = math.max(1, self.data.level or 1)

    local track = {}
    for level, definition in pairs(unlockDefinitions) do
        local entry = {
            level = level,
            id = definition.id,
            name = definition.name,
            description = definition.description,
            unlockTags = definition.unlockTags,
            effects = definition.effects,
            unlocked = currentLevel >= level,
        }
        entry.totalXpRequired = self:getTotalXpForLevel(level)
        local remaining = entry.totalXpRequired - currentTotal
        entry.remainingXp = math.max(0, math.floor(remaining + 0.5))
        table.insert(track, entry)
    end

    table.sort(track, function(a, b)
        if a.level == b.level then
            return (a.id or "") < (b.id or "")
        end
        return a.level < b.level
    end)

    return track
end

function MetaProgression:getUnlockDefinitions()
    return copyTable(unlockDefinitions)
end

local function buildSnapshot(self, totalXP)
    local level, xpIntoLevel, xpForNext = self:getProgressForTotal(totalXP)
    return {
        total = math.floor(totalXP + 0.5),
        level = level,
        xpIntoLevel = xpIntoLevel,
        xpForNext = xpForNext,
    }
end

local function calculateRunGain(runStats)
    local apples = math.max(0, math.floor(runStats.apples or 0))
    local score = math.max(0, math.floor(runStats.score or 0))
    local bonusXP = math.max(0, math.floor(runStats.bonusXP or 0))

    local fruitPoints = apples * XP_PER_FRUIT
    local scoreBonus = 0
    if SCORE_BONUS_DIVISOR > 0 then
        scoreBonus = math.min(SCORE_BONUS_MAX, math.floor(score / SCORE_BONUS_DIVISOR))
    end

    local total = fruitPoints + bonusXP
    return {
        apples = apples,
        fruitPoints = fruitPoints,
        scoreBonus = scoreBonus,
        bonusXP = bonusXP,
        total = total,
    }
end

local function prepareUnlocks(levelUps)
    local unlocks = {}
    for _, level in ipairs(levelUps) do
        local info = unlockDefinitions[level]
        if info then
            unlocks[#unlocks + 1] = {
                level = level,
                name = info.name,
                description = info.description,
            }
        else
            unlocks[#unlocks + 1] = {
                level = level,
                name = string.format("Meta Reward %d", level),
                description = "Placeholder: Future reward details coming soon.",
            }
        end
    end
    return unlocks
end

local function prepareMilestones(startTotal, endTotal)
    local milestones = {}
    for _, threshold in ipairs(milestoneThresholds) do
        if startTotal < threshold and endTotal >= threshold then
            milestones[#milestones + 1] = {
                threshold = threshold,
            }
        end
    end
    return milestones
end

function MetaProgression:getState()
    self:_ensureLoaded()
    local snapshot = buildSnapshot(self, self.data.totalExperience)
    return {
        totalExperience = snapshot.total,
        level = snapshot.level,
        xpIntoLevel = snapshot.xpIntoLevel,
        xpForNext = snapshot.xpForNext,
    }
end

function MetaProgression:grantRunPoints(runStats)
    self:_ensureLoaded()
    runStats = runStats or {}

    local gain = calculateRunGain(runStats)
    local startTotal = self.data.totalExperience or 0
    local startSnapshot = buildSnapshot(self, startTotal)

    local gainedTotal = math.max(0, (gain.fruitPoints or 0) + (gain.bonusXP or 0))
    local endTotal = startTotal + gainedTotal
    local endSnapshot = buildSnapshot(self, endTotal)

    local levelUps = {}
    for level = startSnapshot.level + 1, endSnapshot.level do
        levelUps[#levelUps + 1] = level
        self.data.unlockHistory[level] = true
    end

    self.data.totalExperience = endTotal
    self.data.level = endSnapshot.level
    self:_save()

    local unlocks = prepareUnlocks(levelUps)
    local milestones = prepareMilestones(startTotal, endTotal)

    return {
        apples = gain.apples,
        gained = gainedTotal,
        breakdown = gain,
        start = startSnapshot,
        result = endSnapshot,
        levelUps = levelUps,
        unlocks = unlocks,
        milestones = milestones,
        eventsCount = #levelUps + #unlocks + #milestones,
    }
end

return MetaProgression
