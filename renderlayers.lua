local ModuleUtil = require("moduleutil")

local RenderLayers = ModuleUtil.create("RenderLayers")

local LAYERS = {
        "background",
        "shadows",
        "main",
        "overlay",
}

local canvases = {}
local canvasWidth = 0
local canvasHeight = 0

local function ensureCanvas(name, width, height)
        local w = width
        local h = height

        if not w or w < 1 then
                w = math.max(1, love.graphics.getWidth() or 1)
        end

        if not h or h < 1 then
                h = math.max(1, love.graphics.getHeight() or 1)
        end

        local canvas = canvases[name]
        if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
                canvas = love.graphics.newCanvas(w, h)
                canvases[name] = canvas
        end
        return canvas
end

function RenderLayers:begin(width, height)
        local w = math.max(1, math.floor(width or love.graphics.getWidth() or 1))
        local h = math.max(1, math.floor(height or love.graphics.getHeight() or 1))

        if canvasWidth ~= w or canvasHeight ~= h then
                canvasWidth = w
                canvasHeight = h
        end

        for _, name in ipairs(LAYERS) do
                local canvas = ensureCanvas(name, canvasWidth, canvasHeight)
                love.graphics.push("all")
                love.graphics.setCanvas({ canvas, stencil = true })
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.pop()
        end
end

function RenderLayers:push(layerName)
        local canvas = canvases[layerName]
        if not canvas then
                canvas = ensureCanvas(layerName, canvasWidth, canvasHeight)
        end

        love.graphics.push("all")
        love.graphics.setCanvas({ canvas, stencil = true })
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

function RenderLayers:present()
        love.graphics.push("all")
        love.graphics.setCanvas()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)

        for _, name in ipairs(LAYERS) do
                local canvas = canvases[name]
                if canvas then
                        love.graphics.draw(canvas, 0, 0)
                end
        end

        love.graphics.pop()
end

return RenderLayers
