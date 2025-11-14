-- Stubs for dependencies required by arena.lua
local noop = function() end

love = {
	graphics = {
		isSupported = function()
			return false
		end,
		newShader = function()
			return nil
		end,
		getWidth = function()
			return 800
		end,
		getHeight = function()
			return 600
		end,
		newCanvas = function()
			return {}
		end,
		getCanvas = function()
			return nil
		end,
		setCanvas = noop,
		origin = noop,
		clear = noop,
		setBlendMode = noop,
		push = noop,
		pop = noop,
		setShader = noop,
		rectangle = noop,
		setColor = noop,
		draw = noop,
		getLineWidth = function()
			return 1
		end,
		setLineWidth = noop,
		getLineStyle = function()
			return "smooth"
		end,
		setLineStyle = noop,
		getLineJoin = function()
			return "miter"
		end,
		setLineJoin = noop,
		setScissor = noop,
		line = noop,
		circle = noop,
		arc = noop,
		newImage = function()
			return {}
		end,
		newMesh = function()
			return {}
		end,
		newQuad = function()
			return {}
		end,
		stencil = noop,
		setStencilTest = noop,
	},
	math = {
		random = function()
			return 0
		end,
		newRandomGenerator = function()
			local rng = {}
			function rng:random()
				return 0
			end
			return rng
		end,
	},
	timer = {
		getTime = function()
			return 0
		end,
	},
}

package.loaded["theme"] = {
	arenaBG = {0, 0, 0, 1},
	highlightColor = {1, 1, 1, 1},
	shadowColor = {0, 0, 0, 1},
	arenaBorder = {1, 1, 1, 1},
	rock = {1, 1, 1, 1},
	bgColor = {0, 0, 0, 1},
}

package.loaded["audio"] = {
	playSound = noop,
}

package.loaded["renderlayers"] = {
	withLayer = function(_, _, fn)
		if fn then
			fn()
		end
	end,
}

package.loaded["sharedcanvas"] = {
	ensureCanvas = function()
		return {}, false, 0
	end,
}

package.loaded["timer"] = {
	getTime = function()
		return 0
	end,
}

local SnakeSafeZone = {
	{5, 5},
	{5, 4},
	{4, 5},
}

package.loaded["snakeutils"] = {
	SEGMENT_SIZE = 24,
	isOccupied = function()
		return false
	end,
	setOccupied = noop,
}

package.loaded["snake"] = {
	getSegments = function()
		return {}
	end,
	getSafeZone = function()
		return SnakeSafeZone
	end,
	getHead = function()
		return 1000, 1000
	end,
}

package.loaded["fruit"] = {
	getTile = function()
		return nil, nil
	end,
}

package.loaded["rocks"] = {
	getAll = function()
		return {}
	end,
}

local Arena = require("arena")

local testArena = {}
for key, value in pairs(Arena) do
	testArena[key] = value
end

testArena.tileSize = 24
testArena.rows = 10
testArena.cols = 10
testArena.exit = nil
testArena._exitDrawRequested = false

function testArena:getCenterOfTile(col, row)
	return col * 10, row * 10
end

function testArena:getTileFromWorld(x, y)
	local col = math.floor(x / 10 + 0.5)
	local row = math.floor(y / 10 + 0.5)
	return col, row
end

function testArena:getRandomTile()
	return 5, 5
end

testArena:spawnExit()

assert(testArena.exit ~= nil, "expected exit to spawn")

for _, cell in ipairs(SnakeSafeZone) do
	assert(not (testArena.exit.col == cell[1] and testArena.exit.row == cell[2]), "exit spawned within the snake safe zone")
end

print("spawn_exit_spec.lua: ok")
