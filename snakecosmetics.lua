local Theme = require("theme")
local Achievements = require("achievements")

local max = math.max
local insert = table.insert

local SnakeCosmetics = {}

local SAVE_FILE = "snakecosmetics_state.lua"
local DEFAULT_SKIN_ID = "classic_emerald"
local DEFAULT_ORDER = 1000
local DEFAULT_OUTLINE_COLOR = {0, 0, 0, 1}

local function compareSkinDefinitions(a, b)
	if a.order == b.order then
		return (a.id or "") < (b.id or "")
	end
	return (a.order or DEFAULT_ORDER) < (b.order or DEFAULT_ORDER)
end

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
		unlock = {default = true},
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
			glow = {
				intensity = 0.52,
				radiusMultiplier = 1.35,
				color = {0.98, 0.72, 0.78, 1.0},
				step = 2,
			},
		},
		unlock = {default = true},
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
		unlock = {default = true},
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
		unlock = {default = true},
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
		unlock = {level = 3},
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
			glow = {
				intensity = 0.55,
				radiusMultiplier = 1.45,
				color = {0.60, 0.85, 1.00, 1.0},
			},
		},
		unlock = {level = 6},
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
				radiusMultiplier = 1.3,
				color = {1.00, 0.78, 0.35, 1.0},
			},
		},
		unlock = {achievement = "appleTycoon"},
		order = 40,
	},
	{
		id = "abyssal_vanguard",
		name = "Abyssal Vanguard",
		description = "Awarded for conquering the deepest floors. Unlocks at metaprogression level 12.",
		colors = {
			body = {0.28, 0.45, 0.82, 1.0},
			outline = {0.06, 0.12, 0.28, 1.0},
			glow = {0.52, 0.72, 1.00, 0.78},
		},
		effects = {
			glow = {
				intensity = 0.6,
				radiusMultiplier = 1.6,
				color = {0.36, 0.62, 1.00, 1.0},
				step = 3,
			},
		},
		unlock = {level = 12},
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
			glow = {
				intensity = 0.75,
				radiusMultiplier = 1.55,
				color = {0.62, 0.88, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = {level = 9},
		order = 60,
	},
	{
		id = "luminous_bloom",
		name = "Luminous Bloom",
		description = "Bioluminescent petals trail with every turn. Unlocks at metaprogression level 13.",
		colors = {
			body = {0.52, 0.16, 0.58, 1.0},
			outline = {0.14, 0.03, 0.18, 1.0},
			glow = {0.96, 0.54, 0.88, 0.9},
		},
		effects = {
			glow = {
				intensity = 0.65,
				radiusMultiplier = 1.5,
				color = {0.94, 0.48, 0.88, 1.0},
				step = 2,
			},
		},
		unlock = {level = 13},
		order = 70,
	},
	{
		id = "void_wisp",
		name = "Void Wisp",
		description = "An afterimage from beyond the grid. Unlocks at metaprogression level 11.",
		colors = {
			body = {0.08, 0.12, 0.18, 1.0},
			outline = {0.00, 0.00, 0.00, 1.0},
			glow = {0.62, 0.32, 1.00, 0.92},
		},
		effects = {
			glow = {
				intensity = 0.65,
				radiusMultiplier = 1.45,
				color = {0.48, 0.28, 0.96, 0.9},
				step = 1,
			},
		},
		unlock = {level = 11},
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
			glow = {
				intensity = 0.7,
				radiusMultiplier = 1.6,
				color = {0.70, 0.88, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = {level = 12},
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
			glow = {
				intensity = 0.68,
				radiusMultiplier = 1.6,
				color = {0.44, 0.80, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = {level = 15},
		order = 95,
	},
	{
		id = "gilded_siren",
		name = "Gilded Siren",
		description = "Goldleaf fins that shimmer with every high score. Unlocks at metaprogression level 15.",
		colors = {
			body = {0.96, 0.78, 0.42, 1.0},
			outline = {0.36, 0.20, 0.05, 1.0},
			glow = {1.00, 0.88, 0.52, 0.86},
		},
		effects = {
			glow = {
				intensity = 0.68,
				radiusMultiplier = 1.55,
				color = {1.00, 0.90, 0.60, 1.0},
				step = 3,
			},
		},
		unlock = {level = 15},
		order = 100,
	},
	{
		id = "abyssal_constellation",
		name = "Abyssal Constellation",
		description = "Star-mapped scales that mirror the deepest currents. Unlocks at metaprogression level 14.",
		colors = {
			body = {0.14, 0.18, 0.34, 1.0},
			outline = {0.04, 0.06, 0.14, 1.0},
			glow = {0.54, 0.78, 1.00, 0.9},
		},
		effects = {
			glow = {
				intensity = 0.72,
				radiusMultiplier = 1.7,
				color = {0.58, 0.82, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = {level = 14},
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
			glow = {
				intensity = 0.6,
				radiusMultiplier = 1.48,
				color = {0.62, 0.92, 0.70, 1.0},
				step = 2,
			},
		},
		unlock = {achievement = "dailyFunChampion"},
		order = 120,
	},
	{
		id = "obsidian_ritual",
		name = "Obsidian Ritual",
		description = "Scales quenched in volcanic rites. Unlocks at metaprogression level 10.",
		colors = {
			body = {0.18, 0.10, 0.16, 1.0},
			outline = {0.02, 0.01, 0.04, 1.0},
			glow = {0.94, 0.38, 0.32, 0.88},
		},
		effects = {
			glow = {
				intensity = 0.7,
				radiusMultiplier = 1.62,
				color = {0.96, 0.46, 0.42, 1.0},
				step = 3,
			},
		},
		unlock = {level = 10},
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
			glow = {
				intensity = 0.68,
				radiusMultiplier = 1.52,
				color = {0.90, 0.82, 0.58, 1.0},
				step = 1,
			},
		},
		unlock = {achievement = "rockCrusher"},
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
			glow = {
				intensity = 0.74,
				radiusMultiplier = 1.68,
				color = {0.52, 0.92, 1.00, 1.0},
				step = 2,
			},
		},
		unlock = {achievement = "comboInferno"},
		order = 150,
	},
}

local function buildDefaultState()
	local unlocked = {}

	for _, definition in ipairs(SKIN_DEFINITIONS) do
		local unlock = definition.unlock or {}
		if unlock.default then
			unlocked[definition.id] = true
		end
	end

	unlocked[DEFAULT_SKIN_ID] = true

	return {
		selectedSkin = DEFAULT_SKIN_ID,
		unlocked = unlocked,
		unlockHistory = {},
		recentUnlocks = {},
	}
end

local DEFAULT_STATE = buildDefaultState()

local function copyTable(source)
	if type(source) ~= "table" then
		return {}
	end

	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = copyTable(value)
		else
			result[key] = value
		end
	end
	return result
end

local function mergeTables(target, source)
	if type(target) ~= "table" then
		target = {}
	end

	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = mergeTables(copyTable(target[key] or {}), value)
		else
			target[key] = value
		end
	end

	return target
end

local function isArray(tbl)
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
	local valueType = type(value)

	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	elseif valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "table" then
		local spacing = string.rep(" ", indent)
		local lines = {"{\n"}
		local nextIndent = indent + 4
		local entryIndent = string.rep(" ", nextIndent)
		if isArray(value) then
			for index, val in ipairs(value) do
				insert(lines, string.format("%s[%d] = %s,\n", entryIndent, index, serialize(val, nextIndent)))
			end
		else
			for key, val in pairs(value) do
				local keyRepr
				if type(key) == "string" then
					keyRepr = string.format("[\"%s\"]", key)
				else
					keyRepr = string.format("[%s]", tostring(key))
				end
				insert(lines, string.format("%s%s = %s,\n", entryIndent, keyRepr, serialize(val, nextIndent)))
			end
		end
		insert(lines, string.format("%s}", spacing))
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
		local entry = copyTable(def)
		entry.order = entry.order or DEFAULT_ORDER
		self._skinsById[entry.id] = entry
		insert(self._orderedSkins, entry)
	end

	table.sort(self._orderedSkins, compareSkinDefinitions)

	self._indexBuilt = true
end

function SnakeCosmetics:_ensureLoaded()
	if self._loaded then
		return
	end

	self:_buildIndex()

	self.state = copyTable(DEFAULT_STATE)

	if love.filesystem.getInfo(SAVE_FILE) then
		local ok, chunk = pcall(love.filesystem.load, SAVE_FILE)
		if ok and chunk then
			local success, data = pcall(chunk)
			if success and type(data) == "table" then
				self.state = mergeTables(copyTable(DEFAULT_STATE), data)
			end
		end
	end

	self.state.unlocked = self.state.unlocked or {}
	self.state.unlocked[DEFAULT_SKIN_ID] = true
	self.state.unlockHistory = self.state.unlockHistory or {}
	self.state.recentUnlocks = self.state.recentUnlocks or {}

	self:_validateSelection()

	self._loaded = true
end

function SnakeCosmetics:_validateSelection()
	if not self.state then
		return
	end

	local selected = self.state.selectedSkin or DEFAULT_SKIN_ID
	if not self.state.unlocked[selected] then
		self.state.selectedSkin = DEFAULT_SKIN_ID
	else
		self.state.selectedSkin = selected
	end
end

function SnakeCosmetics:_save()
	if not self._loaded then
		return
	end

	local snapshot = {
		selectedSkin = self.state.selectedSkin,
		unlocked = copyTable(self.state.unlocked),
		unlockHistory = copyTable(self.state.unlockHistory or {}),
		recentUnlocks = copyTable(self.state.recentUnlocks or {}),
	}

	local serialized = "return " .. serialize(snapshot, 0) .. "\n"
	love.filesystem.write(SAVE_FILE, serialized)
end

function SnakeCosmetics:_recordUnlock(id, context)
	context = context or {}
	self.state.unlockHistory = self.state.unlockHistory or {}

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

	insert(self.state.unlockHistory, record)
end

function SnakeCosmetics:_unlockSkinInternal(id, context)
	if not id then
		return false
	end

	if self.state.unlocked[id] then
		return false
	end

	self.state.unlocked[id] = true
	self.state.recentUnlocks = self.state.recentUnlocks or {}
	self.state.recentUnlocks[id] = true
	self:_recordUnlock(id, context)
	return true
end

function SnakeCosmetics:isSkinUnlocked(id)
	self:_ensureLoaded()
	return self.state.unlocked[id] == true
end

function SnakeCosmetics:_registerAchievementListener()
	if self._achievementListenerRegistered then
		return
	end

	if not (Achievements and Achievements.registerUnlockListener) then
		return
	end

	Achievements:registerUnlockListener(function(id)
		local ok, err = pcall(function()
			self:onAchievementUnlocked(id)
		end)
		if not ok then
			print("[snakecosmetics] failed to process achievement unlock", tostring(id), err)
		end
	end)

	self._achievementListenerRegistered = true
end

local function matchesLevelRequirement(skin, level)
	local unlock = skin.unlock or {}
	if not unlock.level then
		return false
	end
	return level >= unlock.level
end

local function matchesAchievementRequirement(skin, achievementId)
	local unlock = skin.unlock or {}
	if not unlock.achievement then
		return false
	end
	return unlock.achievement == achievementId
end

function SnakeCosmetics:syncMetaLevel(level, context)
	self:_ensureLoaded()

	level = max(1, math.floor(level or 1))
	self._highestKnownMetaLevel = max(self._highestKnownMetaLevel or 0, level)

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		if matchesLevelRequirement(skin, level) then
			local unlockContext = {
				source = "metaLevel",
				level = skin.unlock.level,
			}
			if context and type(context.levelUps) == "table" then
				for _, lvl in ipairs(context.levelUps) do
					if lvl == skin.unlock.level then
						unlockContext.justUnlocked = true
						break
					end
				end
			end
			changed = self:_unlockSkinInternal(skin.id, unlockContext) or changed
		end
	end

	if changed then
		self:_validateSelection()
		self:_save()
	end
end

function SnakeCosmetics:syncAchievements()
	self:_ensureLoaded()

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		local unlock = skin.unlock or {}
		if unlock.achievement then
			local definition = Achievements:getDefinition(unlock.achievement)
			if definition and definition.unlocked then
				local unlockContext = {
					source = "achievement",
					achievement = unlock.achievement,
				}
				changed = self:_unlockSkinInternal(skin.id, unlockContext) or changed
			end
		end
	end

	if changed then
		self:_validateSelection()
		self:_save()
	end
end

function SnakeCosmetics:onAchievementUnlocked(id)
	self:_ensureLoaded()

	local changed = false
	for _, skin in ipairs(self._orderedSkins or {}) do
		if matchesAchievementRequirement(skin, id) then
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
		self:syncMetaLevel(context.metaLevel)
	end

	self:syncAchievements()
end

function SnakeCosmetics:getSkins()
	self:_ensureLoaded()

	local list = {}
	local recentUnlocks = self.state.recentUnlocks or {}
	for _, skin in ipairs(self._orderedSkins or {}) do
		local entry = copyTable(skin)
		entry.unlocked = self.state.unlocked[skin.id] == true
		entry.selected = (self.state.selectedSkin == skin.id)
		entry.justUnlocked = recentUnlocks[skin.id] == true
		list[#list + 1] = entry
	end
	return list
end

function SnakeCosmetics:clearRecentUnlocks(ids)
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
			if id and self.state.recentUnlocks[id] then
				self.state.recentUnlocks[id] = nil
				changed = true
			end
		end
	else
		for id in pairs(self.state.recentUnlocks or {}) do
			self.state.recentUnlocks[id] = nil
			changed = true
		end
	end

	if changed then
		self:_save()
	end
end

function SnakeCosmetics:getActiveSkinId()
	self:_ensureLoaded()
	return self.state.selectedSkin or DEFAULT_SKIN_ID
end

function SnakeCosmetics:getActiveSkin()
	self:_ensureLoaded()
	local id = self:getActiveSkinId()
	return self._skinsById[id] or self._skinsById[DEFAULT_SKIN_ID]
end

function SnakeCosmetics:setActiveSkin(id)
	self:_ensureLoaded()

	if not id or not self._skinsById[id] then
		return false
	end

	if not self:isSkinUnlocked(id) then
		return false
	end

	if self.state.selectedSkin == id then
		return false
	end

	self.state.selectedSkin = id
	self:_save()
	return true
end

local function resolveColor(color, fallback)
	if type(color) == "table" and #color >= 3 then
		local r = color[1] or 0
		local g = color[2] or 0
		local b = color[3] or 0
		local a = color[4]
		return {r, g, b, a or 1}
	end

	if fallback then
		return resolveColor(fallback)
	end

	return {1, 1, 1, 1}
end

function SnakeCosmetics:getBodyColor()
	local skin = self:getActiveSkin()
	local palette = skin and skin.colors or {}
	return resolveColor(palette.body, Theme.snakeDefault)
end

function SnakeCosmetics:getOutlineColor()
	return resolveColor(DEFAULT_OUTLINE_COLOR)
end

function SnakeCosmetics:getGlowColor()
	local skin = self:getActiveSkin()
	local palette = skin and skin.colors or {}
	local effects = skin and skin.effects or {}
	local glowEffect = effects.glow or {}
	if glowEffect.color then
		return resolveColor(glowEffect.color)
	end
	return resolveColor(palette.glow, self:getBodyColor())
end

function SnakeCosmetics:getPaletteForSkin(skin)
	local target = skin or self:getActiveSkin()
	if not target then
		return {
			body = resolveColor(nil, Theme.snakeDefault),
			outline = resolveColor(DEFAULT_OUTLINE_COLOR),
			glow = resolveColor(nil, Theme.snakeDefault),
		}
	end

	local palette = target.colors or {}
	local effects = target.effects or {}

	local result = {}
	result.body = resolveColor(palette.body, Theme.snakeDefault)
	result.outline = resolveColor(DEFAULT_OUTLINE_COLOR)

	local glowEffect = effects.glow or {}
	if glowEffect.color then
		result.glow = resolveColor(glowEffect.color)
	else
		result.glow = resolveColor(palette.glow, result.body)
	end

        if effects.glow then
                result.glowEffect = copyTable(effects.glow)
        end

        return result
end

return SnakeCosmetics
