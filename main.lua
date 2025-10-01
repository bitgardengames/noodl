local App = require("app")

local function forward(method)
    return function(...)
        return App[method](App, ...)
    end
end

local handlers = {
    load = "load",
    update = "update",
    draw = "draw",
    mousepressed = "mousepressed",
    mousereleased = "mousereleased",
    wheelmoved = "wheelmoved",
    keypressed = "keypressed",
    keyreleased = "keyreleased",
    joystickpressed = "joystickpressed",
    joystickreleased = "joystickreleased",
    joystickaxis = "joystickaxis",
    gamepadpressed = "gamepadpressed",
    gamepadreleased = "gamepadreleased",
    gamepadaxis = "gamepadaxis",
    resize = "resize",
}

for event, method in pairs(handlers) do
    love[event] = forward(method)
end
