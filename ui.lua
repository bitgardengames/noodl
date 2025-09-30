local Audio = require("audio")
local Theme = require("theme")
local Localization = require("localization")

local UI = {}

local scorePulse = 1.0
local pulseTimer = 0
local PULSE_DURATION = 0.3

UI.fruitCollected = 0
UI.fruitRequired = 0
UI.fruitSockets = {}
UI.socketAnimTime = 0.25
UI.socketBounceDuration = 0.65
UI.socketSize = 26
UI.goalReachedAnim = 0
UI.goalCelebrated = false

UI.floorModifiers = {}

UI.combo = {
    count = 0,
    timer = 0,
    duration = 0,
    pop = 0,
}

UI.shields = {
    count = 0,
    display = 0,
    popDuration = 0.32,
    popTimer = 0,
    shakeDuration = 0.45,
    shakeTimer = 0,
    flashDuration = 0.4,
    flashTimer = 0,
    lastDirection = 0,
}

UI.upgradeIndicators = {
    items = {},
    order = {},
    layout = {
        width = 252,
        spacing = 12,
        baseHeight = 58,
        iconRadius = 18,
        barHeight = 6,
        margin = 24,
    },
}

local BUTTON_POP_DURATION = 0.32

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function approachExp(current, target, dt, speed)
    if speed <= 0 or dt <= 0 then
        return target
    end

    local factor = 1 - math.exp(-speed * dt)
    return current + (target - current) * factor
end

local function lightenColor(color, amount)
    if not color then
        return {1, 1, 1, 1}
    end

    local a = color[4] or 1
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
        a,
    }
end

local function darkenColor(color, amount)
    if not color then
        return {0, 0, 0, 1}
    end

    local a = color[4] or 1
    return {
        color[1] * amount,
        color[2] * amount,
        color[3] * amount,
        a,
    }
end

local function setColor(color, alphaMultiplier)
    if not color then
        love.graphics.setColor(1, 1, 1, alphaMultiplier or 1)
        return
    end

    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local a = color[4] or 1
    love.graphics.setColor(r, g, b, a * (alphaMultiplier or 1))
end

-- Button states
UI.buttons = {}

local function createButtonState()
    return {
        pressed = false,
        anim = 0,
        hoverAnim = 0,
        focusAnim = 0,
        hoverTarget = 0,
        glow = 0,
        popProgress = 0,
    }
end

function UI.clearButtons()
    UI.buttons = {}
end

function UI.setButtonFocus(id, focused)
    if not id then return end

    local btn = UI.buttons[id]
    if not btn then
        btn = createButtonState()
        UI.buttons[id] = btn
    end

    btn.focused = focused or nil
end

-- Fonts
UI.fonts = {
    title        = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 72),
    display      = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 64),
    subtitle     = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 32),
    heading      = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 28),
    button       = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 24),
    body         = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 16),
    caption      = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 14),
    small        = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 12),
    timer        = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 42),
    timerSmall   = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 20),
    achieve      = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 18),
    badge        = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 20),
}

UI.colors = {
    background  = Theme.bgColor,
    text        = Theme.textColor,
    subtleText  = {Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], (Theme.textColor[4] or 1) * 0.7},
    button      = Theme.buttonColor,
    buttonHover = Theme.buttonHover or lightenColor(Theme.buttonColor, 0.15),
    buttonPress = Theme.buttonPress or darkenColor(Theme.buttonColor, 0.65),
    border      = Theme.borderColor,
    panel       = Theme.panelColor,
    panelBorder = Theme.panelBorder,
    shadow      = Theme.shadowColor,
    highlight   = Theme.highlightColor or {1, 1, 1, 0.08},
    progress    = Theme.progressColor,
    accentText  = Theme.accentTextColor,
    mutedText   = Theme.mutedTextColor,
    warning     = Theme.warningColor,
}

-- Spacing and layout constants
UI.spacing = {
    buttonWidth       = 260,
    buttonHeight      = 56,
    buttonRadius      = 14,
    buttonSpacing     = 24,
    panelRadius       = 16,
    panelPadding      = 20,
    shadowOffset      = 6,
    sectionSpacing    = 28,
    sliderHeight      = 68,
    sliderTrackHeight = 10,
    sliderHandleRadius= 12,
    sliderPadding     = 22,
}

-- Utility: set font
function UI.setFont(font)
    love.graphics.setFont(UI.fonts[font or "body"])
end

-- Utility: draw rounded rectangle
function UI.drawRoundedRect(x, y, w, h, r)
    r = r or UI.spacing.buttonRadius
    local segments = 8
    love.graphics.rectangle("fill", x + r, y, w - 2 * r, h)
    love.graphics.rectangle("fill", x, y + r, r, h - 2 * r)
    love.graphics.rectangle("fill", x + w - r, y + r, r, h - 2 * r)
    love.graphics.circle("fill", x + r, y + r, r, segments)
    love.graphics.circle("fill", x + w - r, y + r, r, segments)
    love.graphics.circle("fill", x + r, y + h - r, r, segments)
    love.graphics.circle("fill", x + w - r, y + h - r, r, segments)
end

function UI.drawPanel(x, y, w, h, opts)
    opts = opts or {}
    local radius = opts.radius or UI.spacing.panelRadius
    local shadowOffset = opts.shadowOffset
    if shadowOffset == nil then shadowOffset = UI.spacing.shadowOffset end

    if shadowOffset and shadowOffset ~= 0 then
        setColor(opts.shadowColor or UI.colors.shadow, opts.shadowAlpha or 1)
        love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, w, h, radius, radius)
    end

    setColor(opts.fill or UI.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    if opts.border ~= false then
        setColor(opts.borderColor or UI.colors.panelBorder)
        love.graphics.setLineWidth(opts.borderWidth or 2)
        love.graphics.rectangle("line", x, y, w, h, radius, radius)
        love.graphics.setLineWidth(1)
    end

    if opts.focused then
        local focusRadius = radius + (opts.focusRadiusOffset or 4)
        local focusPadding = opts.focusPadding or 3
        setColor(opts.focusColor or UI.colors.border, opts.focusAlpha or 1.1)
        love.graphics.setLineWidth(opts.focusWidth or 3)
        love.graphics.rectangle("line", x - focusPadding, y - focusPadding, w + focusPadding * 2, h + focusPadding * 2, focusRadius, focusRadius)
        love.graphics.setLineWidth(1)
    end
end

function UI.drawLabel(text, x, y, width, align, opts)
    opts = opts or {}
    local font = opts.font or UI.fonts[opts.fontKey or "body"]
    if font then
        love.graphics.setFont(font)
    end

    local color = opts.color or UI.colors.text
    setColor(color, opts.alpha or 1)

    if width then
        love.graphics.printf(text, x, y, width, align or "left")
    else
        love.graphics.print(text, x, y)
    end
end

function UI.drawSlider(id, x, y, w, value, opts)
    opts = opts or {}
    local h = opts.height or UI.spacing.sliderHeight
    local radius = opts.radius or UI.spacing.buttonRadius
    local padding = opts.padding or UI.spacing.sliderPadding
    local trackHeight = opts.trackHeight or UI.spacing.sliderTrackHeight
    local handleRadius = opts.handleRadius or UI.spacing.sliderHandleRadius
    local focused = opts.focused

    if opts.register ~= false and id then
        UI.registerButton(id, x, y, w, h, opts.label)
    end

    local hovered = opts.hovered
    local baseFill = opts.fill or UI.colors.button
    if hovered and not focused then
        baseFill = opts.hoverFill or UI.colors.buttonHover
    end

    UI.drawPanel(x, y, w, h, {
        radius = radius,
        shadowOffset = opts.shadowOffset,
        fill = baseFill,
        borderColor = opts.borderColor or UI.colors.border,
        focused = focused,
        focusColor = opts.focusColor or UI.colors.highlight,
        focusAlpha = opts.focusAlpha,
    })

    local label = opts.label
    if label then
        UI.drawLabel(label, x + padding, y + padding, w - padding * 2, opts.labelAlign or "left", {
            fontKey = opts.labelFont or "body",
            color = opts.labelColor or UI.colors.text,
        })
    end

    local sliderValue = clamp01(value or 0)
    local trackX = x + padding
    local trackW = w - padding * 2
    local trackY = y + h - padding - trackHeight

    setColor(UI.colors.panel, 0.7)
    love.graphics.rectangle("fill", trackX, trackY, trackW, trackHeight, trackHeight / 2, trackHeight / 2)

    if sliderValue > 0 then
        setColor(opts.progressColor or UI.colors.progress)
        love.graphics.rectangle("fill", trackX, trackY, trackW * sliderValue, trackHeight, trackHeight / 2, trackHeight / 2)
    end

    local handleX = trackX + trackW * sliderValue
    local handleY = trackY + trackHeight / 2
    setColor(opts.handleColor or UI.colors.text)
    love.graphics.circle("fill", handleX, handleY, handleRadius)

    if opts.showValue ~= false then
        local valueFont = UI.fonts[opts.valueFont or "small"]
        if valueFont then
            love.graphics.setFont(valueFont)
        end
        setColor(opts.valueColor or UI.colors.subtleText)
        local percentText = opts.valueText or string.format("%d%%", math.floor(sliderValue * 100 + 0.5))
        love.graphics.printf(percentText, trackX, trackY - (valueFont and valueFont:getHeight() or 14) - 6, trackW, "right")
    end

    love.graphics.setLineWidth(1)

    return trackX, trackY, trackW, trackHeight, handleRadius
end

-- Easing
local function easeOutQuad(t)
    return t * (2 - t)
end

-- Register a button (once per frame in your draw code)
function UI.registerButton(id, x, y, w, h, text)
    UI.buttons[id] = UI.buttons[id] or createButtonState()
    local btn = UI.buttons[id]
    btn.bounds = {x = x, y = y, w = w, h = h}
    btn.text = text
end

-- Draw button (render only)
function UI.drawButton(id)
    local btn = UI.buttons[id]
    if not btn or not btn.bounds then return end

    local b = btn.bounds
    local s = UI.spacing

    local mx, my = love.mouse.getPosition()
    local hoveredByMouse = UI.isHovered(b.x, b.y, b.w, b.h, mx, my)
    local displayHover = hoveredByMouse or btn.focused

    if displayHover and not btn.wasHovered then
        Audio:playSound("hover")
    end
    btn.wasHovered = displayHover
    btn.hoverTarget = displayHover and 1 or 0

    -- Animate press depth
    local pressAnim = btn.anim or 0
    local yOffset = easeOutQuad(pressAnim) * 4

    local baseScale = 1 + (btn.popProgress or 0) * 0.08
    local hoverScale = 1 + (btn.hoverAnim or 0) * 0.02
    local focusScale = 1 + (btn.focusAnim or 0) * 0.015
    local totalScale = baseScale * hoverScale * focusScale

    local centerX = b.x + b.w / 2
    local centerY = b.y + yOffset + b.h / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(totalScale, totalScale)
    love.graphics.translate(-centerX, -centerY)

    local radius = s.buttonRadius
    local shadowOffset = s.shadowOffset

    if shadowOffset and shadowOffset ~= 0 then
        setColor(UI.colors.shadow)
        love.graphics.rectangle("fill", b.x + shadowOffset, b.y + shadowOffset + yOffset, b.w, b.h, radius, radius)
    end

    local fillColor = UI.colors.button
    if displayHover then
        fillColor = UI.colors.buttonHover
    end
    if btn.pressed then
        fillColor = UI.colors.buttonPress
    end

    setColor(fillColor)
    love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)

    local highlightStrength = (btn.hoverAnim or 0) * 0.18 + (btn.popProgress or 0) * 0.22
    if highlightStrength > 0.001 then
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(1, 1, 1, 0.12 + 0.18 * highlightStrength)
        love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)
        love.graphics.setBlendMode(prevMode, prevAlphaMode)
    end

    if UI.colors.border then
        setColor(UI.colors.border)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", b.x, b.y + yOffset, b.w, b.h, radius, radius)
    end

    if btn.focused then
        local focusStrength = btn.focusAnim or 0
        if focusStrength > 0.01 then
            local focusRadius = radius + 4
            local padding = 3
            local focusColor = UI.colors.border or UI.colors.highlight
            setColor(focusColor, 0.8 + 0.4 * focusStrength)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", b.x - padding, b.y + yOffset - padding, b.w + padding * 2, b.h + padding * 2, focusRadius, focusRadius)
        end
    end

    local glowStrength = btn.glow or 0
    if glowStrength > 0.01 then
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(1, 1, 1, 0.16 * glowStrength)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", b.x + 2, b.y + yOffset + 2, b.w - 4, b.h - 4, radius - 2, radius - 2)
        love.graphics.setBlendMode(prevMode, prevAlphaMode)
    end

    love.graphics.setLineWidth(1)

    -- TEXT
    UI.setFont("button")
    local textColor = UI.colors.text
    if displayHover or (btn.focusAnim or 0) > 0.001 then
        textColor = lightenColor(textColor, 0.18 + 0.1 * (btn.focusAnim or 0))
    end
    setColor(textColor)
    local textY = b.y + yOffset + (b.h - UI.fonts.button:getHeight()) / 2
    love.graphics.printf(btn.text or "", b.x, textY, b.w, "center")

    love.graphics.pop()
end

-- Hover check
function UI.isHovered(x, y, w, h, px, py)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Mouse press
function UI:mousepressed(x, y, button)
    if button == 1 then
        for id, btn in pairs(UI.buttons) do
            local b = btn.bounds
            if b and UI.isHovered(b.x, b.y, b.w, b.h, x, y) then
                btn.pressed = true
                Audio:playSound("click")
                return id
            end
        end
    end
end

-- Mouse release
function UI:mousereleased(x, y, button)
    if button == 1 then
        for id, btn in pairs(UI.buttons) do
            if btn.pressed then
                btn.pressed = false
                local b = btn.bounds
                if b and UI.isHovered(b.x, b.y, b.w, b.h, x, y) then
                    btn.popTimer = 0
                    btn.popProgress = 0
                    return id -- valid click
                end
            end
        end
    end
end

-- Score pulse logic
function UI:reset()
    scorePulse = 1.0
    pulseTimer = 0
    self.combo.count = 0
    self.combo.timer = 0
    self.combo.duration = 0
    self.combo.pop = 0
    self.floorModifiers = {}
    self.shields.count = 0
    self.shields.display = 0
    self.shields.popTimer = 0
    self.shields.shakeTimer = 0
    self.shields.flashTimer = 0
    self.shields.lastDirection = 0
end

function UI:triggerScorePulse()
    scorePulse = 1.2
    pulseTimer = 0
end

function UI:setFruitGoal(required)
    self.fruitRequired = required
    self.fruitCollected = 0
        self.fruitSockets = {} -- clear collected fruit sockets each floor
end

function UI:adjustFruitGoal(delta)
    if not delta or delta == 0 then return end

    local newGoal = math.max(1, (self.fruitRequired or 0) + delta)
    self.fruitRequired = newGoal

    if (self.fruitCollected or 0) > newGoal then
        self.fruitCollected = newGoal
    end

    if type(self.fruitSockets) == "table" then
        while #self.fruitSockets > newGoal do
            table.remove(self.fruitSockets)
        end
    end
end

function UI:getFruitGoal(required)
    return self.fruitRequired
end

function UI:addFruit()
    self.fruitCollected = math.min(self.fruitCollected + 1, self.fruitRequired)
end

function UI:setFloorModifiers(modifiers)
    if type(modifiers) == "table" then
        self.floorModifiers = modifiers
    else
        self.floorModifiers = {}
    end
end

local function collectModifierSections(self)
    local sections = {}
    if self.floorModifiers and #self.floorModifiers > 0 then
        table.insert(sections, { title = "Floor Traits", items = self.floorModifiers })
    end
    return sections
end

function UI:drawFloorModifiers()
    local sections = collectModifierSections(self)
    if not sections or #sections == 0 then return end

    local margin = 20
    local width = 280
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local x = screenW - width - margin

    local lineHeight = UI.fonts.body:getHeight()
    local spacing = 12
    local wrapWidth = width - 32
    local topPadding = 20
    local bottomPadding = 28

    local totalHeight = topPadding + bottomPadding
    local measuredSections = {}
    UI.setFont("body")

    for _, section in ipairs(sections) do
        local entries = {}
        local sectionHeight = UI.fonts.button:getHeight() + spacing
        if section.items then
            for _, trait in ipairs(section.items) do
                local _, wrapped = UI.fonts.body:getWrap(trait.desc or "", wrapWidth)
                local descLines = math.max(1, #wrapped)
                local descHeight = descLines * lineHeight
                table.insert(entries, { trait = trait, descHeight = descHeight })
                sectionHeight = sectionHeight + lineHeight + descHeight + spacing
            end
        end
        if #entries > 0 then
            sectionHeight = sectionHeight - spacing
        end
        totalHeight = totalHeight + sectionHeight
        table.insert(measuredSections, { title = section.title, entries = entries, height = sectionHeight })
    end

    local height = totalHeight

    local minY = margin
    local y = math.max(minY, screenH - height - margin)

    love.graphics.setColor(Theme.panelColor)
    love.graphics.rectangle("fill", x, y, width, height, 12, 12)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height, 12, 12)

    local textY = y + topPadding
    for sectionIndex, section in ipairs(measuredSections) do
        love.graphics.setColor(Theme.textColor)
        UI.setFont("button")
        local title = section.title or "Floor Traits"
        love.graphics.printf(title, x + 16, textY, width - 32, "left")
        textY = textY + UI.fonts.button:getHeight() + spacing

        UI.setFont("body")
        for entryIndex, info in ipairs(section.entries) do
            local trait = info.trait
            love.graphics.setColor(Theme.textColor)
            love.graphics.printf(trait.name, x + 16, textY, width - 32, "left")
            textY = textY + lineHeight
            love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.75)
            love.graphics.printf(trait.desc, x + 16, textY, width - 32, "left")
            textY = textY + info.descHeight
            if entryIndex < #section.entries then
                textY = textY + spacing
            end
        end

        if sectionIndex < #measuredSections then
            textY = textY + spacing
        end
    end
end

function UI:isGoalReached()
	if self.fruitCollected >= self.fruitRequired then
		if not self.goalCelebrated then
			self:celebrateGoal()
		end
		return true
	end
end

function UI:addFruit(fruitType)
    self.fruitCollected = math.min(self.fruitCollected + 1, self.fruitRequired)
    local fruit = fruitType or { name = "Apple", color = { 1, 0, 0 } }
    table.insert(self.fruitSockets, {
        type = fruit,
        anim = 0,
        wobblePhase = love.math.random() * math.pi * 2,
        bounceTimer = 0,
    })
end

function UI:celebrateGoal()
    self.goalReachedAnim = 0
    self.goalCelebrated = true
    Audio:playSound("goal_reached")
    for _, socket in ipairs(self.fruitSockets) do
        socket.bounceTimer = 0
    end
end

function UI:update(dt)
    --[[ Update score pulse
    pulseTimer = pulseTimer + dt
    if pulseTimer > PULSE_DURATION then
        scorePulse = 1.0
    else
        local progress = pulseTimer / PULSE_DURATION
        scorePulse = 1.2 - 0.2 * progress
    end]]

    -- Update button animations
    for _, button in pairs(UI.buttons) do
        local hoverTarget = button.hoverTarget or 0
        local focusTarget = button.focused and 1 or 0
        button.anim = approachExp(button.anim or 0, button.pressed and 1 or 0, dt, 18)
        if hoverTarget > 0 then
            button.hoverAnim = approachExp(button.hoverAnim or 0, hoverTarget, dt, 12)
        else
            button.hoverAnim = 0
        end
        button.focusAnim = approachExp(button.focusAnim or 0, focusTarget, dt, 9)
        local glowTarget = math.max(hoverTarget, focusTarget)
        button.glow = approachExp(button.glow or 0, glowTarget, dt, 5)

        if button.popTimer ~= nil then
            button.popTimer = button.popTimer + dt
            local progress = math.min(1, button.popTimer / BUTTON_POP_DURATION)
            button.popProgress = math.sin(progress * math.pi) * (1 - progress * 0.45)
            if progress >= 1 then
                button.popTimer = nil
            end
        else
            button.popProgress = approachExp(button.popProgress or 0, 0, dt, 10)
        end

        button.hoverTarget = 0
    end

    -- update fruit socket animations
    for _, socket in ipairs(self.fruitSockets) do
        if socket.anim < self.socketAnimTime then
            socket.anim = math.min(socket.anim + dt, self.socketAnimTime)
        end

        if socket.bounceTimer ~= nil then
            socket.bounceTimer = socket.bounceTimer + dt
            if socket.bounceTimer >= self.socketBounceDuration then
                socket.bounceTimer = nil
            end
        end

        if socket.wobblePhase == nil then
            socket.wobblePhase = love.math.random() * math.pi * 2
        end
        socket.wobblePhase = socket.wobblePhase + dt * 6.2
    end

    if self.goalCelebrated then
        self.goalReachedAnim = self.goalReachedAnim + dt
        if self.goalReachedAnim > 1 then
            self.goalCelebrated = false
        end
    end

    if self.combo.pop > 0 then
        self.combo.pop = math.max(0, self.combo.pop - dt * 3)
    end

    local shields = self.shields
    if shields then
        if shields.display == nil then
            shields.display = shields.count or 0
        end

        local target = shields.count or 0
        local current = shields.display or 0
        local diff = target - current
        if math.abs(diff) > 0.01 then
            local step = diff * math.min(dt * 10, 1)
            shields.display = current + step
        else
            shields.display = target
        end

        if shields.popTimer and shields.popTimer > 0 then
            shields.popTimer = math.max(0, shields.popTimer - dt)
        end

        if shields.shakeTimer and shields.shakeTimer > 0 then
            shields.shakeTimer = math.max(0, shields.shakeTimer - dt)
        end

        if shields.flashTimer and shields.flashTimer > 0 then
            shields.flashTimer = math.max(0, shields.flashTimer - dt)
        end
    end

    local container = self.upgradeIndicators
    if container and container.items then
        local smoothing = math.min(dt * 8, 1)
        local toRemove = {}
        for id, item in pairs(container.items) do
            item.visibility = item.visibility or 0
            local targetVis = item.targetVisibility or 0
            item.visibility = lerp(item.visibility, targetVis, smoothing)

            if item.targetProgress ~= nil then
                item.displayProgress = item.displayProgress or item.targetProgress or 0
                item.displayProgress = lerp(item.displayProgress, item.targetProgress, smoothing)
            else
                item.displayProgress = nil
            end

            if item.visibility <= 0.01 and targetVis <= 0 then
                table.insert(toRemove, id)
            end
        end

        for _, id in ipairs(toRemove) do
            container.items[id] = nil
        end
    end

end

function UI:setCombo(count, timer, duration)
    local combo = self.combo
    local previous = combo.count or 0

    combo.count = count or 0
    combo.timer = timer or 0

    if duration and duration > 0 then
        combo.duration = duration
    elseif not combo.duration then
        combo.duration = 0
    end

    if combo.count >= 2 then
        if combo.count > previous then
            combo.pop = 1.0
        end

    else
        if previous >= 2 then
            combo.pop = 0
        end
    end
end

function UI:getCrashShields()
    return (self.shields and self.shields.count) or 0
end

function UI:setCrashShields(count, opts)
    local shields = self.shields
    if not shields then return end

    count = math.max(0, math.floor((count or 0) + 0.0001))

    if shields.count == nil then
        shields.count = count
        shields.display = count
        return
    end

    local previous = shields.count or 0
    shields.count = count

    if opts and opts.immediate then
        shields.display = count
    end

    if count == previous then
        return
    end

    local silent = opts and opts.silent

    if count > previous then
        shields.lastDirection = 1
        shields.popTimer = shields.popDuration
        shields.flashTimer = shields.flashDuration * 0.6
        shields.shakeTimer = 0
        if not silent then
            Audio:playSound("shield_gain")
        end
    else
        shields.lastDirection = -1
        shields.shakeTimer = shields.shakeDuration
        shields.flashTimer = shields.flashDuration
        shields.popTimer = 0
        if not silent then
            Audio:playSound("shield_break")
        end
    end
end

function UI:setUpgradeIndicators(indicators)
    local container = self.upgradeIndicators
    if not container then return end

    local items = container.items
    if not items then
        container.items = {}
        items = container.items
    end

    local seen = {}
    container.order = {}

    if indicators then
        for index, data in ipairs(indicators) do
            local id = data.id or ("indicator_" .. tostring(index))
            seen[id] = true
            container.order[#container.order + 1] = id

            local item = items[id]
            if not item then
                item = {
                    id = id,
                    visibility = 0,
                    targetVisibility = 1,
                    displayProgress = data.charge ~= nil and clamp01(data.charge) or nil,
                }
                items[id] = item
            end

            item.targetVisibility = 1
            item.label = data.label or id
            item.stackCount = data.stackCount
            item.icon = data.icon
            item.accentColor = data.accentColor or {1, 1, 1, 1}
            item.status = data.status
            item.chargeLabel = data.chargeLabel
            if data.charge ~= nil then
                item.targetProgress = clamp01(data.charge)
                if item.displayProgress == nil then
                    item.displayProgress = item.targetProgress
                end
            else
                item.targetProgress = nil
                item.displayProgress = nil
            end
            if data.showBar ~= nil then
                item.showBar = data.showBar
            else
                item.showBar = data.charge ~= nil
            end
        end
    end

    for id, item in pairs(items) do
        if not seen[id] then
            item.targetVisibility = 0
        end
    end
end

local function drawComboIndicator(self)
    local combo = self.combo
    local comboActive = combo and combo.count >= 2 and (combo.duration or 0) > 0

    if not comboActive then
        return
    end

    local duration = combo.duration or 0
    local timer = 0
    local progress = 0
    timer = math.max(0, math.min(combo.timer or 0, duration))
    progress = duration > 0 and timer / duration or 0

    local screenW = love.graphics.getWidth()
    local titleText = "Combo"
    titleText = "Combo x" .. combo.count

    local width = math.max(240, UI.fonts.button:getWidth(titleText) + 120)
    local height = 68
    local x = (screenW - width) / 2
    local y = 16

    local scale = 1 + 0.08 * math.sin((1 - progress) * math.pi * 2) + (combo.pop or 0) * 0.25

    love.graphics.push()
    love.graphics.translate(x + width / 2, y + height / 2)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-(x + width / 2), -(y + height / 2))

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 4, y + 6, width, height, 18, 18)

    love.graphics.setColor(Theme.panelColor[1], Theme.panelColor[2], Theme.panelColor[3], 0.95)
    love.graphics.rectangle("fill", x, y, width, height, 18, 18)

    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height, 18, 18)

    UI.setFont("button")
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(titleText, x, y + 8, width, "center")

    local barPadding = 18
    local barHeight = 10
    local barWidth = width - barPadding * 2
    local comboBarY = y + height - barPadding - barHeight

    if comboActive then
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle("fill", x + barPadding, comboBarY, barWidth, barHeight, 6, 6)

        local glow = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
        love.graphics.setColor(1, 0.78, 0.3, 0.85)
        love.graphics.rectangle("fill", x + barPadding, comboBarY, barWidth * progress, barHeight, 6, 6)

        love.graphics.setColor(1, 0.95, 0.75, 0.4 + glow * 0.2)
        love.graphics.rectangle("line", x + barPadding - 2, comboBarY - 2, barWidth + 4, barHeight + 4, 8, 8)
    end

    love.graphics.pop()
end

local function buildShieldPoints(radius)
    return {
        0, -radius,
        radius * 0.78, -radius * 0.28,
        radius * 0.55, radius * 0.85,
        0, radius,
        -radius * 0.55, radius * 0.85,
        -radius * 0.78, -radius * 0.28,
    }
end

local function drawIndicatorIcon(icon, accentColor, x, y, radius, overlay)
    local accent = accentColor or {1, 1, 1, 1}

    love.graphics.push("all")
    love.graphics.translate(x, y)

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", 3, 4, radius + 3, 28)

    local base = darkenColor(accent, 0.6)
    love.graphics.setColor(base[1], base[2], base[3], base[4] or 1)
    love.graphics.circle("fill", 0, 0, radius, 28)

    local detail = lightenColor(accent, 0.12)
    love.graphics.setColor(detail[1], detail[2], detail[3], detail[4] or 1)

    if icon == "shield" then
        local shield = buildShieldPoints(radius * 0.9)
        love.graphics.polygon("fill", shield)
        local outline = lightenColor(accent, 0.35)
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", shield)
    elseif icon == "bolt" then
        local bolt = {
            -radius * 0.28, -radius * 0.92,
            radius * 0.42, -radius * 0.2,
            radius * 0.08, -radius * 0.18,
            radius * 0.48, radius * 0.82,
            -radius * 0.2, radius * 0.14,
            radius * 0.05, 0,
        }
        love.graphics.polygon("fill", bolt)
    elseif icon == "pickaxe" then
        love.graphics.push()
        love.graphics.rotate(-math.pi / 8)
        love.graphics.rectangle("fill", -radius * 0.14, -radius * 0.92, radius * 0.28, radius * 1.84, radius * 0.16)
        love.graphics.pop()
        local outline = lightenColor(accent, 0.35)
        love.graphics.setColor(outline[1], outline[2], outline[3], outline[4] or 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, radius * 0.95, 28)
    elseif icon == "hourglass" then
        local bowl = {
            -radius * 0.7, -radius * 0.78,
            radius * 0.7, -radius * 0.78,
            radius * 0.32, -radius * 0.12,
            radius * 0.32, radius * 0.12,
            radius * 0.7, radius * 0.78,
            -radius * 0.7, radius * 0.78,
            -radius * 0.32, radius * 0.12,
            -radius * 0.32, -radius * 0.12,
        }
        love.graphics.polygon("fill", bowl)
        love.graphics.setColor(base[1], base[2], base[3], (base[4] or 1) * 0.6)
        love.graphics.ellipse("fill", 0, -radius * 0.36, radius * 0.4, radius * 0.2, 28)
        love.graphics.ellipse("fill", 0, radius * 0.36, radius * 0.4, radius * 0.2, 28)
        love.graphics.setColor(detail[1], detail[2], detail[3], detail[4] or 1)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", bowl)
    elseif icon == "phoenix" then
        local wing = {
            -radius * 0.88, radius * 0.16,
            -radius * 0.26, -radius * 0.7,
            0, -radius * 0.25,
            radius * 0.26, -radius * 0.7,
            radius * 0.88, radius * 0.16,
            0, radius * 0.88,
        }
        love.graphics.polygon("fill", wing)
    else
        love.graphics.circle("fill", 0, 0, radius * 0.72, 28)
    end

    if overlay and overlay.text then
        local background = overlay.backgroundColor or {0, 0, 0, 0.78}
        local borderColor = overlay.borderColor or lightenColor(accent, 0.35)
        local fontKey = overlay.font or "small"
        local paddingX = overlay.paddingX or 6
        local paddingY = overlay.paddingY or 2
        local previousFont = love.graphics.getFont()
        UI.setFont(fontKey)
        local font = love.graphics.getFont()
        local text = tostring(overlay.text)
        local textWidth = font:getWidth(text)
        local boxWidth = textWidth + paddingX * 2
        local boxHeight = font:getHeight() + paddingY * 2
        local position = overlay.position or "bottomRight"
        local anchorX, anchorY

        if position == "topLeft" then
            anchorX = -radius * 0.75
            anchorY = -radius * 0.75
        elseif position == "topRight" then
            anchorX = radius * 0.75
            anchorY = -radius * 0.75
        elseif position == "bottomLeft" then
            anchorX = -radius * 0.75
            anchorY = radius * 0.75
        else
            anchorX = radius * 0.75
            anchorY = radius * 0.75
        end

        local boxX = anchorX - boxWidth * 0.5
        local boxY = anchorY - boxHeight * 0.5
        local cornerRadius = overlay.cornerRadius or math.min(10, boxHeight * 0.5)

        love.graphics.setColor(background[1], background[2], background[3], background[4] or 1)
        love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, cornerRadius, cornerRadius)

        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1))
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, cornerRadius, cornerRadius)

        local textColor = overlay.textColor or {1, 1, 1, 1}
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        love.graphics.printf(text, boxX, boxY + paddingY - 1, boxWidth, "center")
        if previousFont then
            love.graphics.setFont(previousFont)
        end
    end

    love.graphics.pop()
end

local function buildShieldIndicator(self)
    local shields = self.shields
    if not shields then return nil end

    local rawCount = shields.count
    if rawCount == nil then
        rawCount = shields.display
    end

    local count = math.max(0, math.floor((rawCount or 0) + 0.5))

    if count <= 0 then
        return nil
    end

    local label = Localization:get("upgrades.hud.shields")

    local accent = {0.55, 0.82, 1.0, 1.0}
    local statusKey = "ready"

    if (shields.lastDirection or 0) < 0 and (shields.flashTimer or 0) > 0 then
        accent = {1.0, 0.55, 0.45, 1.0}
        statusKey = "depleted"
    end

    return {
        id = "__shields",
        label = label,
        stackCount = count,
        icon = "shield",
        accentColor = accent,
        iconOverlay = {
            text = count,
            position = "bottomRight",
            font = "small",
        },
        status = Localization:get("upgrades.hud." .. statusKey),
        showBar = false,
        visibility = 1,
    }
end

function UI:drawUpgradeIndicators()
    local container = self.upgradeIndicators
    if not container or not container.items then return end

    local orderedIds = {}
    local seen = {}
    if container.order then
        for _, id in ipairs(container.order) do
            if container.items[id] and not seen[id] then
                table.insert(orderedIds, id)
                seen[id] = true
            end
        end
    end

    for id in pairs(container.items) do
        if not seen[id] then
            table.insert(orderedIds, id)
            seen[id] = true
        end
    end

    local entries = {}
    for _, id in ipairs(orderedIds) do
        local item = container.items[id]
        if item and clamp01(item.visibility or 0) > 0.01 then
            table.insert(entries, item)
        end
    end

    local shieldEntry = buildShieldIndicator(self)
    if shieldEntry then
        table.insert(entries, 1, shieldEntry)
    end

    if #entries == 0 then
        return
    end

    local layout = container.layout or {}
    local width = layout.width or 252
    local spacing = layout.spacing or 12
    local baseHeight = layout.baseHeight or 64
    local barHeight = layout.barHeight or 10
    local iconRadius = layout.iconRadius or 18
    local margin = layout.margin or 24

    local screenW = love.graphics.getWidth()
    local x = screenW - width - margin
    local y = margin

    for _, entry in ipairs(entries) do
        local visibility = clamp01(entry.visibility or 1)
        local accent = entry.accentColor or Theme.panelBorder or {1, 1, 1, 1}
        local hasBar = entry.showBar and entry.displayProgress ~= nil
        local panelHeight = baseHeight + (hasBar and 8 or 0)

        local drawY = y

        love.graphics.push("all")

        love.graphics.setColor(0, 0, 0, 0.4 * visibility)
        love.graphics.rectangle("fill", x + 4, drawY + 6, width, panelHeight, 14, 14)

        local panelColor = Theme.panelColor or {0.16, 0.18, 0.22, 1}
        love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1) * (0.95 * visibility))
        love.graphics.rectangle("fill", x, drawY, width, panelHeight, 14, 14)

        local border = lightenColor(accent, 0.15)
        love.graphics.setColor(border[1], border[2], border[3], (border[4] or 1) * visibility)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, drawY, width, panelHeight, 14, 14)

        local iconX = x + iconRadius + 16
        local iconY = drawY + iconRadius + 12
        drawIndicatorIcon(entry.icon or "circle", accent, iconX, iconY, iconRadius, entry.iconOverlay)

        local textX = iconX + iconRadius + 16
        local textWidth = width - textX - 16

        UI.setFont("button")
        love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], visibility)
        love.graphics.printf(entry.label or entry.id, textX, drawY + 12, textWidth, "left")

        if entry.stackCount ~= nil then
            local stackText = "x" .. tostring(entry.stackCount)
            UI.setFont("button")
            local stackColor = lightenColor(accent, 0.3)
            love.graphics.setColor(stackColor[1], stackColor[2], stackColor[3], (stackColor[4] or 1) * visibility)
            love.graphics.printf(stackText, textX, drawY + 12, textWidth, "right")
        end

        if entry.status then
            UI.setFont("small")
            love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.75 * visibility)
            love.graphics.printf(entry.status, textX, drawY + 38, textWidth, "left")
        end

        if hasBar then
            local progress = clamp01(entry.displayProgress or 0)
            local iconBarWidth = layout.iconBarWidth or (iconRadius * 1.8)
            local iconBarHeight = layout.iconBarHeight or math.max(4, math.floor(barHeight))
            local barX = iconX - iconBarWidth * 0.5
            local desiredBarY = iconY + iconRadius + 6
            local maxBarY = drawY + panelHeight - iconBarHeight - 6
            local barY = math.min(desiredBarY, maxBarY)

            love.graphics.setColor(0, 0, 0, 0.28 * visibility)
            love.graphics.rectangle("fill", barX, barY, iconBarWidth, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

            local fill = lightenColor(accent, 0.05)
            love.graphics.setColor(fill[1], fill[2], fill[3], (fill[4] or 1) * 0.85 * visibility)
            love.graphics.rectangle("fill", barX, barY, iconBarWidth * progress, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

            local outline = lightenColor(accent, 0.3)
            love.graphics.setColor(outline[1], outline[2], outline[3], (outline[4] or 1) * 0.9 * visibility)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", barX, barY, iconBarWidth, iconBarHeight, iconBarHeight * 0.5, iconBarHeight * 0.5)

            if entry.chargeLabel then
                UI.setFont("small")
                love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.8 * visibility)
                local labelY = barY + iconBarHeight + 4
                love.graphics.printf(entry.chargeLabel, barX, labelY, iconBarWidth, "center")
            end
        elseif entry.chargeLabel then
            UI.setFont("small")
            love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.8 * visibility)
            love.graphics.printf(entry.chargeLabel, textX, drawY + panelHeight - 24, textWidth, "right")
        end

        love.graphics.pop()

        y = y + panelHeight + spacing
    end
end

function UI:drawFruitSockets()
    if self.fruitRequired <= 0 then
        return
    end

    local baseX, baseY = 20, 60
    local perRow = 10
    local spacing = self.socketSize + 6
    local rows = math.max(1, math.ceil(self.fruitRequired / perRow))
    local cols = math.min(self.fruitRequired, perRow)
    if cols == 0 then cols = 1 end

    local gridWidth = (cols - 1) * spacing + self.socketSize
    local gridHeight = (rows - 1) * spacing + self.socketSize
    local paddingX = self.socketSize * 0.75
    local paddingY = self.socketSize * 0.75

    local panelX = baseX - paddingX
    local panelY = baseY - paddingY
    local panelW = gridWidth + paddingX * 2
    local panelH = gridHeight + paddingY * 2

    local goalFlash = 0
    if self.goalCelebrated then
        local flashProgress = math.min(1, self.goalReachedAnim / 0.65)
        goalFlash = math.sin(flashProgress * math.pi)
    end

    -- juicy backdrop for the whole socket grid
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", panelX + 6, panelY + 8, panelW, panelH, 18, 18)

    local panelColor = lightenColor(Theme.panelColor, 0.2 + 0.25 * goalFlash)
    love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], (panelColor[4] or 1))
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 18, 18)

    local borderColor = Theme.panelBorder or Theme.textColor
    borderColor = lightenColor(borderColor, 0.1 + 0.2 * goalFlash)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1))
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 18, 18)

    local highlight = Theme.highlightColor or {1, 1, 1, 0.05}
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * 0.75)
    love.graphics.rectangle("fill", panelX + 4, panelY + 4, panelW - 8, panelH * 0.35, 14, 14)

    if goalFlash > 0 then
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(1, 1, 1, 0.16 * goalFlash)
        love.graphics.rectangle("line", panelX - 4, panelY - 4, panelW + 8, panelH + 8, 22, 22)
        love.graphics.setBlendMode(prevMode, prevAlphaMode)
    end

    local time = love.timer.getTime()
    local socketRadius = (self.socketSize / 2) - 2
    local socketFill = lightenColor(Theme.panelColor, 0.45)
    local socketOutline = lightenColor(Theme.panelBorder or Theme.textColor, 0.2)

    for i = 1, self.fruitRequired do
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local bounce = 0
        local x = baseX + col * spacing + self.socketSize / 2
        local y = baseY + row * spacing + self.socketSize / 2 + bounce

        -- socket shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        local socket = self.fruitSockets[i]
        local hasFruit = socket ~= nil
        local radius = hasFruit and socketRadius or socketRadius * 0.8
        local shadowScale = hasFruit and 1 or 0.85
        love.graphics.ellipse("fill", x, y + radius * 0.65, radius * 0.95 * shadowScale, radius * 0.55 * shadowScale, 32)

        -- empty socket base
        love.graphics.setColor(socketFill[1], socketFill[2], socketFill[3], (socketFill[4] or 1) * 0.9)
        love.graphics.circle("fill", x, y, radius, 48)

        -- subtle animated rim
        local rimPulse = 0.35 + 0.25 * math.sin(time * 3.5 + i * 0.7)
        love.graphics.setColor(socketOutline[1], socketOutline[2], socketOutline[3], (socketOutline[4] or 1) * rimPulse)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, radius, 48)

        love.graphics.setColor(1, 1, 1, 0.08)
        love.graphics.arc("fill", x, y, radius * 1.1, -math.pi * 0.6, -math.pi * 0.1, 24)

        -- draw fruit if collected
        if socket then
            local t = math.min(socket.anim / self.socketAnimTime, 1)
            local scale = 0.75 + 0.25 * (1 - (1 - t) * (1 - t))
            local bounceScale = 1
            if socket.bounceTimer ~= nil then
                local bounceProgress = math.min(1, socket.bounceTimer / self.socketBounceDuration)
                bounceScale = 1 + math.sin(bounceProgress * math.pi) * 0.22 * (1 - bounceProgress * 0.35)
            end

            local goalPulse = 1.0
            if self.goalCelebrated then
                local goalT = math.min(self.goalReachedAnim / 0.25, 1)
                goalPulse = 1 + 0.3 * (1 - (1 - goalT) * (1 - goalT))
            end

            love.graphics.push()
            love.graphics.translate(x, y)
            local wobbleRotation = 0
            if socket.wobblePhase then
                wobbleRotation = math.sin(socket.wobblePhase) * 0.08 * (1 - t)
            end
            love.graphics.rotate(wobbleRotation)
            love.graphics.scale(scale * goalPulse * bounceScale, scale * goalPulse * bounceScale)

            -- fruit shadow inside socket
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.ellipse("fill", 0, radius * 0.55, radius * 0.8, radius * 0.45, 32)

            local r = radius * 1.0
            local fruit = socket.type

            love.graphics.setColor(fruit.color[1], fruit.color[2], fruit.color[3], 1)
            love.graphics.circle("fill", 0, 0, r, 32)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", 0, 0, r, 32)

            -- juicy highlight
            local highlightColor = lightenColor(fruit.color, 0.6)
            local highlightAlpha = (highlightColor[4] or 1) * 0.75
            love.graphics.push()
            love.graphics.translate(-r * 0.3, -r * 0.35)
            love.graphics.rotate(-0.35)
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightAlpha)
            love.graphics.ellipse("fill", 0, 0, r * 0.55, r * 0.45, 32)
            love.graphics.pop()

            -- sparkling rim when fruit is fresh
            if t < 1 then
                local sparkle = 0.4 + 0.4 * (1 - t)
                love.graphics.setColor(1, 1, 1, sparkle)
                love.graphics.circle("line", 0, 0, r + 3, 24)
            end

            -- dragonfruit glow
            if fruit.name == "Dragonfruit" then
                local pulse = 0.5 + 0.5 * math.sin(time * 6.0)
                love.graphics.setColor(1, 0, 1, 0.25 * pulse)
                love.graphics.circle("line", 0, 0, r + 4 * pulse, 32)
            end

            love.graphics.pop()
        else
            -- idle shimmer in empty sockets
            local emptyGlow = 0.12 + 0.12 * math.sin(time * 5 + i * 0.9)
            love.graphics.setColor(highlight[1], highlight[2], highlight[3], (highlight[4] or 1) * emptyGlow)
            love.graphics.circle("line", x, y, radius - 1.5, 32)
        end
    end
end

function UI:draw()
    self:drawUpgradeIndicators()
    drawComboIndicator(self)
    -- draw socket grid
    self:drawFruitSockets()

    -- fruit counter text (small, under sockets)
    if self.fruitRequired > 0 then
        local collected = tostring(self.fruitCollected)
        local required  = tostring(self.fruitRequired)

        UI.setFont("button")
        love.graphics.setColor(Theme.textColor)
        love.graphics.printf(
            collected .. " / " .. required,
            20, 20,                     -- x, y (just above sockets)
            200, "left"
        )
    end

    self:drawFloorModifiers()
end

return UI
