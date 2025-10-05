local Popup = require("popup")
local PlayerStats = require("playerstats")
local Localization = require("localization")
local UI = require("ui")

local GameModes = {}

-------------------------------------------------
-- Shared assets (preloaded to avoid per-frame GC)
-------------------------------------------------
local FONTS = {
    timer = UI.fonts.timerSmall or UI.fonts.button
}

-------------------------------------------------
-- Internal constants
-------------------------------------------------
GameModes.SAVE_VERSION = 1 -- bump this if unlock system changes
GameModes.UNLOCK_FILE  = "unlocks.lua"

-------------------------------------------------
-- Mode definitions
-------------------------------------------------
GameModes.available = {
    classic = {
        labelKey = "gamemodes.classic.label",
        descriptionKey = "gamemodes.classic.description",
        speed = 0.08,
        timed = false,
        timeLimit = nil,
        unlocked = true,
        unlockCondition = nil,
        unlockDescription = nil,
        maxHealth = 3,

        load = function(game)
            game.timer = nil
        end,
    },

    hardcore = {
        labelKey = "gamemodes.hardcore.label",
        descriptionKey = "gamemodes.hardcore.description",
        speed = 0.04,
        timed = false,
        timeLimit = nil,
        unlocked = false,
        unlockCondition = {
            type = "score",
            mode = "classic",
            value = 25,
        },
        unlockDescriptionKey = "gamemodes.hardcore.unlock_description",
        maxHealth = 1,

        load = function(game)
            if game.Effects and game.Effects.shake then
                game.Effects:shake(0.3)
            end
        end,
    },

    timed = {
        labelKey = "gamemodes.timed.label",
        descriptionKey = "gamemodes.timed.description",
        speed = 0.06,
        timed = true,
        timeLimit = 60,
        unlocked = false,
        unlockCondition = {
            type = "playerStat",
            stat = "totalApplesEaten",
            value = 50,
        },
        unlockDescriptionKey = "gamemodes.timed.unlock_description",
        maxHealth = 3,

        load = function(game)
            game.timer = game.mode.timeLimit
            game.timerExpired = false
        end,

        update = function(game, dt)
            if game.timer and not game.timerExpired then
                game.timer = game.timer - dt
                if game.timer <= 0 then
                    game.timer = 0
                    game.timerExpired = true
                    game.dead = true
                end
            end
        end,

        draw = function(game)
            if game.timer and not game.gameOver then
                local timeLeft = math.ceil(game.timer)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setFont(FONTS.timer)
                local label = Localization:get("gamemodes.timed.timer_label", { seconds = timeLeft })
                love.graphics.printf(label, 0, 16, love.graphics.getWidth(), "center")
                love.graphics.setColor(1, 1, 1, 1) -- reset color
            end
        end,
    },

    daily = {
        labelKey = "gamemodes.daily.label",
        descriptionKey = "gamemodes.daily.description",
        speed = 0.06,
        timed = false,
        timeLimit = nil,
        unlocked = true,
        daily = true,
        maxHealth = 3,

        load = function(game)
            game.effects = GameModes:getDailyModifiers()
        end,
    },
}

GameModes.modeList = { "classic", "hardcore", "timed", "daily" }
GameModes.current = "classic"
GameModes.unlockData = {}

-------------------------------------------------
-- Mode selection
-------------------------------------------------
function GameModes:set(mode)
    if self.available[mode] and self.available[mode].unlocked then
        self.current = mode
    end
end

function GameModes:get()
    return self.available[self.current]
end

function GameModes:getCurrentName()
    return self.current
end

-------------------------------------------------
-- Daily challenge utilities
-------------------------------------------------
function GameModes:getDailySeed()
    return tonumber(os.date("%Y%m%d"))
end

function GameModes:getDailyModifiers()
    local seed = self:getDailySeed()
    love.math.setRandomSeed(seed)

    local possibleEffects = {
        "reverseControls",
        "scoreMultiplier",
        "slowTime",
        "speedBoost",
    }

    local chosen = {}
    local count = 2 + love.math.random(0, 2) -- 2–4 effects

    for i = 1, count do
        if #possibleEffects == 0 then break end
        local index = love.math.random(1, #possibleEffects)
        table.insert(chosen, possibleEffects[index])
        table.remove(possibleEffects, index)
    end

    return chosen
end

-------------------------------------------------
-- Unlock system
-------------------------------------------------
function GameModes:checkUnlocks(stats, currentModeID)
    for _, modeID in ipairs(self.modeList) do
        local mode = self.available[modeID]
        local cond = mode.unlockCondition

        if not mode.unlocked and cond then
            local satisfied = false

            if cond.type == "score" and currentModeID == cond.mode then
                satisfied = (stats.score or 0) >= cond.value
            elseif cond.type == "playerStat" and PlayerStats and PlayerStats.get then
                local statValue = PlayerStats:get(cond.stat) or 0
                satisfied = statValue >= cond.value
            end

            if satisfied then
                self:unlock(modeID)
            end
        end
    end
end

function GameModes:unlock(modeID)
    if self.available[modeID] then
        self.available[modeID].unlocked = true
        self.unlockData[modeID] = true
        self:saveUnlocks()

        local mode = self.available[modeID]
        if Popup and Popup.show then
            local modeName = mode.labelKey and Localization:get(mode.labelKey) or mode.label or modeID
            local description = mode.descriptionKey and Localization:get(mode.descriptionKey) or mode.description or ""
            local title = Localization:get("gamemodes.unlock_popup", { mode = modeName })
            Popup:show(title, description)
        end
    end
end

-------------------------------------------------
-- Save/load unlocks with versioning
-------------------------------------------------
function GameModes:saveUnlocks()
    local lines = { "return {\n" }
    table.insert(lines, string.format("    __version = %d,\n", self.SAVE_VERSION))
    for k, v in pairs(self.unlockData) do
        if v == true then
            table.insert(lines, string.format("    [%q] = true,\n", k))
        end
    end
    table.insert(lines, "}\n")
    love.filesystem.write(self.UNLOCK_FILE, table.concat(lines))
end

function GameModes:loadUnlocks()
    if love.filesystem.getInfo(self.UNLOCK_FILE) then
        local chunk = love.filesystem.load(self.UNLOCK_FILE)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                if not data.__version or data.__version ~= self.SAVE_VERSION then
                    -- version mismatch, reset
                    love.filesystem.remove(self.UNLOCK_FILE)
                    return self:initializeDefaultUnlocks()
                end
                self.unlockData = data
                for k in pairs(data) do
                    if self.available[k] then
                        self.available[k].unlocked = true
                    end
                end
                -- post-load validation
                self:checkUnlocks({ score = 0 }, "classic")
                return
            end
        end
        love.filesystem.remove(self.UNLOCK_FILE)
    end
    self:initializeDefaultUnlocks()
end

function GameModes:initializeDefaultUnlocks()
    self.available.classic.unlocked = true
    self.unlockData = { classic = true, __version = self.SAVE_VERSION }
    self:saveUnlocks()
    self:checkUnlocks({ score = 0 }, "classic")
end

return GameModes