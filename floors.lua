local Floors = {
	[1] = {
		nameKey = "floors.garden_gate.name",
		flavorKey = "floors.garden_gate.flavor",
		palette = {
			bgColor     = {0.07, 0.11, 0.11, 1},
			arenaBG     = {0.33, 0.47, 0.38, 1}, -- forest green
			arenaBorder = {0.54, 0.45, 0.26, 1}, -- warm oak
			rock        = {0.70, 0.72, 0.73, 1},
			sawColor    = {0.84, 0.88, 0.91, 1},
		},
	},

	-- Floor 2: SLATE INDIGO (cool, dark, mysterious, not purple)
	[2] = {
		nameKey = "floors.moonwell_caves.name",
		flavorKey = "floors.moonwell_caves.flavor",
		palette = {
			bgColor     = {0.09, 0.11, 0.13, 1},
			arenaBG     = {0.16, 0.20, 0.30, 1}, -- cooler, more blue-slate than purple
			arenaBorder = {0.26, 0.29, 0.38, 1}, -- slate steel
			rock        = {0.68, 0.70, 0.72, 1},
			sawColor    = {0.84, 0.88, 0.91, 1},
		},
	},

	-- Floor 3: FUNGAL OLIVE SLATE (earthy greenish slate, no blue tint)
	[3] = {
		nameKey = "floors.tide_vault.name",
		flavorKey = "floors.tide_vault.flavor",
		palette = {
			bgColor     = {0.09, 0.11, 0.12, 1}, -- keep
			arenaBG     = {0.20, 0.26, 0.18, 1}, -- deeper moss, less gray
			arenaBorder = {0.30, 0.36, 0.22, 1}, -- richer olive-bronze
			rock        = {0.64, 0.66, 0.62, 1}, -- slightly cooler/lighter stone
			sawColor    = {0.80, 0.84, 0.86, 1},
		},
	},

	-- Floor 4: GLACIER MIST (pale neutral-cool, not blue/cyan)
	[4] = {
		nameKey = "floors.frosty_cavern.name",
		flavorKey = "floors.frosty_cavern.flavor",
		palette = {
			bgColor     = {0.10, 0.12, 0.14, 1},
			arenaBG     = {0.30, 0.36, 0.38, 1}, -- misty gray with faint cool tint
			arenaBorder = {0.42, 0.48, 0.50, 1}, -- glacier stone
			rock        = {0.78, 0.82, 0.86, 1},
			sawColor    = {0.92, 0.95, 0.98, 1},
		},
	},

	-- Floor 5: TERRACOTTA RUINS (warm muted clay, earthy, not poop)
	[5] = {
		nameKey = "floors.terracotta_ruins.name",
		flavorKey = "floors.terracotta_ruins.flavor",
		palette = {
			bgColor     = {0.11, 0.10, 0.10, 1},
			arenaBG     = {0.36, 0.28, 0.24, 1}, -- muted terracotta, cozy, ancient
			arenaBorder = {0.48, 0.38, 0.32, 1}, -- dusty clay brick
			rock        = {0.64, 0.58, 0.54, 1}, -- ruin stone
			sawColor    = {0.88, 0.84, 0.82, 1}, -- pale warm steel
		},
	},

	-- Floor 6: BRIMSTONE DEPTHS (now more volcanic, less wine)
	[6] = {
		nameKey = "floors.inferno_gates.name",
		flavorKey = "floors.inferno_gates.flavor",
		palette = {
			bgColor     = {0.08, 0.06, 0.07, 1}, -- darker, sootier
			arenaBG     = {0.20, 0.08, 0.09, 1}, -- volcanic dark red (less purple)
			arenaBorder = {0.34, 0.12, 0.14, 1}, -- iron-oxide red, not wine
			rock        = {0.28, 0.24, 0.25, 1}, -- scorched basalt
			sawColor    = {0.84, 0.80, 0.80, 1}, -- ash steel
		},
	},

	[7] = {
		nameKey = "floors.skywalk.name",
		flavorKey = "floors.skywalk.flavor",
		palette = {
			bgColor     = {0.11, 0.13, 0.12, 1},
			arenaBG     = {0.34, 0.60, 0.52, 1},
			arenaBorder = {0.26, 0.48, 0.42, 1},
			rock        = {0.60, 0.68, 0.66, 1},
			sawColor    = {0.90, 0.92, 0.80, 1},
		},
	},

	[8] = {
		nameKey = "floors.promise_gate.name",
		flavorKey = "floors.promise_gate.flavor",
		palette = {
			bgColor     = {0.13, 0.11, 0.15, 1},
			arenaBG     = {0.28, 0.20, 0.38, 1},
			arenaBorder = {0.42, 0.32, 0.56, 1},
			rock        = {0.64, 0.56, 0.72, 1},
			sawColor    = {0.90, 0.76, 0.88, 1},
		},
	},
}

Floors.storyTitleKey = "floors.story_title"
Floors.victoryMessageKey = "floors.victory_message"

return Floors
