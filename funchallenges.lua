local PlayerStats = require("playerstats")

local FunChallenges = {}

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

local function evaluateChallenge(challenge, context)
    if not challenge then
        return nil
    end

    context = context or {}

    local goal = resolveGoal(challenge, context)
    local current = resolveCurrent(challenge, context)
    local ratio = clampRatio(current, goal)

    local descriptionReplacements = resolveDescriptionReplacements(challenge, current, goal, context)
    local progressReplacements = resolveProgressReplacements(challenge, current, goal, context)

    return {
        id = challenge.id,
        index = challenge.index,
        titleKey = challenge.titleKey,
        descriptionKey = challenge.descriptionKey,
        descriptionReplacements = descriptionReplacements,
        progressKey = challenge.progressKey,
        progressReplacements = progressReplacements,
        completeKey = challenge.completeKey,
        goal = goal,
        current = current,
        ratio = ratio,
        completed = goal > 0 and current >= goal,
    }
end

FunChallenges.challenges = {
    {
        id = "combo_crunch",
        titleKey = "menu.fun_daily.combo.title",
        descriptionKey = "menu.fun_daily.combo.description",
        stat = "bestComboStreak",
        goal = 6,
        progressKey = "menu.fun_daily.combo.progress",
        completeKey = "menu.fun_daily.combo.complete",
        progressReplacements = function(self, current, goal)
            return {
                best = current or 0,
                goal = goal or 0,
            }
        end,
    },
    {
        id = "floor_explorer",
        titleKey = "menu.fun_daily.floors.title",
        descriptionKey = "menu.fun_daily.floors.description",
        stat = "floorsCleared",
        goal = 24,
    },
    {
        id = "fruit_sampler",
        titleKey = "menu.fun_daily.apples.title",
        descriptionKey = "menu.fun_daily.apples.description",
        stat = "totalApplesEaten",
        goal = 180,
        progressKey = "menu.fun_daily.apples.progress",
    },
    {
        id = "dragonfruit_delight",
        titleKey = "menu.fun_daily.dragonfruit.title",
        descriptionKey = "menu.fun_daily.dragonfruit.description",
        stat = "totalDragonfruitEaten",
        goal = 12,
        progressKey = "menu.fun_daily.dragonfruit.progress",
        completeKey = "menu.fun_daily.dragonfruit.complete",
    },
    {
        id = "combo_conductor",
        titleKey = "menu.fun_daily.combos.title",
        descriptionKey = "menu.fun_daily.combos.description",
        stat = "totalCombosTriggered",
        goal = 45,
        progressKey = "menu.fun_daily.combos.progress",
    },
    {
        id = "shield_specialist",
        titleKey = "menu.fun_daily.shields.title",
        descriptionKey = "menu.fun_daily.shields.description",
        stat = "crashShieldsSaved",
        goal = 20,
        progressKey = "menu.fun_daily.shields.progress",
        completeKey = "menu.fun_daily.shields.complete",
    },
    {
        id = "shopaholic",
        titleKey = "menu.fun_daily.shop.title",
        descriptionKey = "menu.fun_daily.shop.description",
        stat = "totalUpgradesPurchased",
        goal = 30,
        progressKey = "menu.fun_daily.shop.progress",
        completeKey = "menu.fun_daily.shop.complete",
    },
    {
        id = "legendary_collector",
        titleKey = "menu.fun_daily.legendary.title",
        descriptionKey = "menu.fun_daily.legendary.description",
        stat = "legendaryUpgradesPurchased",
        goal = 3,
        progressKey = "menu.fun_daily.legendary.progress",
        completeKey = "menu.fun_daily.legendary.complete",
    },
    {
        id = "serpentine_marathon",
        titleKey = "menu.fun_daily.marathon.title",
        descriptionKey = "menu.fun_daily.marathon.description",
        stat = "tilesTravelled",
        goal = 12000,
        progressKey = "menu.fun_daily.marathon.progress",
    },
    {
        id = "shield_wall_master",
        titleKey = "menu.fun_daily.shield_bounce.title",
        descriptionKey = "menu.fun_daily.shield_bounce.description",
        stat = "shieldWallBounces",
        goal = 18,
        progressKey = "menu.fun_daily.shield_bounce.progress",
        completeKey = "menu.fun_daily.shield_bounce.complete",
    },
    {
        id = "rock_breaker",
        titleKey = "menu.fun_daily.rock_breaker.title",
        descriptionKey = "menu.fun_daily.rock_breaker.description",
        stat = "shieldRockBreaks",
        goal = 15,
        progressKey = "menu.fun_daily.rock_breaker.progress",
        completeKey = "menu.fun_daily.rock_breaker.complete",
    },
    {
        id = "saw_parry_ace",
        titleKey = "menu.fun_daily.saw_parry.title",
        descriptionKey = "menu.fun_daily.saw_parry.description",
        stat = "shieldSawParries",
        goal = 8,
        progressKey = "menu.fun_daily.saw_parry.progress",
        completeKey = "menu.fun_daily.saw_parry.complete",
    },
    {
        id = "time_keeper",
        titleKey = "menu.fun_daily.time_keeper.title",
        descriptionKey = "menu.fun_daily.time_keeper.description",
        stat = "totalTimeAlive",
        goal = 5400,
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
    },
    {
        id = "streak_pusher",
        titleKey = "menu.fun_daily.streak_pusher.title",
        descriptionKey = "menu.fun_daily.streak_pusher.description",
        stat = "bestComboStreak",
        getGoal = function(self)
            local best = PlayerStats:get(self.stat) or 0
            return math.max(4, best + 2)
        end,
        progressKey = "menu.fun_daily.streak_pusher.progress",
        completeKey = "menu.fun_daily.streak_pusher.complete",
        descriptionReplacements = function(self, current, goal)
            return {
                current = current or 0,
                goal = goal or 0,
            }
        end,
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

    return evaluateChallenge(challenge, context)
end

function FunChallenges:getChallengeForIndex(index, context)
    local challenge = self.challenges[index]
    return evaluateChallenge(challenge, context)
end

function FunChallenges:getDailyChallenge(date, context)
    local count = #self.challenges
    local index = getChallengeIndex(self, count, date)
    if not index then
        return nil
    end

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

        local evaluated = self:getChallengeForIndex(currentIndex, context)
        if evaluated then
            results[#results + 1] = evaluated
        end
    end

    return results
end

return FunChallenges
