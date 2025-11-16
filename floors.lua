local Floors = {
	[1] = {
		nameKey = "floors.garden_gate.name",
		flavorKey = "floors.garden_gate.flavor",
		palette = {
			bgColor = {0.08, 0.10, 0.09, 1},
			arenaBG = {0.22, 0.20, 0.23, 1},
			arenaBorder = {0.56, 0.50, 0.42},
			rock = {0.60, 0.58, 0.54, 1},
			sawColor = {0.78, 0.78, 0.80, 1},
		},
	},
	[2] = {
		nameKey = "floors.moonwell_caves.name",
		flavorKey = "floors.moonwell_caves.flavor",
		palette = {
			bgColor     = {0.05, 0.07, 0.10, 1},
			arenaBG     = {0.17, 0.18, 0.24, 1},
			arenaBorder = {0.47, 0.40, 0.57, 1},
			rock        = {0.50, 0.53, 0.57, 1},
			sawColor    = {0.72, 0.72, 0.76, 1},
		},
	},
	[3] = {
		nameKey = "floors.tide_vault.name",
		flavorKey = "floors.tide_vault.flavor",
		palette = {
			bgColor     = {0.04, 0.07, 0.09, 1},
			arenaBG     = {0.12, 0.21, 0.24, 1},
			arenaBorder = {0.50, 0.39, 0.43, 1},
			rock        = {0.50, 0.54, 0.56, 1},
			sawColor    = {0.72, 0.72, 0.76, 1},
		},
	},
	[4] = {
		nameKey = "floors.frosty_cavern.name",
		flavorKey = "floors.frosty_cavern.flavor",
		palette = {
			bgColor     = {0.038, 0.058, 0.085, 1},
			arenaBG     = {0.22, 0.26, 0.38, 1},
			arenaBorder = {0.62, 0.58, 0.74, 1},
			rock        = {0.56, 0.60, 0.73, 1},
			sawColor    = {0.75, 0.77, 0.82, 1},
		},
	},
	[5] = {
		nameKey = "floors.crystal_run.name",
		flavorKey = "floors.crystal_run.flavor",
		palette = {
			bgColor    = {0.040, 0.070, 0.110, 1},
			arenaBG    = {0.13, 0.17, 0.23, 1},
			arenaBorder= {0.42, 0.68, 0.92, 1},
			rock       = {0.52, 0.60, 0.82, 1},
			sawColor   = {0.68, 0.88, 1.0, 1},
		},
	},
	[6] = {
		nameKey = "floors.inferno_gates.name",
		flavorKey = "floors.inferno_gates.flavor",
		palette = {
			bgColor     = {0.07, 0.03, 0.035, 1},    -- soot darkness (unchanged feeling)
			arenaBG     = {0.11, 0.065, 0.10, 1},     -- volcanic plum (adds contrast)
			arenaBorder = {0.42, 0.09, 0.10, 1},     -- saturated inferno red
			rock        = {0.36, 0.30, 0.28, 1},     -- ashstone: brown-grey, stands out clearly
			sawColor    = {0.78, 0.80, 0.85, 1},     -- crisp heated blade
		},
	},
	[7] = {
		nameKey = "floors.skywalk.name",
		flavorKey = "floors.skywalk.flavor",
		palette = {
			bgColor    = {0.080, 0.110, 0.180, 1},
			arenaBG    = {0.70, 0.84, 0.95, 1},
			arenaBorder= {0.54, 0.74, 0.9, 1},
			rock       = {0.50, 0.62, 0.86, 1},
			sawColor   = {0.96, 0.62, 0.34, 1},
		},
	},
	[8] = {
		nameKey = "floors.promise_gate.name",
		flavorKey = "floors.promise_gate.flavor",
		palette = {
			bgColor    = {0.060, 0.040, 0.110, 1},
			arenaBG    = {0.18, 0.08, 0.26, 1},
			arenaBorder= {0.68, 0.26, 0.72, 1},
			rock       = {0.54, 0.32, 0.68, 1},
			sawColor   = {1.0, 0.5, 0.7, 1},
		},
	},
}

Floors.storyTitleKey = "floors.story_title"
Floors.victoryMessageKey = "floors.victory_message"

return Floors