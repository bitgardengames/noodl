local Screen = require("screen")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local FunChallenges = require("funchallenges")

local GameOver = {}

local ANALOG_DEADZONE = 0.35

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
local analogAxisDirections = { horizontal = nil, vertical = nil }

local analogAxisActions = {
    horizontal = {
        negative = function()
            buttonList:moveFocus(-1)
        end,
        positive = function()
            buttonList:moveFocus(1)
        end,
    },
    vertical = {
        negative = function()
            buttonList:moveFocus(-1)
        end,
        positive = function()
            buttonList:moveFocus(1)
        end,
    },
}

local analogAxisMap = {
    leftx = { slot = "horizontal" },
    rightx = { slot = "horizontal" },
    lefty = { slot = "vertical" },
    righty = { slot = "vertical" },
    [1] = { slot = "horizontal" },
    [2] = { slot = "vertical" },
}

local function resetAnalogAxis()
    analogAxisDirections.horizontal = nil
    analogAxisDirections.vertical = nil
end

local function handleAnalogAxis(axis, value)
    local mapping = analogAxisMap[axis]
    if not mapping then
        return
    end

    local direction
    if value >= ANALOG_DEADZONE then
        direction = "positive"
    elseif value <= -ANALOG_DEADZONE then
        direction = "negative"
    end

    if analogAxisDirections[mapping.slot] == direction then
        return
    end

    analogAxisDirections[mapping.slot] = direction

    if direction then
        local actions = analogAxisActions[mapping.slot]
        local action = actions and actions[direction]
        if action then
            action()
        end
    end
end
-- Layout constants
local BUTTON_WIDTH = UI.spacing.buttonWidth
local BUTTON_HEIGHT = UI.spacing.buttonHeight
local BUTTON_SPACING = UI.spacing.buttonSpacing
local CELEBRATION_ENTRY_HEIGHT = 64
local CELEBRATION_ENTRY_SPACING = CELEBRATION_ENTRY_HEIGHT + 10

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local progress = t - 1
    return 1 + c3 * (progress * progress * progress) + c1 * (progress * progress)
end

local function drawBackground(sw, sh)
    love.graphics.setColor(UI.colors.background or Theme.bgColor)
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
    UI.drawPanel(x, y, width, height, {
        radius = radius,
        shadowOffset = UI.spacing.shadowOffset,
        fill = Theme.panelColor,
        borderColor = Theme.panelBorder,
        borderWidth = 2,
    })
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
    resetAnalogAxis()

    data = data or {cause = "unknown"}

    Audio:playMusic("scorescreen")
    Screen:update()

    local cause = data.cause or "unknown"
    self.deathMessage = pickDeathMessage(cause)

    fontTitle = UI.fonts.display or UI.fonts.title
    fontScore = UI.fonts.title or UI.fonts.display
    fontSmall = UI.fonts.caption or UI.fonts.body
    fontBadge = UI.fonts.badge or UI.fonts.button
    fontProgressTitle = UI.fonts.heading or UI.fonts.subtitle
    fontProgressValue = UI.fonts.display or UI.fonts.title
    fontProgressSmall = UI.fonts.caption or UI.fonts.body

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

    self.funChallengeResult = FunChallenges:applyRunResults(SessionStats)
    local challengeBonusXP = 0
    if self.funChallengeResult then
        challengeBonusXP = math.max(0, self.funChallengeResult.xpAwarded or 0)
    end

    self.progression = MetaProgression:grantRunPoints({
        apples = stats.apples or 0,
        score = stats.score or 0,
        bonusXP = challengeBonusXP,
    })

    self.xpSectionHeight = 0
    self.progressionAnimation = nil

    if self.progression then
        local startSnapshot = self.progression.start or { total = 0, level = 1, xpIntoLevel = 0, xpForNext = MetaProgression:getXpForLevel(1) }
        local resultSnapshot = self.progression.result or startSnapshot
        local baseHeight = 220
        if challengeBonusXP > 0 then
            baseHeight = baseHeight + 28
        end
        self.baseXpSectionHeight = baseHeight
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
            bonusXP = challengeBonusXP,
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
    UI.drawPanel(x, y, width, height, {
        radius = 18,
        shadowOffset = 0,
        fill = { Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], (Theme.panelColor[4] or 1) * 0.7 },
        borderColor = UI.colors.border or Theme.panelBorder,
        borderWidth = 2,
    })

    UI.drawLabel(label, x + 8, y + 12, width - 16, "center", {
        font = fontProgressSmall,
        color = UI.colors.mutedText or UI.colors.text,
    })

    local displayFont = fontProgressValue
    if displayFont:getWidth(value) > width - 32 then
        displayFont = fontBadge
        if displayFont:getWidth(value) > width - 32 then
            displayFont = fontSmall
        end
    end

    local valueY = y + height / 2 - displayFont:getHeight() / 2 + 6
    UI.drawLabel(value, x + 8, valueY, width - 16, "center", {
        font = displayFont,
        color = UI.colors.text,
    })
end

local function drawCelebrationsList(anim, x, startY, width)
    local events = anim and anim.celebrations or {}
    if not events or #events == 0 then
        return startY
    end

    local y = startY
    local cardWidth = width - 32
    local now = love.timer.getTime()

    for index, event in ipairs(events) do
        local timer = math.max(0, event.timer or 0)
        local appear = math.min(1, timer / 0.35)
        local appearEase = easeOutBack(appear)
        local fadeAlpha = 1
        local duration = event.duration or 4.5
        if duration > 0 then
            local fadeStart = math.max(0, duration - 0.65)
            if timer > fadeStart then
                local fadeProgress = math.min(1, (timer - fadeStart) / 0.65)
                fadeAlpha = 1 - fadeProgress
            end
        end

        local alpha = math.max(0, fadeAlpha)

        if alpha > 0.01 then
            local cardX = x + 16
            local cardY = y
            local wobble = math.sin(now * 4.2 + index * 0.8) * 2 * alpha

            love.graphics.push()
            love.graphics.translate(cardX + cardWidth / 2, cardY + CELEBRATION_ENTRY_HEIGHT / 2 + wobble)
            love.graphics.scale(0.92 + 0.08 * appearEase, 0.92 + 0.08 * appearEase)
            love.graphics.translate(-(cardX + cardWidth / 2), -(cardY + CELEBRATION_ENTRY_HEIGHT / 2 + wobble))

            love.graphics.setColor(0, 0, 0, 0.35 * alpha)
            love.graphics.rectangle("fill", cardX + 5, cardY + 6, cardWidth, CELEBRATION_ENTRY_HEIGHT, 16, 16)

            local accent = event.color or Theme.progressColor or { 1, 1, 1, 1 }
            love.graphics.setColor(accent[1], accent[2], accent[3], 0.22 * alpha)
            love.graphics.rectangle("fill", cardX, cardY, cardWidth, CELEBRATION_ENTRY_HEIGHT, 16, 16)

            love.graphics.setColor(accent[1], accent[2], accent[3], 0.55 * alpha)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX, cardY, cardWidth, CELEBRATION_ENTRY_HEIGHT, 16, 16)

            local shimmer = 0.45 + 0.25 * math.sin(now * 6 + index)
            love.graphics.setColor(accent[1], accent[2], accent[3], shimmer * 0.18 * alpha)
            love.graphics.rectangle("line", cardX + 3, cardY + 3, cardWidth - 6, CELEBRATION_ENTRY_HEIGHT - 6, 12, 12)

            UI.drawLabel(event.title or "", cardX + 18, cardY + 12, cardWidth - 36, "left", {
                font = fontProgressSmall,
                color = { UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], alpha },
            })

            if event.subtitle and event.subtitle ~= "" then
                UI.drawLabel(event.subtitle, cardX + 18, cardY + 32, cardWidth - 36, "left", {
                    font = fontSmall,
                    color = { UI.colors.mutedText[1], UI.colors.mutedText[2], UI.colors.mutedText[3], alpha },
                })
            end

            love.graphics.pop()
        end

        y = y + CELEBRATION_ENTRY_SPACING
    end

    love.graphics.setLineWidth(1)
    return y
end

local function drawXpSection(self, x, y, width)
    local anim = self.progressionAnimation
    if not anim then
        return
    end

    local baseHeight = self.baseXpSectionHeight or 220
    local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
    local targetHeight = baseHeight + celebrationCount * CELEBRATION_ENTRY_SPACING
    local height = math.max(160, self.xpSectionHeight or targetHeight, targetHeight)
    UI.drawPanel(x, y, width, height, {
        radius = 18,
        shadowOffset = 0,
        fill = { Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], (Theme.panelColor[4] or 1) * 0.65 },
        borderColor = UI.colors.border or Theme.panelBorder,
        borderWidth = 2,
    })

    local headerY = y + 18
    UI.drawLabel(getLocalizedOrFallback("gameover.meta_progress_title", "Experience"), x, headerY, width, "center", {
        font = fontProgressTitle,
        color = UI.colors.text,
    })

    local levelColor = Theme.progressColor or UI.colors.progress or UI.colors.text
    local flash = math.max(0, math.min(1, anim.levelFlash or 0))
    local levelText = Localization:get("gameover.meta_progress_level_label", { level = anim.displayedLevel or 1 })
    local levelY = headerY + fontProgressTitle:getHeight() + 12
    UI.drawLabel(levelText, x, levelY, width, "center", {
        font = fontProgressValue,
        color = { levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.78 + 0.2 * flash },
    })

    if flash > 0.01 then
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        local centerX = x + width / 2
        local centerY = levelY + fontProgressValue:getHeight() / 2
        love.graphics.setColor(levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.24 * flash)
        love.graphics.circle("fill", centerX, centerY, 48 + flash * 26, 48)
        love.graphics.setColor(1, 1, 1, 0.12 * flash)
        love.graphics.circle("line", centerX, centerY, 48 + flash * 18, 48)
        love.graphics.setBlendMode(prevMode, prevAlphaMode)
    end

    local gained = math.max(0, math.floor((anim.displayedGained or 0) + 0.5))
    local gainedText = Localization:get("gameover.meta_progress_gain_short", { points = gained })
    local gainedY = levelY + fontProgressValue:getHeight() + 6
    UI.drawLabel(gainedText, x, gainedY, width, "center", {
        font = fontProgressSmall,
        color = UI.colors.mutedText or UI.colors.text,
    })

    local barY = gainedY + fontProgressSmall:getHeight() + 16
    local barHeight = 26
    local barWidth = width - 48
    local barX = x + 24
    local percent = 0
    if (anim.xpForLevel or 0) > 0 then
        percent = math.min(1, math.max(0, (anim.xpIntoLevel or 0) / anim.xpForLevel))
    end

    local shadowColor = UI.colors.shadow or { 0, 0, 0, 0.4 }
    local trackColor = { shadowColor[1], shadowColor[2], shadowColor[3], 0.35 }
    love.graphics.setColor(trackColor)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 12, 12)

    local progressColor = { levelColor[1] or 1, levelColor[2] or 1, levelColor[3] or 1, 0.92 }
    love.graphics.setColor(progressColor)
    love.graphics.rectangle("fill", barX, barY, barWidth * percent, barHeight, 12, 12)

    if percent > 0 then
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(progressColor[1], progressColor[2], progressColor[3], 0.22 + 0.18 * flash)
        love.graphics.rectangle("fill", barX, barY, barWidth * percent, barHeight, 12, 12)

        local sweepWidth = 28
        local sweepPos = (love.timer.getTime() * 80) % (barWidth + sweepWidth) - sweepWidth
        love.graphics.setScissor(barX, barY, barWidth * percent, barHeight)
        love.graphics.setColor(1, 1, 1, 0.22 * (0.5 + 0.5 * math.sin(love.timer.getTime() * 4 + percent * math.pi)))
        love.graphics.rectangle("fill", barX + sweepPos, barY - 4, sweepWidth, barHeight + 8, 10, 10)
        love.graphics.setScissor()
        love.graphics.setBlendMode(prevMode, prevAlphaMode)
    end

    local outlineSource = UI.colors.highlight or UI.colors.border or { 1, 1, 1, 0.6 }
    love.graphics.setColor(outlineSource[1], outlineSource[2], outlineSource[3], 0.6)
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
    local breakdown = self.progression and self.progression.breakdown or {}
    local bonusXP = math.max(0, math.floor(((breakdown and breakdown.bonusXP) or 0) + 0.5))
    if bonusXP > 0 then
        local bonusText = Localization:get("gameover.meta_progress_bonus", { bonus = bonusXP })
        UI.drawLabel(bonusText, x, labelY, width, "center", {
            font = fontProgressSmall,
            color = UI.colors.highlight or UI.colors.text,
        })
        labelY = labelY + fontProgressSmall:getHeight() + 6
    end

    UI.drawLabel(totalLabel, x, labelY, width, "center", {
        font = fontProgressSmall,
        color = UI.colors.text,
    })

    labelY = labelY + fontProgressSmall:getHeight() + 4
    UI.drawLabel(remainingLabel, x, labelY, width, "center", {
        font = fontProgressSmall,
        color = UI.colors.mutedText or UI.colors.text,
    })

    local celebrationStart = labelY + fontProgressSmall:getHeight() + 16
    drawCelebrationsList(anim, x, celebrationStart, width)
end

local function drawCombinedPanel(self, contentWidth, contentX, padding)
    local panelHeight = self.summaryPanelHeight or 0
    local panelY = 120
    drawCenteredPanel(contentX, panelY, contentWidth, panelHeight, 20)

    local messageText = self.deathMessage or Localization:get("gameover.default_message")
    local wrapLimit = contentWidth - padding * 2
    local _, wrappedMessage = fontSmall:getWrap(messageText, wrapLimit)
    local lineHeight = fontSmall:getHeight()
    local messageLines = math.max(1, #wrappedMessage)

    local textY = panelY + padding
    UI.drawLabel(getLocalizedOrFallback("gameover.run_summary_title", "Run Summary"), contentX, textY, contentWidth, "center", {
        font = UI.fonts.heading or fontSmall,
        color = UI.colors.text,
    })

    textY = textY + lineHeight + 12
    UI.drawLabel(messageText, contentX + padding, textY, wrapLimit, "center", {
        font = fontSmall,
        color = UI.colors.mutedText or UI.colors.text,
    })

    textY = textY + messageLines * lineHeight + 28
    local progressColor = Theme.progressColor or { 1, 1, 1, 1 }
    UI.drawLabel(tostring(stats.score or 0), contentX, textY, contentWidth, "center", {
        font = fontScore,
        color = { progressColor[1] or 1, progressColor[2] or 1, progressColor[3] or 1, 0.92 },
    })

    textY = textY + fontScore:getHeight() + 16
    if self.isNewHighScore then
        local badgeColor = Theme.achieveColor or { 1, 1, 1, 1 }
        UI.drawLabel(Localization:get("gameover.high_score_badge"), contentX + padding, textY, contentWidth - padding * 2, "center", {
            font = fontBadge,
            color = { badgeColor[1] or 1, badgeColor[2] or 1, badgeColor[3] or 1, 0.9 },
        })
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
        local achievementsLabel = getLocalizedOrFallback("gameover.achievements_header", "Achievements")
        local achievementsText = string.format("%s: %d", achievementsLabel, #achievementsList)
        UI.drawLabel(achievementsText, contentX + padding, textY, wrapLimit, "center", {
            font = fontSmall,
            color = UI.colors.mutedText or UI.colors.text,
        })
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

    UI.drawLabel(Localization:get("gameover.title"), 0, 48, sw, "center", {
        font = fontTitle,
        color = UI.colors.text,
    })

    drawCombinedPanel(self, contentWidth, contentX, padding)

    for _, btn in buttonList:iter() do
        if btn.textKey then
            btn.text = Localization:get(btn.textKey)
        end
    end

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

    local baseHeight = self.baseXpSectionHeight or 220
    local celebrationCount = (anim.celebrations and #anim.celebrations) or 0
    local targetHeight = baseHeight + celebrationCount * CELEBRATION_ENTRY_SPACING
    self.xpSectionHeight = self.xpSectionHeight or baseHeight
    local smoothing = math.min(dt * 6, 1)
    self.xpSectionHeight = self.xpSectionHeight + (targetHeight - self.xpSectionHeight) * smoothing
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

function GameOver:gamepadaxis(_, axis, value)
    handleAnalogAxis(axis, value)
end

GameOver.joystickaxis = GameOver.gamepadaxis

return GameOver
