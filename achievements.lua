local Audio = require("audio")
local Localization = require("localization")
local PlayerStats = require("playerstats")
local DailyProgress = require("dailyprogress")
local SessionStats = require("sessionstats")
local floor = math.floor
local min = math.min
local m_type = math.type
local insert = table.insert
local sort = table.sort

local Achievements = {
	definitions = {},
	definitionOrder = {},
	categories = {},
	categoryOrder = {},
	unlocked = {},
	popupQueue = {},
	popupTimer = 0,
	popupDuration = 3,
	stateProviders = {},
	_statIndex = {},
	_fallbackDefinitions = {},
}

local DEFAULT_CATEGORY_ORDER = 100
local DEFAULT_ORDER = 1000

local currentDefinitionsForSort

local function compareAchievementIds(aId, bId)
	local definitions = currentDefinitionsForSort
	if not definitions then
		return tostring(aId) < tostring(bId)
	end

	local a = definitions[aId]
	local b = definitions[bId]
	if not a or not b then
		return tostring(aId) < tostring(bId)
	end
	if a.order == b.order then
		return (a.titleKey or a.id) < (b.titleKey or b.id)
	end
	return (a.order or DEFAULT_ORDER) < (b.order or DEFAULT_ORDER)
end

local function compareCategoryEntries(a, b)
	if a.order == b.order then
		return a.id < b.id
	end
	return a.order < b.order
end

local function copyTable(source)
	local target = {}
	if source then
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

local function applyDefaults(def)
	def.id = def.id or ""
	def.titleKey = def.titleKey or ("achievements_definitions." .. def.id .. ".title")
	def.descriptionKey = def.descriptionKey or ("achievements_definitions." .. def.id .. ".description")
	def.category = def.category or "general"
	def.goal = def.goal or 0
	def.order = def.order or DEFAULT_ORDER
	def.categoryOrder = def.categoryOrder or DEFAULT_CATEGORY_ORDER
	def.unlocked = false
	def.progress = 0
	def.popupIcon = def.popupIcon or def.icon
	def.hidden = def.hidden or false
	return def
end

function Achievements:registerStateProvider(provider)
	if type(provider) == "function" then
		insert(self.stateProviders, provider)
	end
end

function Achievements:registerUnlockListener(listener)
	if type(listener) ~= "function" then
		return
	end

	self:_ensureInitialized()

	self._unlockListeners = self._unlockListeners or {}
	insert(self._unlockListeners, listener)
end

function Achievements:_notifyUnlockListeners(id, achievement)
	if not self._unlockListeners then
		return
	end

	for _, listener in ipairs(self._unlockListeners) do
		local ok, err = pcall(listener, id, achievement)
		if not ok then
			print("[achievements] unlock listener failed for", tostring(id), err)
		end
	end
end

function Achievements:_addDefinition(rawDef)
	local def = applyDefaults(copyTable(rawDef))
	self.definitions[def.id] = def
	insert(self.definitionOrder, def.id)

	self.categories[def.category] = self.categories[def.category] or {}
	insert(self.categories[def.category], def.id)

	if def.stat then
		local statIndex = self._statIndex[def.stat]
		if not statIndex then
			statIndex = {}
			self._statIndex[def.stat] = statIndex
		end
		statIndex[#statIndex + 1] = def.id
	else
		if not def.progressFn and not def.condition then
			if not self._statlessWarning then
				self._statlessWarning = {}
			end
			if not self._statlessWarning[def.id] then
				print("[achievements] definition without stat or custom handlers:", def.id)
				self._statlessWarning[def.id] = true
			end
		end
		insert(self._fallbackDefinitions, def.id)
	end
end

function Achievements:_finalizeOrdering()
	currentDefinitionsForSort = self.definitions
	sort(self.definitionOrder, compareAchievementIds)

	local orderedCategories = {}
	for category, ids in pairs(self.categories) do
		sort(ids, compareAchievementIds)
		orderedCategories[#orderedCategories + 1] = {
			id = category,
			order = (self.definitions[ids[1]] and self.definitions[ids[1]].categoryOrder) or DEFAULT_CATEGORY_ORDER
		}
	end

	currentDefinitionsForSort = nil

	sort(orderedCategories, compareCategoryEntries)

	self.categoryOrder = {}
	for _, info in ipairs(orderedCategories) do
		insert(self.categoryOrder, info.id)
	end

	if self._fallbackDefinitions then
		local fallbackLookup = {}
		for i = 1, #self._fallbackDefinitions do
			fallbackLookup[self._fallbackDefinitions[i]] = true
		end

		local orderedFallback = {}
		for i = 1, #self.definitionOrder do
			local id = self.definitionOrder[i]
			if fallbackLookup[id] then
				orderedFallback[#orderedFallback + 1] = id
			end
		end

		self._fallbackDefinitions = orderedFallback
	end

	if self._statIndex then
		local position = {}
		for i = 1, #self.definitionOrder do
			position[self.definitionOrder[i]] = i
		end

		for stat, ids in pairs(self._statIndex) do
			sort(ids, function(a, b)
				return (position[a] or 0) < (position[b] or 0
			)
				end
			)
		end
	end
end

function Achievements:_ensureInitialized()
	if self._initialized then
		return
	end

	local ok, definitions = pcall(require, "achievement_definitions")
	if not ok then
		error("Failed to load achievement definitions: " .. tostring(definitions))
	end

	for _, def in ipairs(definitions) do
		self:_addDefinition(def)
	end

	self:_finalizeOrdering()

	if not self._defaultProvidersRegistered then
		self:registerStateProvider(function(state)
			state.totalFruitEaten = PlayerStats:get("totalFruitEaten") or 0
			state.totalDragonfruitEaten = PlayerStats:get("totalDragonfruitEaten") or 0
			state.bestComboStreak = PlayerStats:get("bestComboStreak") or 0
                        local totals = DailyProgress:getTotals()
                        state.dailyChallengesCompleted = (totals and totals.completed) or 0
			state.shieldWallBounces = PlayerStats:get("shieldWallBounces") or 0
			state.shieldRockBreaks = PlayerStats:get("shieldRockBreaks") or 0
			state.shieldSawParries = PlayerStats:get("shieldSawParries") or 0
			end
		)

		self:registerStateProvider(function(state)
			state.runFloorsCleared = SessionStats:get("floorsCleared") or 0
			state.runShieldWallBounces = SessionStats:get("runShieldWallBounces") or 0
			state.runShieldRockBreaks = SessionStats:get("runShieldRockBreaks") or 0
			state.runShieldSawParries = SessionStats:get("runShieldSawParries") or 0
			state.runDragonfruitEaten = SessionStats:get("dragonfruitEaten") or 0
			state.runBestComboStreak = SessionStats:get("bestComboStreak") or 0
			end
		)

		self._defaultProvidersRegistered = true
	end

	self._iconCache = {}
	self._initialized = true
end

local function mergeStateValue(target, key, value)
	local existing = target[key]
	if type(value) == "number" then
		if type(existing) == "number" then
			if value > existing then
				target[key] = value
			end
		else
			target[key] = value
		end
	else
		if existing == nil then
			target[key] = value
		end
	end
end

function Achievements:_mergeState(target, source)
	if not source then return end
	for key, value in pairs(source) do
		mergeStateValue(target, key, value)
	end
end

local function clearTable(t)
	for key in pairs(t) do
		t[key] = nil
	end
end

function Achievements:_buildState(external)
	self._combinedState = self._combinedState or {}
	local combined = self._combinedState
	clearTable(combined)

	for _, provider in ipairs(self.stateProviders) do
		local ok, result = pcall(provider, combined)
		if ok then
			if type(result) == "table" and result ~= combined then
				self:_mergeState(combined, result)
			end
		else
			print("[achievements] state provider failed:", result)
		end
	end

	if external then
		self:_mergeState(combined, external)
	end

	return combined
end

local function evaluateProgress(def, state)
	if def.progressFn then
		local ok, value = pcall(def.progressFn, state, def)
		if ok and type(value) == "number" then
			return value
		elseif not ok then
			print("[achievements] progress function failed for", def.id, value)
		end
	end

	if def.stat then
		return state[def.stat] or 0
	end

	return def.progress or 0
end

local function shouldUnlock(def, state, progress)
	if def.condition then
		local ok, result = pcall(def.condition, state, def)
		if ok then
			if type(result) == "boolean" then
				return result
			elseif type(result) == "number" then
				return result >= (def.goal or result)
			end
		else
			print("[achievements] condition failed for", def.id, result)
		end
	end

	if def.goal and def.goal > 0 then
		return progress >= def.goal
	end

	return false
end

local function clampProgress(def, progress)
	if def.goal and def.goal > 0 then
		return min(progress, def.goal)
	end
	return progress
end

function Achievements:unlock(name)
	self:_ensureInitialized()

	local achievement = self.definitions[name]
	if not achievement then
		print("Unknown achievement:", name)
		return
	end

	if achievement.unlocked then
		return
	end

	achievement.unlocked = true
	if achievement.goal then
		achievement.progress = achievement.goal
	end
	achievement.unlockedAt = os.time()

	if not self._unlockedLookup then
		self._unlockedLookup = {}
	end
	if not self._unlockedLookup[name] then
		insert(self.unlocked, name)
		self._unlockedLookup[name] = true
	end

	local runAchievements = SessionStats:get("runAchievements")
	if type(runAchievements) ~= "table" then
		runAchievements = {}
	end
	local alreadyRecorded = false
	for _, id in ipairs(runAchievements) do
		if id == name then
			alreadyRecorded = true
			break
		end
	end
	if not alreadyRecorded then
		runAchievements[#runAchievements + 1] = name
		SessionStats:set("runAchievements", runAchievements)
	end

	insert(self.popupQueue, achievement)

	if Audio and Audio.playSound then
		Audio:playSound("achievement")
	end

	self:save()

	self:_notifyUnlockListeners(name, achievement)
end

function Achievements:check(key, state)
	self:_ensureInitialized()

	local achievement = self.definitions[key]
	if not achievement then
		return
	end

	if achievement.unlocked then
		return
	end

	local combinedState = self:_buildState(state)
	local progress = evaluateProgress(achievement, combinedState)
	if type(progress) == "number" then
		achievement.progress = clampProgress(achievement, progress)
	end

	if not achievement.unlocked and shouldUnlock(achievement, combinedState, progress) then
		self:unlock(key)
	end
end

function Achievements:checkAll(state)
	self:_ensureInitialized()

	local combinedState = self:_buildState(state)

	local stateKeysProvided = type(state) == "table" and next(state) ~= nil
	local candidateLookup

	if stateKeysProvided then
		candidateLookup = self._candidateLookup or {}
		self._candidateLookup = candidateLookup
		for key in pairs(candidateLookup) do
			candidateLookup[key] = nil
		end

		if self._statIndex then
			for key in pairs(state) do
				local ids = self._statIndex[key]
				if ids then
					for i = 1, #ids do
						candidateLookup[ids[i]] = true
					end
				end
			end
		end

		if self._fallbackDefinitions then
			for i = 1, #self._fallbackDefinitions do
				candidateLookup[self._fallbackDefinitions[i]] = true
			end
		end
	end

	local iterateAll = not stateKeysProvided

	for i = 1, #self.definitionOrder do
		local key = self.definitionOrder[i]
		if iterateAll or (candidateLookup and candidateLookup[key]) then
			local achievement = self.definitions[key]
			if achievement and not achievement.unlocked then
				local progress = evaluateProgress(achievement, combinedState)
				if type(progress) == "number" then
					achievement.progress = clampProgress(achievement, progress)
				end

				if shouldUnlock(achievement, combinedState, progress) then
					self:unlock(key)
				end
			end
		end
	end

	if candidateLookup then
		for key in pairs(candidateLookup) do
			candidateLookup[key] = nil
		end
	end
end

function Achievements:update(dt)
	self:_ensureInitialized()

	if #self.popupQueue > 0 then
		self.popupTimer = self.popupTimer + dt
		local totalTime = self.popupDuration + 1.0

		if self.popupTimer >= totalTime then
			table.remove(self.popupQueue, 1)
			self.popupTimer = 0
		end
	end
end

function Achievements:_getPopupFonts()
	local UI = require("ui")
	return UI.fonts.badge or UI.fonts.button, UI.fonts.caption or UI.fonts.body
end

local function iconPaths(iconName)
	return {
		string.format("Assets/Achievements/%s.png", iconName),
		string.format("Assets/%s.png", iconName),
	}
end

function Achievements:_getIcon(iconName)
	if not iconName then return nil end
	self._iconCache = self._iconCache or {}

	if self._iconCache[iconName] ~= nil then
		return self._iconCache[iconName]
	end

	for _, path in ipairs(iconPaths(iconName)) do
		if love.filesystem.getInfo(path) then
			local ok, image = pcall(love.graphics.newImage, path)
			if ok then
				self._iconCache[iconName] = image
				return image
			end
		end
	end

	self._iconCache[iconName] = false
	return nil
end

function Achievements:draw()
	self:_ensureInitialized()

	if #self.popupQueue == 0 then
		return
	end

	local ach = self.popupQueue[1]
	local Screen = require("screen")
	local sw, sh = Screen:get()

	local fontTitle, fontDesc = self:_getPopupFonts()

	local padding = 20
	local width = 500
	local height = 100
	local baseX = (sw - width) / 2
	local baseY = sh * 0.25

	local appearTime = 0.4
	local holdTime = self.popupDuration
	local exitTime = 0.6

	local t = self.popupTimer
	local alpha, offsetY, scale = 1, 0, 1

	if t < appearTime then
		local p = t / appearTime
		local ease = p * p * (3 - 2 * p)
		offsetY = (1 - ease) * -150
		scale = 1.0 + 0.2 * (1 - ease)
		alpha = ease
	elseif t < appearTime + holdTime then
		offsetY = 0
		scale = 1.0
		alpha = 1
	else
		local p = (t - appearTime - holdTime) / exitTime
		local ease = p * p
		offsetY = ease * -150
		alpha = 1 - ease
	end

	local x = baseX
	local y = baseY + offsetY

	love.graphics.push()
	love.graphics.translate(x + width / 2, y + height / 2)
	love.graphics.scale(scale)
	love.graphics.translate(-(x + width / 2), -(y + height / 2))

	love.graphics.setColor(0, 0, 0, 0.75 * alpha)
	love.graphics.rectangle("fill", x, y, width, height, 12, 12)

	local icon = self:_getIcon(ach.popupIcon or ach.icon)
	local iconSize = 64
	local iconSpace = icon and iconSize or 0

	if icon then
		love.graphics.setColor(1, 1, 1, alpha)
		local scaleX = iconSize / icon:getWidth()
		local scaleY = iconSize / icon:getHeight()
		love.graphics.draw(icon, x + padding, y + (height - iconSize) / 2, 0, scaleX, scaleY)
	end

	local localizedTitle = Localization:get(ach.titleKey)
	local localizedDescription = Localization:get(ach.descriptionKey)
	local heading = Localization:get("achievements.popup_heading", {title = localizedTitle})

	love.graphics.setColor(1, 1, 0.2, alpha)
	love.graphics.setFont(fontTitle)
	love.graphics.printf(heading, x + padding + iconSpace, y + 15, width - (padding * 2) - iconSpace, "left")

	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.setFont(fontDesc)
	local message = Localization:get("achievements.popup_message", {
		title = localizedTitle,
		description = localizedDescription,
		}
	)
	love.graphics.printf(message, x + padding + iconSpace, y + 50, width - (padding * 2) - iconSpace, "left")

	love.graphics.pop()
end

local function serializeValue(value)
	if type(value) == "number" then
		if m_type and m_type(value) == "integer" then
			return string.format("%d", value)
		end
		return string.format("%0.4f", value)
	end
	return tostring(value)
end

function Achievements:save()
	self:_ensureInitialized()

	local data = {}
	for key, ach in pairs(self.definitions) do
		data[key] = {
			unlocked = ach.unlocked,
			progress = ach.progress,
		}
	end

	local lines = {"return {"}
	for key, value in pairs(data) do
		insert(lines, string.format("  [\"%s\"] = {unlocked = %s, progress = %s},",
			key, tostring(value.unlocked), serializeValue(value.progress or 0
		)
		)
		)
	end
	insert(lines, "}")

	local luaData = table.concat(lines, "\n")
	love.filesystem.write("achievementdata.lua", luaData)
end

local function applySavedData(definitions, saved)
	for key, info in pairs(saved) do
		local def = definitions[key]
		if def then
			def.unlocked = info.unlocked or false
			if info.progress ~= nil then
				if type(info.progress) == "number" then
					def.progress = info.progress
				elseif type(info.progress) == "string" then
					local numeric = tonumber(info.progress)
					if numeric then
						def.progress = numeric
					end
				end
			end
		end
	end
end

function Achievements:load()
	self:_ensureInitialized()

	if love.filesystem.getInfo("achievementdata.lua") then
		local chunk = love.filesystem.load("achievementdata.lua")
		local ok, data = pcall(chunk)
		if ok and type(data) == "table" then
			applySavedData(self.definitions, data)
		end
	end
end

function Achievements:getDisplayOrder()
	self:_ensureInitialized()

	local blocks = {}
	for _, category in ipairs(self.categoryOrder) do
		local ids = self.categories[category] or {}
		local entries = {}
		for _, id in ipairs(ids) do
			entries[#entries + 1] = self.definitions[id]
		end
		blocks[#blocks + 1] = {
			id = category,
			achievements = entries,
		}
	end
	return blocks
end

function Achievements:getProgressLabel(def)
	self:_ensureInitialized()

	if def.unlocked then
		return Localization:get("achievements.progress.unlocked")
	end

	if def.hidden and not def.unlocked then
		return Localization:get("achievements.hidden.progress")
	end

	if def.formatProgress then
		local ok, result = pcall(def.formatProgress, def)
		if ok and result then
			return result
		end
	end

	if def.goal and def.goal > 0 then
		local progress = floor(def.progress or 0)
		local goal = floor(def.goal)
		return Localization:get("achievements.progress.label", {
			current = progress,
			goal = goal,
			}
		)
	end

	return nil
end

function Achievements:getProgressRatio(def)
	if def.unlocked then
		return 1
	end

	if def.goal and def.goal > 0 then
		return min(1, (def.progress or 0) / def.goal)
	end

	return 0
end

function Achievements:getTotals()
	self:_ensureInitialized()

	local total = #self.definitionOrder
	local unlocked = 0
	local completion = 0

	if total == 0 then
		return {
			total = 0,
			unlocked = 0,
			completion = 0,
		}
	end

	for _, id in ipairs(self.definitionOrder) do
		local def = self.definitions[id]
		if def and def.unlocked then
			unlocked = unlocked + 1
		end
	end

	completion = unlocked / total

	return {
		total = total,
		unlocked = unlocked,
		completion = completion,
	}
end

function Achievements:getDefinition(id)
	self:_ensureInitialized()
	return self.definitions[id]
end

return Achievements
