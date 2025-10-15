local Snake = require("snake")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local GameState = require("gamestate")
local Score = require("score")
local UI = require("ui")
local Localization = require("localization")
local MetaProgression = require("metaprogression")
local PlayerStats = require("playerstats")
local UpgradeHelpers = require("upgradehelpers")
local DataSchemas = require("dataschemas")

local Upgrades = {}
local PoolById = {}
local UpgradeSchema = DataSchemas.UpgradeDefinition
local GetUpgradeString = UpgradeHelpers.GetUpgradeString
local rarities = UpgradeHelpers.rarities
local deepcopy = UpgradeHelpers.deepcopy
local DefaultEffects = UpgradeHelpers.DefaultEffects
local CelebrateUpgrade = UpgradeHelpers.CelebrateUpgrade
local GetEventPosition = UpgradeHelpers.GetEventPosition

local RunState = {}
RunState.__index = RunState

function RunState.new(defaults)
	local state = {
		TakenOrder = {},
		TakenSet = {},
		tags = {},
		counters = {},
		handlers = {},
		effects = deepcopy(defaults or DefaultEffects),
		baseline = {},
	}

	return setmetatable(state, RunState)
end

function RunState:GetStacks(id)
	if not id then
		return 0
	end

	return self.TakenSet[id] or 0
end

function RunState:AddStacks(id, amount)
	if not id then
		return
	end

	amount = amount or 1
	self.TakenSet[id] = (self.TakenSet[id] or 0) + amount
end

function RunState:HasUpgrade(id)
	return self:GetStacks(id) > 0
end

function RunState:AddHandler(event, handler)
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

function RunState:ResetEffects(defaults)
	self.effects = deepcopy(defaults or DefaultEffects)
end

local POCKET_SPRINGS_FRUIT_TARGET = 20

local function GetStacks(state, id)
	if not state or not id then
		return 0
	end

	local method = state.getStacks
	if type(method) == "function" then
		return method(state, id)
	end

	local TakenSet = state.takenSet
	if not TakenSet then
		return 0
	end

	return TakenSet[id] or 0
end

local function GetGameInstance()
	if GameState and GameState.states then
		return GameState.states.game
	end
end

local function GrantCrashShields(amount)
        amount = math.max(0, math.floor((amount or 0) + 0.0001))
        if amount <= 0 then
                return 0
        end

        if Snake and Snake.AddCrashShields then
                Snake:AddCrashShields(amount)
                return amount
        end

        return 0
end

local function GetSegmentPosition(fraction)
        if not Snake or not Snake.GetSegments then
                if Snake and Snake.GetHead then
                        return Snake:GetHead()
                end
                return nil, nil
        end

        local segments = Snake:GetSegments()
        local count = segments and #segments or 0
        if count <= 0 then
                if Snake and Snake.GetHead then
                        return Snake:GetHead()
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

        if Snake and Snake.GetHead then
                return Snake:GetHead()
        end

        return nil, nil
end

local function ApplySegmentPosition(options, fraction)
        if not options then
                options = {}
        end

        local x, y = GetSegmentPosition(fraction)
        if x and y then
                options.x = options.x or x
                options.y = options.y or y
        end

        return options
end

local function CollectPositions(source, limit, extractor)
        if not source then
                return nil
        end

        local count = #source
        if not count or count <= 0 then
                return {}
        end

        local result = {}
        local MaxCount = math.min(limit or count, count)
        for index = 1, MaxCount do
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

local function GetSawCenters(limit)
        if not Saws or not Saws.GetAll then
                return nil
        end

        return CollectPositions(Saws:GetAll(), limit, function(saw)
                local sx, sy
                if Saws.GetCollisionCenter then
                        sx, sy = Saws:GetCollisionCenter(saw)
                end
                return sx or saw.x, sy or saw.y
        end)
end

local function GetRockCenters(limit)
        if not Rocks or not Rocks.GetAll then
                return nil
        end

        return CollectPositions(Rocks:GetAll(), limit, function(rock)
                return rock.x, rock.y
        end)
end

local function GetLaserCenters(limit)
        if not Lasers or not Lasers.GetEmitters then
                return nil
        end

        return CollectPositions(Lasers:GetEmitters(), limit, function(beam)
                return beam.x, beam.y
        end)
end

local function StoneSkinShieldHandler(data, state)
        if not state then return end
        if GetStacks(state, "stone_skin") <= 0 then return end
        if not data or data.cause ~= "rock" then return end
        if not Rocks or not Rocks.ShatterNearest then return end

	local fx, fy = GetEventPosition(data)
	CelebrateUpgrade(nil, nil, {
		x = fx,
		y = fy,
		SkipText = true,
		color = {0.75, 0.82, 0.88, 1},
		ParticleCount = 16,
		ParticleSpeed = 100,
		ParticleLife = 0.42,
		visual = {
			badge = "shield",
			OuterRadius = 56,
			InnerRadius = 16,
			RingCount = 3,
			RingSpacing = 10,
			life = 0.82,
			GlowAlpha = 0.28,
			HaloAlpha = 0.18,
		},
	})
	Rocks:ShatterNearest(fx or 0, fy or 0, 1)
end

local function NewRunState()
        return RunState.new(DefaultEffects)
end

Upgrades.RunState = NewRunState()

local function NormalizeUpgradeDefinition(upgrade)
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

	DataSchemas.ApplyDefaults(UpgradeSchema, upgrade)
	local context = string.format("upgrade '%s'", tostring(upgrade.id or "?"))
	DataSchemas.validate(UpgradeSchema, upgrade, context)

	return upgrade
end

local function register(upgrade)
	NormalizeUpgradeDefinition(upgrade)
	PoolById[upgrade.id] = upgrade
	return upgrade
end

local function CountUpgradesWithTag(state, tag)
	if not state or not tag then return 0 end

	local total = 0
	if not state.takenSet then return total end

	for id, count in pairs(state.takenSet) do
		local upgrade = PoolById[id]
		if upgrade and upgrade.tags then
			for _, UpgradeTag in ipairs(upgrade.tags) do
				if UpgradeTag == tag then
					total = total + (count or 0)
					break
				end
			end
		end
	end

	return total
end

local function UpdateResonantShellBonus(state)
	if not state then return end

	local PerBonus = state.counters and state.counters.resonantShellPerBonus or 0
	local PerCharge = state.counters and state.counters.resonantShellPerCharge or 0
	if PerBonus <= 0 and PerCharge <= 0 then return end

	local DefenseCount = CountUpgradesWithTag(state, "defense")

	if PerBonus > 0 then
		local previous = state.counters.resonantShellBonus or 0
		local NewBonus = PerBonus * DefenseCount
		state.counters.resonantShellBonus = NewBonus
		state.effects.sawStall = (state.effects.sawStall or 0) - previous + NewBonus
	end

	if PerCharge > 0 then
		local PreviousCharge = state.counters.resonantShellChargeBonus or 0
		local NewCharge = PerCharge * DefenseCount
		state.counters.resonantShellChargeBonus = NewCharge
		state.effects.laserChargeFlat = (state.effects.laserChargeFlat or 0) - PreviousCharge + NewCharge
	end
end

local function UpdateGuildLedger(state)
	if not state then return end

	local PerSlot = state.counters and state.counters.guildLedgerFlatPerSlot or 0
	if PerSlot == 0 then return end

	local slots = 0
	if state.effects then
		slots = state.effects.shopSlots or 0
	end

	local previous = state.counters.guildLedgerBonus or 0
	local NewBonus = -(PerSlot * slots)
	state.counters.guildLedgerBonus = NewBonus
	state.effects.rockSpawnFlat = (state.effects.rockSpawnFlat or 0) - previous + NewBonus
end

local function UpdateStoneCensus(state)
	if not state then return end

	local PerEconomy = state.counters and state.counters.stoneCensusReduction or 0
	if PerEconomy == 0 then return end

	local previous = state.counters.stoneCensusMult or 1
	if previous <= 0 then previous = 1 end

	local effects = state.effects or {}
	effects.rockSpawnMult = effects.rockSpawnMult or 1
	effects.rockSpawnMult = effects.rockSpawnMult / previous

	local EconomyCount = CountUpgradesWithTag(state, "economy")
	local NewMult = math.max(0.2, 1 - PerEconomy * EconomyCount)

	state.counters.stoneCensusMult = NewMult
	effects.rockSpawnMult = effects.rockSpawnMult * NewMult
	state.effects = effects
end

local function HandleBulwarkChorusFloorStart(_, state)
	if not state or not state.counters then return end
	if GetStacks(state, "wardens_chorus") <= 0 then return end

	local PerDefense = state.counters.bulwarkChorusPerDefense or 0
	if PerDefense <= 0 then return end

	local DefenseCount = CountUpgradesWithTag(state, "defense")
	if DefenseCount <= 0 then return end

	local progress = (state.counters.bulwarkChorusProgress or 0) + PerDefense * DefenseCount
	local shields = math.floor(progress)
	state.counters.bulwarkChorusProgress = progress - shields

	if shields > 0 and Snake.AddCrashShields then
		Snake:AddCrashShields(shields)
		CelebrateUpgrade(nil, nil, {
			SkipText = true,
			color = {0.7, 0.9, 1.0, 1},
			SkipParticles = true,
			visual = {
				badge = "shield",
				OuterRadius = 54,
				InnerRadius = 14,
				RingCount = 3,
				life = 0.85,
				GlowAlpha = 0.24,
				HaloAlpha = 0.15,
			},
		})
	end
end

local MapmakersCompassHazards = {
	{
		key = "LaserCount",
		EffectKey = "LaserSpawnBonus",
		LabelKey = "lasers_text",
		color = {0.72, 0.9, 1.0, 1},
		priority = 3,
	},
	{
		key = "saws",
		EffectKey = "SawSpawnBonus",
		LabelKey = "saws_text",
		color = {1.0, 0.78, 0.42, 1},
		priority = 2,
	},
	{
		key = "rocks",
		EffectKey = "RockSpawnBonus",
		LabelKey = "rocks_text",
		color = {0.72, 0.86, 1.0, 1},
		priority = 1,
	},
}

local function ClearMapmakersCompass(state)
	if not state then return end
	local counters = state.counters
	if not counters then return end

	local applied = counters.mapmakersCompassApplied
	if not applied then return end

	state.effects = state.effects or {}

	for EffectKey, delta in pairs(applied) do
		if delta ~= 0 then
			state.effects[EffectKey] = (state.effects[EffectKey] or 0) - delta
		end
	end

	counters.mapmakersCompassApplied = {}
end

local function ApplyMapmakersCompass(state, context, options)
	if not state then return end
	state.effects = state.effects or {}
	state.counters = state.counters or {}

	ClearMapmakersCompass(state)

	local stacks = GetStacks(state, "mapmakers_compass")
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
	for _, entry in ipairs(MapmakersCompassHazards) do
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
	local EventData = options and options.eventData

	if not chosen then
		if Score and Score.AddBonus then
			Score:AddBonus(2 + stacks)
		end

		if Saws and Saws.stall then
			Saws:stall(0.6 + 0.1 * stacks)
		end

                if celebrate then
                        local label = GetUpgradeString("mapmakers_compass", "activation_text") or GetUpgradeString("mapmakers_compass", "name")
                        CelebrateUpgrade(label, EventData, {
                                color = {0.92, 0.82, 0.6, 1},
                                TextOffset = 46,
                                TextScale = 1.08,
                                visual = {
                                        variant = "guiding_compass",
                                        ShowBase = false,
                                        life = 0.78,
                                        InnerRadius = 12,
                                        OuterRadius = 58,
                                        AddBlend = true,
                                        color = {0.92, 0.82, 0.6, 1},
                                        VariantSecondaryColor = {1.0, 0.68, 0.32, 0.95},
                                        VariantTertiaryColor = {0.72, 0.86, 1.0, 0.7},
                                },
                        })
                end

		return
	end

	local reduction = 1 + math.floor((stacks - 1) * 0.5)
	local delta = -reduction
	local EffectKey = chosen.effectKey
	state.effects[EffectKey] = (state.effects[EffectKey] or 0) + delta
	applied[EffectKey] = delta
	state.counters.mapmakersCompassTarget = chosen.key
	state.counters.mapmakersCompassReduction = reduction

        if celebrate then
                local label = GetUpgradeString("mapmakers_compass", chosen.labelKey or "activation_text") or GetUpgradeString("mapmakers_compass", "name")
                CelebrateUpgrade(label, EventData, {
                        color = chosen.color or {0.72, 0.86, 1.0, 1},
                        TextOffset = 46,
                        TextScale = 1.08,
                        visual = {
                                variant = "guiding_compass",
                                ShowBase = false,
                                life = 0.82,
                                InnerRadius = 12,
                                OuterRadius = 62,
                                AddBlend = true,
                                color = chosen.color or {0.72, 0.86, 1.0, 1},
                                VariantSecondaryColor = {1.0, 0.82, 0.42, 1},
                                VariantTertiaryColor = {0.48, 0.72, 1.0, 0.85},
                        },
                })
        end
end

local function MapmakersCompassFloorStart(data, state)
	if not (data and state) then return end
	if GetStacks(state, "mapmakers_compass") <= 0 then return end

	local context = data.context
	ApplyMapmakersCompass(state, context, { celebrate = true, EventData = data })
end

local pool = {
	register({
		id = "quick_fangs",
		NameKey = "upgrades.quick_fangs.name",
		DescKey = "upgrades.quick_fangs.description",
		rarity = "uncommon",
		AllowDuplicates = true,
		MaxStacks = 4,
                OnAcquire = function(state)
                        Snake:AddSpeedMultiplier(1.10)

                        if state then
                                state.counters = state.counters or {}
                                local stacks = (state.counters.quickFangsStacks or 0) + 1
                                state.counters.quickFangsStacks = stacks
                                if Snake.SetQuickFangsStacks then
                                        Snake:SetQuickFangsStacks(stacks)
                                end
                        elseif Snake.SetQuickFangsStacks then
                                Snake:SetQuickFangsStacks((Snake.QuickFangs and Snake.QuickFangs.stacks or 0) + 1)
                        end

                        local CelebrationOptions = {
                                color = {1, 0.63, 0.42, 1},
                                ParticleCount = 18,
                                ParticleSpeed = 150,
                                ParticleLife = 0.38,
                                TextOffset = 46,
                                TextScale = 1.18,
                        }
                        ApplySegmentPosition(CelebrationOptions, 0.28)
                        CelebrateUpgrade(GetUpgradeString("quick_fangs", "name"), nil, CelebrationOptions)
                end,
        }),
        register({
                id = "stone_skin",
		NameKey = "upgrades.stone_skin.name",
		DescKey = "upgrades.stone_skin.description",
		rarity = "uncommon",
		AllowDuplicates = true,
		MaxStacks = 4,
		OnAcquire = function(state)
			Snake:AddCrashShields(1)
			if Snake.AddStoneSkinSawGrace then
				Snake:AddStoneSkinSawGrace(1)
			end
			if not state.counters.stoneSkinHandlerRegistered then
				state.counters.stoneSkinHandlerRegistered = true
				Upgrades:AddEventHandler("ShieldConsumed", StoneSkinShieldHandler)
			end
                        local CelebrationOptions = {
                                color = {0.75, 0.82, 0.88, 1},
                                ParticleCount = 14,
                                ParticleSpeed = 90,
                                ParticleLife = 0.45,
                                TextOffset = 50,
                                TextScale = 1.12,
                                visual = {
                                        variant = "stoneguard_bastion",
                                        life = 0.8,
                                        InnerRadius = 14,
                                        OuterRadius = 60,
                                        color = {0.74, 0.8, 0.88, 1},
                                        VariantSecondaryColor = {0.46, 0.5, 0.56, 1},
                                        VariantTertiaryColor = {0.94, 0.96, 0.98, 0.72},
                                },
                        }
                        ApplySegmentPosition(CelebrationOptions, 0.46)
                        CelebrateUpgrade(GetUpgradeString("stone_skin", "name"), nil, CelebrationOptions)
                end,
        }),
	register({
		id = "aegis_recycler",
		NameKey = "upgrades.aegis_recycler.name",
		DescKey = "upgrades.aegis_recycler.description",
		rarity = "uncommon",
		tags = {"defense"},
		OnAcquire = function(state)
			state.counters.aegisRecycler = state.counters.aegisRecycler or 0
		end,
		handlers = {
			ShieldConsumed = function(data, state)
				state.counters.aegisRecycler = (state.counters.aegisRecycler or 0) + 1
				if state.counters.aegisRecycler >= 2 then
					state.counters.aegisRecycler = state.counters.aegisRecycler - 2
					Snake:AddCrashShields(1)
					local fx, fy = GetEventPosition(data)
					if fx and fy then
						CelebrateUpgrade(nil, data, {
							x = fx,
							y = fy,
							SkipText = true,
							color = {0.6, 0.85, 1, 1},
							ParticleCount = 10,
							ParticleSpeed = 90,
							ParticleLife = 0.45,
							visual = {
								badge = "shield",
								OuterRadius = 50,
								InnerRadius = 14,
								RingCount = 3,
								life = 0.75,
								GlowAlpha = 0.26,
								HaloAlpha = 0.16,
							},
						})
					end
				end
			end,
		},
	}),
	register({
		id = "extra_bite",
		NameKey = "upgrades.extra_bite.name",
		DescKey = "upgrades.extra_bite.description",
		rarity = "common",
		OnAcquire = function(state)
			state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) - 1
			state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 1.15
			if UI.AdjustFruitGoal then
				UI:AdjustFruitGoal(-1)
			end
                        local CelebrationOptions = {
                                color = {1, 0.86, 0.36, 1},
                                ParticleCount = 10,
                                ParticleSpeed = 70,
                                ParticleLife = 0.38,
                                TextOffset = 38,
                                TextScale = 1.04,
                        }
                        ApplySegmentPosition(CelebrationOptions, 0.92)
                        CelebrateUpgrade(GetUpgradeString("extra_bite", "celebration"), nil, CelebrationOptions)
		end,
	}),
	register({
		id = "adrenaline_surge",
		NameKey = "upgrades.adrenaline_surge.name",
		DescKey = "upgrades.adrenaline_surge.description",
		rarity = "uncommon",
		tags = {"adrenaline"},
                OnAcquire = function(state)
                        state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
                        CelebrateUpgrade(GetUpgradeString("adrenaline_surge", "name"), nil, {
                                color = {1, 0.42, 0.42, 1},
                                ParticleCount = 20,
                                ParticleSpeed = 160,
                                ParticleLife = 0.36,
                                TextOffset = 42,
                                TextScale = 1.16,
                                visual = {
                                        variant = "adrenaline_rush",
                                        ShowBase = false,
                                        life = 0.72,
                                        InnerRadius = 12,
                                        OuterRadius = 56,
                                        AddBlend = true,
                                        color = {1, 0.46, 0.42, 1},
                                        VariantSecondaryColor = {1, 0.72, 0.44, 0.95},
                                        VariantTertiaryColor = {1, 0.94, 0.92, 0.85},
                                },
                        })
                end,
        }),
	register({
		id = "stone_whisperer",
		NameKey = "upgrades.stone_whisperer.name",
		DescKey = "upgrades.stone_whisperer.description",
		rarity = "common",
		OnAcquire = function(state)
			state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.6
		end,
	}),
        register({
                id = "deliberate_coil",
                NameKey = "upgrades.deliberate_coil.name",
                DescKey = "upgrades.deliberate_coil.description",
                rarity = "epic",
		tags = {"speed", "risk"},
		UnlockTag = "speedcraft",
		OnAcquire = function(state)
			Snake:AddSpeedMultiplier(0.85)
			state.effects.fruitGoalDelta = (state.effects.fruitGoalDelta or 0) + 1
			if UI.AdjustFruitGoal then
				UI:AdjustFruitGoal(1)
			end
                        CelebrateUpgrade(GetUpgradeString("deliberate_coil", "name"), nil, {
                                color = {0.76, 0.56, 0.88, 1},
                                ParticleCount = 16,
                                ParticleSpeed = 90,
                                ParticleLife = 0.5,
                                TextOffset = 40,
                                TextScale = 1.08,
                                visual = {
                                        variant = "coiled_focus",
                                        ShowBase = false,
                                        life = 0.86,
                                        InnerRadius = 14,
                                        OuterRadius = 60,
                                        AddBlend = true,
                                        color = {0.76, 0.56, 0.88, 1},
                                        VariantSecondaryColor = {0.58, 0.44, 0.92, 0.9},
                                        VariantTertiaryColor = {0.98, 0.9, 1.0, 0.75},
                                },
                        })
                end,
        }),
	register({
		id = "pocket_springs",
		NameKey = "upgrades.pocket_springs.name",
		DescKey = "upgrades.pocket_springs.description",
		rarity = "uncommon",
		tags = {"defense"},
		OnAcquire = function(state)
			state.counters.pocketSpringsFruit = state.counters.pocketSpringsFruit or 0
			if state.counters.pocketSpringsComplete == nil then
				state.counters.pocketSpringsComplete = false
			end
		end,
		handlers = {
			FruitCollected = function(data, state)
				if GetStacks(state, "pocket_springs") <= 0 then
					return
				end

				if state.counters.pocketSpringsComplete then
					return
				end

				state.counters.pocketSpringsFruit = (state.counters.pocketSpringsFruit or 0) + 1
				if state.counters.pocketSpringsFruit >= POCKET_SPRINGS_FRUIT_TARGET then
					state.counters.pocketSpringsFruit = POCKET_SPRINGS_FRUIT_TARGET
					state.counters.pocketSpringsComplete = true
					Snake:AddCrashShields(1)
				end
			end,
		},
	}),
	register({
		id = "mapmakers_compass",
		NameKey = "upgrades.mapmakers_compass.name",
		DescKey = "upgrades.mapmakers_compass.description",
		rarity = "uncommon",
		tags = {"defense", "utility"},
		OnAcquire = function(state)
			state.effects = state.effects or {}
			state.counters = state.counters or {}
			state.counters.mapmakersCompassApplied = state.counters.mapmakersCompassApplied or {}

			if not state.counters.mapmakersCompassHandlerRegistered then
				state.counters.mapmakersCompassHandlerRegistered = true
				Upgrades:AddEventHandler("FloorStart", MapmakersCompassFloorStart)
			end

			if state.counters.mapmakersCompassLastContext then
				ApplyMapmakersCompass(state, state.counters.mapmakersCompassLastContext, { celebrate = false })
			end
		end,
	}),
        register({
                id = "momentum_memory",
                NameKey = "upgrades.momentum_memory.name",
                DescKey = "upgrades.momentum_memory.description",
                rarity = "uncommon",
		RequiresTags = {"adrenaline"},
		OnAcquire = function(state)
			state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
			state.effects.adrenalineDurationBonus = (state.effects.adrenalineDurationBonus or 0) + 2
		end,
	}),
	register({
		id = "molting_reflex",
		NameKey = "upgrades.molting_reflex.name",
		DescKey = "upgrades.molting_reflex.description",
		rarity = "uncommon",
		RequiresTags = {"adrenaline"},
		tags = {"adrenaline", "defense"},
		handlers = {
			ShieldConsumed = function(data)
				if not Snake.adrenaline then return end

				Snake.adrenaline.active = true
				local BaseDuration = Snake.adrenaline.duration or 2.5
				local SurgeDuration = BaseDuration * 0.6
				if SurgeDuration <= 0 then SurgeDuration = 1 end
				local CurrentTimer = Snake.adrenaline.timer or 0
				Snake.adrenaline.timer = math.max(CurrentTimer, SurgeDuration)

				local fx, fy = GetEventPosition(data)
				if fx and fy then
					CelebrateUpgrade(nil, data, {
						x = fx,
						y = fy,
						SkipText = true,
						color = {1, 0.72, 0.28, 1},
						ParticleCount = 12,
						ParticleSpeed = 120,
						ParticleLife = 0.5,
						visual = {
							badge = "spark",
							OuterRadius = 50,
							InnerRadius = 14,
							RingCount = 3,
							life = 0.74,
							GlowAlpha = 0.28,
							HaloAlpha = 0.18,
						},
					})
				end
			end,
		},
	}),
local function NormalizeDirection(dx, dy)
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

local function ApplyCircuitBreakerFacing(options, dx, dy)
        if not options then
                return
        end

        local particles = options.particles
        if not particles then
                return
        end

        dx, dy = NormalizeDirection(dx, dy)
        local BaseAngle = atan2(dy, dx)
        local spread = particles.spread or 0
        particles.angleOffset = BaseAngle - spread * 0.5
end

local function GetSawFacingDirection(SawInfo)
        if not SawInfo then
                return 0, -1
        end

        if SawInfo.dir == "vertical" then
                if SawInfo.side == "left" then
                        return 1, 0
                elseif SawInfo.side == "right" then
                        return -1, 0
                end

                return -1, 0
        end

        return 0, -1
end

local function BuildCircuitBreakerTargets(data)
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

        register({
                id = "circuit_breaker",
                NameKey = "upgrades.circuit_breaker.name",
                DescKey = "upgrades.circuit_breaker.description",
                rarity = "uncommon",
                OnAcquire = function(state)
                        state.effects.sawStall = (state.effects.sawStall or 0) + 1
                        local SparkColor = {1, 0.58, 0.32, 1}
                        CelebrateUpgrade(GetUpgradeString("circuit_breaker", "name"), nil, {
                                color = SparkColor,
                                SkipVisuals = true,
                                SkipParticles = true,
                                TextOffset = 44,
                                TextScale = 1.08,
                        })
                end,
                handlers = {
                        SawsStalled = function(data, state)
                                if GetStacks(state, "circuit_breaker") <= 0 then
                                        return
                                end

                                if not data then
                                        return
                                end

                                if data.cause and data.cause ~= "fruit" then
                                        return
                                end

                                local SparkColor = {1, 0.58, 0.32, 1}
                                local BaseOptions = {
                                        color = SparkColor,
                                        SkipText = true,
                                        SkipVisuals = true,
                                        particles = {
                                                count = 14,
                                                speed = 120,
                                                SpeedVariance = 70,
                                                life = 0.28,
                                                size = 2.2,
                                                color = {1, 0.74, 0.38, 1},
                                                spread = math.pi * 0.45,
                                                AngleJitter = math.pi * 0.18,
                                                gravity = 200,
                                                drag = 1.5,
                                                FadeTo = 0,
                                                ScaleMin = 0.32,
                                                ScaleVariance = 0.2,
                                        },
                                }
                                local targets = BuildCircuitBreakerTargets(data)
                                if not targets or #targets == 0 then
                                        targets = {}
                                        local SawCenters = GetSawCenters(2)
                                        if SawCenters and #SawCenters > 0 then
                                                for _, pos in ipairs(SawCenters) do
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
                                                        local SparkOptions = deepcopy(BaseOptions)
                                                        SparkOptions.x = target.x
                                                        SparkOptions.y = target.y
                                                        local DirX, DirY = GetSawFacingDirection(target)
                                                        ApplyCircuitBreakerFacing(SparkOptions, DirX, DirY)
                                                        CelebrateUpgrade(nil, nil, SparkOptions)
                                                end
                                        end
                                else
                                        local FallbackOptions = deepcopy(BaseOptions)
                                        ApplySegmentPosition(FallbackOptions, 0.82)
                                        ApplyCircuitBreakerFacing(FallbackOptions, 0, -1)
                                        CelebrateUpgrade(nil, nil, FallbackOptions)
                                end
                        end,
                },
        }),
        register({
                id = "stonebreaker_hymn",
                NameKey = "upgrades.stonebreaker_hymn.name",
                DescKey = "upgrades.stonebreaker_hymn.description",
                rarity = "rare",
                AllowDuplicates = true,
                MaxStacks = 2,
                OnAcquire = function(state)
                        state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
                        state.counters.stonebreakerStacks = (state.counters.stonebreakerStacks or 0) + 1
                        if Snake.SetStonebreakerStacks then
                                Snake:SetStonebreakerStacks(state.counters.stonebreakerStacks)
                        end
                        local HymnColor = {0.9, 0.82, 0.64, 1}
                        CelebrateUpgrade(GetUpgradeString("stonebreaker_hymn", "name"), nil, {
                                color = HymnColor,
                                SkipVisuals = true,
                                SkipParticles = true,
                                TextOffset = 48,
                                TextScale = 1.1,
                        })

                        local RockCenters = GetRockCenters(2)
                        local BaseVisual = {
                                variant = "stoneguard_bastion",
                                life = 0.78,
                                InnerRadius = 14,
                                OuterRadius = 64,
                                color = {0.82, 0.76, 0.66, 1},
                                VariantSecondaryColor = {0.5, 0.54, 0.58, 1},
                                VariantTertiaryColor = {0.96, 0.98, 1.0, 0.72},
                        }
                        local BaseOptions = {
                                color = HymnColor,
                                SkipText = true,
                                ParticleCount = 14,
                                ParticleSpeed = 100,
                                ParticleLife = 0.48,
                                visual = BaseVisual,
                        }
                        if RockCenters and #RockCenters > 0 then
                                for _, pos in ipairs(RockCenters) do
                                        local celebration = deepcopy(BaseOptions)
                                        celebration.x = pos[1]
                                        celebration.y = pos[2]
                                        CelebrateUpgrade(nil, nil, celebration)
                                end
                        else
                                local fallback = deepcopy(BaseOptions)
                                ApplySegmentPosition(fallback, 0.6)
                                CelebrateUpgrade(nil, nil, fallback)
                        end
                end,
        }),
        register({
                id = "diffraction_barrier",
                NameKey = "upgrades.diffraction_barrier.name",
                DescKey = "upgrades.diffraction_barrier.description",
                rarity = "uncommon",
                tags = {"defense"},
                OnAcquire = function(state)
                        state.effects.laserChargeMult = (state.effects.laserChargeMult or 1) * 1.25
                        state.effects.laserFireMult = (state.effects.laserFireMult or 1) * 0.8
                        state.effects.laserCooldownFlat = (state.effects.laserCooldownFlat or 0) + 0.5
                        local BarrierColor = {0.74, 0.88, 1, 1}
                        CelebrateUpgrade(GetUpgradeString("diffraction_barrier", "name"), nil, {
                                color = BarrierColor,
                                SkipVisuals = true,
                                SkipParticles = true,
                                TextOffset = 48,
                                TextScale = 1.08,
                        })

                        local LaserCenters = GetLaserCenters(2)
                        local BaseVisual = {
                                variant = "prism_refraction",
                                life = 0.74,
                                InnerRadius = 16,
                                OuterRadius = 64,
                                AddBlend = true,
                                color = {0.74, 0.88, 1, 1},
                                VariantSecondaryColor = {0.46, 0.78, 1.0, 0.95},
                                VariantTertiaryColor = {1.0, 0.96, 0.72, 0.82},
                        }
                        local BaseOptions = {
                                color = BarrierColor,
                                SkipText = true,
                                ParticleCount = 14,
                                ParticleSpeed = 120,
                                ParticleLife = 0.46,
                                visual = BaseVisual,
                        }
                        if LaserCenters and #LaserCenters > 0 then
                                for _, pos in ipairs(LaserCenters) do
                                        local celebration = deepcopy(BaseOptions)
                                        celebration.x = pos[1]
                                        celebration.y = pos[2]
                                        CelebrateUpgrade(nil, nil, celebration)
                                end
                        else
                                local fallback = deepcopy(BaseOptions)
                                ApplySegmentPosition(fallback, 0.18)
                                CelebrateUpgrade(nil, nil, fallback)
                        end
                end,
        }),
	register({
		id = "resonant_shell",
		NameKey = "upgrades.resonant_shell.name",
		DescKey = "upgrades.resonant_shell.description",
		rarity = "uncommon",
		RequiresTags = {"defense"},
		tags = {"defense"},
		UnlockTag = "specialist",
		OnAcquire = function(state)
			state.counters.resonantShellPerBonus = 0.35
			state.counters.resonantShellPerCharge = 0.08
			UpdateResonantShellBonus(state)

			if not state.counters.resonantShellHandlerRegistered then
				state.counters.resonantShellHandlerRegistered = true
				Upgrades:AddEventHandler("UpgradeAcquired", function(_, RunState)
					if not RunState then return end
					if GetStacks(RunState, "resonant_shell") <= 0 then return end
					UpdateResonantShellBonus(RunState)
				end)
			end

                        local CelebrationOptions = {
                                color = {0.8, 0.88, 1, 1},
                                ParticleCount = 18,
                                ParticleSpeed = 120,
                                ParticleLife = 0.48,
                                TextOffset = 48,
                                TextScale = 1.12,
                        }
                        ApplySegmentPosition(CelebrationOptions, 0.52)
                        CelebrateUpgrade(GetUpgradeString("resonant_shell", "name"), nil, CelebrationOptions)
                end,
        }),
        register({
                id = "wardens_chorus",
                NameKey = "upgrades.wardens_chorus.name",
		DescKey = "upgrades.wardens_chorus.description",
		rarity = "rare",
		RequiresTags = {"defense"},
		tags = {"defense"},
		UnlockTag = "specialist",
		OnAcquire = function(state)
			state.counters.bulwarkChorusPerDefense = 0.33
			state.counters.bulwarkChorusProgress = state.counters.bulwarkChorusProgress or 0

			if not state.counters.bulwarkChorusHandlerRegistered then
				state.counters.bulwarkChorusHandlerRegistered = true
				Upgrades:AddEventHandler("FloorStart", HandleBulwarkChorusFloorStart)
			end

			CelebrateUpgrade(GetUpgradeString("wardens_chorus", "name"), nil, {
				color = {0.66, 0.88, 1, 1},
				ParticleCount = 18,
				ParticleSpeed = 120,
				ParticleLife = 0.46,
				TextOffset = 46,
				TextScale = 1.1,
			})
		end,
	}),
        register({
                id = "pulse_bloom",
                NameKey = "upgrades.pulse_bloom.name",
                DescKey = "upgrades.pulse_bloom.description",
                rarity = "rare",
		tags = {"defense", "economy"},
		AllowDuplicates = true,
		MaxStacks = 2,
		OnAcquire = function(state)
			state.counters.pulseBloomSeen = {}
			state.counters.pulseBloomUnique = 0
		end,
		handlers = {
			FruitCollected = function(data, state)
				if not (data and state) then return end

				local stacks = GetStacks(state, "pulse_bloom")
				if stacks <= 0 then return end

				local FruitId = data.name or (data.fruitType and data.fruitType.id)
				if not FruitId then return end

				local seen = state.counters.pulseBloomSeen or {}
				if not seen[FruitId] then
					seen[FruitId] = true
					state.counters.pulseBloomUnique = (state.counters.pulseBloomUnique or 0) + 1
					state.counters.pulseBloomSeen = seen
				end

				local threshold = math.max(1, 3 - math.max(0, stacks - 1))
				if (state.counters.pulseBloomUnique or 0) < threshold then
					return
				end

				state.counters.pulseBloomUnique = 0
				state.counters.pulseBloomSeen = {}

				GrantCrashShields(1)

				CelebrateUpgrade(GetUpgradeString("pulse_bloom", "shield_text"), data, {
					color = {0.76, 0.94, 0.82, 1},
					TextOffset = 50,
					TextScale = 1.12,
					ParticleCount = 20 + stacks * 2,
					ParticleSpeed = 120,
					ParticleLife = 0.44,
				})
			end,
		},
        }),
        register({
                id = "caravan_contract",
                NameKey = "upgrades.caravan_contract.name",
                DescKey = "upgrades.caravan_contract.description",
		rarity = "uncommon",
		tags = {"economy", "risk"},
		OnAcquire = function(state)
			state.effects.shopSlots = (state.effects.shopSlots or 0) + 1
			state.effects.rockSpawnBonus = (state.effects.rockSpawnBonus or 0) + 1
		end,
        }),

        register({
                id = "verdant_bonds",
                NameKey = "upgrades.verdant_bonds.name",
                DescKey = "upgrades.verdant_bonds.description",
		rarity = "uncommon",
		tags = {"economy", "defense"},
		AllowDuplicates = true,
		MaxStacks = 3,
                OnAcquire = function(state)
                        state.counters = state.counters or {}
                        state.counters.verdantBondsProgress = state.counters.verdantBondsProgress or 0
                        if not state.counters.verdantBondsHandlerRegistered then
                                state.counters.verdantBondsHandlerRegistered = true
                                Upgrades:AddEventHandler("UpgradeAcquired", function(data, RunState)
                                        if not RunState then return end
                                        if GetStacks(RunState, "verdant_bonds") <= 0 then return end
                                        if not data or not data.upgrade then return end

                                        local UpgradeTags = data.upgrade.tags
                                        local HasEconomy = false
                                        if UpgradeTags then
                                                for _, tag in ipairs(UpgradeTags) do
                                                        if tag == "economy" then
                                                                HasEconomy = true
                                                                break
                                                        end
                                                end
                                        end

                                        if not HasEconomy then return end

                                        RunState.counters = RunState.counters or {}
                                        local counters = RunState.counters

                                        local stacks = GetStacks(RunState, "verdant_bonds")
                                        if stacks <= 0 then return end

                                        local progress = (counters.verdantBondsProgress or 0) + stacks
                                        local threshold = 3
                                        local shields = math.floor(progress / threshold)
                                        counters.verdantBondsProgress = progress - shields * threshold

                                        if shields <= 0 then return end

                                        if Snake and Snake.AddCrashShields then
                                                Snake:AddCrashShields(shields)
                                        end

                                        local label = GetUpgradeString("verdant_bonds", "activation_text")
                                        if shields > 1 then
                                                if label and label ~= "" then
                                                        label = string.format("%s +%d", label, shields)
                                                else
                                                        label = string.format("+%d", shields)
                                                end
                                        end

                                        CelebrateUpgrade(label, data, {
                                                color = {0.58, 0.88, 0.64, 1},
                                                ParticleCount = 14,
                                                ParticleSpeed = 120,
                                                ParticleLife = 0.48,
                                                TextOffset = 46,
                                                TextScale = 1.1,
                                                visual = {
                                                        badge = "shield",
                                                        OuterRadius = 52,
                                                        InnerRadius = 16,
                                                        RingCount = 3,
                                                        life = 0.68,
                                                        GlowAlpha = 0.26,
                                                        HaloAlpha = 0.18,
                                                },
                                        })
                                end)
                        end
                end,
        }),
	register({
		id = "fresh_supplies",
		NameKey = "upgrades.fresh_supplies.name",
		DescKey = "upgrades.fresh_supplies.description",
		rarity = "common",
		tags = {"economy"},
		RestockShop = true,
		AllowDuplicates = true,
		weight = 0.6,
	}),
	register({
		id = "stone_census",
		NameKey = "upgrades.stone_census.name",
		DescKey = "upgrades.stone_census.description",
		rarity = "rare",
		RequiresTags = {"economy"},
		tags = {"economy", "defense"},
		OnAcquire = function(state)
			state.counters.stoneCensusReduction = 0.07
			state.counters.stoneCensusMult = state.counters.stoneCensusMult or 1
			UpdateStoneCensus(state)

			if not state.counters.stoneCensusHandlerRegistered then
				state.counters.stoneCensusHandlerRegistered = true
				Upgrades:AddEventHandler("UpgradeAcquired", function(_, RunState)
					if not RunState then return end
					if GetStacks(RunState, "stone_census") <= 0 then return end
					UpdateStoneCensus(RunState)
				end)
			end

			CelebrateUpgrade(GetUpgradeString("stone_census", "name"), nil, {
				color = {0.85, 0.92, 1, 1},
				ParticleCount = 16,
				ParticleSpeed = 110,
				ParticleLife = 0.4,
				TextOffset = 44,
				TextScale = 1.08,
			})
		end,
	}),
	register({
		id = "guild_ledger",
		NameKey = "upgrades.guild_ledger.name",
		DescKey = "upgrades.guild_ledger.description",
		rarity = "uncommon",
		RequiresTags = {"economy"},
		tags = {"economy", "defense"},
		OnAcquire = function(state)
			state.counters.guildLedgerFlatPerSlot = 0.015
			UpdateGuildLedger(state)

			if not state.counters.guildLedgerHandlerRegistered then
				state.counters.guildLedgerHandlerRegistered = true
				Upgrades:AddEventHandler("UpgradeAcquired", function(_, RunState)
					if not RunState then return end
					if GetStacks(RunState, "guild_ledger") <= 0 then return end
					UpdateGuildLedger(RunState)
				end)
			end

			CelebrateUpgrade(GetUpgradeString("guild_ledger", "name"), nil, {
				color = {1, 0.86, 0.46, 1},
				ParticleCount = 16,
				ParticleSpeed = 120,
				ParticleLife = 0.42,
				TextOffset = 42,
				TextScale = 1.1,
			})
		end,
        }),
        register({
                id = "predators_reflex",
                NameKey = "upgrades.predators_reflex.name",
                DescKey = "upgrades.predators_reflex.description",
                rarity = "rare",
		RequiresTags = {"adrenaline"},
		OnAcquire = function(state)
			state.effects.adrenaline = state.effects.adrenaline or { duration = 3, boost = 1.5 }
			state.effects.adrenalineBoostBonus = (state.effects.adrenalineBoostBonus or 0) + 0.25
		end,
		handlers = {
			FloorStart = function()
				if Snake.adrenaline then
					Snake.adrenaline.active = true
					Snake.adrenaline.timer = (Snake.adrenaline.duration or 0) * 0.5
				end
			end,
		},
	}),

	register({
		id = "abyssal_catalyst",
		NameKey = "upgrades.abyssal_catalyst.name",
		DescKey = "upgrades.abyssal_catalyst.description",
		rarity = "epic",
		AllowDuplicates = false,
		tags = {"defense", "risk"},
                UnlockTag = "abyssal_protocols",
                OnAcquire = function(state)
                        state.effects.laserChargeMult = (state.effects.laserChargeMult or 1) * 0.85
                        state.effects.laserFireMult = (state.effects.laserFireMult or 1) * 0.9
                        state.effects.laserCooldownFlat = (state.effects.laserCooldownFlat or 0) - 0.5
                        state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.2
                        state.effects.abyssalCatalyst = (state.effects.abyssalCatalyst or 0) + 1

                        GrantCrashShields(1)

                        CelebrateUpgrade(GetUpgradeString("abyssal_catalyst", "name"), nil, {
                                color = {0.62, 0.58, 0.94, 1},
				ParticleCount = 22,
				ParticleSpeed = 150,
				ParticleLife = 0.5,
				TextOffset = 48,
				TextScale = 1.14,
			})
		end,
	}),
	register({
		id = "spectral_harvest",
		NameKey = "upgrades.spectral_harvest.name",
		DescKey = "upgrades.spectral_harvest.description",
		rarity = "epic",
		tags = {"economy", "combo"},
		OnAcquire = function(state)
			state.counters.spectralHarvestReady = true
		end,
		handlers = {
			FloorStart = function(_, state)
				state.counters.spectralHarvestReady = true
			end,
			FruitCollected = function(_, state)
				if not state.counters.spectralHarvestReady then return end
				state.counters.spectralHarvestReady = false

				local Fruit = require("fruit")
				local FruitEvents = require("fruitevents")
				if not (Fruit and FruitEvents and FruitEvents.HandleConsumption) then return end

				local fx, fy = Fruit:GetPosition()
				if not (fx and fy) then return end

				FruitEvents.HandleConsumption(fx, fy)
			end,
		},
	}),
	register({
		id = "solar_reservoir",
		NameKey = "upgrades.solar_reservoir.name",
		DescKey = "upgrades.solar_reservoir.description",
		rarity = "epic",
		tags = {"economy", "defense"},
		OnAcquire = function(state)
			state.counters.solarReservoirReady = false
		end,
		handlers = {
			FloorStart = function(_, state)
				state.counters.solarReservoirReady = true
			end,
			FruitCollected = function(data, state)
				if not state.counters.solarReservoirReady then return end
				state.counters.solarReservoirReady = false
				if Saws and Saws.stall then
					Saws:stall(2)
				end
				if Score.AddBonus then
					Score:AddBonus(4)
				end
			end,
		},
	}),

	register({
		id = "tectonic_resolve",
		NameKey = "upgrades.tectonic_resolve.name",
		DescKey = "upgrades.tectonic_resolve.description",
		rarity = "rare",
		tags = {"defense"},
		OnAcquire = function(state)
			state.effects.rockSpawnMult = (state.effects.rockSpawnMult or 1) * 0.85
			state.effects.rockShatter = (state.effects.rockShatter or 0) + 0.25
		end,
	}),
	register({
		id = "titanblood_pact",
		NameKey = "upgrades.titanblood_pact.name",
		DescKey = "upgrades.titanblood_pact.description",
		rarity = "epic",
		tags = {"defense", "risk"},
		UnlockTag = "abyssal_protocols",
		weight = 1,
                OnAcquire = function(state)
                        Snake:AddCrashShields(3)
                        state.effects.sawStall = (state.effects.sawStall or 0) + 2
                        for _ = 1, 5 do
                                Snake:grow()
                        end
                        Snake.ExtraGrowth = (Snake.ExtraGrowth or 0) + 2
                        state.effects.titanbloodPact = (state.effects.titanbloodPact or 0) + 1
                        if Snake.SetTitanbloodStacks then
                                Snake:SetTitanbloodStacks(state.effects.titanbloodPact)
                        end
                end,
        }),
	register({
		id = "chronospiral_core",
		NameKey = "upgrades.chronospiral_core.name",
		DescKey = "upgrades.chronospiral_core.description",
		rarity = "epic",
		tags = {"combo", "defense", "risk"},
		weight = 1,
                UnlockTag = "combo_mastery",
                OnAcquire = function(state)
                        state.effects.sawSpeedMult = (state.effects.sawSpeedMult or 1) * 0.75
                        state.effects.sawSpinMult = (state.effects.sawSpinMult or 1) * 0.6
                        state.effects.comboBonusMult = (state.effects.comboBonusMult or 1) * 1.6
                        state.effects.chronospiralCore = true
                        for _ = 1, 4 do
                                Snake:grow()
                        end
                        Snake.ExtraGrowth = (Snake.ExtraGrowth or 0) + 1
                end,
	}),
	register({
		id = "phoenix_echo",
		NameKey = "upgrades.phoenix_echo.name",
		DescKey = "upgrades.phoenix_echo.description",
		rarity = "epic",
		tags = {"defense", "risk"},
		UnlockTag = "abyssal_protocols",
		OnAcquire = function(state)
			state.counters.phoenixEchoCharges = (state.counters.phoenixEchoCharges or 0) + 1
		end,
	}),
	register({
		id = "thunder_dash",
		NameKey = "upgrades.thunder_dash.name",
		DescKey = "upgrades.thunder_dash.description",
		rarity = "rare",
		tags = {"mobility"},
		AllowDuplicates = false,
		UnlockTag = "abilities",
		OnAcquire = function(state)
			local dash = state.effects.dash or {}
			dash.duration = dash.duration or 0.35
			dash.cooldown = dash.cooldown or 6
			dash.speedMult = dash.speedMult or 2.4
			dash.breaksRocks = true
			state.effects.dash = dash

			if not state.counters.thunderDashHandlerRegistered then
				state.counters.thunderDashHandlerRegistered = true
				Upgrades:AddEventHandler("DashActivated", function(data)
					local label = GetUpgradeString("thunder_dash", "activation_text")
					CelebrateUpgrade(label, data, {
						color = {1.0, 0.78, 0.32, 1},
						ParticleCount = 24,
						ParticleSpeed = 160,
						ParticleLife = 0.35,
						ParticleSize = 4,
						ParticleSpread = math.pi * 2,
						ParticleSpeedVariance = 90,
						TextOffset = 52,
						TextScale = 1.14,
					})
				end)
			end
		end,
	}),
	register({
		id = "sparkstep_relay",
		NameKey = "upgrades.sparkstep_relay.name",
		DescKey = "upgrades.sparkstep_relay.description",
		rarity = "rare",
		RequiresTags = {"mobility"},
		tags = {"mobility", "defense"},
		UnlockTag = "stormtech",
		handlers = {
			DashActivated = function(data)
				local fx, fy = GetEventPosition(data)
				if Rocks and Rocks.ShatterNearest then
					Rocks:ShatterNearest(fx or 0, fy or 0, 1)
				end
				if Saws and Saws.stall then
					Saws:stall(0.6)
				end
				CelebrateUpgrade(GetUpgradeString("sparkstep_relay", "activation_text"), data, {
					color = {1.0, 0.78, 0.36, 1},
					ParticleCount = 20,
					ParticleSpeed = 150,
					ParticleLife = 0.36,
					TextOffset = 56,
					TextScale = 1.16,
					visual = {
						badge = "bolt",
						OuterRadius = 54,
						InnerRadius = 18,
						RingCount = 3,
						life = 0.6,
						GlowAlpha = 0.32,
						HaloAlpha = 0.22,
					},
				})
			end,
		},
        }),
        register({
                id = "temporal_anchor",
		NameKey = "upgrades.temporal_anchor.name",
		DescKey = "upgrades.temporal_anchor.description",
		rarity = "rare",
		tags = {"utility", "defense"},
		AllowDuplicates = false,
		UnlockTag = "timekeeper",
                OnAcquire = function(state)
                        local ability = state.effects.timeSlow or {}
                        ability.duration = ability.duration or 1.6
                        ability.cooldown = ability.cooldown or 8
                        ability.timeScale = ability.timeScale or 0.35
                        ability.source = ability.source or "temporal_anchor"
                        state.effects.timeSlow = ability

			if not state.counters.temporalAnchorHandlerRegistered then
				state.counters.temporalAnchorHandlerRegistered = true
				Upgrades:AddEventHandler("TimeDilationActivated", function(data)
					local label = GetUpgradeString("temporal_anchor", "activation_text")
					CelebrateUpgrade(label, data, {
						color = {0.62, 0.84, 1.0, 1},
						ParticleCount = 26,
						ParticleSpeed = 120,
						ParticleLife = 0.5,
						ParticleSize = 5,
						ParticleSpread = math.pi * 2,
						ParticleSpeedVariance = 70,
						TextOffset = 60,
						TextScale = 1.12,
					})
				end)
			end
		end,
	}),
	register({
		id = "zephyr_coils",
		NameKey = "upgrades.zephyr_coils.name",
		DescKey = "upgrades.zephyr_coils.description",
		rarity = "rare",
		tags = {"mobility", "risk"},
		UnlockTag = "stormtech",
		OnAcquire = function(state)
			Snake:AddSpeedMultiplier(1.2)
			Snake.ExtraGrowth = (Snake.ExtraGrowth or 0) + 1
		end,
	}),
	register({
		id = "event_horizon",
		NameKey = "upgrades.event_horizon.name",
		DescKey = "upgrades.event_horizon.description",
		rarity = "legendary",
		tags = {"defense", "mobility"},
		AllowDuplicates = false,
		weight = 1,
		UnlockTag = "legendary",
                OnAcquire = function(state)
                        state.effects.wallPortal = true
                        CelebrateUpgrade(GetUpgradeString("event_horizon", "name"), nil, {
                                color = {1, 0.86, 0.34, 1},
                                ParticleCount = 32,
                                ParticleSpeed = 160,
                                ParticleLife = 0.6,
                                ParticleSize = 5,
                                ParticleSpread = math.pi * 2,
                                ParticleSpeedVariance = 90,
                                visual = {
                                        variant = "event_horizon",
                                        ShowBase = false,
                                        life = 0.92,
                                        InnerRadius = 16,
                                        OuterRadius = 62,
                                        color = {1, 0.86, 0.34, 1},
                                        VariantSecondaryColor = {0.46, 0.78, 1.0, 0.9},
                                },
                        })
                end,
        }),
}

local function GetRarityInfo(rarity)
	return rarities[rarity or "common"] or rarities.common
end

function Upgrades:BeginRun()
	self.RunState = NewRunState()
end

function Upgrades:GetEffect(name)
	if not name then return nil end
	return self.RunState.effects[name]
end

function Upgrades:HasTag(tag)
	return tag and self.RunState.tags[tag] or false
end

function Upgrades:AddTag(tag)
	if not tag then return end
	self.RunState.tags[tag] = true
end

local function HudText(key, replacements)
	return Localization:get("upgrades.hud." .. key, replacements)
end

function Upgrades:GetTakenCount(id)
	if not id then return 0 end
	return GetStacks(self.RunState, id)
end

function Upgrades:AddEventHandler(event, handler)
	if not event or type(handler) ~= "function" then return end
	local state = self.RunState
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
	local state = self.RunState
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

function Upgrades:GetHUDIndicators()
	local indicators = {}
	local state = self.RunState
	if not state then
		return indicators
	end

	local function HasUpgrade(id)
		return GetStacks(state, id) > 0
	end

	local StoneStacks = state.counters and state.counters.stonebreakerStacks or 0
	if StoneStacks > 0 then
		local label = Localization:get("upgrades.stonebreaker_hymn.name")
		local current = 0
		if Rocks.GetShatterProgress then
			current = Rocks:GetShatterProgress() or 0
		end

		local rate = 0
		if Rocks.GetShatterRate then
			rate = Rocks:GetShatterRate() or 0
		else
			rate = Rocks.ShatterOnFruit or 0
		end

		local progress = 0
		local IsReady = false
		if rate and rate > 0 then
			if rate >= 1 then
				progress = 1
				IsReady = true
			else
				progress = clamp(current, 0, 1)
				if progress >= 0.999 then
					IsReady = true
				end
			end
		end

		local StatusKey
		if not rate or rate <= 0 then
			StatusKey = "depleted"
		elseif IsReady then
			StatusKey = "ready"
		else
			StatusKey = "charging"
		end

		local ChargeLabel
		if rate and rate > 0 then
			ChargeLabel = HudText("percent", { percent = math.floor(progress * 100 + 0.5) })
		end

		table.insert(indicators, {
			id = "stonebreaker_hymn",
			label = label,
			AccentColor = {1.0, 0.78, 0.36, 1},
			StackCount = StoneStacks,
			charge = progress,
			ChargeLabel = ChargeLabel,
			status = HudText(StatusKey),
			icon = "pickaxe",
			ShowBar = true,
		})
	end

	if HasUpgrade("pocket_springs") then
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
				AccentColor = {0.58, 0.82, 1.0, 1.0},
				StackCount = nil,
				charge = progress,
				ChargeLabel = HudText("progress", {
					current = tostring(collected),
					target = tostring(POCKET_SPRINGS_FRUIT_TARGET),
				}),
				status = HudText("charging"),
				icon = "shield",
				ShowBar = true,
			})
		end
	end

	local AdrenalineTaken = HasUpgrade("adrenaline_surge")
	local adrenaline = Snake.adrenaline
	if AdrenalineTaken or (adrenaline and adrenaline.active) then
		local label = Localization:get("upgrades.adrenaline_surge.name")
		local active = adrenaline and adrenaline.active
		local duration = (adrenaline and adrenaline.duration) or 0
		local timer = (adrenaline and math.max(adrenaline.timer or 0, 0)) or 0
		local charge
		local ChargeLabel

		if active and duration > 0 then
			charge = clamp(timer / duration, 0, 1)
			ChargeLabel = HudText("seconds", { seconds = string.format("%.1f", timer) })
		end

		local status = active and HudText("active") or HudText("ready")

		table.insert(indicators, {
			id = "adrenaline_surge",
			label = label,
			HideLabel = true,
			AccentColor = {1.0, 0.45, 0.45, 1},
			StackCount = nil,
			charge = charge,
			ChargeLabel = ChargeLabel,
			status = status,
			icon = "bolt",
			ShowBar = active and charge ~= nil,
		})
	end

	local DashState = Snake.GetDashState and Snake:GetDashState()
	if DashState then
		local label = Localization:get("upgrades.thunder_dash.name")
		local accent = {1.0, 0.78, 0.32, 1}
		local status
		local charge
		local ChargeLabel
		local ShowBar = false

		if DashState.active and DashState.duration > 0 then
			local remaining = math.max(DashState.timer or 0, 0)
			charge = clamp(remaining / DashState.duration, 0, 1)
			ChargeLabel = HudText("seconds", { seconds = string.format("%.1f", remaining) })
			status = HudText("active")
			ShowBar = true
		else
			local cooldown = DashState.cooldown or 0
			local RemainingCooldown = math.max(DashState.cooldownTimer or 0, 0)
			if cooldown > 0 and RemainingCooldown > 0 then
				local progress = 1 - clamp(RemainingCooldown / cooldown, 0, 1)
				charge = progress
				ChargeLabel = HudText("seconds", { seconds = string.format("%.1f", RemainingCooldown) })
				status = HudText("charging")
				ShowBar = true
			else
				charge = 1
				status = HudText("ready")
			end
		end

		table.insert(indicators, {
			id = "thunder_dash",
			label = label,
			HideLabel = true,
			AccentColor = accent,
			StackCount = nil,
			charge = charge,
			ChargeLabel = ChargeLabel,
			status = status,
			icon = "bolt",
			ShowBar = ShowBar,
		})
	end

	local TimeState = Snake.GetTimeDilationState and Snake:GetTimeDilationState()
	if TimeState then
		local label = Localization:get("upgrades.temporal_anchor.name")
		local accent = {0.62, 0.84, 1.0, 1}
		local status
		local charge
		local ChargeLabel
		local ShowBar = false

		local ChargesRemaining = TimeState.floorCharges
		local MaxUses = TimeState.maxFloorUses

		if TimeState.active and TimeState.duration > 0 then
			local remaining = math.max(TimeState.timer or 0, 0)
			charge = clamp(remaining / TimeState.duration, 0, 1)
			ChargeLabel = HudText("seconds", { seconds = string.format("%.1f", remaining) })
			status = HudText("active")
			ShowBar = true
		else
			if MaxUses and ChargesRemaining ~= nil and ChargesRemaining <= 0 then
				charge = 0
				status = HudText("depleted")
				ChargeLabel = nil
				ShowBar = false
			else
				local cooldown = TimeState.cooldown or 0
				local RemainingCooldown = math.max(TimeState.cooldownTimer or 0, 0)
				if cooldown > 0 and RemainingCooldown > 0 then
					local progress = 1 - clamp(RemainingCooldown / cooldown, 0, 1)
					charge = progress
					ChargeLabel = HudText("seconds", { seconds = string.format("%.1f", RemainingCooldown) })
					status = HudText("charging")
					ShowBar = true
				else
					charge = 1
					status = HudText("ready")
				end
			end
		end

		table.insert(indicators, {
			id = "temporal_anchor",
			label = label,
			HideLabel = true,
			AccentColor = accent,
			StackCount = nil,
			charge = charge,
			ChargeLabel = ChargeLabel,
			status = status,
			icon = "hourglass",
			ShowBar = ShowBar,
		})
	end

	local PhoenixCharges = 0
	if state.counters then
		PhoenixCharges = state.counters.phoenixEchoCharges or 0
	end

	if PhoenixCharges > 0 then
		local label = Localization:get("upgrades.phoenix_echo.name")
		table.insert(indicators, {
			id = "phoenix_echo",
			label = label,
			AccentColor = {1.0, 0.62, 0.32, 1},
			StackCount = PhoenixCharges,
			charge = nil,
			status = nil,
			icon = "phoenix",
			ShowBar = false,
		})
	end

	return indicators
end

function Upgrades:RecordFloorReplaySnapshot(game)
	if not game then return end

	local state = self.RunState
	if not state or not state.counters then return end

	-- The phoenix upgrade no longer tracks snake position, so we don't need to
	-- capture any state here.
	return
end

function Upgrades:ModifyFloorContext(context)
	if not context then return context end

	local effects = self.RunState.effects
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

function Upgrades:GetComboBonus(ComboCount)
	local bonus = 0
	local breakdown = {}

	if not ComboCount or ComboCount < 2 then
		return bonus, breakdown
	end

	local effects = self.RunState.effects
	local flat = (effects.comboBonusFlat or 0) * (ComboCount - 1)
	if flat ~= 0 then
		local amount = round(flat)
		if amount ~= 0 then
			bonus = bonus + amount
			table.insert(breakdown, { label = Localization:get("upgrades.momentum_label"), amount = amount })
		end
	end

	return bonus, breakdown
end

function Upgrades:TryFloorReplay(game, cause)
	if not game then return false end

	local state = self.RunState
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
	Snake:ResetPosition()
	restored = true

	game.state = "playing"
	game.deathCause = nil

	local hx, hy = Snake:GetHead()
        CelebrateUpgrade(GetUpgradeString("phoenix_echo", "name"), nil, {
                x = hx,
                y = hy,
                color = {1, 0.62, 0.32, 1},
                ParticleCount = 24,
                ParticleSpeed = 170,
                ParticleLife = 0.6,
                TextOffset = 60,
                TextScale = 1.22,
                visual = {
                        variant = "phoenix_flare",
                        ShowBase = false,
                        life = 1.18,
                        InnerRadius = 16,
                        OuterRadius = 58,
                        AddBlend = true,
                        color = {1, 0.62, 0.32, 1},
                        VariantSecondaryColor = {1, 0.44, 0.14, 0.95},
                        VariantTertiaryColor = {1, 0.85, 0.48, 0.88},
                },
        })

        self:ApplyPersistentEffects(false)
        if Snake.SetPhoenixEchoCharges then
                Snake:SetPhoenixEchoCharges(state.counters.phoenixEchoCharges or 0, { triggered = 1.4, FlareDuration = 1.4 })
        end

        return restored
end

local function CaptureBaseline(state)
	local baseline = state.baseline
	baseline.sawSpeedMult = Saws.SpeedMult or 1
	baseline.sawSpinMult = Saws.SpinMult or 1
	if Saws.GetStallOnFruit then
		baseline.sawStall = Saws:GetStallOnFruit()
	else
		baseline.sawStall = Saws.StallOnFruit or 0
	end
	if Rocks.GetSpawnChance then
		baseline.rockSpawnChance = Rocks:GetSpawnChance()
	else
		baseline.rockSpawnChance = Rocks.SpawnChance or 0.25
	end
	baseline.rockShatter = Rocks.ShatterOnFruit or 0
	if Score.GetComboBonusMultiplier then
		baseline.comboBonusMult = Score:GetComboBonusMultiplier()
	else
		baseline.comboBonusMult = Score.ComboBonusMult or 1
	end
	if Lasers then
		baseline.laserChargeMult = Lasers.ChargeDurationMult or 1
		baseline.laserChargeFlat = Lasers.ChargeDurationFlat or 0
		baseline.laserFireMult = Lasers.FireDurationMult or 1
		baseline.laserFireFlat = Lasers.FireDurationFlat or 0
		baseline.laserCooldownMult = Lasers.CooldownMult or 1
		baseline.laserCooldownFlat = Lasers.CooldownFlat or 0
	end
end

local function EnsureBaseline(state)
	state.baseline = state.baseline or {}
	if not next(state.baseline) then
		CaptureBaseline(state)
	end
end

function Upgrades:ApplyPersistentEffects(rebaseline)
	local state = self.RunState
	local effects = state.effects

	if rebaseline then
		state.baseline = {}
	end
	EnsureBaseline(state)
	local base = state.baseline

	local SawSpeed = (base.sawSpeedMult or 1) * (effects.sawSpeedMult or 1)
	local SawSpin = (base.sawSpinMult or 1) * (effects.sawSpinMult or 1)
	Saws.SpeedMult = SawSpeed
	Saws.SpinMult = SawSpin

	local StallBase = base.sawStall or 0
	local StallBonus = effects.sawStall or 0
	local StallValue = StallBase + StallBonus
	if Saws.SetStallOnFruit then
		Saws:SetStallOnFruit(StallValue)
	else
		Saws.StallOnFruit = StallValue
	end

	local RockBase = base.rockSpawnChance or 0.25
	local RockChance = math.max(0.02, RockBase * (effects.rockSpawnMult or 1) + (effects.rockSpawnFlat or 0))
	Rocks.SpawnChance = RockChance
	Rocks.ShatterOnFruit = (base.rockShatter or 0) + (effects.rockShatter or 0)
	if Snake.SetStonebreakerStacks then
		local stacks = 0
		if state and state.counters then
			stacks = state.counters.stonebreakerStacks or 0
		end
		if stacks <= 0 and effects.rockShatter then
			local PerStack = 0.25
			stacks = math.floor(((effects.rockShatter or 0) / PerStack) + 0.5)
		end
		Snake:SetStonebreakerStacks(stacks)
	end

	local ComboBase = base.comboBonusMult or 1
	local ComboMult = ComboBase * (effects.comboBonusMult or 1)
	if Score.SetComboBonusMultiplier then
		Score:SetComboBonusMultiplier(ComboMult)
	else
		Score.ComboBonusMult = ComboMult
	end

	if Lasers then
		Lasers.ChargeDurationMult = (base.laserChargeMult or 1) * (effects.laserChargeMult or 1)
		Lasers.ChargeDurationFlat = (base.laserChargeFlat or 0) + (effects.laserChargeFlat or 0)
		Lasers.FireDurationMult = (base.laserFireMult or 1) * (effects.laserFireMult or 1)
		Lasers.FireDurationFlat = (base.laserFireFlat or 0) + (effects.laserFireFlat or 0)
		Lasers.CooldownMult = (base.laserCooldownMult or 1) * (effects.laserCooldownMult or 1)
		Lasers.CooldownFlat = (base.laserCooldownFlat or 0) + (effects.laserCooldownFlat or 0)
		if Lasers.ApplyTimingModifiers then
			Lasers:ApplyTimingModifiers()
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
		local FirstSetup = not dash.configured
		dash.duration = effects.dash.duration or dash.duration or 0
		dash.cooldown = effects.dash.cooldown or dash.cooldown or 0
		dash.speedMult = effects.dash.speedMult or dash.speedMult or 1
		dash.breaksRocks = effects.dash.breaksRocks ~= false
		dash.configured = true
		dash.timer = dash.timer or 0
		dash.cooldownTimer = dash.cooldownTimer or 0
		dash.active = dash.active or false
		if FirstSetup then
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
		Snake.TimeDilation = Snake.TimeDilation or {}
		local ability = Snake.TimeDilation
		local FirstSetup = not ability.configured
		ability.duration = effects.timeSlow.duration or ability.duration or 0
		ability.cooldown = effects.timeSlow.cooldown or ability.cooldown or 0
		ability.timeScale = effects.timeSlow.timeScale or ability.timeScale or 1
		ability.configured = true
		ability.timer = ability.timer or 0
		ability.cooldownTimer = ability.cooldownTimer or 0
		ability.active = ability.active or false
		if FirstSetup then
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
		if FirstSetup or rebaseline then
			ability.floorCharges = ability.maxFloorUses
		elseif ability.floorCharges == nil then
			ability.floorCharges = ability.maxFloorUses
		else
			local MaxUses = ability.maxFloorUses or ability.floorCharges
			ability.floorCharges = math.max(0, math.min(ability.floorCharges, MaxUses))
		end
        else
                Snake.TimeDilation = nil
        end

        if Snake.SetChronospiralActive then
                Snake:SetChronospiralActive(effects.chronospiralCore and true or false)
        end

        if Snake.SetAbyssalCatalystStacks then
                Snake:SetAbyssalCatalystStacks(effects.abyssalCatalyst or 0)
        end

        if Snake.SetTitanbloodStacks then
                Snake:SetTitanbloodStacks(effects.titanbloodPact or 0)
        end

        if Snake.SetEventHorizonActive then
                Snake:SetEventHorizonActive(effects.wallPortal and true or false)
        end

        if Snake.SetQuickFangsStacks then
                local counters = state.counters or {}
                Snake:SetQuickFangsStacks(counters.quickFangsStacks or 0)
        end

        if Snake.SetPhoenixEchoCharges then
                local counters = state.counters or {}
                Snake:SetPhoenixEchoCharges(counters.phoenixEchoCharges or 0)
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

local function CalculateWeight(upgrade, PityLevel)
	local RarityInfo = GetRarityInfo(upgrade.rarity)
	local RarityWeight = RarityInfo.weight or 1
	local weight = RarityWeight * (upgrade.weight or 1)

	local bonus = SHOP_PITY_RARITY_BONUS[upgrade.rarity]
	if bonus and PityLevel and PityLevel > 0 then
		weight = weight * (1 + math.min(PityLevel, SHOP_PITY_MAX) * bonus)
	end

	return weight
end

function Upgrades:CanOffer(upgrade, context, AllowTaken)
        if not upgrade then return false end

        local count = self:GetTakenCount(upgrade.id)
        if upgrade.rarity == "legendary" and count > 0 then
                return false
        end

        if not AllowTaken then
                if (count > 0 and not upgrade.allowDuplicates) then
                        return false
                end
                if upgrade.maxStacks and count >= upgrade.maxStacks then
                        return false
                end
	end

	if upgrade.requiresTags then
		for _, tag in ipairs(upgrade.requiresTags) do
			if not self:HasTag(tag) then
				return false
			end
		end
	end

	if upgrade.excludesTags then
		for _, tag in ipairs(upgrade.excludesTags) do
			if self:HasTag(tag) then
				return false
			end
		end
	end

	local CombinedUnlockTags = nil
	if type(upgrade.unlockTags) == "table" then
		CombinedUnlockTags = {}
		for _, tag in ipairs(upgrade.unlockTags) do
			CombinedUnlockTags[#CombinedUnlockTags + 1] = tag
		end
	end
	if upgrade.unlockTag then
		CombinedUnlockTags = CombinedUnlockTags or {}
		CombinedUnlockTags[#CombinedUnlockTags + 1] = upgrade.unlockTag
	end

	if CombinedUnlockTags and MetaProgression and MetaProgression.IsTagUnlocked then
		for _, tag in ipairs(CombinedUnlockTags) do
			if tag and not MetaProgression:IsTagUnlocked(tag) then
				return false
			end
		end
	elseif upgrade.unlockTag and MetaProgression and MetaProgression.IsTagUnlocked then
		if not MetaProgression:IsTagUnlocked(upgrade.unlockTag) then
			return false
		end
	end

	if upgrade.condition and not upgrade.condition(self.RunState, context) then
		return false
	end

	return true
end

local function DecorateCard(upgrade)
	local RarityInfo = GetRarityInfo(upgrade.rarity)
	local name = upgrade.name
	local description = upgrade.desc
	local RarityLabel = RarityInfo and RarityInfo.label

	if upgrade.nameKey then
		name = Localization:get(upgrade.nameKey)
	end
	if upgrade.descKey then
		description = Localization:get(upgrade.descKey)
	end
	if RarityInfo and RarityInfo.labelKey then
		RarityLabel = Localization:get(RarityInfo.labelKey)
	end

	return {
		id = upgrade.id,
		name = name,
		desc = description,
		rarity = upgrade.rarity,
		RarityColor = RarityInfo.color,
		RarityLabel = RarityLabel,
		RestockShop = upgrade.restockShop,
		upgrade = upgrade,
	}
end

function Upgrades:GetRandom(n, context)
	local state = self.RunState or NewRunState()
	local PityLevel = 0
	if state and state.counters then
		PityLevel = math.min(state.counters.shopBadLuck or 0, SHOP_PITY_MAX)
	end

	local available = {}
	for _, upgrade in ipairs(pool) do
		if self:CanOffer(upgrade, context, false) then
			table.insert(available, upgrade)
		end
	end

	if #available == 0 then
		for _, upgrade in ipairs(pool) do
			if self:CanOffer(upgrade, context, true) then
				table.insert(available, upgrade)
			end
		end
	end

	local cards = {}
	n = math.min(n or 3, #available)
	for _ = 1, n do
		local TotalWeight = 0
		local weights = {}
		for i, upgrade in ipairs(available) do
			local weight = CalculateWeight(upgrade, PityLevel)
			TotalWeight = TotalWeight + weight
			weights[i] = weight
		end

		if TotalWeight <= 0 then break end

		local roll = love.math.random() * TotalWeight
		local cumulative = 0
		local ChosenIndex = 1
		for i, weight in ipairs(weights) do
			cumulative = cumulative + weight
			if roll <= cumulative then
				ChosenIndex = i
				break
			end
		end

		local choice = available[ChosenIndex]
		table.insert(cards, DecorateCard(choice))
		table.remove(available, ChosenIndex)
		if #available == 0 then break end
	end

	if state and state.counters then
		local BestRank = 0
		for _, card in ipairs(cards) do
			local rank = SHOP_PITY_RARITY_RANK[card.rarity] or 0
			if rank > BestRank then
				BestRank = rank
			end
		end

		if BestRank >= (SHOP_PITY_RARITY_RANK.rare or 0) then
			state.counters.shopBadLuck = 0
		else
			local counter = (state.counters.shopBadLuck or 0) + 1
			state.counters.shopBadLuck = math.min(counter, SHOP_PITY_MAX)
		end

		local LegendaryUnlocked = MetaProgression and MetaProgression.IsTagUnlocked and MetaProgression:IsTagUnlocked("legendary")
		if LegendaryUnlocked then
			local HasLegendary = false
			for _, card in ipairs(cards) do
				if card.rarity == "legendary" then
					HasLegendary = true
					break
				end
			end

			if HasLegendary then
				state.counters.legendaryBadLuck = 0
			else
				local LegendaryCounter = (state.counters.legendaryBadLuck or 0) + 1
				if LegendaryCounter >= LEGENDARY_PITY_THRESHOLD then
					local LegendaryChoices = {}
					for _, upgrade in ipairs(pool) do
						if upgrade.rarity == "legendary" and self:CanOffer(upgrade, context, false) then
							table.insert(LegendaryChoices, DecorateCard(upgrade))
						end
					end
					if #LegendaryChoices == 0 then
						for _, upgrade in ipairs(pool) do
							if upgrade.rarity == "legendary" and self:CanOffer(upgrade, context, true) then
								table.insert(LegendaryChoices, DecorateCard(upgrade))
							end
						end
					end

					if #LegendaryChoices > 0 then
						local ReplacementIndex
						local LowestRank
						for index, card in ipairs(cards) do
							local rank = SHOP_PITY_RARITY_RANK[card.rarity] or 0
							if not ReplacementIndex or rank < LowestRank then
								ReplacementIndex = index
								LowestRank = rank
							end
						end

						if ReplacementIndex then
							cards[ReplacementIndex] = LegendaryChoices[love.math.random(1, #LegendaryChoices)]
						else
							table.insert(cards, LegendaryChoices[love.math.random(1, #LegendaryChoices)])
						end

						LegendaryCounter = 0
					end
				end

				state.counters.legendaryBadLuck = math.min(LegendaryCounter, LEGENDARY_PITY_THRESHOLD)
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
	local state = self.RunState

	if state and state.addStacks then
		state:addStacks(upgrade.id, 1)
	else
		local CurrentStacks = GetStacks(state, upgrade.id)
		state.takenSet[upgrade.id] = CurrentStacks + 1
	end
	table.insert(state.takenOrder, upgrade.id)

	PlayerStats:add("TotalUpgradesPurchased", 1)
	PlayerStats:UpdateMax("MostUpgradesInRun", #state.takenOrder)

	if upgrade.rarity == "legendary" then
		PlayerStats:add("LegendaryUpgradesPurchased", 1)
	end

	if upgrade.tags then
		for _, tag in ipairs(upgrade.tags) do
			self:AddTag(tag)
		end
	end

	if upgrade.onAcquire then
		upgrade.onAcquire(state, context)
	end

	if upgrade.handlers then
		for event, handler in pairs(upgrade.handlers) do
			self:AddEventHandler(event, handler)
		end
	end

	self:notify("UpgradeAcquired", { id = upgrade.id, upgrade = upgrade, context = context })
	self:ApplyPersistentEffects(false)
end

return Upgrades
