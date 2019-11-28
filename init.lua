----------------------------------------------------------------
-- CoolAuras Initialization
----------------------------------------------------------------

local addonName = ... 

local addon = { addonName = addonName }
_G[addonName] = addon

----------------------------------------------------------------
-- Variables
----------------------------------------------------------------

local Groups = {
	PlayerBuffs = {
		name = 'PlayerBuffs',
		type = 'AURAS',
		unit = 'player',
		filter = 'PLAYER|HELPFUL',
		isBlackList = false,
		spells = "Caudal de encantador\nLuminosidad Arcana",
		
		left = 0,
		top = 0,
		anchorTo = 'CENTER',
		centerButtons  = true,		

		displayCombat      = nil, -- true|false|nil
		displayPlayerName  = nil, 
		displayPlayerClass = nil,
		displayPlayerSpec  = nil,
		displayPlayerRole  = nil,
		
		buttonAnchor  = 'LEFT', -- | 'TOP' | 'BOTTOM' | 'RIGHT'
		buttonCount   = 5,
		buttonSize    = 32,
		buttonSpacing = 4,
		buttonBorderSize = 1,
		buttonBorderColor = {1,1,1,1},
		
		countNoMasque  = true,
		countFontName  = nil, -- FONT,
		countFontColor = {1,1,1},
		countFontSize  =  10,
		countFontFlags = 'OUTLINE',
		countJustifyH  = 'RIGHT',
		countJustifyV  = 'BOTTOM',
		countAdjustX   = 0,
		countAdjustY   = 0,
		
		timerNoMasque  = true,
		timerFontName  = nil, -- FONT,
		timerFontColor = {1,1,1},
		timerFontSize  =  10,
		timerFontFlags = 'OUTLINE',
		timerJustifyH  = 'RIGHT',
		timerJustifyV  = 'MIDDLE',
		timerAdjustX   = 0,
		timerAdjustY   = 0,
	},
	
	ArcaneCooldowns = {
		name = 'ArcaneCooldowns',
  		type = 'MISC',
		left = 0,
		top = 100,
		anchor = 'CENTER',
		anchorTo = 'CENTER',
		buttonSize    = 36,
		buttonSpacing = 5,
		buttonAnchor  = 'LEFT',
		
		countNoMasque  = false,
		countFontName  = FONT,
		countFontColor = {1,1,1},
		countFontSize  =  10,
		countFontFlags = 'OUTLINE',
		countJustifyH  = 'RIGHT',
		countJustifyV  = 'BOTTOM',
		countAdjustX   = 0,
		countAdjustY   = 0,
		
		timerNoMasque  = false,
		timerFontName  = FONT,
		timerFontColor = {1,1,1},
		timerFontSize  =  10,
		timerFontFlags = 'OUTLINE',
		timerJustifyH  = 'RIGHT',
		timerJustifyV  = 'MIDDLE',
		timerAdjustX   = 0,
		timerAdjustY   = 0,		
		
		{ type = 'AURA', filter = 'PLAYER|HELPFUL',  spell = 'Luminosidad Arcana',  unit = 'player', enabled = 1, disabled = nil },
		{ type = 'AURA', filter = 'PLAYER|HARMFUL',  spell = 'Carga Arcana', unit = 'player', enabled = 1, disabled = 0.25 },
		{ type = 'AURA', filter = 'PLAYER|HELPFUL',  spell = 'Caudal de encantador',  unit = 'player', enabled = 1, disabled = nil },
		{ type = 'COOLDOWN',  spell = 'Supernova',  enabled = 1, disabled = 0.25 },
		{ type = 'COOLDOWN',  spell = 'Traslación',  enabled = 1, disabled = 0.25 },
	},
}


addon.defaults = {
	general = {
		Masque = false,
		--disableBlizzard = true,
	},
	groups = Groups,
}	

----------------------------------------------------------------
-- Database
----------------------------------------------------------------

function addon:GetDB(name, defaults)
	local db = _G[name]
	if not db then 
		db = defaults or {}
		_G[name] = db
	end
	self.GetDB = nil
	return db
end

----------------------------------------------------------------
-- Options Load
----------------------------------------------------------------

function addon.OnChatCommand(input)
	if not IsAddOnLoaded("CoolAuras_Options") then
		if InCombatLockdown() then
			print("CoolAuras Options cannot be loaded in combat.")
			return
		end
		LoadAddOn("CoolAuras_Options")		
	end
	if not addon.OptionsTable then
		print("You need CoolAuras_Options addon enabled to be able to configure CoolAuras.")
		return
	end
	addon:InitializeOptionsTable()
end

SlashCmdList[ addonName:upper() ] = addon.OnChatCommand
_G[ 'SLASH_'..addonName:upper()..'1' ] = '/coolauras'

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

function addon:Initialize()
	addon.db = addon:GetDB('CoolAurasDB', addon.defaults)
	local optionsFrame = CreateFrame( "Frame", nil, UIParent )
	optionsFrame.name = "CoolAuras"
	local button = CreateFrame("BUTTON", nil, optionsFrame, "UIPanelButtonTemplate")
	button:SetText("Open CoolAuras Options")
	button:SetSize(200,32)
	button:SetPoint('TOPLEFT', optionsFrame, 'TOPLEFT', 20, -20)
	button:SetScript("OnClick", function(self) 
		HideUIPanel(InterfaceOptionsFrame) 
		HideUIPanel(GameMenuFrame) 
		addon.OnChatCommand()
	end)
	InterfaceOptions_AddCategory(optionsFrame)
	self.optionsFrame = optionsFrame
	self.Initialize = nil
end

----------------------------------------------------------------
-- Init
----------------------------------------------------------------

local MainFrame = CreateFrame('Frame')
MainFrame:RegisterEvent("ADDON_LOADED")
MainFrame:RegisterEvent("PLAYER_LOGIN")
MainFrame:SetScript("OnEvent", function(frame, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addon:Initialize()
	end
	if (not addon.Initialize) and IsLoggedIn() then
		frame:Hide()
		frame:UnregisterAllEvents()
		frame:SetScript("OnEvent", nil)
		addon:Run(MainFrame)
	end	
end)

