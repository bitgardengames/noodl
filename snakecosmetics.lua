local Theme = require("theme")

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
			body = Theme.defaultSnake,
			outline = {0, 0, 0, 1.0},
			glow = {0.35, 0.95, 0.80, 0.75},
		},
		unlock = {default = true},
		order = 0,
	},
}

local function buildDefaultState()
        return {
                selectedSkin = DEFAULT_SKIN_ID,
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

        self:_validateSelection()

        self._loaded = true
end

function SnakeCosmetics:_validateSelection()
        if not self.state then
                return
        end

        local selected = self.state.selectedSkin or DEFAULT_SKIN_ID
        if self._skinsById[selected] then
                self.state.selectedSkin = selected
                return
        end

        self.state.selectedSkin = DEFAULT_SKIN_ID
end

function SnakeCosmetics:_save()
        if not self._loaded then
                return
        end

        local snapshot = {
                selectedSkin = self.state.selectedSkin,
        }

	local serialized = "return " .. serialize(snapshot, 0) .. "\n"
	love.filesystem.write(SAVE_FILE, serialized)
end

function SnakeCosmetics:load(context)
        self:_ensureLoaded()
end

function SnakeCosmetics:getSkins()
        self:_ensureLoaded()

        local list = {}
        for _, skin in ipairs(self._orderedSkins or {}) do
                local entry = copyTable(skin)
                entry.unlocked = true
                entry.selected = (self.state.selectedSkin == skin.id)
                list[#list + 1] = entry
        end
        return list
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
