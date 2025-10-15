local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Particles = require("particles")
local Theme = require("theme")

local Saws = {}
local current = {}
local slots = {}
local NextSlotId = 0

local SAW_RADIUS = 24
local COLLISION_RADIUS_MULT = 0.7 -- keep the visual size but ease up on collision tightness
local SAW_TEETH = 12
local HUB_HOLE_RADIUS = 4
local HUB_HIGHLIGHT_PADDING = 3
local TRACK_LENGTH = 120 -- how far the saw moves on its track
local MOVE_SPEED = 60    -- units per second along the track
local SPAWN_DURATION = 0.3
local SQUASH_DURATION = 0.15
local SINK_OFFSET = 2
local SINK_DISTANCE = 28
local SINK_SPEED = 3
local HIT_FLASH_DURATION = 0.18
local HIT_FLASH_COLOR = {0.95, 0.08, 0.12, 1}

local function CopyColor(color)
	if not color then
		return { 1, 1, 1, 1 }
	end

	return {
		color[1] or 1,
		color[2] or 1,
		color[3] or 1,
		color[4] == nil and 1 or color[4],
	}
end

local function GetHighlightColor(color)
	color = color or {1, 1, 1, 1}
	local r = math.min(1, color[1] * 1.2 + 0.08)
	local g = math.min(1, color[2] * 1.2 + 0.08)
	local b = math.min(1, color[3] * 1.2 + 0.08)
	local a = (color[4] or 1) * 0.7
	return {r, g, b, a}
end

-- modifiers
Saws.SpeedMult = 1.0
Saws.SpinMult = 1.0
Saws.StallOnFruit = 0

local StallTimer = 0
local SinkTimer = 0
local SinkAutoRaise = false
local SinkActive = false

local function GetTileSize()
	return Arena and Arena.TileSize or SnakeUtils.SEGMENT_SIZE or 24
end

local function ClampRow(row)
	if not Arena or (Arena.rows or 0) <= 0 then
		return row
	end

	return math.max(1, math.min(Arena.rows, row))
end

local function ClampCol(col)
	if not Arena or (Arena.cols or 0) <= 0 then
		return col
	end

	return math.max(1, math.min(Arena.cols, col))
end

local function AddCell(target, seen, col, row)
	if not (col and row) then
		return
	end

	col = ClampCol(col)
	row = ClampRow(row)

	local key = tostring(col) .. ":" .. tostring(row)
	if seen[key] then
		return
	end

	seen[key] = true
	target[#target + 1] = { col, row }
end

local function BuildCollisionCellsForSaw(saw)
	if not saw then
		return nil
	end

	local TrackCells = SnakeUtils.GetSawTrackCells(saw.x, saw.y, saw.dir) or {}
	if #TrackCells == 0 then
		return nil
	end

	local cells = {}
	local seen = {}

	-- Limit collision coverage to the track cell and the adjacent cell the blade
	-- actually occupies so the hazard doesn't spill into neighboring tiles.
	if saw.dir == "horizontal" then
		for _, cell in ipairs(TrackCells) do
			local col, row = cell[1], cell[2]
			AddCell(cells, seen, col, row)
			AddCell(cells, seen, col, row + 1)
		end
	else
		local OffsetDir = (saw.side == "left") and -1 or 1

		for _, cell in ipairs(TrackCells) do
			local col, row = cell[1], cell[2]
			AddCell(cells, seen, col, row)
			AddCell(cells, seen, col + OffsetDir, row)
		end
	end

	return cells
end

local function OverlapsCollisionCell(saw, x, y, w, h)
	local cells = saw and saw.collisionCells
	if not (cells and #cells > 0) then
		return true
	end

	if not (Arena and Arena.GetTilePosition) then
		return true
	end

	local TileSize = GetTileSize()

	for _, cell in ipairs(cells) do
		local col, row = cell[1], cell[2]
		local CellX, CellY = Arena:GetTilePosition(col, row)
		if x < CellX + TileSize and x + w > CellX and y < CellY + TileSize and y + h > CellY then
			return true
		end
	end

	return false
end

local function IsCollisionCandidate(saw, x, y, w, h)
	if not (saw and x and y and w and h) then
		return false
	end

	if (saw.sinkProgress or 0) > 0 or (saw.sinkTarget or 0) > 0 then
		return false
	end

	return OverlapsCollisionCell(saw, x, y, w, h)
end

local function GetMoveSpeed()
	return MOVE_SPEED * (Saws.SpeedMult or 1)
end

local function GetOrCreateSlot(x, y, dir)
	dir = dir or "horizontal"

	for _, slot in ipairs(slots) do
		if slot.x == x and slot.y == y and slot.dir == dir then
			return slot
		end
	end

	NextSlotId = NextSlotId + 1
	local slot = {
		id = NextSlotId,
		x = x,
		y = y,
		dir = dir,
	}

	table.insert(slots, slot)
	return slot
end

local function GetSawCenter(saw)
	if not saw then
		return nil, nil
	end

	if saw.dir == "horizontal" then
		local MinX = saw.x - TRACK_LENGTH/2 + saw.radius
		local MaxX = saw.x + TRACK_LENGTH/2 - saw.radius
		local px = MinX + (MaxX - MinX) * saw.progress
		return px, saw.y
	end

	local MinY = saw.y - TRACK_LENGTH/2 + saw.radius
	local MaxY = saw.y + TRACK_LENGTH/2 - saw.radius
	local py = MinY + (MaxY - MinY) * saw.progress

	-- Vertical saws should sit centered in their track just like horizontal ones.
	-- Previously the hub was offset vertically, which made the blade appear to
	-- jut too far into the arena. Keep the center aligned with the track so both
	-- orientations look consistent.
	return saw.x, py
end

local function GetSawCollisionCenter(saw)
	local px, py = GetSawCenter(saw)
	if not (px and py) then
		return px, py
	end

	local SinkOffset = SINK_OFFSET + (saw.sinkProgress or 0) * SINK_DISTANCE
	if saw.dir == "horizontal" then
		py = py + SinkOffset
	else
		local SinkDir = (saw.side == "left") and -1 or 1
		px = px + SinkDir * SinkOffset
	end

	return px, py
end

local function RemoveSaw(target)
	if not target then
		return
	end

	for index, saw in ipairs(current) do
		if saw == target or index == target then
			local px, py = GetSawCenter(saw)
			local SawColor = Theme.SawColor or {0.85, 0.8, 0.75, 1}
			local primary = CopyColor(SawColor)
			primary[4] = 1
			local highlight = GetHighlightColor(SawColor)

                        Particles:SpawnBurst(px or saw.x, py or saw.y, {
                                count = 12,
                                speed = 82,
                                SpeedVariance = 68,
                                life = 0.35,
                                size = 2.3,
                                color = {primary[1], primary[2], primary[3], primary[4]},
                                spread = math.pi * 2,
                                AngleJitter = math.pi,
                                drag = 3.5,
                                gravity = 260,
                                ScaleMin = 0.45,
                                ScaleVariance = 0.5,
                                FadeTo = 0.04,
                        })

                        Particles:SpawnBurst(px or saw.x, py or saw.y, {
                                count = love.math.random(4, 6),
                                speed = 132,
                                SpeedVariance = 72,
                                life = 0.26,
                                size = 1.8,
                                color = {1.0, 0.94, 0.52, highlight[4] or 1},
                                spread = math.pi * 2,
                                AngleJitter = math.pi,
                                drag = 1.4,
                                gravity = 200,
                                ScaleMin = 0.34,
                                ScaleVariance = 0.28,
                                FadeTo = 0.02,
                        })

			table.remove(current, index)
			break
		end
	end
end

-- Easing similar to Rocks
-- Spawn a saw on a track
function Saws:spawn(x, y, radius, teeth, dir, side)
	local slot = GetOrCreateSlot(x, y, dir)

	table.insert(current, {
		x = x,
		y = y,
		radius = radius or SAW_RADIUS,
		CollisionRadius = (radius or SAW_RADIUS) * COLLISION_RADIUS_MULT,
		teeth = teeth or SAW_TEETH,
		rotation = 0,
		timer = 0,
		phase = "drop",
		ScaleX = 1,
		ScaleY = 0,
		OffsetY = -40,

		-- movement
		dir = dir or "horizontal",
		side = side,
		progress = 0,
		direction = 1,
		SlotId = slot and slot.id or nil,

		SinkProgress = SinkActive and 1 or 0,
		SinkTarget = SinkActive and 1 or 0,
		CollisionCells = nil,
		HitFlashTimer = 0,
	})

	local saw = current[#current]
	saw.collisionCells = BuildCollisionCellsForSaw(saw)
end

function Saws:GetAll()
	return current
end

function Saws:GetCollisionCenter(saw)
	return GetSawCollisionCenter(saw)
end

function Saws:reset()
	current = {}
	slots = {}
	NextSlotId = 0
	self.SpeedMult = 1.0
	self.SpinMult = 1.0
	self.StallOnFruit = 0
	StallTimer = 0
	SinkTimer = 0
	SinkAutoRaise = false
	SinkActive = false
end

function Saws:destroy(target)
	RemoveSaw(target)
end

function Saws:update(dt)
	if StallTimer > 0 then
		StallTimer = math.max(0, StallTimer - dt)
	end

	if SinkAutoRaise and SinkTimer > 0 then
		SinkTimer = math.max(0, SinkTimer - dt)
		if SinkTimer <= 0 then
			self:unsink()
		end
	end

	for _, saw in ipairs(current) do
		if not saw.collisionCells then
			saw.collisionCells = BuildCollisionCellsForSaw(saw)
		end

		saw.collisionRadius = (saw.radius or SAW_RADIUS) * COLLISION_RADIUS_MULT

		saw.timer = saw.timer + dt
		saw.rotation = (saw.rotation + dt * 5 * (self.SpinMult or 1)) % (math.pi * 2)

		local SinkDirection = (saw.sinkTarget or 0) > 0 and 1 or -1
		saw.sinkProgress = saw.sinkProgress + SinkDirection * dt * SINK_SPEED
		if saw.sinkProgress < 0 then
			saw.sinkProgress = 0
		elseif saw.sinkProgress > 1 then
			saw.sinkProgress = 1
		end

		saw.hitFlashTimer = math.max(0, (saw.hitFlashTimer or 0) - dt)

		if saw.phase == "drop" then
			local progress = math.min(saw.timer / SPAWN_DURATION, 1)
			saw.offsetY = -40 * (1 - progress)
			saw.scaleY = progress
			saw.scaleX = progress

                        if progress >= 1 then
                                saw.phase = "squash"
                                saw.timer = 0
                        end

		elseif saw.phase == "squash" then
			local progress = math.min(saw.timer / SQUASH_DURATION, 1)
			saw.scaleX = 1 + 0.3 * (1 - progress)
			saw.scaleY = 1 - 0.3 * (1 - progress)
			saw.offsetY = 0

			if progress >= 1 then
				saw.phase = "done"
				saw.scaleX = 1
				saw.scaleY = 1
				saw.offsetY = 0
			end
		elseif saw.phase == "done" then
			if StallTimer <= 0 then
				-- Move along the track
				local delta = (GetMoveSpeed() * dt) / TRACK_LENGTH
				saw.progress = saw.progress + delta * saw.direction

				if saw.progress > 1 then
					saw.progress = 1
					saw.direction = -1
				elseif saw.progress < 0 then
					saw.progress = 0
					saw.direction = 1
				end
			end
		end
	end
end

function Saws:draw()
	if #slots > 0 then
		love.graphics.setColor(0, 0, 0, 1)
		for _, slot in ipairs(slots) do
			if slot.dir == "horizontal" then
				love.graphics.rectangle("fill", slot.x - TRACK_LENGTH/2, slot.y - 5, TRACK_LENGTH, 10, 6, 6)
			else
				love.graphics.rectangle("fill", slot.x - 5, slot.y - TRACK_LENGTH/2, 10, TRACK_LENGTH, 6, 6)
			end
		end
	end

	for _, saw in ipairs(current) do
		local px, py = GetSawCenter(saw)

		-- Stencil: clip saw into the track (adjust direction for left/right mounted saws)
		love.graphics.stencil(function()
			if saw.dir == "horizontal" then
				love.graphics.rectangle("fill",
					saw.x - TRACK_LENGTH/2 - saw.radius,
					saw.y - 999 + SINK_OFFSET,
					TRACK_LENGTH + saw.radius * 2,
					999)
			else
				-- For vertical saws, choose stencil side based on saw.side
				local height = TRACK_LENGTH + saw.radius * 2
				local top = saw.y - TRACK_LENGTH/2 - saw.radius
				if saw.side == "left" then
					-- allow rightwards area (blade peeking into arena)
					love.graphics.rectangle("fill",
						saw.x,
						top,
						999,
						height)
				elseif saw.side == "right" then
					-- allow leftwards area (default)
					love.graphics.rectangle("fill",
						saw.x - 999,
						top,
						999,
						height)
				else
					-- centered/default: cover left side as before (keeps backward compatibility)
					love.graphics.rectangle("fill",
						saw.x - 999,
						top,
						999,
						height)
				end
			end
		end, "replace", 1)

		love.graphics.setStencilTest("equal", 1)

		-- Saw blade
		love.graphics.push()
		local SinkOffset = (saw.sinkProgress or 0) * SINK_DISTANCE
		local OffsetX, OffsetY = 0, 0

		if saw.dir == "horizontal" then
			OffsetY = SINK_OFFSET + SinkOffset
		else
			local SinkDir = (saw.side == "left") and -1 or 1
			OffsetX = SinkDir * (SINK_OFFSET + SinkOffset)
		end

		love.graphics.translate((px or saw.x) + OffsetX, (py or saw.y) + OffsetY)

		-- apply spinning rotation
		love.graphics.rotate(saw.rotation)

		local SinkScale = 1 - 0.1 * (saw.sinkProgress or 0)
		love.graphics.scale(SinkScale, SinkScale)

		local points = {}
		local teeth = saw.teeth or 8
		local outer = saw.radius
		local inner = saw.radius * 0.8
		local step = math.pi / teeth

		for i = 0, (teeth * 2) - 1 do
			local r = (i % 2 == 0) and outer or inner
			local angle = i * step
			table.insert(points, math.cos(angle) * r)
			table.insert(points, math.sin(angle) * r)
		end

		-- Fill
		local BaseColor = Theme.SawColor or {0.8, 0.8, 0.8, 1}
		if saw.hitFlashTimer and saw.hitFlashTimer > 0 then
			BaseColor = HIT_FLASH_COLOR
		end

		love.graphics.setColor(BaseColor)
		love.graphics.polygon("fill", points)

		-- Determine whether the hub highlight should be visible. When the saw
		-- is mounted in a wall (vertical with an explicit side) the hub sits
		-- mostly inside the track. If the track clips through the hub we end
		-- up with a stray grey arc poking out of the blade edge. Skip drawing
		-- the highlight (and hub hole) in that situation.
		local HighlightRadius = HUB_HOLE_RADIUS + HUB_HIGHLIGHT_PADDING - 1
		local HideHubHighlight = false
		local OcclusionDepth = SINK_OFFSET + SinkOffset

		if saw.dir == "vertical" and (saw.side == "left" or saw.side == "right") then
			if OcclusionDepth < HighlightRadius then
				HideHubHighlight = true
			end
		elseif OcclusionDepth > HighlightRadius then
			HideHubHighlight = true
		end

		if not HideHubHighlight then
			local highlight = GetHighlightColor(BaseColor)
			love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", 0, 0, HighlightRadius)
		end

		-- Outline
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.setLineWidth(3)
		love.graphics.polygon("line", points)

		if not HideHubHighlight then
			-- Hub hole
			love.graphics.circle("fill", 0, 0, HUB_HOLE_RADIUS)
		end

		love.graphics.pop()

		-- Reset stencil
		love.graphics.setStencilTest()

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(1)
	end
end

function Saws:stall(duration, options)
	if not duration or duration <= 0 then
		return
	end

	StallTimer = (StallTimer or 0) + duration

	local Upgrades = package.loaded["upgrades"]
	if Upgrades and Upgrades.notify then
		local event = {
			duration = duration,
			total = StallTimer,
			cause = options and options.cause or nil,
			source = options and options.source or nil,
		}

                local positions = {}
                local SawDetails = {}
                local limit = (options and options.positionLimit) or 4

                for _, saw in ipairs(current) do
                        if saw then
                                local cx, cy = GetSawCenter(saw)
                                if cx and cy then
                                        positions[#positions + 1] = { cx, cy }
                                        SawDetails[#SawDetails + 1] = {
                                                x = cx,
                                                y = cy,
                                                dir = saw.dir,
                                                side = saw.side,
                                        }

                                        if limit and limit > 0 and #positions >= limit then
                                                break
                                        end
                                end
                        end
                end

                if #positions > 0 then
                        event.positions = positions
                        event.positionCount = #positions
                end

                if #SawDetails > 0 then
                        event.saws = SawDetails
                        event.sawCount = #SawDetails
                end

		Upgrades:notify("SawsStalled", event)
	end
end

function Saws:sink(duration)
	for _, saw in ipairs(self:GetAll()) do
		saw.sinkTarget = 1
	end

	SinkActive = true

	if duration and duration > 0 then
		SinkTimer = math.max(SinkTimer, duration)
		SinkAutoRaise = true
	else
		SinkTimer = 0
		SinkAutoRaise = false
	end
end

function Saws:unsink()
	for _, saw in ipairs(self:GetAll()) do
		saw.sinkTarget = 0
	end

	SinkTimer = 0
	SinkAutoRaise = false
	SinkActive = false
end

function Saws:SetStallOnFruit(duration)
	self.StallOnFruit = duration or 0
end

function Saws:GetStallOnFruit()
	return self.StallOnFruit or 0
end

function Saws:OnFruitCollected()
	local duration = self:GetStallOnFruit()
	if duration > 0 then
		self:stall(duration, { cause = "fruit" })
	end
end

function Saws:IsCollisionCandidate(saw, x, y, w, h)
	return IsCollisionCandidate(saw, x, y, w, h)
end

function Saws:CheckCollision(x, y, w, h)
	for _, saw in ipairs(self:GetAll()) do
		if IsCollisionCandidate(saw, x, y, w, h) then
			local px, py = GetSawCollisionCenter(saw)

			-- Circle vs AABB
			local ClosestX = math.max(x, math.min(px, x + w))
			local ClosestY = math.max(y, math.min(py, y + h))
			local dx = px - ClosestX
			local dy = py - ClosestY
			local CollisionRadius = saw.collisionRadius or saw.radius
			if dx * dx + dy * dy < CollisionRadius * CollisionRadius then
				saw.hitFlashTimer = math.max(saw.hitFlashTimer or 0, HIT_FLASH_DURATION)
				return saw
			end
		end
	end
	return nil
end

return Saws
