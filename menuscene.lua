local Theme = require("theme")
local Easing = require("easing")

local MenuScene = {}

local backgroundCaches = {}
local manualBackground = false
local drawRole = nil

local function copyColor(color)
        if not color then
                return {0, 0, 0, 1}
        end

        return {
                color[1] or 0,
                color[2] or 0,
                color[3] or 0,
                color[4] == nil and 1 or color[4],
        }
end

local function getPlainBackgroundBaseColor(override)
        if override then
                return copyColor(override)
        end

        local base = Theme.menuBackgroundColor or Theme.bgColor or {0.07, 0.08, 0.11, 1}
        return copyColor(base)
end

function MenuScene.getPlainBackgroundOptions(effectKey, overrideColor)
        local baseColor = getPlainBackgroundBaseColor(overrideColor)

        return {
                effectKey = effectKey or "menu/plain",
                baseColor = baseColor,
                accentColor = baseColor,
                pulseColor = baseColor,
                baseDarken = 0,
                accentLighten = 0,
                pulseLighten = 0,
                vignetteAlpha = 0,
                vignetteLighten = 0,
        }
end

local function lightenColor(color, factor)
        factor = factor or 0.35
        local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] == nil and 1 or color[4]
	return {
		r + (1 - r) * factor,
		g + (1 - g) * factor,
		b + (1 - b) * factor,
		a * (0.65 + factor * 0.35),
	}
end

local function darkenColor(color, factor)
	factor = factor or 0.35
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] == nil and 1 or color[4]
	return {
		r * (1 - factor),
		g * (1 - factor),
		b * (1 - factor),
		a,
	}
end

local function withAlpha(color, alpha)
	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] == nil and 1 or color[4]
	return {r, g, b, a * alpha}
end

local function getCacheEntry(options)
        local key = "default"
        if options and options.effectKey then
                key = tostring(options.effectKey)
        end

        local entry = backgroundCaches[key]
        if not entry then
                entry = {
                        hash = nil,
                        fillColor = nil,
                        overlayColor = nil,
                }
                backgroundCaches[key] = entry
        end

        return entry
end

local function getBaseColor(options)
	local override = options and options.baseColor
	if override then
		return copyColor(override)
	end

        return copyColor(Theme.bgColor or {0.07, 0.08, 0.11, 1})
end

local function computePalette(options)
	local baseColor = getBaseColor(options)
	local accentSource = (options and options.accentColor) or Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
	local accentLighten = (options and options.accentLighten) or 0.18
	local accentColor = lightenColor(copyColor(accentSource), accentLighten)
	accentColor[4] = 1

	local pulseSource = (options and options.pulseColor) or Theme.panelBorder or Theme.progressColor or accentColor
	local pulseLighten = (options and options.pulseLighten) or 0.26
	local pulseColor = lightenColor(copyColor(pulseSource), pulseLighten)
	pulseColor[4] = 1

	local fillDarken = (options and options.baseDarken) or 0.15
	local fillColor = darkenColor(copyColor(baseColor), fillDarken)
	fillColor[4] = baseColor[4] ~= nil and baseColor[4] or 1

	local vignetteLighten = (options and options.vignetteLighten) or 0.05
	local vignetteAlpha = (options and options.vignetteAlpha) or 0.28
	local vignetteColor = lightenColor(copyColor(accentSource), vignetteLighten)
	local vignette = {
		color = withAlpha(vignetteColor, vignetteAlpha),
		alpha = vignetteAlpha,
		steps = (options and options.vignetteSteps) or 3,
		thickness = options and options.vignetteThickness,
	}

	return fillColor, accentColor, pulseColor, vignette
end

local function hashColor(color)
	if not color then
		return "nil"
	end

	return string.format("%.4f,%.4f,%.4f,%.4f", color[1] or 0, color[2] or 0, color[3] or 0, color[4] ~= nil and color[4] or 1)
end

local function computeHash(options)
	local baseColor = getBaseColor(options)
	local accentSource = (options and options.accentColor) or Theme.blueberryColor or Theme.panelBorder or {0.35, 0.3, 0.5, 1}
	local pulseSource = (options and options.pulseColor) or Theme.panelBorder or Theme.progressColor or accentSource
	return table.concat({
		hashColor(baseColor),
		hashColor(accentSource),
		hashColor(pulseSource),
		tostring((options and options.baseDarken) or 0.15),
		tostring((options and options.accentLighten) or 0.18),
		tostring((options and options.pulseLighten) or 0.26),
		tostring((options and options.vignetteLighten) or 0.05),
		tostring((options and options.vignetteAlpha) or 0.28),
		tostring((options and options.vignetteSteps) or 3),
		tostring(options and options.vignetteThickness or "nil"),
	}, "|")
end

function MenuScene.prepareBackground(options)
        local entry = getCacheEntry(options)
        local configHash = computeHash(options)
        if entry.hash == configHash then
                return
        end

        local fillColor, accentColor, pulseColor, vignette = computePalette(options)

        entry.hash = configHash
        entry.fillColor = fillColor
        entry.overlayColor = vignette and vignette.color or nil
end

local function resolveFillColor(entry, options)
	if entry and entry.fillColor then
		return entry.fillColor
	end
	return getBaseColor(options)
end

function MenuScene.drawBackground(sw, sh, options)
        local entry = getCacheEntry(options)
        MenuScene.prepareBackground(options)

        local fillColor = resolveFillColor(entry, options)
        love.graphics.setColor(fillColor[1] or 0, fillColor[2] or 0, fillColor[3] or 0, fillColor[4] or 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        if entry.overlayColor then
                local overlay = entry.overlayColor
                love.graphics.setColor(overlay[1] or 0, overlay[2] or 0, overlay[3] or 0, overlay[4] or 1)
                love.graphics.rectangle("fill", 0, 0, sw, sh)
        end

        love.graphics.setColor(1, 1, 1, 1)
end

function MenuScene.setDrawRole(role)
	drawRole = role
end

function MenuScene.getDrawRole()
	return drawRole
end

function MenuScene.beginManualBackground()
	manualBackground = true
end

function MenuScene.endManualBackground()
	manualBackground = false
end

function MenuScene.shouldDrawBackground()
	if manualBackground then
		return false
	end

	return drawRole ~= "outgoing"
end

local function resolveSlideProgress(progress)
	progress = Easing.clamp01(progress or 0)
	return Easing.easeInOutSine(progress)
end

function MenuScene.getIncomingOffset(progress, width)
	local eased = resolveSlideProgress(progress)
	return (1 - eased) * (width or 0)
end

function MenuScene.getOutgoingOffset(progress, width)
	local eased = resolveSlideProgress(progress)
	return -eased * (width or 0)
end

return MenuScene
