local floor = math.floor
local max = math.max

local SharedCanvas = {}

local MAX_ALLOWED_MSAA = 8

local desiredMSAASamples = nil
local canvasCreationOptions = nil
local maxSupportedSamples = 0

local function updateDesiredSamples(samples)
        if type(samples) ~= "number" then
                samples = 0
        end

        if samples >= 2 then
                samples = floor(samples)
                if samples < 2 then
                        samples = 0
                else
                        if maxSupportedSamples >= 2 then
                                samples = math.min(samples, maxSupportedSamples)
                        end
                        samples = math.min(samples, MAX_ALLOWED_MSAA)
                        if samples < 2 then
                                samples = 0
                        end
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

local function normalizeOverrideSamples(samples)
        if samples == nil then
                return nil
        end

	if type(samples) ~= "number" then
		samples = 0
	end

	samples = floor(samples)
	if samples < 0 then
		samples = 0
	end

        if samples >= 2 then
                if maxSupportedSamples >= 2 then
                        samples = math.min(samples, maxSupportedSamples)
                else
                        samples = 0
                end
                samples = math.min(samples, MAX_ALLOWED_MSAA)
                if samples < 2 then
                        samples = 0
                end
        else
                samples = 0
	end

	return samples
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
	canvasCreationOptions = nil
	maxSupportedSamples = 0

	local limits = love.graphics.getSystemLimits and love.graphics.getSystemLimits()
	local maximumSamples = getMaximumSamplesFromLimits(limits) or 0
	if maximumSamples < 0 then
		maximumSamples = 0
	end
	maxSupportedSamples = maximumSamples

        if maxSupportedSamples >= 2 then
                updateDesiredSamples(math.min(MAX_ALLOWED_MSAA, maxSupportedSamples))
        else
                updateDesiredSamples(0)
        end
end

function SharedCanvas.getDesiredSamples()
        ensureInitialized()
        return desiredMSAASamples or 0
end

function SharedCanvas.isMSAAEnabled()
        return SharedCanvas.getDesiredSamples() >= 2
end

function SharedCanvas.getMaximumSupportedSamples()
        ensureInitialized()
        return maxSupportedSamples or 0
end

function SharedCanvas.setDesiredSamples(samples)
        ensureInitialized()
        updateDesiredSamples(samples)
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

function SharedCanvas.newCanvas(width, height, requestedSamples)
	ensureInitialized()

	local w, h = resolveDimensions(width, height)
	local canvas = nil
	local samples = 0

	local overrideSamples = normalizeOverrideSamples(requestedSamples)
	local usingDefaultSamples = (overrideSamples == nil)
	local targetSamples = 0

	if usingDefaultSamples then
		targetSamples = desiredMSAASamples or 0
	else
		targetSamples = overrideSamples or 0
	end

	local creationOptions = nil
	if usingDefaultSamples then
		creationOptions = canvasCreationOptions
	elseif targetSamples >= 2 then
		creationOptions = {msaa = targetSamples}
	end

	if creationOptions then
		local ok, result = pcall(love.graphics.newCanvas, w, h, creationOptions)
		if ok and result then
			canvas = result
			if canvas.getMSAA then
				samples = canvas:getMSAA() or (creationOptions.msaa or 0)
			else
				samples = creationOptions.msaa or 0
			end

			if usingDefaultSamples and samples ~= (creationOptions.msaa or 0) then
				updateDesiredSamples(samples)
			end
		else
			if usingDefaultSamples then
				updateDesiredSamples(0)
			end
		end
	end

	if not canvas then
		canvas = love.graphics.newCanvas(w, h)
		if canvas.getMSAA then
			samples = canvas:getMSAA() or 0
			if usingDefaultSamples and samples >= 2 and (desiredMSAASamples or 0) < 2 then
				updateDesiredSamples(samples)
			end
		else
			samples = 0
		end
	end

	return canvas, samples
end

function SharedCanvas.ensureCanvas(existingCanvas, width, height, requestedSamples)
	ensureInitialized()

	local w, h = resolveDimensions(width, height)
	local overrideSamples = normalizeOverrideSamples(requestedSamples)
	local targetSamples = 0
	if overrideSamples == nil then
		targetSamples = desiredMSAASamples or 0
	else
		targetSamples = overrideSamples or 0
	end
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
		canvas, samples = SharedCanvas.newCanvas(w, h, overrideSamples)
		return canvas, true, samples
	end

	return canvas, false, samples
end

return SharedCanvas

