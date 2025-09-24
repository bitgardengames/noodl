local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
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