local UI = require("ui")
local Upgrades = require("upgrades")
local Audio = require("audio")

local Shop = {}

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
    self.selectedIndex = nil
    self.shopkeeperLine = nil
    self.shopkeeperSubline = nil
    self.cardStates = {}
    self.time = 0
    self.selectionProgress = 0
    self.selectionTimer = 0
    self.selectionHoldDuration = 1.85
    self.selectionComplete = false
    self.focusIndex = nil
    self.inputMode = nil
    if #self.cards > 0 then
        self:setFocus(1)
    end
    for i = 1, #self.cards do
        self.cardStates[i] = {
            progress = 0,
            delay = (i - 1) * 0.08,
            selection = 0,
            selectionClock = 0,
            focus = 0,
            fadeOut = 0,
            selectionFlash = nil,
        }
    end
end

function Shop:setFocus(index)
    if not self.cards or not index then return end
    if index < 1 or index > #self.cards then return end
    local previous = self.focusIndex
    if previous ~= index then
        Audio:playSound("shop_focus")
    end
    self.focusIndex = index
    return self.cards[index]
end

function Shop:moveFocus(delta)
    if not delta or delta == 0 then return end
    if not self.cards or #self.cards == 0 then return end

    local count = #self.cards
    local index = self.focusIndex or 1
    index = ((index - 1 + delta) % count) + 1
    self.focusIndex = index

    return self.cards[index]
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
            end
        end
    else
        self.selectionTimer = 0
        self.selectionComplete = false
        self.selectedIndex = nil
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
        base = {0.24, 0.16, 0.32, 1},
        shadowAlpha = 0.30,
        aura = {
            color = {0.82, 0.64, 0.98, 0.30},
            radius = 0.82,
            y = 0.36,
        },
        outerGlow = {
            color = {0.86, 0.72, 1.0, 1},
            min = 0.14,
            max = 0.32,
            speed = 1.9,
            expand = 7,
            width = 7,
        },
        innerGlow = {
            color = {0.94, 0.82, 1.0, 1},
            min = 0.16,
            max = 0.36,
            speed = 2.1,
            inset = 8,
            width = 3,
        },
    },
    epic = {
        base = {0.32, 0.14, 0.08, 1},
        shadowAlpha = 0.34,
        aura = {
            color = {1.0, 0.62, 0.36, 0.34},
            radius = 0.86,
            y = 0.38,
        },
        outerGlow = {
            color = {1.0, 0.72, 0.48, 1},
            min = 0.18,
            max = 0.40,
            speed = 2.2,
            expand = 8,
            width = 8,
        },
        innerGlow = {
            color = {1.0, 0.82, 0.62, 1},
            min = 0.22,
            max = 0.42,
            speed = 2.4,
            inset = 8,
            width = 3,
        },
    },
    legendary = {
        base = {0.38, 0.26, 0.04, 1},
        shadowAlpha = 0.42,
        aura = {
            color = {1.0, 0.86, 0.32, 0.42},
            radius = 0.92,
            y = 0.4,
        },
        outerGlow = {
            color = {1.0, 0.9, 0.5, 1},
            min = 0.22,
            max = 0.48,
            speed = 2.5,
            expand = 9,
            width = 9,
        },
        innerGlow = {
            color = {1.0, 0.96, 0.72, 1},
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

local function drawCard(card, x, y, w, h, hovered, index, _, isSelected, appearanceAlpha)
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

    if index then
        love.graphics.setFont(UI.fonts.small)
        setColor(1, 1, 1, 0.65)
        love.graphics.printf("[" .. tostring(index) .. "]", x + 18, y + 8, w - 36, "left")
        setColor(1, 1, 1, 1)
    end

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

            -- Start cards a touch smaller and ease them up to full size so
            -- the reveal animation feels like a gentle pop rather than a flat fade.
            local appearScaleMin = 0.94
            local appearScaleMax = 1.0
            scale = appearScaleMin + (appearScaleMax - appearScaleMin) * eased

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
            -- Make sure the selected card renders at full opacity while it
            -- animates toward the center. Without this clamp the focus easing
            -- could leave it slightly translucent until the animation fully
            -- completes, which felt like a bug. Forcing alpha to 1 keeps the
            -- spotlighted card crisp for the whole animation.
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

        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-cardWidth / 2, -cardHeight / 2)
        local appearanceAlpha = self.selected == card and 1 or alpha
        drawCard(card, 0, 0, cardWidth, cardHeight, hovered, i, nil, self.selected == card, appearanceAlpha)
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
    for i, card in ipairs(self.cards) do
        if card == self.selected then
            selectedIndex = i
        else
            renderCard(i, card)
        end
    end

    if selectedIndex then
        renderCard(selectedIndex, self.cards[selectedIndex])
    end

    love.graphics.setFont(UI.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.7)
    local keyHint
    local choices = #self.cards
    if choices > 0 then
        keyHint = string.format("Press 1-%d or use arrows + Enter to claim a relic", choices)
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
    if not self.cards or #self.cards == 0 then return end

    local index = pickIndexFromKey(key)
    if index then
        self.inputMode = "keyboard"
        return self:pick(index)
    end

    if self.selected then return end

    if key == "left" or key == "up" then
        self.inputMode = "keyboard"
        self:moveFocus(-1)
        return true
    elseif key == "right" or key == "down" then
        self.inputMode = "keyboard"
        self:moveFocus(1)
        return true
    elseif key == "return" or key == "kpenter" or key == "enter" then
        self.inputMode = "keyboard"
        local focusIndex = self.focusIndex or 1
        return self:pick(focusIndex)
    end
end

function Shop:mousepressed(x, y, button)
    if button ~= 1 then return end
    self.inputMode = "mouse"
    for i, card in ipairs(self.cards) do
        local b = card.bounds
        if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            self:setFocus(i)
            return self:pick(i)
        end
    end
end

function Shop:gamepadpressed(_, button)
    if not self.cards or #self.cards == 0 then return end

    self.inputMode = "gamepad"

    if self.selected then return end

    if button == "dpup" or button == "dpleft" then
        self:moveFocus(-1)
    elseif button == "dpdown" or button == "dpright" then
        self:moveFocus(1)
    elseif button == "a" or button == "start" then
        local index = self.focusIndex or 1
        return self:pick(index)
    end
end

Shop.joystickpressed = Shop.gamepadpressed

function Shop:pick(i)
    if self.selected then return false end
    local card = self.cards[i]
    if not card then return false end

    Upgrades:acquire(card, { floor = self.floor })
    self.selected = card
    self.selectedIndex = i
    self.selectionTimer = 0
    self.selectionComplete = false

    local state = self.cardStates and self.cardStates[i]
    if state then
        state.selectionFlash = 0
    end
    Audio:playSound("shop_purchase")
    return true
end

function Shop:isSelectionComplete()
    return self.selected ~= nil and self.selectionComplete == true
end

return Shop
