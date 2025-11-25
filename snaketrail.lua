local sqrt = math.sqrt

local Trail = {}

function Trail.newPoolState()
        return {
                pool = {},
                count = 0,
                removeSnakeBodySpatialEntry = nil,
        }
end

local function getRemover(poolState, override)
        return override or poolState.removeSnakeBodySpatialEntry
end

function Trail.acquireSegment(poolState)
        local count = poolState.count
        if count > 0 then
                local segment = poolState.pool[count]
                poolState.pool[count] = nil
                poolState.count = count - 1
                return segment
        end

        return {}
end

function Trail.releaseSegment(poolState, removeSnakeBodySpatialEntry, segment)
        if not segment then
                        return
        end

        local remover = getRemover(poolState, removeSnakeBodySpatialEntry)
        if remover then
                local col, row = segment.cellCol, segment.cellRow
                if col and row then
                        remover(col, row, segment)
                end
        end

        segment.drawX = nil
        segment.drawY = nil
        segment.x = nil
        segment.y = nil
        segment.dirX = nil
        segment.dirY = nil
        segment.fruitMarker = nil
        segment.fruitMarkerX = nil
        segment.fruitMarkerY = nil
        segment.fruitScore = nil
        segment.lengthToPrev = nil
        segment.cellCol = nil
        segment.cellRow = nil

        local count = poolState.count + 1
        poolState.count = count
        poolState.pool[count] = segment
end

function Trail.releaseSegmentRange(poolState, buffer, startIndex, removeSnakeBodySpatialEntry)
        if not buffer then
                return
        end

        for i = #buffer, startIndex, -1 do
                local segment = buffer[i]
                buffer[i] = nil
                if segment then
                        Trail.releaseSegment(poolState, removeSnakeBodySpatialEntry, segment)
                end
        end
end

function Trail.ensureHeadLength(trail, trailLength)
        if not (trail and trail[1]) then
                return trailLength
        end

        local head = trail[1]
        local existing = head.lengthToPrev or 0
        if existing ~= 0 then
                trailLength = trailLength - existing
                head.lengthToPrev = 0
        end

        return trailLength
end

function Trail.updateSegmentLengthAt(trail, trailLength, index)
        if not (trail and index and index >= 2) then
                return trailLength
        end

        local curr = trail[index]
        local prev = trail[index - 1]
        if not curr then
                return trailLength
        end

        local length = 0
        if prev and prev.drawX and prev.drawY and curr.drawX and curr.drawY then
                local dx = prev.drawX - curr.drawX
                local dy = prev.drawY - curr.drawY
                length = sqrt(dx * dx + dy * dy)
        end

        local existing = curr.lengthToPrev or 0
        if existing ~= length then
                trailLength = trailLength - existing + length
                curr.lengthToPrev = length
        end

        return trailLength
end

function Trail.recalcSegmentLengthsRange(trail, trailLength, startIndex, endIndex)
        if not trail or #trail == 0 then
                return 0
        end

        if not startIndex or startIndex <= 1 then
                trailLength = Trail.ensureHeadLength(trail, trailLength)
                startIndex = 2
        end

        if not endIndex or endIndex > #trail then
                endIndex = #trail
        end

        for i = startIndex, endIndex do
                trailLength = Trail.updateSegmentLengthAt(trail, trailLength, i)
        end

        return trailLength
end

function Trail.syncTrailLength(trail, trailLength)
        if not trail or #trail == 0 then
                return 0
        end

        trailLength = Trail.ensureHeadLength(trail, trailLength)
        for i = 2, #trail do
                trailLength = Trail.updateSegmentLengthAt(trail, trailLength, i)
        end

        return trailLength
end

function Trail.recycleTrail(poolState, trail, trailLength, buffer, removeSnakeBodySpatialEntry)
        if not buffer then
                return trailLength
        end

        for i = #buffer, 1, -1 do
                local segment = buffer[i]
                buffer[i] = nil
                if segment then
                        Trail.releaseSegment(poolState, removeSnakeBodySpatialEntry, segment)
                end
        end

        if buffer == trail then
                trailLength = 0
        end

        return trailLength
end

return Trail
