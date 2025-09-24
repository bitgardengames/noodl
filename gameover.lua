local Screen = require("screen")
local SessionStats = require("sessionstats")
local Audio = require("audio")
local Theme = require("theme")
local UI = require("ui")
local ButtonList = require("buttonlist")

local GameOver = {}

-- Add one about no snakes were harmed in the making of this game
local deathMessages = {
    self = {
        "You bit yourself. Ouch.",
        "Snake vs. Snake: Snake wins.",
        "Ever heard of personal space?",
        "Cannibalism? Bold choice.",
        "Your tail says hi… a little too close.",
        "Snake made a knot it couldn’t untie.",
		"Congratulations, you played yourself.",
		"Snake practiced yoga… permanently.",
    },
    wall = {
        "Splat! Right into the wall.",
        "The wall was stronger.",
        "Note to self: bricks don’t move.",
        "Snake discovered geometry… fatally.",
        "That’s not an exit.",
        "Turns out walls don’t taste like apples.",
        "Ever heard of brakes?",
        "Snake tried parkour. Failed.",
    },
    rock = {
        "That rock didn’t budge.",
        "Oof. Rocks are hard.",
        "Who put that there?!",
        "Snake tested rock durability. Confirmed.",
        "Rock 1 – Snake 0.",
        "Snake’s greatest enemy: landscaping.",
		"New diet: minerals.",
		"You’ve unlocked Rock Appreciation 101.",
		"Rock solid. Snake squishy.",
    },
	saw = {
		"That wasn’t a salad spinner.",
		"Just rub some dirt on it.",
		"OSHA has entered the chat.",
		"Snake auditioned for a horror movie."
	},
    unknown = {
        "Mysterious demise...",
        "The void has claimed you.",
        "Well, that’s one way to end it.",
        "Snake blinked out of existence.",
        "Cosmic forces intervened.",
        "Snake entered the glitch dimension.",
    },
}

local fontLarge
local fontSmall
local stats = {}
local buttonList = ButtonList.new()

-- Layout constants
local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 50
local BUTTON_SPACING = 20

-- All button definitions in one place
local buttonDefs = {
    { id = "goPlay", text = "Play Again", action = "game" },
    { id = "goMenu", text = "Quit to Menu", action = "menu" },
}

function GameOver:enter(data)
    UI.clearButtons()

    data = data or {cause = "unknown"}

    Audio:playMusic("scorescreen")
    Screen:update()

	local cause = data.cause or "unknown"
	self.deathMessage = "You died."

	-- Pick a random quip if we have one
	if deathMessages[cause] then
		local options = deathMessages[cause]
		self.deathMessage = options[love.math.random(#options)]
	end

    fontLarge = love.graphics.newFont(32)
    fontSmall = love.graphics.newFont(18)

    -- Merge default stats with provided stats
    stats = {
        score       = 0,
        highScore   = 0,
        apples      = SessionStats:get("applesEaten"),
        mode        = "Classic",
        totalApples = "?",
    }
    for k, v in pairs(data.stats or {}) do
        stats[k] = v
    end
    if data.score then stats.score = data.score end
    if data.highScore then stats.highScore = data.highScore end
    if data.apples then stats.apples = data.apples end
    if data.mode then stats.mode = data.mode end
    if data.totalApples then stats.totalApples = data.totalApples end

    -- Build buttons
    local sw, sh = Screen:get()
    local startY = math.floor(sh * 0.55)
    local centerX = sw / 2 - BUTTON_WIDTH / 2

    local defs = {}
    for i, def in ipairs(buttonDefs) do
        local y = startY + (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)
        defs[#defs + 1] = {
            id = def.id,
            text = def.text,
            action = def.action,
            x = centerX,
            y = y,
            w = BUTTON_WIDTH,
            h = BUTTON_HEIGHT,
        }
    end

    buttonList:reset(defs)
end

function GameOver:draw()
    local sw, sh = Screen:get()

    love.graphics.setColor(Theme.bgColor)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Over", 0, 80, sw, "center")

    -- Stats block
    love.graphics.setFont(fontSmall)
    local y = 140
    local lineHeight = 25
    local statLines = {
        ("Final Score: %d"):format(stats.score),
        ("High Score: %d"):format(stats.highScore),
        ("Apples Eaten: %d"):format(stats.apples),
    }
    for i, text in ipairs(statLines) do
        love.graphics.printf(text, 0, y + (i - 1) * lineHeight, sw, "center")
    end

	-- Death message
	love.graphics.setFont(fontSmall)
	love.graphics.setColor(1, 0.8, 0.8) -- light red/pink for flavor
	love.graphics.printf(self.deathMessage, 0, y + #statLines * lineHeight + 20, sw, "center")

    -- Buttons
    buttonList:draw()
end

function GameOver:mousepressed(x, y, button)
    buttonList:mousepressed(x, y, button)
end

function GameOver:mousereleased(x, y, button)
    local action = buttonList:mousereleased(x, y, button)
    return action
end

return GameOver