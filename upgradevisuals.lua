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
		ringCount = max(1, math.floor(options.ringCount or 2)),
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
                local width = innerRadius * (0.26 + 0.12 * (1 - progress))

                local baseX = x + dirX * baseRadius
                local baseY = y + dirY * baseRadius
                local tipX = x + dirX * tipRadius
                local tipY = y + dirY * tipRadius
                local leftX = baseX + perpX * width
                local leftY = baseY + perpY * width
                local rightX = baseX - perpX * width
                local rightY = baseY - perpY * width

                local fade = 1 - offset * 0.2
                love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseAlpha * (0.8 + 0.2 * fade))
                love.graphics.polygon("fill", leftX, leftY, tipX, tipY, rightX, rightY)

                love.graphics.setLineWidth(1.6)
                love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], (highlightColor[4] or 1) * baseAlpha * 0.9 * fade)
                love.graphics.polygon("line", leftX, leftY, tipX, tipY, rightX, rightY)

                local slashRadius = tipRadius + innerRadius * (0.28 + 0.18 * (1 - progress))
                local slashWidth = 0.18 + 0.12 * (1 - progress)
                love.graphics.setLineWidth(2.4)
                love.graphics.setColor(slashColor[1], slashColor[2], slashColor[3], (slashColor[4] or 1) * baseAlpha * 0.65 * fade)
                love.graphics.arc("line", "open", x, y, slashRadius, angle - slashWidth, angle + slashWidth, 14)
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

local function drawPrismRefraction(effect, progress)
        local x, y = effect.x, effect.y
        local innerRadius = effect.innerRadius or 12
        local outerRadius = effect.outerRadius or 44
        local beamColor = effect.variantColor or effect.color or {0.72, 0.92, 1.0, 1}
        local shardColor = effect.variantSecondaryColor or {0.46, 0.78, 1.0, 0.95}
        local glintColor = effect.variantTertiaryColor or {1.0, 0.96, 0.72, 0.82}

        local beamAlpha = (beamColor[4] or 1) * clamp01(1.08 - progress * 1.2)
        if beamAlpha <= 0 then return end

        local shardCount = (effect.variantData and effect.variantData.shards) or 6
        local rotation = (effect.rotation or 0) + progress * pi * 1.1

        love.graphics.push("all")

        if effect.addBlend then
                love.graphics.setBlendMode("add")
        end

        for index = 1, shardCount do
                local offset = (index - 1) / shardCount
                local angle = rotation + offset * pi * 2
                local sway = sin(progress * pi * (3.2 + index * 0.25)) * 0.2
                angle = angle + sway

                local dirX, dirY = cos(angle), sin(angle)
                local perpX, perpY = -dirY, dirX

                local innerDist = innerRadius * (0.72 + 0.18 * sin(progress * pi * 4 + index))
                local outerDist = outerRadius * (0.8 + 0.16 * sin(progress * pi * 3 + index * 1.1))
                local width = innerRadius * (0.22 + 0.1 * (1 - progress))

                local baseX = x + dirX * innerDist
                local baseY = y + dirY * innerDist
                local tipX = x + dirX * outerDist
                local tipY = y + dirY * outerDist
                local leftX = baseX + perpX * width
                local leftY = baseY + perpY * width
                local rightX = baseX - perpX * width
                local rightY = baseY - perpY * width

                local fade = 1 - progress * 0.4
                love.graphics.setColor(shardColor[1], shardColor[2], shardColor[3], (shardColor[4] or 1) * beamAlpha * (0.65 + 0.35 * fade))
                love.graphics.polygon("fill", leftX, leftY, tipX, tipY, rightX, rightY)

                love.graphics.setLineWidth(1.8)
                love.graphics.setColor(beamColor[1], beamColor[2], beamColor[3], beamAlpha * 0.9)
                love.graphics.polygon("line", leftX, leftY, tipX, tipY, rightX, rightY)
        end

        local glintAlpha = (glintColor[4] or 1) * clamp01(1 - progress * 0.95)
        if glintAlpha > 0 then
                love.graphics.setColor(glintColor[1], glintColor[2], glintColor[3], glintAlpha)
                love.graphics.setLineWidth(2.6)
                local arcRadius = outerRadius * (0.82 + 0.12 * sin(progress * pi * 2))
                local arcSpan = pi * 0.28
                local arcCount = math.max(3, math.floor(shardCount / 2))
                for index = 1, arcCount do
                        local angle = rotation + index * (pi * 2 / arcCount)
                        love.graphics.arc("line", "open", x, y, arcRadius, angle - arcSpan * 0.5, angle + arcSpan * 0.5, 18)
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

local function drawEventHorizon(effect, progress)
        local x, y = effect.x, effect.y
        local outerRadius = effect.outerRadius or 44
        local innerRadius = effect.innerRadius or 12
        local highlightColor = effect.variantColor or effect.color or {1, 0.82, 0.38, 1}
        local shardColor = effect.variantSecondaryColor or {0.4, 0.7, 1.0, 1}

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

        local shardAlpha = (shardColor[4] or 1) * gravityAlpha
        for i = 1, 6 do
                local orbit = innerRadius * (1.2 + i * 0.32)
                local angle = (effect.rotation or 0) + progress * pi * (2.6 + i * 0.18) + i * 0.8
                local ex = x + cos(angle) * orbit
                local ey = y + sin(angle) * orbit
                love.graphics.setColor(shardColor[1], shardColor[2], shardColor[3], shardAlpha * (0.65 + 0.25 * ((i % 2 == 0) and 1 or 0.8)))
                love.graphics.circle("fill", ex, ey, innerRadius * 0.22 * clamp01(1.05 - progress * 0.8), 18)
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

                        local points = { x, y }
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
                        love.graphics.circle("fill", sx, sy, innerRadius * 0.28, 12)
                end
        end

        love.graphics.setLineWidth(1)
end

local variantDrawers = {
        phoenix_flare = drawPhoenixFlare,
        event_horizon = drawEventHorizon,
        storm_burst = drawStormBurst,
        fang_flurry = drawFangFlurry,
        stoneguard_bastion = drawStoneguardBastion,
        prism_refraction = drawPrismRefraction,
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
        if not love or not love.graphics then return end
        if #self.effects == 0 then return end

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
end

function UpgradeVisuals:reset()
	self.effects = {}
end

function UpgradeVisuals:isEmpty()
	return #self.effects == 0
end

return UpgradeVisuals
