----------------------------------------------------------------
-- CoolAuras Initialization
----------------------------------------------------------------

local addonName = ...

local addon = { addonName = addonName }
_G[addonName] = addon

----------------------------------------------------------------
-- Variables
----------------------------------------------------------------

addon.defaults = {
	general = {
		Masque = false,
		--disableBlizzard = true,
	},
	groups = {},
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

