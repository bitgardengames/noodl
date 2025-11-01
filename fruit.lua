local Particles = require("particles")
local SnakeUtils = require("snakeutils")
local Theme = require("theme")
local Arena = require("arena")
local RenderLayers = require("renderlayers")
local MathUtil = require("noodl.mathutil")

local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin

local fruitWeightTotal = 0
local fruitWeightCumulative = {}
local fruitWeightDirty = true

local function markFruitWeightsDirty()
	fruitWeightDirty = true
end

local highlightDefault = {1, 1, 1, 1}
local defaultHighlightColor

local function updateHighlightColor(out, color)
        local r = min(1, color[1] * 1.2 + 0.08)
        local g = min(1, color[2] * 1.2 + 0.08)
        local b = min(1, color[3] * 1.2 + 0.08)
        local a = (color[4] or 1) * 0.75
        out[1], out[2], out[3], out[4] = r, g, b, a
        return out
end

local function computeHighlightColor(color, out)
        color = color or highlightDefault
        out = out or {0, 0, 0, 0}
        return updateHighlightColor(out, color)
end

local function refreshFruitHighlight(entry)
        if not entry then
                return nil
        end

        entry.highlightColor = computeHighlightColor(entry.color, entry.highlightColor)
        return entry.highlightColor
end

defaultHighlightColor = computeHighlightColor(nil, {0, 0, 0, 0})

local function attachFruitTypeMetatable(entry)
        refreshFruitHighlight(entry)
        return setmetatable(entry, {
                __newindex = function(t, key, value)
                        rawset(t, key, value)
                        if key == "weight" then
                                markFruitWeightsDirty()
                        elseif key == "color" then
                                refreshFruitHighlight(t)
                        end
                end,
        })
end

local fruitTypes = {
	{
		id = "apple",
		name = "Apple",
		color = Theme.appleColor,
		points = 1,
		weight = 70,
	},
	{
		id = "banana",
		name = "Banana",
		color = Theme.bananaColor,
		points = 3,
		weight = 20,
	},
	{
		id = "blueberry",
		name = "Blueberry",
		color = Theme.blueberryColor,
		points = 5,
		weight = 8,
	},
	{
		id = "goldenPear",
		name = "GoldenPear",
		color = Theme.goldenPearColor,
		points = 10,
		weight = 2,
	},
	{
		id = "dragonfruit",
		name = "Dragonfruit",
		color = Theme.dragonfruitColor,
		points = 50,
		weight = 0.2,
	},
}

for i = 1, #fruitTypes do
	fruitTypes[i] = attachFruitTypeMetatable(fruitTypes[i])
end

setmetatable(fruitTypes, {
	__newindex = function(t, key, value)
		if type(value) == "table" then
			value = attachFruitTypeMetatable(value)
		end
		rawset(t, key, value)
		markFruitWeightsDirty()
	end,
})

local function refreshFruitWeightCache()
	local total = 0
	for i = #fruitWeightCumulative, 1, -1 do
		fruitWeightCumulative[i] = nil
	end
	for i, fruit in ipairs(fruitTypes) do
		total = total + (fruit.weight or 0)
		fruitWeightCumulative[i] = total
	end
	fruitWeightTotal = total
	fruitWeightDirty = false
end

local function ensureFruitWeightCache()
	if fruitWeightDirty then
		refreshFruitWeightCache()
	end
end

local Fruit = {}

function Fruit.invalidateFruitWeights()
	markFruitWeightsDirty()
end

local SEGMENT_SIZE   = 24
local HITBOX_SIZE    = SEGMENT_SIZE - 1
Fruit.SEGMENT_SIZE   = SEGMENT_SIZE

-- Spawn / land tuning
local DROP_HEIGHT     = 40
local DROP_DURATION   = 0.30
local SQUASH_DURATION = 0.12
local WOBBLE_DURATION = 0.22

-- Idle flourish tuning
local IDLE_FLOAT_AMPLITUDE = 3.6
local IDLE_FLOAT_SPEED = 1.6
local IDLE_GLOW_SPEED = 2.4
local IDLE_SPARKLE_MIN_DELAY = 0.55
local IDLE_SPARKLE_MAX_DELAY = 1.15
local IDLE_SPARKLE_DURATION = 0.85
local IDLE_SPARKLE_SPIN = 1.2

local FADE_DURATION   = 0.20

-- Fruit styling
local SHADOW_OFFSET = 3
local OUTLINE_SIZE = 3

-- State
local active = {
        x = 0, y = 0,
        alpha = 0,
        scaleX = 1, scaleY = 1,
        shadow = 0.5,
        offsetY = 0,
        type = fruitTypes[1],
        phase = "idle",
        timer = 0,
        drawCache = {},
}
local fading = nil
local fadingDrawCache = {}
local fadeTimer = 0
local lastCollectedType = fruitTypes[1]
local lastCollectedMeta = nil
local idleSparkles = {}
local drawList = {}

local function drawFruitShadows(list, count)
        for i = 1, count do
                local data = list[i]
                drawFruitShadow(data)
        end
end

local function drawFruitMainBatch(list, count)
        for i = 1, count do
                local data = list[i]
                drawFruitMain(data)
        end
end

local function copyColor(color)
	if not color then
		return {1, 1, 1, 1}
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
	}
end

-- Easing
local clamp = MathUtil.clamp

local function easeOutQuad(t)  return 1 - (1 - t)^2 end
-- Helpers
local function chooseFruitType()
	ensureFruitWeightCache()

	if fruitWeightTotal <= 0 then
		return fruitTypes[1]
	end

	local r = love.math.random() * fruitWeightTotal
	for i, cumulative in ipairs(fruitWeightCumulative) do
		if r <= cumulative then
			return fruitTypes[i]
		end
	end

	return fruitTypes[#fruitTypes] or fruitTypes[1]
end

local function findFruitType(option)
	if not option then
		return nil
	end

	if type(option) == "table" and option.id and option.name then
		return option
	end

	if type(option) == "string" then
		for _, f in ipairs(fruitTypes) do
			if f.id == option or f.name == option then
				return f
			end
		end
	end

	return nil
end

local function clearLastCollectedMeta()
	lastCollectedMeta = nil
end

local function spawnIdleSparkle(x, y, color)
	idleSparkles[#idleSparkles + 1] = {
		x = x,
		y = y,
		color = copyColor(color),
		timer = 0,
		duration = IDLE_SPARKLE_DURATION,
		angle = love.math.random() * pi * 2,
		spin = (love.math.random() - 0.5) * IDLE_SPARKLE_SPIN,
		radius = HITBOX_SIZE * 0.45 + love.math.random() * HITBOX_SIZE * 0.25,
		drift = love.math.random() * 8 + 6,
		size = 1.8 + love.math.random() * 1.6,
	}
end

local function aabb(x1,y1,w1,h1, x2,y2,w2,h2)
	return x1 < x2 + w2 and x1 + w1 > x2 and
	y1 < y2 + h2 and y1 + h1 > y2
end

function Fruit:spawn(trail, rocks, safeZone, options)
	options = options or {}

	local cx, cy, col, row = SnakeUtils.getSafeSpawn(trail, self, rocks, safeZone)
	if not cx then
		local attempts = max(1, (Arena.cols or 0) * (Arena.rows or 0))
		for _ = 1, attempts do
			local candidateCol, candidateRow = Arena:getRandomTile()
			if candidateCol and candidateRow and not SnakeUtils.isOccupied(candidateCol, candidateRow) then
				local candidateX, candidateY = Arena:getCenterOfTile(candidateCol, candidateRow)
				if candidateX and candidateY then
					col, row = candidateCol, candidateRow
					cx, cy = candidateX, candidateY
					break
				end
			end
		end

		if not cx then
			col, row = Arena:getRandomTile()
			cx, cy = Arena:getCenterOfTile(col, row)
		end
	end

	active.x, active.y = cx, cy
	active.col, active.row = col, row
	local forcedType = findFruitType(options.type or options.typeId)
	active.type   = forcedType or chooseFruitType()
	active.alpha  = 0
	active.scaleX = 0.8
	active.scaleY = 0.6
	active.shadow = 0.35
	active.offsetY= -DROP_HEIGHT
	active.phase  = "drop"
	active.timer  = 0
	active.bobOffset = 0
	active.idleTimer = 0
	active.glowPulse = 1
	active.sparkleTimer = love.math.random(IDLE_SPARKLE_MIN_DELAY, IDLE_SPARKLE_MAX_DELAY)
	active.isBonus = options.isBonus or false
	if options.countsForGoal == nil then
		active.countsForGoal = true
	else
		active.countsForGoal = not (options.countsForGoal == false)
	end
	active.eventTag = options.eventTag
	active.expireDuration = options.lifespan
	active.expireTimer = nil
	active.onExpire = options.onExpire

	if col and row then
		SnakeUtils.setOccupied(col, row, true)
	end

	idleSparkles = {}
	clearLastCollectedMeta()
end

function Fruit:update(dt)
	if fading then
		fadeTimer = fadeTimer + dt
		local p = clamp(fadeTimer / FADE_DURATION, 0, 1)
		local e = easeOutQuad(p)
		fading.alpha = 1 - e
		fading.scaleX = 1 - 0.2 * e
		fading.scaleY = 1 - 0.2 * e
		if p >= 1 then fading = nil end
	end

	for i = #idleSparkles, 1, -1 do
		local sparkle = idleSparkles[i]
		sparkle.timer = sparkle.timer + dt
		sparkle.angle = sparkle.angle + sparkle.spin * dt
		sparkle.radius = sparkle.radius + sparkle.drift * dt * 0.08
		if sparkle.timer >= sparkle.duration then
			local lastIndex = #idleSparkles
			if i ~= lastIndex then
				idleSparkles[i] = idleSparkles[lastIndex]
			end
			idleSparkles[lastIndex] = nil
		end
	end

	active.timer = active.timer + dt

	if active.phase ~= "inactive" and active.expireDuration and active.expireDuration > 0 then
		active.expireTimer = (active.expireTimer or 0) + dt
		if active.expireTimer >= active.expireDuration then
			local expireCallback = active.onExpire
			local expireInfo = {
				x = active.x,
				y = active.y,
				eventTag = active.eventTag,
				isBonus = active.isBonus,
				countsForGoal = active.countsForGoal,
				reason = "timeout",
			}

			if active.col and active.row then
				SnakeUtils.setOccupied(active.col, active.row, false)
			end

			active.phase = "inactive"
			active.alpha = 0
			active.bobOffset = 0
			active.glowPulse = 1
			active.expireDuration = nil
			active.expireTimer = nil
			active.onExpire = nil
			idleSparkles = {}
			fading = nil
			clearLastCollectedMeta()

			if expireCallback then
				expireCallback(expireInfo)
			end
			return
		end
	end

	if active.phase == "drop" then
		local t = clamp(active.timer / DROP_DURATION, 0, 1)
		active.offsetY = -DROP_HEIGHT * (1 - easeOutQuad(t))
		active.alpha   = easeOutQuad(t)
		active.scaleX  = 0.9 + 0.1 * t
		active.scaleY  = 0.7 + 0.3 * t
		active.shadow  = 0.35 + 0.65 * t

		if t >= 1 then
			local col = active.type.color or {1,1,1,1}
			Particles:spawnBurst(active.x, active.y, {
				count = love.math.random(6, 9),
				speed = 48,
				speedVariance = 36,
				life  = 0.35,
				size  = 3,
				color = {col[1], col[2], col[3], 1},
				spread= pi * 2,
				angleJitter = pi,
				drag = 2.2,
				gravity = 160,
				scaleMin = 0.55,
				scaleVariance = 0.65,
				fadeTo = 0,
			})
			active.phase = "squash"
			active.timer = 0
			active.offsetY = 0
		end
	elseif active.phase == "squash" then
		local t = clamp(active.timer / SQUASH_DURATION, 0, 1)
		active.scaleX = 1 + 0.25 * (1 - t)
		active.scaleY = 1 - 0.25 * (1 - t)
		active.shadow = 1.0
		if t >= 1 then
			active.phase = "wobble"
			active.timer = 0
			active.scaleX = 1.12
			active.scaleY = 0.88
		end
	elseif active.phase == "wobble" then
		local t = clamp(active.timer / WOBBLE_DURATION, 0, 1)
		local s = (1 - t)
		local k = sin(t * pi * 2.0) * 0.06 * s
		active.scaleX = 1 + k
		active.scaleY = 1 - k
		active.shadow = 1.0
		active.alpha  = 1.0
		if t >= 1 then
			active.phase = "idle"
			active.timer = 0
			active.scaleX, active.scaleY = 1, 1
			active.shadow = 1.0
			-- Intentionally keep active.idleTimer unchanged so the bob animation stays continuous
			active.sparkleTimer = love.math.random(IDLE_SPARKLE_MIN_DELAY, IDLE_SPARKLE_MAX_DELAY)
		end
	end

	if active.phase == "idle" or active.phase == "wobble" then
		active.idleTimer = (active.idleTimer or 0) + dt
		local floatPhase = sin((active.idleTimer or 0) * IDLE_FLOAT_SPEED)
		active.bobOffset = floatPhase * IDLE_FLOAT_AMPLITUDE
		active.glowPulse = 0.7 + 0.3 * sin((active.idleTimer or 0) * IDLE_GLOW_SPEED)

		active.sparkleTimer = (active.sparkleTimer or IDLE_SPARKLE_MAX_DELAY) - dt
		if active.sparkleTimer <= 0 then
			spawnIdleSparkle(active.x, active.y, (active.type and active.type.highlightColor) or defaultHighlightColor)
			active.sparkleTimer = love.math.random(IDLE_SPARKLE_MIN_DELAY, IDLE_SPARKLE_MAX_DELAY)
		end
	else
		active.bobOffset = 0
		active.glowPulse = 1
	end
end

function Fruit:checkCollisionWith(x, y, trail, rocks)
	if fading then return false end
	if active.phase == "inactive" then return false end

	local half = HITBOX_SIZE / 2
	if aabb(x - half, y - half, HITBOX_SIZE, HITBOX_SIZE,
	active.x - half, active.y - half, HITBOX_SIZE, HITBOX_SIZE) then
		lastCollectedType = active.type
		lastCollectedMeta = {
			isBonus = active.isBonus or false,
			countsForGoal = active.countsForGoal ~= false,
			eventTag = active.eventTag,
		}
		active.onExpire = nil
                local drawCache = fading and fading.drawCache or fadingDrawCache

                fading = {
                        x = active.x,
                        y = active.y,
                        alpha = 1,
                        scaleX = active.scaleX,
                        scaleY = active.scaleY,
                        shadow = active.shadow,
                        type = active.type,
                        drawCache = drawCache,
                }
                fadingDrawCache = drawCache
		fadeTimer = 0
		active.phase = "inactive"
		active.alpha = 0
		active.bobOffset = 0
		active.glowPulse = 1
		idleSparkles = {}

                local fxColor = (active.type and active.type.highlightColor) or defaultHighlightColor
		Particles:spawnBurst(active.x, active.y, {
			count = love.math.random(10, 14),
			speed = 120,
			speedVariance = 90,
			life = 0.45,
			size = 3.2,
			color = {fxColor[1], fxColor[2], fxColor[3], 0.95},
			spread = pi * 2,
			drag = 2.7,
			gravity = -60,
			fadeTo = 0,
		})
		return true
	end
	return false
end

local function prepareFruitDrawData(f, out)
        if not f or f.phase == "inactive" then
                return nil
        end

        out = out or {}

        local offsetY = (f.offsetY or 0) + (f.bobOffset or 0)
        local x = f.x
        local y = f.y + offsetY
        local alpha = f.alpha or 1
        local sx, sy = f.scaleX or 1, f.scaleY or 1
        local radius = HITBOX_SIZE / 2
        local pulse = f.glowPulse or 1
        local bobOffset = f.bobOffset or 0
        local bobStrength = bobOffset / IDLE_FLOAT_AMPLITUDE
        local liftStrength = max(0, -bobStrength)
        local shadowAlpha = 0.25 * alpha * (f.shadow or 1)
        shadowAlpha = shadowAlpha * (1 + liftStrength * 0.4)
        local shadowScale = 1 + liftStrength * 0.12
        local shadowYOffset = min(0, bobOffset * 0.35)
        local bodyColor = (f.type and f.type.color) or highlightDefault
        local highlight = (f.type and f.type.highlightColor) or defaultHighlightColor
        local isActive = (f == active)

        out.fruit = f
        out.x = x
        out.y = y
        out.alpha = alpha
        out.sx = sx
        out.sy = sy
        out.radius = radius
        out.pulse = pulse
        out.bobOffset = bobOffset
        out.shadowAlpha = shadowAlpha
        out.shadowScale = shadowScale
        out.shadowYOffset = shadowYOffset
        out.bodyColor = bodyColor
        out.highlight = highlight
        out.isActive = isActive
        if isActive then
                out.idleSparkles = idleSparkles
                out.idleSparkleCount = #idleSparkles
                out.activeTimer = f.timer or 0
        else
                out.idleSparkles = nil
                out.idleSparkleCount = 0
                out.activeTimer = nil
        end
        out.isDragonfruitActive = isActive and f.type ~= nil and f.type.name == "Dragonfruit"

        return out
end

local function drawFruitShadow(data)
        if not data then return end

        local x, y = data.x, data.y
        local sx, sy = data.sx, data.sy
        local r = data.radius
        local segments = 32
        local shadowYOffset = data.shadowYOffset or 0

        love.graphics.setColor(0, 0, 0, data.shadowAlpha)
        love.graphics.ellipse(
        "fill",
        x + SHADOW_OFFSET,
        y + SHADOW_OFFSET + shadowYOffset,
        (r * sx + OUTLINE_SIZE * 0.5) * data.shadowScale,
        (r * sy + OUTLINE_SIZE * 0.5) * data.shadowScale,
        segments
        )
end

local function drawFruitMain(data)
        if not data then return end

        local x, y = data.x, data.y
        local alpha = data.alpha
        local sx, sy = data.sx, data.sy
        local r = data.radius
        local pulse = data.pulse
        local bodyColor = data.bodyColor or highlightDefault
        local highlight = data.highlight or defaultHighlightColor

        -- fruit body
        love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], alpha)
        love.graphics.ellipse("fill", x, y, r * sx, r * sy)

        -- highlight
        local hx = x - r * sx * 0.3
        local hy = y - r * sy * 0.35
        local hrx = r * sx * 0.55
        local hry = r * sy * 0.45
        love.graphics.push()
	love.graphics.translate(hx, hy)
	love.graphics.rotate(-0.35)
	local highlightAlpha = (highlight[4] or 1) * alpha * (0.75 + pulse * 0.25)
        love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlightAlpha)
        love.graphics.ellipse("fill", 0, 0, hrx, hry)
        love.graphics.pop()

        if data.isActive and (data.idleSparkleCount or 0) > 0 then
                local sparkles = data.idleSparkles
                if sparkles then
                        local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()
                        local prevColor = { love.graphics.getColor() }
                        local prevLineWidth = love.graphics.getLineWidth()

                        love.graphics.setBlendMode("add")
                        for i = 1, data.idleSparkleCount do
                                local sparkle = sparkles[i]
                                if not sparkle then break end
                                local progress = clamp(sparkle.timer / sparkle.duration, 0, 1)
                                local fade = 1 - progress
                                local orbit = sparkle.radius + progress * 6
                                local px = x + math.cos(sparkle.angle) * orbit
                                local py = y + sin(sparkle.angle) * orbit - progress * 6
                                local glowSize = sparkle.size * (0.6 + 0.4 * sin(progress * pi))
                                local alphaMul = 0.25 * fade * (0.6 + pulse * 0.4)

                                love.graphics.setColor(sparkle.color[1], sparkle.color[2], sparkle.color[3], alphaMul)
                                love.graphics.circle("fill", px, py, glowSize)
                                love.graphics.setColor(1, 1, 1, alphaMul * 1.6)
                                love.graphics.circle("line", px, py, glowSize * 0.9)
                        end
                        love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)
                        love.graphics.setColor(prevColor[1], prevColor[2], prevColor[3], prevColor[4])
                        love.graphics.setLineWidth(prevLineWidth)
                end
        end

        -- outline (2–3px black border)
	love.graphics.setLineWidth(OUTLINE_SIZE)
	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.ellipse("line", x, y, r * sx, r * sy)

        -- subtle spawn glow
        -- Removed to avoid the temporary color tint when fruit spawn in

        -- rare fruit flair
        if data.isDragonfruitActive then
                local t = data.activeTimer or 0
                local rarePulse = 0.5 + 0.5 * sin(t * 6.0)
                love.graphics.setColor(1, 0, 1, 0.15 * rarePulse * alpha)
                love.graphics.circle("line", x, y, HITBOX_SIZE * 0.8 + rarePulse * 4)
        end
end

function Fruit:draw()
        for i = #drawList, 1, -1 do
                drawList[i] = nil
        end

        local drawCount = 0

        if fading and fading.alpha and fading.alpha > 0 then
                local data = prepareFruitDrawData(fading, fading.drawCache or fadingDrawCache)
                if data then
                        drawCount = drawCount + 1
                        drawList[drawCount] = data
                end
        end

        local activeData = prepareFruitDrawData(active, active.drawCache)
        if activeData then
                drawCount = drawCount + 1
                drawList[drawCount] = activeData
        end

        if drawCount == 0 then
                return
        end

        local list = drawList
        RenderLayers:queue("shadows", RenderLayers:acquireCommand(drawFruitShadows, list, drawCount))
        RenderLayers:queue("main", RenderLayers:acquireCommand(drawFruitMainBatch, list, drawCount))
end

-- Queries
function Fruit:getPosition() return active.x, active.y end

function Fruit:getDrawPosition()
	if not active then
		return nil, nil
	end

	local baseX, baseY = active.x, active.y
	if not (baseX and baseY) then
		return baseX, baseY
	end

	local offsetY = (active.offsetY or 0) + (active.bobOffset or 0)
	return baseX, baseY + offsetY
end
function Fruit:getPoints()   return lastCollectedType.points or 1 end
function Fruit:getTypeName() return lastCollectedType.name or "Apple" end
function Fruit:getType()     return lastCollectedType end
function Fruit:getTile()     return active.col, active.row end

function Fruit:getLastCollectedMeta()
	return lastCollectedMeta
end

function Fruit:getActiveMetadata()
	if active and active.phase ~= "inactive" then
		return {
			eventTag = active.eventTag,
			isBonus = active.isBonus,
			countsForGoal = active.countsForGoal,
		}
	end

	return nil
end

function Fruit:getActive()
	if active and active.phase ~= "inactive" and (active.alpha or 0) > 0 then
		return active
	end

	return nil
end

return Fruit
