local DEFAULTS = {
	MusicVolume = 0.5,
	SfxVolume = 1.0,
	MuteMusic = false,
	MuteSFX = false,
	language = "english",
	DisplayMode = "fullscreen",
	resolution = "1280x720",
	vsync = true,
	ScreenShake = true,
	BloodEnabled = true,
	ShowFPS = false,
}

local Settings = {}

for key, value in pairs(DEFAULTS) do
	Settings[key] = value
end

local SaveFile = "user_settings.lua"

local function SerializeSettings(tbl)
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
		local EncodedValue

		if type(value) == "string" then
			EncodedValue = string.format("%q", value)
		elseif type(value) == "boolean" or type(value) == "number" then
			EncodedValue = tostring(value)
		else
			local DefaultValue = DEFAULTS[key]
			tbl[key] = DefaultValue
			if type(DefaultValue) == "string" then
				EncodedValue = string.format("%q", DefaultValue)
			else
				EncodedValue = tostring(DefaultValue)
			end
		end

		buffer[#buffer + 1] = string.format("    [%q] = %s,\n", key, EncodedValue)
	end

	buffer[#buffer + 1] = "}"
	return table.concat(buffer)
end

function Settings:load()
	if not love.filesystem.getInfo(SaveFile) then
		local Display = require("display")
		if Display.ensure then
			Display.ensure(Settings)
		end
		return
	end

	local ChunkOk, chunk = pcall(love.filesystem.load, SaveFile)
	if not ChunkOk or type(chunk) ~= "function" then
		return
	end

	local CallOk, loaded = pcall(chunk)
	if not CallOk or type(loaded) ~= "table" then
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
	local data = "return " .. SerializeSettings(Settings)
	return love.filesystem.write(SaveFile, data)
end

return Settings
