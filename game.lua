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
local GameModes = require("gamemodes")
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
local InputMode = require("inputmode")
local HealthSystem = require("healthsystem")
local TalentTree = require("talenttree")

local Game = {}

local clamp01 = Easing.clamp01
local easeOutExpo = Easing.easeOutExpo
local easeOutBack = Easing.easeOutBack
local easeInOutCubic = Easing.easeInOutCubic
local easedProgress = Easing.easedProgress

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local floorTitlePixelateShader
do
    local shaderSource = [[
        extern vec2 canvasSize;
        extern float pixelSize;
        extern float dissolve;
        extern float time;

        float hash21(vec2 p)
        {
            p = fract(p * vec2(0.1031, 0.11369));
            p += dot(p, p + 19.19);
            return fract((p.x + p.y) * p.x * p.y);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = texture_coords * canvasSize;
            float size = max(1.0, pixelSize);
            vec2 blockIndex = floor(uv / size);
            vec2 blockCenter = (blockIndex + 0.5) * size;
            vec2 sampleCoords = blockCenter / canvasSize;
            vec4 base = Texel(tex, sampleCoords) * color;

            float anim = sin(time * 6.0 + hash21(blockIndex) * 6.28318) * 0.12;
            float threshold = clamp(1.0 - dissolve + anim, 0.0, 1.0);
            float noise = hash21(blockIndex + floor(time * 7.0));
            float visibility = smoothstep(0.0, 0.45, threshold - noise);

            float anger = clamp(dissolve * 0.65, 0.0, 1.0);
            vec3 angerColor = vec3(0.92, 0.28, 0.28);
            base.rgb = mix(base.rgb, angerColor, anger);
            base.rgb *= visibility;
            base.a *= visibility;

            return base;
        }
    ]]
    local ok, shader = pcall(love.graphics.newShader, shaderSource)
    if ok then
        floorTitlePixelateShader = shader
    end
end

local function ensureTransitionTitleCanvas(self)
    local width = math.max(1, math.ceil(self.screenWidth or love.graphics.getWidth() or 1))
    local height = math.max(1, math.ceil(self.screenHeight or love.graphics.getHeight() or 1))
    local canvas = self.transitionTitleCanvas
    if not canvas or canvas:getWidth() ~= width or canvas:getHeight() ~= height then
        canvas = love.graphics.newCanvas(width, height)
        canvas:setFilter("nearest", "nearest")
        self.transitionTitleCanvas = canvas
    end
    return canvas
end

local RUN_ACTIVE_STATES = {
    playing = true,
    descending = true,
}

local ENTITY_UPDATE_ORDER = {
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
}

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

    local targetDanger = 0
    if self.healthSystem and self.healthSystem.isCritical and self.healthSystem:isCritical() then
        targetDanger = 1
    elseif (state.panicTimer or 0) > 0 and (state.panicDuration or 0) > 0 then
        targetDanger = math.max(0, math.min(1, (state.panicTimer or 0) / state.panicDuration))
    end

    local smoothing = math.min(dt * 4.5, 1)
    state.dangerLevel = (state.dangerLevel or 0) + (targetDanger - (state.dangerLevel or 0)) * smoothing

    local impactDecay = math.min(dt * 2.6, 1)
    state.impactPeak = math.max(0, (state.impactPeak or 0) - impactDecay)

    local surgeDecay = math.min(dt * 1.8, 1)
    state.surgePeak = math.max(0, (state.surgePeak or 0) - surgeDecay)

    state.panicBurst = math.max(0, (state.panicBurst or 0) - dt * 0.9)
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
        local progress = math.max(0, math.min(1, impactTimer / impactDuration))
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
            local color = ripple.color or { 1, 0.42, 0.32, 1 }
            local ringRadius = baseRadius + easeOutExpo(age) * (140 + intensity * 80)
            local fillRadius = baseRadius * (0.55 + age * 0.6)

            love.graphics.setLineWidth(2.5 + intensity * 4)
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.55 * intensity)
            love.graphics.circle("line", rx, ry, ringRadius, 64)

            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.22 * intensity)
            love.graphics.circle("fill", rx, ry, fillRadius, 48)
        end

        love.graphics.pop()
    end

    local surgeTimer = state.surgeTimer or 0
    local surgeDuration = state.surgeDuration or 1
    local surgePeak = state.surgePeak or 0
    if surgeTimer > 0 and surgePeak > 0 then
        local progress = math.max(0, math.min(1, surgeTimer / surgeDuration))
        local intensity = surgePeak * (progress ^ 0.8)
        local expansion = 1 - progress

        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        local radius = math.sqrt(screenW * screenW + screenH * screenH)
        love.graphics.setColor(1, 0.9, 0.5, 0.22 * intensity)
        love.graphics.setLineWidth(2 + intensity * 6)
        love.graphics.circle("line", screenW * 0.5, screenH * 0.5, radius * (0.6 + expansion * 0.26), 64)
        local ripple = state.surgeRipple
        if ripple then
            local rx = ripple.x or screenW * 0.5
            local ry = ripple.y or screenH * 0.5
            local baseRadius = ripple.baseRadius or 48
            local color = ripple.color or { 1, 0.9, 0.55, 1 }
            local eased = easeOutCubic(1 - progress)
            local ringRadius = baseRadius + eased * (160 + intensity * 90)
            love.graphics.setLineWidth(2 + intensity * 4)
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.35 * intensity)
            love.graphics.circle("line", rx, ry, ringRadius, 72)

            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.18 * intensity)
            love.graphics.circle("fill", rx, ry, baseRadius * (0.4 + eased * 0.6), 48)
        end

        love.graphics.pop()
    end

    local baseDanger = state.dangerLevel or 0
    local burst = state.panicBurst or 0
    local danger = math.max(baseDanger, burst * 0.7)
    if danger > 0 then
        local pulseTimer = state.dangerPulseTimer or 0
        local pulse = 0.5 + 0.5 * math.sin(pulseTimer * (4.6 + danger * 3.2))
        love.graphics.push("all")
        love.graphics.setColor(0.45, 0.03, 0.08, 0.4 * danger + 0.22 * pulse * danger)
        love.graphics.rectangle("fill", -14, -14, screenW + 28, screenH + 28)

        local outlineAlpha = math.min(0.78, 0.35 + danger * 0.45 + burst * 0.35)
        love.graphics.setColor(0.95, 0.1, 0.22, outlineAlpha)
        local thickness = 16 + danger * 28
        love.graphics.setLineWidth(thickness)
        love.graphics.rectangle("line", thickness * 0.5, thickness * 0.5, screenW - thickness, screenH - thickness, 32, 32)
        love.graphics.pop()
    end
end

local function clampToInt(value)
    if value == nil then
        return 0
    end

    return math.max(0, math.floor(value + 0.0001))
end

function Game:usesHealth()
    if self.usesHealthSystem == nil then
        return true
    end

    return self.usesHealthSystem
end

function Game:_ensureHealthSystem()
    if not self:usesHealth() then
        return nil
    end

    if self.healthSystem then
        return self.healthSystem
    end

    local maxHealth = clampToInt(self.maxHealth or 0)
    if maxHealth <= 0 then
        maxHealth = 1
    end

    self.healthSystem = HealthSystem.new(maxHealth)
    if self.health ~= nil then
        self.healthSystem:setCurrent(self.health)
    end

    return self.healthSystem
end

function Game:syncHealth(opts)
    if not self:usesHealth() then
        self.health = nil
        if UI and UI.setHealth then
            UI:setHealth(0, 0, opts)
        end
        return
    end

    local system = self.healthSystem
    if system then
        self.health = system:getCurrent()
    end

    if UI and UI.setHealth then
        UI:setHealth(self.health or 0, self.maxHealth, opts)
    end
end

function Game:setMaxHealth(max, opts)
    if not self:usesHealth() then
        return false
    end

    max = clampToInt(max)
    if max <= 0 then
        max = 1
    end

    self.maxHealth = max
    local system = self:_ensureHealthSystem()
    system:setMax(max)
    self:syncHealth(opts)

    if system:getCurrent() > (system.criticalThreshold or 1) then
        self.healthCriticalReady = true
    end

    return true
end

function Game:adjustMaxHealth(delta, opts)
    if not self:usesHealth() then
        return false
    end

    if not delta or delta == 0 then
        return false
    end

    local newMax = clampToInt((self.maxHealth or 0) + delta)
    if newMax <= 0 then
        newMax = 1
    end

    return self:setMaxHealth(newMax, opts)
end

function Game:triggerCriticalHealth(cause, context)
    if not (self.healthSystem and self.healthSystem:isCritical()) then
        return
    end

    if not self.healthCriticalReady then
        return
    end

    self.healthCriticalReady = false

    if UI and UI.triggerHealthCritical then
        UI:triggerHealthCritical()
    end

    if Settings.screenShake ~= false and self.Effects and self.Effects.shake then
        self.Effects:shake(0.22)
    end

    self:triggerPanicFeedback(1.1)

    -- No additional surge effects when second wind is disabled.
end

local function resolveFeedbackPosition(self, options)
    if not options then
        options = {}
    end

    local x = options.hitX or options.x or options.headX or options.snakeX
    local y = options.hitY or options.y or options.headY or options.snakeY

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

function Game:applyHitStop(intensity, duration)
    intensity = math.max(intensity or 0, 0)
    duration = math.max(duration or 0, 0)

    if intensity <= 0 or duration <= 0 then
        return
    end

    local state = ensureHitStopState(self)
    state.timer = math.max(state.timer or 0, duration)
    state.duration = math.max(state.duration or 0, duration)
    state.intensity = math.min(0.95, math.max(state.intensity or 0, intensity))
end

function Game:triggerImpactFeedback(strength, options)
    local state = ensureFeedbackState(self)
    strength = math.max(strength or 0, 0)

    local duration = 0.28 + strength * 0.24
    state.impactDuration = duration
    state.impactTimer = duration

    local spike = 0.55 + strength * 0.65
    state.impactPeak = math.min(1.25, math.max(state.impactPeak or 0, spike))
    state.panicBurst = math.min(1.35, (state.panicBurst or 0) + 0.35 + strength * 0.4)

    local impactRipple = state.impactRipple or {}
    local rx, ry = resolveFeedbackPosition(self, options)
    impactRipple.x = rx
    impactRipple.y = ry
    impactRipple.baseRadius = (options and options.radius) or impactRipple.baseRadius or 54
    impactRipple.color = cloneColor(options and options.color, { 1, 0.42, 0.32, 1 })
    state.impactRipple = impactRipple

    local hitStopStrength = 0.3 + strength * 0.35
    local hitStopDuration = 0.08 + strength * 0.08
    self:applyHitStop(hitStopStrength, hitStopDuration)

    if Shaders and Shaders.notify then
        Shaders.notify("specialEvent", {
            type = "danger",
            strength = math.min(1.2, 0.45 + strength * 0.55),
        })
    end
end

function Game:triggerPanicFeedback(strength)
    local state = ensureFeedbackState(self)
    strength = math.max(strength or 0, 0)

    local baseDuration = state.panicDuration or 2.6
    local duration = baseDuration * (0.55 + strength * 0.5)
    state.panicTimer = math.max(state.panicTimer or 0, duration)
    state.panicBurst = math.min(1.5, (state.panicBurst or 0) + 0.5 + strength * 0.5)
    state.dangerPulseTimer = 0
end

function Game:triggerSurgeFeedback(strength, options)
    local state = ensureFeedbackState(self)
    strength = math.max(strength or 0, 0)

    local duration = 0.6 + strength * 0.4
    state.surgeDuration = duration
    state.surgeTimer = duration
    local surgeSpike = 0.45 + strength * 0.55
    state.surgePeak = math.min(1.15, math.max(state.surgePeak or 0, surgeSpike))

    local ripple = state.surgeRipple or {}
    local rx, ry = resolveFeedbackPosition(self, options)
    ripple.x = rx
    ripple.y = ry
    ripple.baseRadius = (options and options.radius) or ripple.baseRadius or 48
    ripple.color = cloneColor(options and options.color, { 1, 0.9, 0.55, 1 })
    state.surgeRipple = ripple

    if Shaders and Shaders.notify then
        Shaders.notify("specialEvent", {
            type = "tension",
            strength = math.min(1.0, 0.3 + strength * 0.45),
        })
    end
end

local function callMode(self, methodName, ...)
    local mode = self.mode
    if not mode then
        return
    end

    local handler = mode[methodName]
    if handler then
        return handler(self, ...)
    end
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

    if not love or not love.mouse then
        cachedMouseInterface = nil
        return nil
    end

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

local function ensureHitStopState(self)
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

    state.timer = math.max(0, (state.timer or 0) - (dt or 0))
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

    local progress = math.max(0, math.min(1, timer / duration))
    local slow = 1 - easeOutCubic(progress) * math.min(intensity, 0.95)
    return math.max(0.1, slow)
end

local function resolveMouseVisibilityTarget(self)
    if not InputMode:isMouseActive() then
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
    for _, system in ipairs(systems) do
        local updater = system.update
        if updater then
            updater(system, dt)
        end
    end
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
    local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
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

    if Snake.adrenaline and Snake.adrenaline.active then
        local duration = Snake.adrenaline.duration or 1
        if duration > 0 then
            local adrenalineStrength = math.max(0, math.min(1, (Snake.adrenaline.timer or 0) / duration))
            glowStrength = math.max(glowStrength, adrenalineStrength * 0.85)
        end
    end

    if glowStrength <= 0 then return end

    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local pulse = 0.85 + 0.15 * math.sin(time * 2.25)
    local easedStrength = 0.6 + glowStrength * 0.4
    local alpha = 0.18 * easedStrength * pulse

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.65, 0.82, 0.95, alpha)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.pop()
end

function Game:load()
    self.state = "playing"
    self.floor = 1
    self.runTimer = 0
    self.floorTimer = 0

    self.mouseCursorState = nil

    Screen:update()
    self.screenWidth, self.screenHeight = Screen:get()
    Arena:updateScreenBounds(self.screenWidth, self.screenHeight)

    Score:load()
    Upgrades:beginRun()
    GameUtils:prepareGame(self.screenWidth, self.screenHeight)
    Face:set("idle")

    self.transition = TransitionManager.new(self)
    self.input = GameInput.new(self, self.transition)
    self.input:resetAxes()

    resetFeedbackState(self)

    local talentEffects = TalentTree and TalentTree.getAggregatedEffects and TalentTree:getAggregatedEffects()

    self.mode = GameModes:get()
    self.singleTouchDeath = (self.mode and self.mode.singleTouchDeath) or false
    if self.mode and self.mode.usesHealthSystem ~= nil then
        self.usesHealthSystem = self.mode.usesHealthSystem
    else
        self.usesHealthSystem = true
    end

    if self:usesHealth() then
        local startingMax = (self.mode and self.mode.maxHealth) or 3
        if talentEffects and talentEffects.maxHealthBonus then
            startingMax = startingMax + talentEffects.maxHealthBonus
        end

        self.maxHealth = clampToInt(startingMax)
        if self.maxHealth <= 0 then
            self.maxHealth = 1
        end

        self.healthSystem = HealthSystem.new(self.maxHealth)
        self.health = self.maxHealth
    else
        self.maxHealth = 0
        self.healthSystem = nil
        self.health = nil
    end

    if TalentTree and TalentTree.applyRunModifiers then
        TalentTree:applyRunModifiers(self, talentEffects)
    end

    if self:usesHealth() then
        self.healthCriticalReady = true
        self:syncHealth({ immediate = true })
    else
        self.healthCriticalReady = false
        self.health = nil
        if UI and UI.setHealth then
            UI:setHealth(0, 0, { immediate = true })
        end
    end
    callMode(self, "load")

    if Snake.adrenaline then
        Snake.adrenaline.active = false
    end

    self:setupFloor(self.floor)

    self.transition:startFloorIntro(3.5, {
        transitionAdvance = false,
        transitionFloorData = Floors[self.floor] or Floors[1],
    })
end

function Game:reset()
    GameUtils:prepareGame(self.screenWidth, self.screenHeight)
    Face:set("idle")
    self.state = "playing"
    self.floor = 1
    self.runTimer = 0
    self.floorTimer = 0

    self.mouseCursorState = nil

    resetFeedbackState(self)

    if self.healthSystem then
        self.healthSystem:reset(self.maxHealth)
        self.healthCriticalReady = true
        self:syncHealth({ immediate = true })
    end

    if self.transition then
        self.transition:reset()
    end

    if self.input then
        self.input:resetAxes()
    end
end

function Game:enter()
    UI.clearButtons()
    self:load()

    Audio:playMusic("game")
    SessionStats:reset()
    PlayerStats:add("sessionsPlayed", 1)

    Achievements:checkAll({
        sessionsPlayed = PlayerStats:get("sessionsPlayed"),
    })

    callMode(self, "enter")

    self:updateMouseVisibility()
end

function Game:leave()
    callMode(self, "leave")

    self:releaseMouseVisibility()

    if Snake and Snake.resetModifiers then
        Snake:resetModifiers()
    end

    if UI and UI.setUpgradeIndicators then
        UI:setUpgradeIndicators(nil)
    end
end

function Game:beginDeath()
    if self.state ~= "dying" then
        self.state = "dying"
        if self.healthSystem then
            self.healthSystem:setCurrent(0)
        end
        self.health = 0
        UI:setHealth(self.health, self.maxHealth, { immediate = true })
        if Snake and Snake.setDead then
            Snake:setDead(true)
        end
        local trail = Snake:getSegments()
        Death:spawnFromSnake(trail, SnakeUtils.SEGMENT_SIZE)
        Audio:playSound("death")
    end
end

function Game:applyDamage(amount, cause, context)
    amount = clampToInt(amount or 1)
    if amount <= 0 then
        return true
    end

    if context then
        context.inflictedDamage = amount
    end

    local impactStrength = math.max(0.35, ((context and context.shake) or 0) + amount * 0.12)

    if Snake and Snake.onDamageTaken then
        Snake:onDamageTaken(cause, context)
    end

    self:triggerImpactFeedback(impactStrength, context)

    if self.singleTouchDeath or not self:usesHealth() then
        if Settings.screenShake ~= false and context and context.shake and self.Effects and self.Effects.shake then
            self.Effects:shake(context.shake)
        end
        return false
    end

    local system = self:_ensureHealthSystem()
    if not system then
        return false
    end

    if self.health == nil then
        self.health = system:getCurrent()
    end

    local _, updated, alive = system:damage(amount)
    self:syncHealth()

    if not alive or updated <= 0 then
        return false
    end

    if Settings.screenShake ~= false and context and context.shake and self.Effects and self.Effects.shake then
        self.Effects:shake(context.shake)
    end

    if system:isCritical() then
        self:triggerCriticalHealth(cause, context)
    end

    return true
end

function Game:restoreHealth(amount, context)
    if not self:usesHealth() then
        return 0, 0
    end

    local system = self:_ensureHealthSystem()

    amount = clampToInt(amount or 0)
    if amount <= 0 then
        return 0, 0
    end

    local restored, overflow = system:heal(amount)
    if restored <= 0 and overflow <= 0 then
        return 0, 0
    end

    self:syncHealth(context)

    if system:getCurrent() > (system.criticalThreshold or 1) then
        self.healthCriticalReady = true
        if UI and UI.calmHealthCritical then
            UI:calmHealthCritical()
        end
    end

    local forged = 0
    if overflow > 0 and context and context.overflowToShields and Snake and Snake.addCrashShields then
        forged = overflow
        Snake:addCrashShields(forged)
        context.crashShieldsForged = forged
    end

    return restored, forged
end

function Game:startDescending(holeX, holeY, holeRadius)
    self.state = "descending"
    self.hole = { x = holeX, y = holeY, radius = holeRadius or 24 }
    Snake:startDescending(self.hole.x, self.hole.y, self.hole.radius)
    Audio:playSound("exit_enter")
end

-- start a floor transition
function Game:startFloorTransition(advance, skipFade)
    Snake:finishDescending()
    self.transition:startFloorTransition(advance, skipFade)
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
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < self.hole.radius then
        Snake:finishDescending()
        self:startFloorTransition(true)
    end
end

function Game:updateGameplay(dt)
    local fruitX, fruitY = Fruit:getPosition()

    if Upgrades and Upgrades.recordFloorReplaySnapshot then
        Upgrades:recordFloorReplaySnapshot(self)
    end

    local moveResult, cause, context = Movement:update(dt)

    if moveResult == "hit" then
        local damage = (context and context.damage) or 1
        local survived = self:applyDamage(damage, cause, context)
        if not survived then
            local replayTriggered = false
            if self:usesHealth() and Upgrades.tryFloorReplay then
                replayTriggered = Upgrades:tryFloorReplay(self, cause)
            end
            if replayTriggered then
                local system = self:_ensureHealthSystem()
                if system then
                    local resetValue = math.max(1, self.maxHealth or 1)
                    system:setCurrent(resetValue)
                    self.healthCriticalReady = true
                    self:syncHealth({ immediate = true })
                    return
                end
            end
            self.deathCause = cause
            self:beginDeath()
        end
        return
    elseif moveResult == "dead" then
        local replayTriggered = false
        if self:usesHealth() and Upgrades.tryFloorReplay then
            replayTriggered = Upgrades:tryFloorReplay(self, cause)
        end
        if replayTriggered then
            local system = self:_ensureHealthSystem()
            if system then
                local resetValue = math.max(1, self.maxHealth or 1)
                system:setCurrent(resetValue)
                self.healthCriticalReady = true
                self:syncHealth({ immediate = true })
                return
            end
        end
        self.deathCause = cause
        self:beginDeath()
        return
    end

    if moveResult == "scored" then
        FruitEvents.handleConsumption(fruitX, fruitY)

        local goalReached = UI:isGoalReached()
        if goalReached then
            Arena:spawnExit()
        end

        local comboCount = FruitEvents.getComboCount and FruitEvents.getComboCount() or 0
        local surgeStrength = 0.45 + math.min(comboCount, 6) * 0.08
        if goalReached then
            surgeStrength = surgeStrength + 0.25
        end

        self:triggerSurgeFeedback(surgeStrength, { x = fruitX, y = fruitY })
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

function Game:handleDeath(dt)
    if self.state ~= "dying" then
        return
    end

    Death:update(dt)
    if not Death:isFinished() then
        return
    end

    Achievements:save()
    local result = Score:handleGameOver(self.deathCause)
    if result then
        return { state = "gameover", data = result }
    end
end

local function drawPlayfieldLayers(self, stateOverride)
    local renderState = stateOverride or self.state

    Arena:drawBackground()
    Death:applyShake()

    Fruit:draw()
    Rocks:draw()
    Lasers:draw()
    Darts:draw()
    Saws:draw()

    local isDescending = (renderState == "descending")
    if not isDescending then
        Arena:drawExit()
    end

    if isDescending then
        self:drawDescending()
    elseif renderState == "dying" then
        Death:draw()
    elseif renderState ~= "gameover" then
        Snake:draw()
    end

    Particles:draw()
    UpgradeVisuals:draw()
    Popup:draw()
    Arena:drawBorder()
end

local function drawDeveloperAssistBadge(self)
    if not (Snake.isDeveloperAssistEnabled and Snake:isDeveloperAssistEnabled()) then
        return
    end

    local fonts = UI and UI.fonts
    local badgeFont = fonts and (fonts.caption or fonts.prompt or fonts.body)
    local previousFont = love.graphics.getFont()
    if badgeFont then
        love.graphics.setFont(badgeFont)
    else
        badgeFont = previousFont
    end

    local label = "DEV ASSIST ENABLED (F1)"
    local textWidth = badgeFont and badgeFont:getWidth(label) or (#label * 7)
    local textHeight = badgeFont and badgeFont:getHeight() or 16
    local paddingX = 16
    local paddingY = 10
    local margin = 24
    local boxWidth = textWidth + paddingX * 2
    local boxHeight = textHeight + paddingY * 2
    local x = (self.screenWidth or 0) - boxWidth - margin
    local y = margin

    love.graphics.setColor(0.1, 0.14, 0.21, 0.72)
    love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 10, 10)

    love.graphics.setColor(0.28, 0.42, 0.58, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, boxWidth, boxHeight, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.85, 0.97, 1, 1)
    love.graphics.print(label, x + paddingX, y + paddingY)

    love.graphics.setColor(1, 1, 1, 1)
    if previousFont then
        love.graphics.setFont(previousFont)
    end
end

local function drawInterfaceLayers(self)
    FloatingText:draw()

    drawAdrenalineGlow(self)

    drawFeedbackOverlay(self)

    Death:drawFlash(self.screenWidth, self.screenHeight)
    PauseMenu:draw(self.screenWidth, self.screenHeight)
    UI:draw()
    drawDeveloperAssistBadge(self)
    Achievements:draw()

    callMode(self, "draw", self.screenWidth, self.screenHeight)
end

local function drawTransitionFadeOut(self, timer, duration)
    local progress = easedProgress(timer, duration)
    local overlayAlpha = progress * 0.9
    local scale = 1 - 0.04 * easeOutExpo(progress)
    local yOffset = 24 * progress

    love.graphics.push()
    love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2 + yOffset)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-self.screenWidth / 2, -self.screenHeight / 2)
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.pop()

    love.graphics.setColor(0, 0, 0, overlayAlpha)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, overlayAlpha * 0.25)
    local radius = math.sqrt(self.screenWidth * self.screenWidth + self.screenHeight * self.screenHeight)
    love.graphics.circle("fill", self.screenWidth / 2, self.screenHeight / 2, radius, 64)
    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
    love.graphics.setColor(1, 0.84, 0.48, overlayAlpha * 0.16)
    local burstRadius = radius * (0.32 + 0.4 * progress)
    local burstArms = 5
    love.graphics.setLineWidth(2 + progress * 3)
    for i = 1, burstArms do
        local armAngle = time * 0.45 + (i / burstArms) * math.pi * 2
        love.graphics.arc("line", "open", self.screenWidth / 2, self.screenHeight / 2, burstRadius, armAngle, armAngle + math.pi * (0.25 + 0.35 * progress))
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)

    return true
end

local function drawTransitionShop(self, timer)
    local entrance = easeOutBack(clamp01(timer / 0.6))
    local scale = 0.92 + 0.08 * entrance
    local yOffset = (1 - entrance) * 40

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.push()
    love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2 + yOffset)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-self.screenWidth / 2, -self.screenHeight / 2)
    Shop:draw(self.screenWidth, self.screenHeight)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

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

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }

    love.graphics.setFont(UI.fonts.title)
    local titleY = self.screenHeight / 2 - 90
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadow[4] or 0.5)
    love.graphics.printf(floorData.name or "", 2, titleY + 2, self.screenWidth, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(floorData.name or "", 0, titleY, self.screenWidth, "center")

    if floorData.flavor and floorData.flavor ~= "" then
        love.graphics.setFont(UI.fonts.button)
        local flavorY = titleY + UI.fonts.title:getHeight() + 32
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadow[4] or 0.5)
        love.graphics.printf(floorData.flavor, 2, flavorY + 2, self.screenWidth, "center")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(floorData.flavor, 0, flavorY, self.screenWidth, "center")
    end

    drawTransitionNotes(self, 999, 1, nil)

    if data.transitionAwaitInput then
        local promptText = Localization:get("game.floor_intro.prompt")
        if promptText and promptText ~= "" then
            local promptFont = UI.fonts.prompt or UI.fonts.body
            love.graphics.setFont(promptFont)
            local y = self.screenHeight - promptFont:getHeight() * 2.2
            love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadow[4] or 0.5)
            love.graphics.printf(promptText, 2, y + 2, self.screenWidth, "center")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(promptText, 0, y, self.screenWidth, "center")
        end
    end

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
    local data = self.transition:getData() or {}

    if phase == "fadeout" then
        if drawTransitionFadeOut(self, timer, duration) then
            return
        end
    elseif phase == "shop" then
        if drawTransitionShop(self, timer) then
            return
        end
    elseif phase == "floorintro" then
        if drawTransitionFloorIntro(self, timer, duration, data) then
            return
        end
    elseif phase == "fadein" then
        local progress = easedProgress(timer, duration)
        local alpha = 1 - progress
        local yOffset = alpha * 20

        love.graphics.push()
        love.graphics.translate(0, yOffset)
        drawPlayfieldLayers(self, "playing")
        love.graphics.pop()

        drawInterfaceLayers(self)

        love.graphics.setColor(0, 0, 0, alpha * 0.85)
        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, alpha * 0.2)
        local radius = math.sqrt(self.screenWidth * self.screenWidth + self.screenHeight * self.screenHeight) * 0.75
        love.graphics.circle("fill", self.screenWidth / 2, self.screenHeight / 2, radius, 64)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Game:drawStateTransition(direction, progress, eased, alpha)
    local isFloorTransition = false
    if self.transition and self.transition:isActive() then
        local phase = self.transition:getPhase()
        isFloorTransition = phase ~= nil
    end

    if direction == "out" and not isFloorTransition then
        return nil
    end

    self:draw()

    if isFloorTransition then
        love.graphics.setColor(1, 1, 1, 1)
        return { skipOverlay = true }
    end

    if direction == "in" then
        local width = self.screenWidth or love.graphics.getWidth()
        local height = self.screenHeight or love.graphics.getHeight()

        if alpha and alpha > 0 then
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.rectangle("fill", 0, 0, width, height)
        end

        love.graphics.setColor(1, 1, 1, 1)
        return { skipOverlay = true }
    end

    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function Game:drawDescending()
    Arena:drawExit()

    if not self.hole then
        Snake:draw()
        return
    end

    local hx, hy, hr = self.hole.x, self.hole.y, self.hole.radius

    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.circle("fill", hx, hy, hr)

    love.graphics.setColor(0, 0, 0, 1)
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", hx, hy, hr)
    love.graphics.setLineWidth(previousLineWidth)

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

    updateRunTimers(self, scaledDt)

    updateGlobalSystems(scaledDt)

    local transition = self.transition
    local transitionBlocking = false
    if transition and transition:isActive() then
        transition:update(scaledDt)
        transitionBlocking = transition.isGameplayBlocked and transition:isGameplayBlocked()
    end

    if transitionBlocking then
        return
    end

    local stateHandler = STATE_UPDATERS[self.state]
    if stateHandler and stateHandler(self, scaledDt) then
        return
    end

    callMode(self, "update", scaledDt)

    if self.state == "playing" then
        self:updateGameplay(scaledDt)
    end

    self:updateEntities(scaledDt)
    UI:setUpgradeIndicators(Upgrades:getHUDIndicators())

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

    local healAmount = traitContext and traitContext.floorHeal
    if healAmount == nil and self.mode and self.mode.floorHeal ~= nil then
        healAmount = self.mode.floorHeal
    end
    if healAmount == nil then
        healAmount = 1
    end
    healAmount = tonumber(healAmount) or 0

    local restoredHealth, forgedShields = 0, 0
    if healAmount > 0 and self:usesHealth() then
        local overflowToShields = true
        local system = self:_ensureHealthSystem()
        if system then
            local current = system:getCurrent() or 0
            local max = system:getMax() or 0
            if max > 0 and current >= max then
                overflowToShields = false
            end
        end

        local restored, forged = self:restoreHealth(healAmount, {
            source = "floorIntro",
            overflowToShields = overflowToShields,
        })
        restoredHealth = restored or 0
        forgedShields = forged or 0
    end

    UI:setFruitGoal(traitContext.fruitGoal)

    local restNotes = {}
    if restoredHealth and restoredHealth > 0 then
        local healSectionTitle = Localization:get("game.floor_intro.heal_section_title")
        local healText = Localization:get("game.floor_intro.heal_note", {
            amount = restoredHealth,
        })
        table.insert(restNotes, { title = healSectionTitle, text = healText })
    end

    if forgedShields and forgedShields > 0 then
        local healSectionTitle = Localization:get("game.floor_intro.heal_section_title")
        local shieldText = Localization:get("game.floor_intro.shield_note", {
            amount = forgedShields,
        })
        table.insert(restNotes, { title = healSectionTitle, text = shieldText })
    end

    if #restNotes > 0 then
        self.transitionNotes = {}
        for _, note in ipairs(restNotes) do
            table.insert(self.transitionNotes, {
                title = note.title,
                text = note.text,
            })
        end
    else
        self.transitionNotes = nil
    end

    Upgrades:applyPersistentEffects(true)

    if Snake.adrenaline then
        Snake.adrenaline.active = false
        Snake.adrenaline.timer = 0
    end

    FloorSetup.finalizeContext(traitContext, spawnPlan)
    Upgrades:notify("floorStart", { floor = floorNum, context = traitContext })

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

function Game:keypressed(key)
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
