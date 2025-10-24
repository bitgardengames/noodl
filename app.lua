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

local DEFAULT_BG_COLOR = {0, 0, 0, 1}

local App = {
	stateModules = {
		splash = require("splashscreen"),
                menu = require("menu"),
                game = require("game"),
                gameover = require("gameover"),
                achievementsmenu = require("achievementsmenu"),
                metaprogression = require("metaprogressionscreen"),
                settings = require("settingsscreen"),
        }
}

function App:registerStates()
	local states = {}
	for stateName, module in pairs(self.stateModules) do
		states[stateName] = module
	end
	GameState.states = states
end

function App:loadSubsystems()
	Screen:update()
	Localization:setLanguage(Settings.language)
	Audio:load()
	Achievements:load()
	Score:load()
	PlayerStats:load()
	local metaState = MetaProgression:getState() or {}
	SnakeCosmetics:load({
		metaLevel = metaState.level or 1,
	})
end

function App:resolveAction(action)
	if not action then return end

	if type(action) == "table" then
		local stateName = action.state
		if stateName and GameState.states[stateName] then
			GameState:switch(stateName, action.data)
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

	self:registerStates()
	self:loadSubsystems()

	GameState:switch("splash")
end

function App:forwardEvent(eventName, ...)
	local result = GameState:dispatch(eventName, ...)
	self:resolveAction(result)

	return result
end

function App:update(dt)
	Screen:update(dt)
	local action = GameState:update(dt)
	self:resolveAction(action)
	UI:update(dt)
end

function App:draw()
        local bg = Theme.bgColor or DEFAULT_BG_COLOR
	local r = bg[1] or 0
	local g = bg[2] or 0
	local b = bg[3] or 0
	local a = bg[4] or 1
	love.graphics.clear(r, g, b, a)
	love.graphics.setColor(1, 1, 1, 1)

	GameState:draw()

	if Settings.showFPS then
		local fps = love.timer.getFPS()
		local label = string.format("FPS: %d", fps)
		local padding = 6

                UI.setFont("caption")

		local font = love.graphics.getFont()
		local textWidth = font and font:getWidth(label) or 0
		local textHeight = font and font:getHeight() or 14
		local boxWidth = textWidth + padding * 2
		local boxHeight = textHeight + padding * 2
		local x = 12
		local y = 12

		love.graphics.setColor(0, 0, 0, 0.6)
		love.graphics.rectangle("fill", x, y, boxWidth, boxHeight, 6, 6)
		love.graphics.setColor(1, 1, 1, 0.95)
		love.graphics.print(label, x + padding, y + padding)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function App:keypressed(key)
	InputMode:noteKeyboard()
	if key == "printscreen" then
		local time = os.date("%Y-%m-%d_%H-%M-%S")
		love.graphics.captureScreenshot("screenshot_" .. time .. ".png")
	end

	return self:forwardEvent("keypressed", key)
end

function App:resize()
	Screen:update()
end

local function createEventForwarder(eventName, preHook)
	return function(self, ...)
		if preHook then
			preHook(...)
		end
		return self:forwardEvent(eventName, ...)
	end
end

local eventForwarders = {
	mousepressed = function()
		InputMode:noteMouse()
	end,
	mousereleased = function()
		InputMode:noteMouse()
	end,
	mousemoved = function()
		InputMode:noteMouse()
	end,
	wheelmoved = function()
		InputMode:noteMouse()
	end,
	joystickpressed = function()
		InputMode:noteGamepad()
	end,
	joystickaxis = function(_, _, value)
		InputMode:noteGamepadAxis(value)
	end,
	gamepadpressed = function()
		InputMode:noteGamepad()
	end,
	gamepadaxis = function(_, _, value)
		InputMode:noteGamepadAxis(value)
	end,
}

local passthroughEvents = {
	joystickreleased = true,
	gamepadreleased = true,
}

for eventName, hook in pairs(eventForwarders) do
	App[eventName] = createEventForwarder(eventName, hook)
end

for eventName in pairs(passthroughEvents) do
	App[eventName] = createEventForwarder(eventName)
end

return App
