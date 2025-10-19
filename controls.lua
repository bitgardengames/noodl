local Snake = require("snake")

local Controls = {}

local gameplayKeyHandlers = {
    up = function()
        Snake:setDirection("up")
    end,
    down = function()
        Snake:setDirection("down")
    end,
    left = function()
        Snake:setDirection("left")
    end,
    right = function()
        Snake:setDirection("right")
    end,
    space = function()
        Snake:activateDash()
    end,
    lshift = function()
        Snake:activateTimeDilation()
    end,
    rshift = function()
        Snake:activateTimeDilation()
    end,
    f1 = function()
        if Snake.toggleDeveloperAssist then
            Snake:toggleDeveloperAssist()
        end
    end,
}

local function togglePause(game)
    if game.state == "paused" then
        game.state = "playing"
    else
        game.state = "paused"
    end
end

function Controls:keypressed(game, key)
    if key == "escape" and game.state ~= "gameover" then
        togglePause(game)
        return
    end

    if game.state ~= "playing" then
        return
    end

    local handler = gameplayKeyHandlers[key]
    if handler then
        handler()
    end
end

return Controls
