local Theme = require("theme")
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
    local col, row = self:getRandomTile()
    local x, y = self:getCenterOfTile(col, row)
    local size = self.tileSize * 0.75
    self.exit = {
        x = x, y = y,
        size = size,
        anim = 0,                -- 0 = closed, 1 = fully open
        animTime = 0.4           -- seconds to open
    }
end

function Arena:getExitCenter()
    if not self.exit then return nil, nil, 0 end
    local r = self.exit.size * 0.5
    return self.exit.x, self.exit.y, r
end

function Arena:update(dt)
    if self.exit and self.exit.anim < 1 then
        self.exit.anim = math.min(1, self.exit.anim + dt / self.exit.animTime)
    end
end

-- Reset/clear exit when moving to next floor
function Arena:resetExit()
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

    -- ease-out growth
    local t = self.exit.anim
    local eased = 1 - (1 - t) * (1 - t) -- quadratic ease-out
    local r = (self.exit.size / 1.5) * eased

    -- fill
    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.circle("fill", self.exit.x, self.exit.y, r)

    -- outline
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.exit.x, self.exit.y, r)
end

return Arena