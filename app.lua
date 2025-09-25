local GameState = require("gamestate")
local Screen = require("screen")
local Settings = require("settings")
local Audio = require("audio")
local Achievements = require("achievements")
local Score = require("score")
local PlayerStats = require("playerstats")
local GameModes = require("gamemodes")
local UI = require("ui")
local Localization = require("localization")

local App = {
    stateModules = {
        menu = "menu",
        modeselect = "modeselect",
        game = "game",
        gameover = "gameover",
        achievementsmenu = "achievementsmenu",
        settings = "settingsscreen",
    }
}

local function clearStates()
    for key in pairs(GameState.states) do
        GameState.states[key] = nil
    end
end

function App:registerStates()
    clearStates()

    for stateName, modulePath in pairs(self.stateModules) do
        GameState.states[stateName] = require(modulePath)
    end
end

function App:loadSubsystems()
    Screen:update()
    Settings:load()
    Localization:setLanguage(Settings.language)
    Audio:load()
    Achievements:load()
    Score:load()
    PlayerStats:load()
    GameModes:loadUnlocks()
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

function App:dispatch(eventName, ...)
    local handler = GameState[eventName]
    if not handler then return end

    local result = handler(GameState, ...)
    self:resolveAction(result)

    return result
end

function App:load()
    love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop"})

    self:registerStates()
    self:loadSubsystems()
    GameState:switch("menu")
end

function App:update(dt)
    local action = GameState:update(dt)
    self:resolveAction(action)
    UI:update(dt)
end

function App:draw()
    GameState:draw()
end

function App:mousepressed(x, y, button)
    return self:dispatch("mousepressed", x, y, button)
end

function App:mousereleased(x, y, button)
    return self:dispatch("mousereleased", x, y, button)
end

function App:keypressed(key)
    if key == "printscreen" then
        local time = os.date("%Y-%m-%d_%H-%M-%S")
        love.graphics.captureScreenshot("screenshot_" .. time .. ".png")
    end

    return self:dispatch("keypressed", key)
end

function App:joystickpressed(joystick, button)
    return self:dispatch("joystickpressed", joystick, button)
end

function App:joystickreleased(joystick, button)
    return self:dispatch("joystickreleased", joystick, button)
end

function App:gamepadpressed(joystick, button)
    return self:dispatch("gamepadpressed", joystick, button)
end

function App:gamepadreleased(joystick, button)
    return self:dispatch("gamepadreleased", joystick, button)
end

function App:resize()
    Screen:update()
end

return App
