--[[
    snakeactor.lua
    ----------------
    Lightweight actor module for drawing Noodl outside of gameplay. It wraps
    the existing snakedraw renderer with a deterministic path follower so that
    menus, cutscenes, and other UI scenes can place an animated snake without
    spinning up the full game state.

    Usage example:

        local SnakeActor = require("snakeactor")
        local noodl = SnakeActor:new({
            x = 480,
            y = 300,
            radiusX = 180,
            radiusY = 110,
            speed = 140,
        })

        function love.update(dt)
            noodl:update(dt)
        end

        function love.draw()
            noodl:draw()
        end

    Provide your own path points to steer the actor through a bespoke cutscene
    camera move, or rely on the default elliptical idle loop shown above.
]]

local DrawSnake = require("snakedraw")

local SEGMENT_SIZE = 24
local SEGMENT_SPACING = SEGMENT_SIZE

local ok, snakeUtils = pcall(require, "snakeutils")
if ok and type(snakeUtils) == "table" then
    SEGMENT_SIZE = snakeUtils.SEGMENT_SIZE or SEGMENT_SIZE
    SEGMENT_SPACING = snakeUtils.SEGMENT_SPACING or SEGMENT_SPACING
end

local DEFAULTS = {
    segmentCount = 14,
    speed = 110,
    wiggleAmplitude = 0,
    wiggleFrequency = 0,
    wiggleStride = 0,
    loop = true,
    defaultPathPoints = 28,
}

local SnakeActor = {}
SnakeActor.__index = SnakeActor

local function resolvePoint(point)
    if type(point) == "table" then
        local x = point.x or point[1] or 0
        local y = point.y or point[2] or 0
        return x, y
    end

    return 0, 0
end

local function appendSegment(segments, ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local length = math.sqrt(dx * dx + dy * dy)

    if length <= 0.0001 then
        return 0
    end

    segments[#segments + 1] = {
        ax = ax,
        ay = ay,
        bx = bx,
        by = by,
        dx = dx,
        dy = dy,
        length = length,
        dirx = dx / length,
        diry = dy / length,
    }

    return length
end

local function nearlyEqual(a, b, epsilon)
    epsilon = epsilon or 0.0001
    return math.abs(a - b) <= epsilon
end

local function pushPoint(points, x, y)
    local last = points[#points]
    if not last or not (nearlyEqual(last[1], x) and nearlyEqual(last[2], y)) then
        points[#points + 1] = { x, y }
    end
end

local function appendOrthogonalSegments(accumulatedPoints, segments, ax, ay, bx, by)
    if nearlyEqual(ax, bx) and nearlyEqual(ay, by) then
        return 0
    end

    if nearlyEqual(ax, bx) or nearlyEqual(ay, by) then
        pushPoint(accumulatedPoints, ax, ay)
        pushPoint(accumulatedPoints, bx, by)
        return appendSegment(segments, ax, ay, bx, by)
    end

    local horizontalFirst = math.abs(bx - ax) >= math.abs(by - ay)
    local midX, midY
    if horizontalFirst then
        midX, midY = bx, ay
    else
        midX, midY = ax, by
    end

    local total = appendOrthogonalSegments(accumulatedPoints, segments, ax, ay, midX, midY)
    total = total + appendOrthogonalSegments(accumulatedPoints, segments, midX, midY, bx, by)
    return total
end

local function buildPath(points, options)
    options = options or {}
    local offsetX = options.offsetX or 0
    local offsetY = options.offsetY or 0
    local loop = options.loop

    local resolved = {}
    for i = 1, #points do
        local px, py = resolvePoint(points[i])
        resolved[i] = { px + offsetX, py + offsetY }
    end

    local segments = {}
    local totalLength = 0

    local expanded = {}

    for i = 1, #resolved - 1 do
        local ax, ay = resolved[i][1], resolved[i][2]
        local bx, by = resolved[i + 1][1], resolved[i + 1][2]
        totalLength = totalLength + appendOrthogonalSegments(expanded, segments, ax, ay, bx, by)
    end

    if loop and #resolved >= 2 then
        local ax, ay = resolved[#resolved][1], resolved[#resolved][2]
        local bx, by = resolved[1][1], resolved[1][2]
        totalLength = totalLength + appendOrthogonalSegments(expanded, segments, ax, ay, bx, by)
    end

    if #expanded == 0 then
        expanded = resolved
    end

    local originX, originY = 0, 0
    if expanded[1] then
        originX, originY = expanded[1][1], expanded[1][2]
    end

    return {
        points = expanded,
        segments = segments,
        length = totalLength,
        loop = loop,
        originX = originX,
        originY = originY,
    }
end

local function buildDefaultLoop(options)
    options = options or {}

    local cx = options.x or options.anchorX or 0
    local cy = options.y or options.anchorY or 0
    local radiusX = options.radiusX or options.radius or SEGMENT_SIZE * 6.5
    local radiusY = options.radiusY or (radiusX * 0.55)
    local desiredSegments = math.max(4, options.defaultPathPoints or DEFAULTS.defaultPathPoints)

    local perSide = math.max(1, math.floor(desiredSegments / 4))
    local remainder = desiredSegments - perSide * 4
    local steps = { perSide, perSide, perSide, perSide }
    for i = 1, remainder do
        local index = ((i - 1) % 4) + 1
        steps[index] = steps[index] + 1
    end

    local left = cx - radiusX
    local right = cx + radiusX
    local top = cy - radiusY
    local bottom = cy + radiusY

    local points = {}
    local currentX, currentY = left, top
    points[#points + 1] = { currentX, currentY }

    local function addAlong(dx, dy, count)
        if count <= 0 then
            return
        end

        local stepX = dx / count
        local stepY = dy / count
        for _ = 1, count do
            currentX = currentX + stepX
            currentY = currentY + stepY
            points[#points + 1] = { currentX, currentY }
        end
    end

    addAlong(right - left, 0, steps[1])
    addAlong(0, bottom - top, steps[2])
    addAlong(left - right, 0, steps[3])
    addAlong(0, top - bottom, steps[4])

    return points
end

local function samplePath(path, distance)
    local segments = path and path.segments
    if not segments or #segments == 0 then
        return path and path.originX or 0, path and path.originY or 0, 1, 0
    end

    local total = path.length or 0
    if total <= 0 then
        local seg = segments[1]
        return seg.ax, seg.ay, seg.dirx, seg.diry
    end

    local loop = path.loop
    local dist = distance or 0

    if loop then
        dist = dist % total
        if dist < 0 then
            dist = dist + total
        end
    else
        if dist <= 0 then
            local seg = segments[1]
            return seg.ax, seg.ay, seg.dirx, seg.diry
        end
        if dist >= total then
            local seg = segments[#segments]
            return seg.bx, seg.by, seg.dirx, seg.diry
        end
    end

    local remaining = dist
    for i = 1, #segments do
        local seg = segments[i]
        local length = seg.length
        if remaining <= length then
            local t = (length > 0) and (remaining / length) or 0
            local x = seg.ax + seg.dx * t
            local y = seg.ay + seg.dy * t
            return x, y, seg.dirx, seg.diry
        end
        remaining = remaining - length
    end

    local seg = segments[#segments]
    return seg.bx, seg.by, seg.dirx, seg.diry
end

local function computeWiggleOffset(actor, distance, dirx, diry)
    local amplitude = actor.wiggleAmplitude or 0
    if amplitude == 0 then
        return 0, 0
    end

    local spacing = actor.segmentSpacing
    if not spacing or spacing <= 0 then
        spacing = SEGMENT_SPACING
    end

    dirx = dirx or 1
    diry = diry or 0

    local normalX = -diry
    local normalY = dirx
    local phase = (actor.time or 0) * (actor.wiggleFrequency or 0) + (distance / spacing) * (actor.wiggleStride or 0)
    local offset = math.sin(phase) * amplitude
    return normalX * offset, normalY * offset
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function SnakeActor:new(options)
    options = options or {}

    local actor = setmetatable({}, self)

    actor.segmentSize = options.segmentSize or SEGMENT_SIZE
    actor.segmentSpacing = options.segmentSpacing or SEGMENT_SPACING
    if actor.segmentSpacing <= 0 then
        actor.segmentSpacing = SEGMENT_SPACING
    end

    actor.segmentCount = math.max(1, math.floor(options.segmentCount or options.length or DEFAULTS.segmentCount))
    actor.speed = options.speed or DEFAULTS.speed
    actor.wiggleAmplitude = 0
    actor.wiggleFrequency = 0
    actor.wiggleStride = 0
    actor.drawFace = options.drawFace ~= false
    actor.popTimer = options.popTimer or 0
    actor.shieldCount = options.shieldCount or 0
    actor.shieldFlashTimer = options.shieldFlashTimer or 0
    actor.upgradeVisuals = options.upgradeVisuals
    actor.time = options.timeOffset or 0
    actor.loopPath = options.loop
    if actor.loopPath == nil then
        actor.loopPath = DEFAULTS.loop
    end

    actor.pathOffsetX = options.offsetX or 0
    actor.pathOffsetY = options.offsetY or 0

    local pathPoints = options.path
    if not pathPoints then
        pathPoints = buildDefaultLoop(options)
        actor.loopPath = true
    end

    actor.path = buildPath(pathPoints, {
        offsetX = actor.pathOffsetX,
        offsetY = actor.pathOffsetY,
        loop = actor.loopPath,
    })

    actor.trail = {}
    actor.headDistance = options.startDistance or 0
    local length = actor.path.length or 0
    if actor.loopPath and length > 0 then
        actor.headDistance = actor.headDistance % length
    else
        actor.headDistance = clamp(actor.headDistance, 0, length)
    end

    actor:refreshTrail(true)

    return actor
end

function SnakeActor:setPath(points, options)
    options = options or {}

    local loop = options.loop
    if loop == nil then
        loop = self.loopPath
    end
    if loop == nil then
        loop = false
    end
    self.loopPath = loop

    self.pathOffsetX = options.offsetX or self.pathOffsetX or 0
    self.pathOffsetY = options.offsetY or self.pathOffsetY or 0

    self.path = buildPath(points, {
        offsetX = self.pathOffsetX,
        offsetY = self.pathOffsetY,
        loop = self.loopPath,
    })

    local total = self.path.length or 0
    self.headDistance = options.startDistance or self.headDistance or 0
    if self.loopPath and total > 0 then
        self.headDistance = self.headDistance % total
    else
        self.headDistance = clamp(self.headDistance, 0, total)
    end

    self:refreshTrail(true)
end

function SnakeActor:setOffset(x, y)
    x = x or 0
    y = y or 0
    local dx = x - (self.pathOffsetX or 0)
    local dy = y - (self.pathOffsetY or 0)
    if dx == 0 and dy == 0 then
        return
    end

    self.pathOffsetX = x
    self.pathOffsetY = y

    local path = self.path
    if not path then
        return
    end

    for _, point in ipairs(path.points or {}) do
        point[1] = point[1] + dx
        point[2] = point[2] + dy
    end

    for _, seg in ipairs(path.segments or {}) do
        seg.ax = seg.ax + dx
        seg.ay = seg.ay + dy
        seg.bx = seg.bx + dx
        seg.by = seg.by + dy
    end

    path.originX = (path.originX or 0) + dx
    path.originY = (path.originY or 0) + dy

    self:refreshTrail(true)
end

function SnakeActor:setSpeed(speed)
    self.speed = speed or 0
end

function SnakeActor:setWiggle(amplitude, frequency, stride)
    self.wiggleAmplitude = 0
    self.wiggleFrequency = 0
    self.wiggleStride = 0
end

function SnakeActor:getHead()
    local head = self.trail and self.trail[1]
    if head and head.drawX and head.drawY then
        return head.drawX, head.drawY
    end
    return nil, nil
end

function SnakeActor:refreshTrail(force)
    if not self.path then
        return
    end

    local total = self.path.length or 0
    local loop = self.loopPath

    for i = 1, self.segmentCount do
        local offset = (i - 1) * self.segmentSpacing
        local dist = self.headDistance - offset
        if not loop then
            dist = clamp(dist, 0, total)
        end

        local x, y, dirx, diry = samplePath(self.path, dist)
        local wiggleX, wiggleY = computeWiggleOffset(self, dist, dirx, diry)

        local segment = self.trail[i]
        if not segment then
            segment = {}
            self.trail[i] = segment
        end

        segment.x = x
        segment.y = y
        segment.drawX = x + wiggleX
        segment.drawY = y + wiggleY
    end

    for i = self.segmentCount + 1, #self.trail do
        self.trail[i] = nil
    end
end

function SnakeActor:update(dt)
    dt = dt or 0
    self.time = (self.time or 0) + dt

    local move = (self.speed or 0) * dt
    if move ~= 0 and self.path then
        local total = self.path.length or 0
        if total <= 0 then
            self.headDistance = 0
        else
            self.headDistance = (self.headDistance or 0) + move
            if self.loopPath then
                self.headDistance = self.headDistance % total
                if self.headDistance < 0 then
                    self.headDistance = self.headDistance + total
                end
            else
                self.headDistance = clamp(self.headDistance, 0, total)
            end
        end
    end

    self:refreshTrail()

    if self.popTimer and self.popTimer > 0 then
        self.popTimer = math.max(0, self.popTimer - dt)
    end

    if self.shieldFlashTimer and self.shieldFlashTimer > 0 then
        self.shieldFlashTimer = math.max(0, self.shieldFlashTimer - dt)
    end
end

function SnakeActor:draw()
    if not self.trail or #self.trail == 0 then
        return
    end

    local function getHead()
        return self:getHead()
    end

    DrawSnake(
        self.trail,
        self.segmentCount,
        self.segmentSize,
        self.popTimer,
        getHead,
        self.shieldCount,
        self.shieldFlashTimer,
        self.upgradeVisuals,
        self.drawFace
    )
end

return SnakeActor
