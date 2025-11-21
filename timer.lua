local fallbackTimer = {}

function fallbackTimer:getTime()
        return 0
end

function fallbackTimer:getFPS()
        return 0
end

function fallbackTimer:sleep()
end

local Timer = {}
Timer.__index = Timer

local EMPTY_OPTIONS = {}

local function sanitizeDuration(duration)
        if duration == nil then
                return 0
        end
        if duration < 0 then
                return 0
        end
        return duration
end

function Timer.new(duration, options)
        options = options or EMPTY_OPTIONS

        local instance = {
                duration = sanitizeDuration(duration or 0),
                elapsed = 0,
                loop = options.loop or false,
                paused = options.paused or false,
                active = options.autoStart or false,
        }

        if instance.active and instance.paused then
                instance.paused = false
        end

        return setmetatable(instance, Timer)
end

function Timer:setDuration(duration)
        self.duration = sanitizeDuration(duration or 0)
        if self.elapsed > self.duration then
                self.elapsed = self.duration
        end
        return self
end

function Timer:start(duration)
        if duration ~= nil then
                self:setDuration(duration)
        end

        self.elapsed = 0
        self.active = true
        self.paused = false

        if self.duration <= 0 then
                self.active = false
        end
        return self
end

function Timer:getElapsed()
        return self.elapsed
end

function Timer:getDuration()
        return self.duration
end

function Timer:isFinished()
        if self.duration <= 0 then
                return not self.active
        end

        return (not self.active) and (self.elapsed >= self.duration)
end

function Timer:update(dt)
        if not self.active or self.paused or dt == nil or dt <= 0 then
                return false
        end

        self.elapsed = self.elapsed + dt

        if self.duration > 0 and self.elapsed >= self.duration then
                if self.loop then
                        self.elapsed = self.elapsed % self.duration
                        return true
                end

                self.elapsed = self.duration
                self.active = false
                return true
        end

        return false
end

function Timer.setFallback(timer)
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

function Timer.getTime()
        local timer = resolveTimer()
        return timer:getTime()
end

function Timer.getFPS()
        local timer = resolveTimer()
        return timer:getFPS()
end

function Timer.sleep(duration)
        local timer = resolveTimer()
        return timer:sleep(duration)
end

return Timer
