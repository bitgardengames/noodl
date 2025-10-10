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
      drawSnake(letterTrail, #letterTrail, cellSize, nil, nil, nil, nil, nil, false)

      for _, p in ipairs(letterTrail) do table.insert(fullTrail, p) end

      x = x + (3 * cellSize) + spacing
    end
  end
  return fullTrail
end

return drawWord
