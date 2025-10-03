local Theme = require("theme")
local UI = require("ui")
local Localization = require("localization")
local Snake = require("snake")
local Score = require("score")
local Arena = require("arena")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Conveyors = require("conveyors")
local Lasers = require("lasers")
local Saws = require("saws")
local Particles = require("particles")
local UpgradeVisuals = require("upgradevisuals")
local Popup = require("popup")
local FloatingText = require("floatingtext")
local PauseMenu = require("pausemenu")
local Achievements = require("achievements")
local Shop = require("shop")
local Death = require("death")
local Easing = require("easing")

local GameRenderer = {}

local clamp01 = Easing.clamp01
local easeOutExpo = Easing.easeOutExpo
local easeOutBack = Easing.easeOutBack
local easedProgress = Easing.easedProgress

local MAX_TRANSITION_TRAITS = 4

local function drawShadowedText(font, text, x, y, width, align, alpha)
    if alpha <= 0 then
        return
    end

    love.graphics.setFont(font)
    local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
    local shadowAlpha = (shadow[4] or 1) * alpha
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], shadowAlpha)
    love.graphics.printf(text, x + 2, y + 2, width, align)

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(text, x, y, width, align)
end

local function buildTraitEntries(sections, maxTraits)
    local entries = {}
    local totalTraits, shownTraits = 0, 0

    for _, section in ipairs(sections) do
        local traits = section.items
        if traits and #traits > 0 then
            local addedHeader = false

            for _, trait in ipairs(traits) do
                totalTraits = totalTraits + 1

                if shownTraits < maxTraits then
                    if not addedHeader then
                        table.insert(entries, {
                            type = "header",
                            title = section.title or Localization:get("game.floor_traits.default_title"),
                        })
                        addedHeader = true
                    end

                    table.insert(entries, {
                        type = "trait",
                        name = trait.name,
                    })
                    shownTraits = shownTraits + 1
                end
            end
        end
    end

    return entries, totalTraits, shownTraits
end

local function drawAdrenalineGlow(game)
    local glowStrength = Score:getHighScoreGlowStrength()

    if Snake.adrenaline and Snake.adrenaline.active then
        local duration = Snake.adrenaline.duration or 1
        if duration > 0 then
            local adrenalineStrength = math.max(0, math.min(1, (Snake.adrenaline.timer or 0) / duration))
            glowStrength = math.max(glowStrength, adrenalineStrength * 0.85)
        end
    end

    if glowStrength <= 0 then return end

    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local pulse = 0.85 + 0.15 * math.sin(time * 2.25)
    local easedStrength = 0.6 + glowStrength * 0.4
    local alpha = 0.18 * easedStrength * pulse

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.65, 0.82, 0.95, alpha)
    love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)
    love.graphics.pop()
end

function GameRenderer.buildModifierSections(activeFloorTraits)
    if not activeFloorTraits or #activeFloorTraits == 0 then
        return nil
    end

    return {
        {
            title = Localization:get("game.floor_traits.section_title"),
            items = activeFloorTraits,
        },
    }
end

local function drawTraitEntries(game, timer, outroAlpha, fadeAlpha)
    local sections = game.transitionTraits or GameRenderer.buildModifierSections(game.activeFloorTraits)
    if not (sections and #sections > 0) then
        return
    end

    local entries, totalTraits, shownTraits = buildTraitEntries(sections, MAX_TRANSITION_TRAITS)
    if #entries == 0 then
        return
    end

    local remaining = math.max(0, totalTraits - shownTraits)
    if remaining > 0 then
        local suffixKey = (remaining == 1)
            and "game.floor_traits.more_modifiers_one"
            or "game.floor_traits.more_modifiers_other"
        table.insert(entries, {
            type = "note",
            text = Localization:get(suffixKey, {
                count = remaining,
            }),
        })
    end

    local y = game.screenHeight / 2 + 64
    local width = game.screenWidth * 0.45
    local x = (game.screenWidth - width) / 2
    local index = 0
    local buttonFont = UI.fonts.button
    local bodyFont = UI.fonts.body

    for _, entry in ipairs(entries) do
        index = index + 1
        local offsetDelay = 0.9 + (index - 1) * 0.22
        local traitAlpha = fadeAlpha(offsetDelay, 0.4)
        local traitOffset = (1 - easeOutExpo(clamp01((timer - offsetDelay) / 0.55))) * 16 * outroAlpha

        if entry.type == "header" then
            drawShadowedText(
                buttonFont,
                entry.title or Localization:get("game.floor_traits.default_title"),
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + buttonFont:getHeight() + 4
        elseif entry.type == "trait" then
            drawShadowedText(
                buttonFont,
                "• " .. (entry.name or ""),
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + buttonFont:getHeight() + 6
        elseif entry.type == "note" then
            drawShadowedText(
                bodyFont,
                entry.text or "",
                x,
                y + traitOffset,
                width,
                "center",
                traitAlpha
            )
            y = y + bodyFont:getHeight()
        end
    end
end

local function drawTransitionFadeOut(game, timer, duration)
    local progress = easedProgress(timer, duration)
    local overlayAlpha = progress * 0.9
    local scale = 1 - 0.04 * easeOutExpo(progress)
    local yOffset = 24 * progress

    love.graphics.push()
    love.graphics.translate(game.screenWidth / 2, game.screenHeight / 2 + yOffset)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-game.screenWidth / 2, -game.screenHeight / 2)
    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)
    love.graphics.pop()

    love.graphics.setColor(0, 0, 0, overlayAlpha)
    love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)

    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, overlayAlpha * 0.25)
    local radius = math.sqrt(game.screenWidth * game.screenWidth + game.screenHeight * game.screenHeight)
    love.graphics.circle("fill", game.screenWidth / 2, game.screenHeight / 2, radius, 64)
    local time = love.timer and love.timer.getTime and love.timer.getTime() or 0
    love.graphics.setColor(1, 0.84, 0.48, overlayAlpha * 0.16)
    local burstRadius = radius * (0.32 + 0.4 * progress)
    local burstArms = 5
    love.graphics.setLineWidth(2 + progress * 3)
    for i = 1, burstArms do
        local armAngle = time * 0.45 + (i / burstArms) * math.pi * 2
        love.graphics.arc("line", "open", game.screenWidth / 2, game.screenHeight / 2, burstRadius, armAngle, armAngle + math.pi * (0.25 + 0.35 * progress))
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)

    return true
end

local function drawTransitionShop(game, timer)
    local entrance = easeOutBack(clamp01(timer / 0.6))
    local scale = 0.92 + 0.08 * entrance
    local yOffset = (1 - entrance) * 40

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)
    love.graphics.push()
    love.graphics.translate(game.screenWidth / 2, game.screenHeight / 2 + yOffset)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-game.screenWidth / 2, -game.screenHeight / 2)
    Shop:draw(game.screenWidth, game.screenHeight)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

    return true
end

local function drawTransitionFloorIntro(game, timer, duration, data)
    local floorData = data.transitionFloorData or game.currentFloorData
    if not floorData then
        return
    end

    local progress = easedProgress(timer, duration)
    local awaitingInput = data.transitionAwaitInput
    local introConfirmed = data.transitionIntroConfirmed
    local outroDuration = math.min(0.6, duration > 0 and duration * 0.5 or 0)
    local outroProgress = 0
    if outroDuration > 0 then
        local outroStart = math.max(0, duration - outroDuration)
        local outroTimer = timer
        if awaitingInput and not introConfirmed then
            outroTimer = math.min(outroTimer, outroStart)
        end
        outroProgress = clamp01((outroTimer - outroStart) / outroDuration)
    end
    local outroAlpha = 1 - outroProgress

    local overlayAlpha = math.min(0.75, progress * 0.85)
    if outroProgress > 0 then
        overlayAlpha = overlayAlpha + (1 - overlayAlpha) * outroProgress
    end
    love.graphics.setColor(0, 0, 0, overlayAlpha)
    love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)

    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    local bloomProgress = 0.55 + 0.45 * progress
    local bloomIntensity = bloomProgress * (0.45 + 0.55 * outroAlpha)
    if Arena.drawBackgroundEffect then
        Arena:drawBackgroundEffect(0, 0, game.screenWidth, game.screenHeight, bloomIntensity)
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

    local function fadeAlpha(delay, fadeDuration)
        local alpha = progress * clamp01((timer - delay) / (fadeDuration or 0.35))
        return alpha * outroAlpha
    end

    local nameAlpha = fadeAlpha(0.0, 0.45)
    local titleParams
    if nameAlpha > 0 then
        local titleProgress = easeOutBack(clamp01((timer - 0.1) / 0.6))
        local titleScale = 0.9 + 0.1 * titleProgress
        local yOffset = (1 - titleProgress) * 36 * outroAlpha
        local centerY = game.screenHeight / 2 - 80 + yOffset
        titleParams = {
            alpha = nameAlpha,
            scale = titleScale,
            centerY = centerY,
            padding = 12,
        }
    end

    local flavorParams
    local flavorAlpha = 0
    if floorData.flavor and floorData.flavor ~= "" then
        flavorAlpha = fadeAlpha(0.45, 0.4)
        if flavorAlpha > 0 then
            local flavorProgress = easeOutExpo(clamp01((timer - 0.45) / 0.65))
            local flavorOffset = (1 - flavorProgress) * 24 * outroAlpha
            local flavorPadding = 10
            local flavorHeight = UI.fonts.button:getHeight() + flavorPadding * 2
            flavorParams = {
                alpha = flavorAlpha,
                offset = flavorOffset,
                padding = flavorPadding,
                height = flavorHeight,
                y = game.screenHeight / 2 - flavorPadding + flavorOffset,
            }
        end
    end

    if titleParams or flavorParams then
        local top = math.huge
        local bottom = -math.huge
        local backdropAlpha = 0

        if titleParams then
            local titleHeight = (UI.fonts.title:getHeight() + titleParams.padding * 2) * titleParams.scale
            local titleTop = titleParams.centerY - titleParams.padding * titleParams.scale
            local titleBottom = titleTop + titleHeight
            top = math.min(top, titleTop)
            bottom = math.max(bottom, titleBottom)
            backdropAlpha = math.max(backdropAlpha, 0.6 * titleParams.alpha)
        end

        if flavorParams then
            local flavorTop = flavorParams.y
            local flavorBottom = flavorTop + flavorParams.height
            top = math.min(top, flavorTop)
            bottom = math.max(bottom, flavorBottom)
            backdropAlpha = math.max(backdropAlpha, 0.55 * flavorParams.alpha)
        end

        if top < bottom and backdropAlpha > 0 then
            local bandPadding = 4
            top = top - bandPadding
            bottom = bottom + bandPadding
            love.graphics.setColor(0, 0, 0, backdropAlpha)
            love.graphics.rectangle("fill", 0, top, game.screenWidth, bottom - top)
        end
    end

    if titleParams then
        love.graphics.setFont(UI.fonts.title)
        love.graphics.push()
        love.graphics.translate(game.screenWidth / 2, titleParams.centerY)
        love.graphics.scale(titleParams.scale, titleParams.scale)
        love.graphics.translate(-game.screenWidth / 2, -titleParams.centerY)
        local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * titleParams.alpha)
        love.graphics.printf(floorData.name, 2, titleParams.centerY + 2, game.screenWidth, "center")
        love.graphics.setColor(1, 1, 1, titleParams.alpha)
        love.graphics.printf(floorData.name, 0, titleParams.centerY, game.screenWidth, "center")
        love.graphics.pop()
    end

    if flavorParams then
        love.graphics.setFont(UI.fonts.button)
        love.graphics.push()
        love.graphics.translate(0, flavorParams.offset)
        local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
        love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * flavorParams.alpha)
        love.graphics.printf(floorData.flavor, 2, game.screenHeight / 2 + 2, game.screenWidth, "center")
        love.graphics.setColor(1, 1, 1, flavorParams.alpha)
        love.graphics.printf(floorData.flavor, 0, game.screenHeight / 2, game.screenWidth, "center")
        love.graphics.pop()
    end

    drawTraitEntries(game, timer, outroAlpha, fadeAlpha)

    if data.transitionAwaitInput then
        local introDuration = data.transitionIntroDuration or duration or 0
        local promptDelay = data.transitionIntroPromptDelay or 0
        local promptStart = introDuration + promptDelay
        local promptProgress = clamp01((timer - promptStart) / 0.45)
        local promptAlpha = promptProgress * outroAlpha

        if promptAlpha > 0 then
            local promptText = Localization:get("game.floor_intro.prompt")
            if promptText and promptText ~= "" then
                local promptFont = UI.fonts.prompt or UI.fonts.body
                love.graphics.setFont(promptFont)
                local y = game.screenHeight - promptFont:getHeight() * 2.2
                local shadow = Theme.shadowColor or { 0, 0, 0, 0.5 }
                love.graphics.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 1) * promptAlpha)
                love.graphics.printf(promptText, 2, y + 2, game.screenWidth, "center")
                love.graphics.setColor(1, 1, 1, promptAlpha)
                love.graphics.printf(promptText, 0, y, game.screenWidth, "center")
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)

    return true
end

function GameRenderer.drawDescending(game)
    if not game.hole then
        Snake:draw()
        return
    end

    local hx, hy, hr = game.hole.x, game.hole.y, game.hole.radius

    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.circle("fill", hx, hy, hr)

    Snake:drawClipped(hx, hy, hr)

    love.graphics.setColor(0, 0, 0, 1)
    local previousLineWidth = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", hx, hy, hr)
    love.graphics.setLineWidth(previousLineWidth)
    love.graphics.setColor(1, 1, 1, 1)
end

function GameRenderer.drawPlayfield(game, stateOverride)
    local renderState = stateOverride or game.state

    Arena:drawBackground()
    Death:applyShake()

    Fruit:draw()
    Rocks:draw()
    Conveyors:draw()
    Saws:draw()
    Lasers:draw()
    Arena:drawExit()

    if renderState == "descending" then
        GameRenderer.drawDescending(game)
    elseif renderState == "dying" then
        Death:draw()
    elseif renderState ~= "gameover" then
        Snake:draw()
    end

    Particles:draw()
    UpgradeVisuals:draw()
    Popup:draw()
    Arena:drawBorder()
end

function GameRenderer.drawInterface(game, callMode)
    FloatingText:draw()

    drawAdrenalineGlow(game)

    Death:drawFlash(game.screenWidth, game.screenHeight)
    PauseMenu:draw(game.screenWidth, game.screenHeight)
    UI:draw()
    Achievements:draw()

    if callMode then
        callMode(game, "draw", game.screenWidth, game.screenHeight)
    end
end

function GameRenderer.drawTransition(game, callMode)
    if not (game.transition and game.transition:isActive()) then
        return
    end

    local phase = game.transition:getPhase()
    local timer = game.transition:getTimer() or 0
    local duration = game.transition:getDuration() or 0
    local data = game.transition:getData() or {}

    if phase == "fadeout" then
        if drawTransitionFadeOut(game, timer, duration) then
            return
        end
    elseif phase == "shop" then
        if drawTransitionShop(game, timer) then
            return
        end
    elseif phase == "floorintro" then
        if drawTransitionFloorIntro(game, timer, duration, data) then
            return
        end
    elseif phase == "fadein" then
        local progress = easedProgress(timer, duration)
        local alpha = 1 - progress
        local scale = 1 + 0.03 * alpha
        local yOffset = alpha * 20

        love.graphics.push()
        love.graphics.translate(game.screenWidth / 2, game.screenHeight / 2 + yOffset)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-game.screenWidth / 2, -game.screenHeight / 2)
        GameRenderer.drawPlayfield(game, "playing")
        love.graphics.pop()

        GameRenderer.drawInterface(game, callMode)

        love.graphics.setColor(0, 0, 0, alpha * 0.85)
        love.graphics.rectangle("fill", 0, 0, game.screenWidth, game.screenHeight)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, alpha * 0.2)
        local radius = math.sqrt(game.screenWidth * game.screenWidth + game.screenHeight * game.screenHeight) * 0.75
        love.graphics.circle("fill", game.screenWidth / 2, game.screenHeight / 2, radius, 64)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return GameRenderer
