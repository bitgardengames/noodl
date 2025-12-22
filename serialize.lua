local Serialization = {}

local DEFAULT_INDENT_STEP = 4
local IDENTIFIER_PATTERN = "^[%a_][%w_]*$"

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

Serialization.isArray = isArray

local function defaultKeyComparator(a, b)
	if type(a) == "number" and type(b) == "number" then
		return a < b
	end

	return tostring(a) < tostring(b)
end

local function sortedKeyIterator(tbl, comparator)
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end

	table.sort(keys, comparator or defaultKeyComparator)

	local index = 0
	return function()
		index = index + 1
		local key = keys[index]
		if key ~= nil then
			return key, tbl[key]
		end
	end
end

local function iterateKeys(tbl, options)
	if options and options.sortKeys == false then
		return pairs(tbl)
	end

	return sortedKeyIterator(tbl, options and options.keyComparator)
end

local function formatKey(key, options)
	if type(key) == "string" then
		if not (options and options.quoteKeys) and key:match(IDENTIFIER_PATTERN) then
			return key .. " = "
		end
		return string.format("[%q] = ", key)
	elseif type(key) == "number" then
		return string.format("[%d] = ", key)
	else
		return string.format("[%q] = ", tostring(key))
	end
end

local function serializeValue(value, options, indent)
	indent = indent or options.indent or 0
	local valueType = type(value)

	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	elseif valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "table" then
		local spacing = string.rep(" ", indent)
		local lines = {"{\n"}
		local step = options.indentStep or DEFAULT_INDENT_STEP
		local nextIndent = indent + step
		local entryIndent = string.rep(" ", nextIndent)

		if isArray(value) then
			for index, val in ipairs(value) do
				lines[#lines + 1] = string.format("%s[%d] = %s,\n", entryIndent, index, serializeValue(val, options, nextIndent))
			end
		else
			for key, val in iterateKeys(value, options) do
				lines[#lines + 1] = string.format("%s%s%s,\n", entryIndent, formatKey(key, options), serializeValue(val, options, nextIndent))
			end
		end

		lines[#lines + 1] = string.format("%s}", spacing)
		return table.concat(lines)
	end

	return "nil"
end

function Serialization.serialize(value, options)
	return serializeValue(value, options or {}, nil)
end

function Serialization.saveTable(path, value, options)
	local serialized = Serialization.serialize(value, options)
	local prefix = "return "
	if options and options.prefix ~= nil then
		prefix = options.prefix
	end

	local suffix = "\n"
	if options and options.suffix ~= nil then
		suffix = options.suffix
	end

	return love.filesystem.write(path, string.format("%s%s%s", prefix, serialized, suffix))
end

function Serialization.loadTable(path)
	if not love.filesystem.getInfo(path) then
		return nil
	end

	local ok, chunk = pcall(love.filesystem.load, path)
	if not (ok and chunk) then
		return nil
	end

	local success, data = pcall(chunk)
	if success and type(data) == "table" then
		return data
	end

	return nil
end

return Serialization
