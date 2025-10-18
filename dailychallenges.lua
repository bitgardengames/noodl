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
DailyChallenges.defaultXpReward = 120

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

local function getStatValue(statsSource, key)
        if not key then
                return 0
        end

        if statsSource then
                if type(statsSource.get) == "function" then
                        local value = statsSource:get(key)
                        if value ~= nil then
                                return value
                        end
                end

                local value = statsSource[key]
                if value ~= nil then
                        return value
                end
        end

        if SessionStats and SessionStats.get then
                local value = SessionStats:get(key)
                if value ~= nil then
                        return value
                end
        end

        return 0
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
                id = "shield_showoff",
                titleKey = "menu.daily.shield_showoff.title",
                descriptionKey = "menu.daily.shield_showoff.description",
                goal = 6,
                progressKey = "menu.daily.shield_showoff.progress",
                completeKey = "menu.daily.shield_showoff.complete",
                getValue = function(self, context)
                        local rocks, saws = 0, 0
                        local statsSource = context and context.sessionStats
                        if statsSource and type(statsSource.get) == "function" then
                                rocks = statsSource:get("runShieldRockBreaks") or 0
                                saws = statsSource:get("runShieldSawParries") or 0
                        elseif SessionStats and SessionStats.get then
                                rocks = SessionStats:get("runShieldRockBreaks") or 0
                                saws = SessionStats:get("runShieldSawParries") or 0
                        end

                        return (rocks or 0) + (saws or 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local rocks, saws = 0, 0
                        local statsSource = context and context.sessionStats
                        if statsSource and type(statsSource.get) == "function" then
                                rocks = statsSource:get("runShieldRockBreaks") or 0
                                saws = statsSource:get("runShieldSawParries") or 0
                        elseif SessionStats and SessionStats.get then
                                rocks = SessionStats:get("runShieldRockBreaks") or 0
                                saws = SessionStats:get("runShieldSawParries") or 0
                        end

                        return {
                                current = current or 0,
                                goal = goal or 0,
                                rocks = rocks,
                                saws = saws,
                        }
                end,
                xpReward = 95,
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
                sessionStat = "shieldsSaved",
		goal = 3,
		progressKey = "menu.daily.shields.progress",
		completeKey = "menu.daily.shields.complete",
		xpReward = 80,
	},
        {
                id = "balanced_banquet",
                titleKey = "menu.daily.balanced_banquet.title",
                descriptionKey = "menu.daily.balanced_banquet.description",
                goal = 3,
                progressKey = "menu.daily.balanced_banquet.progress",
                completeKey = "menu.daily.balanced_banquet.complete",
                getValue = function(self, context)
                        local apples, combos = 0, 0
                        local statsSource = context and context.sessionStats
                        if statsSource and type(statsSource.get) == "function" then
                                apples = statsSource:get("applesEaten") or 0
                                combos = statsSource:get("combosTriggered") or 0
                        elseif SessionStats and SessionStats.get then
                                apples = SessionStats:get("applesEaten") or 0
                                combos = SessionStats:get("combosTriggered") or 0
                        end

                        apples = apples or 0
                        combos = combos or 0

                        local feasts = math.min(math.floor(apples / 15), combos)
                        return math.max(feasts, 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local apples, combos = 0, 0
                        local statsSource = context and context.sessionStats
                        if statsSource and type(statsSource.get) == "function" then
                                apples = statsSource:get("applesEaten") or 0
                                combos = statsSource:get("combosTriggered") or 0
                        elseif SessionStats and SessionStats.get then
                                apples = SessionStats:get("applesEaten") or 0
                                combos = SessionStats:get("combosTriggered") or 0
                        end

                        return {
                                current = current or 0,
                                goal = goal or 0,
                                apples = apples or 0,
                                combos = combos or 0,
                        }
                end,
                descriptionReplacements = function(self, current, goal)
                        return {
                                goal = goal or 0,
                                apples_per_combo = 15,
                        }
                end,
                xpReward = 110,
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
        {
                id = "dragonfruit_gourmand",
                titleKey = "menu.daily.dragonfruit_gourmand.title",
                descriptionKey = "menu.daily.dragonfruit_gourmand.description",
                sessionStat = "dragonfruitEaten",
                goal = 3,
                progressKey = "menu.daily.dragonfruit_gourmand.progress",
                completeKey = "menu.daily.dragonfruit_gourmand.complete",
                xpReward = 100,
        },
        {
                id = "shield_triathlon",
                titleKey = "menu.daily.shield_triathlon.title",
                descriptionKey = "menu.daily.shield_triathlon.description",
                goal = 3,
                progressKey = "menu.daily.shield_triathlon.progress",
                completeKey = "menu.daily.shield_triathlon.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local bounces = getStatValue(statsSource, "runShieldWallBounces")
                        local rocks = getStatValue(statsSource, "runShieldRockBreaks")
                        local saws = getStatValue(statsSource, "runShieldSawParries")

                        local completed = 0
                        if bounces > 0 then
                                completed = completed + 1
                        end
                        if rocks > 0 then
                                completed = completed + 1
                        end
                        if saws > 0 then
                                completed = completed + 1
                        end

                        return completed
                end,
                getRunValue = function(self, statsSource)
                        local bounces = getStatValue(statsSource, "runShieldWallBounces")
                        local rocks = getStatValue(statsSource, "runShieldRockBreaks")
                        local saws = getStatValue(statsSource, "runShieldSawParries")

                        local completed = 0
                        if bounces > 0 then
                                completed = completed + 1
                        end
                        if rocks > 0 then
                                completed = completed + 1
                        end
                        if saws > 0 then
                                completed = completed + 1
                        end

                        return completed
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                bounces = getStatValue(statsSource, "runShieldWallBounces"),
                                rocks = getStatValue(statsSource, "runShieldRockBreaks"),
                                saws = getStatValue(statsSource, "runShieldSawParries"),
                        }
                end,
                xpReward = 120,
        },
        {
                id = "floor_speedrunner",
                titleKey = "menu.daily.floor_speedrunner.title",
                descriptionKey = "menu.daily.floor_speedrunner.description",
                goal = 1,
                progressKey = "menu.daily.floor_speedrunner.progress",
                completeKey = "menu.daily.floor_speedrunner.complete",
                targetSeconds = 45,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        if fastest <= 0 then
                                return 0
                        end

                        return fastest <= (self.targetSeconds or 0) and 1 or 0
                end,
                getRunValue = function(self, statsSource)
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        if fastest <= 0 then
                                return 0
                        end

                        return fastest <= (self.targetSeconds or 0) and 1 or 0
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        local target = self.targetSeconds or 0

                        local function formatSeconds(seconds)
                                seconds = math.max(0, seconds or 0)
                                local minutes = math.floor(seconds / 60)
                                local secs = math.floor(seconds % 60)
                                return string.format("%d:%02d", minutes, secs)
                        end

                        return {
                                current = current or 0,
                                goal = goal or 0,
                                best = fastest > 0 and formatSeconds(fastest) or "--:--",
                                target = formatSeconds(target),
                        }
                end,
                descriptionReplacements = function(self)
                        return {
                                seconds = self.targetSeconds or 0,
                        }
                end,
                xpReward = 110,
        },
        {
                id = "pace_setter",
                titleKey = "menu.daily.pace_setter.title",
                descriptionKey = "menu.daily.pace_setter.description",
                goal = 240,
                progressKey = "menu.daily.pace_setter.progress",
                completeKey = "menu.daily.pace_setter.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if timeAlive <= 0 then
                                return 0
                        end

                        return math.floor((tiles / timeAlive) * 60)
                end,
                getRunValue = function(self, statsSource)
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if timeAlive <= 0 then
                                return 0
                        end

                        return math.floor((tiles / timeAlive) * 60)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        local minutes = timeAlive / 60
                        local pace = 0
                        if timeAlive > 0 then
                                pace = math.floor((tiles / timeAlive) * 60)
                        end

                        return {
                                current = pace,
                                goal = goal or 0,
                                pace = pace,
                                tiles = math.floor(tiles + 0.5),
                                minutes = string.format("%.1f", math.max(minutes, 0)),
                        }
                end,
                descriptionReplacements = function(self, current, goal)
                        return {
                                pace = goal or self.goal or 0,
                        }
                end,
                xpReward = 105,
        },
        {
                id = "combo_harvester",
                titleKey = "menu.daily.combo_harvester.title",
                descriptionKey = "menu.daily.combo_harvester.description",
                goal = 4,
                progressKey = "menu.daily.combo_harvester.progress",
                completeKey = "menu.daily.combo_harvester.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local apples = getStatValue(statsSource, "applesEaten")
                        local combos = getStatValue(statsSource, "combosTriggered")
                        local harvests = math.min(math.floor(apples / 8), combos)
                        return math.max(harvests, 0)
                end,
                getRunValue = function(self, statsSource)
                        local apples = getStatValue(statsSource, "applesEaten")
                        local combos = getStatValue(statsSource, "combosTriggered")
                        local harvests = math.min(math.floor(apples / 8), combos)
                        return math.max(harvests, 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local apples = getStatValue(statsSource, "applesEaten")
                        local combos = getStatValue(statsSource, "combosTriggered")
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                apples = apples,
                                combos = combos,
                                fruit_batch = 8,
                        }
                end,
                descriptionReplacements = function(self, current, goal)
                        return {
                                fruit_batch = 8,
                        }
                end,
                xpReward = 95,
        },
        {
                id = "guardian_angel",
                titleKey = "menu.daily.guardian_angel.title",
                descriptionKey = "menu.daily.guardian_angel.description",
                goal = 2,
                progressKey = "menu.daily.guardian_angel.progress",
                completeKey = "menu.daily.guardian_angel.complete",
                targetShields = 3,
                targetSeconds = 480,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local shields = getStatValue(statsSource, "shieldsSaved")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        local completed = 0
                        if shields >= (self.targetShields or 0) then
                                completed = completed + 1
                        end
                        if timeAlive >= (self.targetSeconds or 0) then
                                completed = completed + 1
                        end
                        return completed
                end,
                getRunValue = function(self, statsSource)
                        local shields = getStatValue(statsSource, "shieldsSaved")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        local completed = 0
                        if shields >= (self.targetShields or 0) then
                                completed = completed + 1
                        end
                        if timeAlive >= (self.targetSeconds or 0) then
                                completed = completed + 1
                        end
                        return completed
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local shields = getStatValue(statsSource, "shieldsSaved")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                shields = shields,
                                minutes = string.format("%.1f", math.max(timeAlive / 60, 0)),
                                target_shields = self.targetShields or 0,
                                target_minutes = string.format("%.1f", (self.targetSeconds or 0) / 60),
                        }
                end,
                descriptionReplacements = function(self)
                        return {
                                target_shields = self.targetShields or 0,
                                target_minutes = string.format("%.1f", (self.targetSeconds or 0) / 60),
                        }
                end,
                xpReward = 115,
        },
        {
                id = "fruit_rush",
                titleKey = "menu.daily.fruit_rush.title",
                descriptionKey = "menu.daily.fruit_rush.description",
                goal = 16,
                progressKey = "menu.daily.fruit_rush.progress",
                completeKey = "menu.daily.fruit_rush.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local apples = getStatValue(statsSource, "applesEaten")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if timeAlive <= 0 then
                                return 0
                        end

                        return math.floor((apples / timeAlive) * 60)
                end,
                getRunValue = function(self, statsSource)
                        local apples = getStatValue(statsSource, "applesEaten")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if timeAlive <= 0 then
                                return 0
                        end

                        return math.floor((apples / timeAlive) * 60)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local apples = getStatValue(statsSource, "applesEaten")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        local minutes = timeAlive / 60
                        local pace = 0
                        if timeAlive > 0 then
                                pace = math.floor((apples / timeAlive) * 60)
                        end

                        return {
                                current = pace,
                                goal = goal or 0,
                                pace = pace,
                                apples = apples,
                                minutes = string.format("%.1f", math.max(minutes, 0)),
                        }
                end,
                descriptionReplacements = function(self, current, goal)
                        return {
                                pace = goal or self.goal or 0,
                        }
                end,
                xpReward = 100,
        },
        {
                id = "achievement_hunter",
                titleKey = "menu.daily.achievement_hunter.title",
                descriptionKey = "menu.daily.achievement_hunter.description",
                goal = 1,
                progressKey = "menu.daily.achievement_hunter.progress",
                completeKey = "menu.daily.achievement_hunter.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local runAchievements = getStatValue(statsSource, "runAchievements")
                        if type(runAchievements) ~= "table" then
                                return 0
                        end

                        return #runAchievements
                end,
                getRunValue = function(self, statsSource)
                        local runAchievements = getStatValue(statsSource, "runAchievements")
                        if type(runAchievements) ~= "table" then
                                return 0
                        end

                        return #runAchievements
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local runAchievements = getStatValue(statsSource, "runAchievements")
                        local count = 0
                        if type(runAchievements) == "table" then
                                count = #runAchievements
                        end

                        return {
                                current = count,
                                goal = goal or 0,
                                unlocked = count,
                        }
                end,
                xpReward = 130,
        },
        {
                id = "consistency_champion",
                titleKey = "menu.daily.consistency_champion.title",
                descriptionKey = "menu.daily.consistency_champion.description",
                goal = 1,
                progressKey = "menu.daily.consistency_champion.progress",
                completeKey = "menu.daily.consistency_champion.complete",
                tolerance = 30,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        local slowest = getStatValue(statsSource, "slowestFloorClear")
                        if fastest <= 0 or slowest <= 0 then
                                return 0
                        end

                        return (slowest - fastest) <= (self.tolerance or 0) and 1 or 0
                end,
                getRunValue = function(self, statsSource)
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        local slowest = getStatValue(statsSource, "slowestFloorClear")
                        if fastest <= 0 or slowest <= 0 then
                                return 0
                        end

                        return (slowest - fastest) <= (self.tolerance or 0) and 1 or 0
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local fastest = getStatValue(statsSource, "fastestFloorClear")
                        local slowest = getStatValue(statsSource, "slowestFloorClear")
                        local differenceSeconds = 0
                        if fastest > 0 and slowest > 0 then
                                differenceSeconds = math.max(0, slowest - fastest)
                        end

                        local function formatSeconds(seconds)
                                seconds = math.max(0, seconds or 0)
                                local minutes = math.floor(seconds / 60)
                                local secs = math.floor(seconds % 60)
                                return string.format("%d:%02d", minutes, secs)
                        end

                        return {
                                current = current or 0,
                                goal = goal or 0,
                                fastest = fastest > 0 and formatSeconds(fastest) or "--:--",
                                slowest = slowest > 0 and formatSeconds(slowest) or "--:--",
                                difference = math.floor(differenceSeconds + 0.5),
                                tolerance = self.tolerance or 0,
                        }
                end,
                descriptionReplacements = function(self)
                        return {
                                tolerance = self.tolerance or 0,
                        }
                end,
                xpReward = 120,
        },
        {
                id = "depth_sprinter",
                titleKey = "menu.daily.depth_sprinter.title",
                descriptionKey = "menu.daily.depth_sprinter.description",
                goal = 1,
                progressKey = "menu.daily.depth_sprinter.progress",
                completeKey = "menu.daily.depth_sprinter.complete",
                targetFloor = 6,
                targetSeconds = 420,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if floors >= (self.targetFloor or 0) and timeAlive > 0 and timeAlive <= (self.targetSeconds or 0) then
                                return 1
                        end
                        return 0
                end,
                getRunValue = function(self, statsSource)
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeAlive = getStatValue(statsSource, "timeAlive")
                        if floors >= (self.targetFloor or 0) and timeAlive > 0 and timeAlive <= (self.targetSeconds or 0) then
                                return 1
                        end
                        return 0
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeAlive = getStatValue(statsSource, "timeAlive")

                        local function formatSeconds(seconds)
                                seconds = math.max(0, seconds or 0)
                                local minutes = math.floor(seconds / 60)
                                local secs = math.floor(seconds % 60)
                                return string.format("%d:%02d", minutes, secs)
                        end

                        return {
                                current = current or 0,
                                goal = goal or 0,
                                floors = floors,
                                time = formatSeconds(timeAlive),
                                target_floor = self.targetFloor or 0,
                                target_time = formatSeconds(self.targetSeconds or 0),
                        }
                end,
                descriptionReplacements = function(self)
                        local function formatSeconds(seconds)
                                seconds = math.max(0, seconds or 0)
                                local minutes = math.floor(seconds / 60)
                                local secs = math.floor(seconds % 60)
                                return string.format("%d:%02d", minutes, secs)
                        end

                        return {
                                target_floor = self.targetFloor or 0,
                                target_time = formatSeconds(self.targetSeconds or 0),
                        }
                end,
                xpReward = 130,
        },
        {
                id = "momentum_master",
                titleKey = "menu.daily.momentum_master.title",
                descriptionKey = "menu.daily.momentum_master.description",
                goal = 3,
                progressKey = "menu.daily.momentum_master.progress",
                completeKey = "menu.daily.momentum_master.complete",
                fruitChunk = 8,
                tileChunk = 1000,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local chain = getStatValue(statsSource, "fruitWithoutTurning")
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        local surges = math.min(math.floor(chain / (self.fruitChunk or 1)), math.floor(tiles / (self.tileChunk or 1)))
                        return math.max(surges, 0)
                end,
                getRunValue = function(self, statsSource)
                        local chain = getStatValue(statsSource, "fruitWithoutTurning")
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        local surges = math.min(math.floor(chain / (self.fruitChunk or 1)), math.floor(tiles / (self.tileChunk or 1)))
                        return math.max(surges, 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local chain = getStatValue(statsSource, "fruitWithoutTurning")
                        local tiles = getStatValue(statsSource, "tilesTravelled")
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                chain = chain,
                                tiles = tiles,
                                fruit_chunk = self.fruitChunk or 1,
                                tile_chunk = self.tileChunk or 1,
                        }
                end,
                descriptionReplacements = function(self)
                        return {
                                fruit_chunk = self.fruitChunk or 1,
                                tile_chunk = self.tileChunk or 1,
                        }
                end,
                xpReward = 110,
        },
        {
                id = "floor_cartographer",
                titleKey = "menu.daily.floor_cartographer.title",
                descriptionKey = "menu.daily.floor_cartographer.description",
                goal = 4,
                progressKey = "menu.daily.floor_cartographer.progress",
                completeKey = "menu.daily.floor_cartographer.complete",
                timeChunk = 180,
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeSpent = getStatValue(statsSource, "totalFloorTime")
                        local value = math.min(floors, math.floor(timeSpent / (self.timeChunk or 1)))
                        return math.max(value, 0)
                end,
                getRunValue = function(self, statsSource)
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeSpent = getStatValue(statsSource, "totalFloorTime")
                        local value = math.min(floors, math.floor(timeSpent / (self.timeChunk or 1)))
                        return math.max(value, 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local floors = getStatValue(statsSource, "floorsCleared")
                        local timeSpent = getStatValue(statsSource, "totalFloorTime")
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                floors = floors,
                                minutes = string.format("%.1f", math.max(timeSpent / 60, 0)),
                                minutes_chunk = string.format("%.1f", (self.timeChunk or 1) / 60),
                        }
                end,
                descriptionReplacements = function(self)
                        return {
                                minutes_chunk = string.format("%.1f", (self.timeChunk or 1) / 60),
                        }
                end,
                xpReward = 100,
        },
        {
                id = "safety_dance",
                titleKey = "menu.daily.safety_dance.title",
                descriptionKey = "menu.daily.safety_dance.description",
                goal = 3,
                progressKey = "menu.daily.safety_dance.progress",
                completeKey = "menu.daily.safety_dance.complete",
                getValue = function(self, context)
                        local statsSource = context and context.sessionStats
                        local bounces = getStatValue(statsSource, "runShieldWallBounces")
                        local saws = getStatValue(statsSource, "runShieldSawParries")
                        local pairs = math.min(math.floor(bounces / 2), math.floor(saws / 2))
                        return math.max(pairs, 0)
                end,
                getRunValue = function(self, statsSource)
                        local bounces = getStatValue(statsSource, "runShieldWallBounces")
                        local saws = getStatValue(statsSource, "runShieldSawParries")
                        local pairs = math.min(math.floor(bounces / 2), math.floor(saws / 2))
                        return math.max(pairs, 0)
                end,
                progressReplacements = function(self, current, goal, context)
                        local statsSource = context and context.sessionStats
                        local bounces = getStatValue(statsSource, "runShieldWallBounces")
                        local saws = getStatValue(statsSource, "runShieldSawParries")
                        return {
                                current = current or 0,
                                goal = goal or 0,
                                bounces = bounces,
                                saws = saws,
                        }
                end,
                xpReward = 110,
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

local function getDayValue(date)
	if not date then
		return nil
	end

	return (date.year or 0) * 512 + (date.yday or 0)
end

function DailyChallenges:applyRunResults(statsSource, options)
	statsSource = statsSource or SessionStats
	options = options or {}

	local date = options.date
	local resolvedDate = resolveDate(self, date)
	local count = #self.challenges
	if count == 0 then
		return nil
	end

	local index = getChallengeIndex(self, count, resolvedDate)
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
	local storedProgress = getStoredProgress(self, challenge, resolvedDate)
	local best = storedProgress
	if runValue > best then
		best = runValue
		setStoredProgress(self, challenge, resolvedDate, best)
	end

	local alreadyCompleted = isStoredComplete(self, challenge, resolvedDate)
	local xpAwarded = 0
	local completedNow = false
	local streakInfo = nil

	local previousStreak = PlayerStats:get("dailyChallengeStreak") or 0
	local previousBest = PlayerStats:get("dailyChallengeBestStreak") or 0
	local lastCompletionDay = PlayerStats:get("dailyChallengeLastCompletionDay") or 0
	local dayValue = getDayValue(resolvedDate)

	if goal > 0 and runValue >= goal and not alreadyCompleted then
		setStoredComplete(self, challenge, resolvedDate, true)
		xpAwarded = challenge.xpReward or self.defaultXpReward
		completedNow = true

		PlayerStats:add("dailyChallengesCompleted", 1)

		local newStreak = previousStreak
		if dayValue then
			if lastCompletionDay > 0 then
				if lastCompletionDay == dayValue then
					newStreak = math.max(previousStreak, 1)
				elseif lastCompletionDay == dayValue - 1 then
					newStreak = math.max(previousStreak, 0) + 1
				else
					newStreak = 1
				end
			else
				newStreak = 1
			end

			PlayerStats:set("dailyChallengeLastCompletionDay", dayValue)
		else
			newStreak = math.max(previousStreak, 1)
		end

		if newStreak <= 0 then
			newStreak = 1
		end

		PlayerStats:set("dailyChallengeStreak", newStreak)

		local bestStreak = previousBest
		if newStreak > bestStreak then
			bestStreak = newStreak
			PlayerStats:set("dailyChallengeBestStreak", bestStreak)
		end

		streakInfo = {
			current = newStreak,
			best = bestStreak,
			wasNewBest = newStreak > previousBest,
			continued = (lastCompletionDay > 0 and dayValue and (dayValue - lastCompletionDay) == 1) or false,
			dayValue = dayValue,
		}

		local achievements = getAchievements()
		if achievements and achievements.checkAll then
			local ok, err = pcall(function()
				achievements:checkAll()
			end)
			if not ok then
				print("[DailyChallenges] Failed to update achievements after daily challenge completion:", err)
			end
		end
	elseif alreadyCompleted then
		local currentStreak = math.max(previousStreak, 0)
		local bestStreak = math.max(previousBest, currentStreak)
		streakInfo = {
			current = currentStreak,
			best = bestStreak,
			alreadyCompleted = true,
			dayValue = dayValue,
		}
	elseif previousStreak > 0 then
		local currentStreak = math.max(previousStreak, 0)
		local bestStreak = math.max(previousBest, currentStreak)
		streakInfo = {
			current = currentStreak,
			best = bestStreak,
			needsCompletion = (dayValue ~= nil and lastCompletionDay ~= dayValue),
			dayValue = dayValue,
		}
	end

	return {
		challengeId = challenge.id,
		goal = goal,
		progress = best,
		completed = alreadyCompleted or completedNow,
		completedNow = completedNow,
		xpAwarded = xpAwarded,
		streakInfo = streakInfo,
	}
end

return DailyChallenges
