local Screen = require("screen")

local SplashScreen = {
	TransitionDurationIn = 0.25,
	TransitionDurationOut = 0.25,
	DisplayDuration = 2,
	BackgroundColor = { 0.04, 0.04, 0.05, 1 },
}

local LogoImage = nil

local function LoadImage(path)
	if not path then
		return nil
	end

	local ok, image = pcall(love.graphics.newImage, path)
	if ok then
		return image
	end

	return nil
end

local function EnsureLogo()
	if LogoImage or not love or not love.graphics then
		return LogoImage
	end

	LogoImage = LoadImage("Assets/SplashLogo.png")

	return LogoImage
end

function SplashScreen:enter()
	self.timer = 0
	EnsureLogo()
end

function SplashScreen:leave()
	self.timer = 0
end

local function DrawBackground(color, width, height)
	if not color then
		love.graphics.clear(0, 0, 0, 1)
		return
	end

	love.graphics.setColor(color)
	love.graphics.rectangle("fill", 0, 0, width, height)
end

local function DrawLogo(image, width, height)
	if not image then
		return
	end

	local ImgWidth, ImgHeight = image:getDimensions()
	if not ImgWidth or not ImgHeight or ImgWidth == 0 or ImgHeight == 0 then
		return
	end

	local MaxWidth = width * 0.5
	local MaxHeight = height * 0.5
	local scale = math.min(MaxWidth / ImgWidth, MaxHeight / ImgHeight, 1)
	if scale <= 0 then
		scale = 1
	end

	local DrawWidth = ImgWidth * scale
	local DrawHeight = ImgHeight * scale
	local x = (width - DrawWidth) * 0.5
	local y = (height - DrawHeight) * 0.5 - 20

	if y < 0 then
		y = 0
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, x, y, 0, scale, scale)
end

function SplashScreen:update(dt)
	if not self.timer then
		self.timer = 0
	end

	self.timer = self.timer + (dt or 0)

	if self.timer >= self.DisplayDuration then
		return "menu"
	end
end

local function DrawFadeOverlay(timer, duration, width, height)
	if not timer or not duration or duration <= 0 then
		return
	end

	local FadeInTime = math.min(timer, 0.2)
	local FadeInAlpha = 1 - math.min(FadeInTime / 0.2, 1)

	local FadeOutStart = (duration or 1.25) - 0.25
	local FadeOutAlpha = 0
	if timer > FadeOutStart then
		local FadeOutProgress = math.min((timer - FadeOutStart) / 0.25, 1)
		FadeOutAlpha = FadeOutProgress
	end

	local alpha = math.max(FadeInAlpha, FadeOutAlpha)
	if alpha <= 0 then
		return
	end

	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.rectangle("fill", 0, 0, width, height)
end

function SplashScreen:draw()
	local sw, sh = Screen:get()
	if not sw or not sh then
		sw, sh = love.graphics.getDimensions()
	end

	DrawBackground(self.BackgroundColor, sw, sh)
	DrawLogo(LogoImage, sw, sh)
	DrawFadeOverlay(self.timer, self.DisplayDuration, sw, sh)

	love.graphics.setColor(1, 1, 1, 1)
end

local function skip()
	return "menu"
end

SplashScreen.mousepressed = skip
SplashScreen.keypressed = skip
SplashScreen.joystickpressed = skip
SplashScreen.gamepadpressed = skip

return SplashScreen
