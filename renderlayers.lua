local ModuleUtil = require("moduleutil")
local SharedCanvas = require("sharedcanvas")

local floor = math.floor
local max = math.max

local RenderLayers = ModuleUtil.create("RenderLayers")

local DEFAULT_LAYER_ORDER = {
		"background",
		"shadows",
		"main",
		"effects",
		"overlay",
}

local canvases = {}
local layerClearedThisFrame = {}
local layerUsedThisFrame = {}
local layerPresent = {}
local layerOrder = {}
local queuedDraws = {}
local canvasWidth = 0
local canvasHeight = 0

local function ensureCanvas(name, width, height)
		local canvas, replaced = SharedCanvas.ensureCanvas(canvases[name], width, height)
		if canvas ~= canvases[name] then
				canvases[name] = canvas
				replaced = true
		end

		return canvas, replaced
end

local function ensureLayerTables(name)
		if not layerPresent[name] then
				layerPresent[name] = true
				layerOrder[#layerOrder + 1] = name
		end

		if layerClearedThisFrame[name] == nil then
				layerClearedThisFrame[name] = false
		end

		if layerUsedThisFrame[name] == nil then
				layerUsedThisFrame[name] = false
		end

		if not queuedDraws[name] then
				queuedDraws[name] = {}
		end
end

local function resetLayerState()
		queuedDraws = {}
		layerOrder = {}
		layerPresent = {}

		for name in pairs(layerClearedThisFrame) do
				layerClearedThisFrame[name] = false
		end

		for name in pairs(layerUsedThisFrame) do
				layerUsedThisFrame[name] = false
		end

		for _, name in ipairs(DEFAULT_LAYER_ORDER) do
				ensureLayerTables(name)
		end
end

function RenderLayers:begin(width, height)
		local w = max(1, floor(width or love.graphics.getWidth() or 1))
		local h = max(1, floor(height or love.graphics.getHeight() or 1))

		if canvasWidth ~= w or canvasHeight ~= h then
				canvasWidth = w
				canvasHeight = h
		end

		resetLayerState()

		for name in pairs(canvases) do
				ensureLayerTables(name)
		end
end

function RenderLayers:queue(layerName, drawFunc)
		if not drawFunc then
				return
		end

		ensureLayerTables(layerName)

		local entries = queuedDraws[layerName]
		entries[#entries + 1] = drawFunc
end

function RenderLayers:withLayer(layerName, drawFunc)
		self:queue(layerName, drawFunc)
end

local function processQueuedDraws()
		local passes = 0
		local maxPasses = 16

		while true do
				local processedAny = false

				for _, layerName in ipairs(layerOrder) do
						local draws = queuedDraws[layerName]
						if draws and #draws > 0 then
								processedAny = true

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

								local i = 1
								while i <= #draws do
										draws[i]()
										i = i + 1
								end

								love.graphics.pop()

								layerUsedThisFrame[layerName] = true
								queuedDraws[layerName] = {}
						end
				end

				if not processedAny then
						break
				end

				passes = passes + 1
				if passes >= maxPasses then
						break
				end
		end
end

local function drawLayers(offsetX, offsetY)
		offsetX = offsetX or 0
		offsetY = offsetY or 0

		for _, name in ipairs(layerOrder) do
				local canvas = canvases[name]
				if canvas and layerUsedThisFrame[name] then
						love.graphics.draw(canvas, offsetX, offsetY)
				end
		end
end

function RenderLayers:present()
		processQueuedDraws()

		love.graphics.push("all")
		love.graphics.setCanvas()
		love.graphics.origin()
		love.graphics.setColor(1, 1, 1, 1)

		drawLayers(0, 0)

		love.graphics.pop()
end

return RenderLayers
