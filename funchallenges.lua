local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")

local FunChallenges = {}
FunChallenges.defaultXpReward = 60

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

local function buildChallengeLookup(list)
    local lookup = {}

    for index, challenge in ipairs(list) do
        challenge.index = index
        if challenge.id and not lookup[challenge.id] then
            lookup[challenge.id] = challenge
        end
    end

    return lookup
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
        print(string.format("[FunChallenges] Failed to call %s for '%s': %s", key, challenge.id or "<unknown>", result))
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

local DEFAULT_PROGRESS_KEY = "menu.fun_panel_progress"
local DEFAULT_COMPLETE_KEY = "menu.fun_panel_complete"

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
    return string.format("funChallenge:%s:%d:%s", challenge.id, dayValue, suffix)
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
        xpReward = challenge.xpReward or FunChallenges.defaultXpReward,
        statusBar = statusBar,
    }
end

FunChallenges.challenges = {
    {
        id = "combo_crunch",
        titleKey = "menu.fun_daily.combo.title",
        descriptionKey = "menu.fun_daily.combo.description",
        sessionStat = "bestComboStreak",
        goal = 6,
        progressKey = "menu.fun_daily.combo.progress",
        completeKey = "menu.fun_daily.combo.complete",
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
        titleKey = "menu.fun_daily.floors.title",
        descriptionKey = "menu.fun_daily.floors.description",
        sessionStat = "floorsCleared",
        goal = 6,
        xpReward = 80,
    },
    {
        id = "fruit_sampler",
        titleKey = "menu.fun_daily.apples.title",
        descriptionKey = "menu.fun_daily.apples.description",
        sessionStat = "applesEaten",
        goal = 65,
        progressKey = "menu.fun_daily.apples.progress",
        xpReward = 70,
    },
    {
        id = "dragonfruit_delight",
        titleKey = "menu.fun_daily.dragonfruit.title",
        descriptionKey = "menu.fun_daily.dragonfruit.description",
        sessionStat = "dragonfruitEaten",
        goal = 2,
        progressKey = "menu.fun_daily.dragonfruit.progress",
        completeKey = "menu.fun_daily.dragonfruit.complete",
        xpReward = 90,
    },
    {
        id = "combo_conductor",
        titleKey = "menu.fun_daily.combos.title",
        descriptionKey = "menu.fun_daily.combos.description",
        sessionStat = "combosTriggered",
        goal = 12,
        progressKey = "menu.fun_daily.combos.progress",
        xpReward = 60,
    },
    {
        id = "shield_specialist",
        titleKey = "menu.fun_daily.shields.title",
        descriptionKey = "menu.fun_daily.shields.description",
        sessionStat = "crashShieldsSaved",
        goal = 4,
        progressKey = "menu.fun_daily.shields.progress",
        completeKey = "menu.fun_daily.shields.complete",
        xpReward = 80,
    },
    {
        id = "serpentine_marathon",
        titleKey = "menu.fun_daily.marathon.title",
        descriptionKey = "menu.fun_daily.marathon.description",
        sessionStat = "tilesTravelled",
        goal = 4500,
        progressKey = "menu.fun_daily.marathon.progress",
        xpReward = 70,
    },
    {
        id = "shield_wall_master",
        titleKey = "menu.fun_daily.shield_bounce.title",
        descriptionKey = "menu.fun_daily.shield_bounce.description",
        sessionStat = "runShieldWallBounces",
        goal = 8,
        progressKey = "menu.fun_daily.shield_bounce.progress",
        completeKey = "menu.fun_daily.shield_bounce.complete",
        xpReward = 80,
    },
    {
        id = "rock_breaker",
        titleKey = "menu.fun_daily.rock_breaker.title",
        descriptionKey = "menu.fun_daily.rock_breaker.description",
        sessionStat = "runShieldRockBreaks",
        goal = 5,
        progressKey = "menu.fun_daily.rock_breaker.progress",
        completeKey = "menu.fun_daily.rock_breaker.complete",
        xpReward = 80,
    },
    {
        id = "saw_parry_ace",
        titleKey = "menu.fun_daily.saw_parry.title",
        descriptionKey = "menu.fun_daily.saw_parry.description",
        sessionStat = "runShieldSawParries",
        goal = 3,
        progressKey = "menu.fun_daily.saw_parry.progress",
        completeKey = "menu.fun_daily.saw_parry.complete",
        xpReward = 90,
    },
    {
        id = "time_keeper",
        titleKey = "menu.fun_daily.time_keeper.title",
        descriptionKey = "menu.fun_daily.time_keeper.description",
        sessionStat = "timeAlive",
        goal = 900,
        progressKey = "menu.fun_daily.time_keeper.progress",
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
        id = "streak_pusher",
        titleKey = "menu.fun_daily.streak_pusher.title",
        descriptionKey = "menu.fun_daily.streak_pusher.description",
        sessionStat = "fruitWithoutTurning",
        goal = 10,
        progressKey = "menu.fun_daily.streak_pusher.progress",
        completeKey = "menu.fun_daily.streak_pusher.complete",
        xpReward = 70,
    },
    {
        id = "floor_conqueror",
        titleKey = "menu.fun_daily.floor_conqueror.title",
        descriptionKey = "menu.fun_daily.floor_conqueror.description",
        sessionStat = "floorsCleared",
        goal = 10,
        xpReward = 100,
    },
    {
        id = "apple_hoarder",
        titleKey = "menu.fun_daily.apple_hoarder.title",
        descriptionKey = "menu.fun_daily.apple_hoarder.description",
        sessionStat = "applesEaten",
        goal = 90,
        progressKey = "menu.fun_daily.apple_hoarder.progress",
        xpReward = 90,
    },
    {
        id = "streak_perfectionist",
        titleKey = "menu.fun_daily.streak_perfectionist.title",
        descriptionKey = "menu.fun_daily.streak_perfectionist.description",
        sessionStat = "fruitWithoutTurning",
        goal = 15,
        progressKey = "menu.fun_daily.streak_perfectionist.progress",
        completeKey = "menu.fun_daily.streak_perfectionist.complete",
        xpReward = 90,
    },
}

FunChallenges.lookup = buildChallengeLookup(FunChallenges.challenges)

function FunChallenges:setDateProvider(provider)
    if type(provider) == "function" then
        self._dateProvider = provider
    else
        self._dateProvider = nil
    end
end

function FunChallenges:setDailyOffset(offset)
    if type(offset) == "number" then
        self._dailyOffset = math.floor(offset)
    else
        self._dailyOffset = nil
    end
end

function FunChallenges:getChallengeIndex(date)
    return getChallengeIndex(self, #self.challenges, date)
end

function FunChallenges:getChallengeById(id, context)
    if not id then
        return nil
    end

    local challenge = self.lookup[id]
    if not challenge then
        return nil
    end

    return evaluateChallenge(self, challenge, context)
end

function FunChallenges:getChallengeForIndex(index, context)
    local challenge = self.challenges[index]
    return evaluateChallenge(self, challenge, context)
end

function FunChallenges:getDailyChallenge(date, context)
    local count = #self.challenges
    local index = getChallengeIndex(self, count, date)
    if not index then
        return nil
    end

    context = context or {}
    context.date = context.date or resolveDate(self, date)
    return self:getChallengeForIndex(index, context)
end

function FunChallenges:getUpcomingChallenges(amount, options)
    amount = math.max(0, math.floor(amount or 0))
    if amount == 0 or #self.challenges == 0 then
        return {}
    end

    local results = {}
    local date = options and options.date
    local sharedContext = options and options.context
    local contextBuilder = options and options.contextBuilder
    local index = getChallengeIndex(self, #self.challenges, date)
    if not index then
        return results
    end

    for i = 0, amount - 1 do
        local currentIndex = ((index + i - 1) % #self.challenges) + 1
        local context
        if contextBuilder then
            context = contextBuilder(currentIndex, self.challenges[currentIndex])
        else
            context = sharedContext
        end

        if context then
            context.date = context.date or resolveDate(self, date)
        end

        local evaluated = self:getChallengeForIndex(currentIndex, context)
        if evaluated then
            results[#results + 1] = evaluated
        end
    end

    return results
end

function FunChallenges:applyRunResults(statsSource, options)
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

return FunChallenges
