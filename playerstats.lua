local DataSchemas = require("dataschemas")

local PlayerStats = {}

local SaveFile = "savedstats.lua"
local PlayerSchema = DataSchemas.PlayerStats

PlayerStats.data = {}

local function ApplySchemaDefaults(store)
	if type(store.data) ~= "table" then
		store.data = {}
	end

	DataSchemas.ApplyDefaults(PlayerSchema, store.data)
end

local function FreshData()
	return DataSchemas.CollectDefaults(PlayerSchema)
end

function PlayerStats:load()
	if love.filesystem.getInfo(SaveFile) then
		local success, chunk = pcall(love.filesystem.load, SaveFile)
		if success and chunk then
			local ok, saved = pcall(chunk)
			if ok and type(saved) == "table" then
				self.data = saved
			end
		end
	end

	ApplySchemaDefaults(self)
end

function PlayerStats:save()
	local lines = { "return {\n" }

	for k, v in pairs(self.data) do
		local VType = type(v)
		if VType == "number" then
			table.insert(lines, string.format("    [%q] = %s,\n", k, tostring(v)))
		elseif VType == "string" then
			table.insert(lines, string.format("    [%q] = %q,\n", k, v))
		elseif VType == "boolean" then
			table.insert(lines, string.format("    [%q] = %s,\n", k, tostring(v)))
		end
		-- Skip nested tables or unsupported types
	end

	table.insert(lines, "}\n")
	love.filesystem.write(SaveFile, table.concat(lines))
end

function PlayerStats:add(stat, amount)
	self.data[stat] = (self.data[stat] or 0) + amount
	self:save()
end

function PlayerStats:UpdateMax(stat, value)
	if not self.data[stat] or value > self.data[stat] then
		self.data[stat] = value
		self:save()
	end
end

function PlayerStats:UpdateMin(stat, value)
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

function PlayerStats:reset(SaveAfter)
	self.data = FreshData()

	ApplySchemaDefaults(self)

	if SaveAfter ~= false then
		self:save()
	end
end

return PlayerStats
