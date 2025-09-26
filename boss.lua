local Arena = require("arena")
local Theme = require("theme")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local Audio = require("audio")
local UI = require("ui")

local Boss = {}

local TWO_PI = math.pi * 2
local BOSS_FLOOR_INTERVAL = 3
local INTRO_DURATION = 1.35
local STAGGER_DURATION = 0.9
local EXIT_DELAY = 0.8
local CLEANUP_DURATION = 1.2
local HIT_COOLDOWN = 0.8
local BASE_RING_THICKNESS = 36

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function approach(current, target, rate, dt)
    if current == target then return current end
    local diff = target - current
    local step = rate * dt
    if math.abs(diff) <= step then
        return target
    end
    return current + step * (diff > 0 and 1 or -1)
end

local function angleDiff(a, b)
    local diff = (a - b) % TWO_PI
    if diff > math.pi then
        diff = diff - TWO_PI
    end
    return diff
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local current = nil

local function spawnPulse(encounter, startRadius, width, speed, life)
    encounter.pulses = encounter.pulses or {}
    table.insert(encounter.pulses, {
        radius = startRadius,
        width = width or 18,
        speed = speed or 160,
        life = life or 1.2,
        maxLife = life or 1.2,
    })
end

local function announce(text, color, duration, rise)
    local ax, ay, aw = Arena:getBounds()
    FloatingText:add(text, ax + aw / 2, ay + 32, color, duration or 1.4, rise or 18, UI.fonts.button)
end

local function buildEncounter(floor)
    local encounter = {
        floor = floor or 1,
        requiresEncounter = (floor or 1) % BOSS_FLOOR_INTERVAL == 0,
        state = "dormant",
        defeated = false,
        exitSpawned = false,
        timer = 0,
        breathTimer = 0,
        gapAngle = love.math.random() * TWO_PI,
        gapWidth = math.rad(80),
        baseGap = math.rad(80),
        maxGap = math.rad(130),
        minGap = math.rad(60),
        rotationSpeed = math.rad(40) + math.rad((floor or 1) * 2),
        hitCooldown = 0,
        pulses = {},
        pulseTimer = 0,
        pulseInterval = clamp(3.6 - 0.15 * (floor or 1), 2.1, 3.6),
        coreInside = false,
        instructionsShown = false,
        fade = 0,
        goalAnnounced = false,
    }

    return encounter
end

function Boss:prepareFloor(floor)
    current = buildEncounter(floor)
end

function Boss:requiresEncounter()
    return current and current.requiresEncounter
end

function Boss:hasEncounterStarted()
    if not current then return false end
    return current.state ~= "dormant" and not current.defeated
end

function Boss:isActive()
    if not current then return false end
    return current.state == "intro" or current.state == "active" or current.state == "stagger"
end

function Boss:isDefeated()
    return current and current.defeated
end

function Boss:shouldHoldFruit()
    return current and current.requiresEncounter and current.state ~= "dormant" and not current.defeated
end

local function setupArenaAnchors(encounter)
    local ax, ay, aw, ah = Arena:getBounds()
    encounter.centerX = ax + aw / 2
    encounter.centerY = ay + ah / 2

    local dimension = math.min(aw, ah)
    encounter.baseRadius = dimension * 0.32
    encounter.ringThickness = BASE_RING_THICKNESS
    encounter.displayRadius = encounter.baseRadius
    encounter.innerRadius = encounter.displayRadius - encounter.ringThickness
    encounter.coreRadius = math.max(32, encounter.innerRadius - 22)
end

local function introEncounter(encounter)
    encounter.state = "intro"
    encounter.timer = 0
    encounter.introProgress = 0
    encounter.defeated = false
    encounter.hitCooldown = 0
    encounter.coreInside = false
    encounter.pulses = {}
    encounter.gapWidth = encounter.baseGap
    encounter.targetGap = encounter.baseGap
    encounter.goalAnnounced = true
    announce("Boss Floor!", {1, 0.88, 0.35, 1}, 1.5, 16)
    announce("Slip through the gap and hit the core!", {1, 1, 1, 0.85}, 2.4, 14)
    Audio:playSound("shield_gain")
end

local function getBossColor()
    local color = Theme.snake or {0.9, 0.9, 0.9, 1}
    return color[1], color[2], color[3], color[4] or 1
end

function Boss:startEncounter(options)
    if not current or current.defeated or not current.requiresEncounter then
        return
    end

    if current.state ~= "dormant" then
        return
    end

    if options and options.floor then
        current.floor = options.floor
    end

    setupArenaAnchors(current)
    current.maxHealth = 3 + math.floor((current.floor or 1) / BOSS_FLOOR_INTERVAL)
    current.health = current.maxHealth
    current.rotationSpeed = math.rad(36) + math.rad((current.floor or 1) * 2.5)
    current.pulseInterval = clamp(3.4 - 0.18 * (current.floor or 1), 1.9, 3.4)
    current.hitCooldown = 0
    current.exitSpawned = false
    current.fade = 0
    current.defeatTimer = 0
    current.instructionsShown = false
    current.pulses = {}
    current.gapGlow = 0
    current.targetGap = current.baseGap

    introEncounter(current)
end

local function updateIntro(encounter, dt)
    encounter.timer = encounter.timer + dt
    local progress = clamp(encounter.timer / INTRO_DURATION, 0, 1)
    encounter.introProgress = progress
    encounter.displayRadius = encounter.baseRadius * easeOutBack(progress)
    encounter.innerRadius = encounter.displayRadius - encounter.ringThickness
    encounter.coreRadius = math.max(32, encounter.innerRadius - 22)

    if progress >= 1 then
        encounter.state = "active"
        encounter.timer = 0
    end
end

local function updatePulses(encounter, dt)
    if not encounter.pulses then return end

    for index = #encounter.pulses, 1, -1 do
        local pulse = encounter.pulses[index]
        pulse.radius = pulse.radius + (pulse.speed or 0) * dt
        pulse.life = (pulse.life or 0) - dt
        if pulse.life <= 0 then
            table.remove(encounter.pulses, index)
        end
    end
end

local function updateActive(encounter, dt)
    encounter.timer = encounter.timer + dt
    encounter.breathTimer = encounter.breathTimer + dt
    encounter.gapAngle = (encounter.gapAngle + encounter.rotationSpeed * dt) % TWO_PI
    encounter.targetGap = encounter.baseGap

    if encounter.hitCooldown > 0 then
        encounter.hitCooldown = math.max(0, encounter.hitCooldown - dt)
    end

    encounter.displayRadius = encounter.baseRadius + math.sin(encounter.breathTimer * 2.2) * 10
    encounter.innerRadius = encounter.displayRadius - encounter.ringThickness
    encounter.coreRadius = math.max(30, encounter.innerRadius - 22)

    encounter.gapWidth = approach(encounter.gapWidth, encounter.targetGap, 4.5, dt)

    encounter.pulseTimer = encounter.pulseTimer + dt
    if encounter.pulseTimer >= encounter.pulseInterval then
        encounter.pulseTimer = encounter.pulseTimer - encounter.pulseInterval
        spawnPulse(encounter, encounter.innerRadius + 12, 20, 160 + encounter.floor * 3, 1.25)
        encounter.gapGlow = 1
        Audio:playSound("click")
    end

    updatePulses(encounter, dt)

    if encounter.gapGlow and encounter.gapGlow > 0 then
        encounter.gapGlow = math.max(0, encounter.gapGlow - dt * 1.6)
    end
end

local function updateStagger(encounter, dt)
    encounter.staggerTimer = (encounter.staggerTimer or 0) + dt
    encounter.gapWidth = approach(encounter.gapWidth, encounter.maxGap, 6.5, dt)
    encounter.displayRadius = approach(encounter.displayRadius, encounter.baseRadius * 0.96, 80, dt)
    updatePulses(encounter, dt)

    if encounter.hitCooldown > 0 then
        encounter.hitCooldown = math.max(0, encounter.hitCooldown - dt)
    end

    if encounter.staggerTimer >= STAGGER_DURATION then
        if encounter.defeated then
            encounter.state = "defeated"
            encounter.timer = 0
        else
            encounter.state = "active"
            encounter.staggerTimer = 0
            encounter.pulseTimer = 0
            encounter.gapWidth = encounter.maxGap
        end
    end
end

local function updateDefeated(encounter, dt)
    encounter.defeatTimer = (encounter.defeatTimer or 0) + dt
    encounter.fade = clamp(encounter.defeatTimer / CLEANUP_DURATION, 0, 1)
    encounter.gapWidth = approach(encounter.gapWidth, encounter.maxGap, 5, dt)
    updatePulses(encounter, dt)

    if not encounter.exitSpawned and encounter.defeatTimer >= EXIT_DELAY then
        Arena:spawnExit()
        encounter.exitSpawned = true
    end

    if encounter.defeatTimer >= CLEANUP_DURATION then
        encounter.state = "cleanup"
    end
end

function Boss:update(dt)
    if not current or not current.requiresEncounter then
        return
    end

    if current.state == "dormant" then
        return
    end

    if current.state == "intro" then
        updateIntro(current, dt)
    elseif current.state == "active" then
        updateActive(current, dt)
    elseif current.state == "stagger" then
        updateStagger(current, dt)
    elseif current.state == "defeated" then
        updateDefeated(current, dt)
    end
end

function Boss:onCoreEntered(x, y)
    if not current or current.hitCooldown > 0 then
        return
    end

    if current.state ~= "active" and current.state ~= "stagger" then
        return
    end

    current.hitCooldown = HIT_COOLDOWN
    current.health = math.max(0, (current.health or 0) - 1)
    current.state = "stagger"
    current.staggerTimer = 0
    current.gapGlow = 1

    Particles:spawnBurst(current.centerX, current.centerY, {
        count = 18,
        speed = 140,
        life = 0.55,
        size = 4,
        color = Theme.snake,
        spread = TWO_PI,
    })

    FloatingText:add("Core hit!", x, y - 40, {1, 0.9, 0.5, 1}, 1.0, 30)

    spawnPulse(current, current.coreRadius + 10, 26, 220, 1.0)
    Audio:playSound("shield_break")

    if current.health <= 0 then
        current.defeated = true
        current.state = "defeated"
        current.defeatTimer = 0
        current.fade = 0
        current.gapGlow = 1
        current.pulses = {}
        FloatingText:add("Boss shattered!", current.centerX, current.centerY - current.baseRadius - 32, {1, 0.95, 0.65, 1}, 1.8, 18, UI.fonts.title)
        Particles:spawnBurst(current.centerX, current.centerY, {
            count = 28,
            speed = 170,
            life = 0.75,
            size = 5,
            color = {1, 0.85, 0.35, 1},
            spread = TWO_PI,
        })
        Audio:playSound("achievement")
    end
end

function Boss:onShieldBlocked(x, y)
    Particles:spawnBurst(x, y, {
        count = 10,
        speed = 90,
        life = 0.4,
        size = 3,
        color = {1, 0.4, 0.4, 1},
        spread = TWO_PI,
    })
end

local function drawRing(encounter, alpha)
    local ringAlpha = (alpha or 1)
    local prevWidth = love.graphics.getLineWidth()
    local r, g, b = getBossColor()
    love.graphics.setLineWidth(encounter.ringThickness)
    love.graphics.setColor(r, g, b, 0.85 * ringAlpha)

    local radius = encounter.displayRadius - encounter.ringThickness / 2
    local start = (encounter.gapAngle + encounter.gapWidth * 0.5) % TWO_PI
    local endAngle = start + (TWO_PI - encounter.gapWidth)
    love.graphics.arc("line", encounter.centerX, encounter.centerY, radius, start, endAngle, 96)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(0, 0, 0, 0.9 * ringAlpha)
    love.graphics.circle("line", encounter.centerX, encounter.centerY, encounter.displayRadius, 96)
    love.graphics.circle("line", encounter.centerX, encounter.centerY, encounter.innerRadius, 96)
    love.graphics.setLineWidth(prevWidth)
end

local function drawGapGlow(encounter, alpha)
    if not encounter.gapGlow or encounter.gapGlow <= 0 then
        return
    end

    local glowAlpha = encounter.gapGlow * 0.55 * (alpha or 1)
    local gapHalf = encounter.gapWidth * 0.5
    local start = encounter.gapAngle - gapHalf
    local finish = encounter.gapAngle + gapHalf
    love.graphics.setColor(1, 1, 1, glowAlpha)
    love.graphics.arc("fill", encounter.centerX, encounter.centerY, encounter.displayRadius + 24, start, finish, 32)
end

local function drawPulses(encounter, alpha)
    if not encounter.pulses then return end

    local prevWidth = love.graphics.getLineWidth()
    for _, pulse in ipairs(encounter.pulses) do
        local progress = clamp(pulse.life / (pulse.maxLife or 1), 0, 1)
        local pulseAlpha = progress * 0.55 * (alpha or 1)
        love.graphics.setLineWidth(pulse.width)
        love.graphics.setColor(1, 1, 1, pulseAlpha)
        love.graphics.circle("line", encounter.centerX, encounter.centerY, pulse.radius, 64)
    end
    love.graphics.setLineWidth(prevWidth)
end

local function drawCore(encounter, alpha)
    local r, g, b = getBossColor()
    local coreAlpha = 0.85 * (alpha or 1)
    love.graphics.setColor(r, g, b, coreAlpha)
    love.graphics.circle("fill", encounter.centerX, encounter.centerY, encounter.coreRadius, 48)

    love.graphics.setColor(0, 0, 0, coreAlpha)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", encounter.centerX, encounter.centerY, encounter.coreRadius, 48)
end

local function drawHealth(encounter, alpha)
    if not encounter.maxHealth or encounter.maxHealth <= 0 then
        return
    end

    local ax, ay, aw = Arena:getBounds()
    local total = encounter.maxHealth
    local spacing = 24
    local width = (total - 1) * spacing
    local startX = ax + aw / 2 - width / 2
    local y = ay - 40

    for i = 1, total do
        local filled = i <= (encounter.health or 0)
        local fillAlpha = filled and (alpha or 1) or (0.2 * (alpha or 1))
        love.graphics.setColor(1, 0.9, 0.4, fillAlpha)
        love.graphics.rectangle("fill", startX + (i - 1) * spacing, y, 18, 18, 5, 5)
        love.graphics.setColor(0, 0, 0, 0.9 * (alpha or 1))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", startX + (i - 1) * spacing, y, 18, 18, 5, 5)
    end
end

function Boss:draw()
    if not current or not current.requiresEncounter then
        return
    end

    if current.state == "dormant" then
        return
    end

    local alpha = 1
    if current.state == "defeated" or current.state == "cleanup" then
        alpha = math.max(0, 1 - (current.fade or 0))
    end

    drawPulses(current, alpha)
    drawGapGlow(current, alpha)
    drawRing(current, alpha)
    drawCore(current, alpha)
    drawHealth(current, alpha)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

local function checkPulseCollision(encounter, dist, size)
    if not encounter.pulses then
        return false
    end

    for _, pulse in ipairs(encounter.pulses) do
        local half = (pulse.width or 18) * 0.5 + (size or 0) * 0.35
        if dist >= pulse.radius - half and dist <= pulse.radius + half then
            return true
        end
    end

    return false
end

function Boss:checkCollision(x, y, size)
    if not current or not current.requiresEncounter then
        return nil
    end

    if current.state ~= "active" and current.state ~= "stagger" then
        if current.state == "defeated" and checkPulseCollision(current, 0, size) then
            return "pulse"
        end
        return nil
    end

    local dx = x - current.centerX
    local dy = y - current.centerY
    local dist = math.sqrt(dx * dx + dy * dy)

    if checkPulseCollision(current, dist, size) then
        return "pulse"
    end

    local angle = math.atan2(dy, dx)
    if angle < 0 then angle = angle + TWO_PI end

    local outer = current.displayRadius + (size or 0) * 0.35
    local inner = current.innerRadius - (size or 0) * 0.35
    local coreRadius = current.coreRadius - (size or 0) * 0.25

    if dist <= coreRadius then
        if not current.coreInside and current.hitCooldown <= 0 then
            current.coreInside = true
            return "core"
        end
    else
        current.coreInside = false
    end

    if current.state == "stagger" then
        return nil
    end

    if dist >= inner and dist <= outer then
        local gapHalf = current.gapWidth * 0.5
        local diff = math.abs(angleDiff(angle, current.gapAngle))
        if diff > gapHalf then
            return "ring"
        end
    end

    return nil
end

return Boss
