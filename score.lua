local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local max = math.max
local insert = table.insert

local Score = {}

Achievements:registerStateProvider(function(state)
	if type(state) == "table" then
	state.snakeScore = Score.current or 0
	end
	end
)

Score.current = 0
Score.highscore = 0
Score.saveFile = "scores.lua"
Score.comboBonusMult = 1
Score.comboBonusBase = 1
Score.highScoreGlowDuration = 4
Score.highScoreGlowTimer = 0
Score.previousHighScore = 0
Score.runHighScoreTriggered = false
Score._pendingApples = 0

local function updateAchievementChecks(self)
	Achievements:checkAll({
		totalFruitEaten = (PlayerStats:get("totalFruitEaten") or 0) + (self._pendingApples or 0),
		}
	)
end

function Score:load()
	self.current = 0
	self.highscore = 0
	self.comboBonusBase = 1
	self.comboBonusMult = 1
	self.highScoreGlowTimer = 0
	self.previousHighScore = 0
	self.runHighScoreTriggered = false
	self._pendingApples = 0

	-- Load from file
	if love.filesystem.getInfo(self.saveFile) then
		local chunk = love.filesystem.load(self.saveFile)
		local ok, saved = pcall(chunk)
		if ok and type(saved) == "table" then
			if type(saved.highscore) == "number" then
				self.highscore = saved.highscore
			else
				local highest = 0
				for _, value in pairs(saved) do
					if type(value) == "number" and value > highest then
						highest = value
					end
				end
				self.highscore = highest
			end
		elseif ok and type(saved) == "number" then
			self.highscore = saved
		end
	end

	-- Legacy compatibility
	if love.filesystem.getInfo("highscore_snake.txt") then
		local contents = love.filesystem.read("highscore_snake.txt")
		local legacy = tonumber(contents)
		if legacy then
			if legacy > self.highscore then
				self.highscore = legacy
				self:save()
			end
			love.filesystem.remove("highscore_snake.txt")
		end
	end
end

function Score:save()
	local lines = {"return {\n"}
	insert(lines, string.format("    highscore = %d,\n", max(0, self.highscore or 0)))
	insert(lines, "}\n")
	love.filesystem.write(self.saveFile, table.concat(lines))
end

function Score:reset(mode)
	if mode == nil then
		-- Just reset the current score
		self.current = 0
		self.comboBonusBase = 1
		self.comboBonusMult = 1
		self.highScoreGlowTimer = 0
		self.runHighScoreTriggered = false
		self.previousHighScore = self:getHighScore()
		self._pendingApples = 0
	elseif mode == "all" then
		self.highscore = 0
		self.previousHighScore = 0
		self:save()
		self._pendingApples = 0
	end
end

function Score:get()
	return self.current
end

function Score:getHighScore()
	return self.highscore or 0
end

function Score:setHighScore(score)
	if score > (self.highscore or 0) then
		self.highscore = score
		self:save()
	end
end

function Score:increase(points)
	points = points or 1
	self.current = self.current + points

	self._pendingApples = (self._pendingApples or 0) + 1
	updateAchievementChecks(self)

	if not self.runHighScoreTriggered and (self.previousHighScore or 0) > 0 and self.current > self.previousHighScore then
		self.runHighScoreTriggered = true
		self.highScoreGlowTimer = 0
	end
end

function Score:addBonus(points)
	if not points or points == 0 then return end
	self.current = self.current + points
	updateAchievementChecks(self)

	if not self.runHighScoreTriggered and (self.previousHighScore or 0) > 0 and self.current > self.previousHighScore then
		self.runHighScoreTriggered = true
		self.highScoreGlowTimer = 0
	end
end

local function updateComboBonusValue(self)
	local base = self.comboBonusBase or 1
	if base < 0 then base = 0 end
	self.comboBonusMult = base
	return self.comboBonusMult
end

function Score:setComboBonusMultiplier(mult)
	mult = mult or 1
	if mult < 0 then mult = 0 end
	self.comboBonusBase = mult
	return updateComboBonusValue(self)
end

function Score:getComboBonusMultiplier()
	return updateComboBonusValue(self)
end

function Score:update(dt)
	if self.highScoreGlowTimer and self.highScoreGlowTimer > 0 then
		self.highScoreGlowTimer = max(0, self.highScoreGlowTimer - dt)
	end
end

function Score:getHighScoreGlowStrength()
	if not self.highScoreGlowTimer or self.highScoreGlowTimer <= 0 then
		return 0
	end

	local normalized = self.highScoreGlowTimer / self.highScoreGlowDuration
	return max(0, math.min(1, normalized))
end

local function finalizeRunResult(self, options)
	options = options or {}
	local cause = options.cause or "unknown"
	local won = options.won or false

	self:flushPendingStats()

	PlayerStats:updateMax("snakeScore", self.current)

	Achievements:checkAll({
		bestScore = PlayerStats:get("snakeScore"),
		snakeScore = self.current,
		}
	)

	self:setHighScore(self.current)

	local runFruit = SessionStats:get("fruitEaten") or 0
	local lifetimeFruit = PlayerStats:get("totalFruitEaten") or 0
	local runTiles = SessionStats:get("tilesTravelled") or 0
	local runCombos = SessionStats:get("combosTriggered") or 0
	local runTime = SessionStats:get("timeAlive") or 0
	local fastestFloor = SessionStats:get("fastestFloorClear") or 0
	local slowestFloor = SessionStats:get("slowestFloorClear") or 0

	PlayerStats:updateMax("mostFruitInRun", runFruit)
	if runTime > 0 then
		PlayerStats:add("totalTimeAlive", runTime)
		PlayerStats:updateMax("longestRunDuration", runTime)
	end
	if runTiles > 0 then
		PlayerStats:add("tilesTravelled", runTiles)
		PlayerStats:updateMax("mostTilesTravelledInRun", runTiles)
	end
	if runCombos > 0 then
		PlayerStats:add("totalCombosTriggered", runCombos)
		PlayerStats:updateMax("mostCombosInRun", runCombos)
	end
	if fastestFloor > 0 then
		PlayerStats:updateMin("bestFloorClearTime", fastestFloor)
	end

	if slowestFloor > 0 then
		PlayerStats:updateMax("longestFloorClearTime", slowestFloor)
	end

	local result = {
		score       = self.current,
		highScore   = self:getHighScore(),
		apples      = runFruit,
		totalApples = lifetimeFruit,
		stats = {
			apples = runFruit
		},
		cause = cause,
		won = won,
	}

	if options.endingMessage then
		result.endingMessage = options.endingMessage
	end

	if options.storyTitle then
		result.storyTitle = options.storyTitle
	end

	return result
end

function Score:handleGameOver(cause)
	return finalizeRunResult(self, {cause = cause or "unknown", won = false})
end

function Score:handleRunClear(options)
	options = options or {}
	options.cause = options.cause or "victory"
	options.won = true
	return finalizeRunResult(self, options)
end

function Score:flushPendingStats()
	if self._pendingApples and self._pendingApples ~= 0 then
		PlayerStats:add("totalFruitEaten", self._pendingApples)
		self._pendingApples = 0
	end
end

return Score
