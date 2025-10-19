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

local function createInstance(config)
	config = config or {}

	local instance = {
		active = false,
		text = "",
		subtext = "",
		alpha = 0,
		scale = 1,
		offsetY = 0,
		duration = config.duration or DEFAULT_DURATION,
		fadeInDuration = config.fadeInDuration or DEFAULT_FADE,
		fadeOutDuration = config.fadeOutDuration or DEFAULT_FADE,
		timer = Timer.new(config.duration or DEFAULT_DURATION),
		startScale = config.startScale or DEFAULT_START_SCALE,
		startOffsetY = config.startOffsetY or DEFAULT_START_OFFSET,
	}

	return setmetatable(instance, Popup)
end

function Popup.new(config)
	return createInstance(config)
end

function Popup:show(title, description, options)
	options = options or {}

	if options.duration then
		self.duration = options.duration
	end
	if options.fadeInDuration then
		self.fadeInDuration = options.fadeInDuration
	end
	if options.fadeOutDuration then
		self.fadeOutDuration = options.fadeOutDuration
	end

	local startScale = options.startScale or self.startScale or DEFAULT_START_SCALE
	local startOffsetY = options.startOffsetY or self.startOffsetY or DEFAULT_START_OFFSET

	self.text = title or ""
	self.subtext = description or ""
	self.alpha = 0
	self.scale = startScale
	self.offsetY = startOffsetY
	self.active = true

	local timer = self.timer
	if not timer then
		timer = Timer.new(self.duration)
		self.timer = timer
	end
	timer:setDuration(self.duration)
	timer:start()
end

local function computeAlpha(self, elapsed, duration)
	if duration <= 0 then
		return 1
	end

	local fadeInDuration = math.min(self.fadeInDuration or DEFAULT_FADE, duration)
	local fadeOutDuration = math.min(self.fadeOutDuration or DEFAULT_FADE, duration)

	if fadeInDuration > 0 and elapsed < fadeInDuration then
		return math.min(elapsed / fadeInDuration, 1)
	end

	if fadeOutDuration > 0 and (duration - elapsed) <= fadeOutDuration then
		local remaining = duration - elapsed
		return math.max(remaining / fadeOutDuration, 0)
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

	self.alpha = computeAlpha(self, elapsed, duration)

	if self.alpha > 0.9 then
		local t = elapsed * 8
		self.scale = 1 + 0.05 * math.sin(t) * math.exp(-t * 0.2)
	else
		self.scale = self.scale + (1 - self.scale) * dt * 6
	end

	self.offsetY = self.offsetY + (0 - self.offsetY) * dt * 6

	if completed or timer:isFinished() then
		self.active = false
	end
end

function Popup:draw()
	if not self.active then return end

	local sw, sh = Screen:get()
	local spacing = UI.spacing or {}
	local padding = spacing.panelPadding or (UI.scaled and UI.scaled(20, 12) or 20)
	local innerSpacing = (spacing.sectionSpacing or 28) * 0.4
	local scaledMaxWidth = UI.scaled and UI.scaled(BASE_MAX_WIDTH, 360) or BASE_MAX_WIDTH
	local maxWidth = math.min(scaledMaxWidth, sw - padding * 2)
	local fontTitle = UI.fonts.heading or UI.fonts.subtitle
	local fontDesc = UI.fonts.caption or UI.fonts.body

	local titleHeight = fontTitle:getHeight()
	local boxWidth = maxWidth
	local wrapWidth = boxWidth - padding * 2

	local hasSubtext = self.subtext and self.subtext:match("%S")
	local descHeight = 0
	if hasSubtext then
		local descLines = select(2, fontDesc:getWrap(self.subtext, wrapWidth))
		descHeight = (#descLines > 0 and #descLines or 1) * fontDesc:getHeight()
	else
		innerSpacing = 0
	end

	local boxHeight = padding * 2 + titleHeight + innerSpacing + descHeight
	local x = sw / 2
	local y = sh * 0.25 + self.offsetY

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.scale(self.scale, self.scale)

	local panelColor = Theme.panelColor or {1, 1, 1, 1}
	UI.drawPanel(-boxWidth / 2, 0, boxWidth, boxHeight, {
		radius = UI.spacing and UI.spacing.panelRadius or 16,
		shadowOffset = (UI.spacing and UI.spacing.shadowOffset or 6) * 0.6,
		fill = {panelColor[1] or 1, panelColor[2] or 1, panelColor[3] or 1, (panelColor[4] or 1) * self.alpha},
		borderColor = Theme.panelBorder,
	})

	local colors = UI.colors or {}
	local textColor = colors.text or {1, 1, 1, 1}
	love.graphics.setFont(fontTitle)
	love.graphics.setColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, (textColor[4] or 1) * self.alpha)
	love.graphics.printf(self.text, -boxWidth / 2 + padding, padding, wrapWidth, "center")

	if hasSubtext then
		local mutedText = colors.mutedText or textColor
		love.graphics.setFont(fontDesc)
		love.graphics.setColor(mutedText[1] or 1, mutedText[2] or 1, mutedText[3] or 1, (mutedText[4] or 1) * self.alpha)
		love.graphics.printf(self.subtext, -boxWidth / 2 + padding, padding + titleHeight + innerSpacing, wrapWidth, "center")
	end

	love.graphics.pop()
end

local defaultPopup = createInstance()

function defaultPopup:new(config)
	return createInstance(config)
end

function defaultPopup:getPrototype()
	return Popup
end

return defaultPopup
