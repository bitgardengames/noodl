local Particles = require("particles")
local SnakeUtils = require("snakeutils")
local Theme = require("theme")
local Arena = require("arena")

local fruitTypes = {
    {name = "Apple", color = Theme.appleColor, points = 1,  weight = 70},
    {name = "Banana", color = Theme.bananaColor, points = 3,  weight = 20},
    {name = "Blueberry", color = Theme.blueberryColor,  points = 5,  weight = 8},
    {name = "GoldenPear", color = Theme.goldenPearColor, points = 10, weight = 2},
    {name = "Dragonfruit", color = Theme.dragonfruitColor, points = 50, weight = 0.2}
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

-- Fruit styling
local SHADOW_OFFSET = 3
local OUTLINE_SIZE = 3

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

-- Easing
local function clamp(a, lo, hi) if a < lo then return lo elseif a > hi then return hi else return a end end

local function easeOutQuad(t)  return 1 - (1 - t)^2 end
local function easeOutBack(t)
    local c1 = 1.70158; local c3 = c1 + 1
    return 1 + c3 * (t - 1)^3 + c1 * (t - 1)^2
end

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

function Fruit:spawn(trail, rocks)
    local cx, cy, col, row = SnakeUtils.getSafeSpawn(trail, self, rocks)
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
                life  = 0.35,
                size  = 3,
                color = {col[1], col[2], col[3], 1},
                spread= math.pi * 2
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
        return true
    end
    return false
end

local function drawFruit(f)
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

function Fruit:draw()
    if fading and fading.alpha > 0 then
        drawFruit(fading)
    end
    drawFruit(active)
end

-- Queries
function Fruit:getPosition() return active.x, active.y end
function Fruit:getPoints()   return lastCollectedType.points or 1 end
function Fruit:getTypeName() return lastCollectedType.name or "Apple" end
function Fruit:getType()     return lastCollectedType end
function Fruit:getTile()     return active.col, active.row end

return Fruit