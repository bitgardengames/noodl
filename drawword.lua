local SnakeDraw = require("snakedraw")

local DrawWord = {}

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

function DrawWord.draw(word, ox, oy, cellSize, spacing)
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
		SnakeDraw.run(snakeTrail, #snakeTrail, cellSize, nil, nil, nil, nil, nil, {
		drawFace = false,
		})

		x = x + (3 * cellSize) + spacing
	end
	end
	return fullTrail
end

return DrawWord
