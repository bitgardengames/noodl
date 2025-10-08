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
      local letterTrail = {}
      for _, pt in ipairs(def) do
        table.insert(letterTrail, {x = x + pt[1] * cellSize, y = oy + pt[2] * cellSize})
      end

      -- The menu draws the face manually so it sits at the end of the word.
      -- Disable the built-in face rendering here to avoid double faces.
      drawSnake(letterTrail, #letterTrail, cellSize, nil, nil, nil, nil, nil, {
        drawFace = false
      })

      for _, p in ipairs(letterTrail) do table.insert(fullTrail, p) end

      x = x + (3 * cellSize) + spacing
    end
  end
  return fullTrail
end

return drawWord
