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
local DebugOverlay = require("debugoverlay")

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

function App:load()
    love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop"})

    self:registerStates()
    self:loadSubsystems()
    DebugOverlay:load()
    GameState:switch("menu")
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
    DebugOverlay:update(dt)
end

function App:draw()
    GameState:draw()
    DebugOverlay:draw()
end

function App:mousepressed(x, y, button)
    return self:forwardEvent("mousepressed", x, y, button)
end

function App:mousereleased(x, y, button)
    return self:forwardEvent("mousereleased", x, y, button)
end

function App:wheelmoved(dx, dy)
    return self:forwardEvent("wheelmoved", dx, dy)
end

function App:keypressed(key)
    if key == "printscreen" then
        local time = os.date("%Y-%m-%d_%H-%M-%S")
        love.graphics.captureScreenshot("screenshot_" .. time .. ".png")
    end

    DebugOverlay:keypressed(key)
    return self:forwardEvent("keypressed", key)
end

function App:joystickpressed(joystick, button)
    return self:forwardEvent("joystickpressed", joystick, button)
end

function App:joystickreleased(joystick, button)
    return self:forwardEvent("joystickreleased", joystick, button)
end

function App:gamepadpressed(joystick, button)
    return self:forwardEvent("gamepadpressed", joystick, button)
end

function App:gamepadreleased(joystick, button)
    return self:forwardEvent("gamepadreleased", joystick, button)
end

function App:resize()
    Screen:update()
end

return App
