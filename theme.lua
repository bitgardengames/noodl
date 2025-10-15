local Theme = {
	-- Arena
	ArenaBG      = {0.18, 0.18, 0.22, 1.0},
	ArenaBorder  = {0.35, 0.30, 0.50, 1.0},

	-- General background / chrome
	BgColor        = {0.12, 0.12, 0.14, 1.0},
	ShadowColor    = {0.0, 0.0, 0.0, 0.45},
	HighlightColor = {1.0, 1.0, 1.0, 0.06},

	-- Buttons
	ButtonColor     = {0.26, 0.22, 0.34, 1.0},
	ButtonHover     = {0.34, 0.30, 0.48, 1.0},
	ButtonPress     = {0.20, 0.18, 0.28, 1.0},
	BorderColor     = {0.42, 0.72, 0.62, 1.0},

	-- Panels
	PanelColor      = {0.16, 0.16, 0.22, 0.94},
	PanelBorder     = {0.32, 0.50, 0.54, 1.0},

	-- Text
	TextColor       = {0.88, 0.88, 0.92, 1.0},
	MutedTextColor  = {0.70, 0.72, 0.78, 1.0},
	AccentTextColor = {0.82, 0.92, 0.78, 1.0},

	-- State / feedback colours
	LockedCardColor = {0.50, 0.35, 0.40, 1.0},
	AchieveColor    = {0.80, 0.45, 0.65, 1.0},
	ProgressColor   = {0.55, 0.75, 0.55, 1.0},
	WarningColor    = {0.92, 0.55, 0.40, 1.0},

	-- Gameplay
	SnakeDefault    = {0.45, 0.85, 0.70, 1.0},

	-- Fruits / pickups
	AppleColor       = {0.90, 0.45, 0.55, 1.0},
	BananaColor      = {0.90, 0.85, 0.55, 1.0},
	BlueberryColor   = {0.55, 0.65, 0.95, 1.0},
	GoldenPearColor  = {0.95, 0.80, 0.45, 1.0},
	DragonfruitColor = {0.90, 0.60, 0.80, 1.0},

	-- Obstacles
	SawColor         = {0.65, 0.65, 0.70, 1.0},
	rock             = {0.30, 0.30, 0.35, 1.0},
}

local function CopyTable(value)
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
	defaults[key] = CopyTable(value)
end

function Theme.reset()
	for key in pairs(Theme) do
		if key ~= "reset" then
			Theme[key] = nil
		end
	end

	for key, value in pairs(defaults) do
		Theme[key] = CopyTable(value)
	end
end

return Theme
