local Localization = {}

Localization._languages = {}
Localization._languageOrder = nil
Localization._currentCode = nil
Localization._currentStrings = {}
Localization._fallbackCode = "english"
Localization._fallbackStrings = {}
Localization._revision = 0
Localization._cachedStrings = {}
Localization._cachedTemplates = {}

local function resolveNode(tbl, key)
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

function Localization:setLanguage(code)
        if not code then
                code = self._fallbackCode
        end

	local data, err = self:_loadLanguage(code)
	if not data then
		if code ~= self._fallbackCode then
			return self:setLanguage(self._fallbackCode)
		end

		error("Failed to load language '" .. tostring(code) .. "': " .. tostring(err))
	end

	self._currentCode = code
	self._currentStrings = data.strings or {}

	local fallbackData = self:_loadLanguage(self._fallbackCode)
	if fallbackData then
		self._fallbackStrings = fallbackData.strings or {}
	end

        self._revision = (self._revision or 0) + 1
        self._cachedStrings = {}
        self._cachedTemplates = {}

        return true
end

local function compileTemplate(source)
        local parts = {}
        local hasPlaceholders = false
        local searchStart = 1

        while true do
                local startPos, endPos, name = source:find("%${([^}]+)}", searchStart)
                if not startPos then
                        break
                end

                hasPlaceholders = true

                if startPos > searchStart then
                        parts[#parts + 1] = source:sub(searchStart, startPos - 1)
                end

                parts[#parts + 1] = { name = name }
                searchStart = endPos + 1
        end

        if searchStart <= #source then
                parts[#parts + 1] = source:sub(searchStart)
        end

        if not hasPlaceholders then
                -- No substitutions were found, treat the whole string as a literal.
                parts = { source }
        end

        return {
                source = source,
                parts = parts,
                buffer = {},
                hasPlaceholders = hasPlaceholders,
        }
end

local function renderTemplate(template, replacements)
        local parts = template.parts
        local buffer = template.buffer

        for i = 1, #parts do
                local part = parts[i]
                if type(part) == "table" then
                        buffer[i] = tostring(replacements[part.name] or "")
                else
                        buffer[i] = part
                end
        end

        for i = #parts + 1, #buffer do
                buffer[i] = nil
        end

        return table.concat(buffer)
end

function Localization:get(key, replacements)
        if not key then
                return ""
        end

        local baseValue = self._cachedStrings[key]
        if baseValue == nil then
                local resolved = resolveNode(self._currentStrings, key) or resolveNode(self._fallbackStrings, key)
                if type(resolved) ~= "string" then
                        resolved = key
                end
                baseValue = resolved
                self._cachedStrings[key] = baseValue
        end

        if replacements and type(replacements) == "table" then
                local template = self._cachedTemplates[key]
                if not template or template.source ~= baseValue then
                        template = compileTemplate(baseValue)
                        self._cachedTemplates[key] = template
                end

                if not template.hasPlaceholders then
                        return baseValue
                end

                return renderTemplate(template, replacements)
        end

        return baseValue
end

function Localization:getTable(key)
	local value = resolveNode(self._currentStrings, key) or resolveNode(self._fallbackStrings, key)
	if type(value) == "table" then
		return value
	end
	return nil
end

function Localization:getCurrentLanguage()
	return self._currentCode or self._fallbackCode
end

function Localization:getLanguageName(code)
	local data = self:_loadLanguage(code)
	if data and data.name then
		return data.name
	end
	return code
end

local function scanLanguages()
	local items = {}
	for _, item in ipairs(love.filesystem.getDirectoryItems("Languages")) do
		if item:match("%.lua$") then
			items[#items + 1] = item:gsub("%.lua$", "")
		end
	end
	table.sort(items)
	return items
end

function Localization:getAvailableLanguages()
	if not self._languageOrder then
		self._languageOrder = scanLanguages()
	end
	return self._languageOrder
end

function Localization:getRevision()
	return self._revision or 0
end

return Localization