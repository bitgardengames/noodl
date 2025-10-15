local Snake = require("snake")

local Controls = {}

local GameplayKeyHandlers = {
	up = function()
		Snake:SetDirection("up")
	end,
	down = function()
		Snake:SetDirection("down")
	end,
	left = function()
		Snake:SetDirection("left")
	end,
	right = function()
		Snake:SetDirection("right")
	end,
	space = function()
		Snake:ActivateDash()
	end,
	lshift = function()
		Snake:ActivateTimeDilation()
	end,
	rshift = function()
		Snake:ActivateTimeDilation()
	end,
	f1 = function()
		if Snake.ToggleDeveloperAssist then
			Snake:ToggleDeveloperAssist()
		end
	end,
}

local function TogglePause(game)
	if game.state == "paused" then
		game.state = "playing"
	else
		game.state = "paused"
	end
end

function Controls:keypressed(game, key)
	if key == "escape" and game.state ~= "gameover" then
		TogglePause(game)
		return
	end

	if game.state ~= "playing" then
		return
	end

	local handler = GameplayKeyHandlers[key]
	if handler then
		handler()
	end
end

return Controls
