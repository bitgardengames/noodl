local floor = math.floor
local max = math.max

local MetaProgression = {}

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
                unlockTags = {"specialist"},
        },
        [4] = {
                id = "dash_prototype",
                name = "Thunder Dash Prototype",
                description = "Unlocks dash ability upgrades in the shop.",
                unlockTags = {"abilities"},
        },
        [5] = {
                id = "temporal_study",
                name = "Temporal Study",
                description = "Unlocks time-bending upgrades that slow the arena.",
                unlockTags = {"timekeeper"},
        },
        [6] = {
                id = "event_horizon",
                name = "Event Horizon",
                description = "Unlocks experimental portal tech—legendary upgrades included.",
                unlockTags = {"legendary"},
        },
        [7] = {
                id = "combo_research",
                name = "Combo Research Initiative",
                description = "Unlocks advanced combo support upgrades in the shop.",
                unlockTags = {"combo_mastery"},
        },
        [9] = {
                id = "ion_storm_scales",
                name = "Ion Storm Scales",
                description = "Unlocks the Ion Storm snake skin for your handler profile.",
        },
        [10] = {
                id = "stormrunner_certification",
                name = "Stormrunner Certification",
                description = "Unlocks dash-synergy upgrades like Sparkstep Relay in the shop.",
                unlockTags = {"stormtech"},
        },
        [11] = {
                id = "precision_coils",
                name = "Precision Coil Prototypes",
                description = "Unlocks the deliberate coil speed regulator upgrade.",
                unlockTags = {"speedcraft"},
        },
        [12] = {
                id = "chrono_carapace_scales",
                name = "Chrono Carapace Scales",
                description = "Unlocks the Chrono Carapace snake skin and artisan supply contracts in the shop.",
                unlockTags = {"artisan_alliance"},
        },
        [13] = {
                id = "abyssal_protocols",
                name = "Abyssal Protocols",
                description = "Unlocks abyssal relic upgrades including the Abyssal Catalyst.",
                unlockTags = {"abyssal_protocols"},
        },
        [14] = {
                id = "midnight_circuit_scales",
                name = "Midnight Circuit Scales",
                description = "Unlocks the Midnight Circuit snake skin for your handler profile.",
        },
}

local sort = table.sort

local function getMaxUnlockLevel()
        local maxLevel = 1
        for level in pairs(unlockDefinitions) do
            if level > maxLevel then
                maxLevel = level
            end
        end
        return maxLevel
end

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

local function compareUnlockTrackEntries(a, b)
        if a.level == b.level then
                return (a.id or "") < (b.id or "")
        end
        return a.level < b.level
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

function MetaProgression:_ensureLoaded()
        if self._loaded then
                return
        end

        self.data = {
                totalExperience = 0,
                level = getMaxUnlockLevel(),
                unlockHistory = {},
        }
        self._loaded = true
end

function MetaProgression:getXpForLevel(_)
        return 0
end

function MetaProgression:getProgressForTotal(_)
        self:_ensureLoaded()
        return self.data.level or getMaxUnlockLevel(), 0, 0
end

function MetaProgression:getTotalXpForLevel(_)
        return 0
end

function MetaProgression:_collectUnlockedEffects()
        self:_ensureLoaded()

        local effects = {
                shopExtraChoices = 0,
                tags = {[CORE_UNLOCK_TAG] = true},
        }

        for _, definition in pairs(unlockDefinitions) do
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

        return effects
end

function MetaProgression:getShopBonusSlots()
        local effects = self:_collectUnlockedEffects()
        return floor(effects.shopExtraChoices or 0)
end

function MetaProgression:getUnlockedTags()
        local effects = self:_collectUnlockedEffects()
        return effects.tags or {}
end

function MetaProgression:isTagUnlocked(_)
        return true
end

function MetaProgression:getUnlockTrack()
        local track = {}
        for level, definition in pairs(unlockDefinitions) do
                track[#track + 1] = {
                        level = level,
                        id = definition.id,
                        name = definition.name,
                        description = definition.description,
                        unlockTags = definition.unlockTags,
                        effects = definition.effects,
                        unlocked = true,
                        totalXpRequired = 0,
                        remainingXp = 0,
                }
        end

        sort(track, compareUnlockTrackEntries)
        return track
end

local function buildSnapshot(self)
        local level = select(1, self:getProgressForTotal())
        return {
                total = 0,
                level = level,
                xpIntoLevel = 0,
                xpForNext = 0,
        }
end

local function calculateRunGain(runStats)
        local apples = max(0, floor((runStats and runStats.apples) or 0))
        return {
                apples = apples,
                fruitPoints = 0,
                scoreBonus = 0,
                bonusXP = 0,
                total = 0,
        }
end

function MetaProgression:getState()
        local snapshot = buildSnapshot(self)
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
        local snapshot = buildSnapshot(self)

        return {
                apples = gain.apples,
                gained = 0,
                breakdown = gain,
                start = copyTable(snapshot),
                result = copyTable(snapshot),
                levelUps = {},
                unlocks = {},
                milestones = {},
                eventsCount = 0,
        }
end

return MetaProgression
