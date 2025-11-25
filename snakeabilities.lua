local SnakeUpgrades = require("snakeupgrades")

local max = math.max
local min = math.min

local Abilities = {}

local DASH_STATE_ACTIVE = 1
local DASH_STATE_TIMER = 2
local DASH_STATE_DURATION = 3
local DASH_STATE_COOLDOWN = 4
local DASH_STATE_COOLDOWN_TIMER = 5

Abilities.DASH_STATE_ACTIVE = DASH_STATE_ACTIVE
Abilities.DASH_STATE_TIMER = DASH_STATE_TIMER
Abilities.DASH_STATE_DURATION = DASH_STATE_DURATION
Abilities.DASH_STATE_COOLDOWN = DASH_STATE_COOLDOWN
Abilities.DASH_STATE_COOLDOWN_TIMER = DASH_STATE_COOLDOWN_TIMER

local dashStateCache = {false, 0, 0, 0, 0}

local TIME_STATE_ACTIVE = 1
local TIME_STATE_TIMER = 2
local TIME_STATE_DURATION = 3
local TIME_STATE_COOLDOWN = 4
local TIME_STATE_COOLDOWN_TIMER = 5
local TIME_STATE_SCALE = 6
local TIME_STATE_FLOOR_CHARGES = 7
local TIME_STATE_MAX_FLOOR_USES = 8

Abilities.TIME_STATE_ACTIVE = TIME_STATE_ACTIVE
Abilities.TIME_STATE_TIMER = TIME_STATE_TIMER
Abilities.TIME_STATE_DURATION = TIME_STATE_DURATION
Abilities.TIME_STATE_COOLDOWN = TIME_STATE_COOLDOWN
Abilities.TIME_STATE_COOLDOWN_TIMER = TIME_STATE_COOLDOWN_TIMER
Abilities.TIME_STATE_SCALE = TIME_STATE_SCALE
Abilities.TIME_STATE_FLOOR_CHARGES = TIME_STATE_FLOOR_CHARGES
Abilities.TIME_STATE_MAX_FLOOR_USES = TIME_STATE_MAX_FLOOR_USES

local timeDilationStateCache = {false, 0, 0, 0, 0, 1, nil, nil}

local resolveTimeDilationScale = SnakeUpgrades.resolveTimeDilationScale

local function getUpgradesModule()
        return package.loaded["upgrades"]
end

function Abilities.activateDash(self)
        local dash = self.dash
        if not dash or dash.active then
                return false
        end

        if (dash.cooldownTimer or 0) > 0 then
                return false
        end

        dash.active = true
        dash.timer = dash.duration or 0
        dash.cooldownTimer = dash.cooldown or 0

        if dash.timer <= 0 then
                dash.active = false
        end

        local hx, hy = self:getHead()
        local Upgrades = getUpgradesModule()
        if Upgrades and Upgrades.notify then
                Upgrades:notify("dashActivated", {
                        x = hx,
                        y = hy,
                        }
                )
        end

        return dash.active
end

function Abilities.isDashActive(self)
        return self.dash and self.dash.active or false
end

function Abilities.getDashState(self)
        if not self.dash then
                return nil
        end

        local state = dashStateCache
        state[DASH_STATE_ACTIVE] = self.dash.active or false
        state[DASH_STATE_TIMER] = self.dash.timer or 0
        state[DASH_STATE_DURATION] = self.dash.duration or 0
        state[DASH_STATE_COOLDOWN] = self.dash.cooldown or 0
        state[DASH_STATE_COOLDOWN_TIMER] = self.dash.cooldownTimer or 0

        return state
end

function Abilities.onDashBreakRock(self, x, y)
        local dash = self.dash
        if not dash then return end

        local Upgrades = getUpgradesModule()
        if Upgrades and Upgrades.notify then
                Upgrades:notify("dashBreakRock", {
                        x = x,
                        y = y,
                        }
                )
        end
end

function Abilities.activateTimeDilation(self)
        local ability = self.timeDilation
        if not ability or ability.active then
                return false
        end

        if (ability.cooldownTimer or 0) > 0 then
                return false
        end

        local charges = ability.floorCharges
        if charges == nil and ability.maxFloorUses then
                charges = ability.maxFloorUses
                ability.floorCharges = charges
        end
        if charges ~= nil and charges <= 0 then
                return false
        end

        ability.active = true
        ability.timer = ability.duration or 0
        ability.cooldownTimer = ability.cooldown or 0

        if ability.timer <= 0 then
                ability.active = false
        end

        if ability.active and charges ~= nil then
                ability.floorCharges = max(0, charges - 1)
        end

        local hx, hy = self:getHead()
        local Upgrades = getUpgradesModule()
        if Upgrades and Upgrades.notify then
                Upgrades:notify("timeDilationActivated", {
                        x = hx,
                        y = hy,
                        }
                )
        end

        return ability.active
end

function Abilities.triggerChronoWard(self, duration, scale)
        duration = duration or 0
        if duration <= 0 then
                return false
        end

        scale = scale or 0.45
        if not (scale and scale > 0) then
                scale = 0.05
        else
                scale = max(0.05, min(1, scale))
        end

        local effect = self.chronoWard
        if not effect then
                effect = {}
                self.chronoWard = effect
        end

        effect.duration = duration
        effect.timeScale = min(effect.timeScale or 1, scale)
        if not (effect.timeScale and effect.timeScale > 0) then
                effect.timeScale = scale
        end

        effect.timer = max(effect.timer or 0, duration)
        effect.active = true
        effect.target = 1
        effect.time = effect.time or 0
        effect.intensity = effect.intensity or 0

        return true
end

function Abilities.getTimeDilationState(self)
        local ability = self.timeDilation
        if not ability then
                return nil
        end

        local state = timeDilationStateCache
        state[TIME_STATE_ACTIVE] = ability.active or false
        state[TIME_STATE_TIMER] = ability.timer or 0
        state[TIME_STATE_DURATION] = ability.duration or 0
        state[TIME_STATE_COOLDOWN] = ability.cooldown or 0
        state[TIME_STATE_COOLDOWN_TIMER] = ability.cooldownTimer or 0
        state[TIME_STATE_SCALE] = resolveTimeDilationScale(ability)
        state[TIME_STATE_FLOOR_CHARGES] = ability.floorCharges
        state[TIME_STATE_MAX_FLOOR_USES] = ability.maxFloorUses

        return state
end

function Abilities.getTimeScale(self)
        return resolveTimeDilationScale(self.timeDilation, self.chronoWard)
end

return Abilities
