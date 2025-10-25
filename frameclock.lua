local FrameClock = {
        value = nil,
}

function FrameClock:capture(time)
        if time ~= nil then
                self.value = time
                return time
        end

        if love and love.timer and love.timer.getTime then
                local now = love.timer.getTime()
                self.value = now
                return now
        end

        self.value = self.value or 0
        return self.value
end

function FrameClock:get()
        if self.value == nil then
                return self:capture()
        end

        return self.value
end

return FrameClock
