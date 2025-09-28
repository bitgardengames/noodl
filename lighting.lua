-- Temporary stub for the snake lighting system.
-- Lighting visuals and updates are disabled, but we keep the module
-- interface so existing callers can safely require it.
local Lighting = {
    darkness = 0,
    lightRadius = 0,
    maxLights = 0,
    overlayMargin = 0,
    cachedSegments = {},
}

function Lighting:setFloorData()
    -- Lighting is disabled, so we just reset cached values.
    self.darkness = 0
    self.lightRadius = 0
    self.maxLights = 0
    self.cachedSegments = {}
end

function Lighting:getLightSources()
    -- Lighting is inactive, so there are no segment lights to render.
    return self.cachedSegments
end

function Lighting:update()
    -- No-op while lighting is disabled.
end

function Lighting:draw()
    -- Lighting visuals are disabled.
end

return Lighting
