local TOCNAME, LFGAnnouncements = ...
local AceGUI = LibStub("AceGUI-3.0", "AceEvent-3.0")

local Dungeons
local DifficultyTextLookup = {
	NORMAL = " |cff00ff00[N]|r ",
	HEROIC = " |cffff0000[H]|r ",
	RAID = " |cff8000ff[R]|r ",
}


local LFGAnnouncementsUI = {}
function LFGAnnouncementsUI:OnInitialize()
	LFGAnnouncements.UI = self

	self._dungeonContainers = {}
	self._frame = nil

	self:RegisterMessage("OnDungeonActivated", "OnDungeonActivated")
	self:RegisterMessage("OnDungeonDeactivated", "OnDungeonDeactivated")
	self:RegisterMessage("OnDungeonEntry", "OnDungeonEntry")
	self:RegisterMessage("OnRemoveDungeonEntry", "OnRemoveDungeonEntry")
	self:RegisterMessage("OnRemoveDungeons", "OnRemoveDungeons")
end

function LFGAnnouncementsUI:OnEnable()
	-- Called on PLAYER_LOGIN event
	Dungeons = LFGAnnouncements.Dungeons
	self._ready = true

	self._fontSettings = LFGAnnouncements.DB:GetProfileData("general", "font")
end

function LFGAnnouncementsUI:IsShown()
	return (not not self._frame) and self._frame:IsShown()
end

function LFGAnnouncementsUI:Show()
	if not self._frame then
		self:_createUI()
		self:SendMessage("OnShowUI")
	elseif not self._frame:IsShown() then
		self._frame:Show()
		self:SendMessage("OnShowUI")
	end
end

function LFGAnnouncementsUI:Hide()
	if self._frame and self._frame:IsShown() then
		self._frame:Hide()
		self:SendMessage("OnHideUI")
	end
end

function LFGAnnouncementsUI:Toggle()
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

function LFGAnnouncementsUI:CloseAll()
	for _, container in pairs(self._dungeonContainers) do
		container.group:Collapse()
	end
end

function LFGAnnouncementsUI:OpenGroup(dungeonId)
	local container = self._dungeonContainers[dungeonId]
	if not container then
		return
	end

	container.group:Expand()
end

-- TODO - This is maybe not the best solution, but we give the max font width of a name
local nameSize, timeSize
local function temp(fontSettings)
	if nameSize then
		return nameSize, timeSize
	end

	local frame = CreateFrame("Frame", nil, UIParent)
	local s = frame:CreateFontString(frame, "BACKGROUND")
	s:SetFont(fontSettings.path, fontSettings.size, fontSettings.flags)

	s:SetText("XXXXXXXXXXXX")
	nameSize = s:GetStringWidth()

	s:SetText(" 99m 59s ")
	timeSize = s:GetStringWidth()

	frame:Hide()
	return nameSize, timeSize
end

function LFGAnnouncementsUI:SetFont(font, size, flags)
	local settings = self._fontSettings
	settings.path = font and font or settings.path
	settings.size = size and size or settings.size
	settings.flags = flags and flags or settings.flags
	LFGAnnouncements.DB:SetProfileData("font", settings, "general")

	nameSize = nil
	timeSize = nil

	for _, container in pairs(self._dungeonContainers) do
		for _, entry in pairs(container.entries) do
			self:_setFont(entry)
			self:_calculateSize(entry, container.group, true)
		end
		container.group:SetTitleFont(settings.path, settings.size, settings.flags)
	end

	self._scrollContainer:DoLayout()
end

function LFGAnnouncementsUI:_createUI()
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(TOCNAME)
	frame:SetLayout("List")
	frame.statustext:GetParent():Hide()

	local container = AceGUI:Create("ScrollFrame")
	container:SetFullWidth(true)
	container:SetLayout("List")
	container.RemoveChild = function(self, widget)
		for i = 1, #self.children do
			local child = self.children[i]
			if child == widget then
				tremove(self.children, i)
				break
			end
		end
	end
	frame:AddChild(container)

	local settingsButton = AceGUI:Create("Button")
	settingsButton:ClearAllPoints()
	settingsButton:SetPoint("BOTTOMLEFT", frame.frame, "BOTTOMLEFT", 27, 17)
	settingsButton:SetHeight(20)
	settingsButton:SetWidth(100)
	settingsButton:SetText("Settings")
	settingsButton:SetCallback("OnClick", function(widget, event, button)
		if button == "LeftButton" then
			LFGAnnouncements.Options.Toggle()
		end
	end)
	frame:AddChild(settingsButton)

	self._frame = frame
	self._scrollContainer = container
end

function LFGAnnouncementsUI:_createDungeonContainer(dungeonId)
	local dungeons = Dungeons
	local name = dungeons:GetDungeonName(dungeonId)

	local group = AceGUI:Create("CollapsableInlineGroup")
	group.name = name
	group.counter = 0
	group:SetFullWidth(true)
	group:SetLayout("Flow")
	group.RemoveChild = function(self, widget)
		for i = 1, #self.children do
			local child = self.children[i]
			if child == widget then
				tremove(self.children, i)
				break
			end
		end
	end
	group:SetTitle(string.format("%s (0)", name))
	group:SetTitleFont(self._fontSettings.path, self._fontSettings.size, self._fontSettings.flags)
	group:Collapse()

	self._scrollContainer:AddChild(group)

	self._dungeonContainers[dungeonId] = {
		group = group,
		entries = {},
	}

	group:SetCallback("Expand", function() self._scrollContainer:DoLayout() end)
	group:SetCallback("Collapse", function() self._scrollContainer:DoLayout() end)
	group:SetCallback("OnWidthSet", function()
		local entires = self._dungeonContainers[dungeonId].entries
		for _, entry in pairs(entires) do
			self:_calculateSize(entry, group, false)
		end
	end)

	return self._dungeonContainers[dungeonId]
end

function LFGAnnouncementsUI:_removeDungeonContainer(dungeonId)
	local container = self._dungeonContainers[dungeonId]
	if not container then
		return
	end

	local group = container.group
	local entries = container.entries
	for _, entry in pairs(entries) do
		for _, widget in pairs(entry) do
			group:RemoveChild(widget)
			widget:Release()
		end
	end

	self._scrollContainer:RemoveChild(group)
	group:Release()
	self._dungeonContainers[dungeonId] = nil -- TODO: This will force us to re-create container tables everytime we remove/add. Might want to change
	self._scrollContainer:DoLayout()
end

local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onTooltipEnter(widget, event)
	if widget.is_truncated then
		local tooltip = AceGUI.tooltip
		tooltip:SetOwner(widget.frame, "ANCHOR_NONE")
		tooltip:SetPoint(getAnchors(widget.frame))
		tooltip:SetText(widget.label:GetText() or "", 1, .82, 0, true)
		tooltip:Show()
	end
end

local function onTooltipLeave(widget, event)
	AceGUI.tooltip:Hide()
end

function LFGAnnouncementsUI:_setFont(entry)
	local font = self._fontSettings.path
	local size = self._fontSettings.size
	local flags = self._fontSettings.flags

	for _, obj in pairs(entry) do
		obj:SetFont(font, size, flags)
	end
end

function LFGAnnouncementsUI:_createEntryLabel(dungeonId, difficulty, message, time, authorGUID, reason)
	local container = self._dungeonContainers[dungeonId]
	if not container then
		container = self:_createDungeonContainer(dungeonId)
	end

	local _, class, _, _, _, author = GetPlayerInfoByGUID(authorGUID)
	local _,_,_, hex = GetClassColor(class)

	local entry = container.entries[authorGUID]
	local temp = false
	if not entry then
		local group = container.group
		local onClick = function(widget, event, button) -- TODO: This is stupid. Should use one function instead of creating a new one every time
			if button == "LeftButton" then
				ChatFrame_OpenChat(string.format("/w %s ", author))
			elseif button == "RightButton" then
				C_FriendList.SendWho(author)
			end
		end

		local difficultyLabel = AceGUI:Create("InteractiveLabel")
		difficultyLabel:SetCallback("OnClick", onClick)
		group:AddChild(difficultyLabel)

		local nameLabel = AceGUI:Create("InteractiveLabel")
		nameLabel:SetCallback("OnClick", onClick)
		group:AddChild(nameLabel)

		local messageLabel = AceGUI:Create("InteractiveLabel")
		messageLabel.label:SetWordWrap(false)
		messageLabel.label:SetNonSpaceWrap(false)
		messageLabel:SetCallback("OnClick", onClick)
		messageLabel:SetCallback("OnEnter", onTooltipEnter)
		messageLabel:SetCallback("OnLeave", onTooltipLeave)
		group:AddChild(messageLabel)

		local timeLabel = AceGUI:Create("InteractiveLabel")
		timeLabel.label:SetJustifyH("RIGHT")
		timeLabel:SetCallback("OnClick", onClick)
		group:AddChild(timeLabel)

		entry = {
			name = nameLabel,
			difficulty = difficultyLabel,
			message = messageLabel,
			time = timeLabel,
		}
		self:_setFont(entry)

		container.entries[authorGUID] = entry

		local containerName = group.name
		local containerCounter = group.counter + 1
		group.counter = containerCounter
		group:SetTitle(string.format("%s (%d)", containerName, containerCounter))
		temp = true
	end

	entry.name:SetText(string.format("|c%s%s|r", hex, author))
	entry.difficulty:SetText(DifficultyTextLookup[difficulty])
	entry.message:SetText(message)
	entry.time:SetText(self:_format_time(time))

	self:_calculateSize(entry, container.group, temp)
end

function LFGAnnouncementsUI:_removeEntryLabel(dungeonId, authorGUID)
	local container = self._dungeonContainers[dungeonId]
	if container then
		local group = container.group
		local entry = container.entries[authorGUID]
		if entry then
			for _, widget in pairs(entry) do
				group:RemoveChild(widget)
				widget:Release()
			end
			container.entries[authorGUID] = nil

			local counter = group.counter - 1

			if counter <= 0 then
				self:_removeDungeonContainer(dungeonId)
			else
				local containerName = group.name
				group.counter = counter
				group:SetTitle(string.format("%s (%d)", containerName, counter))
			end
		end
	end
end

local TimeColorLookup = {
	NEW = "|cff00ff00",
	MEDIUM = "|cffeed202",
	OLD = "|cffff0000",
}
function LFGAnnouncementsUI:_format_time(time)
	local time_visible_sec = LFGAnnouncements.DB:GetProfileData("general", "time_visible_sec") -- TODO: Might be slow. Cache?
	local percentage = time / time_visible_sec
	local color
	if percentage < 0.33 then
		color = TimeColorLookup.NEW
	elseif percentage < 0.66 then
		color = TimeColorLookup.MEDIUM
	else
		color = TimeColorLookup.OLD
	end

	local min = math.floor(time / 60)
	return string.format("%s%dm %02ds|r", color, min, time % 60)
end

function LFGAnnouncementsUI:_calculateSize(entry, group, newEntry)
	local diffWidth = entry.difficulty.label:GetStringWidth()
	local nameWidth, timeWidth = temp(self._fontSettings)

	if newEntry then
		entry.difficulty:SetWidth(diffWidth)
		entry.name:SetWidth(nameWidth)
		entry.time:SetWidth(timeWidth)
	end

	local groupWidth = group.frame:GetWidth()

	local messageTextWidth = entry.message.label:GetStringWidth()
	local availableWidth = groupWidth - diffWidth - timeWidth - nameWidth - 8 - 8 - 8
	entry.message.is_truncated = messageTextWidth > availableWidth
	entry.message:SetWidth(availableWidth)
end

function LFGAnnouncementsUI:OnDungeonActivated(event, dungeonId)
end

function LFGAnnouncementsUI:OnDungeonDeactivated(event, dungeonId)
	self:_removeDungeonContainer(dungeonId)
end

function LFGAnnouncementsUI:OnDungeonEntry(event, dungeonId, difficulty, message, time, authorGUID, reason)
	if self:IsShown() then
		self:_createEntryLabel(dungeonId, difficulty, message, time, authorGUID, reason)
		-- self._scrollContainer:DoLayout()
	end
end

function LFGAnnouncementsUI:OnRemoveDungeonEntry(event, dungeonId, authorGUID)
	if self:IsShown() then
		self:_removeEntryLabel(dungeonId, authorGUID)
		self._scrollContainer:DoLayout()
	end
end

function LFGAnnouncementsUI:OnRemoveDungeons(event, dungeons)
	for i = 1, #dungeons, 2 do
		local dungeonId = dungeons[i]
		local authorGUID = dungeons[i + 1]
		self:_removeEntryLabel(dungeonId, authorGUID)
	end

	if self:IsShown() then
		self._scrollContainer:DoLayout()
	end
end

LFGAnnouncements.Core:RegisterModule("UI", LFGAnnouncementsUI, "AceEvent-3.0")