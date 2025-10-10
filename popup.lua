local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")

local Popup = {}

Popup.active = false
Popup.text = ""
Popup.subtext = ""
Popup.timer = 0
Popup.duration = 3
Popup.alpha = 0
Popup.scale = 1
Popup.offsetY = 0

local BASE_MAX_WIDTH = 560

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
        local _, descLines = fontDesc:getWrap(self.subtext, wrapWidth)
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
        fill = { panelColor[1] or 1, panelColor[2] or 1, panelColor[3] or 1, (panelColor[4] or 1) * self.alpha },
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

return Popup
