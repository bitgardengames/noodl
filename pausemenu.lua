local Audio = require("audio")
local Settings = require("settings")
local Localization = require("localization")
local UI = require("ui")
local Theme = require("theme")

local max = math.max
local min = math.min

local PauseMenu = {}

local alpha = 0
local fadeSpeed = 4

local currentFloorLabel = nil

local ButtonList = require("buttonlist")
local ANALOG_DEADZONE = 0.3
local panelBounds = {x = 0, y = 0, w = 0, h = 0}
local panelFillColor = {0, 0, 0, 1}
local panelBorderColor = {0, 0, 0, 1}
local panelDrawOptions = {fill = panelFillColor, borderColor = panelBorderColor, borderWidth = 3, shadowAlpha = 1}
local subtitleLabelOptions = {fontKey = "subtitle", alpha = 1}
local toggleLabelArgs = {state = nil}
local floorLabelArgs = {number = nil, name = nil}

local function toggleMusic()
	Audio:playSound("click")
	Settings.muteMusic = not Settings.muteMusic
	Settings:save()
	Audio:applyVolumes()
end

local function toggleSFX()
	Audio:playSound("click")
	Settings.muteSFX = not Settings.muteSFX
	Settings:save()
	Audio:applyVolumes()
end

local baseButtons = {
	{textKey = "pause.resume",       id = "pauseResume", action = "resume"},
	{id = "pauseToggleMusic", action = toggleMusic},
	{id = "pauseToggleSFX",   action = toggleSFX},
	{textKey = "pause.quit", id = "pauseQuit",   action = "menu"},
}

local buttonList = ButtonList.new()
local analogAxisDirections = {horizontal = nil, vertical = nil}

local analogAxisActions = {
	horizontal = {
		negative = function()
			buttonList:moveFocus(-1)
		end,
		positive = function()
			buttonList:moveFocus(1)
		end,
	},
	vertical = {
		negative = function()
			buttonList:moveFocus(-1)
		end,
		positive = function()
			buttonList:moveFocus(1)
		end,
	},
}

local analogAxisMap = {
	leftx = {slot = "horizontal"},
	rightx = {slot = "horizontal"},
	lefty = {slot = "vertical"},
	righty = {slot = "vertical"},
	[1] = {slot = "horizontal"},
	[2] = {slot = "vertical"},
}

local function resetAnalogAxis()
	analogAxisDirections.horizontal = nil
	analogAxisDirections.vertical = nil
end

local function handleAnalogAxis(axis, value)
	local mapping = analogAxisMap[axis]
	if not mapping then
		return
	end

	local direction
	if value >= ANALOG_DEADZONE then
		direction = "positive"
	elseif value <= -ANALOG_DEADZONE then
		direction = "negative"
	end

	if analogAxisDirections[mapping.slot] == direction then
		return
	end

	analogAxisDirections[mapping.slot] = direction

	if direction then
		local actions = analogAxisActions[mapping.slot]
		local action = actions and actions[direction]
		if action then
			action()
		end
	end
end

local function getToggleLabel(id)
	if id == "pauseToggleMusic" then
		local state = Settings.muteMusic and Localization:get("common.off") or Localization:get("common.on")
		toggleLabelArgs.state = state
		local label = Localization:get("pause.toggle_music", toggleLabelArgs)
		toggleLabelArgs.state = nil
		return label
	elseif id == "pauseToggleSFX" then
		local state = Settings.muteSFX and Localization:get("common.off") or Localization:get("common.on")
		toggleLabelArgs.state = state
		local label = Localization:get("pause.toggle_sfx", toggleLabelArgs)
		toggleLabelArgs.state = nil
		return label
	end

	return nil
end

function PauseMenu:updateButtonLabels()
	for _, button in buttonList:iter() do
		if button.textKey then
			button.text = Localization:get(button.textKey)
		end
		local label = getToggleLabel(button.id)
		if label then
			button.text = label
		end
	end
end

function PauseMenu:load(screenWidth, screenHeight)
	UI.clearButtons()

	resetAnalogAxis()

	local centerX = screenWidth / 2
	local centerY = screenHeight / 2
	local menuLayout = UI.getMenuLayout(screenWidth, screenHeight)
	local buttonWidth = UI.spacing.buttonWidth
	local buttonHeight = UI.spacing.buttonHeight
	local spacing = UI.spacing.buttonSpacing
	local count = #baseButtons

	local titleHeight = UI.fonts.subtitle:getHeight()
	local headerSpacing = UI.spacing.sectionSpacing * 0.5
	local buttonArea = count * buttonHeight + max(0, count - 1) * spacing
	local panelPadding = UI.spacing.panelPadding
	local panelWidth = buttonWidth + panelPadding * 2
	local panelHeight = panelPadding + titleHeight + headerSpacing + buttonArea + panelPadding

	local panelX = centerX - panelWidth / 2
	local panelY = centerY - panelHeight / 2
	local topMargin = menuLayout.marginTop or UI.spacing.sectionSpacing
	local bottomMargin = menuLayout.marginBottom or topMargin
	local minPanelY = topMargin
	local maxPanelY = (menuLayout.bottomY or (screenHeight - bottomMargin)) - panelHeight
	if maxPanelY < minPanelY then
		panelY = minPanelY
	else
		panelY = min(max(panelY, minPanelY), maxPanelY)
	end

	panelBounds.x = panelX
	panelBounds.y = panelY
	panelBounds.w = panelWidth
	panelBounds.h = panelHeight

	local defs = {}

	local startY = panelY + panelPadding + titleHeight + headerSpacing

	for index, btn in ipairs(baseButtons) do
		defs[#defs + 1] = {
			id = btn.id,
			textKey = btn.textKey,
			baseText = btn.textKey and Localization:get(btn.textKey) or "",
			text = getToggleLabel(btn.id) or baseText,
			action = btn.action,
			x = panelX + panelPadding,
			y = startY + (index - 1) * (buttonHeight + spacing),
			w = buttonWidth,
			h = buttonHeight,
		}
	end

	buttonList:reset(defs)
	self:updateButtonLabels()
	alpha = 0
end

local function refreshFloorLabel(floorNumber, floorName)
	if not floorNumber then
		return
	end

	local resolvedName = floorName
	if not resolvedName or resolvedName == "" then
		resolvedName = Localization:get("common.unknown")
	end

	floorLabelArgs.number = floorNumber
	floorLabelArgs.name = resolvedName
	currentFloorLabel = Localization:get("pause.floor_label", floorLabelArgs)
end

function PauseMenu:update(dt, isPaused, floorNumber, floorName)
	if isPaused then
		alpha = math.min(alpha + dt * fadeSpeed, 1)
	else
		alpha = max(alpha - dt * fadeSpeed, 0)
	end

	if alpha > 0 then
		local mx, my = love.mouse.getPosition()
		buttonList:updateHover(mx, my)
	end

	if floorNumber then
		refreshFloorLabel(floorNumber, floorName)
	end

	self:updateButtonLabels()
end

function PauseMenu:draw(screenWidth, screenHeight)
	if alpha <= 0 then return end

	love.graphics.setColor(0, 0, 0, 0.55 * alpha)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

	local menuLayout = UI.getMenuLayout(screenWidth, screenHeight)
	if currentFloorLabel then
		subtitleLabelOptions.alpha = alpha
		local topLabelY = menuLayout.marginTop or UI.spacing.panelPadding
		UI.drawLabel(currentFloorLabel, 0, topLabelY, screenWidth, "center", subtitleLabelOptions)
	end

	local panel = panelBounds
	if panel and panel.w > 0 and panel.h > 0 then
		panelFillColor[1] = Theme.panelColor[1]
		panelFillColor[2] = Theme.panelColor[2]
		panelFillColor[3] = Theme.panelColor[3]
		panelFillColor[4] = (Theme.panelColor[4] or 1) * alpha

		panelBorderColor[1] = 0
		panelBorderColor[2] = 0
		panelBorderColor[3] = 0
		panelBorderColor[4] = alpha

		panelDrawOptions.shadowAlpha = alpha

		UI.drawPanel(panel.x, panel.y, panel.w, panel.h, panelDrawOptions)

		subtitleLabelOptions.alpha = alpha
		UI.drawLabel(Localization:get("pause.title"), panel.x, panel.y + UI.spacing.panelPadding, panel.w, "center", subtitleLabelOptions)
	end

	buttonList:draw()
end

function PauseMenu:mousepressed(x, y, button)
	buttonList:mousepressed(x, y, button)
end

function PauseMenu:mousereleased(x, y, button)
	local action, entry = buttonList:mousereleased(x, y, button)

	if type(action) == "function" then
		action()
		self:updateButtonLabels()
		return nil
	end

	if entry and getToggleLabel(entry.id) then
		self:updateButtonLabels()
	end

	return action
end

local function handleActionResult(action, entry)
	if type(action) == "function" then
		action()
		if entry then
			return nil, true
		end
		return nil, true
	end

	return action, entry and getToggleLabel(entry.id) ~= nil
end

function PauseMenu:activateFocused()
	local action, entry = buttonList:activateFocused()
	if not entry and not action then return nil end

	local resolved, requiresRefresh = handleActionResult(action, entry)
	if requiresRefresh then
		self:updateButtonLabels()
	end

	return resolved
end

function PauseMenu:keypressed(key)
	if key == "up" or key == "left" then
		buttonList:moveFocus(-1)
	elseif key == "down" or key == "right" then
		buttonList:moveFocus(1)
	elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
		return self:activateFocused()
	elseif key == "escape" or key == "backspace" then
		return "resume"
	end
end

function PauseMenu:gamepadpressed(_, button)
	if button == "dpup" or button == "dpleft" then
		buttonList:moveFocus(-1)
	elseif button == "dpdown" or button == "dpright" then
		buttonList:moveFocus(1)
	elseif button == "a" or button == "start" then
		return self:activateFocused()
	elseif button == "b" then
		return "resume"
	end
end

PauseMenu.joystickpressed = PauseMenu.gamepadpressed

function PauseMenu:gamepadaxis(_, axis, value)
	handleAnalogAxis(axis, value)
end

PauseMenu.joystickaxis = PauseMenu.gamepadaxis

return PauseMenu
