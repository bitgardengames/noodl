local Floors = {
	[1] = {
		nameKey = "floors.garden_gate.name",
		flavorKey = "floors.garden_gate.flavor",
		palette = {
			bgColor     = {0.07, 0.11, 0.11, 1},   -- teal forest vignette
			arenaBG     = {0.34, 0.48, 0.39, 1},   -- moss green interior
			arenaBorder = {0.67, 0.52, 0.26, 1},   -- warm oak wood frame
			rock        = {0.72, 0.74, 0.74, 1},   -- neutral stone
			sawColor    = {0.85, 0.88, 0.92, 1},   -- silver metal
		},
	},
	[2] = {
		nameKey = "floors.moonwell_caves.name",
		flavorKey = "floors.moonwell_caves.flavor",
		palette = {
			bgColor     = {0.10, 0.11, 0.13, 1},
			arenaBG     = {0.20, 0.22, 0.36, 1},   -- cool midnight indigo
			arenaBorder = {0.36, 0.32, 0.50, 1},   -- muted lavender stone
			rock        = {0.70, 0.72, 0.74, 1},
			sawColor    = {0.85, 0.88, 0.92, 1},
		},
	},
	[3] = {
		nameKey = "floors.tide_vault.name",
		flavorKey = "floors.tide_vault.flavor",
		palette = {
			bgColor     = {0.10, 0.11, 0.13, 1},
			arenaBG     = {0.16, 0.26, 0.33, 1},   -- deep teal-slate (underwater vault)
			arenaBorder = {0.32, 0.40, 0.43, 1},   -- wet stone
			rock        = {0.62, 0.64, 0.66, 1},
			sawColor    = {0.80, 0.84, 0.88, 1},
		},
	},
	[4] = {
		nameKey = "floors.frosty_cavern.name",
		flavorKey = "floors.frosty_cavern.flavor",
		palette = {
			bgColor     = {0.10, 0.12, 0.15, 1},   -- cold twilight slate
			arenaBG     = {0.26, 0.39, 0.52, 1},   -- deep ice-slate blue (no pastel)
			arenaBorder = {0.38, 0.50, 0.68, 1},   -- cold steel-blue frame
			rock        = {0.78, 0.84, 0.90, 1},   -- frosted pebbles
			sawColor    = {0.92, 0.95, 0.98, 1},   -- bright cold steel
		},
	},
	[5] = {
		nameKey = "floors.crystal_run.name",
		flavorKey = "floors.crystal_run.flavor",
		palette = {
			bgColor     = {0.12, 0.13, 0.15, 1},
			arenaBG     = {0.42, 0.55, 0.78, 1},   -- soft crystal blue
			arenaBorder = {0.58, 0.45, 0.80, 1},   -- crystalline violet
			rock        = {0.75, 0.80, 0.88, 1},   -- cool crystal shard
			sawColor    = {0.95, 0.98, 1.00, 1},   -- radiant saw
		},
	},
	[6] = {
		nameKey = "floors.inferno_gates.name",
		flavorKey = "floors.inferno_gates.flavor",
		palette = {
			bgColor     = {0.11, 0.09, 0.09, 1},   -- dark iron soot
			arenaBG     = {0.28, 0.16, 0.13, 1},   -- burnt clay / lava rock
			arenaBorder = {0.62, 0.18, 0.15, 1},   -- red iron oxide
			rock        = {0.38, 0.32, 0.26, 1},   -- ashy basalt
			sawColor    = {0.94, 0.84, 0.76, 1},   -- heated soft metal
		},
	},
	[7] = {
		nameKey = "floors.skywalk.name",
		flavorKey = "floors.skywalk.flavor",
		palette = {
			bgColor     = {0.12, 0.13, 0.15, 1},
			arenaBG     = {0.58, 0.76, 0.88, 1},   -- airy sky blue
			arenaBorder = {0.42, 0.60, 0.80, 1},   -- cool skyframe
			rock        = {0.68, 0.72, 0.80, 1},   -- pale sky stone
			sawColor    = {1.00, 0.82, 0.40, 1},   -- sunlight gold
		},
	},
	[8] = {
		nameKey = "floors.promise_gate.name",
		flavorKey = "floors.promise_gate.flavor",
		palette = {
			bgColor     = {0.14, 0.11, 0.16, 1},
			arenaBG     = {0.42, 0.32, 0.55, 1},   -- royal twilight violet
			arenaBorder = {0.60, 0.46, 0.75, 1},   -- ascendant purple
			rock        = {0.72, 0.62, 0.80, 1},   -- arcane stone
			sawColor    = {0.95, 0.70, 0.85, 1},   -- magical pink steel
		},
	},
}

Floors.storyTitleKey = "floors.story_title"
Floors.victoryMessageKey = "floors.victory_message"

return Floors