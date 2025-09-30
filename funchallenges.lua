local PlayerStats = require("playerstats")

local FunChallenges = {}

local function defaultProgressReplacements(current, goal)
    return {
        current = current or 0,
        goal = goal or 0,
    }
end

local function mergeReplacements(base, extra)
    if not extra then
        return base
    end

    for k, v in pairs(extra) do
        base[k] = v
    end

    return base
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
        progressReplacements = function(current, goal)
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
}

local function getChallengeIndex(count)
    if count <= 0 then
        return nil
    end

    local date = os.date("*t")
    if not date then
        return 1
    end

    local value = (date.year or 0) * 512 + (date.yday or 0)
    return (value % count) + 1
end

local function resolveProgressReplacements(challenge, current, goal)
    local replacements = defaultProgressReplacements(current, goal)
    if challenge.progressReplacements then
        replacements = mergeReplacements(replacements, challenge.progressReplacements(current, goal))
    end
    return replacements
end

local function resolveDescriptionReplacements(challenge, current, goal)
    local replacements = { goal = goal or 0 }
    if challenge.descriptionReplacements then
        replacements = mergeReplacements(replacements, challenge.descriptionReplacements(current, goal))
    end
    return replacements
end

local function resolveGoal(challenge)
    if challenge.getGoal then
        local value = challenge:getGoal()
        if value ~= nil then
            return value
        end
    end

    return challenge.goal or 0
end

function FunChallenges:getDailyChallenge()
    local count = #self.challenges
    local index = getChallengeIndex(count)
    if not index then
        return nil
    end

    local challenge = self.challenges[index]
    if not challenge then
        return nil
    end

    local current = 0
    if challenge.getValue then
        current = challenge:getValue() or 0
    elseif challenge.stat then
        current = PlayerStats:get(challenge.stat) or 0
    end

    local goal = resolveGoal(challenge)
    local ratio = 0
    if goal > 0 then
        ratio = math.min(1, current / goal)
    end

    local descriptionReplacements = resolveDescriptionReplacements(challenge, current, goal)
    local progressReplacements = resolveProgressReplacements(challenge, current, goal)

    return {
        id = challenge.id,
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

return FunChallenges
