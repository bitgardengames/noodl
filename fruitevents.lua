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
local Shaders = require("shaders")

local FruitEvents = {}

local DEFAULT_COMBO_WINDOW = 2.25

local ComboState = {
	count = 0,
	timer = 0,
	window = DEFAULT_COMBO_WINDOW,
	BaseWindow = DEFAULT_COMBO_WINDOW,
	BaseOverride = DEFAULT_COMBO_WINDOW,
	best = 0,
}

Achievements:RegisterStateProvider(function()
	return {
		CurrentCombo = ComboState.count or 0,
		BestComboStreak = math.max(ComboState.best or 0, ComboState.count or 0),
	}
end)

local function GetUpgradeEffect(name)
	if Upgrades and Upgrades.GetEffect then
		return Upgrades:GetEffect(name)
	end
end

local function GetBaseWindow()
	local override = ComboState.baseOverride or DEFAULT_COMBO_WINDOW
	local bonus = GetUpgradeEffect("ComboWindowBonus") or 0
	return math.max(0.5, override + bonus)
end

local function UpdateComboWindow()
	ComboState.baseWindow = GetBaseWindow()
	ComboState.window = math.max(0.75, ComboState.baseWindow)
	ComboState.timer = math.min(ComboState.timer or 0, ComboState.window)
end

local function SyncComboToUI()
	UpdateComboWindow()
	UI:SetCombo(
		ComboState.count or 0,
		ComboState.timer or 0,
		ComboState.window or DEFAULT_COMBO_WINDOW
	)
end

local function ApplyComboReward(x, y)
	if ComboState.timer > 0 then
		ComboState.count = ComboState.count + 1
	else
		ComboState.count = 1
	end

	ComboState.timer = ComboState.window
	local ComboCount = ComboState.count
	ComboState.best = math.max(ComboState.best or 0, ComboCount)
	local BestStreak = ComboState.best or ComboCount or 0
	PlayerStats:UpdateMax("BestComboStreak", BestStreak)
	SessionStats:UpdateMax("BestComboStreak", BestStreak)
	if ComboCount >= 2 then
		SessionStats:add("CombosTriggered", 1)
	end
	Shaders.notify("ComboChanged", {
		combo = ComboCount,
		timer = ComboState.timer or 0,
		window = ComboState.window or DEFAULT_COMBO_WINDOW,
	})
	SyncComboToUI()

	if ComboCount < 2 then
		return
	end

	local BurstColor = {1, 0.82, 0.3, 1}
	local BaseBonus = math.min((ComboCount - 1) * 2, 10)
	local multiplier = Score.GetComboBonusMultiplier and Score:GetComboBonusMultiplier() or 1
	local ScaledCombo = math.floor(BaseBonus * multiplier + 0.5)

	local ExtraBonus = 0
	if Upgrades and Upgrades.GetComboBonus then
		ExtraBonus = Upgrades:GetComboBonus(ComboCount) or 0
	end

	local TotalBonus = math.max(0, ScaledCombo + ExtraBonus)

	if TotalBonus > 0 then
		Score:AddBonus(TotalBonus)

		local summary = string.format("Combo Bonus +%d", TotalBonus)
		FloatingText:add(summary, x, y - 74, {1, 0.95, 0.6, 1}, 1.3, 48)
		Shaders.notify("SpecialEvent", {
			type = "combo",
			strength = 0.38,
			color = {1, 0.9, 0.5, 1},
		})
	end

	Particles:SpawnBurst(x, y, {
		count = love.math.random(10, 14) + ComboCount,
		speed = 90 + ComboCount * 12,
		life = 0.6,
		size = 4,
		color = BurstColor,
		spread = math.pi * 2,
		gravity = 30,
		drag = 2.5,
		FadeTo = 0
	})
end

local function AddFloatingText(label, x, y, color, duration, size)
	if not label or label == "" then return end
	FloatingText:add(label, x, y, color or Theme.TextColor, duration or 1.1, size or 42)
end

local function ApplyRunRewards(FruitType, x, y)
	if not FruitType then return end

	local rewards = FruitType.runRewards or FruitType.runReward
	if not rewards then return end

	if rewards.type then
		rewards = { rewards }
	end

	local offset = 74
	for _, reward in ipairs(rewards) do
		local RewardType = reward.type
		if RewardType == "ComboTime" then
			local amount = reward.amount or reward.duration or 0
			if amount and amount ~= 0 then
				FruitEvents.BoostComboTimer(amount)
				if reward.label then
					AddFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("SpecialEvent", {
					type = "ComboBoost",
					strength = 0.24,
					color = reward.color,
				})
			end
		elseif RewardType == "StallSaws" then
			local duration = reward.duration or reward.amount or 0
			if duration and duration > 0 then
				Saws:stall(duration)
				if reward.label then
					AddFloatingText(reward.label, x, y - offset, reward.color or {0.8, 0.9, 1, 1}, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("SpecialEvent", {
					type = "StallSaws",
					strength = 0.36,
					color = reward.color or {0.72, 0.85, 1, 1},
				})
			end
		elseif RewardType == "shield" then
			local shields = math.floor(reward.amount or 0)
			if shields ~= 0 then
				Snake:AddCrashShields(shields)
				if reward.label and reward.showLabel ~= false then
					AddFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("SpecialEvent", {
					type = "shield",
					strength = 0.48,
					color = reward.color or {0.72, 1, 0.82, 1},
				})
			end
		elseif RewardType == "ScoreBonus" then
			local bonus = math.floor(reward.amount or 0)
			if bonus ~= 0 then
				Score:AddBonus(bonus)
				if reward.label then
					AddFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("SpecialEvent", {
					type = "score",
					strength = 0.32,
					color = reward.color or {1, 0.78, 0.45, 1},
				})
			end
		end
	end
end

function FruitEvents.reset()
	ComboState.count = 0
	ComboState.timer = 0
	ComboState.baseOverride = DEFAULT_COMBO_WINDOW
	ComboState.baseWindow = DEFAULT_COMBO_WINDOW
	ComboState.window = DEFAULT_COMBO_WINDOW
	ComboState.best = 0
	SyncComboToUI()
	Shaders.notify("ComboLost", { reason = "reset" })
end

function FruitEvents:GetDefaultComboWindow()
	return DEFAULT_COMBO_WINDOW
end

function FruitEvents:SetComboWindow(window)
	ComboState.baseOverride = math.max(0.5, window or DEFAULT_COMBO_WINDOW)
	SyncComboToUI()
end

function FruitEvents.update(dt)
	UpdateComboWindow()
	if ComboState.timer > 0 then
		ComboState.timer = math.max(0, ComboState.timer - dt)

		if ComboState.timer == 0 then
			ComboState.count = 0
			Shaders.notify("ComboLost", { reason = "timeout" })
		end

		SyncComboToUI()
	end
end

function FruitEvents.GetComboCount()
	return ComboState.count or 0
end

function FruitEvents.BoostComboTimer(amount)
	if not amount or amount <= 0 then return end
	UpdateComboWindow()
	ComboState.timer = math.min(ComboState.window or DEFAULT_COMBO_WINDOW, (ComboState.timer or 0) + amount)
	SyncComboToUI()
	if (ComboState.count or 0) >= 2 then
		Shaders.notify("SpecialEvent", {
			type = "ComboBoost",
			strength = 0.22,
		})
	end
end

function FruitEvents.HandleConsumption(x, y)
	local points = Fruit:GetPoints()
	local name = Fruit:GetTypeName()
	local FruitType = Fruit:GetType()
	local col, row = Fruit:GetTile()

	Snake:grow()
	Snake:MarkFruitSegment(x, y)

	Face:set("happy", 2)
	FloatingText:add("+" .. tostring(points), x, y, Theme.TextColor, 1.0, 40)
	Score:increase(points)
	Audio:PlaySound("fruit")
	SessionStats:add("ApplesEaten", 1)
	if Snake.OnFruitCollected then
		Snake:OnFruitCollected()
	end

	if col and row then
		SnakeUtils.SetOccupied(col, row, false)
	end

	local SafeZone = Snake:GetSafeZone(3)

	if name == "Dragonfruit" then
		PlayerStats:add("TotalDragonfruitEaten", 1)
		SessionStats:add("DragonfruitEaten", 1)
		Achievements:unlock("DragonHunter")
		Shaders.notify("SpecialEvent", {
			type = "dragonfruit",
			strength = 0.9,
		})
	end

	UI:TriggerScorePulse()
	UI:AddFruit(FruitType)
	local GoalReached = UI:IsGoalReached()

	local ExitAlreadyOpen = Arena and Arena.HasExit and Arena:HasExit()
	if not ExitAlreadyOpen and not GoalReached then
		Fruit:spawn(Snake:GetSegments(), Rocks, SafeZone)
	end

	if love.math.random() < Rocks:GetSpawnChance() then
		local fx, fy, TileCol, TileRow = SnakeUtils.GetSafeSpawn(
			Snake:GetSegments(),
			Fruit,
			Rocks,
			SafeZone,
			{
				AvoidFrontOfSnake = true,
				direction = Snake:GetDirection(),
				FrontBuffer = 5,
			}
		)
		if fx then
			Rocks:spawn(fx, fy, "small")
			SnakeUtils.SetOccupied(TileCol, TileRow, true)
		end
	end

	Saws:OnFruitCollected()
	if Rocks.OnFruitCollected then
		Rocks:OnFruitCollected(x, y)
	end

	ApplyComboReward(x, y)
	ApplyRunRewards(FruitType, x, y)

	if Arena and Arena.TriggerBorderFlare then
		local ComboCount = FruitEvents.GetComboCount and FruitEvents.GetComboCount() or 0
		local BaseStrength = 0.12
		local ComboBoost = math.min(ComboCount, 5) * 0.02
		local duration = 0.55 + math.min(ComboCount, 4) * 0.03
		Arena:TriggerBorderFlare(BaseStrength + ComboBoost, duration)
	end

	if Snake.adrenaline then
		Snake.adrenaline.active = true
		Snake.adrenaline.timer = Snake.adrenaline.duration
	end

	Upgrades:notify("FruitCollected", {
		x = x,
		y = y,
		FruitType = FruitType,
		name = name,
		combo = ComboState.count or 0,
	})

	local state = {
		SnakeScore = Score:get(),
		SnakeApplesEaten = Score:get(),
		TotalApplesEaten = PlayerStats:get("TotalApplesEaten") or 0
	}
	Achievements:CheckAll(state)
end

return FruitEvents
