local Screen = require("screen")

local SplashScreen = {
    transitionDurationIn = 0.25,
    transitionDurationOut = 0.25,
    displayDuration = 1.35,
    backgroundColor = { 0.04, 0.04, 0.05, 1 },
}

local logoImage = nil

local function ensureLogo()
    if logoImage or not love or not love.graphics then
        return logoImage
    end

    local ok, image = pcall(love.graphics.newImage, "Assets/BitGarden.png")
    if ok then
        logoImage = image
    end

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
        love.graphics.clear(0, 0, 0, 1)
        return
    end

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", 0, 0, width, height)
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
    local scale = math.min(maxWidth / imgWidth, maxHeight / imgHeight)
    if scale > 1.75 then
        scale = 1.75
    elseif scale <= 0 then
        scale = 1
    end

    local drawWidth = imgWidth * scale
    local drawHeight = imgHeight * scale
    local x = (width - drawWidth) * 0.5
    local y = (height - drawHeight) * 0.5

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y, 0, scale, scale)
end

function SplashScreen:update(dt)
    if not self.timer then
        self.timer = 0
    end

    self.timer = self.timer + (dt or 0)

    if self.timer >= (self.displayDuration or 1.25) then
        return "menu"
    end
end

local function drawFadeOverlay(timer, duration, width, height)
    if not timer or not duration or duration <= 0 then
        return
    end

    local fadeInTime = math.min(timer, 0.2)
    local fadeInAlpha = 1 - math.min(fadeInTime / 0.2, 1)

    local fadeOutStart = (duration or 1.25) - 0.25
    local fadeOutAlpha = 0
    if timer > fadeOutStart then
        local fadeOutProgress = math.min((timer - fadeOutStart) / 0.25, 1)
        fadeOutAlpha = fadeOutProgress
    end

    local alpha = math.max(fadeInAlpha, fadeOutAlpha)
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

    drawBackground(self.backgroundColor, sw, sh)
    drawLogo(logoImage, sw, sh)
    drawFadeOverlay(self.timer, self.displayDuration, sw, sh)

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
