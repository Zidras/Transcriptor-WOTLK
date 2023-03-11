local addonTbl
do
	local _
	_, addonTbl = ...
end

--[[ Block certain spells from appearing in the TIMERS list
	[spellId] = { -- Spell name
		[npcId] = true, -- NPC name (reason)
	}
]]
addonTbl.TIMERS_BLOCKLIST = {
	[28714] = { -- Flame Cap
	},
}