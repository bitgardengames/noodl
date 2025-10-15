local Audio = require("audio")
local Settings = require("settings")
local Localization = require("localization")
local UI = require("ui")
local Theme = require("theme")

local PauseMenu = {}

local alpha = 0
local FadeSpeed = 4

local CurrentFloorLabel = nil

local ButtonList = require("buttonlist")
local ANALOG_DEADZONE = 0.35
local PanelBounds = { x = 0, y = 0, w = 0, h = 0 }

local function ToggleMusic()
	Audio:PlaySound("click")
	Settings.MuteMusic = not Settings.MuteMusic
	Settings:save()
	Audio:ApplyVolumes()
end

local function ToggleSFX()
	Audio:PlaySound("click")
	Settings.MuteSFX = not Settings.MuteSFX
	Settings:save()
	Audio:ApplyVolumes()
end

local BaseButtons = {
	{ TextKey = "pause.resume",       id = "PauseResume", action = "resume" },
	{ id = "PauseToggleMusic", action = ToggleMusic },
	{ id = "PauseToggleSFX",   action = ToggleSFX },
	{ TextKey = "pause.quit", id = "PauseQuit",   action = "menu" },
}

local ButtonList = ButtonList.new()
local AnalogAxisDirections = { horizontal = nil, vertical = nil }

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

local function ResetAnalogAxis()
	AnalogAxisDirections.horizontal = nil
	AnalogAxisDirections.vertical = nil
end

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

local function GetToggleLabel(id)
	if id == "PauseToggleMusic" then
		local state = Settings.MuteMusic and Localization:get("common.off") or Localization:get("common.on")
		return Localization:get("pause.toggle_music", { state = state })
	elseif id == "PauseToggleSFX" then
		local state = Settings.MuteSFX and Localization:get("common.off") or Localization:get("common.on")
		return Localization:get("pause.toggle_sfx", { state = state })
	end

	return nil
end

function PauseMenu:UpdateButtonLabels()
	for _, button in ButtonList:iter() do
		if button.textKey then
			button.text = Localization:get(button.textKey)
		end
		local label = GetToggleLabel(button.id)
		if label then
			button.text = label
		end
	end
end

function PauseMenu:load(ScreenWidth, ScreenHeight)
	UI.ClearButtons()

	ResetAnalogAxis()

	local CenterX = ScreenWidth / 2
	local CenterY = ScreenHeight / 2
	local ButtonWidth = UI.spacing.ButtonWidth
	local ButtonHeight = UI.spacing.ButtonHeight
	local spacing = UI.spacing.ButtonSpacing
	local count = #BaseButtons

	local TitleHeight = UI.fonts.subtitle:GetHeight()
	local HeaderSpacing = UI.spacing.SectionSpacing * 0.5
	local ButtonArea = count * ButtonHeight + math.max(0, count - 1) * spacing
	local PanelPadding = UI.spacing.PanelPadding
	local PanelWidth = ButtonWidth + PanelPadding * 2
	local PanelHeight = PanelPadding + TitleHeight + HeaderSpacing + ButtonArea + PanelPadding

	local PanelX = CenterX - PanelWidth / 2
	local PanelY = CenterY - PanelHeight / 2

	PanelBounds = { x = PanelX, y = PanelY, w = PanelWidth, h = PanelHeight }

	local defs = {}

	local StartY = PanelY + PanelPadding + TitleHeight + HeaderSpacing

	for index, btn in ipairs(BaseButtons) do
		defs[#defs + 1] = {
			id = btn.id,
			TextKey = btn.textKey,
			BaseText = btn.textKey and Localization:get(btn.textKey) or "",
			text = GetToggleLabel(btn.id) or BaseText,
			action = btn.action,
			x = PanelX + PanelPadding,
			y = StartY + (index - 1) * (ButtonHeight + spacing),
			w = ButtonWidth,
			h = ButtonHeight,
		}
	end

	ButtonList:reset(defs)
	self:UpdateButtonLabels()
	alpha = 0
end

local function RefreshFloorLabel(FloorNumber, FloorName)
	if not FloorNumber then
		return
	end

	local ResolvedName = FloorName
	if not ResolvedName or ResolvedName == "" then
		ResolvedName = Localization:get("common.unknown")
	end

	CurrentFloorLabel = Localization:get("pause.floor_label", {
		number = FloorNumber,
		name = ResolvedName,
	})
end

function PauseMenu:update(dt, IsPaused, FloorNumber, FloorName)
	if IsPaused then
		alpha = math.min(alpha + dt * FadeSpeed, 1)
	else
		alpha = math.max(alpha - dt * FadeSpeed, 0)
	end

	if alpha > 0 then
		local mx, my = love.mouse.getPosition()
		ButtonList:updateHover(mx, my)
	end

	if FloorNumber then
		RefreshFloorLabel(FloorNumber, FloorName)
	end

	self:UpdateButtonLabels()
end

function PauseMenu:draw(ScreenWidth, ScreenHeight)
	if alpha <= 0 then return end

	love.graphics.setColor(0, 0, 0, 0.55 * alpha)
	love.graphics.rectangle("fill", 0, 0, ScreenWidth, ScreenHeight)

	if CurrentFloorLabel then
		UI.DrawLabel(CurrentFloorLabel, 0, UI.spacing.PanelPadding, ScreenWidth, "center", {
			FontKey = "subtitle",
			alpha = alpha,
		})
	end

	local panel = PanelBounds
	if panel and panel.w > 0 and panel.h > 0 then
		local PanelFill = { Theme.PanelColor[1], Theme.PanelColor[2], Theme.PanelColor[3], (Theme.PanelColor[4] or 1) * alpha }
		local PanelBorder = { Theme.PanelBorder[1], Theme.PanelBorder[2], Theme.PanelBorder[3], (Theme.PanelBorder[4] or 1) * alpha }

		UI.DrawPanel(panel.x, panel.y, panel.w, panel.h, {
			fill = PanelFill,
			BorderColor = PanelBorder,
			ShadowAlpha = alpha,
		})

		UI.DrawLabel(Localization:get("pause.title"), panel.x, panel.y + UI.spacing.PanelPadding, panel.w, "center", {
			FontKey = "subtitle",
			alpha = alpha,
		})
	end

	ButtonList:draw()
end

function PauseMenu:mousepressed(x, y, button)
	ButtonList:mousepressed(x, y, button)
end

function PauseMenu:mousereleased(x, y, button)
	local action, entry = ButtonList:mousereleased(x, y, button)

	if type(action) == "function" then
		action()
		self:UpdateButtonLabels()
		return nil
	end

	if entry and GetToggleLabel(entry.id) then
		self:UpdateButtonLabels()
	end

	return action
end

local function HandleActionResult(action, entry)
	if type(action) == "function" then
		action()
		if entry then
			return nil, true
		end
		return nil, true
	end

	return action, entry and GetToggleLabel(entry.id) ~= nil
end

function PauseMenu:ActivateFocused()
	local action, entry = ButtonList:activateFocused()
	if not entry and not action then return nil end

	local resolved, RequiresRefresh = HandleActionResult(action, entry)
	if RequiresRefresh then
		self:UpdateButtonLabels()
	end

	return resolved
end

function PauseMenu:keypressed(key)
	if key == "up" or key == "left" then
		ButtonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		ButtonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return self:ActivateFocused()
	elseif key == "escape" or key == "backspace" then
		return "resume"
	end
end

function PauseMenu:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		ButtonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		ButtonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return self:ActivateFocused()
	elseif button == "b" then
		return "resume"
	end
end

PauseMenu.joystickpressed = PauseMenu.gamepadpressed

function PauseMenu:gamepadaxis(_, axis, value)
	HandleAnalogAxis(axis, value)
end

PauseMenu.joystickaxis = PauseMenu.gamepadaxis

return PauseMenu
