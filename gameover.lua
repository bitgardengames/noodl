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

local fontTitle
local fontScore
local fontSmall
local fontTiny
local fontBadge
local stats = {}
local buttonList = ButtonList.new()
local fruitSummary = {}

-- Layout constants
local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 50
local BUTTON_SPACING = 20

local function drawBackground(sw, sh)
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
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

    local sw, sh = Screen:get()

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
    drawBackground(sw, sh)

    local contentWidth = math.min(sw * 0.72, 560)
    local contentX = (sw - contentWidth) / 2
    local padding = 28

    -- Title
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(Localization:get("gameover.title"), 0, 40, sw, "center")

    -- Death message panel
    local messageHeight = 68
    local messageY = 112
    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", contentX, messageY, contentWidth, messageHeight, 20, 20)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", contentX, messageY, contentWidth, messageHeight, 20, 20)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.9)
    local messageTextY = messageY + (messageHeight - fontSmall:getHeight()) / 2
    love.graphics.printf(self.deathMessage or Localization:get("gameover.default_message"), contentX + padding, messageTextY, contentWidth - padding * 2, "center")

    -- Score + stats panel
    local panelY = messageY + messageHeight + 28
    local statsLines = {
        Localization:get("gameover.high_score", { score = stats.highScore }),
        Localization:get("gameover.apples_eaten", { count = stats.apples }),
        Localization:get("gameover.total_apples_collected", { count = stats.totalApples }),
        Localization:get("gameover.mode_label", { mode = self.modeLabel or Localization:get("common.unknown") }),
    }

    local headerHeight = fontSmall:getHeight()
    local scoreHeight = fontScore:getHeight()
    local lineHeight = fontSmall:getHeight() + 10
    local badgeHeight = 0
    if self.isNewHighScore then
        badgeHeight = fontBadge:getHeight() + 22
    end
    local statsHeight = #statsLines * lineHeight
    local statsStartOffset = 24
    local panelHeight = padding * 2 + headerHeight + 12 + scoreHeight + 20 + badgeHeight + statsStartOffset + statsHeight

    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", contentX, panelY, contentWidth, panelHeight, 22, 22)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", contentX, panelY, contentWidth, panelHeight, 22, 22)
    love.graphics.setLineWidth(1)

    local textY = panelY + padding
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(Localization:get("gameover.run_summary_title"), contentX, textY, contentWidth, "center")

    textY = textY + headerHeight + 12
    love.graphics.setFont(fontScore)
    local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
    love.graphics.setColor(progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92)
    love.graphics.printf(tostring(stats.score or 0), contentX, textY, contentWidth, "center")

    textY = textY + scoreHeight + 20
    if self.isNewHighScore then
        local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
        love.graphics.setFont(fontBadge)
        love.graphics.setColor(badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9)
        love.graphics.printf(Localization:get("gameover.high_score_badge"), contentX + padding, textY, contentWidth - padding * 2, "center")
        textY = textY + fontBadge:getHeight() + 22
    end

    local dividerY = textY + statsStartOffset - 12
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("fill", contentX + padding, dividerY, contentWidth - padding * 2, 2, 1, 1)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.9)
    local statsY = textY + statsStartOffset
    for _, line in ipairs(statsLines) do
        love.graphics.printf(line, contentX + padding, statsY, contentWidth - padding * 2, "left")
        statsY = statsY + lineHeight
    end

    -- Fruit summary panel
    local fruitPanelY = panelY + panelHeight + 24
    love.graphics.setFont(fontSmall)
    local fruitTitleHeight = fontSmall:getHeight()
    local fruitLineHeight = fontSmall:getHeight() + 12
    local fruitCount = fruitSummary and #fruitSummary or 0
    local fruitContentHeight
    if fruitCount > 0 then
        fruitContentHeight = fruitCount * fruitLineHeight
    else
        fruitContentHeight = fruitLineHeight
    end
    local fruitPanelHeight = padding * 2 + fruitTitleHeight + 12 + fruitContentHeight

    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", contentX, fruitPanelY, contentWidth, fruitPanelHeight, 22, 22)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", contentX, fruitPanelY, contentWidth, fruitPanelHeight, 22, 22)
    love.graphics.setLineWidth(1)

    local fruitTextY = fruitPanelY + padding
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(Localization:get("gameover.fruit_summary_title"), contentX, fruitTextY, contentWidth, "center")

    fruitTextY = fruitTextY + fruitTitleHeight + 12
    if fruitCount > 0 then
        for _, info in ipairs(fruitSummary) do
            local chipText = Localization:get("gameover.fruit_chip", {
                label = info.label or Localization:get("common.unknown"),
                gained = info.gained or 0,
                total = info.total or 0,
            })
            local color = info.color or Theme.progressColor or { 1, 1, 1, 1 }
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, 0.8)
            love.graphics.circle("fill", contentX + padding + 10, fruitTextY + fontSmall:getHeight() / 2, 6)
            love.graphics.setColor(1, 1, 1, 0.92)
            love.graphics.printf(chipText, contentX + padding + 24, fruitTextY, contentWidth - padding * 2 - 24, "left")
            fruitTextY = fruitTextY + fruitLineHeight
        end
    else
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf(Localization:get("gameover.no_fruit_summary"), contentX + padding, fruitTextY, contentWidth - padding * 2, "center")
    end

    -- Play tip at the bottom
    if self.runTip then
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(1, 1, 1, 0.6)
        local tipText = Localization:get("gameover.tip_prefix", { tip = self.runTip })
        love.graphics.printf(tipText, contentX + padding, fruitPanelY + fruitPanelHeight + 24, contentWidth - padding * 2, "center")
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
    -- No animated elements yet, but keep hook for future transitions
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
