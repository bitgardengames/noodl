local Arena = require("arena")
local SnakeUtils = require("snakeutils")

local ArenaGen = {}

local DEFAULT_MIN_DENSITY = 0.045
local DEFAULT_MAX_DENSITY = 0.11
local MAX_GENERATION_ATTEMPTS = 6
local MAX_DENSITY = 0.38
local MIN_DENSITY = 0

local TEMPLATE_LIBRARY = {
        stone_single = {
                weight = 0.6,
                cells = {
                        {0, 0},
                },
                kind = "stone",
        },
        stone_corner = {
                weight = 1.05,
                cells = {
                        {0, 0}, {1, 0}, {0, 1},
                },
                allowRotate = true,
                kind = "stone",
        },
        stone_bar = {
                weight = 0.95,
                cells = {
                        {-1, 0}, {0, 0}, {1, 0},
                },
                allowRotate = true,
                kind = "stone",
        },
        stone_patch = {
                weight = 1.1,
                cells = {
                        {0, 0}, {1, 0}, {0, 1}, {1, 1},
                },
                kind = "stone",
        },
        stone_cross = {
                weight = 0.9,
                cells = {
                        {0, 0}, {1, 0}, {-1, 0}, {0, 1},
                },
                allowRotate = true,
                kind = "stone",
        },
        pillar = {
                weight = 0.45,
                cells = {
                        {0, 0},
                },
                kind = "pillar",
        },
        foliage_tuft = {
                weight = 0.8,
                cells = {
                        {0, 0},
                },
                kind = "foliage",
        },
        foliage_patch = {
                weight = 0.85,
                cells = {
                        {0, 0}, {0, 1},
                },
                allowRotate = true,
                kind = "foliage",
        },
        foliage_cluster = {
                weight = 0.7,
                cells = {
                        {0, 0}, {1, 0}, {0, 1},
                },
                allowRotate = true,
                kind = "foliage",
        },
}

local DEFAULT_TEMPLATES = {
        { name = "stone_corner" },
        { name = "stone_patch" },
        { name = "stone_bar" },
        { name = "stone_single" },
        { name = "pillar" },
        { name = "foliage_tuft" },
}

local NEIGHBOR_OFFSETS = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},
}

local function clamp(value, minValue, maxValue)
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return value
end

local function normalizeDensityRange(range)
        if type(range) == "number" then
                local value = clamp(range, MIN_DENSITY, MAX_DENSITY)
                return value, value
        end

        if type(range) ~= "table" then
                return DEFAULT_MIN_DENSITY, DEFAULT_MAX_DENSITY
        end

        local minValue, maxValue

        if range.min or range.max then
                minValue = range.min or DEFAULT_MIN_DENSITY
                maxValue = range.max or range.min or DEFAULT_MAX_DENSITY
        else
                minValue = range[1] or DEFAULT_MIN_DENSITY
                maxValue = range[2] or minValue or DEFAULT_MAX_DENSITY
        end

        minValue = clamp(minValue, MIN_DENSITY, MAX_DENSITY)
        maxValue = clamp(maxValue, MIN_DENSITY, MAX_DENSITY)

        if maxValue < minValue then
                minValue, maxValue = maxValue, minValue
        end

        return minValue, maxValue
end

local function copyTable(value)
        if type(value) ~= "table" then
                return value
        end

        local result = {}
        for key, item in pairs(value) do
                result[key] = copyTable(item)
        end
        return result
end

local function mergeHazardExclusions(base, override)
        if not base and not override then
                return nil
        end

        local merged = {}

        if base then
                for key, value in pairs(base) do
                        merged[key] = value and true or false
                end
        end

        if override then
                for key, value in pairs(override) do
                        merged[key] = value and true or false
                end
        end

        return merged
end

local function toCellKey(col, row)
        return col .. "," .. row
end

local function buildSpawnLookup(spawnBuffer)
        if not spawnBuffer then
                return {}
        end

        local lookup = {}
        for _, cell in ipairs(spawnBuffer) do
                local col = math.floor((cell[1] or 0) + 0.5)
                local row = math.floor((cell[2] or 0) + 0.5)
                lookup[toCellKey(col, row)] = true
        end

        return lookup
end

local function transformOffset(offset, orientation)
        local ox, oy = offset[1], offset[2]
        if orientation == 1 then
                return -oy, ox
        elseif orientation == 2 then
                return -ox, -oy
        elseif orientation == 3 then
                return oy, -ox
        end
        return ox, oy
end

local function getRotatedOffsets(template, orientation)
        local offsets = {}
        local minX, maxX = 0, 0
        local minY, maxY = 0, 0

        for index, offset in ipairs(template.cells or {}) do
                local rx, ry = transformOffset(offset, orientation)
                offsets[index] = {rx, ry}

                if rx < minX then minX = rx end
                if rx > maxX then maxX = rx end
                if ry < minY then minY = ry end
                if ry > maxY then maxY = ry end
        end

        return offsets, minX, maxX, minY, maxY
end

local function addMaskCell(mask, col, row, template, index)
        local key = toCellKey(col, row)
        if mask.lookup[key] then
                return false
        end

        local entry = {col, row}
        entry.kind = template and template.kind or "stone"
        entry.template = template and template.name or nil
        entry.orientation = template and template.orientation or 0
        entry.index = index

        mask.lookup[key] = true
        mask.cells[#mask.cells + 1] = entry
        return true
end

local function buildTemplatePool(config)
        local templates = config.templates or DEFAULT_TEMPLATES
        local pool = {}
        local totalWeight = 0

        for _, entry in ipairs(templates) do
                local templateName
                local weight = 1
                if type(entry) == "table" then
                        templateName = entry.name or entry.id or entry[1]
                        if entry.weight then
                                weight = entry.weight
                        end
                else
                        templateName = entry
                end

                if templateName then
                        local template = TEMPLATE_LIBRARY[templateName]
                        if template then
                                local templateWeight = (template.weight or 1) * weight
                                if templateWeight > 0 then
                                        pool[#pool + 1] = {
                                                name = templateName,
                                                template = template,
                                                weight = templateWeight,
                                        }
                                        totalWeight = totalWeight + templateWeight
                                end
                        end
                end
        end

        if totalWeight <= 0 then
                for name, template in pairs(TEMPLATE_LIBRARY) do
                        local weight = template.weight or 1
                        pool[#pool + 1] = { name = name, template = template, weight = weight }
                        totalWeight = totalWeight + weight
                end
        end

        return pool, totalWeight
end

local function chooseTemplate(rng, pool, totalWeight)
        if totalWeight <= 0 or #pool == 0 then
                return nil
        end

        local value = rng:random() * totalWeight
        local cumulative = 0
        for _, entry in ipairs(pool) do
                cumulative = cumulative + entry.weight
                if value <= cumulative then
                        return entry.template, entry.name
                end
        end

        return pool[#pool].template, pool[#pool].name
end

local function resolveSpawnOrigin(spawnBuffer)
        local cols = math.max(1, Arena.cols or 1)
        local rows = math.max(1, Arena.rows or 1)
        local midCol = math.floor(cols / 2)
        local midRow = math.floor(rows / 2)

        if spawnBuffer and #spawnBuffer > 0 then
                local bestCol, bestRow
                local bestScore = math.huge
                for _, cell in ipairs(spawnBuffer) do
                        local col = math.floor((cell[1] or 0) + 0.5)
                        local row = math.floor((cell[2] or 0) + 0.5)
                        if col >= 1 and col <= cols and row >= 1 and row <= rows then
                                local score = math.abs(col - midCol) + math.abs(row - midRow)
                                if score < bestScore then
                                        bestScore = score
                                        bestCol, bestRow = col, row
                                end
                        end
                end

                if bestCol and bestRow then
                        return bestCol, bestRow
                end
        end

        if midCol < 1 then midCol = 1 end
        if midRow < 1 then midRow = 1 end
        if midCol > cols then midCol = cols end
        if midRow > rows then midRow = rows end

        return midCol, midRow
end

local function cellViolatesHazardRules(col, row, cols, rows, hazardExclusions, centerCol, centerRow, spawnLookup, keepSpawnRing, spawnCol, spawnRow)
        if spawnLookup[toCellKey(col, row)] then
                return true
        end

        if hazardExclusions then
                if hazardExclusions.lasers or hazardExclusions.darts then
                        if col == 1 or col == cols or row == 1 or row == rows then
                                return true
                        end
                end

                if hazardExclusions.saws then
                        if math.abs(col - centerCol) <= 1 or math.abs(row - centerRow) <= 1 then
                                return true
                        end
                end
        end

        if keepSpawnRing and spawnCol and spawnRow then
                local dx = math.abs(col - spawnCol)
                local dy = math.abs(row - spawnRow)
                if math.max(dx, dy) <= keepSpawnRing then
                        return true
                end
        end

        return false
end

local function canPlaceMask(template, placement, mask, cols, rows, spawnLookup, hazardExclusions, centerCol, centerRow, keepSpawnRing, spawnCol, spawnRow)
        for _, offset in ipairs(placement.offsets) do
                local col = placement.baseCol + offset[1]
                local row = placement.baseRow + offset[2]
                if col < 1 or col > cols or row < 1 or row > rows then
                        return false
                end

                if cellViolatesHazardRules(col, row, cols, rows, hazardExclusions, centerCol, centerRow, spawnLookup, keepSpawnRing, spawnCol, spawnRow) then
                        return false
                end

                if SnakeUtils.isOccupied(col, row) then
                        return false
                end

                local key = toCellKey(col, row)
                if mask.lookup[key] then
                        return false
                end
        end

        return true
end

local function placeTemplate(mask, template, placement)
        local added = 0
        for index, offset in ipairs(placement.offsets) do
                local col = placement.baseCol + offset[1]
                local row = placement.baseRow + offset[2]
                if addMaskCell(mask, col, row, placement.templateInfo, index) then
                        added = added + 1
                end
        end
        return added
end
local function floodFill(mask, spawnCol, spawnRow)
        local cols = math.max(1, Arena.cols or 1)
        local rows = math.max(1, Arena.rows or 1)

        if spawnCol < 1 or spawnCol > cols or spawnRow < 1 or spawnRow > rows then
                return 0, false, 0
        end

        local lookup = mask.lookup or {}
        if lookup[toCellKey(spawnCol, spawnRow)] then
                return 0, false, 0
        end

        local visited = {}
        local queue = {{spawnCol, spawnRow}}
        local head = 1
        visited[toCellKey(spawnCol, spawnRow)] = true

        local reachable = 0
        local touchesEdge = false

        while head <= #queue do
                local node = queue[head]
                head = head + 1
                local col, row = node[1], node[2]

                reachable = reachable + 1
                if col == 1 or col == cols or row == 1 or row == rows then
                        touchesEdge = true
                end

                for _, offset in ipairs(NEIGHBOR_OFFSETS) do
                        local nextCol = col + offset[1]
                        local nextRow = row + offset[2]

                        if nextCol >= 1 and nextCol <= cols and nextRow >= 1 and nextRow <= rows then
                                local key = toCellKey(nextCol, nextRow)
                                if not lookup[key] and not visited[key] then
                                        visited[key] = true
                                        queue[#queue + 1] = {nextCol, nextRow}
                                end
                        end
                end
        end

        return reachable, touchesEdge, cols * rows
end

local function validateMask(mask, spawnCol, spawnRow, spawnBufferCount)
        local reachable, touchesEdge, totalCells = floodFill(mask, spawnCol, spawnRow)
        local blockedCount = #(mask.cells or {})
        local openCells = totalCells - blockedCount

        if reachable <= 0 then
                return false, reachable, touchesEdge
        end

        if touchesEdge then
                return true, reachable, touchesEdge
        end

        local threshold = math.max(spawnBufferCount + 6, math.floor(openCells * 0.35))
        if reachable >= threshold then
                return true, reachable, touchesEdge
        end

        return false, reachable, touchesEdge
end

local function prepareTemplatePlacement(rng, template, templateName)
        local orientation = 0
        if template.allowRotate then
                orientation = rng:random(0, 3)
        end

        local offsets, minX, maxX, minY, maxY = getRotatedOffsets(template, orientation)
        return {
                offsets = offsets,
                minX = minX,
                maxX = maxX,
                minY = minY,
                maxY = maxY,
                orientation = orientation,
                templateInfo = {
                        name = templateName,
                        kind = template.kind,
                        orientation = orientation,
                },
        }
end

local function attemptGenerate(seed, params)
        local rng = love.math.newRandomGenerator(seed)
        local cols = math.max(1, Arena.cols or 1)
        local rows = math.max(1, Arena.rows or 1)
        local totalCells = cols * rows

        if totalCells <= 0 then
                return { cells = {}, lookup = {}, metadata = { seed = seed, density = 0, attempts = 0 } }
        end

        local minDensity, maxDensity = normalizeDensityRange(params.densityRange)
        local density = minDensity
        if maxDensity > minDensity then
                density = minDensity + (maxDensity - minDensity) * rng:random()
        end
        density = clamp(density, MIN_DENSITY, MAX_DENSITY)

        local spawnLookup = buildSpawnLookup(params.spawnBuffer)
        local spawnCol, spawnRow = resolveSpawnOrigin(params.spawnBuffer)
        local keepSpawnRing = params.keepSpawnRing or 2
        local hazardExclusions = params.hazardExclusions
        local centerCol = math.floor(cols / 2)
        local centerRow = math.floor(rows / 2)

        local targetCount = clamp(math.floor(totalCells * density + 0.5), 0, math.floor(totalCells * 0.45))
        local pool, totalWeight = buildTemplatePool(params)
        local mask = { cells = {}, lookup = {}, metadata = {} }

        local maxPlacementAttempts = math.max(120, targetCount * 8)
        local attempts = 0

        while attempts < maxPlacementAttempts and #mask.cells < targetCount do
                attempts = attempts + 1

                local template, templateName = chooseTemplate(rng, pool, totalWeight)
                if not template then
                        break
                end

                local placement = prepareTemplatePlacement(rng, template, templateName)
                local minCol = 1 - placement.minX
                local maxCol = cols - placement.maxX
                local minRow = 1 - placement.minY
                local maxRow = rows - placement.maxY

                if minCol <= maxCol and minRow <= maxRow then
                        placement.baseCol = rng:random(minCol, maxCol)
                        placement.baseRow = rng:random(minRow, maxRow)

                        if canPlaceMask(template, placement, mask, cols, rows, spawnLookup, hazardExclusions, centerCol, centerRow, keepSpawnRing, spawnCol, spawnRow) then
                                local added = placeTemplate(mask, template, placement)
                                if added == 0 then
                                        break
                                end
                        end
                end
        end

        mask.metadata = {
                seed = seed,
                density = density,
                target = targetCount,
                attempts = attempts,
                spawnCol = spawnCol,
                spawnRow = spawnRow,
                totalCells = totalCells,
        }

        table.sort(mask.cells, function(a, b)
                if a[2] == b[2] then
                        if a[1] == b[1] then
                                return (a.template or "") < (b.template or "")
                        end
                        return a[1] < b[1]
                end
                return a[2] < b[2]
        end)

        return mask
end

function ArenaGen.generate(options)
        options = options or {}
        local floorNum = math.max(1, math.floor((options.floor or 1) + 0.5))
        local config = copyTable(options.config or {})
        config.densityRange = config.densityRange or config.density or { DEFAULT_MIN_DENSITY, DEFAULT_MAX_DENSITY }
        config.spawnBuffer = options.spawnBuffer
        config.keepSpawnRing = config.keepSpawnRing or options.keepSpawnRing or 2
        config.hazardExclusions = mergeHazardExclusions(config.hazardExclusions, options.hazardExclusions)
        config.templates = config.templates or DEFAULT_TEMPLATES

        local baseSeed = math.floor(options.seed or config.seed or 0)
        baseSeed = baseSeed + floorNum * 173
        local spawnBufferCount = #(options.spawnBuffer or {})

        local bestMask
        local validation
        local attempts = options.maxAttempts or config.maxAttempts or MAX_GENERATION_ATTEMPTS

        for attempt = 0, math.max(0, attempts - 1) do
                local attemptSeed = baseSeed + attempt * 977
                local mask = attemptGenerate(attemptSeed, config)
                local spawnCol, spawnRow = mask.metadata.spawnCol, mask.metadata.spawnRow
                local isValid, reachable, touchesEdge = validateMask(mask, spawnCol, spawnRow, spawnBufferCount)

                mask.metadata.reachable = reachable
                mask.metadata.touchesEdge = touchesEdge
                mask.metadata.valid = isValid
                mask.metadata.floor = floorNum
                mask.metadata.attemptIndex = attempt
                mask.metadata.theme = options.theme

                if isValid then
                        bestMask = mask
                        validation = true
                        break
                end

                if not bestMask or (reachable or 0) > (bestMask.metadata.reachable or -1) then
                        bestMask = mask
                end
        end

        if not bestMask then
                bestMask = { cells = {}, lookup = {}, metadata = { seed = baseSeed, density = 0, attempts = 0, valid = false } }
        end

        if not validation then
                bestMask.metadata.valid = false
        end

        return bestMask
end

return ArenaGen
