local Snake = require("snake")
local Fruit = require("fruit")
local Rocks = require("rocks")
local Saws = require("saws")
local Arena = require("arena")
local Particles = require("particles")

local Movement = {}

local SEGMENT_SIZE = 24 -- same size as rocks and snake

-- AABB collision check
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and ax + aw > bx and
		   ay < by + bh and ay + ah > by
end

function Movement:reset()
	Snake:resetPosition()
end

function Movement:update(dt)
	local alive, cause = Snake:update(dt)
	if not alive then
		return "dead", cause or "self"
	end

	local headX, headY = Snake:getHead()

	if not Arena:isInside(headX, headY) then
		if Snake:consumeCrashShield() then
			-- survived, maybe bounce back / particles
		else
			return "dead", "wall"
		end
	end

	for _, rock in ipairs(Rocks:getAll()) do
		if aabb(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE, rock.x, rock.y, rock.w, rock.h) then
			if Snake:consumeCrashShield() then
				-- shield absorbed the hit, play feedback and continue
				Particles:spawnBurst(rock.x + rock.w/2, rock.y + rock.h/2, {
					count = 8, speed = 40, life = 0.4, size = 3,
					color = {0.9, 0.8, 0.5, 1}, spread = math.pi*2
				})
				-- optionally mark rock as destroyed or not; I'm leaving it intact
			else
				return "dead", "rock"
			end
		end
	end

	local sawHit = Saws:checkCollision(headX, headY, SEGMENT_SIZE, SEGMENT_SIZE)

	if sawHit then
		if Snake:consumeCrashShield() then
			Particles:spawnBurst(headX, headY, {
				count = 8, speed = 40, life = 0.35, size = 3,
				color = {0.9,0.7,0.3,1}, spread = math.pi*2
			})
			-- shield consumed -> survive
		else
			return "dead", "saw"
		end
	end

	if Fruit:checkCollisionWith(headX, headY) then
		return "scored"
	end
end

return Movement