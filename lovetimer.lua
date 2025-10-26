local fallbackTimer = {}

function fallbackTimer:getTime()
        return 0
end

function fallbackTimer:getFPS()
        return 0
end

function fallbackTimer:sleep()
end

local LoveTimer = {}

function LoveTimer.setFallback(timer)
        if type(timer) == "table" then
                if type(timer.getTime) == "function" then
                        fallbackTimer.getTime = function(_, ...)
                                return timer.getTime(timer, ...)
                        end
                end
                if type(timer.getFPS) == "function" then
                        fallbackTimer.getFPS = function(_, ...)
                                return timer.getFPS(timer, ...)
                        end
                end
                if type(timer.sleep) == "function" then
                        fallbackTimer.sleep = function(_, ...)
                                return timer.sleep(timer, ...)
                        end
                end
        end
end

local function resolveTimer()
        if love and love.timer then
                return love.timer
        end
        return fallbackTimer
end

function LoveTimer.getTime()
        local timer = resolveTimer()
        return timer:getTime()
end

function LoveTimer.getFPS()
        local timer = resolveTimer()
        return timer:getFPS()
end

function LoveTimer.sleep(duration)
        local timer = resolveTimer()
        return timer:sleep(duration)
end

return LoveTimer
