-- floors.lua

--[[
		Verdant Garden → bright, life-filled welcome
		Echoing Caverns → cooler stone, lingering echoes
		Mushroom Grotto → whimsical glow and spores
		Flooded Catacombs → damp stone and muffled waves
		Ancient Ruins → mysterious decay and hidden machines
		Crystal Hollows → eerie, refracted calm
		Bone Pits → brittle remains underfoot
		The Abyss → oppressive darkness and pressure
		Inferno Gates → searing heat and rising danger
		Obsidian Keep → molten veins beneath black stone
		Ashen Frontier → scorched wastes before the end
		Spirit Crucible → astral winds and wailing phantoms
		The Underworld → final gauntlet of ash and fire
		Celestial Causeway → shimmer of hope and gilded winds
		Sky Spire → false dawn beyond the pit
		Starfall Bastion → starlit bulwark bracing the astral gale
		Nebula Crown → drifting halos frame the precipice of nothing
		Eventide Observatory → mirrored constellations bargain for devotion
		Void Throne → silence condenses into obsidian dominion
		Singularity Gate → all light bends toward the final horizon
]]

local Floors = {
               [1] = {
                               name = "Verdant Garden",
                               flavor = "Noodl chases picnic fruit into a secret burrow, giggling at the accidental adventure.",
				palette = {
						bgColor     = {0.24, 0.32, 0.24, 1}, -- brighter forest green backdrop
						arenaBG     = {0.46, 0.66, 0.39, 1}, -- still bright, grassy playfield
						arenaBorder = {0.52, 0.38, 0.24, 1},  -- warm soil rim to break up the greens
						snake       = {0.12, 0.9, 0.48, 1},  -- vivid spring green snake
						rock        = {0.74, 0.59, 0.38, 1}, -- sun-baked sandstone, pops from grass
				},
				backgroundEffect = {
						type = "softCanopy",
						backdropIntensity = 0.55,
						arenaIntensity = 0.32,
				},
				backgroundTheme = "botanical",
		},
       [2] = {
               name = "Echoing Caverns",
               flavor = "Playful echoes promise berries ahead, so Noodl follows the snack-scented breeze.",
		palette = {
			bgColor    = {0.07, 0.09, 0.14, 1},   -- dim midnight backdrop
			arenaBG    = {0.12, 0.16, 0.24, 1},   -- misty navy floor
			arenaBorder= {0.47, 0.33, 0.58, 1},   -- humming amethyst rim
			snake      = {0.78, 0.86, 0.98, 1},   -- moonlit frost scales
			rock       = {0.36, 0.52, 0.62, 1},   -- cool slate with silver luster
		},
		backgroundEffect = {
			type = "softCavern",
			backdropIntensity = 0.52,
			arenaIntensity = 0.3,
		},
		backgroundTheme = "cavern",
	},
       [3] = {
               name = "Mushroom Grotto",
               flavor = "Glowing caps taste like candy floss; Noodl twirls between them for another bite.",
		palette = {
			bgColor    = {0.12, 0.14, 0.2, 1},  -- teal haze
			arenaBG    = {0.18, 0.22, 0.26, 1},  -- cave stone
			arenaBorder= {0.45, 0.3, 0.55, 1},  -- glowing purple
			snake      = {0.45, 0.95, 0.75, 1}, -- neon cyan-green
			rock       = {0.48, 0.32, 0.55, 1}, -- luminous violet slate
			sawColor   = {0.85, 0.6, 0.9, 1},   -- bright fungal pink-pop
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
               name = "Flooded Catacombs",
               flavor = "Floating citrus bob through flooded halls and Noodl paddles happily after them.",
		palette = {
			bgColor    = {0.03, 0.07, 0.11, 1},   -- abyssal tide
			arenaBG    = {0.06, 0.13, 0.18, 1},   -- drowned slate floor
			arenaBorder= {0.16, 0.39, 0.44, 1},   -- oxidized copper rim
			snake      = {0.82, 0.94, 0.58, 1},   -- bioluminescent kelp
			rock       = {0.24, 0.47, 0.55, 1},   -- wave-worn teal shale
			sawColor   = {0.91, 0.77, 0.46, 1},   -- tarnished lantern brass
		},
		backgroundEffect = {
			type = "softCurrent",
			backdropIntensity = 0.6,
			arenaIntensity = 0.36,
		},
		backgroundTheme = "oceanic",
	},
       [5] = {
               name = "Ancient Ruins",
               flavor = "Sticky altar syrup coats Noodl's nose while puzzles of crumbling stone lead onward.",
		palette = {
			bgColor    = {0.14, 0.12, 0.08, 1}, -- shadowed nave
			arenaBG    = {0.21, 0.18, 0.12, 1}, -- sunken sandstone
			arenaBorder= {0.46, 0.40, 0.22, 1},  -- lichen-lit carvings
			snake      = {0.98, 0.88, 0.48, 1}, -- gleaming relic gold
			rock       = {0.52, 0.38, 0.20, 1},   -- baked umber blocks
			sawColor   = {0.78, 0.74, 0.62, 1},   -- polished bronze gears
		},
		backgroundEffect = {
			type = "ruinMotes",
			backdropIntensity = 0.58,
			arenaIntensity = 0.32,
		},
		backgroundTheme = "machine",
	},
       [6] = {
               name = "Crystal Hollows",
               flavor = "Cold prisms drip sugary dew, and Noodl hums a tune while collecting every sparkle.",
		palette = {
			bgColor    = {0.11, 0.13, 0.17, 1}, -- sapphire veil
			arenaBG    = {0.15, 0.17, 0.22, 1}, -- cold blue
			arenaBorder= {0.4, 0.65, 0.9, 1},   -- refracted glow
			snake      = {0.75, 0.9, 1.0, 1},   -- icy shine
			rock       = {0.45, 0.5, 0.68, 1},   -- frosted indigo crystal
			sawColor   = {0.65, 0.85, 1.0, 1},  -- crystalline edges
		},
		backgroundEffect = {
			type = "auroraVeil",
			backdropIntensity = 0.6,
			arenaIntensity = 0.4,
		},
		backgroundTheme = "arctic",
	},
       [7] = {
               name = "Bone Pits",
               flavor = "Rattling rib-cages hide chewy dried fruit, perfect for a fearless, fun-loving snake.",
		palette = {
			bgColor    = {0.08, 0.07, 0.09, 1},   -- midnight ossuary
			arenaBG    = {0.18, 0.14, 0.11, 1},  -- soot-stained earth
			arenaBorder= {0.82, 0.68, 0.46, 1},   -- polished bone rim
			snake      = {0.95, 0.9, 0.78, 1},    -- sun-bleached ivory
			rock       = {0.62, 0.52, 0.46, 1},   -- sun-bleached splinters that pop against the pit
			sawColor   = {0.62, 0.82, 0.78, 1},   -- necrotic teal glint
		},
		backgroundEffect = {
			type = "echoMist",
			backdropIntensity = 0.5,
			arenaIntensity = 0.28,
		},
		backgroundTheme = "cavern",
		backgroundVariant = "bone",
	},
       [8] = {
               name = "The Abyss",
               flavor = "Low tides thrum with violet jellyfish snacks, daring Noodl into the chasm.",
		palette = {
			bgColor    = {0.08, 0.08, 0.12, 1}, -- depth-black
			arenaBG    = {0.12, 0.12, 0.16, 1}, -- softened void
			arenaBorder= {0.22, 0.12, 0.35, 1}, -- violet rim
			snake      = {0.7, 0.35, 0.85, 1},  -- glowing violet
			rock       = {0.38, 0.45, 0.65, 1},  -- luminous abyssal shale distinct from the void floor
			sawColor   = {0.55, 0.25, 0.6, 1},  -- eerie violet shimmer
		},
		backgroundEffect = {
			type = "voidPulse",
			backdropIntensity = 0.68,
			arenaIntensity = 0.4,
		},
		backgroundTheme = "oceanic",
		backgroundVariant = "abyss",
	},
       [9] = {
               name = "Inferno Gates",
               flavor = "Caramelized peppers pop like candy, and Noodl dances between sparks to taste them.",
		palette = {
			bgColor    = {0.14, 0.05, 0.06, 1}, -- smoke-stained dusk
			arenaBG    = {0.18, 0.06, 0.08, 1}, -- smoldered ember glow
			arenaBorder= {0.78, 0.28, 0.16, 1}, -- molten rim
			snake      = {0.98, 0.6, 0.18, 1},  -- searing amber
			rock       = {0.62, 0.36, 0.28, 1},  -- ember-etched boulders lit by the fires
			sawColor   = {1.0, 0.32, 0.22, 1},  -- incandescent flare
		},
		backgroundEffect = {
			type = "emberDrift",
			backdropIntensity = 0.65,
			arenaIntensity = 0.4,
		},
		backgroundTheme = "desert",
		backgroundVariant = "hell",
	},
       [10] = {
               name = "Obsidian Keep",
               flavor = "Guardians forgot the molten honeycomb, so Noodl raids the glowing hoard.",
		palette = {
			bgColor    = {0.08, 0.06, 0.08, 1},  -- abyssal black
			arenaBG    = {0.14, 0.11, 0.14, 1},  -- polished obsidian
			arenaBorder= {0.45, 0.18, 0.08, 1},  -- smoldering cracks
			snake      = {0.95, 0.45, 0.25, 1},  -- molten ember
			rock       = {0.4, 0.24, 0.32, 1},  -- molten plum glass
			sawColor   = {1.0, 0.35, 0.18, 1},   -- forgefire
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
               name = "Ashen Frontier",
               flavor = "Soot storms swirl around smoky seed brittle, and Noodl bounds through the gusts.",
		palette = {
			bgColor    = {0.11, 0.07, 0.12, 1},  -- soot-stained dusk
			arenaBG    = {0.16, 0.09, 0.15, 1},  -- embered plumplain
			arenaBorder= {0.5, 0.28, 0.16, 1},   -- molten shale ridge
			snake      = {0.72, 0.78, 0.58, 1},  -- sage ember scales
			rock       = {0.55, 0.38, 0.5, 1},  -- rose-tinted pumice cutting through the ash haze
			sawColor   = {0.88, 0.52, 0.32, 1},  -- burnished sparksteel
		},
		backgroundEffect = {
			type = "emberDrift",
			backdropIntensity = 0.58,
			arenaIntensity = 0.34,
		},
		backgroundTheme = "desert",
		backgroundVariant = "inferno",
	},
       [12] = {
               name = "Spirit Crucible",
               flavor = "Friendly phantoms trade misty sorbet for jokes, keeping Noodl grinning in the glow.",
		palette = {
			bgColor    = {0.1, 0.08, 0.14, 1},  -- ethereal violet
			arenaBG    = {0.16, 0.1, 0.2, 1},  -- twilight bloom
			arenaBorder= {0.5, 0.35, 0.75, 1},   -- spectral rim
			snake      = {0.7, 0.85, 1.0, 1},    -- ghostlight
			rock       = {0.64, 0.52, 0.78, 1},   -- brightened spiritstone facets
			sawColor   = {0.8, 0.65, 1.0, 1},    -- spirit steel
		},
		backgroundEffect = {
			type = "auroraVeil",
			backdropIntensity = 0.58,
			arenaIntensity = 0.38,
		},
		backgroundTheme = "laboratory",
	},
       [13] = {
               name = "The Underworld",
               flavor = "Lava chefs flambé exotic fruit, and Noodl samples every sizzling skewer.",
		palette = {
			bgColor    = {0.12, 0.08, 0.1, 1}, -- smoky dark veil
			arenaBG    = {0.14, 0.1, 0.14, 1}, -- charcoal
			arenaBorder= {0.3, 0.05, 0.08, 1},  -- blood red
			snake      = {0.9, 0.15, 0.25, 1},  -- crimson glow
			rock       = {0.58, 0.32, 0.34, 1}, -- glowing cinderstone chunks against the dark arena
			sawColor   = {1.0, 0.1, 0.2, 1},    -- hellsteel
		},
		backgroundEffect = {
			type = "voidPulse",
			backdropIntensity = 0.7,
			arenaIntensity = 0.44,
		},
		backgroundTheme = "desert",
		backgroundVariant = "hell",
	},
       [14] = {
               name = "Celestial Causeway",
               flavor = "Breezy bridges drip star syrup, guiding Noodl upward on sugar-sparkled winds.",
		palette = {
			bgColor    = {0.2, 0.22, 0.29, 1},  -- cool nightfall above the abyss
			arenaBG    = {0.82, 0.86, 0.92, 1},   -- moonlit alabaster path
			arenaBorder= {0.9, 0.76, 0.55, 1},   -- gilded balustrades
			snake      = {0.95, 0.72, 0.45, 1},   -- burnished auric scales
			rock       = {0.36, 0.38, 0.64, 1},   -- indigo-limned plinths silhouetted on the alabaster bridge
			sawColor   = {0.95, 0.7, 0.5, 1},     -- rosy sunlit brass
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
               name = "Sky Spire",
               flavor = "Warm sunrise custard wafts from lofty terraces, pulling Noodl along laughing.",
                palette = {
                        bgColor    = {0.22, 0.17, 0.24, 1},  -- sunrise violet sky
                        arenaBG    = {0.96, 0.9, 0.82, 1},   -- peach-lit terrace
                        arenaBorder= {0.98, 0.64, 0.48, 1},  -- glowing copper filigree
                        snake      = {0.98, 0.76, 0.54, 1},  -- marmalade shimmer
                        rock       = {0.58, 0.46, 0.52, 1},  -- rosy marble pylons
                        sawColor   = {1.0, 0.58, 0.4, 1},    -- amber sunburst
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
               name = "Starfall Bastion",
               flavor = "Meteor crumbs rain into golden bowls; Noodl vaults battlements for the crunchy treats.",
                palette = {
                        bgColor    = {0.14, 0.17, 0.28, 1},  -- deep midnight ramparts
                        arenaBG    = {0.74, 0.8, 0.94, 1},   -- starlit stonework
                        arenaBorder= {0.92, 0.62, 0.42, 1},  -- molten brass crenels
                        snake      = {0.98, 0.78, 0.42, 1},  -- toasted comet glaze
                        rock       = {0.32, 0.36, 0.62, 1},  -- cobalt bulwark bricks
                        sawColor   = {0.96, 0.64, 0.42, 1},  -- shooting-star arcs
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
               name = "Nebula Crown",
               flavor = "Weightless vines offer cosmic jam, letting Noodl bounce with joy between constellations.",
		palette = {
			bgColor    = {0.14, 0.13, 0.21, 1},  -- deep violet firmament
			arenaBG    = {0.42, 0.34, 0.54, 1},  -- dusk-lit bridgework
			arenaBorder= {0.76, 0.48, 0.82, 1},  -- luminous nebular trim
			snake      = {0.85, 0.68, 0.98, 1},  -- starlit wyrm
			rock       = {0.78, 0.6, 0.88, 1},  -- radiant nebulite braces easily seen in the dusk glow
			sawColor   = {0.92, 0.58, 0.85, 1},   -- prismatic edge
		},
		backgroundEffect = {
			type = "auroraVeil",
			backdropIntensity = 0.7,
			arenaIntensity = 0.42,
		},
		backgroundTheme = "laboratory",
	},
       [18] = {
               name = "Eventide Observatory",
               flavor = "Clockwork telescopes grind out frosted fruit tarts, and Noodl licks the gears clean.",
		palette = {
			bgColor    = {0.1, 0.1, 0.18, 1},   -- midnight indigo vault
			arenaBG    = {0.16, 0.2, 0.3, 1},   -- mirrored starsteel
			arenaBorder= {0.58, 0.52, 0.85, 1}, -- prismatic lenswork
			snake      = {0.82, 0.9, 1.0, 1},   -- argent trailblazer
			rock       = {0.38, 0.4, 0.6, 1},   -- star-brushed stone
			sawColor   = {0.92, 0.72, 1.0, 1},  -- refracted glass edge
		},
		backgroundEffect = {
			type = "auroraVeil",
			backdropIntensity = 0.7,
			arenaIntensity = 0.4,
		},
		backgroundTheme = "laboratory",
	},
       [19] = {
               name = "Void Throne",
               flavor = "Silent courtiers serve shimmering grape orbs; Noodl thanks them with a polite tail wag.",
		palette = {
			bgColor    = {0.1, 0.08, 0.14, 1},  -- eventide abyss
			arenaBG    = {0.14, 0.12, 0.18, 1},  -- onyx dais
			arenaBorder= {0.35, 0.12, 0.32, 1},  -- royal voidstone
			snake      = {0.78, 0.42, 0.88, 1},  -- imperial amaranth
			rock       = {0.46, 0.3, 0.54, 1},   -- royal obsidian studded with arcane gloss
			sawColor   = {0.68, 0.28, 0.6, 1},    -- shadowed corona
		},
		backgroundEffect = {
			type = "voidPulse",
			backdropIntensity = 0.72,
			arenaIntensity = 0.46,
		},
		backgroundTheme = "desert",
		backgroundVariant = "hell",
	},
       [20] = {
               name = "Singularity Gate",
               flavor = "A final swirl of gravity tugs at a perfect snack, and Noodl grabs it before racing home.",
		palette = {
			bgColor    = {0.08, 0.08, 0.12, 1},  -- collapsing night
			arenaBG    = {0.12, 0.1, 0.16, 1},  -- gravitic maw
			arenaBorder= {0.58, 0.26, 0.62, 1},  -- eventide flare
			snake      = {0.88, 0.48, 0.98, 1},   -- horizonflare serpent
			rock       = {0.52, 0.38, 0.72, 1},   -- event-horizon geodes glowing above the void
			sawColor   = {0.98, 0.52, 0.72, 1},   -- collapsing corona
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

return Floors
