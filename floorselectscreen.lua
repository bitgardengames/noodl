local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local Localization = require("localization")
local PlayerStats = require("playerstats")
local Floors = require("floors")
local ButtonList = require("buttonlist")
local Shaders = require("shaders")
local Audio = require("audio")

local FloorSelect = {
        transitionDuration = 0.45,
}

local buttonList = ButtonList.new()
local buttons = {}
local highestUnlocked = 1
local defaultFloor = 1

local BACKGROUND_EFFECT_TYPE = "menuConstellation"
local backgroundEffectCache = {}
local backgroundEffect = nil

local ANALOG_DEADZONE = 0.35
local analogAxisDirections = { horizontal = nil, vertical = nil }

local layout = {
        startX = 0,
        startY = 0,
        gridWidth = 0,
        gridHeight = 0,
        sectionSpacing = 0,
        backY = 0,
        buttonHeight = 0,
        lastWidth = 0,
        lastHeight = 0,
}

local function configureBackgroundEffect()
        local effect = Shaders.ensure(backgroundEffectCache, BACKGROUND_EFFECT_TYPE)
        if not effect then
                backgroundEffect = nil
                return
        end

        local defaultBackdrop = select(1, Shaders.getDefaultIntensities(effect))
        effect.backdropIntensity = defaultBackdrop or effect.backdropIntensity or 0.58

        Shaders.configure(effect, {
                bgColor = Theme.bgColor,
                accentColor = Theme.buttonHover,
                highlightColor = Theme.accentTextColor,
        })

        backgroundEffect = effect
end

local function drawBackground(sw, sh)
        love.graphics.setColor(Theme.bgColor)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        if not backgroundEffect then
                configureBackgroundEffect()
        end

        if backgroundEffect then
                local intensity = backgroundEffect.backdropIntensity or select(1, Shaders.getDefaultIntensities(backgroundEffect))
                Shaders.draw(backgroundEffect, 0, 0, sw, sh, intensity)
        end

        love.graphics.setColor(1, 1, 1, 1)
end

local function resetAnalogAxis()
        analogAxisDirections.horizontal = nil
        analogAxisDirections.vertical = nil
end

local analogAxisActions = {
        horizontal = {
                negative = function()
                        buttonList:moveFocus(-1)
                end,
                positive = function()
                        buttonList:moveFocus(1)
                end,
        },
        vertical = {
                negative = function()
                        buttonList:moveFocus(-1)
                end,
                positive = function()
                        buttonList:moveFocus(1)
                end,
        },
}

local analogAxisMap = {
        leftx = { slot = "horizontal" },
        rightx = { slot = "horizontal" },
        lefty = { slot = "vertical" },
        righty = { slot = "vertical" },
        [1] = { slot = "horizontal" },
        [2] = { slot = "vertical" },
}

local function handleAnalogAxis(axis, value)
        local mapping = analogAxisMap[axis]
        if not mapping then
                return
        end

        local direction
        if value >= ANALOG_DEADZONE then
                direction = "positive"
        elseif value <= -ANALOG_DEADZONE then
                direction = "negative"
        end

        if analogAxisDirections[mapping.slot] == direction then
                return
        end

        analogAxisDirections[mapping.slot] = direction

        if direction then
                local actions = analogAxisActions[mapping.slot]
                local action = actions and actions[direction]
                if action then
                        action()
                end
        end
end

local function clamp(value, minimum, maximum)
        if value < minimum then
                return minimum
        elseif value > maximum then
                return maximum
        end
        return value
end

local function buildButtons(sw, sh)
        local spacing = UI.spacing or {}
        local marginX = math.max(72, math.floor(sw * 0.08))
        local marginBottom = math.max(140, math.floor(sh * 0.18))
        local gapX = math.max(18, spacing.buttonSpacing or 24)
        local gapY = math.max(18, spacing.buttonSpacing or 24)
        local sectionSpacing = spacing.sectionSpacing or 28

        local columns = math.max(1, math.min(4, math.ceil(highestUnlocked / 4)))
        local availableWidth = sw - marginX * 2 - gapX * (columns - 1)
        local buttonWidth = math.max(180, math.floor(availableWidth / columns))
        local buttonHeight = math.max(44, math.floor((spacing.buttonHeight or 56) * 0.9))

        local rows = math.ceil(highestUnlocked / columns)
        local gridHeight = rows * buttonHeight + math.max(0, rows - 1) * gapY

        local topMargin = math.max(120, math.floor(sh * 0.2))
        local availableHeight = sh - topMargin - marginBottom
        local startY = topMargin + math.max(0, math.floor((availableHeight - gridHeight) / 2))
        local startX = math.floor((sw - (buttonWidth * columns + gapX * (columns - 1))) / 2)

        local defs = {}

        for floor = 1, highestUnlocked do
                local col = (floor - 1) % columns
                local row = math.floor((floor - 1) / columns)
                local x = startX + col * (buttonWidth + gapX)
                local y = startY + row * (buttonHeight + gapY)
                local floorData = Floors[floor] or {}
                local labelArgs = {
                        floor = floor,
                        name = floorData.name or Localization:get("common.unknown"),
                }

                defs[#defs + 1] = {
                        id = string.format("floor_button_%d", floor),
                        x = x,
                        y = y,
                        w = buttonWidth,
                        h = buttonHeight,
                        action = {
                                state = "game",
                                data = { startFloor = floor },
                        },
                        floor = floor,
                        labelKey = "floor_select.button_label",
                        labelArgs = labelArgs,
                }
        end

        local backWidth = buttonWidth
        local backX = math.floor((sw - backWidth) / 2)
        local backY = startY + gridHeight + sectionSpacing * 4
        local maxBackY = sh - (spacing.buttonHeight or 56) - 40
        backY = clamp(backY, startY + gridHeight + sectionSpacing * 2, maxBackY)

        defs[#defs + 1] = {
                        id = "floor_back",
                        x = backX,
                        y = backY,
                        w = backWidth,
                        h = buttonHeight,
                        action = "menu",
                        labelKey = "common.back",
        }

        buttons = buttonList:reset(defs)

        for index, btn in ipairs(buttons) do
                if btn.floor == defaultFloor then
                        buttonList:setFocus(index)
                        break
                end
        end

        layout.startX = startX
        layout.startY = startY
        layout.gridWidth = buttonWidth * columns + gapX * (columns - 1)
        layout.gridHeight = gridHeight
        layout.sectionSpacing = sectionSpacing
        layout.backY = backY
        layout.buttonHeight = buttonHeight
        layout.lastWidth = sw
        layout.lastHeight = sh
end

local function ensureLayout(sw, sh)
        if layout.lastWidth ~= sw or layout.lastHeight ~= sh then
                buildButtons(sw, sh)
        end
end

function FloorSelect:enter(data)
        UI.clearButtons()
        Screen:update()
        configureBackgroundEffect()
        resetAnalogAxis()

        local requestedHighest = data and data.highestFloor
        highestUnlocked = math.max(1, math.floor(requestedHighest or PlayerStats:get("deepestFloorReached") or 1))
        local totalFloors = #Floors
        if totalFloors > 0 then
                        highestUnlocked = math.min(highestUnlocked, totalFloors)
        end

        defaultFloor = math.max(1, math.min(highestUnlocked, math.floor((data and data.defaultFloor) or highestUnlocked)))

        local sw, sh = Screen:get()
        buildButtons(sw, sh)
end

function FloorSelect:update(dt)
        local sw, sh = Screen:get()
        ensureLayout(sw, sh)

        local mx, my = love.mouse.getPosition()
        buttonList:updateHover(mx, my)
end

local function drawHeading(sw, sh)
        local title = Localization:get("floor_select.title")
        local subtitle = Localization:get("floor_select.subtitle")
        local highestText = Localization:get("floor_select.highest_label", { floor = highestUnlocked })

        UI.drawLabel(title, 0, math.floor(sh * 0.08), sw, "center", { fontKey = "title" })

        local subtitleFont = UI.fonts.body
        local subtitleHeight = subtitleFont and subtitleFont:getHeight() or 28
        local subtitleY = math.floor(sh * 0.08) + (UI.fonts.title and UI.fonts.title:getHeight() or 64) + 10
        UI.drawLabel(subtitle, sw * 0.15, subtitleY, sw * 0.7, "center", { fontKey = "body", color = UI.colors.subtleText })

        local highestY = subtitleY + subtitleHeight + 8
        UI.drawLabel(highestText, sw * 0.2, highestY, sw * 0.6, "center", { fontKey = "body", color = UI.colors.text })

        local instruction = Localization:get("floor_select.instruction")
        local instructionY = layout.startY - layout.sectionSpacing * 1.5
        UI.drawLabel(instruction, sw * 0.15, instructionY, sw * 0.7, "center", { fontKey = "body", color = UI.colors.subtleText })
end

local function drawButtons()
        for _, btn in ipairs(buttons) do
                if btn.labelKey then
                        btn.text = Localization:get(btn.labelKey, btn.labelArgs)
                end

                UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)
                UI.drawButton(btn.id)
        end
end

local function drawDescription(sw)
        local focused = buttonList:getFocused()
        local focusFloor = focused and focused.floor
        if type(focusFloor) ~= "number" then
                focusFloor = defaultFloor
        end

        local floorData = Floors[focusFloor] or {}
        local description = floorData.flavor or Localization:get("floor_select.description_fallback")
        local padding = math.max(60, math.floor(sw * 0.12))
        local width = sw - padding * 2
        local sectionSpacing = layout.sectionSpacing or 24
        local baseY = layout.backY - sectionSpacing * 2

        local bodyFont = UI.fonts.body
        local descHeight = 0
        if bodyFont then
                local _, lines = bodyFont:getWrap(description, width)
                descHeight = #lines * bodyFont:getHeight()
        end

        local minY = layout.startY + layout.gridHeight + sectionSpacing
        local y = math.max(minY, baseY - descHeight)
        UI.drawLabel(description, padding, y, width, "center", { fontKey = "body", color = UI.colors.subtleText })
end

function FloorSelect:draw()
        local sw, sh = Screen:get()
        drawBackground(sw, sh)

        drawHeading(sw, sh)
        drawButtons()
        drawDescription(sw)
end

function FloorSelect:mousepressed(x, y, button)
        buttonList:mousepressed(x, y, button)
end

function FloorSelect:mousereleased(x, y, button)
        local action = buttonList:mousereleased(x, y, button)
        if action then
                Audio:playSound("click")
                return action
        end
end

local function activateFocused()
        local action = buttonList:activateFocused()
        if action then
                Audio:playSound("click")
        end
        return action
end

function FloorSelect:keypressed(key)
        if key == "left" or key == "up" then
                buttonList:moveFocus(-1)
        elseif key == "right" or key == "down" then
                buttonList:moveFocus(1)
        elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
                return activateFocused()
        elseif key == "escape" or key == "backspace" then
                Audio:playSound("click")
                return "menu"
        end
end

function FloorSelect:gamepadpressed(_, button)
        if button == "dpup" or button == "dpleft" then
                buttonList:moveFocus(-1)
        elseif button == "dpdown" or button == "dpright" then
                buttonList:moveFocus(1)
        elseif button == "a" or button == "start" then
                return activateFocused()
        elseif button == "b" then
                Audio:playSound("click")
                return "menu"
        end
end

FloorSelect.joystickpressed = FloorSelect.gamepadpressed

function FloorSelect:gamepadaxis(_, axis, value)
        handleAnalogAxis(axis, value)
end

function FloorSelect:joystickaxis(_, axis, value)
        handleAnalogAxis(axis, value)
end

FloorSelect.joystickaxis = FloorSelect.gamepadaxis

return FloorSelect
