local Arena = require("arena")

local SnakeUtils = {}

SnakeUtils.SEGMENT_SIZE = 24
SnakeUtils.SEGMENT_SPACING = SnakeUtils.SEGMENT_SIZE
SnakeUtils.SPEED = 8 -- cells per second now, not pixels
SnakeUtils.POP_DURATION = 0.3

SnakeUtils.occupied = {}

function SnakeUtils.InitOccupancy()
	SnakeUtils.occupied = {}
	for col = 1, Arena.cols do
		SnakeUtils.occupied[col] = {}
		for row = 1, Arena.rows do
			SnakeUtils.occupied[col][row] = false
		end
	end
end

-- Mark / unmark cells
function SnakeUtils.SetOccupied(col, row, value)
	if SnakeUtils.occupied[col] and SnakeUtils.occupied[col][row] ~= nil then
		SnakeUtils.occupied[col][row] = value
	end
end

function SnakeUtils.IsOccupied(col, row)
	return SnakeUtils.occupied[col] and SnakeUtils.occupied[col][row]
end

local function CellWithinBounds(col, row)
	return col >= 1 and col <= Arena.cols and row >= 1 and row <= Arena.rows
end

local function NormalizeCell(col, row)
	if not col or not row then
		return nil
	end

	col = math.floor(col + 0.5)
	row = math.floor(row + 0.5)

	if not CellWithinBounds(col, row) then
		return nil
	end

	return col, row
end

local function ForEachNormalizedCell(cells, callback)
	if not cells then
		return
	end

	for _, cell in ipairs(cells) do
		local col, row = NormalizeCell(cell[1], cell[2])
		if col then
			callback(col, row)
		end
	end
end

local function MarkCells(cells, value)
	ForEachNormalizedCell(cells, function(col, row)
		SnakeUtils.SetOccupied(col, row, value)
	end)
end

-- Reserve a collection of cells and return the subset that we actually marked.
function SnakeUtils.ReserveCells(cells)
	local reserved = {}

	ForEachNormalizedCell(cells, function(col, row)
		if not SnakeUtils.IsOccupied(col, row) then
			SnakeUtils.SetOccupied(col, row, true)
			reserved[#reserved + 1] = {col, row}
		end
	end)

	return reserved
end

function SnakeUtils.ReleaseCells(cells)
	MarkCells(cells, false)
end

function SnakeUtils.GetTrackCells(fx, fy, dir, TrackLength)
	local CenterCol, CenterRow = Arena:GetTileFromWorld(fx, fy)
	local TileSize = SnakeUtils.SEGMENT_SIZE
	local HalfTiles = math.floor((TrackLength / TileSize) / 2)
	local cells = {}

	if dir == "horizontal" then
		local StartCol = CenterCol - HalfTiles
		local EndCol   = CenterCol + HalfTiles
		if StartCol < 1 or EndCol > Arena.cols then
			return {}
		end

		for c = StartCol, EndCol do
			cells[#cells + 1] = {c, CenterRow}
		end
	else
		local StartRow = CenterRow - HalfTiles
		local EndRow   = CenterRow + HalfTiles
		if StartRow < 1 or EndRow > Arena.rows then
			return {}
		end

		for r = StartRow, EndRow do
			cells[#cells + 1] = {CenterCol, r}
		end
	end

	return cells
end

local SAW_TRACK_OFFSETS = {-2, -1, 0, 1, 2}

function SnakeUtils.GetSawTrackCells(fx, fy, dir)
	local CenterCol, CenterRow = Arena:GetTileFromWorld(fx, fy)
	local cells = {}

	if dir == "horizontal" then
		if CenterRow < 1 or CenterRow > Arena.rows then
			return {}
		end

		for _, offset in ipairs(SAW_TRACK_OFFSETS) do
			local col = CenterCol + offset
			if col < 1 or col > Arena.cols then
				return {}
			end

			cells[#cells + 1] = {col, CenterRow}
		end
	else
		if CenterCol < 1 or CenterCol > Arena.cols then
			return {}
		end

		for _, offset in ipairs(SAW_TRACK_OFFSETS) do
			local row = CenterRow + offset
			if row < 1 or row > Arena.rows then
				return {}
			end

			cells[#cells + 1] = {CenterCol, row}
		end
	end

	return cells
end

local function CellsAreFree(cells)
	if not cells or #cells == 0 then
		return false
	end

	for _, cell in ipairs(cells) do
		if SnakeUtils.IsOccupied(cell[1], cell[2]) then
			return false
		end
	end

	return true
end

function SnakeUtils.TrackIsFree(fx, fy, dir, TrackLength)
	return CellsAreFree(SnakeUtils.GetTrackCells(fx, fy, dir, TrackLength))
end

-- Mark every grid cell overlapped by a hazard track
function SnakeUtils.OccupyTrack(fx, fy, dir, TrackLength)
	local cells = SnakeUtils.GetTrackCells(fx, fy, dir, TrackLength)
	MarkCells(cells, true)
	return cells
end

function SnakeUtils.OccupySawTrack(fx, fy, dir)
	local cells = SnakeUtils.GetSawTrackCells(fx, fy, dir)
	MarkCells(cells, true)
	return cells
end

function SnakeUtils.SawTrackIsFree(fx, fy, dir)
	return CellsAreFree(SnakeUtils.GetSawTrackCells(fx, fy, dir))
end

-- Safe spawn: just randomize until we find a free cell
-- Axis-Aligned Bounding Box
function SnakeUtils.aabb(ax, ay, asize, bx, by, bsize)
	-- If tables passed, extract DrawX/DrawY
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
function SnakeUtils.CalculateDirection(current, input)
	local nd = SnakeUtils.directions[input]
	if nd and not (nd.x == -current.x and nd.y == -current.y) then
		return nd
	end
	return current
end

SnakeUtils.directions = {
	up    = { x = 0, y = -1 },
	down  = { x = 0, y = 1 },
	left  = { x = -1, y = 0 },
	right = { x = 1, y = 0 },
}

-- safer apple spawn (grid aware)
function SnakeUtils.GetSafeSpawn(trail, fruit, rocks, SafeZone, opts)
	opts = opts or {}
	local MaxAttempts = 200
	local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
	local cols, rows = Arena.cols, Arena.rows

	trail = trail or {}
	local FruitX, FruitY = 0, 0
	if fruit and fruit.getPosition then
		FruitX, FruitY = fruit:getPosition()
	end
	local RockList = (rocks and rocks.getAll and rocks:getAll()) or {}
	local SafeCells = SafeZone or {}

	local AvoidFront = not not opts.avoidFrontOfSnake
	local FrontCells
	local FrontLookup

	if AvoidFront and trail[1] then
		local head = trail[1]
		local DirX, DirY = head.dirX, head.dirY

		if (DirX == nil or DirY == nil) and opts.direction then
			DirX = opts.direction.x
			DirY = opts.direction.y
		end

		if DirX and DirY then
			local HeadCol, HeadRow = Arena:GetTileFromWorld(head.drawX, head.drawY)
			if HeadCol and HeadRow then
				local buffer = math.max(1, math.floor(opts.frontBuffer or 1))
				for i = 1, buffer do
					local AheadCol = HeadCol + DirX * i
					local AheadRow = HeadRow + DirY * i

					if CellWithinBounds(AheadCol, AheadRow) then
						if not FrontCells then
							FrontCells = {}
							FrontLookup = {}
						end

						local key = AheadCol .. "," .. AheadRow
						if not FrontLookup[key] then
							FrontLookup[key] = true
							FrontCells[#FrontCells + 1] = { AheadCol, AheadRow }
						end
					else
						break
					end
				end
			end
		end
	end

	for _ = 1, MaxAttempts do
		local col = love.math.random(1, cols)
		local row = love.math.random(1, rows)
		local cx, cy = Arena:GetCenterOfTile(col, row)

		local blocked = false

		if SnakeUtils.IsOccupied(col, row) then
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
		if not blocked and SnakeUtils.aabb(cx, cy, SEGMENT_SIZE, FruitX, FruitY, SEGMENT_SIZE) then
			blocked = true
		end

		-- rocks
		if not blocked then
			for _, rock in ipairs(RockList) do
				if SnakeUtils.aabb(cx, cy, SEGMENT_SIZE, rock.x, rock.y, rock.w) then
					blocked = true
					break
				end
			end
		end

		if not blocked and SafeZone then
			for _, cell in ipairs(SafeCells) do
				if cell[1] == col and cell[2] == row then
					blocked = true
					break
				end
			end
		end

		if not blocked and FrontCells then
			for i = 1, #FrontCells do
				local cell = FrontCells[i]
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
