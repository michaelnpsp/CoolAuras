-- Mage Arcane Charges
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return end

local ButtonSetIcon    = CoolAuras.ButtonSetIcon
local ButtonSetCount   = CoolAuras.ButtonSetCount
local ButtonSetEnabled = CoolAuras.ButtonSetEnabled

local aura  = {}
local UnitPower = UnitPower
local SPELL_POWER_ARCANE_CHARGES = Enum.PowerType.ArcaneCharges

function aura.OnUpdate(button, event, unit, powerType)
	if powerType == "ARCANE_CHARGES" or (not powerType) then
		local count = UnitPower("player", SPELL_POWER_ARCANE_CHARGES) or 0
		ButtonSetCount( button, count )
		ButtonSetEnabled( button, count>0 )
	end
end

function aura.OnCreate(button)
	local _, _, icon = GetSpellInfo(36032)
	button.countThreshold = 1
	ButtonSetIcon( button, icon )
	button:RegisterUnitEvent( 'UNIT_POWER_UPDATE', 'player' )
	button:SetScript('OnEvent', aura.OnUpdate)
end

function aura.OnDestroy(button)
	button:UnregisterAllEvents()
	button:SetScript('OnEvent', nil)
end

CoolAuras.events.ARCANECHARGES = aura
