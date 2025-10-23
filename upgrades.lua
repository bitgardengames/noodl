local Face = require("face")
local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Score = require("score")
local UI = require("ui")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local PlayerStats = require("playerstats")
local UpgradeHelpers = require("upgradehelpers")
local DataSchemas = require("dataschemas")

local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local abs = math.abs
local insert = table.insert

local Upgrades = {}
local poolById = {}
local upgradeSchema = DataSchemas.upgradeDefinition
local getUpgradeString = UpgradeHelpers.getUpgradeString
local rarities = UpgradeHelpers.rarities
local deepcopy = UpgradeHelpers.deepcopy
local defaultEffects = UpgradeHelpers.defaultEffects
local celebrateUpgrade = UpgradeHelpers.celebrateUpgrade
local getEventPosition = UpgradeHelpers.getEventPosition

local RunState = {}
RunState.__index = RunState

function RunState.new(defaults)
	local state = {
		takenOrder = {},
		takenSet = {},
		tags = {},
		counters = {},
		handlers = {},
		effects = deepcopy(defaults or defaultEffects),
		baseline = {},
	}

	return setmetatable(state, RunState)
end

function RunState:getStacks(id)
	if not id then
		return 0
	end

	return self.takenSet[id] or 0
end

function RunState:addStacks(id, amount)
	if not id then
		return
	end

	amount = amount or 1
	self.takenSet[id] = (self.takenSet[id] or 0) + amount
end

function RunState:hasUpgrade(id)
	return self:getStacks(id) > 0
end

function RunState:addHandler(event, handler)
	if not event or type(handler) ~= "function" then
		return
	end

	local handlers = self.handlers[event]
	if not handlers then
		handlers = {}
		self.handlers[event] = handlers
	end

	insert(handlers, handler)
end

function RunState:notify(event, data)
	local handlers = self.handlers[event]
	if not handlers then
		return
	end

	for _, fn in ipairs(handlers) do
		fn(data, self)
	end
end

local POCKET_SPRINGS_FRUIT_TARGET = 20
local CHRONO_WARD_DEFAULT_DURATION = 0.85
local CHRONO_WARD_DEFAULT_SCALE = 0.45
local CIRCUIT_BREAKER_STALL_DURATION = 0.75
local SUBDUCTION_ARRAY_SINK_DURATION = 1.6
local SUBDUCTION_ARRAY_VISUAL_LIMIT = 3
local RESONANT_SHELL_DEFENSE_CAP = 5
local TREMOR_BLOOM_RADIUS = 2
local TREMOR_BLOOM_SLIDE_DURATION = 0.28
local TREMOR_BLOOM_SAW_NUDGE_AMOUNT = 0.22
local TREMOR_BLOOM_COLOR = {0.76, 0.64, 1.0, 1}

local function getStacks(state, id)
	if not state or not id then
		return 0
	end

	local method = state.getStacks
	if type(method) == "function" then
		return method(state, id)
	end

	local takenSet = state.takenSet
	if not takenSet then
		return 0
	end

	return takenSet[id] or 0
end

local function grantShields(amount)
	amount = max(0, floor((amount or 0) + 0.0001))
	if amount <= 0 then
		return 0
	end

        Snake:addShields(amount)
        return amount
end

local function getSegmentPosition(fraction)
        local segments = Snake:getSegments()
        local count = segments and #segments or 0
        if count <= 0 then
                return Snake:getHead()
        end

	fraction = fraction or 0
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	local index = 1
	if count > 1 then
		local scaled = fraction * (count - 1)
		index = floor(scaled + 0.5) + 1
	end

	if index > count then
		index = count
	elseif index < 1 then
		index = 1
	end

	local segment = segments[index]
	if segment then
		local x = segment.drawX or segment.x
		local y = segment.drawY or segment.y
		if x and y then
			return x, y
		end
	end

        return Snake:getHead()
end

local function triggerChronoWard(state, data)
        local effects = state and state.effects or {}
        local duration = effects.chronoWardDuration or CHRONO_WARD_DEFAULT_DURATION
        local scale = effects.chronoWardScale or CHRONO_WARD_DEFAULT_SCALE

        Snake:triggerChronoWard(duration, scale)
end

local function applySegmentPosition(options, fraction)
	if not options then
		options = {}
	end

	local x, y = getSegmentPosition(fraction)
	if x and y then
		options.x = options.x or x
		options.y = options.y or y
	end

	return options
end

local function collectPositions(source, limit, extractor)
	if not source then
		return nil
	end

	local count = #source
	if not count or count <= 0 then
		return {}
	end

	local result = {}
	local maxCount = min(limit or count, count)
	for index = 1, maxCount do
		local item = source[index]
		if item then
			local px, py = extractor(item)
			if px and py then
				result[#result + 1] = {px, py}
			end
		end
	end

	return result
end

local function getSawCenters(limit)
        if not Saws or not Saws.getAll then
                return nil
        end

        return collectPositions(Saws:getAll(), limit, function(saw)
                local sx, sy
                if Saws.getCollisionCenter then
                        sx, sy = Saws:getCollisionCenter(saw)
                end
                return sx or saw.x, sy or saw.y
        end)
end

local function getLaserCenters(limit)
        if not Lasers or not Lasers.getEmitters then
                return nil
        end

        return collectPositions(Lasers:getEmitters(), limit, function(beam)
                return beam.x, beam.y
        end)
end

local function getLaserEmitterDetails(limit)
        if not Lasers or not Lasers.getEmitters then
                return {}
        end

        local emitters = Lasers:getEmitters()
        if not emitters then
                return {}
        end

        local count = #emitters
        if not count or count <= 0 then
                return {}
        end

        local targets = {}
        local maxCount = min(limit or count, count)
        for index = 1, maxCount do
                local beam = emitters[index]
                if beam then
                        local x = beam.x
                        local y = beam.y
                        if x and y then
                                targets[#targets + 1] = {
                                        x = x,
                                        y = y,
                                        dir = beam.dir,
                                        facing = beam.facing,
                                }
                        end
                end
        end

        return targets
end

local function arenaHasGrid()
        return Arena and Arena.cols and Arena.rows and Arena.getTileFromWorld and Arena.getCenterOfTile
end

local function getCellKey(col, row)
        return tostring(col) .. ":" .. tostring(row)
end

local function isCellWithinBounds(col, row)
        if not arenaHasGrid() then
                return false
        end

        return col >= 1 and col <= Arena.cols and row >= 1 and row <= Arena.rows
end

local function isCellOpen(col, row, ignoreLookup)
        if not isCellWithinBounds(col, row) then
                return false
        end

        if ignoreLookup and ignoreLookup[getCellKey(col, row)] then
                return true
        end

        if SnakeUtils and SnakeUtils.isOccupied then
                return not SnakeUtils.isOccupied(col, row)
        end

        return true
end

local function addPosition(positions, x, y)
        if positions and x and y then
                positions[#positions + 1] = {x, y}
        end
end

local function getPushCandidates(col, row, originCol, originRow)
        if not (col and row and originCol and originRow) then
                return nil
        end

        local dx = col - originCol
        local dy = row - originRow

        if dx == 0 and dy == 0 then
                return nil
        end

        if max(abs(dx), abs(dy)) > TREMOR_BLOOM_RADIUS then
                return nil
        end

        local stepX = 0
        if dx > 0 then
                stepX = 1
        elseif dx < 0 then
                stepX = -1
        end

        local stepY = 0
        if dy > 0 then
                stepY = 1
        elseif dy < 0 then
                stepY = -1
        end

        if stepX == 0 and stepY == 0 then
                return nil
        end

        local candidates = {}
        local function addCandidate(cx, cy)
                candidates[#candidates + 1] = {cx, cy}
        end

        if stepX ~= 0 and stepY ~= 0 then
                addCandidate(col + stepX, row + stepY)
                if abs(dx) >= abs(dy) then
                        addCandidate(col + stepX, row)
                        addCandidate(col, row + stepY)
                else
                        addCandidate(col, row + stepY)
                        addCandidate(col + stepX, row)
                end
        else
                addCandidate(col + stepX, row + stepY)
        end

        return candidates
end

local function pushNearbyRocks(originCol, originRow, positions)
        if not Rocks or not Rocks.getAll or not arenaHasGrid() then
                return false
        end

        local moved = false
        local rocks = Rocks:getAll()
        if not rocks then
                return false
        end

        for _, rock in ipairs(rocks) do
                local col, row = rock.col, rock.row
                if col and row then
                        local candidates = getPushCandidates(col, row, originCol, originRow)
                        if candidates then
                                for _, candidate in ipairs(candidates) do
                                        local targetCol, targetRow = candidate[1], candidate[2]
                                        if isCellOpen(targetCol, targetRow) then
                                                local startX, startY = rock.x, rock.y

                                                if SnakeUtils and SnakeUtils.setOccupied then
                                                        SnakeUtils.setOccupied(col, row, false)
                                                end

                                                local centerX, centerY = Arena:getCenterOfTile(targetCol, targetRow)
                                                if Rocks and Rocks.beginSlide then
                                                        Rocks:beginSlide(rock, startX, startY, centerX, centerY, {
                                                                duration = TREMOR_BLOOM_SLIDE_DURATION,
                                                                lift = 12,
                                                        })
                                                end

                                                rock.col = targetCol
                                                rock.row = targetRow
                                                rock.x = centerX
                                                rock.y = centerY
                                                rock.timer = 0
                                                rock.phase = "done"
                                                rock.scaleX = 1
                                                rock.scaleY = 1
                                                rock.offsetY = 0

                                                if SnakeUtils and SnakeUtils.setOccupied then
                                                        SnakeUtils.setOccupied(targetCol, targetRow, true)
                                                end

                                                addPosition(positions, centerX, centerY)
                                                moved = true
                                                break
                                        end
                                end
                        end
                end
        end

        return moved
end

local function computeLaserFacing(dir, col, row)
        if dir == "vertical" then
                local midpoint = floor((Arena.rows or 1) / 2)
                if row and row > midpoint then
                        return -1
                end
        else
                local midpoint = floor((Arena.cols or 1) / 2)
                if col and col > midpoint then
                        return -1
                end
        end

        return 1
end

local function pushNearbyLasers(originCol, originRow, positions)
        if not Lasers or not Lasers.getEmitters or not arenaHasGrid() then
                return false
        end

        local moved = false
        local emitters = Lasers:getEmitters()
        if not emitters then
                return false
        end

        for _, beam in ipairs(emitters) do
                local col, row = beam.col, beam.row
                if col and row then
                        local candidates = getPushCandidates(col, row, originCol, originRow)
                        if candidates then
                                for _, candidate in ipairs(candidates) do
                                        local targetCol, targetRow = candidate[1], candidate[2]
                                        if isCellOpen(targetCol, targetRow) then
                                                local startX, startY = beam.x, beam.y

                                                if SnakeUtils and SnakeUtils.setOccupied then
                                                        SnakeUtils.setOccupied(col, row, false)
                                                end

                                                local centerX, centerY = Arena:getCenterOfTile(targetCol, targetRow)
                                                beam.col = targetCol
                                                beam.row = targetRow
                                                beam.x = centerX
                                                beam.y = centerY
                                                beam.facing = computeLaserFacing(beam.dir, targetCol, targetRow)

                                                if Lasers and Lasers.beginEmitterSlide then
                                                        Lasers:beginEmitterSlide(beam, startX, startY, centerX, centerY, {
                                                                duration = TREMOR_BLOOM_SLIDE_DURATION,
                                                        })
                                                end

                                                if SnakeUtils and SnakeUtils.setOccupied then
                                                        SnakeUtils.setOccupied(targetCol, targetRow, true)
                                                end

                                                addPosition(positions, centerX, centerY)
                                                moved = true
                                                break
                                        end
                                end
                        end
                end
        end

        return moved
end

local function buildCellLookup(cells)
        local lookup = {}
        if not cells then
                return lookup
        end

        for i = 1, #cells do
                local cell = cells[i]
                if cell then
                        lookup[getCellKey(cell[1], cell[2])] = true
                end
        end

        return lookup
end

local function nudgeSawAlongTrack(saw, originCol, originRow, positions)
        if not (saw and Arena and Arena.getCenterOfTile and Saws and Saws.getCenterForProgress) then
                return false
        end

        local originX, originY = Arena:getCenterOfTile(originCol, originRow)
        if not (originX and originY) then
                return false
        end

        local startProgress = saw.progress or 0
        local startCenterX, startCenterY = Saws:getCenterForProgress(saw, startProgress)
        local targetProgress = startProgress

        if saw.dir == "horizontal" then
                if (startCenterX or 0) >= originX then
                        targetProgress = min(1, startProgress + TREMOR_BLOOM_SAW_NUDGE_AMOUNT)
                else
                        targetProgress = max(0, startProgress - TREMOR_BLOOM_SAW_NUDGE_AMOUNT)
                end
        else
                if (startCenterY or 0) >= originY then
                        targetProgress = min(1, startProgress + TREMOR_BLOOM_SAW_NUDGE_AMOUNT)
                else
                        targetProgress = max(0, startProgress - TREMOR_BLOOM_SAW_NUDGE_AMOUNT)
                end
        end

        if abs(targetProgress - startProgress) < 1e-4 then
                return false
        end

        if Saws.beginProgressNudge then
                Saws:beginProgressNudge(saw, startProgress, targetProgress, {
                        duration = TREMOR_BLOOM_SLIDE_DURATION,
                })
        else
                saw.progress = targetProgress
        end

        if targetProgress > startProgress then
                saw.direction = 1
        elseif targetProgress < startProgress then
                saw.direction = -1
        end

        if positions then
                local endX, endY = Saws:getCenterForProgress(saw, targetProgress)
                if endX and endY then
                        addPosition(positions, endX, endY)
                end
        end

        return true
end

local function pushNearbySaws(originCol, originRow, positions)
        if not Saws or not Saws.getAll or not arenaHasGrid() then
                return false
        end

        if not SnakeUtils or not (SnakeUtils.getSawTrackCells and SnakeUtils.releaseCells and SnakeUtils.occupySawTrack) then
                return false
        end

        local moved = false
        local saws = Saws:getAll()
        if not saws then
                return false
        end

        for _, saw in ipairs(saws) do
                local sx, sy = saw.x, saw.y
                if sx and sy then
                        local col, row = Arena:getTileFromWorld(sx, sy)
                        if col and row then
                                local candidates = getPushCandidates(col, row, originCol, originRow)
                                local movedThisSaw = false
                                local withinRadius = candidates ~= nil
                                if candidates then
                                        local oldCells = SnakeUtils.getSawTrackCells(saw.x, saw.y, saw.dir)
                                        local ignoreLookup = buildCellLookup(oldCells)

                                        for _, candidate in ipairs(candidates) do
                                                local targetCol, targetRow = candidate[1], candidate[2]
                                                if isCellOpen(targetCol, targetRow, ignoreLookup) then
                                                        local centerX, centerY = Arena:getCenterOfTile(targetCol, targetRow)
                                                        local targetCells = SnakeUtils.getSawTrackCells(centerX, centerY, saw.dir)
                                                        if targetCells and #targetCells > 0 then
                                                                local blocked = false
                                                                if SnakeUtils.isOccupied then
                                                                        for i = 1, #targetCells do
                                                                                local cell = targetCells[i]
                                                                                local key = getCellKey(cell[1], cell[2])
                                                                                if not ignoreLookup[key] and SnakeUtils.isOccupied(cell[1], cell[2]) then
                                                                                        blocked = true
                                                                                        break
                                                                                end
                                                                        end
                                                                end

                                                                if not blocked then
                                                                        local startX, startY = saw.x, saw.y
                                                                        if oldCells then
                                                                                SnakeUtils.releaseCells(oldCells)
                                                                        end

                                                                        SnakeUtils.occupySawTrack(centerX, centerY, saw.dir)
                                                                        if Saws.beginTrackSlide then
                                                                                Saws:beginTrackSlide(saw, startX, startY, centerX, centerY, {
                                                                                        duration = TREMOR_BLOOM_SLIDE_DURATION,
                                                                                })
                                                                        else
                                                                                saw.x = centerX
                                                                                saw.y = centerY
                                                                        end

                                                                        saw.collisionCells = nil
                                                                        addPosition(positions, centerX, centerY)
                                                                        moved = true
                                                                        movedThisSaw = true
                                                                        break
                                                                end
                                                        end
                                                end
                                        end
                                end

                                if not movedThisSaw and withinRadius then
                                        if nudgeSawAlongTrack(saw, originCol, originRow, positions) then
                                                moved = true
                                        end
                                end
                        end
                end
        end

        return moved
end

local function tremorBloomPushHazards(data)
        if not data or not arenaHasGrid() then
                return false, nil
        end

        local fx, fy = getEventPosition(data)
        if not (fx and fy) then
                return false, nil
        end

        local originCol, originRow = Arena:getTileFromWorld(fx, fy)
        if not (originCol and originRow) then
                return false, nil
        end

        local positions = {}
        local moved = false

        if pushNearbyRocks(originCol, originRow, positions) then
                moved = true
        end

        if pushNearbyLasers(originCol, originRow, positions) then
                moved = true
        end

        if pushNearbySaws(originCol, originRow, positions) then
                moved = true
        end

        if not moved then
                return false, nil
        end

        return true, positions
end

local function stoneSkinShieldHandler(data, state)
        if not state then return end
        if getStacks(state, "stone_skin") <= 0 then return end
        if not data or data.cause ~= "rock" then return end
        if not Rocks or not Rocks.shatterNearest then return end

	local fx, fy = getEventPosition(data)
	celebrateUpgrade(nil, nil, {
		x = fx,
		y = fy,
		skipText = true,
		color = {0.75, 0.82, 0.88, 1},
		particleCount = 16,
		particleSpeed = 100,
		particleLife = 0.42,
		visual = {
			badge = "shield",
			outerRadius = 56,
			innerRadius = 16,
			ringCount = 3,
			ringSpacing = 10,
			life = 0.82,
			glowAlpha = 0.28,
			haloAlpha = 0.18,
		},
	})
	Rocks:shatterNearest(fx or 0, fy or 0, 1)
end

local AMBER_BLOOM_SHATTER_THRESHOLD = 3
local AMBER_BLOOM_PROGRESS_PER_TRIGGER = 0.25

local function handleAmberBloomRockShatter(data, state)
	if not state then return end

	if getStacks(state, "amber_bloom") <= 0 then
		return
	end

	state.counters = state.counters or {}
	local counters = state.counters

	counters.amberBloomRockCount = (counters.amberBloomRockCount or 0) + 1

	while (counters.amberBloomRockCount or 0) >= AMBER_BLOOM_SHATTER_THRESHOLD do
		counters.amberBloomRockCount = (counters.amberBloomRockCount or 0) - AMBER_BLOOM_SHATTER_THRESHOLD

		local progress = (counters.amberBloomShieldProgress or 0) + AMBER_BLOOM_PROGRESS_PER_TRIGGER
		local shields = floor(progress + 1e-6)
		counters.amberBloomShieldProgress = progress - shields

		local label = getUpgradeString("amber_bloom", "activation_text")
		if label and label ~= "" then
			if shields > 0 then
				if shields > 1 then
					label = string.format("%s +%d", label, shields)
				else
					label = string.format("%s +1", label)
				end
			else
				label = string.format("%s +25%%", label)
			end
		else
			label = nil
		end

		if shields > 0 then
			grantShields(shields)
		end

		celebrateUpgrade(label, data, {
			color = {1.0, 0.72, 0.38, 1},
			particleCount = 12,
			particleSpeed = 110,
			particleLife = 0.44,
			textOffset = 44,
			textScale = 1.06,
			visual = {
				badge = "shield",
				outerRadius = 52,
				innerRadius = 14,
				ringCount = 3,
				life = 0.7,
				glowAlpha = 0.24,
				haloAlpha = 0.16,
				color = {1.0, 0.72, 0.38, 1},
				variantSecondaryColor = {1.0, 0.54, 0.24, 0.92},
				variantTertiaryColor = {1.0, 0.9, 0.58, 0.78},
			},
		})
	end
end

local function newRunState()
	return RunState.new(defaultEffects)
end

Upgrades.runState = newRunState()

local function normalizeUpgradeDefinition(upgrade)
	if type(upgrade) ~= "table" then
		error("upgrade definition must be a table")
	end

	if upgrade.id == nil and upgrade.name ~= nil then
		upgrade.id = upgrade.name
	end

	if upgrade.name and not upgrade.nameKey then
		upgrade.nameKey = upgrade.name
		upgrade.name = nil
	end

	if upgrade.desc and not upgrade.descKey then
		upgrade.descKey = upgrade.desc
		upgrade.desc = nil
	end

	DataSchemas.applyDefaults(upgradeSchema, upgrade)
	local context = string.format("upgrade '%s'", tostring(upgrade.id or "?"))
	DataSchemas.validate(upgradeSchema, upgrade, context)

	if type(upgrade.tags) ~= "table" then
		upgrade.tags = {"default"}
	else
		local tagCount = #upgrade.tags
		if tagCount == 0 then
			upgrade.tags[1] = "default"
		end
	end

	return upgrade
end

local function register(upgrade)
	normalizeUpgradeDefinition(upgrade)
	poolById[upgrade.id] = upgrade
	return upgrade
end

local function countUpgradesWithTag(state, tag)
	if not state or not tag then return 0 end

	local total = 0
	if not state.takenSet then return total end

	for id, count in pairs(state.takenSet) do
		local upgrade = poolById[id]
		if upgrade and upgrade.tags then
			for _, upgradeTag in ipairs(upgrade.tags) do
				if upgradeTag == tag then
					total = total + (count or 0)
					break
				end
			end
		end
	end

	return total
end

local function updateResonantShellBonus(state)
	if not state then return end

	local perBonus = state.counters and state.counters.resonantShellPerBonus or 0
	local perCharge = state.counters and state.counters.resonantShellPerCharge or 0
	if perBonus <= 0 and perCharge <= 0 then return end

        local defenseCount = countUpgradesWithTag(state, "defense")
        local effectiveDefenseCount = min(defenseCount, RESONANT_SHELL_DEFENSE_CAP)

        if perBonus > 0 then
                local previous = state.counters.resonantShellBonus or 0
                local newBonus = perBonus * effectiveDefenseCount
                state.counters.resonantShellBonus = newBonus
                state.effects.sawStall = (state.effects.sawStall or 0) - previous + newBonus
        end

        if perCharge > 0 then
                local previousCharge = state.counters.resonantShellChargeBonus or 0
                local newCharge = perCharge * effectiveDefenseCount
                state.counters.resonantShellChargeBonus = newCharge
                state.effects.laserChargeFlat = (state.effects.laserChargeFlat or 0) - previousCharge + newCharge
        end
end

local function updateGuildLedger(state)
	if not state then return end

	local perSlot = state.counters and state.counters.guildLedgerFlatPerSlot or 0
	if perSlot == 0 then return end

	local slots = 0
	if state.effects then
		slots = state.effects.shopSlots or 0
	end

	local previous = state.counters.guildLedgerBonus or 0
	local newBonus = -(perSlot * slots)
	state.counters.guildLedgerBonus = newBonus
	state.effects.rockSpawnFlat = (state.effects.rockSpawnFlat or 0) - previous + newBonus
end

local function updateRadiantCharter(state)
	if not state then return end

	local perSlotLaser = state.counters and state.counters.radiantCharterLaserPerSlot or 0
	local perSlotSaw = state.counters and state.counters.radiantCharterSawPerSlot or 0
	if perSlotLaser == 0 and perSlotSaw == 0 then return end

	local slots = 0
	if state.effects then
		slots = state.effects.shopSlots or 0
	end

	slots = max(0, floor(slots + 0.0001))

	local previousLaser = state.counters.radiantCharterLaserBonus or 0
	local previousSaw = state.counters.radiantCharterSawBonus or 0

	local newLaser = -(perSlotLaser * slots)
	local newSaw = perSlotSaw * slots

	state.counters.radiantCharterLaserBonus = newLaser
	state.counters.radiantCharterSawBonus = newSaw

	state.effects.laserSpawnBonus = (state.effects.laserSpawnBonus or 0) - previousLaser + newLaser
	state.effects.sawSpawnBonus = (state.effects.sawSpawnBonus or 0) - previousSaw + newSaw
end

local function updateStoneCensus(state)
	if not state then return end

	local perEconomy = state.counters and state.counters.stoneCensusReduction or 0
	if perEconomy == 0 then return end

	local previous = state.counters.stoneCensusMult or 1
	if previous <= 0 then previous = 1 end

	local effects = state.effects or {}
	effects.rockSpawnMult = effects.rockSpawnMult or 1
	effects.rockSpawnMult = effects.rockSpawnMult / previous

	local economyCount = countUpgradesWithTag(state, "economy")
	local newMult = max(0.2, 1 - perEconomy * economyCount)

	state.counters.stoneCensusMult = newMult
	effects.rockSpawnMult = effects.rockSpawnMult * newMult
	state.effects = effects
end

local mapmakersCompassHazards = {
        {
                key = "laserCount",
                effectKey = "laserSpawnBonus",
                labelKey = "lasers_text",
                color = {0.72, 0.9, 1.0, 1},
                priority = 3,
        },
        {
                key = "saws",
                effectKey = "sawSpawnBonus",
                labelKey = "saws_text",
                color = {1.0, 0.78, 0.42, 1},
                priority = 2,
        },
        {
                key = "rocks",
                effectKey = "rockSpawnBonus",
                labelKey = "rocks_text",
                color = {0.72, 0.86, 1.0, 1},
                priority = 1,
        },
}

local function compareCompassCandidates(a, b)
        if a.value == b.value then
                return (a.info.priority or 0) < (b.info.priority or 0)
        end
        return (a.value or 0) > (b.value or 0)
end

local function clearMapmakersCompass(state)
	if not state then return end
	local counters = state.counters
	if not counters then return end

	local applied = counters.mapmakersCompassApplied
	if not applied then return end

	state.effects = state.effects or {}

	for effectKey, delta in pairs(applied) do
		if delta ~= 0 then
			state.effects[effectKey] = (state.effects[effectKey] or 0) - delta
		end
	end

	counters.mapmakersCompassApplied = {}
end

local function applyMapmakersCompass(state, context, options)
	if not state then return end
	state.effects = state.effects or {}
	state.counters = state.counters or {}

	clearMapmakersCompass(state)

	local stacks = getStacks(state, "mapmakers_compass")
	if stacks <= 0 then
		return
	end

	state.counters.mapmakersCompassApplied = state.counters.mapmakersCompassApplied or {}
	state.counters.mapmakersCompassTarget = nil
	state.counters.mapmakersCompassReduction = nil

	if context == nil then
		return
	end

	state.counters.mapmakersCompassLastContext = context

	local candidates = {}
	for _, entry in ipairs(mapmakersCompassHazards) do
		local value = context[entry.key] or 0
		insert(candidates, {info = entry, value = value})
	end

        table.sort(candidates, compareCompassCandidates)

	local chosen
	for _, candidate in ipairs(candidates) do
		if candidate.value and candidate.value > 0 then
			chosen = candidate.info
			break
		end
	end

	local applied = state.counters.mapmakersCompassApplied
	local celebrate = options and options.celebrate
	local eventData = options and options.eventData

	if not chosen then
		if Score and Score.addBonus then
			Score:addBonus(2 + stacks)
		end

		if Saws and Saws.stall then
			Saws:stall(0.6 + 0.1 * stacks)
		end

		if celebrate then
			local label = getUpgradeString("mapmakers_compass", "activation_text") or getUpgradeString("mapmakers_compass", "name")
			celebrateUpgrade(label, eventData, {
				color = {0.92, 0.82, 0.6, 1},
				textOffset = 46,
				textScale = 1.08,
				visual = {
					variant = "guiding_compass",
					showBase = false,
					life = 0.78,
					innerRadius = 12,
					outerRadius = 58,
					addBlend = true,
					color = {0.92, 0.82, 0.6, 1},
					variantSecondaryColor = {1.0, 0.68, 0.32, 0.95},
					variantTertiaryColor = {0.72, 0.86, 1.0, 0.7},
				},
			})
		end

		return
	end

	local reduction = 1 + floor((stacks - 1) * 0.5)
	local delta = -reduction
	local effectKey = chosen.effectKey
	state.effects[effectKey] = (state.effects[effectKey] or 0) + delta
	applied[effectKey] = delta
	state.counters.mapmakersCompassTarget = chosen.key
	state.counters.mapmakersCompassReduction = reduction

	if celebrate then
		local label = getUpgradeString("mapmakers_compass", chosen.labelKey or "activation_text") or getUpgradeString("mapmakers_compass", "name")
		celebrateUpgrade(label, eventData, {
			color = chosen.color or {0.72, 0.86, 1.0, 1},
			textOffset = 46,
			textScale = 1.08,
			visual = {
				variant = "guiding_compass",
				showBase = false,
				life = 0.82,
				innerRadius = 12,
				outerRadius = 62,
				addBlend = true,
				color = chosen.color or {0.72, 0.86, 1.0, 1},
				variantSecondaryColor = {1.0, 0.82, 0.42, 1},
				variantTertiaryColor = {0.48, 0.72, 1.0, 0.85},
			},
		})
	end
end

local function mapmakersCompassFloorStart(data, state)
	if not (data and state) then return end
	if getStacks(state, "mapmakers_compass") <= 0 then return end

	local context = data.context
	applyMapmakersCompass(state, context, {celebrate = true, eventData = data})
end

local function normalizeDirection(dx, dy)
	dx = dx or 0
	dy = dy or 0

	local length = math.sqrt(dx * dx + dy * dy)
	if not length or length <= 1e-5 then
		return 0, -1
	end

	return dx / length, dy / length
end

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local function applyCircuitBreakerFacing(options, dx, dy)
	if not options then
		return
	end

	local particles = options.particles
	if not particles then
		return
	end

	dx, dy = normalizeDirection(dx, dy)
	local baseAngle = atan2(dy, dx)
	local spread = particles.spread or 0
	particles.angleOffset = baseAngle - spread * 0.5
end

local function getSawFacingDirection(sawInfo)
        if not sawInfo then
                return 0, -1
        end

	if sawInfo.dir == "vertical" then
		if sawInfo.side == "left" then
			return 1, 0
		elseif sawInfo.side == "right" then
			return -1, 0
		end

		return -1, 0
	end

        return 0, -1
end

local function getLaserFacingDirection(laserInfo)
        if not laserInfo then
                return 0, -1
        end

        local dir = laserInfo.dir
        local facing = (laserInfo.facing or 1) >= 0 and 1 or -1

        if dir == "horizontal" then
                return facing, 0
        end

        return 0, facing
end

local function buildCircuitBreakerTargets(data)
        local targets = {}
        if not data then
                return targets
        end

        if data.saws and #data.saws > 0 then
                for _, entry in ipairs(data.saws) do
                        if entry then
                                local x = entry.x or entry[1]
                                local y = entry.y or entry[2]
                                if x and y then
                                        targets[#targets + 1] = {
                                                x = x,
                                                y = y,
                                                dir = entry.dir,
                                                side = entry.side,
                                                type = "saw",
                                        }
                                end
                        end
                end
        elseif data.positions and #data.positions > 0 then
                for _, pos in ipairs(data.positions) do
                        if pos then
                                local x = pos[1]
                                local y = pos[2]
                                if x and y then
                                        targets[#targets + 1] = {
                                                x = x,
                                                y = y,
                                                type = "saw",
                                        }
                                end
                        end
                end
        end

        return targets
end

local function buildCircuitBreakerLaserTargets(limit)
        return getLaserEmitterDetails(limit)
end

local pool = {
        register({
                id = "serpents_reflex",
                nameKey = "upgrades.serpents_reflex.name",
                descKey = "upgrades.serpents_reflex.description",
                rarity = "common",
                tags = {"mobility"},
                allowDuplicates = true,
                onAcquire = function(state)
                        Snake:addSpeedMultiplier(1.04)

                        celebrateUpgrade(getUpgradeString("serpents_reflex", "name"), nil, {
                                color = {0.98, 0.76, 0.36, 1},
                                particleCount = 12,
                                particleSpeed = 120,
                                particleLife = 0.34,
                                textOffset = 36,
                                textScale = 1.06,
                        })
                end,
        }),
        register({
                id = "quick_fangs",
                nameKey = "upgrades.quick_fangs.name",
                descKey = "upgrades.quick_fangs.description",
                rarity = "rare",
                allowDuplicates = true,
		maxStacks = 4,
                onAcquire = function(state)
                        Snake:addSpeedMultiplier(1.10)

			if state then
				state.counters = state.counters or {}
				local stacks = (state.counters.quickFangsStacks or 0) + 1
				state.counters.quickFangsStacks = stacks
				if Snake.setQuickFangsStacks then
					Snake:setQuickFangsStacks(stacks)
				end
			elseif Snake.setQuickFangsStacks then
				Snake:setQuickFangsStacks((Snake.quickFangs and Snake.quickFangs.stacks or 0) + 1)
			end

                        Face:set("veryHappy", 1.6)

			local celebrationOptions = {
				color = {1, 0.63, 0.42, 1},
				particleCount = 18,
				particleSpeed = 150,
				particleLife = 0.38,
				textOffset = 46,
				textScale = 1.18,
			}
			applySegmentPosition(celebrationOptions, 0.28)
			celebrateUpgrade(getUpgradeString("quick_fangs", "name"), nil, celebrationOptions)
		end,
	}),
	register({
		id = "stone_skin",
		nameKey = "upgrades.stone_skin.name",
		descKey = "upgrades.stone_skin.description",
		rarity = "uncommon",
		allowDuplicates = true,
		maxStacks = 4,
		onAcquire = function(state)
			Snake:addShields(1)
			if Snake.addStoneSkinSawGrace then
				Snake:addStoneSkinSawGrace(1)
			end
			if not state.counters.stoneSkinHandlerRegistered then
				state.counters.stoneSkinHandlerRegistered = true
				Upgrades:addEventHandler("shieldConsumed", stoneSkinShieldHandler)
			end
                        Face:set("blank", 1.8)
			local celebrationOptions = {
				color = {0.75, 0.82, 0.88, 1},
				particleCount = 14,
				particleSpeed = 90,
				particleLife = 0.45,
				textOffset = 50,
				textScale = 1.12,
				visual = {
					variant = "stoneguard_bastion",
					life = 0.8,
					innerRadius = 14,
					outerRadius = 60,
					color = {0.74, 0.8, 0.88, 1},
					variantSecondaryColor = {0.46, 0.5, 0.56, 1},
					variantTertiaryColor = {0.94, 0.96, 0.98, 0.72},
				},
			}
			applySegmentPosition(celebrationOptions, 0.46)
			celebrateUpgrade(getUpgradeString("stone_skin", "name"), nil, celebrationOptions)
		end,
	}),
	register({
		id = "aegis_recycler",
		nameKey = "upgrades.aegis_recycler.name",
		descKey = "upgrades.aegis_recycler.description",
		rarity = "uncommon",
		tags = {"defense"},
		onAcquire = function(state)
			state.counters.aegisRecycler = state.counters.aegisRecycler or 0
		end,
		handlers = {
			shieldConsumed = function(data, state)
                                state.counters.aegisRecycler = (state.counters.aegisRecycler or 0) + 1
                                if state.counters.aegisRecycler >= 3 then
                                        state.counters.aegisRecycler = state.counters.aegisRecycler - 3
					Snake:addShields(1)
					local fx, fy = getEventPosition(data)
					if fx and fy then
						celebrateUpgrade(nil, data, {
							x = fx,
							y = fy,
							skipText = true,
							color = {0.6, 0.85, 1, 1},
							particleCount = 10,
							particleSpeed = 90,
							particleLife = 0.45,
							visual = {
								badge = "shield",
								outerRadius = 50,
								innerRadius = 14,
								ringCount = 3,
								life = 0.75,
								glowAlpha = 0.26,
								haloAlpha = 0.16,
							},
						})
					end
				end
			end,
		},
	}),
	register({
		id = "amber_bloom",
		nameKey = "upgrades.amber_bloom.name",
		descKey = "upgrades.amber_bloom.description",
		rarity = "common",
		tags = {"defense"},
		onAcquire = function(state)
			state.counters = state.counters or {}
			state.counters.amberBloomRockCount = state.counters.amberBloomRockCount or 0
			state.counters.amberBloomShieldProgress = state.counters.amberBloomShieldProgress or 0

			if not state.counters.amberBloomHandlerRegistered then
				state.counters.amberBloomHandlerRegistered = true
				Upgrades:addEventHandler("rockShattered", handleAmberBloomRockShatter)
			end
		end,
	}),
	register({
                id = "extra_bite",
                nameKey = "upgrades.extra_bite.name",
                descKey = "upgrades.extra_bite.description",
                rarity = "common",
                tags = {"hazard"},
                onAcquire = function(state)
                        state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
                        state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 1.15
                        UI:adjustFruitGoal(-1)
                        Face:set("angry", 1.4)
			local celebrationOptions = {
				color = {1, 0.86, 0.36, 1},
				particleCount = 10,
				particleSpeed = 70,
				particleLife = 0.38,
				textOffset = 38,
				textScale = 1.04,
				visual = {
					variant = "extra_bite_chomp",
					showBase = false,
					life = 0.78,
					innerRadius = 10,
					outerRadius = 52,
					addBlend = true,
					color = {1, 0.86, 0.36, 1},
					variantSecondaryColor = {1, 1, 1, 0.92},
					variantTertiaryColor = {1, 0.62, 0.28, 0.82},
				},
			}
			applySegmentPosition(celebrationOptions, 0.92)
			celebrateUpgrade(getUpgradeString("extra_bite", "celebration"), nil, celebrationOptions)
		end,
	}),
	register({
		id = "adrenaline_surge",
		nameKey = "upgrades.adrenaline_surge.name",
		descKey = "upgrades.adrenaline_surge.description",
		rarity = "uncommon",
		tags = {"adrenaline"},
		onAcquire = function(state)
			state.effects.adrenaline = state.effects.adrenaline or {duration = 3, boost = 1.5}
			celebrateUpgrade(getUpgradeString("adrenaline_surge", "name"), nil, {
				color = {1, 0.42, 0.42, 1},
				particleCount = 20,
				particleSpeed = 160,
				particleLife = 0.36,
				textOffset = 42,
				textScale = 1.16,
				skipVisuals = true,
			})
		end,
	}),
	register({
		id = "stone_whisperer",
		nameKey = "upgrades.stone_whisperer.name",
		descKey = "upgrades.stone_whisperer.description",
		rarity = "common",
		tags = {"hazard", "rocks"},
		onAcquire = function(state)
			state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.6
		end,
	}),
	register({
		id = "deliberate_coil",
		nameKey = "upgrades.deliberate_coil.name",
		descKey = "upgrades.deliberate_coil.description",
		rarity = "epic",
		tags = {"speed", "risk"},
		unlockTag = "speedcraft",
		onAcquire = function(state)
			Snake:addSpeedMultiplier(0.85)
			state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1
                        UI:adjustFruitGoal(1)
                        Face:set("sad", 2.0)
			celebrateUpgrade(getUpgradeString("deliberate_coil", "name"), nil, {
				color = {0.76, 0.56, 0.88, 1},
				particleCount = 16,
				particleSpeed = 90,
				particleLife = 0.5,
				textOffset = 40,
				textScale = 1.08,
				visual = {
					variant = "coiled_focus",
					showBase = false,
					life = 0.86,
					innerRadius = 14,
					outerRadius = 60,
					addBlend = true,
					color = {0.76, 0.56, 0.88, 1},
					variantSecondaryColor = {0.58, 0.44, 0.92, 0.9},
					variantTertiaryColor = {0.98, 0.9, 1.0, 0.75},
				},
			})
		end,
	}),
	register({
		id = "pocket_springs",
		nameKey = "upgrades.pocket_springs.name",
		descKey = "upgrades.pocket_springs.description",
		rarity = "uncommon",
		tags = {"defense"},
		onAcquire = function(state)
			state.counters.pocketSpringsFruit = state.counters.pocketSpringsFruit or 0
			if state.counters.pocketSpringsComplete == nil then
				state.counters.pocketSpringsComplete = false
			end
		end,
		handlers = {
			fruitCollected = function(data, state)
				if getStacks(state, "pocket_springs") <= 0 then
					return
				end

				if state.counters.pocketSpringsComplete then
					return
				end

				state.counters.pocketSpringsFruit = (state.counters.pocketSpringsFruit or 0) + 1
				if state.counters.pocketSpringsFruit >= POCKET_SPRINGS_FRUIT_TARGET then
					state.counters.pocketSpringsFruit = POCKET_SPRINGS_FRUIT_TARGET
					state.counters.pocketSpringsComplete = true
					Snake:addShields(1)
                                        Face:set("happy", 1.6)
					local celebrationOptions = {
						color = {0.64, 0.86, 1.0, 1},
						particleCount = 14,
						particleSpeed = 110,
						particleLife = 0.46,
						textOffset = 44,
						textScale = 1.1,
						visual = {
							variant = "pocket_springs",
							showBase = false,
							life = 0.84,
							innerRadius = 12,
							outerRadius = 58,
							addBlend = true,
							color = {0.68, 0.88, 1.0, 1},
							variantSecondaryColor = {0.42, 0.72, 1.0, 0.92},
							variantTertiaryColor = {1.0, 0.92, 0.6, 0.8},
						},
					}
					applySegmentPosition(celebrationOptions, 0.42)
					celebrateUpgrade(getUpgradeString("pocket_springs", "name"), nil, celebrationOptions)
				end
			end,
		},
	}),
	register({
		id = "mapmakers_compass",
		nameKey = "upgrades.mapmakers_compass.name",
		descKey = "upgrades.mapmakers_compass.description",
		rarity = "uncommon",
		tags = {"defense", "utility"},
		onAcquire = function(state)
			state.effects = state.effects or {}
			state.counters = state.counters or {}
			state.counters.mapmakersCompassApplied = state.counters.mapmakersCompassApplied or {}

			if not state.counters.mapmakersCompassHandlerRegistered then
				state.counters.mapmakersCompassHandlerRegistered = true
				Upgrades:addEventHandler("floorStart", mapmakersCompassFloorStart)
			end

                        Face:set("happy", 1.4)

			if state.counters.mapmakersCompassLastContext then
				applyMapmakersCompass(state, state.counters.mapmakersCompassLastContext, {celebrate = false})
			end
		end,
	}),
       register({
               id = "molting_reflex",
		nameKey = "upgrades.molting_reflex.name",
		descKey = "upgrades.molting_reflex.description",
		rarity = "uncommon",
		requiresTags = {"adrenaline"},
		tags = {"adrenaline", "defense"},
		handlers = {
			shieldConsumed = function(data)
				if not Snake.adrenaline then return end

				Snake.adrenaline.active = true
				local baseDuration = Snake.adrenaline.duration or 2.5
				local surgeDuration = baseDuration * 0.6
				if surgeDuration <= 0 then surgeDuration = 1 end
				local currentTimer = Snake.adrenaline.timer or 0
				Snake.adrenaline.timer = max(currentTimer, surgeDuration)
				Snake.adrenaline.suppressVisuals = nil

				local fx, fy = getEventPosition(data)
				if fx and fy then
					celebrateUpgrade(nil, data, {
						x = fx,
						y = fy,
						skipText = true,
						color = {1, 0.72, 0.28, 1},
						particleCount = 12,
						particleSpeed = 120,
						particleLife = 0.5,
						visual = {
							variant = "molting_reflex",
							showBase = false,
							life = 0.78,
							innerRadius = 12,
							outerRadius = 56,
							addBlend = true,
							color = {1, 0.72, 0.28, 1},
							variantSecondaryColor = {1, 0.46, 0.18, 0.95},
							variantTertiaryColor = {1, 0.92, 0.62, 0.8},
						},
					})
				end
			end,
		},
	}),
        register({
                id = "circuit_breaker",
                nameKey = "upgrades.circuit_breaker.name",
                descKey = "upgrades.circuit_breaker.description",
                rarity = "rare",
                onAcquire = function(state)
                        state.effects.sawStall = (state.effects.sawStall or 0) + CIRCUIT_BREAKER_STALL_DURATION
			local sparkColor = {1, 0.58, 0.32, 1}
			celebrateUpgrade(getUpgradeString("circuit_breaker", "name"), nil, {
				color = sparkColor,
				skipVisuals = true,
				skipParticles = true,
				textOffset = 44,
				textScale = 1.08,
			})
		end,
		handlers = {
			sawsStalled = function(data, state)
				if getStacks(state, "circuit_breaker") <= 0 then
					return
				end

				if not data then
					return
				end

				if data.cause and data.cause ~= "fruit" then
					return
				end

                                local duration = (data and data.duration) or CIRCUIT_BREAKER_STALL_DURATION
                                if Lasers and Lasers.stall then
                                        Lasers:stall(duration, {
                                                cause = data and data.cause or nil,
                                                source = "circuit_breaker",
                                                positionLimit = 2,
                                        })
                                end

                                local sparkColor = {1, 0.58, 0.32, 1}
                                local baseOptions = {
                                        color = sparkColor,
                                        skipText = true,
                                        skipVisuals = true,
                                        particles = {
                                                count = 14,
                                                speed = 120,
                                                speedVariance = 70,
                                                life = 0.28,
                                                size = 2.8,
                                                color = {1, 0.74, 0.38, 1},
                                                spread = pi * 0.45,
                                                angleJitter = pi * 0.18,
                                                gravity = 200,
                                                drag = 1.5,
                                                fadeTo = 0,
                                                scaleMin = 0.4,
                                                scaleVariance = 0.26,
                                        },
                                }

                                local sawTargets = buildCircuitBreakerTargets(data)
                                if not sawTargets or #sawTargets == 0 then
                                        sawTargets = {}
                                        local sawCenters = getSawCenters(2)
                                        if sawCenters and #sawCenters > 0 then
                                                for _, pos in ipairs(sawCenters) do
                                                        if pos then
                                                                sawTargets[#sawTargets + 1] = {
                                                                        x = pos[1],
                                                                        y = pos[2],
                                                                        type = "saw",
                                                                }
                                                        end
                                                end
                                        end
                                end

                                local sparksSpawned = 0

                                if sawTargets and #sawTargets > 0 then
                                        local limit = min(#sawTargets, 2)
                                        for i = 1, limit do
                                                local target = sawTargets[i]
                                                if target then
                                                        local sparkOptions = deepcopy(baseOptions)
                                                        sparkOptions.x = target.x
                                                        sparkOptions.y = target.y
                                                        local dirX, dirY = getSawFacingDirection(target)
                                                        applyCircuitBreakerFacing(sparkOptions, dirX, dirY)
                                                        celebrateUpgrade(nil, nil, sparkOptions)
                                                        sparksSpawned = sparksSpawned + 1
                                                end
                                        end
                                end

                                local laserTargets = buildCircuitBreakerLaserTargets(2)
                                if laserTargets and #laserTargets > 0 then
                                        local limit = min(#laserTargets, 2)
                                        for i = 1, limit do
                                                local target = laserTargets[i]
                                                if target then
                                                        local sparkOptions = deepcopy(baseOptions)
                                                        sparkOptions.x = target.x
                                                        sparkOptions.y = target.y
                                                        local dirX, dirY = getLaserFacingDirection(target)
                                                        applyCircuitBreakerFacing(sparkOptions, dirX, dirY)
                                                        celebrateUpgrade(nil, nil, sparkOptions)
                                                        sparksSpawned = sparksSpawned + 1
                                                end
                                        end
                                end

                                if sparksSpawned <= 0 then
                                        local fallbackOptions = deepcopy(baseOptions)
                                        applySegmentPosition(fallbackOptions, 0.82)
                                        applyCircuitBreakerFacing(fallbackOptions, 0, -1)
                                        celebrateUpgrade(nil, nil, fallbackOptions)
                                end
                        end,
                },
        }),
        register({
                id = "tremor_bloom",
                nameKey = "upgrades.tremor_bloom.name",
                descKey = "upgrades.tremor_bloom.description",
                rarity = "rare",
                tags = {"mobility", "hazard", "rocks", "control"},
                onAcquire = function()
                        celebrateUpgrade(getUpgradeString("tremor_bloom", "name"), nil, {
                                color = TREMOR_BLOOM_COLOR,
                                textOffset = 46,
                                textScale = 1.08,
                                particleCount = 18,
                                particleSpeed = 120,
                                particleLife = 0.38,
                                visual = {
                                        variant = "pulse",
                                        showBase = false,
                                        life = 0.78,
                                        innerRadius = 10,
                                        outerRadius = 64,
                                        ringCount = 3,
                                        ringSpacing = 10,
                                        addBlend = true,
                                        color = TREMOR_BLOOM_COLOR,
                                        variantSecondaryColor = {0.52, 0.44, 0.96, 0.85},
                                        variantTertiaryColor = {1.0, 0.86, 0.4, 0.62},
                                },
                        })
                end,
                handlers = {
                        fruitCollected = function(data, state)
                                if getStacks(state, "tremor_bloom") <= 0 then
                                        return
                                end

                                local moved, hazardPositions = tremorBloomPushHazards(data)
                                if not moved then
                                        return
                                end

                                local activationLabel = getUpgradeString("tremor_bloom", "activation_text")
                                if activationLabel == "" or activationLabel == "upgrades.tremor_bloom.activation_text" then
                                        activationLabel = nil
                                end

                                local celebrationOptions = {
                                        color = TREMOR_BLOOM_COLOR,
                                        textOffset = 48,
                                        textScale = 1.08,
                                        particleCount = 18,
                                        particleSpeed = 120,
                                        particleLife = 0.4,
                                        visual = {
                                                variant = "pulse",
                                                showBase = false,
                                                life = 0.72,
                                                innerRadius = 12,
                                                outerRadius = 70,
                                                ringCount = 3,
                                                ringSpacing = 10,
                                                addBlend = true,
                                                color = TREMOR_BLOOM_COLOR,
                                                variantSecondaryColor = {0.52, 0.44, 0.96, 0.8},
                                                variantTertiaryColor = {1.0, 0.84, 0.38, 0.56},
                                        },
                                }

                                celebrateUpgrade(activationLabel, data, celebrationOptions)

                                if hazardPositions and #hazardPositions > 0 then
                                        for _, pos in ipairs(hazardPositions) do
                                                local hx, hy = pos[1], pos[2]
                                                if hx and hy then
                                                        celebrateUpgrade(nil, nil, {
                                                                x = hx,
                                                                y = hy,
                                                                skipText = true,
                                                                color = TREMOR_BLOOM_COLOR,
                                                                particleCount = 8,
                                                                particleSpeed = 90,
                                                                particleLife = 0.32,
                                                                visual = {
                                                                        variant = "pulse",
                                                                        showBase = false,
                                                                        life = 0.5,
                                                                        innerRadius = 8,
                                                                        outerRadius = 40,
                                                                        ringCount = 2,
                                                                        ringSpacing = 7,
                                                                        addBlend = true,
                                                                        color = TREMOR_BLOOM_COLOR,
                                                                        variantSecondaryColor = {0.52, 0.44, 0.96, 0.7},
                                                                        variantTertiaryColor = {1.0, 0.84, 0.38, 0.48},
                                                                },
                                                        })
                                                end
                                        end
                                end
                        end,
                },
        }),
        register({
                id = "contract_of_cinders",
                nameKey = "upgrades.contract_of_cinders.name",
                descKey = "upgrades.contract_of_cinders.description",
                rarity = "rare",
                tags = {"defense", "risk", "hazard"},
                onAcquire = function(state)
                        grantShields(2)
                        if state then
                                state.counters = state.counters or {}
                                state.counters.contractOfCindersPendingSaws = state.counters.contractOfCindersPendingSaws or 0
                        end

                        local emberColor = {1.0, 0.46, 0.18, 1}
                        local celebrationOptions = {
                                color = emberColor,
                                particleCount = 18,
                                particleSpeed = 150,
                                particleLife = 0.52,
                                textOffset = 46,
                                textScale = 1.14,
                                particles = {
                                        count = 16,
                                        speed = 170,
                                        speedVariance = 60,
                                        life = 0.58,
                                        size = 3.4,
                                        spread = pi * 0.6,
                                        angleOffset = -pi / 2,
                                        angleJitter = pi * 0.5,
                                        drag = 1.6,
                                        gravity = -220,
                                        fadeTo = 0.05,
                                },
                        }
                        applySegmentPosition(celebrationOptions, 0.42)
                        celebrateUpgrade(getUpgradeString("contract_of_cinders", "name"), nil, celebrationOptions)
                end,
                handlers = {
                        shieldConsumed = function(data, state)
                                if not state or getStacks(state, "contract_of_cinders") <= 0 then
                                        return
                                end

                                state.counters = state.counters or {}
                                state.counters.contractOfCindersPendingSaws = (state.counters.contractOfCindersPendingSaws or 0) + 1

                                local emberColor = {1.0, 0.46, 0.18, 1}
                                celebrateUpgrade(nil, data, {
                                        skipText = true,
                                        color = emberColor,
                                        particles = {
                                                count = 9,
                                                speed = 180,
                                                speedVariance = 70,
                                                life = 0.64,
                                                size = 3.0,
                                                spread = pi * 0.32,
                                                angleOffset = -pi / 2,
                                                angleJitter = pi * 0.36,
                                                drag = 1.9,
                                                gravity = -250,
                                                fadeTo = 0.04,
                                        },
                                })
                        end,
                },
        }),
        register({
                id = "subduction_array",
                nameKey = "upgrades.subduction_array.name",
                descKey = "upgrades.subduction_array.description",
                rarity = "uncommon",
		tags = {"defense"},
                onAcquire = function(state)
                        if state and state.effects then
                                state.effects.sawSinkDuration = (state.effects.sawSinkDuration or 0) + SUBDUCTION_ARRAY_SINK_DURATION
                        end

			local celebrationOptions = {
				color = {0.68, 0.86, 1.0, 1},
				skipVisuals = true,
				skipParticles = true,
				textOffset = 46,
				textScale = 1.1,
			}

			celebrateUpgrade(getUpgradeString("subduction_array", "name"), nil, celebrationOptions)
		end,
		handlers = {
			fruitCollected = function(data, state)
				if getStacks(state, "subduction_array") <= 0 then
					return
				end

                                local duration = SUBDUCTION_ARRAY_SINK_DURATION
                                if state and state.effects then
                                        local stackedDuration = state.effects.sawSinkDuration or 0
                                        if stackedDuration > 0 then
                                                duration = stackedDuration
                                        end
                                end

				if Saws and Saws.sink then
					Saws:sink(duration)
				end

				local sinkColor = {0.68, 0.86, 1.0, 1}
				local activationLabel = getUpgradeString("subduction_array", "activation_text")
				if activationLabel == "" or activationLabel == "upgrades.subduction_array.activation_text" then
					activationLabel = nil
				end
				local celebrationOptions = {
					color = sinkColor,
					textOffset = 48,
					textScale = 1.08,
					particleCount = 16,
					particleSpeed = 100,
					particleLife = 0.46,
				}

				celebrateUpgrade(activationLabel, data, celebrationOptions)

				local sawCenters = getSawCenters(SUBDUCTION_ARRAY_VISUAL_LIMIT)
				if sawCenters and #sawCenters > 0 then
					for _, pos in ipairs(sawCenters) do
						local fx, fy = pos[1], pos[2]
						if fx and fy then
							local sinkOptions = {
								x = fx,
								y = fy,
								color = sinkColor,
								skipText = true,
								particleCount = 10,
								particleSpeed = 80,
								particleLife = 0.4,
								particleSpread = pi * 2,
								particleSpeedVariance = 40,
							}
							celebrateUpgrade(nil, nil, sinkOptions)
						end
					end
				end
			end,
		},
	}),
        register({
                id = "diffraction_barrier",
                nameKey = "upgrades.diffraction_barrier.name",
		descKey = "upgrades.diffraction_barrier.description",
		rarity = "uncommon",
		tags = {"defense"},
                onAcquire = function(state)
                        state.effects.laserChargeMult = (state.effects.laserChargeMult or 1) * 1.25
                        state.effects.laserFireMult = (state.effects.laserFireMult or 1) * 0.8
                        state.effects.laserCooldownFlat = (state.effects.laserCooldownFlat or 0) + 0.5
                        local disruptorColor = {0.76, 0.48, 1.0, 1}
                        state.effects.laserFireColor = disruptorColor
                        state.effects.phaseDisruptor = true
                        celebrateUpgrade(getUpgradeString("diffraction_barrier", "name"), nil, {
                                color = disruptorColor,
                                skipVisuals = true,
                                skipParticles = true,
                                textOffset = 48,
                                textScale = 1.08,
                        })

                        Snake:setPhaseDisruptorActive(true)

                        local laserCenters = getLaserCenters(2)
                        local baseVisual = {
                                variant = "prism_refraction",
                                life = 0.74,
                                innerRadius = 16,
                                outerRadius = 64,
                                addBlend = true,
                                color = {0.76, 0.48, 1.0, 1},
                                variantSecondaryColor = {0.58, 0.34, 1.0, 0.9},
                                variantTertiaryColor = {0.94, 0.78, 1.0, 0.82},
                        }
                        local baseOptions = {
                                color = disruptorColor,
                                skipText = true,
                                particleCount = 14,
                                particleSpeed = 120,
                                particleLife = 0.46,
				visual = baseVisual,
			}
			if laserCenters and #laserCenters > 0 then
				for _, pos in ipairs(laserCenters) do
					local celebration = deepcopy(baseOptions)
					celebration.x = pos[1]
					celebration.y = pos[2]
					celebrateUpgrade(nil, nil, celebration)
				end
			else
				local fallback = deepcopy(baseOptions)
				applySegmentPosition(fallback, 0.18)
				celebrateUpgrade(nil, nil, fallback)
			end
		end,
	}),
	register({
		id = "resonant_shell",
		nameKey = "upgrades.resonant_shell.name",
		descKey = "upgrades.resonant_shell.description",
		rarity = "uncommon",
		requiresTags = {"defense"},
		tags = {"defense"},
		unlockTag = "specialist",
		onAcquire = function(state)
			state.counters.resonantShellPerBonus = 0.35
			state.counters.resonantShellPerCharge = 0.08
			updateResonantShellBonus(state)

			if not state.counters.resonantShellHandlerRegistered then
				state.counters.resonantShellHandlerRegistered = true
				Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
					if not runState then return end
					if getStacks(runState, "resonant_shell") <= 0 then return end
					updateResonantShellBonus(runState)
				end)
			end

			local celebrationOptions = {
				color = {0.8, 0.88, 1, 1},
				particleCount = 18,
				particleSpeed = 120,
				particleLife = 0.48,
				textOffset = 48,
				textScale = 1.12,
				visual = {
					variant = "resonant_shell",
					life = 0.86,
					innerRadius = 12,
					outerRadius = 60,
					addBlend = true,
					glowAlpha = 0.24,
					haloAlpha = 0.16,
					color = {0.8, 0.88, 1, 1},
					variantSecondaryColor = {0.54, 0.76, 1.0, 0.9},
					variantTertiaryColor = {1.0, 0.96, 0.82, 0.75},
				},
			}
			applySegmentPosition(celebrationOptions, 0.52)
			celebrateUpgrade(getUpgradeString("resonant_shell", "name"), nil, celebrationOptions)
		end,
	}),
        register({
                id = "golden_debt",
                nameKey = "upgrades.golden_debt.name",
                descKey = "upgrades.golden_debt.description",
                rarity = "rare",
                tags = {"economy", "risk", "shop", "progression"},
                onAcquire = function(state)
                        state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
                        state.counters = state.counters or {}
                        state.counters.goldenDebtFruitTax = state.counters.goldenDebtFruitTax or 0
                end,
                handlers = {
                        upgradeAcquired = function(data, state)
                                if not state or getStacks(state, "golden_debt") <= 0 then return end
                                if not data or not data.upgrade then return end

                                state.counters = state.counters or {}
                                state.counters.goldenDebtFruitTax = (state.counters.goldenDebtFruitTax or 0) + 1
                                state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1

                                UI:adjustFruitGoal(1)
                        end,
                },
        }),
        register({
                id = "caravan_contract",
                nameKey = "upgrades.caravan_contract.name",
                descKey = "upgrades.caravan_contract.description",
                rarity = "rare",
                tags = {"economy", "risk"},
                allowDuplicates = true,
                onAcquire = function(state)
                        state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
                end,
        }),
        register({
                id = "gilded_obsession",
                nameKey = "upgrades.gilded_obsession.name",
                descKey = "upgrades.gilded_obsession.description",
                rarity = "rare",
                tags = {"economy", "risk", "hazard"},
                onAcquire = function(state)
                        state.effects.shopGuaranteedRare = true
                        state.counters = state.counters or {}
                        state.counters.gildedObsessionPendingHazards = state.counters.gildedObsessionPendingHazards or {}

                        local celebrationOptions = {
                                color = {1.0, 0.84, 0.36, 1},
                                particleCount = 20,
                                particleSpeed = 140,
                                particleLife = 0.5,
                                textOffset = 44,
                                textScale = 1.12,
                        }
                        celebrateUpgrade(getUpgradeString("gilded_obsession", "name"), nil, celebrationOptions)
                end,
                handlers = {
                        upgradeAcquired = function(data, state)
                                if not state or getStacks(state, "gilded_obsession") <= 0 then return end
                                if not data or not data.upgrade or data.upgrade.rarity ~= "rare" then return end

                                state.counters = state.counters or {}
                                local pending = state.counters.gildedObsessionPendingHazards or {}
                                local hazardType = (love.math.random() < 0.5) and "laser" or "saw"
                                pending[#pending + 1] = {type = hazardType}
                                state.counters.gildedObsessionPendingHazards = pending

                                local activationLabel = getUpgradeString("gilded_obsession", "activation_text")
                                celebrateUpgrade(activationLabel, data, {
                                        color = {1.0, 0.84, 0.34, 1},
                                        particleCount = 14,
                                        particleSpeed = 120,
                                        particleLife = 0.46,
                                        textOffset = 40,
                                        textScale = 1.08,
                                })
                        end,
                },
        }),
        register({
                id = "gluttons_wake",
                nameKey = "upgrades.gluttons_wake.name",
                descKey = "upgrades.gluttons_wake.description",
                rarity = "rare",
                tags = {"economy", "risk", "hazard", "rocks"},
                onAcquire = function(state)
                        state.effects.fruitValueMult = (state.effects.fruitValueMult or 1) * 2
                        state.effects.gluttonsWake = true

                        celebrateUpgrade(getUpgradeString("gluttons_wake", "name"), nil, {
                                color = {1.0, 0.7, 0.36, 1},
                                particleCount = 18,
                                particleSpeed = 120,
                                particleLife = 0.5,
                                textOffset = 46,
                                textScale = 1.12,
                        })
                end,
        }),

        register({
                id = "grand_bazaar",
                nameKey = "upgrades.grand_bazaar.name",
                descKey = "upgrades.grand_bazaar.description",
                rarity = "rare",
                tags = {"shop", "economy", "utility", "reward"},
                onAcquire = function(state)
                        state.effects.shopGuaranteedRare = true
                        state.effects.shopMinimumRarity = "uncommon"

                        celebrateUpgrade(getUpgradeString("grand_bazaar", "name"), nil, {
                                color = {0.95, 0.86, 0.62, 1},
                                particleCount = 18,
                                particleSpeed = 120,
                                particleLife = 0.48,
                                textOffset = 46,
                                textScale = 1.1,
                        })
                end,
        }),

        register({
                id = "verdant_bonds",
                nameKey = "upgrades.verdant_bonds.name",
		descKey = "upgrades.verdant_bonds.description",
		rarity = "uncommon",
		tags = {"economy", "defense"},
		allowDuplicates = true,
		maxStacks = 3,
		onAcquire = function(state)
			state.counters = state.counters or {}
			state.counters.verdantBondsProgress = state.counters.verdantBondsProgress or 0
			if not state.counters.verdantBondsHandlerRegistered then
				state.counters.verdantBondsHandlerRegistered = true
				Upgrades:addEventHandler("upgradeAcquired", function(data, runState)
					if not runState then return end
					if getStacks(runState, "verdant_bonds") <= 0 then return end
					if not data or not data.upgrade then return end

					local upgradeTags = data.upgrade.tags
					local hasEconomy = false
					if upgradeTags then
						for _, tag in ipairs(upgradeTags) do
							if tag == "economy" then
								hasEconomy = true
								break
							end
						end
					end

					if not hasEconomy then return end

					runState.counters = runState.counters or {}
					local counters = runState.counters

					local stacks = getStacks(runState, "verdant_bonds")
					if stacks <= 0 then return end

                                       local progress = (counters.verdantBondsProgress or 0) + stacks
                                       progress = min(progress, 9)
                                       local threshold = 3
                                       local shields = floor(progress / threshold)
					counters.verdantBondsProgress = progress - shields * threshold

					if shields <= 0 then return end

                                        Snake:addShields(shields)

					local label = getUpgradeString("verdant_bonds", "activation_text")
					if shields > 1 then
						if label and label ~= "" then
							label = string.format("%s +%d", label, shields)
						else
							label = string.format("+%d", shields)
						end
					end

					celebrateUpgrade(label, data, {
						color = {0.58, 0.88, 0.64, 1},
						particleCount = 14,
						particleSpeed = 120,
						particleLife = 0.48,
						textOffset = 46,
						textScale = 1.1,
						visual = {
							badge = "shield",
							outerRadius = 52,
							innerRadius = 16,
							ringCount = 3,
							life = 0.68,
							glowAlpha = 0.26,
							haloAlpha = 0.18,
						},
					})
				end)
			end
		end,
	}),
	register({
		id = "fresh_supplies",
		nameKey = "upgrades.fresh_supplies.name",
		descKey = "upgrades.fresh_supplies.description",
		rarity = "common",
		tags = {"economy"},
		restockShop = true,
		allowDuplicates = true,
		weight = 0.6,
	}),
	register({
		id = "stone_census",
		nameKey = "upgrades.stone_census.name",
		descKey = "upgrades.stone_census.description",
		rarity = "common",
		requiresTags = {"economy"},
		tags = {"economy", "defense"},
		onAcquire = function(state)
			state.counters.stoneCensusReduction = 0.07
			state.counters.stoneCensusMult = state.counters.stoneCensusMult or 1
			updateStoneCensus(state)

			if not state.counters.stoneCensusHandlerRegistered then
				state.counters.stoneCensusHandlerRegistered = true
				Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
					if not runState then return end
					if getStacks(runState, "stone_census") <= 0 then return end
					updateStoneCensus(runState)
				end)
			end

			celebrateUpgrade(getUpgradeString("stone_census", "name"), nil, {
				color = {0.85, 0.92, 1, 1},
				particleCount = 16,
				particleSpeed = 110,
				particleLife = 0.4,
				textOffset = 44,
				textScale = 1.08,
			})
		end,
	}),
	register({
		id = "guild_ledger",
		nameKey = "upgrades.guild_ledger.name",
		descKey = "upgrades.guild_ledger.description",
		rarity = "uncommon",
		requiresTags = {"economy"},
		tags = {"economy", "defense"},
		onAcquire = function(state)
			state.counters.guildLedgerFlatPerSlot = 0.015
			updateGuildLedger(state)

			if not state.counters.guildLedgerHandlerRegistered then
				state.counters.guildLedgerHandlerRegistered = true
				Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
					if not runState then return end
					if getStacks(runState, "guild_ledger") <= 0 then return end
					updateGuildLedger(runState)
				end)
			end

			celebrateUpgrade(getUpgradeString("guild_ledger", "name"), nil, {
				color = {1, 0.86, 0.46, 1},
				particleCount = 16,
				particleSpeed = 120,
				particleLife = 0.42,
				textOffset = 42,
				textScale = 1.1,
			})
		end,
	}),
	register({
		id = "radiant_charter",
		nameKey = "upgrades.radiant_charter.name",
		descKey = "upgrades.radiant_charter.description",
		rarity = "uncommon",
		requiresTags = {"economy"},
		tags = {"economy", "defense"},
		onAcquire = function(state)
			state.counters = state.counters or {}
			state.counters.radiantCharterLaserPerSlot = 1
			state.counters.radiantCharterSawPerSlot = 1

			updateRadiantCharter(state)

			if not state.counters.radiantCharterHandlerRegistered then
				state.counters.radiantCharterHandlerRegistered = true
				Upgrades:addEventHandler("upgradeAcquired", function(_, runState)
					if not runState then return end
					if getStacks(runState, "radiant_charter") <= 0 then return end
					updateRadiantCharter(runState)
				end)
			end

			celebrateUpgrade(getUpgradeString("radiant_charter", "name"), nil, {
				color = {0.82, 0.94, 1, 1},
				particleCount = 18,
				particleSpeed = 118,
				particleLife = 0.44,
				textOffset = 44,
				textScale = 1.08,
			})
		end,
	}),
       register({
		id = "abyssal_catalyst",
		nameKey = "upgrades.abyssal_catalyst.name",
		descKey = "upgrades.abyssal_catalyst.description",
		rarity = "epic",
		allowDuplicates = false,
		tags = {"defense", "risk"},
		unlockTag = "abyssal_protocols",
		onAcquire = function(state)
			state.effects.laserChargeMult = (state.effects.laserChargeMult or 1) * 0.85
			state.effects.laserFireMult = (state.effects.laserFireMult or 1) * 0.9
			state.effects.laserCooldownFlat = (state.effects.laserCooldownFlat or 0) - 0.5
			state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.2
			state.effects.abyssalCatalyst = (state.effects.abyssalCatalyst or 0) + 1

			grantShields(1)

			local celebrationOptions = {
				color = {0.62, 0.58, 0.94, 1},
				particleCount = 22,
				particleSpeed = 150,
				particleLife = 0.5,
				textOffset = 48,
				textScale = 1.14,
				visual = {
					variant = "abyssal_catalyst",
					showBase = false,
					life = 0.92,
					innerRadius = 13,
					outerRadius = 62,
					addBlend = true,
					color = {0.52, 0.48, 0.92, 1},
					variantSecondaryColor = {0.72, 0.66, 0.98, 0.9},
					variantTertiaryColor = {1.0, 0.84, 1.0, 0.82},
				},
			}
			applySegmentPosition(celebrationOptions, 0.36)
			celebrateUpgrade(getUpgradeString("abyssal_catalyst", "name"), nil, celebrationOptions)
		end,
	}),
	register({
		id = "spectral_harvest",
		nameKey = "upgrades.spectral_harvest.name",
		descKey = "upgrades.spectral_harvest.description",
		rarity = "epic",
		tags = {"economy", "combo"},
		onAcquire = function(state)
                        state.counters.spectralHarvestReady = true
                        Snake:setSpectralHarvestReady(true, {pulse = 0.8, instantIntensity = 0.45})
		end,
		handlers = {
			floorStart = function(_, state)
                                state.counters.spectralHarvestReady = true
                                Snake:setSpectralHarvestReady(true, {pulse = 0.6})
			end,
			fruitCollected = function(_, state)
				if not state.counters.spectralHarvestReady then return end
				state.counters.spectralHarvestReady = false

                                Snake:triggerSpectralHarvest({flash = 1, echo = 1, instantIntensity = 0.55})

                                local Fruit = require("fruit")
                                local FruitEvents = require("fruitevents")

                                local fx, fy = Fruit:getPosition()
                                if not (fx and fy) then return end

                                FruitEvents.handleConsumption(fx, fy)
                                Snake:setSpectralHarvestReady(false)
			end,
		},
	}),
        register({
                id = "tectonic_resolve",
                nameKey = "upgrades.tectonic_resolve.name",
		descKey = "upgrades.tectonic_resolve.description",
		rarity = "rare",
		tags = {"defense"},
		onAcquire = function(state)
                        state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.85
                        state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.20
		end,
	}),
	register({
		id = "titanblood_pact",
		nameKey = "upgrades.titanblood_pact.name",
		descKey = "upgrades.titanblood_pact.description",
		rarity = "epic",
		tags = {"defense", "risk"},
		unlockTag = "abyssal_protocols",
		weight = 1,
		onAcquire = function(state)
                        Snake:addShields(1)
                        Snake:addSpeedMultiplier(1.05)
			Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
			state.effects.titanbloodPact = (state.effects.titanbloodPact or 0) + 1
			if Snake.setTitanbloodStacks then
				Snake:setTitanbloodStacks(state.effects.titanbloodPact)
			end
		end,
	}),
        register({
                id = "chronospiral_core",
                nameKey = "upgrades.chronospiral_core.name",
                descKey = "upgrades.chronospiral_core.description",
                rarity = "rare",
                tags = {"mobility"},
                unlockTag = "combo_mastery",
                onAcquire = function(state)
                        Snake:addSpeedMultiplier(0.75)
                        state.effects.chronospiralCore = true

                        local celebrationOptions = {
                                color = {0.7, 0.76, 1.0, 1},
                                particleCount = 18,
                                particleSpeed = 120,
                                particleLife = 0.5,
                                textOffset = 46,
                                textScale = 1.1,
                                visual = {
                                        variant = "chronospiral_core",
                                        showBase = false,
                                        life = 0.94,
                                        innerRadius = 12,
                                        outerRadius = 60,
                                        addBlend = true,
                                        color = {0.68, 0.78, 1.0, 1},
                                        variantSecondaryColor = {0.82, 0.62, 1.0, 0.92},
                                        variantTertiaryColor = {1.0, 0.92, 0.64, 0.9},
                                },
                        }
                        applySegmentPosition(celebrationOptions, 0.64)
                        celebrateUpgrade(getUpgradeString("chronospiral_core", "name"), nil, celebrationOptions)
                end,
        }),
	register({
		id = "phoenix_echo",
		nameKey = "upgrades.phoenix_echo.name",
		descKey = "upgrades.phoenix_echo.description",
		rarity = "epic",
		tags = {"defense", "risk"},
		unlockTag = "abyssal_protocols",
		onAcquire = function(state)
			state.counters.phoenixEchoCharges = (state.counters.phoenixEchoCharges or 0) + 1
		end,
	}),
	register({
		id = "thunder_dash",
		nameKey = "upgrades.thunder_dash.name",
		descKey = "upgrades.thunder_dash.description",
		rarity = "rare",
		tags = {"mobility"},
		allowDuplicates = false,
		unlockTag = "abilities",
		onAcquire = function(state)
			local dash = state.effects.dash or {}
			dash.duration = dash.duration or 0.35
			dash.cooldown = dash.cooldown or 6
			dash.speedMult = dash.speedMult or 2.4
			dash.breaksRocks = true
			state.effects.dash = dash

			if not state.counters.thunderDashHandlerRegistered then
				state.counters.thunderDashHandlerRegistered = true
				Upgrades:addEventHandler("dashActivated", function(data)
					local label = getUpgradeString("thunder_dash", "activation_text")
					celebrateUpgrade(label, data, {
						color = {1.0, 0.78, 0.32, 1},
						particleCount = 24,
						particleSpeed = 160,
						particleLife = 0.35,
						particleSize = 4,
						particleSpread = pi * 2,
						particleSpeedVariance = 90,
						textOffset = 52,
						textScale = 1.14,
					})
				end)
			end
		end,
	}),
	register({
		id = "sparkstep_relay",
		nameKey = "upgrades.sparkstep_relay.name",
		descKey = "upgrades.sparkstep_relay.description",
		rarity = "uncommon",
		requiresTags = {"mobility"},
		tags = {"mobility", "defense"},
		unlockTag = "stormtech",
		handlers = {
			dashActivated = function(data)
				local fx, fy = getEventPosition(data)
				if Rocks and Rocks.shatterNearest then
					Rocks:shatterNearest(fx or 0, fy or 0, 1)
				end
				if Saws and Saws.stall then
					Saws:stall(0.6)
				end
				celebrateUpgrade(getUpgradeString("sparkstep_relay", "activation_text"), data, {
					color = {1.0, 0.78, 0.36, 1},
					particleCount = 20,
					particleSpeed = 150,
					particleLife = 0.36,
					textOffset = 56,
					textScale = 1.16,
					visual = {
						badge = "bolt",
						outerRadius = 54,
						innerRadius = 18,
						ringCount = 3,
						life = 0.6,
						glowAlpha = 0.32,
						haloAlpha = 0.22,
					},
				})
			end,
		},
	}),
	register({
		id = "chrono_ward",
		nameKey = "upgrades.chrono_ward.name",
		descKey = "upgrades.chrono_ward.description",
		rarity = "rare",
		tags = {"defense", "utility"},
		allowDuplicates = false,
		unlockTag = "timekeeper",
		onAcquire = function(state)
			state.effects = state.effects or {}
			state.effects.chronoWardDuration = CHRONO_WARD_DEFAULT_DURATION
			state.effects.chronoWardScale = CHRONO_WARD_DEFAULT_SCALE

			local celebrationOptions = {
				color = {0.62, 0.86, 1.0, 1},
				particleCount = 16,
				particleSpeed = 110,
				particleLife = 0.42,
				textOffset = 52,
				textScale = 1.12,
				visual = {
					badge = "shield",
					outerRadius = 56,
					innerRadius = 16,
					ringCount = 3,
					life = 0.7,
					glowAlpha = 0.26,
					haloAlpha = 0.18,
				},
			}
			applySegmentPosition(celebrationOptions, 0.36)
			celebrateUpgrade(getUpgradeString("chrono_ward", "name"), nil, celebrationOptions)
		end,
		handlers = {
			shieldConsumed = function(data, state)
				triggerChronoWard(state, data)
			end,
		},
	}),
	register({
		id = "temporal_anchor",
		nameKey = "upgrades.temporal_anchor.name",
		descKey = "upgrades.temporal_anchor.description",
		rarity = "rare",
		tags = {"utility", "defense"},
		allowDuplicates = false,
		unlockTag = "timekeeper",
		onAcquire = function(state)
			local ability = state.effects.timeSlow or {}
			ability.duration = ability.duration or 1.6
			ability.cooldown = ability.cooldown or 8
			ability.timeScale = ability.timeScale or 0.35
			ability.source = ability.source or "temporal_anchor"
			state.effects.timeSlow = ability

			if not state.counters.temporalAnchorHandlerRegistered then
				state.counters.temporalAnchorHandlerRegistered = true
				Upgrades:addEventHandler("timeDilationActivated", function(data)
					local label = getUpgradeString("temporal_anchor", "activation_text")
					celebrateUpgrade(label, data, {
						color = {0.62, 0.84, 1.0, 1},
						particleCount = 26,
						particleSpeed = 120,
						particleLife = 0.5,
						particleSize = 5,
						particleSpread = pi * 2,
						particleSpeedVariance = 70,
						textOffset = 60,
						textScale = 1.12,
					})
				end)
			end
		end,
	}),
	register({
		id = "zephyr_coils",
		nameKey = "upgrades.zephyr_coils.name",
		descKey = "upgrades.zephyr_coils.description",
		rarity = "rare",
		tags = {"mobility", "risk"},
		unlockTag = "stormtech",
		onAcquire = function(state)
			Snake:addSpeedMultiplier(1.15)
			Snake.extraGrowth = (Snake.extraGrowth or 0) + 1
			if state then
				state.counters = state.counters or {}
				local stacks = (state.counters.zephyrCoilsStacks or 0) + 1
				state.counters.zephyrCoilsStacks = stacks
				if Snake.setZephyrCoilsStacks then
					Snake:setZephyrCoilsStacks(stacks)
				end
			elseif Snake.setZephyrCoilsStacks then
				local stacks = (Snake.zephyrCoils and Snake.zephyrCoils.stacks or 0) + 1
				Snake:setZephyrCoilsStacks(stacks)
			end
		end,
	}),
	register({
		id = "event_horizon",
		nameKey = "upgrades.event_horizon.name",
		descKey = "upgrades.event_horizon.description",
		rarity = "legendary",
		tags = {"defense", "mobility"},
		allowDuplicates = false,
		weight = 1,
		unlockTag = "legendary",
		onAcquire = function(state)
			state.effects.wallPortal = true
			celebrateUpgrade(getUpgradeString("event_horizon", "name"), nil, {
				color = {1, 0.86, 0.34, 1},
				particleCount = 32,
				particleSpeed = 160,
				particleLife = 0.6,
				particleSize = 5,
				particleSpread = pi * 2,
				particleSpeedVariance = 90,
				visual = {
					variant = "event_horizon",
					showBase = false,
					life = 0.92,
					innerRadius = 16,
					outerRadius = 62,
					color = {1, 0.86, 0.34, 1},
					variantSecondaryColor = {0.46, 0.78, 1.0, 0.9},
				},
			})
		end,
	}),
}

local function getRarityInfo(rarity)
	return rarities[rarity or "common"] or rarities.common
end

function Upgrades:beginRun()
	self.runState = newRunState()
end

function Upgrades:getEffect(name)
	if not name then return nil end
	return self.runState.effects[name]
end

function Upgrades:hasTag(tag)
	return tag and self.runState.tags[tag] or false
end

function Upgrades:addTag(tag)
	if not tag then return end
	self.runState.tags[tag] = true
end

local function hudText(key, replacements)
	return Localization:get("upgrades.hud." .. key, replacements)
end

local function hudStatus(key)
	if not key or key == "ready" or key == "charging" then
		return nil
	end

	return hudText(key)
end

function Upgrades:getTakenCount(id)
	if not id then return 0 end
	return getStacks(self.runState, id)
end

function Upgrades:addEventHandler(event, handler)
	if not event or type(handler) ~= "function" then return end
	local state = self.runState
	if state and state.addHandler then
		state:addHandler(event, handler)
		return
	end

	local handlers = state and state.handlers and state.handlers[event]
	if not handlers then
		handlers = {}
		if state and state.handlers then
			state.handlers[event] = handlers
		end
	end

	insert(handlers, handler)
end

function Upgrades:notify(event, data)
	local state = self.runState
	if not state then return end

	if state.notify then
		state:notify(event, data)
		return
	end

	local handlers = state.handlers and state.handlers[event]
	if not handlers then return end
	for _, handler in ipairs(handlers) do
		handler(data, state)
	end
end

local function clamp(value, min, max)
	if min and value < min then return min end
	if max and value > max then return max end
	return value
end

function Upgrades:getHUDIndicators()
	local indicators = {}
	local state = self.runState
	if not state then
		return indicators
	end

	local function hasUpgrade(id)
		return getStacks(state, id) > 0
	end

        if hasUpgrade("pocket_springs") then
                local counters = state.counters or {}
		local complete = counters.pocketSpringsComplete
		if not complete then
			local collected = min(counters.pocketSpringsFruit or 0, POCKET_SPRINGS_FRUIT_TARGET)
			local progress = 0
			if POCKET_SPRINGS_FRUIT_TARGET > 0 then
				progress = clamp(collected / POCKET_SPRINGS_FRUIT_TARGET, 0, 1)
			end

			insert(indicators, {
				id = "pocket_springs",
				label = Localization:get("upgrades.pocket_springs.name"),
				accentColor = {0.58, 0.82, 1.0, 1.0},
				stackCount = nil,
				charge = progress,
				chargeLabel = hudText("progress", {
					current = tostring(collected),
					target = tostring(POCKET_SPRINGS_FRUIT_TARGET),
				}),
				status = hudStatus("charging"),
				icon = "shield",
				showBar = true,
			})
		end
	end

	local adrenalineTaken = hasUpgrade("adrenaline_surge")
	local adrenaline = Snake.adrenaline
	if adrenalineTaken or (adrenaline and adrenaline.active) then
		local label = Localization:get("upgrades.adrenaline_surge.name")
		local active = adrenaline and adrenaline.active
		local duration = (adrenaline and adrenaline.duration) or 0
		local timer = (adrenaline and max(adrenaline.timer or 0, 0)) or 0
		local charge
		local chargeLabel

		if active and duration > 0 then
			charge = clamp(timer / duration, 0, 1)
			chargeLabel = hudText("seconds", {seconds = string.format("%.1f", timer)})
		end

		local status = active and hudStatus("active") or hudStatus("ready")

		insert(indicators, {
			id = "adrenaline_surge",
			label = label,
			hideLabel = true,
			accentColor = {1.0, 0.45, 0.45, 1},
			stackCount = nil,
			charge = charge,
			chargeLabel = chargeLabel,
			status = status,
			icon = "bolt",
			showBar = active and charge ~= nil,
		})
	end

	local dashState = Snake.getDashState and Snake:getDashState()
	if dashState then
		local label = Localization:get("upgrades.thunder_dash.name")
		local accent = {1.0, 0.78, 0.32, 1}
		local status
		local charge
		local chargeLabel
		local showBar = false

		if dashState.active and dashState.duration > 0 then
			local remaining = max(dashState.timer or 0, 0)
			charge = clamp(remaining / dashState.duration, 0, 1)
			chargeLabel = hudText("seconds", {seconds = string.format("%.1f", remaining)})
			status = hudStatus("active")
			showBar = true
		else
			local cooldown = dashState.cooldown or 0
			local remainingCooldown = max(dashState.cooldownTimer or 0, 0)
			if cooldown > 0 and remainingCooldown > 0 then
				local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
				charge = progress
				chargeLabel = hudText("seconds", {seconds = string.format("%.1f", remainingCooldown)})
				status = hudStatus("charging")
				showBar = true
			else
				charge = 1
				status = hudStatus("ready")
			end
		end

		insert(indicators, {
			id = "thunder_dash",
			label = label,
			hideLabel = true,
			accentColor = accent,
			stackCount = nil,
			charge = charge,
			chargeLabel = chargeLabel,
			status = status,
			icon = "bolt",
			showBar = showBar,
		})
	end

	local timeState = Snake.getTimeDilationState and Snake:getTimeDilationState()
	if timeState then
		local label = Localization:get("upgrades.temporal_anchor.name")
		local accent = {0.62, 0.84, 1.0, 1}
		local status
		local charge
		local chargeLabel
		local showBar = false

		local chargesRemaining = timeState.floorCharges
		local maxUses = timeState.maxFloorUses

		if timeState.active and timeState.duration > 0 then
			local remaining = max(timeState.timer or 0, 0)
			charge = clamp(remaining / timeState.duration, 0, 1)
			chargeLabel = hudText("seconds", {seconds = string.format("%.1f", remaining)})
			status = hudStatus("active")
			showBar = true
		else
			if maxUses and chargesRemaining ~= nil and chargesRemaining <= 0 then
				charge = 0
				status = hudStatus("depleted")
				chargeLabel = nil
				showBar = false
			else
				local cooldown = timeState.cooldown or 0
				local remainingCooldown = max(timeState.cooldownTimer or 0, 0)
				if cooldown > 0 and remainingCooldown > 0 then
					local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
					charge = progress
					chargeLabel = hudText("seconds", {seconds = string.format("%.1f", remainingCooldown)})
					status = hudStatus("charging")
					showBar = true
				else
					charge = 1
					status = hudStatus("ready")
				end
			end
		end

		insert(indicators, {
			id = "temporal_anchor",
			label = label,
			hideLabel = true,
			accentColor = accent,
			stackCount = nil,
			charge = charge,
			chargeLabel = chargeLabel,
			status = status,
			icon = "hourglass",
			showBar = showBar,
		})
	end

	local phoenixCharges = 0
	if state.counters then
		phoenixCharges = state.counters.phoenixEchoCharges or 0
	end

	if phoenixCharges > 0 then
		local label = Localization:get("upgrades.phoenix_echo.name")
		insert(indicators, {
			id = "phoenix_echo",
			label = label,
			accentColor = {1.0, 0.62, 0.32, 1},
			stackCount = phoenixCharges,
			charge = nil,
			status = nil,
			icon = "phoenix",
			showBar = false,
		})
	end

	return indicators
end

function Upgrades:recordFloorReplaySnapshot(game)
	if not game then return end

	local state = self.runState
	if not state or not state.counters then return end

	-- The phoenix upgrade no longer tracks snake position, so we don't need to
	-- capture any state here.
	return
end

function Upgrades:modifyFloorContext(context)
	if not context then return context end

	local effects = self.runState.effects
	if effects.fruitGoalDelta and context.fruitGoal then
		local goal = context.fruitGoal + effects.fruitGoalDelta
		goal = floor(goal + 0.5)
		context.fruitGoal = clamp(goal, 1)
	end
	if effects.rockSpawnBonus and context.rocks then
		local rocks = context.rocks + effects.rockSpawnBonus
		rocks = floor(rocks + 0.5)
		context.rocks = clamp(rocks, 0)
	end
	if effects.sawSpawnBonus and context.saws then
		local saws = context.saws + effects.sawSpawnBonus
		saws = floor(saws + 0.5)
		context.saws = clamp(saws, 0)
	end
        if effects.laserSpawnBonus and context.laserCount then
                local lasers = context.laserCount + effects.laserSpawnBonus
                lasers = floor(lasers + 0.5)
                context.laserCount = clamp(lasers, 0)
        end

        local state = self.runState
        if state and state.counters then
                local emberPending = state.counters.contractOfCindersPendingSaws
                if emberPending and emberPending > 0 then
                        context.saws = context.saws or 0
                        context.contractOfCindersEmberSaws = (context.contractOfCindersEmberSaws or 0) + emberPending
                        context.saws = context.saws + emberPending
                        state.counters.contractOfCindersActiveSaws = emberPending
                        state.counters.contractOfCindersPendingSaws = 0
                else
                        state.counters.contractOfCindersActiveSaws = nil
                end

                local pending = state.counters.gildedObsessionPendingHazards
                if pending and #pending > 0 then
                        context.saws = context.saws or 0
                        context.laserCount = context.laserCount or 0
                        local active = {saws = 0, lasers = 0}

                        for _, hazard in ipairs(pending) do
                                local hazardType = hazard and hazard.type or nil
                                if hazardType == "laser" then
                                        context.laserCount = context.laserCount + 1
                                        active.lasers = (active.lasers or 0) + 1
                                else
                                        context.saws = context.saws + 1
                                        active.saws = (active.saws or 0) + 1
                                end
                        end

                        state.counters.gildedObsessionActiveHazards = active
                        state.counters.gildedObsessionPendingHazards = {}
                        context.gildedObsessionExtraSaws = active.saws
                        context.gildedObsessionExtraLasers = active.lasers
                end
        end

        return context
end

function Upgrades:consumeGildedObsessionHazards()
        local state = self.runState
        if not state or not state.counters then
                return nil
        end

        local active = state.counters.gildedObsessionActiveHazards
        state.counters.gildedObsessionActiveHazards = nil
        return active
end

local function round(value)
	if value >= 0 then
		return floor(value + 0.5)
	else
		return -floor(math.abs(value) + 0.5)
	end
end

function Upgrades:getComboBonus(comboCount)
	local bonus = 0
	local breakdown = {}

	if not comboCount or comboCount < 2 then
		return bonus, breakdown
	end

	local effects = self.runState.effects
	local flat = (effects.comboBonusFlat or 0) * (comboCount - 1)
	if flat ~= 0 then
		local amount = round(flat)
		if amount ~= 0 then
			bonus = bonus + amount
			insert(breakdown, {label = Localization:get("upgrades.momentum_label"), amount = amount})
		end
	end

	return bonus, breakdown
end

function Upgrades:tryFloorReplay(game, cause)
	if not game then return false end

	local state = self.runState
	if not state or not state.counters then return false end

	local charges = state.counters.phoenixEchoCharges or 0
	if charges <= 0 then return false end

	state.counters.phoenixEchoCharges = charges - 1
	state.counters.phoenixEchoUsed = (state.counters.phoenixEchoUsed or 0) + 1
	state.counters.phoenixEchoLastCause = cause

	game.transitionPhase = nil
	game.transitionTimer = 0
	game.transitionDuration = 0
	game.shopCloseRequested = nil
	game.transitionResumePhase = nil
	game.transitionResumeFadeDuration = nil

	local restored = false
	Snake:resetPosition()
	restored = true

	game.state = "playing"
	game.deathCause = nil

	local hx, hy = Snake:getHead()
	celebrateUpgrade(getUpgradeString("phoenix_echo", "name"), nil, {
		x = hx,
		y = hy,
		color = {1, 0.62, 0.32, 1},
		particleCount = 24,
		particleSpeed = 170,
		particleLife = 0.6,
		textOffset = 60,
		textScale = 1.22,
		visual = {
			variant = "phoenix_flare",
			showBase = false,
			life = 1.18,
			innerRadius = 16,
			outerRadius = 58,
			addBlend = true,
			color = {1, 0.62, 0.32, 1},
			variantSecondaryColor = {1, 0.44, 0.14, 0.95},
			variantTertiaryColor = {1, 0.85, 0.48, 0.88},
		},
	})

	self:applyPersistentEffects(false)
	if Snake.setPhoenixEchoCharges then
		Snake:setPhoenixEchoCharges(state.counters.phoenixEchoCharges or 0, {triggered = 1.4, flareDuration = 1.4})
	end

	return restored
end

local function captureBaseline(state)
	local baseline = state.baseline
	baseline.sawSpeedMult = Saws.speedMult or 1
	baseline.sawSpinMult = Saws.spinMult or 1
	if Saws.getStallOnFruit then
		baseline.sawStall = Saws:getStallOnFruit()
	else
		baseline.sawStall = Saws.stallOnFruit or 0
	end
	if Rocks.getSpawnChance then
		baseline.rockSpawnChance = Rocks:getSpawnChance()
	else
		baseline.rockSpawnChance = Rocks.spawnChance or 0.25
	end
	baseline.rockShatter = Rocks.shatterOnFruit or 0
	if Score.getComboBonusMultiplier then
		baseline.comboBonusMult = Score:getComboBonusMultiplier()
	else
		baseline.comboBonusMult = Score.comboBonusMult or 1
	end
	if Lasers then
		baseline.laserChargeMult = Lasers.chargeDurationMult or 1
		baseline.laserChargeFlat = Lasers.chargeDurationFlat or 0
		baseline.laserFireMult = Lasers.fireDurationMult or 1
		baseline.laserFireFlat = Lasers.fireDurationFlat or 0
		baseline.laserCooldownMult = Lasers.cooldownMult or 1
		baseline.laserCooldownFlat = Lasers.cooldownFlat or 0
	end
end

local function ensureBaseline(state)
	state.baseline = state.baseline or {}
	if not next(state.baseline) then
		captureBaseline(state)
	end
end

function Upgrades:applyPersistentEffects(rebaseline)
	local state = self.runState
	local effects = state.effects

	if rebaseline then
		state.baseline = {}
	end
	ensureBaseline(state)
	local base = state.baseline

	local sawSpeed = (base.sawSpeedMult or 1) * (effects.sawSpeedMult or 1)
	local sawSpin = (base.sawSpinMult or 1) * (effects.sawSpinMult or 1)
	Saws.speedMult = sawSpeed
	Saws.spinMult = sawSpin

	local stallBase = base.sawStall or 0
	local stallBonus = effects.sawStall or 0
	local stallValue = stallBase + stallBonus
	if Saws.setStallOnFruit then
		Saws:setStallOnFruit(stallValue)
	else
		Saws.stallOnFruit = stallValue
	end

        local rockBase = base.rockSpawnChance or 0.25
        local rockChance = max(0.02, rockBase * (effects.rockSpawnMult or 1) + (effects.rockSpawnFlat or 0))
        Rocks.spawnChance = rockChance
        Rocks.shatterOnFruit = (base.rockShatter or 0) + (effects.rockShatter or 0)

	local comboBase = base.comboBonusMult or 1
	local comboMult = comboBase * (effects.comboBonusMult or 1)
	if Score.setComboBonusMultiplier then
		Score:setComboBonusMultiplier(comboMult)
	else
		Score.comboBonusMult = comboMult
	end

        if Lasers then
                Lasers.chargeDurationMult = (base.laserChargeMult or 1) * (effects.laserChargeMult or 1)
                Lasers.chargeDurationFlat = (base.laserChargeFlat or 0) + (effects.laserChargeFlat or 0)
                Lasers.fireDurationMult = (base.laserFireMult or 1) * (effects.laserFireMult or 1)
                Lasers.fireDurationFlat = (base.laserFireFlat or 0) + (effects.laserFireFlat or 0)
                Lasers.cooldownMult = (base.laserCooldownMult or 1) * (effects.laserCooldownMult or 1)
                Lasers.cooldownFlat = (base.laserCooldownFlat or 0) + (effects.laserCooldownFlat or 0)
                if Lasers.applyTimingModifiers then
                        Lasers:applyTimingModifiers()
                end
                if Lasers.setFireColorOverride then
                        Lasers:setFireColorOverride(effects.laserFireColor)
                end
        end

       if effects.adrenaline then
               Snake.adrenaline = Snake.adrenaline or {}
               Snake.adrenaline.active = Snake.adrenaline.active or false
               Snake.adrenaline.timer = Snake.adrenaline.timer or 0
               local duration = (effects.adrenaline.duration or 3) + (effects.adrenalineDurationBonus or 0)
               Snake.adrenaline.duration = duration
               local boost = (effects.adrenaline.boost or 1.5) + (effects.adrenalineBoostBonus or 0)
               Snake.adrenaline.boost = boost
       end

	if effects.dash then
		Snake.dash = Snake.dash or {}
		local dash = Snake.dash
		local firstSetup = not dash.configured
		dash.duration = effects.dash.duration or dash.duration or 0
		dash.cooldown = effects.dash.cooldown or dash.cooldown or 0
		dash.speedMult = effects.dash.speedMult or dash.speedMult or 1
		dash.breaksRocks = effects.dash.breaksRocks ~= false
		dash.configured = true
		dash.timer = dash.timer or 0
		dash.cooldownTimer = dash.cooldownTimer or 0
		dash.active = dash.active or false
		if firstSetup then
			dash.active = false
			dash.timer = 0
			dash.cooldownTimer = 0
		else
			if dash.cooldown and dash.cooldown > 0 then
				dash.cooldownTimer = min(dash.cooldownTimer or 0, dash.cooldown)
			else
				dash.cooldownTimer = 0
			end
		end
	else
		Snake.dash = nil
	end

	if effects.timeSlow then
		Snake.timeDilation = Snake.timeDilation or {}
		local ability = Snake.timeDilation
		local firstSetup = not ability.configured
		ability.duration = effects.timeSlow.duration or ability.duration or 0
		ability.cooldown = effects.timeSlow.cooldown or ability.cooldown or 0
		ability.timeScale = effects.timeSlow.timeScale or ability.timeScale or 1
		ability.configured = true
		ability.timer = ability.timer or 0
		ability.cooldownTimer = ability.cooldownTimer or 0
		ability.active = ability.active or false
		if firstSetup then
			ability.active = false
			ability.timer = 0
			ability.cooldownTimer = 0
		else
			if rebaseline then
				ability.active = false
				ability.timer = 0
				ability.cooldownTimer = 0
			elseif ability.cooldown and ability.cooldown > 0 then
				ability.cooldownTimer = min(ability.cooldownTimer or 0, ability.cooldown)
			else
				ability.cooldownTimer = 0
			end
		end

		ability.maxFloorUses = 1
		if firstSetup or rebaseline then
			ability.floorCharges = ability.maxFloorUses
		elseif ability.floorCharges == nil then
			ability.floorCharges = ability.maxFloorUses
		else
			local maxUses = ability.maxFloorUses or ability.floorCharges
			ability.floorCharges = max(0, min(ability.floorCharges, maxUses))
		end
	else
		Snake.timeDilation = nil
	end

	if Snake.setChronospiralActive then
		Snake:setChronospiralActive(effects.chronospiralCore and true or false)
	end

	if Snake.setAbyssalCatalystStacks then
		Snake:setAbyssalCatalystStacks(effects.abyssalCatalyst or 0)
	end

	if Snake.setTitanbloodStacks then
		Snake:setTitanbloodStacks(effects.titanbloodPact or 0)
	end

	if Snake.setEventHorizonActive then
		Snake:setEventHorizonActive(effects.wallPortal and true or false)
	end

	if Snake.setPhaseDisruptorActive then
		Snake:setPhaseDisruptorActive(effects.phaseDisruptor and true or false)
	end

	if Snake.setQuickFangsStacks then
		local counters = state.counters or {}
		Snake:setQuickFangsStacks(counters.quickFangsStacks or 0)
	end

	if Snake.setPhoenixEchoCharges then
		local counters = state.counters or {}
		Snake:setPhoenixEchoCharges(counters.phoenixEchoCharges or 0)
	end
end

local SHOP_PITY_MAX = 5
local SHOP_PITY_RARITY_BONUS = {
	rare = 0.24,
	epic = 0.4,
	legendary = 0.65,
}

local LEGENDARY_PITY_THRESHOLD = 5

local SHOP_PITY_RARITY_RANK = {
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
}

local function calculateWeight(upgrade, pityLevel)
	local rarityInfo = getRarityInfo(upgrade.rarity)
	local rarityWeight = rarityInfo.weight or 1
	local weight = rarityWeight * (upgrade.weight or 1)

	local bonus = SHOP_PITY_RARITY_BONUS[upgrade.rarity]
	if bonus and pityLevel and pityLevel > 0 then
		weight = weight * (1 + min(pityLevel, SHOP_PITY_MAX) * bonus)
	end

	return weight
end

function Upgrades:canOffer(upgrade, context, allowTaken)
	if not upgrade then return false end

	local count = self:getTakenCount(upgrade.id)
	if upgrade.rarity == "legendary" and count > 0 then
		return false
	end

	if not allowTaken then
		if (count > 0 and not upgrade.allowDuplicates) then
			return false
		end
		if upgrade.maxStacks and count >= upgrade.maxStacks then
			return false
		end
	end

	if upgrade.requiresTags then
		for _, tag in ipairs(upgrade.requiresTags) do
			if not self:hasTag(tag) then
				return false
			end
		end
	end

	if upgrade.excludesTags then
		for _, tag in ipairs(upgrade.excludesTags) do
			if self:hasTag(tag) then
				return false
			end
		end
	end

	local combinedUnlockTags = nil
	if type(upgrade.unlockTags) == "table" then
		combinedUnlockTags = {}
		for _, tag in ipairs(upgrade.unlockTags) do
			combinedUnlockTags[#combinedUnlockTags + 1] = tag
		end
	end
	if upgrade.unlockTag then
		combinedUnlockTags = combinedUnlockTags or {}
		combinedUnlockTags[#combinedUnlockTags + 1] = upgrade.unlockTag
	end

	if combinedUnlockTags and MetaProgression and MetaProgression.isTagUnlocked then
		for _, tag in ipairs(combinedUnlockTags) do
			if tag and not MetaProgression:isTagUnlocked(tag) then
				return false
			end
		end
	elseif upgrade.unlockTag and MetaProgression and MetaProgression.isTagUnlocked then
		if not MetaProgression:isTagUnlocked(upgrade.unlockTag) then
			return false
		end
	end

	if upgrade.condition and not upgrade.condition(self.runState, context) then
		return false
	end

	return true
end

local function decorateCard(upgrade)
	local rarityInfo = getRarityInfo(upgrade.rarity)
	local name = upgrade.name
	local description = upgrade.desc
	local rarityLabel = rarityInfo and rarityInfo.label

	if upgrade.nameKey then
		name = Localization:get(upgrade.nameKey)
	end
	if upgrade.descKey then
		description = Localization:get(upgrade.descKey)
	end
	if rarityInfo and rarityInfo.labelKey then
		rarityLabel = Localization:get(rarityInfo.labelKey)
	end

	return {
		id = upgrade.id,
		name = name,
		desc = description,
		rarity = upgrade.rarity,
		rarityColor = rarityInfo.color,
		rarityLabel = rarityLabel,
		restockShop = upgrade.restockShop,
		upgrade = upgrade,
	}
end

function Upgrades:getRandom(n, context)
        local state = self.runState or newRunState()
        local pityLevel = 0
        if state and state.counters then
                pityLevel = min(state.counters.shopBadLuck or 0, SHOP_PITY_MAX)
        end

        local minimumRank = 0
        if state and state.effects then
                local effects = state.effects
                if type(effects.shopMinimumRarityRank) == "number" then
                        minimumRank = effects.shopMinimumRarityRank
                elseif effects.shopMinimumRarity and SHOP_PITY_RARITY_RANK[effects.shopMinimumRarity] then
                        minimumRank = SHOP_PITY_RARITY_RANK[effects.shopMinimumRarity]
                end
        end

        local available = {}
        for _, upgrade in ipairs(pool) do
                if self:canOffer(upgrade, context, false) then
                        local rarityRank = SHOP_PITY_RARITY_RANK[upgrade.rarity] or 0
                        if rarityRank >= minimumRank then
                                insert(available, upgrade)
                        end
                end
        end

        if #available == 0 then
                for _, upgrade in ipairs(pool) do
                        if self:canOffer(upgrade, context, true) then
                                local rarityRank = SHOP_PITY_RARITY_RANK[upgrade.rarity] or 0
                                if rarityRank >= minimumRank then
                                        insert(available, upgrade)
                                end
                        end
                end
        end

        local cards = {}
        n = min(n or 3, #available)
        for _ = 1, n do
		local totalWeight = 0
		local weights = {}
		for i, upgrade in ipairs(available) do
			local weight = calculateWeight(upgrade, pityLevel)
			totalWeight = totalWeight + weight
			weights[i] = weight
		end

		if totalWeight <= 0 then break end

		local roll = love.math.random() * totalWeight
		local cumulative = 0
		local chosenIndex = 1
		for i, weight in ipairs(weights) do
			cumulative = cumulative + weight
			if roll <= cumulative then
				chosenIndex = i
				break
			end
		end

                local choice = available[chosenIndex]
                insert(cards, decorateCard(choice))
                table.remove(available, chosenIndex)
                if #available == 0 then break end
        end

        local guaranteeRare = state and state.effects and state.effects.shopGuaranteedRare
        if guaranteeRare and #cards > 0 then
                local hasRare = false
                for _, card in ipairs(cards) do
                        if card.rarity == "rare" then
                                hasRare = true
                                break
                        end
                end

                if not hasRare then
                        local rareChoices = {}
                        for _, upgrade in ipairs(pool) do
                                if upgrade.rarity == "rare" and self:canOffer(upgrade, context, false) then
                                        local rarityRank = SHOP_PITY_RARITY_RANK[upgrade.rarity] or 0
                                        if rarityRank >= minimumRank then
                                                insert(rareChoices, upgrade)
                                        end
                                end
                        end

                        if #rareChoices == 0 then
                                for _, upgrade in ipairs(pool) do
                                        if upgrade.rarity == "rare" and self:canOffer(upgrade, context, true) then
                                                local rarityRank = SHOP_PITY_RARITY_RANK[upgrade.rarity] or 0
                                                if rarityRank >= minimumRank then
                                                        insert(rareChoices, upgrade)
                                                end
                                        end
                                end
                        end

                        if #rareChoices > 0 then
                                local replacementIndex
                                local lowestRank
                                for index, card in ipairs(cards) do
                                        local rank = SHOP_PITY_RARITY_RANK[card.rarity] or 0
                                        if not replacementIndex or rank < lowestRank then
                                                replacementIndex = index
                                                lowestRank = rank
                                        end
                                end

                                if replacementIndex then
                                        local choice = rareChoices[love.math.random(1, #rareChoices)]
                                        cards[replacementIndex] = decorateCard(choice)
                                else
                                        cards[#cards + 1] = decorateCard(rareChoices[love.math.random(1, #rareChoices)])
                                end
                        end
                end
        end

        if state and state.counters then
                local bestRank = 0
                for _, card in ipairs(cards) do
                        local rank = SHOP_PITY_RARITY_RANK[card.rarity] or 0
                        if rank > bestRank then
                                bestRank = rank
                        end
                end

		if bestRank >= (SHOP_PITY_RARITY_RANK.rare or 0) then
			state.counters.shopBadLuck = 0
		else
			local counter = (state.counters.shopBadLuck or 0) + 1
			state.counters.shopBadLuck = min(counter, SHOP_PITY_MAX)
		end

		local legendaryUnlocked = MetaProgression and MetaProgression.isTagUnlocked and MetaProgression:isTagUnlocked("legendary")
		if legendaryUnlocked then
			local hasLegendary = false
			for _, card in ipairs(cards) do
				if card.rarity == "legendary" then
					hasLegendary = true
					break
				end
			end

			if hasLegendary then
				state.counters.legendaryBadLuck = 0
			else
				local legendaryCounter = (state.counters.legendaryBadLuck or 0) + 1
				if legendaryCounter >= LEGENDARY_PITY_THRESHOLD then
					local legendaryChoices = {}
					for _, upgrade in ipairs(pool) do
						if upgrade.rarity == "legendary" and self:canOffer(upgrade, context, false) then
							insert(legendaryChoices, decorateCard(upgrade))
						end
					end
					if #legendaryChoices == 0 then
						for _, upgrade in ipairs(pool) do
							if upgrade.rarity == "legendary" and self:canOffer(upgrade, context, true) then
								insert(legendaryChoices, decorateCard(upgrade))
							end
						end
					end

					if #legendaryChoices > 0 then
						local replacementIndex
						local lowestRank
						for index, card in ipairs(cards) do
							local rank = SHOP_PITY_RARITY_RANK[card.rarity] or 0
							if not replacementIndex or rank < lowestRank then
								replacementIndex = index
								lowestRank = rank
							end
						end

						if replacementIndex then
							cards[replacementIndex] = legendaryChoices[love.math.random(1, #legendaryChoices)]
						else
							insert(cards, legendaryChoices[love.math.random(1, #legendaryChoices)])
						end

						legendaryCounter = 0
					end
				end

				state.counters.legendaryBadLuck = min(legendaryCounter, LEGENDARY_PITY_THRESHOLD)
			end
		else
			state.counters.legendaryBadLuck = nil
		end
	end

	return cards
end

function Upgrades:acquire(card, context)
	if not card or not card.upgrade then return end

	local upgrade = card.upgrade
	local state = self.runState

	if state and state.addStacks then
		state:addStacks(upgrade.id, 1)
	else
		local currentStacks = getStacks(state, upgrade.id)
		state.takenSet[upgrade.id] = currentStacks + 1
	end
	insert(state.takenOrder, upgrade.id)

	PlayerStats:add("totalUpgradesPurchased", 1)
	PlayerStats:updateMax("mostUpgradesInRun", #state.takenOrder)

	if upgrade.rarity == "legendary" then
		PlayerStats:add("legendaryUpgradesPurchased", 1)
	end

	if upgrade.tags then
		for _, tag in ipairs(upgrade.tags) do
			self:addTag(tag)
		end
	end

	if upgrade.onAcquire then
		upgrade.onAcquire(state, context)
	end

	if upgrade.handlers then
		for event, handler in pairs(upgrade.handlers) do
			self:addEventHandler(event, handler)
		end
	end

	self:notify("upgradeAcquired", {id = upgrade.id, upgrade = upgrade, context = context})
	self:applyPersistentEffects(false)
end

return Upgrades
