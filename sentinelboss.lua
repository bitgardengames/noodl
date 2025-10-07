local Arena = require("arena")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local Audio = require("audio")
local UI = require("ui")
local Theme = require("theme")
local Score = require("score")
local Shaders = require("shaders")

local SentinelBoss = {}

local state = {
    active = false,
    guardians = {},
    pulses = {},
    centerX = 0,
    centerY = 0,
    empowerTimer = 0,
    empowerStacks = 0,
    empowerGlow = 0,
    empowerDuration = 6,
    maxStacks = 3,
    totalRequired = 0,
    damageCount = 0,
    guardianRadius = 32,
    defeated = false,
}

local HEAD_RADIUS = (SnakeUtils.SEGMENT_SIZE or 24) * 0.5
local TWO_PI = math.pi * 2

local function getTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return 0
end

local function resetState()
    state.active = false
    state.guardians = {}
    state.pulses = {}
    state.centerX = 0
    state.centerY = 0
    state.empowerTimer = 0
    state.empowerStacks = 0
    state.empowerGlow = 0
    state.empowerDuration = 6
    state.maxStacks = 3
    state.totalRequired = 0
    state.damageCount = 0
    state.guardianRadius = 32
    state.defeated = false
end

local function computeArenaCenter()
    local ax, ay, aw, ah = Arena:getBounds()
    return ax + aw * 0.5, ay + ah * 0.5, math.min(aw, ah)
end

local function spawnPulse(guardian)
    if not guardian or guardian.dead then
        return
    end

    local speed = guardian.pulseSpeed or 90
    local life = guardian.pulseLife or 2.8
    local thickness = guardian.pulseThickness or 18

    local pulse = {
        x = guardian.x or state.centerX,
        y = guardian.y or state.centerY,
        radius = state.guardianRadius * 0.75,
        speed = speed,
        life = life,
        maxLife = life,
        thickness = thickness,
        dangerous = true,
    }

    table.insert(state.pulses, pulse)

    Particles:spawnBurst(pulse.x, pulse.y, {
        count = love.math.random(8, 12),
        speed = 96,
        life = 0.45,
        size = 3,
        gravity = 0,
        color = {1, 0.65, 0.35, 0.9},
        fadeTo = 0,
    })
end

local function markGuardianHit(guardian)
    if not guardian or guardian.dead then
        return
    end

    guardian.health = math.max(0, (guardian.health or 1) - 1)
    guardian.hitFlash = 0.4
    guardian.pulseTimer = math.min(guardian.pulseTimer or 0, 0.45)

    state.damageCount = state.damageCount + 1

    Audio:playSound("shield_break")
    Score:addBonus(5)
    FloatingText:add("Sentinel hit!", guardian.x or state.centerX, (guardian.y or state.centerY) - 44, {1, 0.85, 0.5, 1}, 1.4, 40)

    Particles:spawnBurst(guardian.x or state.centerX, guardian.y or state.centerY, {
        count = love.math.random(12, 16),
        speed = 120,
        life = 0.6,
        gravity = 0,
        size = 4,
        drag = 1.2,
        color = {1, 0.6, 0.3, 1},
        fadeTo = 0,
    })

    UI:addFruit()
    if UI:isGoalReached() then
        Arena:spawnExit()
        Audio:playSound("goal_reached")
    end

    if guardian.health <= 0 then
        guardian.dead = true
        guardian.fade = 1.2
        guardian.hitRadius = 0
        FloatingText:add("Guardian down!", guardian.x or state.centerX, (guardian.y or state.centerY) - 72, {1, 0.95, 0.6, 1}, 1.8, 46)
    end

    if state.damageCount >= state.totalRequired then
        state.defeated = true
    end
end

local function updateGuardian(guardian, dt)
    if guardian.dead then
        guardian.fade = math.max(0, (guardian.fade or 0) - dt)
        return
    end

    guardian.angle = guardian.angle + (guardian.orbitSpeed or 0.8) * dt
    local orbitRadius = guardian.orbitRadius or state.guardianRadius
    local orbitSquash = guardian.orbitSquash or 0.72

    guardian.x = state.centerX + math.cos(guardian.angle) * orbitRadius
    guardian.y = state.centerY + math.sin(guardian.angle) * orbitRadius * orbitSquash

    guardian.pulseTimer = (guardian.pulseTimer or 0) - dt
    if guardian.pulseTimer <= 0 then
        spawnPulse(guardian)
        local base = guardian.pulseInterval or 4
        local variance = guardian.pulseVariance or 2.4
        guardian.pulseTimer = base + love.math.random() * variance
    end

    if guardian.hitFlash then
        guardian.hitFlash = math.max(0, guardian.hitFlash - dt)
    end
end

local function updatePulses(dt)
    for i = #state.pulses, 1, -1 do
        local pulse = state.pulses[i]
        pulse.radius = pulse.radius + pulse.speed * dt
        pulse.life = pulse.life - dt
        if pulse.life <= 0 then
            table.remove(state.pulses, i)
        end
    end
end

local function removeExpiredGuardians()
    for i = #state.guardians, 1, -1 do
        local guardian = state.guardians[i]
        if guardian.dead and (guardian.fade or 0) <= 0 then
            table.remove(state.guardians, i)
        end
    end
end

local function ensureCenter()
    state.centerX, state.centerY = computeArenaCenter()
end

function SentinelBoss:reset()
    resetState()
end

function SentinelBoss:isActive()
    return state.active
end

function SentinelBoss:beginFight(config)
    config = config or {}
    resetState()

    ensureCenter()

    state.active = true
    state.empowerDuration = math.max(2.5, config.empowerDuration or 6)
    state.maxStacks = math.max(1, config.maxStacks or 3)

    local _, _, arenaMin = computeArenaCenter()
    local baseRadius = math.max(80, (arenaMin or 240) * 0.25)
    state.guardianRadius = baseRadius

    local guardianCount = math.max(1, math.floor(config.guardians or 2))
    local healthPer = math.max(1, math.floor(config.guardianHealth or config.healthPerGuardian or 3))
    state.totalRequired = guardianCount * healthPer

    for i = 1, guardianCount do
        local angle = (i - 1) * (TWO_PI / guardianCount)
        local guardian = {
            angle = angle,
            orbitRadius = baseRadius,
            orbitSpeed = (config.orbitSpeed or 0.85) * (love.math.random() * 0.15 + 0.9),
            orbitSquash = config.orbitSquash or 0.68,
            pulseTimer = 1 + (i - 1) * 0.75,
            pulseInterval = config.pulseInterval or 4.2,
            pulseVariance = config.pulseVariance or 2.6,
            pulseSpeed = config.pulseSpeed or 90,
            pulseThickness = config.pulseThickness or 18,
            pulseLife = config.pulseLife or 2.8,
            health = healthPer,
            hitRadius = config.hitRadius or 28,
            maxHealth = healthPer,
        }
        guardian.x = state.centerX + math.cos(guardian.angle) * guardian.orbitRadius
        guardian.y = state.centerY + math.sin(guardian.angle) * guardian.orbitRadius * (guardian.orbitSquash or 0.72)
        table.insert(state.guardians, guardian)
    end

    UI:setFruitGoal(state.totalRequired)

    FloatingText:add("Twin sentinels awakened!", state.centerX, state.centerY - state.guardianRadius - 90, {1, 0.92, 0.65, 1}, 2.5, 48)
    FloatingText:add("Collect fruit to charge up", state.centerX, state.centerY - state.guardianRadius - 54, {0.7, 0.9, 1, 1}, 2.8, 38)
    Shaders.notify("specialEvent", { type = "boss", strength = 0.85, color = {1, 0.7, 0.35, 1} })
end

function SentinelBoss:onFruitCollected(info)
    if not state.active then
        return nil
    end

    state.empowerStacks = math.min(state.maxStacks, (state.empowerStacks or 0) + 1)
    state.empowerTimer = state.empowerDuration
    state.empowerGlow = 1

    local headX, headY = Snake:getHead()
    FloatingText:add("Power siphoned", headX or state.centerX, (headY or state.centerY) - 52, {0.7, 0.95, 1, 1}, 1.5, 34)
    Audio:playSound("shield_gain")
    Particles:spawnBurst(headX or state.centerX, headY or state.centerY, {
        count = love.math.random(10, 14),
        speed = 110,
        life = 0.45,
        gravity = 0,
        size = 3,
        drag = 1.0,
        color = {0.65, 0.95, 1, 1},
        fadeTo = 0,
    })

    return { skipProgress = true }
end

local function releaseCharge()
    state.empowerStacks = math.max(0, (state.empowerStacks or 0) - 1)
    if state.empowerStacks <= 0 then
        state.empowerTimer = 0
    end
end

function SentinelBoss:checkCollision(headX, headY)
    if not state.active and #state.guardians == 0 then
        return nil
    end

    local hitRadius = HEAD_RADIUS

    for _, pulse in ipairs(state.pulses) do
        if pulse.dangerous then
            local dx = headX - (pulse.x or state.centerX)
            local dy = headY - (pulse.y or state.centerY)
            local dist = math.sqrt(dx * dx + dy * dy)
            local inner = pulse.radius - (pulse.thickness or 16) * 0.5 - hitRadius
            local outer = pulse.radius + (pulse.thickness or 16) * 0.5 + hitRadius
            if dist >= (inner or 0) and dist <= (outer or 0) then
                return "hit", "boss", { boss = "sentinelPulse", damage = 1, fatal = true }
            end
        end
    end

    if not state.active then
        return nil
    end

    for _, guardian in ipairs(state.guardians) do
        if not guardian.dead then
            local radius = (guardian.hitRadius or 28) + hitRadius
            local dx = (guardian.x or state.centerX) - headX
            local dy = (guardian.y or state.centerY) - headY
            local distSq = dx * dx + dy * dy
            if distSq <= radius * radius then
                if state.empowerStacks > 0 and state.empowerTimer > 0 then
                    markGuardianHit(guardian)
                    releaseCharge()
                    return nil
                end
                return "hit", "boss", { boss = "sentinelGuardian", damage = 1, fatal = true }
            end
        end
    end

    return nil
end

local function drawGuardian(guardian)
    if guardian.dead then
        if (guardian.fade or 0) <= 0 then
            return
        end
    end

    local alpha = guardian.dead and (guardian.fade or 0) or 1
    local bodyColor = Theme.bossBodyColor or {0.95, 0.55, 0.25, 1}
    local rimColor = Theme.bossRimColor or {0.35, 0.85, 1, 0.9}
    local shadowColor = {0, 0, 0, 0.35 * alpha}

    love.graphics.setColor(shadowColor)
    love.graphics.circle("fill", guardian.x, guardian.y + 6, (guardian.hitRadius or 28) + 6)

    love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3], (bodyColor[4] or 1) * alpha)
    love.graphics.circle("fill", guardian.x, guardian.y, guardian.hitRadius or 28)

    local sections = guardian.maxHealth or guardian.health or 1
    local filled = guardian.health or sections
    local arcRadius = (guardian.hitRadius or 28) + 8

    love.graphics.setLineWidth(4)
    for i = 1, sections do
        local startAngle = -math.pi * 0.5 + (i - 1) * (TWO_PI / sections)
        local endAngle = startAngle + (TWO_PI / sections) - 0.22
        if i <= filled then
            love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], (rimColor[4] or 1) * alpha)
        else
            love.graphics.setColor(0.2, 0.25, 0.3, 0.45 * alpha)
        end
        love.graphics.arc("line", guardian.x, guardian.y, arcRadius, startAngle, endAngle)
    end
    love.graphics.setLineWidth(1)

    if guardian.hitFlash and guardian.hitFlash > 0 then
        local flashAlpha = math.min(1, guardian.hitFlash / 0.4)
        love.graphics.setColor(1, 1, 1, 0.6 * flashAlpha)
        love.graphics.circle("line", guardian.x, guardian.y, (guardian.hitRadius or 28) + 2)
    end
end

local function drawPulses()
    if #state.pulses == 0 then
        return
    end

    love.graphics.setLineJoin("miter")
    for _, pulse in ipairs(state.pulses) do
        local progress = math.max(0, pulse.life / (pulse.maxLife or pulse.life + 0.001))
        local alpha = (pulse.dangerous and 0.45 or 0.25) * progress
        local color = pulse.dangerous and {1, 0.5, 0.35, alpha} or {0.6, 0.7, 0.8, alpha}
        love.graphics.setColor(color)
        love.graphics.setLineWidth(pulse.thickness or 16)
        love.graphics.circle("line", pulse.x or state.centerX, pulse.y or state.centerY, pulse.radius)
    end
    love.graphics.setLineWidth(1)
end

local function drawLink()
    local alive = {}
    for _, guardian in ipairs(state.guardians) do
        if not guardian.dead then
            table.insert(alive, guardian)
        end
    end
    if #alive < 2 then
        return
    end

    love.graphics.setColor(0.6, 0.9, 1, 0.45)
    love.graphics.setLineWidth(6)
    love.graphics.line(alive[1].x, alive[1].y, alive[2].x, alive[2].y)
    love.graphics.setLineWidth(1)
end

local function drawEmpowerment()
    if state.empowerStacks <= 0 or state.empowerTimer <= 0 then
        return
    end

    local headX, headY = Snake:getHead()
    if not (headX and headY) then
        return
    end

    local fraction = math.max(0, math.min(1, state.empowerTimer / state.empowerDuration))
    local glow = state.empowerGlow or fraction
    local pulses = math.max(1, state.empowerStacks)
    local baseRadius = HEAD_RADIUS + 14
    local time = getTime()

    for i = 1, pulses do
        local offset = (i - 1) * 4
        local wobble = math.sin(time * 4 + i * 1.3) * 2
        local radius = baseRadius + offset + wobble
        local alpha = (0.35 + 0.1 * i) * glow
        love.graphics.setColor(0.6, 0.95, 1, alpha)
        love.graphics.setLineWidth(3 + i)
        love.graphics.circle("line", headX, headY, radius)
    end
    love.graphics.setLineWidth(1)
end

function SentinelBoss:update(dt)
    if state.empowerGlow and state.empowerGlow > 0 then
        state.empowerGlow = math.max(0, state.empowerGlow - dt * 1.4)
    end

    if state.empowerTimer > 0 then
        state.empowerTimer = math.max(0, state.empowerTimer - dt)
        if state.empowerTimer <= 0 then
            state.empowerStacks = 0
        end
    end

    ensureCenter()

    for _, guardian in ipairs(state.guardians) do
        updateGuardian(guardian, dt)
    end

    updatePulses(dt)
    removeExpiredGuardians()

    if state.defeated then
        self:deactivate()
    end
end

function SentinelBoss:deactivate()
    if not state.active and state.defeated then
        state.pulses = {}
        state.defeated = false
        return
    end

    state.active = false
    state.empowerStacks = 0
    state.empowerTimer = 0
    for _, pulse in ipairs(state.pulses) do
        pulse.dangerous = false
    end
    state.defeated = false
end

function SentinelBoss:draw()
    if state.active or #state.guardians > 0 or #state.pulses > 0 then
        drawPulses()
        drawLink()
        for _, guardian in ipairs(state.guardians) do
            drawGuardian(guardian)
        end
        drawEmpowerment()
    end
end

return SentinelBoss
