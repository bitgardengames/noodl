local Arena = require("arena")
local Snake = require("snake")
local Theme = require("theme")
local SnakeUtils = require("snakeutils")

local Lighting = {
    darkness = 0.0,
    lightRadius = SnakeUtils.SEGMENT_SIZE * 10,
    maxLights = 12,
    overlayMargin = 48,
    cachedSegments = {},
    glowColor = {1, 0.95, 0.8, 1},
    meshSegments = 64,
}

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function luminance(color)
    if not color then return 0.5 end
    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function brightenColor(color, strength)
    if not color then
        return {1, 0.95, 0.8, 1}
    end

    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0

    local t = clamp(strength or 0.4, 0, 1)
    r = mix(r, 1.0, t)
    g = mix(g, 0.98, t)
    b = mix(b, 0.85, t)

    return {r, g, b, 1}
end

local function buildRadialMesh(segments)
    segments = segments or 48

    if not love or not love.graphics or not love.graphics.newMesh then
        return nil
    end

    local vertices = {}
    vertices[1] = {0, 0, 0.5, 0.5, 1, 1, 1, 1}

    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local x = math.cos(angle)
        local y = math.sin(angle)
        vertices[#vertices + 1] = {x, y, x * 0.5 + 0.5, y * 0.5 + 0.5, 1, 1, 1, 0}
    end

    return love.graphics.newMesh(vertices, "fan", "static")
end

local function ensureRadialMesh(self)
    if self.lightMesh then
        return self.lightMesh
    end

    self.lightMesh = buildRadialMesh(self.meshSegments)
    return self.lightMesh
end

local function drawRadialLight(self, x, y, radius, color, intensity)
    if radius <= 0 or intensity <= 0 then return end

    local mesh = ensureRadialMesh(self)
    if not mesh then
        love.graphics.setColor(color[1], color[2], color[3], intensity)
        love.graphics.circle("fill", x, y, radius)
        return
    end

    love.graphics.setColor(color[1], color[2], color[3], intensity)
    love.graphics.draw(mesh, x, y, 0, radius, radius)
end

local function calculateDepthFactor(floorNum)
    if not floorNum then return 0 end
    return clamp((floorNum - 6) / 8, 0, 1)
end

function Lighting:setFloorData(floorData, floorNum)
    local palette = floorData and floorData.palette or nil
    local arenaBG = (palette and palette.arenaBG) or Theme.arenaBG
    local snakeColor = (palette and palette.snake) or Theme.snakeDefault

    local brightness = luminance(arenaBG)
    local depthFactor = calculateDepthFactor(floorNum)

    -- Baseline darkness rises as the arena palette gets darker and the player descends.
    local darkness = 0.08 + (0.6 - brightness) * 0.4
    darkness = darkness + depthFactor * 0.18
    self.darkness = clamp(darkness, 0.05, 0.65)

    self.lightRadius = SnakeUtils.SEGMENT_SIZE * (9 + depthFactor * 4 + (1 - brightness) * 5)
    self.maxLights = 8 + math.floor(depthFactor * 4)
    self.segmentFalloff = 0.4 + depthFactor * 0.25
    self.headBoost = 1.15 + depthFactor * 0.1

    self.glowColor = brightenColor(snakeColor, 0.35 + depthFactor * 0.18)
end

function Lighting:getLightSources(renderState)
    if renderState == "gameover" then
        return {}
    end

    local segments = Snake:getSegments()
    if segments and #segments > 0 then
        self.cachedSegments = segments
        return segments
    end

    return self.cachedSegments or {}
end

function Lighting:draw(renderState)
    if not love or not love.graphics then return end

    local darkness = self.darkness or 0
    if darkness <= 0.05 then return end

    local sources = self:getLightSources(renderState)
    if not sources or #sources == 0 then return end

    local ax, ay, aw, ah = Arena:getBounds()
    local margin = self.overlayMargin or 0

    love.graphics.push("all")
    love.graphics.setScissor(ax - margin, ay - margin, aw + margin * 2, ah + margin * 2)

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, darkness)
    love.graphics.rectangle("fill", ax - margin, ay - margin, aw + margin * 2, ah + margin * 2)

    love.graphics.setBlendMode("add")
    local radius = self.lightRadius or (SnakeUtils.SEGMENT_SIZE * 10)
    local maxLights = math.min(#sources, self.maxLights or #sources)
    local color = self.glowColor or {1, 0.95, 0.8, 1}
    local falloff = self.segmentFalloff or 0.6

    for i = 1, maxLights do
        local seg = sources[i]
        if seg and seg.drawX and seg.drawY then
            local strength = 1 - (i - 1) / math.max(1, maxLights)
            strength = clamp(strength, 0, 1) * falloff
            local intensity = darkness * (0.55 + 0.45 * strength)
            if i == 1 then
                intensity = intensity * (self.headBoost or 1.25)
            end
            local scale = 0.85 + 0.2 * strength
            drawRadialLight(self, seg.drawX, seg.drawY, radius * scale, color, intensity)
        end
    end

    love.graphics.pop()
end

return Lighting
