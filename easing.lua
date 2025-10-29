local pow = math.pow

local Easing = {}

function Easing.clamp(value, minValue, maxValue)
	if minValue > maxValue then
		minValue, maxValue = maxValue, minValue
	end

	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end

	return value
end

function Easing.clamp01(value)
	return Easing.clamp(value, 0, 1)
end

function Easing.lerp(a, b, t)
	return a + (b - a) * t
end

function Easing.easeOutCubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

function Easing.easeInOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end

	local inv = 1 - t
	return 1 - 4 * inv * inv * inv
end

function Easing.easeInCubic(t)
	return t * t * t
end

function Easing.easeOutExpo(t)
	if t >= 1 then
		return 1
	end

	return 1 - pow(2, -10 * t)
end

function Easing.easeOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1

	return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
end

function Easing.easeInBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1

	return c3 * pow(t, 3) - c1 * pow(t, 2)
end

function Easing.getTransitionAlpha(t, direction)
	t = Easing.clamp01(t)

	if direction == 1 then
		return t
	end

	return 1 - t
end

return Easing