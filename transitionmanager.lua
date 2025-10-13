local Audio = require("audio")
local Floors = require("floors")
local SessionStats = require("sessionstats")
local PlayerStats = require("playerstats")
local Shop = require("shop")

local TransitionManager = {}
TransitionManager.__index = TransitionManager

local function shallowCopy(values)
	local copy = {}
	if not values then
		return copy
	end

	for key, value in pairs(values) do
		copy[key] = value
	end

	return copy
end

function TransitionManager.new(game)
	return setmetatable({
		game = game,
		phase = nil,
		timer = 0,
		duration = 0,
		data = {},
		shopCloseRequested = false,
	}, TransitionManager)
end

local function getResumeState(self)
	local data = self.data or {}
	local resume = data.transitionResumePhase
	if resume == nil or resume == "fadein" then
		return "playing"
	end
	return resume
end

function TransitionManager:isGameplayBlocked()
	local phase = self.phase
	if not phase then
		return false
	end

	if phase == "floorintro" then
		local data = self.data or {}
		local duration = self.duration or 0
		if self.timer < duration then
			return true
		end
		return data.transitionAwaitInput and not data.transitionIntroConfirmed
	end

	if phase == "fadein" then
		return false
	end

	return true
end

function TransitionManager:updateGameplayState()
	local game = self.game
	if not game then
		return
	end

	local phase = self.phase
	if not phase then
		if game.state == "transition" then
			game.state = getResumeState(self)
		end
		return
	end

	if self:isGameplayBlocked() then
		game.state = "transition"
	else
		game.state = getResumeState(self)
	end
end

function TransitionManager:reset()
	self.phase = nil
	self.timer = 0
	self.duration = 0
	self.data = {}
	self.shopCloseRequested = false
	self:updateGameplayState()
end

function TransitionManager:isActive()
	return self.phase ~= nil
end

function TransitionManager:isShopActive()
	return self.phase == "shop"
end

function TransitionManager:getPhase()
	return self.phase
end

function TransitionManager:getTimer()
	return self.timer
end

function TransitionManager:getDuration()
	return self.duration
end

function TransitionManager:getData()
	return self.data
end

function TransitionManager:setData(values)
	self.data = shallowCopy(values)
end

function TransitionManager:mergeData(values)
	if not values then
		return
	end

	for key, value in pairs(values) do
		self.data[key] = value
	end
end

function TransitionManager:startPhase(phase, duration)
	self.phase = phase
	self.timer = 0
	self.duration = duration or 0
	self:updateGameplayState()
end

function TransitionManager:clearPhase()
	self.phase = nil
	self.timer = 0
	self.duration = 0
	self:updateGameplayState()
end

function TransitionManager:openShop()
	Shop:start(self.game.floor)
	self.shopCloseRequested = false
	self.phase = "shop"
	self.timer = 0
	self.duration = 0
	Audio:playSound("shop_open")
	self:updateGameplayState()
end

function TransitionManager:startFloorIntro(duration, extra)
	extra = shallowCopy(extra)
	if not extra.transitionResumePhase then
		extra.transitionResumePhase = "playing"
	end

	if extra.transitionResumePhase == "fadein" and not extra.transitionResumeFadeDuration then
		extra.transitionResumeFadeDuration = 0.9
	elseif extra.transitionResumePhase ~= "fadein" then
		extra.transitionResumeFadeDuration = nil
	end

	self.data.transitionIntroConfirmed = nil
	self.data.transitionIntroReady = nil

	self:mergeData(extra)

	local data = self.data
	local introDuration = duration or data.transitionIntroDuration or 2.2
	data.transitionIntroDuration = introDuration

	local defaultAwaitInput = true
	if data.transitionAdvance == false then
		defaultAwaitInput = false
	end

	if extra.transitionAwaitInput ~= nil then
		data.transitionAwaitInput = extra.transitionAwaitInput and true or false
	else
		data.transitionAwaitInput = defaultAwaitInput
	end

	if extra.transitionIntroPromptDelay ~= nil then
		data.transitionIntroPromptDelay = extra.transitionIntroPromptDelay or 0
	else
		data.transitionIntroPromptDelay = 0.18
	end

	data.transitionIntroConfirmed = nil

	self:startPhase("floorintro", introDuration)
	Audio:playSound("floor_intro")
end

function TransitionManager:startFadeIn(duration)
	self:startPhase("fadein", duration or 0.9)
end

function TransitionManager:startFloorTransition(advance, skipFade)
	local game = self.game

	local pendingFloor = advance and (game.floor + 1) or nil
	local floorData = Floors[pendingFloor or game.floor] or Floors[1]

	if advance then
		local floorTime = game.floorTimer or 0
		if floorTime and floorTime > 0 then
			SessionStats:add("totalFloorTime", floorTime)
			SessionStats:updateMin("fastestFloorClear", floorTime)
			SessionStats:updateMax("slowestFloorClear", floorTime)
			SessionStats:set("lastFloorClearTime", floorTime)
		end
		game.floorTimer = 0

		local currentFloor = game.floor or 1
		local nextFloor = currentFloor + 1
		PlayerStats:add("floorsCleared", 1)
		PlayerStats:updateMax("deepestFloorReached", nextFloor)
		SessionStats:add("floorsCleared", 1)
		SessionStats:updateMax("deepestFloorReached", nextFloor)
		Audio:playSound("floor_advance")
	end

	self:setData({
		transitionAdvance = advance,
		pendingFloor = pendingFloor,
		transitionFloorData = floorData,
		floorApplied = false,
	})

	self.shopCloseRequested = false
	self:startPhase("fadeout", skipFade and 0 or 1.2)
end

function TransitionManager:update(dt)
	if not self:isActive() then
		return
	end

	self.timer = self.timer + dt
	local phase = self.phase

	if phase == "fadeout" then
                if self.timer >= self.duration then
                        local data = self.data
                        if data.transitionAdvance and not data.floorApplied and data.pendingFloor then
                                self.game.floor = data.pendingFloor
                                self.game:setupFloor(self.game.floor)
                                data.floorApplied = true
                                data.transitionFloorData = self.game.currentFloorData or data.transitionFloorData
                        end

                        self:openShop()
                end
                return
	end

	if phase == "shop" then
		Shop:update(dt)
		if self.shopCloseRequested and Shop:isSelectionComplete() then
			self.shopCloseRequested = false
			self:startFloorIntro()
		end
		return
	end

	if phase == "floorintro" then
		if self.timer >= self.duration then
			local data = self.data

			if data.transitionAwaitInput then
				data.transitionIntroReady = true
				if not data.transitionIntroConfirmed then
					return
				end
			end

			self:completeFloorIntro()
		end
		return
	end

	if phase == "fadein" then
		if self.timer >= self.duration then
			self.game.state = "playing"
			self:clearPhase()
		end
		return
	end
end

function TransitionManager:handleShopInput(methodName, ...)
	if not self:isShopActive() then
		return false
	end

	local handler = Shop[methodName]
	if not handler then
		return true
	end

	local result = handler(Shop, ...)
	if result then
		self.shopCloseRequested = true
	end

	return true
end

function TransitionManager:completeFloorIntro()
	local data = self.data
	local resumePhase = data.transitionResumePhase or "fadein"
	local fadeDuration = data.transitionResumeFadeDuration

	data.transitionIntroConfirmed = nil
	data.transitionIntroReady = nil
	data.transitionAwaitInput = nil
	data.transitionIntroPromptDelay = nil
	data.transitionIntroDuration = nil

	data.transitionResumePhase = nil
	data.transitionResumeFadeDuration = nil

	if resumePhase == "fadein" then
		self:startFadeIn(fadeDuration)
	else
		self.game.state = "playing"
		self:clearPhase()
	end
end

function TransitionManager:confirmFloorIntro()
	if self.phase ~= "floorintro" then
		return false
	end

	local data = self.data
	if not data.transitionAwaitInput then
		return false
	end

        data.transitionIntroConfirmed = true

        local duration = self.duration or 0
        if duration > 0 and self.timer < duration then
                -- Keep only a brief dissolve after the player confirms the intro.
                local minRemaining = 0.3
                local targetTimer = duration - minRemaining
                if targetTimer < 0 then
                        targetTimer = 0
                end
                if targetTimer > self.timer then
                        self.timer = targetTimer
                end
        end

        self:updateGameplayState()

        if self.timer >= self.duration then
                self:completeFloorIntro()
        end

        return true
end

return TransitionManager
