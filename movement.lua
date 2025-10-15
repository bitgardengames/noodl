local Snake = require("snake")
local Audio = require("audio")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Arena = require("arena")
local Theme = require("theme")
local Particles = require("particles")
local Upgrades = require("upgrades")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Achievements = require("achievements")

local Movement = {}

function Movement:ApplyForcedDirection(DirX, DirY)
		if not (Snake and Snake.SetDirectionVector) then
				return
		end

		DirX = DirX or 0
		DirY = DirY or 0

		if DirX == 0 and DirY == 0 then
				return
		end

		Snake:SetDirectionVector(DirX, DirY)
end

local SEGMENT_SIZE = 24 -- same size as rocks and snake
local DAMAGE_GRACE = 0.35
local WALL_GRACE = 0.25

local ShieldStatMap = {
		wall = {
				lifetime = "ShieldWallBounces",
				run = "RunShieldWallBounces",
				achievements = { "WallRicochet" },
		},
		rock = {
				lifetime = "ShieldRockBreaks",
				run = "RunShieldRockBreaks",
				achievements = { "RockShatter" },
		},
		saw = {
				lifetime = "ShieldSawParries",
				run = "RunShieldSawParries",
				achievements = { "SawParry" },
		},
		laser = {
				lifetime = "ShieldSawParries",
				run = "RunShieldSawParries",
				achievements = { "SawParry" },
		},
		dart = {
				lifetime = "ShieldSawParries",
				run = "RunShieldSawParries",
				achievements = { "SawParry" },
		},
}

local function RecordShieldEvent(cause)
		local info = ShieldStatMap[cause]
		if not info then
				return
		end

		if info.run then
				SessionStats:add(info.run, 1)
		end

		if info.lifetime then
				PlayerStats:add(info.lifetime, 1)
		end

		if info.achievements then
				for _, AchievementId in ipairs(info.achievements) do
						Achievements:check(AchievementId)
				end
		end

		Achievements:check("ShieldTriad")
end

-- AABB collision check
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
		return ax < bx + bw and ax + aw > bx and
					ay < by + bh and ay + ah > by
end

local function RerouteAlongWall(HeadX, HeadY)
		local ax, ay, aw, ah = Arena:GetBounds()
		local inset = Arena.TileSize / 2
		local left = ax + inset
		local right = ax + aw - inset
		local top = ay + inset
		local bottom = ay + ah - inset

		local ClampedX = math.max(left + 1, math.min(right - 1, HeadX or left))
		local ClampedY = math.max(top + 1, math.min(bottom - 1, HeadY or top))

		local HitLeft = (HeadX or ClampedX) <= left
		local HitRight = (HeadX or ClampedX) >= right
		local HitTop = (HeadY or ClampedY) <= top
		local HitBottom = (HeadY or ClampedY) >= bottom

		local dir = Snake:GetDirection() or { x = 0, y = 0 }
		local NewDirX, NewDirY = dir.x or 0, dir.y or 0

		local function FallbackVertical()
				if dir.y and dir.y ~= 0 then
						return dir.y > 0 and 1 or -1
				end
				local CenterY = ay + ah / 2
				if ClampedY <= CenterY then
						return 1
				end
				return -1
		end

		local function FallbackHorizontal()
				if dir.x and dir.x ~= 0 then
						return dir.x > 0 and 1 or -1
				end
				local CenterX = ax + aw / 2
				if ClampedX <= CenterX then
						return 1
				end
				return -1
		end

		local CollidedHorizontal = HitLeft or HitRight
		local CollidedVertical = HitTop or HitBottom
		local HorizontalDominant = math.abs(dir.x or 0) >= math.abs(dir.y or 0)

		if CollidedHorizontal and CollidedVertical then
				if HorizontalDominant then
						NewDirX = 0
						local slide = FallbackVertical()
						if HitTop and slide < 0 then
								slide = 1
						elseif HitBottom and slide > 0 then
								slide = -1
						end
						NewDirY = slide
				else
						NewDirY = 0
						local slide = FallbackHorizontal()
						if HitLeft and slide < 0 then
								slide = 1
						elseif HitRight and slide > 0 then
								slide = -1
						end
						NewDirX = slide
				end
		else
				if CollidedHorizontal then
						NewDirX = 0
						local slide = FallbackVertical()
						if HitTop and slide < 0 then
								slide = 1
						elseif HitBottom and slide > 0 then
								slide = -1
						end
						NewDirY = slide
				end

				if CollidedVertical then
						NewDirY = 0
						local slide = FallbackHorizontal()
						if HitLeft and slide < 0 then
								slide = 1
						elseif HitRight and slide > 0 then
								slide = -1
						end
						NewDirX = slide
				end
		end

		if NewDirX == 0 and NewDirY == 0 then
				if HitLeft and not HitRight then
						NewDirX = 1
				elseif HitRight and not HitLeft then
						NewDirX = -1
				elseif HitTop and not HitBottom then
						NewDirY = 1
				elseif HitBottom and not HitTop then
						NewDirY = -1
				else
						if dir.x and dir.x ~= 0 then
								NewDirX = dir.x > 0 and 1 or -1
						elseif dir.y and dir.y ~= 0 then
								NewDirY = dir.y > 0 and 1 or -1
						else
								NewDirY = 1
						end
				end
		end

		Movement:ApplyForcedDirection(NewDirX, NewDirY)

		return ClampedX, ClampedY
end

local function clamp(value, min, max)
		if min and value < min then
				return min
		end
		if max and value > max then
				return max
		end
		return value
end

local function PortalThroughWall(HeadX, HeadY)
		if not (Upgrades and Upgrades.GetEffect and Upgrades:GetEffect("WallPortal")) then
				return nil, nil
		end

		local ax, ay, aw, ah = Arena:GetBounds()
		local inset = Arena.TileSize / 2
		local left = ax + inset
		local right = ax + aw - inset
		local top = ay + inset
		local bottom = ay + ah - inset

		local OutLeft = HeadX < left
		local OutRight = HeadX > right
		local OutTop = HeadY < top
		local OutBottom = HeadY > bottom

		if not (OutLeft or OutRight or OutTop or OutBottom) then
				return nil, nil
		end

		local HorizontalDist = 0
		if OutLeft then
				HorizontalDist = left - HeadX
		elseif OutRight then
				HorizontalDist = HeadX - right
		end

		local VerticalDist = 0
		if OutTop then
				VerticalDist = top - HeadY
		elseif OutBottom then
				VerticalDist = HeadY - bottom
		end

		local EntryX = clamp(HeadX, left, right)
		local EntryY = clamp(HeadY, top, bottom)

		local margin = math.max(4, math.floor(Arena.TileSize * 0.3))
		local function InsideX(x)
				return clamp(x, left + margin, right - margin)
		end

		local function InsideY(y)
				return clamp(y, top + margin, bottom - margin)
		end

		local ExitX, ExitY
		if HorizontalDist >= VerticalDist then
				if OutLeft then
						ExitX = InsideX(right - margin)
				else
						ExitX = InsideX(left + margin)
				end
				ExitY = InsideY(HeadY)
		else
				if OutTop then
						ExitY = InsideY(bottom - margin)
				else
						ExitY = InsideY(top + margin)
				end
				ExitX = InsideX(HeadX)
		end

		local dx = (ExitX or HeadX) - HeadX
		local dy = (ExitY or HeadY) - HeadY

		if dx == 0 and dy == 0 then
				return nil, nil
		end

		if Snake.translate then
				Snake:translate(dx, dy)
		else
				Snake:SetHeadPosition(HeadX + dx, HeadY + dy)
		end

		local NewHeadX, NewHeadY = Snake:GetHead()

		if Particles then
				Particles:SpawnBurst(EntryX, EntryY, {
						count = 18,
						speed = 120,
						SpeedVariance = 80,
						life = 0.5,
						size = 5,
						color = {0.9, 0.75, 0.3, 1},
						spread = math.pi * 2,
						FadeTo = 0.1,
				})
				Particles:SpawnBurst(NewHeadX, NewHeadY, {
						count = 22,
						speed = 150,
						SpeedVariance = 90,
						life = 0.55,
						size = 5,
						color = {1.0, 0.88, 0.4, 1},
						spread = math.pi * 2,
						FadeTo = 0.05,
				})
		end

		return NewHeadX, NewHeadY
end

local function HandleWallCollision(HeadX, HeadY)
		if Arena:IsInside(HeadX, HeadY) then
				return HeadX, HeadY
		end

		local PortalX, PortalY = PortalThroughWall(HeadX, HeadY)
		if PortalX and PortalY then
				Audio:PlaySound("wall_portal")
				return PortalX, PortalY
		end

		local ax, ay, aw, ah = Arena:GetBounds()
		local inset = Arena.TileSize / 2
		local left = ax + inset
		local right = ax + aw - inset
		local top = ay + inset
		local bottom = ay + ah - inset

		if not Snake:ConsumeCrashShield() then
				local SafeX = clamp(HeadX, left, right)
				local SafeY = clamp(HeadY, top, bottom)
				local ReroutedX, ReroutedY = RerouteAlongWall(SafeX, SafeY)
				local ClampedX = ReroutedX or SafeX
				local ClampedY = ReroutedY or SafeY
				if Snake and Snake.SetHeadPosition then
						Snake:SetHeadPosition(ClampedX, ClampedY)
				end
				local dir = Snake.GetDirection and Snake:GetDirection() or { x = 0, y = 0 }

				return ClampedX, ClampedY, "wall", {
						PushX = 0,
						PushY = 0,
						SnapX = ClampedX,
						SnapY = ClampedY,
						DirX = dir.x or 0,
						DirY = dir.y or 0,
						grace = WALL_GRACE,
						shake = 0.2,
				}
		end

		local ReroutedX, ReroutedY = RerouteAlongWall(HeadX, HeadY)
		local ClampedX = ReroutedX or clamp(HeadX, left, right)
		local ClampedY = ReroutedY or clamp(HeadY, top, bottom)
		if Snake and Snake.SetHeadPosition then
				Snake:SetHeadPosition(ClampedX, ClampedY)
		end
		HeadX, HeadY = ClampedX, ClampedY

		Particles:SpawnBurst(HeadX, HeadY, {
				count = 12,
				speed = 70,
				SpeedVariance = 55,
				life = 0.45,
				size = 4,
				color = {0.55, 0.85, 1, 1},
				spread = math.pi * 2,
				AngleJitter = math.pi * 0.75,
				drag = 3.2,
				gravity = 180,
				ScaleMin = 0.5,
				ScaleVariance = 0.75,
				FadeTo = 0,
		})

		Audio:PlaySound("shield_wall")

		if Snake.OnShieldConsumed then
				Snake:OnShieldConsumed(HeadX, HeadY, "wall")
		end

		RecordShieldEvent("wall")

		return HeadX, HeadY
end

local function HandleRockCollision(HeadX, HeadY)
		for _, rock in ipairs(Rocks:GetAll()) do
				if aabb(HeadX, HeadY, SEGMENT_SIZE, SEGMENT_SIZE, rock.x, rock.y, rock.w, rock.h) then
						local CenterX = rock.x + rock.w / 2
						local CenterY = rock.y + rock.h / 2

						if Snake.IsDashActive and Snake:IsDashActive() then
								Rocks:destroy(rock)
								Particles:SpawnBurst(CenterX, CenterY, {
										count = 10,
										speed = 120,
										SpeedVariance = 70,
										life = 0.35,
										size = 4,
										color = {1.0, 0.78, 0.32, 1},
										spread = math.pi * 2,
										AngleJitter = math.pi * 0.6,
										drag = 3.0,
										gravity = 180,
										ScaleMin = 0.5,
										ScaleVariance = 0.6,
										FadeTo = 0.05,
								})
								Audio:PlaySound("shield_rock")
								if Snake.OnDashBreakRock then
										Snake:OnDashBreakRock(CenterX, CenterY)
								end
						else
								local context = {
										PushX = 0,
										PushY = 0,
										grace = DAMAGE_GRACE,
										shake = 0.35,
								}

								local shielded = Snake:ConsumeCrashShield()

								if not shielded then
										Rocks:TriggerHitFlash(rock)
										return "hit", "rock", context
								end

								Rocks:destroy(rock)
								context.damage = 0

								Particles:SpawnBurst(CenterX, CenterY, {
										count = 8,
										speed = 40,
										SpeedVariance = 36,
										life = 0.4,
										size = 3,
										color = {0.9, 0.8, 0.5, 1},
										spread = math.pi * 2,
										AngleJitter = math.pi * 0.8,
										drag = 2.8,
										gravity = 210,
										ScaleMin = 0.55,
										ScaleVariance = 0.5,
										FadeTo = 0.05,
								})
								Audio:PlaySound("shield_rock")

								if Snake.OnShieldConsumed then
										Snake:OnShieldConsumed(CenterX, CenterY, "rock")
								end

								RecordShieldEvent("rock")

								return "hit", "rock", context
						end

						break
				end
		end
end

local function HandleSawCollision(HeadX, HeadY)
		if Snake:IsHazardGraceActive() then
				return
		end

		local SawHit = Saws:CheckCollision(HeadX, HeadY, SEGMENT_SIZE, SEGMENT_SIZE)
		if not SawHit then
				return
		end

		local shielded = Snake:ConsumeCrashShield()
		local SurvivedSaw = shielded

		if not SurvivedSaw and Snake.ConsumeStoneSkinSawGrace then
				SurvivedSaw = Snake:ConsumeStoneSkinSawGrace()
		end

		if not SurvivedSaw then
				local PushX, PushY = 0, 0
				local NormalX, NormalY = 0, -1
				if Saws.GetCollisionCenter then
						local sx, sy = Saws:GetCollisionCenter(SawHit)
						if sx and sy then
								local dx = (HeadX or sx) - sx
								local dy = (HeadY or sy) - sy
								local dist = math.sqrt(dx * dx + dy * dy)
								local PushDist = SEGMENT_SIZE
								if dist > 1e-4 then
										NormalX = dx / dist
										NormalY = dy / dist
										PushX = NormalX * PushDist
										PushY = NormalY * PushDist
								end
						end
				end

				if Particles and Particles.SpawnBlood then
						Particles:SpawnBlood(HeadX, HeadY, {
								DirX = NormalX,
								DirY = NormalY,
						})
				end

				return "hit", "saw", {
						PushX = PushX,
						PushY = PushY,
						grace = DAMAGE_GRACE,
						shake = 0.4,
				}
		end

		Saws:destroy(SawHit)

                Particles:SpawnBurst(HeadX, HeadY, {
                                count = 8,
                                speed = 48,
                                SpeedVariance = 36,
                                life = 0.32,
                                size = 2.2,
                                color = {1.0, 0.9, 0.45, 1},
                                spread = math.pi * 2,
                                AngleJitter = math.pi * 0.9,
                                drag = 3.2,
                                gravity = 240,
                                ScaleMin = 0.4,
                                ScaleVariance = 0.45,
                                FadeTo = 0.05,
                })
		Audio:PlaySound("shield_saw")

		if Snake.OnShieldConsumed then
				Snake:OnShieldConsumed(HeadX, HeadY, "saw")
		end

		Snake:BeginHazardGrace()

		if Snake.ChopTailBySaw then
				Snake:ChopTailBySaw()
		end

		if shielded then
				RecordShieldEvent("saw")
		end

		return
end

local function HandleLaserCollision(HeadX, HeadY)
		if not Lasers or not Lasers.CheckCollision then
				return
		end

		if Snake:IsHazardGraceActive() then
				return
		end

		local LaserHit = Lasers:CheckCollision(HeadX, HeadY, SEGMENT_SIZE, SEGMENT_SIZE)
		if not LaserHit then
				return
		end

		local shielded = Snake:ConsumeCrashShield()
		local survived = shielded

		if not survived and Snake.ConsumeStoneSkinSawGrace then
				survived = Snake:ConsumeStoneSkinSawGrace()
		end

		if not survived then
				local PushX, PushY = 0, 0
				if LaserHit then
						local lx = LaserHit.impactX or LaserHit.x or HeadX
						local ly = LaserHit.impactY or LaserHit.y or HeadY
						local dx = (HeadX or lx) - lx
						local dy = (HeadY or ly) - ly
						local dist = math.sqrt(dx * dx + dy * dy)
						local PushDist = SEGMENT_SIZE
						if dist > 1e-4 then
								PushX = (dx / dist) * PushDist
								PushY = (dy / dist) * PushDist
						end
				end

				return "hit", "laser", {
						PushX = PushX,
						PushY = PushY,
						grace = DAMAGE_GRACE,
						shake = 0.32,
				}
		end

		Lasers:OnShieldedHit(LaserHit, HeadX, HeadY)

		Particles:SpawnBurst(HeadX, HeadY, {
				count = 10,
				speed = 80,
				SpeedVariance = 30,
				life = 0.25,
				size = 2.5,
				color = {1.0, 0.55, 0.25, 1},
				spread = math.pi * 2,
				AngleJitter = math.pi,
				drag = 3.4,
				gravity = 120,
				ScaleMin = 0.45,
				ScaleVariance = 0.4,
				FadeTo = 0,
		})

		Audio:PlaySound("shield_saw")

		if Snake.OnShieldConsumed then
				Snake:OnShieldConsumed(HeadX, HeadY, "laser")
		end

		if Snake.ChopTailByHazard then
				Snake:ChopTailByHazard("laser")
		elseif Snake.ChopTailBySaw then
				Snake:ChopTailBySaw()
		end

		Snake:BeginHazardGrace()

		if shielded then
				RecordShieldEvent("laser")
		end

		return
end

local function HandleDartCollision(HeadX, HeadY)
		if not Darts or not Darts.CheckCollision then
				return
		end

		if Snake:IsHazardGraceActive() then
				return
		end

		local DartHit = Darts:CheckCollision(HeadX, HeadY, SEGMENT_SIZE, SEGMENT_SIZE)
		if not DartHit then
				return
		end

		local shielded = Snake:ConsumeCrashShield()
		local survived = shielded

		if not survived and Snake.ConsumeStoneSkinSawGrace then
				survived = Snake:ConsumeStoneSkinSawGrace()
		end

		if not survived then
				if Particles and Particles.SpawnBlood then
						local ImpactX = DartHit.x or HeadX
						local ImpactY = DartHit.y or HeadY
						Particles:SpawnBlood(ImpactX, ImpactY, {
								DirX = DartHit.dirX or 0,
								DirY = DartHit.dirY or 0,
						})
				end

				local PushDist = SEGMENT_SIZE
				local PushX = -(DartHit.dirX or 0) * PushDist
				local PushY = -(DartHit.dirY or 0) * PushDist

				return "hit", "dart", {
						PushX = PushX,
						PushY = PushY,
						grace = DAMAGE_GRACE,
						shake = 0.3,
				}
		end

		Darts:OnShieldedHit(DartHit, HeadX, HeadY)

		Particles:SpawnBurst(HeadX, HeadY, {
				count = 9,
				speed = 88,
				SpeedVariance = 36,
				life = 0.28,
				size = 2.6,
				color = Theme and Theme.LaserColor or {1.0, 0.5, 0.3, 1},
				spread = math.pi * 2,
				AngleJitter = math.pi,
				drag = 3.1,
				gravity = 120,
				ScaleMin = 0.42,
				ScaleVariance = 0.36,
				FadeTo = 0,
		})

		Audio:PlaySound("shield_saw")

		if Snake.OnShieldConsumed then
				Snake:OnShieldConsumed(HeadX, HeadY, "dart")
		end

		if Snake.ChopTailByHazard then
				Snake:ChopTailByHazard("dart")
		elseif Snake.ChopTailBySaw then
				Snake:ChopTailBySaw()
		end

		Snake:BeginHazardGrace()

		if shielded then
				RecordShieldEvent("dart")
		end

		return
end

function Movement:reset()
		Snake:ResetPosition()
end

function Movement:update(dt)
		local alive, cause, context = Snake:update(dt)
		if not alive then
				if context and context.fatal then
						return "dead", cause or "self", context
				end
				return "hit", cause or "self", context
		end

		local HeadX, HeadY = Snake:GetHead()

		local WallCause, WallContext
		HeadX, HeadY, WallCause, WallContext = HandleWallCollision(HeadX, HeadY)
		if WallCause then
				return "hit", WallCause, WallContext
		end

		local state, StateCause, StateContext = HandleRockCollision(HeadX, HeadY)
		if state then
				return state, StateCause, StateContext
		end

		local LaserState, LaserCause, LaserContext = HandleLaserCollision(HeadX, HeadY)
		if LaserState then
				return LaserState, LaserCause, LaserContext
		end

		local DartState, DartCause, DartContext = HandleDartCollision(HeadX, HeadY)
		if DartState then
				return DartState, DartCause, DartContext
		end

		local SawState, SawCause, SawContext = HandleSawCollision(HeadX, HeadY)
		if SawState then
				return SawState, SawCause, SawContext
		end

		if Snake.CheckSawBodyCollision then
				Snake:CheckSawBodyCollision()
		end

		if Fruit:CheckCollisionWith(HeadX, HeadY) then
				return "scored"
		end
end

return Movement
