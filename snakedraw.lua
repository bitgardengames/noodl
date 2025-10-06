local Face = require("face")
local SnakeCosmetics = require("snakecosmetics")

local unpack = unpack

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 3
local FRUIT_BULGE_SCALE = 1.25

-- Canvas for single-pass shadow
local snakeCanvas = nil
local snakeOverlayCanvas = nil

local overlayShaderSources = {
  stripes = [[
    extern float time;
    extern float frequency;
    extern float speed;
    extern float angle;
    extern float intensity;
    extern vec4 colorA;
    extern vec4 colorB;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
      vec4 base = Texel(tex, texture_coords);
      float mask = base.a;
      if (mask <= 0.0) {
        return base * color;
      }

      vec2 uv = texture_coords - vec2(0.5);
      float c = cos(angle);
      float s = sin(angle);
      float stripe = sin((uv.x * c + uv.y * s) * frequency + time * speed) * 0.5 + 0.5;
      float blend = clamp(stripe * intensity, 0.0, 1.0);
      vec3 mixCol = mix(colorA.rgb, colorB.rgb, stripe);
      vec3 result = mix(base.rgb, mixCol, blend);
      return vec4(result, base.a) * color;
    }
  ]],
  holo = [[
    extern float time;
    extern float speed;
    extern float intensity;
    extern vec4 colorA;
    extern vec4 colorB;
    extern vec4 colorC;

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
      vec4 base = Texel(tex, texture_coords);
      float mask = base.a;
      if (mask <= 0.0) {
        return base * color;
      }

      vec2 uv = texture_coords - vec2(0.5);
      float wave = sin((uv.x + uv.y) * 10.0 + time * speed);
      float radial = sin(length(uv * vec2(1.4, 1.0)) * 12.0 - time * (speed * 0.6 + 0.2));
      float shimmer = sin((uv.x - uv.y) * 16.0 + time * speed * 1.8);

      float baseMix = clamp(0.5 + 0.5 * wave, 0.0, 1.0);
      vec3 layer = mix(colorA.rgb, colorB.rgb, baseMix);
      layer = mix(layer, colorC.rgb, clamp(radial * 0.5 + 0.5, 0.0, 1.0) * 0.6);
      layer += shimmer * 0.12 * colorC.rgb;

      float blend = clamp(intensity, 0.0, 1.0);
      vec3 result = mix(base.rgb, layer, blend);
      return vec4(result, base.a) * color;
    }
  ]],
}

local overlayShaderCache = {}

local function safeResolveShader(typeId)
  if overlayShaderCache[typeId] ~= nil then
    return overlayShaderCache[typeId]
  end

  local source = overlayShaderSources[typeId]
  if not source then
    overlayShaderCache[typeId] = false
    return nil
  end

  local ok, shader = pcall(love.graphics.newShader, source)
  if not ok then
    print("[snakedraw] failed to build overlay shader", typeId, shader)
    overlayShaderCache[typeId] = false
    return nil
  end

  overlayShaderCache[typeId] = shader
  return shader
end

local function resolveColor(color, fallback)
  if type(color) == "table" then
    return {
      color[1] or 0,
      color[2] or 0,
      color[3] or 0,
      color[4] or 1,
    }
  end

  if fallback then
    return resolveColor(fallback)
  end

  return {1, 1, 1, 1}
end

local function applyOverlay(canvas, config)
  if not (canvas and config and config.type) then
    return false
  end

  local shader = safeResolveShader(config.type)
  if not shader then
    return false
  end

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local colors = config.colors or {}
  local primary = resolveColor(colors.primary or colors.color or SnakeCosmetics:getBodyColor())
  local secondary = resolveColor(colors.secondary or SnakeCosmetics:getGlowColor())
  local tertiary = resolveColor(colors.tertiary or secondary)

  shader:send("time", time)
  shader:send("intensity", config.intensity or 0.5)
  shader:send("colorA", primary)
  shader:send("colorB", secondary)

  if config.type == "stripes" then
    shader:send("frequency", config.frequency or 18)
    shader:send("speed", config.speed or 0.6)
    shader:send("angle", math.rad(config.angle or 45))
  elseif config.type == "holo" then
    shader:send("speed", config.speed or 1.0)
    shader:send("colorC", tertiary)
  end

  love.graphics.push("all")
  love.graphics.setShader(shader)
  love.graphics.setBlendMode(config.blendMode or "alpha")
  love.graphics.setColor(1, 1, 1, config.opacity or 1)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()

  return true
end

-- helper: prefer drawX/drawY, fallback to x/y
local function ptXY(p)
  if not p then return nil, nil end
  return (p.drawX or p.x), (p.drawY or p.y)
end

local drawSoftGlow

local function applySkinGlow(trail, head, radius, config)
  if not config then
    return
  end

  local color = resolveColor(config.color, SnakeCosmetics:getGlowColor())
  local intensity = config.intensity or 0.5
  local step = math.max(1, math.floor(config.step or 2))
  local radiusMultiplier = config.radiusMultiplier or 1.4

  local function drawGlowAt(x, y)
    if not (x and y) then
      return
    end
    drawSoftGlow(x, y, radius * radiusMultiplier, color[1], color[2], color[3], (color[4] or 1) * intensity)
  end

  if trail and #trail > 0 then
    for i = 1, #trail, step do
      local seg = trail[i]
      if seg and seg ~= head then
        local x, y = ptXY(seg)
        drawGlowAt(x, y)
      end
    end
  end

  if head then
    local hx, hy = ptXY(head)
    drawGlowAt(hx, hy)
  end
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

local function drawFruitBulges(trail, head, radius)
  if not trail or radius <= 0 then return end

  for i = 1, #trail do
    local seg = trail[i]
    if seg and seg.fruitMarker and seg ~= head then
      local x = seg.fruitMarkerX or (seg.drawX or seg.x)
      local y = seg.fruitMarkerY or (seg.drawY or seg.y)

      if x and y then
        love.graphics.circle("fill", x, y, radius)
      end
    end
  end
end

local function addPoint(list, x, y)
  if not (x and y) then return end

  local n = #list
  if n >= 2 then
    local lastX = list[n - 1]
    local lastY = list[n]
    if math.abs(lastX - x) < 1e-4 and math.abs(lastY - y) < 1e-4 then
      return
    end
  end

  list[#list + 1] = x
  list[#list + 1] = y
end

local function buildSmoothedCoords(coords, radius)
  if radius <= 0 or #coords <= 4 then
    return coords
  end

  local smoothed = {}
  local smoothSteps = 4
  local maxSmooth = radius * 1.5

  addPoint(smoothed, coords[1], coords[2])

  for i = 3, #coords - 3, 2 do
    local x, y = coords[i], coords[i + 1]
    local px, py = coords[i - 2], coords[i - 1]
    local nx, ny = coords[i + 2], coords[i + 3]

    if not (px and py and nx and ny) then
      addPoint(smoothed, x, y)
    else
      local prevDx, prevDy = x - px, y - py
      local nextDx, nextDy = nx - x, ny - y
      local prevLen = math.sqrt(prevDx * prevDx + prevDy * prevDy)
      local nextLen = math.sqrt(nextDx * nextDx + nextDy * nextDy)

      if prevLen < 1e-3 or nextLen < 1e-3 then
        addPoint(smoothed, x, y)
      else
        local entryDist = math.min(prevLen * 0.5, maxSmooth)
        local exitDist = math.min(nextLen * 0.5, maxSmooth)

        local entryX = x - prevDx / prevLen * entryDist
        local entryY = y - prevDy / prevLen * entryDist
        local exitX = x + nextDx / nextLen * exitDist
        local exitY = y + nextDy / nextLen * exitDist

        addPoint(smoothed, entryX, entryY)

        for step = 1, smoothSteps - 1 do
          local t = step / smoothSteps
          local inv = 1 - t
          local qx = inv * inv * entryX + 2 * inv * t * x + t * t * exitX
          local qy = inv * inv * entryY + 2 * inv * t * y + t * t * exitY
          addPoint(smoothed, qx, qy)
        end

        addPoint(smoothed, exitX, exitY)
      end
    end
  end

  addPoint(smoothed, coords[#coords - 1], coords[#coords])

  return smoothed
end

local function drawSnakeStroke(path, radius)
  if not path or radius <= 0 or #path < 2 then
    return
  end

  if #path == 2 then
    love.graphics.circle("fill", path[1], path[2], radius)
    return
  end

  love.graphics.setLineWidth(radius * 2)
  love.graphics.line(path)
end

local function renderSnakeToCanvas(trail, coords, head, half)
  local bodyColor = SnakeCosmetics:getBodyColor()
  local outlineColor = SnakeCosmetics:getOutlineColor()
  local bodyR, bodyG, bodyB, bodyA = bodyColor[1] or 0, bodyColor[2] or 0, bodyColor[3] or 0, bodyColor[4] or 1
  local outlineR, outlineG, outlineB, outlineA = outlineColor[1] or 0, outlineColor[2] or 0, outlineColor[3] or 0, outlineColor[4] or 1
  local bulgeRadius = half * FRUIT_BULGE_SCALE

  local outlineCoords = buildSmoothedCoords(coords, half + OUTLINE_SIZE)
  local bodyCoords = buildSmoothedCoords(coords, half)

  love.graphics.push("all")
  love.graphics.setLineStyle("smooth")
  if love.graphics.setLineCap then
    love.graphics.setLineCap("round")
  end

  love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
  drawSnakeStroke(outlineCoords, half + OUTLINE_SIZE)
  drawFruitBulges(trail, head, bulgeRadius + OUTLINE_SIZE)

  love.graphics.setColor(bodyR, bodyG, bodyB, bodyA)
  drawSnakeStroke(bodyCoords, half)
  drawFruitBulges(trail, head, bulgeRadius)

  love.graphics.pop()

end

drawSoftGlow = function(x, y, radius, r, g, b, a)
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

local function drawTimeDilationAura(hx, hy, SEGMENT_SIZE, data)
  if not data then return end

  local duration = data.duration or 0
  if duration <= 0 then duration = 1 end

  local timer = math.max(0, data.timer or 0)
  local cooldown = data.cooldown or 0
  local cooldownTimer = math.max(0, data.cooldownTimer or 0)

  local readiness
  if cooldown > 0 then
    readiness = 1 - math.min(1, cooldownTimer / math.max(0.0001, cooldown))
  else
    readiness = data.active and 1 or 0.6
  end

  local intensity = readiness * 0.35
  if data.active then
    intensity = math.max(intensity, 0.45) + 0.45 * math.min(1, timer / duration)
  end

  if intensity <= 0 then return end

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local baseRadius = SEGMENT_SIZE * (0.95 + 0.35 * intensity)

  drawSoftGlow(hx, hy, baseRadius * 1.55, 0.45, 0.9, 1, 0.3 + 0.45 * intensity)

  love.graphics.push("all")

  love.graphics.setBlendMode("add")
  for i = 1, 3 do
    local ringT = (i - 1) / 2
    local wobble = math.sin(time * (1.6 + ringT * 0.8)) * SEGMENT_SIZE * 0.06
    love.graphics.setColor(0.32, 0.74, 1, (0.15 + 0.25 * intensity) * (1 - ringT * 0.35))
    love.graphics.setLineWidth(1.6 + (3 - i) * 0.9)
    love.graphics.circle("line", hx, hy, baseRadius * (1.05 + ringT * 0.25) + wobble)
  end

  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(0.4, 0.8, 1, 0.25 + 0.4 * intensity)
  love.graphics.setLineWidth(2)
  local wobble = 1 + 0.08 * math.sin(time * 2.2)
  love.graphics.circle("line", hx, hy, baseRadius * wobble)

  local dialRotation = time * (data.active and 1.8 or 0.9)
  love.graphics.setColor(0.26, 0.62, 0.95, 0.2 + 0.25 * intensity)
  love.graphics.setLineWidth(2.4)
  for i = 1, 3 do
    local offset = dialRotation + (i - 1) * (math.pi * 2 / 3)
    love.graphics.arc("line", "open", hx, hy, baseRadius * 0.75, offset, offset + math.pi / 4)
  end

  local tickCount = 6
  local spin = time * (data.active and -1.2 or -0.6)
  love.graphics.setColor(0.6, 0.95, 1, 0.2 + 0.35 * intensity)
  for i = 1, tickCount do
    local angle = spin + (i / tickCount) * math.pi * 2
    local inner = baseRadius * 0.55
    local outer = baseRadius * (1.25 + 0.1 * math.sin(time * 3 + i))
    love.graphics.line(
      hx + math.cos(angle) * inner,
      hy + math.sin(angle) * inner,
      hx + math.cos(angle) * outer,
      hy + math.sin(angle) * outer
    )
  end

  love.graphics.pop()
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

local function drawDashStreaks(trail, SEGMENT_SIZE, data)
  if not data then return end
  if not trail or #trail < 2 then return end

  local duration = data.duration or 0
  if duration <= 0 then duration = 1 end

  local timer = math.max(0, data.timer or 0)
  local cooldown = data.cooldown or 0
  local cooldownTimer = math.max(0, data.cooldownTimer or 0)

  local intensity = 0
  if data.active then
    intensity = math.max(0.35, math.min(1, timer / duration + 0.2))
  elseif cooldown > 0 then
    intensity = math.max(0, 1 - cooldownTimer / math.max(0.0001, cooldown)) * 0.45
  else
    intensity = 0.3
  end

  if intensity <= 0 then return end

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local streaks = math.min(#trail - 1, 6)
  if streaks <= 0 then return end

  love.graphics.push("all")
  love.graphics.setBlendMode("add")

  for i = 1, streaks do
    local seg = trail[i]
    local nextSeg = trail[i + 1]
    local x1, y1 = ptXY(seg)
    local x2, y2 = ptXY(nextSeg)
    if x1 and y1 and x2 and y2 then
      local fade = (streaks - i + 1) / streaks
      local wobble = math.sin(time * 8 + i) * SEGMENT_SIZE * 0.05
      local dirX, dirY = x2 - x1, y2 - y1
      local length = math.sqrt(dirX * dirX + dirY * dirY)
      if length > 1e-4 then
        dirX, dirY = dirX / length, dirY / length
      end
      local perpX, perpY = -dirY, dirX

      local offsetX = perpX * wobble
      local offsetY = perpY * wobble

      love.graphics.setColor(1, 0.76, 0.28, 0.18 + 0.4 * intensity * fade)
      love.graphics.setLineWidth(SEGMENT_SIZE * (0.35 + 0.12 * intensity * fade))
      love.graphics.line(x1 + offsetX, y1 + offsetY, x2 + offsetX, y2 + offsetY)

      love.graphics.setColor(1, 0.42, 0.12, 0.15 + 0.25 * intensity * fade)
      love.graphics.circle("fill", x2 + offsetX * 0.5, y2 + offsetY * 0.5, SEGMENT_SIZE * 0.16 * fade)
    end
  end

  love.graphics.pop()
end

local function drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, data)
  if not data then return end

  local duration = data.duration or 0
  if duration <= 0 then duration = 1 end

  local timer = math.max(0, data.timer or 0)
  local cooldown = data.cooldown or 0
  local cooldownTimer = math.max(0, data.cooldownTimer or 0)

  local readiness
  if data.active then
    readiness = math.min(1, timer / duration)
  elseif cooldown > 0 then
    readiness = 1 - math.min(1, cooldownTimer / math.max(0.0001, cooldown))
  else
    readiness = 1
  end

  readiness = math.max(0, math.min(1, readiness))
  local intensity = readiness
  if data.active then
    intensity = math.max(intensity, 0.75)
  end

  if intensity <= 0 then return end

  local time = 0
  if love and love.timer and love.timer.getTime then
    time = love.timer.getTime()
  end

  local baseRadius = SEGMENT_SIZE * (0.85 + 0.3 * intensity)
  drawSoftGlow(hx, hy, baseRadius * (1.35 + 0.25 * intensity), 1, 0.78, 0.32, 0.25 + 0.35 * intensity)

  local dirX, dirY = 0, -1
  local head = trail and trail[1]
  if head and (head.dirX or head.dirY) then
    dirX = head.dirX or dirX
    dirY = head.dirY or dirY
  end

  local nextSeg = trail and trail[2]
  if head and nextSeg then
    local hx1, hy1 = ptXY(head)
    local hx2, hy2 = ptXY(nextSeg)
    if hx1 and hy1 and hx2 and hy2 then
      local dx, dy = hx2 - hx1, hy2 - hy1
      if dx ~= 0 or dy ~= 0 then
        dirX, dirY = dx, dy
      end
    end
  end

  local length = math.sqrt(dirX * dirX + dirY * dirY)
  if length > 1e-4 then
    dirX, dirY = dirX / length, dirY / length
  end

  local angle
  if math.atan2 then
    angle = math.atan2(dirY, dirX)
  else
    angle = math.atan(dirY, dirX)
  end

  love.graphics.push("all")
  love.graphics.translate(hx, hy)
  love.graphics.rotate(angle)

  love.graphics.setColor(1, 0.78, 0.26, 0.3 + 0.4 * intensity)
  love.graphics.setLineWidth(2 + intensity * 2)
  love.graphics.arc("line", "open", 0, 0, baseRadius, -math.pi * 0.65, math.pi * 0.65)

  love.graphics.setBlendMode("add")
  local flareRadius = baseRadius * (1.18 + 0.08 * math.sin(time * 5))
  love.graphics.setColor(1, 0.86, 0.42, 0.22 + 0.35 * intensity)
  love.graphics.arc("fill", 0, 0, flareRadius, -math.pi * 0.28, math.pi * 0.28)

  if not data.active then
    local sweep = readiness * math.pi * 2
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 0.62, 0.18, 0.35 + 0.4 * intensity)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", 0, 0, baseRadius * 0.85, -math.pi / 2, -math.pi / 2 + sweep)
  else
    local pulse = 0.75 + 0.25 * math.sin(time * 10)
    love.graphics.setColor(1, 0.95, 0.55, 0.5)
    love.graphics.polygon("fill",
      baseRadius * 0.75, 0,
      baseRadius * (1.35 + 0.15 * pulse), -SEGMENT_SIZE * 0.34 * pulse,
      baseRadius * (1.35 + 0.15 * pulse), SEGMENT_SIZE * 0.34 * pulse
    )
    love.graphics.setBlendMode("alpha")
  end

  love.graphics.setColor(1, 0.68, 0.2, 0.22 + 0.4 * intensity)
  local sparks = 6
  for i = 1, sparks do
    local offset = time * (data.active and 7 or 3.5) + (i / sparks) * math.pi * 2
    local inner = baseRadius * 0.5
    local outer = baseRadius * (1.1 + 0.1 * math.sin(time * 4 + i))
    love.graphics.setLineWidth(1.25)
    love.graphics.line(math.cos(offset) * inner, math.sin(offset) * inner, math.cos(offset) * outer, math.sin(offset) * outer)
  end

  love.graphics.pop()
end

local function drawSnake(trail, segmentCount, SEGMENT_SIZE, popTimer, getHead, shieldCount, shieldFlashTimer, upgradeVisuals, drawFace)
  if not trail or #trail == 0 then return end

  local thickness = SEGMENT_SIZE * 0.8
  local half      = thickness / 2

  local overlayEffect = SnakeCosmetics:getOverlayEffect()
  local glowEffect = SnakeCosmetics:getGlowEffect()

  local coords = buildCoords(trail)
  local head = trail[1]

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
    renderSnakeToCanvas(trail, coords, head, half)
    love.graphics.setCanvas()

    -- single-pass drop shadow
    love.graphics.setColor(0,0,0,0.25)
    love.graphics.draw(snakeCanvas, SHADOW_OFFSET, SHADOW_OFFSET)

    -- snake
    local drewOverlay = false
    if overlayEffect then
      if not snakeOverlayCanvas or snakeOverlayCanvas:getWidth() ~= ww or snakeOverlayCanvas:getHeight() ~= hh then
        snakeOverlayCanvas = love.graphics.newCanvas(ww, hh)
      end

      love.graphics.setCanvas(snakeOverlayCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.setColor(1,1,1,1)
      love.graphics.draw(snakeCanvas, 0, 0)
      drewOverlay = applyOverlay(snakeCanvas, overlayEffect)
      love.graphics.setCanvas()
    end

    love.graphics.setColor(1,1,1,1)
    if drewOverlay then
      love.graphics.draw(snakeOverlayCanvas, 0, 0)
    else
      love.graphics.draw(snakeCanvas, 0, 0)
    end

    applySkinGlow(trail, head, half, glowEffect)
  elseif hx and hy then
    -- fallback: draw a simple disk when only the head is visible
    local bodyColor = SnakeCosmetics:getBodyColor()
    local outlineColor = SnakeCosmetics:getOutlineColor()
    local outlineR = outlineColor[1] or 0
    local outlineG = outlineColor[2] or 0
    local outlineB = outlineColor[3] or 0
    local outlineA = outlineColor[4] or 1
    local bodyR = bodyColor[1] or 1
    local bodyG = bodyColor[2] or 1
    local bodyB = bodyColor[3] or 1
    local bodyA = bodyColor[4] or 1

    love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
    love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
    love.graphics.setColor(bodyR, bodyG, bodyB, bodyA)
    love.graphics.circle("fill", hx, hy, half)

    applySkinGlow(trail, head, half, glowEffect)
  end

  if hx and hy and drawFace ~= false then
    if upgradeVisuals and upgradeVisuals.timeDilation then
      drawTimeDilationAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.timeDilation)
    end

    if upgradeVisuals and upgradeVisuals.adrenaline then
      drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.adrenaline)
    end

    if upgradeVisuals and upgradeVisuals.dash then
      drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.dash)
    end

    local faceScale = 1
    Face:draw(hx, hy, faceScale)

    drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)

    if upgradeVisuals and upgradeVisuals.dash then
      drawDashStreaks(trail, SEGMENT_SIZE, upgradeVisuals.dash)
    end

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
