local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")

local Tooltip = {
        active = false,
        alpha = 0,
        delayTimer = 0,
        currentId = nil,
        text = "",
        placement = "cursor",
        anchorX = 0,
        anchorY = 0,
        maxWidth = 320,
        offset = 18,
        followCursor = true,
        mouseX = 0,
        mouseY = 0,
        defaultDelay = 0.18,
        defaultOffset = 18,
        defaultMaxWidth = 320,
}

local function hasContent(text)
        return type(text) == "string" and text:match("%S") ~= nil
end

local function applyDelay(self, options, changed)
        local delay = options and options.delay
        if delay == nil then
                delay = self.defaultDelay or 0
        end

        if changed then
                self.delayTimer = -(delay or 0)
        end
end

function Tooltip:update(dt, mx, my)
        if mx then
                self.mouseX = mx
        end
        if my then
                self.mouseY = my
        end

        if self.active then
                if self.delayTimer < 0 then
                        self.delayTimer = math.min(self.delayTimer + dt, 0)
                end
        elseif self.delayTimer ~= 0 then
                        self.delayTimer = 0
        end

        local shouldDisplay = self.active and self.delayTimer >= 0 and hasContent(self.text)
        local targetAlpha = shouldDisplay and 1 or 0
        local speed = targetAlpha > self.alpha and 16 or 12
        self.alpha = self.alpha + (targetAlpha - self.alpha) * math.min(dt * speed, 1)

        if not self.active and self.alpha < 0.01 then
                self.alpha = 0
                self.text = ""
                self.currentId = nil
                self.delayTimer = 0
        end
end

function Tooltip:show(text, options)
        options = options or {}

        local id = options.id or text
        local placement = options.placement or "cursor"
        local x = options.x or self.anchorX
        local y = options.y or self.anchorY
        local maxWidth = options.maxWidth or self.defaultMaxWidth or self.maxWidth
        local offset = options.offset or self.defaultOffset or self.offset

        local changed = (self.currentId ~= id)
                or (self.text ~= text)
                or (self.placement ~= placement)
                or (self.anchorX ~= x)
                or (self.anchorY ~= y)
                or (self.maxWidth ~= maxWidth)
                or (self.offset ~= offset)

        applyDelay(self, options, changed)

        self.text = text or ""
        self.currentId = id
        self.placement = placement
        self.anchorX = x
        self.anchorY = y
        self.maxWidth = maxWidth
        self.offset = offset
        self.followCursor = placement == "cursor" and (options.followMouse ~= false)
        self.active = true
end

function Tooltip:hide(id)
        if id and self.currentId and id ~= self.currentId then
                return
        end

        self.active = false
end

function Tooltip:isVisible()
        return self.alpha > 0.01 and hasContent(self.text)
end

local function computeWrap(font, text, maxWidth)
        if not hasContent(text) then
                return 0, {}
        end

        local width, lines = font:getWrap(text, maxWidth)
        if not lines or #lines == 0 then
                return width, { text }
        end

        return width, lines
end

local function clamp(value, minValue, maxValue)
        if value < minValue then
                return minValue
        end
        if value > maxValue then
                return maxValue
        end
        return value
end

function Tooltip:draw()
        local alpha = self.alpha
        if alpha <= 0.01 then
                return
        end

        local text = self.text
        if not hasContent(text) then
                return
        end

        local sw, sh = Screen:get()
        local fonts = UI.fonts or {}
        local font = fonts.caption or fonts.small or fonts.body
        if not font then
                return
        end

        love.graphics.setFont(font)

        local maxWidth = clamp(self.maxWidth or self.defaultMaxWidth or 320, 120, sw - 24)
        local _, lines = computeWrap(font, text, maxWidth)
        local lineCount = math.max(1, #lines)
        local lineHeight = font:getHeight()
        local textHeight = lineCount * lineHeight

        local spacing = UI.spacing or {}
        local paddingX = (spacing.panelPadding or 20) * 0.6
        local paddingY = paddingX * 0.75
        local measuredWidth = 0
        for i = 1, lineCount do
                measuredWidth = math.max(measuredWidth, font:getWidth(lines[i]))
        end
        local boxWidth = math.min(maxWidth, measuredWidth) + paddingX * 2
        boxWidth = math.max(boxWidth, paddingX * 2 + 12)
        local boxHeight = textHeight + paddingY * 2

        local placement = self.placement or "cursor"
        local offset = self.offset or self.defaultOffset or 18
        local anchorX = self.anchorX or 0
        local anchorY = self.anchorY or 0

        if placement == "cursor" or self.followCursor then
                anchorX = (self.mouseX or 0) + offset
                anchorY = (self.mouseY or 0) + offset
        end

        local x = anchorX
        local y = anchorY
        local originX = 0

        if placement == "cursor" then
                originX = 0
        elseif placement == "above" then
                originX = boxWidth / 2
                x = anchorX
                y = anchorY - boxHeight - offset
        elseif placement == "below" then
                originX = boxWidth / 2
                x = anchorX
                y = anchorY + offset
        elseif placement == "left" then
                originX = boxWidth
                x = anchorX - offset
        elseif placement == "right" then
                originX = 0
                x = anchorX + offset
        elseif placement == "center" then
                originX = boxWidth / 2
                x = anchorX
                y = anchorY - boxHeight / 2
        else
                originX = boxWidth / 2
                x = anchorX
        end

        local margin = 12
        local left = x - originX
        local right = left + boxWidth
        if left < margin then
                left = margin
                right = left + boxWidth
        end
        if right > sw - margin then
                right = sw - margin
                left = right - boxWidth
        end
        x = left + originX

        if y < margin then
                y = margin
        end
        if y + boxHeight > sh - margin then
                y = sh - margin - boxHeight
        end

        local colors = UI.colors or {}
        local panelColor = Theme.tooltipBackground or colors.panel or Theme.panelColor or {0.08, 0.08, 0.12, 0.94}
        local borderColor = Theme.tooltipBorder or colors.border or Theme.panelBorder or {1, 1, 1, 0.16}
        local shadowColor = Theme.tooltipShadow or colors.shadow or Theme.shadowColor or {0, 0, 0, 0.4}
        local textColor = Theme.tooltipText or colors.text or Theme.textColor or {1, 1, 1, 1}
        local radius = spacing.panelRadius or 12

        love.graphics.setColor(shadowColor[1] or 0, shadowColor[2] or 0, shadowColor[3] or 0, (shadowColor[4] or 1) * alpha * 0.7)
        love.graphics.rectangle("fill", left + 3, y + 5, boxWidth, boxHeight, radius, radius)

        love.graphics.setColor(panelColor[1] or 1, panelColor[2] or 1, panelColor[3] or 1, (panelColor[4] or 1) * alpha)
        love.graphics.rectangle("fill", left, y, boxWidth, boxHeight, radius, radius)

        love.graphics.setLineWidth(1)
        love.graphics.setColor(borderColor[1] or 1, borderColor[2] or 1, borderColor[3] or 1, (borderColor[4] or 1) * alpha)
        love.graphics.rectangle("line", left, y, boxWidth, boxHeight, radius, radius)

        love.graphics.setColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, (textColor[4] or 1) * alpha)
        love.graphics.printf(text, left + paddingX, y + paddingY, boxWidth - paddingX * 2)
end

return Tooltip
