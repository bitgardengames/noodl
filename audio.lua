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

    -- Music Tracks
    self.musicTracks.menu = love.audio.newSource("Assets/Music/Menu2.ogg", "stream")
    self.musicTracks.game = love.audio.newSource("Assets/Music/Game2.ogg", "stream")
    self.musicTracks.scorescreen = love.audio.newSource("Assets/Music/Scorescreen.ogg", "stream")

    for _, track in pairs(self.musicTracks) do
        track:setLooping(true)
    end

    self:applyVolumes()
end

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
