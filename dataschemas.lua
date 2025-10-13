local DataSchemas = {}

local function clone(value)
        if type(value) ~= "table" then
                return value
        end

        local copy = {}
        for key, entry in pairs(value) do
                copy[key] = clone(entry)
        end

        return copy
end

local function resolveDefault(entry)
        if type(entry) ~= "table" then
                return nil
        end

        local defaultValue = entry.default
        if defaultValue == nil then
                return nil
        end

        if type(defaultValue) == "function" then
                return defaultValue()
        end

        return clone(defaultValue)
end

function DataSchemas.applyDefaults(schema, target)
        if type(schema) ~= "table" or type(target) ~= "table" then
                return target
        end

        for key, entry in pairs(schema) do
                if target[key] == nil then
                        local defaultValue = resolveDefault(entry)
                        if defaultValue ~= nil then
                                target[key] = defaultValue
                        end
                end
        end

        return target
end

function DataSchemas.collectDefaults(schema)
        local defaults = {}
        if type(schema) ~= "table" then
                return defaults
        end

        for key, entry in pairs(schema) do
                local value = resolveDefault(entry)
                if value ~= nil then
                        defaults[key] = value
                end
        end

        return defaults
end

function DataSchemas.validate(schema, target, context)
        if type(schema) ~= "table" or type(target) ~= "table" then
                return true
        end

        context = context or "value"

        for key, entry in pairs(schema) do
                if type(entry) == "table" then
                        if entry.required and target[key] == nil then
                                error(string.format("%s missing required field '%s'", context, key))
                        end

                        if entry.type and target[key] ~= nil and type(target[key]) ~= entry.type then
                                error(string.format(
                                        "%s field '%s' expected %s, received %s",
                                        context,
                                        key,
                                        entry.type,
                                        type(target[key])
                                ))
                        end
                end
        end

        return true
end

DataSchemas.playerStats = {
        totalApplesEaten = {
                type = "number",
                default = 0,
                description = "Lifetime apples eaten across all runs.",
        },
        sessionsPlayed = {
                type = "number",
                default = 0,
                description = "Number of complete run attempts.",
        },
        totalDragonfruitEaten = {
                type = "number",
                default = 0,
                description = "Lifetime dragonfruit collected.",
        },
        snakeScore = {
                type = "number",
                description = "Highest score achieved in a single run.",
        },
        floorsCleared = {
                type = "number",
                default = 0,
                description = "Total floors cleared across all runs.",
        },
        deepestFloorReached = {
                type = "number",
                default = 0,
                description = "Deepest floor reached in any run.",
        },
        bestComboStreak = {
                type = "number",
                default = 0,
                description = "Highest combo streak recorded.",
        },
        dailyChallengesCompleted = {
                type = "number",
                default = 0,
                description = "Daily challenges completed.",
        },
        shieldWallBounces = {
                type = "number",
                default = 0,
                description = "Shield wall ricochets accumulated.",
        },
        shieldRockBreaks = {
                type = "number",
                default = 0,
                description = "Shield-assisted rock breaks.",
        },
        shieldSawParries = {
                type = "number",
                default = 0,
                description = "Shield parries against saws and similar hazards.",
        },
        totalUpgradesPurchased = {
                type = "number",
                default = 0,
                description = "Lifetime upgrades bought from the shop.",
        },
        mostUpgradesInRun = {
                type = "number",
                default = 0,
                description = "Highest number of upgrades acquired in a single run.",
        },
        legendaryUpgradesPurchased = {
                type = "number",
                default = 0,
                description = "Legendary upgrades purchased across all runs.",
        },
        dailyChallengeStreak = {
                type = "number",
                default = 0,
                description = "Current daily challenge completion streak.",
        },
        dailyChallengeBestStreak = {
                type = "number",
                default = 0,
                description = "Best daily challenge streak achieved.",
        },
        dailyChallengeLastCompletionDay = {
                type = "number",
                description = "Calendar day value of the most recent daily completion.",
        },
        mostApplesInRun = {
                type = "number",
                default = 0,
                description = "Most apples collected in a single run.",
        },
        totalTimeAlive = {
                type = "number",
                default = 0,
                description = "Total survival time across all runs (seconds).",
        },
        longestRunDuration = {
                type = "number",
                default = 0,
                description = "Longest run duration recorded (seconds).",
        },
        tilesTravelled = {
                type = "number",
                default = 0,
                description = "Lifetime tiles travelled.",
        },
        mostTilesTravelledInRun = {
                type = "number",
                default = 0,
                description = "Most tiles travelled in a single run.",
        },
        totalCombosTriggered = {
                type = "number",
                default = 0,
                description = "Total combos triggered across all runs.",
        },
        mostCombosInRun = {
                type = "number",
                default = 0,
                description = "Most combos triggered in a single run.",
        },
        crashShieldsSaved = {
                type = "number",
                default = 0,
                description = "Crash shields spent to prevent hits.",
        },
        mostShieldsSavedInRun = {
                type = "number",
                default = 0,
                description = "Most crash shields saved in a single run.",
        },
        bestFloorClearTime = {
                type = "number",
                description = "Fastest floor clear time (seconds).",
        },
        longestFloorClearTime = {
                type = "number",
                description = "Slowest floor clear time (seconds).",
        },
}

DataSchemas.upgradeDefinition = {
        id = {
                type = "string",
                required = true,
                description = "Unique identifier for the upgrade.",
        },
        nameKey = {
                type = "string",
                required = true,
                description = "Localization key for upgrade name.",
        },
        descKey = {
                type = "string",
                description = "Localization key for upgrade description.",
        },
        rarity = {
                type = "string",
                default = "common",
                description = "Rarity tier used for weighting and presentation.",
        },
        weight = {
                type = "number",
                default = 1,
                description = "Relative weight used for pool selection.",
        },
        tags = {
                type = "table",
                description = "Categorisation tags applied to the upgrade.",
        },
        handlers = {
                type = "table",
                description = "Event handlers attached to upgrade events.",
        },
        effects = {
                type = "table",
                description = "Stat modifications applied while upgrade is owned.",
        },
}

return DataSchemas
