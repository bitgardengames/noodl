local Face = require("face")
local Theme = require("theme")

local faceTexture = love.graphics.newImage("Assets/faceBlank.png")
local bodyTexture = love.graphics.newImage("Assets/SnakeBodyDesaturated.png")
bodyTexture:setWrap("repeat", "repeat")

local unpack = unpack

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 6

-- colors (body color reused for patches so they blend)
local BODY_R, BODY_G, BODY_B = Theme.snakeDefault
local TINT_ALPHA = 0.1

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


local function renderSnakeToCanvas(trail, coords, head, tail, half, thickness)
	-- OUTLINE
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.setLineWidth(thickness + OUTLINE_SIZE)
	drawPolyline(coords)
	drawEndcaps(head, tail, half + OUTLINE_SIZE * 0.5)
	drawCornerPlugs(trail, half + OUTLINE_SIZE*0.5)

	-- BODY
	love.graphics.setColor(BODY_R, BODY_G, BODY_B)
	love.graphics.setLineWidth(thickness)
	drawPolyline(coords)
	drawEndcaps(head, tail, half)

	love.graphics.setColor(BODY_R, BODY_G, BODY_B)
	drawCornerPlugs(trail, half)
end

local function drawSnake(trail, segmentCount, SEGMENT_SIZE, popTimer, getHead)
  if not trail or #trail < 2 then return end

  --local thickness = SEGMENT_SIZE * 0.75
  local thickness = SEGMENT_SIZE * 0.8
  local half      = thickness / 2

  local coords = buildCoords(trail)
  if #coords < 4 then return end

  local head = trail[1]
  local tail = trail[#trail]

  love.graphics.setLineStyle("smooth")
  love.graphics.setLineJoin("bevel") -- or "bevel" if you prefer fewer spikes

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

	if head and head.drawX then
		local hx, hy = getHead()
		if hx and hy then
			local faceTexture = Face:getTexture()
			local faceScale = 1
			local ox = faceTexture:getWidth() / 2
			local oy = faceTexture:getHeight() / 2

			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.draw(faceTexture, hx, hy, 0, faceScale, faceScale, ox, oy)
		end
	end

  -- POP EFFECT
  if popTimer and popTimer > 0 then
    local t = 1 - (popTimer / POP_DURATION)
    if t < 1 then
      local pulse = 0.8 + 0.4 * math.sin(t * math.pi)
      local px, py = hx, hy
      if px and py then
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.circle("fill", px, py, thickness * 0.6 * pulse)
      end
    end
  end
end

return drawSnake