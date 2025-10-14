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
local ArenaLayout = require("arenalayout")

local FloorSetup = {}

local computeSpawnContext

local TRACK_LENGTH = 120
local DEFAULT_SAW_RADIUS = 16
local LAYOUT_VALIDATION_MAX_ATTEMPTS = 8
local LAYOUT_VALIDATION_RELAX_AFTER = 5

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
        if Arena.setLayout then
                Arena:setLayout(nil)
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

	local midCol = math.floor(cols / 2)
	local midRow = math.floor(rows / 2)
	return midCol, midRow
end

local function sawPlacementThreatensSpawn(col, row, dir)
	if not (col and row and dir) then
		return false
	end

	local midCol, midRow = getCenterSpawnCell()

	if dir == "horizontal" then
		if math.abs(col - midCol) <= 2 then
			return true
		end

		if math.abs(row - midRow) <= 1 then
			return true
		end
	else
		if math.abs(row - midRow) <= 2 then
			return true
		end
	end

	return false
end

local function addCellUnique(list, seen, col, row)
	if not (col and row) then
		return
	end

	col = math.floor(col + 0.5)
	row = math.floor(row + 0.5)

	if col < 1 or col > (Arena.cols or 1) or row < 1 or row > (Arena.rows or 1) then
		return
	end

	local key = col .. "," .. row
	if seen[key] then
		return
	end

	seen[key] = true
	list[#list + 1] = { col, row }
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
	local dir = Snake:getDirection() or { x = 0, y = 0 }
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
        for _, segment in ipairs(Snake:getSegments()) do
                local col, row = Arena:getTileFromWorld(segment.drawX, segment.drawY)
                SnakeUtils.setOccupied(col, row, true)
        end

        local spawnContext = computeSpawnContext()
        local safeZone = spawnContext.safeZone
        local rockSafeZone = spawnContext.rockSafeZone
        local spawnBuffer = spawnContext.spawnBuffer

        local reservedCells = SnakeUtils.reserveCells(spawnContext.reservedCandidates)
        local reservedSafeZone = SnakeUtils.reserveCells(safeZone)
        local reservedSpawnBuffer = SnakeUtils.reserveCells(spawnBuffer)

        return safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, spawnContext
end

local function applyBaselineHazardTraits(traitContext)
	traitContext.laserCount = math.max(0, traitContext.laserCount or 0)
	traitContext.dartCount = math.max(0, traitContext.dartCount or 0)

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

	traitContext.laserCount = spawnPlan.laserCount or #(spawnPlan.lasers or {})
	traitContext.dartCount = spawnPlan.dartCount or #(spawnPlan.darts or {})
end

local function buildCellLookup(cells)
        if not cells or #cells == 0 then
                return nil
        end

        local lookup = {}
        for _, cell in ipairs(cells) do
                local col = math.floor((cell[1] or 0) + 0.5)
                local row = math.floor((cell[2] or 0) + 0.5)
                lookup[col .. "," .. row] = true
        end

        return lookup
end

local function countLookupEntries(lookup)
        if not lookup then
                return 0
        end

        local count = 0
        for _ in pairs(lookup) do
                count = count + 1
        end

        return count
end

local function normalizeCells(cells)
        if not cells or #cells == 0 then
                return {}, {}
        end

        local list = {}
        local lookup = {}
        local cols = math.max(0, Arena.cols or 0)
        local rows = math.max(0, Arena.rows or 0)

        for _, cell in ipairs(cells) do
                local col = math.floor((cell[1] or 0) + 0.5)
                local row = math.floor((cell[2] or 0) + 0.5)
                if col >= 1 and col <= cols and row >= 1 and row <= rows then
                        local key = col .. "," .. row
                        if not lookup[key] then
                                lookup[key] = true
                                list[#list + 1] = {col, row}
                        end
                end
        end

        return list, lookup
end

local function buildFruitCandidateLookup(walkableLookup, spawnLookup)
        if not walkableLookup then
                return nil, 0
        end

        local lookup = {}
        local count = 0

        for key in pairs(walkableLookup) do
                if not (spawnLookup and spawnLookup[key]) then
                        lookup[key] = true
                        count = count + 1
                end
        end

        return lookup, count
end

local function buildExitCandidateLookup(walkableLookup, spawnLookup, blockedLookup)
        local cols = math.max(0, Arena.cols or 0)
        local rows = math.max(0, Arena.rows or 0)

        if cols <= 0 or rows <= 0 then
                return nil, 0
        end

        local lookup = {}
        local count = 0

        for row = 2, rows - 1 do
                for col = 2, cols - 1 do
                        local key = col .. "," .. row
                        if not (blockedLookup and blockedLookup[key]) then
                        if (not walkableLookup or walkableLookup[key]) and (not spawnLookup or not spawnLookup[key]) then
                                if not lookup[key] then
                                        lookup[key] = true
                                        count = count + 1
                                end
                        end
                        end
                end
        end

        return lookup, count
end

local function trackThreatensSpawnBuffer(fx, fy, dir, spawnLookup)
        if not spawnLookup then
                return false
        end

        local cells = SnakeUtils.getSawTrackCells(fx, fy, dir)
        for _, cell in ipairs(cells) do
                if spawnLookup[cell[1] .. "," .. cell[2]] then
                        return true
                end
        end

        return false
end

local function trackHitsBlocked(fx, fy, dir, blockedLookup)
        if not blockedLookup then
                return false
        end

        local cells = SnakeUtils.getSawTrackCells(fx, fy, dir)
        for _, cell in ipairs(cells) do
                if blockedLookup[cell[1] .. "," .. cell[2]] then
                        return true
                end
        end

        return false
end

function computeSpawnContext()
        local safeZone = Snake:getSafeZone(3)
        local rockSafeZone = Snake:getSafeZone(5)
        local spawnBuffer = buildSpawnBuffer(rockSafeZone)
        local reservedCandidates = {}

        local headCol, headRow = Snake:getHeadCell()
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

        if rockSafeZone then
                for _, cell in ipairs(rockSafeZone) do
                        reservedCandidates[#reservedCandidates + 1] = { cell[1], cell[2] }
                end
        end

        return {
                safeZone = safeZone,
                rockSafeZone = rockSafeZone,
                spawnBuffer = spawnBuffer,
                reservedCandidates = reservedCandidates,
        }
end

local function validateLayoutConnectivity(layout, spawnContext, options)
        options = options or {}

        local requireFruit = options.requireFruit ~= false
        local requireExit = options.requireExit ~= false

        local blockedLookup = layout and layout.blockedLookup or nil
        if not blockedLookup and layout and layout.blocked then
                local _, built = normalizeCells(layout.blocked)
                blockedLookup = built
        end

        local spawnList, spawnLookup = normalizeCells(spawnContext and spawnContext.spawnBuffer)
        local totalSpawn = #spawnList

        local queue = {}
        local visited = {}

        for _, cell in ipairs(spawnList) do
                local key = cell[1] .. "," .. cell[2]
                if not (blockedLookup and blockedLookup[key]) then
                        visited[key] = true
                        queue[#queue + 1] = {cell[1], cell[2]}
                end
        end

        local metrics = {
                requireFruit = requireFruit,
                requireExit = requireExit,
                totalSpawn = totalSpawn,
                startCells = #queue,
                blockedCells = countLookupEntries(blockedLookup),
        }

        local walkableLookup = layout and layout.walkableLookup or nil
        if not walkableLookup and layout and layout.walkable then
                local _, built = normalizeCells(layout.walkable)
                walkableLookup = built
        end

        local cols = math.max(0, Arena.cols or 0)
        local rows = math.max(0, Arena.rows or 0)
        local totalWalkable
        if walkableLookup then
                totalWalkable = countLookupEntries(walkableLookup)
        else
                totalWalkable = math.max(0, cols * rows - metrics.blockedCells)
        end

        local fruitLookup, totalFruit = buildFruitCandidateLookup(walkableLookup, spawnLookup)
        local exitLookup, totalExit = buildExitCandidateLookup(walkableLookup, spawnLookup, blockedLookup)

        metrics.totalWalkable = totalWalkable
        metrics.totalFruit = totalFruit
        metrics.totalExit = totalExit

        if #queue == 0 then
                metrics.visited = 0
                metrics.reachableWalkable = 0
                metrics.reachableFruit = 0
                metrics.reachableExit = 0
                local success = (not requireFruit) and (not requireExit)
                metrics.success = success
                if not success then
                        metrics.reason = "spawn_blocked"
                end
                return metrics
        end

        local head = 1
        local visitedCount = 0
        local reachableWalkable = 0
        local reachableFruit = 0
        local reachableExit = 0

        local function tryVisit(col, row)
                if col < 1 or row < 1 or col > cols or row > rows then
                        return
                end

                local key = col .. "," .. row
                if blockedLookup and blockedLookup[key] then
                        return
                end

                if not visited[key] then
                        visited[key] = true
                        queue[#queue + 1] = {col, row}
                end
        end

        while head <= #queue do
                local cell = queue[head]
                head = head + 1
                visitedCount = visitedCount + 1

                local key = cell[1] .. "," .. cell[2]

                if walkableLookup then
                        if walkableLookup[key] then
                                reachableWalkable = reachableWalkable + 1
                        end
                else
                        reachableWalkable = reachableWalkable + 1
                end

                if fruitLookup and fruitLookup[key] then
                        reachableFruit = reachableFruit + 1
                end

                if exitLookup and exitLookup[key] then
                        reachableExit = reachableExit + 1
                end

                tryVisit(cell[1] + 1, cell[2])
                tryVisit(cell[1] - 1, cell[2])
                tryVisit(cell[1], cell[2] + 1)
                tryVisit(cell[1], cell[2] - 1)
        end

        metrics.visited = visitedCount
        metrics.reachableWalkable = reachableWalkable
        metrics.reachableFruit = reachableFruit
        metrics.reachableExit = reachableExit

        local fruitOk = (not requireFruit) or (totalFruit == 0) or (reachableFruit > 0)
        local exitOk = (not requireExit) or (totalExit == 0) or (reachableExit > 0)

        metrics.success = fruitOk and exitOk
        if not metrics.success then
                if not fruitOk then
                        metrics.reason = "fruit_unreachable"
                elseif not exitOk then
                        metrics.reason = "exit_unreachable"
                else
                        metrics.reason = "unknown"
                end
        end

        return metrics
end

local function trySpawnHorizontalSaw(halfTiles, bladeRadius, spawnLookup, blockedLookup)
        local row = love.math.random(2, Arena.rows - 1)
        local col = love.math.random(1 + halfTiles, Arena.cols - halfTiles)
        local fx, fy = Arena:getCenterOfTile(col, row)

        if sawPlacementThreatensSpawn(col, row, "horizontal") then
                return false
        end

        if trackThreatensSpawnBuffer(fx, fy, "horizontal", spawnLookup) then
                return false
        end

        if trackHitsBlocked(fx, fy, "horizontal", blockedLookup) then
                return false
        end

        if SnakeUtils.sawTrackIsFree(fx, fy, "horizontal") then
                Saws:spawn(fx, fy, bladeRadius, 8, "horizontal")
                SnakeUtils.occupySawTrack(fx, fy, "horizontal")
                return true
        end

        return false
end

local function trySpawnVerticalSaw(halfTiles, bladeRadius, spawnLookup, blockedLookup)
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

        if trackHitsBlocked(fx, fy, "vertical", blockedLookup) then
                return false
        end

        if SnakeUtils.sawTrackIsFree(fx, fy, "vertical") then
                Saws:spawn(fx, fy, bladeRadius, 8, "vertical", side)
                SnakeUtils.occupySawTrack(fx, fy, "vertical")
                return true
        end

        return false
end

local function spawnSaws(numSaws, halfTiles, bladeRadius, spawnBuffer, layout)
        local spawnLookup = buildCellLookup(spawnBuffer)
        local blockedLookup = layout and layout.blockedLookup

        for _ = 1, numSaws do
                local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
                local placed = false
                local attempts = 0
                local maxAttempts = 60

                while not placed and attempts < maxAttempts do
                        attempts = attempts + 1

                        if dir == "horizontal" then
                                placed = trySpawnHorizontalSaw(halfTiles, bladeRadius, spawnLookup, blockedLookup)
                        else
                                placed = trySpawnVerticalSaw(halfTiles, bladeRadius, spawnLookup, blockedLookup)
                        end
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

local function spawnRocks(numRocks, safeZone, layout)
        local blockedLookup = layout and layout.blockedLookup

        for _ = 1, numRocks do
                local attempts = 0
                local maxAttempts = 8
                local placed = false

                while not placed and attempts < maxAttempts do
                        attempts = attempts + 1
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

                        if not fx then
                                break
                        end

                        local col, row = Arena:getTileFromWorld(fx, fy)
                        local key = col .. "," .. row
                        if blockedLookup and blockedLookup[key] then
                                -- try again with a different sample
                        else
                                Rocks:spawn(fx, fy, "small")
                                SnakeUtils.setOccupied(col, row, true)
                                placed = true
                        end
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
		baseline = math.max(0, math.floor((traitContext.laserCount or 0) + 0.5))
	end

	local ambient = getAmbientLaserPreference(traitContext, floorData)

	return math.max(baseline, ambient)
end

local function buildLaserPlan(traitContext, halfTiles, trackLength, floorData, layout)
        local desired = getDesiredLaserCount(traitContext, floorData)

        if desired <= 0 then
                return {}, 0
        end
	local plan = {}
	local attempts = 0
	local maxAttempts = desired * 40
        local totalCols = math.max(1, Arena.cols or 1)
        local totalRows = math.max(1, Arena.rows or 1)
        local blockedLookup = layout and layout.blockedLookup

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

                if col and row then
                        local key = col .. "," .. row
                        local blocked = blockedLookup and blockedLookup[key]
                        if not blocked and not SnakeUtils.isOccupied(col, row) then
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
        end

        return plan, desired
end

local function getDesiredDartCount(traitContext)
	if not traitContext then
		return 0
	end

	return math.max(0, math.floor((traitContext.dartCount or 0) + 0.5))
end

local function buildDartPlan(traitContext, layout)
        local desired = getDesiredDartCount(traitContext)

        if desired <= 0 then
                return {}, 0
        end

        local plan = {}
        local attempts = 0
        local maxAttempts = desired * 40
        local totalCols = math.max(1, Arena.cols or 1)
        local totalRows = math.max(1, Arena.rows or 1)
        local blockedLookup = layout and layout.blockedLookup

        while #plan < desired and attempts < maxAttempts do
                attempts = attempts + 1
                local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
                local facing = (love.math.random() < 0.5) and 1 or -1
		local col, row

		if dir == "horizontal" then
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

                if col and row then
                        local key = col .. "," .. row
                        local blocked = blockedLookup and blockedLookup[key]
                        if not blocked and not SnakeUtils.isOccupied(col, row) then
                                local fx, fy = Arena:getCenterOfTile(col, row)
                                local telegraph = 0.7 + love.math.random() * 0.3
                                local cooldownMin = 3.0 + love.math.random() * 1.4
                                local cooldownMax = cooldownMin + 1.8 + love.math.random() * 1.6
                                local fireSpeed = 420 + love.math.random() * 120

                                plan[#plan + 1] = {
                                        x = fx,
                                        y = fy,
                                        dir = dir,
                                        options = {
                                                facing = facing,
                                                telegraphDuration = telegraph,
                                                cooldownMin = cooldownMin,
                                                cooldownMax = cooldownMax,
                                                fireSpeed = fireSpeed,
                                        },
                                }

                                SnakeUtils.setOccupied(col, row, true)
                        end
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

local function buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, floorData, layout)
        local halfTiles = math.floor((TRACK_LENGTH / Arena.tileSize) / 2)
        local laserPlan, desiredLasers = buildLaserPlan(traitContext, halfTiles, TRACK_LENGTH, floorData, layout)
        local dartPlan, desiredDarts = buildDartPlan(traitContext, layout)
        local spawnSafeCells = mergeCells(rockSafeZone, spawnBuffer)

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
                layout = layout,
        }
end

function FloorSetup.prepare(floorNum, floorData)
        applyPalette(floorData and floorData.palette)
        Arena:setBackgroundEffect(floorData and floorData.backgroundEffect, floorData and floorData.palette)
        resetFloorEntities()

        local chosenLayout = nil
        local chosenValidation = nil
        local attempts = 0
        local lastLayout = nil
        local lastValidation = nil
        local relaxThreshold = math.max(1, math.min(LAYOUT_VALIDATION_RELAX_AFTER, LAYOUT_VALIDATION_MAX_ATTEMPTS))

        while attempts < LAYOUT_VALIDATION_MAX_ATTEMPTS do
                attempts = attempts + 1
                SnakeUtils.initOccupancy()

                local layout = ArenaLayout.generate(floorNum, floorData, attempts - 1)
                lastLayout = layout

                if layout and layout.blocked then
                        for _, cell in ipairs(layout.blocked) do
                                SnakeUtils.setOccupied(cell[1], cell[2], true)
                        end
                end

                local spawnContext = computeSpawnContext()
                local requireExit = attempts <= relaxThreshold
                local validation = validateLayoutConnectivity(layout, spawnContext, {
                        requireFruit = true,
                        requireExit = requireExit,
                })
                validation.attempt = attempts
                validation.attempts = attempts
                validation.maxAttempts = LAYOUT_VALIDATION_MAX_ATTEMPTS
                validation.relaxed = not requireExit
                validation.requireExit = requireExit
                validation.requireFruit = true
                validation.seedOffset = layout and layout.seedOffset
                validation.rngSeed = layout and layout.rngSeed
                validation.baseSeed = layout and layout.seed
                lastValidation = validation

                if validation.success then
                        chosenLayout = layout
                        chosenValidation = validation
                        break
                else
                        local mode = requireExit and "strict" or "relaxed"
                        local reason = validation.reason or "unknown"
                        print(string.format("[FloorSetup] Layout validation failed on attempt %d (%s, %s)", attempts, reason, mode))
                end
        end

        if not chosenLayout then
                chosenLayout = lastLayout
                if lastValidation then
                        chosenValidation = lastValidation
                        chosenValidation.forced = true
                end
        end

        if chosenValidation then
                chosenValidation.attempts = chosenValidation.attempt or attempts
                if chosenValidation.success then
                        if (chosenValidation.attempt or attempts) > 1 then
                                local note = chosenValidation.relaxed and " with relaxed exit requirement" or ""
                                print(string.format("[FloorSetup] Layout validation succeeded after %d attempts%s.", chosenValidation.attempt or attempts, note))
                        end
                else
                        print(string.format("[FloorSetup] Using layout after validation failure (reason=%s)", chosenValidation.reason or "unknown"))
                end
        end

        SnakeUtils.initOccupancy()
        if chosenLayout and chosenLayout.blocked then
                for _, cell in ipairs(chosenLayout.blocked) do
                        SnakeUtils.setOccupied(cell[1], cell[2], true)
                end
        end

        if Arena.setLayout then
                Arena:setLayout(chosenLayout)
        end

        local safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, spawnContext = prepareOccupancy()

        local traitContext = FloorPlan.buildBaselineFloorContext(floorNum)
        applyBaselineHazardTraits(traitContext)

        traitContext = Upgrades:modifyFloorContext(traitContext)
        traitContext.laserCount = math.max(0, traitContext.laserCount or 0)
        traitContext.dartCount = math.max(0, traitContext.dartCount or 0)

        local cap = FloorPlan.getLaserCap and FloorPlan.getLaserCap(traitContext.floor)
        if cap and traitContext.laserCount ~= nil then
                traitContext.laserCount = math.min(cap, traitContext.laserCount)
        end

        local dartCap = FloorPlan.getDartCap and FloorPlan.getDartCap(traitContext.floor)
        if dartCap and traitContext.dartCount ~= nil then
                traitContext.dartCount = math.min(dartCap, traitContext.dartCount)
        end

        local spawnPlan = buildSpawnPlan(traitContext, safeZone, reservedCells, reservedSafeZone, rockSafeZone, spawnBuffer, reservedSpawnBuffer, floorData, chosenLayout)

        local finalValidation = nil
        if chosenLayout then
                finalValidation = validateLayoutConnectivity(chosenLayout, spawnContext, {
                        requireFruit = chosenValidation and chosenValidation.requireFruit ~= false,
                        requireExit = chosenValidation and chosenValidation.requireExit ~= false,
                })
                finalValidation.attempt = chosenValidation and chosenValidation.attempt or attempts
                finalValidation.attempts = chosenValidation and chosenValidation.attempts or attempts
                finalValidation.maxAttempts = LAYOUT_VALIDATION_MAX_ATTEMPTS
                finalValidation.relaxed = chosenValidation and chosenValidation.relaxed or finalValidation.relaxed
                finalValidation.requireExit = chosenValidation and chosenValidation.requireExit
                finalValidation.requireFruit = chosenValidation and chosenValidation.requireFruit
                finalValidation.forced = chosenValidation and chosenValidation.forced
                finalValidation.seedOffset = chosenLayout and chosenLayout.seedOffset
                finalValidation.rngSeed = chosenLayout and chosenLayout.rngSeed
                finalValidation.baseSeed = chosenLayout and chosenLayout.seed
                if chosenValidation and not chosenValidation.success then
                        finalValidation.success = false
                        finalValidation.reason = chosenValidation.reason or finalValidation.reason
                end
        end

        if not finalValidation then
                finalValidation = chosenValidation
        end

        if Arena.setSpawnDebugData then
                Arena:setSpawnDebugData({
                        safeZone = safeZone,
                        rockSafeZone = rockSafeZone,
                        spawnBuffer = spawnBuffer,
                        spawnSafeCells = spawnPlan and spawnPlan.spawnSafeCells,
                        reservedCells = reservedCells,
                        reservedSafeZone = reservedSafeZone,
                        reservedSpawnBuffer = reservedSpawnBuffer,
                        layout = chosenLayout,
                        layoutValidation = finalValidation,
                })
        end

        return {
                traitContext = traitContext,
                spawnPlan = spawnPlan,
                layout = chosenLayout,
                layoutValidation = finalValidation,
        }
end

function FloorSetup.finalizeContext(traitContext, spawnPlan)
	finalizeTraitContext(traitContext, spawnPlan)
end

function FloorSetup.spawnHazards(spawnPlan)
        if Arena.setLayout and spawnPlan.layout then
                Arena:setLayout(spawnPlan.layout)
        end
        spawnSaws(spawnPlan.numSaws or 0, spawnPlan.halfTiles, spawnPlan.bladeRadius, spawnPlan.spawnSafeCells, spawnPlan.layout)
        spawnLasers(spawnPlan.lasers or {})
        spawnDarts(spawnPlan.darts or {})
        spawnRocks(spawnPlan.numRocks or 0, spawnPlan.spawnSafeCells or spawnPlan.rockSafeZone or spawnPlan.safeZone, spawnPlan.layout)
        Fruit:spawn(Snake:getSegments(), Rocks, spawnPlan.safeZone)
        SnakeUtils.releaseCells(spawnPlan.reservedSafeZone)
        SnakeUtils.releaseCells(spawnPlan.reservedSpawnBuffer)
        SnakeUtils.releaseCells(spawnPlan.reservedCells)
end

return FloorSetup
