local Snake = require("snake")
local Fruit = require("fruit")
local PauseMenu = require("pausemenu")
local Movement = require("movement")
local Score = require("score")
local FloatingText = require("floatingtext")
local Rocks = require("rocks")
local Saws = require("saws")
local Particles = require("particles")
local UpgradeVisuals = require("upgradevisuals")
local UI = require("ui")

local GameUtils = {}

local function loadCoreSystems(sw, sh)
    Snake:load(sw, sh)
    Snake:resetModifiers()
    PauseMenu:load(sw, sh)
end

local GAMEPLAY_SYSTEMS = {
    Movement,
    Score,
    FloatingText,
    Particles,
    UpgradeVisuals,
    Rocks,
    Saws,
    UI,
}

local function resetGameplaySystems()
    for _, system in ipairs(GAMEPLAY_SYSTEMS) do
        system:reset()
    end
end

function GameUtils:prepareGame(sw, sh)
    loadCoreSystems(sw, sh)
    resetGameplaySystems()

    Fruit:spawn(Snake:getSegments(), Rocks, Snake:getSafeZone(3))
end

return GameUtils
