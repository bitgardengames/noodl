local floor = math.floor
local max = math.max

local SharedCanvas = {}

local DEFAULT_MSAA = 8

local desiredMSAASamples = nil
local canvasCreationOptions = nil

local function updateDesiredSamples(samples)
	if type(samples) ~= "number" then
		samples = 0
	end

	if samples >= 2 then
		samples = math.floor(samples)
		if samples < 2 then
			samples = 0
		else
			samples = math.min(samples, DEFAULT_MSAA)
		end
	end

	if samples >= 2 then
		desiredMSAASamples = samples
		canvasCreationOptions = {msaa = samples}
	else
		desiredMSAASamples = 0
		canvasCreationOptions = nil
	end
end

local function getMaximumSamplesFromLimits(limits)
	if type(limits) ~= "table" then
		return 0
	end

	local sampleCount = limits.canvasmsaa or limits.msaa or limits.canvasMSAA or limits.MSAA
	if type(sampleCount) ~= "number" then
		return 0
	end

	return sampleCount
end

local function ensureInitialized()
	if desiredMSAASamples ~= nil then
		return
	end

	desiredMSAASamples = 0

	local limits = love.graphics.getSystemLimits and love.graphics.getSystemLimits()
	local maximumSamples = getMaximumSamplesFromLimits(limits)
	if maximumSamples >= 2 then
		desiredMSAASamples = math.min(DEFAULT_MSAA, maximumSamples)
		if desiredMSAASamples >= 2 then
			canvasCreationOptions = {msaa = desiredMSAASamples}
		else
			desiredMSAASamples = 0
			canvasCreationOptions = nil
		end
	end
end

function SharedCanvas.getDesiredSamples()
	ensureInitialized()
	return desiredMSAASamples or 0
end

function SharedCanvas.isMSAAEnabled()
	return SharedCanvas.getDesiredSamples() >= 2
end

local function resolveDimensions(width, height)
	local w = width
	local h = height

	if not w or w < 1 then
		w = love.graphics.getWidth() or 1
	end

	if not h or h < 1 then
		h = love.graphics.getHeight() or 1
	end

	return max(1, floor(w)), max(1, floor(h))
end

function SharedCanvas.newCanvas(width, height)
	ensureInitialized()

	local w, h = resolveDimensions(width, height)
	local canvas = nil
	local samples = 0

	if canvasCreationOptions then
		local ok, result = pcall(love.graphics.newCanvas, w, h, canvasCreationOptions)
		if ok and result then
			canvas = result
			if canvas.getMSAA then
				samples = canvas:getMSAA() or (canvasCreationOptions.msaa or 0)
			else
				samples = canvasCreationOptions.msaa or 0
			end

			if samples ~= (canvasCreationOptions.msaa or 0) then
				updateDesiredSamples(samples)
			end
		else
			updateDesiredSamples(0)
		end
	end

	if not canvas then
		canvas = love.graphics.newCanvas(w, h)
		if canvas.getMSAA then
			samples = canvas:getMSAA() or 0
			if samples >= 2 and SharedCanvas.getDesiredSamples() < 2 then
				updateDesiredSamples(samples)
			end
		else
			samples = 0
		end
	end

	return canvas, samples
end

function SharedCanvas.ensureCanvas(existingCanvas, width, height)
	ensureInitialized()

	local w, h = resolveDimensions(width, height)
	local targetSamples = SharedCanvas.getDesiredSamples()
	local canvas = existingCanvas
	local samples = 0

	if canvas then
		if canvas:getWidth() ~= w or canvas:getHeight() ~= h then
			canvas = nil
		else
			if canvas.getMSAA then
				samples = canvas:getMSAA() or 0
			else
				samples = 0
			end

			if targetSamples >= 2 then
				if samples ~= targetSamples then
					canvas = nil
				end
			elseif samples >= 2 then
				canvas = nil
			end
		end
	end

	if not canvas then
		canvas, samples = SharedCanvas.newCanvas(w, h)
		return canvas, true, samples
	end

	return canvas, false, samples
end

return SharedCanvas