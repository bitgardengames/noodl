local Screen = {}

function Screen:update()
    self.width, self.height = love.graphics.getDimensions()
    self.cx = self.width / 2
    self.cy = self.height / 2
end

function Screen:get()
    return self.width, self.height
end

function Screen:getWidth()
    return self.width
end

function Screen:getHeight()
    return self.height
end

function Screen:center()
    return self.cx, self.cy
end

return Screen