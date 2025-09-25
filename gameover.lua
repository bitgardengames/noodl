local Screen = require("screen")
local SessionStats = require("sessionstats")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local FruitWallet = require("fruitwallet")

local GameOver = {}

local function pickDeathMessage(cause)
    local deathTable = Localization:getTable("gameover.deaths") or {}
    local entries = deathTable[cause] or deathTable.unknown or {}
    if #entries == 0 then
        return Localization:get("gameover.default_message")
    end

    return entries[love.math.random(#entries)]
end

local function copyColor(color, alphaOverride)
    color = color or { 1, 1, 1, 1 }
    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        alphaOverride or color[4] or 1,
    }
end

local fontTitle
local fontScore
local fontSmall
local fontTiny
local fontBadge
local stats = {}
local buttonList = ButtonList.new()
local fruitSummary = {}
local backgroundOrbs = {}

-- Layout constants
local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 50
local BUTTON_SPACING = 20

local function generateBackgroundOrbs(sw, sh)
    backgroundOrbs = {}

    local primary = copyColor(Theme.highlightColor, 0.18)
    local secondary = copyColor(Theme.progressColor, 0.2)
    local tertiary = copyColor(Theme.buttonHover, 0.15)
    local palette = { primary, secondary, tertiary }

    for i = 1, 6 do
        local radius = love.math.random(math.floor(sh * 0.09), math.floor(sh * 0.17))
        local orb = {
            x = love.math.random(radius, sw - radius),
            y = love.math.random(radius, math.floor(sh * 0.6)),
            radius = radius,
            color = palette[(i - 1) % #palette + 1],
            speed = 0.3 + love.math.random() * 0.35,
            phase = love.math.random() * math.pi * 2,
        }
        backgroundOrbs[#backgroundOrbs + 1] = orb
    end
end

local function drawBackground(sw, sh, time)
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    for _, orb in ipairs(backgroundOrbs) do
        local wobble = math.sin(time * orb.speed + orb.phase) * (orb.radius * 0.08)
        love.graphics.setColor(orb.color[1], orb.color[2], orb.color[3], orb.color[4])
        love.graphics.circle("fill", orb.x + wobble, orb.y + wobble * 0.35, orb.radius)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- All button definitions in one place
local buttonDefs = {
    { id = "goPlay", textKey = "gameover.play_again", action = "game" },
    { id = "goMenu", textKey = "gameover.quit_to_menu", action = "menu" },
}

function GameOver:enter(data)
    UI.clearButtons()

    data = data or {cause = "unknown"}

    Audio:playMusic("scorescreen")
    Screen:update()

    local cause = data.cause or "unknown"
    self.deathMessage = pickDeathMessage(cause)
    self.animTime = 0

    fontTitle = love.graphics.newFont(48)
    fontScore = love.graphics.newFont(72)
    fontSmall = love.graphics.newFont(20)
    fontTiny = love.graphics.newFont(14)
    fontBadge = love.graphics.newFont(26)

    -- Merge default stats with provided stats
    stats = {
        score       = 0,
        highScore   = 0,
        apples      = SessionStats:get("applesEaten"),
        mode        = "classic",
        totalApples = "?",
    }
    for k, v in pairs(data.stats or {}) do
        stats[k] = v
    end
    if data.score then stats.score = data.score end
    if data.highScore then stats.highScore = data.highScore end
    if data.apples then stats.apples = data.apples end
    if data.mode then stats.mode = data.mode end
    if data.totalApples then stats.totalApples = data.totalApples end

    local sw, sh = Screen:get()
    generateBackgroundOrbs(sw, sh)

    local tipTable = Localization:getTable("gameover.tips") or {}
    if #tipTable > 0 then
        self.runTip = tipTable[love.math.random(#tipTable)]
    else
        self.runTip = nil
    end

    local modeID = stats.mode
    local localizedMode = modeID and Localization:get("gamemodes." .. modeID .. ".label") or nil
    if localizedMode and localizedMode ~= ("gamemodes." .. tostring(modeID) .. ".label") then
        self.modeLabel = localizedMode
    elseif type(modeID) == "string" and modeID ~= "" then
        self.modeLabel = modeID:sub(1, 1):upper() .. modeID:sub(2)
    else
        self.modeLabel = Localization:get("common.unknown")
    end

    stats.highScore = stats.highScore or 0
    stats.totalApples = stats.totalApples or stats.apples or 0
    self.isNewHighScore = (stats.score or 0) > 0 and (stats.score or 0) >= (stats.highScore or 0)

    -- Build buttons
    local totalButtonHeight = #buttonDefs * BUTTON_HEIGHT + (#buttonDefs - 1) * BUTTON_SPACING
    local startY = math.max(math.floor(sh * 0.66), math.floor(sh - totalButtonHeight - 50))
    local centerX = sw / 2 - BUTTON_WIDTH / 2

    local defs = {}
    for i, def in ipairs(buttonDefs) do
        local y = startY + (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)
        local buttonText = def.textKey and Localization:get(def.textKey) or def.text or ""
        defs[#defs + 1] = {
            id = def.id,
            textKey = def.textKey,
            text = buttonText,
            action = def.action,
            x = centerX,
            y = y,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
        }
    end

    buttonList:reset(defs)

    fruitSummary = FruitWallet:getRunSummary() or {}
end

function GameOver:draw()
    local sw, sh = Screen:get()
    local time = self.animTime or 0

    drawBackground(sw, sh, time)

    -- Title
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(Localization:get("gameover.title"), 0, 40, sw, "center")

    -- Death ribbon for the final moment
    local ribbonWidth = math.min(sw * 0.8, 640)
    local ribbonX = (sw - ribbonWidth) / 2
    local ribbonY = 96
    love.graphics.setColor(0.9, 0.35, 0.45, 0.82)
    love.graphics.rectangle("fill", ribbonX, ribbonY, ribbonWidth, 56, 18, 18)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ribbonX, ribbonY, ribbonWidth, 56, 18, 18)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(self.deathMessage or Localization:get("gameover.default_message"), ribbonX + 16, ribbonY + 16, ribbonWidth - 32, "center")

    -- Score card panel
    local panelWidth = math.min(sw * 0.75, 540)
    local panelHeight = 270
    local panelX = (sw - panelWidth) / 2
    local panelY = ribbonY + 88
    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 22, 22)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 22, 22)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(Localization:get("gameover.run_summary_title"), panelX, panelY + 18, panelWidth, "center")

    love.graphics.setFont(fontScore)
    local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
    love.graphics.setColor(progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.9)
    love.graphics.printf(tostring(stats.score or 0), panelX, panelY + 48, panelWidth, "center")

    if self.isNewHighScore then
        local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
        love.graphics.setFont(fontBadge)
        love.graphics.setColor(badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9)
        love.graphics.printf(Localization:get("gameover.high_score_badge"), panelX, panelY + 128, panelWidth, "center")
    end

    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", panelX + 24, panelY + panelHeight - 110, panelWidth - 48, 1)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.9)
    local detailY = panelY + panelHeight - 94
    local halfWidth = panelWidth / 2
    love.graphics.printf(Localization:get("gameover.high_score", { score = stats.highScore }), panelX, detailY, halfWidth, "center")
    love.graphics.printf(Localization:get("gameover.apples_eaten", { count = stats.apples }), panelX + halfWidth, detailY, halfWidth, "center")

    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(Localization:get("gameover.mode_label", { mode = self.modeLabel or Localization:get("common.unknown") }), panelX, detailY + 30, panelWidth, "center")
    love.graphics.printf(Localization:get("gameover.total_apples_collected", { count = stats.totalApples }), panelX, detailY + 58, panelWidth, "center")

    -- Fruit summary area
    local summaryY = panelY + panelHeight + 40
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(Localization:get("gameover.fruit_summary_title"), 0, summaryY, sw, "center")
    summaryY = summaryY + 32

    if fruitSummary and #fruitSummary > 0 then
        local chipAreaWidth = sw * 0.85
        local startX = (sw - chipAreaWidth) / 2
        local currentX = startX
        local currentY = summaryY
        local chipPaddingX = 18
        local chipPaddingY = 8
        local chipSpacing = 14
        local chipHeight = fontSmall:getHeight() + chipPaddingY * 2

        for _, info in ipairs(fruitSummary) do
            local gained = info.gained or 0
            local total = info.total or 0
            local chipText = Localization:get("gameover.fruit_chip", {
                label = info.label or Localization:get("common.unknown"),
                gained = gained,
                total = total,
            })
            local textWidth = fontSmall:getWidth(chipText)
            local chipWidth = textWidth + chipPaddingX * 2

            if currentX + chipWidth > startX + chipAreaWidth then
                currentX = startX
                currentY = currentY + chipHeight + chipSpacing
            end

            local color = info.color or Theme.progressColor or { 1, 1, 1, 1 }
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, 0.28)
            love.graphics.rectangle("fill", currentX, currentY, chipWidth, chipHeight, 16, 16)
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", currentX, currentY, chipWidth, chipHeight, 16, 16)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(chipText, currentX, currentY + chipPaddingY - 2, chipWidth, "center")

            currentX = currentX + chipWidth + chipSpacing
        end
    else
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf(Localization:get("gameover.no_fruit_summary"), 0, summaryY, sw, "center")
    end

    -- Play tip at the bottom
    if self.runTip then
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(1, 1, 1, 0.6)
        local tipText = Localization:get("gameover.tip_prefix", { tip = self.runTip })
        love.graphics.printf(tipText, 60, sh - 120, sw - 120, "center")
    end

    -- Buttons
    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    buttonList:draw()
end

function GameOver:update(dt)
    self.animTime = (self.animTime or 0) + (dt or 0)
end

function GameOver:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    return action
end

function GameOver:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        local action = buttonList:activateFocused()
        if action then
            Audio:playSound("click")
        end
        return action
    elseif button == "b" then
        Audio:playSound("click")
        return "menu"
    end
end

GameOver.joystickpressed = GameOver.gamepadpressed

return GameOver
