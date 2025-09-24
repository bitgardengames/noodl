local PlayerStats = require("playerstats")
local Achievements = require("achievements")
local GameModes = require("gamemodes")
local Snake = require("snake")

local Score = {}

Score.current = 0
Score.highscores = {}
Score.saveFile = "scores.lua"
Score.fruitBonus = 0

function Score:load()
	self.current = 0
	self.highscores = {}

	-- Load from file
	if love.filesystem.getInfo(self.saveFile) then
		local chunk = love.filesystem.load(self.saveFile)
		local ok, saved = pcall(chunk)
		if ok and type(saved) == "table" then
			self.highscores = saved
		end
	end

	-- Legacy compatibility
	if love.filesystem.getInfo("highscore_snake.txt") then
		local contents = love.filesystem.read("highscore_snake.txt")
		local legacy = tonumber(contents)
		if legacy then
			local classicScore = self.highscores["classic"] or 0
			if legacy > classicScore then
				self.highscores["classic"] = legacy
				self:save()
			end
			love.filesystem.remove("highscore_snake.txt")
		end
	end
end

function Score:save()
	local lines = { "return {\n" }

	for mode, score in pairs(self.highscores) do
		if type(score) == "number" then
			table.insert(lines, string.format("    [%q] = %d,\n", mode, score))
		end
	end

	table.insert(lines, "}\n")
	love.filesystem.write(self.saveFile, table.concat(lines))
end

function Score:reset(mode)
    if mode == nil then
        -- Just reset the current score
        self.current = 0
        self.fruitBonus = 0
	elseif mode == "all" then
		self.highscores = {}
		self:save()
	elseif self.highscores[mode] then
		self.highscores[mode] = nil
		self:save()
	end
end

function Score:get()
	return self.current
end

function Score:getHigh()
	return self:getHighScore(GameModes:getCurrentName())
end

function Score:getHighScore(mode)
	return self.highscores[mode] or 0
end

function Score:setHighScore(mode, score)
	if score > (self.highscores[mode] or 0) then
		self.highscores[mode] = score
		self:save()
	end
end

function Score:increase(points)
    points = points or 1
        self.current = self.current + points + (self.fruitBonus or 0)

	PlayerStats:add("totalApplesEaten", 1)

	Achievements:checkAll({
		totalApplesEaten = PlayerStats:get("totalApplesEaten"),
		snakeScore = self.current,
		currentMode = GameModes:getCurrentName(),
	})
end

function Score:addFruitBonus(amount)
        self.fruitBonus = (self.fruitBonus or 0) + (amount or 0)
end

function Score:handleGameOver(cause)
    PlayerStats:updateMax("snakeScore", self.current)

    local mode = GameModes:getCurrentName()
    self:setHighScore(mode, self.current)

    return {
        score       = self.current,
        highScore   = self:getHighScore(mode),
        apples      = PlayerStats:get("totalApplesEaten") or 0,
        mode        = mode,
        totalApples = PlayerStats:get("totalApplesEaten") or 0,
        stats = {
            apples = PlayerStats:get("totalApplesEaten") or 0
        },
        cause = cause or "unknown",
        won = false,
    }
end

return Score
