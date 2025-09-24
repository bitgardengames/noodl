local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local DrawSnake = require("snakedraw")

local Snake = {}

local screenW, screenH
local direction = { x = 1, y = 0 }
local pendingDir = { x = 1, y = 0 }
local trail = {}
local segmentCount = 1
local reverseControls = false
local popTimer = 0
local isDead = false

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
local moveTimer = 0
local POP_DURATION = SnakeUtils.POP_DURATION
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
-- movement baseline + modifiers
Snake.baseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.speedMult   = 1.0 -- stackable multiplier (upgrade-friendly)
Snake.crashShields = 0 -- crash protection: number of hits the snake can absorb

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
        -- optional: spawn particle / sound feedback here
        return true
    end
    return false
end

function Snake:resetModifiers()
    self.speedMult    = 1.0
    self.crashShields = 0
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
    trail = buildInitialTrail()
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
    local visible = {}
    for _, seg in ipairs(trail) do
        local dx, dy = seg.drawX - hx, seg.drawY - hy
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < hr then
            break
        end

        visible[#visible + 1] = {
            drawX = seg.drawX,
            drawY = seg.drawY,
            dirX = seg.dirX,
            dirY = seg.dirY
        }
    end

    if #visible == 0 then
        return
    end

    love.graphics.push("all")
    DrawSnake(visible, math.min(segmentCount, #visible), SEGMENT_SIZE, popTimer, function()
        return self:getHead()
    end)
    love.graphics.pop()
end

function Snake:update(dt)
    if isDead then return false end

    -- base speed with upgrades/modifiers
    local head = trail[1]
    local speed = self:getSpeed()

    -- adrenaline boost check
    if self.adrenaline and self.adrenaline.active then
        speed = speed * self.adrenaline.boost
        self.adrenaline.timer = self.adrenaline.timer - dt
        if self.adrenaline.timer <= 0 then
            self.adrenaline.active = false
        end
    end

    local newX = head.drawX + direction.x * speed * dt
    local newY = head.drawY + direction.y * speed * dt

    -- advance cell clock, maybe snap & commit queued direction
    local snappedThisTick = false
    local moveInterval
    if speed > 0 then
        moveInterval = SEGMENT_SPACING / speed
    end

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

    local maxLen = segmentCount * SEGMENT_SPACING
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

    return true
end

function Snake:updateReverseState(reversed)
    if reversed ~= self.reverseState then
        self:setReverseControls(reversed)
        self.reverseState = reversed
    end
end

function Snake:grow()
    segmentCount = segmentCount + 1
    popTimer = POP_DURATION
end

function Snake:draw()
    if not isDead then
        DrawSnake(trail, segmentCount, SEGMENT_SIZE, popTimer, function()
            return self:getHead()
        end)
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
