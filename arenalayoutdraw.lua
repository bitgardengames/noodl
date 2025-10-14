local Theme = require("theme")

local ArenaLayoutDraw = {}

local function getColor(color, fallback)
        return color or fallback or {1, 1, 1, 1}
end

function ArenaLayoutDraw.draw(arena, layout)
        if not (arena and layout) then
                return
        end

        local tileSize = arena.tileSize or 24
        local colors = layout.colors or {}
        local walkwayColor = getColor(colors.walkway, Theme.arenaBG)
        local walkwayOutline = colors.walkwayOutline
        local blockedColor = getColor(colors.blocked, Theme.arenaBorder)
        local blockedHighlight = colors.blockedHighlight
        local accentColor = getColor(colors.accent, Theme.arenaBorder)
        local accentHighlight = colors.accentHighlight or accentColor

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha")
        love.graphics.setLineWidth(1)

        local radius = math.min(tileSize * 0.35, 8)
        if layout.walkable and #layout.walkable > 0 then
                love.graphics.setColor(walkwayColor)
                for _, cell in ipairs(layout.walkable) do
                        local col, row = cell[1], cell[2]
                        local x, y = arena:getTilePosition(col, row)
                        love.graphics.rectangle("fill", x + 2, y + 2, tileSize - 4, tileSize - 4, radius, radius)
                end

                if walkwayOutline then
                        love.graphics.setColor(walkwayOutline[1], walkwayOutline[2], walkwayOutline[3], (walkwayOutline[4] or 1) * 0.7)
                        for _, cell in ipairs(layout.walkable) do
                                local col, row = cell[1], cell[2]
                                local x, y = arena:getTilePosition(col, row)
                                love.graphics.rectangle("line", x + 2, y + 2, tileSize - 4, tileSize - 4, radius, radius)
                        end
                end
        end

        if layout.blocked and #layout.blocked > 0 then
                local blockedRadius = math.min(tileSize * 0.3, 6)
                love.graphics.setColor(blockedColor)
                for _, cell in ipairs(layout.blocked) do
                        local col, row = cell[1], cell[2]
                        local x, y = arena:getTilePosition(col, row)
                        love.graphics.rectangle("fill", x + 4, y + 4, tileSize - 8, tileSize - 8, blockedRadius, blockedRadius)
                end

                if blockedHighlight then
                        love.graphics.setColor(blockedHighlight)
                        for _, cell in ipairs(layout.blocked) do
                                local col, row = cell[1], cell[2]
                                local x, y = arena:getTilePosition(col, row)
                                love.graphics.rectangle("line", x + 4, y + 4, tileSize - 8, tileSize - 8, blockedRadius, blockedRadius)
                        end
                end
        end

        if layout.decorations and #layout.decorations > 0 then
                for _, deco in ipairs(layout.decorations) do
                        local col, row = deco[1], deco[2]
                        local decoType = deco.type or deco[3] or "marker"
                        local cx, cy = arena:getCenterOfTile(col, row)

                        if decoType == "pillar" then
                                love.graphics.setColor(accentColor)
                                local w, h = tileSize * 0.28, tileSize * 0.46
                                love.graphics.rectangle("fill", cx - w / 2, cy - h / 2, w, h, tileSize * 0.15, tileSize * 0.15)
                                love.graphics.setColor(accentHighlight)
                                love.graphics.rectangle("line", cx - w / 2, cy - h / 2, w, h, tileSize * 0.15, tileSize * 0.15)
                        elseif decoType == "planter" then
                                love.graphics.setColor(accentColor)
                                local w, h = tileSize * 0.42, tileSize * 0.24
                                love.graphics.rectangle("fill", cx - w / 2, cy - h / 2, w, h, tileSize * 0.16, tileSize * 0.16)
                                love.graphics.setColor(accentHighlight)
                                love.graphics.rectangle("line", cx - w / 2, cy - h / 2, w, h, tileSize * 0.16, tileSize * 0.16)
                                love.graphics.setColor(walkwayColor[1], walkwayColor[2], walkwayColor[3], (walkwayColor[4] or 1) * 0.85)
                                love.graphics.circle("fill", cx, cy - h * 0.05, tileSize * 0.12)
                        else
                                love.graphics.setColor(accentHighlight)
                                love.graphics.circle("fill", cx, cy, tileSize * 0.18)
                                love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], (accentColor[4] or 1) * 0.75)
                                love.graphics.circle("line", cx, cy, tileSize * 0.18)
                        end
                end
        end

        love.graphics.pop()
end

return ArenaLayoutDraw
