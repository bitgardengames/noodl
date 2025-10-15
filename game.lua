local Audio = require("audio")
local Screen = require("screen")
local Controls = require("controls")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Easing = require("easing")
local Face = require("face")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Popup = require("popup")
local Score = require("score")
local PauseMenu = require("pausemenu")
local Movement = require("movement")
local Particles = require("particles")
local UpgradeVisuals = require("upgradevisuals")
local Achievements = require("achievements")
local FloatingText = require("floatingtext")
local Arena = require("arena")
local UI = require("ui")
local Theme = require("theme")
local FruitEvents = require("fruitevents")
local Shaders = require("shaders")
local Settings = require("settings")
local GameUtils = require("gameutils")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Death = require("death")
local Floors = require("floors")
local Shop = require("shop")
local Upgrades = require("upgrades")
local Localization = require("localization")
local FloorSetup = require("floorsetup")
local TransitionManager = require("transitionmanager")
local GameInput = require("gameinput")
local ModuleUtil = require("moduleutil")
local Game = {}

local clamp01 = Easing.clamp01
local EaseOutExpo = Easing.EaseOutExpo

local function EaseOutCubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function EnsureTransitionTitleCanvas(self)
	local width = math.max(1, math.ceil(self.ScreenWidth or love.graphics.getWidth() or 1))
	local height = math.max(1, math.ceil(self.ScreenHeight or love.graphics.getHeight() or 1))
	local canvas = self.TransitionTitleCanvas
	if not canvas or canvas:getWidth() ~= width or canvas:getHeight() ~= height then
		canvas = love.graphics.newCanvas(width, height)
		canvas:setFilter("linear", "linear")
		self.TransitionTitleCanvas = canvas
	end
	return canvas
end

local RUN_ACTIVE_STATES = {
	playing = true,
	descending = true,
}

local ENTITY_UPDATE_ORDER = ModuleUtil.PrepareSystems({
	Face,
	Popup,
	Fruit,
	Rocks,
	Lasers,
	Darts,
	Saws,
	Arena,
	Particles,
	UpgradeVisuals,
	Achievements,
	FloatingText,
	Score,
})

local function CloneColor(color, fallback)
	local source = color or fallback
	if not source then
		return nil
	end

	return {
		source[1] or 1,
		source[2] or 1,
		source[3] or 1,
		source[4] == nil and 1 or source[4],
	}
end

local function ResetFeedbackState(self)
	self.feedback = {
		ImpactTimer = 0,
		ImpactDuration = 0.36,
		ImpactPeak = 0,
		SurgeTimer = 0,
		SurgeDuration = 0.78,
		SurgePeak = 0,
		PanicTimer = 0,
		PanicDuration = 2.6,
		DangerLevel = 0,
		DangerPulseTimer = 0,
		PanicBurst = 0,
		ImpactRipple = nil,
		SurgeRipple = nil,
	}
	self.HitStop = nil
end

local function EnsureFeedbackState(self)
	if not self.feedback then
		ResetFeedbackState(self)
	end

	return self.feedback
end

local function UpdateFeedbackState(self, dt)
	if not dt or dt <= 0 then
		return
	end

	local state = EnsureFeedbackState(self)

	state.impactTimer = math.max(0, (state.impactTimer or 0) - dt)
	state.surgeTimer = math.max(0, (state.surgeTimer or 0) - dt)
	state.panicTimer = math.max(0, (state.panicTimer or 0) - dt)
	state.dangerPulseTimer = (state.dangerPulseTimer or 0) + dt

	if (state.impactTimer or 0) <= 0 then
		state.impactRipple = nil
	end

	if (state.surgeTimer or 0) <= 0 then
		state.surgeRipple = nil
	end

	local TargetDanger = 0
	if (state.panicTimer or 0) > 0 and (state.panicDuration or 0) > 0 then
		TargetDanger = math.max(0, math.min(1, (state.panicTimer or 0) / state.panicDuration))
	end

	local smoothing = math.min(dt * 4.5, 1)
	state.dangerLevel = (state.dangerLevel or 0) + (TargetDanger - (state.dangerLevel or 0)) * smoothing

	local ImpactDecay = math.min(dt * 2.6, 1)
	state.impactPeak = math.max(0, (state.impactPeak or 0) - ImpactDecay)

	local SurgeDecay = math.min(dt * 1.8, 1)
	state.surgePeak = math.max(0, (state.surgePeak or 0) - SurgeDecay)

	state.panicBurst = math.max(0, (state.panicBurst or 0) - dt * 0.9)
end

local function DrawFeedbackOverlay(self)
	local state = self.feedback
	if not state then
		return
	end

	local ScreenW = self.ScreenWidth or love.graphics.getWidth()
	local ScreenH = self.ScreenHeight or love.graphics.getHeight()

	local ImpactTimer = state.impactTimer or 0
	local ImpactDuration = state.impactDuration or 1
	local ImpactPeak = state.impactPeak or 0

	if ImpactTimer > 0 and ImpactPeak > 0 then
		local progress = math.max(0, math.min(1, ImpactTimer / ImpactDuration))
		local intensity = ImpactPeak * (progress ^ 0.7)
		local age = 1 - progress

		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		love.graphics.setColor(1, 1, 1, 0.22 * intensity)
		love.graphics.rectangle("fill", -12, -12, ScreenW + 24, ScreenH + 24)

		love.graphics.setColor(1, 0.78, 0.45, 0.32 * intensity)
		local inset = 10 + intensity * 8
		love.graphics.setLineWidth(3 + intensity * 6)
		love.graphics.rectangle("line", inset, inset, ScreenW - inset * 2, ScreenH - inset * 2, 28, 28)

		local ripple = state.impactRipple
		if ripple then
			local rx = ripple.x or ScreenW * 0.5
			local ry = ripple.y or ScreenH * 0.5
			local BaseRadius = ripple.baseRadius or 52
			local color = ripple.color or { 1, 0.42, 0.32, 1 }
			local RingRadius = BaseRadius + EaseOutExpo(age) * (140 + intensity * 80)
			local FillRadius = BaseRadius * (0.55 + age * 0.6)

			love.graphics.setLineWidth(2.5 + intensity * 4)
			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.55 * intensity)
			love.graphics.circle("line", rx, ry, RingRadius, 64)

			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.22 * intensity)
			love.graphics.circle("fill", rx, ry, FillRadius, 48)
		end

		love.graphics.pop()
	end

	local SurgeTimer = state.surgeTimer or 0
	local SurgeDuration = state.surgeDuration or 1
	local SurgePeak = state.surgePeak or 0
	if SurgeTimer > 0 and SurgePeak > 0 then
		local progress = math.max(0, math.min(1, SurgeTimer / SurgeDuration))
		local intensity = SurgePeak * (progress ^ 0.8)
		local expansion = 1 - progress

		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		local radius = math.sqrt(ScreenW * ScreenW + ScreenH * ScreenH)
		love.graphics.setColor(1, 0.9, 0.5, 0.22 * intensity)
		love.graphics.setLineWidth(2 + intensity * 6)
		love.graphics.circle("line", ScreenW * 0.5, ScreenH * 0.5, radius * (0.6 + expansion * 0.26), 64)
		local ripple = state.surgeRipple
		if ripple then
			local rx = ripple.x or ScreenW * 0.5
			local ry = ripple.y or ScreenH * 0.5
			local BaseRadius = ripple.baseRadius or 48
			local color = ripple.color or { 1, 0.9, 0.55, 1 }
			local eased = EaseOutCubic(1 - progress)
			local RingRadius = BaseRadius + eased * (160 + intensity * 90)
			love.graphics.setLineWidth(2 + intensity * 4)
			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.35 * intensity)
			love.graphics.circle("line", rx, ry, RingRadius, 72)

			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.18 * intensity)
			love.graphics.circle("fill", rx, ry, BaseRadius * (0.4 + eased * 0.6), 48)
		end

		love.graphics.pop()
	end

	local BaseDanger = state.dangerLevel or 0
	local burst = state.panicBurst or 0
	local danger = math.max(BaseDanger, burst * 0.7)
	if danger > 0 then
		local PulseTimer = state.dangerPulseTimer or 0
		local pulse = 0.5 + 0.5 * math.sin(PulseTimer * (4.6 + danger * 3.2))
		love.graphics.push("all")
		love.graphics.setColor(0.45, 0.03, 0.08, 0.4 * danger + 0.22 * pulse * danger)
		love.graphics.rectangle("fill", -14, -14, ScreenW + 28, ScreenH + 28)

		local OutlineAlpha = math.min(0.78, 0.35 + danger * 0.45 + burst * 0.35)
		love.graphics.setColor(0.95, 0.1, 0.22, OutlineAlpha)
		local thickness = 16 + danger * 28
		love.graphics.setLineWidth(thickness)
		love.graphics.rectangle("line", thickness * 0.5, thickness * 0.5, ScreenW - thickness, ScreenH - thickness, 32, 32)
		love.graphics.pop()
	end
end

local function ResolveFeedbackPosition(self, options)
	if not options then
		options = {}
	end

	local x = options.hitX or options.x or options.headX or options.snakeX
	local y = options.hitY or options.y or options.headY or options.snakeY

	if not (x and y) and Snake and Snake.GetHead then
		x, y = Snake:GetHead()
	end

	if not (x and y) then
		local w = self.ScreenWidth or love.graphics.getWidth() or 0
		local h = self.ScreenHeight or love.graphics.getHeight() or 0
		x = w * 0.5
		y = h * 0.5
	end

	return x, y
end

local EnsureHitStopState

function Game:ApplyHitStop(intensity, duration)
	intensity = math.max(intensity or 0, 0)
	duration = math.max(duration or 0, 0)

	if intensity <= 0 or duration <= 0 then
		return
	end

	local state = EnsureHitStopState(self)
	state.timer = math.max(state.timer or 0, duration)
	state.duration = math.max(state.duration or 0, duration)
	state.intensity = math.min(0.95, math.max(state.intensity or 0, intensity))
end

function Game:TriggerImpactFeedback(strength, options)
	local state = EnsureFeedbackState(self)
	strength = math.max(strength or 0, 0)

	local duration = 0.28 + strength * 0.24
	state.impactDuration = duration
	state.impactTimer = duration

	local spike = 0.55 + strength * 0.65
	state.impactPeak = math.min(1.25, math.max(state.impactPeak or 0, spike))
	state.panicBurst = math.min(1.35, (state.panicBurst or 0) + 0.35 + strength * 0.4)

	local ImpactRipple = state.impactRipple or {}
	local rx, ry = ResolveFeedbackPosition(self, options)
	ImpactRipple.x = rx
	ImpactRipple.y = ry
	ImpactRipple.baseRadius = (options and options.radius) or ImpactRipple.baseRadius or 54
	ImpactRipple.color = CloneColor(options and options.color, { 1, 0.42, 0.32, 1 })
	state.impactRipple = ImpactRipple

	local HitStopStrength = 0.3 + strength * 0.35
	local HitStopDuration = 0.08 + strength * 0.08
	self:ApplyHitStop(HitStopStrength, HitStopDuration)

	if Shaders and Shaders.notify then
		Shaders.notify("SpecialEvent", {
			type = "danger",
			strength = math.min(1.2, 0.45 + strength * 0.55),
		})
	end
end

function Game:TriggerPanicFeedback(strength)
	local state = EnsureFeedbackState(self)
	strength = math.max(strength or 0, 0)

	local BaseDuration = state.panicDuration or 2.6
	local duration = BaseDuration * (0.55 + strength * 0.5)
	state.panicTimer = math.max(state.panicTimer or 0, duration)
	state.panicBurst = math.min(1.5, (state.panicBurst or 0) + 0.5 + strength * 0.5)
	state.dangerPulseTimer = 0
end

function Game:TriggerSurgeFeedback(strength, options)
	local state = EnsureFeedbackState(self)
	strength = math.max(strength or 0, 0)

	local duration = 0.6 + strength * 0.4
	state.surgeDuration = duration
	state.surgeTimer = duration
	local SurgeSpike = 0.45 + strength * 0.55
	state.surgePeak = math.min(1.15, math.max(state.surgePeak or 0, SurgeSpike))

	local ripple = state.surgeRipple or {}
	local rx, ry = ResolveFeedbackPosition(self, options)
	ripple.x = rx
	ripple.y = ry
	ripple.baseRadius = (options and options.radius) or ripple.baseRadius or 48
	ripple.color = CloneColor(options and options.color, { 1, 0.9, 0.55, 1 })
	state.surgeRipple = ripple

	if Shaders and Shaders.notify then
		Shaders.notify("SpecialEvent", {
			type = "tension",
			strength = math.min(1.0, 0.3 + strength * 0.45),
		})
	end
end

local CachedMouseInterface
local MouseSupportChecked = false

local function IsCursorSupported(mouse)
	local checker = mouse and mouse.isCursorSupported
	if not checker then
		return true
	end

	local ok, supported = pcall(checker)
	if not ok then
		return false
	end

	if supported == nil then
		return true
	end

	return supported and true or false
end

local function GetMouseInterface()
	if MouseSupportChecked then
		return CachedMouseInterface
	end

	MouseSupportChecked = true

	if not love or not love.mouse then
		CachedMouseInterface = nil
		return nil
	end

	local mouse = love.mouse
	if not mouse.setVisible or not IsCursorSupported(mouse) then
		CachedMouseInterface = nil
		return nil
	end

	CachedMouseInterface = mouse
	return CachedMouseInterface
end

local function GetMouseVisibility(mouse)
	if mouse and mouse.isVisible then
		local ok, visible = pcall(mouse.isVisible)
		if ok and visible ~= nil then
			return visible and true or false
		end
	end

	return true
end

EnsureHitStopState = function(self)
	if not self.HitStop then
		self.HitStop = {
			timer = 0,
			duration = 0,
			intensity = 0,
		}
	end

	return self.HitStop
end

local function UpdateHitStopState(self, dt)
	local state = self.HitStop
	if not state then
		return
	end

	state.timer = math.max(0, (state.timer or 0) - (dt or 0))
	if state.timer <= 0 then
		self.HitStop = nil
	end
end

local function ResolveHitStopScale(self)
	local state = self.HitStop
	if not state then
		return 1
	end

	local timer = state.timer or 0
	local duration = state.duration or 0
	local intensity = state.intensity or 0

	if timer <= 0 or duration <= 0 or intensity <= 0 then
		return 1
	end

	local progress = math.max(0, math.min(1, timer / duration))
	local slow = 1 - EaseOutCubic(progress) * math.min(intensity, 0.95)
	return math.max(0.1, slow)
end

local function ResolveMouseVisibilityTarget(self)
	if not GetMouseInterface() then
		return nil
	end

	local transition = self.transition
	local InShop = transition and transition:isShopActive()
	if InShop then
		return true
	end

	if RUN_ACTIVE_STATES[self.state] == true then
		return false
	end

	return nil
end

function Game:ReleaseMouseVisibility()
	local state = self.MouseCursorState
	if not state then
		return
	end

	local mouse = state.interface or GetMouseInterface()
	if mouse and mouse.setVisible then
		local restore = state.originalVisible
		if restore == nil then
			restore = true
		end
		mouse.setVisible(restore and true or false)
	end

	self.MouseCursorState = nil
end

function Game:UpdateMouseVisibility()
	local mouse = GetMouseInterface()
	if not mouse then
		self:ReleaseMouseVisibility()
		return
	end

	local TargetVisible = ResolveMouseVisibilityTarget(self)
	if TargetVisible == nil then
		self:ReleaseMouseVisibility()
		return
	end

	local state = self.MouseCursorState
	if not state then
		local CurrentVisible = GetMouseVisibility(mouse)
		state = {
			interface = mouse,
			OriginalVisible = CurrentVisible,
			CurrentVisible = CurrentVisible,
		}
		self.MouseCursorState = state
	end

	if state.currentVisible ~= TargetVisible then
		mouse.setVisible(TargetVisible and true or false)
		state.currentVisible = TargetVisible
	end
end

function Game:IsTransitionActive()
	local transition = self.transition
	return transition ~= nil and transition:isActive()
end

function Game:ConfirmTransitionIntro()
	local transition = self.transition
	if not transition then
		return false
	end

	return transition:confirmFloorIntro() and true or false
end

local function GetScaledDeltaTime(self, dt)
	if not dt then
		return dt
	end

	local scale = 1
	if Snake and Snake.GetTimeScale then
		local SnakeScale = Snake:GetTimeScale()
		if SnakeScale and SnakeScale > 0 then
			scale = SnakeScale
		end
	end

	scale = scale * ResolveHitStopScale(self)

	return dt * scale
end

local function UpdateRunTimers(self, dt)
	if RUN_ACTIVE_STATES[self.state] then
		SessionStats:add("TimeAlive", dt)
		self.RunTimer = (self.RunTimer or 0) + dt
	end

	if self.state == "playing" then
		self.FloorTimer = (self.FloorTimer or 0) + dt
	end
end

local function UpdateSystems(systems, dt)
	ModuleUtil.RunHook(systems, "update", dt)
end

local function UpdateGlobalSystems(dt)
	FruitEvents.update(dt)
	Shaders.update(dt)
end

local function HandlePauseMenu(game, dt)
	local paused = game.state == "paused"
	local FloorName = nil
	if game.currentFloorData then
		FloorName = game.currentFloorData.name
	end
	PauseMenu:update(dt, paused, game.floor, FloorName)
	return paused
end

local function ForwardShopInput(game, EventName, ...)
	local input = game.input
	if not input or not input.handleShopInput then
		return false
	end

	return input:handleShopInput(EventName, ...)
end

local function DrawShadowedText(font, text, x, y, width, align, alpha)
	if alpha <= 0 then
		return
	end

	love.graphics.setFont(font)
	local shadow = Theme.ShadowColor or { 0, 0, 0, 0.5 }
	local ShadowAlpha = (shadow[4] or 1) * alpha
	love.graphics.setColor(shadow[1], shadow[2], shadow[3], ShadowAlpha)
	love.graphics.printf(text, x + 2, y + 2, width, align)

	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.printf(text, x, y, width, align)
end

local STATE_UPDATERS = {
	descending = function(self, dt)
		self:UpdateDescending(dt)
		return true
	end,
}

local function DrawAdrenalineGlow(self)
	local GlowStrength = Score:GetHighScoreGlowStrength()

	if Snake.adrenaline and Snake.adrenaline.active then
		local duration = Snake.adrenaline.duration or 1
		if duration > 0 then
			local AdrenalineStrength = math.max(0, math.min(1, (Snake.adrenaline.timer or 0) / duration))
			GlowStrength = math.max(GlowStrength, AdrenalineStrength * 0.85)
		end
	end

	if GlowStrength <= 0 then return end

        local time = love.timer.getTime()
	local pulse = 0.85 + 0.15 * math.sin(time * 2.25)
	local EasedStrength = 0.6 + GlowStrength * 0.4
	local alpha = 0.18 * EasedStrength * pulse

	love.graphics.push("all")
	love.graphics.setBlendMode("add")
	love.graphics.setColor(0.65, 0.82, 0.95, alpha)
	love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)
	love.graphics.pop()
end

function Game:load(options)
	options = options or {}

	local RequestedFloor = math.max(1, math.floor(options.startFloor or 1))
	local TotalFloors = #Floors
	if TotalFloors > 0 then
		RequestedFloor = math.min(RequestedFloor, TotalFloors)
	end

	self.state = "playing"
	self.StartFloor = RequestedFloor
	self.floor = RequestedFloor
	self.RunTimer = 0
	self.FloorTimer = 0

	self.MouseCursorState = nil

	Screen:update()
	self.ScreenWidth, self.ScreenHeight = Screen:get()
	Arena:UpdateScreenBounds(self.ScreenWidth, self.ScreenHeight)

	Score:load()
	Upgrades:BeginRun()
	GameUtils:PrepareGame(self.ScreenWidth, self.ScreenHeight)
	Face:set("idle")

	self.transition = TransitionManager.new(self)
	self.input = GameInput.new(self, self.transition)
	self.input:ResetAxes()

	ResetFeedbackState(self)

	self.SingleTouchDeath = true

	if Snake.adrenaline then
		Snake.adrenaline.active = false
	end

	self:SetupFloor(self.floor)

	self.transition:StartFloorIntro(2.8, {
		TransitionAdvance = false,
		TransitionAwaitInput = true,
		TransitionFloorData = Floors[self.floor] or Floors[1],
	})
end

function Game:reset()
	GameUtils:PrepareGame(self.ScreenWidth, self.ScreenHeight)
	Face:set("idle")
	self.state = "playing"
	self.floor = self.StartFloor or 1
	self.RunTimer = 0
	self.FloorTimer = 0

	self.MouseCursorState = nil

	ResetFeedbackState(self)

	if self.transition then
		self.transition:reset()
	end

	if self.input then
		self.input:ResetAxes()
	end
end

function Game:enter(data)
	UI.ClearButtons()
	self:load(data)

	Audio:PlayMusic("game")
	SessionStats:reset()
	PlayerStats:add("SessionsPlayed", 1)

	Achievements:CheckAll({
		SessionsPlayed = PlayerStats:get("SessionsPlayed"),
	})

	self:UpdateMouseVisibility()
end

function Game:leave()
	self:ReleaseMouseVisibility()

	if Snake and Snake.ResetModifiers then
		Snake:ResetModifiers()
	end

	if UI and UI.SetUpgradeIndicators then
		UI:SetUpgradeIndicators(nil)
	end
end

function Game:BeginDeath()
	if self.state ~= "dying" then
		self.state = "dying"
		if Snake and Snake.SetDead then
			Snake:SetDead(true)
		end
		local trail = Snake:GetSegments()
		Death:SpawnFromSnake(trail, SnakeUtils.SEGMENT_SIZE)
		Audio:PlaySound("death")
	end
end

function Game:ApplyDamage(amount, cause, context)
	local inflicted = math.floor((amount or 0) + 0.0001)
	if inflicted < 0 then
		inflicted = 0
	end

	if context then
		context.inflictedDamage = inflicted
	end

	if inflicted <= 0 then
		return true
	end

	local ImpactStrength = math.max(0.35, ((context and context.shake) or 0) + inflicted * 0.12)

	if Snake and Snake.OnDamageTaken then
		Snake:OnDamageTaken(cause, context)
	end

	self:TriggerImpactFeedback(ImpactStrength, context)

	if Settings.ScreenShake ~= false and context and context.shake and self.Effects and self.Effects.shake then
		self.Effects:shake(context.shake)
	end

	return false
end

function Game:StartDescending(HoleX, HoleY, HoleRadius)
	self.state = "descending"
	self.hole = { x = HoleX, y = HoleY, radius = HoleRadius or 24 }
	Snake:StartDescending(self.hole.x, self.hole.y, self.hole.radius)
	Audio:PlaySound("exit_enter")
end

-- start a floor transition
function Game:StartFloorTransition(advance, SkipFade)
	Snake:FinishDescending()
	self.transition:StartFloorTransition(advance, SkipFade)
end

function Game:TriggerVictory()
	if self.state == "victory" then
		return
	end

	Snake:FinishDescending()
	if Arena and Arena.ResetExit then
		Arena:ResetExit()
	end

	local FloorTime = self.FloorTimer or 0
	if FloorTime and FloorTime > 0 then
		SessionStats:add("TotalFloorTime", FloorTime)
		SessionStats:UpdateMin("FastestFloorClear", FloorTime)
		SessionStats:UpdateMax("SlowestFloorClear", FloorTime)
		SessionStats:set("LastFloorClearTime", FloorTime)
	end
	self.FloorTimer = 0

	local CurrentFloor = self.floor or 1
	local NextFloor = CurrentFloor + 1
	PlayerStats:add("FloorsCleared", 1)
	PlayerStats:UpdateMax("DeepestFloorReached", NextFloor)
	SessionStats:add("FloorsCleared", 1)
	SessionStats:UpdateMax("DeepestFloorReached", NextFloor)

	Audio:PlaySound("floor_advance")

	local FloorData = Floors[CurrentFloor] or {}
	local FloorName = FloorData.name or string.format("Floor %d", CurrentFloor)
	local EndingMessage = Localization:get("gameover.victory_story_body", { floor = FloorName })
	if EndingMessage == "gameover.victory_story_body" then
		EndingMessage = Floors.VictoryMessage or string.format("With the festival feast safely reclaimed from %s, Noodl rockets home to start the parade.", FloorName)
	end

	local StoryTitle = Localization:get("gameover.victory_story_title")
	if StoryTitle == "gameover.victory_story_title" then
		StoryTitle = Floors.StoryTitle or "Noodl's Grand Feast"
	end

	local result = Score:HandleRunClear({
		EndingMessage = EndingMessage,
		StoryTitle = StoryTitle,
	})

	Achievements:save()

	self.VictoryResult = result
	self.VictoryTimer = 0
	self.VictoryDelay = 1.2
	self.state = "victory"
end

function Game:StartFloorIntro(duration, extra)
	self.transition:StartFloorIntro(duration, extra)
end

function Game:StartFadeIn(duration)
	self.transition:StartFadeIn(duration)
end

function Game:UpdateDescending(dt)
	Snake:update(dt)

	-- Keep saw blades animating while the snake descends into the exit hole
	if Saws and Saws.update then
		Saws:update(dt)
	end

	local segments = Snake:GetSegments()
	local tail = segments[#segments]
	if not tail then
		Snake:FinishDescending()
		self:StartFloorTransition(true)
		return
	end

	local dx, dy = tail.drawX - self.hole.x, tail.drawY - self.hole.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < self.hole.radius then
		local FinalFloor = #Floors
		if (self.floor or 1) >= FinalFloor then
			self:TriggerVictory()
		else
			Snake:FinishDescending()
			self:StartFloorTransition(true)
		end
	end
end

function Game:UpdateGameplay(dt)
	local FruitX, FruitY = Fruit:GetPosition()

	if Upgrades and Upgrades.RecordFloorReplaySnapshot then
		Upgrades:RecordFloorReplaySnapshot(self)
	end

	local MoveResult, cause, context = Movement:update(dt)

	if MoveResult == "hit" then
		local damage = (context and context.damage) or 1
		local survived = self:ApplyDamage(damage, cause, context)
		if not survived then
			local ReplayTriggered = false
			if Upgrades and Upgrades.TryFloorReplay then
				ReplayTriggered = Upgrades:TryFloorReplay(self, cause)
			end
			if ReplayTriggered then
				return
			end
			self.DeathCause = cause
			self:BeginDeath()
		end
		return
	elseif MoveResult == "dead" then
		local ReplayTriggered = false
		if Upgrades and Upgrades.TryFloorReplay then
			ReplayTriggered = Upgrades:TryFloorReplay(self, cause)
		end
		if ReplayTriggered then
			return
		end
		self.DeathCause = cause
		self:BeginDeath()
		return
	end

	if MoveResult == "scored" then
		FruitEvents.HandleConsumption(FruitX, FruitY)

		local GoalReached = UI:IsGoalReached()
		if GoalReached then
			Arena:SpawnExit()
		end

		-- Removed surge feedback when collecting fruit to eliminate the outward ring effect.
	end

	local SnakeX, SnakeY = Snake:GetHead()
	if Arena:CheckExitCollision(SnakeX, SnakeY) then
		local hx, hy, hr = Arena:GetExitCenter()
		if hx and hy then
			self:StartDescending(hx, hy, hr)
		end
	end
end

function Game:UpdateEntities(dt)
	UpdateSystems(ENTITY_UPDATE_ORDER, dt)
end

function Game:HandleDeath(dt)
	if self.state ~= "dying" then
		return
	end

	Death:update(dt)
	if not Death:IsFinished() then
		return
	end

	Achievements:save()
	local result = Score:HandleGameOver(self.DeathCause)
	if result then
		return { state = "gameover", data = result }
	end
end

local function DrawPlayfieldLayers(self, StateOverride)
	local RenderState = StateOverride or self.state

	Arena:DrawBackground()
	Death:ApplyShake()

	Fruit:draw()
	Rocks:draw()
	Lasers:draw()
	Darts:draw()
	Saws:draw()

	local IsDescending = (RenderState == "descending")
	local ShouldDrawExitAfterSnake = (not IsDescending and RenderState ~= "dying" and RenderState ~= "gameover")

	if not IsDescending and not ShouldDrawExitAfterSnake then
		Arena:DrawExit()
	end

	if IsDescending then
		self:DrawDescending()
	elseif RenderState == "dying" then
		Death:draw()
	elseif RenderState ~= "gameover" then
		Snake:draw()
	end

	if ShouldDrawExitAfterSnake then
		Arena:DrawExit()
	end

	Particles:draw()
	UpgradeVisuals:draw()
	Popup:draw()
	Arena:DrawBorder()
end

local function DrawDeveloperAssistBadge(self)
	if not (Snake.IsDeveloperAssistEnabled and Snake:IsDeveloperAssistEnabled()) then
		return
	end

	local fonts = UI and UI.fonts
	local BadgeFont = fonts and (fonts.caption or fonts.prompt or fonts.body)
	local PreviousFont = love.graphics.getFont()
	if BadgeFont then
		love.graphics.setFont(BadgeFont)
	else
		BadgeFont = PreviousFont
	end

	local label = "DEV ASSIST ENABLED (F1)"
	local TextWidth = BadgeFont and BadgeFont:getWidth(label) or (#label * 7)
	local TextHeight = BadgeFont and BadgeFont:getHeight() or 16
	local PaddingX = 16
	local PaddingY = 10
	local margin = 24
	local BoxWidth = TextWidth + PaddingX * 2
	local BoxHeight = TextHeight + PaddingY * 2
	local x = (self.ScreenWidth or 0) - BoxWidth - margin
	local y = margin

	love.graphics.setColor(0.1, 0.14, 0.21, 0.72)
	love.graphics.rectangle("fill", x, y, BoxWidth, BoxHeight, 10, 10)

	love.graphics.setColor(0.28, 0.42, 0.58, 0.9)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, BoxWidth, BoxHeight, 10, 10)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(0.85, 0.97, 1, 1)
	love.graphics.print(label, x + PaddingX, y + PaddingY)

	love.graphics.setColor(1, 1, 1, 1)
	if PreviousFont then
		love.graphics.setFont(PreviousFont)
	end
end

local function DrawInterfaceLayers(self)
	FloatingText:draw()

	DrawAdrenalineGlow(self)

	DrawFeedbackOverlay(self)

	Death:DrawFlash(self.ScreenWidth, self.ScreenHeight)
	PauseMenu:draw(self.ScreenWidth, self.ScreenHeight)
	UI:draw()
	DrawDeveloperAssistBadge(self)
	Achievements:draw()
end

local function DrawTransitionFadeOut(self, timer, duration)
	DrawPlayfieldLayers(self)
	DrawInterfaceLayers(self)

	local progress
	if not duration or duration <= 0 then
		progress = 1
	else
		progress = clamp01(timer / duration)
	end

	love.graphics.setColor(0, 0, 0, progress)
	love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)
	love.graphics.setColor(1, 1, 1, 1)

	return true
end

local function DrawTransitionShop(self, _)
	love.graphics.setColor(0, 0, 0, 0.85)
	love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)
	love.graphics.setColor(1, 1, 1, 1)
	Shop:draw(self.ScreenWidth, self.ScreenHeight)

	return true
end

local function DrawTransitionNotes(self, timer, OutroAlpha, FadeAlpha)
	local notes = self.TransitionNotes
	if not (notes and #notes > 0) then
		return
	end

	local y = self.ScreenHeight / 2 + 64
	local width = self.ScreenWidth * 0.45
	local x = (self.ScreenWidth - width) / 2
	local ButtonFont = UI.fonts.button
	local BodyFont = UI.fonts.body

	for index, note in ipairs(notes) do
		local OffsetDelay = 0.9 + (index - 1) * 0.22
		local NoteAlpha
		local NoteOffset = 0

		if FadeAlpha then
			NoteAlpha = FadeAlpha(OffsetDelay, 0.4)
			NoteOffset = (1 - EaseOutExpo(clamp01((timer - OffsetDelay) / 0.55))) * 16 * (OutroAlpha or 1)
		else
			NoteAlpha = OutroAlpha or 1
		end

		if note.title and note.title ~= "" then
			DrawShadowedText(
				ButtonFont,
				note.title,
				x,
				y + NoteOffset,
				width,
				"center",
				NoteAlpha
			)
			y = y + ButtonFont:getHeight() + 6
		end

		if note.text and note.text ~= "" then
			DrawShadowedText(
				BodyFont,
				note.text,
				x,
				y + NoteOffset,
				width,
				"center",
				NoteAlpha
			)
			y = y + BodyFont:getHeight() + 10
		end
	end
end

local function DrawTransitionFloorIntro(self, timer, duration, data)
	local FloorData = data.transitionFloorData or self.CurrentFloorData
	if not FloorData then
		return
	end

	love.graphics.setColor(1, 1, 1, 1)
	DrawPlayfieldLayers(self, "playing")

	local TotalDuration = duration or 0
	local progress = TotalDuration > 0 and clamp01(timer / TotalDuration) or 1
	local AwaitingConfirm = data.transitionAwaitInput and not data.transitionIntroConfirmed
	local VisualProgress = progress
	if AwaitingConfirm then
		VisualProgress = math.min(VisualProgress, 0.7)
	end

	local AppearProgress = math.min(1, VisualProgress / 0.28)
	local appear = EaseOutCubic(AppearProgress)
	local DissolveProgress = VisualProgress > 0.48 and clamp01((VisualProgress - 0.48) / 0.4) or 0
	if AwaitingConfirm then
		DissolveProgress = 0
	end
	local OverlayAlpha = 0.8 * (1 - 0.55 * DissolveProgress)
	local HighlightAlpha = appear * (1 - DissolveProgress)

	love.graphics.setColor(0, 0, 0, OverlayAlpha)
	love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)

	local canvas = EnsureTransitionTitleCanvas(self)
	local shadow = Theme.ShadowColor or { 0, 0, 0, 0.5 }
	local TitleOffset = (1 - appear) * 36

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.origin()
	love.graphics.setBlendMode("alpha")

	love.graphics.setFont(UI.fonts.title)
	local TitleY = self.ScreenHeight / 2 - 90 + TitleOffset
	local ShadowAlpha = (shadow[4] or 0.5) * HighlightAlpha
	love.graphics.setColor(shadow[1], shadow[2], shadow[3], ShadowAlpha)
	love.graphics.printf(FloorData.name or "", 2, TitleY + 2, self.ScreenWidth, "center")
	love.graphics.setColor(1, 1, 1, HighlightAlpha)
	love.graphics.printf(FloorData.name or "", 0, TitleY, self.ScreenWidth, "center")

	if FloorData.flavor and FloorData.flavor ~= "" then
		love.graphics.setFont(UI.fonts.button)
		local FlavorY = TitleY + UI.fonts.title:GetHeight() + 32
		local FlavorAlpha = HighlightAlpha * 0.95
		love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 0.5) * FlavorAlpha)
		love.graphics.printf(FloorData.flavor, 2, FlavorY + 2, self.ScreenWidth, "center")
		love.graphics.setColor(1, 1, 1, FlavorAlpha)
		love.graphics.printf(FloorData.flavor, 0, FlavorY, self.ScreenWidth, "center")
	end

	if data.transitionAwaitInput then
		local PromptText = Localization:get("game.floor_intro.prompt")
		if PromptText and PromptText ~= "" then
			local PromptFont = UI.fonts.prompt or UI.fonts.body
			love.graphics.setFont(PromptFont)
			local PromptFade = 1 - clamp01((VisualProgress - 0.72) / 0.18)
			local PromptAlpha = HighlightAlpha * PromptFade
			local y = self.ScreenHeight - PromptFont:getHeight() * 2.2
			love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 0.5) * PromptAlpha)
			love.graphics.printf(PromptText, 2, y + 2, self.ScreenWidth, "center")
			love.graphics.setColor(1, 1, 1, PromptAlpha)
			love.graphics.printf(PromptText, 0, y, self.ScreenWidth, "center")
		end
	end

	love.graphics.setCanvas()
	love.graphics.pop()

	love.graphics.push("all")
	local CanvasAlpha = 1 - clamp01(DissolveProgress)
	love.graphics.setColor(1, 1, 1, CanvasAlpha)
	love.graphics.draw(canvas, 0, 0)
	love.graphics.pop()

	DrawTransitionNotes(self, 999, 1, nil)

	love.graphics.setColor(1, 1, 1, 1)

	return true
end

function Game:DrawTransition()
	if not self:IsTransitionActive() then
		return
	end

	local phase = self.transition:GetPhase()
	local timer = self.transition:GetTimer() or 0
	local duration = self.transition:GetDuration() or 0
	local data = self.transition:GetData() or {}

	if phase == "fadeout" then
		if DrawTransitionFadeOut(self, timer, duration) then
			return
		end
	elseif phase == "shop" then
		if DrawTransitionShop(self, timer) then
			return
		end
	elseif phase == "floorintro" then
		if DrawTransitionFloorIntro(self, timer, duration, data) then
			return
		end
	elseif phase == "fadein" then
		DrawPlayfieldLayers(self, "playing")
		DrawInterfaceLayers(self)

		local progress
		if not duration or duration <= 0 then
			progress = 1
		else
			progress = clamp01(timer / duration)
		end

		local alpha = 1 - progress
		love.graphics.setColor(0, 0, 0, alpha)
		love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function Game:DrawStateTransition(direction, progress, eased, alpha)
	local IsFloorTransition = false
	if self.transition and self.transition:IsActive() then
		local phase = self.transition:GetPhase()
		IsFloorTransition = phase ~= nil
	end

	if direction == "out" and not IsFloorTransition then
		return nil
	end

	self:draw()

	if IsFloorTransition then
		love.graphics.setColor(1, 1, 1, 1)
		return { SkipOverlay = true }
	end

	if direction == "in" then
		local width = self.ScreenWidth or love.graphics.getWidth()
		local height = self.ScreenHeight or love.graphics.getHeight()

		if alpha and alpha > 0 then
			love.graphics.setColor(0, 0, 0, alpha)
			love.graphics.rectangle("fill", 0, 0, width, height)
		end

		love.graphics.setColor(1, 1, 1, 1)
		return { SkipOverlay = true }
	end

	love.graphics.setColor(1, 1, 1, 1)
	return true
end

function Game:DrawDescending()
	if not self.hole then
		Snake:draw()
		Arena:DrawExit()
		return
	end

	local hx = self.hole.x
	local hy = self.hole.y
	local hr = self.hole.radius or 0

	Arena:DrawExit()

	local CoverRadius = hr * 0.92
	if CoverRadius <= 0 then
		CoverRadius = hr
	end

	if CoverRadius > 0 then
		love.graphics.setColor(0.05, 0.05, 0.05, 1)
		love.graphics.circle("fill", hx, hy, CoverRadius)

		love.graphics.setColor(0, 0, 0, 1)
		local PreviousLineWidth = love.graphics.getLineWidth()
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", hx, hy, CoverRadius)
		love.graphics.setLineWidth(PreviousLineWidth)
	end

	Snake:DrawClipped(hx, hy, hr)

	love.graphics.setColor(1, 1, 1, 1)
end

function Game:update(dt)
	self:UpdateMouseVisibility()

	local ScaledDt = GetScaledDeltaTime(self, dt)
	UpdateFeedbackState(self, ScaledDt)
	UpdateHitStopState(self, dt)

	if HandlePauseMenu(self, dt) then
		return
	end

	if self.state == "victory" then
		local delay = self.VictoryDelay or 0
		self.VictoryTimer = (self.VictoryTimer or 0) + ScaledDt

		if self.VictoryTimer >= delay then
			local summary = self.VictoryResult or Score:HandleRunClear()
			return { state = "gameover", data = summary }
		end

		return
	end

	UpdateRunTimers(self, ScaledDt)

	UpdateGlobalSystems(ScaledDt)

	local transition = self.transition
	local TransitionBlocking = false
	if transition and transition:isActive() then
		transition:update(ScaledDt)
		TransitionBlocking = transition.isGameplayBlocked and transition:isGameplayBlocked()
	end

	if TransitionBlocking then
		return
	end

	local StateHandler = STATE_UPDATERS[self.state]
	if StateHandler and StateHandler(self, ScaledDt) then
		return
	end

	if self.state == "playing" then
		self:UpdateGameplay(ScaledDt)
	end

	self:UpdateEntities(ScaledDt)
	UI:SetUpgradeIndicators(Upgrades:GetHUDIndicators())

	local result = self:HandleDeath(ScaledDt)
	if result then
		return result
	end
end

function Game:SetupFloor(FloorNum)
	self.CurrentFloorData = Floors[FloorNum] or Floors[1]

	FruitEvents.reset()

	self.FloorTimer = 0

	local setup = FloorSetup.prepare(FloorNum, self.CurrentFloorData)
	local TraitContext = setup.traitContext
	local SpawnPlan = setup.spawnPlan

	UI:SetFruitGoal(TraitContext.fruitGoal)

	self.TransitionNotes = nil

	Upgrades:ApplyPersistentEffects(true)

	if Snake.adrenaline then
		Snake.adrenaline.active = false
		Snake.adrenaline.timer = 0
	end

	FloorSetup.FinalizeContext(TraitContext, SpawnPlan)
	Upgrades:notify("FloorStart", { floor = FloorNum, context = TraitContext })

	FloorSetup.SpawnHazards(SpawnPlan)
end

function Game:draw()
	love.graphics.clear()

	if Arena.DrawBackdrop then
		Arena:DrawBackdrop(self.ScreenWidth, self.ScreenHeight)
	else
		love.graphics.setColor(Theme.BgColor)
		love.graphics.rectangle("fill", 0, 0, self.ScreenWidth, self.ScreenHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end

	if self:IsTransitionActive() then
		self:DrawTransition()
		return
	end

	DrawPlayfieldLayers(self)
	DrawInterfaceLayers(self)
end

function Game:keypressed(key)
	if ForwardShopInput(self, "keypressed", key) then
		return
	end

	if self:ConfirmTransitionIntro() then
		return
	end

	Controls:keypressed(self, key)
end

function Game:mousepressed(x, y, button)
	if self:ConfirmTransitionIntro() then
		return
	end

	if self.state == "paused" then
		PauseMenu:mousepressed(x, y, button)
		return
	end

	ForwardShopInput(self, "mousepressed", x, y, button)
end

function Game:mousereleased(x, y, button)
	if self.state ~= "paused" or button ~= 1 then
		return
	end

	local selection = PauseMenu:mousereleased(x, y, button)
	if not selection then
		return
	end

	if self.input then
		return self.input:ApplyPauseMenuSelection(selection)
	end
end

function Game:gamepadpressed(_, button)
	if self:ConfirmTransitionIntro() then
		return
	end

	if self.input then
		return self.input:HandleGamepadButton(button)
	end
end
Game.joystickpressed = Game.gamepadpressed

function Game:gamepadaxis(_, axis, value)
	if self.input then
		return self.input:HandleGamepadAxis(axis, value)
	end
end
Game.joystickaxis = Game.gamepadaxis

return Game
