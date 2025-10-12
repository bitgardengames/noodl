local Theme = require("theme")

local SawActor = {}
SawActor.__index = SawActor

local DEFAULT_RADIUS = 24
local DEFAULT_TEETH = 12
local HUB_HOLE_RADIUS = 4
local HUB_HIGHLIGHT_PADDING = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = { 0.95, 0.08, 0.12, 1 }
local DEFAULT_SPIN_SPEED = 5

local function getHighlightColor(color)
        color = color or { 1, 1, 1, 1 }
        local r = math.min(1, color[1] * 1.2 + 0.08)
        local g = math.min(1, color[2] * 1.2 + 0.08)
        local b = math.min(1, color[3] * 1.2 + 0.08)
        local a = (color[4] or 1) * 0.7
        return { r, g, b, a }
end

function SawActor.new(options)
        local actor = setmetatable({}, SawActor)
        actor.radius = options and options.radius or DEFAULT_RADIUS
        actor.teeth = options and options.teeth or DEFAULT_TEETH
        actor.rotation = options and options.rotation or 0
        actor.spinSpeed = options and options.spinSpeed or DEFAULT_SPIN_SPEED
        actor.hitFlashTimer = 0
        return actor
end

function SawActor:update(dt)
        if not dt then
                return
        end

        self.rotation = (self.rotation + dt * self.spinSpeed) % (math.pi * 2)

        if self.hitFlashTimer > 0 then
                self.hitFlashTimer = math.max(0, self.hitFlashTimer - dt)
        end
end

function SawActor:triggerHitFlash(duration)
        if duration and duration > 0 then
                self.hitFlashTimer = duration
        else
                self.hitFlashTimer = HIT_FLASH_DURATION
        end
end

function SawActor:draw(x, y, scale)
        if not (x and y) then
                return
        end

        local radius = self.radius or DEFAULT_RADIUS
        local teeth = self.teeth or DEFAULT_TEETH
        local drawScale = scale or 1

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(self.rotation or 0)
        love.graphics.scale(drawScale, drawScale)

        local points = {}
        local outer = radius
        local inner = radius * 0.8
        local step = math.pi / teeth

        for i = 0, (teeth * 2) - 1 do
                local r = (i % 2 == 0) and outer or inner
                local angle = i * step
                points[#points + 1] = math.cos(angle) * r
                points[#points + 1] = math.sin(angle) * r
        end

        local baseColor = Theme.sawColor or { 0.8, 0.8, 0.8, 1 }
        if self.hitFlashTimer and self.hitFlashTimer > 0 then
                baseColor = HIT_FLASH_COLOR
        end

        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", points)

        local highlight = getHighlightColor(baseColor)
        love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, HUB_HOLE_RADIUS + HUB_HIGHLIGHT_PADDING - 1)

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", points)

        love.graphics.circle("fill", 0, 0, HUB_HOLE_RADIUS)

        love.graphics.pop()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
end

return SawActor
