local UI = require("ui")
local SessionStats = require("sessionstats")
local SnakeUpgrades = require("snakeupgrades")

local max = math.max
local min = math.min
local floor = math.floor

local UpgradesState = {}

UpgradesState.SHIELD_FLASH_DURATION = 0.3

function UpgradesState.getSpeed(state)
        local speed = (state.baseSpeed or 1) * (state.speedMult or 1)

        return speed
end

function UpgradesState.addSpeedMultiplier(state, mult)
        state.speedMult = (state.speedMult or 1) * (mult or 1)
end

function UpgradesState.addShields(state, n)
        n = n or 1
        local previous = state.shields or 0
        local updated = previous + n
        if updated < 0 then
                updated = 0
        end
        state.shields = updated

        if n ~= 0 then
                UI:setShields(state.shields)
        end
end

function UpgradesState.consumeShield(state)
        if (state.shields or 0) > 0 then
                state.shields = state.shields - 1
                state.shieldFlashTimer = UpgradesState.SHIELD_FLASH_DURATION
                UI:setShields(state.shields)
                SessionStats:add("shieldsSaved", 1)
                return true
        end
        return false
end

function UpgradesState.resetModifiers(state)
        state.speedMult    = 1
        state.shields = 0
        state.extraGrowth  = 0
        state.shieldFlashTimer = 0
        state.stoneSkinSawGrace = 0
        state.dash = nil
        state.timeDilation = nil
        state.adrenaline = nil
        state.hazardGraceTimer = 0
        state.phoenixEcho = nil
        state.eventHorizon = nil
        state.stormchaser = nil
        state.temporalAnchor = nil
        state.swiftFangs = nil
        state.zephyrCoils = nil
        state.momentumCoils = nil
        state.serpentsReflex = nil
        state.deliberateCoil = nil
        state.stoneSkinVisual = nil
        state.speedVisual = nil
        state.diffractionBarrier = nil
        UI:setShields(state.shields or 0, {silent = true, immediate = true})
end

local function normalizeStacks(count)
        return max(0, floor((count or 0) + 0.0001))
end

function UpgradesState.setSwiftFangsStacks(state, count)
        count = normalizeStacks(count)
        local existing = state.swiftFangs
        local previous = existing and (existing.stacks or 0) or 0

        if count > 0 then
                if not existing then
                        existing = {intensity = 0, baseTarget = 0, time = 0, stacks = 0, flash = 0}
                        state.swiftFangs = existing
                end

                existing.stacks = count
                existing.baseTarget = min(0.65, 0.32 + 0.11 * min(count, 4))
                existing.target = existing.baseTarget
                if count > previous then
                        existing.intensity = max(existing.intensity or 0, 0.55)
                        existing.flash = min(1, (existing.flash or 0) + 0.7)
                end
        elseif existing then
                existing.stacks = 0
                existing.baseTarget = 0
                existing.target = 0
        end

        if state.swiftFangs then
                local data = state.swiftFangs
                if (data.stacks or 0) <= 0 and (data.intensity or 0) <= 0.01 then
                        state.swiftFangs = nil
                end
        end
end

function UpgradesState.setSerpentsReflexStacks(state, count)
        count = normalizeStacks(count)

        local existing = state.serpentsReflex
        local previous = existing and (existing.stacks or 0) or 0

        if count > 0 then
                if not existing then
                        existing = {stacks = 0, intensity = 0, target = 0, time = 0, flash = 0}
                        state.serpentsReflex = existing
                end

                existing.stacks = count
                existing.target = min(1, 0.28 + 0.12 * min(count, 4))
                if count > previous then
                        existing.flash = min(1, (existing.flash or 0) + 0.65)
                        existing.intensity = max(existing.intensity or 0, 0.35)
                end
        elseif existing then
                existing.stacks = 0
                existing.target = 0
        end

        if state.serpentsReflex then
                local data = state.serpentsReflex
                if (data.stacks or 0) <= 0 and (data.intensity or 0) <= 0.01 and (data.flash or 0) <= 0.01 then
                        state.serpentsReflex = nil
                end
        end
end

local function ensureStackState(state, key)
        local stackState = state[key]
        if not stackState then
                stackState = {stacks = 0, intensity = 0, target = 0, time = 0}
                state[key] = stackState
        end
        return stackState
end

local function updateStackTarget(stackState, count, base, step, cap)
        stackState.stacks = count
        if count > 0 then
            stackState.target = min(1, base + step * min(count, cap))
            if (stackState.intensity or 0) < 0.25 then
                    stackState.intensity = max(stackState.intensity or 0, 0.25)
            end
        else
            stackState.target = 0
        end
end

function UpgradesState.setDeliberateCoilStacks(state, count)
        count = normalizeStacks(count)

        if count <= 0 and not state.deliberateCoil then
                return
        end

        local stackState = ensureStackState(state, "deliberateCoil")
        updateStackTarget(stackState, count, 0.38, 0.14, 3)
end

function UpgradesState.setMomentumCoilsStacks(state, count)
        count = normalizeStacks(count)

        if count <= 0 and not state.momentumCoils then
                return
        end

        local stackState = ensureStackState(state, "momentumCoils")
        updateStackTarget(stackState, count, 0.45, 0.2, 3)
end

function UpgradesState.setDiffractionBarrierActive(state, active)
        SnakeUpgrades.setDiffractionBarrierActive(state, active)
end

function UpgradesState.setPhoenixEchoCharges(state, count, options)
        SnakeUpgrades.setPhoenixEchoCharges(state, count, options)
end

function UpgradesState.setEventHorizonActive(state, active)
        SnakeUpgrades.setEventHorizonActive(state, active)
end

function UpgradesState.onShieldConsumed(state, x, y, cause)
        SnakeUpgrades.onShieldConsumed(state, x, y, cause)
end

function UpgradesState.addStoneSkinSawGrace(state, n)
        SnakeUpgrades.addStoneSkinSawGrace(state, n)
end

function UpgradesState.consumeStoneSkinSawGrace(state)
        return SnakeUpgrades.consumeStoneSkinSawGrace(state, UpgradesState.SHIELD_FLASH_DURATION)
end

function UpgradesState.isHazardGraceActive(state)
        return SnakeUpgrades.isHazardGraceActive(state)
end

function UpgradesState.beginHazardGrace(state, duration)
        SnakeUpgrades.beginHazardGrace(state, duration)
end

return UpgradesState
