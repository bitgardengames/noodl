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

local floor = math.floor
local max = math.max
local min = math.min

local FruitEvents = {}

local DEFAULT_COMBO_WINDOW = 2.25

local BLOOM_EVENT_TAG = "dragonfruitBloom"
local BLOOM_MIN_FRUIT = 5
local BLOOM_MAX_FRUIT = 7
local BLOOM_FRUIT_LIFESPAN = false
local BLOOM_RESPAWN_DELAY_MIN = 0.08
local BLOOM_RESPAWN_DELAY_MAX = 0.2

local dragonfruitBloom = {
	triggered = false,
	active = false,
	fruitsRemaining = 0,
	spawnCooldown = 0,
	pendingSpawn = false,
	safeZone = nil,
	activeFruitTag = nil,
}

local comboState = {
	count = 0,
	timer = 0,
	window = DEFAULT_COMBO_WINDOW,
	baseWindow = DEFAULT_COMBO_WINDOW,
	baseOverride = DEFAULT_COMBO_WINDOW,
	best = 0,
}

Achievements:registerStateProvider(function()
	return {
		currentCombo = comboState.count or 0,
		bestComboStreak = max(comboState.best or 0, comboState.count or 0),
	}
end)

local function resetDragonfruitBloomState()
	dragonfruitBloom.triggered = false
	dragonfruitBloom.active = false
	dragonfruitBloom.fruitsRemaining = 0
	dragonfruitBloom.spawnCooldown = 0
	dragonfruitBloom.pendingSpawn = false
	dragonfruitBloom.safeZone = nil
	dragonfruitBloom.activeFruitTag = nil
end

local function bloomRandomDelay()
	return BLOOM_RESPAWN_DELAY_MIN + (BLOOM_RESPAWN_DELAY_MAX - BLOOM_RESPAWN_DELAY_MIN) * love.math.random()
end

local function endDragonfruitBloom()
	if not dragonfruitBloom.active then
		dragonfruitBloom.pendingSpawn = false
		dragonfruitBloom.fruitsRemaining = 0
		dragonfruitBloom.safeZone = nil
		dragonfruitBloom.activeFruitTag = nil
		return
	end

	dragonfruitBloom.active = false
	dragonfruitBloom.pendingSpawn = false
	dragonfruitBloom.spawnCooldown = 0
	dragonfruitBloom.fruitsRemaining = 0
	dragonfruitBloom.safeZone = nil
	dragonfruitBloom.activeFruitTag = nil

	local exitAlreadyOpen = Arena and Arena.hasExit and Arena:hasExit()
	if not exitAlreadyOpen and not UI:isGoalReached() then
		if not Fruit:getActive() then
			Fruit:spawn(Snake:getSegments(), Rocks, Snake:getSafeZone(3))
		end
	end
end

local function handleBloomFruitExpired()
	if not dragonfruitBloom.active then
		return
	end

	dragonfruitBloom.activeFruitTag = nil

	if (dragonfruitBloom.fruitsRemaining or 0) <= 0 then
		dragonfruitBloom.pendingSpawn = false
	else
		dragonfruitBloom.pendingSpawn = true
		dragonfruitBloom.spawnCooldown = bloomRandomDelay()
	end

	Shaders.notify("specialEvent", {
		type = BLOOM_EVENT_TAG,
		strength = 0.5,
		color = Theme.dragonfruitColor,
	})
end

local function spawnDragonfruitBloomFruit()
	if not dragonfruitBloom.active then
		return false
	end

	if (dragonfruitBloom.fruitsRemaining or 0) <= 0 then
		dragonfruitBloom.pendingSpawn = false
		return false
	end

	dragonfruitBloom.safeZone = dragonfruitBloom.safeZone or Snake:getSafeZone(3)

	local options = {
		isBonus = true,
		countsForGoal = false,
		eventTag = BLOOM_EVENT_TAG,
	}

	if BLOOM_FRUIT_LIFESPAN and BLOOM_FRUIT_LIFESPAN > 0 then
		options.lifespan = BLOOM_FRUIT_LIFESPAN
		options.onExpire = handleBloomFruitExpired
	end

	Fruit:spawn(Snake:getSegments(), Rocks, dragonfruitBloom.safeZone, options)
	dragonfruitBloom.fruitsRemaining = max(0, (dragonfruitBloom.fruitsRemaining or 0) - 1)
	dragonfruitBloom.pendingSpawn = false
	dragonfruitBloom.spawnCooldown = bloomRandomDelay()
	dragonfruitBloom.activeFruitTag = BLOOM_EVENT_TAG
	dragonfruitBloom.safeZone = Snake:getSafeZone(3)

	Shaders.notify("specialEvent", {
		type = BLOOM_EVENT_TAG,
		strength = 0.75,
		color = Theme.dragonfruitColor,
	})

	return true
end

local function handleBloomFruitCollected()
	if not dragonfruitBloom.active then
		return false
	end

	dragonfruitBloom.activeFruitTag = nil

	if (dragonfruitBloom.fruitsRemaining or 0) <= 0 then
		dragonfruitBloom.pendingSpawn = false
	else
		dragonfruitBloom.pendingSpawn = true
		dragonfruitBloom.spawnCooldown = bloomRandomDelay()
	end

	Shaders.notify("specialEvent", {
		type = BLOOM_EVENT_TAG,
		strength = 0.65,
		color = Theme.dragonfruitColor,
	})

	return true
end

local function startDragonfruitBloom(safeZone)
	if dragonfruitBloom.triggered then
		return false
	end

	dragonfruitBloom.triggered = true
	dragonfruitBloom.active = true
	dragonfruitBloom.fruitsRemaining = love.math.random(BLOOM_MIN_FRUIT, BLOOM_MAX_FRUIT)
	dragonfruitBloom.spawnCooldown = 0
	dragonfruitBloom.pendingSpawn = true
	dragonfruitBloom.safeZone = safeZone
	dragonfruitBloom.activeFruitTag = nil

	Shaders.notify("specialEvent", {
		type = BLOOM_EVENT_TAG,
		strength = 1.0,
		color = Theme.dragonfruitColor,
	})

	spawnDragonfruitBloomFruit()

	return true
end

local function updateDragonfruitBloom(dt)
	if not dragonfruitBloom.active then
		return
	end

	dragonfruitBloom.spawnCooldown = max(0, (dragonfruitBloom.spawnCooldown or 0) - dt)
	dragonfruitBloom.safeZone = Snake:getSafeZone(3)

	local activeFruit = Fruit:getActive()
	local activeTag = nil
	if activeFruit then
		activeTag = activeFruit.eventTag or (activeFruit.type and activeFruit.type.id)
	end

	if activeTag ~= BLOOM_EVENT_TAG then
		dragonfruitBloom.activeFruitTag = nil
	end

	if dragonfruitBloom.pendingSpawn and dragonfruitBloom.spawnCooldown <= 0 and activeTag ~= BLOOM_EVENT_TAG then
		if not spawnDragonfruitBloomFruit() then
			dragonfruitBloom.pendingSpawn = false
		end
	end

	if (dragonfruitBloom.fruitsRemaining or 0) <= 0 and not dragonfruitBloom.pendingSpawn and activeTag ~= BLOOM_EVENT_TAG then
		endDragonfruitBloom()
	end
end

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
	comboState.baseWindow = getBaseWindow()
	comboState.window = max(0.75, comboState.baseWindow)
	comboState.timer = min(comboState.timer or 0, comboState.window)
end

local function syncComboToUI()
        UI:setCombo(
                comboState.count or 0,
                comboState.timer or 0,
                comboState.window or DEFAULT_COMBO_WINDOW
        )
end

local function applyComboReward(x, y)
	if comboState.timer > 0 then
		comboState.count = comboState.count + 1
	else
		comboState.count = 1
	end

	comboState.timer = comboState.window
	local comboCount = comboState.count
	comboState.best = max(comboState.best or 0, comboCount)
	local bestStreak = comboState.best or comboCount or 0
	PlayerStats:updateMax("bestComboStreak", bestStreak)
	SessionStats:updateMax("bestComboStreak", bestStreak)
	if comboCount >= 2 then
		SessionStats:add("combosTriggered", 1)
	end
        Shaders.notify("comboChanged", {
                combo = comboCount,
                timer = comboState.timer or 0,
                window = comboState.window or DEFAULT_COMBO_WINDOW,
        })
        updateComboWindow()
        syncComboToUI()

	if comboCount < 2 then
		return
	end

	local burstColor = {1, 0.82, 0.3, 1}
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

		local summary = string.format("Combo Bonus +%d", totalBonus)
		FloatingText:add(summary, x, y - 74, {1, 0.95, 0.6, 1}, 1.3, 48)
		Shaders.notify("specialEvent", {
			type = "combo",
			strength = 0.38,
			color = {1, 0.9, 0.5, 1},
		})
	end

	Particles:spawnBurst(x, y, {
		count = love.math.random(10, 14) + comboCount,
		speed = 90 + comboCount * 12,
		life = 0.6,
		size = 4,
		color = burstColor,
		spread = math.pi * 2,
		gravity = 30,
		drag = 2.5,
		fadeTo = 0
	})
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
				Shaders.notify("specialEvent", {
					type = "comboBoost",
					strength = 0.24,
					color = reward.color,
				})
			end
		elseif rewardType == "stallSaws" then
			local duration = reward.duration or reward.amount or 0
			if duration and duration > 0 then
				Saws:stall(duration)
				if reward.label then
					addFloatingText(reward.label, x, y - offset, reward.color or {0.8, 0.9, 1, 1}, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("specialEvent", {
					type = "stallSaws",
					strength = 0.36,
					color = reward.color or {0.72, 0.85, 1, 1},
				})
			end
		elseif rewardType == "shield" then
			local shields = floor(reward.amount or 0)
			if shields ~= 0 then
				Snake:addShields(shields)
				if reward.label and reward.showLabel ~= false then
					addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("specialEvent", {
					type = "shield",
					strength = 0.48,
					color = reward.color or {0.72, 1, 0.82, 1},
				})
			end
		elseif rewardType == "scoreBonus" then
			local bonus = floor(reward.amount or 0)
			if bonus ~= 0 then
				Score:addBonus(bonus)
				if reward.label then
					addFloatingText(reward.label, x, y - offset, reward.color, reward.duration, reward.size)
					offset = offset + 22
				end
				Shaders.notify("specialEvent", {
					type = "score",
					strength = 0.32,
					color = reward.color or {1, 0.78, 0.45, 1},
				})
			end
		end
	end
end

function FruitEvents.reset()
        comboState.count = 0
        comboState.timer = 0
        comboState.baseOverride = DEFAULT_COMBO_WINDOW
        comboState.baseWindow = DEFAULT_COMBO_WINDOW
        comboState.window = DEFAULT_COMBO_WINDOW
        comboState.best = 0
        updateComboWindow()
        syncComboToUI()
        Shaders.notify("comboLost", {reason = "reset"})
        resetDragonfruitBloomState()
end

function FruitEvents.update(dt)
        updateComboWindow()
        if comboState.timer > 0 then
                comboState.timer = max(0, comboState.timer - dt)

                if comboState.timer == 0 then
                        comboState.count = 0
                        Shaders.notify("comboLost", {reason = "timeout"})
                end

                updateComboWindow()
                syncComboToUI()
        end

        updateDragonfruitBloom(dt)
end

function FruitEvents.getComboCount()
	return comboState.count or 0
end

function FruitEvents.boostComboTimer(amount)
        if not amount or amount <= 0 then return end
        updateComboWindow()
        comboState.timer = min(comboState.window or DEFAULT_COMBO_WINDOW, (comboState.timer or 0) + amount)
        updateComboWindow()
        syncComboToUI()
	if (comboState.count or 0) >= 2 then
		Shaders.notify("specialEvent", {
			type = "comboBoost",
			strength = 0.22,
		})
	end
end

function FruitEvents.handleConsumption(x, y)
	local basePoints = Fruit:getPoints()
	local multiplier = getUpgradeEffect("fruitValueMult") or 1
	if multiplier < 1 then
		multiplier = 1
	end
	local points = basePoints * multiplier
	if points < 0 then
		points = 0
	else
		points = floor(points + 0.0001)
	end
	local name = Fruit:getTypeName()
	local fruitType = Fruit:getType()
	local collectedMeta = Fruit:getLastCollectedMeta()
	local isBloomFruit = collectedMeta and collectedMeta.eventTag == BLOOM_EVENT_TAG
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
	Audio:playSound("fruit")
	SessionStats:add("applesEaten", 1)
	if Snake.onFruitCollected then
		Snake:onFruitCollected()
	end

	if col and row then
		SnakeUtils.setOccupied(col, row, false)
	end

	local safeZone = Snake:getSafeZone(3)

	local bloomTriggeredThisFruit = false
	if name == "Dragonfruit" then
		PlayerStats:add("totalDragonfruitEaten", 1)
		SessionStats:add("dragonfruitEaten", 1)
		Achievements:unlock("dragonHunter")
		Shaders.notify("specialEvent", {
			type = "dragonfruit",
			strength = 0.9,
		})
		if not dragonfruitBloom.triggered then
			bloomTriggeredThisFruit = startDragonfruitBloom(safeZone)
		end
	end

	if countsForGoal then
		UI:addFruit(fruitType)
	end
	local goalReached = UI:isGoalReached()

	local exitAlreadyOpen = Arena and Arena.hasExit and Arena:hasExit()
	local spawnHandled = false
	if bloomTriggeredThisFruit then
		spawnHandled = true
	elseif isBloomFruit then
		spawnHandled = handleBloomFruitCollected()
	end

	if not spawnHandled and not exitAlreadyOpen and not goalReached then
		Fruit:spawn(Snake:getSegments(), Rocks, safeZone)
	end

	if love.math.random() < Rocks:getSpawnChance() then
		local fx, fy, tileCol, tileRow = SnakeUtils.getSafeSpawn(
		Snake:getSegments(),
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

	applyComboReward(x, y)
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
	})

        local state = {
                snakeScore = Score:get(),
                snakeApplesEaten = Score:get(),
                totalApplesEaten = PlayerStats:get("totalApplesEaten") or 0,
                totalDragonfruitEaten = PlayerStats:get("totalDragonfruitEaten") or 0,
                bestComboStreak = PlayerStats:get("bestComboStreak") or 0,
        }
        Achievements:checkAll(state)
end

return FruitEvents