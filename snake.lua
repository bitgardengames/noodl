local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local SnakeDraw = require("snakedraw")
local Rocks = require("rocks")
local Saws = require("saws")
local UI = require("ui")
local Fruit = require("fruit")
local Particles = require("particles")
local SessionStats = require("sessionstats")
local Score = require("score")
local SnakeCosmetics = require("snakecosmetics")
local FloatingText = require("floatingtext")

local abs = math.abs
local floor = math.floor
local huge = math.huge
local min = math.min
local pi = math.pi
local insert = table.insert
local remove = table.remove
local Snake = {}
local sqrt = math.sqrt
local max = math.max

local spawnGluttonsWakeRock
local crystallizeGluttonsWakeSegments

local screenW, screenH
local direction = {x = 1, y = 0}
local pendingDir = {x = 1, y = 0}
local trail = {}
local descendingHole = nil
local segmentCount = 1
local popTimer = 0
local isDead = false

local clippedTrailBuffer = {}
local clippedTrailProxy = {drawX = 0, drawY = 0}
local severedPieces = {}
local developerAssistEnabled = false
local portalAnimation = nil
local cellKeyStride = 0

local segmentPool = {}
local segmentPoolCount = 0

local headCellBuffer = {}
local snakeBodyOccupancy = {}

local TILE_COORD_EPSILON = 1e-9

local function wipeTable(t)
        if not t then
                return
        end

        for k in pairs(t) do
                t[k] = nil
        end
end

local function clearSnakeBodyOccupancy()
        for _, column in pairs(snakeBodyOccupancy) do
                wipeTable(column)
        end
end
local snakeOccupiedCells = {}
local snakeOccupiedCellCount = 0
local occupancyCols = 0
local occupancyRows = 0
local headOccupancyCol = nil
local headOccupancyRow = nil

local function resetTrackedSnakeCells()
        if snakeOccupiedCellCount <= 0 then
                return
        end

        for i = 1, snakeOccupiedCellCount do
                local cell = snakeOccupiedCells[i]
                if cell then
                        cell[1] = nil
                        cell[2] = nil
                end
        end

        snakeOccupiedCellCount = 0
end

local function clearSnakeOccupiedCells()
        if snakeOccupiedCellCount <= 0 then
                return
        end

        for i = 1, snakeOccupiedCellCount do
                local cell = snakeOccupiedCells[i]
                if cell then
                        local col, row = cell[1], cell[2]
                        if col and row then
                                SnakeUtils.setOccupied(col, row, false)
                        end
                        cell[1] = nil
                        cell[2] = nil
                end
        end

        snakeOccupiedCellCount = 0
end

local function recordSnakeOccupiedCell(col, row)
        local index = snakeOccupiedCellCount + 1
        local cell = snakeOccupiedCells[index]
        if cell then
                cell[1] = col
                cell[2] = row
        else
                snakeOccupiedCells[index] = {col, row}
        end
        snakeOccupiedCellCount = index
        SnakeUtils.setOccupied(col, row, true)
end

local function resetSnakeOccupancyGrid()
        if SnakeUtils and SnakeUtils.initOccupancy then
                SnakeUtils.initOccupancy()
        end

        resetTrackedSnakeCells()
        clearSnakeBodyOccupancy()

        occupancyCols = (Arena and Arena.cols) or 0
        occupancyRows = (Arena and Arena.rows) or 0

        headOccupancyCol = nil
        headOccupancyRow = nil
end

local function ensureOccupancyGrid()
        local cols = (Arena and Arena.cols) or 0
        local rows = (Arena and Arena.rows) or 0
        if cols <= 0 or rows <= 0 then
                return false
        end

        if cols ~= occupancyCols or rows ~= occupancyRows then
                resetSnakeOccupancyGrid()
        elseif not SnakeUtils or not SnakeUtils.occupied or not SnakeUtils.occupied[cols] then
                resetSnakeOccupancyGrid()
        end

        return true
end

local function acquireSegment()
        if segmentPoolCount > 0 then
                local segment = segmentPool[segmentPoolCount]
                segmentPool[segmentPoolCount] = nil
                segmentPoolCount = segmentPoolCount - 1
                return segment
        end

        return {}
end

local function releaseSegment(segment)
        if not segment then
                return
        end

        segment.drawX = nil
        segment.drawY = nil
        segment.x = nil
        segment.y = nil
        segment.dirX = nil
        segment.dirY = nil
        segment.fruitMarker = nil
        segment.fruitMarkerX = nil
        segment.fruitMarkerY = nil

        segmentPoolCount = segmentPoolCount + 1
        segmentPool[segmentPoolCount] = segment
end

local function releaseSegmentRange(buffer, startIndex)
        if not buffer then
                return
        end

        for i = #buffer, startIndex, -1 do
                local segment = buffer[i]
                buffer[i] = nil
                if segment then
                        releaseSegment(segment)
                end
        end
end

local function recycleTrail(buffer)
        if not buffer then
                return
        end

        for i = #buffer, 1, -1 do
                local segment = buffer[i]
                buffer[i] = nil
                if segment then
                        releaseSegment(segment)
                end
        end
end

local function clearPortalAnimation(state)
        if not state then
                return
        end

        recycleTrail(state.entrySourceTrail)
        recycleTrail(state.entryTrail)
        recycleTrail(state.exitTrail)
        state.entrySourceTrail = nil
        state.entryTrail = nil
        state.exitTrail = nil
        state.entryHole = nil
        state.exitHole = nil
end

local function smoothStep(edge0, edge1, value)
        if edge0 == nil or edge1 == nil or value == nil then
                return 0
        end

        if edge0 == edge1 then
                return value >= edge1 and 1 or 0
        end

        local t = (value - edge0) / (edge1 - edge0)
        if t < 0 then
                t = 0
        elseif t > 1 then
                t = 1
        end

        return t * t * (3 - 2 * t)
end

local function clearSeveredPieces()
	if not severedPieces then
		return
	end

	for i = #severedPieces, 1, -1 do
		local piece = severedPieces[i]
		if piece and piece.trail then
			recycleTrail(piece.trail)
			piece.trail = nil
		end
		severedPieces[i] = nil
	end
end

local function addSnakeBodyOccupancy(col, row)
        if not (col and row) then
                return
        end

        local column = snakeBodyOccupancy[col]
        if not column then
                column = {}
                snakeBodyOccupancy[col] = column
        end

        column[row] = (column[row] or 0) + 1
end

local function isCellOccupiedBySnakeBody(col, row)
        if not (col and row) then
                return false
        end

        local column = snakeBodyOccupancy[col]
        if not column then
                return false
        end

        return (column[row] or 0) > 0
end

local stencilCircleX, stencilCircleY, stencilCircleRadius = 0, 0, 0
local function drawStencilCircle()
        love.graphics.circle("fill", stencilCircleX, stencilCircleY, stencilCircleRadius)
end

local clippedHeadX, clippedHeadY, clipCenterX, clipCenterY, clipRadiusValue
local function getClippedHeadPosition()
        if not (clippedHeadX and clippedHeadY) then
                return clippedHeadX, clippedHeadY
        end

        local radius = clipRadiusValue or 0
        if radius > 0 then
                local dx = clippedHeadX - (clipCenterX or 0)
                local dy = clippedHeadY - (clipCenterY or 0)
                if dx * dx + dy * dy < radius * radius then
                        return nil, nil
                end
        end

        return clippedHeadX, clippedHeadY
end

local currentHeadOwner = nil
local function getOwnerHead()
        if currentHeadOwner then
                return currentHeadOwner:getHead()
        end

        return nil, nil
end

local activeTrailForHead = nil
local function getActiveTrailHead()
        local trailData = activeTrailForHead
        if not trailData then
                return nil, nil
        end

        local headSeg = trailData[1]
        if not headSeg then
                return nil, nil
        end

        return headSeg.drawX or headSeg.x, headSeg.drawY or headSeg.y
end

local function assignDirection(target, x, y)
        if not target then
                return
        end

	target.x = x
	target.y = y
end

local DEV_ASSIST_ENABLED_COLOR = {0.72, 0.94, 1.0, 1}
local DEV_ASSIST_DISABLED_COLOR = {1.0, 0.7, 0.68, 1}
local DEV_ASSIST_FLOATING_TEXT_OPTIONS = {
        scale = 1.1,
        popScaleFactor = 1.28,
        popDuration = 0.28,
        wobbleMagnitude = 0.12,
        glow = {
                color = {0.72, 0.94, 1.0, 0.45},
                magnitude = 0.35,
                frequency = 3.2,
        },
        shadow = {
                color = {0, 0, 0, 0.65},
                offset = {0, 2},
                blur = 1.5,
        },
}

local SHIELD_DAMAGE_FLOATING_TEXT_COLOR = {1, 0.78, 0.68, 1}
local SHIELD_DAMAGE_FLOATING_TEXT_OPTIONS = {
        scale = 1.08,
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

-- Shared burst configuration to avoid allocations when trimming segments.
local LOSE_SEGMENTS_DEFAULT_BURST_COLOR = {1, 0.8, 0.4, 1}
local LOSE_SEGMENTS_SAW_BURST_COLOR = {1, 0.6, 0.3, 1}
local LOSE_SEGMENTS_BURST_OPTIONS = {
        count = 0,
        speed = 120,
        speedVariance = 46,
        life = 0.42,
        size = 4,
        color = LOSE_SEGMENTS_DEFAULT_BURST_COLOR,
        spread = pi * 2,
        drag = 3.1,
        gravity = 220,
        fadeTo = 0,
}

local SHIELD_BREAK_PARTICLE_OPTIONS = {
        count = 16,
        speed = 170,
        speedVariance = 90,
        life = 0.48,
        size = 5,
        color = {1, 0.46, 0.32, 1},
        spread = pi * 2,
        angleJitter = pi,
        drag = 3.2,
        gravity = 280,
        fadeTo = 0.05,
}

local SHIELD_BLOOD_PARTICLE_OPTIONS = {
        dirX = 0,
        dirY = -1,
        spread = pi * 0.65,
        count = 10,
        dropletCount = 6,
        speed = 210,
        speedVariance = 80,
        life = 0.5,
        size = 3.6,
        gravity = 340,
        fadeTo = 0.06,
}

local function announceDeveloperAssistChange(enabled)
	if not (FloatingText and FloatingText.add) then
		return
	end

	local message = enabled and "DEV ASSIST ENABLED" or "DEV ASSIST DISABLED"
	local hx, hy
	if Snake.getHead then
		hx, hy = Snake:getHead()
	end
	if not (hx and hy) then
		hx = (screenW or 0) * 0.5
		hy = (screenH or 0) * 0.45
	end

	hy = (hy or 0) - 80

	local font = UI and UI.fonts and (UI.fonts.prompt or UI.fonts.button)
        local color = enabled and DEV_ASSIST_ENABLED_COLOR or DEV_ASSIST_DISABLED_COLOR
        local options = DEV_ASSIST_FLOATING_TEXT_OPTIONS
        local glowColor = options.glow.color
        glowColor[1] = color[1]
        glowColor[2] = color[2]
        glowColor[3] = color[3]

        FloatingText:add(message, hx, hy, color, 1.6, nil, font, options)
end

local SEVERED_TAIL_LIFE = 0.9
local SEVERED_TAIL_FADE_DURATION = 0.35

local SEGMENT_SIZE = SnakeUtils.SEGMENT_SIZE
local SEGMENT_SPACING = SnakeUtils.SEGMENT_SPACING
-- distance travelled since last grid snap (in world units)
local moveProgress = 0
local POP_DURATION = SnakeUtils.POP_DURATION
local SHIELD_FLASH_DURATION = 0.3
local HAZARD_GRACE_DURATION = 0.12 -- brief invulnerability window after surviving certain hazards
local DAMAGE_FLASH_DURATION = 0.45
-- keep polyline spacing stable for rendering
local SAMPLE_STEP = SEGMENT_SPACING * 0.1  -- 4 samples per tile is usually enough
-- movement baseline + modifiers
Snake.baseSpeed   = 240 -- pick a sensible default (units you already use)
Snake.speedMult   = 1.0 -- stackable multiplier (upgrade-friendly)
Snake.shields = 0 -- shield protection: number of hits the snake can absorb
Snake.extraGrowth = 0
Snake.shieldFlashTimer = 0
Snake.stoneSkinSawGrace = 0
Snake.dash = nil
Snake.timeDilation = nil
Snake.chronoWard = nil
Snake.hazardGraceTimer = 0
Snake.chronospiral = nil
Snake.abyssalCatalyst = nil
Snake.phoenixEcho = nil
Snake.eventHorizon = nil
Snake.stormchaser = nil
Snake.titanblood = nil
Snake.temporalAnchor = nil
Snake.quickFangs = nil
Snake.phaseDisruptor = nil

local function resolveTimeDilationScale(primary, secondary)
	local scale = 1

	if primary and primary.active then
		local primaryScale = primary.timeScale or 1
		if not (primaryScale and primaryScale > 0) then
			primaryScale = 0.05
		end
		scale = primaryScale
	end

	if secondary and secondary.active then
		local secondaryScale = secondary.timeScale or 1
		if not (secondaryScale and secondaryScale > 0) then
			secondaryScale = 0.05
		end
		if secondaryScale < scale then
			scale = secondaryScale
		end
	end

	return scale
end

-- getters / mutators (safe API for upgrades)
function Snake:getSpeed()
	local speed = (self.baseSpeed or 1) * (self.speedMult or 1)
	local scale = resolveTimeDilationScale(self.timeDilation, self.chronoWard)
	if scale ~= 1 then
		speed = speed * scale
	end

	return speed
end

function Snake:addSpeedMultiplier(mult)
	self.speedMult = (self.speedMult or 1) * (mult or 1)
end

function Snake:addShields(n)
	n = n or 1
	local previous = self.shields or 0
	local updated = previous + n
	if updated < 0 then
		updated = 0
	end
	self.shields = updated

	if n ~= 0 then
		UI:setShields(self.shields)
	end

end

function Snake:consumeShield()
	if developerAssistEnabled then
		self.shieldFlashTimer = SHIELD_FLASH_DURATION
		UI:setShields(self.shields or 0, {silent = true})
		return true
	end

	if (self.shields or 0) > 0 then
		self.shields = self.shields - 1
		self.shieldFlashTimer = SHIELD_FLASH_DURATION
		UI:setShields(self.shields)
		SessionStats:add("shieldsSaved", 1)
		return true
	end
	return false
end

function Snake:resetModifiers()
	self.speedMult    = 1.0
	self.shields = 0
	self.extraGrowth  = 0
	self.shieldFlashTimer = 0
        self.stoneSkinSawGrace = 0
	self.dash = nil
	self.timeDilation = nil
	self.adrenaline = nil
	self.hazardGraceTimer = 0
	self.chronospiral = nil
	self.abyssalCatalyst = nil
	self.phoenixEcho = nil
	self.eventHorizon = nil
	self.stormchaser = nil
	self.titanblood = nil
	self.temporalAnchor = nil
	self.quickFangs = nil
	self.phaseDisruptor = nil
	self.zephyrCoils = nil
	self.spectralHarvest = nil
	self.stoneSkinVisual = nil
       self.speedVisual = nil
       UI:setShields(self.shields or 0, {silent = true, immediate = true})
end

function Snake:setQuickFangsStacks(count)
	count = max(0, floor((count or 0) + 0.0001))
	local state = self.quickFangs
	local previous = state and (state.stacks or 0) or 0

	if count > 0 then
		if not state then
			state = {intensity = 0, baseTarget = 0, time = 0, stacks = 0, flash = 0}
			self.quickFangs = state
		end

		state.stacks = count
		state.baseTarget = min(0.65, 0.32 + 0.11 * min(count, 4))
		state.target = state.baseTarget
		if count > previous then
			state.intensity = max(state.intensity or 0, 0.55)
			state.flash = min(1.0, (state.flash or 0) + 0.7)
		end
	elseif state then
		state.stacks = 0
		state.baseTarget = 0
		state.target = 0
	end

	if self.quickFangs then
		local data = self.quickFangs
		if (data.stacks or 0) <= 0 and (data.intensity or 0) <= 0.01 then
			self.quickFangs = nil
		end
	end
end

function Snake:setZephyrCoilsStacks(count)
	count = max(0, floor((count or 0) + 0.0001))

	local state = self.zephyrCoils
	if not state and count <= 0 then
		return
	end

	if not state then
		state = {stacks = 0, intensity = 0, target = 0, time = 0}
		self.zephyrCoils = state
	end

	state.stacks = count
	if count > 0 then
		state.target = min(1, 0.45 + 0.2 * min(count, 3))
		if (state.intensity or 0) < 0.25 then
			state.intensity = max(state.intensity or 0, 0.25)
		end
	else
		state.target = 0
	end
end

function Snake:setChronospiralActive(active)
	if active then
		local state = self.chronospiral
		if not state then
			state = {intensity = 0, target = 1, spin = 0}
			self.chronospiral = state
		end
		state.target = 1
		state.active = true
	else
		local state = self.chronospiral
		if state then
			state.target = 0
			state.active = false
		end
	end
end

function Snake:setAbyssalCatalystStacks(count)
	count = max(0, floor((count or 0) + 0.0001))
	local state = self.abyssalCatalyst

	if count > 0 then
		if not state then
			state = {intensity = 0, target = 0, time = 0}
			self.abyssalCatalyst = state
		end
		state.stacks = count
		state.target = min(1, 0.55 + 0.18 * min(count, 3))
	elseif state then
		state.stacks = 0
		state.target = 0
	end

	if self.abyssalCatalyst and (self.abyssalCatalyst.stacks or 0) <= 0 and (self.abyssalCatalyst.intensity or 0) <= 0 then
		self.abyssalCatalyst = nil
	end
end

function Snake:setPhoenixEchoCharges(count, options)
	count = max(0, floor((count or 0) + 0.0001))
	options = options or {}

	local state = self.phoenixEcho
	if not state and (count > 0 or options.triggered or options.instantIntensity) then
		state = {intensity = 0, target = 0, time = 0, flareTimer = 0, flareDuration = 1.2, charges = 0}
		self.phoenixEcho = state
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
		self.phoenixEcho = nil
	end
end

function Snake:setSpectralHarvestReady(active, options)
	options = options or {}
	local state = self.spectralHarvest

	if active then
		if not state then
			state = {intensity = 0, target = 0, time = 0, burst = 0, echo = 0}
			self.spectralHarvest = state
		end
		state.ready = true
		state.target = max(state.target or 0, 1)
		if options.pulse then
			state.burst = max(state.burst or 0, options.pulse)
		end
		if options.instantIntensity then
			state.intensity = max(state.intensity or 0, options.instantIntensity)
		end
	elseif state then
		state.ready = false
		state.target = 0
		if options.pulse then
			state.burst = max(state.burst or 0, options.pulse)
		end
	elseif options and options.ensure then
		self.spectralHarvest = {ready = false, intensity = 0, target = 0, time = 0, burst = 0, echo = 0}
	end
end

function Snake:triggerSpectralHarvest(options)
	options = options or {}
	local state = self.spectralHarvest
	if not state then
		state = {intensity = 0, target = 0, time = 0, burst = 0, echo = 0}
		self.spectralHarvest = state
	end

	state.ready = false
	state.target = 0
	state.burst = max(state.burst or 0, options.flash or 1)
	state.echo = max(state.echo or 0, options.echo or 1)
	if options.instantIntensity then
		state.intensity = max(state.intensity or 0, options.instantIntensity)
	end
end

function Snake:setEventHorizonActive(active)
	if active then
		local state = self.eventHorizon
		if not state then
			state = {intensity = 0, target = 1, spin = 0, time = 0}
			self.eventHorizon = state
		end
		state.target = 1
		state.active = true
	else
		local state = self.eventHorizon
		if state then
			state.target = 0
			state.active = false
		end
	end
end

function Snake:setPhaseDisruptorActive(active)
	if active then
		self.phaseDisruptor = true
	else
		self.phaseDisruptor = nil
	end
end

function Snake:setTitanbloodStacks(count)
	count = max(0, floor((count or 0) + 0.0001))
	local state = self.titanblood

	if count > 0 then
		if not state then
			state = {intensity = 0, target = 0, time = 0}
			self.titanblood = state
		end
		state.stacks = count
		state.target = min(1, 0.5 + 0.18 * min(count, 3))
	elseif state then
		state.stacks = 0
		state.target = 0
	end

	if self.titanblood and (self.titanblood.stacks or 0) <= 0 and (self.titanblood.intensity or 0) <= 0 then
		self.titanblood = nil
	end
end

function Snake:onShieldConsumed(x, y, cause)
	if (not x or not y) and self.getHead then
		x, y = self:getHead()
	end

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		Upgrades:notify("shieldConsumed", {
			x = x,
			y = y,
			cause = cause or "unknown",
		})
	end
end

function Snake:addStoneSkinSawGrace(n)
	n = n or 1
	if n <= 0 then return end
	self.stoneSkinSawGrace = (self.stoneSkinSawGrace or 0) + n

	local visual = self.stoneSkinVisual
	if not visual then
		visual = {intensity = 0, target = 0, flash = 0, time = 0, charges = 0}
		self.stoneSkinVisual = visual
	end

	visual.charges = self.stoneSkinSawGrace or 0
	visual.target = min(1, 0.45 + 0.18 * min(visual.charges, 4))
	visual.intensity = max(visual.intensity or 0, 0.32 + 0.12 * min(visual.charges, 3))
	visual.flash = max(visual.flash or 0, 0.75)
end

function Snake:consumeStoneSkinSawGrace()
	if (self.stoneSkinSawGrace or 0) > 0 then
		self.stoneSkinSawGrace = self.stoneSkinSawGrace - 1
		self.shieldFlashTimer = SHIELD_FLASH_DURATION

		if self.stoneSkinVisual then
			local visual = self.stoneSkinVisual
			visual.charges = self.stoneSkinSawGrace or 0
			visual.target = min(1, 0.45 + 0.18 * min(visual.charges, 4))
			visual.flash = max(visual.flash or 0, 1.0)
		end

		return true
	end
	return false
end

function Snake:isHazardGraceActive()
	return (self.hazardGraceTimer or 0) > 0
end

function Snake:beginHazardGrace(duration)
	local grace = duration or HAZARD_GRACE_DURATION
	if not (grace and grace > 0) then
		return
	end

	local current = self.hazardGraceTimer or 0
	if grace > current then
		self.hazardGraceTimer = grace
	end
end

function Snake:onDamageTaken(cause, info)
	info = info or {}

	local pushX = info.pushX or 0
	local pushY = info.pushY or 0
	local translated = false

	if pushX ~= 0 or pushY ~= 0 then
		self:translate(pushX, pushY)
		translated = true
	end

	if info.snapX and info.snapY and not translated then
		self:setHeadPosition(info.snapX, info.snapY)
	end

	local dirX = info.dirX
	local dirY = info.dirY
	if (dirX and dirX ~= 0) or (dirY and dirY ~= 0) then
		self:setDirectionVector(dirX or 0, dirY or 0)
	end

	local grace = info.grace or (HAZARD_GRACE_DURATION * 2)
	if grace and grace > 0 then
		self:beginHazardGrace(grace)
	end

	local headX, headY = self:getHead()
	if headX and headY then
		local centerX = headX + SEGMENT_SIZE * 0.5
		local centerY = headY + SEGMENT_SIZE * 0.5

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
                else
                        local faceX = direction and direction.x or 0
                        local faceY = direction and direction.y or -1
                        local faceMag = sqrt(faceX * faceX + faceY * faceY)
                        if faceMag > 1e-4 then
                                burstDirX = -faceX / faceMag
                                burstDirY = -faceY / faceMag
                        end
                end

                if Particles and Particles.spawnBurst then
                        Particles:spawnBurst(centerX, centerY, SHIELD_BREAK_PARTICLE_OPTIONS)
                end

                local shielded = info.damage ~= nil and info.damage <= 0
                if Particles and Particles.spawnBlood and not shielded then
                        SHIELD_BLOOD_PARTICLE_OPTIONS.dirX = burstDirX
                        SHIELD_BLOOD_PARTICLE_OPTIONS.dirY = burstDirY
                        Particles:spawnBlood(centerX, centerY, SHIELD_BLOOD_PARTICLE_OPTIONS)
                end

		if FloatingText and FloatingText.add then
			local inflicted = info.inflictedDamage or info.damage
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

	self.shieldFlashTimer = SHIELD_FLASH_DURATION
	self.damageFlashTimer = DAMAGE_FLASH_DURATION
end

-- >>> Small integration note:
-- Inside your snake:update(dt) where you compute movement, replace any hard-coded speed use with:
-- local speed = Snake:getSpeed()
-- and then use `speed` for position updates. This gives upgrades an immediate effect.

-- helpers
local function snapToCenter(v)
	return (floor(v / SEGMENT_SPACING) + 0.5) * SEGMENT_SPACING
end

local function toCell(x, y)
        if not (x and y) then
                return nil, nil
        end

        if Arena and Arena.getTileFromWorld then
                return Arena:getTileFromWorld(x, y)
        end

        local tileSize = Arena and Arena.tileSize or SEGMENT_SPACING or 1
        if tileSize == 0 then
                tileSize = 1
        end

        local offsetX = (Arena and Arena.x) or 0
        local offsetY = (Arena and Arena.y) or 0
        local normalizedCol = ((x - offsetX) / tileSize) + TILE_COORD_EPSILON
        local normalizedRow = ((y - offsetY) / tileSize) + TILE_COORD_EPSILON
        local col = floor(normalizedCol) + 1
        local row = floor(normalizedRow) + 1

        if Arena then
                local cols = Arena.cols or col
                local rows = Arena.rows or row
                col = max(1, min(cols, col))
                row = max(1, min(rows, row))
        end

        return col, row
end

local function rebuildOccupancyFromTrail(headColOverride, headRowOverride)
        if not ensureOccupancyGrid() then
                resetTrackedSnakeCells()
                clearSnakeBodyOccupancy()
                headOccupancyCol = nil
                headOccupancyRow = nil
                return
        end

        clearSnakeOccupiedCells()
        clearSnakeBodyOccupancy()

        if not trail then
                headOccupancyCol = nil
                headOccupancyRow = nil
                return
        end

        local assignedHeadCol, assignedHeadRow = nil, nil
        local headCellCleared = false

        for i = 1, #trail do
                local segment = trail[i]
                if segment then
                        local x, y = segment.drawX, segment.drawY
                        if x and y then
                                local col, row = toCell(x, y)
                                if col and row then
                                        if i == 1 then
                                                if headColOverride and headRowOverride then
                                                        col, row = headColOverride, headRowOverride
                                                end
                                                assignedHeadCol, assignedHeadRow = col, row
                                        end
                                        recordSnakeOccupiedCell(col, row)
                                        if i > 1 then
                                                if assignedHeadCol and assignedHeadRow and not headCellCleared then
                                                        if col ~= assignedHeadCol or row ~= assignedHeadRow then
                                                                headCellCleared = true
                                                                addSnakeBodyOccupancy(col, row)
                                                        end
                                                else
                                                        addSnakeBodyOccupancy(col, row)
                                                end
                                        end
                                end
                        end
                end
        end

        headOccupancyCol = assignedHeadCol
        headOccupancyRow = assignedHeadRow
end

local function findCircleIntersection(px, py, qx, qy, cx, cy, radius)
	local dx = qx - px
	local dy = qy - py
	local fx = px - cx
	local fy = py - cy

	local a = dx * dx + dy * dy
	if a == 0 then
		return nil, nil
	end

	local b = 2 * (fx * dx + fy * dy)
	local c = fx * fx + fy * fy - radius * radius
	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return nil, nil
	end

    discriminant = sqrt(discriminant)
	local t1 = (-b - discriminant) / (2 * a)
	local t2 = (-b + discriminant) / (2 * a)

	local t
	if t1 >= 0 and t1 <= 1 then
		t = t1
	elseif t2 >= 0 and t2 <= 1 then
		t = t2
	end

	if not t then
		return nil, nil
	end

	return px + t * dx, py + t * dy
end

local function normalizeDirection(dx, dy)
    local len = sqrt(dx * dx + dy * dy)
	if len == 0 then
		return 0, 0
	end
	return dx / len, dy / len
end

local function closestPointOnSegment(px, py, ax, ay, bx, by)
	if not (px and py and ax and ay and bx and by) then
		return nil, nil, huge, 0
	end

	local abx = bx - ax
	local aby = by - ay
	local abLenSq = abx * abx + aby * aby
	if abLenSq <= 1e-6 then
		local dx = px - ax
		local dy = py - ay
		return ax, ay, dx * dx + dy * dy, 0
	end

	local apx = px - ax
	local apy = py - ay
	local t = (apx * abx + apy * aby) / abLenSq
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end

	local cx = ax + abx * t
	local cy = ay + aby * t
	local dx = px - cx
	local dy = py - cy

	return cx, cy, dx * dx + dy * dy, t
end

local function copySegmentData(segment)
        if not segment then
                return nil
        end

        local copy = acquireSegment()
        copy.drawX = segment.drawX
        copy.drawY = segment.drawY
        copy.dirX = segment.dirX
        copy.dirY = segment.dirY
        copy.x = segment.x
        copy.y = segment.y
        copy.fruitMarker = segment.fruitMarker
        copy.fruitMarkerX = segment.fruitMarkerX
        copy.fruitMarkerY = segment.fruitMarkerY

        return copy
end

local function computeTrailLength(trailData)
	if not trailData then
		return 0
	end

	local total = 0
        for i = 2, #trailData do
                local prev = trailData[i - 1]
                local curr = trailData[i]
                local ax, ay = prev and prev.drawX, prev and prev.drawY
                local bx, by = curr and curr.drawX, curr and curr.drawY
                if ax and ay and bx and by then
                        local dx = bx - ax
                        local dy = by - ay
                        total = total + sqrt(dx * dx + dy * dy)
                end
        end

	return total
end

local function sliceTrailByLength(sourceTrail, maxLength, destination)
        local result = destination or {}
        local previousCount = #result
        local count = 0

        if not sourceTrail or #sourceTrail == 0 then
                releaseSegmentRange(result, 1)
                return result
        end

        if previousCount >= 1 then
                local existing = result[1]
                if existing then
                        releaseSegment(existing)
                end
        end
        local first = copySegmentData(sourceTrail[1]) or acquireSegment()
        count = 1
        result[count] = first

        if not (maxLength and maxLength > 0) then
                releaseSegmentRange(result, count + 1)
                return result
        end

        local accumulated = 0
        for i = 2, #sourceTrail do
                local prev = sourceTrail[i - 1]
                local curr = sourceTrail[i]
                local px, py = prev and prev.drawX, prev and prev.drawY
                local cx, cy = curr and curr.drawX, curr and curr.drawY
                if not (px and py and cx and cy) then
                        break
                end

                local dx = cx - px
                local dy = cy - py
                local segLen = sqrt(dx * dx + dy * dy)

                if segLen <= 1e-6 then
                        count = count + 1
                        if count <= previousCount then
                                local existing = result[count]
                                if existing then
                                        releaseSegment(existing)
                                end
                        end
                        result[count] = copySegmentData(curr)
                else
                        if accumulated + segLen >= maxLength then
                                local remaining = maxLength - accumulated
                                local t = remaining / segLen
                                if t < 0 then
                                        t = 0
                                elseif t > 1 then
                                        t = 1
                                end
                                local x = px + dx * t
                                local y = py + dy * t
                                if count + 1 <= previousCount then
                                        local existing = result[count + 1]
                                        if existing then
                                                releaseSegment(existing)
                                        end
                                end
                                local segCopy = copySegmentData(curr) or acquireSegment()
                                segCopy.drawX = x
                                segCopy.drawY = y
                                count = count + 1
                                result[count] = segCopy
                                releaseSegmentRange(result, count + 1)
                                return result
                        end

                        accumulated = accumulated + segLen
                        count = count + 1
                        if count <= previousCount then
                                local existing = result[count]
                                if existing then
                                        releaseSegment(existing)
                                end
                        end
                        result[count] = copySegmentData(curr)
                end
        end

        releaseSegmentRange(result, count + 1)

        return result
end

local function cloneTailFromIndex(startIndex, entryX, entryY)
	if not trail or #trail == 0 then
		return {}
	end

	local index = max(1, min(startIndex or 1, #trail))
	local clone = {}

	for i = index, #trail do
		local segCopy = copySegmentData(trail[i]) or {}
		if i == index then
			segCopy.drawX = entryX or segCopy.drawX
			segCopy.drawY = entryY or segCopy.drawY
		end
		clone[#clone + 1] = segCopy
	end

	return clone
end

local function findPortalEntryIndex(entryX, entryY)
	if not trail or #trail == 0 then
		return 1
	end

	local bestIndex = 1
	local bestDist = huge

	for i = 1, #trail - 1 do
		local segA = trail[i]
		local segB = trail[i + 1]
		local ax, ay = segA and segA.drawX, segA and segA.drawY
		local bx, by = segB and segB.drawX, segB and segB.drawY
		if ax and ay and bx and by then
			local _, _, distSq = closestPointOnSegment(entryX, entryY, ax, ay, bx, by)
			if distSq < bestDist then
				bestDist = distSq
				bestIndex = i + 1
			end
		end
	end

	if bestIndex > #trail then
		bestIndex = #trail
	end

	return bestIndex
end

local function trimHoleSegments(hole)
	if not hole or not trail or #trail == 0 then
		return
	end

	local hx, hy = hole.x, hole.y
	local radius = hole.radius or 0
	if radius <= 0 then
		return
	end

	local workingTrail = {}
	for i = 1, #trail do
		local seg = trail[i]
		if not seg then break end
		workingTrail[i] = {
			drawX = seg.drawX,
			drawY = seg.drawY,
			dirX = seg.dirX,
			dirY = seg.dirY,
		}
	end

	local radiusSq = radius * radius
	local consumed = 0
	local lastInsideX, lastInsideY = nil, nil
	local lastInsideDirX, lastInsideDirY = nil, nil
	local removedAny = false
	local i = 1

	while i <= #workingTrail do
		local seg = workingTrail[i]
		local x = seg and seg.drawX
		local y = seg and seg.drawY

		if not (x and y) then
			break
		end

		local dx = x - hx
		local dy = y - hy
		if dx * dx + dy * dy <= radiusSq then
			removedAny = true
			lastInsideX = x
			lastInsideY = y
			lastInsideDirX = seg.dirX
			lastInsideDirY = seg.dirY

			local nextSeg = workingTrail[i + 1]
			if nextSeg then
				local nx, ny = nextSeg.drawX, nextSeg.drawY
				if nx and ny then
					local segDx = nx - x
					local segDy = ny - y
					consumed = consumed + sqrt(segDx * segDx + segDy * segDy)
				end
			end

			remove(workingTrail, i)
		else
			break
		end
	end

	local newHead = workingTrail[1]
	if removedAny and newHead and lastInsideX and lastInsideY then
		local oldDx = newHead.drawX - lastInsideX
		local oldDy = newHead.drawY - lastInsideY
		local oldLen = sqrt(oldDx * oldDx + oldDy * oldDy)
		if oldLen > 0 then
			consumed = consumed - oldLen
		end

		local ix, iy = findCircleIntersection(lastInsideX, lastInsideY, newHead.drawX, newHead.drawY, hx, hy, radius)
		if ix and iy then
			local newDx = ix - lastInsideX
			local newDy = iy - lastInsideY
			local newLen = sqrt(newDx * newDx + newDy * newDy)
			consumed = consumed + newLen
			newHead.drawX = ix
			newHead.drawY = iy
		else
			-- fallback: if no intersection, clamp head to previous inside point
			newHead.drawX = lastInsideX
			newHead.drawY = lastInsideY
		end
	end

	hole.consumedLength = consumed

	local totalLength = max(0, (segmentCount or 0) * SEGMENT_SPACING)
	if totalLength <= 1e-4 then
		hole.fullyConsumed = true
	else
		local epsilon = SEGMENT_SPACING * 0.1
		if consumed >= totalLength - epsilon then
			hole.fullyConsumed = true
		else
			hole.fullyConsumed = false
		end
	end

	if newHead and newHead.drawX and newHead.drawY then
		hole.entryPointX = newHead.drawX
		hole.entryPointY = newHead.drawY
	elseif lastInsideX and lastInsideY then
		hole.entryPointX = lastInsideX
		hole.entryPointY = lastInsideY
	end

	if lastInsideDirX and lastInsideDirY then
		hole.entryDirX, hole.entryDirY = normalizeDirection(lastInsideDirX, lastInsideDirY)
	end
end

local isGluttonsWakeActive

local function trimTrailToSegmentLimit()
	if not trail or #trail == 0 then
		return
	end

	local consumedLength = (descendingHole and descendingHole.consumedLength) or 0
	local maxLen = max(0, segmentCount * SEGMENT_SPACING - consumedLength)

        if maxLen <= 0 then
                recycleTrail(trail)
                trail = {}
                return
        end

        local traveled = 0
        local i = 2
        local gluttonsWakeActive = isGluttonsWakeActive()
        while i <= #trail do
                local prev = trail[i - 1]
                local seg = trail[i]
                local px, py = prev and (prev.drawX or prev.x), prev and (prev.drawY or prev.y)
                local sx, sy = seg and (seg.drawX or seg.x), seg and (seg.drawY or seg.y)

                if not (px and py and sx and sy) then
                        crystallizeGluttonsWakeSegments(trail, i, #trail, gluttonsWakeActive)
                        releaseSegmentRange(trail, i)
                        break
                end

                local dx = px - sx
                local dy = py - sy
                local segLen = sqrt(dx * dx + dy * dy)

                if segLen <= 0 then
                        if gluttonsWakeActive then
                                spawnGluttonsWakeRock(trail[i])
                        end
                        local removed = trail[i]
                        if removed then
                                releaseSegment(removed)
                        end
                        remove(trail, i)
                else
                        if traveled + segLen > maxLen then
                                local excess = traveled + segLen - maxLen
                                local t = 1 - (excess / segLen)
                                local tailX = px - dx * t
                                local tailY = py - dy * t

                                crystallizeGluttonsWakeSegments(trail, i + 1, #trail, gluttonsWakeActive)
                                releaseSegmentRange(trail, i + 1)

                                seg.drawX = tailX
                                seg.drawY = tailY
                                if not seg.dirX or not seg.dirY then
                                        seg.dirX = direction.x
					seg.dirY = direction.y
				end
				break
			else
				traveled = traveled + segLen
				i = i + 1
			end
		end
	end
end

local function drawDescendingIntoHole(hole)
	if not hole then
		return
	end

	local consumed = hole.consumedLength or 0
	local depth = hole.renderDepth or 0
	if consumed <= 0 and depth <= 0 then
		return
	end

	local hx = hole.x or 0
	local hy = hole.y or 0
	local entryX = hole.entryPointX or hx
	local entryY = hole.entryPointY or hy

        local dirX, dirY = hole.entryDirX or 0, hole.entryDirY or 0
        local dirLen = sqrt(dirX * dirX + dirY * dirY)
        if dirLen <= 1e-4 then
                dirX = hx - entryX
                dirY = hy - entryY
                dirLen = sqrt(dirX * dirX + dirY * dirY)
        end

	if dirLen <= 1e-4 then
		dirX, dirY = 0, -1
	else
		dirX, dirY = dirX / dirLen, dirY / dirLen
	end

	local toCenterX = hx - entryX
	local toCenterY = hy - entryY
	if toCenterX * dirX + toCenterY * dirY < 0 then
		dirX, dirY = -dirX, -dirY
	end

	local bodyColor = SnakeCosmetics:getBodyColor() or {1, 1, 1, 1}
	local r = bodyColor[1] or 1
	local g = bodyColor[2] or 1
	local b = bodyColor[3] or 1
	local a = bodyColor[4] or 1

	local baseRadius = SEGMENT_SIZE * 0.5
	local holeRadius = max(baseRadius, hole.radius or baseRadius * 1.6)
	local depthTarget = min(1, consumed / (holeRadius + SEGMENT_SPACING * 0.75))
	local renderDepth = max(depth, depthTarget)

	local steps = max(2, min(7, floor((consumed + SEGMENT_SPACING * 0.4) / (SEGMENT_SPACING * 0.55)) + 2))

	local totalLength = (segmentCount or 0) * SEGMENT_SPACING
	local completion = 0
	if totalLength > 1e-4 then
		completion = min(1, consumed / totalLength)
	end
	local globalVisibility = max(0, 1 - completion)

	local perpX, perpY = -dirY, dirX
	local wobble = 0
	if hole.time then
		wobble = math.sin(hole.time * 4.6) * 0.35
	end

	love.graphics.setLineWidth(2)

	for layer = 0, steps - 1 do
		local layerFrac = (layer + 0.6) / steps
		local layerDepth = min(1, renderDepth * (0.35 + 0.65 * layerFrac))
		local depthFade = 1 - layerDepth
		local visibility = depthFade * depthFade * globalVisibility

		if visibility <= 1e-3 then
			break
		end

		local radius = baseRadius * (0.9 - 0.55 * layerDepth)
		radius = max(baseRadius * 0.2, radius)

		local sink = holeRadius * 0.35 * layerDepth
		local lateral = wobble * (0.4 + 0.25 * layerFrac) * depthFade
		local px = entryX + (hx - entryX) * layerDepth + dirX * sink + perpX * radius * lateral
		local py = entryY + (hy - entryY) * layerDepth + dirY * sink + perpY * radius * lateral

		local shade = 0.25 + 0.7 * visibility
		local shadeR = r * shade
		local shadeG = g * shade
		local shadeB = b * shade
		local alpha = a * (0.2 + 0.8 * visibility)
		love.graphics.setColor(shadeR, shadeG, shadeB, max(0, min(1, alpha)))
		love.graphics.circle("fill", px, py, radius)

		local outlineAlpha = 0.15 + 0.5 * visibility
		love.graphics.setColor(0, 0, 0, max(0, min(1, outlineAlpha)))
		love.graphics.circle("line", px, py, radius)

		if layer == 0 then
			local highlight = 0.45 * min(1, depthFade * 1.1) * globalVisibility
			if highlight > 0 then
				love.graphics.setColor(r, g, b, highlight)
				love.graphics.circle("line", px, py, radius * 0.75)
			end
		end
	end
	local coverAlpha = max(depth, renderDepth) * 0.55
	love.graphics.setColor(0, 0, 0, coverAlpha)
	love.graphics.circle("fill", hx, hy, holeRadius * (0.38 + 0.22 * renderDepth))

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function collectUpgradeVisuals(self)
        local visuals = self._upgradeVisualBuffer
        -- The returned table is reused every frame; treat it as read-only outside this function.
        if visuals then
                wipeTable(visuals)
        else
		visuals = {}
		self._upgradeVisualBuffer = visuals
	end

	local pool = self._upgradeVisualPool
	if not pool then
		pool = {}
		self._upgradeVisualPool = pool
	end

        local hasAny = false

        local function acquireEntry(key)
                local entry = pool[key]
                if not entry then
                        entry = {}
                        pool[key] = entry
                else
                        wipeTable(entry)
                end

                visuals[key] = entry
                hasAny = true

                return entry
        end

        local adrenaline = self.adrenaline
        if adrenaline and adrenaline.active and not adrenaline.suppressVisuals then
                local entry = acquireEntry("adrenaline")
                entry.active = true
                entry.timer = adrenaline.timer or 0
		entry.duration = adrenaline.duration or 0
	end

	local speedVisual = self.speedVisual
	if speedVisual and (((speedVisual.intensity or 0) > 0.01) or (speedVisual.target or 0) > 0) then
		local entry = acquireEntry("speedArcs")
		entry.intensity = speedVisual.intensity or 0
		entry.ratio = speedVisual.ratio or 0
		entry.time = speedVisual.time or 0
	end

	local quickFangs = self.quickFangs
	if quickFangs and (((quickFangs.intensity or 0) > 0.01) or (quickFangs.stacks or 0) > 0) then
		local entry = acquireEntry("quickFangs")
		entry.stacks = quickFangs.stacks or 0
		entry.intensity = quickFangs.intensity or 0
		entry.target = quickFangs.target or 0
		entry.speedRatio = quickFangs.speedRatio or 1
		entry.active = quickFangs.active or false
		entry.time = quickFangs.time or 0
		entry.flash = quickFangs.flash or 0
	end

	local zephyr = self.zephyrCoils
	if zephyr and (((zephyr.intensity or 0) > 0.01) or (zephyr.stacks or 0) > 0 or (zephyr.target or 0) > 0) then
		local entry = acquireEntry("zephyrCoils")
		entry.stacks = zephyr.stacks or 0
		entry.intensity = zephyr.intensity or 0
		entry.time = zephyr.time or 0
		entry.ratio = zephyr.speedRatio or (1 + 0.2 * min(1, max(0, zephyr.intensity or 0)))
		entry.hasBody = (segmentCount or 0) > 1
	end

	local timeDilation = self.timeDilation
	if timeDilation then
		local entry = acquireEntry("timeDilation")
		entry.active = timeDilation.active or false
		entry.timer = timeDilation.timer or 0
		entry.duration = timeDilation.duration or 0
		entry.cooldown = timeDilation.cooldown or 0
		entry.cooldownTimer = timeDilation.cooldownTimer or 0
	end

	local chronoWard = self.chronoWard
	if chronoWard and (((chronoWard.intensity or 0) > 1e-3) or chronoWard.active) then
		local entry = acquireEntry("chronoWard")
		entry.active = chronoWard.active or false
		entry.intensity = chronoWard.intensity or 0
		entry.time = chronoWard.time or 0
	end

	local temporalAnchor = self.temporalAnchor
	if temporalAnchor and (((temporalAnchor.intensity or 0) > 1e-3) or (temporalAnchor.target or 0) > 0) then
		local entry = acquireEntry("temporalAnchor")
		entry.intensity = temporalAnchor.intensity or 0
		entry.ready = temporalAnchor.ready or 0
		entry.active = temporalAnchor.active or false
		entry.time = temporalAnchor.time or 0
	end

	local dash = self.dash
	if dash then
		local entry = acquireEntry("dash")
		entry.active = dash.active or false
		entry.timer = dash.timer or 0
		entry.duration = dash.duration or 0
		entry.cooldown = dash.cooldown or 0
		entry.cooldownTimer = dash.cooldownTimer or 0
	end

	local chronospiral = self.chronospiral
	if chronospiral and ((chronospiral.intensity or 0) > 1e-3 or (chronospiral.target or 0) > 0) then
		local entry = acquireEntry("chronospiral")
		entry.intensity = chronospiral.intensity or 0
		entry.spin = chronospiral.spin or 0
	end

	local abyssal = self.abyssalCatalyst
	if abyssal and ((abyssal.intensity or 0) > 1e-3 or (abyssal.target or 0) > 0) then
		local entry = acquireEntry("abyssalCatalyst")
		entry.intensity = abyssal.intensity or 0
		entry.stacks = abyssal.stacks or 0
		entry.pulse = abyssal.pulse or abyssal.time or 0
	end

	local titanblood = self.titanblood
	if titanblood and ((titanblood.intensity or 0) > 1e-3 or (titanblood.target or 0) > 0) then
		local entry = acquireEntry("titanblood")
		entry.intensity = titanblood.intensity or 0
		entry.stacks = titanblood.stacks or 0
		entry.time = titanblood.time or 0
	end

	local stormchaser = self.stormchaser
	if stormchaser and ((stormchaser.intensity or 0) > 1e-3 or (stormchaser.target or 0) > 0) then
		local entry = acquireEntry("stormchaser")
		entry.intensity = stormchaser.intensity or 0
		entry.primed = stormchaser.primed or false
		entry.time = stormchaser.time or 0
	end

	local eventHorizon = self.eventHorizon
	if eventHorizon and ((eventHorizon.intensity or 0) > 1e-3 or (eventHorizon.target or 0) > 0) then
		local entry = acquireEntry("eventHorizon")
		entry.intensity = eventHorizon.intensity or 0
		entry.spin = eventHorizon.spin or 0
		entry.time = eventHorizon.time or 0
	end

	local phoenix = self.phoenixEcho
	if phoenix and (((phoenix.intensity or 0) > 1e-3) or (phoenix.charges or 0) > 0 or (phoenix.flareTimer or 0) > 0) then
		local entry = acquireEntry("phoenixEcho")
		local flare = 0
		local flareDuration = phoenix.flareDuration or 1.2
		if flareDuration > 0 and (phoenix.flareTimer or 0) > 0 then
			flare = min(1, phoenix.flareTimer / flareDuration)
		end
		entry.intensity = phoenix.intensity or 0
		entry.charges = phoenix.charges or 0
		entry.flare = flare
		entry.time = phoenix.time or 0
	end

	local stoneSkin = self.stoneSkinVisual
	if stoneSkin and (((stoneSkin.intensity or 0) > 0.01) or (stoneSkin.flash or 0) > 0 or (stoneSkin.charges or 0) > 0) then
		local entry = acquireEntry("stoneSkin")
		entry.intensity = stoneSkin.intensity or 0
		entry.flash = stoneSkin.flash or 0
		entry.charges = stoneSkin.charges or 0
		entry.time = stoneSkin.time or 0
	end

        local spectral = self.spectralHarvest
        if spectral and (((spectral.intensity or 0) > 0.01) or (spectral.burst or 0) > 0 or (spectral.echo or 0) > 0 or spectral.ready) then
                local entry = acquireEntry("spectralHarvest")
                entry.intensity = spectral.intensity or 0
                entry.burst = spectral.burst or 0
                entry.echo = spectral.echo or 0
                entry.ready = spectral.ready or false
                entry.time = spectral.time or 0
        end

        if self.phaseDisruptor then
                local entry = acquireEntry("face")
                entry.phaseDisruptor = true
        end

        if hasAny then
                return visuals
        end

        return nil
end

local function getUpgradeVisualsForDraw(self)
	local visuals = collectUpgradeVisuals(self)
	if visuals then
		return visuals
	end

	if not self.phaseDisruptor then
		return nil
	end

	local fallback = self._fallbackUpgradeVisuals
	if fallback then
		wipeTable(fallback)
	else
		fallback = {}
		self._fallbackUpgradeVisuals = fallback
	end

	local faceEntry = self._fallbackFaceVisual
	if faceEntry then
		wipeTable(faceEntry)
	else
		faceEntry = {}
		self._fallbackFaceVisual = faceEntry
	end

	faceEntry.phaseDisruptor = true
	fallback.face = faceEntry

	return fallback
end

-- Build initial trail aligned to CELL CENTERS
local function buildInitialTrail()
        local t = {}
        local midCol = floor(Arena.cols / 2)
        local midRow = floor(Arena.rows / 2)
        local startX, startY = Arena:getCenterOfTile(midCol, midRow)

        for i = 0, segmentCount - 1 do
                local cx = startX - i * SEGMENT_SPACING * direction.x
                local cy = startY - i * SEGMENT_SPACING * direction.y
                local segment = acquireSegment()
                segment.drawX = cx
                segment.drawY = cy
                segment.dirX = direction.x
                segment.dirY = direction.y
                t[#t + 1] = segment
        end
        return t
end

function Snake:load(w, h)
	screenW, screenH = w, h
	assignDirection(direction, 1, 0)
	assignDirection(pendingDir, 1, 0)
	segmentCount = 1
        popTimer = 0
        moveProgress = 0
        isDead = false
        self.shieldFlashTimer = 0
        self.hazardGraceTimer = 0
        self.damageFlashTimer = 0
        recycleTrail(trail)
        trail = buildInitialTrail()
        descendingHole = nil
        clearSeveredPieces()
        severedPieces = {}
        clearPortalAnimation(portalAnimation)
        portalAnimation = nil
        local stride = (Arena and Arena.rows or 0) + 16
        if stride <= 0 then
                stride = 64
        end
        cellKeyStride = stride
        rebuildOccupancyFromTrail()
end

local function getUpgradesModule()
        return package.loaded["upgrades"]
end

isGluttonsWakeActive = function()
        local Upgrades = getUpgradesModule()
        if not (Upgrades and Upgrades.getEffect) then
                return false
        end

        local effect = Upgrades:getEffect("gluttonsWake")
        if effect == nil then
                return false
        end

        if type(effect) == "boolean" then
                return effect
        end

        if type(effect) == "number" then
                return effect ~= 0
        end

        return not not effect
end

spawnGluttonsWakeRock = function(segment)
        if not segment or not segment.fruitMarker then
                return
        end

        local x = segment.fruitMarkerX or segment.drawX or segment.x
        local y = segment.fruitMarkerY or segment.drawY or segment.y
        if not (x and y) then
                return
        end

    Rocks:spawn(x, y)
    local col, row = Arena:getTileFromWorld(x, y)
    if col and row then
            SnakeUtils.setOccupied(col, row, true)
    end
end

crystallizeGluttonsWakeSegments = function(buffer, startIndex, endIndex, upgradeActive)
        if not buffer then
                return
        end

        if upgradeActive == nil then
                upgradeActive = isGluttonsWakeActive()
        end

        if not upgradeActive then
                return
        end

        startIndex = startIndex or 1
        endIndex = endIndex or #buffer
        if endIndex > #buffer then
                endIndex = #buffer
        end

        for i = startIndex, endIndex do
                local segment = buffer[i]
                if segment and segment.fruitMarker then
                        spawnGluttonsWakeRock(segment)
                end
        end
end

function Snake:setDirection(name)
        if not isDead then
                local nd = SnakeUtils.calculateDirection(direction, name)
                if nd then
                        assignDirection(pendingDir, nd.x, nd.y)
		end
	end
end

function Snake:setDead(state)
        isDead = not not state
        if isDead then
                resetSnakeOccupancyGrid()
                clearSnakeBodyOccupancy()
        else
                rebuildOccupancyFromTrail()
        end
end

function Snake:getDirection()
	return direction
end

function Snake:getHead()
	local head = trail[1]
	if not head then
		return nil, nil
	end
	return head.drawX, head.drawY
end

function Snake:setHeadPosition(x, y)
	local head = trail[1]
	if not head then
		return
	end

	head.drawX = x
	head.drawY = y
end

function Snake:translate(dx, dy)
	dx = dx or 0
	dy = dy or 0
	if dx == 0 and dy == 0 then
		return
	end

	for i = 1, #trail do
		local seg = trail[i]
		if seg then
			seg.drawX = seg.drawX + dx
			seg.drawY = seg.drawY + dy
		end
	end

        if descendingHole then
                descendingHole.x = (descendingHole.x or 0) + dx
                descendingHole.y = (descendingHole.y or 0) + dy
                if descendingHole.entryPointX then
                        descendingHole.entryPointX = descendingHole.entryPointX + dx
                end
                if descendingHole.entryPointY then
                        descendingHole.entryPointY = descendingHole.entryPointY + dy
                end
        end

        rebuildOccupancyFromTrail()
end

function Snake:beginPortalWarp(params)
	if type(params) ~= "table" then
		return false
	end

	local entryX = params.entryX
	local entryY = params.entryY
	local exitX = params.exitX
	local exitY = params.exitY
	local duration = params.duration
	local dx = params.dx
	local dy = params.dy

	if not (entryX and entryY and exitX and exitY) then
		return false
	end

	local headSeg = trail and trail[1]
	if headSeg then
		local hx = headSeg.drawX or headSeg.x or 0
		local hy = headSeg.drawY or headSeg.y or 0
		if dx == nil then dx = (exitX or hx) - hx end
		if dy == nil then dy = (exitY or hy) - hy end
	else
		dx = dx or 0
		dy = dy or 0
	end

	local entryIndex = findPortalEntryIndex(entryX, entryY)
	local entryClone = cloneTailFromIndex(entryIndex, entryX, entryY)
	if not entryClone or #entryClone == 0 then
		return false
	end

	local totalLength = computeTrailLength(entryClone)
	if totalLength <= 0 then
		totalLength = SEGMENT_SPACING
	end

	local warpDuration = duration or 0.3
	if warpDuration < 0.05 then
		warpDuration = 0.05
	end

	if (abs(dx or 0) > 0) or (abs(dy or 0) > 0) then
		self:translate(dx or 0, dy or 0)
	end

	local head = trail and trail[1]
	if head then
		head.drawX = exitX
		head.drawY = exitY
	end

        local entrySource = {}
        for i = 1, #entryClone do
                entrySource[i] = copySegmentData(entryClone[i]) or {}
        end
        recycleTrail(entryClone)

        clearPortalAnimation(portalAnimation)
        portalAnimation = {
                timer = 0,
                duration = warpDuration,
                entryIndex = entryIndex,
                entryX = entryX,
                entryY = entryY,
                exitX = exitX,
                exitY = exitY,
                totalLength = totalLength,
                entrySourceTrail = entrySource,
                entryTrail = sliceTrailByLength(entrySource, totalLength),
                exitTrail = {},
                progress = 0,
                entryHole = {
                        x = entryX,
                        y = entryY,
                        baseRadius = SEGMENT_SIZE * 0.7,
                        radius = SEGMENT_SIZE * 0.7,
                        open = 0,
                        visibility = 0,
                        spin = 0,
                        time = 0,
                },
                exitHole = {
                        x = exitX,
                        y = exitY,
                        baseRadius = SEGMENT_SIZE * 0.75,
                        radius = SEGMENT_SIZE * 0.75,
                        open = 0,
                        visibility = 0,
                        spin = 0,
                        time = 0,
                },
        }

        return true
end

function Snake:setDirectionVector(dx, dy)
	if isDead then return end

	dx = dx or 0
	dy = dy or 0

	local nx, ny = normalizeDirection(dx, dy)
	if nx == 0 and ny == 0 then
		return
	end

	assignDirection(direction, nx, ny)
	assignDirection(pendingDir, nx, ny)

	local head = trail and trail[1]
	if head then
		head.dirX = nx
		head.dirY = ny
	end

end

function Snake:getHeadCell()
	local hx, hy = self:getHead()
	if not (hx and hy) then
		return nil, nil
	end
	return toCell(hx, hy)
end

local SAFE_ZONE_SEEN_RESET = 1000000000

local safeZoneCellsBuffer = {}
local safeZoneSeen = {}
local safeZoneSeenGen = 0

local function clearExcessSafeCells(cells, count)
        for i = count + 1, #cells do
                cells[i] = nil
        end
end

local function addSafeCellUnique(cells, seen, gen, count, col, row)
        local stride = cellKeyStride
        if stride <= 0 then
                stride = (Arena and Arena.rows or 0) + 16
                if stride <= 0 then
                        stride = 64
                end
                cellKeyStride = stride
        end

        local key = col * stride + row
        if seen[key] ~= gen then
                seen[key] = gen
                count = count + 1
                local cell = cells[count]
                if cell then
                        cell[1] = col
                        cell[2] = row
                else
                        cells[count] = {col, row}
                end
        end

        return count
end

function Snake:getSafeZone(lookahead)
        local cells = safeZoneCellsBuffer
        local seen = safeZoneSeen

        safeZoneSeenGen = safeZoneSeenGen + 1
        if safeZoneSeenGen >= SAFE_ZONE_SEEN_RESET then
                safeZoneSeenGen = 1
                for key in pairs(seen) do
                        seen[key] = 0
                end
        end

        local gen = safeZoneSeenGen

        local count = 0

        local hx, hy = self:getHeadCell()
        if not (hx and hy) then
                clearExcessSafeCells(cells, count)
                return cells
        end

        local dir = self:getDirection()

        for i = 1, lookahead do
                local cx = hx + dir.x * i
                local cy = hy + dir.y * i
                count = addSafeCellUnique(cells, seen, gen, count, cx, cy)
        end

        local pending = pendingDir
        if pending and (pending.x ~= dir.x or pending.y ~= dir.y) then
                -- Immediate turn path (if the queued direction snaps before the next tile)
                local px, py = hx, hy
                for i = 1, lookahead do
                        px = px + pending.x
                        py = py + pending.y
                        count = addSafeCellUnique(cells, seen, gen, count, px, py)
                end

                -- Typical turn path: advance one tile forward, then apply the queued turn
                local turnCol = hx + dir.x
                local turnRow = hy + dir.y
                px, py = turnCol, turnRow
                for i = 2, lookahead do
                        px = px + pending.x
                        py = py + pending.y
                        count = addSafeCellUnique(cells, seen, gen, count, px, py)
                end
        end

        clearExcessSafeCells(cells, count)

        return cells
end

function Snake:drawClipped(hx, hy, hr)
	if not trail or #trail == 0 then
		return
	end

	local headX, headY = self:getHead()
	local clipRadius = hr or 0
	local renderTrail = trail

	if clipRadius > 0 then
		local radiusSq = clipRadius * clipRadius
		local startIndex = 1

		while startIndex <= #trail do
			local seg = trail[startIndex]
			local x = seg and (seg.drawX or seg.x)
			local y = seg and (seg.drawY or seg.y)

			if not (x and y) then
				break
			end

			local dx = x - hx
			local dy = y - hy
			if dx * dx + dy * dy > radiusSq then
				break
			end

			startIndex = startIndex + 1
		end

                if startIndex == 1 then
                        -- Head is still outside the clip region; render entire trail
                        renderTrail = trail
                else
                        local trimmed = clippedTrailBuffer
                        local trimmedLen = #trimmed
                        if trimmedLen > 0 then
                                for i = trimmedLen, 1, -1 do
                                        trimmed[i] = nil
                                end
                        end

                        if startIndex > #trail then
                                -- Entire snake is within the clip; nothing to draw outside
                                renderTrail = trimmed
                        else
                                local prev = trail[startIndex - 1]
                                local curr = trail[startIndex]
                                local px = prev and (prev.drawX or prev.x)
                                local py = prev and (prev.drawY or prev.y)
                                local cx = curr and (curr.drawX or curr.x)
                                local cy = curr and (curr.drawY or curr.y)
                                local ix, iy

                                if px and py and cx and cy then
                                        ix, iy = findCircleIntersection(px, py, cx, cy, hx, hy, clipRadius)
                                end

                                if not (ix and iy) then
                                        if descendingHole and abs((descendingHole.x or 0) - hx) < 1e-3 and abs((descendingHole.y or 0) - hy) < 1e-3 then
                                                ix = descendingHole.entryPointX or px
                                                iy = descendingHole.entryPointY or py
                                        else
                                                ix, iy = px, py
                                        end
                                end

                                if ix and iy then
                                        local proxy = clippedTrailProxy
                                        proxy.drawX = ix
                                        proxy.drawY = iy
                                        proxy.x = nil
                                        proxy.y = nil
                                        trimmed[1] = proxy
                                end

                                local insertIndex = ix and iy and 2 or 1
                                for i = startIndex, #trail do
                                        trimmed[insertIndex] = trail[i]
                                        insertIndex = insertIndex + 1
                                end

                                renderTrail = trimmed
                        end
                end
        end

	love.graphics.push("all")
	local upgradeVisuals = getUpgradeVisualsForDraw(self)

        if clipRadius > 0 then
                stencilCircleX, stencilCircleY, stencilCircleRadius = hx, hy, clipRadius
                love.graphics.stencil(drawStencilCircle, "replace", 1)
                love.graphics.setStencilTest("equal", 0)
        end

	local shouldDrawFace = descendingHole == nil
	local hideDescendingBody = descendingHole and descendingHole.fullyConsumed

        if not hideDescendingBody then
                clippedHeadX, clippedHeadY = headX, headY
                clipCenterX, clipCenterY, clipRadiusValue = hx, hy, clipRadius
                SnakeDraw.run(renderTrail, segmentCount, SEGMENT_SIZE, popTimer, getClippedHeadPosition, self.shields or 0, self.shieldFlashTimer or 0, upgradeVisuals, shouldDrawFace)
                clippedHeadX, clippedHeadY, clipCenterX, clipCenterY, clipRadiusValue = nil, nil, nil, nil, nil
        end

	if clipRadius > 0 and descendingHole and not hideDescendingBody and abs((descendingHole.x or 0) - hx) < 1e-3 and abs((descendingHole.y or 0) - hy) < 1e-3 then
		love.graphics.setStencilTest("equal", 1)
		drawDescendingIntoHole(descendingHole)
	end

	love.graphics.setStencilTest()
	love.graphics.pop()
end

function Snake:startDescending(hx, hy, hr)
	descendingHole = {
		x = hx,
		y = hy,
		radius = hr or 0,
		consumedLength = 0,
		renderDepth = 0,
		time = 0,
		fullyConsumed = false,
	}

	local headX, headY = self:getHead()
	if headX and headY then
		descendingHole.entryPointX = headX
		descendingHole.entryPointY = headY
		local dirX, dirY = normalizeDirection((hx or headX) - headX, (hy or headY) - headY)
		descendingHole.entryDirX = dirX
		descendingHole.entryDirY = dirY
	end
end

function Snake:finishDescending()
	descendingHole = nil
end

function Snake:update(dt)
	if isDead then return false, "dead", {fatal = true} end

	if self.chronospiral then
		local state = self.chronospiral
		state.spin = (state.spin or 0) + dt
		local intensity = state.intensity or 0
		local target = state.target or 0
		local rate = (state.active and 4.0 or 2.4)
		local blend = min(1, dt * rate)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if intensity < 0.005 and target <= 0 then
			self.chronospiral = nil
		end
	end

	if self.abyssalCatalyst then
		local state = self.abyssalCatalyst
		state.time = (state.time or 0) + dt
		state.pulse = state.time
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 3.0)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if (state.stacks or 0) <= 0 and intensity < 0.01 then
			self.abyssalCatalyst = nil
		end
	end

	if self.phoenixEcho then
		local state = self.phoenixEcho
		state.time = (state.time or 0) + dt
		state.flareDuration = state.flareDuration or 1.2
		if state.flareTimer then
			state.flareTimer = max(0, state.flareTimer - dt)
		end
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 4.2)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if (state.charges or 0) <= 0 and target <= 0 and intensity < 0.01 and (state.flareTimer or 0) <= 0 then
			self.phoenixEcho = nil
		end
	end

	if self.eventHorizon then
		local state = self.eventHorizon
		state.time = (state.time or 0) + dt
		state.spin = (state.spin or 0) + dt * (0.7 + 0.9 * (state.intensity or 0))
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * (state.active and 3.2 or 2.0))
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if not state.active and target <= 0 and intensity < 0.01 then
			self.eventHorizon = nil
		end
	end

	if self.stormchaser then
		local state = self.stormchaser
		state.time = (state.time or 0) + dt
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * (state.primed and 6.5 or 4.2))
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if not state.primed and target <= 0 and intensity < 0.02 then
			self.stormchaser = nil
		end
	end

	if self.titanblood then
		local state = self.titanblood
		state.time = (state.time or 0) + dt
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 3.4)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if (state.stacks or 0) <= 0 and target <= 0 and intensity < 0.01 then
			self.titanblood = nil
		end
	end

	local zephyr = self.zephyrCoils
	if zephyr then
		zephyr.time = (zephyr.time or 0) + dt
		local stacks = zephyr.stacks or 0
		local target = zephyr.target or (stacks > 0 and min(1, 0.45 + 0.2 * min(stacks, 3)) or 0)
		zephyr.target = target
		local blend = min(1, dt * 3.6)
		local intensity = (zephyr.intensity or 0) + (target - (zephyr.intensity or 0)) * blend
		zephyr.intensity = intensity
		if stacks <= 0 and intensity <= 0.01 then
			self.zephyrCoils = nil
		end
	end

	local stoneSkin = self.stoneSkinVisual
	if stoneSkin then
		stoneSkin.time = (stoneSkin.time or 0) + dt
		local charges = self.stoneSkinSawGrace or 0
		stoneSkin.charges = charges
		local target = stoneSkin.target or (charges > 0 and min(1, 0.45 + 0.18 * min(charges, 4)) or 0)
		stoneSkin.target = target
		local blend = min(1, dt * 5.2)
		local current = stoneSkin.intensity or 0
		stoneSkin.intensity = current + (target - current) * blend
		stoneSkin.flash = max(0, (stoneSkin.flash or 0) - dt * 2.6)
		if charges <= 0 and stoneSkin.intensity <= 0.02 and stoneSkin.flash <= 0.02 then
			self.stoneSkinVisual = nil
		end
	end

	local spectral = self.spectralHarvest
	if spectral then
		spectral.time = (spectral.time or 0) + dt
		local target = spectral.target or ((spectral.ready and 1) or 0)
		spectral.target = target
		local blend = min(1, dt * 3.2)
		local current = spectral.intensity or 0
		spectral.intensity = current + (target - current) * blend
		spectral.burst = max(0, (spectral.burst or 0) - dt * 1.8)
		spectral.echo = max(0, (spectral.echo or 0) - dt * 0.9)
		if not spectral.ready and spectral.target <= 0 and spectral.intensity <= 0.02 and spectral.burst <= 0.02 and spectral.echo <= 0.02 then
			self.spectralHarvest = nil
		end
	end

       -- base speed with upgrades/modifiers
	local head = trail[1]
	local speed = self:getSpeed()
	local baselineSpeed = speed

	local hole = descendingHole
	if hole then
		hole.time = (hole.time or 0) + dt

		if head and head.drawX and head.drawY then
			hole.entryPointX = head.drawX
			hole.entryPointY = head.drawY

			local dirX, dirY = normalizeDirection((hole.x or head.drawX) - head.drawX, (hole.y or head.drawY) - head.drawY)
			if dirX ~= 0 or dirY ~= 0 then
				hole.entryDirX = dirX
				hole.entryDirY = dirY
			end
		end

		local consumed = hole.consumedLength or 0
		local totalDepth = max(SEGMENT_SPACING * 0.5, (hole.radius or 0) + SEGMENT_SPACING)
		local targetDepth = min(1, consumed / totalDepth)
		local currentDepth = hole.renderDepth or 0
		local blend = min(1, dt * 10)
		currentDepth = currentDepth + (targetDepth - currentDepth) * blend
		hole.renderDepth = currentDepth
	end

	if self.dash then
		if self.dash.cooldownTimer and self.dash.cooldownTimer > 0 then
			self.dash.cooldownTimer = max(0, (self.dash.cooldownTimer or 0) - dt)
		end

		if self.dash.active then
			speed = speed * (self.dash.speedMult or 1)
			self.dash.timer = (self.dash.timer or 0) - dt
			if self.dash.timer <= 0 then
				self.dash.active = false
				self.dash.timer = 0
			end
		end
	end

	if self.timeDilation then
		if self.timeDilation.cooldownTimer and self.timeDilation.cooldownTimer > 0 then
			self.timeDilation.cooldownTimer = max(0, (self.timeDilation.cooldownTimer or 0) - dt)
		end

		if self.timeDilation.active then
			self.timeDilation.timer = (self.timeDilation.timer or 0) - dt
			if self.timeDilation.timer <= 0 then
				self.timeDilation.active = false
				self.timeDilation.timer = 0
			end
		end
	end

	if self.chronoWard then
		local ward = self.chronoWard
		ward.time = (ward.time or 0) + dt

		if ward.active then
			ward.timer = (ward.timer or 0) - dt
			if ward.timer <= 0 then
				ward.active = false
				ward.timer = 0
			end
		end

		local target = ward.active and 1 or 0
		ward.target = target
		local blend = min(1, dt * 6.0)
		local currentIntensity = ward.intensity or 0
		ward.intensity = currentIntensity + (target - currentIntensity) * blend

		if not ward.active and (ward.intensity or 0) <= 0.01 then
			self.chronoWard = nil
		end
	end

	local dilation = self.timeDilation
	if dilation and dilation.source == "temporal_anchor" then
		local state = self.temporalAnchor
		if not state then
			state = {intensity = 0, target = 0, ready = 0, time = 0}
			self.temporalAnchor = state
		end
		state.time = (state.time or 0) + dt
		state.active = dilation.active or false
		local cooldown = dilation.cooldown or 0
		local cooldownTimer = dilation.cooldownTimer or 0
		local readiness
		if dilation.active then
			readiness = 1
		elseif cooldown and cooldown > 0 then
			readiness = 1 - min(1, cooldownTimer / cooldown)
		else
			readiness = (cooldownTimer <= 0) and 1 or 0
		end
		state.ready = max(0, min(1, readiness))
		if dilation.active then
			state.target = 1
		else
			state.target = max(0.2, 0.3 + state.ready * 0.5)
		end
	elseif self.temporalAnchor then
		local state = self.temporalAnchor
		state.time = (state.time or 0) + dt
		state.active = false
		state.ready = 0
		state.target = 0
	end

	if self.temporalAnchor then
		local state = self.temporalAnchor
		local intensity = state.intensity or 0
		local target = state.target or 0
		local blend = min(1, dt * 5.0)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		if intensity < 0.01 and target <= 0 then
			self.temporalAnchor = nil
		end
	end

	hole = descendingHole
	if hole and head then
		local dx = hole.x - head.drawX
		local dy = hole.y - head.drawY
		local dist = sqrt(dx * dx + dy * dy)
		if dist > 1e-4 then
			local nx, ny = dx / dist, dy / dist
			assignDirection(direction, nx, ny)
			assignDirection(pendingDir, nx, ny)
		end
	end

	-- adrenaline boost check
	if self.adrenaline and self.adrenaline.active then
		speed = speed * self.adrenaline.boost
		self.adrenaline.timer = self.adrenaline.timer - dt
		if self.adrenaline.timer <= 0 then
			self.adrenaline.active = false
			self.adrenaline.suppressVisuals = nil
		end
	end

	do
		local reference = self.baseSpeed or baselineSpeed
		if not (reference and reference > 1e-3) then
			reference = baselineSpeed
		end

		local ratio
		if reference and reference > 1e-3 then
			ratio = speed / reference
		else
			ratio = 1
		end
		if ratio < 0 then
			ratio = 0
		end

		local state = self.speedVisual or {intensity = 0, time = 0, ratio = 1}
		local target = max(0, min(1, (ratio - 1) / 0.8))
		local blend = min(1, dt * 5.5)
		local current = state.intensity or 0
		current = current + (target - current) * blend
		state.intensity = current
		state.target = target

		local ratioBlend = min(1, dt * 6.0)
		local prevRatio = state.ratio or ratio
		prevRatio = prevRatio + (ratio - prevRatio) * ratioBlend
		if prevRatio < 0 then prevRatio = 0 end
		state.ratio = prevRatio

		if self.zephyrCoils then
			self.zephyrCoils.speedRatio = prevRatio
		end

		local timeAdvance = 2.4 + prevRatio * 1.3 + target * 0.8
		state.time = (state.time or 0) + dt * timeAdvance

		if current > 0.01 or target > 0 then
			self.speedVisual = state
		else
			self.speedVisual = nil
		end
	end

	if self.quickFangs then
		local state = self.quickFangs
		state.time = (state.time or 0) + dt * (1.4 + min(1.8, (speed / max(1, self.baseSpeed or 1))))
		state.flash = max(0, (state.flash or 0) - dt * 1.8)

		local baseTarget = state.baseTarget or 0
		local baseSpeed = self.baseSpeed or 1
		if not baseSpeed or baseSpeed <= 0 then
			baseSpeed = 1
		end

		local ratio = speed / baseSpeed
		if ratio < 0 then ratio = 0 end
		state.speedRatio = ratio

		local bonus = max(0, ratio - 1)
		local dynamic = min(0.35, bonus * 0.4)
		local flashBonus = (state.flash or 0) * 0.35
		local target = min(1, max(0, baseTarget + dynamic + flashBonus))
		state.target = target

		local intensity = state.intensity or 0
		local blend = min(1, dt * 6.0)
		intensity = intensity + (target - intensity) * blend
		state.intensity = intensity
		state.active = (target > baseTarget + 0.02) or (ratio > 1.05) or ((state.flash or 0) > 0.05)

		if (state.stacks or 0) <= 0 and target <= 0 and intensity < 0.02 then
			self.quickFangs = nil
		end
	end

        local newX, newY
        local headCells = headCellBuffer
        local headCellCount = 0

        -- advance cell clock, maybe snap & commit queued direction
        if hole then
                moveProgress = 0
                local stepX = direction.x * speed * dt
                local stepY = direction.y * speed * dt
                newX = head.drawX + stepX
                newY = head.drawY + stepY
        else
                local remaining = speed * dt
                local currentDirX, currentDirY = direction.x, direction.y
                local currX, currY = head.drawX, head.drawY
                local snaps = 0
                local segmentLength = SEGMENT_SPACING

                while remaining > 0 do
                        local available = segmentLength - moveProgress
                        if available <= 0 then
                                available = segmentLength
                                moveProgress = 0
                        end

                        if remaining < available then
                                currX = currX + currentDirX * remaining
                                currY = currY + currentDirY * remaining
                                moveProgress = moveProgress + remaining
                                remaining = 0
                        else
                                currX = currX + currentDirX * available
                                currY = currY + currentDirY * available
                                remaining = remaining - available
                                moveProgress = 0
                                snaps = snaps + 1

                                local snapCol, snapRow = toCell(currX, currY)
                                if snapCol and snapRow then
                                        headCellCount = headCellCount + 1
                                        local cell = headCells[headCellCount]
                                        if cell then
                                                cell[1] = snapCol
                                                cell[2] = snapRow
                                                cell[3] = currX
                                                cell[4] = currY
                                        else
                                                headCells[headCellCount] = {snapCol, snapRow, currX, currY}
                                        end
                                end

			assignDirection(direction, pendingDir.x, pendingDir.y)
			currentDirX, currentDirY = direction.x, direction.y
                        end
                end

                if snaps > 0 then
                        SessionStats:add("tilesTravelled", snaps)
                end

                newX, newY = currX, currY
        end

	-- spatially uniform sampling along the motion path
        local dx = newX - head.drawX
        local dy = newY - head.drawY
        local dist = sqrt(dx * dx + dy * dy)

	local nx, ny = 0, 0
	if dist > 0 then
		nx, ny = dx / dist, dy / dist
	end

	local remaining = dist
	local prevX, prevY = head.drawX, head.drawY

        while remaining >= SAMPLE_STEP do
                prevX = prevX + nx * SAMPLE_STEP
                prevY = prevY + ny * SAMPLE_STEP
                local segment = acquireSegment()
                segment.drawX = prevX
                segment.drawY = prevY
                segment.dirX = direction.x
                segment.dirY = direction.y
                segment.fruitMarker = nil
                segment.fruitMarkerX = nil
                segment.fruitMarkerY = nil
                insert(trail, 1, segment)
                remaining = remaining - SAMPLE_STEP
        end

	-- final correction: put true head at exact new position
	if trail[1] then
		trail[1].drawX = newX
		trail[1].drawY = newY
	end

	if hole then
		trimHoleSegments(hole)
		head = trail[1]
		if head then
			newX, newY = head.drawX, head.drawY
		end
	end

	-- tail trimming
	local tailBeforeX, tailBeforeY = nil, nil
	local len = #trail
	if len > 0 then
		tailBeforeX, tailBeforeY = trail[len].drawX, trail[len].drawY
	end
	local tailBeforeCol, tailBeforeRow
	if tailBeforeX and tailBeforeY then
		tailBeforeCol, tailBeforeRow = toCell(tailBeforeX, tailBeforeY)
	end

	local tailAfterCol, tailAfterRow

	local consumedLength = (hole and hole.consumedLength) or 0
	local maxLen = max(0, segmentCount * SEGMENT_SPACING - consumedLength)

        if maxLen == 0 then
                recycleTrail(trail)
                trail = {}
                len = 0
        end

        local traveled = 0
        local gluttonsWakeActive = isGluttonsWakeActive()
        for i = 2, #trail do
                local dx = trail[i - 1].drawX - trail[i].drawX
                local dy = trail[i - 1].drawY - trail[i].drawY
                local segLen = sqrt(dx * dx + dy * dy)

                if traveled + segLen > maxLen then
			local excess = traveled + segLen - maxLen
			local t = 1 - (excess / segLen)
			local tailX = trail[i-1].drawX - dx * t
			local tailY = trail[i-1].drawY - dy * t

                        crystallizeGluttonsWakeSegments(trail, i + 1, #trail, gluttonsWakeActive)
                        releaseSegmentRange(trail, i + 1)

                        trail[i].drawX, trail[i].drawY = tailX, tailY
                        break
                else
                        traveled = traveled + segLen
		end
	end

        local lenAfterTrim = #trail
        do
                lenAfterTrim = #trail
                if lenAfterTrim >= 1 then
                        local tailX, tailY = trail[lenAfterTrim].drawX, trail[lenAfterTrim].drawY
                        if tailX and tailY then
                                tailAfterCol, tailAfterRow = toCell(tailX, tailY)
                        end
                end
        end

        local tailMoved = false
        if lenAfterTrim == 0 then
                tailMoved = true
        elseif tailBeforeCol and tailBeforeRow then
                if not tailAfterCol or not tailAfterRow then
                        tailMoved = true
                else
                        tailMoved = tailBeforeCol ~= tailAfterCol or tailBeforeRow ~= tailAfterRow
                end
        end

        if headCellCount > 0 or tailMoved then
                local overrideCol, overrideRow = nil, nil

                if headCellCount > 0 then
                        local latest = headCells[headCellCount]
                        if latest then
                                overrideCol = latest[1]
                                overrideRow = latest[2]
                        end
                else
                        overrideCol = headOccupancyCol
                        overrideRow = headOccupancyRow
                end

                if (not overrideCol) or (not overrideRow) then
                        local headSeg = trail and trail[1]
                        if headSeg then
                                overrideCol, overrideRow = toCell(headSeg.drawX, headSeg.drawY)
                        end
                end

                rebuildOccupancyFromTrail(overrideCol, overrideRow)
        end

        -- collision with self (grid-cell based, only at snap ticks)
        if headCellCount > 0 and not self:isHazardGraceActive() then
                local hx, hy = trail[1].drawX, trail[1].drawY
                local lastCheckedCol, lastCheckedRow = nil, nil

                for i = 1, headCellCount do
                        local cell = headCells[i]
                        local headCol, headRow = cell and cell[1], cell and cell[2]
                        local headSnapX, headSnapY = cell and cell[3], cell and cell[4]
                        if headCol and headRow then
                                if lastCheckedCol == headCol and lastCheckedRow == headRow then
                                        goto continue
                                end
                                lastCheckedCol, lastCheckedRow = headCol, headRow

                                local tailVacated = false
                                if i == 1 and tailBeforeCol and tailBeforeRow then
                                        if tailBeforeCol == headCol and tailBeforeRow == headRow then
                                                if not (tailAfterCol == headCol and tailAfterRow == headRow) then
                                                        tailVacated = true
                                                end
                                        end
                                end

                                if not tailVacated and isCellOccupiedBySnakeBody(headCol, headRow) then
                                        local gridOccupied = SnakeUtils and SnakeUtils.isOccupied and SnakeUtils.isOccupied(headCol, headRow)
                                        if gridOccupied then
                                                if self:consumeShield() then
                                                        self:onShieldConsumed(hx, hy, "self")
                                                        self:beginHazardGrace()
                                                        break
                                                else
                                                        local pushX = -(direction.x or 0) * SEGMENT_SPACING
                                                        local pushY = -(direction.y or 0) * SEGMENT_SPACING
                                                        local context = {
                                                                pushX = pushX,
                                                                pushY = pushY,
                                                                dirX = -(direction.x or 0),
                                                                dirY = -(direction.y or 0),
                                                                grace = HAZARD_GRACE_DURATION * 2,
                                                                shake = 0.28,
                                                        }
                                                        return false, "self", context
                                                end
                                        end
                                end
                                ::continue::
                        end
                end
        end

        if portalAnimation then
                local state = portalAnimation
                local duration = state.duration or 0.3
                if not duration or duration <= 1e-4 then
                        duration = 1e-4
		end

		state.timer = (state.timer or 0) + dt
		local progress = state.timer / duration
		if progress < 0 then progress = 0 end
		if progress > 1 then progress = 1 end
		state.progress = progress

		local totalLength = state.totalLength
		if not totalLength or totalLength <= 0 then
			totalLength = computeTrailLength(state.entrySourceTrail)
			if totalLength <= 0 then
				totalLength = SEGMENT_SPACING
			end
			state.totalLength = totalLength
		end

		local entryLength = totalLength * (1 - progress)
		local exitLength = totalLength * progress

                state.entryTrail = sliceTrailByLength(state.entrySourceTrail, entryLength, state.entryTrail)
                state.exitTrail = sliceTrailByLength(trail, exitLength, state.exitTrail)

                local entryHole = state.entryHole
                if entryHole then
                        entryHole.x = state.entryX
                        entryHole.y = state.entryY
                        entryHole.time = (entryHole.time or 0) + dt

                        local entryOpen = smoothStep(0.0, 0.22, progress)
                        local entryClose = smoothStep(0.68, 1.0, progress)
                        local entryVisibility = max(0, entryOpen * (1 - entryClose))

                        entryHole.open = entryOpen
                        entryHole.closing = entryClose
                        entryHole.visibility = entryVisibility
                        local baseRadius = entryHole.baseRadius or (SEGMENT_SIZE * 0.7)
                        entryHole.radius = baseRadius * (0.55 + 0.65 * entryOpen)
                        entryHole.spin = (entryHole.spin or 0) + dt * (2.4 + 2.1 * entryOpen)
                        entryHole.pulse = (entryHole.pulse or 0) + dt
                end

                local exitHole = state.exitHole
                if exitHole then
                        exitHole.x = state.exitX
                        exitHole.y = state.exitY
                        exitHole.time = (exitHole.time or 0) + dt

                        local exitOpen = smoothStep(0.08, 0.48, progress)
                        local exitSettle = smoothStep(0.82, 1.0, progress)
                        local exitVisibility = max(exitOpen, (1 - exitSettle) * 0.45)

                        exitHole.open = exitOpen
                        exitHole.closing = exitSettle
                        exitHole.visibility = exitVisibility
                        local baseRadius = exitHole.baseRadius or (SEGMENT_SIZE * 0.75)
                        exitHole.radius = baseRadius * (0.5 + 0.6 * exitOpen)
                        exitHole.spin = (exitHole.spin or 0) + dt * (2.0 + 2.2 * exitOpen)
                        exitHole.pulse = (exitHole.pulse or 0) + dt
                end

                if progress >= 1 then
                        clearPortalAnimation(state)
                        portalAnimation = nil
                end
        end

	-- update timers
	if popTimer > 0 then
		popTimer = max(0, popTimer - dt)
	end

	if self.shieldFlashTimer and self.shieldFlashTimer > 0 then
		self.shieldFlashTimer = max(0, self.shieldFlashTimer - dt)
	end

	if self.hazardGraceTimer and self.hazardGraceTimer > 0 then
		self.hazardGraceTimer = max(0, self.hazardGraceTimer - dt)
	end

	if self.damageFlashTimer and self.damageFlashTimer > 0 then
		self.damageFlashTimer = max(0, self.damageFlashTimer - dt)
	end

        if severedPieces and #severedPieces > 0 then
                for index = #severedPieces, 1, -1 do
                        local piece = severedPieces[index]
                        if piece then
                                piece.timer = (piece.timer or 0) - dt
                                if piece.timer <= 0 then
                                        if piece.trail then
                                                recycleTrail(piece.trail)
                                                piece.trail = nil
                                        end
                                        remove(severedPieces, index)
                                end
                        end
                end
        end

	return true
end

function Snake:activateDash()
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
		})
	end

	return dash.active
end

function Snake:isDashActive()
	return self.dash and self.dash.active or false
end

function Snake:getDashState()
	if not self.dash then
		return nil
	end

	return {
		active = self.dash.active or false,
		timer = self.dash.timer or 0,
		duration = self.dash.duration or 0,
		cooldown = self.dash.cooldown or 0,
		cooldownTimer = self.dash.cooldownTimer or 0,
	}
end

function Snake:onDashBreakRock(x, y)
	local dash = self.dash
	if not dash then return end

	local Upgrades = getUpgradesModule()
	if Upgrades and Upgrades.notify then
		Upgrades:notify("dashBreakRock", {
			x = x,
			y = y,
		})
	end
end

function Snake:activateTimeDilation()
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
		})
	end

	return ability.active
end

function Snake:triggerChronoWard(duration, scale)
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

function Snake:getTimeDilationState()
	local ability = self.timeDilation
	if not ability then
		return nil
	end

	return {
		active = ability.active or false,
		timer = ability.timer or 0,
		duration = ability.duration or 0,
		cooldown = ability.cooldown or 0,
		cooldownTimer = ability.cooldownTimer or 0,
		timeScale = resolveTimeDilationScale(ability),
		floorCharges = ability.floorCharges,
		maxFloorUses = ability.maxFloorUses,
	}
end

function Snake:getTimeScale()
	return resolveTimeDilationScale(self.timeDilation, self.chronoWard)
end

function Snake:grow()
	local bonus = self.extraGrowth or 0
	segmentCount = segmentCount + 1 + bonus
	popTimer = POP_DURATION
end

function Snake:loseSegments(count, options)
	count = floor(count or 0)
	if count <= 0 then
		return 0
	end

	local available = max(0, (segmentCount or 1) - 1)
	local trimmed = min(count, available)
	if trimmed <= 0 then
		return 0
	end

	local exitWasOpen = Arena and Arena.hasExit and Arena:hasExit()
	segmentCount = segmentCount - trimmed
	popTimer = 0

	local shouldTrimTrail = true
	if options and options.trimTrail == false then
		shouldTrimTrail = false
	end

	if shouldTrimTrail then
		trimTrailToSegmentLimit()
	end

	local tail = trail[#trail]
	local tailX = tail and tail.drawX
	local tailY = tail and tail.drawY

	if (not options) or options.updateFruit ~= false then
		if UI and UI.removeFruit then
			UI:removeFruit(trimmed)
		elseif UI then
			UI.fruitCollected = max(0, (UI.fruitCollected or 0) - trimmed)
			if type(UI.fruitSockets) == "table" then
				for _ = 1, min(trimmed, #UI.fruitSockets) do
					remove(UI.fruitSockets)
				end
			end
		end
	end

	local fruitGoalLost = false
	if UI then
		local collected = UI.fruitCollected or 0
		local required = UI.fruitRequired or 0
		fruitGoalLost = required > 0 and collected < required
	end

	if exitWasOpen and fruitGoalLost and Arena and Arena.resetExit then
		Arena:resetExit()
		if Fruit and Fruit.spawn then
			Fruit:spawn(self:getSegments(), Rocks, self:getSafeZone(3))
		end
	end

    local apples = SessionStats:get("applesEaten") or 0
    apples = max(0, apples - trimmed)
    SessionStats:set("applesEaten", apples)

	if Score and Score.addBonus and Score.get then
		local currentScore = Score:get() or 0
		local deduction = min(currentScore, trimmed)
		if deduction > 0 then
			Score:addBonus(-deduction)
		end
	end

        if (not options) or options.spawnParticles ~= false then
                local burstColor = LOSE_SEGMENTS_DEFAULT_BURST_COLOR
                if options and options.cause == "saw" then
                        burstColor = LOSE_SEGMENTS_SAW_BURST_COLOR
                end

                if Particles and Particles.spawnBurst and tailX and tailY then
                        local burstOptions = LOSE_SEGMENTS_BURST_OPTIONS
                        burstOptions.count = min(10, 4 + trimmed)
                        burstOptions.color = burstColor
                        Particles:spawnBurst(tailX, tailY, burstOptions)
                end
        end

	return trimmed
end

local function chopTailLossAmount()
	local available = max(0, (segmentCount or 1) - 1)
	if available <= 0 then
		return 0
	end

	local loss = floor(max(1, available * 0.2))
	return min(loss, available)
end

function Snake:chopTailByHazard(cause)
	local loss = chopTailLossAmount()
	if loss <= 0 then
		return 0
	end

	return self:loseSegments(loss, {cause = cause or "saw"})
end

function Snake:chopTailBySaw()
	return self:chopTailByHazard("saw")
end

local function isSawActive(saw)
	if not saw then
		return false
	end

	return not ((saw.sinkProgress or 0) > 0 or (saw.sinkTarget or 0) > 0)
end

local function getSawCenterPosition(saw)
	if not (Saws and Saws.getCollisionCenter) then
		return nil, nil
	end

	return Saws:getCollisionCenter(saw)
end

local function isSawCutPointExposed(saw, sx, sy, px, py)
	if not (saw and sx and sy and px and py) then
		return true
	end

	local tolerance = 1.0
	local nx, ny

	if saw.dir == "horizontal" then
		-- Horizontal saws sit in the floor and only the top half (negative Y)
		-- should be able to slice the snake.
		nx, ny = 0, -1
	else
		-- For vertical saws, the exposed side depends on which wall the blade
		-- is mounted to. The sink direction indicates which side is hidden in
		-- the track, so flip it to get the exposed normal.
		local sinkDir = (saw.side == "left") and -1 or 1
		nx, ny = -sinkDir, 0
	end

	local dx = px - sx
	local dy = py - sy
	local projection = dx * nx + dy * ny

	return projection >= -tolerance
end

local function clamp01(value)
	return max(0, min(1, value or 0))
end

local function scaleColorAlpha(color, scale)
	local r = 1
	local g = 1
	local b = 1
	local a = 1

	if type(color) == "table" then
		r = color[1] or r
		g = color[2] or g
		b = color[3] or b
		a = color[4] or a
	end

	return {r, g, b, clamp01(a * scale)}
end

local function buildSeveredPalette(fade)
	local palette = SnakeCosmetics and SnakeCosmetics:getPaletteForSkin() or nil
	local bodyColor = palette and palette.body or (SnakeCosmetics and SnakeCosmetics.getBodyColor and SnakeCosmetics:getBodyColor())
	local outlineColor = palette and palette.outline or (SnakeCosmetics and SnakeCosmetics.getOutlineColor and SnakeCosmetics:getOutlineColor())

	local alpha = clamp01(fade or 1)

	return {
		body = scaleColorAlpha(bodyColor, alpha),
		outline = scaleColorAlpha(outlineColor, alpha),
	}
end

local function addSeveredTrail(pieceTrail, segmentEstimate)
	if not pieceTrail or #pieceTrail <= 1 then
		return
	end

	severedPieces = severedPieces or {}
	local fadeDuration = min(SEVERED_TAIL_LIFE, SEVERED_TAIL_FADE_DURATION)
	insert(severedPieces, {
		trail = pieceTrail,
		timer = SEVERED_TAIL_LIFE,
		life = SEVERED_TAIL_LIFE,
		fadeDuration = fadeDuration,
		segmentCount = max(1, segmentEstimate or #pieceTrail),
	})
end

local function spawnSawCutParticles(x, y, count)
	if not (Particles and Particles.spawnBurst and x and y) then
		return
	end

	Particles:spawnBurst(x, y, {
		count = min(12, 5 + (count or 0)),
		speed = 120,
		speedVariance = 60,
		life = 0.42,
		size = 4,
		color = {1, 0.6, 0.3, 1},
		spread = pi * 2,
		drag = 3.0,
		gravity = 220,
		fadeTo = 0,
	})
end

function Snake:handleSawBodyCut(context)
	if not context then
		return false
	end

	local available = max(0, (segmentCount or 1) - 1)
	if available <= 0 then
		return false
	end

	local index = context.index or 2
	if index <= 1 or index > #trail then
		return false
	end

	local previousIndex = index - 1
	local previousSegment = trail[previousIndex]
	if not previousSegment then
		return false
	end

	local cutX = context.cutX
	local cutY = context.cutY
	if not (cutX and cutY) then
		return false
	end

	local totalLength = (segmentCount or 1) * SEGMENT_SPACING
	local cutDistance = max(0, context.cutDistance or 0)
	if cutDistance <= SEGMENT_SPACING then
		return false
	end

	local tailDistance = 0
	do
		local prevCutX, prevCutY = cutX, cutY
		for i = index, #trail do
			local seg = trail[i]
			local sx = seg and (seg.drawX or seg.x)
			local sy = seg and (seg.drawY or seg.y)
			if sx and sy and prevCutX and prevCutY then
				local ddx = sx - prevCutX
				local ddy = sy - prevCutY
                                tailDistance = tailDistance + sqrt(ddx * ddx + ddy * ddy)
				prevCutX, prevCutY = sx, sy
			end
		end
	end

	local rawSegments = tailDistance / SEGMENT_SPACING
	local lostSegments = max(1, floor(rawSegments + 0.25))
	if lostSegments > available then
		lostSegments = available
	end
	if lostSegments <= 0 then
		return false
	end

	if (totalLength - lostSegments * SEGMENT_SPACING) < cutDistance and lostSegments > 1 then
		local adjusted = totalLength - (lostSegments - 1) * SEGMENT_SPACING
		if adjusted >= cutDistance then
			lostSegments = lostSegments - 1
		end
	end

	local newTail = copySegmentData(previousSegment) or {}
	newTail.drawX = cutX
	newTail.drawY = cutY
	if previousSegment.x and previousSegment.y then
		newTail.x = cutX
		newTail.y = cutY
	end

	local dirX, dirY = normalizeDirection(cutX - (previousSegment.drawX or previousSegment.x or cutX), cutY - (previousSegment.drawY or previousSegment.y or cutY))
	if (dirX == 0 and dirY == 0) and previousSegment then
		dirX = previousSegment.dirX or 0
		dirY = previousSegment.dirY or 0
	end
	newTail.dirX = dirX
	newTail.dirY = dirY
	newTail.fruitMarker = nil
	newTail.fruitMarkerX = nil
	newTail.fruitMarkerY = nil

	local severedTrail = {}
	severedTrail[1] = copySegmentData(newTail)

        for i = index, #trail do
                local segCopy = copySegmentData(trail[i])
                if segCopy then
                        severedTrail[#severedTrail + 1] = segCopy
                end
        end

        for i = #trail, previousIndex + 1, -1 do
                local removed = trail[i]
                trail[i] = nil
                if removed then
                        releaseSegment(removed)
                end
        end

        trail[#trail + 1] = newTail

	addSeveredTrail(severedTrail, lostSegments + 1)
	spawnSawCutParticles(cutX, cutY, lostSegments)

	self:loseSegments(lostSegments, {cause = "saw", trimTrail = false})

	return true
end

function Snake:checkSawBodyCollision()
	if isDead then
		return false
	end

	if not (trail and #trail > 2) then
		return false
	end

	if not (Saws and Saws.getAll) then
		return false
	end

	local saws = Saws:getAll()
	if not (saws and #saws > 0) then
		return false
	end

	local head = trail[1]
	local headX = head and (head.drawX or head.x)
	local headY = head and (head.drawY or head.y)
	if not (headX and headY) then
		return false
	end

	local guardDistance = SEGMENT_SPACING * 0.9
	local bodyRadius = SEGMENT_SIZE * 0.5

	for i = 1, #saws do
		local saw = saws[i]
		if isSawActive(saw) then
			local sx, sy = getSawCenterPosition(saw)
			if sx and sy then
				local sawRadius = (saw.collisionRadius or saw.radius or 0)
				local travelled = 0
				local prevX, prevY = headX, headY

				for index = 2, #trail do
					local segment = trail[index]
					local cx = segment and (segment.drawX or segment.x)
					local cy = segment and (segment.drawY or segment.y)
					if cx and cy then
						local dx = cx - prevX
						local dy = cy - prevY
                                                local segLen = sqrt(dx * dx + dy * dy)
						local minX = min(prevX, cx) - bodyRadius
						local minY = min(prevY, cy) - bodyRadius
						local maxX = max(prevX, cx) + bodyRadius
						local maxY = max(prevY, cy) + bodyRadius
						local width = maxX - minX
						local height = maxY - minY

						if segLen > 1e-6 and (not (Saws and Saws.isCollisionCandidate) or Saws:isCollisionCandidate(saw, minX, minY, width, height)) then
							local closestX, closestY, distSq, t = closestPointOnSegment(sx, sy, prevX, prevY, cx, cy)
							local along = travelled + segLen * (t or 0)
							if along > guardDistance then
								local combined = sawRadius + bodyRadius
								if distSq <= combined * combined and isSawCutPointExposed(saw, sx, sy, closestX, closestY) then
									local handled = self:handleSawBodyCut({
										index = index,
										cutX = closestX,
										cutY = closestY,
										cutDistance = along,
									})
									if handled then
										return true
									end
								end
							end
						end

						travelled = travelled + segLen
						prevX, prevY = cx, cy
					end
				end
			end
		end
	end

	return false
end

function Snake:markFruitSegment(fruitX, fruitY)
	if not trail or #trail == 0 then
		return
	end

	local targetIndex = 1

	if fruitX and fruitY then
		local bestDistSq = huge
		for i = 1, #trail do
			local seg = trail[i]
			local sx = seg and (seg.drawX or seg.x)
			local sy = seg and (seg.drawY or seg.y)
			if sx and sy then
				local dx = fruitX - sx
				local dy = fruitY - sy
				local distSq = dx * dx + dy * dy
				if distSq < bestDistSq then
					bestDistSq = distSq
					targetIndex = i
					if distSq <= 1 then
						break
					end
				end
			end
		end
	end

	local segment = trail[targetIndex]
	if segment then
		segment.fruitMarker = true
		if fruitX and fruitY then
			segment.fruitMarkerX = fruitX
			segment.fruitMarkerY = fruitY
		else
			segment.fruitMarkerX = nil
			segment.fruitMarkerY = nil
		end
	end
end

function Snake:draw()
	if not isDead then
	local upgradeVisuals = getUpgradeVisualsForDraw(self)

		if severedPieces and #severedPieces > 0 then
			for i = 1, #severedPieces do
				local piece = severedPieces[i]
				local trailData = piece and piece.trail
                                if trailData and #trailData > 1 then
                                        local remaining = piece.timer or 0
                                        local life = piece.life or SEVERED_TAIL_LIFE
                                        local fadeDuration = piece.fadeDuration or SEVERED_TAIL_FADE_DURATION
                                        local fade = 1

					if fadeDuration and fadeDuration > 0 then
						if remaining <= fadeDuration then
							fade = clamp01(remaining / fadeDuration)
						end
					elseif life and life > 0 then
						fade = clamp01(remaining / life)
					end

					local drawOptions = {
						drawFace = false,
						paletteOverride = buildSeveredPalette(fade),
						overlayEffect = nil,
					}

                                        activeTrailForHead = trailData
                                        SnakeDraw.run(trailData, piece.segmentCount or #trailData, SEGMENT_SIZE, 0, getActiveTrailHead, 0, 0, nil, drawOptions)
                                        activeTrailForHead = nil
                                end
                        end
                end

		local shouldDrawFace = descendingHole == nil
		local hideDescendingBody = descendingHole and descendingHole.fullyConsumed

		if not hideDescendingBody then
			local drawOptions
                        if portalAnimation then
                                drawOptions = {
                                        drawFace = shouldDrawFace,
                                        portalAnimation = {
                                                entryTrail = portalAnimation.entryTrail,
                                                exitTrail = portalAnimation.exitTrail,
                                                entryX = portalAnimation.entryX,
                                                entryY = portalAnimation.entryY,
                                                exitX = portalAnimation.exitX,
                                                exitY = portalAnimation.exitY,
                                                progress = portalAnimation.progress or 0,
                                                duration = portalAnimation.duration or 0.3,
                                                timer = portalAnimation.timer or 0,
                                                entryHole = portalAnimation.entryHole,
                                                exitHole = portalAnimation.exitHole,
                                        },
                                }
                        else
                                drawOptions = shouldDrawFace
                        end

                        currentHeadOwner = self
                        SnakeDraw.run(trail, segmentCount, SEGMENT_SIZE, popTimer, getOwnerHead, self.shields or 0, self.shieldFlashTimer or 0, upgradeVisuals, drawOptions)
                        currentHeadOwner = nil
                end

        end
end

function Snake:resetPosition()
	self:load(screenW, screenH)
end

function Snake:getSegments()
	local copy = {}
	for i = 1, #trail do
		local seg = trail[i]
		copy[i] = {
			drawX = seg.drawX,
			drawY = seg.drawY,
			dirX = seg.dirX,
			dirY = seg.dirY
		}
	end
	return copy
end

function Snake:setDeveloperAssist(state)
        local newState = not not state
        if developerAssistEnabled == newState then
                return developerAssistEnabled
        end

        developerAssistEnabled = newState
        announceDeveloperAssistChange(newState)
        rebuildOccupancyFromTrail()
        return developerAssistEnabled
end

function Snake:toggleDeveloperAssist()
	return self:setDeveloperAssist(not developerAssistEnabled)
end

function Snake:isDeveloperAssistEnabled()
	return developerAssistEnabled
end

function Snake:getLength()
        return segmentCount
end

return Snake
