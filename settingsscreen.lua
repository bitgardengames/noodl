local Screen = require("screen")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Settings = require("settings")

local SettingsScreen = {}

local options = {
    { label = "Toggle Fullscreen", action = function()
        love.window.setFullscreen(not love.window.getFullscreen())
        Settings:save()
    end },
    { label = "Toggle Music", toggle = "muteMusic" },
    { label = "Toggle Sound FX", toggle = "muteSFX" },
    { label = "Music Volume", slider = "musicVolume" },
    { label = "SFX Volume", slider = "sfxVolume" },
    { label = "Back", action = "menu" }
}

local buttons = {}
local hoveredIndex = nil
local sliderDragging = nil

function SettingsScreen:enter()
    Screen:update()
    local sw, sh = Screen:get()
    local centerX = sw / 2
    local totalHeight = (#options) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing) - UI.spacing.buttonSpacing
    local startY = sh / 2 - totalHeight / 2

    -- reset UI.buttons so we don’t keep stale hitboxes
    UI.buttons = {}
    buttons = {}

    for i, opt in ipairs(options) do
        local x = centerX - UI.spacing.buttonWidth / 2
        local y = startY + (i - 1) * (UI.spacing.buttonHeight + UI.spacing.buttonSpacing)
        local w = UI.spacing.buttonWidth
        local h = UI.spacing.buttonHeight
        local id = "settingsOption" .. i

        table.insert(buttons, {
            id = id,
            x = x,
            y = y,
            w = w,
            h = h,
            option = opt,
            hovered = false,
        })

        -- register for clickable items (skip sliders, those are custom)
        if not opt.slider then
            UI.registerButton(id, x, y, w, h, opt.label)
        end
    end
end

function SettingsScreen:leave()
    sliderDragging = nil
end

function SettingsScreen:update(dt)
    local mx, my = love.mouse.getPosition()
    hoveredIndex = nil

    for i, btn in ipairs(buttons) do
        local opt = btn.option
        btn.hovered = UI.isHovered(btn.x, btn.y, btn.w, btn.h, mx, my)
        if btn.hovered then
            hoveredIndex = i
        end

        if sliderDragging and opt.slider == sliderDragging then
            local rel = (mx - btn.x) / btn.w
            Settings[sliderDragging] = math.min(1, math.max(0, rel))
            Settings:save()
            Audio:applyVolumes()
        end
    end
end

function SettingsScreen:draw()
    local sw, _ = Screen:get()
    love.graphics.clear(Theme.bgColor)

    love.graphics.setFont(UI.fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Settings", 0, 80, sw, "center")

    love.graphics.setFont(UI.fonts.body)

    for _, btn in ipairs(buttons) do
        local opt = btn.option
        local label = opt.label

        if opt.toggle then
            local isMuted = Settings[opt.toggle]
            label = label .. ": " .. (isMuted and "Off" or "On")
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.drawButton(btn.id)

        elseif opt.slider then
            -- slider UI
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(label, btn.x, btn.y - 20, btn.w, "center")

            local trackY = btn.y + btn.h / 2 - 4
            local trackH = 8

            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", btn.x, trackY, btn.w, trackH, 4, 4)

            local value = Settings[opt.slider]
            love.graphics.setColor(0.6, 0.8, 1.0)
            love.graphics.rectangle("fill", btn.x, trackY, btn.w * value, trackH, 4, 4)

            local handleX = btn.x + btn.w * value
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", handleX, trackY + trackH / 2, 10)

            local percentText = string.format("%.0f%%", value * 100)
            love.graphics.printf(percentText, btn.x + btn.w + 10, btn.y + btn.h / 2 - 8, 50, "left")

        else
            -- plain button
            UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, label)
            UI.drawButton(btn.id)
        end
    end
end

function SettingsScreen:mousepressed(x, y, button)
    local id = UI:mousepressed(x, y, button)

    for _, btn in ipairs(buttons) do
        local opt = btn.option

        if btn.id and btn.id == id then
            if opt.action then
                if type(opt.action) == "function" then
                    opt.action()
                else
                    return opt.action
                end
            elseif opt.toggle then
                Settings[opt.toggle] = not Settings[opt.toggle]
                Settings:save()
                Audio:applyVolumes()
            end
        end

        if opt.slider then
            local trackY = btn.y + btn.h / 2 - 4
            local trackH = 8
            local hoveredSlider = x >= btn.x and x <= btn.x + btn.w and
                                  y >= trackY and y <= trackY + trackH
            if hoveredSlider then
                sliderDragging = opt.slider
                local rel = (x - btn.x) / btn.w
                Settings[sliderDragging] = math.min(1, math.max(0, rel))
                Settings:save()
                Audio:applyVolumes()
            end
        end
    end
end

function SettingsScreen:mousereleased(x, y, button)
    UI:mousereleased(x, y, button)
    sliderDragging = nil
end

return SettingsScreen