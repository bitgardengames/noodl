local Theme = require("theme")
local Arena = require("arena")
local SnakeUtils = require("snakeutils")
local Rocks = require("rocks")
local Audio = require("audio")
local Particles = require("particles")

local Darts = {}

local DARTS_ENABLED = false

local launchers = {}

function Darts:isEnabled()
	return DARTS_ENABLED
end

local DEFAULT_TELEGRAPH_DURATION = 1.15
local DEFAULT_COOLDOWN_MIN = 4.0
local DEFAULT_COOLDOWN_MAX = 5.8
local DEFAULT_FIRE_SPEED = 460
local DEFAULT_DART_LENGTH = 32
local DART_THICKNESS = 8
local HOLE_RADIUS = 10
local TELEGRAPH_PULSE_SPEED = 6.4
local IMPACT_RING_LIFE = 0.32

local function getTime()
	return love.timer.getTime()
end

local function clamp(value)
        if value < 0 then
                return 0
        elseif value > 1 then
                return 1
        end
        return value
end

local function getLauncherColors()
	local body = Theme.laserBaseColor or {0.18, 0.19, 0.24, 0.95}
	local accent = Theme.laserColor or {1, 0.32, 0.26, 1}
	return body, accent
end

local function getDartColors(accent)
	local shaft = Theme.dartShaftColor or {0.82, 0.84, 0.88, 1}
	local highlight = Theme.dartHighlightColor or {1, 1, 1, 0.65}
	local fletching = Theme.dartFletchingColor or {0.24, 0.26, 0.32, 0.95}
	local tip = Theme.dartTipColor or {accent[1], accent[2], accent[3], 1}
	return shaft, highlight, fletching, tip
end

local function getArenaLimits(dir, facing)
	local ax, ay, aw, ah = Arena:getBounds()
	local inset = (Arena.tileSize or 24) * 0.5
	local left = ax + inset
	local right = ax + aw - inset
	local top = ay + inset
	local bottom = ay + ah - inset

	if dir == "horizontal" then
		if facing >= 0 then
			return left, right - 4
		else
			return right, left + 4
		end
	else
		if facing >= 0 then
			return top, bottom - 4
		else
			return bottom, top + 4
		end
	end
end

local function getHolePosition(dir, facing, x, y)
	local tileSize = Arena.tileSize or 24
	local offset = tileSize * 0.5 + 6
	if dir == "horizontal" then
		return x - facing * offset, y
	else
		return x, y - facing * offset
	end
end

local function updateImpact(launcher, dt)
	local impact = launcher and launcher.impact
	if not impact then
		return
	end

	impact.timer = impact.timer - dt
	if impact.timer <= 0 then
		launcher.impact = nil
	end
end

local function scheduleCooldown(launcher)
	local minCooldown = launcher.cooldownMin or DEFAULT_COOLDOWN_MIN
	local maxCooldown = launcher.cooldownMax or DEFAULT_COOLDOWN_MAX
	if maxCooldown < minCooldown then
		maxCooldown = minCooldown
	end

	local roll = love.math.random()
	launcher.cooldownTimer = minCooldown + (maxCooldown - minCooldown) * roll
	launcher.state = "cooldown"
	launcher.telegraphProgress = 0
end

local function spawnImpactFX(x, y, dirX, dirY)
	local _, accent = getLauncherColors()
	local normalX = dirX or 0
	local normalY = dirY or 0

	Particles:spawnBurst(x, y, {
		count = love.math.random(4, 6),
		speed = 110,
		speedVariance = 40,
		life = 0.32,
		size = 3.2,
		color = {accent[1], accent[2], accent[3], 1},
		spread = math.pi * 0.6,
		angle = math.atan2(normalY, normalX),
		angleJitter = math.pi * 0.25,
		drag = 2.6,
		gravity = 160,
		scaleMin = 0.48,
		scaleVariance = 0.4,
		fadeTo = 0,
	})

	Particles:spawnBurst(x, y, {
		count = love.math.random(4, 6),
		speed = 60,
		speedVariance = 28,
		life = 0.38,
		size = 2.0,
		color = {1, 0.92, 0.72, 0.6},
		spread = math.pi * 2,
		angleJitter = math.pi,
		drag = 3.4,
		gravity = 0,
		scaleMin = 0.32,
		scaleVariance = 0.4,
		fadeTo = 0,
	})
end

local function triggerImpact(launcher, hitX, hitY)
	if not launcher then
		return
	end

	local projectile = launcher.projectile
	if projectile then
		launcher.impact = {
			x = hitX or projectile.tipX,
			y = hitY or projectile.tipY,
			dirX = projectile.dirX,
			dirY = projectile.dirY,
			timer = IMPACT_RING_LIFE,
			life = IMPACT_RING_LIFE,
		}
	end

	spawnImpactFX(hitX or launcher.x, hitY or launcher.y, launcher.dirX, launcher.dirY)
	Audio:playSound("shield_saw")
	launcher.projectile = nil
	scheduleCooldown(launcher)
end

local function jamLauncher(launcher, duration)
	if not (launcher and duration and duration > 0) then
		return
	end

	if launcher.state == "firing" then
		local projectile = launcher.projectile
		triggerImpact(launcher, projectile and projectile.tipX, projectile and projectile.tipY)
	end

	if launcher.state == "telegraph" then
		launcher.telegraphTimer = (launcher.telegraphTimer or 0) + duration
	elseif launcher.state == "cooldown" then
		launcher.cooldownTimer = (launcher.cooldownTimer or 0) + duration
	else
		if launcher.cooldownTimer then
			launcher.cooldownTimer = launcher.cooldownTimer + duration
		end
	end
end

local function getRockCollision(projectile, newTipX, newTipY)
	local rocks = Rocks:getAll()
	if not (rocks and #rocks > 0) then
		return nil
	end

	local bestDistance
	local hit
	local dirX, dirY = projectile.dirX, projectile.dirY
	local prevX, prevY = projectile.tipX, projectile.tipY

	for _, rock in ipairs(rocks) do
		local width = rock.w or 24
		local height = rock.h or 24
		local offsetY = rock.offsetY or 0
		local scaleX = rock.scaleX or 1
		local scaleY = rock.scaleY or 1

		local halfW = (width * scaleX) * 0.5
		local halfH = (height * scaleY) * 0.5
		local left = (rock.x or 0) - halfW
		local right = left + width * scaleX
		local top = (rock.y or 0) + offsetY - halfH
		local bottom = top + height * scaleY

		if dirX ~= 0 then
			local y = newTipY
			if y >= top and y <= bottom then
				if dirX > 0 then
					if prevX <= left and newTipX >= left then
						local distance = left - projectile.originX
						if not bestDistance or distance < bestDistance then
							bestDistance = distance
							hit = { x = left, y = y }
						end
					end
				else
					if prevX >= right and newTipX <= right then
						local distance = projectile.originX - right
						if not bestDistance or distance < bestDistance then
							bestDistance = distance
							hit = { x = right, y = y }
						end
					end
				end
			end
		else
			local x = newTipX
			if x >= left and x <= right then
				if dirY > 0 then
					if prevY <= top and newTipY >= top then
						local distance = top - projectile.originY
						if not bestDistance or distance < bestDistance then
							bestDistance = distance
							hit = { x = x, y = top }
						end
					end
				else
					if prevY >= bottom and newTipY <= bottom then
						local distance = projectile.originY - bottom
						if not bestDistance or distance < bestDistance then
							bestDistance = distance
							hit = { x = x, y = bottom }
						end
					end
				end
			end
		end
	end

	return hit
end

local function updateProjectile(launcher, dt)
	local projectile = launcher.projectile
	if not projectile then
		return
	end

	local speed = projectile.speed or DEFAULT_FIRE_SPEED
	local dirX, dirY = projectile.dirX, projectile.dirY
	local travel = speed * dt

	projectile.prevTipX = projectile.tipX
	projectile.prevTipY = projectile.tipY

	local newTipX = projectile.tipX + dirX * travel
	local newTipY = projectile.tipY + dirY * travel

	if dirX ~= 0 then
		if (dirX > 0 and newTipX > projectile.limit) or (dirX < 0 and newTipX < projectile.limit) then
			newTipX = projectile.limit
		end
	else
		if (dirY > 0 and newTipY > projectile.limit) or (dirY < 0 and newTipY < projectile.limit) then
			newTipY = projectile.limit
		end
	end

	local collision = getRockCollision(projectile, newTipX, newTipY)
	if collision then
		newTipX = collision.x
		newTipY = collision.y
	end

	projectile.tipX = newTipX
	projectile.tipY = newTipY
	projectile.baseX = newTipX - dirX * projectile.length
	projectile.baseY = newTipY - dirY * projectile.length

	if (dirX ~= 0 and newTipX == projectile.limit) or (dirY ~= 0 and newTipY == projectile.limit) or collision then
		triggerImpact(launcher, newTipX, newTipY)
	end
end

local function advanceLauncher(launcher, dt)
	if launcher.state == "cooldown" then
		launcher.cooldownTimer = (launcher.cooldownTimer or 0) - dt
		if launcher.cooldownTimer <= 0 then
			launcher.telegraphTimer = launcher.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
			launcher.state = "telegraph"
			launcher.cooldownTimer = nil
		end
	elseif launcher.state == "telegraph" then
		launcher.telegraphTimer = (launcher.telegraphTimer or 0) - dt
		local duration = launcher.telegraphDuration or DEFAULT_TELEGRAPH_DURATION
		local progress = 1 - (launcher.telegraphTimer or 0) / duration
		launcher.telegraphProgress = clamp(progress)

		if launcher.telegraphTimer <= 0 then
			launcher.projectile = {
				tipX = launcher.startX,
				tipY = launcher.startY,
				prevTipX = launcher.startX,
				prevTipY = launcher.startY,
				baseX = launcher.startX - launcher.dirX * launcher.dartLength,
				baseY = launcher.startY - launcher.dirY * launcher.dartLength,
				dirX = launcher.dirX,
				dirY = launcher.dirY,
				speed = launcher.fireSpeed or DEFAULT_FIRE_SPEED,
				length = launcher.dartLength,
				limit = launcher.travelLimit,
				originX = launcher.startX,
				originY = launcher.startY,
			}
			launcher.state = "firing"
			launcher.telegraphProgress = 1
			Audio:playSound("laser_fire")
		end
	elseif launcher.state == "firing" then
		updateProjectile(launcher, dt)
	end

	updateImpact(launcher, dt)
end

function Darts:reset()
	for _, launcher in ipairs(launchers) do
		if launcher.col and launcher.row then
			SnakeUtils.setOccupied(launcher.col, launcher.row, false)
		end
	end

	launchers = {}

	if not DARTS_ENABLED then
		return
	end
end

function Darts:spawn(x, y, dir, options)
	if not DARTS_ENABLED then
		return
	end

	dir = dir or "horizontal"
	options = options or {}

	local col, row = Arena:getTileFromWorld(x, y)
	local facing = options.facing
	if facing == nil then
		if dir == "horizontal" then
			facing = (col <= math.floor((Arena.cols or 1) / 2)) and 1 or -1
		else
			facing = (row <= math.floor((Arena.rows or 1) / 2)) and 1 or -1
		end
	end

	facing = (facing >= 0) and 1 or -1
	local dirX = (dir == "horizontal") and facing or 0
	local dirY = (dir == "vertical") and facing or 0
	local _, travelLimit = getArenaLimits(dir, facing)

	local tileSize = Arena.tileSize or 24
	local startX = x + dirX * (tileSize * 0.5 - 6)
	local startY = y + dirY * (tileSize * 0.5 - 6)

	local launcher = {
		x = x,
		y = y,
		col = col,
		row = row,
		dir = dir,
		facing = facing,
		dirX = dirX,
		dirY = dirY,
		startX = startX,
		startY = startY,
		travelLimit = travelLimit,
		telegraphDuration = options.telegraphDuration or DEFAULT_TELEGRAPH_DURATION,
		fireSpeed = options.fireSpeed or DEFAULT_FIRE_SPEED,
		dartLength = options.dartLength or DEFAULT_DART_LENGTH,
		cooldownMin = options.cooldownMin or DEFAULT_COOLDOWN_MIN,
		cooldownMax = options.cooldownMax or DEFAULT_COOLDOWN_MAX,
		state = "cooldown",
		telegraphProgress = 0,
		randomOffset = love.math.random() * math.pi * 2,
	}

	launcher.travelLimit = travelLimit

	launcher.holeX, launcher.holeY = getHolePosition(dir, facing, x, y)

	SnakeUtils.setOccupied(col, row, true)
	scheduleCooldown(launcher)

	launchers[#launchers + 1] = launcher
	return launcher
end

function Darts:update(dt)
	if not DARTS_ENABLED then
		return
	end

	if dt <= 0 then
		return
	end

	for _, launcher in ipairs(launchers) do
		advanceLauncher(launcher, dt)
	end
end

local function drawTelegraph(launcher, bodyColor, accentColor)
	local progress = launcher.telegraphProgress or 0
	if progress <= 0 then
		return
	end

	local pulse = 0.35 + 0.25 * math.sin((getTime() + launcher.randomOffset) * TELEGRAPH_PULSE_SPEED)
	local glowAlpha = clamp(progress * 0.9 + pulse * 0.35)

	love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], glowAlpha)

	local tipAdvance = 12
	local shaftLength = 18
	local shaftThickness = DART_THICKNESS * 0.6

	if launcher.dir == "horizontal" then
		local dir = launcher.dirX >= 0 and 1 or -1
		local tipX = launcher.startX - dir * (1 - progress) * tipAdvance
		local baseX = tipX - dir * shaftLength
		local shaftX = math.min(baseX, tipX)
		local shaftW = math.abs(tipX - baseX)

		love.graphics.rectangle("fill", shaftX, launcher.y - shaftThickness * 0.5, shaftW, shaftThickness)

		love.graphics.polygon("fill",
			tipX, launcher.y,
			tipX - dir * 8, launcher.y - DART_THICKNESS * 0.8,
			tipX - dir * 8, launcher.y + DART_THICKNESS * 0.8
		)
	else
		local dir = launcher.dirY >= 0 and 1 or -1
		local tipY = launcher.startY - dir * (1 - progress) * tipAdvance
		local baseY = tipY - dir * shaftLength
		local shaftY = math.min(baseY, tipY)
		local shaftH = math.abs(tipY - baseY)

		love.graphics.rectangle("fill", launcher.x - shaftThickness * 0.5, shaftY, shaftThickness, shaftH)

		love.graphics.polygon("fill",
			launcher.x, tipY,
			launcher.x - DART_THICKNESS * 0.8, tipY - dir * 8,
			launcher.x + DART_THICKNESS * 0.8, tipY - dir * 8
		)
	end

	love.graphics.setColor(1, 1, 1, glowAlpha * 0.5)
	love.graphics.circle("line", launcher.holeX, launcher.holeY, HOLE_RADIUS * clamp(progress * 0.75))
	love.graphics.setColor(1, 1, 1, glowAlpha * 0.35)
	love.graphics.circle("fill", launcher.holeX, launcher.holeY, HOLE_RADIUS * clamp(progress * 0.4))
end

local function drawProjectile(launcher, accentColor)
	local projectile = launcher.projectile
	if not projectile then
		return
	end

	local dirX, dirY = projectile.dirX, projectile.dirY
	local shaftColor, highlightColor, fletchingColor, tipColor = getDartColors(accentColor)
	local shaftThickness = DART_THICKNESS * 0.75
	local tipLength = 12
	local fletchingSize = 6

	if dirX ~= 0 then
		local dir = dirX >= 0 and 1 or -1
		local baseX = projectile.baseX
		local tipX = projectile.tipX
		local shaftEndX = tipX - dir * tipLength
		if dir > 0 then
			shaftEndX = math.max(shaftEndX, baseX)
		else
			shaftEndX = math.min(shaftEndX, baseX)
		end

		local shaftX = math.min(baseX, shaftEndX)
		local shaftW = math.abs(shaftEndX - baseX)

		love.graphics.setColor(shaftColor)
		if shaftW > 0 then
			love.graphics.rectangle("fill", shaftX, projectile.tipY - shaftThickness * 0.5, shaftW, shaftThickness)

			love.graphics.setColor(highlightColor)
			love.graphics.rectangle("fill", shaftX, projectile.tipY - shaftThickness * 0.5, shaftW, shaftThickness * 0.35)
		end

		love.graphics.setColor(fletchingColor)
		local fletchX = baseX - dir * 2
		love.graphics.polygon("fill",
			fletchX, projectile.tipY,
			fletchX - dir * fletchingSize, projectile.tipY - DART_THICKNESS * 0.9,
			fletchX - dir * fletchingSize, projectile.tipY + DART_THICKNESS * 0.9
		)

		love.graphics.setColor(tipColor)
		love.graphics.polygon("fill",
			tipX + dir * 2, projectile.tipY,
			tipX - dir * tipLength, projectile.tipY - DART_THICKNESS,
			tipX - dir * tipLength, projectile.tipY + DART_THICKNESS
		)
	else
		local top = math.min(projectile.baseY, projectile.tipY)
		local height = math.abs(projectile.tipY - projectile.baseY)
		local dir = dirY >= 0 and 1 or -1
		local baseY = projectile.baseY
		local tipY = projectile.tipY
		local shaftEndY = tipY - dir * tipLength
		if dir > 0 then
			shaftEndY = math.max(shaftEndY, baseY)
		else
			shaftEndY = math.min(shaftEndY, baseY)
		end

		local shaftY = math.min(baseY, shaftEndY)
		local shaftH = math.abs(shaftEndY - baseY)

		love.graphics.setColor(shaftColor)
		if shaftH > 0 then
			love.graphics.rectangle("fill", projectile.tipX - shaftThickness * 0.5, shaftY, shaftThickness, shaftH)

			love.graphics.setColor(highlightColor)
			love.graphics.rectangle("fill", projectile.tipX - shaftThickness * 0.5, shaftY, shaftThickness * 0.35, shaftH)
		end

		love.graphics.setColor(fletchingColor)
		local fletchY = baseY - dir * 2
		love.graphics.polygon("fill",
			projectile.tipX, fletchY,
			projectile.tipX - DART_THICKNESS * 0.9, fletchY - dir * fletchingSize,
			projectile.tipX + DART_THICKNESS * 0.9, fletchY - dir * fletchingSize
		)

		love.graphics.setColor(tipColor)
		love.graphics.polygon("fill",
			projectile.tipX, tipY + dir * 2,
			projectile.tipX - DART_THICKNESS, tipY - dir * tipLength,
			projectile.tipX + DART_THICKNESS, tipY - dir * tipLength
		)
	end
end

local function drawHole(launcher, bodyColor)
	love.graphics.setColor(bodyColor)
	love.graphics.circle("fill", launcher.holeX, launcher.holeY, HOLE_RADIUS)

	love.graphics.setColor(1, 1, 1, 0.15)
	love.graphics.circle("fill", launcher.holeX - launcher.dirX * 2, launcher.holeY - launcher.dirY * 2, HOLE_RADIUS * 0.6)

	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.setLineWidth(3)
	love.graphics.circle("line", launcher.holeX, launcher.holeY, HOLE_RADIUS)
	love.graphics.setLineWidth(1)
end

local function drawImpact(launcher, accentColor)
	local impact = launcher.impact
	if not impact then
		return
	end

	local progress = clamp(impact.timer / (impact.life or IMPACT_RING_LIFE))
	local radius = 6 + (1 - progress) * 12
	love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], progress * 0.6)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", impact.x, impact.y, radius)
	love.graphics.setLineWidth(1)
end

function Darts:draw()
	if not DARTS_ENABLED then
		return
	end

	local bodyColor, accentColor = getLauncherColors()

	for _, launcher in ipairs(launchers) do
		drawHole(launcher, bodyColor)
		drawTelegraph(launcher, bodyColor, accentColor)
		drawProjectile(launcher, accentColor)
		drawImpact(launcher, accentColor)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

local function overlapsProjectile(launcher, x, y, w, h)
	local projectile = launcher.projectile
	if not projectile then
		return false
	end

	local margin = DART_THICKNESS * 0.5
	if projectile.dirX ~= 0 then
		local prevBase = projectile.prevTipX - projectile.dirX * projectile.length
		local left = math.min(projectile.baseX, projectile.tipX, projectile.prevTipX, prevBase) - margin
		local right = math.max(projectile.baseX, projectile.tipX, projectile.prevTipX, prevBase) + margin
		local top = projectile.tipY - margin
		local bottom = projectile.tipY + margin

		return x < right and x + w > left and y < bottom and y + h > top
	else
		local prevBase = projectile.prevTipY - projectile.dirY * projectile.length
		local top = math.min(projectile.baseY, projectile.tipY, projectile.prevTipY, prevBase) - margin
		local bottom = math.max(projectile.baseY, projectile.tipY, projectile.prevTipY, prevBase) + margin
		local left = projectile.tipX - margin
		local right = projectile.tipX + margin

		return x < right and x + w > left and y < bottom and y + h > top
	end
end

function Darts:checkCollision(x, y, w, h)
	if not DARTS_ENABLED then
		return nil
	end

	for _, launcher in ipairs(launchers) do
		if launcher.state == "firing" and overlapsProjectile(launcher, x, y, w, h) then
			return {
				launcher = launcher,
				dirX = launcher.dirX,
				dirY = launcher.dirY,
				x = launcher.projectile and launcher.projectile.tipX,
				y = launcher.projectile and launcher.projectile.tipY,
			}
		end
	end

	return nil
end

function Darts:onShieldedHit(hit, hitX, hitY)
	if not DARTS_ENABLED then
		return
	end

	if not hit then
		return
	end

	local launcher = hit.launcher
	if not launcher then
		return
	end

	triggerImpact(launcher, hitX or hit.x, hitY or hit.y)
end

function Darts:addGlobalJam(duration)
	if not duration or duration <= 0 then
		return
	end

	for _, launcher in ipairs(launchers) do
		jamLauncher(launcher, duration)
	end
end

return Darts
