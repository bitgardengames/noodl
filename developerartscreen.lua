local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local MenuScene = require("menuscene")
local Localization = require("localization")
local MenuLogo = require("menulogo")
local ButtonList = require("buttonlist")
local Audio = require("audio")
local Face = require("face")

local max = math.max
local min = math.min

local DeveloperArtScreen = {
        transitionDuration = 0.4,
        transitionStyle = "menuSlide",
}

local buttonList = ButtonList.new()
local buttons = {}
local buttonLocaleRevision = nil
local previewCanvas = nil
local previewSize = MenuLogo.LOGO_EXPORT_SIZES[2] or 1024
local DEFAULT_MENU_BUTTON_COUNT = 5

local buttonEntries = {
        {key = "developer_art.export_png", action = "export"},
        {key = "common.back", action = "menu"},
}

local function getBackgroundOptions(self)
        return MenuScene.getPlainBackgroundOptions()
end

local function drawBackground(sw, sh, options)
        if MenuScene.shouldDrawBackground and not MenuScene.shouldDrawBackground() then
                return
        end

        MenuScene.drawBackground(sw, sh, options)
end

local function ensurePreviewCanvas()
        if not (love.graphics and love.graphics.newCanvas) then
                previewCanvas = nil
                return nil, "Graphics unavailable"
        end

        if previewCanvas and previewCanvas:getWidth() == previewSize then
                return previewCanvas
        end

	previewCanvas = love.graphics.newCanvas(previewSize, previewSize, {format = "rgba8", stencil = true})
        return previewCanvas
end

local function refreshPreviewCanvas()
        local canvas, err = ensurePreviewCanvas()
        if not canvas then
                return nil, err
        end

        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()

        MenuLogo:draw(previewSize, previewSize, MenuLogo:computeButtonLayout(previewSize, previewSize, DEFAULT_MENU_BUTTON_COUNT), {drawFace = true})

        love.graphics.pop()

        return canvas
end

local function updateButtonTexts(revision)
        local currentRevision = revision or Localization:getRevision()

        for _, btn in ipairs(buttons) do
            if btn.labelKey then
                btn.text = Localization:get(btn.labelKey)
            end
        end

        buttonLocaleRevision = currentRevision
end

local function computeLayout(sw, sh)
        local layout = UI.getMenuLayout(sw, sh)
        local margin = layout.marginHorizontal or 36
        local titleY = layout.titleY or (sh * 0.12)
        local sectionSpacing = UI.spacing.sectionSpacing or 24
        local titleFont = UI.fonts.title
        local subtitleFont = UI.fonts.body
        local titleHeight = titleFont and titleFont:getHeight() or 32
        local subtitleHeight = subtitleFont and subtitleFont:getHeight() or 18

        local previewTop = titleY + titleHeight + subtitleHeight + sectionSpacing * 0.6
        local maxPreviewSize = min(sw - margin * 2, sh * 0.52)
        local previewDrawSize = maxPreviewSize
        local previewX = (sw - previewDrawSize) / 2
        local previewY = previewTop

        local buttonSpacing = (UI.spacing.buttonSpacing or 0) + 6
        local buttonCount = #buttonEntries
        local totalButtonHeight = buttonCount * UI.spacing.buttonHeight + max(0, buttonCount - 1) * buttonSpacing
        local buttonsY = previewY + previewDrawSize + sectionSpacing
        local lowerBound = (layout.bottomY or (sh - (layout.marginBottom or sh * 0.12))) - totalButtonHeight

        if buttonsY > lowerBound then
                buttonsY = lowerBound
        end

        return {
                margin = margin,
                titleY = titleY,
                previewSize = previewDrawSize,
                previewX = previewX,
                previewY = previewY,
                buttonSpacing = buttonSpacing,
                buttonsY = buttonsY,
        }
end

local function rebuildButtons(sw, sh)
        local layout = computeLayout(sw, sh)
        local centerX = sw / 2
        local defs = {}

        for i, entry in ipairs(buttonEntries) do
                local x = centerX - UI.spacing.buttonWidth / 2
                local y = layout.buttonsY + (i - 1) * (UI.spacing.buttonHeight + layout.buttonSpacing)

                defs[#defs + 1] = {
                        id = "developerArtButton" .. i,
                        x = x,
                        y = y,
                        w = UI.spacing.buttonWidth,
                        h = UI.spacing.buttonHeight,
                        labelKey = entry.key,
                        action = entry.action,
                        text = Localization:get(entry.key),
                        hovered = false,
                }
        end

        buttons = buttonList:reset(defs)
        updateButtonTexts(Localization:getRevision())
end

local function handleAction(action)
        if not action then return end

        if action == "export" then
                local filename, err = MenuLogo:exportLogo(nil, DEFAULT_MENU_BUTTON_COUNT)

                if filename then
                        local message = string.format(Localization:get("menu.export_logo_dev_success") or "Saved logo to %s", filename)
                        if love.window and love.window.showMessageBox then
                                love.window.showMessageBox(Localization:get("menu.export_logo_dev_title") or "Export logo", message, "info")
                        else
                                print(message)
                        end
                elseif err ~= "cancelled" then
                        local message = string.format(Localization:get("menu.export_logo_dev_failed") or "Failed to export logo: %s", tostring(err))
                        if love.window and love.window.showMessageBox then
                                love.window.showMessageBox(Localization:get("menu.export_logo_dev_title") or "Export logo", message, "error")
                        else
                                print(message)
                        end
                end

                return
        end

        return action
end

function DeveloperArtScreen:getMenuBackgroundOptions()
        return getBackgroundOptions(self)
end

function DeveloperArtScreen:enter()
        UI.clearButtons()
        MenuScene.prepareBackground(self:getMenuBackgroundOptions())
        rebuildButtons(Screen:get())
end

function DeveloperArtScreen:update(dt)
        MenuLogo:update(dt)
        Face:update(dt)

        local mx, my = UI.refreshCursor()
        buttonList:updateHover(mx, my)

        local currentRevision = Localization:getRevision()
        if buttonLocaleRevision ~= currentRevision then
                updateButtonTexts(currentRevision)
        end
end

function DeveloperArtScreen:draw()
        local sw, sh = Screen:get()
        local layout = computeLayout(sw, sh)

        drawBackground(sw, sh, self:getMenuBackgroundOptions())

        local title = Localization:get("developer_art.title") or "Developer art"
        local subtitle = Localization:get("developer_art.subtitle") or "Preview and export the menu logo."
        local titleOptions = {font = UI.fonts.title, color = Theme.text or {1, 1, 1, 1}}
        local subtitleOptions = {font = UI.fonts.body, color = Theme.subtleText or {0.8, 0.8, 0.8, 1}}
        UI.drawLabel(title, layout.margin, layout.titleY, sw - layout.margin * 2, "center", titleOptions)
        UI.drawLabel(subtitle, layout.margin, layout.titleY + (titleOptions.font and titleOptions.font:getHeight() or 32), sw - layout.margin * 2, "center", subtitleOptions)

        local canvas = refreshPreviewCanvas()
        if canvas then
                local drawScale = layout.previewSize / previewSize
                local drawX = layout.previewX
                local drawY = layout.previewY

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(canvas, drawX, drawY, 0, drawScale, drawScale)

                love.graphics.setColor(1, 1, 1, 0.2)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", drawX, drawY, layout.previewSize, layout.previewSize, 12, 12)
        else
                local errorText = Localization:get("menu.export_logo_dev_failed") or "Unable to render preview"
                UI.drawLabel(errorText, layout.margin, layout.previewY + layout.previewSize / 2, sw - layout.margin * 2, "center", {font = UI.fonts.body})
        end

        buttonList:draw(1)
end

function DeveloperArtScreen:mousepressed(x, y, button)
        buttonList:mousepressed(x, y, button)
end

function DeveloperArtScreen:mousereleased(x, y, button)
        local action = buttonList:mousereleased(x, y, button)
        if action then
                Audio:playSound("click")
                return handleAction(action)
        end
end

local function handleConfirm()
        local action = buttonList:activateFocused()
        if action then
                Audio:playSound("click")
                return handleAction(action)
        end
end

function DeveloperArtScreen:keypressed(key)
        if key == "up" or key == "left" then
                buttonList:moveFocus(-1)
        elseif key == "down" or key == "right" then
                buttonList:moveFocus(1)
        elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
                return handleConfirm()
        elseif key == "escape" or key == "backspace" then
                return "menu"
        end
end

function DeveloperArtScreen:gamepadpressed(_, button)
        if button == "dpup" or button == "dpleft" then
                buttonList:moveFocus(-1)
        elseif button == "dpdown" or button == "dpright" then
                buttonList:moveFocus(1)
        elseif button == "a" or button == "start" then
                return handleConfirm()
        elseif button == "b" then
                return "menu"
        end
end

function DeveloperArtScreen:resize()
        rebuildButtons(Screen:get())
end

return DeveloperArtScreen
