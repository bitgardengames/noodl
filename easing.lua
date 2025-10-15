local Easing = {}

function Easing.clamp(value, MinValue, MaxValue)
	if MinValue > MaxValue then
		MinValue, MaxValue = MaxValue, MinValue
	end

	if value < MinValue then
		return MinValue
	elseif value > MaxValue then
		return MaxValue
	end

	return value
end

function Easing.clamp01(value)
	return Easing.clamp(value, 0, 1)
end

function Easing.lerp(a, b, t)
	return a + (b - a) * t
end

function Easing.EaseOutCubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

function Easing.EaseInCubic(t)
	return t * t * t
end

function Easing.EaseInOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end

	t = (2 * t) - 2
	return 0.5 * t * t * t + 1
end

function Easing.EaseOutExpo(t)
	if t >= 1 then
		return 1
	end

	return 1 - math.pow(2, -10 * t)
end

function Easing.EaseOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1

	return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function Easing.EaseInBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1

	return c3 * math.pow(t, 3) - c1 * math.pow(t, 2)
end

function Easing.EasedProgress(timer, duration)
	if not duration or duration <= 0 then
		return 1
	end

	return Easing.EaseInOutCubic(Easing.clamp01(timer / duration))
end

function Easing.GetTransitionAlpha(t, direction)
	t = Easing.clamp01(t)

	if direction == 1 then
		return t
	end

	return 1 - t
end

return Easing
