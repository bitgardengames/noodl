local Screen = require("screen")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")

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
local fontProgressTitle
local fontProgressValue
local fontProgressSmall
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

local function defaultButtonLayout(sw, sh, defs, startY)
    local list = {}
    local centerX = sw / 2 - BUTTON_WIDTH / 2

    for i, def in ipairs(defs) do
        local y = startY + (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)
        list[#list + 1] = {
            id = def.id,
            textKey = def.textKey,
            text = def.text,
            action = def.action,
            x = centerX,
            y = y,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
        }
    end

    return list
end

local function drawCenteredPanel(x, y, width, height, radius)
    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", x, y, width, height, radius, radius)
    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, radius, radius)
    love.graphics.setLineWidth(1)
end

local function handleButtonAction(_, action)
    return action
end

function GameOver:updateButtonLayout()
    local sw, sh = Screen:get()
    local totalButtonHeight = #buttonDefs * BUTTON_HEIGHT + (#buttonDefs - 1) * BUTTON_SPACING
    local panelY = 120
    local panelHeight = self.summaryPanelHeight or 0
    local contentBottom = panelY + panelHeight + 60
    local defaultStartY = math.max(math.floor(sh * 0.66), math.floor(sh - totalButtonHeight - 50))
    local startY = math.max(defaultStartY, math.floor(contentBottom))
    startY = math.min(startY, math.floor(sh - totalButtonHeight - 40))
    local defs = defaultButtonLayout(sw, sh, buttonDefs, startY)

    buttonList:reset(defs)
end

local function addCelebration(anim, entry)
    if not anim or not entry then
        return
    end

    anim.celebrations = anim.celebrations or {}
    entry.timer = 0
    entry.duration = entry.duration or 4.5
    table.insert(anim.celebrations, entry)

    local maxVisible = 3
    while #anim.celebrations > maxVisible do
        table.remove(anim.celebrations, 1)
    end
end

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
    fontProgressTitle = love.graphics.newFont(30)
    fontProgressValue = love.graphics.newFont(38)
    fontProgressSmall = love.graphics.newFont(18)

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

    self.achievementsEarned = {}
    local runAchievements = SessionStats:get("runAchievements")
    if type(runAchievements) == "table" then
        for _, achievementId in ipairs(runAchievements) do
            local def = Achievements:getDefinition(achievementId)
            if def then
                self.achievementsEarned[#self.achievementsEarned + 1] = {
                    id = achievementId,
                    title = Localization:get(def.titleKey),
                    description = Localization:get(def.descriptionKey),
                }
            end
        end
    end

    local sw, sh = Screen:get()
    local contentWidth = math.min(sw * 0.65, 520)
    local padding = 24
    local wrapLimit = contentWidth - padding * 2
    local messageText = self.deathMessage or Localization:get("gameover.default_message")
    local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
    local lineHeight = fontSmall:getHeight()
    local messageHeight = (#wrappedMessage > 0 and #wrappedMessage or 1) * lineHeight

    local achievementsList = self.achievementsEarned or {}
    local achievementsHeight = (#achievementsList > 0) and (lineHeight + 12) or 0
    local scoreHeight = fontScore:getHeight()
    local badgeHeight = self.isNewHighScore and (fontBadge:getHeight() + 18) or 0
    local statRowHeight = 96
    local summaryPanelHeight = padding * 2
        + lineHeight
        + 12
        + messageHeight
        + 28
        + scoreHeight
        + 16
        + badgeHeight
        + statRowHeight
        + achievementsHeight

    self.progression = MetaProgression:grantRunPoints({
        apples = stats.apples or 0,
        score = stats.score or 0,
    })

    self.xpSectionHeight = 0
    self.progressionAnimation = nil

    if self.progression then
        local startSnapshot = self.progression.start or { total = 0, level = 1, xpIntoLevel = 0, xpForNext = MetaProgression:getXpForLevel(1) }
        local resultSnapshot = self.progression.result or startSnapshot
        local baseHeight = 200
        self.xpSectionHeight = baseHeight
        summaryPanelHeight = summaryPanelHeight + self.xpSectionHeight + 12

        local fillSpeed = math.max(60, (self.progression.gained or 0) / 1.2)
        self.progressionAnimation = {
            displayedTotal = startSnapshot.total or 0,
            targetTotal = resultSnapshot.total or (startSnapshot.total or 0),
            displayedLevel = startSnapshot.level or 1,
            xpIntoLevel = startSnapshot.xpIntoLevel or 0,
            xpForLevel = startSnapshot.xpForNext or MetaProgression:getXpForLevel(startSnapshot.level or 1),
            displayedGained = 0,
            fillSpeed = fillSpeed,
            levelFlash = 0,
            celebrations = {},
            pendingMilestones = {},
            levelUnlocks = {},
        }

        if type(self.progression.milestones) == "table" then
            for _, milestone in ipairs(self.progression.milestones) do
                self.progressionAnimation.pendingMilestones[#self.progressionAnimation.pendingMilestones + 1] = {
                    threshold = milestone.threshold,
                    triggered = false,
                }
            end
        end

        if type(self.progression.unlocks) == "table" then
            for _, unlock in ipairs(self.progression.unlocks) do
                local level = unlock.level
                self.progressionAnimation.levelUnlocks[level] = self.progressionAnimation.levelUnlocks[level] or {}
                table.insert(self.progressionAnimation.levelUnlocks[level], {
                    name = unlock.name,
                    description = unlock.description,
                })
            end
        end
    end

    self.summaryPanelHeight = summaryPanelHeight
    self:updateButtonLayout()

end

local function getLocalizedOrFallback(key, fallback)
    local value = Localization:get(key)
    if value == key then
        return fallback
    end
    return value
end

local function drawStatPill(x, y, width, height, label, value)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", x, y, width, height, 18, 18)
    love.graphics.setColor(1, 1, 1, 0.24)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 18, 18)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fontProgressSmall)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(label, x + 8, y + 14, width - 16, "center")

    local displayFont = fontProgressValue
    if displayFont:getWidth(value) > width - 32 then
        displayFont = fontBadge
        if displayFont:getWidth(value) > width - 32 then
            displayFont = fontSmall
        end
    end

    love.graphics.setFont(displayFont)
    love.graphics.setColor(1, 1, 1, 0.92)
    local valueY = y + height / 2 - displayFont:getHeight() / 2 + 10
    love.graphics.printf(value, x + 8, valueY, width - 16, "center")
end

local function drawXpSection(self, x, y, width)
    local anim = self.progressionAnimation
    if not anim then
        return
    end

    local height = math.max(160, self.xpSectionHeight or 0)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", x, y, width, height, 18, 18)
    love.graphics.setColor(1, 1, 1, 0.24)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 18, 18)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fontProgressTitle)
    love.graphics.setColor(1, 1, 1, 0.88)
    love.graphics.printf(getLocalizedOrFallback("gameover.meta_progress_title", "Experience"), x, y + 18, width, "center")

    local levelColor = Theme.progressColor or { 1, 1, 1, 1 }
    local flash = math.max(0, math.min(1, anim.levelFlash or 0))
    love.graphics.setFont(fontProgressValue)
    love.graphics.setColor(levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.78 + 0.2 * flash)
    local levelText = Localization:get("gameover.meta_progress_level_label", { level = anim.displayedLevel or 1 })
    local levelY = y + 60
    love.graphics.printf(levelText, x, levelY, width, "center")

    local gained = math.max(0, math.floor((anim.displayedGained or 0) + 0.5))
    love.graphics.setFont(fontProgressSmall)
    love.graphics.setColor(1, 1, 1, 0.78)
    local gainedText = Localization:get("gameover.meta_progress_gain_short", { points = gained })
    local gainedY = levelY + fontProgressValue:getHeight() + 8
    love.graphics.printf(gainedText, x, gainedY, width, "center")

    local barY = gainedY + fontProgressSmall:getHeight() + 18
    local barHeight = 26
    local barWidth = width - 48
    local barX = x + 24
    local percent = 0
    if (anim.xpForLevel or 0) > 0 then
        percent = math.min(1, math.max(0, (anim.xpIntoLevel or 0) / anim.xpForLevel))
    end

    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 12, 12)
    love.graphics.setColor(levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.92)
    love.graphics.rectangle("fill", barX, barY, barWidth * percent, barHeight, 12, 12)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 12, 12)
    love.graphics.setLineWidth(1)

    local totalLabel = Localization:get("gameover.meta_progress_total_label", {
        total = math.floor((anim.displayedTotal or 0) + 0.5),
    })

    local remainingLabel
    if (anim.xpForLevel or 0) <= 0 then
        remainingLabel = Localization:get("gameover.meta_progress_max_level")
    else
        local remaining = math.max(0, math.ceil((anim.xpForLevel or 0) - (anim.xpIntoLevel or 0)))
        remainingLabel = Localization:get("gameover.meta_progress_next", { remaining = remaining })
    end

    local labelY = barY + barHeight + 14
    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.printf(totalLabel, x, labelY, width, "center")
    labelY = labelY + fontProgressSmall:getHeight() + 4
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(remainingLabel, x, labelY, width, "center")
end

local function drawCombinedPanel(self, contentWidth, contentX, padding)
    local panelHeight = self.summaryPanelHeight or 0
    local panelY = 120
    drawCenteredPanel(contentX, panelY, contentWidth, panelHeight, 20)

    love.graphics.setFont(fontSmall)
    local messageText = self.deathMessage or Localization:get("gameover.default_message")
    local wrapLimit = contentWidth - padding * 2
    local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
    local lineHeight = fontSmall:getHeight()
    local messageLines = math.max(1, #wrappedMessage)

    local textY = panelY + padding
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf(getLocalizedOrFallback("gameover.run_summary_title", "Run Summary"), contentX, textY, contentWidth, "center")

    textY = textY + lineHeight + 12
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(messageText, contentX + padding, textY, wrapLimit, "center")

    textY = textY + messageLines * lineHeight + 28
    love.graphics.setFont(fontScore)
    local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
    love.graphics.setColor(progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92)
    love.graphics.printf(tostring(stats.score or 0), contentX, textY, contentWidth, "center")

    textY = textY + fontScore:getHeight() + 16
    if self.isNewHighScore then
        love.graphics.setFont(fontBadge)
        local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
        love.graphics.setColor(badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9)
        love.graphics.printf(Localization:get("gameover.high_score_badge"), contentX + padding, textY, contentWidth - padding * 2, "center")
        textY = textY + fontBadge:getHeight() + 18
    end

    local cardY = textY
    local cardHeight = 96
    local cardSpacing = 18
    local cardWidth = (contentWidth - padding * 2 - cardSpacing * 2) / 3
    local cardX = contentX + padding

    local bestLabel = getLocalizedOrFallback("gameover.stats_best_label", "Best")
    local applesLabel = getLocalizedOrFallback("gameover.stats_apples_label", "Apples")
    local modeLabel = getLocalizedOrFallback("gameover.stats_mode_label", "Mode")

    drawStatPill(cardX, cardY, cardWidth, cardHeight, bestLabel, tostring(stats.highScore or 0))
    drawStatPill(cardX + cardWidth + cardSpacing, cardY, cardWidth, cardHeight, applesLabel, tostring(stats.apples or 0))
    drawStatPill(cardX + (cardWidth + cardSpacing) * 2, cardY, cardWidth, cardHeight, modeLabel, tostring(self.modeLabel or Localization:get("common.unknown")))

    textY = textY + cardHeight + 12

    local achievementsList = self.achievementsEarned or {}
    if #achievementsList > 0 then
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1, 1, 1, 0.72)
        local achievementsLabel = getLocalizedOrFallback("gameover.achievements_header", "Achievements")
        local achievementsText = string.format("%s: %d", achievementsLabel, #achievementsList)
        love.graphics.printf(achievementsText, contentX + padding, textY, wrapLimit, "center")
        textY = textY + lineHeight + 12
    end

    if self.progressionAnimation then
        drawXpSection(self, contentX + padding, textY, contentWidth - padding * 2)
    end
end

function GameOver:draw()
    local sw, sh = Screen:get()
    drawBackground(sw, sh)

    local contentWidth = math.min(sw * 0.65, 520)
    local contentX = (sw - contentWidth) / 2
    local padding = 24

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(Localization:get("gameover.title"), 0, 48, sw, "center")

    drawCombinedPanel(self, contentWidth, contentX, padding)

    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    buttonList:draw()
end

function GameOver:update(dt)
    local anim = self.progressionAnimation
    if not anim then
        return
    end

    local targetTotal = anim.targetTotal or anim.displayedTotal or 0
    local startTotal = 0
    if self.progression and self.progression.start then
        startTotal = self.progression.start.total or 0
    end

    if (anim.displayedTotal or 0) < targetTotal then
        local increment = anim.fillSpeed * dt
        anim.displayedTotal = math.min(targetTotal, (anim.displayedTotal or 0) + increment)
        anim.displayedGained = math.min((self.progression and self.progression.gained) or 0, anim.displayedTotal - startTotal)

        local previousLevel = anim.displayedLevel or 1
        local level, xpIntoLevel, xpForNext = MetaProgression:getProgressForTotal(anim.displayedTotal)
        if level > previousLevel then
            for levelReached = previousLevel + 1, level do
                anim.levelFlash = 0.9
                addCelebration(anim, {
                    type = "level",
                    title = Localization:get("gameover.meta_progress_level_up", { level = levelReached }),
                    subtitle = Localization:get("gameover.meta_progress_level_up_subtitle"),
                    color = Theme.progressColor or { 1, 1, 1, 1 },
                    duration = 5.5,
                })
                Audio:playSound("goal_reached")

                local unlockList = anim.levelUnlocks[levelReached]
                if unlockList then
                    for _, unlock in ipairs(unlockList) do
                        addCelebration(anim, {
                            type = "unlock",
                            title = Localization:get("gameover.meta_progress_unlock_header", { name = unlock.name or "???" }),
                            subtitle = unlock.description or "",
                            color = Theme.achieveColor or { 1, 1, 1, 1 },
                            duration = 6,
                        })
                    end
                end
            end
        end

        anim.displayedLevel = level
        anim.xpIntoLevel = xpIntoLevel
        anim.xpForLevel = xpForNext
    else
        anim.displayedTotal = targetTotal
        anim.displayedGained = (self.progression and self.progression.gained) or 0
    end

    if anim.levelFlash then
        anim.levelFlash = math.max(0, anim.levelFlash - dt)
    end

    if anim.pendingMilestones then
        for _, milestone in ipairs(anim.pendingMilestones) do
            if not milestone.triggered and (anim.displayedTotal or 0) >= (milestone.threshold or 0) then
                milestone.triggered = true
                addCelebration(anim, {
                    type = "milestone",
                    title = Localization:get("gameover.meta_progress_milestone_header"),
                    subtitle = Localization:get("gameover.meta_progress_milestone", { threshold = milestone.threshold }),
                    color = Theme.achieveColor or { 1, 1, 1, 1 },
                    duration = 6.5,
                })
                Audio:playSound("achievement")
            end
        end
    end

    if anim.celebrations then
        for index = #anim.celebrations, 1, -1 do
            local event = anim.celebrations[index]
            event.timer = (event.timer or 0) + dt
            if event.timer >= (event.duration or 4.5) then
                table.remove(anim.celebrations, index)
            end
        end
    end
end

function GameOver:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    return handleButtonAction(self, action)
end

function GameOver:keypressed(key)
    if key == "up" or key == "left" then
        buttonList:moveFocus(-1)
    elseif key == "down" or key == "right" then
        buttonList:moveFocus(1)
    elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
        local action = buttonList:activateFocused()
        local resolved = handleButtonAction(self, action)
        if resolved then
            Audio:playSound("click")
        end
        return resolved
    elseif key == "escape" or key == "backspace" then
        Audio:playSound("click")
        return "menu"
    end
end

function GameOver:gamepadpressed(_, button)
    if button == "dpup" or button == "dpleft" then
        buttonList:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        buttonList:moveFocus(1)
    elseif button == "a" or button == "start" then
        local action = buttonList:activateFocused()
        local resolved = handleButtonAction(self, action)
        if resolved then
            Audio:playSound("click")
        end
        return resolved
    elseif button == "b" then
        Audio:playSound("click")
        return "menu"
    end
end

GameOver.joystickpressed = GameOver.gamepadpressed

return GameOver
