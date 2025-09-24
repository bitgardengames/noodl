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

function FruitEvents.handleConsumption(x, y)
    local points = Fruit:getPoints()
    local name = Fruit:getTypeName()
	local FruitType = Fruit:getType()
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
        local fx, fy, col, row = SnakeUtils.getSafeSpawn(Snake:getSegments(), Fruit, Rocks)
        if fx then
            --Rocks:spawn(fx, fy)
                        Rocks:spawn(fx, fy, "small")

            SnakeUtils.setOccupied(col, row, true)
        end
    end

    UI:triggerScorePulse()
        UI:addFruit(FruitType)
        Saws:onFruitCollected()

        if Snake.adrenaline then
                Snake.adrenaline.active = true
                Snake.adrenaline.timer = Snake.adrenaline.duration
	end

    local state = {
        snakeScore = Score:get(),
        snakeApplesEaten = Score:get(),
        totalApplesEaten = PlayerStats:get("totalApplesEaten") or 0
    }
    Achievements:checkAll(state)
end

return FruitEvents
