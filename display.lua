local Display = {}

local DisplayModes = { "fullscreen", "windowed" }

local resolutions = {
	{ id = "1280x720", width = 1280, height = 720 },
	{ id = "1280x800", width = 1280, height = 800, NoteKey = "settings.resolution_note_steam_deck" },
	{ id = "1366x768", width = 1366, height = 768 },
	{ id = "1600x900", width = 1600, height = 900 },
	{ id = "1920x1080", width = 1920, height = 1080 },
	{ id = "2560x1440", width = 2560, height = 1440 },
}

local ResolutionIndex = {}
for index, res in ipairs(resolutions) do
	ResolutionIndex[res.id] = index
end

local function WrapIndex(index, count)
	return ((index - 1) % count) + 1
end

function Display.GetDisplayModes()
	return DisplayModes
end

function Display.CycleDisplayMode(current, delta)
	delta = delta or 1
	local count = #DisplayModes
	if count == 0 then
		return current
	end

	local CurrentIndex = 1
	for i, mode in ipairs(DisplayModes) do
		if mode == current then
			CurrentIndex = i
			break
		end
	end

	local NewIndex = WrapIndex(CurrentIndex + delta, count)
	return DisplayModes[NewIndex]
end

function Display.GetResolution(id)
	if id and ResolutionIndex[id] then
		return resolutions[ResolutionIndex[id]]
	end

	return resolutions[1]
end

function Display.GetResolutionLabel(localization, id)
	local entry = Display.GetResolution(id)
	local label = string.format("%d x %d", entry.width, entry.height)

	if entry.noteKey and localization and localization.get then
		local note = localization:get(entry.noteKey)
		if note and note ~= "" then
			label = string.format("%s (%s)", label, note)
		end
	end

	return label
end

function Display.GetDefaultResolutionId()
	return resolutions[1].id
end

function Display.CycleResolution(CurrentId, delta)
	delta = delta or 1
	local count = #resolutions
	if count == 0 then
		return CurrentId
	end

	local CurrentIndex = ResolutionIndex[CurrentId] or 1
	local NewIndex = WrapIndex(CurrentIndex + delta, count)
	return resolutions[NewIndex].id
end

function Display.ensure(settings)
	local changed = false

	if not settings.displayMode or (settings.displayMode ~= "fullscreen" and settings.displayMode ~= "windowed") then
		settings.displayMode = "fullscreen"
		changed = true
	end

	if not settings.resolution or not ResolutionIndex[settings.resolution] then
		settings.resolution = Display.GetDefaultResolutionId()
		changed = true
	end

	if type(settings.vsync) ~= "boolean" then
		settings.vsync = true
		changed = true
	end

	return changed
end

function Display.apply(settings)
	if not love.window then
		return
	end

	local _, _, flags = love.window.getMode()
	flags = flags or {}

	local mode = (settings.displayMode == "windowed") and "windowed" or "fullscreen"

	local width, height
	if mode == "fullscreen" then
		width, height = 0, 0
		flags.fullscreen = true
		flags.fullscreentype = "desktop"
	else
		local res = Display.GetResolution(settings.resolution)
		width, height = res.width, res.height
		flags.fullscreen = false
		flags.fullscreentype = nil
		flags.resizable = true
	end

	if settings.vsync == false then
		flags.vsync = 0
	else
		flags.vsync = 1
	end

	love.window.setMode(width, height, flags)
end

return Display
