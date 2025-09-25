local UI = require("ui")
local Upgrades = require("upgrades")

local Shop = {}

function Shop:start(currentFloor)
    self.floor = currentFloor or 1
    self.cards = Upgrades:getRandom(3, { floor = self.floor }) or {}
    self.selected = nil
end

function Shop:update(dt)
    -- reserved for future animations
end

local rarityBorderAlpha = 0.85

local function drawCard(card, x, y, w, h, hovered)
    local bgColor = hovered and {0.28, 0.35, 0.28, 1} or {0.2, 0.2, 0.2, 1}
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)

    local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], rarityBorderAlpha)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.printf(card.name, x + 14, y + 24, w - 28, "center")

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
    love.graphics.printf(card.desc or "", x + 18, descY, w - 36, "center")
end

function Shop:draw(screenW, screenH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.title)
    love.graphics.printf("Choose an Upgrade", 0, screenH * 0.15, screenW, "center")

    local cardWidth, cardHeight = 240, 320
    local spacing = 48
    local totalWidth = (#self.cards * cardWidth) + math.max(0, (#self.cards - 1)) * spacing
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.34

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(self.cards) do
        local x = startX + (i - 1) * (cardWidth + spacing)
        local hovered = mx >= x and mx <= x + cardWidth and my >= y and my <= y + cardHeight
        drawCard(card, x, y, cardWidth, cardHeight, hovered)
        card.bounds = { x = x, y = y, w = cardWidth, h = cardHeight }
    end
end

local function pickIndexFromKey(key)
    if key == "1" or key == "kp1" then return 1 end
    if key == "2" or key == "kp2" then return 2 end
    if key == "3" or key == "kp3" then return 3 end
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
