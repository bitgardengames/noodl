local Audio = require("audio")
local Theme = require("theme")
local Localization = require("localization")
local Easing = require("easing")

local UI = {}

local ScorePulse = 1.0
local PulseTimer = 0
local PULSE_DURATION = 0.3

UI.FruitCollected = 0
UI.FruitRequired = 0
UI.FruitSockets = {}
UI.SocketAnimTime = 0.25
UI.SocketRemoveTime = 0.18
UI.SocketBounceDuration = 0.65
UI.SocketSize = 26
UI.GoalReachedAnim = 0
UI.GoalCelebrated = false

UI.combo = {
	count = 0,
	timer = 0,
	duration = 0,
	pop = 0,
}

UI.shields = {
	count = 0,
	display = 0,
	PopDuration = 0.32,
	PopTimer = 0,
	ShakeDuration = 0.45,
	ShakeTimer = 0,
	FlashDuration = 0.4,
	FlashTimer = 0,
	LastDirection = 0,
}

UI.UpgradeIndicators = {
	items = {},
	order = {},
	layout = {},
}

local BASE_SCREEN_WIDTH = 1920
local BASE_SCREEN_HEIGHT = 1080
local MIN_LAYOUT_SCALE = 0.6
local MAX_LAYOUT_SCALE = 1.5

local FontDefinitions = {
	title = { path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 72, min = 28 },
	display = { path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 64, min = 24 },
	subtitle = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 32, min = 18 },
	heading = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 28, min = 16 },
	button = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 24, min = 14 },
	body = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 16, min = 12 },
	prompt = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 20, min = 12 },
	caption = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 14, min = 10 },
	small = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 12, min = 9 },
	timer = { path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 42, min = 24 },
	TimerSmall = { path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 20, min = 12 },
	achieve = { path = "Assets/Fonts/Comfortaa-Bold.ttf", size = 18, min = 12 },
	badge = { path = "Assets/Fonts/Comfortaa-SemiBold.ttf", size = 20, min = 12 },
}

local BaseSpacing = {
	ButtonWidth = 260,
	ButtonHeight = 56,
	ButtonRadius = 14,
	ButtonSpacing = 24,
	PanelRadius = 16,
	PanelPadding = 20,
	ShadowOffset = 6,
	SectionSpacing = 28,
	SectionHeaderSpacing = 16,
	SliderHeight = 68,
	SliderTrackHeight = 10,
	SliderHandleRadius = 12,
	SliderPadding = 22,
}

local SpacingMinimums = {
	ButtonWidth = 180,
	ButtonHeight = 44,
	ButtonRadius = 8,
	ButtonSpacing = 16,
	PanelRadius = 12,
	PanelPadding = 14,
	ShadowOffset = 2,
	SectionSpacing = 18,
	SectionHeaderSpacing = 10,
	SliderHeight = 48,
	SliderTrackHeight = 4,
	SliderHandleRadius = 10,
	SliderPadding = 14,
}

local BaseUpgradeLayout = {
	width = 208,
	spacing = 12,
	baseHeight = 58,
	iconRadius = 18,
	barHeight = 6,
	margin = 24,
}

local BaseSocketSize = 26
local BaseSectionHeaderPadding = 8

UI.fonts = {}

local BUTTON_POP_DURATION = 0.32

local function clamp01(value)
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function ApproachExp(current, target, dt, speed)
	if speed <= 0 or dt <= 0 then
		return target
	end

	local factor = 1 - math.exp(-speed * dt)
	return current + (target - current) * factor
end

local function LightenColor(color, amount)
	if not color then
		return {1, 1, 1, 1}
	end

	local a = color[4] or 1
	return {
		color[1] + (1 - color[1]) * amount,
		color[2] + (1 - color[2]) * amount,
		color[3] + (1 - color[3]) * amount,
		a,
	}
end

local function DarkenColor(color, amount)
	if not color then
		return {0, 0, 0, 1}
	end

	local a = color[4] or 1
	return {
		color[1] * amount,
		color[2] * amount,
		color[3] * amount,
		a,
	}
end

local function SetColor(color, AlphaMultiplier)
	if not color then
		love.graphics.setColor(1, 1, 1, AlphaMultiplier or 1)
		return
	end

	local r = color[1] or 1
	local g = color[2] or 1
	local b = color[3] or 1
	local a = color[4] or 1
	love.graphics.setColor(r, g, b, a * (AlphaMultiplier or 1))
end

local HeartBasePoints
local HeartTriangles
local HeartMesh
local HeartOutlinePoints = {}

local function GetHeartBasePoints()
	if HeartBasePoints then
		return HeartBasePoints
	end

	local segments = 72
	local RawPoints = {}
	local MinX, MaxX = math.huge, -math.huge
	local MinY, MaxY = math.huge, -math.huge

	for i = 0, segments - 1 do
		local t = (i / segments) * (2 * math.pi)
		local SinT = math.sin(t)
		local CosT = math.cos(t)
		local x = 16 * SinT * SinT * SinT
		local y = -(13 * CosT - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))

		RawPoints[#RawPoints + 1] = { x, y }

		if x < MinX then MinX = x end
		if x > MaxX then MaxX = x end
		if y < MinY then MinY = y end
		if y > MaxY then MaxY = y end
	end

	local height = MaxY - MinY
	if height == 0 then
		height = 1
	end

	local CenterX = (MinX + MaxX) * 0.5
	local CenterY = (MinY + MaxY) * 0.5

	local points = {}
	for i = 1, #RawPoints do
		local rx, ry = RawPoints[i][1], RawPoints[i][2]
		points[#points + 1] = (rx - CenterX) / height
		points[#points + 1] = (ry - CenterY) / height
	end

	HeartBasePoints = points
	return points
end

local function GetHeartTriangles()
	if HeartTriangles then
		return HeartTriangles
	end

	if not love.math or not love.math.triangulate then
		HeartTriangles = { GetHeartBasePoints() }
		return HeartTriangles
	end

	local BasePoints = GetHeartBasePoints()
	local coords = {}
	for i = 1, #BasePoints do
		coords[i] = BasePoints[i]
	end

	HeartTriangles = love.math.triangulate(coords)
	return HeartTriangles
end

local function GetHeartMesh()
	if HeartMesh ~= nil then
		return HeartMesh
	end

	if not love.graphics or not love.graphics.newMesh then
		HeartMesh = false
		return HeartMesh
	end

	local triangles = GetHeartTriangles()
	local vertices = {}

	for i = 1, #triangles do
		local triangle = triangles[i]
		for j = 1, #triangle, 2 do
			local vx = triangle[j]
			local vy = triangle[j + 1]
			vertices[#vertices + 1] = { vx, vy, 0, 0, 1, 1, 1, 1 }
		end
	end

	HeartMesh = love.graphics.newMesh(vertices, "triangles", "static")
	return HeartMesh
end

local function DrawHeartGeometry(x, y, size)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.scale(size, size)

	local mesh = GetHeartMesh()
	if mesh then
		love.graphics.draw(mesh)
	else
		local triangles = GetHeartTriangles()
		for i = 1, #triangles do
			love.graphics.polygon("fill", triangles[i])
		end
	end

	love.graphics.pop()
end

local function DrawHeartOutline(x, y, size, thickness)
	if thickness <= 0 then
		return
	end

	local BasePoints = GetHeartBasePoints()
	local coords = HeartOutlinePoints
	for i = 1, #coords do
		coords[i] = nil
	end

	local FirstX, FirstY
	for i = 1, #BasePoints, 2 do
		local px = x + BasePoints[i] * size
		local py = y + BasePoints[i + 1] * size

		if not FirstX then
			FirstX, FirstY = px, py
		end

		coords[#coords + 1] = px
		coords[#coords + 1] = py
	end

	if FirstX then
		coords[#coords + 1] = FirstX
		coords[#coords + 1] = FirstY
	end

	local PreviousWidth = love.graphics.getLineWidth()
	local PreviousJoin = love.graphics.getLineJoin()
	local PreviousStyle = love.graphics.getLineStyle()

	love.graphics.setLineWidth(thickness)
	love.graphics.setLineJoin("bevel")
	love.graphics.setLineStyle("smooth")

	love.graphics.polygon("line", coords)

	love.graphics.setLineWidth(PreviousWidth)
	love.graphics.setLineJoin(PreviousJoin)
	love.graphics.setLineStyle(PreviousStyle)
end

local function DrawHeartShape(x, y, size)
	if size <= 0 then
		return
	end

	local r, g, b, a = love.graphics.getColor()

	love.graphics.setColor(0, 0, 0, a)
	DrawHeartOutline(x, y, size, HEART_OUTLINE_SIZE)

	love.graphics.setColor(r, g, b, a)
	DrawHeartGeometry(x, y, size)

	-- top-left highlight for a juicy look similar to fruits
	love.graphics.stencil(function()
		DrawHeartGeometry(x, y, size)
	end, "replace", 1)

	love.graphics.setStencilTest("greater", 0)

	local highlight = LightenColor({r, g, b, a}, 0.6)
	local hx = x - size * 0.18
	local hy = y - size * 0.28
	local hrx = size * 0.46
	local hry = size * 0.34
	love.graphics.push()
	love.graphics.translate(hx, hy)
	love.graphics.rotate(-0.35)
	love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * 0.75)
	love.graphics.ellipse("fill", 0, 0, hrx, hry)
	love.graphics.pop()

	love.graphics.setStencilTest()

	love.graphics.setColor(r, g, b, a)
end

-- Button states
UI.buttons = {}

local function CreateButtonState()
	return {
		pressed = false,
		anim = 0,
		HoverAnim = 0,
		FocusAnim = 0,
		HoverTarget = 0,
		glow = 0,
		PopProgress = 0,
	}
end

function UI.ClearButtons()
	UI.buttons = {}
end

function UI.SetButtonFocus(id, focused)
	if not id then return end

	local btn = UI.buttons[id]
	if not btn then
		btn = CreateButtonState()
		UI.buttons[id] = btn
	end

	btn.focused = focused or nil
end

local function round(value)
	return math.floor(value + 0.5)
end

local function BuildFonts(scale)
	for key, def in pairs(FontDefinitions) do
		local size = round(def.size * scale)
		if def.min then
			size = math.max(def.min, size)
		end
		UI.fonts[key] = love.graphics.newFont(def.path, size)
	end
end

UI.spacing = {}
UI.LayoutScale = nil

local function ScaledSpacingValue(key, scale)
	local BaseValue = BaseSpacing[key] or 0
	local MinValue = SpacingMinimums[key] or 0
	local value = round(BaseValue * scale)
	if MinValue > 0 then
		value = math.max(MinValue, value)
	end
	return value
end

local function ApplySpacing(scale)
	for key in pairs(BaseSpacing) do
		UI.spacing[key] = ScaledSpacingValue(key, scale)
	end

	local HeaderPadding = round(BaseSectionHeaderPadding * scale)
	if BaseSectionHeaderPadding > 0 then
		HeaderPadding = math.max(4, HeaderPadding)
	end

	local HeadingFont = UI.fonts.heading
	if HeadingFont and HeadingFont.getHeight then
		UI.spacing.SectionHeaderHeight = HeadingFont:getHeight() + HeaderPadding
	else
		local FallbackHeight = round((FontDefinitions.heading.size + BaseSectionHeaderPadding) * scale)
		FallbackHeight = math.max(HeaderPadding * 2, FallbackHeight)
		UI.spacing.SectionHeaderHeight = FallbackHeight
	end
end

local function ApplyUpgradeLayout(scale)
	local layout = UI.UpgradeIndicators.layout
	layout.width = math.max(160, round(BaseUpgradeLayout.width * scale))
	layout.spacing = math.max(8, round(BaseUpgradeLayout.spacing * scale))
	layout.baseHeight = math.max(42, round(BaseUpgradeLayout.baseHeight * scale))
	layout.iconRadius = math.max(12, round(BaseUpgradeLayout.iconRadius * scale))
	layout.barHeight = math.max(4, round(BaseUpgradeLayout.barHeight * scale))
	layout.margin = math.max(16, round(BaseUpgradeLayout.margin * scale))
end

local function ApplySocketSize(scale)
	UI.SocketSize = math.max(18, round(BaseSocketSize * scale))
end

function UI.GetScale()
	return UI.LayoutScale or 1
end

function UI.scaled(value, MinValue)
	local result = (value or 0) * UI.GetScale()
	if MinValue then
		result = math.max(MinValue, result)
	end
	return round(result)
end

function UI.RefreshLayout(sw, sh)
	if not sw or not sh or sw <= 0 or sh <= 0 then
		return
	end

	local WidthScale = sw / BASE_SCREEN_WIDTH
	local HeightScale = sh / BASE_SCREEN_HEIGHT
	local scale = math.min(WidthScale, HeightScale)
	if MIN_LAYOUT_SCALE then
		scale = math.max(MIN_LAYOUT_SCALE, scale)
	end
	if MAX_LAYOUT_SCALE then
		scale = math.min(MAX_LAYOUT_SCALE, scale)
	end

	if UI.LayoutScale and math.abs(scale - UI.LayoutScale) < 0.01 then
		return
	end

	UI.LayoutScale = scale

	BuildFonts(scale)
	ApplySpacing(scale)
	ApplyUpgradeLayout(scale)
	ApplySocketSize(scale)
end

UI.colors = {
	background  = Theme.BgColor,
	text        = Theme.TextColor,
	SubtleText  = {Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], (Theme.TextColor[4] or 1) * 0.7},
	button      = Theme.ButtonColor,
	ButtonHover = Theme.ButtonHover or LightenColor(Theme.ButtonColor, 0.15),
	ButtonPress = Theme.ButtonPress or DarkenColor(Theme.ButtonColor, 0.65),
	border      = Theme.BorderColor,
	panel       = Theme.PanelColor,
	PanelBorder = Theme.PanelBorder,
	shadow      = Theme.ShadowColor,
	highlight   = Theme.HighlightColor or {1, 1, 1, 0.08},
	progress    = Theme.ProgressColor,
	AccentText  = Theme.AccentTextColor,
	MutedText   = Theme.MutedTextColor,
	warning     = Theme.WarningColor,
}

-- Utility: set font
function UI.SetFont(font)
	love.graphics.setFont(UI.fonts[font or "body"])
end

-- Utility: draw rounded rectangle
function UI.DrawRoundedRect(x, y, w, h, r, segments)
	local radius = r or UI.spacing.ButtonRadius
	radius = math.min(radius, w / 2, h / 2)
	love.graphics.rectangle("fill", x, y, w, h, radius, radius, segments)
end

function UI.DrawPanel(x, y, w, h, opts)
	opts = opts or {}
	local radius = opts.radius or UI.spacing.PanelRadius
	local ShadowOffset = opts.shadowOffset
	if ShadowOffset == nil then ShadowOffset = UI.spacing.ShadowOffset end

	if ShadowOffset and ShadowOffset ~= 0 then
		SetColor(opts.shadowColor or UI.colors.shadow, opts.shadowAlpha or 1)
		love.graphics.rectangle("fill", x + ShadowOffset, y + ShadowOffset, w, h, radius, radius)
	end

	local AlphaMultiplier = opts.alpha or 1
	local FillColor = opts.fill or UI.colors.panel or UI.colors.button
	SetColor(FillColor, AlphaMultiplier)
	love.graphics.rectangle("fill", x, y, w, h, radius, radius)

	if opts.highlight ~= false then
		local HighlightAlpha = opts.highlightAlpha
		if HighlightAlpha == nil then
			HighlightAlpha = 0.12
		end
		HighlightAlpha = HighlightAlpha * AlphaMultiplier
		if HighlightAlpha > 0 then
			local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
			love.graphics.setBlendMode("add", "alphamultiply")
			local HighlightColor = opts.highlightColor or {1, 1, 1, 1}
			local hr = HighlightColor[1] or 1
			local hg = HighlightColor[2] or 1
			local hb = HighlightColor[3] or 1
			local ha = (HighlightColor[4] or 1) * HighlightAlpha
			love.graphics.setColor(hr, hg, hb, ha)
			love.graphics.rectangle("fill", x, y, w, h, radius, radius)
			love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
		end
	end

	if opts.border ~= false then
		local BorderColor = opts.borderColor or UI.colors.border or UI.colors.PanelBorder
		SetColor(BorderColor, AlphaMultiplier)
		love.graphics.setLineWidth(opts.borderWidth or 2)
		love.graphics.rectangle("line", x, y, w, h, radius, radius)
		love.graphics.setLineWidth(1)
	end

	if opts.focused then
		local FocusRadius = radius + (opts.focusRadiusOffset or 4)
		local FocusPadding = opts.focusPadding or 3
		local FocusColor = opts.focusColor or UI.colors.border or UI.colors.highlight
		SetColor(FocusColor, opts.focusAlpha or 1.1)
		love.graphics.setLineWidth(opts.focusWidth or 3)
		love.graphics.rectangle("line", x - FocusPadding, y - FocusPadding, w + FocusPadding * 2, h + FocusPadding * 2, FocusRadius, FocusRadius)
		love.graphics.setLineWidth(1)
	end
end

function UI.DrawLabel(text, x, y, width, align, opts)
	opts = opts or {}
	local font = opts.font or UI.fonts[opts.fontKey or "body"]
	if font then
		love.graphics.setFont(font)
	end

	local color = opts.color or UI.colors.text
	SetColor(color, opts.alpha or 1)

	if width then
		love.graphics.printf(text, x, y, width, align or "left")
	else
		love.graphics.print(text, x, y)
	end
end

function UI.DrawSlider(id, x, y, w, value, opts)
	opts = opts or {}
	local h = opts.height or UI.spacing.SliderHeight
	local radius = opts.radius or UI.spacing.ButtonRadius
	local padding = opts.padding or UI.spacing.SliderPadding
	local TrackHeight = opts.trackHeight or UI.spacing.SliderTrackHeight
	local HandleRadius = opts.handleRadius or UI.spacing.SliderHandleRadius
	local focused = opts.focused

	if opts.register ~= false and id then
		UI.RegisterButton(id, x, y, w, h, opts.label)
	end

	local hovered = opts.hovered
	local BaseFill = opts.fill or UI.colors.button
	if hovered and not focused then
		BaseFill = opts.hoverFill or UI.colors.ButtonHover
	end

	UI.DrawPanel(x, y, w, h, {
		radius = radius,
		ShadowOffset = opts.shadowOffset,
		fill = BaseFill,
		BorderColor = opts.borderColor or UI.colors.border,
		focused = focused,
		FocusColor = opts.focusColor or UI.colors.highlight,
		FocusAlpha = opts.focusAlpha,
	})

	local label = opts.label
	if label then
		UI.DrawLabel(label, x + padding, y + padding, w - padding * 2, opts.labelAlign or "left", {
			FontKey = opts.labelFont or "body",
			color = opts.labelColor or UI.colors.text,
		})
	end

	local SliderValue = clamp01(value or 0)
	local TrackX = x + padding
	local TrackW = w - padding * 2
	local TrackY = y + h - padding - TrackHeight

	SetColor(UI.colors.panel, 0.7)
	love.graphics.rectangle("fill", TrackX, TrackY, TrackW, TrackHeight, TrackHeight / 2, TrackHeight / 2)

	if SliderValue > 0 then
		SetColor(opts.progressColor or UI.colors.progress)
		love.graphics.rectangle("fill", TrackX, TrackY, TrackW * SliderValue, TrackHeight, TrackHeight / 2, TrackHeight / 2)
	end

	local HandleX = TrackX + TrackW * SliderValue
	local HandleY = TrackY + TrackHeight / 2
	SetColor(opts.handleColor or UI.colors.text)
	love.graphics.circle("fill", HandleX, HandleY, HandleRadius)

	if opts.showValue ~= false then
		local ValueFont = UI.fonts[opts.valueFont or "small"]
		if ValueFont then
			love.graphics.setFont(ValueFont)
		end
		SetColor(opts.valueColor or UI.colors.SubtleText)
		local PercentText = opts.valueText or string.format("%d%%", math.floor(SliderValue * 100 + 0.5))
		love.graphics.printf(PercentText, TrackX, TrackY - (ValueFont and ValueFont:getHeight() or 14) - 6, TrackW, "right")
	end

	love.graphics.setLineWidth(1)

	return TrackX, TrackY, TrackW, TrackHeight, HandleRadius
end

-- Easing
local function EaseOutQuad(t)
	return t * (2 - t)
end

-- Register a button (once per frame in your draw code)
function UI.RegisterButton(id, x, y, w, h, text)
	UI.buttons[id] = UI.buttons[id] or CreateButtonState()
	local btn = UI.buttons[id]
	btn.bounds = {x = x, y = y, w = w, h = h}
	btn.text = text
end

-- Draw button (render only)
function UI.DrawButton(id)
	local btn = UI.buttons[id]
	if not btn or not btn.bounds then return end

	local b = btn.bounds
	local s = UI.spacing

	local mx, my = love.mouse.getPosition()
	local HoveredByMouse = UI.IsHovered(b.x, b.y, b.w, b.h, mx, my)
	local DisplayHover = HoveredByMouse or btn.focused

	if DisplayHover and not btn.wasHovered then
		Audio:PlaySound("hover")
	end
	btn.wasHovered = DisplayHover
	btn.hoverTarget = DisplayHover and 1 or 0

	-- Animate press depth
	local PressAnim = btn.anim or 0
	local YOffset = EaseOutQuad(PressAnim) * 4

	local BaseScale = 1 + (btn.popProgress or 0) * 0.08
	local HoverScale = 1 + (btn.hoverAnim or 0) * 0.02
	local FocusScale = 1 + (btn.focusAnim or 0) * 0.015
	local TotalScale = BaseScale * HoverScale * FocusScale

	local CenterX = b.x + b.w / 2
	local CenterY = b.y + YOffset + b.h / 2

	love.graphics.push()
	love.graphics.translate(CenterX, CenterY)
	love.graphics.scale(TotalScale, TotalScale)
	love.graphics.translate(-CenterX, -CenterY)

	local radius = s.buttonRadius
	local ShadowOffset = s.shadowOffset

	if ShadowOffset and ShadowOffset ~= 0 then
		SetColor(UI.colors.shadow)
		love.graphics.rectangle("fill", b.x + ShadowOffset, b.y + ShadowOffset + YOffset, b.w, b.h, radius, radius)
	end

	local FillColor = UI.colors.button
	local IsToggled = btn.toggled
	if DisplayHover then
		FillColor = UI.colors.ButtonHover
	end
	if btn.pressed or IsToggled then
		FillColor = UI.colors.ButtonPress
	end

	SetColor(FillColor)
	love.graphics.rectangle("fill", b.x, b.y + YOffset, b.w, b.h, radius, radius)

	local HighlightStrength = (btn.hoverAnim or 0) * 0.18 + (btn.popProgress or 0) * 0.22
	if HighlightStrength > 0.001 then
		local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 0.12 + 0.18 * HighlightStrength)
		love.graphics.rectangle("fill", b.x, b.y + YOffset, b.w, b.h, radius, radius)
		love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
	end

	if UI.colors.border then
		SetColor(UI.colors.border)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", b.x, b.y + YOffset, b.w, b.h, radius, radius)
	end

	if btn.focused then
		local FocusStrength = btn.focusAnim or 0
		if FocusStrength > 0.01 then
			local FocusRadius = radius + 4
			local padding = 3
			local FocusColor = UI.colors.border or UI.colors.highlight
			SetColor(FocusColor, 0.8 + 0.4 * FocusStrength)
			love.graphics.setLineWidth(3)
			love.graphics.rectangle("line", b.x - padding, b.y + YOffset - padding, b.w + padding * 2, b.h + padding * 2, FocusRadius, FocusRadius)
		end
	end

	local GlowStrength = btn.glow or 0
	if GlowStrength > 0.01 then
		local PrevMode, PrevAlphaMode = love.graphics.getBlendMode()
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 0.16 * GlowStrength)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", b.x + 2, b.y + YOffset + 2, b.w - 4, b.h - 4, radius - 2, radius - 2)
		love.graphics.setBlendMode(PrevMode, PrevAlphaMode)
	end

	love.graphics.setLineWidth(1)

	-- TEXT
	UI.SetFont("button")
	local TextColor = UI.colors.text
	if DisplayHover or (btn.focusAnim or 0) > 0.001 or IsToggled then
		TextColor = LightenColor(TextColor, 0.18 + 0.1 * (btn.focusAnim or 0))
	end
	SetColor(TextColor)
	local TextY = b.y + YOffset + (b.h - UI.fonts.button:GetHeight()) / 2
	love.graphics.printf(btn.text or "", b.x, TextY, b.w, "center")

	love.graphics.pop()
end

-- Hover check
function UI.IsHovered(x, y, w, h, px, py)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Mouse press
function UI:mousepressed(x, y, button)
	if button == 1 then
		for id, btn in pairs(UI.buttons) do
			local b = btn.bounds
			if b and UI.IsHovered(b.x, b.y, b.w, b.h, x, y) then
				btn.pressed = true
				Audio:PlaySound("click")
				return id
			end
		end
	end
end

-- Mouse release
function UI:mousereleased(x, y, button)
	if button == 1 then
		for id, btn in pairs(UI.buttons) do
			if btn.pressed then
				btn.pressed = false
				local b = btn.bounds
				if b and UI.IsHovered(b.x, b.y, b.w, b.h, x, y) then
					btn.popTimer = 0
					btn.popProgress = 0
					return id -- valid click
				end
			end
		end
	end
end

-- Score pulse logic
function UI:reset()
	ScorePulse = 1.0
	PulseTimer = 0
	self.combo.count = 0
	self.combo.timer = 0
	self.combo.duration = 0
	self.combo.pop = 0
	self.shields.count = 0
	self.shields.display = 0
	self.shields.PopTimer = 0
	self.shields.ShakeTimer = 0
	self.shields.FlashTimer = 0
	self.shields.LastDirection = 0
end

function UI:TriggerScorePulse()
	ScorePulse = 1.2
	PulseTimer = 0
end

function UI:SetFruitGoal(required)
	self.FruitRequired = required
	self.FruitCollected = 0
		self.FruitSockets = {} -- clear collected fruit sockets each floor
end

function UI:AdjustFruitGoal(delta)
	if not delta or delta == 0 then return end

	local NewGoal = math.max(1, (self.FruitRequired or 0) + delta)
	self.FruitRequired = NewGoal

	if (self.FruitCollected or 0) > NewGoal then
		self.FruitCollected = NewGoal
	end

	if type(self.FruitSockets) == "table" then
		while #self.FruitSockets > NewGoal do
			table.remove(self.FruitSockets)
		end
	end
end


function UI:IsGoalReached()
	if self.FruitCollected >= self.FruitRequired then
		if not self.GoalCelebrated then
			self:CelebrateGoal()
		end
		return true
	end
end

function UI:AddFruit(FruitType)
	self.FruitCollected = math.min(self.FruitCollected + 1, self.FruitRequired)
	local fruit = FruitType or { name = "Apple", color = { 1, 0, 0 } }
	table.insert(self.FruitSockets, {
		type = fruit,
		anim = 0,
		state = "appearing",
		WobblePhase = love.math.random() * math.pi * 2,
		BounceTimer = 0,
		RemoveTimer = 0,
		CelebrationGlow = nil,
		CelebrationDelay = nil,
		PendingCelebration = nil,
	})
end

function UI:RemoveFruit(count)
	count = math.floor(count or 0)
	if count <= 0 then
		return 0
	end

	local removed = 0
	local RemovalStagger = 0
	self.FruitCollected = math.max(0, self.FruitCollected or 0)

	for _ = 1, count do
		if (self.FruitCollected or 0) <= 0 then
			break
		end

		self.FruitCollected = self.FruitCollected - 1
		removed = removed + 1

		if type(self.FruitSockets) == "table" and #self.FruitSockets > 0 then
			local marked = false
			for i = #self.FruitSockets, 1, -1 do
				local socket = self.FruitSockets[i]
				if socket and socket.state ~= "removing" then
					socket.state = "removing"
					socket.removeTimer = 0
					socket.removeDelay = RemovalStagger
					socket.anim = math.min(socket.anim or self.SocketAnimTime, self.SocketAnimTime)
					socket.bounceTimer = nil
					socket.celebrationGlow = nil
					socket.celebrationDelay = nil
					socket.pendingCelebration = nil
					socket.wobblePhase = socket.wobblePhase or love.math.random() * math.pi * 2
					marked = true
					RemovalStagger = RemovalStagger + 0.05
					break
				end
			end

			if not marked then
				local last = self.FruitSockets[#self.FruitSockets]
				if last then
					last.state = "removing"
					last.removeTimer = 0
					last.removeDelay = RemovalStagger
					last.anim = math.min(last.anim or self.SocketAnimTime, self.SocketAnimTime)
					last.bounceTimer = nil
					last.celebrationGlow = nil
					last.celebrationDelay = nil
					last.pendingCelebration = nil
					last.wobblePhase = last.wobblePhase or love.math.random() * math.pi * 2
					RemovalStagger = RemovalStagger + 0.05
				end
			end
		end
	end

	if (self.FruitCollected or 0) < (self.FruitRequired or 0) then
		self.GoalCelebrated = false
		self.GoalReachedAnim = 0
	end

	return removed
end

function UI:CelebrateGoal()
	self.GoalReachedAnim = 0
	self.GoalCelebrated = true
	Audio:PlaySound("goal_reached")
	for index, socket in ipairs(self.FruitSockets) do
		if socket.state ~= "removing" then
			socket.bounceTimer = nil
			socket.pendingCelebration = true
			socket.celebrationDelay = (index - 1) * 0.05
			socket.celebrationGlow = nil
		end
	end
end

function UI:update(dt)
	--[[ Update score pulse
	PulseTimer = PulseTimer + dt
	if PulseTimer > PULSE_DURATION then
		ScorePulse = 1.0
	else
		local progress = PulseTimer / PULSE_DURATION
		ScorePulse = 1.2 - 0.2 * progress
	end]]

	-- Update button animations
	for _, button in pairs(UI.buttons) do
		local HoverTarget = button.hoverTarget or 0
		local FocusTarget = button.focused and 1 or 0
		button.anim = ApproachExp(button.anim or 0, button.pressed and 1 or 0, dt, 18)
		if HoverTarget > 0 then
			button.hoverAnim = ApproachExp(button.hoverAnim or 0, HoverTarget, dt, 12)
		else
			button.hoverAnim = 0
		end
		button.focusAnim = ApproachExp(button.focusAnim or 0, FocusTarget, dt, 9)
		local GlowTarget = math.max(HoverTarget, FocusTarget)
		button.glow = ApproachExp(button.glow or 0, GlowTarget, dt, 5)

		if button.popTimer ~= nil then
			button.popTimer = button.popTimer + dt
			local progress = math.min(1, button.popTimer / BUTTON_POP_DURATION)
			button.popProgress = math.sin(progress * math.pi) * (1 - progress * 0.45)
			if progress >= 1 then
				button.popTimer = nil
			end
		else
			button.popProgress = ApproachExp(button.popProgress or 0, 0, dt, 10)
		end

		button.hoverTarget = 0
	end

	-- update fruit socket animations
	for i = #self.FruitSockets, 1, -1 do
		local socket = self.FruitSockets[i]
		local RemoveSocket = false

		socket.anim = socket.anim or 0
		socket.removeTimer = socket.removeTimer or 0

		if socket.state == "removing" then
			socket.removeTimer = socket.removeTimer + dt
			local delay = socket.removeDelay or 0
			if socket.removeTimer >= delay then
				local RemovalDuration = self.SocketRemoveTime > 0 and self.SocketRemoveTime or self.SocketAnimTime
				local RemovalSpeed = self.SocketAnimTime / (RemovalDuration > 0 and RemovalDuration or 1)
				socket.anim = math.max(0, socket.anim - dt * RemovalSpeed)
				if socket.anim <= 0.001 then
					RemoveSocket = true
				end
			end
		else
			if socket.anim < self.SocketAnimTime then
				socket.anim = math.min(socket.anim + dt, self.SocketAnimTime)
			elseif socket.state == "appearing" then
				socket.state = "idle"
			end
		end

		if socket.pendingCelebration and socket.state ~= "removing" then
			if not self.GoalCelebrated then
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
			if socket.bounceTimer >= self.SocketBounceDuration then
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
			socket.wobblePhase = love.math.random() * math.pi * 2
		end
		local WobbleSpeed = socket.state == "removing" and 5.0 or 6.2
		socket.wobblePhase = socket.wobblePhase + dt * WobbleSpeed

		if RemoveSocket then
			table.remove(self.FruitSockets, i)
		end
	end

	if self.GoalCelebrated then
		self.GoalReachedAnim = self.GoalReachedAnim + dt
		if self.GoalReachedAnim > 1 then
			self.GoalCelebrated = false
		end
	end

	if self.combo.pop > 0 then
		self.combo.pop = math.max(0, self.combo.pop - dt * 3)
	end

	local shields = self.shields
	if shields then
		if shields.display == nil then
			shields.display = shields.count or 0
		end

		local target = shields.count or 0
		local current = shields.display or 0
		local diff = target - current
		if math.abs(diff) > 0.01 then
			local step = diff * math.min(dt * 10, 1)
			shields.display = current + step
		else
			shields.display = target
		end

		if shields.popTimer and shields.popTimer > 0 then
			shields.popTimer = math.max(0, shields.popTimer - dt)
		end

		if shields.shakeTimer and shields.shakeTimer > 0 then
			shields.shakeTimer = math.max(0, shields.shakeTimer - dt)
		end

		if shields.flashTimer and shields.flashTimer > 0 then
			shields.flashTimer = math.max(0, shields.flashTimer - dt)
		end
	end

	local container = self.UpgradeIndicators
	if container and container.items then
		local smoothing = math.min(dt * 8, 1)
		local ToRemove = {}
		for id, item in pairs(container.items) do
			item.visibility = item.visibility or 0
			local TargetVis = item.targetVisibility or 0
			item.visibility = lerp(item.visibility, TargetVis, smoothing)

			if item.targetProgress ~= nil then
				item.displayProgress = item.displayProgress or item.targetProgress or 0
				item.displayProgress = lerp(item.displayProgress, item.targetProgress, smoothing)
			else
				item.displayProgress = nil
			end

			if item.visibility <= 0.01 and TargetVis <= 0 then
				table.insert(ToRemove, id)
			end
		end

		for _, id in ipairs(ToRemove) do
			container.items[id] = nil
		end
	end

end

function UI:SetCombo(count, timer, duration)
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


function UI:SetCrashShields(count, opts)
	local shields = self.shields
	if not shields then return end

	count = math.max(0, math.floor((count or 0) + 0.0001))

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
			Audio:PlaySound("shield_gain")
		end
	else
		shields.lastDirection = -1
		shields.shakeTimer = shields.shakeDuration
		shields.flashTimer = shields.flashDuration
		shields.popTimer = 0
		if not silent then
			Audio:PlaySound("shield_break")
		end
	end
end

function UI:SetUpgradeIndicators(indicators)
	local container = self.UpgradeIndicators
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
					TargetVisibility = 1,
					DisplayProgress = data.charge ~= nil and clamp01(data.charge) or nil,
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

local function DrawComboIndicator(self)
	local combo = self.combo
	local ComboActive = combo and combo.count >= 2 and (combo.duration or 0) > 0

	if not ComboActive then
		return
	end

	local duration = combo.duration or 0
	local timer = 0
	local progress = 0
	timer = math.max(0, math.min(combo.timer or 0, duration))
	progress = duration > 0 and timer / duration or 0

	local ScreenW = love.graphics.getWidth()
	local TitleText = "Combo"
	TitleText = "Combo x" .. combo.count

	local width = math.max(240, UI.fonts.button:GetWidth(TitleText) + 120)
	local height = 68
	local x = (ScreenW - width) / 2
	local y = 16

	local scale = 1 + 0.08 * math.sin((1 - progress) * math.pi * 2) + (combo.pop or 0) * 0.25

	love.graphics.push()
	love.graphics.translate(x + width / 2, y + height / 2)
	love.graphics.scale(scale, scale)
	love.graphics.translate(-(x + width / 2), -(y + height / 2))

	love.graphics.setColor(0, 0, 0, 0.4)
	love.graphics.rectangle("fill", x + 4, y + 6, width, height, 18, 18)

	love.graphics.setColor(Theme.PanelColor[1], Theme.PanelColor[2], Theme.PanelColor[3], 0.95)
	love.graphics.rectangle("fill", x, y, width, height, 18, 18)

	love.graphics.setColor(Theme.PanelBorder)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", x, y, width, height, 18, 18)

	UI.SetFont("button")
	love.graphics.setColor(Theme.TextColor)
	love.graphics.printf(TitleText, x, y + 8, width, "center")

	local BarPadding = 18
	local BarHeight = 10
	local BarWidth = width - BarPadding * 2
	local ComboBarY = y + height - BarPadding - BarHeight

	if ComboActive then
		love.graphics.setColor(0, 0, 0, 0.25)
		love.graphics.rectangle("fill", x + BarPadding, ComboBarY, BarWidth, BarHeight, 6, 6)

		love.graphics.setColor(1, 0.78, 0.3, 0.85)
		love.graphics.rectangle("fill", x + BarPadding, ComboBarY, BarWidth * progress, BarHeight, 6, 6)
	end

	love.graphics.pop()
end

local function BuildShieldPoints(radius)
	return {
		0, -radius,
		radius * 0.78, -radius * 0.28,
		radius * 0.55, radius * 0.85,
		0, radius,
		-radius * 0.55, radius * 0.85,
		-radius * 0.78, -radius * 0.28,
	}
end

local function DrawIndicatorIcon(icon, AccentColor, x, y, radius, overlay)
	local accent = AccentColor or {1, 1, 1, 1}

	love.graphics.push("all")
	love.graphics.translate(x, y)

	love.graphics.setColor(0, 0, 0, 0.3)
	love.graphics.circle("fill", 3, 4, radius + 3, 28)

	local base = DarkenColor(accent, 0.6)
	love.graphics.setColor(base[1], base[2], base[3], base[4] or 1)
	love.graphics.circle("fill", 0, 0, radius, 28)

	local detail = LightenColor(accent, 0.12)
	love.graphics.setColor(detail[1], detail[2], detail[3], detail[4] or 1)

	if icon == "shield" then
		local shield = BuildShieldPoints(radius * 0.9)
		love.graphics.polygon("fill", shield)
		local outline = LightenColor(accent, 0.35)
		love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
		love.graphics.setLineWidth(2)
		love.graphics.polygon("line", shield)
	elseif icon == "bolt" then
		local bolt = {
			-radius * 0.28, -radius * 0.92,
			radius * 0.42, -radius * 0.2,
			radius * 0.08, -radius * 0.18,
			radius * 0.48, radius * 0.82,
			-radius * 0.2, radius * 0.14,
			radius * 0.05, 0,
		}
		love.graphics.polygon("fill", bolt)
	elseif icon == "pickaxe" then
		love.graphics.push()
		love.graphics.rotate(-math.pi / 8)
		love.graphics.rectangle("fill", -radius * 0.14, -radius * 0.92, radius * 0.28, radius * 1.84, radius * 0.16)
		love.graphics.pop()
		local outline = LightenColor(accent, 0.35)
		love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", 0, 0, radius * 0.95, 28)
	elseif icon == "hourglass" then
		local bowl = {
			radius * 0.68, -radius * 0.78,
			0, -radius * 0.16,
			-radius * 0.68, -radius * 0.78,
			-radius * 0.68, radius * 0.78,
			0, radius * 0.16,
			radius * 0.68, radius * 0.78,
		}
		love.graphics.polygon("fill", bowl)
		love.graphics.setColor(base[1], base[2], base[3], (base[4] or 1) * 0.6)
		love.graphics.ellipse("fill", 0, -radius * 0.36, radius * 0.4, radius * 0.2, 28)
		love.graphics.ellipse("fill", 0, radius * 0.36, radius * 0.4, radius * 0.2, 28)
		love.graphics.setColor(detail[1], detail[2], detail[3], detail[4] or 1)
		love.graphics.setLineWidth(2)
		love.graphics.polygon("line", bowl)
	elseif icon == "phoenix" then
		local wing = {
			-radius * 0.88, radius * 0.16,
			-radius * 0.26, -radius * 0.7,
			0, -radius * 0.25,
			radius * 0.26, -radius * 0.7,
			radius * 0.88, radius * 0.16,
			0, radius * 0.88,
		}
		love.graphics.polygon("fill", wing)
	else
		love.graphics.circle("fill", 0, 0, radius * 0.72, 28)
	end

	if overlay and overlay.text then
		local background = overlay.backgroundColor or {0, 0, 0, 0.78}
		local BorderColor = overlay.borderColor or LightenColor(accent, 0.35)
		local FontKey = overlay.font or "small"
		local PaddingX = overlay.paddingX or 6
		local PaddingY = overlay.paddingY or 2
		local PreviousFont = love.graphics.getFont()
		UI.SetFont(FontKey)
		local font = love.graphics.getFont()
		local text = tostring(overlay.text)
		local TextWidth = font:getWidth(text)
		local BoxWidth = TextWidth + PaddingX * 2
		local BoxHeight = font:getHeight() + PaddingY * 2
		local position = overlay.position or "BottomRight"
		local AnchorX, AnchorY

		if position == "TopLeft" then
			AnchorX = -radius * 0.75
			AnchorY = -radius * 0.75
		elseif position == "TopRight" then
			AnchorX = radius * 0.75
			AnchorY = -radius * 0.75
		elseif position == "BottomLeft" then
			AnchorX = -radius * 0.75
			AnchorY = radius * 0.75
		elseif position == "center" then
			AnchorX = 0
			AnchorY = 0
		else
			AnchorX = radius * 0.75
			AnchorY = radius * 0.75
		end

		AnchorX = AnchorX + (overlay.offsetX or 0)
		AnchorY = AnchorY + (overlay.offsetY or 0)

		local BoxX = AnchorX - BoxWidth * 0.5
		local BoxY = AnchorY - BoxHeight * 0.5
		local CornerRadius = overlay.cornerRadius or math.min(10, BoxHeight * 0.5)

		love.graphics.setColor(background[1], background[2], background[3], background[4] or 1)
		love.graphics.rectangle("fill", BoxX, BoxY, BoxWidth, BoxHeight, CornerRadius, CornerRadius)

		love.graphics.setColor(BorderColor[1], BorderColor[2], BorderColor[3], (BorderColor[4] or 1))
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", BoxX, BoxY, BoxWidth, BoxHeight, CornerRadius, CornerRadius)

		local TextColor = overlay.textColor or {1, 1, 1, 1}
		love.graphics.setColor(TextColor[1], TextColor[2], TextColor[3], TextColor[4] or 1)
		local TextY = BoxY + (BoxHeight - font:getHeight()) * 0.5
		love.graphics.printf(text, BoxX, TextY, BoxWidth, "center")
		if PreviousFont then
			love.graphics.setFont(PreviousFont)
		end
	end

	love.graphics.pop()
end

local function BuildShieldIndicator(self)
	local shields = self.shields
	if not shields then return nil end

	local RawCount = shields.count
	if RawCount == nil then
		RawCount = shields.display
	end

	local count = math.max(0, math.floor((RawCount or 0) + 0.5))

	if count <= 0 then
		return nil
	end

	local label = Localization:get("upgrades.hud.shields")

	local accent = {0.55, 0.82, 1.0, 1.0}
	local StatusKey = "ready"

	if (shields.lastDirection or 0) < 0 and (shields.flashTimer or 0) > 0 then
		accent = {1.0, 0.55, 0.45, 1.0}
		StatusKey = "depleted"
	end

	local OverlayBackground = LightenColor(accent, 0.1)
	OverlayBackground[4] = 0.92

	return {
		id = "__shields",
		label = label,
		StackCount = count,
		icon = "shield",
		AccentColor = accent,
		IconOverlay = {
			text = count,
			position = "center",
			font = "badge",
			PaddingX = 8,
			PaddingY = 4,
			BackgroundColor = OverlayBackground,
			TextColor = Theme.TextColor,
		},
		status = Localization:get("upgrades.hud." .. StatusKey),
		ShowBar = false,
		visibility = 1,
	}
end

function UI:DrawUpgradeIndicators()
	local container = self.UpgradeIndicators
	if not container or not container.items then return end

	local OrderedIds = {}
	local seen = {}
	if container.order then
		for _, id in ipairs(container.order) do
			if container.items[id] and not seen[id] then
				table.insert(OrderedIds, id)
				seen[id] = true
			end
		end
	end

	for id in pairs(container.items) do
		if not seen[id] then
			table.insert(OrderedIds, id)
			seen[id] = true
		end
	end

	local entries = {}
	for _, id in ipairs(OrderedIds) do
		local item = container.items[id]
		if item and clamp01(item.visibility or 0) > 0.01 then
			table.insert(entries, item)
		end
	end

	local ShieldEntry = BuildShieldIndicator(self)
	if ShieldEntry then
		table.insert(entries, 1, ShieldEntry)
	end

	if #entries == 0 then
		return
	end

	local layout = container.layout or {}
	local width = layout.width or 252
	local spacing = layout.spacing or 12
	local BaseHeight = layout.baseHeight or 64
	local BarHeight = layout.barHeight or 10
	local IconRadius = layout.iconRadius or 18
	local margin = layout.margin or 24

	local ScreenW = love.graphics.getWidth()
	local x = ScreenW - width - margin
	local y = margin

	for _, entry in ipairs(entries) do
		local visibility = clamp01(entry.visibility or 1)
		local accent = entry.accentColor or Theme.PanelBorder or {1, 1, 1, 1}
		local HasBar = entry.showBar and entry.displayProgress ~= nil
		local PanelHeight = BaseHeight + (HasBar and 8 or 0)

		local DrawY = y

		love.graphics.push("all")

		love.graphics.setColor(0, 0, 0, 0.4 * visibility)
		love.graphics.rectangle("fill", x + 4, DrawY + 6, width, PanelHeight, 14, 14)

		local PanelColor = Theme.PanelColor or {0.16, 0.18, 0.22, 1}
		love.graphics.setColor(PanelColor[1], PanelColor[2], PanelColor[3], (PanelColor[4] or 1) * (0.95 * visibility))
		love.graphics.rectangle("fill", x, DrawY, width, PanelHeight, 14, 14)

		local border = LightenColor(accent, 0.15)
		love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * visibility)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x, DrawY, width, PanelHeight, 14, 14)

		local IconX = x + IconRadius + 14
		local IconY = DrawY + IconRadius + 12
		DrawIndicatorIcon(entry.icon or "circle", accent, IconX, IconY, IconRadius, entry.iconOverlay)

		local TextX = IconX + IconRadius + 12
		local TextWidth = math.max(60, width - (TextX - x) - 14)

		local ShowLabel = false

		if entry.status then
			UI.SetFont("small")
			love.graphics.setColor(Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], 0.75 * visibility)
			local StatusY = ShowLabel and (DrawY + 38) or (DrawY + 20)
			love.graphics.printf(entry.status, TextX, StatusY, TextWidth, "left")
		end

		if HasBar then
			local progress = clamp01(entry.displayProgress or 0)
			local IconBarWidth = layout.iconBarWidth or (IconRadius * 1.8)
			local IconBarHeight = layout.iconBarHeight or math.max(4, math.floor(BarHeight))
			local BarX = IconX - IconBarWidth * 0.5
			local DesiredBarY = IconY + IconRadius + 6
			local MaxBarY = DrawY + PanelHeight - IconBarHeight - 6
			local BarY = math.min(DesiredBarY, MaxBarY)

			love.graphics.setColor(0, 0, 0, 0.28 * visibility)
			love.graphics.rectangle("fill", BarX, BarY, IconBarWidth, IconBarHeight, IconBarHeight * 0.5, IconBarHeight * 0.5)

			local fill = LightenColor(accent, 0.05)
			love.graphics.setColor(fill[1], fill[2], fill[3], (fill[4] or 1) * 0.85 * visibility)
			love.graphics.rectangle("fill", BarX, BarY, IconBarWidth * progress, IconBarHeight, IconBarHeight * 0.5, IconBarHeight * 0.5)

			local outline = LightenColor(accent, 0.3)
			love.graphics.setColor(outline[1], outline[2], outline[3], (outline[4] or 1) * 0.9 * visibility)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", BarX, BarY, IconBarWidth, IconBarHeight, IconBarHeight * 0.5, IconBarHeight * 0.5)

			if entry.chargeLabel then
				UI.SetFont("small")
				love.graphics.setColor(Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], 0.8 * visibility)
				local LabelY = BarY + IconBarHeight + 4
				love.graphics.printf(entry.chargeLabel, BarX, LabelY, IconBarWidth, "center")
			end
		elseif entry.chargeLabel then
			UI.SetFont("small")
			love.graphics.setColor(Theme.TextColor[1], Theme.TextColor[2], Theme.TextColor[3], 0.8 * visibility)
			love.graphics.printf(entry.chargeLabel, TextX, DrawY + PanelHeight - 24, TextWidth, "right")
		end

		love.graphics.pop()

		y = y + PanelHeight + spacing
	end
end


function UI:DrawFruitSockets()
	if self.FruitRequired <= 0 then
		self.FruitPanelBounds = nil
		return
	end

	-- Position the fruit sockets near the top-left corner.
	local HeaderHeight = 0
	local PaddingOffsetY = 8
	local BaseX, BaseY = 20, 20
	local PerRow = 10
	local spacing = self.SocketSize + 6
	local rows = math.max(1, math.ceil(self.FruitRequired / PerRow))
	local cols = math.min(self.FruitRequired, PerRow)
	if cols == 0 then cols = 1 end

	local GridWidth = (cols - 1) * spacing + self.SocketSize
	local GridHeight = (rows - 1) * spacing + self.SocketSize
	local PaddingX = self.SocketSize * 0.75
	local PaddingY = self.SocketSize * 0.75 + PaddingOffsetY

	local PanelX = 20
	local PanelY = 20

	local PanelW = GridWidth + PaddingX * 2
	local PanelH = HeaderHeight + GridHeight + PaddingY * 2

	local InnerWidth = PanelW - PaddingX * 2
	local InnerHeight = PanelH - PaddingY * 2 - HeaderHeight
	local BaseOffsetX = math.max(0, (InnerWidth - GridWidth) * 0.5)
	local BaseOffsetY = math.max(0, (InnerHeight - GridHeight) * 0.5)
	BaseX = PanelX + PaddingX + BaseOffsetX
	BaseY = PanelY + PaddingY + HeaderHeight + BaseOffsetY

	local GoalFlash = 0
	if self.GoalCelebrated then
		local FlashT = clamp01(self.GoalReachedAnim / 0.7)
		GoalFlash = math.pow(1 - FlashT, 1.4)
	end

	-- backdrop styled like the HUD panel card
	local ShadowOffset = (UI.spacing and UI.spacing.ShadowOffset) or 6
	if ShadowOffset ~= 0 then
		local ShadowColor = Theme.ShadowColor or {0, 0, 0, 0.5}
		local ShadowAlpha = ShadowColor[4] or 1
		love.graphics.setColor(ShadowColor[1], ShadowColor[2], ShadowColor[3], ShadowAlpha)
		love.graphics.rectangle("fill", PanelX + ShadowOffset, PanelY + ShadowOffset, PanelW, PanelH, 12, 12)
	end

	local PanelColor = Theme.PanelColor
	if GoalFlash > 0 then
		PanelColor = LightenColor(PanelColor, 0.25 * GoalFlash)
	end

	love.graphics.setColor(PanelColor[1], PanelColor[2], PanelColor[3], (PanelColor[4] or 1))
	love.graphics.rectangle("fill", PanelX, PanelY, PanelW, PanelH, 12, 12)

	local BorderColor = Theme.PanelBorder or {0, 0, 0, 1}
	if GoalFlash > 0 then
		BorderColor = LightenColor(BorderColor, 0.4 * GoalFlash)
	end
	love.graphics.setColor(BorderColor[1], BorderColor[2], BorderColor[3], (BorderColor[4] or 1))
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", PanelX, PanelY, PanelW, PanelH, 12, 12)

	local time = love.timer.getTime()
	local SocketRadius = (self.SocketSize / 2) - 2
	local SocketFill = LightenColor(Theme.PanelColor, 0.45)
	local SocketOutline = LightenColor(Theme.PanelBorder or Theme.TextColor, 0.2)

	local HighlightColor = (UI.colors and UI.colors.highlight) or Theme.HighlightColor or {1, 1, 1, 0.08}

	for i = 1, self.FruitRequired do
		local row = math.floor((i - 1) / PerRow)
		local col = (i - 1) % PerRow
		local bounce = 0
		local x = BaseX + col * spacing + self.SocketSize / 2
		local y = BaseY + row * spacing + self.SocketSize / 2 + bounce

		-- socket shadow
		local socket = self.FruitSockets[i]
		local HasFruit = socket ~= nil
		local appear = HasFruit and clamp01(socket.anim / self.SocketAnimTime) or 0
		local radius = HasFruit and SocketRadius or SocketRadius * 0.8
		local ShadowScale = HasFruit and (0.75 + 0.25 * appear) or 0.85
		local ShadowAlpha = HasFruit and (0.45 * math.max(appear, 0.2)) or 0.4
		love.graphics.setColor(0, 0, 0, ShadowAlpha)
		love.graphics.ellipse("fill", x, y + radius * 0.65, radius * 0.95 * ShadowScale, radius * 0.55 * ShadowScale, 32)

		-- empty socket base
		love.graphics.setColor(SocketFill[1], SocketFill[2], SocketFill[3], (SocketFill[4] or 1) * 0.9)
		love.graphics.circle("fill", x, y, radius, 48)

		-- subtle animated rim
		local RimPulse = 0.35 + 0.25 * math.sin(time * 3.5 + i * 0.7)
		love.graphics.setColor(SocketOutline[1], SocketOutline[2], SocketOutline[3], (SocketOutline[4] or 1) * RimPulse)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", x, y, radius, 48)

		love.graphics.setColor(1, 1, 1, 0.08 * (HasFruit and appear or 1))
		love.graphics.arc("fill", x, y, radius * 1.1, -math.pi * 0.6, -math.pi * 0.1, 24)

		-- draw fruit if collected
		if socket then
			local t = clamp01(socket.anim / self.SocketAnimTime)
			local AppearEase
			if socket.state == "removing" then
				AppearEase = 1 - Easing.EaseInBack(1 - t)
			else
				AppearEase = Easing.EaseOutBack(t)
			end
			AppearEase = math.max(0, AppearEase)

			local scale = math.min(1.18, AppearEase)
			local BounceScale = 1
			if socket.bounceTimer ~= nil then
				local BounceProgress = clamp01(socket.bounceTimer / self.SocketBounceDuration)
				BounceScale = 1 + math.sin(BounceProgress * math.pi) * 0.24 * (1 - BounceProgress * 0.4)
			end

			local CelebrationWave = 0
			if self.GoalCelebrated then
				local WaveTime = self.GoalReachedAnim or 0
				local WaveFade = math.max(0, 1 - clamp01(WaveTime / 0.9))
				CelebrationWave = math.sin(WaveTime * 12 - i * 0.35) * 0.05 * WaveFade
			end

			local GoalPulse = 1 + (socket.celebrationGlow or 0) * 0.22 + CelebrationWave
			GoalPulse = math.max(0.85, GoalPulse)

			local visibility = t
			if socket.state == "removing" then
				visibility = visibility * visibility
			else
				visibility = math.pow(visibility, 0.85)
			end

			love.graphics.push()
			love.graphics.translate(x, y)
			local WobbleRotation = 0
			if socket.wobblePhase then
				WobbleRotation = math.sin(socket.wobblePhase) * 0.08 * (1 - t)
			end
			love.graphics.rotate(WobbleRotation)
			love.graphics.scale(scale * GoalPulse * BounceScale, scale * GoalPulse * BounceScale)

			-- fruit shadow inside socket
			love.graphics.setColor(0, 0, 0, 0.3 * visibility)
			love.graphics.ellipse("fill", 0, radius * 0.55, radius * 0.8, radius * 0.45, 32)

			local r = radius
			local fruit = socket.type

			local FruitAlpha = (fruit.color[4] or 1) * visibility
			love.graphics.setColor(fruit.color[1], fruit.color[2], fruit.color[3], FruitAlpha)
			love.graphics.circle("fill", 0, 0, r, 32)

			love.graphics.setColor(0, 0, 0, math.max(0.2, visibility))
			love.graphics.setLineWidth(3)
			love.graphics.circle("line", 0, 0, r, 32)

			-- juicy highlight
			local HighlightColor = LightenColor(fruit.color, 0.6)
			local HighlightAlpha = (HighlightColor[4] or 1) * 0.75 * visibility
			love.graphics.push()
			love.graphics.translate(-r * 0.3 + 1, -r * 0.35)
			love.graphics.rotate(-0.35)
			love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], HighlightAlpha)
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
				local SparkleRadius = r + 4 + glow * 4
				love.graphics.setLineWidth(2)
				love.graphics.setColor(1, 1, 1, 0.18 * glow * visibility)
				love.graphics.circle("line", 0, 0, SparkleRadius, 28)
				love.graphics.setLineWidth(3)
				local BarWidth = 3 + glow * 2
				local BarLength = SparkleRadius * 1.1
				love.graphics.setColor(1, 1, 1, 0.12 * glow * visibility)
				love.graphics.rectangle("fill", -BarWidth * 0.5, -BarLength, BarWidth, BarLength * 2, BarWidth * 0.4, BarWidth * 0.4)
				love.graphics.rectangle("fill", -BarLength, -BarWidth * 0.5, BarLength * 2, BarWidth, BarWidth * 0.4, BarWidth * 0.4)
			end

			-- dragonfruit glow
			if fruit.name == "Dragonfruit" then
				local pulse = 0.5 + 0.5 * math.sin(time * 6.0)
				love.graphics.setColor(1, 0, 1, 0.25 * pulse * visibility)
				love.graphics.circle("line", 0, 0, r + 4 * pulse, 32)
			end

			love.graphics.pop()
		else
			-- idle shimmer in empty sockets
			local EmptyGlow = 0.12 + 0.12 * math.sin(time * 5 + i * 0.9)
			if GoalFlash > 0 then
				EmptyGlow = EmptyGlow + 0.08 * GoalFlash
			end
			love.graphics.setColor(
				HighlightColor[1],
				HighlightColor[2],
				HighlightColor[3],
				(HighlightColor[4] or 1) * EmptyGlow
			)
			love.graphics.circle("line", x, y, radius - 1.5, 32)
		end
	end

	-- draw fruit counter text anchored to the socket panel
	local collected = tostring(self.FruitCollected)
	local required  = tostring(self.FruitRequired)
	UI.SetFont("button")
	local font = love.graphics.getFont()
	local padding = 12
	local TextY = PanelY + PanelH + padding
	local ShadowColor = Theme.ShadowColor or {0, 0, 0, 0.5}
	love.graphics.setColor(ShadowColor[1], ShadowColor[2], ShadowColor[3], (ShadowColor[4] or 1))
	love.graphics.printf(
		collected .. " / " .. required,
		PanelX + 2,
		TextY + 2,
		PanelW,
		"right"
	)
	love.graphics.setColor(Theme.TextColor)
	love.graphics.printf(
		collected .. " / " .. required,
		PanelX,
		TextY,
		PanelW,
		"right"
	)

	self.FruitPanelBounds = {
		x = PanelX,
		y = PanelY,
		w = PanelW,
		h = PanelH,
	}
end

function UI:draw()
	-- draw socket grid
	self:DrawFruitSockets()
	self:DrawUpgradeIndicators()
	DrawComboIndicator(self)
end

UI.RefreshLayout(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT)

return UI
