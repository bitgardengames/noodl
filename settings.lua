local DEFAULTS = {
    musicVolume = 0.5,
    sfxVolume = 1.0,
    muteMusic = false,
    muteSFX = false,
    language = "english",
    displayMode = "fullscreen",
    resolution = "1280x720",
    vsync = true,
    screenShake = true,
    bloodEnabled = true,
    showFPS = false,
}

local Settings = {}

for key, value in pairs(DEFAULTS) do
    Settings[key] = value
end

local saveFile = "user_settings.lua"

local function serializeSettings(tbl)
    local keys = {}
    for key in pairs(tbl) do
        if DEFAULTS[key] ~= nil then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)

    local buffer = {"{\n"}
    for _, key in ipairs(keys) do
        local value = tbl[key]
        local encodedValue

        if type(value) == "string" then
            encodedValue = string.format("%q", value)
        elseif type(value) == "boolean" or type(value) == "number" then
            encodedValue = tostring(value)
        else
            local defaultValue = DEFAULTS[key]
            tbl[key] = defaultValue
            if type(defaultValue) == "string" then
                encodedValue = string.format("%q", defaultValue)
            else
                encodedValue = tostring(defaultValue)
            end
        end

        buffer[#buffer + 1] = string.format("    [%q] = %s,\n", key, encodedValue)
    end

    buffer[#buffer + 1] = "}"
    return table.concat(buffer)
end

function Settings:load()
    if not love.filesystem.getInfo(saveFile) then
        local Display = require("display")
        if Display.ensure then
            Display.ensure(Settings)
        end
        return
    end

    local chunkOk, chunk = pcall(love.filesystem.load, saveFile)
    if not chunkOk or type(chunk) ~= "function" then
        return
    end

    local callOk, loaded = pcall(chunk)
    if not callOk or type(loaded) ~= "table" then
        return
    end

    for key, value in pairs(loaded) do
        if DEFAULTS[key] ~= nil and type(value) == type(DEFAULTS[key]) then
            Settings[key] = value
        end
    end

    local Display = require("display")
    if Display.ensure then
        if Display.ensure(Settings) then
            Settings:save()
        end
    end
end

function Settings:save()
    local data = "return " .. serializeSettings(Settings)
    return love.filesystem.write(saveFile, data)
end

return Settings
