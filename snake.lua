local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local DrawSnake = require("snakedraw")
local Rocks = require("rocks")
local Saws = require("saws")

local Snake = {}

local screenW, screenH
local direction = { x = 1, y = 0 }
local pendingDir = { x = 1, y = 0 }
local trail = {}
local descendingHole = nil
local segmentCount = 1
local reverseControls = false
local popTimer = 0
local isDead = false

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
local moveTimer = 0
local POP_DURATION = SnakeUtils.POP_DURATION
local SHIELD_FLASH_DURATION = 0.3
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
-- movement baseline + modifiers
Snake.baseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.speedMult   = 1.0 -- stackable multiplier (upgrade-friendly)
Snake.crashShields = 0 -- crash protection: number of hits the snake can absorb
Snake.extraGrowth = 0
Snake.shieldBurst = nil
Snake.shieldFlashTimer = 0

-- getters / mutators (safe API for upgrades)
function Snake:getSpeed()
    return (self.baseSpeed or 1) * (self.speedMult or 1)
end

function Snake:addSpeedMultiplier(mult)
    self.speedMult = (self.speedMult or 1) * (mult or 1)
end

function Snake:addCrashShields(n)
    n = n or 1
    self.crashShields = (self.crashShields or 0) + n
end

function Snake:consumeCrashShield()
    if (self.crashShields or 0) > 0 then
        self.crashShields = self.crashShields - 1
        self.shieldFlashTimer = SHIELD_FLASH_DURATION
        -- optional: spawn particle / sound feedback here
        return true
    end
    return false
end

function Snake:resetModifiers()
    self.speedMult    = 1.0
    self.crashShields = 0
    self.extraGrowth  = 0
    self.shieldBurst  = nil
    self.shieldFlashTimer = 0
    if self.adrenaline then
        self.adrenaline.active = false
        self.adrenaline.timer = 0
    end
end

function Snake:addShieldBurst(config)
    config = config or {}
    self.shieldBurst = self.shieldBurst or { rocks = 0, stall = 0 }
    local rocks = config.rocks or 0
    local stall = config.stall or 0
    if rocks ~= 0 then
        self.shieldBurst.rocks = (self.shieldBurst.rocks or 0) + rocks
    end
    if stall ~= 0 then
        local current = self.shieldBurst.stall or 0
        self.shieldBurst.stall = math.max(current, stall)
    end
end

function Snake:onShieldConsumed(x, y, cause)
    if self.shieldBurst then
        local rocksToBreak = math.floor(self.shieldBurst.rocks or 0)
        if rocksToBreak > 0 and Rocks and Rocks.shatterNearest then
            Rocks:shatterNearest(x or 0, y or 0, rocksToBreak)
        end

        local stallDuration = self.shieldBurst.stall or 0
        if stallDuration > 0 and Saws and Saws.stall then
            Saws:stall(stallDuration)
        end
    end

    local Upgrades = package.loaded["upgrades"]
    if Upgrades and Upgrades.notify then
        Upgrades:notify("shieldConsumed", {
            x = x,
            y = y,
            cause = cause or "unknown",
        })
    end
end

-- >>> Small integration note:
-- Inside your snake:update(dt) where you compute movement, replace any hard-coded speed use with:
-- local speed = Snake:getSpeed()
-- and then use `speed` for position updates. This gives upgrades an immediate effect.

-- helpers
local function snapToCenter(v)
    return (math.floor(v / SEGMENT_SPACING) + 0.5) * SEGMENT_SPACING
end

local function toCell(x, y)
    return math.floor(x / SEGMENT_SPACING + 0.5), math.floor(y / SEGMENT_SPACING + 0.5)
end

local function findCircleIntersection(px, py, qx, qy, cx, cy, radius)
    local dx = qx - px
    local dy = qy - py
    local fx = px - cx
    local fy = py - cy

    local a = dx * dx + dy * dy
    if a == 0 then
        return nil, nil
    end

    local b = 2 * (fx * dx + fy * dy)
    local c = fx * fx + fy * fy - radius * radius
    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return nil, nil
    end

    discriminant = math.sqrt(discriminant)
    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    local t
    if t1 >= 0 and t1 <= 1 then
        t = t1
    elseif t2 >= 0 and t2 <= 1 then
        t = t2
    end

    if not t then
        return nil, nil
    end

    return px + t * dx, py + t * dy
end

local function trimHoleSegments(hole)
    if not hole or not trail or #trail == 0 then
        return
    end

    local hx, hy = hole.x, hole.y
    local radius = hole.radius or 0
    if radius <= 0 then
        return
    end

    local radiusSq = radius * radius
    local consumed = hole.consumedLength or 0
    local lastInside = nil
    local removedAny = false
    local i = 1

    while i <= #trail do
        local seg = trail[i]
        local x = seg.drawX
        local y = seg.drawY

        if not (x and y) then
            break
        end

        local dx = x - hx
        local dy = y - hy
        if dx * dx + dy * dy <= radiusSq then
            removedAny = true
            lastInside = { x = x, y = y, dirX = seg.dirX, dirY = seg.dirY }

            local nextSeg = trail[i + 1]
            if nextSeg then
                local nx, ny = nextSeg.drawX, nextSeg.drawY
                if nx and ny then
                    local segDx = nx - x
                    local segDy = ny - y
                    consumed = consumed + math.sqrt(segDx * segDx + segDy * segDy)
                end
            end

            table.remove(trail, i)
        else
            break
        end
    end

    local newHead = trail[1]
    if removedAny and newHead and lastInside then
        local oldDx = newHead.drawX - lastInside.x
        local oldDy = newHead.drawY - lastInside.y
        local oldLen = math.sqrt(oldDx * oldDx + oldDy * oldDy)
        if oldLen > 0 then
            consumed = consumed - oldLen
        end

        local ix, iy = findCircleIntersection(lastInside.x, lastInside.y, newHead.drawX, newHead.drawY, hx, hy, radius)
        if ix and iy then
            local newDx = ix - lastInside.x
            local newDy = iy - lastInside.y
            local newLen = math.sqrt(newDx * newDx + newDy * newDy)
            consumed = consumed + newLen
            newHead.drawX = ix
            newHead.drawY = iy
        else
            -- fallback: if no intersection, clamp head to previous inside point
            newHead.drawX = lastInside.x
            newHead.drawY = lastInside.y
        end
    end

    hole.consumedLength = consumed
end

-- Build initial trail aligned to CELL CENTERS
local function buildInitialTrail()
    local t = {}
    local midCol = math.floor(Arena.cols / 2)
    local midRow = math.floor(Arena.rows / 2)
    local startX, startY = Arena:getCenterOfTile(midCol, midRow)

    for i = 0, segmentCount - 1 do
        local cx = startX - i * SEGMENT_SPACING * direction.x
        local cy = startY - i * SEGMENT_SPACING * direction.y
        table.insert(t, {
            drawX = cx, drawY = cy,
            dirX = direction.x, dirY = direction.y
        })
    end
    return t
end

function Snake:load(w, h)
    screenW, screenH = w, h
    direction = { x = 1, y = 0 }
    pendingDir = { x = 1, y = 0 }
    segmentCount = 1
    reverseControls = false
    popTimer = 0
    moveTimer = 0
    isDead = false
    self.reverseState = false
    self.shieldFlashTimer = 0
    trail = buildInitialTrail()
    descendingHole = nil
end

function Snake:setReverseControls(state)
    reverseControls = state
end

function Snake:setDirection(name)
    if not isDead then
        pendingDir = SnakeUtils.calculateDirection(direction, name, reverseControls)
    end
end

function Snake:getDirection()
    return direction
end

function Snake:getHead()
    local head = trail[1]
    if not head then
        return nil, nil
    end
    return head.drawX, head.drawY
end

function Snake:setHeadPosition(x, y)
    local head = trail[1]
    if not head then
        return
    end

    head.drawX = x
    head.drawY = y
end

local function normalizeDirection(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        return 0, 0
    end
    return dx / len, dy / len
end

function Snake:setDirectionVector(dx, dy)
    if isDead then return end

    dx = dx or 0
    dy = dy or 0

    local nx, ny = normalizeDirection(dx, dy)
    if nx == 0 and ny == 0 then
        return
    end

    direction = { x = nx, y = ny }
    pendingDir = { x = nx, y = ny }
end

function Snake:getHeadCell()
    local hx, hy = self:getHead()
    if not (hx and hy) then
        return nil, nil
    end
    return toCell(hx, hy)
end

function Snake:getSafeZone(lookahead)
    local hx, hy = self:getHeadCell()
    if not (hx and hy) then
        return {}
    end
    local dir = self:getDirection()
    local cells = {}

    for i = 1, lookahead do
        local cx = hx + dir.x * i
        local cy = hy + dir.y * i
        table.insert(cells, {cx, cy})
    end

    return cells
end

function Snake:drawClipped(hx, hy, hr)
    if not trail or #trail == 0 then
        return
    end

    local headX, headY = self:getHead()
    local clipRadius = hr or 0
    local renderTrail = trail

    if clipRadius > 0 then
        local radiusSq = clipRadius * clipRadius

        local trimmed = {}

        for i = 1, #trail do
            local seg = trail[i]
            local x = seg.drawX or seg.x
            local y = seg.drawY or seg.y

            if x and y then
                local dx = x - hx
                local dy = y - hy
                if dx * dx + dy * dy <= radiusSq then
                    if i > 1 then
                        local prev = trail[i - 1]
                        local px = prev.drawX or prev.x
                        local py = prev.drawY or prev.y
                        if px and py then
                            local ix, iy = findCircleIntersection(px, py, x, y, hx, hy, clipRadius)
                            if ix and iy then
                                trimmed[#trimmed + 1] = { drawX = ix, drawY = iy }
                            end
                        end
                    end
                    renderTrail = trimmed
                    break
                end
            end

            trimmed[#trimmed + 1] = seg
            renderTrail = trimmed
        end
    end

    love.graphics.push("all")

    if clipRadius > 0 then
        love.graphics.stencil(function()
            love.graphics.circle("fill", hx, hy, clipRadius)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 0)
    end

    DrawSnake(renderTrail, segmentCount, SEGMENT_SIZE, popTimer, function()
        if headX and headY and clipRadius > 0 then
            local dx = headX - hx
            local dy = headY - hy
            if dx * dx + dy * dy < clipRadius * clipRadius then
                return nil, nil
            end
        end
        return headX, headY
    end, self.crashShields or 0, self.shieldFlashTimer or 0)

    love.graphics.setStencilTest()
    love.graphics.pop()
end

function Snake:startDescending(hx, hy, hr)
    descendingHole = {
        x = hx,
        y = hy,
        radius = hr or 0
    }
end

function Snake:finishDescending()
    descendingHole = nil
end

function Snake:update(dt)
    if isDead then return false end

    -- base speed with upgrades/modifiers
    local head = trail[1]
    local speed = self:getSpeed()

    local hole = descendingHole
    if hole and head then
        local dx = hole.x - head.drawX
        local dy = hole.y - head.drawY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 1e-4 then
            local nx, ny = dx / dist, dy / dist
            direction = { x = nx, y = ny }
            pendingDir = { x = nx, y = ny }
        end
    end

    -- adrenaline boost check
    if self.adrenaline and self.adrenaline.active then
        speed = speed * self.adrenaline.boost
        self.adrenaline.timer = self.adrenaline.timer - dt
        if self.adrenaline.timer <= 0 then
            self.adrenaline.active = false
        end
    end

    local stepX = direction.x * speed * dt
    local stepY = direction.y * speed * dt
    local newX = head.drawX + stepX
    local newY = head.drawY + stepY

    -- advance cell clock, maybe snap & commit queued direction
    local snappedThisTick = false
    local moveInterval
    if speed > 0 and not hole then
        moveInterval = SEGMENT_SPACING / speed
    end

    if hole then
        moveTimer = 0
    else
        moveTimer = moveTimer + dt
        local snaps = 0
        while moveInterval and moveTimer >= moveInterval do
            moveTimer = moveTimer - moveInterval
            snaps = snaps + 1
        end
        if snaps > 0 then
            -- snap to the nearest grid center
            newX = snapToCenter(newX)
            newY = snapToCenter(newY)
            -- commit queued direction
            direction = { x = pendingDir.x, y = pendingDir.y }
            snappedThisTick = true
        end
    end

    -- spatially uniform sampling along the motion path
    local dx = newX - head.drawX
    local dy = newY - head.drawY
    local dist = math.sqrt(dx*dx + dy*dy)

    local nx, ny = 0, 0
    if dist > 0 then
        nx, ny = dx / dist, dy / dist
    end

    local remaining = dist
    local prevX, prevY = head.drawX, head.drawY

    while remaining >= SAMPLE_STEP do
        prevX = prevX + nx * SAMPLE_STEP
        prevY = prevY + ny * SAMPLE_STEP
        table.insert(trail, 1, {
            drawX = prevX,
            drawY = prevY,
            dirX  = direction.x,
            dirY  = direction.y
        })
        remaining = remaining - SAMPLE_STEP
    end

    -- final correction: put true head at exact new position
    if trail[1] then
        trail[1].drawX = newX
        trail[1].drawY = newY
    end

    if hole then
        trimHoleSegments(hole)
        head = trail[1]
        if head then
            newX, newY = head.drawX, head.drawY
        end
    end

    -- tail trimming
    local tailBeforeX, tailBeforeY = nil, nil
    local len = #trail
    if len > 0 then
        tailBeforeX, tailBeforeY = trail[len].drawX, trail[len].drawY
    end
    local tailBeforeCol, tailBeforeRow
    if tailBeforeX and tailBeforeY then
        tailBeforeCol, tailBeforeRow = toCell(tailBeforeX, tailBeforeY)
    end

    local consumedLength = (hole and hole.consumedLength) or 0
    local maxLen = math.max(0, segmentCount * SEGMENT_SPACING - consumedLength)

    if maxLen == 0 then
        trail = {}
        len = 0
    end

    local traveled = 0
    for i = 2, #trail do
        local dx = trail[i-1].drawX - trail[i].drawX
        local dy = trail[i-1].drawY - trail[i].drawY
        local segLen = math.sqrt(dx*dx + dy*dy)

        if traveled + segLen > maxLen then
            local excess = traveled + segLen - maxLen
            local t = 1 - (excess / segLen)
            local tailX = trail[i-1].drawX - dx * t
            local tailY = trail[i-1].drawY - dy * t

            for j = #trail, i+1, -1 do
                table.remove(trail, j)
            end

            trail[i].drawX, trail[i].drawY = tailX, tailY
            break
        else
            traveled = traveled + segLen
        end
    end

    -- collision with self (grid-cell based, only at snap ticks)
        if snappedThisTick then
                local hx, hy = trail[1].drawX, trail[1].drawY
                local headCol, headRow = toCell(hx, hy)

		-- Don’t check the first ~1 segment of body behind the head (neck).
		-- Compute by *distance*, not “skip N nodes”.
		local guardDist = SEGMENT_SPACING * 1.05  -- about one full cell
		local walked = 0

		local function seglen(i)
			local dx = trail[i-1].drawX - trail[i].drawX
			local dy = trail[i-1].drawY - trail[i].drawY
			return math.sqrt(dx*dx + dy*dy)
		end

		-- advance 'walked' until we’re past the neck
		local startIndex = 2
		while startIndex < #trail and walked < guardDist do
			walked = walked + seglen(startIndex)
			startIndex = startIndex + 1
		end

		-- If tail vacated the head cell this tick, don’t count that as a hit
		local tailBeforeCol, tailBeforeRow = nil, nil
		do
			local len = #trail
			if len >= 1 then
				local tbx, tby = trail[len].drawX, trail[len].drawY
				if tbx and tby then
					tailBeforeCol, tailBeforeRow = toCell(tbx, tby)
				end
			end
		end

		for i = startIndex, #trail do
			local cx, cy = toCell(trail[i].drawX, trail[i].drawY)

			-- allow stepping into the tail cell if the tail moved off this tick
			local tailVacated =
				(i == #trail) and (tailBeforeCol == headCol and tailBeforeRow == headRow)

			if not tailVacated and cx == headCol and cy == headRow then
                                if self:consumeCrashShield() then
                                        -- survived; optional FX here
                                        self:onShieldConsumed(hx, hy, "self")
                                else
                                        isDead = true
                                        return false, "self"
                                end
			end
		end
	end

    -- update timers
    if popTimer > 0 then
        popTimer = math.max(0, popTimer - dt)
    end

    if self.shieldFlashTimer and self.shieldFlashTimer > 0 then
        self.shieldFlashTimer = math.max(0, self.shieldFlashTimer - dt)
    end

    return true
end

function Snake:updateReverseState(reversed)
    if reversed ~= self.reverseState then
        self:setReverseControls(reversed)
        self.reverseState = reversed
    end
end

function Snake:grow()
    local bonus = self.extraGrowth or 0
    segmentCount = segmentCount + 1 + bonus
    popTimer = POP_DURATION
end

function Snake:draw()
    if not isDead then
        DrawSnake(trail, segmentCount, SEGMENT_SIZE, popTimer, function()
            return self:getHead()
        end, self.crashShields or 0, self.shieldFlashTimer or 0)
    end
end

function Snake:resetPosition()
    self:load(screenW, screenH)
end

function Snake:getSegments()
    local copy = {}
    for i = 1, #trail do
        local seg = trail[i]
        copy[i] = {
            drawX = seg.drawX,
            drawY = seg.drawY,
            dirX = seg.dirX,
            dirY = seg.dirY
        }
    end
    return copy
end

function Snake:isDead()
    return isDead
end

function Snake:getLength()
    return segmentCount
end

return Snake
