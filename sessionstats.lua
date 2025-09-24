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

function SessionStats:set(stat, value)
    self.data[stat] = value
end

function SessionStats:get(stat)
    return self.data[stat] or 0
end

return SessionStats