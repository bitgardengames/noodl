local Settings = require("settings")

local Audio = {
    sounds = {},
    musicTracks = {},
    currentMusic = nil,
}

local SOUND_DEFINITIONS = {
    fruit = "Assets/Sounds/drop_003.ogg",
    hover = "Assets/Sounds/tick_002.ogg",
    click = "Assets/Sounds/select.ogg",
    achievement = "Assets/Sounds/Retro Event Acute 11.wav",
    shield_gain = "Assets/Sounds/switch_001.ogg",
    shield_break = "Assets/Sounds/abs-cancel-1.wav",
    death = "Assets/Sounds/error_007.ogg",
    exit_spawn = "Assets/Sounds/toggle_001.ogg",
    exit_enter = "Assets/Sounds/abs-confirm-1.wav",
    floor_advance = "Assets/Sounds/Retro PickUp 18.wav",
    --floor_intro = "Assets/Sounds/Retro Event Acute 08.wav", -- currently unused
    shop_open = "Assets/Sounds/apple.wav",
    shop_focus = "Assets/Sounds/paper.wav",
    shop_card_deal = "Assets/Sounds/deal1.ogg",
    shop_card_select = "Assets/Sounds/deal2.ogg",
    shop_purchase = "Assets/Sounds/paper.wav",
    goal_reached = "Assets/Sounds/harp strum 5.wav",
    wall_portal = "Assets/Sounds/Glyph Activation Light 01.wav",
    shield_wall = "Assets/Sounds/Activate Glyph Forcefield.wav",
    shield_rock = "Assets/Sounds/Rotate Stone 03.wav",
    shield_saw = "Assets/Sounds/Arcane Wind Chime Gust.wav",
    rock_shatter = "Assets/Sounds/Activate Plinth 03.wav",
    laser_fire = "Assets/Sounds/LASRBeam_Plasma Loop_01.wav",
}

local MUSIC_DEFINITIONS = {
    menu = "Assets/Music/Menu2.ogg",
    game = "Assets/Music/Game2.ogg",
    scorescreen = "Assets/Music/Scorescreen.ogg",
}

local function loadSources(definitions, defaultType)
    local sources = {}

    for name, spec in pairs(definitions) do
        local path = spec
        local sourceType = defaultType

        if type(spec) == "table" then
            path = spec.path or spec[1]
            sourceType = spec.type or spec[2] or defaultType
        end

        if path then
            sources[name] = love.audio.newSource(path, sourceType)
        end
    end

    return sources
end

function Audio:load()
    self.sounds = loadSources(SOUND_DEFINITIONS, "static")
    self.musicTracks = loadSources(MUSIC_DEFINITIONS, "stream")

    for _, track in pairs(self.musicTracks) do
        track:setLooping(true)
    end

    self:applyVolumes()
end

Audio.soundDesignNotes = {
    death = "Short, heavy failure sting with a crunchy impact to sell the snake's demise.",
    exit_spawn = "Gentle magical chime that signals the exit portal appearing nearby.",
    exit_enter = "Deep whoosh or portal suction to reinforce diving into the exit.",
    floor_advance = "Upbeat arpeggio or rising tone to celebrate clearing a floor.",
    floor_intro = "Soft swell or drum hit that sets the tone for the new floor intro card.",
    shop_open = "Friendly bell or door chime that implies entering the shop.",
    shop_focus = "Gentle flourish as the cursor glides over a relic choice.",
    shop_card_deal = "Light card slide as the relic options are dealt onto the table.",
    shop_card_select = "Subtle flip as you commit to a relic pick.",
    shop_purchase = "Burst of coins confirming an upgrade purchase.",
    goal_reached = "Triumphant swell to celebrate filling the fruit goal.",
    wall_portal = "Gentle shimmer hinting at slipping through the arena wall.",
    shield_wall = "Firm magical rebound when a shield saves you from the arena edge.",
    shield_rock = "Crunchy crack as the shield pulverizes a rock.",
    shield_saw = "Arcane whoosh to sell deflecting a spinning saw.",
}

function Audio:applyVolumes()
    for _, track in pairs(self.musicTracks) do
        track:setVolume(Settings.muteMusic and 0 or Settings.musicVolume)
    end
    for _, sound in pairs(self.sounds) do
        sound:setVolume(Settings.muteSFX and 0 or Settings.sfxVolume)
    end
end

function Audio:playSound(name)
    if not Settings.muteSFX and self.sounds[name] then
        self.sounds[name]:stop()
        self.sounds[name]:setVolume(Settings.sfxVolume)
        self.sounds[name]:play()
    end
end

function Audio:playMusic(trackName)
    if Settings.muteMusic then
        if self.currentMusic then self.currentMusic:stop() end
        return
    end

    local newTrack = self.musicTracks[trackName]
    if newTrack and newTrack ~= self.currentMusic then
        if self.currentMusic then self.currentMusic:stop() end
        self.currentMusic = newTrack
        self.currentMusic:setVolume(Settings.musicVolume)
        self.currentMusic:play()
    end
end

return Audio
