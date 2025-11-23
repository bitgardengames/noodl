local Theme = require("theme")
local Easing = require("easing")
local Color = require("color")
local Timer = require("timer")

local min = math.min
local max = math.max
local floor = math.floor
local ceil = math.ceil
local sin = math.sin
local pi = math.pi

local MenuScene = {}

local backgroundCaches = {}
local manualBackground = false
local drawRole = nil

local copyColor = Color.copy

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

local lightenColor = function(color, factor)
	return Color.lighten(color, factor)
end

local darkenColor = function(color, factor)
	return Color.darken(color, factor)
end

local withAlpha = function(color, alpha)
	return Color.withAlpha(color, alpha)
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
                        seed = os.time(),
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
		}, "|"
	)
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

local function clamp01(value)
        if value < 0 then
                return 0
        end

        if value > 1 then
                return 1
        end

        return value
end

local function mixChannel(base, target, amount)
        return base + (target - base) * amount
end

local function mixColorTowards(baseColor, targetColor, amount, alphaOverride)
        local color = {}
        for i = 1, 3 do
                color[i] = clamp01(mixChannel(baseColor[i] or 0, targetColor[i] or 0, amount))
        end

        if alphaOverride ~= nil then
                color[4] = alphaOverride
        else
                local baseAlpha = baseColor[4] or 1
                local targetAlpha = targetColor[4] or 1
                color[4] = clamp01(mixChannel(baseAlpha, targetAlpha, amount))
        end

        return color
end

local function copyColor(color, defaultAlpha)
        return Color.copy(color, {
                default = {0, 0, 0, defaultAlpha or 1},
                defaultAlpha = defaultAlpha,
        })
end

local function getPaletteColor(palette, key, fallback, defaultAlpha)
        local value = fallback
        if palette and palette[key] then
                value = palette[key]
        end
        return copyColor(value, defaultAlpha)
end

local function jitterColor(color, jitterAmount, rng)
        local jittered = copyColor(color)
        for i = 1, 3 do
                jittered[i] = clamp01(jittered[i] + (rng:random() * 2 - 1) * jitterAmount)
        end
        jittered[4] = clamp01((jittered[4] or 1) * (0.92 + rng:random() * 0.08))
        return jittered
end

local function addRoundedSquare(decorations, rng, tileSize, col, row, size, radius, color)
local baseAlpha = color[4] or 1
decorations[#decorations + 1] = {
col = col,
row = row,
                x = (tileSize - size) * 0.5,
                y = (tileSize - size) * 0.5,
w = size,
h = size,
radius = radius,
color = {color[1], color[2], color[3], baseAlpha},
}
end

local function buildDecorationConfig(sw, sh, options, fillColor, accentColor, seed)
        local palette = options and options.palette
        local baseColor = copyColor(fillColor)
        local highlightTarget = getPaletteColor(palette, "highlightColor", Theme.highlightColor, 1)
        local shadowTarget = getPaletteColor(palette, "shadowColor", Theme.shadowColor, 1)
        local accentTarget = getPaletteColor(palette, "arenaBorder", accentColor or Theme.arenaBorder, 1)
        if palette and palette.rock then
                accentTarget = copyColor(palette.rock, 1)
        elseif Theme.rock then
                accentTarget = copyColor(Theme.rock, 1)
        end

        local baseSeed = (seed or os.time()) % 2147483647
        baseSeed = baseSeed + floor(Timer.getTime() * 1000)
        local rng = love.math.newRandomGenerator(baseSeed)

        local baseTileSize = (Theme.tileSize or 24) * 2
        local tileSize = max(1, baseTileSize)
        local cols = ceil(sw / tileSize)
        local rows = ceil(sh / tileSize)
        local clusterChance = 0.01
        local minClusterSize = 2
        local maxClusterSize = 4
        local colorJitter = 0.005

        clusterChance = clusterChance * (0.85 + rng:random() * 0.35)
        clusterChance = max(0, min(0.25, clusterChance))

        local decorations = {}
        local directions = {
                {1, 0},
                {-1, 0},
                {0, 1},
                {0, -1},
        }

        local function makeClusterColor()
                local lighten = rng:random() < 0.45
                local target = lighten and highlightTarget or shadowTarget
                local amount = lighten and (0.1 + rng:random() * 0.06) or (0.12 + rng:random() * 0.04)
                local alpha = lighten and (0.18 + rng:random() * 0.04) or (0.22 + rng:random() * 0.04)
                local color = mixColorTowards(baseColor, target, amount, alpha)

                if rng:random() < 0.35 then
                        local accentMix = 0.24 + rng:random() * 0.14
                        local accentAlpha = clamp01((color[4] or 1) * (0.9 + rng:random() * 0.1))
                        color = mixColorTowards(color, accentTarget, accentMix, accentAlpha)
                end

                return color
        end

        for row = 1, rows do
                for col = 1, cols do
                        if rng:random() < clusterChance then
                                local clusterColor = makeClusterColor()
                                local clusterSize = rng:random(minClusterSize, maxClusterSize)
                                local clusterCells = {{col = col, row = row}}

                                local attempts = 0
                                while #clusterCells < clusterSize and attempts < clusterSize * 6 do
                                        attempts = attempts + 1
                                        local baseIndex = rng:random(1, #clusterCells)
                                        local baseCell = clusterCells[baseIndex]
                                        local dir = directions[rng:random(1, #directions)]
                                        local nextCol = baseCell.col + dir[1]
                                        local nextRow = baseCell.row + dir[2]

                                        if nextCol >= 1 and nextCol <= cols and nextRow >= 1 and nextRow <= rows then
                                                local alreadyUsed = false
                                                for i = 1, #clusterCells do
                                                        local cell = clusterCells[i]
                                                        if cell.col == nextCol and cell.row == nextRow then
                                                                alreadyUsed = true
                                                                break
                                                        end
                                                end

                                                if not alreadyUsed then
                                                        clusterCells[#clusterCells + 1] = {col = nextCol, row = nextRow}
                                                end
                                        end
                                end

                                local size = min(tileSize * (0.48 + rng:random() * 0.18), tileSize)
                                local radius = size * (0.18 + rng:random() * 0.14)

                                for i = 1, #clusterCells do
                                        local cell = clusterCells[i]
                                        addRoundedSquare(decorations, rng, tileSize, cell.col, cell.row, size, radius, jitterColor(clusterColor, colorJitter, rng))
                                end
                        end
                end
        end

        local staticDecorations = {}
        local dynamicDecorations = {}

        for i = 1, #decorations do
                local deco = decorations[i]
                if deco.fade then
                        dynamicDecorations[#dynamicDecorations + 1] = deco
                else
                        staticDecorations[#staticDecorations + 1] = deco
                end
        end

        return {
                tileSize = tileSize,
                static = staticDecorations,
                dynamic = dynamicDecorations,
        }
end

local function rebuildDecorationCanvas(entry, decorations, sw, sh)
        local staticDecorations = decorations and decorations.static
        if not staticDecorations or #staticDecorations == 0 then
                entry.decorationCanvas = nil
                return
        end

        local canvasWidth = ceil(sw or 0)
        local canvasHeight = ceil(sh or 0)
        if canvasWidth <= 0 or canvasHeight <= 0 then
                entry.decorationCanvas = nil
                return
        end

        local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)

        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.setBlendMode("alpha")

        for i = 1, #staticDecorations do
                local deco = staticDecorations[i]
                local color = deco.color
                local rectWidth = deco.w or 0
                local rectHeight = deco.h or 0
                if color and rectWidth > 0 and rectHeight > 0 then
                        local drawX = ((deco.col - 1) * decorations.tileSize) + (deco.x or 0)
                        local drawY = ((deco.row - 1) * decorations.tileSize) + (deco.y or 0)
                        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
                        love.graphics.rectangle("fill", drawX, drawY, rectWidth, rectHeight, deco.radius or 0, deco.radius or 0)
                end
        end

        love.graphics.pop()

        entry.decorationCanvas = canvas
end

local function ensureMenuDecorations(entry, options, sw, sh)
        if not sw or not sh or sw <= 0 or sh <= 0 then
                entry.decorations = nil
                entry.decorationCanvas = nil
                entry.decorationHash = nil
                return
        end

        local fillColor = resolveFillColor(entry, options)
        local accentColor = (options and options.accentColor) or Theme.blueberryColor or Theme.panelBorder
        local decorationHash = table.concat({entry.hash or "", tostring(sw), tostring(sh), hashColor(fillColor), hashColor(accentColor)}, "|")

        if entry.decorationHash == decorationHash and entry.decorationCanvas then
                return
        end

        entry.decorations = buildDecorationConfig(sw, sh, options, fillColor, accentColor, entry.seed)
        rebuildDecorationCanvas(entry, entry.decorations, sw, sh)
        entry.decorationHash = decorationHash
end

local function drawMenuDecorations(entry)
        local decorations = entry.decorations
        if not decorations then
                return
        end

        local staticCanvas = entry.decorationCanvas
        local dynamicDecorations = decorations.dynamic
        local hasDynamic = dynamicDecorations and #dynamicDecorations > 0

        if not staticCanvas and not hasDynamic then
                return
        end

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha")

        if staticCanvas then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(staticCanvas, 0, 0)
        end

        if hasDynamic then
                local fadeTime
                for i = 1, #dynamicDecorations do
                        local fade = dynamicDecorations[i].fade
                        if fade and fade.amplitude and fade.amplitude > 0 then
                                fadeTime = Timer.getTime()
                                break
                        end
                end

                for i = 1, #dynamicDecorations do
                        local deco = dynamicDecorations[i]
                        local color = deco.color
                        local width = deco.w or 0
                        local height = deco.h or 0
                        if color and width > 0 and height > 0 then
                                local drawX = ((deco.col - 1) * decorations.tileSize) + (deco.x or 0)
                                local drawY = ((deco.row - 1) * decorations.tileSize) + (deco.y or 0)
                                local alpha = color[4] or 1
                                local fade = deco.fade
                                if fade and fade.amplitude and fade.amplitude > 0 then
                                        local time = fadeTime or Timer.getTime()
                                        local oscillation = sin(time * (fade.speed or 1) + (fade.offset or 0))
                                        local factor = 1 + oscillation * fade.amplitude
                                        alpha = clamp01((fade.base or alpha) * factor)
                                end

                                love.graphics.setColor(color[1], color[2], color[3], alpha)
                                love.graphics.rectangle("fill", drawX, drawY, width, height, deco.radius or 0, deco.radius or 0)
                        end
                end
        end

        love.graphics.pop()
end

function MenuScene.drawBackground(sw, sh, options)
        local entry = getCacheEntry(options)
        MenuScene.prepareBackground(options)

        local fillColor = resolveFillColor(entry, options)
        love.graphics.setColor(fillColor[1] or 0, fillColor[2] or 0, fillColor[3] or 0, fillColor[4] or 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        ensureMenuDecorations(entry, options, sw, sh)
        drawMenuDecorations(entry)

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

	local eased = Easing.easeInOutSine(progress)
	local accent = (Easing.easeOutCubic(progress) - progress) * 0.12

	return Easing.clamp(eased + accent, 0, 1.05)
end

function MenuScene.getIncomingOffset(progress, width)
	local x = MenuScene.getIncomingTransform(progress, width)
	return x
end

function MenuScene.getOutgoingOffset(progress, width)
	local x = MenuScene.getOutgoingTransform(progress, width)
	return x
end

local function getTransformCenter(width, height)
	return (width or 0) * 0.5, (height or 0) * 0.5
end

local function resolveLift(progress, maxOffset)
	local arc = sin(progress * pi)
	local easedArc = arc * Easing.easeOutCubic(progress)
	return (easedArc * easedArc) * (maxOffset or 0)
end

function MenuScene.getIncomingTransform(progress, width, height)
	local eased = resolveSlideProgress(progress)
	local slide = 1 - eased
	local lift = resolveLift(1 - progress, 14)
	local scale = 1.015 - 0.015 * Easing.easeOutCubic(progress)

	return slide * (width or 0), lift, scale, getTransformCenter(width, height)
end

function MenuScene.getOutgoingTransform(progress, width, height)
	local eased = resolveSlideProgress(progress)
	local slide = -eased
	local lift = -resolveLift(progress, 10)
	local scale = 1 - 0.028 * Easing.easeInOutSine(progress)

	return slide * (width or 0), lift, scale, getTransformCenter(width, height)
end

return MenuScene
