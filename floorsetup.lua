local Theme = require("theme")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Arena = require("arena")
local BackgroundAmbience = require("backgroundambience")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Conveyors = require("conveyors")
local Saws = require("saws")
local Movement = require("movement")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local FloorTraits = require("floortraits")
local FloorPlan = require("floorplan")
local Upgrades = require("upgrades")

local FloorSetup = {}

local TRACK_LENGTH = 120
local DEFAULT_SAW_RADIUS = 16

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
    local reservedSafeZone = SnakeUtils.reserveCells(safeZone)

    return safeZone, reservedCells, reservedSafeZone
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

local function buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone)
    local halfTiles = math.floor((TRACK_LENGTH / Arena.tileSize) / 2)

    return {
        numRocks = traitContext.rocks,
        numSaws = traitContext.saws,
        numConveyors = math.max(0, math.min(8, math.floor((traitContext.conveyors or 0) + 0.5))),
        halfTiles = halfTiles,
        bladeRadius = DEFAULT_SAW_RADIUS,
        safeZone = safeZone,
        reservedCells = reservedCells,
        reservedSafeZone = reservedSafeZone,
    }
end

function FloorSetup.prepare(floorNum, floorData)
    applyPalette(floorData and floorData.palette)
    Arena:setBackgroundEffect(floorData and floorData.backgroundEffect, floorData and floorData.palette)
    BackgroundAmbience.configure(floorData)
    resetFloorEntities()
    local safeZone, reservedCells, reservedSafeZone = prepareOccupancy()

    local traitContext = FloorPlan.buildBaselineFloorContext(floorNum)
    applyBaselineHazardTraits(traitContext)

    local adjustedContext, appliedTraits = FloorTraits:apply(floorData and floorData.traits, traitContext)
    traitContext = adjustedContext or traitContext

    traitContext = Upgrades:modifyFloorContext(traitContext)
    traitContext.conveyors = math.max(0, traitContext.conveyors or 0)

    local spawnPlan = buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone)

    return {
        traitContext = traitContext,
        appliedTraits = appliedTraits or {},
        spawnPlan = spawnPlan,
    }
end

function FloorSetup.finalizeContext(traitContext, spawnPlan)
    finalizeTraitContext(traitContext, spawnPlan.numConveyors)
end

function FloorSetup.spawnHazards(spawnPlan)
    spawnSaws(spawnPlan.numSaws or 0, spawnPlan.halfTiles, spawnPlan.bladeRadius)
    spawnConveyors(spawnPlan.numConveyors or 0, spawnPlan.halfTiles)
    spawnRocks(spawnPlan.numRocks or 0, spawnPlan.safeZone)
    Fruit:spawn(Snake:getSegments(), Rocks, spawnPlan.safeZone)
    SnakeUtils.releaseCells(spawnPlan.reservedSafeZone)
    SnakeUtils.releaseCells(spawnPlan.reservedCells)
end

return FloorSetup
