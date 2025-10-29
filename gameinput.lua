local Controls = require("controls")
local PauseMenu = require("pausemenu")
local Shop = require("shop")
local Achievements = require("achievements")

local GameInput = {}
GameInput.__index = GameInput

local directionButtonMap = {dpleft = "left", dpright = "right", dpup = "up", dpdown = "down"}
local ANALOG_DEADZONE = 0.3
local axisButtonMap = {
	leftx = {slot = "horizontal", negative = "dpleft", positive = "dpright"},
	rightx = {slot = "horizontal", negative = "dpleft", positive = "dpright"},
	lefty = {slot = "vertical", negative = "dpup", positive = "dpdown"},
	righty = {slot = "vertical", negative = "dpup", positive = "dpdown"},
	[1] = {slot = "horizontal", negative = "dpleft", positive = "dpright"},
	[2] = {slot = "vertical", negative = "dpup", positive = "dpdown"},
}

local buttonAliases = {
	a = "dash",
	rightshoulder = "dash",
	righttrigger = "dash",
	x = "slow",
	leftshoulder = "slow",
	lefttrigger = "slow",
}

local playingButtonHandlers = {
	dash = function(game)
		if game.state == "playing" then
			Controls:keypressed(game, "space")
		end
	end,
	slow = function(game)
		if game.state == "playing" then
			Controls:keypressed(game, "lshift")
		end
	end,
}

local function resolvePlayingAction(button)
	return buttonAliases[button] or button
end

function GameInput.new(game, transition)
	return setmetatable({
		game = game,
		transition = transition,
		axisState = {horizontal = nil, vertical = nil},
	}, GameInput)
end

function GameInput:resetAxes()
	self.axisState.horizontal = nil
	self.axisState.vertical = nil
end

function GameInput:applyPauseMenuSelection(selection)
	if selection == "resume" then
		self.game:exitPause()
	elseif selection == "menu" then
		self.game:exitPause()
		Achievements:save()
		return "menu"
	end
end

function GameInput:handlePauseMenuInput(button)
	if button == "start" then
		return self:applyPauseMenuSelection("resume")
	end

	local action = PauseMenu:gamepadpressed(nil, button)
	if action then
		return self:applyPauseMenuSelection(action)
	end
end

function GameInput:handlePlayingButton(button)
	local direction = directionButtonMap[button]
	if direction then
		Controls:keypressed(self.game, direction)
		return
	end

	local handler = playingButtonHandlers[resolvePlayingAction(button)]
	if handler then
		return handler(self.game)
	end
end

function GameInput:handleGamepadButton(button)
	if self.game.state == "paused" then
		return self:handlePauseMenuInput(button)
	end

	if button == "start" then
		self.game:enterPause()
		return
	end

	if self.transition:handleShopInput("gamepadpressed", nil, button) then
		return
	end

	return self:handlePlayingButton(button)
end

function GameInput:handleGamepadAxis(axis, value)
	if self.game.state == "paused" then
		if PauseMenu.gamepadaxis then
			PauseMenu:gamepadaxis(nil, axis, value)
		end
		return
	end

	if self.transition:isShopActive() and Shop.gamepadaxis then
		Shop:gamepadaxis(nil, axis, value)
	end

	local config = axisButtonMap[axis]
	if not config then
		return
	end

	local state = self.axisState
	local direction
	if value >= ANALOG_DEADZONE then
		direction = config.positive
	elseif value <= -ANALOG_DEADZONE then
		direction = config.negative
	end

	if state[config.slot] ~= direction then
		state[config.slot] = direction
		if direction then
			self:handleGamepadButton(direction)
		end
	end
end

function GameInput:handleShopInput(methodName, ...)
	return self.transition:handleShopInput(methodName, ...)
end

return GameInput
