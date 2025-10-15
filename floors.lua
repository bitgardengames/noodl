-- floors.lua
--[[
Threshold of Scales → The serpent's hide opens, inviting the first offerings.
Gullet of Echoes → Reverent tides pull fruit toward the chanting throat.
Heartfire Crucible → Pulsing chambers beat with molten devotion.
Breathlit Gallery → Luminous currents cycle offerings through radiant lungs.
Sanguine Basin → The stomach's tides dissolve doubt and polish every tribute.
Ossified Labyrinth → Bone towers guard the offerings etched in memory.
Synapse Sanctum → Crackling nerves test the resolve of the faithful.
Coilcore Reliquary → At the deity's heart, the final blessing awaits.
]]

local Floors = {
[1] = {
name = "Threshold of Scales",
flavor = "The serpent's hide parts, and Noodl glides along gleaming plates to lay the first offerings.",
palette = {
bgColor     = {0.1, 0.13, 0.11, 1},
arenaBG     = {0.18, 0.26, 0.22, 1},
arenaBorder = {0.42, 0.66, 0.5, 1},
snake       = {0.76, 0.92, 0.62, 1},
rock        = {0.36, 0.48, 0.38, 1},
},
backgroundEffect = {
type = "softCanopy",
backdropIntensity = 0.58,
arenaIntensity = 0.32,
},
backgroundTheme = "botanical",
},
[2] = {
name = "Gullet of Echoes",
flavor = "Reverent tides pull fruit toward the chanting throat as Noodl coils through resonant currents.",
palette = {
bgColor    = {0.06, 0.09, 0.14, 1},
arenaBG    = {0.12, 0.18, 0.26, 1},
arenaBorder= {0.28, 0.54, 0.68, 1},
snake      = {0.7, 0.86, 0.98, 1},
rock       = {0.26, 0.4, 0.54, 1},
sawColor   = {0.58, 0.76, 0.88, 1},
},
backgroundEffect = {
type = "softCurrent",
backdropIntensity = 0.6,
arenaIntensity = 0.34,
},
backgroundTheme = "oceanic",
},
[3] = {
name = "Heartfire Crucible",
flavor = "Pulse by pulse, the Coil's heart bathes each offering in molten devotion and testing heat.",
palette = {
bgColor    = {0.12, 0.07, 0.08, 1},
arenaBG    = {0.2, 0.11, 0.12, 1},
arenaBorder= {0.74, 0.32, 0.24, 1},
snake      = {0.92, 0.58, 0.34, 1},
rock       = {0.46, 0.28, 0.3, 1},
sawColor   = {0.94, 0.46, 0.3, 1},
},
backgroundEffect = {
type = "emberDrift",
backdropIntensity = 0.68,
arenaIntensity = 0.42,
},
backgroundTheme = "desert",
},
[4] = {
name = "Breathlit Gallery",
flavor = "Glowing vapors rhythmically expand and contract, suspending fruit within the deity's radiant lungs.",
palette = {
bgColor    = {0.09, 0.11, 0.16, 1},
arenaBG    = {0.16, 0.2, 0.28, 1},
arenaBorder= {0.44, 0.68, 0.9, 1},
snake      = {0.76, 0.92, 1.0, 1},
rock       = {0.34, 0.46, 0.64, 1},
sawColor   = {0.64, 0.82, 0.98, 1},
},
backgroundEffect = {
type = "auroraVeil",
backdropIntensity = 0.64,
arenaIntensity = 0.38,
},
backgroundTheme = "arctic",
},
[5] = {
name = "Sanguine Basin",
flavor = "Digestive tides polish every tribute as Noodl navigates crimson pools in the Coil's vast stomach.",
palette = {
bgColor    = {0.12, 0.08, 0.1, 1},
arenaBG    = {0.18, 0.12, 0.18, 1},
arenaBorder= {0.52, 0.32, 0.46, 1},
snake      = {0.88, 0.54, 0.72, 1},
rock       = {0.44, 0.28, 0.42, 1},
sawColor   = {0.84, 0.4, 0.54, 1},
},
backgroundEffect = {
type = "voidPulse",
backdropIntensity = 0.7,
arenaIntensity = 0.44,
},
backgroundTheme = "laboratory",
},
[6] = {
name = "Ossified Labyrinth",
flavor = "Ivory towers of rib and spine ring with ancestral hymns as offerings settle between ancient bones.",
palette = {
bgColor    = {0.09, 0.09, 0.12, 1},
arenaBG    = {0.18, 0.17, 0.22, 1},
arenaBorder= {0.72, 0.64, 0.48, 1},
snake      = {0.86, 0.8, 0.58, 1},
rock       = {0.5, 0.44, 0.32, 1},
sawColor   = {0.86, 0.66, 0.4, 1},
},
backgroundEffect = {
type = "ruinMotes",
backdropIntensity = 0.62,
arenaIntensity = 0.36,
},
backgroundTheme = "machine",
},
[7] = {
name = "Synapse Sanctum",
flavor = "Crackling nerves spark prophetic sigils while Noodl threads the lightning-lit corridors.",
palette = {
bgColor    = {0.08, 0.08, 0.14, 1},
arenaBG    = {0.14, 0.16, 0.26, 1},
arenaBorder= {0.46, 0.62, 0.92, 1},
snake      = {0.68, 0.9, 0.98, 1},
rock       = {0.36, 0.4, 0.6, 1},
sawColor   = {0.78, 0.72, 0.98, 1},
},
backgroundEffect = {
type = "auroraVeil",
backdropIntensity = 0.7,
arenaIntensity = 0.42,
},
backgroundTheme = "laboratory",
},
[8] = {
name = "Coilcore Reliquary",
flavor = "The deity's innermost chamber blooms with celestial scales awaiting the final devoted harvest.",
palette = {
bgColor    = {0.06, 0.07, 0.12, 1},
arenaBG    = {0.12, 0.14, 0.22, 1},
arenaBorder= {0.64, 0.48, 0.86, 1},
snake      = {0.88, 0.7, 1.0, 1},
rock       = {0.48, 0.32, 0.64, 1},
sawColor   = {0.96, 0.54, 0.82, 1},
},
backgroundEffect = {
type = "voidPulse",
backdropIntensity = 0.76,
arenaIntensity = 0.48,
},
backgroundTheme = "oceanic",
backgroundVariant = "abyss",
},
}

Floors.storyTitle = "Descent of the Coil"
Floors.victoryMessage = "The Coil accepts every offering. Noodl rests within the deity's embrace, reborn in luminous scales."

return Floors
