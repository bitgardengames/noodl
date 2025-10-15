local UI = require("ui")

local ButtonList = {}
ButtonList.__index = ButtonList

local function IsSelectable(button)
	if not button then return false end
	if button.disabled then return false end
	if button.unlocked == false then return false end
	if button.selectable == false then return false end
	return true
end

function ButtonList.new()
	return setmetatable({buttons = {}, FocusIndex = nil, FocusSource = nil, LastNonMouseFocusIndex = nil}, ButtonList)
end

function ButtonList:reset(definitions)
	self.buttons = {}
	self.FocusIndex = nil
	self.FocusSource = nil
	self.LastNonMouseFocusIndex = nil

	for index, definition in ipairs(definitions or {}) do
		local button = {}
		for key, value in pairs(definition) do
			button[key] = value
		end

		button.id = button.id or button.action or button.text or button.label or ("button" .. index)
		button.text = button.text or button.label or button.id
		button.w = button.w or UI.spacing.ButtonWidth
		button.h = button.h or UI.spacing.ButtonHeight
		button.x = button.x or 0
		button.y = button.y or 0
		button.hoveredByMouse = false

		self.buttons[#self.buttons + 1] = button
	end

	self:FocusFirst()
	-- Avoid treating the initial focus as a non-mouse selection so that
	-- the UI can clear focus when the cursor leaves the buttons before any
	-- keyboard/controller input has occurred.
	self.LastNonMouseFocusIndex = nil

	return self.buttons
end

function ButtonList:iter()
	return ipairs(self.buttons)
end

function ButtonList:UpdateFocusVisuals()
	for index, button in ipairs(self.buttons) do
		local focused = (self.FocusIndex == index)
		button.focused = focused
		button.hovered = focused or button.hoveredByMouse or false
		UI.SetButtonFocus(button.id, focused)
	end
end

function ButtonList:SetFocus(index, source, SkipNonMouseHistory)
	if not index or not self.buttons[index] then return end

	self.FocusIndex = index
	self.FocusSource = source or "programmatic"
	if self.FocusSource ~= "mouse" and not SkipNonMouseHistory then
		self.LastNonMouseFocusIndex = index
	end
	self:UpdateFocusVisuals()

	return self.buttons[index]
end

function ButtonList:ClearFocus()
	self.FocusIndex = nil
	self.FocusSource = nil
	self.LastNonMouseFocusIndex = nil
	self:UpdateFocusVisuals()
end

function ButtonList:FocusFirst()
	for index, button in ipairs(self.buttons) do
		if IsSelectable(button) then
			return self:SetFocus(index, nil, true)
		end
	end

	if #self.buttons > 0 then
		return self:SetFocus(1, nil, true)
	end
end

function ButtonList:MoveFocus(delta)
	if not delta or delta == 0 or #self.buttons == 0 then return end

	local index = self.FocusIndex or 0
	for _ = 1, #self.buttons do
		index = ((index - 1 + delta) % #self.buttons) + 1
		if IsSelectable(self.buttons[index]) then
			return self:SetFocus(index)
		end
	end
end

function ButtonList:GetFocused()
	if not self.FocusIndex then return nil end
	return self.buttons[self.FocusIndex]
end

function ButtonList:SyncUI()
	for _, button in ipairs(self.buttons) do
		UI.RegisterButton(button.id, button.x, button.y, button.w, button.h, button.text)
	end
end

function ButtonList:draw()
	self:SyncUI()
	for _, button in ipairs(self.buttons) do
		UI.DrawButton(button.id)
	end
end

function ButtonList:UpdateHover(mx, my)
	local hovered
	local HoveredIndex

	for index, button in ipairs(self.buttons) do
		local IsHover = UI.IsHovered(button.x, button.y, button.w, button.h, mx, my)
		button.hoveredByMouse = IsHover
		if IsHover then
			hovered = button
			HoveredIndex = index
		end
	end

	if HoveredIndex then
		self:SetFocus(HoveredIndex, "mouse")
	else
		if self.FocusSource == "mouse" then
			if self.LastNonMouseFocusIndex and self.buttons[self.LastNonMouseFocusIndex] then
				self:SetFocus(self.LastNonMouseFocusIndex)
			else
				self:ClearFocus()
			end
		else
			self:UpdateFocusVisuals()
		end
	end

	return hovered
end

function ButtonList:mousepressed(x, y, button)
	local id = UI:mousepressed(x, y, button)
	if not id then return end

	for index, entry in ipairs(self.buttons) do
		if entry.id == id then
			self:SetFocus(index)
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

function ButtonList:ActivateFocused()
	local button = self:GetFocused()
	if not button then return end

	if not IsSelectable(button) then
		return nil, button
	end

	return button.action or button.id, button
end

return ButtonList
