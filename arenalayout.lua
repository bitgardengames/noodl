local Arena = require("arena")
local Theme = require("theme")

local ArenaLayout = {}

local PRIME = 2147483647

local function clamp(value, lo, hi)
        if value < lo then return lo end
        if value > hi then return hi end
        return value
end

local function adjustColor(color, delta)
        color = color or {1, 1, 1, 1}
        local r = clamp((color[1] or 0) + delta, 0, 1)
        local g = clamp((color[2] or 0) + delta, 0, 1)
        local b = clamp((color[3] or 0) + delta, 0, 1)
        local a = color[4] == nil and 1 or color[4]
        return {r, g, b, a}
end

local function mixColor(base, target, amount)
        base = base or {1, 1, 1, 1}
        target = target or {1, 1, 1, 1}
        local mix = clamp(amount or 0, 0, 1)
        local r = base[1] + (target[1] - base[1]) * mix
        local g = base[2] + (target[2] - base[2]) * mix
        local b = base[3] + (target[3] - base[3]) * mix
        local a = base[4] + (target[4] - base[4]) * mix
        return {r, g, b, a}
end

local function computeSeed(floorNum, floorData)
        if floorData and type(floorData.layoutSeed) == "number" then
                return math.floor(floorData.layoutSeed)
        end

        local seed = math.floor(floorNum or 0)
        if seed <= 0 then
                seed = 1
        end

        local accumulator = seed
        local function ingest(value)
                if not value then
                        return
                end

                for i = 1, #value do
                        accumulator = (accumulator * 131 + value:byte(i)) % PRIME
                end
        end

        if floorData then
                if type(floorData.layoutSeed) == "string" then
                        ingest(floorData.layoutSeed)
                end

                if type(floorData.name) == "string" then
                        ingest(floorData.name)
                end

                if type(floorData.backgroundTheme) == "string" then
                        ingest(floorData.backgroundTheme)
                end

                if type(floorData.backgroundVariant) == "string" then
                        ingest(floorData.backgroundVariant)
                end
        end

        accumulator = (accumulator + seed * 17) % PRIME
        if accumulator <= 0 then
                accumulator = seed
        end

        return accumulator
end

local function getBasePalette(floorData)
        if floorData and floorData.palette then
                        return floorData.palette
        end

        return Theme
end

local function buildColors(floorData)
        local palette = getBasePalette(floorData)
        local arenaBG = palette and palette.arenaBG or Theme.arenaBG or {0.32, 0.32, 0.32, 1}
        local border = palette and palette.arenaBorder or Theme.arenaBorder or {0.24, 0.24, 0.24, 1}
        local walkway = adjustColor(arenaBG, 0.08)
        local walkwayOutline = adjustColor(border, -0.08)
        local blocked = adjustColor(arenaBG, -0.14)
        local blockedHighlight = mixColor(blocked, arenaBG, 0.35)
        local accent = mixColor(border, arenaBG, 0.35)
        local accentHighlight = adjustColor(accent, 0.12)

        return {
                walkway = walkway,
                walkwayOutline = walkwayOutline,
                blocked = blocked,
                blockedHighlight = blockedHighlight,
                accent = accent,
                accentHighlight = accentHighlight,
        }
end

local function addCell(list, lookup, col, row, variant)
        local key = col .. "," .. row
        local cell = {col, row}
        if variant then
                cell.variant = variant
        end
        list[#list + 1] = cell
        if lookup then
                lookup[key] = true
        end
        return cell
end

function ArenaLayout.generate(floorNum, floorData)
        local cols = Arena.cols or 0
        local rows = Arena.rows or 0
        if cols <= 0 or rows <= 0 then
                return nil
        end

        local seed = computeSeed(floorNum, floorData)
        local rng = love.math.newRandomGenerator(seed)

        local blocked = {}
        local walkable = {}
        local decorations = {}
        local blockedLookup = {}
        local walkableLookup = {}

        local centerCol = math.floor((cols + 1) / 2)
        local centerRow = math.floor((rows + 1) / 2)

        local ringInset = math.min(3 + rng:random(0, 1), math.floor(math.min(cols, rows) / 4))
        ringInset = math.max(ringInset, 2)

        local crossHalfCols = math.max(1, math.floor(cols * 0.06 + 0.5)) + rng:random(0, 1)
        local crossHalfRows = math.max(1, math.floor(rows * 0.06 + 0.5)) + rng:random(0, 1)

        local columnSpacing = math.max(3, math.floor(cols / (4 + rng:random(0, 1))))
        local rowSpacing = math.max(3, math.floor(rows / (4 + rng:random(0, 1))))
        local columnOffset = rng:random(0, columnSpacing - 1)
        local rowOffset = rng:random(0, rowSpacing - 1)

        local accentChance = 0.16 + rng:random() * 0.12
        local diagWidth = (((seed + columnSpacing + rowSpacing) % 3) == 0) and 2 or 1

        for row = 1, rows do
                for col = 1, cols do
                        local insideRing = col > ringInset and row > ringInset and col < (cols - ringInset + 1) and row < (rows - ringInset + 1)
                        local isWalkable = false

                        if insideRing then
                                local vertical = math.abs(col - centerCol) <= crossHalfCols
                                local horizontal = math.abs(row - centerRow) <= crossHalfRows
                                local gridColumn = ((col - ringInset) % columnSpacing) == columnOffset
                                local gridRow = ((row - ringInset) % rowSpacing) == rowOffset
                                local diagonal = math.abs(col - row) <= diagWidth and (((col + row + seed) % 3) == 0)
                                isWalkable = vertical or horizontal or gridColumn or gridRow or diagonal
                        end

                        if isWalkable then
                                local cell = addCell(walkable, walkableLookup, col, row)

                                if insideRing and rng:random() < accentChance then
                                        local deco = {col, row}
                                        if rng:random() < 0.45 then
                                                deco.type = "marker"
                                        elseif rng:random() < 0.7 then
                                                deco.type = "planter"
                                        else
                                                deco.type = "pillar"
                                        end
                                        decorations[#decorations + 1] = deco
                                end
                        else
                                local variant = ((col + row + seed) % 3 == 0) and "cluster" or "single"
                                addCell(blocked, blockedLookup, col, row, variant)
                        end
                end
        end

        local colors = buildColors(floorData)

        return {
                seed = seed,
                blocked = blocked,
                walkable = walkable,
                decorations = decorations,
                blockedLookup = blockedLookup,
                walkableLookup = walkableLookup,
                colors = colors,
                meta = {
                        ringInset = ringInset,
                        columnSpacing = columnSpacing,
                        rowSpacing = rowSpacing,
                        crossHalfCols = crossHalfCols,
                        crossHalfRows = crossHalfRows,
                },
        }
end

return ArenaLayout
