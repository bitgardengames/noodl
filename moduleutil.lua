local ModuleUtil = {}

local noop = function() end
local LIFECYCLE_HOOKS = {"load", "reset", "update", "draw"}
local EMPTY_TABLE = {}

function ModuleUtil.create(name, defaults)
	if defaults ~= nil and type(defaults) ~= "table" then
		error("module defaults must be a table if provided")
	end

	local module = {}
	if type(defaults) == "table" then
		for key, value in pairs(defaults) do
			module[key] = value
		end
	end

	module.__name = name

	return module
end

local function ensureLifecycle(system, fallbacks)
	if type(system) ~= "table" then
		error("system must be a table")
	end

	local fallbackHandlers = fallbacks or EMPTY_TABLE

	for _, hook in ipairs(LIFECYCLE_HOOKS) do
		if system[hook] == nil then
			system[hook] = fallbackHandlers[hook] or noop
		end
	end

	return system
end

function ModuleUtil.prepareSystems(systems, fallbacks)
	if type(systems) ~= "table" then
		return {}
	end

	local prepared = {}
	for index, system in ipairs(systems) do
		if type(system) == "table" then
			prepared[index] = ensureLifecycle(system, fallbacks)
		else
			prepared[index] = system
		end
	end

	return prepared
end

function ModuleUtil.runHook(systems, hook, ...)
	if not systems or not hook then
		return
	end

	for _, system in ipairs(systems) do
		local handler = system and system[hook]
		if type(handler) == "function" then
			handler(system, ...)
		end
	end
end

return ModuleUtil