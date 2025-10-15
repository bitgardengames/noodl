local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local Localization = require("localization")
local PlayerStats = require("playerstats")
local Floors = require("floors")
local ButtonList = require("buttonlist")
local Shaders = require("shaders")
local Audio = require("audio")

local FloorSelect = {
	TransitionDuration = 0.45,
}

local ButtonList = ButtonList.new()
local buttons = {}
local HighestUnlocked = 1
local DefaultFloor = 1

local BACKGROUND_EFFECT_TYPE = "MenuConstellation"
local BackgroundEffectCache = {}
local BackgroundEffect = nil

local ANALOG_DEADZONE = 0.35
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

local layout = {
	StartX = 0,
	StartY = 0,
	GridWidth = 0,
	GridHeight = 0,
	SectionSpacing = 0,
	BackY = 0,
	ButtonHeight = 0,
	LastWidth = 0,
	LastHeight = 0,
}

local function ConfigureBackgroundEffect()
	local effect = Shaders.ensure(BackgroundEffectCache, BACKGROUND_EFFECT_TYPE)
	if not effect then
		BackgroundEffect = nil
		return
	end

	local DefaultBackdrop = select(1, Shaders.GetDefaultIntensities(effect))
	effect.backdropIntensity = DefaultBackdrop or effect.backdropIntensity or 0.58

	Shaders.configure(effect, {
		BgColor = Theme.BgColor,
		AccentColor = Theme.ButtonHover,
		HighlightColor = Theme.AccentTextColor,
	})

	BackgroundEffect = effect
end

local function DrawBackground(sw, sh)
	love.graphics.setColor(Theme.BgColor)
	love.graphics.rectangle("fill", 0, 0, sw, sh)

	if not BackgroundEffect then
		ConfigureBackgroundEffect()
	end

	if BackgroundEffect then
		local intensity = BackgroundEffect.backdropIntensity or select(1, Shaders.GetDefaultIntensities(BackgroundEffect))
		Shaders.draw(BackgroundEffect, 0, 0, sw, sh, intensity)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function ResetAnalogAxis()
	AnalogAxisDirections.horizontal = nil
	AnalogAxisDirections.vertical = nil
end

local AnalogAxisActions = {
	horizontal = {
		negative = function()
			ButtonList:moveFocus(-1)
		end,
		positive = function()
			ButtonList:moveFocus(1)
		end,
	},
	vertical = {
		negative = function()
			ButtonList:moveFocus(-1)
		end,
		positive = function()
			ButtonList:moveFocus(1)
		end,
	},
}

local AnalogAxisMap = {
	leftx = { slot = "horizontal" },
	rightx = { slot = "horizontal" },
	lefty = { slot = "vertical" },
	righty = { slot = "vertical" },
	[1] = { slot = "horizontal" },
	[2] = { slot = "vertical" },
}

local function HandleAnalogAxis(axis, value)
	local mapping = AnalogAxisMap[axis]
	if not mapping then
		return
	end

	local direction
	if value >= ANALOG_DEADZONE then
		direction = "positive"
	elseif value <= -ANALOG_DEADZONE then
		direction = "negative"
	end

	if AnalogAxisDirections[mapping.slot] == direction then
		return
	end

	AnalogAxisDirections[mapping.slot] = direction

	if direction then
		local actions = AnalogAxisActions[mapping.slot]
		local action = actions and actions[direction]
		if action then
			action()
		end
	end
end

local function clamp(value, minimum, maximum)
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

local function BuildButtons(sw, sh)
	local spacing = UI.spacing or {}
	local MarginX = math.max(72, math.floor(sw * 0.08))
	local MarginBottom = math.max(140, math.floor(sh * 0.18))
	local GapX = math.max(18, spacing.buttonSpacing or 24)
	local GapY = math.max(18, spacing.buttonSpacing or 24)
	local SectionSpacing = spacing.sectionSpacing or 28

	local columns = math.max(1, math.min(4, math.ceil(HighestUnlocked / 4)))
	local AvailableWidth = sw - MarginX * 2 - GapX * (columns - 1)
	local ButtonWidth = math.max(180, math.floor(AvailableWidth / columns))
	local ButtonHeight = math.max(44, math.floor((spacing.buttonHeight or 56) * 0.9))

	local rows = math.ceil(HighestUnlocked / columns)
	local GridHeight = rows * ButtonHeight + math.max(0, rows - 1) * GapY

	local TopMargin = math.max(120, math.floor(sh * 0.2))
	local AvailableHeight = sh - TopMargin - MarginBottom
	local StartY = TopMargin + math.max(0, math.floor((AvailableHeight - GridHeight) / 2))
	local StartX = math.floor((sw - (ButtonWidth * columns + GapX * (columns - 1))) / 2)

	local defs = {}

	for floor = 1, HighestUnlocked do
		local col = (floor - 1) % columns
		local row = math.floor((floor - 1) / columns)
		local x = StartX + col * (ButtonWidth + GapX)
		local y = StartY + row * (ButtonHeight + GapY)
		local FloorData = Floors[floor] or {}
		local LabelArgs = {
			floor = floor,
			name = FloorData.name or Localization:get("common.unknown"),
		}

		defs[#defs + 1] = {
			id = string.format("floor_button_%d", floor),
			x = x,
			y = y,
			w = ButtonWidth,
			h = ButtonHeight,
			action = {
				state = "game",
				data = { StartFloor = floor },
			},
			floor = floor,
			LabelKey = "floor_select.button_label",
			LabelArgs = LabelArgs,
		}
	end

	local BackWidth = ButtonWidth
	local BackX = math.floor((sw - BackWidth) / 2)
	local BackY = StartY + GridHeight + SectionSpacing * 4
	local MaxBackY = sh - (spacing.buttonHeight or 56) - 40
	BackY = clamp(BackY, StartY + GridHeight + SectionSpacing * 2, MaxBackY)

	defs[#defs + 1] = {
			id = "floor_back",
			x = BackX,
			y = BackY,
			w = BackWidth,
			h = ButtonHeight,
			action = "menu",
			LabelKey = "common.back",
	}

	buttons = ButtonList:reset(defs)

	for index, btn in ipairs(buttons) do
		if btn.floor == DefaultFloor then
			ButtonList:setFocus(index, nil, true)
			break
		end
	end

	layout.startX = StartX
	layout.startY = StartY
	layout.gridWidth = ButtonWidth * columns + GapX * (columns - 1)
	layout.gridHeight = GridHeight
	layout.sectionSpacing = SectionSpacing
	layout.backY = BackY
	layout.buttonHeight = ButtonHeight
	layout.lastWidth = sw
	layout.lastHeight = sh
end

local function EnsureLayout(sw, sh)
	if layout.lastWidth ~= sw or layout.lastHeight ~= sh then
		BuildButtons(sw, sh)
	end
end

function FloorSelect:enter(data)
	UI.ClearButtons()
	Screen:update()
	ConfigureBackgroundEffect()
	ResetAnalogAxis()

	local RequestedHighest = data and data.highestFloor
	HighestUnlocked = math.max(1, math.floor(RequestedHighest or PlayerStats:get("DeepestFloorReached") or 1))
	local TotalFloors = #Floors
	if TotalFloors > 0 then
			HighestUnlocked = math.min(HighestUnlocked, TotalFloors)
	end

	DefaultFloor = math.max(1, math.min(HighestUnlocked, math.floor((data and data.defaultFloor) or HighestUnlocked)))

	local sw, sh = Screen:get()
	BuildButtons(sw, sh)
end

function FloorSelect:update(dt)
	local sw, sh = Screen:get()
	EnsureLayout(sw, sh)

	local mx, my = love.mouse.getPosition()
	ButtonList:updateHover(mx, my)
end

local function DrawHeading(sw, sh)
	local title = Localization:get("floor_select.title")
	local subtitle = Localization:get("floor_select.subtitle")
	local HighestText = Localization:get("floor_select.highest_label", { floor = HighestUnlocked })

	UI.DrawLabel(title, 0, math.floor(sh * 0.08), sw, "center", { FontKey = "title" })

	local SubtitleFont = UI.fonts.body
	local SubtitleHeight = SubtitleFont and SubtitleFont:getHeight() or 28
	local SubtitleY = math.floor(sh * 0.08) + (UI.fonts.title and UI.fonts.title:GetHeight() or 64) + 10
	UI.DrawLabel(subtitle, sw * 0.15, SubtitleY, sw * 0.7, "center", { FontKey = "body", color = UI.colors.SubtleText })

	local HighestY = SubtitleY + SubtitleHeight + 8
	UI.DrawLabel(HighestText, sw * 0.2, HighestY, sw * 0.6, "center", { FontKey = "body", color = UI.colors.text })

	local instruction = Localization:get("floor_select.instruction")
	local InstructionY = layout.startY - layout.sectionSpacing * 1.5
	UI.DrawLabel(instruction, sw * 0.15, InstructionY, sw * 0.7, "center", { FontKey = "body", color = UI.colors.SubtleText })
end

local function DrawButtons()
	for _, btn in ipairs(buttons) do
		if btn.labelKey then
			btn.text = Localization:get(btn.labelKey, btn.labelArgs)
		end

		UI.RegisterButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
		UI.DrawButton(btn.id)
	end
end

local function DrawDescription(sw)
	local focused = ButtonList:getFocused()
	local FocusFloor = focused and focused.floor
	if type(FocusFloor) ~= "number" then
		FocusFloor = DefaultFloor
	end

	local FloorData = Floors[FocusFloor] or {}
	local description = FloorData.flavor or Localization:get("floor_select.description_fallback")
	local padding = math.max(60, math.floor(sw * 0.12))
	local width = sw - padding * 2
	local SectionSpacing = layout.sectionSpacing or 24
	local BaseY = layout.backY - SectionSpacing * 2

	local BodyFont = UI.fonts.body
	local DescHeight = 0
	if BodyFont then
		local _, lines = BodyFont:getWrap(description, width)
		DescHeight = #lines * BodyFont:getHeight()
	end

	local MinY = layout.startY + layout.gridHeight + SectionSpacing
	local y = math.max(MinY, BaseY - DescHeight)
	UI.DrawLabel(description, padding, y, width, "center", { FontKey = "body", color = UI.colors.SubtleText })
end

function FloorSelect:draw()
	local sw, sh = Screen:get()
	DrawBackground(sw, sh)

	DrawHeading(sw, sh)
	DrawButtons()
	DrawDescription(sw)
end

function FloorSelect:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function FloorSelect:mousereleased(x, y, button)
	local action = ButtonList:mousereleased(x, y, button)
	if action then
		Audio:PlaySound("click")
		return action
	end
end

local function ActivateFocused()
	local action = ButtonList:activateFocused()
	if action then
		Audio:PlaySound("click")
	end
	return action
end

function FloorSelect:keypressed(key)
	if key == "left" or key == "up" then
		ButtonList:moveFocus(-1)
	elseif key == "right" or key == "down" then
		ButtonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return ActivateFocused()
	elseif key == "escape" or key == "backspace" then
		Audio:PlaySound("click")
		return "menu"
	end
end

function FloorSelect:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return ActivateFocused()
	elseif button == "b" then
		Audio:PlaySound("click")
		return "menu"
	end
end

FloorSelect.joystickpressed = FloorSelect.gamepadpressed

function FloorSelect:gamepadaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

function FloorSelect:joystickaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

FloorSelect.joystickaxis = FloorSelect.gamepadaxis

return FloorSelect
