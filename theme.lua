local Theme = {
	-- Arena
	arenaBG      = {0.18, 0.18, 0.22, 1.0},
	arenaBorder  = {0.35, 0.30, 0.50, 1.0},

	-- General background / chrome
	bgColor        = {0.07, 0.08, 0.11, 1.0},
	menuBackgroundColor = {0.14, 0.12, 0.12},
	shopBackgroundColor = {0.08, 0.06, 0.12, 1.0},
	shadowColor    = {0.0, 0.0, 0.0, 0.25},
	highlightColor = {1.0, 1.0, 1.0, 0.06},

	-- Buttons
	buttonColor = {0.32, 0.27, 0.40, 1.0},
	buttonHover = {0.38, 0.32, 0.48, 1.0},
	buttonPress = {0.26, 0.22, 0.32, 1.0},
	borderColor     = {0.42, 0.72, 0.62, 1.0},

	-- Panels
	panelColor      = {0.32, 0.27, 0.40, 1.0},
	panelBorder     = {0.32, 0.50, 0.54, 1.0},

	-- Darts
	dartBaseColor      = {0.17, 0.18, 0.23, 0.98},
	dartAccentColor    = {0.42, 0.72, 0.62, 1.0},
	dartTelegraphColor = {0.52, 0.78, 0.72, 0.78},
	dartBodyColor      = {0.70, 0.68, 0.60, 1.0},
	dartTipColor       = {0.82, 0.86, 0.90, 1.0},
	dartTailColor      = {0.42, 0.68, 0.64, 1.0},

	-- Text
	textColor = {0.90, 0.90, 0.92, 1.0},
	mutedTextColor  = {0.70, 0.72, 0.78, 1.0},
	accentTextColor = {0.82, 0.92, 0.78, 1.0},

	-- State / feedback colours
	lockedCardColor = {0.50, 0.35, 0.40, 1.0},
	achieveColor    = {0.80, 0.45, 0.65, 1.0},
	progressColor   = {0.55, 0.75, 0.55, 1.0},
	warningColor    = {0.92, 0.55, 0.40, 1.0},

	-- Gameplay
	snakeDefault    = {0.45, 0.85, 0.70, 1.0},

	-- Fruits / pickups
	appleColor       = {0.90, 0.45, 0.55, 1.0},
	bananaColor      = {0.90, 0.85, 0.55, 1.0},
	blueberryColor   = {0.55, 0.65, 0.95, 1.0},
	goldenPearColor  = {0.95, 0.80, 0.45, 1.0},
	dragonfruitColor = {0.90, 0.60, 0.80, 1.0},

	-- Obstacles
	sawColor         = {0.65, 0.65, 0.70, 1.0},
	rock             = {0.30, 0.30, 0.35, 1.0},
}

local function copyTable(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[key] = item
	end

	return copy
end

local defaults = {}
for key, value in pairs(Theme) do
	defaults[key] = copyTable(value)
end

function Theme.reset()
	for key in pairs(Theme) do
		if key ~= "reset" then
			Theme[key] = nil
		end
	end

	for key, value in pairs(defaults) do
		Theme[key] = copyTable(value)
	end
end

return Theme