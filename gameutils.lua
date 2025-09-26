local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Fruit = require("fruit")
local PauseMenu = require("pausemenu")
local Movement = require("movement")
local Score = require("score")
local FloatingText = require("floatingtext")
local Rocks = require("rocks")
local Saws = require("saws")
local Presses = require("presses")
local Particles = require("particles")
local UI = require("ui")

local GameUtils = {}

function GameUtils:prepareGame(sw, sh)
        Snake:load(sw, sh)
        Snake:resetModifiers()
        PauseMenu:load(sw, sh)
        Movement:reset()
        Score:reset()
        FloatingText:reset()
        Particles:reset()
        Rocks:reset()
        Saws:reset()
        Presses:reset()
        UI:reset()

        --SnakeUtils.initOccupancy()

        Fruit:spawn(Snake:getSegments(), Rocks)
end

return GameUtils
