local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Particles = require("particles")
local Audio = require("audio")
local Timer = require("timer")
local Color = require("color")

local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local sin = math.sin
local pi = math.pi
local random = love.math.random

local Darts = {}

Darts.speedMult = 1.0

local emitters = {}
local stallTimer = 0

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
local OUT = 3
local RADIUS = 3
local SHADOW_OFS = 3
local SHADOW_ALPHA = 0.25
local HALO_LINE = 2
local MUZZLE_INSET = 5
local MUZZLE_RADIUS = 2
local FIN_BACK = 5

local BASE_EMITTER_COLOR = {0.32, 0.34, 0.38, 0.95}
local BASE_ACCENT_COLOR = {0.46, 0.56, 0.62, 1.0}
local TELEGRAPH_COLOR = {0.64, 0.74, 0.82, 0.85}
local DART_BODY_COLOR = {0.70, 0.68, 0.60, 1.0}
local DART_TIP_COLOR = {0.82, 0.86, 0.90, 1.0}
local DART_TAIL_COLOR = {0.42, 0.68, 0.64, 1.0}

local scaleColorScratch = {0, 0, 0, 0}
local impactColorScratch = {0, 0, 0, 0}
local insetColorScratch = {0, 0, 0, 0}

local impactBurstOptions = {
	count = 0,
	speed = 118,
	speedVariance = 58,
	life = 0.3,
	size = 2.6,
	color = impactColorScratch,
	spread = pi * 2,
	angleJitter = pi * 0.9,
	drag = 3.8,
	gravity = 150,
	scaleMin = 0.5,
	scaleVariance = 0.42,
	fadeTo = 0.07,
}

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

local function scaleColor(color, factor, alphaFactor, target)
	local scale = factor or 1
	return Color.scale(color, scale, {
		default = Color.white,
		alphaFactor = alphaFactor or scale,
		target = target,
		}
	)
end

local function lerp(a, b, t)
	return a + (b - a) * t
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

local function applySpeedMultiplier(emitter)
	if not emitter then
		return
	end

	local mult = Darts.speedMult or 1
	if mult <= 0 then
		mult = 1
	end

	local travelDistance = emitter.travelDistance or 0

	if emitter.baseFireDuration and emitter.baseFireDuration > 0 then
		emitter.fireDuration = max(0.28, (emitter.baseFireDuration or 0.28) / mult)
	elseif travelDistance > 0 then
		local baseSpeed = emitter.baseDartSpeed or emitter.dartSpeed or DEFAULT_DART_SPEED
		if baseSpeed <= 0 then
			baseSpeed = DEFAULT_DART_SPEED
		end

		local speed = baseSpeed * mult
		if speed <= 0 then
			speed = DEFAULT_DART_SPEED
		end

		emitter.fireDuration = max(0.28, travelDistance / speed)
	else
		emitter.fireDuration = max(0.28, (emitter.fireDuration or 0.28) / mult)
	end

	if travelDistance > 0 then
		emitter.dartSpeed = travelDistance / (emitter.fireDuration or 0.28)
	else
		emitter.dartSpeed = (emitter.baseDartSpeed or emitter.dartSpeed or DEFAULT_DART_SPEED) * mult
	end

	if emitter.state == "firing" then
		local progress = clamp01(emitter.dartProgress or 0)
		emitter.fireTimer = (1 - progress) * (emitter.fireDuration or 0)
	end
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

	applySpeedMultiplier(emitter)
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
		local color = scaleColor(rockColor, 1.25, 1, impactColorScratch)
		color[4] = 1
		return color
	end

	local _, _, _, _, tipColor = getEmitterColors()
	local factor = (impactType == "snake") and 1.12 or 0.96
	local color = scaleColor(tipColor, factor, 1, impactColorScratch)
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

	impactBurstOptions.count = random(7, 11)
	impactBurstOptions.color = color
	impactBurstOptions.gravity = (impactType == "rock") and 200 or 150
	impactBurstOptions.fadeTo = (impactType == "rock") and 0.03 or 0.07

	Particles:spawnBurst(x, y, impactBurstOptions)
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
		Audio:playSound("dart_fire")
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
	self.speedMult = 1
end

function Darts:spawn(x, y, dir, options)
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

	emitter.baseDartSpeed = emitter.dartSpeed

	computeShotTargets(emitter)
	enterCooldown(emitter, true)

	if initialCooldownBonus and initialCooldownBonus > 0 then
		emitter.cooldownTimer = (emitter.cooldownTimer or 0) + initialCooldownBonus
	end

	emitters[#emitters + 1] = emitter
	return emitter
end

function Darts:setSpeedMultiplier(mult)
	local clamped = mult or 1
	if clamped <= 0 then
		clamped = 0.01
	end

	self.speedMult = clamped

	for _, emitter in ipairs(emitters) do
		applySpeedMultiplier(emitter)
	end
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
	dt = dt or 0

	local stall = stallTimer or 0
	local consumed = min(stall, dt)
	if consumed > 0 then
		stallTimer = stall - consumed
	end

	local idleDt = dt - consumed

	for index = 1, #emitters do
		local emitter = emitters[index]
		if emitter and emitter.state == "firing" then
			updateEmitter(emitter, dt)
		else
			updateEmitter(emitter, idleDt)
		end
	end
end

local function drawEmitter(emitter)
	local bodyColor, accentColor, telegraphColor = getEmitterColors()
	local tileSize = (Arena.tileSize or BASE_EMITTER_SIZE)
	local half = tileSize * 0.5
	local centerX = emitter.x or 0
	local centerY = emitter.y or 0
	local baseX = centerX - half
	local baseY = centerY - half

	love.graphics.push("all")

	local flash    = clamp01(emitter.flashTimer or 0)
	local strength = clamp01(emitter.telegraphStrength or 0)

	-- DROP SHADOW
	love.graphics.setColor(0, 0, 0, SHADOW_ALPHA)
	love.graphics.rectangle(
		"fill",
		baseX + SHADOW_OFS,
		baseY + SHADOW_OFS,
		tileSize,
		tileSize,
		RADIUS,
		RADIUS
	)

	-- MAIN HOUSING
	local housingAlpha = clamp01((bodyColor[4] or 1) + flash * 0.1)
	love.graphics.setColor(bodyColor)
	love.graphics.rectangle("fill", baseX, baseY, tileSize, tileSize, RADIUS, RADIUS)

	-- INSET
	local insetPad = 2
	local insetColor = scaleColor(bodyColor, 0.78 + strength * 0.12, 1, insetColorScratch)

	love.graphics.setColor(insetColor)
	love.graphics.rectangle(
		"fill",
		baseX + insetPad,
		baseY + insetPad,
		tileSize - insetPad * 2,
		tileSize - insetPad * 2,
		RADIUS - 1,
		RADIUS - 1
	)

	-- OUTER BLACK OUTLINE
	love.graphics.setColor(0, 0, 0, clamp01(0.9 + flash * 0.1 + strength * 0.1))
	love.graphics.setLineWidth(OUT)
	love.graphics.rectangle("line", baseX, baseY, tileSize, tileSize, RADIUS, RADIUS)

	-- MUZZLE POSITIONING (pixel perfect)
	local facing = emitter.facing or 1
	local muzzleX, muzzleY = centerX, centerY

	if emitter.dir == "horizontal" then
		muzzleX = centerX + facing * MUZZLE_INSET
	else
		muzzleY = centerY + facing * MUZZLE_INSET
	end

	-- HALO RING
	local haloRadius = MUZZLE_RADIUS + 2
	love.graphics.setColor(accentColor)
	love.graphics.setLineWidth(HALO_LINE)
	love.graphics.circle("line", muzzleX, muzzleY, haloRadius, 24)

	-- MUZZLE BLACK FILL
	love.graphics.setColor(0, 0, 0, clamp01(0.72 + strength * 0.15 + flash * 0.1))
	love.graphics.circle("fill", muzzleX, muzzleY, MUZZLE_RADIUS, 24)

	-- MUZZLE OUTLINE
	love.graphics.setColor(0, 0, 0, 0.9 + flash * 0.1)
	love.graphics.setLineWidth(OUT)
	love.graphics.circle("line", muzzleX, muzzleY, MUZZLE_RADIUS, 24)

	-- FLASH FRAME
	if flash > 0 then
		love.graphics.setColor(1, 1, 1, 0.3 * flash)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle(
			"line",
			baseX - 4,
			baseY - 4,
			tileSize + 8,
			tileSize + 8,
			8,
			8
		)
	end

	love.graphics.pop()
end

local function drawTelegraphPath(emitter)
	if not (emitter and emitter.state == "telegraph") then
		return
	end

	local _, _, telegraphColor, bodyColor, tipColor = getEmitterColors()
	local strength = clamp01(emitter.telegraphStrength or 0)
	if strength <= 0 then return end

	love.graphics.push("all")

	local tileSize = (Arena.tileSize or BASE_EMITTER_SIZE) - 2
	local centerX = emitter.x or 0
	local centerY = emitter.y or 0
	local facing  = emitter.facing or 1

	-- MUZZLE POSITIONING
	local muzzleX, muzzleY = centerX, centerY

	if emitter.dir == "horizontal" then
		muzzleX = centerX + facing * MUZZLE_INSET
	else
		muzzleY = centerY + facing * MUZZLE_INSET
	end

	-- TELEGRAPH SHAPING
	local peekDistance   = tileSize * (0.16 + strength * 0.28)
	local shaftThickness = tileSize * 0.18
	local tipLength      = tileSize * 0.22
	local shaftLength    = max(0, peekDistance - tipLength * 0.35)

	if emitter.dir == "horizontal" then
		local baseX  = muzzleX - facing * 2
		local tipX   = baseX + facing * peekDistance
		local shaftStart = baseX - facing * shaftLength

		local shaftY = muzzleY - shaftThickness * 0.34
		local shaftH = shaftThickness * 0.68

		if shaftLength > 0 then
			love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3],
				clamp01((bodyColor[4] or 1) * (0.6 + 0.4 * strength
			)
			)
			)
			love.graphics.rectangle("fill",
				min(shaftStart, baseX),
				shaftY,
				abs(baseX - shaftStart),
				shaftH,
				3,3
			)
		end

		-- Tip
		local tipHalf = shaftThickness * 0.55
		love.graphics.setColor(tipColor[1], tipColor[2], tipColor[3],
			clamp01((tipColor[4] or 1) * (0.65 + 0.35 * strength
		)
		)
		)
		love.graphics.polygon("fill",
			tipX, muzzleY,
			baseX, muzzleY - tipHalf,
			baseX, muzzleY + tipHalf
		)

	else -- vertical emitter
		local baseY  = muzzleY - facing * 2
		local tipY   = baseY + facing * peekDistance
		local shaftStart = baseY - facing * shaftLength

		local shaftX = muzzleX - shaftThickness * 0.34
		local shaftW = shaftThickness * 0.68

		if shaftLength > 0 then
			love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3],
				clamp01((bodyColor[4] or 1) * (0.6 + 0.4 * strength
			)
			)
			)
			love.graphics.rectangle("fill",
				shaftX,
				min(shaftStart, baseY),
				shaftW,
				abs(baseY - shaftStart),
				3,3
			)
		end

		local tipHalf = shaftThickness * 0.55
		love.graphics.setColor(tipColor[1], tipColor[2], tipColor[3],
			clamp01((tipColor[4] or 1) * (0.65 + 0.35 * strength
		)
		)
		)
		love.graphics.polygon("fill",
			muzzleX, tipY,
			muzzleX - tipHalf, baseY,
			muzzleX + tipHalf, baseY
		)
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

	-- COMMON HELPERS
	local function drawPoly(points, fillColor)
		-- Shadow
		love.graphics.setColor(0,0,0,SHADOW_ALPHA)
		local sh = {}
		for i=1,#points,2 do
			sh[i]   = points[i]   + SHADOW_OFS
			sh[i+1] = points[i+1] + SHADOW_OFS
		end
		love.graphics.polygon("fill", sh)

		-- Outline
		love.graphics.setColor(0,0,0,1)
		love.graphics.setLineWidth(OUT)
		love.graphics.polygon("line", points)

		-- Fill
		love.graphics.setColor(fillColor)
		love.graphics.polygon("fill", points)
	end

	local function drawRect(x,y,w,h,fillColor)
		-- Shadow
		love.graphics.setColor(0,0,0,SHADOW_ALPHA)
		love.graphics.rectangle("fill", x+SHADOW_OFS, y+SHADOW_OFS, w, h)

		-- Outline
		love.graphics.setColor(0,0,0,1)
		love.graphics.setLineWidth(OUT)
		love.graphics.rectangle("line", x,y,w,h)

		-- Fill
		love.graphics.setColor(fillColor)
		love.graphics.rectangle("fill", x,y,w,h)
	end

	-- HORIZONTAL DART
	if emitter.dir == "horizontal" then
		local facing = emitter.facing or 1
		local cx = emitter.dartX or emitter.startX
		local cy = emitter.dartY or emitter.startY

		local shaftH = 2
		local shaftY = cy - shaftH/2

		local tipX  = cx + facing * (rw * 0.5)
		local tailX = cx - facing * (rw * 0.5)

		local tipLength = 8
		local tailInset = 5

		local shaftStart = tailX + facing * tailInset
		local shaftEnd   = tipX  - facing * tipLength

		drawRect(shaftStart, shaftY, shaftEnd - shaftStart, shaftH, bodyColor)

		local tipPoly = {
			tipX, cy,
			shaftEnd, cy - 3,
			shaftEnd, cy + 3
		}
		drawPoly(tipPoly, tipColor)

		-- ARROW FLETCHING
		local finOuter = tailX + facing * (tailInset * 2.6 - FIN_BACK)
		local finInner = tailX + facing * (tailInset * 1.0 - FIN_BACK)
		local finH = 6

		local fletchTop = {
			finOuter, cy,
			finInner, cy - finH,
			tailX + facing*1, cy - 2
		}

		local fletchBot = {
			finOuter, cy,
			finInner, cy + finH,
			tailX + facing*1, cy + 2
		}

		drawPoly(fletchTop, tailColor)
		drawPoly(fletchBot, tailColor)

		-- VERTICAL DART
	else
		local facing = emitter.facing or 1
		local cx = emitter.dartX or emitter.startX
		local cy = emitter.dartY or emitter.startY

		local shaftW = 2
		local shaftX = cx - shaftW/2

		local tipY  = cy + facing * (rh * 0.5)
		local tailY = cy - facing * (rh * 0.5)

		local tipLength = 8
		local tailInset = 5

		local shaftStart = tailY + facing * tailInset
		local shaftEnd   = tipY  - facing * tipLength

		drawRect(shaftX, shaftStart, shaftW, shaftEnd - shaftStart, bodyColor)

		local tipPoly = {
			cx, tipY,
			cx - 3, shaftEnd,
			cx + 3, shaftEnd
		}
		drawPoly(tipPoly, tipColor)

		-- ARROW FLETCHING
		local finOuter = tailY + facing * (tailInset * 2.6 - FIN_BACK)
		local finInner = tailY + facing * (tailInset * 1.0 - FIN_BACK)
		local finW = 6

		local fletchLeft = {
			cx, finOuter,
			cx - finW, finInner,
			cx - 2, tailY + facing*1
		}

		local fletchRight = {
			cx, finOuter,
			cx + finW, finInner,
			cx + 2, tailY + facing*1
		}

		drawPoly(fletchLeft, tailColor)
		drawPoly(fletchRight, tailColor)
	end

	love.graphics.pop()
end

function Darts:draw()
	for index = 1, #emitters do
		local emitter = emitters[index]
		drawEmitter(emitter)
		drawTelegraphPath(emitter)
		drawDart(emitter)
	end
end

return Darts
