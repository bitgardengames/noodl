local FloatingText = {}

local entries = {}
local defaultFont = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 32)

local DEFAULTS = {
    color = { 1, 1, 1, 1 },
    duration = 1.0,
    riseSpeed = 30,
    scale = 1.2,
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
end

function FloatingText:add(text, x, y, color, duration, riseSpeed, font)
    assert(text ~= nil, "FloatingText:add requires text")

    font = font or defaultFont
    text = tostring(text)

    local fontWidth = font:getWidth(text)
    local fontHeight = font:getHeight()
    local entryDuration = (duration ~= nil and duration > 0) and duration or DEFAULTS.duration
    local entryColor = color and cloneColor(color) or cloneColor(DEFAULTS.color)

    table.insert(entries, {
        text = text,
        x = x,
        y = y,
        color = entryColor,
        duration = entryDuration,
        timer = 0,
        riseSpeed = riseSpeed or DEFAULTS.riseSpeed,
        font = font,
        offsetY = 0,
        scale = DEFAULTS.scale,
        rotation = (love.math.random() - 0.5) * 0.2,
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
        entry.offsetY = entry.offsetY - entry.riseSpeed * dt

        if entry.scale > 1.0 then
            entry.scale = math.max(1.0, entry.scale - dt * 1.2)
        end

        if entry.timer >= entry.duration then
            table.remove(entries, i)
        end
    end
end

function FloatingText:draw()
    for _, entry in ipairs(entries) do
        local duration = entry.duration
        local alpha = 1

        if duration > 0 then
            alpha = 1 - math.min(entry.timer / duration, 1)
        end

        love.graphics.setFont(entry.font)

        love.graphics.push()
        love.graphics.translate(entry.x, entry.y + entry.offsetY)
        love.graphics.rotate(entry.rotation)
        love.graphics.scale(entry.scale)

        -- Draw shadow
        love.graphics.setColor(0, 0, 0, 0.4 * alpha)
        love.graphics.print(entry.text, -entry.ox + 2, -entry.oy + 2)

        -- Draw main text
        local r, g, b, a = unpack(entry.color)
        love.graphics.setColor(r, g, b, (a or 1) * alpha)
        love.graphics.print(entry.text, -entry.ox, -entry.oy)

        love.graphics.pop()
    end

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
