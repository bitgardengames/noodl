local GameState = require("gamestate")
local Screen = require("screen")
local Settings = require("settings")
local Display = require("display")
local Audio = require("audio")
local Achievements = require("achievements")
local Score = require("score")
local PlayerStats = require("playerstats")
local GameModes = require("gamemodes")
local UI = require("ui")
local Localization = require("localization")
local Theme = require("theme")

local App = {
    stateModules = {
        menu = "menu",
        modeselect = "modeselect",
        game = "game",
        gameover = "gameover",
        achievementsmenu = "achievementsmenu",
        metaprogression = "metaprogressionscreen",
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
    Settings:load()
    Display.apply(Settings)

    self:registerStates()
    self:loadSubsystems()

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
end

function App:draw()
    local bg = Theme.bgColor or {0, 0, 0, 1}
    local r = bg[1] or 0
    local g = bg[2] or 0
    local b = bg[3] or 0
    local a = bg[4] or 1
    love.graphics.clear(r, g, b, a)
    love.graphics.setColor(1, 1, 1, 1)

    GameState:draw()
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

    return self:forwardEvent("keypressed", key)
end

function App:joystickpressed(joystick, button)
    return self:forwardEvent("joystickpressed", joystick, button)
end

function App:joystickreleased(joystick, button)
    return self:forwardEvent("joystickreleased", joystick, button)
end

function App:joystickaxis(joystick, axis, value)
    return self:forwardEvent("joystickaxis", joystick, axis, value)
end

function App:gamepadpressed(joystick, button)
    return self:forwardEvent("gamepadpressed", joystick, button)
end

function App:gamepadreleased(joystick, button)
    return self:forwardEvent("gamepadreleased", joystick, button)
end

function App:gamepadaxis(joystick, axis, value)
    return self:forwardEvent("gamepadaxis", joystick, axis, value)
end

function App:resize()
    Screen:update()
end

return App
