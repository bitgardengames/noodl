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
local ModuleUtil = require("moduleutil")

local GameUtils = {}

local function LoadCoreSystems(sw, sh)
	Snake:load(sw, sh)
	Snake:ResetModifiers()
	PauseMenu:load(sw, sh)
end

local GAMEPLAY_SYSTEMS = ModuleUtil.PrepareSystems({
	Movement,
	Score,
	FloatingText,
	Particles,
	UpgradeVisuals,
	Rocks,
	Saws,
	UI,
})

local function LoadGameplaySystems(context)
	ModuleUtil.RunHook(GAMEPLAY_SYSTEMS, "load", context)
end

local function ResetGameplaySystems()
	ModuleUtil.RunHook(GAMEPLAY_SYSTEMS, "reset")
end

function GameUtils:PrepareGame(sw, sh)
	LoadCoreSystems(sw, sh)
	local context = {
		ScreenWidth = sw,
		ScreenHeight = sh,
	}
	LoadGameplaySystems(context)
	ResetGameplaySystems()

	Fruit:spawn(Snake:GetSegments(), Rocks, Snake:GetSafeZone(3))
end

function GameUtils:GetGameplaySystems()
	return GAMEPLAY_SYSTEMS
end

return GameUtils
