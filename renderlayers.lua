local ModuleUtil = require("moduleutil")
local SharedCanvas = require("sharedcanvas")

local floor = math.floor
local max = math.max

local RenderLayers = ModuleUtil.create("RenderLayers")

local LAYERS = {
        "background",
        "shadows",
        "main",
        "overlay",
}

local canvases = {}
local layerClearedThisFrame = {}
local layerUsedThisFrame = {}
local canvasWidth = 0
local canvasHeight = 0
local active = false

local function ensureCanvas(name, width, height)
        local canvas, replaced = SharedCanvas.ensureCanvas(canvases[name], width, height)
        if canvas ~= canvases[name] then
                canvases[name] = canvas
                replaced = true
        end

        return canvas, replaced
end

function RenderLayers:begin(width, height)
        local w = max(1, floor(width or love.graphics.getWidth() or 1))
        local h = max(1, floor(height or love.graphics.getHeight() or 1))

        active = true

        if canvasWidth ~= w or canvasHeight ~= h then
                canvasWidth = w
                canvasHeight = h
        end

        for name in pairs(canvases) do
                layerClearedThisFrame[name] = false
                layerUsedThisFrame[name] = false
        end

        for _, name in ipairs(LAYERS) do
                layerClearedThisFrame[name] = false
                layerUsedThisFrame[name] = false
        end
end

function RenderLayers:push(layerName)
        if not active then
                love.graphics.push("all")
                return
        end

        local canvas, replaced = ensureCanvas(layerName, canvasWidth, canvasHeight)
        if replaced then
                layerClearedThisFrame[layerName] = false
        end

        love.graphics.push("all")
        love.graphics.setCanvas({canvas, stencil = true})

        if not layerClearedThisFrame[layerName] then
                love.graphics.clear(0, 0, 0, 0)
                layerClearedThisFrame[layerName] = true
        end

        layerUsedThisFrame[layerName] = true
end

function RenderLayers:pop()
        love.graphics.pop()
end

function RenderLayers:withLayer(layerName, drawFunc)
        if not drawFunc then
                return
        end

        self:push(layerName)
        drawFunc()
        self:pop()
end

function RenderLayers:isActive()
        return active
end

local function drawLayers(offsetX, offsetY)
        offsetX = offsetX or 0
        offsetY = offsetY or 0

        for _, name in ipairs(LAYERS) do
                local canvas = canvases[name]
                if canvas and layerUsedThisFrame[name] then
                        love.graphics.draw(canvas, offsetX, offsetY)
                end
        end
end

function RenderLayers:present()
        love.graphics.push("all")
        love.graphics.setCanvas()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)

        drawLayers(0, 0)

        love.graphics.pop()

        active = false
end

return RenderLayers
