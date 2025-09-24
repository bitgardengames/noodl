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

local function drawLetter(letterDef, ox, oy, cellSize)
  local trail = {}
  for i, pt in ipairs(letterDef) do
    trail[#trail+1] = {
      x = ox + pt[1] * cellSize,
      y = oy + pt[2] * cellSize,
    }
  end

  local function getHead()
    return trail[#trail].x, trail[#trail].y
  end

for _, p in ipairs(trail) do
  love.graphics.setColor(1, 0, 0)
  love.graphics.circle("fill", p.x, p.y, 3)
end


  drawSnake(trail, #trail, cellSize, 0, getHead)
end

local function drawWord(word, ox, oy, cellSize, spacing)
  local x = ox
  local fullTrail = {}
  for i = 1, #word do
    local ch = word:sub(i,i)
    local def = letters[ch]
    if def then
      local letterTrail = {}
      for _, pt in ipairs(def) do
        table.insert(letterTrail, {x = x + pt[1] * cellSize, y = oy + pt[2] * cellSize})
      end
      drawSnake(letterTrail, #letterTrail, cellSize)
      for _, p in ipairs(letterTrail) do table.insert(fullTrail, p) end

      x = x + (3 * cellSize) + spacing
    end
  end
  return fullTrail
end

return drawWord