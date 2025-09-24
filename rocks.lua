local Particles = require("particles")
local Theme = require("theme")
local Arena = require("arena")

local Rocks = {}
local current = {}

Rocks.spawnChance = 0.25

local ROCK_SIZE = 24
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SHADOW_OFFSET = 3

-- smoother, rounder “stone” generator
local function generateRockShape(size, seed)
    love.math.setRandomSeed(seed or love.timer.getTime() * 1000)

    local points = {}
    local sides = love.math.random(12, 16) -- more segments = rounder
    local step = (math.pi * 2) / sides
    local baseRadius = size * 0.45

    for i = 1, sides do
        local angle = step * i
        -- slight wobble so it’s lumpy, but no sharp spikes
        local r = baseRadius * (0.9 + love.math.random() * 0.2)
        table.insert(points, math.cos(angle) * r)
        table.insert(points, math.sin(angle) * r)
    end

    return points
end

function Rocks:spawn(x, y)
    table.insert(current, {
        x = x,
        y = y,
        w = ROCK_SIZE,
        h = ROCK_SIZE,
        timer = 0,
        phase = "drop",
        scaleX = 1,
        scaleY = 0,
        offsetY = -40,
        shape = generateRockShape(ROCK_SIZE, love.math.random(1, 999999)),
    })
end

function Rocks:getAll()
    return current
end

function Rocks:reset()
    current = {}
    self.spawnChance = 0.25
end

function Rocks:update(dt)
    for _, rock in ipairs(current) do
        rock.timer = rock.timer + dt

        if rock.phase == "drop" then
            local progress = math.min(rock.timer / SPAWN_DURATION, 1)
            rock.offsetY = -40 * (1 - progress)
            rock.scaleY = progress
            rock.scaleX = progress

            if progress >= 1 then
                rock.phase = "squash"
                rock.timer = 0
                Particles:spawnBurst(rock.x, rock.y, {
                    count = love.math.random(6, 10),
                    speed = 40,
                    life = 0.4,
                    size = 3,
                    color = {0.6, 0.5, 0.4, 1},
                    spread = math.pi * 2,
                })
            end

        elseif rock.phase == "squash" then
            local progress = math.min(rock.timer / SQUASH_DURATION, 1)
            rock.scaleX = 1 + 0.3 * (1 - progress)
            rock.scaleY = 1 - 0.3 * (1 - progress)
            rock.offsetY = 0

            if progress >= 1 then
                rock.phase = "done"
                rock.scaleX = 1
                rock.scaleY = 1
                rock.offsetY = 0
            end
        end
    end
end

function Rocks:draw()
    for _, rock in ipairs(current) do
        love.graphics.push()
        love.graphics.translate(rock.x, rock.y + rock.offsetY)
        love.graphics.scale(rock.scaleX, rock.scaleY)

        -- shadow (slightly offset behind rock, scaled up so it feels bigger than outline)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.push()
        love.graphics.translate(SHADOW_OFFSET, SHADOW_OFFSET)
        love.graphics.scale(1.1, 1.1) -- make shadow a bit larger
        love.graphics.polygon("fill", rock.shape)
        love.graphics.pop()

        -- main rock fill
        love.graphics.setColor(Theme.rock)
        love.graphics.polygon("fill", rock.shape)

        -- outline
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", rock.shape)

        love.graphics.pop()
    end
end

function Rocks:getSpawnChance()
    return self.spawnChance or 0.25
end

return Rocks
