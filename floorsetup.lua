local Theme = require("theme")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Arena = require("arena")
local BackgroundAmbience = require("backgroundambience")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Conveyors = require("conveyors")
local Saws = require("saws")
local Lasers = require("lasers")
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
    if Theme.reset then
        Theme.reset()
    end

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
    Lasers:reset()
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
    traitContext.laserCount = math.max(0, traitContext.laserCount or 0)

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

local function finalizeTraitContext(traitContext, spawnPlan)
    traitContext.rockSpawnChance = Rocks:getSpawnChance()
    traitContext.sawSpeedMult = Saws.speedMult
    traitContext.sawSpinMult = Saws.spinMult

    if Saws.getStallOnFruit then
        traitContext.sawStall = Saws:getStallOnFruit()
    else
        traitContext.sawStall = Saws.stallOnFruit or 0
    end

    traitContext.conveyors = spawnPlan.numConveyors or 0
    traitContext.laserCount = spawnPlan.laserCount or #(spawnPlan.lasers or {})
end

local function trySpawnHorizontalSaw(halfTiles, bladeRadius)
    local row = love.math.random(2, Arena.rows - 1)
    local col = love.math.random(1 + halfTiles, Arena.cols - halfTiles)
    local fx, fy = Arena:getCenterOfTile(col, row)

    if SnakeUtils.sawTrackIsFree(fx, fy, "horizontal") then
        Saws:spawn(fx, fy, bladeRadius, 8, "horizontal")
        SnakeUtils.occupySawTrack(fx, fy, "horizontal")
        return true
    end

    return false
end

local function trySpawnVerticalSaw(halfTiles, bladeRadius)
    local side = (love.math.random() < 0.5) and "left" or "right"
    local col = (side == "left") and 1 or Arena.cols
    local row = love.math.random(1 + halfTiles, Arena.rows - halfTiles)
    local fx, fy = Arena:getCenterOfTile(col, row)

    if SnakeUtils.sawTrackIsFree(fx, fy, "vertical") then
        Saws:spawn(fx, fy, bladeRadius, 8, "vertical", side)
        SnakeUtils.occupySawTrack(fx, fy, "vertical")
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

local function spawnLasers(laserPlan)
    if not (laserPlan and #laserPlan > 0) then
        return
    end

    for _, plan in ipairs(laserPlan) do
        Lasers:spawn(plan.x, plan.y, plan.dir, plan.length, plan.options)
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

local function getAmbientLaserPreference(floorData)
    if not floorData then
        return 0
    end

    if floorData.backgroundTheme == "machine" then
        return 2
    end

    if type(floorData.name) == "string" and floorData.name:lower():find("machin") then
        return 2
    end

    if type(floorData.traits) == "table" then
        for _, trait in ipairs(floorData.traits) do
            if trait == "ancientMachinery" then
                return 2
            end
        end
    end

    return 0
end

local function getDesiredLaserCount(traitContext, floorData)
    local baseline = 0

    if traitContext then
        baseline = math.max(0, math.floor((traitContext.laserCount or 0) + 0.5))
    end

    local ambient = getAmbientLaserPreference(floorData)

    return math.max(baseline, ambient)
end

local function buildLaserPlan(traitContext, halfTiles, trackLength, floorData)
    local desired = getDesiredLaserCount(traitContext, floorData)

    if desired <= 0 then
        return {}, 0
    end
    local plan = {}
    local attempts = 0
    local maxAttempts = desired * 40
    local totalCols = math.max(1, Arena.cols or 1)
    local totalRows = math.max(1, Arena.rows or 1)

    while #plan < desired and attempts < maxAttempts do
        attempts = attempts + 1
        local dir = (#plan % 2 == 0) and "horizontal" or "vertical"
        if love.math.random() < 0.5 then
            dir = (dir == "horizontal") and "vertical" or "horizontal"
        end

        local col, row, facing
        if dir == "horizontal" then
            facing = (love.math.random() < 0.5) and 1 or -1
            col = (facing > 0) and 1 or totalCols
            local rowMin = 2
            local rowMax = totalRows - 1

            if rowMax < rowMin then
                local fallback = math.floor(totalRows / 2 + 0.5)
                rowMin = fallback
                rowMax = fallback
            end

            rowMin = math.max(1, math.min(totalRows, rowMin))
            rowMax = math.max(rowMin, math.min(totalRows, rowMax))
            row = love.math.random(rowMin, rowMax)
        else
            facing = (love.math.random() < 0.5) and 1 or -1
            row = (facing > 0) and 1 or totalRows
            local colMin = 2
            local colMax = totalCols - 1

            if colMax < colMin then
                local fallback = math.floor(totalCols / 2 + 0.5)
                colMin = fallback
                colMax = fallback
            end

            colMin = math.max(1, math.min(totalCols, colMin))
            colMax = math.max(colMin, math.min(totalCols, colMax))
            col = love.math.random(colMin, colMax)
        end

        if col and row and not SnakeUtils.isOccupied(col, row) then
            local fx, fy = Arena:getCenterOfTile(col, row)
            local fireDuration = 0.9 + love.math.random() * 0.6
            local fireCooldownMin = 3.5 + love.math.random() * 1.5
            local fireCooldownMax = fireCooldownMin + 2.0 + love.math.random() * 2.0
            local chargeDuration = 0.8 + love.math.random() * 0.4
            local fireColor = {1, 0.12 + love.math.random() * 0.15, 0.15, 1}

            plan[#plan + 1] = {
                x = fx,
                y = fy,
                dir = dir,
                length = trackLength,
                options = {
                    facing = facing,
                    fireDuration = fireDuration,
                    fireCooldownMin = fireCooldownMin,
                    fireCooldownMax = fireCooldownMax,
                    chargeDuration = chargeDuration,
                    fireColor = fireColor,
                },
            }

            SnakeUtils.setOccupied(col, row, true)
        end
    end

    return plan, desired
end

local function buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, floorData)
    local halfTiles = math.floor((TRACK_LENGTH / Arena.tileSize) / 2)
    local laserPlan, desiredLasers = buildLaserPlan(traitContext, halfTiles, TRACK_LENGTH, floorData)

    return {
        numRocks = traitContext.rocks,
        numSaws = traitContext.saws,
        numConveyors = 0,
        halfTiles = halfTiles,
        bladeRadius = DEFAULT_SAW_RADIUS,
        safeZone = safeZone,
        reservedCells = reservedCells,
        reservedSafeZone = reservedSafeZone,
        lasers = laserPlan,
        laserCount = desiredLasers,
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
    traitContext.laserCount = math.max(0, traitContext.laserCount or 0)

    local spawnPlan = buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, floorData)

    return {
        traitContext = traitContext,
        appliedTraits = appliedTraits or {},
        spawnPlan = spawnPlan,
    }
end

function FloorSetup.finalizeContext(traitContext, spawnPlan)
    finalizeTraitContext(traitContext, spawnPlan)
end

function FloorSetup.spawnHazards(spawnPlan)
    spawnSaws(spawnPlan.numSaws or 0, spawnPlan.halfTiles, spawnPlan.bladeRadius)
    spawnLasers(spawnPlan.lasers or {})
    spawnRocks(spawnPlan.numRocks or 0, spawnPlan.safeZone)
    Fruit:spawn(Snake:getSegments(), Rocks, spawnPlan.safeZone)
    SnakeUtils.releaseCells(spawnPlan.reservedSafeZone)
    SnakeUtils.releaseCells(spawnPlan.reservedCells)
end

return FloorSetup
