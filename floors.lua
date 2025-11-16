local Floors = {
	[1] = {
		nameKey = "floors.garden_gate.name",
		flavorKey = "floors.garden_gate.flavor",
		palette = {
			bgColor     = {0.19, 0.21, 0.22, 1},     -- R64[35] neutral slate (clean backdrop)
			arenaBG     = {0.24, 0.21, 0.27, 1},     -- R64[2] muted plum (best snake contrast)
			arenaBorder = {0.67, 0.58, 0.48, 1},     -- R64[5] warm wood/stone
			rock        = {0.61, 0.67, 0.70, 1},     -- R64[8] soft cool rock
			sawColor    = {0.78, 0.86, 0.82, 1},     -- R64[9] consistent metal tone
		},
	},
	[2] = {
		nameKey = "floors.moonwell_caves.name",
		flavorKey = "floors.moonwell_caves.flavor",
		palette = {
			bgColor     = {0.18, 0.13, 0.18, 1},     -- R64[1] deep purple-black
			arenaBG     = {0.20, 0.20, 0.33, 1},     -- R64[45] cool violet-blue (distinct!)
			arenaBorder = {0.50, 0.44, 0.54, 1},     -- R64[7] muted violet stone
			rock        = {0.61, 0.67, 0.70, 1},     -- R64[8] soft rock color
			sawColor    = {0.78, 0.86, 0.82, 1},     -- R64[9] metal
		},
	},
	[3] = {
		nameKey = "floors.tide_vault.name",
		flavorKey = "floors.tide_vault.flavor",
		palette = {
			bgColor     = {0.18, 0.13, 0.18, 1},     -- R64[1]
			arenaBG     = {0.20, 0.20, 0.33, 1},     -- R64[45]
			arenaBorder = {0.22, 0.31, 0.29, 1},     -- R64[36]
			rock        = {0.61, 0.67, 0.70, 1},     -- R64[8]
			sawColor    = {0.78, 0.86, 0.82, 1},     -- R64[9]
		},
	},
	[4] = {
		nameKey = "floors.frosty_cavern.name",
		flavorKey = "floors.frosty_cavern.flavor",
		palette = {
			bgColor     = {0.20, 0.20, 0.33, 1},     -- R64[45] #323353 (closest to 0.038,0.058,0.085 — darkest cold tone)
			arenaBG     = {0.28, 0.29, 0.47, 1},     -- R64[46] #484a77 (closest to 0.22,0.26,0.38)
			arenaBorder = {0.56, 0.37, 0.66, 1},     -- R64[52] #905ea9 (closest to 0.62,0.58,0.74)
			rock        = {0.61, 0.67, 0.70, 1},     -- R64[47] #4d65b4 (closest to 0.56,0.60,0.73 but R64 has no light blues—best viable hue)
			sawColor    = {0.78, 0.86, 0.82, 1},     -- R64[9]  #c7dcd0 (closest to 0.75,0.77,0.82)
		},
	},
	[5] = {
		nameKey = "floors.crystal_run.name",
		flavorKey = "floors.crystal_run.flavor",
		palette = {
			bgColor    = {0.20, 0.20, 0.33, 1},     -- R64[45] #323353  (closest to 0.04,0.07,0.11)
			arenaBG    = {0.28, 0.29, 0.47, 1},     -- R64[46] #484a77  (closest to 0.13,0.17,0.23)
			arenaBorder= {0.30, 0.61, 0.90, 1},     -- R64[48] #4d9be6  (closest to 0.42,0.68,0.92)
			rock       = {0.30, 0.40, 0.71, 1},     -- R64[47] #4d65b4  (closest to 0.52,0.60,0.82)
			sawColor   = {0.56, 0.83, 1.00, 1},     -- R64[49] #8fd3ff  (closest to 0.68,0.88,1.0)
		}
	},
	[6] = {
		nameKey = "floors.inferno_gates.name",
		flavorKey = "floors.inferno_gates.flavor",
		palette = {
			bgColor     = {0.27, 0.16, 0.25, 1},    -- R64[50] #45293f (closest to 0.07,0.03,0.035 — darkest warm/soot-like tone)
			arenaBG     = {0.48, 0.19, 0.27, 1},    -- R64[20] #7a3045 (closest to 0.11,0.065,0.10 — volcanic plum → dark wine/plum)
			arenaBorder = {0.70, 0.22, 0.19, 1},    -- R64[12] #b33831 (closest to 0.42,0.09,0.10 — strong inferno red)
			rock        = {0.30, 0.24, 0.14, 1},    -- R64[25] #4c3e24 (closest earthy ashstone brown-gray)
			sawColor    = {0.78, 0.86, 0.82, 1},    -- R64[9]  #c7dcd0 (closest to 0.78,0.80,0.85 — light neutral)
		},
	},
	[7] = {
		nameKey = "floors.skywalk.name",
		flavorKey = "floors.skywalk.flavor",
		palette = {
			bgColor    = {0.20, 0.20, 0.33, 1},     -- R64[45] #323353 (closest dark cool blue)
			arenaBG    = {0.56, 0.83, 1.00, 1},     -- R64[49] #8fd3ff (closest to 0.70,0.84,0.95)
			arenaBorder= {0.30, 0.61, 0.90, 1},     -- R64[48] #4d9be6 (closest to 0.54,0.74,0.90)
			rock       = {0.30, 0.40, 0.71, 1},     -- R64[47] #4d65b4 (closest to 0.50,0.62,0.86)
			sawColor   = {0.98, 0.76, 0.17, 1},     -- R64[19] #f9c22b (closest warm/yellow/orange to 0.96,0.62,0.34)
		},
	},
	[8] = {
		nameKey = "floors.promise_gate.name",
		flavorKey = "floors.promise_gate.flavor",
		palette = {
			bgColor    = {0.27, 0.16, 0.25, 1},     -- R64[50] #45293f (closest dark purple-tinted tone)
			arenaBG    = {0.42, 0.24, 0.46, 1},     -- R64[51] #6b3e75 (closest to 0.18,0.08,0.26)
			arenaBorder= {0.56, 0.37, 0.66, 1},     -- R64[52] #905ea9 (closest violet to 0.68,0.26,0.72)
			rock       = {0.46, 0.24, 0.33, 1},     -- R64[55] #753c54 (closest to 0.54,0.32,0.68; R64 lacks light violets)
			sawColor   = {0.93, 0.50, 0.60, 1},     -- R64[58] #ed8099 (closest to 1.0,0.5,0.7)
		},
	},
}

Floors.storyTitleKey = "floors.story_title"
Floors.victoryMessageKey = "floors.victory_message"

return Floors