local Audio = require("audio")
local Floors = require("floors")
local SessionStats = require("sessionstats")
local PlayerStats = require("playerstats")
local Shop = require("shop")

local TransitionManager = {}
TransitionManager.__index = TransitionManager

local function ShallowCopy(values)
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
		ShopCloseRequested = false,
	}, TransitionManager)
end

local function GetResumeState(self)
	local data = self.data or {}
	local resume = data.transitionResumePhase
	if resume == nil or resume == "fadein" then
		return "playing"
	end
	return resume
end

function TransitionManager:IsGameplayBlocked()
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

function TransitionManager:UpdateGameplayState()
	local game = self.game
	if not game then
		return
	end

	local phase = self.phase
	if not phase then
		if game.state == "transition" then
			game.state = GetResumeState(self)
		end
		return
	end

	if self:IsGameplayBlocked() then
		game.state = "transition"
	else
		game.state = GetResumeState(self)
	end
end

function TransitionManager:reset()
	self.phase = nil
	self.timer = 0
	self.duration = 0
	self.data = {}
	self.ShopCloseRequested = false
	self:UpdateGameplayState()
end

function TransitionManager:IsActive()
	return self.phase ~= nil
end

function TransitionManager:IsShopActive()
	return self.phase == "shop"
end

function TransitionManager:GetPhase()
	return self.phase
end

function TransitionManager:GetTimer()
	return self.timer
end

function TransitionManager:GetDuration()
	return self.duration
end

function TransitionManager:GetData()
	return self.data
end

function TransitionManager:SetData(values)
	self.data = ShallowCopy(values)
end

function TransitionManager:MergeData(values)
	if not values then
		return
	end

	for key, value in pairs(values) do
		self.data[key] = value
	end
end

function TransitionManager:StartPhase(phase, duration)
	self.phase = phase
	self.timer = 0
	self.duration = duration or 0
	self:UpdateGameplayState()
end

function TransitionManager:ClearPhase()
	self.phase = nil
	self.timer = 0
	self.duration = 0
	self:UpdateGameplayState()
end

function TransitionManager:OpenShop()
	Shop:start(self.game.floor)
	self.ShopCloseRequested = false
	self.phase = "shop"
	self.timer = 0
	self.duration = 0
	Audio:PlaySound("shop_open")
	self:UpdateGameplayState()
end

function TransitionManager:StartFloorIntro(duration, extra)
	extra = ShallowCopy(extra)
	if not extra.transitionResumePhase then
		extra.transitionResumePhase = "playing"
	end

	if extra.transitionResumePhase == "fadein" and not extra.transitionResumeFadeDuration then
		extra.transitionResumeFadeDuration = 0.9
	elseif extra.transitionResumePhase ~= "fadein" then
		extra.transitionResumeFadeDuration = nil
	end

	self.data.TransitionIntroConfirmed = nil
	self.data.TransitionIntroReady = nil

	self:MergeData(extra)

	local data = self.data
	local IntroDuration = duration or data.transitionIntroDuration or 2.2
	data.transitionIntroDuration = IntroDuration

	local DefaultAwaitInput = true
	if data.transitionAdvance == false then
		DefaultAwaitInput = false
	end

	if extra.transitionAwaitInput ~= nil then
		data.transitionAwaitInput = extra.transitionAwaitInput and true or false
	else
		data.transitionAwaitInput = DefaultAwaitInput
	end

	if extra.transitionIntroPromptDelay ~= nil then
		data.transitionIntroPromptDelay = extra.transitionIntroPromptDelay or 0
	else
		data.transitionIntroPromptDelay = 0.18
	end

	data.transitionIntroConfirmed = nil

	self:StartPhase("floorintro", IntroDuration)
	Audio:PlaySound("floor_intro")
end

function TransitionManager:StartFadeIn(duration)
	self:StartPhase("fadein", duration or 0.9)
end

function TransitionManager:StartFloorTransition(advance, SkipFade)
	local game = self.game

	local PendingFloor = advance and (game.floor + 1) or nil
	local FloorData = Floors[PendingFloor or game.floor] or Floors[1]

	if advance then
		local FloorTime = game.floorTimer or 0
		if FloorTime and FloorTime > 0 then
			SessionStats:add("TotalFloorTime", FloorTime)
			SessionStats:UpdateMin("FastestFloorClear", FloorTime)
			SessionStats:UpdateMax("SlowestFloorClear", FloorTime)
			SessionStats:set("LastFloorClearTime", FloorTime)
		end
		game.floorTimer = 0

		local CurrentFloor = game.floor or 1
		local NextFloor = CurrentFloor + 1
		PlayerStats:add("FloorsCleared", 1)
		PlayerStats:UpdateMax("DeepestFloorReached", NextFloor)
		SessionStats:add("FloorsCleared", 1)
		SessionStats:UpdateMax("DeepestFloorReached", NextFloor)
		Audio:PlaySound("floor_advance")
	end

	self:SetData({
		TransitionAdvance = advance,
		PendingFloor = PendingFloor,
		TransitionFloorData = FloorData,
		FloorApplied = false,
	})

	self.ShopCloseRequested = false
	self:StartPhase("fadeout", SkipFade and 0 or 1.2)
end

function TransitionManager:update(dt)
	if not self:IsActive() then
		return
	end

	self.timer = self.timer + dt
	local phase = self.phase

	if phase == "fadeout" then
		if self.timer >= self.duration then
			local data = self.data
			if data.transitionAdvance and not data.floorApplied and data.pendingFloor then
				self.game.floor = data.pendingFloor
				self.game:SetupFloor(self.game.floor)
				data.floorApplied = true
			end

			self:OpenShop()
		end
		return
	end

	if phase == "shop" then
		Shop:update(dt)
		if self.ShopCloseRequested and Shop:IsSelectionComplete() then
			self.ShopCloseRequested = false
			self:StartFloorIntro()
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

			self:CompleteFloorIntro()
		end
		return
	end

	if phase == "fadein" then
		if self.timer >= self.duration then
			self.game.state = "playing"
			self:ClearPhase()
		end
		return
	end
end

function TransitionManager:HandleShopInput(MethodName, ...)
	if not self:IsShopActive() then
		return false
	end

	local handler = Shop[MethodName]
	if not handler then
		return true
	end

	local result = handler(Shop, ...)
	if result then
		self.ShopCloseRequested = true
	end

	return true
end

function TransitionManager:CompleteFloorIntro()
	local data = self.data
	local ResumePhase = data.transitionResumePhase or "fadein"
	local FadeDuration = data.transitionResumeFadeDuration

	data.transitionIntroConfirmed = nil
	data.transitionIntroReady = nil
	data.transitionAwaitInput = nil
	data.transitionIntroPromptDelay = nil
	data.transitionIntroDuration = nil

	data.transitionResumePhase = nil
	data.transitionResumeFadeDuration = nil

	if ResumePhase == "fadein" then
		self:StartFadeIn(FadeDuration)
	else
		self.game.state = "playing"
		self:ClearPhase()
	end
end

function TransitionManager:ConfirmFloorIntro()
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
		local MinRemaining = 0.3
		local TargetTimer = duration - MinRemaining
		if TargetTimer < 0 then
			TargetTimer = 0
		end
		if TargetTimer > self.timer then
			self.timer = TargetTimer
		end
	end

	self:UpdateGameplayState()

	if self.timer >= self.duration then
		self:CompleteFloorIntro()
	end

	return true
end

return TransitionManager
