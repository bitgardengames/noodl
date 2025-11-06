local ModuleUtil = {}

local noop = function() end
local LIFECYCLE_HOOKS = {"load", "reset", "update", "draw"}
local EMPTY_TABLE = {}
local HANDLER_CACHE_FIELD = "__handlerCache"
local SYSTEM_REGISTRY_FIELD = "__moduleUtilHandlerEntries"
local METATABLE_PATCH_FLAG = "__moduleUtilLifecyclePatched"

local function createHandlerCache(container)
	local handlers = {}
	for _, hook in ipairs(LIFECYCLE_HOOKS) do
		handlers[hook] = {}
	end

	if container then
		container[HANDLER_CACHE_FIELD] = handlers
	end

	return handlers
end

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

local function invalidateRegistryEntries(registry, hook)
	local entries = registry and registry[hook]
	if not entries then
		return
	end

	for index = 1, #entries do
		entries[index].handler = nil
	end
end

local function patchLifecycleMetatable(system, registry)
	local meta = getmetatable(system)
	if meta and meta[METATABLE_PATCH_FLAG] then
		return
	end

	local newMeta = {}
	local originalNewIndex

	if meta then
		for key, value in pairs(meta) do
			newMeta[key] = value
		end
		originalNewIndex = meta.__newindex
	else
		originalNewIndex = nil
	end

	newMeta.__newindex = function(tbl, key, value)
		if type(originalNewIndex) == "function" then
			originalNewIndex(tbl, key, value)
		elseif type(originalNewIndex) == "table" then
			rawset(originalNewIndex, key, value)
		else
			rawset(tbl, key, value)
		end

		invalidateRegistryEntries(registry, key)
	end

	newMeta[METATABLE_PATCH_FLAG] = true

	setmetatable(system, newMeta)
end

local function getOrCreateRegistry(system)
	local registry = rawget(system, SYSTEM_REGISTRY_FIELD)
	if not registry then
		registry = {}
		rawset(system, SYSTEM_REGISTRY_FIELD, registry)
	end

	return registry
end

local function trackEntry(system, hook, entry)
	local registry = getOrCreateRegistry(system)
	local hookEntries = registry[hook]
	if not hookEntries then
		hookEntries = {}
		registry[hook] = hookEntries
	end

	hookEntries[#hookEntries + 1] = entry

	patchLifecycleMetatable(system, registry)
end

local function registerHandler(handlerCache, hook, system)
	if not handlerCache then
		return
	end

	local handler = system and system[hook]
	if type(handler) ~= "function" then
		return
	end

	local entry = {system = system, handler = handler}

	local entries = handlerCache[hook]
	entries[#entries + 1] = entry

	if type(system) == "table" then
		trackEntry(system, hook, entry)
	end
end

local function resolveHandler(entry, hook)
	local handler = entry.handler
	if handler ~= nil then
		return handler
	end

	local system = entry.system
	if not system then
		return nil
	end

	local updated = system[hook]
	if type(updated) == "function" then
		entry.handler = updated
		return updated
	end

	return nil
end

local function runCachedHandlers(entries, hook, ...)
	for index = 1, #entries do
		local entry = entries[index]
		local handler = resolveHandler(entry, hook)
		if handler then
			handler(entry.system, ...)
		end
	end
end

local function getHandlerCache(systems)
	if type(systems) ~= "table" then
		return nil
	end

	return systems[HANDLER_CACHE_FIELD]
end

function ModuleUtil.prepareSystems(systems, fallbacks)
	local prepared = {}
	local handlerCache = createHandlerCache(prepared)

	if type(systems) ~= "table" then
		return prepared
	end

	for index, system in ipairs(systems) do
		local preparedSystem
		if type(system) == "table" then
			preparedSystem = ensureLifecycle(system, fallbacks)
			for _, hook in ipairs(LIFECYCLE_HOOKS) do
				registerHandler(handlerCache, hook, preparedSystem)
			end
		else
			preparedSystem = system
		end

		prepared[index] = preparedSystem
	end

	return prepared
end

function ModuleUtil.getHookHandlers(systems, hook)
	local handlerCache = getHandlerCache(systems)
	if handlerCache then
		return handlerCache[hook]
	end

	return nil
end

function ModuleUtil.runCachedHandlers(entries, hook, ...)
	if not entries then
		return
	end

	runCachedHandlers(entries, hook, ...)
end

function ModuleUtil.runHook(systems, hook, ...)
	if not systems or not hook then
		return
	end

	local handlerCache = getHandlerCache(systems)
	if handlerCache then
		local handlers = handlerCache[hook]
		if handlers then
			runCachedHandlers(handlers, hook, ...)
			return
		end
	end

	for _, system in ipairs(systems) do
		local handler = system and system[hook]
		if type(handler) == "function" then
			handler(system, ...)
		end
	end
end

return ModuleUtil
