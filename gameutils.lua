local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Fruit = require("fruit")
local PauseMenu = require("pausemenu")
local Movement = require("movement")
local Score = require("score")
local FloatingText = require("floatingtext")
local Rocks = require("rocks")
local Conveyors = require("conveyors")
local Saws = require("saws")
local Particles = require("particles")
local UI = require("ui")

local GameUtils = {}

local function loadCoreSystems(sw, sh)
    Snake:load(sw, sh)
    Snake:resetModifiers()
    PauseMenu:load(sw, sh)
end

local function resetGameplaySystems()
    Movement:reset()
    Score:reset()
    FloatingText:reset()
    Particles:reset()
    Rocks:reset()
    Conveyors:reset()
    Saws:reset()
    UI:reset()
end

function GameUtils:prepareGame(sw, sh)
    loadCoreSystems(sw, sh)
    resetGameplaySystems()

    --SnakeUtils.initOccupancy()

    Fruit:spawn(Snake:getSegments(), Rocks, Snake:getSafeZone(3))
end

return GameUtils
