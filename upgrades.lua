local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Score = require("score")
local UI = require("ui")

local Upgrades = {}
local pool = {
    { -- movement
        name = "Quick Fangs",
        desc = "Snake moves 10% faster",
        apply = function()
            Snake:addSpeedMultiplier(1.10)
        end
    },
    { -- crash protection
        name = "Stone Skin",
        desc = "Survive one crash",
        apply = function()
            Snake:addCrashShields(1)
        end
    },
    { -- slow saws
        name = "Saw Grease",
        desc = "Saws move 20% slower",
        apply = function()
            Saws.speedMult = (Saws.speedMult or 1) * 0.8
        end
    },
    { -- exit unlock tweak (defensive)
        name = "Extra Bite",
        desc = "Exit unlocks one fruit earlier",
        apply = function()
			UI:setFruitGoal( math.max(1, UI:getFruitGoal() - 1) )
        end
    },
    { -- speed up after fruit collection
        name = "Adrenaline Surge",
        desc = "Snake gains a burst of speed after eating fruit",
        apply = function()
            Snake.adrenaline = {
                active = false,
                timer = 0,
                duration = 3, -- seconds
                boost = 1.5 -- 50% faster
            }
        end
    },
    {
        name = "Stone Whisperer",
        desc = "Rocks appear far less often after you snack",
        apply = function()
            local chance = Rocks.spawnChance or Rocks:getSpawnChance()
            Rocks.spawnChance = math.max(0.02, chance * 0.6)
        end
    },
    {
        name = "Tail Trainer",
        desc = "Gain an extra segment each time you grow",
        apply = function()
            Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
        end
    },
    {
        name = "Lucky Bite",
        desc = "+1 score every time you eat fruit",
        apply = function()
            if Score.addFruitBonus then
                Score:addFruitBonus(1)
            else
                Score.fruitBonus = (Score.fruitBonus or 0) + 1
            end
        end
    },
    {
        name = "Momentum Memory",
        desc = "Adrenaline bursts last 2 seconds longer",
        apply = function()
            Snake.adrenaline = Snake.adrenaline or {
                active = false,
                timer = 0,
                duration = 3,
                boost = 1.5
            }
            Snake.adrenaline.duration = Snake.adrenaline.duration + 2
        end
    },
    {
        name = "Circuit Breaker",
        desc = "Saw tracks freeze for 2s after each fruit",
        apply = function()
            if Saws.setStallOnFruit then
                Saws:setStallOnFruit(math.max(Saws:getStallOnFruit(), 2))
            else
                Saws.stallOnFruit = math.max(Saws.stallOnFruit or 0, 2)
            end
        end
    },
    {
        name = "Gem Maw",
        desc = "Fruits have a 12% chance to erupt into +5 bonus score",
        apply = function()
            if Score.addJackpotChance then
                Score:addJackpotChance(0.12, 5)
            else
                Score.jackpotChance = math.min(1, (Score.jackpotChance or 0) + 0.12)
                Score.jackpotReward = (Score.jackpotReward or 0) + 5
            end
        end
    },
    {
        name = "Stonebreaker Hymn",
        desc = "Each fruit shatters the nearest rock",
        apply = function()
            if Rocks.addShatterOnFruit then
                Rocks:addShatterOnFruit(1)
            else
                Rocks.shatterOnFruit = (Rocks.shatterOnFruit or 0) + 1
            end
        end
    },
    {
        name = "Echo Aegis",
        desc = "Crash shields unleash a shockwave that stalls saws",
        apply = function()
            if Snake.addShieldBurst then
                Snake:addShieldBurst({ rocks = 1, stall = 1.5 })
            else
                Snake.shieldBurst = Snake.shieldBurst or { rocks = 0, stall = 0 }
                Snake.shieldBurst.rocks = (Snake.shieldBurst.rocks or 0) + 1
                Snake.shieldBurst.stall = math.max(Snake.shieldBurst.stall or 0, 1.5)
            end
        end
    },
}

function Upgrades:getRandom(n)
    local chosen = {}
    for i = 1, n do
        local pick = pool[love.math.random(1, #pool)]
        table.insert(chosen, pick)
    end
    return chosen
end

return Upgrades
