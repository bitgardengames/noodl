local FloorShaders = {
    shader = nil,
    time = 0,
    activeDef = nil,
}

local shaderSource = [[
extern vec2 u_resolution;
extern float u_time;
extern vec4 u_gradient;
extern vec4 u_wave;
extern vec4 u_swirl;
extern vec4 u_rays;
extern vec4 u_misc;
extern vec3 u_tintA;
extern vec3 u_tintB;
extern float u_overlayScale;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 norm = screen_coords / u_resolution;
    vec2 centered = norm - 0.5;

    float gradientV = (0.5 - norm.y) * u_gradient.x;
    float gradientH = (norm.x - 0.5) * u_gradient.y;

    float wavePrimary = sin(norm.x * u_wave.x + u_time * u_wave.z) * u_wave.y;
    float waveSecondary = sin(norm.y * u_wave.w + u_time * (u_wave.z * 0.5)) * (u_wave.y * 0.5);

    float swirl = sin((norm.x + norm.y) * u_swirl.x + u_time * u_swirl.z) * u_swirl.y;
    float pulse = sin(u_time * u_misc.x) * u_swirl.w;

    float radius = length(centered);
    float angle = atan(centered.y, centered.x);
    float rayMask = 1.0 - smoothstep(u_rays.z, 1.1, radius);
    float rays = cos(angle * u_rays.y + u_time * u_rays.w) * u_rays.x * rayMask;

    float composite = clamp(gradientV + gradientH + wavePrimary + waveSecondary + swirl + pulse + rays, -1.5, 1.5);

    vec3 baseColor = color.rgb;
    float overlayScale = u_overlayScale;
    vec3 accent = u_tintA * composite * overlayScale;

    float highlightMask = 1.0 - smoothstep(0.0, u_misc.w, radius);
    vec3 highlight = u_tintB * highlightMask * u_misc.z * overlayScale;

    float grain = fract(sin(dot(norm + u_time * 0.05, vec2(12.9898, 78.233))) * 43758.5453);
    grain = (grain - 0.5) * u_misc.y * overlayScale;

    vec3 overlay = baseColor + accent + highlight + grain;

    float overlayStrength = clamp(u_gradient.w * overlayScale, 0.0, 1.0);
    vec3 finalColor = mix(baseColor, overlay, overlayStrength);

    float vignette = smoothstep(0.0, 1.0, radius);
    finalColor = mix(finalColor, baseColor, vignette * u_gradient.z);

    return vec4(finalColor, color.a);
}
]]

local function ensureShader(self)
    if not self.shader then
        self.shader = love.graphics.newShader(shaderSource)
    end
end

local function copyVector(values)
    if not values then return {0, 0, 0, 0} end
    return { values[1] or 0, values[2] or 0, values[3] or 0, values[4] or 0 }
end

local function copyVector3(values)
    if not values then return {0, 0, 0} end
    return { values[1] or 0, values[2] or 0, values[3] or 0 }
end

local function scaledVector(values, scale, indices)
    local result = copyVector(values)
    if scale ~= 1 and indices then
        for _, index in ipairs(indices) do
            if result[index] then
                result[index] = result[index] * scale
            end
        end
    end
    return result
end

FloorShaders.definitions = {
    [1] = {
        gradient = {0.25, 0.08, 0.35, 0.55},
        wave = {5.0, 0.06, 0.6, 2.5},
        swirl = {2.5, 0.05, 0.2, 0.04},
        rays = {0.12, 5.0, 0.35, 0.3},
        misc = {0.5, 0.02, 0.18, 0.6},
        tintA = {0.08, 0.18, 0.08},
        tintB = {0.32, 0.28, 0.12},
        overlay = 0.9,
        arenaScale = 0.65,
    },
    [2] = {
        gradient = {0.18, -0.05, 0.45, 0.4},
        wave = {3.5, 0.05, 0.3, 1.5},
        swirl = {1.8, 0.04, 0.25, 0.03},
        rays = {0.05, 7.0, 0.5, 0.15},
        misc = {0.35, 0.015, 0.08, 0.9},
        tintA = {0.1, 0.15, 0.25},
        tintB = {0.3, 0.4, 0.6},
        overlay = 0.65,
        arenaScale = 0.6,
    },
    [3] = {
        gradient = {0.12, 0.0, 0.35, 0.5},
        wave = {8.0, 0.07, 0.7, 4.5},
        swirl = {5.0, 0.08, 0.6, 0.08},
        rays = {0.06, 9.0, 0.45, 0.4},
        misc = {0.8, 0.025, 0.22, 0.5},
        tintA = {0.2, 0.3, 0.35},
        tintB = {0.4, 0.25, 0.55},
        overlay = 0.85,
        arenaScale = 0.7,
    },
    [4] = {
        gradient = {0.2, 0.05, 0.4, 0.55},
        wave = {10.0, 0.08, 0.9, 7.0},
        swirl = {3.0, 0.06, 0.5, 0.04},
        rays = {0.04, 6.0, 0.6, 0.25},
        misc = {0.6, 0.02, 0.12, 0.7},
        tintA = {0.1, 0.25, 0.28},
        tintB = {0.2, 0.45, 0.5},
        overlay = 0.8,
        arenaScale = 0.75,
    },
    [5] = {
        gradient = {0.16, 0.1, 0.5, 0.45},
        wave = {4.0, 0.04, 0.35, 2.0},
        swirl = {2.5, 0.03, 0.15, 0.02},
        rays = {0.03, 5.0, 0.7, 0.1},
        misc = {0.3, 0.03, 0.1, 0.95},
        tintA = {0.22, 0.18, 0.12},
        tintB = {0.35, 0.28, 0.15},
        overlay = 0.55,
        arenaScale = 0.6,
    },
    [6] = {
        gradient = {0.22, -0.06, 0.4, 0.6},
        wave = {9.0, 0.05, 0.8, 5.0},
        swirl = {4.5, 0.06, 0.7, 0.05},
        rays = {0.1, 11.0, 0.4, 0.55},
        misc = {0.7, 0.018, 0.2, 0.5},
        tintA = {0.15, 0.25, 0.4},
        tintB = {0.35, 0.55, 0.9},
        overlay = 0.85,
        arenaScale = 0.7,
    },
    [7] = {
        gradient = {0.1, 0.08, 0.45, 0.4},
        wave = {3.5, 0.035, 0.25, 1.8},
        swirl = {2.2, 0.03, 0.2, 0.02},
        rays = {0.025, 4.0, 0.75, 0.08},
        misc = {0.25, 0.028, 0.08, 0.9},
        tintA = {0.25, 0.2, 0.15},
        tintB = {0.5, 0.4, 0.25},
        overlay = 0.5,
        arenaScale = 0.6,
    },
    [8] = {
        gradient = {0.28, -0.02, 0.6, 0.6},
        wave = {5.0, 0.06, 0.35, 3.5},
        swirl = {6.5, 0.09, 0.45, 0.07},
        rays = {0.08, 8.0, 0.5, 0.2},
        misc = {0.55, 0.02, 0.16, 0.7},
        tintA = {0.25, 0.12, 0.35},
        tintB = {0.5, 0.3, 0.65},
        overlay = 0.75,
        arenaScale = 0.65,
    },
    [9] = {
        gradient = {0.22, 0.05, 0.4, 0.65},
        wave = {12.0, 0.08, 1.1, 6.5},
        swirl = {3.5, 0.06, 0.5, 0.06},
        rays = {0.12, 7.0, 0.45, 0.5},
        misc = {0.9, 0.035, 0.22, 0.6},
        tintA = {0.32, 0.12, 0.05},
        tintB = {0.8, 0.35, 0.1},
        overlay = 0.9,
        arenaScale = 0.7,
    },
    [10] = {
        gradient = {0.18, -0.08, 0.55, 0.7},
        wave = {7.0, 0.07, 0.9, 4.0},
        swirl = {5.0, 0.05, 0.65, 0.05},
        rays = {0.1, 10.0, 0.5, 0.35},
        misc = {0.75, 0.03, 0.24, 0.55},
        tintA = {0.28, 0.1, 0.08},
        tintB = {0.9, 0.4, 0.18},
        overlay = 0.85,
        arenaScale = 0.7,
    },
    [11] = {
        gradient = {0.2, 0.04, 0.5, 0.6},
        wave = {8.0, 0.06, 0.8, 3.5},
        swirl = {3.0, 0.04, 0.4, 0.04},
        rays = {0.06, 6.0, 0.6, 0.25},
        misc = {0.5, 0.035, 0.18, 0.75},
        tintA = {0.28, 0.15, 0.08},
        tintB = {0.65, 0.3, 0.12},
        overlay = 0.75,
        arenaScale = 0.65,
    },
    [12] = {
        gradient = {0.24, -0.04, 0.45, 0.7},
        wave = {6.0, 0.06, 0.6, 3.0},
        swirl = {7.5, 0.08, 0.7, 0.07},
        rays = {0.1, 9.0, 0.45, 0.45},
        misc = {0.65, 0.02, 0.25, 0.6},
        tintA = {0.28, 0.16, 0.45},
        tintB = {0.6, 0.4, 0.85},
        overlay = 0.85,
        arenaScale = 0.7,
    },
    [13] = {
        gradient = {0.26, 0.05, 0.55, 0.7},
        wave = {9.0, 0.07, 0.9, 5.5},
        swirl = {4.5, 0.05, 0.5, 0.06},
        rays = {0.11, 7.5, 0.5, 0.4},
        misc = {0.7, 0.04, 0.24, 0.65},
        tintA = {0.3, 0.08, 0.12},
        tintB = {0.75, 0.2, 0.2},
        overlay = 0.85,
        arenaScale = 0.7,
    },
    [14] = {
        gradient = {0.18, -0.12, 0.35, 0.65},
        wave = {5.5, 0.05, 0.45, 2.5},
        swirl = {2.8, 0.04, 0.35, 0.04},
        rays = {0.15, 12.0, 0.3, 0.5},
        misc = {0.45, 0.018, 0.22, 0.55},
        tintA = {0.2, 0.22, 0.3},
        tintB = {0.95, 0.75, 0.35},
        overlay = 0.8,
        arenaScale = 0.6,
    },
}

local gradientScaleIndices = {1, 2, 4}
local waveScaleIndices = {2}
local swirlScaleIndices = {2, 4}
local raysScaleIndices = {1}
local miscScaleIndices = {2, 3}

function FloorShaders:setFloor(index)
    self.activeDef = self.definitions[index]
    self.time = 0
    if self.activeDef then
        ensureShader(self)
        if self.shader then
            self.shader:send("u_time", self.time)
        end
    end
end

function FloorShaders:update(dt)
    if not self.activeDef or not self.shader then return end
    self.time = self.time + dt
    self.shader:send("u_time", self.time)
end

function FloorShaders:apply(area, width, height)
    if not self.activeDef or not self.shader then
        return false
    end

    self.shader:send("u_resolution", { width, height })

    local def = self.activeDef
    local overlayScale = def.overlay or 1
    if area == "arena" then
        overlayScale = overlayScale * (def.arenaScale or 0.7)
    end
    overlayScale = math.max(0, math.min(overlayScale, 1))

    local gradient = scaledVector(def.gradient, overlayScale, gradientScaleIndices)
    local wave = scaledVector(def.wave, overlayScale, waveScaleIndices)
    local swirl = scaledVector(def.swirl, overlayScale, swirlScaleIndices)
    local rays = scaledVector(def.rays, overlayScale, raysScaleIndices)
    local misc = scaledVector(def.misc, overlayScale, miscScaleIndices)

    self.shader:send("u_gradient", gradient)
    self.shader:send("u_wave", wave)
    self.shader:send("u_swirl", swirl)
    self.shader:send("u_rays", rays)
    self.shader:send("u_misc", misc)
    self.shader:send("u_tintA", copyVector3(def.tintA))
    self.shader:send("u_tintB", copyVector3(def.tintB))
    self.shader:send("u_overlayScale", overlayScale)

    love.graphics.setShader(self.shader)
    return true
end

function FloorShaders:clear()
    love.graphics.setShader()
end

return FloorShaders
