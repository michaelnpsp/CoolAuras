----------------------------------------------------------------
-- AURAS
----------------------------------------------------------------

local addon = CoolAuras

local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)

local UnitAuraByName   = addon.UnitAuraByName
local ButtonSetValues  = addon.ButtonSetValues
local ButtonSetEnabled = addon.ButtonSetEnabled

-- Track target & focus changes
local RegisterUnitChange, UnregisterUnitChange
do
	local next    = next
	local frame   = CreateFrame('Frame')
	local count   = 0
	local events  = { target = 'PLAYER_TARGET_CHANGED', focus = 'PLAYER_FOCUS_CHANGED' }
	local updates = { PLAYER_TARGET_CHANGED = {}, PLAYER_FOCUS_CHANGED  = {} }
	local Notify  = CoolAuras.Notify

	function RegisterUnitChange(object, unit)
		local event = events[unit]
		if event then
			local objects = updates[event]
			if objects then
				if count == 0 then frame:Show()	end
				object.__unitChangeEvent = event
				objects[object] = true
				count = count + 1
			end
		end
	end

	function UnregisterUnitChange(object)
		local event = object.__unitChangeEvent
		if event then
			object.__unitChangeEvent = nil
			local objects = updates[event]
			if objects then
				objects[object] = nil
				count = count - 1
				if count == 0 then frame:Hide() end
			end
		end
	end

	frame:Hide()
	frame:RegisterEvent('PLAYER_TARGET_CHANGED')
	if not isClassic then frame:RegisterEvent('PLAYER_FOCUS_CHANGED') end
	frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
	frame:SetScript('OnEvent',  function(frame, event)
		local time    = GetTime()
		local objects = updates[event]
		if objects then
			for object in next, objects do
				Notify(object, 'OnUpdate', time)
			end
		else
			for _, objects in next, updates do
				for object in next, objects do
					Notify(object, 'OnUpdate', time)
				end
			end
		end
	end )
end


-- Compile a filter function --------------------------------------
local CompileFilter
do
	-- Time Left is an special case, we must track the time remaining using a timer.
	local func_timeLeft = [[
		if time > %limit% then
			local texp = exp - %limit%
			if texp < timer.expiration then
				timer.expiration = texp
				timer:Stop()
				timer.params:SetDuration( time - %limit% )
				timer:Play()
			end
		end
		return %cond%
	]]

	local function NamesToList(names)
		local list = {}
		if names then
			local t = { strsplit("\n",names) }
			for i=1,#t do -- Remove comments: any text starting with #@\/[ characters.
				local s = strtrim( (strsplit( "#@\\\/\[", t[i] )) ) -- Don't remove strsplit extra brackets.
				if #s>0 then list[s] = true end
			end
		end
		return list
	end

	local function GetTimeParams(value)
		if value == true then
			return '>', 0
		elseif value == false then
			return '==', 0
		elseif value < 0 then
			return '<', -value
		else
			return '>=', value
		end
	end

	function CompileFilter(db)
		local conds, extra, list, source = {}
		if db.timeLeftFilter then
			local comp,value = GetTimeParams(db.timeLeftFilter)
			extra = string.gsub( func_timeLeft, "%%limit%%", tostring(tonumber(value)-0.1) )
			extra = string.gsub( extra, "%%cond%%", string.format('time %s %d', comp, value ) )
		end
		if db.durationFilter~=nil then
			local comp,value = GetTimeParams(db.durationFilter)
			table.insert( conds, string.format('%s dur %s %d', (comp=='<' and 'dur>0 and' or '') , GetTimeParams(db.durationFilter) ) )
		end
		if db.casterFilter==false then
			table.insert( conds, "caster~='player'" )
		end
		if db.isBlackList~=nil then
			table.insert( conds, string.format('%s L[name]', db.isBlackList and 'not' or '') )
			list = NamesToList(db.spells)
		end
		if extra then
			if #conds>0 then -- time left condition + other conditions
				source = string.format( "return function(timer, name, dur, exp, con, caster, time, tray) if %s then %s end end",  table.concat(conds,' and '), extra )
			else -- only time left condition
				source = string.format( "return function(timer, name, dur, exp, con, caster, time, tray) %s end",  extra)
			end
		elseif #conds>0 then -- no time left condition
			source = string.format( "return function(timer, name, dur, exp, con, caster, time, tray) return %s end", table.concat(conds,' and ') )
		end
		if source then
			if list then
				return loadstring(string.format( "return function(L) %s end", source ))()(list)
			else
				return loadstring(source)()
			end
		end
	end
end

----------------------------------------------------------------
-- GROUP AURAS
----------------------------------------------------------------
do
	local GetTime = GetTime
	local UnitAura = UnitAura
	local GameTooltip = GameTooltip
	local C_Timer_After = C_Timer.After
	local auras, tipUnit, tipIndex, tipFilter = {}

	-- Tooltips display
	local function UpdateTooltip()
		if tipUnit then
			GameTooltip:SetUnitAura(tipUnit,tipIndex,tipFilter)
			C_Timer_After(0.1, UpdateTooltip)
		end
	end

	local function OnMouseEnter(button)
		local db = button.bar.db
		tipIndex = button.auraIndex
		if tipIndex then
			if tipIndex == 0 then
				local relPoint = button.bar.tooltipAnchor
				local point    = addon.opositePoints[relPoint]
				--RaidBuffTray_Update()
				ConsolidatedBuffsTooltip:ClearAllPoints()
				ConsolidatedBuffsTooltip:SetPoint(point, button, relPoint)
				ConsolidatedBuffsTooltip:Show()
			elseif db.showTooltips then
				tipUnit, tipFilter = db.unit, db.filter
				GameTooltip:SetOwner(button, 'ANCHOR_' .. button.bar.tooltipAnchor)
				GameTooltip:SetFrameLevel(button:GetFrameLevel() + 2)
				GameTooltip:SetUnitAura(tipUnit, tipIndex, tipFilter)
				C_Timer_After(0.1, UpdateTooltip)
			end
		end
	end

	local function OnMouseLeave(button)
		if button.auraIndex == 0 then
			ConsolidatedBuffsTooltip:ClearAllPoints()
			ConsolidatedBuffsTooltip:Hide()
		else
			GameTooltip:Hide()
			tipUnit = nil
		end
	end

	-- Buffs Right-Click cancellation
	local function OnMouseClick(button)
		if not InCombatLockdown() then
			CancelUnitBuff( 'player', button.auraIndex, button.bar.db.filter )
		end
	end

	-- Auras management
	local function Update(bar)
		local time = GetTime()
		local db = bar.db
		local unit = db.unit
		local filter = db.filter
		local max = db.buttonCount
		local buttons = bar.buttons
		local timer = bar.timer
		local filterFunc = bar.filterFunc
		local i = 1
		for index=1,32 do
			local name, tex, count, _, dur, exp, caster, _, con = UnitAura(unit, index, filter)
			if not name then break end
			if not filterFunc or filterFunc(timer, name, dur, exp, con, caster, exp-time) then
				local button = buttons[i]
				button.auraIndex = index
				ButtonSetValues(button, tex, count>1 and count or nil, exp, time )
				button:Show()
				i = i + 1
				if i>max then break end
			end
		end
		for j=bar.countVisible,i,-1 do
			buttons[j]:Hide()
		end
		bar.countVisible = i - 1
	end

	function auras.OnCreate( bar )
		local db = bar.db
		bar.filterFunc = CompileFilter(db)
		if db.timeLeftFilter and not bar.timer then
			local timer = bar:CreateAnimationGroup()
			timer.params = timer:CreateAnimation()
			timer.params:SetOrder(1)
			timer:SetLooping('NONE')
			timer.expiration = 9E+16 -- arbitrary high number
			timer:SetScript("OnFinished", function()
				timer.expiration = 9E+16
				Update(bar)
			end )
			bar.timer = timer
		end
		local tips = db.showTooltips
		if tips or db.cancelBuffs then
			addon.EnableMouse( bar,	tips and OnMouseEnter, tips and OnMouseLeave, db.cancelBuffs and OnMouseClick )
		end
		bar:RegisterUnitEvent( 'UNIT_AURA', db.unit )
		bar:SetScript('OnEvent', Update)
		RegisterUnitChange(bar, db.unit)
	end

	function auras.OnDestroy( bar )
		bar:UnregisterAllEvents()
		bar:SetScript('OnEvent', nil)
		if bar.TextTray then
			bar.TextTray:SetParent(bar)
			bar.TextTray:Hide()
		end
		UnregisterUnitChange(bar)
	end

	auras.OnUpdate = Update
	addon.events.AURAS = auras
end

----------------------------------------------------------------
-- BUTTON AURA
----------------------------------------------------------------

do
	local OverlayUpdate = addon.ButtonOverlayUpdate
	local OverlayHide   = addon.ButtonOverlayHide
	local GetTime = GetTime

	local aura = {}

	function aura.OnUpdate(button)
		local db = button.db
		local texture, count, dur, exp = UnitAuraByName(db.unit, db.spell, db.filter)
		if not db.texture and texture then db.texture = texture end
		ButtonSetValues( button, texture, count, exp, GetTime() )
		ButtonSetEnabled( button, texture~=nil )
		local overlayReverse = button.vOverlayReverse
		if overlayReverse~=nil then
			OverlayUpdate( button, button.vEnabled, overlayReverse )
		end
	end

	function aura.OnCreate(button)
		button.countThreshold = 2
		button.vOverlayReverse = button.db.overlayEnabled
		if button.vOverlayReverse~=nil then
			button.vOverlayReverse = not button.vOverlayReverse
		end
		button.Icon:SetTexture( GetSpellTexture(button.db.spell) or button.db.texture )
		button:RegisterUnitEvent( 'UNIT_AURA', button.db.unit )
		button:SetScript('OnEvent', aura.OnUpdate)
		RegisterUnitChange(button, button.db.unit)
	end

	function aura.OnDestroy(button)
		OverlayHide(button)
		button:UnregisterAllEvents()
		button:SetScript('OnEvent', nil)
		UnregisterUnitChange(button)
	end

	CoolAuras.events.AURA = aura
end
