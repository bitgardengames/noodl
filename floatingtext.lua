local UI = require("ui")
local Easing = require("easing")

local FloatingText = {}
FloatingText.__index = FloatingText

local lg = love.graphics
local lm = love.math
local random = lm.random
local sin, cos = math.sin, math.cos
local pi = math.pi
local max = math.max

local clamp = Easing.clamp
local lerp = Easing.lerp
local easeOutCubic = Easing.easeOutCubic
local easeInCubic = Easing.easeInCubic
local easeOutBack = Easing.easeOutBack

local defaultFont = UI.fonts.subtitle or UI.fonts.display or lg.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 24)

local baseColor = UI.colors.accentText or UI.colors.text or {1, 1, 1, 1}
local fallbackShadow = {offsetX = 0, offsetY = 0, alpha = 0}

local DEFAULTS = {
	font = defaultFont,
	color = {baseColor[1], baseColor[2], baseColor[3], 1},
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
		color = {baseColor[1], baseColor[2], baseColor[3], 0.55},
		frequency = 3.4,
		magnitude = 0.45,
	},
	jitter = 0.8,
}

local function deepCopyTable(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = deepCopyTable(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function applyOverrides(target, overrides)
	for key, value in pairs(overrides) do
		if type(value) == "table" then
			local existing = target[key]
			if type(existing) == "table" then
				applyOverrides(existing, value)
			else
				target[key] = deepCopyTable(value)
			end
		else
			target[key] = value
		end
	end
end

local function resolveDefaults(overrides)
	local defaults = deepCopyTable(DEFAULTS)
	if overrides then
		applyOverrides(defaults, overrides)
	end
	return defaults
end

local function applyColor(target, defaults, color)
	local base = color or defaults.color or DEFAULTS.color
	local fallback = defaults.color or DEFAULTS.color
	local destination = target or {}

	destination[1] = base[1] or fallback[1]
	destination[2] = base[2] or fallback[2]
	destination[3] = base[3] or fallback[3]

	local baseAlpha = base[4]
	if baseAlpha == nil then
		local fallbackAlpha = fallback[4]
		if fallbackAlpha == nil then
			fallbackAlpha = 1
		end
		destination[4] = fallbackAlpha
	else
		destination[4] = baseAlpha
	end

	return destination
end

local function buildShadow(defaults, shadow, target)
	local defaultsShadow = defaults.shadow or DEFAULTS.shadow
	if defaultsShadow == nil then
		return nil
	end

	if shadow == false then
		return nil
	end

	if shadow == nil then
		local destination = target or {}
		destination.offsetX = defaultsShadow.offsetX
		destination.offsetY = defaultsShadow.offsetY
		destination.alpha = defaultsShadow.alpha
		return destination
	end

	local destination = target or {}
	destination.offsetX = shadow.offsetX or defaultsShadow.offsetX
	destination.offsetY = shadow.offsetY or defaultsShadow.offsetY
	if shadow.alpha == nil then
		destination.alpha = defaultsShadow.alpha
	else
		destination.alpha = shadow.alpha
	end

	return destination
end

local function buildGlow(defaults, glow, colorTarget)
	local defaultsGlow = defaults.glow or DEFAULTS.glow
	if defaultsGlow == nil or defaultsGlow == false then
		return nil
	end

	if glow == false then
		return nil
	end

	if glow == nil then
		local destination = colorTarget or {}
		local color = defaultsGlow.color
		destination[1] = color[1]
		destination[2] = color[2]
		destination[3] = color[3]
		destination[4] = color[4] or 1
		return destination, defaultsGlow.frequency, defaultsGlow.magnitude
	end

	local sourceColor = glow.color or defaultsGlow.color

	local destination = colorTarget or {}
	destination[1] = sourceColor[1] or defaultsGlow.color[1]
	destination[2] = sourceColor[2] or defaultsGlow.color[2]
	destination[3] = sourceColor[3] or defaultsGlow.color[3]
	if sourceColor[4] == nil then
		destination[4] = defaultsGlow.color[4] or 1
	else
		destination[4] = sourceColor[4]
	end

	return destination, glow.frequency or defaultsGlow.frequency, glow.magnitude or defaultsGlow.magnitude
end

local function resolveFade(duration, fadeStart)
	if duration <= 0 then
		return nil, nil
	end

	local startTime = duration * clamp(fadeStart, 0, 0.99)
	local fadeDuration = max(duration - startTime, 0.001)

	return startTime, fadeDuration
end

local function resolveDrift(defaults, options)
	if options.drift ~= nil then
		return options.drift
	end

	local defaultDrift = defaults.drift or 0
	if defaultDrift == 0 then
		return 0
	end

	return (random() * 2 - 1) * defaultDrift
end

local function resolveRiseDistance(defaults, duration, riseSpeed, options)
	if options.riseDistance ~= nil then
		return options.riseDistance
	end

	local speed = riseSpeed or defaults.riseSpeed or DEFAULTS.riseSpeed
	return speed * max(duration, 0.05)
end

local function createInstance(overrides)
	local defaults = resolveDefaults(overrides)

	local instance = {
		defaults = defaults,
		entries = {},
		entryPool = {},
	}

	return setmetatable(instance, FloatingText)
end

function FloatingText:add(text, x, y, color, duration, riseSpeed, font, options)
	assert(text ~= nil, "FloatingText:add requires text")

	options = options or {}
	font = font or self.defaults.font or defaultFont
	text = tostring(text)

	local defaults = self.defaults
	local entries = self.entries

	local fontWidth = font:getWidth(text)
	local fontHeight = font:getHeight()
	local entryDuration = (duration ~= nil and duration > 0) and duration or defaults.duration or DEFAULTS.duration
	local entryPool = self.entryPool
	local entryIndex = #entryPool
	local entry
	if entryIndex > 0 then
		entry = entryPool[entryIndex]
		entryPool[entryIndex] = nil
	else
		entry = {}
	end

	entry.color = applyColor(entry.color, defaults, color)
	local baseScale = options.scale or defaults.scale or DEFAULTS.scale

	local popDefaults = defaults.pop or DEFAULTS.pop
	local popScale = baseScale * (options.popScaleFactor or popDefaults.scale)
	local popDuration = options.popDuration or popDefaults.duration

	local wobbleDefaults = defaults.wobble or DEFAULTS.wobble
	local wobbleMagnitude = options.wobbleMagnitude or wobbleDefaults.magnitude
	local wobbleFrequency = options.wobbleFrequency or wobbleDefaults.frequency

	local fadeStart = options.fadeStart or defaults.fadeStart or DEFAULTS.fadeStart
	local drift = resolveDrift(defaults, options)
	local rise = resolveRiseDistance(defaults, entryDuration, riseSpeed, options)
	local rotationAmplitude = options.rotationAmplitude or defaults.rotation or DEFAULTS.rotation
	local rotationDirection = (random() < 0.5) and -1 or 1
	local glowColor, glowFrequency, glowMagnitude = buildGlow(defaults, options.glow, entry.glowColor)
	entry.glowColor = glowColor
	if glowColor then
		entry.glowFrequency = glowFrequency or 0
		entry.glowMagnitude = glowMagnitude or 0
		entry.hasGlow = (entry.glowMagnitude or 0) > 0
	else
		entry.glowFrequency = 0
		entry.glowMagnitude = 0
		entry.hasGlow = false
	end
	local jitter = options.jitter
	if jitter == nil then
		jitter = defaults.jitter or DEFAULTS.jitter
	end

	local fadeStartTime, fadeDuration = resolveFade(entryDuration, fadeStart)

	local shadowBuffer = entry._shadow
	local resolvedShadow = buildShadow(defaults, options.shadow, shadowBuffer)
	if resolvedShadow then
		entry.shadow = resolvedShadow
		entry._shadow = resolvedShadow
	else
		entry.shadow = fallbackShadow
		entry._shadow = entry._shadow or {}
	end

	entry.text = text
	entry.x = x
	entry.y = y
	entry.font = font
	entry.duration = entryDuration
	entry.timer = 0
	entry.riseDistance = rise
	entry.baseScale = baseScale
	entry.popScale = popScale
	entry.popDuration = popDuration
	entry.wobbleMagnitude = wobbleMagnitude
	entry.wobbleFrequency = wobbleFrequency
	entry.fadeStart = clamp(fadeStart, 0, 0.99)
	entry.fadeStartTime = fadeStartTime
	entry.fadeDuration = fadeDuration
	entry.drift = drift
	entry.rotationAmplitude = rotationAmplitude
	entry.rotationDirection = rotationDirection
	entry.glowPhase = random() * pi * 2
	entry.glowAlpha = 0
	entry.jitter = jitter or 0
	entry.hasJitter = (jitter or 0) > 0
	entry.jitterSeed = random() * pi * 2
	entry.jitterX = 0
	entry.jitterY = 0
	entry.offsetX = 0
	entry.offsetY = 0
	entry.scale = baseScale
	entry.rotation = 0
	entry.ox = fontWidth / 2
	entry.oy = fontHeight / 2

	entries[#entries + 1] = entry
end

function FloatingText:update(dt)
	if dt <= 0 then
		return
	end

	local entries = self.entries
	local entryPool = self.entryPool
	local count = #entries
	if count == 0 then
		return
	end

	for index = count, 1, -1 do
		local entry = entries[index]
		entry.timer = entry.timer + dt

		local duration = entry.duration
		local progress = duration > 0 and clamp(entry.timer / duration, 0, 1) or 1

		entry.offsetY = -entry.riseDistance * easeOutCubic(progress)
		entry.offsetX = entry.drift * progress + entry.wobbleMagnitude * sin(entry.wobbleFrequency * entry.timer)

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
			local settleDuration = max(duration - entry.popDuration, 0.001)
			local settleProgress = clamp((entry.timer - entry.popDuration) / settleDuration, 0, 1)
			local pulse = sin(entry.timer * 6) * (1 - settleProgress) * 0.04
			entry.scale = entry.baseScale * (1 + pulse)
		end

		entry.rotation = entry.rotationAmplitude * entry.rotationDirection * sin(progress * pi)

		if entry.hasGlow then
			local pulse = sin(entry.timer * entry.glowFrequency + entry.glowPhase) * 0.5 + 0.5
			local emphasis = (1 - progress * 0.6)
			entry.glowAlpha = pulse * entry.glowMagnitude * emphasis
		else
			entry.glowAlpha = 0
		end

		if duration > 0 and entry.timer >= duration then
			local lastIndex = #entries
			local lastEntry = entries[lastIndex]
			entries[lastIndex] = nil

			if index ~= lastIndex then
				entries[index] = lastEntry
			end

			entryPool[#entryPool + 1] = entry
		end
	end
end

function FloatingText:draw()
	local entries = self.entries
	local defaultBlendMode, defaultAlphaMode = lg.getBlendMode()
	local activeGlowBlend = false
	local currentFont = nil

        for index = 1, #entries do
                local entry = entries[index]
                if entry.font ~= currentFont then
                        lg.setFont(entry.font)
                        currentFont = entry.font
                end

		local alpha = entry.color[4] or 1
		if entry.duration > 0 and entry.fadeStartTime then
			if entry.timer >= entry.fadeStartTime then
				local fadeProgress = clamp((entry.timer - entry.fadeStartTime) / entry.fadeDuration, 0, 1)
				alpha = alpha * (1 - easeInCubic(fadeProgress))
			end
		end

                alpha = clamp(alpha, 0, 1)

                local baseX = (entry.x or 0) + (entry.offsetX or 0) + (entry.jitterX or 0)
                local baseY = (entry.y or 0) + (entry.offsetY or 0) + (entry.jitterY or 0)
                local rotation = entry.rotation or 0
                local scale = entry.scale or 1
                local originX = entry.ox or 0
                local originY = entry.oy or 0

                local shadow = entry.shadow
                if shadow and shadow.alpha > 0 then
                        local shadowOriginX = originX - (shadow.offsetX or 0)
                        local shadowOriginY = originY - (shadow.offsetY or 0)
                        lg.setColor(0, 0, 0, shadow.alpha * alpha)
                        lg.print(entry.text, baseX, baseY, rotation, scale, scale, shadowOriginX, shadowOriginY)
                end

                lg.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
                lg.print(entry.text, baseX, baseY, rotation, scale, scale, originX, originY)

                if entry.glowAlpha and entry.glowAlpha > 0 and entry.glowColor then
                        if not activeGlowBlend then
                                lg.setBlendMode("add", "alphamultiply")
                                activeGlowBlend = true
                        end
                        lg.setColor(entry.glowColor[1], entry.glowColor[2], entry.glowColor[3], alpha * entry.glowAlpha)
                        lg.print(entry.text, baseX, baseY, rotation, scale, scale, originX, originY)
                        lg.setBlendMode(defaultBlendMode, defaultAlphaMode)
                        activeGlowBlend = false
                end
        end

        lg.setColor(1, 1, 1, 1)
end

function FloatingText:reset()
	local entries = self.entries
	local entryPool = self.entryPool

	for index = #entries, 1, -1 do
		entryPool[#entryPool + 1] = entries[index]
		entries[index] = nil
	end
end

local defaultInstance = createInstance()

function defaultInstance:new(overrides)
	return createInstance(overrides)
end

function defaultInstance:getPrototype()
	return FloatingText
end

return defaultInstance