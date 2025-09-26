--[[
    Hydraulic press hazard composed of simple primitives with a consistent
    3 px outline. The housing, piston, and striking head are rectangles with
    rounded corners, while the warning chevron is a triangle so the silhouette
    stays readable at gameplay scale.
]]

local Theme = require("theme")
local Arena = require("arena")
local Particles = require("particles")
local SnakeUtils = require("snakeutils")

local Presses = {}
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

local function getMetalColor()
    local c = Theme.sawColor or {0.82, 0.82, 0.86, 1}
    return c[1] or 0.82, c[2] or 0.82, c[3] or 0.86, c[4] == nil and 1 or c[4]
end

local function setOccupied(col, row)
    if col and row then
        SnakeUtils.setOccupied(col, row, true)
    end
end

function Presses:reset()
    active = {}
end

function Presses:getAll()
    return active
end

function Presses:spawn(x, y, opts)
    opts = opts or {}

    local col, row = opts.col, opts.row
    if not col or not row then
        col, row = Arena:getTileFromWorld(x, y)
    end

    setOccupied(col, row)

    local tile = Arena.tileSize or 24
    local headWidth = tile * 1.35
    local headHeight = tile * 1.1
    local travel = tile * 2.4
    local targetY = y
    local restY = y - travel

    local press = {
        x = x,
        y = y,
        col = col,
        row = row,
        headWidth = headWidth,
        headHeight = headHeight,
        targetY = targetY,
        restY = restY,
        headY = restY,
        state = "idle",
        timer = love.math.random() * 0.5,
        idleDuration = love.math.random(0.8, 1.5),
        warnDuration = 0.55,
        slamDuration = 0.22,
        holdDuration = 0.32,
        riseDuration = 0.38,
        warningPulse = 0,
        isDangerous = false,
        didImpactBurst = false,
    }

    press.housingHeight = tile * 0.8
    press.housingWidth = headWidth + tile * 0.7
    press.housingGap = tile * 0.55
    press.housingBottom = press.restY - press.headHeight / 2 - press.housingGap
    press.housingTop = press.housingBottom - press.housingHeight
    press.pistonWidth = math.max(10, headWidth * 0.28)

    active[#active + 1] = press
    return press
end

local function spawnImpactBurst(press)
    if press.didImpactBurst then
        return
    end

    press.didImpactBurst = true

    local r, g, b = getMetalColor()
    Particles:spawnBurst(press.x, press.targetY + press.headHeight * 0.5, {
        count = 8,
        speed = 70,
        life = 0.35,
        size = 3,
        color = {r, g, b, 1},
        gravity = 260,
        spread = math.pi,
        angleJitter = 0.6,
    })
end

function Presses:bounce(press)
    if not press then return end

    press.state = "rise"
    press.timer = 0
    press.isDangerous = false
    press.didImpactBurst = true
end

function Presses:update(dt)
    if dt <= 0 or #active == 0 then
        return
    end

    for _, press in ipairs(active) do
        press.timer = press.timer + dt

        if press.state == "idle" then
            press.headY = press.restY
            press.isDangerous = false
            press.warningPulse = 0
            press.didImpactBurst = false

            if press.timer >= press.idleDuration then
                press.state = "warn"
                press.timer = 0
            end

        elseif press.state == "warn" then
            local t = clamp01(press.timer / press.warnDuration)
            press.headY = press.restY + math.sin(t * math.pi * 5) * 4
            press.warningPulse = 0.35 + 0.65 * math.sin(love.timer.getTime() * 12)
            press.isDangerous = false

            if press.timer >= press.warnDuration then
                press.state = "slam"
                press.timer = 0
                press.warningPulse = 1
            end

        elseif press.state == "slam" then
            local t = clamp01(press.timer / press.slamDuration)
            local eased = easeInQuad(t)
            press.headY = press.restY + (press.targetY - press.restY) * eased
            press.isDangerous = true

            if press.timer >= press.slamDuration then
                press.state = "hold"
                press.timer = 0
                press.headY = press.targetY
                press.isDangerous = true
                spawnImpactBurst(press)
            end

        elseif press.state == "hold" then
            press.headY = press.targetY
            press.isDangerous = true
            spawnImpactBurst(press)

            if press.timer >= press.holdDuration then
                press.state = "rise"
                press.timer = 0
                press.isDangerous = false
            end

        elseif press.state == "rise" then
            local t = clamp01(press.timer / press.riseDuration)
            local eased = easeOutQuad(t)
            press.headY = press.targetY + (press.restY - press.targetY) * eased
            press.isDangerous = false

            if press.timer >= press.riseDuration then
                press.state = "idle"
                press.timer = 0
                press.headY = press.restY
                press.idleDuration = love.math.random(0.8, 1.5)
            end
        end
    end
end

local function drawOutlinedRect(mode, x, y, w, h, rx, ry)
    love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, rx, ry)
end

local function drawFloorIndicator(press)
    local tile = Arena.tileSize or 24
    local baseSize = tile * 0.9
    local r, g, b = getMetalColor()

    local alpha = 0.12
    if press.state == "warn" then
        alpha = 0.18 + 0.12 * math.abs(press.warningPulse or 0)
    elseif press.state == "slam" then
        alpha = 0.32
    elseif press.state == "hold" then
        alpha = 0.24
    end

    love.graphics.setColor(r, g, b, alpha)
    drawOutlinedRect("fill", press.x - baseSize / 2, press.y - baseSize / 2, baseSize, baseSize, 6, 6)

    love.graphics.push()
    love.graphics.translate(press.x, press.y)
    love.graphics.rotate(math.pi / 4)
    love.graphics.setColor(r, g, b, alpha * 0.9)
    drawOutlinedRect("fill", -baseSize * 0.35, -baseSize * 0.35, baseSize * 0.7, baseSize * 0.7, 4, 4)
    love.graphics.pop()
end

local function drawPiston(press)
    local top = press.housingBottom
    local bottom = press.headY - press.headHeight / 2
    if bottom <= top then
        return
    end

    local height = bottom - top
    local width = press.pistonWidth
    local r, g, b = getMetalColor()

    love.graphics.setColor(r * 0.9, g * 0.9, b * 0.9, 1)
    drawOutlinedRect("fill", press.x - width / 2, top, width, height, 4, 4)
end

local function drawHousing(press)
    local r, g, b = getMetalColor()
    love.graphics.setColor(r * 0.8, g * 0.8, b * 0.85, 1)
    drawOutlinedRect("fill", press.x - press.housingWidth / 2, press.housingTop, press.housingWidth, press.housingHeight, 6, 6)

    local hubRadius = press.housingHeight * 0.22
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", press.x, press.housingTop + press.housingHeight / 2, hubRadius)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", press.x, press.housingTop + press.housingHeight / 2, hubRadius)
end

local function drawHead(press)
    local headWidth = press.headWidth
    local headHeight = press.headHeight
    local r, g, b = getMetalColor()
    local x = press.x - headWidth / 2
    local y = press.headY - headHeight / 2

    love.graphics.setColor(r, g, b, 1)
    drawOutlinedRect("fill", x, y, headWidth, headHeight, 8, 8)

    love.graphics.setColor(r * 0.7, g * 0.4, b * 0.4, 0.6)
    drawOutlinedRect("fill", x, y + headHeight * 0.55, headWidth, headHeight * 0.25, 6, 6)

    local tipHeight = headHeight * 0.28
    local tipWidth = headWidth * 0.38
    local cx = press.x
    local baseY = y + headHeight

    love.graphics.setColor(r * 0.95, g * 0.35, b * 0.35, press.isDangerous and 0.95 or 0.6)
    local trianglePoints = {
        cx, baseY + tipHeight,
        cx - tipWidth / 2, baseY,
        cx + tipWidth / 2, baseY,
    }
    love.graphics.polygon("fill", trianglePoints)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.polygon("line", trianglePoints)
end

function Presses:draw()
    if #active == 0 then
        return
    end

    for _, press in ipairs(active) do
        drawFloorIndicator(press)
        drawPiston(press)
        drawHead(press)
        drawHousing(press)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function intersects(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Presses:checkCollision(x, y, w, h)
    local test = { x = x, y = y, w = w, h = h }

    for _, press in ipairs(active) do
        if press.isDangerous then
            local headX = press.x - press.headWidth / 2
            local headY = press.headY - press.headHeight / 2
            local hitbox = {
                x = headX,
                y = headY,
                w = press.headWidth,
                h = press.headHeight,
            }

            if intersects(test, hitbox) then
                return press
            end
        end
    end

    return nil
end

return Presses
