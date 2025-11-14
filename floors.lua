-- floors.lua
--[[
Garden Gate → Noodl winds through the grove to gather scattered fruit.
Moonwell Caves → Reflected pools guide each pear into reach.
Tide Vault → Rolling tides usher citrus toward the basket.
Gloomshaft Hoist → Echoing caverns drip with glowcaps along the hoist.
Crystal Run → Frozen light chills the apples along the path.
Ember Market → Emberlit stalls keep peppered fruit warm for pickup.
Skywalk → High lanterns reveal every dangling peach.
Promise Gate → The final gate seals the harvest.
]]

local Floors = {
	[1] = {
		name = "Garden Gate",
		flavor = "Noodl winds through the garden, scooping up fruit scattered among the vines.",
                palette = {
                        bgColor     = {0.055, 0.085, 0.070, 1},
                        arenaBG     = {0.165, 0.192, 0.267, 1},
                        arenaBorder = {0.722, 0.663, 0.522, 1},
                        snake       = {0.463, 0.839, 0.765, 1},
                        rock        = {0.69, 0.663, 0.596, 1},
                        sawColor    = {0.824, 0.839, 0.855, 1},
                        backgroundTone = {
                                {0.106, 0.165, 0.137, 1},
                                {0.184, 0.255, 0.212, 0.55},
                        },
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
                        bgColor    = {0.035, 0.055, 0.095, 1},
                        arenaBG    = {0.13, 0.17, 0.25, 1},
                        arenaBorder= {0.44, 0.36, 0.62, 1},
                        snake      = {0.78, 0.86, 0.98, 1},
                        rock       = {0.41, 0.58, 0.71, 1},
                        sawColor   = {0.69, 0.69, 0.74, 1},
                        backgroundTone = {
                                {0.071, 0.102, 0.169, 1},
                                {0.114, 0.173, 0.251, 0.58},
                        },
                },
                backgroundEffect = {
                        type = "softCavern",
                        backdropIntensity = 0.54,
			arenaIntensity = 0.32,
		},
		backgroundTheme = "cavern",
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
                        backgroundTone = {
                                {0.059, 0.114, 0.149, 1},
                                {0.11, 0.184, 0.227, 0.58},
                        },
                },
                backgroundEffect = {
                        type = "abyssDrift",
                        backdropIntensity = 0.64,
			arenaIntensity = 0.38,
		},
		backgroundTheme = "oceanic",
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
                        backgroundTone = {
                                {0.051, 0.094, 0.129, 1},
                                {0.102, 0.157, 0.192, 0.6},
                        },
                },
                backgroundEffect = {
                        type = "mushroomPulse",
			backdropIntensity = 0.68,
			arenaIntensity = 0.42,
		},
		backgroundTheme = "cavern",
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
                        backgroundTone = {
                                {0.063, 0.11, 0.149, 1},
                                {0.125, 0.192, 0.263, 0.55},
                        },
                },
                backgroundEffect = {
                        type = "auroraVeil",
			backdropIntensity = 0.62,
			arenaIntensity = 0.42,
		},
		backgroundTheme = "arctic",
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
                        backgroundTone = {
                                {0.157, 0.078, 0.047, 1},
                                {0.227, 0.125, 0.075, 0.58},
                        },
                },
                backgroundEffect = {
                        type = "emberDrift",
			backdropIntensity = 0.62,
			arenaIntensity = 0.38,
		},
		backgroundTheme = "desert",
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
                        backgroundTone = {
                                {0.224, 0.275, 0.365, 1},
                                {0.29, 0.361, 0.463, 0.5},
                        },
                },
                backgroundEffect = {
                        type = "auroraVeil",
			backdropIntensity = 0.48,
			arenaIntensity = 0.28,
		},
		backgroundTheme = "urban",
		backgroundVariant = "celestial",
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
                        backgroundTone = {
                                {0.118, 0.059, 0.18, 1},
                                {0.176, 0.106, 0.247, 0.62},
                        },
                },
                backgroundEffect = {
                        type = "voidPulse",
			backdropIntensity = 0.74,
			arenaIntensity = 0.46,
		},
		backgroundTheme = "urban",
		backgroundVariant = "celestial",
	},
}

Floors.storyTitle = "Harvest Complete"
Floors.victoryMessage = "Noodl hauls the full harvest home, every fruit accounted for."

return Floors
