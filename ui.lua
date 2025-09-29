local Score = require("score")
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

UI.upgradeIndicators = {
    items = {},
    order = {},
    layout = {
        width = 252,
        spacing = 12,
        baseHeight = 64,
        iconRadius = 18,
        barHeight = 10,
        margin = 24,
    },
}

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function lerp(a, b, t)
    return a + (b - a) * t
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

    if hovered and not btn.wasHovered then
        Audio:playSound("hover")
    end
    btn.wasHovered = hovered

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
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", b.x, b.y + yOffset, b.w, b.h, radius, radius)

    -- BODY
    love.graphics.setColor(Theme.buttonColor)
    love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)

    -- HOVER / PRESS overlay
    if hovered or btn.pressed then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", b.x, b.y + yOffset, b.w, b.h, radius, radius)
    end

    -- TEXT
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
    table.insert(self.fruitSockets, {
        type = fruitType or {name="Apple", color={1,0,0}}, -- fallback
        anim = 0,
    })
end

function UI:celebrateGoal()
    self.goalReachedAnim = 0
    self.goalCelebrated = true
    Audio:playSound("goal_reached")
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

local function drawIndicatorIcon(icon, accentColor, x, y, radius)
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

    love.graphics.pop()
end

local function buildShieldIndicator(self)
    local shields = self.shields
    if not shields then return nil end

    local count = math.max(0, math.floor((shields.count or 0) + 0.0001))

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
        local panelHeight = baseHeight + (hasBar and (barHeight + 12) or 0)

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
        drawIndicatorIcon(entry.icon or "circle", accent, iconX, iconY, iconRadius)

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
            local barX = textX
            local barY = drawY + panelHeight - barHeight - 14
            local barWidth = textWidth
            local progress = clamp01(entry.displayProgress or 0)

            love.graphics.setColor(0, 0, 0, 0.25 * visibility)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 6, 6)

            local fill = lightenColor(accent, 0.05)
            love.graphics.setColor(fill[1], fill[2], fill[3], (fill[4] or 1) * 0.85 * visibility)
            love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight, 6, 6)

            local outline = lightenColor(accent, 0.3)
            love.graphics.setColor(outline[1], outline[2], outline[3], (outline[4] or 1) * 0.9 * visibility)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 6, 6)

            if entry.chargeLabel then
                UI.setFont("small")
                love.graphics.setColor(Theme.textColor[1], Theme.textColor[2], Theme.textColor[3], 0.8 * visibility)
                love.graphics.printf(entry.chargeLabel, barX, barY - 18, barWidth, "right")
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
