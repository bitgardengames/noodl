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
local layerNeedsStencilThisFrame = {}
local layerPresent = {}
local layerOrder = {}
local queuedDraws = {}
local canvasWidth = 0
local canvasHeight = 0

local function clearArray(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

local function clearMap(t)
	for key in pairs(t) do
		t[key] = nil
	end
end

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

	if layerNeedsStencilThisFrame[name] == nil then
		layerNeedsStencilThisFrame[name] = false
	end

	if not queuedDraws[name] then
		queuedDraws[name] = {}
	end
end

local function clearQueuedDrawEntries(draws)
	if not draws then
		return
	end

	for i = #draws, 1, -1 do
		draws[i] = nil
	end
end

local function resetLayerState()
	for _, draws in pairs(queuedDraws) do
		clearQueuedDrawEntries(draws)
	end

	clearArray(layerOrder)
	clearMap(layerPresent)

	for name in pairs(layerClearedThisFrame) do
		layerClearedThisFrame[name] = false
	end

	for name in pairs(layerUsedThisFrame) do
		layerUsedThisFrame[name] = false
	end

	for name in pairs(layerNeedsStencilThisFrame) do
		layerNeedsStencilThisFrame[name] = false
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

local function shouldEnableStencil(options)
	if options == nil then
		return false
	end

	if type(options) == "table" then
		return not not options.stencil
	end

	return not not options
end

function RenderLayers:queue(layerName, drawFunc, options)
	if not drawFunc then
		return
	end

	ensureLayerTables(layerName)

	if shouldEnableStencil(options) then
		layerNeedsStencilThisFrame[layerName] = true
	end

	local entries = queuedDraws[layerName]
	entries[#entries + 1] = drawFunc
end

function RenderLayers:withLayer(layerName, drawFunc, options)
	self:queue(layerName, drawFunc, options)
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

				local enableStencil = layerNeedsStencilThisFrame[layerName]
				if enableStencil then
					love.graphics.setCanvas({canvas, stencil = true})
				else
					love.graphics.setCanvas(canvas)
				end

				if not layerClearedThisFrame[layerName] then
					if enableStencil then
						love.graphics.clear(0, 0, 0, 0, false, true)
					else
						love.graphics.clear(0, 0, 0, 0)
					end
					layerClearedThisFrame[layerName] = true
				end

				local i = 1
				while i <= #draws do
					draws[i]()
					i = i + 1
				end

				love.graphics.pop()

				layerUsedThisFrame[layerName] = true
				clearQueuedDrawEntries(draws)
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

function RenderLayers:present(offsetX, offsetY)
	processQueuedDraws()

	local transformOffsetX, transformOffsetY = offsetX, offsetY
	if transformOffsetX == nil and transformOffsetY == nil then
		transformOffsetX, transformOffsetY = love.graphics.transformPoint(0, 0)
	end

	love.graphics.push("all")
	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1, 1)

	drawLayers(transformOffsetX or 0, transformOffsetY or 0)

	love.graphics.pop()
end

return RenderLayers
