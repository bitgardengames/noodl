local GamepadAliases = {}

GamepadAliases.layouts = {
	xbox = {
		display = {
			a = "A",
			b = "B",
			x = "X",
			y = "Y",
			leftshoulder = "Left Shoulder",
			rightshoulder = "Right Shoulder",
			lefttrigger = "Left Trigger",
			righttrigger = "Right Trigger",
		},
		normalize = {
			a = "a",
			b = "b",
			x = "x",
			y = "y",
			leftshoulder = "leftshoulder",
			rightshoulder = "rightshoulder",
			lefttrigger = "lefttrigger",
			righttrigger = "righttrigger",
		},
		keywords = {"xbox", "xinput"},
		vendorIds = {0x045e},
	},
	playstation = {
		display = {
			a = "Cross",
			b = "Circle",
			x = "Square",
			y = "Triangle",
			leftshoulder = "L1",
			rightshoulder = "R1",
			lefttrigger = "L2",
			righttrigger = "R2",
		},
		normalize = {
			a = "a",
			b = "b",
			x = "x",
			y = "y",
			cross = "a",
			circle = "b",
			square = "x",
			triangle = "y",
			leftshoulder = "leftshoulder",
			rightshoulder = "rightshoulder",
			lefttrigger = "lefttrigger",
			righttrigger = "righttrigger",
			l1 = "leftshoulder",
			r1 = "rightshoulder",
			l2 = "lefttrigger",
			r2 = "righttrigger",
		},
		keywords = {
			"playstation",
			"dualshock",
			"dualsense",
			"sony",
			"ps4",
			"ps5",
			"ps3",
			"wireless controller",
		},
		vendorIds = {0x054c},
	},
}

GamepadAliases.actionButtons = {
	dash = {face = "a", shoulder = "rightshoulder", trigger = "righttrigger"},
}

local DETECTION_ORDER = {"playstation", "xbox"}

local COMMON_ALIASES = {
	cross = "a",
	circle = "b",
	square = "x",
	triangle = "y",
	l1 = "leftshoulder",
	r1 = "rightshoulder",
	l2 = "lefttrigger",
	r2 = "righttrigger",
}

GamepadAliases.activeLayout = "xbox"
GamepadAliases._revision = 0

local function toLower(value)
	if type(value) == "string" then
		return value:lower()
	end
	return value
end

local function matchesVendor(layout, vendorId)
	if not vendorId or not layout.vendorIds then
		return false
	end

	for _, id in ipairs(layout.vendorIds) do
		if id == vendorId then
			return true
		end
	end

	return false
end

local function matchesKeywords(layout, text)
	if not text or text == "" or not layout.keywords then
		return false
	end

	local lowered = text:lower()
	for _, keyword in ipairs(layout.keywords) do
		if lowered:find(keyword, 1, true) then
			return true
		end
	end

	return false
end

local function gatherJoystickMetadata(joystick)
	if not joystick then
		return {}
	end

	local name = toLower(joystick.getName and joystick:getName() or "")
	local guid = toLower(joystick.getGUID and joystick:getGUID() or "")
	local mapping = toLower(joystick.getGamepadMappingString and joystick:getGamepadMappingString() or "")
	local vendor = joystick.getVendorID and joystick:getVendorID()

	local text = table.concat({name or "", guid or "", mapping or ""}, " ")

	return {
		text = text,
		vendor = vendor,
	}
end

function GamepadAliases:getLayout()
	if self.layouts[self.activeLayout] then
		return self.activeLayout
	end

	return "xbox"
end

function GamepadAliases:getLayoutConfig()
	return self.layouts[self:getLayout()] or self.layouts.xbox
end

function GamepadAliases:getRevision()
	return self._revision or 0
end

function GamepadAliases:setLayout(layout)
	if not layout or not self.layouts[layout] then
		return false
	end

	if self.activeLayout ~= layout then
		self.activeLayout = layout
		self._revision = (self._revision or 0) + 1
	end

	return true
end

function GamepadAliases:detectLayout(joystick)
	if not joystick then
		return nil
	end

	local metadata = gatherJoystickMetadata(joystick)

	for _, layoutName in ipairs(DETECTION_ORDER) do
		local layout = self.layouts[layoutName]
		if layout then
			if matchesVendor(layout, metadata.vendor) then
				return layoutName
			end

			if matchesKeywords(layout, metadata.text) then
				return layoutName
			end
		end
	end

	return nil
end

function GamepadAliases:noteJoystick(joystick)
	local detected = self:detectLayout(joystick)
	if detected then
		self:setLayout(detected)
	end
end

function GamepadAliases:refreshLayoutFromJoysticks()
	if not love or not love.joystick or not love.joystick.getJoysticks then
		return
	end

	local fallback = "xbox"
	local detected

	for _, joystick in ipairs(love.joystick.getJoysticks()) do
		local layout = self:detectLayout(joystick)
		if layout then
			detected = layout
			break
		end
	end

	self:setLayout(detected or fallback)
end

function GamepadAliases:handleJoystickRemoved()
	-- When a joystick is removed, rescan the remaining devices to keep the
	-- layout in sync with whatever hardware is still connected.
	self:refreshLayoutFromJoysticks()
end

function GamepadAliases:normalizeButton(button)
	if type(button) ~= "string" then
		return button
	end

	local lowered = button:lower()
	local alias = COMMON_ALIASES[lowered]
	if alias then
		lowered = alias
	end

	local layout = self:getLayoutConfig()
	if layout and layout.normalize then
		local normalized = layout.normalize[lowered]
		if normalized then
			return normalized
		end
	end

	return lowered
end

function GamepadAliases:getButtonDisplayName(button)
	if not button then
		return nil
	end

	local canonical = self:normalizeButton(button)
	local layout = self:getLayoutConfig()
	local display = layout and layout.display

	return (display and display[canonical]) or canonical
end

function GamepadAliases:getActionPromptReplacements(action, prefix)
	prefix = prefix or action
	local mapping = self.actionButtons[action]
	if not mapping then
		return {}
	end

	local replacements = {}
	if mapping.face then
		replacements[prefix .. "_face"] = self:getButtonDisplayName(mapping.face)
	end
	if mapping.shoulder then
		replacements[prefix .. "_shoulder"] = self:getButtonDisplayName(mapping.shoulder)
	end
	if mapping.trigger then
		replacements[prefix .. "_trigger"] = self:getButtonDisplayName(mapping.trigger)
	end

	return replacements
end

function GamepadAliases:getAllPromptReplacements()
	local replacements = {}
	for action in pairs(self.actionButtons) do
		local actionReplacements = self:getActionPromptReplacements(action)
		for key, value in pairs(actionReplacements) do
			replacements[key] = value
		end
	end

	return replacements
end

return GamepadAliases
