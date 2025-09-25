local Arena = require("arena")

local SnakeUtils = {}

SnakeUtils.SEGMENT_SIZE = 24
SnakeUtils.SEGMENT_SPACING = SnakeUtils.SEGMENT_SIZE
SnakeUtils.SPEED = 8 -- cells per second now, not pixels
SnakeUtils.POP_DURATION = 0.3
local HANG_FACTOR = 0.6

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

-- Mark every grid cell overlapped by a saw’s track
function SnakeUtils.occupySawTrack(fx, fy, dir, radius, trackLength, side)
    -- Snap the center to tile space
    local centerCol, centerRow = Arena:getTileFromWorld(fx, fy)
    local tileSize = SnakeUtils.SEGMENT_SIZE
    local halfTiles = math.floor((trackLength / tileSize) / 2)

    if dir == "horizontal" then
        local startCol = centerCol - halfTiles
        local endCol   = centerCol + halfTiles
        local row      = centerRow

        for c = startCol, endCol do
            SnakeUtils.setOccupied(c, row, true)
        end

    else -- vertical
        local startRow = centerRow - halfTiles
        local endRow   = centerRow + halfTiles
        local col      = centerCol

        for r = startRow, endRow do
            SnakeUtils.setOccupied(col, r, true)
        end
    end
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
        local col = math.random(1, cols)
        local row = math.random(1, rows)
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

-- SnakeUtils.lua (add somewhere near the bottom)

local DEBUG_OCCUPANCY = true

function SnakeUtils.debugDrawOccupancy(grid, tileSize)
    if not DEBUG_OCCUPANCY or not grid then return end

    local ax, ay = Arena:getBounds()

    love.graphics.push()
    love.graphics.setColor(1, 0, 0, 0.25) -- semi-transparent red

    for col = 1, #grid do
        for row = 1, #grid[col] do
            if grid[col][row] then
                local x = ax + (col - 1) * tileSize
                local y = ay + (row - 1) * tileSize
                love.graphics.rectangle("fill", x, y, tileSize, tileSize)
            end
        end
    end

    love.graphics.pop()
end

function SnakeUtils.debugDrawGrid(tileSize)
    local ax, ay, aw, ah = Arena:getBounds()
    local cols, rows = Arena.cols, Arena.rows

    love.graphics.setColor(0, 1, 0, 0.2) -- faint green grid
    for col = 0, cols do
        love.graphics.line(ax + col * tileSize, ay, ax + col * tileSize, ay + ah)
    end
    for row = 0, rows do
        love.graphics.line(ax, ay + row * tileSize, ax + aw, ay + row * tileSize)
    end
end

return SnakeUtils
