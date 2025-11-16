local Theme = require("theme")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Arena = require("arena")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Movement = require("movement")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local FloorPlan = require("floorplan")
local Upgrades = require("upgrades")

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min

local FloorSetup = {}

local TRACK_LENGTH = 120
local DEFAULT_SAW_RADIUS = 16
local EMBER_SAW_COLOR = {1.0, 0.47, 0.18, 1}
local EMBER_SAW_TRAIL_COLOR = {1.0, 0.32, 0.08, 0.2}
local EMBER_SAW_GLOW_COLOR = {1.0, 0.62, 0.22, 0.44}
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
	if Arena.clearSpawnDebugData then
		Arena:clearSpawnDebugData()
	end
	Movement:reset()
	FloatingText:reset()
	Particles:reset()
	Rocks:reset()
	Saws:reset()
	Lasers:reset()
	Darts:reset()
end

local function getCenterSpawnCell()
	local cols = Arena.cols or 1
	local rows = Arena.rows or 1
	if cols < 1 then cols = 1 end
	if rows < 1 then rows = 1 end

	local midCol = floor(cols / 2)
	local midRow = floor(rows / 2)
	return midCol, midRow
end

local function sawPlacementThreatensSpawn(col, row, dir)
	if not (col and row and dir) then
		return false
	end

	local midCol, midRow = getCenterSpawnCell()

	if dir == "horizontal" then
		if abs(col - midCol) <= 2 then
			return true
		end

		if abs(row - midRow) <= 1 then
			return true
		end
	else
		if abs(row - midRow) <= 2 then
			return true
		end
	end

	return false
end

local function addCellUnique(list, seen, col, row)
	if not (col and row) then
		return
	end

	col = floor(col + 0.5)
	row = floor(row + 0.5)

	if col < 1 or col > (Arena.cols or 1) or row < 1 or row > (Arena.rows or 1) then
		return
	end

	local key = col .. "," .. row
	if seen[key] then
		return
	end

	seen[key] = true
	list[#list + 1] = {col, row}
end

local function buildSpawnBuffer(baseSafeZone)
	local buffer = {}
	local seen = {}

	if baseSafeZone then
		for _, cell in ipairs(baseSafeZone) do
			addCellUnique(buffer, seen, cell[1], cell[2])
		end
	end

	local headCol, headRow = Snake:getHeadCell()
	local dir = Snake:getDirection() or {x = 0, y = 0}
	local dirX, dirY = dir.x or 0, dir.y or 0

	if dirX == 0 and dirY == 0 then
		dirX, dirY = 1, 0
	end

	if headCol and headRow then
		addCellUnique(buffer, seen, headCol, headRow)
		for i = 1, 5 do
			addCellUnique(buffer, seen, headCol + dirX * i, headRow + dirY * i)
		end
	else
		local midCol, midRow = getCenterSpawnCell()
		addCellUnique(buffer, seen, midCol, midRow)
		for i = 1, 5 do
			addCellUnique(buffer, seen, midCol + dirX * i, midRow + dirY * i)
		end
	end

	return buffer
end

local function prepareOccupancy()
	SnakeUtils.initOccupancy()

	for _, segment in ipairs(Snake:getSegments()) do
		local col, row = Arena:getTileFromWorld(segment.drawX, segment.drawY)
		SnakeUtils.setOccupied(col, row, true)
	end

	local safeZone = Snake:getSafeZone(3)
	local rockSafeZone = Snake:getSafeZone(5)
	local spawnBuffer = buildSpawnBuffer(rockSafeZone)
	local headCol, headRow = Snake:getHeadCell()
	local reservedCandidates = {}

	if headCol and headRow then
		for dx = -1, 1 do
			for dy = -1, 1 do
				reservedCandidates[#reservedCandidates + 1] = {headCol + dx, headRow + dy}
			end
		end
	end

	if safeZone then
		for _, cell in ipairs(safeZone) do
			reservedCandidates[#reservedCandidates + 1] = {cell[1], cell[2]}
		end
	end

	if rockSafeZone then
		for _, cell in ipairs(rockSafeZone) do
			reservedCandidates[#reservedCandidates + 1] = {cell[1], cell[2]}
		end
	end

	local reservedCells = SnakeUtils.reserveCells(reservedCandidates)
	local reservedSafeZone = SnakeUtils.reserveCells(safeZone)
	local reservedSpawnBuffer = SnakeUtils.reserveCells(spawnBuffer)

	return safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer
end

local function applyBaselineHazardTraits(traitContext)
	traitContext.laserCount = max(0, traitContext.laserCount or 0)
	traitContext.dartCount = max(0, traitContext.dartCount or 0)

	if traitContext.rockSpawnChance then
		Rocks.spawnChance = traitContext.rockSpawnChance
	end

	if traitContext.sawSpeedMult then
		Saws.speedMult = traitContext.sawSpeedMult
	end

	if traitContext.sawSpinMult then
		Saws.spinMult = traitContext.sawSpinMult
	end

	Saws:setStallOnFruit(traitContext.sawStall or 0)
end

local function finalizeTraitContext(traitContext, spawnPlan)
	traitContext.rockSpawnChance = Rocks:getSpawnChance()
	traitContext.sawSpeedMult = Saws.speedMult
	traitContext.sawSpinMult = Saws.spinMult

	traitContext.sawStall = Saws:getStallOnFruit()

	traitContext.laserCount = spawnPlan.laserCount or #(spawnPlan.lasers or {})
	traitContext.dartCount = spawnPlan.dartCount or #(spawnPlan.darts or {})
end

local function buildCellLookup(cells)
	if not cells or #cells == 0 then
		return nil
	end

	local lookup = {}
	for i = 1, #cells do
		local cell = cells[i]
		local col = floor((cell[1] or 0) + 0.5)
		local row = floor((cell[2] or 0) + 0.5)
		lookup[col .. "," .. row] = true
	end

	return lookup
end

local trackThreatCellBuffer = {}

local function trackThreatensSpawnBuffer(fx, fy, dir, spawnLookup)
	if not spawnLookup then
		return false
	end

	local cells = SnakeUtils.getSawTrackCells(fx, fy, dir, trackThreatCellBuffer)
	for i = 1, #cells do
		local cell = cells[i]
		if spawnLookup[cell[1] .. "," .. cell[2]] then
			return true
		end
	end

	return false
end

local function trySpawnHorizontalSaw(halfTiles, bladeRadius, spawnLookup, options)
	local row = love.math.random(2, Arena.rows - 1)
	local col = love.math.random(1 + halfTiles, Arena.cols - halfTiles)
	local fx, fy = Arena:getCenterOfTile(col, row)

	if sawPlacementThreatensSpawn(col, row, "horizontal") then
		return false
	end

	if trackThreatensSpawnBuffer(fx, fy, "horizontal", spawnLookup) then
		return false
	end

	if SnakeUtils.sawTrackIsFree(fx, fy, "horizontal") then
		Saws:spawn(fx, fy, bladeRadius, 8, "horizontal", nil, options)
		SnakeUtils.occupySawTrack(fx, fy, "horizontal")
		return true
	end

	return false
end

local function trySpawnVerticalSaw(halfTiles, bladeRadius, spawnLookup, options)
	local side = (love.math.random() < 0.5) and "left" or "right"
	local col = (side == "left") and 1 or Arena.cols
	local row = love.math.random(1 + halfTiles, Arena.rows - halfTiles)
	local fx, fy = Arena:getCenterOfTile(col, row)

	if sawPlacementThreatensSpawn(col, row, "vertical") then
		return false
	end

	if trackThreatensSpawnBuffer(fx, fy, "vertical", spawnLookup) then
		return false
	end

	if SnakeUtils.sawTrackIsFree(fx, fy, "vertical") then
		Saws:spawn(fx, fy, bladeRadius, 8, "vertical", side, options)
		SnakeUtils.occupySawTrack(fx, fy, "vertical")
		return true
	end

	return false
end

local function spawnSaws(numSaws, halfTiles, bladeRadius, spawnBuffer, options)
	local spawnLookup = buildCellLookup(spawnBuffer)
	options = options or {}
	local specialQueue = {}
	local defaultOptions = options.spawnWithSink and {spawnWithSink = true} or nil
	local function addSpecial(count, specialOptions)
		local amount = max(0, floor((count or 0) + 0.5))
		if amount <= 0 then
			return
		end

		if options.spawnWithSink and specialOptions then
			specialOptions.spawnWithSink = true
		end

		specialQueue[#specialQueue + 1] = {
			remaining = amount,
			options = specialOptions,
		}
	end

	addSpecial(options.emberCount, {
		color = options.emberColor or EMBER_SAW_COLOR,
		ember = true,
		emberTrailColor = options.emberTrailColor or EMBER_SAW_TRAIL_COLOR,
		emberGlowColor = options.emberGlowColor or EMBER_SAW_GLOW_COLOR,
	})

	local nextSpecialIndex = 1

	local function acquireSpecial()
		if #specialQueue == 0 then
			return nil, nil
		end

		for offset = 0, #specialQueue - 1 do
			local index = ((nextSpecialIndex + offset - 1) % #specialQueue) + 1
			local special = specialQueue[index]
			if special and special.remaining > 0 then
				return special, index
			end
		end

		return nil, nil
	end

	for _ = 1, numSaws do
		local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
		local placed = false
		local attempts = 0
		local maxAttempts = 60
		local activeSpecial, activeIndex = acquireSpecial()
		local sawOptions = activeSpecial and activeSpecial.options or defaultOptions

		while not placed and attempts < maxAttempts do
			attempts = attempts + 1

			if dir == "horizontal" then
				placed = trySpawnHorizontalSaw(halfTiles, bladeRadius, spawnLookup, sawOptions)
			else
				placed = trySpawnVerticalSaw(halfTiles, bladeRadius, spawnLookup, sawOptions)
			end
		end

		if placed and activeSpecial then
			activeSpecial.remaining = max(0, (activeSpecial.remaining or 0) - 1)
			nextSpecialIndex = ((activeIndex or 1) % max(#specialQueue, 1)) + 1
		elseif activeSpecial then
			nextSpecialIndex = ((activeIndex or 1) % max(#specialQueue, 1)) + 1
		end
	end
end

local function spawnLasers(laserPlan)
	if not (laserPlan and #laserPlan > 0) then
		return
	end

	for _, plan in ipairs(laserPlan) do
		Lasers:spawn(plan.x, plan.y, plan.dir, plan.options)
	end
end

local function spawnDarts(dartPlan)
	if not (dartPlan and #dartPlan > 0) then
		return
	end

	for _, plan in ipairs(dartPlan) do
		Darts:spawn(plan.x, plan.y, plan.dir, plan.options)
	end
end

local function spawnRocks(numRocks, safeZone)
	for _ = 1, numRocks do
		local fx, fy = SnakeUtils.getSafeSpawn(
			Snake:getSegments(),
			Fruit,
			Rocks,
			safeZone,
			{
			avoidFrontOfSnake = true,
			direction = Snake:getDirection(),
			frontBuffer = 5,
			}
		)
		if fx then
			Rocks:spawn(fx, fy, "small")
			local col, row = Arena:getTileFromWorld(fx, fy)
			SnakeUtils.setOccupied(col, row, true)
		end
	end
end

local function getAmbientLaserPreference(traitContext, floorData)
	if not floorData then
		return 0
	end

	local floorIndex = traitContext and traitContext.floor

	local function isMachineThemed()
		if floorData.backgroundTheme == "machine" then
			return true
		end

		if type(floorData.name) == "string" and floorData.name:lower():find("machin") then
			return true
		end

		return false
	end

	if isMachineThemed() then
		if floorIndex and floorIndex <= 5 then
			return 1
		end

		return 2
	end

	return 0
end

local function getDesiredLaserCount(traitContext, floorData)
	local baseline = 0

	if traitContext then
		baseline = max(0, floor((traitContext.laserCount or 0) + 0.5))
	end

	local ambient = getAmbientLaserPreference(traitContext, floorData)

	return max(baseline, ambient)
end

local function getDesiredDartCount(traitContext)
	if not traitContext then
		return 0
	end

	return max(0, floor((traitContext.dartCount or 0) + 0.5))
end

local function buildDartPlan(traitContext)
	local desired = getDesiredDartCount(traitContext)

	if desired <= 0 then
		return {}, 0
	end

	local plan = {}
	local attempts = desired * 30
	local totalCols = max(1, Arena.cols or 1)
	local totalRows = max(1, Arena.rows or 1)

	while #plan < desired and attempts > 0 do
		attempts = attempts - 1

		local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
		local facing = (love.math.random() < 0.5) and 1 or -1
		local col, row

		if dir == "horizontal" then
			col = (facing > 0) and 1 or totalCols
			local rowMin = 2
			local rowMax = totalRows - 1

			if rowMax < rowMin then
				local fallback = floor(totalRows / 2 + 0.5)
				rowMin = fallback
				rowMax = fallback
			end

			rowMin = max(1, min(totalRows, rowMin))
			rowMax = max(rowMin, min(totalRows, rowMax))
			row = love.math.random(rowMin, rowMax)
		else
			row = (facing > 0) and 1 or totalRows
			local colMin = 2
			local colMax = totalCols - 1

			if colMax < colMin then
				local fallback = floor(totalCols / 2 + 0.5)
				colMin = fallback
				colMax = fallback
			end

			colMin = max(1, min(totalCols, colMin))
			colMax = max(colMin, min(totalCols, colMax))
			col = love.math.random(colMin, colMax)
		end

		if col and row and not SnakeUtils.isOccupied(col, row) then
			local fx, fy = Arena:getCenterOfTile(col, row)
			local telegraphDuration = 0.8 + love.math.random() * 0.5
			local cooldownMin = 3.0 + love.math.random() * 1.6
			local cooldownMax = cooldownMin + 1.6 + love.math.random() * 1.4
			local dartSpeed = 320 + love.math.random() * 140

			plan[#plan + 1] = {
				x = fx,
				y = fy,
				dir = dir,
				options = {
					facing = facing,
					telegraphDuration = telegraphDuration,
					fireCooldownMin = cooldownMin,
					fireCooldownMax = cooldownMax,
					dartSpeed = dartSpeed,
				},
			}

			SnakeUtils.setOccupied(col, row, true)
		end
	end

	return plan, desired
end

local function buildLaserPlan(traitContext, halfTiles, trackLength, floorData)
	local desired = getDesiredLaserCount(traitContext, floorData)

	if desired <= 0 then
		return {}, 0
	end
	local plan = {}
	local attempts = 0
	local maxAttempts = desired * 40
	local totalCols = max(1, Arena.cols or 1)
	local totalRows = max(1, Arena.rows or 1)

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
				local fallback = floor(totalRows / 2 + 0.5)
				rowMin = fallback
				rowMax = fallback
			end

			rowMin = max(1, min(totalRows, rowMin))
			rowMax = max(rowMin, min(totalRows, rowMax))
			row = love.math.random(rowMin, rowMax)
		else
			facing = (love.math.random() < 0.5) and 1 or -1
			row = (facing > 0) and 1 or totalRows
			local colMin = 2
			local colMax = totalCols - 1

			if colMax < colMin then
				local fallback = floor(totalCols / 2 + 0.5)
				colMin = fallback
				colMax = fallback
			end

			colMin = max(1, min(totalCols, colMin))
			colMax = max(colMin, min(totalCols, colMax))
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

local function mergeCells(primary, secondary)
	if not primary or #primary == 0 then
		return secondary
	end

	if not secondary or #secondary == 0 then
		return primary
	end

	local merged = {}
	local seen = {}

	for _, cell in ipairs(primary) do
		addCellUnique(merged, seen, cell[1], cell[2])
	end

	for _, cell in ipairs(secondary) do
		addCellUnique(merged, seen, cell[1], cell[2])
	end

	return merged
end

local function buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, floorData)
	local halfTiles = floor((TRACK_LENGTH / Arena.tileSize) / 2)
	local laserPlan, desiredLasers = buildLaserPlan(traitContext, halfTiles, TRACK_LENGTH, floorData)
	local dartPlan, desiredDarts = buildDartPlan(traitContext)
	local spawnSafeCells = mergeCells(rockSafeZone, spawnBuffer)

	local emberSaws = max(0, floor((traitContext.contractOfCindersEmberSaws or 0) + 0.5))
	traitContext.contractOfCindersEmberSaws = emberSaws

	return {
		numRocks = traitContext.rocks,
		numSaws = traitContext.saws,
		halfTiles = halfTiles,
		bladeRadius = DEFAULT_SAW_RADIUS,
		safeZone = safeZone,
		reservedCells = reservedCells,
		reservedSafeZone = reservedSafeZone,
		rockSafeZone = rockSafeZone,
		spawnBuffer = spawnBuffer,
		reservedSpawnBuffer = reservedSpawnBuffer,
		spawnSafeCells = spawnSafeCells,
		lasers = laserPlan,
		laserCount = desiredLasers,
		darts = dartPlan,
		dartCount = desiredDarts,
		emberSawCount = emberSaws,
	}
end

function FloorSetup.prepare(floorNum, floorData)
	applyPalette(floorData and floorData.palette)
	resetFloorEntities()
	Arena:setFloorDecorations(floorNum, floorData)
	local safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer = prepareOccupancy()

	local traitContext = FloorPlan.buildBaselineFloorContext(floorNum)
	applyBaselineHazardTraits(traitContext)

	traitContext = Upgrades:modifyFloorContext(traitContext)
	traitContext.laserCount = max(0, traitContext.laserCount or 0)

	local cap = FloorPlan.getLaserCap and FloorPlan.getLaserCap(traitContext.floor)
	if cap and traitContext.laserCount ~= nil then
		traitContext.laserCount = min(cap, traitContext.laserCount)
	end

	local spawnPlan = buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, floorData)

	Arena:setSpawnDebugData({
		safeZone = safeZone,
		rockSafeZone = rockSafeZone,
		spawnBuffer = spawnBuffer,
		spawnSafeCells = spawnPlan and spawnPlan.spawnSafeCells,
		reservedCells = reservedCells,
		reservedSafeZone = reservedSafeZone,
		reservedSpawnBuffer = reservedSpawnBuffer,
	})

	return {
		traitContext = traitContext,
		spawnPlan = spawnPlan,
	}
end

function FloorSetup.finalizeContext(traitContext, spawnPlan)
	finalizeTraitContext(traitContext, spawnPlan)
end

function FloorSetup.spawnHazards(spawnPlan)
	local emberSawCount = 0
	if spawnPlan then
		emberSawCount = spawnPlan.emberSawCount or 0
	end

	spawnSaws(
		spawnPlan.numSaws or 0,
		spawnPlan.halfTiles,
		spawnPlan.bladeRadius,
		spawnPlan.spawnSafeCells,
		{
		emberCount = emberSawCount,
		emberColor = EMBER_SAW_COLOR,
		emberTrailColor = EMBER_SAW_TRAIL_COLOR,
		emberGlowColor = EMBER_SAW_GLOW_COLOR,
		spawnWithSink = true,
		}
	)
	spawnLasers(spawnPlan.lasers or {})
	spawnDarts(spawnPlan.darts or {})
	spawnRocks(spawnPlan.numRocks or 0, spawnPlan.spawnSafeCells or spawnPlan.rockSafeZone or spawnPlan.safeZone)
	Fruit:spawn(Snake:getSegments(), Rocks, spawnPlan.safeZone)
	SnakeUtils.releaseCells(spawnPlan.reservedSafeZone)
	SnakeUtils.releaseCells(spawnPlan.reservedSpawnBuffer)
	SnakeUtils.releaseCells(spawnPlan.reservedCells)
end

return FloorSetup
