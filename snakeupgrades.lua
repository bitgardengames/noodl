local min = math.min
local max = math.max
local floor = math.floor

local SnakeUpgrades = {}

SnakeUpgrades.HAZARD_GRACE_DURATION = 0.12 -- brief invulnerability window after surviving certain hazards

function SnakeUpgrades.setDiffractionBarrierActive(snake, active)
        if active then
                local state = snake.diffractionBarrier
                if not state then
                        state = {intensity = 0, target = 0, time = 0, flash = 0}
                        snake.diffractionBarrier = state
                end

                if not state.active then
                        state.flash = min(1.25, (state.flash or 0) + 0.9)
                        state.intensity = max(state.intensity or 0, 0.55)
                end

                state.active = true
                state.target = 1
        else
                local state = snake.diffractionBarrier
                if state then
                        state.active = false
                        state.target = 0
                end
        end
end

function SnakeUpgrades.setPhoenixEchoCharges(snake, count, options)
        count = max(0, floor((count or 0) + 0.0001))
        options = options or {}

        local state = snake.phoenixEcho
        if not state and (count > 0 or options.triggered or options.instantIntensity) then
                state = {intensity = 0, target = 0, time = 0, flareTimer = 0, flareDuration = 1.2, charges = 0}
                snake.phoenixEcho = state
        elseif not state then
                return
        end

        local previous = state.charges or 0
        state.charges = count

        if count > 0 then
                state.target = min(1, 0.55 + 0.18 * min(count, 3))
        else
                state.target = 0
        end

        if count > previous then
                state.flareTimer = max(state.flareTimer or 0, 1.25)
        elseif count < previous then
                state.flareTimer = max(state.flareTimer or 0, 0.9)
        end

        if options.triggered then
                state.flareTimer = max(state.flareTimer or 0, options.triggered)
                state.intensity = max(state.intensity or 0, 0.85)
        end

        if options.instantIntensity then
                state.intensity = max(state.intensity or 0, options.instantIntensity)
        end

        if options.flareDuration then
                state.flareDuration = options.flareDuration
        elseif not state.flareDuration then
                state.flareDuration = 1.2
        end

        if count <= 0 and state.target <= 0 and (state.intensity or 0) <= 0 and (state.flareTimer or 0) <= 0 then
                snake.phoenixEcho = nil
        end
end

function SnakeUpgrades.setEventHorizonActive(snake, active)
        if active then
                local state = snake.eventHorizon
                if not state then
                        state = {intensity = 0, target = 1, spin = 0, time = 0}
                        snake.eventHorizon = state
                end
                state.target = 1
                state.active = true
        else
                local state = snake.eventHorizon
                if state then
                        state.target = 0
                        state.active = false
                end
        end
end

function SnakeUpgrades.onShieldConsumed(snake, x, y, cause)
        if (not x or not y) and snake.getHead then
                x, y = snake:getHead()
        end

        local Upgrades = package.loaded["upgrades"]
        if Upgrades and Upgrades.notify then
                Upgrades:notify("shieldConsumed", {
                                x = x,
                                y = y,
                                cause = cause or "unknown",
                        }
                )
        end
end

function SnakeUpgrades.addStoneSkinSawGrace(snake, n)
        n = n or 1
        if n <= 0 then return end
        snake.stoneSkinSawGrace = (snake.stoneSkinSawGrace or 0) + n

        local visual = snake.stoneSkinVisual
        if not visual then
                visual = {intensity = 0, target = 0, flash = 0, time = 0, charges = 0}
                snake.stoneSkinVisual = visual
        end

        visual.charges = snake.stoneSkinSawGrace or 0
        visual.target = min(1, 0.45 + 0.18 * min(visual.charges, 4))
        visual.intensity = max(visual.intensity or 0, 0.32 + 0.12 * min(visual.charges, 3))
        visual.flash = max(visual.flash or 0, 0.75)
end

function SnakeUpgrades.consumeStoneSkinSawGrace(snake, shieldFlashDuration)
        if (snake.stoneSkinSawGrace or 0) > 0 then
                snake.stoneSkinSawGrace = snake.stoneSkinSawGrace - 1
                snake.shieldFlashTimer = shieldFlashDuration or 0

                if snake.stoneSkinVisual then
                        local visual = snake.stoneSkinVisual
                        visual.charges = snake.stoneSkinSawGrace or 0
                        visual.target = min(1, 0.45 + 0.18 * min(visual.charges, 4))
                        visual.flash = max(visual.flash or 0, 1)
                end

                return true
        end
        return false
end

function SnakeUpgrades.isHazardGraceActive(snake)
        return (snake.hazardGraceTimer or 0) > 0
end

function SnakeUpgrades.beginHazardGrace(snake, duration)
        local grace = duration or SnakeUpgrades.HAZARD_GRACE_DURATION
        if not (grace and grace > 0) then
                return
        end

        local current = snake.hazardGraceTimer or 0
        if grace > current then
                snake.hazardGraceTimer = grace
        end
end

return SnakeUpgrades
