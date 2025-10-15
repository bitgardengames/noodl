local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local SnakeDraw = require("snakedraw")
local Rocks = require("rocks")
local Saws = require("saws")
local UI = require("ui")
local Fruit = require("fruit")
local UpgradeVisuals = require("upgradevisuals")
local Particles = require("particles")
local SessionStats = require("sessionstats")
local Score = require("score")
local SnakeCosmetics = require("snakecosmetics")
local FloatingText = require("floatingtext")

local Snake = {}

local unpack = table.unpack or unpack

local ScreenW, ScreenH
local direction = { x = 1, y = 0 }
local PendingDir = { x = 1, y = 0 }
local trail = {}
local DescendingHole = nil
local SegmentCount = 1
local PopTimer = 0
local IsDead = false
local FruitsSinceLastTurn = 0
local SeveredPieces = {}
local DeveloperAssistEnabled = false

local function AnnounceDeveloperAssistChange(enabled)
	if not (FloatingText and FloatingText.add) then
		return
	end

	local message = enabled and "DEV ASSIST ENABLED" or "DEV ASSIST DISABLED"
	local hx, hy
	if Snake.GetHead then
		hx, hy = Snake:GetHead()
	end
	if not (hx and hy) then
		hx = (ScreenW or 0) * 0.5
		hy = (ScreenH or 0) * 0.45
	end

	hy = (hy or 0) - 80

	local font = UI and UI.fonts and (UI.fonts.prompt or UI.fonts.button)
	local color
	if enabled then
		color = {0.72, 0.94, 1.0, 1}
	else
		color = {1.0, 0.7, 0.68, 1}
	end

	local options = {
		scale = 1.1,
		PopScaleFactor = 1.28,
		PopDuration = 0.28,
		WobbleMagnitude = 0.12,
		glow = {
			color = {color[1], color[2], color[3], 0.45},
			magnitude = 0.35,
			frequency = 3.2,
		},
		shadow = {
			color = {0, 0, 0, 0.65},
			offset = {0, 2},
			blur = 1.5,
		},
	}

	FloatingText:add(message, hx, hy, color, 1.6, nil, font, options)
end

local SEVERED_TAIL_LIFE = 0.9

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
-- distance travelled since last grid snap (in world units)
local MoveProgress = 0
local POP_DURATION = SnakeUtils.POP_DURATION
local SHIELD_FLASH_DURATION = 0.3
local HAZARD_GRACE_DURATION = 0.12 -- brief invulnerability window after surviving certain hazards
local DAMAGE_FLASH_DURATION = 0.45
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
-- movement baseline + modifiers
Snake.BaseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.SpeedMult   = 1.0 -- stackable multiplier (upgrade-friendly)
Snake.CrashShields = 0 -- crash protection: number of hits the snake can absorb
Snake.ExtraGrowth = 0
Snake.ShieldBurst = nil
Snake.ShieldFlashTimer = 0
Snake.StonebreakerStacks = 0
Snake.StoneSkinSawGrace = 0
Snake.dash = nil
Snake.TimeDilation = nil
Snake.HazardGraceTimer = 0
Snake.chronospiral = nil
Snake.AbyssalCatalyst = nil
Snake.PhoenixEcho = nil
Snake.EventHorizon = nil
Snake.stormchaser = nil
Snake.titanblood = nil
Snake.TemporalAnchor = nil
Snake.QuickFangs = nil

local function ResolveTimeDilationScale(ability)
	if ability and ability.active then
		local scale = ability.timeScale or 1
		if not (scale and scale > 0) then
			scale = 0.05
		end
		return scale
	end

	return 1
end

-- getters / mutators (safe API for upgrades)
function Snake:GetSpeed()
	local speed = (self.BaseSpeed or 1) * (self.SpeedMult or 1)
	local scale = ResolveTimeDilationScale(self.TimeDilation)
	if scale ~= 1 then
		speed = speed * scale
	end

	return speed
end

function Snake:AddSpeedMultiplier(mult)
	self.SpeedMult = (self.SpeedMult or 1) * (mult or 1)
end

function Snake:AddCrashShields(n)
	n = n or 1
	local previous = self.CrashShields or 0
	local updated = previous + n
	if updated < 0 then
		updated = 0
	end
	self.CrashShields = updated

	if n ~= 0 then
		UI:SetCrashShields(self.CrashShields)
	end

	if n and n > 0 then
		local HeadX, HeadY = self:GetHead()
		if HeadX and HeadY then
			local extra = math.max(0, math.floor(n - 1))
			UpgradeVisuals:spawn(HeadX, HeadY, {
				color = {0.68, 0.88, 1.0, 1},
				badge = "shield",
				RingCount = math.min(4, 2 + extra),
				OuterRadius = 46 + math.min(18, extra * 6),
				InnerRadius = 14,
				life = 0.78 + math.min(0.3, extra * 0.08),
				BadgeScale = 1 + math.min(0.35, extra * 0.12),
				GlowAlpha = 0.28,
				HaloAlpha = 0.18,
			})
		end
	end
end

function Snake:ConsumeCrashShield()
	if DeveloperAssistEnabled then
		self.ShieldFlashTimer = SHIELD_FLASH_DURATION
		UI:SetCrashShields(self.CrashShields or 0, { silent = true })
		return true
	end

	if (self.CrashShields or 0) > 0 then
		self.CrashShields = self.CrashShields - 1
		self.ShieldFlashTimer = SHIELD_FLASH_DURATION
		UI:SetCrashShields(self.CrashShields)
		local HeadX, HeadY = self:GetHead()
		if HeadX and HeadY then
			UpgradeVisuals:spawn(HeadX, HeadY, {
				color = {1, 0.66, 0.4, 1},
				badge = "shield",
				RingCount = 3,
				OuterRadius = 44,
				InnerRadius = 12,
				life = 0.62,
				BadgeScale = 0.95,
				GlowAlpha = 0.24,
				HaloAlpha = 0.18,
			})
		end
		SessionStats:add("CrashShieldsSaved", 1)
		return true
	end
	return false
end

function Snake:ResetModifiers()
	self.SpeedMult    = 1.0
	self.CrashShields = 0
	self.ExtraGrowth  = 0
	self.ShieldBurst  = nil
	self.ShieldFlashTimer = 0
	self.StonebreakerStacks = 0
	self.StoneSkinSawGrace = 0
	self.dash = nil
        self.TimeDilation = nil
        self.adrenaline = nil
        self.HazardGraceTimer = 0
        self.chronospiral = nil
        self.AbyssalCatalyst = nil
        self.PhoenixEcho = nil
        self.EventHorizon = nil
        self.stormchaser = nil
        self.titanblood = nil
        self.TemporalAnchor = nil
        self.QuickFangs = nil
        UI:SetCrashShields(self.CrashShields or 0, { silent = true, immediate = true })
end

function Snake:SetStonebreakerStacks(count)
        count = count or 0
        if count < 0 then count = 0 end
        self.StonebreakerStacks = count
end

function Snake:SetQuickFangsStacks(count)
        count = math.max(0, math.floor((count or 0) + 0.0001))
        local state = self.QuickFangs
        local previous = state and (state.stacks or 0) or 0

        if count > 0 then
                if not state then
                        state = { intensity = 0, BaseTarget = 0, time = 0, stacks = 0, flash = 0 }
                        self.QuickFangs = state
                end

                state.stacks = count
                state.baseTarget = math.min(0.65, 0.32 + 0.11 * math.min(count, 4))
                state.target = state.baseTarget
                if count > previous then
                        state.intensity = math.max(state.intensity or 0, 0.55)
                        state.flash = math.min(1.0, (state.flash or 0) + 0.7)
                end
        elseif state then
                state.stacks = 0
                state.baseTarget = 0
                state.target = 0
        end

        if self.QuickFangs then
                local data = self.QuickFangs
                if (data.stacks or 0) <= 0 and (data.intensity or 0) <= 0.01 then
                        self.QuickFangs = nil
                end
        end
end

function Snake:SetChronospiralActive(active)
        if active then
                local state = self.chronospiral
                if not state then
                        state = { intensity = 0, target = 1, spin = 0 }
                        self.chronospiral = state
                end
                state.target = 1
                state.active = true
        else
                local state = self.chronospiral
                if state then
                        state.target = 0
                        state.active = false
                end
        end
end

function Snake:SetAbyssalCatalystStacks(count)
        count = math.max(0, math.floor((count or 0) + 0.0001))
        local state = self.AbyssalCatalyst

        if count > 0 then
                if not state then
                        state = { intensity = 0, target = 0, time = 0 }
                        self.AbyssalCatalyst = state
                end
                state.stacks = count
                state.target = math.min(1, 0.55 + 0.18 * math.min(count, 3))
        elseif state then
                state.stacks = 0
                state.target = 0
        end

        if self.AbyssalCatalyst and (self.AbyssalCatalyst.stacks or 0) <= 0 and (self.AbyssalCatalyst.intensity or 0) <= 0 then
                self.AbyssalCatalyst = nil
        end
end

function Snake:SetPhoenixEchoCharges(count, options)
        count = math.max(0, math.floor((count or 0) + 0.0001))
        options = options or {}

        local state = self.PhoenixEcho
        if not state and (count > 0 or options.triggered or options.instantIntensity) then
                state = { intensity = 0, target = 0, time = 0, FlareTimer = 0, FlareDuration = 1.2, charges = 0 }
                self.PhoenixEcho = state
        elseif not state then
                return
        end

        local previous = state.charges or 0
        state.charges = count

        if count > 0 then
                state.target = math.min(1, 0.55 + 0.18 * math.min(count, 3))
        else
                state.target = 0
        end

        if count > previous then
                state.flareTimer = math.max(state.flareTimer or 0, 1.25)
        elseif count < previous then
                state.flareTimer = math.max(state.flareTimer or 0, 0.9)
        end

        if options.triggered then
                state.flareTimer = math.max(state.flareTimer or 0, options.triggered)
                state.intensity = math.max(state.intensity or 0, 0.85)
        end

        if options.instantIntensity then
                state.intensity = math.max(state.intensity or 0, options.instantIntensity)
        end

        if options.flareDuration then
                state.flareDuration = options.flareDuration
        elseif not state.flareDuration then
                state.flareDuration = 1.2
        end

        if count <= 0 and state.target <= 0 and (state.intensity or 0) <= 0 and (state.flareTimer or 0) <= 0 then
                self.PhoenixEcho = nil
        end
end

function Snake:SetEventHorizonActive(active)
        if active then
                local state = self.EventHorizon
                if not state then
                        state = { intensity = 0, target = 1, spin = 0, time = 0 }
                        self.EventHorizon = state
                end
                state.target = 1
                state.active = true
        else
                local state = self.EventHorizon
                if state then
                        state.target = 0
                        state.active = false
                end
        end
end

function Snake:SetStormchaserPrimed(active)
        local state = self.stormchaser
        if active then
                if not state then
                        state = { intensity = 0, target = 1, time = 0, primed = true }
                        self.stormchaser = state
                end
                state.target = 1
                state.primed = true
        elseif state then
                state.target = 0
                state.primed = false
        end

        if self.stormchaser and not self.stormchaser.primed and (self.stormchaser.intensity or 0) <= 0 and (self.stormchaser.target or 0) <= 0 then
                self.stormchaser = nil
        end
end

function Snake:SetTitanbloodStacks(count)
        count = math.max(0, math.floor((count or 0) + 0.0001))
        local state = self.titanblood

        if count > 0 then
                if not state then
                        state = { intensity = 0, target = 0, time = 0 }
                        self.titanblood = state
                end
                state.stacks = count
                state.target = math.min(1, 0.5 + 0.18 * math.min(count, 3))
        elseif state then
                state.stacks = 0
                state.target = 0
        end

        if self.titanblood and (self.titanblood.stacks or 0) <= 0 and (self.titanblood.intensity or 0) <= 0 then
                self.titanblood = nil
        end
end

function Snake:AddShieldBurst(config)
	config = config or {}
	self.ShieldBurst = self.ShieldBurst or { rocks = 0, stall = 0 }
	local rocks = config.rocks or 0
	local stall = config.stall or 0
	if rocks ~= 0 then
		self.ShieldBurst.rocks = (self.ShieldBurst.rocks or 0) + rocks
	end
	if stall ~= 0 then
		self.ShieldBurst.stall = (self.ShieldBurst.stall or 0) + stall
	end
end

function Snake:OnShieldConsumed(x, y, cause)
	local BurstTriggered = false
	local BurstRocks = 0
	local BurstStall = 0

	if self.ShieldBurst then
		local RocksToBreak = math.floor(self.ShieldBurst.rocks or 0)
		if RocksToBreak > 0 and Rocks and Rocks.ShatterNearest then
			Rocks:ShatterNearest(x or 0, y or 0, RocksToBreak)
			BurstTriggered = true
			BurstRocks = RocksToBreak
		end

		local StallDuration = self.ShieldBurst.stall or 0
		if StallDuration > 0 and Saws and Saws.stall then
			Saws:stall(StallDuration)
			BurstTriggered = true
			BurstStall = StallDuration
		end
	end

	if BurstTriggered and (not x or not y) and self.GetHead then
		x, y = self:GetHead()
	end

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		Upgrades:notify("ShieldConsumed", {
			x = x,
			y = y,
			cause = cause or "unknown",
			BurstTriggered = BurstTriggered,
			burst = BurstTriggered and {
				rocks = BurstRocks,
				stall = BurstStall,
			} or nil,
		})
	elseif BurstTriggered and x and y then
		UpgradeVisuals:spawn(x, y, {
			color = {0.72, 0.9, 1, 1},
			GlowColor = {0.58, 0.78, 1, 1},
			HaloColor = {0.46, 0.66, 1, 0.22},
			badge = "burst",
			BadgeScale = 1.08,
			RingCount = 4,
			RingSpacing = 14,
			RingWidth = 5,
			InnerRadius = 18,
			OuterRadius = 86,
			life = 0.58,
			GlowAlpha = 0.28,
			HaloAlpha = 0.2,
		})

		if Particles and Particles.SpawnBurst then
			Particles:SpawnBurst(x, y, {
				count = 22,
				speed = 140,
				SpeedVariance = 70,
				life = 0.52,
				size = 7,
				color = {0.58, 0.82, 1, 0.9},
				drag = 3.2,
				FadeTo = 0,
			})
		end
	end
end

function Snake:AddStoneSkinSawGrace(n)
	n = n or 1
	if n <= 0 then return end
	self.StoneSkinSawGrace = (self.StoneSkinSawGrace or 0) + n
end

function Snake:ConsumeStoneSkinSawGrace()
	if (self.StoneSkinSawGrace or 0) > 0 then
		self.StoneSkinSawGrace = self.StoneSkinSawGrace - 1
		self.ShieldFlashTimer = SHIELD_FLASH_DURATION
		return true
	end
	return false
end

function Snake:IsHazardGraceActive()
	return (self.HazardGraceTimer or 0) > 0
end

function Snake:BeginHazardGrace(duration)
	local grace = duration or HAZARD_GRACE_DURATION
	if not (grace and grace > 0) then
		return
	end

	local current = self.HazardGraceTimer or 0
	if grace > current then
		self.HazardGraceTimer = grace
	end
end

function Snake:OnDamageTaken(cause, info)
	info = info or {}

	local PushX = info.pushX or 0
	local PushY = info.pushY or 0
	local translated = false

	if PushX ~= 0 or PushY ~= 0 then
		self:translate(PushX, PushY)
		translated = true
	end

	if info.snapX and info.snapY and not translated then
		self:SetHeadPosition(info.snapX, info.snapY)
	end

	local DirX = info.dirX
	local DirY = info.dirY
	if (DirX and DirX ~= 0) or (DirY and DirY ~= 0) then
		self:SetDirectionVector(DirX or 0, DirY or 0)
	end

	local grace = info.grace or (HAZARD_GRACE_DURATION * 2)
	if grace and grace > 0 then
		self:BeginHazardGrace(grace)
	end

	local HeadX, HeadY = self:GetHead()
	if HeadX and HeadY then
		local CenterX = HeadX + SEGMENT_SIZE * 0.5
		local CenterY = HeadY + SEGMENT_SIZE * 0.5

		local BurstDirX, BurstDirY = 0, -1
		local PushMag = math.sqrt(PushX * PushX + PushY * PushY)
		if PushMag > 1e-4 then
			BurstDirX = PushX / PushMag
			BurstDirY = PushY / PushMag
		elseif DirX and DirY and (DirX ~= 0 or DirY ~= 0) then
			local DirMag = math.sqrt(DirX * DirX + DirY * DirY)
			if DirMag > 1e-4 then
				BurstDirX = -DirX / DirMag
				BurstDirY = -DirY / DirMag
			end
		else
			local FaceX = direction and direction.x or 0
			local FaceY = direction and direction.y or -1
			local FaceMag = math.sqrt(FaceX * FaceX + FaceY * FaceY)
			if FaceMag > 1e-4 then
				BurstDirX = -FaceX / FaceMag
				BurstDirY = -FaceY / FaceMag
			end
		end

		if Particles and Particles.SpawnBurst then
			Particles:SpawnBurst(CenterX, CenterY, {
				count = 16,
				speed = 170,
				SpeedVariance = 90,
				life = 0.48,
				size = 5,
				color = {1, 0.46, 0.32, 1},
				spread = math.pi * 2,
				AngleJitter = math.pi,
				drag = 3.2,
				gravity = 280,
				FadeTo = 0.05,
			})
		end

		local shielded = info.damage ~= nil and info.damage <= 0
		if Particles and Particles.SpawnBlood and not shielded then
			Particles:SpawnBlood(CenterX, CenterY, {
				DirX = BurstDirX,
				DirY = BurstDirY,
				spread = math.pi * 0.65,
				count = 10,
				DropletCount = 6,
				speed = 210,
				SpeedVariance = 80,
				life = 0.5,
				size = 3.6,
				gravity = 340,
				FadeTo = 0.06,
			})
		end

		if FloatingText and FloatingText.add then
			local inflicted = info.inflictedDamage or info.damage
			local label
			if shielded then
				label = "SHIELD!"
			elseif inflicted and inflicted > 0 then
				label = nil
			else
				label = "HIT!"
			end

			if label then
				local options = {
					scale = 1.08,
					PopScaleFactor = 1.45,
					PopDuration = 0.24,
					WobbleMagnitude = 0.2,
					WobbleFrequency = 4.6,
					shadow = {
						color = {0, 0, 0, 0.6},
						offset = {0, 3},
						blur = 1.6,
					},
					glow = {
						color = {1, 0.42, 0.32, 0.45},
						magnitude = 0.35,
						frequency = 5.2,
					},
					jitter = 2.4,
				}

				FloatingText:add(label, CenterX, CenterY - 30, {1, 0.78, 0.68, 1}, 0.9, 36, nil, options)
			end
		end
	end

	self.ShieldFlashTimer = SHIELD_FLASH_DURATION
	self.DamageFlashTimer = DAMAGE_FLASH_DURATION
end

-- >>> Small integration note:
-- Inside your snake:update(dt) where you compute movement, replace any hard-coded speed use with:
-- local speed = Snake:GetSpeed()
-- and then use `speed` for position updates. This gives upgrades an immediate effect.

-- helpers
local function SnapToCenter(v)
	return (math.floor(v / SEGMENT_SPACING) + 0.5) * SEGMENT_SPACING
end

local function ToCell(x, y)
	return math.floor(x / SEGMENT_SPACING + 0.5), math.floor(y / SEGMENT_SPACING + 0.5)
end

local function FindCircleIntersection(px, py, qx, qy, cx, cy, radius)
	local dx = qx - px
	local dy = qy - py
	local fx = px - cx
	local fy = py - cy

	local a = dx * dx + dy * dy
	if a == 0 then
		return nil, nil
	end

	local b = 2 * (fx * dx + fy * dy)
	local c = fx * fx + fy * fy - radius * radius
	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return nil, nil
	end

	discriminant = math.sqrt(discriminant)
	local t1 = (-b - discriminant) / (2 * a)
	local t2 = (-b + discriminant) / (2 * a)

	local t
	if t1 >= 0 and t1 <= 1 then
		t = t1
	elseif t2 >= 0 and t2 <= 1 then
		t = t2
	end

	if not t then
		return nil, nil
	end

	return px + t * dx, py + t * dy
end

local function NormalizeDirection(dx, dy)
	local len = math.sqrt(dx * dx + dy * dy)
	if len == 0 then
		return 0, 0
	end
	return dx / len, dy / len
end

local function ClosestPointOnSegment(px, py, ax, ay, bx, by)
	if not (px and py and ax and ay and bx and by) then
		return nil, nil, math.huge, 0
	end

	local abx = bx - ax
	local aby = by - ay
	local AbLenSq = abx * abx + aby * aby
	if AbLenSq <= 1e-6 then
		local dx = px - ax
		local dy = py - ay
		return ax, ay, dx * dx + dy * dy, 0
	end

	local apx = px - ax
	local apy = py - ay
	local t = (apx * abx + apy * aby) / AbLenSq
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end

	local cx = ax + abx * t
	local cy = ay + aby * t
	local dx = px - cx
	local dy = py - cy

	return cx, cy, dx * dx + dy * dy, t
end

local function CopySegmentData(segment)
	if not segment then
		return nil
	end

	local copy = {}
	for key, value in pairs(segment) do
		copy[key] = value
	end

	return copy
end

local function TrimHoleSegments(hole)
	if not hole or not trail or #trail == 0 then
		return
	end

	local hx, hy = hole.x, hole.y
	local radius = hole.radius or 0
	if radius <= 0 then
		return
	end

	local WorkingTrail = {}
	for i = 1, #trail do
		local seg = trail[i]
		if not seg then break end
		WorkingTrail[i] = {
			DrawX = seg.drawX,
			DrawY = seg.drawY,
			DirX = seg.dirX,
			DirY = seg.dirY,
		}
	end

	local RadiusSq = radius * radius
	local consumed = 0
	local LastInside = nil
	local RemovedAny = false
	local i = 1

	while i <= #WorkingTrail do
		local seg = WorkingTrail[i]
		local x = seg and seg.drawX
		local y = seg and seg.drawY

		if not (x and y) then
			break
		end

		local dx = x - hx
		local dy = y - hy
		if dx * dx + dy * dy <= RadiusSq then
			RemovedAny = true
			LastInside = { x = x, y = y, DirX = seg.dirX, DirY = seg.dirY }

			local NextSeg = WorkingTrail[i + 1]
			if NextSeg then
				local nx, ny = NextSeg.drawX, NextSeg.drawY
				if nx and ny then
					local SegDx = nx - x
					local SegDy = ny - y
					consumed = consumed + math.sqrt(SegDx * SegDx + SegDy * SegDy)
				end
			end

			table.remove(WorkingTrail, i)
		else
			break
		end
	end

	local NewHead = WorkingTrail[1]
	if RemovedAny and NewHead and LastInside then
		local OldDx = NewHead.drawX - LastInside.x
		local OldDy = NewHead.drawY - LastInside.y
		local OldLen = math.sqrt(OldDx * OldDx + OldDy * OldDy)
		if OldLen > 0 then
			consumed = consumed - OldLen
		end

		local ix, iy = FindCircleIntersection(LastInside.x, LastInside.y, NewHead.drawX, NewHead.drawY, hx, hy, radius)
		if ix and iy then
			local NewDx = ix - LastInside.x
			local NewDy = iy - LastInside.y
			local NewLen = math.sqrt(NewDx * NewDx + NewDy * NewDy)
			consumed = consumed + NewLen
			NewHead.drawX = ix
			NewHead.drawY = iy
		else
			-- fallback: if no intersection, clamp head to previous inside point
			NewHead.drawX = LastInside.x
			NewHead.drawY = LastInside.y
		end
	end

	hole.consumedLength = consumed

	local TotalLength = math.max(0, (SegmentCount or 0) * SEGMENT_SPACING)
	if TotalLength <= 1e-4 then
		hole.fullyConsumed = true
	else
		local epsilon = SEGMENT_SPACING * 0.1
		if consumed >= TotalLength - epsilon then
			hole.fullyConsumed = true
		else
			hole.fullyConsumed = false
		end
	end

	if NewHead and NewHead.drawX and NewHead.drawY then
		hole.entryPointX = NewHead.drawX
		hole.entryPointY = NewHead.drawY
	elseif LastInside then
		hole.entryPointX = LastInside.x
		hole.entryPointY = LastInside.y
	end

	if LastInside and LastInside.dirX and LastInside.dirY then
		hole.entryDirX, hole.entryDirY = NormalizeDirection(LastInside.dirX, LastInside.dirY)
	end
end

local function TrimTrailToSegmentLimit()
	if not trail or #trail == 0 then
		return
	end

	local ConsumedLength = (DescendingHole and DescendingHole.consumedLength) or 0
	local MaxLen = math.max(0, SegmentCount * SEGMENT_SPACING - ConsumedLength)

	if MaxLen <= 0 then
		local head = trail[1]
		trail = {}
		if head then
			trail[1] = {
				DrawX = head.drawX,
				DrawY = head.drawY,
				DirX = head.dirX,
				DirY = head.dirY,
			}
		end
		return
	end

	local traveled = 0
	local i = 2
	while i <= #trail do
		local prev = trail[i - 1]
		local seg = trail[i]
		local px, py = prev and (prev.drawX or prev.x), prev and (prev.drawY or prev.y)
		local sx, sy = seg and (seg.drawX or seg.x), seg and (seg.drawY or seg.y)

		if not (px and py and sx and sy) then
			for j = #trail, i, -1 do
				table.remove(trail, j)
			end
			break
		end

		local dx = px - sx
		local dy = py - sy
		local SegLen = math.sqrt(dx * dx + dy * dy)

		if SegLen <= 0 then
			table.remove(trail, i)
		else
			if traveled + SegLen > MaxLen then
				local excess = traveled + SegLen - MaxLen
				local t = 1 - (excess / SegLen)
				local TailX = px - dx * t
				local TailY = py - dy * t

				for j = #trail, i + 1, -1 do
					table.remove(trail, j)
				end

				seg.drawX = TailX
				seg.drawY = TailY
				if not seg.dirX or not seg.dirY then
					seg.dirX = direction.x
					seg.dirY = direction.y
				end
				break
			else
				traveled = traveled + SegLen
				i = i + 1
			end
		end
	end
end

local function DrawDescendingIntoHole(hole)
	if not hole then
		return
	end

	local consumed = hole.consumedLength or 0
	local depth = hole.renderDepth or 0
	if consumed <= 0 and depth <= 0 then
		return
	end

	local hx = hole.x or 0
	local hy = hole.y or 0
	local EntryX = hole.entryPointX or hx
	local EntryY = hole.entryPointY or hy

	local DirX, DirY = hole.entryDirX or 0, hole.entryDirY or 0
	local DirLen = math.sqrt(DirX * DirX + DirY * DirY)
	if DirLen <= 1e-4 then
		DirX = hx - EntryX
		DirY = hy - EntryY
		DirLen = math.sqrt(DirX * DirX + DirY * DirY)
	end

	if DirLen <= 1e-4 then
		DirX, DirY = 0, -1
	else
		DirX, DirY = DirX / DirLen, DirY / DirLen
	end

	local ToCenterX = hx - EntryX
	local ToCenterY = hy - EntryY
	if ToCenterX * DirX + ToCenterY * DirY < 0 then
		DirX, DirY = -DirX, -DirY
	end

	local BodyColor = SnakeCosmetics:GetBodyColor() or { 1, 1, 1, 1 }
	local r = BodyColor[1] or 1
	local g = BodyColor[2] or 1
	local b = BodyColor[3] or 1
	local a = BodyColor[4] or 1

	local BaseRadius = SEGMENT_SIZE * 0.5
	local HoleRadius = math.max(BaseRadius, hole.radius or BaseRadius * 1.6)
	local DepthTarget = math.min(1, consumed / (HoleRadius + SEGMENT_SPACING * 0.75))
	local RenderDepth = math.max(depth, DepthTarget)

	local steps = math.max(2, math.min(7, math.floor((consumed + SEGMENT_SPACING * 0.4) / (SEGMENT_SPACING * 0.55)) + 2))

	local TotalLength = (SegmentCount or 0) * SEGMENT_SPACING
	local completion = 0
	if TotalLength > 1e-4 then
		completion = math.min(1, consumed / TotalLength)
	end
	local GlobalVisibility = math.max(0, 1 - completion)

	local PerpX, PerpY = -DirY, DirX
	local wobble = 0
	if hole.time then
		wobble = math.sin(hole.time * 4.6) * 0.35
	end

	love.graphics.setLineWidth(2)

	for layer = 0, steps - 1 do
		local LayerFrac = (layer + 0.6) / steps
		local LayerDepth = math.min(1, RenderDepth * (0.35 + 0.65 * LayerFrac))
		local DepthFade = 1 - LayerDepth
		local visibility = DepthFade * DepthFade * GlobalVisibility

		if visibility <= 1e-3 then
			break
		end

		local radius = BaseRadius * (0.9 - 0.55 * LayerDepth)
		radius = math.max(BaseRadius * 0.2, radius)

		local sink = HoleRadius * 0.35 * LayerDepth
		local lateral = wobble * (0.4 + 0.25 * LayerFrac) * DepthFade
		local px = EntryX + (hx - EntryX) * LayerDepth + DirX * sink + PerpX * radius * lateral
		local py = EntryY + (hy - EntryY) * LayerDepth + DirY * sink + PerpY * radius * lateral

		local shade = 0.25 + 0.7 * visibility
		local ShadeR = r * shade
		local ShadeG = g * shade
		local ShadeB = b * shade
		local alpha = a * (0.2 + 0.8 * visibility)
		love.graphics.setColor(ShadeR, ShadeG, ShadeB, math.max(0, math.min(1, alpha)))
		love.graphics.circle("fill", px, py, radius)

		local OutlineAlpha = 0.15 + 0.5 * visibility
		love.graphics.setColor(0, 0, 0, math.max(0, math.min(1, OutlineAlpha)))
		love.graphics.circle("line", px, py, radius)

		if layer == 0 then
			local highlight = 0.45 * math.min(1, DepthFade * 1.1) * GlobalVisibility
			if highlight > 0 then
				love.graphics.setColor(r, g, b, highlight)
				love.graphics.circle("line", px, py, radius * 0.75)
			end
		end
	end
	local CoverAlpha = math.max(depth, RenderDepth) * 0.55
	love.graphics.setColor(0, 0, 0, CoverAlpha)
	love.graphics.circle("fill", hx, hy, HoleRadius * (0.38 + 0.22 * RenderDepth))

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function CollectUpgradeVisuals(self)
	local visuals = nil

	if (self.StonebreakerStacks or 0) > 0 then
		visuals = visuals or {}
		local progress = 0
		if Rocks.GetShatterProgress then
			progress = Rocks:GetShatterProgress()
		end
		local rate = 0
		if Rocks.GetShatterRate then
			rate = Rocks:GetShatterRate()
		else
			rate = Rocks.ShatterOnFruit or 0
		end
		visuals.stonebreaker = {
			stacks = self.StonebreakerStacks or 0,
			progress = progress,
			rate = rate,
		}
	end

        if self.adrenaline and self.adrenaline.active then
                visuals = visuals or {}
                visuals.adrenaline = {
                        active = true,
                        timer = self.adrenaline.timer or 0,
                        duration = self.adrenaline.duration or 0,
                }
        end

        local QuickFangs = self.QuickFangs
        if QuickFangs and (((QuickFangs.intensity or 0) > 0.01) or (QuickFangs.stacks or 0) > 0) then
                visuals = visuals or {}
                visuals.quickFangs = {
                        stacks = QuickFangs.stacks or 0,
                        intensity = QuickFangs.intensity or 0,
                        target = QuickFangs.target or 0,
                        SpeedRatio = QuickFangs.speedRatio or 1,
                        active = QuickFangs.active or false,
                        time = QuickFangs.time or 0,
                        flash = QuickFangs.flash or 0,
                }
        end

        if self.TimeDilation then
                visuals = visuals or {}
                visuals.timeDilation = {
                        active = self.TimeDilation.active or false,
                        timer = self.TimeDilation.timer or 0,
			duration = self.TimeDilation.duration or 0,
			cooldown = self.TimeDilation.cooldown or 0,
                        CooldownTimer = self.TimeDilation.CooldownTimer or 0,
                }
        end

        local TemporalAnchor = self.TemporalAnchor
        if TemporalAnchor and (((TemporalAnchor.intensity or 0) > 1e-3) or (TemporalAnchor.target or 0) > 0) then
                visuals = visuals or {}
                visuals.temporalAnchor = {
                        intensity = TemporalAnchor.intensity or 0,
                        ready = TemporalAnchor.ready or 0,
                        active = TemporalAnchor.active or false,
                        time = TemporalAnchor.time or 0,
                }
        end

        if self.dash then
                visuals = visuals or {}
                visuals.dash = {
                        active = self.dash.active or false,
                        timer = self.dash.timer or 0,
			duration = self.dash.duration or 0,
			cooldown = self.dash.cooldown or 0,
			CooldownTimer = self.dash.CooldownTimer or 0,
                }
        end

        local chronospiral = self.chronospiral
        if chronospiral and ((chronospiral.intensity or 0) > 1e-3 or (chronospiral.target or 0) > 0) then
                visuals = visuals or {}
                visuals.chronospiral = {
                        intensity = chronospiral.intensity or 0,
                        spin = chronospiral.spin or 0,
                }
        end

        local abyssal = self.AbyssalCatalyst
        if abyssal and ((abyssal.intensity or 0) > 1e-3 or (abyssal.target or 0) > 0) then
                visuals = visuals or {}
                visuals.abyssalCatalyst = {
                        intensity = abyssal.intensity or 0,
                        stacks = abyssal.stacks or 0,
                        pulse = abyssal.pulse or abyssal.time or 0,
                }
        end

        local titanblood = self.titanblood
        if titanblood and ((titanblood.intensity or 0) > 1e-3 or (titanblood.target or 0) > 0) then
                visuals = visuals or {}
                visuals.titanblood = {
                        intensity = titanblood.intensity or 0,
                        stacks = titanblood.stacks or 0,
                        time = titanblood.time or 0,
                }
        end

        local stormchaser = self.stormchaser
        if stormchaser and ((stormchaser.intensity or 0) > 1e-3 or (stormchaser.target or 0) > 0) then
                visuals = visuals or {}
                visuals.stormchaser = {
                        intensity = stormchaser.intensity or 0,
                        primed = stormchaser.primed or false,
                        time = stormchaser.time or 0,
                }
        end

        local EventHorizon = self.EventHorizon
        if EventHorizon and ((EventHorizon.intensity or 0) > 1e-3 or (EventHorizon.target or 0) > 0) then
                visuals = visuals or {}
                visuals.eventHorizon = {
                        intensity = EventHorizon.intensity or 0,
                        spin = EventHorizon.spin or 0,
                        time = EventHorizon.time or 0,
                }
        end

        local phoenix = self.PhoenixEcho
        if phoenix and (((phoenix.intensity or 0) > 1e-3) or (phoenix.charges or 0) > 0 or (phoenix.flareTimer or 0) > 0) then
                visuals = visuals or {}
                local flare = 0
                local FlareDuration = phoenix.flareDuration or 1.2
                if FlareDuration > 0 and (phoenix.flareTimer or 0) > 0 then
                        flare = math.min(1, phoenix.flareTimer / FlareDuration)
                end
                visuals.phoenixEcho = {
                        intensity = phoenix.intensity or 0,
                        charges = phoenix.charges or 0,
                        flare = flare,
                        time = phoenix.time or 0,
                }
        end

        return visuals
end

-- Build initial trail aligned to CELL CENTERS
local function BuildInitialTrail()
	local t = {}
	local MidCol = math.floor(Arena.cols / 2)
	local MidRow = math.floor(Arena.rows / 2)
	local StartX, StartY = Arena:GetCenterOfTile(MidCol, MidRow)

	for i = 0, SegmentCount - 1 do
		local cx = StartX - i * SEGMENT_SPACING * direction.x
		local cy = StartY - i * SEGMENT_SPACING * direction.y
		table.insert(t, {
			DrawX = cx, DrawY = cy,
			DirX = direction.x, DirY = direction.y
		})
	end
	return t
end

function Snake:load(w, h)
	ScreenW, ScreenH = w, h
	direction = { x = 1, y = 0 }
	PendingDir = { x = 1, y = 0 }
	SegmentCount = 1
	PopTimer = 0
	MoveProgress = 0
	IsDead = false
	self.ShieldFlashTimer = 0
	self.HazardGraceTimer = 0
	self.DamageFlashTimer = 0
	trail = BuildInitialTrail()
	DescendingHole = nil
	FruitsSinceLastTurn = 0
	SeveredPieces = {}
end

local function GetUpgradesModule()
	return package.loaded["upgrades"]
end

function Snake:SetDirection(name)
	if not IsDead then
		PendingDir = SnakeUtils.CalculateDirection(direction, name)
	end
end

function Snake:SetDead(state)
	IsDead = not not state
end

function Snake:GetDirection()
	return direction
end

function Snake:GetHead()
	local head = trail[1]
	if not head then
		return nil, nil
	end
	return head.drawX, head.drawY
end

function Snake:SetHeadPosition(x, y)
	local head = trail[1]
	if not head then
		return
	end

	head.drawX = x
	head.drawY = y
end

function Snake:translate(dx, dy)
	dx = dx or 0
	dy = dy or 0
	if dx == 0 and dy == 0 then
		return
	end

	for i = 1, #trail do
		local seg = trail[i]
		if seg then
			seg.drawX = seg.drawX + dx
			seg.drawY = seg.drawY + dy
		end
	end

	if DescendingHole then
		DescendingHole.x = (DescendingHole.x or 0) + dx
		DescendingHole.y = (DescendingHole.y or 0) + dy
		if DescendingHole.entryPointX then
			DescendingHole.entryPointX = DescendingHole.entryPointX + dx
		end
		if DescendingHole.entryPointY then
			DescendingHole.entryPointY = DescendingHole.entryPointY + dy
		end
	end
end

function Snake:SetDirectionVector(dx, dy)
	if IsDead then return end

	dx = dx or 0
	dy = dy or 0

	local nx, ny = NormalizeDirection(dx, dy)
	if nx == 0 and ny == 0 then
		return
	end

	local PrevX, PrevY = direction.x, direction.y
	direction = { x = nx, y = ny }
	PendingDir = { x = nx, y = ny }

	local head = trail and trail[1]
	if head then
		head.dirX = nx
		head.dirY = ny
	end

	if PrevX ~= direction.x or PrevY ~= direction.y then
		FruitsSinceLastTurn = 0
	end
end

function Snake:GetHeadCell()
	local hx, hy = self:GetHead()
	if not (hx and hy) then
		return nil, nil
	end
	return ToCell(hx, hy)
end

local function AddSafeCellUnique(cells, seen, col, row)
	local key = col .. "," .. row
	if not seen[key] then
		seen[key] = true
		cells[#cells + 1] = {col, row}
	end
end

function Snake:GetSafeZone(lookahead)
	local hx, hy = self:GetHeadCell()
	if not (hx and hy) then
		return {}
	end

	local dir = self:GetDirection()
	local cells = {}
	local seen = {}

	for i = 1, lookahead do
		local cx = hx + dir.x * i
		local cy = hy + dir.y * i
		AddSafeCellUnique(cells, seen, cx, cy)
	end

	local pending = PendingDir
	if pending and (pending.x ~= dir.x or pending.y ~= dir.y) then
		-- Immediate turn path (if the queued direction snaps before the next tile)
		local px, py = hx, hy
		for i = 1, lookahead do
			px = px + pending.x
			py = py + pending.y
			AddSafeCellUnique(cells, seen, px, py)
		end

		-- Typical turn path: advance one tile forward, then apply the queued turn
		local TurnCol = hx + dir.x
		local TurnRow = hy + dir.y
		px, py = TurnCol, TurnRow
		for i = 2, lookahead do
			px = px + pending.x
			py = py + pending.y
			AddSafeCellUnique(cells, seen, px, py)
		end
	end

	return cells
end

function Snake:DrawClipped(hx, hy, hr)
	if not trail or #trail == 0 then
		return
	end

	local HeadX, HeadY = self:GetHead()
	local ClipRadius = hr or 0
	local RenderTrail = trail

	if ClipRadius > 0 then
		local RadiusSq = ClipRadius * ClipRadius
		local StartIndex = 1

		while StartIndex <= #trail do
			local seg = trail[StartIndex]
			local x = seg and (seg.drawX or seg.x)
			local y = seg and (seg.drawY or seg.y)

			if not (x and y) then
				break
			end

			local dx = x - hx
			local dy = y - hy
			if dx * dx + dy * dy > RadiusSq then
				break
			end

			StartIndex = StartIndex + 1
		end

		if StartIndex == 1 then
			-- Head is still outside the clip region; render entire trail
			RenderTrail = trail
		elseif StartIndex > #trail then
			-- Entire snake is within the clip; nothing to draw outside
			RenderTrail = {}
		else
			local trimmed = {}
			local prev = trail[StartIndex - 1]
			local curr = trail[StartIndex]
			local px = prev and (prev.drawX or prev.x)
			local py = prev and (prev.drawY or prev.y)
			local cx = curr and (curr.drawX or curr.x)
			local cy = curr and (curr.drawY or curr.y)
			local ix, iy

			if px and py and cx and cy then
				ix, iy = FindCircleIntersection(px, py, cx, cy, hx, hy, ClipRadius)
			end

			if not (ix and iy) then
				if DescendingHole and math.abs((DescendingHole.x or 0) - hx) < 1e-3 and math.abs((DescendingHole.y or 0) - hy) < 1e-3 then
					ix = DescendingHole.entryPointX or px
					iy = DescendingHole.entryPointY or py
				else
					ix, iy = px, py
				end
			end

			if ix and iy then
				trimmed[#trimmed + 1] = { DrawX = ix, DrawY = iy }
			end

			for i = StartIndex, #trail do
				trimmed[#trimmed + 1] = trail[i]
			end

			RenderTrail = trimmed
		end
	end

	love.graphics.push("all")
	local UpgradeVisuals = CollectUpgradeVisuals(self)

	if ClipRadius > 0 then
		love.graphics.stencil(function()
			love.graphics.circle("fill", hx, hy, ClipRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 0)
	end

	local ShouldDrawFace = DescendingHole == nil
	local HideDescendingBody = DescendingHole and DescendingHole.fullyConsumed

	if not HideDescendingBody then
		SnakeDraw.run(RenderTrail, SegmentCount, SEGMENT_SIZE, PopTimer, function()
			if HeadX and HeadY and ClipRadius > 0 then
				local dx = HeadX - hx
				local dy = HeadY - hy
				if dx * dx + dy * dy < ClipRadius * ClipRadius then
					return nil, nil
				end
			end
			return HeadX, HeadY
		end, self.CrashShields or 0, self.ShieldFlashTimer or 0, UpgradeVisuals, ShouldDrawFace)
	end

	if ClipRadius > 0 and DescendingHole and not HideDescendingBody and math.abs((DescendingHole.x or 0) - hx) < 1e-3 and math.abs((DescendingHole.y or 0) - hy) < 1e-3 then
		love.graphics.setStencilTest("equal", 1)
		DrawDescendingIntoHole(DescendingHole)
	end

	love.graphics.setStencilTest()
	love.graphics.pop()
end

function Snake:StartDescending(hx, hy, hr)
	DescendingHole = {
		x = hx,
		y = hy,
		radius = hr or 0,
		ConsumedLength = 0,
		RenderDepth = 0,
		time = 0,
		FullyConsumed = false,
	}

	local HeadX, HeadY = self:GetHead()
	if HeadX and HeadY then
		DescendingHole.entryPointX = HeadX
		DescendingHole.entryPointY = HeadY
		local DirX, DirY = NormalizeDirection((hx or HeadX) - HeadX, (hy or HeadY) - HeadY)
		DescendingHole.entryDirX = DirX
		DescendingHole.entryDirY = DirY
	end
end

function Snake:FinishDescending()
	DescendingHole = nil
end

function Snake:update(dt)
        if IsDead then return false, "dead", { fatal = true } end

        if self.chronospiral then
                local state = self.chronospiral
                state.spin = (state.spin or 0) + dt
                local intensity = state.intensity or 0
                local target = state.target or 0
                local rate = (state.active and 4.0 or 2.4)
                local blend = math.min(1, dt * rate)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if intensity < 0.005 and target <= 0 then
                        self.chronospiral = nil
                end
        end

        if self.AbyssalCatalyst then
                local state = self.AbyssalCatalyst
                state.time = (state.time or 0) + dt
                state.pulse = state.time
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * 3.0)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if (state.stacks or 0) <= 0 and intensity < 0.01 then
                        self.AbyssalCatalyst = nil
                end
        end

        if self.PhoenixEcho then
                local state = self.PhoenixEcho
                state.time = (state.time or 0) + dt
                state.flareDuration = state.flareDuration or 1.2
                if state.flareTimer then
                        state.flareTimer = math.max(0, state.flareTimer - dt)
                end
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * 4.2)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if (state.charges or 0) <= 0 and target <= 0 and intensity < 0.01 and (state.flareTimer or 0) <= 0 then
                        self.PhoenixEcho = nil
                end
        end

        if self.EventHorizon then
                local state = self.EventHorizon
                state.time = (state.time or 0) + dt
                state.spin = (state.spin or 0) + dt * (0.7 + 0.9 * (state.intensity or 0))
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * (state.active and 3.2 or 2.0))
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if not state.active and target <= 0 and intensity < 0.01 then
                        self.EventHorizon = nil
                end
        end

        if self.stormchaser then
                local state = self.stormchaser
                state.time = (state.time or 0) + dt
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * (state.primed and 6.5 or 4.2))
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if not state.primed and target <= 0 and intensity < 0.02 then
                        self.stormchaser = nil
                end
        end

        if self.titanblood then
                local state = self.titanblood
                state.time = (state.time or 0) + dt
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * 3.4)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if (state.stacks or 0) <= 0 and target <= 0 and intensity < 0.01 then
                        self.titanblood = nil
                end
        end

        -- base speed with upgrades/modifiers
        local head = trail[1]
        local speed = self:GetSpeed()

	local hole = DescendingHole
	if hole then
		hole.time = (hole.time or 0) + dt

		if head and head.drawX and head.drawY then
			hole.entryPointX = head.drawX
			hole.entryPointY = head.drawY

			local DirX, DirY = NormalizeDirection((hole.x or head.drawX) - head.drawX, (hole.y or head.drawY) - head.drawY)
			if DirX ~= 0 or DirY ~= 0 then
				hole.entryDirX = DirX
				hole.entryDirY = DirY
			end
		end

		local consumed = hole.consumedLength or 0
		local TotalDepth = math.max(SEGMENT_SPACING * 0.5, (hole.radius or 0) + SEGMENT_SPACING)
		local TargetDepth = math.min(1, consumed / TotalDepth)
		local CurrentDepth = hole.renderDepth or 0
		local blend = math.min(1, dt * 10)
		CurrentDepth = CurrentDepth + (TargetDepth - CurrentDepth) * blend
		hole.renderDepth = CurrentDepth
	end

	if self.dash then
		if self.dash.CooldownTimer and self.dash.CooldownTimer > 0 then
			self.dash.CooldownTimer = math.max(0, (self.dash.CooldownTimer or 0) - dt)
		end

		if self.dash.active then
			speed = speed * (self.dash.SpeedMult or 1)
			self.dash.timer = (self.dash.timer or 0) - dt
			if self.dash.timer <= 0 then
				self.dash.active = false
				self.dash.timer = 0
			end
		end
	end

        if self.TimeDilation then
                if self.TimeDilation.CooldownTimer and self.TimeDilation.CooldownTimer > 0 then
                        self.TimeDilation.CooldownTimer = math.max(0, (self.TimeDilation.CooldownTimer or 0) - dt)
                end

                if self.TimeDilation.active then
                        self.TimeDilation.timer = (self.TimeDilation.timer or 0) - dt
                        if self.TimeDilation.timer <= 0 then
                                self.TimeDilation.active = false
                                self.TimeDilation.timer = 0
                        end
                end
        end

        local dilation = self.TimeDilation
        if dilation and dilation.source == "temporal_anchor" then
                local state = self.TemporalAnchor
                if not state then
                        state = { intensity = 0, target = 0, ready = 0, time = 0 }
                        self.TemporalAnchor = state
                end
                state.time = (state.time or 0) + dt
                state.active = dilation.active or false
                local cooldown = dilation.cooldown or 0
                local CooldownTimer = dilation.cooldownTimer or 0
                local readiness
                if dilation.active then
                        readiness = 1
                elseif cooldown and cooldown > 0 then
                        readiness = 1 - math.min(1, CooldownTimer / cooldown)
                else
                        readiness = (CooldownTimer <= 0) and 1 or 0
                end
                state.ready = math.max(0, math.min(1, readiness))
                if dilation.active then
                        state.target = 1
                else
                        state.target = math.max(0.2, 0.3 + state.ready * 0.5)
                end
        elseif self.TemporalAnchor then
                local state = self.TemporalAnchor
                state.time = (state.time or 0) + dt
                state.active = false
                state.ready = 0
                state.target = 0
        end

        if self.TemporalAnchor then
                local state = self.TemporalAnchor
                local intensity = state.intensity or 0
                local target = state.target or 0
                local blend = math.min(1, dt * 5.0)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                if intensity < 0.01 and target <= 0 then
                        self.TemporalAnchor = nil
                end
        end

	hole = DescendingHole
	if hole and head then
		local dx = hole.x - head.drawX
		local dy = hole.y - head.drawY
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist > 1e-4 then
			local nx, ny = dx / dist, dy / dist
			local PrevX, PrevY = direction.x, direction.y
			direction = { x = nx, y = ny }
			PendingDir = { x = nx, y = ny }
			if PrevX ~= direction.x or PrevY ~= direction.y then
				FruitsSinceLastTurn = 0
			end
		end
	end

	-- adrenaline boost check
        if self.adrenaline and self.adrenaline.active then
                speed = speed * self.adrenaline.boost
                self.adrenaline.timer = self.adrenaline.timer - dt
                if self.adrenaline.timer <= 0 then
                        self.adrenaline.active = false
                end
        end

        if self.QuickFangs then
                local state = self.QuickFangs
                state.time = (state.time or 0) + dt * (1.4 + math.min(1.8, (speed / math.max(1, self.BaseSpeed or 1))))
                state.flash = math.max(0, (state.flash or 0) - dt * 1.8)

                local BaseTarget = state.baseTarget or 0
                local BaseSpeed = self.BaseSpeed or 1
                if not BaseSpeed or BaseSpeed <= 0 then
                        BaseSpeed = 1
                end

                local ratio = speed / BaseSpeed
                if ratio < 0 then ratio = 0 end
                state.speedRatio = ratio

                local bonus = math.max(0, ratio - 1)
                local dynamic = math.min(0.35, bonus * 0.4)
                local FlashBonus = (state.flash or 0) * 0.35
                local target = math.min(1, math.max(0, BaseTarget + dynamic + FlashBonus))
                state.target = target

                local intensity = state.intensity or 0
                local blend = math.min(1, dt * 6.0)
                intensity = intensity + (target - intensity) * blend
                state.intensity = intensity
                state.active = (target > BaseTarget + 0.02) or (ratio > 1.05) or ((state.flash or 0) > 0.05)

                if (state.stacks or 0) <= 0 and target <= 0 and intensity < 0.02 then
                        self.QuickFangs = nil
                end
        end

        local StepX = direction.x * speed * dt
        local StepY = direction.y * speed * dt
        local NewX = head.drawX + StepX
        local NewY = head.drawY + StepY

	-- advance cell clock, maybe snap & commit queued direction
	local SnappedThisTick = false
	if hole then
		MoveProgress = 0
	else
		local StepDistance = speed * dt
		MoveProgress = MoveProgress + StepDistance
		local snaps = 0
		local SegmentLength = SEGMENT_SPACING
		while MoveProgress >= SegmentLength do
			MoveProgress = MoveProgress - SegmentLength
			snaps = snaps + 1
		end
		if snaps > 0 then
			SessionStats:add("TilesTravelled", snaps)
		end
		if snaps > 0 then
			-- snap to the nearest grid center
			NewX = SnapToCenter(NewX)
			NewY = SnapToCenter(NewY)
			-- commit queued direction
			local PrevX, PrevY = direction.x, direction.y
			direction = { x = PendingDir.x, y = PendingDir.y }
			if PrevX ~= direction.x or PrevY ~= direction.y then
				FruitsSinceLastTurn = 0
			end
			SnappedThisTick = true
		end
	end

	-- spatially uniform sampling along the motion path
	local dx = NewX - head.drawX
	local dy = NewY - head.drawY
	local dist = math.sqrt(dx*dx + dy*dy)

	local nx, ny = 0, 0
	if dist > 0 then
		nx, ny = dx / dist, dy / dist
	end

	local remaining = dist
	local PrevX, PrevY = head.drawX, head.drawY

	while remaining >= SAMPLE_STEP do
		PrevX = PrevX + nx * SAMPLE_STEP
		PrevY = PrevY + ny * SAMPLE_STEP
		table.insert(trail, 1, {
			DrawX = PrevX,
			DrawY = PrevY,
			DirX  = direction.x,
			DirY  = direction.y
		})
		remaining = remaining - SAMPLE_STEP
	end

	-- final correction: put true head at exact new position
	if trail[1] then
		trail[1].DrawX = NewX
		trail[1].DrawY = NewY
	end

	if hole then
		TrimHoleSegments(hole)
		head = trail[1]
		if head then
			NewX, NewY = head.drawX, head.drawY
		end
	end

	-- tail trimming
	local TailBeforeX, TailBeforeY = nil, nil
	local len = #trail
	if len > 0 then
		TailBeforeX, TailBeforeY = trail[len].DrawX, trail[len].DrawY
	end
	local TailBeforeCol, TailBeforeRow
	if TailBeforeX and TailBeforeY then
		TailBeforeCol, TailBeforeRow = ToCell(TailBeforeX, TailBeforeY)
	end

	local ConsumedLength = (hole and hole.consumedLength) or 0
	local MaxLen = math.max(0, SegmentCount * SEGMENT_SPACING - ConsumedLength)

	if MaxLen == 0 then
		trail = {}
		len = 0
	end

	local traveled = 0
	for i = 2, #trail do
		local dx = trail[i-1].DrawX - trail[i].DrawX
		local dy = trail[i-1].DrawY - trail[i].DrawY
		local SegLen = math.sqrt(dx*dx + dy*dy)

		if traveled + SegLen > MaxLen then
			local excess = traveled + SegLen - MaxLen
			local t = 1 - (excess / SegLen)
			local TailX = trail[i-1].DrawX - dx * t
			local TailY = trail[i-1].DrawY - dy * t

			for j = #trail, i+1, -1 do
				table.remove(trail, j)
			end

			trail[i].DrawX, trail[i].DrawY = TailX, TailY
			break
		else
			traveled = traveled + SegLen
		end
	end

	-- collision with self (grid-cell based, only at snap ticks)
		if SnappedThisTick and not self:IsHazardGraceActive() then
				local hx, hy = trail[1].DrawX, trail[1].DrawY
				local HeadCol, HeadRow = ToCell(hx, hy)

		-- Don’t check the first ~1 segment of body behind the head (neck).
		-- Compute by *distance*, not “skip N nodes”.
		local GuardDist = SEGMENT_SPACING * 1.05  -- about one full cell
		local walked = 0

		local function seglen(i)
			local dx = trail[i-1].DrawX - trail[i].DrawX
			local dy = trail[i-1].DrawY - trail[i].DrawY
			return math.sqrt(dx*dx + dy*dy)
		end

		-- advance 'walked' until we’re past the neck
		local StartIndex = 2
		while StartIndex < #trail and walked < GuardDist do
			walked = walked + seglen(StartIndex)
			StartIndex = StartIndex + 1
		end

		-- If tail vacated the head cell this tick, don’t count that as a hit
		local TailBeforeCol, TailBeforeRow = nil, nil
		do
			local len = #trail
			if len >= 1 then
				local tbx, tby = trail[len].DrawX, trail[len].DrawY
				if tbx and tby then
					TailBeforeCol, TailBeforeRow = ToCell(tbx, tby)
				end
			end
		end

		for i = StartIndex, #trail do
			local cx, cy = ToCell(trail[i].DrawX, trail[i].DrawY)

			-- allow stepping into the tail cell if the tail moved off this tick
			local TailVacated =
				(i == #trail) and (TailBeforeCol == HeadCol and TailBeforeRow == HeadRow)

						if not TailVacated and cx == HeadCol and cy == HeadRow then
								if self:ConsumeCrashShield() then
										-- survived; optional FX here
										self:OnShieldConsumed(hx, hy, "self")
										self:BeginHazardGrace()
								else
										local PushX = -(direction.x or 0) * SEGMENT_SPACING
										local PushY = -(direction.y or 0) * SEGMENT_SPACING
										local context = {
											PushX = PushX,
											PushY = PushY,
											DirX = -(direction.x or 0),
											DirY = -(direction.y or 0),
											grace = HAZARD_GRACE_DURATION * 2,
											shake = 0.28,
										}
										return false, "self", context
								end
						end
				end
		end

	-- update timers
	if PopTimer > 0 then
		PopTimer = math.max(0, PopTimer - dt)
	end

	if self.ShieldFlashTimer and self.ShieldFlashTimer > 0 then
		self.ShieldFlashTimer = math.max(0, self.ShieldFlashTimer - dt)
	end

	if self.HazardGraceTimer and self.HazardGraceTimer > 0 then
		self.HazardGraceTimer = math.max(0, self.HazardGraceTimer - dt)
	end

	if self.DamageFlashTimer and self.DamageFlashTimer > 0 then
		self.DamageFlashTimer = math.max(0, self.DamageFlashTimer - dt)
	end

	if SeveredPieces and #SeveredPieces > 0 then
		for index = #SeveredPieces, 1, -1 do
			local piece = SeveredPieces[index]
			if piece then
				piece.timer = (piece.timer or 0) - dt
				if piece.timer <= 0 then
					table.remove(SeveredPieces, index)
				end
			end
		end
	end

	return true
end

function Snake:ActivateDash()
	local dash = self.dash
	if not dash or dash.active then
		return false
	end

	if (dash.cooldownTimer or 0) > 0 then
		return false
	end

	dash.active = true
	dash.timer = dash.duration or 0
	dash.cooldownTimer = dash.cooldown or 0

	if dash.timer <= 0 then
		dash.active = false
	end

	local hx, hy = self:GetHead()
	local Upgrades = GetUpgradesModule()
	if Upgrades and Upgrades.notify then
		Upgrades:notify("DashActivated", {
			x = hx,
			y = hy,
		})
	end

	return dash.active
end

function Snake:IsDashActive()
	return self.dash and self.dash.active or false
end

function Snake:GetDashState()
	if not self.dash then
		return nil
	end

	return {
		active = self.dash.active or false,
		timer = self.dash.timer or 0,
		duration = self.dash.duration or 0,
		cooldown = self.dash.cooldown or 0,
		CooldownTimer = self.dash.CooldownTimer or 0,
	}
end

function Snake:OnDashBreakRock(x, y)
	local dash = self.dash
	if not dash then return end

	local Upgrades = GetUpgradesModule()
	if Upgrades and Upgrades.notify then
		Upgrades:notify("DashBreakRock", {
			x = x,
			y = y,
		})
	end
end

function Snake:ActivateTimeDilation()
	local ability = self.TimeDilation
	if not ability or ability.active then
		return false
	end

	if (ability.cooldownTimer or 0) > 0 then
		return false
	end

	local charges = ability.floorCharges
	if charges == nil and ability.maxFloorUses then
		charges = ability.maxFloorUses
		ability.floorCharges = charges
	end
	if charges ~= nil and charges <= 0 then
		return false
	end

	ability.active = true
	ability.timer = ability.duration or 0
	ability.cooldownTimer = ability.cooldown or 0

	if ability.timer <= 0 then
		ability.active = false
	end

	if ability.active and charges ~= nil then
		ability.floorCharges = math.max(0, charges - 1)
	end

	local hx, hy = self:GetHead()
	local Upgrades = GetUpgradesModule()
	if Upgrades and Upgrades.notify then
		Upgrades:notify("TimeDilationActivated", {
			x = hx,
			y = hy,
		})
	end

	return ability.active
end

function Snake:GetTimeDilationState()
	local ability = self.TimeDilation
	if not ability then
		return nil
	end

	return {
		active = ability.active or false,
		timer = ability.timer or 0,
		duration = ability.duration or 0,
		cooldown = ability.cooldown or 0,
		CooldownTimer = ability.cooldownTimer or 0,
		TimeScale = ResolveTimeDilationScale(ability),
		FloorCharges = ability.floorCharges,
		MaxFloorUses = ability.maxFloorUses,
	}
end

function Snake:GetTimeScale()
	return ResolveTimeDilationScale(self.TimeDilation)
end

function Snake:grow()
	local bonus = self.ExtraGrowth or 0
	SegmentCount = SegmentCount + 1 + bonus
	PopTimer = POP_DURATION
end

function Snake:LoseSegments(count, options)
	count = math.floor(count or 0)
	if count <= 0 then
		return 0
	end

	local available = math.max(0, (SegmentCount or 1) - 1)
	local trimmed = math.min(count, available)
	if trimmed <= 0 then
		return 0
	end

	local ExitWasOpen = Arena and Arena.HasExit and Arena:HasExit()
	SegmentCount = SegmentCount - trimmed
	PopTimer = 0

	local ShouldTrimTrail = true
	if options and options.trimTrail == false then
		ShouldTrimTrail = false
	end

	if ShouldTrimTrail then
		TrimTrailToSegmentLimit()
	end

	local tail = trail[#trail]
	local TailX = tail and tail.drawX
	local TailY = tail and tail.drawY

	if (not options) or options.updateFruit ~= false then
		if UI and UI.RemoveFruit then
			UI:RemoveFruit(trimmed)
		elseif UI then
			UI.FruitCollected = math.max(0, (UI.FruitCollected or 0) - trimmed)
			if type(UI.FruitSockets) == "table" then
				for _ = 1, math.min(trimmed, #UI.FruitSockets) do
					table.remove(UI.FruitSockets)
				end
			end
		end
	end

	local FruitGoalLost = false
	if UI then
		local collected = UI.FruitCollected or 0
		local required = UI.FruitRequired or 0
		FruitGoalLost = required > 0 and collected < required
	end

	if ExitWasOpen and FruitGoalLost and Arena and Arena.ResetExit then
		Arena:ResetExit()
		if Fruit and Fruit.spawn then
			Fruit:spawn(self:GetSegments(), Rocks, self:GetSafeZone(3))
		end
	end

	if SessionStats and SessionStats.get and SessionStats.set then
		local apples = SessionStats:get("ApplesEaten") or 0
		apples = math.max(0, apples - trimmed)
		SessionStats:set("ApplesEaten", apples)
	end

	if Score and Score.AddBonus and Score.get then
		local CurrentScore = Score:get() or 0
		local deduction = math.min(CurrentScore, trimmed)
		if deduction > 0 then
			Score:AddBonus(-deduction)
		end
	end

	if (not options) or options.spawnParticles ~= false then
		local BurstColor = {1, 0.8, 0.4, 1}
		if options and options.cause == "saw" then
			BurstColor = {1, 0.6, 0.3, 1}
		end

		if Particles and Particles.SpawnBurst and TailX and TailY then
			Particles:SpawnBurst(TailX, TailY, {
				count = math.min(10, 4 + trimmed),
				speed = 120,
				SpeedVariance = 46,
				life = 0.42,
				size = 4,
				color = BurstColor,
				spread = math.pi * 2,
				drag = 3.1,
				gravity = 220,
				FadeTo = 0,
			})
		end
	end

	return trimmed
end

local function ChopTailLossAmount()
	local available = math.max(0, (SegmentCount or 1) - 1)
	if available <= 0 then
		return 0
	end

	local loss = math.floor(math.max(1, available * 0.2))
	return math.min(loss, available)
end

function Snake:ChopTailByHazard(cause)
	local loss = ChopTailLossAmount()
	if loss <= 0 then
		return 0
	end

	return self:LoseSegments(loss, { cause = cause or "saw" })
end

function Snake:ChopTailBySaw()
	return self:ChopTailByHazard("saw")
end

local function IsSawActive(saw)
	if not saw then
		return false
	end

	return not ((saw.sinkProgress or 0) > 0 or (saw.sinkTarget or 0) > 0)
end

local function GetSawCenterPosition(saw)
	if not (Saws and Saws.GetCollisionCenter) then
		return nil, nil
	end

	return Saws:GetCollisionCenter(saw)
end

local function IsSawCutPointExposed(saw, sx, sy, px, py)
	if not (saw and sx and sy and px and py) then
		return true
	end

	local tolerance = 1.0
	local nx, ny

	if saw.dir == "horizontal" then
		-- Horizontal saws sit in the floor and only the top half (negative Y)
		-- should be able to slice the snake.
		nx, ny = 0, -1
	else
		-- For vertical saws, the exposed side depends on which wall the blade
		-- is mounted to. The sink direction indicates which side is hidden in
		-- the track, so flip it to get the exposed normal.
		local SinkDir = (saw.side == "left") and -1 or 1
		nx, ny = -SinkDir, 0
	end

	local dx = px - sx
	local dy = py - sy
	local projection = dx * nx + dy * ny

	return projection >= -tolerance
end

local function AddSeveredTrail(PieceTrail, SegmentEstimate)
	if not PieceTrail or #PieceTrail <= 1 then
		return
	end

	SeveredPieces = SeveredPieces or {}
	table.insert(SeveredPieces, {
		trail = PieceTrail,
		timer = SEVERED_TAIL_LIFE,
		SegmentCount = math.max(1, SegmentEstimate or #PieceTrail),
	})
end

local function SpawnSawCutParticles(x, y, count)
	if not (Particles and Particles.SpawnBurst and x and y) then
		return
	end

	Particles:SpawnBurst(x, y, {
		count = math.min(12, 5 + (count or 0)),
		speed = 120,
		SpeedVariance = 60,
		life = 0.42,
		size = 4,
		color = {1, 0.6, 0.3, 1},
		spread = math.pi * 2,
		drag = 3.0,
		gravity = 220,
		FadeTo = 0,
	})
end

function Snake:HandleSawBodyCut(context)
	if not context then
		return false
	end

	local available = math.max(0, (SegmentCount or 1) - 1)
	if available <= 0 then
		return false
	end

	local index = context.index or 2
	if index <= 1 or index > #trail then
		return false
	end

	local PreviousIndex = index - 1
	local PreviousSegment = trail[PreviousIndex]
	if not PreviousSegment then
		return false
	end

	local CutX = context.cutX
	local CutY = context.cutY
	if not (CutX and CutY) then
		return false
	end

	local TotalLength = (SegmentCount or 1) * SEGMENT_SPACING
	local CutDistance = math.max(0, context.cutDistance or 0)
	if CutDistance <= SEGMENT_SPACING then
		return false
	end

	local TailDistance = 0
	do
		local PrevCutX, PrevCutY = CutX, CutY
		for i = index, #trail do
			local seg = trail[i]
			local sx = seg and (seg.drawX or seg.x)
			local sy = seg and (seg.drawY or seg.y)
			if sx and sy and PrevCutX and PrevCutY then
				local ddx = sx - PrevCutX
				local ddy = sy - PrevCutY
				TailDistance = TailDistance + math.sqrt(ddx * ddx + ddy * ddy)
				PrevCutX, PrevCutY = sx, sy
			end
		end
	end

	local RawSegments = TailDistance / SEGMENT_SPACING
	local LostSegments = math.max(1, math.floor(RawSegments + 0.25))
	if LostSegments > available then
		LostSegments = available
	end
	if LostSegments <= 0 then
		return false
	end

	if (TotalLength - LostSegments * SEGMENT_SPACING) < CutDistance and LostSegments > 1 then
		local adjusted = TotalLength - (LostSegments - 1) * SEGMENT_SPACING
		if adjusted >= CutDistance then
			LostSegments = LostSegments - 1
		end
	end

	local NewTail = CopySegmentData(PreviousSegment) or {}
	NewTail.drawX = CutX
	NewTail.drawY = CutY
	if PreviousSegment.x and PreviousSegment.y then
		NewTail.x = CutX
		NewTail.y = CutY
	end

	local DirX, DirY = NormalizeDirection(CutX - (PreviousSegment.drawX or PreviousSegment.x or CutX), CutY - (PreviousSegment.drawY or PreviousSegment.y or CutY))
	if (DirX == 0 and DirY == 0) and PreviousSegment then
		DirX = PreviousSegment.dirX or 0
		DirY = PreviousSegment.dirY or 0
	end
	NewTail.dirX = DirX
	NewTail.dirY = DirY
	NewTail.fruitMarker = nil
	NewTail.fruitMarkerX = nil
	NewTail.fruitMarkerY = nil

	local SeveredTrail = {}
	SeveredTrail[1] = CopySegmentData(NewTail)

	for i = index, #trail do
		local SegCopy = CopySegmentData(trail[i])
		if SegCopy then
			table.insert(SeveredTrail, SegCopy)
		end
	end

	for i = #trail, PreviousIndex + 1, -1 do
		table.remove(trail, i)
	end

	table.insert(trail, NewTail)

	AddSeveredTrail(SeveredTrail, LostSegments + 1)
	SpawnSawCutParticles(CutX, CutY, LostSegments)

	self:LoseSegments(LostSegments, { cause = "saw", TrimTrail = false })

	return true
end

function Snake:CheckSawBodyCollision()
	if IsDead then
		return false
	end

	if not (trail and #trail > 2) then
		return false
	end

	if not (Saws and Saws.GetAll) then
		return false
	end

	local saws = Saws:GetAll()
	if not (saws and #saws > 0) then
		return false
	end

	local head = trail[1]
	local HeadX = head and (head.drawX or head.x)
	local HeadY = head and (head.drawY or head.y)
	if not (HeadX and HeadY) then
		return false
	end

	local GuardDistance = SEGMENT_SPACING * 0.9
	local BodyRadius = SEGMENT_SIZE * 0.5

	for _, saw in ipairs(saws) do
		if IsSawActive(saw) then
			local sx, sy = GetSawCenterPosition(saw)
			if sx and sy then
				local SawRadius = (saw.collisionRadius or saw.radius or 0)
				local travelled = 0
				local PrevX, PrevY = HeadX, HeadY

				for index = 2, #trail do
					local segment = trail[index]
					local cx = segment and (segment.drawX or segment.x)
					local cy = segment and (segment.drawY or segment.y)
					if cx and cy then
						local dx = cx - PrevX
						local dy = cy - PrevY
						local SegLen = math.sqrt(dx * dx + dy * dy)
						local MinX = math.min(PrevX, cx) - BodyRadius
						local MinY = math.min(PrevY, cy) - BodyRadius
						local MaxX = math.max(PrevX, cx) + BodyRadius
						local MaxY = math.max(PrevY, cy) + BodyRadius
						local width = MaxX - MinX
						local height = MaxY - MinY

						if SegLen > 1e-6 and (not (Saws and Saws.IsCollisionCandidate) or Saws:IsCollisionCandidate(saw, MinX, MinY, width, height)) then
							local ClosestX, ClosestY, DistSq, t = ClosestPointOnSegment(sx, sy, PrevX, PrevY, cx, cy)
							local along = travelled + SegLen * (t or 0)
							if along > GuardDistance then
								local combined = SawRadius + BodyRadius
								if DistSq <= combined * combined and IsSawCutPointExposed(saw, sx, sy, ClosestX, ClosestY) then
									local handled = self:HandleSawBodyCut({
										index = index,
										CutX = ClosestX,
										CutY = ClosestY,
										CutDistance = along,
									})
									if handled then
										return true
									end
								end
							end
						end

						travelled = travelled + SegLen
						PrevX, PrevY = cx, cy
					end
				end
			end
		end
	end

	return false
end

function Snake:OnFruitCollected()
	FruitsSinceLastTurn = (FruitsSinceLastTurn or 0) + 1
	SessionStats:UpdateMax("FruitWithoutTurning", FruitsSinceLastTurn)
end

function Snake:MarkFruitSegment(FruitX, FruitY)
	if not trail or #trail == 0 then
		return
	end

	local TargetIndex = 1

	if FruitX and FruitY then
		local BestDistSq = math.huge
		for i = 1, #trail do
			local seg = trail[i]
			local sx = seg and (seg.drawX or seg.x)
			local sy = seg and (seg.drawY or seg.y)
			if sx and sy then
				local dx = FruitX - sx
				local dy = FruitY - sy
				local DistSq = dx * dx + dy * dy
				if DistSq < BestDistSq then
					BestDistSq = DistSq
					TargetIndex = i
					if DistSq <= 1 then
						break
					end
				end
			end
		end
	end

	local segment = trail[TargetIndex]
	if segment then
		segment.fruitMarker = true
		if FruitX and FruitY then
			segment.fruitMarkerX = FruitX
			segment.fruitMarkerY = FruitY
		else
			segment.fruitMarkerX = nil
			segment.fruitMarkerY = nil
		end
	end
end

function Snake:draw()
	if not IsDead then
		local UpgradeVisuals = CollectUpgradeVisuals(self)

		if SeveredPieces and #SeveredPieces > 0 then
			for _, piece in ipairs(SeveredPieces) do
				local TrailData = piece and piece.trail
				if TrailData and #TrailData > 1 then
					local function GetPieceHead()
						local HeadSeg = TrailData[1]
						if not HeadSeg then
							return nil, nil
						end
						return HeadSeg.drawX or HeadSeg.x, HeadSeg.drawY or HeadSeg.y
					end

					SnakeDraw.run(TrailData, piece.segmentCount or #TrailData, SEGMENT_SIZE, 0, GetPieceHead, 0, 0, nil, false)
				end
			end
		end

		local ShouldDrawFace = DescendingHole == nil
		local HideDescendingBody = DescendingHole and DescendingHole.fullyConsumed

		if not HideDescendingBody then
			SnakeDraw.run(trail, SegmentCount, SEGMENT_SIZE, PopTimer, function()
				return self:GetHead()
			end, self.CrashShields or 0, self.ShieldFlashTimer or 0, UpgradeVisuals, ShouldDrawFace)
		end

	end
end

function Snake:ResetPosition()
	self:load(ScreenW, ScreenH)
end

function Snake:GetSegments()
	local copy = {}
	for i = 1, #trail do
		local seg = trail[i]
		copy[i] = {
			DrawX = seg.drawX,
			DrawY = seg.drawY,
			DirX = seg.dirX,
			DirY = seg.dirY
		}
	end
	return copy
end

function Snake:SetDeveloperAssist(state)
	local NewState = not not state
	if DeveloperAssistEnabled == NewState then
		return DeveloperAssistEnabled
	end

	DeveloperAssistEnabled = NewState
	AnnounceDeveloperAssistChange(NewState)
	return DeveloperAssistEnabled
end

function Snake:ToggleDeveloperAssist()
	return self:SetDeveloperAssist(not DeveloperAssistEnabled)
end

function Snake:IsDeveloperAssistEnabled()
	return DeveloperAssistEnabled
end

function Snake:GetLength()
	return SegmentCount
end

return Snake
