local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")

local floor = math.floor
local max = math.max
local min = math.min

local function formatSeconds(seconds, floorFirst)
	seconds = seconds or 0
	if floorFirst then
		seconds = floor(seconds)
	end

	seconds = max(0, seconds)

	local minutes = floor(seconds / 60)
	local secs = floor(seconds % 60)

	return string.format("%d:%02d", minutes, secs)
end

local function formatSecondsFloor(seconds)
	return formatSeconds(seconds, true)
end

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

local NO_VALUE = {}

local function getStatValue(statsSource, key, context)
	if not key then
		return 0
	end

	local cache = context and context.statCache

	local function getCacheKey(source)
		if source == nil then
			return "__nil"
		end

		return source
	end

	local function fetch(source)
		if not source then
			return nil
		end

		local cacheKey = getCacheKey(source)
		local sourceCache = cache and cache[cacheKey]
		if sourceCache and sourceCache[key] ~= nil then
			local cached = sourceCache[key]
			if cached == NO_VALUE then
				return nil
			end
			return cached
		end

		local value
		if type(source.get) == "function" then
			value = source:get(key)
		end

		if value == nil then
			value = source[key]
		end

		if cache then
			sourceCache = sourceCache or {}
			cache[cacheKey] = sourceCache
			sourceCache[key] = value ~= nil and value or NO_VALUE
		end

		return value
	end

	if statsSource then
		local value = fetch(statsSource)
		if value ~= nil then
			return value
		end
	end

	if SessionStats and SessionStats.get then
		local value = fetch(SessionStats)
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
		return getStatValue(statsSource, challenge.sessionStat, context)
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
	local replacements = {goal = goal or 0, current = current or 0}
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
		return max(0, min(1, current / goal))
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


local function secondsUntilNextMidnight(date)
	if not date then
		return nil
	end

	if not date.year or not date.month or not date.day then
		return nil
	end

	if type(date.hour) ~= "number" or type(date.min) ~= "number" or type(date.sec) ~= "number" then
		return nil
	end

	local secondsPerDay = 24 * 60 * 60
	local elapsed = date.hour * 60 * 60 + date.min * 60 + date.sec

	if type(elapsed) ~= "number" then
		return nil
	end

	if elapsed < 0 then
		return nil
	end

	-- clamp elapsed into the range of a single day in case of slightly
	-- out-of-range values (e.g. floating point rounding or hour == 24)
	elapsed = elapsed % secondsPerDay

	local remaining = secondsPerDay - elapsed
	if remaining <= 0 then
		remaining = remaining + secondsPerDay
	end

	return remaining
end

local function getDayValue(date)
	if not date then
		return nil
	end

	return (date.year or 0) * 512 + (date.yday or 0)
end

local function buildDailyStoragePrefix(self, challenge, date)
	if not challenge or not challenge.id then
		return nil
	end

	date = resolveDate(self, date)
	if not date then
		return nil
	end

	local dayValue = getDayValue(date)
	if not dayValue then
		return nil
	end

	self._dailyStoragePrefixCache = self._dailyStoragePrefixCache or {}
	local cache = self._dailyStoragePrefixCache[challenge.id]
	if not cache or cache.day ~= dayValue then
		cache = {
			day = dayValue,
			prefix = string.format("dailyChallenge:%s:%d:", challenge.id, dayValue),
		}
		self._dailyStoragePrefixCache[challenge.id] = cache
	end

	return cache.prefix
end

local function getStoredProgress(self, challenge, date, prefix)
	prefix = prefix or buildDailyStoragePrefix(self, challenge, date)
	if not prefix then
		return 0
	end

	return PlayerStats:get(prefix .. "progress") or 0
end

local function setStoredProgress(self, challenge, date, value, prefix)
	prefix = prefix or buildDailyStoragePrefix(self, challenge, date)
	if not prefix then
		return
	end

	value = max(0, floor(value or 0))
	PlayerStats:set(prefix .. "progress", value)
end

local function isStoredComplete(self, challenge, date, prefix)
	prefix = prefix or buildDailyStoragePrefix(self, challenge, date)
	if not prefix then
		return false
	end

	local value = PlayerStats:get(prefix .. "complete") or 0
	return value >= 1
end

local function setStoredComplete(self, challenge, date, complete, prefix)
	prefix = prefix or buildDailyStoragePrefix(self, challenge, date)
	if not prefix then
		return
	end

	PlayerStats:set(prefix .. "complete", complete and 1 or 0)
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
	if context.statCache then
		for key in pairs(context.statCache) do
			context.statCache[key] = nil
		end
	else
		context.statCache = {}
	end

	local goal = resolveGoal(challenge, context)
	local current = resolveCurrent(challenge, context)
	local date = context.date or context.dateOverride
	local prefix = buildDailyStoragePrefix(self, challenge, date)
	local storedProgress = getStoredProgress(self, challenge, date, prefix)
	if storedProgress and storedProgress > (current or 0) then
		current = storedProgress
	end

	local storedComplete = isStoredComplete(self, challenge, date, prefix)
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
		id = "shield_showoff",
		titleKey = "menu.daily.shield_showoff.title",
		descriptionKey = "menu.daily.shield_showoff.description",
		goal = 6,
		progressKey = "menu.daily.shield_showoff.progress",
		completeKey = "menu.daily.shield_showoff.complete",
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local rocks = getStatValue(statsSource, "runShieldRockBreaks", context)
			local saws = getStatValue(statsSource, "runShieldSawParries", context)

			return (rocks or 0) + (saws or 0)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			return {
				current = current or 0,
				goal = goal or 0,
				rocks = getStatValue(statsSource, "runShieldRockBreaks", context),
				saws = getStatValue(statsSource, "runShieldSawParries", context),
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
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local combos = getStatValue(statsSource, "combosTriggered", context)

			local feasts = min(floor(apples / 15), combos)
			return max(feasts, 0)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			return {
				current = current or 0,
				goal = goal or 0,
				apples = getStatValue(statsSource, "applesEaten", context),
				combos = getStatValue(statsSource, "combosTriggered", context),
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
			return {
				current = formatSecondsFloor(current),
				goal = formatSecondsFloor(goal),
			}
		end,
		descriptionReplacements = function(self, current, goal)
			return {
				goal = floor((goal or 0) / 60),
				current = floor((current or 0) / 60),
			}
		end,
		xpReward = 90,
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
				current = max(1, floor(current or 1)),
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
		id = "shield_triathlon",
		titleKey = "menu.daily.shield_triathlon.title",
		descriptionKey = "menu.daily.shield_triathlon.description",
		goal = 3,
		progressKey = "menu.daily.shield_triathlon.progress",
		completeKey = "menu.daily.shield_triathlon.complete",
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local bounces = getStatValue(statsSource, "runShieldWallBounces", context)
			local rocks = getStatValue(statsSource, "runShieldRockBreaks", context)
			local saws = getStatValue(statsSource, "runShieldSawParries", context)

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
				bounces = getStatValue(statsSource, "runShieldWallBounces", context),
				rocks = getStatValue(statsSource, "runShieldRockBreaks", context),
				saws = getStatValue(statsSource, "runShieldSawParries", context),
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
			local fastest = getStatValue(statsSource, "fastestFloorClear", context)
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
			local fastest = getStatValue(statsSource, "fastestFloorClear", context)
			local target = self.targetSeconds or 0

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
		id = "combo_harvester",
		titleKey = "menu.daily.combo_harvester.title",
		descriptionKey = "menu.daily.combo_harvester.description",
		goal = 4,
		progressKey = "menu.daily.combo_harvester.progress",
		completeKey = "menu.daily.combo_harvester.complete",
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local combos = getStatValue(statsSource, "combosTriggered", context)
			local harvests = min(floor(apples / 8), combos)
			return max(harvests, 0)
		end,
		getRunValue = function(self, statsSource)
			local apples = getStatValue(statsSource, "applesEaten")
			local combos = getStatValue(statsSource, "combosTriggered")
			local harvests = min(floor(apples / 8), combos)
			return max(harvests, 0)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local combos = getStatValue(statsSource, "combosTriggered", context)
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
		id = "shielded_marathon",
		titleKey = "menu.daily.shielded_marathon.title",
		descriptionKey = "menu.daily.shielded_marathon.description",
		goal = 2,
		progressKey = "menu.daily.shielded_marathon.progress",
		completeKey = "menu.daily.shielded_marathon.complete",
		targetShields = 2,
		targetTiles = 320,
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local shields = getStatValue(statsSource, "shieldsSaved", context)
			local tiles = getStatValue(statsSource, "tilesTravelled", context)
			local completed = 0
			if shields >= (self.targetShields or 0) then
				completed = completed + 1
			end
			if tiles >= (self.targetTiles or 0) then
				completed = completed + 1
			end
			return completed
		end,
		getRunValue = function(self, statsSource)
			local shields = getStatValue(statsSource, "shieldsSaved")
			local tiles = getStatValue(statsSource, "tilesTravelled")
			local completed = 0
			if shields >= (self.targetShields or 0) then
				completed = completed + 1
			end
			if tiles >= (self.targetTiles or 0) then
				completed = completed + 1
			end
			return completed
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local shields = getStatValue(statsSource, "shieldsSaved", context)
			local tiles = getStatValue(statsSource, "tilesTravelled", context)
			return {
				current = current or 0,
				goal = goal or 0,
				shields = shields,
				tiles = tiles,
				target_shields = self.targetShields or 0,
				target_tiles = self.targetTiles or 0,
			}
		end,
		descriptionReplacements = function(self)
			return {
				target_shields = self.targetShields or 0,
				target_tiles = self.targetTiles or 0,
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
			local apples = getStatValue(statsSource, "applesEaten", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)
			if timeAlive <= 0 then
				return 0
			end

			return floor((apples / timeAlive) * 60)
		end,
		getRunValue = function(self, statsSource)
			local apples = getStatValue(statsSource, "applesEaten")
			local timeAlive = getStatValue(statsSource, "timeAlive")
			if timeAlive <= 0 then
				return 0
			end

			return floor((apples / timeAlive) * 60)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)
			local minutes = timeAlive / 60
			local pace = 0
			if timeAlive > 0 then
				pace = floor((apples / timeAlive) * 60)
			end

			return {
				current = pace,
				goal = goal or 0,
				pace = pace,
				apples = apples,
				minutes = string.format("%.1f", max(minutes, 0)),
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
		id = "combo_courier",
		titleKey = "menu.daily.combo_courier.title",
		descriptionKey = "menu.daily.combo_courier.description",
		goal = 1,
		progressKey = "menu.daily.combo_courier.progress",
		completeKey = "menu.daily.combo_courier.complete",
		comboGoal = 5,
		floorGoal = 4,
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local combos = getStatValue(statsSource, "combosTriggered", context)
			local floors = getStatValue(statsSource, "floorsCleared", context)

			if combos >= (self.comboGoal or 0) and floors >= (self.floorGoal or 0) then
				return 1
			end

			return 0
		end,
		getRunValue = function(self, statsSource)
			local combos = getStatValue(statsSource, "combosTriggered")
			local floors = getStatValue(statsSource, "floorsCleared")

			if combos >= (self.comboGoal or 0) and floors >= (self.floorGoal or 0) then
				return 1
			end

			return 0
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local combos = getStatValue(statsSource, "combosTriggered", context)
			local floors = getStatValue(statsSource, "floorsCleared", context)
			local comboGoal = self.comboGoal or 0
			local floorGoal = self.floorGoal or 0

			return {
				current = current or 0,
				goal = goal or 0,
				combos = combos,
				combo_goal = comboGoal,
				floors = floors,
				floor_goal = floorGoal,
			}
		end,
		descriptionReplacements = function(self)
			return {
				combo_goal = self.comboGoal or 0,
				floor_goal = self.floorGoal or 0,
			}
		end,
		xpReward = 125,
	},
	{
		id = "combo_dash",
		titleKey = "menu.daily.combo_dash.title",
		descriptionKey = "menu.daily.combo_dash.description",
		goal = 1,
		progressKey = "menu.daily.combo_dash.progress",
		completeKey = "menu.daily.combo_dash.complete",
		comboGoal = 6,
		timeGoal = 360,
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local combos = getStatValue(statsSource, "combosTriggered", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)
			if timeAlive <= 0 then
				return 0
			end

			if combos >= (self.comboGoal or 0) and timeAlive <= (self.timeGoal or 0) then
				return 1
			end

			return 0
		end,
		getRunValue = function(self, statsSource)
			local combos = getStatValue(statsSource, "combosTriggered")
			local timeAlive = getStatValue(statsSource, "timeAlive")
			if timeAlive <= 0 then
				return 0
			end

			if combos >= (self.comboGoal or 0) and timeAlive <= (self.timeGoal or 0) then
				return 1
			end

			return 0
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local combos = getStatValue(statsSource, "combosTriggered", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)

			return {
				current = current or 0,
				goal = goal or 0,
				combos = combos,
				combo_goal = self.comboGoal or 0,
				time = formatSeconds(timeAlive),
				time_goal = formatSeconds(self.timeGoal or 0),
			}
		end,
		descriptionReplacements = function(self)
			return {
				combo_goal = self.comboGoal or 0,
				time_goal = formatSeconds(self.timeGoal or 0),
			}
		end,
		xpReward = 130,
	},
	{
		id = "fruit_frenzy",
		titleKey = "menu.daily.fruit_frenzy.title",
		descriptionKey = "menu.daily.fruit_frenzy.description",
		goal = 1,
		progressKey = "menu.daily.fruit_frenzy.progress",
		completeKey = "menu.daily.fruit_frenzy.complete",
		targetApples = 45,
		targetSeconds = 360,
		getValue = function(self, context)
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)
			if apples >= (self.targetApples or 0) and timeAlive > 0 and timeAlive <= (self.targetSeconds or 0) then
				return 1
			end
			return 0
		end,
		getRunValue = function(self, statsSource)
			local apples = getStatValue(statsSource, "applesEaten")
			local timeAlive = getStatValue(statsSource, "timeAlive")
			if apples >= (self.targetApples or 0) and timeAlive > 0 and timeAlive <= (self.targetSeconds or 0) then
				return 1
			end
			return 0
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local apples = getStatValue(statsSource, "applesEaten", context)
			local timeAlive = getStatValue(statsSource, "timeAlive", context)

			return {
				current = current or 0,
				goal = goal or 0,
				apples = apples,
				time = formatSeconds(timeAlive),
				target_apples = self.targetApples or 0,
				target_time = formatSeconds(self.targetSeconds or 0),
			}
		end,
		descriptionReplacements = function(self)
			return {
				target_apples = self.targetApples or 0,
				target_time = formatSeconds(self.targetSeconds or 0),
			}
		end,
		xpReward = 130,
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
			local floors = getStatValue(statsSource, "floorsCleared", context)
			local timeSpent = getStatValue(statsSource, "totalFloorTime", context)
			local value = min(floors, floor(timeSpent / (self.timeChunk or 1)))
			return max(value, 0)
		end,
		getRunValue = function(self, statsSource)
			local floors = getStatValue(statsSource, "floorsCleared")
			local timeSpent = getStatValue(statsSource, "totalFloorTime")
			local value = min(floors, floor(timeSpent / (self.timeChunk or 1)))
			return max(value, 0)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local floors = getStatValue(statsSource, "floorsCleared", context)
			local timeSpent = getStatValue(statsSource, "totalFloorTime", context)
			return {
				current = current or 0,
				goal = goal or 0,
				floors = floors,
				minutes = string.format("%.1f", max(timeSpent / 60, 0)),
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
			local bounces = getStatValue(statsSource, "runShieldWallBounces", context)
			local saws = getStatValue(statsSource, "runShieldSawParries", context)
			local pairs = min(floor(bounces / 2), floor(saws / 2))
			return max(pairs, 0)
		end,
		getRunValue = function(self, statsSource)
			local bounces = getStatValue(statsSource, "runShieldWallBounces")
			local saws = getStatValue(statsSource, "runShieldSawParries")
			local pairs = min(floor(bounces / 2), floor(saws / 2))
			return max(pairs, 0)
		end,
		progressReplacements = function(self, current, goal, context)
			local statsSource = context and context.sessionStats
			local bounces = getStatValue(statsSource, "runShieldWallBounces", context)
			local saws = getStatValue(statsSource, "runShieldSawParries", context)
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

function DailyChallenges:getTimeUntilReset(date)
	local resolved = resolveDate(self, date)
	return secondsUntilNextMidnight(resolved)
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
			runValue = getStatValue(statsSource, challenge.sessionStat)
		elseif challenge.stat then
			runValue = PlayerStats:get(challenge.stat) or 0
		end
	end

	runValue = max(0, floor(runValue or 0))

	local goal = resolveGoal(challenge)
	local prefix = buildDailyStoragePrefix(self, challenge, resolvedDate)
	local storedProgress = getStoredProgress(self, challenge, resolvedDate, prefix)
	local best = storedProgress
	if runValue > best then
		best = runValue
		setStoredProgress(self, challenge, resolvedDate, best, prefix)
	end

	local alreadyCompleted = isStoredComplete(self, challenge, resolvedDate, prefix)
	local xpAwarded = 0
	local completedNow = false
	local streakInfo = nil

	local previousStreak = PlayerStats:get("dailyChallengeStreak") or 0
	local previousBest = PlayerStats:get("dailyChallengeBestStreak") or 0
	local lastCompletionDay = PlayerStats:get("dailyChallengeLastCompletionDay") or 0
	local dayValue = getDayValue(resolvedDate)

	if goal > 0 and runValue >= goal and not alreadyCompleted then
		setStoredComplete(self, challenge, resolvedDate, true, prefix)
		xpAwarded = challenge.xpReward or self.defaultXpReward
		completedNow = true

		PlayerStats:add("dailyChallengesCompleted", 1)

		local newStreak = previousStreak
		if dayValue then
			if lastCompletionDay > 0 then
				if lastCompletionDay == dayValue then
					newStreak = max(previousStreak, 1)
				elseif lastCompletionDay == dayValue - 1 then
					newStreak = max(previousStreak, 0) + 1
				else
					newStreak = 1
				end
			else
				newStreak = 1
			end

			PlayerStats:set("dailyChallengeLastCompletionDay", dayValue)
		else
			newStreak = max(previousStreak, 1)
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
		local currentStreak = max(previousStreak, 0)
		local bestStreak = max(previousBest, currentStreak)
		streakInfo = {
			current = currentStreak,
			best = bestStreak,
			alreadyCompleted = true,
			dayValue = dayValue,
		}
	elseif previousStreak > 0 then
		local currentStreak = max(previousStreak, 0)
		local bestStreak = max(previousBest, currentStreak)
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