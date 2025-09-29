local Settings = require("settings")

local Audio = {
    sounds = {},
    musicTracks = {},
    currentMusic = nil,
}

function Audio:load()
    -- Sound Effects
    self.sounds.fruit = love.audio.newSource("Assets/Sounds/drop_003.ogg", "static")
    self.sounds.hover = love.audio.newSource("Assets/Sounds/tick_002.ogg", "static")
    self.sounds.click = love.audio.newSource("Assets/Sounds/select.ogg", "static")
    self.sounds.achievement = love.audio.newSource("Assets/Sounds/Retro Event Acute 11.wav", "static")
    self.sounds.shield_gain = love.audio.newSource("Assets/Sounds/switch_001.ogg", "static")
    self.sounds.shield_break = love.audio.newSource("Assets/Sounds/abs-cancel-1.wav", "static")
    self.sounds.death = love.audio.newSource("Assets/Sounds/error_007.ogg", "static")
    self.sounds.exit_spawn = love.audio.newSource("Assets/Sounds/toggle_001.ogg", "static")
    self.sounds.exit_enter = love.audio.newSource("Assets/Sounds/abs-confirm-1.wav", "static")
    self.sounds.floor_advance = love.audio.newSource("Assets/Sounds/Retro PickUp 18.wav", "static")
    --self.sounds.floor_intro = love.audio.newSource("Assets/Sounds/Retro Event Acute 08.wav", "static")
    self.sounds.shop_open = love.audio.newSource("Assets/Sounds/apple.wav", "static")
    self.sounds.shop_focus = love.audio.newSource("Assets/Sounds/paper.wav", "static")
    self.sounds.shop_card_deal = love.audio.newSource("Assets/Sounds/deal1.ogg", "static")
    self.sounds.shop_card_select = love.audio.newSource("Assets/Sounds/deal2.ogg", "static")
    self.sounds.shop_purchase = love.audio.newSource("Assets/Sounds/paper.wav", "static")
    self.sounds.goal_reached = love.audio.newSource("Assets/Sounds/harp strum 5.wav", "static")
    self.sounds.wall_portal = love.audio.newSource("Assets/Sounds/Glyph Activation Light 01.wav", "static")
    self.sounds.shield_wall = love.audio.newSource("Assets/Sounds/Activate Glyph Forcefield.wav", "static")
    self.sounds.shield_rock = love.audio.newSource("Assets/Sounds/Rotate Stone 03.wav", "static")
    self.sounds.shield_saw = love.audio.newSource("Assets/Sounds/Arcane Wind Chime Gust.wav", "static")

    -- Music Tracks
    self.musicTracks.menu = love.audio.newSource("Assets/Music/Menu2.ogg", "stream")
    self.musicTracks.game = love.audio.newSource("Assets/Music/Game2.ogg", "stream")
    self.musicTracks.scorescreen = love.audio.newSource("Assets/Music/Scorescreen.ogg", "stream")

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

function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
    end
end

return Audio
