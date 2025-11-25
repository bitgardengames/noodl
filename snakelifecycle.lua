local floor = math.floor
local sqrt = math.sqrt

local SnakeLifecycle = {}

local function getUpgradesModule()
        return package.loaded["upgrades"]
end

function SnakeLifecycle.new(deps)
        local Arena = deps.Arena
        local SEGMENT_SPACING = deps.SEGMENT_SPACING
        local acquireSegment = deps.acquireSegment
        local assignDirection = deps.assignDirection
        local SnakeRender = deps.SnakeRender
        local renderState = deps.renderState
        local recycleTrail = deps.recycleTrail
        local clearPortalAnimation = deps.clearPortalAnimation
        local SnakeUtils = deps.SnakeUtils
        local Rocks = deps.Rocks
        local DIR_X, DIR_Y = deps.DIR_X, deps.DIR_Y
        local resetSnakeOccupancyGrid = deps.resetSnakeOccupancyGrid
        local clearSnakeBodyOccupancy = deps.clearSnakeBodyOccupancy

        local function buildInitialTrail(segmentCount, direction)
                local t = {}
                local midCol = floor(Arena.cols / 2)
                local midRow = floor(Arena.rows / 2)
                local startX, startY = Arena:getCenterOfTile(midCol, midRow)

                for i = 0, segmentCount - 1 do
                        local cx = startX - i * SEGMENT_SPACING * direction[DIR_X]
                        local cy = startY - i * SEGMENT_SPACING * direction[DIR_Y]
                        local segment = acquireSegment()
                        segment.drawX = cx
                        segment.drawY = cy
                        segment.dirX = direction[DIR_X]
                        segment.dirY = direction[DIR_Y]
                        t[#t + 1] = segment
                end

                if #t > 0 then
                        t[1].lengthToPrev = 0
                end

                local total = 0
                for i = 2, #t do
                        local prev = t[i - 1]
                        local curr = t[i]
                        if prev and curr then
                                local dx = (prev.drawX or 0) - (curr.drawX or 0)
                                local dy = (prev.drawY or 0) - (curr.drawY or 0)
                                local length = sqrt(dx * dx + dy * dy)
                                curr.lengthToPrev = length
                                total = total + length
                        end
                end

                return t, total
        end

        local function load(snake, state)
                assignDirection(state.direction, 1, 0)
                assignDirection(state.pendingDir, 1, 0)
                state.segmentCount = 1
                state.popTimer = 0
                state.moveProgress = 0
                state.isDead = false
                snake.shieldFlashTimer = 0
                snake.hazardGraceTimer = 0
                snake.damageFlashTimer = 0
                snake.tailHitFlashTimer = 0

                recycleTrail(state.trail)
                local newTrail, trailLength = buildInitialTrail(state.segmentCount, state.direction)
                state.trail = newTrail
                state.trailLength = trailLength
                state.descendingHole = nil

                SnakeRender.clearSeveredPieces(renderState, state.severedPieces, recycleTrail)
                state.severedPieces = {}
                clearPortalAnimation(state.portalAnimation)
                state.portalAnimation = nil

                state.screenW = state.w
                state.screenH = state.h
                local stride = (Arena and Arena.rows or 0) + 16
                if stride <= 0 then
                        stride = 64
                end
                state.cellKeyStride = stride

                return state
        end

        local function isGluttonsWakeActive()
                local Upgrades = getUpgradesModule()
                if not (Upgrades and Upgrades.getEffect) then
                        return false
                end

                local effect = Upgrades:getEffect("gluttonsWake")
                if effect == nil then
                        return false
                end

                if type(effect) == "boolean" then
                        return effect
                end

                if type(effect) == "number" then
                        return effect ~= 0
                end

                return not not effect
        end

        local function spawnGluttonsWakeRock(segment)
                if not segment or not segment.fruitMarker then
                        return
                end

                local x = segment.fruitMarkerX or segment.drawX or segment.x
                local y = segment.fruitMarkerY or segment.drawY or segment.y
                if not (x and y) then
                        return
                end

                Rocks:spawn(x, y)
                local col, row = Arena:getTileFromWorld(x, y)
                if col and row then
                        SnakeUtils.setOccupied(col, row, true)
                end
        end

        local function crystallizeGluttonsWakeSegments(buffer, startIndex, endIndex, upgradeActive)
                if not buffer then
                        return
                end

                if upgradeActive == nil then
                        upgradeActive = isGluttonsWakeActive()
                end

                if not upgradeActive then
                        return
                end

                startIndex = startIndex or 1
                endIndex = endIndex or #buffer
                if endIndex > #buffer then
                        endIndex = #buffer
                end

                for i = startIndex, endIndex do
                        local segment = buffer[i]
                        if segment and segment.fruitMarker then
                                spawnGluttonsWakeRock(segment)
                        end
                end
        end

        local function setDirection(name, isDead, direction, pendingDir)
                if isDead then
                        return
                end

                local nd = SnakeUtils.calculateDirection(direction, name)
                if nd then
                        assignDirection(pendingDir, nd[DIR_X], nd[DIR_Y])
                end
        end

        local function setDead(state, rebuildOccupancyFromTrail)
                local dead = not not state
                if dead then
                        resetSnakeOccupancyGrid()
                        clearSnakeBodyOccupancy()
                elseif rebuildOccupancyFromTrail then
                        rebuildOccupancyFromTrail()
                end

                return dead
        end

        return {
                buildInitialTrail = buildInitialTrail,
                load = load,
                spawnGluttonsWakeRock = spawnGluttonsWakeRock,
                crystallizeGluttonsWakeSegments = crystallizeGluttonsWakeSegments,
                isGluttonsWakeActive = isGluttonsWakeActive,
                setDirection = setDirection,
                setDead = setDead,
        }
end

return SnakeLifecycle
