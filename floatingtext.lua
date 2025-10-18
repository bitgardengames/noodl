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

local baseColor = UI.colors.accentText or UI.colors.text or { 1, 1, 1, 1 }
local fallbackShadow = { offsetX = 0, offsetY = 0, alpha = 0 }

local DEFAULTS = {
	font = defaultFont,
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

local function cloneColor(defaults, color)
	local base = color or defaults.color or DEFAULTS.color

	return {
		base[1] or defaults.color[1],
		base[2] or defaults.color[2],
		base[3] or defaults.color[3],
		base[4] == nil and ((defaults.color and defaults.color[4]) or 1) or base[4],
	}
end

local function buildShadow(defaults, shadow)
	local defaultsShadow = defaults.shadow or DEFAULTS.shadow
	if defaultsShadow == nil then
		return nil
	end

	if shadow == nil then
		return {
			offsetX = defaultsShadow.offsetX,
			offsetY = defaultsShadow.offsetY,
			alpha = defaultsShadow.alpha,
		}
	end

	return {
		offsetX = shadow.offsetX or defaultsShadow.offsetX,
		offsetY = shadow.offsetY or defaultsShadow.offsetY,
		alpha = shadow.alpha == nil and defaultsShadow.alpha or shadow.alpha,
	}
end

local function buildGlow(defaults, glow)
	local defaultsGlow = defaults.glow or DEFAULTS.glow
	if defaultsGlow == nil or defaultsGlow == false then
		return nil
	end

	if glow == false then
		return nil
	end

	if glow == nil then
		return {
			color = {
				defaultsGlow.color[1],
				defaultsGlow.color[2],
				defaultsGlow.color[3],
				defaultsGlow.color[4] or 1,
			},
			frequency = defaultsGlow.frequency,
			magnitude = defaultsGlow.magnitude,
		}
	end

	local sourceColor = glow.color or defaultsGlow.color

	return {
		color = {
			sourceColor[1] or defaultsGlow.color[1],
			sourceColor[2] or defaultsGlow.color[2],
			sourceColor[3] or defaultsGlow.color[3],
			sourceColor[4] == nil and (defaultsGlow.color[4] or 1) or sourceColor[4],
		},
		frequency = glow.frequency or defaultsGlow.frequency,
		magnitude = glow.magnitude or defaultsGlow.magnitude,
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

function FloatingText.new(overrides)
	return createInstance(overrides)
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
	local entryColor = cloneColor(defaults, color)
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
	local glow = buildGlow(defaults, options.glow)
	local jitter = options.jitter
	if jitter == nil then
		jitter = defaults.jitter or DEFAULTS.jitter
	end

	local fadeStartTime, fadeDuration = resolveFade(entryDuration, fadeStart)
	local glowColor, glowFrequency, glowMagnitude, hasGlow
	if glow then
		glowColor = glow.color
		glowFrequency = glow.frequency
		glowMagnitude = glow.magnitude
		hasGlow = glowMagnitude and glowMagnitude > 0
	end

        local shadow = buildShadow(defaults, options.shadow) or fallbackShadow

        local entryPool = self.entryPool
        local entryIndex = #entryPool
        local entry
        if entryIndex > 0 then
                entry = entryPool[entryIndex]
                entryPool[entryIndex] = nil
        else
                entry = {}
        end

        entry.text = text
        entry.x = x
        entry.y = y
        entry.color = entryColor
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
        entry.shadow = shadow
        entry.glowColor = glowColor
        entry.glowFrequency = glowFrequency or 0
        entry.glowMagnitude = glowMagnitude or 0
        entry.hasGlow = hasGlow
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
        for index = 1, #entries do
                local entry = entries[index]
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
		if shadow and shadow.alpha > 0 then
			lg.setColor(0, 0, 0, shadow.alpha * alpha)
			lg.print(entry.text, -entry.ox + shadow.offsetX, -entry.oy + shadow.offsetY)
		end

		lg.setColor(entry.color[1], entry.color[2], entry.color[3], alpha)
		lg.print(entry.text, -entry.ox, -entry.oy)

		if entry.glowAlpha and entry.glowAlpha > 0 and entry.glowColor then
			local previousMode, previousAlphaMode = lg.getBlendMode()
			lg.setBlendMode("add", "alphamultiply")
			lg.setColor(entry.glowColor[1], entry.glowColor[2], entry.glowColor[3], alpha * entry.glowAlpha)
			lg.print(entry.text, -entry.ox, -entry.oy)
			lg.setBlendMode(previousMode, previousAlphaMode)
		end

		lg.pop()
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
