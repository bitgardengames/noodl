local Display = {}

local displayModes = { "fullscreen", "windowed" }

local resolutions = {
	{ id = "1280x720", width = 1280, height = 720 },
	{ id = "1280x800", width = 1280, height = 800, noteKey = "settings.resolution_note_steam_deck" },
	{ id = "1366x768", width = 1366, height = 768 },
	{ id = "1600x900", width = 1600, height = 900 },
	{ id = "1920x1080", width = 1920, height = 1080 },
	{ id = "2560x1440", width = 2560, height = 1440 },
}

local resolutionIndex = {}
for index, res in ipairs(resolutions) do
	resolutionIndex[res.id] = index
end

local function wrapIndex(index, count)
	return ((index - 1) % count) + 1
end

function Display.getDisplayModes()
	return displayModes
end

function Display.cycleDisplayMode(current, delta)
	delta = delta or 1
	local count = #displayModes
	if count == 0 then
		return current
	end

	local currentIndex = 1
	for i, mode in ipairs(displayModes) do
		if mode == current then
			currentIndex = i
			break
		end
	end

	local newIndex = wrapIndex(currentIndex + delta, count)
	return displayModes[newIndex]
end

function Display.getResolution(id)
	if id and resolutionIndex[id] then
		return resolutions[resolutionIndex[id]]
	end

	return resolutions[1]
end

function Display.getResolutionLabel(localization, id)
	local entry = Display.getResolution(id)
	local label = string.format("%d x %d", entry.width, entry.height)

	if entry.noteKey and localization and localization.get then
		local note = localization:get(entry.noteKey)
		if note and note ~= "" then
			label = string.format("%s (%s)", label, note)
		end
	end

	return label
end

function Display.getDefaultResolutionId()
	return resolutions[1].id
end

function Display.cycleResolution(currentId, delta)
	delta = delta or 1
	local count = #resolutions
	if count == 0 then
		return currentId
	end

	local currentIndex = resolutionIndex[currentId] or 1
	local newIndex = wrapIndex(currentIndex + delta, count)
	return resolutions[newIndex].id
end

function Display.ensure(settings)
	local changed = false

	if not settings.displayMode or (settings.displayMode ~= "fullscreen" and settings.displayMode ~= "windowed") then
		settings.displayMode = "fullscreen"
		changed = true
	end

	if not settings.resolution or not resolutionIndex[settings.resolution] then
		settings.resolution = Display.getDefaultResolutionId()
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
		local res = Display.getResolution(settings.resolution)
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
