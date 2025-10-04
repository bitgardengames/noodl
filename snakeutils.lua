local Arena = require("arena")

local SnakeUtils = {}

SnakeUtils.SEGMENT_SIZE = 24
SnakeUtils.SEGMENT_SPACING = SnakeUtils.SEGMENT_SIZE
SnakeUtils.SPEED = 8 -- cells per second now, not pixels
SnakeUtils.POP_DURATION = 0.3

SnakeUtils.occupied = {}

function SnakeUtils.initOccupancy()
    SnakeUtils.occupied = {}
    for col = 1, Arena.cols do
        SnakeUtils.occupied[col] = {}
        for row = 1, Arena.rows do
            SnakeUtils.occupied[col][row] = false
        end
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

local function cellWithinBounds(col, row)
    return col >= 1 and col <= Arena.cols and row >= 1 and row <= Arena.rows
end

local function normalizeCell(col, row)
    if not col or not row then
        return nil
    end

    col = math.floor(col + 0.5)
    row = math.floor(row + 0.5)

    if not cellWithinBounds(col, row) then
        return nil
    end

    return col, row
end

local function forEachNormalizedCell(cells, callback)
    if not cells then
        return
    end

    for _, cell in ipairs(cells) do
        local col, row = normalizeCell(cell[1], cell[2])
        if col then
            callback(col, row)
        end
    end
end

local function markCells(cells, value)
    forEachNormalizedCell(cells, function(col, row)
        SnakeUtils.setOccupied(col, row, value)
    end)
end

-- Reserve a collection of cells and return the subset that we actually marked.
function SnakeUtils.reserveCells(cells)
    local reserved = {}

    forEachNormalizedCell(cells, function(col, row)
        if not SnakeUtils.isOccupied(col, row) then
            SnakeUtils.setOccupied(col, row, true)
            reserved[#reserved + 1] = {col, row}
        end
    end)

    return reserved
end

function SnakeUtils.releaseCells(cells)
    markCells(cells, false)
end

function SnakeUtils.getTrackCells(fx, fy, dir, trackLength)
    local centerCol, centerRow = Arena:getTileFromWorld(fx, fy)
    local tileSize = SnakeUtils.SEGMENT_SIZE
    local halfTiles = math.floor((trackLength / tileSize) / 2)
    local cells = {}

    if dir == "horizontal" then
        local startCol = centerCol - halfTiles
        local endCol   = centerCol + halfTiles
        if startCol < 1 or endCol > Arena.cols then
            return {}
        end

        for c = startCol, endCol do
            cells[#cells + 1] = {c, centerRow}
        end
    else
        local startRow = centerRow - halfTiles
        local endRow   = centerRow + halfTiles
        if startRow < 1 or endRow > Arena.rows then
            return {}
        end

        for r = startRow, endRow do
            cells[#cells + 1] = {centerCol, r}
        end
    end

    return cells
end

local SAW_TRACK_OFFSETS = {-2, -1, 0, 1, 2}

function SnakeUtils.getSawTrackCells(fx, fy, dir)
    local centerCol, centerRow = Arena:getTileFromWorld(fx, fy)
    local cells = {}

    if dir == "horizontal" then
        if centerRow < 1 or centerRow > Arena.rows then
            return {}
        end

        for _, offset in ipairs(SAW_TRACK_OFFSETS) do
            local col = centerCol + offset
            if col < 1 or col > Arena.cols then
                return {}
            end

            cells[#cells + 1] = {col, centerRow}
        end
    else
        if centerCol < 1 or centerCol > Arena.cols then
            return {}
        end

        for _, offset in ipairs(SAW_TRACK_OFFSETS) do
            local row = centerRow + offset
            if row < 1 or row > Arena.rows then
                return {}
            end

            cells[#cells + 1] = {centerCol, row}
        end
    end

    return cells
end

local function cellsAreFree(cells)
    if not cells or #cells == 0 then
        return false
    end

    for _, cell in ipairs(cells) do
        if SnakeUtils.isOccupied(cell[1], cell[2]) then
            return false
        end
    end

    return true
end

function SnakeUtils.trackIsFree(fx, fy, dir, trackLength)
    return cellsAreFree(SnakeUtils.getTrackCells(fx, fy, dir, trackLength))
end

-- Mark every grid cell overlapped by a hazard track
function SnakeUtils.occupyTrack(fx, fy, dir, trackLength)
    local cells = SnakeUtils.getTrackCells(fx, fy, dir, trackLength)
    markCells(cells, true)
    return cells
end

function SnakeUtils.occupySawTrack(fx, fy, dir)
    local cells = SnakeUtils.getSawTrackCells(fx, fy, dir)
    markCells(cells, true)
    return cells
end

function SnakeUtils.sawTrackIsFree(fx, fy, dir)
    return cellsAreFree(SnakeUtils.getSawTrackCells(fx, fy, dir))
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
function SnakeUtils.calculateDirection(current, input, reverse)
    local nd = SnakeUtils.directions[input]
    if reverse and nd then nd = { x = -nd.x, y = -nd.y } end
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
function SnakeUtils.getSafeSpawn(trail, fruit, rocks, safeZone)
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

        if not blocked then
            return cx, cy, col, row
        end
    end

    return nil, nil, nil, nil
end

return SnakeUtils
