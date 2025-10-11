-- floors.lua

--[[
Garden Gate → Pip spills fruit through the opening grove.
Moonwell Caves → Echoed hops and pears mark the chase.
Glowcap Den → Mushrooms point to the dropped jars.
Tide Vault → Tides roll citrus toward the basket.
Rusted Hoist → Old lifts cough up sweet stores.
Crystal Run → Frozen light chills Pip's stashed apples.
Firefly Grove → Lantern bugs rally around Noodl.
Storm Ledge → Thunder shakes snacks loose.
Ember Market → Cooks toss fuel for the sprint.
Molten Keep → Lava guards return honeyed figs.
Wind Steppe → Gusts bundle herbs for pickup.
Ribbon Loom → Ribbons mark the gathered treats.
Forge Pit → Sparks shine on reclaimed tools.
Skywalk → High lanterns reveal every peach.
Sun Tower → Warm custards steady the climb.
Star Ward → Watchers slow Pip with sugar.
Drift Garden → Floating beds shed stardust jam.
Night Observatory → Charts keep the chase on track.
Dusk Court → Calm light readies the final dash.
Promise Gate → Pip returns the orchard stash.
]]

local Floors = {
      [1] = {
name = "Garden Gate",
flavor = "Pip bolts through the garden, spilling orchard fruit behind. Noodl surges after the trail.",
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
name = "Moonwell Caves",
flavor = "Moonlit pools mirror Pip's hops while stray pears drift into Noodl's basket.",
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
name = "Glowcap Den",
flavor = "Blinking mushrooms outline fresh fruit drops, and Noodl scoops each jar in stride.",
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
name = "Tide Vault",
flavor = "Slow waves roll shining citrus along the tiles as Noodl pushes deeper underground.",
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
name = "Rusted Hoist",
flavor = "Ancient lifts cough up stashed syrup, giving Noodl fuel to keep chasing.",
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
name = "Crystal Run",
flavor = "Frosted crystals light the tunnel and chill Pip's apple stash for Noodl to reclaim.",
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
name = "Firefly Grove",
flavor = "Fireflies relay sweet rolls from the branches, cheering Noodl to keep moving.",
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
name = "Storm Ledge",
flavor = "Thunder bridges shake loose salty snacks that Noodl snatches mid-sprint.",
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
name = "Ember Market",
flavor = "Stall cooks toss peppered fruit bites to Noodl as Pip darts through the aisles.",
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
name = "Molten Keep",
flavor = "Lava guards melt their doubts and slide honeyed figs back into Noodl's pack.",
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
name = "Wind Steppe",
flavor = "Steady gusts herd loose herbs into bundles that Noodl stacks while staying on Pip's tail.",
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
name = "Ribbon Loom",
flavor = "Cloud weavers knot recovered treats in ribbon, leaving a bright path for Noodl.",
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
name = "Forge Pit",
flavor = "Meteor sparks polish serving tools while Pip loses more fruit to Noodl's basket.",
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
name = "Skywalk",
flavor = "Lanterns line the high road, showing every peach Pip dropped across the bridge.",
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
name = "Sun Tower",
flavor = "Solar ovens warm custards that Noodl balances carefully during the climb.",
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
name = "Star Ward",
flavor = "Watchers fling sugar crystals toward Noodl, slowing Pip's escape.",
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
name = "Drift Garden",
flavor = "Floating planters shake loose stardust jam that Noodl tucks away.",
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
name = "Night Observatory",
flavor = "Chart keepers slide maps and melon slices to help Noodl track the runaway sprite.",
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
name = "Dusk Court",
flavor = "Soft light calms the loaded basket while Noodl readies for the last push.",
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
name = "Promise Gate",
flavor = "Pip finally yields the fruit stash, and Noodl turns home with the orchard saved.",
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

Floors.storyTitle = "Trail Complete"
Floors.victoryMessage = "With Pip pitching in, Noodl hauls the fruit home for a fresh orchard feast."

return Floors
