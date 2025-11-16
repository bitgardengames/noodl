local R64 = {
    [1]  = {0.18, 0.13, 0.18, 1}, -- #2e222f
    [2]  = {0.24, 0.21, 0.27, 1}, -- #3e3546
    [3]  = {0.38, 0.33, 0.40, 1}, -- #625565
    [4]  = {0.59, 0.42, 0.42, 1}, -- #966c6c
    [5]  = {0.67, 0.58, 0.48, 1}, -- #ab947a
    [6]  = {0.41, 0.31, 0.38, 1}, -- #694f62
    [7]  = {0.50, 0.44, 0.54, 1}, -- #7f708a
    [8]  = {0.61, 0.67, 0.70, 1}, -- #9babb2
    [9]  = {0.78, 0.86, 0.82, 1}, -- #c7dcd0
    [10] = {10, 10, 10, 1}, -- #ffffff
    [11] = {0.43, 0.15, 0.15, 1}, -- #6e2727
    [12] = {0.70, 0.22, 0.19, 1}, -- #b33831
    [13] = {0.92, 0.31, 0.21, 1}, -- #ea4f36
    [14] = {0.96, 0.49, 0.29, 1}, -- #f57d4a
    [15] = {0.68, 0.14, 0.20, 1}, -- #ae2334
    [16] = {0.91, 0.23, 0.23, 1}, -- #e83b3b
    [17] = {0.98, 0.42, 0.11, 1}, -- #fb6b1d
    [18] = {0.97, 0.59, 0.09, 1}, -- #f79617
    [19] = {0.98, 0.76, 0.17, 1}, -- #f9c22b
    [20] = {0.48, 0.19, 0.27, 1}, -- #7a3045
    [21] = {0.62, 0.27, 0.22, 1}, -- #9e4539
    [22] = {0.80, 0.41, 0.24, 1}, -- #cd683d
    [23] = {0.90, 0.56, 0.31, 1}, -- #e6904e
    [24] = {0.98, 0.73, 0.33, 1}, -- #fbb954
    [25] = {0.30, 0.24, 0.14, 1}, -- #4c3e24
    [26] = {0.40, 0.40, 0.20, 1}, -- #676633
    [27] = {0.64, 0.66, 0.28, 1}, -- #a2a947
    [28] = {0.84, 0.88, 0.29, 1}, -- #d5e04b
    [29] = {0.98, 10, 0.53, 1}, -- #fbff86
    [30] = {0.09, 0.35, 0.30, 1}, -- #165a4c
    [31] = {0.14, 0.56, 0.39, 1}, -- #239063
    [32] = {0.12, 0.74, 0.45, 1}, -- #1ebc73
    [33] = {0.57, 0.86, 0.41, 1}, -- #91db69
    [34] = {0.80, 0.87, 0.42, 1}, -- #cddf6c
    [35] = {0.19, 0.21, 0.22, 1}, -- #313638
    [36] = {0.22, 0.31, 0.29, 1}, -- #374e4a
    [37] = {0.33, 0.49, 0.39, 1}, -- #547e64
    [38] = {0.57, 0.66, 0.52, 1}, -- #92a984
    [39] = {0.70, 0.73, 0.56, 1}, -- #b2ba90
    [40] = {0.04, 0.37, 0.40, 1}, -- #0b5e65
    [41] = {0.04, 0.54, 0.56, 1}, -- #0b8a8f
    [42] = {0.05, 0.69, 0.61, 1}, -- #0eaf9b
    [43] = {0.19, 0.88, 0.73, 1}, -- #30e1b9
    [44] = {0.56, 0.97, 0.89, 1}, -- #8ff8e2
    [45] = {0.20, 0.20, 0.33, 1}, -- #323353
    [46] = {0.28, 0.29, 0.47, 1}, -- #484a77
    [47] = {0.30, 0.40, 0.71, 1}, -- #4d65b4
    [48] = {0.30, 0.61, 0.90, 1}, -- #4d9be6
    [49] = {0.56, 0.83, 10, 1}, -- #8fd3ff
    [50] = {0.27, 0.16, 0.25, 1}, -- #45293f
    [51] = {0.42, 0.24, 0.46, 1}, -- #6b3e75
    [52] = {0.56, 0.37, 0.66, 1}, -- #905ea9
    [53] = {0.66, 0.52, 0.95, 1}, -- #a884f3
    [54] = {0.92, 0.68, 0.93, 1}, -- #eaaded
    [55] = {0.46, 0.24, 0.33, 1}, -- #753c54
    [56] = {0.64, 0.29, 0.44, 1}, -- #a24b6f
    [57] = {0.81, 0.40, 0.50, 1}, -- #cf657f
    [58] = {0.93, 0.50, 0.60, 1}, -- #ed8099
    [59] = {0.51, 0.11, 0.36, 1}, -- #831c5d
    [60] = {0.76, 0.14, 0.33, 1}, -- #c32454
    [61] = {0.94, 0.31, 0.47, 1}, -- #f04f78
    [62] = {0.97, 0.51, 0.51, 1}, -- #f68181
    [63] = {0.99, 0.65, 0.56, 1}, -- #fca790
    [64] = {0.99, 0.80, 0.69, 1}, -- #fdcbb0
}

local Theme = {
    -- ARENA (unchanged)
    arenaBG      = R64[35],
    arenaBorder  = R64[2],

    -- GENERAL BACKGROUND / CHROME
    bgColor              = R64[25],
    menuBackgroundColor  = R64[35],
    shopBackgroundColor  = R64[35],
    shadowColor          = {0, 0, 0, 0.25},
    highlightColor       = {1, 1, 1, 0.06},

    -- BUTTONS
    buttonColor = R64[20],
    buttonHover = R64[20],
    buttonPress = R64[20],
    borderColor = {0, 0, 0, 1},

    -- PANELS
    panelColor  = R64[50],
    panelBorder = {0, 0, 0, 1},

    -- DARTS
    dartBaseColor      = R64[35],
    dartAccentColor    = R64[33],
    dartTelegraphColor = {R64[33][1], R64[33][2], R64[33][3], 0.78},
    dartBodyColor      = R64[39],
    dartTipColor       = R64[9],
    dartTailColor      = R64[33],

    -- TEXT
    textColor        = R64[10],
    mutedTextColor   = R64[8],
    accentTextColor  = R64[24],

    -- FEEDBACK
    lockedCardColor = R64[51],
    achieveColor    = R64[24],
    progressColor   = R64[32],
    warningColor    = R64[16],

    -- SNAKE
    snakeDefault = R64[32],

    -- FRUITS (picked for strong palette harmony)
    appleColor       = R64[16], -- #e83b3b (best “apple red” in palette)
    bananaColor      = R64[19], -- #f9c22b warm yellow
    blueberryColor   = R64[47], -- #4d65b4 deep berry blue
    goldenPearColor  = R64[24], -- golden
    dragonfruitColor = R64[54], -- pastel magenta-pink

    -- HAZARDS
    sawColor = R64[8],
    rock     = R64[3],
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