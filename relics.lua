local Upgrades = require("upgrades")
local Score = require("score")
local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local FruitEvents = require("fruitevents")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local UI = require("ui")
local SessionStats = require("sessionstats")

local Relics = {}

local rarityInfo = {
    common = {
        label = "Common",
        weight = 80,
        color = {0.7, 0.9, 0.7, 1},
    },
    uncommon = {
        label = "Uncommon",
        weight = 45,
        color = {0.55, 0.78, 0.88, 1},
    },
    rare = {
        label = "Rare",
        weight = 24,
        color = {0.88, 0.66, 0.35, 1},
    },
    epic = {
        label = "Epic",
        weight = 10,
        color = {0.95, 0.55, 0.8, 1},
    },
}

local function getState(self)
    if not self.state then
        self.state = {
            acquired = {},
            order = {},
            floorClaims = {},
            schedule = {},
            counters = {},
            floorStartHandlers = {},
        }
    end
    return self.state
end

local function buildVaultSchedule()
    local schedule = {}
    local floor = 2
    while floor <= 14 do
        table.insert(schedule, floor)
        floor = floor + love.math.random(1, 2)
    end
    return schedule
end

local function rarityColor(info)
    info = info or rarityInfo.common
    return { info.color[1], info.color[2], info.color[3], info.color[4] }
end

local function addFloatingBanner(text, color)
    local hx, hy = Snake:getHead()
    if hx and hy then
        FloatingText:add(text, hx, hy - 68, color or {1, 1, 1, 1}, 1.25, 48)
    end
end

local relicPool = {
    {
        id = "evergreen_totem",
        name = "Evergreen Totem",
        desc = "Floors begin with a crash shield and the saws hesitate.",
        summary = "Start every floor with a crash shield.",
        rarity = "common",
        minFloor = 2,
        onFloorStart = function(_, floor, context)
            Snake:addCrashShields(1)
            if Saws and Saws.stall then
                Saws:stall(0.45)
            end
            addFloatingBanner("Evergreen Ward", {0.55, 0.92, 0.62, 1})
        end,
    },
    {
        id = "ember_core",
        name = "Ember Core",
        desc = "Every fourth fruit ignites, stalling saws and shattering rock.",
        summary = "Every 4 fruits trigger a fiery blast.",
        rarity = "uncommon",
        minFloor = 2,
        onAcquire = function(self, state)
            Upgrades:addEventHandler("fruitCollected", function(data)
                local relicState = getState(self)
                relicState.counters.emberCore = (relicState.counters.emberCore or 0) + 1
                if relicState.counters.emberCore < 4 then
                    return
                end
                relicState.counters.emberCore = relicState.counters.emberCore - 4
                local x = data and data.x or 0
                local y = data and data.y or 0
                if Saws and Saws.stall then
                    Saws:stall(1.25)
                end
                if Rocks and Rocks.shatterNearest then
                    Rocks:shatterNearest(x, y, 2)
                end
                Particles:spawnBurst(x, y, {
                    count = 26,
                    speed = 150,
                    life = 0.55,
                    size = 5,
                    spread = math.pi * 2,
                    color = {1, 0.55, 0.25, 1},
                    fadeTo = 0,
                })
                FloatingText:add("Ignition!", x, y - 62, {1, 0.6, 0.28, 1}, 1.2, 54)
            end)
        end,
    },
    {
        id = "echo_flask",
        name = "Echo Flask",
        desc = "Combos of three or more pour extra score and time into the chain.",
        summary = "Big combos grant bonus score and combo time.",
        rarity = "uncommon",
        minFloor = 3,
        onAcquire = function(self)
            Upgrades:addEventHandler("fruitCollected", function(data)
                if not data then return end
                local combo = data.combo or 0
                if combo < 3 then return end
                local x = data.x or 0
                local y = data.y or 0
                local bonus = 4 + math.floor((combo - 3) * 1.5)
                Score:addBonus(bonus)
                FruitEvents.boostComboTimer(0.6)
                FloatingText:add("Echo +" .. tostring(bonus), x, y - 70, {0.75, 0.85, 1.0, 1}, 1.1, 46)
            end)
        end,
    },
    {
        id = "glacial_prism",
        name = "Glacial Prism",
        desc = "Saw blades slow and linger after fruit, calming the arena.",
        summary = "Saws slow down and stall longer after fruit.",
        rarity = "rare",
        minFloor = 4,
        multipliers = {
            sawSpeedMult = 0.85,
            sawSpinMult = 0.9,
            rockSpawnMult = 0.9,
        },
        bonuses = {
            sawStall = 0.2,
        },
        onAcquire = function()
            addFloatingBanner("Prism Chill", {0.75, 0.9, 1, 1})
        end,
    },
    {
        id = "storm_banner",
        name = "Storm Banner",
        desc = "Crash shields crackle, stunning saws and raining shards of score.",
        summary = "Shields stun saws and grant bonus score.",
        rarity = "rare",
        minFloor = 5,
        onAcquire = function(self)
            Upgrades:addEventHandler("shieldConsumed", function(data)
                local x = data and data.x or 0
                local y = data and data.y or 0
                if Saws and Saws.stall then
                    Saws:stall(1.0)
                end
                local bonus = 8 + (#(getState(self).order) * 2)
                Score:addBonus(bonus)
                FloatingText:add("Storm Shield +" .. tostring(bonus), x, y - 58, {0.7, 0.9, 1.0, 1}, 1.0, 48)
                Particles:spawnBurst(x, y, {
                    count = 18,
                    speed = 120,
                    life = 0.5,
                    size = 4,
                    spread = math.pi * 2,
                    color = {0.65, 0.85, 1, 1},
                    fadeTo = 0,
                })
            end)
        end,
    },
    {
        id = "celestial_lens",
        name = "Celestial Lens",
        desc = "The combo timer stretches and fruit reveal glimpses of fate.",
        summary = "Combo window +0.75; first fruit each floor gives bonus score.",
        rarity = "epic",
        minFloor = 6,
        bonuses = {
            comboWindowBonus = 0.75,
        },
        onFloorStart = function(self, floor)
            local relicState = getState(self)
            relicState.counters.floorFruit = relicState.counters.floorFruit or {}
            relicState.counters.floorFruit[floor] = false
        end,
        onAcquire = function(self)
            Upgrades:addEventHandler("fruitCollected", function(data)
                local state = getState(self)
                local floor = state.currentFloor or 1
                state.counters.floorFruit = state.counters.floorFruit or {}
                if state.counters.floorFruit[floor] then return end
                state.counters.floorFruit[floor] = true
                local x = data and data.x or 0
                local y = data and data.y or 0
                local reward = 12 + floor * 2
                Score:addBonus(reward)
                FloatingText:add("Starlit Tithe +" .. tostring(reward), x, y - 76, {0.9, 0.8, 1.0, 1}, 1.3, 52)
            end)
        end,
    },
}

local poolById = {}
for _, relic in ipairs(relicPool) do
    poolById[relic.id] = relic
end

local function ensureSchedule(self)
    local state = getState(self)
    if #state.schedule == 0 then
        state.schedule = buildVaultSchedule()
    end
    return state.schedule
end

local function adjustEffects(mult, bonuses)
    local runState = Upgrades:getRunState()
    if not runState then return end
    local effects = runState.effects
    if mult then
        for key, value in pairs(mult) do
            if effects[key] == nil or effects[key] == 0 then
                effects[key] = value
            else
                effects[key] = effects[key] * value
            end
        end
    end
    if bonuses then
        for key, value in pairs(bonuses) do
            effects[key] = (effects[key] or 0) + value
        end
    end
    Upgrades:applyPersistentEffects(true)
end

local function getAvailableRelics(self, floor)
    local state = getState(self)
    local list = {}
    for _, relic in ipairs(relicPool) do
        if not state.acquired[relic.id] then
            if not relic.minFloor or relic.minFloor <= floor then
                table.insert(list, relic)
            end
        end
    end
    return list
end

local function weightedSample(list)
    local total = 0
    for _, relic in ipairs(list) do
        local rarity = rarityInfo[relic.rarity or "common"] or rarityInfo.common
        total = total + (relic.weight or rarity.weight or 1)
    end
    if total <= 0 then return nil end
    local draw = love.math.random() * total
    local running = 0
    for index, relic in ipairs(list) do
        local rarity = rarityInfo[relic.rarity or "common"] or rarityInfo.common
        running = running + (relic.weight or rarity.weight or 1)
        if draw <= running then
            table.remove(list, index)
            return relic
        end
    end
    return table.remove(list)
end

local function nextVaultFloor(self, currentFloor)
    local schedule = ensureSchedule(self)
    local state = getState(self)
    for _, floor in ipairs(schedule) do
        if not state.floorClaims[floor] and floor >= (currentFloor or 1) then
            return floor
        end
    end
    return nil
end

function Relics:beginRun()
    self.state = nil
    local state = getState(self)
    state.schedule = buildVaultSchedule()
    state.currentFloor = 1
    state.highlightId = nil
    state.pendingFloor = nil
    SessionStats:set("relicsClaimed", 0)
    self:updateUI(1)
end

function Relics:getState()
    return getState(self)
end

function Relics:hasRelic(id)
    local state = getState(self)
    return state.acquired[id] == true
end

function Relics:getRelic(id)
    return poolById[id]
end

function Relics:getRelicCount()
    local state = getState(self)
    return #state.order
end

function Relics:modifyFloorContext(context, floor)
    return context
end

function Relics:shouldOfferVault(floor)
    if not floor or floor <= 1 then return false end
    local state = getState(self)
    if state.floorClaims[floor] then return false end
    if not nextVaultFloor(self, floor) or nextVaultFloor(self, floor) ~= floor then
        return false
    end
    local available = getAvailableRelics(self, floor)
    return #available > 0
end

function Relics:prepareVault(floor)
    local state = getState(self)
    state.pendingFloor = floor
    local available = getAvailableRelics(self, floor)
    if #available == 0 then
        state.floorClaims[floor] = true
        return nil
    end
    local selection = {}
    local poolCopy = {}
    for _, relic in ipairs(available) do
        table.insert(poolCopy, relic)
    end
    for _ = 1, math.min(3, #poolCopy) do
        local relic = weightedSample(poolCopy)
        if relic then
            table.insert(selection, {
                relic = relic,
                name = relic.name,
                desc = relic.desc,
                rarity = relic.rarity or "common",
                rarityInfo = rarityInfo[relic.rarity or "common"] or rarityInfo.common,
            })
        end
    end
    if #selection == 0 then
        state.floorClaims[floor] = true
        return nil
    end
    return selection
end

function Relics:getSkipReward(floor)
    floor = floor or getState(self).currentFloor or 1
    local claimed = self:getRelicCount()
    return 12 + floor * 3 + claimed * 4
end

function Relics:skipVault(floor)
    local state = getState(self)
    local reward = self:getSkipReward(floor)
    state.floorClaims[floor] = true
    state.pendingFloor = nil
    Score:addBonus(reward)
    addFloatingBanner("Vault Banked +" .. tostring(reward), {1, 0.8, 0.3, 1})
    self:updateUI(state.currentFloor or floor)
    return reward
end

function Relics:claim(relic, floor)
    if not relic then return end
    local state = getState(self)
    if state.acquired[relic.id] then return end
    state.acquired[relic.id] = true
    table.insert(state.order, relic)
    state.highlightId = relic.id
    state.floorClaims[floor or state.pendingFloor or state.currentFloor or 1] = true
    state.pendingFloor = nil
    SessionStats:add("relicsClaimed", 1)
    if relic.bonuses or relic.multipliers then
        adjustEffects(relic.multipliers, relic.bonuses)
    end
    if relic.onAcquire then
        relic.onAcquire(self, state)
    end
    if relic.onFloorStart then
        table.insert(state.floorStartHandlers, relic.onFloorStart)
    end
    self:updateUI(state.currentFloor or floor)
end

function Relics:onFloorStart(floor, context)
    local state = getState(self)
    state.currentFloor = floor
    if state.floorStartHandlers then
        for _, handler in ipairs(state.floorStartHandlers) do
            handler(self, floor, context)
        end
    end
    self:updateUI(floor)
end

function Relics:updateUI(currentFloor)
    local state = getState(self)
    local display = { items = {}, nextVault = nextVaultFloor(self, currentFloor), nextSkip = nil }
    for _, relic in ipairs(state.order) do
        local info = rarityInfo[relic.rarity or "common"] or rarityInfo.common
        table.insert(display.items, {
            id = relic.id,
            name = relic.name,
            summary = relic.summary or relic.desc,
            rarity = info.label,
            color = rarityColor(info),
            highlight = (state.highlightId == relic.id),
        })
    end
    if display.nextVault then
        display.nextSkip = self:getSkipReward(display.nextVault)
    end
    if UI and UI.setRelics then
        UI:setRelics(display)
    end
end

return Relics
