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
    self.cardStates = {}
    self.time = 0
    self.selectionProgress = 0
    for i = 1, #self.cards do
        self.cardStates[i] = {
            progress = 0,
            delay = (i - 1) * 0.08,
            selection = 0,
            selectionClock = 0,
            focus = 0,
            fadeOut = 0,
        }
    end
end

function Shop:update(dt)
    if not dt then return end
    self.time = (self.time or 0) + dt
    if not self.cardStates then return end

    self.selectionProgress = self.selectionProgress or 0
    if self.selected then
        self.selectionProgress = math.min(1, self.selectionProgress + dt * 2.4)
    else
        self.selectionProgress = math.max(0, self.selectionProgress - dt * 3)
    end

    for i, state in ipairs(self.cardStates) do
        if self.time >= state.delay and state.progress < 1 then
            state.progress = math.min(1, state.progress + dt * 3.2)
        end

        local card = self.cards and self.cards[i]
        local isSelected = card and self.selected == card
        if isSelected then
            state.selection = math.min(1, (state.selection or 0) + dt * 4)
            state.selectionClock = (state.selectionClock or 0) + dt
            state.focus = math.min(1, (state.focus or 0) + dt * 3)
            state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 4)
        else
            state.selection = math.max(0, (state.selection or 0) - dt * 3)
            if state.selection <= 0.001 then
                state.selectionClock = 0
            else
                state.selectionClock = (state.selectionClock or 0) + dt
            end
            if self.selected then
                state.fadeOut = math.min(1, (state.fadeOut or 0) + dt * 3.2)
                state.focus = math.max(0, (state.focus or 0) - dt * 4)
            else
                state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 3)
                state.focus = math.max(0, (state.focus or 0) - dt * 3)
            end
        end
    end
end

local rarityBorderAlpha = 0.85

local function drawCard(card, x, y, w, h, hovered, index, _, isSelected, appearanceAlpha)
    local fadeAlpha = appearanceAlpha or 1
    local function setColor(r, g, b, a)
        love.graphics.setColor(r, g, b, (a or 1) * fadeAlpha)
    end

    if isSelected then
        local glowClock = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local pulse = 0.35 + 0.25 * (math.sin(glowClock * 5) * 0.5 + 0.5)
        setColor(1, 0.9, 0.45, pulse)
        love.graphics.setLineWidth(10)
        love.graphics.rectangle("line", x - 14, y - 14, w + 28, h + 28, 18, 18)
        love.graphics.setLineWidth(4)
    end

    local base = hovered and 0.28 or 0.22
    local bgColor = {base, base * 0.92, base * 0.65, 1}
    setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)

    local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}
    setColor(borderColor[1], borderColor[2], borderColor[3], rarityBorderAlpha)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    if hovered or isSelected then
        local glowAlpha = hovered and 0.55 or 0.35
        setColor(borderColor[1], borderColor[2], borderColor[3], glowAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12, 10, 10)
    end

    setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.fonts.button)
    love.graphics.printf(card.name, x + 14, y + 24, w - 28, "center")

    if index then
        love.graphics.setFont(UI.fonts.small)
        setColor(1, 1, 1, 0.65)
        love.graphics.printf("[" .. tostring(index) .. "]", x + 18, y + 8, w - 36, "left")
        setColor(1, 1, 1, 1)
    end

    if card.rarityLabel then
        love.graphics.setFont(UI.fonts.body)
        setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
        love.graphics.printf(card.rarityLabel, x + 14, y + 64, w - 28, "center")
        setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 24, y + 92, x + w - 24, y + 92)
    else
        setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 24, y + 68, x + w - 24, y + 68)
    end

    love.graphics.setFont(UI.fonts.body)
    setColor(0.92, 0.92, 0.92, 1)
    local descY = card.rarityLabel and (y + 108) or (y + 80)
    if card.upgrade and card.upgrade.tags and #card.upgrade.tags > 0 then
        love.graphics.setFont(UI.fonts.small)
        setColor(0.8, 0.85, 0.9, 0.9)
        love.graphics.printf(table.concat(card.upgrade.tags, " • "), x + 18, descY, w - 36, "center")
        descY = descY + 22
        love.graphics.setFont(UI.fonts.body)
        setColor(0.92, 0.92, 0.92, 1)
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

    local selectionOverlay = self.selectionProgress or 0
    if selectionOverlay > 0 then
        local overlayEase = selectionOverlay * selectionOverlay * (3 - 2 * selectionOverlay)
        love.graphics.setColor(0, 0, 0, 0.35 * overlayEase)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local cardWidth, cardHeight = 264, 344
    local spacing = 48
    local totalWidth = (#self.cards * cardWidth) + math.max(0, (#self.cards - 1)) * spacing
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.34

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(self.cards) do
        local baseX = startX + (i - 1) * (cardWidth + spacing)
        local alpha = 1
        local scale = 1
        local yOffset = 0
        local state = self.cardStates and self.cardStates[i]
        if state then
            local progress = state.progress or 0
            local eased = progress * progress * (3 - 2 * progress)
            alpha = eased
            yOffset = (1 - eased) * 48
            scale = 0.94 + 0.06 * eased

            local selection = state.selection or 0
            if selection > 0 then
                local pulse = 1 + 0.05 * math.sin((state.selectionClock or 0) * 8)
                scale = scale * (1 + 0.08 * selection) * pulse
                alpha = math.min(1, alpha * (1 + 0.2 * selection))
            end
        end

        local focus = state and state.focus or 0
        local fadeOut = state and state.fadeOut or 0
        local focusEase = focus * focus * (3 - 2 * focus)
        local fadeEase = fadeOut * fadeOut * (3 - 2 * fadeOut)

        if card == self.selected then
            yOffset = yOffset + 46 * focusEase
            scale = scale * (1 + 0.35 * focusEase)
            alpha = math.min(1, alpha * (1 + 0.6 * focusEase))
        else
            yOffset = yOffset - 32 * fadeEase
            scale = scale * (1 - 0.2 * fadeEase)
            alpha = alpha * (1 - 0.9 * fadeEase)
        end

        alpha = math.max(0, math.min(alpha, 1))

        local centerX = baseX + cardWidth / 2
        local centerY = y + cardHeight / 2 - yOffset

        if card == self.selected then
            centerX = centerX + (screenW / 2 - centerX) * focusEase
            local targetY = screenH * 0.48
            centerY = centerY + (targetY - centerY) * focusEase
        else
            centerY = centerY + 28 * fadeEase
        end

        local drawWidth = cardWidth * scale
        local drawHeight = cardHeight * scale
        local drawX = centerX - drawWidth / 2
        local drawY = centerY - drawHeight / 2

        local hovered = not self.selected
            and mx >= drawX and mx <= drawX + drawWidth
            and my >= drawY and my <= drawY + drawHeight

        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-cardWidth / 2, -cardHeight / 2)
        drawCard(card, 0, 0, cardWidth, cardHeight, hovered, i, nil, self.selected == card, alpha)
        love.graphics.pop()
        card.bounds = { x = drawX, y = drawY, w = drawWidth, h = drawHeight }
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
    if self.selected then return false end
    local card = self.cards[i]
    if not card then return false end

    Upgrades:acquire(card, { floor = self.floor })
    self.selected = card
    return true
end

return Shop
