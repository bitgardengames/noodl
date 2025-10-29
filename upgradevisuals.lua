local RenderLayers = require("renderlayers")

local floor = math.floor

local UpgradeVisuals = {}
UpgradeVisuals.effects = {}

local max = math.max
local pi = math.pi
local cos = math.cos
local sin = math.sin
local random = love.math.random

local function clamp01(value)
	if value <= 0 then
		return 0
	end
	if value >= 1 then
		return 1
	end
	return value
end

local function deepcopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepcopy(v)
	end

	return copy
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

local function copyOptionalColor(color)
	if not color then
		return nil
	end

	return copyColor(color)
end

local function drawShieldBadge(effect, progress)
	local badgeColor = effect.badgeColor
	if not badgeColor then return end

	local alpha = (badgeColor[4] or 1) * clamp01(1 - progress * 1.1)
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

	local alpha = (badgeColor[4] or 1) * clamp01(1 - progress * 1.05)
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

	local alpha = (badgeColor[4] or 1) * clamp01(1 - progress * 1.2)
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
		ringCount = max(1, floor(options.ringCount or 2)),
		ringSpacing = options.ringSpacing or 10,
		ringWidth = options.ringWidth or 4,
		pulseDelay = options.pulseDelay or 0.12,
		innerRadius = options.innerRadius or 12,
		outerRadius = options.outerRadius or options.radius or 44,
		variant = options.variant or "pulse",
		variantColor = copyOptionalColor(options.variantColor),
		variantSecondaryColor = copyOptionalColor(options.variantSecondaryColor),
		variantTertiaryColor = copyOptionalColor(options.variantTertiaryColor),
		variantData = options.variantData and deepcopy(options.variantData) or nil,
		showBase = options.showBase ~= false,
		glowAlpha = options.glowAlpha,
		haloAlpha = options.haloAlpha,
		addBlend = options.addBlend ~= false,
	}

	effect.outerRadius = max(effect.outerRadius or 0, effect.innerRadius + 6)
	if options.outerRadius and options.radius then
		effect.outerRadius = options.outerRadius
	elseif options.radius and not options.outerRadius then
		effect.outerRadius = max(effect.innerRadius + 6, options.radius)
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

local function drawFangFlurry(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local baseColor = effect.variantColor or effect.color or {1.0, 0.62, 0.42, 1}
	local highlightColor = effect.variantSecondaryColor or {1.0, 0.9, 0.74, 0.92}
	local slashColor = effect.variantTertiaryColor or {1.0, 0.46, 0.26, 0.78}

	local baseAlpha = (baseColor[4] or 1) * clamp01(1.1 - progress * 1.25)
	if baseAlpha <= 0 then return end

	local fangCount = (effect.variantData and effect.variantData.fangs) or 6
	local rotation = (effect.rotation or 0) + progress * pi * 0.8

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local pulse = 0.9 + 0.18 * sin(progress * pi * 4.2)
	love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], (highlightColor[4] or 1) * baseAlpha * 0.4)
	love.graphics.circle("fill", x, y, innerRadius * (0.6 + 0.25 * pulse), 24)

	for index = 1, fangCount do
		local offset = (index - 1) / fangCount
		local angle = rotation + offset * pi * 2
		local sway = sin(progress * pi * (4 + index * 0.35)) * 0.18
		angle = angle + sway * 0.18

		local dirX, dirY = cos(angle), sin(angle)
		local perpX, perpY = -dirY, dirX

		local tipRadius = innerRadius + (outerRadius - innerRadius) * (0.82 + 0.12 * sin(progress * pi * 5 + index))
		local baseRadius = innerRadius * (0.55 + 0.2 * cos(progress * pi * 3 + index))
		local width = innerRadius * (0.16 + 0.1 * (1 - progress))
		local outlineWidth = 0.8 + 0.5 * (1 - progress)

		local baseX = x + dirX * baseRadius
		local baseY = y + dirY * baseRadius
		local tipX = x + dirX * tipRadius
		local tipY = y + dirY * tipRadius
		local leftX = baseX + perpX * width
		local leftY = baseY + perpY * width
		local rightX = baseX - perpX * width
		local rightY = baseY - perpY * width

		local fade = 1 - offset * 0.2
		love.graphics.setLineWidth(outlineWidth)
		love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseAlpha * (0.75 + 0.25 * fade))
		love.graphics.polygon("line", leftX, leftY, tipX, tipY, rightX, rightY)

		love.graphics.setLineWidth(outlineWidth * 0.7)
		love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], (highlightColor[4] or 1) * baseAlpha * 0.85 * fade)
		love.graphics.line(leftX, leftY, tipX, tipY)
		love.graphics.line(rightX, rightY, tipX, tipY)

		local slashRadius = tipRadius + innerRadius * (0.28 + 0.18 * (1 - progress))
		local slashWidth = 0.18 + 0.12 * (1 - progress)
		love.graphics.setLineWidth(2.4)
		love.graphics.setColor(slashColor[1], slashColor[2], slashColor[3], (slashColor[4] or 1) * baseAlpha * 0.65 * fade)
		love.graphics.arc("line", "open", x, y, slashRadius, angle - slashWidth, angle + slashWidth, 14)
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawExtraBiteChomp(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local fruitColor = effect.variantColor or effect.color or {1.0, 0.82, 0.36, 1}
	local toothColor = effect.variantSecondaryColor or {1.0, 1.0, 1.0, 0.92}
	local crumbColor = effect.variantTertiaryColor or {1.0, 0.62, 0.28, 0.82}

	local fruitAlpha = (fruitColor[4] or 1) * clamp01(1.08 - progress * 1.2)
	if fruitAlpha <= 0 then return end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local pulse = 0.94 + 0.16 * sin(progress * pi * 4.4)
	local bodyRadius = outerRadius * (0.52 + 0.12 * (1 - progress)) * pulse
	love.graphics.setColor(fruitColor[1], fruitColor[2], fruitColor[3], fruitAlpha * 0.85)
	love.graphics.circle("fill", x, y, bodyRadius, 40)

	love.graphics.setLineWidth(innerRadius * 0.22)
	love.graphics.setColor(fruitColor[1], fruitColor[2], fruitColor[3], fruitAlpha * 0.6)
	love.graphics.circle("line", x, y, bodyRadius * (0.86 + 0.1 * sin(progress * pi * 3.6)), 36)

	local biteRadius = bodyRadius * (0.72 + 0.05 * sin(progress * pi * 5.1))
	local biteDepth = innerRadius * (0.85 + 0.25 * progress)
	local toothCount = (effect.variantData and effect.variantData.teeth) or 4
	for index = 1, toothCount do
		local offset = (index - 0.5) / toothCount
		local angle = (effect.rotation or 0) + offset * pi * 2 + sin(progress * pi * (3.4 + index * 0.15)) * 0.08
		local dirX, dirY = cos(angle), sin(angle)
		local perpX, perpY = -dirY, dirX

		local baseX = x + dirX * biteRadius
		local baseY = y + dirY * biteRadius
		local tipX = x + dirX * (biteRadius + biteDepth)
		local tipY = y + dirY * (biteRadius + biteDepth)
		local width = innerRadius * (0.62 + 0.16 * sin(progress * pi * 4.6 + index))

		local points = {
			baseX + perpX * width * 0.45, baseY + perpY * width * 0.45,
			tipX, tipY,
			baseX - perpX * width * 0.45, baseY - perpY * width * 0.45,
		}

		love.graphics.setColor(toothColor[1], toothColor[2], toothColor[3], (toothColor[4] or 1) * fruitAlpha)
		love.graphics.polygon("fill", points)

		love.graphics.setLineWidth(innerRadius * 0.16)
		love.graphics.setColor(toothColor[1], toothColor[2], toothColor[3], (toothColor[4] or 1) * fruitAlpha * 0.9)
		love.graphics.polygon("line", points)
	end

	local crumbAlpha = (crumbColor[4] or 1) * clamp01(1 - progress * 1.3) * fruitAlpha
	if crumbAlpha > 0 then
		love.graphics.setColor(crumbColor[1], crumbColor[2], crumbColor[3], crumbAlpha)
		local crumbCount = 6
		for index = 1, crumbCount do
			local angle = (effect.rotation or 0) + index * (pi * 2 / crumbCount) + progress * pi * 1.8
			local distance = biteRadius + innerRadius * (0.6 + 0.25 * sin(progress * pi * 6 + index))
			local size = innerRadius * (0.2 + 0.05 * sin(progress * pi * 5.4 + index))
			love.graphics.circle("fill", x + cos(angle) * distance, y + sin(angle) * distance, size, 12)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawStoneguardBastion(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local slabColor = effect.variantColor or effect.color or {0.74, 0.8, 0.88, 1}
	local edgeColor = effect.variantSecondaryColor or {0.46, 0.5, 0.56, 1}
	local dustColor = effect.variantTertiaryColor or {0.94, 0.96, 0.98, 0.72}

	local slabAlpha = (slabColor[4] or 1) * clamp01(1.05 - progress * 1.1)
	if slabAlpha <= 0 then return end

	local slabCount = (effect.variantData and effect.variantData.slabs) or 5
	local rotation = (effect.rotation or 0) + sin(progress * pi * 2.2) * 0.12
	local bandRadius = (innerRadius + outerRadius) * 0.5
	local bandThickness = (outerRadius - innerRadius) * (0.55 + 0.2 * (1 - progress))

	love.graphics.push("all")

	for index = 1, slabCount do
		local offset = (index - 0.5) / slabCount
		local angle = rotation + offset * pi * 2
		local wobble = sin(progress * pi * (3 + index * 0.4)) * 0.18
		angle = angle + wobble * 0.12

		local dirX, dirY = cos(angle), sin(angle)
		local perpX, perpY = -dirY, dirX

		local centerDist = bandRadius + sin(progress * pi * 4 + index) * innerRadius * 0.08
		local halfWidth = bandThickness * 0.28
		local halfTopWidth = halfWidth * (0.78 + 0.08 * sin(progress * pi * 5 + index))
		local length = bandThickness * (0.9 + 0.18 * sin(progress * pi * 3.2 + index * 0.6))

		local innerDist = centerDist - length * 0.5
		local outerDist = centerDist + length * 0.5

		local innerLeftX = x + dirX * innerDist + perpX * halfWidth
		local innerLeftY = y + dirY * innerDist + perpY * halfWidth
		local innerRightX = x + dirX * innerDist - perpX * halfWidth
		local innerRightY = y + dirY * innerDist - perpY * halfWidth
		local outerLeftX = x + dirX * outerDist + perpX * halfTopWidth
		local outerLeftY = y + dirY * outerDist + perpY * halfTopWidth
		local outerRightX = x + dirX * outerDist - perpX * halfTopWidth
		local outerRightY = y + dirY * outerDist - perpY * halfTopWidth

		local fade = 1 - progress * 0.45
		love.graphics.setColor(slabColor[1], slabColor[2], slabColor[3], slabAlpha * (0.85 + 0.15 * fade))
		love.graphics.polygon("fill", innerLeftX, innerLeftY, outerLeftX, outerLeftY, outerRightX, outerRightY, innerRightX, innerRightY)

		love.graphics.setLineWidth(2)
		love.graphics.setColor(edgeColor[1], edgeColor[2], edgeColor[3], (edgeColor[4] or 1) * slabAlpha * 0.95)
		love.graphics.polygon("line", innerLeftX, innerLeftY, outerLeftX, outerLeftY, outerRightX, outerRightY, innerRightX, innerRightY)

		love.graphics.setLineWidth(1.1)
		love.graphics.setColor(edgeColor[1], edgeColor[2], edgeColor[3], (edgeColor[4] or 1) * slabAlpha * 0.55)
		love.graphics.line((innerLeftX + outerLeftX) * 0.5, (innerLeftY + outerLeftY) * 0.5, (innerRightX + outerRightX) * 0.5, (innerRightY + outerRightY) * 0.5)
	end

	local dustAlpha = (dustColor[4] or 1) * clamp01(1 - progress * 1.4)
	if dustAlpha > 0 then
		love.graphics.setColor(dustColor[1], dustColor[2], dustColor[3], dustAlpha)
		local dustCount = 8
		local dustRadius = outerRadius * (0.62 + 0.18 * progress)
		for index = 1, dustCount do
			local angle = rotation + index * (pi * 2 / dustCount) + sin(progress * pi * 5 + index) * 0.12
			local distance = dustRadius * (0.88 + 0.18 * sin(progress * pi * 4 + index * 0.6))
			local px = x + cos(angle) * distance
			local py = y + sin(angle) * distance
			love.graphics.circle("fill", px, py, innerRadius * (0.14 + 0.04 * sin(progress * pi * 6 + index)), 12)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawCoiledFocus(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local coilColor = effect.variantColor or effect.color or {0.76, 0.56, 0.88, 1}
	local bandColor = effect.variantSecondaryColor or {0.58, 0.44, 0.92, 0.9}
	local focusColor = effect.variantTertiaryColor or {0.98, 0.9, 1.0, 0.75}

	local coilAlpha = (coilColor[4] or 1) * clamp01(1.08 - progress * 1.15)
	if coilAlpha <= 0 then return end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	love.graphics.translate(x, y)
	local rotation = (effect.rotation or 0) + sin(progress * pi * 3.4) * 0.16
	love.graphics.rotate(rotation)

	local coilCount = (effect.variantData and effect.variantData.coils) or 3
	local spacing = innerRadius * (0.8 - 0.2 * clamp01(progress * 1.2))
	for index = 1, coilCount do
		local t = coilCount == 1 and 0.5 or (index - 1) / (coilCount - 1)
		local offset = (t - 0.5) * spacing
		local majorRadius = innerRadius * (1.1 + 0.45 * t)
		local minorRadius = innerRadius * (0.55 - 0.1 * t) * (1 - progress * 0.25)

		love.graphics.setLineWidth(innerRadius * (0.42 - 0.08 * t))
		love.graphics.setColor(coilColor[1], coilColor[2], coilColor[3], coilAlpha * (0.85 - 0.18 * t))
		love.graphics.ellipse("line", offset, 0, majorRadius, minorRadius, 36)

		local fillAlpha = (bandColor[4] or 1) * coilAlpha * 0.22 * (1 - 0.4 * t)
		if fillAlpha > 0 then
			love.graphics.setColor(bandColor[1], bandColor[2], bandColor[3], fillAlpha)
			love.graphics.ellipse("fill", offset, 0, majorRadius * 0.92, minorRadius * 0.72, 36)
		end
	end

	local spiralRadius = innerRadius * (0.7 + 0.3 * sin(progress * pi * 2.6))
	love.graphics.setLineWidth(innerRadius * 0.18)
	love.graphics.setColor(bandColor[1], bandColor[2], bandColor[3], (bandColor[4] or 1) * coilAlpha * 0.6)
	for i = 1, 4 do
		local angle = progress * pi * 3.2 + i * (pi * 0.5)
		local px = cos(angle) * spiralRadius
		local py = sin(angle) * spiralRadius * 0.8
		love.graphics.line(0, 0, px, py)
	end

	local focusAlpha = (focusColor[4] or 1) * clamp01(1 - progress * 1.35)
	if focusAlpha > 0 then
		local pulse = 0.88 + 0.18 * sin(progress * pi * 4.4)
		love.graphics.setColor(focusColor[1], focusColor[2], focusColor[3], focusAlpha)
		love.graphics.circle("fill", 0, 0, innerRadius * (0.7 + 0.35 * pulse), 24)
		love.graphics.setLineWidth(1.8)
		love.graphics.circle("line", 0, 0, innerRadius * (1.05 + 0.25 * pulse), 24)
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawPocketSprings(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local coilColor = effect.variantColor or effect.color or {0.68, 0.88, 1.0, 1}
	local plateColor = effect.variantSecondaryColor or {0.42, 0.72, 1.0, 0.92}
	local sparkColor = effect.variantTertiaryColor or {1.0, 0.92, 0.6, 0.8}

	local coilAlpha = (coilColor[4] or 1) * clamp01(1.04 - progress * 1.15)
	if coilAlpha <= 0 then return end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local wobble = sin(progress * pi * 4.2)
	local coilHeight = (outerRadius - innerRadius) * (0.78 + 0.18 * sin(progress * pi * 3.2))
	local startY = y - coilHeight * 0.5
	local endY = y + coilHeight * 0.5
	local coilRadius = innerRadius * (0.4 + 0.12 * sin(progress * pi * 5.4))
	local turns = (effect.variantData and effect.variantData.turns) or 4
	local spacing = innerRadius * (1.05 + 0.25 * (1 - progress))

	for side = -1, 1, 2 do
		local offsetX = x + side * spacing
		local points = {}
		local steps = 16
		for step = 0, steps do
			local t = step / steps
			local angle = t * turns * pi * 2 + progress * pi * 1.4 * side
			local px = offsetX + sin(angle) * coilRadius
			local py = startY + (endY - startY) * t
			points[#points + 1] = px
			points[#points + 1] = py
		end

		love.graphics.setLineWidth(innerRadius * 0.26)
		love.graphics.setColor(coilColor[1], coilColor[2], coilColor[3], coilAlpha)
		love.graphics.line(points)

		local plateAlpha = (plateColor[4] or 1) * coilAlpha
		if plateAlpha > 0 then
			love.graphics.setLineWidth(innerRadius * 0.18)
			love.graphics.setColor(plateColor[1], plateColor[2], plateColor[3], plateAlpha)
			local width = coilRadius * (1.2 + 0.3 * wobble * side)
			love.graphics.line(offsetX - width, startY, offsetX + width, startY)
			love.graphics.line(offsetX - width, endY, offsetX + width, endY)
		end
	end

	local sparkAlpha = (sparkColor[4] or 1) * clamp01(1 - progress * 1.3) * coilAlpha
	if sparkAlpha > 0 then
		love.graphics.setColor(sparkColor[1], sparkColor[2], sparkColor[3], sparkAlpha)
		local sparkCount = 4
		for index = 1, sparkCount do
			local angle = progress * pi * 2 + index * (pi * 0.5)
			local radius = innerRadius * (1.4 + 0.25 * sin(progress * pi * 6 + index))
			love.graphics.circle("fill", x + cos(angle) * radius, y + sin(angle) * radius, innerRadius * 0.26, 14)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawPhoenixFlare(effect, progress)
	local x, y = effect.x, effect.y
	local outerRadius = effect.outerRadius or 44
	local innerRadius = effect.innerRadius or 12
	local baseColor = effect.variantColor or effect.color or {1, 0.6, 0.24, 1}
	local wingColor = effect.variantSecondaryColor or {1, 0.42, 0.12, 1}
	local emberColor = effect.variantTertiaryColor or {1, 0.82, 0.44, 1}

	local baseAlpha = (baseColor[4] or 1) * clamp01(1.1 - progress * 1.15)
	if baseAlpha <= 0 then return end

	local pulse = 0.9 + 0.18 * sin(progress * pi * 5)

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local flareHeight = outerRadius * (1.1 + 0.25 * pulse)
	love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseAlpha * 0.55)
	love.graphics.ellipse("fill", x, y + flareHeight * 0.1, innerRadius * 0.85 * pulse, flareHeight * 0.55, 36)

	local crestAlpha = (emberColor[4] or 1) * clamp01(1 - progress * 1.05)
	love.graphics.setColor(emberColor[1], emberColor[2], emberColor[3], crestAlpha * 0.9)
	love.graphics.polygon("fill", x, y - innerRadius * 1.2, x + innerRadius * 0.7, y + innerRadius * 0.4, x, y + innerRadius * 0.9, x - innerRadius * 0.7, y + innerRadius * 0.4)

	local wingAlpha = (wingColor[4] or 1) * clamp01(1 - progress * 1.35)
	local span = outerRadius * (1.35 + 0.12 * sin(progress * pi * 4))
	local height = outerRadius * 0.7
	for side = -1, 1, 2 do
		local points = {
			x, y - height * 0.18,
			x + side * span * 0.58, y - height * 0.32,
			x + side * span * 0.9, y + height * 0.05,
			x + side * span * 0.4, y + height * 0.55,
			x, y + height * 0.32,
		}
		love.graphics.setColor(wingColor[1], wingColor[2], wingColor[3], wingAlpha * 0.55)
		love.graphics.polygon("fill", points)
		love.graphics.setColor(wingColor[1], wingColor[2], wingColor[3], wingAlpha)
		love.graphics.setLineWidth(2.2)
		love.graphics.polygon("line", points)
	end

	local emberBaseAlpha = (emberColor[4] or 1) * clamp01(1 - progress * 0.9)
	if emberBaseAlpha > 0 then
		for i = 1, 6 do
			local start = (i - 1) * 0.12
			local emberProgress = (progress - start) / 0.58
			if emberProgress > -0.1 and emberProgress < 1.1 then
				emberProgress = clamp01(emberProgress)
				local fade = 1 - emberProgress
				local angle = (effect.rotation or 0) + i * 0.75 + progress * pi * 1.4
				local dist = innerRadius * (0.5 + 0.3 * sin(progress * pi * 6 + i))
				local ex = x + cos(angle) * dist
				local ey = y - outerRadius * (0.15 + emberProgress * 0.75) - i * 2
				love.graphics.setColor(emberColor[1], emberColor[2], emberColor[3], emberBaseAlpha * fade * 0.85)
				love.graphics.circle("fill", ex, ey, innerRadius * 0.2 * (0.8 + 0.4 * fade), 18)
			end
		end
	end

	if effect.addBlend then
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.setLineWidth(1)
end

local function drawAdrenalineRush(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local streakColor = effect.variantColor or effect.color or {1, 0.46, 0.42, 1}
	local glowColor = effect.variantSecondaryColor or {1, 0.72, 0.44, 0.95}
	local pulseColor = effect.variantTertiaryColor or {1, 0.94, 0.92, 0.85}

	local streakAlpha = (streakColor[4] or 1) * clamp01(1.1 - progress * 1.25)
	if streakAlpha <= 0 then return end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
		love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], (glowColor[4] or 1) * streakAlpha * 0.45)
		love.graphics.circle("fill", x, y, innerRadius * (1.4 + 0.4 * sin(progress * pi * 6)), 24)
		love.graphics.setBlendMode("alpha")
	end

	local streakCount = (effect.variantData and effect.variantData.streaks) or 7
	local rotation = (effect.rotation or 0) + sin(progress * pi * 5.2) * 0.16
	for index = 1, streakCount do
		local offset = (index - 1) / streakCount
		local angle = rotation + offset * pi * 2
		angle = angle + sin(progress * pi * (6 + index)) * 0.18

		local startRadius = innerRadius * (0.3 + 0.22 * sin(progress * pi * 4 + index))
		local endRadius = outerRadius * (0.85 + 0.12 * sin(progress * pi * 3.6 + index * 0.6))

		local startX = x + cos(angle) * startRadius
		local startY = y + sin(angle) * startRadius
		local endX = x + cos(angle) * endRadius
		local endY = y + sin(angle) * endRadius

		love.graphics.setLineWidth(3 - offset * 1.6)
		love.graphics.setColor(streakColor[1], streakColor[2], streakColor[3], streakAlpha * (0.75 + 0.2 * offset))
		love.graphics.line(startX, startY, endX, endY)

		local midX = x + cos(angle) * ((startRadius + endRadius) * 0.55)
		local midY = y + sin(angle) * ((startRadius + endRadius) * 0.55)
		love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], (glowColor[4] or 1) * streakAlpha * 0.6)
		love.graphics.circle("fill", midX, midY, innerRadius * 0.22, 12)
	end

	local pulseAlpha = (pulseColor[4] or 1) * clamp01(1 - progress * 1.1)
	if pulseAlpha > 0 then
		local pulseRadius = innerRadius * (1 + 0.55 * sin(progress * pi * 6.2))
		love.graphics.setColor(pulseColor[1], pulseColor[2], pulseColor[3], pulseAlpha * 0.9)
		love.graphics.circle("line", x, y, pulseRadius, 32)
		love.graphics.circle("line", x, y, pulseRadius * 1.25, 32)
		love.graphics.setColor(pulseColor[1], pulseColor[2], pulseColor[3], pulseAlpha)
		love.graphics.circle("fill", x, y, innerRadius * 0.48, 18)
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawEventHorizon(effect, progress)
	local x, y = effect.x, effect.y
	local outerRadius = effect.outerRadius or 44
	local innerRadius = effect.innerRadius or 12
		local highlightColor = effect.variantColor or effect.color or {1, 0.82, 0.38, 1}

	local gravityAlpha = clamp01(1 - progress * 0.9)
	if gravityAlpha <= 0 then return end

	love.graphics.setColor(0.02, 0.02, 0.08, 0.7 * gravityAlpha)
	love.graphics.circle("fill", x, y, outerRadius * (0.65 + 0.2 * progress), 48)

	love.graphics.setColor(0, 0, 0, 0.88 * gravityAlpha)
	love.graphics.circle("fill", x, y, innerRadius * (1.25 - 0.4 * progress), 48)

	love.graphics.setLineWidth(3)
	for i = 1, 3 do
		local radius = innerRadius * (1.7 + i * 0.55)
		local startAngle = (effect.rotation or 0) + progress * pi * (1.6 + i * 0.25) + i * 0.6
		local sweep = pi * (0.45 + 0.1 * i)
		local alpha = (highlightColor[4] or 1) * clamp01(1.15 - progress * (0.7 + i * 0.15)) * 0.9
		love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], alpha)
		love.graphics.arc("line", "open", x, y, radius, startAngle, startAngle + sweep, 32)
	end

	local rimAlpha = (highlightColor[4] or 1) * clamp01(1 - progress * 1.2)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], rimAlpha)
	love.graphics.circle("line", x, y, outerRadius * (0.92 - 0.18 * progress), 48)

	love.graphics.setLineWidth(1)
end

local function drawStormBurst(effect, progress)
	local x, y = effect.x, effect.y
	local outerRadius = effect.outerRadius or 44
	local innerRadius = effect.innerRadius or 12
	local boltColor = effect.variantColor or effect.color or {0.86, 0.94, 1.0, 1}
	local auraColor = effect.variantSecondaryColor or {0.34, 0.66, 1.0, 0.9}
	local sparkColor = effect.variantTertiaryColor or {1, 0.95, 0.75, 0.9}

	local alpha = (boltColor[4] or 1) * clamp01(1.05 - progress * 1.15)
	if alpha <= 0 then return end

	if effect.addBlend then
		love.graphics.setBlendMode("add")
		love.graphics.setColor(auraColor[1], auraColor[2], auraColor[3], (auraColor[4] or 1) * alpha * 0.55)
		love.graphics.circle("fill", x, y, outerRadius * (0.78 + 0.18 * sin(progress * pi * 4)), 36)
		love.graphics.setBlendMode("alpha")
	end

	local branches = 3
	for branch = 1, branches do
		local delay = (branch - 1) * 0.08
		local branchProgress = clamp01((progress - delay) / (0.78 - delay * 0.4))
		if branchProgress > 0 then
			local branchAlpha = alpha * (1 - 0.2 * (branch - 1))
			local angle = (effect.rotation or 0) + branch * (pi / 3) + sin(progress * pi * (3 + branch)) * 0.2
			local length = outerRadius * (1.25 + 0.22 * branch) * branchProgress
			local lateral = innerRadius * (0.9 - 0.18 * branch)

			local points = {x, y}
			local segments = 4
			for seg = 1, segments do
				local t = seg / segments
				local wobble = sin(progress * pi * (4 + branch) + seg * 1.4) * lateral * (1 - t)
				local px = x + cos(angle) * length * t - sin(angle) * wobble * (seg % 2 == 0 and -0.6 or 0.6)
				local py = y + sin(angle) * length * t + cos(angle) * wobble * (seg % 2 == 0 and -0.6 or 0.6)
				points[#points + 1] = px
				points[#points + 1] = py
			end

			love.graphics.setColor(boltColor[1], boltColor[2], boltColor[3], branchAlpha)
			love.graphics.setLineWidth(3.2 - branch * 0.4)
			love.graphics.line(points)

			local tipX = points[#points - 1]
			local tipY = points[#points]
			love.graphics.setColor(boltColor[1], boltColor[2], boltColor[3], branchAlpha * 0.8)
			love.graphics.circle("fill", tipX, tipY, innerRadius * 0.35, 18)
		end
	end

	local sparkAlpha = (sparkColor[4] or 1) * alpha * 0.75
	if sparkAlpha > 0 then
		for i = 1, 6 do
			local angle = (effect.rotation or 0) + i * (pi / 3) + progress * pi * 1.8
			local radius = innerRadius * (1.6 + 0.35 * sin(progress * pi * 5 + i))
			local sx = x + cos(angle) * radius
			local sy = y + sin(angle) * radius
			love.graphics.setColor(sparkColor[1], sparkColor[2], sparkColor[3], sparkAlpha)
			love.graphics.circle("fill", sx, sy, innerRadius * 0.32, 12)
		end
	end

	love.graphics.setLineWidth(1)
end

local function drawGuidingCompass(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local ringColor = effect.variantColor or effect.color or {0.72, 0.86, 1.0, 1}
	local pointerColor = effect.variantSecondaryColor or {1.0, 0.82, 0.42, 1}
	local markerColor = effect.variantTertiaryColor or {0.48, 0.72, 1.0, 0.85}

	local ringAlpha = (ringColor[4] or 1) * clamp01(1.05 - progress * 1.15)
	if ringAlpha <= 0 then return end

	love.graphics.push("all")

	local rotation = (effect.rotation or 0) + progress * pi * 0.7

	love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], ringAlpha * 0.35)
	love.graphics.circle("fill", x, y, outerRadius * (0.82 - 0.12 * progress), 48)

	love.graphics.setLineWidth(2.4)
	love.graphics.setColor(ringColor[1], ringColor[2], ringColor[3], ringAlpha)
	love.graphics.circle("line", x, y, outerRadius * (0.78 - 0.16 * progress), 48)

	local markerAlpha = (markerColor[4] or 1) * clamp01(1 - progress * 1.25)
	if markerAlpha > 0 then
		for index = 1, 8 do
			local weight = (index % 2 == 0) and 1 or 0.6
			local angle = rotation + index * (pi / 4)
			local inner = innerRadius * (0.85 + 0.12 * weight)
			local outer = outerRadius * (0.58 + 0.18 * weight)
			local sx = x + cos(angle) * inner
			local sy = y + sin(angle) * inner
			local ex = x + cos(angle) * outer
			local ey = y + sin(angle) * outer
			love.graphics.setLineWidth(1.4 + weight * 0.8)
			love.graphics.setColor(markerColor[1], markerColor[2], markerColor[3], markerAlpha * weight)
			love.graphics.line(sx, sy, ex, ey)
		end
	end

	local pointerAlpha = (pointerColor[4] or 1) * clamp01(1.1 - progress * 1.05)
	if pointerAlpha > 0 then
		local pointerAngle = rotation + progress * pi * 1.4
		local tipRadius = outerRadius * (0.68 + 0.08 * sin(progress * pi * 4))
		local tailRadius = innerRadius * 0.7
		local leftAngle = pointerAngle + pi * 0.55
		local rightAngle = pointerAngle - pi * 0.55

		love.graphics.setColor(pointerColor[1], pointerColor[2], pointerColor[3], pointerAlpha * 0.9)
		love.graphics.polygon(
		"fill",
		x + cos(pointerAngle) * tipRadius,
		y + sin(pointerAngle) * tipRadius,
		x + cos(leftAngle) * tailRadius,
		y + sin(leftAngle) * tailRadius,
		x,
		y,
		x + cos(rightAngle) * tailRadius,
		y + sin(rightAngle) * tailRadius
		)

		love.graphics.setLineWidth(2)
		love.graphics.setColor(pointerColor[1], pointerColor[2], pointerColor[3], pointerAlpha)
		love.graphics.polygon(
		"line",
		x + cos(pointerAngle) * tipRadius,
		y + sin(pointerAngle) * tipRadius,
		x + cos(leftAngle) * tailRadius,
		y + sin(leftAngle) * tailRadius,
		x,
		y,
		x + cos(rightAngle) * tailRadius,
		y + sin(rightAngle) * tailRadius
		)
	end

	local innerAlpha = (markerColor[4] or 1) * clamp01(1 - progress * 0.95)
	if innerAlpha > 0 then
		local pulse = 0.9 + 0.2 * sin(progress * pi * 5)
		love.graphics.setColor(markerColor[1], markerColor[2], markerColor[3], innerAlpha)
		love.graphics.circle("line", x, y, innerRadius * (0.9 + 0.35 * pulse), 30)
		love.graphics.circle("line", x, y, innerRadius * (1.35 + 0.25 * pulse), 30)
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawMoltingReflex(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local scaleColor = effect.variantColor or effect.color or {1.0, 0.72, 0.28, 1}
	local emberColor = effect.variantSecondaryColor or {1.0, 0.46, 0.18, 0.95}
	local glowColor = effect.variantTertiaryColor or {1.0, 0.92, 0.62, 0.8}

	local scaleAlpha = (scaleColor[4] or 1) * clamp01(1.02 - progress * 1.1)
	if scaleAlpha <= 0 then return end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local drift = (outerRadius - innerRadius) * (0.22 + 0.58 * progress)
	local scaleCount = (effect.variantData and effect.variantData.scales) or 8
	for index = 1, scaleCount do
		local fraction = (index - 0.5) / scaleCount
		local angle = (effect.rotation or 0) + fraction * pi * 2 + sin(progress * pi * (3.6 + index * 0.25)) * 0.1
		local dirX, dirY = cos(angle), sin(angle)
		local perpX, perpY = -dirY, dirX

		local radius = innerRadius + drift + sin(progress * pi * 4 + index) * innerRadius * 0.08
		local centerX = x + dirX * radius
		local centerY = y + dirY * radius
		local length = innerRadius * (0.65 + 0.25 * (1 - progress))
		local width = innerRadius * (0.45 + 0.15 * sin(progress * pi * 5 + index))

		local points = {
			centerX + dirX * length * 0.5, centerY + dirY * length * 0.5,
			centerX + perpX * width, centerY + perpY * width,
			centerX - dirX * length * 0.5, centerY - dirY * length * 0.5,
			centerX - perpX * width, centerY - perpY * width,
		}

		love.graphics.setColor(scaleColor[1], scaleColor[2], scaleColor[3], scaleAlpha * (0.85 - 0.15 * fraction))
		love.graphics.polygon("fill", points)

		love.graphics.setLineWidth(innerRadius * 0.14)
		love.graphics.setColor(emberColor[1], emberColor[2], emberColor[3], (emberColor[4] or 1) * scaleAlpha)
		love.graphics.polygon("line", points)
	end

	local glowAlpha = (glowColor[4] or 1) * clamp01(1 - progress * 1.3) * scaleAlpha
	if glowAlpha > 0 then
		local pulse = 0.9 + 0.18 * sin(progress * pi * 5.2)
		love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowAlpha)
		love.graphics.setLineWidth(innerRadius * 0.18)
		love.graphics.circle("line", x, y, innerRadius * (1.2 + 0.4 * pulse), 36)
		love.graphics.circle("line", x, y, innerRadius * (1.8 + 0.6 * pulse), 36)

		local fleckCount = max(4, scaleCount)
		love.graphics.setLineWidth(1)
		for index = 1, fleckCount do
			local angle = (effect.rotation or 0) + index * (pi * 2 / fleckCount) + progress * pi * 2
			local radius = innerRadius * (1.6 + 0.45 * progress) + outerRadius * 0.15
			love.graphics.circle("fill", x + cos(angle) * radius, y + sin(angle) * radius, innerRadius * 0.18, 10)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawResonantShell(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local shellColor = effect.variantColor or effect.color or {0.8, 0.88, 1.0, 1}
	local waveColor = effect.variantSecondaryColor or {0.54, 0.76, 1.0, 0.92}
	local sparkColor = effect.variantTertiaryColor or {1.0, 0.96, 0.82, 0.75}

	local shellAlpha = (shellColor[4] or 1) * clamp01(1.05 - progress * 1.1)
	if shellAlpha <= 0 then
		return
	end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
		love.graphics.setColor(shellColor[1], shellColor[2], shellColor[3], shellAlpha * 0.22)
		love.graphics.circle("fill", x, y, outerRadius * (0.65 + 0.25 * progress), 48)
		love.graphics.setBlendMode("alpha")
	end

	local pulse = 0.94 + 0.14 * sin(progress * pi * 5.2)
	love.graphics.setLineWidth(innerRadius * 0.4)
	love.graphics.setColor(shellColor[1], shellColor[2], shellColor[3], shellAlpha * 0.8)
	love.graphics.circle("line", x, y, innerRadius * (0.85 + 0.25 * pulse), 36)

	local waveAlphaBase = (waveColor[4] or 1) * shellAlpha
	local waveCount = (effect.variantData and effect.variantData.waves) or 3
	for index = 1, waveCount do
		local offset = (index - 1) * 0.2
		local waveProgress = clamp01(progress * 1.1 - offset)
		if waveProgress > 0 then
			local fade = 1 - waveProgress * 0.8
			local radius = innerRadius + (outerRadius - innerRadius) * (0.35 + 0.5 * waveProgress)
			local thickness = innerRadius * (0.28 + 0.18 * (1 - waveProgress))
			local sweep = pi * (0.55 + 0.18 * sin(progress * pi * 4 + index))
			local rotation = (effect.rotation or 0) + sin(progress * pi * (3.2 + index * 0.4)) * 0.18
			local startAngle = rotation - sweep * 0.5
			local endAngle = rotation + sweep * 0.5

			love.graphics.setLineWidth(thickness)
			love.graphics.setColor(
			waveColor[1],
			waveColor[2],
			waveColor[3],
			waveAlphaBase * (0.7 + 0.2 * (1 - (index - 1) / waveCount)) * fade
			)
			love.graphics.arc("line", "open", x, y, radius, startAngle, endAngle, 40)
		end
	end

	local sparkAlpha = (sparkColor[4] or 1) * clamp01(1 - progress * 1.25) * shellAlpha
	if sparkAlpha > 0 then
		local sparkCount = waveCount * 3
		local baseRadius = innerRadius + (outerRadius - innerRadius) * (0.45 + 0.35 * progress)
		for index = 1, sparkCount do
			local angle = (effect.rotation or 0) + index * (pi * 2 / sparkCount) + progress * pi * 2.4
			local radius = baseRadius + sin(progress * pi * (6 + index * 0.3)) * innerRadius * 0.18
			local size = innerRadius * (0.18 + 0.06 * sin(progress * pi * 5.4 + index))
			love.graphics.setColor(
			sparkColor[1],
			sparkColor[2],
			sparkColor[3],
			sparkAlpha * (0.75 + 0.2 * sin(progress * pi * 4.2 + index))
			)
			love.graphics.circle("fill", x + cos(angle) * radius, y + sin(angle) * radius, size, 12)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawAbyssalCatalyst(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local coreColor = effect.variantColor or effect.color or {0.52, 0.48, 0.92, 1}
	local accentColor = effect.variantSecondaryColor or {0.72, 0.66, 0.98, 0.9}
	local sparkColor = effect.variantTertiaryColor or {1.0, 0.84, 1.0, 0.82}

	local coreAlpha = (coreColor[4] or 1) * clamp01(1.1 - progress * 1.2)
	if coreAlpha <= 0 then
		return
	end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
	end

	local vortexRadius = outerRadius * (0.34 + 0.42 * (1 - progress))
	love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreAlpha * 0.85)
	love.graphics.circle("fill", x, y, vortexRadius, 40)

	local rimRadius = vortexRadius * (1.2 + 0.3 * sin(progress * pi * 3.6))
	love.graphics.setLineWidth(innerRadius * 0.26)
	love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], coreAlpha * 0.6)
	love.graphics.circle("line", x, y, rimRadius, 40)

	local shardAlphaBase = (accentColor[4] or 1) * clamp01(1.05 - progress * 0.95) * coreAlpha
	local shardCount = (effect.variantData and effect.variantData.shards) or 5
	for index = 1, shardCount do
		local angle = (effect.rotation or 0) + index * (pi * 2 / shardCount) + progress * pi * 1.8
		local wobble = sin(progress * pi * (4 + index * 0.35)) * 0.3
		local startRadius = innerRadius * (0.4 + 0.18 * sin(progress * pi * 6 + index))
		local endRadius = outerRadius * (0.65 + 0.2 * sin(progress * pi * 3.2 + index))
		local width = innerRadius * (0.3 + 0.1 * cos(progress * pi * 4.6 + index))
		local dirX, dirY = cos(angle), sin(angle)
		local perpX, perpY = -dirY, dirX

		local baseX = x + dirX * startRadius
		local baseY = y + dirY * startRadius
		local tipX = x + dirX * endRadius + perpX * width * wobble
		local tipY = y + dirY * endRadius + perpY * width * wobble
		local leftX = baseX + perpX * width
		local leftY = baseY + perpY * width
		local rightX = baseX - perpX * width
		local rightY = baseY - perpY * width

		love.graphics.setColor(
		accentColor[1],
		accentColor[2],
		accentColor[3],
		shardAlphaBase * (0.8 + 0.2 * (index % 2))
		)
		love.graphics.polygon("fill", baseX, baseY, leftX, leftY, tipX, tipY, rightX, rightY)

		love.graphics.setLineWidth(innerRadius * 0.12)
		love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], shardAlphaBase * 0.9)
		love.graphics.polygon("line", baseX, baseY, leftX, leftY, tipX, tipY, rightX, rightY)
	end

	local spiralAlpha = (sparkColor[4] or 1) * clamp01(1 - progress * 1.1) * coreAlpha
	if spiralAlpha > 0 then
		local orbitCount = shardCount * 2
		for index = 1, orbitCount do
			local t = index / orbitCount
			local angle = (effect.rotation or 0) + progress * pi * 3 + t * pi * 2
			local radius = innerRadius * (0.8 + 0.5 * progress) + (outerRadius - innerRadius) * t * 0.45
			radius = radius + sin(progress * pi * 5 + index) * innerRadius * 0.12
			local size = innerRadius * (0.16 + 0.08 * t)
			love.graphics.setColor(
			sparkColor[1],
			sparkColor[2],
			sparkColor[3],
			spiralAlpha * (0.65 + 0.25 * sin(angle * 1.4 + progress * pi * 2))
			)
			love.graphics.circle("fill", x + cos(angle) * radius, y + sin(angle) * radius, size, 14)
		end
	end

	if effect.addBlend then
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local function drawChronospiralCore(effect, progress)
	local x, y = effect.x, effect.y
	local innerRadius = effect.innerRadius or 12
	local outerRadius = effect.outerRadius or 44
	local spiralColor = effect.variantColor or effect.color or {0.68, 0.78, 1.0, 1}
	local accentColor = effect.variantSecondaryColor or {0.82, 0.62, 1.0, 0.92}
	local markerColor = effect.variantTertiaryColor or {1.0, 0.92, 0.64, 0.9}

	local spiralAlpha = (spiralColor[4] or 1) * clamp01(1.06 - progress * 1.1)
	if spiralAlpha <= 0 then
		return
	end

	love.graphics.push("all")

	if effect.addBlend then
		love.graphics.setBlendMode("add")
		love.graphics.setColor(spiralColor[1], spiralColor[2], spiralColor[3], spiralAlpha * 0.3)
		love.graphics.circle("fill", x, y, outerRadius * (0.7 + 0.18 * (1 - progress)), 48)
		love.graphics.setBlendMode("alpha")
	end

	local armCount = (effect.variantData and effect.variantData.arms) or 3
	local rotations = 1.5 + 0.4 * (1 - progress)
	local rotation = (effect.rotation or 0) + progress * pi * 1.6

	for arm = 1, armCount do
		local angleOffset = rotation + (arm - 1) * (pi * 2 / armCount)
		local steps = 24
		local points = {}
		for step = 0, steps do
			local t = step / steps
			local eased = t ^ 0.82
			local radius = innerRadius + (outerRadius - innerRadius) * eased
			local angle = angleOffset + eased * rotations * pi * 2
			angle = angle + sin(progress * pi * (3.4 + arm * 0.3) + t * 4) * 0.08
			points[#points + 1] = x + cos(angle) * radius
			points[#points + 1] = y + sin(angle) * radius
		end

		love.graphics.setLineWidth(innerRadius * (0.28 - 0.06 * (arm - 1) / armCount))
		love.graphics.setColor(
		spiralColor[1],
		spiralColor[2],
		spiralColor[3],
		spiralAlpha * (0.8 - 0.1 * (arm - 1))
		)
		love.graphics.line(points)
	end

	local accentAlpha = (accentColor[4] or 1) * clamp01(1.05 - progress * 1.25) * spiralAlpha
	if accentAlpha > 0 then
		local ringRadius = innerRadius * (0.8 + 0.4 * sin(progress * pi * 4.2))
		love.graphics.setLineWidth(innerRadius * 0.22)
		love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], accentAlpha)
		love.graphics.circle("line", x, y, ringRadius, 36)

		love.graphics.setLineWidth(innerRadius * 0.16)
		for index = 1, armCount do
			local angle = rotation + index * (pi * 2 / armCount) + progress * pi * 2
			local radius = innerRadius * (1.2 + 0.4 * sin(progress * pi * 3.2 + index))
			love.graphics.arc("line", "open", x, y, radius, angle - pi * 0.25, angle + pi * 0.25, 24)
		end
	end

	local markerAlpha = (markerColor[4] or 1) * clamp01(1 - progress * 1.1) * spiralAlpha
	if markerAlpha > 0 then
		local markerCount = max(6, armCount * 4)
		local baseRadius = innerRadius + (outerRadius - innerRadius) * progress
		for index = 1, markerCount do
			local angle = rotation + index * (pi * 2 / markerCount) + progress * pi * 2.6
			local radius = baseRadius + sin(progress * pi * 5 + index) * innerRadius * 0.25
			local size = innerRadius * (0.16 + 0.04 * (index % 2))
			love.graphics.setColor(
			markerColor[1],
			markerColor[2],
			markerColor[3],
			markerAlpha * (0.7 + 0.3 * sin(angle * 1.4))
			)
			love.graphics.circle("fill", x + cos(angle) * radius, y + sin(angle) * radius, size, 10)
		end
	end

	love.graphics.pop()
	love.graphics.setLineWidth(1)
end

local variantDrawers = {
	phoenix_flare = drawPhoenixFlare,
	event_horizon = drawEventHorizon,
	storm_burst = drawStormBurst,
	fang_flurry = drawFangFlurry,
	extra_bite_chomp = drawExtraBiteChomp,
		stoneguard_bastion = drawStoneguardBastion,
		pocket_springs = drawPocketSprings,
	coiled_focus = drawCoiledFocus,
	adrenaline_rush = drawAdrenalineRush,
	molting_reflex = drawMoltingReflex,
	guiding_compass = drawGuidingCompass,
	resonant_shell = drawResonantShell,
	abyssal_catalyst = drawAbyssalCatalyst,
	chronospiral_core = drawChronospiralCore,
}

local function drawVariant(effect, progress)
	if not effect.variant then return end
	local drawer = variantDrawers[effect.variant]
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
		local ringProgress = clamp01((progress - delay) / (1 - delay))
		if ringProgress > 0 then
			local eased = ringProgress * ringProgress
			local radius = innerRadius + (outerRadius - innerRadius) * eased + (index - 1) * ringSpacing
			local alpha = (color[4] or 1) * clamp01(1.1 - ringProgress * 1.1)
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
		local haloAlpha = haloColor[4] * clamp01(1 - progress)
		if haloAlpha > 0 then
			love.graphics.setColor(haloColor[1], haloColor[2], haloColor[3], haloAlpha)
			love.graphics.circle("fill", effect.x, effect.y, (effect.outerRadius or 44) * (0.4 + progress * 0.45), 36)
		end
	end

	local glowColor = effect.glowColor
	if glowColor and (glowColor[4] or 0) > 0 then
		local glowAlpha = glowColor[4] * clamp01(1 - progress * 0.8)
		if glowAlpha > 0 then
			local pulse = 0.9 + 0.2 * sin(progress * pi * 4)
			love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowAlpha)
			love.graphics.circle("fill", effect.x, effect.y, (effect.innerRadius or 12) * (1.4 + 0.6 * pulse), 24)
		end
	end

	love.graphics.setBlendMode("alpha")
end

function UpgradeVisuals:draw()
	if #self.effects == 0 then return end

	RenderLayers:withLayer("overlay", function()
		love.graphics.push("all")

		for _, effect in ipairs(self.effects) do
			local progress = clamp01(effect.age / effect.life)
			if effect.showBase ~= false then
				drawGlow(effect, progress)
				drawRings(effect, progress)
				drawBadge(effect, progress)
			end
			drawVariant(effect, progress)
		end

		love.graphics.pop()
	end)
end

function UpgradeVisuals:reset()
	self.effects = {}
end

return UpgradeVisuals
