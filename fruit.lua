local Particles = require("particles")
local SnakeUtils = require("snakeutils")
local Theme = require("theme")
local Arena = require("arena")

local fruitTypes = {
    {
        id = "apple",
        name = "Apple",
        color = Theme.appleColor,
        points = 1,
        weight = 70,
    },
    {
        id = "banana",
        name = "Banana",
        color = Theme.bananaColor,
        points = 3,
        weight = 20,
    },
    {
        id = "blueberry",
        name = "Blueberry",
        color = Theme.blueberryColor,
        points = 5,
        weight = 8,
    },
    {
        id = "goldenPear",
        name = "GoldenPear",
        color = Theme.goldenPearColor,
        points = 10,
        weight = 2,
    },
    {
        id = "dragonfruit",
        name = "Dragonfruit",
        color = Theme.dragonfruitColor,
        points = 50,
        weight = 0.2,
    },
}

local Fruit = {}

local SEGMENT_SIZE   = 24
local HITBOX_SIZE    = SEGMENT_SIZE - 1
Fruit.SEGMENT_SIZE   = SEGMENT_SIZE

-- Spawn / land tuning
local DROP_HEIGHT     = 40
local DROP_DURATION   = 0.30
local SQUASH_DURATION = 0.12
local WOBBLE_DURATION = 0.22

-- Fade-out when collected
local FADE_DURATION   = 0.20
local COLLECT_FX_DURATION = 0.45

-- Fruit styling
local SHADOW_OFFSET = 3
local OUTLINE_SIZE = 3

local function getHighlightColor(color)
    color = color or {1, 1, 1, 1}
    local r = math.min(1, color[1] * 1.2 + 0.08)
    local g = math.min(1, color[2] * 1.2 + 0.08)
    local b = math.min(1, color[3] * 1.2 + 0.08)
    local a = (color[4] or 1) * 0.75
    return {r, g, b, a}
end

-- State
local active = {
    x = 0, y = 0,
    alpha = 0,
    scaleX = 1, scaleY = 1,
    shadow = 0.5,
    offsetY = 0,
    type = fruitTypes[1],
    phase = "idle",
    timer = 0
}
local fading = nil
local fadeTimer = 0
local lastCollectedType = fruitTypes[1]
local collectFx = {}

-- Easing
local function clamp(a, lo, hi) if a < lo then return lo elseif a > hi then return hi else return a end end

local function easeOutQuad(t)  return 1 - (1 - t)^2 end
-- Helpers
local function chooseFruitType()
    local total = 0
    for _, f in ipairs(fruitTypes) do total = total + f.weight end
    local r, sum = love.math.random() * total, 0
    for _, f in ipairs(fruitTypes) do
        sum = sum + f.weight
        if r <= sum then return f end
    end
    return fruitTypes[1]
end

local function aabb(x1,y1,w1,h1, x2,y2,w2,h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and
           y1 < y2 + h2 and y1 + h1 > y2
end

function Fruit:spawn(trail, rocks, safeZone)
    local cx, cy, col, row = SnakeUtils.getSafeSpawn(trail, self, rocks, safeZone)
    if not cx then
        col, row = Arena:getRandomTile()
        cx, cy = Arena:getCenterOfTile(col, row)
    end

    active.x, active.y = cx, cy
    active.col, active.row = col, row
    active.type   = chooseFruitType()
    active.alpha  = 0
    active.scaleX = 0.8
    active.scaleY = 0.6
    active.shadow = 0.35
    active.offsetY= -DROP_HEIGHT
    active.phase  = "drop"
    active.timer  = 0

    if col and row then
        SnakeUtils.setOccupied(col, row, true)
    end
end

function Fruit:update(dt)
    if fading then
        fadeTimer = fadeTimer + dt
        local p = clamp(fadeTimer / FADE_DURATION, 0, 1)
        local e = easeOutQuad(p)
        fading.alpha = 1 - e
        fading.scaleX = 1 - 0.2 * e
        fading.scaleY = 1 - 0.2 * e
        if p >= 1 then fading = nil end
    end

    for i = #collectFx, 1, -1 do
        local fx = collectFx[i]
        fx.timer = fx.timer + dt
        fx.rotation = fx.rotation + dt * fx.spin
        if fx.timer >= fx.duration then
            table.remove(collectFx, i)
        end
    end

    active.timer = active.timer + dt

    if active.phase == "drop" then
        local t = clamp(active.timer / DROP_DURATION, 0, 1)
        active.offsetY = -DROP_HEIGHT * (1 - easeOutQuad(t))
        active.alpha   = easeOutQuad(t)
        active.scaleX  = 0.9 + 0.1 * t
        active.scaleY  = 0.7 + 0.3 * t
        active.shadow  = 0.35 + 0.65 * t

        if t >= 1 then
            local col = active.type.color or {1,1,1,1}
            Particles:spawnBurst(active.x, active.y, {
                count = love.math.random(6, 9),
                speed = 48,
                speedVariance = 36,
                life  = 0.35,
                size  = 3,
                color = {col[1], col[2], col[3], 1},
                spread= math.pi * 2,
                angleJitter = math.pi,
                drag = 2.2,
                gravity = 160,
                scaleMin = 0.55,
                scaleVariance = 0.65,
                fadeTo = 0,
            })
            active.phase = "squash"
            active.timer = 0
            active.offsetY = 0
        end
    elseif active.phase == "squash" then
        local t = clamp(active.timer / SQUASH_DURATION, 0, 1)
        active.scaleX = 1 + 0.25 * (1 - t)
        active.scaleY = 1 - 0.25 * (1 - t)
        active.shadow = 1.0
        if t >= 1 then
            active.phase = "wobble"
            active.timer = 0
            active.scaleX = 1.12
            active.scaleY = 0.88
        end
    elseif active.phase == "wobble" then
        local t = clamp(active.timer / WOBBLE_DURATION, 0, 1)
        local s = (1 - t)
        local k = math.sin(t * math.pi * 2.0) * 0.06 * s
        active.scaleX = 1 + k
        active.scaleY = 1 - k
        active.shadow = 1.0
        active.alpha  = 1.0
        if t >= 1 then
            active.phase = "idle"
            active.timer = 0
            active.scaleX, active.scaleY = 1, 1
            active.shadow = 1.0
        end
    end
end

function Fruit:checkCollisionWith(x, y, trail, rocks)
    if fading then return false end
    if active.phase == "inactive" then return false end

    local half = HITBOX_SIZE / 2
    if aabb(x - half, y - half, HITBOX_SIZE, HITBOX_SIZE,
            active.x - half, active.y - half, HITBOX_SIZE, HITBOX_SIZE) then
        lastCollectedType = active.type
        fading = {
            x = active.x,
            y = active.y,
            alpha = 1,
            scaleX = active.scaleX,
            scaleY = active.scaleY,
            shadow = active.shadow,
            type = active.type
        }
        fadeTimer = 0
        active.phase = "inactive"
        active.alpha = 0

        local fxColor = getHighlightColor(active.type.color)
        collectFx[#collectFx + 1] = {
            x = active.x,
            y = active.y,
            color = fxColor,
            timer = 0,
            duration = COLLECT_FX_DURATION,
            rotation = love.math.random() * math.pi * 2,
            spin = love.math.random() * 1.4 + 0.6,
            spokes = love.math.random(5, 7),
        }

        Particles:spawnBurst(active.x, active.y, {
            count = love.math.random(10, 14),
            speed = 120,
            speedVariance = 90,
            life = 0.45,
            size = 3.2,
            color = {fxColor[1], fxColor[2], fxColor[3], 0.95},
            spread = math.pi * 2,
            drag = 2.7,
            gravity = -60,
            fadeTo = 0,
        })
        return true
    end
    return false
end

local function drawFruit(f)
    if f.phase == "inactive" then return end

    local x, y = f.x, f.y + (f.offsetY or 0)
    local alpha = f.alpha or 1
    local sx, sy = f.scaleX or 1, f.scaleY or 1
    local r = HITBOX_SIZE / 2
	local segments = 32

    -- drop shadow
    love.graphics.setColor(0, 0, 0, 0.25 * alpha)
    love.graphics.ellipse("fill", x + SHADOW_OFFSET, y + SHADOW_OFFSET, r * sx + OUTLINE_SIZE * 0.5, r * sy + OUTLINE_SIZE * 0.5, segments)

    -- fruit body
    love.graphics.setColor(f.type.color[1], f.type.color[2], f.type.color[3], alpha)
    love.graphics.ellipse("fill", x, y, r * sx, r * sy)

    -- highlight
    local highlight = getHighlightColor(f.type.color)
    local hx = x - r * sx * 0.3
    local hy = y - r * sy * 0.35
    local hrx = r * sx * 0.55
    local hry = r * sy * 0.45
    love.graphics.push()
    love.graphics.translate(hx, hy)
    love.graphics.rotate(-0.35)
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * alpha)
    love.graphics.ellipse("fill", 0, 0, hrx, hry)
    love.graphics.pop()

    -- outline (2–3px black border)
    love.graphics.setLineWidth(OUTLINE_SIZE)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.ellipse("line", x, y, r * sx, r * sy)

    -- subtle spawn glow
    if (f == active) and (active.phase ~= "idle") then
        local glow = 0.18 * alpha
        local gx = (HITBOX_SIZE * math.max(sx, sy)) * 0.65
        love.graphics.setColor(1, 1, 1, glow)
        love.graphics.circle("fill", x, y, gx)
    end

    -- rare fruit flair
    if f.type.name == "Dragonfruit" and f == active then
        local t = (active.timer or 0)
        local pulse = 0.5 + 0.5 * math.sin(t * 6.0)
        love.graphics.setColor(1, 0, 1, 0.15 * pulse * alpha)
        love.graphics.circle("line", x, y, HITBOX_SIZE * 0.8 + pulse * 4)
    end
end

local function drawCollectFx()
    if #collectFx == 0 then return end

    local lg = love.graphics
    for _, fx in ipairs(collectFx) do
        local progress = clamp(fx.timer / fx.duration, 0, 1)
        local fade = 1 - progress
        local eased = easeOutQuad(progress)
        local alpha = fade * fade

        local radius = HITBOX_SIZE * 0.5 + eased * 22
        local inner = radius * 0.45

        lg.setColor(fx.color[1], fx.color[2], fx.color[3], 0.18 * alpha)
        lg.circle("fill", fx.x, fx.y, radius * 0.9)

        lg.setLineWidth(3)
        lg.setColor(fx.color[1], fx.color[2], fx.color[3], 0.7 * alpha)
        lg.circle("line", fx.x, fx.y, radius)

        lg.setColor(1, 1, 1, 0.55 * alpha)
        for i = 1, fx.spokes do
            local angle = fx.rotation + (i - 1) * (math.pi * 2 / fx.spokes)
            local sx = fx.x + math.cos(angle) * inner
            local sy = fx.y + math.sin(angle) * inner
            local ex = fx.x + math.cos(angle) * (inner + 10 + eased * 18)
            local ey = fx.y + math.sin(angle) * (inner + 10 + eased * 18)
            lg.line(sx, sy, ex, ey)
        end
    end

    lg.setLineWidth(1)
    lg.setColor(1, 1, 1, 1)
end

function Fruit:draw()
    if fading and fading.alpha > 0 then
        drawFruit(fading)
    end
    drawFruit(active)
    drawCollectFx()
end

-- Queries
function Fruit:getPosition() return active.x, active.y end
function Fruit:getPoints()   return lastCollectedType.points or 1 end
function Fruit:getTypeName() return lastCollectedType.name or "Apple" end
function Fruit:getType()     return lastCollectedType end
function Fruit:getTile()     return active.col, active.row end

return Fruit
