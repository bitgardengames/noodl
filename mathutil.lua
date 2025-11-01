local MathUtil = {}

function MathUtil.clamp(value, minimum, maximum)
        if minimum ~= nil and value < minimum then
                return minimum
        end

        if maximum ~= nil and value > maximum then
                return maximum
        end

        return value
end

function MathUtil.clamp01(value)
        return MathUtil.clamp(value, 0, 1)
end

function MathUtil.lerp(fromValue, toValue, alpha)
        return fromValue + (toValue - fromValue) * alpha
end

function MathUtil.inverseLerp(rangeStart, rangeEnd, value)
        if rangeStart == rangeEnd then
                return 0
        end

        return (value - rangeStart) / (rangeEnd - rangeStart)
end

return MathUtil
