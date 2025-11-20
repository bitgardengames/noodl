local Color = {}

Color.black = {0, 0, 0, 1}
Color.white = {1, 1, 1, 1}

local EMPTY_OPTIONS = {}

local function clamp01(value)
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

function Color.copy(color, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.black
        local alphaOverride = options.alpha
        local defaultAlpha = options.defaultAlpha

	local source = color
	if type(source) ~= "table" then
		source = nil
	end

	target[1] = (source and source[1]) or (default and default[1]) or 0
	target[2] = (source and source[2]) or (default and default[2]) or 0
	target[3] = (source and source[3]) or (default and default[3]) or 0

	local alpha = source and source[4]
	if alpha == nil then
		if alphaOverride ~= nil then
			alpha = alphaOverride
		elseif defaultAlpha ~= nil then
			alpha = defaultAlpha
		elseif default and default[4] ~= nil then
			alpha = default[4]
		else
			alpha = 1
		end
	end

	target[4] = alpha
	return target
end

function Color.copyIfPresent(color, options)
	if type(color) ~= "table" then
		return nil
	end
	return Color.copy(color, options)
end

function Color.lighten(color, amount, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.black
        local defaultAlpha = options.defaultAlpha
        local preserveAlpha = options.preserveAlpha or false
        local alphaMin = options.alphaMin or 0.65
        local alphaMax = options.alphaMax or 1

	local factor = clamp01(amount or 0.35)

	local r = (type(color) == "table" and color[1]) or (default and default[1]) or 0
	local g = (type(color) == "table" and color[2]) or (default and default[2]) or 0
	local b = (type(color) == "table" and color[3]) or (default and default[3]) or 0
	local baseAlpha = (type(color) == "table" and color[4])
	if baseAlpha == nil then
		if defaultAlpha ~= nil then
			baseAlpha = defaultAlpha
		elseif default and default[4] ~= nil then
			baseAlpha = default[4]
		else
			baseAlpha = 1
		end
	end

	target[1] = clamp01(r + (1 - r) * factor)
	target[2] = clamp01(g + (1 - g) * factor)
	target[3] = clamp01(b + (1 - b) * factor)

	if preserveAlpha then
		target[4] = baseAlpha
	else
		local alphaScale = alphaMin + factor * (alphaMax - alphaMin)
		target[4] = baseAlpha * alphaScale
	end

	return target
end

function Color.darken(color, amount, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.black
        local defaultAlpha = options.defaultAlpha
        local preserveAlpha = options.preserveAlpha ~= false
        local scaleAlpha = options.scaleAlpha or false
        local scale = options.scale

	local factor = clamp01(amount or 0.35)
	if scale == nil then
		scale = 1 - factor
	else
		scale = clamp01(scale)
	end

	local r = (type(color) == "table" and color[1]) or (default and default[1]) or 0
	local g = (type(color) == "table" and color[2]) or (default and default[2]) or 0
	local b = (type(color) == "table" and color[3]) or (default and default[3]) or 0
	local baseAlpha = (type(color) == "table" and color[4])
	if baseAlpha == nil then
		if defaultAlpha ~= nil then
			baseAlpha = defaultAlpha
		elseif default and default[4] ~= nil then
			baseAlpha = default[4]
		else
			baseAlpha = 1
		end
	end

	target[1] = clamp01(r * scale)
	target[2] = clamp01(g * scale)
	target[3] = clamp01(b * scale)

	if scaleAlpha then
		target[4] = baseAlpha * scale
	elseif preserveAlpha then
		target[4] = baseAlpha
	else
		target[4] = baseAlpha * (1 - factor)
	end

	return target
end

function Color.withAlpha(color, alpha, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.black
        local defaultAlpha = options.defaultAlpha
        local alphaOverride = options.alpha

        local source = color
        if type(source) ~= "table" then
                source = nil
        end

        target[1] = (source and source[1]) or (default and default[1]) or 0
        target[2] = (source and source[2]) or (default and default[2]) or 0
        target[3] = (source and source[3]) or (default and default[3]) or 0

        local baseAlpha = source and source[4]
        if baseAlpha == nil then
                if alphaOverride ~= nil then
                        baseAlpha = alphaOverride
                elseif defaultAlpha ~= nil then
                        baseAlpha = defaultAlpha
                elseif default and default[4] ~= nil then
                        baseAlpha = default[4]
                else
                        baseAlpha = 1
                end
        end

        target[4] = (baseAlpha or 1) * (alpha or 1)
        return target
end

function Color.desaturate(color, amount, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.white
        local defaultAlpha = options.defaultAlpha
	local t = type(color) == "table" and color or default

	local r = (t and t[1]) or 1
	local g = (t and t[2]) or 1
	local b = (t and t[3]) or 1
	local a = (t and t[4])
	if a == nil then
		if defaultAlpha ~= nil then
			a = defaultAlpha
		elseif default and default[4] ~= nil then
			a = default[4]
		else
			a = 1
		end
	end

	local saturation = clamp01(amount or 0.5)
	local grey = r * 0.299 + g * 0.587 + b * 0.114

	target[1] = r + (grey - r) * saturation
	target[2] = g + (grey - g) * saturation
	target[3] = b + (grey - b) * saturation
	target[4] = a

	return target
end

function Color.clampComponent(value)
	if value ~= value then
		return 0
	end
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

function Color.scale(color, factor, options)
        options = options or EMPTY_OPTIONS
        local target = options.target or {}
        local default = options.default or Color.white
        local defaultAlpha = options.defaultAlpha

	local t = type(color) == "table" and color or default
	local scale = factor or 1

	target[1] = clamp01((t and t[1] or 1) * scale)
	target[2] = clamp01((t and t[2] or 1) * scale)
	target[3] = clamp01((t and t[3] or 1) * scale)

	local alpha = (t and t[4])
	if alpha == nil then
		if defaultAlpha ~= nil then
			alpha = defaultAlpha
		elseif default and default[4] ~= nil then
			alpha = default[4]
		else
			alpha = 1
		end
	end

	local alphaFactor = options.alphaFactor
	if alphaFactor == nil then
		if options.scaleAlpha then
			alphaFactor = scale
		else
			alphaFactor = 1
		end
	end

	target[4] = alpha * alphaFactor

	return target
end

return Color
