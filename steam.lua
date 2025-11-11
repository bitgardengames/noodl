local ok, Steam = pcall(require, "luasteam") -- Thank you luasteam; https://github.com/uspgamedev/luasteam
local steam = {}

steam.initialized = false

function steam.init()
	if not ok or not Steam then
		print("[Steam] luasteam not found, running in offline mode.")
		return false
	end

	if Steam.init() then
		steam.initialized = true
		print("[Steam] Initialized successfully.")
		Steam.userStats.requestCurrentStats()
		return true
	else
		print("[Steam] Failed to initialize Steam.")
		return false
	end
end

function steam.update()
	if steam.initialized then
		Steam.runCallbacks()
	end
end

function steam.shutdown()
	if steam.initialized then
		Steam.shutdown()
	end
end

-- Stats
function steam.addStat(id, value)
	if steam.initialized then
		local current = Steam.userStats.getStatInt(id)
		Steam.userStats.setStatInt(id, current + value)
	end
end

function steam.storeStats()
	if steam.initialized then
		Steam.userStats.storeStats()
	end
end

-- Achievements
function steam.progressAchievement(id, current, goal)
	if steam.initialized then
		Steam.userStats.indicateAchievementProgress(id, current, goal)
	end
end

function steam.unlock(id)
	if steam.initialized then
		Steam.userStats.setAchievement(id)
		Steam.userStats.storeStats()
		print("[Steam] Achievement unlocked:", id)
	end
end

function steam.resetAchievement(id)
	if steam.initialized then
		Steam.userStats.clearAchievement(id)
		Steam.userStats.storeStats()
		print("[Steam] Achievement reset:", id)
	end
end

function steam.isUnlocked(id)
	if steam.initialized then
		return Steam.userStats.getAchievement(id)
	end
	return false
end

return steam