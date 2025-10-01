local Snake = require("snake")

local Controls = {}

local analogKeyMap = {
    up = "up",
    w = "up",
    down = "down",
    s = "down",
    left = "left",
    a = "left",
    right = "right",
    d = "right",
}

Controls.analogState = {
    up = false,
    down = false,
    left = false,
    right = false,
}

local gameplayKeyHandlers = {
    space = function()
        Snake:activateDash()
    end,
    lshift = function()
        Snake:activateTimeDilation()
    end,
    rshift = function()
        Snake:activateTimeDilation()
    end,
}

local function togglePause(game)
    if game.state == "paused" then
        game.state = "playing"
    else
        game.state = "paused"
    end
end

local function applyAnalogDirection(game)
    if game and game.state ~= "playing" then
        return
    end

    local state = Controls.analogState
    if not state then
        return
    end

    local dx = 0
    if state.right then
        dx = dx + 1
    end
    if state.left then
        dx = dx - 1
    end

    local dy = 0
    if state.down then
        dy = dy + 1
    end
    if state.up then
        dy = dy - 1
    end

    if Snake.reverseState then
        dx = -dx
        dy = -dy
    end

    if dx ~= 0 or dy ~= 0 then
        Snake:setDirectionVector(dx, dy)
    end
end

function Controls:resetAnalog()
    local state = self.analogState
    if not state then
        return
    end

    state.up = false
    state.down = false
    state.left = false
    state.right = false
end

function Controls:keypressed(game, key)
    if key == "escape" and game.state ~= "gameover" then
        togglePause(game)
        return
    end

    local mapped = analogKeyMap[key]
    if mapped then
        self.analogState[mapped] = true
        applyAnalogDirection(game)
    end

    if game.state ~= "playing" then
        return
    end

    local handler = gameplayKeyHandlers[key]
    if handler then
        handler()
    end
end

function Controls:keyreleased(game, key)
    local mapped = analogKeyMap[key]
    if not mapped then
        return
    end

    self.analogState[mapped] = false
    applyAnalogDirection(game)
end

return Controls
