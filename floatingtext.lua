local UI = require("ui")
local Easing = require("easing")

local FloatingText = {}
FloatingText.__index = FloatingText

local lg = love.graphics
local lm = love.math
local random = lm.random
local sin, cos = math.sin, math.cos
local max = math.max

local clamp = Easing.clamp
local lerp = Easing.lerp
local EaseOutCubic = Easing.EaseOutCubic
local EaseInCubic = Easing.EaseInCubic
local EaseOutBack = Easing.EaseOutBack

local DefaultFont = UI.fonts.subtitle or UI.fonts.display or lg.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 24)

local BaseColor = UI.colors.AccentText or UI.colors.text or { 1, 1, 1, 1 }

local DEFAULTS = {
	font = DefaultFont,
	color = { BaseColor[1], BaseColor[2], BaseColor[3], 1 },
	duration = 1.0,
	RiseSpeed = 30,
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
	FadeStart = 0.35,
	rotation = math.rad(5),
	shadow = {
		OffsetX = 2,
		OffsetY = 2,
		alpha = 0.35,
	},
	glow = {
		color = { BaseColor[1], BaseColor[2], BaseColor[3], 0.55 },
		frequency = 3.4,
		magnitude = 0.45,
	},
	jitter = 0.8,
}

local function DeepCopyTable(source)
	if type(source) ~= "table" then
		return source
	end

	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function ApplyOverrides(target, overrides)
	for key, value in pairs(overrides) do
		if type(value) == "table" then
			local existing = target[key]
			if type(existing) == "table" then
				ApplyOverrides(existing, value)
			else
				target[key] = DeepCopyTable(value)
			end
		else
			target[key] = value
		end
	end
end

local function ResolveDefaults(overrides)
	local defaults = DeepCopyTable(DEFAULTS)
	if overrides then
		ApplyOverrides(defaults, overrides)
	end
	return defaults
end

local function CloneColor(defaults, color)
	local base = color or defaults.color or DEFAULTS.color

	return {
		base[1] or defaults.color[1],
		base[2] or defaults.color[2],
		base[3] or defaults.color[3],
		base[4] == nil and ((defaults.color and defaults.color[4]) or 1) or base[4],
	}
end

local function BuildShadow(defaults, shadow)
	local DefaultsShadow = defaults.shadow or DEFAULTS.shadow
	if DefaultsShadow == nil then
		return nil
	end

	if shadow == nil then
		return {
			OffsetX = DefaultsShadow.offsetX,
			OffsetY = DefaultsShadow.offsetY,
			alpha = DefaultsShadow.alpha,
		}
	end

	return {
		OffsetX = shadow.offsetX or DefaultsShadow.offsetX,
		OffsetY = shadow.offsetY or DefaultsShadow.offsetY,
		alpha = shadow.alpha == nil and DefaultsShadow.alpha or shadow.alpha,
	}
end

local function BuildGlow(defaults, glow)
	local DefaultsGlow = defaults.glow or DEFAULTS.glow
	if DefaultsGlow == nil or DefaultsGlow == false then
		return nil
	end

	if glow == false then
		return nil
	end

	if glow == nil then
		return {
			color = {
				DefaultsGlow.color[1],
				DefaultsGlow.color[2],
				DefaultsGlow.color[3],
				DefaultsGlow.color[4] or 1,
			},
			frequency = DefaultsGlow.frequency,
			magnitude = DefaultsGlow.magnitude,
		}
	end

	local SourceColor = glow.color or DefaultsGlow.color

	return {
		color = {
			SourceColor[1] or DefaultsGlow.color[1],
			SourceColor[2] or DefaultsGlow.color[2],
			SourceColor[3] or DefaultsGlow.color[3],
			SourceColor[4] == nil and (DefaultsGlow.color[4] or 1) or SourceColor[4],
		},
		frequency = glow.frequency or DefaultsGlow.frequency,
		magnitude = glow.magnitude or DefaultsGlow.magnitude,
	}
end

local function ResolveFade(duration, FadeStart)
	if duration <= 0 then
		return nil, nil
	end

	local StartTime = duration * clamp(FadeStart, 0, 0.99)
	local FadeDuration = max(duration - StartTime, 0.001)

	return StartTime, FadeDuration
end

local function ResolveDrift(defaults, options)
	if options.drift ~= nil then
		return options.drift
	end

	local DefaultDrift = defaults.drift or 0
	if DefaultDrift == 0 then
		return 0
	end

	return (random() * 2 - 1) * DefaultDrift
end

local function ResolveRiseDistance(defaults, duration, RiseSpeed, options)
	if options.riseDistance ~= nil then
		return options.riseDistance
	end

	local speed = RiseSpeed or defaults.riseSpeed or DEFAULTS.RiseSpeed
	return speed * max(duration, 0.05)
end

local function CreateInstance(overrides)
	local defaults = ResolveDefaults(overrides)

	local instance = {
		defaults = defaults,
		entries = {},
	}

	return setmetatable(instance, FloatingText)
end

function FloatingText.new(overrides)
	return CreateInstance(overrides)
end

function FloatingText:add(text, x, y, color, duration, RiseSpeed, font, options)
	assert(text ~= nil, "FloatingText:add requires text")

	options = options or {}
	font = font or self.defaults.font or DefaultFont
	text = tostring(text)

	local defaults = self.defaults
	local entries = self.entries

	local FontWidth = font:getWidth(text)
	local FontHeight = font:getHeight()
	local EntryDuration = (duration ~= nil and duration > 0) and duration or defaults.duration or DEFAULTS.duration
	local EntryColor = CloneColor(defaults, color)
	local BaseScale = options.scale or defaults.scale or DEFAULTS.scale

	local PopDefaults = defaults.pop or DEFAULTS.pop
	local PopScale = BaseScale * (options.popScaleFactor or PopDefaults.scale)
	local PopDuration = options.popDuration or PopDefaults.duration

	local WobbleDefaults = defaults.wobble or DEFAULTS.wobble
	local WobbleMagnitude = options.wobbleMagnitude or WobbleDefaults.magnitude
	local WobbleFrequency = options.wobbleFrequency or WobbleDefaults.frequency

	local FadeStart = options.fadeStart or defaults.fadeStart or DEFAULTS.FadeStart
	local drift = ResolveDrift(defaults, options)
	local rise = ResolveRiseDistance(defaults, EntryDuration, RiseSpeed, options)
	local RotationAmplitude = options.rotationAmplitude or defaults.rotation or DEFAULTS.rotation
	local RotationDirection = (random() < 0.5) and -1 or 1
	local glow = BuildGlow(defaults, options.glow)
	local jitter = options.jitter
	if jitter == nil then
		jitter = defaults.jitter or DEFAULTS.jitter
	end

	local FadeStartTime, FadeDuration = ResolveFade(EntryDuration, FadeStart)
	local GlowColor, GlowFrequency, GlowMagnitude, HasGlow
	if glow then
		GlowColor = glow.color
		GlowFrequency = glow.frequency
		GlowMagnitude = glow.magnitude
		HasGlow = GlowMagnitude and GlowMagnitude > 0
	end

	local shadow = BuildShadow(defaults, options.shadow) or {
		OffsetX = 0,
		OffsetY = 0,
		alpha = 0,
	}

	entries[#entries + 1] = {
		text = text,
		x = x,
		y = y,
		color = EntryColor,
		font = font,
		duration = EntryDuration,
		timer = 0,
		RiseDistance = rise,
		BaseScale = BaseScale,
		PopScale = PopScale,
		PopDuration = PopDuration,
		WobbleMagnitude = WobbleMagnitude,
		WobbleFrequency = WobbleFrequency,
		FadeStart = clamp(FadeStart, 0, 0.99),
		FadeStartTime = FadeStartTime,
		FadeDuration = FadeDuration,
		drift = drift,
		RotationAmplitude = RotationAmplitude,
		RotationDirection = RotationDirection,
		shadow = shadow,
		GlowColor = GlowColor,
		GlowFrequency = GlowFrequency or 0,
		GlowMagnitude = GlowMagnitude or 0,
		HasGlow = HasGlow,
		GlowPhase = random() * math.pi * 2,
		GlowAlpha = 0,
		jitter = jitter or 0,
		HasJitter = (jitter or 0) > 0,
		JitterSeed = random() * math.pi * 2,
		JitterX = 0,
		JitterY = 0,
		OffsetX = 0,
		OffsetY = 0,
		scale = BaseScale,
		rotation = 0,
		ox = FontWidth / 2,
		oy = FontHeight / 2,
	}
end

function FloatingText:update(dt)
	if dt <= 0 then
		return
	end

	local entries = self.entries
	if #entries == 0 then
		return
	end

	for index = #entries, 1, -1 do
		local entry = entries[index]
		entry.timer = entry.timer + dt

		local duration = entry.duration
		local progress = duration > 0 and clamp(entry.timer / duration, 0, 1) or 1

		entry.offsetY = -entry.riseDistance * EaseOutCubic(progress)
		entry.offsetX = entry.drift * progress + entry.wobbleMagnitude * math.sin(entry.wobbleFrequency * entry.timer)

		if entry.hasJitter then
			local falloff = (1 - progress)
			local JitterStrength = entry.jitter * falloff * falloff
			local phase = entry.jitterSeed
			entry.jitterX = sin(entry.timer * 9 + phase) * JitterStrength
			entry.jitterY = cos(entry.timer * 7.4 + phase * 1.3) * JitterStrength * 0.6
		else
			entry.jitterX, entry.jitterY = 0, 0
		end

		if entry.popDuration > 0 and entry.timer < entry.popDuration then
			local PopProgress = clamp(entry.timer / entry.popDuration, 0, 1)
			entry.scale = lerp(entry.popScale, entry.baseScale, EaseOutBack(PopProgress))
		else
			local SettleDuration = math.max(duration - entry.popDuration, 0.001)
			local SettleProgress = clamp((entry.timer - entry.popDuration) / SettleDuration, 0, 1)
			local pulse = sin(entry.timer * 6) * (1 - SettleProgress) * 0.04
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
			table.remove(entries, index)
		end
	end
end

function FloatingText:draw()
	local entries = self.entries
	for _, entry in ipairs(entries) do
		lg.setFont(entry.font)

		local alpha = entry.color[4] or 1
		if entry.duration > 0 and entry.fadeStartTime then
			if entry.timer >= entry.fadeStartTime then
				local FadeProgress = clamp((entry.timer - entry.fadeStartTime) / entry.fadeDuration, 0, 1)
				alpha = alpha * (1 - EaseInCubic(FadeProgress))
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
			local PreviousMode, PreviousAlphaMode = lg.getBlendMode()
			lg.setBlendMode("add", "alphamultiply")
			lg.setColor(entry.glowColor[1], entry.glowColor[2], entry.glowColor[3], alpha * entry.glowAlpha)
			lg.print(entry.text, -entry.ox, -entry.oy)
			lg.setBlendMode(PreviousMode, PreviousAlphaMode)
		end

		lg.pop()
	end

	lg.setColor(1, 1, 1, 1)
end

function FloatingText:reset()
	self.entries = {}
end

function FloatingText:clear()
	self:reset()
end

function FloatingText:GetDefaults()
	return self.defaults
end

local DefaultInstance = CreateInstance()

function DefaultInstance:new(overrides)
	return CreateInstance(overrides)
end

function DefaultInstance:getPrototype()
	return FloatingText
end

return DefaultInstance
