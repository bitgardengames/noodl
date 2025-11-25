local MovementContext = require("movementcontext")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local SnakeUpgrades = require("snakeupgrades")
local SnakeUtils = require("snakeutils")
local SnakeUpgradesState = require("snakeupgradesstate")

local sqrt = math.sqrt

local Damage = {}

local SHIELD_DAMAGE_FLOATING_TEXT_COLOR = {1, 0.78, 0.68, 1}
local SHIELD_DAMAGE_FLOATING_TEXT_OPTIONS = {
        scale = 18,
        popScaleFactor = 1.45,
        popDuration = 0.24,
        wobbleMagnitude = 0.2,
        wobbleFrequency = 4.6,
        shadow = {
                color = {0, 0, 0, 0.6},
                offset = {0, 3},
                blur = 1.6,
        },
        glow = {
                color = {1, 0.42, 0.32, 0.45},
                magnitude = 0.35,
                frequency = 5.2,
        },
        jitter = 2.4,
}

local SHIELD_BREAK_PARTICLE_OPTIONS = {
        count = 16,
        speed = 1,
        speedVariance = 90,
        life = 0.48,
        size = 5,
        color = {1, 0.46, 0.32, 1},
        spread = math.pi * 2,
        angleJitter = math.pi,
        drag = 3.2,
        gravity = 280,
        fadeTo = 0.05,
}

local SHIELD_BLOOD_PARTICLE_OPTIONS = {
        dirX = 0,
        dirY = -1,
        spread = math.pi * 0.65,
        count = 10,
        dropletCount = 6,
        speed = 210,
        speedVariance = 80,
        life = 0.5,
        size = 3.6,
        gravity = 340,
        fadeTo = 0.06,
}

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local HAZARD_GRACE_DURATION = SnakeUpgrades.HAZARD_GRACE_DURATION
local SHIELD_FLASH_DURATION = SnakeUpgradesState.SHIELD_FLASH_DURATION
local DAMAGE_FLASH_DURATION = 0.45

local CTX_PUSH_X = MovementContext.PUSH_X
local CTX_PUSH_Y = MovementContext.PUSH_Y
local CTX_SNAP_X = MovementContext.SNAP_X
local CTX_SNAP_Y = MovementContext.SNAP_Y
local CTX_DIR_X = MovementContext.DIR_X
local CTX_DIR_Y = MovementContext.DIR_Y
local CTX_GRACE = MovementContext.GRACE
local CTX_DAMAGE = MovementContext.DAMAGE
local CTX_INFLICTED_DAMAGE = MovementContext.INFLICTED_DAMAGE

local function resolveBurstDir(pushX, pushY, dirX, dirY, direction)
        local burstDirX, burstDirY = 0, -1
        local pushMag = sqrt(pushX * pushX + pushY * pushY)
        if pushMag > 1e-4 then
                burstDirX = pushX / pushMag
                burstDirY = pushY / pushMag
        elseif dirX and dirY and (dirX ~= 0 or dirY ~= 0) then
                local dirMag = sqrt(dirX * dirX + dirY * dirY)
                if dirMag > 1e-4 then
                        burstDirX = -dirX / dirMag
                        burstDirY = -dirY / dirMag
                end
        elseif direction then
                local faceX = direction[1] or 0
                local faceY = direction[2] or -1
                local faceMag = sqrt(faceX * faceX + faceY * faceY)
                if faceMag > 1e-4 then
                        burstDirX = -faceX / faceMag
                        burstDirY = -faceY / faceMag
                end
        end

        return burstDirX, burstDirY
end

function Damage.onDamageTaken(snake, cause, info, direction)
        local pushX = (info and info[CTX_PUSH_X]) or 0
        local pushY = (info and info[CTX_PUSH_Y]) or 0
        local translated = false

        if pushX ~= 0 or pushY ~= 0 then
                snake:translate(pushX, pushY)
                translated = true
        end

        local snapX = info and info[CTX_SNAP_X]
        local snapY = info and info[CTX_SNAP_Y]
        if snapX and snapY and not translated then
                snake:setHeadPosition(snapX, snapY)
        end

        local dirX = info and info[CTX_DIR_X]
        local dirY = info and info[CTX_DIR_Y]
        if (dirX and dirX ~= 0) or (dirY and dirY ~= 0) then
                snake:setDirectionVector(dirX or 0, dirY or 0)
        end

        local grace = (info and info[CTX_GRACE]) or (HAZARD_GRACE_DURATION * 2)
        if grace and grace > 0 then
                snake:beginHazardGrace(grace)
        end

        local headX, headY = snake:getHead()
        if headX and headY then
                local centerX = headX + SEGMENT_SIZE * 0.5
                local centerY = headY + SEGMENT_SIZE * 0.5

                local burstDirX, burstDirY = resolveBurstDir(pushX, pushY, dirX, dirY, direction)

                if Particles and Particles.spawnBurst then
                        Particles:spawnBurst(centerX, centerY, SHIELD_BREAK_PARTICLE_OPTIONS)
                end

                local shielded = info and info[CTX_DAMAGE] ~= nil and info[CTX_DAMAGE] <= 0
                if Particles and Particles.spawnBlood and not shielded then
                        SHIELD_BLOOD_PARTICLE_OPTIONS.dirX = burstDirX
                        SHIELD_BLOOD_PARTICLE_OPTIONS.dirY = burstDirY
                        Particles:spawnBlood(centerX, centerY, SHIELD_BLOOD_PARTICLE_OPTIONS)
                end

                if FloatingText and FloatingText.add then
                        local inflicted = info and (info[CTX_INFLICTED_DAMAGE] or info[CTX_DAMAGE])
                        local label
                        if shielded then
                                label = "SHIELD!"
                        elseif inflicted and inflicted > 0 then
                                label = nil
                        else
                                label = "HIT!"
                        end

                        if label then
                                FloatingText:add(label, centerX, centerY - 30, SHIELD_DAMAGE_FLOATING_TEXT_COLOR, 0.9, 36, nil, SHIELD_DAMAGE_FLOATING_TEXT_OPTIONS)
                        end
                end
        end

        snake.shieldFlashTimer = SHIELD_FLASH_DURATION
        snake.damageFlashTimer = DAMAGE_FLASH_DURATION
end

return Damage
