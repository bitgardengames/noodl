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
local Bombs = require("bombs")
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
local RenderLayers = require("renderlayers")
local Timer = require("timer")
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin
local sqrt = math.sqrt

local EMPTY_TABLE = {}

local Game = {}

local clamp01 = Easing.clamp01
local easeOutExpo = Easing.easeOutExpo

local currentGame
local currentRenderState

local DEATH_HOLD_DURATION = 0.5
local DEFAULT_SHADOW_COLOR = {0, 0, 0, 0.5}
local DEFAULT_IMPACT_RIPPLE_COLOR = {1, 0.42, 0.32, 1}
local DEFAULT_SURGE_RIPPLE_COLOR = {1, 0.9, 0.55, 1}

local function drawBackgroundLayer()
        Arena:drawBackground()
end

local function drawOverlayLayer()
        if Arena.drawDimLighting then
                Arena:drawDimLighting()
        end

        if Arena.drawQueuedExit then
                Arena:drawQueuedExit()
        end

        Arena:drawBorder()
end

local function drawMainLayer()
        local game = currentGame
        local renderState = currentRenderState

        if not game then
                return
        end

        Fruit:draw()
        Rocks:draw()
        Saws:draw()
        Darts:draw()
        Lasers:draw()

        local isDescending = (renderState == "descending")
        local shouldDrawExitAfterSnake = (not isDescending and renderState ~= "dying" and renderState ~= "gameover")

        if not isDescending and not shouldDrawExitAfterSnake then
                Arena:drawExit()
        end

        if isDescending then
                game:drawDescending()
        elseif renderState == "dying" then
                Death:draw()
        elseif renderState ~= "gameover" then
                Snake:draw()
        end

        if shouldDrawExitAfterSnake then
                Arena:drawExit()
        end

        Particles:draw()
        Bombs:draw()
        UpgradeVisuals:draw()
        Popup:draw()

        RenderLayers:withLayer("overlay", drawOverlayLayer)
end

local function easeOutCubic(t)
        local inv = 1 - t
        return 1 - inv * inv * inv
end

local function clamp(value, minimum, maximum)
        if value < minimum then
                return minimum
        elseif value > maximum then
                return maximum
        end
        return value
end

local function circleSegments(radius)
        return clamp(ceil(radius / 6), 12, 48)
end

local function updateScreenDimensions(self, width, height)
        if width == nil or height == nil then
                width = width or love.graphics.getWidth()
                height = height or love.graphics.getHeight()
        end

        if width == nil or height == nil then
                self.screenWidth = width
                self.screenHeight = height
                self.screenDiagonal = nil
                return false
        end

        if width == self.screenWidth and height == self.screenHeight and self.screenDiagonal then
                return false
        end

        self.screenWidth = width
        self.screenHeight = height
        self.screenDiagonal = sqrt(width * width + height * height)

        return true
end

local function ensureTransitionTitleCanvas(self)
        local width = max(1, ceil(self.screenWidth or love.graphics.getWidth() or 1))
        local height = max(1, ceil(self.screenHeight or love.graphics.getHeight() or 1))
        local canvas = self.transitionTitleCanvas
        if not canvas or canvas:getWidth() ~= width or canvas:getHeight() ~= height then
                canvas = love.graphics.newCanvas(width, height)
                canvas:setFilter("linear", "linear")
                self.transitionTitleCanvas = canvas
        end
        return canvas
end

function Game:invalidateTransitionTitleCache()
        if self.transitionTitleCache then
                self.transitionTitleCache = nil
        end
        if self.transitionPromptCanvas then
                self.transitionPromptCanvas = nil
        end
end

function Game:refreshTransitionTitleCanvas(data)
        local floorData = data and (data.transitionFloorData or self.currentFloorData) or self.currentFloorData
        if not floorData then
                self:invalidateTransitionTitleCache()
                return nil
        end

        local promptText
        if data and data.transitionAwaitInput then
                promptText = Localization:get("game.floor_intro.prompt")
                if not promptText or promptText == "" then
                        promptText = nil
                end
        end

        local titleCanvas = ensureTransitionTitleCanvas(self)
        local width = titleCanvas:getWidth()
        local height = titleCanvas:getHeight()

        local promptCanvas = nil
        if promptText then
                promptCanvas = self.transitionPromptCanvas
                if not promptCanvas or promptCanvas:getWidth() ~= width or promptCanvas:getHeight() ~= height then
                        promptCanvas = love.graphics.newCanvas(width, height)
                        promptCanvas:setFilter("linear", "linear")
                        self.transitionPromptCanvas = promptCanvas
                end
        else
                self.transitionPromptCanvas = nil
        end

        local cache = self.transitionTitleCache
        if cache
                and cache.canvas == titleCanvas
                and cache.floorData == floorData
                and cache.promptText == promptText
                and cache.width == width
                and cache.height == height
                and cache.promptCanvas == (promptText and self.transitionPromptCanvas or nil) then
                return cache
        end

        local shadow = Theme.shadowColor or DEFAULT_SHADOW_COLOR
        local shadowAlpha = shadow[4] or 0.5

        love.graphics.push("all")
        love.graphics.setCanvas({titleCanvas, stencil = true})
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.setBlendMode("alpha")

        love.graphics.setFont(UI.fonts.title)
        local titleY = (self.screenHeight or height) / 2 - 90
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadowAlpha)
        love.graphics.printf(floorData.name or "", 2, titleY + 2, self.screenWidth or width, "center")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(floorData.name or "", 0, titleY, self.screenWidth or width, "center")

        if floorData.flavor and floorData.flavor ~= "" then
                love.graphics.setFont(UI.fonts.button)
                local flavorY = titleY + UI.fonts.title:getHeight() + 32
                love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadowAlpha * 0.95)
                love.graphics.printf(floorData.flavor, 2, flavorY + 2, self.screenWidth or width, "center")
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.printf(floorData.flavor, 0, flavorY, self.screenWidth or width, "center")
        end

        love.graphics.setCanvas()
        love.graphics.pop()

        if promptCanvas then
                love.graphics.push("all")
                love.graphics.setCanvas({promptCanvas, stencil = true})
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.origin()
                love.graphics.setBlendMode("alpha")

                local promptFont = UI.fonts.prompt or UI.fonts.body
                love.graphics.setFont(promptFont)
                local promptY = (self.screenHeight or height) - promptFont:getHeight() * 2.2
                love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadowAlpha)
                love.graphics.printf(promptText, 2, promptY + 2, self.screenWidth or width, "center")
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(promptText, 0, promptY, self.screenWidth or width, "center")

                love.graphics.setCanvas()
                love.graphics.pop()
        end

        cache = {
                canvas = titleCanvas,
                promptCanvas = promptCanvas,
                floorData = floorData,
                promptText = promptText,
                width = width,
                height = height,
        }

        self.transitionTitleCache = cache

        return cache
end

local RUN_ACTIVE_STATES = {
	playing = true,
	descending = true,
}

local ENTITY_UPDATE_ORDER = ModuleUtil.prepareSystems({
        Face,
        Popup,
        Fruit,
        Rocks,
        Lasers,
        Darts,
        Saws,
        Arena,
        Particles,
        Bombs,
        UpgradeVisuals,
	Achievements,
	FloatingText,
	Score,
})

local TRANSITION_VISUAL_SYSTEMS = ModuleUtil.prepareSystems({
        Face,
        Popup,
        Arena,
        Darts,
        Particles,
        Bombs,
        UpgradeVisuals,
        Achievements,
        FloatingText,
	Score,
})

local function cloneColor(color, fallback)
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

local function resetFeedbackState(self)
	self.feedback = {
		impactTimer = 0,
		impactDuration = 0.36,
		impactPeak = 0,
		surgeTimer = 0,
		surgeDuration = 0.78,
		surgePeak = 0,
		panicTimer = 0,
		panicDuration = 2.6,
		dangerLevel = 0,
		dangerPulseTimer = 0,
		panicBurst = 0,
		impactRipple = nil,
		surgeRipple = nil,
	}
	self.hitStop = nil
end

local function ensureFeedbackState(self)
	if not self.feedback then
		resetFeedbackState(self)
	end

	return self.feedback
end

local function updateFeedbackState(self, dt)
	if not dt or dt <= 0 then
		return
	end

	local state = ensureFeedbackState(self)

	state.impactTimer = max(0, (state.impactTimer or 0) - dt)
	state.surgeTimer = max(0, (state.surgeTimer or 0) - dt)
	state.panicTimer = max(0, (state.panicTimer or 0) - dt)
	state.dangerPulseTimer = (state.dangerPulseTimer or 0) + dt

	if (state.impactTimer or 0) <= 0 then
		state.impactRipple = nil
	end

	if (state.surgeTimer or 0) <= 0 then
		state.surgeRipple = nil
	end

	local targetDanger = 0
	if (state.panicTimer or 0) > 0 and (state.panicDuration or 0) > 0 then
		targetDanger = max(0, min(1, (state.panicTimer or 0) / state.panicDuration))
	end

	local smoothing = min(dt * 4.5, 1)
	state.dangerLevel = (state.dangerLevel or 0) + (targetDanger - (state.dangerLevel or 0)) * smoothing

	local impactDecay = min(dt * 2.6, 1)
	state.impactPeak = max(0, (state.impactPeak or 0) - impactDecay)

	local surgeDecay = min(dt * 1.8, 1)
	state.surgePeak = max(0, (state.surgePeak or 0) - surgeDecay)

	state.panicBurst = max(0, (state.panicBurst or 0) - dt * 0.9)
end

local function drawFeedbackOverlay(self)
	local state = self.feedback
	if not state then
		return
	end

	local screenW = self.screenWidth or love.graphics.getWidth()
	local screenH = self.screenHeight or love.graphics.getHeight()

	local impactTimer = state.impactTimer or 0
	local impactDuration = state.impactDuration or 1
	local impactPeak = state.impactPeak or 0

	if impactTimer > 0 and impactPeak > 0 then
		local progress = max(0, min(1, impactTimer / impactDuration))
		local intensity = impactPeak * (progress ^ 0.7)
		local age = 1 - progress

		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		love.graphics.setColor(1, 1, 1, 0.22 * intensity)
		love.graphics.rectangle("fill", -12, -12, screenW + 24, screenH + 24)

		love.graphics.setColor(1, 0.78, 0.45, 0.32 * intensity)
		local inset = 10 + intensity * 8
		love.graphics.setLineWidth(3 + intensity * 6)
		love.graphics.rectangle("line", inset, inset, screenW - inset * 2, screenH - inset * 2, 28, 28)

		local ripple = state.impactRipple
		if ripple then
			local rx = ripple.x or screenW * 0.5
			local ry = ripple.y or screenH * 0.5
			local baseRadius = ripple.baseRadius or 52
                        local color = ripple.color or DEFAULT_IMPACT_RIPPLE_COLOR
			local ringRadius = baseRadius + easeOutExpo(age) * (140 + intensity * 80)
			local fillRadius = baseRadius * (0.55 + age * 0.6)

                        love.graphics.setLineWidth(2.5 + intensity * 4)
                        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.55 * intensity)
                        love.graphics.circle("line", rx, ry, ringRadius, circleSegments(ringRadius))

                        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.22 * intensity)
                        love.graphics.circle("fill", rx, ry, fillRadius, circleSegments(fillRadius))
		end

		love.graphics.pop()
	end

        local surgeTimer = state.surgeTimer or 0
        local surgeDuration = state.surgeDuration or 1
        local surgePeak = state.surgePeak or 0
        if surgeTimer > 0 and surgePeak > 0 then
                local progress = max(0, min(1, surgeTimer / surgeDuration))
                local intensity = surgePeak * (progress ^ 0.8)
                local expansion = 1 - progress

                love.graphics.push("all")
                love.graphics.setBlendMode("add")
                local radius = self.screenDiagonal
                if not radius then
                        radius = sqrt(screenW * screenW + screenH * screenH)
                        self.screenDiagonal = radius
                end
                love.graphics.setColor(1, 0.9, 0.5, 0.22 * intensity)
                love.graphics.setLineWidth(2 + intensity * 6)
                local surgeRingRadius = radius * (0.6 + expansion * 0.26)
                love.graphics.circle("line", screenW * 0.5, screenH * 0.5, surgeRingRadius, circleSegments(surgeRingRadius))
		local ripple = state.surgeRipple
		if ripple then
			local rx = ripple.x or screenW * 0.5
			local ry = ripple.y or screenH * 0.5
			local baseRadius = ripple.baseRadius or 48
                        local color = ripple.color or DEFAULT_SURGE_RIPPLE_COLOR
			local eased = easeOutCubic(1 - progress)
			local ringRadius = baseRadius + eased * (160 + intensity * 90)
                        love.graphics.setLineWidth(2 + intensity * 4)
                        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.35 * intensity)
                        love.graphics.circle("line", rx, ry, ringRadius, circleSegments(ringRadius))

                        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.18 * intensity)
                        local fillRadius = baseRadius * (0.4 + eased * 0.6)
                        love.graphics.circle("fill", rx, ry, fillRadius, circleSegments(fillRadius))
		end

		love.graphics.pop()
	end

	local baseDanger = state.dangerLevel or 0
	local burst = state.panicBurst or 0
	local danger = max(baseDanger, burst * 0.7)
	if danger > 0 then
		local pulseTimer = state.dangerPulseTimer or 0
		local pulse = 0.5 + 0.5 * sin(pulseTimer * (4.6 + danger * 3.2))
		love.graphics.push("all")
		love.graphics.setColor(0.45, 0.03, 0.08, 0.4 * danger + 0.22 * pulse * danger)
		love.graphics.rectangle("fill", -14, -14, screenW + 28, screenH + 28)

		local outlineAlpha = min(0.78, 0.35 + danger * 0.45 + burst * 0.35)
		love.graphics.setColor(0.95, 0.1, 0.22, outlineAlpha)
		local thickness = 16 + danger * 28
		love.graphics.setLineWidth(thickness)
		love.graphics.rectangle("line", thickness * 0.5, thickness * 0.5, screenW - thickness, screenH - thickness, 32, 32)
		love.graphics.pop()
	end
end

local function resolveFeedbackPosition(self, options)
        local x, y

        if options then
                x = options.hitX or options.x or options.headX or options.snakeX
                y = options.hitY or options.y or options.headY or options.snakeY
        end

        if not (x and y) and Snake and Snake.getHead then
                x, y = Snake:getHead()
        end

	if not (x and y) then
		local w = self.screenWidth or love.graphics.getWidth() or 0
		local h = self.screenHeight or love.graphics.getHeight() or 0
		x = w * 0.5
		y = h * 0.5
	end

	return x, y
end

local ensureHitStopState

function Game:applyHitStop(intensity, duration)
	intensity = max(intensity or 0, 0)
	duration = max(duration or 0, 0)

	if intensity <= 0 or duration <= 0 then
		return
	end

	local state = ensureHitStopState(self)
	state.timer = max(state.timer or 0, duration)
	state.duration = max(state.duration or 0, duration)
	state.intensity = min(0.95, max(state.intensity or 0, intensity))
end

function Game:triggerImpactFeedback(strength, options)
        local state = ensureFeedbackState(self)
        strength = max(strength or 0, 0)

	local duration = 0.28 + strength * 0.24
	state.impactDuration = duration
	state.impactTimer = duration

	local spike = 0.55 + strength * 0.65
	state.impactPeak = min(1.25, max(state.impactPeak or 0, spike))
	state.panicBurst = min(1.35, (state.panicBurst or 0) + 0.35 + strength * 0.4)

	local impactRipple = state.impactRipple or {}
	local rx, ry = resolveFeedbackPosition(self, options)
	impactRipple.x = rx
	impactRipple.y = ry
	impactRipple.baseRadius = (options and options.radius) or impactRipple.baseRadius or 54
	impactRipple.color = cloneColor(options and options.color, {1, 0.42, 0.32, 1})
	state.impactRipple = impactRipple

	local hitStopStrength = 0.3 + strength * 0.35
	local hitStopDuration = 0.08 + strength * 0.08
	self:applyHitStop(hitStopStrength, hitStopDuration)

        if Shaders and Shaders.notify then
                Shaders.notify("specialEvent", {
                        type = "danger",
                        strength = min(1.2, 0.45 + strength * 0.55),
                })
        end
end

local TAIL_HAZARD_SHAKE = {
        saw = 0.18,
        laser = 0.16,
        dart = 0.14,
}

function Game:triggerScreenShake(amount)
        if Settings.screenShake == false then
                return
        end

        amount = max(amount or 0, 0)
        if amount <= 0 then
                return
        end

        local effects = self.Effects
        if effects and effects.shake then
                effects:shake(amount)
        end
end

function Game:triggerTailChopShake(cause)
        local amount = TAIL_HAZARD_SHAKE[cause or ""] or TAIL_HAZARD_SHAKE.saw
        self:triggerScreenShake(amount)
end

local cachedMouseInterface
local mouseSupportChecked = false

local function isCursorSupported(mouse)
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

local function getMouseInterface()
	if mouseSupportChecked then
		return cachedMouseInterface
	end

	mouseSupportChecked = true

	local mouse = love.mouse
	if not mouse.setVisible or not isCursorSupported(mouse) then
		cachedMouseInterface = nil
		return nil
	end

	cachedMouseInterface = mouse
	return cachedMouseInterface
end

local function getMouseVisibility(mouse)
	if mouse and mouse.isVisible then
		local ok, visible = pcall(mouse.isVisible)
		if ok and visible ~= nil then
			return visible and true or false
		end
	end

	return true
end

ensureHitStopState = function(self)
	if not self.hitStop then
		self.hitStop = {
			timer = 0,
			duration = 0,
			intensity = 0,
		}
	end

	return self.hitStop
end

local function updateHitStopState(self, dt)
	local state = self.hitStop
	if not state then
		return
	end

	state.timer = max(0, (state.timer or 0) - (dt or 0))
	if state.timer <= 0 then
		self.hitStop = nil
	end
end

local function resolveHitStopScale(self)
	local state = self.hitStop
	if not state then
		return 1
	end

	local timer = state.timer or 0
	local duration = state.duration or 0
	local intensity = state.intensity or 0

	if timer <= 0 or duration <= 0 or intensity <= 0 then
		return 1
	end

	local progress = max(0, min(1, timer / duration))
	local slow = 1 - easeOutCubic(progress) * min(intensity, 0.95)
	return max(0.1, slow)
end

local function resolveMouseVisibilityTarget(self)
	if not getMouseInterface() then
		return nil
	end

	local transition = self.transition
	local inShop = transition and transition:isShopActive()
	if inShop then
		return true
	end

	if RUN_ACTIVE_STATES[self.state] == true then
		return false
	end

	return nil
end

function Game:releaseMouseVisibility()
	local state = self.mouseCursorState
	if not state then
		return
	end

	local mouse = state.interface or getMouseInterface()
	if mouse and mouse.setVisible then
		local restore = state.originalVisible
		if restore == nil then
			restore = true
		end
		mouse.setVisible(restore and true or false)
	end

	self.mouseCursorState = nil
end

function Game:updateMouseVisibility()
	local mouse = getMouseInterface()
	if not mouse then
		self:releaseMouseVisibility()
		return
	end

	local targetVisible = resolveMouseVisibilityTarget(self)
	if targetVisible == nil then
		self:releaseMouseVisibility()
		return
	end

	local state = self.mouseCursorState
	if not state then
		local currentVisible = getMouseVisibility(mouse)
		state = {
			interface = mouse,
			originalVisible = currentVisible,
			currentVisible = currentVisible,
		}
		self.mouseCursorState = state
	end

	if state.currentVisible ~= targetVisible then
		mouse.setVisible(targetVisible and true or false)
		state.currentVisible = targetVisible
	end
end

function Game:isTransitionActive()
	local transition = self.transition
	return transition ~= nil and transition:isActive()
end

function Game:enterPause()
	if self.state == "paused" then
		return
	end

	if self.state == "gameover" then
		return
	end

	self.pauseReturnState = self.state
	self.state = "paused"
end

function Game:exitPause()
	if self.state ~= "paused" then
		return
	end

	local restoreState = self.pauseReturnState or "playing"
	self.pauseReturnState = nil
	self.state = restoreState
end

function Game:togglePause()
	if self.state == "paused" then
		self:exitPause()
	elseif self.state ~= "gameover" then
		self:enterPause()
	end
end

function Game:confirmTransitionIntro()
	local transition = self.transition
	if not transition then
		return false
	end

	return transition:confirmFloorIntro() and true or false
end

local function getScaledDeltaTime(self, dt)
	if not dt then
		return dt
	end

	local scale = 1
	if Snake and Snake.getTimeScale then
		local snakeScale = Snake:getTimeScale()
		if snakeScale and snakeScale > 0 then
			scale = snakeScale
		end
	end

	scale = scale * resolveHitStopScale(self)

	return dt * scale
end

local function updateRunTimers(self, dt)
	if RUN_ACTIVE_STATES[self.state] then
		SessionStats:add("timeAlive", dt)
		self.runTimer = (self.runTimer or 0) + dt
	end

	if self.state == "playing" then
		self.floorTimer = (self.floorTimer or 0) + dt
	end
end

local function updateSystems(systems, dt)
	ModuleUtil.runHook(systems, "update", dt)
end

local function updateGlobalSystems(dt)
	FruitEvents.update(dt)
	Shaders.update(dt)
end

local function handlePauseMenu(game, dt)
	local paused = game.state == "paused"
	local floorName = nil
	if game.currentFloorData then
		floorName = game.currentFloorData.name
	end
	PauseMenu:update(dt, paused, game.floor, floorName)
	return paused
end

local function forwardShopInput(game, eventName, ...)
	local input = game.input
	if not input or not input.handleShopInput then
		return false
	end

	return input:handleShopInput(eventName, ...)
end

local function drawShadowedText(font, text, x, y, width, align, alpha)
	if alpha <= 0 then
		return
	end

	love.graphics.setFont(font)
        local shadow = Theme.shadowColor or DEFAULT_SHADOW_COLOR
	local shadowAlpha = (shadow[4] or 1) * alpha
	love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadowAlpha)
	love.graphics.printf(text, x + 2, y + 2, width, align)

	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.printf(text, x, y, width, align)
end

local STATE_UPDATERS = {
	descending = function(self, dt)
		self:updateDescending(dt)
		return true
	end,
}

local function drawAdrenalineGlow(self)
	local glowStrength = Score:getHighScoreGlowStrength()

	if Snake.adrenaline and Snake.adrenaline.active and not Snake.adrenaline.suppressVisuals then
		local duration = Snake.adrenaline.duration or 1
		if duration > 0 then
			local adrenalineStrength = max(0, min(1, (Snake.adrenaline.timer or 0) / duration))
			glowStrength = max(glowStrength, adrenalineStrength * 0.85)
		end
	end

	if glowStrength <= 0 then return end

	local time = Timer.getTime()
	local pulse = 0.85 + 0.15 * sin(time * 2.25)
	local easedStrength = 0.6 + glowStrength * 0.4
	local alpha = 0.18 * easedStrength * pulse

	love.graphics.push("all")
	love.graphics.setBlendMode("add")
	love.graphics.setColor(0.65, 0.82, 0.95, alpha)
	love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
	love.graphics.pop()
end

function Game:load(options)
	options = options or {}

	local requestedFloor = max(1, floor(options.startFloor or 1))
	local totalFloors = #Floors
	if totalFloors > 0 then
		requestedFloor = min(requestedFloor, totalFloors)
	end

	self.state = "playing"
	self.startFloor = requestedFloor
	self.floor = requestedFloor
	self.runTimer = 0
	self.floorTimer = 0
        self.pauseReturnState = nil

        self.mouseCursorState = nil

        self:invalidateTransitionTitleCache()

        Screen:update()
        updateScreenDimensions(self, Screen:get())
        Arena:updateScreenBounds(self.screenWidth, self.screenHeight)

	Score:load()
	Upgrades:beginRun()
	GameUtils:prepareGame(self.screenWidth, self.screenHeight)
	Face:set("idle")

        self.transition = TransitionManager.new(self)
        self.input = GameInput.new(self, self.transition)
        self.input:resetAxes()

        resetFeedbackState(self)

        self.singleTouchDeath = true

        self.hudIndicatorRefreshInterval = 1 / 30
        self.hudIndicatorActiveRefreshInterval = 1 / 60
        self.hudIndicatorRefreshTimer = self.hudIndicatorRefreshInterval

        if Snake.adrenaline then
                Snake.adrenaline.active = false
                Snake.adrenaline.suppressVisuals = nil
        end

	self:setupFloor(self.floor)

	self.transition:startFloorIntro(2.8, {
		transitionAdvance = false,
		transitionAwaitInput = true,
		transitionFloorData = Floors[self.floor] or Floors[1],
	})
end

function Game:reset()
        GameUtils:prepareGame(self.screenWidth, self.screenHeight)
        Face:set("idle")
        self.state = "playing"
        self.floor = self.startFloor or 1
        self.runTimer = 0
        self.floorTimer = 0
        self.pauseReturnState = nil

        self.mouseCursorState = nil

        self.deathHoldTimer = nil
        self.deathHoldDuration = nil

        self:invalidateTransitionTitleCache()

        resetFeedbackState(self)

        self.hudIndicatorRefreshInterval = 1 / 30
        self.hudIndicatorActiveRefreshInterval = 1 / 60
        self.hudIndicatorRefreshTimer = self.hudIndicatorRefreshInterval

        if self.transition then
                self.transition:reset()
        end

        if self.input then
		self.input:resetAxes()
	end
end

function Game:enter(data)
	UI.clearButtons()
	self:load(data)

	Audio:playMusic("game")
	SessionStats:reset()
	PlayerStats:add("sessionsPlayed", 1)

	Achievements:checkAll({
		sessionsPlayed = PlayerStats:get("sessionsPlayed"),
	})

	self:updateMouseVisibility()
end

function Game:leave()
	self:releaseMouseVisibility()

	Snake:resetModifiers()

	UI:setUpgradeIndicators(nil)
end

function Game:beginDeath()
        if self.state ~= "dying" then
                self.state = "dying"
                Snake:setDead(true)
                local trail = Snake:getSegments()
                Death:spawnFromSnake(trail, SnakeUtils.SEGMENT_SIZE)
                Audio:playSound("death")
                self.deathHoldTimer = nil
                self.deathHoldDuration = DEATH_HOLD_DURATION
        end
end

function Game:applyDamage(amount, cause, context)
	local inflicted = floor((amount or 0) + 0.0001)
	if inflicted < 0 then
		inflicted = 0
	end

	if context then
		context.inflictedDamage = inflicted
	end

	if inflicted <= 0 then
		return true
	end

	local impactStrength = max(0.35, ((context and context.shake) or 0) + inflicted * 0.12)

	if Snake and Snake.onDamageTaken then
		Snake:onDamageTaken(cause, context)
	end

	self:triggerImpactFeedback(impactStrength, context)

	if Settings.screenShake ~= false and context and context.shake and self.Effects and self.Effects.shake then
		self.Effects:shake(context.shake)
	end

	return false
end

function Game:startDescending(holeX, holeY, holeRadius)
	self.state = "descending"
	self.hole = {x = holeX, y = holeY, radius = holeRadius or 24}
	Snake:startDescending(self.hole.x, self.hole.y, self.hole.radius)
	Audio:playSound("exit_enter")
end

-- start a floor transition
function Game:startFloorTransition(advance, skipFade)
	Snake:finishDescending()
	self.transition:startFloorTransition(advance, skipFade)
end

function Game:triggerVictory()
	if self.state == "victory" then
		return
	end

	Snake:finishDescending()
	if Arena and Arena.resetExit then
		Arena:resetExit()
	end

	local floorTime = self.floorTimer or 0
	if floorTime and floorTime > 0 then
		SessionStats:add("totalFloorTime", floorTime)
		SessionStats:updateMin("fastestFloorClear", floorTime)
		SessionStats:updateMax("slowestFloorClear", floorTime)
		SessionStats:set("lastFloorClearTime", floorTime)
	end
	self.floorTimer = 0

	local currentFloor = self.floor or 1
	local nextFloor = currentFloor + 1
	PlayerStats:add("floorsCleared", 1)
	PlayerStats:updateMax("deepestFloorReached", nextFloor)
	SessionStats:add("floorsCleared", 1)
	SessionStats:updateMax("deepestFloorReached", nextFloor)

	Audio:playSound("floor_advance")

	local floorData = Floors[currentFloor] or {}
	local floorName = floorData.name or string.format("Floor %d", currentFloor)
	local endingMessage = Localization:get("gameover.victory_story_body", {floor = floorName})
	if endingMessage == "gameover.victory_story_body" then
		endingMessage = Floors.victoryMessage or string.format("With the festival feast safely reclaimed from %s, Noodl rockets home to start the parade.", floorName)
	end

	local storyTitle = Localization:get("gameover.victory_story_title")
	if storyTitle == "gameover.victory_story_title" then
		storyTitle = Floors.storyTitle or "Noodl's Grand Feast"
	end

	local result = Score:handleRunClear({
		endingMessage = endingMessage,
		storyTitle = storyTitle,
	})

	Achievements:save()

	self.victoryResult = result
	self.victoryTimer = 0
	self.victoryDelay = 1.2
	self.state = "victory"
end

function Game:startFloorIntro(duration, extra)
	self.transition:startFloorIntro(duration, extra)
end

function Game:startFadeIn(duration)
	self.transition:startFadeIn(duration)
end

function Game:updateDescending(dt)
	Snake:update(dt)

	-- Keep saw blades animating while the snake descends into the exit hole
	if Saws and Saws.update then
		Saws:update(dt)
	end

	local segments = Snake:getSegments()
	local tail = segments[#segments]
	if not tail then
		Snake:finishDescending()
		self:startFloorTransition(true)
		return
	end

	local dx, dy = tail.drawX - self.hole.x, tail.drawY - self.hole.y
	local dist = sqrt(dx * dx + dy * dy)
	if dist < self.hole.radius then
		local finalFloor = #Floors
		if (self.floor or 1) >= finalFloor then
			self:triggerVictory()
		else
			Snake:finishDescending()
			self:startFloorTransition(true)
		end
	end
end

function Game:updateGameplay(dt)

	if Upgrades and Upgrades.recordFloorReplaySnapshot then
		Upgrades:recordFloorReplaySnapshot(self)
	end

	local moveResult, cause, context = Movement:update(dt)

	if moveResult == "hit" then
		local damage = (context and context.damage) or 1
		local survived = self:applyDamage(damage, cause, context)
		if not survived then
			local replayTriggered = false
			if Upgrades and Upgrades.tryFloorReplay then
				replayTriggered = Upgrades:tryFloorReplay(self, cause)
			end
			if replayTriggered then
				return
			end
			self.deathCause = cause
			self:beginDeath()
		end
		return
	elseif moveResult == "dead" then
		local replayTriggered = false
		if Upgrades and Upgrades.tryFloorReplay then
			replayTriggered = Upgrades:tryFloorReplay(self, cause)
		end
		if replayTriggered then
			return
		end
		self.deathCause = cause
		self:beginDeath()
		return
	end

        if moveResult == "scored" then
                local fruitX, fruitY = Fruit:getDrawPosition()
                FruitEvents.handleConsumption(fruitX, fruitY)

		local goalReached = UI:isGoalReached()
		if goalReached then
			Arena:spawnExit()
		end

		-- Removed surge feedback when collecting fruit to eliminate the outward ring effect.
	end

	local snakeX, snakeY = Snake:getHead()
	if Arena:checkExitCollision(snakeX, snakeY) then
		local hx, hy, hr = Arena:getExitCenter()
		if hx and hy then
			self:startDescending(hx, hy, hr)
		end
	end
end

function Game:updateEntities(dt)
	updateSystems(ENTITY_UPDATE_ORDER, dt)
end

function Game:updateTransitionVisuals(dt)
	if not dt or dt <= 0 then
		return
	end

	updateSystems(TRANSITION_VISUAL_SYSTEMS, dt)
end

function Game:handleDeath(dt)
	if self.state ~= "dying" then
		return
	end

        Death:update(dt)
        if not Death:isFinished() then
                self.deathHoldTimer = nil
                return
        end

        local holdDuration = self.deathHoldDuration or DEATH_HOLD_DURATION or 0
        if holdDuration > 0 then
                self.deathHoldTimer = (self.deathHoldTimer or 0) + dt
                if self.deathHoldTimer < holdDuration then
                        return
                end
        end

        self.deathHoldTimer = nil
        self.deathHoldDuration = nil

        Achievements:save()
        local result = Score:handleGameOver(self.deathCause)
        if result then
                return {state = "gameover", data = result}
	end
end

local function drawPlayfieldLayers(self, stateOverride)
        local renderState = stateOverride or self.state

        RenderLayers:begin(self.screenWidth or love.graphics.getWidth(), self.screenHeight or love.graphics.getHeight())

        currentGame = self
        currentRenderState = renderState

        RenderLayers:withLayer("background", drawBackgroundLayer)

        Death:applyShake()

        RenderLayers:withLayer("main", drawMainLayer)

        RenderLayers:present()

        currentGame = nil
        currentRenderState = nil
end

local function drawInterfaceLayers(self)
	FloatingText:draw()

	drawAdrenalineGlow(self)

	drawFeedbackOverlay(self)

	Death:drawFlash(self.screenWidth, self.screenHeight)
	PauseMenu:draw(self.screenWidth, self.screenHeight)
	UI:draw()
	Achievements:draw()
end

local function drawTransitionFadeOut(self, timer, duration)
	drawPlayfieldLayers(self)
	drawInterfaceLayers(self)

	local progress
	if not duration or duration <= 0 then
		progress = 1
	else
		progress = clamp01(timer / duration)
	end

	love.graphics.setColor(0, 0, 0, progress)
	love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
	love.graphics.setColor(1, 1, 1, 1)

	return true
end

local function drawTransitionShop(self, _)
	love.graphics.setColor(0, 0, 0, 0.85)
	love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
	love.graphics.setColor(1, 1, 1, 1)
	Shop:draw(self.screenWidth, self.screenHeight)
	PauseMenu:draw(self.screenWidth, self.screenHeight)

	return true
end

local function drawTransitionNotes(self, timer, outroAlpha, fadeAlpha)
	local notes = self.transitionNotes
	if not (notes and #notes > 0) then
		return
	end

	local y = self.screenHeight / 2 + 64
	local width = self.screenWidth * 0.45
	local x = (self.screenWidth - width) / 2
	local buttonFont = UI.fonts.button
	local bodyFont = UI.fonts.body

	for index, note in ipairs(notes) do
		local offsetDelay = 0.9 + (index - 1) * 0.22
		local noteAlpha
		local noteOffset = 0

		if fadeAlpha then
			noteAlpha = fadeAlpha(offsetDelay, 0.4)
			noteOffset = (1 - easeOutExpo(clamp01((timer - offsetDelay) / 0.55))) * 16 * (outroAlpha or 1)
		else
			noteAlpha = outroAlpha or 1
		end

		if note.title and note.title ~= "" then
			drawShadowedText(
			buttonFont,
			note.title,
			x,
			y + noteOffset,
			width,
			"center",
			noteAlpha
			)
			y = y + buttonFont:getHeight() + 6
		end

		if note.text and note.text ~= "" then
			drawShadowedText(
			bodyFont,
			note.text,
			x,
			y + noteOffset,
			width,
			"center",
			noteAlpha
			)
			y = y + bodyFont:getHeight() + 10
		end
	end
end

local function drawTransitionFloorIntro(self, timer, duration, data)
        local floorData = data.transitionFloorData or self.currentFloorData
        if not floorData then
                return
        end

        love.graphics.setColor(1, 1, 1, 1)
        drawPlayfieldLayers(self, "playing")

        local totalDuration = duration or 0
        local progress = totalDuration > 0 and clamp01(timer / totalDuration) or 1
        local awaitingConfirm = data.transitionAwaitInput and not data.transitionIntroConfirmed
        local visualProgress = progress
        if awaitingConfirm then
                visualProgress = min(visualProgress, 0.7)
        end

        local appearProgress = min(1, visualProgress / 0.28)
        local appear = easeOutCubic(appearProgress)
        local dissolveProgress = visualProgress > 0.48 and clamp01((visualProgress - 0.48) / 0.4) or 0
        if awaitingConfirm then
                dissolveProgress = 0
        end
        local overlayAlpha = 0.8 * (1 - 0.55 * dissolveProgress)
        local highlightAlpha = appear * (1 - dissolveProgress)

        love.graphics.setColor(0, 0, 0, overlayAlpha)
        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

        local cache = self:refreshTransitionTitleCanvas(data)
        local titleCanvas = cache and cache.canvas
        local promptCanvas = cache and cache.promptCanvas
        local titleOffset = (1 - appear) * 36

        local canvasAlpha = 1 - clamp01(dissolveProgress)
        if titleCanvas and highlightAlpha > 0 and canvasAlpha > 0 then
                love.graphics.push("all")
                love.graphics.translate(0, titleOffset)
                love.graphics.setColor(1, 1, 1, highlightAlpha * canvasAlpha)
                love.graphics.draw(titleCanvas, 0, 0)
                love.graphics.pop()
        end

        if promptCanvas and canvasAlpha > 0 then
                local promptFade = 1 - clamp01((visualProgress - 0.72) / 0.18)
                local promptAlpha = highlightAlpha * promptFade * canvasAlpha
                if promptAlpha > 0 then
                        love.graphics.setColor(1, 1, 1, promptAlpha)
                        love.graphics.draw(promptCanvas, 0, 0)
                end
        end

        drawTransitionNotes(self, 999, 1, nil)

        love.graphics.setColor(1, 1, 1, 1)

        return true
end

function Game:drawTransition()
	if not self:isTransitionActive() then
		return
	end

	local phase = self.transition:getPhase()
	local timer = self.transition:getTimer() or 0
	local duration = self.transition:getDuration() or 0
        local data = self.transition:getData() or EMPTY_TABLE

        if phase == "fadeout" then
                self:invalidateTransitionTitleCache()
                if drawTransitionFadeOut(self, timer, duration) then
                        return
                end
        elseif phase == "shop" then
                self:invalidateTransitionTitleCache()
                if drawTransitionShop(self, timer) then
                        return
                end
        elseif phase == "floorintro" then
                if drawTransitionFloorIntro(self, timer, duration, data) then
                        return
                end
                self:invalidateTransitionTitleCache()
        elseif phase == "fadein" then
                self:invalidateTransitionTitleCache()
                drawPlayfieldLayers(self, "playing")
                drawInterfaceLayers(self)

		local progress
		if not duration or duration <= 0 then
			progress = 1
		else
			progress = clamp01(timer / duration)
		end

		local alpha = 1 - progress
		love.graphics.setColor(0, 0, 0, alpha)
		love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function Game:drawDescending()
	if not self.hole then
		Snake:draw()
		Arena:drawExit()
		return
	end

	local hx = self.hole.x
	local hy = self.hole.y
	local hr = self.hole.radius or 0

	Arena:drawExit()

	local coverRadius = hr * 0.92
	if coverRadius <= 0 then
		coverRadius = hr
	end

	if coverRadius > 0 then
		love.graphics.setColor(0.05, 0.05, 0.05, 1)
		love.graphics.circle("fill", hx, hy, coverRadius)

		love.graphics.setColor(0, 0, 0, 1)
		local previousLineWidth = love.graphics.getLineWidth()
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", hx, hy, coverRadius)
		love.graphics.setLineWidth(previousLineWidth)
	end

	Snake:drawClipped(hx, hy, hr)

	love.graphics.setColor(1, 1, 1, 1)
end

function Game:update(dt)
	self:updateMouseVisibility()

	local scaledDt = getScaledDeltaTime(self, dt)
	updateFeedbackState(self, scaledDt)
	updateHitStopState(self, dt)

	if handlePauseMenu(self, dt) then
		return
	end

	if self.state == "victory" then
		local delay = self.victoryDelay or 0
		self.victoryTimer = (self.victoryTimer or 0) + scaledDt

		if self.victoryTimer >= delay then
			local summary = self.victoryResult or Score:handleRunClear()
			return {state = "gameover", data = summary}
		end

		return
	end

	updateRunTimers(self, scaledDt)

	updateGlobalSystems(scaledDt)

	local transition = self.transition
	local transitionBlocking = false
	if transition and transition:isActive() then
		transition:update(scaledDt)
		transitionBlocking = transition.isGameplayBlocked and transition:isGameplayBlocked()
	end

	if transitionBlocking then
		self:updateTransitionVisuals(scaledDt)
		return
	end

	local stateHandler = STATE_UPDATERS[self.state]
	if stateHandler and stateHandler(self, scaledDt) then
		return
	end

	if self.state == "playing" then
		self:updateGameplay(scaledDt)
	end

        self:updateEntities(scaledDt)

        local refreshInterval = self.hudIndicatorRefreshInterval or (1 / 30)
        local activeRefreshInterval = self.hudIndicatorActiveRefreshInterval or refreshInterval

        local adrenaline = Snake and Snake.adrenaline
        local dash = Snake and Snake.dash

        if adrenaline and adrenaline.active then
                refreshInterval = min(refreshInterval, activeRefreshInterval)
        end

        if dash and (dash.active or (dash.cooldownTimer or 0) > 0) then
                refreshInterval = min(refreshInterval, activeRefreshInterval)
        end

        self.hudIndicatorRefreshTimer = (self.hudIndicatorRefreshTimer or 0) + scaledDt

        local shouldRefresh = Upgrades.hudIndicatorsDirty or false
        if self.hudIndicatorRefreshTimer >= refreshInterval then
                shouldRefresh = true
        end

        if shouldRefresh then
                local upgradeIndicators, indicatorsUpdated = Upgrades:getHUDIndicators()
                if indicatorsUpdated then
                        UI:setUpgradeIndicators(upgradeIndicators)
                end

                if self.hudIndicatorRefreshTimer >= refreshInterval then
                        self.hudIndicatorRefreshTimer = self.hudIndicatorRefreshTimer % refreshInterval
                else
                        self.hudIndicatorRefreshTimer = 0
                end
        end

        local result = self:handleDeath(scaledDt)
        if result then
                return result
        end
end

function Game:setupFloor(floorNum)
	self.currentFloorData = Floors[floorNum] or Floors[1]

	FruitEvents.reset()

	self.floorTimer = 0

	local setup = FloorSetup.prepare(floorNum, self.currentFloorData)
	local traitContext = setup.traitContext
	local spawnPlan = setup.spawnPlan

	UI:setFruitGoal(traitContext.fruitGoal)

	self.transitionNotes = nil

	Upgrades:applyPersistentEffects(true)

	if Snake.adrenaline then
		Snake.adrenaline.active = false
		Snake.adrenaline.timer = 0
		Snake.adrenaline.suppressVisuals = nil
	end

	FloorSetup.finalizeContext(traitContext, spawnPlan)
	Upgrades:notify("floorStart", {floor = floorNum, context = traitContext})

	FloorSetup.spawnHazards(spawnPlan)
end

function Game:draw()
        love.graphics.clear()

        if Arena.drawBackdrop then
                Arena:drawBackdrop(self.screenWidth, self.screenHeight)
	else
		love.graphics.setColor(Theme.bgColor)
		love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end

	if self:isTransitionActive() then
		self:drawTransition()
		return
	end

        drawPlayfieldLayers(self)
        drawInterfaceLayers(self)
end

function Game:resize(width, height)
        if updateScreenDimensions(self, width, height) then
                Arena:updateScreenBounds(self.screenWidth, self.screenHeight)
                self:invalidateTransitionTitleCache()
        end
end

function Game:keypressed(key)
	if key == "escape" and self.state ~= "gameover" then
		self:togglePause()
		return
	end

	if self.state == "paused" then
		local action = PauseMenu:keypressed(key)
		if action and self.input then
			return self.input:applyPauseMenuSelection(action)
		end
		return
	end

	if forwardShopInput(self, "keypressed", key) then
		return
	end

	if self:confirmTransitionIntro() then
		return
	end

	Controls:keypressed(self, key)
end

function Game:mousepressed(x, y, button)
	if self:confirmTransitionIntro() then
		return
	end

	if self.state == "paused" then
		PauseMenu:mousepressed(x, y, button)
		return
	end

	forwardShopInput(self, "mousepressed", x, y, button)
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
		return self.input:applyPauseMenuSelection(selection)
	end
end

function Game:gamepadpressed(_, button)
	if self:confirmTransitionIntro() then
		return
	end

	if self.input then
		return self.input:handleGamepadButton(button)
	end
end
Game.joystickpressed = Game.gamepadpressed

function Game:gamepadaxis(_, axis, value)
	if self.input then
		return self.input:handleGamepadAxis(axis, value)
	end
end
Game.joystickaxis = Game.gamepadaxis

return Game