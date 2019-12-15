---------------------------------------------------------------------------
-- INCANTER FLOW BUFF TRACKING
-- Adds a cooldown animation to easy track buff stacks
---------------------------------------------------------------------------
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return end

local addon = CoolAuras
local UnitAura = UnitAura
local GetTime = GetTime
local unpack = unpack
local buffName
local DOWNCOLOR = { .6, .6, .6, 1 }
local ButtonSetCount = addon.ButtonSetCount
local UnitAuraByName = addon.UnitAuraByName

---------------------------------------------------------------------------
local CooldownCreate, CooldownDestroy, CooldownLayout, CooldownMasque
do
	local durations = {
		[ 1]  = { [2] = 5, [3] = 4, [4] = 3, [5] = 2  },
		[-1]  = { [4] = 10, [3] = 9, [2] = 8, [1] = 7 },
	}
	local buttonAttached, frameCount, cooldown, count
	local duration, state = 0, false
	function CooldownOnUpdate(_, elapsed)
		duration = duration - elapsed
		if duration<=0 then
			if state then
				cooldown:SetCooldown( GetTime(), 10 )
				state, count = nil, nil
			else
				local _,ncount = UnitAuraByName('player', buffName, 'HELPFUL|PLAYER' )
				if ncount then
					if count then
						local diff = ncount - count
						if diff==-1 or diff==1 then
							state, duration = true, durations[diff][ncount]
							cooldown:SetCooldown( GetTime() - ( 10 - duration ) , 10 )
							cooldown:Show()
						end
					end
					count = ncount
				else
					duration, state, count = 1, nil, nil
					cooldown:Hide()
				end
			end
		end
	end
	function CooldownCreate(button)
		frameCount = CreateFrame('Frame')
		cooldown = CreateFrame("Cooldown", nil , button, "CooldownFrameTemplate")
		cooldown.noCooldownCount = true
		cooldown:SetDrawEdge(true)
		cooldown:SetReverse(false)
		cooldown:SetHideCountdownNumbers(true)
		cooldown:SetDrawBling(false)
		CooldownCreate = function(button)
			if not buttonAttached then
				frameCount:SetParent(button)
				frameCount:SetAllPoints()
				frameCount:SetFrameLevel( button:GetFrameLevel()+5 )
				frameCount:Show()
				cooldown:SetParent(button)
				cooldown:ClearAllPoints()
				cooldown:SetAllPoints()
				cooldown:Hide()
				button:SetScript('OnUpdate', CooldownOnUpdate )
				buttonAttached, duration, state, count = button, 0, nil, nil
			end
		end
		CooldownCreate(button)
	end
	function CooldownDestroy(button)
		if button==buttonAttached then
			frameCount:SetParent(nil)
			frameCount:Hide()
			cooldown:SetParent(frameCount)
			cooldown:Hide()
			button.Count:SetParent(button)
			button:SetScript( 'OnUpdate', nil )
			buttonAttached = nil
		end
	end
	function CooldownLayout(button)
		if button==buttonAttached then
			button.Count:SetParent(frameCount)
		end
	end
	function CooldownMasque(button,ButtonData)
		if button==buttonAttached then
			ButtonData.Cooldown = cooldown
		end
	end
end

---------------------------------------------------------------------------

local aura = { OnLayout = CooldownLayout, OnMasqueLayout = CooldownMasque }

function aura.OnUpdate(button)
	local buffCount = button.buffIncanterCount
	local _, count = UnitAuraByName( 'player', buffName, 'HELPFUL|PLAYER' )
	if buffCount ~= count then
		if count then
			button.Count:SetTextColor( unpack(count>buffCount and button.countFontColor or DOWNCOLOR)  )
			ButtonSetCount( button, count )
			button.buffIncanterCount = count
		else
			button.Count:SetTextColor( unpack(button.countFontColor)  )
			ButtonSetCount( button, 0 )
			button.buffIncanterCount = 10
		end
	end
end

function aura.OnCreate(button)
	local icon, _
	buffName, _, icon = GetSpellInfo(116267)
	button.Icon:SetTexture( icon )
	button:RegisterUnitEvent( 'UNIT_AURA', 'player' )
	button:SetScript('OnEvent', aura.OnUpdate)
	button.buffIncanterCount = 10 -- Arbitrary high value
	button.countFontColor = button.db.countFontColor or addon.COLORWHITE
	button.countThreshold = 1
	CooldownCreate(button)
end

function aura.OnDestroy(button)
	button:UnregisterAllEvents()
	button:SetScript('OnEvent', nil)
	CooldownDestroy(button)
end

function aura.OnDisableCheck()
	return not GetSpellInfo(116267)
end

CoolAuras.events.INCANTERFLOW = aura
