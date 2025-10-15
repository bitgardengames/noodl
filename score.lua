local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Score = {}

Achievements:RegisterStateProvider(function()
	return {
		SnakeScore = Score.current or 0,
	}
end)

Score.current = 0
Score.highscore = 0
Score.SaveFile = "scores.lua"
Score.ComboBonusMult = 1
Score.ComboBonusBase = 1
Score.HighScoreGlowDuration = 4
Score.HighScoreGlowTimer = 0
Score.PreviousHighScore = 0
Score.RunHighScoreTriggered = false

local function UpdateAchievementChecks(self)
		Achievements:CheckAll({
				TotalApplesEaten = PlayerStats:get("TotalApplesEaten"),
				SnakeScore = self.current,
		})
end

function Score:load()
		self.current = 0
		self.highscore = 0
		self.ComboBonusBase = 1
		self.ComboBonusMult = 1
		self.HighScoreGlowTimer = 0
		self.PreviousHighScore = 0
		self.RunHighScoreTriggered = false

		-- Load from file
		if love.filesystem.getInfo(self.SaveFile) then
				local chunk = love.filesystem.load(self.SaveFile)
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
		local lines = { "return {\n" }
		table.insert(lines, string.format("    highscore = %d,\n", math.max(0, self.highscore or 0)))
		table.insert(lines, "}\n")
		love.filesystem.write(self.SaveFile, table.concat(lines))
end

function Score:reset(mode)
	if mode == nil then
		-- Just reset the current score
		self.current = 0
		self.ComboBonusBase = 1
		self.ComboBonusMult = 1
		self.HighScoreGlowTimer = 0
		self.RunHighScoreTriggered = false
		self.PreviousHighScore = self:GetHighScore()
	elseif mode == "all" then
		self.highscore = 0
		self.PreviousHighScore = 0
		self:save()
	end
end

function Score:get()
		return self.current
end

function Score:GetHighScore()
		return self.highscore or 0
end

function Score:SetHighScore(score)
		if score > (self.highscore or 0) then
				self.highscore = score
				self:save()
		end
end

function Score:increase(points)
	points = points or 1
		self.current = self.current + points

		PlayerStats:add("TotalApplesEaten", 1)
		UpdateAchievementChecks(self)

		if not self.RunHighScoreTriggered and (self.PreviousHighScore or 0) > 0 and self.current > self.PreviousHighScore then
				self.RunHighScoreTriggered = true
				self.HighScoreGlowTimer = 0
		end
end

function Score:AddBonus(points)
		if not points or points == 0 then return end
		self.current = self.current + points
		UpdateAchievementChecks(self)

		if not self.RunHighScoreTriggered and (self.PreviousHighScore or 0) > 0 and self.current > self.PreviousHighScore then
				self.RunHighScoreTriggered = true
				self.HighScoreGlowTimer = 0
		end
end

local function UpdateComboBonusValue(self)
		local base = self.ComboBonusBase or 1
		if base < 0 then base = 0 end
		self.ComboBonusMult = base
		return self.ComboBonusMult
end

function Score:SetComboBonusMultiplier(mult)
		mult = mult or 1
		if mult < 0 then mult = 0 end
		self.ComboBonusBase = mult
		return UpdateComboBonusValue(self)
end

function Score:GetComboBonusMultiplier()
		return UpdateComboBonusValue(self)
end

function Score:update(dt)
		if self.HighScoreGlowTimer and self.HighScoreGlowTimer > 0 then
				self.HighScoreGlowTimer = math.max(0, self.HighScoreGlowTimer - dt)
		end
end

function Score:GetHighScoreGlowStrength()
		if not self.HighScoreGlowTimer or self.HighScoreGlowTimer <= 0 then
				return 0
		end

		local normalized = self.HighScoreGlowTimer / self.HighScoreGlowDuration
		return math.max(0, math.min(1, normalized))
end

local function FinalizeRunResult(self, options)
	options = options or {}
	local cause = options.cause or "unknown"
	local won = options.won or false

	PlayerStats:UpdateMax("SnakeScore", self.current)

	Achievements:CheckAll({
		BestScore = PlayerStats:get("SnakeScore"),
		SnakeScore = self.current,
	})

	self:SetHighScore(self.current)

	local RunApples = SessionStats:get("ApplesEaten") or 0
	local LifetimeApples = PlayerStats:get("TotalApplesEaten") or 0
	local RunTiles = SessionStats:get("TilesTravelled") or 0
	local RunCombos = SessionStats:get("CombosTriggered") or 0
	local RunShieldsSaved = SessionStats:get("CrashShieldsSaved") or 0
	local RunTime = SessionStats:get("TimeAlive") or 0
	local FastestFloor = SessionStats:get("FastestFloorClear") or 0
	local SlowestFloor = SessionStats:get("SlowestFloorClear") or 0

	PlayerStats:UpdateMax("MostApplesInRun", RunApples)
	if RunTime > 0 then
		PlayerStats:add("TotalTimeAlive", RunTime)
		PlayerStats:UpdateMax("LongestRunDuration", RunTime)
	end
	if RunTiles > 0 then
		PlayerStats:add("TilesTravelled", RunTiles)
		PlayerStats:UpdateMax("MostTilesTravelledInRun", RunTiles)
	end
	if RunCombos > 0 then
		PlayerStats:add("TotalCombosTriggered", RunCombos)
		PlayerStats:UpdateMax("MostCombosInRun", RunCombos)
	end
	if RunShieldsSaved > 0 then
		PlayerStats:add("CrashShieldsSaved", RunShieldsSaved)
		PlayerStats:UpdateMax("MostShieldsSavedInRun", RunShieldsSaved)
	end
	if FastestFloor > 0 then
		PlayerStats:UpdateMin("BestFloorClearTime", FastestFloor)
	end

	if SlowestFloor > 0 then
		PlayerStats:UpdateMax("LongestFloorClearTime", SlowestFloor)
	end

	local result = {
		score       = self.current,
		HighScore   = self:GetHighScore(),
		apples      = RunApples,
		TotalApples = LifetimeApples,
		stats = {
			apples = RunApples
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

function Score:HandleGameOver(cause)
	return FinalizeRunResult(self, { cause = cause or "unknown", won = false })
end

function Score:HandleRunClear(options)
	options = options or {}
	options.cause = options.cause or "victory"
	options.won = true
	return FinalizeRunResult(self, options)
end

return Score
