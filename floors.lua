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
                threat = "A gentle opening where fruit is plentiful and blades are scarce.",
                palette = {
                        bgColor     = {0.20, 0.28, 0.20, 1}, -- darker forest green backdrop
                        arenaBG     = {0.42, 0.62, 0.35, 1}, -- still bright, grassy playfield
                        arenaBorder = {0.55, 0.75, 0.4, 1},  -- leafy, slightly lighter edge
                        snake       = {0.12, 0.9, 0.48, 1},  -- vivid spring green snake
                        rock        = {0.68, 0.58, 0.42, 1}, -- warm tan stone
                },
                loadout = {
                        fruitGoal = 6,
                        rocks = 3,
                        saws = 0,
                        rockSpawnChance = 0.18,
                        comboWindow = 2.6,
                },
                tuning = {
                        sawSpeed = 0.9,
                        sawSpin = 0.9,
                        stallOnFruit = 0.6,
                        fruitWeights = {
                                Apple = { mult = 1.1 },
                                Banana = { mult = 0.8 },
                                fallbackMult = 0.9,
                        },
                },
                traits = {"sunlitSanctuary"},
        },
    [2] = {
        name = "Echoing Caverns",
        flavor = "The air cools; faint echoes linger in the dark.",
        threat = "Shifting stone and the first whirring saw keep you on edge.",
        palette = {
            bgColor    = {0.07, 0.09, 0.13, 1}, -- bluish depth
            arenaBG    = {0.12, 0.12, 0.15, 1}, -- slate
            arenaBorder= {0.2, 0.28, 0.42, 1},  -- cool blue edge
            snake      = {0.6, 0.65, 0.7, 1},   -- pale stone
            rock       = {0.25, 0.28, 0.32, 1}, -- sheen
        },
        loadout = {
            fruitGoal = 9,
            rocks = 5,
            saws = 1,
            rockSpawnChance = 0.22,
            comboWindow = 2.4,
        },
        tuning = {
            sawSpeed = 0.95,
            sawSpin = 0.95,
            stallOnFruit = 0.45,
            fruitWeights = {
                Banana = { mult = 1.1 },
                Blueberry = { mult = 1.1 },
                fallbackMult = 0.95,
            },
        },
        traits = {"restlessEarth"},
    },
    [3] = {
        name = "Mushroom Grotto",
        flavor = "Bioluminescent fungi glow softly in the damp air.",
        threat = "Sporelight slows the chase, but the harvest stretches deeper.",
        palette = {
            bgColor    = {0.08, 0.1, 0.16, 1},  -- teal haze
            arenaBG    = {0.12, 0.16, 0.2, 1},  -- cave stone
            arenaBorder= {0.45, 0.3, 0.55, 1},  -- glowing purple
            snake      = {0.45, 0.95, 0.75, 1}, -- neon cyan-green
            rock       = {0.25, 0.2, 0.3, 1},   -- fungus stone
            sawColor   = {0.85, 0.6, 0.9, 1},   -- bright fungal pink-pop
        },
        loadout = {
            fruitGoal = 11,
            rocks = 6,
            saws = 1,
            rockSpawnChance = 0.24,
            comboWindow = 2.3,
        },
        tuning = {
            sawSpeed = 0.9,
            sawSpin = 0.9,
            stallOnFruit = 0.7,
            fruitWeights = {
                Blueberry = { mult = 1.3, min = 6 },
                GoldenPear = { mult = 1.1 },
                fallbackMult = 0.9,
            },
        },
        traits = {"glowingSpores"},
    },
    [4] = {
        name = "Ancient Ruins",
        flavor = "Forgotten walls crumble; whispers cling to the stone.",
        threat = "Clockwork guardians rouse, stacking stone and twin blades against you.",
        palette = {
            bgColor    = {0.14, 0.12, 0.08, 1}, -- dim brown haze
            arenaBG    = {0.18, 0.16, 0.12, 1}, -- sandstone
            arenaBorder= {0.4, 0.38, 0.25, 1},  -- moss overtaking
            snake      = {0.95, 0.85, 0.55, 1}, -- faded gold
            rock       = {0.3, 0.25, 0.2, 1},   -- collapsed stone
            sawColor   = {0.7, 0.7, 0.75, 1},   -- pale tarnished steel
        },
        loadout = {
            fruitGoal = 14,
            rocks = 8,
            saws = 2,
            rockSpawnChance = 0.28,
            comboWindow = 2.2,
        },
        tuning = {
            sawSpeed = 1.0,
            sawSpin = 1.05,
            stallOnFruit = 0.4,
            fruitWeights = {
                GoldenPear = { mult = 1.2, min = 3 },
            },
        },
        traits = {"ancientMachinery"},
    },
    [5] = {
        name = "Crystal Hollows",
        flavor = "Shards of crystal scatter light in eerie hues.",
        threat = "Refractions slow blades but the path stretches long and cold.",
        palette = {
            bgColor    = {0.06, 0.08, 0.12, 1}, -- sapphire veil
            arenaBG    = {0.09, 0.11, 0.16, 1}, -- cold blue
            arenaBorder= {0.4, 0.65, 0.9, 1},   -- refracted glow
            snake      = {0.75, 0.9, 1.0, 1},   -- icy shine
            rock       = {0.3, 0.35, 0.5, 1},   -- tinted crystal gray
            sawColor   = {0.65, 0.85, 1.0, 1},  -- crystalline edges
        },
        loadout = {
            fruitGoal = 17,
            rocks = 9,
            saws = 2,
            rockSpawnChance = 0.3,
            comboWindow = 2.1,
        },
        tuning = {
            sawSpeed = 0.9,
            sawSpin = 0.85,
            stallOnFruit = 0.5,
            fruitWeights = {
                GoldenPear = { mult = 1.4, min = 4 },
                Dragonfruit = { mult = 1.1, min = 0.25 },
                fallbackMult = 0.95,
            },
        },
        traits = {"crystallineResonance"},
    },
    [6] = {
        name = "The Abyss",
        flavor = "The silence is heavy; unseen things stir below.",
        threat = "The void presses in with relentless stone and extra blades.",
        palette = {
            bgColor    = {0.02, 0.02, 0.05, 1}, -- depth-black
            arenaBG    = {0.05, 0.05, 0.08, 1}, -- void
            arenaBorder= {0.22, 0.12, 0.35, 1}, -- violet rim
            snake      = {0.7, 0.35, 0.85, 1},  -- glowing violet
            rock       = {0.08, 0.1, 0.14, 1},  -- deep obsidian
            sawColor   = {0.55, 0.25, 0.6, 1},  -- eerie violet shimmer
        },
        loadout = {
            fruitGoal = 20,
            rocks = 11,
            saws = 3,
            rockSpawnChance = 0.33,
            comboWindow = 2.0,
        },
        tuning = {
            sawSpeed = 1.05,
            sawSpin = 1.0,
            stallOnFruit = 0.35,
            fruitWeights = {
                Blueberry = { mult = 1.2 },
                Dragonfruit = { mult = 1.4, min = 0.3 },
            },
        },
        traits = {"echoingStillness", "restlessEarth"},
    },
    [7] = {
        name = "Inferno Gates",
        flavor = "Heat rises, and the walls bleed with firelight.",
        threat = "Flames drive saws harder while molten stone keeps falling.",
        palette = {
            bgColor    = {0.12, 0.03, 0.03, 1}, -- hazy red
            arenaBG    = {0.15, 0.04, 0.04, 1}, -- burning tone
            arenaBorder= {0.65, 0.25, 0.25, 1}, -- fiery rim
            snake      = {1.0, 0.55, 0.25, 1},  -- ember orange
            rock       = {0.35, 0.15, 0.1, 1},  -- brimstone
            sawColor   = {1.0, 0.25, 0.25, 1},  -- glowing hot red
        },
        loadout = {
            fruitGoal = 23,
            rocks = 12,
            saws = 3,
            rockSpawnChance = 0.36,
            comboWindow = 1.9,
        },
        tuning = {
            sawSpeed = 1.12,
            sawSpin = 1.15,
            stallOnFruit = 0.25,
            fruitWeights = {
                Banana = { mult = 0.9 },
                GoldenPear = { mult = 1.25 },
                fallbackMult = 1.0,
            },
        },
        traits = {"infernalPressure"},
    },
    [8] = {
        name = "The Underworld",
        flavor = "Ash and shadow coil around you; the end awaits.",
        threat = "Ashstorms and molten cracks force brutal pacing and more blades.",
        palette = {
            bgColor    = {0.06, 0.02, 0.04, 1}, -- smoky dark veil
            arenaBG    = {0.08, 0.05, 0.08, 1}, -- charcoal
            arenaBorder= {0.3, 0.05, 0.08, 1},  -- blood red
            snake      = {0.9, 0.15, 0.25, 1},  -- crimson glow
            rock       = {0.18, 0.15, 0.15, 1}, -- ashstone
            sawColor   = {1.0, 0.1, 0.2, 1},    -- hellsteel
        },
        loadout = {
            fruitGoal = 27,
            rocks = 13,
            saws = 4,
            rockSpawnChance = 0.38,
            comboWindow = 1.85,
        },
        tuning = {
            sawSpeed = 1.08,
            sawSpin = 1.1,
            stallOnFruit = 0.3,
            fruitWeights = {
                GoldenPear = { mult = 1.3 },
                Dragonfruit = { mult = 1.5, min = 0.4 },
                fallbackMult = 1.0,
            },
        },
        traits = {"ashenTithe", "glowingSpores"},
    },
    [9] = {
        name = "Flooded Catacombs",
        flavor = "Cold water laps at your scales; echoes gurgle through the dark.",
        threat = "Floodwaters slow blades and rocks but punish sloppy footing.",
        palette = {
            bgColor    = {0.03, 0.08, 0.1, 1},   -- deep teal void
            arenaBG    = {0.05, 0.12, 0.14, 1},  -- water-stained stone
            arenaBorder= {0.1, 0.28, 0.3, 1},    -- mossy cyan edge
            snake      = {0.35, 0.9, 0.85, 1},   -- luminous aqua
            rock       = {0.2, 0.35, 0.4, 1},    -- soaked slate
            sawColor   = {0.5, 0.8, 0.85, 1},    -- oxidized steel
        },
        loadout = {
            fruitGoal = 30,
            rocks = 11,
            saws = 4,
            rockSpawnChance = 0.32,
            comboWindow = 2.3,
        },
        tuning = {
            sawSpeed = 0.85,
            sawSpin = 0.9,
            stallOnFruit = 0.9,
            fruitWeights = {
                Blueberry = { mult = 1.2 },
                GoldenPear = { mult = 1.1 },
                fallbackMult = 0.95,
            },
        },
        traits = {"waterloggedCatacombs"},
    },
    [10] = {
        name = "Bone Pits",
        flavor = "Crunching ivory shards warn you: nothing escapes intact.",
        threat = "Brittle bone piles crowd the arena as saws quicken their hunt.",
        palette = {
            bgColor    = {0.12, 0.11, 0.1, 1},   -- sepulchral haze
            arenaBG    = {0.18, 0.17, 0.16, 1},  -- dusty bone field
            arenaBorder= {0.5, 0.45, 0.38, 1},   -- tarnished bone rim
            snake      = {0.86, 0.84, 0.75, 1},  -- ashen ivory
            rock       = {0.42, 0.36, 0.32, 1},  -- brittle remains
            sawColor   = {0.76, 0.62, 0.52, 1},  -- aged bronze
        },
        loadout = {
            fruitGoal = 34,
            rocks = 16,
            saws = 4,
            rockSpawnChance = 0.4,
            comboWindow = 1.9,
        },
        tuning = {
            sawSpeed = 1.05,
            sawSpin = 1.1,
            stallOnFruit = 0.35,
            fruitWeights = {
                Banana = { mult = 1.1 },
                GoldenPear = { mult = 1.2 },
                Dragonfruit = { mult = 1.2, min = 0.3 },
            },
        },
        traits = {"boneHarvest", "restlessEarth"},
    },
    [11] = {
        name = "Obsidian Keep",
        flavor = "Molten veins pulse beneath mirror-black stone.",
        threat = "The keep's guardians surge with volatile speed and spin.",
        palette = {
            bgColor    = {0.01, 0.01, 0.02, 1},  -- abyssal black
            arenaBG    = {0.07, 0.05, 0.07, 1},  -- polished obsidian
            arenaBorder= {0.45, 0.18, 0.08, 1},  -- smoldering cracks
            snake      = {0.95, 0.45, 0.25, 1},  -- molten ember
            rock       = {0.22, 0.16, 0.18, 1},  -- volcanic glass
            sawColor   = {1.0, 0.35, 0.18, 1},   -- forgefire
        },
        loadout = {
            fruitGoal = 38,
            rocks = 18,
            saws = 5,
            rockSpawnChance = 0.42,
            comboWindow = 1.8,
        },
        tuning = {
            sawSpeed = 1.18,
            sawSpin = 1.25,
            stallOnFruit = 0.25,
            fruitWeights = {
                GoldenPear = { mult = 1.2 },
                Dragonfruit = { mult = 1.35, min = 0.4 },
            },
        },
        traits = {"obsidianResonance", "infernalPressure"},
    },
    [12] = {
        name = "Spirit Crucible",
        flavor = "Wails of the lost weave through a glowing astral gale.",
        threat = "Spectral winds lengthen combos while thinning stone defenses.",
        palette = {
            bgColor    = {0.04, 0.02, 0.08, 1},  -- ethereal violet
            arenaBG    = {0.09, 0.05, 0.14, 1},  -- twilight bloom
            arenaBorder= {0.5, 0.35, 0.75, 1},   -- spectral rim
            snake      = {0.7, 0.85, 1.0, 1},    -- ghostlight
            rock       = {0.2, 0.18, 0.28, 1},   -- phantasmal stone
            sawColor   = {0.8, 0.65, 1.0, 1},    -- spirit steel
        },
        loadout = {
            fruitGoal = 42,
            rocks = 16,
            saws = 5,
            rockSpawnChance = 0.36,
            comboWindow = 2.2,
            crashShields = 1,
        },
        tuning = {
            sawSpeed = 0.95,
            sawSpin = 0.9,
            stallOnFruit = 0.5,
            fruitWeights = {
                Blueberry = { mult = 1.25 },
                Dragonfruit = { mult = 1.4, min = 0.35 },
                fallbackMult = 0.95,
            },
        },
        traits = {"spectralEchoes", "echoingStillness"},
    },
    [13] = {
        name = "Sky Spire",
        flavor = "Clouds part to reveal a false dawn of gleaming marble.",
        threat = "Radiant blades and thin air leave little room for mistakes.",
        palette = {
            bgColor    = {0.12, 0.12, 0.18, 1},  -- starlit indigo
            arenaBG    = {0.85, 0.88, 0.92, 1},  -- alabaster platform
            arenaBorder= {0.95, 0.78, 0.45, 1},  -- gilded trim
            snake      = {0.98, 0.85, 0.4, 1},   -- auric serpent
            rock       = {0.75, 0.72, 0.68, 1},  -- polished stone
            sawColor   = {1.0, 0.65, 0.3, 1},    -- radiant brass
        },
        loadout = {
            fruitGoal = 48,
            rocks = 14,
            saws = 6,
            rockSpawnChance = 0.34,
            comboWindow = 2.0,
        },
        tuning = {
            sawSpeed = 1.1,
            sawSpin = 1.15,
            stallOnFruit = 0.4,
            fruitWeights = {
                GoldenPear = { mult = 1.35 },
                Dragonfruit = { mult = 1.5, min = 0.45 },
            },
        },
        traits = {"divineAscent", "crystallineResonance"},
    },
}

return Floors
