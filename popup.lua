local Popup = {}
local Screen = require("screen")

Popup.active = false
Popup.text = ""
Popup.subtext = ""
Popup.timer = 0
Popup.duration = 3
Popup.alpha = 0
Popup.scale = 1
Popup.offsetY = 0

local padding = 20
local maxWidth = 600

function Popup:show(title, description)
    self.text = title
    self.subtext = description or ""
    self.timer = self.duration
    self.active = true
    self.alpha = 0
    self.scale = 0.8       -- start small, bounce in
    self.offsetY = -30     -- slide from above
end

function Popup:update(dt)
    if self.active then
        self.timer = self.timer - dt

        -- Fade in/out
        if self.timer > self.duration - 0.5 then
            self.alpha = math.min(self.alpha + dt * 4, 1)
        elseif self.timer < 0.5 then
            self.alpha = math.max(self.alpha - dt * 4, 0)
        end

        -- Scale bounce (ease toward 1.05 then back to 1)
        if self.alpha > 0.9 then
            local t = (self.duration - self.timer) * 8
            self.scale = 1 + 0.05 * math.sin(t) * math.exp(-t * 0.2)
        else
            self.scale = self.scale + (1 - self.scale) * dt * 6
        end

        -- Slide in (ease offset toward 0)
        self.offsetY = self.offsetY + (0 - self.offsetY) * dt * 6

        if self.timer <= 0 then
            self.active = false
        end
    end
end

function Popup:draw()
    if not self.active then return end

    local sw, sh = Screen:get()
    local fontTitle = love.graphics.newFont(24)
    local fontDesc = love.graphics.newFont(16)

    local titleHeight = fontTitle:getHeight()
    local descHeight = fontDesc:getHeight()

    local boxWidth = maxWidth
    local boxHeight = padding * 2 + titleHeight + descHeight + 20
    local x = sw / 2
    local y = sh * 0.25 + self.offsetY

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(self.scale, self.scale)

    -- Background with rounded corners
    love.graphics.setColor(0, 0, 0, 0.75 * self.alpha)
    love.graphics.rectangle("fill", -boxWidth/2, 0, boxWidth, boxHeight, 12, 12)

    -- Subtle border glow
    love.graphics.setColor(1, 1, 1, 0.1 * self.alpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -boxWidth/2, 0, boxWidth, boxHeight, 12, 12)

    -- Text
    love.graphics.setColor(1, 1, 1, self.alpha)

    love.graphics.setFont(fontTitle)
    love.graphics.printf(self.text, -boxWidth/2 + padding, padding, boxWidth - padding * 2, "center")

    love.graphics.setFont(fontDesc)
    love.graphics.printf(self.subtext, -boxWidth/2 + padding, padding + titleHeight + 10, boxWidth - padding * 2, "center")

    love.graphics.pop()
end

return Popup