local Theme = {
	arenaBG      = {0.10, 0.14, 0.18, 1},
	arenaBorder  = {0.38, 0.44, 0.48, 1},

	bgColor             = {0.18, 0.19, 0.21, 1},
	menuBackgroundColor = {0.17, 0.21, 0.29, 1},
	shopBackgroundColor = {0.17, 0.21, 0.29, 1},

	shadowColor         = {0, 0, 0, 0.28},
	highlightColor      = {1, 1, 1, 0.06},

	buttonColor = {0.30, 0.38, 0.48, 1},
	buttonHover = {0.40, 0.52, 0.60, 1},
	buttonPress = {0.28, 0.34, 0.40, 1},
	borderColor = {0, 0, 0, 1},

	panelColor  = {0.16, 0.18, 0.20, 1},
	panelBorder = {0, 0, 0, 1},

	dartBaseColor      = {0.22, 0.24, 0.28, 1},
	dartAccentColor    = {0.88, 0.68, 0.22, 1},  -- harmonized (less orange)
	dartTelegraphColor = {0.88, 0.68, 0.22, 0.70},
	dartBodyColor      = {0.64, 0.67, 0.72, 1},
	dartTipColor       = {0.84, 0.88, 0.92, 1},
	dartTailColor      = {0.88, 0.68, 0.22, 1},

	textColor        = {0.92, 0.95, 0.97, 1},
	mutedTextColor   = {0.60, 0.62, 0.65, 1},
	accentTextColor  = {0.98, 0.78, 0.35, 1},

	lockedCardColor = {0.40, 0.32, 0.42, 1},
	achieveColor    = {0.98, 0.78, 0.35, 1},
	progressColor   = {0.20, 0.70, 0.45, 1},
	warningColor    = {0.88, 0.22, 0.22, 1},

	snakeDefault = {0.12, 0.74, 0.45, 1},

	appleColor       = {0.92, 0.28, 0.28, 1},
	bananaColor      = {0.98, 0.78, 0.25, 1},
	blueberryColor   = {0.28, 0.42, 0.78, 1},
	goldenPearColor  = {0.98, 0.78, 0.35, 1},
	dragonfruitColor = {0.92, 0.48, 0.88, 1},

	sawColor = {0.80, 0.84, 0.88, 1},
	rock     = {0.62, 0.64, 0.66, 1},
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
