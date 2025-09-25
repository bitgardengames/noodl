local Theme = require("theme")

local Backdrop = {
    width = 0,
    height = 0,
    gradientMesh = nil,
    vignetteMesh = nil,
    orbs = {},
    time = 0,
    scanTimer = 0,
    cachedTop = nil,
    cachedBottom = nil,
    cachedVignetteColor = nil,
    cachedAccentA = nil,
    cachedAccentB = nil,
}

local ORB_COUNT = 14

local function copyColor(color, fallback)
    local src = color or fallback or {0, 0, 0, 1}
    return {src[1] or 0, src[2] or 0, src[3] or 0, src[4] or src[4] == 0 and 0 or 1}
end

local function colorChanged(a, b)
    if not a then return true end

    for i = 1, 4 do
        local av = a[i] or 0
        local bv = b[i] or 0
        if math.abs(av - bv) > 0.001 then
            return true
        end
    end

    return false
end

function Backdrop:resetGeometry()
    self.gradientMesh = nil
    self.vignetteMesh = nil
    self.cachedTop = nil
    self.cachedBottom = nil
    self.cachedVignetteColor = nil
end

function Backdrop:initializeOrbs(width, height, force)
    if not force and #self.orbs > 0 then return end

    self.orbs = {}
    for i = 1, ORB_COUNT do
        local radius = love.math.random(40, 120)
        local speed = (love.math.random() * 12 + 6) * (love.math.random() < 0.5 and -1 or 1)
        self.orbs[i] = {
            x = love.math.random() * width,
            baseY = love.math.random() * height,
            radius = radius,
            speed = speed,
            waveSpeed = love.math.random() * 0.4 + 0.2,
            waveOffset = love.math.random() * math.pi * 2,
            driftSpeed = love.math.random() * 0.3 + 0.1,
            colorMix = love.math.random(),
        }
    end

    self.cachedAccentA = copyColor(Theme.bgAccent, {0.95, 0.6, 0.75, 0.12})
    self.cachedAccentB = copyColor(Theme.bgAccentSecondary, {0.4, 0.65, 0.9, 0.1})
end

function Backdrop:onPaletteChanged()
    self:resetGeometry()
    self:initializeOrbs(self.width, self.height, true)
end

function Backdrop:resize(width, height)
    if width <= 0 or height <= 0 then return end

    if self.width ~= width or self.height ~= height then
        self.width = width
        self.height = height
        self:resetGeometry()
        self:initializeOrbs(width, height, true)
    end
end

function Backdrop:update(dt, width, height)
    width = width or self.width
    height = height or self.height

    if not width or not height then return end

    if self.width ~= width or self.height ~= height then
        self:resize(width, height)
    end

    if #self.orbs == 0 then
        self:initializeOrbs(width, height, true)
    end

    self.time = (self.time or 0) + dt
    self.scanTimer = (self.scanTimer or 0) + dt

    for _, orb in ipairs(self.orbs) do
        orb.x = orb.x + orb.speed * dt
        if orb.x < -orb.radius then
            orb.x = width + orb.radius
        elseif orb.x > width + orb.radius then
            orb.x = -orb.radius
        end

        local drift = math.sin(self.time * orb.driftSpeed + orb.waveOffset) * 18 * dt
        orb.baseY = orb.baseY + drift
        if orb.baseY < -orb.radius then
            orb.baseY = height + orb.radius
        elseif orb.baseY > height + orb.radius then
            orb.baseY = -orb.radius
        end
    end
end

function Backdrop:refreshGradient(width, height)
    local top = copyColor(Theme.bgGradientTop, Theme.bgColor)
    local bottom = copyColor(Theme.bgGradientBottom, Theme.bgColor)

    if not self.gradientMesh or self.width ~= width or self.height ~= height or
       colorChanged(self.cachedTop, top) or colorChanged(self.cachedBottom, bottom) then
        self.gradientMesh = love.graphics.newMesh({
            {0,      0,      0, 0, top[1],    top[2],    top[3],    top[4]},
            {width,  0,      1, 0, top[1],    top[2],    top[3],    top[4]},
            {width,  height, 1, 1, bottom[1], bottom[2], bottom[3], bottom[4]},
            {0,      height, 0, 1, bottom[1], bottom[2], bottom[3], bottom[4]},
        }, "fan", "static")

        self.cachedTop = top
        self.cachedBottom = bottom
    end
end

function Backdrop:refreshVignette(width, height)
    local vignette = copyColor(Theme.vignetteColor, {0, 0, 0, 0.7})

    if not self.vignetteMesh or self.width ~= width or self.height ~= height or colorChanged(self.cachedVignetteColor, vignette) then
        local alpha = vignette[4] or 0.7
        self.vignetteMesh = love.graphics.newMesh({
            {width / 2, height / 2, 0.5, 0.5, vignette[1], vignette[2], vignette[3], 0},
            {0,         0,          0,   0,  vignette[1], vignette[2], vignette[3], alpha},
            {width,     0,          1,   0,  vignette[1], vignette[2], vignette[3], alpha},
            {width,     height,     1,   1,  vignette[1], vignette[2], vignette[3], alpha},
            {0,         height,     0,   1,  vignette[1], vignette[2], vignette[3], alpha},
        }, "fan", "static")

        self.cachedVignetteColor = vignette
    end
end

function Backdrop:drawGradient(width, height)
    self:refreshGradient(width, height)
    if not self.gradientMesh then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.gradientMesh)
end

local function lerpColor(a, b, t)
    return a[1] * t + b[1] * (1 - t),
           a[2] * t + b[2] * (1 - t),
           a[3] * t + b[3] * (1 - t),
           (a[4] or 0) * t + (b[4] or 0) * (1 - t)
end

function Backdrop:drawOrbs(width, height)
    if #self.orbs == 0 then return end

    local accentA = copyColor(Theme.bgAccent, self.cachedAccentA)
    local accentB = copyColor(Theme.bgAccentSecondary, self.cachedAccentB)

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    for _, orb in ipairs(self.orbs) do
        local y = orb.baseY + math.sin(self.time * orb.waveSpeed + orb.waveOffset) * orb.radius * 0.2
        local x = orb.x
        local t = orb.colorMix
        local r, g, b, a = lerpColor(accentA, accentB, t)
        local pulse = 0.6 + 0.4 * math.sin(self.time * 1.2 + orb.waveOffset * 1.7)
        local alpha = (a or 0.1) * pulse

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", x, y, orb.radius, 64)

        love.graphics.setLineWidth(2)
        love.graphics.setColor(r, g, b, alpha * 0.6)
        love.graphics.circle("line", x, y, orb.radius * 1.15, 64)
    end

    love.graphics.pop()
end

function Backdrop:drawScanlines(width, height)
    local color = copyColor(Theme.scanlineColor, {0.95, 0.75, 1.0, 0.08})
    local bandHeight = height * 0.18
    local y = (self.scanTimer * 45) % (height + bandHeight) - bandHeight

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.rectangle("fill", 0, y, width, bandHeight)

    love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.6)
    love.graphics.rectangle("fill", 0, y - bandHeight * 0.25, width, bandHeight * 0.25)
    love.graphics.rectangle("fill", 0, y + bandHeight, width, bandHeight * 0.25)

    love.graphics.pop()
end

function Backdrop:drawBase(width, height)
    if not width or not height then return end

    self:drawGradient(width, height)
    self:drawOrbs(width, height)
    self:drawScanlines(width, height)
end

function Backdrop:drawArenaGlow(arena)
    if not arena then return end

    local ax, ay, aw, ah = arena:getBounds()
    local glow = copyColor(Theme.arenaHighlight, {1, 0.8, 1, 0.18})
    local inner = copyColor(Theme.arenaHorizon, {0.7, 0.5, 0.8, 0.12})

    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    love.graphics.setColor(glow[1], glow[2], glow[3], glow[4])
    love.graphics.ellipse("fill", ax + aw / 2, ay + ah / 2, aw * 0.52, ah * 0.5, 96)

    love.graphics.setColor(inner[1], inner[2], inner[3], inner[4])
    love.graphics.ellipse("fill", ax + aw / 2, ay + ah * 0.45, aw * 0.45, ah * 0.35, 96)

    love.graphics.pop()
end

function Backdrop:drawArenaGrid(arena)
    if not arena then return end

    local ax, ay, aw, ah = arena:getBounds()
    local primary = copyColor(Theme.arenaGridPrimary, {1, 1, 1, 0.04})
    local highlight = copyColor(Theme.arenaGridHighlight, {0.9, 0.6, 0.85, 0.08})

    love.graphics.push("all")
    love.graphics.setScissor(ax, ay, aw, ah)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(primary[1], primary[2], primary[3], primary[4])

    local step = arena.tileSize
    for x = ax + step, ax + aw - step, step do
        love.graphics.line(x, ay, x, ay + ah)
    end
    for y = ay + step, ay + ah - step, step do
        love.graphics.line(ax, y, ax + aw, y)
    end

    local pulse = 0.5 + 0.5 * math.sin(self.time * 1.4)
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 0.08) * pulse)

    local diagStep = step * 2
    for x = ax - ah, ax + aw, diagStep do
        love.graphics.line(x, ay, x + ah, ay + ah)
    end

    love.graphics.pop()
end

function Backdrop:drawVignette(width, height)
    if not width or not height then return end

    self:refreshVignette(width, height)
    if not self.vignetteMesh then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.vignetteMesh)
end

return Backdrop
