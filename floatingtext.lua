local FloatingText = {}

local entries = {}
local defaultFont = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 32)

function FloatingText:add(text, x, y, color, duration, riseSpeed, font)
    font = font or defaultFont
    text = tostring(text)

    local ox = font:getWidth(text) / 2
    local oy = font:getHeight() / 2

    table.insert(entries, {
        text = text,
        x = x,
        y = y,
        color = color or {1, 1, 1, 1},
        duration = duration or 1.0,
        timer = 0,
        riseSpeed = riseSpeed or 30,
        font = font,
        offsetY = 0,
        scale = 1.2,
        rotation = (love.math.random() - 0.5) * 0.2,
        ox = ox,
        oy = oy
    })
end

function FloatingText:update(dt)
    for i = #entries, 1, -1 do
        local entry = entries[i]
        entry.timer = entry.timer + dt
        entry.offsetY = entry.offsetY - entry.riseSpeed * dt

        if entry.scale > 1.0 then
            entry.scale = entry.scale - dt * 1.2
        end

        if entry.timer >= entry.duration then
            table.remove(entries, i)
        end
    end
end

function FloatingText:draw()
    for _, entry in ipairs(entries) do
        local alpha = 1 - (entry.timer / entry.duration)
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

function FloatingText:reset()
    entries = {}
end

return FloatingText