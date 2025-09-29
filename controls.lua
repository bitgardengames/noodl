local Snake = require("snake")

local Controls = {}

function Controls:keypressed(game, key)
    if key == "escape" and game.state ~= "gameover" then
        if game.state == "paused" then
            game.state = "playing"
        else
            game.state = "paused"
        end
    elseif game.state == "playing" then
        if key == "up" then Snake:setDirection("up")
        elseif key == "down" then Snake:setDirection("down")
        elseif key == "left" then Snake:setDirection("left")
        elseif key == "right" then Snake:setDirection("right")
        elseif key == "space" then Snake:activateDash()
        end
    end
end

return Controls