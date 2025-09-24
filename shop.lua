local UI = require("ui")
local Shop = {}
local Upgrades = require("upgrades")

function Shop:start()
    self.cards = Upgrades:getRandom(3)
    self.selected = nil
end

function Shop:update(dt)
    -- could add animations later
end

function Shop:draw(screenW, screenH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.title)
    love.graphics.printf("Choose an Upgrade", 0, screenH * 0.15, screenW, "center")

    -- Card dimensions
    local cardWidth, cardHeight = 220, 300
    local spacing = 40

    -- Center the row of cards
    local totalWidth = (#self.cards * cardWidth) + ((#self.cards - 1) * spacing)
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.35

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(self.cards) do
        local x = startX + (i-1) * (cardWidth + spacing)

        -- Hover check
        local hovered = mx >= x and mx <= x + cardWidth and my >= y and my <= y + cardHeight

        -- Background
        if hovered then
            love.graphics.setColor(0.35, 0.65, 0.35, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 1)
        end
        love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, 12, 12)

        -- Border
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 12, 12)

        -- Title
        love.graphics.setFont(UI.fonts.button)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(card.name, x + 10, y + 20, cardWidth - 20, "center")

        -- Separator line
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 20, y + 60, x + cardWidth - 20, y + 60)

        -- Description
        love.graphics.setFont(UI.fonts.body)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(card.desc, x + 15, y + 80, cardWidth - 30, "center")

        -- Save bounds for clicking
        card.bounds = {x = x, y = y, w = cardWidth, h = cardHeight}
    end
end

function Shop:keypressed(key)
    if key == "1" or key == "kp1" then return self:pick(1) end
    if key == "2" or key == "kp2" then return self:pick(2) end
    if key == "3" or key == "kp3" then return self:pick(3) end
end

function Shop:mousepressed(x, y, button)
    if button == 1 then
        for i, card in ipairs(self.cards) do
            local b = card.bounds
            if b and x >= b.x and x <= b.x+b.w and y >= b.y and y <= b.y+b.h then
                return self:pick(i)
            end
        end
    end
end

function Shop:pick(i)
    local card = self.cards[i]
    if card then
        card.apply()
        self.selected = card
        return true
    end
    return false
end

return Shop