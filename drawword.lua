local drawSnake = require("snakedraw")

--[[local letters = {
  n = {
    {0,0}, {0,3}, {1,3}, {1,0}, {2,0}, {2,3}
  },
  o = {
    {0,0}, {2,0}, {2,3}, {0,3}, {0,0}
  },
  d = {
    {0,3}, {0,0}, {1,0}, {2,1}, {2,2}, {1,3}, {0,3}
  },
  l = {
    {0,0}, {0,3}
  }
}]]

local function expandLetter(points)
  local expanded = {}
  if not points or #points == 0 then
    return expanded
  end

  local function addPoint(x, y)
    local last = expanded[#expanded]
    if not last or last[1] ~= x or last[2] ~= y then
      expanded[#expanded + 1] = {x, y}
    end
  end

  addPoint(points[1][1], points[1][2])

  for i = 2, #points do
    local prev = points[i - 1]
    local curr = points[i]
    local dx = curr[1] - prev[1]
    local dy = curr[2] - prev[2]

    assert(dx == 0 or dy == 0, "Letter paths must use axis-aligned segments")

    local stepX = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local stepY = dy > 0 and 1 or (dy < 0 and -1 or 0)

    local x, y = prev[1], prev[2]
    while x ~= curr[1] or y ~= curr[2] do
      if stepX ~= 0 then
        x = x + stepX
      else
        y = y + stepY
      end
      addPoint(x, y)
    end
  end

  return expanded
end

local letters = {
  n = expandLetter({
    {0, 2}, {0, 0}, {2, 0}, {2, 2}
  }),
  o = expandLetter({
    {0, 0}, {2, 0}, {2, 2}, {0, 2}, {0, 0}
  }),
  d = expandLetter({
    {0, 0}, {2, 0}, {2, 2}, {0, 2}, {0, 0},
    {2, 0}, {2, -2}
  }),
  l = expandLetter({
    {0, -2}, {0, 2}
  })
}

local function normalize(dx, dy)
  local lenSq = dx * dx + dy * dy
  if lenSq > 1e-6 then
    local invLen = 1 / math.sqrt(lenSq)
    return dx * invLen, dy * invLen
  end
  return 0, 0
end

local function drawWord(word, ox, oy, cellSize, spacing)
  local x = ox
  local fullTrail = {}

  local letterCount = 0
  for i = 1, #word do
    if letters[word:sub(i, i)] then
      letterCount = letterCount + 1
    end
  end

  local drawnLetters = 0
  for i = 1, #word do
    local ch = word:sub(i,i)
    local def = letters[ch]
    if def then
      drawnLetters = drawnLetters + 1
      local letterPoints = {}
      for index, pt in ipairs(def) do
        local px = x + pt[1] * cellSize
        local py = oy + pt[2] * cellSize
        letterPoints[index] = { x = px, y = py }
        fullTrail[#fullTrail + 1] = { x = px, y = py }
      end

      local snakeTrail = {}
      for index = #letterPoints, 1, -1 do
        local point = letterPoints[index]
        local dirX, dirY = 0, 0

        local prev = letterPoints[index - 1]
        local nextPoint = letterPoints[index + 1]

        if prev then
          dirX, dirY = normalize(point.x - prev.x, point.y - prev.y)
        elseif nextPoint then
          dirX, dirY = normalize(nextPoint.x - point.x, nextPoint.y - point.y)
        end

        snakeTrail[#snakeTrail + 1] = {
          x = point.x,
          y = point.y,
          drawX = point.x,
          drawY = point.y,
          dirX = dirX,
          dirY = dirY
        }
      end

      -- The menu draws the face manually so it sits at the end of the word.
      -- Disable the built-in face rendering here to avoid double faces.
      drawSnake(snakeTrail, #snakeTrail, cellSize, nil, nil, nil, nil, nil, {
        drawFace = false
      })

      x = x + (3 * cellSize) + spacing
    end
  end
  return fullTrail
end

return drawWord
