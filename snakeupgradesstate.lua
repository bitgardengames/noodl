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
        state.adrenaline = nil
        state.hazardGraceTimer = 0
        state.phoenixEcho = nil
        state.eventHorizon = nil
        state.stormchaser = nil
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

local STACK_DEFAULTS = {stacks = 0, intensity = 0, target = 0, time = 0, flash = 0}

local function acquireStackState(state, key, defaults)
        local stackState = state[key]
        if not stackState then
                stackState = {}
                for k, v in pairs(STACK_DEFAULTS) do
                        stackState[k] = v
                end
                if defaults then
                        for k, v in pairs(defaults) do
                                stackState[k] = v
                        end
                end
                state[key] = stackState
        end
        return stackState
end

local function updateStackedEffect(state, key, count, options)
        count = normalizeStacks(count)
        local existing = state[key]
        local previous = existing and (existing.stacks or 0) or 0

        if count <= 0 and not existing then
                return
        end

        if count > 0 then
                existing = acquireStackState(state, key, options.defaults)
                existing.stacks = count

                local scaledStacks = min(count, options.stackCap or count)
                local target = min(options.targetCap or 1, options.base + options.step * scaledStacks)
                existing.target = target
                if options.targetField then
                        existing[options.targetField] = target
                end

                if count > previous then
                        if options.minIntensity then
                                existing.intensity = max(existing.intensity or 0, options.minIntensity)
                        end
                        if options.flashIncrease then
                                existing.flash = min(1, (existing.flash or 0) + options.flashIncrease)
                        end
                end
        elseif existing then
                existing.stacks = 0
                existing.target = 0
                if options.targetField then
                        existing[options.targetField] = 0
                end
        end

        local data = state[key]
        if not data then
                return
        end

        local shouldRemove = (data.stacks or 0) <= 0 and (data.intensity or 0) <= 0.01
        if options.checkFlashForCleanup then
                shouldRemove = shouldRemove and (data.flash or 0) <= 0.01
        end

        if shouldRemove then
                state[key] = nil
        end
end

function UpgradesState.setSwiftFangsStacks(state, count)
        updateStackedEffect(state, "swiftFangs", count, {
                base = 0.32,
                step = 0.11,
                stackCap = 4,
                targetCap = 0.65,
                targetField = "baseTarget",
                minIntensity = 0.55,
                flashIncrease = 0.7,
                defaults = {baseTarget = 0},
        })
end

function UpgradesState.setSerpentsReflexStacks(state, count)
        updateStackedEffect(state, "serpentsReflex", count, {
                base = 0.28,
                step = 0.12,
                stackCap = 4,
                minIntensity = 0.35,
                flashIncrease = 0.65,
                checkFlashForCleanup = true,
        })
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
