local Theme = {
	-- ARENA (base arena before floor overrides)
	arenaBG      = {0.10, 0.14, 0.18, 1},   -- deep slate-teal
	arenaBorder  = {0.40, 0.45, 0.48, 1},   -- muted steel frame

	-- GENERAL BACKGROUND / CHROME
	bgColor             = {0.18, 0.19, 0.21, 1},  -- universal game background (charcoal)
	menuBackgroundColor = {0.17, 0.21, 0.29, 1},  -- darker for contrast against panels
	shopBackgroundColor = {0.17, 0.21, 0.29, 1},
	shadowColor         = {0, 0, 0, 0.28},
	highlightColor      = {1, 1, 1, 0.06},

	-- BUTTONS
	buttonColor = {0.30, 0.38, 0.48, 1},
	buttonHover = {0.40, 0.52, 0.60, 1},
	buttonPress = {0.28, 0.34, 0.40, 1},
	borderColor = {0, 0, 0, 1},

	-- PANELS
	panelColor  = {0.16, 0.18, 0.20, 1},     -- soft charcoal slate
	panelBorder = {0, 0, 0, 1},

	-- DARTS
	dartBaseColor      = {0.22, 0.24, 0.28, 1},   -- muted steel
	dartAccentColor    = {0.90, 0.70, 0.25, 1},   -- warm bronze
	dartTelegraphColor = {0.90, 0.70, 0.25, 0.70},
	dartBodyColor      = {0.65, 0.68, 0.72, 1},   -- cool silver
	dartTipColor       = {0.85, 0.90, 0.92, 1},   -- bright steel
	dartTailColor      = {0.90, 0.70, 0.25, 1},

	-- TEXT
	textColor        = {0.92, 0.95, 0.97, 1},
	mutedTextColor   = {0.60, 0.62, 0.65, 1},
	accentTextColor  = {0.98, 0.78, 0.35, 1},  -- warm amber

	-- FEEDBACK
	lockedCardColor = {0.40, 0.32, 0.42, 1},  -- muted purple-gray
	achieveColor    = {0.98, 0.78, 0.35, 1},  -- gold
	progressColor   = {0.20, 0.70, 0.45, 1},  -- green progress bar
	warningColor    = {0.88, 0.22, 0.22, 1},  -- red warning

	-- SNAKE (kept exactly your original green, works on all)
	snakeDefault = {0.12, 0.74, 0.45, 1},

	-- FRUITS (vibrant, readable, but slightly softened saturation)
	appleColor       = {0.92, 0.28, 0.28, 1},
	bananaColor      = {0.98, 0.78, 0.25, 1},
	blueberryColor   = {0.28, 0.42, 0.78, 1},
	goldenPearColor  = {0.98, 0.78, 0.35, 1},
	dragonfruitColor = {0.92, 0.48, 0.88, 1},

	-- HAZARDS
	sawColor = {0.80, 0.84, 0.88, 1},     -- crisp silver saw
	rock     = {0.62, 0.64, 0.66, 1},     -- clean neutral rock (no blue, no green)
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
