local DataSchemas = require("dataschemas")

local PlayerStats = {}

local saveFile = "savedstats.lua"
local playerSchema = DataSchemas.playerStats

PlayerStats.data = {}

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
		local success, chunk = pcall(love.filesystem.load, saveFile)
		if success and chunk then
			local ok, saved = pcall(chunk)
			if ok and type(saved) == "table" then
				self.data = saved
			end
		end
	end

	applySchemaDefaults(self)
end

function PlayerStats:save()
	local lines = {"return {\n"}

	for k, v in pairs(self.data) do
		local vType = type(v)
		if vType == "number" then
			table.insert(lines, string.format("    [%q] = %s,\n", k, tostring(v)))
		elseif vType == "string" then
			table.insert(lines, string.format("    [%q] = %q,\n", k, v))
		elseif vType == "boolean" then
			table.insert(lines, string.format("    [%q] = %s,\n", k, tostring(v)))
		end
		-- Skip nested tables or unsupported types
	end

	table.insert(lines, "}\n")
	love.filesystem.write(saveFile, table.concat(lines))
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
