-- floors.lua
--[[
Garden Gate → Noodl winds through the grove to gather scattered fruit.
Moonwell Caves → Reflected pools guide each pear into reach.
Tide Vault → Rolling tides usher citrus toward the basket.
Rusted Hoist → Old lifts reveal syrupy stores to reclaim.
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
                        bgColor     = {0.1, 0.18, 0.22, 1},
                        arenaBG     = {0.122, 0.18, 0.227, 1},
                        arenaBorder = {0.294, 0.42, 0.388, 1},
                        snake       = {0.467, 0.882, 0.706, 1},
                        rock        = {0.576, 0.769, 0.784, 1},
                        sawColor    = {0.769, 0.788, 0.757, 1},
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
                        rock       = {0.41, 0.58, 0.71, 1},
                        sawColor   = {0.69, 0.69, 0.74, 1},
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
                        bgColor    = {0.05, 0.11, 0.15, 1},
                        arenaBG    = {0.094, 0.216, 0.251, 1},
                        arenaBorder= {0.165, 0.322, 0.345, 1},
                        snake      = {0.84, 0.95, 0.58, 1},
                        rock       = {0.361, 0.561, 0.635, 1},
                        sawColor   = {0.62, 0.659, 0.671, 1},
                },
                backgroundEffect = {
                        type = "softCurrent",
                        backdropIntensity = 0.6,
                        arenaIntensity = 0.36,
                },
                backgroundTheme = "oceanic",
        },
        [4] = {
                name = "Rusted Hoist",
                flavor = "Ancient lifts cough up stashed syrup, giving Noodl fresh fuel for the harvest.",
                palette = {
                        bgColor    = {0.14, 0.12, 0.08, 1},
                        arenaBG    = {0.24, 0.2, 0.12, 1},
                        arenaBorder= {0.58, 0.48, 0.28, 1},
                        snake      = {0.98, 0.88, 0.48, 1},
                        rock       = {0.66, 0.46, 0.28, 1},
                        sawColor   = {0.92, 0.76, 0.42, 1},
                },
                backgroundEffect = {
                        type = "ruinMotes",
                        backdropIntensity = 0.6,
                        arenaIntensity = 0.34,
                },
                backgroundTheme = "machine",
        },
        [5] = {
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
        [6] = {
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
        [7] = {
                name = "Skywalk",
                flavor = "Lanterns line the high road, showing every peach for Noodl to scoop along the bridge.",
                palette = {
                        bgColor    = {0.64, 0.74, 0.88, 1},
                        arenaBG    = {0.68, 0.82, 0.94, 1},
                        arenaBorder= {0.54, 0.74, 0.9, 1},
                        snake      = {0.98, 0.7, 0.32, 1},
                        rock       = {0.44, 0.62, 0.88, 1},
                        sawColor   = {0.96, 0.62, 0.34, 1},
                        bananaColor     = {0.88, 0.68, 0.24, 1},
                        goldenPearColor = {0.9, 0.58, 0.2, 1},
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
                        bgColor    = {0.12, 0.05, 0.2, 1},
                        arenaBG    = {0.18, 0.08, 0.26, 1},
                        arenaBorder= {0.68, 0.26, 0.72, 1},
                        snake      = {0.92, 0.48, 0.98, 1},
                        rock       = {0.54, 0.32, 0.68, 1},
                        sawColor   = {1.0, 0.5, 0.7, 1},
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
