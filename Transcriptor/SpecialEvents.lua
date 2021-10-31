local tbl
do
	local _
	_, tbl = ...
end

tbl.specialEvents = {
	["UNIT_SPELLCAST_SUCCEEDED"] = {
	},
	["UNIT_SPELLCAST_INTERRUPTED"] = {
	},
	["SPELL_AURA_APPLIED"] = {
	},
	["SPELL_AURA_APPLIED_DOSE"] = {
	},
	["SPELL_AURA_REMOVED"] = {
	},
	["SPELL_CAST_START"] = {
	},
	["SPELL_CAST_SUCCESS"] = {
	},
	["UNIT_DIED"] = {
	}
}