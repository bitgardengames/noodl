local Theme = require("theme")
local Achievements = require("achievements")

local SnakeCosmetics = {}

local SAVE_FILE = "snakecosmetics_state.lua"
local DEFAULT_SKIN_ID = "classic_emerald"
local DEFAULT_ORDER = 1000

local SKIN_DEFINITIONS = {
	{
		id = "classic_emerald",
		name = "Classic Expedition",
		description = "Standard expedition scales issued to every new handler.",
		colors = {
			body = {0.45, 0.85, 0.70, 1.0},
			outline = {0.05, 0.15, 0.12, 1.0},
			glow = {0.35, 0.95, 0.80, 0.75},
		},
		unlock = { default = true },
		order = 0,
	},
	{
		id = "candy_cane",
		name = "Candy Cane Coil",
		description = "Festive stripes that twirl with every holiday dash.",
		colors = {
			body = {0.88, 0.14, 0.22, 1.0},
			outline = {0.28, 0.04, 0.07, 1.0},
			glow = {0.98, 0.72, 0.78, 0.86},
		},
		effects = {
			overlay = {
				type = "stripes",
				intensity = 1.0,
				frequency = 22,
				speed = 0.9,
				angle = 52,
				colors = {
					primary = {0.95, 0.95, 0.95, 1.0},
					secondary = {0.86, 0.12, 0.26, 1.0},
				},
			},
			glow = {
				intensity = 0.52,
				RadiusMultiplier = 1.35,
				color = {0.98, 0.72, 0.78, 1.0},
				step = 2,
			},
		},
		unlock = { default = true },
		order = 12,
	},
	{
		id = "solar_flare",
		name = "Solar Flare",
		description = "Basked in reactor light until it took on a stellar sheen.",
		colors = {
			body = {0.98, 0.60, 0.18, 1.0},
			outline = {0.28, 0.08, 0.00, 1.0},
			glow = {1.00, 0.78, 0.32, 0.90},
		},
		unlock = { default = true },
		order = 15,
	},
	{
		id = "prismatic_tide",
		name = "Prismatic Tide",
		description = "Reflective scales tuned to the beat of the abyssal currents.",
		colors = {
			body = {0.32, 0.58, 0.95, 1.0},
			outline = {0.06, 0.16, 0.35, 1.0},
			glow = {0.52, 0.86, 1.00, 0.88},
		},
		unlock = { default = true },
		order = 18,
	},
	{
		id = "emberforge",
		name = "Emberforge Alloy",
		description = "Forged from repurposed saw cores. Unlocks at metaprogression level 3.",
		colors = {
			body = {0.82, 0.38, 0.28, 1.0},
			outline = {0.20, 0.05, 0.02, 1.0},
			glow = {0.95, 0.55, 0.30, 0.78},
		},
		unlock = { level = 3 },
		order = 20,
	},
	{
		id = "aurora_current",
		name = "Aurora Current",
		description = "Caught light from the abyss. Unlocks at metaprogression level 6.",
		colors = {
			body = {0.48, 0.70, 0.98, 1.0},
			outline = {0.08, 0.12, 0.28, 1.0},
			glow = {0.60, 0.85, 1.00, 0.80},
		},
		effects = {
			overlay = {
				type = "AuroraVeil",
				intensity = 0.68,
				opacity = 0.82,
				CurtainDensity = 7.5,
				DriftSpeed = 0.85,
				parallax = 1.6,
				ShimmerStrength = 0.75,
				colors = {
					primary = {0.36, 0.88, 0.96, 0.85},
					secondary = {0.76, 0.58, 1.00, 0.95},
					tertiary = {0.48, 0.70, 0.98, 1.0},
				},
			},
			glow = {
				intensity = 0.55,
				RadiusMultiplier = 1.45,
				color = {0.60, 0.85, 1.00, 1.0},
			},
		},
		unlock = { level = 6 },
		order = 30,
	},
	{
		id = "orchard_sovereign",
		name = "Orchard Sovereign",
		description = "Proof that you've mastered fruit runs. Unlock the Apple Tycoon achievement to earn it.",
		colors = {
			body = {0.95, 0.58, 0.28, 1.0},
			outline = {0.35, 0.12, 0.05, 1.0},
			glow = {1.00, 0.78, 0.35, 0.82},
		},
		effects = {
			glow = {
				intensity = 0.45,
				RadiusMultiplier = 1.3,
				color = {1.00, 0.78, 0.35, 1.0},
			},
		},
		unlock = { achievement = "AppleTycoon" },
		order = 40,
	},
	{
		id = "abyssal_vanguard",
		name = "Abyssal Vanguard",
		description = "Awarded for conquering the deepest floors. Unlock the Floor Ascendant achievement to claim it.",
		colors = {
			body = {0.28, 0.45, 0.82, 1.0},
			outline = {0.06, 0.12, 0.28, 1.0},
			glow = {0.52, 0.72, 1.00, 0.78},
		},
		effects = {
			overlay = {
				type = "AbyssalPulse",
				intensity = 0.72,
				opacity = 0.86,
				SwirlDensity = 9.0,
				GlimmerFrequency = 4.2,
				DriftSpeed = 1.05,
				darkness = 0.32,
				colors = {
					primary = {0.20, 0.35, 0.75, 1.0},
					secondary = {0.38, 0.78, 1.00, 1.0},
					tertiary = {0.76, 0.46, 1.00, 1.0},
				},
			},
			glow = {
				intensity = 0.6,
				RadiusMultiplier = 1.6,
				color = {0.36, 0.62, 1.00, 1.0},
				step = 3,
			},
		},
		unlock = { achievement = "FloorAscendant" },
		order = 50,
	},
	{
		id = "ion_storm",
		name = "Ion Storm",
		description = "Charged scales hum with contained lightning. Unlocks at metaprogression level 9.",
		colors = {
			body = {0.24, 0.36, 0.94, 1.0},
			outline = {0.04, 0.05, 0.22, 1.0},
			glow = {0.58, 0.82, 1.00, 0.9},
		},
		effects = {
			overlay = {
				type = "IonStorm",
				intensity = 0.82,
				opacity = 0.9,
				BoltFrequency = 9.5,
				FlashFrequency = 5.8,
				haze = 0.7,
				turbulence = 1.45,
				colors = {
					primary = {0.32, 0.85, 1.00, 1.0},
					secondary = {0.18, 0.52, 1.00, 1.0},
					tertiary = {0.82, 0.45, 1.00, 1.0},
				},
			},
			glow = {
				intensity = 0.75,
				RadiusMultiplier = 1.55,
				color = {0.62, 0.88, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = { level = 9 },
		order = 60,
	},
	{
		id = "luminous_bloom",
		name = "Luminous Bloom",
		description = "Bioluminescent petals trail with every turn. Unlock the Meta Milestone 5 achievement to claim it.",
		colors = {
			body = {0.52, 0.16, 0.58, 1.0},
			outline = {0.14, 0.03, 0.18, 1.0},
			glow = {0.96, 0.54, 0.88, 0.9},
		},
		effects = {
			overlay = {
				type = "PetalBloom",
				intensity = 0.76,
				opacity = 0.84,
				PetalCount = 8.5,
				PulseSpeed = 2.2,
				TrailStrength = 0.6,
				BloomStrength = 0.8,
				colors = {
					primary = {0.52, 0.16, 0.58, 1.0},
					secondary = {0.94, 0.48, 0.88, 1.0},
					tertiary = {0.68, 0.94, 0.78, 1.0},
				},
			},
			glow = {
				intensity = 0.65,
				RadiusMultiplier = 1.5,
				color = {0.94, 0.48, 0.88, 1.0},
				step = 2,
			},
		},
		unlock = { achievement = "MetaMilestone5" },
		order = 70,
	},
	{
		id = "void_wisp",
		name = "Void Wisp",
		description = "An afterimage from beyond the grid. Unlock the Floor Abyss achievement to claim it.",
		colors = {
			body = {0.08, 0.12, 0.18, 1.0},
			outline = {0.00, 0.00, 0.00, 1.0},
			glow = {0.62, 0.32, 1.00, 0.92},
		},
		effects = {
			overlay = {
				type = "VoidEcho",
				intensity = 0.64,
				opacity = 0.8,
				VeilFrequency = 7.6,
				EchoSpeed = -1.1,
				PhaseShift = 0.3,
				RiftIntensity = 0.22,
				colors = {
					primary = {0.18, 0.18, 0.32, 1.0},
					secondary = {0.32, 0.22, 0.52, 1.0},
					tertiary = {0.62, 0.32, 1.00, 1.0},
				},
			},
			glow = {
				intensity = 0.65,
				RadiusMultiplier = 1.45,
				color = {0.48, 0.28, 0.96, 0.9},
				step = 1,
			},
		},
		unlock = { achievement = "FloorAbyss" },
		order = 80,
	},
	{
		id = "chrono_carapace",
		name = "Chrono Carapace",
		description = "Temporal plating gleaned from time-locked relics. Unlocks at metaprogression level 12.",
		colors = {
			body = {0.58, 0.72, 0.95, 1.0},
			outline = {0.12, 0.18, 0.32, 1.0},
			glow = {0.76, 0.92, 1.00, 0.88},
		},
		effects = {
			overlay = {
				type = "ChronoWeave",
				intensity = 0.7,
				opacity = 0.88,
				RingDensity = 10.5,
				TimeFlow = 2.6,
				WeaveStrength = 1.2,
				PhaseOffset = 0.04,
				colors = {
					primary = {0.46, 0.70, 1.00, 0.95},
					secondary = {0.60, 0.82, 1.00, 1.0},
					tertiary = {0.88, 0.78, 1.00, 0.9},
				},
			},
			glow = {
				intensity = 0.7,
				RadiusMultiplier = 1.6,
				color = {0.70, 0.88, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = { level = 12 },
		order = 90,
	},
	{
		id = "midnight_circuit",
		name = "Midnight Circuit",
		description = "Quantum filaments hum with midnight energy. Unlocks at metaprogression level 15.",
		colors = {
			body = {0.16, 0.20, 0.44, 1.0},
			outline = {0.04, 0.06, 0.16, 1.0},
			glow = {0.48, 0.82, 1.00, 0.88},
		},
		effects = {
			overlay = {
				type = "IonStorm",
				intensity = 0.62,
				opacity = 0.85,
				BoltFrequency = 6.2,
				FlashFrequency = 4.0,
				haze = 0.4,
				turbulence = 1.1,
				colors = {
					primary = {0.24, 0.58, 0.98, 1.0},
					secondary = {0.56, 0.32, 0.92, 1.0},
					tertiary = {0.32, 0.86, 0.96, 1.0},
				},
			},
			glow = {
				intensity = 0.68,
				RadiusMultiplier = 1.6,
				color = {0.44, 0.80, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = { level = 15 },
		order = 95,
	},
	{
		id = "gilded_siren",
		name = "Gilded Siren",
		description = "Goldleaf fins that shimmer with every high score. Unlock the Score Legend achievement to claim it.",
		colors = {
			body = {0.96, 0.78, 0.42, 1.0},
			outline = {0.36, 0.20, 0.05, 1.0},
			glow = {1.00, 0.88, 0.52, 0.86},
		},
		effects = {
			overlay = {
				type = "GildedFacet",
				intensity = 0.7,
				opacity = 0.83,
				FacetDensity = 15.0,
				SparkleDensity = 11.5,
				BeamSpeed = 0.9,
				ReflectionStrength = 0.75,
				colors = {
					primary = {0.96, 0.78, 0.42, 1.0},
					secondary = {1.00, 0.92, 0.68, 1.0},
					tertiary = {0.88, 0.54, 0.24, 1.0},
				},
			},
			glow = {
				intensity = 0.68,
				RadiusMultiplier = 1.55,
				color = {1.00, 0.90, 0.60, 1.0},
				step = 3,
			},
		},
		unlock = { achievement = "ScoreLegend" },
		order = 100,
	},
	{
		id = "abyssal_constellation",
		name = "Abyssal Constellation",
		description = "Star-mapped scales that mirror the deepest currents. Unlock the Meta Milestone 7 achievement to claim it.",
		colors = {
			body = {0.14, 0.18, 0.34, 1.0},
			outline = {0.04, 0.06, 0.14, 1.0},
			glow = {0.54, 0.78, 1.00, 0.9},
		},
		effects = {
			overlay = {
				type = "ConstellationDrift",
				intensity = 0.74,
				opacity = 0.86,
				StarDensity = 6.8,
				DriftSpeed = 1.25,
				parallax = 0.75,
				TwinkleStrength = 0.85,
				colors = {
					primary = {0.24, 0.32, 0.62, 1.0},
					secondary = {0.52, 0.70, 1.00, 1.0},
					tertiary = {0.84, 0.64, 1.00, 1.0},
				},
			},
			glow = {
				intensity = 0.72,
				RadiusMultiplier = 1.7,
				color = {0.58, 0.82, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = { achievement = "MetaMilestone7" },
		order = 110,
	},
	{
		id = "crystalline_mire",
		name = "Crystalline Mire",
		description = "Speleotherm scales harvested from luminous caverns. Unlock the Daily Fun Champion achievement to claim it.",
		colors = {
			body = {0.26, 0.58, 0.48, 1.0},
			outline = {0.05, 0.16, 0.14, 1.0},
			glow = {0.60, 0.92, 0.68, 0.86},
		},
		effects = {
			overlay = {
				type = "CrystalBloom",
				intensity = 0.66,
				opacity = 0.82,
				ShardDensity = 7.8,
				SweepSpeed = -0.75,
				RefractionStrength = 0.7,
				VeinStrength = 0.68,
				colors = {
					primary = {0.24, 0.72, 0.58, 1.0},
					secondary = {0.32, 0.86, 0.68, 1.0},
					tertiary = {0.62, 0.92, 0.54, 1.0},
				},
			},
			glow = {
				intensity = 0.6,
				RadiusMultiplier = 1.48,
				color = {0.62, 0.92, 0.70, 1.0},
				step = 2,
			},
		},
		unlock = { achievement = "DailyFunChampion" },
		order = 120,
	},
	{
		id = "obsidian_ritual",
		name = "Obsidian Ritual",
		description = "Scales quenched in volcanic rites. Unlock the Apple Eternal achievement to claim it.",
		colors = {
			body = {0.18, 0.10, 0.16, 1.0},
			outline = {0.02, 0.01, 0.04, 1.0},
			glow = {0.94, 0.38, 0.32, 0.88},
		},
		effects = {
			overlay = {
				type = "EmberForge",
				intensity = 0.78,
				opacity = 0.84,
				EmberFrequency = 8.8,
				EmberSpeed = 1.2,
				EmberGlow = 0.82,
				SlagDarkness = 0.42,
				colors = {
					primary = {0.32, 0.14, 0.28, 1.0},
					secondary = {0.94, 0.38, 0.32, 1.0},
					tertiary = {0.98, 0.78, 0.38, 1.0},
				},
			},
			glow = {
				intensity = 0.7,
				RadiusMultiplier = 1.62,
				color = {0.96, 0.46, 0.42, 1.0},
				step = 3,
			},
		},
		unlock = { achievement = "AppleEternal" },
		order = 130,
	},
	{
		id = "midnight_mechanica",
		name = "Midnight Mechanica",
		description = "Clockwork plating salvaged from rogue automatons. Unlock the Rock Crusher achievement to claim it.",
		colors = {
			body = {0.18, 0.20, 0.28, 1.0},
			outline = {0.05, 0.06, 0.10, 1.0},
			glow = {0.80, 0.72, 0.46, 0.9},
		},
		effects = {
			overlay = {
				type = "MechanicalScan",
				intensity = 0.63,
				opacity = 0.86,
				ScanSpeed = 1.6,
				GearFrequency = 13.2,
				GearParallax = 1.35,
				ServoIntensity = 0.58,
				colors = {
					primary = {0.42, 0.46, 0.62, 1.0},
					secondary = {0.56, 0.60, 0.82, 1.0},
					tertiary = {0.88, 0.78, 0.48, 1.0},
				},
			},
			glow = {
				intensity = 0.68,
				RadiusMultiplier = 1.52,
				color = {0.90, 0.82, 0.58, 1.0},
				step = 1,
			},
		},
		unlock = { achievement = "RockCrusher" },
		order = 140,
	},
	{
		id = "tidal_resonance",
		name = "Tidal Resonance",
		description = "Harmonic fins tuned to echo clearing streaks. Unlock the Combo Inferno achievement to claim it.",
		colors = {
			body = {0.20, 0.44, 0.82, 1.0},
			outline = {0.04, 0.12, 0.26, 1.0},
			glow = {0.46, 0.88, 1.00, 0.88},
		},
		effects = {
			overlay = {
				type = "TidalChorus",
				intensity = 0.78,
				opacity = 0.88,
				WaveFrequency = 6.2,
				CrestSpeed = 1.5,
				ChorusStrength = 0.68,
				DepthShift = -0.08,
				colors = {
					primary = {0.20, 0.62, 0.94, 1.0},
					secondary = {0.40, 0.90, 1.00, 1.0},
					tertiary = {0.76, 0.52, 1.00, 1.0},
				},
			},
			glow = {
				intensity = 0.74,
				RadiusMultiplier = 1.68,
				color = {0.52, 0.92, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = { achievement = "ComboInferno" },
		order = 150,
	},
}

local function BuildDefaultState()
	local unlocked = {}

	for _, definition in ipairs(SKIN_DEFINITIONS) do
		local unlock = definition.unlock or {}
		if unlock.default then
			unlocked[definition.id] = true
		end
	end

	unlocked[DEFAULT_SKIN_ID] = true

	return {
		SelectedSkin = DEFAULT_SKIN_ID,
		unlocked = unlocked,
		UnlockHistory = {},
		RecentUnlocks = {},
	}
end

local DEFAULT_STATE = BuildDefaultState()

local function CopyTable(source)
	if type(source) ~= "table" then
		return {}
	end

	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = CopyTable(value)
		else
			result[key] = value
		end
	end
	return result
end

local function MergeTables(target, source)
	if type(target) ~= "table" then
		target = {}
	end

	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = MergeTables(CopyTable(target[key] or {}), value)
		else
			target[key] = value
		end
	end

	return target
end

local function IsArray(tbl)
	if type(tbl) ~= "table" then
		return false
	end

	local count = 0
	for key in pairs(tbl) do
		if type(key) ~= "number" then
			return false
		end
		count = count + 1
	end

	return count == #tbl
end

local function serialize(value, indent)
	indent = indent or 0
	local ValueType = type(value)

	if ValueType == "number" or ValueType == "boolean" then
		return tostring(value)
	elseif ValueType == "string" then
		return string.format("%q", value)
	elseif ValueType == "table" then
		local spacing = string.rep(" ", indent)
		local lines = { "{\n" }
		local NextIndent = indent + 4
		local EntryIndent = string.rep(" ", NextIndent)
		if IsArray(value) then
			for index, val in ipairs(value) do
				table.insert(lines, string.format("%s[%d] = %s,\n", EntryIndent, index, serialize(val, NextIndent)))
			end
		else
			for key, val in pairs(value) do
				local KeyRepr
				if type(key) == "string" then
					KeyRepr = string.format("[\"%s\"]", key)
				else
					KeyRepr = string.format("[%s]", tostring(key))
				end
				table.insert(lines, string.format("%s%s = %s,\n", EntryIndent, KeyRepr, serialize(val, NextIndent)))
			end
		end
		table.insert(lines, string.format("%s}", spacing))
		return table.concat(lines)
	end

	return "nil"
end

function SnakeCosmetics:_buildIndex()
	if self._indexBuilt then
		return
	end

	self._skinsById = {}
	self._orderedSkins = {}

	for _, def in ipairs(SKIN_DEFINITIONS) do
		local entry = CopyTable(def)
		entry.order = entry.order or DEFAULT_ORDER
		self._skinsById[entry.id] = entry
		table.insert(self._orderedSkins, entry)
	end

	table.sort(self._orderedSkins, function(a, b)
		if a.order == b.order then
			return (a.id or "") < (b.id or "")
		end
		return (a.order or DEFAULT_ORDER) < (b.order or DEFAULT_ORDER)
	end)

	self._indexBuilt = true
end

function SnakeCosmetics:_ensureLoaded()
	if self._loaded then
		return
	end

	self:_buildIndex()

	self.state = CopyTable(DEFAULT_STATE)

	if love.filesystem.getInfo(SAVE_FILE) then
		local ok, chunk = pcall(love.filesystem.load, SAVE_FILE)
		if ok and chunk then
			local success, data = pcall(chunk)
			if success and type(data) == "table" then
				self.state = MergeTables(CopyTable(DEFAULT_STATE), data)
			end
		end
	end

	self.state.unlocked = self.state.unlocked or {}
	self.state.unlocked[DEFAULT_SKIN_ID] = true
	self.state.UnlockHistory = self.state.UnlockHistory or {}
	self.state.RecentUnlocks = self.state.RecentUnlocks or {}

	self:_validateSelection()

	self._loaded = true
end

function SnakeCosmetics:_validateSelection()
	if not self.state then
		return
	end

	local selected = self.state.SelectedSkin or DEFAULT_SKIN_ID
	if not self.state.unlocked[selected] then
		self.state.SelectedSkin = DEFAULT_SKIN_ID
	else
		self.state.SelectedSkin = selected
	end
end

function SnakeCosmetics:_save()
	if not self._loaded then
		return
	end

	local snapshot = {
		SelectedSkin = self.state.SelectedSkin,
		unlocked = CopyTable(self.state.unlocked),
		UnlockHistory = CopyTable(self.state.UnlockHistory or {}),
		RecentUnlocks = CopyTable(self.state.RecentUnlocks or {}),
	}

	local serialized = "return " .. serialize(snapshot, 0) .. "\n"
	love.filesystem.write(SAVE_FILE, serialized)
end

function SnakeCosmetics:_recordUnlock(id, context)
	context = context or {}
	self.state.UnlockHistory = self.state.UnlockHistory or {}

	local record = {
		id = id,
		source = context.source or context.reason or "system",
		level = context.level,
		achievement = context.achievement,
	}

	if context.justUnlocked ~= nil then
		record.justUnlocked = context.justUnlocked and true or false
	end

	if os and os.time then
		record.timestamp = os.time()
	end

	table.insert(self.state.UnlockHistory, record)
end

function SnakeCosmetics:_unlockSkinInternal(id, context)
	if not id then
		return false
	end

	if self.state.unlocked[id] then
		return false
	end

	self.state.unlocked[id] = true
	self.state.RecentUnlocks = self.state.RecentUnlocks or {}
	self.state.RecentUnlocks[id] = true
	self:_recordUnlock(id, context)
	return true
end

function SnakeCosmetics:IsSkinUnlocked(id)
	self:_ensureLoaded()
	return self.state.unlocked[id] == true
end

function SnakeCosmetics:_registerAchievementListener()
	if self._achievementListenerRegistered then
		return
	end

	if not (Achievements and Achievements.RegisterUnlockListener) then
		return
	end

	Achievements:RegisterUnlockListener(function(id)
		local ok, err = pcall(function()
			self:OnAchievementUnlocked(id)
		end)
		if not ok then
			print("[snakecosmetics] failed to process achievement unlock", tostring(id), err)
		end
	end)

	self._achievementListenerRegistered = true
end

local function MatchesLevelRequirement(skin, level)
	local unlock = skin.unlock or {}
	if not unlock.level then
		return false
	end
	return level >= unlock.level
end

local function MatchesAchievementRequirement(skin, AchievementId)
	local unlock = skin.unlock or {}
	if not unlock.achievement then
		return false
	end
	return unlock.achievement == AchievementId
end

function SnakeCosmetics:SyncMetaLevel(level, context)
	self:_ensureLoaded()

	level = math.max(1, math.floor(level or 1))
	self._highestKnownMetaLevel = math.max(self._highestKnownMetaLevel or 0, level)

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		if MatchesLevelRequirement(skin, level) then
			local UnlockContext = {
				source = "MetaLevel",
				level = skin.unlock.level,
			}
			if context and type(context.levelUps) == "table" then
				for _, lvl in ipairs(context.levelUps) do
					if lvl == skin.unlock.level then
						UnlockContext.justUnlocked = true
						break
					end
				end
			end
			changed = self:_unlockSkinInternal(skin.id, UnlockContext) or changed
		end
	end

	if changed then
		self:_validateSelection()
		self:_save()
	end
end

function SnakeCosmetics:SyncAchievements()
	self:_ensureLoaded()

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		local unlock = skin.unlock or {}
		if unlock.achievement then
			local definition = Achievements:GetDefinition(unlock.achievement)
			if definition and definition.unlocked then
				local UnlockContext = {
					source = "achievement",
					achievement = unlock.achievement,
				}
				changed = self:_unlockSkinInternal(skin.id, UnlockContext) or changed
			end
		end
	end

	if changed then
		self:_validateSelection()
		self:_save()
	end
end

function SnakeCosmetics:OnAchievementUnlocked(id)
	self:_ensureLoaded()

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		if MatchesAchievementRequirement(skin, id) then
			changed = self:_unlockSkinInternal(skin.id, {
				source = "achievement",
				achievement = id,
			}) or changed
		end
	end

	if changed then
		self:_validateSelection()
		self:_save()
	end
end

function SnakeCosmetics:load(context)
	self:_ensureLoaded()
	self:_registerAchievementListener()

	context = context or {}

	if context.metaLevel then
		self:SyncMetaLevel(context.metaLevel)
	end

	self:SyncAchievements()
end

function SnakeCosmetics:GetSkins()
	self:_ensureLoaded()

	local list = {}
	local RecentUnlocks = self.state.RecentUnlocks or {}
	for _, skin in ipairs(self._orderedSkins or {}) do
		local entry = CopyTable(skin)
		entry.unlocked = self.state.unlocked[skin.id] == true
		entry.selected = (self.state.SelectedSkin == skin.id)
		entry.justUnlocked = RecentUnlocks[skin.id] == true
		list[#list + 1] = entry
	end
	return list
end

function SnakeCosmetics:ClearRecentUnlocks(ids)
	self:_ensureLoaded()

	local changed = false
	if type(ids) == "table" then
		for key, value in pairs(ids) do
			local id
			if type(key) == "number" then
				id = value
			else
				id = key
			end
			if id and self.state.RecentUnlocks[id] then
				self.state.RecentUnlocks[id] = nil
				changed = true
			end
		end
	else
		for id in pairs(self.state.RecentUnlocks or {}) do
			self.state.RecentUnlocks[id] = nil
			changed = true
		end
	end

	if changed then
		self:_save()
	end
end

function SnakeCosmetics:GetActiveSkinId()
	self:_ensureLoaded()
	return self.state.SelectedSkin or DEFAULT_SKIN_ID
end

function SnakeCosmetics:GetActiveSkin()
	self:_ensureLoaded()
	local id = self:GetActiveSkinId()
	return self._skinsById[id] or self._skinsById[DEFAULT_SKIN_ID]
end

function SnakeCosmetics:SetActiveSkin(id)
	self:_ensureLoaded()

	if not id or not self._skinsById[id] then
		return false
	end

	if not self:IsSkinUnlocked(id) then
		return false
	end

	if self.state.SelectedSkin == id then
		return false
	end

	self.state.SelectedSkin = id
	self:_save()
	return true
end

local function ResolveColor(color, fallback)
	if type(color) == "table" and #color >= 3 then
		local r = color[1] or 0
		local g = color[2] or 0
		local b = color[3] or 0
		local a = color[4]
		return { r, g, b, a or 1 }
	end

	if fallback then
		return ResolveColor(fallback)
	end

	return { 1, 1, 1, 1 }
end

function SnakeCosmetics:GetBodyColor()
	local skin = self:GetActiveSkin()
	local palette = skin and skin.colors or {}
	return ResolveColor(palette.body, Theme.SnakeDefault)
end

function SnakeCosmetics:GetOutlineColor()
	local skin = self:GetActiveSkin()
	local palette = skin and skin.colors or {}
	return ResolveColor(palette.outline, { 0, 0, 0, 1 })
end

function SnakeCosmetics:GetGlowColor()
	local skin = self:GetActiveSkin()
	local palette = skin and skin.colors or {}
	local effects = skin and skin.effects or {}
	local GlowEffect = effects.glow or {}
	if GlowEffect.color then
		return ResolveColor(GlowEffect.color)
	end
	return ResolveColor(palette.glow, self:GetBodyColor())
end

function SnakeCosmetics:GetGlowEffect()
	local skin = self:GetActiveSkin()
	local effects = skin and skin.effects or {}
	if effects.glow then
		return CopyTable(effects.glow)
	end
	return nil
end

function SnakeCosmetics:GetOverlayEffect()
	local skin = self:GetActiveSkin()
	local effects = skin and skin.effects or {}
	if effects.overlay then
		return CopyTable(effects.overlay)
	end
	return nil
end

return SnakeCosmetics
