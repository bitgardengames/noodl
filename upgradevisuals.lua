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

local function CopyOptionalColor(color)
        if not color then
                return nil
        end

        return CopyColor(color)
end

local function DrawShieldBadge(effect, progress)
	local BadgeColor = effect.badgeColor
	if not BadgeColor then return end

	local alpha = (BadgeColor[4] or 1) * clamp01(1 - progress * 1.1)
	if alpha <= 0 then return end

	local pulse = 1 + 0.05 * sin(progress * pi * 6)
	local BaseRadius = (effect.outerRadius or 42) * 0.32 * (effect.badgeScale or 1)
	local width = BaseRadius * pulse
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

	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha * 0.75)
	love.graphics.polygon("fill", vertices)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha)
	love.graphics.polygon("line", vertices)
end

local function DrawBurstBadge(effect, progress)
	local BadgeColor = effect.badgeColor
	if not BadgeColor then return end

	local alpha = (BadgeColor[4] or 1) * clamp01(1 - progress * 1.05)
	if alpha <= 0 then return end

	local points = 5
	local BaseRadius = (effect.outerRadius or 42) * 0.34 * (effect.badgeScale or 1)
	local InnerRadius = BaseRadius * 0.45
	local AngleOffset = (effect.rotation or 0) + progress * pi * 2 * 0.35

	local vertices = {}
	for i = 0, points * 2 - 1 do
		local radius = (i % 2 == 0) and BaseRadius or InnerRadius
		local angle = AngleOffset + i * (pi / points)
		vertices[#vertices + 1] = effect.x + cos(angle) * radius
		vertices[#vertices + 1] = effect.y + sin(angle) * radius
	end

	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha * 0.8)
	love.graphics.polygon("fill", vertices)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha)
	love.graphics.polygon("line", vertices)
end

local function DrawSparkBadge(effect, progress)
	local BadgeColor = effect.badgeColor
	if not BadgeColor then return end

	local alpha = (BadgeColor[4] or 1) * clamp01(1 - progress * 1.2)
	if alpha <= 0 then return end

	local rotation = (effect.rotation or 0) + progress * pi * 0.8
	local radius = (effect.outerRadius or 42) * 0.36 * (effect.badgeScale or 1)
	local thickness = radius * 0.3
	local x, y = effect.x, effect.y

	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(rotation)
	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha * 0.7)
	love.graphics.rectangle("fill", -radius, -thickness * 0.5, radius * 2, thickness)
	love.graphics.rectangle("fill", -thickness * 0.5, -radius, thickness, radius * 2)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(BadgeColor[1], BadgeColor[2], BadgeColor[3], alpha)
	love.graphics.rectangle("line", -radius, -thickness * 0.5, radius * 2, thickness)
	love.graphics.rectangle("line", -thickness * 0.5, -radius, thickness, radius * 2)
	love.graphics.pop()
end

local BadgeDrawers = {
	shield = DrawShieldBadge,
	burst = DrawBurstBadge,
	star = DrawBurstBadge,
	combo = DrawBurstBadge,
	spark = DrawSparkBadge,
}

function UpgradeVisuals:spawn(x, y, options)
        if not x or not y then return end
        options = options or {}

        local effect = {
		x = x,
		y = y,
		age = 0,
		life = options.life and max(0.05, options.life) or 0.72,
		color = CopyColor(options.color),
		GlowColor = CopyColor(options.glowColor or options.color),
		HaloColor = CopyColor(options.haloColor or options.color),
		BadgeColor = CopyColor(options.badgeColor or options.color),
		BadgeScale = options.badgeScale or 1,
		badge = options.badge,
		rotation = options.rotation or random() * pi * 2,
		RingCount = max(1, math.floor(options.ringCount or 2)),
		RingSpacing = options.ringSpacing or 10,
		RingWidth = options.ringWidth or 4,
		PulseDelay = options.pulseDelay or 0.12,
		InnerRadius = options.innerRadius or 12,
		OuterRadius = options.outerRadius or options.radius or 44,
                variant = options.variant or "pulse",
                VariantColor = CopyOptionalColor(options.variantColor),
                VariantSecondaryColor = CopyOptionalColor(options.variantSecondaryColor),
                VariantTertiaryColor = CopyOptionalColor(options.variantTertiaryColor),
                VariantData = options.variantData and deepcopy(options.variantData) or nil,
                ShowBase = options.showBase ~= false,
                GlowAlpha = options.glowAlpha,
                HaloAlpha = options.haloAlpha,
                AddBlend = options.addBlend ~= false,
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

local function DrawBadge(effect, progress)
        if not effect.badge then return end
        local drawer = BadgeDrawers[effect.badge]
        if not drawer then return end
        drawer(effect, progress)
end

local function DrawFangFlurry(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local BaseColor = effect.variantColor or effect.color or {1.0, 0.62, 0.42, 1}
        local HighlightColor = effect.variantSecondaryColor or {1.0, 0.9, 0.74, 0.92}
        local SlashColor = effect.variantTertiaryColor or {1.0, 0.46, 0.26, 0.78}

        local BaseAlpha = (BaseColor[4] or 1) * clamp01(1.1 - progress * 1.25)
        if BaseAlpha <= 0 then return end

        local FangCount = (effect.variantData and effect.variantData.fangs) or 6
        local rotation = (effect.rotation or 0) + progress * pi * 0.8

        love.graphics.push("all")

        if effect.addBlend then
                love.graphics.setBlendMode("add")
        end

        local pulse = 0.9 + 0.18 * sin(progress * pi * 4.2)
        love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], (HighlightColor[4] or 1) * BaseAlpha * 0.4)
        love.graphics.circle("fill", x, y, InnerRadius * (0.6 + 0.25 * pulse), 24)

        for index = 1, FangCount do
                local offset = (index - 1) / FangCount
                local angle = rotation + offset * pi * 2
                local sway = sin(progress * pi * (4 + index * 0.35)) * 0.18
                angle = angle + sway * 0.18

                local DirX, DirY = cos(angle), sin(angle)
                local PerpX, PerpY = -DirY, DirX

                local TipRadius = InnerRadius + (OuterRadius - InnerRadius) * (0.82 + 0.12 * sin(progress * pi * 5 + index))
                local BaseRadius = InnerRadius * (0.55 + 0.2 * cos(progress * pi * 3 + index))
                local width = InnerRadius * (0.16 + 0.1 * (1 - progress))
                local OutlineWidth = 0.8 + 0.5 * (1 - progress)

                local BaseX = x + DirX * BaseRadius
                local BaseY = y + DirY * BaseRadius
                local TipX = x + DirX * TipRadius
                local TipY = y + DirY * TipRadius
                local LeftX = BaseX + PerpX * width
                local LeftY = BaseY + PerpY * width
                local RightX = BaseX - PerpX * width
                local RightY = BaseY - PerpY * width

                local fade = 1 - offset * 0.2
                love.graphics.setLineWidth(OutlineWidth)
                love.graphics.setColor(BaseColor[1], BaseColor[2], BaseColor[3], BaseAlpha * (0.75 + 0.25 * fade))
                love.graphics.polygon("line", LeftX, LeftY, TipX, TipY, RightX, RightY)

                love.graphics.setLineWidth(OutlineWidth * 0.7)
                love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], (HighlightColor[4] or 1) * BaseAlpha * 0.85 * fade)
                love.graphics.line(LeftX, LeftY, TipX, TipY)
                love.graphics.line(RightX, RightY, TipX, TipY)

                local SlashRadius = TipRadius + InnerRadius * (0.28 + 0.18 * (1 - progress))
                local SlashWidth = 0.18 + 0.12 * (1 - progress)
                love.graphics.setLineWidth(2.4)
                love.graphics.setColor(SlashColor[1], SlashColor[2], SlashColor[3], (SlashColor[4] or 1) * BaseAlpha * 0.65 * fade)
                love.graphics.arc("line", "open", x, y, SlashRadius, angle - SlashWidth, angle + SlashWidth, 14)
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local function DrawStoneguardBastion(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local SlabColor = effect.variantColor or effect.color or {0.74, 0.8, 0.88, 1}
        local EdgeColor = effect.variantSecondaryColor or {0.46, 0.5, 0.56, 1}
        local DustColor = effect.variantTertiaryColor or {0.94, 0.96, 0.98, 0.72}

        local SlabAlpha = (SlabColor[4] or 1) * clamp01(1.05 - progress * 1.1)
        if SlabAlpha <= 0 then return end

        local SlabCount = (effect.variantData and effect.variantData.slabs) or 5
        local rotation = (effect.rotation or 0) + sin(progress * pi * 2.2) * 0.12
        local BandRadius = (InnerRadius + OuterRadius) * 0.5
        local BandThickness = (OuterRadius - InnerRadius) * (0.55 + 0.2 * (1 - progress))

        love.graphics.push("all")

        for index = 1, SlabCount do
                local offset = (index - 0.5) / SlabCount
                local angle = rotation + offset * pi * 2
                local wobble = sin(progress * pi * (3 + index * 0.4)) * 0.18
                angle = angle + wobble * 0.12

                local DirX, DirY = cos(angle), sin(angle)
                local PerpX, PerpY = -DirY, DirX

                local CenterDist = BandRadius + sin(progress * pi * 4 + index) * InnerRadius * 0.08
                local HalfWidth = BandThickness * 0.28
                local HalfTopWidth = HalfWidth * (0.78 + 0.08 * sin(progress * pi * 5 + index))
                local length = BandThickness * (0.9 + 0.18 * sin(progress * pi * 3.2 + index * 0.6))

                local InnerDist = CenterDist - length * 0.5
                local OuterDist = CenterDist + length * 0.5

                local InnerLeftX = x + DirX * InnerDist + PerpX * HalfWidth
                local InnerLeftY = y + DirY * InnerDist + PerpY * HalfWidth
                local InnerRightX = x + DirX * InnerDist - PerpX * HalfWidth
                local InnerRightY = y + DirY * InnerDist - PerpY * HalfWidth
                local OuterLeftX = x + DirX * OuterDist + PerpX * HalfTopWidth
                local OuterLeftY = y + DirY * OuterDist + PerpY * HalfTopWidth
                local OuterRightX = x + DirX * OuterDist - PerpX * HalfTopWidth
                local OuterRightY = y + DirY * OuterDist - PerpY * HalfTopWidth

                local fade = 1 - progress * 0.45
                love.graphics.setColor(SlabColor[1], SlabColor[2], SlabColor[3], SlabAlpha * (0.85 + 0.15 * fade))
                love.graphics.polygon("fill", InnerLeftX, InnerLeftY, OuterLeftX, OuterLeftY, OuterRightX, OuterRightY, InnerRightX, InnerRightY)

                love.graphics.setLineWidth(2)
                love.graphics.setColor(EdgeColor[1], EdgeColor[2], EdgeColor[3], (EdgeColor[4] or 1) * SlabAlpha * 0.95)
                love.graphics.polygon("line", InnerLeftX, InnerLeftY, OuterLeftX, OuterLeftY, OuterRightX, OuterRightY, InnerRightX, InnerRightY)

                love.graphics.setLineWidth(1.1)
                love.graphics.setColor(EdgeColor[1], EdgeColor[2], EdgeColor[3], (EdgeColor[4] or 1) * SlabAlpha * 0.55)
                love.graphics.line((InnerLeftX + OuterLeftX) * 0.5, (InnerLeftY + OuterLeftY) * 0.5, (InnerRightX + OuterRightX) * 0.5, (InnerRightY + OuterRightY) * 0.5)
        end

        local DustAlpha = (DustColor[4] or 1) * clamp01(1 - progress * 1.4)
        if DustAlpha > 0 then
                love.graphics.setColor(DustColor[1], DustColor[2], DustColor[3], DustAlpha)
                local DustCount = 8
                local DustRadius = OuterRadius * (0.62 + 0.18 * progress)
                for index = 1, DustCount do
                        local angle = rotation + index * (pi * 2 / DustCount) + sin(progress * pi * 5 + index) * 0.12
                        local distance = DustRadius * (0.88 + 0.18 * sin(progress * pi * 4 + index * 0.6))
                        local px = x + cos(angle) * distance
                        local py = y + sin(angle) * distance
                        love.graphics.circle("fill", px, py, InnerRadius * (0.14 + 0.04 * sin(progress * pi * 6 + index)), 12)
                end
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local function DrawCoiledFocus(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local CoilColor = effect.variantColor or effect.color or {0.76, 0.56, 0.88, 1}
        local BandColor = effect.variantSecondaryColor or {0.58, 0.44, 0.92, 0.9}
        local FocusColor = effect.variantTertiaryColor or {0.98, 0.9, 1.0, 0.75}

        local CoilAlpha = (CoilColor[4] or 1) * clamp01(1.08 - progress * 1.15)
        if CoilAlpha <= 0 then return end

        love.graphics.push("all")

        if effect.addBlend then
                love.graphics.setBlendMode("add")
        end

        love.graphics.translate(x, y)
        local rotation = (effect.rotation or 0) + sin(progress * pi * 3.4) * 0.16
        love.graphics.rotate(rotation)

        local CoilCount = (effect.variantData and effect.variantData.coils) or 3
        local spacing = InnerRadius * (0.8 - 0.2 * clamp01(progress * 1.2))
        for index = 1, CoilCount do
                local t = CoilCount == 1 and 0.5 or (index - 1) / (CoilCount - 1)
                local offset = (t - 0.5) * spacing
                local MajorRadius = InnerRadius * (1.1 + 0.45 * t)
                local MinorRadius = InnerRadius * (0.55 - 0.1 * t) * (1 - progress * 0.25)

                love.graphics.setLineWidth(InnerRadius * (0.42 - 0.08 * t))
                love.graphics.setColor(CoilColor[1], CoilColor[2], CoilColor[3], CoilAlpha * (0.85 - 0.18 * t))
                love.graphics.ellipse("line", offset, 0, MajorRadius, MinorRadius, 36)

                local FillAlpha = (BandColor[4] or 1) * CoilAlpha * 0.22 * (1 - 0.4 * t)
                if FillAlpha > 0 then
                        love.graphics.setColor(BandColor[1], BandColor[2], BandColor[3], FillAlpha)
                        love.graphics.ellipse("fill", offset, 0, MajorRadius * 0.92, MinorRadius * 0.72, 36)
                end
        end

        local SpiralRadius = InnerRadius * (0.7 + 0.3 * sin(progress * pi * 2.6))
        love.graphics.setLineWidth(InnerRadius * 0.18)
        love.graphics.setColor(BandColor[1], BandColor[2], BandColor[3], (BandColor[4] or 1) * CoilAlpha * 0.6)
        for i = 1, 4 do
                local angle = progress * pi * 3.2 + i * (pi * 0.5)
                local px = cos(angle) * SpiralRadius
                local py = sin(angle) * SpiralRadius * 0.8
                love.graphics.line(0, 0, px, py)
        end

        local FocusAlpha = (FocusColor[4] or 1) * clamp01(1 - progress * 1.35)
        if FocusAlpha > 0 then
                local pulse = 0.88 + 0.18 * sin(progress * pi * 4.4)
                love.graphics.setColor(FocusColor[1], FocusColor[2], FocusColor[3], FocusAlpha)
                love.graphics.circle("fill", 0, 0, InnerRadius * (0.7 + 0.35 * pulse), 24)
                love.graphics.setLineWidth(1.8)
                love.graphics.circle("line", 0, 0, InnerRadius * (1.05 + 0.25 * pulse), 24)
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local function DrawPrismRefraction(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local BeamColor = effect.variantColor or effect.color or {0.72, 0.92, 1.0, 1}
        local ShardColor = effect.variantSecondaryColor or {0.46, 0.78, 1.0, 0.95}
        local GlintColor = effect.variantTertiaryColor or {1.0, 0.96, 0.72, 0.82}

        local BeamAlpha = (BeamColor[4] or 1) * clamp01(1.08 - progress * 1.2)
        if BeamAlpha <= 0 then return end

        local ShardCount = (effect.variantData and effect.variantData.shards) or 6
        local rotation = (effect.rotation or 0) + progress * pi * 1.1

        love.graphics.push("all")

        if effect.addBlend then
                love.graphics.setBlendMode("add")
        end

        for index = 1, ShardCount do
                local offset = (index - 1) / ShardCount
                local angle = rotation + offset * pi * 2
                local sway = sin(progress * pi * (3.2 + index * 0.25)) * 0.2
                angle = angle + sway

                local DirX, DirY = cos(angle), sin(angle)
                local PerpX, PerpY = -DirY, DirX

                local InnerDist = InnerRadius * (0.72 + 0.18 * sin(progress * pi * 4 + index))
                local OuterDist = OuterRadius * (0.8 + 0.16 * sin(progress * pi * 3 + index * 1.1))
                local width = InnerRadius * (0.22 + 0.1 * (1 - progress))

                local BaseX = x + DirX * InnerDist
                local BaseY = y + DirY * InnerDist
                local TipX = x + DirX * OuterDist
                local TipY = y + DirY * OuterDist
                local LeftX = BaseX + PerpX * width
                local LeftY = BaseY + PerpY * width
                local RightX = BaseX - PerpX * width
                local RightY = BaseY - PerpY * width

                local fade = 1 - progress * 0.4
                love.graphics.setColor(ShardColor[1], ShardColor[2], ShardColor[3], (ShardColor[4] or 1) * BeamAlpha * (0.65 + 0.35 * fade))
                love.graphics.polygon("fill", LeftX, LeftY, TipX, TipY, RightX, RightY)

                love.graphics.setLineWidth(1.8)
                love.graphics.setColor(BeamColor[1], BeamColor[2], BeamColor[3], BeamAlpha * 0.9)
                love.graphics.polygon("line", LeftX, LeftY, TipX, TipY, RightX, RightY)
        end

        local GlintAlpha = (GlintColor[4] or 1) * clamp01(1 - progress * 0.95)
        if GlintAlpha > 0 then
                love.graphics.setColor(GlintColor[1], GlintColor[2], GlintColor[3], GlintAlpha)
                love.graphics.setLineWidth(2.6)
                local ArcRadius = OuterRadius * (0.82 + 0.12 * sin(progress * pi * 2))
                local ArcSpan = pi * 0.28
                local ArcCount = math.max(3, math.floor(ShardCount / 2))
                for index = 1, ArcCount do
                        local angle = rotation + index * (pi * 2 / ArcCount)
                        love.graphics.arc("line", "open", x, y, ArcRadius, angle - ArcSpan * 0.5, angle + ArcSpan * 0.5, 18)
                end
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local function DrawPhoenixFlare(effect, progress)
        local x, y = effect.x, effect.y
        local OuterRadius = effect.outerRadius or 44
        local InnerRadius = effect.innerRadius or 12
        local BaseColor = effect.variantColor or effect.color or {1, 0.6, 0.24, 1}
        local WingColor = effect.variantSecondaryColor or {1, 0.42, 0.12, 1}
        local EmberColor = effect.variantTertiaryColor or {1, 0.82, 0.44, 1}

        local BaseAlpha = (BaseColor[4] or 1) * clamp01(1.1 - progress * 1.15)
        if BaseAlpha <= 0 then return end

        local pulse = 0.9 + 0.18 * sin(progress * pi * 5)

        if effect.addBlend then
                love.graphics.setBlendMode("add")
        end

        local FlareHeight = OuterRadius * (1.1 + 0.25 * pulse)
        love.graphics.setColor(BaseColor[1], BaseColor[2], BaseColor[3], BaseAlpha * 0.55)
        love.graphics.ellipse("fill", x, y + FlareHeight * 0.1, InnerRadius * 0.85 * pulse, FlareHeight * 0.55, 36)

        local CrestAlpha = (EmberColor[4] or 1) * clamp01(1 - progress * 1.05)
        love.graphics.setColor(EmberColor[1], EmberColor[2], EmberColor[3], CrestAlpha * 0.9)
        love.graphics.polygon("fill", x, y - InnerRadius * 1.2, x + InnerRadius * 0.7, y + InnerRadius * 0.4, x, y + InnerRadius * 0.9, x - InnerRadius * 0.7, y + InnerRadius * 0.4)

        local WingAlpha = (WingColor[4] or 1) * clamp01(1 - progress * 1.35)
        local span = OuterRadius * (1.35 + 0.12 * sin(progress * pi * 4))
        local height = OuterRadius * 0.7
        for side = -1, 1, 2 do
                local points = {
                        x, y - height * 0.18,
                        x + side * span * 0.58, y - height * 0.32,
                        x + side * span * 0.9, y + height * 0.05,
                        x + side * span * 0.4, y + height * 0.55,
                        x, y + height * 0.32,
                }
                love.graphics.setColor(WingColor[1], WingColor[2], WingColor[3], WingAlpha * 0.55)
                love.graphics.polygon("fill", points)
                love.graphics.setColor(WingColor[1], WingColor[2], WingColor[3], WingAlpha)
                love.graphics.setLineWidth(2.2)
                love.graphics.polygon("line", points)
        end

        local EmberBaseAlpha = (EmberColor[4] or 1) * clamp01(1 - progress * 0.9)
        if EmberBaseAlpha > 0 then
                for i = 1, 6 do
                        local start = (i - 1) * 0.12
                        local EmberProgress = (progress - start) / 0.58
                        if EmberProgress > -0.1 and EmberProgress < 1.1 then
                                EmberProgress = clamp01(EmberProgress)
                                local fade = 1 - EmberProgress
                                local angle = (effect.rotation or 0) + i * 0.75 + progress * pi * 1.4
                                local dist = InnerRadius * (0.5 + 0.3 * sin(progress * pi * 6 + i))
                                local ex = x + cos(angle) * dist
                                local ey = y - OuterRadius * (0.15 + EmberProgress * 0.75) - i * 2
                                love.graphics.setColor(EmberColor[1], EmberColor[2], EmberColor[3], EmberBaseAlpha * fade * 0.85)
                                love.graphics.circle("fill", ex, ey, InnerRadius * 0.2 * (0.8 + 0.4 * fade), 18)
                        end
                end
        end

        if effect.addBlend then
                love.graphics.setBlendMode("alpha")
        end

        love.graphics.setLineWidth(1)
end

local function DrawAdrenalineRush(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local StreakColor = effect.variantColor or effect.color or {1, 0.46, 0.42, 1}
        local GlowColor = effect.variantSecondaryColor or {1, 0.72, 0.44, 0.95}
        local PulseColor = effect.variantTertiaryColor or {1, 0.94, 0.92, 0.85}

        local StreakAlpha = (StreakColor[4] or 1) * clamp01(1.1 - progress * 1.25)
        if StreakAlpha <= 0 then return end

        love.graphics.push("all")

        if effect.addBlend then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(GlowColor[1], GlowColor[2], GlowColor[3], (GlowColor[4] or 1) * StreakAlpha * 0.45)
                love.graphics.circle("fill", x, y, InnerRadius * (1.4 + 0.4 * sin(progress * pi * 6)), 24)
                love.graphics.setBlendMode("alpha")
        end

        local StreakCount = (effect.variantData and effect.variantData.streaks) or 7
        local rotation = (effect.rotation or 0) + sin(progress * pi * 5.2) * 0.16
        for index = 1, StreakCount do
                local offset = (index - 1) / StreakCount
                local angle = rotation + offset * pi * 2
                angle = angle + sin(progress * pi * (6 + index)) * 0.18

                local StartRadius = InnerRadius * (0.3 + 0.22 * sin(progress * pi * 4 + index))
                local EndRadius = OuterRadius * (0.85 + 0.12 * sin(progress * pi * 3.6 + index * 0.6))

                local StartX = x + cos(angle) * StartRadius
                local StartY = y + sin(angle) * StartRadius
                local EndX = x + cos(angle) * EndRadius
                local EndY = y + sin(angle) * EndRadius

                love.graphics.setLineWidth(3 - offset * 1.6)
                love.graphics.setColor(StreakColor[1], StreakColor[2], StreakColor[3], StreakAlpha * (0.75 + 0.2 * offset))
                love.graphics.line(StartX, StartY, EndX, EndY)

                local MidX = x + cos(angle) * ((StartRadius + EndRadius) * 0.55)
                local MidY = y + sin(angle) * ((StartRadius + EndRadius) * 0.55)
                love.graphics.setColor(GlowColor[1], GlowColor[2], GlowColor[3], (GlowColor[4] or 1) * StreakAlpha * 0.6)
                love.graphics.circle("fill", MidX, MidY, InnerRadius * 0.22, 12)
        end

        local PulseAlpha = (PulseColor[4] or 1) * clamp01(1 - progress * 1.1)
        if PulseAlpha > 0 then
                local PulseRadius = InnerRadius * (1 + 0.55 * sin(progress * pi * 6.2))
                love.graphics.setColor(PulseColor[1], PulseColor[2], PulseColor[3], PulseAlpha * 0.9)
                love.graphics.circle("line", x, y, PulseRadius, 32)
                love.graphics.circle("line", x, y, PulseRadius * 1.25, 32)
                love.graphics.setColor(PulseColor[1], PulseColor[2], PulseColor[3], PulseAlpha)
                love.graphics.circle("fill", x, y, InnerRadius * 0.48, 18)
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local function DrawEventHorizon(effect, progress)
        local x, y = effect.x, effect.y
        local OuterRadius = effect.outerRadius or 44
        local InnerRadius = effect.innerRadius or 12
        local HighlightColor = effect.variantColor or effect.color or {1, 0.82, 0.38, 1}
        local ShardColor = effect.variantSecondaryColor or {0.4, 0.7, 1.0, 1}

        local GravityAlpha = clamp01(1 - progress * 0.9)
        if GravityAlpha <= 0 then return end

        love.graphics.setColor(0.02, 0.02, 0.08, 0.7 * GravityAlpha)
        love.graphics.circle("fill", x, y, OuterRadius * (0.65 + 0.2 * progress), 48)

        love.graphics.setColor(0, 0, 0, 0.88 * GravityAlpha)
        love.graphics.circle("fill", x, y, InnerRadius * (1.25 - 0.4 * progress), 48)

        love.graphics.setLineWidth(3)
        for i = 1, 3 do
                local radius = InnerRadius * (1.7 + i * 0.55)
                local StartAngle = (effect.rotation or 0) + progress * pi * (1.6 + i * 0.25) + i * 0.6
                local sweep = pi * (0.45 + 0.1 * i)
                local alpha = (HighlightColor[4] or 1) * clamp01(1.15 - progress * (0.7 + i * 0.15)) * 0.9
                love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], alpha)
                love.graphics.arc("line", "open", x, y, radius, StartAngle, StartAngle + sweep, 32)
        end

        local ShardAlpha = (ShardColor[4] or 1) * GravityAlpha
        for i = 1, 6 do
                local orbit = InnerRadius * (1.2 + i * 0.32)
                local angle = (effect.rotation or 0) + progress * pi * (2.6 + i * 0.18) + i * 0.8
                local ex = x + cos(angle) * orbit
                local ey = y + sin(angle) * orbit
                love.graphics.setColor(ShardColor[1], ShardColor[2], ShardColor[3], ShardAlpha * (0.65 + 0.25 * ((i % 2 == 0) and 1 or 0.8)))
                love.graphics.circle("fill", ex, ey, InnerRadius * 0.22 * clamp01(1.05 - progress * 0.8), 18)
        end

        local RimAlpha = (HighlightColor[4] or 1) * clamp01(1 - progress * 1.2)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(HighlightColor[1], HighlightColor[2], HighlightColor[3], RimAlpha)
        love.graphics.circle("line", x, y, OuterRadius * (0.92 - 0.18 * progress), 48)

        love.graphics.setLineWidth(1)
end

local function DrawStormBurst(effect, progress)
        local x, y = effect.x, effect.y
        local OuterRadius = effect.outerRadius or 44
        local InnerRadius = effect.innerRadius or 12
        local BoltColor = effect.variantColor or effect.color or {0.86, 0.94, 1.0, 1}
        local AuraColor = effect.variantSecondaryColor or {0.34, 0.66, 1.0, 0.9}
        local SparkColor = effect.variantTertiaryColor or {1, 0.95, 0.75, 0.9}

        local alpha = (BoltColor[4] or 1) * clamp01(1.05 - progress * 1.15)
        if alpha <= 0 then return end

        if effect.addBlend then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(AuraColor[1], AuraColor[2], AuraColor[3], (AuraColor[4] or 1) * alpha * 0.55)
                love.graphics.circle("fill", x, y, OuterRadius * (0.78 + 0.18 * sin(progress * pi * 4)), 36)
                love.graphics.setBlendMode("alpha")
        end

        local branches = 3
        for branch = 1, branches do
                local delay = (branch - 1) * 0.08
                local BranchProgress = clamp01((progress - delay) / (0.78 - delay * 0.4))
                if BranchProgress > 0 then
                        local BranchAlpha = alpha * (1 - 0.2 * (branch - 1))
                        local angle = (effect.rotation or 0) + branch * (pi / 3) + sin(progress * pi * (3 + branch)) * 0.2
                        local length = OuterRadius * (1.25 + 0.22 * branch) * BranchProgress
                        local lateral = InnerRadius * (0.9 - 0.18 * branch)

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

                        love.graphics.setColor(BoltColor[1], BoltColor[2], BoltColor[3], BranchAlpha)
                        love.graphics.setLineWidth(3.2 - branch * 0.4)
                        love.graphics.line(points)

                        local TipX = points[#points - 1]
                        local TipY = points[#points]
                        love.graphics.setColor(BoltColor[1], BoltColor[2], BoltColor[3], BranchAlpha * 0.8)
                        love.graphics.circle("fill", TipX, TipY, InnerRadius * 0.35, 18)
                end
        end

        local SparkAlpha = (SparkColor[4] or 1) * alpha * 0.75
        if SparkAlpha > 0 then
                for i = 1, 6 do
                        local angle = (effect.rotation or 0) + i * (pi / 3) + progress * pi * 1.8
                        local radius = InnerRadius * (1.6 + 0.35 * sin(progress * pi * 5 + i))
                        local sx = x + cos(angle) * radius
                        local sy = y + sin(angle) * radius
                        love.graphics.setColor(SparkColor[1], SparkColor[2], SparkColor[3], SparkAlpha)
                        love.graphics.circle("fill", sx, sy, InnerRadius * 0.28, 12)
                end
        end

        love.graphics.setLineWidth(1)
end

local function DrawGuidingCompass(effect, progress)
        local x, y = effect.x, effect.y
        local InnerRadius = effect.innerRadius or 12
        local OuterRadius = effect.outerRadius or 44
        local RingColor = effect.variantColor or effect.color or {0.72, 0.86, 1.0, 1}
        local PointerColor = effect.variantSecondaryColor or {1.0, 0.82, 0.42, 1}
        local MarkerColor = effect.variantTertiaryColor or {0.48, 0.72, 1.0, 0.85}

        local RingAlpha = (RingColor[4] or 1) * clamp01(1.05 - progress * 1.15)
        if RingAlpha <= 0 then return end

        love.graphics.push("all")

        local rotation = (effect.rotation or 0) + progress * pi * 0.7

        love.graphics.setColor(RingColor[1], RingColor[2], RingColor[3], RingAlpha * 0.35)
        love.graphics.circle("fill", x, y, OuterRadius * (0.82 - 0.12 * progress), 48)

        love.graphics.setLineWidth(2.4)
        love.graphics.setColor(RingColor[1], RingColor[2], RingColor[3], RingAlpha)
        love.graphics.circle("line", x, y, OuterRadius * (0.78 - 0.16 * progress), 48)

        local MarkerAlpha = (MarkerColor[4] or 1) * clamp01(1 - progress * 1.25)
        if MarkerAlpha > 0 then
                for index = 1, 8 do
                        local weight = (index % 2 == 0) and 1 or 0.6
                        local angle = rotation + index * (pi / 4)
                        local inner = InnerRadius * (0.85 + 0.12 * weight)
                        local outer = OuterRadius * (0.58 + 0.18 * weight)
                        local sx = x + cos(angle) * inner
                        local sy = y + sin(angle) * inner
                        local ex = x + cos(angle) * outer
                        local ey = y + sin(angle) * outer
                        love.graphics.setLineWidth(1.4 + weight * 0.8)
                        love.graphics.setColor(MarkerColor[1], MarkerColor[2], MarkerColor[3], MarkerAlpha * weight)
                        love.graphics.line(sx, sy, ex, ey)
                end
        end

        local PointerAlpha = (PointerColor[4] or 1) * clamp01(1.1 - progress * 1.05)
        if PointerAlpha > 0 then
                local PointerAngle = rotation + progress * pi * 1.4
                local TipRadius = OuterRadius * (0.68 + 0.08 * sin(progress * pi * 4))
                local TailRadius = InnerRadius * 0.7
                local LeftAngle = PointerAngle + pi * 0.55
                local RightAngle = PointerAngle - pi * 0.55

                love.graphics.setColor(PointerColor[1], PointerColor[2], PointerColor[3], PointerAlpha * 0.9)
                love.graphics.polygon(
                        "fill",
                        x + cos(PointerAngle) * TipRadius,
                        y + sin(PointerAngle) * TipRadius,
                        x + cos(LeftAngle) * TailRadius,
                        y + sin(LeftAngle) * TailRadius,
                        x,
                        y,
                        x + cos(RightAngle) * TailRadius,
                        y + sin(RightAngle) * TailRadius
                )

                love.graphics.setLineWidth(2)
                love.graphics.setColor(PointerColor[1], PointerColor[2], PointerColor[3], PointerAlpha)
                love.graphics.polygon(
                        "line",
                        x + cos(PointerAngle) * TipRadius,
                        y + sin(PointerAngle) * TipRadius,
                        x + cos(LeftAngle) * TailRadius,
                        y + sin(LeftAngle) * TailRadius,
                        x,
                        y,
                        x + cos(RightAngle) * TailRadius,
                        y + sin(RightAngle) * TailRadius
                )
        end

        local InnerAlpha = (MarkerColor[4] or 1) * clamp01(1 - progress * 0.95)
        if InnerAlpha > 0 then
                local pulse = 0.9 + 0.2 * sin(progress * pi * 5)
                love.graphics.setColor(MarkerColor[1], MarkerColor[2], MarkerColor[3], InnerAlpha)
                love.graphics.circle("line", x, y, InnerRadius * (0.9 + 0.35 * pulse), 30)
                love.graphics.circle("line", x, y, InnerRadius * (1.35 + 0.25 * pulse), 30)
        end

        love.graphics.pop()
        love.graphics.setLineWidth(1)
end

local VariantDrawers = {
        phoenix_flare = DrawPhoenixFlare,
        event_horizon = DrawEventHorizon,
        storm_burst = DrawStormBurst,
        fang_flurry = DrawFangFlurry,
        stoneguard_bastion = DrawStoneguardBastion,
        prism_refraction = DrawPrismRefraction,
        coiled_focus = DrawCoiledFocus,
        adrenaline_rush = DrawAdrenalineRush,
        guiding_compass = DrawGuidingCompass,
}

local function DrawVariant(effect, progress)
        if not effect.variant then return end
        local drawer = VariantDrawers[effect.variant]
        if not drawer then return end
        drawer(effect, progress)
end

local function DrawRings(effect, progress)
        local color = effect.color or {1, 1, 1, 1}
        local RingCount = effect.ringCount or 1
        local RingSpacing = effect.ringSpacing or 10
	local OuterRadius = effect.outerRadius or 44
	local InnerRadius = effect.innerRadius or 12
	local PulseDelay = effect.pulseDelay or 0.12

	for index = 1, RingCount do
		local delay = (index - 1) * PulseDelay
		local RingProgress = clamp01((progress - delay) / (1 - delay))
		if RingProgress > 0 then
			local eased = RingProgress * RingProgress
			local radius = InnerRadius + (OuterRadius - InnerRadius) * eased + (index - 1) * RingSpacing
			local alpha = (color[4] or 1) * clamp01(1.1 - RingProgress * 1.1)
			if alpha > 0 then
				love.graphics.setLineWidth((effect.ringWidth or 4) * (1 - 0.35 * eased))
				love.graphics.setColor(color[1], color[2], color[3], alpha)
				love.graphics.circle("line", effect.x, effect.y, radius, 48)
			end
		end
	end

	love.graphics.setLineWidth(1)
end

local function DrawGlow(effect, progress)
	if not effect.addBlend then return end
	love.graphics.setBlendMode("add")

	local HaloColor = effect.haloColor
	if HaloColor and (HaloColor[4] or 0) > 0 then
		local HaloAlpha = HaloColor[4] * clamp01(1 - progress)
		if HaloAlpha > 0 then
			love.graphics.setColor(HaloColor[1], HaloColor[2], HaloColor[3], HaloAlpha)
			love.graphics.circle("fill", effect.x, effect.y, (effect.outerRadius or 44) * (0.4 + progress * 0.45), 36)
		end
	end

	local GlowColor = effect.glowColor
	if GlowColor and (GlowColor[4] or 0) > 0 then
		local GlowAlpha = GlowColor[4] * clamp01(1 - progress * 0.8)
		if GlowAlpha > 0 then
			local pulse = 0.9 + 0.2 * sin(progress * pi * 4)
			love.graphics.setColor(GlowColor[1], GlowColor[2], GlowColor[3], GlowAlpha)
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
                        DrawGlow(effect, progress)
                        DrawRings(effect, progress)
                        DrawBadge(effect, progress)
                end
                DrawVariant(effect, progress)
        end

        love.graphics.pop()
end

function UpgradeVisuals:reset()
	self.effects = {}
end

function UpgradeVisuals:IsEmpty()
	return #self.effects == 0
end

return UpgradeVisuals
