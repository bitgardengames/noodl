local GameState = require("gamestate")
local Screen = require("screen")
local Settings = require("settings")
local Display = require("display")
local Audio = require("audio")
local Achievements = require("achievements")
local MetaProgression = require("metaprogression")
local Score = require("score")
local PlayerStats = require("playerstats")
local UI = require("ui")
local Localization = require("localization")
local Theme = require("theme")
local SnakeCosmetics = require("snakecosmetics")
local InputMode = require("inputmode")

local App = {
	StateModules = {
		splash = require("splashscreen"),
		menu = require("menu"),
		game = require("game"),
		gameover = require("gameover"),
		achievementsmenu = require("achievementsmenu"),
		floorselect = require("floorselectscreen"),
		metaprogression = require("metaprogressionscreen"),
		settings = require("settingsscreen"),
		dev = require("devscreen"),
	}
}

function App:RegisterStates()
	local states = {}
	for StateName, module in pairs(self.StateModules) do
		states[StateName] = module
	end
	GameState.states = states
end

function App:LoadSubsystems()
	Screen:update()
	Localization:SetLanguage(Settings.language)
	Audio:load()
	Achievements:load()
	Score:load()
	PlayerStats:load()
	local MetaState = MetaProgression:GetState() or {}
	SnakeCosmetics:load({
		MetaLevel = MetaState.level or 1,
	})
end

function App:ResolveAction(action)
	if not action then return end

	if type(action) == "table" then
		local StateName = action.state
		if StateName and GameState.states[StateName] then
			GameState:switch(StateName, action.data)
		end
		return
	end

	if type(action) ~= "string" then return end

	if action == "quit" then
		love.event.quit()
		return
	end

	if GameState.states[action] then
		GameState:switch(action)
	end
end

function App:load()
	Settings:load()
	Display.apply(Settings)

	self:RegisterStates()
	self:LoadSubsystems()

	GameState:switch("splash")
end

function App:ForwardEvent(EventName, ...)
	local result = GameState:dispatch(EventName, ...)
	self:ResolveAction(result)

	return result
end

function App:update(dt)
	Screen:update(dt)
	local action = GameState:update(dt)
	self:ResolveAction(action)
	UI:update(dt)
end

function App:draw()
	local bg = Theme.BgColor or {0, 0, 0, 1}
	local r = bg[1] or 0
	local g = bg[2] or 0
	local b = bg[3] or 0
	local a = bg[4] or 1
	love.graphics.clear(r, g, b, a)
	love.graphics.setColor(1, 1, 1, 1)

	GameState:draw()

        if Settings.ShowFPS then
                local fps = love.timer.getFPS()
		local label = string.format("FPS: %d", fps)
		local padding = 6

		if UI.SetFont then
			UI.SetFont("caption")
		end

		local font = love.graphics.getFont()
		local TextWidth = font and font:getWidth(label) or 0
		local TextHeight = font and font:getHeight() or 14
		local BoxWidth = TextWidth + padding * 2
		local BoxHeight = TextHeight + padding * 2
		local x = 12
		local y = 12

		love.graphics.setColor(0, 0, 0, 0.6)
		love.graphics.rectangle("fill", x, y, BoxWidth, BoxHeight, 6, 6)
		love.graphics.setColor(1, 1, 1, 0.95)
		love.graphics.print(label, x + padding, y + padding)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function App:keypressed(key)
	InputMode:NoteKeyboard()
	if key == "printscreen" then
		local time = os.date("%Y-%m-%d_%H-%M-%S")
		love.graphics.captureScreenshot("screenshot_" .. time .. ".png")
	end

	return self:ForwardEvent("keypressed", key)
end

function App:resize()
	Screen:update()
end

local function CreateEventForwarder(EventName, PreHook)
	return function(self, ...)
		if PreHook then
			PreHook(...)
		end
		return self:ForwardEvent(EventName, ...)
	end
end

local EventForwarders = {
	mousepressed = function()
		InputMode:NoteMouse()
	end,
	mousereleased = function()
		InputMode:NoteMouse()
	end,
	mousemoved = function()
		InputMode:NoteMouse()
	end,
	wheelmoved = function()
		InputMode:NoteMouse()
	end,
	joystickpressed = function()
		InputMode:NoteGamepad()
	end,
	joystickaxis = function(_, _, value)
		InputMode:NoteGamepadAxis(value)
	end,
	gamepadpressed = function()
		InputMode:NoteGamepad()
	end,
	gamepadaxis = function(_, _, value)
		InputMode:NoteGamepadAxis(value)
	end,
}

local PassthroughEvents = {
	joystickreleased = true,
	gamepadreleased = true,
}

for EventName, hook in pairs(EventForwarders) do
	App[EventName] = CreateEventForwarder(EventName, hook)
end

for EventName in pairs(PassthroughEvents) do
	App[EventName] = CreateEventForwarder(EventName)
end

return App
