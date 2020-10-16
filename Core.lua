local AngryNotes = LibStub("AceAddon-3.0"):NewAddon("AngryNotes", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local lwin = LibStub("LibWindow-1.1")
local LSM = LibStub("LibSharedMedia-3.0")

BINDING_HEADER_AngryNotes = "Angry Notes"
BINDING_NAME_AngryNotes_WINDOW = "Toggle Window"
BINDING_NAME_AngryNotes_LOCK = "Toggle Lock"
BINDING_NAME_AngryNotes_DISPLAY = "Toggle Display"
BINDING_NAME_AngryNotes_OUTPUT = "Output Note to Chat"

local AngryNotes_Version = '@project-version@'
local AngryNotes_Timestamp = '@project-date-integer@'

local currentGroup = nil

-- Pages Saved Variable Format 
-- 	AngryNotes_Pages = {
-- 		[Id] = { Id = "1231", Name = "Name", Contents = "...", CategoryId = 123 },
--		...
-- 	}
-- 	AngryNotes_Categories = {
-- 		[Id] = { Id = "1231", Name = "Name", CategoryId = 123 },
--		...
-- 	}

-----------------------
-- Utility Functions --
-----------------------

local function selectedLastValue(input)
	local a = select(-1, strsplit("", input or ""))
	return tonumber(a)
end

local function tReverse(tbl)
	for i=1, math.floor(#tbl / 2) do
		tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
	end
end

local _player_realm = nil
local function EnsureUnitFullName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	if unit and not unit:find('-') then
		unit = unit..'-'.._player_realm
	end
	return unit
end

local function EnsureUnitShortName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	local name, realm = strsplit("-", unit, 2)
	if not realm or realm == _player_realm then
		return name
	else
		return unit
	end
end

local function PlayerFullName()
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	return UnitName('player')..'-'.._player_realm
end

local function RGBToHex(r, g, b, a)
	r = math.ceil(255 * r)
	g = math.ceil(255 * g)
	b = math.ceil(255 * b)
	if a == nil then
		return string.format("%02x%02x%02x", r, g, b)
	else
		a = math.ceil(255 * a)
		return string.format("%02x%02x%02x%02x", r, g, b, a)
	end
end

local function HexToRGB(hex)
	if string.len(hex) == 8 then
		return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255, tonumber("0x"..hex:sub(7,8)) / 255
	else
		return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255
	end
end

-------------------------
-- Addon Communication --
-------------------------

function AngryNotes:GetCurrentGroup()
	local player = PlayerFullName()
	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if EnsureUnitFullName(name) == player then
				return subgroup
			end
		end
	end
	return nil
end

--------------------------
-- Editing Pages Window --
--------------------------

function AngryNotes_ToggleWindow()
	if not AngryNotes.window then AngryNotes:CreateWindow() end
	if AngryNotes.window:IsShown() then 
		AngryNotes.window:Hide() 
	else
		AngryNotes.window:Show() 
	end
end

function AngryNotes_ToggleLock()
	AngryNotes:ToggleLock()
end

local function AngryNotes_AddPage(widget, event, value)
	local popup_name = "AngryNotes_AddPage"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				if text ~= "" then AngryNotes:CreatePage(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				if text ~= "" then AngryNotes:CreatePage(text) end
				self:GetParent():Hide()
			end,
			text = "New page name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngryNotes_RenamePage(pageId)
	local page = AngryNotes:Get(pageId)
	if not page then return end

	local popup_name = "AngryNotes_RenamePage_"..page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngryNotes:RenamePage(page.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngryNotes:RenamePage(page.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				self.editBox:SetText(page.Name)
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename page "'.. page.Name ..'" to:'

	StaticPopup_Show(popup_name)
end

local function AngryNotes_DeletePage(pageId)
	local page = AngryNotes:Get(pageId)
	if not page then return end

	local popup_name = "AngryNotes_DeletePage_"..page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngryNotes:DeletePage(page.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete page "'.. page.Name ..'"?'

	StaticPopup_Show(popup_name)
end

local function AngryNotes_AddCategory(widget, event, value)
	local popup_name = "AngryNotes_AddCategory"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				if text ~= "" then AngryNotes:CreateCategory(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				if text ~= "" then AngryNotes:CreateCategory(text) end
				self:GetParent():Hide()
			end,
			text = "New category name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngryNotes_RenameCategory(catId)
	local cat = AngryNotes:GetCat(catId)
	if not cat then return end

	local popup_name = "AngryNotes_RenameCategory_"..cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngryNotes:RenameCategory(cat.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngryNotes:RenameCategory(cat.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				self.editBox:SetText(cat.Name)
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename category "'.. cat.Name ..'" to:'

	StaticPopup_Show(popup_name)
end

local function AngryNotes_DeleteCategory(catId)
	local cat = AngryNotes:GetCat(catId)
	if not cat then return end

	local popup_name = "AngryNotes_DeleteCategory_"..cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngryNotes:DeleteCategory(cat.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete category "'.. cat.Name ..'"?'

	StaticPopup_Show(popup_name)
end

local function AngryNotes_AssignCategory(frame, entryId, catId)
	HideDropDownMenu(1)

	AngryNotes:AssignCategory(entryId, catId)
end

local function AngryNotes_RevertPage(widget, event, value)
	if not AngryNotes.window then return end
	AngryNotes:UpdateSelected(true)
end

function AngryNotes:DisplayPageByName( name )
	for id, page in pairs(AngryNotes_Pages) do
		if page.Name == name then
			return self:DisplayPage( id )
		end
	end
	return false
end

function AngryNotes:DisplayPage( id )
	
	if AngryNotes_State.displayed ~= id then
		AngryNotes_State.displayed = id
		AngryNotes:UpdateDisplayed()
		AngryNotes:ShowDisplay()
		AngryNotes:UpdateTree()
	end
	
	return true
end

local function AngryNotes_DisplayPage(widget, event, value)
	local id = AngryNotes:SelectedId()
	AngryNotes:DisplayPage( id )
end

local function AngryNotes_ClearPage(widget, event, value)
	AngryNotes:ClearDisplayed()
end

local function AngryNotes_TextChanged(widget, event, value)
	AngryNotes.window.button_revert:SetDisabled(false)
	AngryNotes.window.button_display:SetDisabled(true)
	AngryNotes.window.button_output:SetDisabled(true)
end

local function AngryNotes_TextEntered(widget, event, value)
	AngryNotes:UpdateContents(AngryNotes:SelectedId(), value)
end

local function AngryNotes_CategoryMenuList(entryId, parentId)
	local categories = {}

	local checkedId
	if entryId > 0 then
		local page = AngryNotes_Pages[entryId]
		checkedId = page.CategoryId
	else
		local cat = AngryNotes_Categories[-entryId]
		checkedId = cat.CategoryId
	end

	for _, cat in pairs(AngryNotes_Categories) do
		if cat.Id ~= -entryId and (parentId or not cat.CategoryId) and (not parentId or cat.CategoryId == parentId) then 
			local subMenu = AngryNotes_CategoryMenuList(entryId, cat.Id)
			table.insert(categories, { text = cat.Name, value = cat.Id, menuList = subMenu, hasArrow = (subMenu ~= nil), checked = (checkedId == cat.Id), func = AngryNotes_AssignCategory, arg1 = entryId, arg2 = cat.Id })
		end
	end

	table.sort(categories, function(a,b) return a.text < b.text end)

	if #categories > 0 then
		return categories
	end
end

local PagesDropDownList
function AngryNotes_PageMenu(pageId)
	local page = AngryNotes_Pages[pageId]
	if not page then return end

	if not PagesDropDownList then
		PagesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename", notCheckable = true, func = function(frame, pageId) AngryNotes_RenamePage(pageId) end },
			{ text = "Delete", notCheckable = true, func = function(frame, pageId) AngryNotes_DeletePage(pageId) end },
			{ text = "Category", notCheckable = true, hasArrow = true },
		}
	end

	PagesDropDownList[1].text = page.Name
	PagesDropDownList[2].arg1 = pageId
	PagesDropDownList[3].arg1 = pageId

	local categories = AngryNotes_CategoryMenuList(pageId)
	if categories ~= nil then
		PagesDropDownList[4].menuList = categories
		PagesDropDownList[4].disabled = false
	else
		PagesDropDownList[4].menuList = {}
		PagesDropDownList[4].disabled = true
	end
	return PagesDropDownList
end

local CategoriesDropDownList
local function AngryNotes_CategoryMenu(catId)
	local cat = AngryNotes_Categories[catId]
	if not cat then return end

	if not CategoriesDropDownList then
		CategoriesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename", notCheckable = true, func = function(frame, pageId) AngryNotes_RenameCategory(pageId) end },
			{ text = "Delete", notCheckable = true, func = function(frame, pageId) AngryNotes_DeleteCategory(pageId) end },
			{ text = "Category", notCheckable = true, hasArrow = true },
		}
	end
	CategoriesDropDownList[1].text = cat.Name
	CategoriesDropDownList[2].arg1 = catId
	CategoriesDropDownList[3].arg1 = catId

	local categories = AngryNotes_CategoryMenuList(-catId)
	if categories ~= nil then
		CategoriesDropDownList[4].menuList = categories
		CategoriesDropDownList[4].disabled = false
	else
		CategoriesDropDownList[4].menuList = {}
		CategoriesDropDownList[4].disabled = true
	end

	return CategoriesDropDownList
end

local AngryNotes_DropDown
local function AngryNotes_TreeClick(widget, event, value, selected, button)
	HideDropDownMenu(1)
	local selectedId = selectedLastValue(value)
	if selectedId < 0 then
		if button == "RightButton" then
			if not AngryNotes_DropDown then
				AngryNotes_DropDown = CreateFrame("Frame", "AngryNotesMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngryNotes_CategoryMenu(-selectedId), AngryNotes_DropDown, "cursor", 0 , 0, "MENU")

		else
			local status = (widget.status or widget.localstatus).groups
			status[value] = not status[value]
			widget:RefreshTree()
		end
		return false
	else
		if button == "RightButton" then
			if not AngryNotes_DropDown then
				AngryNotes_DropDown = CreateFrame("Frame", "AngryNotesMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngryNotes_PageMenu(selectedId), AngryNotes_DropDown, "cursor", 0 , 0, "MENU")

			return false
		end
	end
end

function AngryNotes:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Notes")
	window:SetStatusText("")
	window:SetLayout("Flow")
	if AngryNotes:GetConfig('scale') then window.frame:SetScale( AngryNotes:GetConfig('scale') ) end
	window:SetStatusTable(AngryNotes_State.window)
	window:Hide()
	AngryNotes.window = window

	AngryNotes_Window = window.frame
	window.frame:SetMinResize(700, 400)
	window.frame:SetFrameStrata("HIGH")
	window.frame:SetFrameLevel(1)
	tinsert(UISpecialFrames, "AngryNotes_Window")

	local tree = AceGUI:Create("AngryTreeGroup")
	tree:SetTree( self:GetTree() )
	tree:SelectByValue(1)
	tree:SetStatusTable(AngryNotes_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	tree:SetCallback("OnGroupSelected", function(widget, event, value) AngryNotes:UpdateSelected(true) end)
	tree:SetCallback("OnClick", AngryNotes_TreeClick)
	window:AddChild(tree)
	window.tree = tree

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetCallback("OnTextChanged", AngryNotes_TextChanged)
	text:SetCallback("OnEnterPressed", AngryNotes_TextEntered)
	tree:AddChild(text)
	window.text = text
	text.button:SetWidth(75)
	local buttontext = text.button:GetFontString()
	buttontext:ClearAllPoints()
	buttontext:SetPoint("TOPLEFT", text.button, "TOPLEFT", 15, -1)
	buttontext:SetPoint("BOTTOMRIGHT", text.button, "BOTTOMRIGHT", -15, 1)

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Display")
	button_display:SetWidth(100)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 4)
	button_display:SetCallback("OnClick", AngryNotes_DisplayPage)
	tree:AddChild(button_display)
	window.button_display = button_display

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(80)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	button_revert:SetCallback("OnClick", AngryNotes_RevertPage)
	tree:AddChild(button_revert)
	window.button_revert = button_revert
	
	local button_output = AceGUI:Create("Button")
	button_output:SetText("Output")
	button_output:SetWidth(80)
	button_output:SetHeight(22)
	button_output:ClearAllPoints()
	button_output:SetPoint("BOTTOMRIGHT", button_display.frame, "BOTTOMLEFT", -6, 0)
	button_output:SetCallback("OnClick", AngryNotes_OutputDisplayed)
	tree:AddChild(button_output)
	window.button_output = button_output

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("Add")
	button_add:SetWidth(80)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 17, 18)
	button_add:SetCallback("OnClick", AngryNotes_AddPage)
	window:AddChild(button_add)
	window.button_add = button_add

	local button_rename = AceGUI:Create("Button")
	button_rename:SetText("Rename")
	button_rename:SetWidth(80)
	button_rename:SetHeight(19)
	button_rename:ClearAllPoints()
	button_rename:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	button_rename:SetCallback("OnClick", function() AngryNotes_RenamePage() end)
	window:AddChild(button_rename)
	window.button_rename = button_rename

	local button_delete = AceGUI:Create("Button")
	button_delete:SetText("Delete")
	button_delete:SetWidth(80)
	button_delete:SetHeight(19)
	button_delete:ClearAllPoints()
	button_delete:SetPoint("BOTTOMLEFT", button_rename.frame, "BOTTOMRIGHT", 5, 0)
	button_delete:SetCallback("OnClick", function() AngryNotes_DeletePage() end)
	window:AddChild(button_delete)
	window.button_delete = button_delete

	local button_add_cat = AceGUI:Create("Button")
	button_add_cat:SetText("Add Category")
	button_add_cat:SetWidth(120)
	button_add_cat:SetHeight(19)
	button_add_cat:ClearAllPoints()
	button_add_cat:SetPoint("BOTTOMLEFT", button_delete.frame, "BOTTOMRIGHT", 5, 0)
	button_add_cat:SetCallback("OnClick", function() AngryNotes_AddCategory() end)
	window:AddChild(button_add_cat)
	window.button_add_cat = button_add_cat

	local button_clear = AceGUI:Create("Button")
	button_clear:SetText("Clear")
	button_clear:SetWidth(80)
	button_clear:SetHeight(19)
	button_clear:ClearAllPoints()
	button_clear:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	button_clear:SetCallback("OnClick", AngryNotes_ClearPage)
	window:AddChild(button_clear)
	window.button_clear = button_clear

	self:UpdateSelected(true)
	self:UpdateMedia()
	
	--self:CreateIconPicker()
end

local function GetTree_InsertPage(tree, page)
	if page.Id == AngryNotes_State.displayed then
		table.insert(tree, { value = page.Id, text = page.Name, icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up" })
	else
		table.insert(tree, { value = page.Id, text = page.Name })
	end
end

local function GetTree_InsertChildren(categoryId, displayedPages)
	local tree = {}
	for _, cat in pairs(AngryNotes_Categories) do
		if cat.CategoryId == categoryId then
			table.insert(tree, { value = -cat.Id, text = cat.Name, children = GetTree_InsertChildren(cat.Id, displayedPages) })
		end
	end

	for _, page in pairs(AngryNotes_Pages) do
		if page.CategoryId == categoryId then
			displayedPages[page.Id] = true
			GetTree_InsertPage(tree, page)
		end
	end

	table.sort(tree, function(a,b) return a.text < b.text end)
	return tree
end

function AngryNotes:GetTree()
	local tree = {}
	local displayedPages = {}

	for _, cat in pairs(AngryNotes_Categories) do
		if not cat.CategoryId then
			table.insert(tree, { value = -cat.Id, text = cat.Name, children = GetTree_InsertChildren(cat.Id, displayedPages) })
		end
	end

	for _, page in pairs(AngryNotes_Pages) do
		if not page.CategoryId or not displayedPages[page.Id] then
			GetTree_InsertPage(tree, page)
		end
	end

	table.sort(tree, function(a,b) return a.text < b.text end)

	return tree
end

function AngryNotes:UpdateTree(id)
	if not self.window then return end
	self.window.tree:SetTree( self:GetTree() )
	if id then
		self:SetSelectedId( id )
	end
end

function AngryNotes:UpdateSelected(destructive)
	if not self.window then return end
	local page = AngryNotes_Pages[ self:SelectedId() ]
	if destructive or not self.window.text.button:IsEnabled() then
		if page then
			self.window.text:SetText( page.Contents )
		else
			self.window.text:SetText("")
		end
		self.window.text.button:Disable()
	end
	if page then
		self.window.button_rename:SetDisabled(false)
		self.window.button_revert:SetDisabled(not self.window.text.button:IsEnabled())
		self.window.button_display:SetDisabled(false)
		self.window.button_output:SetDisabled(false)
		self.window.text:SetDisabled(false)
	else
		self.window.button_rename:SetDisabled(true)
		self.window.button_revert:SetDisabled(true)
		self.window.button_display:SetDisabled(true)
		self.window.button_output:SetDisabled(true)
		self.window.text:SetDisabled(true)
	end
	if page then
		self.window.button_delete:SetDisabled(false)
	else
		self.window.button_delete:SetDisabled(true)
	end
	self.window.button_add:SetDisabled(false)
	self.window.button_clear:SetDisabled(false)
end

----------------------------------
-- Performing changes functions --
----------------------------------

function AngryNotes:SelectedId()
	return selectedLastValue( AngryNotes_State.tree.selected )
end

function AngryNotes:SetSelectedId(selectedId)
	local page = AngryNotes_Pages[selectedId]
	if page then
		if page.CategoryId then
			local cat = AngryNotes_Categories[page.CategoryId]
			local path = { }
			while cat do
				table.insert(path, -cat.Id)
				if cat.CategoryId then
					cat = AngryNotes_Categories[cat.CategoryId]
				else 
					cat = nil
				end
			end
			tReverse(path)
			table.insert(path, page.Id)
			self.window.tree:SelectByPath(unpack(path))
		else
			self.window.tree:SelectByValue(page.Id)
		end
	else
		self.window.tree:SetSelected()
	end
end

function AngryNotes:Get(id)
	if id == nil then id = self:SelectedId() end
	return AngryNotes_Pages[id]
end

function AngryNotes:GetCat(id)
	return AngryNotes_Categories[id]
end

function AngryNotes:CreatePage(name)
	local id = math.random(2000000000)

	AngryNotes_Pages[id] = { Id = id, Name = name, Contents = "" }
	self:UpdateTree(id)
end

function AngryNotes:RenamePage(id, name)
	local page = self:Get(id)

	page.Name = name

	if AngryNotes_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
	end
end

function AngryNotes:DeletePage(id)
	AngryNotes_Pages[id] = nil
	if self.window and self:SelectedId() == id then
		self:SetSelectedId(nil)
		self:UpdateSelected(true)
	end
	if AngryNotes_State.displayed == id then
		self:ClearDisplayed()
	end
	self:UpdateTree()
end

function AngryNotes:CreateCategory(name)
	local id = math.random(2000000000)

	AngryNotes_Categories[id] = { Id = id, Name = name }

	if AngryNotes_State.tree.groups then
		AngryNotes_State.tree.groups[ -id ] = true
	end
	self:UpdateTree()
end

function AngryNotes:RenameCategory(id, name)
	local cat = self:GetCat(id)
	if not cat then return end

	cat.Name = name

	self:UpdateTree()
end

function AngryNotes:DeleteCategory(id)
	local cat = self:GetCat(id)
	if not cat then return end

	local selectedId = self:SelectedId()

	for _, c in pairs(AngryNotes_Categories) do
		if cat.Id == c.CategoryId then
			c.CategoryId = cat.CategoryId
		end
	end

	for _, p in pairs(AngryNotes_Pages) do
		if cat.Id == p.CategoryId then
			p.CategoryId = cat.CategoryId
		end
	end

	AngryNotes_Categories[id] = nil

	self:UpdateTree()
	self:SetSelectedId(selectedId)
end

function AngryNotes:AssignCategory(entryId, parentId)
	local page, cat
	if entryId > 0 then
		page = self:Get(entryId)
	else
		cat = self:GetCat(-entryId)
	end
	local parent = self:GetCat(parentId)
	if not (page or cat) or not parent then return end

	if page then
		if page.CategoryId == parentId then
			page.CategoryId = nil
		else
			page.CategoryId = parentId
		end
	end

	if cat then
		if cat.CategoryId == parentId then
			cat.CategoryId = nil
		else
			cat.CategoryId = parentId
		end
	end

	local selectedId = self:SelectedId()
	self:UpdateTree()
	if selectedId == entryId then
		self:SetSelectedId( selectedId )
	end
end

function AngryNotes:UpdateContents(id, value)
	local page = self:Get(id)
	if not page then return end

	local new_content = value:gsub('^%s+', ''):gsub('%s+$', '')
	local contents_updated = new_content ~= page.Contents
	page.Contents = new_content

	self:UpdateSelected(true)
	if AngryNotes_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
	end
end

function AngryNotes:ClearDisplayed()
	AngryNotes_State.displayed = nil
	self:UpdateDisplayed()
	self:UpdateTree()
end

-------------
-- Displaying Page --
---------------------

local function DragHandle_MouseDown(frame) frame:GetParent():GetParent():StartSizing("RIGHT") end
local function DragHandle_MouseUp(frame)
	local display = frame:GetParent():GetParent()
	display:StopMovingOrSizing()
	AngryNotes_State.display.width = display:GetWidth()
	lwin.SavePosition(display)
	AngryNotes:UpdateBackdrop()
end
local function Mover_MouseDown(frame) frame:GetParent():StartMoving() end
local function Mover_MouseUp(frame)
	local display = frame:GetParent()
	display:StopMovingOrSizing()
	lwin.SavePosition(display)
end

function AngryNotes:ResetPosition()
	AngryNotes_State.display = {}
	AngryNotes_State.directionUp = false
	AngryNotes_State.locked = false
	
	self.display_text:Show()
	self.mover:Show()
	self.frame:SetWidth(300)
	
	lwin.RegisterConfig(self.frame, AngryNotes_State.display)
	lwin.RestorePosition(self.frame)
	
	self:UpdateDirection()
end

function AngryNotes_ToggleDisplay()
	AngryNotes:ToggleDisplay()
end

function AngryNotes:ShowDisplay()
	self.display_text:Show()
	self:UpdateBackdrop()
	AngryNotes_State.display.hidden = false
end

function AngryNotes:HideDisplay()
	self.display_text:Hide()
	AngryNotes_State.display.hidden = true
end

function AngryNotes:ToggleDisplay()
	if self.display_text:IsShown() then
		self:HideDisplay()
	else
		self:ShowDisplay()
	end
end


function AngryNotes:CreateDisplay()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetPoint("CENTER",0,0)
	frame:SetWidth(AngryNotes_State.display.width or 300)
	frame:SetHeight(1)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetClampedToScreen(true)
	frame:SetMinResize(180,1)
	frame:SetMaxResize(830,1)
	frame:SetFrameStrata("MEDIUM")	
	self.frame = frame

	lwin.RegisterConfig(frame, AngryNotes_State.display)
	lwin.RestorePosition(frame)

	local text = CreateFrame("ScrollingMessageFrame", nil, frame)
	text:SetIndentedWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetFading(false)
	text:SetMaxLines(70)
	text:SetHeight(700)
	text:SetHyperlinksEnabled(false)
	self.display_text = text

	local backdrop = text:CreateTexture()
	backdrop:SetDrawLayer("BACKGROUND")
	self.backdrop = backdrop

	local mover = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mover:SetPoint("LEFT",0,0)
	mover:SetPoint("RIGHT",0,0)
	mover:SetHeight(16)
	mover:EnableMouse(true)
	mover:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	mover:SetBackdropColor( 0.616, 0.149, 0.114, 0.9)
	mover:SetScript("OnMouseDown", Mover_MouseDown)
	mover:SetScript("OnMouseUp", Mover_MouseUp)
	self.mover = mover
	if AngryNotes_State.locked then mover:Hide() end

	local label = mover:CreateFontString()
	label:SetFontObject("GameFontNormal")
	label:SetJustifyH("CENTER")
	label:SetPoint("LEFT", 38, 0)
	label:SetPoint("RIGHT", -38, 0)
	label:SetText("Angry Notes")

	local direction = CreateFrame("Button", nil, mover)
	direction:SetPoint("LEFT", 2, 0)
	direction:SetWidth(16)
	direction:SetHeight(16)
	direction:SetNormalTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetPushedTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	direction:SetScript("OnClick", function() AngryNotes:ToggleDirection() end)
	self.direction_button = direction

	local lock = CreateFrame("Button", nil, mover)
	lock:SetNormalTexture("Interface\\LFGFRAME\\UI-LFG-ICON-LOCK")
	lock:GetNormalTexture():SetTexCoord(0, 0.71875, 0, 0.875)
	lock:SetPoint("LEFT", direction, "RIGHT", 4, 0)
	lock:SetWidth(12)
	lock:SetHeight(14)
	lock:SetScript("OnClick", function() AngryNotes:ToggleLock() end)

	local drag = CreateFrame("Frame", nil, mover)
	drag:SetFrameLevel(mover:GetFrameLevel() + 10)
	drag:SetWidth(16)
	drag:SetHeight(16)
	drag:SetPoint("BOTTOMRIGHT", 0, 0)
	drag:EnableMouse(true)
	drag:SetScript("OnMouseDown", DragHandle_MouseDown)
	drag:SetScript("OnMouseUp", DragHandle_MouseUp)
	drag:SetAlpha(0.5)
	local dragtex = drag:CreateTexture(nil, "OVERLAY")
	dragtex:SetTexture("Interface\\AddOns\\AngryNotes\\Textures\\draghandle")
	dragtex:SetWidth(16)
	dragtex:SetHeight(16)
	dragtex:SetBlendMode("ADD")
	dragtex:SetPoint("CENTER", drag)

	if AngryNotes_State.display.hidden then text:Hide() end
	self:UpdateMedia()
	self:UpdateDirection()
end

function AngryNotes:ToggleLock()
	AngryNotes_State.locked = not AngryNotes_State.locked
	if AngryNotes_State.locked then
		self.mover:Hide()
	else
		self.mover:Show()
	end
end

function AngryNotes:ToggleDirection()
	AngryNotes_State.directionUp = not AngryNotes_State.directionUp
	self:UpdateDirection()
end

function AngryNotes:UpdateDirection()
	if AngryNotes_State.directionUp then
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("BOTTOMLEFT", 0, 8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)
	else
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("TOPLEFT", 0, -8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0, 0.5)
	end
	if self.display_text:IsShown() then
		self.display_text:Hide()
		self.display_text:Show()
	end
	self:UpdateDisplayed()
end

function AngryNotes:UpdateBackdrop()
	local first, last
	for lineIndex, visibleLine in ipairs(self.display_text.visibleLines) do
		local messageInfo = self.display_text.historyBuffer:GetEntryAtIndex(lineIndex)
		if messageInfo then
			if not first then first = visibleLine end
			last = visibleLine
		end
	end

	if first and last and self:GetConfig('backdropShow') then
		self.backdrop:ClearAllPoints()
		if AngryNotes_State.directionUp then
			self.backdrop:SetPoint("TOPLEFT", last, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", 4, -4)
		else
			self.backdrop:SetPoint("TOPLEFT", first, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 4, -4)
		end
		self.backdrop:SetColorTexture( HexToRGB(self:GetConfig('backdropColor')) )
		self.backdrop:Show()
	else
		self.backdrop:Hide()
	end
end

local editFontName, editFontHeight, editFontFlags
function AngryNotes:UpdateMedia()
	local fontName = LSM:Fetch("font", AngryNotes:GetConfig('fontName'))
	local fontHeight = AngryNotes:GetConfig('fontHeight')
	local fontFlags = AngryNotes:GetConfig('fontFlags')
	
	self.display_text:SetTextColor( HexToRGB(self:GetConfig('color')) )
	self.display_text:SetFont(fontName, fontHeight, fontFlags)
	self.display_text:SetSpacing( AngryNotes:GetConfig('lineSpacing') )

	if self.window then
		if self:GetConfig('editBoxFont') then
			if not editFontName then
				editFontName, editFontHeight, editFontFlags = self.window.text.editBox:GetFont()
			end
			self.window.text.editBox:SetFont(fontName, fontHeight, fontFlags)
		elseif editFontName then
			self.window.text.editBox:SetFont(editFontName, editFontHeight, editFontFlags)
		end
	end

	self:UpdateBackdrop()
end

local function ci_pattern(pattern)
	local p = pattern:gsub("(%%?)(.)", function(percent, letter)
		if percent ~= "" or not letter:match("%a") then
			return percent .. letter
		else
			return string.format("[%s%s]", letter:lower(), letter:upper())
		end
	end)
	return p
end

function AngryNotes:UpdateDisplayedIfNewGroup()
	local newGroup = self:GetCurrentGroup()
	if newGroup ~= currentGroup then
		currentGroup = newGroup
		self:UpdateDisplayed()
	end
end

function AngryNotes:UpdateDisplayed()
	local page = AngryNotes_Pages[ AngryNotes_State.displayed ]
	if page then
		local text = page.Contents

		local highlights = { }
		for token in string.gmatch( AngryNotes:GetConfig('highlight') , "[^%s%p]+") do
			token = token:lower()
			if token == 'group'then
				tinsert(highlights, 'g'..(currentGroup or 0))
			else
				tinsert(highlights, token)
			end
		end
		local highlightHex = self:GetConfig('highlightColor')
		
		text = text:gsub("||", "|")
			:gsub(ci_pattern('|cblue'), "|cff00cbf4")
			:gsub(ci_pattern('|cgreen'), "|cff0adc00")
			:gsub(ci_pattern('|cred'), "|cffeb310c")
			:gsub(ci_pattern('|cyellow'), "|cfffaf318")
			:gsub(ci_pattern('|corange'), "|cffff9d00")
			:gsub(ci_pattern('|cpink'), "|cfff64c97")
			:gsub(ci_pattern('|cpurple'), "|cffdc44eb")
			:gsub(ci_pattern('|cdeathknight'), "|cffc41f3b")
			:gsub(ci_pattern('|cdruid'), "|cffff7d0a")
			:gsub(ci_pattern('|chunter'), "|cffabd473")
			:gsub(ci_pattern('|cmage'), "|cff69ccf0")
			:gsub(ci_pattern('|cmonk'), "|cff00ff96")
			:gsub(ci_pattern('|cpaladin'), "|cfff58cba")
			:gsub(ci_pattern('|cpriest'), "|cffffffff")
			:gsub(ci_pattern('|crogue'), "|cfffff569")
			:gsub(ci_pattern('|cshaman'), "|cff0070de")
			:gsub(ci_pattern('|cwarlock'), "|cff9482c9")
			:gsub(ci_pattern('|cwarrior'), "|cffc79c6e")
			:gsub(ci_pattern('|cdemonhunter'), "|cffa330c9")
			:gsub("([^%s%p]+)", function(word)
				local word_lower = word:lower()
				for _, token in ipairs(highlights) do
					if token == word_lower then
						return string.format("|cff%s%s|r", highlightHex, word)
					end
				end
				return word
			end)
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
				return select(5, EJ_GetEncounterInfo(id))
			end)
			:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
				return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{rt([1-8])}'), "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t" )
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), "|TInterface\\Icons\\INV_Stone_04:0|t")
			:gsub(ci_pattern('{bloodlust}'), "{bl}")
			:gsub(ci_pattern('{bl}'), "|TInterface\\Icons\\SPELL_Nature_Bloodlust:0|t")
			:gsub(ci_pattern('{icon%s+(%d+)}'), function(id)
				return format("|T%s:0|t", select(3, GetSpellInfo(tonumber(id))) )
			end)
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), "|TInterface\\Icons\\%1:0|t")
			:gsub(ci_pattern('{damage}'), "{dps}")
			:gsub(ci_pattern('{tank}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t")
			:gsub(ci_pattern('{healer}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t")
			:gsub(ci_pattern('{dps}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t")
			:gsub(ci_pattern('{hero}'), "{heroism}")
			:gsub(ci_pattern('{heroism}'), "|TInterface\\Icons\\ABILITY_Shaman_Heroism:0|t")
			:gsub(ci_pattern('{hunter}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:16:32|t")
			:gsub(ci_pattern('{warrior}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:0:16|t")
			:gsub(ci_pattern('{rogue}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:0:16|t")
			:gsub(ci_pattern('{mage}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:0:16|t")
			:gsub(ci_pattern('{priest}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:16:32|t")
			:gsub(ci_pattern('{warlock}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:16:32|t")
			:gsub(ci_pattern('{paladin}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:32:48|t")
			:gsub(ci_pattern('{deathknight}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:32:48|t")
			:gsub(ci_pattern('{druid}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:0:16|t")
			:gsub(ci_pattern('{monk}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:32:48|t")
			:gsub(ci_pattern('{shaman}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:16:32|t")
			:gsub(ci_pattern('{demonhunter}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:64:48:32:48|t")

		self.display_text:Clear()
		local lines = { strsplit("\n", text) }
		local lines_count = #lines
		for i = 1, lines_count do
			local line
			if AngryNotes_State.directionUp then
				line = lines[i]
			else 
				line = lines[lines_count - i + 1]
			end
			if line == "" then line = " " end
			self.display_text:AddMessage(line)
		end
	else
		self.display_text:Clear()
	end
	self:UpdateBackdrop()
end

function AngryNotes_OutputDisplayed()
	return AngryNotes:OutputDisplayed( AngryNotes:SelectedId() )
end
function AngryNotes:OutputDisplayed(id)
	if not id then id = AngryNotes_State.displayed end
	local page = AngryNotes_Pages[ id ]
	local channel
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		channel = "INSTANCE_CHAT"
	elseif IsInRaid() then
		channel = "RAID"
	elseif IsInGroup() then
		channel = "PARTY"
	end
	if channel and page then
		local output = page.Contents

		output = output:gsub("||", "|")
			:gsub(ci_pattern('|r'), "")
			:gsub(ci_pattern('|cblue'), "")
			:gsub(ci_pattern('|cgreen'), "")
			:gsub(ci_pattern('|cred'), "")
			:gsub(ci_pattern('|cyellow'), "")
			:gsub(ci_pattern('|corange'), "")
			:gsub(ci_pattern('|cpink'), "")
			:gsub(ci_pattern('|cpurple'), "")
			:gsub(ci_pattern('|cdeathknight'), "")
			:gsub(ci_pattern('|cdruid'), "")
			:gsub(ci_pattern('|chunter'), "")
			:gsub(ci_pattern('|cmage'), "")
			:gsub(ci_pattern('|cmonk'), "")
			:gsub(ci_pattern('|cpaladin'), "")
			:gsub(ci_pattern('|cpriest'), "")
			:gsub(ci_pattern('|crogue'), "")
			:gsub(ci_pattern('|cshaman'), "")
			:gsub(ci_pattern('|cwarlock'), "")
			:gsub(ci_pattern('|cwarrior'), "")
			:gsub(ci_pattern('|cdemonhunter'), "")
			:gsub(ci_pattern('|c%w?%w?%w?%w?%w?%w?%w?%w?'), "")
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
				return select(5, EJ_GetEncounterInfo(id))
			end)
			:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
				return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), 'Healthstone')
			:gsub(ci_pattern('{bloodlust}'), "{bl}")
			:gsub(ci_pattern('{bl}'), 'Bloodlust')
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), '')
			:gsub(ci_pattern('{damage}'), 'Damage')
			:gsub(ci_pattern('{tank}'), 'Tanks')
			:gsub(ci_pattern('{healer}'), 'Healers')
			:gsub(ci_pattern('{dps}'), 'Damage')
			:gsub(ci_pattern('{hero}'), "{heroism}")
			:gsub(ci_pattern('{heroism}'), 'Heroism')
			:gsub(ci_pattern('{hunter}'), LOCALIZED_CLASS_NAMES_MALE["HUNTER"])
			:gsub(ci_pattern('{warrior}'), LOCALIZED_CLASS_NAMES_MALE["WARRIOR"])
			:gsub(ci_pattern('{rogue}'), LOCALIZED_CLASS_NAMES_MALE["ROGUE"])
			:gsub(ci_pattern('{mage}'), LOCALIZED_CLASS_NAMES_MALE["MAGE"])
			:gsub(ci_pattern('{priest}'), LOCALIZED_CLASS_NAMES_MALE["PRIEST"])
			:gsub(ci_pattern('{warlock}'), LOCALIZED_CLASS_NAMES_MALE["WARLOCK"])
			:gsub(ci_pattern('{paladin}'), LOCALIZED_CLASS_NAMES_MALE["PALADIN"])
			:gsub(ci_pattern('{deathknight}'), LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"])
			:gsub(ci_pattern('{druid}'), LOCALIZED_CLASS_NAMES_MALE["DRUID"])
			:gsub(ci_pattern('{monk}'), LOCALIZED_CLASS_NAMES_MALE["MONK"])
			:gsub(ci_pattern('{shaman}'), LOCALIZED_CLASS_NAMES_MALE["SHAMAN"])
			:gsub(ci_pattern('{demonhunter}'), LOCALIZED_CLASS_NAMES_MALE["DEMONHUNTER"])
		
		local lines = { strsplit("\n", output) }
		for _, line in ipairs(lines) do
			if line ~= "" then
				SendChatMessage(line, channel)
			end
		end
	end
end

-----------------
-- Addon Setup --
-----------------

local configDefaults = {
	scale = 1,
	hideoncombat = false,
	fontName = "Friz Quadrata TT",
	fontHeight = 12,
	fontFlags = "NONE",
	highlight = "",
	highlightColor = "ffd200",
	color = "ffffff",
	lineSpacing = 0,
	backdropShow = false,
	backdropColor = "00000080",
	editBoxFont = false,
}

function AngryNotes:GetConfig(key)
	if AngryNotes_Config[key] == nil then
		return configDefaults[key]
	else
		return AngryNotes_Config[key]
	end
end

function AngryNotes:SetConfig(key, value)
	if configDefaults[key] == value then
		AngryNotes_Config[key] = nil
	else
		AngryNotes_Config[key] = value
	end
end

function AngryNotes:RestoreDefaults()
	AngryNotes_Config = {}
	self:UpdateMedia()
	self:UpdateDisplayed()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("AngryNotes")
end

local blizOptionsPanel
function AngryNotes:OnInitialize()
	if AngryNotes_State == nil then
		AngryNotes_State = { tree = {}, window = {}, display = {}, displayed = nil, locked = false, directionUp = false }
	end
	if AngryNotes_Pages == nil then AngryNotes_Pages = { } end
	if AngryNotes_Config == nil then AngryNotes_Config = { } end
	if AngryNotes_Categories == nil then
		AngryNotes_Categories = { }
	else
		for _, cat in pairs(AngryNotes_Categories) do
			if cat.Children then
				for _, pageId in ipairs(cat.Children) do
					local page = AngryNotes_Pages[pageId]
					if page then
						page.CategoryId = cat.Id
					end
				end
				cat.Children = nil
			end
		end
	end

	local ver = AngryNotes_Version
	if ver:sub(1,1) == "@" then ver = "dev" end
	
	local options = {
		name = "Angry Notes "..ver,
		handler = AngryNotes,
		type = "group",
		args = {
			window = {
				type = "execute",
				order = 3,
				name = "Toggle Window",
				desc = "Shows/hides the edit window (also available in game keybindings)",
				func = function() AngryNotes_ToggleWindow() end
			},
			help = {
				type = "execute",
				order = 99,
				name = "Help",
				hidden = true,
				func = function()
					LibStub("AceConfigCmd-3.0").HandleCommand(self, "aa", "AngryNotes", "")
				end
			},
			toggle = {
				type = "execute",
				order = 1,
				name = "Toggle Display",
				desc = "Shows/hides the display frame (also available in game keybindings)",
				func = function() AngryNotes_ToggleDisplay() end
			},
			deleteall = {
				type = "execute",
				name = "Delete All Pages",
				desc = "Deletes all pages",
				order = 4,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					AngryNotes_State.displayed = nil
					AngryNotes_Pages = {}
					AngryNotes_Categories = {}
					self:UpdateTree()
					self:UpdateSelected()
					self:UpdateDisplayed()
					if self.window then self.window.tree:SetSelected(nil) end
					self:Print("All pages have been deleted.")
				end
			},
			defaults = {
				type = "execute",
				name = "Restore Defaults",
				desc = "Restore configuration values to their default settings",
				order = 10,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:RestoreDefaults()
				end
			},
			output = {
				type = "execute",
				name = "Output",
				desc = "Outputs currently displayed notes to chat",
				order = 11,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:OutputDisplayed()
				end
			},
			send = {
				type = "input",
				name = "Display",
				desc = "Display page with specified name",
				order = 12,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				get = function(info) return "" end,
				set = function(info, val)
					local result = self:DisplayPageByName( val:trim() )
					if result == false then
						self:Print( RED_FONT_COLOR_CODE .. "A page with the name \""..val:trim().."\" could not be found.|r" )
					elseif not result then 
						self:Print( RED_FONT_COLOR_CODE .. "You don't have permission to send a page.|r" )
					end
				end
			},
			clear = {
				type = "execute",
				name = "Clear",
				desc = "Clears currently displayed page",
				order = 13,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					AngryNotes_ClearPage()
				end
			},
			resetposition = {
				type = "execute",
				order = 22,
				name = "Reset Position",
				desc = "Resets position for the note display",
				func = function()
					self:ResetPosition()
				end
			},
			lock = {
				type = "execute",
				order = 2,
				name = "Toggle Lock",
				desc = "Shows/hides the display mover (also available in game keybindings)",
				func = function() self:ToggleLock() end
			},
			config = { 
				type = "group",
				order = 5,
				name = "General",
				inline = true,
				args = {
					highlight = {
						type = "input",
						order = 1,
						name = "Highlight",
						desc = "A list of words to highlight on displayed pages (separated by spaces or punctuation)\n\nUse 'Group' to highlight the current group you are in, ex. G2",
						get = function(info) return self:GetConfig('highlight') end,
						set = function(info, val)
							self:SetConfig('highlight', val)
							self:UpdateDisplayed()
						end
					},
					hideoncombat = {
						type = "toggle",
						order = 3,
						name = "Hide on Combat",
						desc = "Enable to hide display frame upon entering combat",
						get = function(info) return self:GetConfig('hideoncombat') end,
						set = function(info, val)
							self:SetConfig('hideoncombat', val)

						end
					},
					scale = {
						type = "range",
						order = 4,
						name = "Scale",
						desc = "Sets the scale of the edit window",
						min = 0.3,
						max = 3,
						get = function(info) return self:GetConfig('scale') end,
						set = function(info, val)
							self:SetConfig('scale', val)
							if AngryNotes.window then AngryNotes.window.frame:SetScale(val) end
						end
					},
					backdrop = {
						type = "toggle",
						order = 5,
						name = "Display Backdrop",
						desc = "Enable to display a backdrop behind the note display",
						get = function(info) return self:GetConfig('backdropShow') end,
						set = function(info, val)
							self:SetConfig('backdropShow', val)
							self:UpdateBackdrop()
						end
					},
					backdropcolor = {
						type = "color",
						order = 6,
						name = "Backdrop Color",
						desc = "The color used by the backdrop",
						hasAlpha = true,
						get = function(info)
							local hex = self:GetConfig('backdropColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b, a)
							self:SetConfig('backdropColor', RGBToHex(r, g, b, a))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
				}
			},
			font = { 
				type = "group",
				order = 6,
				name = "Font",
				inline = true,
				args = {
					fontname = {
						type = 'select',
						order = 1,
						dialogControl = 'LSM30_Font',
						name = 'Face',
						desc = 'Sets the font face used to display a page',
						values = LSM:HashTable("font"),
						get = function(info) return self:GetConfig('fontName') end,
						set = function(info, val)
							self:SetConfig('fontName', val)
							self:UpdateMedia()
						end
					},
					fontheight = {
						type = "range",
						order = 2,
						name = "Size",
						desc = function() 
							return "Sets the font height used to display a page"
						end,
						min = 6,
						max = 24,
						step = 1,
						get = function(info) return self:GetConfig('fontHeight') end,
						set = function(info, val)
							self:SetConfig('fontHeight', val)
							self:UpdateMedia()
						end
					},
					fontflags = {
						type = "select",
						order = 3,
						name = "Outline",
						desc = "Sets the font outline used to display a page",
						values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROMEOUTLINE"] = "Monochrome" },
						get = function(info) return self:GetConfig('fontFlags') end,
						set = function(info, val)
							self:SetConfig('fontFlags', val)
							self:UpdateMedia()
						end
					},
					color = {
						type = "color",
						order = 4,
						name = "Normal Color",
						desc = "The normal color used to display notes",
						get = function(info)
							local hex = self:GetConfig('color')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('color', RGBToHex(r, g, b))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					highlightcolor = {
						type = "color",
						order = 5,
						name = "Highlight Color",
						desc = "The color used to emphasize highlighted words",
						get = function(info)
							local hex = self:GetConfig('highlightColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('highlightColor', RGBToHex(r, g, b))
							self:UpdateDisplayed()
						end
					},
					linespacing = {
						type = "range",
						order = 6,
						name = "Line Spacing",
						desc = function()
							return "Sets the line spacing used to display a page"
						end,
						min = 0,
						max = 10,
						step = 1,
						get = function(info) return self:GetConfig('lineSpacing') end,
						set = function(info, val)
							self:SetConfig('lineSpacing', val)
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					editBoxFont =  {
						type = "toggle",
						order = 7,
						name = "Change Edit Box Font",
						desc = "Enable to set edit box font to display font",
						get = function(info) return self:GetConfig('editBoxFont') end,
						set = function(info, val)
							self:SetConfig('editBoxFont', val)
							self:UpdateMedia()
						end
					},
				}
			},
		}
	}

	self:RegisterChatCommand("an", "ChatCommand")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AngryNotes", options)

	blizOptionsPanel = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AngryNotes", "Angry Notes")
	blizOptionsPanel.default = function() self:RestoreDefaults() end
end

function AngryNotes:ChatCommand(input)
	if not input or input:trim() == "" then
		AngryNotes_ToggleWindow()
	elseif input:trim() == "config" then
		InterfaceOptionsFrame_OpenToCategory(blizOptionsPanel)
		InterfaceOptionsFrame_OpenToCategory(blizOptionsPanel)
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(self, "an", "AngryNotes", input)
	end
end

function AngryNotes:OnEnable()
	self:CreateDisplay()
	C_Timer.After(0.1, function() self:UpdateBackdrop() end)
	
	self:RegisterEvent("GROUP_JOINED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateMedia")
	LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "UpdateMedia")
end

function AngryNotes:GROUP_JOINED()
	self:UpdateDisplayedIfNewGroup()
end

function AngryNotes:PLAYER_REGEN_DISABLED()
	if AngryNotes:GetConfig('hideoncombat') then
		self:HideDisplay()
	end
end

function AngryNotes:GROUP_ROSTER_UPDATE()
	if not (IsInRaid() or IsInGroup()) then
		if AngryNotes_State.displayed then self:ClearDisplayed() end
		currentGroup = nil
		warnedPermission = false
	else
		self:UpdateDisplayedIfNewGroup()
	end
end
