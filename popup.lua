local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Timer = require("timers")

local min = math.min

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
	self._layoutCache = nil

	local timer = self.timer
	if not timer then
		timer = Timer.new(self.duration)
		self.timer = timer
	end
	timer:setDuration(self.duration)
	timer:start()

	self:_ensureLayoutCache()
	self:_refreshTextObjects(self._layoutCache)
end

local function computeAlpha(self, elapsed, duration)
	if duration <= 0 then
		return 1
	end

	local fadeInDuration = min(self.fadeInDuration or DEFAULT_FADE, duration)
	local fadeOutDuration = min(self.fadeOutDuration or DEFAULT_FADE, duration)

	if fadeInDuration > 0 and elapsed < fadeInDuration then
		return min(elapsed / fadeInDuration, 1)
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

function Popup:_computeLayout(sw, sh, fontTitle, fontDesc, padding, baseInnerSpacing, maxWidth)
	local wrapWidth = maxWidth - padding * 2
	if wrapWidth < 0 then
		wrapWidth = 0
	end

	local hasSubtext = self.subtext and self.subtext:match("%S") ~= nil
	local descLines = {}
	local descHeight = 0
	local innerSpacing = baseInnerSpacing

	if hasSubtext and fontDesc and fontDesc.getWrap then
		descLines = select(2, fontDesc:getWrap(self.subtext, wrapWidth)) or {}
		local lineCount = #descLines > 0 and #descLines or 1
		local descLineHeight = fontDesc:getHeight()
		if descLineHeight then
			descHeight = lineCount * descLineHeight
		end
	else
		innerSpacing = 0
	end

	local titleHeight = fontTitle and fontTitle.getHeight and fontTitle:getHeight() or 0
	local boxHeight = padding * 2 + titleHeight + innerSpacing + descHeight

	local scale = UI.getScale and UI.getScale() or nil

	local cache = {
		text = self.text,
		subtext = self.subtext,
		screenWidth = sw,
		screenHeight = sh,
		scale = scale,
		fontTitle = fontTitle,
		fontDesc = fontDesc,
		padding = padding,
		baseInnerSpacing = baseInnerSpacing,
		innerSpacing = innerSpacing,
		wrapWidth = wrapWidth,
		boxWidth = maxWidth,
		boxHeight = boxHeight,
		descLines = descLines,
		descHeight = descHeight,
		hasSubtext = hasSubtext,
		titleHeight = titleHeight,
		maxWidth = maxWidth,
	}

	self.hasSubtext = hasSubtext
	self.descLines = descLines
	self.descHeight = descHeight
	self.wrapWidth = wrapWidth
	self.innerSpacing = innerSpacing
	self.boxWidth = maxWidth
	self.boxHeight = boxHeight
	self.padding = padding
	self.titleHeight = titleHeight

	self._layoutCache = cache

	self:_refreshTextObjects(cache)

	return cache
end

function Popup:_refreshTextObjects(cache)
	cache = cache or self._layoutCache
	if not cache then
		return
	end

	local wrapWidth = cache.wrapWidth or 0
	local effectiveWrap = wrapWidth > 0 and wrapWidth or 1

	local titleFont = cache.fontTitle
	if titleFont then
		if not self.titleText or self._titleFont ~= titleFont then
			self.titleText = love.graphics.newText(titleFont)
			self._titleFont = titleFont
			self._titleWrapWidth = nil
			self._titleString = nil
		end

		if self.titleText and (self._titleString ~= self.text or self._titleWrapWidth ~= wrapWidth) then
			self.titleText:setf(self.text or "", effectiveWrap, "center")
			self._titleString = self.text
			self._titleWrapWidth = wrapWidth
		end
	else
		self.titleText = nil
		self._titleFont = nil
		self._titleWrapWidth = nil
		self._titleString = nil
	end

	local descFont = cache.fontDesc
	if cache.hasSubtext and descFont then
		if not self.subText or self._subFont ~= descFont then
			self.subText = love.graphics.newText(descFont)
			self._subFont = descFont
			self._subWrapWidth = nil
			self._subString = nil
		end

		if self.subText and (self._subString ~= self.subtext or self._subWrapWidth ~= wrapWidth) then
			self.subText:setf(self.subtext or "", effectiveWrap, "center")
			self._subString = self.subtext
			self._subWrapWidth = wrapWidth
		end
	else
		self.subText = nil
		self._subFont = nil
		self._subWrapWidth = nil
		self._subString = nil
	end
end

function Popup:_ensureLayoutCache()
	if not self.active then
		self._layoutCache = nil
		return nil
	end

	local sw, sh = Screen:get()
	local spacing = UI.spacing or {}
	local padding = spacing.panelPadding or (UI.scaled and UI.scaled(20, 12) or 20)
	local baseInnerSpacing = (spacing.sectionSpacing or 28) * 0.4
	local scaledMaxWidth = UI.scaled and UI.scaled(BASE_MAX_WIDTH, 360) or BASE_MAX_WIDTH
	local maxWidth = min(scaledMaxWidth, sw - padding * 2)
	local fontTitle = UI.fonts.heading or UI.fonts.subtitle
	local fontDesc = UI.fonts.caption or UI.fonts.body

	local cache = self._layoutCache
	if cache
	and cache.text == self.text
	and cache.subtext == self.subtext
	and cache.screenWidth == sw
	and cache.screenHeight == sh
	and cache.padding == padding
	and cache.baseInnerSpacing == baseInnerSpacing
	and cache.maxWidth == maxWidth
	and cache.fontTitle == fontTitle
	and cache.fontDesc == fontDesc
	and cache.scale == (UI.getScale and UI.getScale() or nil) then
		self:_refreshTextObjects(cache)
		return cache
	end

	return self:_computeLayout(sw, sh, fontTitle, fontDesc, padding, baseInnerSpacing, maxWidth)
end

function Popup:draw()
	if not self.active then return end

	local cache = self:_ensureLayoutCache()
	if not cache then
		return
	end

	local sw, sh = cache.screenWidth, cache.screenHeight
	local padding = cache.padding
	local innerSpacing = cache.innerSpacing
	local boxWidth = cache.boxWidth
	local boxHeight = cache.boxHeight
	local x = sw / 2
	local y = sh * 0.25 + self.offsetY

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.scale(self.scale, self.scale)

	local panelColor = Theme.panelColor or {1, 1, 1, 1}
	UI.drawPanel(-boxWidth / 2, 0, boxWidth, boxHeight, {
		radius = UI.spacing and UI.spacing.panelRadius or 16,
		shadowOffset = UI.shadowOffset,
		fill = {panelColor[1] or 1, panelColor[2] or 1, panelColor[3] or 1, (panelColor[4] or 1) * self.alpha},
		borderColor = Theme.panelBorder,
	})

	local colors = UI.colors or {}
	local textColor = colors.text or {1, 1, 1, 1}
	if self.titleText then
		love.graphics.setColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, (textColor[4] or 1) * self.alpha)
		love.graphics.draw(self.titleText, -boxWidth / 2 + padding, padding)
	end

	if cache.hasSubtext and self.subText then
		local mutedText = colors.mutedText or textColor
		love.graphics.setColor(mutedText[1] or 1, mutedText[2] or 1, mutedText[3] or 1, (mutedText[4] or 1) * self.alpha)
		love.graphics.draw(self.subText, -boxWidth / 2 + padding, padding + cache.titleHeight + innerSpacing)
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
