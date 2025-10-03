local Audio = require("audio")
local Screen = require("screen")
local Controls = require("controls")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
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
local Upgrades = require("upgrades")
local FloorSetup = require("floorsetup")
local TransitionManager = require("transitionmanager")
local GameInput = require("gameinput")
local InputMode = require("inputmode")
local GameRenderer = require("game_renderer")

local Game = {}

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

local STATE_UPDATERS = {
    descending = function(self, dt)
        self:updateDescending(dt)
        return true
    end,
}

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
    self.transitionTraits = GameRenderer.buildModifierSections(self.activeFloorTraits)

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

function Game:update(dt)
    self:updateMouseVisibility()

    if self.state == "paused" then
        PauseMenu:update(dt, true)
        return
    end

    PauseMenu:update(dt, false)

    local scaledDt = getScaledDeltaTime(dt)

    updateRunTimers(self, scaledDt)

    FruitEvents.update(scaledDt)
    Shaders.update(scaledDt)

    if self.transition and self.transition:isActive() then
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
    self.transitionTraits = GameRenderer.buildModifierSections(self.activeFloorTraits)

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

    if self.transition and self.transition:isActive() then
        GameRenderer.drawTransition(self, callMode)
        return
    end

    GameRenderer.drawPlayfield(self)
    GameRenderer.drawInterface(self, callMode)
end

function Game:keypressed(key)
    if self.input and self.input:handleShopInput("keypressed", key) then
        return
    end

    if self.transition and self.transition:confirmFloorIntro() then
        return
    end

    Controls:keypressed(self, key)
end

function Game:mousepressed(x, y, button)
    if self.transition and self.transition:confirmFloorIntro() then
        return
    end

    if self.state == "paused" then
        PauseMenu:mousepressed(x, y, button)
        return
    end

    if self.input then
        self.input:handleShopInput("mousepressed", x, y, button)
    end
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
    if self.transition and self.transition:confirmFloorIntro() then
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
