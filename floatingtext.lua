local UI = require("ui")

local FloatingText = {}

local entries = {}

local lg = love.graphics
local lm = love.math
local random = lm.random
local sin, cos = math.sin, math.cos
local max = math.max

local defaultFont = UI.fonts.subtitle or UI.fonts.display or lg.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 24)

local baseColor = UI.colors.accentText or UI.colors.text or { 1, 1, 1, 1 }

local DEFAULTS = {
	color = { baseColor[1], baseColor[2], baseColor[3], 1 },
	duration = 1.0,
	riseSpeed = 30,
	scale = 0.9,
	pop = {
		scale = 1.12,
		duration = 0.18,
	},
	wobble = {
		magnitude = 5,
		frequency = 2.4,
	},
	drift = 12,
	fadeStart = 0.35,
	rotation = math.rad(5),
	shadow = {
		offsetX = 2,
		offsetY = 2,
		alpha = 0.35,
	},
	glow = {
		color = { baseColor[1], baseColor[2], baseColor[3], 0.55 },
		frequency = 3.4,
		magnitude = 0.45,
	},
	jitter = 0.8,
}

local function cloneColor(color)
	local source = color or DEFAULTS.color

	return {
		source[1] or DEFAULTS.color[1],
		source[2] or DEFAULTS.color[2],
		source[3] or DEFAULTS.color[3],
		source[4] == nil and DEFAULTS.color[4] or source[4],
	}
end

local function clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function easeOutCubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function easeInCubic(t)
	return t * t * t
end

local function easeOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	local progress = t - 1
	return 1 + c3 * (progress * progress * progress) + c1 * (progress * progress)
end

local function buildShadow(shadow)
	local defaults = DEFAULTS.shadow

	if shadow == nil then
		return {
			offsetX = defaults.offsetX,
			offsetY = defaults.offsetY,
			alpha = defaults.alpha,
		}
	end

	return {
		offsetX = shadow.offsetX or defaults.offsetX,
		offsetY = shadow.offsetY or defaults.offsetY,
		alpha = shadow.alpha == nil and defaults.alpha or shadow.alpha,
	}
end

local function buildGlow(glow)
	if glow == false then
		return nil
	end

	local defaults = DEFAULTS.glow
	if not defaults then
		return nil
	end

	if glow == nil then
		return {
			color = {
				defaults.color[1],
				defaults.color[2],
				defaults.color[3],
				defaults.color[4] or 1,
			},
			frequency = defaults.frequency,
			magnitude = defaults.magnitude,
		}
	end

	local sourceColor = glow.color or defaults.color

	return {
		color = {
			sourceColor[1] or defaults.color[1],
			sourceColor[2] or defaults.color[2],
			sourceColor[3] or defaults.color[3],
			sourceColor[4] == nil and (defaults.color[4] or 1) or sourceColor[4],
		},
		frequency = glow.frequency or defaults.frequency,
		magnitude = glow.magnitude or defaults.magnitude,
	}
end

local function resolveFade(duration, fadeStart)
	if duration <= 0 then
		return nil, nil
	end

	local startTime = duration * clamp(fadeStart, 0, 0.99)
	local fadeDuration = max(duration - startTime, 0.001)

	return startTime, fadeDuration
end

local function resolveDrift(options)
	if options.drift ~= nil then
		return options.drift
	end

	if DEFAULTS.drift == 0 then
		return 0
	end

	return (random() * 2 - 1) * DEFAULTS.drift
end

local function resolveRiseDuration(duration, riseSpeed, options)
	if options.riseDistance ~= nil then
		return options.riseDistance
	end

	local speed = riseSpeed or DEFAULTS.riseSpeed
	return speed * max(duration, 0.05)
end

function FloatingText:add(text, x, y, color, duration, riseSpeed, font, options)
	assert(text ~= nil, "FloatingText:add requires text")

	options = options or {}
	font = font or defaultFont
	text = tostring(text)

	local fontWidth = font:getWidth(text)
	local fontHeight = font:getHeight()
	local entryDuration = (duration ~= nil and duration > 0) and duration or DEFAULTS.duration
	local entryColor = color and cloneColor(color) or cloneColor(DEFAULTS.color)
	local baseScale = options.scale or DEFAULTS.scale
	local popScale = baseScale * (options.popScaleFactor or DEFAULTS.pop.scale)
	local popDuration = options.popDuration or DEFAULTS.pop.duration
	local wobbleMagnitude = options.wobbleMagnitude or DEFAULTS.wobble.magnitude
	local wobbleFrequency = options.wobbleFrequency or DEFAULTS.wobble.frequency
	local fadeStart = options.fadeStart or DEFAULTS.fadeStart
	local drift = resolveDrift(options)
	local rise = resolveRiseDuration(entryDuration, riseSpeed, options)
	local rotationAmplitude = options.rotationAmplitude or DEFAULTS.rotation
	local rotationDirection = (random() < 0.5) and -1 or 1
	local glow = buildGlow(options.glow)
	local jitter = options.jitter
	if jitter == nil then
		jitter = DEFAULTS.jitter
	end

	local fadeStartTime, fadeDuration = resolveFade(entryDuration, fadeStart)
	local glowColor, glowFrequency, glowMagnitude, hasGlow
	if glow then
		glowColor = glow.color
		glowFrequency = glow.frequency
		glowMagnitude = glow.magnitude
		hasGlow = glowMagnitude and glowMagnitude > 0
	end

	entries[#entries + 1] = {
		text = text,
		x = x,
		y = y,
		color = entryColor,
		font = font,
		duration = entryDuration,
		timer = 0,
		riseDistance = rise,
		baseScale = baseScale,
		popScale = popScale,
		popDuration = popDuration,
		wobbleMagnitude = wobbleMagnitude,
		wobbleFrequency = wobbleFrequency,
		fadeStart = clamp(fadeStart, 0, 0.99),
		fadeStartTime = fadeStartTime,
		fadeDuration = fadeDuration,
		drift = drift,
		rotationAmplitude = rotationAmplitude,
		rotationDirection = rotationDirection,
		shadow = buildShadow(options.shadow),
		glowColor = glowColor,
		glowFrequency = glowFrequency or 0,
		glowMagnitude = glowMagnitude or 0,
		hasGlow = hasGlow,
		glowPhase = random() * math.pi * 2,
		glowAlpha = 0,
		jitter = jitter or 0,
		hasJitter = (jitter or 0) > 0,
		jitterSeed = random() * math.pi * 2,
		jitterX = 0,
		jitterY = 0,
		offsetX = 0,
		offsetY = 0,
		scale = baseScale,
		rotation = 0,
		ox = fontWidth / 2,
		oy = fontHeight / 2,
	}
end

function FloatingText:update(dt)
	if dt <= 0 or #entries == 0 then
		return
	end

	for i = #entries, 1, -1 do
		local entry = entries[i]
		entry.timer = entry.timer + dt

		local duration = entry.duration
		local progress = duration > 0 and clamp(entry.timer / duration, 0, 1) or 1

		entry.offsetY = -entry.riseDistance * easeOutCubic(progress)
		entry.offsetX = entry.drift * progress + entry.wobbleMagnitude * math.sin(entry.wobbleFrequency * entry.timer)

		if entry.hasJitter then
			local falloff = (1 - progress)
			local jitterStrength = entry.jitter * falloff * falloff
			local phase = entry.jitterSeed
			entry.jitterX = sin(entry.timer * 9 + phase) * jitterStrength
			entry.jitterY = cos(entry.timer * 7.4 + phase * 1.3) * jitterStrength * 0.6
		else
			entry.jitterX, entry.jitterY = 0, 0
		end

		if entry.popDuration > 0 and entry.timer < entry.popDuration then
			local popProgress = clamp(entry.timer / entry.popDuration, 0, 1)
			entry.scale = lerp(entry.popScale, entry.baseScale, easeOutBack(popProgress))
		else
			local settleDuration = math.max(duration - entry.popDuration, 0.001)
			local settleProgress = clamp((entry.timer - entry.popDuration) / settleDuration, 0, 1)
			local pulse = sin(entry.timer * 6) * (1 - settleProgress) * 0.04
			entry.scale = entry.baseScale * (1 + pulse)
		end

		entry.rotation = entry.rotationAmplitude * entry.rotationDirection * sin(progress * math.pi)

		if entry.hasGlow then
			local pulse = sin(entry.timer * entry.glowFrequency + entry.glowPhase) * 0.5 + 0.5
			local emphasis = (1 - progress * 0.6)
			entry.glowAlpha = pulse * entry.glowMagnitude * emphasis
		else
			entry.glowAlpha = 0
		end

		if duration > 0 and entry.timer >= duration then
			table.remove(entries, i)
		end
	end
end

function FloatingText:draw()
	for _, entry in ipairs(entries) do
		lg.setFont(entry.font)

		local alpha = entry.color[4] or 1
		if entry.duration > 0 and entry.fadeStartTime then
			if entry.timer >= entry.fadeStartTime then
				local fadeProgress = clamp((entry.timer - entry.fadeStartTime) / entry.fadeDuration, 0, 1)
				alpha = alpha * (1 - easeInCubic(fadeProgress))
			end
		end

		alpha = clamp(alpha, 0, 1)

		lg.push()
		lg.translate(entry.x + entry.offsetX + entry.jitterX, entry.y + entry.offsetY + entry.jitterY)
		lg.rotate(entry.rotation)
		lg.scale(entry.scale)

		local shadow = entry.shadow
		if shadow.alpha > 0 then
			lg.setColor(0, 0, 0, shadow.alpha * alpha)
			lg.print(entry.text, -entry.ox + shadow.offsetX, -entry.oy + shadow.offsetY)
		end

		lg.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
		lg.print(entry.text, -entry.ox, -entry.oy)

		if entry.glowAlpha and entry.glowAlpha > 0 and entry.glowColor then
			local prevMode, prevAlphaMode = lg.getBlendMode()
			lg.setBlendMode("add", "alphamultiply")
			lg.setColor(entry.glowColor[1], entry.glowColor[2], entry.glowColor[3], alpha * entry.glowAlpha)
			lg.print(entry.text, -entry.ox, -entry.oy)
			lg.setBlendMode(prevMode, prevAlphaMode)
		end

		lg.pop()
	end

	lg.setColor(1, 1, 1, 1)
end

function FloatingText:reset()
	entries = {}
end

return FloatingText
