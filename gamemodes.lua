local Popup = require("popup")
local PlayerStats = require("playerstats")
local Localization = require("localization")
local UI = require("ui")
local Settings = require("settings")

local GameModes = {}

-------------------------------------------------
-- Shared assets (preloaded to avoid per-frame GC)
-------------------------------------------------
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
        usesHealthSystem = true,
        singleTouchDeath = false,

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
        usesHealthSystem = false,
        singleTouchDeath = true,

        load = function(game)
            if Settings.screenShake ~= false and game.Effects and game.Effects.shake then
                game.Effects:shake(0.3)
            end
        end,
    },
}

GameModes.modeList = { "classic", "hardcore" }
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