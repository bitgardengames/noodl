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
local Popup = require("popup")
local Score = require("score")
local PauseMenu = require("pausemenu")
local Movement = require("movement")
local Particles = require("particles")
local Achievements = require("achievements")
local FloatingText = require("floatingtext")
local Arena = require("arena")
local UI = require("ui")
local Theme = require("theme")
local FruitEvents = require("fruitevents")
local FloorTraits = require("floortraits")
local GameModes = require("gamemodes")
local GameUtils = require("gameutils")
local Saws = require("saws")
local Death = require("death")
local Floors = require("floors")
local Shop = require("shop")
local Upgrades = require("upgrades")

local Game = {}
local TRACK_LENGTH = 120

local function startTransitionPhase(self, phase, duration, extra)
    self.state = "transition"
    self.transitionPhase = phase
    self.transitionTimer = 0
    self.transitionDuration = duration or 0

    if extra then
        for key, value in pairs(extra) do
            self[key] = value
        end
    end
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

    local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 5)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.7, 0.9, 1.0, 0.35 * glowStrength * pulse)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.setBlendMode("alpha")

    local vignetteAlpha = 0.45 * glowStrength
    local borderThickness = 120
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(0, 0, 0, vignetteAlpha)
    love.graphics.setLineWidth(borderThickness)
    love.graphics.rectangle(
        "line",
        borderThickness / 2,
        borderThickness / 2,
        math.max(0, self.screenWidth - borderThickness),
        math.max(0, self.screenHeight - borderThickness),
        48,
        48
    )
    love.graphics.setLineWidth(previousLineWidth)
    love.graphics.setColor(1, 1, 1, 1)
end

function Game:load()
        self.state = "playing"
        self.floor = 1

        Screen:update()
        self.screenWidth, self.screenHeight = Screen:get()
        Arena:updateScreenBounds(self.screenWidth, self.screenHeight)

        Score:load()
        Upgrades:beginRun()
        GameUtils:prepareGame(self.screenWidth, self.screenHeight)
        Face:set("idle")

        self.mode = GameModes:get()
        if self.mode and self.mode.load then
                self.mode.load(self)
        end

        if Snake.adrenaline then Snake.adrenaline.active = false end -- reset adrenaline state

        -- prepare floor 1 immediately for gameplay (theme, spawns, etc.)
        self:setupFloor(self.floor)
        self.transitionTraits = self.activeFloorTraits

        -- first intro: fade-in text for floor 1 only
        startTransitionPhase(self, "floorintro", 2.5, {
                transitionAdvance = false,
                transitionFloorData = Floors[self.floor] or Floors[1],
        })
end

function Game:reset()
	GameUtils:prepareGame(self.screenWidth, self.screenHeight)
	Face:set("idle")
	self.state = "playing"
	self.floor = 1
end

function Game:enter()
    UI.clearButtons()
    self:load()
	Audio:playMusic("game")
	SessionStats:reset()
	PlayerStats:add("sessionsPlayed", 1)
	if self.mode and self.mode.enter then
		self.mode.enter(self)
	end
end

function Game:leave()
	if self.mode and self.mode.leave then
		self.mode.leave(self)
	end
end

function Game:beginDeath()
	if self.state ~= "dying" then
		self.state = "dying"
		local trail = Snake:getSegments()
		Death:spawnFromSnake(trail, SnakeUtils.SEGMENT_SIZE)
	end
end

function Game:startDescending(holeX, holeY, holeRadius)
    self.state = "descending"
    self.hole = {x = holeX, y = holeY, radius = holeRadius or 24}
    Snake:startDescending(self.hole.x, self.hole.y, self.hole.radius)
end

-- start a floor transition
function Game:startFloorTransition(advance, skipFade)
        Snake:finishDescending()
        local pendingFloor = advance and (self.floor + 1) or nil
        local floorData = Floors[pendingFloor or self.floor] or Floors[1]
        startTransitionPhase(self, "fadeout", skipFade and 0 or 1.0, {
                transitionAdvance = advance,
                pendingFloor = pendingFloor,
                transitionFloorData = floorData,
                floorApplied = false,
        })
end

function Game:openShop()
        Shop:start(self.floor)
        startTransitionPhase(self, "shop", 0)
end

function Game:startFloorIntro(duration, extra)
        startTransitionPhase(self, "floorintro", duration or 2.5, extra)
end

function Game:startFadeIn(duration)
        startTransitionPhase(self, "fadein", duration or 1.0)
end

function Game:updateTransition(dt)
        self.transitionTimer = self.transitionTimer + dt

        if self.transitionPhase == "fadeout" then
                if self.transitionTimer >= self.transitionDuration then
                        if self.transitionAdvance and not self.floorApplied and self.pendingFloor then
                                self.floor = self.pendingFloor
                                self:setupFloor(self.floor)
                                self.floorApplied = true
                        end

                        self:openShop()
                end

        elseif self.transitionPhase == "shop" then
                Shop:update(dt)

        elseif self.transitionPhase == "floorintro" then
                if self.transitionTimer >= self.transitionDuration then
                        self:startFadeIn(1.0)
                end

        elseif self.transitionPhase == "fadein" then
                if self.transitionTimer >= self.transitionDuration then
                        self.state = "playing"
                        self.transitionPhase = nil
                end
        end
end

function Game:updateDescending(dt)
        Snake:update(dt)

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
        local moveResult, cause = Movement:update(dt)

        if moveResult == "dead" then
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
        Face:update(dt)
        Popup:update(dt)
        Fruit:update(dt)
        Rocks:update(dt)
        Saws:update(dt)
        Arena:update(dt)
        Particles:update(dt)
        Achievements:update(dt)
        FloatingText:update(dt)
        Score:update(dt)
end

function Game:handleDeath(dt)
        if self.state ~= "dying" then return end

        Death:update(dt)
        if not Death:isFinished() then return end

        Achievements:save()
        local result = Score:handleGameOver(self.deathCause)
        if result then
                return { state = "gameover", data = result }
        end
end

function Game:drawTransition()
        if self.transitionPhase == "fadeout" then
                local alpha = (self.transitionDuration <= 0) and 1 or math.min(1, self.transitionTimer / self.transitionDuration)
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
                love.graphics.setColor(1, 1, 1, 1)
                return
        end

        if self.transitionPhase == "shop" then
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
                Shop:draw(self.screenWidth, self.screenHeight)
                love.graphics.setColor(1, 1, 1, 1)
                return
        end

        if self.transitionPhase == "floorintro" then
                local data = self.transitionFloorData or self.currentFloorData
                if data then
                        local timer = self.transitionTimer or 0
                        local progress = (self.transitionDuration <= 0) and 1 or math.min(1, timer / self.transitionDuration)

                        local function fadeAlpha(delay, duration)
                                local t = math.max(0, math.min(1, (timer - delay) / (duration or 0.35)))
                                return progress * t
                        end

                        local nameAlpha = fadeAlpha(0.0, 0.4)
                        if nameAlpha > 0 then
                                love.graphics.setFont(UI.fonts.title)
                                love.graphics.setColor(1, 1, 1, nameAlpha)
                                love.graphics.printf(data.name, 0, self.screenHeight / 2 - 80, self.screenWidth, "center")
                        end

                        if data.flavor and data.flavor ~= "" then
                                local flavorAlpha = fadeAlpha(0.45, 0.4)
                                if flavorAlpha > 0 then
                                        love.graphics.setFont(UI.fonts.button)
                                        love.graphics.setColor(1, 1, 1, flavorAlpha)
                                        love.graphics.printf(data.flavor, 0, self.screenHeight / 2, self.screenWidth, "center")
                                end
                        end

                        local traits = self.transitionTraits or self.activeFloorTraits
                        if traits and #traits > 0 then
                                love.graphics.setFont(UI.fonts.body)
                                local y = self.screenHeight / 2 + 64
                                for i, trait in ipairs(traits) do
                                        local traitAlpha = fadeAlpha(1.0 + (i - 1) * 0.25, 0.35)
                                        if traitAlpha > 0 then
                                                love.graphics.setColor(1, 1, 1, traitAlpha)
                                                local text = trait.name .. ": " .. trait.desc
                                                love.graphics.printf(text, self.screenWidth * 0.2, y + (i - 1) * 36, self.screenWidth * 0.6, "center")
                                        end
                                end
                        end
                end

                love.graphics.setColor(1, 1, 1, 1)
                return
        end

        if self.transitionPhase == "fadein" then
                local progress = (self.transitionDuration <= 0) and 1 or math.min(1, self.transitionTimer / self.transitionDuration)
                local alpha = 1 - progress
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
                love.graphics.setColor(1, 1, 1, 1)
        end
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
        if self.state == "paused" then
                PauseMenu:update(dt, true)
                return
        end

        PauseMenu:update(dt, false)
        FruitEvents.update(dt)

        if self.state == "transition" then
                self:updateTransition(dt)
                return
        end

        if self.state == "descending" then
                self:updateDescending(dt)
                return
        end

        if self.mode and self.mode.update then
                self.mode.update(self, dt)
        end

        if self.state == "playing" then
                self:updateGameplay(dt)
        end

        self:updateEntities(dt)

        local result = self:handleDeath(dt)
        if result then
                return result
        end
end

function Game:setupFloor(floorNum)
    self.currentFloorData = Floors[floorNum] or Floors[1]

    FruitEvents.reset()

    if self.currentFloorData.palette then
        for k, v in pairs(self.currentFloorData.palette) do
            Theme[k] = v
        end
    end

    -- reset entities
    Arena:resetExit()
    Movement:reset()
    FloatingText:reset()
    Particles:reset()
    Rocks:reset()
    Saws:reset()
    SnakeUtils.initOccupancy()

    for _, seg in ipairs(Snake:getSegments()) do
        local col, row = Arena:getTileFromWorld(seg.drawX, seg.drawY)
        SnakeUtils.setOccupied(col, row, true)
    end

    -- difficulty scaling baseline with floor traits
    local traitContext = {
        floor = floorNum,
        fruitGoal = floorNum * 5,
        rocks = math.min(3 + floorNum * 2, 40),
        saws = math.min(math.floor(floorNum / 2), 8),
    }

    local adjustedContext, appliedTraits = FloorTraits:apply(self.currentFloorData.traits, traitContext)
    traitContext = adjustedContext or traitContext
    traitContext = Upgrades:modifyFloorContext(traitContext)

    UI:setFruitGoal(traitContext.fruitGoal)
    UI:setFloorModifiers(appliedTraits)
    self.activeFloorTraits = appliedTraits
    self.transitionTraits = appliedTraits

    Upgrades:applyPersistentEffects(true)
    Upgrades:notify("floorStart", { floor = floorNum, context = traitContext })

    local numRocks = traitContext.rocks
    local numSaws = traitContext.saws
    local safeZone = Snake:getSafeZone(3)

    -- Spawn saws FIRST so they reserve their track cells
	for i = 1, numSaws do
		local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
		local halfTiles = math.floor((TRACK_LENGTH / Arena.tileSize) / 2)
		local r = 16 -- blade radius

		if dir == "horizontal" then
			-- Pick a row inside borders
			local row = love.math.random(2, Arena.rows - 1)
			-- Pick a safe column so track fits horizontally
			local col = love.math.random(1 + halfTiles, Arena.cols - halfTiles)

			local fx, fy = Arena:getCenterOfTile(col, row)
			Saws:spawn(fx, fy, r, 8, "horizontal")
			SnakeUtils.occupySawTrack(fx, fy, "horizontal", r, TRACK_LENGTH)

		else -- vertical
			local side = (love.math.random() < 0.5) and "left" or "right"
			local col = (side == "left") and 1 or Arena.cols
			-- Pick a safe row so track fits vertically
			local row = love.math.random(1 + halfTiles, Arena.rows - halfTiles)

			local fx, fy = Arena:getCenterOfTile(col, row)
			Saws:spawn(fx, fy, r, 8, "vertical", side)
			SnakeUtils.occupySawTrack(fx, fy, "vertical", r, TRACK_LENGTH, side)
		end
	end

    -- Now spawn rocks
    for i = 1, numRocks do
        local fx, fy = SnakeUtils.getSafeSpawn(Snake:getSegments(), Fruit, Rocks, safeZone)
        if fx then
            Rocks:spawn(fx, fy, "small")
            local c, r = Arena:getTileFromWorld(fx, fy)
            SnakeUtils.setOccupied(c, r, true)
        end
    end

    Fruit:spawn(Snake:getSegments(), Rocks)

    --FloatingText:add("Floor " .. floorNum, self.screenWidth/2, self.screenHeight/2, {1,1,0}, 2)
end

function Game:draw()
        love.graphics.clear()

        love.graphics.setColor(Theme.bgColor)
        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

        if self.state == "transition" then
                self:drawTransition()
                return
        end

        Arena:drawBackground()
        Death:applyShake()

        Fruit:draw()
        Rocks:draw()
        Saws:draw()
        Arena:drawExit()

        if self.state == "descending" then
                self:drawDescending()
        elseif self.state == "dying" then
                Death:draw()
        elseif self.state ~= "gameover" then
                Snake:draw()
        end

        Particles:draw()
        Popup:draw()
        Arena:drawBorder()
        FloatingText:draw()

        drawAdrenalineGlow(self)

        Death:drawFlash(self.screenWidth, self.screenHeight)
        PauseMenu:draw(self.screenWidth, self.screenHeight)
        UI:draw()
        Achievements:draw()

        if self.mode and self.mode.draw then
                self.mode.draw(self, self.screenWidth, self.screenHeight)
        end
end

function Game:keypressed(key)
        if self.transitionPhase == "shop" then
                if Shop:keypressed(key) then
                        self:startFloorIntro()
                end
        else
                Controls:keypressed(self, key)
        end
end

function Game:mousepressed(x, y, button)
    if self.state == "paused" then
        PauseMenu:mousepressed(x, y, button)

    elseif self.transitionPhase == "shop" then
        if Shop:mousepressed(x, y, button) then
            self:startFloorIntro()
        end
        end
end

function Game:mousereleased(x, y, button)
	if self.state == "paused" and button == 1 then
		local clicked = PauseMenu:mousereleased(x, y, button)
		if clicked == "resume" then
			self.state = "playing"
		elseif clicked == "menu" then
			Achievements:save()
			return "menu"
		end
	end
end

local map = { dpleft="left", dpright="right", dpup="up", dpdown="down" }
local function handleGamepadInput(self, button)
	if self.state == "paused" then
		if button == "start" then self.state = "playing" end
	else
		if map[button] then
			Controls:keypressed(self, map[button])
		elseif button == "start" and self.state == "playing" then
			self.state = "paused"
		end
	end
end

function Game:gamepadpressed(_, button)
	return handleGamepadInput(self, button)
end
Game.joystickpressed = Game.gamepadpressed

return Game
