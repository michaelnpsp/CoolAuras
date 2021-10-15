----------------------------------------------------------------
-- BUTTON COOLDOWN
----------------------------------------------------------------

local addon = CoolAuras

local isClassic = addon.isClassic -- vanilla or tbc

local tinsert = table.insert
local tremove = table.remove

-- COOLDOWN SPIRAL FRAME FACTORY
local CooldownFactory_Get, CooldownFactory_Put
do
	local frames  = {}
	function CooldownFactory_Get()
		return tremove( frames ) or CreateFrame("Cooldown", nil, nil, "CooldownFrameTemplate")
	end
	function CooldownFactory_Put( button, name )
		local frame = button[name]
		if frame then
			frame:Hide()
			frame:SetParent(nil)
			tinsert( frames, frame )
			button[name] = nil
		end
	end
end

-- COOLDOWN BUTTON
do
	local C_Timer_After      = C_Timer.After
	local GetSpellCooldown   = GetSpellCooldown
	local GetSpellCharges    = GetSpellCharges
	local GetSpellTexture    = GetSpellTexture
	local GetItemCooldown    = GetItemCooldown
	local IsUsableSpell      = IsUsableSpell
	local IsSpellOverlayed   = IsSpellOverlayed or function() end
	local ButtonOverlayShow  = addon.ButtonOverlayShow
	local ButtonOverlayHide  = addon.ButtonOverlayHide
	local ButtonSetIcon      = addon.ButtonSetIcon
	local ButtonSetCount     = addon.ButtonSetCount
	local ButtonSetCountdown = addon.ButtonSetCountdown
	local ButtonSetValues    = addon.ButtonSetValues
	local ButtonSetEnabled   = addon.ButtonSetEnabled

	local tipButton
	local cooldown = {}

	if isClassic then
		local GetSpellCooldownOrig = GetSpellCooldown
		local classSpell = ({ MAGE=116, ROGUE=1752, PRIEST=585, WARLOCK=686, HUNTER=2973, WARRIOR=12294, PALADIN=635, SHAMAN=403, DRUID=5185 })[addon.playerClass]
		GetSpellCooldown = function(spellID)
			if spellID~=61304 then return GetSpellCooldownOrig(spellID) end
			local start, duration = GetSpellCooldownOrig(classSpell)
			if duration~=0 and duration<=1.501 then
				return start, duration
			else
				return 0, 0
			end
		end
	end

	local function UpdateOverlay(button)
		if button.vOverlayEnabled then
			local overlay = button.overlay
			local flag = button.vOverlayReady and (not not button.vEnabled) or IsSpellOverlayed(button.spellID or 1)
			if flag ~= (overlay~=nil) then
				if overlay then
					ButtonOverlayHide(button)
				else
					ButtonOverlayShow(button)
				end
			end
		end
	end

	local function UpdateCount(button)
		if button.spellID then
			local charges = GetSpellCharges(button.spellID)
			ButtonSetCount( button, charges or 1 )
		end
	end

	local function UpdateUsable(button)
		if not button.vExpiration then
			if button.spellID then
				ButtonSetEnabled( button, IsUsableSpell(button.spellID) )
			else
				ButtonSetEnabled( button, IsUsableItem(button.itemID) )
			end
			UpdateOverlay(button)
		end
	end

	local function UpdateIcon(button)
		if button.spellID then
			local texture = GetSpellTexture(button.spellID)
			if texture ~= button.vIconTexture then
				button.vIconTexture = texture
				button.Icon:SetTexture( texture )
			end
		end
	end

	local function UpdateCountdown(button, time)
		local spellID = button.spellID
		if spellID then
			local charges, max, start, duration = GetSpellCharges( spellID )
			if charges then
				ButtonSetCountdown(button, charges~=max and start + duration or 0, time )
				ButtonSetCount( button, charges )
				ButtonSetEnabled( button, charges~=0 )
			else
				local gs, gd = GetSpellCooldown( 61304 ) -- GCD
				local start, duration = GetSpellCooldown( spellID )
				local ready = (duration==0) -- or IsSpellOverlayed(spellID)
				if duration and ( ready or duration>1.5 or gs~=start or gd~=duration ) then
					if ready then
						ButtonSetCountdown( button )
						ButtonSetCount( button, 1 )
						ButtonSetEnabled( button, IsUsableSpell(spellID) )
					else
						ButtonSetCountdown( button, start+duration, time)
						ButtonSetCount( button,  0 )
						ButtonSetEnabled( button, false )
					end
				elseif button.vEnabled and not IsUsableSpell(spellID) then
					ButtonSetEnabled( button, false )
				end
			end
		else
			local start, duration = GetItemCooldown( button.itemID )
			local ready = duration == 0
			if duration and (ready or duration>1.5) then
				ButtonSetCountdown( button, start+duration, time )
				ButtonSetCount( button, ready and 1 or 0 )
				ButtonSetEnabled( button, ready )
			end
		end
		if button.Cooldown then -- GCD display
			local gs, gd = GetSpellCooldown( 61304 )
			if gs==0 or button.vEnabled then
				button.Cooldown:SetCooldown(gs,gd)
			end
		end
	end

	local function UpdateCountUsable(button)
		UpdateCount(button)
		UpdateUsable(button)
	end

	local function Update(button)
		UpdateIcon( button )
		UpdateCountdown( button, GetTime() )
	end

	--

	local RegisterCooldown, UnregisterCooldown
	do
		local frame   = CreateFrame("Frame")
		local next    = next
		local GetTime = GetTime
		local buttons = {}
		local funcs   = {
			SPELL_UPDATE_ICON                  = Update,
			SPELL_UPDATE_CHARGES               = UpdateCount,
			SPELL_UPDATE_USABLE                = UpdateUsable,
			SPELL_UPDATE_COOLDOWN              = UpdateCountdown,
			SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = UpdateOverlay,
			SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = UpdateOverlay,
			ACTIONBAR_UPDATE_USABLE            = UpdateUsable,
		}

		local function UpdateCooldowns(frame, event, ...)
			local time = GetTime()
			local func = funcs[event]
			for object in next,buttons do
				func(object, time, ...)
			end
		end

		function RegisterCooldown( object )
			if not next(buttons) then frame:Show() end
			buttons[object] = true
		end

		function UnregisterCooldown( object )
			buttons[object] = nil
			if not next(buttons) then frame:Hide() end
		end

		frame:SetScript('OnEvent', UpdateCooldowns)
		frame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
		frame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
		frame:RegisterEvent('SPELL_UPDATE_USABLE')
		frame:RegisterEvent("SPELL_UPDATE_CHARGES")
		frame:RegisterEvent("SPELL_UPDATE_ICON")
		if not isClassic then
			frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
			frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
		end
	end

	--

	cooldown.OnUpdate = Update

	cooldown.OnCountdown = UpdateCountUsable

	function cooldown.ShowTooltip()
		if tipButton then
			GameTooltip:SetOwner(tipButton, 'ANCHOR_' .. tipButton.bar.tooltipAnchor)
			GameTooltip:SetFrameLevel(tipButton:GetFrameLevel() + 2)
			GameTooltip:SetSpellByID(tipButton.spellID)
			local k1 = addon.GetSpellBindings(tipButton.spellID)
			if k1 then
				GameTooltip:AddLine(" ")
				GameTooltip:AddDoubleLine("KeyBind:", k1, 0,1,0, 1,0,0 )
				GameTooltip:Show()
			end
			tipButton = nil
		end
	end

	function cooldown.OnMouseEnter(button)
		if (not addon.inCombat) and button.spellID then
			tipButton = button
			C_Timer_After(0.5,cooldown.ShowTooltip)
		end
	end

	function cooldown.OnMouseLeave(button)
		tipButton = nil
		GameTooltip:Hide()
	end

	function cooldown.OnCreate(button)
		local texture
		if button.db.spell then
			button.itemID  = nil
			button.spellID = button.db.spellID or select( 7, GetSpellInfo(button.db.spell) ) or 1
			texture        = (GetSpellTexture(button.db.spell)) or button.db.texture
		else
			button.spellID = nil
			button.itemID  = button.db.itemID
			texture = (select(10,GetItemInfo(button.db.itemID))) or button.db.texture
		end
		if button.db.tipEnabled then
			button:EnableMouse(true)
			button:SetScript("OnEnter", cooldown.OnMouseEnter)
			button:SetScript("OnLeave", cooldown.OnMouseLeave)
		end
		button.vOverlayEnabled  = button.db.overlayEnabled
		button.vOverlayReady    = button.db.overlayReady
		button.vIconTexture = texture
		button.Icon:SetTexture( texture )
		button.countThreshold = button.db.countThreshold or 1
		button.Cooldown = button.db.gcdEnabled and CooldownFactory_Get() or nil
		RegisterCooldown( button )
	end

	function cooldown.OnLayout(button)
		local Cool = button.Cooldown
		if Cool then
			Cool:SetParent(button)
			Cool:ClearAllPoints()
			Cool:SetAllPoints()
			Cool:SetDrawEdge(false)
			Cool:SetDrawBling(false)
			if not addon.Masque then
				Cool:SetSwipeColor(0, 0, 0)
				Cool:SetHideCountdownNumbers(true)
				Cool.noCooldownCount = true
			end
			Cool:Show()
		end
	end

	function cooldown.OnDestroy(button)
		ButtonOverlayHide(button)
		CooldownFactory_Put(button, "Cooldown")
		UnregisterCooldown( button )
	end

	function cooldown.OnDisableCheck(button)
		if button.db.spell then
			return not GetSpellCooldown(button.db.spell)
		end
	end

	CoolAuras.events.COOLDOWN = cooldown
end
