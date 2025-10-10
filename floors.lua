-- floors.lua

--[[
                Verdant Garden → lantern-lit welcome where the Starlit Harvest begins
                Echoing Caverns → glittering waterways carry teasing laughter ahead
                Luminous Grotto → glowcaps ripple with clues to the runaway feast
                Tideglass Vault → tidal halls shimmer with reclaimed citrus pearls
                Sunken Reliquary → ancient mechanisms release preserved delights
                Crystal Hollows → refracted frost keeps the chase quick and bright
                Amber Wildwood → emberfire foliage shares spiced sap offerings
                Tempest Peaks → thunderbridges trade storm salt for a song
                Emberlight Bazaar → warm desert market roasts comet peppers
                Obsidian Keep → molten sentries guard the ember honey cache
                Verdigris Frontier → wind-scoured ramparts bundle fragrant herbs
                Auric Loom → spirit artisans weave aurora ribbons for plating
                Starforge Depths → meteoric smiths temper star-iron serving ware
                Celestial Causeway → alabaster skybridge aligns moonglow lanterns
                Solar Spire → sunrise terraces glaze the parade's custard fountains
                Starfall Bastion → cobalt bulwark catches meteor sugar for garnish
                Nebula Crown → drifting gardens shake stardust jam into jars
                Eventide Observatory → orrery keepers chart the dessert constellation
                Eclipse Court → twilight envoys bless the hamper with calm light
                Singularity Gate → the wisp relents and the harvest basket is secured
]]

local Floors = {
               [1] = {
                               name = "Verdant Garden",
                               flavor = "Festival lanterns sway as a star-wisp snatches the harvest basket, and Noodl dives after the glittering thief.",
                                palette = {
                                                bgColor     = {0.24, 0.32, 0.24, 1},
                                                arenaBG     = {0.46, 0.66, 0.39, 1},
                                                arenaBorder = {0.52, 0.38, 0.24, 1},
                                                snake       = {0.12, 0.9, 0.48, 1},
                                                rock        = {0.74, 0.59, 0.38, 1},
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
               flavor = "Laughter ricochets across moonlit pools; Noodl follows the echoing trail of spilled starlight sugar.",
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
               name = "Luminous Grotto",
               flavor = "Glowcaps pulse in rhythm with the wisp's giggles, lighting hidden jars of candied dew for Noodl to reclaim.",
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
               name = "Tideglass Vault",
               flavor = "Tide spirits swirl brined citrus pearls back into the hamper as Noodl splashes through the flooded archive.",
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
               name = "Sunken Reliquary",
               flavor = "Ancient mechanisms unseal jars of amber syrup when Noodl answers their humming riddles mid-chase.",
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
               name = "Crystal Hollows",
               flavor = "Prisms drip frost-sugar onto the path, sparkling clues that keep the chase singing forward.",
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
               name = "Amber Wildwood",
               flavor = "Firefly bakers trade spicebark morsels for stories, cheering Noodl deeper after the runaway wisp.",
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
               name = "Tempest Peaks",
               flavor = "Thunderbridges boom with song as wind herders return jars of storm salt to the hamper.",
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
               name = "Emberlight Bazaar",
               flavor = "Desert vendors roast comet peppers in braziers, slipping the tastiest ones back into the basket.",
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
               name = "Obsidian Keep",
               flavor = "Molten sentries guard the ember honey cache, but Noodl barters a tune and pockets every glowing comb.",
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
               name = "Verdigris Frontier",
               flavor = "Wind-scoured ramparts trade bundles of fragrant herbs, wrapping them snugly into the returning hamper.",
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
               name = "Auric Loom",
               flavor = "Spirit artisans weave aurora ribbons that secure the gathered treats without a single crumb escaping.",
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
               name = "Starforge Depths",
               flavor = "Meteoric smiths temper star-iron serving ware, polishing each plate before handing it to Noodl.",
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
               name = "Celestial Causeway",
               flavor = "Skybridge caretakers tilt alabaster lanterns so the parade path gleams with moonglow again.",
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
               name = "Solar Spire",
               flavor = "Sunrise terraces caramelize custard fountains, and Noodl balances the steaming jars atop the basket.",
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
               name = "Starfall Bastion",
               flavor = "Meteor wardens volley sugar shards into gilded bowls, topping the hamper with crackling stardust.",
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
               name = "Nebula Crown",
               flavor = "Drifting gardens shake stardust jam into jars while Noodl twirls through weightless vines.",
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
               name = "Eventide Observatory",
               flavor = "Orrery keepers chart the dessert constellation, handing Noodl a compass spoon that never spills.",
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
               name = "Eclipse Court",
               flavor = "Twilight envoys bless the refilled basket with calm moonlight, steadying Noodl for the last chase.",
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
               name = "Singularity Gate",
               flavor = "At the final swirl the wisp relents; Noodl secures the hamper and rockets home for the Starlit Harvest.",
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

Floors.storyTitle = "Starlit Harvest Parade"
Floors.victoryMessage = "With the Starlit Harvest basket finally brimming again, Noodl streaks back toward the garden to light the festival."

return Floors
