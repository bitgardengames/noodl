local Audio = require("audio")
local ButtonList = require("buttonlist")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Localization = require("localization")
local RenderLayers = require("renderlayers")
local SnakeDraw = require("snakedraw")
local SawActor = require("sawactor")
local Lasers = require("lasers")
local Rocks = require("rocks")
local SnakeUtils = require("snakeutils")
local Arena = require("arena")

local max = math.max
local min = math.min
local floor = math.floor

local RenderScreen = {
        transitionDuration = 0.35,
}

local ANALOG_DEADZONE = 0.35

local buttonList = ButtonList.new()
local buttons = {}

local layout = {
        screen = {w = 0, h = 0},
        canvas = {x = 0, y = 0, w = 0, h = 0},
        panel = {x = 0, y = 0, w = 0, h = 0, padding = 0},
}

local analogAxisDirections = {horizontal = nil, vertical = nil}

local buttonDefinitions = {
        {id = "renderCapture",         labelKey = "render.capture",           action = "capture"},
        {id = "renderToggleOverlay",   labelKey = "render.toggle_overlay",    action = "toggleOverlay"},
        {id = "renderToggleBackground",labelKey = "render.toggle_background", action = "toggleBackground"},
        {id = "renderBack",            labelKey = "render.back",              action = "dev"},
}

local function copyColor(color)
        if type(color) ~= "table" then
                return {0, 0, 0, 1}
        end

        return {
                color[1] or 0,
                color[2] or 0,
                color[3] or 0,
                color[4] == nil and 1 or color[4],
        }
end

local function clamp(value, minimum, maximum)
        if minimum ~= nil then
                value = max(value, minimum)
        end
        if maximum ~= nil then
                value = min(value, maximum)
        end
        return value
end

local function computeGridIndices(count, total)
        local indices = {}
        if total <= 0 or count <= 0 then
                return indices
        end

        if total <= count then
                for index = 1, count do
                        indices[index] = clamp(index, 1, total)
                end
                return indices
        end

        local spacing = (total + 1) / (count + 1)
        for index = 1, count do
                local position = floor(spacing * index + 0.5)
                indices[index] = clamp(position, 1, total)
        end

        return indices
end

local function countLines(text)
        if not text or text == "" then
                return 1
        end

        local count = 1
        for _ in string.gmatch(text, "\n") do
                count = count + 1
        end
        return count
end

local function resetAnalogAxis()
        analogAxisDirections.horizontal = nil
        analogAxisDirections.vertical = nil
end

local function handleAnalogAxis(axis, value)
        if axis ~= "leftx" and axis ~= "lefty" and axis ~= "rightx" and axis ~= "righty" then
                return
        end

        local axisType = (axis == "lefty" or axis == "righty") and "vertical" or "horizontal"
        local direction
        if value > ANALOG_DEADZONE then
                direction = "positive"
        elseif value < -ANALOG_DEADZONE then
                direction = "negative"
        end

        if not direction then
                analogAxisDirections[axisType] = nil
                return
        end

        if analogAxisDirections[axisType] == direction then
                return
        end

        analogAxisDirections[axisType] = direction

        local delta = direction == "positive" and 1 or -1
        buttonList:moveFocus(delta)
end

local function buildSnakeTrail(startX, startY, segmentSize, totalSegments, direction)
        local trail = {}
        direction = direction or "horizontal"

        local stepX = (direction == "vertical") and 0 or segmentSize
        local stepY = (direction == "vertical") and segmentSize or 0

        for index = 0, totalSegments - 1 do
                local x = startX + stepX * index
                local y = startY + stepY * index
                trail[#trail + 1] = {
                        x = x,
                        y = y,
                        drawX = x,
                        drawY = y,
                }
        end

        return trail
end

local function getHighlightColor(color)
        color = color or {1, 1, 1, 1}
        local r = min(1, color[1] * 1.2 + 0.08)
        local g = min(1, color[2] * 1.2 + 0.08)
        local b = min(1, color[3] * 1.2 + 0.08)
        local a = (color[4] or 1) * 0.75
        return {r, g, b, a}
end

local function drawFruitIcon(cx, cy, radius, color)
        if not (cx and cy and radius) then
                return
        end

        local appleColor = color or Theme.appleColor or {0.9, 0.45, 0.55, 1}
        local highlight = getHighlightColor(appleColor)
        local borderWidth = max(4, radius * 0.22)
        local appleRadius = radius

        local shadowAlpha = 0.3
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.circle("fill", cx + appleRadius * 0.16, cy + appleRadius * 0.18, appleRadius + borderWidth * 0.5, 48)

        love.graphics.setColor(appleColor[1], appleColor[2], appleColor[3], appleColor[4] or 1)
        love.graphics.circle("fill", cx, cy, appleRadius, 64)

        love.graphics.push()
        love.graphics.translate(cx - appleRadius * 0.3, cy - appleRadius * 0.35)
        love.graphics.rotate(-0.35)
        local highlightAlpha = (highlight[4] or 1) * 0.85
        love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
        love.graphics.circle("fill", 0, 0, radius * 0.5, 48)
        love.graphics.pop()

        love.graphics.setLineWidth(borderWidth)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", cx, cy, appleRadius, 64)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1, 1)
end

local function drawCanvasBackground(self)
        local canvas = layout.canvas
        if not (canvas and canvas.w and canvas.h) then
                return
        end

        if self.transparentBackground then
                return
        end

        local cellSize = 32
        love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
        love.graphics.rectangle("fill", canvas.x, canvas.y, canvas.w, canvas.h, 16, 16)

        love.graphics.setColor(0.12, 0.12, 0.16, 0.55)
        local rows = math.ceil(canvas.h / cellSize)
        local cols = math.ceil(canvas.w / cellSize)
        for row = 0, rows - 1 do
                for col = 0, cols - 1 do
                        if (row + col) % 2 == 0 then
                                local x = canvas.x + col * cellSize
                                local y = canvas.y + row * cellSize
                                love.graphics.rectangle("fill", x, y, cellSize, cellSize)
                        end
                end
        end

        love.graphics.setColor(1, 1, 1, 1)
end

local function exportCanvasToFile(self, filename)
        local canvas = layout.canvas
        if not (canvas and canvas.w and canvas.h and canvas.w > 0 and canvas.h > 0) then
                return false, "no_canvas"
        end

        local width = max(1, floor(canvas.w + 0.5))
        local height = max(1, floor(canvas.h + 0.5))
        local captureCanvas = love.graphics.newCanvas(width, height)

        local function drawSceneToCapture()
                RenderLayers:begin(layout.screen.w, layout.screen.h)

                if self.snakeTrail and #self.snakeTrail > 0 then
                        SnakeDraw.run(self.snakeTrail, #self.snakeTrail, self.snakeSegmentSize, nil, nil, nil, nil, nil)
                end

                Rocks:draw()

                RenderLayers:presentToCanvas(captureCanvas, -canvas.x, -canvas.y)

                love.graphics.push("all")
                love.graphics.setCanvas({captureCanvas, stencil = true})
                love.graphics.origin()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setScissor(0, 0, width, height)
                love.graphics.translate(-canvas.x, -canvas.y)

                if self.sawActor and self.sawPosition then
                        self.sawActor:draw(self.sawPosition.x, self.sawPosition.y, 1)
                end

                if self.fruitCenter and self.fruitRadius then
                        drawFruitIcon(self.fruitCenter.x, self.fruitCenter.y, self.fruitRadius)
                end

                Lasers:draw()

                love.graphics.setScissor()
                love.graphics.pop()
        end

        local ok, err = pcall(function()
                drawSceneToCapture()
                local imageData = captureCanvas:newImageData()
                imageData:encode("png", filename)
        end)

        captureCanvas:release()

        if not ok then
                return false, err
        end

        return true
end

local function drawCanvasOverlay(self)
        if not self.showOverlay then
                return
        end

        local canvas = layout.canvas
        if not (canvas and canvas.w and canvas.h) then
                return
        end

        love.graphics.setLineWidth(3)
        local borderColor = Theme.panelBorder or {0.45, 0.72, 0.62, 1}
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * 0.85)
        love.graphics.rectangle("line", canvas.x, canvas.y, canvas.w, canvas.h, 18, 18)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.line(canvas.x + canvas.w / 2, canvas.y, canvas.x + canvas.w / 2, canvas.y + canvas.h)
        love.graphics.line(canvas.x, canvas.y + canvas.h / 2, canvas.x + canvas.w, canvas.y + canvas.h / 2)
        love.graphics.setColor(1, 1, 1, 1)
end

local function copyArenaState()
        return {
                x = Arena.x,
                y = Arena.y,
                width = Arena.width,
                height = Arena.height,
                tileSize = Arena.tileSize,
                cols = Arena.cols,
                rows = Arena.rows,
        }
end
function RenderScreen:applyBackgroundColor()
        if self.transparentBackground then
                Theme.bgColor = {0, 0, 0, 0}
        else
                Theme.bgColor = copyColor(self.savedBgColor or Theme.bgColor)
        end
end

function RenderScreen:ensureOccupancy()
        if self.savedOccupancy == nil then
                self.savedOccupancy = SnakeUtils.occupied
        end

        SnakeUtils.occupied = {}
        SnakeUtils.initOccupancy()
end

function RenderScreen:setupLasers(segmentSize, positions)
        Lasers:reset()
        self:ensureOccupancy()

        local size = segmentSize or SnakeUtils.SEGMENT_SIZE or 24
        local thickness = max(4, size * 0.4)
        local firing = positions and positions.firing
        local idle = positions and positions.idle

        if firing and firing.x and firing.y then
                local beamA = Lasers:spawn(firing.x, firing.y, firing.dir or "horizontal", {
                        beamThickness = thickness,
                })
                if beamA then
                        beamA.state = "firing"
                        beamA.fireTimer = beamA.fireDuration
                        beamA.chargeTimer = 0
                        beamA.fireCooldown = 0
                        beamA.flashTimer = 0.4
                        beamA.burnAlpha = 0.8
                        beamA.baseGlow = 0.6
                        beamA.telegraphStrength = 0
                end
        end

        if idle and idle.x and idle.y then
                local beamB = Lasers:spawn(idle.x, idle.y, idle.dir or "vertical", {
                        beamThickness = thickness,
                })
                if beamB then
                        beamB.state = "cooldown"
                        beamB.fireTimer = 0
                        beamB.chargeTimer = beamB.baseChargeDuration
                        beamB.fireCooldown = 0
                        beamB.flashTimer = 0
                        beamB.burnAlpha = 0
                        beamB.baseGlow = 0.2
                        beamB.telegraphStrength = 0
                end
        end
end

function RenderScreen:setupRocks(positions)
        Rocks:reset()
        if not positions or #positions == 0 then
                return
        end

        for _, pos in ipairs(positions) do
                if pos.x and pos.y then
                        Rocks:spawn(pos.x, pos.y)
                end
        end

        local rocks = Rocks:getAll()
        for _, rock in ipairs(rocks) do
                rock.phase = "done"
                rock.scaleX = 1
                rock.scaleY = 1
                rock.offsetY = 0
                rock.timer = 1
        end
end

function RenderScreen:rebuildScene()
        local canvas = layout.canvas
        if not canvas then
                return
        end

        local tileSize = Arena.tileSize or SnakeUtils.SEGMENT_SIZE or 24
        local cols = max(1, Arena.cols or floor((canvas.w or tileSize) / tileSize))
        local rows = max(1, Arena.rows or floor((canvas.h or tileSize) / tileSize))

        local gridCols = 3
        local gridRows = 2
        local columnTiles = computeGridIndices(gridCols, cols)
        local rowTiles = computeGridIndices(gridRows, rows)

        local function tileCenter(col, row)
                local cx = canvas.x + (col - 0.5) * tileSize
                local cy = canvas.y + (row - 0.5) * tileSize
                return cx, cy
        end

        self.snakeSegmentSize = tileSize

        local snakeRow = rowTiles[1] or clamp(floor(rows * 0.3), 1, rows)
        local totalSegments = clamp(floor(cols * 0.35), 6, min(12, cols))
        local startColLimit = max(1, cols - totalSegments + 1)
        local baseCol = columnTiles[1] or clamp(floor(cols * 0.2), 1, cols)
        local startCol = clamp(baseCol - floor(totalSegments / 2), 1, startColLimit)
        if startCol + totalSegments - 1 > cols then
                totalSegments = max(1, cols - startCol + 1)
        end

        if totalSegments < 1 then
                self.snakeTrail = {}
        else
                local startX, startY = tileCenter(startCol, snakeRow)
                self.snakeTrail = buildSnakeTrail(startX, startY, tileSize, totalSegments, "horizontal")
        end

        local fruitCol = columnTiles[2] or clamp(floor(cols * 0.5), 1, cols)
        local fruitRow = rowTiles[1] or snakeRow
        local fruitX, fruitY = tileCenter(fruitCol, fruitRow)
        self.fruitCenter = {
                x = fruitX,
                y = fruitY,
        }
        self.fruitRadius = max(4, (tileSize - 2) * 0.5)

        if not self.sawActor then
                self.sawActor = SawActor.new({
                        radius = tileSize,
                        trackLength = tileSize * 4,
                        moveSpeed = 0,
                        progress = 0.5,
                        dir = "horizontal",
                        sinkProgress = 0.18,
                        side = "right",
                        spinSpeed = 4.2,
                })
        end

        self.sawActor.radius = tileSize
        self.sawActor.trackLength = tileSize * 4
        self.sawActor.moveSpeed = 0
        self.sawActor.progress = 0.5
        self.sawActor.sinkProgress = 0.18
        self.sawActor.side = "right"
        self.sawActor.dir = "horizontal"
        self.sawActor.spinSpeed = 4.2

        local sawCol = columnTiles[2] or fruitCol
        local sawRow = rowTiles[2] or clamp(floor(rows * 0.7), 1, rows)
        local sawX, sawY = tileCenter(sawCol, sawRow)
        self.sawPosition = {
                x = sawX,
                y = sawY,
        }

        local rockBaseCol = columnTiles[1] or startCol
        local rockBaseRow = rowTiles[2] or sawRow
        local rockCols = {
                rockBaseCol,
                clamp(rockBaseCol + 1, 1, cols),
                rockBaseCol,
                clamp(rockBaseCol + 1, 1, cols),
        }
        local rockRows = {
                rockBaseRow,
                rockBaseRow,
                clamp(rockBaseRow + 1, 1, rows),
                clamp(rockBaseRow + 1, 1, rows),
        }
        local rockPositions = {}
        for index = 1, #rockCols do
                local rx, ry = tileCenter(rockCols[index], rockRows[index])
                rockPositions[#rockPositions + 1] = {x = rx, y = ry}
        end

        local laserCol = columnTiles[3] or clamp(floor(cols * 0.8), 1, cols)
        local firingLaserX, firingLaserY = tileCenter(laserCol, rowTiles[1] or fruitRow)
        local idleLaserX, idleLaserY = tileCenter(laserCol, rowTiles[2] or sawRow)

        self:setupLasers(tileSize, {
                firing = {x = firingLaserX, y = firingLaserY, dir = "horizontal"},
                idle = {x = idleLaserX, y = idleLaserY, dir = "vertical"},
        })
        self:setupRocks(rockPositions)
end

function RenderScreen:updateLayout()
        local sw, sh = Screen:get()
        layout.screen.w = sw
        layout.screen.h = sh

        if not self.savedArena then
                self.savedArena = copyArenaState()
        end

        if self.savedArena then
                Arena.width = self.savedArena.width
                Arena.height = self.savedArena.height
                Arena.tileSize = self.savedArena.tileSize
        end

        Arena:updateScreenBounds(sw, sh)
        layout.canvas.x = Arena.x or 0
        layout.canvas.y = Arena.y or 0
        layout.canvas.w = Arena.width or 792
        layout.canvas.h = Arena.height or 600

        layout.panel.padding = UI.spacing.panelPadding or 20

        if self.showOverlay then
                local panelWidth = min(360, sw * 0.32)
                local margin = 24
                local panelX = layout.canvas.x + layout.canvas.w + margin
                if panelX + panelWidth > sw - margin then
                        panelX = margin
                end

                local panelY = margin
                layout.panel.x = panelX
                layout.panel.y = panelY
                layout.panel.w = panelWidth

                local headingFont = UI.fonts.heading
                local bodyFont = UI.fonts.body
                local smallFont = UI.fonts.small

                local headingHeight = headingFont and headingFont:getHeight() or 32
                local bodyHeight = bodyFont and bodyFont:getHeight() or 22
                local smallHeight = smallFont and smallFont:getHeight() or 16

                local description = Localization:get("render.description")
                local shortcuts = Localization:get("render.shortcuts")
                local descriptionLines = countLines(description)
                local shortcutLines = countLines(shortcuts)

                local buttonHeight = UI.spacing.buttonHeight or 60
                local buttonSpacing = UI.spacing.buttonSpacing or 16
                local buttonCount = #buttonDefinitions
                local buttonStackHeight = buttonCount * buttonHeight + (buttonCount - 1) * buttonSpacing

                local panelHeight = layout.panel.padding * 2
                panelHeight = panelHeight + headingHeight
                panelHeight = panelHeight + 12
                panelHeight = panelHeight + bodyHeight
                panelHeight = panelHeight + 10
                panelHeight = panelHeight + descriptionLines * smallHeight
                panelHeight = panelHeight + 8
                panelHeight = panelHeight + shortcutLines * smallHeight
                panelHeight = panelHeight + 24
                panelHeight = panelHeight + buttonStackHeight

                layout.panel.h = panelHeight
                layout.panel.headingHeight = headingHeight
                layout.panel.bodyHeight = bodyHeight
                layout.panel.smallHeight = smallHeight
                layout.panel.descriptionLines = descriptionLines
                layout.panel.shortcutLines = shortcutLines

                local buttonX = panelX + (panelWidth - (UI.spacing.buttonWidth or 240)) / 2
                local buttonStartY = panelY + layout.panel.padding + headingHeight + 12 + bodyHeight + 10 + descriptionLines * smallHeight + 8 + shortcutLines * smallHeight + 24

                local defs = {}
                for index, entry in ipairs(buttonDefinitions) do
                        defs[#defs + 1] = {
                                id = entry.id,
                                x = buttonX,
                                y = buttonStartY + (index - 1) * (buttonHeight + buttonSpacing),
                                w = UI.spacing.buttonWidth,
                                h = buttonHeight,
                                labelKey = entry.labelKey,
                                action = entry.action,
                                hovered = false,
                                scale = 1,
                                alpha = 1,
                                offsetY = 0,
                        }
                end

                buttons = buttonList:reset(defs)
        else
                buttons = buttonList:reset({})
        end

        self:rebuildScene()
end
function RenderScreen:enter()
        UI.clearButtons()
        resetAnalogAxis()
        self.transparentBackground = true
        self.showOverlay = true
        self.statusMessage = nil
        self.statusTimer = nil
        self.savedBgColor = copyColor(Theme.bgColor or {0, 0, 0, 1})
        self.savedArena = copyArenaState()
        self.savedOccupancy = SnakeUtils.occupied
        self:applyBackgroundColor()
        self.sawActor = self.sawActor or SawActor.new({
                radius = 48,
                trackLength = 160,
                moveSpeed = 0,
                progress = 0.5,
                dir = "horizontal",
                sinkProgress = 0.18,
                side = "right",
                spinSpeed = 4.2,
        })
        self:updateLayout()
end

function RenderScreen:leave()
        if self.savedBgColor then
                Theme.bgColor = copyColor(self.savedBgColor)
        end

        Lasers:reset()
        Rocks:reset()

        if self.savedOccupancy ~= nil then
                SnakeUtils.occupied = self.savedOccupancy
                self.savedOccupancy = nil
        end

        if self.savedArena then
                Arena.x = self.savedArena.x
                Arena.y = self.savedArena.y
                Arena.width = self.savedArena.width
                Arena.height = self.savedArena.height
                Arena.tileSize = self.savedArena.tileSize
                Arena.cols = self.savedArena.cols
                Arena.rows = self.savedArena.rows
                self.savedArena = nil
        end
end

local function handleAction(self, action)
        if not action then
                return nil
        end

        if action == "dev" then
                Audio:playSound("click")
                return "dev"
        elseif action == "toggleOverlay" then
                Audio:playSound("click")
                self.showOverlay = not self.showOverlay
                self:updateLayout()
        elseif action == "toggleBackground" then
                Audio:playSound("click")
                self.transparentBackground = not self.transparentBackground
                self:applyBackgroundColor()
        elseif action == "capture" then
                Audio:playSound("click")
                local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
                local filename = string.format("render_canvas_%s.png", timestamp)
                local ok = exportCanvasToFile(self, filename)
                if ok then
                        self.statusMessage = Localization:get("render.capture_success", {file = filename})
                else
                        self.statusMessage = Localization:get("render.capture_failed")
                end
                self.statusTimer = 4
        end

        return nil
end
function RenderScreen:update(dt)
        local sw, sh = Screen:get()
        if sw ~= layout.screen.w or sh ~= layout.screen.h then
                self:updateLayout()
        end

        if self.sawActor then
                self.sawActor:update(dt)
        end

        if self.statusMessage and self.statusTimer then
                self.statusTimer = max(0, self.statusTimer - dt)
                if self.statusTimer <= 0 then
                        self.statusMessage = nil
                        self.statusTimer = nil
                end
        end

        if #buttons > 0 then
                local mx, my = love.mouse.getPosition()
                buttonList:updateHover(mx, my)
        end
end

local function drawPanel(self)
        if not self.showOverlay then
                return
        end

        local panel = layout.panel
        local padding = panel.padding or 20
        local contentX = panel.x + padding
        local contentWidth = panel.w - padding * 2
        local y = panel.y + padding

        UI.drawPanel(panel.x, panel.y, panel.w, panel.h, {
                fill = {0.14, 0.14, 0.18, 0.94},
                borderColor = Theme.panelBorder,
                shadowOffset = UI.spacing.shadowOffset or 8,
        })

        UI.drawLabel(Localization:get("render.title"), contentX, y, contentWidth, "left", {
                fontKey = "heading",
                color = Theme.accentTextColor,
        })
        y = y + (panel.headingHeight or 32) + 12

        UI.drawLabel(Localization:get("render.subtitle"), contentX, y, contentWidth, "left", {
                fontKey = "body",
                color = Theme.textColor,
        })
        y = y + (panel.bodyHeight or 20) + 10

        UI.drawLabel(Localization:get("render.description"), contentX, y, contentWidth, "left", {
                fontKey = "small",
                color = Theme.mutedTextColor,
        })
        y = y + (panel.smallHeight or 16) * (panel.descriptionLines or 1) + 8

        UI.drawLabel(Localization:get("render.shortcuts"), contentX, y, contentWidth, "left", {
                fontKey = "small",
                color = Theme.mutedTextColor,
        })
        y = y + (panel.smallHeight or 16) * (panel.shortcutLines or 1) + 24

        for _, btn in ipairs(buttons) do
                if btn.labelKey then
                        btn.text = Localization:get(btn.labelKey)
                end
                UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
                UI.drawButton(btn.id)
        end
end

local function drawStatusMessage(self)
        if not self.statusMessage then
                return
        end

        local sw = layout.screen.w
        local sh = layout.screen.h
        local canvas = layout.canvas

        local previousFont = love.graphics.getFont()
        local font = UI.fonts.small or previousFont
        if font then
                love.graphics.setFont(font)
        end

        local textWidth = font and font:getWidth(self.statusMessage) or (#self.statusMessage * 8)
        local textHeight = font and font:getHeight() or 16
        local padding = 10

        local x = canvas and canvas.x or 24
        local y = (canvas and (canvas.y + canvas.h + 16)) or (sh - textHeight - padding * 2 - 24)
        if y + textHeight + padding * 2 > sh - 24 then
                y = sh - textHeight - padding * 2 - 24
        end
        if x + textWidth + padding * 2 > sw - 24 then
                x = sw - textWidth - padding * 2 - 24
        end

        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", x, y, textWidth + padding * 2, textHeight + padding * 2, 8, 8)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(self.statusMessage, x + padding, y + padding)
        love.graphics.setColor(1, 1, 1, 1)

        if previousFont and font ~= previousFont then
                love.graphics.setFont(previousFont)
        end
end

function RenderScreen:draw()
        local canvas = layout.canvas
        local hasCanvas = canvas and canvas.w and canvas.h

        if hasCanvas then
                love.graphics.push("all")
                love.graphics.setScissor(canvas.x, canvas.y, canvas.w, canvas.h)
        end

        drawCanvasBackground(self)

        if hasCanvas then
                love.graphics.setScissor()
        end

        RenderLayers:begin(layout.screen.w, layout.screen.h)
        if self.snakeTrail and #self.snakeTrail > 0 then
                SnakeDraw.run(self.snakeTrail, #self.snakeTrail, self.snakeSegmentSize, nil, nil, nil, nil, nil)
        end
        Rocks:draw()

        if hasCanvas then
                love.graphics.setScissor(canvas.x, canvas.y, canvas.w, canvas.h)
        end

        RenderLayers:present()

        if self.sawActor and self.sawPosition then
                self.sawActor:draw(self.sawPosition.x, self.sawPosition.y, 1)
        end
        if self.fruitCenter and self.fruitRadius then
                drawFruitIcon(self.fruitCenter.x, self.fruitCenter.y, self.fruitRadius)
        end
        Lasers:draw()

        if hasCanvas then
                love.graphics.setScissor()
                love.graphics.pop()
        end

        drawCanvasOverlay(self)
        drawPanel(self)
        drawStatusMessage(self)
end
function RenderScreen:mousepressed(x, y, button)
        if #buttons > 0 then
                buttonList:mousepressed(x, y, button)
        end
end

function RenderScreen:mousereleased(x, y, button)
        if #buttons > 0 then
                local action = buttonList:mousereleased(x, y, button)
                if action then
                        return handleAction(self, action)
                end
        end
end

function RenderScreen:keypressed(key)
        if key == "escape" or key == "backspace" then
                return "dev"
        elseif key == "tab" then
                handleAction(self, "toggleOverlay")
                return
        elseif key == "b" then
                handleAction(self, "toggleBackground")
                return
        elseif key == "p" then
                handleAction(self, "capture")
                return
        end

        if #buttons > 0 then
                if key == "up" or key == "left" then
                        buttonList:moveFocus(-1)
                elseif key == "down" or key == "right" then
                        buttonList:moveFocus(1)
                elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
                        local action = buttonList:activateFocused()
                        if action then
                                return handleAction(self, action)
                        end
                end
        elseif key == "space" then
                handleAction(self, "capture")
        end
end

function RenderScreen:gamepadpressed(_, button)
        if button == "dpup" or button == "dpleft" then
                buttonList:moveFocus(-1)
        elseif button == "dpdown" or button == "dpright" then
                buttonList:moveFocus(1)
        elseif button == "a" or button == "start" then
                local action = buttonList:activateFocused()
                if action then
                        return handleAction(self, action)
                end
        elseif button == "b" then
                return handleAction(self, "dev")
        elseif button == "x" then
                handleAction(self, "toggleBackground")
        elseif button == "y" then
                handleAction(self, "toggleOverlay")
        end
end

RenderScreen.joystickpressed = RenderScreen.gamepadpressed

function RenderScreen:gamepadaxis(_, axis, value)
        handleAnalogAxis(axis, value)
end

RenderScreen.joystickaxis = RenderScreen.gamepadaxis

return RenderScreen
