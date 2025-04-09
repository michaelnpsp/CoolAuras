----------------------------------------------------------------
-- Options Table for CoolAuras Addon
----------------------------------------------------------------

local addon = CoolAuras

local isClassic = addon.isClassic

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

----------------------------------------------------------------
-- More user friendly Names
----------------------------------------------------------------

local L = {
	AURA = 'Aura',
	COOLDOWN = 'Cooldown',
	INCANTERFLOW = 'Incanter Flow',
}

----------------------------------------------------------------
-- Appearance fields
----------------------------------------------------------------
APPEARANCE_FIELDS = {
	'buttonSize',
	'buttonSpacing',
	'buttonBorderSize',
	'buttonBorderColor',
	'timerNoMasque' ,
	'timerFontName' ,
	'timerFontColor',
	'timerFontSize' ,
	'timerFontFlags',
	'timerJustifyH' ,
	'timerJustifyV' ,
	'timerAdjustX'  ,
	'timerAdjustY'  ,
	'countNoMasque' ,
	'countFontName' ,
	'countFontColor',
	'countFontSize' ,
	'countFontFlags',
	'countJustifyH' ,
	'countJustifyV' ,
	'countAdjustX'  ,
	'countAdjustY'  ,
}
----------------------------------------------------------------
-- New Groups & Buttons templates
----------------------------------------------------------------
local TEMPLATES = {
	GROUP = {
		left = 0,
		top = 0,
		anchorTo      = 'CENTER',
		buttonAnchor  = 'LEFT',
		buttonSize    = 32,
		buttonSpacing = 2,
		buttonBorderSize = 1,
		buttonBorderColor = {0,0,0,1},
		timerNoMasque  = false,
		timerFontName  = 'Friz Quadrata TT',
		timerFontColor = {1,1,1},
		timerFontSize  =  12,
		timerFontFlags = 'OUTLINE',
		timerJustifyH  = 'CENTER',
		timerJustifyV  = 'MIDDLE',
		timerAdjustX   = 0,
		timerAdjustY   = 0,
		countNoMasque  = false,
		countFontName  = 'Friz Quadrata TT',
		countFontColor = {1,1,1},
		countFontSize  =  10,
		countFontFlags = 'OUTLINE',
		countJustifyH  = 'RIGHT',
		countJustifyV  = 'BOTTOM',
		countAdjustX   = -1,
		countAdjustY   = 1,
	},
	-- AURAS GROUP SPECIFIC OPTIONS
	AURAS = { type = 'AURAS', unit = 'player', filter = 'HELPFUL', buttonCount = 5, },
	-- CUSTOM GROUP SPECIFIC OPTIONS
	MISC = { type = 'MISC' },
}
local BUTTONS = {}

----------------------------------------------------------------
-- Database & options pointers
----------------------------------------------------------------

-- general options database
local general = addon.db.general
-- groups database
local groups  = addon.db.groups
-- selected group database
local group
-- selected button database
local button
-- buttons list aceoptions table
local optbuttons

----------------------------------------------------------------
-- Misc util functions & variables
----------------------------------------------------------------

local function CopyTable(src, dst)
	if type(dst)~="table" then dst = {} end
	for k,v in next,src do
		if type(v)=="table" then
			dst[k] = CopyTable(v,dst[k])
		elseif not dst[k] then
			dst[k] = v
		end
	end
	return dst
end

-- Helper variables to create new bar groups
local newGroupType

---- Button Types
local buttonTypes = { AURA = 'Aura', COOLDOWN = 'Cooldown' }
if addon.playerClass == 'MAGE' and not isClassic then
	buttonTypes.INCANTERFLOW = (GetSpellInfo(116267)) or 'Incanter Flow'
	buttonTypes.ARCANECHARGES = (GetSpellInfo(36032)) or 'Arcane Charges'
end


-- Class & Spec Information
local classTalents
local classNames = {}
local classSpecs = {}
local classNameToID = {}
if isClassic then
	classNames = {
		WARRIOR = string.format("|c%sWarrior|r", RAID_CLASS_COLORS.WARRIOR.colorStr),
		PALADIN = string.format("|c%sPaladin|r", RAID_CLASS_COLORS.PALADIN.colorStr),
		HUNTER  = string.format("|c%sHunter|r",  RAID_CLASS_COLORS.HUNTER.colorStr),
		ROGUE   = string.format("|c%sRogue|r",   RAID_CLASS_COLORS.ROGUE.colorStr),
		PRIEST  = string.format("|c%sPriest|r",  RAID_CLASS_COLORS.PRIEST.colorStr),
		SHAMAN  = string.format("|c%sShaman|r",  RAID_CLASS_COLORS.SHAMAN.colorStr),
		MAGE    = string.format("|c%sMage|r",    RAID_CLASS_COLORS.MAGE.colorStr),
		WARLOCK = string.format("|c%sWarlock|r", RAID_CLASS_COLORS.WARLOCK.colorStr),
		DRUID   = string.format("|c%sDruid|r",   RAID_CLASS_COLORS.DRUID.colorStr),
	}
	classNameToID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 6, MAGE = 7, WARLOCK = 8, DRUID = 9 }
	classSpecs[addon.playerClass] = {}
else
	for i=GetNumClasses(),1,-1 do
		local classNameLoc, className, classID = GetClassInfo(i)
		classNameToID[className] = classID
		classNames[className]    = string.format( "|c%s%s|r", RAID_CLASS_COLORS[className].colorStr, classNameLoc )
		classSpecs[className]    = {}
		for i=GetNumSpecializationsForClassID(classID),1,-1 do
			local _, specName, _, icon = GetSpecializationInfoForClassID(classID, i);
			if specName then
				classSpecs[className][specName] = string.format( "|T%s:0|t %s", icon, specName )
			end
		end
	end
end

local GetClassTalents
if isClassic then
	local MAX_TALENT_TABS = 5
	local MAX_NUM_TALENTS = 20
	GetClassTalents = function(class)
		if not classTalents then
			classTalents = { undefined = {} }
			classTalents[addon.playerClass] = {}
			for i=1,MAX_TALENT_TABS do
				for j=1,MAX_NUM_TALENTS do
					classTalents.undefined[ (i-1)*MAX_TALENT_TABS+j ] = string.format("Tab %d - %d", i,j)
				end
			end
		end
		local talents = classTalents[class]
		if talents then
			talents = talents[0]
			if not talents then
				talents = {}
				classTalents[class][0] = talents
				for tab = 1, GetNumTalentTabs() do
					for id = 1, GetNumTalents(tab) do
						local name, icon = GetTalentInfo(tab, id)
						talents[(tab-1)*MAX_NUM_TALENTS+id] = string.format("|T%s:0|t %s", icon, name)
					end
				end
			end
		end
		return talents or classTalents.undefined
	end
else
	GetClassTalents = function(class, spec)
		if not classTalents then
			classTalents = { undefined = {} }
			classTalents[addon.playerClass] = {}
			for i=1,MAX_TALENT_TIERS do
				for j=1,NUM_TALENT_COLUMNS do
					classTalents.undefined[ (i-1)*3+j ] = string.format("Tier %d - %d", i,j)
				end
			end
		end
		local talents = classTalents[class]
		if talents then
			talents = talents[spec]
			if not talents then
				local specID = GetSpecialization()
				if specID and spec == select(2,GetSpecializationInfo(specID)) then
					talents = {}
					classTalents[class][spec] = talents
					local specGroup = GetActiveSpecGroup()
					for tier = 1, MAX_TALENT_TIERS do
						for col = 1, NUM_TALENT_COLUMNS do
							local _, name, icon = GetTalentInfo(tier, col, specGroup)
							talents[(tier-1)*3+col] = string.format("|T%s:0|t %s", icon,name)
						end
					end
				end
			end
		end
		return talents or classTalents.undefined
	end
end

-- shapeshift forms
local shapeshiftForms = {}
local shapeshiftDefault
for i=1,GetNumShapeshiftForms() do
   local icon, active, castable, spellID = GetShapeshiftFormInfo(i)
   shapeshiftForms[spellID] = string.format( "|T%s:0|t %s", icon, (GetSpellInfo(spellID)) )
   shapeshiftDefault = shapeshiftDefault or spellID
end
if addon.isWrath and not shapeshiftForms[33891] then
	local name, _, icon = GetSpellInfo(33891)
	shapeshiftForms[33891] = string.format( "|T%s:0|t %s", icon, name )
end

-- Corner Points
local cornerPoints = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

-- Align Points
local alignPoints = {
	TOPLEFT = "TOPLEFT",
	LEFT = "LEFT",
	BOTTOMLEFT = "BOTTOMLEFT",
	TOP = "TOP",
	CENTER = "CENTER",
	BOTTOM = "BOTTOM",
	TOPRIGHT = "TOPRIGHT",
	RIGHT = "RIGHT",
	BOTTOMRIGHT = "BOTTOMRIGHT",
}

-- Fonts
local fontFlagsValues = {
	["NONE"] = "Soft",
	["OUTLINE"] = "Soft Thin",
	["THICKOUTLINE"] = "Soft Thick",
	["MONOCHROME"] = "Sharp",
	["MONOCHROME, OUTLINE"] = "Sharp Thin",
	["MONOCHROME, THICKOUTLINE"] = "Sharp Thick",
}

-- UnitAura Filter management functions
local function StrDel( str, sub )
	local s,c = string.gsub( str, sub,'')
	if c>0 then return s end
end

local function AuraFilterDel( filter, v1, v2 )
	filter = StrDel(filter, '|'..v1) or StrDel(filter, v1..'|') or StrDel(filter, v1) or filter
	if v2 then
		return StrDel(filter, '|'..v2) or StrDel(filter, v2..'|') or StrDel(filter, v2) or filter
	else
		return filter
	end
end

local function AuraFilterGet( filter, v1, v2 )
	return (v1 and strmatch(filter, v1)) or (v2 and strmatch(filter, v2))
end

local function AuraFilterAdd( filter, value)
	return (strfind(filter, value) and filter) or (filter=='' and value) or filter..'|'..value
end

local function AuraFilterSet( filter, value, enabled)
	if enabled then
		return AuraFilterAdd(filter or '',value)
	else
		return AuraFilterDel(filter or '', value)
	end
end

local GroupReload
do
	local queued
	function GroupReload()
		if group and not queued then
			queued = true
			C_Timer.After(0.1, function()
				local bar = addon.bars[group.name]
				if bar then	addon.DestroyBar(bar) end
				addon.ReloadBar(group)
				queued = nil
			end )
		end
	end
end

local function GroupLayout()
	if group and addon.bars[group.name] then
		addon.LayoutBar( addon.bars[group.name] )
	end
end

local function SetSelectedGroup(key)
	group = key and groups[key] or nil
end

local function GroupSetValue(field)
	return group[field]
end

local function GroupGetValue(field, value)
	group[field] = value
end

local function ButtonGetValue(field)
	return button[field]
end

local function ButtonSetValue(field, value)
	button[field] = value
end

local function FormatSpellName(spell, spellID, texture)
	return string.format( "|T%s:0|t %s", texture or GetSpellTexture(spellID or spell) or 'Interface\\GossipFrame\\ActiveLegendaryQuestIcon' , spell )
end

local function FormatItemName(item, itemID)
	return string.format( "|T%s:0|t %s", select(10,GetItemInfo(itemID)) or 'Interface\\GossipFrame\\ActiveLegendaryQuestIcon' , item or itemID)
end

local function FormatButtonName(buttondb)
	if not buttondb.itemID then
		local name = buttondb.spellID and GetSpellInfo(buttondb.spellID) or buttondb.spell
		if not name or strlen(name) == 0 then
			return string.format( "|TInterface\\GossipFrame\\ActiveLegendaryQuestIcon:0|t New %s", L[buttondb.type] )
		else
			return FormatSpellName(name, buttondb.spellID, buttondb.texture)
		end
	end
	return FormatItemName( buttondb.item, buttondb.itemID)
end

local GetGroupList, GetNameKey
do
	local list = {}
	local keys = {}
	function GetNameKey(v)
		if v then return keys[v] end
	end
	function GetGroupList()
		wipe(keys)
		wipe(list)
		for name,db in next, groups do
			local class   = db.displayPlayerClass
			local enabled = addon.GroupDisplayFilter(db)
			local key = string.format( "%s%s===%s", enabled and 'A' or 'B', class == addon.playerClass and 'A' or 'B', name )
			keys[key], keys[name]  = name, key
			list[key] = string.format("|c%s%s|r%s", enabled and "FFFFFFFF" or "FF909090", name, class and string.format( " (%s)",classNames[class] ) or '')
		end
		return list
	end
end

local function GroupCopyAppearance(src)
	if src~=group then
		for _,field in next,APPEARANCE_FIELDS do
			group[field] = src[field]
		end
		GroupReload()
	end
end

local GroupTest
do
	local testName
	function GroupTest()
		local flag = testName ~=  group.name
		if testName then
			local bar = addon.bars[testName]
			if bar then
				for _,button in next,bar.buttons do
					button.Count:SetText( '' )
					button.Timer:SetText( '' )
				end
				addon.UpdateBar(bar)
			end
			testName = nil
		end
		if flag then
			local bar = addon.bars[group.name]
			if bar and #bar.db==0 then
				for _,button in next,bar.buttons do
					button.Icon:SetTexture( "Interface\\Icons\\inv_weapon_hand_30" )
					button.Count:SetText( math.random(99) )
					button.Timer:SetText( math.random(99) )
					button:Show()
				end
				bar.countVisible = #bar.buttons
			end
			testName = group.name
		end
	end
end

-------------------------------------------------------------------------------------
-- CUSTOM GROUP: DYNAMIC BUTTONS OPTIONS GENERATION
-------------------------------------------------------------------------------------

local MakeButtonsOptions, GetButtonOptions, GetButtonKey
do
	local lastKey = 1
	local buttonKey
	local groupbuttons

	local function Tracker(info)
		local key = info[#info-1]
		local optbutton = optbuttons[key]
		if optbutton and optbutton.order>=1 then
			buttonKey = key
			button    = group[optbutton.order]
		end
		return false
	end

	local function MakeButton(buttons, buttondb, index)
		buttons['K'..lastKey] = { type = 'group', order = index, name = FormatButtonName(buttondb), childGroups = "tab", args = {
			General = { type = "group", order = 10, inline = true, name = '', args = BUTTONS[buttondb.type] or {}, hidden = Tracker },
			Display = { type = "group", order = 20, inline = true, name = '', args = BUTTONS.SHARED_OPTIONS , hidden = Tracker },
		} }
		lastKey = lastKey + 1
	end

	function MakeButtonsOptions(force)
		if group~=groupbuttons or (force==true) then
			for k,b in next, optbuttons do
				if b.order>=1 then
					optbuttons[k] = nil
				end
			end
			for i=1,#group do
				MakeButton(optbuttons, group[i], i)
			end
			groupbuttons = group
		end
	end

	function GetButtonKey(info)
		return info[#info-2]
	end

	function GetButtonOptions(order)
		local buttons = optbuttons
		if type(order) == 'number' then
			for k,b in next, buttons do
				if b.order == order then
					return b
				end
			end
		elseif order or buttonKey then
			return buttons[order or buttonKey]
		end
	end

end

----------------------------------------------------------------
-- Default options handler
----------------------------------------------------------------

local newHandler
do
	local handler = {}
	local handler_meta = { __index = handler }

	function handler:Get( info )
		local key = info[#info]
		local db  = self:GetDB(info) -- GetDB method must be provided in newHandler() table parameter
		if db then
			local v = db[key]
			if type(v) == 'table' then
				return unpack(v)
			else
				return v
			end
		end
	end

	function handler:Set(info, v, ...)
		local key = info[#info]
		local db = self:GetDB(info) -- GetDB method must be provided in newHandler() table parameter
		db[key] = info.type == 'color' and { v, ... } or v
		if self.OnChange then self.OnChange(info, v, ...) end
	end

	function handler:Hidden()
		return false
	end

	function newHandler(t)
		return setmetatable( t or {}, handler_meta )
	end

end

----------------------------------------------------------------
-- Options Table
----------------------------------------------------------------

addon.OptionsTable = { name = "Cool Auras", type = "group", childGroups = "tab", get = "Get", set = "Set", args = {
	Group = { type = "group", order = 10, name = 'General', childGroups = "tab",
		-- Group options handler
		handler = newHandler({
			GetDB    = function() return group end,
			Hidden   = function() return not group end,
			OnChange = GroupReload,
		}), args = {
		--- SELECT, CREATE, REMOVE GROUP
		selectedGroup = {
			type = 'select',
			order = 1,
			width = 1.5,
			name = 'Select a Group of Icons',
			get = function() return GetNameKey(group and group.name) end,
			set = function(info, key) SetSelectedGroup( GetNameKey(key)	) end,
			values = GetGroupList,
			hidden = function() return newGroupType or (not next(groups)) end,
		},
		testGroup = {
			type = 'execute',
			order = 1.2,
			width = 'half',
			name = 'Test',
			desc = 'Toggle test mode for this group',
			func = GroupTest,
			hidden = function() return (not group) or newGroupType~=nil or group.type ~= 'AURAS' end,
		},
		renameGroup = {
			type = 'execute',
			order = 1.5,
			width = 'half',
			name = 'Rename',
			desc = 'Rename selected Group',
			func = function() newGroupType = false end,
			hidden = function() return (not group) or newGroupType~=nil end,
		},
		createGroup = {
			type = 'execute',
			order = 15,
			width = 'half',
			name = 'Create',
			desc = 'Create a New Group of Icons',
			func = function() newGroupType = 'AURAS'; end,
			hidden = function() return newGroupType~=nil end,
		},
		newGroupType = {
			type = 'select',
			order = 3,
			name = 'New Group Type',
			get = function() return newGroupType end,
			set = function(info,value) newGroupType = value end,
			values = { AURAS = 'Auras Group', MISC = 'Custom Group' },
			hidden = function() return not newGroupType end,
		},
		newGroupName = {
			type = 'input',
			name = 'Type the Group Name',
			order = 4,
			get = function() return end,
			set = function(info,newGroupName)
				if newGroupType then
					-- Create new Group
					local db = CopyTable( TEMPLATES[newGroupType], CopyTable(TEMPLATES['GROUP']) )
					db.type = newGroupType
					db.name = newGroupName
					groups[newGroupName] = db
					addon.ReloadBar(db)
					SetSelectedGroup(newGroupName)
				else
					-- Rename selected group
					local bar = addon.bars[group.name]
					if bar then addon.DestroyBar(bar) end
					groups[group.name] = nil
					groups[newGroupName] = group
					group.name = newGroupName
					if bar then addon.CreateBar(group) end
				end
				newGroupType = nil
			end,
			hidden = function() return newGroupType==nil end,
			validate = function(info,value) return not groups[value] end,
		},
		newGroupCancel = {
			type = 'execute',
			order = 6,
			width = 'half',
			name = 'Cancel',
			func = function() newGroupType = nil end,
			hidden = function() return newGroupType==nil end,
		},
		deleteGroup = {
			type = 'execute',
			order = 9,
			width = 'half',
			name = 'Delete',
			desc = 'Delete selected Icons Group',
			func = function()
				local bar = addon.bars[group.name]
				if bar then	addon.DestroyBar(bar) end
				groups[group.name] = nil
				SetSelectedGroup( next(groups) )
			end,
			confirm = function() return 'Are you sure you want to delete the selected group ?' end,
			hidden = function() return (not group) or newGroupType end,
		},
		-- GROUP APPEARANCE
		Appearance = { type = "group", order = 20, name = 'Appearance & Position', hidden = "Hidden", childGroups = "tab",
			handler = newHandler({
				GetDB    = function() return group end,
				Hidden   = function() return not group end,
				OnChange = GroupLayout,
			}),
			args = {
				---- Icons Group Layout and appearnce ------------------------------------------
				header1 = { type = 'header', order = 0, name= 'Icons Group'},
				anchorTo = {
					type = 'select', order = 1, name = 'Group Placement', desc = 'Select the Screen Point to Anchor this Group',
					set = function(info,value)
						group.left = 0
						group.top = 0
						group.anchorTo = value
						group.buttonAnchor = strfind(value,'LEFT') and 'LEFT' or 'RIGHT'
						GroupLayout()
					end,
					values = alignPoints,
				},
				left = {
					type = 'range', order = 2, width = 'normal', name = 'Horizontal Adjust', softMin = -512, softMax = 512, step = 1,
				},
				top = {
					type = 'range', order = 3, width = 'normal', name = 'Vertical Adjust', softMin = -512, softMax = 512, step = 2,
				},
				copyLayout = {
					type = "select",
					order = 4,
					name = "Copy Appearance from:",
					values = GetGroupList,
					set = function(info, key) GroupCopyAppearance(groups[GetNameKey(key)]) end,
				},
				buttonAnchor = {
					type = 'select', order = 10, name = 'Icons Flow',
					values = {  LEFT = 'Left to Right', RIGHT ='Right to Left', TOP = 'Top to Bottom', BOTTOM = 'Bottom to Top' },
				},
				buttonSize = {
					type = 'range', order = 20, name = 'Icon Size', min = 1, softMax = 64, step = 1,
				},
				buttonSpacing = {
					type = 'range', order = 30, name = 'Icon Spacing', min = -16, softMin= 0, softMax = 64, step = 1,
				},
				centerButtons = {
					type = 'toggle', order = 35, name = 'Center Icons',
					set = function(info,value)
						group.centerButtons = value or nil
						GroupLayout()
					end,
				},
				-------- Icon Border Appearance Options ------------------------------
				buttonBorderHeader = { type = 'header', name= 'Icons Border' , order = 89, hidden = function() return general.Masque end, },
				buttonBorderSize = {
					type = 'range', order = 90, width = 'normal', name = 'Border Size', min=0, max= 16, step=1,
					hidden = function() return general.Masque end,
				},
				buttonBorderColor = {
					type = 'color',	order = 95, name = 'Border Color', hasAlpha = true,
					disabled = function() return group.buttonBorderSize==0 end,
					hidden = function() return general.Masque end,
				},
				-------- Timer Text Appearance Options ------------------------------
				timerFontHeader = { type = 'header', name= 'Icons Timer Text' , order = 100 },
				timerFontName = {
					type = "select", dialogControl = "LSM30_Font",
					order = 101,
					name = "Font Name",
					values = AceGUIWidgetLSMlists.font,
				},
				timerFontFlags = {
					type = "select",
					order = 102,
					name = "Font Border",
					values = fontFlagsValues,
				},
				timerFontSize = {
					type = "range",
					order = 103,
					name = 'Font Size',
					min = 6,
					softMax = 24,
					step = 1,
				},
				timerFontColor = {
					type = 'color',
					order = 104,
					name = 'Font Color',
					desc = 'Color',
				},
				timerJustifyH = {
					type = "select",
					order = 105,
					name = "JustifyH",
					desc = 'Text Horizontal Justify',
					width = 'half',
					values = { CENTER = 'CENTER', LEFT = 'LEFT', RIGHT = 'RIGHT', },
					disabled = function() return addon.Masque and not group.timerNoMasque end,
				},
				timerJustifyV = {
					type = "select",
					order = 106,
					name = "JustifyV",
					desc = 'Text Vertical Justify',
					width = 'half',
					values = { MIDDLE = 'CENTER', TOP = 'TOP', BOTTOM = 'BOTTOM', },
					disabled = function() return addon.Masque and not group.timerNoMasque end,
				},
				timerAdjustX = {
					type = "range",
					order = 107,
					step = 1,
					softMin = -32,
					softMax = 32,
					name = "Horizontal Adjust",
					disabled = function() return addon.Masque and not group.timerNoMasque end,
				},
				timerAdjustY = {
					type = "range",
					order = 108,
					step = 1,
					softMin = -32,
					softMax = 32,
					name = "Vertical Adjust",
					disabled = function() return addon.Masque and not group.timerNoMasque end,
				},
				timerNoMasque = {
					type = 'toggle', order = 120, name = 'Use Masque', desc = 'Let Masque addon to layout the Timer Text',
					get = function() return not group.timerNoMasque end,
					set = function(info,value)
						group.timerNoMasque = (not value) or nil
						GroupLayout()
					end,
					hidden = function() return not addon.Masque end,
				},
				-------- Count Text Appearance Options ------------------------------
				countHeaderFont = { type = 'header', name= 'Icons Count Text' , order = 200 },
				countFontName = {
					type = "select", dialogControl = "LSM30_Font",
					order = 201,
					name = "Font Name",
					values = AceGUIWidgetLSMlists.font,
				},
				countFontFlags = {
					type = "select",
					order = 202,
					name = "Font Border",
					values = fontFlagsValues,
				},
				countFontSize = {
					type = "range",
					order = 203,
					name = 'Font Size',
					min = 6,
					softMax = 24,
					step = 1,
				},
				countFontColor = {
					type = 'color',
					name = 'Font Color',
					desc = 'Color',
					order = 204,
				},
				countJustifyH = {
					type = "select",
					order = 206,
					width = 'half',
					name = "JustifyH",
					desc = 'Text Horizontal Justify',
					values = { CENTER = 'CENTER', LEFT = 'LEFT', RIGHT = 'RIGHT', },
					disabled = function() return addon.Masque and not group.countNoMasque end,
				},
				countJustifyV = {
					type = "select",
					order = 207,
					width = 'half',
					name = "JustifyV",
					desc = 'Text Vertical Justify',
					values = { MIDDLE = 'CENTER', TOP = 'TOP', BOTTOM = 'BOTTOM', },
					disabled = function() return addon.Masque and not group.countNoMasque end,
				},
				countAdjustX = {
					type = "range",
					order = 208,
					step = 1,
					softMin = -32,
					softMax = 32,
					name = "Horizontal Adjust",
					disabled = function() return addon.Masque and not group.countNoMasque end,
				},
				countAdjustY = {
					type = "range",
					order = 209,
					step = 1,
					softMin = -32,
					softMax = 32,
					name = "Vertical Adjust",
					disabled = function() return addon.Masque and not group.countNoMasque end,
				},
				countNoMasque = {
					type = 'toggle', order = 210, name = 'Use Masque', desc = 'Let Masque addon to layout the Timer Text',
					get = function() return not group.countNoMasque end,
					set = function(info,value)
						group.countNoMasque = (not value) and true or nil
						GroupLayout()
					end,
					hidden = function() return not addon.Masque end,
				},
			},
		},
		-- GROUP DISPLAY CONDITIONS
		Display = { type = "group", order = 30, name = 'Display Conditions', hidden = "Hidden", args = {
			sep1 = { type = 'header', order = 0, name = 'Filters', width = 'full' },
			displayCombatEnabled ={
				type = 'toggle',
				order = 1,
				name = 'Combat Status',
				get = function(info)
					return group.displayCombat ~= nil
				end,
				set = function(info,value)
					group.displayCombat = value or nil
					GroupReload()
				end,
			},
			displayCombat = {
				type = 'select',
				order = 2,
				name = 'Combat Status',
				values = { [0] = 'Out of Combat', [1] = 'In Combat' },
				get = function()
					return (group.displayCombat==true and 1) or (group.displayCombat==false and 0) or nil
				end,
				set = function(info,value)
					group.displayCombat = (value==1)
					GroupReload()
				end,
				disabled = function(info)
					return group.displayCombat == nil
				end,
			},
			sep1 = { type = 'description', order = 10, name = "" },
			displayPlayerNameEnabled ={
				type = 'toggle',
				order = 11,
				name = 'Player Name',
				get = function(info)
					return group.displayPlayerName ~= nil
				end,
				set = function(info,value)
					group.displayPlayerName = value and addon.playerName or nil
					GroupReload()
				end,
			},
			displayPlayerName = {
				type = 'input',
				order = 12,
				name = 'Player Name',
				set = function(info,value)
					group.displayPlayerName = value
					GroupReload()
				end,
				disabled = function(info)
					return not group.displayPlayerName
				end,
			},
			sep2 = { type = 'description', order = 20, name = "" },
			displayPlayerRoleEnabled ={
				type = 'toggle',
				order = 21,
				name = 'Player Role',
				get = function()
					return group.displayPlayerRole ~= nil
				end,
				set = function(info,value)
					group.displayPlayerRole = value and addon.playerRole or nil
					GroupReload()
				end,
				hidden = function()	return isClassic end,
			},
			displayPlayerRole = {
				type = 'select',
				order = 22,
				name = 'Player Role',
				set = function(info,value)
					group.displayPlayerRole = value
					GroupReload()
				end,
				values = { HEALER = 'HEALER', DAMAGER = 'DAMAGER', TANK = 'TANK' },
				disabled = function(info)
					return not group.displayPlayerRole
				end,
				hidden = function()	return isClassic end,
			},
			sep3 = { type = 'description', order = 30, name = "" },
			displayPlayerClassEnabled ={
				type = 'toggle',
				order = 31,
				name = 'Player Class',
				get = function(info)
					return group.displayPlayerClass ~= nil
				end,
				set = function(info,value)
					group.displayPlayerClass = value and addon.playerClass or nil
					group.displayPlayerSpec = nil
					group.displayPlayerTalent = nil
					GroupReload()
				end,
			},
			displayPlayerClass = {
				type = 'select',
				order = 32,
				name = 'Player Class',
				values = classNames,
				set = function(info,value)
					group.displayPlayerClass = value
					group.displayPlayerSpec = nil
					group.displayPlayerTalent = nil
					GroupReload()
				end,
				disabled = function(info)
					return not group.displayPlayerClass
				end,
			},
			sep4 = { type = 'description', order = 40, name = "" },
			displayPlayerSpecEnabled ={
				type = 'toggle',
				order = 41,
				name = 'Player Spec',
				get = function(info)
					return group.displayPlayerSpec ~= nil
				end,
				set = function(info,value)
					if value then
						if group.displayPlayerClass == addon.playerClass and addon.playerSpec then
							group.displayPlayerSpec = addon.playerSpec
						else
							group.displayPlayerSpec = next( classSpecs[ group.displayPlayerClass ] )
						end
					else
						group.displayPlayerSpec = nil
						group.displayPlayerTalent = nil
					end
					GroupReload()
				end,
				hidden = function(info)
					return isClassic or not group.displayPlayerClass
				end,
			},
			displayPlayerSpec = {
				type  = 'select',
				order = 42,
				name  = 'Player Specialization',
				set = function(info,value)
					group.displayPlayerSpec = value
					GroupReload()
				end,
				values = function()
					return classSpecs[ group.displayPlayerClass ]
				end,
				hidden = function()
					return isClassic or not group.displayPlayerClass
				end,
				disabled = function()
					return isClassic or not group.displayPlayerSpec
				end,
			},
			sep5 = { type = 'description', order = 50, name = "" },
			displayPlayerTalentEnabled ={
				type = 'toggle',
				order = 51,
				name = 'Player Talent',
				get = function(info)
					return group.displayPlayerTalent ~= nil
				end,
				set = function(info,value)
					group.displayPlayerTalent = value and 1 or nil
					GroupReload()
				end,
				hidden = function(info)
					return not group.displayPlayerSpec and not isClassic
				end,
			},
			displayPlayerTalent = {
				type = 'select',
				order = 52,
				name = 'Talent',
				set = function(info,value)
					group.displayPlayerTalent = value
					GroupReload()
				end,
				values = function()
					return GetClassTalents(group.displayPlayerClass, group.displayPlayerSpec)
				end,
				disabled = function()
					return not group.displayPlayerTalent
				end,
				hidden = function()
					return not group.displayPlayerSpec and not isClassic
				end,
			},
			sep6 = { type = 'description', order = 60, name = "" },
			displayPlayerShapeshiftEnabled ={
				type = 'toggle',
				order = 61,
				name = 'Player Shapeshift',
				get = function(info)
					return group.displayPlayerShapeshift ~= nil
				end,
				set = function(info,value)
					group.displayPlayerShapeshift = value and shapeshiftDefault or nil
					GroupReload()
				end,
			},
			displayPlayerShapeshift = {
				type = 'select',
				order = 62,
				name = 'Shapeshift Form',
				set = function(info,value)
					group.displayPlayerShapeshift = value
					GroupReload()
				end,
				values = shapeshiftForms,
				disabled = function()
					return not group.displayPlayerShapeshift
				end,
			},
		} },
		-- AURAS GROUP CONFIGURATION
		GroupAuras = { type = "group", order = 10, name = 'Auras Configuration',
			hidden = function()
				return not (group and group.type=='AURAS')
			end,
			args = {
				header =  { type = 'header', order = 0, name = 'Auras to Display' },
				auraType = {
					type = 'select', order = 10, name = 'Type',  -- width = 'half',
					get = function()
						return AuraFilterGet( group.filter, 'HARMFUL' ) or 'HELPFUL'
					end,
					set = function(info,value)
						group.filter = AuraFilterSet(group.filter, 'HELPFUL', value=='HELPFUL')
						group.filter = AuraFilterSet(group.filter, 'HARMFUL', value=='HARMFUL')
						group.cancelBuffs = nil
						group.consolidatedFilter = nil
						group.showRaidBuffTray = nil
						GroupReload()
					end,
					values = { HELPFUL = 'BUFFS',  HARMFUL = 'DEBUFFS' },
				},
				unit = {
					type = 'select', order = 20, name = 'Unit', -- width = 'half',
					values = { player = 'player', target = 'target', focus = 'focus' },
					set = function(info,value)
						group.unit = value
						group.cancelBuffs = nil
						group.consolidatedFilter = nil
						group.showRaidBuffTray = nil
						GroupReload()
					end,
				},
				buttonCount = {
					type = 'range', order = 30, name = 'Max Auras', desc = 'Maximum number of auras to display.',
					min = 1, max = 40, step = 1,
				},
				timeThreshold = {
					type = 'range', order = 35, name = 'Time Left Threshold', desc = 'Threshold in seconds to display the time left text. Set zero to disable the time left text.',
					min = 0, softMax = 180, step = 1,
					get = function() return group.timeThreshold or 60 end,
				},
				showTooltips = {
					type = 'toggle', order = 41, name = 'Display Tooltips', desc = 'Show Aura Tooltip on Mouse Over',
					set = function(info,value)
						group.showTooltips = value or nil
						GroupReload()
					end,
				},
				showRaidBuffTray = {
					type = 'toggle', order = 45, name = 'Display Buffs Tray', desc = 'Display Consolidated Raid Buffs Tray Icon.',
					set = function(info,value)
						if value then
							group.showRaidBuffTray = true
							group.consolidatedFilter = nil
						else
							group.showRaidBuffTray = nil
						end
						GroupReload()
					end,
					hidden = function() return group.unit~='player' or AuraFilterGet( group.filter, 'HARMFUL' )~=nil end,
				},
				cancelBuffs = {
					type = 'toggle', order = 46, name = 'Cancelable Buffs',
					desc = 'Enable Buffs cancellation using Mouse Right Clicks. Only works out of combat.',
					set = function(info,value)
						group.cancelBuffs = value or nil
						GroupReload()
					end,
					hidden = function() return group.unit~='player' or strfind(group.filter or '','HARMFUL') end,
				},
				--- Other Filters Section ---
				otherFilters =  { type = 'header', order = 50, name = 'Additional Filters' },
				enableCaster = {
					type = 'toggle', order = 51, name = 'Caster',
					get = function() return group.casterFilter~=nil end,
					set = function(info,value)
						group.casterFilter = value or nil
						group.filter = AuraFilterSet( group.filter, 'PLAYER', value)
						GroupReload()
					end,
				},
				enableCancelable = {
					type = 'toggle', order = 52, width = 'normal', name = 'Cancelable Auras',
					get = function() return not not AuraFilterGet( group.filter, 'NOT_CANCELABLE', 'CANCELABLE' ) end,
					set = function(info,value)
						if value then
							group.filter = AuraFilterAdd(group.filter, 'CANCELABLE')
						else
							group.filter = AuraFilterDel(group.filter, 'NOT_CANCELABLE', 'CANCELABLE')
						end
						GroupReload()
					end,
				},
				enableConsolidated = {
					type = 'toggle', order = 53, width = 'normal', name = 'Consolidated Buffs',
					get = function() return group.consolidatedFilter~=nil end,
					set = function(info,value)
						group.consolidatedFilter = value or nil;
						GroupReload()
					end,
					hidden = function() return group.unit~='player' or group.showRaidBuffTray or strfind(group.filter or '','HARMFUL') end,
				},
				enableTimeLeft = {
					type = 'toggle', order = 54, width = 'normal', name = 'Time Left',
					get = function() return group.timeLeftFilter~=nil end,
					set = function(info,value)
						group.timeLeftFilter = value and 0 or nil;
						GroupReload()
					end,
				},
				enableDuration = {
					type = 'toggle', order = 55, width = 'normal', name = 'Duration',
					get = function() return group.durationFilter~=nil end,
					set = function(info,value)
						group.durationFilter = value or nil
						GroupReload()
					end,
				},
				enableWhiteList = {
					type = 'toggle', order = 56, width = 'normal', name = 'WhiteList',
					get = function() return group.isBlackList==false end,
					set = function(info,value)
						if value then
							group.isBlackList = false
						else
							group.isBlackList = nil
						end
						GroupReload()
					end,
				},
				enableBlackList = {
					type = 'toggle', order = 57, width = 'normal', name = 'BlackList',
					get = function() return group.isBlackList==true end,
					set = function(info,value)
						group.isBlackList = value and true or nil
						GroupReload()
					end,
				},
				------- Filters Conditions ----
				casterHeader = { type = 'header', order = 70, name = 'Filters Conditions', hidden = function()
					return group.casterFilter==nil and group.consolidatedFilter == nil and not AuraFilterGet(group.filter, 'NOT_CANCELABLE', 'CANCELABLE')
				end },
				casterCondition = {
					type = 'select', order = 75, name = 'Display (Caster)',
					get = function()
						return group.casterFilter and 1 or 2
					end,
					set = function(info,value)
						group.casterFilter = (value==1)
						group.filter = AuraFilterSet( group.filter, 'PLAYER', value==1)
						GroupReload()
					end,
					values = { [1] = 'Auras casted By Me', [2] = 'Auras casted by Others' },
					hidden = function() return group.casterFilter==nil end,
				},
				cancelableFilter = {
					type = 'select', order = 76, name = 'Display (Cancelable)',
					get = function()
						return AuraFilterGet( group.filter, 'NOT_CANCELABLE', 'CANCELABLE' )
					end,
					set = function(info,value)
						group.filter = AuraFilterSet(group.filter, 'NOT_CANCELABLE', value=='NOT_CANCELABLE')
						group.filter = AuraFilterSet(group.filter, 'CANCELABLE',     value=='CANCELABLE')
						GroupReload()
					end,
					values = { CANCELABLE = 'Cancelable auras', NOT_CANCELABLE = 'Non Cancelable auras' },
					hidden = function()	return not AuraFilterGet(group.filter, 'NOT_CANCELABLE', 'CANCELABLE') end,
				},
				consolidatedFilter = {
					type = 'select', order = 77, name = 'Display (Consolidated)',
					get = function() return group.consolidatedFilter	and 2 or 1 end,
					set = function(info,value)
						group.consolidatedFilter = (value==2)
						GroupReload()
					end,
					values = { 'Non Consolidated Buffs', 'Consolidated Buffs' },
					hidden = function()	return group.consolidatedFilter == nil or group.showRaidBuffTray end,
				},
				---- TimeLeft Condition
				timeLeftHeader = { type = 'header', order = 80, name = 'Time Left Filter', hidden = function() return not group.timeLeftFilter end },
				timeLeftCondition = {
					type = 'select',
					order = 90,
					name = 'Aura Time Left',
					get = function() return group.timeLeftFilter>=0 and 2 or 1 end,
					set = function(info,value)
						group.timeLeftFilter = math.abs(group.timeLeftFilter or 0) * (value==2 and 1 or -1)
						GroupReload()
					end,
					values = { [1] = 'Less than', [2] = 'Greater than' },
					hidden = function() return not group.timeLeftFilter end,
				},
				timeLeftMinutes = {
					type = "range",
					order = 100,
					name = 'Minutes',
					min = 0,
					softMax = 120,
					step = 1,
					get = function() return math.floor( math.abs(group.timeLeftFilter or 0) / 60 ) end,
					set = function(info,value)
						value = (value*60 + math.abs(group.timeLeftFilter) % 60)
						group.timeLeftFilter = group.timeLeftFilter>=0 and value or -value
						GroupReload()
					end,
					hidden = function() return not group.timeLeftFilter end,
				},
				timeLeftSeconds = {
					type = "range",
					order = 110,
					name = 'Seconds',
					min = 0,
					max = 59,
					step = 1,
					get = function() return math.abs(group.timeLeftFilter or 0) % 60 end,
					set = function(info,value)
						value = math.floor( math.abs(group.timeLeftFilter) / 60 )*60 + value
						group.timeLeftFilter = group.timeLeftFilter>=0 and value or -value
						GroupReload()
					end,
					hidden = function() return not group.timeLeftFilter end,
				},
				-- Duration Condition
				durationHeader = { type = 'header', order = 120, name = 'Duration Filter', hidden = function() return group.durationFilter==nil end },
				durationCondition = {
					type = 'select',
					order = 130,
					name = 'Aura Duration',
					get = function()
						return (group.durationFilter==true and 4) or (group.durationFilter==false and 3) or (group.durationFilter>=0 and 2) or 1
					end,
					set = function(info,value)
						if value == 1 then
							group.durationFilter = -math.abs( type(group.durationFilter)=='number' and group.durationFilter or 0)
						elseif value == 2 then
							group.durationFilter = math.abs( type(group.durationFilter)=='number' and group.durationFilter or 1)
						else
							group.durationFilter = (value==4)
						end
						GroupReload()
					end,
					values = { [1] = 'Less than', [2] = 'Greater than', [3] = 'Unlimited', [4] = "Limited" },
					hidden = function() return group.durationFilter==nil end,
				},
				durationMinutes = {
					type = "range",
					order = 140,
					name = 'Minutes',
					min = 0,
					softMax = 120,
					step = 1,
					get = function() return math.floor( math.abs( type(group.durationFilter)=='number' and group.durationFilter or 0) / 60 ) end,
					set = function(info,value)
						value = (value*60 + math.abs(group.durationFilter) % 60)
						group.durationFilter = group.durationFilter>=0 and value or -value
						GroupReload()
					end,
					disabled = function() return type(group.durationFilter)~='number' end,
					hidden   = function() return group.durationFilter==nil end,
				},
				durationSeconds = {
					type = "range",
					order = 150,
					name = 'Seconds',
					min = 0,
					max = 59,
					step = 1,
					get = function() return math.abs(type(group.durationFilter)=='number' and group.durationFilter or 0) % 60 end,
					set = function(info,value)
						value = math.floor( math.abs(group.durationFilter) / 60 )*60 + value
						group.durationFilter = group.durationFilter>=0 and value or -value
						GroupReload()
					end,
					disabled = function() return type(group.durationFilter)~='number' end,
					hidden   = function() return group.durationFilter==nil end,
				},
				-- WhiteList & BlackList Conditions
				spellsHeader1 = { type = 'header', order = 500, name = 'WhiteList Filter', hidden = function() return not (group.isBlackList==false) end },
				spellsHeader2 = { type = 'header', order = 500, name = 'BlackList Filter', hidden = function() return not (group.isBlackList==true) end },
				spells = {
					type = 'input',
					order = 510,
					name = '',
					width = 'full',
					multiline = 7,
					set = function(info,value)
						group.spells = value
						GroupReload()
					end,
					hidden = function()	return group.isBlackList==nil end
				},
			},
		},
		-- CUSTOM GROUP CONFIGURATION
		GroupCustom = {  type = "group", order = 10, name = 'Icons Configuration', hidden = "Hidden",
			handler = newHandler({
				GetDB = function(_, info) return group[ optbuttons[GetButtonKey(info)].order ] end,
				Hidden = function()	return not group end,
				OnChange = GroupReload,
			}),
			disabled = MakeButtonsOptions,
			hidden = function() return not (group and group.type == 'MISC') end,
			args = {
				newIcon = {
					type = 'select',
					order = 0,
					name = 'Create a New Icon',
					get = function() end,
					set = function(info, type)
						local butdb = CopyTable(TEMPLATES[type])
						butdb.type = type
						tinsert(group, 1, butdb)
						GroupReload()
						MakeButtonsOptions(true)
					end,
					values = buttonTypes,
				},
				moveUp = {
					type = 'execute',
					order = 0.1,
					name = 'Up',
					desc = 'Move selected Icon Up',
					width = 'half',
					func = function()
						local button = GetButtonOptions()
						if button then
							local i = button.order
							local j = i>1 and i-1 or #group
							group[i], group[j] = group[j], group[i]
							GetButtonOptions(j).order = i
							button.order = j
							GroupReload()
						end
					end,
					hidden = function() return not (group and #group>1) end,
				},
				moveDown = {
					type = 'execute',
					order = 0.2,
					name = 'Down',
					desc = 'Move selected Icon Down',
					width = 'half',
					func = function()
						local button = GetButtonOptions()
						if button then
							local i = button.order
							local j = i<#group and i+1 or 1
							group[i], group[j] = group[j], group[i]
							GetButtonOptions(j).order = i
							button.order = j
							GroupReload()
						end
					end,
					hidden = function() return not (group and #group>1) end,
				},
				delIcon = {
					type = 'execute',
					order = 0.3,
					name = 'Delete',
					desc = 'Delete Selected Icon',
					width = 'half',
					func = function()
						local button = GetButtonOptions()
						if button then
							tremove( group, button.order )
							GroupReload()
							MakeButtonsOptions(true)
						end
					end,
					confirm = function() return 'Are you sure do you want to delete the selected icon ?' end,
					hidden = function() return not (group and #group>0) end,
				},
				--- HERE BUTTONS ARE ADDED DYNAMICALLY
			}
		},
	} },
	Misc  = { type = "group", order = 20, name = 'Miscellaneus', childGroups = "tab", args = {
		enableMinimap = {
			type = 'toggle', order = 5, width = 'full', name = 'Display Minimap Icon',
			get = function() return not addon.db.minimap.hide end,
			set = function(info,value)
				addon.db.minimap.hide = (not addon.db.minimap.hide) or nil
				local LDBI = LibStub("LibDBIcon-1.0")
				LDBI[value and 'Show' or 'Hide'](LDBI, 'CoolAuras')
			end,
		},
		enableMasque = {
			type = 'toggle', order = 10, width = 'full', name = 'Enable Masque support',
			get = function() return general.Masque end,
			set = function(info,value)
				general.Masque = value
				if value then
					addon.EnableMasque()
					addon.DestroyBars()
					addon.ReloadBars()
				else
					ReloadUI()
				end
			end,
			confirm = function(info,value)
				if value then return false end
				return 'UI must be reloaded to disable Masque support. Are you sure ?'
			end,
		},
		disableBlizzard = {
			type = 'toggle', order = 20, width ='full', name = 'Hide Blizzard Buff Frames',
			get = function() return general.disableBlizzard end,
			set = function(info,value)
				general.disableBlizzard = value
				if value then
					addon.HideBlizzardFrames()
				else
					ReloadUI()
				end
			end,
			confirm = function(info,value)
				return (not value) and 'UI will be reloaded to Reenable Blizzard Buff Frames. Are you sure ?'
			end,
		}
	} },
	About  = { type = "group", order = 30, name = 'About', childGroups = "tab", args = {
		tit = {
			type  = "description", order = 10, width = "full", fontSize = "large",
			image = "Interface\\Addons\\CoolAuras\\icon", imageWidth  = 30, imageHeight = 30, imageCoords = { 0.05, 0.95, 0.05, 0.95 },
			name  = string.format("%sCoolAuras v%s|r\nWelcome to CoolAuras", NORMAL_FONT_COLOR_CODE , GetAddOnMetadata("CoolAuras","Version")),
		},
		sep = { type = "header", order = 20, width = "full", name = "" },
		des = { type = "description", order = 30, fontSize = "small", name = "Bars of icons to monitor buffs, debuffs and cooldowns." },
	} },
} }

--- Fast reference to buttons list
optbuttons = addon.OptionsTable.args.Group.args.GroupCustom.args

-------------------------------------------------------------------------------------
-- BUTTONS SHARED OPTIONS (FOR CUSTOMGROUPS)
-------------------------------------------------------------------------------------
BUTTONS.SHARED_OPTIONS = {
	headerOpacity = { type = 'header', order = 10, name = 'Icon Opacity' },
	enabled = {
		type = "range",
		order = 11,
		name = 'Enabled Opacity',
		desc = function()
			return button.type == 'AURA' and 'Icon Opacity when the Aura Exists. Select zero to hide the icon.' or 'Icon Opacity when the spell is ready to use. Choose zero to hide the icon.'
		end,
		min = 0,
		max = 1,
		step = 0.01,
		get = function(info) return button.enabled end,
		set = function(info,value)
			button.enabled = value>0 and value or nil
			GroupReload()
		end
	},
	disabled = {
		type = "range",
		order = 12,
		name = 'Disabled Opacity',
		desc = function()
			return button.type == 'AURA' and 'Icon Opacity when the Aura does not Exist. Select zero to hide the icon.' or 'Icon Opacity when the spell is on Cooldown. Choose zero to hide the icon.'
		end,
		min = 0,
		max = 1,
		step = 0.01,
		get = function(info) return button.disabled end,
		set = function(info,value)
			button.disabled = value>0 and value or nil
			GroupReload()
		end
	},
	timeHeader = { type = 'header', order = 20, name = 'Time Left' },
	timeEnabled = {
		type = 'toggle',
		name = 'Display TimeLeft',
		order = 21,
		get = function(info)
			return (button.timeThreshold or 60)>0
		end,
		set = function(info,value)
			button.timeThreshold = value and 300 or 0
			GroupReload()
		end,
	},
	timeThreshold = {
		type = 'range', order = 22, name = 'Time Left Threshold', desc = 'Threshold in seconds to display the time left text.',
		min = 1, softMax = 300, step = 1,
		get = function()
			return button.timeThreshold or 60
		end,
		disabled = function(info)
			return button.timeThreshold==0
		end,
	},
	miscHeader = { type = 'header', order = 400, name = 'Miscellaneous', hidden = function() return button.type ~= 'COOLDOWN' end, },
	gcdEnabled= {
		type = 'toggle', order = 410, name = 'Display GCD', desc = "Display Global Cooldown Spiral",
		hidden = function() return button.type ~= 'COOLDOWN' end,
	},
	tipEnabled= {
		type = 'toggle', order = 420, name = 'Display Tip', desc = "Display Tooltip (only out of combat)",
		hidden = function() return button.type ~= 'COOLDOWN' end,
	},
	countThreshold = {
		type = 'range', order = 430,
		name = 'Charges Threshold',
		desc = 'Minimum value to display the number of charges.',
		min = 0, softMax = 5, step = 1,
		get = function() return button.countThreshold or 1 end,
		set = function(info, value)
			button.countThreshold = value
			GroupReload()
		end,
		hidden = function() return button.type ~= 'COOLDOWN' end,
	},
	displaySep = { type = 'header', order = 500, name = 'Display Conditions' },
	displayPlayerTalentEnabled = {
		type = 'toggle',
		order = 510,
		name = 'Player Talent',
		get = function(info)
			return button.displayPlayerTalent ~= nil
		end,
		set = function(info,value)
			button.displayPlayerTalent = value and 1 or nil
		end,
	},
	displayPlayerTalent = {
		type = 'select',
		order = 520,
		name = 'Player Talent',
		values = function(info)
			return GetClassTalents(group.displayPlayerClass, group.displayPlayerSpec or addon.playerSpec)
		end,
		disabled = function(info)
			return not button.displayPlayerTalent
		end,
	},
	displaySep1 = { type = 'description', order = 600, name = "" },
	displayPlayerShapeshiftEnabled ={
		type = 'toggle',
		order = 610,
		name = 'Player Shapeshift',
		get = function(info)
			return button.displayPlayerShapeshift ~= nil
		end,
		set = function(info,value)
			button.displayPlayerShapeshift = value and shapeshiftDefault or nil
		end,
	},
	displayPlayerShapeshift = {
		type = 'select',
		order = 620,
		name = 'Shapeshift Form',
		values = shapeshiftForms,
		disabled = function()
			return not button.displayPlayerShapeshift
		end,
	},
}

-------------------------------------------------------------------------------------
-- AURA BUTTON (FOR CUSTOMGROUPS)
-------------------------------------------------------------------------------------
TEMPLATES.AURA = { type = 'AURA', filter = 'HELPFUL',  spell = '',  unit = 'player', enabled = 1, disabled = nil }

BUTTONS.AURA = {
	auraType = {
		type = 'select', order = 10, name = 'Aura Type', width = 'normal',
		get = function(info)
			return AuraFilterGet( button.filter, 'HARMFUL' ) or 'HELPFUL'
		end,
		set = function(info,value)
			button.filter = AuraFilterSet(button.filter, 'HELPFUL', value=='HELPFUL')
			button.filter = AuraFilterSet(button.filter, 'HARMFUL', value=='HARMFUL')
			GroupReload()
		end,
		values = { HELPFUL = 'BUFF',  HARMFUL = 'DEBUFF' },
	},
	unit = {
		type = 'select', order = 20, name = 'Unit', width = 'normal',
		values = { player = 'player', target = 'target', focus = 'focus' },
	},
	castByMe = {
		type = 'toggle', order = 30, name = 'Cast be Me',
		get = function(info)
			return not not AuraFilterGet( button.filter, 'PLAYER' )
		end,
		set = function(info,value)
			button.filter = AuraFilterSet( button.filter, 'PLAYER', value )
			GroupReload()
		end,
	},
	spell = {
		type = 'input',
		name = 'Aura Name',
		width = 'full',
		order = 5,
		set = function(info,spell)
			local texture, spellID, _
			if tonumber(spell) then
				spell,_,texture,_,_,_,spellID = GetSpellInfo(spell)
				if not spell then return end
			else
				_,texture,_,_,_,_,_,_,_, spellID = AuraUtil.FindAuraByName(spell, button.unit, button.filter)
				if not spellID then
					_,_,texture,_,_,_,spellID = GetSpellInfo(spell)
				end
			end
			button.spell   = spell
			button.spellID = spellID
			button.texture = texture
			GetButtonOptions().name = FormatSpellName( spell, spellID, texture )
			GroupReload()
		end,
	},
	overlayEnabled = {
		type = 'toggle', tristate = true, order = 40, name = 'Overlay Visibility', desc = 'Display Overlay Glow Border.',
	},
}

-------------------------------------------------------------------------------------
-- COOLDOWN BUTTON (FOR CUSTOMGROUPS)
-------------------------------------------------------------------------------------

TEMPLATES.COOLDOWN = { type = 'COOLDOWN',  spell = '',  timeThreshold = 300, enabled = 1, disabled = 0.4 }

BUTTONS.COOLDOWN = {
	spell = {
		type = 'input',
		name = 'Spell or Item Name whose Cooldown will be displayed',
		width = 'full',
		order = 5,
		get = function(info)
			return button.spell or button.item
		end,
		set = function(info, spell)
			local spellName, spellID, itemName, itemID, texture, countThreshold
			countThreshold = 2
			if tonumber(spell) then
				spellName,_,texture,_,_,_,spellID = GetSpellInfo(spell)
				if spellName then
					if GetSpellCharges(spellID) then
						countThreshold = 1
					end
				else
					itemName, itemLink = GetItemInfo(spell)
					if not itemName then return end
					itemID = spell
				end
			else
				itemName, itemLink, _,_,_,_,_,_,_, texture = GetItemInfo(spell)
				if itemName then
					itemID = string.match(itemLink, 'item:(%d+):')
				else
					spellName,_,texture,_,_,_,spellID = GetSpellInfo(spell)
					if not spellName then spellName = spell	end
				end
			end
			button.texture = texture
			button.countThreshold = countThreshold
			if itemName then
				button.item,  button.itemID  = itemName, itemID
				button.spell, button.spellID = nil, nil
				GetButtonOptions().name = FormatItemName( itemName, itemID )
			else
				button.spell, button.spellID = spellName, spellID
				button.item, button.itemID   = nil, nil
				GetButtonOptions().name = FormatSpellName( spellName, spellID, texture )
			end
			GroupReload()
		end,
	},
	overlayHeader = { type = 'header', order = 6, name = 'Display Overlay Glow' },
	overlayEnabled = {
		type = 'toggle', order = 7, name = 'When spell procs', desc = "Display overlay glowing border when a reactive proc-like spell becomes active.",
	},
	overlayReady = {
		type = 'toggle', order = 8, name = 'Also when is ready', desc = "Also display overlay glow when spell is ready to use.",
		disabled = function() return not button.overlayEnabled end,
	},
}

-------------------------------------------------------------------------------------
-- MAGE INCANTERFLOW SPECIAL AURA BUTTON (FOR CUSTOMGROUPS)
-------------------------------------------------------------------------------------

TEMPLATES.INCANTERFLOW = { spellID = 116267, enabled = 1, disabled = nil }

BUTTONS.INCANTERFLOW = {
	description = {
		type = 'description',
		order = 0,
		fontSize = 'large',
		image = "Interface\\Icons\\Ability_Mage_IncantersAbsorbtion",
		name = buttonTypes.INCANTERFLOW,
	}
}

-------------------------------------------------------------------------------------
-- MAGE ARCANE CHARGES SPECIAL AURA BUTTON (FOR CUSTOMGROUPS)
-------------------------------------------------------------------------------------

TEMPLATES.ARCANECHARGES = { spellID = 36032, enabled = 1, disabled = 0.4 }

BUTTONS.ARCANECHARGES = {
	description = {
		type = 'description',
		order = 0,
		fontSize = 'large',
		image = "Interface\\Icons\\Spell_Arcane_Arcane01",
		name = buttonTypes.ARCANECHARGES,
	}
}

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------

function addon.OnChatCommand()
	local LIB = LibStub("AceConfigDialog-3.0")
	LIB[ LIB.OpenFrames.CoolAuras and 'Close' or 'Open' ](LIB, 'CoolAuras')
end

function addon:InitializeOptionsTable()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CoolAuras", self.OptionsTable)
	LibStub("AceConfigDialog-3.0"):SetDefaultSize("CoolAuras", 800, 655)
	SlashCmdList[ addon.addonName:upper() ] = self.OnChatCommand
	self.OnChatCommand()
	self.InitializeOptionsTable = nil
end
