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

function DrawWord.draw(word, ox, oy, CellSize, spacing)
	local x = ox
	local FullTrail = {}

	local LetterCount = 0
	for i = 1, #word do
	if letters[word:sub(i, i)] then
		LetterCount = LetterCount + 1
	end
	end

	local DrawnLetters = 0
	for i = 1, #word do
	local ch = word:sub(i,i)
	local def = letters[ch]
	if def then
		DrawnLetters = DrawnLetters + 1
		local LetterPoints = {}
		for index, pt in ipairs(def) do
		local px = x + pt[1] * CellSize
		local py = oy + pt[2] * CellSize
		LetterPoints[index] = { x = px, y = py }
		FullTrail[#FullTrail + 1] = { x = px, y = py }
		end

		local SnakeTrail = {}
		for index = #LetterPoints, 1, -1 do
		local point = LetterPoints[index]
		SnakeTrail[#SnakeTrail + 1] = {
			x = point.x,
			y = point.y,
			DrawX = point.x,
			DrawY = point.y,
		}
		end

		-- The menu draws the face manually so it sits at the end of the word.
		-- Disable the built-in face rendering here to avoid double faces.
		SnakeDraw.run(SnakeTrail, #SnakeTrail, CellSize, nil, nil, nil, nil, nil, {
		DrawFace = false,
		})

		x = x + (3 * CellSize) + spacing
	end
	end
	return FullTrail
end

return DrawWord
