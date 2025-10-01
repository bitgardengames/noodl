local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Localization = require("localization")
local Snake = require("snake")
local FruitEvents = require("fruitevents")
local Rocks = require("rocks")
local Score = require("score")
local FloatingText = require("floatingtext")

local RogueChoices = {
    activeModifiers = {},
    pickedCounts = {},
    decision = nil,
    game = nil,
}

local CARD_COUNT = 3
local ANALOG_DEADZONE = 0.5

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function approach(current, target, dt, speed)
    if speed <= 0 or dt <= 0 then
        return target
    end

    local factor = 1 - math.exp(-speed * dt)
    return current + (target - current) * factor
end

local boonColor = {0.65, 0.92, 0.72, 1}
local costColor = {0.95, 0.55, 0.5, 1}
local borderColor = Theme.highlightColor or {1, 1, 1, 0.12}

local CHOICE_DEFINITIONS = {
    {
        id = "iron_resonance",
        title = "Iron Resonance",
        flavor = "Forge the ever-grinding blades into a warded core.",
        boons = {
            "+1 crash shield at the start of each floor",
        },
        drawbacks = {
            "Saws move 12% faster",
        },
        summary = "Start each floor with +1 shield; saws surge 12% faster.",
        maxStacks = 1,
        modifyContext = function(context)
            context.sawSpeedMult = (context.sawSpeedMult or 1) * 1.12
        end,
        onFloorStart = function()
            return { shields = 1 }
        end,
    },
    {
        id = "ember_cohort",
        title = "Ember Cohort",
        flavor = "Invite the ember spirits to thin the stone—at a price.",
        boons = {
            "Fruit goal reduced by 2",
            "Fruit shatters a nearby rock",
        },
        drawbacks = {
            "+1 starting rock",
            "Rocks fall more often after fruit",
        },
        summary = "Fruit goal -2, extra rock pressure, fruits crack nearby stone.",
        maxStacks = 1,
        modifyContext = function(context)
            context.fruitGoal = math.max(1, (context.fruitGoal or 1) - 2)
            context.rocks = math.min(40, (context.rocks or 0) + 1)
            context.rockSpawnChance = clamp((context.rockSpawnChance or 0.25) + 0.18, 0, 0.9)
        end,
        onFruitConsumed = function(_, x, y)
            Rocks:shatterNearest(x or 0, y or 0, 1)
        end,
    },
    {
        id = "auric_transposer",
        title = "Auric Transposer",
        flavor = "A golden metronome slows the world for perfect combos.",
        boons = {
            "+0.75s combo window each floor",
        },
        drawbacks = {
            "Fruit goal +1",
            "+1 conveyor spawns",
        },
        summary = "Combo window widens by 0.75s; more fruit and conveyors arrive.",
        maxStacks = 1,
        modifyContext = function(context)
            context.fruitGoal = math.max(1, (context.fruitGoal or 1) + 1)
            context.conveyors = math.max(0, (context.conveyors or 0) + 1)
        end,
        onFloorStart = function()
            return { comboBonus = 0.75 }
        end,
    },
    {
        id = "gilded_bond",
        title = "Gilded Bond",
        flavor = "Strike a pact—wealth for danger in the machine halls.",
        boons = {
            "Each fruit grants +25 bonus score",
        },
        drawbacks = {
            "+1 saw awakens",
            "Saw spin increases by 10%",
        },
        summary = "Fruits pay +25 score; an extra, faster saw joins the hunt.",
        maxStacks = 1,
        modifyContext = function(context)
            context.saws = math.min(8, (context.saws or 0) + 1)
            context.sawSpinMult = (context.sawSpinMult or 1) * 1.1
        end,
        onFruitConsumed = function(_, x, y)
            Score:addBonus(25)
            if x and y then
                FloatingText:add("+25", x, y - 36, {1, 0.9, 0.4, 1}, 0.8, 34)
            end
        end,
    },
}

local function copyList(list)
    if not list then return {} end
    local result = {}
    for i, value in ipairs(list) do
        result[i] = value
    end
    return result
end

local function computeLayout(decision, width, height)
    if not decision then
        return nil
    end

    local count = #decision.choices
    if count == 0 then
        decision.cardLayout = { rects = {} }
        return decision.cardLayout
    end

    local cardWidth = math.min(360, width * 0.28)
    local cardHeight = math.min(420, height * 0.55)
    local spacing = math.min(56, width * 0.05)
    local totalWidth = cardWidth * count + spacing * (count - 1)
    local startX = (width - totalWidth) * 0.5
    local cardY = math.max(height * 0.34, 160)

    local layout = {
        cardWidth = cardWidth,
        cardHeight = cardHeight,
        spacing = spacing,
        rects = {},
    }

    for i = 1, count do
        local x = startX + (i - 1) * (cardWidth + spacing)
        layout.rects[i] = { x = x, y = cardY, w = cardWidth, h = cardHeight }
    end

    decision.cardLayout = layout
    decision.renderSize = { width = width, height = height }
    return layout
end

local function playFocusSound()
    Audio:playSound("shop_focus")
end

local function playSelectSound()
    Audio:playSound("shop_card_select")
end

local function getDecision(self)
    return self.decision
end

function RogueChoices:beginRun(game)
    self.game = game
    self.activeModifiers = {}
    self.pickedCounts = {}
    self.decision = nil
end

function RogueChoices:getActiveSummaries()
    local summaries = {}

    for _, modifier in ipairs(self.activeModifiers or {}) do
        summaries[#summaries + 1] = {
            name = modifier.title,
            desc = modifier.summary,
        }
    end

    return summaries
end

function RogueChoices:modifyFloorContext(context, floor)
    if not context then
        return context
    end

    for _, modifier in ipairs(self.activeModifiers or {}) do
        if modifier.modifyContext then
            modifier.modifyContext(context, floor)
        end
    end

    return context
end

function RogueChoices:onFloorStart(game, floor, traitContext, spawnPlan)
    local totalShields = 0
    local comboBonus = 0

    for _, modifier in ipairs(self.activeModifiers or {}) do
        if modifier.onFloorStart then
            local result = modifier.onFloorStart(game, floor, traitContext, spawnPlan)
            if result then
                totalShields = totalShields + (result.shields or 0)
                comboBonus = comboBonus + (result.comboBonus or 0)
            end
        end
    end

    if comboBonus ~= 0 then
        local base = FruitEvents:getDefaultComboWindow()
        FruitEvents:setComboWindow(base + comboBonus)
    end

    if totalShields ~= 0 then
        Snake:addCrashShields(totalShields)
    end
end

function RogueChoices:onFruitConsumed(x, y)
    for _, modifier in ipairs(self.activeModifiers or {}) do
        if modifier.onFruitConsumed then
            modifier.onFruitConsumed(self.game, x, y)
        end
    end
end

local function isDefinitionAvailable(self, def, floor)
    if def.minFloor and floor < def.minFloor then
        return false
    end
    if def.maxFloor and floor > def.maxFloor then
        return false
    end
    local picked = self.pickedCounts[def.id] or 0
    local limit = def.maxStacks or 1
    if picked >= limit then
        return false
    end
    return true
end

local function collectAvailableDefinitions(self, floor)
    local pool = {}
    for _, def in ipairs(CHOICE_DEFINITIONS) do
        if isDefinitionAvailable(self, def, floor) then
            pool[#pool + 1] = def
        end
    end
    return pool
end

function RogueChoices:hasAvailableChoices(floor)
    local pool = collectAvailableDefinitions(self, floor)
    return #pool > 0
end

function RogueChoices:shouldOfferDecision(floor)
    floor = floor or 1
    if floor <= 1 then
        return false
    end
    return self:hasAvailableChoices(floor)
end

local function getRandom()
    if love and love.math and love.math.random then
        return love.math.random
    end
    return math.random
end

local function cloneDefinition(def)
    return {
        id = def.id,
        title = def.title,
        flavor = def.flavor,
        boons = copyList(def.boons),
        drawbacks = copyList(def.drawbacks),
        summary = def.summary,
        modifyContext = def.modifyContext,
        onFloorStart = def.onFloorStart,
        onFruitConsumed = def.onFruitConsumed,
        applyImmediate = def.applyImmediate,
    }
end

function RogueChoices:generateChoices(floor)
    local pool = collectAvailableDefinitions(self, floor)
    if #pool == 0 then
        return {}
    end

    local rng = getRandom()
    local choices = {}
    local remaining = math.min(CARD_COUNT, #pool)
    for _ = 1, remaining do
        local index = rng(1, #pool)
        local def = table.remove(pool, index)
        choices[#choices + 1] = cloneDefinition(def)
    end

    return choices
end

local function ensureDecisionState(self)
    if not self.decision then
        self.decision = {
            choices = {},
            focusIndex = 1,
            selectedIndex = nil,
            selectionComplete = false,
            selectionTimer = 0,
            cardStates = {},
            axisState = { horizontal = 0 },
        }
    end
    return self.decision
end

local function refreshCardStates(decision)
    decision.cardStates = decision.cardStates or {}
    for index = 1, #decision.choices do
        local state = decision.cardStates[index]
        if not state then
            state = { focus = 0, hover = 0, select = 0 }
            decision.cardStates[index] = state
        else
            state.focus = state.focus or 0
            state.hover = state.hover or 0
            state.select = state.select or 0
        end
    end
end

function RogueChoices:startDecision(game, floor)
    local choices = self:generateChoices(floor)
    if #choices == 0 then
        return false
    end

    local decision = ensureDecisionState(self)
    decision.choices = choices
    decision.focusIndex = 1
    decision.selectedIndex = nil
    decision.selectionComplete = false
    decision.selectionTimer = 0
    decision.hoverIndex = nil
    decision.axisState = { horizontal = 0 }
    decision.cardLayout = nil
    decision.renderSize = nil
    refreshCardStates(decision)

    self.game = game or self.game

    Audio:playSound("shop_card_deal")
    return true
end

local function applyModifier(self, choice)
    if not choice then
        return
    end

    local modifier = {
        id = choice.id,
        title = choice.title,
        summary = choice.summary,
        modifyContext = choice.modifyContext,
        onFloorStart = choice.onFloorStart,
        onFruitConsumed = choice.onFruitConsumed,
    }

    table.insert(self.activeModifiers, modifier)
    self.pickedCounts[choice.id] = (self.pickedCounts[choice.id] or 0) + 1

    if choice.applyImmediate then
        choice.applyImmediate(self.game, modifier)
    end
end

function RogueChoices:isSelectionComplete()
    local decision = getDecision(self)
    return decision and decision.selectionComplete or false
end

function RogueChoices:clearDecision()
    if self.decision then
        self.decision = nil
    end
end

function RogueChoices:setFocus(index)
    local decision = getDecision(self)
    if not decision or not index then
        return
    end

    index = clamp(index, 1, #decision.choices)
    if decision.focusIndex ~= index then
        decision.focusIndex = index
        playFocusSound()
    end

    return decision.choices[index]
end

function RogueChoices:moveFocus(delta)
    local decision = getDecision(self)
    if not decision or not delta or delta == 0 then
        return
    end

    local target = clamp((decision.focusIndex or 1) + delta, 1, #decision.choices)
    self:setFocus(target)
end

function RogueChoices:select(index)
    local decision = getDecision(self)
    if not decision or decision.selectionComplete then
        return false
    end

    local choice = decision.choices[index]
    if not choice then
        return false
    end

    decision.selectedIndex = index
    decision.selectionComplete = true
    decision.selectionTimer = 0

    applyModifier(self, choice)
    playSelectSound()
    return true
end

function RogueChoices:keypressed(_, key)
    if not self.decision then
        return false
    end

    if key == "left" or key == "a" or key == "h" then
        self:moveFocus(-1)
        return "handled"
    elseif key == "right" or key == "d" or key == "l" then
        self:moveFocus(1)
        return "handled"
    elseif key == "return" or key == "space" or key == "kpenter" then
        if self:select(self.decision.focusIndex or 1) then
            return true
        end
        return "handled"
    end

    return "handled"
end

local function isPointInside(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function RogueChoices:mousepressed(x, y, button)
    if not self.decision then
        return false
    end

    if button ~= 1 then
        return "handled"
    end

    local layout = self.decision.cardLayout
    if not layout or not layout.rects then
        if self.decision.renderSize then
            layout = computeLayout(self.decision, self.decision.renderSize.width, self.decision.renderSize.height)
        end
    end

    if layout and layout.rects then
        for index, rect in ipairs(layout.rects) do
            if isPointInside(rect, x, y) then
                self.decision.focusIndex = index
                local selected = self:select(index)
                return selected and true or "handled"
            end
        end
    end

    return "handled"
end

function RogueChoices:mousemoved(x, y)
    if not self.decision then
        return false
    end

    local layout = self.decision.cardLayout
    if not layout or not layout.rects then
        if self.decision.renderSize then
            layout = computeLayout(self.decision, self.decision.renderSize.width, self.decision.renderSize.height)
        end
    end

    if not layout or not layout.rects then
        return "handled"
    end

    local found
    for index, rect in ipairs(layout.rects) do
        if isPointInside(rect, x, y) then
            found = index
            break
        end
    end

    self.decision.hoverIndex = found
    return "handled"
end

function RogueChoices:gamepadpressed(_, button)
    if not self.decision then
        return false
    end

    if button == "dpleft" or button == "leftshoulder" then
        self:moveFocus(-1)
        return "handled"
    elseif button == "dpright" or button == "rightshoulder" then
        self:moveFocus(1)
        return "handled"
    elseif button == "a" or button == "start" then
        if self:select(self.decision.focusIndex or 1) then
            return true
        end
        return "handled"
    end

    return "handled"
end

function RogueChoices:gamepadaxis(axis, value)
    if not self.decision then
        return false
    end

    if axis ~= "leftx" and axis ~= "rightx" and axis ~= 1 then
        return "handled"
    end

    local state = self.decision.axisState or { horizontal = 0 }
    self.decision.axisState = state

    local direction = 0
    if value >= ANALOG_DEADZONE then
        direction = 1
    elseif value <= -ANALOG_DEADZONE then
        direction = -1
    end

    if direction ~= 0 and state.horizontal ~= direction then
        state.horizontal = direction
        self:moveFocus(direction)
    elseif direction == 0 then
        state.horizontal = 0
    end

    return "handled"
end

local function drawText(text, x, y, width, font, align, color)
    love.graphics.setFont(font)
    if color then
        love.graphics.setColor(color)
    end
    love.graphics.printf(text, x, y, width, align or "left")
end

local function drawList(items, x, y, width, font, color)
    local offsetY = 0
    love.graphics.setFont(font)
    for _, item in ipairs(items or {}) do
        love.graphics.setColor(color)
        love.graphics.printf(item, x, y + offsetY, width, "left")
        offsetY = offsetY + font:getHeight() + 6
    end
    return offsetY
end

function RogueChoices:update(dt)
    local decision = self.decision
    if not decision then
        return
    end

    decision.selectionTimer = decision.selectionTimer + dt

    refreshCardStates(decision)

    for index, state in ipairs(decision.cardStates) do
        local focusTarget = (decision.focusIndex == index) and 1 or 0
        local hoverTarget = (decision.hoverIndex == index) and 1 or 0
        local selectTarget = (decision.selectedIndex == index) and 1 or 0

        state.focus = approach(state.focus or 0, focusTarget, dt, 9)
        state.hover = approach(state.hover or 0, hoverTarget, dt, 9)
        state.select = approach(state.select or 0, selectTarget, dt, 10)
    end
end

function RogueChoices:draw(width, height)
    local decision = self.decision
    if not decision then
        return
    end

    computeLayout(decision, width, height)

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, width, height)

    local title = Localization:get("game.rogue_choices.title")
    local prompt = Localization:get("game.rogue_choices.prompt")
    local confirm = Localization:get("game.rogue_choices.confirm_hint")
    local gamepad = Localization:get("game.rogue_choices.gamepad_hint")
    local locked = Localization:get("game.rogue_choices.selection_locked")
    local boonLabel = Localization:get("game.rogue_choices.boons_label")
    local drawbackLabel = Localization:get("game.rogue_choices.drawbacks_label")

    drawText(title, 0, 60, width, UI.fonts.title, "center", {1, 1, 1, 1})
    drawText(prompt, width * 0.15, 140, width * 0.7, UI.fonts.subtitle, "center", {1, 1, 1, 0.9})

    local layout = decision.cardLayout
    if layout and layout.rects then
        for index, rect in ipairs(layout.rects) do
            local choice = decision.choices[index]
            local state = decision.cardStates[index]
            local scale = 1 + 0.04 * (state.focus or 0) + 0.06 * (state.select or 0)
            local centerX = rect.x + rect.w * 0.5
            local centerY = rect.y + rect.h * 0.5

            love.graphics.push()
            love.graphics.translate(centerX, centerY)
            love.graphics.scale(scale, scale)
            love.graphics.translate(-rect.w * 0.5, -rect.h * 0.5)

            local panelColor = UI.colors.panel or {0.1, 0.12, 0.16, 0.96}
            local border = UI.colors.panelBorder or borderColor
            local highlightAlpha = 0.2 * (state.focus or 0)

            love.graphics.setColor(0, 0, 0, 0.25 + 0.35 * (state.focus or 0))
            love.graphics.rectangle("fill", -12, rect.h * 0.12, rect.w + 24, rect.h + 24, 24, 24)

            love.graphics.setColor(panelColor)
            love.graphics.rectangle("fill", 0, 0, rect.w, rect.h, 20, 20)

            love.graphics.setColor(border)
            love.graphics.setLineWidth(2 + 2 * (state.focus or 0))
            love.graphics.rectangle("line", 1, 1, rect.w - 2, rect.h - 2, 18, 18)

            if state.select and state.select > 0 then
                love.graphics.setColor(1, 0.85, 0.35, 0.35 + 0.4 * state.select)
                love.graphics.rectangle("line", 4, 4, rect.w - 8, rect.h - 8, 16, 16)
            end

            love.graphics.setColor(1, 1, 1, highlightAlpha)
            love.graphics.rectangle("fill", 0, 0, rect.w, rect.h, 20, 20)

            local padding = 26
            local textWidth = rect.w - padding * 2
            local cursorY = padding

            drawText(choice.title, padding, cursorY, textWidth, UI.fonts.heading, "left", {1, 1, 1, 1})
            cursorY = cursorY + UI.fonts.heading:getHeight() + 6

            if choice.flavor and choice.flavor ~= "" then
                drawText(choice.flavor, padding, cursorY, textWidth, UI.fonts.body, "left", {1, 1, 1, 0.8})
                cursorY = cursorY + UI.fonts.body:getHeight() + 10
            end

            drawText(boonLabel, padding, cursorY, textWidth, UI.fonts.caption, "left", boonColor)
            cursorY = cursorY + UI.fonts.caption:getHeight() + 4
            cursorY = cursorY + drawList(choice.boons, padding, cursorY, textWidth, UI.fonts.body, boonColor)
            cursorY = cursorY + 8

            drawText(drawbackLabel, padding, cursorY, textWidth, UI.fonts.caption, "left", costColor)
            cursorY = cursorY + UI.fonts.caption:getHeight() + 4
            drawList(choice.drawbacks, padding, cursorY, textWidth, UI.fonts.body, costColor)

            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1, 0.85)
    drawText(confirm, 0, height - 120, width, UI.fonts.caption, "center", {1, 1, 1, 0.75})
    drawText(gamepad, 0, height - 96, width, UI.fonts.caption, "center", {1, 1, 1, 0.55})

    if decision.selectionComplete then
        drawText(locked, 0, height - 68, width, UI.fonts.button, "center", {1, 0.9, 0.5, 1})
    end

    love.graphics.pop()
end

return RogueChoices
