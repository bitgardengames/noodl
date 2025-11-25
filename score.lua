local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local DailyChallenges = require("dailychallenges")
local max = math.max
local insert = table.insert

local Score = {}

Achievements:registerStateProvider(function(state)
        if type(state) == "table" then
                state.snakeScore = Score.current or 0
        end
end)

Score.current = 0
Score.highscores = {journey = 0, classic = 0}
Score.mode = "journey"
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

local function normalizeMode(mode)
        if mode == "classic" then
                return "classic"
        end

        return "journey"
end

local function normalizeHighScoresTable(tbl)
        tbl = tbl or {}

        return {
                journey = tonumber(tbl.journey) or 0,
                classic = tonumber(tbl.classic) or 0,
        }
end

function Score:setMode(mode)
        self.mode = normalizeMode(mode)
        self.previousHighScore = self:getHighScore()
end

function Score:load(mode)
        self.current = 0
        self.highscores = self.highscores or {journey = 0, classic = 0}
        self.comboBonusBase = 1
        self.comboBonusMult = 1
        self.highScoreGlowTimer = 0
        self.previousHighScore = 0
        self.runHighScoreTriggered = false
        self._pendingApples = 0

        self:setMode(mode or self.mode)

        -- Load from file
        if love.filesystem.getInfo(self.saveFile) then
                local chunk = love.filesystem.load(self.saveFile)
                local ok, saved = pcall(chunk)
                if ok and type(saved) == "table" then
                        local loadedHighScores = normalizeHighScoresTable(saved.highscores)

                        if type(saved.highscore) == "number" then
                                loadedHighScores.journey = saved.highscore
                        end

                        if type(saved.journey) == "number" then
                                loadedHighScores.journey = saved.journey
                        end

                        if type(saved.classic) == "number" then
                                loadedHighScores.classic = saved.classic
                        end

                        if loadedHighScores.classic == 0 and loadedHighScores.journey == 0 then
                                local highest = 0
                                for _, value in pairs(saved) do
                                        if type(value) == "number" and value > highest then
                                                highest = value
                                        end
                                end
                                loadedHighScores.journey = highest
                        end

                        self.highscores = loadedHighScores
                elseif ok and type(saved) == "number" then
                        self.highscores = {journey = saved, classic = 0}
                end
        end

        -- Legacy compatibility
        if love.filesystem.getInfo("highscore_snake.txt") then
                        local contents = love.filesystem.read("highscore_snake.txt")
                        local legacy = tonumber(contents)
                        if legacy then
                                if legacy > (self.highscores.journey or 0) then
                                        self.highscores.journey = legacy
                                        self:save()
                                end
                                love.filesystem.remove("highscore_snake.txt")
                        end
        end

        self.previousHighScore = self:getHighScore()
end

function Score:save()
        local scores = normalizeHighScoresTable(self.highscores)

        local lines = {"return {\n"}
        insert(lines, "    highscores = {\n")
        insert(lines, string.format("        journey = %d,\n", max(0, scores.journey)))
        insert(lines, string.format("        classic = %d,\n", max(0, scores.classic)))
        insert(lines, "    },\n")

        -- Legacy duplicates for backward compatibility
        insert(lines, string.format("    journey = %d,\n", max(0, scores.journey)))
        insert(lines, string.format("    classic = %d,\n", max(0, scores.classic)))
        insert(lines, string.format("    highscore = %d,\n", max(0, scores.journey)))
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
                self.highscores = {journey = 0, classic = 0}
                self.previousHighScore = 0
                self._pendingApples = 0
                self:save()
        end
end

function Score:get()
	return self.current
end

function Score:getHighScore(mode)
        mode = normalizeMode(mode or self.mode)
        if not self.highscores then
                self.highscores = {journey = 0, classic = 0}
        end

        return self.highscores[mode] or 0
end

function Score:setHighScore(score, mode)
        mode = normalizeMode(mode or self.mode)
        if not self.highscores then
                self.highscores = {journey = 0, classic = 0}
        end

        if score > (self.highscores[mode] or 0) then
                self.highscores[mode] = score
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

	DailyChallenges:applyRunResults(SessionStats, {date = options.date})

	PlayerStats:updateMax("snakeScore", self.current)

        Achievements:checkAll({
                bestScore = PlayerStats:get("snakeScore"),
                snakeScore = self.current,
                }
        )

        self:setHighScore(self.current, self.mode)

	local runFruit = SessionStats:get("fruitEaten") or 0
	local lifetimeFruit = PlayerStats:get("totalFruitEaten") or 0
	local runTiles = SessionStats:get("tilesTravelled") or 0
	local runCombos = SessionStats:get("combosTriggered") or 0
	local runTime = SessionStats:get("timeAlive") or 0
	local fastestFloor = SessionStats:get("fastestFloorClear") or 0
	local slowestFloor = SessionStats:get("slowestFloorClear") or 0
	local floorsCleared = SessionStats:get("floorsCleared") or 0
	local deepestFloor = SessionStats:get("deepestFloorReached") or 0
	local bestComboStreak = SessionStats:get("bestComboStreak") or 0
	local dragonfruitEaten = SessionStats:get("dragonfruitEaten") or 0

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
                        apples = runFruit,
                        timeAlive = runTime,
			tilesTravelled = runTiles,
			combosTriggered = runCombos,
			floorsCleared = floorsCleared,
			deepestFloor = deepestFloor,
			fastestFloor = fastestFloor,
			slowestFloor = slowestFloor,
			bestComboStreak = bestComboStreak,
			dragonfruit = dragonfruitEaten,
                },
                cause = cause,
                won = won,
                mode = self.mode,
        }

        result.restartAction = {state = "game", data = {mode = self.mode}}

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
