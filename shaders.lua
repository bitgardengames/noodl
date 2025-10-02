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

local function lerp(a, b, t)
    if not a then
        return b
    end

    return a + (b - a) * t
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

local WHITE = {1, 1, 1, 1}

local reactiveState = {
    comboTarget = 0,
    comboDisplay = 0,
    comboPulse = 0,
    eventPulse = 0,
    eventColor = {1, 1, 1, 1},
    lastCombo = 0,
}

local EVENT_COLORS = {
    combo = {1.0, 0.86, 0.45, 1},
    comboBoost = {1.0, 0.92, 0.55, 1},
    shield = {0.7, 0.98, 0.86, 1},
    stallSaws = {0.65, 0.82, 1.0, 1},
    score = {1.0, 0.72, 0.36, 1},
    dragonfruit = {1.0, 0.45, 0.28, 1},
}

local function assignEventColor(color)
    local components = getColorComponents(color, WHITE)
    reactiveState.eventColor[1] = components[1]
    reactiveState.eventColor[2] = components[2]
    reactiveState.eventColor[3] = components[3]
    reactiveState.eventColor[4] = components[4] or 1
end

function Shaders.notify(event, data)
    if event == "comboChanged" then
        local combo = math.max(0, (data and data.combo) or 0)
        if combo >= 2 then
            reactiveState.comboTarget = combo
            if combo > (reactiveState.lastCombo or 0) then
                reactiveState.comboPulse = math.min(reactiveState.comboPulse + 0.65, 1.4)
            end
        else
            reactiveState.comboTarget = 0
        end

        reactiveState.lastCombo = combo
    elseif event == "comboLost" then
        reactiveState.comboTarget = 0
        reactiveState.lastCombo = 0
    elseif event == "specialEvent" then
        local strength = math.max((data and data.strength) or 0.7, 0)
        local color = (data and data.color) or EVENT_COLORS[(data and data.type) or ""]
        reactiveState.eventPulse = math.min(reactiveState.eventPulse + strength, 2.4)
        if color then
            assignEventColor(color)
        end
    end
end

function Shaders.update(dt)
    if not dt or dt <= 0 then
        return
    end

    local smoothing = math.min(dt * 6, 1)
    reactiveState.comboDisplay = lerp(reactiveState.comboDisplay, reactiveState.comboTarget, smoothing)
    reactiveState.comboPulse = math.max(0, reactiveState.comboPulse - dt * 2.4)
    reactiveState.eventPulse = math.max(0, reactiveState.eventPulse - dt * 1.8)

    local colorFade = math.min(dt * 2.2, 1)
    reactiveState.eventColor[1] = lerp(reactiveState.eventColor[1], 1, colorFade)
    reactiveState.eventColor[2] = lerp(reactiveState.eventColor[2], 1, colorFade)
    reactiveState.eventColor[3] = lerp(reactiveState.eventColor[3], 1, colorFade)
    reactiveState.eventColor[4] = 1
end

local function computeReactiveResponse()
    local comboValue = reactiveState.comboDisplay or 0
    local comboStrength = 0
    if comboValue >= 2 then
        comboStrength = math.min((comboValue - 1.5) / 6.0, 1.0)
    end

    local comboPulse = reactiveState.comboPulse or 0
    local eventPulse = reactiveState.eventPulse or 0

    local boost = comboStrength * 0.45 + comboPulse * 0.3 + eventPulse * 0.55
    boost = math.max(0, math.min(boost, 1.2))

    local tintBlend = math.min(0.45, eventPulse * 0.4 + comboStrength * 0.25)
    local eventColor = reactiveState.eventColor or WHITE
    local tint = {
        lerp(1, eventColor[1] or 1, tintBlend),
        lerp(1, eventColor[2] or 1, tintBlend),
        lerp(1, eventColor[3] or 1, tintBlend),
        1,
    }

    return 1 + boost, comboStrength, comboPulse, eventPulse, tint, boost
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

    local intensityMultiplier, comboStrength, comboPulse, eventPulse, tint, boost = computeReactiveResponse()
    actualIntensity = actualIntensity * intensityMultiplier

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

    if shaderHasUniform(shader, "comboLevel") then
        shader:send("comboLevel", reactiveState.comboDisplay or 0)
    end

    if shaderHasUniform(shader, "comboStrength") then
        shader:send("comboStrength", comboStrength)
    end

    if shaderHasUniform(shader, "comboPulse") then
        shader:send("comboPulse", comboPulse)
    end

    if shaderHasUniform(shader, "eventPulse") then
        shader:send("eventPulse", eventPulse)
    end

    if shaderHasUniform(shader, "reactiveBoost") then
        shader:send("reactiveBoost", boost)
    end

    if shaderHasUniform(shader, "eventTint") then
        shader:sendColor("eventTint", tint)
    end

    if sendUniforms then
        sendUniforms(shader, now, x, y, w, h, actualIntensity)
    end

    love.graphics.push("all")
    love.graphics.setShader(shader)
    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.pop()

    return true
end

local effectDefinitions = {}

local function registerEffect(def)
    effectDefinitions[def.type] = def
end

-- Gentle canopy gradient for relaxed botanical floors
registerEffect({
    type = "softCanopy",
    backdropIntensity = 0.52,
    arenaIntensity = 0.3,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 canopyColor;
        extern vec4 glowColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float sway = sin((uv.x + time * 0.05) * 3.2) * 0.04;
            float canopy = smoothstep(0.18, 0.82, uv.y + sway);
            float lightBands = sin((uv.x * 5.0 + uv.y * 1.2) + time * 0.25) * 0.5 + 0.5;

            vec3 base = mix(baseColor.rgb, canopyColor.rgb, canopy * 0.65);
            float highlight = clamp(lightBands * 0.35 * intensity, 0.0, 1.0);
            vec3 col = mix(base, glowColor.rgb, highlight * 0.5);

            float vignette = smoothstep(0.45, 0.98, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, vignette * 0.45);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local canopy = getColorComponents(palette and palette.arenaBG, Theme.arenaBG)
        local glow = getColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.arenaBorder)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "canopyColor", canopy)
        sendColor(shader, "glowColor", glow)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})

-- Soft cavern haze with muted glints
registerEffect({
    type = "softCavern",
    backdropIntensity = 0.48,
    arenaIntensity = 0.28,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 fogColor;
        extern vec4 glintColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float ceiling = smoothstep(0.1, 0.7, uv.y + sin((uv.x * 3.5) + time * 0.18) * 0.04);
            float mist = smoothstep(0.0, 1.0, uv.y * 1.1);
            float shimmer = sin((uv.x * 6.0 - uv.y * 1.2) + time * 0.32) * 0.5 + 0.5;

            vec3 base = mix(baseColor.rgb, fogColor.rgb, ceiling * 0.55 + mist * 0.38);
            float highlight = clamp(shimmer * 0.32 * intensity, 0.0, 1.0);
            vec3 col = mix(base, glintColor.rgb, highlight * 0.5);

            float depth = smoothstep(0.0, 0.4, uv.y);
            col = mix(col, baseColor.rgb, depth * 0.12);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local fog = getColorComponents(palette and (palette.arenaBG or palette.rock), Theme.arenaBG)
        local glint = getColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.arenaBorder)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "fogColor", fog)
        sendColor(shader, "glintColor", glint)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})

-- Gentle tidal drift for calmer aquatic stages
registerEffect({
    type = "softCurrent",
    backdropIntensity = 0.56,
    arenaIntensity = 0.32,
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

            float depth = smoothstep(0.0, 1.0, uv.y);
            float wave = sin((uv.x * 3.6 - uv.y * 1.4) + time * 0.22) * 0.5 + 0.5;
            float shafts = sin((uv.y * 2.4) - time * 0.18) * 0.5 + 0.5;

            vec3 gradient = mix(baseColor.rgb, deepColor.rgb, depth * 0.75);
            float highlight = clamp((wave * 0.4 + shafts * 0.25) * intensity, 0.0, 1.0);
            vec3 col = mix(gradient, foamColor.rgb, highlight * 0.35);

            float vignette = smoothstep(0.42, 1.0, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, vignette * 0.4);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local deep = getColorComponents(palette and (palette.arenaBG or palette.rock), Theme.arenaBG)
        local foam = getColorComponents(palette and (palette.arenaBorder or palette.snake), Theme.arenaBorder)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "deepColor", deep)
        sendColor(shader, "foamColor", foam)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity)
    end,
})
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

            float canopyLight = smoothstep(0.55, 0.0, uv.y);
            col = mix(col, lightColor.rgb, canopyLight * 0.2 * intensity);

            float bloomMask = smoothstep(0.6, 0.18, distance(uv, vec2(0.5, 0.35)));
            vec3 bloomColor = mix(lightColor.rgb, accentColor.rgb, 0.25);
            col += bloomColor * bloomMask * 0.12 * intensity;

            for (int i = 0; i < 3; ++i)
            {
                float fi = float(i);
                float density = 2.6 + fi * 2.0;
                float speed = 0.04 + fi * 0.03;
                float size = 0.2 - fi * 0.045;
                float layerStrength = 0.18 + fi * 0.08;

                vec2 grid = (uv + vec2(0.0, time * speed)) * density;
                vec2 cell = floor(grid);
                vec2 cellUV = fract(grid);
                vec2 rand = hash2(cell + fi * 17.0);

                float d = distance(cellUV, rand);
                float particle = exp(-d * d / (size * size + 1e-5));

                vec3 glowColor = mix(lightColor.rgb, accentColor.rgb, 0.3 + fi * 0.22);
                float softness = smoothstep(0.0, 1.0, 1.0 - d * 1.3);
                float blend = clamp(particle * layerStrength * intensity * (0.6 + softness * 0.4), 0.0, 1.0);
                col = mix(col, glowColor, blend);
            }

            float vignette = smoothstep(0.92, 0.48, distance(uv, vec2(0.5)));
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
    backdropIntensity = 0.78,
    arenaIntensity = 0.5,
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

            float sharp1 = 8.4 - intensity * 1.6;
            float sharp2 = 6.1 - intensity * 1.2;
            float sharp3 = 4.1 - intensity * 0.8;

            float bloom1 = bloomShape(centered, offset1, sharp1);
            float bloom2 = bloomShape(centered, offset2, sharp2);
            float bloom3 = bloomShape(centered, offset3, sharp3);

            float combinedBloom = bloom1 * (0.4 + 0.22 * intensity);
            combinedBloom += bloom2 * (0.32 + 0.24 * breathing * intensity);
            combinedBloom += bloom3 * (0.24 + 0.2 * intensity);

            float petalWave = sin((centered.x + centered.y) * 6.0 + time * 0.5);
            float waveMix = clamp(petalWave * 0.5 + 0.5, 0.0, 1.0) * (0.18 + 0.28 * intensity);

            vec3 base = baseColor.rgb;
            vec3 accent = mix(base, accentColor.rgb, 0.55);
            vec3 glow = mix(accentColor.rgb, glowColor.rgb, 0.45);

            float accentMix = clamp(combinedBloom * 0.85, 0.0, 1.0);
            float glowMix = clamp(combinedBloom * 0.48 + waveMix * 0.85, 0.0, 1.0);

            vec3 colorBlend = mix(base, accent, accentMix);
            colorBlend = mix(colorBlend, glow, glowMix);

            float innerEdge = max(0.12, 0.28 - 0.1 * intensity);
            float outerEdge = min(0.96, 0.82 + 0.12 * intensity);
            float vignette = 1.0 - smoothstep(innerEdge, outerEdge, dist + breathing * 0.1 * intensity);

            float finalMix = clamp(vignette * 0.82 + 0.12, 0.0, 1.0);
            vec3 finalColor = mix(base, colorBlend, finalMix);

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
-- Dust motes and faint machinery glow for ancient ruins
registerEffect({
    type = "ruinMotes",
    backdropIntensity = 0.6,
    arenaIntensity = 0.34,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 dustColor;
        extern vec4 highlightColor;
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

            float dustAmount = clamp((motes * 0.6 + sparkle * 0.4) * intensity, 0.0, 1.0);

            vec3 col = mix(baseColor.rgb, dustColor.rgb, vertical * 0.3 + dustAmount * 0.25);
            col = mix(col, highlightColor.rgb, dustAmount * 0.2);

            float vignette = smoothstep(0.4, 0.95, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, vignette * 0.55);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local dust = getColorComponents(palette and (palette.rock or palette.arenaBorder), Theme.rock)
        local highlight = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "dustColor", dust)
        sendColor(shader, "highlightColor", highlight)
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
-- Soft morning light for the shop screen
registerEffect({
    type = "shopGlimmer",
    backdropIntensity = 0.54,
    arenaIntensity = 0.32,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 glowColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);
            vec2 centered = uv - vec2(0.5);

            float radius = length(centered);

            float gentleWave = sin(time * 0.35 + radius * 6.0) * 0.5 + 0.5;
            float sweep = smoothstep(-0.1, 0.45, uv.x + sin(time * 0.25) * 0.08);
            float vertical = smoothstep(0.05, 0.75, uv.y);

            float accentMix = clamp((gentleWave * 0.35 + sweep * 0.45) * intensity, 0.0, 1.0);
            vec3 col = mix(baseColor.rgb, accentColor.rgb, accentMix);

            float glow = exp(-radius * radius * 3.0);
            float breathe = sin(time * 0.2) * 0.5 + 0.5;
            float glowAmount = (glow * 0.4 + vertical * 0.2) * (0.4 + breathe * 0.3) * intensity;
            col = mix(col, glowColor.rgb, clamp(glowAmount, 0.0, 1.0));

            float subtleGrain = sin((uv.x + uv.y) * 18.0 + time * 0.1) * 0.5 + 0.5;
            col = mix(col, baseColor.rgb, 0.2 * (1.0 - subtleGrain));

            col = mix(baseColor.rgb, col, 0.75);
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
-- Simple gradient wash for mode selection
registerEffect({
    type = "modeGradient",
    backdropIntensity = 0.46,
    arenaIntensity = 0.28,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern float intensity;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            float vertical = smoothstep(0.0, 1.0, uv.y);
            float wave = sin((uv.x + time * 0.18) * 2.6) * 0.5 + 0.5;
            float mixAmount = clamp(vertical * 0.55 + wave * 0.25, 0.0, 1.0) * intensity;

            vec3 col = mix(baseColor.rgb, accentColor.rgb, mixAmount);
            col = mix(baseColor.rgb, col, 0.82);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.bgColor or palette.baseColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.progressColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
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
-- Gentle afterglow for game over reflection
registerEffect({
    type = "afterglowPulse",
    backdropIntensity = 0.52,
    arenaIntensity = 0.3,
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
            float fade = smoothstep(0.95, 0.15, dist);

            float breathe = sin(time * 0.25) * 0.5 + 0.5;

            vec3 col = mix(baseColor.rgb, accentColor.rgb, fade * 0.35 * intensity);

            float glow = exp(-dist * dist * 2.4);
            float outerGlow = smoothstep(0.5, 0.1, dist);
            float glowAmount = (glow * 0.55 + outerGlow * 0.25) * (0.45 + breathe * 0.35) * intensity;
            col = mix(col, pulseColor.rgb, clamp(glowAmount, 0.0, 1.0));

            float gentleSweep = smoothstep(-0.2, 0.7, dot(centered, normalize(vec2(0.4, 1.0))) + sin(time * 0.3) * 0.1);
            col = mix(col, accentColor.rgb, gentleSweep * 0.25 * intensity);

            float grain = sin((uv.x * 10.0 + uv.y * 8.0) + time * 0.15) * 0.5 + 0.5;
            col = mix(col, baseColor.rgb, 0.18 * (1.0 - grain));

            col = mix(baseColor.rgb, col, clamp(fade, 0.0, 1.0));
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
