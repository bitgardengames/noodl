local MetaProgression = {}

local SaveFile = "metaprogression_state.lua"

local DEFAULT_DATA = {
	TotalExperience = 0,
	level = 1,
	UnlockHistory = {},
}

--[[
	Meta progression tuning notes

	The previous tuning handed out experience very slowly which made the
	early unlocks feel grindy. Doubling the fruit award while also widening
	the score bonus band keeps skilled runs feeling rewarding, and the
	updated level curve makes sure the later levels still ask for commitment
	without becoming an endless slog.
]]

local XP_PER_FRUIT = 2
local SCORE_BONUS_DIVISOR = 450
local SCORE_BONUS_MAX = 400

local BASE_XP_PER_LEVEL = 65
local LINEAR_XP_PER_LEVEL = 21
local XP_CURVE_SCALE = 10
local XP_CURVE_EXPONENT = 1.32

local UnlockDefinitions = {
	[2] = {
		id = "shop_expansion_1",
		name = "Shop Expansion I",
		description = "Adds a third upgrade card to every visit.",
		effects = {
			ShopExtraChoices = 1,
		},
	},
	[3] = {
		id = "specialist_pool",
		name = "Specialist Contracts",
		description = "Unlocks rare defensive specialists in the upgrade pool.",
		UnlockTags = { "specialist" },
	},
	[4] = {
		id = "dash_prototype",
		name = "Thunder Dash Prototype",
		description = "Unlocks dash ability upgrades in the shop.",
		UnlockTags = { "abilities" },
	},
	[5] = {
		id = "temporal_study",
		name = "Temporal Study",
		description = "Unlocks time-bending upgrades that slow the arena.",
		UnlockTags = { "timekeeper" },
	},
	[6] = {
		id = "event_horizon",
		name = "Event Horizon",
		description = "Unlocks experimental portal tech—legendary upgrades included.",
		UnlockTags = { "legendary" },
	},
	[7] = {
		id = "combo_research",
		name = "Combo Research Initiative",
		description = "Unlocks advanced combo support upgrades in the shop.",
		UnlockTags = { "combo_mastery" },
	},
	[9] = {
		id = "ion_storm_scales",
		name = "Ion Storm Scales",
		description = "Unlocks the Ion Storm snake skin for your handler profile.",
	},
	[10] = {
		id = "stormrunner_certification",
		name = "Stormrunner Certification",
		description = "Unlocks dash-synergy upgrades like Sparkstep Relay in the shop.",
		UnlockTags = { "stormtech" },
	},
	[11] = {
		id = "precision_coils",
		name = "Precision Coil Prototypes",
		description = "Unlocks the deliberate coil speed regulator upgrade.",
		UnlockTags = { "speedcraft" },
	},
	[12] = {
		id = "chrono_carapace_scales",
		name = "Chrono Carapace Scales",
		description = "Unlocks the Chrono Carapace snake skin and artisan supply contracts in the shop.",
		UnlockTags = { "artisan_alliance" },
	},
	[13] = {
		id = "abyssal_protocols",
		name = "Abyssal Protocols",
		description = "Unlocks abyssal relic upgrades including the Abyssal Catalyst.",
		UnlockTags = { "abyssal_protocols" },
	},
        [14] = {
                id = "midnight_circuit_scales",
                name = "Midnight Circuit Scales",
                description = "Unlocks the Midnight Circuit snake skin for your handler profile.",
        },
}

local MilestoneThresholds = {
	650,
	1300,
	2400,
	3800,
	5200,
	7800,
	10500,
}

local function CopyTable(tbl)
	local result = {}
	if type(tbl) ~= "table" then
		return result
	end
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			result[k] = CopyTable(v)
		else
			result[k] = v
		end
	end
	return result
end

function MetaProgression:_ensureLoaded()
	if self._loaded then
		return
	end

	self.data = CopyTable(DEFAULT_DATA)

	if love.filesystem.getInfo(SaveFile) then
		local success, chunk = pcall(love.filesystem.load, SaveFile)
		if success and chunk then
			local ok, saved = pcall(chunk)
			if ok and type(saved) == "table" then
				for k, v in pairs(saved) do
					if type(DEFAULT_DATA[k]) ~= "table" then
						self.data[k] = v
					elseif type(v) == "table" then
						self.data[k] = CopyTable(v)
					end
				end
			end
		end
	end

	if type(self.data.TotalExperience) ~= "number" or self.data.TotalExperience < 0 then
		self.data.TotalExperience = 0
	end
	if type(self.data.level) ~= "number" or self.data.level < 1 then
		self.data.level = 1
	end
	if type(self.data.UnlockHistory) ~= "table" then
		self.data.UnlockHistory = {}
	end

	self._loaded = true
end

local function serialize(value, indent)
	indent = indent or 0
	local ValueType = type(value)

	if ValueType == "number" or ValueType == "boolean" then
		return tostring(value)
	elseif ValueType == "string" then
		return string.format("%q", value)
	elseif ValueType == "table" then
		local spacing = string.rep(" ", indent)
		local lines = { "{\n" }
		local NextIndent = indent + 4
		local EntryIndent = string.rep(" ", NextIndent)
		for k, v in pairs(value) do
			local key = string.format("[%q]", tostring(k))
			table.insert(lines, string.format("%s%s = %s,\n", EntryIndent, key, serialize(v, NextIndent)))
		end
		table.insert(lines, string.format("%s}", spacing))
		return table.concat(lines)
	end

	return "nil"
end

function MetaProgression:_save()
	self:_ensureLoaded()
	local ToSave = {
		TotalExperience = self.data.TotalExperience,
		level = self.data.level,
		UnlockHistory = self.data.UnlockHistory,
	}
	local serialized = "return " .. serialize(ToSave, 0) .. "\n"
	love.filesystem.write(SaveFile, serialized)
end

function MetaProgression:GetXpForLevel(level)
	level = math.max(1, math.floor(level or 1))
	local LevelIndex = level - 1
	local base = BASE_XP_PER_LEVEL
	local linear = LINEAR_XP_PER_LEVEL * LevelIndex
	local curve = math.floor((LevelIndex ^ XP_CURVE_EXPONENT) * XP_CURVE_SCALE)
	return base + linear + curve
end

function MetaProgression:GetProgressForTotal(TotalXP)
	self:_ensureLoaded()
	local level = 1
	local XpForNext = self:GetXpForLevel(level)
	local remaining = math.max(0, TotalXP or 0)

	while remaining >= XpForNext do
		remaining = remaining - XpForNext
		level = level + 1
		XpForNext = self:GetXpForLevel(level)
	end

	return level, remaining, XpForNext
end

function MetaProgression:GetTotalXpForLevel(level)
	level = math.max(1, math.floor(level or 1))
	local total = 0
	for lvl = 1, level - 1 do
		total = total + self:GetXpForLevel(lvl)
	end
	return total
end

local CORE_UNLOCK_TAG = "core"

local function AccumulateEffects(target, source)
	if type(source) ~= "table" then
		return
	end

	for key, value in pairs(source) do
		if type(value) == "number" then
			target[key] = (target[key] or 0) + value
		else
			target[key] = value
		end
	end
end

function MetaProgression:_collectUnlockedEffects()
	self:_ensureLoaded()

	local effects = {
		ShopExtraChoices = 0,
		tags = { [CORE_UNLOCK_TAG] = true },
	}

	local CurrentLevel = self.data.level or 1
	for level, definition in pairs(UnlockDefinitions) do
		if level <= CurrentLevel then
			if definition.effects then
				AccumulateEffects(effects, definition.effects)
			end
			if definition.unlockTags then
				for _, tag in ipairs(definition.unlockTags) do
					if tag then
						effects.tags[tag] = true
					end
				end
			end
		end
	end

	return effects
end

function MetaProgression:GetShopBonusSlots()
	local effects = self:_collectUnlockedEffects()
	return math.floor(effects.shopExtraChoices or 0)
end

function MetaProgression:GetUnlockedTags()
	local effects = self:_collectUnlockedEffects()
	return effects.tags or {}
end

function MetaProgression:IsTagUnlocked(tag)
	if not tag or tag == CORE_UNLOCK_TAG then
		return true
	end

	local unlocked = self:GetUnlockedTags()
	return unlocked[tag] == true
end

function MetaProgression:GetUnlockTrack()
	self:_ensureLoaded()

	local CurrentTotal = math.max(0, self.data.TotalExperience or 0)
	local CurrentLevel = math.max(1, self.data.level or 1)

	local track = {}
	for level, definition in pairs(UnlockDefinitions) do
		local entry = {
			level = level,
			id = definition.id,
			name = definition.name,
			description = definition.description,
			UnlockTags = definition.unlockTags,
			effects = definition.effects,
			unlocked = CurrentLevel >= level,
		}
		entry.totalXpRequired = self:GetTotalXpForLevel(level)
		local remaining = entry.totalXpRequired - CurrentTotal
		entry.remainingXp = math.max(0, math.floor(remaining + 0.5))
		table.insert(track, entry)
	end

	table.sort(track, function(a, b)
		if a.level == b.level then
			return (a.id or "") < (b.id or "")
		end
		return a.level < b.level
	end)

	return track
end

local function BuildSnapshot(self, TotalXP)
	local level, XpIntoLevel, XpForNext = self:GetProgressForTotal(TotalXP)
	return {
		total = math.floor(TotalXP + 0.5),
		level = level,
		XpIntoLevel = XpIntoLevel,
		XpForNext = XpForNext,
	}
end

local function CalculateRunGain(RunStats)
	local apples = math.max(0, math.floor(RunStats.apples or 0))
	local score = math.max(0, math.floor(RunStats.score or 0))
	local BonusXP = math.max(0, math.floor(RunStats.bonusXP or 0))

	local FruitPoints = apples * XP_PER_FRUIT
	local ScoreBonus = 0
	if SCORE_BONUS_DIVISOR > 0 then
		ScoreBonus = math.min(SCORE_BONUS_MAX, math.floor(score / SCORE_BONUS_DIVISOR))
	end

	local total = FruitPoints + BonusXP
	return {
		apples = apples,
		FruitPoints = FruitPoints,
		ScoreBonus = ScoreBonus,
		BonusXP = BonusXP,
		total = total,
	}
end

local function PrepareUnlocks(LevelUps)
	local unlocks = {}
	for _, level in ipairs(LevelUps) do
		local info = UnlockDefinitions[level]
		if info then
			unlocks[#unlocks + 1] = {
				level = level,
				name = info.name,
				description = info.description,
			}
		else
			unlocks[#unlocks + 1] = {
				level = level,
				name = string.format("Meta Reward %d", level),
				description = "Placeholder: Future reward details coming soon.",
			}
		end
	end
	return unlocks
end

local function PrepareMilestones(StartTotal, EndTotal)
	local milestones = {}
	for _, threshold in ipairs(MilestoneThresholds) do
		if StartTotal < threshold and EndTotal >= threshold then
			milestones[#milestones + 1] = {
				threshold = threshold,
			}
		end
	end
	return milestones
end

function MetaProgression:GetState()
	self:_ensureLoaded()
	local snapshot = BuildSnapshot(self, self.data.TotalExperience)
	return {
		TotalExperience = snapshot.total,
		level = snapshot.level,
		XpIntoLevel = snapshot.xpIntoLevel,
		XpForNext = snapshot.xpForNext,
	}
end

function MetaProgression:GrantRunPoints(RunStats)
	self:_ensureLoaded()
	RunStats = RunStats or {}

	local gain = CalculateRunGain(RunStats)
	local StartTotal = self.data.TotalExperience or 0
	local StartSnapshot = BuildSnapshot(self, StartTotal)

	local GainedTotal = math.max(0, (gain.fruitPoints or 0) + (gain.bonusXP or 0))
	local EndTotal = StartTotal + GainedTotal
	local EndSnapshot = BuildSnapshot(self, EndTotal)

	local LevelUps = {}
	for level = StartSnapshot.level + 1, EndSnapshot.level do
		LevelUps[#LevelUps + 1] = level
		self.data.UnlockHistory[level] = true
	end

	self.data.TotalExperience = EndTotal
	self.data.level = EndSnapshot.level
	self:_save()

	local OkCosmetics, Cosmetics = pcall(require, "snakecosmetics")
	if OkCosmetics and Cosmetics and Cosmetics.SyncMetaLevel then
		local OkSync, err = pcall(function()
			Cosmetics:SyncMetaLevel(EndSnapshot.level, { LevelUps = CopyTable(LevelUps) })
		end)
		if not OkSync then
			print("[metaprogression] failed to sync cosmetics:", err)
		end
	end

	local unlocks = PrepareUnlocks(LevelUps)
	local milestones = PrepareMilestones(StartTotal, EndTotal)

	return {
		apples = gain.apples,
		gained = GainedTotal,
		breakdown = gain,
		start = StartSnapshot,
		result = EndSnapshot,
		LevelUps = LevelUps,
		unlocks = unlocks,
		milestones = milestones,
		EventsCount = #LevelUps + #unlocks + #milestones,
	}
end

return MetaProgression
