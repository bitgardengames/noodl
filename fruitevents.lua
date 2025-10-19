local Fruit = require("fruit")
local Audio = require("audio")
local Snake = require("snake")
local Face = require("face")
local Score = require("score")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Rocks = require("rocks")
local Saws = require("saws")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local UI = require("ui")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local Theme = require("theme")
local Achievements = require("achievements")
local Upgrades = require("upgrades")
local Shaders = require("shaders")

local FruitEvents = {}

local DEFAULT_COMBO_WINDOW = 2.25

local comboState = {
    count = 0,
    timer = 0,
    window = DEFAULT_COMBO_WINDOW,
    baseWindow = DEFAULT_COMBO_WINDOW,
    baseOverride = DEFAULT_COMBO_WINDOW,
    best = 0,
}

Achievements:registerStateProvider(function()
    return {
        currentCombo = comboState.count or 0,
        bestComboStreak = math.max(comboState.best or 0, comboState.count or 0),
    }
end)

local function getUpgradeEffect(name)
    if Upgrades and Upgrades.getEffect then
        return Upgrades:getEffect(name)
    end
end

local function getBaseWindow()
    local override = comboState.baseOverride or DEFAULT_COMBO_WINDOW
    local bonus = getUpgradeEffect("comboWindowBonus") or 0
    return math.max(0.5, override + bonus)
end

local function updateComboWindow()
    comboState.baseWindow = getBaseWindow()
    comboState.window = math.max(0.75, comboState.baseWindow)
    comboState.timer = math.min(comboState.timer or 0, comboState.window)
end

local function syncComboToUI()
    updateComboWindow()
    UI:setCombo(
    comboState.count or 0,
    comboState.timer or 0,
    comboState.window or DEFAULT_COMBO_WINDOW
    )
end

local function applyComboReward(x, y)
    if comboState.timer > 0 then
        comboState.count = comboState.count + 1
    else
        comboState.count = 1
    end

    comboState.timer = comboState.window
    local comboCount = comboState.count
    comboState.best = math.max(comboState.best or 0, comboCount)
    local bestStreak = comboState.best or comboCount or 0
    PlayerStats:updateMax("bestComboStreak", bestStreak)
    SessionStats:updateMax("bestComboStreak", bestStreak)
    if comboCount >= 2 then
        SessionStats:add("combosTriggered", 1)
    end
    Shaders.notify("comboChanged", {
        combo = comboCount,
        timer = comboState.timer or 0,
        window = comboState.window or DEFAULT_COMBO_WINDOW,
    })
    syncComboToUI()

    if comboCount < 2 then
        return
    end

    local burstColor = {1, 0.82, 0.3, 1}
    local baseBonus = math.min((comboCount - 1) * 2, 10)
    local multiplier = Score.getComboBonusMultiplier and Score:getComboBonusMultiplier() or 1
    local scaledCombo = math.floor(baseBonus * multiplier + 0.5)

    local extraBonus = 0
    if Upgrades and Upgrades.getComboBonus then
        extraBonus = Upgrades:getComboBonus(comboCount) or 0
    end

    local totalBonus = math.max(0, scaledCombo + extraBonus)

    if totalBonus > 0 then
        Score:addBonus(totalBonus)

        local summary = string.format("Combo Bonus +%d", totalBonus)
        FloatingText:add(summary, x, y - 74, {1, 0.95, 0.6, 1}, 1.3, 48)
        Shaders.notify("specialEvent", {
            type = "combo",
            strength = 0.38,
            color = {1, 0.9, 0.5, 1},
        })
    end

    Particles:spawnBurst(x, y, {
        count = love.math.random(10, 14) + comboCount,
        speed = 90 + comboCount * 12,
        life = 0.6,
        size = 4,
        color = burstColor,
        spread = math.pi * 2,
        gravity = 30,
        drag = 2.5,
        fadeTo = 0
    })
end

local function addFloatingText(label, x, y, color, duration, size)
    if not label or label == "" then return end
    FloatingText:add(label, x, y, color or Theme.textColor, duration or 1.1, size or 42)
end

local function applyRunRewards(fruitType, x, y)
    if not fruitType then return end

    local rewards = fruitType.runRewards or fruitType.runReward
    if not rewards then return end

    if rewards.type then
        rewards = { rewards }
    end

    local offset = 74
    for _, reward in ipairs(rewards) do
        local rewardType = reward.type
        if rewardType == "comboTime" then
            local amount = reward.amount or reward.duration or 0
            if amount and amount ~= 0 then
                FruitEvents.boostComboTimer(amount)
                if reward.label then
                    addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
                    offset = offset + 22
                end
                Shaders.notify("specialEvent", {
                    type = "comboBoost",
                    strength = 0.24,
                    color = reward.color,
                })
            end
        elseif rewardType == "stallSaws" then
            local duration = reward.duration or reward.amount or 0
            if duration and duration > 0 then
                Saws:stall(duration)
                if reward.label then
                    addFloatingText(reward.label, x, y - offset, reward.color or {0.8, 0.9, 1, 1}, reward.duration, reward.size)
                    offset = offset + 22
                end
                Shaders.notify("specialEvent", {
                    type = "stallSaws",
                    strength = 0.36,
                    color = reward.color or {0.72, 0.85, 1, 1},
                })
            end
        elseif rewardType == "shield" then
            local shields = math.floor(reward.amount or 0)
            if shields ~= 0 then
                Snake:addShields(shields)
                if reward.label and reward.showLabel ~= false then
                    addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
                    offset = offset + 22
                end
                Shaders.notify("specialEvent", {
                    type = "shield",
                    strength = 0.48,
                    color = reward.color or {0.72, 1, 0.82, 1},
                })
            end
        elseif rewardType == "scoreBonus" then
            local bonus = math.floor(reward.amount or 0)
            if bonus ~= 0 then
                Score:addBonus(bonus)
                if reward.label then
                    addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
                    offset = offset + 22
                end
                Shaders.notify("specialEvent", {
                    type = "score",
                    strength = 0.32,
                    color = reward.color or {1, 0.78, 0.45, 1},
                })
            end
        end
    end
end

function FruitEvents.reset()
    comboState.count = 0
    comboState.timer = 0
    comboState.baseOverride = DEFAULT_COMBO_WINDOW
    comboState.baseWindow = DEFAULT_COMBO_WINDOW
    comboState.window = DEFAULT_COMBO_WINDOW
    comboState.best = 0
    syncComboToUI()
    Shaders.notify("comboLost", { reason = "reset" })
end

function FruitEvents:getDefaultComboWindow()
    return DEFAULT_COMBO_WINDOW
end

function FruitEvents:setComboWindow(window)
    comboState.baseOverride = math.max(0.5, window or DEFAULT_COMBO_WINDOW)
    syncComboToUI()
end

function FruitEvents.update(dt)
    updateComboWindow()
    if comboState.timer > 0 then
        comboState.timer = math.max(0, comboState.timer - dt)

        if comboState.timer == 0 then
            comboState.count = 0
            Shaders.notify("comboLost", { reason = "timeout" })
        end

        syncComboToUI()
    end
end

function FruitEvents.getComboCount()
    return comboState.count or 0
end

function FruitEvents.boostComboTimer(amount)
    if not amount or amount <= 0 then return end
    updateComboWindow()
    comboState.timer = math.min(comboState.window or DEFAULT_COMBO_WINDOW, (comboState.timer or 0) + amount)
    syncComboToUI()
    if (comboState.count or 0) >= 2 then
        Shaders.notify("specialEvent", {
            type = "comboBoost",
            strength = 0.22,
        })
    end
end

function FruitEvents.handleConsumption(x, y)
    local points = Fruit:getPoints()
    local name = Fruit:getTypeName()
    local fruitType = Fruit:getType()
    local col, row = Fruit:getTile()

    Snake:grow()
    Snake:markFruitSegment(x, y)

    Face:set("happy", 2)
    FloatingText:add("+" .. tostring(points), x, y, Theme.textColor, 1.0, 40)
    Score:increase(points)
    Audio:playSound("fruit")
    SessionStats:add("applesEaten", 1)
    if Snake.onFruitCollected then
        Snake:onFruitCollected()
    end

    if col and row then
        SnakeUtils.setOccupied(col, row, false)
    end

    local safeZone = Snake:getSafeZone(3)

    if name == "Dragonfruit" then
        PlayerStats:add("totalDragonfruitEaten", 1)
        SessionStats:add("dragonfruitEaten", 1)
        Achievements:unlock("dragonHunter")
        Shaders.notify("specialEvent", {
            type = "dragonfruit",
            strength = 0.9,
        })
    end

    UI:addFruit(fruitType)
    local goalReached = UI:isGoalReached()

    local exitAlreadyOpen = Arena and Arena.hasExit and Arena:hasExit()
    if not exitAlreadyOpen and not goalReached then
        Fruit:spawn(Snake:getSegments(), Rocks, safeZone)
    end

    if love.math.random() < Rocks:getSpawnChance() then
        local fx, fy, tileCol, tileRow = SnakeUtils.getSafeSpawn(
        Snake:getSegments(),
        Fruit,
        Rocks,
        safeZone,
        {
            avoidFrontOfSnake = true,
            direction = Snake:getDirection(),
            frontBuffer = 5,
        }
        )
        if fx then
            Rocks:spawn(fx, fy, "small")
            SnakeUtils.setOccupied(tileCol, tileRow, true)
        end
    end

    Saws:onFruitCollected()
    if Rocks.onFruitCollected then
        Rocks:onFruitCollected(x, y)
    end

    applyComboReward(x, y)
    applyRunRewards(fruitType, x, y)

    if Arena and Arena.triggerBorderFlare then
        local comboCount = FruitEvents.getComboCount and FruitEvents.getComboCount() or 0
        local baseStrength = 0.12
        local comboBoost = math.min(comboCount, 5) * 0.02
        local duration = 0.55 + math.min(comboCount, 4) * 0.03
        Arena:triggerBorderFlare(baseStrength + comboBoost, duration)
    end

    if Snake.adrenaline then
        Snake.adrenaline.active = true
        Snake.adrenaline.timer = Snake.adrenaline.duration
        Snake.adrenaline.suppressVisuals = nil
    end

    Upgrades:notify("fruitCollected", {
        x = x,
        y = y,
        fruitType = fruitType,
        name = name,
        combo = comboState.count or 0,
    })

    local state = {
        snakeScore = Score:get(),
        snakeApplesEaten = Score:get(),
        totalApplesEaten = PlayerStats:get("totalApplesEaten") or 0
    }
    Achievements:checkAll(state)
end

return FruitEvents
