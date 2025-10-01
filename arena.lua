local Theme = require("theme")
local Audio = require("audio")

local EXIT_SAFE_ATTEMPTS = 180
local MIN_HEAD_DISTANCE_TILES = 2

local function getModule(name)
    local loaded = package.loaded[name]
    if loaded ~= nil then
        if loaded == true then
            return nil
        end
        return loaded
    end

    local ok, result = pcall(require, name)
    if ok then
        return result
    end

    return nil
end

local function distanceSquared(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

local function getHighlightColor(color)
    color = color or {1, 1, 1, 1}

    local r = math.min(1, color[1] * 1.2 + 0.08)
    local g = math.min(1, color[2] * 1.2 + 0.08)
    local b = math.min(1, color[3] * 1.2 + 0.08)
    local a = (color[4] or 1) * 0.75

    return {r, g, b, a}
end

local function isTileInSafeZone(safeZone, col, row)
    if not safeZone then return false end

    for _, cell in ipairs(safeZone) do
        if cell[1] == col and cell[2] == row then
            return true
        end
    end

    return false
end

local Arena = {
    x = 0, y = 0,
    width = 792,
    height = 600,
    tileSize = 24,
    cols = 0,
    rows = 0,
	exit = nil,
}

function Arena:updateScreenBounds(sw, sh)
    self.x = math.floor((sw - self.width) / 2)
    self.y = math.floor((sh - self.height) / 2)

    -- snap x,y to nearest tile boundary so centers align
    self.x = self.x - (self.x % self.tileSize)
    self.y = self.y - (self.y % self.tileSize)

    self.cols = math.floor(self.width / self.tileSize)
    self.rows = math.floor(self.height / self.tileSize)
end

function Arena:getTilePosition(col, row)
    return self.x + (col - 1) * self.tileSize,
           self.y + (row - 1) * self.tileSize
end

function Arena:getCenterOfTile(col, row)
    local x, y = self:getTilePosition(col, row)
    return x + self.tileSize / 2, y + self.tileSize / 2
end

function Arena:getRandomWorldPosition()
    return self:getCenterOfTile(self:getRandomTile())
end

function Arena:getTileFromWorld(x, y)
    local col = math.floor((x - self.x) / self.tileSize) + 1
    local row = math.floor((y - self.y) / self.tileSize) + 1

    -- clamp inside arena grid
    col = math.max(1, math.min(self.cols, col))
    row = math.max(1, math.min(self.rows, row))

    return col, row
end

function Arena:isInside(x, y)
    local inset = self.tileSize / 2

    return x >= (self.x + inset) and
           x <= (self.x + self.width  - inset) and
           y >= (self.y + inset) and
           y <= (self.y + self.height - inset)
end

function Arena:getRandomTile()
    local col = love.math.random(2, self.cols - 1)
    local row = love.math.random(2, self.rows - 1)
    return col, row
end

function Arena:getBounds()
    return self.x, self.y, self.width, self.height
end

-- Draws the playfield with a solid fill + simple border
function Arena:drawBackground()
    local ax, ay, aw, ah = self:getBounds()

    -- Solid fill
    love.graphics.setColor(Theme.arenaBG)
    love.graphics.rectangle("fill", ax, ay, aw, ah)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draws border
function Arena:drawBorder()
    local ax, ay, aw, ah = self:getBounds()

    -- Match snake style
    local thickness    = 18       -- border thickness
    local outlineSize  = 6        -- black outline thickness
    local shadowOffset = 3
    local radius       = thickness / 2

    -- Expand the border rect outward so it doesn’t bleed inside
	local correction = (thickness / 2) + 3   -- negative = pull inward, positive = push outward
	local ox = correction
	local oy = correction
	local bx, by = ax - ox, ay - oy
	local bw, bh = aw + ox * 2, ah + oy * 2

    -- Create/reuse MSAA canvas
    if not self.borderCanvas or
       self.borderCanvas:getWidth() ~= love.graphics.getWidth() or
       self.borderCanvas:getHeight() ~= love.graphics.getHeight() then
        self.borderCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {msaa = 8})
    end

    love.graphics.setCanvas(self.borderCanvas)
    love.graphics.clear(0,0,0,0)

    love.graphics.setLineStyle("smooth")

    -- Outline pass
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(thickness + outlineSize)
    love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

    -- Fill (arena border color)
    love.graphics.setColor(Theme.arenaBorder)
    love.graphics.setLineWidth(thickness)
    love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)

    -- Highlight pass for the top + left edges
    local highlightShift = 3
    local function appendArcPoints(points, cx, cy, radius, startAngle, endAngle, segments, skipFirst)
        if segments < 1 then
            segments = 1
        end

        for i = 0, segments do
            if not (skipFirst and i == 0) then
                local t = i / segments
                local angle = startAngle + (endAngle - startAngle) * t
                points[#points + 1] = cx + math.cos(angle) * radius - highlightShift
                points[#points + 1] = cy + math.sin(angle) * radius - highlightShift
            end
        end
    end

    local highlight = getHighlightColor(Theme.arenaBorder)
    local highlightWidth = math.max(1.5, thickness * 0.32)
    local highlightOffset = 2
    local cornerOffsetX = 2
    local cornerOffsetY = 2
    local scissorX = math.floor(bx - highlightWidth - highlightOffset - highlightShift)
    local scissorY = math.floor(by - highlightWidth - highlightOffset - highlightShift)
    local scissorW = math.ceil(bw + highlightWidth * 2 + highlightOffset + highlightShift * 2)
    local scissorH = math.ceil(bh + highlightWidth * 2 + highlightOffset + highlightShift * 2)
    local outerRadius = radius + highlightOffset
    local arcSegments = math.max(6, math.floor(outerRadius * 0.75))

    local topPoints = {}
    topPoints[#topPoints + 1] = bx + bw - radius - highlightShift
    topPoints[#topPoints + 1] = by - highlightOffset - highlightShift
    topPoints[#topPoints + 1] = bx + radius - highlightShift
    topPoints[#topPoints + 1] = by - highlightOffset - highlightShift
    local cornerStartIndex = #topPoints + 1
    appendArcPoints(topPoints, bx + radius - highlightShift, by + radius - highlightShift, outerRadius, -math.pi / 2, -math.pi, arcSegments, true)
    for i = cornerStartIndex, #topPoints, 2 do
        topPoints[i] = topPoints[i] + cornerOffsetX
        topPoints[i + 1] = topPoints[i + 1] + cornerOffsetY
    end

    local leftPoints = {}
    leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
    leftPoints[#leftPoints + 1] = by + radius - highlightShift
    leftPoints[#leftPoints + 1] = bx - highlightOffset - highlightShift
    leftPoints[#leftPoints + 1] = by + bh - radius - highlightShift

    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
    local prevLineWidth = love.graphics.getLineWidth()
    local prevLineStyle = love.graphics.getLineStyle()
    local prevLineJoin = love.graphics.getLineJoin()
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(highlightWidth)

    -- Top edge highlight
    love.graphics.setScissor(scissorX, scissorY, scissorW, math.ceil(highlightWidth * 2.4 + cornerOffsetY))
    love.graphics.line(topPoints)

    -- Left edge highlight
    love.graphics.setScissor(scissorX, scissorY, math.ceil(highlightWidth * 2.4), scissorH)
    love.graphics.line(leftPoints)

    love.graphics.setScissor()
    love.graphics.setLineWidth(prevLineWidth)
    love.graphics.setLineStyle(prevLineStyle)
    love.graphics.setLineJoin(prevLineJoin)

    -- Soft caps for highlight ends
    local topCapX = bx + bw - radius - highlightShift
    local topCapY = by - highlightOffset - highlightShift
    local leftCapX = bx - highlightOffset - highlightShift
    local leftCapY = by + bh - radius - highlightShift

    local capRadius = highlightWidth * 0.75
    local featherRadius = capRadius * 1.5
    local capAlpha = highlight[4] * 0.55
    local featherAlpha = highlight[4] * 0.22

    local function drawHighlightCap(cx, cy)
        if capAlpha > 0 then
            love.graphics.setColor(highlight[1], highlight[2], highlight[3], capAlpha)
            love.graphics.circle("fill", cx, cy, capRadius)
        end

        if featherAlpha > 0 then
            love.graphics.setColor(highlight[1], highlight[2], highlight[3], featherAlpha)
            love.graphics.circle("fill", cx, cy, featherRadius)
        end
    end

    drawHighlightCap(topCapX, topCapY)
    drawHighlightCap(leftCapX, leftCapY)

    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])

    love.graphics.setCanvas()

    -- Shadow pass
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.draw(self.borderCanvas, shadowOffset, shadowOffset)

    -- Final draw
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.borderCanvas, 0, 0)
end

function Arena:drawGrid()
    local ax, ay, aw, ah = self:getBounds()
    love.graphics.setColor(1, 1, 1, 0.03) -- very faint
    local step = self.tileSize * 2
    for x = ax, ax + aw, step do
        love.graphics.line(x, ay, x, ay + ah)
    end
    for y = ay, ay + ah, step do
        love.graphics.line(ax, y, ax + aw, y)
    end
end

-- Spawn an exit at a random valid tile
function Arena:spawnExit()
    if self.exit then return end

    local SnakeUtils = getModule("snakeutils")
    local Fruit = getModule("fruit")
    local fruitCol, fruitRow = nil, nil
    if Fruit and Fruit.getTile then
        fruitCol, fruitRow = Fruit:getTile()
    end

    local Rocks = getModule("rocks")
    local rockList = (Rocks and Rocks.getAll and Rocks:getAll()) or {}

    local Snake = getModule("snake")
    local snakeSegments = nil
    local snakeSafeZone = nil
    local headX, headY = nil, nil
    if Snake then
        if Snake.getSegments then
            snakeSegments = Snake:getSegments()
        end
        if Snake.getSafeZone then
            snakeSafeZone = Snake:getSafeZone(3)
        end
        if Snake.getHead then
            headX, headY = Snake:getHead()
        end
    end

    local threshold = (SnakeUtils and SnakeUtils.SEGMENT_SIZE) or self.tileSize
    local halfThreshold = threshold * 0.5
    local minHeadDistance = self.tileSize * MIN_HEAD_DISTANCE_TILES
    local minHeadDistanceSq = minHeadDistance * minHeadDistance

    local function tileIsSafe(col, row)
        local cx, cy = self:getCenterOfTile(col, row)

        if SnakeUtils and SnakeUtils.isOccupied and SnakeUtils.isOccupied(col, row) then
            return false
        end

        if fruitCol and fruitRow and fruitCol == col and fruitRow == row then
            return false
        end

        for _, rock in ipairs(rockList) do
            local rcol, rrow = self:getTileFromWorld(rock.x or cx, rock.y or cy)
            if rcol == col and rrow == row then
                return false
            end
        end

        if snakeSafeZone and isTileInSafeZone(snakeSafeZone, col, row) then
            return false
        end

        if snakeSegments then
            for _, seg in ipairs(snakeSegments) do
                local dx = math.abs((seg.drawX or 0) - cx)
                local dy = math.abs((seg.drawY or 0) - cy)
                if dx < halfThreshold and dy < halfThreshold then
                    return false
                end
            end
        end

        if headX and headY then
            if distanceSquared(cx, cy, headX, headY) < minHeadDistanceSq then
                return false
            end
        end

        return true
    end

    local chosenCol, chosenRow
    for _ = 1, EXIT_SAFE_ATTEMPTS do
        local col, row = self:getRandomTile()
        if tileIsSafe(col, row) then
            chosenCol, chosenRow = col, row
            break
        end
    end

    if not (chosenCol and chosenRow) then
        for row = 2, self.rows - 1 do
            for col = 2, self.cols - 1 do
                if tileIsSafe(col, row) then
                    chosenCol, chosenRow = col, row
                    break
                end
            end
            if chosenCol then break end
        end
    end

    chosenCol = chosenCol or math.floor(self.cols / 2)
    chosenRow = chosenRow or math.floor(self.rows / 2)

    if SnakeUtils and SnakeUtils.setOccupied then
        SnakeUtils.setOccupied(chosenCol, chosenRow, true)
    end

    local x, y = self:getCenterOfTile(chosenCol, chosenRow)
    local size = self.tileSize * 0.75
    self.exit = {
        x = x, y = y,
        size = size,
        anim = 0,                -- 0 = closed, 1 = fully open
        animTime = 0.4,          -- seconds to open
        col = chosenCol,
        row = chosenRow,
        time = 0,
    }
    Audio:playSound("exit_spawn")
end

function Arena:getExitCenter()
    if not self.exit then return nil, nil, 0 end
    local r = self.exit.size * 0.5
    return self.exit.x, self.exit.y, r
end

function Arena:hasExit()
    return self.exit ~= nil
end

function Arena:update(dt)
    if not self.exit then
        return
    end

    if self.exit.anim < 1 then
        self.exit.anim = math.min(1, self.exit.anim + dt / self.exit.animTime)
    end

    self.exit.time = (self.exit.time or 0) + dt
end

-- Reset/clear exit when moving to next floor
function Arena:resetExit()
    if self.exit then
        local SnakeUtils = getModule("snakeutils")
        if SnakeUtils and SnakeUtils.setOccupied and self.exit.col and self.exit.row then
            SnakeUtils.setOccupied(self.exit.col, self.exit.row, false)
        end
    end

    self.exit = nil
end

-- Check if snake head collides with the exit
function Arena:checkExitCollision(snakeX, snakeY)
    if not self.exit then return false end
    local dx, dy = snakeX - self.exit.x, snakeY - self.exit.y
    local distSq = dx * dx + dy * dy
    local r = self.exit.size * 0.5
    return distSq <= (r * r)
end

-- Draw the exit (if active)
function Arena:drawExit()
    if not self.exit then return end

    local exit = self.exit
    local t = exit.anim
    local eased = 1 - (1 - t) * (1 - t)
    local radius = (exit.size / 1.5) * eased
    local cx, cy = exit.x, exit.y
    local time = exit.time or 0

    local rimRadius = radius * (1.05 + 0.03 * math.sin(time * 1.3))
    love.graphics.setColor(0.16, 0.15, 0.19, 1)
    love.graphics.circle("fill", cx, cy, rimRadius, 48)

    love.graphics.setColor(0.10, 0.09, 0.12, 1)
    love.graphics.circle("fill", cx, cy, radius * 0.94, 48)

    love.graphics.setColor(0.06, 0.05, 0.07, 1)
    love.graphics.circle("fill", cx, cy, radius * (0.78 + 0.05 * math.sin(time * 2.1)), 48)

    love.graphics.setColor(0.0, 0.0, 0.0, 1)
    love.graphics.circle("fill", cx, cy, radius * (0.58 + 0.04 * math.sin(time * 1.7)), 48)

    love.graphics.setColor(0.22, 0.20, 0.24, 0.85 * eased)
    love.graphics.arc("fill", cx, cy, radius * 0.98, -math.pi * 0.65, -math.pi * 0.05, 32)

    love.graphics.setColor(0, 0, 0, 0.45 * eased)
    love.graphics.arc("fill", cx, cy, radius * 0.72, math.pi * 0.2, math.pi * 1.05, 32)

    love.graphics.setColor(0.04, 0.04, 0.05, 0.9 * eased)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, radius * 0.96, 48)
    love.graphics.setLineWidth(1)
end

return Arena
