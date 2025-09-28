local Screen = require("screen")
local GameState = require("gamestate")
local Settings = require("settings")
local Audio = require("audio")
local Score = require("score")
local PlayerStats = require("playerstats")
local GameModes = require("gamemodes")
local UI = require("ui")
local Localization = require("localization")

local Debug = {
    enabled = false,
    frameHistory = {},
    memoryHistory = {},
    maxSamples = 240,
    sampleTimer = 0,
    sampleInterval = 0,
    refreshTimer = 0,
    refreshInterval = 0.25,
    cachedSections = {},
    panelWidth = 360,
    panelPadding = 12,
    sectionSpacing = 8,
    graphHeight = 64,
    memoryGraphHeight = 48,
}

local function countTableEntries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

local function addSample(history, maxSamples, value)
    history[#history + 1] = value
    if #history > maxSamples then
        table.remove(history, 1)
    end
end

local function getHistoryBounds(history)
    local minValue = math.huge
    local maxValue = -math.huge

    for i = 1, #history do
        local value = history[i]
        if value < minValue then
            minValue = value
        end
        if value > maxValue then
            maxValue = value
        end
    end

    if minValue == math.huge then
        minValue = 0
    end
    if maxValue == -math.huge then
        maxValue = 1
    end

    if minValue == maxValue then
        maxValue = maxValue + 1
    end

    return minValue, maxValue
end

local function formatBool(value)
    if value then
        return "yes"
    end
    return "no"
end

function Debug:load()
    self.font = love.graphics.newFont(12)
    self.sampleTimer = 0
    self.sampleInterval = 0
    self.refreshTimer = 0
    self.cachedSections = {}
end

function Debug:toggle()
    self.enabled = not self.enabled
    if self.enabled then
        self:collectData()
    end
end

function Debug:keypressed(key)
    if key == "f3" then
        self:toggle()
    elseif key == "f4" then
        self.frameHistory = {}
        self.memoryHistory = {}
    end
end

function Debug:collectData()
    local sections = {}

    local fps = love.timer.getFPS()
    local frameMs = self.frameHistory[#self.frameHistory] or 0
    local uptime = love.timer.getTime()
    local drawStats = love.graphics.getStats()
    local gpuMemory = drawStats and drawStats.texturememory or 0

    sections[#sections + 1] = {
        title = "Frame",
        lines = {
            string.format("FPS: %d", fps),
            string.format("Frame time: %.2f ms", frameMs),
            string.format("Uptime: %.1f s", uptime),
        }
    }

    if drawStats then
        sections[#sections].lines[#sections[#sections].lines + 1] = string.format("Draw calls: %d", drawStats.drawcalls)
        sections[#sections].lines[#sections[#sections].lines + 1] = string.format("Textures: %d", drawStats.textures)
        sections[#sections].lines[#sections[#sections].lines + 1] = string.format("GPU memory: %.1f MB", gpuMemory / 1024)
    end

    local screenWidth, screenHeight = Screen:get()
    local targetWidth, targetHeight = Screen:getTarget()

    sections[#sections + 1] = {
        title = "Screen",
        lines = {
            string.format("Current: %s", screenWidth and string.format("%.0f x %.0f", screenWidth, screenHeight) or "n/a"),
            string.format("Target: %s", targetWidth and string.format("%.0f x %.0f", targetWidth, targetHeight) or "n/a"),
            string.format("Smoothing: %.2f", Screen.smoothingSpeed or 0),
            string.format("Snap threshold: %.1f", Screen.snapThreshold or 0),
        }
    }

    local currentState = GameState.current or "(none)"
    local queuedState = GameState.queuedState or "(none)"
    local nextState = GameState.next or "(none)"
    local transitionContext = GameState:getTransitionContext()

    local transitionLines = {
        string.format("Current: %s", tostring(currentState)),
        string.format("Next: %s", tostring(nextState)),
        string.format("Queued: %s", tostring(queuedState)),
        string.format("Transitioning: %s", formatBool(GameState:isTransitioning())),
    }

    if transitionContext then
        transitionLines[#transitionLines + 1] = string.format("Direction: %s", transitionContext.directionName or transitionContext.direction or "none")
        transitionLines[#transitionLines + 1] = string.format("Progress: %.2f", transitionContext.progress or 0)
        transitionLines[#transitionLines + 1] = string.format("Alpha: %.2f", transitionContext.alpha or 0)
        transitionLines[#transitionLines + 1] = string.format("Duration: %.2f s", transitionContext.duration or 0)
    end

    local stateNames = {}
    for name in pairs(GameState.states) do
        stateNames[#stateNames + 1] = name
    end
    table.sort(stateNames)
    if #stateNames > 0 then
        transitionLines[#transitionLines + 1] = "States: " .. table.concat(stateNames, ", ")
    else
        transitionLines[#transitionLines + 1] = "States: (none)"
    end

    sections[#sections + 1] = {
        title = "State",
        lines = transitionLines,
    }

    local currentMusicName
    for name, source in pairs(Audio.musicTracks or {}) do
        if source == Audio.currentMusic then
            currentMusicName = name
            break
        end
    end

    sections[#sections + 1] = {
        title = "Audio",
        lines = {
            string.format("Music muted: %s", formatBool(Settings.muteMusic)),
            string.format("SFX muted: %s", formatBool(Settings.muteSFX)),
            string.format("Music volume: %.2f", Settings.musicVolume or 0),
            string.format("SFX volume: %.2f", Settings.sfxVolume or 0),
            string.format("Music tracks: %d", countTableEntries(Audio.musicTracks)),
            string.format("Sounds: %d", countTableEntries(Audio.sounds)),
            string.format("Current music: %s", currentMusicName or "(none)"),
        }
    }

    sections[#sections + 1] = {
        title = "Progression",
        lines = {
            string.format("Language: %s", Localization:getCurrentLanguage() or Settings.language or "unknown"),
            string.format("Game mode: %s", GameModes:getCurrentName() or "(none)"),
            string.format("Score: %d", Score:get() or 0),
            string.format("High score: %d", Score:getHigh() or 0),
            string.format("Player stats: %d entries", countTableEntries(PlayerStats.data)),
            string.format("UI buttons: %d", countTableEntries(UI.buttons)),
        }
    }

    self.cachedSections = sections
end

function Debug:update(dt)
    local frameMs = dt * 1000
    addSample(self.frameHistory, self.maxSamples, frameMs)

    local memoryMB = collectgarbage("count") / 1024
    addSample(self.memoryHistory, self.maxSamples, memoryMB)

    self.refreshTimer = self.refreshTimer + dt
    if self.refreshTimer >= self.refreshInterval then
        self.refreshTimer = self.refreshTimer - self.refreshInterval
        self:collectData()
    end
end

local function drawHistoryGraph(history, x, y, width, height, color)
    if #history < 2 then
        return
    end

    local minValue, maxValue = getHistoryBounds(history)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("line", x, y, width, height)

    love.graphics.setScissor(x, y, width, height)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)

    local prevX, prevY
    local count = #history
    local step = width / (count - 1)
    for i = 1, count do
        local value = history[i]
        local normalized = (value - minValue) / (maxValue - minValue)
        local px = x + (i - 1) * step
        local py = y + height - normalized * height
        if prevX then
            love.graphics.line(prevX, prevY, px, py)
        end
        prevX, prevY = px, py
    end

    love.graphics.setScissor()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("min %.2f", minValue), x + 4, y + height - 14)
    love.graphics.printf(string.format("max %.2f", maxValue), x, y + 2, width - 4, "right")
end

function Debug:draw()
    if not self.enabled then
        return
    end

    if not self.font then
        self:load()
    end

    love.graphics.push("all")
    love.graphics.setFont(self.font)

    local padding = self.panelPadding
    local x = 16
    local y = 16
    local width = self.panelWidth
    local lineHeight = self.font:getHeight() + 2
    local graphSpacing = 10

    local totalHeight = padding * 2 + self.graphHeight + self.memoryGraphHeight + graphSpacing

    for index, section in ipairs(self.cachedSections) do
        totalHeight = totalHeight + lineHeight
        totalHeight = totalHeight + (#section.lines * lineHeight)
        if index < #self.cachedSections then
            totalHeight = totalHeight + self.sectionSpacing
        end
    end

    local instructionsHeight = lineHeight + self.sectionSpacing
    totalHeight = totalHeight + instructionsHeight

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - padding, y - padding, width + padding * 2, totalHeight)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", x - padding, y - padding, width + padding * 2, totalHeight)

    local graphX = x
    local frameGraphY = y
    love.graphics.setColor(1, 1, 1, 1)
    drawHistoryGraph(self.frameHistory, graphX, frameGraphY, width, self.graphHeight, {0.2, 0.9, 0.3, 1})
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Frame time (ms)", graphX + 6, frameGraphY + 6)

    local memoryGraphY = frameGraphY + self.graphHeight + graphSpacing
    love.graphics.setColor(1, 1, 1, 1)
    drawHistoryGraph(self.memoryHistory, graphX, memoryGraphY, width, self.memoryGraphHeight, {0.4, 0.7, 1.0, 1})
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Memory (MB)", graphX + 6, memoryGraphY + 6)

    local cursorY = memoryGraphY + self.memoryGraphHeight + graphSpacing

    for index, section in ipairs(self.cachedSections) do
        love.graphics.setColor(1, 0.8, 0.3, 1)
        love.graphics.print(section.title, x, cursorY)
        cursorY = cursorY + lineHeight

        love.graphics.setColor(1, 1, 1, 1)
        for _, line in ipairs(section.lines) do
            love.graphics.print(line, x + 12, cursorY)
            cursorY = cursorY + lineHeight
        end

        if index < #self.cachedSections then
            cursorY = cursorY + self.sectionSpacing
        end
    end

    cursorY = cursorY + self.sectionSpacing
    love.graphics.setColor(0.9, 0.9, 0.9, 0.6)
    love.graphics.print("F3: toggle debug  |  F4: reset graphs", x, cursorY)

    love.graphics.pop()
end

return Debug
