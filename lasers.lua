local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Audio = require("audio")

local Lasers = {}

local LASERS_ENABLED = true

local emitters = {}

function Lasers:IsEnabled()
	return LASERS_ENABLED
end

Lasers.FireDurationMult = 1
Lasers.FireDurationFlat = 0
Lasers.ChargeDurationMult = 1
Lasers.ChargeDurationFlat = 0
Lasers.CooldownMult = 1
Lasers.CooldownFlat = 0

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

local function GetTime()
	return love.timer.getTime()
end

local function CopyColor(color, alpha)
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

	return { r, g, b, a }
end

local function GetFirePalette(color)
	local base = CopyColor(color or DEFAULT_FIRE_COLOR)
	local glow = CopyColor(base, (base[4] or 1) * 0.65)
	local core = CopyColor(base, 0.95)
	local rim = CopyColor(base, 1.0)

	rim[1] = math.min(1, rim[1] * 1.1)
	rim[2] = math.min(1, rim[2] * 0.7)
	rim[3] = math.min(1, rim[3] * 0.7)
	rim[4] = 1.0

	return {
		glow = glow,
		core = core,
		rim = rim,
	}
end

local function GetEmitterColors()
	local body = Theme.LaserBaseColor or {0.18, 0.19, 0.24, 0.95}
	local accent = CopyColor(Theme.LaserColor or {1, 0.32, 0.26, 1})
	accent[4] = 0.85
	return body, accent
end

local function ReleaseOccupancy(beam)
	if not beam then
		return
	end

	if beam.col and beam.row then
		SnakeUtils.SetOccupied(beam.col, beam.row, false)
	end
end

local function GetFacingFromPosition(dir, col, row)
	if dir == "vertical" then
		local midpoint = math.floor((Arena.rows or 1) / 2)
		if row and row > midpoint then
			return -1
		end
	else
		local midpoint = math.floor((Arena.cols or 1) / 2)
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

local function ApplyDurationModifiers(base, mult, flat, minimum)
	if not base then
		return nil
	end

	mult = mult or 1
	flat = flat or 0
	local value = base * mult + flat
	if minimum then
		value = math.max(minimum, value)
	end

	return value
end

local function ComputeCooldownBounds(BaseMin, BaseMax)
	local mult = Lasers.CooldownMult or 1
	local flat = Lasers.CooldownFlat or 0

	local MinValue = (BaseMin or 0) * mult + flat
	MinValue = math.max(0, MinValue)

	local MaxBase = BaseMax or BaseMin or 0
	local MaxValue = MaxBase * mult + flat
	if MaxValue < MinValue then
		MaxValue = MinValue
	end

	return MinValue, MaxValue
end

local function RecalcBeamTiming(beam, IsInitial)
	if not beam then
		return
	end

	local BaseFire = beam.baseFireDuration or DEFAULT_FIRE_DURATION
	local BaseCharge = beam.baseChargeDuration or DEFAULT_CHARGE_DURATION
	local BaseMin = beam.baseCooldownMin or 4.2
	local BaseMax = beam.baseCooldownMax or (BaseMin + 3.4)

	local OldFire = beam.fireDuration or BaseFire
	local OldCharge = beam.chargeDuration or BaseCharge
	local OldCooldownDuration = beam.cooldownDuration or (beam.fireCooldown or BaseMin)
	local RemainingCooldown = beam.fireCooldown

	local NewFire = ApplyDurationModifiers(BaseFire, Lasers.FireDurationMult, Lasers.FireDurationFlat, 0.1)
	local NewCharge = ApplyDurationModifiers(BaseCharge, Lasers.ChargeDurationMult, Lasers.ChargeDurationFlat, 0.05)
	local NewMin, NewMax = ComputeCooldownBounds(BaseMin, BaseMax)

	beam.fireDuration = NewFire
	beam.chargeDuration = NewCharge
	beam.fireCooldownMin = NewMin
	beam.fireCooldownMax = NewMax

	local roll = beam.cooldownRoll
	if roll == nil or IsInitial then
		roll = love.math.random()
		beam.cooldownRoll = roll
	end

	local duration = NewMin + (NewMax - NewMin) * roll
	duration = math.max(NewMin, duration)

	beam.cooldownDuration = duration

	if IsInitial then
		beam.fireCooldown = duration
		beam.fireTimer = nil
		beam.chargeTimer = nil
		return
	end

	if beam.state == "firing" and beam.fireTimer then
		local progress = 0
		if OldFire and OldFire > 0 then
			progress = clamp(1 - (beam.fireTimer / OldFire), 0, 1)
		end
		beam.fireTimer = NewFire * (1 - progress)
	elseif beam.fireTimer and beam.fireTimer > NewFire then
		beam.fireTimer = NewFire
	end

	if beam.state == "charging" and beam.chargeTimer then
		local progress = 0
		if OldCharge and OldCharge > 0 then
			progress = clamp(1 - (beam.chargeTimer / OldCharge), 0, 1)
		end
		beam.chargeTimer = NewCharge * (1 - progress)
	elseif beam.chargeTimer and beam.chargeTimer > NewCharge then
		beam.chargeTimer = NewCharge
	end

	if RemainingCooldown then
		local progress = 0
		if OldCooldownDuration and OldCooldownDuration > 0 then
			progress = clamp(1 - (RemainingCooldown / OldCooldownDuration), 0, 1)
		end
		beam.fireCooldown = duration * (1 - progress)
	end
end

local function ComputeBeamTarget(beam)
	local TileSize = Arena.TileSize or 24
	local facing = beam.facing or 1
	local inset = math.max(2, TileSize * 0.5 - 4)
	local StartX = beam.x or 0
	local StartY = beam.y or 0
	local EndX, EndY
	local rocks = Rocks:GetAll() or {}
	local BestDistance = math.huge
	local HitRock

	if beam.dir == "horizontal" then
		StartX = StartX + facing * inset
		EndY = StartY

		local WallX
		if facing > 0 then
			WallX = (Arena.x or 0) + (Arena.width or 0) - WALL_INSET
		else
			WallX = (Arena.x or 0) + WALL_INSET
		end

		EndX = WallX

		for _, rock in ipairs(rocks) do
			if rock.row == beam.row then
				local delta = (rock.x - (beam.x or 0)) * facing
				if delta and delta > 0 and delta < BestDistance then
					BestDistance = delta
					HitRock = rock
				end
			end
		end

		if HitRock then
			local edge = TileSize * 0.5 - 2
			EndX = HitRock.x - facing * edge
		end
	else
		StartY = StartY + facing * inset
		EndX = StartX

		local WallY
		if facing > 0 then
			WallY = (Arena.y or 0) + (Arena.height or 0) - WALL_INSET
		else
			WallY = (Arena.y or 0) + WALL_INSET
		end

		EndY = WallY

		for _, rock in ipairs(rocks) do
			if rock.col == beam.col then
				local delta = (rock.y - (beam.y or 0)) * facing
				if delta and delta > 0 and delta < BestDistance then
					BestDistance = delta
					HitRock = rock
				end
			end
		end

		if HitRock then
			local edge = TileSize * 0.5 - 2
			EndY = HitRock.y - facing * edge
		end
	end

	if beam.dir == "horizontal" then
		local MinX = math.min(StartX, EndX)
		local width = math.max(0, math.abs(EndX - StartX))
		local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
		beam.beamRect = {MinX, StartY - thickness * 0.5, width, thickness}
	else
		local MinY = math.min(StartY, EndY)
		local height = math.max(0, math.abs(EndY - StartY))
		local thickness = beam.beamThickness or DEFAULT_BEAM_THICKNESS
		beam.beamRect = {StartX - thickness * 0.5, MinY, thickness, height}
	end

	beam.beamStartX = StartX
	beam.beamStartY = StartY
	beam.beamEndX = EndX
	beam.beamEndY = EndY or StartY
	beam.impactX = EndX
	beam.impactY = EndY or StartY
	beam.targetRock = HitRock
end

function Lasers:ReflectBeam(beam, options)
	if not LASERS_ENABLED then
		return nil
	end

	if not beam then
		return nil
	end

	options = options or {}

	local facing = beam.facing or 1
	beam.facing = -(facing >= 0 and 1 or -1)

	ComputeBeamTarget(beam)

	local BaseCharge = beam.chargeDuration or beam.baseChargeDuration or DEFAULT_CHARGE_DURATION
	local factor = options.chargeFactor or 0.45
	if factor < 0.05 then
		factor = 0.05
	elseif factor > 1 then
		factor = 1
	end

	local ChargeTime = math.max(0.12, BaseCharge * factor)

	beam.state = "charging"
	beam.chargeTimer = ChargeTime
	beam.fireTimer = nil
	beam.fireCooldown = nil
	beam.cooldownRoll = love.math.random()
	beam.cooldownDuration = ChargeTime
	beam.telegraphStrength = 0
	beam.flashTimer = math.max(beam.flashTimer or 0, 0.9)
	beam.burnAlpha = 0.92

	return ChargeTime
end

function Lasers:reset()
	for _, beam in ipairs(emitters) do
		ReleaseOccupancy(beam)
	end
	emitters = {}

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

	local col, row = Arena:GetTileFromWorld(x, y)
	local facing = options.facing
	if facing == nil then
		facing = GetFacingFromPosition(dir, col, row)
	end

	facing = (facing >= 0) and 1 or -1

	local beam = {
		x = x,
		y = y,
		col = col,
		row = row,
		dir = dir,
		facing = facing,
		BeamThickness = options.beamThickness or DEFAULT_BEAM_THICKNESS,
		FirePalette = options.firePalette or GetFirePalette(options.fireColor),
		state = "cooldown",
		FlashTimer = 0,
		BurnAlpha = 0,
		BaseGlow = 0,
		TelegraphStrength = 0,
		RandomOffset = love.math.random() * math.pi * 2,
	}

	beam.baseFireDuration = math.max(0.2, options.fireDuration or DEFAULT_FIRE_DURATION)
	beam.baseChargeDuration = math.max(0.25, options.chargeDuration or DEFAULT_CHARGE_DURATION)
	beam.baseCooldownMin = options.fireCooldownMin or 4.2
	beam.baseCooldownMax = options.fireCooldownMax or (beam.baseCooldownMin + 3.4)
	if beam.baseCooldownMax < beam.baseCooldownMin then
		beam.baseCooldownMax = beam.baseCooldownMin
	end

	RecalcBeamTiming(beam, true)

	SnakeUtils.SetOccupied(col, row, true)

	ComputeBeamTarget(beam)
        emitters[#emitters + 1] = beam
        return beam
end

function Lasers:GetEmitters()
        local copies = {}
        for index, beam in ipairs(emitters) do
                copies[index] = beam
        end
        return copies
end

function Lasers:update(dt)
        if not LASERS_ENABLED then
                return
        end

	if dt <= 0 then
		return
	end

	for _, beam in ipairs(emitters) do
		ComputeBeamTarget(beam)

		if beam.state == "charging" then
			beam.chargeTimer = (beam.chargeTimer or beam.chargeDuration) - dt
			if beam.chargeTimer <= 0 then
				beam.state = "firing"
				beam.fireTimer = beam.fireDuration
				beam.chargeTimer = nil
				beam.flashTimer = math.max(beam.flashTimer or 0, 0.75)
				beam.burnAlpha = 0.92
				Audio:PlaySound("laser_fire")
			end
		elseif beam.state == "firing" then
			beam.fireTimer = (beam.fireTimer or beam.fireDuration) - dt
			beam.burnAlpha = 0.92
			if beam.fireTimer <= 0 then
				beam.state = "cooldown"
				beam.cooldownRoll = love.math.random()
				local MinCooldown = beam.fireCooldownMin or 0
				local MaxCooldown = beam.fireCooldownMax or MinCooldown
				if MaxCooldown < MinCooldown then
					MaxCooldown = MinCooldown
				end
				local duration = MinCooldown + (MaxCooldown - MinCooldown) * (beam.cooldownRoll or 0)
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

		local TargetGlow = 0
		local TelegraphStrength = beam.telegraphStrength or 0
		if beam.state == "charging" then
			local duration = math.max(beam.chargeDuration or 0, 0.01)
			local timer = clamp(beam.chargeTimer or duration, 0, duration)
			local progress = 1 - (timer / duration)
			progress = clamp(progress, 0, 1)
			TelegraphStrength = progress * progress
			TargetGlow = TelegraphStrength
		else
			TelegraphStrength = math.max(0, TelegraphStrength - dt * 3.6)
			TargetGlow = 0
		end
		beam.telegraphStrength = TelegraphStrength

		local glow = beam.baseGlow or 0
		local GlowApproach = dt * 3.2
		if glow < TargetGlow then
			glow = math.min(TargetGlow, glow + GlowApproach)
		else
			glow = math.max(TargetGlow, glow - GlowApproach * 0.75)
		end
		beam.baseGlow = glow

		if beam.state ~= "firing" then
			beam.burnAlpha = math.max(0, (beam.burnAlpha or 0) - dt * BURN_FADE_RATE)
		end

		if beam.flashTimer and beam.flashTimer > 0 then
			beam.flashTimer = math.max(0, beam.flashTimer - dt * FLASH_DECAY)
		end
	end
end

function Lasers:OnShieldedHit(beam, HitX, HitY)
	if not LASERS_ENABLED then
		return
	end

	if not beam then
		return
	end

	beam.flashTimer = math.max(beam.flashTimer or 0, 1)

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		Upgrades:notify("LaserShielded", {
			beam = beam,
			x = HitX,
			y = HitY,
			EmitterX = beam.x,
			EmitterY = beam.y,
			ImpactX = beam.impactX,
			ImpactY = beam.impactY,
		})
	end
end

local function RectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function BaseBounds(beam)
	if not beam then
		return
	end

	local size = Arena.TileSize or 24
	local half = size * 0.5
	local margin = math.max(2, size * 0.22)
	if margin > half then
		margin = half
	end

	local width = size - margin * 2
	local height = width
	local bx = (beam.x or 0) - width * 0.5
	local by = (beam.y or 0) - height * 0.5
	return bx, by, width, height
end

function Lasers:ApplyTimingModifiers()
	if not LASERS_ENABLED then
		return
	end

	for _, beam in ipairs(emitters) do
		RecalcBeamTiming(beam, false)
	end
end

function Lasers:CheckCollision(x, y, w, h)
	if not LASERS_ENABLED then
		return nil
	end

	if not (x and y and w and h) then
		return nil
	end

	for _, beam in ipairs(emitters) do
		local bx, by, bw, bh = BaseBounds(beam)
		if bx and RectsOverlap(bx, by, bw, bh, x, y, w, h) then
			beam.flashTimer = math.max(beam.flashTimer or 0, 1)
			return beam
		end

		if beam.state == "firing" and beam.beamRect then
			local rx, ry, rw, rh = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
			if rw and rh and rw > 0 and rh > 0 and RectsOverlap(rx, ry, rw, rh, x, y, w, h) then
				beam.flashTimer = math.max(beam.flashTimer or 0, 1)
				return beam
			end
		end
	end

	return nil
end

local function DrawBurnMark(beam)
	if not (beam and beam.impactX and beam.impactY) then
		return
	end

	local alpha = clamp(beam.burnAlpha or 0, 0, 1)
	if alpha <= 0 then
		return
	end

	local radius = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8)
	love.graphics.setColor(0, 0, 0, 0.5 * alpha)
	love.graphics.circle("fill", beam.impactX, beam.impactY, radius)
	love.graphics.setColor(0.1, 0.05, 0.05, 0.7 * alpha)
	love.graphics.circle("fill", beam.impactX, beam.impactY, radius * 0.55)
	love.graphics.setColor(0.95, 0.25, 0.2, 0.18 * alpha)
	love.graphics.circle("line", beam.impactX, beam.impactY, radius * 0.9)
end

local function DrawBeam(beam)
	if not beam.beamRect then
		return
	end

	local palette = beam.firePalette or GetFirePalette(DEFAULT_FIRE_COLOR)
	local x, y, w, h = beam.beamRect[1], beam.beamRect[2], beam.beamRect[3], beam.beamRect[4]
	if not (x and y and w and h) then
		return
	end

	local t = GetTime()
	local FacingSign = beam.facing or 1

	if beam.state == "firing" then
		local flicker = 0.82 + 0.18 * math.sin(t * 11 + (beam.beamStartX or 0) * 0.05 + (beam.beamStartY or 0) * 0.05)
		local GlowAlpha = (palette.glow[4] or 0.5) * flicker
		love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], GlowAlpha)
		love.graphics.rectangle("fill", x - BEAM_GLOW_EXPANSION, y - BEAM_GLOW_EXPANSION, w + BEAM_GLOW_EXPANSION * 2, h + BEAM_GLOW_EXPANSION * 2, 7, 7)

		local InnerGlowAlpha = math.min(1, (palette.core[4] or 0.9) * (0.85 + 0.15 * flicker))
		love.graphics.setColor(palette.core[1], palette.core[2], palette.core[3], InnerGlowAlpha)
		love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 6, 6)

		local rim = palette.rim or palette.core
		love.graphics.setColor(rim[1], rim[2], rim[3], (rim[4] or 1))
		love.graphics.rectangle("fill", x, y, w, h, 4, 4)

		local HighlightThickness = math.max(1.5, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.35)
		love.graphics.setColor(1, 0.97, 0.75, 0.55)
		if beam.dir == "horizontal" then
			local CenterY = y + h * 0.5
			love.graphics.rectangle("fill", x, CenterY - HighlightThickness * 0.5, w, HighlightThickness, 3, 3)
		else
			local CenterX = x + w * 0.5
			love.graphics.rectangle("fill", CenterX - HighlightThickness * 0.5, y, HighlightThickness, h, 3, 3)
		end

		local EdgeThickness = math.max(1, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.22)
		love.graphics.setColor(1, 0.65, 0.45, 0.35 + 0.25 * flicker)
		if beam.dir == "horizontal" then
			love.graphics.rectangle("fill", x, y + h - EdgeThickness, w, EdgeThickness, 3, 3)
			love.graphics.rectangle("fill", x, y, w, EdgeThickness, 3, 3)
		else
			love.graphics.rectangle("fill", x + w - EdgeThickness, y, EdgeThickness, h, 3, 3)
			love.graphics.rectangle("fill", x, y, EdgeThickness, h, 3, 3)
		end

		local length = (beam.dir == "horizontal") and w or h
		local PulseSpacing = math.max(24, length / 6)
		local PulseSize = PulseSpacing * 0.55
		local travel = (t * BEAM_PULSE_SPEED * 45 * FacingSign) % PulseSpacing
		love.graphics.setColor(1, 0.8, 0.45, 0.25 + 0.35 * flicker)
		if beam.dir == "horizontal" then
			for start = -travel, w, PulseSpacing do
				local SegmentStart = math.max(0, start)
				local SegmentEnd = math.min(w, start + PulseSize)
				if SegmentEnd > SegmentStart then
					love.graphics.rectangle("fill", x + SegmentStart, y + h * 0.15, SegmentEnd - SegmentStart, h * 0.7, 3, 3)
				end
			end

			local SparkCount = math.max(2, math.floor(w / 96))
			love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
			for i = 0, SparkCount do
				local offset = (i / math.max(1, SparkCount)) * w
				local sway = math.sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (h * 0.12)
				local SparkWidth = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
				love.graphics.rectangle("fill", x + offset - SparkWidth * 0.5, y + h * 0.5 + sway - EdgeThickness, SparkWidth, EdgeThickness * 2, 3, 3)
			end
		else
			for start = -travel, h, PulseSpacing do
				local SegmentStart = math.max(0, start)
				local SegmentEnd = math.min(h, start + PulseSize)
				if SegmentEnd > SegmentStart then
					love.graphics.rectangle("fill", x + w * 0.15, y + SegmentStart, w * 0.7, SegmentEnd - SegmentStart, 3, 3)
				end
			end

			local SparkCount = math.max(2, math.floor(h / 96))
			love.graphics.setColor(1, 0.92, 0.75, 0.4 + 0.35 * flicker)
			for i = 0, SparkCount do
				local offset = (i / math.max(1, SparkCount)) * h
				local sway = math.sin(t * 6 + offset * 0.04 + (beam.randomOffset or 0)) * (w * 0.12)
				local SparkHeight = math.max(3, (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.4)
				love.graphics.rectangle("fill", x + w * 0.5 + sway - EdgeThickness, y + offset - SparkHeight * 0.5, EdgeThickness * 2, SparkHeight, 3, 3)
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
			local BandHeight = math.max(1.2, h * 0.25)
			love.graphics.rectangle("fill", x, y + h * 0.5 - BandHeight * 0.5, w, BandHeight, 2, 2)
		else
			local BandWidth = math.max(1.2, w * 0.25)
			love.graphics.rectangle("fill", x + w * 0.5 - BandWidth * 0.5, y, BandWidth, h, 2, 2)
		end

		local stripes = 4
		local rim = palette.rim or palette.core
		for i = 0, stripes - 1 do
			local offset = (progress + i / stripes) % 1
			local StripeAlpha = math.max(0, (0.55 - i * 0.08) * (0.35 + progress * 0.65))
			if beam.dir == "horizontal" then
				local StripeX = x + (w - 6) * offset
				love.graphics.setColor(rim[1], rim[2], rim[3], StripeAlpha)
				love.graphics.rectangle("fill", StripeX, y + 1, 6, h - 2, 2, 2)
			else
				local StripeY = y + (h - 6) * offset
				love.graphics.setColor(rim[1], rim[2], rim[3], StripeAlpha)
				love.graphics.rectangle("fill", x + 1, StripeY, w - 2, 6, 2, 2)
			end
		end

		local resonance = math.sin(t * 4 + (beam.randomOffset or 0)) * 0.5 + 0.5
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

local function DrawImpactEffect(beam)
	if beam.state ~= "firing" then
		return
	end

	if not (beam.impactX and beam.impactY) then
		return
	end

	local palette = beam.firePalette or GetFirePalette(DEFAULT_FIRE_COLOR)
	local core = palette.core or DEFAULT_FIRE_COLOR
	local rim = palette.rim or core
	local t = GetTime()
	local offset = beam.randomOffset or 0
	local flicker = 0.75 + 0.25 * math.sin(t * 10 + offset)
	local BaseRadius = (beam.beamThickness or DEFAULT_BEAM_THICKNESS) * 0.8

	love.graphics.setColor(core[1], core[2], core[3], 0.35 + 0.4 * flicker)
	love.graphics.circle("fill", beam.impactX, beam.impactY, BaseRadius + math.sin(t * 8 + offset) * 1.5)

	local pulse = math.fmod(t * IMPACT_RING_SPEED + offset, 1)
	if pulse < 0 then
		pulse = pulse + 1
	end

	local PulseRadius = IMPACT_FLARE_RADIUS + pulse * IMPACT_RING_RANGE
	local PulseAlpha = math.max(0, 0.55 * (1 - pulse))
	love.graphics.setColor(rim[1], rim[2], rim[3], PulseAlpha)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", beam.impactX, beam.impactY, PulseRadius)

	love.graphics.setColor(1, 0.95, 0.75, 0.45 * flicker)
	local SparkLength = IMPACT_FLARE_RADIUS * 1.3
	local spokes = 6
	for i = 0, spokes - 1 do
		local angle = offset + (i / spokes) * (math.pi * 2)
		local dx = math.cos(angle) * SparkLength
		local dy = math.sin(angle) * SparkLength
		love.graphics.line(beam.impactX - dx * 0.35, beam.impactY - dy * 0.35, beam.impactX + dx, beam.impactY + dy)
	end
end

local function DrawEmitterBase(beam)
	local BaseColor, AccentColor = GetEmitterColors()
	local TileSize = Arena.TileSize or 24
	local half = TileSize * 0.5
	local bx = (beam.x or 0) - half
	local by = (beam.y or 0) - half
	local flash = clamp(beam.flashTimer or 0, 0, 1)
	local telegraph = clamp(beam.telegraphStrength or 0, 0, 1)
	local BaseGlow = clamp(beam.baseGlow or 0, 0, 1)
	local HighlightBoost = (beam.state == "firing") and 0.28 or 0
	HighlightBoost = HighlightBoost + telegraph * 0.4

	local t = GetTime()
	local PulseStrength = telegraph > 0 and (telegraph * (0.6 + telegraph * 0.4)) or 0
	local pulse = 0
	if PulseStrength > 0 then
		pulse = (0.18 + 0.25 * math.sin(t * 5.5 + (beam.x or 0) * 0.03 + (beam.y or 0) * 0.03)) * PulseStrength
	end
	local ShowPrimeRing = (telegraph > 0) or (beam.state == "firing")
	if ShowPrimeRing then
		local GlowAlpha = 0.16 + BaseGlow * 0.6 + flash * 0.35 + HighlightBoost * 0.35 + pulse * 0.4
		love.graphics.setColor(1, 0.32, 0.25, math.min(0.85, GlowAlpha))
		local GlowRadius = BASE_GLOW_RADIUS + TileSize * 0.1 + BaseGlow * (TileSize * 0.22)
		love.graphics.circle("fill", beam.x or 0, beam.y or 0, GlowRadius)
	end

	love.graphics.setColor(BaseColor[1], BaseColor[2], BaseColor[3], (BaseColor[4] or 1) + flash * 0.1)
	love.graphics.rectangle("fill", bx, by, TileSize, TileSize, 6, 6)

	love.graphics.setColor(0, 0, 0, 0.45 + flash * 0.25 + telegraph * 0.15)
	love.graphics.rectangle("line", bx, by, TileSize, TileSize, 6, 6)

	local AccentAlpha = (AccentColor[4] or 0.8) + flash * 0.2 + HighlightBoost
	love.graphics.setColor(AccentColor[1], AccentColor[2], AccentColor[3], math.min(1, AccentAlpha))
	love.graphics.rectangle("line", bx + 2, by + 2, TileSize - 4, TileSize - 4, 4, 4)

	love.graphics.setColor(1, 1, 1, 0.16 + HighlightBoost * 0.45 + flash * 0.2 + telegraph * 0.25)
	local HighlightWidth = math.min(TileSize * 0.45, TileSize - 6)
	love.graphics.rectangle("fill", bx + 3, by + 3, HighlightWidth, TileSize * 0.2, 3, 3)

	local SlitLength = TileSize * 0.55
	local SlitThickness = math.max(3, TileSize * 0.18)
	local cx = beam.x or 0
	local cy = beam.y or 0
	if ShowPrimeRing then
		local spin = (t * 2.5 + (beam.randomOffset or 0)) % (math.pi * 2)
		local RingRadius = TileSize * 0.45 + math.sin(t * 3.5 + (beam.randomOffset or 0)) * (TileSize * 0.05)
		love.graphics.setLineWidth(2)
		love.graphics.setColor(AccentColor[1], AccentColor[2], AccentColor[3], 0.28 + flash * 0.4 + HighlightBoost * 0.35 + telegraph * 0.25)
		for i = 0, 2 do
			local angle = spin + i * (math.pi * 2 / 3)
			love.graphics.arc("line", "open", cx, cy, RingRadius, angle - 0.35, angle + 0.35, 16)
		end

		if beam.state == "charging" then
			local ChargeLift = (math.sin(t * 6 + (beam.randomOffset or 0)) * 0.5 + 0.5) * TileSize * 0.08
			love.graphics.setColor(1, 0.4, 0.32, 0.35 + flash * 0.35 + telegraph * 0.55)
			love.graphics.circle("line", cx, cy, RingRadius * 0.65 + ChargeLift)
		elseif beam.state == "firing" then
			love.graphics.setColor(1, 0.55, 0.4, 0.35 + flash * 0.45 + telegraph * 0.25)
			love.graphics.circle("line", cx, cy, RingRadius * 0.8)
		end
	end
	if beam.dir == "horizontal" then
		local dir = beam.facing or 1
		local front = cx + dir * (TileSize * 0.32)
		love.graphics.rectangle("fill", front - SlitThickness * 0.5, cy - SlitLength * 0.5, SlitThickness, SlitLength, 3, 3)
	else
		local dir = beam.facing or 1
		local front = cy + dir * (TileSize * 0.32)
		love.graphics.rectangle("fill", cx - SlitLength * 0.5, front - SlitThickness * 0.5, SlitLength, SlitThickness, 3, 3)
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
		DrawBurnMark(beam)
	end

	for _, beam in ipairs(emitters) do
		DrawBeam(beam)
	end

	for _, beam in ipairs(emitters) do
		DrawImpactEffect(beam)
	end

	for _, beam in ipairs(emitters) do
		DrawEmitterBase(beam)
	end

	love.graphics.pop()
end

return Lasers
