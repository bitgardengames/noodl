local Face = require("face")
local SnakeCosmetics = require("snakecosmetics")
local ModuleUtil = require("moduleutil")

local SnakeDraw = ModuleUtil.create("SnakeDraw")

local unpack = unpack

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 3
local FRUIT_BULGE_SCALE = 1.25

-- Canvas for single-pass shadow
local SnakeCanvas = nil
local SnakeOverlayCanvas = nil

local ApplyOverlay

local OverlayShaderSources = {
	stripes = [[
	extern float time;
	extern float frequency;
	extern float speed;
	extern float angle;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float c = cos(angle);
	  float s = sin(angle);
	  float stripe = sin((uv.x * c + uv.y * s) * frequency + time * speed) * 0.5 + 0.5;
	  vec3 StripeColor = mix(ColorA.rgb, ColorB.rgb, stripe);
	  float blend = clamp(intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, StripeColor, blend);
	  return vec4(result, base.a) * color;
	}
	]],
	holo = [[
	extern float time;
	extern float speed;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float wave = sin((uv.x + uv.y) * 10.0 + time * speed);
	  float radial = sin(length(uv * vec2(1.4, 1.0)) * 12.0 - time * (speed * 0.6 + 0.2));
	  float shimmer = sin((uv.x - uv.y) * 16.0 + time * speed * 1.8);

	  float BaseMix = clamp(0.5 + 0.5 * wave, 0.0, 1.0);
	  vec3 layer = mix(ColorA.rgb, ColorB.rgb, BaseMix);
	  layer = mix(layer, ColorC.rgb, clamp(radial * 0.5 + 0.5, 0.0, 1.0) * 0.6);
	  layer += shimmer * 0.12 * ColorC.rgb;

	  float blend = clamp(intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, layer, blend);
	  return vec4(result, base.a) * color;
	}
	]],
	AuroraVeil = [[
	extern float time;
	extern float CurtainDensity;
	extern float DriftSpeed;
	extern float parallax;
	extern float ShimmerStrength;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float curtain = sin(uv.x * CurtainDensity + time * DriftSpeed);
	  float CurtainB = sin((uv.x * 0.6 - uv.y * 0.8) * (CurtainDensity * 0.7) - time * DriftSpeed * 0.6);
	  float blend = (curtain + CurtainB) * 0.5;
	  float vertical = clamp(smoothstep(-0.65, 0.65, uv.y + blend * 0.25), 0.0, 1.0);
	  float shimmer = sin((uv.y * 5.0 + uv.x * 3.0) - time * parallax) * 0.5 + 0.5;

	  vec3 aurora = mix(ColorA.rgb, ColorB.rgb, vertical);
	  aurora = mix(aurora, ColorC.rgb, shimmer * ShimmerStrength);

	  float glow = clamp((vertical * 0.6 + shimmer * 0.4) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, aurora, glow);
	  result += aurora * glow * 0.25;
	  return vec4(result, base.a) * color;
	}
	]],
	IonStorm = [[
	extern float time;
	extern float BoltFrequency;
	extern float FlashFrequency;
	extern float haze;
	extern float turbulence;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float angle = atan(uv.y, uv.x);
	  float radius = length(uv);
	  float bolts = sin(angle * BoltFrequency + sin(time * turbulence + radius * 8.0) * 2.2);
	  float arcs = sin(radius * (BoltFrequency * 2.5) - time * FlashFrequency);
	  float flicker = sin(time * FlashFrequency * 1.8 + radius * 12.0) * 0.5 + 0.5;
	  float strike = pow(clamp((bolts * 0.5 + 0.5) * (arcs * 0.5 + 0.5), 0.0, 1.0), 1.5);
	  float halo = smoothstep(0.0, 0.65, 1.0 - radius) * haze;

	  vec3 energy = mix(ColorA.rgb, ColorB.rgb, clamp(strike + flicker * 0.4, 0.0, 1.0));
	  energy = mix(energy, ColorC.rgb, clamp(flicker, 0.0, 1.0));

	  float glow = clamp((strike * 0.8 + halo * 0.6) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, energy, glow);
	  result += ColorC.rgb * glow * 0.2;
	  return vec4(result, base.a) * color;
	}
	]],
	PetalBloom = [[
	extern float time;
	extern float PetalCount;
	extern float PulseSpeed;
	extern float TrailStrength;
	extern float BloomStrength;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float angle = atan(uv.y, uv.x);
	  float petals = sin(angle * PetalCount + sin(time * PulseSpeed) * 0.8);
	  float rings = sin(radius * (PetalCount * 1.4) - time * PulseSpeed * 0.7);
	  float pulse = sin(time * PulseSpeed + radius * 6.0) * 0.5 + 0.5;
	  float bloom = pow(clamp(petals * 0.5 + 0.5, 0.0, 1.0), 1.2);
	  float trails = smoothstep(0.0, 1.0, 1.0 - radius) * TrailStrength;

	  vec3 PetalColor = mix(ColorA.rgb, ColorB.rgb, bloom);
	  PetalColor = mix(PetalColor, ColorC.rgb, clamp(pulse, 0.0, 1.0));

	  float glow = clamp((bloom * BloomStrength + trails * 0.4 + pulse * 0.5) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, PetalColor, glow);
	  result += PetalColor * glow * 0.15;
	  return vec4(result, base.a) * color;
	}
	]],
	AbyssalPulse = [[
	extern float time;
	extern float SwirlDensity;
	extern float GlimmerFrequency;
	extern float darkness;
	extern float DriftSpeed;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float angle = atan(uv.y, uv.x);
	  float swirl = sin(angle * SwirlDensity - time * DriftSpeed + radius * 4.0);
	  float waves = sin(radius * (SwirlDensity * 0.5) + time * DriftSpeed * 0.6);
	  float glimmer = sin(angle * GlimmerFrequency + time * GlimmerFrequency * 0.7);
	  float depth = smoothstep(0.0, 0.9, radius);

	  vec3 abyss = mix(ColorA.rgb, ColorB.rgb, clamp(swirl * 0.5 + 0.5, 0.0, 1.0));
	  abyss = mix(abyss, ColorC.rgb, clamp(glimmer * 0.5 + 0.5, 0.0, 1.0) * 0.6);

	  float glow = clamp((1.0 - depth) * 0.6 + waves * 0.2 + glimmer * 0.2, 0.0, 1.0) * intensity;
	  glow = mix(glow, glow * (1.0 - depth), clamp(darkness, 0.0, 1.0));

	  vec3 result = mix(base.rgb, abyss, glow);
	  result += ColorC.rgb * glow * 0.12;
	  return vec4(result, base.a) * color;
	}
	]],
	ChronoWeave = [[
	extern float time;
	extern float RingDensity;
	extern float TimeFlow;
	extern float WeaveStrength;
	extern float PhaseOffset;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float angle = atan(uv.y, uv.x);
	  float rings = sin(radius * RingDensity - time * TimeFlow);
	  float spokes = sin(angle * (RingDensity * 0.5) + time * WeaveStrength);
	  float warp = sin((radius * 8.0 + angle * 6.0) + time * (TimeFlow * 0.5 + WeaveStrength)) * 0.5 + 0.5;
	  float chrono = clamp(rings * 0.5 + 0.5, 0.0, 1.0);

	  vec3 core = mix(ColorA.rgb, ColorB.rgb, chrono);
	  core = mix(core, ColorC.rgb, warp);

	  float glow = clamp((chrono * 0.5 + (spokes * 0.5 + 0.5) * WeaveStrength + warp * 0.35) * intensity, 0.0, 1.0);
	  float fade = smoothstep(0.85, 1.1, radius + PhaseOffset);
	  glow *= (1.0 - fade);

	  vec3 result = mix(base.rgb, core, glow);
	  result += ColorC.rgb * glow * 0.1;
	  return vec4(result, base.a) * color;
	}
	]],
	GildedFacet = [[
	extern float time;
	extern float FacetDensity;
	extern float SparkleDensity;
	extern float BeamSpeed;
	extern float ReflectionStrength;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float facets = sin(uv.x * FacetDensity + sin(uv.y * FacetDensity * 1.3 + time * BeamSpeed) * 1.5);
	  float prismatic = sin((uv.x + uv.y) * (FacetDensity * 0.7) - time * BeamSpeed * 0.8);
	  float sparkle = sin(time * SparkleDensity + atan(uv.y, uv.x) * 12.0 + radius * 16.0) * 0.5 + 0.5;
	  float highlight = clamp(facets * 0.5 + 0.5, 0.0, 1.0);

	  vec3 metal = mix(ColorA.rgb, ColorB.rgb, highlight);
	  metal = mix(metal, ColorC.rgb, pow(clamp(sparkle, 0.0, 1.0), 2.0) * ReflectionStrength);

	  float glow = clamp((highlight * 0.5 + prismatic * 0.35 + sparkle * 0.6) * intensity, 0.0, 1.0);
	  glow *= (1.0 - smoothstep(0.0, 1.1, radius));

	  vec3 result = mix(base.rgb, metal, glow);
	  result += ColorC.rgb * glow * 0.18;
	  return vec4(result, base.a) * color;
	}
	]],
	VoidEcho = [[
	extern float time;
	extern float VeilFrequency;
	extern float EchoSpeed;
	extern float PhaseShift;
	extern float RiftIntensity;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float angle = atan(uv.y, uv.x);
	  float field = sin((uv.x + uv.y) * VeilFrequency + time * EchoSpeed);
	  float lens = sin(radius * (VeilFrequency * 1.6) - time * EchoSpeed * 0.6 + PhaseShift);
	  float echoes = sin(angle * (VeilFrequency * 0.8) - time * EchoSpeed * 1.3);
	  float drift = sin((uv.x - uv.y) * (VeilFrequency * 0.5) + time * EchoSpeed * 0.4);

	  float veil = clamp(field * 0.4 + lens * 0.4 + echoes * 0.2, -1.0, 1.0) * 0.5 + 0.5;
	  float rift = smoothstep(0.2, 0.95, radius) * RiftIntensity;

	  vec3 wisp = mix(ColorA.rgb, ColorB.rgb, veil);
	  wisp = mix(wisp, ColorC.rgb, clamp(drift * 0.5 + 0.5, 0.0, 1.0));

	  float glow = clamp((veil * 0.6 + (1.0 - rift) * 0.4 + drift * 0.2) * intensity, 0.0, 1.0);
	  glow *= (1.0 - smoothstep(0.0, 1.05, radius + drift * 0.08));

	  vec3 result = mix(base.rgb, wisp, glow);
	  result += ColorC.rgb * glow * 0.16;
	  return vec4(result, base.a) * color;
	}
	]],
	ConstellationDrift = [[
	extern float time;
	extern float StarDensity;
	extern float DriftSpeed;
	extern float parallax;
	extern float TwinkleStrength;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	float hash(vec2 p)
	{
	  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
	}

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  vec2 StarUV = uv * StarDensity;
	  vec2 id = floor(StarUV);
	  vec2 frac = fract(StarUV);

	  float twinkle = 0.0;
	  for (int x = -1; x <= 1; ++x) {
		for (int y = -1; y <= 1; ++y) {
		  vec2 offset = vec2(x, y);
		  vec2 cell = id + offset;
		  float StarSeed = hash(cell);
		  vec2 StarPos = fract(sin(vec2(StarSeed, StarSeed * 1.7)) * 43758.5453);
		  vec2 delta = offset + StarPos - frac;
		  float dist = length(delta);
		  float sparkle = clamp(1.0 - dist * 2.4, 0.0, 1.0);
		  float pulse = sin(time * DriftSpeed + StarSeed * 6.283 + parallax * dot(delta, vec2(0.6, -0.4)));
		  twinkle += sparkle * (0.5 + 0.5 * pulse);
		}
	  }

	  twinkle = clamp(twinkle * TwinkleStrength, 0.0, 1.2);
	  float band = sin((uv.x + uv.y) * 6.0 + time * DriftSpeed * 0.4) * 0.5 + 0.5;

	  vec3 StarColor = mix(ColorA.rgb, ColorB.rgb, band);
	  StarColor = mix(StarColor, ColorC.rgb, clamp(twinkle, 0.0, 1.0));

	  float glow = clamp((band * 0.4 + twinkle) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, StarColor, glow);
	  result += ColorC.rgb * glow * 0.12;
	  return vec4(result, base.a) * color;
	}
	]],
	CrystalBloom = [[
	extern float time;
	extern float ShardDensity;
	extern float SweepSpeed;
	extern float RefractionStrength;
	extern float VeinStrength;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  vec2 shard = uv * ShardDensity;
	  float ridge = sin(shard.x + sin(shard.y * 1.7 + time * SweepSpeed) * 1.2);
	  float RidgeB = sin(shard.y * 1.4 - time * SweepSpeed * 0.6);
	  float veins = sin((uv.x - uv.y) * 12.0 + time * SweepSpeed * 1.3);

	  float crystalline = clamp(ridge * 0.5 + RidgeB * 0.5, -1.0, 1.0) * 0.5 + 0.5;
	  float caustic = clamp(veins * 0.5 + 0.5, 0.0, 1.0);

	  vec3 mineral = mix(ColorA.rgb, ColorB.rgb, crystalline);
	  mineral = mix(mineral, ColorC.rgb, caustic * RefractionStrength);

	  float glow = clamp((crystalline * 0.45 + caustic * VeinStrength) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, mineral, glow);
	  result += ColorC.rgb * glow * 0.14;
	  return vec4(result, base.a) * color;
	}
	]],
	EmberForge = [[
	extern float time;
	extern float EmberFrequency;
	extern float EmberSpeed;
	extern float EmberGlow;
	extern float SlagDarkness;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float EmberFlow = sin((uv.x * 1.4 + uv.y * 0.6) * EmberFrequency + time * EmberSpeed);
	  float EmberPulse = sin((uv.x - uv.y) * (EmberFrequency * 0.5) + time * EmberSpeed * 1.6);
	  float sparks = sin(time * EmberSpeed * 2.3 + radius * 18.0) * 0.5 + 0.5;

	  float forge = clamp(EmberFlow * 0.5 + EmberPulse * 0.5, -1.0, 1.0) * 0.5 + 0.5;
	  float slag = smoothstep(0.2, 0.95, radius) * SlagDarkness;

	  vec3 molten = mix(ColorA.rgb, ColorB.rgb, forge);
	  molten = mix(molten, ColorC.rgb, clamp(sparks, 0.0, 1.0) * EmberGlow);

	  float glow = clamp((forge * 0.7 + sparks * 0.4) * intensity, 0.0, 1.0);
	  glow *= (1.0 - slag);

	  vec3 result = mix(base.rgb, molten, glow);
	  result += ColorC.rgb * glow * 0.2;
	  return vec4(result, base.a) * color;
	}
	]],
	MechanicalScan = [[
	extern float time;
	extern float ScanSpeed;
	extern float GearFrequency;
	extern float GearParallax;
	extern float ServoIntensity;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float radius = length(uv);
	  float scan = sin((uv.y + uv.x * 0.3) * GearFrequency - time * ScanSpeed) * 0.5 + 0.5;
	  float gears = sin(atan(uv.y, uv.x) * GearFrequency * 0.7 + time * GearParallax);
	  float ticks = sin(radius * (GearFrequency * 1.8) - time * ScanSpeed * 1.5);

	  vec3 steel = mix(ColorA.rgb, ColorB.rgb, scan);
	  steel = mix(steel, ColorC.rgb, clamp(gears * 0.5 + 0.5, 0.0, 1.0) * ServoIntensity);

	  float glow = clamp((scan * 0.45 + ticks * 0.3 + (gears * 0.5 + 0.5) * 0.25) * intensity, 0.0, 1.0);
	  glow *= (1.0 - smoothstep(0.0, 1.05, radius + 0.02));

	  vec3 result = mix(base.rgb, steel, glow);
	  result += ColorC.rgb * glow * 0.12;
	  return vec4(result, base.a) * color;
	}
	]],
	TidalChorus = [[
	extern float time;
	extern float WaveFrequency;
	extern float CrestSpeed;
	extern float ChorusStrength;
	extern float DepthShift;
	extern float intensity;
	extern vec4 ColorA;
	extern vec4 ColorB;
	extern vec4 ColorC;

	vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
	{
	  vec4 base = Texel(tex, texture_coords);
	  float mask = base.a;
	  if (mask <= 0.0) {
		return base * color;
	  }

	  vec2 uv = texture_coords - vec2(0.5);
	  float wave = sin((uv.x * WaveFrequency - uv.y * 1.2) + time * CrestSpeed);
	  float counter = sin((uv.x * 0.8 + uv.y * WaveFrequency * 0.7) - time * CrestSpeed * 0.7);
	  float harmonics = sin((uv.x + uv.y) * 5.0 + time * CrestSpeed * 1.3);
	  float depth = smoothstep(-0.4 + DepthShift, 0.6 + DepthShift, uv.y + wave * 0.1);

	  vec3 tide = mix(ColorA.rgb, ColorB.rgb, clamp(depth, 0.0, 1.0));
	  tide = mix(tide, ColorC.rgb, clamp(harmonics * 0.5 + 0.5, 0.0, 1.0) * ChorusStrength);

	  float glow = clamp((depth * 0.5 + (wave * 0.5 + 0.5) * 0.3 + (counter * 0.5 + 0.5) * 0.3) * intensity, 0.0, 1.0);
	  vec3 result = mix(base.rgb, tide, glow);
	  result += ColorC.rgb * glow * 0.16;
	  return vec4(result, base.a) * color;
	}
	]],
}

local OverlayShaderCache = {}

local function SafeResolveShader(TypeId)
	if OverlayShaderCache[TypeId] ~= nil then
	return OverlayShaderCache[TypeId]
	end

	local source = OverlayShaderSources[TypeId]
	if not source then
	OverlayShaderCache[TypeId] = false
	return nil
	end

	local ok, shader = pcall(love.graphics.newShader, source)
	if not ok then
	print("[snakedraw] failed to build overlay shader", TypeId, shader)
	OverlayShaderCache[TypeId] = false
	return nil
	end

	OverlayShaderCache[TypeId] = shader
	return shader
end

local function EnsureSnakeCanvas(width, height)
	if not SnakeCanvas or SnakeCanvas:getWidth() ~= width or SnakeCanvas:getHeight() ~= height then
	SnakeCanvas = love.graphics.newCanvas(width, height, {msaa = 8})
	end
	return SnakeCanvas
end

local function EnsureSnakeOverlayCanvas(width, height)
	if not SnakeOverlayCanvas or SnakeOverlayCanvas:getWidth() ~= width or SnakeOverlayCanvas:getHeight() ~= height then
	SnakeOverlayCanvas = love.graphics.newCanvas(width, height)
	end
	return SnakeOverlayCanvas
end

local function PresentSnakeCanvas(OverlayEffect, width, height)
	if not SnakeCanvas then
	return false
	end

	love.graphics.setColor(0, 0, 0, 0.25)
	love.graphics.draw(SnakeCanvas, SHADOW_OFFSET, SHADOW_OFFSET)

	local DrewOverlay = false
	if OverlayEffect then
	local OverlayCanvas = EnsureSnakeOverlayCanvas(width, height)
	love.graphics.setCanvas(OverlayCanvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(SnakeCanvas, 0, 0)
	DrewOverlay = ApplyOverlay(SnakeCanvas, OverlayEffect)
	love.graphics.setCanvas()
	end

	love.graphics.setColor(1, 1, 1, 1)
	if DrewOverlay then
	love.graphics.draw(SnakeOverlayCanvas, 0, 0)
	else
	love.graphics.draw(SnakeCanvas, 0, 0)
	end

	return DrewOverlay
end

local function ResolveColor(color, fallback)
	if type(color) == "table" then
	return {
		color[1] or 0,
		color[2] or 0,
		color[3] or 0,
		color[4] or 1,
	}
	end

	if fallback then
	return ResolveColor(fallback)
	end

	return {1, 1, 1, 1}
end

ApplyOverlay = function(canvas, config)
	if not (canvas and config and config.type) then
	return false
	end

	local shader = SafeResolveShader(config.type)
	if not shader then
	return false
	end

	local time = love.timer.getTime()

	local colors = config.colors or {}
	local primary = ResolveColor(colors.primary or colors.color or SnakeCosmetics:GetBodyColor())
	local secondary = ResolveColor(colors.secondary or SnakeCosmetics:GetGlowColor())
	local tertiary = ResolveColor(colors.tertiary or secondary)

	shader:send("time", time)
	shader:send("intensity", config.intensity or 0.5)
	shader:send("ColorA", primary)
	shader:send("ColorB", secondary)

	if config.type == "stripes" then
	shader:send("frequency", config.frequency or 18)
	shader:send("speed", config.speed or 0.6)
	shader:send("angle", math.rad(config.angle or 45))
	elseif config.type == "holo" then
	shader:send("speed", config.speed or 1.0)
	shader:send("ColorC", tertiary)
	elseif config.type == "AuroraVeil" then
	shader:send("CurtainDensity", config.curtainDensity or 6.5)
	shader:send("DriftSpeed", config.driftSpeed or 0.7)
	shader:send("parallax", config.parallax or 1.4)
	shader:send("ShimmerStrength", config.shimmerStrength or 0.6)
	shader:send("ColorC", tertiary)
	elseif config.type == "IonStorm" then
	shader:send("BoltFrequency", config.boltFrequency or 8.5)
	shader:send("FlashFrequency", config.flashFrequency or 5.2)
	shader:send("haze", config.haze or 0.6)
	shader:send("turbulence", config.turbulence or 1.2)
	shader:send("ColorC", tertiary)
	elseif config.type == "PetalBloom" then
	shader:send("PetalCount", config.petalCount or 8.0)
	shader:send("PulseSpeed", config.pulseSpeed or 1.8)
	shader:send("TrailStrength", config.trailStrength or 0.45)
	shader:send("BloomStrength", config.bloomStrength or 0.65)
	shader:send("ColorC", tertiary)
	elseif config.type == "AbyssalPulse" then
	shader:send("SwirlDensity", config.swirlDensity or 7.0)
	shader:send("GlimmerFrequency", config.glimmerFrequency or 3.5)
	shader:send("darkness", config.darkness or 0.25)
	shader:send("DriftSpeed", config.driftSpeed or 0.9)
	shader:send("ColorC", tertiary)
	elseif config.type == "ChronoWeave" then
	shader:send("RingDensity", config.ringDensity or 9.0)
	shader:send("TimeFlow", config.timeFlow or 2.4)
	shader:send("WeaveStrength", config.weaveStrength or 1.0)
	shader:send("PhaseOffset", config.phaseOffset or 0.0)
	shader:send("ColorC", tertiary)
	elseif config.type == "GildedFacet" then
	shader:send("FacetDensity", config.facetDensity or 14.0)
	shader:send("SparkleDensity", config.sparkleDensity or 12.0)
	shader:send("BeamSpeed", config.beamSpeed or 1.4)
	shader:send("ReflectionStrength", config.reflectionStrength or 0.6)
	shader:send("ColorC", tertiary)
	elseif config.type == "VoidEcho" then
	shader:send("VeilFrequency", config.veilFrequency or 7.2)
	shader:send("EchoSpeed", config.echoSpeed or 1.2)
	shader:send("PhaseShift", config.phaseShift or 0.4)
	shader:send("RiftIntensity", config.riftIntensity or 0.4)
	shader:send("ColorC", tertiary)
	elseif config.type == "ConstellationDrift" then
	shader:send("StarDensity", config.starDensity or 6.5)
	shader:send("DriftSpeed", config.driftSpeed or 1.2)
	shader:send("parallax", config.parallax or 0.6)
	shader:send("TwinkleStrength", config.twinkleStrength or 0.8)
	shader:send("ColorC", tertiary)
	elseif config.type == "CrystalBloom" then
	shader:send("ShardDensity", config.shardDensity or 6.0)
	shader:send("SweepSpeed", config.sweepSpeed or 1.1)
	shader:send("RefractionStrength", config.refractionStrength or 0.7)
	shader:send("VeinStrength", config.veinStrength or 0.6)
	shader:send("ColorC", tertiary)
	elseif config.type == "EmberForge" then
	shader:send("EmberFrequency", config.emberFrequency or 8.0)
	shader:send("EmberSpeed", config.emberSpeed or 1.6)
	shader:send("EmberGlow", config.emberGlow or 0.7)
	shader:send("SlagDarkness", config.slagDarkness or 0.35)
	shader:send("ColorC", tertiary)
	elseif config.type == "MechanicalScan" then
	shader:send("ScanSpeed", config.scanSpeed or 1.8)
	shader:send("GearFrequency", config.gearFrequency or 12.0)
	shader:send("GearParallax", config.gearParallax or 1.2)
	shader:send("ServoIntensity", config.servoIntensity or 0.6)
	shader:send("ColorC", tertiary)
	elseif config.type == "TidalChorus" then
	shader:send("WaveFrequency", config.waveFrequency or 6.5)
	shader:send("CrestSpeed", config.crestSpeed or 1.4)
	shader:send("ChorusStrength", config.chorusStrength or 0.6)
	shader:send("DepthShift", config.depthShift or 0.0)
	shader:send("ColorC", tertiary)
	end

	love.graphics.push("all")
	love.graphics.setShader(shader)
	love.graphics.setBlendMode(config.blendMode or "alpha")
	love.graphics.setColor(1, 1, 1, config.opacity or 1)
	love.graphics.draw(canvas, 0, 0)
	love.graphics.pop()

	return true
end

-- helper: prefer DrawX/DrawY, fallback to x/y
local function PtXY(p)
	if not p then return nil, nil end
	return (p.drawX or p.x), (p.drawY or p.y)
end

local DrawSoftGlow

-- polyline coords {x1,y1,x2,y2,...}
local function BuildCoords(trail)
	local coords = {}
	local lastx, lasty
	for i = 1, #trail do
	local x, y = PtXY(trail[i])
	if x and y then
		if not (lastx and lasty and x == lastx and y == lasty) then
		coords[#coords+1] = x
		coords[#coords+1] = y
		lastx, lasty = x, y
		end
	end
	end
	return coords
end

local function DrawFruitBulges(trail, head, radius)
	if not trail or radius <= 0 then return end

	for i = 1, #trail do
	local seg = trail[i]
	if seg and seg.fruitMarker and seg ~= head then
		local x = seg.fruitMarkerX or (seg.drawX or seg.x)
		local y = seg.fruitMarkerY or (seg.drawY or seg.y)

		if x and y then
		love.graphics.circle("fill", x, y, radius)
		end
	end
	end
end

local function AddPoint(list, x, y)
	if not (x and y) then return end

	local n = #list
	if n >= 2 then
	local LastX = list[n - 1]
	local LastY = list[n]
	if math.abs(LastX - x) < 1e-4 and math.abs(LastY - y) < 1e-4 then
		return
	end
	end

	list[#list + 1] = x
	list[#list + 1] = y
end

local function BuildSmoothedCoords(coords, radius)
	if radius <= 0 or #coords <= 4 then
	return coords
	end

	local smoothed = {}
	local SmoothSteps = 4
	local MaxSmooth = radius * 1.5

	AddPoint(smoothed, coords[1], coords[2])

	for i = 3, #coords - 3, 2 do
	local x, y = coords[i], coords[i + 1]
	local px, py = coords[i - 2], coords[i - 1]
	local nx, ny = coords[i + 2], coords[i + 3]

	if not (px and py and nx and ny) then
		AddPoint(smoothed, x, y)
	else
		local PrevDx, PrevDy = x - px, y - py
		local NextDx, NextDy = nx - x, ny - y
		local PrevLen = math.sqrt(PrevDx * PrevDx + PrevDy * PrevDy)
		local NextLen = math.sqrt(NextDx * NextDx + NextDy * NextDy)

		if PrevLen < 1e-3 or NextLen < 1e-3 then
		AddPoint(smoothed, x, y)
		else
		local EntryDist = math.min(PrevLen * 0.5, MaxSmooth)
		local ExitDist = math.min(NextLen * 0.5, MaxSmooth)

		local EntryX = x - PrevDx / PrevLen * EntryDist
		local EntryY = y - PrevDy / PrevLen * EntryDist
		local ExitX = x + NextDx / NextLen * ExitDist
		local ExitY = y + NextDy / NextLen * ExitDist

		AddPoint(smoothed, EntryX, EntryY)

		for step = 1, SmoothSteps - 1 do
			local t = step / SmoothSteps
			local inv = 1 - t
			local qx = inv * inv * EntryX + 2 * inv * t * x + t * t * ExitX
			local qy = inv * inv * EntryY + 2 * inv * t * y + t * t * ExitY
			AddPoint(smoothed, qx, qy)
		end

		AddPoint(smoothed, ExitX, ExitY)
		end
	end
	end

	AddPoint(smoothed, coords[#coords - 1], coords[#coords])

	return smoothed
end

local function DrawCornerCaps(path, radius)
	if not path or radius <= 0 then
	return
	end

	local CoordCount = #path
	if CoordCount < 6 then
	return
	end

	local PointCount = math.floor(CoordCount / 2)
	if PointCount < 3 then
	return
	end

	for PointIndex = 2, PointCount - 1 do
	local px = path[(PointIndex - 1) * 2 - 1]
	local py = path[(PointIndex - 1) * 2]
	local x = path[PointIndex * 2 - 1]
	local y = path[PointIndex * 2]
	local nx = path[(PointIndex + 1) * 2 - 1]
	local ny = path[(PointIndex + 1) * 2]

	if px and py and x and y and nx and ny then
		local dx1 = x - px
		local dy1 = y - py
		local dx2 = nx - x
		local dy2 = ny - y

		local len1 = math.sqrt(dx1 * dx1 + dy1 * dy1)
		local len2 = math.sqrt(dx2 * dx2 + dy2 * dy2)

		if len1 > 1e-6 and len2 > 1e-6 then
		local dot = (dx1 * dx2 + dy1 * dy2) / (len1 * len2)
		if dot > 1 then dot = 1 end
		if dot < -1 then dot = -1 end

		if math.abs(dot - 1) > 1e-3 then
			love.graphics.circle("fill", x, y, radius)
		end
		end
	end
	end
end

local function DrawSnakeStroke(path, radius, options)
	if not path or radius <= 0 or #path < 2 then
	return
	end

	if #path == 2 then
	if options and options.sharpCorners then
		local x, y = path[1], path[2]
		love.graphics.rectangle("fill", x - radius, y - radius, radius * 2, radius * 2)
	else
		love.graphics.circle("fill", path[1], path[2], radius)
	end
	return
	end

	love.graphics.setLineWidth(radius * 2)
	love.graphics.line(path)

	local FirstX, FirstY = path[1], path[2]
	local LastX, LastY = path[#path - 1], path[#path]

	local UseRoundCaps = not (options and options.sharpCorners)

	if FirstX and FirstY and UseRoundCaps then
	love.graphics.circle("fill", FirstX, FirstY, radius)
	end

	if LastX and LastY and UseRoundCaps then
	love.graphics.circle("fill", LastX, LastY, radius)
	end

	DrawCornerCaps(path, radius)
end

local function RenderSnakeToCanvas(trail, coords, head, half, options)
	local BodyColor = SnakeCosmetics:GetBodyColor()
	local OutlineColor = SnakeCosmetics:GetOutlineColor()
	local BodyR, BodyG, BodyB, BodyA = BodyColor[1] or 0, BodyColor[2] or 0, BodyColor[3] or 0, BodyColor[4] or 1
	local OutlineR, OutlineG, OutlineB, OutlineA = OutlineColor[1] or 0, OutlineColor[2] or 0, OutlineColor[3] or 0, OutlineColor[4] or 1
	local BulgeRadius = half * FRUIT_BULGE_SCALE

	local SharpCorners = options and options.sharpCorners

	local OutlineCoords = coords
	local BodyCoords = coords

	love.graphics.push("all")
	if SharpCorners then
	love.graphics.setLineStyle("rough")
	love.graphics.setLineJoin("miter")
	else
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineJoin("bevel")
	end

	love.graphics.setColor(OutlineR, OutlineG, OutlineB, OutlineA)
	DrawSnakeStroke(OutlineCoords, half + OUTLINE_SIZE, options)
	DrawFruitBulges(trail, head, BulgeRadius + OUTLINE_SIZE)

	love.graphics.setColor(BodyR, BodyG, BodyB, BodyA)
	DrawSnakeStroke(BodyCoords, half, options)
	DrawFruitBulges(trail, head, BulgeRadius)

	love.graphics.pop()

end

DrawSoftGlow = function(x, y, radius, r, g, b, a, BlendMode)
	if radius <= 0 then return end

	local ColorR = r or 0
	local ColorG = g or 0
	local ColorB = b or 0
	local ColorA = a or 1
	local mode = BlendMode or "add"

	love.graphics.push("all")

	if mode == "alpha" then
	love.graphics.setBlendMode("alpha", "premultiplied")
	else
	love.graphics.setBlendMode("add")
	end

	local layers = 4
	for i = 1, layers do
	local t = (i - 1) / (layers - 1)
	local fade = (1 - t)
	local LayerAlpha = ColorA * fade * fade

	if mode == "alpha" then
		love.graphics.setColor(ColorR * LayerAlpha, ColorG * LayerAlpha, ColorB * LayerAlpha, LayerAlpha)
	else
		love.graphics.setColor(ColorR, ColorG, ColorB, LayerAlpha)
	end

	love.graphics.circle("fill", x, y, radius * (0.55 + 0.35 * t))
	end

	love.graphics.pop()
end

local function DrawShieldBubble(hx, hy, SEGMENT_SIZE, ShieldCount, ShieldFlashTimer)
        local HasShield = ShieldCount and ShieldCount > 0
        if not HasShield and not (ShieldFlashTimer and ShieldFlashTimer > 0) then
        return
        end

	local BaseRadius = SEGMENT_SIZE * (0.95 + 0.06 * math.max(0, (ShieldCount or 1) - 1))
	local time = love.timer.getTime()

	local pulse = 1 + 0.08 * math.sin(time * 6)
	local alpha = 0.35 + 0.1 * math.sin(time * 5)

	if ShieldFlashTimer and ShieldFlashTimer > 0 then
	local flash = math.min(1, ShieldFlashTimer / 0.3)
	pulse = pulse + flash * 0.25
	alpha = alpha + flash * 0.4
	end

	DrawSoftGlow(hx, hy, BaseRadius * (1.2 + 0.1 * pulse), 0.35, 0.8, 1, alpha * 0.8)

	love.graphics.setLineWidth(4)
	local LineAlpha = alpha + (HasShield and 0.25 or 0.45)
	love.graphics.setColor(0.45, 0.85, 1, LineAlpha)
	love.graphics.circle("line", hx, hy, BaseRadius * pulse)

	love.graphics.setColor(0.45, 0.85, 1, (alpha + 0.15) * 0.5)
	love.graphics.circle("fill", hx, hy, BaseRadius * 0.8 * pulse)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
end

local function DrawQuickFangsAura(hx, hy, SEGMENT_SIZE, data)
        if not data then return end
        local stacks = data.stacks or 0
        if stacks <= 0 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local flash = math.max(0, data.flash or 0)
        local ratio = data.speedRatio or 1
        if not ratio or ratio < 0 then
                ratio = 0
        end

        local SpeedBonus = math.max(0, ratio - 1)
        local highlight = math.min(1, intensity * 0.85 + flash * 0.6 + math.min(0.45, SpeedBonus * 0.4))
        local time = data.time or love.timer.getTime()
        if not time or time <= 0 then
                time = love.timer.getTime()
        end

        local BaseRadius = SEGMENT_SIZE * (0.92 + 0.07 * math.min(stacks, 4))
        DrawSoftGlow(hx, hy, BaseRadius * (1.25 + 0.25 * highlight), 1.0, 0.62, 0.42, 0.18 + 0.24 * highlight)

        love.graphics.push("all")
        love.graphics.translate(hx, hy)
        love.graphics.setBlendMode("alpha")

        local RingAlpha = 0.18 + 0.28 * highlight
        love.graphics.setLineWidth(2.2)
        love.graphics.setColor(1.0, 0.68, 0.42, RingAlpha)
        love.graphics.circle("line", 0, 0, BaseRadius * (0.92 + 0.18 * highlight), 32)

        local FangCount = 5 + math.min(stacks * 2, 6)
        local orbit = BaseRadius * (0.8 + 0.18 * highlight)
        local FangLength = SEGMENT_SIZE * (0.35 + 0.05 * stacks + 0.08 * highlight)
        local FangWidth = FangLength * 0.24
        local OutlineWidth = 0.9 + 0.6 * highlight
        local spin = 2.8 + stacks * 0.35 + SpeedBonus * 1.2

        for i = 1, FangCount do
                local offset = (i - 1) / FangCount
                local angle = time * spin + offset * math.pi * 2
                local wobble = math.sin(time * (4.6 + stacks * 0.3) + i * 1.2) * (0.18 + 0.12 * highlight)
                local FinalAngle = angle + wobble

                local DirX = math.cos(FinalAngle)
                local DirY = math.sin(FinalAngle)
                local BaseX = DirX * orbit
                local BaseY = DirY * orbit
                local TipX = DirX * (orbit + FangLength)
                local TipY = DirY * (orbit + FangLength)
                local PerpX = -DirY
                local PerpY = DirX
                local LeftX = BaseX + PerpX * FangWidth * 0.5
                local LeftY = BaseY + PerpY * FangWidth * 0.5
                local RightX = BaseX - PerpX * FangWidth * 0.5
                local RightY = BaseY - PerpY * FangWidth * 0.5

                local FangAlpha = math.min(1, 0.36 + 0.4 * intensity + flash * 0.4)
                love.graphics.setLineWidth(OutlineWidth)
                love.graphics.setColor(1.0, 0.66, 0.46, FangAlpha)
                love.graphics.polygon("line", LeftX, LeftY, TipX, TipY, RightX, RightY)

                love.graphics.setLineWidth(OutlineWidth * 0.7)
                love.graphics.setColor(1.0, 0.9, 0.7, FangAlpha * 0.85)
                love.graphics.line(LeftX, LeftY, TipX, TipY)
                love.graphics.line(RightX, RightY, TipX, TipY)

                local SlashRadius = orbit + FangLength * (0.75 + 0.1 * highlight)
                local SlashWidth = 0.2 + 0.08 * highlight
                love.graphics.setLineWidth(1.6)
                love.graphics.setColor(1.0, 0.74, 0.46, (0.22 + 0.26 * intensity + 0.2 * flash) * (0.9 - offset * 0.2))
                love.graphics.arc("line", "open", 0, 0, SlashRadius, FinalAngle - SlashWidth, FinalAngle + SlashWidth, 18)
        end

        if data.active then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1.0, 0.82, 0.52, 0.2 + 0.3 * highlight)
                love.graphics.circle("line", 0, 0, BaseRadius * (1.35 + 0.25 * highlight), 36)
        end

        love.graphics.pop()
end

local function DrawStonebreakerAura(hx, hy, SEGMENT_SIZE, data)
        if not data then return end
        local stacks = data.stacks or 0
        if stacks <= 0 then return end

	local progress = data.progress or 0
	local rate = data.rate or 0
	if rate >= 1 then
	progress = 1
	else
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	end

	local time = love.timer.getTime()

	local BaseRadius = SEGMENT_SIZE * (1.05 + 0.04 * math.min(stacks, 3))
	local BaseAlpha = 0.18 + 0.08 * math.min(stacks, 3)

	DrawSoftGlow(hx, hy, BaseRadius * 1.25, 0.95, 0.86, 0.6, BaseAlpha * 1.2)

	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.52, 0.46, 0.4, BaseAlpha)
	love.graphics.circle("line", hx, hy, BaseRadius)

	if progress > 0 then
	local StartAngle = -math.pi / 2
	love.graphics.setColor(0.88, 0.74, 0.46, 0.35 + 0.25 * progress)
	love.graphics.setLineWidth(3)
	love.graphics.arc("line", "open", hx, hy, BaseRadius * 1.08, StartAngle, StartAngle + progress * math.pi * 2)
	end

	local shards = math.max(4, 3 + math.min(stacks * 2, 6))
	local ready = (rate >= 1) or (progress >= 0.99)
	for i = 1, shards do
	local angle = time * (0.8 + stacks * 0.2) + (i / shards) * math.pi * 2
	local wobble = 0.08 * math.sin(time * 3 + i)
	local radius = BaseRadius * (1.05 + wobble)
	local size = SEGMENT_SIZE * (0.08 + 0.02 * math.min(stacks, 3))
	local alpha = 0.25 + 0.35 * progress
	if ready then
		alpha = alpha + 0.2
	end
	love.graphics.setColor(0.95, 0.86, 0.6, alpha)
	love.graphics.circle("fill", hx + math.cos(angle) * radius, hy + math.sin(angle) * radius, size)
	end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
end

local function DrawEventHorizonSheath(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 1 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local time = data.time or love.timer.getTime()
        local spin = data.spin or 0
        local SegmentCount = math.min(#trail, 10)

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        for i = 1, SegmentCount do
                local seg = trail[i]
                local px, py = PtXY(seg)
                if px and py then
                        local progress = (i - 1) / math.max(SegmentCount - 1, 1)
                        local fade = 1 - progress * 0.65
                        local radius = SEGMENT_SIZE * (0.7 + 0.28 * intensity + 0.16 * fade)
                        local swirl = spin * 1.3 + time * 0.6 + progress * math.pi * 1.2

                        love.graphics.setColor(0.04, 0.08, 0.16, (0.18 + 0.22 * intensity) * fade)
                        love.graphics.circle("fill", px, py, radius * 1.05)

                        love.graphics.setColor(0.78, 0.88, 1.0, (0.14 + 0.25 * intensity) * fade)
                        love.graphics.setLineWidth(SEGMENT_SIZE * (0.08 + 0.05 * intensity) * fade)
                        love.graphics.circle("line", px, py, radius)

                        local ShardCount = 3
                        for shard = 1, ShardCount do
                                local angle = swirl + shard * (math.pi * 2 / ShardCount)
                                local orbit = radius * (1.2 + 0.12 * shard)
                                local ox = px + math.cos(angle) * orbit
                                local oy = py + math.sin(angle) * orbit
                                local ShardSize = SEGMENT_SIZE * (0.12 + 0.07 * intensity) * fade
                                love.graphics.setColor(0.96, 0.84, 0.46, (0.18 + 0.24 * intensity) * fade)
                                love.graphics.circle("fill", ox, oy, ShardSize)
                                love.graphics.setColor(0.36, 0.66, 1.0, (0.2 + 0.28 * intensity) * fade)
                                love.graphics.circle("line", ox, oy, ShardSize * 1.35)
                        end
                end
        end

        local HeadSeg = trail[1]
        local hx, hy = PtXY(HeadSeg)
        if hx and hy then
                DrawSoftGlow(hx, hy, SEGMENT_SIZE * (2.15 + 0.65 * intensity), 0.7, 0.84, 1.0, 0.18 + 0.24 * intensity)
        end

        love.graphics.pop()
end

local function DrawStormchaserCurrent(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 2 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local primed = data.primed or false
        local time = data.time or love.timer.getTime()
        local stride = math.max(1, math.floor(#trail / (6 + intensity * 6)))

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        for i = 1, #trail - stride, stride do
                local seg = trail[i]
                local NextSeg = trail[i + stride]
                local x1, y1 = PtXY(seg)
                local x2, y2 = PtXY(NextSeg)
                if x1 and y1 and x2 and y2 then
                        local DirX, DirY = x2 - x1, y2 - y1
                        local len = math.sqrt(DirX * DirX + DirY * DirY)
                        if len < 1e-4 then
                                DirX, DirY = 0, 1
                        else
                                DirX, DirY = DirX / len, DirY / len
                        end
                        local PerpX, PerpY = -DirY, DirX

                        local bolt = { x1, y1 }
                        local segments = 3
                        for SegIdx = 1, segments do
                                local t = SegIdx / (segments + 1)
                                local offset = math.sin(time * 8 + i * 0.45 + SegIdx * 1.2) * SEGMENT_SIZE * 0.3 * intensity
                                local px = x1 + DirX * len * t + PerpX * offset
                                local py = y1 + DirY * len * t + PerpY * offset
                                bolt[#bolt + 1] = px
                                bolt[#bolt + 1] = py
                        end
                        bolt[#bolt + 1] = x2
                        bolt[#bolt + 1] = y2

                        love.graphics.setColor(0.32, 0.68, 1.0, 0.2 + 0.32 * intensity)
                        love.graphics.setLineWidth(2.2 + intensity * 1.2)
                        love.graphics.line(bolt)

                        local cx = (x1 + x2) * 0.5
                        local cy = (y1 + y2) * 0.5
                        love.graphics.setColor(0.9, 0.96, 1.0, 0.16 + 0.26 * intensity)
                        love.graphics.circle("fill", cx, cy, SEGMENT_SIZE * (0.16 + 0.08 * intensity))
                end
        end

        if primed then
                local HeadSeg = trail[1]
                local hx, hy = PtXY(HeadSeg)
                if hx and hy then
                        love.graphics.setColor(0.38, 0.74, 1.0, 0.24 + 0.34 * intensity)
                        love.graphics.setLineWidth(2.4)
                        love.graphics.circle("line", hx, hy, SEGMENT_SIZE * (1.4 + 0.32 * intensity))
                end
        end

        love.graphics.pop()
end

local function DrawTitanbloodSigils(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 3 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local stacks = math.max(1, data.stacks or 1)
        local time = data.time or love.timer.getTime()
        local SigilCount = math.min(#trail - 1, 8 + stacks * 3)

        love.graphics.push("all")

        for i = 2, SigilCount + 1 do
                local seg = trail[i]
                local prev = trail[i - 1]
                local x1, y1 = PtXY(seg)
                local x0, y0 = PtXY(prev)
                if x1 and y1 and x0 and y0 then
                        local DirX, DirY = x1 - x0, y1 - y0
                        local len = math.sqrt(DirX * DirX + DirY * DirY)
                        if len < 1e-4 then
                                DirX, DirY = 0, 1
                        else
                                DirX, DirY = DirX / len, DirY / len
                        end
                        local PerpX, PerpY = -DirY, DirX
                        local progress = (i - 2) / math.max(SigilCount - 1, 1)
                        local fade = 1 - progress * 0.6
                        local sway = math.sin(time * 2.6 + i * 0.8) * SEGMENT_SIZE * 0.12 * fade
                        local offset = SEGMENT_SIZE * (0.45 + 0.08 * math.min(stacks, 4))
                        local cx = x1 + PerpX * (offset + sway)
                        local cy = y1 + PerpY * (offset + sway)

                        love.graphics.push()
                        love.graphics.translate(cx, cy)
                        love.graphics.rotate(math.atan2(DirY, DirX))

                        local base = SEGMENT_SIZE * (0.28 + 0.08 * math.min(stacks, 3))
                        love.graphics.setColor(0.32, 0.02, 0.08, (0.16 + 0.24 * intensity) * fade)
                        love.graphics.ellipse("fill", 0, 0, base * 1.2, base * 0.55)

                        local scale = base * (1.1 + 0.45 * intensity)
                        local vertices = {
                                0, -scale * 0.6,
                                scale * 0.45, 0,
                                0, scale * 0.6,
                                -scale * 0.45, 0,
                        }

                        love.graphics.setColor(0.82, 0.14, 0.22, (0.22 + 0.3 * intensity) * fade)
                        love.graphics.polygon("fill", vertices)
                        love.graphics.setColor(1.0, 0.52, 0.4, (0.2 + 0.28 * intensity) * fade)
                        love.graphics.setLineWidth(1.4)
                        love.graphics.polygon("line", vertices)

                        love.graphics.pop()
                end
        end

        love.graphics.pop()
end

local function DrawChronospiralWake(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 2 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local spin = data.spin or 0
        local step = math.max(2, math.floor(#trail / 12))

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        for i = 1, #trail, step do
                local seg = trail[i]
                local NextSeg = trail[math.min(#trail, i + 1)]
                local px, py = PtXY(seg)
                if px and py then
                        local nx, ny = PtXY(NextSeg)
                        local DirX, DirY = 0, -1
                        if nx and ny then
                                DirX, DirY = nx - px, ny - py
                                local len = math.sqrt(DirX * DirX + DirY * DirY)
                                if len > 1e-3 then
                                        DirX, DirY = DirX / len, DirY / len
                                else
                                        DirX, DirY = 0, -1
                                end
                        end

                        local angle = (math.atan2 and math.atan2(DirY, DirX)) or math.atan(DirY, DirX)
                        local progress = (i - 1) / math.max(#trail - 1, 1)
                        local BaseRadius = SEGMENT_SIZE * (0.55 + 0.35 * intensity)
                        local fade = 1 - progress * 0.65
                        local swirl = spin * 1.25 + progress * math.pi * 1.6

                        love.graphics.setLineWidth(1.2 + intensity * 1.2)
                        love.graphics.setColor(0.56, 0.82, 1.0, (0.14 + 0.28 * intensity) * fade)
                        love.graphics.circle("line", px, py, BaseRadius)

                        love.graphics.setColor(0.84, 0.68, 1.0, (0.16 + 0.3 * intensity) * fade)
                        love.graphics.arc("line", "open", px, py, BaseRadius * 1.15, swirl, swirl + math.pi * 0.35)
                        love.graphics.arc("line", "open", px, py, BaseRadius * 0.85, swirl + math.pi, swirl + math.pi + math.pi * 0.3)

                        love.graphics.push()
                        love.graphics.translate(px, py)
                        love.graphics.rotate(angle)
                        local ribbon = BaseRadius * (0.8 + 0.25 * math.sin(swirl * 1.4))
                        love.graphics.setColor(0.46, 0.78, 1.0, (0.12 + 0.22 * intensity) * fade)
                        love.graphics.rectangle("fill", -ribbon, -BaseRadius * 0.22, ribbon * 2, BaseRadius * 0.44)
                        love.graphics.pop()
                end
        end

        local coords = {}
        local PathStep = math.max(1, math.floor(#trail / 24))
        local JitterScale = SEGMENT_SIZE * 0.2 * intensity
        for i = 1, #trail, PathStep do
                local seg = trail[i]
                local px, py = PtXY(seg)
                if px and py then
                        local jitter = math.sin(spin * 2.0 + i * 0.33) * JitterScale
                        coords[#coords + 1] = px + jitter
                        coords[#coords + 1] = py - jitter * 0.4
                end
        end

        if #coords >= 4 then
                love.graphics.setColor(0.52, 0.86, 1.0, 0.1 + 0.18 * intensity)
                love.graphics.setLineWidth(SEGMENT_SIZE * (0.12 + 0.05 * intensity))
                love.graphics.line(coords)
        end

        love.graphics.pop()
end

local function DrawAbyssalCatalystVeil(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 2 then return end

        local intensity = math.max(0, data.intensity or 0)
        if intensity <= 0.01 then return end

        local stacks = math.max(1, data.stacks or 1)
        local pulse = data.pulse or 0
        local BaseRadius = SEGMENT_SIZE * (0.48 + 0.14 * math.min(stacks, 3))
        local OrbCount = math.min(28, (#trail - 1) * 2)

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        for i = 1, OrbCount do
                local progress = (i - 0.5) / OrbCount
                local IdxFloat = 1 + progress * math.max(#trail - 1, 1)
                local index = math.floor(IdxFloat)
                local frac = IdxFloat - index
                local seg = trail[index]
                local NextSeg = trail[math.min(#trail, index + 1)]
                local px, py = PtXY(seg)
                local nx, ny = PtXY(NextSeg)
                if px and py and nx and ny then
                        local x = px + (nx - px) * frac
                        local y = py + (ny - py) * frac
                        local DirX, DirY = nx - px, ny - py
                        local len = math.sqrt(DirX * DirX + DirY * DirY)
                        if len < 1e-4 then
                                DirX, DirY = 0, 1
                        else
                                DirX, DirY = DirX / len, DirY / len
                        end
                        local PerpX, PerpY = -DirY, DirX
                        local swirl = pulse * 1.4 + progress * math.pi * 4
                        local offset = math.sin(swirl) * BaseRadius * (0.9 + intensity * 0.7)
                        local drift = math.cos(swirl * 0.6) * BaseRadius * 0.35
                        local ax = x + PerpX * offset + DirX * drift
                        local ay = y + PerpY * offset + DirY * drift
                        local fade = 1 - progress * 0.6
                        local OrbRadius = SEGMENT_SIZE * (0.16 + 0.12 * intensity * fade)

                        love.graphics.setColor(0.32, 0.2, 0.52, 0.24 * intensity * fade)
                        love.graphics.circle("fill", ax, ay, OrbRadius * 1.4)
                        love.graphics.setColor(0.68, 0.56, 0.94, 0.18 * intensity * fade)
                        love.graphics.circle("line", ax, ay, OrbRadius * 1.9)
                end
        end

        local HeadSeg = trail[1]
        local hx, hy = PtXY(HeadSeg)
        if hx and hy then
                DrawSoftGlow(hx, hy, BaseRadius * (2.4 + 0.4 * intensity), 0.62, 0.42, 0.94, 0.22 + 0.3 * intensity)
                love.graphics.setColor(0.22, 0.14, 0.36, 0.18 + 0.28 * intensity)
                love.graphics.setLineWidth(2.2)
                love.graphics.circle("line", hx, hy, BaseRadius * (2.0 + 0.55 * intensity))
        end

        love.graphics.pop()
end

local function DrawPhoenixEchoTrail(trail, SEGMENT_SIZE, data)
        if not (trail and data) then return end
        if #trail < 2 then return end

        local intensity = math.max(0, data.intensity or 0)
        local charges = math.max(0, data.charges or 0)
        local flare = math.max(0, data.flare or 0)
        local heat = math.min(1.2, intensity * 0.7 + charges * 0.18 + flare * 0.6)
        if heat <= 0.02 then return end

        local time = data.time or love.timer.getTime()

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        local WingSegments = math.min(#trail - 1, 8 + charges * 3)
        for i = 1, WingSegments do
                local seg = trail[i]
                local NextSeg = trail[i + 1]
                local x1, y1 = PtXY(seg)
                local x2, y2 = PtXY(NextSeg)
                if x1 and y1 and x2 and y2 then
                        local DirX, DirY = x2 - x1, y2 - y1
                        local len = math.sqrt(DirX * DirX + DirY * DirY)
                        if len < 1e-4 then
                                DirX, DirY = 0, 1
                        else
                                DirX, DirY = DirX / len, DirY / len
                        end
                        local PerpX, PerpY = -DirY, DirX
                        local progress = (i - 1) / math.max(1, WingSegments - 1)
                        local fade = 1 - progress * 0.6
                        local width = SEGMENT_SIZE * (0.32 + 0.14 * heat + 0.06 * charges)
                        local length = SEGMENT_SIZE * (0.7 + 0.25 * heat + 0.1 * charges)
                        local flutter = math.sin(time * 7 + i * 0.55) * width * 0.35
                        local BaseX = x1 - DirX * SEGMENT_SIZE * 0.25 + PerpX * flutter
                        local BaseY = y1 - DirY * SEGMENT_SIZE * 0.25 + PerpY * flutter
                        local TipX = BaseX + DirX * length
                        local TipY = BaseY + DirY * length
                        local LeftX = BaseX + PerpX * width
                        local LeftY = BaseY + PerpY * width
                        local RightX = BaseX - PerpX * width
                        local RightY = BaseY - PerpY * width

                        love.graphics.setColor(1.0, 0.58, 0.22, (0.18 + 0.3 * heat) * fade)
                        love.graphics.polygon("fill", LeftX, LeftY, TipX, TipY, RightX, RightY)
                        love.graphics.setColor(1.0, 0.82, 0.32, (0.12 + 0.22 * heat) * fade)
                        love.graphics.polygon("line", LeftX, LeftY, TipX, TipY, RightX, RightY)
                        love.graphics.setColor(1.0, 0.42, 0.12, (0.16 + 0.28 * heat) * fade)
                        love.graphics.circle("fill", TipX, TipY, SEGMENT_SIZE * (0.15 + 0.08 * heat))
                end
        end

        local EmberCount = math.min(32, (#trail - 2) * 2 + charges * 4)
        for i = 1, EmberCount do
                local progress = (i - 0.5) / EmberCount
                local IdxFloat = 1 + progress * math.max(#trail - 2, 1)
                local index = math.floor(IdxFloat)
                local frac = IdxFloat - index
                local seg = trail[index]
                local NextSeg = trail[math.min(#trail, index + 1)]
                local x1, y1 = PtXY(seg)
                local x2, y2 = PtXY(NextSeg)
                if x1 and y1 and x2 and y2 then
                        local x = x1 + (x2 - x1) * frac
                        local y = y1 + (y2 - y1) * frac
                        local DirX, DirY = x2 - x1, y2 - y1
                        local len = math.sqrt(DirX * DirX + DirY * DirY)
                        if len < 1e-4 then
                                DirX, DirY = 0, 1
                        else
                                DirX, DirY = DirX / len, DirY / len
                        end
                        local PerpX, PerpY = -DirY, DirX
                        local sway = math.sin(time * 5.2 + i) * SEGMENT_SIZE * 0.22 * heat
                        local lift = math.cos(time * 3.4 + i * 0.8) * SEGMENT_SIZE * 0.28
                        local fx = x + PerpX * sway + DirX * lift * 0.25
                        local fy = y + PerpY * sway + DirY * lift
                        local fade = 0.5 + 0.5 * (1 - progress)

                        love.graphics.setColor(1.0, 0.5, 0.16, (0.12 + 0.2 * heat) * fade)
                        love.graphics.circle("fill", fx, fy, SEGMENT_SIZE * (0.1 + 0.05 * heat * fade))
                        love.graphics.setColor(1.0, 0.86, 0.42, (0.08 + 0.16 * heat) * fade)
                        love.graphics.circle("line", fx, fy, SEGMENT_SIZE * (0.14 + 0.06 * heat))
                end
        end

        local HeadSeg = trail[1]
        local hx, hy = PtXY(HeadSeg)
        if hx and hy then
                DrawSoftGlow(hx, hy, SEGMENT_SIZE * (1.35 + 0.35 * (charges + heat)), 1.0, 0.62, 0.26, 0.3 + 0.35 * heat)
        end

        love.graphics.pop()
end

local function DrawTimeDilationAura(hx, hy, SEGMENT_SIZE, data)
        if not data then return end

        local duration = data.duration or 0
        if duration <= 0 then duration = 1 end

	local timer = math.max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local CooldownTimer = math.max(0, data.cooldownTimer or 0)

	local readiness
	if cooldown > 0 then
	readiness = 1 - math.min(1, CooldownTimer / math.max(0.0001, cooldown))
	else
	readiness = data.active and 1 or 0.6
	end

	local intensity = readiness * 0.35
	if data.active then
	intensity = math.max(intensity, 0.45) + 0.45 * math.min(1, timer / duration)
	end

	if intensity <= 0 then return end

	local time = love.timer.getTime()

	local BaseRadius = SEGMENT_SIZE * (0.95 + 0.35 * intensity)

	DrawSoftGlow(hx, hy, BaseRadius * 1.55, 0.45, 0.9, 1, 0.3 + 0.45 * intensity)

	love.graphics.push("all")

	love.graphics.setBlendMode("add")
	for i = 1, 3 do
	local RingT = (i - 1) / 2
	local wobble = math.sin(time * (1.6 + RingT * 0.8)) * SEGMENT_SIZE * 0.06
	love.graphics.setColor(0.32, 0.74, 1, (0.15 + 0.25 * intensity) * (1 - RingT * 0.35))
	love.graphics.setLineWidth(1.6 + (3 - i) * 0.9)
	love.graphics.circle("line", hx, hy, BaseRadius * (1.05 + RingT * 0.25) + wobble)
	end

	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(0.4, 0.8, 1, 0.25 + 0.4 * intensity)
	love.graphics.setLineWidth(2)
	local wobble = 1 + 0.08 * math.sin(time * 2.2)
	love.graphics.circle("line", hx, hy, BaseRadius * wobble)

	local DialRotation = time * (data.active and 1.8 or 0.9)
	love.graphics.setColor(0.26, 0.62, 0.95, 0.2 + 0.25 * intensity)
	love.graphics.setLineWidth(2.4)
	for i = 1, 3 do
	local offset = DialRotation + (i - 1) * (math.pi * 2 / 3)
	love.graphics.arc("line", "open", hx, hy, BaseRadius * 0.75, offset, offset + math.pi / 4)
	end

	local TickCount = 6
	local spin = time * (data.active and -1.2 or -0.6)
	love.graphics.setColor(0.6, 0.95, 1, 0.2 + 0.35 * intensity)
	for i = 1, TickCount do
	local angle = spin + (i / TickCount) * math.pi * 2
	local inner = BaseRadius * 0.55
	local outer = BaseRadius * (1.25 + 0.1 * math.sin(time * 3 + i))
	love.graphics.line(
		hx + math.cos(angle) * inner,
		hy + math.sin(angle) * inner,
		hx + math.cos(angle) * outer,
		hy + math.sin(angle) * outer
	)
	end

        love.graphics.pop()
end

local function DrawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, data)
        if not (data and hx and hy) then return end

        local intensity = math.max(0, data.intensity or 0)
        local readiness = math.max(0, math.min(1, data.ready or 0))
        if intensity <= 0.01 and readiness <= 0.01 then return end

        local time = data.time or love.timer.getTime()
        local BaseRadius = SEGMENT_SIZE * (1.05 + 0.28 * readiness + 0.22 * intensity)

        DrawSoftGlow(hx, hy, BaseRadius * 1.35, 0.52, 0.78, 1.0, 0.18 + 0.28 * (intensity + readiness * 0.5))

        love.graphics.push("all")
        love.graphics.setBlendMode("add")

        love.graphics.setColor(0.46, 0.8, 1.0, 0.18 + 0.32 * (intensity + readiness * 0.6))
        love.graphics.setLineWidth(2 + 1.2 * intensity)
        love.graphics.circle("line", hx, hy, BaseRadius)

        local OrbitCount = 4
        for i = 1, OrbitCount do
                local angle = time * (1.0 + 0.4 * intensity) + (i - 1) * (math.pi * 2 / OrbitCount)
                local inner = BaseRadius * 0.58
                local outer = BaseRadius * (0.92 + 0.18 * readiness)
                love.graphics.setColor(0.68, 0.9, 1.0, (0.16 + 0.26 * readiness) * (0.6 + 0.4 * intensity))
                love.graphics.setLineWidth(2.4)
                love.graphics.line(
                        hx + math.cos(angle) * inner,
                        hy + math.sin(angle) * inner,
                        hx + math.cos(angle) * outer,
                        hy + math.sin(angle) * outer
                )
        end

        local sweep = math.pi * 0.35
        local rotation = time * (1.4 + 0.6 * readiness)
        love.graphics.setColor(0.38, 0.7, 1.0, 0.16 + 0.28 * intensity)
        love.graphics.setLineWidth(1.8)
        love.graphics.arc("line", "open", hx, hy, BaseRadius * 0.78, rotation, rotation + sweep)
        love.graphics.arc("line", "open", hx, hy, BaseRadius * 0.78, rotation + math.pi, rotation + math.pi + sweep * 0.85)

        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0.82, 0.94, 1.0, 0.24 + 0.28 * intensity)
        love.graphics.setLineWidth(2.4)
        love.graphics.line(hx - BaseRadius * 0.22, hy, hx + BaseRadius * 0.22, hy)
        love.graphics.line(hx, hy - BaseRadius * 0.45, hx, hy + BaseRadius * 0.4)

        love.graphics.pop()
end

local function DrawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, data)
        if not data or not data.active then return end

        local duration = data.duration or 0
        if duration <= 0 then duration = 1 end
	local timer = data.timer or 0
	if timer < 0 then timer = 0 end
	local intensity = math.min(1, timer / duration)

	local time = love.timer.getTime()

	local pulse = 0.9 + 0.1 * math.sin(time * 6)
	local radius = SEGMENT_SIZE * (0.6 + 0.35 * intensity) * pulse

	DrawSoftGlow(hx, hy, radius * 1.4, 1, 0.68 + 0.2 * intensity, 0.25, 0.4 + 0.5 * intensity)

	love.graphics.setColor(1, 0.6 + 0.25 * intensity, 0.2, 0.35 + 0.4 * intensity)
	love.graphics.circle("fill", hx, hy, radius)

	love.graphics.setColor(1, 0.52 + 0.3 * intensity, 0.18, 0.2 + 0.25 * intensity)
	love.graphics.circle("line", hx, hy, radius * 1.1)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function DrawDashStreaks(trail, SEGMENT_SIZE, data)
	if not data then return end
	if not trail or #trail < 2 then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = math.max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local CooldownTimer = math.max(0, data.cooldownTimer or 0)

	local intensity = 0
	if data.active then
	intensity = math.max(0.35, math.min(1, timer / duration + 0.2))
	elseif cooldown > 0 then
	intensity = math.max(0, 1 - CooldownTimer / math.max(0.0001, cooldown)) * 0.45
	else
	intensity = 0.3
	end

	if intensity <= 0 then return end

	local time = love.timer.getTime()

	local streaks = math.min(#trail - 1, 6)
	if streaks <= 0 then return end

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, streaks do
	local seg = trail[i]
	local NextSeg = trail[i + 1]
	local x1, y1 = PtXY(seg)
	local x2, y2 = PtXY(NextSeg)
	if x1 and y1 and x2 and y2 then
		local fade = (streaks - i + 1) / streaks
		local wobble = math.sin(time * 8 + i) * SEGMENT_SIZE * 0.05
		local DirX, DirY = x2 - x1, y2 - y1
		local length = math.sqrt(DirX * DirX + DirY * DirY)
		if length > 1e-4 then
		DirX, DirY = DirX / length, DirY / length
		end
		local PerpX, PerpY = -DirY, DirX

		local OffsetX = PerpX * wobble
		local OffsetY = PerpY * wobble

		love.graphics.setColor(1, 0.76, 0.28, 0.18 + 0.4 * intensity * fade)
		love.graphics.setLineWidth(SEGMENT_SIZE * (0.35 + 0.12 * intensity * fade))
		love.graphics.line(x1 + OffsetX, y1 + OffsetY, x2 + OffsetX, y2 + OffsetY)

		love.graphics.setColor(1, 0.42, 0.12, 0.15 + 0.25 * intensity * fade)
		love.graphics.circle("fill", x2 + OffsetX * 0.5, y2 + OffsetY * 0.5, SEGMENT_SIZE * 0.16 * fade)
	end
	end

	love.graphics.pop()
end

local function DrawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = math.max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local CooldownTimer = math.max(0, data.cooldownTimer or 0)

	local readiness
	if data.active then
	readiness = math.min(1, timer / duration)
	elseif cooldown > 0 then
	readiness = 1 - math.min(1, CooldownTimer / math.max(0.0001, cooldown))
	else
	readiness = 1
	end

	readiness = math.max(0, math.min(1, readiness))
	local intensity = readiness
	if data.active then
	intensity = math.max(intensity, 0.75)
	end

	if intensity <= 0 then return end

	local time = love.timer.getTime()

	local BaseRadius = SEGMENT_SIZE * (0.85 + 0.3 * intensity)
	DrawSoftGlow(hx, hy, BaseRadius * (1.35 + 0.25 * intensity), 1, 0.78, 0.32, 0.25 + 0.35 * intensity)

	local DirX, DirY = 0, -1
	local head = trail and trail[1]
	if head and (head.dirX or head.dirY) then
	DirX = head.dirX or DirX
	DirY = head.dirY or DirY
	end

	local NextSeg = trail and trail[2]
	if head and NextSeg then
	local hx1, hy1 = PtXY(head)
	local hx2, hy2 = PtXY(NextSeg)
	if hx1 and hy1 and hx2 and hy2 then
		local dx, dy = hx2 - hx1, hy2 - hy1
		if dx ~= 0 or dy ~= 0 then
		DirX, DirY = dx, dy
		end
	end
	end

	local length = math.sqrt(DirX * DirX + DirY * DirY)
	if length > 1e-4 then
	DirX, DirY = DirX / length, DirY / length
	end

	local angle
	if math.atan2 then
	angle = math.atan2(DirY, DirX)
	else
	angle = math.atan(DirY, DirX)
	end

	love.graphics.push("all")
	love.graphics.translate(hx, hy)
	love.graphics.rotate(angle)

	love.graphics.setColor(1, 0.78, 0.26, 0.3 + 0.4 * intensity)
	love.graphics.setLineWidth(2 + intensity * 2)
	love.graphics.arc("line", "open", 0, 0, BaseRadius, -math.pi * 0.65, math.pi * 0.65)

	love.graphics.setBlendMode("add")
	local FlareRadius = BaseRadius * (1.18 + 0.08 * math.sin(time * 5))
	love.graphics.setColor(1, 0.86, 0.42, 0.22 + 0.35 * intensity)
	love.graphics.arc("fill", 0, 0, FlareRadius, -math.pi * 0.28, math.pi * 0.28)

	if not data.active then
	local sweep = readiness * math.pi * 2
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 0.62, 0.18, 0.35 + 0.4 * intensity)
	love.graphics.setLineWidth(3)
	love.graphics.arc("line", "open", 0, 0, BaseRadius * 0.85, -math.pi / 2, -math.pi / 2 + sweep)
	else
	local pulse = 0.75 + 0.25 * math.sin(time * 10)
	love.graphics.setColor(1, 0.95, 0.55, 0.5)
	love.graphics.polygon("fill",
		BaseRadius * 0.75, 0,
		BaseRadius * (1.35 + 0.15 * pulse), -SEGMENT_SIZE * 0.34 * pulse,
		BaseRadius * (1.35 + 0.15 * pulse), SEGMENT_SIZE * 0.34 * pulse
	)
	love.graphics.setBlendMode("alpha")
	end

	love.graphics.setColor(1, 0.68, 0.2, 0.22 + 0.4 * intensity)
	local sparks = 6
	for i = 1, sparks do
	local offset = time * (data.active and 7 or 3.5) + (i / sparks) * math.pi * 2
	local inner = BaseRadius * 0.5
	local outer = BaseRadius * (1.1 + 0.1 * math.sin(time * 4 + i))
	love.graphics.setLineWidth(1.25)
	love.graphics.line(math.cos(offset) * inner, math.sin(offset) * inner, math.cos(offset) * outer, math.sin(offset) * outer)
	end

	love.graphics.pop()
end

function SnakeDraw.run(trail, SegmentCount, SEGMENT_SIZE, PopTimer, GetHead, ShieldCount, ShieldFlashTimer, UpgradeVisuals, DrawFace)
	local options
	if type(DrawFace) == "table" then
	options = DrawFace
	DrawFace = options.drawFace
	end

	if DrawFace == nil then
	DrawFace = true
	end

	if not trail or #trail == 0 then return end

	local thickness = SEGMENT_SIZE * 0.8
	local half      = thickness / 2

	local OverlayEffect = SnakeCosmetics:GetOverlayEffect()

	local coords = BuildCoords(trail)
	local head = trail[1]

	love.graphics.setLineStyle("smooth")
	love.graphics.setLineJoin("bevel") -- or "bevel" if you prefer fewer spikes

	local hx, hy
	if GetHead then
	hx, hy = GetHead()
	end
	if not (hx and hy) then
	hx, hy = PtXY(head)
	end

	if #coords >= 4 then
	-- render into a canvas once
	local ww, hh = love.graphics.getDimensions()
	EnsureSnakeCanvas(ww, hh)

	love.graphics.setCanvas(SnakeCanvas)
	love.graphics.clear(0,0,0,0)
	RenderSnakeToCanvas(trail, coords, head, half, options)
	love.graphics.setCanvas()
	PresentSnakeCanvas(OverlayEffect, ww, hh)
	elseif hx and hy then
	-- fallback: draw a simple disk when only the head is visible
	local BodyColor = SnakeCosmetics:GetBodyColor()
	local OutlineColor = SnakeCosmetics:GetOutlineColor()
	local OutlineR = OutlineColor[1] or 0
	local OutlineG = OutlineColor[2] or 0
	local OutlineB = OutlineColor[3] or 0
	local OutlineA = OutlineColor[4] or 1
	local BodyR = BodyColor[1] or 1
	local BodyG = BodyColor[2] or 1
	local BodyB = BodyColor[3] or 1
	local BodyA = BodyColor[4] or 1

	local ww, hh = love.graphics.getDimensions()
	EnsureSnakeCanvas(ww, hh)

	love.graphics.setCanvas(SnakeCanvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(OutlineR, OutlineG, OutlineB, OutlineA)
	love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
	love.graphics.setColor(BodyR, BodyG, BodyB, BodyA)
	love.graphics.circle("fill", hx, hy, half)
	love.graphics.setCanvas()

	PresentSnakeCanvas(OverlayEffect, ww, hh)
	end

        if hx and hy and DrawFace ~= false then
        if UpgradeVisuals and UpgradeVisuals.temporalAnchor then
                DrawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, UpgradeVisuals.temporalAnchor)
        end

        if UpgradeVisuals and UpgradeVisuals.timeDilation then
                DrawTimeDilationAura(hx, hy, SEGMENT_SIZE, UpgradeVisuals.timeDilation)
        end

        if UpgradeVisuals and UpgradeVisuals.adrenaline then
                DrawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, UpgradeVisuals.adrenaline)
        end

        if UpgradeVisuals and UpgradeVisuals.quickFangs then
                DrawQuickFangsAura(hx, hy, SEGMENT_SIZE, UpgradeVisuals.quickFangs)
        end

        if UpgradeVisuals and UpgradeVisuals.dash then
                DrawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, UpgradeVisuals.dash)
        end

	local FaceScale = 1
	Face:draw(hx, hy, FaceScale)

        DrawShieldBubble(hx, hy, SEGMENT_SIZE, ShieldCount, ShieldFlashTimer)

        if UpgradeVisuals and UpgradeVisuals.dash then
                DrawDashStreaks(trail, SEGMENT_SIZE, UpgradeVisuals.dash)
        end

        if UpgradeVisuals and UpgradeVisuals.eventHorizon then
                DrawEventHorizonSheath(trail, SEGMENT_SIZE, UpgradeVisuals.eventHorizon)
        end

        if UpgradeVisuals and UpgradeVisuals.stormchaser then
                DrawStormchaserCurrent(trail, SEGMENT_SIZE, UpgradeVisuals.stormchaser)
        end

        if UpgradeVisuals and UpgradeVisuals.chronospiral then
                DrawChronospiralWake(trail, SEGMENT_SIZE, UpgradeVisuals.chronospiral)
        end

        if UpgradeVisuals and UpgradeVisuals.abyssalCatalyst then
                DrawAbyssalCatalystVeil(trail, SEGMENT_SIZE, UpgradeVisuals.abyssalCatalyst)
        end

        if UpgradeVisuals and UpgradeVisuals.titanblood then
                DrawTitanbloodSigils(trail, SEGMENT_SIZE, UpgradeVisuals.titanblood)
        end

        if UpgradeVisuals and UpgradeVisuals.phoenixEcho then
                DrawPhoenixEchoTrail(trail, SEGMENT_SIZE, UpgradeVisuals.phoenixEcho)
        end

        if UpgradeVisuals and UpgradeVisuals.stonebreaker then
                DrawStonebreakerAura(hx, hy, SEGMENT_SIZE, UpgradeVisuals.stonebreaker)
        end
        end

	-- POP EFFECT
	if PopTimer and PopTimer > 0 and hx and hy then
	local t = 1 - (PopTimer / POP_DURATION)
	if t < 1 then
		local pulse = 0.8 + 0.4 * math.sin(t * math.pi)
		love.graphics.setColor(1, 1, 1, 0.4)
		love.graphics.circle("fill", hx, hy, thickness * 0.6 * pulse)
	end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return SnakeDraw
