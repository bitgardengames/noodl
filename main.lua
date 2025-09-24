local GameState = require("gamestate")
local Menu = require("menu")
local ModeSelect = require("modeselect")
local Game = require("game")
local GameOver = require("gameover")
local GameModes = require("gamemodes")
local AchievementsMenu = require("achievementsmenu")
local Achievements = require("achievements")
local Settings = require("settings")
local SettingsScreen = require("settingsscreen")
local Audio = require("audio")
local Screen = require("screen")
local Score = require("score")
local PlayerStats = require("playerstats")
local UI = require("ui")

-- Register states
GameState.states.menu = Menu
GameState.states.modeselect = ModeSelect
GameState.states.game = Game
GameState.states.gameover = GameOver
GameState.states.achievementsmenu = AchievementsMenu
GameState.states.settings = SettingsScreen

function love.load()
	love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop"})

	Screen:update()
	Settings:load()
	Audio:load()
	Achievements:load()
	Score:load()
	PlayerStats:load()
	GameModes:loadUnlocks()
    GameState:switch("menu")

	--[[for _, joystick in ipairs(love.joystick.getJoysticks()) do
		print("Joystick found:", joystick:getName(), joystick:isGamepad() and "(Gamepad)" or "(Joystick)")
	end]]
end

function love.update(dt)
	GameState:update(dt)
	UI:update(dt)
end

function love.draw()
	GameState:draw()
end

local function handleAction(action)
	if action == "quit" then
		love.event.quit()
	elseif action then
		GameState:switch(action)
	end
end

function love.mousepressed(x, y, button)
	handleAction(GameState:mousepressed(x, y, button))
end

function love.mousereleased(x, y, button)
	handleAction(GameState:mousereleased(x, y, button))
end

function love.keypressed(key)
	if key == "printscreen" then
		local time = os.date("%Y-%m-%d_%H-%M-%S")
		love.graphics.captureScreenshot("screenshot_" .. time .. ".png")
	end

	handleAction(GameState:keypressed(key))
end

function love.joystickpressed(joystick, button)
	handleAction(GameState:joystickpressed(joystick, button))
end

function love.joystickreleased(joystick, button)
	GameState:joystickreleased(joystick, button)
end

function love.gamepadpressed(joystick, button)
	handleAction(GameState:gamepadpressed(joystick, button))
end

function love.gamepadreleased(joystick, button)
	GameState:gamepadreleased(joystick, button)
end

function love.resize(w, h)
	Screen:update()
end