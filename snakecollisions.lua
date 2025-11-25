local sqrt = math.sqrt
local min = math.min
local max = math.max

local SnakeCollisions = {}

-- Use indexed slots so collision contexts stay array-backed in hot paths.
local CTX_SNAKE = 1
local CTX_TRAIL = 2
local CTX_HEAD_X = 3
local CTX_HEAD_Y = 4
local CTX_GUARD_DISTANCE = 5
local CTX_BODY_RADIUS = 6
local CTX_CUT_EVENT = 7

local function resetCollisionContext(context)
        if not context then
                return
        end

        context[CTX_SNAKE] = nil
        context[CTX_TRAIL] = nil
        context[CTX_HEAD_X] = nil
        context[CTX_HEAD_Y] = nil
        context[CTX_GUARD_DISTANCE] = 0
        context[CTX_BODY_RADIUS] = 0

        local cutEvent = context[CTX_CUT_EVENT]
        if cutEvent then
                cutEvent.index = nil
                cutEvent.cutX = nil
                cutEvent.cutY = nil
                cutEvent.cutDistance = nil
        end
end

local function prepareCollisionContext(context, snake, trail, guardDistance, bodyRadius)
        if not (trail and trail[1]) then
                return false
        end

        local head = trail[1]
        local headX = head and (head.drawX or head.x)
        local headY = head and (head.drawY or head.y)
        if not (headX and headY) then
                return false
        end

        context[CTX_SNAKE] = snake
        context[CTX_TRAIL] = trail
        context[CTX_HEAD_X] = headX
        context[CTX_HEAD_Y] = headY
        context[CTX_GUARD_DISTANCE] = guardDistance
        context[CTX_BODY_RADIUS] = bodyRadius
        return true
end

function SnakeCollisions.new(deps)
        local collectSnakeSegmentCandidatesForRect = deps.collectSnakeSegmentCandidatesForRect
        local collectSnakeSegmentCandidatesForCircle = deps.collectSnakeSegmentCandidatesForCircle
        local segmentRectIntersection = deps.segmentRectIntersection
        local closestPointOnSegment = deps.closestPointOnSegment
        local isSawCutPointExposed = deps.isSawCutPointExposed
        local getSawCenterPosition = deps.getSawCenterPosition
        local isSawActive = deps.isSawActive
        local SEGMENT_SPACING = deps.SEGMENT_SPACING
        local SEGMENT_SIZE = deps.SEGMENT_SIZE
        local Lasers = deps.Lasers
        local Darts = deps.Darts
        local Saws = deps.Saws

        local laserCollisionContext = {
                [CTX_CUT_EVENT] = {cause = "laser"},
        }

        local dartCollisionContext = {
                [CTX_CUT_EVENT] = {cause = "dart"},
        }

        local sawCollisionContext = {
                [CTX_CUT_EVENT] = {},
        }

        local function evaluateTrailRectCut(context, expandedX, expandedY, expandedW, expandedH, candidateIndices, candidateCount, candidateLookup, candidateGeneration)
                local trailRef = context[CTX_TRAIL]
                if not (trailRef and trailRef[1]) then
                        return nil
                end

                local headX = context[CTX_HEAD_X]
                local headY = context[CTX_HEAD_Y]
                if not (headX and headY) then
                        return nil
                end

                if not candidateLookup then
                        candidateIndices, candidateCount, candidateLookup, candidateGeneration = collectSnakeSegmentCandidatesForRect(expandedX, expandedY, expandedW, expandedH)
                end

                local useCandidateFilter = candidateLookup ~= nil
                if useCandidateFilter and (not candidateIndices or (candidateCount or 0) == 0) then
                        return nil
                end

                local travelled = 0
                local prevX, prevY = headX, headY

                for index = 2, #trailRef do
                        local segment = trailRef[index]
                        local cx = segment and (segment.drawX or segment.x)
                        local cy = segment and (segment.drawY or segment.y)
                        if cx and cy then
                                local dx = cx - prevX
                                local dy = cy - prevY
                                local segLen = sqrt(dx * dx + dy * dy)

                                if segLen > 1e-6 then
                                        local shouldTest = not useCandidateFilter or (candidateLookup[segment] == candidateGeneration)
                                        if shouldTest then
                                                local intersects, cutX, cutY, t = segmentRectIntersection(
                                                        prevX,
                                                        prevY,
                                                        cx,
                                                        cy,
                                                        expandedX,
                                                        expandedY,
                                                        expandedW,
                                                        expandedH
                                                )

                                                if intersects and t then
                                                        local along = travelled + segLen * t
                                                        if along > context[CTX_GUARD_DISTANCE] then
                                                                local cutEvent = context[CTX_CUT_EVENT]
                                                                cutEvent.index = index
                                                                cutEvent.cutX = cutX
                                                                cutEvent.cutY = cutY
                                                                cutEvent.cutDistance = along
                                                                return cutEvent
                                                        end
                                                end
                                        end
                                end

                                travelled = travelled + segLen
                                prevX, prevY = cx, cy
                        end
                end

                return nil
        end

        local function evaluateTrailCircleCut(context, saw, centerX, centerY, combinedRadiusSq, candidateIndices, candidateCount, candidateLookup, candidateGeneration)
                local trailRef = context[CTX_TRAIL]
                if not (trailRef and trailRef[1]) then
                        return nil
                end

                local headX = context[CTX_HEAD_X]
                local headY = context[CTX_HEAD_Y]
                if not (headX and headY) then
                        return nil
                end

                local radius = 0
                if combinedRadiusSq and combinedRadiusSq > 0 then
                        radius = sqrt(combinedRadiusSq)
                end

                if not candidateLookup then
                        candidateIndices, candidateCount, candidateLookup, candidateGeneration = collectSnakeSegmentCandidatesForCircle(centerX, centerY, radius)
                end

                local useCandidateFilter = candidateLookup ~= nil
                if useCandidateFilter and (not candidateIndices or (candidateCount or 0) == 0) then
                        return nil
                end

                local travelled = 0
                local prevX, prevY = headX, headY
                local bodyRadius = context[CTX_BODY_RADIUS] or 0

                for index = 2, #trailRef do
                        local segment = trailRef[index]
                        local cx = segment and (segment.drawX or segment.x)
                        local cy = segment and (segment.drawY or segment.y)
                        if cx and cy then
                                local dx = cx - prevX
                                local dy = cy - prevY
                                local segLen = sqrt(dx * dx + dy * dy)

                                if segLen > 1e-6 then
                                        local shouldTest = not useCandidateFilter or (candidateLookup[segment] == candidateGeneration)
                                        if shouldTest then
                                                local candidate = true
                                                if Saws and Saws.isCollisionCandidate then
                                                        local minX = min(prevX, cx) - bodyRadius
                                                        local minY = min(prevY, cy) - bodyRadius
                                                        local maxX = max(prevX, cx) + bodyRadius
                                                        local maxY = max(prevY, cy) + bodyRadius
                                                        candidate = Saws:isCollisionCandidate(saw, minX, minY, maxX - minX, maxY - minY)
                                                end

                                                if candidate then
                                                        local closestX, closestY, distSq, t = closestPointOnSegment(centerX, centerY, prevX, prevY, cx, cy)
                                                        local along = travelled + segLen * (t or 0)
                                                        if along > context[CTX_GUARD_DISTANCE] and distSq <= combinedRadiusSq then
                                                                if isSawCutPointExposed(saw, centerX, centerY, closestX, closestY) then
                                                                        local cutEvent = context[CTX_CUT_EVENT]
                                                                        cutEvent.index = index
                                                                        cutEvent.cutX = closestX
                                                                        cutEvent.cutY = closestY
                                                                        cutEvent.cutDistance = along
                                                                        return cutEvent
                                                                end
                                                        end
                                                end
                                        end
                                end

                                travelled = travelled + segLen
                                prevX, prevY = cx, cy
                        end
                end

                return nil
        end

        local function checkLaserBodyCollision(snake, state)
                if state.isDead then
                        return false
                end

                local trail = state.trail
                if not (trail and #trail > 2) then
                        return false
                end

                if not (Lasers and Lasers.getEmitterArray) then
                        return false
                end

                local emitters = Lasers:getEmitterArray()
                local emitterCount = emitters and #emitters or 0
                if emitterCount == 0 then
                        return false
                end

                local context = laserCollisionContext
                if not prepareCollisionContext(context, snake, trail, SEGMENT_SPACING * 0.9, SEGMENT_SIZE * 0.5) then
                        resetCollisionContext(context)
                        return false
                end

                local bodyRadius = context[CTX_BODY_RADIUS]

                for index = 1, emitterCount do
                        local beam = emitters[index]
                        if beam and beam.state == "firing" then
                                local rect = beam.beamRect
                                if rect then
                                        local rx, ry, rw, rh = rect[1], rect[2], rect[3], rect[4]
                                        if rw and rh and rw > 0 and rh > 0 then
                                                local expandedX = (rx or 0) - bodyRadius
                                                local expandedY = (ry or 0) - bodyRadius
                                                local expandedW = rw + bodyRadius * 2
                                                local expandedH = rh + bodyRadius * 2

                                                local candidates, candidateCount, candidateLookup, candidateGeneration = collectSnakeSegmentCandidatesForRect(expandedX, expandedY, expandedW, expandedH)
                                                local cutEvent = evaluateTrailRectCut(context, expandedX, expandedY, expandedW, expandedH, candidates, candidateCount, candidateLookup, candidateGeneration)
                                                if cutEvent and context[CTX_SNAKE]:handleSawBodyCut(cutEvent) then
                                                        beam.burnAlpha = 0.92
                                                        resetCollisionContext(context)
                                                        return true
                                                end
                                        end
                                end
                        end
                end

                resetCollisionContext(context)
                return false
        end

        local function checkDartBodyCollision(snake, state)
                if state.isDead then
                        return false
                end

                local trail = state.trail
                if not (trail and #trail > 2) then
                        return false
                end

                if not (Darts and Darts.getEmitterArray) then
                        return false
                end

                local emitters = Darts:getEmitterArray()
                local emitterCount = emitters and #emitters or 0
                if emitterCount == 0 then
                        return false
                end

                local context = dartCollisionContext
                if not prepareCollisionContext(context, snake, trail, SEGMENT_SPACING * 0.85, SEGMENT_SIZE * 0.45) then
                        resetCollisionContext(context)
                        return false
                end

                local bodyRadius = context[CTX_BODY_RADIUS]

                for index = 1, emitterCount do
                        local emitter = emitters[index]
                        if emitter and emitter.state == "firing" then
                                local rect = emitter.shotRect
                                if rect then
                                        local rx, ry, rw, rh = rect[1], rect[2], rect[3], rect[4]
                                        if rw and rh and rw > 0 and rh > 0 then
                                                local expandedX = (rx or 0) - bodyRadius
                                                local expandedY = (ry or 0) - bodyRadius
                                                local expandedW = rw + bodyRadius * 2
                                                local expandedH = rh + bodyRadius * 2

                                                local candidates, candidateCount, candidateLookup, candidateGeneration = collectSnakeSegmentCandidatesForRect(expandedX, expandedY, expandedW, expandedH)
                                                local cutEvent = evaluateTrailRectCut(context, expandedX, expandedY, expandedW, expandedH, candidates, candidateCount, candidateLookup, candidateGeneration)
                                                if cutEvent and context[CTX_SNAKE]:handleSawBodyCut(cutEvent) then
                                                        resetCollisionContext(context)
                                                        return true
                                                end
                                        end
                                end
                        end
                end

                resetCollisionContext(context)
                return false
        end

        local function checkSawBodyCollision(snake, state)
                if state.isDead then
                        return false
                end

                local trail = state.trail
                if not (trail and #trail > 2) then
                        return false
                end

                if not (Saws and Saws.getAll) then
                        return false
                end

                local saws = Saws:getAll()
                if not (saws and #saws > 0) then
                        return false
                end

                local context = sawCollisionContext
                if not prepareCollisionContext(context, snake, trail, SEGMENT_SPACING * 0.9, SEGMENT_SIZE * 0.5) then
                        resetCollisionContext(context)
                        return false
                end

                local bodyRadius = context[CTX_BODY_RADIUS]

                for i = 1, #saws do
                        local saw = saws[i]
                        if isSawActive(saw) then
                                local sx, sy = getSawCenterPosition(saw)
                                if sx and sy then
                                        local sawRadius = (saw.collisionRadius or saw.radius or 0)
                                        local combined = sawRadius + bodyRadius
                                        if combined > 0 then
                                                local candidates, candidateCount, candidateLookup, candidateGeneration = collectSnakeSegmentCandidatesForCircle(sx, sy, combined)
                                                local cutEvent = evaluateTrailCircleCut(context, saw, sx, sy, combined * combined, candidates, candidateCount, candidateLookup, candidateGeneration)
                                                if cutEvent and context[CTX_SNAKE]:handleSawBodyCut(cutEvent) then
                                                        resetCollisionContext(context)
                                                        return true
                                                end
                                        end
                                end
                        end
                end

                resetCollisionContext(context)
                return false
        end

        return {
                checkLaserBodyCollision = checkLaserBodyCollision,
                checkDartBodyCollision = checkDartBodyCollision,
                checkSawBodyCollision = checkSawBodyCollision,
        }
end

return SnakeCollisions
