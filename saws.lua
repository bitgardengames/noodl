local Particles = require("particles")
local Theme = require("theme")

local Saws = {}
local current = {}

local SAW_RADIUS = 24
local SAW_TEETH = 12
local TRACK_LENGTH = 120 -- how far the saw moves on its track
local HANG_FACTOR = 0.6 -- how far the blade hub peeks into the arena (multiplied by radius)
local MOVE_SPEED = 60    -- units per second along the track
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SINK_OFFSET = 2

-- modifiers
Saws.speedMult = 1.0
Saws.spinMult = 1.0
Saws.stallOnFruit = 0

local stallTimer = 0

local function getMoveSpeed()
    return MOVE_SPEED * (Saws.speedMult or 1)
end

-- Easing similar to Rocks
-- Spawn a saw on a track
function Saws:spawn(x, y, radius, teeth, dir, side)
    table.insert(current, {
        x = x,
        y = y,
        radius = radius or SAW_RADIUS,
        teeth = teeth or SAW_TEETH,
        rotation = 0,
        timer = 0,
        phase = "drop",
        scaleX = 1,
        scaleY = 0,
        offsetY = -40,

        -- movement
        dir = dir or "horizontal",
        side = side,
        progress = 0,
        direction = 1,
    })
end

function Saws:getAll()
    return current
end

function Saws:reset()
    current = {}
    self.speedMult = 1.0
    self.spinMult = 1.0
    self.stallOnFruit = 0
    stallTimer = 0
end

function Saws:update(dt)
    if stallTimer > 0 then
        stallTimer = math.max(0, stallTimer - dt)
    end

    for _, saw in ipairs(current) do
        saw.timer = saw.timer + dt
        saw.rotation = (saw.rotation + dt * 5 * (self.spinMult or 1)) % (math.pi * 2)

        if saw.phase == "drop" then
            local progress = math.min(saw.timer / SPAWN_DURATION, 1)
            saw.offsetY = -40 * (1 - progress)
            saw.scaleY = progress
            saw.scaleX = progress

            if progress >= 1 then
                saw.phase = "squash"
                saw.timer = 0
                Particles:spawnBurst(saw.x, saw.y, {
                    count = love.math.random(6, 10),
                    speed = 60,
                    life = 0.4,
                    size = 3,
                    color = {0.8, 0.8, 0.8, 1},
                    spread = math.pi * 2,
                })
            end

        elseif saw.phase == "squash" then
            local progress = math.min(saw.timer / SQUASH_DURATION, 1)
            saw.scaleX = 1 + 0.3 * (1 - progress)
            saw.scaleY = 1 - 0.3 * (1 - progress)
            saw.offsetY = 0

            if progress >= 1 then
                saw.phase = "done"
                saw.scaleX = 1
                saw.scaleY = 1
                saw.offsetY = 0
            end
        elseif saw.phase == "done" then
            if stallTimer <= 0 then
                -- Move along the track
                local delta = (getMoveSpeed() * dt) / TRACK_LENGTH
                saw.progress = saw.progress + delta * saw.direction

                if saw.progress > 1 then
                    saw.progress = 1
                    saw.direction = -1
                elseif saw.progress < 0 then
                    saw.progress = 0
                    saw.direction = 1
                end
            end
        end
    end
end

function Saws:draw()
    for _, saw in ipairs(current) do
        -- Compute saw’s actual position along its track
        local px, py
        if saw.dir == "horizontal" then
            local minX = saw.x - TRACK_LENGTH/2 + saw.radius
            local maxX = saw.x + TRACK_LENGTH/2 - saw.radius
            px = minX + (maxX - minX) * saw.progress
            py = saw.y
		else
			local minY = saw.y - TRACK_LENGTH/2 + saw.radius
			local maxY = saw.y + TRACK_LENGTH/2 - saw.radius
			py = minY + (maxY - minY) * saw.progress

			-- hub stays centered like horizontal saws
			px = saw.x
		end

        -- Draw the track slot (slimmer, dropped 1px)
        love.graphics.setColor(0, 0, 0, 1)
        if saw.dir == "horizontal" then
            love.graphics.rectangle("fill", saw.x - TRACK_LENGTH/2, saw.y - 5, TRACK_LENGTH, 10, 6, 6)
        else
            love.graphics.rectangle("fill", saw.x - 5, saw.y - TRACK_LENGTH/2, 10, TRACK_LENGTH, 6, 6)
        end

        -- Stencil: clip saw into the track (adjust direction for left/right mounted saws)
        love.graphics.stencil(function()
            if saw.dir == "horizontal" then
				love.graphics.rectangle("fill",
					saw.x - TRACK_LENGTH/2 - saw.radius,
					saw.y - 999 + SINK_OFFSET,
					TRACK_LENGTH + saw.radius * 2,
					999)
            else
                -- For vertical saws, choose stencil side based on saw.side
                local height = TRACK_LENGTH + saw.radius * 2
                local top = saw.y - TRACK_LENGTH/2 - saw.radius
                if saw.side == "left" then
                    -- allow rightwards area (blade peeking into arena)
                    love.graphics.rectangle("fill",
                        saw.x, -- start at wall x, extend right
                        top,
                        999,
                        height)
                elseif saw.side == "right" then
                    -- allow leftwards area (default)
                    love.graphics.rectangle("fill",
                        saw.x - 999,
                        top,
                        999,
                        height)
                else
                    -- centered/default: cover left side as before (keeps backward compatibility)
                    love.graphics.rectangle("fill",
                        saw.x - 999,
                        top,
                        999,
                        height)
                end
            end
        end, "replace", 1)

        love.graphics.setStencilTest("equal", 1)

        -- Saw blade
        love.graphics.push()
        love.graphics.translate(px, py + SINK_OFFSET) -- sink blade into track

        -- rotate so orientation + spin behave nicely; spin is applied after base orientation
        if saw.side == "left" then
            -- blade points to the right (since it's mounted on left wall)
            -- rotate 0 for vertical saws (we'll just spin normally)
            -- (no extra rotate needed here unless you want directional angle)
        elseif saw.side == "right" then
            -- similarly default orientation is fine
        end

        -- apply spinning rotation
        love.graphics.rotate(saw.rotation)

        local points = {}
        local teeth = saw.teeth or 8
        local outer = saw.radius
        local inner = saw.radius * 0.8
        local step = math.pi / teeth

        for i = 0, (teeth * 2) - 1 do
            local r = (i % 2 == 0) and outer or inner
            local angle = i * step
            table.insert(points, math.cos(angle) * r)
            table.insert(points, math.sin(angle) * r)
        end

        -- Fill
        love.graphics.setColor(Theme.sawColor)
        love.graphics.polygon("fill", points)

        -- Outline
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", points)

        -- Hub hole
        love.graphics.circle("fill", 0, 0, 4)

        love.graphics.pop()

        -- Reset stencil
        love.graphics.setStencilTest()
    end
end

function Saws:stall(duration)
    stallTimer = math.max(stallTimer, duration or 0)
end

function Saws:setStallOnFruit(duration)
    self.stallOnFruit = duration or 0
end

function Saws:getStallOnFruit()
    return self.stallOnFruit or 0
end

function Saws:onFruitCollected()
    local duration = self:getStallOnFruit()
    if duration > 0 then
        self:stall(duration)
    end
end

function Saws:checkCollision(x, y, w, h)
    for _, saw in ipairs(self:getAll()) do
        -- Get saw’s center position
        local px, py
        if saw.dir == "horizontal" then
            local minX = saw.x - TRACK_LENGTH/2 + saw.radius
            local maxX = saw.x + TRACK_LENGTH/2 - saw.radius
            px = minX + (maxX - minX) * saw.progress
            py = saw.y
        else
            local minY = saw.y - TRACK_LENGTH/2 + saw.radius
            local maxY = saw.y + TRACK_LENGTH/2 - saw.radius
            py = minY + (maxY - minY) * saw.progress

            local hang = 0
            if saw.side == "left" then
                hang = math.abs(saw.radius) * HANG_FACTOR
            elseif saw.side == "right" then
                hang = -math.abs(saw.radius) * HANG_FACTOR
            end
            px = saw.x + hang
        end

        -- Circle vs AABB
        local closestX = math.max(x, math.min(px, x + w))
        local closestY = math.max(y, math.min(py, y + h))
        local dx = px - closestX
        local dy = py - closestY
        if dx * dx + dy * dy < saw.radius * saw.radius then
            return true
        end
    end
    return false
end

return Saws
