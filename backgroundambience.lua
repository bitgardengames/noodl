local Theme = require("theme")

local BackgroundAmbience = {
    current = nil,
}

local TWO_PI = math.pi * 2

local function copyColor(color)
    if not color then
        return {1, 1, 1, 1}
    end

    return {color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1}
end

local function withAlpha(color, alpha)
    local result = copyColor(color)
    result[4] = (result[4] or 1) * alpha
    return result
end

local function lighten(color, amount)
    local result = copyColor(color)
    result[1] = result[1] + (1 - result[1]) * amount
    result[2] = result[2] + (1 - result[2]) * amount
    result[3] = result[3] + (1 - result[3]) * amount
    return result
end

local function darken(color, amount)
    local result = copyColor(color)
    result[1] = result[1] * (1 - amount)
    result[2] = result[2] * (1 - amount)
    result[3] = result[3] * (1 - amount)
    return result
end

local function mix(colorA, colorB, t)
    local a = copyColor(colorA)
    local b = copyColor(colorB)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        a[4] + (b[4] - a[4]) * t,
    }
end

local function computeSeed(floorData)
    if not floorData or not floorData.name then
        return love.timer.getTime() * 1000
    end

    local seed = 0
    for i = 1, #floorData.name do
        seed = (seed * 31 + string.byte(floorData.name, i)) % 2^24
    end
    return seed
end

local function applySwayOffset(sway, axisLength, time)
    if not sway then
        return 0
    end

    local speed = sway.speed or 0
    local amplitude = sway.amplitude or 0
    local phase = sway.phase or 0
    local shift = math.sin(time * speed + phase) * amplitude
    return shift * axisLength
end

local function drawPolygon(shape, bounds, time)
    local points = {}
    local offsetX = 0
    local offsetY = 0

    if shape.sway then
        if shape.sway.axis == "x" or shape.sway.axis == "both" then
            offsetX = applySwayOffset(shape.sway, bounds.w, time)
        end
        if shape.sway.axis == "y" or shape.sway.axis == "both" then
            offsetY = applySwayOffset(shape.sway, bounds.h, time)
        end
    end

    for i = 1, #shape.points, 2 do
        local nx, ny = shape.points[i], shape.points[i + 1]
        points[#points + 1] = bounds.x + nx * bounds.w + offsetX
        points[#points + 1] = bounds.y + ny * bounds.h + offsetY
    end

    love.graphics.polygon(shape.mode or "fill", points)
end

local function drawRectangle(shape, bounds, time)
    local offsetX = 0
    local offsetY = 0

    if shape.sway then
        if shape.sway.axis == "x" or shape.sway.axis == "both" then
            offsetX = applySwayOffset(shape.sway, bounds.w, time)
        end
        if shape.sway.axis == "y" or shape.sway.axis == "both" then
            offsetY = applySwayOffset(shape.sway, bounds.h, time)
        end
    end

    love.graphics.rectangle(
        shape.mode or "fill",
        bounds.x + shape.x * bounds.w + offsetX,
        bounds.y + shape.y * bounds.h + offsetY,
        shape.w * bounds.w,
        shape.h * bounds.h
    )
end

local function drawCircle(shape, bounds, time)
    local offsetX = 0
    local offsetY = 0

    if shape.sway then
        if shape.sway.axis == "x" or shape.sway.axis == "both" then
            offsetX = applySwayOffset(shape.sway, bounds.w, time)
        end
        if shape.sway.axis == "y" or shape.sway.axis == "both" then
            offsetY = applySwayOffset(shape.sway, bounds.h, time)
        end
    end

    local radiusAxis = math.min(bounds.w, bounds.h)

    love.graphics.circle(
        shape.mode or "fill",
        bounds.x + shape.x * bounds.w + offsetX,
        bounds.y + shape.y * bounds.h + offsetY,
        (shape.radius or 0.01) * radiusAxis
    )
end

local function drawEllipse(shape, bounds, time)
    local offsetX = 0
    local offsetY = 0

    if shape.sway then
        if shape.sway.axis == "x" or shape.sway.axis == "both" then
            offsetX = applySwayOffset(shape.sway, bounds.w, time)
        end
        if shape.sway.axis == "y" or shape.sway.axis == "both" then
            offsetY = applySwayOffset(shape.sway, bounds.h, time)
        end
    end

    love.graphics.ellipse(
        shape.mode or "fill",
        bounds.x + shape.x * bounds.w + offsetX,
        bounds.y + shape.y * bounds.h + offsetY,
        (shape.rx or 0.05) * bounds.w,
        (shape.ry or 0.03) * bounds.h,
        shape.segments
    )
end

local function drawPolyline(shape, bounds, time)
    local points = {}
    local offsetX = 0
    local offsetY = 0

    if shape.sway then
        if shape.sway.axis == "x" or shape.sway.axis == "both" then
            offsetX = applySwayOffset(shape.sway, bounds.w, time)
        end
        if shape.sway.axis == "y" or shape.sway.axis == "both" then
            offsetY = applySwayOffset(shape.sway, bounds.h, time)
        end
    end

    for i = 1, #shape.points, 2 do
        local nx, ny = shape.points[i], shape.points[i + 1]
        points[#points + 1] = bounds.x + nx * bounds.w + offsetX
        points[#points + 1] = bounds.y + ny * bounds.h + offsetY
    end

    if shape.lineWidth then
        love.graphics.setLineWidth(shape.lineWidth * bounds.h)
    end

    love.graphics.setLineJoin(shape.lineJoin or "miter")
    love.graphics.line(points)
end

local function drawCustom(shape, bounds, time)
    if shape.draw then
        shape.draw(bounds, time)
    end
end

local drawHandlers = {
    polygon = drawPolygon,
    rectangle = drawRectangle,
    circle = drawCircle,
    ellipse = drawEllipse,
    polyline = drawPolyline,
    custom = drawCustom,
}

local function createAuroraLayer(color, height, thickness, amplitude, speed, offset)
    return {
        type = "custom",
        draw = function(bounds, time)
            local segments = 28
            local points = {}
            local baseY = bounds.y + height * bounds.h
            local bandHeight = thickness * bounds.h

            love.graphics.setColor(color)

            for i = 0, segments do
                local t = i / segments
                local wave = math.sin((t * 3 + offset) * TWO_PI + time * speed) * amplitude
                local x = bounds.x + t * bounds.w
                points[#points + 1] = x
                points[#points + 1] = baseY + wave * bounds.h
            end

            for i = segments, 0, -1 do
                local t = i / segments
                local wave = math.sin((t * 3 + offset) * TWO_PI + time * speed) * amplitude
                local x = bounds.x + t * bounds.w
                points[#points + 1] = x
                points[#points + 1] = baseY + bandHeight + wave * bounds.h * 0.3
            end

            love.graphics.polygon("fill", points)
        end,
    }
end

local function createHexGrid(color, spacing, thickness)
    spacing = spacing or 0.12
    thickness = thickness or 0.002

    return {
        type = "custom",
        draw = function(bounds)
            local w, h = bounds.w, bounds.h
            local step = spacing * w
            local vStep = step * math.sin(math.rad(60))
            local radius = step / 2

            love.graphics.setColor(color)
            love.graphics.setLineWidth(thickness * h)

            local cols = math.ceil(w / (radius * 1.5)) + 2
            local rows = math.ceil(h / vStep) + 2

            for row = -1, rows do
                for col = -1, cols do
                    local cx = col * radius * 1.5
                    local cy = row * vStep
                    if row % 2 == 1 then
                        cx = cx + radius * 0.75
                    end

                    local px = bounds.x + cx
                    local py = bounds.y + cy

                    local points = {}
                    for i = 0, 5 do
                        local angle = math.rad(60 * i)
                        points[#points + 1] = px + radius * math.cos(angle)
                        points[#points + 1] = py + radius * math.sin(angle)
                    end

                    love.graphics.line(
                        points[1], points[2], points[3], points[4],
                        points[3], points[4], points[5], points[6],
                        points[5], points[6], points[7], points[8],
                        points[7], points[8], points[9], points[10],
                        points[9], points[10], points[11], points[12],
                        points[11], points[12], points[1], points[2]
                    )
                end
            end
        end,
    }
end

local function createRisingBubble(color, radius, startX, baseY, height, speed, offset)
    return {
        type = "custom",
        draw = function(bounds, time)
            local progress = (time * speed + offset) % 1
            local y = baseY - progress * height
            local drawY = bounds.y + y * bounds.h
            local drawX = bounds.x + startX * bounds.w
            local r = radius * math.min(bounds.w, bounds.h)

            love.graphics.setColor(color)
            love.graphics.setLineWidth(r * 0.25)
            love.graphics.circle("line", drawX, drawY, r)
        end,
    }
end

local function createDataStream(color, x, speed, length, gap)
    gap = gap or 0.08
    length = length or 0.25

    return {
        type = "custom",
        draw = function(bounds, time)
            local streamHeight = length * bounds.h
            local startY = (time * speed) % (gap + length)
            local y = bounds.y + (startY - length) * bounds.h
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", bounds.x + x * bounds.w, y, bounds.w * 0.01, streamHeight)
        end,
    }
end

local function buildBotanical(state, rng)
    local palette = state.palette or Theme
    local canopyColor = withAlpha(lighten(palette.arenaBorder or palette.bgColor, 0.25), 0.35)
    local vineColor = withAlpha(mix(palette.snake or Theme.snakeDefault, palette.arenaBorder or palette.bgColor, 0.55), 0.45)
    local glowColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.3), 0.28)

    local shapes = {}

    for _ = 1, 4 do
        local cx = rng:random() * 0.8 + 0.1
        local cy = rng:random(4, 9) / 100
        local rx = rng:random(24, 38) / 100
        local ry = rng:random(10, 16) / 100
        shapes[#shapes + 1] = {
            type = "ellipse",
            x = cx,
            y = cy,
            rx = rx * 0.5,
            ry = ry * 0.5,
            color = canopyColor,
            sway = { axis = "y", amplitude = rng:random(4, 9) / 1000, speed = rng:random(12, 22) / 10, phase = rng:random() * TWO_PI },
        }
    end

    for _ = 1, 3 do
        local baseX = rng:random() * 0.7 + 0.15
        local midOffset = rng:random(-12, 12) / 100
        local bottomOffset = rng:random(-8, 8) / 100
        shapes[#shapes + 1] = {
            type = "polyline",
            points = {
                baseX, 0.08,
                baseX + midOffset, 0.32,
                baseX + bottomOffset, 0.92,
            },
            color = vineColor,
            lineWidth = rng:random(6, 10) / 1000,
            sway = { axis = "x", amplitude = rng:random(4, 9) / 1000, speed = rng:random(8, 16) / 10, phase = rng:random() * TWO_PI },
            lineJoin = "bevel",
        }
    end

    for _ = 1, 9 do
        local cx = rng:random() * 0.8 + 0.1
        local cy = rng:random(1, 9) / 10
        shapes[#shapes + 1] = {
            type = "circle",
            x = cx,
            y = cy,
            radius = rng:random(6, 11) / 100,
            color = glowColor,
            sway = { axis = "both", amplitude = rng:random(2, 6) / 1000, speed = rng:random(12, 20) / 10, phase = rng:random() * TWO_PI },
        }
    end

    if state.variant == "fungal" then
        local stalkColor = withAlpha(mix(palette.rock or palette.arenaBorder or Theme.shadowColor, palette.arenaBorder or palette.bgColor, 0.35), 0.6)
        local capColor = withAlpha(lighten(palette.sawColor or palette.snake or Theme.snakeDefault, 0.18), 0.55)
        local glowColor = withAlpha(lighten(palette.sawColor or palette.snake or Theme.snakeDefault, 0.35), 0.35)

        local mushroomCount = rng:random(3, 5)
        for _ = 1, mushroomCount do
            local centerX = rng:random() * 0.7 + 0.15
            local baseY = rng:random(72, 88) / 100
            local stalkHeight = rng:random(22, 36) / 100
            local stalkWidth = rng:random(4, 8) / 100
            local capRx = rng:random(14, 24) / 100
            local capRy = rng:random(7, 12) / 100
            local stalkTop = baseY - stalkHeight

            shapes[#shapes + 1] = {
                type = "rectangle",
                x = centerX - stalkWidth / 2,
                y = math.max(0, stalkTop),
                w = stalkWidth,
                h = stalkHeight,
                color = stalkColor,
                sway = { axis = "both", amplitude = rng:random(2, 6) / 1000, speed = rng:random(6, 12) / 10, phase = rng:random() * TWO_PI },
            }

            local capCenterY = math.max(0, stalkTop) + capRy
            shapes[#shapes + 1] = {
                type = "ellipse",
                x = centerX,
                y = capCenterY,
                rx = capRx,
                ry = capRy,
                color = capColor,
                sway = { axis = "both", amplitude = rng:random(3, 7) / 1000, speed = rng:random(8, 16) / 10, phase = rng:random() * TWO_PI },
            }

            shapes[#shapes + 1] = {
                type = "ellipse",
                x = centerX,
                y = capCenterY - capRy * rng:random(25, 45) / 100,
                rx = capRx * rng:random(45, 65) / 100,
                ry = capRy * rng:random(35, 55) / 100,
                color = glowColor,
            }
        end
    end

    return shapes
end

local function buildCavern(state, rng)
    local palette = state.palette or Theme
    local baseRockColor = darken(palette.arenaBorder or palette.rock or Theme.shadowColor, 0.35)
    local rockColor = copyColor(baseRockColor)
    rockColor[4] = 1

    local accentColor = withAlpha(lighten(palette.rock or palette.snake or Theme.snakeDefault, 0.2), 0.35)

    local shapes = {
        {
            type = "polygon",
            points = {0, 0.02, 0.18, 0.07, 0.38, 0.05, 0.6, 0.08, 0.82, 0.04, 1, 0.06, 1, 0, 0, 0},
            color = rockColor,
        },
    }

    local function addStalactiteLayer(count, widthRange, depthRange, color, verticalOffset, variance)
        local placements = {}
        local attempts = 0
        local maxAttempts = count * 12
        local baseY = 0.06 + (verticalOffset or 0)
        local minGap = 0.01

        while #placements < count and attempts < maxAttempts do
            attempts = attempts + 1

            local width = rng:random(widthRange[1], widthRange[2]) / 100
            local depth = rng:random(depthRange[1], depthRange[2]) / 100
            local baseX = rng:random(7, 93) / 100

            local overlap = false
            for _, existing in ipairs(placements) do
                local spacing = (width + existing.width) * 0.5 + minGap
                if math.abs(baseX - existing.baseX) < spacing then
                    overlap = true
                    break
                end
            end

            if not overlap then
                placements[#placements + 1] = {
                    baseX = baseX,
                    width = width,
                    depth = depth,
                }
            end
        end

        table.sort(placements, function(a, b)
            return a.baseX < b.baseX
        end)

        for _, stalactite in ipairs(placements) do
            local stalactiteColor = copyColor(color)

            if variance and variance > 0 then
                local shadeShift = rng:random(-variance, variance) / 100
                if shadeShift > 0 then
                    stalactiteColor = lighten(stalactiteColor, shadeShift)
                elseif shadeShift < 0 then
                    stalactiteColor = darken(stalactiteColor, -shadeShift)
                end
            end

            shapes[#shapes + 1] = {
                type = "polygon",
                points = {
                    stalactite.baseX - stalactite.width * 0.5, baseY,
                    stalactite.baseX + stalactite.width * 0.5, baseY,
                    stalactite.baseX, baseY + stalactite.depth,
                },
                color = stalactiteColor,
            }
        end
    end

    addStalactiteLayer(
        6,
        {3, 6},
        {8, 14},
        lighten(baseRockColor, 0.08),
        -0.008,
        4
    )

    addStalactiteLayer(
        5,
        {5, 9},
        {14, 22},
        darken(baseRockColor, 0.05),
        0,
        6
    )

    for _ = 1, 4 do
        local startX = rng:random(8, 92) / 100
        local startY = rng:random(35, 65) / 100
        local endX = startX + rng:random(-15, 15) / 100
        local endY = startY + rng:random(12, 22) / 100
        shapes[#shapes + 1] = {
            type = "polyline",
            points = {startX, startY, endX, endY},
            color = accentColor,
            lineWidth = rng:random(2, 4) / 1000,
        }
    end

    if state.variant == "bone" then
        local boneColor = withAlpha(lighten(palette.snake or {0.9, 0.87, 0.72, 1}, 0.15), 0.4)
        for i = 0, 2 do
            shapes[#shapes + 1] = {
                type = "polyline",
                points = {
                    0.15 + i * 0.28, 0.75,
                    0.18 + i * 0.28, 0.55,
                    0.2 + i * 0.28, 0.78,
                },
                color = boneColor,
                lineWidth = 0.006,
            }
        end
    end

    return shapes
end

local function buildMachine(state, rng)
    local palette = state.palette or Theme
    local beltColor = withAlpha(darken(palette.arenaBorder or palette.bgColor, 0.25), 0.4)
    local cogColor = withAlpha(lighten(palette.rock or palette.sawColor or Theme.shadowColor, 0.25), 0.35)
    local cableColor = withAlpha(mix(palette.snake or Theme.snakeDefault, palette.arenaBorder or palette.bgColor, 0.4), 0.55)
    local glowColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.45), 0.25)

    local shapes = {}

    for i = 0, 1 do
        local y = 0.22 + i * 0.22
        shapes[#shapes + 1] = { type = "rectangle", x = 0.05, y = y, w = 0.9, h = 0.03, color = beltColor }

        for s = 0, 5 do
            local segmentX = 0.07 + s * 0.15 + rng:random(-4, 4) / 100
            shapes[#shapes + 1] = {
                type = "rectangle",
                x = segmentX,
                y = y + 0.005,
                w = 0.035,
                h = 0.02,
                color = withAlpha(cogColor, 0.6),
            }
        end
    end

    for _ = 1, 3 do
        local cx = rng:random(15, 80) / 100
        local cy = 0.58 + rng:random(-6, 6) / 100
        local radius = rng:random(9, 15) / 100
        shapes[#shapes + 1] = {
            type = "circle",
            mode = "line",
            x = cx,
            y = cy,
            radius = radius,
            color = cogColor,
            sway = { axis = "x", amplitude = rng:random(1, 3) / 1000, speed = rng:random(4, 8), phase = rng:random() * TWO_PI },
            lineWidth = 0.004,
        }
        shapes[#shapes + 1] = {
            type = "circle",
            mode = "line",
            x = cx,
            y = cy,
            radius = radius * 0.55,
            color = cogColor,
            lineWidth = 0.003,
        }
    end

    for _ = 1, 4 do
        local topX = rng:random(2, 96) / 100
        local bottomX = topX + rng:random(-10, 10) / 100
        shapes[#shapes + 1] = {
            type = "polyline",
            points = {topX, 0.0, bottomX, 0.5},
            color = cableColor,
            lineWidth = rng:random(3, 5) / 1000,
            sway = { axis = "x", amplitude = rng:random(6, 12) / 1000, speed = rng:random(6, 12), phase = rng:random() * TWO_PI },
        }
    end

    for _ = 1, 3 do
        local px = rng:random(15, 80) / 100
        local py = rng:random(68, 85) / 100
        local width = rng:random(12, 18) / 100
        local height = rng:random(8, 12) / 100
        shapes[#shapes + 1] = {
            type = "rectangle",
            x = px,
            y = py,
            w = width,
            h = height,
            color = glowColor,
            sway = { axis = "y", amplitude = rng:random(3, 7) / 1000, speed = rng:random(4, 8), phase = rng:random() * TWO_PI },
        }
    end

    return shapes
end

local function buildArctic(state, rng)
    local palette = state.palette or Theme
    local shelfColor = withAlpha(lighten(palette.arenaBG or palette.bgColor, 0.28), 0.4)
    local icicleColor = withAlpha(lighten(palette.arenaBorder or palette.snake or Theme.snakeDefault, 0.15), 0.45)
    local auroraColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.4), 0.28)

    local shapes = {
        { type = "rectangle", x = 0, y = 0.82, w = 1, h = 0.08, color = shelfColor },
        { type = "rectangle", x = 0.15, y = 0.76, w = 0.7, h = 0.05, color = withAlpha(shelfColor, 0.8) },
    }

    for _ = 1, 8 do
        local baseX = rng:random(3, 97) / 100
        local width = rng:random(2, 5) / 100
        local length = rng:random(8, 18) / 100
        shapes[#shapes + 1] = {
            type = "polygon",
            points = {
                baseX - width * 0.5, 0.02,
                baseX + width * 0.5, 0.02,
                baseX, 0.02 + length,
            },
            color = icicleColor,
        }
    end

    shapes[#shapes + 1] = createAuroraLayer(auroraColor, 0.18, 0.06, 0.012, 0.8 + rng:random() * 0.4, rng:random())

    return shapes
end

local function buildUrban(state, rng)
    local palette = state.palette or Theme
    local skylineColor = withAlpha(darken(palette.arenaBorder or palette.bgColor, 0.3), 0.65)
    local lightColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.35), 0.4)
    local glowColor = withAlpha(lighten(palette.bgColor or Theme.bgColor, 0.6), 0.35)

    local shapes = {
        { type = "rectangle", x = 0, y = 0.88, w = 1, h = 0.12, color = glowColor },
    }

    for _ = 0, 7 do
        local width = rng:random(6, 14) / 100
        local height = rng:random(25, 45) / 100
        local x = rng:random(2, 94) / 100
        local y = 0.88 - height
        shapes[#shapes + 1] = {
            type = "rectangle",
            x = x,
            y = y,
            w = width,
            h = height,
            color = skylineColor,
        }

        if rng:random() < 0.65 then
            local rows = rng:random(2, 4)
            local cols = rng:random(1, 3)
            local cellW = width / (cols + 1)
            local cellH = height / (rows + 2)
            for r = 1, rows do
                for c = 1, cols do
                    shapes[#shapes + 1] = {
                        type = "rectangle",
                        x = x + c * cellW * 0.9,
                        y = y + r * cellH * 0.9,
                        w = cellW * 0.2,
                        h = cellH * 0.2,
                        color = withAlpha(lightColor, rng:random(45, 65) / 100),
                    }
                end
            end
        end
    end

    if state.variant == "celestial" then
        shapes[#shapes + 1] = createAuroraLayer(withAlpha(lightColor, 0.25), 0.32, 0.07, 0.01, 0.9, rng:random())
    end

    return shapes
end

local function buildDesert(state, rng)
    local palette = state.palette or Theme
    local sandColor = withAlpha(lighten(palette.arenaBorder or palette.rock or Theme.progressColor, 0.1), 0.4)
    local glyphColor = withAlpha(darken(palette.rock or Theme.progressColor, 0.2), 0.35)
    local windColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.3), 0.25)

    local shapes = {
        { type = "rectangle", x = 0, y = 0.85, w = 1, h = 0.15, color = sandColor },
    }

    for i = 0, 2 do
        local width = 0.22
        local x = 0.08 + i * 0.28
        local top = 0.45 + rng:random(-4, 5) / 100
        local base = 0.85
        local curvePoints = {
            x, base,
            x + width * 0.08, top,
            x + width * 0.5, top - 0.08,
            x + width * 0.92, top,
            x + width, base,
            x + width, base + 0.05,
            x, base + 0.05,
        }
        shapes[#shapes + 1] = {
            type = "polygon",
            points = curvePoints,
            color = withAlpha(sandColor, 0.75),
        }
    end

    for _ = 1, 4 do
        local startX = rng:random(5, 95) / 100
        local startY = rng:random(5, 40) / 100
        local endX = startX + rng:random(12, 22) / 100
        local endY = startY + rng:random(-6, 6) / 100
        shapes[#shapes + 1] = {
            type = "polyline",
            points = {startX, startY, (startX + endX) / 2, (startY + endY) / 2 + 0.03, endX, endY},
            color = windColor,
            lineWidth = rng:random(2, 4) / 1000,
            sway = { axis = "y", amplitude = rng:random(4, 8) / 1000, speed = rng:random(6, 11), phase = rng:random() * TWO_PI },
        }
    end

    for i = 0, 5 do
        shapes[#shapes + 1] = {
            type = "rectangle",
            x = 0.05 + i * 0.15,
            y = 0.9,
            w = 0.04,
            h = 0.02,
            color = glyphColor,
        }
    end

    if state.variant == "inferno" or state.variant == "hell" then
        local heatColor = withAlpha(lighten(palette.sawColor or palette.snake or Theme.warningColor, 0.2), 0.35)
        for _ = 1, 3 do
            local x = rng:random(2, 96) / 100
            shapes[#shapes + 1] = {
                type = "polyline",
                points = {x, 0.88, x + 0.02, 0.65, x - 0.01, 0.42},
                color = heatColor,
                lineWidth = 0.004,
                sway = { axis = "x", amplitude = rng:random(3, 6) / 1000, speed = rng:random(7, 12), phase = rng:random() * TWO_PI },
            }
        end
    end

    return shapes
end

local function buildLaboratory(state, rng)
    local palette = state.palette or Theme
    local gridColor = withAlpha(lighten(palette.arenaBorder or Theme.highlightColor, 0.25), 0.18)
    local tubeColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.4), 0.3)
    local streamColor = withAlpha(lighten(palette.sawColor or Theme.accentTextColor, 0.35), 0.55)

    local shapes = {
        createHexGrid(gridColor, 0.16, 0.0025),
    }

    for _ = 1, 3 do
        local x = rng:random(12, 80) / 100
        local y = rng:random(55, 75) / 100
        shapes[#shapes + 1] = {
            type = "rectangle",
            x = x,
            y = y,
            w = 0.06,
            h = 0.18,
            color = tubeColor,
            sway = { axis = "y", amplitude = rng:random(3, 6) / 1000, speed = rng:random(6, 9), phase = rng:random() * TWO_PI },
        }
    end

    for i = 1, 4 do
        local x = i * 0.18
        shapes[#shapes + 1] = createDataStream(streamColor, x, 0.6 + rng:random() * 0.3, 0.28, 0.18)
    end

    return shapes
end

local function buildOceanic(state, rng)
    local palette = state.palette or Theme
    local coneColor = withAlpha(lighten(palette.snake or Theme.snakeDefault, 0.45), 0.25)
    local kelpColor = withAlpha(mix(palette.arenaBorder or palette.bgColor, palette.snake or Theme.snakeDefault, 0.5), 0.55)
    local bubbleColor = withAlpha(lighten(palette.sawColor or palette.snake or Theme.snakeDefault, 0.2), 0.4)

    local shapes = {}

    for _ = 1, 2 do
        local baseX = rng:random(2, 40) / 100
        local width = rng:random(18, 26) / 100
        local height = rng:random(45, 55) / 100
        shapes[#shapes + 1] = {
            type = "polygon",
            points = {baseX, 0.02, baseX + width, 0.02, baseX + width * 0.5, 0.02 + height},
            color = coneColor,
        }
    end

    for _ = 1, 2 do
        local baseX = rng:random(60, 98) / 100
        local width = rng:random(16, 22) / 100
        local height = rng:random(45, 55) / 100
        shapes[#shapes + 1] = {
            type = "polygon",
            points = {baseX, 0.02, baseX - width, 0.02, baseX - width * 0.5, 0.02 + height},
            color = withAlpha(coneColor, 0.6),
        }
    end

    for _ = 1, 4 do
        local x = rng:random(8, 92) / 100
        local swayAmp = rng:random(6, 12) / 1000
        shapes[#shapes + 1] = {
            type = "polyline",
            points = {x, 0.88, x + 0.02, 0.65, x - 0.015, 0.32, x + 0.005, 0.05},
            color = kelpColor,
            lineWidth = rng:random(4, 7) / 1000,
            sway = { axis = "x", amplitude = swayAmp, speed = rng:random(5, 9), phase = rng:random() * TWO_PI },
        }
    end

    for i = 1, 5 do
        local startX = rng:random(2, 98) / 100
        local baseY = rng:random(35, 80) / 100
        local radius = rng:random(6, 10) / 100
        shapes[#shapes + 1] = createRisingBubble(bubbleColor, radius, startX, baseY, 0.4, 0.3 + rng:random() * 0.25, rng:random())
    end

    if state.variant == "abyss" then
        local silhouetteColor = withAlpha(darken(palette.bgColor or Theme.bgColor, 0.25), 0.45)
        shapes[#shapes + 1] = {
            type = "polygon",
            points = {0.15, 0.4, 0.18, 0.2, 0.25, 0.32, 0.22, 0.48},
            color = silhouetteColor,
        }
        shapes[#shapes + 1] = {
            type = "polygon",
            points = {0.75, 0.28, 0.82, 0.1, 0.9, 0.22, 0.84, 0.4},
            color = withAlpha(silhouetteColor, 0.7),
        }
    end

    return shapes
end

local themeBuilders = {
    botanical = buildBotanical,
    cavern = buildCavern,
    machine = buildMachine,
    arctic = buildArctic,
    urban = buildUrban,
    desert = buildDesert,
    laboratory = buildLaboratory,
    oceanic = buildOceanic,
}

local function deriveTheme(floorData)
    if not floorData or not floorData.name then
        return nil
    end

    local name = floorData.name:lower()
    if name:find("garden") then
        return "botanical"
    elseif name:find("mushroom") or name:find("grotto") then
        return "botanical", "fungal"
    elseif name:find("crystal") or name:find("glacial") then
        return "arctic"
    elseif name:find("catacomb") or name:find("flood") then
        return "oceanic"
    elseif name:find("abyss") then
        return "oceanic", "abyss"
    elseif name:find("cavern") or name:find("hollow") or name:find("pit") then
        local variant = nil
        if name:find("bone") then
            variant = "bone"
        end
        return "cavern", variant
    elseif name:find("ash") or name:find("frontier") then
        return "desert", "inferno"
    elseif name:find("inferno") or name:find("underworld") then
        return "desert", "hell"
    elseif name:find("obsidian") then
        return "desert", "hell"
    elseif name:find("ruin") or name:find("ancient") then
        return "machine"
    elseif name:find("spirit") or name:find("lab") or name:find("crucible") then
        return "laboratory"
    elseif name:find("celestial") or name:find("sky") or name:find("spire") then
        return "urban", "celestial"
    elseif name:find("machine") or name:find("factory") then
        return "machine"
    end

    return nil
end

function BackgroundAmbience.configure(floorData)
    if not floorData then
        BackgroundAmbience.current = nil
        return
    end

    local theme = floorData.backgroundTheme
    local variant = floorData.backgroundVariant

    if not theme then
        theme, variant = deriveTheme(floorData)
    end

    if not theme then
        BackgroundAmbience.current = nil
        return
    end

    local shapesEnabled = false
    if floorData and floorData.name then
        shapesEnabled = floorData.name:lower() == "echoing caverns"
    end

    BackgroundAmbience.current = {
        theme = theme,
        variant = variant or floorData.backgroundVariant,
        palette = floorData.palette or Theme,
        seed = computeSeed(floorData),
        shapes = nil,
        bounds = nil,
        shapesEnabled = shapesEnabled,
    }
end

local function buildShapes(state, bounds)
    local builder = themeBuilders[state.theme]
    if not builder then
        return nil
    end

    local rng = love.math.newRandomGenerator(state.seed)
    local shapes = builder({
        palette = state.palette,
        variant = state.variant,
    }, rng)

    return shapes
end

function BackgroundAmbience.draw(arena)
    local state = BackgroundAmbience.current
    if not state then
        return
    end

    if not state.shapesEnabled then
        return
    end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local x, y, w, h = 0, 0, screenWidth, screenHeight
    local bounds = state.bounds or {}

    if not state.shapes or not bounds or bounds.w ~= w or bounds.h ~= h or bounds.x ~= x or bounds.y ~= y then
        state.shapes = buildShapes(state, { x = x, y = y, w = w, h = h })
        state.bounds = { x = x, y = y, w = w, h = h }
    end

    if not state.shapes then
        return
    end

    love.graphics.push("all")
    local time = love.timer.getTime()
    local drawBounds = state.bounds

    for _, shape in ipairs(state.shapes) do
        local color = shape.color or {1, 1, 1, 1}
        love.graphics.setColor(color)

        local handler = drawHandlers[shape.type]
        if handler then
            if shape.lineWidth then
                love.graphics.setLineWidth(shape.lineWidth * drawBounds.h)
            end
            handler(shape, drawBounds, time)
        end
    end

    love.graphics.pop()
end

return BackgroundAmbience

