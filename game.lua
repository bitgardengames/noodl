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
local Achievements = require("achievements")
local FloatingText = require("floatingtext")
local Arena = require("arena")
local UI = require("ui")
local Theme = require("theme")
local FruitEvents = require("fruitevents")
local FloorTraits = require("floortraits")
local FloorPlan = require("floorplan")
local GameModes = require("gamemodes")
local GameUtils = require("gameutils")
local Saws = require("saws")
local Death = require("death")
local Floors = require("floors")
local Shop = require("shop")
local Upgrades = require("upgrades")
local Localization = require("localization")

local Game = {}
local TRACK_LENGTH = 120

local clamp01 = Easing.clamp01
local lerp = Easing.lerp
local easeInOutCubic = Easing.easeInOutCubic
local easeOutExpo = Easing.easeOutExpo
local easeOutBack = Easing.easeOutBack
local easedProgress = Easing.easedProgress

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

local function applyPalette(palette)
    if not palette then
        return
    end

    for key, value in pairs(palette) do
        Theme[key] = value
    end
end

local function resetFloorEntities()
    Arena:resetExit()
    Movement:reset()
    FloatingText:reset()
    Particles:reset()
    Rocks:reset()
    Conveyors:reset()
    Saws:reset()
end

local function prepareOccupancy()
    SnakeUtils.initOccupancy()

    for _, segment in ipairs(Snake:getSegments()) do
        local col, row = Arena:getTileFromWorld(segment.drawX, segment.drawY)
        SnakeUtils.setOccupied(col, row, true)
    end

    local safeZone = Snake:getSafeZone(3)
    local headCol, headRow = Snake:getHeadCell()
    local reservedCandidates = {}

    if headCol and headRow then
        for dx = -1, 1 do
            for dy = -1, 1 do
                reservedCandidates[#reservedCandidates + 1] = { headCol + dx, headRow + dy }
            end
        end
    end

    if safeZone then
        for _, cell in ipairs(safeZone) do
            reservedCandidates[#reservedCandidates + 1] = { cell[1], cell[2] }
        end
    end

    local reservedCells = SnakeUtils.reserveCells(reservedCandidates)

    return safeZone, reservedCells
end

local function applyBaselineHazardTraits(traitContext)
    traitContext.conveyors = math.max(0, traitContext.conveyors or 0)

    if traitContext.rockSpawnChance then
        Rocks.spawnChance = traitContext.rockSpawnChance
    end

    if traitContext.sawSpeedMult then
        Saws.speedMult = traitContext.sawSpeedMult
    end

    if traitContext.sawSpinMult then
        Saws.spinMult = traitContext.sawSpinMult
    end

    if Saws.setStallOnFruit then
        Saws:setStallOnFruit(traitContext.sawStall or 0)
    else
        Saws.stallOnFruit = traitContext.sawStall or 0
    end
end

local function finalizeTraitContext(traitContext, numConveyors)
    traitContext.rockSpawnChance = Rocks:getSpawnChance()
    traitContext.sawSpeedMult = Saws.speedMult
    traitContext.sawSpinMult = Saws.spinMult

    if Saws.getStallOnFruit then
        traitContext.sawStall = Saws:getStallOnFruit()
    else
        traitContext.sawStall = Saws.stallOnFruit or 0
    end

    traitContext.conveyors = numConveyors
end

local function trySpawnHorizontalSaw(halfTiles, bladeRadius)
    local row = love.math.random(2, Arena.rows - 1)
    local col = love.math.random(1 + halfTiles, Arena.cols - halfTiles)
    local fx, fy = Arena:getCenterOfTile(col, row)

    if SnakeUtils.trackIsFree(fx, fy, "horizontal", TRACK_LENGTH) then
        Saws:spawn(fx, fy, bladeRadius, 8, "horizontal")
        SnakeUtils.occupySawTrack(fx, fy, "horizontal", bladeRadius, TRACK_LENGTH)
        return true
    end

    return false
end

local function trySpawnVerticalSaw(halfTiles, bladeRadius)
    local side = (love.math.random() < 0.5) and "left" or "right"
    local col = (side == "left") and 1 or Arena.cols
    local row = love.math.random(1 + halfTiles, Arena.rows - halfTiles)
    local fx, fy = Arena:getCenterOfTile(col, row)

    if SnakeUtils.trackIsFree(fx, fy, "vertical", TRACK_LENGTH) then
        Saws:spawn(fx, fy, bladeRadius, 8, "vertical", side)
        SnakeUtils.occupySawTrack(fx, fy, "vertical", bladeRadius, TRACK_LENGTH, side)
        return true
    end

    return false
end

local function spawnSaws(numSaws, halfTiles, bladeRadius)
    for _ = 1, numSaws do
        local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
        local placed = false
        local attempts = 0
        local maxAttempts = 60

        while not placed and attempts < maxAttempts do
            attempts = attempts + 1

            if dir == "horizontal" then
                placed = trySpawnHorizontalSaw(halfTiles, bladeRadius)
            else
                placed = trySpawnVerticalSaw(halfTiles, bladeRadius)
            end
        end
    end
end

local function chooseConveyorDirection(horizontalPossible, verticalPossible)
    if horizontalPossible and verticalPossible then
        return (love.math.random() < 0.5) and "horizontal" or "vertical"
    elseif horizontalPossible then
        return "horizontal"
    elseif verticalPossible then
        return "vertical"
    end
end

local function trySpawnConveyor(dir, halfTiles, conveyorTrackLength)
    if not dir then
        return false
    end

    if dir == "horizontal" then
        local minCol = 1 + halfTiles
        local maxCol = Arena.cols - halfTiles
        local col = love.math.random(minCol, maxCol)
        local row = love.math.random(1, Arena.rows)
        local fx, fy = Arena:getCenterOfTile(col, row)

        if SnakeUtils.trackIsFree(fx, fy, dir, conveyorTrackLength) then
            Conveyors:spawn(fx, fy, dir, conveyorTrackLength)
            SnakeUtils.occupyTrack(fx, fy, dir, conveyorTrackLength)
            return true
        end
    else
        local col = love.math.random(1, Arena.cols)
        local rowMin = 1 + halfTiles
        local rowMax = Arena.rows - halfTiles
        local row = love.math.random(rowMin, rowMax)
        local fx, fy = Arena:getCenterOfTile(col, row)

        if SnakeUtils.trackIsFree(fx, fy, dir, conveyorTrackLength) then
            Conveyors:spawn(fx, fy, dir, conveyorTrackLength)
            SnakeUtils.occupyTrack(fx, fy, dir, conveyorTrackLength)
            return true
        end
    end

    return false
end

local function spawnConveyors(numConveyors, halfTiles)
    local conveyorTrackLength = TRACK_LENGTH
    local horizontalPossible = (1 + halfTiles) <= (Arena.cols - halfTiles)
    local verticalPossible = (1 + halfTiles) <= (Arena.rows - halfTiles)

    for _ = 1, numConveyors do
        local placed = false
        local attempts = 0
        local maxAttempts = 60

        while not placed and attempts < maxAttempts do
            attempts = attempts + 1
            local dir = chooseConveyorDirection(horizontalPossible, verticalPossible)

            if not dir then
                break
            end

            placed = trySpawnConveyor(dir, halfTiles, conveyorTrackLength)
        end
    end
end

local function spawnRocks(numRocks, safeZone)
    for _ = 1, numRocks do
        local fx, fy = SnakeUtils.getSafeSpawn(Snake:getSegments(), Fruit, Rocks, safeZone)
        if fx then
            Rocks:spawn(fx, fy, "small")
            local col, row = Arena:getTileFromWorld(fx, fy)
            SnakeUtils.setOccupied(col, row, true)
        end
    end
end

function Game:load()
        self.state = "playing"
        self.floor = 1
        self.runTimer = 0
        self.floorTimer = 0
        self.gamepadAxisDirections = { horizontal = nil, vertical = nil }

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
        self.gamepadAxisDirections = { horizontal = nil, vertical = nil }
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
                Audio:playSound("death")
        end
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
        local pendingFloor = advance and (self.floor + 1) or nil
        local floorData = Floors[pendingFloor or self.floor] or Floors[1]

        if advance then
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
        end

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
        Audio:playSound("shop_open")
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
        Audio:playSound("floor_intro")
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
        Face:update(dt)
        Popup:update(dt)
        Fruit:update(dt)
        Rocks:update(dt)
        Conveyors:update(dt)
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
        Conveyors:draw()
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
                                local maxTraits = 4
                                local totalTraits = 0
                                local shownTraits = 0

                                for _, section in ipairs(sections) do
                                        if section.items and #section.items > 0 then
                                                local visible = {}
                                                for _, trait in ipairs(section.items) do
                                                        totalTraits = totalTraits + 1
                                                        if shownTraits < maxTraits then
                                                                table.insert(visible, trait)
                                                                shownTraits = shownTraits + 1
                                                        end
                                                end

                                                if #visible > 0 then
                                                        table.insert(entries, {
                                                                type = "header",
                                                                title = section.title or Localization:get("game.floor_traits.default_title"),
                                                        })
                                                        for _, trait in ipairs(visible) do
                                                                table.insert(entries, {
                                                                        type = "trait",
                                                                        name = trait.name,
                                                                })
                                                        end
                                                end
                                        end
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

                                for _, entry in ipairs(entries) do
                                        index = index + 1
                                        local traitAlpha = fadeAlpha(0.9 + (index - 1) * 0.22, 0.4)
                                        local traitOffset = (1 - easeOutExpo(clamp01((timer - (0.9 + (index - 1) * 0.22)) / 0.55))) * 16 * outroAlpha

                                        if entry.type == "header" then
                                                local headerHeight = UI.fonts.button:getHeight() + 4
                                                if traitAlpha > 0 then
                                                        love.graphics.setFont(UI.fonts.button)
                                                        love.graphics.setColor(1, 1, 1, traitAlpha)
                                                        love.graphics.printf(entry.title or Localization:get("game.floor_traits.default_title"), x, y + traitOffset, width, "center")
                                                end
                                                y = y + headerHeight
                                        elseif entry.type == "trait" then
                                                local lineHeight = UI.fonts.button:getHeight()
                                                if traitAlpha > 0 then
                                                        love.graphics.setFont(UI.fonts.button)
                                                        love.graphics.setColor(1, 1, 1, traitAlpha)
                                                        love.graphics.printf("• " .. (entry.name or ""), x, y + traitOffset, width, "center")
                                                end
                                                y = y + lineHeight + 6
                                        elseif entry.type == "note" then
                                                local noteHeight = UI.fonts.body:getHeight()
                                                if traitAlpha > 0 then
                                                        love.graphics.setFont(UI.fonts.body)
                                                        love.graphics.setColor(1, 1, 1, traitAlpha)
                                                        love.graphics.printf(entry.text or "", x, y + traitOffset, width, "center")
                                                end
                                                y = y + noteHeight
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

        local timeScale = 1
        if Snake.getTimeScale then
                local scale = Snake:getTimeScale()
                if scale and scale > 0 then
                        timeScale = scale
                end
        end
        local scaledDt = dt * timeScale

        local isRunActive = (self.state == "playing" or self.state == "descending")
        if isRunActive then
                SessionStats:add("timeAlive", scaledDt)
                self.runTimer = (self.runTimer or 0) + scaledDt
        end

        if self.state == "playing" then
                self.floorTimer = (self.floorTimer or 0) + scaledDt
        end

        FruitEvents.update(scaledDt)

        if self.state == "transition" then
                self:updateTransition(scaledDt)
                return
        end

        if self.state == "descending" then
                self:updateDescending(scaledDt)
                return
        end

        if self.mode and self.mode.update then
                self.mode.update(self, scaledDt)
        end

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

    applyPalette(self.currentFloorData.palette)

    resetFloorEntities()
    local safeZone, reservedCells = prepareOccupancy()

    local traitContext = FloorPlan.buildBaselineFloorContext(floorNum)
    applyBaselineHazardTraits(traitContext)

    local adjustedContext, appliedTraits = FloorTraits:apply(self.currentFloorData.traits, traitContext)
    traitContext = adjustedContext or traitContext

    traitContext = Upgrades:modifyFloorContext(traitContext)
    traitContext.conveyors = math.max(0, traitContext.conveyors or 0)

    local numRocks = traitContext.rocks
    local numSaws = traitContext.saws
    local numConveyors = math.max(0, math.min(8, math.floor((traitContext.conveyors or 0) + 0.5)))

    UI:setFruitGoal(traitContext.fruitGoal)
    UI:setFloorModifiers(appliedTraits)
    self.activeFloorTraits = appliedTraits
    self.transitionTraits = buildModifierSections(self)

    Upgrades:applyPersistentEffects(true)

    finalizeTraitContext(traitContext, numConveyors)
    Upgrades:notify("floorStart", { floor = floorNum, context = traitContext })

    local halfTiles = math.floor((TRACK_LENGTH / Arena.tileSize) / 2)
    local bladeRadius = 16

    spawnSaws(numSaws, halfTiles, bladeRadius)
    spawnConveyors(numConveyors, halfTiles)
    spawnRocks(numRocks, safeZone)

    Fruit:spawn(Snake:getSegments(), Rocks, safeZone)

    SnakeUtils.releaseCells(reservedCells)
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
        if handleShopInput(self, "keypressed", key) then
                return
        end

        Controls:keypressed(self, key)
end

function Game:mousepressed(x, y, button)
        if self.state == "paused" then
                PauseMenu:mousepressed(x, y, button)
                return
        end

        handleShopInput(self, "mousepressed", x, y, button)
end

function Game:mousereleased(x, y, button)
        if self.state ~= "paused" or button ~= 1 then
                return
        end

        local selection = PauseMenu:mousereleased(x, y, button)
        if not selection then
                return
        end

        return applyPauseMenuSelection(self, selection)
end

local directionButtonMap = { dpleft = "left", dpright = "right", dpup = "up", dpdown = "down" }
local ANALOG_DEADZONE = 0.5
local axisButtonMap = {
        leftx = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
        rightx = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
        lefty = { slot = "vertical", negative = "dpup", positive = "dpdown" },
        righty = { slot = "vertical", negative = "dpup", positive = "dpdown" },
        [1] = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
        [2] = { slot = "vertical", negative = "dpup", positive = "dpdown" },
}

local buttonAliases = {
        a = "dash",
        rightshoulder = "dash",
        righttrigger = "dash",
        x = "slow",
        leftshoulder = "slow",
        lefttrigger = "slow",
}

local playingButtonHandlers = {
        start = function(self)
                if self.state == "playing" then
                        self.state = "paused"
                end
        end,
        dash = function(self)
                if self.state == "playing" then
                        Controls:keypressed(self, "space")
                end
        end,
        slow = function(self)
                if self.state == "playing" then
                        Controls:keypressed(self, "lshift")
                end
        end,
}

local function resolvePlayingAction(button)
        return buttonAliases[button] or button
end

local function isShopActive(self)
        return self.transitionPhase == "shop"
end

local function handleShopInput(self, methodName, ...)
        if not isShopActive(self) then
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

local function applyPauseMenuSelection(self, selection)
        if selection == "resume" then
                self.state = "playing"
        elseif selection == "menu" then
                Achievements:save()
                return "menu"
        end
end

local function handlePauseMenuInput(self, button)
        if button == "start" then
                applyPauseMenuSelection(self, "resume")
                return
        end

        local action = PauseMenu:gamepadpressed(nil, button)
        if action then
                return applyPauseMenuSelection(self, action)
        end
end

local function handlePlayingButton(self, button)
        local direction = directionButtonMap[button]
        if direction then
                Controls:keypressed(self, direction)
                return
        end

        local handler = playingButtonHandlers[resolvePlayingAction(button)]
        if handler then
                return handler(self)
        end
end

local function handleGamepadInput(self, button)
        if handleShopInput(self, "gamepadpressed", nil, button) then
                return
        end

        if self.state == "paused" then
                return handlePauseMenuInput(self, button)
        end

        return handlePlayingButton(self, button)
end

local function handleGamepadAxisInput(self, axis, value)
        if isShopActive(self) and Shop.gamepadaxis then
                Shop:gamepadaxis(nil, axis, value)
        end

        local config = axisButtonMap[axis]
        if not config then
                return
        end

        local state = self.gamepadAxisDirections
        if not state then
                state = { horizontal = nil, vertical = nil }
                self.gamepadAxisDirections = state
        end

        local direction
        if value >= ANALOG_DEADZONE then
                direction = config.positive
        elseif value <= -ANALOG_DEADZONE then
                direction = config.negative
        else
                direction = nil
        end

        if state[config.slot] ~= direction then
                state[config.slot] = direction
                if direction then
                        handleGamepadInput(self, direction)
                end
        end
end

function Game:gamepadpressed(_, button)
        return handleGamepadInput(self, button)
end
Game.joystickpressed = Game.gamepadpressed

function Game:gamepadaxis(_, axis, value)
        return handleGamepadAxisInput(self, axis, value)
end
Game.joystickaxis = Game.gamepadaxis

return Game
