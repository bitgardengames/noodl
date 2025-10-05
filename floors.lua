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
                flavor = "Noodl snacks on backyard fruit, meaning to head home soon. Curiosity pulls them down the hole.",
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
                traits = {"sunlitSanctuary"},
        },
    [2] = {
        name = "Echoing Caverns",
        flavor = "Echoes promise sweeter bites deeper in. Noodl slithers on, belly rumbling.",
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
        traits = {"echoingStillness"},
    },
    [3] = {
        name = "Mushroom Grotto",
        flavor = "Glowshrooms taste like candy, so Noodl loads up. Home already feels far away.",
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
        flavor = "Brackish fruit floats past, irresistible. Noodl swims after, forgetting the exit.",
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
        traits = {"waterloggedCatacombs"},
    },
    [5] = {
        name = "Ancient Ruins",
        flavor = "Dusty altars drip nectar. Noodl licks them clean and creeps farther in.",
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
        traits = {"ancientMachinery", "echoingStillness"},
    },
    [6] = {
        name = "Crystal Hollows",
        flavor = "Cold crystals trap syrupy dew. Hunger beats the chill, and Noodl keeps chasing it.",
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
        flavor = "Old bones guard shriveled berries. Noodl crunches through, ignoring the warning creaks.",
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
        traits = {"boneHarvest"},
    },
    [8] = {
        name = "The Abyss",
        flavor = "A dark draft smells of ripe treasure. Noodl dives, certain one more snack lies below.",
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
        traits = {"echoingStillness", "restlessEarth"},
    },
    [9] = {
        name = "Inferno Gates",
        flavor = "Heat sears the fruit skins, caramel sweet. Noodl risks a scorch for another bite.",
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
        traits = {"infernalPressure"},
    },
    [10] = {
        name = "Obsidian Keep",
        flavor = "Molten pits spit sugared sparks. Noodl edges past, eyes only on the feast.",
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
        flavor = "Ash storms hide bitter seeds that taste perfect. Turning back feels impossible now.",
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
        traits = {"ashenTithe", "boneHarvest"},
    },
    [12] = {
        name = "Spirit Crucible",
        flavor = "Whispers offer ethereal pulp for a toll. Noodl trades caution for flavor.",
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
        traits = {"spectralEchoes", "glowingSpores"},
    },
    [13] = {
        name = "The Underworld",
        flavor = "Lava markets fry fruit to smoky bliss. Noodl devours, unaware how far home is.",
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
        traits = {"ashenTithe", "infernalPressure"},
    },
    [14] = {
        name = "Celestial Causeway",
        flavor = "A sudden breeze carries airy petals. Noodl chases the scent across thin bridges.",
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
        traits = {"divineAscent", "spectralEchoes"},
    },
    [15] = {
        name = "Sky Spire",
        flavor = "Sky banquets glimmer above yawning clouds. Noodl climbs, stomach louder than fear.",
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
        flavor = "Falling stars sear trails of candied light. Noodl weaves through guards to taste them.",
        palette = {
            bgColor    = {0.2, 0.21, 0.28, 1},  -- twilight navy mantle
            arenaBG    = {0.82, 0.86, 0.96, 1},  -- moonlit parapets
            arenaBorder= {0.96, 0.74, 0.52, 1},  -- gilded battlements
            snake      = {0.98, 0.82, 0.48, 1},  -- auric champion
            rock       = {0.42, 0.4, 0.68, 1},  -- dusk-lacquered bastion stones
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
        flavor = "Nebula vines drip cosmic jam. Lenses in the mist hint at home, yet Noodl drifts farther, dizzy and full.",
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
        traits = {"spectralEchoes", "glowingSpores"},
    },
    [18] = {
        name = "Eventide Observatory",
        flavor = "Crystal orreries map a path back. Noodl samples their luminous fruit instead, promising just one more taste.",
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
        traits = {"spectralEchoes", "crystallineResonance"},
    },
    [19] = {
        name = "Void Throne",
        flavor = "A silent court sets out obsidian fruit and a glint of the way home. Noodl bows only to hunger.",
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
        traits = {"obsidianResonance", "infernalPressure"},
    },
    [20] = {
        name = "Singularity Gate",
        flavor = "Gravity hoards the final harvest. Reflections of home collapse inward, yet Noodl leans in, torn between one last bite and the path back.",
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
        traits = {"obsidianResonance", "ashenTithe"},
    },
}

return Floors
