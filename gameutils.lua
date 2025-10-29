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
local VolatileBloom = require("volatilebloom")
local UI = require("ui")
local ModuleUtil = require("moduleutil")

local GameUtils = {}

local function loadCoreSystems(sw, sh)
	Snake:load(sw, sh)
	Snake:resetModifiers()
	PauseMenu:load(sw, sh)
end

local GAMEPLAY_SYSTEMS = ModuleUtil.prepareSystems({
        Movement,
        Score,
        FloatingText,
        Particles,
        VolatileBloom,
        UpgradeVisuals,
        Rocks,
        Saws,
        UI,
})

local gameplayContext = {}

local function loadGameplaySystems(context)
	ModuleUtil.runHook(GAMEPLAY_SYSTEMS, "load", context)
end

local function resetGameplaySystems()
	ModuleUtil.runHook(GAMEPLAY_SYSTEMS, "reset")
end

function GameUtils:prepareGame(sw, sh)
	loadCoreSystems(sw, sh)
	for key in pairs(gameplayContext) do
		gameplayContext[key] = nil
	end

	gameplayContext.screenWidth = sw
	gameplayContext.screenHeight = sh

	loadGameplaySystems(gameplayContext)
	resetGameplaySystems()

	Fruit:spawn(Snake:getSegments(), Rocks, Snake:getSafeZone(3))
end

return GameUtils
