local Audio = require("audio")
local Theme = require("theme")
local Localization = require("localization")
local Easing = require("easing")
local Timer = require("timer")

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local pow = math.pow
local sin = math.sin
local insert = table.insert
local remove = table.remove

local UI = {}

local SHADOW_OFFSET = 5

UI.shadowOffset = SHADOW_OFFSET

UI._cursorX = nil
UI._cursorY = nil


UI.fruitCollected = 0
UI.fruitRequired = 0
UI.fruitSockets = {}
UI.socketAnimTime = 0.25
UI.socketRemoveTime = 0.18
UI.socketBounceDuration = 0.65
UI.socketSize = 26
UI.goalReachedAnim = 0
UI.goalCelebrated = false

UI.combo = {
	count = 0,
	timer = 0,
	duration = 0,
	pop = 0,
}

UI.shields = {
        count = 0,
        display = 0,
        popDuration = 0.32,
        popTimer = 0,
        shakeDuration = 0.45,
        shakeTimer = 0,
        flashDuration = 0.4,
        flashTimer = 0,
        lastDirection = 0,
}

UI._shieldLocaleRevision = nil
UI._shieldLabel = nil
UI._shieldStatusKey = nil
UI._shieldStatusText = nil

UI.upgradeIndicators = {
        items = {},
        order = {},
        layout = {},
        visibleList = {},
}

local BASE_SCREEN_WIDTH = 1920
local BASE_SCREEN_HEIGHT = 1080
local MIN_LAYOUT_SCALE = 0.6
local MAX_LAYOUT_SCALE = 1.5

local fontDefinitions = {
	title = {path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 72, min = 28},
	display = {path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 64, min = 24},
	subtitle = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 32, min = 18},
	heading = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 28, min = 16},
	button = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 24, min = 14},
	body = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 16, min = 12},
	prompt = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 20, min = 12},
	caption = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 14, min = 10},
	small = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 12, min = 9},
	timer = {path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 42, min = 24},
	timerSmall = {path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 20, min = 12},
	achieve = {path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 18, min = 12},
	badge = {path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 20, min = 12},
}

local baseSpacing = {
	buttonWidth = 260,
	buttonHeight = 56,
	buttonRadius = 14,
	buttonSpacing = 24,
	panelRadius = 16,
	panelPadding = 20,
	shadowOffset = SHADOW_OFFSET,
	sectionSpacing = 28,
	sectionHeaderSpacing = 16,
	sliderHeight = 68,
	sliderTrackHeight = 10,
	sliderHandleRadius = 12,
	sliderPadding = 22,
}

local spacingMinimums = {
	buttonWidth = 180,
	buttonHeight = 44,
	buttonRadius = 8,
	buttonSpacing = 16,
	panelRadius = 12,
	panelPadding = 14,
	shadowOffset = SHADOW_OFFSET,
	sectionSpacing = 18,
	sectionHeaderSpacing = 10,
	sliderHeight = 48,
	sliderTrackHeight = 4,
	sliderHandleRadius = 10,
	sliderPadding = 14,
}

local baseUpgradeLayout = {
	width = 192,
	spacing = 12,
	baseHeight = 68,
	iconRadius = 18,
	barHeight = 6,
	margin = 24,
}

local baseSocketSize = 26
local baseSectionHeaderPadding = 8

UI.fonts = {}

local BUTTON_POP_DURATION = 0.32
local BUTTON_BORDER_WIDTH = 2

UI.buttonBorderWidth = BUTTON_BORDER_WIDTH

local function clamp01(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function approachExp(current, target, dt, speed)
	if speed <= 0 or dt <= 0 then
		return target
	end

	local factor = 1 - math.exp(-speed * dt)
	return current + (target - current) * factor
end

local function calculateShadowPadding(defaultStrokeWidth, overrideStrokeWidth)
	local strokeWidth = overrideStrokeWidth
	if strokeWidth == nil then
		strokeWidth = defaultStrokeWidth
	end

	if not strokeWidth or strokeWidth <= 0 then
		return 0
	end

	return strokeWidth * 0.5
end

local function lightenColor(color, amount, out)
	local target = out or {}
	if not color then
		target[1], target[2], target[3], target[4] = 1, 1, 1, 1
		return target
	end

	local a = color[4] or 1
	target[1] = color[1] + (1 - color[1]) * amount
	target[2] = color[2] + (1 - color[2]) * amount
	target[3] = color[3] + (1 - color[3]) * amount
	target[4] = a

	return target
end

local function darkenColor(color, amount, out)
	local target = out or {}
	if not color then
		target[1], target[2], target[3], target[4] = 0, 0, 0, 1
		return target
	end

	local a = color[4] or 1
	target[1] = color[1] * amount
	target[2] = color[2] * amount
	target[3] = color[3] * amount
	target[4] = a

	return target
end

local function setColor(color, alphaMultiplier)
        if not color then
                love.graphics.setColor(1, 1, 1, alphaMultiplier or 1)
                return
        end

        local r = color[1] or 1
        local g = color[2] or 1
        local b = color[3] or 1
        local a = color[4] or 1
        love.graphics.setColor(r, g, b, a * (alphaMultiplier or 1))
end

function UI.refreshCursor(x, y)
        if x ~= nil and y ~= nil then
                UI._cursorX = x
                UI._cursorY = y
        else
                UI._cursorX, UI._cursorY = love.mouse.getPosition()
        end

        return UI._cursorX, UI._cursorY
end

function UI.getCursorPosition()
        local x, y = UI._cursorX, UI._cursorY
        if x == nil or y == nil then
                return UI.refreshCursor()
        end

        return x, y
end

-- Button states
UI.buttons = {}

local function createButtonState()
	return {
		pressed = false,
		anim = 0,
		hoverAnim = 0,
		focusAnim = 0,
		hoverTarget = 0,
		glow = 0,
		popProgress = 0,
	}
end

function UI.clearButtons()
	UI.buttons = {}
end

function UI.setButtonFocus(id, focused)
	if not id then return end

	local btn = UI.buttons[id]
	if not btn then
		btn = createButtonState()
		UI.buttons[id] = btn
	end

	btn.focused = focused or nil
end

local function round(value)
	return floor(value + 0.5)
end

local function buildFonts(scale)
	for key, def in pairs(fontDefinitions) do
		local size = round(def.size * scale)
		if def.min then
			size = max(def.min, size)
		end
		UI.fonts[key] = love.graphics.newFont(def.path, size)
	end
end

UI.spacing = { shadowOffset = SHADOW_OFFSET }
UI.layout = UI.layout or {}
UI.layout.menu = UI.layout.menu or {}
UI.layoutScale = nil

local baseMenuLayout = {
	marginTop = 128,
	marginBottom = 112,
	marginHorizontal = 156,
	buttonStackOffset = 48,
	subtitleSpacing = 18,
	footerSpacing = 32,
	tooltipOffset = 18,
	panelMaxWidth = 420,
}

local function scaledSpacingValue(key, scale)
	if key == "shadowOffset" then
		return SHADOW_OFFSET
	end
	local baseValue = baseSpacing[key] or 0
	local minValue = spacingMinimums[key] or 0
	local value = round(baseValue * scale)
	if minValue > 0 then
		value = max(minValue, value)
	end
	return value
end

local function applySpacing(scale)
	for key in pairs(baseSpacing) do
		UI.spacing[key] = scaledSpacingValue(key, scale)
	end

	UI.spacing.shadowOffset = SHADOW_OFFSET

	local headerPadding = round(baseSectionHeaderPadding * scale)
	if baseSectionHeaderPadding > 0 then
		headerPadding = max(4, headerPadding)
	end

	local headingFont = UI.fonts.heading
	if headingFont and headingFont.getHeight then
		UI.spacing.sectionHeaderHeight = headingFont:getHeight() + headerPadding
	else
		local fallbackHeight = round((fontDefinitions.heading.size + baseSectionHeaderPadding) * scale)
		fallbackHeight = max(headerPadding * 2, fallbackHeight)
		UI.spacing.sectionHeaderHeight = fallbackHeight
	end
end

local function applyUpgradeLayout(scale)
	local layout = UI.upgradeIndicators.layout
	layout.width = max(160, round(baseUpgradeLayout.width * scale))
	layout.spacing = max(8, round(baseUpgradeLayout.spacing * scale))
	layout.baseHeight = max(42, round(baseUpgradeLayout.baseHeight * scale))
	layout.iconRadius = max(12, round(baseUpgradeLayout.iconRadius * scale))
	layout.barHeight = max(4, round(baseUpgradeLayout.barHeight * scale))
	layout.margin = max(16, round(baseUpgradeLayout.margin * scale))
end

local function applySocketSize(scale)
	UI.socketSize = max(18, round(baseSocketSize * scale))
end

local function applyMenuLayout(scale, sw, sh)
	local layout = UI.layout.menu or {}

	local function scaled(value, minimum)
		local result = round((value or 0) * scale)
		if minimum then
			result = max(minimum, result)
		end
		return result
	end

	layout.marginTop = max(48, scaled(baseMenuLayout.marginTop, 0))
	layout.marginBottom = max(48, scaled(baseMenuLayout.marginBottom, 0))
	layout.marginHorizontal = max(48, scaled(baseMenuLayout.marginHorizontal, 0))
	layout.buttonStackOffset = max(12, scaled(baseMenuLayout.buttonStackOffset, 0))
	layout.subtitleSpacing = max(8, scaled(baseMenuLayout.subtitleSpacing, 0))
	layout.footerSpacing = max(12, scaled(baseMenuLayout.footerSpacing, 0))
	layout.tooltipOffset = max(10, scaled(baseMenuLayout.tooltipOffset, 0))
	layout.panelMaxWidth = max(260, scaled(baseMenuLayout.panelMaxWidth, 0))
	layout.sectionSpacing = UI.spacing.sectionSpacing
	layout.headerSpacing = UI.spacing.sectionHeaderSpacing

	local titleHeight
	if UI.fonts.title and UI.fonts.title.getHeight then
		titleHeight = UI.fonts.title:getHeight()
	else
		titleHeight = scaled(fontDefinitions.title.size, 48)
	end

	layout.titleHeight = titleHeight
	layout.titleY = layout.marginTop
	layout.stackTop = layout.titleY + titleHeight + layout.subtitleSpacing
	layout.bodyTop = layout.stackTop + layout.buttonStackOffset
	layout.bottomY = sh - layout.marginBottom
	layout.contentWidth = max(0, sw - layout.marginHorizontal * 2)
	layout.screenWidth = sw
	layout.screenHeight = sh

	UI.layout.menu = layout
end

function UI.getScale()
	return UI.layoutScale or 1
end

function UI.scaled(value, minValue)
	local result = (value or 0) * UI.getScale()
	if minValue then
		result = max(minValue, result)
	end
	return round(result)
end

function UI.refreshLayout(sw, sh)
	if not sw or not sh or sw <= 0 or sh <= 0 then
		return
	end

	local widthScale = sw / BASE_SCREEN_WIDTH
	local heightScale = sh / BASE_SCREEN_HEIGHT
	local scale = min(widthScale, heightScale)
	if MIN_LAYOUT_SCALE then
		scale = max(MIN_LAYOUT_SCALE, scale)
	end
	if MAX_LAYOUT_SCALE then
		scale = min(MAX_LAYOUT_SCALE, scale)
	end

	if UI.layoutScale and abs(scale - UI.layoutScale) < 0.01 then
		return
	end

	UI.layoutScale = scale

	buildFonts(scale)
	applySpacing(scale)
	applyUpgradeLayout(scale)
	applySocketSize(scale)
	applyMenuLayout(scale, sw, sh)
end

function UI.getHeaderY(sw, sh)
	local layout = UI.getMenuLayout(sw, sh)
	if layout then
		local titleY = layout.titleY or layout.marginTop
		if titleY then
			return titleY
		end
	end

	if sh and sh > 0 then
		return round(sh * 0.08)
	end

	return 78
end

function UI.getMenuLayout(sw, sh)
	local layout = UI.layout and UI.layout.menu or nil
	if not layout then
		local widthScale = sw and (sw / BASE_SCREEN_WIDTH) or 1
		local heightScale = sh and (sh / BASE_SCREEN_HEIGHT) or widthScale
		local scale = min(widthScale, heightScale)
		local function scaled(value, minimum)
			local result = round((value or 0) * scale)
			if minimum then
				result = max(minimum, result)
			end
			return result
		end

		local sectionSpacing = UI.spacing and UI.spacing.sectionSpacing or scaled(baseSpacing.sectionSpacing or 28, 0)
		local headerSpacing = UI.spacing and UI.spacing.sectionHeaderSpacing or scaled(baseSpacing.sectionHeaderSpacing or 16, 0)

		return {
			marginTop = max(48, scaled(baseMenuLayout.marginTop or 128, 0)),
			marginBottom = max(48, scaled(baseMenuLayout.marginBottom or 112, 0)),
			marginHorizontal = max(48, scaled(baseMenuLayout.marginHorizontal or 156, 0)),
			buttonStackOffset = max(12, scaled(baseMenuLayout.buttonStackOffset or 48, 0)),
			subtitleSpacing = max(8, scaled(baseMenuLayout.subtitleSpacing or 18, 0)),
			footerSpacing = max(12, scaled(baseMenuLayout.footerSpacing or 32, 0)),
			tooltipOffset = max(10, scaled(baseMenuLayout.tooltipOffset or 18, 0)),
			panelMaxWidth = max(260, scaled(baseMenuLayout.panelMaxWidth or 420, 0)),
			sectionSpacing = sectionSpacing,
			headerSpacing = headerSpacing,
		}
	end

	if sw and sh then
		local resolved = {}
		for key, value in pairs(layout) do
			resolved[key] = value
		end
		resolved.screenWidth = sw
		resolved.screenHeight = sh
		resolved.contentWidth = resolved.contentWidth or max(0, sw - (resolved.marginHorizontal or 0) * 2)
		resolved.bottomY = resolved.bottomY or (sh - (resolved.marginBottom or 0))
		if not resolved.stackTop then
			local titleHeight = resolved.titleHeight or ((UI.fonts.title and UI.fonts.title:getHeight()) or round(fontDefinitions.title.size or 72))
			local baseTitleY = resolved.titleY or (sh * 0.08)
			resolved.stackTop = baseTitleY + titleHeight + (resolved.subtitleSpacing or 16)
		end
		if not resolved.bodyTop then
			resolved.bodyTop = resolved.stackTop + (resolved.buttonStackOffset or 0)
		end
		return resolved
	end

	return layout
end

UI.colors = {
	background  = Theme.bgColor,
	text        = Theme.textColor,
	subtleText  = {Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], (Theme.textColor[4] or 1) * 0.7},
	button      = Theme.buttonColor,
	buttonHover = Theme.buttonHover or lightenColor(Theme.buttonColor, 0.15),
	buttonPress = Theme.buttonPress or darkenColor(Theme.buttonColor, 0.65),
	border      = {0, 0, 0, 1},
	panel       = Theme.panelColor,
	panelBorder = {0, 0, 0, 1},
	shadow      = Theme.shadowColor,
	highlight   = Theme.highlightColor or {1, 1, 1, 0.08},
	progress    = Theme.progressColor,
	accentText  = Theme.accentTextColor,
	mutedText   = Theme.mutedTextColor,
	warning     = Theme.warningColor,
}

-- Utility: set font
function UI.setFont(font)
	love.graphics.setFont(UI.fonts[font or "body"])
end

-- Utility: draw rounded rectangle
function UI.drawRoundedRect(x, y, w, h, r, segments)
	local radius = r or UI.spacing.buttonRadius
	radius = min(radius, w / 2, h / 2)
	love.graphics.rectangle("fill", x, y, w, h, radius, radius, segments)
end

function UI.drawPanel(x, y, w, h, opts)
	opts = opts or {}
	local radius = opts.radius or UI.spacing.panelRadius
	radius = radius or 0
	local borderWidth = 0
	if opts.border ~= false then
		borderWidth = opts.borderWidth or 2
	end
	local shadowPadding = calculateShadowPadding(borderWidth, opts.shadowStrokeWidth)
	local shadowRadius = radius + shadowPadding
	if shadowRadius > 0 then
		local maxShadowRadius = min((w + shadowPadding * 2) / 2, (h + shadowPadding * 2) / 2)
		if maxShadowRadius > 0 then
			shadowRadius = min(shadowRadius, maxShadowRadius)
		end
	end
	local shadowOffset = opts.shadowOffset
	if shadowOffset == nil then shadowOffset = UI.shadowOffset end

	if shadowOffset and shadowOffset ~= 0 then
		setColor(opts.shadowColor or UI.colors.shadow, opts.shadowAlpha or 1)
		love.graphics.rectangle(
			"fill",
			x + shadowOffset - shadowPadding,
			y + shadowOffset - shadowPadding,
			w + shadowPadding * 2,
			h + shadowPadding * 2,
			shadowRadius,
			shadowRadius
		)
	end

	local alphaMultiplier = opts.alpha or 1
	local fillColor = opts.fill or UI.colors.panel or UI.colors.button
	setColor(fillColor, alphaMultiplier)
	love.graphics.rectangle("fill", x, y, w, h, radius, radius)

	if opts.highlight ~= false then
		local highlightAlpha = opts.highlightAlpha
		if highlightAlpha == nil then
			highlightAlpha = 0.12
		end
		highlightAlpha = highlightAlpha * alphaMultiplier
		if highlightAlpha > 0 then
			local prevMode, prevAlphaMode = love.graphics.getBlendMode()
			love.graphics.setBlendMode("add", "alphamultiply")
			local highlightColor = opts.highlightColor or {1, 1, 1, 1}
			local hr = highlightColor[1] or 1
			local hg = highlightColor[2] or 1
			local hb = highlightColor[3] or 1
			local ha = (highlightColor[4] or 1) * highlightAlpha
			love.graphics.setColor(hr, hg, hb, ha)
			love.graphics.rectangle("fill", x, y, w, h, radius, radius)
			love.graphics.setBlendMode(prevMode, prevAlphaMode)
		end
	end

	if opts.border ~= false then
		local borderColor = opts.borderColor or UI.colors.border or UI.colors.panelBorder
		setColor(borderColor, alphaMultiplier)
		love.graphics.setLineWidth(borderWidth)
		love.graphics.rectangle("line", x, y, w, h, radius, radius)
		love.graphics.setLineWidth(1)
	end

	if opts.focused then
		local focusRadius = radius + (opts.focusRadiusOffset or 4)
		local focusPadding = opts.focusPadding or 3
		local focusColor = opts.focusColor or UI.colors.highlight or UI.colors.border
		setColor(focusColor, opts.focusAlpha or 1.1)
		love.graphics.setLineWidth(opts.focusWidth or 3)
		love.graphics.rectangle("line", x - focusPadding, y - focusPadding, w + focusPadding * 2, h + focusPadding * 2, focusRadius, focusRadius)
		love.graphics.setLineWidth(1)
	end
end

function UI.drawLabel(text, x, y, width, align, opts)
	opts = opts or {}
	local font = opts.font or UI.fonts[opts.fontKey or "body"]
	if font then
		love.graphics.setFont(font)
	end

	local alpha = opts.alpha or 1

	local shadow = opts.shadow
	if shadow == nil then
		shadow = opts.dropShadow
	end

	if shadow then
		local baseOffset = opts.shadowOffset
		if baseOffset == nil then
			local baseShadow = UI.shadowOffset or 0
			baseOffset = max(1, floor(baseShadow * 0.4 + 0.5))
		end

		local shadowOffsetX = opts.shadowOffsetX
		local shadowOffsetY = opts.shadowOffsetY
		if shadowOffsetX == nil and shadowOffsetY == nil then
			shadowOffsetX = baseOffset
			shadowOffsetY = baseOffset
		else
			shadowOffsetX = shadowOffsetX or 0
			shadowOffsetY = shadowOffsetY or 0
		end

		if shadowOffsetX ~= 0 or shadowOffsetY ~= 0 then
			local shadowColor = opts.shadowColor or UI.colors.shadow or {0, 0, 0, 0.6}
			local shadowAlpha = (opts.shadowAlpha or 1) * alpha
			setColor(shadowColor, shadowAlpha)

			if width then
				love.graphics.printf(text, x + shadowOffsetX, y + shadowOffsetY, width, align or "left")
			else
				love.graphics.print(text, x + shadowOffsetX, y + shadowOffsetY)
			end
		end
	end

	local color = opts.color or UI.colors.text
	setColor(color, alpha)

	if width then
		love.graphics.printf(text, x, y, width, align or "left")
	else
		love.graphics.print(text, x, y)
	end
end

function UI.drawSlider(id, x, y, w, value, opts)
	opts = opts or {}
	local h = opts.height or UI.spacing.sliderHeight
	local radius = opts.radius or UI.spacing.buttonRadius
	local padding = opts.padding or UI.spacing.sliderPadding
	local trackHeight = opts.trackHeight or UI.spacing.sliderTrackHeight
	local handleRadius = opts.handleRadius or UI.spacing.sliderHandleRadius
	local focused = opts.focused

	if opts.register ~= false and id then
		UI.registerButton(id, x, y, w, h, opts.label)
	end

	local hovered = opts.hovered
	local baseFill = opts.fill or UI.colors.button
	if hovered and not focused then
		baseFill = opts.hoverFill or UI.colors.buttonHover
	end

	UI.drawPanel(x, y, w, h, {
		radius = radius,
		shadowOffset = opts.shadowOffset,
		fill = baseFill,
		borderColor = opts.borderColor or UI.colors.border,
		focused = focused,
		focusColor = opts.focusColor or UI.colors.highlight,
		focusAlpha = opts.focusAlpha,
	})

	local label = opts.label
	if label then
		UI.drawLabel(label, x + padding, y + padding, w - padding * 2, opts.labelAlign or "left", {
			fontKey = opts.labelFont or "body",
			color = opts.labelColor or UI.colors.text,
		})
	end

	local sliderValue = clamp01(value or 0)
	local trackX = x + padding
	local trackW = w - padding * 2
	local trackY = y + h - padding - trackHeight

	setColor(UI.colors.panel, 0.7)
	love.graphics.rectangle("fill", trackX, trackY, trackW, trackHeight, trackHeight / 2, trackHeight / 2)

	if sliderValue > 0 then
		setColor(opts.progressColor or UI.colors.progress)
		love.graphics.rectangle("fill", trackX, trackY, trackW * sliderValue, trackHeight, trackHeight / 2, trackHeight / 2)
	end

	local handleX = trackX + trackW * sliderValue
	local handleY = trackY + trackHeight / 2
	setColor(opts.handleColor or UI.colors.text)
	love.graphics.circle("fill", handleX, handleY, handleRadius)

	if opts.showValue ~= false then
		local valueFont = UI.fonts[opts.valueFont or "small"]
		if valueFont then
			love.graphics.setFont(valueFont)
		end
		setColor(opts.valueColor or UI.colors.subtleText)
		local percentText = opts.valueText or string.format("%d%%", floor(sliderValue * 100 + 0.5))
		love.graphics.printf(percentText, trackX, trackY - (valueFont and valueFont:getHeight() or 14) - 6, trackW, "right")
	end

	love.graphics.setLineWidth(1)

	return trackX, trackY, trackW, trackHeight, handleRadius
end

-- Easing
local function easeOutQuad(t)
	return t * (2 - t)
end

-- Register a button (once per frame in your draw code)
function UI.registerButton(id, x, y, w, h, text)
	UI.buttons[id] = UI.buttons[id] or createButtonState()
	local btn = UI.buttons[id]
	local bounds = btn.bounds
	if not bounds then
		bounds = {}
		btn.bounds = bounds
	end
	bounds.x = x
	bounds.y = y
	bounds.w = w
	bounds.h = h
	btn.text = text
end

-- Draw button (render only)
function UI.drawButton(id)
	local btn = UI.buttons[id]
	if not btn or not btn.bounds then return end

	local b = btn.bounds
	local s = UI.spacing

        local mx, my = UI.getCursorPosition()
        local hoveredByMouse = UI.isHovered(b.x, b.y, b.w, b.h, mx, my)
	local displayHover = hoveredByMouse or btn.focused

	if displayHover and not btn.wasHovered then
		Audio:playSound("hover")
	end
	btn.wasHovered = displayHover
	btn.hoverTarget = displayHover and 1 or 0

	-- Animate press depth
	local pressAnim = btn.anim or 0
	local yOffset = easeOutQuad(pressAnim) * 4

	local baseScale = 1 + (btn.popProgress or 0) * 0.08
	local hoverScale = 1 + (btn.hoverAnim or 0) * 0.02
	local focusScale = 1 + (btn.focusAnim or 0) * 0.015
	local totalScale = baseScale * hoverScale * focusScale

	local centerX = b.x + b.w / 2
	local centerY = b.y + yOffset + b.h / 2

	love.graphics.push()
	love.graphics.translate(centerX, centerY)
	love.graphics.scale(totalScale, totalScale)
	love.graphics.translate(-centerX, -centerY)

	local radius = s.buttonRadius or 0
	local hasBorder = UI.colors.border ~= nil
	local borderWidth = hasBorder and (UI.buttonBorderWidth or BUTTON_BORDER_WIDTH) or 0
	local shadowPadding = calculateShadowPadding(borderWidth, UI.buttonShadowStrokeWidth)
	local shadowRadius = radius + shadowPadding
	if shadowRadius > 0 then
		local maxShadowRadius = min((b.w + shadowPadding * 2) / 2, (b.h + shadowPadding * 2) / 2)
		if maxShadowRadius > 0 then
			shadowRadius = min(shadowRadius, maxShadowRadius)
		end
	end
	local shadowOffset = s.shadowOffset
	if shadowOffset == nil then
		shadowOffset = UI.shadowOffset
	end

	if shadowOffset and shadowOffset ~= 0 then
		local shadowOffsetX = shadowOffset - 1
		local shadowOffsetY = shadowOffset - 1
		setColor(UI.colors.shadow)
		love.graphics.rectangle(
			"fill",
			b.x + shadowOffsetX - shadowPadding,
			b.y + shadowOffsetY + yOffset - shadowPadding,
			b.w + shadowPadding * 2,
			b.h + shadowPadding * 2,
			shadowRadius,
			shadowRadius
		)
	end

	local fillColor = UI.colors.button
	local isToggled = btn.toggled
	if displayHover then
		fillColor = UI.colors.buttonHover
	end
	if btn.pressed or isToggled then
		fillColor = UI.colors.buttonPress
	end

	setColor(fillColor)
	love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)

	local highlightStrength = (btn.hoverAnim or 0) * 0.18 + (btn.popProgress or 0) * 0.22
	if highlightStrength > 0.001 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 0.12 + 0.18 * highlightStrength)
		love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	if hasBorder then
		setColor(UI.colors.border)
		love.graphics.setLineWidth(borderWidth)
		love.graphics.rectangle("line", b.x, b.y + yOffset, b.w, b.h, radius, radius)
	end

	if btn.focused then
		local focusStrength = btn.focusAnim or 0
		if focusStrength > 0.01 then
			local focusRadius = radius + 4
			local padding = 3
			local focusColor = UI.colors.highlight or UI.colors.border
			setColor(focusColor, 0.8 + 0.4 * focusStrength)
			love.graphics.setLineWidth(3)
			love.graphics.rectangle("line", b.x - padding, b.y + yOffset - padding, b.w + padding * 2, b.h + padding * 2, focusRadius, focusRadius)
		end
	end

	local glowStrength = btn.glow or 0
	if glowStrength > 0.01 then
		local prevMode, prevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 0.16 * glowStrength)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", b.x + 2, b.y + yOffset + 2, b.w - 4, b.h - 4, radius - 2, radius - 2)
		love.graphics.setBlendMode(prevMode, prevAlphaMode)
	end

	love.graphics.setLineWidth(1)

	-- TEXT
	UI.setFont("button")
	local textColor = UI.colors.text
	if displayHover or (btn.focusAnim or 0) > 0.001 or isToggled then
		btn._lightenedTextColor = lightenColor(textColor, 0.18 + 0.1 * (btn.focusAnim or 0), btn._lightenedTextColor)
		textColor = btn._lightenedTextColor
	end
	local text = btn.text or ""
	local textY = b.y + yOffset + (b.h - UI.fonts.button:getHeight()) / 2

	setColor({0, 0, 0, 0.7})
	love.graphics.printf(text, b.x + 1, textY + 1, b.w, "center")

	setColor(textColor)
	love.graphics.printf(text, b.x, textY, b.w, "center")

	love.graphics.pop()
end

-- Hover check
function UI.isHovered(x, y, w, h, px, py)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Mouse press
function UI:mousepressed(x, y, button)
        UI.refreshCursor(x, y)
        if button == 1 then
                for id, btn in pairs(UI.buttons) do
                        local b = btn.bounds
			if b and UI.isHovered(b.x, b.y, b.w, b.h, x, y) then
				btn.pressed = true
				Audio:playSound("click")
				return id
			end
		end
	end
end

-- Mouse release
function UI:mousereleased(x, y, button)
        UI.refreshCursor(x, y)
        if button == 1 then
                for id, btn in pairs(UI.buttons) do
                        if btn.pressed then
				btn.pressed = false
				local b = btn.bounds
				if b and UI.isHovered(b.x, b.y, b.w, b.h, x, y) then
					btn.popTimer = 0
					btn.popProgress = 0
					return id -- valid click
				end
			end
		end
	end
end

function UI:reset()
	self.combo.count = 0
	self.combo.timer = 0
	self.combo.duration = 0
	self.combo.pop = 0
	self.shields.count = 0
	self.shields.display = 0
	self.shields.popTimer = 0
	self.shields.shakeTimer = 0
	self.shields.flashTimer = 0
	self.shields.lastDirection = 0
end

function UI:setFruitGoal(required)
	self.fruitRequired = required
	self.fruitCollected = 0
	self.fruitSockets = {} -- clear collected fruit sockets each floor
end

function UI:adjustFruitGoal(delta)
	if not delta or delta == 0 then return end

	local newGoal = max(1, (self.fruitRequired or 0) + delta)
	self.fruitRequired = newGoal

	if (self.fruitCollected or 0) > newGoal then
		self.fruitCollected = newGoal
	end

	if type(self.fruitSockets) == "table" then
		while #self.fruitSockets > newGoal do
			remove(self.fruitSockets)
		end
	end
end


function UI:isGoalReached()
	if self.fruitCollected >= self.fruitRequired then
		if not self.goalCelebrated then
			self:celebrateGoal()
		end
		return true
	end
end

function UI:addFruit(fruitType)
	self.fruitCollected = min(self.fruitCollected + 1, self.fruitRequired)
	local fruit = fruitType or {name = "Apple", color = {1, 0, 0}}
	insert(self.fruitSockets, {
		type = fruit,
		anim = 0,
		state = "appearing",
		wobblePhase = love.math.random() * pi * 2,
		bounceTimer = 0,
		removeTimer = 0,
		celebrationGlow = nil,
		celebrationDelay = nil,
		pendingCelebration = nil,
	})
end

function UI:removeFruit(count)
	count = floor(count or 0)
	if count <= 0 then
		return 0
	end

	local removed = 0
	local removalStagger = 0
	self.fruitCollected = max(0, self.fruitCollected or 0)

	for _ = 1, count do
		if (self.fruitCollected or 0) <= 0 then
			break
		end

		self.fruitCollected = self.fruitCollected - 1
		removed = removed + 1

		if type(self.fruitSockets) == "table" and #self.fruitSockets > 0 then
			local marked = false
			for i = #self.fruitSockets, 1, -1 do
				local socket = self.fruitSockets[i]
				if socket and socket.state ~= "removing" then
					socket.state = "removing"
					socket.removeTimer = 0
					socket.removeDelay = removalStagger
					socket.anim = min(socket.anim or self.socketAnimTime, self.socketAnimTime)
					socket.bounceTimer = nil
					socket.celebrationGlow = nil
					socket.celebrationDelay = nil
					socket.pendingCelebration = nil
					socket.wobblePhase = socket.wobblePhase or love.math.random() * pi * 2
					marked = true
					removalStagger = removalStagger + 0.05
					break
				end
			end

			if not marked then
				local last = self.fruitSockets[#self.fruitSockets]
				if last then
					last.state = "removing"
					last.removeTimer = 0
					last.removeDelay = removalStagger
					last.anim = min(last.anim or self.socketAnimTime, self.socketAnimTime)
					last.bounceTimer = nil
					last.celebrationGlow = nil
					last.celebrationDelay = nil
					last.pendingCelebration = nil
					last.wobblePhase = last.wobblePhase or love.math.random() * pi * 2
					removalStagger = removalStagger + 0.05
				end
			end
		end
	end

	if (self.fruitCollected or 0) < (self.fruitRequired or 0) then
		self.goalCelebrated = false
		self.goalReachedAnim = 0
	end

	return removed
end

function UI:celebrateGoal()
	self.goalReachedAnim = 0
	self.goalCelebrated = true
	Audio:playSound("goal_reached")
	for index, socket in ipairs(self.fruitSockets) do
		if socket.state ~= "removing" then
			socket.bounceTimer = nil
			socket.pendingCelebration = true
			socket.celebrationDelay = (index - 1) * 0.05
			socket.celebrationGlow = nil
		end
	end
end

function UI:update(dt)
	for _, button in pairs(UI.buttons) do
		local hoverTarget = button.hoverTarget or 0
		local focusTarget = button.focused and 1 or 0
		button.anim = approachExp(button.anim or 0, button.pressed and 1 or 0, dt, 18)
		if hoverTarget > 0 then
			button.hoverAnim = approachExp(button.hoverAnim or 0, hoverTarget, dt, 12)
		else
			button.hoverAnim = 0
		end
		button.focusAnim = approachExp(button.focusAnim or 0, focusTarget, dt, 9)
		local glowTarget = max(hoverTarget, focusTarget)
		button.glow = approachExp(button.glow or 0, glowTarget, dt, 5)

		if button.popTimer ~= nil then
			button.popTimer = button.popTimer + dt
			local progress = min(1, button.popTimer / BUTTON_POP_DURATION)
			button.popProgress = sin(progress * pi) * (1 - progress * 0.45)
			if progress >= 1 then
				button.popTimer = nil
			end
		else
			button.popProgress = approachExp(button.popProgress or 0, 0, dt, 10)
		end

		button.hoverTarget = 0
	end

	-- update fruit socket animations
	for i = #self.fruitSockets, 1, -1 do
		local socket = self.fruitSockets[i]
		local removeSocket = false

		socket.anim = socket.anim or 0
		socket.removeTimer = socket.removeTimer or 0

		if socket.state == "removing" then
			socket.removeTimer = socket.removeTimer + dt
			local delay = socket.removeDelay or 0
			if socket.removeTimer >= delay then
				local removalDuration = self.socketRemoveTime > 0 and self.socketRemoveTime or self.socketAnimTime
				local removalSpeed = self.socketAnimTime / (removalDuration > 0 and removalDuration or 1)
				socket.anim = max(0, socket.anim - dt * removalSpeed)
				if socket.anim <= 0.001 then
					removeSocket = true
				end
			end
		else
			if socket.anim < self.socketAnimTime then
				socket.anim = min(socket.anim + dt, self.socketAnimTime)
			elseif socket.state == "appearing" then
				socket.state = "idle"
			end
		end

		if socket.pendingCelebration and socket.state ~= "removing" then
			if not self.goalCelebrated then
				socket.pendingCelebration = nil
				socket.celebrationDelay = nil
			else
				socket.celebrationDelay = (socket.celebrationDelay or 0) - dt
				if (socket.celebrationDelay or 0) <= 0 then
					socket.pendingCelebration = nil
					socket.celebrationDelay = nil
					socket.celebrationGlow = 1
					socket.bounceTimer = 0
				end
			end
		elseif socket.state == "removing" then
			socket.pendingCelebration = nil
			socket.celebrationDelay = nil
			socket.celebrationGlow = nil
		end

		if socket.bounceTimer ~= nil then
			socket.bounceTimer = socket.bounceTimer + dt
			if socket.bounceTimer >= self.socketBounceDuration then
				socket.bounceTimer = nil
			end
		end

		if socket.celebrationGlow then
			socket.celebrationGlow = socket.celebrationGlow - dt * 1.8
			if socket.celebrationGlow <= 0.01 then
				socket.celebrationGlow = nil
			end
		end

		if socket.wobblePhase == nil then
			socket.wobblePhase = love.math.random() * pi * 2
		end
		local wobbleSpeed = socket.state == "removing" and 5.0 or 6.2
		socket.wobblePhase = socket.wobblePhase + dt * wobbleSpeed

		if removeSocket then
			remove(self.fruitSockets, i)
		end
	end

	if self.goalCelebrated then
		self.goalReachedAnim = self.goalReachedAnim + dt
		if self.goalReachedAnim > 1 then
			self.goalCelebrated = false
		end
	end

	if self.combo.pop > 0 then
		self.combo.pop = max(0, self.combo.pop - dt * 3)
	end

	local shields = self.shields
	if shields then
		if shields.display == nil then
			shields.display = shields.count or 0
		end

		local target = shields.count or 0
		local current = shields.display or 0
		local diff = target - current
		if abs(diff) > 0.01 then
			local step = diff * min(dt * 10, 1)
			shields.display = current + step
		else
			shields.display = target
		end

		if shields.popTimer and shields.popTimer > 0 then
			shields.popTimer = max(0, shields.popTimer - dt)
		end

		if shields.shakeTimer and shields.shakeTimer > 0 then
			shields.shakeTimer = max(0, shields.shakeTimer - dt)
		end

		if shields.flashTimer and shields.flashTimer > 0 then
			shields.flashTimer = max(0, shields.flashTimer - dt)
		end
	end

        local container = self.upgradeIndicators
        if container and container.items then
                local smoothing = min(dt * 8, 1)
                local toRemove = {}
                for id, item in pairs(container.items) do
			item.visibility = item.visibility or 0
			local targetVis = item.targetVisibility or 0
			item.visibility = lerp(item.visibility, targetVis, smoothing)

			if item.targetProgress ~= nil then
				item.displayProgress = item.displayProgress or item.targetProgress or 0
				item.displayProgress = lerp(item.displayProgress, item.targetProgress, smoothing)
			else
				item.displayProgress = nil
			end

			if item.visibility <= 0.01 and targetVis <= 0 then
				insert(toRemove, id)
			end
                end

                for _, id in ipairs(toRemove) do
                        container.items[id] = nil
                end

                local visibleList = container.visibleList
                if visibleList then
                        local seen = container._visibleSeen or {}
                        container._visibleSeen = seen
                        for key in pairs(seen) do
                                seen[key] = nil
                        end

                        local count = 0
                        if container.order then
                                for _, id in ipairs(container.order) do
                                        local item = container.items[id]
                                        if item and clamp01(item.visibility or 0) > 0.01 then
                                                count = count + 1
                                                visibleList[count] = item
                                                seen[id] = true
                                        end
                                end
                        end

                        for id, item in pairs(container.items) do
                                if not seen[id] and clamp01(item.visibility or 0) > 0.01 then
                                        count = count + 1
                                        visibleList[count] = item
                                end
                        end

                        for key in pairs(seen) do
                                seen[key] = nil
                        end

                        for i = count + 1, #visibleList do
                                visibleList[i] = nil
                        end
                end
        end

end

function UI:setCombo(count, timer, duration)
	local combo = self.combo
	local previous = combo.count or 0

	combo.count = count or 0
	combo.timer = timer or 0

	if duration and duration > 0 then
		combo.duration = duration
	elseif not combo.duration then
		combo.duration = 0
	end

	if combo.count >= 2 then
		if combo.count > previous then
			combo.pop = 1.0
		end

	else
		if previous >= 2 then
			combo.pop = 0
		end
	end
end


function UI:setShields(count, opts)
	local shields = self.shields
	if not shields then return end

	count = max(0, floor((count or 0) + 0.0001))

	if shields.count == nil then
		shields.count = count
		shields.display = count
		return
	end

	local previous = shields.count or 0
	shields.count = count

	if opts and opts.immediate then
		shields.display = count
	end

	if count == previous then
		return
	end

	local silent = opts and opts.silent

	if count > previous then
		shields.lastDirection = 1
		shields.popTimer = shields.popDuration
		shields.flashTimer = shields.flashDuration * 0.6
		shields.shakeTimer = 0
		if not silent then
			Audio:playSound("shield_gain")
		end
	else
		shields.lastDirection = -1
		shields.shakeTimer = shields.shakeDuration
		shields.flashTimer = shields.flashDuration
		shields.popTimer = 0
		if not silent then
			Audio:playSound("shield_break")
		end
	end
end

function UI:setUpgradeIndicators(indicators)
	local container = self.upgradeIndicators
	if not container then return end

	local items = container.items
	if not items then
		container.items = {}
		items = container.items
	end

	local seen = {}
	container.order = {}

	if indicators then
		for index, data in ipairs(indicators) do
			local id = data.id or ("indicator_" .. tostring(index))
			seen[id] = true
			container.order[#container.order + 1] = id

			local item = items[id]
			if not item then
				item = {
					id = id,
					visibility = 0,
					targetVisibility = 1,
					displayProgress = data.charge ~= nil and clamp01(data.charge) or nil,
				}
				items[id] = item
			end

			item.targetVisibility = 1
			item.label = data.label or id
			item.stackCount = data.stackCount
			item.icon = data.icon
			item.accentColor = data.accentColor or {1, 1, 1, 1}
			item.status = data.status
			item.chargeLabel = data.chargeLabel
			if data.charge ~= nil then
				item.targetProgress = clamp01(data.charge)
				if item.displayProgress == nil then
					item.displayProgress = item.targetProgress
				end
			else
				item.targetProgress = nil
				item.displayProgress = nil
			end
			if data.showBar ~= nil then
				item.showBar = data.showBar
			else
				item.showBar = data.charge ~= nil
			end
		end
	end

	for id, item in pairs(items) do
		if not seen[id] then
			item.targetVisibility = 0
		end
	end
end

local function drawComboIndicator(self)
	local combo = self.combo
	local comboActive = combo and combo.count >= 2 and (combo.duration or 0) > 0

	if not comboActive then
		return
	end

	local duration = combo.duration or 0
	local timer = 0
	local progress = 0
	timer = max(0, min(combo.timer or 0, duration))
	progress = duration > 0 and timer / duration or 0

	local screenW = love.graphics.getWidth()
	local titleText = "Combo"
	titleText = "Combo x" .. combo.count

	local width = max(240, UI.fonts.button:getWidth(titleText) + 120)
	local height = 68
	local x = (screenW - width) / 2
	local y = 16

	local scale = 1 + 0.08 * sin((1 - progress) * pi * 2) + (combo.pop or 0) * 0.25

	love.graphics.push()
	love.graphics.translate(x + width / 2, y + height / 2)
	love.graphics.scale(scale, scale)
	love.graphics.translate(-(x + width / 2), -(y + height / 2))

	love.graphics.setColor(0, 0, 0, 0.4)
	love.graphics.rectangle("fill", x + 4, y + 6, width, height, 18, 18)

	love.graphics.setColor(Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], 0.95)
	love.graphics.rectangle("fill", x, y, width, height, 18, 18)

	love.graphics.setColor(UI.colors.border)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", x, y, width, height, 18, 18)

	UI.setFont("button")
	love.graphics.setColor(Theme.textColor)
	love.graphics.printf(titleText, x, y + 8, width, "center")

	local barPadding = 18
	local barHeight = 10
	local barWidth = width - barPadding * 2
	local comboBarY = y + height - barPadding - barHeight

	if comboActive then
		love.graphics.setColor(0, 0, 0, 0.25)
		love.graphics.rectangle("fill", x + barPadding, comboBarY, barWidth, barHeight, 6, 6)

		love.graphics.setColor(1, 0.78, 0.3, 0.85)
		love.graphics.rectangle("fill", x + barPadding, comboBarY, barWidth * progress, barHeight, 6, 6)
	end

	love.graphics.pop()
end

local ICON_ACCENT_DEFAULT = {1, 1, 1, 1}
local ICON_COLOR_BASE = {0, 0, 0, 1}
local ICON_COLOR_DETAIL = {0, 0, 0, 1}
local ICON_COLOR_OUTLINE = {0, 0, 0, 1}
local ICON_COLOR_HIGHLIGHT = {0, 0, 0, 1}
local ICON_COLOR_SHEEN = {0, 0, 0, 1}
local ICON_COLOR_RIM = {0, 0, 0, 1}
local ICON_COLOR_SEAM = {0, 0, 0, 1}

local DEFAULT_UPGRADE_PANEL_COLOR = {0.16, 0.18, 0.22, 1}
local DEFAULT_SOCKET_PANEL_COLOR = {0.16, 0.16, 0.22, 0.94}
local DEFAULT_HIGHLIGHT_COLOR = {1, 1, 1, 0.08}
local ICON_OVERLAY_BACKGROUND = {0, 0, 0, 1}
local ICON_OVERLAY_TEXT_DEFAULT = {1, 1, 1, 1}

--[[
Graphics state usage:
* transform: applies push/translate and may rotate/scale for certain icons
* colours: adjusts active color for fills, lines, and overlay elements
* line width: changes between multiple stroke widths
* font: temporarily switches fonts for overlay labels
]]
local function drawIndicatorIcon(icon, accentColor, x, y, radius, overlay)
        local accent = accentColor or ICON_ACCENT_DEFAULT

        local originalR, originalG, originalB, originalA = love.graphics.getColor()
        local originalLineWidth = love.graphics.getLineWidth()
        local originalFont = love.graphics.getFont()

        love.graphics.push()
        love.graphics.translate(x, y)

        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", 3, 4, radius + 3, 28)

	local base = darkenColor(accent, 0.6, ICON_COLOR_BASE)
	love.graphics.setColor(base[1], base[2], base[3], base[4] or 1)
	love.graphics.circle("fill", 0, 0, radius, 28)

	local detail = lightenColor(accent, 0.12, ICON_COLOR_DETAIL)
	love.graphics.setColor(detail[1], detail[2], detail[3], detail[4] or 1)

	if icon == "shield" then
		local shieldRadius = radius * 0.9
		local topY = -shieldRadius
		local rightX = shieldRadius * 0.78
		local midY = -shieldRadius * 0.28
		local lowerRightX = shieldRadius * 0.55
		local lowerY = shieldRadius * 0.85
		local bottomY = shieldRadius
		local lowerLeftX = -lowerRightX
		local leftX = -rightX
		local function drawShieldPolygon(mode)
			love.graphics.polygon(
			mode,
			0, topY,
			rightX, midY,
			lowerRightX, lowerY,
			0, bottomY,
			lowerLeftX, lowerY,
			leftX, midY
			)
		end

		drawShieldPolygon("fill")
		local outline = lightenColor(accent, 0.35, ICON_COLOR_OUTLINE)
		love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
		love.graphics.setLineWidth(2)
		drawShieldPolygon("line")
	elseif icon == "bolt" then
		love.graphics.polygon(
		"fill",
		-radius * 0.28, -radius * 0.92,
		radius * 0.42, -radius * 0.2,
		radius * 0.08, -radius * 0.18,
		radius * 0.48, radius * 0.82,
		-radius * 0.2, radius * 0.14,
		radius * 0.05, 0
		)
	elseif icon == "pickaxe" then
		love.graphics.push()
		love.graphics.rotate(-pi / 8)
		love.graphics.rectangle("fill", -radius * 0.14, -radius * 0.92, radius * 0.28, radius * 1.84, radius * 0.16)
		love.graphics.pop()
		local outline = lightenColor(accent, 0.35, ICON_COLOR_OUTLINE)
		love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", 0, 0, radius * 0.95, 28)
	elseif icon == "hourglass" then
		local baseHalfWidth = radius * 0.62
		local baseHeight = radius * 0.86

		love.graphics.polygon(
		"fill",
		0, 0,
		-baseHalfWidth, -baseHeight,
		baseHalfWidth, -baseHeight
		)
		love.graphics.polygon(
		"fill",
		0, 0,
		-baseHalfWidth, baseHeight,
		baseHalfWidth, baseHeight
		)

		local highlight = lightenColor(detail, 0.22, ICON_COLOR_HIGHLIGHT)
		love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * 0.85)
		local highlightHalfWidth = radius * 0.38
		local highlightBase = radius * 0.64
		local highlightApexOffset = radius * 0.18
		love.graphics.polygon(
		"fill",
		0, -highlightApexOffset,
		-highlightHalfWidth, -highlightBase,
		highlightHalfWidth, -highlightBase
		)
		love.graphics.polygon(
		"fill",
		0, highlightApexOffset,
		-highlightHalfWidth, highlightBase,
		highlightHalfWidth, highlightBase
		)

		local sheen = lightenColor(detail, 0.42, ICON_COLOR_SHEEN)
		love.graphics.setColor(sheen[1], sheen[2], sheen[3], (sheen[4] or 1) * 0.6)
		love.graphics.setLineWidth(1.4)
		love.graphics.line(-radius * 0.22, -radius * 0.72, -radius * 0.05, -radius * 0.2)
		love.graphics.line(radius * 0.22, radius * 0.72, radius * 0.05, radius * 0.2)

		local rim = lightenColor(detail, 0.32, ICON_COLOR_RIM)
		love.graphics.setColor(rim[1], rim[2], rim[3], rim[4] or 1)
		love.graphics.setLineWidth(2.2)
		love.graphics.polygon(
		"line",
		0, 0,
		-baseHalfWidth, -baseHeight,
		baseHalfWidth, -baseHeight
		)
		love.graphics.polygon(
		"line",
		0, 0,
		-baseHalfWidth, baseHeight,
		baseHalfWidth, baseHeight
		)

		local seam = darkenColor(detail, 0.25, ICON_COLOR_SEAM)
		love.graphics.setColor(seam[1], seam[2], seam[3], (seam[4] or 1) * 0.9)
		love.graphics.setLineWidth(1.5)
		love.graphics.line(-baseHalfWidth, -baseHeight, baseHalfWidth, -baseHeight)
		love.graphics.line(-baseHalfWidth, baseHeight, baseHalfWidth, baseHeight)
	elseif icon == "phoenix" then
		love.graphics.polygon(
		"fill",
		-radius * 0.88, radius * 0.16,
		-radius * 0.26, -radius * 0.7,
		0, -radius * 0.25,
		radius * 0.26, -radius * 0.7,
		radius * 0.88, radius * 0.16,
		0, radius * 0.88
		)
	else
		love.graphics.circle("fill", 0, 0, radius * 0.72, 28)
	end

	if overlay and overlay.text then
		local overlayBackground = lightenColor(accent, 0.1, ICON_OVERLAY_BACKGROUND)
		overlayBackground[4] = 0.92
		local background = overlay.backgroundColor or overlayBackground
		local borderColor = overlay.borderColor or lightenColor(accent, 0.35, ICON_COLOR_OUTLINE)
		local fontKey = overlay.font or "small"
		local paddingX = overlay.paddingX or 6
		local paddingY = overlay.paddingY or 2
                local overlayPreviousFont = love.graphics.getFont()
                UI.setFont(fontKey)
                local font = love.graphics.getFont()
                local text = tostring(overlay.text)
                local textWidth = font:getWidth(text)
                local boxWidth = textWidth + paddingX * 2
                local boxHeight = font:getHeight() + paddingY * 2
		local position = overlay.position or "bottomRight"
		local anchorX, anchorY

		if position == "topLeft" then
			anchorX = -radius * 0.75
			anchorY = -radius * 0.75
		elseif position == "topRight" then
			anchorX = radius * 0.75
			anchorY = -radius * 0.75
		elseif position == "bottomLeft" then
			anchorX = -radius * 0.75
			anchorY = radius * 0.75
		elseif position == "center" then
			anchorX = 0
			anchorY = 0
		else
			anchorX = radius * 0.75
			anchorY = radius * 0.75
		end

		anchorX = anchorX + (overlay.offsetX or 0)
		anchorY = anchorY + (overlay.offsetY or 0)

		local boxX = anchorX - boxWidth * 0.5
		local boxY = anchorY - boxHeight * 0.5
		local cornerRadius = overlay.cornerRadius or min(10, boxHeight * 0.5)

		love.graphics.setColor(background[1], background[2], background[3], background[4] or 1)
		love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, cornerRadius, cornerRadius)

		love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1))
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, cornerRadius, cornerRadius)

		local textColor = overlay.textColor or ICON_OVERLAY_TEXT_DEFAULT
		love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
		local textY = boxY + (boxHeight - font:getHeight()) * 0.5
		love.graphics.printf(text, boxX, textY, boxWidth, "center")
                if overlayPreviousFont then
                        love.graphics.setFont(overlayPreviousFont)
                end
        end

        love.graphics.pop()

        love.graphics.setLineWidth(originalLineWidth)
        if originalFont then
                love.graphics.setFont(originalFont)
        end
        love.graphics.setColor(originalR, originalG, originalB, originalA)
end

local SHIELD_ACCENT_READY = {0.55, 0.82, 1.0, 1.0}
local SHIELD_ACCENT_DEPLETED = {1.0, 0.55, 0.45, 1.0}
local SHIELD_OVERLAY_BACKGROUND = {0, 0, 0, 0.92}

local function buildShieldIndicator(self)
        local shields = self.shields
        if not shields then return nil end

        local rawCount = shields.count
	if rawCount == nil then
		rawCount = shields.display
	end

        local count = max(0, floor((rawCount or 0) + 0.5))

        if count <= 0 then
                return nil
        end

        local accent = SHIELD_ACCENT_READY
        local statusKey = "ready"

        if (shields.lastDirection or 0) < 0 and (shields.flashTimer or 0) > 0 then
                accent = SHIELD_ACCENT_DEPLETED
                statusKey = "depleted"
        end

        local revision = Localization:getRevision()
        local needsRefresh = (self._shieldLocaleRevision ~= revision)
        if not needsRefresh then
                local cachedStatusKey = self._shieldStatusKey or "ready"
                if cachedStatusKey ~= statusKey then
                        needsRefresh = true
                end
        end

        if needsRefresh then
                self._shieldLocaleRevision = revision
                self._shieldStatusKey = statusKey
                self._shieldLabel = Localization:get("upgrades.hud.shields")
                if statusKey ~= "ready" then
                        self._shieldStatusText = Localization:get("upgrades.hud." .. statusKey)
                else
                        self._shieldStatusText = nil
                end
        end

        local overlayBackground = lightenColor(accent, 0.1, SHIELD_OVERLAY_BACKGROUND)
        overlayBackground[4] = 0.92

        return {
                id = "__shields",
                label = self._shieldLabel,
                icon = "shield",
                accentColor = accent,
                iconOverlay = {
                        text = count,
                        position = "center",
			font = "badge",
			paddingX = 8,
                        paddingY = 4,
                        backgroundColor = overlayBackground,
                        textColor = Theme.textColor,
                },
                status = self._shieldStatusText,
                showBar = false,
                visibility = 1,
        }
end

local UPGRADE_BAR_FILL_COLOR = {0, 0, 0, 1}
local UPGRADE_BAR_OUTLINE_COLOR = {0, 0, 0, 1}

--[[
Graphics state usage:
* colours: sets panel, border, text, and progress bar colours
* line width: adjusts stroke widths for borders and progress outlines
* font: switches between UI fonts for labels, stacks, and charge text
]]
local function drawUpgradeIndicatorEntry(cursor, layout, colors, entry)
        if not entry then
                return cursor.y
        end

        local visibility = clamp01(entry.visibility or 1)
        if visibility <= 0.01 then
                return cursor.y
        end

        local accent = entry.accentColor or Theme.panelBorder or ICON_ACCENT_DEFAULT
        local hasBar = entry.showBar and entry.displayProgress ~= nil
        local panelHeight = layout.baseHeight + (hasBar and 8 or 0)

        local drawY = cursor.y
        local x = cursor.x
        local width = layout.width

        local originalR, originalG, originalB, originalA = love.graphics.getColor()
        local originalLineWidth = love.graphics.getLineWidth()
        local originalFont = love.graphics.getFont()

        love.graphics.setColor(0, 0, 0, 0.4 * visibility)
        love.graphics.rectangle("fill", x + 4, drawY + 6, width, panelHeight, 14, 14)

        local panelColor = Theme.arenaBG or Theme.panelColor or DEFAULT_UPGRADE_PANEL_COLOR
        love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1) * (0.95 * visibility))
        love.graphics.rectangle("fill", x, drawY, width, panelHeight, 14, 14)

        local border = colors.border or UI.colors.border
        love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * visibility)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, drawY, width, panelHeight, 14, 14)

        local iconRadius = layout.iconRadius
        local iconX = x + iconRadius + 14
        local iconY = drawY + iconRadius + 12
        drawIndicatorIcon(entry.icon or "circle", accent, iconX, iconY, iconRadius, entry.iconOverlay)

        local textX = iconX + iconRadius + 12
        local textWidth = max(60, width - (textX - x) - 14)
        local chargeFont = UI.fonts.body
        local chargeFontHeight = (chargeFont and chargeFont:getHeight()) or 16

        local showLabel = entry.hideLabel ~= true and entry.label and entry.label ~= ""
        local labelTop = drawY + 16

        if showLabel then
                UI.setFont("body")
                love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], visibility)
                love.graphics.printf(entry.label, textX, labelTop, textWidth, "left")
        end

        if entry.stackCount and entry.stackCount > 0 then
                local stackText = entry.stackCount
                if type(stackText) == "number" then
                        if stackText > 1 then
                                stackText = "×" .. tostring(stackText)
                        else
                                stackText = tostring(stackText)
                        end
                else
                        stackText = tostring(stackText)
                end
                UI.setFont("body")
                love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.9 * visibility)
                love.graphics.printf(stackText, textX, labelTop, textWidth, "right")
        end

        if hasBar then
                local progress = clamp01(entry.displayProgress or 0)
                local iconBarWidth = layout.iconBarWidth or (iconRadius * 1.8)
                if entry.chargeLabel and chargeFont and chargeFont.getWidth then
                        local labelWidth = chargeFont:getWidth(entry.chargeLabel)
                        iconBarWidth = max(iconBarWidth, labelWidth + 16)
                end
                local iconBarHeight = layout.iconBarHeight or max(4, floor(layout.barHeight))
                local barX = iconX - iconBarWidth * 0.5
                local desiredBarY = iconY + iconRadius + 6
                local reservedSpace = entry.chargeLabel and (chargeFontHeight + 8) or 6
                local maxBarY = drawY + panelHeight - iconBarHeight - reservedSpace
                local barY = min(desiredBarY, maxBarY)

                love.graphics.setColor(0, 0, 0, 0.28 * visibility)
                love.graphics.rectangle("fill", barX, barY, iconBarWidth, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

                local fill = lightenColor(accent, 0.05, UPGRADE_BAR_FILL_COLOR)
                love.graphics.setColor(fill[1], fill[2], fill[3], (fill[4] or 1) * 0.85 * visibility)
                love.graphics.rectangle("fill", barX, barY, iconBarWidth * progress, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

                local outline = lightenColor(accent, 0.3, UPGRADE_BAR_OUTLINE_COLOR)
                love.graphics.setColor(outline[1], outline[2], outline[3], (outline[4] or 1) * 0.9 * visibility)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", barX, barY, iconBarWidth, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

                if entry.chargeLabel then
                        UI.setFont("body")
                        love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.9 * visibility)
                        local labelY = barY + iconBarHeight + 4
                        love.graphics.printf(entry.chargeLabel, barX, labelY, iconBarWidth, "center")
                end
        elseif entry.chargeLabel then
                UI.setFont("body")
                love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.9 * visibility)
                local labelY = drawY + panelHeight - chargeFontHeight - 12
                love.graphics.printf(entry.chargeLabel, textX, labelY, textWidth, "right")
        end

        love.graphics.setLineWidth(originalLineWidth)
        if originalFont then
                love.graphics.setFont(originalFont)
        end
        love.graphics.setColor(originalR, originalG, originalB, originalA)

        return cursor.y + panelHeight + layout.spacing
end

function UI:drawUpgradeIndicators()
        local container = self.upgradeIndicators
        if not container or not container.items then return end

        local entries = container.visibleList or {}
        local shieldEntry = buildShieldIndicator(self)

        if (#entries == 0) and not shieldEntry then
                return
        end

        local containerLayout = container.layout or {}
        local width = containerLayout.width or 252
        local spacing = containerLayout.spacing or 12
        local baseHeight = containerLayout.baseHeight or 64
        local barHeight = containerLayout.barHeight or 10
        local iconRadius = containerLayout.iconRadius or 18
        local margin = containerLayout.margin or 24

        local screenW = love.graphics.getWidth()
        local x = screenW - width - margin
        local cursor = {
                x = x,
                y = margin,
        }

        local layout = {
                width = width,
                spacing = spacing,
                baseHeight = baseHeight,
                barHeight = barHeight,
                iconRadius = iconRadius,
                iconBarWidth = containerLayout.iconBarWidth,
                iconBarHeight = containerLayout.iconBarHeight,
        }

        local colors = {
                border = UI.colors.border,
        }

        if shieldEntry then
                cursor.y = drawUpgradeIndicatorEntry(cursor, layout, colors, shieldEntry)
        end

        for i = 1, #entries do
                cursor.y = drawUpgradeIndicatorEntry(cursor, layout, colors, entries[i])
        end
end


local SOCKET_FILL_COLOR = {0, 0, 0, 1}
local SOCKET_OUTLINE_COLOR = {0, 0, 0, 1}
local FRUIT_HIGHLIGHT_COLOR = {0, 0, 0, 1}

function UI:drawFruitSockets()
	if self.fruitRequired <= 0 then
		self.fruitPanelBounds = nil
		return
	end

	-- Position the fruit sockets near the top-left corner.
	local headerHeight = 0
	local paddingOffsetY = 8
	local baseX, baseY = 20, 20
	local perRow = 10
	local spacing = self.socketSize + 6
	local rows = max(1, math.ceil(self.fruitRequired / perRow))
	local cols = min(self.fruitRequired, perRow)
	if cols == 0 then cols = 1 end

	local gridWidth = (cols - 1) * spacing + self.socketSize
	local gridHeight = (rows - 1) * spacing + self.socketSize
	local paddingX = self.socketSize * 0.75
	local paddingY = self.socketSize * 0.75 + paddingOffsetY

	local panelX = 20
	local panelY = 20

	local panelW = gridWidth + paddingX * 2
	local panelH = headerHeight + gridHeight + paddingY * 2

	local innerWidth = panelW - paddingX * 2
	local innerHeight = panelH - paddingY * 2 - headerHeight
	local baseOffsetX = max(0, (innerWidth - gridWidth) * 0.5)
	local baseOffsetY = max(0, (innerHeight - gridHeight) * 0.5)
	baseX = panelX + paddingX + baseOffsetX
	baseY = panelY + paddingY + headerHeight + baseOffsetY

	local goalFlash = 0
	if self.goalCelebrated then
		local flashT = clamp01(self.goalReachedAnim / 0.7)
		goalFlash = pow(1 - flashT, 1.4)
	end

	-- backdrop styled like the HUD panel card
	local shadowOffsetBase = UI.shadowOffset or 0
	local shadowInset = 3
	local shadowOffsetX = shadowOffsetBase - shadowInset
	local shadowOffsetY = shadowOffsetBase - shadowInset
	if shadowOffsetX ~= 0 or shadowOffsetY ~= 0 then
		local shadowColor = Theme.shadowColor or {0, 0, 0, 0.5}
		local shadowAlpha = shadowColor[4] or 1
		love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
		love.graphics.rectangle("fill", panelX + shadowOffsetX, panelY + shadowOffsetY, panelW, panelH, 12, 12)
	end

        local basePanelColor = Theme.arenaBG or Theme.panelColor or DEFAULT_SOCKET_PANEL_COLOR
	local panelColor = basePanelColor
	if goalFlash > 0 then
		panelColor = lightenColor(panelColor, 0.25 * goalFlash)
	end

	love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1))
	love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

	local borderColor = UI.colors.border or {0, 0, 0, 1}
	if goalFlash > 0 then
		borderColor = lightenColor(borderColor, 0.4 * goalFlash)
	end
	love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1))
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)

	local time = Timer.getTime()
	local socketRadius = (self.socketSize / 2) - 2
	local socketFill = lightenColor(basePanelColor, 0.45, SOCKET_FILL_COLOR)
	local socketOutline = lightenColor(UI.colors.panelBorder or Theme.textColor, 0.2, SOCKET_OUTLINE_COLOR)

        local highlightColor = (UI.colors and UI.colors.highlight) or Theme.highlightColor or DEFAULT_HIGHLIGHT_COLOR

	for i = 1, self.fruitRequired do
		local row = floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		local bounce = 0
		local x = baseX + col * spacing + self.socketSize / 2
		local y = baseY + row * spacing + self.socketSize / 2 + bounce

		-- socket shadow
		local socket = self.fruitSockets[i]
		local hasFruit = socket ~= nil
		local appear = hasFruit and clamp01(socket.anim / self.socketAnimTime) or 0
		local radius = hasFruit and socketRadius or socketRadius * 0.8
		local shadowAlpha = hasFruit and (0.45 * max(appear, 0.2)) or 0.4
		love.graphics.setColor(0, 0, 0, shadowAlpha)
		love.graphics.circle("fill", x + shadowOffsetX, y + shadowOffsetY, radius, 48)

		-- empty socket base
		love.graphics.setColor(socketFill[1], socketFill[2], socketFill[3], (socketFill[4] or 1) * 0.9)
		love.graphics.circle("fill", x, y, radius, 48)

		-- subtle animated rim
		local rimPulse = 0.35 + 0.25 * sin(time * 3.5 + i * 0.7)
		love.graphics.setColor(socketOutline[1], socketOutline[2], socketOutline[3], (socketOutline[4] or 1) * rimPulse)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", x, y, radius, 48)

		love.graphics.setColor(1, 1, 1, 0.08 * (hasFruit and appear or 1))
		love.graphics.arc("fill", x, y, radius * 1.1, -pi * 0.6, -pi * 0.1, 24)

		-- draw fruit if collected
		if socket then
			local t = clamp01(socket.anim / self.socketAnimTime)
			local appearEase
			if socket.state == "removing" then
				appearEase = 1 - Easing.easeInBack(1 - t)
			else
				appearEase = Easing.easeOutBack(t)
			end
			appearEase = max(0, appearEase)

			local scale = min(1.18, appearEase)
			local bounceScale = 1
			if socket.bounceTimer ~= nil then
				local bounceProgress = clamp01(socket.bounceTimer / self.socketBounceDuration)
				bounceScale = 1 + sin(bounceProgress * pi) * 0.24 * (1 - bounceProgress * 0.4)
			end

			local celebrationWave = 0
			if self.goalCelebrated then
				local waveTime = self.goalReachedAnim or 0
				local waveFade = max(0, 1 - clamp01(waveTime / 0.9))
				celebrationWave = sin(waveTime * 12 - i * 0.35) * 0.05 * waveFade
			end

			local goalPulse = 1 + (socket.celebrationGlow or 0) * 0.22 + celebrationWave
			goalPulse = max(0.85, goalPulse)

			local visibility = t
			if socket.state == "removing" then
				visibility = visibility * visibility
			else
				visibility = pow(visibility, 0.85)
			end

			love.graphics.push()
			love.graphics.translate(x, y)
			local wobbleRotation = 0
			if socket.wobblePhase then
				wobbleRotation = sin(socket.wobblePhase) * 0.08 * (1 - t)
			end
			love.graphics.rotate(wobbleRotation)
			love.graphics.scale(scale * goalPulse * bounceScale, scale * goalPulse * bounceScale)

			-- fruit shadow inside socket
			love.graphics.setColor(0, 0, 0, 0.3 * visibility)
			love.graphics.ellipse("fill", 0, radius * 0.55, radius * 0.8, radius * 0.45, 32)

			local r = radius
			local fruit = socket.type

			local fruitAlpha = (fruit.color[4] or 1) * visibility
			love.graphics.setColor(fruit.color[1], fruit.color[2], fruit.color[3], fruitAlpha)
			love.graphics.circle("fill", 0, 0, r, 32)

			love.graphics.setColor(0, 0, 0, max(0.2, visibility))
			love.graphics.setLineWidth(3)
			love.graphics.circle("line", 0, 0, r, 32)

			-- juicy highlight
			local highlightColor = lightenColor(fruit.color, 0.6, FRUIT_HIGHLIGHT_COLOR)
			local highlightAlpha = (highlightColor[4] or 1) * 0.75 * visibility
			love.graphics.push()
			love.graphics.translate(-r * 0.3 + 1, -r * 0.35)
			love.graphics.rotate(-0.35)
			love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightAlpha)
			love.graphics.ellipse("fill", 0, 0, r * 0.55, r * 0.45, 32)
			love.graphics.pop()

			-- sparkling rim when fruit is fresh
			if t < 1 and socket.state ~= "removing" then
				local sparkle = 0.25 + 0.55 * (1 - t)
				love.graphics.setColor(1, 1, 1, sparkle * visibility)
				love.graphics.setLineWidth(2)
				love.graphics.circle("line", 0, 0, r + 3, 24)
				love.graphics.setLineWidth(3)
			end

			if socket.celebrationGlow then
				local glow = socket.celebrationGlow
				local sparkleRadius = r + 4 + glow * 4
				love.graphics.setLineWidth(2)
				love.graphics.setColor(1, 1, 1, 0.18 * glow * visibility)
				love.graphics.circle("line", 0, 0, sparkleRadius, 28)
				love.graphics.setLineWidth(3)
				local barWidth = 3 + glow * 2
				local barLength = sparkleRadius * 1.1
				love.graphics.setColor(1, 1, 1, 0.12 * glow * visibility)
				love.graphics.rectangle("fill", -barWidth * 0.5, -barLength, barWidth, barLength * 2, barWidth * 0.4, barWidth * 0.4)
				love.graphics.rectangle("fill", -barLength, -barWidth * 0.5, barLength * 2, barWidth, barWidth * 0.4, barWidth * 0.4)
			end

			-- dragonfruit glow
			if fruit.name == "Dragonfruit" then
				local pulse = 0.65 + 0.35 * sin(time * 7.2)
				local glowColor = Theme.dragonfruitColor or {1, 0.45, 0.86, 1}
				local accentAlpha = (0.45 + 0.35 * pulse) * visibility

				love.graphics.setLineWidth(4)
				love.graphics.setColor(
				min(1, glowColor[1] + 0.15),
				min(1, glowColor[2] * 0.75),
				min(1, glowColor[3] * 1.1),
				accentAlpha
				)
				love.graphics.circle("line", 0, 0, r + 4 + 3 * pulse, 40)

				love.graphics.setColor(1, 0.45, 1, 0.24 * pulse * visibility)
				love.graphics.circle("line", 0, 0, r + 9 + 6 * pulse, 40)
				love.graphics.setLineWidth(3)
			end

			love.graphics.pop()
		else
			-- idle shimmer in empty sockets
			local emptyGlow = 0.12 + 0.12 * sin(time * 5 + i * 0.9)
			if goalFlash > 0 then
				emptyGlow = emptyGlow + 0.08 * goalFlash
			end
			love.graphics.setColor(
			highlightColor[1],
			highlightColor[2],
			highlightColor[3],
			(highlightColor[4] or 1) * emptyGlow
			)
			love.graphics.circle("line", x, y, radius - 1.5, 32)
		end
	end

	-- draw fruit counter text anchored to the socket panel
	local collected = tostring(self.fruitCollected)
	local required  = tostring(self.fruitRequired)
	UI.setFont("button")
	local font = love.graphics.getFont()
	local padding = 12
	local textY = panelY + panelH + padding
	local shadowColor = Theme.shadowColor or {0, 0, 0, 0.5}
	love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], (shadowColor[4] or 1))
	love.graphics.printf(
	collected .. " / " .. required,
	panelX + 2,
	textY + 2,
	panelW,
	"right"
	)
	love.graphics.setColor(Theme.textColor)
	love.graphics.printf(
	collected .. " / " .. required,
	panelX,
	textY,
	panelW,
	"right"
	)

	self.fruitPanelBounds = {
		x = panelX,
		y = panelY,
		w = panelW,
		h = panelH,
	}
end

function UI:draw()
        self:refreshCursor()
        -- draw socket grid
        self:drawFruitSockets()
        self:drawUpgradeIndicators()
	drawComboIndicator(self)
end

UI.refreshLayout(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT)

return UI