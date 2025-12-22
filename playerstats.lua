local DataSchemas = require("dataschemas")
local DailyProgress = require("dailyprogress")
local Serialization = require("serialize")

local PlayerStats = {}

local saveFile = "savedstats.lua"
local playerSchema = DataSchemas.playerStats

PlayerStats.data = {}

local legacyDailyFields = {
	dailyChallengesCompleted = true,
	dailyChallengeStreak = true,
	dailyChallengeBestStreak = true,
	dailyChallengeLastCompletionDay = true,
}

local function migrateLegacyDailyData(store)
	if type(store.data) ~= "table" then
		return
	end

	if DailyProgress and DailyProgress.importLegacyData then
		DailyProgress:importLegacyData(store.data)
	end
end

local function purgeLegacyDailyData(store)
	if type(store.data) ~= "table" then
		return
	end

	for key in pairs(store.data) do
		local isLegacyKey = legacyDailyFields[key]
		or (type(key) == "string" and key:find("^dailyChallenge:"))

		if isLegacyKey then
			store.data[key] = nil
		end
	end
end

local function applySchemaDefaults(store)
	if type(store.data) ~= "table" then
		store.data = {}
	end

	DataSchemas.applyDefaults(playerSchema, store.data)
end

local function freshData()
	return DataSchemas.collectDefaults(playerSchema)
end

function PlayerStats:load()
	if love.filesystem.getInfo(saveFile) then
		local saved = Serialization.loadTable(saveFile)
		if type(saved) == "table" then
			self.data = saved
		end
	end

	migrateLegacyDailyData(self)
	purgeLegacyDailyData(self)

	applySchemaDefaults(self)
end

function PlayerStats:save()
	local snapshot = {}
	for key, value in pairs(self.data) do
		local valueType = type(value)
		if valueType == "number" or valueType == "string" or valueType == "boolean" then
			snapshot[key] = value
		end
	end

	Serialization.saveTable(saveFile, snapshot, {sortKeys = true})
end

function PlayerStats:add(stat, amount)
	self.data[stat] = (self.data[stat] or 0) + amount
	self:save()
end

function PlayerStats:updateMax(stat, value)
	if not self.data[stat] or value > self.data[stat] then
		self.data[stat] = value
		self:save()
	end
end

function PlayerStats:updateMin(stat, value)
	if value == nil then
		return
	end

	if self.data[stat] == nil or value < self.data[stat] then
		self.data[stat] = value
		self:save()
	end
end

function PlayerStats:set(stat, value)
	self.data[stat] = value
	self:save()
end

function PlayerStats:get(stat)
	return self.data[stat] or 0
end

function PlayerStats:reset(saveAfter)
	self.data = freshData()

	applySchemaDefaults(self)

	if saveAfter ~= false then
		self:save()
	end
end

return PlayerStats
