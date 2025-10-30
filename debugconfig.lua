local DebugConfig = {
        validateTrailLength = false,
}

local ok, overrides = pcall(require, "debugconfig_local")
if ok and type(overrides) == "table" then
        for key, value in pairs(overrides) do
                DebugConfig[key] = value
        end
end

return DebugConfig
