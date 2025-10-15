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

local function ResolveDefault(entry)
	if type(entry) ~= "table" then
		return nil
	end

	local DefaultValue = entry.default
	if DefaultValue == nil then
		return nil
	end

	if type(DefaultValue) == "function" then
		return DefaultValue()
	end

	return clone(DefaultValue)
end

function DataSchemas.ApplyDefaults(schema, target)
	if type(schema) ~= "table" or type(target) ~= "table" then
		return target
	end

	for key, entry in pairs(schema) do
		if target[key] == nil then
			local DefaultValue = ResolveDefault(entry)
			if DefaultValue ~= nil then
				target[key] = DefaultValue
			end
		end
	end

	return target
end

function DataSchemas.CollectDefaults(schema)
	local defaults = {}
	if type(schema) ~= "table" then
		return defaults
	end

	for key, entry in pairs(schema) do
		local value = ResolveDefault(entry)
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

DataSchemas.PlayerStats = {
	TotalApplesEaten = {
		type = "number",
		default = 0,
		description = "Lifetime apples eaten across all runs.",
	},
	SessionsPlayed = {
		type = "number",
		default = 0,
		description = "Number of complete run attempts.",
	},
	TotalDragonfruitEaten = {
		type = "number",
		default = 0,
		description = "Lifetime dragonfruit collected.",
	},
	SnakeScore = {
		type = "number",
		description = "Highest score achieved in a single run.",
	},
	FloorsCleared = {
		type = "number",
		default = 0,
		description = "Total floors cleared across all runs.",
	},
	DeepestFloorReached = {
		type = "number",
		default = 0,
		description = "Deepest floor reached in any run.",
	},
	BestComboStreak = {
		type = "number",
		default = 0,
		description = "Highest combo streak recorded.",
	},
	DailyChallengesCompleted = {
		type = "number",
		default = 0,
		description = "Daily challenges completed.",
	},
	ShieldWallBounces = {
		type = "number",
		default = 0,
		description = "Shield wall ricochets accumulated.",
	},
	ShieldRockBreaks = {
		type = "number",
		default = 0,
		description = "Shield-assisted rock breaks.",
	},
	ShieldSawParries = {
		type = "number",
		default = 0,
		description = "Shield parries against saws and similar hazards.",
	},
	TotalUpgradesPurchased = {
		type = "number",
		default = 0,
		description = "Lifetime upgrades bought from the shop.",
	},
	MostUpgradesInRun = {
		type = "number",
		default = 0,
		description = "Highest number of upgrades acquired in a single run.",
	},
	LegendaryUpgradesPurchased = {
		type = "number",
		default = 0,
		description = "Legendary upgrades purchased across all runs.",
	},
	DailyChallengeStreak = {
		type = "number",
		default = 0,
		description = "Current daily challenge completion streak.",
	},
	DailyChallengeBestStreak = {
		type = "number",
		default = 0,
		description = "Best daily challenge streak achieved.",
	},
	DailyChallengeLastCompletionDay = {
		type = "number",
		description = "Calendar day value of the most recent daily completion.",
	},
	MostApplesInRun = {
		type = "number",
		default = 0,
		description = "Most apples collected in a single run.",
	},
	TotalTimeAlive = {
		type = "number",
		default = 0,
		description = "Total survival time across all runs (seconds).",
	},
	LongestRunDuration = {
		type = "number",
		default = 0,
		description = "Longest run duration recorded (seconds).",
	},
	TilesTravelled = {
		type = "number",
		default = 0,
		description = "Lifetime tiles travelled.",
	},
	MostTilesTravelledInRun = {
		type = "number",
		default = 0,
		description = "Most tiles travelled in a single run.",
	},
	TotalCombosTriggered = {
		type = "number",
		default = 0,
		description = "Total combos triggered across all runs.",
	},
	MostCombosInRun = {
		type = "number",
		default = 0,
		description = "Most combos triggered in a single run.",
	},
	CrashShieldsSaved = {
		type = "number",
		default = 0,
		description = "Crash shields spent to prevent hits.",
	},
	MostShieldsSavedInRun = {
		type = "number",
		default = 0,
		description = "Most crash shields saved in a single run.",
	},
	BestFloorClearTime = {
		type = "number",
		description = "Fastest floor clear time (seconds).",
	},
	LongestFloorClearTime = {
		type = "number",
		description = "Slowest floor clear time (seconds).",
	},
}

DataSchemas.UpgradeDefinition = {
	id = {
		type = "string",
		required = true,
		description = "Unique identifier for the upgrade.",
	},
	NameKey = {
		type = "string",
		required = true,
		description = "Localization key for upgrade name.",
	},
	DescKey = {
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
