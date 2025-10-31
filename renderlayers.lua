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
local reusableCommandPool = {}
local reusableCommandPoolSize = 0
local table_unpack = table.unpack
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

local function acquireCommandTable()
        if reusableCommandPoolSize > 0 then
                local command = reusableCommandPool[reusableCommandPoolSize]
                reusableCommandPool[reusableCommandPoolSize] = nil
                reusableCommandPoolSize = reusableCommandPoolSize - 1
                return command
        end

        return {}
end

local function releaseCommandTable(command)
        local numericLength = command._length or #command

        for i = 1, numericLength do
                command[i] = nil
        end

        command._length = nil
        command.fn = nil
        command.args = nil
        command.argCount = nil
        command.argStart = nil
        command.argEnd = nil

        reusableCommandPoolSize = reusableCommandPoolSize + 1
        reusableCommandPool[reusableCommandPoolSize] = command
end

function RenderLayers:acquireCommand(fn, ...)
        local command = acquireCommandTable()

        local argc = select("#", ...)
        command[1] = fn
        for i = 1, argc do
                command[i + 1] = select(i, ...)
        end

        command._length = argc + 1

        return command
end

local function normalizeCommand(layerName, command)
        if type(command) == "function" then
                return command
        end

        if type(command) == "table" then
                return command
        end

        if command ~= nil then
                error(string.format("RenderLayers:queue expected function or table for layer '%s'", tostring(layerName)))
        end

        return nil
end

function RenderLayers:queue(layerName, drawCommand)
        local command = normalizeCommand(layerName, drawCommand)

        if not command then
                return
        end

        ensureLayerTables(layerName)

        local entries = queuedDraws[layerName]
        entries[#entries + 1] = command
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
                                        local entry = draws[i]
                                        local entryType = type(entry)

                                        if entryType == "function" then
                                                entry()
                                        elseif entryType == "table" then
                                                local fn = entry.fn or entry[1]
                                                if fn then
                                                        local argStart = entry.argStart
                                                        if argStart then
                                                                local argEnd = entry.argEnd or entry.argCount or entry._length or #entry
                                                                fn(table_unpack(entry, argStart, argEnd))
                                                        else
                                                                local argCount = entry.argCount or entry._length or #entry
                                                                if entry.args then
                                                                        local args = entry.args
                                                                        local argsCount = entry.argCount or #args
                                                                        fn(table_unpack(args, 1, argsCount))
                                                                elseif argCount > 1 then
                                                                        fn(table_unpack(entry, 2, argCount))
                                                                else
                                                                        fn()
                                                                end
                                                        end
                                                end

                                                releaseCommandTable(entry)
                                        end

                                        draws[i] = nil
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