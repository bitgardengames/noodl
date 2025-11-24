local SnakeOccupancy = require("snakeoccupancy")
local SnakeUtils = require("snakeutils")

local Occupancy = {}

function Occupancy.newState()
        return {
                headCellBuffer = {},
                headOccupancyCol = nil,
                headOccupancyRow = nil,
                toCell = nil,
                newHeadSegmentsMax = 0,
        }
end

function Occupancy.setToCell(state, toCell)
        state.toCell = toCell
        SnakeOccupancy.setToCell(toCell)
end

local function resetHead(state)
        state.headOccupancyCol = nil
        state.headOccupancyRow = nil
end

function Occupancy.resetGrid(state)
        SnakeOccupancy.resetSnakeOccupancyGrid()
        resetHead(state)
end

function Occupancy.ensureGrid(state)
        local ok, reset = SnakeOccupancy.ensureOccupancyGrid()
        if reset then
                resetHead(state)
        end

        return ok
end

function Occupancy.rebuildFromTrail(state, trail, headColOverride, headRowOverride)
        if not Occupancy.ensureGrid(state) then
                SnakeOccupancy.resetTrackedSnakeCells()
                SnakeOccupancy.clearSnakeBodyOccupancy()
                resetHead(state)
                SnakeOccupancy.clearSnakeBodySpatialIndex()
                return
        end

        SnakeOccupancy.clearSnakeOccupiedCells()
        SnakeOccupancy.clearSnakeBodyOccupancy()

        if not trail then
                resetHead(state)
                SnakeOccupancy.clearSnakeBodySpatialIndex()
                return
        end

        local assignedHeadCol, assignedHeadRow = nil, nil

        for i = #trail, 1, -1 do
                local segment = trail[i]
                if segment then
                        local x, y = segment.drawX, segment.drawY
                        if x and y then
                                local col, row = state.toCell and state.toCell(x, y)
                                if col and row then
                                        if i == 1 then
                                                if headColOverride and headRowOverride then
                                                        col, row = headColOverride, headRowOverride
                                                end
                                                assignedHeadCol, assignedHeadRow = col, row
                                        end

                                        SnakeOccupancy.recordSnakeOccupiedCell(col, row)

                                        if i ~= 1 then
                                                SnakeOccupancy.addSnakeBodyOccupancy(col, row)
                                        end
                                end
                        end
                end
        end

        SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)

        if assignedHeadCol and assignedHeadRow then
                state.headOccupancyCol = assignedHeadCol
                state.headOccupancyRow = assignedHeadRow
        else
                state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
        end
end

function Occupancy.applyDelta(state, trail, headCellCount, overrideCol, overrideRow, tailMoved, tailAfterCol, tailAfterRow)
        SnakeOccupancy.clearRecentlyVacatedCells()

        if not Occupancy.ensureGrid(state) then
                SnakeOccupancy.resetTrackedSnakeCells()
                SnakeOccupancy.clearSnakeBodyOccupancy()
                resetHead(state)
                SnakeOccupancy.clearSnakeBodySpatialIndex()
                return
        end

        if not trail or #trail == 0 then
                SnakeOccupancy.clearSnakeOccupiedCells()
                SnakeOccupancy.clearSnakeBodyOccupancy()
                resetHead(state)
                SnakeOccupancy.clearSnakeBodySpatialIndex()
                return
        end

        local hasTailCol, hasTailRow = SnakeOccupancy.getSnakeTailCell()
        if not (hasTailCol and hasTailRow) then
                Occupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
                return
        end

        local processedHead = false
        local headCells = state.headCellBuffer

        for i = 1, headCellCount do
                local cell = headCells[i]
                local headCol = cell and cell[1]
                local headRow = cell and cell[2]
                if headCol and headRow then
                        if state.headOccupancyCol ~= headCol or state.headOccupancyRow ~= headRow then
                                processedHead = true
                                local prevHeadCol, prevHeadRow = state.headOccupancyCol, state.headOccupancyRow
                                SnakeOccupancy.recordSnakeOccupiedCell(headCol, headRow)
                                if prevHeadCol and prevHeadRow then
                                        SnakeOccupancy.addSnakeBodyOccupancy(prevHeadCol, prevHeadRow)
                                end
                                state.headOccupancyCol = headCol
                                state.headOccupancyRow = headRow
                        end
                end
        end

        if not processedHead then
                if overrideCol and overrideRow then
                        if state.headOccupancyCol ~= overrideCol or state.headOccupancyRow ~= overrideRow then
                                Occupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
                                return
                        end
                else
                        state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
                end
        end

        if not SnakeOccupancy.syncSnakeHeadSegments(trail, headCellCount, state.newHeadSegmentsMax) then
                SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
                return
        end

        if not tailMoved then
                return
        end

        if not tailAfterCol or not tailAfterRow then
                while true do
                        local col, row = SnakeOccupancy.popSnakeTailCell()
                        if not (col and row) then
                                break
                        end
                        SnakeOccupancy.markRecentlyVacatedCell(col, row)
                        SnakeUtils.setOccupied(col, row, false)
                        SnakeOccupancy.removeSnakeBodyOccupancy(col, row)
                end

                state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
                SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
                return
        end

        local iterations = 0
        while true do
                local tailCol, tailRow = SnakeOccupancy.getSnakeTailCell()
                if not (tailCol and tailRow) then
                        Occupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
                        return
                end

                if tailCol == tailAfterCol and tailRow == tailAfterRow then
                        break
                end

                local removedCol, removedRow = SnakeOccupancy.popSnakeTailCell()
                if not (removedCol and removedRow) then
                        Occupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
                        return
                end

                SnakeOccupancy.markRecentlyVacatedCell(removedCol, removedRow)
                SnakeUtils.setOccupied(removedCol, removedRow, false)
                SnakeOccupancy.removeSnakeBodyOccupancy(removedCol, removedRow)

                iterations = iterations + 1
                if iterations > 1024 then
                        Occupancy.rebuildFromTrail(state, trail, overrideCol, overrideRow)
                        return
                end
        end

        state.headOccupancyCol, state.headOccupancyRow = SnakeOccupancy.getSnakeHeadCell()
        if not SnakeOccupancy.syncSnakeTailSegment(trail) then
                SnakeOccupancy.rebuildSnakeBodySpatialIndex(trail)
        end
end

function Occupancy.getHeadOccupancy(state)
        return state.headOccupancyCol, state.headOccupancyRow
end

function Occupancy.setNewHeadSegmentsMax(state, value)
        state.newHeadSegmentsMax = value
end

return Occupancy
