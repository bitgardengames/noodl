local Arena = require("arena")
local SnakeUtils = require("snakeutils")

local floor = math.floor
local min = math.min
local max = math.max

local SnakeOccupancy = {}

local TILE_COORD_EPSILON = 1e-9
SnakeOccupancy.TILE_COORD_EPSILON = TILE_COORD_EPSILON

local SEGMENT_CANDIDATE_GENERATION_RESET = 10000000
local RECENTLY_VACATED_GENERATION_RESET = 10000000

local cellKeyStride = 0

local recentlyVacatedCells = {}
local recentlyVacatedLookup = {}
local recentlyVacatedCount = 0
local recentlyVacatedGeneration = 0

local snakeOccupiedCells = {}
local snakeOccupiedFirst = 1
local snakeOccupiedLast = 0
local occupancyCols = 0
local occupancyRows = 0
local snakeBodyOccupancyMaxIndex = 0
local snakeBodyOccupancy = {}
local snakeBodySpatialIndexMaxIndex = 0
local snakeBodySpatialIndex = {}
local snakeBodySpatialIndexAvailable = false

local segmentCandidateBuffer = {}
local segmentCandidateLookup = {}
local segmentCandidateCount = 0
local segmentCandidateGeneration = 0

local toCellFn = nil

function SnakeOccupancy.setToCell(stateOrFn, maybeFn)
        if type(stateOrFn) == "table" then
                stateOrFn.toCell = maybeFn
                toCellFn = maybeFn
                return
        end

        toCellFn = stateOrFn
end

local function getCellLookupKey(col, row)
	if not (col and row) then
		return nil
	end

	local stride = cellKeyStride
	if stride <= 0 then
		stride = (Arena and Arena.rows or 0) + 16
		if stride <= 0 then
			stride = 64
		end
		cellKeyStride = stride
	end

	return col * stride + row
end

function SnakeOccupancy.clearRecentlyVacatedCells()
	recentlyVacatedCount = 0
	recentlyVacatedGeneration = recentlyVacatedGeneration + 1
	if recentlyVacatedGeneration >= RECENTLY_VACATED_GENERATION_RESET then
		recentlyVacatedGeneration = 1
		recentlyVacatedLookup = {}
	end
end

function SnakeOccupancy.markRecentlyVacatedCell(col, row)
	if not (col and row) then
		return
	end

	if recentlyVacatedGeneration == 0 then
		recentlyVacatedGeneration = 1
	end

	local index = recentlyVacatedCount + 1
	local cell = recentlyVacatedCells[index]
	if cell then
		cell[1] = col
		cell[2] = row
	else
		cell = {col, row}
		recentlyVacatedCells[index] = cell
	end

	local key = getCellLookupKey(col, row)
	if key then
		recentlyVacatedLookup[key] = recentlyVacatedGeneration
	end

	recentlyVacatedCount = index
end

function SnakeOccupancy.wasRecentlyVacated(col, row)
	if recentlyVacatedGeneration == 0 or not (col and row) then
		return false
	end

	local key = getCellLookupKey(col, row)
	if not key then
		return false
	end

	return recentlyVacatedLookup[key] == recentlyVacatedGeneration
end

local function clearArrayRange(t, length)
        for i = 1, length do
                t[i] = nil
        end
end

local function clearArray(t)
        clearArrayRange(t, #t)
end

local function getGridIndex(col, row)
        if not (col and row) then
                return nil
        end

        if occupancyRows <= 0 or col < 1 or row < 1 or row > occupancyRows then
                return nil
        end

        return (col - 1) * occupancyRows + row
end

local function hasSpatialEntries()
        local limit = max(snakeBodySpatialIndexMaxIndex, occupancyCols * occupancyRows)
        for i = 1, limit do
                if snakeBodySpatialIndex[i] then
                        return true
                end
        end

        return false
end

function SnakeOccupancy.clearSnakeBodySpatialIndex()
        local limit = max(snakeBodySpatialIndexMaxIndex, occupancyCols * occupancyRows)
        for i = 1, limit do
                local bucket = snakeBodySpatialIndex[i]
                if bucket then
                        clearArray(bucket)
                        snakeBodySpatialIndex[i] = nil
                end
        end

        snakeBodySpatialIndexMaxIndex = 0
        snakeBodySpatialIndexAvailable = false
end

function SnakeOccupancy.clearSnakeBodyOccupancy()
        local limit = max(snakeBodyOccupancyMaxIndex, occupancyCols * occupancyRows)
        clearArrayRange(snakeBodyOccupancy, limit)

        snakeBodyOccupancyMaxIndex = 0
        SnakeOccupancy.clearRecentlyVacatedCells()
        SnakeOccupancy.clearSnakeBodySpatialIndex()
end

function SnakeOccupancy.resetTrackedSnakeCells()
	if snakeOccupiedFirst > snakeOccupiedLast then
		snakeOccupiedFirst = 1
		snakeOccupiedLast = 0
		return
	end

	for i = snakeOccupiedFirst, snakeOccupiedLast do
		local cell = snakeOccupiedCells[i]
		if cell then
			cell[1] = nil
			cell[2] = nil
			snakeOccupiedCells[i] = nil
		end
	end

	snakeOccupiedFirst = 1
	snakeOccupiedLast = 0
end

function SnakeOccupancy.clearSnakeOccupiedCells()
	if snakeOccupiedFirst > snakeOccupiedLast then
		return
	end

	for i = snakeOccupiedFirst, snakeOccupiedLast do
		local cell = snakeOccupiedCells[i]
		if cell then
			local col, row = cell[1], cell[2]
			if col and row then
				SnakeUtils.setOccupied(col, row, false)
			end
			cell[1] = nil
			cell[2] = nil
			snakeOccupiedCells[i] = nil
		end
	end

	snakeOccupiedFirst = 1
	snakeOccupiedLast = 0
end

function SnakeOccupancy.recordSnakeOccupiedCell(col, row)
	if not (col and row) then
		return
	end

	local index = snakeOccupiedLast + 1
	local wasEmpty = snakeOccupiedFirst > snakeOccupiedLast
	local cell = snakeOccupiedCells[index]
	if cell then
		cell[1] = col
		cell[2] = row
	else
		cell = {col, row}
		snakeOccupiedCells[index] = cell
	end

	snakeOccupiedLast = index
	if wasEmpty then
		snakeOccupiedFirst = index
	end

	SnakeUtils.setOccupied(col, row, true)
end

function SnakeOccupancy.getSnakeTailCell()
	if snakeOccupiedFirst > snakeOccupiedLast then
		return nil, nil
	end

	local cell = snakeOccupiedCells[snakeOccupiedFirst]
	if not cell then
		return nil, nil
	end

	return cell[1], cell[2]
end

function SnakeOccupancy.popSnakeTailCell()
	if snakeOccupiedFirst > snakeOccupiedLast then
		return nil, nil
	end

	local cell = snakeOccupiedCells[snakeOccupiedFirst]
	local col, row = nil, nil
	if cell then
		col, row = cell[1], cell[2]
		cell[1] = nil
		cell[2] = nil
	end

	snakeOccupiedFirst = snakeOccupiedFirst + 1
	if snakeOccupiedFirst > snakeOccupiedLast then
		snakeOccupiedFirst = 1
		snakeOccupiedLast = 0
	end

	return col, row
end

function SnakeOccupancy.getSnakeHeadCell()
	if snakeOccupiedFirst > snakeOccupiedLast then
		return nil, nil
	end

	local cell = snakeOccupiedCells[snakeOccupiedLast]
	if not cell then
		return nil, nil
	end

	return cell[1], cell[2]
end

function SnakeOccupancy.resetSnakeOccupancyGrid()
        occupancyCols = (Arena and Arena.cols) or 0
        occupancyRows = (Arena and Arena.rows) or 0
        cellKeyStride = 0

        if SnakeUtils and SnakeUtils.initOccupancy then
                SnakeUtils.initOccupancy()
        end

        SnakeOccupancy.resetTrackedSnakeCells()
        SnakeOccupancy.clearSnakeBodyOccupancy()
end

function SnakeOccupancy.ensureOccupancyGrid()
	local cols = (Arena and Arena.cols) or 0
	local rows = (Arena and Arena.rows) or 0
	if cols <= 0 or rows <= 0 then
		return false, false
	end

	local reset = false
	if cols ~= occupancyCols or rows ~= occupancyRows then
		SnakeOccupancy.resetSnakeOccupancyGrid()
		reset = true
	elseif not SnakeUtils or not SnakeUtils.occupied or not SnakeUtils.occupied[cols] then
		SnakeOccupancy.resetSnakeOccupancyGrid()
		reset = true
	end

	return true, reset
end

function SnakeOccupancy.addSnakeBodyOccupancy(col, row)
        local index = getGridIndex(col, row)
        if not index then
                return
        end

        snakeBodyOccupancy[index] = (snakeBodyOccupancy[index] or 0) + 1
        snakeBodyOccupancyMaxIndex = max(snakeBodyOccupancyMaxIndex, index)
end

function SnakeOccupancy.removeSnakeBodyOccupancy(col, row)
        local index = getGridIndex(col, row)
        if not index then
                return
        end

        local count = (snakeBodyOccupancy[index] or 0) - 1
        if count <= 0 then
                snakeBodyOccupancy[index] = nil
        else
                snakeBodyOccupancy[index] = count
        end
end

function SnakeOccupancy.isCellOccupiedBySnakeBody(col, row)
        local index = getGridIndex(col, row)
        if not index then
                return false
        end

        return (snakeBodyOccupancy[index] or 0) > 0
end

function SnakeOccupancy.addSnakeBodySpatialEntry(col, row, segment)
        if not segment then
                return
        end

        local index = getGridIndex(col, row)
        if not index then
                return
        end

        local bucket = snakeBodySpatialIndex[index]
        if not bucket then
                bucket = {}
                snakeBodySpatialIndex[index] = bucket
        end

        bucket[#bucket + 1] = segment
        snakeBodySpatialIndexMaxIndex = max(snakeBodySpatialIndexMaxIndex, index)
        snakeBodySpatialIndexAvailable = true
end

local function hasSnakeBodySpatialEntry(col, row, segment)
        if not segment then
                return false
        end

        local index = getGridIndex(col, row)
        if not index then
                return false
        end

        local bucket = snakeBodySpatialIndex[index]
        if not bucket then
                return false
        end

	for i = 1, #bucket do
		if bucket[i] == segment then
			return true
		end
	end

        return false
end

function SnakeOccupancy.removeSnakeBodySpatialEntry(col, row, segment)
        if not segment then
                return
        end

        local index = getGridIndex(col, row)
        if not index then
                return
        end

        local bucket = snakeBodySpatialIndex[index]
        if not bucket then
                return
        end

	for i = #bucket, 1, -1 do
		if bucket[i] == segment then
			bucket[i] = bucket[#bucket]
			bucket[#bucket] = nil
			break
		end
	end

        if not bucket[1] then
                snakeBodySpatialIndex[index] = nil
        end

        if snakeBodySpatialIndexAvailable and not hasSpatialEntries() then
                snakeBodySpatialIndexAvailable = false
        end
end

function SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
	SnakeOccupancy.clearSnakeBodySpatialIndex()

	if not (trail and trail[1]) then
		return
	end

	for i = 1, #trail do
		local segment = trail[i]
		local sx = segment and (segment.drawX or segment.x)
		local sy = segment and (segment.drawY or segment.y)
		local col, row = nil, nil
		if sx and sy and toCellFn then
			col, row = toCellFn(sx, sy)
		end

		if segment then
			segment.cellCol = col
			segment.cellRow = row
		end

		if i >= 2 and col and row then
			SnakeOccupancy.addSnakeBodySpatialEntry(col, row, segment)
		end
	end

        snakeBodySpatialIndexAvailable = hasSpatialEntries()
end

local function syncSegmentSpatialEntry(trail, segmentIndex)
	if not (trail and segmentIndex) then
		return false
	end

	local segment = trail[segmentIndex]
	if not segment then
		return false
	end

	local x = segment.drawX or segment.x
	local y = segment.drawY or segment.y

	local col, row = nil, nil
	if x and y and toCellFn then
		col, row = toCellFn(x, y)
	end

	local prevCol, prevRow = segment.cellCol, segment.cellRow

	if prevCol and prevRow and (prevCol ~= col or prevRow ~= row) then
		SnakeOccupancy.removeSnakeBodySpatialEntry(prevCol, prevRow, segment)
	end

	segment.cellCol = col
	segment.cellRow = row

	if segmentIndex >= 2 then
		if not (col and row) then
			return false
		end

		if not hasSnakeBodySpatialEntry(col, row, segment) then
			SnakeOccupancy.addSnakeBodySpatialEntry(col, row, segment)
		end
	elseif col and row then
		SnakeOccupancy.removeSnakeBodySpatialEntry(col, row, segment)
	end

	return true
end

local function syncSegmentSpatialRange(trail, startIndex, finishIndex)
	if not (trail and startIndex and finishIndex) then
		return true
	end

	if finishIndex < startIndex then
		return true
	end

	startIndex = max(1, startIndex)
	finishIndex = min(#trail, finishIndex)

	for i = startIndex, finishIndex do
		if not syncSegmentSpatialEntry(trail, i) then
			return false
		end
	end

	return true
end

function SnakeOccupancy.syncSnakeHeadSegments(trail, headCellCount, extraHeadSegments)
	if not trail or #trail == 0 then
		return true
	end

	local headSynced = syncSegmentSpatialEntry(trail, 1)
	if not headSynced then
		return false
	end

	local syncCount = headCellCount or 0
	if extraHeadSegments and extraHeadSegments > syncCount then
		syncCount = extraHeadSegments
	end

	if syncCount <= 0 then
		return true
	end

	local limit = 1 + syncCount
	return syncSegmentSpatialRange(trail, 2, limit)
end

function SnakeOccupancy.syncSnakeTailSegment(trail)
	if not trail then
		return true
	end

	local length = #trail
	if length <= 1 then
		return true
	end

	return syncSegmentSpatialEntry(trail, length)
end

local function clampTileBounds(minCol, maxCol, minRow, maxRow)
	if Arena then
		local cols = Arena.cols or maxCol
		local rows = Arena.rows or maxRow

		if cols and cols > 0 then
			if minCol < 1 then
				minCol = 1
			end
			if maxCol > cols then
				maxCol = cols
			end
		end

		if rows and rows > 0 then
			if minRow < 1 then
				minRow = 1
			end
			if maxRow > rows then
				maxRow = rows
			end
		end
	end

	if maxCol < minCol then
		maxCol = minCol
	end

	if maxRow < minRow then
		maxRow = minRow
	end

	return minCol, maxCol, minRow, maxRow
end

local function computeTileBoundsForRect(x, y, w, h)
	if not (x and y and w and h) then
		return nil, nil, nil, nil
	end

	local tileSize = (Arena and Arena.tileSize) or SnakeUtils.SEGMENT_SPACING or 1
	if tileSize == 0 then
		tileSize = 1
	end

	local offsetX = (Arena and Arena.x) or 0
	local offsetY = (Arena and Arena.y) or 0

	local minX = min(x, x + w)
	local maxX = max(x, x + w)
	local minY = min(y, y + h)
	local maxY = max(y, y + h)

	local epsilon = TILE_COORD_EPSILON or 1e-9
	local minCol = floor(((minX - offsetX) / tileSize) + epsilon) + 1
	local maxCol = floor(((maxX - offsetX) / tileSize) - epsilon) + 1
	local minRow = floor(((minY - offsetY) / tileSize) + epsilon) + 1
	local maxRow = floor(((maxY - offsetY) / tileSize) - epsilon) + 1

	return clampTileBounds(minCol, maxCol, minRow, maxRow)
end

local function resetSegmentCandidateBuffers()
	segmentCandidateCount = 0
	segmentCandidateGeneration = segmentCandidateGeneration + 1
	if segmentCandidateGeneration >= SEGMENT_CANDIDATE_GENERATION_RESET then
		segmentCandidateGeneration = 1
		segmentCandidateLookup = {}
	end
end

function SnakeOccupancy.collectSnakeSegmentCandidatesForRect(x, y, w, h)
	if not snakeBodySpatialIndexAvailable then
		return nil, 0, nil, segmentCandidateGeneration
	end

	resetSegmentCandidateBuffers()

	local minCol, maxCol, minRow, maxRow = computeTileBoundsForRect(x, y, w, h)
	if not (minCol and maxCol and minRow and maxRow) then
		segmentCandidateBuffer[segmentCandidateCount + 1] = nil
		return segmentCandidateBuffer, segmentCandidateCount, segmentCandidateLookup, segmentCandidateGeneration
	end

        local generation = segmentCandidateGeneration
        local spatialIndex = snakeBodySpatialIndex
        local lookup = segmentCandidateLookup
        local buffer = segmentCandidateBuffer
        local count = segmentCandidateCount
        local rows = occupancyRows

        for col = minCol, maxCol do
                local baseIndex = (col - 1) * rows
                for row = minRow, maxRow do
                        local entries = spatialIndex[baseIndex + row]
                        if entries then
                                for i = 1, #entries do
                                        local segment = entries[i]
                                        if segment and lookup[segment] ~= generation then
                                                lookup[segment] = generation
                                                count = count + 1
                                                buffer[count] = segment
                                        end
                                end
                        end
                end
        end

	segmentCandidateCount = count
	buffer[count + 1] = nil

	return buffer, count, lookup, generation
end

function SnakeOccupancy.collectSnakeSegmentCandidatesForCircle(cx, cy, radius)
        if not radius or radius <= 0 then
                return SnakeOccupancy.collectSnakeSegmentCandidatesForRect(cx, cy, 0, 0)
        end

        local diameter = radius * 2
        return SnakeOccupancy.collectSnakeSegmentCandidatesForRect(cx - radius, cy - radius, diameter, diameter)
end

local function resetHead(state)
	state.headOccupancyCol = nil
	state.headOccupancyRow = nil
	end

function SnakeOccupancy.newState()
	return {
	headCellBuffer = {},
	headOccupancyCol = nil,
	headOccupancyRow = nil,
	toCell = nil,
	newHeadSegmentsMax = 0,
	}
	end

function SnakeOccupancy.resetGrid(state)
	SnakeOccupancy.resetSnakeOccupancyGrid()
	resetHead(state)
	end

function SnakeOccupancy.ensureGrid(state)
	local ok, reset = SnakeOccupancy.ensureOccupancyGrid()
	if reset then
	resetHead(state)
	end

	return ok
	end

function SnakeOccupancy.rebuildFromTrail(state, trail, headColOverride, headRowOverride)
	if not SnakeOccupancy.ensureGrid(state) then
	SnakeOccupancy.resetTrackedSnakeCells()
	SnakeOccupancy.clearSnakeBodyOccupancy()
	resetHead(state)
	SnakeOccupancy.clearSnakeBodySpatialIndex()
	return
	end

	SnakeOccupancy.clearSnakeOccupiedCells()
	SnakeOccupancy.clearSnakeBodyOccupancy()

	if not trail then
	resetHead(state)
	SnakeOccupancy.clearSnakeBodySpatialIndex()
	return
	end

	local assignedHeadCol, assignedHeadRow = nil, nil

	for i = #trail, 1, -1 do
	local segment = trail[i]
	if segment then
	local x, y = segment.drawX, segment.drawY
	if x and y then
	local col, row = state.toCell and state.toCell(x, y)
	if col and row then
	if i == 1 then
	if headColOverride and headRowOverride then
	col, row = headColOverride, headRowOverride
	end
	assignedHeadCol, assignedHeadRow = col, row
	end

	SnakeOccupancy.recordSnakeOccupiedCell(col, row)

	if i ~= 1 then
	SnakeOccupancy.addSnakeBodyOccupancy(col, row)
	end
	end
	end
	end
	end

	SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)

	if assignedHeadCol and assignedHeadRow then
	state.headOccupancyCol = assignedHeadCol
	state.headOccupancyRow = assignedHeadRow
	else
	state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
	end
	end

function SnakeOccupancy.applyDelta(state, trail, headCellCount, overrideCol, overrideRow, tailMoved, tailAfterCol, tailAfterRow)
	SnakeOccupancy.clearRecentlyVacatedCells()

	if not SnakeOccupancy.ensureGrid(state) then
	SnakeOccupancy.resetTrackedSnakeCells()
	SnakeOccupancy.clearSnakeBodyOccupancy()
	resetHead(state)
	SnakeOccupancy.clearSnakeBodySpatialIndex()
	return
	end

	if not trail or #trail == 0 then
	SnakeOccupancy.clearSnakeOccupiedCells()
	SnakeOccupancy.clearSnakeBodyOccupancy()
	resetHead(state)
	SnakeOccupancy.clearSnakeBodySpatialIndex()
	return
	end

	local hasTailCol, hasTailRow = SnakeOccupancy.getSnakeTailCell()
	if not (hasTailCol and hasTailRow) then
	SnakeOccupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
	return
	end

	local processedHead = false
	local headCells = state.headCellBuffer

	for i = 1, headCellCount do
	local cell = headCells[i]
	local headCol = cell and cell[1]
	local headRow = cell and cell[2]
	if headCol and headRow then
	if state.headOccupancyCol ~= headCol or state.headOccupancyRow ~= headRow then
	processedHead = true
	local prevHeadCol, prevHeadRow = state.headOccupancyCol, state.headOccupancyRow
	SnakeOccupancy.recordSnakeOccupiedCell(headCol, headRow)
	if prevHeadCol and prevHeadRow then
	SnakeOccupancy.addSnakeBodyOccupancy(prevHeadCol, prevHeadRow)
	end
	state.headOccupancyCol = headCol
	state.headOccupancyRow = headRow
	end
	end
	end

	if not processedHead then
	if overrideCol and overrideRow then
	if state.headOccupancyCol ~= overrideCol or state.headOccupancyRow ~= overrideRow then
	SnakeOccupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
	return
	end
	else
	state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
	end
	end

	if not SnakeOccupancy.syncSnakeHeadSegments(trail, headCellCount, state.newHeadSegmentsMax) then
	SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
	return
	end

	if not tailMoved then
	return
	end

	if not tailAfterCol or not tailAfterRow then
	while true do
	local col, row = SnakeOccupancy.popSnakeTailCell()
	if not (col and row) then
	break
	end
	SnakeOccupancy.markRecentlyVacatedCell(col, row)
	SnakeUtils.setOccupied(col, row, false)
	SnakeOccupancy.removeSnakeBodyOccupancy(col, row)
	end

	state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
	SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
	return
	end

	local iterations = 0
	while true do
	local tailCol, tailRow = SnakeOccupancy.getSnakeTailCell()
	if not (tailCol and tailRow) then
	SnakeOccupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
	return
	end

	if tailCol == tailAfterCol and tailRow == tailAfterRow then
	break
	end

	local removedCol, removedRow = SnakeOccupancy.popSnakeTailCell()
	if not (removedCol and removedRow) then
	SnakeOccupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
	return
	end

	SnakeOccupancy.markRecentlyVacatedCell(removedCol, removedRow)
	SnakeUtils.setOccupied(removedCol, removedRow, false)
	SnakeOccupancy.removeSnakeBodyOccupancy(removedCol, removedRow)

	iterations = iterations + 1
	if iterations > 1024 then
	SnakeOccupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
	return
	end
	end

	state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
	if not SnakeOccupancy.syncSnakeTailSegment(trail) then
	SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
	end
	end

function SnakeOccupancy.getHeadOccupancy(state)
	return state.headOccupancyCol, state.headOccupancyRow
	end

function SnakeOccupancy.setNewHeadSegmentsMax(state, value)
	state.newHeadSegmentsMax = value
	end

return SnakeOccupancy
