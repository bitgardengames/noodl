local Theme = require("theme")

local Shaders = {}

local function GetColorComponents(color, fallback)
	color = color or fallback or {0, 0, 0, 1}

	local r = color[1] or 0
	local g = color[2] or 0
	local b = color[3] or 0
	local a = color[4]

	if a == nil then
		a = 1
	end

	return {r, g, b, a}
end

local function lerp(a, b, t)
	if not a then
		return b
	end

	return a + (b - a) * t
end

local function ShaderHasUniform(shader, name)
	if not shader or not shader.hasUniform then
		return true
	end

	return shader:hasUniform(name)
end

local function SendColor(shader, name, color)
	if ShaderHasUniform(shader, name) then
		shader:sendColor(name, color)
	end
end

local function SendFloat(shader, name, value)
	if ShaderHasUniform(shader, name) then
		shader:send(name, value)
	end
end

local WHITE = {1, 1, 1, 1}

local ReactiveState = {
	ComboTarget = 0,
	ComboDisplay = 0,
	ComboPulse = 0,
	ComboPulseTarget = 0,
	EventPulse = 0,
	EventPulseTarget = 0,
	EventColor = {1, 1, 1, 1},
	LastCombo = 0,
}

local EVENT_COLORS = {
	combo = {1.0, 0.86, 0.45, 1},
	ComboBoost = {1.0, 0.92, 0.55, 1},
	shield = {0.7, 0.98, 0.86, 1},
	StallSaws = {0.65, 0.82, 1.0, 1},
	score = {1.0, 0.72, 0.36, 1},
	dragonfruit = {1.0, 0.45, 0.28, 1},
	danger = {1.0, 0.38, 0.38, 1},
	tension = {1.0, 0.67, 0.35, 1},
}

local function AssignEventColor(color)
	local components = GetColorComponents(color, WHITE)
	ReactiveState.eventColor[1] = components[1]
	ReactiveState.eventColor[2] = components[2]
	ReactiveState.eventColor[3] = components[3]
	ReactiveState.eventColor[4] = components[4] or 1
end

function Shaders.notify(event, data)
	if event == "ComboChanged" then
		local combo = math.max(0, (data and data.combo) or 0)
		if combo >= 2 then
			ReactiveState.comboTarget = combo
			if combo > (ReactiveState.lastCombo or 0) then
				ReactiveState.comboPulseTarget = math.min((ReactiveState.comboPulseTarget or 0) + 0.35, 0.9)
			end
		else
			ReactiveState.comboTarget = 0
		end

		ReactiveState.lastCombo = combo
	elseif event == "ComboLost" then
		ReactiveState.comboTarget = 0
		ReactiveState.comboPulseTarget = 0
		ReactiveState.lastCombo = 0
	elseif event == "SpecialEvent" then
		local strength = math.max((data and data.strength) or 0.7, 0)
		local color = (data and data.color) or EVENT_COLORS[(data and data.type) or ""]
		ReactiveState.eventPulseTarget = math.min((ReactiveState.eventPulseTarget or 0) + strength * 0.6, 1.5)
		if color then
			AssignEventColor(color)
		end
	end
end

function Shaders.update(dt)
	if not dt or dt <= 0 then
		return
	end

	local smoothing = math.min(dt * 4.2, 1)
	ReactiveState.comboDisplay = lerp(ReactiveState.comboDisplay, ReactiveState.comboTarget, smoothing)
	ReactiveState.comboPulseTarget = math.max(0, (ReactiveState.comboPulseTarget or 0) - dt * 1.35)
	ReactiveState.eventPulseTarget = math.max(0, (ReactiveState.eventPulseTarget or 0) - dt * 1.1)

	local PulseSmoothing = math.min(dt * 6.5, 1)
	ReactiveState.comboPulse = lerp(ReactiveState.comboPulse, ReactiveState.comboPulseTarget or 0, PulseSmoothing)
	ReactiveState.eventPulse = lerp(ReactiveState.eventPulse, ReactiveState.eventPulseTarget or 0, PulseSmoothing)

	local ColorFade = math.min(dt * 1.6, 1)
	ReactiveState.eventColor[1] = lerp(ReactiveState.eventColor[1], 1, ColorFade)
	ReactiveState.eventColor[2] = lerp(ReactiveState.eventColor[2], 1, ColorFade)
	ReactiveState.eventColor[3] = lerp(ReactiveState.eventColor[3], 1, ColorFade)
	ReactiveState.eventColor[4] = 1
end

local function ComputeReactiveResponse()
	local ComboValue = ReactiveState.comboDisplay or 0
	local ComboStrength = 0
	if ComboValue >= 2 then
		ComboStrength = math.min((ComboValue - 1.5) / 8.0, 1.0)
	end

	local ComboPulse = ReactiveState.comboPulse or 0
	local EventPulse = ReactiveState.eventPulse or 0

	local boost = ComboStrength * 0.25 + ComboPulse * 0.18 + EventPulse * 0.32
	boost = math.max(0, math.min(boost, 0.65))

	local TintBlend = math.min(0.25, EventPulse * 0.25 + ComboStrength * 0.15)
	local EventColor = ReactiveState.eventColor or WHITE
	local tint = {
		lerp(1, EventColor[1] or 1, TintBlend),
		lerp(1, EventColor[2] or 1, TintBlend),
		lerp(1, EventColor[3] or 1, TintBlend),
		1,
	}

	return 1 + boost, ComboStrength, ComboPulse, EventPulse, tint, boost
end

local function DrawShader(effect, x, y, w, h, intensity, SendUniforms, DrawOptions)
	if not (effect and effect.shader) then
		return false
	end

	if w <= 0 or h <= 0 then
		return false
	end

	local shader = effect.shader
	local ActualIntensity = intensity or 1.0

	local IntensityMultiplier, ComboStrength, ComboPulse, EventPulse, tint, boost = ComputeReactiveResponse()
	ActualIntensity = ActualIntensity * IntensityMultiplier

	if ShaderHasUniform(shader, "origin") then
		shader:send("origin", {x, y})
	end

	if ShaderHasUniform(shader, "resolution") then
		shader:send("resolution", {w, h})
	end

        local now = love.timer.getTime()

	if ShaderHasUniform(shader, "time") then
		shader:send("time", now)
	end

	if ShaderHasUniform(shader, "intensity") then
		shader:send("intensity", ActualIntensity)
	end

	if ShaderHasUniform(shader, "ComboLevel") then
		shader:send("ComboLevel", ReactiveState.comboDisplay or 0)
	end

	if ShaderHasUniform(shader, "ComboStrength") then
		shader:send("ComboStrength", ComboStrength)
	end

	if ShaderHasUniform(shader, "ComboPulse") then
		shader:send("ComboPulse", ComboPulse)
	end

	if ShaderHasUniform(shader, "EventPulse") then
		shader:send("EventPulse", EventPulse)
	end

	if ShaderHasUniform(shader, "ReactiveBoost") then
		shader:send("ReactiveBoost", boost)
	end

	if ShaderHasUniform(shader, "EventTint") then
		shader:sendColor("EventTint", tint)
	end

	if SendUniforms then
		SendUniforms(shader, now, x, y, w, h, ActualIntensity)
	end

	local RadiusX, RadiusY = 0, 0
	if DrawOptions then
		if DrawOptions.radiusX or DrawOptions.radiusY then
			RadiusX = DrawOptions.radiusX or DrawOptions.radius or 0
			RadiusY = DrawOptions.radiusY or DrawOptions.radius or 0
		elseif DrawOptions.radius then
			RadiusX = DrawOptions.radius
			RadiusY = DrawOptions.radius
		end
	end

	love.graphics.push("all")
	love.graphics.setShader(shader)
	love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
	love.graphics.rectangle("fill", x, y, w, h, RadiusX, RadiusY)
	love.graphics.pop()

	return true
end

local EffectDefinitions = {}

local function RegisterEffect(def)
	EffectDefinitions[def.type] = def
end

-- Gentle canopy gradient for relaxed botanical floors
RegisterEffect({
	type = "SoftCanopy",
	BackdropIntensity = 0.52,
	ArenaIntensity = 0.3,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 CanopyColor;
		extern vec4 GlowColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float sway = sin((uv.x + time * 0.05) * 3.2) * 0.04;
			float canopy = smoothstep(0.18, 0.82, uv.y + sway);
			float LightBands = sin((uv.x * 5.0 + uv.y * 1.2) + time * 0.25) * 0.5 + 0.5;

			vec3 CanopyBase = mix(BaseColor.rgb, CanopyColor.rgb, canopy * 0.5);
			vec3 soil = mix(BaseColor.rgb, GlowColor.rgb, 0.35);
			vec3 base = mix(CanopyBase, soil, smoothstep(0.2, 0.9, uv.y) * 0.4);
			float highlight = clamp(LightBands * (0.22 + intensity * 0.16), 0.0, 1.0);
			vec3 col = mix(base, GlowColor.rgb, highlight * 0.45);
			col = mix(col, soil, 0.18);

			float vignette = smoothstep(0.45, 0.98, distance(uv, vec2(0.5)));
			col = mix(col, BaseColor.rgb, vignette * 0.35);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local canopy = GetColorComponents(palette and palette.arenaBG, Theme.ArenaBG)
		local glow = GetColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.ArenaBorder)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "CanopyColor", canopy)
		SendColor(shader, "GlowColor", glow)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})

-- Soft cavern haze with muted glints
RegisterEffect({
	type = "SoftCavern",
	BackdropIntensity = 0.48,
	ArenaIntensity = 0.28,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 FogColor;
		extern vec4 GlintColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float ceiling = smoothstep(0.1, 0.7, uv.y + sin((uv.x * 3.5) + time * 0.18) * 0.04);
			float mist = smoothstep(0.0, 1.0, uv.y * 1.1);
			float shimmer = sin((uv.x * 6.0 - uv.y * 1.2) + time * 0.32) * 0.5 + 0.5;
			float ColorPulse = sin((uv.x + uv.y) * 4.6 + time * 0.45) * 0.5 + 0.5;

			vec3 base = mix(BaseColor.rgb, FogColor.rgb, ceiling * 0.58 + mist * 0.42);
			float highlight = clamp((shimmer * 0.38 + 0.16) * intensity, 0.0, 1.0);
			vec3 col = mix(base, GlintColor.rgb, highlight * 0.62);

			vec3 accent = mix(GlintColor.rgb, FogColor.rgb, 0.28);
			col = mix(col, accent, ColorPulse * 0.22 * intensity);

			float ambient = clamp(0.18 + intensity * 0.32, 0.0, 0.48);
			col = mix(col, mix(FogColor.rgb, GlintColor.rgb, 0.22), ambient);

			float depth = smoothstep(0.0, 0.4, uv.y);
			col = mix(col, BaseColor.rgb, depth * 0.06);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local fog = GetColorComponents(palette and (palette.arenaBG or palette.rock), Theme.ArenaBG)
		local glint = GetColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.ArenaBorder)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "FogColor", fog)
		SendColor(shader, "GlintColor", glint)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})

-- Gentle tidal drift for calmer aquatic stages
RegisterEffect({
	type = "SoftCurrent",
	BackdropIntensity = 0.56,
	ArenaIntensity = 0.32,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 DeepColor;
		extern vec4 FoamColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float depth = smoothstep(0.0, 1.0, uv.y);
			float wave = sin((uv.x * 3.6 - uv.y * 1.4) + time * 0.22) * 0.5 + 0.5;
			float shafts = sin((uv.y * 2.4) - time * 0.18) * 0.5 + 0.5;
			float CausticA = sin((uv.x * 7.2 + uv.y * 2.8) + time * 0.35) * 0.5 + 0.5;
			float CausticB = sin((uv.x * 5.1 - uv.y * 5.4) - time * 0.28) * 0.5 + 0.5;
			float caustics = clamp((CausticA * 0.6 + CausticB * 0.4), 0.0, 1.0);

			vec3 gradient = mix(BaseColor.rgb, DeepColor.rgb, depth * 0.52);
			float highlight = clamp((wave * 0.42 + shafts * 0.28 + caustics * 0.38 + 0.18) * intensity, 0.0, 1.0);
			vec3 col = mix(gradient, FoamColor.rgb, highlight * 0.48);

			float ambient = clamp(0.18 + intensity * 0.34, 0.0, 0.48);
			vec3 undertow = mix(FoamColor.rgb, DeepColor.rgb, 0.46);
			col = mix(col, undertow, ambient * 0.7);

			float seam = 1.0 - smoothstep(0.0, 0.18, abs(uv.y - 0.4));
			vec3 SeamColor = mix(FoamColor.rgb, BaseColor.rgb, 0.48);
			col = mix(col, SeamColor, seam * caustics * 0.22 * intensity);

			float vignette = smoothstep(0.5, 1.0, distance(uv, vec2(0.5)));
			col = mix(col, BaseColor.rgb, vignette * 0.18);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local deep = GetColorComponents(palette and (palette.arenaBG or palette.rock), Theme.ArenaBG)
		local foam = GetColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.ArenaBorder)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "DeepColor", deep)
		SendColor(shader, "FoamColor", foam)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Forest canopy shimmer for lush floors
RegisterEffect({
	type = "ForestCanopy",
	BackdropIntensity = 0.65,
	ArenaIntensity = 0.38,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 LightColor;
		extern vec4 AccentColor;
		extern float intensity;

		float hash(vec2 p)
		{
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}

		vec2 hash2(vec2 p)
		{
			return vec2(hash(p), hash(p + 19.19));
		}

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			vec3 col = BaseColor.rgb;

			float CanopyLight = smoothstep(0.55, 0.0, uv.y);
			col = mix(col, LightColor.rgb, CanopyLight * 0.2 * intensity);

			float BloomMask = smoothstep(0.6, 0.18, distance(uv, vec2(0.5, 0.35)));
			vec3 BloomColor = mix(LightColor.rgb, AccentColor.rgb, 0.25);
			col += BloomColor * BloomMask * 0.12 * intensity;

			for (int i = 0; i < 3; ++i)
			{
				float fi = float(i);
				float density = 2.6 + fi * 2.0;
				float speed = 0.04 + fi * 0.03;
				float size = 0.2 - fi * 0.045;
				float LayerStrength = 0.18 + fi * 0.08;

				vec2 grid = (uv + vec2(0.0, time * speed)) * density;
				vec2 cell = floor(grid);
				vec2 CellUV = fract(grid);
				vec2 rand = hash2(cell + fi * 17.0);

				float d = distance(CellUV, rand);
				float particle = exp(-d * d / (size * size + 1e-5));

				vec3 GlowColor = mix(LightColor.rgb, AccentColor.rgb, 0.3 + fi * 0.22);
				float softness = smoothstep(0.0, 1.0, 1.0 - d * 1.3);
				float blend = clamp(particle * LayerStrength * intensity * (0.6 + softness * 0.4), 0.0, 1.0);
				col = mix(col, GlowColor, blend);
			}

			float vignette = smoothstep(0.92, 0.48, distance(uv, vec2(0.5)));
			col = mix(BaseColor.rgb, col, clamp(vignette, 0.0, 1.0));

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local light = GetColorComponents(palette and palette.arenaBorder, Theme.ArenaBorder)
		local accent = GetColorComponents(palette and palette.snake, Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "LightColor", light)
		SendColor(shader, "AccentColor", accent)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})

-- Holographic overlay for high-rarity shop cards
RegisterEffect({
	type = "CardHologram",
	BackdropIntensity = 1.0,
	ArenaIntensity = 1.0,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 SparkleColor;
		extern vec4 RimColor;
		extern float intensity;
		extern float parallax;
		extern float ScanOffset;

		float hash(vec2 p)
		{
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			vec2 centered = uv - 0.5;
			float radius = length(centered * vec2(1.15, 1.0));
			float angle = atan(centered.y, centered.x);

			float prism = sin(angle * 9.0 + time * 0.75 + parallax * 1.5) * 0.5 + 0.5;
			float bands = sin((uv.y + parallax * 0.2) * 14.0 + time * 0.9 + uv.x * 7.0);
			float holo = clamp(0.35 + prism * 0.45 + bands * 0.2, 0.0, 1.0);

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, holo * intensity);

			float sweep = smoothstep(-0.25, 0.85, uv.y + sin(time * 0.6 + parallax * 0.3) * 0.1);
			float shimmer = sin((uv.x + uv.y) * 18.0 + time * 2.4);
			float SparkleMix = clamp(sweep * 0.35 + (shimmer * 0.15 + 0.15), 0.0, 1.0);
			col = mix(col, SparkleColor.rgb, SparkleMix * intensity);

			vec2 grid = floor((uv + vec2(time * 0.05, ScanOffset)) * vec2(18.0, 26.0));
			float SparkSeed = hash(grid + floor(time * 1.2));
			float spark = smoothstep(0.7, 1.0, SparkSeed) * (1.0 - radius) * intensity;
			col += SparkleColor.rgb * spark * 0.4;

			float scan = sin((uv.y + ScanOffset - time * 0.8) * 20.0) * 0.5 + 0.5;
			col += SparkleColor.rgb * scan * 0.08 * intensity;

			float rim = smoothstep(0.55, 0.95, 1.0 - radius);
			col = mix(col, RimColor.rgb, rim * (0.3 + 0.4 * intensity));

			col = mix(BaseColor.rgb, col, 0.82);
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette, EffectData)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.baseColor or palette.bgColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.ButtonHover)
		local sparkle = GetColorComponents(palette and (palette.sparkleColor or palette.highlightColor), Theme.AccentTextColor)
		local rim = GetColorComponents(palette and (palette.rimColor or palette.edgeColor), Theme.BorderColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "SparkleColor", sparkle)
		SendColor(shader, "RimColor", rim)

		local parallax = EffectData and EffectData.parallax or 0
		local ScanOffset = EffectData and EffectData.scanOffset or 0

		SendFloat(shader, "parallax", parallax)
		SendFloat(shader, "ScanOffset", ScanOffset)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity, nil, { radius = 12 })
	end,
})
-- Cool cavern mist and echoing shimmer
RegisterEffect({
	type = "EchoMist",
	BackdropIntensity = 0.7,
	ArenaIntensity = 0.4,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 MistColor;
		extern vec4 AccentColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float WaveA = sin(uv.y * 4.2 - time * 0.2);
			float WaveB = sin((uv.x + uv.y) * 5.0 + time * 0.15);
			float layering = mix(WaveA, WaveB, 0.5);
			float depth = smoothstep(0.0, 1.0, uv.y);
			float mist = clamp((layering * 0.25 + 0.5) * intensity, 0.0, 1.0);
			float glimmer = clamp((sin(uv.x * 10.0 + time * 0.4) * 0.15 + 0.5) * intensity * 0.5, 0.0, 1.0);

			vec3 col = mix(BaseColor.rgb, MistColor.rgb, mist * 0.7);
			col = mix(col, AccentColor.rgb, glimmer * (0.3 + depth * 0.2));

			float fade = smoothstep(0.0, 0.6, uv.y);
			col = mix(BaseColor.rgb, col, clamp(fade + 0.15, 0.0, 1.0));

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local mist = GetColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.ArenaBorder)
		local accent = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "MistColor", mist)
		SendColor(shader, "AccentColor", accent)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
RegisterEffect({
	type = "MushroomPulse",
	BackdropIntensity = 0.95,
	ArenaIntensity = 0.6,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 CavernColor;
		extern vec4 StemColor;
		extern vec4 BloomColor;
		extern vec4 EmberColor;
		extern vec4 HazeColor;
		extern float intensity;

		float hash(vec2 p)
		{
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}

		float noise(vec2 p)
		{
			vec2 i = floor(p);
			vec2 f = fract(p);
			vec2 u = f * f * (3.0 - 2.0 * f);

			float a = hash(i);
			float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0));
			float d = hash(i + vec2(1.0, 1.0));

			return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
		}

		float SoftCap(vec2 uv, vec2 center, vec2 radius)
		{
			vec2 p = (uv - center) / radius;
			float d = dot(p, p);
			return exp(-d * 2.6);
		}

		float SoftStem(vec2 uv, vec2 base, vec2 size)
		{
			vec2 p = uv - base;
			float vertical = smoothstep(-0.02, size.y, p.y) * (1.0 - smoothstep(size.y * 0.9, size.y, p.y));
			float width = smoothstep(size.x, 0.0, abs(p.x));
			return clamp(vertical * width, 0.0, 1.0);
		}

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			vec2 centered = uv - vec2(0.5);
			float aspect = resolution.x / max(resolution.y, 0.0001);
			centered.x *= aspect;

			float horizon = smoothstep(-0.45, 0.55, centered.y);
			float CavernMix = 0.35 + 0.45 * horizon;
			vec3 col = mix(BaseColor.rgb, CavernColor.rgb, CavernMix);

			float MistBand = smoothstep(-0.08, 0.32, centered.y) * smoothstep(0.85, 0.15, abs(centered.x));
			float MistPulse = 0.4 + 0.6 * noise(centered * 2.5 + vec2(0.0, time * 0.1));
			col = mix(col, HazeColor.rgb, MistBand * MistPulse * 0.25 * (0.6 + intensity * 0.4));

			vec2 SceneUV = uv;
			float GentleDrift = 0.5 + 0.5 * sin(time * 0.25);

			float StemsMask = 0.0;
			StemsMask += SoftStem(SceneUV, vec2(0.32, 0.42 + 0.01 * GentleDrift), vec2(0.045, 0.26));
			StemsMask += SoftStem(SceneUV, vec2(0.52, 0.44 - 0.01 * GentleDrift), vec2(0.05, 0.24));
			StemsMask += SoftStem(SceneUV, vec2(0.70, 0.40 + 0.008 * GentleDrift), vec2(0.04, 0.28));
			StemsMask = clamp(StemsMask, 0.0, 1.0);

			vec3 stems = mix(col, StemColor.rgb, StemsMask * (0.4 + intensity * 0.35));

			float cap1 = SoftCap(SceneUV, vec2(0.32, 0.58 + 0.012 * GentleDrift), vec2(0.16, 0.11));
			float cap2 = SoftCap(SceneUV, vec2(0.52, 0.60 - 0.008 * GentleDrift), vec2(0.19, 0.12));
			float cap3 = SoftCap(SceneUV, vec2(0.70, 0.57 + 0.014 * GentleDrift), vec2(0.15, 0.10));

			float CapCluster = clamp(cap1 + cap2 * 0.9 + cap3, 0.0, 1.0);
			float pulse = 0.65 + 0.35 * pow(0.5 + 0.5 * sin(time * 0.6 + CapCluster * 2.5), 2.0);
			vec3 caps = mix(stems, BloomColor.rgb, CapCluster * pulse);

			float EmberNoise = noise(SceneUV * 4.5 + vec2(time * 0.2, -time * 0.15));
			float EmberMask = smoothstep(0.55, 0.95, CapCluster) * EmberNoise;
			vec3 embers = mix(caps, EmberColor.rgb, EmberMask * 0.18 * (0.5 + intensity * 0.5));

			float AmbientGlow = smoothstep(0.2, 0.75, CapCluster) * (0.3 + 0.3 * GentleDrift);
			vec3 GlowLayer = mix(embers, HazeColor.rgb, AmbientGlow * 0.2);

			float drift = noise(centered * 1.5 + vec2(time * 0.05, time * 0.04));
			float FloorFog = smoothstep(-0.35, 0.25, centered.y) * (0.25 + 0.35 * drift);
			GlowLayer = mix(GlowLayer, HazeColor.rgb, FloorFog * 0.15 * (0.4 + intensity * 0.6));

			float vignette = smoothstep(0.2, 0.9, length(centered));
			vec3 FinalColor = mix(GlowLayer, BaseColor.rgb, vignette * 0.3);

			return vec4(FinalColor, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local cavern = GetColorComponents(palette and palette.arenaBG, Theme.ArenaBG)
		local stems = GetColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.ArenaBorder)
		local bloom = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)
		local ember = GetColorComponents(palette and (palette.sawColor or palette.snake), Theme.SawColor)
		local haze = GetColorComponents(palette and (palette.arenaHighlight or palette.uiAccent), Theme.UiAccent)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "CavernColor", cavern)
		SendColor(shader, "StemColor", stems)
		SendColor(shader, "BloomColor", bloom)
		SendColor(shader, "EmberColor", ember)
		SendColor(shader, "HazeColor", haze)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Gentle tidal movement for waterlogged floors
RegisterEffect({
	type = "TidalCurrent",
	BackdropIntensity = 0.8,
	ArenaIntensity = 0.5,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 DeepColor;
		extern vec4 FoamColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float wave = sin((uv.x + time * 0.15) * 3.5);
			float wave2 = sin((uv.x * 4.0 - uv.y * 2.0) + time * 0.12);
			float ripple = (wave * 0.6 + wave2 * 0.4) * 0.5 + 0.5;

			float depth = smoothstep(0.0, 1.0, uv.y);

			vec3 layer = mix(BaseColor.rgb, DeepColor.rgb, depth * 0.8 + ripple * 0.2 * intensity);
			vec3 foam = mix(DeepColor.rgb, FoamColor.rgb, clamp(ripple * 0.5 + 0.5, 0.0, 1.0));
			vec3 col = mix(layer, foam, 0.25 * intensity);

			float vignette = 1.0 - smoothstep(0.35, 0.9, distance(uv, vec2(0.5)));
			col = mix(col, BaseColor.rgb, (1.0 - vignette) * 0.6);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local deep = GetColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.ArenaBorder)
		local foam = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "DeepColor", deep)
		SendColor(shader, "FoamColor", foam)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Ember drift for warm and ashen floors
RegisterEffect({
	type = "EmberDrift",
	BackdropIntensity = 0.7,
	ArenaIntensity = 0.42,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 EmberColor;
		extern vec4 GlowColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float rise = smoothstep(0.05, 0.95, uv.y);
			float drift = time * 0.08;
			float scroll = uv.y + drift;
			float ribbons = sin((uv.x * 3.5 + scroll * 3.0) - time * 0.45);
			float shimmer = sin((uv.x * 6.0 - uv.y * 1.5) + time * 0.6);
			float sway = sin(time * 0.1) * 0.12;
			float GlowBand = smoothstep(0.1 + sway, 0.85 + sway, uv.y);

			float ember = rise * 0.55 + ribbons * 0.18 + shimmer * 0.12;
			ember = clamp(ember * (0.55 + intensity * 0.45), 0.0, 1.0);

			vec3 BaseWarm = mix(BaseColor.rgb, EmberColor.rgb, rise * 0.35);
			vec3 EmberGlow = mix(EmberColor.rgb, GlowColor.rgb, clamp(ember * 0.6 + GlowBand * 0.25, 0.0, 1.0));
			vec3 col = mix(BaseWarm, EmberGlow, clamp(ember * 0.65 + GlowBand * 0.25, 0.0, 1.0));

			float haze = smoothstep(0.2, 0.95, GlowBand);
			col = mix(col, GlowColor.rgb, haze * 0.12);

			float vignette = smoothstep(0.25, 0.8, distance(uv, vec2(0.5)));
			col = mix(col, BaseColor.rgb, vignette * 0.4);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local ember = GetColorComponents(palette and (palette.rock or palette.arenaBorder), Theme.rock)
		local glow = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "EmberColor", ember)
		SendColor(shader, "GlowColor", glow)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Dust motes and faint machinery glow for ancient ruins
RegisterEffect({
	type = "RuinMotes",
	BackdropIntensity = 0.6,
	ArenaIntensity = 0.34,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 DustColor;
		extern vec4 HighlightColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float vertical = smoothstep(0.0, 1.0, uv.y);

			float sweep = sin((uv.y + time * 0.08) * 6.0);
			float drift = sin((uv.x * 3.0 + uv.y * 0.5) + time * 0.35);
			float motes = smoothstep(0.35, 0.85, sweep * 0.4 + drift * 0.2 + 0.5);

			float cross = sin((uv.x * 11.0 - time * 0.4)) * sin((uv.y * 9.0 + time * 0.28));
			float sparkle = smoothstep(0.6, 0.94, cross * 0.5 + 0.5);

			float DustAmount = clamp((motes * 0.6 + sparkle * 0.4) * intensity, 0.0, 1.0);

			vec3 col = mix(BaseColor.rgb, DustColor.rgb, vertical * 0.3 + DustAmount * 0.25);
			col = mix(col, HighlightColor.rgb, DustAmount * 0.2);

			float vignette = smoothstep(0.4, 0.95, distance(uv, vec2(0.5)));
			col = mix(col, BaseColor.rgb, vignette * 0.55);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local dust = GetColorComponents(palette and (palette.rock or palette.arenaBorder), Theme.rock)
		local highlight = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "DustColor", dust)
		SendColor(shader, "HighlightColor", highlight)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Aurora veil for crystalline and celestial floors
RegisterEffect({
	type = "AuroraVeil",
	BackdropIntensity = 0.65,
	ArenaIntensity = 0.4,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AuroraPrimary;
		extern vec4 AuroraSecondary;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float wave = sin((uv.x * 4.0 + time * 0.12) + sin(uv.y * 3.0) * 0.5);
			float wave2 = sin((uv.x * 6.0 - uv.y * 2.0) - time * 0.08);
			float band = clamp((wave * 0.35 + wave2 * 0.25) * intensity + 0.5, 0.0, 1.0);
			float vertical = smoothstep(0.0, 1.0, uv.y);

			vec3 col = mix(BaseColor.rgb, AuroraPrimary.rgb, band * 0.7);
			col = mix(col, AuroraSecondary.rgb, band * 0.5 * (0.4 + vertical * 0.6));
			float glow = smoothstep(0.1, 0.9, band) * 0.3;
			col += AuroraSecondary.rgb * glow * 0.2;
			col = mix(BaseColor.rgb, col, 0.6 + 0.3 * band);
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local primary = GetColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.ArenaBorder)
		local secondary = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AuroraPrimary", primary)
		SendColor(shader, "AuroraSecondary", secondary)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Void pulse for deep abyssal floors
RegisterEffect({
	type = "VoidPulse",
	BackdropIntensity = 0.75,
	ArenaIntensity = 0.48,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 RimColor;
		extern vec4 PulseColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float dist = distance(uv, vec2(0.5));
			float pulse = sin(dist * 6.0 - time * 0.7) * 0.5 + 0.5;
			float slow = sin(time * 0.25) * 0.5 + 0.5;
			float rim = smoothstep(0.25, 0.85, dist);

			vec3 col = mix(BaseColor.rgb, PulseColor.rgb, pulse * intensity * (1.0 - rim));
			col = mix(col, RimColor.rgb, (1.0 - rim) * 0.35 + slow * 0.15 * intensity);

			float vignette = smoothstep(0.4, 0.95, dist);
			col = mix(col, BaseColor.rgb, clamp(vignette, 0.0, 1.0));

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and palette.bgColor, Theme.BgColor)
		local rim = GetColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.ArenaBorder)
		local pulse = GetColorComponents(palette and (palette.snake or palette.sawColor), Theme.SnakeDefault)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "RimColor", rim)
		SendColor(shader, "PulseColor", pulse)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Neon hazard backdrop for the main menu
RegisterEffect({
	type = "MenuConstellation",
	BackdropIntensity = 0.46,
	ArenaIntensity = 0.32,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 TopColor;
		extern vec4 BottomColor;
		extern vec4 AccentColor;
		extern float VignetteIntensity;
		extern float AccentStrength;
		extern float TextureStrength;
		extern float BandCenter;
		extern float BandWidth;
		extern float intensity;

		float hash(vec2 p)
		{
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
		}

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float gradient = smoothstep(0.0, 1.0, uv.y);
			vec3 col = mix(TopColor.rgb, BottomColor.rgb, gradient);

			float BandOffset = (uv.y - BandCenter) / max(BandWidth, 0.001);
			float BandGlow = exp(-BandOffset * BandOffset);
			float ripple = sin(time * 0.6 + uv.x * 6.0) * 0.5 + 0.5;
			float glow = clamp(BandGlow * (0.35 + ripple * 0.25) * AccentStrength * intensity, 0.0, 1.0);
			col = mix(col, AccentColor.rgb, glow);

			vec2 centered = uv - vec2(0.5);
			float vignette = smoothstep(0.45, 0.92, length(centered));
			float VignetteMix = clamp(vignette * VignetteIntensity, 0.0, 1.0);
			col = mix(col, col * 0.78, VignetteMix);

			float noise = hash(uv * resolution.xy + time * 15.0);
			float grain = noise * 2.0 - 1.0;
			float scan = sin((uv.y * resolution.y + time * 12.0) * 3.14159);
			scan = clamp(scan * 0.5, -1.0, 1.0);
			float grit = clamp(grain * 0.6 + scan * 0.4, -1.0, 1.0);
			col += col * grit * TextureStrength;

			col = clamp(col, 0.0, 1.0);

			float alpha = mix(TopColor.a, BottomColor.a, gradient);
			return vec4(col, alpha) * color;
		}
	]],
	configure = function(effect)
		local shader = effect.shader

		local top = {0x1A / 255, 0x0F / 255, 0x1E / 255, 1}
		local bottom = {0x05 / 255, 0x05 / 255, 0x05 / 255, 1}
		local accent = {0xFF / 255, 0x2D / 255, 0xAA / 255, 1}

		SendColor(shader, "TopColor", top)
		SendColor(shader, "BottomColor", bottom)
		SendColor(shader, "AccentColor", accent)
		SendFloat(shader, "VignetteIntensity", 0.66)
		SendFloat(shader, "AccentStrength", 0.64)
		SendFloat(shader, "TextureStrength", 0.085)
		SendFloat(shader, "BandCenter", 0.55)
		SendFloat(shader, "BandWidth", 0.42)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Radiant fabric of light for the shop screen
RegisterEffect({
	type = "ShopGlimmer",
	BackdropIntensity = 0.54,
	ArenaIntensity = 0.32,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 GlowColor;
		extern float intensity;

		float hash(vec2 p)
		{
			return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
		}

		float noise(vec2 p)
		{
			vec2 i = floor(p);
			vec2 f = fract(p);
			f = f * f * (3.0 - 2.0 * f);

			float a = hash(i);
			float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0));
			float d = hash(i + vec2(1.0, 1.0));

			return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
		}

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);
			vec2 centered = uv - vec2(0.5);

			float radius = length(centered);

			float RibbonFlow = sin((uv.x * 3.2 + uv.y * 2.6) - time * 0.45);
			float swirl = sin(atan(centered.y, centered.x) * 4.0 - time * 0.28 + radius * 3.5);
			float drift = noise(uv * 3.5 + time * 0.1);

			float RibbonLayer = clamp(RibbonFlow * 0.45 + swirl * 0.3 + drift * 0.6, -1.0, 1.0) * 0.5 + 0.5;
			float halo = exp(-radius * radius * 4.0);
			float VerticalGlow = smoothstep(0.15, 0.95, uv.y + sin(time * 0.16 + uv.x * 1.4) * 0.05);

			float AccentMix = clamp((RibbonLayer * 0.6 + halo * 0.25 + VerticalGlow * 0.2) * intensity, 0.0, 1.0);
			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, AccentMix);

			float SparkleField = noise(uv * 12.0 + time * 0.6);
			float sparkle = smoothstep(0.72, 1.0, SparkleField) * (0.35 + 0.25 * intensity);

			float GlowPulse = sin(time * 0.22) * 0.5 + 0.5;
			float GlowAmount = clamp((halo * (0.55 + GlowPulse * 0.35) + VerticalGlow * 0.3 + sparkle * 0.5) * intensity, 0.0, 1.0);
			col = mix(col, GlowColor.rgb, GlowAmount);

			float weave = noise(uv * vec2(22.0, 18.0) + vec2(0.0, time * 0.35));
			col = mix(col, BaseColor.rgb, (0.18 + 0.1 * (1.0 - RibbonLayer)) * (1.0 - weave));

			col = mix(BaseColor.rgb, col, 0.82);
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.edgeColor), Theme.BorderColor)
		local glow = GetColorComponents(palette and (palette.glowColor or palette.highlightColor), Theme.AccentTextColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "GlowColor", glow)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Simple gradient wash for mode selection
RegisterEffect({
	type = "ModeGradient",
	BackdropIntensity = 0.46,
	ArenaIntensity = 0.28,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float vertical = smoothstep(0.0, 1.0, uv.y);
			float wave = sin((uv.x + time * 0.18) * 2.6) * 0.5 + 0.5;
			float MixAmount = clamp(vertical * 0.55 + wave * 0.25, 0.0, 1.0) * intensity;

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, MixAmount);
			col = mix(BaseColor.rgb, col, 0.82);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.ProgressColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Directional ribbons for mode selection energy
RegisterEffect({
	type = "ModeRibbon",
	BackdropIntensity = 0.52,
	ArenaIntensity = 0.34,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 EdgeColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float diag = sin((uv.x - uv.y) * 6.0 + time * 0.4);
			float sweep = sin(uv.y * 9.0 + time * 0.7);
			float stripes = abs(sin((uv.x + uv.y * 0.5) * 12.0 - time * 0.3));
			float ribbon = clamp(diag * 0.5 + 0.5, 0.0, 1.0);
			float StripeGlow = smoothstep(0.55, 0.95, 1.0 - stripes);

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, (0.25 + ribbon * 0.45 + sweep * 0.15) * intensity);
			col = mix(col, EdgeColor.rgb, StripeGlow * 0.28 * intensity);
			col = mix(BaseColor.rgb, col, 0.82);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.BorderColor)
		local edge = GetColorComponents(palette and (palette.edgeColor or palette.secondary), Theme.ProgressColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "EdgeColor", edge)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Prismatic beams for achievements showcase
RegisterEffect({
	type = "AchievementRadiance",
	BackdropIntensity = 0.48,
	ArenaIntensity = 0.3,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 FlareColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float GentleRise = smoothstep(0.0, 1.0, uv.y);
			float shimmer = sin(time * 0.1 + uv.x * 2.0) * 0.5 + 0.5;
			float CenterGlow = exp(-pow((uv.x - 0.5) * 2.2, 2.0));

			float AccentMix = clamp(0.2 + GentleRise * 0.35 + shimmer * 0.1, 0.0, 1.0) * intensity;
			float FlareMix = clamp(CenterGlow * 0.6 + GentleRise * 0.15, 0.0, 1.0) * 0.55 * intensity;

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, AccentMix);
			col = mix(col, FlareColor.rgb, FlareMix);

			float CalmWave = sin(time * 0.07) * 0.5 + 0.5;
			col = mix(col, BaseColor.rgb, 0.1 * (1.0 - CalmWave));

			col = mix(BaseColor.rgb, col, 0.88);
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.AchieveColor)
		local flare = GetColorComponents(palette and (palette.flareColor or palette.secondary), Theme.AccentTextColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "FlareColor", flare)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Flowing orbitals for metaprogression overview
RegisterEffect({
	type = "MetaFlux",
	BackdropIntensity = 0.6,
	ArenaIntensity = 0.38,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 PrimaryColor;
		extern vec4 SecondaryColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);
			vec2 centered = uv - vec2(0.5);

			float radius = length(centered);
			float angle = atan(centered.y, centered.x);

			float wave = sin(angle * 4.0 + time * 0.25);
			float pulse = sin(radius * 9.0 - time * 0.35);
			float halo = smoothstep(0.0, 0.8, 1.0 - radius);

			float PrimaryMix = clamp(0.28 + wave * 0.18 + halo * 0.3, 0.0, 1.0);
			float SecondaryMix = clamp(pulse * 0.5 + 0.5, 0.0, 1.0) * 0.35;

			vec3 col = mix(BaseColor.rgb, PrimaryColor.rgb, PrimaryMix * intensity);
			col = mix(col, SecondaryColor.rgb, SecondaryMix * intensity);
			col = mix(BaseColor.rgb, col, 0.85);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local primary = GetColorComponents(palette and (palette.primaryColor or palette.accentColor), Theme.ProgressColor)
		local secondary = GetColorComponents(palette and (palette.secondaryColor or palette.highlightColor), Theme.AccentTextColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "PrimaryColor", primary)
		SendColor(shader, "SecondaryColor", secondary)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Blueprint grid for settings clarity
RegisterEffect({
	type = "SettingsBlueprint",
	BackdropIntensity = 0.44,
	ArenaIntensity = 0.28,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 HighlightColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);

			float vertical = smoothstep(0.0, 1.0, uv.y);
			float horizontal = smoothstep(1.0, 0.0, uv.y);
			float SlowWave = sin(time * 0.08 + uv.x * 1.5) * 0.5 + 0.5;

			float AccentMix = clamp(0.16 + vertical * 0.3 + SlowWave * 0.12, 0.0, 1.0) * intensity;
			float HighlightMix = clamp(0.1 + horizontal * 0.25, 0.0, 1.0) * 0.5 * intensity;

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, AccentMix);
			col = mix(col, HighlightColor.rgb, HighlightMix);

			float SoftVignette = smoothstep(0.9, 0.3, length(uv - vec2(0.5)));
			col = mix(col, BaseColor.rgb, 0.18 * SoftVignette);

			col = mix(BaseColor.rgb, col, 0.82);
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.BorderColor)
		local highlight = GetColorComponents(palette and (palette.highlightColor or palette.secondary), Theme.ProgressColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "HighlightColor", highlight)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
-- Gentle afterglow for game over reflection
RegisterEffect({
	type = "AfterglowPulse",
	BackdropIntensity = 0.52,
	ArenaIntensity = 0.3,
	source = [[
		extern float time;
		extern vec2 resolution;
		extern vec2 origin;
		extern vec4 BaseColor;
		extern vec4 AccentColor;
		extern vec4 PulseColor;
		extern float intensity;

		vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
		{
			vec2 uv = (screen_coords - origin) / resolution;
			uv = clamp(uv, 0.0, 1.0);
			vec2 centered = uv - vec2(0.5);

			float dist = length(centered);
			float fade = smoothstep(0.95, 0.15, dist);

			float breathe = sin(time * 0.25) * 0.5 + 0.5;

			vec3 col = mix(BaseColor.rgb, AccentColor.rgb, fade * 0.35 * intensity);

			float glow = exp(-dist * dist * 2.4);
			float OuterGlow = smoothstep(0.5, 0.1, dist);
			float GlowAmount = (glow * 0.55 + OuterGlow * 0.25) * (0.45 + breathe * 0.35) * intensity;
			col = mix(col, PulseColor.rgb, clamp(GlowAmount, 0.0, 1.0));

			float GentleSweep = smoothstep(-0.2, 0.7, dot(centered, normalize(vec2(0.4, 1.0))) + sin(time * 0.3) * 0.1);
			col = mix(col, AccentColor.rgb, GentleSweep * 0.25 * intensity);

			float grain = sin((uv.x * 10.0 + uv.y * 8.0) + time * 0.15) * 0.5 + 0.5;
			col = mix(col, BaseColor.rgb, 0.18 * (1.0 - grain));

			col = mix(BaseColor.rgb, col, clamp(fade, 0.0, 1.0));
			col = clamp(col, 0.0, 1.0);

			return vec4(col, BaseColor.a) * color;
		}
	]],
	configure = function(effect, palette)
		local shader = effect.shader

		local base = GetColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.BgColor)
		local accent = GetColorComponents(palette and (palette.accentColor or palette.primary), Theme.WarningColor)
		local pulse = GetColorComponents(palette and (palette.pulseColor or palette.secondary), Theme.ProgressColor)

		SendColor(shader, "BaseColor", base)
		SendColor(shader, "AccentColor", accent)
		SendColor(shader, "PulseColor", pulse)
	end,
	draw = function(effect, x, y, w, h, intensity)
		return DrawShader(effect, x, y, w, h, intensity)
	end,
})
local function CreateEffect(def)
	local shader = love.graphics.newShader(def.source)

	local DefaultBackdrop = def.backdropIntensity or 1.0
	local DefaultArena = def.arenaIntensity or 0.6

	local effect = {
		type = def.type,
		shader = shader,
		BackdropIntensity = DefaultBackdrop,
		ArenaIntensity = DefaultArena,
		DefaultBackdropIntensity = DefaultBackdrop,
		DefaultArenaIntensity = DefaultArena,
		definition = def,
	}

	return effect
end

function Shaders.ensure(cache, TypeName)
	if not TypeName then
		return nil
	end

	cache = cache or {}

	local effect = cache[TypeName]
	if effect and effect.shader then
		return effect
	end

	local def = EffectDefinitions[TypeName]
	if not def then
		return nil
	end

	local ok, NewEffect = pcall(CreateEffect, def)
	if not ok then
		return nil
	end

	cache[TypeName] = NewEffect
	return NewEffect
end

function Shaders.configure(effect, palette, EffectData)
	if not effect then
		return false
	end

	local def = effect.definition
	if not def then
		return false
	end

	if def.configure then
		def.configure(effect, palette, EffectData)
		return true
	end

	return false
end

function Shaders.draw(effect, x, y, w, h, intensity)
	if not effect then
		return false
	end

	local def = effect.definition
	if not def or not def.draw then
		return false
	end

	return def.draw(effect, x, y, w, h, intensity)
end

function Shaders.GetDefaultIntensities(effect)
	if not effect then
		return 1.0, 0.6
	end

	local backdrop = effect.defaultBackdropIntensity or effect.backdropIntensity or 1.0
	local arena = effect.defaultArenaIntensity or effect.arenaIntensity or 0.6

	return backdrop, arena
end

function Shaders.has(TypeName)
	return EffectDefinitions[TypeName] ~= nil
end

return Shaders
