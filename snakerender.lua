local SnakeDraw = require("snakedraw")
local SnakeCosmetics = require("snakecosmetics")

local abs = math.abs
local max = math.max
local min = math.min

local Render = {}

local STATE_CLIPPED_TRAIL_BUFFER = 1
local STATE_CLIPPED_TRAIL_PROXY = 2
local STATE_CLIPPED_HEAD_X = 3
local STATE_CLIPPED_HEAD_Y = 4

Render.STATE_CLIPPED_TRAIL_BUFFER = STATE_CLIPPED_TRAIL_BUFFER
Render.STATE_CLIPPED_TRAIL_PROXY = STATE_CLIPPED_TRAIL_PROXY
Render.STATE_CLIPPED_HEAD_X = STATE_CLIPPED_HEAD_X
Render.STATE_CLIPPED_HEAD_Y = STATE_CLIPPED_HEAD_Y

function Render.newState()
        return {
                [STATE_CLIPPED_TRAIL_BUFFER] = {},
                [STATE_CLIPPED_TRAIL_PROXY] = {drawX = 0, drawY = 0},
                [STATE_CLIPPED_HEAD_X] = nil,
                [STATE_CLIPPED_HEAD_Y] = nil,
        }
end

local function smoothStep(edge0, edge1, value)
        if edge0 == nil or edge1 == nil or value == nil then
                return 0
        end

        if edge0 == edge1 then
                return value >= edge1 and 1 or 0
        end

        local t = (value - edge0) / (edge1 - edge0)
        if t < 0 then
                t = 0
        elseif t > 1 then
                t = 1
        end

        return t * t * (3 - 2 * t)
end

local function drawStencilCircle(x, y, radius)
        love.graphics.circle("fill", x, y, radius)
end

local function getClippedHeadPosition(state, clipCenterX, clipCenterY, clipRadius)
        local clippedHeadX = state[STATE_CLIPPED_HEAD_X]
        local clippedHeadY = state[STATE_CLIPPED_HEAD_Y]

        if not (clippedHeadX and clippedHeadY) then
                return clippedHeadX, clippedHeadY
        end

        local radius = clipRadius or 0
        if radius > 0 then
                local dx = clippedHeadX - (clipCenterX or 0)
                local dy = clippedHeadY - (clipCenterY or 0)
                if dx * dx + dy * dy < radius * radius then
                        return nil, nil
                end
        end

        return clippedHeadX, clippedHeadY
end

local function clamp01(value)
        return max(0, min(1, value or 0))
end

local function scaleColorAlpha(color, scale)
        local r = 1
        local g = 1
        local b = 1
        local a = 1

        if type(color) == "table" then
                r = color[1] or r
                g = color[2] or g
                b = color[3] or b
                a = color[4] or a
        end

        return {r, g, b, clamp01(a * scale)}
end

local function buildSeveredPalette(fade)
        local palette = SnakeCosmetics and SnakeCosmetics:getPaletteForSkin() or nil
        local bodyColor = palette and palette.body or (SnakeCosmetics and SnakeCosmetics.getBodyColor and SnakeCosmetics:getBodyColor())
        local outlineColor = palette and palette.outline or (SnakeCosmetics and SnakeCosmetics.getOutlineColor and SnakeCosmetics:getOutlineColor())

        local alpha = clamp01(fade or 1)

        return {
                body = scaleColorAlpha(bodyColor, alpha),
                outline = scaleColorAlpha(outlineColor, alpha),
        }
end

local function getOwnerHead(owner)
        if owner and owner.getHead then
                return owner:getHead()
        end

        return nil, nil
end

local function getActiveTrailHead(trailData)
        if not trailData then
                return nil, nil
        end

        local headSeg = trailData[1]
        if not headSeg then
                return nil, nil
        end

        return headSeg.drawX or headSeg.x, headSeg.drawY or headSeg.y
end

local function drawSeveredPieces(state, params, upgradeVisuals)
        local severedPieces = params.severedPieces
        if not severedPieces or #severedPieces == 0 then
                return
        end

        for i = 1, #severedPieces do
                local piece = severedPieces[i]
                local trailData = piece and piece.trail
                if trailData and #trailData > 1 then
                        local remaining = piece.timer or 0
                        local life = piece.life or params.severedLife
                        local fadeDuration = piece.fadeDuration or params.severedFadeDuration
                        local fade = 1

                        if fadeDuration and fadeDuration > 0 then
                                if remaining <= fadeDuration then
                                        fade = clamp01(remaining / fadeDuration)
                                end
                        elseif life and life > 0 then
                                fade = clamp01(remaining / life)
                        end

                        local drawOptions = {
                                drawFace = false,
                                paletteOverride = buildSeveredPalette(fade),
                                overlayEffect = nil,
                                flatStartCap = true,
                        }

                        SnakeDraw.run(
                                trailData,
                                piece.segmentCount or #trailData,
                                params.segmentSize,
                                0,
                                function()
                                        return getActiveTrailHead(trailData)
                                end,
                                0,
                                0,
                                upgradeVisuals,
                                drawOptions
                        )
                end
        end
end

local function setupStencil(hx, hy, clipRadius)
        if clipRadius <= 0 then
                return false
        end

        love.graphics.stencil(function()
                drawStencilCircle(hx, hy, clipRadius)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 0)

        return true
end

local function maybeDrawDescendingHole(descendingHole, hx, hy, clipRadius, shouldDraw, drawDescendingIntoHole)
        if not (clipRadius > 0 and descendingHole and shouldDraw and drawDescendingIntoHole) then
                return
        end

        if abs((descendingHole.x or 0) - hx) < 1e-3 and abs((descendingHole.y or 0) - hy) < 1e-3 then
                love.graphics.setStencilTest("equal", 1)
                drawDescendingIntoHole(descendingHole)
        end
end

function Render.drawClipped(state, params)
        local trail = params.trail
        if not trail or #trail == 0 then
                return
        end

        local hx = params.clipX
        local hy = params.clipY
        local clipRadius = params.clipRadius or 0
        local renderTrail = trail
        local headX, headY = params.headX, params.headY

        if clipRadius > 0 then
                local radiusSq = clipRadius * clipRadius
                local startIndex = 1

                while startIndex <= #trail do
                        local seg = trail[startIndex]
                        local x = seg and (seg.drawX or seg.x)
                        local y = seg and (seg.drawY or seg.y)

                        if not (x and y) then
                                break
                        end

                        local dx = x - hx
                        local dy = y - hy
                        if dx * dx + dy * dy > radiusSq then
                                break
                        end

                        startIndex = startIndex + 1
                end

                if startIndex == 1 then
                        renderTrail = trail
                else
                        local trimmed = state[STATE_CLIPPED_TRAIL_BUFFER]
                        local trimmedLen = #trimmed
                        if trimmedLen > 0 then
                                for i = trimmedLen, 1, -1 do
                                        trimmed[i] = nil
                                end
                        end

                        if startIndex > #trail then
                                renderTrail = trimmed
                        else
                                local prev = trail[startIndex - 1]
                                local curr = trail[startIndex]
                                local px = prev and (prev.drawX or prev.x)
                                local py = prev and (prev.drawY or prev.y)
                                local cx = curr and (curr.drawX or curr.x)
                                local cy = curr and (curr.drawY or curr.y)
                                local ix, iy

                                if px and py and cx and cy and params.findCircleIntersection then
                                        ix, iy = params.findCircleIntersection(px, py, cx, cy, hx, hy, clipRadius)
                                end

                                if not (ix and iy) then
                                        if params.descendingHole and abs((params.descendingHole.x or 0) - hx) < 1e-3 and abs((params.descendingHole.y or 0) - hy) < 1e-3 then
                                                ix = params.descendingHole.entryPointX or px
                                                iy = params.descendingHole.entryPointY or py
                                        else
                                                ix, iy = px, py
                                        end
                                end

                                if ix and iy then
                                        local proxy = state[STATE_CLIPPED_TRAIL_PROXY]
                                        proxy.drawX = ix
                                        proxy.drawY = iy
                                        proxy.x = nil
                                        proxy.y = nil
                                        trimmed[1] = proxy
                                end

                                local insertIndex = ix and iy and 2 or 1
                                for i = startIndex, #trail do
                                        trimmed[insertIndex] = trail[i]
                                        insertIndex = insertIndex + 1
                                end

                                renderTrail = trimmed
                        end
                end
        end

        love.graphics.push("all")
        local upgradeVisuals = params.collectUpgradeVisuals(params.snake)

        local hasStencil = setupStencil(hx, hy, clipRadius)
        local shouldDrawFace = params.descendingHole == nil
        local hideDescendingBody = params.descendingHole and params.descendingHole.fullyConsumed

        if not hideDescendingBody then
                state[STATE_CLIPPED_HEAD_X], state[STATE_CLIPPED_HEAD_Y] = headX, headY
                SnakeDraw.run(
                        renderTrail,
                        params.segmentCount,
                        params.segmentSize,
                        params.popTimer,
                        function()
                                return getClippedHeadPosition(state, hx, hy, clipRadius)
                        end,
                        params.shields or 0,
                        params.shieldFlashTimer or 0,
                        upgradeVisuals,
                        shouldDrawFace
                )
                state[STATE_CLIPPED_HEAD_X], state[STATE_CLIPPED_HEAD_Y] = nil, nil
        end

        maybeDrawDescendingHole(params.descendingHole, hx, hy, clipRadius, hasStencil and not hideDescendingBody, params.drawDescendingIntoHole)

        love.graphics.setStencilTest()
        love.graphics.pop()
end

function Render.clearSeveredPieces(state, severedPieces, recycleTrail)
        if not severedPieces then
                return
        end

        for i = #severedPieces, 1, -1 do
                local piece = severedPieces[i]
                if piece and piece.trail and recycleTrail then
                        recycleTrail(piece.trail)
                        piece.trail = nil
                end
                severedPieces[i] = nil
        end
end

function Render.draw(state, params)
        if params.isDead then
                return
        end

        local upgradeVisuals = params.collectUpgradeVisuals(params.snake)

        drawSeveredPieces(state, params, upgradeVisuals)

        local shouldDrawFace = params.descendingHole == nil
        local hideDescendingBody = params.descendingHole and params.descendingHole.fullyConsumed

        if hideDescendingBody then
                return
        end

        local drawOptions
        if params.portalAnimation then
                drawOptions = {
                        drawFace = shouldDrawFace,
                        portalAnimation = {
                                entryTrail = params.portalAnimation.entryTrail,
                                exitTrail = params.portalAnimation.exitTrail,
                                entryX = params.portalAnimation.entryX,
                                entryY = params.portalAnimation.entryY,
                                exitX = params.portalAnimation.exitX,
                                exitY = params.portalAnimation.exitY,
                                progress = params.portalAnimation.progress or 0,
                                duration = params.portalAnimation.duration or 0.3,
                                timer = params.portalAnimation.timer or 0,
                                entryHole = params.portalAnimation.entryHole,
                                exitHole = params.portalAnimation.exitHole,
                        },
                }
        else
                drawOptions = shouldDrawFace
        end

        local tailHitFlash
        if params.tailHitFlashTimer and params.tailHitFlashTimer > 0 then
                tailHitFlash = clamp01(params.tailHitFlashTimer / params.tailHitFlashDuration)
        end

        if tailHitFlash and tailHitFlash > 0 then
                if type(drawOptions) ~= "table" then
                        drawOptions = {drawFace = drawOptions ~= false}
                else
                        if drawOptions.drawFace == nil then
                                drawOptions.drawFace = true
                        end
                end

                drawOptions.tailHitFlash = tailHitFlash
                drawOptions.tailHitFlashColor = params.tailHitFlashColor
        end

        SnakeDraw.run(
                params.trail,
                params.segmentCount,
                params.segmentSize,
                params.popTimer,
                function()
                        return getOwnerHead(params.snake)
                end,
                params.shields or 0,
                params.shieldFlashTimer or 0,
                upgradeVisuals,
                drawOptions
        )
end

function Render.updatePortalAnimation(portalAnimation, dt)
        if not portalAnimation then
                return
        end

        portalAnimation.timer = (portalAnimation.timer or 0) + dt
        local progress = max(0, min(1, (portalAnimation.timer or 0) / (portalAnimation.duration or 0.3)))
        portalAnimation.progress = progress

        if portalAnimation.entryHole then
                local entryOpen = smoothStep(0.0, 0.22, progress)
                local entryClose = smoothStep(0.68, 1, progress)
                portalAnimation.entryHole.open = entryOpen * (1 - entryClose)
                portalAnimation.entryHole.visibility = entryOpen * (1 - entryClose)
        end

        if portalAnimation.exitHole then
                local exitOpen = smoothStep(0.08, 0.48, progress)
                local exitSettle = smoothStep(0.82, 1, progress)
                portalAnimation.exitHole.open = exitOpen * (1 - exitSettle)
                portalAnimation.exitHole.visibility = exitOpen * (0.75 + 0.25 * (1 - exitSettle))
        end

        return portalAnimation.progress >= 1
end

return Render
