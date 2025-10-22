local Audio = require("audio")
local ButtonList = require("buttonlist")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Localization = require("localization")

local max = math.max
local min = math.min

local DevScreen = {
	transitionDuration = 0.35,
}

local ANALOG_DEADZONE = 0.35

local buttonList = ButtonList.new()
local buttons = {}

local layout = {
	panel = {x = 0, y = 0, w = 0, h = 0, padding = 0},
	button = {x = 0, y = 0},
	contentX = 0,
	contentWidth = 0,
	screen = {w = 0, h = 0},
}

local analogAxisDirections = {horizontal = nil, vertical = nil}

local function resetAnalogAxis()
	analogAxisDirections.horizontal = nil
	analogAxisDirections.vertical = nil
end

local function getHighlightColor(color)
	color = color or {1, 1, 1, 1}
	local r = min(1, color[1] * 1.2 + 0.08)
	local g = min(1, color[2] * 1.2 + 0.08)
	local b = min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75
	return {r, g, b, a}
end

local function drawDevApple(cx, cy, radius)
	local appleColor = Theme.appleColor or {0.9, 0.45, 0.55, 1}
	local highlight = getHighlightColor(appleColor)
	local borderWidth = max(4, radius * 0.22)
	local appleRadiusX = radius

	local shadowAlpha = 0.3
	love.graphics.setColor(0, 0, 0, shadowAlpha)
	love.graphics.circle(
	"fill",
	cx + appleRadiusX * 0.16,
	cy + appleRadiusX * 0.18,
	appleRadiusX + borderWidth * 0.5,
	48
	)

	love.graphics.setColor(appleColor[1], appleColor[2], appleColor[3], appleColor[4] or 1)
	love.graphics.circle("fill", cx, cy, appleRadiusX, 64)

	love.graphics.push()
	love.graphics.translate(cx - appleRadiusX * 0.3, cy - appleRadiusX * 0.35)
	love.graphics.rotate(-0.35)
	local highlightAlpha = (highlight[4] or 1) * 0.85
	love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
	love.graphics.circle("fill", 0, 0, radius * 0.5, 48)
	love.graphics.pop()

	love.graphics.setLineWidth(borderWidth)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle("line", cx, cy, appleRadiusX, 64)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(1, 1, 1, 1)
end

function DevScreen:updateLayout()
	local sw, sh = Screen:get()
	layout.screen.w = sw
	layout.screen.h = sh

	local spacing = UI.spacing
	local panelPadding = spacing.panelPadding or 20
	local frameSize = 256
	local horizontalMargin = max(140, sw * 0.18)

	local minPanelWidth = frameSize + panelPadding * 2 + 160
	local panelWidth = max(minPanelWidth, min(780, sw - horizontalMargin))
	panelWidth = min(panelWidth, sw - 60)

	local minPanelHeight = frameSize + panelPadding * 2 + spacing.buttonHeight + 220
	local panelHeight = max(minPanelHeight, min(640, sh - 160))
	panelHeight = min(panelHeight, sh - 60)

	local panelX = (sw - panelWidth) / 2
	local panelY = (sh - panelHeight) / 2

	layout.panel.x = panelX
	layout.panel.y = panelY
	layout.panel.w = panelWidth
	layout.panel.h = panelHeight
	layout.panel.padding = panelPadding

	layout.contentX = panelX + panelPadding
	layout.contentWidth = panelWidth - panelPadding * 2

        local buttonX = panelX + (panelWidth - spacing.buttonWidth) / 2
        local buttonHeight = spacing.buttonHeight
        local buttonSpacing = spacing.buttonSpacing or 16
        local buttonCount = 2
        local firstButtonY = panelY + panelHeight - panelPadding - buttonHeight
        firstButtonY = firstButtonY - (buttonHeight + buttonSpacing) * (buttonCount - 1)

        layout.button.x = buttonX
        layout.button.y = firstButtonY + (buttonCount - 1) * (buttonHeight + buttonSpacing)

        buttons = buttonList:reset({
                {
                        id = "devRenderButton",
                        x = buttonX,
                        y = firstButtonY,
                        w = spacing.buttonWidth,
                        h = buttonHeight,
                        labelKey = "dev.render_canvas",
                        action = "rendercanvas",
                },
                {
                        id = "devBackButton",
                        x = buttonX,
                        y = firstButtonY + buttonHeight + buttonSpacing,
                        w = spacing.buttonWidth,
                        h = buttonHeight,
                        labelKey = "dev.back_to_menu",
                        action = "menu",
                },
        })
end

function DevScreen:enter()
	UI.clearButtons()
	self:updateLayout()
	resetAnalogAxis()
end

local function handleAnalogAxis(axis, value)
	if axis ~= "leftx" and axis ~= "lefty" and axis ~= "rightx" and axis ~= "righty" then
		return
	end

	local axisType = (axis == "lefty" or axis == "righty") and "vertical" or "horizontal"
	local direction
	if value > ANALOG_DEADZONE then
		direction = "positive"
	elseif value < -ANALOG_DEADZONE then
		direction = "negative"
	end

	if not direction then
		analogAxisDirections[axisType] = nil
		return
	end

	if analogAxisDirections[axisType] == direction then
		return
	end

	analogAxisDirections[axisType] = direction

	local delta = direction == "positive" and 1 or -1
	buttonList:moveFocus(delta)
end

local function handleConfirm()
	local action = buttonList:activateFocused()
	if action then
		Audio:playSound("click")
	end
	return action
end

function DevScreen:update(dt)
	local sw, sh = Screen:get()
	if sw ~= layout.screen.w or sh ~= layout.screen.h then
		self:updateLayout()
	end

	local mx, my = love.mouse.getPosition()
	buttonList:updateHover(mx, my)
end

function DevScreen:draw()
	local sw, sh = Screen:get()
	love.graphics.setColor(0.05, 0.05, 0.08, 1.0)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	local panel = layout.panel
	local contentX = layout.contentX
	local contentWidth = layout.contentWidth
	local buttonPos = layout.button

	UI.drawPanel(panel.x, panel.y, panel.w, panel.h, {
		fill = {0.12, 0.12, 0.16, 0.96},
		borderColor = Theme.panelBorder,
		shadowOffset = UI.spacing.shadowOffset or 8,
	})

	local headingFont = UI.fonts.heading
	local bodyFont = UI.fonts.body
	local smallFont = UI.fonts.small

	local headingHeight = headingFont and headingFont:getHeight() or 32
	local bodyHeight = bodyFont and bodyFont:getHeight() or 20
	local smallHeight = smallFont and smallFont:getHeight() or 14

	local y = panel.y + panel.padding

	UI.drawLabel(Localization:get("dev.title"), contentX, y, contentWidth, "left", {
		fontKey = "heading",
		color = Theme.accentTextColor,
	})

	y = y + headingHeight + 12

	UI.drawLabel(Localization:get("dev.subtitle"), contentX, y, contentWidth, "left", {
		fontKey = "body",
		color = Theme.textColor,
	})

	y = y + bodyHeight + 10

	UI.drawLabel(Localization:get("dev.description"), contentX, y, contentWidth, "left", {
		fontKey = "small",
		color = Theme.mutedTextColor,
	})

	y = y + smallHeight + 36

	local frameSize = 256
	local frameX = panel.x + (panel.w - frameSize) / 2
	local maxFrameY = buttonPos.y - frameSize - 48
	local minFrameY = panel.y + panel.padding + 110
	local frameY = max(minFrameY, min(y, maxFrameY))

	local frameLabel = Localization:get("dev.frame_label")
	if frameLabel and frameLabel ~= "dev.frame_label" then
		UI.drawLabel(frameLabel, frameX, frameY - smallHeight - 10, frameSize, "center", {
			fontKey = "small",
			color = Theme.mutedTextColor,
		})
	end

	local shadowColor = Theme.shadowColor or {0, 0, 0, 0.45}
	love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], (shadowColor[4] or 1) * 0.9)
	love.graphics.rectangle("fill", frameX + 6, frameY + 8, frameSize, frameSize)

	love.graphics.setColor(0.16, 0.16, 0.22, 1.0)
	love.graphics.rectangle("fill", frameX, frameY, frameSize, frameSize)

	love.graphics.setLineWidth(4)
	love.graphics.setColor(Theme.accentTextColor)
	love.graphics.rectangle("line", frameX - 6, frameY - 6, frameSize + 12, frameSize + 12)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(1, 1, 1, 1)

	local appleRadius = frameSize * 0.32
	local appleCenterX = frameX + frameSize / 2
	local appleCenterY = frameY + frameSize / 2
	drawDevApple(appleCenterX, appleCenterY, appleRadius)

	local numberLabel = "5000"
	local previousFont = love.graphics.getFont()
	local labelFont = UI.fonts.display or UI.fonts.heading or UI.fonts.body or previousFont
	if labelFont then
		love.graphics.setFont(labelFont)
	end
	local labelHeight = labelFont and labelFont:getHeight() or 0
	local textMargin = max(10, frameSize * 0.04)
	local textX = frameX + textMargin - 5
	local textOffsetY = max(6, frameSize * 0.02)
	local textY = frameY + frameSize - labelHeight - textMargin + textOffsetY + 5
	local shadowOffset = max(3, labelHeight * 0.08)
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.print(numberLabel, textX + shadowOffset, textY + shadowOffset)
	love.graphics.setColor(Theme.accentTextColor)
	love.graphics.print(numberLabel, textX, textY)

	love.graphics.setColor(1, 1, 1, 1)
	if previousFont then
		love.graphics.setFont(previousFont)
	end

	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey)
		end
		UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
		UI.drawButton(btn.id)
	end
end

function DevScreen:mousepressed(x, y, button)
	buttonList:mousepressed(x, y, button)
end

function DevScreen:mousereleased(x, y, button)
	local action = buttonList:mousereleased(x, y, button)
	if action then
		return action
	end
end

function DevScreen:keypressed(key)
	if key == "up" or key == "left" then
		buttonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		buttonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return handleConfirm()
	elseif key == "escape" or key == "backspace" then
		return "menu"
	end
end

function DevScreen:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		buttonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		buttonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return handleConfirm()
	elseif button == "b" then
		return "menu"
	end
end

DevScreen.joystickpressed = DevScreen.gamepadpressed

function DevScreen:gamepadaxis(_, axis, value)
	handleAnalogAxis(axis, value)
end

DevScreen.joystickaxis = DevScreen.gamepadaxis

return DevScreen
