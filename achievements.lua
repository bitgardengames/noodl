local Audio = require("audio")
local Localization = require("localization")
local PlayerStats = require("playerstats")
local SessionStats = require("sessionstats")
local Snake
local MetaProgression

local Achievements = {
	definitions = {},
	DefinitionOrder = {},
	categories = {},
	CategoryOrder = {},
	unlocked = {},
	PopupQueue = {},
	PopupTimer = 0,
	PopupDuration = 3,
	StateProviders = {},
}

local DEFAULT_CATEGORY_ORDER = 100
local DEFAULT_ORDER = 1000
local function CopyTable(source)
	local target = {}
	if source then
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

local function ApplyDefaults(def)
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

function Achievements:RegisterStateProvider(provider)
	if type(provider) == "function" then
		table.insert(self.StateProviders, provider)
	end
end

function Achievements:RegisterUnlockListener(listener)
	if type(listener) ~= "function" then
		return
	end

	self:_ensureInitialized()

	self._unlockListeners = self._unlockListeners or {}
	table.insert(self._unlockListeners, listener)
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

function Achievements:_addDefinition(RawDef)
	local def = ApplyDefaults(CopyTable(RawDef))
	self.definitions[def.id] = def
	table.insert(self.DefinitionOrder, def.id)

	self.categories[def.category] = self.categories[def.category] or {}
	table.insert(self.categories[def.category], def.id)
end

local function SortAchievements(AId, BId, definitions)
	local a = definitions[AId]
	local b = definitions[BId]
	if a.order == b.order then
		return (a.titleKey or a.id) < (b.titleKey or b.id)
	end
	return (a.order or DEFAULT_ORDER) < (b.order or DEFAULT_ORDER)
end

function Achievements:_finalizeOrdering()
	table.sort(self.DefinitionOrder, function(AId, BId)
		return SortAchievements(AId, BId, self.definitions)
	end)

	local OrderedCategories = {}
	for category, ids in pairs(self.categories) do
		table.sort(ids, function(AId, BId)
			return SortAchievements(AId, BId, self.definitions)
		end)
		OrderedCategories[#OrderedCategories + 1] = {
			id = category,
			order = (self.definitions[ids[1]] and self.definitions[ids[1]].CategoryOrder) or DEFAULT_CATEGORY_ORDER
		}
	end

	table.sort(OrderedCategories, function(a, b)
		if a.order == b.order then
			return a.id < b.id
		end
		return a.order < b.order
	end)

	self.CategoryOrder = {}
	for _, info in ipairs(OrderedCategories) do
		table.insert(self.CategoryOrder, info.id)
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
		self:RegisterStateProvider(function()
			return {
				TotalApplesEaten = PlayerStats:get("TotalApplesEaten") or 0,
				SessionsPlayed = PlayerStats:get("SessionsPlayed") or 0,
				TotalDragonfruitEaten = PlayerStats:get("TotalDragonfruitEaten") or 0,
				BestScore = PlayerStats:get("SnakeScore") or 0,
				FloorsCleared = PlayerStats:get("FloorsCleared") or 0,
				DeepestFloorReached = PlayerStats:get("DeepestFloorReached") or 0,
				BestComboStreak = PlayerStats:get("BestComboStreak") or 0,
				DailyChallengesCompleted = PlayerStats:get("DailyChallengesCompleted") or 0,
				ShieldWallBounces = PlayerStats:get("ShieldWallBounces") or 0,
				ShieldRockBreaks = PlayerStats:get("ShieldRockBreaks") or 0,
				ShieldSawParries = PlayerStats:get("ShieldSawParries") or 0,
			}
		end)

		self:RegisterStateProvider(function()
			local SessionStats = require("sessionstats")
			return {
				RunApplesEaten = SessionStats:get("ApplesEaten") or 0,
				RunFloorsCleared = SessionStats:get("FloorsCleared") or 0,
				RunDeepestFloor = SessionStats:get("DeepestFloorReached") or 0,
				RunShieldWallBounces = SessionStats:get("RunShieldWallBounces") or 0,
				RunShieldRockBreaks = SessionStats:get("RunShieldRockBreaks") or 0,
				RunShieldSawParries = SessionStats:get("RunShieldSawParries") or 0,
				RunCrashShieldsSaved = SessionStats:get("CrashShieldsSaved") or 0,
				RunDragonfruitEaten = SessionStats:get("DragonfruitEaten") or 0,
				RunBestComboStreak = SessionStats:get("BestComboStreak") or 0,
				FruitWithoutTurning = SessionStats:get("FruitWithoutTurning") or 0,
			}
		end)

		self:RegisterStateProvider(function()
			if not Snake then
				local ok, module = pcall(require, "snake")
				if ok then
					Snake = module
				else
					print("[achievements] failed to require snake:", module)
					return nil
				end
			end

			if Snake and Snake.GetLength then
				local length = Snake:GetLength()
				if length then
					return { SnakeLength = length }
				end
			end
			return nil
		end)

		self:RegisterStateProvider(function()
			if not MetaProgression then
				local ok, module = pcall(require, "metaprogression")
				if ok then
					MetaProgression = module
				else
					print("[achievements] failed to require metaprogression:", module)
					return nil
				end
			end

			if MetaProgression and MetaProgression.GetState then
				local ok, state = pcall(MetaProgression.GetState, MetaProgression)
				if ok and type(state) == "table" then
					return {
						TotalMetaExperience = state.totalExperience or 0,
						MetaLevel = state.level or 0,
					}
				elseif not ok then
					print("[achievements] failed to query metaprogression state:", state)
				end
			end

			return nil
		end)

		self._defaultProvidersRegistered = true
	end

	self._iconCache = {}
	self._initialized = true
end

local function MergeStateValue(target, key, value)
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
		MergeStateValue(target, key, value)
	end
end

function Achievements:_buildState(external)
	local combined = {}
	for _, provider in ipairs(self.StateProviders) do
		local ok, result = pcall(provider, combined)
		if ok then
			if type(result) == "table" then
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

local function EvaluateProgress(def, state)
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

local function ShouldUnlock(def, state, progress)
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

local function ClampProgress(def, progress)
	if def.goal and def.goal > 0 then
		return math.min(progress, def.goal)
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
		table.insert(self.unlocked, name)
		self._unlockedLookup[name] = true
	end

	local RunAchievements = SessionStats:get("RunAchievements")
	if type(RunAchievements) ~= "table" then
		RunAchievements = {}
	end
	local AlreadyRecorded = false
	for _, id in ipairs(RunAchievements) do
		if id == name then
			AlreadyRecorded = true
			break
		end
	end
	if not AlreadyRecorded then
		RunAchievements[#RunAchievements + 1] = name
		SessionStats:set("RunAchievements", RunAchievements)
	end

	table.insert(self.PopupQueue, achievement)

	if Audio and Audio.PlaySound then
		Audio:PlaySound("achievement")
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

	local CombinedState = self:_buildState(state)
	local progress = EvaluateProgress(achievement, CombinedState)
	if type(progress) == "number" then
		achievement.progress = ClampProgress(achievement, progress)
	end

	if not achievement.unlocked and ShouldUnlock(achievement, CombinedState, progress) then
		self:unlock(key)
	end
end

function Achievements:CheckAll(state)
	self:_ensureInitialized()

	local CombinedState = self:_buildState(state)

	for key, achievement in pairs(self.definitions) do
		local progress = EvaluateProgress(achievement, CombinedState)
		if type(progress) == "number" then
			achievement.progress = ClampProgress(achievement, progress)
		end

		if not achievement.unlocked and ShouldUnlock(achievement, CombinedState, progress) then
			self:unlock(key)
		end
	end
end

function Achievements:update(dt)
	self:_ensureInitialized()

	if #self.PopupQueue > 0 then
		self.PopupTimer = self.PopupTimer + dt
		local TotalTime = self.PopupDuration + 1.0

		if self.PopupTimer >= TotalTime then
			table.remove(self.PopupQueue, 1)
			self.PopupTimer = 0
		end
	end
end

function Achievements:_getPopupFonts()
	local UI = require("ui")
	return UI.fonts.badge or UI.fonts.button, UI.fonts.caption or UI.fonts.body
end

local function IconPaths(IconName)
	return {
		string.format("Assets/Achievements/%s.png", IconName),
		string.format("Assets/%s.png", IconName),
	}
end

function Achievements:_getIcon(IconName)
	if not IconName then return nil end
	self._iconCache = self._iconCache or {}

	if self._iconCache[IconName] ~= nil then
		return self._iconCache[IconName]
	end

	for _, path in ipairs(IconPaths(IconName)) do
		if love.filesystem.getInfo(path) then
			local ok, image = pcall(love.graphics.newImage, path)
			if ok then
				self._iconCache[IconName] = image
				return image
			end
		end
	end

	self._iconCache[IconName] = false
	return nil
end

function Achievements:draw()
	self:_ensureInitialized()

	if #self.PopupQueue == 0 then
		return
	end

	local ach = self.PopupQueue[1]
	local Screen = require("screen")
	local sw, sh = Screen:get()

	local FontTitle, FontDesc = self:_getPopupFonts()

	local padding = 20
	local width = 500
	local height = 100
	local BaseX = (sw - width) / 2
	local BaseY = sh * 0.25

	local AppearTime = 0.4
	local HoldTime = self.PopupDuration
	local ExitTime = 0.6

	local t = self.PopupTimer
	local alpha, OffsetY, scale = 1, 0, 1

	if t < AppearTime then
		local p = t / AppearTime
		local ease = p * p * (3 - 2 * p)
		OffsetY = (1 - ease) * -150
		scale = 1.0 + 0.2 * (1 - ease)
		alpha = ease
	elseif t < AppearTime + HoldTime then
		OffsetY = 0
		scale = 1.0
		alpha = 1
	else
		local p = (t - AppearTime - HoldTime) / ExitTime
		local ease = p * p
		OffsetY = ease * -150
		alpha = 1 - ease
	end

	local x = BaseX
	local y = BaseY + OffsetY

	love.graphics.push()
	love.graphics.translate(x + width / 2, y + height / 2)
	love.graphics.scale(scale)
	love.graphics.translate(-(x + width / 2), -(y + height / 2))

	love.graphics.setColor(0, 0, 0, 0.75 * alpha)
	love.graphics.rectangle("fill", x, y, width, height, 12, 12)

	local icon = self:_getIcon(ach.popupIcon or ach.icon)
	local IconSize = 64
	local IconSpace = icon and IconSize or 0

	if icon then
		love.graphics.setColor(1, 1, 1, alpha)
		local ScaleX = IconSize / icon:getWidth()
		local ScaleY = IconSize / icon:getHeight()
		love.graphics.draw(icon, x + padding, y + (height - IconSize) / 2, 0, ScaleX, ScaleY)
	end

	local LocalizedTitle = Localization:get(ach.titleKey)
	local LocalizedDescription = Localization:get(ach.descriptionKey)
	local heading = Localization:get("achievements.popup_heading", { title = LocalizedTitle })

	love.graphics.setColor(1, 1, 0.2, alpha)
	love.graphics.setFont(FontTitle)
	love.graphics.printf(heading, x + padding + IconSpace, y + 15, width - (padding * 2) - IconSpace, "left")

	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.setFont(FontDesc)
	local message = Localization:get("achievements.popup_message", {
		title = LocalizedTitle,
		description = LocalizedDescription,
	})
	love.graphics.printf(message, x + padding + IconSpace, y + 50, width - (padding * 2) - IconSpace, "left")

	love.graphics.pop()
end

local function SerializeValue(value)
	if type(value) == "number" then
		if math.type and math.type(value) == "integer" then
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

	local lines = { "return {" }
	for key, value in pairs(data) do
		table.insert(lines, string.format("  [\"%s\"] = { unlocked = %s, progress = %s },",
			key, tostring(value.unlocked), SerializeValue(value.progress or 0)))
	end
	table.insert(lines, "}")

	local LuaData = table.concat(lines, "\n")
	love.filesystem.write("achievementdata.lua", LuaData)
end

local function ApplySavedData(definitions, saved)
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
			ApplySavedData(self.definitions, data)
		end
	end
end

function Achievements:GetDisplayOrder()
	self:_ensureInitialized()

	local blocks = {}
	for _, category in ipairs(self.CategoryOrder) do
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

function Achievements:GetProgressLabel(def)
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
		local progress = math.floor(def.progress or 0)
		local goal = math.floor(def.goal)
		return Localization:get("achievements.progress.label", {
			current = progress,
			goal = goal,
		})
	end

	return nil
end

function Achievements:GetProgressRatio(def)
	if def.unlocked then
		return 1
	end

	if def.goal and def.goal > 0 then
		return math.min(1, (def.progress or 0) / def.goal)
	end

	return 0
end

function Achievements:GetTotals()
	self:_ensureInitialized()

	local total = #self.DefinitionOrder
	local unlocked = 0
	local completion = 0

	if total == 0 then
		return {
			total = 0,
			unlocked = 0,
			completion = 0,
		}
	end

	for _, id in ipairs(self.DefinitionOrder) do
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

function Achievements:GetDefinition(id)
	self:_ensureInitialized()
	return self.definitions[id]
end

return Achievements
