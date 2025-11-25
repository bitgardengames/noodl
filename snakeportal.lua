local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max
local math_huge = math.huge

local SnakePortal = {}

function SnakePortal.computeTrailLength(trailData)
        if not trailData then
                return 0
        end

        local total = 0
        for i = 2, #trailData do
                local prev = trailData[i - 1]
                local curr = trailData[i]
                local ax, ay = prev and prev.drawX, prev and prev.drawY
                local bx, by = curr and curr.drawX, curr and curr.drawY
                if ax and ay and bx and by then
                        local dx = bx - ax
                        local dy = by - ay
                        total = total + math_sqrt(dx * dx + dy * dy)
                end
        end

        return total
end

function SnakePortal.sliceTrailByLength(sourceTrail, maxLength, destination, deps)
        local acquireSegment = deps.acquireSegment
        local releaseSegment = deps.releaseSegment
        local releaseSegmentRange = deps.releaseSegmentRange
        local copySegmentData = deps.copySegmentData

        local result = destination or {}
        local previousCount = #result
        local count = 0

        if not sourceTrail or #sourceTrail == 0 then
                releaseSegmentRange(result, 1)
                return result
        end

        if previousCount >= 1 then
                local existing = result[1]
                if existing then
                        releaseSegment(existing)
                end
        end
        local first = copySegmentData(sourceTrail[1]) or acquireSegment()
        count = 1
        result[count] = first

        if not (maxLength and maxLength > 0) then
                releaseSegmentRange(result, count + 1)
                return result
        end

        local accumulated = 0
        for i = 2, #sourceTrail do
                local prev = sourceTrail[i - 1]
                local curr = sourceTrail[i]
                local px, py = prev and prev.drawX, prev and prev.drawY
                local cx, cy = curr and curr.drawX, curr and curr.drawY
                if not (px and py and cx and cy) then
                        break
                end

                local dx = cx - px
                local dy = cy - py
                local segLen = math_sqrt(dx * dx + dy * dy)
                if segLen <= 1e-4 then
                        segLen = 0
                end

                local nextAccum = accumulated + segLen
                if nextAccum >= maxLength then
                        local remaining = maxLength - accumulated
                        if remaining <= 1e-4 then
                                break
                        end

                        local t = remaining / segLen
                        if t < 0 then
                                t = 0
                        elseif t > 1 then
                                t = 1
                        end
                        local x = px + dx * t
                        local y = py + dy * t
                        if count + 1 <= previousCount then
                                local existing = result[count + 1]
                                if existing then
                                        releaseSegment(existing)
                                end
                        end
                        local segCopy = copySegmentData(curr) or acquireSegment()
                        segCopy.drawX = x
                        segCopy.drawY = y
                        count = count + 1
                        result[count] = segCopy
                        releaseSegmentRange(result, count + 1)
                        return result
                end

                accumulated = accumulated + segLen
                count = count + 1
                if count <= previousCount then
                        local existing = result[count]
                        if existing then
                                releaseSegment(existing)
                        end
                end
                result[count] = copySegmentData(curr)
        end

        releaseSegmentRange(result, count + 1)

        return result
end

function SnakePortal.cloneTailFromIndex(trail, startIndex, entryX, entryY, copySegmentData)
        if not trail or #trail == 0 then
                return {}
        end

        local index = math_min(math_max(startIndex or 1, 1), #trail)
        local clone = {}

        for i = index, #trail do
                local segCopy = copySegmentData(trail[i]) or {}
                if i == index then
                        segCopy.drawX = entryX or segCopy.drawX
                        segCopy.drawY = entryY or segCopy.drawY
                end
                clone[#clone + 1] = segCopy
        end

        return clone
end

function SnakePortal.findPortalEntryIndex(trail, entryX, entryY, closestPointOnSegment)
        if not trail or #trail == 0 then
                return 1
        end

        local bestIndex = 1
        local bestDist = math_huge

        for i = 1, #trail - 1 do
                local segA = trail[i]
                local segB = trail[i + 1]
                local ax, ay = segA and segA.drawX, segA and segA.drawY
                local bx, by = segB and segB.drawX, segB and segB.drawY
                if ax and ay and bx and by then
                        local _, _, distSq = closestPointOnSegment(entryX, entryY, ax, ay, bx, by)
                        if distSq < bestDist then
                                bestDist = distSq
                                bestIndex = i + 1
                        end
                end
        end

        if bestIndex > #trail then
                bestIndex = #trail
        end

        return bestIndex
end

function SnakePortal.clearPortalAnimation(state, recycleTrail)
        if not state then
                return
        end

        recycleTrail(state.entrySourceTrail)
        recycleTrail(state.entryTrail)
        recycleTrail(state.exitTrail)
        state.entrySourceTrail = nil
        state.entryTrail = nil
        state.exitTrail = nil
        state.entryHole = nil
        state.exitHole = nil
end

function SnakePortal.updateAnimation(state, trail, dt, deps)
        local SEGMENT_SIZE = deps.SEGMENT_SIZE
        local SnakeRender = deps.SnakeRender
        local sliceTrailByLength = deps.sliceTrailByLength
        local computeTrailLength = deps.computeTrailLength
        local clearPortalAnimation = deps.clearPortalAnimation

        local duration = state.duration or 0.3
        if not duration or duration <= 1e-4 then
                duration = 1e-4
        end
        state.duration = duration

        local completed = SnakeRender.updatePortalAnimation(state, dt)

        local totalLength = state.totalLength
        if not totalLength or totalLength <= 0 then
                totalLength = computeTrailLength(state.entrySourceTrail)
                if totalLength <= 0 then
                        totalLength = deps.SEGMENT_SPACING
                end
                state.totalLength = totalLength
        end

        local entryLength = totalLength * (1 - (state.progress or 0))
        local exitLength = totalLength * (state.progress or 0)

        state.entryTrail = sliceTrailByLength(state.entrySourceTrail, entryLength, state.entryTrail)
        state.exitTrail = sliceTrailByLength(trail, exitLength, state.exitTrail)

        local entryHole = state.entryHole
        if entryHole then
                entryHole.x = state.entryX
                entryHole.y = state.entryY
                entryHole.time = (entryHole.time or 0) + dt

                local entryOpen = entryHole.open or 0
                entryHole.closing = 1 - entryHole.visibility
                local baseRadius = entryHole.baseRadius or (SEGMENT_SIZE * 0.7)
                entryHole.radius = baseRadius * (0.55 + 0.65 * entryOpen)
                entryHole.spin = (entryHole.spin or 0) + dt * (2.4 + 2.1 * entryOpen)
                entryHole.pulse = (entryHole.pulse or 0) + dt
        end

        local exitHole = state.exitHole
        if exitHole then
                exitHole.x = state.exitX
                exitHole.y = state.exitY
                exitHole.time = (exitHole.time or 0) + dt

                local exitOpen = exitHole.open or 0
                exitHole.closing = 1 - exitHole.visibility
                local baseRadius = exitHole.baseRadius or (SEGMENT_SIZE * 0.75)
                exitHole.radius = baseRadius * (0.5 + 0.6 * exitOpen)
                exitHole.spin = (exitHole.spin or 0) + dt * (2.0 + 2.2 * exitOpen)
                exitHole.pulse = (exitHole.pulse or 0) + dt
        end

        if completed then
                clearPortalAnimation(state)
                return true
        end

        return false
end

return SnakePortal
