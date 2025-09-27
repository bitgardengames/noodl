local Screen = require("screen")
local SessionStats = require("sessionstats")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")

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
local fontBadge
local stats = {}
local buttonList = ButtonList.new()

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

end

function GameOver:draw()
    local sw, sh = Screen:get()
    drawBackground(sw, sh)

    local contentWidth = math.min(sw * 0.65, 520)
    local contentX = (sw - contentWidth) / 2
    local padding = 24

    -- Title
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(Localization:get("gameover.title"), 0, 48, sw, "center")

    -- Combined summary panel
    local statsLines = {
        Localization:get("gameover.high_score", { score = stats.highScore }),
        Localization:get("gameover.apples_eaten", { count = stats.apples }),
        Localization:get("gameover.mode_label", { mode = self.modeLabel or Localization:get("common.unknown") }),
    }

    love.graphics.setFont(fontSmall)
    local messageText = self.deathMessage or Localization:get("gameover.default_message")
    local wrapLimit = contentWidth - padding * 2
    local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
    local lineHeight = fontSmall:getHeight()
    local messageHeight = #wrappedMessage * lineHeight
    if #wrappedMessage == 0 then
        messageHeight = lineHeight
    end

    local statsSpacing = 6
    local statsHeight = #statsLines * lineHeight + math.max(0, #statsLines - 1) * statsSpacing
    local headerHeight = lineHeight
    local scoreHeight = fontScore:getHeight()
    local badgeHeight = self.isNewHighScore and (fontBadge:getHeight() + 18) or 0
    local panelHeight = padding * 2
        + headerHeight
        + 12
        + messageHeight
        + 24
        + scoreHeight
        + 16
        + badgeHeight
        + statsHeight

    local panelY = 120
    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", contentX, panelY, contentWidth, panelHeight, 20, 20)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", contentX, panelY, contentWidth, panelHeight, 20, 20)
    love.graphics.setLineWidth(1)

    local textY = panelY + padding
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(Localization:get("gameover.run_summary_title"), contentX, textY, contentWidth, "center")

    textY = textY + headerHeight + 12
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(messageText, contentX + padding, textY, wrapLimit, "center")

    textY = textY + messageHeight + 24
    love.graphics.setFont(fontScore)
    local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
    love.graphics.setColor(progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92)
    love.graphics.printf(tostring(stats.score or 0), contentX, textY, contentWidth, "center")

    textY = textY + scoreHeight + 16
    if self.isNewHighScore then
        love.graphics.setFont(fontBadge)
        local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
        love.graphics.setColor(badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9)
        love.graphics.printf(Localization:get("gameover.high_score_badge"), contentX + padding, textY, contentWidth - padding * 2, "center")
        textY = textY + fontBadge:getHeight() + 18
    end

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 0.82)
    for index, line in ipairs(statsLines) do
        love.graphics.printf(line, contentX + padding, textY, contentWidth - padding * 2, "center")
        if index < #statsLines then
            textY = textY + lineHeight + statsSpacing
        else
            textY = textY + lineHeight
        end
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
