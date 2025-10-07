local Arena = require("arena")
local SnakeUtils = require("snakeutils")

local FloorLayouts = {}

local function clamp(val, min, max)
    if val < min then
        return min
    end
    if val > max then
        return max
    end
    return val
end

local function addCell(list, col, row)
    if not list then
        return
    end
    list[#list + 1] = { col, row }
end

local function addRectangle(list, col1, row1, col2, row2, step)
    step = step or 1
    col1, col2 = math.min(col1, col2), math.max(col1, col2)
    row1, row2 = math.min(row1, row2), math.max(row1, row2)

    for col = col1, col2, step do
        for row = row1, row2, step do
            addCell(list, col, row)
        end
    end
end

local function markStaticCells(cells)
    if not cells then
        return
    end

    for _, cell in ipairs(cells) do
        local col, row = cell[1], cell[2]
        if col and row then
            col = clamp(col, 1, Arena.cols)
            row = clamp(row, 1, Arena.rows)
            SnakeUtils.setOccupied(col, row, true)
        end
    end
end

local function dedupeCells(cells)
    if not cells or #cells == 0 then
        return cells
    end

    local unique = {}
    local seen = {}
    local cols = Arena.cols or 1
    local rows = Arena.rows or 1

    for _, cell in ipairs(cells) do
        local col = clamp(math.floor((cell[1] or 0) + 0.5), 1, cols)
        local row = clamp(math.floor((cell[2] or 0) + 0.5), 1, rows)
        local key = col .. "," .. row

        if not seen[key] then
            seen[key] = true
            unique[#unique + 1] = { col, row }
        end
    end

    return unique
end

local function buildOpenLayout(layout)
    local safeRadius = layout and layout.safeRadius or 4
    local cols = Arena.cols or 1
    local rows = Arena.rows or 1
    local midCol = math.floor(cols / 2)
    local midRow = math.floor(rows / 2)
    local extraSafe = {}

    for dx = -safeRadius, safeRadius do
        for dy = -safeRadius, safeRadius do
            local col = clamp(midCol + dx, 1, cols)
            local row = clamp(midRow + dy, 1, rows)
            addCell(extraSafe, col, row)
        end
    end

    return {
        extraSafe = extraSafe,
    }
end

local function buildCorridorLayout(layout)
    local cols = Arena.cols or 1
    local rows = Arena.rows or 1
    local corridorWidth = clamp(layout and layout.width or 9, 5, cols - 4)
    local half = math.floor(corridorWidth / 2)
    local midCol = math.floor(cols / 2)
    local leftBarrier = midCol - half - 1
    local rightBarrier = midCol + half + 1
    local staticRocks = {}

    for row = 4, rows - 3 do
        if leftBarrier >= 2 then
            addCell(staticRocks, leftBarrier, row)
        end
        if rightBarrier <= cols - 1 then
            addCell(staticRocks, rightBarrier, row)
        end
    end

    markStaticCells(staticRocks)

    return {
        staticRocks = staticRocks,
    }
end

local function buildSplitIslandsLayout(layout)
    local cols = Arena.cols or 1
    local rows = Arena.rows or 1
    local padding = clamp(layout and layout.padding or 5, 3, 10)
    local staticRocks = {}

    -- vertical divider
    local dividerCol = math.floor(cols / 2)
    for row = padding, rows - padding do
        addCell(staticRocks, dividerCol, row)
    end

    -- horizontal divider with gaps for traversal
    local dividerRow = math.floor(rows * 0.55)
    for col = padding, cols - padding do
        if math.abs(col - dividerCol) > 2 then
            addCell(staticRocks, col, dividerRow)
        end
    end

    markStaticCells(staticRocks)

    return {
        staticRocks = staticRocks,
    }
end

local function buildBossLayout(layout)
    local cols = Arena.cols or 1
    local rows = Arena.rows or 1
    local radius = clamp(layout and layout.radius or 6, 4, 10)
    local staticRocks = {}

    local midCol = math.floor(cols / 2)
    local midRow = math.floor(rows / 2)

    for angle = 0, 330, 30 do
        local rad = math.rad(angle)
        local col = math.floor(midCol + math.cos(rad) * radius)
        local row = math.floor(midRow + math.sin(rad) * (radius * 0.75))
        addCell(staticRocks, col, row)
    end

    markStaticCells(staticRocks)

    return {
        staticRocks = staticRocks,
    }
end

local BUILDERS = {
    open = buildOpenLayout,
    corridor = buildCorridorLayout,
    split = buildSplitIslandsLayout,
    boss = buildBossLayout,
}

function FloorLayouts.apply(layoutSpec, spawnPlan)
    if not (layoutSpec and layoutSpec.type) then
        return spawnPlan
    end

    local builder = BUILDERS[layoutSpec.type]
    if not builder then
        return spawnPlan
    end

    local info = builder(layoutSpec)
    if not info then
        return spawnPlan
    end

    spawnPlan.layoutInfo = info

    if info.extraSafe then
        local safe = spawnPlan.spawnSafeCells or {}
        for _, cell in ipairs(info.extraSafe) do
            safe[#safe + 1] = cell
        end
        spawnPlan.spawnSafeCells = safe
    end

    if info.staticRocks then
        local uniqueStatic = dedupeCells(info.staticRocks)
        spawnPlan.staticRocks = uniqueStatic
        if spawnPlan.numRocks then
            local remaining = (spawnPlan.numRocks or 0) - #(uniqueStatic or {})
            if remaining < 0 then
                remaining = 0
            end
            spawnPlan.numRocks = remaining
        end
    end

    return spawnPlan
end

return FloorLayouts
