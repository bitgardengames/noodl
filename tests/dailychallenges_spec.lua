local function stubDependencies()
        package.loaded["playerstats"] = package.loaded["playerstats"] or {
                get = function()
                        return 0
                end,
        }

        package.loaded["sessionstats"] = package.loaded["sessionstats"] or {}
end

local function legacySecondsUntilNextMidnight(date)
        if not date or not date.year or not date.month or not date.day then
                return nil
        end

        local function cloneTimeTable(source, overrides)
                if not source then
                        return nil
                end

                local result = {
                        year = source.year,
                        month = source.month,
                        day = source.day,
                        hour = source.hour,
                        min = source.min,
                        sec = source.sec,
                        isdst = source.isdst,
                }

                if overrides then
                        for key, value in pairs(overrides) do
                                result[key] = value
                        end
                end

                return result
        end

        local base = cloneTimeTable(date)
        if not base or base.hour == nil or base.min == nil or base.sec == nil then
                return nil
        end

        local nowTimestamp = os.time(base)
        if not nowTimestamp then
                return nil
        end

        local midnightTimestamp = os.time(cloneTimeTable(date, {hour = 0, min = 0, sec = 0}))
        if not midnightTimestamp then
                return nil
        end

        if nowTimestamp >= midnightTimestamp then
                midnightTimestamp = midnightTimestamp + 24 * 60 * 60
        end

        local remaining = midnightTimestamp - nowTimestamp
        if remaining < 0 then
                remaining = 0
        end

        return remaining
end

describe("DailyChallenges:getTimeUntilReset", function()
        local DailyChallenges

        local function arithmeticSecondsUntilNextMidnight(date)
                return DailyChallenges:getTimeUntilReset(date)
        end

        before_each(function()
                package.loaded["dailychallenges"] = nil
                stubDependencies()
                DailyChallenges = require("dailychallenges")
        end)

        it("matches the legacy calculation at the start of a day", function()
                local date = {year = 2024, month = 1, day = 1, hour = 0, min = 0, sec = 0}
                assert.are.equal(legacySecondsUntilNextMidnight(date), arithmeticSecondsUntilNextMidnight(date))
        end)

        it("matches the legacy calculation in the middle of a day", function()
                local date = {year = 2024, month = 6, day = 15, hour = 12, min = 34, sec = 56}
                assert.are.equal(legacySecondsUntilNextMidnight(date), arithmeticSecondsUntilNextMidnight(date))
        end)

        it("matches the legacy calculation right before midnight", function()
                local date = {year = 2024, month = 12, day = 31, hour = 23, min = 59, sec = 59}
                assert.are.equal(legacySecondsUntilNextMidnight(date), arithmeticSecondsUntilNextMidnight(date))
        end)

        it("returns nil when required fields are missing", function()
                local date = {year = 2024, month = 1, day = 1}
                assert.is_nil(arithmeticSecondsUntilNextMidnight(date))
        end)

        it("requires calendar fields even when time is present", function()
                local date = {hour = 12, min = 0, sec = 0}
                assert.is_nil(arithmeticSecondsUntilNextMidnight(date))
        end)

        it("identifies the expected delta during DST transitions when applicable", function()
                local foundTransition = false

                for year = 2020, 2030 do
                        local baseTimestamp = os.time({year = year, month = 1, day = 1, hour = 0, min = 0, sec = 0})
                        if baseTimestamp then
                                for dayOffset = 0, 366 do
                                        local timestamp = baseTimestamp + dayOffset * 24 * 60 * 60
                                        local date = os.date("*t", timestamp)
                                        if not date then
                                                break
                                        end

                                        date.hour = 0
                                        date.min = 0
                                        date.sec = 0

                                        local legacy = legacySecondsUntilNextMidnight(date)
                                        local arithmetic = arithmeticSecondsUntilNextMidnight(date)

                                        if legacy and arithmetic and legacy ~= arithmetic then
                                                foundTransition = true
                                                assert.is_true(math.abs(legacy - arithmetic) == 3600)
                                                break
                                        end
                                end
                        end

                        if foundTransition then
                                break
                        end
                end

                if not foundTransition then
                        pending("No DST transition detected in the current locale")
                end
        end)
end)
