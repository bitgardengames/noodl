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
        Void Throne → silence condenses into obsidian dominion
        Singularity Gate → all light bends toward the final horizon
]]

local Floors = {
        [1] = {
                name = "Verdant Garden",
                flavor = "Noodl, serpent sentinel of the Sky Orchard, feels it shudder; the Heart-root far below is starving, and only fresh fruit pulses can keep it awake.",
                palette = {
                        bgColor     = {0.24, 0.32, 0.24, 1}, -- brighter forest green backdrop
                        arenaBG     = {0.46, 0.66, 0.39, 1}, -- still bright, grassy playfield
                        arenaBorder = {0.55, 0.75, 0.4, 1},  -- leafy, slightly lighter edge
                        snake       = {0.12, 0.9, 0.48, 1},  -- vivid spring green snake
                        rock        = {0.74, 0.59, 0.38, 1}, -- sun-baked sandstone, pops from grass
                },
                backgroundEffect = {
                        type = "softCanopy",
                        backdropIntensity = 0.55,
                        arenaIntensity = 0.32,
                },
                backgroundTheme = "botanical",
                traits = {"sunlitSanctuary"},
        },
    [2] = {
        name = "Echoing Caverns",
        flavor = "Echoes chase Noodl deeper, repeating the Heart-root's fading thrum and urging every fruit to be carried before the rhythm stops.",
        palette = {
            bgColor    = {0.12, 0.14, 0.18, 1}, -- bluish depth
            arenaBG    = {0.18, 0.19, 0.23, 1}, -- softened slate
            arenaBorder= {0.2, 0.28, 0.42, 1},  -- cool blue edge
            snake      = {0.6, 0.65, 0.7, 1},   -- pale stone
            rock       = {0.38, 0.43, 0.52, 1}, -- cool steel-blue highlights
        },
        backgroundEffect = {
            type = "softCavern",
            backdropIntensity = 0.52,
            arenaIntensity = 0.3,
        },
        backgroundTheme = "cavern",
        traits = {"echoingStillness"},
    },
    [3] = {
        name = "Mushroom Grotto",
        flavor = "Glowcaps blink a warning: the hollow storm is close behind, and fruitlight is the only beacon bright enough to outshine it.",
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
        traits = {"glowingSpores"},
    },
    [4] = {
        name = "Flooded Catacombs",
        flavor = "Flooded arches trade rumors that the Heart-room is drowning in shadow, counting on Noodl to ferry enough fruit to relight the pumps.",
        palette = {
            bgColor    = {0.08, 0.14, 0.16, 1},   -- deep teal void
            arenaBG    = {0.1, 0.18, 0.22, 1},  -- water-stained stone
            arenaBorder= {0.1, 0.28, 0.3, 1},    -- mossy cyan edge
            snake      = {0.35, 0.9, 0.85, 1},   -- luminous aqua
            rock       = {0.34, 0.55, 0.6, 1},    -- sea-washed teal stone
            sawColor   = {0.5, 0.8, 0.85, 1},    -- oxidized steel
        },
        backgroundEffect = {
            type = "softCurrent",
            backdropIntensity = 0.6,
            arenaIntensity = 0.36,
        },
        backgroundTheme = "oceanic",
        traits = {"waterloggedCatacombs"},
    },
    [5] = {
        name = "Ancient Ruins",
        flavor = "Clockwork reliefs spin up ancient conduits, hungry for fruit-charge to unlock the sealed descent before the orchard tears free.",
        palette = {
            bgColor    = {0.2, 0.18, 0.14, 1}, -- dim brown haze
            arenaBG    = {0.24, 0.22, 0.18, 1}, -- sandstone
            arenaBorder= {0.4, 0.38, 0.25, 1},  -- moss overtaking
            snake      = {0.95, 0.85, 0.55, 1}, -- faded gold
            rock       = {0.46, 0.38, 0.28, 1},   -- weathered ochre brick
            sawColor   = {0.7, 0.7, 0.75, 1},   -- pale tarnished steel
        },
        backgroundEffect = {
            type = "ruinMotes",
            backdropIntensity = 0.58,
            arenaIntensity = 0.32,
        },
        backgroundTheme = "machine",
        traits = {"ancientMachinery", "echoingStillness"},
    },
    [6] = {
        name = "Crystal Hollows",
        flavor = "Crystal prisms fracture the last sunlight, storing it in fruit seeds; if Noodl falters, the orchard's tether will snap.",
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
        traits = {"crystallineResonance", "glowingSpores"},
    },
    [7] = {
        name = "Bone Pits",
        flavor = "Bone wind chimes tally the roots already gone, promising that fruitlight is the only oath the abyss still honors.",
        palette = {
            bgColor    = {0.17, 0.16, 0.15, 1},   -- sepulchral haze
            arenaBG    = {0.24, 0.23, 0.22, 1},  -- dusty bone field
            arenaBorder= {0.5, 0.45, 0.38, 1},   -- tarnished bone rim
            snake      = {0.86, 0.84, 0.75, 1},  -- ashen ivory
            rock       = {0.63, 0.5, 0.4, 1},  -- bleached bone stacks
            sawColor   = {0.76, 0.62, 0.52, 1},  -- aged bronze
        },
        backgroundEffect = {
            type = "echoMist",
            backdropIntensity = 0.5,
            arenaIntensity = 0.28,
        },
        backgroundTheme = "cavern",
        backgroundVariant = "bone",
        traits = {"boneHarvest"},
    },
    [8] = {
        name = "The Abyss",
        flavor = "Shadows curl like vines severed from home, and even the abyss watches to see if Noodl's satchel of fruit still glows.",
        palette = {
            bgColor    = {0.08, 0.08, 0.12, 1}, -- depth-black
            arenaBG    = {0.12, 0.12, 0.16, 1}, -- softened void
            arenaBorder= {0.22, 0.12, 0.35, 1}, -- violet rim
            snake      = {0.7, 0.35, 0.85, 1},  -- glowing violet
            rock       = {0.18, 0.23, 0.32, 1},  -- cold navy basalt
            sawColor   = {0.55, 0.25, 0.6, 1},  -- eerie violet shimmer
        },
        backgroundEffect = {
            type = "voidPulse",
            backdropIntensity = 0.68,
            arenaIntensity = 0.4,
        },
        backgroundTheme = "oceanic",
        backgroundVariant = "abyss",
        traits = {"echoingStillness", "restlessEarth"},
    },
    [9] = {
        name = "Inferno Gates",
        flavor = "Inferno vents roar awake, smelling the hollow storm rising; only burning through with fruit-fueled gates will keep it from the orchard.",
        palette = {
            bgColor    = {0.18, 0.08, 0.08, 1}, -- hazy red
            arenaBG    = {0.22, 0.08, 0.08, 1}, -- burning tone
            arenaBorder= {0.65, 0.25, 0.25, 1}, -- fiery rim
            snake      = {1.0, 0.55, 0.25, 1},  -- ember orange
            rock       = {0.52, 0.22, 0.16, 1},  -- ember-scarred basalt
            sawColor   = {1.0, 0.25, 0.25, 1},  -- glowing hot red
        },
        backgroundEffect = {
            type = "emberDrift",
            backdropIntensity = 0.65,
            arenaIntensity = 0.4,
        },
        backgroundTheme = "desert",
        backgroundVariant = "hell",
        traits = {"infernalPressure"},
    },
    [10] = {
        name = "Obsidian Keep",
        flavor = "An obsidian chamber calibrates the Heart's armor, demanding fruit sparks before it seals the way for good.",
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
        traits = {"obsidianResonance", "infernalPressure"},
    },
    [11] = {
        name = "Ashen Frontier",
        flavor = "Ash storms whisper that the hollow storm is almost here, measuring how many fruit pulses Noodl can spare for the failing beacons.",
        palette = {
            bgColor    = {0.14, 0.08, 0.07, 1},  -- ember-stained dusk
            arenaBG    = {0.18, 0.1, 0.09, 1},  -- charred earth
            arenaBorder= {0.45, 0.2, 0.12, 1},   -- smoldering ridge
            snake      = {0.88, 0.52, 0.28, 1},  -- wind-burnt scales
            rock       = {0.42, 0.28, 0.24, 1},  -- charred copper shale
            sawColor   = {0.95, 0.4, 0.2, 1},    -- cindersteel
        },
        backgroundEffect = {
            type = "emberDrift",
            backdropIntensity = 0.58,
            arenaIntensity = 0.34,
        },
        backgroundTheme = "desert",
        backgroundVariant = "inferno",
        traits = {"ashenTithe", "boneHarvest"},
    },
    [12] = {
        name = "Spirit Crucible",
        flavor = "Spirits cradle cracked root-lines, feeding on fruitlight as they steady the passage toward the Heart's ember.",
        palette = {
            bgColor    = {0.1, 0.08, 0.14, 1},  -- ethereal violet
            arenaBG    = {0.16, 0.1, 0.2, 1},  -- twilight bloom
            arenaBorder= {0.5, 0.35, 0.75, 1},   -- spectral rim
            snake      = {0.7, 0.85, 1.0, 1},    -- ghostlight
            rock       = {0.4, 0.32, 0.52, 1},   -- spectral amethyst shale
            sawColor   = {0.8, 0.65, 1.0, 1},    -- spirit steel
        },
        backgroundEffect = {
            type = "auroraVeil",
            backdropIntensity = 0.58,
            arenaIntensity = 0.38,
        },
        backgroundTheme = "laboratory",
        traits = {"spectralEchoes", "glowingSpores"},
    },
    [13] = {
        name = "The Underworld",
        flavor = "Underworld stewards lay out a path to the Heart, muttering that without a last surge of fruit the orchard will fall through the sky.",
        palette = {
            bgColor    = {0.12, 0.08, 0.1, 1}, -- smoky dark veil
            arenaBG    = {0.14, 0.1, 0.14, 1}, -- charcoal
            arenaBorder= {0.3, 0.05, 0.08, 1},  -- blood red
            snake      = {0.9, 0.15, 0.25, 1},  -- crimson glow
            rock       = {0.36, 0.24, 0.26, 1}, -- ember-lit ashstone
            sawColor   = {1.0, 0.1, 0.2, 1},    -- hellsteel
        },
        backgroundEffect = {
            type = "voidPulse",
            backdropIntensity = 0.7,
            arenaIntensity = 0.44,
        },
        backgroundTheme = "desert",
        backgroundVariant = "hell",
        traits = {"ashenTithe", "infernalPressure"},
    },
    [14] = {
        name = "Celestial Causeway",
        flavor = "Celestial bridges tremble, streaming pleas upward; Noodl's collected fruit must ignite the guiding stars before they sputter out.",
        palette = {
            bgColor    = {0.2, 0.22, 0.29, 1},  -- cool nightfall above the abyss
            arenaBG    = {0.82, 0.86, 0.92, 1},   -- moonlit alabaster path
            arenaBorder= {0.9, 0.76, 0.55, 1},   -- gilded balustrades
            snake      = {0.95, 0.72, 0.45, 1},   -- burnished auric scales
            rock       = {0.62, 0.6, 0.68, 1},   -- pearlescent pillars
            sawColor   = {0.95, 0.7, 0.5, 1},     -- rosy sunlit brass
        },
        backgroundEffect = {
            type = "auroraVeil",
            backdropIntensity = 0.62,
            arenaIntensity = 0.36,
        },
        backgroundTheme = "urban",
        backgroundVariant = "celestial",
        traits = {"divineAscent", "spectralEchoes"},
    },
    [15] = {
        name = "Sky Spire",
        flavor = "The Sky Spire hums the Heart-root's lullaby in reverse, buying seconds while Noodl shoulders more fruit toward the breach.",
        palette = {
            bgColor    = {0.16, 0.16, 0.22, 1},  -- starlit indigo
            arenaBG    = {0.88, 0.91, 0.94, 1},  -- alabaster platform
            arenaBorder= {0.95, 0.78, 0.45, 1},  -- gilded trim
            snake      = {0.98, 0.85, 0.4, 1},   -- auric serpent
            rock       = {0.55, 0.52, 0.48, 1},  -- dusk-touched marble
            sawColor   = {1.0, 0.65, 0.3, 1},    -- radiant brass
        },
        backgroundEffect = {
            type = "auroraVeil",
            backdropIntensity = 0.6,
            arenaIntensity = 0.34,
        },
        backgroundTheme = "urban",
        backgroundVariant = "celestial",
        traits = {"divineAscent", "crystallineResonance"},
    },
    [16] = {
        name = "Starfall Bastion",
        flavor = "Starfall ramparts crackle as the hollow storm slams closer, and each fruit becomes a shield tile between the orchard and the void.",
        palette = {
            bgColor    = {0.2, 0.21, 0.28, 1},  -- twilight navy mantle
            arenaBG    = {0.82, 0.86, 0.96, 1},  -- moonlit parapets
            arenaBorder= {0.96, 0.74, 0.52, 1},  -- gilded battlements
            snake      = {0.98, 0.82, 0.48, 1},  -- auric champion
            rock       = {0.58, 0.56, 0.64, 1},  -- polished starlit stone
            sawColor   = {0.98, 0.68, 0.4, 1},   -- cometforged brass
        },
        backgroundEffect = {
            type = "auroraVeil",
            backdropIntensity = 0.64,
            arenaIntensity = 0.34,
        },
        backgroundTheme = "urban",
        backgroundVariant = "celestial",
        traits = {"spectralEchoes", "divineAscent"},
    },
    [17] = {
        name = "Nebula Crown",
        flavor = "Nebula crowns unravel into warning flares, asking Noodl to weave the fruitlight into a final thread that can reach the Heart.",
        palette = {
            bgColor    = {0.14, 0.13, 0.21, 1},  -- deep violet firmament
            arenaBG    = {0.42, 0.34, 0.54, 1},  -- dusk-lit bridgework
            arenaBorder= {0.76, 0.48, 0.82, 1},  -- luminous nebular trim
            snake      = {0.85, 0.68, 0.98, 1},  -- starlit wyrm
            rock       = {0.42, 0.32, 0.55, 1},  -- amethyst span
            sawColor   = {0.92, 0.58, 0.85, 1},   -- prismatic edge
        },
        backgroundEffect = {
            type = "auroraVeil",
            backdropIntensity = 0.7,
            arenaIntensity = 0.42,
        },
        backgroundTheme = "laboratory",
        traits = {"spectralEchoes", "glowingSpores"},
    },
    [18] = {
        name = "Void Throne",
        flavor = "Void courtiers drift aside, sensing the Heart through Noodl's satchel and preparing the throne for whichever light arrives first.",
        palette = {
            bgColor    = {0.1, 0.08, 0.14, 1},  -- eventide abyss
            arenaBG    = {0.14, 0.12, 0.18, 1},  -- onyx dais
            arenaBorder= {0.35, 0.12, 0.32, 1},  -- royal voidstone
            snake      = {0.78, 0.42, 0.88, 1},  -- imperial amaranth
            rock       = {0.24, 0.2, 0.32, 1},   -- sigiled basalt
            sawColor   = {0.68, 0.28, 0.6, 1},    -- shadowed corona
        },
        backgroundEffect = {
            type = "voidPulse",
            backdropIntensity = 0.72,
            arenaIntensity = 0.46,
        },
        backgroundTheme = "desert",
        backgroundVariant = "hell",
        traits = {"obsidianResonance", "infernalPressure"},
    },
    [19] = {
        name = "Singularity Gate",
        flavor = "At the Singularity Gate, Noodl pours the fruitlight into the starving Heart-root just as the hollow storm breaks—and the orchard breathes again.",
        palette = {
            bgColor    = {0.08, 0.08, 0.12, 1},  -- collapsing night
            arenaBG    = {0.12, 0.1, 0.16, 1},  -- gravitic maw
            arenaBorder= {0.58, 0.26, 0.62, 1},  -- eventide flare
            snake      = {0.88, 0.48, 0.98, 1},   -- horizonflare serpent
            rock       = {0.26, 0.22, 0.4, 1},   -- warped obsidian
            sawColor   = {0.98, 0.52, 0.72, 1},   -- collapsing corona
        },
        backgroundEffect = {
            type = "voidPulse",
            backdropIntensity = 0.78,
            arenaIntensity = 0.5,
        },
        backgroundTheme = "oceanic",
        backgroundVariant = "abyss",
        traits = {"obsidianResonance", "ashenTithe"},
    },
}

return Floors
