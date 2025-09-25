--[[ Generic
local Theme = {
    -- Arena
    arenaBG      = {0.12, 0.14, 0.28, 1},   -- Muted slate blue-gray
    arenaBorder  = {0.35, 0.65, 0.7, 1},    -- Soft teal accent

    -- General background (full window)
    bgColor         = {0.1, 0.12, 0.15, 1}, -- Gentle dark charcoal-blue
    shadowColor     = {0, 0, 0, 0.4},         -- Balanced shadow
    highlightColor  = {1, 1, 1, 0.04},        -- Low-key shine

    -- Buttons
    buttonColor     = {0.3, 0.55, 0.75, 1}, -- Muted steel blue
    buttonHover     = {0.4, 0.7, 0.85, 1},  -- Softer sky blue hover
    borderColor     = {0.6, 0.85, 0.85, 1}, -- Gentle aqua outline

    -- Panels
    panelColor      = {0.18, 0.2, 0.25, 0.95},-- Deep desaturated indigo-gray
    panelBorder     = {0.5, 0.6, 0.75, 1},  -- Muted lavender-blue

    -- Text
    textColor       = {0.9, 0.9, 0.92, 1},  -- Soft off-white, easy on eyes

    -- States / feedback
    lockedCardColor = {0.4, 0.25, 0.3, 1},  -- Subdued wine red (locked)
    achieveColor    = {0.55, 0.75, 0.55, 1},-- Muted minty green
    progressColor   = {0.85, 0.65, 0.4, 1}, -- Warm muted orange

    -- Gameplay
    snakeDefault    = {0.45, 0.8, 0.55, 1}, -- Calm leafy green snake

    -- Objects (fruits & powerups)
    appleColor       = {0.8, 0.35, 0.4, 1}, -- Muted rose red
    bananaColor      = {0.9, 0.85, 0.45, 1},-- Dusty golden yellow
    blueberryColor   = {0.45, 0.55, 0.8, 1},-- Muted periwinkle blue
    goldenPearColor  = {0.9, 0.8, 0.45, 1}, -- Muted soft gold
    dragonfruitColor = {0.8, 0.5, 0.7, 1},  -- Gentle dusty pink-purple
	sawColor         = {0.85, 0.85, 0.85, 1}, -- Light grey, could be (0.85, 0.15, 0.15) on hellish floors or something
}]]

--[[ Chill / Pastel
local Theme = {
    -- Arena
    arenaBG      = {0.95, 0.95, 1, 1},    -- Very light lavender
    arenaBorder  = {0.7, 0.6, 0.9, 1},      -- Soft periwinkle

    -- General background
    bgColor         = {0.9, 0.95, 1, 1},  -- Sky blue-white
    shadowColor     = {0, 0, 0, 0.1},         -- Gentle soft shadow
    highlightColor  = {1, 1, 1, 0.15},        -- Subtle light sheen

    -- Buttons
    buttonColor     = {0.8, 0.7, 0.9, 1},   -- Pastel purple
    buttonHover     = {0.9, 0.85, 0.6, 1},  -- Soft butter yellow
    borderColor     = {0.6, 0.9, 0.8, 1},   -- Mint outline

    -- Panels
    panelColor      = {0.95, 0.85, 0.95, 0.9},-- Pinkish lavender
    panelBorder     = {0.7, 0.6, 0.9, 1},   -- Periwinkle

    -- Text
    textColor       = {0.2, 0.2, 0.25, 1},  -- Soft charcoal gray

    -- States
    lockedCardColor = {0.8, 0.6, 0.6, 1},   -- Muted rose
    achieveColor    = {0.9, 0.4, 0.6, 1},   -- Pink coral
    progressColor   = {0.6, 0.8, 0.4, 1},   -- Light green

    -- Gameplay
    snakeDefault    = {0.4, 0.8, 0.6, 1},   -- Mint snake

    -- Fruits
    appleColor       = {0.9, 0.5, 0.5, 1},
    bananaColor      = {0.95, 0.9, 0.6, 1},
    blueberryColor   = {0.6, 0.7, 0.95, 1},
    goldenPearColor  = {0.95, 0.85, 0.5, 1},
    dragonfruitColor = {0.9, 0.6, 0.8, 1},
	sawColor         = {0.85, 0.85, 0.85, 1}, -- Light grey
	rock             = {0.6, 0.6, 0.65, 1},
}]]

--[[ Softer / Muted Pastel
local Theme = {
    -- Arena
    arenaBG      = {0.85, 0.85, 0.92, 1},   -- Muted lavender-gray
    arenaBorder  = {0.55, 0.5, 0.7, 1},     -- Dusty periwinkle

    -- General background
    bgColor         = {0.82, 0.87, 0.92, 1}, -- Gentle blue-gray
    shadowColor     = {0, 0, 0, 0.15},       -- Slightly stronger shadow
    highlightColor  = {1, 1, 1, 0.08},       -- Softer, less distracting sheen

    -- Buttons
    buttonColor     = {0.65, 0.55, 0.75, 1}, -- Muted purple
    buttonHover     = {0.85, 0.75, 0.55, 1}, -- Warm sand yellow
    borderColor     = {0.5, 0.75, 0.65, 1},  -- Dusty mint

    -- Panels
    panelColor      = {0.88, 0.78, 0.88, 0.9},-- Softer pink-lavender
    panelBorder     = {0.55, 0.5, 0.7, 1},   -- Consistent periwinkle

    -- Text
    textColor       = {0.25, 0.25, 0.3, 1},  -- Comfortable dark gray

    -- States
    lockedCardColor = {0.7, 0.5, 0.55, 1},   -- Muted rose
    achieveColor    = {0.8, 0.35, 0.55, 1},  -- Dusty coral
    progressColor   = {0.55, 0.75, 0.45, 1}, -- Softer green

    -- Gameplay
    snakeDefault    = {0.35, 0.7, 0.55, 1},  -- Muted mint

    -- Fruits
    appleColor       = {0.8, 0.45, 0.45, 1},
    bananaColor      = {0.9, 0.85, 0.55, 1},
    blueberryColor   = {0.5, 0.6, 0.85, 1},
    goldenPearColor  = {0.85, 0.75, 0.45, 1},
    dragonfruitColor = {0.85, 0.55, 0.7, 1},

    -- Obstacles
    sawColor         = {0.7, 0.7, 0.75, 1},  -- Dimmer grey
    rock             = {0.5, 0.5, 0.55, 1},  -- Darker stone
}]]

-- Dark Pastel Theme
local Theme = {
    -- Arena
    arenaBG      = {0.12, 0.12, 0.15, 1},   -- Charcoal with a hint of blue
    arenaBorder  = {0.35, 0.3, 0.5, 1},     -- Dusty periwinkle

    -- General background
    bgColor         = {0.08, 0.08, 0.1, 1}, -- Deep slate gray
    shadowColor     = {0, 0, 0, 0.4},       -- Stronger shadow for depth
    highlightColor  = {1, 1, 1, 0.05},      -- Very subtle sheen

    -- Buttons
    buttonColor     = {0.4, 0.35, 0.55, 1}, -- Muted purple
    buttonHover     = {0.65, 0.55, 0.35, 1},-- Warm golden-brown
    borderColor     = {0.3, 0.55, 0.45, 1}, -- Soft mint-teal

    -- Panels
    panelColor      = {0.18, 0.18, 0.22, 0.9}, -- Dark slate
    panelBorder     = {0.35, 0.3, 0.5, 1},     -- Dusty periwinkle

    -- Text
    textColor       = {0.85, 0.85, 0.9, 1}, -- Soft off-white

    -- States
    lockedCardColor = {0.5, 0.35, 0.4, 1},  -- Muted rose
    achieveColor    = {0.8, 0.45, 0.65, 1}, -- Warm pink coral
    progressColor   = {0.55, 0.75, 0.55, 1},-- Pastel green

    -- Gameplay
    snakeDefault    = {0.45, 0.85, 0.7, 1}, -- Pastel mint, pops nicely

    -- Fruits
    appleColor       = {0.9, 0.45, 0.55, 1}, -- Soft red
    bananaColor      = {0.9, 0.85, 0.55, 1}, -- Pale yellow
    blueberryColor   = {0.55, 0.65, 0.95, 1},-- Gentle blue
    goldenPearColor  = {0.95, 0.8, 0.45, 1}, -- Warm gold
    dragonfruitColor = {0.9, 0.6, 0.8, 1},   -- Pastel magenta

    -- Obstacles
    sawColor         = {0.65, 0.65, 0.7, 1}, -- Softer grey
    rock             = {0.3, 0.3, 0.35, 1},  -- Deep stone gray
}

--[[ High contrast minimal
local Theme = {
    -- Arena
    arenaBG      = {0.0, 0.0, 0.0, 1},      -- Pure black
    arenaBorder  = {1, 1, 1, 1},      -- Pure white

    -- General background
    bgColor         = {0.05, 0.05, 0.05, 1},-- Near black
    shadowColor     = {0, 0, 0, 0.8},         -- Strong shadow
    highlightColor  = {1, 1, 1, 0.1},

    -- Buttons
    buttonColor     = {0.15, 0.15, 0.15, 1},-- Dark gray
    buttonHover     = {1, 1, 1, 1},   -- White fill on hover
    borderColor     = {1, 1, 1, 1},   -- White outline

    -- Panels
    panelColor      = {0.1, 0.1, 0.1, 0.95},  -- Charcoal
    panelBorder     = {1, 1, 1, 1},   -- White

    -- Text
    textColor       = {1, 1, 1, 1},   -- Pure white

    -- States
    lockedCardColor = {0.2, 0.2, 0.2, 1},   -- Dark gray
    achieveColor    = {1, 0.2, 0.2, 1},   -- Red accent
    progressColor   = {0.2, 0.8, 1, 1},   -- Cyan progress

    -- Gameplay
    snakeDefault    = {1, 1, 1, 1},   -- White snake

    -- Fruits
    appleColor       = {1, 0.2, 0.2, 1},
    bananaColor      = {1, 1, 0.2, 1},
    blueberryColor   = {0.2, 0.4, 1, 1},
    goldenPearColor  = {1, 0.85, 0.2, 1},
    dragonfruitColor = {1, 0.2, 1, 1},
	sawColor         = {0.85, 0.85, 0.85, 1}, -- Light grey
	rock             = {0.6, 0.6, 0.65, 1},
}]]

--[[ Warm Sunset
local Theme = {
    -- Arena
    arenaBG      = {0.18, 0.1, 0.2, 1},   -- Deep plum background
    arenaBorder  = {0.9, 0.5, 0.3, 1},    -- Warm amber border

    -- General background
    bgColor         = {0.12, 0.08, 0.12, 1}, -- Soft wine-charcoal
    shadowColor     = {0, 0, 0, 0.35},       -- Subtle shadow
    highlightColor  = {1, 0.9, 0.8, 0.05},   -- Warm soft glow

    -- Buttons
    buttonColor     = {0.8, 0.45, 0.4, 1},   -- Coral base
    buttonHover     = {0.95, 0.65, 0.4, 1},  -- Golden-orange hover
    borderColor     = {0.95, 0.8, 0.6, 1},   -- Peachy outline

    -- Panels
    panelColor      = {0.22, 0.15, 0.22, 0.95}, -- Dark plum panel
    panelBorder     = {0.85, 0.65, 0.55, 1},    -- Warm muted beige

    -- Text
    textColor       = {0.95, 0.9, 0.85, 1},  -- Gentle cream

    -- States / feedback
    lockedCardColor = {0.5, 0.25, 0.25, 1},  -- Muted oxblood
    achieveColor    = {0.6, 0.85, 0.55, 1},  -- Balanced spring green
    progressColor   = {0.95, 0.7, 0.4, 1},   -- Sunny orange

    -- Gameplay
    snakeDefault    = {0.85, 0.55, 0.65, 1}, -- Soft rose snake

    -- Objects (fruits & powerups)
    appleColor       = {0.9, 0.4, 0.3, 1},  -- Reddish coral
    bananaColor      = {0.95, 0.85, 0.45, 1},-- Warm gold
    blueberryColor   = {0.5, 0.55, 0.9, 1}, -- Violet-blue
    goldenPearColor  = {0.95, 0.75, 0.35, 1},-- Rich amber gold
    dragonfruitColor = {0.9, 0.55, 0.75, 1}, -- Rose pink
    sawColor         = {0.9, 0.9, 0.9, 1},  -- Light neutral
	rock             = {0.6, 0.6, 0.65, 1},
}]]

return Theme