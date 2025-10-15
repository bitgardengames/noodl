-- floors.lua
--[[
Auric Threshold → Gilded plates split to welcome the first devotions.
Resonant Gullet → Songful tides shepherd tributes toward the chanting maw.
Heartforge Crucible → Molten heartbeats temper every offering.
Luminal Gallery → Radiant lungs inhale, flooding the halls with starlit mist.
Hemal Basin → Crimson tides dissolve doubt and polish every tribute.
Marrow Vault → Ivory spires archive vows in fossilised loops.
Stormvein Sanctum → Crackling nerves challenge the faithful with luminous storms.
Celestial Coilcore → Within the deity's heart, blessings crystallise into eternity.
]]

local Floors = {
[1] = {
name = "Auric Threshold",
flavor = "Gilded scales peel aside in concentric halos while Noodl lays the first shimmering tributes.",
        palette = {
            bgColor     = {0.02, 0.06, 0.04, 1},
            arenaBG     = {0.07, 0.18, 0.12, 1},
            arenaBorder = {0.58, 0.97, 0.64, 1},
            snake       = {0.98, 0.94, 0.55, 1},
            rock        = {0.35, 0.32, 0.27, 1},
            sawColor    = {0.74, 0.76, 0.78, 1},
            arenaHighlight = {1.0, 0.88, 0.54, 1},
        },
backgroundEffect = {
type = "scaleBloom",
backdropIntensity = 0.64,
arenaIntensity = 0.36,
},
backgroundTheme = "botanical",
},
[2] = {
name = "Resonant Gullet",
flavor = "Hydrous hymns reverberate through the throat as tidal choirs ferry tributes toward the distant chant.",
        palette = {
            bgColor    = {0.02, 0.05, 0.11, 1},
            arenaBG    = {0.05, 0.11, 0.22, 1},
            arenaBorder= {0.28, 0.72, 1.0, 1},
            snake      = {0.62, 0.95, 1.0, 1},
            rock       = {0.24, 0.3, 0.38, 1},
            sawColor   = {0.76, 0.78, 0.8, 1},
            arenaHighlight = {0.74, 0.94, 1.0, 1},
        },
backgroundEffect = {
type = "softCurrent",
backdropIntensity = 0.68,
arenaIntensity = 0.4,
},
backgroundTheme = "oceanic",
},
[3] = {
name = "Heartforge Crucible",
flavor = "Each pulse slams molten valves together, forging tributes within the Coil's blistering heart.",
        palette = {
            bgColor    = {0.08, 0.01, 0.02, 1},
            arenaBG    = {0.19, 0.04, 0.05, 1},
            arenaBorder= {1.0, 0.46, 0.32, 1},
            snake      = {1.0, 0.72, 0.32, 1},
            rock       = {0.32, 0.18, 0.16, 1},
            sawColor   = {0.88, 0.2, 0.18, 1},
            arenaHighlight = {1.0, 0.6, 0.34, 1},
        },
backgroundEffect = {
type = "emberDrift",
backdropIntensity = 0.68,
arenaIntensity = 0.42,
},
backgroundTheme = "desert",
},
[4] = {
name = "Luminal Gallery",
flavor = "Radiant lungs inhale and exhale nebular mist, suspending every offering in swirling auroras.",
        palette = {
            bgColor    = {0.02, 0.07, 0.15, 1},
            arenaBG    = {0.06, 0.13, 0.26, 1},
            arenaBorder= {0.5, 0.86, 1.0, 1},
            snake      = {0.72, 0.97, 1.0, 1},
            rock       = {0.22, 0.28, 0.36, 1},
            sawColor   = {0.75, 0.78, 0.81, 1},
            arenaHighlight = {0.86, 0.76, 1.0, 1},
        },
backgroundEffect = {
type = "spiralAurora",
backdropIntensity = 0.7,
arenaIntensity = 0.42,
},
backgroundTheme = "arctic",
},
[5] = {
name = "Hemal Basin",
flavor = "Crimson digestion pools churn with sacramental froth, etching offerings with gleaming scars.",
        palette = {
            bgColor    = {0.11, 0.0, 0.08, 1},
            arenaBG    = {0.2, 0.01, 0.14, 1},
            arenaBorder= {1.0, 0.36, 0.6, 1},
            snake      = {1.0, 0.56, 0.84, 1},
            rock       = {0.3, 0.15, 0.22, 1},
            sawColor   = {0.86, 0.18, 0.2, 1},
            arenaHighlight = {1.0, 0.66, 0.78, 1},
        },
backgroundEffect = {
type = "voidPulse",
backdropIntensity = 0.7,
arenaIntensity = 0.44,
},
backgroundTheme = "laboratory",
},
[6] = {
name = "Marrow Vault",
flavor = "Riblike buttresses archive the faithful's promises in rings of polished bone and amber marrow.",
        palette = {
            bgColor    = {0.07, 0.05, 0.02, 1},
            arenaBG    = {0.14, 0.11, 0.05, 1},
            arenaBorder= {0.98, 0.87, 0.52, 1},
            snake      = {1.0, 0.93, 0.67, 1},
            rock       = {0.42, 0.35, 0.24, 1},
            sawColor   = {0.74, 0.72, 0.68, 1},
            arenaHighlight = {0.88, 0.72, 0.45, 1},
        },
backgroundEffect = {
type = "ruinMotes",
backdropIntensity = 0.62,
arenaIntensity = 0.36,
},
backgroundTheme = "machine",
},
[7] = {
name = "Stormvein Sanctum",
flavor = "Electrical hymns lance along nerve-cord spires while sigils flare with stormlight.",
        palette = {
            bgColor    = {0.02, 0.04, 0.11, 1},
            arenaBG    = {0.05, 0.07, 0.2, 1},
            arenaBorder= {0.48, 0.56, 1.0, 1},
            snake      = {0.62, 0.8, 1.0, 1},
            rock       = {0.23, 0.25, 0.37, 1},
            sawColor   = {0.76, 0.78, 0.83, 1},
            arenaHighlight = {0.7, 0.9, 1.0, 1},
        },
backgroundEffect = {
type = "auroraVeil",
backdropIntensity = 0.7,
arenaIntensity = 0.42,
},
backgroundTheme = "laboratory",
},
[8] = {
name = "Celestial Coilcore",
flavor = "The innermost chamber blooms with stellar scales, awaiting the final devoted harvest.",
        palette = {
            bgColor    = {0.04, 0.01, 0.15, 1},
            arenaBG    = {0.08, 0.03, 0.26, 1},
            arenaBorder= {0.76, 0.48, 1.0, 1},
            snake      = {0.95, 0.68, 1.0, 1},
            rock       = {0.29, 0.24, 0.38, 1},
            sawColor   = {0.78, 0.78, 0.84, 1},
            arenaHighlight = {1.0, 0.84, 0.5, 1},
        },
backgroundEffect = {
type = "prismaticSpiral",
backdropIntensity = 0.82,
arenaIntensity = 0.5,
},
backgroundTheme = "oceanic",
backgroundVariant = "abyss",
},
}

Floors.storyTitle = "Descent of the Coil"
Floors.victoryMessage = "The Coil accepts every offering. Noodl rests within the deity's embrace, reborn in luminous scales."

return Floors
