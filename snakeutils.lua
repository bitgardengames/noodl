local Arena = require("arena")

local floor = math.floor
local min = math.min
local max = math.max

local SnakeUtils = {}

SnakeUtils.SEGMENT_SIZE = 24
SnakeUtils.SEGMENT_SPACING = SnakeUtils.SEGMENT_SIZE
SnakeUtils.POP_DURATION = 0.3

SnakeUtils.occupied = {}

local OCCUPANCY_FILL_COLOR = {0.95, 0.32, 0.28, 0.35}
local OCCUPANCY_OUTLINE_COLOR = {1.0, 0.62, 0.46, 0.85}
local OCCUPANCY_GRID_COLOR = {0.85, 0.9, 1.0, 0.22}

function SnakeUtils.initOccupancy()
	local occupied = SnakeUtils.occupied
	if type(occupied) ~= "table" then
		occupied = {}
		SnakeUtils.occupied = occupied
	end
	local cols = Arena.cols
	local rows = Arena.rows

	for col = 1, cols do
		local column = occupied[col]
		if not column then
			column = {}
			occupied[col] = column
		end

		for row = 1, rows do
			column[row] = false
		end

		for row = rows + 1, #column do
			column[row] = nil
		end
	end

	for col = cols + 1, #occupied do
		occupied[col] = nil
	end
end

-- Mark / unmark cells
function SnakeUtils.setOccupied(col, row, value)
	if SnakeUtils.occupied[col] and SnakeUtils.occupied[col][row] ~= nil then
		SnakeUtils.occupied[col][row] = value
	end
end

function SnakeUtils.isOccupied(col, row)
        return SnakeUtils.occupied[col] and SnakeUtils.occupied[col][row]
end

function SnakeUtils.drawOccupancyOverlay(options)
        if not love or not love.graphics then
                return
        end

        local cols = Arena.cols or 0
        local rows = Arena.rows or 0
        if cols <= 0 or rows <= 0 then
                return
        end

        local tileSize = Arena.tileSize or SnakeUtils.SEGMENT_SIZE or 24
        local occupied = SnakeUtils.occupied
        if type(occupied) ~= "table" then
                return
        end

        local gridColor = (options and options.gridColor) or OCCUPANCY_GRID_COLOR
        local fillColor = (options and options.fillColor) or OCCUPANCY_FILL_COLOR
        local outlineColor = (options and options.outlineColor) or OCCUPANCY_OUTLINE_COLOR
        local gridInset = (options and options.gridInset) or 0.5
        local occupiedInset = (options and options.occupiedInset) or 1.0
        local radius = min(8, tileSize * 0.35)
        local gridWidth = max(0, tileSize - gridInset * 2)
        local occupiedWidth = max(0, tileSize - occupiedInset * 2)

        local gridR, gridG, gridB, gridA
        if gridColor then
                gridR = gridColor[1] or 1
                gridG = gridColor[2] or 1
                gridB = gridColor[3] or 1
                gridA = gridColor[4] == nil and 1 or gridColor[4]
        end

        local fillR, fillG, fillB, fillA
        if fillColor then
                fillR = fillColor[1] or 1
                fillG = fillColor[2] or 1
                fillB = fillColor[3] or 1
                fillA = fillColor[4] == nil and 1 or fillColor[4]
        end

        local outlineR, outlineG, outlineB, outlineA
        if outlineColor then
                outlineR = outlineColor[1] or 1
                outlineG = outlineColor[2] or 1
                outlineB = outlineColor[3] or 1
                outlineA = outlineColor[4] == nil and 1 or outlineColor[4]
        end

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha")

        if gridColor then
                love.graphics.setColor(gridR, gridG, gridB, gridA)
                love.graphics.setLineWidth((options and options.gridLineWidth) or 1)
                if gridWidth > 0 then
                        for col = 1, cols do
                                for row = 1, rows do
                                        local x, y = Arena:getTilePosition(col, row)
                                        love.graphics.rectangle("line", x + gridInset, y + gridInset, gridWidth, gridWidth, radius, radius)
                                end
                        end
                end
        end

        if fillColor or outlineColor then
                local drawOutline = outlineColor ~= nil
                if drawOutline then
                        love.graphics.setLineWidth((options and options.occupiedLineWidth) or 1.5)
                end

                for col = 1, cols do
                        local column = occupied[col]
                        if column then
                                for row = 1, rows do
                                        if column[row] then
                                                local x, y = Arena:getTilePosition(col, row)
                                                if fillColor and occupiedWidth > 0 then
                                                        love.graphics.setColor(fillR, fillG, fillB, fillA)
                                                        love.graphics.rectangle("fill", x + occupiedInset, y + occupiedInset, occupiedWidth, occupiedWidth, radius, radius)
                                                end

                                                if drawOutline and occupiedWidth > 0 then
                                                        love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
                                                        love.graphics.rectangle("line", x + occupiedInset, y + occupiedInset, occupiedWidth, occupiedWidth, radius, radius)
                                                end
                                        end
                                end
                        end
                end
        end

        love.graphics.pop()
end

local function cellWithinBounds(col, row)
	return col >= 1 and col <= Arena.cols and row >= 1 and row <= Arena.rows
end

local function normalizeCell(col, row)
	if not col or not row then
		return nil
	end

	col = floor(col + 0.5)
	row = floor(row + 0.5)

	if not cellWithinBounds(col, row) then
		return nil
	end

	return col, row
end

local function markCells(cells, value)
	if not cells then
		return
	end

	local occupied = SnakeUtils.occupied
	for i = 1, #cells do
		local cell = cells[i]
		local col, row = normalizeCell(cell[1], cell[2])
		if col then
			local column = occupied[col]
			if column and column[row] ~= nil then
				column[row] = value
			end
		end
	end
end

-- Reserve a collection of cells and return the subset that we actually marked.
function SnakeUtils.reserveCells(cells)
	local reserved = {}

	if not cells then
		return reserved
	end

	local occupied = SnakeUtils.occupied
	for i = 1, #cells do
		local cell = cells[i]
		local col, row = normalizeCell(cell[1], cell[2])
		if col then
			local column = occupied[col]
			if column and not column[row] then
				column[row] = true
				reserved[#reserved + 1] = {col, row}
			end
		end
	end

	return reserved
end

function SnakeUtils.releaseCells(cells)
	markCells(cells, false)
end

local SAW_TRACK_OFFSETS = {-2, -1, 0, 1, 2}
local NUM_SAW_TRACK_OFFSETS = #SAW_TRACK_OFFSETS

local cellPool = {}
local cellPoolCount = 0

local function releaseCell(cell)
	cell[1] = nil
	cell[2] = nil
	cellPoolCount = cellPoolCount + 1
	cellPool[cellPoolCount] = cell
end

local function trimCells(buffer, count)
	for i = count + 1, #buffer do
		local cell = buffer[i]
		if cell then
			releaseCell(cell)
		end
		buffer[i] = nil
	end
	return buffer
end

local function acquireCell(col, row)
	if cellPoolCount > 0 then
		local cell = cellPool[cellPoolCount]
		cellPool[cellPoolCount] = nil
		cellPoolCount = cellPoolCount - 1
		cell[1] = col
		cell[2] = row
		return cell
	end

	return {col, row}
end

local function assignCell(buffer, index, col, row)
	local cell = buffer[index]
	if cell then
		cell[1] = col
		cell[2] = row
	else
		buffer[index] = acquireCell(col, row)
	end
end

function SnakeUtils.getSawTrackCells(fx, fy, dir, out)
	local centerCol, centerRow = Arena:getTileFromWorld(fx, fy)
	local cols = Arena.cols
	local rows = Arena.rows
	local offsets = SAW_TRACK_OFFSETS
	local cells = out or {}
	local count = 0

	if dir == "horizontal" then
		if centerRow < 1 or centerRow > rows then
			return trimCells(cells, 0)
		end

		for i = 1, NUM_SAW_TRACK_OFFSETS do
			local col = centerCol + offsets[i]
			if col < 1 or col > cols then
				return trimCells(cells, 0)
			end

			count = count + 1
			assignCell(cells, count, col, centerRow)
		end
	else
		if centerCol < 1 or centerCol > cols then
			return trimCells(cells, 0)
		end

		for i = 1, NUM_SAW_TRACK_OFFSETS do
			local row = centerRow + offsets[i]
			if row < 1 or row > rows then
				return trimCells(cells, 0)
			end

			count = count + 1
			assignCell(cells, count, centerCol, row)
		end
	end

	return trimCells(cells, count)
end

local function cellsAreFree(cells)
	if not cells or #cells == 0 then
		return false
	end

	local occupied = SnakeUtils.occupied
	for i = 1, #cells do
		local cell = cells[i]
		local column = occupied[cell[1]]
		if column and column[cell[2]] then
			return false
		end
	end

	return true
end

function SnakeUtils.occupySawTrack(fx, fy, dir)
	local cells = SnakeUtils.getSawTrackCells(fx, fy, dir)
	markCells(cells, true)
	return cells
end

local sawTrackScratch = {}

function SnakeUtils.sawTrackIsFree(fx, fy, dir)
	local cells = SnakeUtils.getSawTrackCells(fx, fy, dir, sawTrackScratch)
	return cellsAreFree(cells)
end

-- Safe spawn: just randomize until we find a free cell
-- Axis-Aligned Bounding Box
function SnakeUtils.aabb(ax, ay, asize, bx, by, bsize)
	-- If tables passed, extract drawX/drawY
	if type(ax) == "table" then
		ax, ay = ax.drawX, ax.drawY
		asize = SnakeUtils.SEGMENT_SIZE
	end
	if type(bx) == "table" then
		bx, by = bx.drawX, bx.drawY
		bsize = SnakeUtils.SEGMENT_SIZE
	end

	return ax < bx + bsize and
	ax + asize > bx and
	ay < by + bsize and
	ay + asize > by
end

-- handle input direction
function SnakeUtils.calculateDirection(current, input)
	local nd = SnakeUtils.directions[input]
	if nd and not (nd.x == -current.x and nd.y == -current.y) then
		return nd
	end
	return current
end

SnakeUtils.directions = {
	up    = {x = 0, y = -1},
	down  = {x = 0, y = 1},
	left  = {x = -1, y = 0},
	right = {x = 1, y = 0},
}

-- safer apple spawn (grid aware)
function SnakeUtils.getSafeSpawn(trail, fruit, rocks, safeZone, opts)
	opts = opts or {}
	local maxAttempts = 200
	local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
	local cols, rows = Arena.cols, Arena.rows

	trail = trail or {}
	local fruitX, fruitY = 0, 0
	if fruit and fruit.getPosition then
		fruitX, fruitY = fruit:getPosition()
	end
	local rockList = (rocks and rocks.getAll and rocks:getAll()) or {}
	local safeCells = safeZone or {}

	local avoidFront = not not opts.avoidFrontOfSnake
	local frontCells
	local frontLookup

	if avoidFront and trail[1] then
		local head = trail[1]
		local dirX, dirY = head.dirX, head.dirY

		if (dirX == nil or dirY == nil) and opts.direction then
			dirX = opts.direction.x
			dirY = opts.direction.y
		end

		if dirX and dirY then
			local headCol, headRow = Arena:getTileFromWorld(head.drawX, head.drawY)
			if headCol and headRow then
				local buffer = math.max(1, floor(opts.frontBuffer or 1))
				for i = 1, buffer do
					local aheadCol = headCol + dirX * i
					local aheadRow = headRow + dirY * i

					if cellWithinBounds(aheadCol, aheadRow) then
						if not frontCells then
							frontCells = {}
							frontLookup = {}
						end

						local key = aheadCol .. "," .. aheadRow
						if not frontLookup[key] then
							frontLookup[key] = true
							frontCells[#frontCells + 1] = {aheadCol, aheadRow}
						end
					else
						break
					end
				end
			end
		end
	end

	for _ = 1, maxAttempts do
		local col = love.math.random(1, cols)
		local row = love.math.random(1, rows)
		local cx, cy = Arena:getCenterOfTile(col, row)

		local blocked = false

		if SnakeUtils.isOccupied(col, row) then
			blocked = true
		end

		-- snake trail
		if not blocked then
			for _, segment in ipairs(trail) do
				if SnakeUtils.aabb(cx, cy, SEGMENT_SIZE, segment.drawX, segment.drawY, SEGMENT_SIZE, SEGMENT_SIZE) then
					blocked = true
					break
				end
			end
		end

		-- fruit
		if not blocked and SnakeUtils.aabb(cx, cy, SEGMENT_SIZE, fruitX, fruitY, SEGMENT_SIZE) then
			blocked = true
		end

		-- rocks
		if not blocked then
			for _, rock in ipairs(rockList) do
				if SnakeUtils.aabb(cx, cy, SEGMENT_SIZE, rock.x, rock.y, rock.w) then
					blocked = true
					break
				end
			end
		end

		if not blocked and safeZone then
			for _, cell in ipairs(safeCells) do
				if cell[1] == col and cell[2] == row then
					blocked = true
					break
				end
			end
		end

		if not blocked and frontCells then
			for i = 1, #frontCells do
				local cell = frontCells[i]
				if cell[1] == col and cell[2] == row then
					blocked = true
					break
				end
			end
		end

		if not blocked then
			return cx, cy, col, row
		end
	end

	return nil, nil, nil, nil
end

return SnakeUtils
