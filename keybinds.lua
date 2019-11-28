
local addon = CoolAuras

local actionBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",  "MultiBarRightButton", "MultiBarLeftButton", "DominosActionButton" }

local bindings 

function addon.ResetBindings()
	bindings = nil
end

function addon.GetSpellBindings(spellID)
	if not bindings then
		bindings = {}
		local macros = {}
		local m = GetNumBindings()
		for i=1,m do
			local com, id, key = GetBinding(i)
			if com == 'SPELL' and key then				
				bindings[id] = key
			end
		end
		for _,barname in ipairs(actionBars) do
			local button, i = _G[barname..'1'], 1
			while button do
				local key = button.buttonType and GetBindingKey(button.buttonType..i) or GetBindingKey("CLICK "..button:GetName()..":LeftButton");
				if key then
					local type, id = GetActionInfo(button.action or 0)
					if type == 'spell' then
						bindings[id] = key	
					elseif type == 'macro' then
						local name,tex,lines = GetMacroInfo(id)
						macros[ select( 7, GetSpellInfo( strmatch(lines,"^#showtooltip (.-)\n") ) ) or 0 ] = string.format( "%s (%s)", key, name )
					end
				end		
				i = i + 1; button = _G[barname..i]
			end
		end
		for spell,macro in pairs(macros) do
			bindings[spell] = bindings[spell] or macro
		end	
	end	
	return bindings[spellID]
end
