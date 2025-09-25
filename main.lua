local App = require("app")

function love.load()
    App:load()
end

function love.update(dt)
    App:update(dt)
end

function love.draw()
    App:draw()
end

function love.mousepressed(x, y, button)
    App:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    App:mousereleased(x, y, button)
end

function love.wheelmoved(dx, dy)
    App:wheelmoved(dx, dy)
end

function love.keypressed(key)
    App:keypressed(key)
end

function love.joystickpressed(joystick, button)
    App:joystickpressed(joystick, button)
end

function love.joystickreleased(joystick, button)
    App:joystickreleased(joystick, button)
end

function love.gamepadpressed(joystick, button)
    App:gamepadpressed(joystick, button)
end

function love.gamepadreleased(joystick, button)
    App:gamepadreleased(joystick, button)
end

function love.resize(w, h)
    App:resize(w, h)
end
