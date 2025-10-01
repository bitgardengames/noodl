local Audio = require("audio")
local Floors = require("floors")
local SessionStats = require("sessionstats")
local PlayerStats = require("playerstats")
local Shop = require("shop")
local RogueChoices = require("roguechoices")

local TransitionManager = {}
TransitionManager.__index = TransitionManager

local function shallowCopy(values)
    local copy = {}
    if not values then
        return copy
    end

    for key, value in pairs(values) do
        copy[key] = value
    end

    return copy
end

function TransitionManager.new(game)
    return setmetatable({
        game = game,
        phase = nil,
        timer = 0,
        duration = 0,
        data = {},
        shopCloseRequested = false,
        decisionCloseRequested = false,
    }, TransitionManager)
end

function TransitionManager:reset()
    self.phase = nil
    self.timer = 0
    self.duration = 0
    self.data = {}
    self.shopCloseRequested = false
    self.decisionCloseRequested = false
    RogueChoices:clearDecision()
end

function TransitionManager:isActive()
    return self.phase ~= nil
end

function TransitionManager:isShopActive()
    return self.phase == "shop"
end

function TransitionManager:isDecisionActive()
    return self.phase == "decision"
end

function TransitionManager:getPhase()
    return self.phase
end

function TransitionManager:getTimer()
    return self.timer
end

function TransitionManager:getDuration()
    return self.duration
end

function TransitionManager:getData()
    return self.data
end

function TransitionManager:setData(values)
    self.data = shallowCopy(values)
end

function TransitionManager:mergeData(values)
    if not values then
        return
    end

    for key, value in pairs(values) do
        self.data[key] = value
    end
end

function TransitionManager:startPhase(phase, duration)
    self.game.state = "transition"
    self.phase = phase
    self.timer = 0
    self.duration = duration or 0
end

function TransitionManager:clearPhase()
    self.phase = nil
    self.timer = 0
    self.duration = 0
end

function TransitionManager:openShop()
    Shop:start(self.game.floor)
    self.shopCloseRequested = false
    self.phase = "shop"
    self.timer = 0
    self.duration = 0
    Audio:playSound("shop_open")
end

function TransitionManager:openDecision()
    self.decisionCloseRequested = false
    self.phase = "decision"
    self.timer = 0
    self.duration = 0
    Audio:playSound("shop_open")
end

function TransitionManager:startFloorIntro(duration, extra)
    extra = shallowCopy(extra)
    if not extra.transitionResumePhase then
        extra.transitionResumePhase = "fadein"
    end

    if extra.transitionResumePhase == "fadein" and not extra.transitionResumeFadeDuration then
        extra.transitionResumeFadeDuration = 1.2
    elseif extra.transitionResumePhase ~= "fadein" then
        extra.transitionResumeFadeDuration = nil
    end

    self:mergeData(extra)
    self:startPhase("floorintro", duration or 3.5)
    Audio:playSound("floor_intro")
end

function TransitionManager:startFadeIn(duration)
    self:startPhase("fadein", duration or 1.2)
end

function TransitionManager:startFloorTransition(advance, skipFade)
    local game = self.game

    local pendingFloor = advance and (game.floor + 1) or nil
    local floorData = Floors[pendingFloor or game.floor] or Floors[1]

    if advance then
        local floorTime = game.floorTimer or 0
        if floorTime and floorTime > 0 then
            SessionStats:add("totalFloorTime", floorTime)
            SessionStats:updateMin("fastestFloorClear", floorTime)
            SessionStats:updateMax("slowestFloorClear", floorTime)
            SessionStats:set("lastFloorClearTime", floorTime)
        end
        game.floorTimer = 0

        local currentFloor = game.floor or 1
        local nextFloor = currentFloor + 1
        PlayerStats:add("floorsCleared", 1)
        PlayerStats:updateMax("deepestFloorReached", nextFloor)
        SessionStats:add("floorsCleared", 1)
        SessionStats:updateMax("deepestFloorReached", nextFloor)
        Audio:playSound("floor_advance")
    end

    local targetFloor = pendingFloor or game.floor
    local pendingDecision = advance and RogueChoices:shouldOfferDecision(targetFloor)

    self:setData({
        transitionAdvance = advance,
        pendingFloor = pendingFloor,
        transitionFloorData = floorData,
        floorApplied = false,
        pendingDecision = pendingDecision,
    })

    self.shopCloseRequested = false
    self.decisionCloseRequested = false
    self:startPhase("fadeout", skipFade and 0 or 1.2)
end

function TransitionManager:update(dt)
    if not self:isActive() then
        return
    end

    self.timer = self.timer + dt
    local phase = self.phase

    if phase == "fadeout" then
        if self.timer >= self.duration then
            local data = self.data

            if data.transitionAdvance and data.pendingFloor then
                self.game.floor = data.pendingFloor
            end

            if data.pendingDecision and data.transitionAdvance then
                if RogueChoices:startDecision(self.game, self.game.floor) then
                    self:openDecision()
                    return
                end
                data.pendingDecision = false
            end

            if not data.floorApplied then
                self.game:setupFloor(self.game.floor)
                data.floorApplied = true
            end

            self:openShop()
        end
        return
    end

    if phase == "decision" then
        RogueChoices:update(dt)
        if self.decisionCloseRequested and RogueChoices:isSelectionComplete() then
            self.decisionCloseRequested = false
            self.data.pendingDecision = false

            self.game:setupFloor(self.game.floor)
            self.data.floorApplied = true

            RogueChoices:clearDecision()
            self:openShop()
        end
        return
    end

    if phase == "shop" then
        Shop:update(dt)
        if self.shopCloseRequested and Shop:isSelectionComplete() then
            self.shopCloseRequested = false
            self:startFloorIntro()
        end
        return
    end

    if phase == "floorintro" then
        if self.timer >= self.duration then
            local data = self.data
            local resumePhase = data.transitionResumePhase or "fadein"
            local fadeDuration = data.transitionResumeFadeDuration

            data.transitionResumePhase = nil
            data.transitionResumeFadeDuration = nil

            if resumePhase == "fadein" then
                self:startFadeIn(fadeDuration)
            else
                self.game.state = "playing"
                self:clearPhase()
            end
        end
        return
    end

    if phase == "fadein" then
        if self.timer >= self.duration then
            self.game.state = "playing"
            self:clearPhase()
        end
        return
    end
end

function TransitionManager:handleShopInput(methodName, ...)
    if not self:isShopActive() then
        return false
    end

    local handler = Shop[methodName]
    if not handler then
        return true
    end

    local result = handler(Shop, ...)
    if result then
        self.shopCloseRequested = true
    end

    return true
end

function TransitionManager:handleDecisionInput(methodName, ...)
    if not self:isDecisionActive() then
        return false
    end

    local handler = RogueChoices[methodName]
    if not handler then
        return true
    end

    local result = handler(RogueChoices, ...)
    if result == true then
        self.decisionCloseRequested = true
    end

    return true
end

return TransitionManager
