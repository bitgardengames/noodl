local PlayerStats = require("playerstats")
local DailyProgress = require("dailyprogress")
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

DailyChallenges._sessionDate = nil

local defaultDateProvider = function()
	if not DailyChallenges._sessionDate then
		DailyChallenges._sessionDate = os.date("*t")
	end
	return DailyChallenges._sessionDate
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

local function resolveDayValue(self, date)
	local resolved = resolveDate(self, date)
	return getDayValue(resolved), resolved
end

local function getStoredProgress(self, challenge, date, dayValue)
	if not challenge or not challenge.id then
		return 0
	end

	dayValue = dayValue or select(1, resolveDayValue(self, date))
	if not dayValue then
		return 0
	end

	return DailyProgress:getProgress(challenge.id, dayValue) or 0
end

local function setStoredProgress(self, challenge, date, value, dayValue, saveAfter)
	if not challenge or not challenge.id then
		return
	end

	dayValue = dayValue or select(1, resolveDayValue(self, date))
	if not dayValue then
		return
	end

	value = max(0, floor(value or 0))
	DailyProgress:setProgress(challenge.id, dayValue, value, saveAfter)
end

local function isStoredComplete(self, challenge, date, dayValue)
	if not challenge or not challenge.id then
		return false
	end

	dayValue = dayValue or select(1, resolveDayValue(self, date))
	if not dayValue then
		return false
	end

	return DailyProgress:isComplete(challenge.id, dayValue)
end

local function setStoredComplete(self, challenge, date, complete, dayValue, saveAfter)
	if not challenge or not challenge.id then
		return
	end

	dayValue = dayValue or select(1, resolveDayValue(self, date))
	if not dayValue then
		return
	end

	DailyProgress:setComplete(challenge.id, dayValue, complete, saveAfter)
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
	local dayValue, resolvedDate = resolveDayValue(self, context.date or context.dateOverride)
	local storedProgress = getStoredProgress(self, challenge, resolvedDate, dayValue)
	if storedProgress and storedProgress >= 0 then
		current = storedProgress
	end

	local storedComplete = isStoredComplete(self, challenge, resolvedDate, dayValue)
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
	},
	{
		id = "pathfinder",
		titleKey = "menu.daily.pathfinder.title",
		descriptionKey = "menu.daily.pathfinder.description",
		sessionStat = "floorsCleared",
		goal = 6,
	},
	{
		id = "combo_conductor",
		titleKey = "menu.daily.combos.title",
		descriptionKey = "menu.daily.combos.description",
		sessionStat = "combosTriggered",
		goal = 10,
		progressKey = "menu.daily.combos.progress",
	},
	{
		id = "stonebreaker_protocol",
		titleKey = "menu.daily.stonebreaker_protocol.title",
		descriptionKey = "menu.daily.stonebreaker_protocol.description",
		sessionStat = "runShieldRockBreaks",
		goal = 4,
		progressKey = "menu.daily.stonebreaker_protocol.progress",
		completeKey = "menu.daily.stonebreaker_protocol.complete",
	},
	{
		id = "saw_parry_ace",
		titleKey = "menu.daily.saw_parry.title",
		descriptionKey = "menu.daily.saw_parry.description",
		sessionStat = "runShieldSawParries",
		goal = 1,
		progressKey = "menu.daily.saw_parry.progress",
		completeKey = "menu.daily.saw_parry.complete",
	},
	{
		id = "depth_delver",
		titleKey = "menu.daily.depth_delver.title",
		descriptionKey = "menu.daily.depth_delver.description",
		sessionStat = "deepestFloorReached",
		goal = 6,
		progressKey = "menu.daily.depth_delver.progress",
		completeKey = "menu.daily.depth_delver.complete",
		progressReplacements = function(self, current, goal)
			return {
				current = max(1, floor(current or 1)),
				goal = goal or 0,
			}
		end,
	},
	{
		id = "floor_speedrunner",
		titleKey = "menu.daily.floor_speedrunner.title",
		descriptionKey = "menu.daily.floor_speedrunner.description",
		goal = 1,
		progressKey = "menu.daily.floor_speedrunner.progress",
		completeKey = "menu.daily.floor_speedrunner.complete",
		targetSeconds = 25, -- This should be dynamic based on floor, they have different fruit requirements and hazards to deal with
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

	local hasSaved = false

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
	local dayValue = getDayValue(resolvedDate)
	local storedProgress = getStoredProgress(self, challenge, resolvedDate, dayValue)
	local best = storedProgress
	if runValue > best then
		best = runValue
		setStoredProgress(self, challenge, resolvedDate, best, dayValue, false)
		hasSaved = true
	end

	local alreadyCompleted = isStoredComplete(self, challenge, resolvedDate, dayValue)
	local completedNow = false
	local streakInfo = nil

	local streakData = DailyProgress:getStreak()
	local previousStreak = streakData.current or 0
	local previousBest = streakData.best or 0
	local lastCompletionDay = streakData.lastCompletionDay or 0

	if goal > 0 and runValue >= goal and not alreadyCompleted then
		setStoredComplete(self, challenge, resolvedDate, true, dayValue, false)
		completedNow = true

		streakInfo = DailyProgress:recordCompletion(dayValue, false)
		hasSaved = true

		local achievements = getAchievements()
		if achievements and achievements.checkAll then
			local ok, err = pcall(function()
				achievements:checkAll(
			)
				end
			)
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

	if hasSaved then
		DailyProgress:save()
	end

	return {
		challengeId = challenge.id,
		goal = goal,
		progress = best,
		completed = alreadyCompleted or completedNow,
		completedNow = completedNow,
		streakInfo = streakInfo,
	}
end

return DailyChallenges
