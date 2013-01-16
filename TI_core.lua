--[[--------------------------------------
--             TInspect
--                by
--               SouD
------------------------------------------
-- @date 06/06/2012
-- @version 1.0
-- @since 06/06/2012
-- @author SouD
--]]--------------------------------------
--[[
						INFORMATION
-----------------------------------------------------------
-- Prefix: TIN
-- Protocol: S:CLASSINT..TALENTSTRING or R:TARGETNAME
-- Prio: NORMAL
-- Channel: PARTY|RAID|BATTLEGROUND
-----------------------------------------------------------
--]]

local vMajor = 1;
local vMedium = 0;
local vMinor = 0;

TInspect = {
	title = "TInspect_ALPHA",
	versum = (vMajor * 1000) + (vMedium * 100) + vMinor,
	version = tostring(vMajor) .. "." .. tostring(vMedium) .. "." .. tostring(vMinor),
	locale = "enUS",
	cint = 1,
	pname = "Unknown",
	talentStr = "",
	saveData = "false",
	FRAME_UPDATE_INTERVAL = 60.0,
	LIGHT_UPDATE_INTERVAL = 5.0,
	HEAVY_UPDATE_INTERVAL = 3600.0,
	timeSinceLastFrameUpdate = 0,
	timeSinceLastLightUpdate = 0,
	timeSinceLastHeavyUpdate = 0,
	pendingEntryExpireTime = 5,
	blacklistEntryExpireTime = 86400,
	cacheEntryExpireTime = 0,
	dbEntryExpireTime = 0,
};

local _G = getfenv(0);
local L = TI_Locale[TInspect.locale];
local LE = L["ERROR"];
local LH = L["HELP"];
local INSPECT_TAB_INDEX = 3;
local initiated = false;
local strf = string.format;
TI_ActiveTalentTab = 1;
TI_TCInt = 1;

-- Default settings
local TInspect_DB_defaults = {
	["version"] = TInspect.version,
	["locale"] = TInspect.locale,
	["blacklistEntryExpireTime"] = 86400,
	["dbEntryExpireTime"] = 864000,
	["cacheEntryExpireTime"] = 0,
	["saveData"] = "false",
	["savedData"] = {},
};

------------------------------Local Functions--------------------------------

local function print(text, name, r, g, b, frame, delay)
	if (not text or string.len(text) == 0) then
		text = " ";
	end
	if (not name or name == AceConsole) then
		(frame or DEFAULT_CHAT_FRAME):AddMessage("|cff55aaeeTInspect:|r " .. text, r, g, b, nil, delay or 5);
	else
		(frame or DEFAULT_CHAT_FRAME):AddMessage("|cff55aaee" .. tostring(name) .. ":|r " .. text, r, g, b, nil, delay or 5);
	end
end

local function Merge(t1, t2)
	for k, v in pairs(t2) do
		if (type(v) == "table") then
			if (type(t1[k] or false) == "table") then
				merge(t1[k] or {}, t2[k] or {});
			else
				t1[k] = v;
			end
		else
			t1[k] = v;
		end
	end
end

local function GetClassInt(class)
	if (class and type(class) == "string") then
		class = string.upper(class);
		if (class == "WARRIOR") then
			return 1;
		elseif (class == "DRUID") then
			return 2;
		elseif (class == "WARLOCK") then
			return 3;
		elseif (class == "MAGE") then
			return 4;
		elseif (class == "PRIEST") then
			return 5;
		elseif (class == "PALADIN") then
			return 6;
		elseif (class == "SHAMAN") then
			return 7;
		elseif (class == "ROGUE") then
			return 8;
		elseif (class == "HUNTER") then
			return 9;
		end
	else
		return 1;
	end
end

local function GetClassString(classInt)
	if (classInt and type(classInt) == "number") then
		if (classInt == 1) then
			return "WARRIOR";
		elseif (classInt == 2) then
			return "DRUID";
		elseif (classInt == 3) then
			return "WARLOCK";
		elseif (classInt == 4) then
			return "MAGE";
		elseif (classInt == 5) then
			return "PRIEST";
		elseif (classInt == 6) then
			return "PALADIN";
		elseif (classInt == 7) then
			return "SHAMAN";
		elseif (classInt == 8) then
			return "ROGUE";
		elseif (classInt == 9) then
			return "HUNTER";
		end
	else
		return "WARRIOR";
	end
end

local function InParty()
	local p = GetNumPartyMembers();
	local r = GetNumRaidMembers();
	local inParty = false;
	
	if ((p + r) > 0) then
		inParty = true;
	end
	
	return inParty;
end

local function InRaid()
	local r = GetNumRaidMembers();
	local inRaid = false;
	
	if (r > 0) then
		inRaid = true;
	end
	
	return inRaid;
end

function Split(str, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	string.gsub(str, pattern, function(c) fields[getn(fields) + 1] = c end)
	return fields
end

function TI_ShouldRequest(unit)
	if (not unit) then 
		return false;
	end
	
	local sr = false;
	
	if (not TI_Blacklist:HasKey(unit) and not TI_Pending:HasKey(unit) and not TI_PlayerCache:RecentlyCached(unit)) then
		sr = true;
	end
	
	return sr;
end

-------------------------------List Functions--------------------------------

TI_Blacklist = {
	["list"] = {},
};
function TI_Blacklist:HasKey(player)
	if (self["list"][player]) then
		return true;
	else
		return false;
	end
end

function TI_Blacklist:Push(player)
	if (not player or type(player) ~= "string") then 
		return false;
	end
	self["list"][player] = self["list"][player] or {};
	self["list"][player]["added"] = time();
	print((strf(L["BLACKLIST_MSG"], player)));
	return true;
end

function TI_Blacklist:Remove(player)
	self["list"][player] = nil;
end

function TI_Blacklist:Expire()
	local now = time();
	local t = TI_Blacklist["list"];
	for k, v in pairs(t) do
		local added = tonumber(t[k]["added"]);
		if ((now - added) > TInspect.blacklistEntryExpireTime) then
			self:Remove(k);
			print("Removed " .. k .. " from blacklist.");
		end
	end
end

TI_Pending = {
	["list"] = {},
};
function TI_Pending:HasKey(player)
	if (self["list"][player]) then
		return true;
	else
		return false;
	end
end

function TI_Pending:Push(player)
	if (not player or type(player) ~= "string") then 
		return false;
	end
	self["list"][player] = self["list"][player] or {};
	self["list"][player]["added"] = time();
	return true;
end

function TI_Pending:Remove(player)
	self["list"][player] = nil;
end

function TI_Pending:Blacklist(player)
	if (not player or type(player) ~= "string") then 
		return false;
	end
	self:Remove(player);
	TI_Blacklist:Push(player);
	return true;
end

function TI_Pending:Expire()
	local now = time();
	local t = TI_Pending["list"];
	for k, v in pairs(t) do
		local added = tonumber(t[k]["added"]);
		if ((now - added) > TInspect.pendingEntryExpireTime) then
			self:Blacklist(k);
		end
	end
end


TI_PlayerCache = {
	["cache"] = {},
};
function TI_PlayerCache:HasKey(player)
	if (self["cache"][player]) then
		return true;
	else
		return false;
	end
end

function TI_PlayerCache:Push(player, talents)
	if (player and talents and type(player) == "string" and type(talents) == "string") then
		self["cache"][player] = self["cache"][player] or {};
		self["cache"][player]["talents"] = talents;
		self["cache"][player]["lastSeen"] = time();
		return true;
	else
		return false;
	end
end

function TI_PlayerCache:RecentlyCached(player, limit)
	local l = limit or 300;
	local now = time();
	if (self:HasKey(player)) then
		local lseen = self["cache"][player]["lastSeen"];
		if ((now - lseen) > l) then
			return false;
		else
			return true;
		end
	else
		return false;
	end
end

function TI_PlayerCache:Remove(player)
	self["cache"][player] = nil;
end

function TI_PlayerCache:Expire()
	if (TInspect.cacheEntryExpireTime > 0) then
		--TODO: Implement cleaning logic
		return;
	end
end

function TInspect_DB_HasKey(player)
	if (TInspect_DB and TInspect_DB["savedData"][player]) then
		return true;
	else
		return false;
	end
end

---------------------------------------------------------------------

------------------------TInspect functions---------------------------

function TInspect_HandleSlashCmd(cmd)
	local cmds = Split(cmd, " ");
	if (cmds[1] == "save") then
		TInspect:ToggleSaving();
	elseif (cmds[1] == "force") then
		TInspect:ForceRequest();
	elseif (cmds[1] == "about") then
		TInspect:About();
	elseif (cmds[1] == "") then
		TInspect.Help();
	else
		TInspect.Help();
	end
end

function TInspect_OnLoad(frame)
	TInspect.frame = frame or this;
	TInspect.timeSinceLastLightUpdate = 0;
	TInspect.timeSinceLastHeavyUpdate = 0;
	TInspect.timeSinceLastFrameUpdate = 0;
	
	SLASH_TInspect1 = "/tinspect";
	SLASH_TInspect2 = "/TInspect";
	SlashCmdList["TInspect"] = TInspect_HandleSlashCmd;
	
	print(L["LOADED"]);
end

function TInspect_EventHandler()
	if (event == "ADDON_LOADED")				then	TInspect_OnAddonLoaded(); 				end; 
	if (event == "PLAYER_LOGOUT")				then	TInspect_OnPlayerLogout();				end;
	if (event == "PLAYER_ALIVE")				then	TInspect_OnPlayerAlive();				end;
	if (event == "CHARACTER_POINTS_CHANGED")	then	TInspect_OnCharacterPointsChanged();	end;
	if (event == "CHAT_MSG_ADDON")				then	TInspect_OnChatMsgAddon();				end;
end

function TInspect_OnAddonLoaded()
	if (string.lower(arg1) == "blizzard_inspectui") then
		--Only init after inspect_ui is loaded
		TInspect_Init();
	elseif (arg1 == "TInspect") then
		if (not TInspect_DB) then
			TInspect_DB = TInspect_DB_defaults;
		end
		
		local now = time();
		TInspect.blacklistEntryExpireTime = TInspect_DB["blacklistEntryExpireTime"];
		TInspect.cacheEntryExpireTime = TInspect_DB["cacheEntryExpireTime"];
		TInspect.dbEntryExpireTime = TInspect_DB["dbEntryExpireTime"];
		TInspect.saveData = TInspect_DB["saveData"];
	end
end

function TInspect_OnUpdate()
	--Update TI_Pending queue and cache
	self = TInspect;
	self.timeSinceLastLightUpdate = self.timeSinceLastLightUpdate + arg1;
	self.timeSinceLastHeavyUpdate = self.timeSinceLastHeavyUpdate + arg1;
	
	--Check pending expire time
	if (self.timeSinceLastLightUpdate > self.LIGHT_UPDATE_INTERVAL) then
		TI_Pending:Expire();
		--TInspect_InspectTalentFrame_Update();
		self.timeSinceLastLightUpdate = 0;
	end
	
	--Check blacklist expire time
	if (self.timeSinceLastHeavyUpdate > self.HEAVY_UPDATE_INTERVAL) then
		TI_Blacklist:Expire();
		TInspect_InspectTalentFrame_Update();
		self.timeSinceLastHeavyUpdate = 0;
	end
end

function TInspect_OnPlayerLogout()
	--Save variables now
	TInspect_DB["saveData"] = TInspect.saveData;
	TInspect_DB["blacklistEntryExpireTime"] = TInspect.blacklistEntryExpireTime;
	TInspect_DB["cacheEntryExpireTime"] = TInspect.cacheEntryExpireTime;
	TInspect_DB["dbEntryExpireTime"] = TInspect.dbEntryExpireTime;
	
	if (TInspect.saveData == "true") then
		Merge(TInspect_DB["savedData"], TI_PlayerCache["cache"]);
	end
end

--Done, don't touch
function TInspect_OnPlayerAlive()
	TInspect.frame:UnregisterEvent("PLAYER_ALIVE");
	local _, c = UnitClass("player");
	TInspect.cint = GetClassInt(c);
	TInspect.pname = UnitName("player");
	TInspect:BuildTalentString();
end

--Done, don't touch
function TInspect_OnCharacterPointsChanged()
	if (arg1 == -1) then
		TInspect:BuildTalentString();
	end
end

function TInspect_OnChatMsgAddon()
	if (arg1 == "TIN") then
		local msg = Split(arg2, ":");
		if (msg[1] == "R") then --Request for data
			if (msg[2] == TInspect.pname) then
				TInspect:SendUnitData();
			end
		elseif (msg[1] == "S") then --Sent data
			if (arg4 ~= TInspect.pname) then --Don't save our own specc!
				TInspect.Cache(arg4, msg[2]);
				TInspect_InspectTalentFrame_Update();
			end
		end
	end
end

function TInspect_Init()
	if (initiated) then 
		return;
	end
	initiated = true;
	
	TInspect_SetupHookFunctions();
	TInspect_AddInspectTab();
	TInspect_AddInspectPanel();
	
	print(L["INIT"]);
end

--Done, don't touch
function TInspect_SetupHookFunctions()
	--InspectFrameTab_Show hook
	InspectFrame_Show_ORIG = InspectFrame_Show;
	InspectFrame_Show = TInspect_InspectFrame_Show;
	
	--InspectFrame_OnUpdate hook
	InspectFrame_OnUpdate_ORIG = InspectFrame_OnUpdate;
	InspectFrame_OnUpdate = TInspect_InspectFrame_OnUpdate;
	
	--InspectFrameTab_OnEvent hook
	InspectFrame_OnEvent_ORIG = InspectFrame_OnEvent;
	InspectFrame_OnEvent = TInspect_InspectFrame_OnEvent;
	
	--InspectFrameTab_ToggleInspect hook
	ToggleInspect_ORIG = ToggleInspect;
	ToggleInspect = TInspect_ToggleInspect;
	
	--InspectFrameTab_OnClick hook
	InspectFrameTab_Onclick_ORIG = InspectFrameTab_OnClick;
	InspectFrameTab_OnClick = TInspect_InspectFrameTab_OnClick;
end

--Might be done
function TInspect_AddInspectPanel()
	local framename = "InspectTalentFrame";
	local frame = CreateFrame("Frame", framename, InspectFrame, "TInspect_InspectTalentFrameTemplate");
	frame:SetID(INSPECT_TAB_INDEX);
	frame:Hide();
end

--Done, don't touch
function TInspect_AddInspectTab()
	local n = InspectFrame.numTabs + 1;
	INSPECT_TAB_INDEX = n;
	local framename = "InspectFrameTab" .. n;
	local frame = CreateFrame("Button", framename, InspectFrame, "TInspect_InspectFrameTabButtonTemplate");
	
	frame:SetID(n);
	frame:SetText("Talents");
	frame:SetPoint("LEFT", getglobal("InspectFrameTab" .. (n - 1)), "RIGHT", -16, 0);
	
	INSPECTFRAME_SUBFRAMES[n] = "InspectTalentFrame";
	PanelTemplates_SetNumTabs(InspectFrame, n);
	--PanelTemplates_SetTab(InspectFrame, 1);
	PanelTemplates_EnableTab(InspectFrame, n);
end

function TInspect_InspectTalentFrameButton_OnClick()
	TI_ActiveTalentTab = this:GetID();
	TInspect_InspectTalentFrame_Update();
end

function TInspect.Help()
	local str = "Available commands:\n";
	str = str .. LH["CMD_SAVE"] .. "\n";
	str = str .. LH["CMD_ABOUT"];
	print(str);
end

function TInspect:About()
	print((strf(L["ABOUT"], self.version)));
end

function TInspect:ToggleSaving()
	local state = "";
	if (self.saveData == "false") then
		self.saveData = "true";
		state = "|cff20ff20" .. L["YES"] .. "|r";
	else
		self.saveData = "false";
		state = "|cffff2020" .. L["NO"] .. "|r";
	end
	local str = strf(L["SAVING_DATA"], state);
	print(str);
end

--Scans player talents and builds string
function TInspect:BuildTalentString()
	local str = "";
	local numTabs = GetNumTalentTabs();
	
	for i = 1, numTabs do
		local nt = GetNumTalents(i);
		for j = 1, nt do
			_, _, _, _, cr = GetTalentInfo(i, j);
			str = str .. tostring(cr);
		end
	end
	
	--Append class integer
	self.talentStr = tostring(self.cint) .. str; 
end

function TInspect:ForceRequest()
	self:GetUnitData("target", true);
end

--Checks if data is cached or requests it
function TInspect:GetUnitData(unit, force)
	if (not InParty()) then --No reason to query outside of party/raid
		return;
	end
	
	if (UnitExists(unit) and UnitIsFriend("player", unit) and UnitPlayerControlled(unit) and (UnitInRaid(unit) or UnitInParty(unit))) then
		local uname = UnitName(unit);
		if (force) then
			self.RequestUnitData(uname);
		elseif (TI_ShouldRequest(uname)) then
			self.RequestUnitData(uname);
		end
		return;
	else
		TInspect_InspectTalentFrameMessage:SetText("Unable to query target..");
		return;
	end
end

--Send unit data request across addon channel
function TInspect.RequestUnitData(unit, prio, channel)
	local msg = "R:" .. unit;
	local p = prio or "NORMAL";
	local c = channel or "RAID";
	TI_Pending:Push(unit);
	ChatThrottleLib:SendAddonMessage(p, "TIN", msg, c);
end

--Send our own data from this function
function TInspect:SendUnitData(prio, channel)
	local msg = "S:" .. self.talentStr;
	local p = prio or "NORMAL";
	local c = channel or "RAID";
	ChatThrottleLib:SendAddonMessage(p, "TIN", msg, c);
end

function TInspect.Cache(player, talents)
	TI_Pending:Remove(player);
	TI_Blacklist:Remove(player);
	if (not TI_PlayerCache:Push(player, talents)) then
		error((strf(LE["ERR_CACHE"], player)));
	end
end

function TInspect_InspectTalentFrame_Update()
	if (not initiated or not InspectFrame:IsVisible() or not UnitExists("target")) then
		return;
	end
	
	local tname = UnitName("target");
	local base;
	if (TI_PlayerCache:HasKey(tname) or TInspect_DB_HasKey(tname)) then
		local tdata, tcint, ttalents;
		
		--Get target data (tdata) from cache or DB
		if (TI_PlayerCache:HasKey(tname)) then
			tdata = TI_PlayerCache["cache"][tname];
		else
			tdata = TInspect_DB["savedData"][tname];
		end
		
		tcint = tonumber(string.sub(tdata["talents"], 1, 1));
		TI_TCInt = tcint;
		ttalents = string.sub(tdata["talents"], 2);
		
		--Handle buttons/active tab
		for i = 1, 3 do
			local button = getglobal("TInspect_InspectTalentFrameButton" .. i);
			local name = TInspect_GetTalentTabInfo(tcint, i);
			button:SetText(name);
			button:Show();
		end
		
		--Get the talent set from the string that we are gonna use
		local talents, numTalents;
		local prevNumTalents = 0;
		for i = 1, TI_ActiveTalentTab do
			numTalents = TInspect_GetNumTalents(tcint, i);
			talents = string.sub(ttalents, prevNumTalents + 1, numTalents + prevNumTalents);
			prevNumTalents = prevNumTalents + numTalents;
		end
		
		--Handle background stuff
		local activeName, activeBackground = TInspect_GetTalentTabInfo(tcint, TI_ActiveTalentTab);
		base = BASE_TALENT_BACKGROUND_PATH .. activeBackground .. "-";
		TInspect_InspectTalentFrameBackgroundTopLeft:SetTexture(base .. "TopLeft");
		TInspect_InspectTalentFrameBackgroundTopRight:SetTexture(base .. "TopRight");
		TInspect_InspectTalentFrameBackgroundBottomLeft:SetTexture(base .. "BottomLeft");
		TInspect_InspectTalentFrameBackgroundBottomRight:SetTexture(base .. "BottomRight");
		
		--Handle buttons
		local pointCounter = 0;
		for i = 1, 20 do
			local button = getglobal("TI_TalentFrameTalent" .. i);
			if (i <= numTalents) then
				local t = TInspect_GetTalentInfo(tcint, TI_ActiveTalentTab, i);
				local rank = tonumber(string.sub(talents, i, i));
				getglobal("TI_TalentFrameTalent" .. i .. "Rank"):SetText(rank);
				TInspect_SetTalentPosition(button, t.col, t.row);
				local texture = BASE_ICON_PATH .. t.icon;
				SetItemButtonTexture(button, texture);
				
				if (rank and rank > 0) then
					SetItemButtonDesaturated(button, nil);
					pointCounter = pointCounter + rank;
					if (rank < t.maxrank) then
						getglobal("TI_TalentFrameTalent" .. i .. "Slot"):SetVertexColor(0.1, 1.0, 0.1);
						getglobal("TI_TalentFrameTalent" .. i .. "Rank"):SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
					else
						getglobal("TI_TalentFrameTalent" .. i .. "Slot"):SetVertexColor(1.0, 0.82, 0);
						getglobal("TI_TalentFrameTalent" .. i .. "Rank"):SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
					end
					getglobal("TI_TalentFrameTalent" .. i .. "RankBorder"):Show();
					getglobal("TI_TalentFrameTalent" .. i .. "Rank"):Show();
				else
					SetItemButtonDesaturated(button, 1, 0.65, 0.65, 0.65);
					getglobal("TI_TalentFrameTalent" .. i .. "Slot"):SetVertexColor(0.5, 0.5, 0.5);
					getglobal("TI_TalentFrameTalent" .. i .. "RankBorder"):Hide();
					getglobal("TI_TalentFrameTalent" .. i .. "Rank"):Hide();
				end
				
				button:Show();
			else
				button:Hide();
			end
		end
		
		--Set message
		TInspect_InspectTalentFrameMessage:SetText(activeName .. " - " .. pointCounter);
		
		--TODO: Handle arrows?
		
		TI_TalentFrameScrollFrame:UpdateScrollChildRect();
	else
		--Hide buttons
		for i = 1, 3 do
			getglobal("TInspect_InspectTalentFrameButton" .. i):Hide();
		end
		for i = 1, 20 do
			getglobal("TI_TalentFrameTalent" .. i):Hide();
		end
		
		--Reset tab
		TI_ActiveTalentTab = 1;
		TI_TCInt = 1;
		
		--Show default background
		base = BASE_TALENT_BACKGROUND_PATH .. "MageFire-";
		TInspect_InspectTalentFrameBackgroundTopLeft:SetTexture(base .. "TopLeft");
		TInspect_InspectTalentFrameBackgroundTopRight:SetTexture(base .. "TopRight");
		TInspect_InspectTalentFrameBackgroundBottomLeft:SetTexture(base .. "BottomLeft");
		TInspect_InspectTalentFrameBackgroundBottomRight:SetTexture(base .. "BottomRight");
		
		--Print temp messages
		if (TI_Pending:HasKey(tname)) then
			TInspect_InspectTalentFrameMessage:SetText(L["TAR_PENDING"]);
		elseif (TI_Blacklist:HasKey(tname)) then
			TInspect_InspectTalentFrameMessage:SetText(L["TAR_BLACKLISTED"]);
		elseif (not InParty()) then
			TInspect_InspectTalentFrameMessage:SetText(L["NOT_IN_PARTY"]);
		end
	end
end

function TInspect_SetTalentPosition(button, col, row)
	col = ((col - 1) * 63) + TI_INITIAL_TALENT_OFFSET_X;
	row = -((row - 1) * 63) - TI_INITIAL_TALENT_OFFSET_Y;
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", col, row);
end

function TInspect_TalentFrameTalent_OnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
	GameTooltip:SetText(TInspect_GetTalentInfo(TI_TCInt, TI_ActiveTalentTab, this:GetID()).name);
end

-----------------------------------------------------------------------

--------------------------Overloaded Functions-------------------------

function TInspect_InspectFrame_Show(unit)
	HideUIPanel(InspectFrame);
	if (CanInspect(unit)) then
		NotifyInspect(unit);
		InspectFrame.unit = unit;
		ShowUIPanel(InspectFrame);
		TInspect:GetUnitData(unit);
		TInspect_InspectTalentFrame_Update();
	end
end

function TInspect_InspectFrame_OnUpdate()
	TInspect.timeSinceLastFrameUpdate = TInspect.timeSinceLastFrameUpdate + arg1;
	if (not UnitExists("target")) then
		HideUIPanel(InspectFrame);
		TI_ActiveTalentTab = 1;
	elseif (TInspect.timeSinceLastFrameUpdate > TInspect.FRAME_UPDATE_INTERVAL) then
		TInspect_InspectTalentFrame_Update();
		TInspect.timeSinceLastFrameUpdate = 0;
	end
end

function TInspect_InspectFrame_OnEvent(event)
	if (not this:IsVisible()) then
		return;
	end
	if (event == "PLAYER_TARGET_CHANGED" or event == "PARTY_MEMBERS_CHANGED") then
		InspectUnit(this.unit);
		TInspect:GetUnitData(this.unit);
		TInspect_InspectTalentFrame_Update();
		return;
	elseif (event == "UNIT_PORTRAIT_UPDATE") then
		if (arg1 == this.unit) then
			SetPortraitTexture(InspectFramePortrait, arg1);
		end
		return;
	elseif (event == "UNIT_NAME_UPDATE") then
		if (arg1 == this.unit) then
			local name = UnitName(arg1);
			InspectNameText:SetText(name);
		end
		return;
	end
end

function TInspect_ToggleInspect(tab)
	local subFrame = getglobal(tab);
	if (subFrame) then
		PanelTemplates_SetTab(InspectFrame, subFrame:GetID());
		if (InspectFrame:IsVisible()) then
			if (subFrame:IsVisible()) then
				HideUIPanel(InspectFrame); 
			else
				PlaySound("igCharacterInfoTab");
				InspectFrame_ShowSubFrame(tab);
			end
		else
			ShowUIPanel(InspectFrame);
			InspectFrame_ShowSubFrame(tab);
		end
	end
end

function TInspect_InspectFrameTab_OnClick()
	if (this:GetName() == "InspectFrameTab1") then
		ToggleInspect("InspectPaperDollFrame");
	elseif (this:GetName() == "InspectFrameTab2") then
		ToggleInspect("InspectHonorFrame");
	elseif (this:GetName() == "InspectFrameTab3") then
		ToggleInspect("InspectTalentFrame");
		TInspect_InspectTalentFrame_Update();
	end
	PlaySound("igCharacterInfoTab");
end
