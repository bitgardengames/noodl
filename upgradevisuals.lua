local UpgradeVisuals = {}
UpgradeVisuals.effects = {}

local max = math.max
local pi = math.pi
local cos = math.cos
local sin = math.sin
local random = love.math.random

local function clamp(value)
        if value <= 0 then
                return 0
        end
        if value >= 1 then
                return 1
        end
	return value
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

local function drawShieldBadge(effect, progress)
	local badgeColor = effect.badgeColor
	if not badgeColor then return end

        local alpha = (badgeColor[4] or 1) * clamp(1 - progress * 1.1)
	if alpha <= 0 then return end

	local pulse = 1 + 0.05 * sin(progress * pi * 6)
	local baseRadius = (effect.outerRadius or 42) * 0.32 * (effect.badgeScale or 1)
	local width = baseRadius * pulse
	local height = width * 1.4
	local x, y = effect.x, effect.y

	local vertices = {
		x, y - height,
		x + width * 0.7, y - height * 0.25,
		x + width * 0.45, y + height * 0.85,
		x, y + height * 1.05,
		x - width * 0.45, y + height * 0.85,
		x - width * 0.7, y - height * 0.25,
	}

	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha * 0.75)
	love.graphics.polygon("fill", vertices)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha)
	love.graphics.polygon("line", vertices)
end

local function drawBurstBadge(effect, progress)
	local badgeColor = effect.badgeColor
	if not badgeColor then return end

        local alpha = (badgeColor[4] or 1) * clamp(1 - progress * 1.05)
	if alpha <= 0 then return end

	local points = 5
	local baseRadius = (effect.outerRadius or 42) * 0.34 * (effect.badgeScale or 1)
	local innerRadius = baseRadius * 0.45
	local angleOffset = (effect.rotation or 0) + progress * pi * 2 * 0.35

	local vertices = {}
	for i = 0, points * 2 - 1 do
		local radius = (i % 2 == 0) and baseRadius or innerRadius
		local angle = angleOffset + i * (pi / points)
		vertices[#vertices + 1] = effect.x + cos(angle) * radius
		vertices[#vertices + 1] = effect.y + sin(angle) * radius
	end

	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha * 0.8)
	love.graphics.polygon("fill", vertices)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha)
	love.graphics.polygon("line", vertices)
end

local function drawSparkBadge(effect, progress)
	local badgeColor = effect.badgeColor
	if not badgeColor then return end

        local alpha = (badgeColor[4] or 1) * clamp(1 - progress * 1.2)
	if alpha <= 0 then return end

	local rotation = (effect.rotation or 0) + progress * pi * 0.8
	local radius = (effect.outerRadius or 42) * 0.36 * (effect.badgeScale or 1)
	local thickness = radius * 0.3
	local x, y = effect.x, effect.y

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(rotation)
	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha * 0.7)
	love.graphics.rectangle("fill", -radius, -thickness * 0.5, radius * 2, thickness)
	love.graphics.rectangle("fill", -thickness * 0.5, -radius, thickness, radius * 2)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(badgeColor[1], badgeColor[2], badgeColor[3], alpha)
	love.graphics.rectangle("line", -radius, -thickness * 0.5, radius * 2, thickness)
	love.graphics.rectangle("line", -thickness * 0.5, -radius, thickness, radius * 2)
	love.graphics.pop()
end

local badgeDrawers = {
	shield = drawShieldBadge,
	burst = drawBurstBadge,
	star = drawBurstBadge,
	combo = drawBurstBadge,
	spark = drawSparkBadge,
}

function UpgradeVisuals:spawn(x, y, options)
	if not x or not y then return end
	options = options or {}

	local effect = {
		x = x,
		y = y,
		age = 0,
		life = options.life and max(0.05, options.life) or 0.72,
		color = copyColor(options.color),
		glowColor = copyColor(options.glowColor or options.color),
		haloColor = copyColor(options.haloColor or options.color),
		badgeColor = copyColor(options.badgeColor or options.color),
		badgeScale = options.badgeScale or 1,
		badge = options.badge,
		rotation = options.rotation or random() * pi * 2,
		ringCount = max(1, math.floor(options.ringCount or 2)),
		ringSpacing = options.ringSpacing or 10,
		ringWidth = options.ringWidth or 4,
		pulseDelay = options.pulseDelay or 0.12,
		innerRadius = options.innerRadius or 12,
		outerRadius = options.outerRadius or options.radius or 44,
		variant = options.variant or "pulse",
		glowAlpha = options.glowAlpha,
		haloAlpha = options.haloAlpha,
		addBlend = options.addBlend ~= false,
	}

	effect.outerRadius = math.max(effect.outerRadius or 0, effect.innerRadius + 6)
	if options.outerRadius and options.radius then
		effect.outerRadius = options.outerRadius
	elseif options.radius and not options.outerRadius then
		effect.outerRadius = math.max(effect.innerRadius + 6, options.radius)
	end

	effect.glowColor[4] = options.glowAlpha or (effect.glowColor[4] or 1) * 0.24
	effect.haloColor[4] = options.haloAlpha or (effect.haloColor[4] or 1) * 0.12
	effect.badgeColor[4] = effect.badgeColor[4] or 1

	self.effects[#self.effects + 1] = effect
end

function UpgradeVisuals:update(dt)
	if dt <= 0 then return end

	for i = #self.effects, 1, -1 do
		local effect = self.effects[i]
		effect.age = effect.age + dt
		if effect.age >= effect.life then
			table.remove(self.effects, i)
		end
	end
end

local function drawBadge(effect, progress)
	if not effect.badge then return end
	local drawer = badgeDrawers[effect.badge]
	if not drawer then return end
	drawer(effect, progress)
end

local function drawRings(effect, progress)
	local color = effect.color or {1, 1, 1, 1}
	local ringCount = effect.ringCount or 1
	local ringSpacing = effect.ringSpacing or 10
	local outerRadius = effect.outerRadius or 44
	local innerRadius = effect.innerRadius or 12
	local pulseDelay = effect.pulseDelay or 0.12

	for index = 1, ringCount do
		local delay = (index - 1) * pulseDelay
                local ringProgress = clamp((progress - delay) / (1 - delay))
		if ringProgress > 0 then
			local eased = ringProgress * ringProgress
			local radius = innerRadius + (outerRadius - innerRadius) * eased + (index - 1) * ringSpacing
                        local alpha = (color[4] or 1) * clamp(1.1 - ringProgress * 1.1)
			if alpha > 0 then
				love.graphics.setLineWidth((effect.ringWidth or 4) * (1 - 0.35 * eased))
				love.graphics.setColor(color[1], color[2], color[3], alpha)
				love.graphics.circle("line", effect.x, effect.y, radius, 48)
			end
		end
	end

	love.graphics.setLineWidth(1)
end

local function drawGlow(effect, progress)
	if not effect.addBlend then return end
	love.graphics.setBlendMode("add")

	local haloColor = effect.haloColor
	if haloColor and (haloColor[4] or 0) > 0 then
        local haloAlpha = haloColor[4] * clamp(1 - progress)
		if haloAlpha > 0 then
			love.graphics.setColor(haloColor[1], haloColor[2], haloColor[3], haloAlpha)
			love.graphics.circle("fill", effect.x, effect.y, (effect.outerRadius or 44) * (0.4 + progress * 0.45), 36)
		end
	end

	local glowColor = effect.glowColor
	if glowColor and (glowColor[4] or 0) > 0 then
        local glowAlpha = glowColor[4] * clamp(1 - progress * 0.8)
		if glowAlpha > 0 then
			local pulse = 0.9 + 0.2 * sin(progress * pi * 4)
			love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowAlpha)
			love.graphics.circle("fill", effect.x, effect.y, (effect.innerRadius or 12) * (1.4 + 0.6 * pulse), 24)
		end
	end

	love.graphics.setBlendMode("alpha")
end

function UpgradeVisuals:draw()
	if not love or not love.graphics then return end
	if #self.effects == 0 then return end

	love.graphics.push("all")

	for _, effect in ipairs(self.effects) do
                local progress = clamp(effect.age / effect.life)
		drawGlow(effect, progress)
		drawRings(effect, progress)
		drawBadge(effect, progress)
	end

	love.graphics.pop()
end

function UpgradeVisuals:reset()
	self.effects = {}
end

function UpgradeVisuals:isEmpty()
	return #self.effects == 0
end

return UpgradeVisuals
