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
        Sky Spire → false dawn beyond the pit
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
                        rock        = {0.74, 0.59, 0.38, 1}, -- sun-baked sandstone, pops from grass
                },
                traits = {"sunlitSanctuary"},
        },
    [2] = {
        name = "Echoing Caverns",
        flavor = "The air cools; faint echoes linger in the dark.",
        palette = {
            bgColor    = {0.07, 0.09, 0.13, 1}, -- bluish depth
            arenaBG    = {0.12, 0.12, 0.15, 1}, -- slate
            arenaBorder= {0.2, 0.28, 0.42, 1},  -- cool blue edge
            snake      = {0.6, 0.65, 0.7, 1},   -- pale stone
            rock       = {0.38, 0.43, 0.52, 1}, -- cool steel-blue highlights
        },
        traits = {"echoingStillness"},
    },
    [3] = {
        name = "Mushroom Grotto",
        flavor = "Bioluminescent fungi glow softly in the damp air.",
        palette = {
            bgColor    = {0.08, 0.1, 0.16, 1},  -- teal haze
            arenaBG    = {0.12, 0.16, 0.2, 1},  -- cave stone
            arenaBorder= {0.45, 0.3, 0.55, 1},  -- glowing purple
            snake      = {0.45, 0.95, 0.75, 1}, -- neon cyan-green
            rock       = {0.48, 0.32, 0.55, 1}, -- luminous violet slate
            sawColor   = {0.85, 0.6, 0.9, 1},   -- bright fungal pink-pop
        },
        traits = {"glowingSpores"},
    },
    [4] = {
        name = "Flooded Catacombs",
        flavor = "Cold water laps at your scales; echoes gurgle through the dark.",
        palette = {
            bgColor    = {0.03, 0.08, 0.1, 1},   -- deep teal void
            arenaBG    = {0.05, 0.12, 0.14, 1},  -- water-stained stone
            arenaBorder= {0.1, 0.28, 0.3, 1},    -- mossy cyan edge
            snake      = {0.35, 0.9, 0.85, 1},   -- luminous aqua
            rock       = {0.34, 0.55, 0.6, 1},    -- sea-washed teal stone
            sawColor   = {0.5, 0.8, 0.85, 1},    -- oxidized steel
        },
        traits = {"waterloggedCatacombs"},
    },
    [5] = {
        name = "Ancient Ruins",
        flavor = "Gears grind beneath the rubble, timing every echoing strike.",
        palette = {
            bgColor    = {0.14, 0.12, 0.08, 1}, -- dim brown haze
            arenaBG    = {0.18, 0.16, 0.12, 1}, -- sandstone
            arenaBorder= {0.4, 0.38, 0.25, 1},  -- moss overtaking
            snake      = {0.95, 0.85, 0.55, 1}, -- faded gold
            rock       = {0.46, 0.38, 0.28, 1},   -- weathered ochre brick
            sawColor   = {0.7, 0.7, 0.75, 1},   -- pale tarnished steel
        },
        traits = {"ancientMachinery", "echoingStillness"},
    },
    [6] = {
        name = "Crystal Hollows",
        flavor = "Luminous shards sing, calming blades in shimmering light.",
        palette = {
            bgColor    = {0.06, 0.08, 0.12, 1}, -- sapphire veil
            arenaBG    = {0.09, 0.11, 0.16, 1}, -- cold blue
            arenaBorder= {0.4, 0.65, 0.9, 1},   -- refracted glow
            snake      = {0.75, 0.9, 1.0, 1},   -- icy shine
            rock       = {0.45, 0.5, 0.68, 1},   -- frosted indigo crystal
            sawColor   = {0.65, 0.85, 1.0, 1},  -- crystalline edges
        },
        traits = {"crystallineResonance", "glowingSpores"},
    },
    [7] = {
        name = "Bone Pits",
        flavor = "Crunching ivory shards warn you: nothing escapes intact.",
        palette = {
            bgColor    = {0.12, 0.11, 0.1, 1},   -- sepulchral haze
            arenaBG    = {0.18, 0.17, 0.16, 1},  -- dusty bone field
            arenaBorder= {0.5, 0.45, 0.38, 1},   -- tarnished bone rim
            snake      = {0.86, 0.84, 0.75, 1},  -- ashen ivory
            rock       = {0.63, 0.5, 0.4, 1},  -- bleached bone stacks
            sawColor   = {0.76, 0.62, 0.52, 1},  -- aged bronze
        },
        traits = {"boneHarvest"},
    },
    [8] = {
        name = "The Abyss",
        flavor = "The silence is heavy; unseen things stir below.",
        palette = {
            bgColor    = {0.02, 0.02, 0.05, 1}, -- depth-black
            arenaBG    = {0.05, 0.05, 0.08, 1}, -- void
            arenaBorder= {0.22, 0.12, 0.35, 1}, -- violet rim
            snake      = {0.7, 0.35, 0.85, 1},  -- glowing violet
            rock       = {0.18, 0.23, 0.32, 1},  -- cold navy basalt
            sawColor   = {0.55, 0.25, 0.6, 1},  -- eerie violet shimmer
        },
        traits = {"echoingStillness", "restlessEarth"},
    },
    [9] = {
        name = "Inferno Gates",
        flavor = "Heat rises, and the walls bleed with firelight.",
        palette = {
            bgColor    = {0.12, 0.03, 0.03, 1}, -- hazy red
            arenaBG    = {0.15, 0.04, 0.04, 1}, -- burning tone
            arenaBorder= {0.65, 0.25, 0.25, 1}, -- fiery rim
            snake      = {1.0, 0.55, 0.25, 1},  -- ember orange
            rock       = {0.52, 0.22, 0.16, 1},  -- ember-scarred basalt
            sawColor   = {1.0, 0.25, 0.25, 1},  -- glowing hot red
        },
        traits = {"infernalPressure"},
    },
    [10] = {
        name = "Obsidian Keep",
        flavor = "Molten veins pulse beneath mirror-black stone.",
        palette = {
            bgColor    = {0.01, 0.01, 0.02, 1},  -- abyssal black
            arenaBG    = {0.07, 0.05, 0.07, 1},  -- polished obsidian
            arenaBorder= {0.45, 0.18, 0.08, 1},  -- smoldering cracks
            snake      = {0.95, 0.45, 0.25, 1},  -- molten ember
            rock       = {0.4, 0.24, 0.32, 1},  -- molten plum glass
            sawColor   = {1.0, 0.35, 0.18, 1},   -- forgefire
        },
        traits = {"obsidianResonance", "infernalPressure"},
    },
    [11] = {
        name = "Ashen Frontier",
        flavor = "Scorched winds whip through charred ossuaries and shattered shale.",
        palette = {
            bgColor    = {0.08, 0.04, 0.03, 1},  -- ember-stained dusk
            arenaBG    = {0.12, 0.06, 0.05, 1},  -- charred earth
            arenaBorder= {0.45, 0.2, 0.12, 1},   -- smoldering ridge
            snake      = {0.88, 0.52, 0.28, 1},  -- wind-burnt scales
            rock       = {0.42, 0.28, 0.24, 1},  -- charred copper shale
            sawColor   = {0.95, 0.4, 0.2, 1},    -- cindersteel
        },
        traits = {"ashenTithe", "boneHarvest"},
    },
    [12] = {
        name = "Spirit Crucible",
        flavor = "Wails of the lost weave through astral gusts that thin the stone.",
        palette = {
            bgColor    = {0.04, 0.02, 0.08, 1},  -- ethereal violet
            arenaBG    = {0.09, 0.05, 0.14, 1},  -- twilight bloom
            arenaBorder= {0.5, 0.35, 0.75, 1},   -- spectral rim
            snake      = {0.7, 0.85, 1.0, 1},    -- ghostlight
            rock       = {0.4, 0.32, 0.52, 1},   -- spectral amethyst shale
            sawColor   = {0.8, 0.65, 1.0, 1},    -- spirit steel
        },
        traits = {"spectralEchoes", "glowingSpores"},
    },
    [13] = {
        name = "The Underworld",
        flavor = "Ash and shadow coil around you; the end awaits.",
        palette = {
            bgColor    = {0.06, 0.02, 0.04, 1}, -- smoky dark veil
            arenaBG    = {0.08, 0.05, 0.08, 1}, -- charcoal
            arenaBorder= {0.3, 0.05, 0.08, 1},  -- blood red
            snake      = {0.9, 0.15, 0.25, 1},  -- crimson glow
            rock       = {0.36, 0.24, 0.26, 1}, -- ember-lit ashstone
            sawColor   = {1.0, 0.1, 0.2, 1},    -- hellsteel
        },
        traits = {"ashenTithe", "infernalPressure"},
    },
    [14] = {
        name = "Sky Spire",
        flavor = "Clouds part to reveal a false dawn of gleaming marble.",
        palette = {
            bgColor    = {0.12, 0.12, 0.18, 1},  -- starlit indigo
            arenaBG    = {0.85, 0.88, 0.92, 1},  -- alabaster platform
            arenaBorder= {0.95, 0.78, 0.45, 1},  -- gilded trim
            snake      = {0.98, 0.85, 0.4, 1},   -- auric serpent
            rock       = {0.55, 0.52, 0.48, 1},  -- dusk-touched marble
            sawColor   = {1.0, 0.65, 0.3, 1},    -- radiant brass
        },
        traits = {"divineAscent", "crystallineResonance"},
    },
}

return Floors
