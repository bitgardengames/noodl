local MetaProgression = {}

local saveFile = "metaprogression_state.lua"

local DEFAULT_DATA = {
    totalExperience = 0,
    level = 1,
    unlockHistory = {},
}

local XP_PER_FRUIT = 12
local SCORE_BONUS_DIVISOR = 600
local SCORE_BONUS_MAX = 250

local unlockDefinitions = {
    [2] = { name = "Concept Art Vault", description = "Placeholder: Sneak peeks at upcoming visuals." },
    [3] = { name = "Prototype Arena Skins", description = "Placeholder: Alternate palettes in development." },
    [4] = { name = "Experimental Relic Slot", description = "Placeholder: A future meta upgrade slot." },
    [5] = { name = "Soundscape Preview", description = "Placeholder: Bonus music and ambience." },
    [6] = { name = "Movement Variant", description = "Placeholder: New control modifiers." },
    [7] = { name = "Challenge Track", description = "Placeholder: Weekly challenge modifiers." },
    [8] = { name = "Friend Leaderboards", description = "Placeholder: Compete with pals in a future update." },
    [9] = { name = "Cosmetic Trails", description = "Placeholder: Stylish serpent trails." },
    [10] = { name = "???", description = "Placeholder: A mysterious meta reward." },
}

local milestoneThresholds = {
    500,
    1000,
    2000,
    3500,
    5000,
    7500,
    10000,
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
    local base = 120
    local linear = 40 * (level - 1)
    local curve = math.floor((level - 1) ^ 1.35 * 18)
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

    local fruitPoints = apples * XP_PER_FRUIT
    local scoreBonus = 0
    if SCORE_BONUS_DIVISOR > 0 then
        scoreBonus = math.min(SCORE_BONUS_MAX, math.floor(score / SCORE_BONUS_DIVISOR))
    end

    local total = fruitPoints + scoreBonus
    return {
        apples = apples,
        fruitPoints = fruitPoints,
        scoreBonus = scoreBonus,
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

    local gainedTotal = math.max(0, gain.total)
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
