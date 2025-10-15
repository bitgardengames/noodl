local Particles = require("particles")
local SnakeUtils = require("snakeutils")
local Theme = require("theme")
local Arena = require("arena")

local FruitTypes = {
	{
		id = "apple",
		name = "Apple",
		color = Theme.AppleColor,
		points = 1,
		weight = 70,
	},
	{
		id = "banana",
		name = "Banana",
		color = Theme.BananaColor,
		points = 3,
		weight = 20,
	},
	{
		id = "blueberry",
		name = "Blueberry",
		color = Theme.BlueberryColor,
		points = 5,
		weight = 8,
	},
	{
		id = "GoldenPear",
		name = "GoldenPear",
		color = Theme.GoldenPearColor,
		points = 10,
		weight = 2,
	},
	{
		id = "dragonfruit",
		name = "Dragonfruit",
		color = Theme.DragonfruitColor,
		points = 50,
		weight = 0.2,
	},
}

local Fruit = {}

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

local function GetHighlightColor(color)
	color = color or {1, 1, 1, 1}
	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.75
	return {r, g, b, a}
end

-- State
local active = {
	x = 0, y = 0,
	alpha = 0,
	ScaleX = 1, ScaleY = 1,
	shadow = 0.5,
	OffsetY = 0,
	type = FruitTypes[1],
	phase = "idle",
	timer = 0
}
local fading = nil
local FadeTimer = 0
local LastCollectedType = FruitTypes[1]
local IdleSparkles = {}

local function CopyColor(color)
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
local function clamp(a, lo, hi) if a < lo then return lo elseif a > hi then return hi else return a end end

local function EaseOutQuad(t)  return 1 - (1 - t)^2 end
-- Helpers
local function ChooseFruitType()
	local total = 0
	for _, f in ipairs(FruitTypes) do total = total + f.weight end
	local r, sum = love.math.random() * total, 0
	for _, f in ipairs(FruitTypes) do
		sum = sum + f.weight
		if r <= sum then return f end
	end
	return FruitTypes[1]
end

local function SpawnIdleSparkle(x, y, color)
	IdleSparkles[#IdleSparkles + 1] = {
		x = x,
		y = y,
		color = CopyColor(color),
		timer = 0,
		duration = IDLE_SPARKLE_DURATION,
		angle = love.math.random() * math.pi * 2,
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

function Fruit:spawn(trail, rocks, SafeZone)
	local cx, cy, col, row = SnakeUtils.GetSafeSpawn(trail, self, rocks, SafeZone)
	if not cx then
		col, row = Arena:GetRandomTile()
		cx, cy = Arena:GetCenterOfTile(col, row)
	end

	active.x, active.y = cx, cy
	active.col, active.row = col, row
	active.type   = ChooseFruitType()
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

	if col and row then
		SnakeUtils.SetOccupied(col, row, true)
	end

	IdleSparkles = {}
end

function Fruit:update(dt)
	if fading then
		FadeTimer = FadeTimer + dt
		local p = clamp(FadeTimer / FADE_DURATION, 0, 1)
		local e = EaseOutQuad(p)
		fading.alpha = 1 - e
		fading.scaleX = 1 - 0.2 * e
		fading.scaleY = 1 - 0.2 * e
		if p >= 1 then fading = nil end
	end

	for i = #IdleSparkles, 1, -1 do
		local sparkle = IdleSparkles[i]
		sparkle.timer = sparkle.timer + dt
		sparkle.angle = sparkle.angle + sparkle.spin * dt
		sparkle.radius = sparkle.radius + sparkle.drift * dt * 0.08
		if sparkle.timer >= sparkle.duration then
			table.remove(IdleSparkles, i)
		end
	end

	active.timer = active.timer + dt

	if active.phase == "drop" then
		local t = clamp(active.timer / DROP_DURATION, 0, 1)
		active.offsetY = -DROP_HEIGHT * (1 - EaseOutQuad(t))
		active.alpha   = EaseOutQuad(t)
		active.scaleX  = 0.9 + 0.1 * t
		active.scaleY  = 0.7 + 0.3 * t
		active.shadow  = 0.35 + 0.65 * t

		if t >= 1 then
			local col = active.type.color or {1,1,1,1}
			Particles:SpawnBurst(active.x, active.y, {
				count = love.math.random(6, 9),
				speed = 48,
				SpeedVariance = 36,
				life  = 0.35,
				size  = 3,
				color = {col[1], col[2], col[3], 1},
				spread= math.pi * 2,
				AngleJitter = math.pi,
				drag = 2.2,
				gravity = 160,
				ScaleMin = 0.55,
				ScaleVariance = 0.65,
				FadeTo = 0,
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
		local k = math.sin(t * math.pi * 2.0) * 0.06 * s
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
		local FloatPhase = math.sin((active.idleTimer or 0) * IDLE_FLOAT_SPEED)
		active.bobOffset = FloatPhase * IDLE_FLOAT_AMPLITUDE
		active.glowPulse = 0.7 + 0.3 * math.sin((active.idleTimer or 0) * IDLE_GLOW_SPEED)

		active.sparkleTimer = (active.sparkleTimer or IDLE_SPARKLE_MAX_DELAY) - dt
		if active.sparkleTimer <= 0 then
			SpawnIdleSparkle(active.x, active.y, GetHighlightColor(active.type.color))
			active.sparkleTimer = love.math.random(IDLE_SPARKLE_MIN_DELAY, IDLE_SPARKLE_MAX_DELAY)
		end
	else
		active.bobOffset = 0
		active.glowPulse = 1
	end
end

function Fruit:CheckCollisionWith(x, y, trail, rocks)
	if fading then return false end
	if active.phase == "inactive" then return false end

	local half = HITBOX_SIZE / 2
	if aabb(x - half, y - half, HITBOX_SIZE, HITBOX_SIZE,
			active.x - half, active.y - half, HITBOX_SIZE, HITBOX_SIZE) then
		LastCollectedType = active.type
		fading = {
			x = active.x,
			y = active.y,
			alpha = 1,
			ScaleX = active.scaleX,
			ScaleY = active.scaleY,
			shadow = active.shadow,
			type = active.type
		}
		FadeTimer = 0
		active.phase = "inactive"
		active.alpha = 0
		active.bobOffset = 0
		active.glowPulse = 1
		IdleSparkles = {}

		local FxColor = GetHighlightColor(active.type.color)
		Particles:SpawnBurst(active.x, active.y, {
			count = love.math.random(10, 14),
			speed = 120,
			SpeedVariance = 90,
			life = 0.45,
			size = 3.2,
			color = {FxColor[1], FxColor[2], FxColor[3], 0.95},
			spread = math.pi * 2,
			drag = 2.7,
			gravity = -60,
			FadeTo = 0,
		})
		return true
	end
	return false
end

local function DrawFruit(f)
	if f.phase == "inactive" then return end

	local x, y = f.x, f.y + (f.offsetY or 0) + (f.bobOffset or 0)
	local alpha = f.alpha or 1
	local sx, sy = f.scaleX or 1, f.scaleY or 1
	local r = HITBOX_SIZE / 2
	local segments = 32
	local pulse = f.glowPulse or 1

	-- drop shadow
	local ShadowAlpha = 0.25 * alpha * (f.shadow or 1)
	local BobStrength = (f.bobOffset or 0) / IDLE_FLOAT_AMPLITUDE
	ShadowAlpha = ShadowAlpha * (1 + math.max(0, BobStrength) * 0.4)
	local ShadowScale = 1 + math.max(0, BobStrength) * 0.12
	love.graphics.setColor(0, 0, 0, ShadowAlpha)
	love.graphics.ellipse(
		"fill",
		x + SHADOW_OFFSET,
		y + SHADOW_OFFSET + math.min(0, (f.bobOffset or 0) * 0.35),
		(r * sx + OUTLINE_SIZE * 0.5) * ShadowScale,
		(r * sy + OUTLINE_SIZE * 0.5) * ShadowScale,
		segments
	)

	-- fruit body
	local BodyColor = f.type.color
	love.graphics.setColor(BodyColor[1], BodyColor[2], BodyColor[3], alpha)
	love.graphics.ellipse("fill", x, y, r * sx, r * sy)

	-- highlight
	local highlight = GetHighlightColor(f.type.color)
	local hx = x - r * sx * 0.3
	local hy = y - r * sy * 0.35
	local hrx = r * sx * 0.55
	local hry = r * sy * 0.45
	love.graphics.push()
	love.graphics.translate(hx, hy)
	love.graphics.rotate(-0.35)
	local HighlightAlpha = (highlight[4] or 1) * alpha * (0.75 + pulse * 0.25)
	love.graphics.setColor(highlight[1], highlight[2], highlight[3], HighlightAlpha)
	love.graphics.ellipse("fill", 0, 0, hrx, hry)
	love.graphics.pop()

	if f == active and #IdleSparkles > 0 then
		love.graphics.push("all")
		love.graphics.setBlendMode("add")
		for _, sparkle in ipairs(IdleSparkles) do
			local progress = clamp(sparkle.timer / sparkle.duration, 0, 1)
			local fade = 1 - progress
			local orbit = sparkle.radius + progress * 6
			local px = x + math.cos(sparkle.angle) * orbit
			local py = y + math.sin(sparkle.angle) * orbit - progress * 6
			local GlowSize = sparkle.size * (0.6 + 0.4 * math.sin(progress * math.pi))
			local AlphaMul = 0.25 * fade * (0.6 + pulse * 0.4)

			love.graphics.setColor(sparkle.color[1], sparkle.color[2], sparkle.color[3], AlphaMul)
			love.graphics.circle("fill", px, py, GlowSize)
			love.graphics.setColor(1, 1, 1, AlphaMul * 1.6)
			love.graphics.circle("line", px, py, GlowSize * 0.9)
		end
		love.graphics.pop()
	end

	-- outline (2–3px black border)
	love.graphics.setLineWidth(OUTLINE_SIZE)
	love.graphics.setColor(0, 0, 0, alpha)
	love.graphics.ellipse("line", x, y, r * sx, r * sy)

	-- subtle spawn glow
	if (f == active) and (active.phase ~= "idle") then
		local glow = 0.18 * alpha
		local gx = (HITBOX_SIZE * math.max(sx, sy)) * 0.65
		love.graphics.setColor(1, 1, 1, glow)
		love.graphics.circle("fill", x, y, gx)
	end

	-- rare fruit flair
	if f.type.name == "Dragonfruit" and f == active then
		local t = (active.timer or 0)
		local pulse = 0.5 + 0.5 * math.sin(t * 6.0)
		love.graphics.setColor(1, 0, 1, 0.15 * pulse * alpha)
		love.graphics.circle("line", x, y, HITBOX_SIZE * 0.8 + pulse * 4)
	end
end

function Fruit:draw()
	if fading and fading.alpha > 0 then
		DrawFruit(fading)
	end
	DrawFruit(active)
end

-- Queries
function Fruit:GetPosition() return active.x, active.y end
function Fruit:GetPoints()   return LastCollectedType.points or 1 end
function Fruit:GetTypeName() return LastCollectedType.name or "Apple" end
function Fruit:GetType()     return LastCollectedType end
function Fruit:GetTile()     return active.col, active.row end

return Fruit
