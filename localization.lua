local Localization = {}

Localization._languages = {}
Localization._languageOrder = nil
Localization._currentCode = nil
Localization._currentStrings = {}
Localization._fallbackCode = "english"
Localization._fallbackStrings = {}

local function ResolveNode(tbl, key)
	local value = tbl
	for part in key:gmatch("[^%.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end

	return value
end

function Localization:_loadLanguage(code)
	if not self._languages[code] then
		local ok, data = pcall(require, "Languages." .. code)
		if not ok then
			return nil, data
		end

		if type(data) ~= "table" then
			return nil, "Language module must return a table"
		end

		self._languages[code] = data
	end

	return self._languages[code]
end

function Localization:SetLanguage(code)
	if not code then
		code = self._fallbackCode
	end

	local data, err = self:_loadLanguage(code)
	if not data then
		if code ~= self._fallbackCode then
			return self:SetLanguage(self._fallbackCode)
		end

		error("Failed to load language '" .. tostring(code) .. "': " .. tostring(err))
	end

	self._currentCode = code
	self._currentStrings = data.strings or {}

	local FallbackData = self:_loadLanguage(self._fallbackCode)
	if FallbackData then
		self._fallbackStrings = FallbackData.strings or {}
	end

	return true
end

function Localization:get(key, replacements)
	if not key then
		return ""
	end

	local result = ResolveNode(self._currentStrings, key) or ResolveNode(self._fallbackStrings, key)
	local value = result
	if type(value) ~= "string" then
		value = key
	end

	if replacements and type(replacements) == "table" then
		value = value:gsub("%${([^}]+)}", function(name)
			return tostring(replacements[name] or "")
		end)
	end

	return value
end

function Localization:GetTable(key)
	local value = ResolveNode(self._currentStrings, key) or ResolveNode(self._fallbackStrings, key)
	if type(value) == "table" then
		return value
	end
	return nil
end

function Localization:GetCurrentLanguage()
	return self._currentCode or self._fallbackCode
end

function Localization:GetLanguageName(code)
	local data = self:_loadLanguage(code)
	if data and data.name then
		return data.name
	end
	return code
end

local function ScanLanguages()
	local items = {}
	for _, item in ipairs(love.filesystem.getDirectoryItems("Languages")) do
		if item:match("%.lua$") then
			items[#items + 1] = item:gsub("%.lua$", "")
		end
	end
	table.sort(items)
	return items
end

function Localization:GetAvailableLanguages()
	if not self._languageOrder then
		self._languageOrder = ScanLanguages()
	end
	return self._languageOrder
end

return Localization
