local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Timer = require("timers")

local Popup = {}
Popup.__index = Popup

local DEFAULT_DURATION = 3
local DEFAULT_FADE = 0.5
local DEFAULT_START_SCALE = 0.8
local DEFAULT_START_OFFSET = -30
local BASE_MAX_WIDTH = 560

local function CreateInstance(config)
	config = config or {}

	local instance = {
		active = false,
		text = "",
		subtext = "",
		alpha = 0,
		scale = 1,
		OffsetY = 0,
		duration = config.duration or DEFAULT_DURATION,
		FadeInDuration = config.fadeInDuration or DEFAULT_FADE,
		FadeOutDuration = config.fadeOutDuration or DEFAULT_FADE,
		timer = Timer.new(config.duration or DEFAULT_DURATION),
		StartScale = config.startScale or DEFAULT_START_SCALE,
		StartOffsetY = config.startOffsetY or DEFAULT_START_OFFSET,
	}

	return setmetatable(instance, Popup)
end

function Popup.new(config)
	return CreateInstance(config)
end

function Popup:configure(options)
	options = options or {}
	if options.duration then
		self.duration = options.duration
	end
	if options.fadeInDuration then
		self.FadeInDuration = options.fadeInDuration
	end
	if options.fadeOutDuration then
		self.FadeOutDuration = options.fadeOutDuration
	end
	if options.startScale then
		self.StartScale = options.startScale
	end
	if options.startOffsetY then
		self.StartOffsetY = options.startOffsetY
	end
	if options.timer then
		self.timer = options.timer
	end
end

function Popup:show(title, description, options)
	options = options or {}

	if options.duration then
		self.duration = options.duration
	end
	if options.fadeInDuration then
		self.FadeInDuration = options.fadeInDuration
	end
	if options.fadeOutDuration then
		self.FadeOutDuration = options.fadeOutDuration
	end

	local StartScale = options.startScale or self.StartScale or DEFAULT_START_SCALE
	local StartOffsetY = options.startOffsetY or self.StartOffsetY or DEFAULT_START_OFFSET

	self.text = title or ""
	self.subtext = description or ""
	self.alpha = 0
	self.scale = StartScale
	self.OffsetY = StartOffsetY
	self.active = true

	local timer = self.timer
	if not timer then
		timer = Timer.new(self.duration)
		self.timer = timer
	end
	timer:setDuration(self.duration)
	timer:start()
end

local function ComputeAlpha(self, elapsed, duration)
	if duration <= 0 then
		return 1
	end

	local FadeInDuration = math.min(self.FadeInDuration or DEFAULT_FADE, duration)
	local FadeOutDuration = math.min(self.FadeOutDuration or DEFAULT_FADE, duration)

	if FadeInDuration > 0 and elapsed < FadeInDuration then
		return math.min(elapsed / FadeInDuration, 1)
	end

	if FadeOutDuration > 0 and (duration - elapsed) <= FadeOutDuration then
		local remaining = duration - elapsed
		return math.max(remaining / FadeOutDuration, 0)
	end

	return 1
end

function Popup:update(dt)
	if not self.active then
		return
	end

	local timer = self.timer
	if not timer then
		return
	end

	local completed = timer:update(dt)
	local elapsed = timer:getElapsed()
	local duration = timer:getDuration()

	self.alpha = ComputeAlpha(self, elapsed, duration)

	if self.alpha > 0.9 then
		local t = elapsed * 8
		self.scale = 1 + 0.05 * math.sin(t) * math.exp(-t * 0.2)
	else
		self.scale = self.scale + (1 - self.scale) * dt * 6
	end

	self.OffsetY = self.OffsetY + (0 - self.OffsetY) * dt * 6

	if completed or timer:isFinished() then
		self.active = false
	end
end

function Popup:draw()
	if not self.active then return end

	local sw, sh = Screen:get()
	local spacing = UI.spacing or {}
	local padding = spacing.panelPadding or (UI.scaled and UI.scaled(20, 12) or 20)
	local InnerSpacing = (spacing.sectionSpacing or 28) * 0.4
	local ScaledMaxWidth = UI.scaled and UI.scaled(BASE_MAX_WIDTH, 360) or BASE_MAX_WIDTH
	local MaxWidth = math.min(ScaledMaxWidth, sw - padding * 2)
	local FontTitle = UI.fonts.heading or UI.fonts.subtitle
	local FontDesc = UI.fonts.caption or UI.fonts.body

	local TitleHeight = FontTitle:getHeight()
	local BoxWidth = MaxWidth
	local WrapWidth = BoxWidth - padding * 2

	local HasSubtext = self.subtext and self.subtext:match("%S")
	local DescHeight = 0
	if HasSubtext then
		local _, DescLines = FontDesc:getWrap(self.subtext, WrapWidth)
		DescHeight = (#DescLines > 0 and #DescLines or 1) * FontDesc:getHeight()
	else
		InnerSpacing = 0
	end

	local BoxHeight = padding * 2 + TitleHeight + InnerSpacing + DescHeight
	local x = sw / 2
	local y = sh * 0.25 + self.OffsetY

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.scale(self.scale, self.scale)

	local PanelColor = Theme.PanelColor or {1, 1, 1, 1}
	UI.DrawPanel(-BoxWidth / 2, 0, BoxWidth, BoxHeight, {
		radius = UI.spacing and UI.spacing.PanelRadius or 16,
		ShadowOffset = (UI.spacing and UI.spacing.ShadowOffset or 6) * 0.6,
		fill = { PanelColor[1] or 1, PanelColor[2] or 1, PanelColor[3] or 1, (PanelColor[4] or 1) * self.alpha },
		BorderColor = Theme.PanelBorder,
	})

	local colors = UI.colors or {}
	local TextColor = colors.text or {1, 1, 1, 1}
	love.graphics.setFont(FontTitle)
	love.graphics.setColor(TextColor[1] or 1, TextColor[2] or 1, TextColor[3] or 1, (TextColor[4] or 1) * self.alpha)
	love.graphics.printf(self.text, -BoxWidth / 2 + padding, padding, WrapWidth, "center")

	if HasSubtext then
		local MutedText = colors.mutedText or TextColor
		love.graphics.setFont(FontDesc)
		love.graphics.setColor(MutedText[1] or 1, MutedText[2] or 1, MutedText[3] or 1, (MutedText[4] or 1) * self.alpha)
		love.graphics.printf(self.subtext, -BoxWidth / 2 + padding, padding + TitleHeight + InnerSpacing, WrapWidth, "center")
	end

	love.graphics.pop()
end

local DefaultPopup = CreateInstance()

function DefaultPopup:new(config)
	return CreateInstance(config)
end

function DefaultPopup:getPrototype()
	return Popup
end

return DefaultPopup
