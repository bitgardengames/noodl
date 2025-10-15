local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Audio = require("audio")
local Particles = require("particles")

local Darts = {}

local DARTS_ENABLED = false

local launchers = {}

function Darts:IsEnabled()
	return DARTS_ENABLED
end

local DEFAULT_TELEGRAPH_DURATION = 1.15
local DEFAULT_COOLDOWN_MIN = 4.0
local DEFAULT_COOLDOWN_MAX = 5.8
local DEFAULT_FIRE_SPEED = 460
local DEFAULT_DART_LENGTH = 32
local DART_THICKNESS = 8
local HOLE_RADIUS = 10
local TELEGRAPH_PULSE_SPEED = 6.4
local IMPACT_RING_LIFE = 0.32

local function GetTime()
	return love.timer.getTime()
end

local function clamp01(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function GetLauncherColors()
	local body = Theme.LaserBaseColor or {0.18, 0.19, 0.24, 0.95}
	local accent = Theme.LaserColor or {1, 0.32, 0.26, 1}
	return body, accent
end

local function GetDartColors(accent)
	local shaft = Theme.DartShaftColor or {0.82, 0.84, 0.88, 1}
	local highlight = Theme.DartHighlightColor or {1, 1, 1, 0.65}
	local fletching = Theme.DartFletchingColor or {0.24, 0.26, 0.32, 0.95}
	local tip = Theme.DartTipColor or {accent[1], accent[2], accent[3], 1}
	return shaft, highlight, fletching, tip
end

local function GetArenaLimits(dir, facing)
	local ax, ay, aw, ah = Arena:GetBounds()
	local inset = (Arena.TileSize or 24) * 0.5
	local left = ax + inset
	local right = ax + aw - inset
	local top = ay + inset
	local bottom = ay + ah - inset

	if dir == "horizontal" then
		if facing >= 0 then
			return left, right - 4
		else
			return right, left + 4
		end
	else
		if facing >= 0 then
			return top, bottom - 4
		else
			return bottom, top + 4
		end
	end
end

local function GetHolePosition(dir, facing, x, y)
	local TileSize = Arena.TileSize or 24
	local offset = TileSize * 0.5 + 6
	if dir == "horizontal" then
		return x - facing * offset, y
	else
		return x, y - facing * offset
	end
end

local function UpdateImpact(launcher, dt)
	local impact = launcher and launcher.impact
	if not impact then
		return
	end

	impact.timer = impact.timer - dt
	if impact.timer <= 0 then
		launcher.impact = nil
	end
end

local function ScheduleCooldown(launcher)
	local MinCooldown = launcher.cooldownMin or DEFAULT_COOLDOWN_MIN
	local MaxCooldown = launcher.cooldownMax or DEFAULT_COOLDOWN_MAX
	if MaxCooldown < MinCooldown then
		MaxCooldown = MinCooldown
	end

	local roll = love.math.random()
	launcher.cooldownTimer = MinCooldown + (MaxCooldown - MinCooldown) * roll
	launcher.state = "cooldown"
	launcher.telegraphProgress = 0
end

local function SpawnImpactFX(x, y, DirX, DirY)
	local _, accent = GetLauncherColors()
	local NormalX = DirX or 0
	local NormalY = DirY or 0

	Particles:SpawnBurst(x, y, {
		count = love.math.random(4, 6),
		speed = 110,
		SpeedVariance = 40,
		life = 0.32,
		size = 3.2,
		color = {accent[1], accent[2], accent[3], 1},
		spread = math.pi * 0.6,
		angle = math.atan2(NormalY, NormalX),
		AngleJitter = math.pi * 0.25,
		drag = 2.6,
		gravity = 160,
		ScaleMin = 0.48,
		ScaleVariance = 0.4,
		FadeTo = 0,
	})

	Particles:SpawnBurst(x, y, {
		count = love.math.random(4, 6),
		speed = 60,
		SpeedVariance = 28,
		life = 0.38,
		size = 2.0,
		color = {1, 0.92, 0.72, 0.6},
		spread = math.pi * 2,
		AngleJitter = math.pi,
		drag = 3.4,
		gravity = 0,
		ScaleMin = 0.32,
		ScaleVariance = 0.4,
		FadeTo = 0,
	})
end

local function TriggerImpact(launcher, HitX, HitY)
	if not launcher then
		return
	end

	local projectile = launcher.projectile
	if projectile then
		launcher.impact = {
			x = HitX or projectile.tipX,
			y = HitY or projectile.tipY,
			DirX = projectile.dirX,
			DirY = projectile.dirY,
			timer = IMPACT_RING_LIFE,
			life = IMPACT_RING_LIFE,
		}
	end

	SpawnImpactFX(HitX or launcher.x, HitY or launcher.y, launcher.dirX, launcher.dirY)
	Audio:PlaySound("shield_saw")
	launcher.projectile = nil
	ScheduleCooldown(launcher)
end

local function JamLauncher(launcher, duration)
	if not (launcher and duration and duration > 0) then
		return
	end

	if launcher.state == "firing" then
		local projectile = launcher.projectile
		TriggerImpact(launcher, projectile and projectile.tipX, projectile and projectile.tipY)
	end

	if launcher.state == "telegraph" then
		launcher.telegraphTimer = (launcher.telegraphTimer or 0) + duration
	elseif launcher.state == "cooldown" then
		launcher.cooldownTimer = (launcher.cooldownTimer or 0) + duration
	else
		if launcher.cooldownTimer then
			launcher.cooldownTimer = launcher.cooldownTimer + duration
		end
	end
end

local function GetRockCollision(projectile, NewTipX, NewTipY)
	local rocks = Rocks:GetAll()
	if not (rocks and #rocks > 0) then
		return nil
	end

	local BestDistance
	local hit
	local DirX, DirY = projectile.dirX, projectile.dirY
	local PrevX, PrevY = projectile.tipX, projectile.tipY

	for _, rock in ipairs(rocks) do
		local width = rock.w or 24
		local height = rock.h or 24
		local OffsetY = rock.offsetY or 0
		local ScaleX = rock.scaleX or 1
		local ScaleY = rock.scaleY or 1

		local HalfW = (width * ScaleX) * 0.5
		local HalfH = (height * ScaleY) * 0.5
		local left = (rock.x or 0) - HalfW
		local right = left + width * ScaleX
		local top = (rock.y or 0) + OffsetY - HalfH
		local bottom = top + height * ScaleY

		if DirX ~= 0 then
			local y = NewTipY
			if y >= top and y <= bottom then
				if DirX > 0 then
					if PrevX <= left and NewTipX >= left then
						local distance = left - projectile.originX
						if not BestDistance or distance < BestDistance then
							BestDistance = distance
							hit = { x = left, y = y }
						end
					end
				else
					if PrevX >= right and NewTipX <= right then
						local distance = projectile.originX - right
						if not BestDistance or distance < BestDistance then
							BestDistance = distance
							hit = { x = right, y = y }
						end
					end
				end
			end
		else
			local x = NewTipX
			if x >= left and x <= right then
				if DirY > 0 then
					if PrevY <= top and NewTipY >= top then
						local distance = top - projectile.originY
						if not BestDistance or distance < BestDistance then
							BestDistance = distance
							hit = { x = x, y = top }
						end
					end
				else
					if PrevY >= bottom and NewTipY <= bottom then
						local distance = projectile.originY - bottom
						if not BestDistance or distance < BestDistance then
							BestDistance = distance
							hit = { x = x, y = bottom }
						end
					end
				end
			end
		end
	end

	return hit
end

local function UpdateProjectile(launcher, dt)
	local projectile = launcher.projectile
	if not projectile then
		return
	end

	local speed = projectile.speed or DEFAULT_FIRE_SPEED
	local DirX, DirY = projectile.dirX, projectile.dirY
	local travel = speed * dt

	projectile.prevTipX = projectile.tipX
	projectile.prevTipY = projectile.tipY

	local NewTipX = projectile.tipX + DirX * travel
	local NewTipY = projectile.tipY + DirY * travel

	if DirX ~= 0 then
		if (DirX > 0 and NewTipX > projectile.limit) or (DirX < 0 and NewTipX < projectile.limit) then
			NewTipX = projectile.limit
		end
	else
		if (DirY > 0 and NewTipY > projectile.limit) or (DirY < 0 and NewTipY < projectile.limit) then
			NewTipY = projectile.limit
		end
	end

	local collision = GetRockCollision(projectile, NewTipX, NewTipY)
	if collision then
		NewTipX = collision.x
		NewTipY = collision.y
	end

	projectile.tipX = NewTipX
	projectile.tipY = NewTipY
	projectile.baseX = NewTipX - DirX * projectile.length
	projectile.baseY = NewTipY - DirY * projectile.length

	if (DirX ~= 0 and NewTipX == projectile.limit) or (DirY ~= 0 and NewTipY == projectile.limit) or collision then
		TriggerImpact(launcher, NewTipX, NewTipY)
	end
end

local function AdvanceLauncher(launcher, dt)
	if launcher.state == "cooldown" then
		launcher.cooldownTimer = (launcher.cooldownTimer or 0) - dt
		if launcher.cooldownTimer <= 0 then
			launcher.telegraphTimer = launcher.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
			launcher.state = "telegraph"
			launcher.cooldownTimer = nil
		end
	elseif launcher.state == "telegraph" then
		launcher.telegraphTimer = (launcher.telegraphTimer or 0) - dt
		local duration = launcher.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
		local progress = 1 - (launcher.telegraphTimer or 0) / duration
		launcher.telegraphProgress = clamp01(progress)

		if launcher.telegraphTimer <= 0 then
			launcher.projectile = {
				TipX = launcher.startX,
				TipY = launcher.startY,
				PrevTipX = launcher.startX,
				PrevTipY = launcher.startY,
				BaseX = launcher.startX - launcher.dirX * launcher.dartLength,
				BaseY = launcher.startY - launcher.dirY * launcher.dartLength,
				DirX = launcher.dirX,
				DirY = launcher.dirY,
				speed = launcher.fireSpeed or DEFAULT_FIRE_SPEED,
				length = launcher.dartLength,
				limit = launcher.travelLimit,
				OriginX = launcher.startX,
				OriginY = launcher.startY,
			}
			launcher.state = "firing"
			launcher.telegraphProgress = 1
			Audio:PlaySound("laser_fire")
		end
	elseif launcher.state == "firing" then
		UpdateProjectile(launcher, dt)
	end

	UpdateImpact(launcher, dt)
end

function Darts:reset()
	for _, launcher in ipairs(launchers) do
		if launcher.col and launcher.row then
			SnakeUtils.SetOccupied(launcher.col, launcher.row, false)
		end
	end

	launchers = {}

	if not DARTS_ENABLED then
		return
	end
end

function Darts:spawn(x, y, dir, options)
	if not DARTS_ENABLED then
		return
	end

	dir = dir or "horizontal"
	options = options or {}

	local col, row = Arena:GetTileFromWorld(x, y)
	local facing = options.facing
	if facing == nil then
		if dir == "horizontal" then
			facing = (col <= math.floor((Arena.cols or 1) / 2)) and 1 or -1
		else
			facing = (row <= math.floor((Arena.rows or 1) / 2)) and 1 or -1
		end
	end

	facing = (facing >= 0) and 1 or -1
	local DirX = (dir == "horizontal") and facing or 0
	local DirY = (dir == "vertical") and facing or 0
	local _, TravelLimit = GetArenaLimits(dir, facing)

	local TileSize = Arena.TileSize or 24
	local StartX = x + DirX * (TileSize * 0.5 - 6)
	local StartY = y + DirY * (TileSize * 0.5 - 6)

	local launcher = {
		x = x,
		y = y,
		col = col,
		row = row,
		dir = dir,
		facing = facing,
		DirX = DirX,
		DirY = DirY,
		StartX = StartX,
		StartY = StartY,
		TravelLimit = TravelLimit,
		TelegraphDuration = options.telegraphDuration or DEFAULT_TELEGRAPH_DURATION,
		FireSpeed = options.fireSpeed or DEFAULT_FIRE_SPEED,
		DartLength = options.dartLength or DEFAULT_DART_LENGTH,
		CooldownMin = options.cooldownMin or DEFAULT_COOLDOWN_MIN,
		CooldownMax = options.cooldownMax or DEFAULT_COOLDOWN_MAX,
		state = "cooldown",
		TelegraphProgress = 0,
		RandomOffset = love.math.random() * math.pi * 2,
	}

	launcher.travelLimit = TravelLimit

	launcher.holeX, launcher.holeY = GetHolePosition(dir, facing, x, y)

	SnakeUtils.SetOccupied(col, row, true)
	ScheduleCooldown(launcher)

	launchers[#launchers + 1] = launcher
	return launcher
end

function Darts:update(dt)
	if not DARTS_ENABLED then
		return
	end

	if dt <= 0 then
		return
	end

	for _, launcher in ipairs(launchers) do
		AdvanceLauncher(launcher, dt)
	end
end

local function DrawTelegraph(launcher, BodyColor, AccentColor)
	local progress = launcher.telegraphProgress or 0
	if progress <= 0 then
		return
	end

	local pulse = 0.35 + 0.25 * math.sin((GetTime() + launcher.randomOffset) * TELEGRAPH_PULSE_SPEED)
	local GlowAlpha = clamp01(progress * 0.9 + pulse * 0.35)

	love.graphics.setColor(AccentColor[1], AccentColor[2], AccentColor[3], GlowAlpha)

	local TipAdvance = 12
	local ShaftLength = 18
	local ShaftThickness = DART_THICKNESS * 0.6

	if launcher.dir == "horizontal" then
		local dir = launcher.dirX >= 0 and 1 or -1
		local TipX = launcher.startX - dir * (1 - progress) * TipAdvance
		local BaseX = TipX - dir * ShaftLength
		local ShaftX = math.min(BaseX, TipX)
		local ShaftW = math.abs(TipX - BaseX)

		love.graphics.rectangle("fill", ShaftX, launcher.y - ShaftThickness * 0.5, ShaftW, ShaftThickness)

		love.graphics.polygon("fill",
			TipX, launcher.y,
			TipX - dir * 8, launcher.y - DART_THICKNESS * 0.8,
			TipX - dir * 8, launcher.y + DART_THICKNESS * 0.8
		)
	else
		local dir = launcher.dirY >= 0 and 1 or -1
		local TipY = launcher.startY - dir * (1 - progress) * TipAdvance
		local BaseY = TipY - dir * ShaftLength
		local ShaftY = math.min(BaseY, TipY)
		local ShaftH = math.abs(TipY - BaseY)

		love.graphics.rectangle("fill", launcher.x - ShaftThickness * 0.5, ShaftY, ShaftThickness, ShaftH)

		love.graphics.polygon("fill",
			launcher.x, TipY,
			launcher.x - DART_THICKNESS * 0.8, TipY - dir * 8,
			launcher.x + DART_THICKNESS * 0.8, TipY - dir * 8
		)
	end

	love.graphics.setColor(1, 1, 1, GlowAlpha * 0.5)
	love.graphics.circle("line", launcher.holeX, launcher.holeY, HOLE_RADIUS * clamp01(progress * 0.75))
	love.graphics.setColor(1, 1, 1, GlowAlpha * 0.35)
	love.graphics.circle("fill", launcher.holeX, launcher.holeY, HOLE_RADIUS * clamp01(progress * 0.4))
end

local function DrawProjectile(launcher, AccentColor)
	local projectile = launcher.projectile
	if not projectile then
		return
	end

	local DirX, DirY = projectile.dirX, projectile.dirY
	local ShaftColor, HighlightColor, FletchingColor, TipColor = GetDartColors(AccentColor)
	local ShaftThickness = DART_THICKNESS * 0.75
	local TipLength = 12
	local FletchingSize = 6

	if DirX ~= 0 then
		local dir = DirX >= 0 and 1 or -1
		local BaseX = projectile.baseX
		local TipX = projectile.tipX
		local ShaftEndX = TipX - dir * TipLength
		if dir > 0 then
			ShaftEndX = math.max(ShaftEndX, BaseX)
		else
			ShaftEndX = math.min(ShaftEndX, BaseX)
		end

		local ShaftX = math.min(BaseX, ShaftEndX)
		local ShaftW = math.abs(ShaftEndX - BaseX)

		love.graphics.setColor(ShaftColor)
		if ShaftW > 0 then
			love.graphics.rectangle("fill", ShaftX, projectile.tipY - ShaftThickness * 0.5, ShaftW, ShaftThickness)

			love.graphics.setColor(HighlightColor)
			love.graphics.rectangle("fill", ShaftX, projectile.tipY - ShaftThickness * 0.5, ShaftW, ShaftThickness * 0.35)
		end

		love.graphics.setColor(FletchingColor)
		local FletchX = BaseX - dir * 2
		love.graphics.polygon("fill",
			FletchX, projectile.tipY,
			FletchX - dir * FletchingSize, projectile.tipY - DART_THICKNESS * 0.9,
			FletchX - dir * FletchingSize, projectile.tipY + DART_THICKNESS * 0.9
		)

		love.graphics.setColor(TipColor)
		love.graphics.polygon("fill",
			TipX + dir * 2, projectile.tipY,
			TipX - dir * TipLength, projectile.tipY - DART_THICKNESS,
			TipX - dir * TipLength, projectile.tipY + DART_THICKNESS
		)
	else
		local top = math.min(projectile.baseY, projectile.tipY)
		local height = math.abs(projectile.tipY - projectile.baseY)
		local dir = DirY >= 0 and 1 or -1
		local BaseY = projectile.baseY
		local TipY = projectile.tipY
		local ShaftEndY = TipY - dir * TipLength
		if dir > 0 then
			ShaftEndY = math.max(ShaftEndY, BaseY)
		else
			ShaftEndY = math.min(ShaftEndY, BaseY)
		end

		local ShaftY = math.min(BaseY, ShaftEndY)
		local ShaftH = math.abs(ShaftEndY - BaseY)

		love.graphics.setColor(ShaftColor)
		if ShaftH > 0 then
			love.graphics.rectangle("fill", projectile.tipX - ShaftThickness * 0.5, ShaftY, ShaftThickness, ShaftH)

			love.graphics.setColor(HighlightColor)
			love.graphics.rectangle("fill", projectile.tipX - ShaftThickness * 0.5, ShaftY, ShaftThickness * 0.35, ShaftH)
		end

		love.graphics.setColor(FletchingColor)
		local FletchY = BaseY - dir * 2
		love.graphics.polygon("fill",
			projectile.tipX, FletchY,
			projectile.tipX - DART_THICKNESS * 0.9, FletchY - dir * FletchingSize,
			projectile.tipX + DART_THICKNESS * 0.9, FletchY - dir * FletchingSize
		)

		love.graphics.setColor(TipColor)
		love.graphics.polygon("fill",
			projectile.tipX, TipY + dir * 2,
			projectile.tipX - DART_THICKNESS, TipY - dir * TipLength,
			projectile.tipX + DART_THICKNESS, TipY - dir * TipLength
		)
	end
end

local function DrawHole(launcher, BodyColor)
	love.graphics.setColor(BodyColor)
	love.graphics.circle("fill", launcher.holeX, launcher.holeY, HOLE_RADIUS)

	love.graphics.setColor(1, 1, 1, 0.15)
	love.graphics.circle("fill", launcher.holeX - launcher.dirX * 2, launcher.holeY - launcher.dirY * 2, HOLE_RADIUS * 0.6)

	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.setLineWidth(3)
	love.graphics.circle("line", launcher.holeX, launcher.holeY, HOLE_RADIUS)
	love.graphics.setLineWidth(1)
end

local function DrawImpact(launcher, AccentColor)
	local impact = launcher.impact
	if not impact then
		return
	end

	local progress = clamp01(impact.timer / (impact.life or IMPACT_RING_LIFE))
	local radius = 6 + (1 - progress) * 12
	love.graphics.setColor(AccentColor[1], AccentColor[2], AccentColor[3], progress * 0.6)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", impact.x, impact.y, radius)
	love.graphics.setLineWidth(1)
end

function Darts:draw()
	if not DARTS_ENABLED then
		return
	end

	local BodyColor, AccentColor = GetLauncherColors()

	for _, launcher in ipairs(launchers) do
		DrawHole(launcher, BodyColor)
		DrawTelegraph(launcher, BodyColor, AccentColor)
		DrawProjectile(launcher, AccentColor)
		DrawImpact(launcher, AccentColor)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function OverlapsProjectile(launcher, x, y, w, h)
	local projectile = launcher.projectile
	if not projectile then
		return false
	end

	local margin = DART_THICKNESS * 0.5
	if projectile.dirX ~= 0 then
		local PrevBase = projectile.prevTipX - projectile.dirX * projectile.length
		local left = math.min(projectile.baseX, projectile.tipX, projectile.prevTipX, PrevBase) - margin
		local right = math.max(projectile.baseX, projectile.tipX, projectile.prevTipX, PrevBase) + margin
		local top = projectile.tipY - margin
		local bottom = projectile.tipY + margin

		return x < right and x + w > left and y < bottom and y + h > top
	else
		local PrevBase = projectile.prevTipY - projectile.dirY * projectile.length
		local top = math.min(projectile.baseY, projectile.tipY, projectile.prevTipY, PrevBase) - margin
		local bottom = math.max(projectile.baseY, projectile.tipY, projectile.prevTipY, PrevBase) + margin
		local left = projectile.tipX - margin
		local right = projectile.tipX + margin

		return x < right and x + w > left and y < bottom and y + h > top
	end
end

function Darts:CheckCollision(x, y, w, h)
	if not DARTS_ENABLED then
		return nil
	end

	for _, launcher in ipairs(launchers) do
		if launcher.state == "firing" and OverlapsProjectile(launcher, x, y, w, h) then
			return {
				launcher = launcher,
				DirX = launcher.dirX,
				DirY = launcher.dirY,
				x = launcher.projectile and launcher.projectile.tipX,
				y = launcher.projectile and launcher.projectile.tipY,
			}
		end
	end

	return nil
end

function Darts:OnShieldedHit(hit, HitX, HitY)
	if not DARTS_ENABLED then
		return
	end

	if not hit then
		return
	end

	local launcher = hit.launcher
	if not launcher then
		return
	end

	TriggerImpact(launcher, HitX or hit.x, HitY or hit.y)
end

function Darts:AddGlobalJam(duration)
	if not duration or duration <= 0 then
		return
	end

	for _, launcher in ipairs(launchers) do
		JamLauncher(launcher, duration)
	end
end

return Darts
