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
local Conveyors = require("conveyors")
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
local GameModes = require("gamemodes")
local GameUtils = require("gameutils")
local Saws = require("saws")
local Lasers = require("lasers")
local Death = require("death")
local Floors = require("floors")
local Shop = require("shop")
local Upgrades = require("upgrades")
local Localization = require("localization")
local FloorSetup = require("floorsetup")
local TransitionManager = require("transitionmanager")
local GameInput = require("gameinput")
local InputMode = require("inputmode")

local Game = {}

local clamp01 = Easing.clamp01
local easeOutExpo = Easing.easeOutExpo
local easeOutBack = Easing.easeOutBack
local easedProgress = Easing.easedProgress

local RUN_ACTIVE_STATES = {
    playing = true,
    descending = true,
}

local ENTITY_UPDATE_ORDER = {
    Face,
    Popup,
    Fruit,
    Rocks,
    Conveyors,
    Lasers,
    Saws,
    Arena,
    Particles,
    UpgradeVisuals,
    Achievements,
    FloatingText,
    Score,
}

local MAX_TRANSITION_TRAITS = 4

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

local function canManageMouseVisibility()
    if not love or not love.mouse or not love.mouse.setVisible then
        return false
    end

    if love.mouse.isCursorSupported then
        local supported = love.mouse.isCursorSupported()
        if supported == false then
            return false
        end
    end

    return true
end

function Game:releaseMouseVisibility()
    if not self.mouseCursorManaged then
        return
    end

    if canManageMouseVisibility() then
        local restore = self.mouseCursorOriginalVisible
        if restore == nil then
            restore = true
        end
        love.mouse.setVisible(restore and true or false)
    end

    self.mouseCursorManaged = false
    self.mouseCursorOriginalVisible = nil
    self.mouseCursorCurrentVisible = nil
end

function Game:updateMouseVisibility()
    if not canManageMouseVisibility() then
        self:releaseMouseVisibility()
        return
    end

    local usingMouse = InputMode:isMouseActive()
    local transition = self.transition
    local inShop = transition and transition:isShopActive()
    local isGameplayState = RUN_ACTIVE_STATES[self.state] == true
    local shouldManage = usingMouse and (inShop or isGameplayState)

    if not shouldManage then
        self:releaseMouseVisibility()
        return
    end

    if not self.mouseCursorManaged then
        local currentVisible = true
        if love.mouse.isVisible then
            currentVisible = love.mouse.isVisible()
        end
        self.mouseCursorManaged = true
        self.mouseCursorOriginalVisible = currentVisible
        self.mouseCursorCurrentVisible = currentVisible
    end

    local targetVisible = inShop
    if self.mouseCursorCurrentVisible ~= targetVisible then
        love.mouse.setVisible(targetVisible)
        self.mouseCursorCurrentVisible = targetVisible
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

local function getScaledDeltaTime(dt)
    if not (Snake.getTimeScale and dt) then
        return dt
    end

    local scale = Snake:getTimeScale()
    if scale and scale > 0 then
        return dt * scale
    end

    return dt
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
    PauseMenu:update(dt, paused)
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

local function buildTraitEntries(sections, maxTraits)
    local entries = {}
    local totalTraits, shownTraits = 0, 0

    for _, section in ipairs(sections) do
        local traits = section.items
        if traits and #traits > 0 then
            local addedHeader = false

            for _, trait in ipairs(traits) do
                totalTraits = totalTraits + 1

                if shownTraits < maxTraits then
                    if not addedHeader then
                        table.insert(entries, {
                            type = "header",
                            title = section.title or Localization:get("game.floor_traits.default_title"),
                        })
                        addedHeader = true
                    end

                    table.insert(entries, {
                        type = "trait",
                        name = trait.name,
                    })
                    shownTraits = shownTraits + 1
                end
            end
        end
    end

    return entries, totalTraits, shownTraits
end

local STATE_UPDATERS = {
    descending = function(self, dt)
        self:updateDescending(dt)
        return true
    end,
}

local function buildModifierSections(self)
    local sections = {}

    if self.activeFloorTraits and #self.activeFloorTraits > 0 then
        table.insert(sections, {
            title = Localization:get("game.floor_traits.section_title"),
            items = self.activeFloorTraits,
        })
    end

    if #sections == 0 then
        return nil
    end

    return sections
end

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

    self.mouseCursorManaged = false
    self.mouseCursorOriginalVisible = nil
    self.mouseCursorCurrentVisible = nil

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

    self.mode = GameModes:get()
    callMode(self, "load")

    if Snake.adrenaline then
        Snake.adrenaline.active = false
    end

    self:setupFloor(self.floor)
    self.transitionTraits = buildModifierSections(self)

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
        local trail = Snake:getSegments()
        Death:spawnFromSnake(trail, SnakeUtils.SEGMENT_SIZE)
        Audio:playSound("death")
    end
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

    local moveResult, cause = Movement:update(dt)

    if moveResult == "dead" then
        if Upgrades.tryFloorReplay and Upgrades:tryFloorReplay(self, cause) then
            return
        end
        self.deathCause = cause
        self:beginDeath()
        return
    end

    if moveResult == "scored" then
        FruitEvents.handleConsumption(fruitX, fruitY)

        if UI:isGoalReached() then
            Arena:spawnExit()
        end
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
    Conveyors:draw()
    Saws:draw()
    Lasers:draw()
    Arena:drawExit()

    if renderState == "descending" then
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

local function drawInterfaceLayers(self)
    FloatingText:draw()

    drawAdrenalineGlow(self)

    Death:drawFlash(self.screenWidth, self.screenHeight)
    PauseMenu:draw(self.screenWidth, self.screenHeight)
    UI:draw()
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

local function drawTraitEntries(self, timer, outroAlpha, fadeAlpha)
    local sections = self.transitionTraits or buildModifierSections(self)
    if not (sections and #sections > 0) then
        return
    end

    local entries, totalTraits, shownTraits = buildTraitEntries(sections, MAX_TRANSITION_TRAITS)
    if #entries == 0 then
        return
    end

    local remaining = math.max(0, totalTraits - shownTraits)
    if remaining > 0 then
        local suffixKey = (remaining == 1)
            and "game.floor_traits.more_modifiers_one"
            or "game.floor_traits.more_modifiers_other"
        table.insert(entries, {
            type = "note",
            text = Localization:get(suffixKey, {
                count = remaining,
            }),
        })
    end

    local y = self.screenHeight / 2 + 64
    local width = self.screenWidth * 0.45
    local x = (self.screenWidth - width) / 2
    local index = 0
    local buttonFont = UI.fonts.button
    local bodyFont = UI.fonts.body

    for _, entry in ipairs(entries) do
        index = index + 1
        local offsetDelay = 0.9 + (index - 1) * 0.22
        local traitAlpha = fadeAlpha(offsetDelay, 0.4)
        local traitOffset = (1 - easeOutExpo(clamp01((timer - offsetDelay) / 0.55))) * 16 * outroAlpha

        if entry.type == "header" then
            drawShadowedText(
                buttonFont,
                entry.title or Localization:get("game.floor_traits.default_title"),
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + buttonFont:getHeight() + 4
        elseif entry.type == "trait" then
            drawShadowedText(
                buttonFont,
                "• " .. (entry.name or ""),
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + buttonFont:getHeight() + 6
        elseif entry.type == "note" then
            drawShadowedText(
                bodyFont,
                entry.text or "",
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + bodyFont:getHeight()
        end
    end
end

local function drawTransitionFloorIntro(self, timer, duration, data)
    local floorData = data.transitionFloorData or self.currentFloorData
    if not floorData then
        return
    end

    local progress = easedProgress(timer, duration)
    local awaitingInput = data.transitionAwaitInput
    local introConfirmed = data.transitionIntroConfirmed
    local outroDuration = math.min(0.6, duration > 0 and duration * 0.5 or 0)
    local outroProgress = 0
    if outroDuration > 0 then
        local outroStart = math.max(0, duration - outroDuration)
        local outroTimer = timer
        if awaitingInput and not introConfirmed then
            outroTimer = math.min(outroTimer, outroStart)
        end
        outroProgress = clamp01((outroTimer - outroStart) / outroDuration)
    end
    local outroAlpha = 1 - outroProgress

    local overlayAlpha = math.min(0.75, progress * 0.85)
    if outroProgress > 0 then
        overlayAlpha = overlayAlpha + (1 - overlayAlpha) * outroProgress
    end
    love.graphics.setColor(0, 0, 0, overlayAlpha)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    local bloomProgress = 0.55 + 0.45 * progress
    local bloomIntensity = bloomProgress * (0.45 + 0.55 * outroAlpha)
    if Arena.drawBackgroundEffect then
        Arena:drawBackgroundEffect(0, 0, self.screenWidth, self.screenHeight, bloomIntensity)
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

    local function fadeAlpha(delay, fadeDuration)
        local alpha = progress * clamp01((timer - delay) / (fadeDuration or 0.35))
        return alpha * outroAlpha
    end

    local nameAlpha = fadeAlpha(0.0, 0.45)
    local titleParams
    if nameAlpha > 0 then
        local titleProgress = easeOutBack(clamp01((timer - 0.1) / 0.6))
        local titleScale = 0.9 + 0.1 * titleProgress
        local yOffset = (1 - titleProgress) * 36 * outroAlpha
        local centerY = self.screenHeight / 2 - 80 + yOffset
        titleParams = {
            alpha = nameAlpha,
            scale = titleScale,
            centerY = centerY,
            padding = 12,
        }
    end

    local flavorParams
    local flavorAlpha = 0
    if floorData.flavor and floorData.flavor ~= "" then
        flavorAlpha = fadeAlpha(0.45, 0.4)
        if flavorAlpha > 0 then
            local flavorProgress = easeOutExpo(clamp01((timer - 0.45) / 0.65))
            local flavorOffset = (1 - flavorProgress) * 24 * outroAlpha
            local flavorPadding = 10
            local flavorHeight = UI.fonts.button:getHeight() + flavorPadding * 2
            flavorParams = {
                alpha = flavorAlpha,
                offset = flavorOffset,
                padding = flavorPadding,
                height = flavorHeight,
                y = self.screenHeight / 2 - flavorPadding + flavorOffset,
            }
        end
    end

    if titleParams or flavorParams then
        local top = math.huge
        local bottom = -math.huge
        local backdropAlpha = 0

        if titleParams then
            local titleHeight = (UI.fonts.title:getHeight() + titleParams.padding * 2) * titleParams.scale
            local titleTop = titleParams.centerY - titleParams.padding * titleParams.scale
            local titleBottom = titleTop + titleHeight
            top = math.min(top, titleTop)
            bottom = math.max(bottom, titleBottom)
            backdropAlpha = math.max(backdropAlpha, 0.6 * titleParams.alpha)
        end

        if flavorParams then
            local flavorTop = flavorParams.y
            local flavorBottom = flavorTop + flavorParams.height
            top = math.min(top, flavorTop)
            bottom = math.max(bottom, flavorBottom)
            backdropAlpha = math.max(backdropAlpha, 0.55 * flavorParams.alpha)
        end

        if top < bottom and backdropAlpha > 0 then
            local bandPadding = 4
            top = top - bandPadding
            bottom = bottom + bandPadding
            love.graphics.setColor(0, 0, 0, backdropAlpha)
            love.graphics.rectangle("fill", 0, top, self.screenWidth, bottom - top)
        end
    end

    if titleParams then
        love.graphics.setFont(UI.fonts.title)
        love.graphics.push()
        love.graphics.translate(self.screenWidth / 2, titleParams.centerY)
        love.graphics.scale(titleParams.scale, titleParams.scale)
        love.graphics.translate(-self.screenWidth / 2, -titleParams.centerY)
        local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * titleParams.alpha)
        love.graphics.printf(floorData.name, 2, titleParams.centerY + 2, self.screenWidth, "center")
        love.graphics.setColor(1, 1, 1, titleParams.alpha)
        love.graphics.printf(floorData.name, 0, titleParams.centerY, self.screenWidth, "center")
        love.graphics.pop()
    end

    if flavorParams then
        love.graphics.setFont(UI.fonts.button)
        love.graphics.push()
        love.graphics.translate(0, flavorParams.offset)
        local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * flavorParams.alpha)
        love.graphics.printf(floorData.flavor, 2, self.screenHeight / 2 + 2, self.screenWidth, "center")
        love.graphics.setColor(1, 1, 1, flavorParams.alpha)
        love.graphics.printf(floorData.flavor, 0, self.screenHeight / 2, self.screenWidth, "center")
        love.graphics.pop()
    end

    drawTraitEntries(self, timer, outroAlpha, fadeAlpha)

    if data.transitionAwaitInput then
        local introDuration = data.transitionIntroDuration or duration or 0
        local promptDelay = data.transitionIntroPromptDelay or 0
        local promptStart = introDuration + promptDelay
        local promptProgress = clamp01((timer - promptStart) / 0.45)
        local promptAlpha = promptProgress * outroAlpha

        if promptAlpha > 0 then
            local promptText = Localization:get("game.floor_intro.prompt")
            if promptText and promptText ~= "" then
                local promptFont = UI.fonts.prompt or UI.fonts.body
                love.graphics.setFont(promptFont)
                local y = self.screenHeight - promptFont:getHeight() * 2.2
                local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
                love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * promptAlpha)
                love.graphics.printf(promptText, 2, y + 2, self.screenWidth, "center")
                love.graphics.setColor(1, 1, 1, promptAlpha)
                love.graphics.printf(promptText, 0, y, self.screenWidth, "center")
            end
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
        local scale = 1 + 0.03 * alpha
        local yOffset = alpha * 20

        love.graphics.push()
        love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2 + yOffset)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-self.screenWidth / 2, -self.screenHeight / 2)
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
    local isFloorTransition = (self.state == "transition")

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
    if not self.hole then
        Snake:draw()
        return
    end

    local hx, hy, hr = self.hole.x, self.hole.y, self.hole.radius

    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.circle("fill", hx, hy, hr)

    Snake:drawClipped(hx, hy, hr)

    love.graphics.setColor(0, 0, 0, 1)
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", hx, hy, hr)
    love.graphics.setLineWidth(previousLineWidth)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:update(dt)
    self:updateMouseVisibility()

    if handlePauseMenu(self, dt) then
        return
    end

    local scaledDt = getScaledDeltaTime(dt)

    updateRunTimers(self, scaledDt)

    updateGlobalSystems(scaledDt)

    if self:isTransitionActive() then
        self.transition:update(scaledDt)
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
    local appliedTraits = setup.appliedTraits
    local spawnPlan = setup.spawnPlan

    UI:setFruitGoal(traitContext.fruitGoal)
    UI:setFloorModifiers(appliedTraits)
    self.activeFloorTraits = appliedTraits
    self.transitionTraits = buildModifierSections(self)

    Upgrades:applyPersistentEffects(true)

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
