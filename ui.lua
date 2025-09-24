local Score = require("score")
local Audio = require("audio")
local Theme = require("theme")
local Fruit = require("fruit")

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

-- Button states
UI.buttons = {}

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
    UI.buttons[id].bounds = {x = x, y = y, w = w, h = h}
    UI.buttons[id].text = text
end

-- Draw button (render only)
function UI.drawButton(id)
    local btn = UI.buttons[id]
    if not btn or not btn.bounds then return end

    local b = btn.bounds
    local s = UI.spacing

    local mx, my = love.mouse.getPosition()
    local hovered = UI.isHovered(b.x, b.y, b.w, b.h, mx, my)

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

-- Label
function UI.drawLabel(text, x, y, font, align)
    font = font or "body"
    align = align or "left"
    UI.setFont(font)
    love.graphics.setColor(Theme.textColor)
    love.graphics.printf(text, x, y, love.graphics.getWidth(), align)
end

-- Panel
function UI.drawPanel(x, y, w, h)
    local s = UI.spacing

    love.graphics.setColor(Theme.shadowColor)
    UI.drawRoundedRect(x + s.shadowOffset, y + s.shadowOffset, w, h, s.panelRadius)

    love.graphics.setColor(Theme.panelColor)
    UI.drawRoundedRect(x, y, w, h, s.panelRadius)

    love.graphics.setColor(Theme.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, s.panelRadius)
end

-- Score pulse logic
function UI:reset()
    scorePulse = 1.0
    pulseTimer = 0
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

function UI:getFruitGoal(required)
    return self.fruitRequired
end

function UI:addFruit()
    self.fruitCollected = math.min(self.fruitCollected + 1, self.fruitRequired)
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
end

local function drawFruitIcon(fruit, x, y, size, scale)
    local r = size / 2
    scale = scale or 1

    -- shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.ellipse("fill", x+2, y+2, r*scale, r*scale*0.85, 24)

    -- body
    love.graphics.setColor(fruit.color[1], fruit.color[2], fruit.color[3], 1)
    love.graphics.ellipse("fill", x, y, r*scale, r*scale*0.85, 24)

    -- outline
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x, y, r*scale, r*scale*0.85, 24)

    -- dragonfruit glow
    if fruit.name == "Dragonfruit" then
        local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6.0)
        love.graphics.setColor(1, 0, 1, 0.25 * pulse)
        love.graphics.circle("line", x, y, r*scale + 3*pulse)
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
end

return UI