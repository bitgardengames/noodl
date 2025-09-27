local UI = require("ui")

local FloatingText = {}

local entries = {}
local defaultFont = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 32)

local DEFAULTS = {
    color = { 1, 1, 1, 1 },
    duration = 1.0,
    riseSpeed = 30,
    scale = 1.2,
    pop = {
        scale = 1.28,
        duration = 0.18,
    },
    wobble = {
        magnitude = 5,
        frequency = 2.4,
    },
    drift = 12,
    fadeStart = 0.35,
    rotation = math.rad(5),
    shadow = {
        offsetX = 2,
        offsetY = 2,
        alpha = 0.35,
    },
}

local function cloneColor(color)
    local source = color or DEFAULTS.color

    return {
        source[1] or DEFAULTS.color[1],
        source[2] or DEFAULTS.color[2],
        source[3] or DEFAULTS.color[3],
        source[4] == nil and DEFAULTS.color[4] or source[4],
    }
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

local function easeInCubic(t)
    return t * t * t
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local progress = t - 1
    return 1 + c3 * (progress * progress * progress) + c1 * (progress * progress)
end

local function buildShadow(shadow)
    local defaults = DEFAULTS.shadow

    if shadow == nil then
        return {
            offsetX = defaults.offsetX,
            offsetY = defaults.offsetY,
            alpha = defaults.alpha,
        }
    end

    return {
        offsetX = shadow.offsetX or defaults.offsetX,
        offsetY = shadow.offsetY or defaults.offsetY,
        alpha = shadow.alpha == nil and defaults.alpha or shadow.alpha,
    }
end

function FloatingText:setDefaultFont(font)
    assert(font ~= nil, "FloatingText:setDefaultFont requires a font")
    defaultFont = font
end

function FloatingText:setDefaults(options)
    assert(type(options) == "table", "FloatingText:setDefaults expects a table")

    if options.color then
        DEFAULTS.color = cloneColor(options.color)
    end

    if options.duration then
        DEFAULTS.duration = math.max(0.01, options.duration)
    end

    if options.riseSpeed then
        DEFAULTS.riseSpeed = options.riseSpeed
    end

    if options.scale then
        DEFAULTS.scale = options.scale
    end

    if options.pop then
        if options.pop.scale then
            DEFAULTS.pop.scale = math.max(0, options.pop.scale)
        end

        if options.pop.duration then
            DEFAULTS.pop.duration = math.max(0, options.pop.duration)
        end
    end

    if options.wobble then
        if options.wobble.magnitude then
            DEFAULTS.wobble.magnitude = options.wobble.magnitude
        end

        if options.wobble.frequency then
            DEFAULTS.wobble.frequency = options.wobble.frequency
        end
    end

    if options.drift ~= nil then
        DEFAULTS.drift = options.drift
    end

    if options.fadeStart then
        DEFAULTS.fadeStart = clamp(options.fadeStart, 0, 0.95)
    end

    if options.rotation then
        DEFAULTS.rotation = options.rotation
    end

    if options.shadow then
        DEFAULTS.shadow = buildShadow(options.shadow)
    end
end

function FloatingText:add(text, x, y, color, duration, riseSpeed, font, options)
    assert(text ~= nil, "FloatingText:add requires text")

    options = options or {}
    font = font or defaultFont
    text = tostring(text)

    local fontWidth = font:getWidth(text)
    local fontHeight = font:getHeight()
    local entryDuration = (duration ~= nil and duration > 0) and duration or DEFAULTS.duration
    local entryColor = color and cloneColor(color) or cloneColor(DEFAULTS.color)
    local baseScale = options.scale or DEFAULTS.scale
    local popScale = baseScale * (options.popScaleFactor or DEFAULTS.pop.scale)
    local popDuration = options.popDuration or DEFAULTS.pop.duration
    local wobbleMagnitude = options.wobbleMagnitude or DEFAULTS.wobble.magnitude
    local wobbleFrequency = options.wobbleFrequency or DEFAULTS.wobble.frequency
    local fadeStart = options.fadeStart or DEFAULTS.fadeStart
    local drift

    if options.drift ~= nil then
        drift = options.drift
    elseif DEFAULTS.drift == 0 then
        drift = 0
    else
        drift = (love.math.random() * 2 - 1) * DEFAULTS.drift
    end

    local rise = options.riseDistance
    if rise == nil then
        local speed = riseSpeed or DEFAULTS.riseSpeed
        rise = speed * math.max(entryDuration, 0.05)
    end

    local rotationAmplitude = options.rotationAmplitude or DEFAULTS.rotation
    local rotationDirection = (love.math.random() < 0.5) and -1 or 1

    table.insert(entries, {
        text = text,
        x = x,
        y = y,
        color = entryColor,
        font = font,
        duration = entryDuration,
        timer = 0,
        riseDistance = rise,
        baseScale = baseScale,
        popScale = popScale,
        popDuration = popDuration,
        wobbleMagnitude = wobbleMagnitude,
        wobbleFrequency = wobbleFrequency,
        fadeStart = clamp(fadeStart, 0, 0.99),
        drift = drift,
        rotationAmplitude = rotationAmplitude,
        rotationDirection = rotationDirection,
        shadow = buildShadow(options.shadow),
        offsetX = 0,
        offsetY = 0,
        scale = baseScale,
        rotation = 0,
        ox = fontWidth / 2,
        oy = fontHeight / 2,
    })
end

function FloatingText:update(dt)
    if dt <= 0 or #entries == 0 then
        return
    end

    for i = #entries, 1, -1 do
        local entry = entries[i]
        entry.timer = entry.timer + dt

        local duration = entry.duration
        local progress = duration > 0 and clamp(entry.timer / duration, 0, 1) or 1

        entry.offsetY = -entry.riseDistance * easeOutCubic(progress)
        entry.offsetX = entry.drift * progress + entry.wobbleMagnitude * math.sin(entry.wobbleFrequency * entry.timer)

        if entry.popDuration > 0 and entry.timer < entry.popDuration then
            local popProgress = clamp(entry.timer / entry.popDuration, 0, 1)
            entry.scale = lerp(entry.popScale, entry.baseScale, easeOutBack(popProgress))
        else
            local settleDuration = math.max(duration - entry.popDuration, 0.001)
            local settleProgress = clamp((entry.timer - entry.popDuration) / settleDuration, 0, 1)
            local pulse = math.sin(entry.timer * 6) * (1 - settleProgress) * 0.04
            entry.scale = entry.baseScale * (1 + pulse)
        end

        entry.rotation = entry.rotationAmplitude * entry.rotationDirection * math.sin(progress * math.pi)

        if duration > 0 and entry.timer >= duration then
            table.remove(entries, i)
        end
    end
end

function FloatingText:draw()
    UI.pushTextShadow(false)

    for _, entry in ipairs(entries) do
        love.graphics.setFont(entry.font)

        local alpha = entry.color[4] or 1
        if entry.duration > 0 then
            local fadeStartTime = entry.duration * entry.fadeStart

            if entry.timer >= fadeStartTime then
                local fadeDuration = math.max(entry.duration - fadeStartTime, 0.001)
                local fadeProgress = clamp((entry.timer - fadeStartTime) / fadeDuration, 0, 1)
                alpha = alpha * (1 - easeInCubic(fadeProgress))
            end
        end

        alpha = clamp(alpha, 0, 1)

        love.graphics.push()
        love.graphics.translate(entry.x + entry.offsetX, entry.y + entry.offsetY)
        love.graphics.rotate(entry.rotation)
        love.graphics.scale(entry.scale)

        local shadow = entry.shadow
        if shadow.alpha > 0 then
            love.graphics.setColor(0, 0, 0, shadow.alpha * alpha)
            love.graphics.print(entry.text, -entry.ox + shadow.offsetX, -entry.oy + shadow.offsetY)
        end

        love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
        love.graphics.print(entry.text, -entry.ox, -entry.oy)

        love.graphics.pop()
    end

    UI.popTextShadow()

    love.graphics.setColor(1, 1, 1, 1)
end

function FloatingText:isEmpty()
    return #entries == 0
end

function FloatingText:count()
    return #entries
end

function FloatingText:reset()
    entries = {}
end

return FloatingText
