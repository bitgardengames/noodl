local UI = require("ui")
local Upgrades = require("upgrades")
local Audio = require("audio")
local MetaProgression = require("metaprogression")
local Score = require("score")

local Shop = {}

local rarityCostMultipliers = {
    common = 0.9,
    uncommon = 1.1,
    rare = 1.55,
    epic = 2.1,
    legendary = 2.8,
}

local rarityCostBonus = {
    common = 0,
    uncommon = 1,
    rare = 2,
    epic = 4,
    legendary = 6,
}

local MIN_CARD_COST = 3

local function round(value)
    return math.floor((value or 0) + 0.5)
end

function Shop:getFruitGoal()
    local goal
    if UI and UI.getFruitGoal then
        goal = UI:getFruitGoal()
    end
    goal = goal or self.fruitGoal or 6
    return math.max(4, goal)
end

function Shop:getCardCost(card)
    if not card then return MIN_CARD_COST end
    local goal = self:getFruitGoal()
    local base = goal * 0.85
    local rarity = card.rarity or "common"
    local mult = rarityCostMultipliers[rarity] or rarityCostMultipliers.common
    local bonus = rarityCostBonus[rarity] or 0
    local cost = round(base * mult + bonus)
    if cost < MIN_CARD_COST then
        cost = MIN_CARD_COST
    end
    return cost
end

function Shop:updateCardCosts()
    self.fruitGoal = self:getFruitGoal()
    if not self.cards then return end
    for _, card in ipairs(self.cards) do
        card.cost = self:getCardCost(card)
        card.purchased = false
    end
end

function Shop:getCurrency()
    if not Score or not Score.getFruitCurrency then
        return 0
    end
    return Score:getFruitCurrency()
end

function Shop:findFirstAvailableIndex()
    if not self.cards then return nil end
    for i, card in ipairs(self.cards) do
        if card and not card.purchased then
            return i
        end
    end
    return nil
end

function Shop:findNextAvailableIndex(startIndex, direction)
    if not self.cards or #self.cards == 0 then return nil end
    local count = #self.cards
    local dir = direction or 1
    if dir == 0 then dir = 1 end
    local index = startIndex or 1
    for _ = 1, count do
        index = ((index - 1 + dir) % count) + 1
        local card = self.cards[index]
        if card and not card.purchased then
            return index
        end
    end
    return nil
end

function Shop:focusFirstAvailable()
    local index = self:findFirstAvailableIndex()
    if index then
        self:setFocus(index)
    else
        self.focusIndex = nil
    end
end

function Shop:ensureValidFocus()
    if not self.cards or #self.cards == 0 then
        self.focusIndex = nil
        return
    end

    if not self.focusIndex then
        self:focusFirstAvailable()
        return
    end

    local current = self.cards[self.focusIndex]
    if current and not current.purchased then
        return
    end

    local nextIndex = self:findNextAvailableIndex(self.focusIndex, 1)
    if not nextIndex then
        nextIndex = self:findNextAvailableIndex(self.focusIndex, -1)
    end

    if nextIndex then
        self.focusIndex = nextIndex
    else
        self.focusIndex = nil
    end
end

function Shop:start(currentFloor)
    self.floor = currentFloor or 1
    self.shopkeeperLine = "Spend your fruit score before the next descent."
    self.shopkeeperSubline = "Buy as many upgrades as you can afford, then press Esc or B to return."
    self.selectionHoldDuration = 0.75
    self.inputMode = nil
    self.fruitGoal = self:getFruitGoal()
    self:refreshCards()
end

function Shop:refreshCards(options)
    options = options or {}
    local initialDelay = options.initialDelay or 0

    self.restocking = nil
    local baseChoices = 2
    local upgradeBonus = 0
    if Upgrades.getEffect then
        upgradeBonus = math.max(0, math.floor(Upgrades:getEffect("shopSlots") or 0))
    end

    local metaBonus = 0
    if MetaProgression and MetaProgression.getShopBonusSlots then
        metaBonus = math.max(0, MetaProgression:getShopBonusSlots() or 0)
    end

    local extraChoices = upgradeBonus + metaBonus

    self.baseChoices = baseChoices
    self.upgradeBonusChoices = upgradeBonus
    self.metaBonusChoices = metaBonus
    self.extraChoices = extraChoices

    local cardCount = baseChoices + extraChoices
    self.totalChoices = cardCount
    self.cards = Upgrades:getRandom(cardCount, { floor = self.floor }) or {}
    self:updateCardCosts()
    self.cardStates = {}
    self.selected = nil
    self.selectedIndex = nil
    self.selectionProgress = 0
    self.selectionTimer = 0
    self.selectionComplete = false
    self.time = 0
    self.focusIndex = nil

    if #self.cards > 0 then
        self:focusFirstAvailable()
    end

    for i = 1, #self.cards do
        self.cardStates[i] = {
            progress = 0,
            delay = initialDelay + (i - 1) * 0.08,
            selection = 0,
            selectionClock = 0,
            hover = 0,
            focus = 0,
            fadeOut = 0,
            selectionFlash = nil,
            revealSoundPlayed = false,
            selectSoundPlayed = false,
        }
    end
end

function Shop:beginRestock()
    if self.restocking then return end

    self.restocking = {
        phase = "fadeOut",
        timer = 0,
        fadeDuration = 0.35,
        delayAfterFade = 0.12,
        revealDelay = 0.1,
    }

    self.selected = nil
    self.selectedIndex = nil
    self.selectionTimer = 0
    self.selectionComplete = false
    self.focusIndex = nil
end

function Shop:setFocus(index)
    if self.restocking then return end
    if not self.cards or not index then return end
    if index < 1 or index > #self.cards then return end
    local card = self.cards[index]
    if not card or card.purchased then
        local nextIndex = self:findNextAvailableIndex(index, 1)
        if not nextIndex then
            nextIndex = self:findNextAvailableIndex(index, -1)
        end
        if not nextIndex then
            self.focusIndex = nil
            return nil
        end
        index = nextIndex
    end
    local previous = self.focusIndex
    if previous and previous ~= index then
        Audio:playSound("shop_focus")
    end
    self.focusIndex = index
    return self.cards[index]
end

function Shop:moveFocus(delta)
    if self.restocking then return end
    if not delta or delta == 0 then return end
    if not self.cards or #self.cards == 0 then return end

    local current = self.focusIndex
    if not current then
        current = self:findFirstAvailableIndex()
        if not current then return end
    end

    local direction = delta > 0 and 1 or -1
    local nextIndex = self:findNextAvailableIndex(current, direction)
    if not nextIndex then
        nextIndex = self:findNextAvailableIndex(current, -direction)
    end

    if nextIndex then
        return self:setFocus(nextIndex)
    end
end

function Shop:update(dt)
    if not dt then return end
    self.time = (self.time or 0) + dt
    if not self.cardStates then return end

    local restock = self.restocking
    local restockProgress = nil
    if restock then
        restock.timer = (restock.timer or 0) + dt
        if restock.phase == "fadeOut" then
            local duration = restock.fadeDuration or 0.35
            if duration <= 0 then
                restock.progress = 1
            else
                restock.progress = math.min(1, restock.timer / duration)
            end
            restockProgress = restock.progress
            if restock.progress >= 1 then
                restock.phase = "waiting"
                restock.timer = 0
            end
        elseif restock.phase == "waiting" then
            restockProgress = 1
            local delay = restock.delayAfterFade or 0
            if restock.timer >= delay then
                local revealDelay = restock.revealDelay or 0
                self.restocking = nil
                self:refreshCards({ initialDelay = revealDelay })
                return
            end
        end
    end

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

        if not state.revealSoundPlayed and self.time >= state.delay then
            state.revealSoundPlayed = true
            Audio:playSound("shop_card_deal")
        end

        local card = self.cards and self.cards[i]
        local isSelected = card and self.selected == card
        local isFocused = (self.focusIndex == i) and not self.selected
        if isSelected then
            state.selection = math.min(1, (state.selection or 0) + dt * 4)
            state.selectionClock = (state.selectionClock or 0) + dt
            state.focus = math.min(1, (state.focus or 0) + dt * 3)
            state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 4)
            state.hover = math.max(0, (state.hover or 0) - dt * 6)
            if not state.selectSoundPlayed then
                state.selectSoundPlayed = true
                Audio:playSound("shop_card_select")
            end
        else
            state.selection = math.max(0, (state.selection or 0) - dt * 3)
            if state.selection <= 0.001 then
                state.selectionClock = 0
            else
                state.selectionClock = (state.selectionClock or 0) + dt
            end
            if isFocused and not restock then
                state.hover = math.min(1, (state.hover or 0) + dt * 6)
            else
                state.hover = math.max(0, (state.hover or 0) - dt * 4)
            end
            if restock then
                local fadeTarget = restockProgress or 0
                state.fadeOut = math.max(fadeTarget, math.min(1, (state.fadeOut or 0) + dt * 3.2))
                state.focus = math.max(0, (state.focus or 0) - dt * 4)
            elseif self.selected then
                state.fadeOut = math.min(1, (state.fadeOut or 0) + dt * 3.2)
                state.focus = math.max(0, (state.focus or 0) - dt * 4)
            else
                state.fadeOut = math.max(0, (state.fadeOut or 0) - dt * 3)
                state.focus = math.max(0, (state.focus or 0) - dt * 3)
            end
            state.selectSoundPlayed = false
        end

        if state.selectionFlash then
            local flashDuration = 0.75
            state.selectionFlash = state.selectionFlash + dt
            if state.selectionFlash >= flashDuration then
                state.selectionFlash = nil
            end
        end
    end

    if self.selected then
        self.selectionTimer = (self.selectionTimer or 0) + dt
        if not self.selectionComplete then
            local hold = self.selectionHoldDuration or 0
            local state = self.selectedIndex and self.cardStates and self.cardStates[self.selectedIndex] or nil
            local flashDone = not (state and state.selectionFlash)
            if self.selectionTimer >= hold and flashDone then
                self.selectionComplete = true
                Audio:playSound("shop_purchase")
            end
        end
    else
        self.selectionTimer = 0
        self.selectionComplete = false
        self.selectedIndex = nil
    end

    if self.selectionComplete and self.selected then
        self.selected = nil
        self.selectedIndex = nil
        self.selectionComplete = false
        self.selectionTimer = 0
        if not self.restocking then
            self:ensureValidFocus()
        end
    end
end

local rarityBorderAlpha = 0.85

local rarityStyles = {
    common = {
        base = {0.20, 0.23, 0.28, 1},
        shadowAlpha = 0.18,
        aura = {
            color = {0.52, 0.62, 0.78, 0.22},
            radius = 0.72,
            y = 0.42,
        },
        outerGlow = {
            color = {0.62, 0.74, 0.92, 1},
            min = 0.04,
            max = 0.14,
            speed = 1.4,
            expand = 5,
            width = 6,
        },
        innerGlow = {
            color = {0.82, 0.90, 1.0, 1},
            min = 0.06,
            max = 0.18,
            speed = 1.2,
            inset = 8,
            width = 2,
        },
    },
    uncommon = {
        base = {0.18, 0.28, 0.22, 1},
        shadowAlpha = 0.24,
        aura = {
            color = {0.46, 0.78, 0.56, 0.28},
            radius = 0.76,
            y = 0.40,
        },
        outerGlow = {
            color = {0.52, 0.92, 0.64, 1},
            min = 0.08,
            max = 0.24,
            speed = 1.6,
            expand = 6,
            width = 6,
        },
        innerGlow = {
            color = {0.68, 0.96, 0.78, 1},
            min = 0.10,
            max = 0.28,
            speed = 1.8,
            inset = 8,
            width = 3,
        },
    },
    rare = {
        base = {0.16, 0.24, 0.34, 1},
        shadowAlpha = 0.30,
        aura = {
            color = {0.40, 0.60, 0.92, 0.32},
            radius = 0.82,
            y = 0.36,
        },
        outerGlow = {
            color = {0.48, 0.72, 1.0, 1},
            min = 0.14,
            max = 0.32,
            speed = 1.9,
            expand = 7,
            width = 7,
        },
        innerGlow = {
            color = {0.64, 0.84, 1.0, 1},
            min = 0.16,
            max = 0.36,
            speed = 2.1,
            inset = 8,
            width = 3,
        },
    },
    epic = {
        base = {0.26, 0.16, 0.36, 1},
        shadowAlpha = 0.34,
        aura = {
            color = {0.82, 0.64, 0.98, 0.34},
            radius = 0.86,
            y = 0.38,
        },
        outerGlow = {
            color = {0.88, 0.72, 1.0, 1},
            min = 0.18,
            max = 0.40,
            speed = 2.2,
            expand = 8,
            width = 8,
        },
        innerGlow = {
            color = {0.96, 0.84, 1.0, 1},
            min = 0.22,
            max = 0.42,
            speed = 2.4,
            inset = 8,
            width = 3,
        },
    },
    legendary = {
        base = {0.40, 0.22, 0.08, 1},
        shadowAlpha = 0.42,
        aura = {
            color = {1.0, 0.64, 0.28, 0.42},
            radius = 0.92,
            y = 0.4,
        },
        outerGlow = {
            color = {1.0, 0.74, 0.36, 1},
            min = 0.22,
            max = 0.48,
            speed = 2.5,
            expand = 9,
            width = 9,
        },
        innerGlow = {
            color = {1.0, 0.84, 0.52, 1},
            min = 0.26,
            max = 0.5,
            speed = 2.8,
            inset = 8,
            width = 3,
        },
    },
}

local function applyColor(setColorFn, color, overrideAlpha)
    if not color then return end
    setColorFn(color[1], color[2], color[3], overrideAlpha or color[4] or 1)
end

local function withTransformedScissor(x, y, w, h, fn)
    if not fn then return end

    local sx1, sy1 = love.graphics.transformPoint(x, y)
    local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)

    local scissorX = math.min(sx1, sx2)
    local scissorY = math.min(sy1, sy2)
    local scissorW = math.abs(sx2 - sx1)
    local scissorH = math.abs(sy2 - sy1)

    if scissorW <= 0 or scissorH <= 0 then
        fn()
        return
    end

    local previous = { love.graphics.getScissor() }
    love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
    fn()
    if previous[1] then
        love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
    else
        love.graphics.setScissor()
    end
end

local function getAnimatedAlpha(def, time)
    if not def then return nil end
    local minAlpha = def.min or def.alpha or 0
    local maxAlpha = def.max or def.alpha or minAlpha
    if not def.speed or maxAlpha == minAlpha then
        return maxAlpha
    end
    local phase = def.phase or 0
    local wave = math.sin(time * def.speed + phase) * 0.5 + 0.5
    return minAlpha + (maxAlpha - minAlpha) * wave
end

local function drawCard(card, x, y, w, h, hovered, index, _, isSelected, appearanceAlpha, currency, affordable)
    local fadeAlpha = appearanceAlpha or 1
    local function setColor(r, g, b, a)
        love.graphics.setColor(r, g, b, (a or 1) * fadeAlpha)
    end

    local style = rarityStyles[card.rarity or "common"] or rarityStyles.common
    local borderColor = card.rarityColor or {1, 1, 1, rarityBorderAlpha}

    if isSelected then
        local glowClock = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local pulse = 0.35 + 0.25 * (math.sin(glowClock * 5) * 0.5 + 0.5)
        setColor(1, 0.9, 0.45, pulse)
        love.graphics.setLineWidth(10)
        love.graphics.rectangle("line", x - 14, y - 14, w + 28, h + 28, 18, 18)
        love.graphics.setLineWidth(4)
    end

    if style.shadowAlpha and style.shadowAlpha > 0 then
        setColor(0, 0, 0, style.shadowAlpha)
        love.graphics.rectangle("fill", x + 6, y + 10, w, h, 18, 18)
    end

    applyColor(setColor, style.base)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)

    local currentTime = (love.timer and love.timer.getTime and love.timer.getTime()) or 0

    if style.aura then
        withTransformedScissor(x, y, w, h, function()
            applyColor(setColor, style.aura.color)
            local radius = math.max(w, h) * (style.aura.radius or 0.72)
            local centerY = y + h * (style.aura.y or 0.4)
            love.graphics.circle("fill", x + w * 0.5, centerY, radius)
        end)
    end

    if style.outerGlow then
        local glowAlpha = getAnimatedAlpha(style.outerGlow, currentTime)
        if glowAlpha and glowAlpha > 0 then
            applyColor(setColor, style.outerGlow.color or borderColor, glowAlpha)
            love.graphics.setLineWidth(style.outerGlow.width or 6)
            local expand = style.outerGlow.expand or 6
            love.graphics.rectangle("line", x - expand, y - expand, w + expand * 2, h + expand * 2, 18, 18)
        end
    end
    if style.flare then
        withTransformedScissor(x, y, w, h, function()
            applyColor(setColor, style.flare.color)
            local radius = math.min(w, h) * (style.flare.radius or 0.36)
            love.graphics.circle("fill", x + w * 0.5, y + h * 0.32, radius)
        end)
    end

    if style.stripes then
        withTransformedScissor(x, y, w, h, function()
            love.graphics.push()
            love.graphics.translate(x + w / 2, y + h / 2)
            love.graphics.rotate(style.stripes.angle or -math.pi / 6)
            local diag = math.sqrt(w * w + h * h)
            local spacing = style.stripes.spacing or 34
            local width = style.stripes.width or 22
            applyColor(setColor, style.stripes.color)
            local stripeCount = math.ceil((diag * 2) / spacing) + 2
            for i = -stripeCount, stripeCount do
                local pos = i * spacing
                love.graphics.rectangle("fill", -diag, pos - width / 2, diag * 2, width)
            end
            love.graphics.pop()
        end)
    end

    if style.sparkles and style.sparkles.positions then
        withTransformedScissor(x, y, w, h, function()
            local time = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
            for i, pos in ipairs(style.sparkles.positions) do
                local px, py, scale = pos[1], pos[2], pos[3] or 1
                local pulse = 0.6 + 0.4 * math.sin(time * (style.sparkles.speed or 1.8) + i * 0.9)
                local radius = (style.sparkles.radius or 9) * scale * pulse
                local sparkleColor = style.sparkles.color or borderColor
                local sparkleAlpha = (sparkleColor[4] or 1) * pulse
                applyColor(setColor, sparkleColor, sparkleAlpha)
                love.graphics.circle("fill", x + px * w, y + py * h, radius)
            end
        end)
    end

    if style.glow and style.glow > 0 then
        applyColor(setColor, borderColor, style.glow)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, 16, 16)
    end

    applyColor(setColor, borderColor, rarityBorderAlpha)
    love.graphics.setLineWidth(style.borderWidth or 4)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    local hoverGlowAlpha
    if style.innerGlow then
        hoverGlowAlpha = getAnimatedAlpha(style.innerGlow, currentTime)
    end

    if hovered or isSelected then
        local focusAlpha = hovered and 0.6 or 0.4
        hoverGlowAlpha = math.max(hoverGlowAlpha or 0, focusAlpha)
    end

    if hoverGlowAlpha and hoverGlowAlpha > 0 then
        local innerColor = (style.innerGlow and style.innerGlow.color) or borderColor
        local inset = (style.innerGlow and style.innerGlow.inset) or 6
        love.graphics.setLineWidth((style.innerGlow and style.innerGlow.width) or 2)
        applyColor(setColor, innerColor, hoverGlowAlpha)
        love.graphics.rectangle("line", x + inset, y + inset, w - inset * 2, h - inset * 2, 10, 10)
    elseif hovered or isSelected then
        local glowAlpha = hovered and 0.55 or 0.35
        applyColor(setColor, borderColor, glowAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12, 10, 10)
    end

    love.graphics.setLineWidth(4)

    setColor(1, 1, 1, 1)
    local titleFont = UI.fonts.button
    love.graphics.setFont(titleFont)
    local titleWidth = w - 28
    local titleY = y + 24
    love.graphics.printf(card.name, x + 14, titleY, titleWidth, "center")

    local _, titleLines = titleFont:getWrap(card.name or "", titleWidth)
    local titleLineCount = math.max(1, #titleLines)
    local titleHeight = titleLineCount * titleFont:getHeight() * titleFont:getLineHeight()
    local contentTop = titleY + titleHeight

    local descStart
    if card.rarityLabel then
        local rarityFont = UI.fonts.body
        love.graphics.setFont(rarityFont)
        setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
        local rarityY = contentTop + 10
        love.graphics.printf(card.rarityLabel, x + 14, rarityY, titleWidth, "center")

        setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        local rarityHeight = rarityFont:getHeight() * rarityFont:getLineHeight()
        local dividerY = rarityY + rarityHeight + 8
        love.graphics.line(x + 24, dividerY, x + w - 24, dividerY)
        descStart = dividerY + 16
    else
        setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        local dividerY = contentTop + 14
        love.graphics.line(x + 24, dividerY, x + w - 24, dividerY)
        descStart = dividerY + 16
    end

    love.graphics.setFont(UI.fonts.body)
    setColor(0.92, 0.92, 0.92, 1)
    local descY = descStart
    if card.upgrade and card.upgrade.tags and #card.upgrade.tags > 0 then
        love.graphics.setFont(UI.fonts.small)
        setColor(0.8, 0.85, 0.9, 0.9)
        love.graphics.printf(table.concat(card.upgrade.tags, " • "), x + 18, descY, w - 36, "center")
        descY = descY + 22
        love.graphics.setFont(UI.fonts.body)
        setColor(0.92, 0.92, 0.92, 1)
    end
    love.graphics.printf(card.desc or "", x + 18, descY, w - 36, "center")

    local panelTop = y + h - 86
    local panelHeight = 64
    local cost = card.cost or 0
    local currentCurrency = currency or 0
    local canAfford = affordable
    if canAfford == nil then
        canAfford = currentCurrency >= cost
    end
    local missing = math.max(0, cost - currentCurrency)

    setColor(0, 0, 0, card.purchased and 0.55 or 0.32)
    love.graphics.rectangle("fill", x + 16, panelTop, w - 32, panelHeight, 12, 12)

    setColor(1, 1, 1, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 16, panelTop, w - 32, panelHeight, 12, 12)

    if card.purchased then
        love.graphics.setFont(UI.fonts.button)
        setColor(0.82, 0.94, 1.0, 0.95)
        love.graphics.printf("Purchased", x + 16, panelTop + 16, w - 32, "center")
    else
        love.graphics.setFont(UI.fonts.button)
        if canAfford then
            setColor(1, 0.88, 0.5, 1)
        else
            setColor(1, 0.45, 0.45, 1)
        end
        love.graphics.printf(string.format("%d Fruit", cost), x + 16, panelTop + 10, w - 32, "center")

        love.graphics.setFont(UI.fonts.small)
        if canAfford then
            setColor(1, 1, 1, 0.75)
            love.graphics.printf("Hold to buy", x + 16, panelTop + 38, w - 32, "center")
        else
            setColor(1, 0.75, 0.75, 0.9)
            if missing > 0 then
                love.graphics.printf(string.format("Need %d more", missing), x + 16, panelTop + 38, w - 32, "center")
            else
                love.graphics.printf("Hold to buy", x + 16, panelTop + 38, w - 32, "center")
            end
        end
    end

    love.graphics.setLineWidth(4)
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

    local currency = self:getCurrency()
    love.graphics.setFont(UI.fonts.body)
    love.graphics.setColor(1, 0.9, 0.45, 1)
    love.graphics.printf(string.format("Fruit score: %d", currency), screenW * 0.58, screenH * 0.18, screenW * 0.36, "right")
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
    local cards = self.cards or {}
    local cardCount = #cards
    local totalWidth = (cardCount * cardWidth) + math.max(0, (cardCount - 1)) * spacing
    local startX = (screenW - totalWidth) / 2
    local y = screenH * 0.34

    local mx, my = love.mouse.getPosition()

    local function renderCard(i, card)
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

            local appearScaleMin = 0.94
            local appearScaleMax = 1.0
            scale = appearScaleMin + (appearScaleMax - appearScaleMin) * eased

            local hover = state.hover or 0
            if hover > 0 and not self.selected then
                local hoverEase = hover * hover * (3 - 2 * hover)
                scale = scale * (1 + 0.07 * hoverEase)
                yOffset = yOffset - 8 * hoverEase
            end

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
            alpha = 1
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

        local affordable = (currency or 0) >= (card.cost or 0)
        if card.purchased and card ~= self.selected then
            alpha = alpha * 0.55
        elseif not affordable and card ~= self.selected then
            alpha = alpha * 0.9
        end

        local drawWidth = cardWidth * scale
        local drawHeight = cardHeight * scale
        local drawX = centerX - drawWidth / 2
        local drawY = centerY - drawHeight / 2

        local usingFocusNavigation = self.inputMode == "gamepad" or self.inputMode == "keyboard"
        local mouseHover = mx >= drawX and mx <= drawX + drawWidth
            and my >= drawY and my <= drawY + drawHeight
        if not self.selected and mouseHover and not usingFocusNavigation then
            self:setFocus(i)
        end

        local hovered = not self.selected and (
            (usingFocusNavigation and self.focusIndex == i) or
            (not usingFocusNavigation and mouseHover)
        )
        if card.purchased and card ~= self.selected then
            hovered = false
        end

        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-cardWidth / 2, -cardHeight / 2)
        local appearanceAlpha = self.selected == card and 1 or alpha
        drawCard(card, 0, 0, cardWidth, cardHeight, hovered, i, nil, self.selected == card, appearanceAlpha, currency, affordable)
        love.graphics.pop()
        card.bounds = { x = drawX, y = drawY, w = drawWidth, h = drawHeight }

        if state and state.selectionFlash then
            local flashDuration = 0.75
            local t = math.max(0, math.min(1, state.selectionFlash / flashDuration))
            local ease = 1 - ((1 - t) * (1 - t))
            local ringAlpha = (1 - ease) * 0.8
            local burstAlpha = (1 - ease) * 0.45
            local radiusBase = math.max(cardWidth, cardHeight) * 0.42
            local radius = radiusBase + ease * 180

            love.graphics.setLineWidth(6)
            love.graphics.setColor(1, 0.88, 0.45, ringAlpha)
            love.graphics.circle("line", centerX, centerY, radius)

            local burstRadius = radiusBase * (1 + ease * 0.5)
            love.graphics.setColor(1, 0.72, 0.32, burstAlpha)
            love.graphics.circle("fill", centerX, centerY, burstRadius)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    local selectedIndex
    for i, card in ipairs(cards) do
        if card == self.selected then
            selectedIndex = i
        else
            renderCard(i, card)
        end
    end

    if selectedIndex then
        renderCard(selectedIndex, cards[selectedIndex])
    end

    if self.selected then
        love.graphics.setFont(UI.fonts.button)
        love.graphics.setColor(1, 0.88, 0.6, 0.9)
        love.graphics.printf(
            string.format("%s claimed", self.selected.name or "Relic"),
            0,
            screenH * 0.87,
            screenW,
            "center"
        )
    end

    love.graphics.setFont(UI.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.printf(
        "Right click, press Esc, or press B to return to the run.",
        0,
        screenH * 0.95,
        screenW,
        "center"
    )

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
    if key == "escape" or key == "backspace" then
        self.inputMode = "keyboard"
        return true
    end

    if self.restocking then return end

    local cards = self.cards
    if not cards or #cards == 0 then return end

    local index = pickIndexFromKey(key)
    if index then
        self.inputMode = "keyboard"
        self:pick(index)
        return false
    end

    if self.selected then return end

    if key == "left" or key == "up" then
        self.inputMode = "keyboard"
        self:moveFocus(-1)
        return false
    elseif key == "right" or key == "down" then
        self.inputMode = "keyboard"
        self:moveFocus(1)
        return false
    elseif key == "return" or key == "kpenter" or key == "enter" then
        self.inputMode = "keyboard"
        local focusIndex = self.focusIndex or self:findFirstAvailableIndex() or 1
        self:pick(focusIndex)
        return false
    end
end

function Shop:mousepressed(x, y, button)
    if button == 2 then
        self.inputMode = "mouse"
        return true
    end

    if self.restocking then return end
    if button ~= 1 then return end

    if not self.cards or #self.cards == 0 then return end

    self.inputMode = "mouse"
    for i, card in ipairs(self.cards) do
        local b = card.bounds
        if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            self:setFocus(i)
            self:pick(i)
            return false
        end
    end
end

function Shop:gamepadpressed(_, button)
    if button == "b" or button == "back" then
        self.inputMode = "gamepad"
        return true
    end

    if self.restocking then return end
    if not self.cards or #self.cards == 0 then return end

    self.inputMode = "gamepad"

    if self.selected then return end

    if button == "dpup" or button == "dpleft" then
        self:moveFocus(-1)
        return false
    elseif button == "dpdown" or button == "dpright" then
        self:moveFocus(1)
        return false
    elseif button == "a" or button == "start" then
        local index = self.focusIndex or self:findFirstAvailableIndex() or 1
        self:pick(index)
        return false
    end
end

Shop.joystickpressed = Shop.gamepadpressed

function Shop:pick(i)
    if self.restocking then return false end
    if self.selected then return false end
    local card = self.cards and self.cards[i]
    if not card or card.purchased then return false end

    local cost = card.cost or self:getCardCost(card)
    card.cost = cost

    if not Score:spendFruit(cost) then
        Audio:playSound("shop_focus")
        return false
    end

    local state = self.cardStates and self.cardStates[i]
    if state then
        state.selectionFlash = 0
        state.selectSoundPlayed = true
    end

    card.purchased = true

    if card.restockShop then
        Audio:playSound("shop_card_select")
        self:beginRestock()
        return false
    end

    Upgrades:acquire(card, { floor = self.floor })
    self.selected = card
    self.selectedIndex = i
    self.selectionTimer = 0
    self.selectionComplete = false

    Audio:playSound("shop_card_select")

    local nextIndex = self:findNextAvailableIndex(i, 1) or self:findNextAvailableIndex(i, -1)
    if self.inputMode ~= "mouse" then
        if nextIndex then
            self:setFocus(nextIndex)
        else
            self.focusIndex = nil
        end
    else
        if nextIndex then
            self.focusIndex = nextIndex
        else
            self.focusIndex = nil
        end
    end

    return false
end

function Shop:isSelectionComplete()
    return self.selected == nil and not self.restocking
end

return Shop
