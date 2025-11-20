local UI = require("ui")
local DrawWord = require("drawword")
local Face = require("face")
local SawActor = require("sawactor")
local Localization = require("localization")

local max = math.max
local min = math.min
local MenuLogo = {
        LOGO_EXPORT_SIZES = {512, 1024, 2048},
        DEFAULT_LOGO_EXPORT_NAME = "logo_export",
        BUTTON_STACK_OFFSET = 80,
        BUTTON_VERTICAL_SHIFT = 40,
        BUTTON_EXTRA_SPACING = 2,
        LOGO_VERTICAL_LIFT = 40,
}

local titleSaw = SawActor.new()

function MenuLogo:update(dt)
        if titleSaw then
                titleSaw:update(dt)
        end
end

function MenuLogo:computeButtonLayout(sw, sh, labelCount, menuLayout)
        local layout = menuLayout or UI.getMenuLayout(sw, sh)
        local centerX = sw / 2
        local effectiveSpacing = (UI.spacing.buttonSpacing or 0) + self.BUTTON_EXTRA_SPACING
        local count = max(0, labelCount or 0)
        local totalButtonHeight = count * UI.spacing.buttonHeight + max(0, count - 1) * effectiveSpacing
        local stackBase = (layout.bodyTop or layout.stackTop or (sh * 0.2))
        local footerGuard = layout.footerSpacing or UI.spacing.sectionSpacing or 24
        local lowerBound = (layout.bottomY or (sh - (layout.marginBottom or sh * 0.12))) - footerGuard
        local availableHeight = max(0, lowerBound - stackBase)
        local startY = stackBase + max(0, (availableHeight - totalButtonHeight) * 0.5) + self.BUTTON_STACK_OFFSET + self.BUTTON_VERTICAL_SHIFT
        local minStart = stackBase + self.BUTTON_STACK_OFFSET + self.BUTTON_VERTICAL_SHIFT
        local maxStart = lowerBound - totalButtonHeight

        if maxStart < minStart then
                startY = maxStart
        else
                if startY > maxStart then
                        startY = maxStart
                end
                if startY < minStart then
                        startY = minStart
                end
        end

        return {
                menuLayout = layout,
                centerX = centerX,
                startY = startY,
                effectiveSpacing = effectiveSpacing,
        }
end

function MenuLogo:draw(sw, sh, layoutInfo, opts)
        if not layoutInfo then return end

        local LOGO_VERTICAL_LIFT = self.LOGO_VERTICAL_LIFT
        local menuLayout = layoutInfo.menuLayout or UI.getMenuLayout(sw, sh)
        local baseCellSize = UI.spacing.baseCellSize
        local baseSpacing = UI.spacing.baseSpacing
        local sawScale = (menuLayout.logoScale or 0.9) * min(1, sw / 1280)
        local sawRadius = 32

        local wordScale = min(sw / 1280, sh / 720) * (menuLayout.logoScale or 1)
        local cellSize = baseCellSize * wordScale
        local word = Localization:get("menu.title_word")
        local spacing = baseSpacing * wordScale
        local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
        local ox = (sw - wordWidth) / 2

        local baseOy = menuLayout.titleY or (sh * 0.2)
        local buttonTop = (layoutInfo and layoutInfo.startY) or (menuLayout.bodyTop or menuLayout.stackTop or (sh * 0.2))
        local desiredSpacing = (UI.spacing.buttonSpacing or 0) + (UI.spacing.buttonHeight or 0) * 0.25 + cellSize * 0.5
        local wordHeightForSpacing = cellSize * 2
        local targetBottom = buttonTop - desiredSpacing
        local currentBottom = baseOy + wordHeightForSpacing
        local additionalOffset = max(0, targetBottom - currentBottom)
        local oy = max(0, baseOy + additionalOffset - LOGO_VERTICAL_LIFT)

        if titleSaw and sawScale and sawRadius then
                local desiredTrackLengthWorld = wordWidth + cellSize
                local shortenedTrackLengthWorld = max(2 * sawRadius * sawScale, desiredTrackLengthWorld - 126)
                local adjustedTrackLengthWorld = shortenedTrackLengthWorld + 4
                local targetTrackLengthBase = adjustedTrackLengthWorld / sawScale
                if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
                        titleSaw.trackLength = targetTrackLengthBase
                end

                local trackLengthWorld = (titleSaw.trackLength or targetTrackLengthBase) * sawScale
                local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
                local slotThicknessWorld = slotThicknessBase * sawScale

                local targetLeft = ox - 15
                local targetBottom = oy - 41

                local sawX = targetLeft + trackLengthWorld / 2 - 4
                local sawY = targetBottom - slotThicknessWorld / 2

                titleSaw:draw(sawX, sawY, sawScale)
        end

        local trail = DrawWord.draw(word, ox, oy, cellSize, spacing)
        local head = trail and trail[#trail]

        if head and (opts == nil or opts.drawFace ~= false) then
                Face:draw(head.x, head.y, wordScale)
        end

        return head, wordScale
end

function MenuLogo:selectExportSize()
        if not love.window or not love.window.showMessageBox then
                return self.LOGO_EXPORT_SIZES[1]
        end

        local buttons = {}
        for _, size in ipairs(self.LOGO_EXPORT_SIZES) do
                buttons[#buttons + 1] = string.format("%dx%d", size, size)
        end
        buttons[#buttons + 1] = Localization:get("common.cancel") or "Cancel"

        local choice = love.window.showMessageBox(Localization:get("menu.export_logo_dev_title") or "Export logo", Localization:get("menu.export_logo_dev_prompt") or "Choose logo export size.", buttons, "info", true)
        if not choice or choice < 1 or choice > #self.LOGO_EXPORT_SIZES then
                return nil
        end

        return self.LOGO_EXPORT_SIZES[choice]
end

function MenuLogo:renderLogoToCanvas(exportSize, buttonCount, menuLayout)
        if not (love.graphics and love.graphics.newCanvas) then
                return nil, "Graphics unavailable"
        end

        local canvas = love.graphics.newCanvas(exportSize, exportSize, {format = "rgba8"})
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()

        self:draw(exportSize, exportSize, self:computeButtonLayout(exportSize, exportSize, buttonCount or 0, menuLayout), {drawFace = true})

        love.graphics.pop()

        return canvas
end

function MenuLogo:exportLogo(size, buttonCount, menuLayout)
        local exportSize = size or self:selectExportSize()
        if not exportSize then
                return nil, "cancelled"
        end

        local canvas, canvasErr = self:renderLogoToCanvas(exportSize, buttonCount, menuLayout)
        if not canvas then
                return nil, canvasErr or "failed"
        end

        local imageData = canvas:newImageData()
        local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
        local filename = string.format("%s_%dx%d_%s.png", self.DEFAULT_LOGO_EXPORT_NAME, exportSize, exportSize, timestamp)
        local ok, encodeErr = pcall(function()
                return imageData:encode("png", filename)
        end)

        if not ok then
                return nil, tostring(encodeErr)
        end

        return filename
end

return MenuLogo
