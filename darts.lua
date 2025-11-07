local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Particles = require("particles")
local Audio = require("audio")
local Timer = require("timer")

local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local sin = math.sin
local pi = math.pi
local random = love.math.random

local Darts = {}

local emitters = {}
local stallTimer = 0

local DARTS_ENABLED = true

local DEFAULT_INITIAL_COOLDOWN_BONUS = 1.5 -- Extra grace period after spawning before the first telegraph.

local DEFAULT_TELEGRAPH_DURATION = 1.0
local DEFAULT_COOLDOWN_MIN = 3.8
local DEFAULT_COOLDOWN_MAX = 6.2
local DEFAULT_DART_SPEED = 360
local DEFAULT_DART_LENGTH = 26
local DEFAULT_DART_THICKNESS = 12
local BASE_EMITTER_SIZE = 18
local FLASH_DECAY = 3.5
local IMPACT_FLASH_DURATION = 0.32
local ROCK_EDGE_INSET = 2

local BASE_EMITTER_COLOR = {0.32, 0.34, 0.38, 0.95}
local BASE_ACCENT_COLOR = {0.46, 0.56, 0.62, 1.0}
local TELEGRAPH_COLOR = {0.64, 0.74, 0.82, 0.85}
local DART_BODY_COLOR = {0.70, 0.68, 0.60, 1.0}
local DART_TIP_COLOR = {0.82, 0.86, 0.90, 1.0}
local DART_TAIL_COLOR = {0.42, 0.68, 0.64, 1.0}

local function clamp01(value)
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

local function releaseOccupancy(emitter)
	if not emitter then
		return
	end

	if emitter.col and emitter.row then
		SnakeUtils.setOccupied(emitter.col, emitter.row, false)
	end
end

local function scaleColor(color, factor, alphaFactor)
	if not color then
		return {1, 1, 1, 1}
	end

	local r = clamp01((color[1] or 0) * factor)
	local g = clamp01((color[2] or 0) * factor)
	local b = clamp01((color[3] or 0) * factor)
	local a = clamp01((color[4] or 1) * (alphaFactor or 1))
	return {r, g, b, a}
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local rimLightScratch = {0, 0, 0, 0}
local occlusionScratch = {0, 0, 0, 0}
local tipGlowScratch = {0, 0, 0, 0}
local highlightFallback = {1, 1, 1, 1}

local function getRimLightColor(color)
	color = color or highlightFallback
	rimLightScratch[1] = min(1, (color[1] or 0) * 1.2 + 0.08)
	rimLightScratch[2] = min(1, (color[2] or 0) * 1.2 + 0.08)
	rimLightScratch[3] = min(1, (color[3] or 0) * 1.2 + 0.08)
	rimLightScratch[4] = (color[4] or 1) * 0.65
	return rimLightScratch
end

local function getOcclusionColor(color)
	color = color or highlightFallback
	occlusionScratch[1] = clamp01((color[1] or 0) * 0.45 + 0.02)
	occlusionScratch[2] = clamp01((color[2] or 0) * 0.45 + 0.02)
	occlusionScratch[3] = clamp01((color[3] or 0) * 0.45 + 0.02)
	occlusionScratch[4] = (color[4] or 1) * 0.7
	return occlusionScratch
end

local function getTipGlowColor(color)
	color = color or highlightFallback
	tipGlowScratch[1] = min(1, (color[1] or 0) * 1.1 + 0.12)
	tipGlowScratch[2] = min(1, (color[2] or 0) * 1.1 + 0.12)
	tipGlowScratch[3] = min(1, (color[3] or 0) * 1.1 + 0.12)
	tipGlowScratch[4] = (color[4] or 1) * 0.6
	return tipGlowScratch
end

local function getEmitterColors()
	local body = Theme.dartBaseColor or BASE_EMITTER_COLOR
	local accent = Theme.dartAccentColor or BASE_ACCENT_COLOR
	local telegraph = Theme.dartTelegraphColor or TELEGRAPH_COLOR
	local dartBody = Theme.dartBodyColor or DART_BODY_COLOR
	local dartTip = Theme.dartTipColor or DART_TIP_COLOR
	local dartTail = Theme.dartTailColor or DART_TAIL_COLOR
	return body, accent, telegraph, dartBody, dartTip, dartTail
end

local function computeShotTargets(emitter)
	if not emitter then
		return
	end

	local tileSize = Arena.tileSize or 24
	local facing = emitter.facing or 1
	local inset = max(4, tileSize * 0.48)
	local startX = emitter.x or 0
	local startY = emitter.y or 0
	local endX, endY
	local impactType = "wall"
	local impactTarget = nil

	if emitter.dir == "horizontal" then
		startX = startX + facing * inset
		endY = startY
		if facing > 0 then
			endX = (Arena.x or 0) + (Arena.width or 0) - inset
		else
			endX = (Arena.x or 0) + inset
		end
		if Rocks and Rocks.getAll then
			local rocks = Rocks:getAll()
			if rocks then
				local bestDistance = math.huge
				for _, rock in ipairs(rocks) do
					if rock and rock.row == emitter.row then
						local delta = (rock.x - (emitter.x or 0)) * facing
						if delta and delta > 0 and delta < bestDistance then
							bestDistance = delta
							impactTarget = rock
						end
					end
				end

				if impactTarget then
					local edge = tileSize * 0.5 - ROCK_EDGE_INSET
					if edge < 0 then
						edge = 0
					end
					endX = impactTarget.x - facing * edge
					impactType = "rock"
				end
			end
		end
	else
		startY = startY + facing * inset
		endX = startX
		if facing > 0 then
			endY = (Arena.y or 0) + (Arena.height or 0) - inset
		else
			endY = (Arena.y or 0) + inset
		end
		if Rocks and Rocks.getAll then
			local rocks = Rocks:getAll()
			if rocks then
				local bestDistance = math.huge
				for _, rock in ipairs(rocks) do
					if rock and rock.col == emitter.col then
						local delta = (rock.y - (emitter.y or 0)) * facing
						if delta and delta > 0 and delta < bestDistance then
							bestDistance = delta
							impactTarget = rock
						end
					end
				end

				if impactTarget then
					local edge = tileSize * 0.5 - ROCK_EDGE_INSET
					if edge < 0 then
						edge = 0
					end
					endY = impactTarget.y - facing * edge
					impactType = "rock"
				end
			end
		end
	end

	emitter.startX = startX
	emitter.startY = startY
	emitter.endX = endX or startX
	emitter.endY = endY or startY
	emitter.targetRock = impactTarget
	emitter.impactType = impactType
	emitter.impactX = emitter.endX
	emitter.impactY = emitter.endY

	local dx = emitter.endX - emitter.startX
	local dy = emitter.endY - emitter.startY
	emitter.travelDistance = sqrt(dx * dx + dy * dy)
	if emitter.travelDistance <= 1e-3 then
		emitter.travelDistance = tileSize
	end

	local desired = emitter.baseFireDuration or nil
	if desired and desired > 0 then
		emitter.fireDuration = desired
		emitter.dartSpeed = emitter.travelDistance / desired
	else
		local speed = emitter.dartSpeed or DEFAULT_DART_SPEED
		if speed <= 0 then
			speed = DEFAULT_DART_SPEED
		end
		emitter.fireDuration = emitter.travelDistance / speed
	end

	emitter.fireDuration = max(0.28, emitter.fireDuration or 0.28)
	emitter.dartSpeed = emitter.travelDistance / emitter.fireDuration
end

local function recordImpact(emitter, x, y, impactType)
	if not emitter then
		return
	end

	emitter.lastImpactX = x
	emitter.lastImpactY = y
	emitter.lastImpactType = impactType
end

local function getImpactColor(impactType)
	if impactType == "rock" then
		local rockColor = Theme.rock or {0.45, 0.40, 0.36, 1}
		local color = scaleColor(rockColor, 1.25, 1)
		color[4] = 1
		return color
	end

	local _, _, _, _, tipColor = getEmitterColors()
	local factor = (impactType == "snake") and 1.12 or 0.96
	local color = scaleColor(tipColor, factor, 1)
	color[4] = 1
	return color
end

local function triggerImpactBurst(emitter, impactType, x, y)
	if not (Particles and Particles.spawnBurst) then
		return
	end

	if not (x and y) then
		return
	end

	local color = getImpactColor(impactType)

	if impactType == "rock" and Rocks and Rocks.triggerHitFlash and emitter and emitter.targetRock then
		Rocks:triggerHitFlash(emitter.targetRock)
	end

	Particles:spawnBurst(x, y, {
		count = random(7, 11),
		speed = 118,
		speedVariance = 58,
		life = 0.3,
		size = 2.6,
		color = color,
		spread = pi * 2,
		angleJitter = pi * 0.9,
		drag = 3.8,
		gravity = (impactType == "rock") and 200 or 150,
		scaleMin = 0.5,
		scaleVariance = 0.42,
		fadeTo = (impactType == "rock") and 0.03 or 0.07,
	})
end

local function randomCooldownDuration(emitter)
	local minCooldown = emitter.fireCooldownMin or DEFAULT_COOLDOWN_MIN
	local maxCooldown = emitter.fireCooldownMax or DEFAULT_COOLDOWN_MAX
	if maxCooldown < minCooldown then
		maxCooldown = minCooldown
	end

	return minCooldown + (maxCooldown - minCooldown) * random()
end

local function resolveInitialCooldownBonus(options)
	if not options then
		return DEFAULT_INITIAL_COOLDOWN_BONUS
	end

	local override = options.initialCooldownBonus
	if override ~= nil then
		if type(override) == "number" then
			return max(0, override)
		elseif type(override) == "string" then
			local numeric = tonumber(override)
			if numeric then
				return max(0, numeric)
			end
		end

		return 0
	end

	return DEFAULT_INITIAL_COOLDOWN_BONUS
end

local function enterCooldown(emitter, initial)
	emitter.state = "cooldown"
	emitter.cooldownTimer = randomCooldownDuration(emitter)
	emitter.telegraphTimer = nil
	emitter.fireTimer = nil
	emitter.dartProgress = 0
	emitter.telegraphStrength = initial and 0 or emitter.telegraphStrength or 0
	emitter.shotRect = nil
	emitter.dartX = nil
	emitter.dartY = nil
end

local function enterTelegraph(emitter)
	computeShotTargets(emitter)
	emitter.state = "telegraph"
	emitter.telegraphTimer = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
	emitter.telegraphStrength = 0
end

local function enterFiring(emitter)
	emitter.state = "firing"
	emitter.fireTimer = emitter.fireDuration or 0.4
	emitter.dartProgress = 0
	emitter.dartX = emitter.startX
	emitter.dartY = emitter.startY
	emitter.shotRect = nil
	emitter.impactTimer = IMPACT_FLASH_DURATION
	if Audio and Audio.playSound then
		Audio:playSound("laser_charge")
	end
end

local function updateShotRect(emitter)
	local thickness = emitter.dartThickness or DEFAULT_DART_THICKNESS
	local length = emitter.dartLength or DEFAULT_DART_LENGTH
	if emitter.dir == "vertical" then
		emitter.shotRect = {
			(emitter.dartX or emitter.startX or 0) - thickness * 0.5,
			(emitter.dartY or emitter.startY or 0) - length * 0.5,
			thickness,
			length,
		}
	else
		emitter.shotRect = {
			(emitter.dartX or emitter.startX or 0) - length * 0.5,
			(emitter.dartY or emitter.startY or 0) - thickness * 0.5,
			length,
			thickness,
		}
	end
end

local function updateEmitter(emitter, dt)
	if emitter.state == "cooldown" then
		emitter.cooldownTimer = max(0, (emitter.cooldownTimer or 0) - dt)
		if stallTimer and stallTimer > 0 then
			return
		end
		if emitter.cooldownTimer <= 0 then
			enterTelegraph(emitter)
		end
		return
	end

	if emitter.state == "telegraph" then
		if emitter.telegraphTimer == nil then
			emitter.telegraphTimer = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
		end

		emitter.telegraphTimer = emitter.telegraphTimer - dt
		local duration = emitter.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
		local progress = clamp01(1 - (emitter.telegraphTimer or 0) / max(duration, 0.01))
		emitter.telegraphStrength = progress * progress

		if emitter.telegraphTimer <= 0 then
			enterFiring(emitter)
		end
		return
	end

	if emitter.state == "firing" then
		emitter.fireTimer = (emitter.fireTimer or emitter.fireDuration) - dt
		local duration = emitter.fireDuration or 0.01
		local progress = clamp01(1 - (emitter.fireTimer or 0) / max(duration, 0.01))
		emitter.dartProgress = progress

		emitter.dartX = emitter.startX + (emitter.endX - emitter.startX) * progress
		emitter.dartY = emitter.startY + (emitter.endY - emitter.startY) * progress

		updateShotRect(emitter)

		if emitter.fireTimer <= 0 then
			local impactX = emitter.dartX or emitter.endX
			local impactY = emitter.dartY or emitter.endY
			local impactType = emitter.impactType or "wall"
			triggerImpactBurst(emitter, impactType, impactX, impactY)
			recordImpact(emitter, impactX, impactY, impactType)
			emitter.flashTimer = max(emitter.flashTimer or 0, 1)
			emitter.impactTimer = IMPACT_FLASH_DURATION
			enterCooldown(emitter, false)
			emitter.lastImpactX = impactX
			emitter.lastImpactY = impactY
		end
	end

	if emitter.flashTimer and emitter.flashTimer > 0 then
		emitter.flashTimer = max(0, emitter.flashTimer - dt * FLASH_DECAY)
	end

	if emitter.impactTimer and emitter.impactTimer > 0 then
		emitter.impactTimer = emitter.impactTimer - dt
	end
end

function Darts:load()
end

function Darts:reset()
	for _, emitter in ipairs(emitters) do
		releaseOccupancy(emitter)
	end

	for i = #emitters, 1, -1 do
		emitters[i] = nil
	end

	stallTimer = 0
end

function Darts:spawn(x, y, dir, options)
	if not DARTS_ENABLED then
		return nil
	end

	if not (x and y and dir) then
		return nil
	end

	local initialCooldownBonus = resolveInitialCooldownBonus(options)

	local emitter = {
		x = x,
		y = y,
		dir = dir,
		facing = options and options.facing or 1,
		telegraphDuration = max(0.2, options and options.telegraphDuration or DEFAULT_TELEGRAPH_DURATION),
		dartSpeed = options and options.dartSpeed or DEFAULT_DART_SPEED,
		dartLength = options and options.dartLength or DEFAULT_DART_LENGTH,
		dartThickness = options and options.dartThickness or DEFAULT_DART_THICKNESS,
		baseFireDuration = options and options.fireDuration or nil,
		fireCooldownMin = options and options.fireCooldownMin or DEFAULT_COOLDOWN_MIN,
		fireCooldownMax = options and options.fireCooldownMax or DEFAULT_COOLDOWN_MAX,
		flashTimer = 0,
		telegraphStrength = 0,
		randomOffset = love.math.random() * 1000,
	}

	emitter.col, emitter.row = Arena:getTileFromWorld(x, y)
	SnakeUtils.setOccupied(emitter.col, emitter.row, true)

	computeShotTargets(emitter)
	enterCooldown(emitter, true)

	if initialCooldownBonus and initialCooldownBonus > 0 then
		emitter.cooldownTimer = (emitter.cooldownTimer or 0) + initialCooldownBonus
	end

	emitters[#emitters + 1] = emitter
	return emitter
end

function Darts:getEmitters()
	local copies = {}
	for index, emitter in ipairs(emitters) do
		copies[index] = emitter
	end
	return copies
end

function Darts:getEmitterArray()
	return emitters
end

function Darts:getEmitterCount()
	return #emitters
end

function Darts:iterateEmitters(callback, context)
	if type(callback) == "table" then
		local spec = callback
		callback = spec.callback
		context = spec.context
	end

	if type(callback) ~= "function" then
		return
	end

	if context ~= nil then
		for index = 1, #emitters do
			local result = callback(context, emitters[index], index)
			if result ~= nil then
				return result
			end
		end
	else
		for index = 1, #emitters do
			local result = callback(emitters[index], index)
			if result ~= nil then
				return result
			end
		end
	end
end

function Darts:iterateShots(callback, context)
	if type(callback) == "table" then
		local spec = callback
		callback = spec.callback
		context = spec.context
	end

	if type(callback) ~= "function" then
		return
	end

	if context ~= nil then
		for index = 1, #emitters do
			local emitter = emitters[index]
			if emitter and emitter.state == "firing" and emitter.shotRect then
				local result = callback(context, emitter, emitter.shotRect, index)
				if result ~= nil then
					return result
				end
			end
		end
	else
		for index = 1, #emitters do
			local emitter = emitters[index]
			if emitter and emitter.state == "firing" and emitter.shotRect then
				local result = callback(emitter, emitter.shotRect, index)
				if result ~= nil then
					return result
				end
			end
		end
	end
end

function Darts:stall(duration)
	if not duration or duration <= 0 then
		return
	end

	stallTimer = (stallTimer or 0) + duration
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function baseBounds(emitter)
	if not emitter then
		return
	end

	local size = Arena.tileSize or BASE_EMITTER_SIZE
	local half = size * 0.5
	local inset = max(2, size * 0.25)
	if inset > half then
		inset = half
	end

	local width = size - inset * 2
	local height = width
	return (emitter.x or 0) - width * 0.5, (emitter.y or 0) - height * 0.5, width, height
end

function Darts:checkCollision(x, y, w, h)
	if not DARTS_ENABLED then
		return nil
	end

	if not (x and y and w and h) then
		return nil
	end

	local snakeW = max(0, w)
	local snakeH = max(0, h)
	if snakeW <= 0 or snakeH <= 0 then
		return nil
	end

	local halfW = snakeW * 0.5
	local halfH = snakeH * 0.5
	local snakeX = x - halfW
	local snakeY = y - halfH

	for _, emitter in ipairs(emitters) do
		local bx, by, bw, bh = baseBounds(emitter)
		if bx and rectsOverlap(bx, by, bw, bh, snakeX, snakeY, snakeW, snakeH) then
			emitter.flashTimer = max(emitter.flashTimer or 0, 1)
			return emitter
		end

		if emitter.state == "firing" and emitter.shotRect then
			local rx, ry, rw, rh = emitter.shotRect[1], emitter.shotRect[2], emitter.shotRect[3], emitter.shotRect[4]
			if rw and rh and rw > 0 and rh > 0 and rectsOverlap(rx, ry, rw, rh, snakeX, snakeY, snakeW, snakeH) then
				emitter.flashTimer = max(emitter.flashTimer or 0, 1)
				return emitter
			end
		end
	end

	return nil
end

function Darts:onShieldedHit(emitter, hitX, hitY)
	if not emitter then
		return
	end

	local impactX = hitX or emitter.dartX or emitter.lastImpactX or emitter.endX or emitter.x or 0
	local impactY = hitY or emitter.dartY or emitter.lastImpactY or emitter.endY or emitter.y or 0

	emitter.flashTimer = max(emitter.flashTimer or 0, 1)
	recordImpact(emitter, impactX, impactY, "snake")
	emitter.impactTimer = IMPACT_FLASH_DURATION
end

function Darts:onSnakeImpact(emitter, hitX, hitY)
	if not emitter then
		return
	end

	local impactX = hitX or emitter.dartX or emitter.lastImpactX or emitter.endX or emitter.x or 0
	local impactY = hitY or emitter.dartY or emitter.lastImpactY or emitter.endY or emitter.y or 0

	emitter.flashTimer = max(emitter.flashTimer or 0, 1)
	triggerImpactBurst(emitter, "snake", impactX, impactY)
	recordImpact(emitter, impactX, impactY, "snake")
	emitter.impactTimer = IMPACT_FLASH_DURATION
end

function Darts:update(dt)
	if not DARTS_ENABLED then
		return
	end

	dt = dt or 0

	local stall = stallTimer or 0
	if stall > 0 then
		if dt <= stall then
			stallTimer = max(0, stall - dt)
			return
		end

		dt = dt - stall
		stallTimer = 0
	end

	for index = 1, #emitters do
		updateEmitter(emitters[index], dt)
	end
end

local function drawEmitter(emitter)
	local bodyColor, accentColor, telegraphColor = getEmitterColors()
	local tileSize = Arena.tileSize or BASE_EMITTER_SIZE
	local half = tileSize * 0.5
	local centerX = emitter.x or 0
	local centerY = emitter.y or 0
	local baseX = centerX - half
	local baseY = centerY - half

	love.graphics.push("all")

	local flash = clamp01(emitter.flashTimer or 0)
	local strength = clamp01(emitter.telegraphStrength or 0)
	local shadowColor = Theme.shadowColor or {0, 0, 0, 0.45}

	local shadowAlpha = clamp01((shadowColor[4] or 0.45) * (0.55 + strength * 0.25 + flash * 0.2))
	if shadowAlpha > 0 then
		love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
		love.graphics.rectangle("fill", baseX + 2, baseY + 3, tileSize, tileSize, 6, 6)
	end

	local housingAlpha = clamp01((bodyColor[4] or 1) + flash * 0.1)
	love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], housingAlpha)
	love.graphics.rectangle("fill", baseX, baseY, tileSize, tileSize, 6, 6)

	local insetColor = scaleColor(bodyColor, 0.78 + strength * 0.12, 1)
	love.graphics.setColor(insetColor)
	love.graphics.rectangle("fill", baseX + 2, baseY + 2, tileSize - 4, tileSize - 4, 5, 5)

	local borderAlpha = clamp01(0.45 + flash * 0.25 + strength * 0.2)
	love.graphics.setColor(0, 0, 0, borderAlpha)
	love.graphics.rectangle("line", baseX, baseY, tileSize, tileSize, 6, 6)

	local accentAlpha = clamp01((accentColor[4] or 0.8) + flash * 0.25 + strength * 0.3)
	love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentAlpha)
	love.graphics.rectangle("line", baseX + 2, baseY + 2, tileSize - 4, tileSize - 4, 4, 4)

	local muzzleOffset = tileSize * 0.34
	local muzzleRadius = tileSize * 0.18
	local muzzleX = centerX
	local muzzleY = centerY
	local facing = emitter.facing or 1
	if emitter.dir == "horizontal" then
		muzzleX = centerX + facing * muzzleOffset
	else
		muzzleY = centerY + facing * muzzleOffset
	end

	local muzzleFillAlpha = clamp01(0.75 + strength * 0.15 + flash * 0.1)
	love.graphics.setColor(0, 0, 0, muzzleFillAlpha)
	love.graphics.circle("fill", muzzleX, muzzleY, muzzleRadius, 16)

	love.graphics.setColor(0, 0, 0, 0.55 + flash * 0.25)
	love.graphics.circle("line", muzzleX, muzzleY, muzzleRadius, 16)

	if flash > 0 then
		love.graphics.setColor(1, 1, 1, 0.3 * flash)
		love.graphics.rectangle("line", baseX - 4, baseY - 4, tileSize + 8, tileSize + 8, 8, 8)
	end

	love.graphics.pop()
end

local function drawTelegraphPath(emitter)
	if not (emitter and emitter.state == "telegraph") then
		return
	end

	local _, _, telegraphColor, bodyColor, tipColor = getEmitterColors()
	local strength = clamp01(emitter.telegraphStrength or 0)
	if strength <= 0 then
		return
	end

	love.graphics.push("all")

	local tileSize = Arena.tileSize or BASE_EMITTER_SIZE
	local centerX = emitter.x or 0
	local centerY = emitter.y or 0
	local facing = emitter.facing or 1
	local muzzleOffset = tileSize * 0.34
	local muzzleX = centerX
	local muzzleY = centerY
	if emitter.dir == "horizontal" then
		muzzleX = centerX + facing * muzzleOffset
	else
		muzzleY = centerY + facing * muzzleOffset
	end

	local peekDistance = tileSize * (0.16 + strength * 0.28)
	local shaftThickness = tileSize * 0.18
	local tipLength = tileSize * 0.22
	local shaftLength = max(0, peekDistance - tipLength * 0.35)

	if emitter.dir == "horizontal" then
		local baseX = muzzleX - facing * (tileSize * 0.02)
		local tipX = baseX + facing * peekDistance
		local shaftStart = baseX - facing * shaftLength
		local shaftY = muzzleY - shaftThickness * 0.34
		local shaftHeight = shaftThickness * 0.68

		if shaftLength > 0 then
			love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], clamp01((bodyColor[4] or 1) * (0.6 + 0.4 * strength)))
			love.graphics.rectangle("fill", min(shaftStart, baseX), shaftY, abs(baseX - shaftStart), shaftHeight, 3, 3)
		end

		local tipBaseY = muzzleY
		local tipHalfHeight = shaftThickness * 0.55
		love.graphics.setColor(tipColor[1], tipColor[2], tipColor[3], clamp01((tipColor[4] or 1) * (0.65 + 0.35 * strength)))
		love.graphics.polygon("fill",
		tipX, tipBaseY,
		baseX, tipBaseY - tipHalfHeight,
		baseX, tipBaseY + tipHalfHeight)
	else
		local baseY = muzzleY - facing * (tileSize * 0.02)
		local tipY = baseY + facing * peekDistance
		local shaftStart = baseY - facing * shaftLength
		local shaftX = muzzleX - shaftThickness * 0.34
		local shaftWidth = shaftThickness * 0.68

		if shaftLength > 0 then
			love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], clamp01((bodyColor[4] or 1) * (0.6 + 0.4 * strength)))
			love.graphics.rectangle("fill", shaftX, min(shaftStart, baseY), shaftWidth, abs(baseY - shaftStart), 3, 3)
		end

		local tipBaseX = muzzleX
		local tipHalfWidth = shaftThickness * 0.55
		love.graphics.setColor(tipColor[1], tipColor[2], tipColor[3], clamp01((tipColor[4] or 1) * (0.65 + 0.35 * strength)))
		love.graphics.polygon("fill",
		tipBaseX, tipY,
		tipBaseX - tipHalfWidth, baseY,
		tipBaseX + tipHalfWidth, baseY)
	end

	love.graphics.pop()
end

local function drawDart(emitter)
	if not (emitter and emitter.state == "firing" and emitter.shotRect) then
		return
	end

	local _, _, _, bodyColor, tipColor, tailColor = getEmitterColors()
	local rx, ry, rw, rh = emitter.shotRect[1], emitter.shotRect[2], emitter.shotRect[3], emitter.shotRect[4]
	if not (rx and ry and rw and rh) then
		return
	end

	love.graphics.push("all")

	if emitter.dir == "horizontal" then
		local shaftHeight = rh * 0.34
		local shaftY = ry + (rh - shaftHeight) * 0.5
		local facing = emitter.facing or 1
		local tipX = (emitter.dartX or emitter.startX or 0) + facing * (rw * 0.5)
		local tailX = (emitter.dartX or emitter.startX or 0) - facing * (rw * 0.5)
		local tipLength = 8
		local tailInset = 6
		local shaftStart = tailX + facing * tailInset
		local shaftEnd = tipX - facing * tipLength
		local shaftX = min(shaftStart, shaftEnd)
		local shaftWidth = abs(shaftEnd - shaftStart)

		local baseY = ry + rh * 0.5
		local fletchInner = tailX - facing * (tailInset * 0.35)
		local fletchOuter = tailX - facing * (tailInset * 1.4 + 4)

		local shadowColor = Theme.shadowColor or {0, 0, 0, 0.45}
		local shadowAlpha = (shadowColor[4] or 1) * 0.55
		if shadowAlpha > 0 then
			love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
			local shadowOffsetX = 3
			local shadowOffsetY = 3
			love.graphics.rectangle("fill", shaftX + shadowOffsetX, shaftY + shadowOffsetY, shaftWidth, shaftHeight, 3, 3)
			love.graphics.polygon("fill",
			tipX + shadowOffsetX, baseY + shadowOffsetY,
			shaftEnd + shadowOffsetX, baseY - shaftHeight * 1.05 + shadowOffsetY,
			shaftEnd + shadowOffsetX, baseY + shaftHeight * 1.05 + shadowOffsetY)
			love.graphics.polygon("fill",
			fletchOuter + shadowOffsetX, baseY + shadowOffsetY,
			fletchInner + shadowOffsetX, baseY - rh * 0.55 + shadowOffsetY,
			tailX + facing * 2 + shadowOffsetX, baseY - rh * 0.22 + shadowOffsetY)
			love.graphics.polygon("fill",
			fletchOuter + shadowOffsetX, baseY + shadowOffsetY,
			fletchInner + shadowOffsetX, baseY + rh * 0.55 + shadowOffsetY,
			tailX + facing * 2 + shadowOffsetX, baseY + rh * 0.22 + shadowOffsetY)
		end

		love.graphics.setColor(bodyColor)
		love.graphics.rectangle("fill", shaftX, shaftY, shaftWidth, shaftHeight, 3, 3)

		local highlight = getRimLightColor(bodyColor)
		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
		love.graphics.rectangle("fill", shaftX, shaftY + shaftHeight * 0.08, shaftWidth, shaftHeight * 0.26, 3, 3)

		local occlusion = getOcclusionColor(bodyColor)
		love.graphics.setColor(occlusion[1], occlusion[2], occlusion[3], occlusion[4])
		love.graphics.rectangle("fill", shaftX, shaftY + shaftHeight * 0.62, shaftWidth, shaftHeight * 0.3, 3, 3)

		love.graphics.setColor(tailColor)
		love.graphics.polygon("fill",
		fletchOuter, baseY,
		fletchInner, baseY - rh * 0.55,
		tailX + facing * 2, baseY - rh * 0.22)
		love.graphics.polygon("fill",
		fletchOuter, baseY,
		fletchInner, baseY + rh * 0.55,
		tailX + facing * 2, baseY + rh * 0.22)

		local fletchOcclusion = getOcclusionColor(tailColor)
		love.graphics.setColor(fletchOcclusion[1], fletchOcclusion[2], fletchOcclusion[3], fletchOcclusion[4])
		love.graphics.polygon("fill",
		lerp(fletchOuter, tailX + facing * 2, 0.45), lerp(baseY, baseY - rh * 0.22, 0.45),
		lerp(fletchInner, tailX + facing * 2, 0.35), lerp(baseY - rh * 0.55, baseY - rh * 0.22, 0.35),
		lerp(fletchOuter, fletchInner, 0.35), lerp(baseY, baseY - rh * 0.55, 0.35))
		love.graphics.polygon("fill",
		lerp(fletchOuter, tailX + facing * 2, 0.45), lerp(baseY, baseY + rh * 0.22, 0.45),
		lerp(fletchInner, tailX + facing * 2, 0.35), lerp(baseY + rh * 0.55, baseY + rh * 0.22, 0.35),
		lerp(fletchOuter, fletchInner, 0.35), lerp(baseY, baseY + rh * 0.55, 0.35))

		local fletchHighlight = getRimLightColor(tailColor)
		love.graphics.setColor(fletchHighlight[1], fletchHighlight[2], fletchHighlight[3], fletchHighlight[4])
		love.graphics.polygon("fill",
		fletchOuter, baseY,
		lerp(fletchOuter, fletchInner, 0.22), lerp(baseY, baseY - rh * 0.55, 0.22),
		lerp(fletchOuter, tailX + facing * 2, 0.22), lerp(baseY, baseY - rh * 0.22, 0.22))
		love.graphics.setColor(fletchHighlight[1], fletchHighlight[2], fletchHighlight[3], (fletchHighlight[4] or 1) * 0.65)
		love.graphics.polygon("fill",
		fletchOuter, baseY,
		lerp(fletchOuter, fletchInner, 0.18), lerp(baseY, baseY + rh * 0.55, 0.18),
		lerp(fletchOuter, tailX + facing * 2, 0.18), lerp(baseY, baseY + rh * 0.22, 0.18))

		love.graphics.setColor(tipColor)
		love.graphics.polygon("fill",
		tipX, baseY,
		shaftEnd, baseY - shaftHeight * 1.05,
		shaftEnd, baseY + shaftHeight * 1.05)

		local tipHighlight = getRimLightColor(tipColor)
		love.graphics.setColor(tipHighlight[1], tipHighlight[2], tipHighlight[3], tipHighlight[4])
		love.graphics.polygon("fill",
		tipX, baseY,
		lerp(tipX, shaftEnd, 0.24), lerp(baseY, baseY - shaftHeight * 1.05, 0.42),
		shaftEnd, lerp(baseY - shaftHeight * 1.05, baseY, 0.18))

		local tipOcclusion = getOcclusionColor(tipColor)
		love.graphics.setColor(tipOcclusion[1], tipOcclusion[2], tipOcclusion[3], tipOcclusion[4])
		love.graphics.polygon("fill",
		tipX, baseY,
		lerp(tipX, shaftEnd, 0.24), lerp(baseY, baseY + shaftHeight * 1.05, 0.42),
		shaftEnd, lerp(baseY + shaftHeight * 1.05, baseY, 0.18))

	else
		local shaftWidth = rw * 0.34
		local shaftX = rx + (rw - shaftWidth) * 0.5
		local facing = emitter.facing or 1
		local tipY = (emitter.dartY or emitter.startY or 0) + facing * (rh * 0.5)
		local tailY = (emitter.dartY or emitter.startY or 0) - facing * (rh * 0.5)
		local tipLength = 8
		local tailInset = 6
		local shaftStart = tailY + facing * tailInset
		local shaftEnd = tipY - facing * tipLength
		local shaftY = min(shaftStart, shaftEnd)
		local shaftHeight = abs(shaftEnd - shaftStart)

		local baseX = rx + rw * 0.5
		local fletchInner = tailY - facing * (tailInset * 0.35)
		local fletchOuter = tailY - facing * (tailInset * 1.4 + 4)

		local shadowColor = Theme.shadowColor or {0, 0, 0, 0.45}
		local shadowAlpha = (shadowColor[4] or 1) * 0.55
		if shadowAlpha > 0 then
			love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
			local shadowOffsetX = 3
			local shadowOffsetY = 3
			love.graphics.rectangle("fill", shaftX + shadowOffsetX, shaftY + shadowOffsetY, shaftWidth, shaftHeight, 3, 3)
			love.graphics.polygon("fill",
			baseX + shadowOffsetX, tipY + shadowOffsetY,
			baseX - shaftWidth * 1.05 + shadowOffsetX, shaftEnd + shadowOffsetY,
			baseX + shaftWidth * 1.05 + shadowOffsetX, shaftEnd + shadowOffsetY)
			love.graphics.polygon("fill",
			baseX + shadowOffsetX, fletchOuter + shadowOffsetY,
			baseX - rw * 0.55 + shadowOffsetX, fletchInner + shadowOffsetY,
			baseX - rw * 0.22 + shadowOffsetX, tailY + facing * 2 + shadowOffsetY)
			love.graphics.polygon("fill",
			baseX + shadowOffsetX, fletchOuter + shadowOffsetY,
			baseX + rw * 0.55 + shadowOffsetX, fletchInner + shadowOffsetY,
			baseX + rw * 0.22 + shadowOffsetX, tailY + facing * 2 + shadowOffsetY)
		end

		love.graphics.setColor(bodyColor)
		love.graphics.rectangle("fill", shaftX, shaftY, shaftWidth, shaftHeight, 3, 3)

		local highlight = getRimLightColor(bodyColor)
		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
		love.graphics.rectangle("fill", shaftX + shaftWidth * 0.08, shaftY, shaftWidth * 0.26, shaftHeight, 3, 3)

		local occlusion = getOcclusionColor(bodyColor)
		love.graphics.setColor(occlusion[1], occlusion[2], occlusion[3], occlusion[4])
		love.graphics.rectangle("fill", shaftX + shaftWidth * 0.62, shaftY, shaftWidth * 0.3, shaftHeight, 3, 3)

		love.graphics.setColor(tailColor)
		love.graphics.polygon("fill",
		baseX, fletchOuter,
		baseX - rw * 0.55, fletchInner,
		baseX - rw * 0.22, tailY + facing * 2)
		love.graphics.polygon("fill",
		baseX, fletchOuter,
		baseX + rw * 0.55, fletchInner,
		baseX + rw * 0.22, tailY + facing * 2)

		local fletchOcclusion = getOcclusionColor(tailColor)
		love.graphics.setColor(fletchOcclusion[1], fletchOcclusion[2], fletchOcclusion[3], fletchOcclusion[4])
		love.graphics.polygon("fill",
		lerp(baseX, baseX - rw * 0.55, 0.45), lerp(fletchOuter, fletchInner, 0.45),
		lerp(baseX, baseX - rw * 0.22, 0.35), lerp(fletchOuter, tailY + facing * 2, 0.35),
		lerp(baseX - rw * 0.55, baseX - rw * 0.22, 0.5), lerp(fletchInner, tailY + facing * 2, 0.5))
		love.graphics.polygon("fill",
		lerp(baseX, baseX + rw * 0.55, 0.45), lerp(fletchOuter, fletchInner, 0.45),
		lerp(baseX, baseX + rw * 0.22, 0.35), lerp(fletchOuter, tailY + facing * 2, 0.35),
		lerp(baseX + rw * 0.55, baseX + rw * 0.22, 0.5), lerp(fletchInner, tailY + facing * 2, 0.5))

		local fletchHighlight = getRimLightColor(tailColor)
		love.graphics.setColor(fletchHighlight[1], fletchHighlight[2], fletchHighlight[3], fletchHighlight[4])
		love.graphics.polygon("fill",
		baseX, fletchOuter,
		lerp(baseX, baseX - rw * 0.55, 0.22), lerp(fletchOuter, fletchInner, 0.22),
		lerp(baseX, baseX - rw * 0.22, 0.22), lerp(fletchOuter, tailY + facing * 2, 0.22))
		love.graphics.setColor(fletchHighlight[1], fletchHighlight[2], fletchHighlight[3], (fletchHighlight[4] or 1) * 0.65)
		love.graphics.polygon("fill",
		baseX, fletchOuter,
		lerp(baseX, baseX + rw * 0.55, 0.18), lerp(fletchOuter, fletchInner, 0.18),
		lerp(baseX, baseX + rw * 0.22, 0.18), lerp(fletchOuter, tailY + facing * 2, 0.18))

		love.graphics.setColor(tipColor)
		love.graphics.polygon("fill",
		baseX, tipY,
		baseX - shaftWidth * 1.05, shaftEnd,
		baseX + shaftWidth * 1.05, shaftEnd)

		local tipHighlight = getRimLightColor(tipColor)
		love.graphics.setColor(tipHighlight[1], tipHighlight[2], tipHighlight[3], tipHighlight[4])
		love.graphics.polygon("fill",
		baseX, tipY,
		lerp(baseX, baseX - shaftWidth * 1.05, 0.42), lerp(tipY, shaftEnd, 0.24),
		lerp(baseX, baseX + shaftWidth * 1.05, 0.18), lerp(tipY, shaftEnd, 0.18))

		local tipOcclusion = getOcclusionColor(tipColor)
		love.graphics.setColor(tipOcclusion[1], tipOcclusion[2], tipOcclusion[3], tipOcclusion[4])
		love.graphics.polygon("fill",
		baseX, tipY,
		lerp(baseX, baseX - shaftWidth * 1.05, 0.42), lerp(tipY, shaftEnd, 0.8),
		lerp(baseX, baseX + shaftWidth * 1.05, 0.42), lerp(tipY, shaftEnd, 0.8))

	end

	love.graphics.pop()

	if emitter.impactTimer and emitter.impactTimer > 0 then
		local age = clamp01(1 - emitter.impactTimer / IMPACT_FLASH_DURATION)
		local radius = 10 + age * 20
		local alpha = clamp01(emitter.impactTimer / IMPACT_FLASH_DURATION)
		love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], 0.4 * alpha)
		love.graphics.circle("line", emitter.dartX or emitter.endX, emitter.dartY or emitter.endY, radius, 16)
	end
end

function Darts:draw()
	if not DARTS_ENABLED then
		return
	end

	for index = 1, #emitters do
		local emitter = emitters[index]
		drawEmitter(emitter)
		drawTelegraphPath(emitter)
		drawDart(emitter)
	end
end

return Darts