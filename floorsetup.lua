local Theme = require("theme")
local Snake = require("snake")
local SnakeUtils = require("snakeutils")
local Arena = require("arena")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Lasers = require("lasers")
local Darts = require("darts")
local Movement = require("movement")
local Particles = require("particles")
local FloatingText = require("floatingtext")
local FloorPlan = require("floorplan")
local Upgrades = require("upgrades")

local FloorSetup = {}

local TRACK_LENGTH = 120
local DEFAULT_SAW_RADIUS = 16

local function ApplyPalette(palette)
	if Theme.reset then
		Theme.reset()
	end

	if not palette then
		return
	end

	for key, value in pairs(palette) do
		Theme[key] = value
	end
end

local function ResetFloorEntities()
	Arena:ResetExit()
	if Arena.ClearSpawnDebugData then
		Arena:ClearSpawnDebugData()
	end
	Movement:reset()
	FloatingText:reset()
	Particles:reset()
	Rocks:reset()
	Saws:reset()
	Lasers:reset()
	Darts:reset()
end

local function GetCenterSpawnCell()
	local cols = Arena.cols or 1
	local rows = Arena.rows or 1
	if cols < 1 then cols = 1 end
	if rows < 1 then rows = 1 end

	local MidCol = math.floor(cols / 2)
	local MidRow = math.floor(rows / 2)
	return MidCol, MidRow
end

local function SawPlacementThreatensSpawn(col, row, dir)
	if not (col and row and dir) then
		return false
	end

	local MidCol, MidRow = GetCenterSpawnCell()

	if dir == "horizontal" then
		if math.abs(col - MidCol) <= 2 then
			return true
		end

		if math.abs(row - MidRow) <= 1 then
			return true
		end
	else
		if math.abs(row - MidRow) <= 2 then
			return true
		end
	end

	return false
end

local function AddCellUnique(list, seen, col, row)
	if not (col and row) then
		return
	end

	col = math.floor(col + 0.5)
	row = math.floor(row + 0.5)

	if col < 1 or col > (Arena.cols or 1) or row < 1 or row > (Arena.rows or 1) then
		return
	end

	local key = col .. "," .. row
	if seen[key] then
		return
	end

	seen[key] = true
	list[#list + 1] = { col, row }
end

local function BuildSpawnBuffer(BaseSafeZone)
	local buffer = {}
	local seen = {}

	if BaseSafeZone then
		for _, cell in ipairs(BaseSafeZone) do
			AddCellUnique(buffer, seen, cell[1], cell[2])
		end
	end

	local HeadCol, HeadRow = Snake:GetHeadCell()
	local dir = Snake:GetDirection() or { x = 0, y = 0 }
	local DirX, DirY = dir.x or 0, dir.y or 0

	if DirX == 0 and DirY == 0 then
		DirX, DirY = 1, 0
	end

	if HeadCol and HeadRow then
		AddCellUnique(buffer, seen, HeadCol, HeadRow)
		for i = 1, 5 do
			AddCellUnique(buffer, seen, HeadCol + DirX * i, HeadRow + DirY * i)
		end
	else
		local MidCol, MidRow = GetCenterSpawnCell()
		AddCellUnique(buffer, seen, MidCol, MidRow)
		for i = 1, 5 do
			AddCellUnique(buffer, seen, MidCol + DirX * i, MidRow + DirY * i)
		end
	end

	return buffer
end

local function PrepareOccupancy()
	SnakeUtils.InitOccupancy()

	for _, segment in ipairs(Snake:GetSegments()) do
		local col, row = Arena:GetTileFromWorld(segment.drawX, segment.drawY)
		SnakeUtils.SetOccupied(col, row, true)
	end

	local SafeZone = Snake:GetSafeZone(3)
	local RockSafeZone = Snake:GetSafeZone(5)
	local SpawnBuffer = BuildSpawnBuffer(RockSafeZone)
	local HeadCol, HeadRow = Snake:GetHeadCell()
	local ReservedCandidates = {}

	if HeadCol and HeadRow then
		for dx = -1, 1 do
			for dy = -1, 1 do
				ReservedCandidates[#ReservedCandidates + 1] = { HeadCol + dx, HeadRow + dy }
			end
		end
	end

	if SafeZone then
		for _, cell in ipairs(SafeZone) do
			ReservedCandidates[#ReservedCandidates + 1] = { cell[1], cell[2] }
		end
	end

	if RockSafeZone then
		for _, cell in ipairs(RockSafeZone) do
			ReservedCandidates[#ReservedCandidates + 1] = { cell[1], cell[2] }
		end
	end

	local ReservedCells = SnakeUtils.ReserveCells(ReservedCandidates)
	local ReservedSafeZone = SnakeUtils.ReserveCells(SafeZone)
	local ReservedSpawnBuffer = SnakeUtils.ReserveCells(SpawnBuffer)

	return SafeZone, ReservedCells, ReservedSafeZone, RockSafeZone, SpawnBuffer, ReservedSpawnBuffer
end

local function ApplyBaselineHazardTraits(TraitContext)
	TraitContext.laserCount = math.max(0, TraitContext.laserCount or 0)
	TraitContext.dartCount = math.max(0, TraitContext.dartCount or 0)

	if TraitContext.rockSpawnChance then
		Rocks.SpawnChance = TraitContext.rockSpawnChance
	end

	if TraitContext.sawSpeedMult then
		Saws.SpeedMult = TraitContext.sawSpeedMult
	end

	if TraitContext.sawSpinMult then
		Saws.SpinMult = TraitContext.sawSpinMult
	end

	if Saws.SetStallOnFruit then
		Saws:SetStallOnFruit(TraitContext.sawStall or 0)
	else
		Saws.StallOnFruit = TraitContext.sawStall or 0
	end
end

local function FinalizeTraitContext(TraitContext, SpawnPlan)
	TraitContext.rockSpawnChance = Rocks:GetSpawnChance()
	TraitContext.sawSpeedMult = Saws.SpeedMult
	TraitContext.sawSpinMult = Saws.SpinMult

	if Saws.GetStallOnFruit then
		TraitContext.sawStall = Saws:GetStallOnFruit()
	else
		TraitContext.sawStall = Saws.StallOnFruit or 0
	end

	TraitContext.laserCount = SpawnPlan.laserCount or #(SpawnPlan.lasers or {})
	TraitContext.dartCount = SpawnPlan.dartCount or #(SpawnPlan.darts or {})
end

local function BuildCellLookup(cells)
	if not cells or #cells == 0 then
		return nil
	end

	local lookup = {}
	for _, cell in ipairs(cells) do
		local col = math.floor((cell[1] or 0) + 0.5)
		local row = math.floor((cell[2] or 0) + 0.5)
		lookup[col .. "," .. row] = true
	end

	return lookup
end

local function TrackThreatensSpawnBuffer(fx, fy, dir, SpawnLookup)
	if not SpawnLookup then
		return false
	end

	local cells = SnakeUtils.GetSawTrackCells(fx, fy, dir)
	for _, cell in ipairs(cells) do
		if SpawnLookup[cell[1] .. "," .. cell[2]] then
			return true
		end
	end

	return false
end

local function TrySpawnHorizontalSaw(HalfTiles, BladeRadius, SpawnLookup)
	local row = love.math.random(2, Arena.rows - 1)
	local col = love.math.random(1 + HalfTiles, Arena.cols - HalfTiles)
	local fx, fy = Arena:GetCenterOfTile(col, row)

	if SawPlacementThreatensSpawn(col, row, "horizontal") then
		return false
	end

	if TrackThreatensSpawnBuffer(fx, fy, "horizontal", SpawnLookup) then
		return false
	end

	if SnakeUtils.SawTrackIsFree(fx, fy, "horizontal") then
		Saws:spawn(fx, fy, BladeRadius, 8, "horizontal")
		SnakeUtils.OccupySawTrack(fx, fy, "horizontal")
		return true
	end

	return false
end

local function TrySpawnVerticalSaw(HalfTiles, BladeRadius, SpawnLookup)
	local side = (love.math.random() < 0.5) and "left" or "right"
	local col = (side == "left") and 1 or Arena.cols
	local row = love.math.random(1 + HalfTiles, Arena.rows - HalfTiles)
	local fx, fy = Arena:GetCenterOfTile(col, row)

	if SawPlacementThreatensSpawn(col, row, "vertical") then
		return false
	end

	if TrackThreatensSpawnBuffer(fx, fy, "vertical", SpawnLookup) then
		return false
	end

	if SnakeUtils.SawTrackIsFree(fx, fy, "vertical") then
		Saws:spawn(fx, fy, BladeRadius, 8, "vertical", side)
		SnakeUtils.OccupySawTrack(fx, fy, "vertical")
		return true
	end

	return false
end

local function SpawnSaws(NumSaws, HalfTiles, BladeRadius, SpawnBuffer)
	local SpawnLookup = BuildCellLookup(SpawnBuffer)

	for _ = 1, NumSaws do
		local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
		local placed = false
		local attempts = 0
		local MaxAttempts = 60

		while not placed and attempts < MaxAttempts do
			attempts = attempts + 1

			if dir == "horizontal" then
				placed = TrySpawnHorizontalSaw(HalfTiles, BladeRadius, SpawnLookup)
			else
				placed = TrySpawnVerticalSaw(HalfTiles, BladeRadius, SpawnLookup)
			end
		end
	end
end

local function SpawnLasers(LaserPlan)
	if not (LaserPlan and #LaserPlan > 0) then
		return
	end

	for _, plan in ipairs(LaserPlan) do
		Lasers:spawn(plan.x, plan.y, plan.dir, plan.options)
	end
end

local function SpawnDarts(DartPlan)
	if not (DartPlan and #DartPlan > 0) then
		return
	end

	for _, plan in ipairs(DartPlan) do
		Darts:spawn(plan.x, plan.y, plan.dir, plan.options)
	end
end

local function SpawnRocks(NumRocks, SafeZone)
	for _ = 1, NumRocks do
		local fx, fy = SnakeUtils.GetSafeSpawn(
			Snake:GetSegments(),
			Fruit,
			Rocks,
			SafeZone,
			{
				AvoidFrontOfSnake = true,
				direction = Snake:GetDirection(),
				FrontBuffer = 5,
			}
		)
		if fx then
			Rocks:spawn(fx, fy, "small")
			local col, row = Arena:GetTileFromWorld(fx, fy)
			SnakeUtils.SetOccupied(col, row, true)
		end
	end
end

local function GetAmbientLaserPreference(TraitContext, FloorData)
	if not FloorData then
		return 0
	end

	local FloorIndex = TraitContext and TraitContext.floor

	local function IsMachineThemed()
		if FloorData.backgroundTheme == "machine" then
			return true
		end

		if type(FloorData.name) == "string" and FloorData.name:lower():find("machin") then
			return true
		end

		return false
	end

	if IsMachineThemed() then
		if FloorIndex and FloorIndex <= 5 then
			return 1
		end

		return 2
	end

	return 0
end

local function GetDesiredLaserCount(TraitContext, FloorData)
	local baseline = 0

	if TraitContext then
		baseline = math.max(0, math.floor((TraitContext.laserCount or 0) + 0.5))
	end

	local ambient = GetAmbientLaserPreference(TraitContext, FloorData)

	return math.max(baseline, ambient)
end

local function BuildLaserPlan(TraitContext, HalfTiles, TrackLength, FloorData)
	local desired = GetDesiredLaserCount(TraitContext, FloorData)

	if desired <= 0 then
		return {}, 0
	end
	local plan = {}
	local attempts = 0
	local MaxAttempts = desired * 40
	local TotalCols = math.max(1, Arena.cols or 1)
	local TotalRows = math.max(1, Arena.rows or 1)

	while #plan < desired and attempts < MaxAttempts do
		attempts = attempts + 1
		local dir = (#plan % 2 == 0) and "horizontal" or "vertical"
		if love.math.random() < 0.5 then
			dir = (dir == "horizontal") and "vertical" or "horizontal"
		end

		local col, row, facing
		if dir == "horizontal" then
			facing = (love.math.random() < 0.5) and 1 or -1
			col = (facing > 0) and 1 or TotalCols
			local RowMin = 2
			local RowMax = TotalRows - 1

			if RowMax < RowMin then
				local fallback = math.floor(TotalRows / 2 + 0.5)
				RowMin = fallback
				RowMax = fallback
			end

			RowMin = math.max(1, math.min(TotalRows, RowMin))
			RowMax = math.max(RowMin, math.min(TotalRows, RowMax))
			row = love.math.random(RowMin, RowMax)
		else
			facing = (love.math.random() < 0.5) and 1 or -1
			row = (facing > 0) and 1 or TotalRows
			local ColMin = 2
			local ColMax = TotalCols - 1

			if ColMax < ColMin then
				local fallback = math.floor(TotalCols / 2 + 0.5)
				ColMin = fallback
				ColMax = fallback
			end

			ColMin = math.max(1, math.min(TotalCols, ColMin))
			ColMax = math.max(ColMin, math.min(TotalCols, ColMax))
			col = love.math.random(ColMin, ColMax)
		end

		if col and row and not SnakeUtils.IsOccupied(col, row) then
			local fx, fy = Arena:GetCenterOfTile(col, row)
			local FireDuration = 0.9 + love.math.random() * 0.6
			local FireCooldownMin = 3.5 + love.math.random() * 1.5
			local FireCooldownMax = FireCooldownMin + 2.0 + love.math.random() * 2.0
			local ChargeDuration = 0.8 + love.math.random() * 0.4
			local FireColor = {1, 0.12 + love.math.random() * 0.15, 0.15, 1}

			plan[#plan + 1] = {
				x = fx,
				y = fy,
				dir = dir,
				options = {
					facing = facing,
					FireDuration = FireDuration,
					FireCooldownMin = FireCooldownMin,
					FireCooldownMax = FireCooldownMax,
					ChargeDuration = ChargeDuration,
					FireColor = FireColor,
				},
			}

			SnakeUtils.SetOccupied(col, row, true)
		end
	end

	return plan, desired
end

local function GetDesiredDartCount(TraitContext)
	if not TraitContext then
		return 0
	end

	return math.max(0, math.floor((TraitContext.dartCount or 0) + 0.5))
end

local function BuildDartPlan(TraitContext)
	local desired = GetDesiredDartCount(TraitContext)

	if desired <= 0 then
		return {}, 0
	end

	local plan = {}
	local attempts = 0
	local MaxAttempts = desired * 40
	local TotalCols = math.max(1, Arena.cols or 1)
	local TotalRows = math.max(1, Arena.rows or 1)

	while #plan < desired and attempts < MaxAttempts do
		attempts = attempts + 1
		local dir = (love.math.random() < 0.5) and "horizontal" or "vertical"
		local facing = (love.math.random() < 0.5) and 1 or -1
		local col, row

		if dir == "horizontal" then
			col = (facing > 0) and 1 or TotalCols
			local RowMin = 2
			local RowMax = TotalRows - 1
			if RowMax < RowMin then
				local fallback = math.floor(TotalRows / 2 + 0.5)
				RowMin = fallback
				RowMax = fallback
			end
			RowMin = math.max(1, math.min(TotalRows, RowMin))
			RowMax = math.max(RowMin, math.min(TotalRows, RowMax))
			row = love.math.random(RowMin, RowMax)
		else
			row = (facing > 0) and 1 or TotalRows
			local ColMin = 2
			local ColMax = TotalCols - 1
			if ColMax < ColMin then
				local fallback = math.floor(TotalCols / 2 + 0.5)
				ColMin = fallback
				ColMax = fallback
			end
			ColMin = math.max(1, math.min(TotalCols, ColMin))
			ColMax = math.max(ColMin, math.min(TotalCols, ColMax))
			col = love.math.random(ColMin, ColMax)
		end

		if col and row and not SnakeUtils.IsOccupied(col, row) then
			local fx, fy = Arena:GetCenterOfTile(col, row)
			local telegraph = 0.7 + love.math.random() * 0.3
			local CooldownMin = 3.0 + love.math.random() * 1.4
			local CooldownMax = CooldownMin + 1.8 + love.math.random() * 1.6
			local FireSpeed = 420 + love.math.random() * 120

			plan[#plan + 1] = {
				x = fx,
				y = fy,
				dir = dir,
				options = {
					facing = facing,
					TelegraphDuration = telegraph,
					CooldownMin = CooldownMin,
					CooldownMax = CooldownMax,
					FireSpeed = FireSpeed,
				},
			}

			SnakeUtils.SetOccupied(col, row, true)
		end
	end

	return plan, desired
end

local function MergeCells(primary, secondary)
	if not primary or #primary == 0 then
		return secondary
	end

	if not secondary or #secondary == 0 then
		return primary
	end

	local merged = {}
	local seen = {}

	for _, cell in ipairs(primary) do
		AddCellUnique(merged, seen, cell[1], cell[2])
	end

	for _, cell in ipairs(secondary) do
		AddCellUnique(merged, seen, cell[1], cell[2])
	end

	return merged
end

local function BuildSpawnPlan(TraitContext, SafeZone, ReservedCells, ReservedSafeZone, RockSafeZone, SpawnBuffer, ReservedSpawnBuffer, FloorData)
	local HalfTiles = math.floor((TRACK_LENGTH / Arena.TileSize) / 2)
	local LaserPlan, DesiredLasers = BuildLaserPlan(TraitContext, HalfTiles, TRACK_LENGTH, FloorData)
	local DartPlan, DesiredDarts = BuildDartPlan(TraitContext)
	local SpawnSafeCells = MergeCells(RockSafeZone, SpawnBuffer)

	return {
		NumRocks = TraitContext.rocks,
		NumSaws = TraitContext.saws,
		HalfTiles = HalfTiles,
		BladeRadius = DEFAULT_SAW_RADIUS,
		SafeZone = SafeZone,
		ReservedCells = ReservedCells,
		ReservedSafeZone = ReservedSafeZone,
		RockSafeZone = RockSafeZone,
		SpawnBuffer = SpawnBuffer,
		ReservedSpawnBuffer = ReservedSpawnBuffer,
		SpawnSafeCells = SpawnSafeCells,
		lasers = LaserPlan,
		LaserCount = DesiredLasers,
		darts = DartPlan,
		DartCount = DesiredDarts,
	}
end

function FloorSetup.prepare(FloorNum, FloorData)
	ApplyPalette(FloorData and FloorData.palette)
	Arena:SetBackgroundEffect(FloorData and FloorData.backgroundEffect, FloorData and FloorData.palette)
	ResetFloorEntities()
	local SafeZone, ReservedCells, ReservedSafeZone, RockSafeZone, SpawnBuffer, ReservedSpawnBuffer = PrepareOccupancy()

	local TraitContext = FloorPlan.BuildBaselineFloorContext(FloorNum)
	ApplyBaselineHazardTraits(TraitContext)

	TraitContext = Upgrades:ModifyFloorContext(TraitContext)
	TraitContext.laserCount = math.max(0, TraitContext.laserCount or 0)
	TraitContext.dartCount = math.max(0, TraitContext.dartCount or 0)

	local cap = FloorPlan.GetLaserCap and FloorPlan.GetLaserCap(TraitContext.floor)
	if cap and TraitContext.laserCount ~= nil then
		TraitContext.laserCount = math.min(cap, TraitContext.laserCount)
	end

	local DartCap = FloorPlan.GetDartCap and FloorPlan.GetDartCap(TraitContext.floor)
	if DartCap and TraitContext.dartCount ~= nil then
		TraitContext.dartCount = math.min(DartCap, TraitContext.dartCount)
	end

	local SpawnPlan = BuildSpawnPlan(TraitContext, SafeZone, ReservedCells, ReservedSafeZone, RockSafeZone, SpawnBuffer, ReservedSpawnBuffer, FloorData)

	if Arena.SetSpawnDebugData then
		Arena:SetSpawnDebugData({
			SafeZone = SafeZone,
			RockSafeZone = RockSafeZone,
			SpawnBuffer = SpawnBuffer,
			SpawnSafeCells = SpawnPlan and SpawnPlan.spawnSafeCells,
			ReservedCells = ReservedCells,
			ReservedSafeZone = ReservedSafeZone,
			ReservedSpawnBuffer = ReservedSpawnBuffer,
		})
	end

	return {
		TraitContext = TraitContext,
		SpawnPlan = SpawnPlan,
	}
end

function FloorSetup.FinalizeContext(TraitContext, SpawnPlan)
	FinalizeTraitContext(TraitContext, SpawnPlan)
end

function FloorSetup.SpawnHazards(SpawnPlan)
	SpawnSaws(SpawnPlan.numSaws or 0, SpawnPlan.halfTiles, SpawnPlan.bladeRadius, SpawnPlan.spawnSafeCells)
	SpawnLasers(SpawnPlan.lasers or {})
	SpawnDarts(SpawnPlan.darts or {})
	SpawnRocks(SpawnPlan.numRocks or 0, SpawnPlan.spawnSafeCells or SpawnPlan.rockSafeZone or SpawnPlan.safeZone)
	Fruit:spawn(Snake:GetSegments(), Rocks, SpawnPlan.safeZone)
	SnakeUtils.ReleaseCells(SpawnPlan.reservedSafeZone)
	SnakeUtils.ReleaseCells(SpawnPlan.reservedSpawnBuffer)
	SnakeUtils.ReleaseCells(SpawnPlan.reservedCells)
end

return FloorSetup
