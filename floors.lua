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
		bgColor     = {0.14, 0.22, 0.2, 1},
		arenaBG     = {0.3, 0.46, 0.38, 1},
		arenaBorder = {0.68, 0.52, 0.3, 1},
		snake       = {0.26, 0.74, 0.56, 1},
		rock        = {0.4, 0.48, 0.42, 1},
	},
	backgroundEffect = {
		type = "gardenMellow",
		backdropIntensity = 0.54,
		arenaIntensity = 0.3,
	},
	backgroundTheme = "botanical",
	},
	[2] = {
	name = "Moonwell Caves",
	flavor = "Moonlit pools mirror Noodl's glide as pears bob within easy reach.",
	palette = {
		bgColor    = {0.07, 0.09, 0.14, 1},
		arenaBG    = {0.13, 0.17, 0.25, 1},
		arenaBorder= {0.44, 0.36, 0.62, 1},
		snake      = {0.78, 0.86, 0.98, 1},
		rock       = {0.38, 0.54, 0.66, 1},
	},
	backgroundEffect = {
		type = "softCavern",
		backdropIntensity = 0.54,
		arenaIntensity = 0.32,
	},
	backgroundTheme = "cavern",
	},
	[3] = {
	name = "Glowcap Den",
	flavor = "Blinking mushrooms outline fresh jars of fruit, and Noodl scoops each in stride.",
	palette = {
		bgColor    = {0.12, 0.14, 0.2, 1},
		arenaBG    = {0.18, 0.22, 0.26, 1},
		arenaBorder= {0.48, 0.32, 0.58, 1},
		snake      = {0.48, 0.96, 0.78, 1},
		rock       = {0.5, 0.34, 0.58, 1},
		sawColor   = {0.86, 0.62, 0.92, 1},
	},
	backgroundEffect = {
		type = "mushroomPulse",
		backdropIntensity = 0.95,
		arenaIntensity = 0.62,
	},
	backgroundTheme = "botanical",
	backgroundVariant = "fungal",
	},
	[4] = {
	name = "Tide Vault",
	flavor = "Slow waves roll shining citrus along the tiles while Noodl gathers every slice.",
	palette = {
		bgColor    = {0.03, 0.07, 0.11, 1},
		arenaBG    = {0.08, 0.15, 0.2, 1},
		arenaBorder= {0.2, 0.44, 0.48, 1},
		snake      = {0.82, 0.94, 0.58, 1},
		rock       = {0.28, 0.5, 0.58, 1},
		sawColor   = {0.93, 0.79, 0.5, 1},
	},
	backgroundEffect = {
		type = "softCurrent",
		backdropIntensity = 0.6,
		arenaIntensity = 0.36,
	},
	backgroundTheme = "oceanic",
	},
	[5] = {
	name = "Rusted Hoist",
	flavor = "Ancient lifts cough up stashed syrup, giving Noodl fresh fuel for the harvest.",
	palette = {
		bgColor    = {0.14, 0.12, 0.08, 1},
		arenaBG    = {0.23, 0.19, 0.12, 1},
		arenaBorder= {0.5, 0.42, 0.24, 1},
		snake      = {0.98, 0.88, 0.48, 1},
		rock       = {0.54, 0.38, 0.22, 1},
		sawColor   = {0.8, 0.74, 0.64, 1},
	},
	backgroundEffect = {
		type = "ruinMotes",
		backdropIntensity = 0.6,
		arenaIntensity = 0.34,
	},
	backgroundTheme = "machine",
	},
	[6] = {
	name = "Crystal Run",
	flavor = "Frosted crystals light the tunnel and chill each reclaimed apple in Noodl's pack.",
	palette = {
		bgColor    = {0.11, 0.13, 0.17, 1},
		arenaBG    = {0.15, 0.18, 0.24, 1},
		arenaBorder= {0.42, 0.68, 0.92, 1},
		snake      = {0.78, 0.92, 1.0, 1},
		rock       = {0.46, 0.52, 0.7, 1},
		sawColor   = {0.68, 0.88, 1.0, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.62,
		arenaIntensity = 0.42,
	},
	backgroundTheme = "arctic",
	},
	[7] = {
	name = "Firefly Grove",
	flavor = "Glow motes shimmer above the branches while Noodl gathers warm sweet rolls.",
	palette = {
		bgColor    = {0.1, 0.08, 0.05, 1},
		arenaBG    = {0.21, 0.15, 0.09, 1},
		arenaBorder= {0.64, 0.42, 0.18, 1},
		snake      = {0.82, 0.9, 0.56, 1},
		rock       = {0.58, 0.46, 0.24, 1},
		sawColor   = {0.78, 0.6, 0.34, 1},
	},
	backgroundEffect = {
		type = "softCanopy",
		backdropIntensity = 0.58,
		arenaIntensity = 0.34,
	},
	backgroundTheme = "botanical",
	},
	[8] = {
	name = "Storm Ledge",
	flavor = "Thunder bridges shake loose salty snacks that Noodl snatches mid-sprint.",
	palette = {
		bgColor    = {0.08, 0.1, 0.16, 1},
		arenaBG    = {0.14, 0.18, 0.24, 1},
		arenaBorder= {0.36, 0.54, 0.78, 1},
		snake      = {0.86, 0.92, 1.0, 1},
		rock       = {0.32, 0.4, 0.52, 1},
		sawColor   = {0.6, 0.78, 0.98, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.66,
		arenaIntensity = 0.4,
	},
	backgroundTheme = "arctic",
	},
	[9] = {
	name = "Ember Market",
	flavor = "Emberlit stalls keep peppered fruit warm while Noodl threads the aisles collecting them.",
	palette = {
		bgColor    = {0.16, 0.08, 0.05, 1},
		arenaBG    = {0.24, 0.12, 0.07, 1},
		arenaBorder= {0.82, 0.5, 0.25, 1},
		snake      = {0.98, 0.76, 0.32, 1},
		rock       = {0.64, 0.4, 0.22, 1},
		sawColor   = {1.0, 0.62, 0.32, 1},
	},
	backgroundEffect = {
		type = "emberDrift",
		backdropIntensity = 0.62,
		arenaIntensity = 0.38,
	},
	backgroundTheme = "desert",
	},
	[10] = {
	name = "Molten Keep",
	flavor = "Lava light glows over honeyed figs that Noodl slides carefully into the pack.",
	palette = {
		bgColor    = {0.08, 0.06, 0.08, 1},
		arenaBG    = {0.14, 0.11, 0.14, 1},
		arenaBorder= {0.45, 0.18, 0.08, 1},
		snake      = {0.95, 0.45, 0.25, 1},
		rock       = {0.4, 0.24, 0.32, 1},
		sawColor   = {1.0, 0.35, 0.18, 1},
	},
	backgroundEffect = {
		type = "voidPulse",
		backdropIntensity = 0.7,
		arenaIntensity = 0.45,
	},
	backgroundTheme = "desert",
	backgroundVariant = "hell",
	},
	[11] = {
	name = "Wind Steppe",
	flavor = "Steady gusts herd loose herbs into bundles that Noodl stacks with practiced coils.",
	palette = {
		bgColor    = {0.09, 0.1, 0.12, 1},
		arenaBG    = {0.14, 0.18, 0.2, 1},
		arenaBorder= {0.32, 0.62, 0.52, 1},
		snake      = {0.78, 0.92, 0.68, 1},
		rock       = {0.4, 0.56, 0.5, 1},
		sawColor   = {0.84, 0.66, 0.46, 1},
	},
	backgroundEffect = {
		type = "softCurrent",
		backdropIntensity = 0.58,
		arenaIntensity = 0.34,
	},
	backgroundTheme = "botanical",
	},
	[12] = {
	name = "Ribbon Loom",
	flavor = "Streaming ribbons knot recovered treats in bright rows that Noodl sweeps into the basket.",
	palette = {
		bgColor    = {0.12, 0.09, 0.16, 1},
		arenaBG    = {0.18, 0.12, 0.22, 1},
		arenaBorder= {0.54, 0.36, 0.78, 1},
		snake      = {0.78, 0.9, 1.0, 1},
		rock       = {0.64, 0.52, 0.82, 1},
		sawColor   = {0.9, 0.7, 1.0, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.6,
		arenaIntensity = 0.38,
	},
	backgroundTheme = "laboratory",
	},
	[13] = {
	name = "Forge Pit",
	flavor = "Meteor sparks polish serving tools while Noodl loads them with reclaimed fruit.",
	palette = {
		bgColor    = {0.1, 0.08, 0.12, 1},
		arenaBG    = {0.16, 0.12, 0.18, 1},
		arenaBorder= {0.58, 0.36, 0.26, 1},
		snake      = {0.92, 0.7, 0.38, 1},
		rock       = {0.48, 0.34, 0.5, 1},
		sawColor   = {0.88, 0.48, 0.38, 1},
	},
	backgroundEffect = {
		type = "voidPulse",
		backdropIntensity = 0.66,
		arenaIntensity = 0.42,
	},
	backgroundTheme = "machine",
	},
	[14] = {
	name = "Skywalk",
	flavor = "Lanterns line the high road, showing every peach for Noodl to scoop along the bridge.",
	palette = {
		bgColor    = {0.18, 0.2, 0.28, 1},
		arenaBG    = {0.88, 0.94, 1.0, 1},
		arenaBorder= {0.72, 0.86, 0.96, 1},
		snake      = {0.96, 0.82, 0.52, 1},
		rock       = {0.34, 0.44, 0.7, 1},
		sawColor   = {0.92, 0.78, 0.58, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.62,
		arenaIntensity = 0.36,
	},
	backgroundTheme = "urban",
	backgroundVariant = "celestial",
	},
	[15] = {
	name = "Sun Tower",
	flavor = "Solar ovens warm custards that Noodl balances carefully during the climb.",
	palette = {
		bgColor    = {0.24, 0.18, 0.26, 1},
		arenaBG    = {0.98, 0.88, 0.78, 1},
		arenaBorder= {1.0, 0.74, 0.46, 1},
		snake      = {0.98, 0.7, 0.4, 1},
		rock       = {0.62, 0.46, 0.54, 1},
		sawColor   = {1.0, 0.6, 0.42, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.6,
		arenaIntensity = 0.34,
	},
	backgroundTheme = "urban",
	backgroundVariant = "celestial",
	},
	[16] = {
	name = "Star Ward",
	flavor = "Starlit corridors glitter with sugar crystals that Noodl gathers while pressing on.",
	palette = {
		bgColor    = {0.1, 0.12, 0.2, 1},
		arenaBG    = {0.54, 0.62, 0.84, 1},
		arenaBorder= {0.88, 0.5, 0.28, 1},
		snake      = {0.98, 0.78, 0.36, 1},
		rock       = {0.34, 0.38, 0.64, 1},
		sawColor   = {0.96, 0.64, 0.38, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.64,
		arenaIntensity = 0.34,
	},
	backgroundTheme = "urban",
	backgroundVariant = "celestial",
	},
	[17] = {
	name = "Drift Garden",
	flavor = "Floating planters shake loose stardust jam that Noodl tucks away.",
	palette = {
		bgColor    = {0.12, 0.11, 0.2, 1},
		arenaBG    = {0.38, 0.28, 0.52, 1},
		arenaBorder= {0.82, 0.5, 0.86, 1},
		snake      = {0.9, 0.68, 0.98, 1},
		rock       = {0.74, 0.58, 0.86, 1},
		sawColor   = {0.94, 0.6, 0.88, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.7,
		arenaIntensity = 0.42,
	},
	backgroundTheme = "laboratory",
	},
	[18] = {
	name = "Night Observatory",
	flavor = "Charts and lenses highlight melon slices so Noodl can track the ripest finds.",
	palette = {
		bgColor    = {0.1, 0.1, 0.18, 1},
		arenaBG    = {0.16, 0.21, 0.32, 1},
		arenaBorder= {0.6, 0.54, 0.86, 1},
		snake      = {0.84, 0.92, 1.0, 1},
		rock       = {0.4, 0.42, 0.62, 1},
		sawColor   = {0.94, 0.74, 1.0, 1},
	},
	backgroundEffect = {
		type = "auroraVeil",
		backdropIntensity = 0.7,
		arenaIntensity = 0.4,
	},
	backgroundTheme = "laboratory",
	},
	[19] = {
	name = "Dusk Court",
	flavor = "Soft light calms the loaded basket while Noodl readies for the last push.",
	palette = {
		bgColor    = {0.1, 0.08, 0.14, 1},
		arenaBG    = {0.16, 0.12, 0.2, 1},
		arenaBorder= {0.48, 0.2, 0.42, 1},
		snake      = {0.82, 0.48, 0.92, 1},
		rock       = {0.46, 0.3, 0.54, 1},
		sawColor   = {0.74, 0.32, 0.68, 1},
	},
	backgroundEffect = {
		type = "voidPulse",
		backdropIntensity = 0.72,
		arenaIntensity = 0.46,
	},
	backgroundTheme = "laboratory",
	},
	[20] = {
	name = "Promise Gate",
	flavor = "At the final gate, Noodl secures the last fruit and coils around the harvest.",
	palette = {
		bgColor    = {0.08, 0.08, 0.12, 1},
		arenaBG    = {0.12, 0.1, 0.18, 1},
		arenaBorder= {0.6, 0.28, 0.66, 1},
		snake      = {0.9, 0.5, 1.0, 1},
		rock       = {0.54, 0.38, 0.74, 1},
		sawColor   = {1.0, 0.54, 0.74, 1},
	},
	backgroundEffect = {
		type = "voidPulse",
		backdropIntensity = 0.78,
		arenaIntensity = 0.5,
	},
	backgroundTheme = "oceanic",
	backgroundVariant = "abyss",
	},
}

Floors.storyTitle = "Harvest Complete"
Floors.victoryMessage = "Noodl hauls the full harvest home, every fruit accounted for."

return Floors
