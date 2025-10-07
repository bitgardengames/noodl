local Localization = require("localization")

local FloorStory = {}

local function deepCopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = deepCopy(value)
    end
    return copy
end

function FloorStory:reset()
    self.state = {
        choices = {},
        history = {},
    }
end

function FloorStory:_ensureState()
    if not self.state then
        self:reset()
    end
    return self.state
end

local function resolveText(node)
    if not node then
        return ""
    end

    if node.text then
        return node.text
    end

    if not node.key then
        return ""
    end

    local replacements
    if node.replacements then
        replacements = {}
        for key, value in pairs(node.replacements) do
            replacements[key] = value
        end
    end

    return Localization:get(node.key, replacements)
end

local function resolveSpeaker(node)
    if not node then
        return ""
    end

    if node.speaker then
        return node.speaker
    end

    if node.speakerKey then
        return Localization:get(node.speakerKey)
    end

    return ""
end

local function valuesInclude(list, value)
    if type(list) ~= "table" then
        return list == value
    end

    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end

    return false
end

function FloorStory:_conditionsMet(when)
    if not when then
        return true
    end

    local state = self:_ensureState()
    local choices = state.choices

    if when.choiceEquals then
        for id, expected in pairs(when.choiceEquals) do
            local selected = choices[id]
            if not valuesInclude(expected, selected) then
                return false
            end
        end
    end

    if when.choiceTaken then
        local required = when.choiceTaken
        local satisfied = false
        for _, selected in pairs(choices) do
            if valuesInclude(required, selected) then
                satisfied = true
                break
            end
        end
        if not satisfied then
            return false
        end
    end

    if when.choiceMissing then
        local id = when.choiceMissing
        if choices[id] ~= nil then
            return false
        end
    end

    return true
end

local function normalizeLines(lines, story)
    if not lines or #lines == 0 then
        return {}
    end

    local resolved = {}
    for _, spec in ipairs(lines) do
        if story:_conditionsMet(spec.when) then
            resolved[#resolved + 1] = {
                speaker = resolveSpeaker(spec),
                text = resolveText(spec),
                key = spec.key,
                duration = spec.duration,
            }
        end
    end

    return resolved
end

local function normalizeChoiceOptions(options, story)
    if not options or #options == 0 then
        return {}
    end

    local filtered = {}
    for _, option in ipairs(options) do
        if story:_conditionsMet(option.when) then
            filtered[#filtered + 1] = option
        end
    end
    return filtered
end

function FloorStory:startFloor(floorNum, floorData)
    local state = self:_ensureState()
    local storySpec = floorData and floorData.story
    local info = {
        floor = floorNum,
        lines = {},
        choice = nil,
    }

    if not storySpec then
        state.history[floorNum] = nil
        return info
    end

    info.lines = normalizeLines(storySpec.lines, self)

    if storySpec.choice then
        local choiceId = storySpec.choice.id or ("floor_" .. tostring(floorNum))
        local options = normalizeChoiceOptions(storySpec.choice.options, self)
        if #options > 0 then
            info.choice = {
                id = choiceId,
                title = storySpec.choice.title,
                prompt = storySpec.choice.prompt,
                options = deepCopy(options),
                selected = state.choices[choiceId],
            }
        end
    end

    state.history[floorNum] = storySpec.historyTag or true
    return info
end

function FloorStory:selectChoice(choiceId, optionId)
    local state = self:_ensureState()
    state.choices[choiceId] = optionId
end

function FloorStory:getChoice(choiceId)
    local state = self:_ensureState()
    return state.choices[choiceId]
end

function FloorStory:choiceSelected(optionId)
    local state = self:_ensureState()
    for _, selected in pairs(state.choices) do
        if selected == optionId then
            return true
        end
    end
    return false
end

return FloorStory
