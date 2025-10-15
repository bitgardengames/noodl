local ModuleUtil = {}

local noop = function() end
local LIFECYCLE_HOOKS = { "load", "reset", "update", "draw" }

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

function ModuleUtil.EnsureLifecycle(system, fallbacks)
	if type(system) ~= "table" then
		error("system must be a table")
	end

	local FallbackHandlers = fallbacks or {}

	for _, hook in ipairs(LIFECYCLE_HOOKS) do
		if system[hook] == nil then
			system[hook] = FallbackHandlers[hook] or noop
		end
	end

	return system
end

function ModuleUtil.PrepareSystems(systems, fallbacks)
	if type(systems) ~= "table" then
		return {}
	end

	local prepared = {}
	for index, system in ipairs(systems) do
		if type(system) == "table" then
			prepared[index] = ModuleUtil.EnsureLifecycle(system, fallbacks)
		else
			prepared[index] = system
		end
	end

	return prepared
end

function ModuleUtil.RunHook(systems, hook, ...)
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

ModuleUtil.noop = noop

return ModuleUtil
