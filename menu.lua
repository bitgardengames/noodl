local Audio = require("audio")
local Screen = require("screen")
local UI = require("ui")
local Theme = require("theme")
local DrawWord = require("drawword")
local Face = require("face")
local ButtonList = require("buttonlist")
local Localization = require("localization")
local DailyChallenges = require("dailychallenges")
local Shaders = require("shaders")
local PlayerStats = require("playerstats")
local SawActor = require("sawactor")

local Menu = {
	transitionDuration = 0.45,
}

local ANALOG_DEADZONE = 0.35
local buttonList = ButtonList.new()
local buttons = {}
local buttonGroupHeadings = {}
local t = 0
local dailyChallenge = nil
local dailyChallengeAnim = 0
local heroTaglineText = nil
local heroTaglineY = 0
local analogAxisDirections = { horizontal = nil, vertical = nil }
local titleSaw = SawActor.new()
local sawTrail = {}

local BACKGROUND_EFFECT_TYPE = "menuKitchenGlow"
local backgroundEffectCache = {}
local backgroundEffect = nil

local BACKGROUND_SPRITE_LAYERS = {
        { count = 12, speed = 12, drift = 6, scale = 0.7, alpha = 0.18, parallax = 0.22, type = "noodle" },
        { count = 8, speed = 20, drift = 10, scale = 1.0, alpha = 0.22, parallax = 0.35, type = "utensil" },
        { count = 6, speed = 28, drift = 14, scale = 1.2, alpha = 0.28, parallax = 0.48, type = "mixed" },
}

local backgroundSprites = {}

local highlightCards = {}
local highlightIndex = 1
local highlightSwitchCooldown = 0
local highlightPanelBounds = nil
local highlightArrowBounds = { prev = nil, next = nil }

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

local function createBackgroundSprite(layer, sw, sh)
        local spriteType = layer.type
        if spriteType == "mixed" then
                spriteType = (love.math.random() < 0.5) and "noodle" or "utensil"
        end

        return {
                layer = layer,
                type = spriteType,
                x = love.math.random() * sw,
                y = love.math.random() * sh,
                speed = layer.speed * (0.6 + love.math.random()),
                drift = (love.math.random() * 2 - 1) * layer.drift,
                rotation = love.math.random() * math.pi * 2,
                scale = layer.scale * (0.8 + love.math.random() * 0.6),
                parallax = layer.parallax or 0,
        }
end

local function resetBackgroundSprites(sw, sh)
        backgroundSprites = {}

        for _, layer in ipairs(BACKGROUND_SPRITE_LAYERS) do
                for _ = 1, layer.count do
                        backgroundSprites[#backgroundSprites + 1] = createBackgroundSprite(layer, sw, sh)
                end
        end
end

local function updateBackgroundSprites(dt, sw, sh)
        if not (dt and sw and sh) then
                return
        end

        for _, sprite in ipairs(backgroundSprites) do
                sprite.x = sprite.x - sprite.speed * dt
                sprite.y = sprite.y + sprite.drift * dt * 0.25

                if sprite.x < -96 then
                        sprite.x = sw + love.math.random() * sw * 0.2
                        sprite.y = love.math.random() * sh
                        sprite.drift = (love.math.random() * 2 - 1) * (sprite.layer.drift or 4)
                        sprite.rotation = love.math.random() * math.pi * 2
                end

                if sprite.y < -120 or sprite.y > sh + 120 then
                        sprite.y = ((sprite.y + sh + 120) % (sh + 240)) - 120
                end
        end
end

local function drawSpriteShape(sprite)
        local layer = sprite.layer or {}
        local alpha = (layer.alpha or 0.2)
        local color = Theme.accentTextColor or {1, 1, 1, 1}
        local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
        love.graphics.setColor(r, g, b, alpha)

        if sprite.type == "utensil" then
                love.graphics.rectangle("fill", -8 * sprite.scale, -22 * sprite.scale, 16 * sprite.scale, 44 * sprite.scale, 6, 6)
                love.graphics.circle("fill", 0, -22 * sprite.scale, 10 * sprite.scale, 12)
        else
                love.graphics.setLineWidth(5 * sprite.scale)
                local wave = math.sin(love.timer.getTime() * 0.5 + sprite.rotation) * 8 * sprite.scale
                love.graphics.line(-28 * sprite.scale, -wave, 0, wave, 28 * sprite.scale, -wave * 0.6)
        end
end

local function drawBackgroundSprites(sw, sh)
        if #backgroundSprites == 0 then
                        return
        end

        local cx, cy = sw / 2, sh / 2
        local time = love.timer.getTime()

        for _, sprite in ipairs(backgroundSprites) do
                local depth = sprite.parallax or 0
                local offsetX = (sprite.x - cx) * depth * 0.1
                local offsetY = (sprite.y - cy) * depth * 0.08
                local bob = math.sin(time * 0.35 + sprite.rotation) * 6 * (0.5 + depth)

                love.graphics.push()
                love.graphics.translate(sprite.x + offsetX, sprite.y + offsetY + bob)
                love.graphics.rotate(sprite.rotation * 0.2 + time * 0.05 * depth)
                drawSpriteShape(sprite)
                love.graphics.pop()
        end
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

        drawBackgroundSprites(sw, sh)

        love.graphics.setColor(1, 1, 1, 1)
end

local function getDayUnit(count)
	if count == 1 then
		return Localization:get("common.day_unit_singular")
	end

	return Localization:get("common.day_unit_plural")
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

local SAW_TRAIL_LIFETIME = 0.6
local SAW_TRAIL_INTERVAL = 0.03

local function resetSawTrail()
        sawTrail = {}
end

local function updateSawTrail(dt)
        for i = #sawTrail, 1, -1 do
                local node = sawTrail[i]
                node.life = node.life - dt
                if node.life <= 0 then
                        table.remove(sawTrail, i)
                end
        end
end

local function pushSawTrailPoint(x, y)
        if not (x and y) then
                return
        end

        local now = love.timer.getTime()
        local last = sawTrail[#sawTrail]

        if last and now - (last.timestamp or 0) < SAW_TRAIL_INTERVAL then
                return
        end

        sawTrail[#sawTrail + 1] = {
                x = x,
                y = y,
                life = SAW_TRAIL_LIFETIME,
                timestamp = now,
        }

        if #sawTrail > 32 then
                table.remove(sawTrail, 1)
        end

end

local function drawSawTrail(sawScale)
        if #sawTrail == 0 then
                return
        end

        local baseColor = Theme.accentTextColor or { 1, 1, 1, 1 }
        local glowColor = Theme.buttonHover or { 0.6, 0.4, 0.8, 1 }
        local prevMode, prevAlphaMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")

        for index, node in ipairs(sawTrail) do
                local alpha = math.max(0, node.life / SAW_TRAIL_LIFETIME)
                local size = 18 * (sawScale or 1) * alpha
                love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.2 * alpha)
                love.graphics.circle("fill", node.x, node.y, size)
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.35 * alpha)
                love.graphics.circle("line", node.x, node.y, size * 0.6 + index * 0.3)
        end

        love.graphics.setBlendMode(prevMode, prevAlphaMode)
        love.graphics.setColor(1, 1, 1, 1)
end

local function resetAnalogAxis()
        analogAxisDirections.horizontal = nil
        analogAxisDirections.vertical = nil
end

local function prepareStartAction(action)
	if type(action) ~= "string" then
		return action
	end

	if action ~= "game" then
		return action
	end

	local deepest = PlayerStats:get("deepestFloorReached") or 0
	if deepest <= 1 then
		return action
	end

	return {
		state = "floorselect",
		data = {
			highestFloor = deepest,
			defaultFloor = deepest,
		},
	}
end

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

local function setColorWithAlpha(color, alpha)
        local r, g, b, a = 1, 1, 1, alpha or 1
        if color then
                r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
                a = (color[4] or 1) * (alpha or 1)
        end
        love.graphics.setColor(r, g, b, a)
end

local function buildDailyHighlightCard()
        if not dailyChallenge then
                return nil
        end

        local headerText = Localization:get("menu.daily_panel_header")
        if dailyChallenge.xpReward and dailyChallenge.xpReward > 0 then
                headerText = string.format("%s · +%d XP", headerText, dailyChallenge.xpReward)
        end

        local titleText = Localization:get(dailyChallenge.titleKey, dailyChallenge.descriptionReplacements)
        local descriptionText = Localization:get(dailyChallenge.descriptionKey, dailyChallenge.descriptionReplacements)

        local progressText = nil
        local statusRatio = nil
        local statusBar = dailyChallenge.statusBar
        if statusBar then
                progressText = Localization:get(statusBar.textKey, statusBar.replacements)
                statusRatio = statusBar.ratio or 0
        end

        local currentStreak = math.max(0, PlayerStats:get("dailyChallengeStreak") or 0)
        local bestStreak = math.max(currentStreak, PlayerStats:get("dailyChallengeBestStreak") or 0)

        local streakText
        if currentStreak > 0 then
                local streakLine = Localization:get("menu.daily_panel_streak", {
                        streak = currentStreak,
                        unit = getDayUnit(currentStreak),
                })

                local bestLine = Localization:get("menu.daily_panel_best", {
                        best = bestStreak,
                        unit = getDayUnit(bestStreak),
                })

                local messageKey = dailyChallenge.completed and "menu.daily_panel_complete_message" or "menu.daily_panel_keep_alive"
                local messageLine = Localization:get(messageKey)

                streakText = string.format("%s (%s) - %s", streakLine, bestLine, messageLine)
        else
                streakText = Localization:get("menu.daily_panel_start")
        end

        return {
                type = "daily",
                header = headerText,
                title = titleText,
                description = descriptionText,
                progressText = progressText,
                statusRatio = statusRatio,
                streakText = streakText,
                completed = dailyChallenge.completed,
                streakWarning = currentStreak > 0 and not dailyChallenge.completed,
        }
end

local function buildWeeklyHighlightCard()
        local current = math.max(0, PlayerStats:get("weeklyWarmupClears") or 0)
        local goal = 5
        local ratio = (goal > 0) and math.min(1, current / goal) or 0

        return {
                type = "weekly",
                header = Localization:get("menu.weekly_panel_header"),
                title = Localization:get("menu.weekly_panel_title"),
                description = Localization:get("menu.weekly_panel_description"),
                progressText = Localization:get("menu.weekly_panel_status", {
                        current = current,
                        goal = goal,
                }),
                statusRatio = ratio,
                streakText = Localization:get("menu.weekly_panel_hint"),
                streakWarning = false,
        }
end

local function buildCommunityHighlightCard()
        local highScore = math.max(0, PlayerStats:get("communityHighScore") or 0)
        local highlight = Localization:get("menu.community_panel_status", { score = highScore })

        return {
                type = "community",
                header = Localization:get("menu.community_panel_header"),
                title = Localization:get("menu.community_panel_title"),
                description = Localization:get("menu.community_panel_description"),
                progressText = highlight,
                statusRatio = nil,
                streakText = Localization:get("menu.community_panel_hint"),
                streakWarning = false,
        }
end

local function refreshHighlightCards()
        highlightCards = {}

        local dailyCard = buildDailyHighlightCard()
        if dailyCard then
                highlightCards[#highlightCards + 1] = dailyCard
        end

        highlightCards[#highlightCards + 1] = buildWeeklyHighlightCard()
        highlightCards[#highlightCards + 1] = buildCommunityHighlightCard()

        if #highlightCards == 0 then
                highlightIndex = 1
        else
                highlightIndex = math.max(1, math.min(highlightIndex, #highlightCards))
        end
end

local function setHighlightIndex(index)
        if #highlightCards == 0 then
                highlightIndex = 1
                return
        end

        local count = #highlightCards
        highlightIndex = ((index - 1) % count) + 1
        highlightSwitchCooldown = 0.25
end

local function stepHighlight(delta)
        if #highlightCards <= 1 then
                return false
        end

        if highlightSwitchCooldown > 0 then
                return false
        end

        setHighlightIndex(highlightIndex + delta)
        Audio:playSound("hover")
        return true
end

local function pointInRect(px, py, rect)
        if not rect then
                return false
        end

        return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function triggerStartFeedback()
        Audio:playSound("menu_start")

        if love.joystick and love.joystick.getJoysticks then
                for _, joystick in ipairs(love.joystick.getJoysticks()) do
                        if joystick and joystick:isVibrationSupported() then
                                joystick:setVibration(0.2, 0.35, 0.25)
                        end
                end
        end
end

function Menu:enter()
        t = 0
        UI.clearButtons()

        Audio:playMusic("menu")
	Screen:update()

        dailyChallenge = DailyChallenges:getDailyChallenge()
        dailyChallengeAnim = 0
        refreshHighlightCards()
        resetAnalogAxis()
        resetSawTrail()

        configureBackgroundEffect()

        local sw, sh = Screen:get()
        local centerX = sw / 2
        heroTaglineText = Localization:get("menu.hero_tagline")
        resetBackgroundSprites(sw, sh)

        local baseCellSize = 20
        local baseSpacing = 10
        local wordScale = 1.5
        local cellSize = baseCellSize * wordScale
        local wordHeight = cellSize * 3
        local oy = sh * 0.2

        local taglineFont = UI.fonts.subtitle or UI.fonts.body
        local taglineHeight = taglineFont and taglineFont:getHeight() or 0
        local taglineSpacing = 24

        local buttonGroups = {
                {
                        headingKey = "menu.group_primary",
                        entries = {
                                { key = "menu.start_game", action = "game" },
                                { key = "menu.progression", action = "metaprogression" },
                        },
                },
                {
                        headingKey = "menu.group_secondary",
                        entries = {
                                { key = "menu.achievements", action = "achievementsmenu" },
                                { key = "menu.settings", action = "settings" },
                                { key = "menu.dev_page", action = "dev" },
                                { key = "menu.quit", action = "quit" },
                        },
                },
        }

        local headingFont = UI.fonts.prompt or UI.fonts.caption or UI.fonts.small
        local headingHeight = headingFont and headingFont:getHeight() or 0
        local headingSpacing = 10
        local groupSpacing = UI.spacing.buttonSpacing * 1.35
        local buttonSpacing = UI.spacing.buttonSpacing

        local totalHeight = 0
        for _, group in ipairs(buttonGroups) do
                totalHeight = totalHeight + headingHeight + headingSpacing
                for index = 1, #group.entries do
                        totalHeight = totalHeight + UI.spacing.buttonHeight
                        if index < #group.entries then
                                totalHeight = totalHeight + buttonSpacing
                        end
                end
        end

        totalHeight = totalHeight + groupSpacing * (#buttonGroups - 1)

        local desiredStart = oy + wordHeight + taglineHeight + taglineSpacing
        local centeredStart = (sh / 2) - totalHeight / 2 + sh * 0.04
        local startY = math.max(desiredStart, centeredStart)
        heroTaglineY = startY - taglineSpacing - taglineHeight

        local defs = {}
        buttonGroupHeadings = {}

        local currentY = startY
        local buttonIndex = 0

        for groupIndex, group in ipairs(buttonGroups) do
                local headingY = currentY
                buttonGroupHeadings[#buttonGroupHeadings + 1] = {
                        key = group.headingKey,
                        x = centerX,
                        y = headingY,
                        font = headingFont,
                        groupIndex = groupIndex,
                }

                currentY = currentY + headingHeight + headingSpacing

                for _, entry in ipairs(group.entries) do
                        buttonIndex = buttonIndex + 1
                        local x = centerX - UI.spacing.buttonWidth / 2
                        local y = currentY

                        defs[#defs + 1] = {
                                id = "menuButton" .. buttonIndex,
                                x = x,
                                y = y,
                                w = UI.spacing.buttonWidth,
                                h = UI.spacing.buttonHeight,
                                labelKey = entry.key,
                                text = Localization:get(entry.key),
                                action = entry.action,
                                hovered = false,
                                scale = 1,
                                alpha = 0,
                                offsetY = 50,
                                groupIndex = groupIndex,
                        }

                        currentY = currentY + UI.spacing.buttonHeight + buttonSpacing
                end

                if groupIndex < #buttonGroups then
                        currentY = currentY + groupSpacing - buttonSpacing
                end
        end

        buttons = buttonList:reset(defs)
end

function Menu:update(dt)
        t = t + dt

        local mx, my = love.mouse.getPosition()
        buttonList:updateHover(mx, my)

        highlightSwitchCooldown = math.max(0, highlightSwitchCooldown - dt)

        local sw, sh = Screen:get()
        updateBackgroundSprites(dt, sw, sh)
        updateSawTrail(dt)

        if #highlightCards > 0 then
                dailyChallengeAnim = math.min(dailyChallengeAnim + dt * 2, 1)
        end

        for i, btn in ipairs(buttons) do
                if btn.hovered then
                        btn.scale = math.min((btn.scale or 1) + dt * 5, 1.1)
                else
			btn.scale = math.max((btn.scale or 1) - dt * 5, 1.0)
		end

		local appearDelay = (i - 1) * 0.08
		local appearTime = math.min((t - appearDelay) * 3, 1)
		btn.alpha = math.max(0, math.min(appearTime, 1))
		btn.offsetY = (1 - btn.alpha) * 50
	end

	if titleSaw then
		titleSaw:update(dt)
	end

	Face:update(dt)
end

function Menu:draw()
        local sw, sh = Screen:get()

        drawBackground(sw, sh)

	local baseCellSize = 20
	local baseSpacing = 10
	local wordScale = 1.5

	local cellSize = baseCellSize * wordScale
	local word = Localization:get("menu.title_word")
	local spacing = baseSpacing * wordScale
        local wordWidth = (#word * (3 * cellSize + spacing)) - spacing - (cellSize * 3)
        local ox = (sw - wordWidth) / 2
        local oy = sh * 0.2

        if titleSaw then
                local sawRadius = titleSaw.radius or 1
                local wordHeight = cellSize * 3
                local sawScale = wordHeight / (2 * sawRadius)
                if sawScale <= 0 then
                        sawScale = 1
                end

                local desiredTrackLengthWorld = wordWidth + cellSize
                local shortenedTrackLengthWorld = math.max(2 * sawRadius * sawScale, desiredTrackLengthWorld - 90)
                local targetTrackLengthBase = shortenedTrackLengthWorld / sawScale
                if not titleSaw.trackLength or math.abs(titleSaw.trackLength - targetTrackLengthBase) > 0.001 then
                        titleSaw.trackLength = targetTrackLengthBase
                end

                local trackLengthWorld = (titleSaw.trackLength or targetTrackLengthBase) * sawScale
                local slotThicknessBase = titleSaw.getSlotThickness and titleSaw:getSlotThickness() or 10
                local slotThicknessWorld = slotThicknessBase * sawScale

                local targetLeft = ox - 15
                local targetBottom = oy - 30

                local sawX = targetLeft + trackLengthWorld / 2
                local sawY = targetBottom - slotThicknessWorld / 2

                pushSawTrailPoint(sawX, sawY)
                drawSawTrail(sawScale)
                titleSaw:draw(sawX, sawY, sawScale)
        else
                drawSawTrail(1)
        end

        local trail = DrawWord.draw(word, ox, oy, cellSize, spacing)

        if trail and #trail > 0 then
                local head = trail[#trail]
                Face:draw(head.x, head.y, wordScale)
        end

        if heroTaglineText and heroTaglineText ~= "" and heroTaglineY > 0 then
                local taglineFont = UI.fonts.subtitle or UI.fonts.body
                if taglineFont then
                        love.graphics.setFont(taglineFont)
                end
                setColorWithAlpha(Theme.mutedTextColor or Theme.textColor, 0.9)
                love.graphics.printf(heroTaglineText, 0, heroTaglineY, sw, "center")
        end

        local headingWidth = UI.spacing.buttonWidth
        for _, heading in ipairs(buttonGroupHeadings) do
                if heading.key then
                        local font = heading.font or UI.fonts.prompt or UI.fonts.body
                        if font then
                                love.graphics.setFont(font)
                        end
                        local groupAlpha = 0
                        for _, btn in ipairs(buttons) do
                                if btn.groupIndex == heading.groupIndex then
                                        groupAlpha = math.max(groupAlpha, btn.alpha or 0)
                                        break
                                end
                        end
                        setColorWithAlpha(Theme.mutedTextColor or Theme.textColor, 0.82 * math.max(groupAlpha, 0.2))
                        love.graphics.printf(Localization:get(heading.key), heading.x - headingWidth / 2, heading.y, headingWidth, "center")
                end
        end

        for _, btn in ipairs(buttons) do
                if btn.labelKey then
                        btn.text = Localization:get(btn.labelKey)
                end

                if btn.alpha > 0 then
                        UI.registerButton(btn.id, btn.x, btn.y, btn.w, btn.h, btn.text)

                        love.graphics.push()
                        love.graphics.translate(btn.x + btn.w / 2, btn.y + btn.h / 2 + btn.offsetY)
                        love.graphics.scale(btn.scale)
                        love.graphics.translate(-(btn.x + btn.w / 2), -(btn.y + btn.h / 2))

                        UI.drawButton(btn.id)

                        local focusStrength = btn.focused and 1 or 0
                        local hoverStrength = btn.hovered and 0.65 or 0
                        local accentStrength = math.max(focusStrength, hoverStrength)
                        if accentStrength > 0 then
                                local baseY = btn.y + btn.offsetY
                                local accentAlpha = btn.alpha * accentStrength

                                setColorWithAlpha(Theme.progressColor or Theme.accentTextColor, accentAlpha * 0.7)
                                love.graphics.rectangle("fill", btn.x - 6, baseY, 6, btn.h, 3, 3)

                                setColorWithAlpha(Theme.buttonHover, accentAlpha * 0.18)
                                love.graphics.rectangle("fill", btn.x, baseY, btn.w, btn.h, UI.spacing.buttonRadius, UI.spacing.buttonRadius)
                                love.graphics.setColor(1, 1, 1, 1)
                        end

                        love.graphics.pop()
                end
        end

        highlightPanelBounds = nil
        highlightArrowBounds.prev = nil
        highlightArrowBounds.next = nil

        local versionText = Localization:get("menu.version")
        local versionFont = UI.fonts.small
        local versionWidthDefault = versionFont and versionFont:getWidth(versionText) or 0
        local versionX = sw - versionWidthDefault - 36
        local versionY = sh - 28

        if #highlightCards > 0 and dailyChallengeAnim > 0 then
                local alpha = math.min(1, dailyChallengeAnim)
                local eased = alpha * alpha
                local panelWidth = math.min(440, sw - 72)
                local padding = UI.spacing.panelPadding or 16
                local panelX = sw - panelWidth - 36
                local headerFont = UI.fonts.small
                local titleFont = UI.fonts.button
                local bodyFont = UI.fonts.body
                local progressFont = UI.fonts.small

                local card = highlightCards[highlightIndex]
                local headerText = card.header or ""
                local titleText = card.title or ""
                local descriptionText = card.description or ""

                local wrapWidth = panelWidth - padding * 2
                local descHeight = 0
                if descriptionText ~= "" then
                        local _, descLines = bodyFont:getWrap(descriptionText, wrapWidth)
                        descHeight = #descLines * bodyFont:getHeight()
                end

                local statusBarHeight = 0
                if card.statusRatio ~= nil then
                        statusBarHeight = 10 + 14
                        if card.progressText and card.progressText ~= "" then
                                statusBarHeight = statusBarHeight + progressFont:getHeight() + 6
                        end
                end

                local streakText = card.streakText
                local streakHeight = 0
                if streakText and streakText ~= "" then
                        local _, streakLinesWrapped = progressFont:getWrap(streakText, wrapWidth)
                        local lineCount = math.max(1, #streakLinesWrapped)
                        streakHeight = lineCount * progressFont:getHeight()
                end

                local panelHeight = padding * 2
                        + (headerFont and headerFont:getHeight() or 0)
                        + 6
                        + (titleFont and titleFont:getHeight() or 0)
                        + 10
                        + descHeight
                        + statusBarHeight

                if streakHeight > 0 then
                        panelHeight = panelHeight + 8 + streakHeight
                end

                local panelY = math.max(36, sh - panelHeight - 48)

                highlightPanelBounds = { x = panelX, y = panelY, w = panelWidth, h = panelHeight }

                setColorWithAlpha(Theme.shadowColor, eased * 0.7)
                love.graphics.rectangle("fill", panelX + 6, panelY + 8, panelWidth, panelHeight, 14, 14)

                setColorWithAlpha(Theme.panelColor, alpha)
                UI.drawRoundedRect(panelX, panelY, panelWidth, panelHeight, 14)

                setColorWithAlpha(Theme.panelBorder, alpha)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 14, 14)

                local textX = panelX + padding
                local textY = panelY + padding

                if headerFont then
                        love.graphics.setFont(headerFont)
                end
                setColorWithAlpha(Theme.shadowColor, alpha)
                love.graphics.print(headerText, textX + 2, textY + 2)
                setColorWithAlpha(Theme.textColor, alpha)
                love.graphics.print(headerText, textX, textY)

                textY = textY + (headerFont and headerFont:getHeight() or 0) + 6

                if titleFont then
                        love.graphics.setFont(titleFont)
                end
                love.graphics.print(titleText, textX, textY)
                textY = textY + (titleFont and titleFont:getHeight() or 0) + 10

                if descHeight > 0 then
                        if bodyFont then
                                love.graphics.setFont(bodyFont)
                        end
                        love.graphics.printf(descriptionText, textX, textY, wrapWidth)
                        textY = textY + descHeight
                end

                if streakHeight > 0 then
                        textY = textY + 8
                        if progressFont then
                                love.graphics.setFont(progressFont)
                        end
                        if card.streakWarning then
                                setColorWithAlpha(Theme.warningColor or Theme.accentTextColor, alpha)
                        else
                                setColorWithAlpha(Theme.mutedTextColor or Theme.textColor, alpha)
                        end
                        love.graphics.printf(streakText, textX, textY, wrapWidth)
                        textY = textY + streakHeight
                        setColorWithAlpha(Theme.textColor, alpha)
                end

                if card.statusRatio ~= nil then
                        textY = textY + 10
                        if progressFont then
                                love.graphics.setFont(progressFont)
                        end

                        if card.progressText and card.progressText ~= "" then
                                love.graphics.print(card.progressText, textX, textY)
                                textY = textY + progressFont:getHeight() + 6
                        end

                        local barHeight = 14
                        local barWidth = panelWidth - padding * 2

                        setColorWithAlpha({0, 0, 0, 0.35}, alpha)
                        UI.drawRoundedRect(textX, textY, barWidth, barHeight, 8)

                        local fillWidth = barWidth * math.max(0, math.min(card.statusRatio or 0, 1))
                        if fillWidth > 0 then
                                setColorWithAlpha(Theme.progressColor, alpha)
                                UI.drawRoundedRect(textX, textY, fillWidth, barHeight, 8)
                        end

                        setColorWithAlpha(Theme.panelBorder, alpha)
                        love.graphics.setLineWidth(1.5)
                        love.graphics.rectangle("line", textX, textY, barWidth, barHeight, 8, 8)

                        textY = textY + barHeight
                end

                if #highlightCards > 1 then
                        local arrowSize = 14
                        local arrowPadding = 10
                        local centerY = panelY + panelHeight / 2
                        highlightArrowBounds.prev = {
                                x = panelX - arrowPadding - arrowSize,
                                y = centerY - arrowSize,
                                w = arrowSize,
                                h = arrowSize * 2,
                        }
                        highlightArrowBounds.next = {
                                x = panelX + panelWidth + arrowPadding,
                                y = centerY - arrowSize,
                                w = arrowSize,
                                h = arrowSize * 2,
                        }

                        setColorWithAlpha(Theme.panelBorder, alpha * 0.8)
                        love.graphics.polygon("fill",
                                highlightArrowBounds.prev.x + highlightArrowBounds.prev.w,
                                highlightArrowBounds.prev.y,
                                highlightArrowBounds.prev.x + highlightArrowBounds.prev.w,
                                highlightArrowBounds.prev.y + highlightArrowBounds.prev.h,
                                highlightArrowBounds.prev.x,
                                centerY)

                        love.graphics.polygon("fill",
                                highlightArrowBounds.next.x,
                                highlightArrowBounds.next.y,
                                highlightArrowBounds.next.x,
                                highlightArrowBounds.next.y + highlightArrowBounds.next.h,
                                highlightArrowBounds.next.x + highlightArrowBounds.next.w,
                                centerY)

                        local dotCount = #highlightCards
                        local dotSpacing = 12
                        local totalWidth = (dotCount - 1) * dotSpacing
                        local dotStart = panelX + panelWidth / 2 - totalWidth / 2
                        local dotY = panelY + panelHeight - 18

                        for i = 1, dotCount do
                                local active = (i == highlightIndex)
                                local dotAlpha = alpha * (active and 1 or 0.35)
                                setColorWithAlpha(Theme.textColor, dotAlpha)
                                if active then
                                        love.graphics.circle("fill", dotStart + (i - 1) * dotSpacing, dotY, 4)
                                else
                                        love.graphics.circle("line", dotStart + (i - 1) * dotSpacing, dotY, 4)
                                end
                        end
                end

                local hintText = Localization:get("menu.highlight_cycle_hint")
                local hintHeight = 0
                if hintText and hintText ~= "" then
                        if progressFont then
                                love.graphics.setFont(progressFont)
                        end
                        setColorWithAlpha(Theme.mutedTextColor or Theme.textColor, alpha * 0.9)
                        love.graphics.printf(hintText, panelX, panelY + panelHeight + 6, panelWidth, "center")
                        hintHeight = progressFont and progressFont:getHeight() or 0
                end

                local versionWidth = versionFont and versionFont:getWidth(versionText) or 0
                versionX = panelX + panelWidth - versionWidth
                versionY = panelY + panelHeight + 10 + hintHeight
        end

        love.graphics.setLineWidth(1)
        if versionFont then
                love.graphics.setFont(versionFont)
        end
        setColorWithAlpha(Theme.mutedTextColor or Theme.textColor, 0.85)
        love.graphics.print(versionText, versionX, versionY)
end

function Menu:mousepressed(x, y, button)
        if button == 1 then
                if pointInRect(x, y, highlightArrowBounds.prev) then
                        stepHighlight(-1)
                        return
                elseif pointInRect(x, y, highlightArrowBounds.next) then
                        stepHighlight(1)
                        return
                end
        end

        buttonList:mousepressed(x, y, button)
end

function Menu:mousereleased(x, y, button)
        if button == 1 then
                if pointInRect(x, y, highlightArrowBounds.prev) or pointInRect(x, y, highlightArrowBounds.next) then
                        return
                end
        end

        local action, entry = buttonList:mousereleased(x, y, button)
        if action then
                if entry and entry.action == "game" then
                        triggerStartFeedback()
                end
                return prepareStartAction(action)
        end
end

local function handleMenuConfirm()
        local action, entry = buttonList:activateFocused()
        if action then
                if entry and entry.action == "game" then
                        triggerStartFeedback()
                else
                        Audio:playSound("click")
                end
                return prepareStartAction(action)
        end
end

function Menu:keypressed(key)
        if key == "q" or key == "pageup" then
                if stepHighlight(-1) then
                        return
                end
        elseif key == "e" or key == "pagedown" then
                if stepHighlight(1) then
                        return
                end
        end

        if key == "up" or key == "left" then
                buttonList:moveFocus(-1)
        elseif key == "down" or key == "right" then
                buttonList:moveFocus(1)
        elseif key == "return" or key == "kpenter" or key == "enter" or key == "space" then
                return handleMenuConfirm()
        elseif key == "escape" or key == "backspace" then
                return "quit"
        end
end

function Menu:gamepadpressed(_, button)
        if button == "leftshoulder" then
                if stepHighlight(-1) then
                        return
                end
        elseif button == "rightshoulder" then
                if stepHighlight(1) then
                        return
                end
        elseif button == "dpup" or button == "dpleft" then
                buttonList:moveFocus(-1)
        elseif button == "dpdown" or button == "dpright" then
                buttonList:moveFocus(1)
        elseif button == "a" or button == "start" then
                return handleMenuConfirm()
        elseif button == "b" then
                return "quit"
        end
end

Menu.joystickpressed = Menu.gamepadpressed

function Menu:gamepadaxis(_, axis, value)
	handleAnalogAxis(axis, value)
end

Menu.joystickaxis = Menu.gamepadaxis

return Menu
