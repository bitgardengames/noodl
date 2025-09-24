-- floors.lua

--[[
	Garden → bright, life-filled
	Caverns → neutral stone
	Mushroom Grotto → whimsical glow
	Ancient Ruins → mysterious decay
	Crystal Depths → eerie beauty
	Abyss → oppressive darkness
	Inferno Gates → heat and danger
	Underworld → finale, red/charcoal palette

	Additional floor ideas
	Flooded Catacombs (murky blues, greens, with dripping sound/flavor).
	Bone Pits (ashen white, pale sickly snake color).
	Obsidian Keep (lava cracks in black stone).
	Spirit realm, hidden or hardmode only floor? requires something extra to reach

	if we incorporate heaven somehow
	Sky Spire (ethereal whites, golds, like climbing out of hell into false heaven).
]]

local Floors = {
	[1] = {
		name = "Verdant Garden",
		flavor = "The sun is warm, the air sweet with life.",
		palette = {
			bgColor     = {0.20, 0.28, 0.20, 1}, -- darker forest green backdrop
			arenaBG     = {0.42, 0.62, 0.35, 1}, -- still bright, grassy playfield
			arenaBorder = {0.55, 0.75, 0.4, 1},  -- leafy, slightly lighter edge
			snake       = {0.12, 0.9, 0.48, 1},  -- vivid spring green snake
			rock        = {0.68, 0.58, 0.42, 1}, -- warm tan stone
		}
	},
    [2] = {
        name = "Echoing Caverns",
        flavor = "The air cools; faint echoes linger in the dark.",
        palette = {
            bgColor    = {0.07, 0.09, 0.13, 1}, -- bluish depth
            arenaBG    = {0.12, 0.12, 0.15, 1}, -- slate
            arenaBorder= {0.2, 0.28, 0.42, 1},  -- cool blue edge
            snake      = {0.6, 0.65, 0.7, 1},   -- pale stone
            rock       = {0.25, 0.28, 0.32, 1}, -- sheen
        }
    },
    [3] = {
        name = "Mushroom Grotto",
        flavor = "Bioluminescent fungi glow softly in the damp air.",
        palette = {
            bgColor    = {0.08, 0.1, 0.16, 1},  -- teal haze
            arenaBG    = {0.12, 0.16, 0.2, 1},  -- cave stone
            arenaBorder= {0.45, 0.3, 0.55, 1},  -- glowing purple
            snake      = {0.45, 0.95, 0.75, 1}, -- neon cyan-green
            rock       = {0.25, 0.2, 0.3, 1},   -- fungus stone
            sawColor   = {0.85, 0.6, 0.9, 1},   -- bright fungal pink-pop
        }
    },
    [4] = {
        name = "Ancient Ruins",
        flavor = "Forgotten walls crumble; whispers cling to the stone.",
        palette = {
            bgColor    = {0.14, 0.12, 0.08, 1}, -- dim brown haze
            arenaBG    = {0.18, 0.16, 0.12, 1}, -- sandstone
            arenaBorder= {0.4, 0.38, 0.25, 1},  -- moss overtaking
            snake      = {0.95, 0.85, 0.55, 1}, -- faded gold
            rock       = {0.3, 0.25, 0.2, 1},   -- collapsed stone
            sawColor   = {0.7, 0.7, 0.75, 1},   -- pale tarnished steel
        }
    },
    [5] = {
        name = "Crystal Hollows",
        flavor = "Shards of crystal scatter light in eerie hues.",
        palette = {
            bgColor    = {0.06, 0.08, 0.12, 1}, -- sapphire veil
            arenaBG    = {0.09, 0.11, 0.16, 1}, -- cold blue
            arenaBorder= {0.4, 0.65, 0.9, 1},   -- refracted glow
            snake      = {0.75, 0.9, 1.0, 1},   -- icy shine
            rock       = {0.3, 0.35, 0.5, 1},   -- tinted crystal gray
            sawColor   = {0.65, 0.85, 1.0, 1},  -- crystalline edges
        }
    },
    [6] = {
        name = "The Abyss",
        flavor = "The silence is heavy; unseen things stir below.",
        palette = {
            bgColor    = {0.02, 0.02, 0.05, 1}, -- depth-black
            arenaBG    = {0.05, 0.05, 0.08, 1}, -- void
            arenaBorder= {0.22, 0.12, 0.35, 1}, -- violet rim
            snake      = {0.7, 0.35, 0.85, 1},  -- glowing violet
            rock       = {0.08, 0.1, 0.14, 1},  -- deep obsidian
            sawColor   = {0.55, 0.25, 0.6, 1},  -- eerie violet shimmer
        }
    },
    [7] = {
        name = "Inferno Gates",
        flavor = "Heat rises, and the walls bleed with firelight.",
        palette = {
            bgColor    = {0.12, 0.03, 0.03, 1}, -- hazy red
            arenaBG    = {0.15, 0.04, 0.04, 1}, -- burning tone
            arenaBorder= {0.65, 0.25, 0.25, 1}, -- fiery rim
            snake      = {1.0, 0.55, 0.25, 1},  -- ember orange
            rock       = {0.35, 0.15, 0.1, 1},  -- brimstone
            sawColor   = {1.0, 0.25, 0.25, 1},  -- glowing hot red
        }
    },
    [8] = {
        name = "The Underworld",
        flavor = "Ash and shadow coil around you; the end awaits.",
        palette = {
            bgColor    = {0.06, 0.02, 0.04, 1}, -- smoky dark veil
            arenaBG    = {0.08, 0.05, 0.08, 1}, -- charcoal
            arenaBorder= {0.3, 0.05, 0.08, 1},  -- blood red
            snake      = {0.9, 0.15, 0.25, 1},  -- crimson glow
            rock       = {0.18, 0.15, 0.15, 1}, -- ashstone
            sawColor   = {1.0, 0.1, 0.2, 1},    -- hellsteel
        }
    },
}

return Floors