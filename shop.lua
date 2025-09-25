local UI = require("ui")
local Upgrades = require("upgrades")

local Shop = {}

local function getLastUpgradeName()
    if not Upgrades.getRunState then return nil end
    local state = Upgrades:getRunState()
    if not state or not state.takenOrder then return nil end
    local lastId = state.takenOrder[#state.takenOrder]
    if not lastId then return nil end
    if Upgrades.getUpgradeById then
        local upgrade = Upgrades:getUpgradeById(lastId)
        if upgrade and upgrade.name then
            return upgrade.name
        end
    end
    return nil
end

local function buildFlavor(floor, extraChoices)
    local lines = {}
    local last = getLastUpgradeName()
    if last then
        table.insert(lines, string.format("That %s is still humming on you.", last))
    end
    if extraChoices and extraChoices > 0 then
        table.insert(lines, "I smuggled an extra relic from the caravans for you.")
    end
    if floor and floor >= 5 then
        table.insert(lines, "Depth bites harder down here—carry something brave.")
    end

    local fallback = {
        "Browse awhile. The dungeon never minds a short delay.",
        "Relics for scales, friend. Pick the one that sings to you.",
        "Listen—the stones hum louder the deeper we trade.",
    }
    for _, line in ipairs(fallback) do
        table.insert(lines, line)
    end

    local chosen = lines[love.math.random(#lines)]
    local subline
    if extraChoices and extraChoices > 0 then
        subline = string.format("Choices on the table: %d", 3 + extraChoices)
    elseif floor then
        subline = string.format("Depth %d wares", floor)
    end

    return chosen, subline
end

function Shop:start(currentFloor)
    self.floor = currentFloor or 1
    local extraChoices = 0
    if Upgrades.getEffect then
        extraChoices = math.max(0, math.floor(Upgrades:getEffect("shopSlots") or 0))
    end
    extraChoices = math.min(extraChoices, 2)
    self.extraChoices = extraChoices
    local cardCount = 3 + extraChoices
    self.cards = Upgrades:getRandom(cardCount, { floor = self.floor }) or {}
    self.selected = nil
    self.shopkeeperLine, self.shopkeeperSubline = buildFlavor(self.floor, extraChoices)
end

function Shop:update(dt)
    -- visual effects were toned down; update kept for compatibility
end

local rarityBorderAlpha = 0.85

local function drawCard(card, x, y, w, h, hovered, index, _, isSelected)
    local base = hovered and 0.28 or 0.22
    local bgColor = {base, base * 0.92, base * 0.65, 1}
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)

    local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], rarityBorderAlpha)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    if hovered or isSelected then
        local glowAlpha = hovered and 0.55 or 0.35
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], glowAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12, 10, 10)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.printf(card.name, x + 14, y + 24, w - 28, "center")

    if index then
        love.graphics.setFont(UI.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.65)
        love.graphics.printf("[" .. tostring(index) .. "]", x + 18, y + 8, w - 36, "left")
        love.graphics.setColor(1, 1, 1, 1)
    end

    if card.rarityLabel then
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
        love.graphics.printf(card.rarityLabel, x + 14, y + 64, w - 28, "center")
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 24, y + 92, x + w - 24, y + 92)
    else
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 24, y + 68, x + w - 24, y + 68)
    end

    love.graphics.setFont(UI.fonts.body)
    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    local descY = card.rarityLabel and (y + 108) or (y + 80)
    if card.upgrade and card.upgrade.tags and #card.upgrade.tags > 0 then
        love.graphics.setFont(UI.fonts.small)
        love.graphics.setColor(0.8, 0.85, 0.9, 0.9)
        love.graphics.printf(table.concat(card.upgrade.tags, " • "), x + 18, descY, w - 36, "center")
        descY = descY + 22
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(0.92, 0.92, 0.92, 1)
    end
    love.graphics.printf(card.desc or "", x + 18, descY, w - 36, "center")
end

function Shop:draw(screenW, screenH)
    love.graphics.setColor(0.07, 0.08, 0.11, 0.92)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.title)
    love.graphics.printf("Choose an Upgrade", 0, screenH * 0.15, screenW, "center")

    if self.shopkeeperLine then
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(1, 0.92, 0.8, 1)
        love.graphics.printf(self.shopkeeperLine, screenW * 0.1, screenH * 0.22, screenW * 0.8, "center")
    end
    if self.shopkeeperSubline then
        love.graphics.setFont(UI.fonts.small)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.printf(self.shopkeeperSubline, screenW * 0.1, screenH * 0.26, screenW * 0.8, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)

    local cardWidth, cardHeight = 264, 344
    local spacing = 48
    local totalWidth = (#self.cards * cardWidth) + math.max(0, (#self.cards - 1)) * spacing
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.34

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(self.cards) do
        local x = startX + (i - 1) * (cardWidth + spacing)
        local hovered = mx >= x and mx <= x + cardWidth and my >= y and my <= y + cardHeight
        drawCard(card, x, y, cardWidth, cardHeight, hovered, i, nil, self.selected == card)
        card.bounds = { x = x, y = y, w = cardWidth, h = cardHeight }
    end

    love.graphics.setFont(UI.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.7)
    local keyHint
    local choices = #self.cards
    if choices > 0 then
        keyHint = string.format("Press 1-%d to claim a relic", choices)
    else
        keyHint = "No relics available"
    end
    love.graphics.printf(keyHint, 0, screenH * 0.82, screenW, "center")

    if self.selected then
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(1, 0.88, 0.6, 0.9)
        love.graphics.printf(
            string.format("%s claimed", self.selected.name or "Relic"),
            0,
            screenH * 0.87,
            screenW,
            "center"
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

local function pickIndexFromKey(key)
    if key == "1" or key == "kp1" then return 1 end
    if key == "2" or key == "kp2" then return 2 end
    if key == "3" or key == "kp3" then return 3 end
    if key == "4" or key == "kp4" then return 4 end
    if key == "5" or key == "kp5" then return 5 end
end

function Shop:keypressed(key)
    local index = pickIndexFromKey(key)
    if index then
        return self:pick(index)
    end
end

function Shop:mousepressed(x, y, button)
    if button ~= 1 then return end
    for i, card in ipairs(self.cards) do
        local b = card.bounds
        if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return self:pick(i)
        end
    end
end

function Shop:pick(i)
    local card = self.cards[i]
    if not card then return false end

    Upgrades:acquire(card, { floor = self.floor })
    self.selected = card
    return true
end

return Shop
