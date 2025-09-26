local UI = require("ui")
local Relics = require("relics")
local RelicVault = {}

function RelicVault:start(floor, options)
    self.floor = floor or 1
    self.cards = options or {}
    self.cardStates = {}
    self.cardBounds = {}
    self.time = 0
    self.selectionTimer = 0
    self.selectionHold = 1.15
    self.selectionDone = false
    self.exitReady = false
    self.selectedIndex = nil
    self.skipChosen = false
    self.skipReward = Relics:getSkipReward(floor)
    for i = 1, #self.cards do
        self.cardStates[i] = {
            progress = 0,
            delay = (i - 1) * 0.08,
            hover = 0,
        }
    end
end

local function getCardLayout(count, screenW, screenH)
    local cardWidth = 280
    local cardHeight = 340
    local spacing = 34
    local totalWidth = cardWidth * count + spacing * math.max(0, count - 1)
    local startX = (screenW - totalWidth) / 2
    local startY = screenH * 0.35
    return cardWidth, cardHeight, spacing, startX, startY
end

local function drawCard(card, state, x, y, w, h, isSelected)
    local progress = math.min(1, state.progress or 0)
    local alpha = progress
    local rarityColor = card.rarityInfo and card.rarityInfo.color or {1, 1, 1, 1}
    love.graphics.setColor(0, 0, 0, 0.35 * alpha)
    love.graphics.rectangle("fill", x + 6, y + 10, w, h, 16, 16)
    love.graphics.setColor(0.12, 0.15, 0.22, 0.92 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, 16, 16)

    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.85 * alpha)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, 16, 16)

    if isSelected then
        local pulse = 0.45 + 0.25 * math.sin(love.timer.getTime() * 5)
        love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], pulse)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", x - 10, y - 12, w + 20, h + 24, 18, 18)
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.printf(card.name, x + 16, y + 24, w - 32, "center")

    love.graphics.setFont(UI.fonts.small)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.9 * alpha)
    love.graphics.printf(card.rarityInfo and card.rarityInfo.label or "", x + 18, y + 72, w - 36, "center")

    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.setFont(UI.fonts.body)
    love.graphics.printf(card.desc or "", x + 18, y + 116, w - 36, "center")
end

function RelicVault:update(dt)
    self.time = (self.time or 0) + dt
    for i, state in ipairs(self.cardStates) do
        if self.time >= (state.delay or 0) then
            state.progress = math.min(1, (state.progress or 0) + dt * 3.4)
        end
    end
    if self.selectionDone then
        self.selectionTimer = self.selectionTimer + dt
        if self.selectionTimer >= self.selectionHold then
            self.exitReady = true
        end
    end
end

function RelicVault:isSelectionComplete()
    return self.exitReady
end

local function within(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h
end

local function claimCard(self, index)
    if self.selectionDone then return false end
    local card = self.cards[index]
    if not card then return false end
    self.selectedIndex = index
    self.selectionDone = true
    self.selectionTimer = 0
    self.skipChosen = false
    Relics:claim(card.relic, self.floor)
    return true
end

local function skipVault(self)
    if self.selectionDone then return false end
    self.selectionDone = true
    self.selectionTimer = 0
    self.skipChosen = true
    local reward = Relics:skipVault(self.floor)
    self.skipReward = reward
    return true
end

function RelicVault:keypressed(key)
    if key == "s" then
        return skipVault(self)
    end
    local index = tonumber(key)
    if index and index >= 1 and index <= #self.cards then
        return claimCard(self, index)
    end
    if key == "return" or key == "space" then
        if self.selectedIndex then
            return claimCard(self, self.selectedIndex)
        end
    end
    return false
end

function RelicVault:mousepressed(x, y, button)
    if button ~= 1 then return false end
    for i, bounds in ipairs(self.cardBounds) do
        if within(x, y, bounds) then
            return claimCard(self, i)
        end
    end
    return false
end

function RelicVault:draw(screenW, screenH)
    screenW = screenW or love.graphics.getWidth()
    screenH = screenH or love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.title)
    love.graphics.printf("Vault of Echoes", 0, screenH * 0.12, screenW, "center")

    love.graphics.setFont(UI.fonts.button)
    love.graphics.setColor(1, 1, 1, 0.85)
    local subtitle = string.format("Floor %d relics hum with possibility.", self.floor or 1)
    love.graphics.printf(subtitle, 0, screenH * 0.2, screenW, "center")

    local skipText = string.format("Press [S] to bank for +%d score", self.skipReward or Relics:getSkipReward(self.floor))
    love.graphics.setFont(UI.fonts.body)
    love.graphics.setColor(1, 1, 1, 0.72)
    love.graphics.printf(skipText, 0, screenH * 0.26, screenW, "center")

    local count = #self.cards
    local cardWidth, cardHeight, spacing, startX, startY = getCardLayout(count, screenW, screenH)
    self.cardBounds = {}
    for i, card in ipairs(self.cards) do
        local x = startX + (i - 1) * (cardWidth + spacing)
        local y = startY
        self.cardBounds[i] = { x = x, y = y, w = cardWidth, h = cardHeight }
        local state = self.cardStates[i]
        drawCard(card, state, x, y, cardWidth, cardHeight, self.selectedIndex == i and self.selectionDone)

        love.graphics.setFont(UI.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("[" .. tostring(i) .. "]", x + 16, y + cardHeight + 12, cardWidth - 32, "center")
    end

    if self.selectionDone then
        local message
        if self.skipChosen then
            message = string.format("Vault banked! +%d score", self.skipReward or 0)
        else
            local card = self.cards[self.selectedIndex]
            message = card and (card.name .. " claimed!") or "Relic claimed!"
        end
        love.graphics.setFont(UI.fonts.button)
        local alpha = math.min(1, self.selectionTimer / self.selectionHold)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(message, 0, screenH * 0.82, screenW, "center")
    end
end

return RelicVault
