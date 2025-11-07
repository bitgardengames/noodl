local SharedCanvas = require("sharedcanvas")

local Display = {}

local floor = math.floor

local displayModes = {"fullscreen", "windowed"}

local msaaLevels = {0, 2, 4, 6, 8}

local resolutions = {
	{id = "1280x720", width = 1280, height = 720},
	{id = "1280x800", width = 1280, height = 800, noteKey = "settings.resolution_note_steam_deck"},
	{id = "1366x768", width = 1366, height = 768},
	{id = "1600x900", width = 1600, height = 900},
	{id = "1920x1080", width = 1920, height = 1080},
	{id = "2560x1440", width = 2560, height = 1440},
}

local resolutionIndex = {}
for index, res in ipairs(resolutions) do
	resolutionIndex[res.id] = index
end

local function wrapIndex(index, count)
	return ((index - 1) % count) + 1
end

local function getMaximumMSAASupport()
	local maxSamples = SharedCanvas.getMaximumSupportedSamples and SharedCanvas.getMaximumSupportedSamples() or 0
	if type(maxSamples) ~= "number" then
		maxSamples = 0
	end

	if maxSamples < 0 then
		maxSamples = 0
	end

	local maxAllowed = msaaLevels[#msaaLevels] or 0
	if maxSamples > maxAllowed then
		maxSamples = maxAllowed
	end

	return maxSamples
end

local function getAvailableMSAALevels()
	local maxSamples = getMaximumMSAASupport()
	local available = {0}

	if maxSamples >= 2 then
		for i = 2, #msaaLevels do
			local level = msaaLevels[i]
			if level <= maxSamples then
				available[#available + 1] = level
			end
		end
	end

	return available
end

local function resolveMSAALevel(value)
	local numeric = tonumber(value) or 0
	if numeric < 0 then
		numeric = 0
	end

	numeric = floor(numeric)

	local available = getAvailableMSAALevels()
	local resolved = available[1] or 0

	for _, level in ipairs(available) do
		if level <= numeric then
			resolved = level
		end
	end

	return resolved
end

local function getAvailableMSAAIndex(value)
	local available = getAvailableMSAALevels()
	local resolved = resolveMSAALevel(value)

	for index, level in ipairs(available) do
		if level == resolved then
			return index, available
		end
	end

	return 1, available
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

	local resolvedMSAA = resolveMSAALevel(settings.msaaSamples)
	if settings.msaaSamples ~= resolvedMSAA then
		settings.msaaSamples = resolvedMSAA
		changed = true
	end

	SharedCanvas.setDesiredSamples(settings.msaaSamples)

	return changed
end

function Display.apply(settings)
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

	local msaa = resolveMSAALevel(settings.msaaSamples)
	if settings.msaaSamples ~= msaa then
		settings.msaaSamples = msaa
	end

	if msaa >= 2 then
		flags.msaa = msaa
	else
		flags.msaa = 0
	end

	love.window.setMode(width, height, flags)

	local _, _, appliedFlags = love.window.getMode()
	if type(appliedFlags) == "table" then
		local appliedMSAA = resolveMSAALevel(appliedFlags.msaa or 0)
		if appliedMSAA ~= settings.msaaSamples then
			settings.msaaSamples = appliedMSAA
		end
	end

	SharedCanvas.setDesiredSamples(settings.msaaSamples)
end

function Display.cycleMSAASamples(current, delta)
	delta = delta or 1

	local currentIndex, available = getAvailableMSAAIndex(current)
	local count = #available

	if count == 0 then
		return resolveMSAALevel(current)
	end

	local newIndex = wrapIndex(currentIndex + delta, count)
	return available[newIndex]
end

return Display