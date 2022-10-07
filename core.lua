----------------------------------------------------------------
-- CoolAuras Core
----------------------------------------------------------------

local addon  = CoolAuras
local Media  = LibStub("LibSharedMedia-3.0", true)

----------------------------------------------------------------
--
----------------------------------------------------------------

addon.playerClass = select(2,UnitClass('player'))
addon.playerName  = UnitName('player')

----------------------------------------------------------------
--
----------------------------------------------------------------

local versionCli = select(4,GetBuildInfo())
addon.versionCli = versionCli
addon.isClassic  = versionCli<40000 -- vanilla or tbc or wrath
addon.isVanilla  = versionCli<20000
addon.isTBC      = versionCli>=20000 and versionCli<30000
addon.isWoW90    = versionCli>=90000

local versionToc = GetAddOnMetadata("CastCursor","Version")
addon.versionToc = versionToc=='@project-version@' and 'Dev' or 'v'..versionToc

----------------------------------------------------------------
--
----------------------------------------------------------------

local next = next
local tinsert = table.insert
local tremove = table.remove
local select  = select
local GetTime = GetTime
local FONT_DEFAULT = STANDARD_TEXT_FONT
local COLORWHITE   = {1,1,1,1}
local COLORBLACK   = {0,0,0,1}
local isClassic = addon.isClassic

----------------------------------------------------------------
--
----------------------------------------------------------------
do
	local UnitAura = UnitAura
	function addon.UnitAuraByName(unit, aura, filter)
		for index=1,40 do
			local name, icon, count, _, duration, expiration = UnitAura(unit, index, filter)
			if not name then
				return
			elseif aura == name then
				return icon, count, duration, expiration
			end
		end
	end
end

----------------------------------------------------------------
--
----------------------------------------------------------------
local FrameFactory_Get, FrameFactory_Put
do
	local frames = setmetatable({}, { __index = function(t,k) local v={}; t[k]=v; return v end } )

	function FrameFactory_Get( name )
		local frame = tremove( frames[name] )
		if frame then
			frame.isHidden = nil
			frame:SetAlpha(1)
			frame:Show()
			return frame
		end
	end

	function FrameFactory_Put( frame, className )
		frame:Hide()
		frame:SetParent(nil)
		tinsert( frames[className or frame.className], frame )
	end

	addon.FrameFactory_Get = FrameFactory_Get
	addon.FrameFactory_Put = FrameFactory_Put
end

----------------------------------------------------------------
--
----------------------------------------------------------------

local Notify
do
	local events = {}

	function Notify(object, event, ...)
		if object then
			local func = events[object.className]
			if func then
				func = func[event]
				if func then
					return func(object, ...)
				end
			end
		end
	end

	addon.events = events
	addon.Notify = Notify
end

----------------------------------------------------------------
--
----------------------------------------------------------------

local ButtonSetCountdown
do
	local C_Timer_After = C_Timer.After

	local buttons = {}

	local function CountdownTimer()
		local time = GetTime()
		for Timer, expiration in next,buttons do
			local dur = expiration-time
			if dur<Timer.timeThreshold then
				local button = Timer.button
				if dur<=0 then
					buttons[Timer] = nil
					Timer:SetText( '' )
					button.vExpiration = nil
					Notify( button, 'OnCountdown', time )
				elseif not button.isHidden then
					if dur<1 then
						Timer:SetFormattedText( "%.1f", dur )
					elseif dur<60 then
						Timer:SetFormattedText( "%d", dur )
					else
						Timer:SetFormattedText( "%dm", dur/60 )
					end
				end
			end
		end
		if next(buttons) then
			C_Timer_After(0.05, CountdownTimer)
		end
	end

	function ButtonSetCountdown(button, expiration, time)
		if expiration and expiration>0 then
			if not next(buttons) then
				C_Timer_After(0.1, CountdownTimer)
			end
			local Timer = button.Timer
			if expiration-time>=Timer.timeThreshold then
				Timer:SetText('')
			end
			buttons[Timer] = expiration
			button.vExpiration = expiration
		else
			local Timer = button.Timer
			Timer:SetText( '' )
			buttons[Timer] = nil
			button.vExpiration = nil
		end
	end

end

----------------------------------------------------------------
-- OVERLAY (SPELL ACTIVATION ALERT)
----------------------------------------------------------------

local ButtonOverlayShow, ButtonOverlayHide, ButtonOverlayUpdate
do
	local unused = {}
	local count  = 0
	local function CreateOverlay()
		count = count + 1
		return CreateFrame("Frame", "CoolAurasOverlayGlow"..count, UIParent, "ActionBarButtonSpellActivationAlert")
	end
	function ButtonOverlayShow(self)
		local overlay = self.overlay
		if overlay then
			overlay.animOut:Stop()
		else
			local w,h = self:GetSize()
			overlay = tremove( unused ) or CreateOverlay()
			overlay:SetParent(self)
			overlay:ClearAllPoints()
			overlay:SetSize(w * 1.4, h * 1.4);
			overlay:SetPoint("TOPLEFT", self, "TOPLEFT", -w * 0.2, h * 0.2);
			overlay:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", w * 0.2, -h * 0.2);
			overlay:Show()
			self.overlay = overlay
		end
		overlay.animIn:Play()
	end
	function ButtonOverlayHide(self)
		local overlay = self.overlay
		if overlay then
			tinsert( unused, overlay)
			self.overlay =  nil
			overlay:Hide()
			overlay:SetParent(nil)
		end
	end
	function ButtonOverlayUpdate(button, enabled, reverse)
		local overlay = button.overlay
		if reverse then
			enabled = not enabled
		else
			enabled = not not enabled
		end
		if enabled ~= (overlay~=nil) then
			if overlay then
				ButtonOverlayHide(button)
			else
				ButtonOverlayShow(button)
			end
		end
	end
end

----------------------------------------------------------------
--
----------------------------------------------------------------

local IsTalentEnabled
do
	local ceil = math.ceil
	local GetTalentInfo = GetTalentInfo
	local GetActiveSpecGroup = GetActiveSpecGroup
	if isClassic then -- classic
		IsTalentEnabled = function(talentID)
			local tab = ceil(talentID / 20) -- max num talents per tab = 20
			local id  = (talentID - 1) % 20 + 1
			return select(5,GetTalentInfo(tab,id)) ~= 0
		end
	else -- retail
		IsTalentEnabled = function(talentID)
			local tier = ceil(talentID / 3)
			local col  = (talentID - 1) % 3 + 1
			return select(4, GetTalentInfo(tier, col, GetActiveSpecGroup() ) )
		end
	end
end

local function GroupDisplayFilter(db)
	return	addon.playerName  == (db.displayPlayerName  or addon.playerName)  and
			addon.playerRole  == (db.displayPlayerRole  or addon.playerRole)  and
			addon.playerClass == (db.displayPlayerClass or addon.playerClass) and
			addon.playerSpec  == (db.displayPlayerSpec  or addon.playerSpec)  and
			addon.playerShapeshift == (db.displayPlayerShapeshift or addon.playerShapeshift)  and
			(not db.displayPlayerTalent or IsTalentEnabled(db.displayPlayerTalent))
end

local function ButtonDisplayFilter(db, button)
	return not Notify(button, 'OnDisableCheck') and
		  (not db.displayPlayerTalent or IsTalentEnabled(db.displayPlayerTalent)) and
		  (not db.displayPlayerShapeshift or db.displayPlayerShapeshift==addon.playerShapeshift)
end

----------------------------------------------------------------
--
----------------------------------------------------------------

-- Useful Points
addon.opositePoints = {
	LEFT = 'RIGHT',
	RIGHT = 'LEFT',
	TOP = 'BOTTOM',
	BOTTOM = 'TOP',
	TOPLEFT = 'BOTTOMRIGHT',
	TOPRIGHT = 'BOTTOMLEFT',
	BOTTOMLEFT = 'TOPRIGHT',
	BOTTOMRIGHT = 'TOPLEFT',
}

addon.tooltipAnchors = {
	TOPLEFT = 'BOTTOMRIGHT',
	LEFT = 'BOTTOMRIGHT',
	BOTTOMLEFT = 'TOPRIGHT',
	TOP = 'BOTTOMRIGHT',
	CENTER = 'BOTTOMRIGHT',
	BOTTOM = 'TOPRIGHT',
	TOPRIGHT = 'BOTTOMLEFT',
	RIGHT = 'BOTTOMLEFT',
	BOTTOMRIGHT = 'TOPLEFT',
}

-- Masque buttonData fields
local masqueLayers = { "FloatingBG", "AutoCast", "AutoCastable", "Backdrop", "Checked", "Cooldown", "ChargeCooldown", "Count", "Disabled", "Flash", "Highlight", "HotKey", "Name", "Pushed" }

-- Created Bars
local bars = {}

local function EnableMasque()
	if addon.db.general.Masque then
		addon.Masque = LibStub('Masque', true)
	end
end

local function UpdateBar(bar)
	local time = GetTime()
	Notify( bar, 'OnUpdate', time )
	if #bar.db>0 then
		for _,button in next,bar.buttons do
			if not button.isHidden then
				Notify( button, 'OnUpdate', time)
			end
		end
	end
end

local function UpdateBarSize(bar)
	local count = bar.countVisible
	if count ~= bar.countVisiblePrev then
		bar:SetBarWidth( count * ( bar.buttonSize + bar.buttonSpacing) - bar.buttonSpacing )
		bar.countVisiblePrev = count
	end
end

local function ButtonSetIcon(button, texture)
	if texture then
		button.Icon:SetTexture(texture)
	end
end

local function ButtonSetCount(button, count)
	button.Count:SetText( (count or 0)>=button.countThreshold and count or '' )
end

local function ButtonSetValues( button, texture, count, expiration, time)
	if texture then	button.Icon:SetTexture(texture)	end
	button.Count:SetText( (count or 0)>=button.countThreshold  and count or '' )
	ButtonSetCountdown(button, expiration, time)
end

local function ButtonSetEnabled( button, enabled )
	local alpha = enabled and button.enabledAlpha or button.disabledAlpha
	button:SetAlpha(alpha)
	if alpha>0 then
		if button.isHidden then
			local bar = button.bar
			local point, relativeTo, relPoint, x, y = button:GetPoint(1)
			button.isHidden = nil
			bar.countVisible = bar.countVisible + 1
			button:SetPoint(point, relativeTo, relPoint, x+bar.buttonDespX, y+bar.buttonDespY )
		end
	elseif not button.isHidden then
		local bar = button.bar
		bar.countVisible = bar.countVisible - 1
		button.isHidden = true
		local point, relativeTo, relPoint, x, y = button:GetPoint(1)
		button:SetPoint(point, relativeTo, relPoint, x-bar.buttonDespX, y-bar.buttonDespY )
	end
	button.vEnabled = enabled
end

local function CreateButton(bar, type)
	local button        = CreateFrame( 'Button', nil, bar )
	button.Normal       = button:CreateTexture(nil, 'BACKGROUND')
	button.Icon         = button:CreateTexture(nil, "ARTWORK")
	button.Count        = button:CreateFontString()
	button.Timer        = button:CreateFontString()
	button.Timer.button = button
	button:SetNormalTexture( button.Normal )
	button.className    = type
	return button
end

local function AddButton(bar, db)
	local type   = db and db.type or 'DEFAULT'
	local button = FrameFactory_Get( type ) or CreateButton(bar, type)
	button:SetParent(bar)
	tinsert( bar.buttons, button )
	button.db = db
	button.bar = bar
	button.enabledAlpha  = db and (db.enabled  or 0) or 1
	button.disabledAlpha = db and (db.disabled or 0) or 0
	button.countThreshold = 2
	button.isCreated = (not db) or ButtonDisplayFilter(db, button)
	if button.isCreated then
		button.isHidden = nil
		bar.countVisible = bar.countVisible + 1
		button:SetAlpha(button.enabledAlpha)
		Notify( button, 'OnCreate' )
	else
		button.isHidden = true
		button:SetAlpha(0)
	end
end

local function DelButton(bar, index)
	local button = bar.buttons[index]
	button:EnableMouse(false)
	FrameFactory_Put( button )
	ButtonSetCountdown( button )
	tremove(bar.buttons,index)
	Notify( button, 'OnDestroy' )
end

local function CreateButtons(bar, db)
	bar.countVisible = 0
	local count = db.buttonCount or #db
	for i=1,count do
		AddButton(bar, db[i])
	end
end

local function DestroyButtons(bar)
	for i=#bar.buttons,1,-1 do
		DelButton( bar, i )
	end
	bar.countVisible = 0
end

local function LayoutButton(button, bar, db)
	local Count = button.Count
	local Timer = button.Timer
	local countMasque = not db.countNoMasque
	local timerMasque = not db.timerNoMasque
	Count:SetFont(Media:Fetch('font', db.countFontName) or FONT_DEFAULT, db.countFontSize or 9,  db.countFontFlags or 'OUTLINE')
	Timer:SetFont(Media:Fetch('font', db.timerFontName) or FONT_DEFAULT, db.timerFontSize or 11, db.timerFontFlags or 'OUTLINE')
	if addon.Masque then
		local ButtonData = button.ButtonData
		if not ButtonData then
			ButtonData = {}
			for i=1,#masqueLayers do
				ButtonData[masqueLayers[i]] = false
			end
			ButtonData.Icon   = button.Icon
			ButtonData.Normal = button.Normal
			button.ButtonData = ButtonData
		end
		ButtonData.Duration = timerMasque and button.Timer or false
		ButtonData.Count    = countMasque and button.Count or false
		Notify(button, 'OnMasqueLayout', ButtonData)
		bar.Masque:AddButton(button, ButtonData)
	else
		local borderSize = db.buttonBorderSize or 1
		local Normal = button.Normal
		Normal:SetParent(button)
		Normal:SetDrawLayer('BACKGROUND')
		Normal:SetColorTexture( unpack(db.buttonBorderColor or COLORBLACK) )
		Normal:ClearAllPoints()
		Normal:SetAllPoints()
		Normal:Show()
		local Icon = button.Icon
		Icon:SetParent(button)
		Icon:SetDrawLayer('ARTWORK')
		Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		Icon:ClearAllPoints()
		Icon:SetPoint( 'TOPLEFT', borderSize, -borderSize )
		Icon:SetPoint( 'BOTTOMRIGHT', -borderSize, borderSize)
	end
	if not (bar.Masque and countMasque) then
		Count:SetParent(button)
		Count:SetDrawLayer('OVERLAY')
		Count:SetTextColor( unpack(db.countFontColor or COLORWHITE ) )
		Count:SetJustifyH( db.countJustifyH or 'RIGHT' )
		Count:SetJustifyV( db.countJustifyV or 'BOTTOM' )
		Count:ClearAllPoints()
		Count:SetPoint( 'CENTER' )
		Count:SetWidth( bar.buttonSize + (db.countAdjustX or 0) )
		Count:SetHeight( bar.buttonSize + (db.countAdjustY or 0) )
	end
	if not (bar.Masque and timerMasque) then
		Timer:SetParent(button)
		Timer:SetDrawLayer('OVERLAY')
		Timer:SetTextColor( unpack(db.timerFontColor or COLORWHITE ) )
		Timer:SetJustifyH( db.timerJustifyH or 'CENTER' )
		Timer:SetJustifyV( db.timerJustifyV or 'MIDDLE' )
		Timer:ClearAllPoints()
		Timer:SetPoint( 'CENTER' )
		Timer:SetWidth( bar.buttonSize + (db.timerAdjustX or 0) )
		Timer:SetHeight( bar.buttonSize + (db.timerAdjustY or 0) )
	end
	Timer.timeThreshold = button.db and button.db.timeThreshold or db.timeThreshold or 60
	Notify( button , 'OnLayout' )
end

local function LayoutButtons(bar)
	local despX, despY, bDespX, bDespY
	local db = bar.db
	local point = db.buttonAnchor
	local buttonSize = db.buttonSize
	local relPoint = addon.opositePoints[point]
	bar.buttonSize    = buttonSize
	bar.buttonSpacing = db.buttonSpacing
	if db.buttonAnchor == 'LEFT' or db.buttonAnchor == 'RIGHT' then
		bar.SetBarWidth  = bar.SetWidth
		bar.SetBarHeight = bar.SetHeight
		despX, despY     = db.buttonSpacing, 0
		bDespX, bDespY   = despX + buttonSize, 0
	else
		bar.SetBarWidth  = bar.SetHeight
		bar.SetBarHeight = bar.SetWidth
		despY, despX     = -db.buttonSpacing, 0
		bDespY, bDespX   = -(db.buttonSpacing+buttonSize), 0
	end
	if db.buttonAnchor == 'RIGHT' or db.buttonAnchor == 'BOTTOM' then
		despX, despY   = -despX, -despY
		bDespX, bDespY = -bDespX, -bDespY
	end
	bar.buttonDespX = bDespX
	bar.buttonDespY = bDespY
	bar.countVisiblePrev = nil
	bar:SetBarHeight( buttonSize )
	bar:SetBarWidth( 0.001 )
	local prev, prevRel, prevX, prevY = bar, point, 0, 0
	for _,button in next, bar.buttons do
		button:ClearAllPoints()
		button:SetSize( buttonSize, buttonSize )
		if button.isHidden then
			button:SetPoint(point, prev, prevRel, prevX-bDespX, prevY-bDespY )
		else
			button:SetPoint(point, prev, prevRel, prevX, prevY)
		end
		LayoutButton(button, bar, db)
		prev, prevRel, prevX, prevY = button, relPoint, despX, despY
	end
end

local function ReloadButtons(bar)
	local relayout
	for _,button in next, bar.buttons do
		if button.isCreated ~= ButtonDisplayFilter(button.db, button) then
			if button.isCreated then
				ButtonSetCountdown(button)
				bar.countVisible = bar.countVisible - (button.isHidden and 0 or 1)
				button.isCreated = false
				button.isHidden  = true
				button:SetAlpha(0)
				Notify( button, 'OnDestroy' )
			else
				bar.countVisible = bar.countVisible + 1
				button.isCreated = true
				button.isHidden = nil
				button:SetAlpha(button.enabledAlpha)
				Notify( button, 'OnCreate' )
			end
			relayout = true
		end
	end
	if relayout then
		LayoutButtons(bar)
		UpdateBar(bar)
	end
end

local function LayoutBar(bar)
	local db = bar.db
	local anchorTo = db.anchorTo or 'CENTER'
	bar.tooltipAnchor = addon.tooltipAnchors[anchorTo]
	bar:ClearAllPoints()
	bar:SetScript('OnUpdate', db.centerButtons and UpdateBarSize or nil)
	bar:SetPoint( anchorTo, UIParent, anchorTo, db.left, db.top )
	local reskin = bar.Masque
	if addon.Masque and not reskin then
		bar.Masque = addon.Masque:Group("CoolAuras", bar.barName )
	end
	LayoutButtons(bar)
	if reskin then
		reskin:ReSkin()
	end
end

local function DisplayBar(bar)
	local displayCombat = bar.db.displayCombat
	local isVisible = displayCombat == nil or displayCombat == addon.inCombat
	if isVisible ~= not not bar:IsShown() then
		bar:SetShown( isVisible )
		if isVisible then
			UpdateBar(bar)
		end
	end
end

local function CreateBar( db )
	local bar = addon.FrameFactory_Get( db.type ) or CreateFrame('Frame')
	bar:Hide()
	bar:SetParent(UIParent)
	bars[db.name] = bar
	bar.db        = db
	bar.className = db.type
	bar.barName   = db.name
	bar.buttons   = bar.buttons or {}
	CreateButtons(bar, db)
	Notify( bar, 'OnCreate' )
	LayoutBar(bar)
	DisplayBar(bar)
	return bar
end

local function DestroyBar(bar)
	bar:SetScript('OnUpdate', nil)
	Notify( bar, 'OnDestroy' )
	bars[ bar.barName ] = nil
	DestroyButtons(bar)
	addon.FrameFactory_Put( bar )
end

local function DestroyBars()
	for _,bar in next, bars do
		DestroyBar(bar)
	end
end

local function ReloadBar(db)
	local bar = bars[db.name]
	if not bar ~= not GroupDisplayFilter(db)  then
		if bar then
			DestroyBar(bar)
		else
			CreateBar(db)
		end
	elseif bar and #bar.db>0 then
		ReloadButtons(bar)
	end
end

local function ReloadBars()
	for _,db in next, addon.db.groups do
		ReloadBar(db)
	end
end

local function EnableMouse(bar, onEnter, onLeave, onClick)
	for _,button in next,bar.buttons do
		button:EnableMouse(true)
		if onEnter then
			button:SetScript("OnEnter", onEnter)
		end
		if onLeave then
			button:SetScript("OnLeave", onLeave)
		end
		if onClick then
			button:RegisterForClicks('RightButtonUp')
			button:SetScript('OnClick', onClick)
		end
	end
end

----------------------------------------------------------------
-- Talents changes
----------------------------------------------------------------
local UpdateTalents
do
	local queued
	local GetSpecialization = GetSpecialization or function() end
	function UpdateTalents(queue)
		if queue then
			if not queued then
				queued = true
				C_Timer.After(0.1,UpdateTalents)
			end
		else
			local specIndex = GetSpecialization()
			if specIndex then
				addon.playerRole = GetSpecializationRole(specIndex) or 'DAMAGER'
				addon.playerSpec = select(2,GetSpecializationInfo(specIndex))
			else
				addon.playerRole = 'DAMAGER'
				addon.playerSpec = nil
			end
			ReloadBars()
			queued = nil
		end
	end
end

----------------------------------------------------------------
-- ShapeShift form
----------------------------------------------------------------

local UpdateShapeshift
do
	local GetShapeshiftForm = GetShapeshiftForm
	local GetShapeshiftFormInfo = GetShapeshiftFormInfo
	function UpdateShapeshift(noReload)
		local index = GetShapeshiftForm()
		if index then
			local spellID = index>0 and select(4,GetShapeshiftFormInfo(index)) or 0 -- 0 = human form
			if addon.playerShapeshift ~= spellID then
				addon.playerShapeshift = spellID
				if not noReload then
					ReloadBars()
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Combat Status
----------------------------------------------------------------

local function UpdateCombat(inCombat)
	addon.inCombat = inCombat
	for _,bar in next,bars do
		DisplayBar(bar)
	end
end

----------------------------------------------------------------
-- Hide Blizzard stuff
----------------------------------------------------------------

local HideBlizzardFrames
do
	local function ReHideFrame(frame)
		if not InCombatLockdown() then frame:Hide() end
	end
	function HideBlizzardFrames()
		local function HideFrame(frame)
			frame:SetParent(addon.hiddenFrame)
			frame:SetScript("OnUpdate", nil)
			frame:HookScript("OnShow", ReHideFrame)
			frame:Hide()
			frame:UnregisterAllEvents()
		end
		if addon.db.general.disableBlizzard then
			addon.hiddenFrame = CreateFrame('Frame')
			addon.hiddenFrame:Hide()
			HideFrame(BuffFrame)
			HideFrame(TemporaryEnchantFrame)
			HideBlizzardFrames = nil
			addon.HideBlizzardFrames = nil
		end
	end
	addon.HideBlizzardFrames = HideBlizzardFrames
end

----------------------------------------------------------------
-- Game Events
----------------------------------------------------------------

local function OnGameEvent(frame, event)
	if event == 'PLAYER_REGEN_DISABLED' or event == 'PLAYER_REGEN_ENABLED' then
		UpdateCombat( event == 'PLAYER_REGEN_DISABLED' )
	elseif event == 'PLAYER_TALENT_UPDATE' or event == 'PLAYER_SPECIALIZATION_CHANGED' or event == 'CHARACTER_POINTS_CHANGED' then
		UpdateTalents(true)
	elseif event == 'PLAYER_ENTERING_WORLD' then
		HideBlizzardFrames()
	elseif event == 'UPDATE_BINDINGS' then
		addon.ResetBindings()
	elseif event == 'UPDATE_SHAPESHIFT_FORM'then
		UpdateShapeshift()
	end
end

----------------------------------------------------------------
-- Publishing some useful stuff
----------------------------------------------------------------

addon.COLORWHITE    = COLORWHITE
addon.COLORBLACK    = COLORBLACK

addon.bars          = bars
addon.DisplayBar    = DisplayBar
addon.ReloadBar     = ReloadBar
addon.ReloadBars    = ReloadBars
addon.DestroyBars   = DestroyBars
addon.CreateBar     = CreateBar
addon.DestroyBar    = DestroyBar
addon.LayoutBar     = LayoutBar
addon.UpdateBar     = UpdateBar
addon.RecreateBar   = RecreateBar
addon.AddButton     = AddButton
addon.DelButton     = DelButton
addon.EnableMouse   = EnableMouse
addon.EnableMasque  = EnableMasque
addon.GroupDisplayFilter = GroupDisplayFilter

addon.ButtonOverlayShow   = ButtonOverlayShow
addon.ButtonOverlayHide   = ButtonOverlayHide
addon.ButtonOverlayUpdate = ButtonOverlayUpdate
addon.ButtonSetIcon       = ButtonSetIcon
addon.ButtonSetCount      = ButtonSetCount
addon.ButtonSetCountdown  = ButtonSetCountdown
addon.ButtonSetValues     = ButtonSetValues
addon.ButtonSetEnabled    = ButtonSetEnabled

----------------------------------------------------------------
--
----------------------------------------------------------------

function addon:Run(frame)
	frame:SetScript('OnEvent', OnGameEvent)
	if isClassic then
		frame:RegisterEvent( 'CHARACTER_POINTS_CHANGED' )
	else
		frame:RegisterEvent( 'PLAYER_TALENT_UPDATE' )
		frame:RegisterEvent( 'PLAYER_SPECIALIZATION_CHANGED' )
	end
	frame:RegisterEvent( 'PLAYER_REGEN_DISABLED' )
	frame:RegisterEvent( 'PLAYER_REGEN_ENABLED' )
	frame:RegisterEvent( 'UPDATE_BINDINGS' )
	frame:RegisterEvent( 'UPDATE_SHAPESHIFT_FORM' )

	self.playerClass = select(2,UnitClass('player'))
	self.playerName  = UnitName('player')
	self.inCombat    = not not InCombatLockdown()
	HideBlizzardFrames()
	EnableMasque()
	UpdateShapeshift(true) -- always before UpdateTalents()
	UpdateTalents()
end
