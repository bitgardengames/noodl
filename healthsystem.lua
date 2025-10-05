local HealthSystem = {}
HealthSystem.__index = HealthSystem

local function clampToInt(value)
    if value == nil then
        return 0
    end

    return math.max(0, math.floor((value or 0) + 0.0001))
end

function HealthSystem.new(maxHealth)
    local instance = setmetatable({}, HealthSystem)
    instance.criticalThreshold = 1
    instance:reset(maxHealth)
    return instance
end

function HealthSystem:reset(maxHealth)
    if maxHealth ~= nil then
        self.max = clampToInt(maxHealth)
        if self.max <= 0 then
            self.max = 1
        end
    else
        self.max = self.max and clampToInt(self.max) or 1
    end

    self.current = clampToInt(self.max or 1)
    self.damageTaken = 0
    self.totalHealed = 0

    return self.current
end

function HealthSystem:setMax(maxHealth)
    self.max = clampToInt(maxHealth)
    if self.max <= 0 then
        self.max = 1
    end

    if self.current == nil then
        self.current = self.max
    else
        self.current = math.min(self.current, self.max)
    end

    return self.current
end

function HealthSystem:setCurrent(value)
    value = clampToInt(value)
    if self.max then
        value = math.min(value, self.max)
    end

    self.current = value
    return self.current
end

function HealthSystem:getCurrent()
    return self.current or 0
end

function HealthSystem:getMax()
    return self.max or 0
end

function HealthSystem:damage(amount)
    local damage = clampToInt(amount)
    if damage <= 0 then
        return 0, self.current or 0, (self.current or 0) > 0
    end

    local previous = self.current or 0
    local updated = math.max(0, previous - damage)
    self.current = updated
    local applied = previous - updated
    self.damageTaken = (self.damageTaken or 0) + applied

    return applied, updated, updated > 0
end

function HealthSystem:heal(amount)
    local heal = clampToInt(amount)
    if heal <= 0 then
        return 0, 0
    end

    local previous = self.current or 0
    local cap = self.max
    local updated

    if cap and cap > 0 then
        updated = math.min(cap, previous + heal)
    else
        updated = previous + heal
    end

    self.current = updated
    local restored = math.max(0, updated - previous)
    local overflow = heal - restored
    if overflow < 0 then
        overflow = 0
    end

    self.totalHealed = (self.totalHealed or 0) + restored

    return restored, overflow
end

function HealthSystem:isCritical()
    local threshold = self.criticalThreshold or 1
    local current = self.current or 0
    if threshold <= 0 then
        return current <= 0
    end

    return current > 0 and current <= threshold
end

return HealthSystem
