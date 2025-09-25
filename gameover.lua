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

local fontLarge
local fontSmall
local stats = {}
local buttonList = ButtonList.new()
local fruitSummary = {}

-- Layout constants
local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 50
local BUTTON_SPACING = 20

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

    fontLarge = love.graphics.newFont(32)
    fontSmall = love.graphics.newFont(18)

    -- Merge default stats with provided stats
    stats = {
        score       = 0,
        highScore   = 0,
        apples      = SessionStats:get("applesEaten"),
        mode        = "Classic",
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

    -- Build buttons
    local sw, sh = Screen:get()
    local startY = math.floor(sh * 0.55)
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

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(Localization:get("gameover.title"), 0, 80, sw, "center")

    -- Stats block
    love.graphics.setFont(fontSmall)
    local y = 140
    local lineHeight = 25
    local statLines = {
        Localization:get("gameover.final_score", { score = stats.score }),
        Localization:get("gameover.high_score", { score = stats.highScore }),
        Localization:get("gameover.apples_eaten", { count = stats.apples }),
    }
    for i, text in ipairs(statLines) do
        love.graphics.printf(text, 0, y + (i - 1) * lineHeight, sw, "center")
    end

        -- Death message
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1, 0.8, 0.8) -- light red/pink for flavor
        love.graphics.printf(self.deathMessage or Localization:get("gameover.default_message"), 0, y + #statLines * lineHeight + 20, sw, "center")

    if fruitSummary and #fruitSummary > 0 then
        local summaryBase = y + #statLines * lineHeight + 60
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(Theme.textColor)
        love.graphics.printf("Fruit Spoils", 0, summaryBase, sw, "center")
        for i, info in ipairs(fruitSummary) do
            local line = string.format("%s: +%d (Total %d)", info.label, info.gained or 0, info.total or 0)
            local color = info.color or Theme.textColor
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, 1)
            love.graphics.printf(line, 0, summaryBase + i * lineHeight, sw, "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Buttons
    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

    buttonList:draw()
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