local SharedCanvas = require("sharedcanvas")

local CRTFilter = {
	enabled = true,
	time = 0,
	canvas = nil,
	shader = nil,
	curvature = 0.12,
	scanlineIntensity = 0.22,
	vignetteStrength = 0.55,
	noiseStrength = 0.035,
	chromaOffset = 1.2,
	maskStrength = 0.32,
}

local shaderSource = [[
extern vec2 resolution;
extern float time;
extern float curvature;
extern float scanlineIntensity;
extern float vignetteStrength;
extern float noiseStrength;
extern float chromaOffset;
extern float maskStrength;

float rand(vec2 co)
{
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233)) + time * 3.7) * 43758.5453);
}

vec2 applyCurvature(vec2 uv)
{
	vec2 coord = uv * 2.0 - 1.0;
	coord.x *= 1.0 + curvature * 0.5;
	coord.y *= 1.0 + curvature;
	return coord * 0.5 + 0.5;
}

vec3 sampleChromatic(Image tex, vec2 uv, float offset)
{
	vec2 pixelOffset = vec2(offset / resolution.x, 0.0);
	vec2 uvR = clamp(uv + pixelOffset, 0.0, 1.0);
	vec2 uvB = clamp(uv - pixelOffset, 0.0, 1.0);
	float r = Texel(tex, uvR).r;
	float g = Texel(tex, uv).g;
	float b = Texel(tex, uvB).b;
	return vec3(r, g, b);
}

vec3 slotMask(vec2 screen)
{
	float slot = mod(floor(screen.x), 3.0);
	vec3 mask = vec3(0.85);
	if (slot < 0.5) {
		mask = vec3(1.0, 0.7, 0.7);
	} else if (slot < 1.5) {
		mask = vec3(0.7, 1.0, 0.7);
	} else {
		mask = vec3(0.7, 0.7, 1.0);
	}
	return mask;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
	vec2 uv = applyCurvature(texture_coords);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		float edgeShade = clamp(1.0 - length((texture_coords - 0.5) * vec2(2.4, 2.0)), 0.0, 1.0);
		float glow = 0.02 + edgeShade * 0.12;
		return vec4(vec3(glow), 1.0) * color;
	}

	vec3 rgb = sampleChromatic(tex, uv, chromaOffset);

	float scan = sin((screen_coords.y + time * 120.0) * 3.14159);
	float scanMix = 1.0 - scanlineIntensity * (0.5 - 0.5 * scan);

	vec3 mask = mix(vec3(1.0), slotMask(screen_coords), maskStrength);

	vec2 dist = (uv - 0.5) * vec2(1.35, 1.1);
	float vignette = clamp(1.0 - dot(dist, dist), 0.0, 1.0);
	vignette = mix(1.0, pow(vignette, 1.6), vignetteStrength);

	float noise = rand(screen_coords + vec2(time * 45.0, time * 21.0)) * 2.0 - 1.0;
	rgb = rgb * scanMix * vignette * mask + noise * noiseStrength;
	rgb = clamp(rgb, 0.0, 1.0);

	float flicker = 1.0 + sin(time * 25.0) * 0.015;
	rgb *= flicker;

	return vec4(rgb, 1.0) * color;
}
]]

local function supportsShader()
	if not love.graphics or not love.graphics.isSupported then
		return false
	end

	if love.graphics.isSupported("canvas") ~= true then
		return false
	end

	return love.graphics.isSupported("shader") ~= false
end

local function releaseCanvas()
	if CRTFilter.canvas and CRTFilter.canvas.release then
		CRTFilter.canvas:release()
	end
	CRTFilter.canvas = nil
end

function CRTFilter.load()
	CRTFilter.time = 0

	if not supportsShader() then
		CRTFilter.enabled = false
		CRTFilter.shader = nil
		releaseCanvas()
		return
	end

	local ok, shader = pcall(love.graphics.newShader, shaderSource)
	if not ok then
		CRTFilter.enabled = false
		CRTFilter.shader = nil
		releaseCanvas()
		return
	end

	CRTFilter.enabled = true
	CRTFilter.shader = shader
	CRTFilter.resize()
end

function CRTFilter.resize()
	if not (CRTFilter.enabled and CRTFilter.shader) then
		releaseCanvas()
		return
	end

	local width, height = love.graphics.getDimensions()
	if width <= 0 or height <= 0 then
		return
	end

	local previous = CRTFilter.canvas
	local canvas, replaced = SharedCanvas.ensureCanvas(previous, width, height)
	if replaced and previous and previous ~= canvas and previous.release then
		previous:release()
	end

	CRTFilter.canvas = canvas
end

function CRTFilter.update(dt)
	if not (CRTFilter.enabled and CRTFilter.shader) then
		return
	end

	if type(dt) == "number" and dt > 0 then
		CRTFilter.time = (CRTFilter.time + dt) % 1000
	end
end

local function sendUniforms(canvas)
	if not (canvas and CRTFilter.shader) then
		return
	end

	CRTFilter.shader:send("resolution", {canvas:getWidth(), canvas:getHeight()})
	CRTFilter.shader:send("time", CRTFilter.time)
	CRTFilter.shader:send("curvature", CRTFilter.curvature)
	CRTFilter.shader:send("scanlineIntensity", CRTFilter.scanlineIntensity)
	CRTFilter.shader:send("vignetteStrength", CRTFilter.vignetteStrength)
	CRTFilter.shader:send("noiseStrength", CRTFilter.noiseStrength)
	CRTFilter.shader:send("chromaOffset", CRTFilter.chromaOffset)
	CRTFilter.shader:send("maskStrength", CRTFilter.maskStrength)
end

function CRTFilter.draw(drawFunc)
	if type(drawFunc) ~= "function" then
		return
	end

	if not (CRTFilter.enabled and CRTFilter.shader) then
		drawFunc()
		return
	end

	CRTFilter.resize()
	local canvas = CRTFilter.canvas
	if not canvas then
		drawFunc()
		return
	end

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	drawFunc()
	love.graphics.setCanvas()
	love.graphics.pop()

	love.graphics.push("all")
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(CRTFilter.shader)
	sendUniforms(canvas)
	love.graphics.draw(canvas, 0, 0)
	love.graphics.setShader()
	love.graphics.pop()
end

return CRTFilter
