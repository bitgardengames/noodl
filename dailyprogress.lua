local floor = math.floor
local max = math.max

local DailyProgress = {}

local saveFile = "saveddaily.lua"

local function ensureTable(target, key)
        if type(target[key]) ~= "table" then
                target[key] = {}
        end
        return target[key]
end

local function cloneTable(source)
        local copy = {}
        if type(source) ~= "table" then
                return copy
        end

        for k, v in pairs(source) do
                if type(v) == "table" then
                        copy[k] = cloneTable(v)
                else
                        copy[k] = v
                end
        end

        return copy
end

local function serialize(value, indent)
        indent = indent or 0
        local valueType = type(value)

        if valueType == "number" then
                return tostring(value)
        elseif valueType == "boolean" then
                return value and "true" or "false"
        elseif valueType == "string" then
                return string.format("%q", value)
        elseif valueType == "table" then
                local keys = {}
                for key in pairs(value) do
                        keys[#keys + 1] = key
                end
                table.sort(keys, function(a, b)
                        if type(a) == "number" and type(b) == "number" then
                                return a < b
                        end
                        return tostring(a) < tostring(b)
                end)

                local childIndent = indent + 4
                local parts = {"{\n"}
                for i = 1, #keys do
                        local key = keys[i]
                        local formattedKey
                        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
                                formattedKey = key .. " = "
                        else
                                formattedKey = string.format("[%q] = ", key)
                        end

                        parts[#parts + 1] = string.rep(" ", childIndent) .. formattedKey .. serialize(value[key], childIndent) .. ",\n"
                end

                parts[#parts + 1] = string.rep(" ", indent) .. "}"
                return table.concat(parts)
        end

        return "nil"
end

local function defaultData()
        return {
                totals = {
                        completed = 0,
                },
                streak = {
                        current = 0,
                        best = 0,
                        lastCompletionDay = 0,
                },
                days = {},
        }
end

function DailyProgress:_ensureData()
        if type(self.data) ~= "table" then
                self.data = defaultData()
                return
        end

        if type(self.data.totals) ~= "table" then
                self.data.totals = {completed = 0}
        end

        if type(self.data.streak) ~= "table" then
                self.data.streak = {current = 0, best = 0, lastCompletionDay = 0}
        else
                local streak = self.data.streak
                streak.current = streak.current or 0
                streak.best = streak.best or 0
                streak.lastCompletionDay = streak.lastCompletionDay or 0
        end

        self.data.days = ensureTable(self.data, "days")
end

function DailyProgress:load()
        if love.filesystem.getInfo(saveFile) then
                local success, chunk = pcall(love.filesystem.load, saveFile)
                if success and chunk then
                        local ok, saved = pcall(chunk)
                        if ok and type(saved) == "table" then
                                self.data = cloneTable(saved)
                        end
                end
        end

        self:_ensureData()
end

function DailyProgress:save()
        self:_ensureData()
        local content = "return " .. serialize(self.data, 0) .. "\n"
        love.filesystem.write(saveFile, content)
end

function DailyProgress:_getDayEntry(dayValue, create)
        self:_ensureData()

        if type(dayValue) ~= "number" or dayValue <= 0 then
                return nil
        end

        local days = ensureTable(self.data, "days")
        local entry = days[dayValue]
        if not entry and create then
                entry = {}
                days[dayValue] = entry
        end

        return entry
end

function DailyProgress:_getChallengeEntry(dayValue, challengeId, create)
        self:_ensureData()

        if not challengeId or dayValue == nil then
                return nil
        end

        local dayEntry = self:_getDayEntry(dayValue, create)
        if not dayEntry then
                return nil
        end

        local entry = dayEntry[challengeId]
        if not entry and create then
                entry = {progress = 0, complete = false}
                dayEntry[challengeId] = entry
        end

        return entry
end

function DailyProgress:getProgress(challengeId, dayValue)
        self:_ensureData()

        local entry = self:_getChallengeEntry(dayValue, challengeId, false)
        return (entry and entry.progress) or 0
end

function DailyProgress:setProgress(challengeId, dayValue, value, saveAfter)
        self:_ensureData()

        local entry = self:_getChallengeEntry(dayValue, challengeId, true)
        if not entry then
                return
        end

        entry.progress = max(0, floor(value or 0))

        if saveAfter ~= false then
                self:save()
        end
end

function DailyProgress:isComplete(challengeId, dayValue)
        self:_ensureData()

        local entry = self:_getChallengeEntry(dayValue, challengeId, false)
        return entry and entry.complete or false
end

function DailyProgress:setComplete(challengeId, dayValue, complete, saveAfter)
        self:_ensureData()

        local entry = self:_getChallengeEntry(dayValue, challengeId, true)
        if not entry then
                return
        end

        entry.complete = complete and true or false

        if saveAfter ~= false then
                self:save()
        end
end

function DailyProgress:getStreak()
        self:_ensureData()
        return self.data.streak
end

function DailyProgress:getTotals()
        self:_ensureData()
        return self.data.totals
end

function DailyProgress:recordCompletion(dayValue, saveAfter)
        self:_ensureData()

        local streak = self.data.streak
        local totals = self.data.totals

        local previousStreak = streak.current or 0
        local previousBest = streak.best or 0
        local lastCompletionDay = streak.lastCompletionDay or 0

        local newStreak
        local continued = false

        if dayValue then
                        if lastCompletionDay > 0 then
                                        if lastCompletionDay == dayValue then
                                                        newStreak = max(previousStreak, 1)
                                        elseif lastCompletionDay == dayValue - 1 then
                                                        newStreak = max(previousStreak, 0) + 1
                                                        continued = true
                                        else
                                                        newStreak = 1
                                        end
                        else
                                        newStreak = 1
                        end

                        streak.lastCompletionDay = dayValue
        else
                        newStreak = max(previousStreak, 1)
        end

        if newStreak <= 0 then
                        newStreak = 1
        end

        streak.current = newStreak
        streak.best = max(previousBest, newStreak)

        if type(totals.completed) ~= "number" then
                        totals.completed = 0
        end
        totals.completed = totals.completed + 1

        if saveAfter ~= false then
                        self:save()
        end

        return {
                        current = newStreak,
                        best = streak.best,
                        wasNewBest = newStreak > previousBest,
                        continued = continued,
                        dayValue = dayValue,
        }
end

local function parseLegacyDailyKey(key, value)
        if type(key) ~= "string" then
                        return nil
        end

        local challengeId, dayValueStr, field = key:match("^dailyChallenge:([^:]+):(%d+):([%w_]+)$")
        if not challengeId or not dayValueStr or not field then
                        return nil
        end

        local dayValue = tonumber(dayValueStr)
        if not dayValue then
                        return nil
        end

        if field ~= "progress" and field ~= "complete" then
                        return nil
        end

        return {
                        challengeId = challengeId,
                        dayValue = dayValue,
                        field = field,
                        value = value,
        }
end

function DailyProgress:importLegacyData(legacyStats)
        if type(legacyStats) ~= "table" then
                        return
        end

        if not self.data then
                        self:load()
        else
                        self:_ensureData()
        end

        local modified = false

        for key, value in pairs(legacyStats) do
                        local parsed = parseLegacyDailyKey(key, value)
                        if parsed then
                                        local entry = self:_getChallengeEntry(parsed.dayValue, parsed.challengeId, true)
                                        if parsed.field == "progress" then
                                                        entry.progress = max(0, floor(parsed.value or 0))
                                        elseif parsed.field == "complete" then
                                                        entry.complete = (parsed.value or 0) >= 1
                                        end
                                        modified = true
                        end
        end

        if legacyStats.dailyChallengeStreak or legacyStats.dailyChallengeBestStreak or legacyStats.dailyChallengeLastCompletionDay then
                        local streak = self:getStreak()
                        streak.current = max(streak.current or 0, legacyStats.dailyChallengeStreak or 0)
                        streak.best = max(streak.best or 0, legacyStats.dailyChallengeBestStreak or 0)
                        streak.lastCompletionDay = max(streak.lastCompletionDay or 0, legacyStats.dailyChallengeLastCompletionDay or 0)
                        modified = true
        end

        if legacyStats.dailyChallengesCompleted then
                        local totals = self:getTotals()
                        totals.completed = max(totals.completed or 0, legacyStats.dailyChallengesCompleted or 0)
                        modified = true
        end

        if modified then
                        self:save()
        end
end

return DailyProgress
