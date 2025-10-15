-- floors.lua

--[[
Garden Gate → Noodl winds through the grove to gather scattered fruit.
Moonwell Caves → Reflected pools guide each pear into reach.
Glowcap Den → Mushrooms spotlight jars ready for collection.
Tide Vault → Rolling tides usher citrus toward the basket.
Rusted Hoist → Old lifts reveal syrupy stores to reclaim.
Crystal Run → Frozen light chills the apples along the path.
Firefly Grove → Glow motes trace branches lined with treats.
Storm Ledge → Thunder shakes snacks loose to seize mid-sprint.
Ember Market → Emberlit stalls keep peppered fruit warm for pickup.
Molten Keep → Lava light guards rows of honeyed figs.
Wind Steppe → Gusts sweep herbs into drifts to gather.
Ribbon Loom → Streaming ribbons mark stacks of sweets.
Forge Pit → Sparks glint over trays of reclaimed fruit.
Skywalk → High lanterns reveal every dangling peach.
Sun Tower → Solar ovens steady the custards for the climb.
Star Ward → Starlit halls glitter with sugar to collect.
Drift Garden → Floating beds shed jars of stardust jam.
Night Observatory → Charts and scopes highlight the ripest slices.
Dusk Court → Calm dusk light steadies the laden basket.
Promise Gate → The final gate seals the harvest.
]]

local Floors = {
	[1] = {
name = "Garden Gate",
flavor = "Noodl winds through the garden, scooping up fruit scattered among the vines.",
				palette = {
						BgColor     = {0.24, 0.32, 0.24, 1},
						ArenaBG     = {0.46, 0.66, 0.39, 1},
						ArenaBorder = {0.52, 0.38, 0.24, 1},
						snake       = {0.12, 0.9, 0.48, 1},
						rock        = {0.74, 0.59, 0.38, 1},
				},
				BackgroundEffect = {
						type = "SoftCanopy",
						BackdropIntensity = 0.55,
						ArenaIntensity = 0.32,
				},
				BackgroundTheme = "botanical",
		},
	[2] = {
name = "Moonwell Caves",
flavor = "Moonlit pools mirror Noodl's glide as pears bob within easy reach.",
		palette = {
			BgColor    = {0.07, 0.09, 0.14, 1},
			ArenaBG    = {0.13, 0.17, 0.25, 1},
			ArenaBorder= {0.44, 0.36, 0.62, 1},
			snake      = {0.78, 0.86, 0.98, 1},
			rock       = {0.38, 0.54, 0.66, 1},
		},
		BackgroundEffect = {
			type = "SoftCavern",
			BackdropIntensity = 0.54,
			ArenaIntensity = 0.32,
		},
		BackgroundTheme = "cavern",
	},
	[3] = {
name = "Glowcap Den",
flavor = "Blinking mushrooms outline fresh jars of fruit, and Noodl scoops each in stride.",
		palette = {
			BgColor    = {0.12, 0.14, 0.2, 1},
			ArenaBG    = {0.18, 0.22, 0.26, 1},
			ArenaBorder= {0.48, 0.32, 0.58, 1},
			snake      = {0.48, 0.96, 0.78, 1},
			rock       = {0.5, 0.34, 0.58, 1},
			SawColor   = {0.86, 0.62, 0.92, 1},
		},
		BackgroundEffect = {
			type = "MushroomPulse",
			BackdropIntensity = 0.95,
			ArenaIntensity = 0.62,
		},
		BackgroundTheme = "botanical",
		BackgroundVariant = "fungal",
	},
	[4] = {
name = "Tide Vault",
flavor = "Slow waves roll shining citrus along the tiles while Noodl gathers every slice.",
		palette = {
			BgColor    = {0.03, 0.07, 0.11, 1},
			ArenaBG    = {0.08, 0.15, 0.2, 1},
			ArenaBorder= {0.2, 0.44, 0.48, 1},
			snake      = {0.82, 0.94, 0.58, 1},
			rock       = {0.28, 0.5, 0.58, 1},
			SawColor   = {0.93, 0.79, 0.5, 1},
		},
		BackgroundEffect = {
			type = "SoftCurrent",
			BackdropIntensity = 0.6,
			ArenaIntensity = 0.36,
		},
		BackgroundTheme = "oceanic",
	},
	[5] = {
name = "Rusted Hoist",
flavor = "Ancient lifts cough up stashed syrup, giving Noodl fresh fuel for the harvest.",
		palette = {
			BgColor    = {0.14, 0.12, 0.08, 1},
			ArenaBG    = {0.23, 0.19, 0.12, 1},
			ArenaBorder= {0.5, 0.42, 0.24, 1},
			snake      = {0.98, 0.88, 0.48, 1},
			rock       = {0.54, 0.38, 0.22, 1},
			SawColor   = {0.8, 0.74, 0.64, 1},
		},
		BackgroundEffect = {
			type = "RuinMotes",
			BackdropIntensity = 0.6,
			ArenaIntensity = 0.34,
		},
		BackgroundTheme = "machine",
	},
	[6] = {
name = "Crystal Run",
flavor = "Frosted crystals light the tunnel and chill each reclaimed apple in Noodl's pack.",
		palette = {
			BgColor    = {0.11, 0.13, 0.17, 1},
			ArenaBG    = {0.15, 0.18, 0.24, 1},
			ArenaBorder= {0.42, 0.68, 0.92, 1},
			snake      = {0.78, 0.92, 1.0, 1},
			rock       = {0.46, 0.52, 0.7, 1},
			SawColor   = {0.68, 0.88, 1.0, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.62,
			ArenaIntensity = 0.42,
		},
		BackgroundTheme = "arctic",
	},
	[7] = {
name = "Firefly Grove",
flavor = "Glow motes shimmer above the branches while Noodl gathers warm sweet rolls.",
		palette = {
			BgColor    = {0.1, 0.08, 0.05, 1},
			ArenaBG    = {0.21, 0.15, 0.09, 1},
			ArenaBorder= {0.64, 0.42, 0.18, 1},
			snake      = {0.82, 0.9, 0.56, 1},
			rock       = {0.58, 0.46, 0.24, 1},
			SawColor   = {0.78, 0.6, 0.34, 1},
		},
		BackgroundEffect = {
			type = "SoftCanopy",
			BackdropIntensity = 0.58,
			ArenaIntensity = 0.34,
		},
		BackgroundTheme = "botanical",
	},
	[8] = {
name = "Storm Ledge",
flavor = "Thunder bridges shake loose salty snacks that Noodl snatches mid-sprint.",
		palette = {
			BgColor    = {0.08, 0.1, 0.16, 1},
			ArenaBG    = {0.14, 0.18, 0.24, 1},
			ArenaBorder= {0.36, 0.54, 0.78, 1},
			snake      = {0.86, 0.92, 1.0, 1},
			rock       = {0.32, 0.4, 0.52, 1},
			SawColor   = {0.6, 0.78, 0.98, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.66,
			ArenaIntensity = 0.4,
		},
		BackgroundTheme = "arctic",
	},
	[9] = {
name = "Ember Market",
flavor = "Emberlit stalls keep peppered fruit warm while Noodl threads the aisles collecting them.",
		palette = {
			BgColor    = {0.16, 0.08, 0.05, 1},
			ArenaBG    = {0.24, 0.12, 0.07, 1},
			ArenaBorder= {0.82, 0.5, 0.25, 1},
			snake      = {0.98, 0.76, 0.32, 1},
			rock       = {0.64, 0.4, 0.22, 1},
			SawColor   = {1.0, 0.62, 0.32, 1},
		},
		BackgroundEffect = {
			type = "EmberDrift",
			BackdropIntensity = 0.62,
			ArenaIntensity = 0.38,
		},
		BackgroundTheme = "desert",
	},
	[10] = {
name = "Molten Keep",
flavor = "Lava light glows over honeyed figs that Noodl slides carefully into the pack.",
		palette = {
			BgColor    = {0.08, 0.06, 0.08, 1},
			ArenaBG    = {0.14, 0.11, 0.14, 1},
			ArenaBorder= {0.45, 0.18, 0.08, 1},
			snake      = {0.95, 0.45, 0.25, 1},
			rock       = {0.4, 0.24, 0.32, 1},
			SawColor   = {1.0, 0.35, 0.18, 1},
		},
		BackgroundEffect = {
			type = "VoidPulse",
			BackdropIntensity = 0.7,
			ArenaIntensity = 0.45,
		},
		BackgroundTheme = "desert",
		BackgroundVariant = "hell",
	},
	[11] = {
name = "Wind Steppe",
flavor = "Steady gusts herd loose herbs into bundles that Noodl stacks with practiced coils.",
		palette = {
			BgColor    = {0.09, 0.1, 0.12, 1},
			ArenaBG    = {0.14, 0.18, 0.2, 1},
			ArenaBorder= {0.32, 0.62, 0.52, 1},
			snake      = {0.78, 0.92, 0.68, 1},
			rock       = {0.4, 0.56, 0.5, 1},
			SawColor   = {0.84, 0.66, 0.46, 1},
		},
		BackgroundEffect = {
			type = "SoftCurrent",
			BackdropIntensity = 0.58,
			ArenaIntensity = 0.34,
		},
		BackgroundTheme = "botanical",
	},
	[12] = {
name = "Ribbon Loom",
flavor = "Streaming ribbons knot recovered treats in bright rows that Noodl sweeps into the basket.",
		palette = {
			BgColor    = {0.12, 0.09, 0.16, 1},
			ArenaBG    = {0.18, 0.12, 0.22, 1},
			ArenaBorder= {0.54, 0.36, 0.78, 1},
			snake      = {0.78, 0.9, 1.0, 1},
			rock       = {0.64, 0.52, 0.82, 1},
			SawColor   = {0.9, 0.7, 1.0, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.6,
			ArenaIntensity = 0.38,
		},
		BackgroundTheme = "laboratory",
	},
	[13] = {
name = "Forge Pit",
flavor = "Meteor sparks polish serving tools while Noodl loads them with reclaimed fruit.",
		palette = {
			BgColor    = {0.1, 0.08, 0.12, 1},
			ArenaBG    = {0.16, 0.12, 0.18, 1},
			ArenaBorder= {0.58, 0.36, 0.26, 1},
			snake      = {0.92, 0.7, 0.38, 1},
			rock       = {0.48, 0.34, 0.5, 1},
			SawColor   = {0.88, 0.48, 0.38, 1},
		},
		BackgroundEffect = {
			type = "VoidPulse",
			BackdropIntensity = 0.66,
			ArenaIntensity = 0.42,
		},
		BackgroundTheme = "machine",
	},
	[14] = {
name = "Skywalk",
flavor = "Lanterns line the high road, showing every peach for Noodl to scoop along the bridge.",
		palette = {
			BgColor    = {0.18, 0.2, 0.28, 1},
			ArenaBG    = {0.88, 0.94, 1.0, 1},
			ArenaBorder= {0.72, 0.86, 0.96, 1},
			snake      = {0.96, 0.82, 0.52, 1},
			rock       = {0.34, 0.44, 0.7, 1},
			SawColor   = {0.92, 0.78, 0.58, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.62,
			ArenaIntensity = 0.36,
		},
		BackgroundTheme = "urban",
		BackgroundVariant = "celestial",
	},
	[15] = {
name = "Sun Tower",
flavor = "Solar ovens warm custards that Noodl balances carefully during the climb.",
		palette = {
			BgColor    = {0.24, 0.18, 0.26, 1},
			ArenaBG    = {0.98, 0.88, 0.78, 1},
			ArenaBorder= {1.0, 0.74, 0.46, 1},
			snake      = {0.98, 0.7, 0.4, 1},
			rock       = {0.62, 0.46, 0.54, 1},
			SawColor   = {1.0, 0.6, 0.42, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.6,
			ArenaIntensity = 0.34,
		},
		BackgroundTheme = "urban",
		BackgroundVariant = "celestial",
	},
	[16] = {
name = "Star Ward",
flavor = "Starlit corridors glitter with sugar crystals that Noodl gathers while pressing on.",
		palette = {
			BgColor    = {0.1, 0.12, 0.2, 1},
			ArenaBG    = {0.54, 0.62, 0.84, 1},
			ArenaBorder= {0.88, 0.5, 0.28, 1},
			snake      = {0.98, 0.78, 0.36, 1},
			rock       = {0.34, 0.38, 0.64, 1},
			SawColor   = {0.96, 0.64, 0.38, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.64,
			ArenaIntensity = 0.34,
		},
		BackgroundTheme = "urban",
		BackgroundVariant = "celestial",
	},
	[17] = {
name = "Drift Garden",
flavor = "Floating planters shake loose stardust jam that Noodl tucks away.",
		palette = {
			BgColor    = {0.12, 0.11, 0.2, 1},
			ArenaBG    = {0.38, 0.28, 0.52, 1},
			ArenaBorder= {0.82, 0.5, 0.86, 1},
			snake      = {0.9, 0.68, 0.98, 1},
			rock       = {0.74, 0.58, 0.86, 1},
			SawColor   = {0.94, 0.6, 0.88, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.7,
			ArenaIntensity = 0.42,
		},
		BackgroundTheme = "laboratory",
	},
	[18] = {
name = "Night Observatory",
flavor = "Charts and lenses highlight melon slices so Noodl can track the ripest finds.",
		palette = {
			BgColor    = {0.1, 0.1, 0.18, 1},
			ArenaBG    = {0.16, 0.21, 0.32, 1},
			ArenaBorder= {0.6, 0.54, 0.86, 1},
			snake      = {0.84, 0.92, 1.0, 1},
			rock       = {0.4, 0.42, 0.62, 1},
			SawColor   = {0.94, 0.74, 1.0, 1},
		},
		BackgroundEffect = {
			type = "AuroraVeil",
			BackdropIntensity = 0.7,
			ArenaIntensity = 0.4,
		},
		BackgroundTheme = "laboratory",
	},
	[19] = {
name = "Dusk Court",
flavor = "Soft light calms the loaded basket while Noodl readies for the last push.",
		palette = {
			BgColor    = {0.1, 0.08, 0.14, 1},
			ArenaBG    = {0.16, 0.12, 0.2, 1},
			ArenaBorder= {0.48, 0.2, 0.42, 1},
			snake      = {0.82, 0.48, 0.92, 1},
			rock       = {0.46, 0.3, 0.54, 1},
			SawColor   = {0.74, 0.32, 0.68, 1},
		},
		BackgroundEffect = {
			type = "VoidPulse",
			BackdropIntensity = 0.72,
			ArenaIntensity = 0.46,
		},
		BackgroundTheme = "laboratory",
	},
	[20] = {
name = "Promise Gate",
flavor = "At the final gate, Noodl secures the last fruit and coils around the harvest.",
		palette = {
			BgColor    = {0.08, 0.08, 0.12, 1},
			ArenaBG    = {0.12, 0.1, 0.18, 1},
			ArenaBorder= {0.6, 0.28, 0.66, 1},
			snake      = {0.9, 0.5, 1.0, 1},
			rock       = {0.54, 0.38, 0.74, 1},
			SawColor   = {1.0, 0.54, 0.74, 1},
		},
		BackgroundEffect = {
			type = "VoidPulse",
			BackdropIntensity = 0.78,
			ArenaIntensity = 0.5,
		},
		BackgroundTheme = "oceanic",
		BackgroundVariant = "abyss",
	},
}

Floors.StoryTitle = "Harvest Complete"
Floors.VictoryMessage = "Noodl hauls the full harvest home, every fruit accounted for."

return Floors
