local Theme = require("theme")

local Conveyors = {}

local belts = {}
local slots = {}
local slotLookup = {}
local nextSlotId = 0

local TRACK_LENGTH = 120
local BELT_THICKNESS = 24
local SPAWN_DURATION = 0.35
local SETTLE_DURATION = 0.3
local CHEVRON_SPACING = 22
local CHEVRON_SPEED = 14
local SHADOW_OFFSET = 4

local function colorLerp(color, factor)
    if not color then
        return {factor, factor, factor, 1}
    end

    return {
        math.min(1, math.max(0, color[1] * factor)),
        math.min(1, math.max(0, color[2] * factor)),
        math.min(1, math.max(0, color[3] * factor)),
        color[4] or 1,
    }
end

local function getPalette()
    local border = Theme.arenaBorder or {0.35, 0.65, 0.7, 1}
    local beltBase = colorLerp(border, 0.25)
    beltBase[4] = 1

    local highlight = colorLerp(border, 0.35)
    highlight[4] = 1

    local roller = Theme.sawColor or {0.85, 0.85, 0.85, 1}
    return {
        base = beltBase,
        highlight = highlight,
        patternDark = colorLerp(beltBase, 0.8),
        patternLight = colorLerp(highlight, 1.2),
        roller = roller,
        shadow = Theme.shadowColor or {0, 0, 0, 0.4},
    }
end

local function makeSlotKey(x, y, dir)
    return x .. ":" .. y .. ":" .. dir
end

local function getSlot(x, y, dir)
    dir = dir or "horizontal"
    local key = makeSlotKey(x, y, dir)
    local slot = slotLookup[key]

    if slot then
        return slot
    end

    nextSlotId = nextSlotId + 1
    slot = {
        id = nextSlotId,
        x = x,
        y = y,
        dir = dir,
    }

    slotLookup[key] = slot
    slots[#slots + 1] = slot
    return slot
end

function Conveyors:spawn(x, y, dir, length)
    dir = dir or "horizontal"
    length = length or TRACK_LENGTH

    -- Temporarily disable conveyor belt spawning by not creating new belt entries.
    -- Keep slot allocation intact in case other systems rely on slot bookkeeping.
    getSlot(x, y, dir)
end

function Conveyors:getAll()
    return belts
end

function Conveyors:reset()
    belts = {}
    slots = {}
    slotLookup = {}
    nextSlotId = 0
end

local function updateDrop(belt, dt)
    local progress = math.min(1, (belt.spawnTimer or 0) / SPAWN_DURATION)
    belt.spawnProgress = progress
    belt.dropOffset = -36 * (1 - progress)
    belt.shadowAlpha = progress * 0.7

    if progress >= 1 then
        belt.phase = "settle"
        belt.spawnTimer = 0
    end
end

local function updateSettle(belt, dt)
    local progress = math.min(1, (belt.spawnTimer or 0) / SETTLE_DURATION)
    local ease = math.sin(progress * math.pi)
    belt.dropOffset = -2 * (1 - progress)
    belt.rollerOffset = ease * 2.4
    belt.spawnProgress = 1
    belt.shadowAlpha = 0.7

    if progress >= 1 then
        belt.phase = "idle"
        belt.spawnTimer = 0
        belt.dropOffset = 0
        belt.rollerOffset = 0
    end
end

function Conveyors:update(dt)
    if dt <= 0 then return end

    for _, belt in ipairs(belts) do
        belt.spawnTimer = (belt.spawnTimer or 0) + dt

        if belt.phase == "drop" then
            updateDrop(belt, dt)
        elseif belt.phase == "settle" then
            updateSettle(belt, dt)
        else
            belt.dropOffset = 0
            belt.rollerOffset = belt.rollerOffset * 0.85
            belt.shadowAlpha = math.min(0.7, (belt.shadowAlpha or 0.7))
        end

        local speed = CHEVRON_SPEED
        if belt.dir == "horizontal" then
            belt.patternOffset = ((belt.patternOffset or 0) - dt * speed) % CHEVRON_SPACING
        else
            belt.patternOffset = ((belt.patternOffset or 0) + dt * speed) % CHEVRON_SPACING
        end
    end
end

local function drawChevronStrip(length, height, offset, colors)
    local start = -length / 2 - CHEVRON_SPACING * 2
    local finish = length / 2 + CHEVRON_SPACING * 2
    local yTop = -height / 2
    local yBottom = height / 2
    local dark = colors.patternDark
    local light = colors.patternLight

    for x = start, finish, CHEVRON_SPACING do
        local base = x + offset

        love.graphics.setColor(dark[1], dark[2], dark[3], 0.6)
        love.graphics.polygon("fill",
            base, yBottom,
            base + CHEVRON_SPACING * 0.5, yTop,
            base + CHEVRON_SPACING, yBottom
        )

        love.graphics.setColor(light[1], light[2], light[3], 0.5)
        love.graphics.polygon("fill",
            base + CHEVRON_SPACING * 0.5, yBottom,
            base + CHEVRON_SPACING, yTop,
            base + CHEVRON_SPACING * 1.5, yBottom
        )
    end
end

local function drawBelt(belt, colors)
    love.graphics.push()
    love.graphics.translate(belt.x or 0, (belt.y or 0) + (belt.dropOffset or 0))

    if belt.dir == "vertical" then
        love.graphics.rotate(math.pi / 2)
    end

    local length = belt.length or TRACK_LENGTH
    local targetThickness = belt.thickness or BELT_THICKNESS
    local thickness = math.max(2, targetThickness * (belt.spawnProgress or 0))
    local radius = thickness / 2

    -- Shadow
    local shadowAlpha = (colors.shadow[4] or 0.4) * (belt.shadowAlpha or 0)
    if shadowAlpha > 0 then
        local shadowOffsetX = SHADOW_OFFSET
        local shadowOffsetY = SHADOW_OFFSET

        if belt.dir == "vertical" then
            shadowOffsetX = SHADOW_OFFSET
            shadowOffsetY = -SHADOW_OFFSET
        end

        love.graphics.setColor(colors.shadow[1], colors.shadow[2], colors.shadow[3], shadowAlpha)
        love.graphics.rectangle(
            "fill",
            -length / 2 + shadowOffsetX,
            -thickness / 2 + shadowOffsetY,
            length,
            thickness,
            radius,
            radius
        )
    end

    love.graphics.setColor(colors.base[1], colors.base[2], colors.base[3], colors.base[4] or 1)
    love.graphics.rectangle("fill", -length / 2, -thickness / 2, length, thickness, radius, radius)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -length / 2, -thickness / 2, length, thickness, radius, radius)

    local inset = 4
    local innerHeight = math.max(2, thickness - inset * 2)
    local innerRadius = math.max(2, radius - inset * 0.75)

    love.graphics.setColor(colors.highlight[1], colors.highlight[2], colors.highlight[3], colors.highlight[4] or 1)
    love.graphics.rectangle("fill", -length / 2 + inset, -innerHeight / 2, length - inset * 2, innerHeight, innerRadius, innerRadius)

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", -length / 2 + inset, -innerHeight / 2, length - inset * 2, innerHeight, innerRadius, innerRadius)
    end, "replace", 1)

    love.graphics.setStencilTest("equal", 1)
    drawChevronStrip(length - inset * 2, innerHeight, belt.patternOffset or 0, colors)
    love.graphics.setStencilTest()

    local rollerRadius = math.min(targetThickness * 0.325, 9)
    local rollerOffset = length / 2 - rollerRadius - 3
    local rollerY = (belt.rollerOffset or 0)

    local function drawRoller(sign)
        love.graphics.push()
        love.graphics.translate(sign * rollerOffset, rollerY)
        love.graphics.setColor(colors.roller[1], colors.roller[2], colors.roller[3], colors.roller[4] or 1)
        love.graphics.circle("fill", 0, 0, rollerRadius)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", 0, 0, rollerRadius)
        local rollerHighlight = colorLerp(colors.roller, 1.2)
        love.graphics.setColor(rollerHighlight[1], rollerHighlight[2], rollerHighlight[3], rollerHighlight[4] or 1)
        love.graphics.circle("fill", 0, -rollerRadius * 0.35, rollerRadius * 0.35)
        love.graphics.pop()
    end

    drawRoller(-1)
    drawRoller(1)

    love.graphics.pop()
end

function Conveyors:draw()
    if #belts == 0 then
        return
    end

    local colors = getPalette()

    for _, belt in ipairs(belts) do
        drawBelt(belt, colors)
    end
end

return Conveyors
