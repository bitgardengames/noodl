local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Score = {}

Achievements:registerStateProvider(function()
    return {
        snakeScore = Score.current or 0,
    }
end)

Score.current = 0
Score.highscore = 0
Score.saveFile = "scores.lua"
Score.fruitBonus = 0
Score.comboBonusMult = 1
Score.comboBonusBase = 1
Score.highScoreGlowDuration = 4
Score.highScoreGlowTimer = 0
Score.previousHighScore = 0
Score.runHighScoreTriggered = false

local function updateAchievementChecks(self)
        Achievements:checkAll({
                totalApplesEaten = PlayerStats:get("totalApplesEaten"),
                snakeScore = self.current,
        })
end

function Score:load()
        self.current = 0
        self.highscore = 0
        self.comboBonusBase = 1
        self.comboBonusMult = 1
        self.highScoreGlowTimer = 0
        self.previousHighScore = 0
        self.runHighScoreTriggered = false

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
        local lines = { "return {\n" }
        table.insert(lines, string.format("    highscore = %d,\n", math.max(0, self.highscore or 0)))
        table.insert(lines, "}\n")
        love.filesystem.write(self.saveFile, table.concat(lines))
end

function Score:reset(mode)
    if mode == nil then
        -- Just reset the current score
        self.current = 0
        self.fruitBonus = 0
        self.comboBonusBase = 1
        self.comboBonusMult = 1
        self.highScoreGlowTimer = 0
        self.runHighScoreTriggered = false
        self.previousHighScore = self:getHighScore()
    elseif mode == "all" then
        self.highscore = 0
        self.previousHighScore = 0
        self:save()
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
        self.current = self.current + points + (self.fruitBonus or 0)

        PlayerStats:add("totalApplesEaten", 1)
        updateAchievementChecks(self)

        if not self.runHighScoreTriggered and (self.previousHighScore or 0) > 0 and self.current > self.previousHighScore then
                self.runHighScoreTriggered = true
                self.highScoreGlowTimer = self.highScoreGlowDuration
        end
end

function Score:addFruitBonus(amount)
        self.fruitBonus = (self.fruitBonus or 0) + (amount or 0)
end

function Score:addBonus(points)
        if not points or points == 0 then return end
        self.current = self.current + points
        updateAchievementChecks(self)

        if not self.runHighScoreTriggered and (self.previousHighScore or 0) > 0 and self.current > self.previousHighScore then
                self.runHighScoreTriggered = true
                self.highScoreGlowTimer = self.highScoreGlowDuration
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
                self.highScoreGlowTimer = math.max(0, self.highScoreGlowTimer - dt)
        end
end

function Score:getHighScoreGlowStrength()
        if not self.highScoreGlowTimer or self.highScoreGlowTimer <= 0 then
                return 0
        end

        local normalized = self.highScoreGlowTimer / self.highScoreGlowDuration
        return math.max(0, math.min(1, normalized))
end

function Score:handleGameOver(cause)
    PlayerStats:updateMax("snakeScore", self.current)

    Achievements:checkAll({
        bestScore = PlayerStats:get("snakeScore"),
        snakeScore = self.current,
    })

    self:setHighScore(self.current)

    local runApples = SessionStats:get("applesEaten") or 0
    local lifetimeApples = PlayerStats:get("totalApplesEaten") or 0
    local runTiles = SessionStats:get("tilesTravelled") or 0
    local runCombos = SessionStats:get("combosTriggered") or 0
    local runShieldsSaved = SessionStats:get("crashShieldsSaved") or 0
    local runTime = SessionStats:get("timeAlive") or 0
    local fastestFloor = SessionStats:get("fastestFloorClear") or 0
    local slowestFloor = SessionStats:get("slowestFloorClear") or 0

    PlayerStats:updateMax("mostApplesInRun", runApples)
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
    if runShieldsSaved > 0 then
        PlayerStats:add("crashShieldsSaved", runShieldsSaved)
        PlayerStats:updateMax("mostShieldsSavedInRun", runShieldsSaved)
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
        apples      = runApples,
        totalApples = lifetimeApples,
        stats = {
            apples = runApples
        },
        cause = cause or "unknown",
        won = false,
    }

    return result
end

return Score
