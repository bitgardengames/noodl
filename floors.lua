local Floors = {
	--[[[1] = {
		name = "Garden Gate",
		flavor = "Noodl winds through the garden, scooping up fruit scattered among the vines.",
		palette = {
			bgColor = {0.08, 0.10, 0.09, 1},
			arenaBG = {0.22, 0.20, 0.23, 1},
			arenaBorder = {0.56, 0.50, 0.42},
			rock = {0.60, 0.58, 0.54, 1},
			sawColor = {0.78, 0.78, 0.80, 1},
		},
	},]]
	[1] = {
		name = "Inferno Gates",
		flavor = "Heat rises, and the walls bleed with firelight.",
		palette = {
			bgColor     = {0.07, 0.03, 0.035, 1},    -- soot darkness (unchanged feeling)
			arenaBG     = {0.11, 0.065, 0.10, 1},     -- volcanic plum (adds contrast)
			arenaBorder = {0.42, 0.09, 0.10, 1},     -- saturated inferno red
			rock        = {0.36, 0.30, 0.28, 1},     -- ashstone: brown-grey, stands out clearly
			sawColor    = {0.78, 0.80, 0.85, 1},     -- crisp heated blade
		},
	},
	[2] = {
		name = "Moonwell Caves",
		flavor = "Moonlit pools mirror Noodl's glide as pears bob within easy reach.",
		palette = {
			bgColor     = {0.05, 0.07, 0.10, 1},
			arenaBG     = {0.17, 0.18, 0.24, 1},
			arenaBorder = {0.47, 0.40, 0.57, 1},
			rock        = {0.50, 0.53, 0.57, 1},
			sawColor    = {0.72, 0.72, 0.76, 1},
		},
	},
	[3] = {
		name = "Tide Vault",
		flavor = "Slow waves roll shining citrus along the tiles while Noodl gathers every slice.",
		palette = {
			bgColor     = {0.04, 0.07, 0.09, 1},
			arenaBG     = {0.12, 0.21, 0.24, 1},
			arenaBorder = {0.50, 0.39, 0.43, 1},
			rock        = {0.50, 0.54, 0.56, 1},
			sawColor    = {0.72, 0.72, 0.76, 1},
		},
	},
	[4] = {
		name = "Frosty Cavern",
		flavor = "",
		palette = {
			bgColor     = {0.038, 0.058, 0.085, 1},
			arenaBG     = {0.22, 0.26, 0.38, 1},
			arenaBorder = {0.62, 0.58, 0.74, 1},
			rock        = {0.56, 0.60, 0.73, 1},
			sawColor    = {0.75, 0.77, 0.82, 1},
		},
	},
	[5] = {
		name = "Crystal Run",
		flavor = "Frosted crystals light the tunnel and chill each reclaimed apple in Noodl's pack.",
		palette = {
			bgColor    = {0.040, 0.070, 0.110, 1},
			arenaBG    = {0.13, 0.17, 0.23, 1},
			arenaBorder= {0.42, 0.68, 0.92, 1},
			rock       = {0.52, 0.60, 0.82, 1},
			sawColor   = {0.68, 0.88, 1.0, 1},
		},
	},
	[6] = {
		name = "Ember Market",
		flavor = "Emberlit stalls keep peppered fruit warm while Noodl threads the aisles collecting them.",
		palette = {
			bgColor    = {0.090, 0.050, 0.040, 1},
			arenaBG    = {0.24, 0.12, 0.07, 1},
			arenaBorder= {0.82, 0.5, 0.25, 1},
			snake      = {0.98, 0.76, 0.32, 1},
			rock       = {0.64, 0.4, 0.22, 1},
			sawColor   = {1.0, 0.62, 0.32, 1},
		},
	},
	[7] = {
		name = "Skywalk",
		flavor = "Lanterns line the high road, showing every peach for Noodl to scoop along the bridge.",
		palette = {
			bgColor    = {0.080, 0.110, 0.180, 1},
			arenaBG    = {0.68, 0.82, 0.94, 1},
			arenaBorder= {0.54, 0.74, 0.9, 1},
			snake      = {0.98, 0.7, 0.32, 1},
			rock       = {0.44, 0.62, 0.88, 1},
			sawColor   = {0.96, 0.62, 0.34, 1},
			bananaColor     = {0.88, 0.68, 0.24, 1},
			goldenPearColor = {0.9, 0.58, 0.2, 1},
		},
	},
	[8] = {
		name = "Promise Gate",
		flavor = "At the final gate, Noodl secures the last fruit and coils around the harvest.",
		palette = {
			bgColor    = {0.060, 0.040, 0.110, 1},
			arenaBG    = {0.18, 0.08, 0.26, 1},
			arenaBorder= {0.68, 0.26, 0.72, 1},
			snake      = {0.92, 0.48, 0.98, 1},
			rock       = {0.54, 0.32, 0.68, 1},
			sawColor   = {1.0, 0.5, 0.7, 1},
		},
	},
}

Floors.storyTitle = "Harvest Complete"
Floors.victoryMessage = "Noodl hauls the full harvest home, every fruit accounted for."

return Floors