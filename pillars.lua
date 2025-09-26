--[[
    Stone pillar hazard that blooms from the arena floor using simple shapes
    outlined with a consistent 3 px stroke. Pillars sit on sturdy bases and
    extend into a tapered spike when triggered, matching the game's geometric
    language without any floating elements.
]]

local Theme = require("theme")
local Arena = require("arena")
local Particles = require("particles")
local SnakeUtils = require("snakeutils")

local Pillars = {}
local active = {}

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function easeInQuad(t)
    return t * t
end

local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function getStoneColors()
    local rock = Theme.rock or {0.68, 0.64, 0.58, 1}
    local shaft = {
        math.max(0, math.min(1, rock[1] * 0.9)),
        math.max(0, math.min(1, rock[2] * 0.9)),
        math.max(0, math.min(1, rock[3] * 0.9)),
        rock[4] or 1
    }
    local highlight = {1, 0.82, 0.36, 1}
    return rock, shaft, highlight
end

local function setOccupied(col, row, occupied)
    if not col or not row then
        return
    end
    SnakeUtils.setOccupied(col, row, occupied)
end

local function release(pillar)
    if not pillar then return end
    setOccupied(pillar.col, pillar.row, false)
end

function Pillars:reset()
    for _, pillar in ipairs(active) do
        release(pillar)
    end
    active = {}
end

function Pillars:getAll()
    return active
end

function Pillars:spawn(x, y, opts)
    opts = opts or {}

    local col, row = opts.col, opts.row
    if not col or not row then
        col, row = Arena:getTileFromWorld(x, y)
    end

    setOccupied(col, row, true)

    local tile = Arena.tileSize or 24
    local baseHeight = tile * 0.35
    local baseWidth = tile * 0.85
    local columnWidth = tile * 0.42
    local tipHeight = tile * 0.3
    local maxHeight = tile * 1.95
    local baseBottom = y + tile * 0.45

    local pillar = {
        x = x,
        y = y,
        col = col,
        row = row,
        baseWidth = baseWidth,
        baseHeight = baseHeight,
        baseBottom = baseBottom,
        baseTop = baseBottom - baseHeight,
        columnWidth = columnWidth,
        tipHeight = tipHeight,
        maxHeight = maxHeight,
        height = 0,
        state = "idle",
        timer = love.math.random() * 0.6,
        idleDuration = love.math.random(1.0, 2.1),
        warnDuration = 0.75,
        riseDuration = 0.32,
        holdDuration = love.math.random(0.6, 1.0),
        fallDuration = 0.42,
        warnPulse = 0,
        isDangerous = false,
        bounced = false,
        didImpactBurst = false,
        dangerHeight = tipHeight + tile * 0.45,
        shadowRadius = baseWidth * 0.55,
    }

    table.insert(active, pillar)
    return pillar
end

local function spawnImpactBurst(pillar, opts)
    if not pillar or pillar.didImpactBurst then
        return
    end

    pillar.didImpactBurst = true

    local rock, shaft = getStoneColors()
    local burstY = pillar.baseTop - pillar.height
    Particles:spawnBurst(pillar.x, burstY, {
        count = opts and opts.count or 8,
        speed = opts and opts.speed or 60,
        life = opts and opts.life or 0.4,
        size = 3,
        color = {shaft[1], shaft[2], shaft[3], 1},
        gravity = 200,
        spread = math.pi,
        angleJitter = 0.5,
    })

    if not opts or not opts.skipBaseDust then
        Particles:spawnBurst(pillar.x, pillar.baseBottom - pillar.baseHeight * 0.2, {
            count = 5,
            speed = 45,
            life = 0.45,
            size = 2,
            color = {rock[1], rock[2], rock[3], 1},
            gravity = 260,
            spread = math.pi * 2,
        })
    end
end

function Pillars:bounce(pillar)
    if not pillar then return end

    pillar.state = "fall"
    pillar.timer = 0
    pillar.height = math.min(pillar.height or 0, pillar.maxHeight)
    pillar.isDangerous = false
    pillar.bounced = true
    pillar.didImpactBurst = true

    spawnImpactBurst(pillar, {
        count = 9,
        speed = 80,
        life = 0.35,
        skipBaseDust = true,
    })
end

function Pillars:update(dt)
    if dt <= 0 then
        return
    end

    for _, pillar in ipairs(active) do
        pillar.timer = pillar.timer + dt

        if pillar.state == "idle" then
            pillar.height = 0
            pillar.isDangerous = false
            pillar.warnPulse = 0
            pillar.didImpactBurst = false
            pillar.bounced = false

            if pillar.timer >= pillar.idleDuration then
                pillar.state = "warn"
                pillar.timer = 0
            end

        elseif pillar.state == "warn" then
            local t = clamp01(pillar.timer / pillar.warnDuration)
            pillar.warnPulse = 0.5 + 0.5 * math.sin(t * math.pi * 6)
            pillar.height = math.sin(t * math.pi) * (pillar.tipHeight * 0.45)
            pillar.isDangerous = false

            if pillar.timer >= pillar.warnDuration then
                pillar.state = "rise"
                pillar.timer = 0
                pillar.warnPulse = 1
            end

        elseif pillar.state == "rise" then
            local t = clamp01(pillar.timer / pillar.riseDuration)
            pillar.height = pillar.maxHeight * easeOutQuad(t)
            pillar.isDangerous = (not pillar.bounced) and pillar.height > pillar.dangerHeight

            if pillar.timer >= pillar.riseDuration then
                pillar.state = "hold"
                pillar.timer = 0
                pillar.height = pillar.maxHeight
                pillar.isDangerous = not pillar.bounced
                spawnImpactBurst(pillar)
            end

        elseif pillar.state == "hold" then
            pillar.height = pillar.maxHeight
            pillar.isDangerous = not pillar.bounced

            if pillar.timer >= pillar.holdDuration or pillar.bounced then
                pillar.state = "fall"
                pillar.timer = 0
            end

        elseif pillar.state == "fall" then
            local t = clamp01(pillar.timer / pillar.fallDuration)
            local eased = easeInQuad(t)
            pillar.height = pillar.maxHeight * (1 - eased)
            pillar.isDangerous = (not pillar.bounced) and pillar.height > pillar.dangerHeight

            if pillar.timer >= pillar.fallDuration then
                pillar.state = "idle"
                pillar.timer = 0
                pillar.height = 0
                pillar.isDangerous = false
                pillar.warnPulse = 0
                pillar.bounced = false
                pillar.didImpactBurst = false
            end
        end
    end
end

local function drawBase(pillar)
    local rock = getStoneColors()
    local baseColor = rock
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.ellipse("fill", 0, 5, pillar.shadowRadius, pillar.shadowRadius * 0.55)

    love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4] or 1)
    love.graphics.rectangle("fill", -pillar.baseWidth / 2, -pillar.baseHeight, pillar.baseWidth, pillar.baseHeight)

    love.graphics.setColor(baseColor[1] * 0.85, baseColor[2] * 0.85, baseColor[3] * 0.85, baseColor[4] or 1)
    love.graphics.rectangle("fill", -pillar.baseWidth * 0.4, -pillar.baseHeight * 0.7, pillar.baseWidth * 0.8, pillar.baseHeight * 0.35)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -pillar.baseWidth / 2, -pillar.baseHeight, pillar.baseWidth, pillar.baseHeight)
end

local function drawWarning(pillar)
    if pillar.state ~= "warn" then
        return
    end

    local glow = 0.45 + 0.35 * pillar.warnPulse
    love.graphics.setColor(1, 0.75, 0.25, glow)
    local stripeHeight = pillar.baseHeight * 0.6
    local stripeWidth = pillar.baseWidth * 0.12
    love.graphics.rectangle("fill", -pillar.baseWidth / 2 + stripeWidth * 0.8, -stripeHeight - 2, stripeWidth, stripeHeight)
    love.graphics.rectangle("fill", pillar.baseWidth / 2 - stripeWidth * 1.8, -stripeHeight - 2, stripeWidth, stripeHeight)
end

local function drawColumn(pillar)
    local _, shaftColor, highlightColor = getStoneColors()
    local height = math.max(0, pillar.height)
    if height <= 0.5 then
        return
    end

    local tipHeight = math.min(pillar.tipHeight, height)
    local shaftHeight = math.max(0, height - tipHeight)
    local tipBaseY = -shaftHeight
    local topY = -height

    love.graphics.setColor(shaftColor[1], shaftColor[2], shaftColor[3], shaftColor[4] or 1)
    if shaftHeight > 0 then
        love.graphics.rectangle("fill", -pillar.columnWidth / 2, -shaftHeight, pillar.columnWidth, shaftHeight)
    end

    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4] or 1)
    love.graphics.polygon("fill",
        0, topY,
        -pillar.columnWidth * 0.55, tipBaseY,
        pillar.columnWidth * 0.55, tipBaseY
    )

    if shaftHeight > 0 then
        love.graphics.setColor(shaftColor[1] * 0.8, shaftColor[2] * 0.8, shaftColor[3] * 0.8, shaftColor[4] or 1)
        local inset = pillar.columnWidth * 0.18
        local stripeHeight = math.max(6, shaftHeight * 0.45)
        love.graphics.rectangle("fill", -pillar.columnWidth / 2 + inset, -stripeHeight - 2, inset, stripeHeight)
        love.graphics.rectangle("fill", pillar.columnWidth / 2 - inset * 2, -stripeHeight - 2, inset, stripeHeight)
    end

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    if shaftHeight > 0 then
        love.graphics.rectangle("line", -pillar.columnWidth / 2, -shaftHeight, pillar.columnWidth, shaftHeight)
    end
    love.graphics.polygon("line",
        0, topY,
        -pillar.columnWidth * 0.55, tipBaseY,
        pillar.columnWidth * 0.55, tipBaseY
    )
end

function Pillars:draw()
    if #active == 0 then
        return
    end

    for _, pillar in ipairs(active) do
        love.graphics.push()
        love.graphics.translate(pillar.x, pillar.baseBottom)

        drawBase(pillar)
        drawWarning(pillar)

        love.graphics.push()
        love.graphics.translate(0, -pillar.baseHeight)
        drawColumn(pillar)
        love.graphics.pop()

        love.graphics.pop()
    end
end

local function intersects(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

local function getHitbox(pillar)
    if not pillar or pillar.height <= 0 then
        return nil
    end

    local width = pillar.columnWidth * 0.9
    local height = pillar.height
    local x = pillar.x - width / 2
    local y = pillar.baseTop - height
    return x, y, width, height
end

function Pillars:checkCollision(x, y, w, h)
    for _, pillar in ipairs(active) do
        if pillar.isDangerous then
            local hx, hy, hw, hh = getHitbox(pillar)
            if hx and intersects(x, y, w, h, hx, hy, hw, hh) then
                return pillar
            end
        end
    end
end

return Pillars
