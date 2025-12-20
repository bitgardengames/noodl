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

return Abilities
