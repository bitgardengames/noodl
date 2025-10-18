local Face = require("face")
local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Score = require("score")
local UI = require("ui")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local PlayerStats = require("playerstats")
local UpgradeHelpers = require("upgradehelpers")
local DataSchemas = require("dataschemas")

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

	table.insert(handlers, handler)
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

function RunState:resetEffects(defaults)
	self.effects = deepcopy(defaults or defaultEffects)
end

local POCKET_SPRINGS_FRUIT_TARGET = 20
local CHRONO_WARD_DEFAULT_DURATION = 0.85
local CHRONO_WARD_DEFAULT_SCALE = 0.45

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
        amount = math.max(0, math.floor((amount or 0) + 0.0001))
        if amount <= 0 then
                return 0
        end

        if Snake and Snake.addShields then
                Snake:addShields(amount)
                return amount
        end

        return 0
end

local function getSegmentPosition(fraction)
        if not Snake or not Snake.getSegments then
                if Snake and Snake.getHead then
                        return Snake:getHead()
                end
                return nil, nil
        end

        local segments = Snake:getSegments()
        local count = segments and #segments or 0
        if count <= 0 then
                if Snake and Snake.getHead then
                        return Snake:getHead()
                end
                return nil, nil
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
                index = math.floor(scaled + 0.5) + 1
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

        if Snake and Snake.getHead then
                return Snake:getHead()
        end

        return nil, nil
end

local function triggerChronoWard(state, data)
        if not Snake or not Snake.triggerChronoWard then
                return
        end

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
        local maxCount = math.min(limit or count, count)
        for index = 1, maxCount do
                local item = source[index]
                if item then
                        local px, py = extractor(item)
                        if px and py then
                                result[#result + 1] = { px, py }
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
                local shields = math.floor(progress + 1e-6)
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

	if perBonus > 0 then
		local previous = state.counters.resonantShellBonus or 0
		local newBonus = perBonus * defenseCount
		state.counters.resonantShellBonus = newBonus
		state.effects.sawStall = (state.effects.sawStall or 0) - previous + newBonus
	end

	if perCharge > 0 then
		local previousCharge = state.counters.resonantShellChargeBonus or 0
		local newCharge = perCharge * defenseCount
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

        slots = math.max(0, math.floor(slots + 0.0001))

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
	local newMult = math.max(0.2, 1 - perEconomy * economyCount)

	state.counters.stoneCensusMult = newMult
	effects.rockSpawnMult = effects.rockSpawnMult * newMult
	state.effects = effects
end

local function handleBulwarkChorusFloorStart(_, state)
	if not state or not state.counters then return end
	if getStacks(state, "wardens_chorus") <= 0 then return end

	local perDefense = state.counters.bulwarkChorusPerDefense or 0
	if perDefense <= 0 then return end

	local defenseCount = countUpgradesWithTag(state, "defense")
	if defenseCount <= 0 then return end

	local progress = (state.counters.bulwarkChorusProgress or 0) + perDefense * defenseCount
	local shields = math.floor(progress)
	state.counters.bulwarkChorusProgress = progress - shields

        if shields > 0 and Snake.addShields then
                Snake:addShields(shields)
                celebrateUpgrade(nil, nil, {
			skipText = true,
			color = {0.7, 0.9, 1.0, 1},
			skipParticles = true,
			visual = {
				badge = "shield",
				outerRadius = 54,
				innerRadius = 14,
				ringCount = 3,
				life = 0.85,
				glowAlpha = 0.24,
				haloAlpha = 0.15,
			},
		})
	end
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
		table.insert(candidates, { info = entry, value = value })
	end

	table.sort(candidates, function(a, b)
		if a.value == b.value then
			return (a.info.priority or 0) < (b.info.priority or 0)
		end
		return (a.value or 0) > (b.value or 0)
	end)

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

	local reduction = 1 + math.floor((stacks - 1) * 0.5)
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
	applyMapmakersCompass(state, context, { celebrate = true, eventData = data })
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
                                        }
                                end
                        end
                end
        end

        return targets
end

local pool = {
        register({
		id = "quick_fangs",
		nameKey = "upgrades.quick_fangs.name",
		descKey = "upgrades.quick_fangs.description",
		rarity = "uncommon",
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

                        if Face and Face.set then
                                Face:set("veryHappy", 1.6)
                        end

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
                        if Face and Face.set then
                                Face:set("blank", 1.8)
                        end
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
                                if state.counters.aegisRecycler >= 2 then
                                        state.counters.aegisRecycler = state.counters.aegisRecycler - 2
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
		onAcquire = function(state)
			state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
			state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 1.15
                        if UI.adjustFruitGoal then
                                UI:adjustFruitGoal(-1)
                        end
                        if Face and Face.set then
                                Face:set("angry", 1.4)
                        end
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
                        state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
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
                        if UI.adjustFruitGoal then
                                UI:adjustFruitGoal(1)
                        end
                        if Face and Face.set then
                                Face:set("sad", 2.0)
                        end
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

			if state.counters.mapmakersCompassLastContext then
				applyMapmakersCompass(state, state.counters.mapmakersCompassLastContext, { celebrate = false })
			end
		end,
	}),
        register({
                id = "momentum_memory",
                nameKey = "upgrades.momentum_memory.name",
                descKey = "upgrades.momentum_memory.description",
                rarity = "uncommon",
		requiresTags = {"adrenaline"},
		onAcquire = function(state)
			state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
			state.effects.adrenalineDurationBonus = (state.effects.adrenalineDurationBonus or 0) + 2
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
				Snake.adrenaline.timer = math.max(currentTimer, surgeDuration)
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
                rarity = "uncommon",
                onAcquire = function(state)
                        state.effects.sawStall = (state.effects.sawStall or 0) + 1
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
                                                spread = math.pi * 0.45,
                                                angleJitter = math.pi * 0.18,
                                                gravity = 200,
                                                drag = 1.5,
                                                fadeTo = 0,
                                                scaleMin = 0.4,
                                                scaleVariance = 0.26,
                                        },
                                }
                                local targets = buildCircuitBreakerTargets(data)
                                if not targets or #targets == 0 then
                                        targets = {}
                                        local sawCenters = getSawCenters(2)
                                        if sawCenters and #sawCenters > 0 then
                                                for _, pos in ipairs(sawCenters) do
                                                        if pos then
                                                                targets[#targets + 1] = {
                                                                        x = pos[1],
                                                                        y = pos[2],
                                                                }
                                                        end
                                                end
                                        end
                                end
                                if targets and #targets > 0 then
                                        local limit = math.min(#targets, 2)
                                        for i = 1, limit do
                                                local target = targets[i]
                                                if target then
                                                        local sparkOptions = deepcopy(baseOptions)
                                                        sparkOptions.x = target.x
                                                        sparkOptions.y = target.y
                                                        local dirX, dirY = getSawFacingDirection(target)
                                                        applyCircuitBreakerFacing(sparkOptions, dirX, dirY)
                                                        celebrateUpgrade(nil, nil, sparkOptions)
                                                end
                                        end
                                else
                                        local fallbackOptions = deepcopy(baseOptions)
                                        applySegmentPosition(fallbackOptions, 0.82)
                                        applyCircuitBreakerFacing(fallbackOptions, 0, -1)
                                        celebrateUpgrade(nil, nil, fallbackOptions)
                                end
                        end,
                },
        }),
        register({
                id = "stonebreaker_hymn",
                nameKey = "upgrades.stonebreaker_hymn.name",
                descKey = "upgrades.stonebreaker_hymn.description",
                rarity = "rare",
                allowDuplicates = true,
                maxStacks = 2,
                onAcquire = function(state)
                        state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
                        state.counters.stonebreakerStacks = (state.counters.stonebreakerStacks or 0) + 1
                        if Snake.setStonebreakerStacks then
                                Snake:setStonebreakerStacks(state.counters.stonebreakerStacks)
                        end
                        celebrateUpgrade(getUpgradeString("stonebreaker_hymn", "name"), nil, {
                                color = {0.9, 0.82, 0.64, 1},
                                skipVisuals = true,
                                skipParticles = true,
                                textOffset = 48,
                                textScale = 1.1,
                        })
                end,
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
                        local barrierColor = {0.74, 0.88, 1, 1}
                        celebrateUpgrade(getUpgradeString("diffraction_barrier", "name"), nil, {
                                color = barrierColor,
                                skipVisuals = true,
                                skipParticles = true,
                                textOffset = 48,
                                textScale = 1.08,
                        })

                        local laserCenters = getLaserCenters(2)
                        local baseVisual = {
                                variant = "prism_refraction",
                                life = 0.74,
                                innerRadius = 16,
                                outerRadius = 64,
                                addBlend = true,
                                color = {0.74, 0.88, 1, 1},
                                variantSecondaryColor = {0.46, 0.78, 1.0, 0.95},
                                variantTertiaryColor = {1.0, 0.96, 0.72, 0.82},
                        }
                        local baseOptions = {
                                color = barrierColor,
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
                id = "wardens_chorus",
                nameKey = "upgrades.wardens_chorus.name",
		descKey = "upgrades.wardens_chorus.description",
		rarity = "rare",
		requiresTags = {"defense"},
		tags = {"defense"},
		unlockTag = "specialist",
		onAcquire = function(state)
			state.counters.bulwarkChorusPerDefense = 0.33
			state.counters.bulwarkChorusProgress = state.counters.bulwarkChorusProgress or 0

			if not state.counters.bulwarkChorusHandlerRegistered then
				state.counters.bulwarkChorusHandlerRegistered = true
				Upgrades:addEventHandler("floorStart", handleBulwarkChorusFloorStart)
			end

			celebrateUpgrade(getUpgradeString("wardens_chorus", "name"), nil, {
				color = {0.66, 0.88, 1, 1},
				particleCount = 18,
				particleSpeed = 120,
				particleLife = 0.46,
				textOffset = 46,
				textScale = 1.1,
			})
		end,
	}),
        register({
                id = "caravan_contract",
                nameKey = "upgrades.caravan_contract.name",
                descKey = "upgrades.caravan_contract.description",
		rarity = "uncommon",
		tags = {"economy", "risk"},
		onAcquire = function(state)
			state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
			state.effects.rockSpawnBonus = (state.effects.rockSpawnBonus or 0) + 1
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
                                        local threshold = 3
                                        local shields = math.floor(progress / threshold)
                                        counters.verdantBondsProgress = progress - shields * threshold

                                        if shields <= 0 then return end

                                        if Snake and Snake.addShields then
                                                Snake:addShields(shields)
                                        end

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
		rarity = "rare",
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
                id = "predators_reflex",
                nameKey = "upgrades.predators_reflex.name",
                descKey = "upgrades.predators_reflex.description",
                rarity = "rare",
		requiresTags = {"adrenaline"},
		onAcquire = function(state)
			state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
			state.effects.adrenalineBoostBonus = (state.effects.adrenalineBoostBonus or 0) + 0.25
		end,
		handlers = {
			floorStart = function()
				if Snake.adrenaline then
					Snake.adrenaline.active = true
					Snake.adrenaline.timer = (Snake.adrenaline.duration or 0) * 0.5
					Snake.adrenaline.suppressVisuals = true
                                end
                        end,
                },
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
                        if Snake and Snake.setSpectralHarvestReady then
                                Snake:setSpectralHarvestReady(true, { pulse = 0.8, instantIntensity = 0.45 })
                        end
                end,
                handlers = {
                        floorStart = function(_, state)
                                state.counters.spectralHarvestReady = true
                                if Snake and Snake.setSpectralHarvestReady then
                                        Snake:setSpectralHarvestReady(true, { pulse = 0.6 })
                                end
                        end,
                        fruitCollected = function(_, state)
                                if not state.counters.spectralHarvestReady then return end
                                state.counters.spectralHarvestReady = false

                                if Snake then
                                        if Snake.triggerSpectralHarvest then
                                                Snake:triggerSpectralHarvest({ flash = 1, echo = 1, instantIntensity = 0.55 })
                                        elseif Snake.setSpectralHarvestReady then
                                                Snake:setSpectralHarvestReady(false, { pulse = 0.8 })
                                        end
                                end

                                local Fruit = require("fruit")
                                local FruitEvents = require("fruitevents")
                                if not (Fruit and FruitEvents and FruitEvents.handleConsumption) then return end

                                local fx, fy = Fruit:getPosition()
                                if not (fx and fy) then return end

                                FruitEvents.handleConsumption(fx, fy)
                                if Snake and Snake.setSpectralHarvestReady and not Snake.triggerSpectralHarvest then
                                        Snake:setSpectralHarvestReady(false)
                                end
                        end,
                },
        }),
	register({
		id = "solar_reservoir",
		nameKey = "upgrades.solar_reservoir.name",
		descKey = "upgrades.solar_reservoir.description",
		rarity = "epic",
		tags = {"economy", "defense"},
		onAcquire = function(state)
			state.counters.solarReservoirReady = false
		end,
		handlers = {
			floorStart = function(_, state)
				state.counters.solarReservoirReady = true
			end,
			fruitCollected = function(data, state)
				if not state.counters.solarReservoirReady then return end
				state.counters.solarReservoirReady = false
				if Saws and Saws.stall then
					Saws:stall(2)
				end
				if Score.addBonus then
					Score:addBonus(4)
				end
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
			state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
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
                        Snake:addShields(3)
                        state.effects.sawStall = (state.effects.sawStall or 0) + 2
                        for _ = 1, 5 do
                                Snake:grow()
                        end
                        Snake.extraGrowth = (Snake.extraGrowth or 0) + 2
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
		rarity = "epic",
		tags = {"combo", "defense", "risk"},
		weight = 1,
                unlockTag = "combo_mastery",
                onAcquire = function(state)
                        state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 0.75
                        state.effects.sawSpinMult = (state.effects.sawSpinMult or 1) * 0.6
                        state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.6
                        state.effects.chronospiralCore = true
                        for _ = 1, 4 do
                                Snake:grow()
                        end
                        Snake.extraGrowth = (Snake.extraGrowth or 0) + 1

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
						particleSpread = math.pi * 2,
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
                rarity = "rare",
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
						particleSpread = math.pi * 2,
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
                        Snake:addSpeedMultiplier(1.2)
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
                                particleSpread = math.pi * 2,
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

	table.insert(handlers, handler)
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

	local stoneStacks = state.counters and state.counters.stonebreakerStacks or 0
	if stoneStacks > 0 then
		local label = Localization:get("upgrades.stonebreaker_hymn.name")
		local current = 0
		if Rocks.getShatterProgress then
			current = Rocks:getShatterProgress() or 0
		end

		local rate = 0
		if Rocks.getShatterRate then
			rate = Rocks:getShatterRate() or 0
		else
			rate = Rocks.shatterOnFruit or 0
		end

		local progress = 0
		local isReady = false
		if rate and rate > 0 then
			if rate >= 1 then
				progress = 1
				isReady = true
			else
				progress = clamp(current, 0, 1)
				if progress >= 0.999 then
					isReady = true
				end
			end
		end

		local statusKey
		if not rate or rate <= 0 then
			statusKey = "depleted"
		elseif isReady then
			statusKey = "ready"
		else
			statusKey = "charging"
		end

		local status = hudStatus(statusKey)
		local chargeLabel
		if rate and rate > 0 then
			chargeLabel = hudText("percent", { percent = math.floor(progress * 100 + 0.5) })
		end

		table.insert(indicators, {
			id = "stonebreaker_hymn",
			label = label,
			accentColor = {1.0, 0.78, 0.36, 1},
			stackCount = stoneStacks,
			charge = progress,
			chargeLabel = chargeLabel,
			status = status,
			icon = "pickaxe",
			showBar = true,
		})
	end

	if hasUpgrade("pocket_springs") then
		local counters = state.counters or {}
		local complete = counters.pocketSpringsComplete
		if not complete then
			local collected = math.min(counters.pocketSpringsFruit or 0, POCKET_SPRINGS_FRUIT_TARGET)
			local progress = 0
			if POCKET_SPRINGS_FRUIT_TARGET > 0 then
				progress = clamp(collected / POCKET_SPRINGS_FRUIT_TARGET, 0, 1)
			end

			table.insert(indicators, {
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
		local timer = (adrenaline and math.max(adrenaline.timer or 0, 0)) or 0
		local charge
		local chargeLabel

		if active and duration > 0 then
			charge = clamp(timer / duration, 0, 1)
			chargeLabel = hudText("seconds", { seconds = string.format("%.1f", timer) })
		end

		local status = active and hudStatus("active") or hudStatus("ready")

		table.insert(indicators, {
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
			local remaining = math.max(dashState.timer or 0, 0)
			charge = clamp(remaining / dashState.duration, 0, 1)
			chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remaining) })
			status = hudStatus("active")
			showBar = true
		else
			local cooldown = dashState.cooldown or 0
			local remainingCooldown = math.max(dashState.cooldownTimer or 0, 0)
			if cooldown > 0 and remainingCooldown > 0 then
				local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
				charge = progress
				chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remainingCooldown) })
				status = hudStatus("charging")
				showBar = true
			else
				charge = 1
				status = hudStatus("ready")
			end
		end

		table.insert(indicators, {
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
			local remaining = math.max(timeState.timer or 0, 0)
			charge = clamp(remaining / timeState.duration, 0, 1)
			chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remaining) })
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
				local remainingCooldown = math.max(timeState.cooldownTimer or 0, 0)
				if cooldown > 0 and remainingCooldown > 0 then
					local progress = 1 - clamp(remainingCooldown / cooldown, 0, 1)
					charge = progress
					chargeLabel = hudText("seconds", { seconds = string.format("%.1f", remainingCooldown) })
					status = hudStatus("charging")
					showBar = true
				else
					charge = 1
					status = hudStatus("ready")
				end
			end
		end

		table.insert(indicators, {
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
		table.insert(indicators, {
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
		goal = math.floor(goal + 0.5)
		context.fruitGoal = clamp(goal, 1)
	end
	if effects.rockSpawnBonus and context.rocks then
		local rocks = context.rocks + effects.rockSpawnBonus
		rocks = math.floor(rocks + 0.5)
		context.rocks = clamp(rocks, 0)
	end
	if effects.sawSpawnBonus and context.saws then
		local saws = context.saws + effects.sawSpawnBonus
		saws = math.floor(saws + 0.5)
		context.saws = clamp(saws, 0)
	end
	if effects.laserSpawnBonus and context.laserCount then
		local lasers = context.laserCount + effects.laserSpawnBonus
		lasers = math.floor(lasers + 0.5)
		context.laserCount = clamp(lasers, 0)
	end

	return context
end

local function round(value)
	if value >= 0 then
		return math.floor(value + 0.5)
	else
		return -math.floor(math.abs(value) + 0.5)
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
			table.insert(breakdown, { label = Localization:get("upgrades.momentum_label"), amount = amount })
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
                Snake:setPhoenixEchoCharges(state.counters.phoenixEchoCharges or 0, { triggered = 1.4, flareDuration = 1.4 })
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
	local rockChance = math.max(0.02, rockBase * (effects.rockSpawnMult or 1) + (effects.rockSpawnFlat or 0))
	Rocks.spawnChance = rockChance
	Rocks.shatterOnFruit = (base.rockShatter or 0) + (effects.rockShatter or 0)
	if Snake.setStonebreakerStacks then
		local stacks = 0
		if state and state.counters then
			stacks = state.counters.stonebreakerStacks or 0
		end
		if stacks <= 0 and effects.rockShatter then
			local perStack = 0.25
			stacks = math.floor(((effects.rockShatter or 0) / perStack) + 0.5)
		end
		Snake:setStonebreakerStacks(stacks)
	end

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
				dash.cooldownTimer = math.min(dash.cooldownTimer or 0, dash.cooldown)
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
				ability.cooldownTimer = math.min(ability.cooldownTimer or 0, ability.cooldown)
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
			ability.floorCharges = math.max(0, math.min(ability.floorCharges, maxUses))
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
		weight = weight * (1 + math.min(pityLevel, SHOP_PITY_MAX) * bonus)
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
		pityLevel = math.min(state.counters.shopBadLuck or 0, SHOP_PITY_MAX)
	end

	local available = {}
	for _, upgrade in ipairs(pool) do
		if self:canOffer(upgrade, context, false) then
			table.insert(available, upgrade)
		end
	end

	if #available == 0 then
		for _, upgrade in ipairs(pool) do
			if self:canOffer(upgrade, context, true) then
				table.insert(available, upgrade)
			end
		end
	end

	local cards = {}
	n = math.min(n or 3, #available)
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
		table.insert(cards, decorateCard(choice))
		table.remove(available, chosenIndex)
		if #available == 0 then break end
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
			state.counters.shopBadLuck = math.min(counter, SHOP_PITY_MAX)
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
							table.insert(legendaryChoices, decorateCard(upgrade))
						end
					end
					if #legendaryChoices == 0 then
						for _, upgrade in ipairs(pool) do
							if upgrade.rarity == "legendary" and self:canOffer(upgrade, context, true) then
								table.insert(legendaryChoices, decorateCard(upgrade))
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
							table.insert(cards, legendaryChoices[love.math.random(1, #legendaryChoices)])
						end

						legendaryCounter = 0
					end
				end

				state.counters.legendaryBadLuck = math.min(legendaryCounter, LEGENDARY_PITY_THRESHOLD)
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
	table.insert(state.takenOrder, upgrade.id)

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

	self:notify("upgradeAcquired", { id = upgrade.id, upgrade = upgrade, context = context })
	self:applyPersistentEffects(false)
end

return Upgrades
