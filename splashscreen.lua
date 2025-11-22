local Screen = require("screen")
local Audio = require("audio")
local Easing = require("easing")

local lg = love.graphics
local min = math.min
local max = math.max

local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.25
local DEFAULT_FADE_DURATION = 1.25
local LOGO_FADE_IN_DURATION = 0.6
local LOGO_ANIMATION_DELAY = 0.25

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

        logoImage = loadImage("Assets/BitGarden.png")

        return logoImage
end

function SplashScreen:enter()
        self.timer = 0
        self.logoAudioPlayed = false
        ensureLogo()

        Audio:playSound("intro")
        self.logoAudioPlayed = true
end

function SplashScreen:leave()
        self.timer = 0
        self.logoAudioPlayed = false
end

local function drawBackground(color, width, height)
	if not color then
		lg.clear(0, 0, 0, 1)
		return
	end

	lg.setColor(color)
	lg.rectangle("fill", 0, 0, width, height)
end

local function getLogoAlpha(timer)
        if not timer then
                return 0
        end

        local adjustedTimer = timer - LOGO_ANIMATION_DELAY
        if adjustedTimer <= 0 then
                return 0
        end

        local progress = min(adjustedTimer / LOGO_FADE_IN_DURATION, 1)

        return Easing.easeOutCubic(progress)
end

local function drawLogo(image, width, height, timer)
        if not image then
                return
        end

        local imgWidth, imgHeight = image:getDimensions()
	if not imgWidth or not imgHeight or imgWidth == 0 or imgHeight == 0 then
		return
	end

        local maxWidth = width * 0.5
        local maxHeight = height * 0.5
        local baseScale = min(maxWidth / imgWidth, maxHeight / imgHeight, 1)
        if baseScale <= 0 then
                baseScale = 1
        end

        local finalScale = baseScale

        local centerX = width * 0.5
        local centerY = height * 0.5 - 20

        if centerY < 0 then
                centerY = 0
        end

        local alpha = getLogoAlpha(timer)

        lg.setColor(1, 1, 1, alpha)
        lg.draw(image, centerX, centerY, 0, finalScale, finalScale, imgWidth * 0.5, imgHeight * 0.5)
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
        drawLogo(logoImage, sw, sh, self.timer or 0)
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
