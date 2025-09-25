local UI = require("ui")
local Upgrades = require("upgrades")

local Shop = {}

local function randomRange(min, max)
    return min + (max - min) * love.math.random()
end

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
    self.time = 0
    self.glowOrbs = {}
    self.sparkles = {}
    self.sparkleCooldown = 0

    for _ = 1, 6 do
        table.insert(self.glowOrbs, {
            angle = love.math.random() * math.pi * 2,
            radius = randomRange(60, 180),
            speed = randomRange(0.25, 0.65),
            size = randomRange(140, 220),
            wobble = randomRange(0.6, 1.2),
            color = {
                randomRange(0.95, 1),
                randomRange(0.55, 0.75),
                randomRange(0.25, 0.45),
                0.17,
            },
        })
    end
end

function Shop:update(dt)
    if not self.time then
        self.time = 0
    end
    self.time = self.time + dt

    self.sparkles = self.sparkles or {}

    if self.glowOrbs then
        for _, orb in ipairs(self.glowOrbs) do
            orb.angle = orb.angle + dt * orb.speed
        end
    end

    if self.sparkleCooldown == nil then
        self.sparkleCooldown = 0
    end

    if self.lastScreenW and self.lastScreenH then
        self.sparkleCooldown = self.sparkleCooldown - dt
        if self.sparkleCooldown <= 0 then
            local duration = randomRange(0.6, 1.2)
            table.insert(self.sparkles, {
                x = randomRange(self.lastScreenW * 0.18, self.lastScreenW * 0.82),
                y = randomRange(self.lastScreenH * 0.25, self.lastScreenH * 0.35),
                vy = randomRange(-22, -12),
                wobble = randomRange(2.5, 4.5),
                baseSize = randomRange(8, 14),
                rotation = love.math.random() * math.pi,
                duration = duration,
                remaining = duration,
                elapsed = 0,
                baseAlpha = randomRange(0.65, 0.9),
                color = {
                    1,
                    randomRange(0.82, 0.95),
                    randomRange(0.45, 0.65),
                },
            })
            self.sparkleCooldown = randomRange(0.12, 0.28)
        end
    end

    for i = #self.sparkles, 1, -1 do
        local s = self.sparkles[i]
        s.elapsed = s.elapsed + dt
        s.remaining = s.remaining - dt
        s.y = s.y + s.vy * dt
        s.x = s.x + math.sin(s.elapsed * s.wobble) * 6 * dt
        s.rotation = s.rotation + dt * 1.3

        local fadeIn = math.min(1, s.elapsed / 0.15)
        local fadeOut = math.min(1, math.max(0, s.remaining) / 0.25)
        s.alpha = s.baseAlpha * math.min(fadeIn, fadeOut)

        if s.remaining <= 0 then
            table.remove(self.sparkles, i)
        end
    end
end

local rarityBorderAlpha = 0.85

local function drawSparkle(s)
    love.graphics.push()
    love.graphics.translate(s.x, s.y)
    love.graphics.rotate(s.rotation)
    local pulse = 1 + 0.2 * math.sin(s.elapsed * 3)
    local size = s.baseSize * pulse
    love.graphics.setColor(s.color[1], s.color[2], s.color[3], s.alpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(-size, 0, size, 0)
    love.graphics.line(0, -size * 0.6, 0, size * 0.6)
    love.graphics.circle("fill", 0, 0, size * 0.35)
    love.graphics.pop()
end

local function drawCard(card, x, y, w, h, hovered, index, time, isSelected)
    local shimmer = math.sin((time or 0) * 2.4 + (index or 0) * 0.9) * 0.04
    local base = hovered and 0.28 or 0.2
    local bgColor = {base + shimmer, base + shimmer * 0.8, base + shimmer * 0.2, 1}
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)

    local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
    local borderAlpha = rarityBorderAlpha + shimmer * 0.5
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
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
    self.lastScreenW, self.lastScreenH = screenW, screenH

    love.graphics.setColor(0.07, 0.08, 0.11, 0.92)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if self.glowOrbs then
        love.graphics.setBlendMode("add")
        for _, orb in ipairs(self.glowOrbs) do
            local baseX = screenW * 0.5
            local baseY = screenH * 0.52
            local offsetX = math.cos(orb.angle) * orb.radius
            local offsetY = math.sin(orb.angle * orb.wobble) * (orb.radius * 0.35)
            love.graphics.setColor(orb.color)
            love.graphics.circle("fill", baseX + offsetX, baseY + offsetY, orb.size)
        end
        love.graphics.setBlendMode("alpha")
    end

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

    local cardWidth, cardHeight = 240, 320
    local spacing = 48
    local totalWidth = (#self.cards * cardWidth) + math.max(0, (#self.cards - 1)) * spacing
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.34

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(self.cards) do
        local x = startX + (i - 1) * (cardWidth + spacing)
        local hovered = mx >= x and mx <= x + cardWidth and my >= y and my <= y + cardHeight
        drawCard(card, x, y, cardWidth, cardHeight, hovered, i, self.time, self.selected == card)
        card.bounds = { x = x, y = y, w = cardWidth, h = cardHeight }
    end

    if self.sparkles and #self.sparkles > 0 then
        love.graphics.setBlendMode("add")
        for _, sparkle in ipairs(self.sparkles) do
            drawSparkle(sparkle)
        end
        love.graphics.setBlendMode("alpha")
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
