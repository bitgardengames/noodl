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
    comboPulseTarget = 0,
    eventPulse = 0,
    eventPulseTarget = 0,
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
                reactiveState.comboPulseTarget = math.min((reactiveState.comboPulseTarget or 0) + 0.35, 0.9)
            end
        else
            reactiveState.comboTarget = 0
        end

        reactiveState.lastCombo = combo
    elseif event == "comboLost" then
        reactiveState.comboTarget = 0
        reactiveState.comboPulseTarget = 0
        reactiveState.lastCombo = 0
    elseif event == "specialEvent" then
        local strength = math.max((data and data.strength) or 0.7, 0)
        local color = (data and data.color) or EVENT_COLORS[(data and data.type) or ""]
        reactiveState.eventPulseTarget = math.min((reactiveState.eventPulseTarget or 0) + strength * 0.6, 1.5)
        if color then
            assignEventColor(color)
        end
    end
end

function Shaders.update(dt)
    if not dt or dt <= 0 then
        return
    end

    local smoothing = math.min(dt * 4.2, 1)
    reactiveState.comboDisplay = lerp(reactiveState.comboDisplay, reactiveState.comboTarget, smoothing)
    reactiveState.comboPulseTarget = math.max(0, (reactiveState.comboPulseTarget or 0) - dt * 1.35)
    reactiveState.eventPulseTarget = math.max(0, (reactiveState.eventPulseTarget or 0) - dt * 1.1)

    local pulseSmoothing = math.min(dt * 6.5, 1)
    reactiveState.comboPulse = lerp(reactiveState.comboPulse, reactiveState.comboPulseTarget or 0, pulseSmoothing)
    reactiveState.eventPulse = lerp(reactiveState.eventPulse, reactiveState.eventPulseTarget or 0, pulseSmoothing)

    local colorFade = math.min(dt * 1.6, 1)
    reactiveState.eventColor[1] = lerp(reactiveState.eventColor[1], 1, colorFade)
    reactiveState.eventColor[2] = lerp(reactiveState.eventColor[2], 1, colorFade)
    reactiveState.eventColor[3] = lerp(reactiveState.eventColor[3], 1, colorFade)
    reactiveState.eventColor[4] = 1
end

local function computeReactiveResponse()
    local comboValue = reactiveState.comboDisplay or 0
    local comboStrength = 0
    if comboValue >= 2 then
        comboStrength = math.min((comboValue - 1.5) / 8.0, 1.0)
    end

    local comboPulse = reactiveState.comboPulse or 0
    local eventPulse = reactiveState.eventPulse or 0

    local boost = comboStrength * 0.25 + comboPulse * 0.18 + eventPulse * 0.32
    boost = math.max(0, math.min(boost, 0.65))

    local tintBlend = math.min(0.25, eventPulse * 0.25 + comboStrength * 0.15)
    local eventColor = reactiveState.eventColor or WHITE
    local tint = {
        lerp(1, eventColor[1] or 1, tintBlend),
        lerp(1, eventColor[2] or 1, tintBlend),
        lerp(1, eventColor[3] or 1, tintBlend),
        1,
    }

    return 1 + boost, comboStrength, comboPulse, eventPulse, tint, boost
end

local function drawShader(effect, x, y, w, h, intensity, sendUniforms, drawOptions)
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

    local radiusX, radiusY = 0, 0
    if drawOptions then
        if drawOptions.radiusX or drawOptions.radiusY then
            radiusX = drawOptions.radiusX or drawOptions.radius or 0
            radiusY = drawOptions.radiusY or drawOptions.radius or 0
        elseif drawOptions.radius then
            radiusX = drawOptions.radius
            radiusY = drawOptions.radius
        end
    end

    love.graphics.push("all")
    love.graphics.setShader(shader)
    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    love.graphics.rectangle("fill", x, y, w, h, radiusX, radiusY)
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
            float colorPulse = sin((uv.x + uv.y) * 4.6 + time * 0.45) * 0.5 + 0.5;

            vec3 base = mix(baseColor.rgb, fogColor.rgb, ceiling * 0.58 + mist * 0.42);
            float highlight = clamp((shimmer * 0.38 + 0.16) * intensity, 0.0, 1.0);
            vec3 col = mix(base, glintColor.rgb, highlight * 0.62);

            vec3 accent = mix(glintColor.rgb, fogColor.rgb, 0.28);
            col = mix(col, accent, colorPulse * 0.22 * intensity);

            float ambient = clamp(0.18 + intensity * 0.32, 0.0, 0.48);
            col = mix(col, mix(fogColor.rgb, glintColor.rgb, 0.22), ambient);

            float depth = smoothstep(0.0, 0.4, uv.y);
            col = mix(col, baseColor.rgb, depth * 0.06);

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
            float causticA = sin((uv.x * 7.2 + uv.y * 2.8) + time * 0.35) * 0.5 + 0.5;
            float causticB = sin((uv.x * 5.1 - uv.y * 5.4) - time * 0.28) * 0.5 + 0.5;
            float caustics = clamp((causticA * 0.6 + causticB * 0.4), 0.0, 1.0);

            vec3 gradient = mix(baseColor.rgb, deepColor.rgb, depth * 0.7);
            float highlight = clamp((wave * 0.38 + shafts * 0.26 + caustics * 0.36 + 0.12) * intensity, 0.0, 1.0);
            vec3 col = mix(gradient, foamColor.rgb, highlight * 0.42);

            float ambient = clamp(0.12 + intensity * 0.3, 0.0, 0.42);
            vec3 undertow = mix(foamColor.rgb, deepColor.rgb, 0.58);
            col = mix(col, undertow, ambient * 0.9);

            float seam = 1.0 - smoothstep(0.0, 0.18, abs(uv.y - 0.4));
            vec3 seamColor = mix(foamColor.rgb, baseColor.rgb, 0.35);
            col = mix(col, seamColor, seam * caustics * 0.24 * intensity);

            float vignette = smoothstep(0.42, 1.0, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, vignette * 0.28);

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

-- Holographic overlay for high-rarity shop cards
registerEffect({
    type = "cardHologram",
    backdropIntensity = 1.0,
    arenaIntensity = 1.0,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 accentColor;
        extern vec4 sparkleColor;
        extern vec4 rimColor;
        extern float intensity;
        extern float parallax;
        extern float scanOffset;

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

            vec3 col = mix(baseColor.rgb, accentColor.rgb, holo * intensity);

            float sweep = smoothstep(-0.25, 0.85, uv.y + sin(time * 0.6 + parallax * 0.3) * 0.1);
            float shimmer = sin((uv.x + uv.y) * 18.0 + time * 2.4);
            float sparkleMix = clamp(sweep * 0.35 + (shimmer * 0.15 + 0.15), 0.0, 1.0);
            col = mix(col, sparkleColor.rgb, sparkleMix * intensity);

            vec2 grid = floor((uv + vec2(time * 0.05, scanOffset)) * vec2(18.0, 26.0));
            float sparkSeed = hash(grid + floor(time * 1.2));
            float spark = smoothstep(0.7, 1.0, sparkSeed) * (1.0 - radius) * intensity;
            col += sparkleColor.rgb * spark * 0.4;

            float scan = sin((uv.y + scanOffset - time * 0.8) * 20.0) * 0.5 + 0.5;
            col += sparkleColor.rgb * scan * 0.08 * intensity;

            float rim = smoothstep(0.55, 0.95, 1.0 - radius);
            col = mix(col, rimColor.rgb, rim * (0.3 + 0.4 * intensity));

            col = mix(baseColor.rgb, col, 0.82);
            col = clamp(col, 0.0, 1.0);

            return vec4(col, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette, effectData)
        local shader = effect.shader

        local base = getColorComponents(palette and (palette.baseColor or palette.bgColor), Theme.bgColor)
        local accent = getColorComponents(palette and (palette.accentColor or palette.primary), Theme.buttonHover)
        local sparkle = getColorComponents(palette and (palette.sparkleColor or palette.highlightColor), Theme.accentTextColor)
        local rim = getColorComponents(palette and (palette.rimColor or palette.edgeColor), Theme.borderColor)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "accentColor", accent)
        sendColor(shader, "sparkleColor", sparkle)
        sendColor(shader, "rimColor", rim)

        local parallax = effectData and effectData.parallax or 0
        local scanOffset = effectData and effectData.scanOffset or 0

        sendFloat(shader, "parallax", parallax)
        sendFloat(shader, "scanOffset", scanOffset)
    end,
    draw = function(effect, x, y, w, h, intensity)
        return drawShader(effect, x, y, w, h, intensity, nil, { radius = 12 })
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
-- Luminescent spores and cap halos for Mushroom Grotto
registerEffect({
    type = "mushroomPulse",
    backdropIntensity = 0.92,
    arenaIntensity = 0.58,
    source = [[
        extern float time;
        extern vec2 resolution;
        extern vec2 origin;
        extern vec4 baseColor;
        extern vec4 cavernColor;
        extern vec4 capColor;
        extern vec4 glowColor;
        extern vec4 sporeColor;
        extern float intensity;

        float capGlow(vec2 uv, vec2 center, vec2 scale, float sharpness)
        {
            vec2 diff = (uv - center) * scale;
            float d = dot(diff, diff);
            return exp(-d * sharpness);
        }

        float sporeTrail(vec2 uv, vec2 dir, float speed, float phase)
        {
            vec2 n = normalize(dir);
            float wave = sin(dot(uv, n) * 12.0 + time * speed + phase);
            return wave * 0.5 + 0.5;
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = (screen_coords - origin) / resolution;
            uv = clamp(uv, 0.0, 1.0);

            vec2 centered = uv - vec2(0.5);
            float aspect = resolution.x / max(resolution.y, 0.0001);
            centered.x *= aspect;

            float grottoRise = smoothstep(-0.4, 1.1, centered.y + 0.15 * sin(time * 0.18 + centered.x * 2.4));
            float mycelium = smoothstep(-0.6, 0.2, centered.y + 0.05 * sin(time * 0.25 + centered.x * 6.0));

            vec3 cave = mix(baseColor.rgb, cavernColor.rgb, grottoRise);

            float drift = time * 0.3;
            vec2 capA = vec2(0.32 + 0.05 * sin(drift * 0.7), 0.62 + 0.04 * sin(drift * 0.5));
            vec2 capB = vec2(0.68 + 0.07 * sin(drift * 0.9 + 1.1), 0.57 + 0.05 * sin(drift * 0.6 + 0.9));
            vec2 capC = vec2(0.48 + 0.05 * sin(drift * 0.8 - 2.1), 0.74 + 0.06 * sin(drift * 0.4 - 1.4));

            float haloA = capGlow(uv, capA, vec2(3.6, 6.0), 3.2);
            float haloB = capGlow(uv, capB, vec2(4.2, 5.4), 2.9);
            float haloC = capGlow(uv, capC, vec2(3.8, 6.8), 3.4);

            float haloBlend = clamp(haloA * (0.45 + intensity * 0.3) + haloB * (0.4 + intensity * 0.25) + haloC * (0.36 + intensity * 0.3), 0.0, 1.2);

            vec3 caps = mix(cave, capColor.rgb, clamp(haloBlend * (0.65 + intensity * 0.25), 0.0, 1.0));
            vec3 glow = mix(capColor.rgb, glowColor.rgb, clamp(haloBlend * (0.35 + intensity * 0.5), 0.0, 1.0));

            vec2 swirlDir1 = normalize(vec2(0.8, 0.6));
            vec2 swirlDir2 = normalize(vec2(-0.7, 0.5));
            float sporesA = sporeTrail(centered, swirlDir1, 1.4, 0.8);
            float sporesB = sporeTrail(centered + vec2(0.1, 0.05), swirlDir2, 1.1, -1.2);
            float sporesC = sporeTrail(centered + vec2(-0.08, -0.02), swirlDir1 * vec2(-1.0, 1.0), 1.7, 2.6);

            float sporeVeil = clamp((sporesA * 0.35 + sporesB * 0.32 + sporesC * 0.28) * (0.7 + intensity * 0.45), 0.0, 1.0);
            vec3 sporeTint = mix(glowColor.rgb, sporeColor.rgb, clamp(0.25 + sporesB * 0.5, 0.0, 1.0));

            float pulse = sin(time * 0.6 + haloBlend * 4.0) * 0.5 + 0.5;
            float myceliumGlow = clamp(mycelium * (0.3 + intensity * 0.5), 0.0, 0.6);

            vec3 layered = cave;
            layered = mix(layered, caps, clamp(haloBlend, 0.0, 1.0));
            layered = mix(layered, glow, clamp(pulse * haloBlend, 0.0, 0.8));
            layered = mix(layered, sporeTint, sporeVeil * 0.6);
            layered = mix(layered, glowColor.rgb, myceliumGlow);

            float vignette = smoothstep(0.2, 0.85, length(centered));
            layered = mix(layered, cave, clamp(vignette, 0.0, 0.8));

            return vec4(layered, baseColor.a) * color;
        }
    ]],
    configure = function(effect, palette)
        local shader = effect.shader

        local base = getColorComponents(palette and palette.bgColor, Theme.bgColor)
        local cavern = getColorComponents(palette and palette.arenaBG, Theme.arenaBG)
        local caps = getColorComponents(palette and palette.arenaBorder, Theme.arenaBorder)
        local glow = getColorComponents(palette and (palette.sawColor or palette.snake), Theme.sawColor)
        local spores = getColorComponents(palette and (palette.snake or palette.sawColor), Theme.snakeDefault)

        sendColor(shader, "baseColor", base)
        sendColor(shader, "cavernColor", cavern)
        sendColor(shader, "capColor", caps)
        sendColor(shader, "glowColor", glow)
        sendColor(shader, "sporeColor", spores)
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

            float rise = smoothstep(0.05, 0.95, uv.y);
            float drift = time * 0.08;
            float scroll = uv.y + drift;
            float ribbons = sin((uv.x * 3.5 + scroll * 3.0) - time * 0.45);
            float shimmer = sin((uv.x * 6.0 - uv.y * 1.5) + time * 0.6);
            float sway = sin(time * 0.1) * 0.12;
            float glowBand = smoothstep(0.1 + sway, 0.85 + sway, uv.y);

            float ember = rise * 0.55 + ribbons * 0.18 + shimmer * 0.12;
            ember = clamp(ember * (0.55 + intensity * 0.45), 0.0, 1.0);

            vec3 baseWarm = mix(baseColor.rgb, emberColor.rgb, rise * 0.35);
            vec3 emberGlow = mix(emberColor.rgb, glowColor.rgb, clamp(ember * 0.6 + glowBand * 0.25, 0.0, 1.0));
            vec3 col = mix(baseWarm, emberGlow, clamp(ember * 0.65 + glowBand * 0.25, 0.0, 1.0));

            float haze = smoothstep(0.2, 0.95, glowBand);
            col = mix(col, glowColor.rgb, haze * 0.12);

            float vignette = smoothstep(0.25, 0.8, distance(uv, vec2(0.5)));
            col = mix(col, baseColor.rgb, vignette * 0.4);

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
-- Radiant fabric of light for the shop screen
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

            float ribbonFlow = sin((uv.x * 3.2 + uv.y * 2.6) - time * 0.45);
            float swirl = sin(atan(centered.y, centered.x) * 4.0 - time * 0.28 + radius * 3.5);
            float drift = noise(uv * 3.5 + time * 0.1);

            float ribbonLayer = clamp(ribbonFlow * 0.45 + swirl * 0.3 + drift * 0.6, -1.0, 1.0) * 0.5 + 0.5;
            float halo = exp(-radius * radius * 4.0);
            float verticalGlow = smoothstep(0.15, 0.95, uv.y + sin(time * 0.16 + uv.x * 1.4) * 0.05);

            float accentMix = clamp((ribbonLayer * 0.6 + halo * 0.25 + verticalGlow * 0.2) * intensity, 0.0, 1.0);
            vec3 col = mix(baseColor.rgb, accentColor.rgb, accentMix);

            float sparkleField = noise(uv * 12.0 + time * 0.6);
            float sparkle = smoothstep(0.72, 1.0, sparkleField) * (0.35 + 0.25 * intensity);

            float glowPulse = sin(time * 0.22) * 0.5 + 0.5;
            float glowAmount = clamp((halo * (0.55 + glowPulse * 0.35) + verticalGlow * 0.3 + sparkle * 0.5) * intensity, 0.0, 1.0);
            col = mix(col, glowColor.rgb, glowAmount);

            float weave = noise(uv * vec2(22.0, 18.0) + vec2(0.0, time * 0.35));
            col = mix(col, baseColor.rgb, (0.18 + 0.1 * (1.0 - ribbonLayer)) * (1.0 - weave));

            col = mix(baseColor.rgb, col, 0.82);
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

            vec2 baseUv = uv;
            float breath = sin(time * 0.24) * 0.5 + 0.5;
            breath = breath * breath * (3.0 - 2.0 * breath);
            float pixelBlend = breath * 0.55 * intensity;
            vec2 pixelDensity = mix(vec2(120.0, 72.0), vec2(36.0, 22.0), breath);
            vec2 pixelatedUv = floor(baseUv * pixelDensity) / pixelDensity;
            uv = mix(baseUv, pixelatedUv, pixelBlend);

            float drift = sin(uv.y * 3.0 + time * 0.18);
            float pulse = sin((uv.x * 6.0 + uv.y * 4.0) - time * 0.24);

            float sparkle = 0.0;
            vec2 grid = floor(uv * vec2(18.0, 10.0));
            float n = hash(grid + floor(time * 0.35));
            float sparklePhase = fract(time * 0.28 + n);
            float sparkleFadeIn = smoothstep(0.0, 0.35, sparklePhase);
            float sparkleFadeOut = 1.0 - smoothstep(0.55, 0.9, sparklePhase);
            sparkle = clamp(sparkleFadeIn * sparkleFadeOut, 0.0, 1.0);
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
