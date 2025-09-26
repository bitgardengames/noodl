local Score = require("score")
local Audio = require("audio")
local Theme = require("theme")

local UI = {}

local scorePulse = 1.0
local pulseTimer = 0
local PULSE_DURATION = 0.3

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function lightenColor(color, amount)
    amount = clamp01(amount or 0)
    local r = color[1] or 0
    local g = color[2] or 0
    local b = color[3] or 0
    local a = color[4] or 1
    return {
        r + (1 - r) * amount,
        g + (1 - g) * amount,
        b + (1 - b) * amount,
        a,
    }
end

UI.fruitCollected = 0
UI.fruitRequired = 0
UI.fruitSockets = {}
UI.socketAnimTime = 0.25
UI.socketSize = 26
UI.goalReachedAnim = 0
UI.goalCelebrated = false

UI.floorModifiers = {}

UI.combo = {
    count = 0,
    timer = 0,
    duration = 0,
    pop = 0,
    tagline = nil,
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

-- Button states
UI.buttons = {}

function UI.clearButtons()
    UI.buttons = {}
end

function UI.setButtonFocus(id, focused)
    if not id then return end

    local btn = UI.buttons[id]
    if not btn then
        btn = { pressed = false, anim = 0 }
        UI.buttons[id] = btn
    end

    btn.focused = focused or nil
end

-- Fonts
UI.fonts = {
    title      = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 72),
    button     = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 24),
    body       = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 16),
    small      = love.graphics.newFont("Assets/Fonts/Comfortaa-SemiBold.ttf", 12),
    timer      = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 42),
    timerSmall = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 20),
    achieve    = love.graphics.newFont("Assets/Fonts/Comfortaa-Bold.ttf", 16),
}

-- Spacing and layout constants
UI.spacing = {
    buttonWidth   = 260,
    buttonHeight  = 56,
    buttonRadius  = 12,
    buttonSpacing = 24,
    panelRadius   = 10,
    panelPadding  = 16,
    shadowOffset  = 4,
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

-- Easing
local function easeOutQuad(t)
    return t * (2 - t)
end

-- Register a button (once per frame in your draw code)
function UI.registerButton(id, x, y, w, h, text)
    UI.buttons[id] = UI.buttons[id] or {pressed = false, anim = 0}
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
    local hovered = UI.isHovered(b.x, b.y, b.w, b.h, mx, my)
    if btn.focused then
        hovered = true
    end

    local targetHover = hovered and 1 or 0
    btn.hoverAnim = btn.hoverAnim or targetHover
    btn.hoverAnim = btn.hoverAnim + (targetHover - btn.hoverAnim) * 0.2

    -- Animate press depth
    local target = (btn.pressed and 1 or 0)
    btn.anim = btn.anim + (target - btn.anim) * 0.25
    local yOffset = easeOutQuad(btn.anim) * 4

    local radius = s.buttonRadius
    local SHADOW_OFFSET = 6

    -- SHADOW
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", b.x + SHADOW_OFFSET, b.y + SHADOW_OFFSET + yOffset, b.w, b.h, radius, radius)

    -- OUTLINE
    local borderColor = Theme.borderColor
    local borderAlpha = (borderColor[4] or 1) * (0.55 + 0.35 * btn.hoverAnim)
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", b.x, b.y + yOffset, b.w, b.h, radius, radius)

    -- BODY
    local fillColor = lightenColor(Theme.buttonColor, 0.15 + 0.2 * btn.hoverAnim)
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
    love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)

    -- TOP HIGHLIGHT
    love.graphics.setColor(1, 1, 1, 0.12 + 0.18 * btn.hoverAnim)
    love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h / 2, radius, radius)

    -- BOTTOM SHADE
    love.graphics.setColor(0, 0, 0, 0.08 + 0.1 * (1 - btn.hoverAnim))
    love.graphics.rectangle("fill", b.x, b.y + yOffset + b.h / 2, b.w, b.h / 2, radius, radius)

    -- FOCUS GLOW
    if btn.focused then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * 0.75)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", b.x - 3, b.y + yOffset - 3, b.w + 6, b.h + 6, radius + 6, radius + 6)
    end

    -- HOVER / PRESS overlay
    if hovered or btn.pressed then
        love.graphics.setColor(1, 1, 1, 0.18 + 0.18 * btn.hoverAnim)
        love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)
    end

    -- TEXT
    love.graphics.setLineWidth(1)
    UI.setFont("button")
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(btn.text, b.x, b.y + yOffset + (b.h / 2) - UI.fonts.button:getHeight() / 2, b.w, "center")
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
    self.combo.tagline = nil
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

    local totalHeight = 16
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

    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height, 12, 12)

    local textY = y + 16
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
    table.insert(self.fruitSockets, {
        type = fruitType or {name="Apple", color={1,0,0}}, -- fallback
        anim = 0,
    })
end

function UI:celebrateGoal()
    self.goalReachedAnim = 0
    self.goalCelebrated = true
    --Audio:playSound("goal_reached") -- placeholder sound
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
        local target = (button.pressed and 1 or 0)
        button.anim = button.anim + (target - button.anim) * 0.25
    end

    -- update fruit socket animations
    for _, socket in ipairs(self.fruitSockets) do
        if socket.anim < self.socketAnimTime then
            socket.anim = math.min(socket.anim + dt, self.socketAnimTime)
        end
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

        if combo.count >= 6 then
            combo.tagline = "Max streak bonus!"
        elseif combo.count >= 5 then
            combo.tagline = "Huge streak bonus!"
        elseif combo.count >= 4 then
            combo.tagline = "Bigger streak bonus!"
        elseif combo.count >= 3 then
            combo.tagline = "Streak bonus active!"
        else
            combo.tagline = nil
        end
    else
        if previous >= 2 then
            combo.pop = 0
        end
        combo.tagline = nil
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

    if comboActive and combo.tagline then
        UI.setFont("small")
        love.graphics.setColor(1, 0.9, 0.65, 0.9)
        love.graphics.printf(combo.tagline, x, y + 30, width, "center")
    end

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

function UI:drawShields()
    local shields = self.shields
    if not shields then return end

    local display = math.max(shields.display or shields.count or 0, 0)
    local count = shields.count or 0
    local flashTimer = shields.flashTimer or 0

    if count <= 0 and display <= 0.05 and flashTimer <= 0 then
        return
    end

    local screenW = love.graphics.getWidth()
    local baseX = screenW - 24
    local baseY = 28
    local spacing = 38
    local maxIcons = 4

    local iconsToDraw = math.min(maxIcons, math.max(count, math.ceil(display)))
    if iconsToDraw <= 0 and flashTimer > 0 then
        iconsToDraw = 1
    end

    local shakeOffset = 0
    if shields.shakeTimer and shields.shakeTimer > 0 and shields.shakeDuration > 0 then
        local t = shields.shakeTimer / shields.shakeDuration
        shakeOffset = math.sin(love.timer.getTime() * 32) * 4 * t
    end

    for i = 1, iconsToDraw do
        local x = baseX - (i - 1) * spacing + shakeOffset
        local y = baseY
        local radius = 16

        love.graphics.push("all")
        love.graphics.translate(x, y)

        local scale = 1
        if shields.popTimer and shields.popTimer > 0 and shields.popDuration > 0 and i == 1 and shields.lastDirection > 0 then
            local t = shields.popTimer / shields.popDuration
            scale = scale + 0.25 * math.sin(t * math.pi)
        end

        love.graphics.scale(scale, scale)

        local fillColor = {0.55, 0.82, 1.0, 0.92}
        local borderColor = {0.15, 0.35, 0.6, 1.0}

        if flashTimer > 0 and shields.lastDirection < 0 then
            local denom = (shields.flashDuration and shields.flashDuration > 0) and shields.flashDuration or 1
            local strength = math.min(1, flashTimer / denom)
            fillColor = {1.0, 0.55 + 0.25 * strength, 0.45 + 0.1 * strength, 0.92}
            borderColor = {0.65, 0.2, 0.2, 1}
        end

        local shieldPoints = buildShieldPoints(radius)
        local shadowPoints = buildShieldPoints(radius + 2)

        love.graphics.push()
        love.graphics.translate(3, 4)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.polygon("fill", shadowPoints)
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", shadowPoints)
        love.graphics.pop()

        love.graphics.setColor(fillColor)
        love.graphics.polygon("fill", shieldPoints)

        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", shieldPoints)

        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.setLineWidth(2)
        love.graphics.line(-radius * 0.45, -radius * 0.1, 0, radius * 0.6)
        love.graphics.line(0, radius * 0.6, radius * 0.45, -radius * 0.1)

        love.graphics.pop()
    end

    if count > maxIcons then
        love.graphics.setFont(UI.fonts.button)
        love.graphics.setColor(Theme.textColor)
        love.graphics.printf("x" .. tostring(count), baseX - maxIcons * spacing - 60, baseY - 18, 120, "right")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function UI:drawFruitSockets()
    local baseX, baseY = 20, 60
    local perRow = 10
    local spacing = self.socketSize + 6

    for i = 1, self.fruitRequired do
        local row = math.floor((i-1) / perRow)
        local col = (i-1) % perRow
        local x = baseX + col * spacing + self.socketSize/2
        local y = baseY + row * spacing + self.socketSize/2

        -- draw empty socket (dark circle)
		love.graphics.setColor(0, 0, 0, 0.6) -- darker backdrop
		love.graphics.circle("fill", x, y, (self.socketSize/2) - 2, 32)
		love.graphics.setColor(0, 0, 0, 1)   -- solid dark outline
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", x, y, (self.socketSize/2) - 2, 32)

        -- draw fruit if collected
        local socket = self.fruitSockets[i]
        if socket then
            local t = math.min(socket.anim / self.socketAnimTime, 1)
            local scale = 0.7 + 0.3 * (1 - (1-t)*(1-t)) -- ease-out pop

			local goalPulse = 1.0
			if self.goalCelebrated then
				local t = math.min(self.goalReachedAnim / 0.25, 1)
				goalPulse = 1 + 0.3 * (1 - (1-t)*(1-t)) -- ease-out pulse
			end

            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.scale(scale * goalPulse, scale * goalPulse)

            -- reuse your fruit drawing style, but centered here
            local r = (self.socketSize/2) - 2
            local fruit = socket.type

            -- fruit body
			love.graphics.setColor(fruit.color[1], fruit.color[2], fruit.color[3], 1)
			love.graphics.circle("fill", 0, 0, r, 32)

            -- outline
			love.graphics.setColor(0,0,0,1)
			love.graphics.setLineWidth(3)
			love.graphics.circle("line", 0, 0, r, 32)

            -- dragonfruit glow
            if fruit.name == "Dragonfruit" then
                local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6.0)
                love.graphics.setColor(1, 0, 1, 0.25 * pulse)
                love.graphics.circle("line", 0, 0, r + 4*pulse)
            end

            love.graphics.pop()
        end
    end
end

function UI:draw()
    self:drawShields()
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
