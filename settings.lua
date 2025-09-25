local Settings = {
    musicVolume = 0.5,
    sfxVolume   = 1.0,
    muteMusic   = false,
    muteSFX     = false,
}

local saveFile = "user_settings.lua"

function Settings:load()
    if love.filesystem.getInfo(saveFile) then
        local chunk = love.filesystem.load(saveFile)
        local loaded = chunk()
        if type(loaded) == "table" then
            for k, v in pairs(loaded) do
                Settings[k] = v
            end
        end
    end
end

function Settings:save()
    local data = "return " .. table.serialize(Settings)
    love.filesystem.write(saveFile, data)
end

function table.serialize(tbl)
    local str = "{\n"
    for k, v in pairs(tbl) do
        local key = string.format("[%q]", k)
        local value

        if type(v) == "string" then
            value = string.format("%q", v)
        elseif type(v) == "boolean" or type(v) == "number" then
            value = tostring(v)
        else
            value = "nil"
        end

        str = str .. string.format("    %s = %s,\n", key, value)
    end
    return str .. "}"
end

return Settings
