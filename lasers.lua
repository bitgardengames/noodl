local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Audio = require("audio")
local Easing = require("easing")
local FrameClock = require("frameclock")

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin

local Lasers = {}

local LASERS_ENABLED = true

local emitters = {}
local stallTimer = 0

function Lasers:isEnabled()
	return LASERS_ENABLED
end

Lasers.fireDurationMult = 1
Lasers.fireDurationFlat = 0
Lasers.chargeDurationMult = 1
Lasers.chargeDurationFlat = 0
Lasers.cooldownMult = 1
Lasers.cooldownFlat = 0

local FLASH_DECAY = 3.8
local DEFAULT_FIRE_COLOR = {1, 0.16, 0.16, 1}
local DEFAULT_BEAM_THICKNESS = 4.5
local DEFAULT_FIRE_DURATION = 1.2
local DEFAULT_CHARGE_DURATION = 1.2
local BURN_FADE_RATE = 0.55
local WALL_INSET = 6
local BEAM_PULSE_SPEED = 7.2
local BEAM_GLOW_EXPANSION = 8
local BASE_GLOW_RADIUS = 18
local IMPACT_RING_SPEED = 1.85
local IMPACT_RING_RANGE = 16
local IMPACT_FLARE_RADIUS = 12

local function getTime()
        return FrameClock:get()
end

local function copyColor(color, alpha)
	local r = 1
	local g = 0.38
	local b = 0.18
	local a = alpha or 1

	if type(color) == "table" then
		r = color[1] or r
		g = color[2] or g
		b = color[3] or b
		a = color[4] or a
	end

	return {r, g, b, a}
end

local function clamp01(value)
        if value < 0 then
                return 0
        end
        if value > 1 then
                return 1
        end
        return value
end

local function getRelativeLuminance(color)
        if not color then
                return 0
        end

        local r = color[1] or 0
        local g = color[2] or 0
        local b = color[3] or 0

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function getFirePalette(color)
        local base = copyColor(color or DEFAULT_FIRE_COLOR)
        local glow = copyColor(base, (base[4] or 1) * 0.65)
        local core = copyColor(base, 0.95)
        local rim = copyColor(base, 1.0)

        rim[1] = min(1, rim[1] * 1.1)
        rim[2] = min(1, rim[2] * 0.7)
        rim[3] = min(1, rim[3] * 0.7)
        rim[4] = 1.0

        local arenaColor = Theme.arenaBG or Theme.bgColor
        local arenaLum = getRelativeLuminance(arenaColor)
        local rimBoost = clamp01((arenaLum - 0.45) * 1.6)
        if rimBoost > 0 then
                rim[1] = clamp01(rim[1] * (1 - 0.35 * rimBoost) + rimBoost)
                rim[2] = clamp01(rim[2] * (1 - 0.45 * rimBoost) + rimBoost * 0.2)
                rim[3] = clamp01(rim[3] * (1 - 0.45 * rimBoost) + rimBoost * 0.2)
                glow[4] = clamp(glow[4] + rimBoost * 0.35, 0, 1)
                core[4] = clamp(core[4] + rimBoost * 0.2, 0, 1)
        end

        return {
                glow = glow,
                core = core,
                rim = rim,
        }
end

local function clonePalette(palette)
        if not palette then
                return nil
        end

        local copy = {}
        if palette.glow then copy.glow = copyColor(palette.glow) end
        if palette.core then copy.core = copyColor(palette.core) end
        if palette.rim then copy.rim = copyColor(palette.rim) end
        return copy
end

local function ensureBasePalette(beam)
        if not beam then
                return nil
        end

        if not beam.baseFirePalette then
                local base = clonePalette(beam.firePalette)
                if not base then
                        base = clonePalette(getFirePalette(DEFAULT_FIRE_COLOR))
                end
                beam.baseFirePalette = base
        end

        return beam.baseFirePalette
end

local function applyPaletteOverride(beam)
        if not beam then
                return
        end

        local basePalette = ensureBasePalette(beam)
        if basePalette then
                beam.firePalette = clonePalette(basePalette)
        end
end

local function getEmitterColors()
	local body = Theme.laserBaseColor or {0.18, 0.19, 0.24, 0.95}
	local accent = copyColor(Theme.laserColor or {1, 0.32, 0.26, 1})
	accent[4] = 0.85
	return body, accent
end

local function releaseOccupancy(beam)
	if not beam then
		return
	end

	if beam.col and beam.row then
		SnakeUtils.setOccupied(beam.col, beam.row, false)
	end
end

local function getFacingFromPosition(dir, col, row)
	if dir == "vertical" then
		local midpoint = floor((Arena.rows or 1) / 2)
		if row and row > midpoint then
			return -1
		end
	else
		local midpoint = floor((Arena.cols or 1) / 2)
		if col and col > midpoint then
			return -1
		end
	end

	return 1
end

local function clamp(value, minimum, maximum)
	if minimum and value < minimum then
		return minimum
	end
	if maximum and value > maximum then
		return maximum
	end
	return value
end

local function applyDurationModifiers(base, mult, flat, minimum)
	if not base then
		return nil
	end

	mult = mult or 1
	flat = flat or 0
	local value = base * mult + flat
	if minimum then
		value = max(minimum, value)
	end

	return value
end

local function computeCooldownBounds(baseMin, baseMax)
	local mult = Lasers.cooldownMult or 1
	local flat = Lasers.cooldownFlat or 0

	local minValue = (baseMin or 0) * mult + flat
	minValue = max(0, minValue)

	local maxBase = baseMax or baseMin or 0
	local maxValue = maxBase * mult + flat
	if maxValue < minValue then
		maxValue = minValue
	end

	return minValue, maxValue
end

local function recalcBeamTiming(beam, isInitial)
	if not beam then
		return
	end

	local baseFire = beam.baseFireDuration or DEFAULT_FIRE_DURATION
	local baseCharge = beam.baseChargeDuration or DEFAULT_CHARGE_DURATION
	local baseMin = beam.baseCooldownMin or 4.2
	local baseMax = beam.baseCooldownMax or (baseMin + 3.4)

	local oldFire = beam.fireDuration or baseFire
	local oldCharge = beam.chargeDuration or baseCharge
	local oldCooldownDuration = beam.cooldownDuration or (beam.fireCooldown or baseMin)
	local remainingCooldown = beam.fireCooldown

	local newFire = applyDurationModifiers(baseFire, Lasers.fireDurationMult, Lasers.fireDurationFlat, 0.1)
	local newCharge = applyDurationModifiers(baseCharge, Lasers.chargeDurationMult, Lasers.chargeDurationFlat, 0.05)
	local newMin, newMax = computeCooldownBounds(baseMin, baseMax)

	beam.fireDuration = newFire
	beam.chargeDuration = newCharge
	beam.fireCooldownMin = newMin
	beam.fireCooldownMax = newMax

	local roll = beam.cooldownRoll
	if roll == nil or isInitial then
		roll = love.math.random()
		beam.cooldownRoll = roll
	end

	local duration = newMin + (newMax - newMin) * roll
	duration = max(newMin, duration)

	beam.cooldownDuration = duration

	if isInitial then
		beam.fireCooldown = duration
		beam.fireTimer = nil
		beam.chargeTimer = nil
		return
	end

	if beam.state == "firing" and beam.fireTimer then
		local progress = 0
		if oldFire and oldFire > 0 then
			progress = clamp(1 - (beam.fireTimer / oldFire), 0, 1)
		end
		beam.fireTimer = newFire * (1 - progress)
	elseif beam.fireTimer and beam.fireTimer > newFire then
		beam.fireTimer = newFire
	end

	if beam.state == "charging" and beam.chargeTimer then
		local progress = 0
		if oldCharge and oldCharge > 0 then
			progress = clamp(1 - (beam.chargeTimer / oldCharge), 0, 1)
		end
		beam.chargeTimer = newCharge * (1 - progress)
	elseif beam.chargeTimer and beam.chargeTimer > newCharge then
		beam.chargeTimer = newCharge
	end

	if remainingCooldown then
		local progress = 0
		if oldCooldownDuration and oldCooldownDuration > 0 then
			progress = clamp(1 - (remainingCooldown / oldCooldownDuration), 0, 1)
		end
		beam.fireCooldown = duration * (1 - progress)
	end
end

local function computeBeamTarget(beam)
	local tileSize = Arena.tileSize or 24
	local facing = beam.facing or 1
	local inset = max(2, tileSize * 0.5 - 4)
	local startX = beam.x or 0
	local startY = beam.y or 0
	local endX, endY
	local rocks = Rocks:getAll() or {}
	local bestDistance = math.huge
	local hitRock

	if beam.dir == "horizontal" then
		startX = startX + facing * inset
		endY = startY

		local wallX
		if facing > 0 then
			wallX = (Arena.x or 0) + (Arena.width or 0) - WALL_INSET
		else
			wallX = (Arena.x or 0) + WALL_INSET
		end

		endX = wallX

		for _, rock in ipairs(rocks) do
			if rock.row == beam.row then
				local delta = (rock.x - (beam.x or 0)) * facing
				if delta and delta > 0 and delta < bestDistance then
					bestDistance = delta
					hitRock = rock
				end
			end
		end

		if hitRock then
			local edge = tileSize * 0.5 - 2
			endX = hitRock.x - facing * edge
		end
	else
		startY = startY + facing * inset
		endX = startX

		local wallY
		if facing > 0 then
			wallY = (Arena.y or 0) + (Arena.height or 0) - WALL_INSET
		else
			wallY = (Arena.y or 0) + WALL_INSET
		end

		endY = wallY

		for _, rock in ipairs(rocks) do
			if rock.col == beam.col then
				local delta = (rock.y - (beam.y or 0)) * facing
				if delta and delta > 0 and delta < bestDistance then
					bestDistance = delta
					hitRock = rock
				end
			end
		end

		if hitRock then
			local edge = tileSize * 0.5 - 2
			endY = hitRock.y - facing * edge
		end
	end

	if beam.dir == "horizontal" then
		local minX = min(startX, endX)
		local width = max(0, abs(endX - startX))
		local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
		beam.beamRect = {minX, startY - thickness * 0.5, width, thickness}
	else
		local minY = min(startY, endY)
		local height = max(0, abs(endY - startY))
		local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
		beam.beamRect = {startX - thickness * 0.5, minY, thickness, height}
	end

	beam.beamStartX = startX
	beam.beamStartY = startY
	beam.beamEndX = endX
	beam.beamEndY = endY or startY
	beam.impactX = endX
	beam.impactY = endY or startY
	beam.targetRock = hitRock
end

function Lasers:reset()
        for _, beam in ipairs(emitters) do
                releaseOccupancy(beam)
        end
        emitters = {}

        stallTimer = 0

        if not LASERS_ENABLED then
                return
        end
end

function Lasers:spawn(x, y, dir, options)
	if not LASERS_ENABLED then
		return
	end

	dir = dir or "horizontal"
	options = options or {}

	local col, row = Arena:getTileFromWorld(x, y)
	local facing = options.facing
	if facing == nil then
		facing = getFacingFromPosition(dir, col, row)
	end

	facing = (facing >= 0) and 1 or -1

        local initialPalette = options.firePalette and clonePalette(options.firePalette) or getFirePalette(options.fireColor)

        local beam = {
                x = x,
                y = y,
                col = col,
                row = row,
                dir = dir,
                facing = facing,
                beamThickness = options.beamThickness or DEFAULT_BEAM_THICKNESS,
                firePalette = clonePalette(initialPalette) or getFirePalette(options.fireColor),
                state = "cooldown",
                flashTimer = 0,
                burnAlpha = 0,
                baseGlow = 0,
                telegraphStrength = 0,
                randomOffset = love.math.random() * pi * 2,
        }

        beam.baseFirePalette = clonePalette(initialPalette)

        beam.baseFireDuration = max(0.2, options.fireDuration or DEFAULT_FIRE_DURATION)
        beam.baseChargeDuration = max(0.25, options.chargeDuration or DEFAULT_CHARGE_DURATION)
        beam.baseCooldownMin = options.fireCooldownMin or 4.2
        beam.baseCooldownMax = options.fireCooldownMax or (beam.baseCooldownMin + 3.4)
        if beam.baseCooldownMax < beam.baseCooldownMin then
                beam.baseCooldownMax = beam.baseCooldownMin
        end

        if options.gilded then
                beam.gilded = true
                beam.baseGlow = max(beam.baseGlow or 0, 0.45)
        end

        recalcBeamTiming(beam, true)

        applyPaletteOverride(beam)

        SnakeUtils.setOccupied(col, row, true)

        computeBeamTarget(beam)
        emitters[#emitters + 1] = beam
	return beam
end

function Lasers:getEmitters()
        local copies = {}
        for index, beam in ipairs(emitters) do
                copies[index] = beam
        end
        return copies
end

function Lasers:stall(duration, options)
        if not duration or duration <= 0 then
                return
        end

        stallTimer = (stallTimer or 0) + duration

        local Upgrades = package.loaded["upgrades"]
        if Upgrades and Upgrades.notify then
                local event = {
                        duration = duration,
                        total = stallTimer,
                        cause = options and options.cause or nil,
                        source = options and options.source or nil,
                }

                local positions = {}
                local beams = {}
                local limit = (options and options.positionLimit) or 4

                for _, beam in ipairs(emitters) do
                        if beam then
                                local bx, by = beam.x, beam.y
                                if bx and by then
                                        positions[#positions + 1] = {bx, by}
                                        beams[#beams + 1] = {
                                                x = bx,
                                                y = by,
                                                dir = beam.dir,
                                                facing = beam.facing,
                                        }

                                        if limit and limit > 0 and #positions >= limit then
                                                break
                                        end
                                end
                        end
                end

                if #positions > 0 then
                        event.positions = positions
                        event.positionCount = #positions
                end

                if #beams > 0 then
                        event.lasers = beams
                        event.laserCount = #beams
                end

                Upgrades:notify("lasersStalled", event)
        end
end

local function updateEmitterSlide(beam, dt)
        local duration = beam and beam.tremorSlideDuration
        if not (duration and duration > 0) then
                return
        end

        local timer = math.min((beam.tremorSlideTimer or 0) + (dt or 0), duration)
        beam.tremorSlideTimer = timer

        local progress = Easing.easeOutCubic(Easing.clamp01(duration <= 0 and 1 or timer / duration))
        local startX = beam.tremorSlideStartX or beam.x
        local startY = beam.tremorSlideStartY or beam.y
        local targetX = beam.tremorSlideTargetX or beam.x
        local targetY = beam.tremorSlideTargetY or beam.y

        beam.renderX = Easing.lerp(startX, targetX, progress)
        beam.renderY = Easing.lerp(startY, targetY, progress)

        if timer >= duration then
                beam.tremorSlideTimer = nil
                beam.tremorSlideDuration = nil
                beam.tremorSlideStartX = nil
                beam.tremorSlideStartY = nil
                beam.tremorSlideTargetX = nil
                beam.tremorSlideTargetY = nil
                beam.renderX = nil
                beam.renderY = nil
        end
end

function Lasers:update(dt)
        if not LASERS_ENABLED then
                return
        end

        if dt <= 0 then
                return
        end

        local stall = stallTimer or 0
        if stall > 0 then
                if dt <= stall then
                        stallTimer = max(0, stall - dt)
                        return
                end

                dt = dt - stall
                stallTimer = 0
        end

        for _, beam in ipairs(emitters) do
                updateEmitterSlide(beam, dt)
                computeBeamTarget(beam)

                if beam.state == "charging" then
			beam.chargeTimer = (beam.chargeTimer or beam.chargeDuration) - dt
			if beam.chargeTimer <= 0 then
				beam.state = "firing"
				beam.fireTimer = beam.fireDuration
				beam.chargeTimer = nil
				beam.flashTimer = max(beam.flashTimer or 0, 0.75)
				beam.burnAlpha = 0.92
				Audio:playSound("laser_fire")
			end
		elseif beam.state == "firing" then
			beam.fireTimer = (beam.fireTimer or beam.fireDuration) - dt
			beam.burnAlpha = 0.92
			if beam.fireTimer <= 0 then
				beam.state = "cooldown"
				beam.cooldownRoll = love.math.random()
				local minCooldown = beam.fireCooldownMin or 0
				local maxCooldown = beam.fireCooldownMax or minCooldown
				if maxCooldown < minCooldown then
					maxCooldown = minCooldown
				end
				local duration = minCooldown + (maxCooldown - minCooldown) * (beam.cooldownRoll or 0)
				local pending = beam.pendingCooldownBonus or 0
				if pending ~= 0 then
					duration = duration + pending
					beam.pendingCooldownBonus = nil
				end
				beam.cooldownDuration = duration
				beam.fireCooldown = duration
				beam.fireTimer = nil
			end
		else
			local pending = beam.pendingCooldownBonus
			if pending and pending ~= 0 and beam.fireCooldown then
				beam.fireCooldown = beam.fireCooldown + pending
				beam.cooldownDuration = (beam.cooldownDuration or 0) + pending
				beam.pendingCooldownBonus = nil
			end
			if beam.fireCooldown then
				beam.fireCooldown = beam.fireCooldown - dt
				if beam.fireCooldown <= 0 then
					beam.state = "charging"
					beam.chargeTimer = beam.chargeDuration
					beam.fireCooldown = nil
				end
			else
				beam.state = "charging"
				beam.chargeTimer = beam.chargeDuration
			end
		end

		local targetGlow = 0
		local telegraphStrength = beam.telegraphStrength or 0
		if beam.state == "charging" then
			local duration = max(beam.chargeDuration or 0, 0.01)
			local timer = clamp(beam.chargeTimer or duration, 0, duration)
			local progress = 1 - (timer / duration)
			progress = clamp(progress, 0, 1)
			telegraphStrength = progress * progress
			targetGlow = telegraphStrength
		else
			telegraphStrength = max(0, telegraphStrength - dt * 3.6)
			targetGlow = 0
		end
		beam.telegraphStrength = telegraphStrength

		local glow = beam.baseGlow or 0
		local glowApproach = dt * 3.2
		if glow < targetGlow then
			glow = min(targetGlow, glow + glowApproach)
		else
			glow = max(targetGlow, glow - glowApproach * 0.75)
		end
		beam.baseGlow = glow

		if beam.state ~= "firing" then
			beam.burnAlpha = max(0, (beam.burnAlpha or 0) - dt * BURN_FADE_RATE)
		end

		if beam.flashTimer and beam.flashTimer > 0 then
			beam.flashTimer = max(0, beam.flashTimer - dt * FLASH_DECAY)
		end
	end
end

function Lasers:onShieldedHit(beam, hitX, hitY)
	if not LASERS_ENABLED then
		return
	end

	if not beam then
		return
	end

	beam.flashTimer = max(beam.flashTimer or 0, 1)

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		Upgrades:notify("laserShielded", {
			beam = beam,
			x = hitX,
			y = hitY,
			emitterX = beam.x,
			emitterY = beam.y,
			impactX = beam.impactX,
			impactY = beam.impactY,
		})
	end
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function baseBounds(beam)
	if not beam then
		return
	end

	local size = Arena.tileSize or 24
	local half = size * 0.5
	local margin = max(2, size * 0.22)
	if margin > half then
		margin = half
	end

	local width = size - margin * 2
	local height = width
	local bx = (beam.x or 0) - width * 0.5
	local by = (beam.y or 0) - height * 0.5
	return bx, by, width, height
end

function Lasers:applyTimingModifiers()
	if not LASERS_ENABLED then
		return
	end

	for _, beam in ipairs(emitters) do
		recalcBeamTiming(beam, false)
	end
end

function Lasers:checkCollision(x, y, w, h)
	if not LASERS_ENABLED then
		return nil
	end

	if not (x and y and w and h) then
		return nil
	end

	for _, beam in ipairs(emitters) do
		local bx, by, bw, bh = baseBounds(beam)
		if bx and rectsOverlap(bx, by, bw, bh, x, y, w, h) then
			beam.flashTimer = max(beam.flashTimer or 0, 1)
			return beam
		end

		if beam.state == "firing" and beam.beamRect then
			local rx, ry, rw, rh = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
			if rw and rh and rw > 0 and rh > 0 and rectsOverlap(rx, ry, rw, rh, x, y, w, h) then
				beam.flashTimer = max(beam.flashTimer or 0, 1)
				return beam
			end
		end
	end

	return nil
end

local function drawBurnMark(beam)
	if not (beam and beam.impactX and beam.impactY) then
		return
	end

	local alpha = clamp(beam.burnAlpha or 0, 0, 1)
	if alpha <= 0 then
		return
	end

	local radius = max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8)
	love.graphics.setColor(0, 0, 0, 0.5 * alpha)
	love.graphics.circle("fill", beam.impactX, beam.impactY, radius)
	love.graphics.setColor(0.1, 0.05, 0.05, 0.7 * alpha)
	love.graphics.circle("fill", beam.impactX, beam.impactY, radius * 0.55)
	love.graphics.setColor(0.95, 0.25, 0.2, 0.18 * alpha)
	love.graphics.circle("line", beam.impactX, beam.impactY, radius * 0.9)
end

local function drawBeam(beam)
	if not beam.beamRect then
		return
	end

	local palette = beam.firePalette or getFirePalette(DEFAULT_FIRE_COLOR)
	local x, y, w, h = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
	if not (x and y and w and h) then
		return
	end

	local t = getTime()
	local facingSign = beam.facing or 1

	if beam.state == "firing" then
		local flicker = 0.82 + 0.18 * sin(t * 11 + (beam.beamStartX or 0) * 0.05 + (beam.beamStartY or 0) * 0.05)
		local glowAlpha = (palette.glow[4] or 0.5) * flicker
		love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], glowAlpha)
		love.graphics.rectangle("fill", x - BEAM_GLOW_EXPANSION, y - BEAM_GLOW_EXPANSION, w + BEAM_GLOW_EXPANSION * 2, h + BEAM_GLOW_EXPANSION * 2, 7, 7)

		local innerGlowAlpha = min(1, (palette.core[4] or 0.9) * (0.85 + 0.15 * flicker))
		love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], innerGlowAlpha)
		love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 6, 6)

		local rim = palette.rim or palette.core
		love.graphics.setColor(rim[1], rim[2], rim[3], (rim[4] or 1))
		love.graphics.rectangle("fill", x, y, w, h, 4, 4)

		local highlightThickness = max(1.5, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.35)
		love.graphics.setColor(1, 0.97, 0.75, 0.55)
		if beam.dir == "horizontal" then
			local centerY = y + h * 0.5
			love.graphics.rectangle("fill", x, centerY - highlightThickness * 0.5, w, highlightThickness, 3, 3)
		else
			local centerX = x + w * 0.5
			love.graphics.rectangle("fill", centerX - highlightThickness * 0.5, y, highlightThickness, h, 3, 3)
		end

		local edgeThickness = max(1, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.22)
		love.graphics.setColor(1, 0.65, 0.45, 0.35 + 0.25 * flicker)
		if beam.dir == "horizontal" then
			love.graphics.rectangle("fill", x, y + h - edgeThickness, w, edgeThickness, 3, 3)
			love.graphics.rectangle("fill", x, y, w, edgeThickness, 3, 3)
		else
			love.graphics.rectangle("fill", x + w - edgeThickness, y, edgeThickness, h, 3, 3)
			love.graphics.rectangle("fill", x, y, edgeThickness, h, 3, 3)
		end

		local length = (beam.dir == "horizontal") and w or h
		local pulseSpacing = max(24, length / 6)
		local pulseSize = pulseSpacing * 0.55
		local travel = (t * BEAM_PULSE_SPEED * 45 * facingSign) % pulseSpacing
		love.graphics.setColor(1, 0.8, 0.45, 0.25 + 0.35 * flicker)
		if beam.dir == "horizontal" then
			for start = -travel, w, pulseSpacing do
				local segmentStart = max(0, start)
				local segmentEnd = min(w, start + pulseSize)
				if segmentEnd > segmentStart then
					love.graphics.rectangle("fill", x + segmentStart, y + h * 0.15, segmentEnd - segmentStart, h * 0.7, 3, 3)
				end
			end

			local sparkCount = max(2, floor(w / 96))
			love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
			for i = 0, sparkCount do
				local offset = (i / max(1, sparkCount)) * w
				local sway = sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (h * 0.12)
				local sparkWidth = max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
				love.graphics.rectangle("fill", x + offset - sparkWidth * 0.5, y + h * 0.5 + sway - edgeThickness, sparkWidth, edgeThickness * 2, 3, 3)
			end
		else
			for start = -travel, h, pulseSpacing do
				local segmentStart = max(0, start)
				local segmentEnd = min(h, start + pulseSize)
				if segmentEnd > segmentStart then
					love.graphics.rectangle("fill", x + w * 0.15, y + segmentStart, w * 0.7, segmentEnd - segmentStart, 3, 3)
				end
			end

			local sparkCount = max(2, floor(h / 96))
			love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
			for i = 0, sparkCount do
				local offset = (i / max(1, sparkCount)) * h
				local sway = sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (w * 0.12)
				local sparkHeight = max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
				love.graphics.rectangle("fill", x + w * 0.5 + sway - edgeThickness, y + offset - sparkHeight * 0.5, edgeThickness * 2, sparkHeight, 3, 3)
			end
		end
	elseif beam.state == "charging" then
		local duration = beam.chargeDuration or DEFAULT_CHARGE_DURATION
		local remaining = clamp(beam.chargeTimer or 0, 0, duration)
		local progress = (duration <= 0) and 1 or (1 - remaining / duration)
		local alpha = 0.15 + 0.45 * progress
		love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], alpha * 0.45)
		love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, 6, 6)
		love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], alpha * 0.85)
		love.graphics.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 4, 4)

		love.graphics.setColor(1, 0.95, 0.65, 0.25 + 0.35 * progress)
		if beam.dir == "horizontal" then
			local bandHeight = max(1.2, h * 0.25)
			love.graphics.rectangle("fill", x, y + h * 0.5 - bandHeight * 0.5, w, bandHeight, 2, 2)
		else
			local bandWidth = max(1.2, w * 0.25)
			love.graphics.rectangle("fill", x + w * 0.5 - bandWidth * 0.5, y, bandWidth, h, 2, 2)
		end

		local stripes = 4
		local rim = palette.rim or palette.core
		for i = 0, stripes - 1 do
			local offset = (progress + i / stripes) % 1
			local stripeAlpha = max(0, (0.55 - i * 0.08) * (0.35 + progress * 0.65))
			if beam.dir == "horizontal" then
				local stripeX = x + (w - 6) * offset
				love.graphics.setColor(rim[1], rim[2], rim[3], stripeAlpha)
				love.graphics.rectangle("fill", stripeX, y + 1, 6, h - 2, 2, 2)
			else
				local stripeY = y + (h - 6) * offset
				love.graphics.setColor(rim[1], rim[2], rim[3], stripeAlpha)
				love.graphics.rectangle("fill", x + 1, stripeY, w - 2, 6, 2, 2)
			end
		end

		local resonance = sin(t * 4 + (beam.randomOffset or 0)) * 0.5 + 0.5
		local shimmer = 0.2 + 0.4 * progress
		love.graphics.setColor(rim[1], rim[2], rim[3], shimmer * (0.3 + resonance * 0.5))
		if beam.dir == "horizontal" then
			love.graphics.rectangle("fill", x, y + h * 0.3, w, h * 0.1, 2, 2)
			love.graphics.rectangle("fill", x, y + h * 0.6, w, h * 0.1, 2, 2)
		else
			love.graphics.rectangle("fill", x + w * 0.3, y, w * 0.1, h, 2, 2)
			love.graphics.rectangle("fill", x + w * 0.6, y, w * 0.1, h, 2, 2)
		end
	end
end

local function drawImpactEffect(beam)
	if beam.state ~= "firing" then
		return
	end

	if not (beam.impactX and beam.impactY) then
		return
	end

	local palette = beam.firePalette or getFirePalette(DEFAULT_FIRE_COLOR)
	local core = palette.core or DEFAULT_FIRE_COLOR
	local rim = palette.rim or core
	local t = getTime()
	local offset = beam.randomOffset or 0
	local flicker = 0.75 + 0.25 * sin(t * 10 + offset)
	local baseRadius = (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8

	love.graphics.setColor(core[1], core[2], core[3], 0.35 + 0.4 * flicker)
	love.graphics.circle("fill", beam.impactX, beam.impactY, baseRadius + sin(t * 8 + offset) * 1.5)

	local pulse = math.fmod(t * IMPACT_RING_SPEED + offset, 1)
	if pulse < 0 then
		pulse = pulse + 1
	end

	local pulseRadius = IMPACT_FLARE_RADIUS + pulse * IMPACT_RING_RANGE
	local pulseAlpha = max(0, 0.55 * (1 - pulse))
	love.graphics.setColor(rim[1], rim[2], rim[3], pulseAlpha)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", beam.impactX, beam.impactY, pulseRadius)

	love.graphics.setColor(1, 0.95, 0.75, 0.45 * flicker)
	local sparkLength = IMPACT_FLARE_RADIUS * 1.3
	local spokes = 6
	for i = 0, spokes - 1 do
		local angle = offset + (i / spokes) * (pi * 2)
		local dx = math.cos(angle) * sparkLength
		local dy = sin(angle) * sparkLength
		love.graphics.line(beam.impactX - dx * 0.35, beam.impactY - dy * 0.35, beam.impactX + dx, beam.impactY + dy)
	end
end

local function drawEmitterBase(beam)
        local baseColor, accentColor = getEmitterColors()
        local tileSize = Arena.tileSize or 24
        local half = tileSize * 0.5
        local cx = beam.renderX or beam.x or 0
        local cy = beam.renderY or beam.y or 0
        local bx = cx - half
        local by = cy - half
        local flash = clamp(beam.flashTimer or 0, 0, 1)
        local telegraph = clamp(beam.telegraphStrength or 0, 0, 1)
        local baseGlow = clamp(beam.baseGlow or 0, 0, 1)
        local highlightBoost = (beam.state == "firing") and 0.28 or 0
        highlightBoost = highlightBoost + telegraph * 0.4

        local t = getTime()
        local pulseStrength = telegraph > 0 and (telegraph * (0.6 + telegraph * 0.4)) or 0
        local pulse = 0
        if pulseStrength > 0 then
                pulse = (0.18 + 0.25 * sin(t * 5.5 + cx * 0.03 + cy * 0.03)) * pulseStrength
        end
        local showPrimeRing = (telegraph > 0) or (beam.state == "firing")
        if showPrimeRing then
                local glowAlpha = 0.16 + baseGlow * 0.6 + flash * 0.35 + highlightBoost * 0.35 + pulse * 0.4
                love.graphics.setColor(1, 0.32, 0.25, min(0.85, glowAlpha))
                local glowRadius = BASE_GLOW_RADIUS + tileSize * 0.1 + baseGlow * (tileSize * 0.22)
                love.graphics.circle("fill", cx, cy, glowRadius)
        end

        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], (baseColor[4] or 1) + flash * 0.1)
        love.graphics.rectangle("fill", bx, by, tileSize, tileSize, 6, 6)

	love.graphics.setColor(0, 0, 0, 0.45 + flash * 0.25 + telegraph * 0.15)
	love.graphics.rectangle("line", bx, by, tileSize, tileSize, 6, 6)

	local accentAlpha = (accentColor[4] or 0.8) + flash * 0.2 + highlightBoost
	love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], min(1, accentAlpha))
	love.graphics.rectangle("line", bx + 2, by + 2, tileSize - 4, tileSize - 4, 4, 4)

	love.graphics.setColor(1, 1, 1, 0.16 + highlightBoost * 0.45 + flash * 0.2 + telegraph * 0.25)
	local highlightWidth = min(tileSize * 0.45, tileSize - 6)
	love.graphics.rectangle("fill", bx + 3, by + 3, highlightWidth, tileSize * 0.2, 3, 3)

	local slitLength = tileSize * 0.55
	local slitThickness = max(3, tileSize * 0.18)
        if showPrimeRing then
                local spin = (t * 2.5 + (beam.randomOffset or 0)) % (pi * 2)
                local ringRadius = tileSize * 0.45 + sin(t * 3.5 + (beam.randomOffset or 0)) * (tileSize * 0.05)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.28 + flash * 0.4 + highlightBoost * 0.35 + telegraph * 0.25)
		for i = 0, 2 do
			local angle = spin + i * (pi * 2 / 3)
			love.graphics.arc("line", "open", cx, cy, ringRadius, angle - 0.35, angle + 0.35, 16)
		end

		if beam.state == "charging" then
			local chargeLift = (sin(t * 6 + (beam.randomOffset or 0)) * 0.5 + 0.5) * tileSize * 0.08
			love.graphics.setColor(1, 0.4, 0.32, 0.35 + flash * 0.35 + telegraph * 0.55)
			love.graphics.circle("line", cx, cy, ringRadius * 0.65 + chargeLift)
		elseif beam.state == "firing" then
			love.graphics.setColor(1, 0.55, 0.4, 0.35 + flash * 0.45 + telegraph * 0.25)
			love.graphics.circle("line", cx, cy, ringRadius * 0.8)
		end
	end
	if beam.dir == "horizontal" then
		local dir = beam.facing or 1
		local front = cx + dir * (tileSize * 0.32)
		love.graphics.rectangle("fill", front - slitThickness * 0.5, cy - slitLength * 0.5, slitThickness, slitLength, 3, 3)
	else
		local dir = beam.facing or 1
		local front = cy + dir * (tileSize * 0.32)
		love.graphics.rectangle("fill", cx - slitLength * 0.5, front - slitThickness * 0.5, slitLength, slitThickness, 3, 3)
	end
end

function Lasers:draw()
        if not LASERS_ENABLED then
                return
        end

	if #emitters == 0 then
		return
	end

	love.graphics.push("all")
	love.graphics.setLineWidth(2)

	for _, beam in ipairs(emitters) do
		drawBurnMark(beam)
	end

	for _, beam in ipairs(emitters) do
		drawBeam(beam)
	end

	for _, beam in ipairs(emitters) do
		drawImpactEffect(beam)
	end

	for _, beam in ipairs(emitters) do
		drawEmitterBase(beam)
	end

        love.graphics.pop()
end

function Lasers:beginEmitterSlide(beam, startX, startY, targetX, targetY, options)
        if not beam then
                return
        end

        options = options or {}
        beam.tremorSlideDuration = options.duration or 0.26
        beam.tremorSlideTimer = 0
        beam.tremorSlideStartX = startX or beam.x
        beam.tremorSlideStartY = startY or beam.y
        beam.tremorSlideTargetX = targetX or beam.x
        beam.tremorSlideTargetY = targetY or beam.y
        beam.renderX = beam.tremorSlideStartX
        beam.renderY = beam.tremorSlideStartY
end

return Lasers
