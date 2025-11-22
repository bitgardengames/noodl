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
	rock_shatter = "Assets/Sounds/materialStone.mp3",
	laser_fire = "Assets/Sounds/LASRBeam_Plasma Loop_01.wav",
	dart_fire = "Assets/Sounds/Whoosh Short Light 03.wav",
	dart_hit = "Assets/Sounds/impact2.ogg",
	intro = "Assets/Sounds/intro.mp3",
}

--MP3 files will often NOT loop seamlessly. You will notice a very short gap when the song loops. This is due to the nature of the MP3 file format and is often difficult to overcome. I highly recommend using these songs as OGG files.
local MUSIC_DEFINITIONS = {
	menu = "Assets/Music/Menu4.ogg",
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

function Audio:applyVolumes()
	for _, track in pairs(self.musicTracks) do
		track:setVolume(Settings.muteMusic and 0 or Settings.musicVolume)
	end
	for _, sound in pairs(self.sounds) do
		sound:setVolume(Settings.muteSFX and 0 or Settings.sfxVolume)
	end
end

function Audio:playSound(name, pitch)
	if not Settings.muteSFX and self.sounds[name] then
		self.sounds[name]:stop()
		self.sounds[name]:setVolume(Settings.sfxVolume) -- should be done on volume change, and then just rely on the stored volume
		self.sounds[name]:setPitch(pitch or 1)
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
