local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")

local FruitWallet = {}

local META_PREFIX = "fruitMeta_"
local RUN_PREFIX = "fruitMetaGain_"

local runGains = {}
local catalog = {}

local function copyColor(color)
    if not color then
        return {1, 1, 1, 1}
    end
    return {color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1}
end

local function registerFruitType(fruitType)
    if not fruitType then return end
    local reward = fruitType.metaReward
    if not reward then return end

    local key = reward.key or fruitType.id
    if not key then return end

    if not catalog[key] then
        local label = reward.name or reward.label or (fruitType.name .. " Token")
        catalog[key] = {
            key = key,
            label = label,
            color = copyColor(reward.color or fruitType.color),
        }
    end
end

function FruitWallet:registerFruits(fruitTypes)
    if type(fruitTypes) ~= "table" then return end
    for _, info in ipairs(fruitTypes) do
        registerFruitType(info)
    end
end

function FruitWallet:resetRun()
    runGains = {}
end

function FruitWallet:addRunGain(key, amount)
    if not key then return end
    amount = math.floor(amount or 0)
    if amount == 0 then return runGains[key] end

    runGains[key] = (runGains[key] or 0) + amount
    return runGains[key]
end

function FruitWallet:grantMeta(fruitType)
    if not fruitType then return nil end
    local reward = fruitType.metaReward
    if not reward then return nil end

    registerFruitType(fruitType)

    local key = reward.key or fruitType.id
    if not key then return nil end

    local amount = math.floor(reward.amount or 0)
    if amount <= 0 then return nil end

    local runTotal = self:addRunGain(key, amount)
    SessionStats:add(RUN_PREFIX .. key, amount)
    PlayerStats:add(META_PREFIX .. key, amount)
    local lifetime = PlayerStats:get(META_PREFIX .. key)

    return {
        key = key,
        amount = amount,
        runTotal = runTotal or amount,
        lifetime = lifetime or amount,
        label = reward.label,
        showTotal = reward.showTotal,
        color = reward.color,
        totalColor = reward.totalColor,
    }
end

function FruitWallet:getRunGain(key)
    return runGains[key] or 0
end

function FruitWallet:getLifetime(key)
    return PlayerStats:get(META_PREFIX .. key)
end

function FruitWallet:getRunSummary()
    local summary = {}
    for key, info in pairs(catalog) do
        local gained = runGains[key] or SessionStats:get(RUN_PREFIX .. key) or 0
        local total = PlayerStats:get(META_PREFIX .. key)
        if gained > 0 or total > 0 then
            summary[#summary + 1] = {
                key = key,
                label = info.label,
                color = copyColor(info.color),
                gained = gained,
                total = total,
            }
        end
    end

    table.sort(summary, function(a, b)
        return a.label < b.label
    end)

    return summary
end

return FruitWallet
