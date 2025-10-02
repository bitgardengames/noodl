local Theme = require("theme")

local Shaders = {}

local function getColorComponents(color, fallback)
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

local function shaderHasUniform(shader, name)
    if not shader or not shader.hasUniform then
        return true
    end

    return shader:hasUniform(name)
end

local function sendColor(shader, name, color)
    if shaderHasUniform(shader, name) then
        shader:sendColor(name, color)
    end
end

local function sendVec2(shader, name, value)
    if shaderHasUniform(shader, name) then
        shader:send(name, value)
    end
end

local function sendFloat(shader, name, value)
    if shaderHasUniform(shader, name) then
        shader:send(name, value)
    end
end

local function drawShader(effect, x, y, w, h, intensity, sendUniforms)
    if not (effect and effect.shader) then
        return false
    end

    if w <= 0 or h <= 0 then
        return false
    end

    local shader = effect.shader
    local actualIntensity = intensity or 1.0

    if shaderHasUniform(shader, "origin") then
        shader:send("origin", {x, y})
    end

    if shaderHasUniform(shader, "resolution") then
        shader:send("resolution", {w, h})
    end

    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0

    if shaderHasUniform(shader, "time") then
        shader:send("time", now)
    end

    if shaderHasUniform(shader, "intensity") then
        shader:send("intensity", actualIntensity)
    end

    if sendUniforms then
        sendUniforms(shader, now, x, y, w, h, actualIntensity)
    end

    love.graphics.push("all")
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.pop()

    return true
end

local effectDefinitions = {}

local function registerEffect(def)
    effectDefinitions[def.type] = def
end
-- Forest canopy shimmer for lush floors
registerEffect({
    type = "forestCanopy",
    backdropIntensity = 0.65,
    arenaIntensity = 0.38,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 lightColor;
        extern vec4 accentColor;
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

            vec3 col = baseColor.rgb;

            float canopyLight = smoothstep(0.35, 0.0, uv.y);
            col = mix(col, lightColor.rgb, canopyLight * 0.3 * intensity);

            for (int i = 0; i < 3; ++i)
            {
                float fi = float(i);
                float density = 3.0 + fi * 2.2;
                float speed = 0.05 + fi * 0.035;
                float size = 0.22 - fi * 0.05;
                float layerStrength = 0.22 + fi * 0.1;

                vec2 grid = (uv + vec2(0.0, time * speed)) * density;
                vec2 cell = floor(grid);
                vec2 cellUV = fract(grid);
                vec2 rand = hash2(cell + fi * 17.0);

                float d = distance(cellUV, rand);
                float particle = exp(-d * d / (size * size + 1e-5));

                vec3 glowColor = mix(lightColor.rgb, accentColor.rgb, 0.35 + fi * 0.25);
                col = mix(col, glowColor, clamp(particle * layerStrength * intensity, 0.0, 1.0));
            }

            float vignette = smoothstep(0.95, 0.45, distance(uv, vec2(0.5)));
            col = mix(baseColor.rgb, col, clamp(vignette, 0.0, 1.0));

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local light = getColorComponents(palette and palette.arenaBorder, Theme.arenaBorder)
        local accent = getColorComponents(palette and palette.snake, Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "lightColor", light)
        sendColor(shader, "accentColor", accent)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Cool cavern mist and echoing shimmer
registerEffect({
    type = "echoMist",
    backdropIntensity = 0.7,
    arenaIntensity = 0.4,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 mistColor;
        extern vec4 accentColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float waveA = sin(uv.y * 4.2 - time * 0.2);
            float waveB = sin((uv.x + uv.y) * 5.0 + time * 0.15);
            float layering = mix(waveA, waveB, 0.5);
            float depth = smoothstep(0.0, 1.0, uv.y);
            float mist = clamp((layering * 0.25 + 0.5) * intensity, 0.0, 1.0);
            float glimmer = clamp((sin(uv.x * 10.0 + time * 0.4) * 0.15 + 0.5) * intensity * 0.5, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, mistColor.rgb, mist * 0.7);
            col = mix(col, accentColor.rgb, glimmer * (0.3 + depth * 0.2));

            float fade = smoothstep(0.0, 0.6, uv.y);
            col = mix(baseColor.rgb, col, clamp(fade + 0.15, 0.0, 1.0));

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local mist = getColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.arenaBorder)
        local accent = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "mistColor", mist)
        sendColor(shader, "accentColor", accent)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Mushroom pulse shader (existing behaviour)
registerEffect({
    type = "mushroomPulse",
    backdropIntensity = 1.0,
    arenaIntensity = 0.68,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 glowColor;
        extern float intensity;

        float bloomShape(vec2 p, vec2 center, float sharpness)
        {
            vec2 diff = p - center;
            float distSq = dot(diff, diff);
            return exp(-distSq * sharpness);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            vec2 centered = uv - vec2(0.5);

            float aspect = resolution.x / max(resolution.y, 0.0001);
            centered.x *= aspect;

            float dist = length(centered);

            float breathing = sin(time * 0.6) * 0.5 + 0.5;
            float drift = time * 0.35;

            vec2 offset1 = vec2(cos(drift), sin(drift * 0.8)) * (0.18 + 0.08 * intensity);
            vec2 offset2 = vec2(cos(drift * 1.3 + 2.2), sin(drift * 0.9 + 1.4)) * (0.26 + 0.1 * intensity);
            vec2 offset3 = vec2(cos(drift * 0.7 - 1.1), sin(drift * 1.1 - 2.4)) * (0.32 + 0.12 * intensity);

            float sharp1 = 10.0 - intensity * 2.0;
            float sharp2 = 7.5 - intensity * 1.5;
            float sharp3 = 5.0 - intensity;

            float bloom1 = bloomShape(centered, offset1, sharp1);
            float bloom2 = bloomShape(centered, offset2, sharp2);
            float bloom3 = bloomShape(centered, offset3, sharp3);

            float combinedBloom = bloom1 * (0.55 + 0.25 * intensity);
            combinedBloom += bloom2 * (0.45 + 0.3 * breathing * intensity);
            combinedBloom += bloom3 * (0.35 + 0.25 * intensity);

            float petalWave = sin((centered.x + centered.y) * 6.0 + time * 0.5);
            float waveMix = clamp(petalWave * 0.5 + 0.5, 0.0, 1.0) * (0.25 + 0.35 * intensity);

            vec3 base = baseColor.rgb;
            vec3 accent = mix(base, accentColor.rgb, 0.7);
            vec3 glow = mix(accentColor.rgb, glowColor.rgb, 0.6);

            float accentMix = clamp(combinedBloom, 0.0, 1.0);
            float glowMix = clamp(combinedBloom * 0.6 + waveMix, 0.0, 1.0);

            vec3 colorBlend = mix(base, accent, accentMix);
            colorBlend = mix(colorBlend, glow, glowMix);

            float innerEdge = max(0.12, 0.28 - 0.1 * intensity);
            float outerEdge = min(0.96, 0.82 + 0.12 * intensity);
            float vignette = 1.0 - smoothstep(innerEdge, outerEdge, dist + breathing * 0.1 * intensity);

            vec3 finalColor = mix(base, colorBlend, clamp(vignette, 0.0, 1.0));

            return vec4(finalColor, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local accent = getColorComponents(palette and palette.arenaBorder, Theme.arenaBorder)
        local glow = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "glowColor", glow)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Gentle tidal movement for waterlogged floors
registerEffect({
    type = "tidalCurrent",
    backdropIntensity = 0.8,
    arenaIntensity = 0.5,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 deepColor;
        extern vec4 foamColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float wave = sin((uv.x + time * 0.15) * 3.5);
            float wave2 = sin((uv.x * 4.0 - uv.y * 2.0) + time * 0.12);
            float ripple = (wave * 0.6 + wave2 * 0.4) * 0.5 + 0.5;

            float depth = smoothstep(0.0, 1.0, uv.y);

            vec3 layer = mix(baseColor.rgb, deepColor.rgb, depth * 0.8 + ripple * 0.2 * intensity);
            vec3 foam = mix(deepColor.rgb, foamColor.rgb, clamp(ripple * 0.5 + 0.5, 0.0, 1.0));
            vec3 col = mix(layer, foam, 0.25 * intensity);

            float vignette = 1.0 - smoothstep(0.35, 0.9, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, (1.0 - vignette) * 0.6);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local deep = getColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.arenaBorder)
        local foam = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "deepColor", deep)
        sendColor(shader, "foamColor", foam)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Ember drift for warm and ashen floors
registerEffect({
    type = "emberDrift",
    backdropIntensity = 0.7,
    arenaIntensity = 0.42,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 emberColor;
        extern vec4 glowColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float drift = time * 0.12;
            float trail = fract(uv.y + drift);
            float sparks = sin((uv.x + trail * 2.5) * 12.0);
            float flicker = sin((uv.x * 10.0) + time * 0.4);
            float motes = clamp(sin((uv.y + time * 0.3) * 6.0 + uv.x * 2.0) * 0.2 + 0.5, 0.0, 1.0);
            float ember = clamp((sparks * 0.2 + flicker * 0.1 + motes) * intensity, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, emberColor.rgb, ember * 0.6);
            col = mix(col, glowColor.rgb, ember * 0.3);

            float vignette = 1.0 - smoothstep(0.45, 0.95, distance(uv, vec2(0.5)));
            col = mix(baseColor.rgb, col, vignette);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local ember = getColorComponents(palette and (palette.rock or palette.arenaBorder), Theme.rock)
        local glow = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "emberColor", ember)
        sendColor(shader, "glowColor", glow)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Aurora veil for crystalline and celestial floors
registerEffect({
    type = "auroraVeil",
    backdropIntensity = 0.65,
    arenaIntensity = 0.4,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 auroraPrimary;
        extern vec4 auroraSecondary;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float wave = sin((uv.x * 4.0 + time * 0.12) + sin(uv.y * 3.0) * 0.5);
            float wave2 = sin((uv.x * 6.0 - uv.y * 2.0) - time * 0.08);
            float band = clamp((wave * 0.35 + wave2 * 0.25) * intensity + 0.5, 0.0, 1.0);
            float vertical = smoothstep(0.0, 1.0, uv.y);

            vec3 col = mix(baseColor.rgb, auroraPrimary.rgb, band * 0.7);
            col = mix(col, auroraSecondary.rgb, band * 0.5 * (0.4 + vertical * 0.6));
            float glow = smoothstep(0.1, 0.9, band) * 0.3;
            col += auroraSecondary.rgb * glow * 0.2;
            col = mix(baseColor.rgb, col, 0.6 + 0.3 * band);
            col = clamp(col, 0.0, 1.0);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local primary = getColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.arenaBorder)
        local secondary = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "auroraPrimary", primary)
        sendColor(shader, "auroraSecondary", secondary)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Void pulse for deep abyssal floors
registerEffect({
    type = "voidPulse",
    backdropIntensity = 0.75,
    arenaIntensity = 0.48,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 rimColor;
        extern vec4 pulseColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float dist = distance(uv, vec2(0.5));
            float pulse = sin(dist * 6.0 - time * 0.7) * 0.5 + 0.5;
            float slow = sin(time * 0.25) * 0.5 + 0.5;
            float rim = smoothstep(0.25, 0.85, dist);

            vec3 col = mix(baseColor.rgb, pulseColor.rgb, pulse * intensity * (1.0 - rim));
            col = mix(col, rimColor.rgb, (1.0 - rim) * 0.35 + slow * 0.15 * intensity);

            float vignette = smoothstep(0.4, 0.95, dist);
            col = mix(col, baseColor.rgb, clamp(vignette, 0.0, 1.0));

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local rim = getColorComponents(palette and (palette.arenaBorder or palette.rock), Theme.arenaBorder)
        local pulse = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "rimColor", rim)
        sendColor(shader, "pulseColor", pulse)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Gentle aurora for main menu ambiance
registerEffect({
    type = "menuBreeze",
    backdropIntensity = 0.58,
    arenaIntensity = 0.36,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 highlightColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float wave = sin((uv.x + uv.y) * 5.0 + time * 0.2);
            float drift = sin(uv.x * 8.0 - time * 0.12);
            float ribbon = smoothstep(0.15, 0.85, uv.y + wave * 0.05);
            float sparkle = sin((uv.x * 10.0 + uv.y * 6.0) + time * 0.6);
            sparkle = clamp(sparkle * 0.5 + 0.5, 0.0, 1.0);
            sparkle = smoothstep(0.6, 1.0, sparkle);

            float accentMix = clamp(0.35 + wave * 0.12 + drift * 0.08 + ribbon * 0.25, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, accentMix * intensity);
            col = mix(col, highlightColor.rgb, sparkle * 0.18 * intensity);
            col = mix(baseColor.rgb, col, 0.8);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.buttonHover)
        local highlight = getColorComponents(palette and (palette.highlightColor or palette.secondary), Theme.accentTextColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "highlightColor", highlight)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Soft bloom for a calm, floral main menu ambiance
registerEffect({
    type = "menuBloom",
    backdropIntensity = 0.64,
    arenaIntensity = 0.38,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 petalColor;
        extern vec4 highlightColor;
        extern float intensity;

        float hash(vec2 p)
        {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            vec2 centered = uv - 0.5;
            float dist = length(centered);

            float pulse = sin(time * 0.35) * 0.5 + 0.5;
            float bloom = 1.0 - smoothstep(0.12, 0.58, dist + pulse * 0.06);

            float angle = atan(centered.y, centered.x);
            float petals = cos(angle * 6.0 + time * 0.12);
            float petalMask = clamp(1.0 - smoothstep(0.1, 0.46, dist + petals * 0.05), 0.0, 1.0);

            float drift = sin((uv.x + uv.y * 0.6) * 4.2 - time * 0.25) * 0.5 + 0.5;
            float gradient = smoothstep(-0.08, 0.72, uv.y + drift * 0.08);

            float sparkleSeed = hash(floor(uv * vec2(24.0, 16.0)) + floor(time * 0.5));
            float sparkle = smoothstep(0.72, 1.0, sparkleSeed) * bloom * 0.35;

            vec3 col = mix(baseColor.rgb, petalColor.rgb, (bloom * 0.6 + petalMask * 0.35) * intensity);
            col = mix(col, highlightColor.rgb, clamp(bloom * 0.3 + gradient * 0.2 + sparkle * 0.5, 0.0, 1.0) * intensity);
            col = mix(baseColor.rgb, col, 0.85);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local petal = getColorComponents(palette and (palette.accentColor or palette.buttonHover), Theme.buttonHover)
        local highlight = getColorComponents(palette and (palette.highlightColor or palette.accentTextColor), Theme.accentTextColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "petalColor", petal)
        sendColor(shader, "highlightColor", highlight)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Shimmering highlights for the shop screen
registerEffect({
    type = "shopGlimmer",
    backdropIntensity = 0.68,
    arenaIntensity = 0.42,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 glowColor;
        extern float intensity;

        float hash(vec2 p)
        {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        float shimmer(vec2 uv, float t)
        {
            vec2 grid = floor(uv * vec2(16.0, 9.0));
            float cell = hash(grid + floor(t * 0.7));
            float pulse = fract(t * 0.9 + cell);
            return smoothstep(0.8, 1.0, 1.0 - pulse);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);
            vec2 centered = uv - vec2(0.5);

            float radius = length(centered);
            float angle = atan(centered.y, centered.x);

            float radialWave = sin(radius * 14.0 - time * 0.9);
            float angularWave = sin(angle * 6.0 + time * 0.6);
            float mixWave = radialWave * 0.35 + angularWave * 0.45;

            float innerGlow = smoothstep(0.0, 0.65, 1.0 - radius);
            float band = clamp(mixWave * 0.5 + 0.5, 0.0, 1.0);

            float drift = sin((uv.x + uv.y) * 6.0 - time * 0.25) * 0.5 + 0.5;
            float highlight = shimmer(uv + vec2(time * 0.04, -time * 0.02), time);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, band * intensity);
            col = mix(col, glowColor.rgb, (innerGlow * 0.4 + drift * 0.25) * intensity);
            col += glowColor.rgb * highlight * 0.25 * intensity;

            col = mix(baseColor.rgb, col, 0.85);
            col = clamp(col, 0.0, 1.0);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.edgeColor), Theme.borderColor)
        local glow = getColorComponents(palette and (palette.glowColor or palette.highlightColor), Theme.accentTextColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "glowColor", glow)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Directional ribbons for mode selection energy
registerEffect({
    type = "modeRibbon",
    backdropIntensity = 0.52,
    arenaIntensity = 0.34,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 edgeColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float diag = sin((uv.x - uv.y) * 6.0 + time * 0.4);
            float sweep = sin(uv.y * 9.0 + time * 0.7);
            float stripes = abs(sin((uv.x + uv.y * 0.5) * 12.0 - time * 0.3));
            float ribbon = clamp(diag * 0.5 + 0.5, 0.0, 1.0);
            float stripeGlow = smoothstep(0.55, 0.95, 1.0 - stripes);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, (0.25 + ribbon * 0.45 + sweep * 0.15) * intensity);
            col = mix(col, edgeColor.rgb, stripeGlow * 0.28 * intensity);
            col = mix(baseColor.rgb, col, 0.82);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.borderColor)
        local edge = getColorComponents(palette and (palette.edgeColor or palette.secondary), Theme.progressColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "edgeColor", edge)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Sparkle field for achievements showcase
registerEffect({
    type = "achievementGlimmer",
    backdropIntensity = 0.56,
    arenaIntensity = 0.32,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 sparkleColor;
        extern float intensity;

        float hash(vec2 p)
        {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float drift = sin(uv.y * 3.0 + time * 0.18);
            float pulse = sin((uv.x * 6.0 + uv.y * 4.0) - time * 0.24);

            float sparkle = 0.0;
            vec2 grid = floor(uv * vec2(18.0, 10.0));
            float n = hash(grid + floor(time * 0.5));
            float sparklePhase = fract(time * 0.6 + n);
            sparkle = smoothstep(0.85, 1.0, 1.0 - sparklePhase);
            sparkle *= smoothstep(0.0, 1.0, pulse * 0.5 + 0.5);

            float accentMix = clamp(0.3 + drift * 0.18 + pulse * 0.12, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, accentMix * intensity);
            col = col + sparkleColor.rgb * sparkle * 0.35 * intensity;
            col = mix(baseColor.rgb, col, 0.88);
            col = clamp(col, 0.0, 1.0);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.achieveColor)
        local sparkle = getColorComponents(palette and (palette.sparkleColor or palette.secondary), Theme.accentTextColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "sparkleColor", sparkle)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Flowing orbitals for metaprogression overview
registerEffect({
    type = "metaFlux",
    backdropIntensity = 0.6,
    arenaIntensity = 0.38,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 primaryColor;
        extern vec4 secondaryColor;
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

            float primaryMix = clamp(0.28 + wave * 0.18 + halo * 0.3, 0.0, 1.0);
            float secondaryMix = clamp(pulse * 0.5 + 0.5, 0.0, 1.0) * 0.35;

            vec3 col = mix(baseColor.rgb, primaryColor.rgb, primaryMix * intensity);
            col = mix(col, secondaryColor.rgb, secondaryMix * intensity);
            col = mix(baseColor.rgb, col, 0.85);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local primary = getColorComponents(palette and (palette.primaryColor or palette.accentColor), Theme.progressColor)
        local secondary = getColorComponents(palette and (palette.secondaryColor or palette.highlightColor), Theme.accentTextColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "primaryColor", primary)
        sendColor(shader, "secondaryColor", secondary)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Soft scanlines for settings clarity
registerEffect({
    type = "settingsScan",
    backdropIntensity = 0.5,
    arenaIntensity = 0.3,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 lineColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float scan = sin((uv.y * 12.0) + time * 0.8);
            float lines = smoothstep(0.2, 0.8, scan * 0.5 + 0.5);
            float shimmer = sin((uv.x + uv.y) * 8.0 - time * 0.25);
            shimmer = clamp(shimmer * 0.5 + 0.5, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, (0.2 + lines * 0.35) * intensity);
            col = mix(col, lineColor.rgb, shimmer * 0.18 * intensity);
            col = mix(baseColor.rgb, col, 0.82);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.borderColor)
        local lines = getColorComponents(palette and (palette.lineColor or palette.secondary), Theme.progressColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "lineColor", lines)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
-- Radiant afterglow for game over reflection
registerEffect({
    type = "afterglowPulse",
    backdropIntensity = 0.62,
    arenaIntensity = 0.4,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 pulseColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);
            vec2 centered = uv - vec2(0.5);

            float dist = length(centered);
            float pulse = sin(time * 0.6 - dist * 9.0) * 0.5 + 0.5;
            float ring = smoothstep(0.18, 0.5, dist) - smoothstep(0.5, 0.85, dist);
            ring = clamp(ring, 0.0, 1.0);
            float fade = smoothstep(1.0, 0.0, dist);

            vec3 col = mix(baseColor.rgb, accentColor.rgb, (0.28 + pulse * 0.4 + ring * 0.25) * intensity);
            col = mix(col, pulseColor.rgb, ring * 0.6 * intensity);
            col = mix(baseColor.rgb, col, fade);
            col = clamp(col, 0.0, 1.0);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.warningColor)
        local pulse = getColorComponents(palette and (palette.pulseColor or palette.secondary), Theme.progressColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "pulseColor", pulse)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
local function createEffect(def)
    local shader = love.graphics.newShader(def.source)

    local defaultBackdrop = def.backdropIntensity or 1.0
    local defaultArena = def.arenaIntensity or 0.6

    local effect = {
        type = def.type,
        shader = shader,
        backdropIntensity = defaultBackdrop,
        arenaIntensity = defaultArena,
        defaultBackdropIntensity = defaultBackdrop,
        defaultArenaIntensity = defaultArena,
        definition = def,
    }

    return effect
end

function Shaders.ensure(cache, typeName)
    if not typeName then
        return nil
    end

    cache = cache or {}

    local effect = cache[typeName]
    if effect and effect.shader then
        return effect
    end

    local def = effectDefinitions[typeName]
    if not def then
        return nil
    end

    local ok, newEffect = pcall(createEffect, def)
    if not ok then
        return nil
    end

    cache[typeName] = newEffect
    return newEffect
end

function Shaders.configure(effect, palette, effectData)
    if not effect then
        return false
    end

    local def = effect.definition
    if not def then
        return false
    end

    if def.configure then
        def.configure(effect, palette, effectData)
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

function Shaders.getDefaultIntensities(effect)
    if not effect then
        return 1.0, 0.6
    end

    local backdrop = effect.defaultBackdropIntensity or effect.backdropIntensity or 1.0
    local arena = effect.defaultArenaIntensity or effect.arenaIntensity or 0.6

    return backdrop, arena
end

function Shaders.has(typeName)
    return effectDefinitions[typeName] ~= nil
end

return Shaders
