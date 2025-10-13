local drawSnake = require("snakedraw")

local letters = {
	n = {
		{0,2}, {0,0},{2,0},{2,2}
	},
	o = {
		{0,0}, {2,0}, {2,2}, {0,2}, {0,0}
	},
	d = {
		{0,0}, {2,0}, {2,2}, {0,2}, {0,0},
		{2,0}, {2,-2}
	},
	l = {
		{0,-2}, {0,2}
	}
}

local drawWord = {}

local function draw(word, ox, oy, cellSize, spacing)
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
                snakeTrail[#snakeTrail + 1] = {
                  x = point.x,
                  y = point.y,
                  drawX = point.x,
                  drawY = point.y,
                }
          end

          -- The menu draws the face manually so it sits at the end of the word.
          -- Disable the built-in face rendering here to avoid double faces.
          drawSnake(snakeTrail, #snakeTrail, cellSize, nil, nil, nil, nil, nil, {
                drawFace = false,
          })

          x = x + (3 * cellSize) + spacing
        end
  end
  return fullTrail
end

local function getBounds(word)
  local minY, maxY

  for i = 1, #word do
        local ch = word:sub(i, i)
        local def = letters[ch]
        if def then
          for _, pt in ipairs(def) do
                local y = pt[2]
                if not minY or y < minY then
                  minY = y
                end
                if not maxY or y > maxY then
                  maxY = y
                end
          end
        end
  end

  return {
        minY = minY or 0,
        maxY = maxY or 0,
  }
end

drawWord.draw = draw
drawWord.getBounds = getBounds

return setmetatable(drawWord, {
  __call = function(self, ...)
    return self.draw(...)
  end,
})
