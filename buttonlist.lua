local UI = require("ui")

local ButtonList = {}
ButtonList.__index = ButtonList

local function isSelectable(button)
	if not button then return false end
	if button.disabled then return false end
	if button.unlocked == false then return false end
	if button.selectable == false then return false end
	return true
end

function ButtonList.new()
	return setmetatable({buttons = {}, focusIndex = nil}, ButtonList)
end

function ButtonList:reset(definitions)
	self.buttons = {}
	self.focusIndex = nil

	for index, definition in ipairs(definitions or {}) do
		local button = {}
		for key, value in pairs(definition) do
			button[key] = value
		end

		button.id = button.id or button.action or button.text or button.label or ("button" .. index)
		button.text = button.text or button.label or button.id
		button.w = button.w or UI.spacing.buttonWidth
		button.h = button.h or UI.spacing.buttonHeight
		button.x = button.x or 0
		button.y = button.y or 0
		button.hoveredByMouse = false

		self.buttons[#self.buttons + 1] = button
	end

	self:focusFirst()

	return self.buttons
end

function ButtonList:iter()
	return ipairs(self.buttons)
end

function ButtonList:updateFocusVisuals()
	for index, button in ipairs(self.buttons) do
		local focused = (self.focusIndex == index)
		button.focused = focused
		button.hovered = focused or button.hoveredByMouse or false
		UI.setButtonFocus(button.id, focused)
	end
end

function ButtonList:setFocus(index)
	if not index or not self.buttons[index] then return end

	self.focusIndex = index
	self:updateFocusVisuals()

	return self.buttons[index]
end

function ButtonList:focusFirst()
	for index, button in ipairs(self.buttons) do
		if isSelectable(button) then
			return self:setFocus(index)
		end
	end

	if #self.buttons > 0 then
		return self:setFocus(1)
	end
end

function ButtonList:moveFocus(delta)
	if not delta or delta == 0 or #self.buttons == 0 then return end

	local index = self.focusIndex or 0
	for _ = 1, #self.buttons do
		index = ((index - 1 + delta) % #self.buttons) + 1
		if isSelectable(self.buttons[index]) then
			return self:setFocus(index)
		end
	end
end

function ButtonList:getFocused()
	if not self.focusIndex then return nil end
	return self.buttons[self.focusIndex]
end

function ButtonList:syncUI()
	for _, button in ipairs(self.buttons) do
		UI.registerButton(button.id, button.x, button.y, button.w, button.h, button.text)
	end
end

function ButtonList:draw()
	self:syncUI()
	for _, button in ipairs(self.buttons) do
		UI.drawButton(button.id)
	end
end

function ButtonList:updateHover(mx, my)
	local hovered
	local hoveredIndex

	for index, button in ipairs(self.buttons) do
		local isHover = UI.isHovered(button.x, button.y, button.w, button.h, mx, my)
		button.hoveredByMouse = isHover
		if isHover then
			hovered = button
			hoveredIndex = index
		end
	end

	if hoveredIndex then
		self:setFocus(hoveredIndex)
	else
		self:updateFocusVisuals()
	end

	return hovered
end

function ButtonList:mousepressed(x, y, button)
	local id = UI:mousepressed(x, y, button)
	if not id then return end

	for index, entry in ipairs(self.buttons) do
		if entry.id == id then
			self:setFocus(index)
			break
		end
	end

	return id
end

function ButtonList:mousereleased(x, y, button)
	local id = UI:mousereleased(x, y, button)
	if not id then return end

	for _, entry in ipairs(self.buttons) do
		if entry.id == id then
			return entry.action or entry.id, entry
		end
	end
end

function ButtonList:activateFocused()
	local button = self:getFocused()
	if not button then return end

	if not isSelectable(button) then
		return nil, button
	end

	return button.action or button.id, button
end

return ButtonList
