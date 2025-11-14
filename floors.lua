local Floors = {
	[1] = {
		name = "Garden Gate",
		flavor = "Noodl winds through the garden, scooping up fruit scattered among the vines.",
		palette = {
			bgColor = {0.08, 0.10, 0.09, 1},
			arenaBG = {0.21, 0.19, 0.22, 1},
			arenaBorder = {0.52, 0.48, 0.38, 1},
			rock = {0.58, 0.56, 0.52, 1},
			sawColor = {0.78, 0.78, 0.80, 1},
		},
	},
	[2] = {
		name = "Moonwell Caves",
		flavor = "Moonlit pools mirror Noodl's glide as pears bob within easy reach.",
		palette = {
			bgColor    = {0.035, 0.055, 0.095, 1},
			arenaBG    = {0.13, 0.17, 0.25, 1},
			arenaBorder= {0.44, 0.36, 0.62, 1},
			snake      = {0.78, 0.86, 0.98, 1},
			rock       = {0.41, 0.58, 0.71, 1},
			sawColor   = {0.69, 0.69, 0.74, 1},
		},
	},
	[3] = {
		name = "Tide Vault",
		flavor = "Slow waves roll shining citrus along the tiles while Noodl gathers every slice.",
		palette = {
			bgColor    = {0.035, 0.070, 0.090, 1},
			arenaBG    = {0.089, 0.242, 0.271, 1},
			arenaBorder= {0.63, 0.36, 0.4, 1},
			snake      = {0.84, 0.95, 0.58, 1},
			rock       = {0.361, 0.561, 0.635, 1},
			sawColor   = {0.62, 0.659, 0.671, 1},
		},
	},
	[4] = {
		name = "Gloomshaft Hoist",
		flavor = "Winches creak through echoing caverns while glimmering dew feeds Noodl's climb.",
		palette = {
			bgColor    = {0.032, 0.055, 0.085, 1},
			arenaBG    = {0.112, 0.162, 0.214, 1},
			arenaBorder= {0.368, 0.512, 0.62, 1},
			snake      = {0.78, 0.95, 0.89, 1},
			rock       = {0.318, 0.452, 0.54, 1},
			sawColor   = {0.67, 0.88, 0.93, 1},
		},
	},
	[5] = {
		name = "Crystal Run",
		flavor = "Frosted crystals light the tunnel and chill each reclaimed apple in Noodl's pack.",
		palette = {
			bgColor    = {0.040, 0.070, 0.110, 1},
			arenaBG    = {0.15, 0.18, 0.24, 1},
			arenaBorder= {0.42, 0.68, 0.92, 1},
			snake      = {0.78, 0.92, 1.0, 1},
			rock       = {0.46, 0.52, 0.7, 1},
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