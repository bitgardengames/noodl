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
local FRUIT_HIGHLIGHT_FILL = {0.32, 0.95, 0.48, 0.3}
local FRUIT_HIGHLIGHT_OUTLINE = {0.32, 0.95, 0.48, 0.8}
local ROCK_HIGHLIGHT_FILL = {0.92, 0.78, 0.54, 0.3}
local ROCK_HIGHLIGHT_OUTLINE = {0.92, 0.78, 0.54, 0.8}
local SAW_TRACK_FILL_COLOR = {1.0, 0.86, 0.3, 0.25}
local SAW_TRACK_OUTLINE_COLOR = {1.0, 0.92, 0.46, 0.8}

local function getLoadedModule(name)
        local loaded = package.loaded[name]
        if loaded == nil or loaded == true then
                return nil
        end

        return loaded
end

local function snapToPixel(value)
        return floor(value + 0.5)
end

local function getLineOffset(width)
        local approximate = floor((width or 1) + 0.5)
        if approximate % 2 == 1 then
                return 0.5
        end

        return 0
end

local function wipeTable(t)
        if not t then
                return
        end

        for key in pairs(t) do
                t[key] = nil
        end
end

function SnakeUtils.initOccupancy()
        local occupied = SnakeUtils.occupied
        if type(occupied) ~= "table" then
                occupied = {}
                SnakeUtils.occupied = occupied
        end
        local cols = Arena.cols or 0
        if cols <= 0 then
                for col = 1, #occupied do
                        occupied[col] = nil
                end
                return
        end

        for col = 1, cols do
                local column = occupied[col]
                if not column then
                        column = {}
                        occupied[col] = column
                else
                        wipeTable(column)
                end
        end

        for col = cols + 1, #occupied do
                occupied[col] = nil
        end
end

-- Mark / unmark cells
function SnakeUtils.setOccupied(col, row, value)
        if not (col and row) then
                return
        end

        local occupied = SnakeUtils.occupied
        if type(occupied) ~= "table" then
                return
        end

        local cols = Arena.cols or 0
        local rows = Arena.rows or 0
        if col < 1 or col > cols or row < 1 or row > rows then
                return
        end

        local column = occupied[col]
        if not column then
                if not value then
                        return
                end

                column = {}
                occupied[col] = column
        end

        local current = column[row]
        if value then
                if current then
                        return
                end

                column[row] = true
        elseif current then
                column[row] = nil
        end
end

function SnakeUtils.isOccupied(col, row)
        local cols = Arena.cols or 0
        local rows = Arena.rows or 0
        if col < 1 or col > cols or row < 1 or row > rows then
                return false
        end

        local column = SnakeUtils.occupied[col]
        if not column then
                return false
        end

        return column[row] and true or false
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
        local gridWidth = max(0, floor((tileSize - gridInset * 2) + 0.5))
        local occupiedWidth = max(0, floor((tileSize - occupiedInset * 2) + 0.5))
        local gridLineWidth = (options and options.gridLineWidth) or 1
        local gridLineOffset = getLineOffset(gridLineWidth)
        local occupiedLineWidth = (options and options.occupiedLineWidth) or 1.5
        local occupiedLineOffset = getLineOffset(occupiedLineWidth)
        local occupiedOutlineWidth = max(0, occupiedWidth - occupiedLineOffset * 2)
        local objectInset = (options and options.objectInset) or occupiedInset
        local objectWidth = max(0, floor((tileSize - objectInset * 2) + 0.5))
        local objectLineWidth = (options and options.objectLineWidth) or 2
        local objectLineOffset = getLineOffset(objectLineWidth)
        local objectOutlineWidth = max(0, objectWidth - objectLineOffset * 2)
        local fruitHighlightFill = (options and options.fruitHighlightFill) or FRUIT_HIGHLIGHT_FILL
        local fruitHighlightOutline = (options and options.fruitHighlightOutline) or FRUIT_HIGHLIGHT_OUTLINE
        local rockHighlightFill = (options and options.rockHighlightFill) or ROCK_HIGHLIGHT_FILL
        local rockHighlightOutline = (options and options.rockHighlightOutline) or ROCK_HIGHLIGHT_OUTLINE
        local sawHighlightFill = (options and options.sawTrackHighlightFill) or SAW_TRACK_FILL_COLOR
        local sawHighlightOutline = (options and options.sawTrackHighlightOutline) or SAW_TRACK_OUTLINE_COLOR

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
                love.graphics.setLineWidth(gridLineWidth)
                local gridDrawWidth = max(0, gridWidth - gridLineOffset * 2)
                if gridDrawWidth > 0 then
                        for col = 1, cols do
                                for row = 1, rows do
                                        local x, y = Arena:getTilePosition(col, row)
                                        x = snapToPixel(x)
                                        y = snapToPixel(y)
                                        love.graphics.rectangle(
                                                "line",
                                                x + gridInset + gridLineOffset,
                                                y + gridInset + gridLineOffset,
                                                gridDrawWidth,
                                                gridDrawWidth,
                                                radius,
                                                radius
                                        )
                                end
                        end
                end
        end

        if fillColor or outlineColor then
                local drawOutline = outlineColor ~= nil and occupiedOutlineWidth > 0
                if drawOutline then
                        love.graphics.setLineWidth(occupiedLineWidth)
                end

                for col = 1, cols do
                        local column = occupied[col]
                        if column then
                                for row = 1, rows do
                                        if column[row] then
                                                local x, y = Arena:getTilePosition(col, row)
                                                x = snapToPixel(x)
                                                y = snapToPixel(y)
                                                if fillColor and occupiedWidth > 0 then
                                                        love.graphics.setColor(fillR, fillG, fillB, fillA)
                                                        love.graphics.rectangle("fill", x + occupiedInset, y + occupiedInset, occupiedWidth, occupiedWidth, radius, radius)
                                                end

                                                if drawOutline then
                                                        love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
                                                        love.graphics.rectangle(
                                                                "line",
                                                                x + occupiedInset + occupiedLineOffset,
                                                                y + occupiedInset + occupiedLineOffset,
                                                                occupiedOutlineWidth,
                                                                occupiedOutlineWidth,
                                                                radius,
                                                                radius
                                                        )
                                                end
                                        end
                                end
                        end
                end
        end

        local function drawHighlightCell(col, row, fillColor, outlineColor)
                if (not fillColor or objectWidth <= 0) and (not outlineColor or objectOutlineWidth <= 0) then
                        return
                end

                if not (col and row) then
                        return
                end

                if col < 1 or col > cols or row < 1 or row > rows then
                        return
                end

                local x, y = Arena:getTilePosition(col, row)
                x = snapToPixel(x)
                y = snapToPixel(y)

                if fillColor and objectWidth > 0 then
                        local r = fillColor[1] or 1
                        local g = fillColor[2] or 1
                        local b = fillColor[3] or 1
                        local a = fillColor[4] == nil and 1 or fillColor[4]
                        love.graphics.setColor(r, g, b, a)
                        love.graphics.rectangle("fill", x + objectInset, y + objectInset, objectWidth, objectWidth, radius, radius)
                end

                if outlineColor and objectOutlineWidth > 0 then
                        local r = outlineColor[1] or 1
                        local g = outlineColor[2] or 1
                        local b = outlineColor[3] or 1
                        local a = outlineColor[4] == nil and 1 or outlineColor[4]
                        love.graphics.setColor(r, g, b, a)
                        love.graphics.setLineWidth(objectLineWidth)
                        love.graphics.rectangle(
                                "line",
                                x + objectInset + objectLineOffset,
                                y + objectInset + objectLineOffset,
                                objectOutlineWidth,
                                objectOutlineWidth,
                                radius,
                                radius
                        )
                end
        end

        local Fruit = getLoadedModule("fruit")
        if Fruit and Fruit.getTile then
                local fruitCol, fruitRow = Fruit:getTile()
                if fruitCol and fruitRow and SnakeUtils.isOccupied and SnakeUtils.isOccupied(fruitCol, fruitRow) then
                        drawHighlightCell(fruitCol, fruitRow, fruitHighlightFill, fruitHighlightOutline)
                end
        end

        local Rocks = getLoadedModule("rocks")
        if Rocks and Rocks.getAll then
                local rockList = Rocks:getAll()
                if type(rockList) == "table" then
                        for i = 1, #rockList do
                                local rock = rockList[i]
                                if rock then
                                        local rockCol, rockRow = rock.col, rock.row
                                        if not (rockCol and rockRow) and rock.x and rock.y then
                                                rockCol, rockRow = Arena:getTileFromWorld(rock.x, rock.y)
                                        end
                                        drawHighlightCell(rockCol, rockRow, rockHighlightFill, rockHighlightOutline)
                                end
                        end
                end
        end

        local Saws = getLoadedModule("saws")
        if Saws and Saws.getAll then
                local sawList = Saws:getAll()
                if type(sawList) == "table" and #sawList > 0 then
                        local seen = {}
                        for i = 1, #sawList do
                                local saw = sawList[i]
                                if saw then
                                        local cells = SnakeUtils.getSawTrackCells(saw.x, saw.y, saw.dir)
                                        if cells then
                                                for j = 1, #cells do
                                                        local cell = cells[j]
                                                        local col, row = cell and cell[1], cell and cell[2]
                                                        if col and row then
                                                                local key = col .. ":" .. row
                                                                if not seen[key] then
                                                                        seen[key] = true
                                                                        drawHighlightCell(col, row, sawHighlightFill, sawHighlightOutline)
                                                                end
                                                        end
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
                        if not column then
                                if value then
                                        column = {}
                                        occupied[col] = column
                                else
                                        column = nil
                                end
                        end

                        if column then
                                if value then
                                        column[row] = true
                                else
                                        column[row] = nil
                                end
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

-- Axis-Aligned Bounding Box
function SnakeUtils.aabb(ax, ay, asize, bx, by, bsize)
        -- If tables passed, extract drawX/drawY and assume segment-sized squares
        if type(ax) == "table" then
                ax, ay = ax.drawX, ax.drawY
                asize = SnakeUtils.SEGMENT_SIZE
        end
        if type(bx) == "table" then
                bx, by = bx.drawX, bx.drawY
                bsize = SnakeUtils.SEGMENT_SIZE
        end

        if not (ax and ay and bx and by) then
                return false
        end

        asize = asize or SnakeUtils.SEGMENT_SIZE
        bsize = bsize or SnakeUtils.SEGMENT_SIZE

        local ah = (asize or 0) * 0.5
        local bh = (bsize or 0) * 0.5

        return (ax - ah) < (bx + bh) and
        (ax + ah) > (bx - bh) and
        (ay - ah) < (by + bh) and
        (ay + ah) > (by - bh)
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
