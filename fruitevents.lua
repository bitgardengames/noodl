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

function FruitEvents.reset()
    comboState.count = 0
    comboState.timer = 0
    comboState.baseOverride = DEFAULT_COMBO_WINDOW
    comboState.baseWindow = DEFAULT_COMBO_WINDOW
    comboState.window = DEFAULT_COMBO_WINDOW
    comboState.best = 0
    syncComboToUI()
end

function FruitEvents:getComboWindow()
    return comboState.window or DEFAULT_COMBO_WINDOW
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

    Particles:spawnBurst(x, y, {
        count = math.random(6, 8),
        speed = 50,
        life = 0.4,
        size = 4,
        color = {1, 1, 1, 1},
        spread = math.pi * 2
    })

    if col and row then
        SnakeUtils.setOccupied(col, row, false)
    end

    local safeZone = Snake:getSafeZone(3)

    UI:triggerScorePulse()
    UI:addFruit(fruitType)
    local goalReached = UI:isGoalReached()

    local exitAlreadyOpen = Arena and Arena.hasExit and Arena:hasExit()
    if not exitAlreadyOpen and not goalReached then
        Fruit:spawn(Snake:getSegments(), Rocks, safeZone)
    end

    if love.math.random() < Rocks:getSpawnChance() then
        local fx, fy, tileCol, tileRow = SnakeUtils.getSafeSpawn(Snake:getSegments(), Fruit, Rocks, safeZone)
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
    if Snake.adrenaline then
        Snake.adrenaline.active = true
        Snake.adrenaline.timer = Snake.adrenaline.duration
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
