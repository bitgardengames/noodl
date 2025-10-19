local SessionStats = {}
SessionStats.data = {}

function SessionStats:reset()
	self.data = {}
end

function SessionStats:add(stat, amount)
	self.data[stat] = (self.data[stat] or 0) + amount
end

function SessionStats:updateMax(stat, value)
	if not self.data[stat] or value > self.data[stat] then
		self.data[stat] = value
	end
end

function SessionStats:updateMin(stat, value)
	if value == nil then
		return
	end

	local current = self.data[stat]
	if current == nil or value < current then
		self.data[stat] = value
	end
end

function SessionStats:set(stat, value)
	self.data[stat] = value
end

function SessionStats:get(stat, defaultValue)
	local value = self.data[stat]
	if value == nil then
		if defaultValue ~= nil then
			return defaultValue
		end
		return 0
	end
	return value
end

return SessionStats
