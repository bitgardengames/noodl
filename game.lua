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
local FruitWallet = require("fruitwallet")

local Game = {}
local TRACK_LENGTH = 120

local function clamp01(value)
        if value < 0 then return 0 end
        if value > 1 then return 1 end
        return value
end

local function easeInOutCubic(t)
        if t < 0.5 then
                return 4 * t * t * t
        end
        t = (2 * t) - 2
        return 0.5 * t * t * t + 1
end

local function easeOutExpo(t)
        if t >= 1 then return 1 end
        return 1 - math.pow(2, -10 * t)
end

local function easeOutBack(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local function easedProgress(timer, duration)
        if not duration or duration <= 0 then
                return 1
        end

        return easeInOutCubic(clamp01(timer / duration))
end

local function buildModifierSections(self)
    local sections = {}

    if self.activeFloorTraits and #self.activeFloorTraits > 0 then
        table.insert(sections, { title = "Floor Traits", items = self.activeFloorTraits })
    end

    if #sections == 0 then
        return nil
    end

    return sections
end

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

    love.graphics.setBlendMode("add")

    if glowStrength > 0 then
        local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 5)
        love.graphics.setColor(0.7, 0.9, 1.0, 0.35 * glowStrength * pulse)
        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    end

    love.graphics.setBlendMode("alpha")
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
        self.transitionTraits = buildModifierSections(self)

        -- first intro: fade-in text for floor 1 only
        self:startFloorIntro(3.5, {
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
        FruitWallet:resetRun()
        FruitWallet:registerFruits(Fruit:getFruitTypes())
        PlayerStats:add("sessionsPlayed", 1)
        Achievements:checkAll({
                sessionsPlayed = PlayerStats:get("sessionsPlayed"),
        })
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
        startTransitionPhase(self, "fadeout", skipFade and 0 or 1.2, {
                transitionAdvance = advance,
                pendingFloor = pendingFloor,
                transitionFloorData = floorData,
                floorApplied = false,
        })
end

function Game:openShop()
        Shop:start(self.floor)
        self.shopCloseRequested = nil
        startTransitionPhase(self, "shop", 0)
end

function Game:startFloorIntro(duration, extra)
        extra = extra or {}

        if extra.transitionResumePhase == nil then
                extra.transitionResumePhase = "fadein"
        end

        if extra.transitionResumePhase == "fadein" and extra.transitionResumeFadeDuration == nil then
                extra.transitionResumeFadeDuration = 1.2
        elseif extra.transitionResumePhase ~= "fadein" then
                extra.transitionResumeFadeDuration = nil
        end

        startTransitionPhase(self, "floorintro", duration or 3.5, extra)
end

function Game:startFadeIn(duration)
        startTransitionPhase(self, "fadein", duration or 1.2)
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
                if self.shopCloseRequested and Shop:isSelectionComplete() then
                        self.shopCloseRequested = nil
                        self:startFloorIntro()
                end

        elseif self.transitionPhase == "floorintro" then
                if self.transitionTimer >= self.transitionDuration then
                        local resumePhase = self.transitionResumePhase or "fadein"
                        local fadeDuration = self.transitionResumeFadeDuration

                        self.transitionResumePhase = nil
                        self.transitionResumeFadeDuration = nil

                        if resumePhase == "fadein" then
                                self:startFadeIn(fadeDuration or 1.2)
                        else
                                self.state = "playing"
                                self.transitionPhase = nil
                        end
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

local function drawPlayfieldLayers(self, stateOverride)
        local renderState = stateOverride or self.state

        Arena:drawBackground()
        Death:applyShake()

        Fruit:draw()
        Rocks:draw()
        Saws:draw()
        Arena:drawExit()

        if renderState == "descending" then
                self:drawDescending()
        elseif renderState == "dying" then
                Death:draw()
        elseif renderState ~= "gameover" then
                Snake:draw()
        end

        Particles:draw()
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

        if self.mode and self.mode.draw then
                self.mode.draw(self, self.screenWidth, self.screenHeight)
        end
end

function Game:drawTransition()
        if self.transitionPhase == "fadeout" then
                local progress = easedProgress(self.transitionTimer, self.transitionDuration)
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
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(1, 1, 1, 1)
                return
        end

        if self.transitionPhase == "shop" then
                local entrance = easeOutBack(clamp01((self.transitionTimer or 0) / 0.6))
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
                return
        end

        if self.transitionPhase == "floorintro" then
                local data = self.transitionFloorData or self.currentFloorData
                if data then
                        local timer = self.transitionTimer or 0
                        local duration = self.transitionDuration or 0
                        local progress = easedProgress(timer, duration)
                        local outroDuration = math.min(0.6, duration > 0 and duration * 0.5 or 0)
                        local outroProgress = 0
                        if outroDuration > 0 then
                                local outroStart = math.max(0, duration - outroDuration)
                                outroProgress = clamp01((timer - outroStart) / outroDuration)
                        end
                        local outroAlpha = 1 - outroProgress

                        local overlayAlpha = math.min(0.75, progress * 0.85)
                        if outroProgress > 0 then
                                overlayAlpha = overlayAlpha + (1 - overlayAlpha) * outroProgress
                        end
                        love.graphics.setColor(0, 0, 0, overlayAlpha)
                        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
                        love.graphics.setColor(1, 1, 1, 1)

                        local function fadeAlpha(delay, fadeDuration)
                                local alpha = progress * clamp01((timer - delay) / (fadeDuration or 0.35))
                                return alpha * outroAlpha
                        end

                        local nameAlpha = fadeAlpha(0.0, 0.45)
                        if nameAlpha > 0 then
                                local titleProgress = easeOutBack(clamp01((timer - 0.1) / 0.6))
                                local titleScale = 0.9 + 0.1 * titleProgress
                                local yOffset = (1 - titleProgress) * 36 * outroAlpha
                                love.graphics.setFont(UI.fonts.title)
                                love.graphics.setColor(1, 1, 1, nameAlpha)
                                love.graphics.push()
                                love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2 - 80 + yOffset)
                                love.graphics.scale(titleScale, titleScale)
                                love.graphics.translate(-self.screenWidth / 2, -(self.screenHeight / 2 - 80 + yOffset))
                                love.graphics.printf(data.name, 0, self.screenHeight / 2 - 80 + yOffset, self.screenWidth, "center")
                                love.graphics.pop()
                        end

                        if data.flavor and data.flavor ~= "" then
                                local flavorAlpha = fadeAlpha(0.45, 0.4)
                                if flavorAlpha > 0 then
                                        local flavorProgress = easeOutExpo(clamp01((timer - 0.45) / 0.65))
                                        local flavorOffset = (1 - flavorProgress) * 24 * outroAlpha
                                        love.graphics.setFont(UI.fonts.button)
                                        love.graphics.setColor(1, 1, 1, flavorAlpha)
                                        love.graphics.push()
                                        love.graphics.translate(0, flavorOffset)
                                        love.graphics.printf(data.flavor, 0, self.screenHeight / 2, self.screenWidth, "center")
                                        love.graphics.pop()
                                end
                        end

                        local sections = self.transitionTraits or buildModifierSections(self)
                        if sections and #sections > 0 then
                                local entries = {}
                                for _, section in ipairs(sections) do
                                        if section.items and #section.items > 0 then
                                                table.insert(entries, { type = "header", title = section.title or "Traits" })
                                                for _, trait in ipairs(section.items) do
                                                        table.insert(entries, {
                                                                type = "trait",
                                                                title = section.title,
                                                                name = trait.name,
                                                                desc = trait.desc,
                                                        })
                                                end
                                        end
                                end

                                local y = self.screenHeight / 2 + 64
                                local width = self.screenWidth * 0.6
                                local x = self.screenWidth * 0.2
                                local index = 0

                                for _, entry in ipairs(entries) do
                                        index = index + 1
                                        local traitAlpha = fadeAlpha(0.9 + (index - 1) * 0.25, 0.45)
                                        local traitOffset = (1 - easeOutExpo(clamp01((timer - (0.9 + (index - 1) * 0.25)) / 0.6))) * 18 * outroAlpha

                                        if entry.type == "header" then
                                                local headerHeight = UI.fonts.button:getHeight() + 6
                                                if traitAlpha > 0 then
                                                        love.graphics.setFont(UI.fonts.button)
                                                        love.graphics.setColor(1, 1, 1, traitAlpha)
                                                        love.graphics.printf(entry.title or "Traits", x, y + traitOffset, width, "center")
                                                end
                                                y = y + headerHeight
                                        else
                                                local text = (entry.name or "") .. ": " .. (entry.desc or "")
                                                local _, wrapped = UI.fonts.body:getWrap(text, width)
                                                local lines = math.max(1, #wrapped)
                                                local blockHeight = lines * UI.fonts.body:getHeight() + 18
                                                if traitAlpha > 0 then
                                                        love.graphics.setFont(UI.fonts.body)
                                                        love.graphics.setColor(1, 1, 1, traitAlpha)
                                                        love.graphics.printf(text, x, y + traitOffset, width, "center")
                                                end
                                                y = y + blockHeight
                                        end
                                end
                        end
                end

                love.graphics.setColor(1, 1, 1, 1)
                return
        end

        if self.transitionPhase == "fadein" then
                local progress = easedProgress(self.transitionTimer, self.transitionDuration)
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
    self.transitionTraits = buildModifierSections(self)

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

        drawPlayfieldLayers(self)
        drawInterfaceLayers(self)
end

function Game:keypressed(key)
        if self.transitionPhase == "shop" then
                if Shop:keypressed(key) then
                        self.shopCloseRequested = true
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
                        self.shopCloseRequested = true
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
                if button == "start" then
                        self.state = "playing"
                        return
                end

                local action = PauseMenu:gamepadpressed(nil, button)
                if action == "resume" then
                        self.state = "playing"
                elseif action == "menu" then
                        Achievements:save()
                        return "menu"
                end
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
