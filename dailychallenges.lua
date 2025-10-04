local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")

local AchievementsModule

local function getAchievements()
    if AchievementsModule == nil then
        local ok, module = pcall(require, "achievements")
        if ok then
            AchievementsModule = module
        else
            print("[DailyChallenges] Failed to require achievements:", module)
            AchievementsModule = false
        end
    end

    if AchievementsModule then
        return AchievementsModule
    end

    return nil
end

local DailyChallenges = {}
DailyChallenges.defaultXpReward = 60

local defaultDateProvider = function()
    return os.date("*t")
end

local function defaultProgressReplacements(current, goal)
    return {
        current = current or 0,
        goal = goal or 0,
    }
end

local function mergeReplacements(base, extra)
    if not base then
        base = {}
    end

    if not extra then
        return base
    end

    for k, v in pairs(extra) do
        base[k] = v
    end

    return base
end

local function callChallengeFunction(challenge, key, ...)
    if not challenge then
        return nil
    end

    local fn = challenge[key]
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn, challenge, ...)
    if not ok then
        print(string.format("[DailyChallenges] Failed to call %s for '%s': %s", key, challenge.id or "<unknown>", result))
        return nil
    end

    return result
end

local function resolveGoal(challenge, context)
    local override = context and context.goalOverride
    if override ~= nil then
        return override
    end

    local value = callChallengeFunction(challenge, "getGoal", context)
    if value ~= nil then
        return value
    end

    return challenge.goal or 0
end

local function resolveCurrent(challenge, context)
    local override = context and context.currentOverride
    if override ~= nil then
        return override
    end

    local value = callChallengeFunction(challenge, "getValue", context)
    if value ~= nil then
        return value
    end

    if challenge.sessionStat then
        local statsSource = context and context.sessionStats
        if statsSource and type(statsSource.get) == "function" then
            return statsSource:get(challenge.sessionStat) or 0
        end

        if SessionStats and SessionStats.get then
            return SessionStats:get(challenge.sessionStat) or 0
        end
    end

    if challenge.stat then
        return PlayerStats:get(challenge.stat) or 0
    end

    return 0
end

local function resolveProgressReplacements(challenge, current, goal, context)
    local replacements = defaultProgressReplacements(current, goal)
    local extra = callChallengeFunction(challenge, "progressReplacements", current, goal, context)
    if extra then
        replacements = mergeReplacements(replacements, extra)
    end
    return replacements
end

local function resolveDescriptionReplacements(challenge, current, goal, context)
    local replacements = { goal = goal or 0, current = current or 0 }
    local extra = callChallengeFunction(challenge, "descriptionReplacements", current, goal, context)
    if extra then
        replacements = mergeReplacements(replacements, extra)
    end
    return replacements
end

local DEFAULT_PROGRESS_KEY = "menu.daily_panel_progress"
local DEFAULT_COMPLETE_KEY = "menu.daily_panel_complete"

local function buildStatusBar(challenge, completed, current, goal, ratio, replacements)
    if not goal or goal <= 0 then
        return nil
    end

    local textKey
    if completed then
        textKey = challenge.completeKey or DEFAULT_COMPLETE_KEY
    else
        textKey = challenge.progressKey or DEFAULT_PROGRESS_KEY
    end

    return {
        current = current or 0,
        goal = goal or 0,
        ratio = ratio or 0,
        textKey = textKey,
        replacements = replacements or defaultProgressReplacements(current, goal),
        completed = completed or false,
    }
end

local function clampRatio(current, goal)
    if goal and goal > 0 then
        return math.max(0, math.min(1, current / goal))
    end
    return 0
end

local function resolveDate(self, override)
    if type(override) == "table" then
        return override
    end

    local provider = self._dateProvider or defaultDateProvider
    return provider()
end

local function buildStorageKey(self, challenge, date, suffix)
    if not challenge or not challenge.id then
        return nil
    end

    date = resolveDate(self, date)
    if not date then
        return nil
    end

    local dayValue = (date.year or 0) * 512 + (date.yday or 0)
    return string.format("dailyChallenge:%s:%d:%s", challenge.id, dayValue, suffix)
end

local function getStoredProgress(self, challenge, date)
    local key = buildStorageKey(self, challenge, date, "progress")
    if not key then
        return 0
    end
    return PlayerStats:get(key) or 0
end

local function setStoredProgress(self, challenge, date, value)
    local key = buildStorageKey(self, challenge, date, "progress")
    if not key then
        return
    end

    value = math.max(0, math.floor(value or 0))
    PlayerStats:set(key, value)
end

local function isStoredComplete(self, challenge, date)
    local key = buildStorageKey(self, challenge, date, "complete")
    if not key then
        return false
    end

    local value = PlayerStats:get(key) or 0
    return value >= 1
end

local function setStoredComplete(self, challenge, date, complete)
    local key = buildStorageKey(self, challenge, date, "complete")
    if not key then
        return
    end

    PlayerStats:set(key, complete and 1 or 0)
end

local function getChallengeIndex(self, count, date)
    if count <= 0 then
        return nil
    end

    date = resolveDate(self, date)
    if not date then
        return 1
    end

    local value = (date.year or 0) * 512 + (date.yday or 0)
    local offset = self._dailyOffset or 0
    local adjusted = value + offset
    local index = ((adjusted % count) + count) % count + 1

    return index
end

local function evaluateChallenge(self, challenge, context)
    if not challenge then
        return nil
    end

    context = context or {}

    local goal = resolveGoal(challenge, context)
    local current = resolveCurrent(challenge, context)
    local date = context.date or context.dateOverride
    local storedProgress = getStoredProgress(self, challenge, date)
    if storedProgress and storedProgress > (current or 0) then
        current = storedProgress
    end

    local storedComplete = isStoredComplete(self, challenge, date)
    local ratio = clampRatio(current, goal)

    local descriptionReplacements = resolveDescriptionReplacements(challenge, current, goal, context)
    local progressReplacements = resolveProgressReplacements(challenge, current, goal, context)
    local completed = storedComplete or (goal > 0 and current >= goal)
    local statusBar = buildStatusBar(challenge, completed, current, goal, ratio, progressReplacements)

    return {
        id = challenge.id,
        index = challenge.index,
        titleKey = challenge.titleKey,
        descriptionKey = challenge.descriptionKey,
        descriptionReplacements = descriptionReplacements,
        goal = goal,
        current = current,
        ratio = ratio,
        completed = completed,
        xpReward = challenge.xpReward or DailyChallenges.defaultXpReward,
        statusBar = statusBar,
    }
end

DailyChallenges.challenges = {
    {
        id = "combo_crunch",
        titleKey = "menu.daily.combo.title",
        descriptionKey = "menu.daily.combo.description",
        sessionStat = "bestComboStreak",
        goal = 5,
        progressKey = "menu.daily.combo.progress",
        completeKey = "menu.daily.combo.complete",
        progressReplacements = function(self, current, goal)
            return {
                best = current or 0,
                goal = goal or 0,
            }
        end,
        xpReward = 70,
    },
    {
        id = "floor_explorer",
        titleKey = "menu.daily.floors.title",
        descriptionKey = "menu.daily.floors.description",
        sessionStat = "floorsCleared",
        goal = 5,
        xpReward = 80,
    },
    {
        id = "fruit_sampler",
        titleKey = "menu.daily.apples.title",
        descriptionKey = "menu.daily.apples.description",
        sessionStat = "applesEaten",
        goal = 45,
        progressKey = "menu.daily.apples.progress",
        xpReward = 70,
    },
    {
        id = "dragonfruit_delight",
        titleKey = "menu.daily.dragonfruit.title",
        descriptionKey = "menu.daily.dragonfruit.description",
        sessionStat = "dragonfruitEaten",
        goal = 1,
        progressKey = "menu.daily.dragonfruit.progress",
        completeKey = "menu.daily.dragonfruit.complete",
        xpReward = 90,
    },
    {
        id = "combo_conductor",
        titleKey = "menu.daily.combos.title",
        descriptionKey = "menu.daily.combos.description",
        sessionStat = "combosTriggered",
        goal = 8,
        progressKey = "menu.daily.combos.progress",
        xpReward = 60,
    },
    {
        id = "shield_specialist",
        titleKey = "menu.daily.shields.title",
        descriptionKey = "menu.daily.shields.description",
        sessionStat = "crashShieldsSaved",
        goal = 3,
        progressKey = "menu.daily.shields.progress",
        completeKey = "menu.daily.shields.complete",
        xpReward = 80,
    },
    {
        id = "shield_triad",
        titleKey = "menu.daily.shield_triad.title",
        descriptionKey = "menu.daily.shield_triad.description",
        goal = 3,
        progressKey = "menu.daily.shield_triad.progress",
        completeKey = "menu.daily.shield_triad.complete",
        getValue = function(self, context)
            local statsSource = context and context.sessionStats
            if statsSource and type(statsSource.get) == "function" then
                local wall = statsSource:get("runShieldWallBounces") or 0
                local rock = statsSource:get("runShieldRockBreaks") or 0
                local saw = statsSource:get("runShieldSawParries") or 0
                return (wall > 0 and 1 or 0) + (rock > 0 and 1 or 0) + (saw > 0 and 1 or 0)
            end

            local wall = SessionStats and SessionStats.get and SessionStats:get("runShieldWallBounces") or 0
            local rock = SessionStats and SessionStats.get and SessionStats:get("runShieldRockBreaks") or 0
            local saw = SessionStats and SessionStats.get and SessionStats:get("runShieldSawParries") or 0
            return (wall > 0 and 1 or 0) + (rock > 0 and 1 or 0) + (saw > 0 and 1 or 0)
        end,
        xpReward = 85,
    },
    {
        id = "serpentine_marathon",
        titleKey = "menu.daily.marathon.title",
        descriptionKey = "menu.daily.marathon.description",
        sessionStat = "tilesTravelled",
        goal = 3000,
        progressKey = "menu.daily.marathon.progress",
        xpReward = 70,
    },
    {
        id = "shield_wall_master",
        titleKey = "menu.daily.shield_bounce.title",
        descriptionKey = "menu.daily.shield_bounce.description",
        sessionStat = "runShieldWallBounces",
        goal = 5,
        progressKey = "menu.daily.shield_bounce.progress",
        completeKey = "menu.daily.shield_bounce.complete",
        xpReward = 80,
    },
    {
        id = "rock_breaker",
        titleKey = "menu.daily.rock_breaker.title",
        descriptionKey = "menu.daily.rock_breaker.description",
        sessionStat = "runShieldRockBreaks",
        goal = 4,
        progressKey = "menu.daily.rock_breaker.progress",
        completeKey = "menu.daily.rock_breaker.complete",
        xpReward = 80,
    },
    {
        id = "saw_parry_ace",
        titleKey = "menu.daily.saw_parry.title",
        descriptionKey = "menu.daily.saw_parry.description",
        sessionStat = "runShieldSawParries",
        goal = 2,
        progressKey = "menu.daily.saw_parry.progress",
        completeKey = "menu.daily.saw_parry.complete",
        xpReward = 90,
    },
    {
        id = "time_keeper",
        titleKey = "menu.daily.time_keeper.title",
        descriptionKey = "menu.daily.time_keeper.description",
        sessionStat = "timeAlive",
        goal = 600,
        progressKey = "menu.daily.time_keeper.progress",
        progressReplacements = function(self, current, goal)
            local function formatSeconds(seconds)
                seconds = math.max(0, math.floor(seconds or 0))
                local minutes = math.floor(seconds / 60)
                local secs = seconds % 60
                return string.format("%d:%02d", minutes, secs)
            end

            return {
                current = formatSeconds(current),
                goal = formatSeconds(goal),
            }
        end,
        descriptionReplacements = function(self, current, goal)
            return {
                goal = math.floor((goal or 0) / 60),
                current = math.floor((current or 0) / 60),
            }
        end,
        xpReward = 90,
    },
    {
        id = "floor_tourist",
        titleKey = "menu.daily.floor_tourist.title",
        descriptionKey = "menu.daily.floor_tourist.description",
        sessionStat = "totalFloorTime",
        goal = 480,
        progressKey = "menu.daily.floor_tourist.progress",
        progressReplacements = function(self, current, goal)
            local function formatSeconds(seconds)
                seconds = math.max(0, math.floor(seconds or 0))
                local minutes = math.floor(seconds / 60)
                local secs = seconds % 60
                return string.format("%d:%02d", minutes, secs)
            end

            return {
                current = formatSeconds(current),
                goal = formatSeconds(goal),
            }
        end,
        descriptionReplacements = function(self, current, goal)
            return {
                goal = math.floor((goal or 0) / 60),
            }
        end,
        xpReward = 85,
    },
    {
        id = "streak_pusher",
        titleKey = "menu.daily.streak_pusher.title",
        descriptionKey = "menu.daily.streak_pusher.description",
        sessionStat = "fruitWithoutTurning",
        goal = 8,
        progressKey = "menu.daily.streak_pusher.progress",
        completeKey = "menu.daily.streak_pusher.complete",
        xpReward = 70,
    },
    {
        id = "floor_conqueror",
        titleKey = "menu.daily.floor_conqueror.title",
        descriptionKey = "menu.daily.floor_conqueror.description",
        sessionStat = "floorsCleared",
        goal = 8,
        xpReward = 100,
    },
    {
        id = "depth_delver",
        titleKey = "menu.daily.depth_delver.title",
        descriptionKey = "menu.daily.depth_delver.description",
        sessionStat = "deepestFloorReached",
        goal = 10,
        progressKey = "menu.daily.depth_delver.progress",
        completeKey = "menu.daily.depth_delver.complete",
        progressReplacements = function(self, current, goal)
            return {
                current = math.max(1, math.floor(current or 1)),
                goal = goal or 0,
            }
        end,
        xpReward = 110,
    },
    {
        id = "apple_hoarder",
        titleKey = "menu.daily.apple_hoarder.title",
        descriptionKey = "menu.daily.apple_hoarder.description",
        sessionStat = "applesEaten",
        goal = 70,
        progressKey = "menu.daily.apple_hoarder.progress",
        xpReward = 90,
    },
    {
        id = "streak_perfectionist",
        titleKey = "menu.daily.streak_perfectionist.title",
        descriptionKey = "menu.daily.streak_perfectionist.description",
        sessionStat = "fruitWithoutTurning",
        goal = 12,
        progressKey = "menu.daily.streak_perfectionist.progress",
        completeKey = "menu.daily.streak_perfectionist.complete",
        xpReward = 90,
    },
}

function DailyChallenges:getChallengeForIndex(index, context)
    local challenge = self.challenges[index]
    if not challenge then
        return nil
    end

    challenge.index = index
    return evaluateChallenge(self, challenge, context)
end

function DailyChallenges:getDailyChallenge(date, context)
    local count = #self.challenges
    local index = getChallengeIndex(self, count, date)
    if not index then
        return nil
    end

    context = context or {}
    context.date = context.date or resolveDate(self, date)
    return self:getChallengeForIndex(index, context)
end

function DailyChallenges:applyRunResults(statsSource, options)
    statsSource = statsSource or SessionStats
    options = options or {}

    local date = options.date
    local count = #self.challenges
    if count == 0 then
        return nil
    end

    local index = getChallengeIndex(self, count, date)
    if not index then
        return nil
    end

    local challenge = self.challenges[index]
    if not challenge then
        return nil
    end

    local runValue = callChallengeFunction(challenge, "getRunValue", statsSource, options)

    if runValue == nil then
        if challenge.sessionStat and statsSource then
            if type(statsSource.get) == "function" then
                runValue = statsSource:get(challenge.sessionStat) or 0
            else
                runValue = statsSource[challenge.sessionStat] or 0
            end
        elseif challenge.stat then
            runValue = PlayerStats:get(challenge.stat) or 0
        end
    end

    runValue = math.max(0, math.floor(runValue or 0))

    local goal = resolveGoal(challenge)
    local storedProgress = getStoredProgress(self, challenge, date)
    local best = storedProgress
    if runValue > best then
        best = runValue
        setStoredProgress(self, challenge, date, best)
    end

    local alreadyCompleted = isStoredComplete(self, challenge, date)
    local xpAwarded = 0
    local completedNow = false

    if goal > 0 and runValue >= goal and not alreadyCompleted then
        setStoredComplete(self, challenge, date, true)
        xpAwarded = challenge.xpReward or self.defaultXpReward
        completedNow = true

        PlayerStats:add("dailyChallengesCompleted", 1)

        local achievements = getAchievements()
        if achievements and achievements.checkAll then
            local ok, err = pcall(function()
                achievements:checkAll()
            end)
            if not ok then
                print("[DailyChallenges] Failed to update achievements after daily challenge completion:", err)
            end
        end
    end

    return {
        challengeId = challenge.id,
        goal = goal,
        progress = best,
        completed = alreadyCompleted or completedNow,
        completedNow = completedNow,
        xpAwarded = xpAwarded,
    }
end

return DailyChallenges
