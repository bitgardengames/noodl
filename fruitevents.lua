local Fruit = require("fruit")
local Audio = require("audio")
local Snake = require("snake")
local Face = require("face")
local Score = require("score")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Rocks = require("rocks")
local Saws = require("saws")
local SnakeUtils = require("snakeutils")
local UI = require("ui")
local FloatingText = require("floatingtext")
local Particles = require("particles")
local Theme = require("theme")
local Achievements = require("achievements")

local FruitEvents = {}

local comboState = {
    count = 0,
    timer = 0,
    window = 2.25,
}

local function comboTagline(count)
    if count >= 6 then
        return "Unstoppable!"
    elseif count >= 5 then
        return "Blazing!"
    elseif count >= 4 then
        return "Hot Streak!"
    elseif count >= 3 then
        return "Juicy!"
    else
        return "Keep it going!"
    end
end

local function applyComboReward(x, y)
    if comboState.timer > 0 then
        comboState.count = comboState.count + 1
    else
        comboState.count = 1
    end

    comboState.timer = comboState.window

    local comboCount = comboState.count
    UI:setCombo(comboCount, comboState.timer, comboState.window)

    if comboCount < 2 then
        return
    end

    local burstColor = {1, 0.82, 0.3, 1}
    local bonus = math.min((comboCount - 1) * 2, 10)

    FloatingText:add(comboTagline(comboCount), x, y - 32, burstColor, 1.3, 55)

    if bonus > 0 then
        Score:addBonus(bonus)
        FloatingText:add("+" .. tostring(bonus) .. " bonus", x, y - 64, {1, 0.95, 0.6, 1}, 1.1, 50)
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
    UI:setCombo(0, 0, comboState.window)
end

function FruitEvents.update(dt)
    if comboState.timer > 0 then
        comboState.timer = math.max(0, comboState.timer - dt)

        if comboState.timer == 0 then
            comboState.count = 0
        end

        UI:setCombo(comboState.count, comboState.timer, comboState.window)
    end
end

function FruitEvents.handleConsumption(x, y)
    local points = Fruit:getPoints()
    local name = Fruit:getTypeName()
    local fruitType = Fruit:getType()
    local col, row = Fruit:getTile()

    Snake:grow()
    Face:set("happy", 2)
    FloatingText:add("+" .. tostring(points), x, y, Theme.textColor, 1.0, 40)
    Score:increase(points)
    Audio:playSound("fruit")
    SessionStats:add("applesEaten", 1)

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

    if name == "Dragonfruit" then
        Achievements:unlock("dragonHunter")
    end

    Fruit:spawn(Snake:getSegments(), Rocks)

    if love.math.random() < Rocks:getSpawnChance() then
        local fx, fy, tileCol, tileRow = SnakeUtils.getSafeSpawn(Snake:getSegments(), Fruit, Rocks)
        if fx then
            Rocks:spawn(fx, fy, "small")
            SnakeUtils.setOccupied(tileCol, tileRow, true)
        end
    end

    UI:triggerScorePulse()
    UI:addFruit(fruitType)
    Saws:onFruitCollected()
    if Rocks.onFruitCollected then
        Rocks:onFruitCollected(x, y)
    end

    applyComboReward(x, y)

    if Snake.adrenaline then
        Snake.adrenaline.active = true
        Snake.adrenaline.timer = Snake.adrenaline.duration
    end

    local jackpotChance = Score.getJackpotChance and Score:getJackpotChance() or 0
    if jackpotChance > 0 then
        if love.math.random() < jackpotChance then
            local reward = Score.getJackpotReward and Score:getJackpotReward() or 0
            if reward > 0 and Score.addBonus then
                Score:addBonus(reward)
                FloatingText:add("Jackpot +" .. tostring(reward), x, y - 28, {1, 0.85, 0.2, 1}, 1.2, 55)
                Particles:spawnBurst(x, y, {
                    count = love.math.random(10, 14),
                    speed = 80,
                    life = 0.5,
                    size = 4,
                    color = {1, 0.9, 0.4, 1},
                    spread = math.pi * 2,
                })
            end
        end
    end

    local state = {
        snakeScore = Score:get(),
        snakeApplesEaten = Score:get(),
        totalApplesEaten = PlayerStats:get("totalApplesEaten") or 0
    }
    Achievements:checkAll(state)
end

return FruitEvents
