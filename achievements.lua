local Audio = require("audio")
local Localization = require("localization")

local Achievements = {}

Achievements.definitions = {
    firstApple = {
        titleKey = "achievements_definitions.firstApple.title",
        descriptionKey = "achievements_definitions.firstApple.description",
        icon = "Apple",
        unlocked = false,
        progress = 0,
        goal = 1,
        condition = function(state)
            return state.totalApplesEaten >= 1
        end,
        updateProgress = function(state)
            return math.min(state.totalApplesEaten, 1)
        end
    },
    appleHoarder = {
        titleKey = "achievements_definitions.appleHoarder.title",
        descriptionKey = "achievements_definitions.appleHoarder.description",
        icon = "Apple",
        unlocked = false,
        progress = 0,
        goal = 100,
        condition = function(state)
            return (state.totalApplesEaten or 0) >= 100
        end,
        updateProgress = function(state)
            return math.min(state.totalApplesEaten or 0, 100)
        end
    },
    fullBelly = {
        titleKey = "achievements_definitions.fullBelly.title",
        descriptionKey = "achievements_definitions.fullBelly.description",
        icon = "Apple",
        unlocked = false,
        progress = 0,
        goal = 50,
        condition = function(state)
            return (state.snakeLength or 0) >= 50
        end,
        updateProgress = function(state)
            return math.min(state.snakeLength or 0, 50)
        end
    },
        dragonHunter = {
                titleKey = "achievements_definitions.dragonHunter.title",
                descriptionKey = "achievements_definitions.dragonHunter.description",
                icon = "Dragonfruit",
                unlocked = false,
                progress = 0,
                goal = 1,
		condition = function(state)
			return (state.totalDragonfruitEaten or 0) >= 1
		end,
		updateProgress = function(state)
			return math.min(state.totalDragonfruitEaten or 0, 1)
		end
	},
}

Achievements.unlocked = {}
Achievements.popupQueue = {}
Achievements.popupTimer = 0
Achievements.popupDuration = 3

function Achievements:unlock(name)
    local achievement = self.definitions[name]
    if not achievement then
        print("Unknown achievement:", name)
        return
    end

    -- Already unlocked? Do nothing
    if achievement.unlocked then
        return
    end

    -- Unlock it!
    achievement.unlocked = true
    if achievement.goal then
        achievement.progress = achievement.goal
    end
    achievement.unlockedAt = os.time()
    table.insert(self.unlocked, name)
    table.insert(self.popupQueue, achievement)

    -- Trigger any visuals/sfx
    Audio:playSound("achievement")

    -- Save achievements
    self:save()
end

-- Check/update only a specific achievement
function Achievements:check(key, state)
    local ach = self.definitions[key]
    if ach then
        if ach.updateProgress then
            ach.progress = ach.updateProgress(state)
        end

        if not ach.unlocked and ach.condition(state) then
            self:unlock(key)
        end
    end
end

-- Updates all achievement progress and unlocks
function Achievements:checkAll(state)
    for key, ach in pairs(self.definitions) do
        if ach.updateProgress then
            ach.progress = ach.updateProgress(state)
        end

        if not ach.unlocked and ach.condition(state) then
            self:unlock(key)
        end
    end
end

-- Update popup logic with nicer timing
function Achievements:update(dt)
    if #self.popupQueue > 0 then
        self.popupTimer = self.popupTimer + dt
        local totalTime = self.popupDuration + 1.0 -- extra second for slide-out

        if self.popupTimer >= totalTime then
            table.remove(self.popupQueue, 1)
            self.popupTimer = 0
        end
    end
end

-- Draw juiced popup
function Achievements:draw()
    if #self.popupQueue == 0 then return end

    local ach = self.popupQueue[1]
    local Screen = require("screen")
    local sw, sh = Screen:get()

    local fontTitle = love.graphics.newFont(18)
    local fontDesc = love.graphics.newFont(14)

    local padding = 20
    local width = 500
    local height = 100
    local baseX = (sw - width) / 2
    local baseY = sh * 0.25

    -- Animation timings
    local appearTime = 0.4  -- slide/bounce in
    local holdTime   = self.popupDuration
    local exitTime   = 0.6

    local t = self.popupTimer
    local alpha, offsetY, scale = 1, 0, 1

    if t < appearTime then
        -- Sliding in
        local p = t / appearTime
        local ease = p * p * (3 - 2 * p) -- smoothstep
        offsetY = (1 - ease) * -150
        scale = 1.0 + 0.2 * (1 - ease) -- bounce scale
        alpha = ease
    elseif t < appearTime + holdTime then
        -- Holding
        offsetY = 0
        scale = 1.0
        alpha = 1
    else
        -- Sliding out
        local p = (t - appearTime - holdTime) / exitTime
        local ease = p * p
        offsetY = ease * -150
        alpha = 1 - ease
    end

    local x = baseX
    local y = baseY + offsetY

    love.graphics.push()
    love.graphics.translate(x + width/2, y + height/2)
    love.graphics.scale(scale)
    love.graphics.translate(-(x + width/2), -(y + height/2))

    -- Background
    love.graphics.setColor(0, 0, 0, 0.75 * alpha)
    love.graphics.rectangle("fill", x, y, width, height, 12, 12)

    -- Optional icon
    local iconSize = 64
    if ach.icon then
        local ok, iconImg = pcall(love.graphics.newImage, "Assets/Icons/" .. ach.icon .. ".png")
        if ok and iconImg then
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(iconImg, x + padding, y + (height - iconSize)/2, 0, iconSize / iconImg:getWidth(), iconSize / iconImg:getHeight())
        end
    end

    -- Title text
    local localizedTitle = Localization:get(ach.titleKey)
    local localizedDescription = Localization:get(ach.descriptionKey)
    local heading = Localization:get("achievements.popup_heading", { title = localizedTitle })

    love.graphics.setColor(1, 1, 0.2, alpha)
    love.graphics.setFont(fontTitle)
    love.graphics.printf(heading, x + padding + iconSize, y + 15, width - (padding * 2) - iconSize, "left")

    -- Description text
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(fontDesc)
    local message = Localization:get("achievements.popup_message", {
        title = localizedTitle,
        description = localizedDescription,
    })
    love.graphics.printf(message, x + padding + iconSize, y + 50, width - (padding * 2) - iconSize, "left")

    love.graphics.pop()
end

-- Save to file (custom serialization)
function Achievements:save()
    local data = {}
    for key, ach in pairs(self.definitions) do
        data[key] = {
            unlocked = ach.unlocked,
            progress = ach.progress
        }
    end

    local lines = {"return {"}
    for key, value in pairs(data) do
        table.insert(lines, string.format("  [\"%s\"] = { unlocked = %s, progress = %d },",
            key, tostring(value.unlocked), value.progress or 0))
    end
    table.insert(lines, "}")

    local luaData = table.concat(lines, "\n")
    love.filesystem.write("achievementdata.lua", luaData)
end

-- Load from file
function Achievements:load()
    if love.filesystem.getInfo("achievementdata.lua") then
        local chunk = love.filesystem.load("achievementdata.lua")
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            for key, saved in pairs(data) do
                if self.definitions[key] then
                    self.definitions[key].unlocked = saved.unlocked or false
                    self.definitions[key].progress = saved.progress or 0
                end
            end
        end
    end
end

return Achievements
