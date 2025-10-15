local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")

local AchievementsModule

local function GetAchievements()
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
DailyChallenges.DefaultXpReward = 120

local DefaultDateProvider = function()
	return os.date("*t")
end

local function DefaultProgressReplacements(current, goal)
	return {
		current = current or 0,
		goal = goal or 0,
	}
end

local function MergeReplacements(base, extra)
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

local function CallChallengeFunction(challenge, key, ...)
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

local function ResolveGoal(challenge, context)
	local override = context and context.goalOverride
	if override ~= nil then
		return override
	end

	local value = CallChallengeFunction(challenge, "GetGoal", context)
	if value ~= nil then
		return value
	end

	return challenge.goal or 0
end

local function ResolveCurrent(challenge, context)
	local override = context and context.currentOverride
	if override ~= nil then
		return override
	end

	local value = CallChallengeFunction(challenge, "GetValue", context)
	if value ~= nil then
		return value
	end

	if challenge.sessionStat then
		local StatsSource = context and context.sessionStats
		if StatsSource and type(StatsSource.get) == "function" then
			return StatsSource:get(challenge.sessionStat) or 0
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

local function ResolveProgressReplacements(challenge, current, goal, context)
	local replacements = DefaultProgressReplacements(current, goal)
	local extra = CallChallengeFunction(challenge, "ProgressReplacements", current, goal, context)
	if extra then
		replacements = MergeReplacements(replacements, extra)
	end
	return replacements
end

local function ResolveDescriptionReplacements(challenge, current, goal, context)
	local replacements = { goal = goal or 0, current = current or 0 }
	local extra = CallChallengeFunction(challenge, "DescriptionReplacements", current, goal, context)
	if extra then
		replacements = MergeReplacements(replacements, extra)
	end
	return replacements
end

local DEFAULT_PROGRESS_KEY = "menu.daily_panel_progress"
local DEFAULT_COMPLETE_KEY = "menu.daily_panel_complete"

local function BuildStatusBar(challenge, completed, current, goal, ratio, replacements)
	if not goal or goal <= 0 then
		return nil
	end

	local TextKey
	if completed then
		TextKey = challenge.completeKey or DEFAULT_COMPLETE_KEY
	else
		TextKey = challenge.progressKey or DEFAULT_PROGRESS_KEY
	end

	return {
		current = current or 0,
		goal = goal or 0,
		ratio = ratio or 0,
		TextKey = TextKey,
		replacements = replacements or DefaultProgressReplacements(current, goal),
		completed = completed or false,
	}
end

local function ClampRatio(current, goal)
	if goal and goal > 0 then
		return math.max(0, math.min(1, current / goal))
	end
	return 0
end

local function ResolveDate(self, override)
	if type(override) == "table" then
		return override
	end

	local provider = self._dateProvider or DefaultDateProvider
	return provider()
end

local function BuildStorageKey(self, challenge, date, suffix)
	if not challenge or not challenge.id then
		return nil
	end

	date = ResolveDate(self, date)
	if not date then
		return nil
	end

	local DayValue = (date.year or 0) * 512 + (date.yday or 0)
	return string.format("DailyChallenge:%s:%d:%s", challenge.id, DayValue, suffix)
end

local function GetStoredProgress(self, challenge, date)
	local key = BuildStorageKey(self, challenge, date, "progress")
	if not key then
		return 0
	end
	return PlayerStats:get(key) or 0
end

local function SetStoredProgress(self, challenge, date, value)
	local key = BuildStorageKey(self, challenge, date, "progress")
	if not key then
		return
	end

	value = math.max(0, math.floor(value or 0))
	PlayerStats:set(key, value)
end

local function IsStoredComplete(self, challenge, date)
	local key = BuildStorageKey(self, challenge, date, "complete")
	if not key then
		return false
	end

	local value = PlayerStats:get(key) or 0
	return value >= 1
end

local function SetStoredComplete(self, challenge, date, complete)
	local key = BuildStorageKey(self, challenge, date, "complete")
	if not key then
		return
	end

	PlayerStats:set(key, complete and 1 or 0)
end

local function GetChallengeIndex(self, count, date)
	if count <= 0 then
		return nil
	end

	date = ResolveDate(self, date)
	if not date then
		return 1
	end

	local value = (date.year or 0) * 512 + (date.yday or 0)
	local offset = self._dailyOffset or 0
	local adjusted = value + offset
	local index = ((adjusted % count) + count) % count + 1

	return index
end

local function EvaluateChallenge(self, challenge, context)
	if not challenge then
		return nil
	end

	context = context or {}

	local goal = ResolveGoal(challenge, context)
	local current = ResolveCurrent(challenge, context)
	local date = context.date or context.dateOverride
	local StoredProgress = GetStoredProgress(self, challenge, date)
	if StoredProgress and StoredProgress > (current or 0) then
		current = StoredProgress
	end

	local StoredComplete = IsStoredComplete(self, challenge, date)
	local ratio = ClampRatio(current, goal)

	local DescriptionReplacements = ResolveDescriptionReplacements(challenge, current, goal, context)
	local ProgressReplacements = ResolveProgressReplacements(challenge, current, goal, context)
	local completed = StoredComplete or (goal > 0 and current >= goal)
	local StatusBar = BuildStatusBar(challenge, completed, current, goal, ratio, ProgressReplacements)

	return {
		id = challenge.id,
		index = challenge.index,
		TitleKey = challenge.titleKey,
		DescriptionKey = challenge.descriptionKey,
		DescriptionReplacements = DescriptionReplacements,
		goal = goal,
		current = current,
		ratio = ratio,
		completed = completed,
		XpReward = challenge.xpReward or DailyChallenges.DefaultXpReward,
		StatusBar = StatusBar,
	}
end

DailyChallenges.challenges = {
	{
		id = "combo_crunch",
		TitleKey = "menu.daily.combo.title",
		DescriptionKey = "menu.daily.combo.description",
		SessionStat = "BestComboStreak",
		goal = 5,
		ProgressKey = "menu.daily.combo.progress",
		CompleteKey = "menu.daily.combo.complete",
		ProgressReplacements = function(self, current, goal)
			return {
				best = current or 0,
				goal = goal or 0,
			}
		end,
		XpReward = 70,
	},
	{
		id = "floor_explorer",
		TitleKey = "menu.daily.floors.title",
		DescriptionKey = "menu.daily.floors.description",
		SessionStat = "FloorsCleared",
		goal = 5,
		XpReward = 80,
	},
	{
		id = "fruit_sampler",
		TitleKey = "menu.daily.apples.title",
		DescriptionKey = "menu.daily.apples.description",
		SessionStat = "ApplesEaten",
		goal = 45,
		ProgressKey = "menu.daily.apples.progress",
		XpReward = 70,
	},
	{
		id = "dragonfruit_delight",
		TitleKey = "menu.daily.dragonfruit.title",
		DescriptionKey = "menu.daily.dragonfruit.description",
		SessionStat = "DragonfruitEaten",
		goal = 1,
		ProgressKey = "menu.daily.dragonfruit.progress",
		CompleteKey = "menu.daily.dragonfruit.complete",
		XpReward = 90,
	},
	{
		id = "combo_conductor",
		TitleKey = "menu.daily.combos.title",
		DescriptionKey = "menu.daily.combos.description",
		SessionStat = "CombosTriggered",
		goal = 8,
		ProgressKey = "menu.daily.combos.progress",
		XpReward = 60,
	},
	{
		id = "shield_specialist",
		TitleKey = "menu.daily.shields.title",
		DescriptionKey = "menu.daily.shields.description",
		SessionStat = "CrashShieldsSaved",
		goal = 3,
		ProgressKey = "menu.daily.shields.progress",
		CompleteKey = "menu.daily.shields.complete",
		XpReward = 80,
	},
	{
		id = "shield_triad",
		TitleKey = "menu.daily.shield_triad.title",
		DescriptionKey = "menu.daily.shield_triad.description",
		goal = 3,
		ProgressKey = "menu.daily.shield_triad.progress",
		CompleteKey = "menu.daily.shield_triad.complete",
		GetValue = function(self, context)
			local StatsSource = context and context.sessionStats
			if StatsSource and type(StatsSource.get) == "function" then
				local wall = StatsSource:get("RunShieldWallBounces") or 0
				local rock = StatsSource:get("RunShieldRockBreaks") or 0
				local saw = StatsSource:get("RunShieldSawParries") or 0
				return (wall > 0 and 1 or 0) + (rock > 0 and 1 or 0) + (saw > 0 and 1 or 0)
			end

			local wall = SessionStats and SessionStats.get and SessionStats:get("RunShieldWallBounces") or 0
			local rock = SessionStats and SessionStats.get and SessionStats:get("RunShieldRockBreaks") or 0
			local saw = SessionStats and SessionStats.get and SessionStats:get("RunShieldSawParries") or 0
			return (wall > 0 and 1 or 0) + (rock > 0 and 1 or 0) + (saw > 0 and 1 or 0)
		end,
		XpReward = 85,
	},
	{
		id = "serpentine_marathon",
		TitleKey = "menu.daily.marathon.title",
		DescriptionKey = "menu.daily.marathon.description",
		SessionStat = "TilesTravelled",
		goal = 3000,
		ProgressKey = "menu.daily.marathon.progress",
		XpReward = 70,
	},
	{
		id = "shield_wall_master",
		TitleKey = "menu.daily.shield_bounce.title",
		DescriptionKey = "menu.daily.shield_bounce.description",
		SessionStat = "RunShieldWallBounces",
		goal = 5,
		ProgressKey = "menu.daily.shield_bounce.progress",
		CompleteKey = "menu.daily.shield_bounce.complete",
		XpReward = 80,
	},
	{
		id = "rock_breaker",
		TitleKey = "menu.daily.rock_breaker.title",
		DescriptionKey = "menu.daily.rock_breaker.description",
		SessionStat = "RunShieldRockBreaks",
		goal = 4,
		ProgressKey = "menu.daily.rock_breaker.progress",
		CompleteKey = "menu.daily.rock_breaker.complete",
		XpReward = 80,
	},
	{
		id = "saw_parry_ace",
		TitleKey = "menu.daily.saw_parry.title",
		DescriptionKey = "menu.daily.saw_parry.description",
		SessionStat = "RunShieldSawParries",
		goal = 2,
		ProgressKey = "menu.daily.saw_parry.progress",
		CompleteKey = "menu.daily.saw_parry.complete",
		XpReward = 90,
	},
	{
		id = "time_keeper",
		TitleKey = "menu.daily.time_keeper.title",
		DescriptionKey = "menu.daily.time_keeper.description",
		SessionStat = "TimeAlive",
		goal = 600,
		ProgressKey = "menu.daily.time_keeper.progress",
		ProgressReplacements = function(self, current, goal)
			local function FormatSeconds(seconds)
				seconds = math.max(0, math.floor(seconds or 0))
				local minutes = math.floor(seconds / 60)
				local secs = seconds % 60
				return string.format("%d:%02d", minutes, secs)
			end

			return {
				current = FormatSeconds(current),
				goal = FormatSeconds(goal),
			}
		end,
		DescriptionReplacements = function(self, current, goal)
			return {
				goal = math.floor((goal or 0) / 60),
				current = math.floor((current or 0) / 60),
			}
		end,
		XpReward = 90,
	},
	{
		id = "floor_tourist",
		TitleKey = "menu.daily.floor_tourist.title",
		DescriptionKey = "menu.daily.floor_tourist.description",
		SessionStat = "TotalFloorTime",
		goal = 480,
		ProgressKey = "menu.daily.floor_tourist.progress",
		ProgressReplacements = function(self, current, goal)
			local function FormatSeconds(seconds)
				seconds = math.max(0, math.floor(seconds or 0))
				local minutes = math.floor(seconds / 60)
				local secs = seconds % 60
				return string.format("%d:%02d", minutes, secs)
			end

			return {
				current = FormatSeconds(current),
				goal = FormatSeconds(goal),
			}
		end,
		DescriptionReplacements = function(self, current, goal)
			return {
				goal = math.floor((goal or 0) / 60),
			}
		end,
		XpReward = 85,
		},
		{
			id = "floor_conqueror",
			TitleKey = "menu.daily.floor_conqueror.title",
			DescriptionKey = "menu.daily.floor_conqueror.description",
			SessionStat = "FloorsCleared",
			goal = 8,
			XpReward = 100,
		},
		{
		id = "depth_delver",
		TitleKey = "menu.daily.depth_delver.title",
		DescriptionKey = "menu.daily.depth_delver.description",
		SessionStat = "DeepestFloorReached",
		goal = 10,
		ProgressKey = "menu.daily.depth_delver.progress",
		CompleteKey = "menu.daily.depth_delver.complete",
		ProgressReplacements = function(self, current, goal)
			return {
				current = math.max(1, math.floor(current or 1)),
				goal = goal or 0,
			}
		end,
		XpReward = 110,
	},
	{
		id = "apple_hoarder",
		TitleKey = "menu.daily.apple_hoarder.title",
		DescriptionKey = "menu.daily.apple_hoarder.description",
		SessionStat = "ApplesEaten",
		goal = 70,
		ProgressKey = "menu.daily.apple_hoarder.progress",
		XpReward = 90,
	},
	{
		id = "streak_perfectionist",
		TitleKey = "menu.daily.streak_perfectionist.title",
		DescriptionKey = "menu.daily.streak_perfectionist.description",
		SessionStat = "FruitWithoutTurning",
		goal = 12,
		ProgressKey = "menu.daily.streak_perfectionist.progress",
		CompleteKey = "menu.daily.streak_perfectionist.complete",
		XpReward = 90,
	},
}

function DailyChallenges:GetChallengeForIndex(index, context)
	local challenge = self.challenges[index]
	if not challenge then
		return nil
	end

	challenge.index = index
	return EvaluateChallenge(self, challenge, context)
end

function DailyChallenges:GetDailyChallenge(date, context)
	local count = #self.challenges
	local index = GetChallengeIndex(self, count, date)
	if not index then
		return nil
	end

	context = context or {}
	context.date = context.date or ResolveDate(self, date)
	return self:GetChallengeForIndex(index, context)
end

local function GetDayValue(date)
	if not date then
		return nil
	end

	return (date.year or 0) * 512 + (date.yday or 0)
end

function DailyChallenges:ApplyRunResults(StatsSource, options)
	StatsSource = StatsSource or SessionStats
	options = options or {}

	local date = options.date
	local ResolvedDate = ResolveDate(self, date)
	local count = #self.challenges
	if count == 0 then
		return nil
	end

	local index = GetChallengeIndex(self, count, ResolvedDate)
	if not index then
		return nil
	end

	local challenge = self.challenges[index]
	if not challenge then
		return nil
	end

	local RunValue = CallChallengeFunction(challenge, "GetRunValue", StatsSource, options)

	if RunValue == nil then
		if challenge.sessionStat and StatsSource then
			if type(StatsSource.get) == "function" then
				RunValue = StatsSource:get(challenge.sessionStat) or 0
			else
				RunValue = StatsSource[challenge.sessionStat] or 0
			end
		elseif challenge.stat then
			RunValue = PlayerStats:get(challenge.stat) or 0
		end
	end

	RunValue = math.max(0, math.floor(RunValue or 0))

	local goal = ResolveGoal(challenge)
	local StoredProgress = GetStoredProgress(self, challenge, ResolvedDate)
	local best = StoredProgress
	if RunValue > best then
		best = RunValue
		SetStoredProgress(self, challenge, ResolvedDate, best)
	end

	local AlreadyCompleted = IsStoredComplete(self, challenge, ResolvedDate)
	local XpAwarded = 0
	local CompletedNow = false
	local StreakInfo = nil

	local PreviousStreak = PlayerStats:get("DailyChallengeStreak") or 0
	local PreviousBest = PlayerStats:get("DailyChallengeBestStreak") or 0
	local LastCompletionDay = PlayerStats:get("DailyChallengeLastCompletionDay") or 0
	local DayValue = GetDayValue(ResolvedDate)

	if goal > 0 and RunValue >= goal and not AlreadyCompleted then
		SetStoredComplete(self, challenge, ResolvedDate, true)
		XpAwarded = challenge.xpReward or self.DefaultXpReward
		CompletedNow = true

		PlayerStats:add("DailyChallengesCompleted", 1)

		local NewStreak = PreviousStreak
		if DayValue then
			if LastCompletionDay > 0 then
				if LastCompletionDay == DayValue then
					NewStreak = math.max(PreviousStreak, 1)
				elseif LastCompletionDay == DayValue - 1 then
					NewStreak = math.max(PreviousStreak, 0) + 1
				else
					NewStreak = 1
				end
			else
				NewStreak = 1
			end

			PlayerStats:set("DailyChallengeLastCompletionDay", DayValue)
		else
			NewStreak = math.max(PreviousStreak, 1)
		end

		if NewStreak <= 0 then
			NewStreak = 1
		end

		PlayerStats:set("DailyChallengeStreak", NewStreak)

		local BestStreak = PreviousBest
		if NewStreak > BestStreak then
			BestStreak = NewStreak
			PlayerStats:set("DailyChallengeBestStreak", BestStreak)
		end

		StreakInfo = {
			current = NewStreak,
			best = BestStreak,
			WasNewBest = NewStreak > PreviousBest,
			continued = (LastCompletionDay > 0 and DayValue and (DayValue - LastCompletionDay) == 1) or false,
			DayValue = DayValue,
		}

		local achievements = GetAchievements()
		if achievements and achievements.checkAll then
			local ok, err = pcall(function()
				achievements:checkAll()
			end)
			if not ok then
				print("[DailyChallenges] Failed to update achievements after daily challenge completion:", err)
			end
		end
	elseif AlreadyCompleted then
		local CurrentStreak = math.max(PreviousStreak, 0)
		local BestStreak = math.max(PreviousBest, CurrentStreak)
		StreakInfo = {
			current = CurrentStreak,
			best = BestStreak,
			AlreadyCompleted = true,
			DayValue = DayValue,
		}
	elseif PreviousStreak > 0 then
		local CurrentStreak = math.max(PreviousStreak, 0)
		local BestStreak = math.max(PreviousBest, CurrentStreak)
		StreakInfo = {
			current = CurrentStreak,
			best = BestStreak,
			NeedsCompletion = (DayValue ~= nil and LastCompletionDay ~= DayValue),
			DayValue = DayValue,
		}
	end

	return {
		ChallengeId = challenge.id,
		goal = goal,
		progress = best,
		completed = AlreadyCompleted or CompletedNow,
		CompletedNow = CompletedNow,
		XpAwarded = XpAwarded,
		StreakInfo = StreakInfo,
	}
end

return DailyChallenges
