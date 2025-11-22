local Screen = require("screen")

local lg = love.graphics
local min = math.min
local max = math.max

local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.25
local DEFAULT_FADE_DURATION = 1.25

local SplashScreen = {
	transitionDurationIn = 0.25,
	transitionDurationOut = 0.25,
	displayDuration = 2,
	backgroundColor = {0.04, 0.04, 0.05, 1},
}

local logoImage = nil

local function loadImage(path)
	if not path then
		return nil
	end

	local ok, image = pcall(lg.newImage, path)
	if ok then
		return image
	end

	return nil
end

local function ensureLogo()
	if logoImage then
		return logoImage
	end

	logoImage = loadImage("Assets/SplashLogo.png")

	return logoImage
end

function SplashScreen:enter()
	self.timer = 0
	ensureLogo()
end

function SplashScreen:leave()
	self.timer = 0
end

local function drawBackground(color, width, height)
	if not color then
		lg.clear(0, 0, 0, 1)
		return
	end

	lg.setColor(color)
	lg.rectangle("fill", 0, 0, width, height)
end

local function drawLogo(image, width, height)
	if not image then
		return
	end

	local imgWidth, imgHeight = image:getDimensions()
	if not imgWidth or not imgHeight or imgWidth == 0 or imgHeight == 0 then
		return
	end

	local maxWidth = width * 0.5
	local maxHeight = height * 0.5
	local scale = min(maxWidth / imgWidth, maxHeight / imgHeight, 1)
	if scale <= 0 then
		scale = 1
	end

	local drawWidth = imgWidth * scale
	local drawHeight = imgHeight * scale
	local x = (width - drawWidth) * 0.5
	local y = (height - drawHeight) * 0.5 - 20

	if y < 0 then
		y = 0
	end

	lg.setColor(1, 1, 1, 1)
	lg.draw(image, x, y, 0, scale, scale)
end

function SplashScreen:update(dt)
	if not self.timer then
		self.timer = 0
	end

	self.timer = self.timer + (dt or 0)

	if self.timer >= self.displayDuration then
		return "menu"
	end
end

local function drawFadeOverlay(timer, duration, width, height)
	if not timer then
		return
	end

	duration = duration or DEFAULT_FADE_DURATION
	if duration <= 0 then
		return
	end

	local fadeInTime = min(timer, FADE_IN_DURATION)
	local fadeInAlpha = 1 - min(fadeInTime / FADE_IN_DURATION, 1)

	local fadeOutStart = duration - FADE_OUT_DURATION
	local fadeOutAlpha = 0
	if timer > fadeOutStart then
		local fadeOutProgress = min((timer - fadeOutStart) / FADE_OUT_DURATION, 1)
		fadeOutAlpha = fadeOutProgress
	end

	local alpha = max(fadeInAlpha, fadeOutAlpha)
	if alpha <= 0 then
		return
	end

	lg.setColor(0, 0, 0, alpha)
	lg.rectangle("fill", 0, 0, width, height)
end

function SplashScreen:draw()
	local sw, sh = Screen:get()
	if not sw or not sh then
		sw, sh = lg.getDimensions()
	end

	drawBackground(self.backgroundColor, sw, sh)
	drawLogo(logoImage, sw, sh)
	drawFadeOverlay(self.timer, self.displayDuration, sw, sh)

	lg.setColor(1, 1, 1, 1)
end

local function skip()
	return "menu"
end

SplashScreen.mousepressed = skip
SplashScreen.keypressed = skip
SplashScreen.joystickpressed = skip
SplashScreen.gamepadpressed = skip

return SplashScreen
