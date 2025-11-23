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

local floor = math.floor
local max = math.max
local min = math.min

local FruitEvents = {}

local DEFAULT_COMBO_WINDOW = 2.25
local COMBO_BURST_COLOR = {1, 0.82, 0.3, 1}

local comboBurstOptions = {
	count = 0,
	speed = 0,
	life = 0.6,
	size = 4,
	color = COMBO_BURST_COLOR,
	spread = math.pi * 2,
	gravity = 30,
	drag = 2.5,
	fadeTo = 0,
}

local function getComboMultiplier(comboCount)
	comboCount = comboCount or 0
	if comboCount >= 15 then
		return 4.0
	elseif comboCount >= 10 then
		return 3.0
	elseif comboCount >= 7 then
		return 2.0
	elseif comboCount >= 5 then
		return 1.5
	elseif comboCount >= 3 then
		return 1.2
	elseif comboCount >= 1 then
		return 1.0
	end

	return 1.0
end

local function getComboPitch(comboMultiplier, wasComboActive)
	if not wasComboActive or (comboMultiplier or 1) <= 1 then
		return 1
	end

	local scaledPitch = 1 + (comboMultiplier - 1) * 0.08
	return scaledPitch
end

local comboState = {
	count = 0,
	timer = 0,
	window = DEFAULT_COMBO_WINDOW,
	baseWindow = DEFAULT_COMBO_WINDOW,
	baseOverride = DEFAULT_COMBO_WINDOW,
	best = 0,
	windowDirty = true,
}

local function markComboWindowDirty()
	comboState.windowDirty = true
end

Achievements:registerStateProvider(function()
	return {
	currentCombo = comboState.count or 0,
	bestComboStreak = max(comboState.best or 0, comboState.count or 0),
	}
	end
)

local function getUpgradeEffect(name)
	if Upgrades and Upgrades.getEffect then
		return Upgrades:getEffect(name)
	end
end

local function getBaseWindow()
	local override = comboState.baseOverride or DEFAULT_COMBO_WINDOW
	local bonus = getUpgradeEffect("comboWindowBonus") or 0
	return max(0.5, override + bonus)
end

local function updateComboWindow()
	if not comboState.windowDirty then
		return
	end

	comboState.baseWindow = getBaseWindow()
	comboState.window = max(0.75, comboState.baseWindow)
	comboState.duration = comboState.duration or comboState.window
	comboState.timer = max(0, comboState.timer or 0)
	comboState.windowDirty = false
end

if Upgrades and Upgrades.addEventHandler then
	Upgrades:addEventHandler("upgradeAcquired", function(data, runState)
		if runState and runState.effects and (runState.effects.comboWindowBonus or 0) ~= 0 then
		markComboWindowDirty(
	)
		return
		end

		if not data or not data.upgrade then return end

		local effects = data.upgrade.effects
		if effects and (effects.comboWindowBonus or 0) ~= 0 then
		markComboWindowDirty(
	)
		end
		end
	)
end

local function syncComboToUI()
	UI:setCombo(
		comboState.count or 0,
		comboState.timer or 0,
		comboState.duration or comboState.window or DEFAULT_COMBO_WINDOW
	)
end

local function applyComboReward(fruitType, x, y, comboCount, wasComboActive)
	comboCount = comboCount or 1

	if comboState.windowDirty then
		updateComboWindow()
	end

	local baseWindow = comboState.window or DEFAULT_COMBO_WINDOW
	local extension = (fruitType and fruitType.comboExtension) or 0
	local totalWindow = baseWindow + extension

	comboState.count = comboCount
	comboState.best = max(comboState.best or 0, comboCount)
	local bestStreak = comboState.best or comboCount or 0
	PlayerStats:updateMax("bestComboStreak", bestStreak)
	SessionStats:updateMax("bestComboStreak", bestStreak)
	if comboCount >= 2 then
		SessionStats:add("combosTriggered", 1)
	end

	comboState.duration = totalWindow
	comboState.timer = totalWindow

	syncComboToUI()

	if comboCount < 2 then
		return
	end

	local baseBonus = min((comboCount - 1) * 2, 10)
	local multiplier = Score.getComboBonusMultiplier and Score:getComboBonusMultiplier() or 1
	local scaledCombo = floor(baseBonus * multiplier + 0.5)

	local extraBonus = 0
	if Upgrades and Upgrades.getComboBonus then
		extraBonus = Upgrades:getComboBonus(comboCount) or 0
	end

	local totalBonus = max(0, scaledCombo + extraBonus)

        if totalBonus > 0 then
                Score:addBonus(totalBonus)
        end

	comboBurstOptions.count = love.math.random(10, 14) + comboCount
	comboBurstOptions.speed = 90 + comboCount * 12

	Particles:spawnBurst(x, y, comboBurstOptions)
end

local function addFloatingText(label, x, y, color, duration, size)
	if not label or label == "" then return end
	FloatingText:add(label, x, y, color or Theme.textColor, duration or 1.1, size or 42)
end

local function applyRunRewards(fruitType, x, y)
	if not fruitType then return end

	local rewards = fruitType.runRewards or fruitType.runReward
	if not rewards then return end

	if rewards.type then
		rewards = {rewards}
	end

	local offset = 74
	for _, reward in ipairs(rewards) do
		local rewardType = reward.type
		if rewardType == "comboTime" then
			local amount = reward.amount or reward.duration or 0
			if amount and amount ~= 0 then
				FruitEvents.boostComboTimer(amount)
				if reward.label then
					addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
			end
		elseif rewardType == "stallSaws" then
			local duration = reward.duration or reward.amount or 0
			if duration and duration > 0 then
				Saws:stall(duration)
				if reward.label then
					addFloatingText(reward.label, x, y - offset, reward.color or {0.8, 0.9, 1, 1}, reward.duration, reward.size)
					offset = offset + 22
				end
			end
		elseif rewardType == "shield" then
			local shields = floor(reward.amount or 0)
			if shields ~= 0 then
				Snake:addShields(shields)
				if reward.label and reward.showLabel ~= false then
					addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
			end
		elseif rewardType == "scoreBonus" then
			local bonus = floor(reward.amount or 0)
			if bonus ~= 0 then
				Score:addBonus(bonus)
				if reward.label then
					addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
			end
		end
	end
end

function FruitEvents.reset()
	comboState.count = 0
	comboState.timer = 0
	comboState.duration = DEFAULT_COMBO_WINDOW
	comboState.baseOverride = DEFAULT_COMBO_WINDOW
	comboState.baseWindow = DEFAULT_COMBO_WINDOW
	comboState.window = DEFAULT_COMBO_WINDOW
	comboState.best = 0
	markComboWindowDirty()
	if comboState.windowDirty then
		updateComboWindow()
	end
	syncComboToUI()
end

function FruitEvents.update(dt)
	if comboState.windowDirty then
		updateComboWindow()
	end
	if comboState.timer > 0 then
		comboState.timer = max(0, comboState.timer - dt)

		if comboState.timer == 0 then
			comboState.count = 0
			markComboWindowDirty()
		end

		if comboState.windowDirty then
			updateComboWindow()
		end
		syncComboToUI()
	end
end

function FruitEvents.getComboCount()
	return comboState.count or 0
end

function FruitEvents.boostComboTimer(amount)
	if not amount or amount <= 0 then return end
	if comboState.windowDirty then
		updateComboWindow()
	end
	local limit = comboState.duration or comboState.window or DEFAULT_COMBO_WINDOW
	comboState.timer = min(limit, (comboState.timer or 0) + amount)
	if comboState.windowDirty then
		updateComboWindow()
	end
	syncComboToUI()
end

function FruitEvents.handleConsumption(x, y)
        local basePoints = Fruit:getPoints()
        local wasComboActive = (comboState.timer or 0) > 0
        local currentComboCount = wasComboActive and (comboState.count or 0) or 0
        local nextComboCount = wasComboActive and currentComboCount + 1 or 1
        local comboMultiplier = getComboMultiplier(currentComboCount)
	local multiplier = getUpgradeEffect("fruitValueMult") or 1
	if multiplier < 1 then
		multiplier = 1
	end
	local fruitPitch = getComboPitch(comboMultiplier, wasComboActive)
	local points = basePoints * comboMultiplier * multiplier
	if points < 0 then
		points = 0
	else
		points = floor(points + 0.0001)
	end
	local name = Fruit:getTypeName()
	local fruitType = Fruit:getType()
	local collectedMeta = Fruit:getLastCollectedMeta()
	local countsForGoal = not (collectedMeta and collectedMeta.countsForGoal == false)
	local col, row = Fruit:getTile()

	Snake:grow()

	local markerX, markerY = Fruit:getPosition()
	if not markerX then markerX = x end
	if not markerY then markerY = y end
	Snake:markFruitSegment(markerX, markerY)

	Face:set("happy", 2)
        FloatingText:add("+" .. tostring(points), x, y, Theme.textColor, 1.0, 40)
	Score:increase(points)
	Audio:playSound("fruit", fruitPitch)
	SessionStats:add("fruitEaten", 1)
	if Snake.onFruitCollected then
		Snake:onFruitCollected()
	end

	if col and row then
		SnakeUtils.setOccupied(col, row, false)
	end

	local safeZone = Snake:getSafeZone(3)
	local segments = Snake:getSegments()

	if name == "Dragonfruit" then
		PlayerStats:add("totalDragonfruitEaten", 1)
		SessionStats:add("dragonfruitEaten", 1)
		Achievements:unlock("dragonHunter")
	end

	if countsForGoal then
		UI:addFruit(fruitType)
	end
	local goalReached = UI:isGoalReached()

	local exitAlreadyOpen = Arena and Arena.hasExit and Arena:hasExit()
	if not exitAlreadyOpen and not goalReached then
		Fruit:spawn(segments, Rocks, safeZone)
	end

	if love.math.random() < Rocks:getSpawnChance() then
		local fx, fy, tileCol, tileRow = SnakeUtils.getSafeSpawn(
			segments,
			Fruit,
			Rocks,
			safeZone,
			{
			avoidFrontOfSnake = true,
			direction = Snake:getDirection(),
			frontBuffer = 5,
			}
		)
		if fx then
			Rocks:spawn(fx, fy, "small")
			SnakeUtils.setOccupied(tileCol, tileRow, true)
		end
	end

	Saws:onFruitCollected()
	if Rocks.onFruitCollected then
		Rocks:onFruitCollected(x, y)
	end

	applyComboReward(fruitType, x, y, nextComboCount, wasComboActive)
	applyRunRewards(fruitType, x, y)

	if Arena and Arena.triggerBorderFlare then
		local comboCount = FruitEvents.getComboCount and FruitEvents.getComboCount() or 0
		local baseStrength = 0.12
		local comboBoost = min(comboCount, 5) * 0.02
		local duration = 0.55 + min(comboCount, 4) * 0.03
		Arena:triggerBorderFlare(baseStrength + comboBoost, duration)
	end

	if Snake.adrenaline then
		Snake.adrenaline.active = true
		Snake.adrenaline.timer = Snake.adrenaline.duration
		Snake.adrenaline.suppressVisuals = nil
	end

	Upgrades:notify("fruitCollected", {
		x = x,
		y = y,
		fruitType = fruitType,
		name = name,
		combo = comboState.count or 0,
		}
	)

        local state = {
                snakeScore = Score:get(),
                snakeApplesEaten = Score:get(),
                totalFruitEaten = PlayerStats:get("totalFruitEaten") or 0,
                totalDragonfruitEaten = PlayerStats:get("totalDragonfruitEaten") or 0,
                bestComboStreak = PlayerStats:get("bestComboStreak") or 0,
        }

        Achievements:checkAll(state)
end

return FruitEvents
