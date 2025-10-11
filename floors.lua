-- floors.lua

--[[
                Verdant Garden → Lanterns swing and the chase begins.
                Echoing Caverns → Echoes guide Noodl deeper underground.
                Luminous Grotto → Glowcaps point to dropped treats.
                Tideglass Vault → Waves send the hamper goods back.
                Sunken Reliquary → Old lifts share hidden syrup.
                Crystal Hollows → Frosty light quickens the run.
                Amber Wildwood → Fireflies pass food and cheers.
                Tempest Peaks → Thunder bridges return the salt.
                Emberlight Bazaar → Market cooks fuel the pursuit.
                Obsidian Keep → Molten guards decide to help.
                Verdigris Frontier → Winds pack herbs for the feast.
                Auric Loom → Weavers tie the harvest tight.
                Starforge Depths → Smiths polish tools for serving.
                Celestial Causeway → Lanterns line the path ahead.
                Solar Spire → Sun ovens warm the custards.
                Starfall Bastion → Wardens toss sugar to the basket.
                Nebula Crown → Gardens shake loose stardust jam.
                Eventide Observatory → Stargazers steady the route.
                Eclipse Court → Twilight calms the loaded basket.
                Singularity Gate → The wisp stops and gives back the haul.
]]

local Floors = {
               [1] = {
                               name = "Verdant Garden",
              flavor = "Lanterns swing as a star-wisp grabs the harvest basket. Noodl starts the chase.",
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
              flavor = "Moonlit pools repeat the wisp's laugh. Noodl follows the echoes deeper.",
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
              flavor = "Glowcaps blink to show where the wisp ran. Noodl collects the fallen jars.",
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
              flavor = "Tide spirits roll citrus pearls toward Noodl. The chase splashes through the vault.",
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
              flavor = "Old lifts rise with stored syrup. Noodl keeps climbing after the wisp.",
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
              flavor = "Cold crystals light the tunnel. Noodl speeds up through the clear glow.",
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
              flavor = "Fireflies pass warm snacks to Noodl. Their cheers push the chase onward.",
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
              flavor = "Wind bridges boom with thunder. Storm herders return salt jars as Noodl hurries by.",
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
              flavor = "Market cooks roast comet peppers for strength. Noodl accepts each gift and keeps running.",
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
              flavor = "Molten guards watch the ember honey. A quick song wins their help for Noodl.",
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
              flavor = "Winds push loose herbs into neat bundles. Noodl secures them before moving on.",
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
              flavor = "Spirit weavers tie the gathered treats with bright ribbons. Noodl keeps after the wisp.",
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
              flavor = "Meteor smiths polish serving tools for the feast. Noodl adds them to the basket and runs on.",
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
              flavor = "Caretakers tilt lanterns to light the parade path. Noodl follows the bright road ahead.",
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
              flavor = "Sun ovens warm the custards waiting inside. Noodl steadies each jar for the climb.",
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
              flavor = "Wardens toss sugar crystals into ready bowls. Noodl shields the basket and keeps moving.",
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
              flavor = "Floating gardens shake stardust jam into jars. Noodl slips through the weightless vines.",
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
              flavor = "Stargazers chart a safe route for the chase. They hand Noodl a steady spoon for balance.",
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
              flavor = "Twilight envoys calm the filled basket with soft light. Noodl takes a breath before the last sprint.",
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
              flavor = "The wisp finally stops and gives back the basket. Noodl turns toward home with every treat safe.",
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

Floors.storyTitle = "Harvest Restored"
Floors.victoryMessage = "With the harvest basket full again, Noodl rushes home to relight the festival."

return Floors
