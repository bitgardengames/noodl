local paletteMoods = {
    calm = {
        bg = {0.14, 0.19, 0.17, 1},
        arena = {0.28, 0.45, 0.34, 1},
        border = {0.36, 0.52, 0.38, 1},
        snake = {0.21, 0.82, 0.62, 1},
        rock = {0.56, 0.42, 0.3, 1},
        highlight = {0.74, 0.88, 0.68, 1},
    },
    curious = {
        bg = {0.18, 0.17, 0.14, 1},
        arena = {0.36, 0.32, 0.22, 1},
        border = {0.52, 0.44, 0.28, 1},
        snake = {0.94, 0.65, 0.32, 1},
        rock = {0.62, 0.48, 0.28, 1},
        highlight = {0.98, 0.78, 0.46, 1},
    },
    tense = {
        bg = {0.09, 0.11, 0.18, 1},
        arena = {0.18, 0.22, 0.3, 1},
        border = {0.32, 0.42, 0.56, 1},
        snake = {0.62, 0.78, 0.92, 1},
        rock = {0.42, 0.48, 0.62, 1},
        highlight = {0.78, 0.84, 0.98, 1},
    },
    dire = {
        bg = {0.11, 0.08, 0.12, 1},
        arena = {0.2, 0.12, 0.16, 1},
        border = {0.45, 0.2, 0.24, 1},
        snake = {0.94, 0.42, 0.36, 1},
        rock = {0.52, 0.32, 0.32, 1},
        highlight = {0.98, 0.62, 0.42, 1},
    },
    triumphant = {
        bg = {0.16, 0.2, 0.24, 1},
        arena = {0.58, 0.68, 0.78, 1},
        border = {0.82, 0.74, 0.52, 1},
        snake = {0.86, 0.78, 0.52, 1},
        rock = {0.52, 0.52, 0.64, 1},
        highlight = {0.94, 0.86, 0.64, 1},
    },
}

local function mixColor(a, b, t)
    if not a and not b then
        return {1, 1, 1, 1}
    end

    a = a or b
    b = b or a
    t = math.max(0, math.min(1, t or 0))

    local ar, ag, ab, aa = a[1] or 0, a[2] or 0, a[3] or 0, a[4] or 1
    local br, bg, bb, ba = b[1] or 0, b[2] or 0, b[3] or 0, b[4] or 1

    return {
        ar + (br - ar) * t,
        ag + (bg - ag) * t,
        ab + (bb - ab) * t,
        aa + (ba - aa) * t,
    }
end

local function makePalette(spec)
    spec = spec or {}
    local base = paletteMoods[spec.base or "calm"] or paletteMoods.calm
    local accent = paletteMoods[spec.accent or spec.base or "calm"] or base
    local highlight = paletteMoods[spec.highlight or spec.accent or spec.base or "calm"] or accent

    return {
        bgColor = mixColor(base.bg, accent.bg, spec.baseBlend or 0.3),
        arenaBG = mixColor(base.arena, accent.arena, spec.arenaBlend or 0.55),
        arenaBorder = mixColor(base.border, highlight.border or highlight.arena, spec.borderBlend or 0.45),
        snake = spec.snake or highlight.snake or base.snake,
        rock = mixColor(base.rock, accent.rock, spec.rockBlend or 0.5),
        sawColor = spec.sawColor or {0.98, 0.4, 0.24, 1},
    }
end

local Floors = {
    [1] = {
        name = "Grove Threshold",
        flavor = "Warm moss cushions each step as the elder keeps the path bright.",
        palette = makePalette({ base = "calm", accent = "curious" }),
        backgroundEffect = { type = "softCanopy", backdropIntensity = 0.6, arenaIntensity = 0.38 },
        backgroundTheme = "botanical",
        traits = { "sunlitSanctuary" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor1.line1", duration = 4.2 },
            },
        },
    },
    [2] = {
        name = "Amber Switchback",
        flavor = "Gentle roots guide a winding trail still touched by sunlight.",
        palette = makePalette({ base = "calm", accent = "curious", arenaBlend = 0.4 }),
        backgroundEffect = { type = "softCanopy", backdropIntensity = 0.58, arenaIntensity = 0.36 },
        backgroundTheme = "botanical",
        traits = { "sunlitSanctuary", "glowingSpores" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor2.line1", duration = 4.2 },
            },
        },
    },
    [3] = {
        name = "Twilight Descent",
        flavor = "Soft echoes replace birdsong as the grove thins behind you.",
        palette = makePalette({ base = "curious", accent = "tense", arenaBlend = 0.4 }),
        backgroundEffect = { type = "softCavern", backdropIntensity = 0.5, arenaIntensity = 0.32 },
        backgroundTheme = "cavern",
        traits = { "echoingStillness" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor3.line1", duration = 4.2 },
            },
        },
    },
    [4] = {
        name = "Echo Ducts",
        flavor = "Stone echoes crowd in without walls, reacting to every slip in rising tension.",
        palette = makePalette({ base = "tense", accent = "curious" }),
        backgroundEffect = { type = "softCavern", backdropIntensity = 0.52, arenaIntensity = 0.34 },
        backgroundTheme = "cavern",
        traits = { "echoingStillness", "restlessEarth" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor4.line1", duration = 4.2 },
            },
        },
    },
    [5] = {
        name = "Floodcarrier Span",
        flavor = "Mist curls around open spans where currents tug at focus.",
        palette = makePalette({ base = "tense", accent = "curious", arenaBlend = 0.45 }),
        backgroundEffect = { type = "softCurrent", backdropIntensity = 0.62, arenaIntensity = 0.38 },
        backgroundTheme = "oceanic",
        traits = { "waterloggedCatacombs" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.noodl", key = "game.story.floor5.line1", duration = 4.2 },
            },
        },
    },
    [6] = {
        name = "Crystal Verge",
        flavor = "Prisms catch stray light, refracting every movement into alarms.",
        palette = makePalette({ base = "tense", accent = "triumphant", arenaBlend = 0.35 }),
        backgroundEffect = { type = "auroraVeil", backdropIntensity = 0.58, arenaIntensity = 0.36 },
        backgroundTheme = "laboratory",
        traits = { "crystallineResonance" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.whisper", key = "game.story.floor6.line1", duration = 4.2 },
            },
        },
    },
    [7] = {
        name = "Sentinel Confluence",
        flavor = "Ancient pylons ignite, calling forth twin guardians to halt your climb.",
        palette = makePalette({ base = "curious", accent = "dire", highlight = "tense" }),
        backgroundEffect = { type = "softCanopy", backdropIntensity = 0.5, arenaIntensity = 0.34 },
        backgroundTheme = "urban",
        layout = { type = "boss", radius = 6 },
        traits = { "guardianConvergence" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.trader", key = "game.story.floor7.line1", duration = 4.2 },
            },
            choice = {
                id = "crossroads_path",
                title = "game.story.choices.crossroads.title",
                prompt = "game.story.choices.crossroads.prompt",
                options = {
                    {
                        id = "ally_support",
                        nameKey = "game.story.choices.crossroads.ally_name",
                        descriptionKey = "game.story.choices.crossroads.ally_desc",
                        effects = {
                            fruitGoalDelta = -2,
                            sawStallAdd = 0.3,
                            extraTrait = {
                                nameKey = "game.story.choices.crossroads.ally_trait_name",
                                descKey = "game.story.choices.crossroads.ally_trait_desc",
                            },
                        },
                    },
                    {
                        id = "hazard_toll",
                        nameKey = "game.story.choices.crossroads.hazard_name",
                        descriptionKey = "game.story.choices.crossroads.hazard_desc",
                        effects = {
                            sawsDelta = 1,
                            rockSpawnDelta = 0.08,
                            extraTrait = {
                                nameKey = "game.story.choices.crossroads.hazard_trait_name",
                                descKey = "game.story.choices.crossroads.hazard_trait_desc",
                            },
                        },
                    },
                },
            },
        },
    },
    [8] = {
        name = "Mistbound Gallery",
        flavor = "Wind sculptures sway, offering guidance or demand.",
        palette = makePalette({ base = "tense", accent = "curious" }),
        backgroundEffect = { type = "softCurrent", backdropIntensity = 0.6, arenaIntensity = 0.36 },
        backgroundTheme = "urban",
        traits = { "glowingSpores" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.noodl", key = "game.story.floor8.line1", duration = 4.0 },
                { speakerKey = "game.story.speakers.mira", key = "game.story.floor8.ally", duration = 3.6, when = { choiceEquals = { crossroads_path = "ally_support" } } },
                { speakerKey = "game.story.speakers.broker", key = "game.story.floor8.hazard", duration = 3.6, when = { choiceEquals = { crossroads_path = "hazard_toll" } } },
            },
            choice = {
                id = "glimmer_pact",
                title = "game.story.choices.glimmer.title",
                prompt = "game.story.choices.glimmer.prompt",
                options = {
                    {
                        id = "bloomward",
                        nameKey = "game.story.choices.glimmer.bloom_name",
                        descriptionKey = "game.story.choices.glimmer.bloom_desc",
                        effects = {
                            fruitGoalDelta = -1,
                            rockSpawnMultiplier = 0.82,
                            extraTrait = {
                                nameKey = "game.story.choices.glimmer.bloom_trait_name",
                                descKey = "game.story.choices.glimmer.bloom_trait_desc",
                            },
                        },
                    },
                    {
                        id = "shadow_toll",
                        nameKey = "game.story.choices.glimmer.shadow_name",
                        descriptionKey = "game.story.choices.glimmer.shadow_desc",
                        effects = {
                            sawsDelta = 1,
                            sawSpeedMultiplier = 1.12,
                            extraTrait = {
                                nameKey = "game.story.choices.glimmer.shadow_trait_name",
                                descKey = "game.story.choices.glimmer.shadow_trait_desc",
                            },
                        },
                    },
                },
            },
        },
    },
    [9] = {
        name = "Veil of Mirrors",
        flavor = "Reflections swirl freely, daring you to choose which shimmer to trust.",
        palette = makePalette({ base = "tense", accent = "dire", arenaBlend = 0.4 }),
        backgroundEffect = { type = "auroraVeil", backdropIntensity = 0.64, arenaIntensity = 0.38 },
        backgroundTheme = "laboratory",
        traits = { "boneHarvest" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.noodl", key = "game.story.floor9.line1", duration = 3.8 },
                { speakerKey = "game.story.speakers.tinkerer", key = "game.story.floor9.bloom", duration = 3.4, when = { choiceEquals = { glimmer_pact = "bloomward" } } },
                { speakerKey = "game.story.speakers.tinkerer", key = "game.story.floor9.shadow", duration = 3.4, when = { choiceEquals = { glimmer_pact = "shadow_toll" } } },
            },
            choice = {
                id = "astral_alignment",
                title = "game.story.choices.astral.title",
                prompt = "game.story.choices.astral.prompt",
                options = {
                    {
                        id = "resonant_path",
                        nameKey = "game.story.choices.astral.resonant_name",
                        descriptionKey = "game.story.choices.astral.resonant_desc",
                        effects = {
                            sawsDelta = -1,
                            sawStallAdd = 0.25,
                            extraTrait = {
                                nameKey = "game.story.choices.astral.resonant_trait_name",
                                descKey = "game.story.choices.astral.resonant_trait_desc",
                            },
                        },
                    },
                    {
                        id = "tempest_path",
                        nameKey = "game.story.choices.astral.tempest_name",
                        descriptionKey = "game.story.choices.astral.tempest_desc",
                        effects = {
                            sawSpeedMultiplier = 1.18,
                            rocksDelta = 2,
                            extraTrait = {
                                nameKey = "game.story.choices.astral.tempest_trait_name",
                                descKey = "game.story.choices.astral.tempest_trait_desc",
                            },
                        },
                    },
                },
            },
        },
    },
    [10] = {
        name = "Ember Maw",
        flavor = "Heat presses close; every choice now glows on the blade edges.",
        palette = makePalette({ base = "dire", accent = "tense" }),
        backgroundEffect = { type = "emberDrift", backdropIntensity = 0.64, arenaIntensity = 0.4 },
        backgroundTheme = "desert",
        traits = { "infernalPressure" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor10.line1", duration = 4.0 },
                { speakerKey = "game.story.speakers.mira", key = "game.story.floor10.ally", duration = 3.6, when = { choiceEquals = { crossroads_path = "ally_support" } } },
                { speakerKey = "game.story.speakers.broker", key = "game.story.floor10.hazard", duration = 3.6, when = { choiceEquals = { crossroads_path = "hazard_toll" } } },
            },
        },
    },
    [11] = {
        name = "Spectral Relay",
        flavor = "Phantoms pace your stride, mirroring every borrowed boon.",
        palette = makePalette({ base = "tense", accent = "dire" }),
        backgroundEffect = { type = "auroraVeil", backdropIntensity = 0.66, arenaIntensity = 0.42 },
        backgroundTheme = "laboratory",
        traits = { "spectralEchoes" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.tinkerer", key = "game.story.floor11.bloom", duration = 3.6, when = { choiceEquals = { glimmer_pact = "bloomward" } } },
                { speakerKey = "game.story.speakers.tinkerer", key = "game.story.floor11.shadow", duration = 3.6, when = { choiceEquals = { glimmer_pact = "shadow_toll" } } },
                { speakerKey = "game.story.speakers.specter", key = "game.story.floor11.resonant", duration = 3.6, when = { choiceEquals = { astral_alignment = "resonant_path" } } },
                { speakerKey = "game.story.speakers.specter", key = "game.story.floor11.tempest", duration = 3.6, when = { choiceEquals = { astral_alignment = "tempest_path" } } },
            },
        },
    },
    [12] = {
        name = "Storm of Paths",
        flavor = "Every prior choice collides in a single roaring conduit.",
        palette = makePalette({ base = "dire", accent = "tense" }),
        backgroundEffect = { type = "voidPulse", backdropIntensity = 0.7, arenaIntensity = 0.46 },
        backgroundTheme = "desert",
        traits = { "obsidianResonance" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor12.line1", duration = 4.0 },
            },
        },
    },
    [13] = {
        name = "Heart of the Blight",
        flavor = "Cleansing nodes flare underfoot; purging them steadies the world.",
        palette = makePalette({ base = "dire", accent = "triumphant", arenaBlend = 0.48 }),
        backgroundEffect = { type = "voidPulse", backdropIntensity = 0.72, arenaIntensity = 0.48 },
        backgroundTheme = "laboratory",
        layout = { type = "boss", radius = 7 },
        traits = { "cleansingNodes", "ashenTithe", "blightOvermind" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor13.line1", duration = 4.2 },
                { speakerKey = "game.story.speakers.specter", key = "game.story.floor13.resonant", duration = 3.6, when = { choiceEquals = { astral_alignment = "resonant_path" } } },
            },
        },
    },
    [14] = {
        name = "Homeward Chorus",
        flavor = "The grove sings back, changed by every step you claimed.",
        palette = makePalette({ base = "triumphant", accent = "calm", arenaBlend = 0.4 }),
        backgroundEffect = { type = "auroraVeil", backdropIntensity = 0.62, arenaIntensity = 0.34 },
        backgroundTheme = "botanical",
        traits = { "sunlitSanctuary", "lushGrowth" },
        story = {
            lines = {
                { speakerKey = "game.story.speakers.elder", key = "game.story.floor14.line1", duration = 4.0 },
                { speakerKey = "game.story.speakers.mira", key = "game.story.floor14.ally", duration = 3.6, when = { choiceEquals = { crossroads_path = "ally_support" } } },
                { speakerKey = "game.story.speakers.broker", key = "game.story.floor14.hazard", duration = 3.6, when = { choiceEquals = { crossroads_path = "hazard_toll" } } },
                { speakerKey = "game.story.speakers.tinkerer", key = "game.story.floor14.glimmer", duration = 3.4, when = { choiceTaken = { "bloomward", "shadow_toll" } } },
                { speakerKey = "game.story.speakers.specter", key = "game.story.floor14.astral", duration = 3.4, when = { choiceTaken = { "resonant_path", "tempest_path" } } },
            },
        },
    },
}

return Floors
