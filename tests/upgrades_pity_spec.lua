local function makeStub()
    local stub = {}
    local mt = {}
    function mt:__index(key)
        local value = makeStub()
        rawset(stub, key, value)
        return value
    end
    function mt:__call()
        return
    end
    return setmetatable(stub, mt)
end

local function stubModule(name, value)
    package.preload[name] = function()
        return value
    end
end

local function stubCallableModule(name)
    stubModule(name, makeStub())
end

stubCallableModule("face")
stubCallableModule("snake")
stubCallableModule("rocks")
stubCallableModule("saws")
stubCallableModule("lasers")
stubCallableModule("score")
stubCallableModule("ui")
stubCallableModule("arena")
stubCallableModule("snakeutils")
stubCallableModule("playerstats")
stubCallableModule("upgradevisuals")

stubModule("localization", {
    get = function(_, key)
        return key
    end,
})

stubModule("metaprogression", {
    isTagUnlocked = function(_, _)
        return true
    end,
})

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepcopy(v)
    end
    return copy
end

stubModule("upgradehelpers", {
    getUpgradeString = function()
        return ""
    end,
    rarities = {
        common = {},
        uncommon = {},
        rare = {},
        epic = {},
        legendary = {},
    },
    deepcopy = deepcopy,
    defaultEffects = {},
    celebrateUpgrade = function() end,
    getEventPosition = function()
        return 0, 0
    end,
})

stubModule("dataschemas", {
    upgradeDefinition = {},
    applyDefaults = function(_, _)
    end,
    validate = function(_, _, _)
    end,
})

love = {
    math = {
        random = function(min, max)
            if min and max then
                return min
            end
            return 0.5
        end,
    },
}

local Upgrades = require("upgrades")

local originalCanOffer = Upgrades.canOffer
local originalRunState = Upgrades.runState

Upgrades.canOffer = function(self, upgrade, _, allowDuplicates)
    if upgrade.rarity == "rare" or upgrade.rarity == "legendary" then
        return allowDuplicates
    end
    return true
end

Upgrades.runState = {
    counters = {
        shopBadLuck = 0,
        legendaryBadLuck = 99,
    },
    effects = {
        shopGuaranteedRare = true,
    },
}

local cards = Upgrades:getRandom(3, {})

local hasRare = false
local hasLegendary = false
for _, card in ipairs(cards) do
    if card.rarity == "rare" then
        hasRare = true
    elseif card.rarity == "legendary" then
        hasLegendary = true
    end
end

assert(hasRare, "Expected rare pity to inject a rare upgrade")
assert(hasLegendary, "Expected legendary pity to inject a legendary upgrade")

Upgrades.canOffer = originalCanOffer
Upgrades.runState = originalRunState
