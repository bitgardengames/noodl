local Controls = require("controls")
local PauseMenu = require("pausemenu")
local Shop = require("shop")
local Achievements = require("achievements")

local GameInput = {}
GameInput.__index = GameInput

local DirectionButtonMap = { dpleft = "left", dpright = "right", dpup = "up", dpdown = "down" }
local ANALOG_DEADZONE = 0.5
local AxisButtonMap = {
	leftx = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
	rightx = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
	lefty = { slot = "vertical", negative = "dpup", positive = "dpdown" },
	righty = { slot = "vertical", negative = "dpup", positive = "dpdown" },
	[1] = { slot = "horizontal", negative = "dpleft", positive = "dpright" },
	[2] = { slot = "vertical", negative = "dpup", positive = "dpdown" },
}

local ButtonAliases = {
	a = "dash",
	rightshoulder = "dash",
	righttrigger = "dash",
	x = "slow",
	leftshoulder = "slow",
	lefttrigger = "slow",
}

local PlayingButtonHandlers = {
	start = function(game)
		if game.state == "playing" then
			game.state = "paused"
		end
	end,
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

local function ResolvePlayingAction(button)
	return ButtonAliases[button] or button
end

function GameInput.new(game, transition)
	return setmetatable({
		game = game,
		transition = transition,
		AxisState = { horizontal = nil, vertical = nil },
	}, GameInput)
end

function GameInput:ResetAxes()
	self.AxisState.horizontal = nil
	self.AxisState.vertical = nil
end

function GameInput:ApplyPauseMenuSelection(selection)
	if selection == "resume" then
		self.game.state = "playing"
	elseif selection == "menu" then
		Achievements:save()
		return "menu"
	end
end

function GameInput:HandlePauseMenuInput(button)
	if button == "start" then
		return self:ApplyPauseMenuSelection("resume")
	end

	local action = PauseMenu:gamepadpressed(nil, button)
	if action then
		return self:ApplyPauseMenuSelection(action)
	end
end

function GameInput:HandlePlayingButton(button)
	local direction = DirectionButtonMap[button]
	if direction then
		Controls:keypressed(self.game, direction)
		return
	end

	local handler = PlayingButtonHandlers[ResolvePlayingAction(button)]
	if handler then
		return handler(self.game)
	end
end

function GameInput:HandleGamepadButton(button)
	if self.transition:HandleShopInput("gamepadpressed", nil, button) then
		return
	end

	if self.game.state == "paused" then
		return self:HandlePauseMenuInput(button)
	end

	return self:HandlePlayingButton(button)
end

function GameInput:HandleGamepadAxis(axis, value)
	if self.transition:IsShopActive() and Shop.gamepadaxis then
		Shop:gamepadaxis(nil, axis, value)
	end

	local config = AxisButtonMap[axis]
	if not config then
		return
	end

	local state = self.AxisState
	local direction
	if value >= ANALOG_DEADZONE then
		direction = config.positive
	elseif value <= -ANALOG_DEADZONE then
		direction = config.negative
	end

	if state[config.slot] ~= direction then
		state[config.slot] = direction
		if direction then
			self:HandleGamepadButton(direction)
		end
	end
end

function GameInput:HandleShopInput(MethodName, ...)
	return self.transition:HandleShopInput(MethodName, ...)
end

return GameInput
