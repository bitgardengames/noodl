local Audio = require("audio")
local ButtonList = require("buttonlist")
local Screen = require("screen")
local Theme = require("theme")
local UI = require("ui")
local Localization = require("localization")

local DevScreen = {
	TransitionDuration = 0.35,
}

local ANALOG_DEADZONE = 0.35

local ButtonList = ButtonList.new()
local buttons = {}

local layout = {
	panel = { x = 0, y = 0, w = 0, h = 0, padding = 0 },
	button = { x = 0, y = 0 },
	ContentX = 0,
	ContentWidth = 0,
	screen = { w = 0, h = 0 },
}

local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local function ResetAnalogAxis()
	AnalogAxisDirections.horizontal = nil
	AnalogAxisDirections.vertical = nil
end

local function GetHighlightColor(color)
	color = color or {1, 1, 1, 1}
	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75
	return {r, g, b, a}
end

local function DrawDevApple(cx, cy, radius)
	local AppleColor = Theme.AppleColor or {0.9, 0.45, 0.55, 1}
	local highlight = GetHighlightColor(AppleColor)
	local BorderWidth = math.max(4, radius * 0.22)
	local AppleRadiusX = radius

	local ShadowAlpha = 0.3
	love.graphics.setColor(0, 0, 0, ShadowAlpha)
	love.graphics.circle(
		"fill",
		cx + AppleRadiusX * 0.16,
		cy + AppleRadiusX * 0.18,
		AppleRadiusX + BorderWidth * 0.5,
		48
	)

	love.graphics.setColor(AppleColor[1], AppleColor[2], AppleColor[3], AppleColor[4] or 1)
	love.graphics.circle("fill", cx, cy, AppleRadiusX, 64)

	love.graphics.push()
	love.graphics.translate(cx - AppleRadiusX * 0.3, cy - AppleRadiusX * 0.35)
	love.graphics.rotate(-0.35)
	local HighlightAlpha = (highlight[4] or 1) * 0.85
	love.graphics.setColor(highlight[1], highlight[2], highlight[3], HighlightAlpha)
	love.graphics.circle("fill", 0, 0, radius * 0.5, 48)
	love.graphics.pop()

	love.graphics.setLineWidth(BorderWidth)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.circle("line", cx, cy, AppleRadiusX, 64)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(1, 1, 1, 1)
end

function DevScreen:UpdateLayout()
	local sw, sh = Screen:get()
	layout.screen.w = sw
	layout.screen.h = sh

	local spacing = UI.spacing
	local PanelPadding = spacing.panelPadding or 20
	local FrameSize = 256
	local HorizontalMargin = math.max(140, sw * 0.18)

	local MinPanelWidth = FrameSize + PanelPadding * 2 + 160
	local PanelWidth = math.max(MinPanelWidth, math.min(780, sw - HorizontalMargin))
	PanelWidth = math.min(PanelWidth, sw - 60)

	local MinPanelHeight = FrameSize + PanelPadding * 2 + spacing.buttonHeight + 220
	local PanelHeight = math.max(MinPanelHeight, math.min(640, sh - 160))
	PanelHeight = math.min(PanelHeight, sh - 60)

	local PanelX = (sw - PanelWidth) / 2
	local PanelY = (sh - PanelHeight) / 2

	layout.panel.x = PanelX
	layout.panel.y = PanelY
	layout.panel.w = PanelWidth
	layout.panel.h = PanelHeight
	layout.panel.padding = PanelPadding

	layout.contentX = PanelX + PanelPadding
	layout.contentWidth = PanelWidth - PanelPadding * 2

	local ButtonX = PanelX + (PanelWidth - spacing.buttonWidth) / 2
	local ButtonY = PanelY + PanelHeight - PanelPadding - spacing.buttonHeight

	layout.button.x = ButtonX
	layout.button.y = ButtonY

	buttons = ButtonList:reset({
		{
			id = "DevBackButton",
			x = ButtonX,
			y = ButtonY,
			w = spacing.buttonWidth,
			h = spacing.buttonHeight,
			LabelKey = "dev.back_to_menu",
			action = "menu",
		},
	})
end

function DevScreen:enter()
	UI.ClearButtons()
	self:UpdateLayout()
	ResetAnalogAxis()
end

local function HandleAnalogAxis(axis, value)
	if axis ~= "leftx" and axis ~= "lefty" and axis ~= "rightx" and axis ~= "righty" then
		return
	end

	local AxisType = (axis == "lefty" or axis == "righty") and "vertical" or "horizontal"
	local direction
	if value > ANALOG_DEADZONE then
		direction = "positive"
	elseif value < -ANALOG_DEADZONE then
		direction = "negative"
	end

	if not direction then
		AnalogAxisDirections[AxisType] = nil
		return
	end

	if AnalogAxisDirections[AxisType] == direction then
		return
	end

	AnalogAxisDirections[AxisType] = direction

	local delta = direction == "positive" and 1 or -1
	ButtonList:moveFocus(delta)
end

local function HandleConfirm()
	local action = ButtonList:activateFocused()
	if action then
		Audio:PlaySound("click")
	end
	return action
end

function DevScreen:update(dt)
	local sw, sh = Screen:get()
	if sw ~= layout.screen.w or sh ~= layout.screen.h then
		self:UpdateLayout()
	end

	local mx, my = love.mouse.getPosition()
	ButtonList:updateHover(mx, my)
end

function DevScreen:draw()
	local sw, sh = Screen:get()
	love.graphics.setColor(0.05, 0.05, 0.08, 1.0)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	local panel = layout.panel
	local ContentX = layout.contentX
	local ContentWidth = layout.contentWidth
	local ButtonPos = layout.button

	UI.DrawPanel(panel.x, panel.y, panel.w, panel.h, {
		fill = {0.12, 0.12, 0.16, 0.96},
		BorderColor = Theme.PanelBorder,
		ShadowOffset = UI.spacing.ShadowOffset or 8,
	})

	local HeadingFont = UI.fonts.heading
	local BodyFont = UI.fonts.body
	local SmallFont = UI.fonts.small

	local HeadingHeight = HeadingFont and HeadingFont:getHeight() or 32
	local BodyHeight = BodyFont and BodyFont:getHeight() or 20
	local SmallHeight = SmallFont and SmallFont:getHeight() or 14

	local y = panel.y + panel.padding

	UI.DrawLabel(Localization:get("dev.title"), ContentX, y, ContentWidth, "left", {
		FontKey = "heading",
		color = Theme.AccentTextColor,
	})

	y = y + HeadingHeight + 12

	UI.DrawLabel(Localization:get("dev.subtitle"), ContentX, y, ContentWidth, "left", {
		FontKey = "body",
		color = Theme.TextColor,
	})

	y = y + BodyHeight + 10

	UI.DrawLabel(Localization:get("dev.description"), ContentX, y, ContentWidth, "left", {
		FontKey = "small",
		color = Theme.MutedTextColor,
	})

	y = y + SmallHeight + 36

	local FrameSize = 256
	local FrameX = panel.x + (panel.w - FrameSize) / 2
	local MaxFrameY = ButtonPos.y - FrameSize - 48
	local MinFrameY = panel.y + panel.padding + 110
	local FrameY = math.max(MinFrameY, math.min(y, MaxFrameY))

	local FrameLabel = Localization:get("dev.frame_label")
	if FrameLabel and FrameLabel ~= "dev.frame_label" then
		UI.DrawLabel(FrameLabel, FrameX, FrameY - SmallHeight - 10, FrameSize, "center", {
			FontKey = "small",
			color = Theme.MutedTextColor,
		})
	end

	local ShadowColor = Theme.ShadowColor or {0, 0, 0, 0.45}
	love.graphics.setColor(ShadowColor[1], ShadowColor[2], ShadowColor[3], (ShadowColor[4] or 1) * 0.9)
	love.graphics.rectangle("fill", FrameX + 6, FrameY + 8, FrameSize, FrameSize)

	love.graphics.setColor(0.16, 0.16, 0.22, 1.0)
	love.graphics.rectangle("fill", FrameX, FrameY, FrameSize, FrameSize)

	love.graphics.setLineWidth(4)
	love.graphics.setColor(Theme.AccentTextColor)
	love.graphics.rectangle("line", FrameX - 6, FrameY - 6, FrameSize + 12, FrameSize + 12)
	love.graphics.setLineWidth(1)

	love.graphics.setColor(1, 1, 1, 1)

	local AppleRadius = FrameSize * 0.32
	local AppleCenterX = FrameX + FrameSize / 2
	local AppleCenterY = FrameY + FrameSize / 2
	DrawDevApple(AppleCenterX, AppleCenterY, AppleRadius)

	local NumberLabel = "5000"
	local PreviousFont = love.graphics.getFont()
	local LabelFont = UI.fonts.display or UI.fonts.heading or UI.fonts.body or PreviousFont
	if LabelFont then
		love.graphics.setFont(LabelFont)
	end
	local LabelWidth = LabelFont and LabelFont:getWidth(NumberLabel) or 0
	local LabelHeight = LabelFont and LabelFont:getHeight() or 0
	local TextMargin = math.max(10, FrameSize * 0.04)
	local TextX = FrameX + TextMargin - 5
	local TextOffsetY = math.max(6, FrameSize * 0.02)
	local TextY = FrameY + FrameSize - LabelHeight - TextMargin + TextOffsetY + 5
	local ShadowOffset = math.max(3, LabelHeight * 0.08)
	love.graphics.setColor(0, 0, 0, 0.55)
	love.graphics.print(NumberLabel, TextX + ShadowOffset, TextY + ShadowOffset)
	love.graphics.setColor(Theme.AccentTextColor)
	love.graphics.print(NumberLabel, TextX, TextY)

	love.graphics.setColor(1, 1, 1, 1)
	if PreviousFont then
		love.graphics.setFont(PreviousFont)
	end

	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey)
		end
		UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
		UI.DrawButton(btn.id)
	end
end

function DevScreen:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function DevScreen:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
	if action then
		return action
	end
end

function DevScreen:keypressed(key)
	if key == "up" or key == "left" then
		ButtonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		ButtonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return HandleConfirm()
	elseif key == "escape" or key == "backspace" then
		return "menu"
	end
end

function DevScreen:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return HandleConfirm()
	elseif button == "b" then
		return "menu"
	end
end

DevScreen.joystickpressed = DevScreen.gamepadpressed

function DevScreen:gamepadaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

DevScreen.joystickaxis = DevScreen.gamepadaxis

return DevScreen
