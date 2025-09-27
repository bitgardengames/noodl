local Face = require("face")
local Theme = require("theme")

local unpack = unpack

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 6
local FRUIT_BULGE_SCALE = 1.25

-- colors (body color reused for patches so they blend)
local BODY_R, BODY_G, BODY_B = Theme.snakeDefault

-- Canvas for single-pass shadow
local snakeCanvas = nil

-- helper: prefer drawX/drawY, fallback to x/y
local function ptXY(p)
  if not p then return nil, nil end
  return (p.drawX or p.x), (p.drawY or p.y)
end

-- polyline coords {x1,y1,x2,y2,...}
local function buildCoords(trail)
  local coords = {}
  local lastx, lasty
  for i = 1, #trail do
    local x, y = ptXY(trail[i])
    if x and y then
      if not (lastx and lasty and x == lastx and y == lasty) then
        coords[#coords+1] = x
        coords[#coords+1] = y
        lastx, lasty = x, y
      end
    end
  end
  return coords
end

local function drawPolyline(coords)
  if #coords >= 4 then
    love.graphics.line(unpack(coords))
  end
end

local function drawEndcaps(head, tail, radius)
  local hx, hy = ptXY(head)
  local tx, ty = ptXY(tail)
  if hx and hy then love.graphics.circle("fill", hx, hy, radius) end
  if tx and ty then love.graphics.circle("fill", tx, ty, radius) end
end

-- draw a body-colored "plug" circle at each corner
local function drawCornerPlugs(trail, radius)
  for i = 2, #trail-1 do
    local x0,y0 = ptXY(trail[i-1])
    local x1,y1 = ptXY(trail[i])
    local x2,y2 = ptXY(trail[i+1])
    if x0 and y0 and x1 and y1 and x2 and y2 then
      -- Only bother if it's actually a turn (angle change > tiny threshold)
      local ux,uy = x1-x0, y1-y0
      local vx,vy = x2-x1, y2-y1
      local ul = math.sqrt(ux*ux + uy*uy)
      local vl = math.sqrt(vx*vx + vy*vy)
      if ul > 1e-3 and vl > 1e-3 then
        local dot = (ux*vx + uy*vy) / (ul*vl)
        if dot < 0.999 then -- not perfectly straight
          love.graphics.circle("fill", x1, y1, radius)
        end
      end
    end
  end
end


local function drawFruitBulges(trail, head, radius)
  if not trail or radius <= 0 then return end

  for i = 1, #trail do
    local seg = trail[i]
    if seg and seg.fruitMarker and seg ~= head then
      local x, y = ptXY(seg)
      if x and y then
        love.graphics.circle("fill", x, y, radius)
      end
    end
  end
end

local function renderSnakeToCanvas(trail, coords, head, tail, half, thickness)
        -- OUTLINE
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(thickness + OUTLINE_SIZE)
        drawPolyline(coords)
        drawEndcaps(head, tail, half + OUTLINE_SIZE * 0.5)
        drawCornerPlugs(trail, half + OUTLINE_SIZE*0.5)
        local bulgeRadius = half * FRUIT_BULGE_SCALE
        drawFruitBulges(trail, head, bulgeRadius + OUTLINE_SIZE * 0.5)

        -- BODY
        love.graphics.setColor(BODY_R, BODY_G, BODY_B)
        love.graphics.setLineWidth(thickness)
        drawPolyline(coords)
        drawEndcaps(head, tail, half)

        love.graphics.setColor(BODY_R, BODY_G, BODY_B)
        drawCornerPlugs(trail, half)
        drawFruitBulges(trail, head, bulgeRadius)
end

local function drawSoftGlow(x, y, radius, r, g, b, a)
  if radius <= 0 then return end

  love.graphics.push("all")
  love.graphics.setBlendMode("add")

  local layers = 4
  for i = 1, layers do
    local t = (i - 1) / (layers - 1)
    local fade = (1 - t)
    love.graphics.setColor(r, g, b, (a or 1) * fade * fade)
    love.graphics.circle("fill", x, y, radius * (0.55 + 0.35 * t))
  end

  love.graphics.pop()
end

local function drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)
  local hasShield = shieldCount and shieldCount > 0
  if not hasShield and not (shieldFlashTimer and shieldFlashTimer > 0) then
    return
  end

  local baseRadius = SEGMENT_SIZE * (0.95 + 0.06 * math.max(0, (shieldCount or 1) - 1))
  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local pulse = 1 + 0.08 * math.sin(time * 6)
  local alpha = 0.35 + 0.1 * math.sin(time * 5)

  if shieldFlashTimer and shieldFlashTimer > 0 then
    local flash = math.min(1, shieldFlashTimer / 0.3)
    pulse = pulse + flash * 0.25
    alpha = alpha + flash * 0.4
  end

  drawSoftGlow(hx, hy, baseRadius * (1.2 + 0.1 * pulse), 0.35, 0.8, 1, alpha * 0.8)

  love.graphics.setLineWidth(4)
  local lineAlpha = alpha + (hasShield and 0.25 or 0.45)
  love.graphics.setColor(0.45, 0.85, 1, lineAlpha)
  love.graphics.circle("line", hx, hy, baseRadius * pulse)

  love.graphics.setColor(0.45, 0.85, 1, (alpha + 0.15) * 0.5)
  love.graphics.circle("fill", hx, hy, baseRadius * 0.8 * pulse)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

local function drawStonebreakerAura(hx, hy, SEGMENT_SIZE, data)
  if not data then return end
  local stacks = data.stacks or 0
  if stacks <= 0 then return end

  local progress = data.progress or 0
  local rate = data.rate or 0
  if rate >= 1 then
    progress = 1
  else
    if progress < 0 then progress = 0 end
    if progress > 1 then progress = 1 end
  end

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local baseRadius = SEGMENT_SIZE * (1.05 + 0.04 * math.min(stacks, 3))
  local baseAlpha = 0.18 + 0.08 * math.min(stacks, 3)

  drawSoftGlow(hx, hy, baseRadius * 1.25, 0.95, 0.86, 0.6, baseAlpha * 1.2)

  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.52, 0.46, 0.4, baseAlpha)
  love.graphics.circle("line", hx, hy, baseRadius)

  if progress > 0 then
    local startAngle = -math.pi / 2
    love.graphics.setColor(0.88, 0.74, 0.46, 0.35 + 0.25 * progress)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", hx, hy, baseRadius * 1.08, startAngle, startAngle + progress * math.pi * 2)
  end

  local shards = math.max(4, 3 + math.min(stacks * 2, 6))
  local ready = (rate >= 1) or (progress >= 0.99)
  for i = 1, shards do
    local angle = time * (0.8 + stacks * 0.2) + (i / shards) * math.pi * 2
    local wobble = 0.08 * math.sin(time * 3 + i)
    local radius = baseRadius * (1.05 + wobble)
    local size = SEGMENT_SIZE * (0.08 + 0.02 * math.min(stacks, 3))
    local alpha = 0.25 + 0.35 * progress
    if ready then
      alpha = alpha + 0.2
    end
    love.graphics.setColor(0.95, 0.86, 0.6, alpha)
    love.graphics.circle("fill", hx + math.cos(angle) * radius, hy + math.sin(angle) * radius, size)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

local function drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, data)
  if not data or not data.active then return end

  local duration = data.duration or 0
  if duration <= 0 then duration = 1 end
  local timer = data.timer or 0
  if timer < 0 then timer = 0 end
  local intensity = math.min(1, timer / duration)

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local pulse = 0.9 + 0.1 * math.sin(time * 6)
  local radius = SEGMENT_SIZE * (0.6 + 0.35 * intensity) * pulse

  drawSoftGlow(hx, hy, radius * 1.4, 1, 0.68 + 0.2 * intensity, 0.25, 0.4 + 0.5 * intensity)

  love.graphics.setColor(1, 0.6 + 0.25 * intensity, 0.2, 0.35 + 0.4 * intensity)
  love.graphics.circle("fill", hx, hy, radius)

  love.graphics.setColor(1, 0.52 + 0.3 * intensity, 0.18, 0.2 + 0.25 * intensity)
  love.graphics.circle("line", hx, hy, radius * 1.1)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
end

local function drawSnake(trail, segmentCount, SEGMENT_SIZE, popTimer, getHead, shieldCount, shieldFlashTimer, upgradeVisuals, drawFace)
  if not trail or #trail == 0 then return end

  local thickness = SEGMENT_SIZE * 0.8
  local half      = thickness / 2

  local coords = buildCoords(trail)
  local head = trail[1]
  local tail = trail[#trail]

  love.graphics.setLineStyle("smooth")
  love.graphics.setLineJoin("bevel") -- or "bevel" if you prefer fewer spikes

  local hx, hy
  if getHead then
    hx, hy = getHead()
  end
  if not (hx and hy) then
    hx, hy = ptXY(head)
  end

  if #coords >= 4 then
    -- render into a canvas once
    local ww, hh = love.graphics.getDimensions()
    if not snakeCanvas or snakeCanvas:getWidth() ~= ww or snakeCanvas:getHeight() ~= hh then
      snakeCanvas = love.graphics.newCanvas(ww, hh, {msaa = 8})
    end

    love.graphics.setCanvas(snakeCanvas)
    love.graphics.clear(0,0,0,0)
    renderSnakeToCanvas(trail, coords, head, tail, half, thickness)
    love.graphics.setCanvas()

    -- single-pass drop shadow
    love.graphics.setColor(0,0,0,0.25)
    love.graphics.draw(snakeCanvas, SHADOW_OFFSET, SHADOW_OFFSET)

    -- snake
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(snakeCanvas, 0, 0)
  elseif hx and hy then
    -- fallback: draw a simple disk when only the head is visible
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(OUTLINE_SIZE)
    love.graphics.circle("line", hx, hy, half + OUTLINE_SIZE * 0.5)
    love.graphics.setColor(BODY_R, BODY_G, BODY_B)
    love.graphics.circle("fill", hx, hy, half)
  end

  if hx and hy and drawFace ~= false then
    if upgradeVisuals and upgradeVisuals.adrenaline then
      drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.adrenaline)
    end

    local faceScale = 1
    Face:draw(hx, hy, faceScale)

    drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)

    if upgradeVisuals and upgradeVisuals.stonebreaker then
      drawStonebreakerAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.stonebreaker)
    end
  end

  -- POP EFFECT
  if popTimer and popTimer > 0 and hx and hy then
    local t = 1 - (popTimer / POP_DURATION)
    if t < 1 then
      local pulse = 0.8 + 0.4 * math.sin(t * math.pi)
      love.graphics.setColor(1, 1, 1, 0.4)
      love.graphics.circle("fill", hx, hy, thickness * 0.6 * pulse)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return drawSnake
