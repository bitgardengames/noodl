local Theme = require("theme")

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
			body = {0.52, 0.82, 0.72, 1},
			outline = {0.05, 0.15, 0.12, 1.0},
			glow = {0.35, 0.95, 0.80, 0.75},
		},
		unlock = {default = true},
		order = 0,
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

	local sanitized = {}
	for _, skin in ipairs(self._orderedSkins or {}) do
		local unlock = skin.unlock or {}
		if unlock.default then
			sanitized[skin.id] = true
		end
	end
	sanitized[DEFAULT_SKIN_ID] = true

	for id, unlocked in pairs(self.state.unlocked or {}) do
		if unlocked and sanitized[id] ~= nil then
			sanitized[id] = true
		end
	end

	self.state.unlocked = sanitized
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

function SnakeCosmetics:syncMetaLevel(level, context)
        self:_ensureLoaded()

        level = max(1, math.floor(level or 1))
        self._highestKnownMetaLevel = max(self._highestKnownMetaLevel or 0, level)
end

function SnakeCosmetics:syncAchievements()
        self:_ensureLoaded()
end

function SnakeCosmetics:onAchievementUnlocked(id)
        self:_ensureLoaded()
end

function SnakeCosmetics:load(context)
        self:_ensureLoaded()

        context = context or {}

        if context.metaLevel then
                self:syncMetaLevel(context.metaLevel)
        end
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

        local result = {}
        result.body = resolveColor(palette.body, Theme.snakeDefault)
        result.outline = resolveColor(DEFAULT_OUTLINE_COLOR)
        result.glow = resolveColor(palette.glow, result.body)

        return result
end

return SnakeCosmetics
