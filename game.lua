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
local GameModes = require("gamemodes")
local GameUtils = require("gameutils")
local Saws = require("saws")
local Death = require("death")
local Floors = require("floors")
local Shop = require("shop")

local Game = {}
local TRACK_LENGTH = 120

function Game:load()
	self.state = "playing"
	self.floor = 1

	Screen:update()
	self.screenWidth, self.screenHeight = Screen:get()
	Arena:updateScreenBounds(self.screenWidth, self.screenHeight)

	Score:load()
	GameUtils:prepareGame(self.screenWidth, self.screenHeight)
	Face:set("idle")

	self.mode = GameModes:get()
	if self.mode and self.mode.load then
		self.mode.load(self)
	end

	if Snake.adrenaline then Snake.adrenaline.active = false end -- reset adrenaline state

	-- prepare floor 1 immediately for gameplay (theme, spawns, etc.)
	self:setupFloor(self.floor)

	-- first intro: fade-in text for floor 1 only
	self.state = "transition"
	self.transitionPhase = "floorintro"
	self.transitionTimer = 0
	self.transitionDuration = 2.5
	self.transitionAdvance = false
	self.transitionFloorData = Floors[self.floor]
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
        self.state = "transition"
        self.transitionPhase = "fadeout"   -- new
	self.transitionTimer = 0
	self.transitionDuration = skipFade and 0 or 1.0
	self.transitionAdvance = advance
	self.pendingFloor = advance and (self.floor + 1) or nil
	self.transitionFloorData = Floors[self.pendingFloor or self.floor] or Floors[1]
	self.floorApplied = false
end

function Game:update(dt)
	--if self.state == "gameover" then return end

        -- pause
        if self.state == "paused" then
                PauseMenu:update(dt, true)
                return
        else
                PauseMenu:update(dt, false)
        end

        FruitEvents.update(dt)

        if self.state == "transition" then
		self.transitionTimer = self.transitionTimer + dt

		if self.transitionPhase == "fadeout" then
			if self.transitionTimer >= self.transitionDuration then
				-- Apply floor in darkness
				if self.transitionAdvance and not self.floorApplied then
					self.floor = self.pendingFloor
					self:setupFloor(self.floor)
					self.floorApplied = true
				end
				self.transitionPhase = "shop"
				self.transitionTimer = 0
				Shop:start()
			end

		elseif self.transitionPhase == "shop" then
			Shop:update(dt)
		elseif self.transitionPhase == "floorintro" then
			if self.transitionTimer >= self.transitionDuration then
				self.transitionPhase = "fadein"
				self.transitionTimer = 0
				self.transitionDuration = 1.0 -- how long the fade back takes
			end

		elseif self.transitionPhase == "fadein" then
			if self.transitionTimer >= self.transitionDuration then
				self.state = "playing"
				self.transitionPhase = nil
			end
		end

		return
	end

    if self.state == "descending" then
        -- let snake keep moving normally toward hole
        Snake:update(dt)

        -- check tail position
        local segments = Snake:getSegments()
        local tail = segments[#segments]
        if not tail then
            Snake:finishDescending()
            self:startFloorTransition(true)
        else
            local dx, dy = tail.drawX - self.hole.x, tail.drawY - self.hole.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < self.hole.radius then
                Snake:finishDescending()
                self:startFloorTransition(true) -- will advance to next floor when finished
            end
        end
        return
    end

	if self.mode and self.mode.update then
		self.mode.update(self, dt)
	end

	-- movement + fruit
	if self.state == "playing" then
		local fruitX, fruitY = Fruit:getPosition()
		local moveResult, cause = Movement:update(dt)
		if moveResult == "dead" then
			self.deathCause = cause
			self:beginDeath()
		elseif moveResult == "scored" then
			FruitEvents.handleConsumption(fruitX, fruitY)

			if UI:isGoalReached() then -- threshold check to unlock exit
				Arena:spawnExit()
			end
		end
	end

	local snakeX, snakeY = Snake:getHead()

	-- next floor trigger
	if Arena:checkExitCollision(snakeX, snakeY) then
		local hx, hy, hr = Arena:getExitCenter()
		if hx and hy then
			self:startDescending(hx, hy, hr)
		end
	end

	-- entity updates
	Face:update(dt)
	Popup:update(dt)
	Fruit:update(dt)
	Rocks:update(dt)
	Saws:update(dt)
	Arena:update(dt)
        Particles:update(dt)
        Achievements:update(dt)
        FloatingText:update(dt)

        if self.state == "dying" then
		Death:update(dt)
		if Death:isFinished() then
			Achievements:save()
			local result = Score:handleGameOver(self.deathCause)
			if result then
				return {state = "gameover", data = result}
			end
		end
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

    -- fruit goal based on actual floorNum
    UI:setFruitGoal(floorNum * 5)

    -- difficulty scaling
    local numRocks = math.min(3 + floorNum * 2, 40)
    local numSaws = math.min(math.floor(floorNum / 2), 8)
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
		local alpha = 1.0
		if self.transitionPhase == "fadeout" then
			alpha = math.min(1, self.transitionTimer / self.transitionDuration)
			love.graphics.setColor(0,0,0,alpha)
			love.graphics.rectangle("fill", 0,0,self.screenWidth,self.screenHeight)
		elseif self.transitionPhase == "shop" then
			love.graphics.setColor(0,0,0,1)
			love.graphics.rectangle("fill", 0,0,self.screenWidth,self.screenHeight)
			Shop:draw(self.screenWidth, self.screenHeight)
		elseif self.transitionPhase == "floorintro" then
			local data = self.transitionFloorData or self.currentFloorData
			if data then
				local t = math.min(1, self.transitionTimer / self.transitionDuration)
				love.graphics.setColor(1,1,1,t)
				love.graphics.setFont(UI.fonts.title)
				love.graphics.printf(data.name, 0, self.screenHeight/2 - 80, self.screenWidth, "center")
				love.graphics.setFont(UI.fonts.button)
				love.graphics.printf(data.flavor, 0, self.screenHeight/2, self.screenWidth, "center")
			end
		elseif self.transitionPhase == "fadein" then
			local t = math.min(1, self.transitionTimer / self.transitionDuration)
			local alpha = 1 - t
			love.graphics.setColor(0, 0, 0, alpha)
			love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
		end
		return
	end

	Arena:drawBackground()
	Death:applyShake()

	Fruit:draw()
	Rocks:draw()
	Saws:draw()
	Arena:drawExit()

	if self.state == "dying" then
		Death:draw()
	elseif self.state ~= "gameover" then
		if self.state == "descending" and self.hole then
			local hx, hy, hr = self.hole.x, self.hole.y, self.hole.radius

			-- draw hole
			love.graphics.setColor(0.05, 0.05, 0.05, 1)
			love.graphics.circle("fill", hx, hy, hr)

			-- draw snake only until it reaches the hole
			Snake:drawClipped(hx, hy, hr)

			-- optional: rim
			love.graphics.setColor(0, 0, 0, 1)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", hx, hy, hr)
		else
			Snake:draw()
		end
	end

	Particles:draw()
	Popup:draw()
	Arena:drawBorder()
	FloatingText:draw()
	PauseMenu:draw(self.screenWidth, self.screenHeight)
	UI:draw()
	Achievements:draw()

	--SnakeUtils.debugDrawOccupancy(SnakeUtils.occupied, Arena.tileSize)
	--SnakeUtils.debugDrawGrid(SnakeUtils.SEGMENT_SIZE)

	if self.mode and self.mode.draw then
		self.mode.draw(self, self.screenWidth, self.screenHeight)
	end
end

function Game:keypressed(key)
	if self.transitionPhase == "shop" then
		if Shop:keypressed(key) then
			self.state = "transition"
			self.transitionPhase = "floorintro"
			self.transitionTimer = 0
			self.transitionDuration = 2.5
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
            self.state = "transition"
            self.transitionPhase = "floorintro"
            self.transitionTimer = 0
            self.transitionDuration = 2.5
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