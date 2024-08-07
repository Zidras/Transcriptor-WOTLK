local addonTbl
local dataTbl = {}
do
	local _
	_, addonTbl = ...
	addonTbl.TIMERS_SPECIAL_EVENTS_DATA = dataTbl
end

-- Insert special events into
addonTbl.TIMERS_SPECIAL_EVENTS = {
	["UNIT_SPELLCAST_SUCCEEDED"] = {
		-- [[ Icecrown Citadel ]] --
--[[
		[GetSpellInfo(72852)] = { -- Create Concoction
			[36678] = "Stage 2", -- Professor Putricide
		},
--]]
	},
	["UNIT_SPELLCAST_INTERRUPTED"] = {
	},
	["SPELL_AURA_APPLIED"] = {
		-- [[ Trial of the Crusader ]] --
		[66758] = { -- Staggered Daze
			[34797] = "Staggered", -- Icehowl
		},
		[66759] = { -- Frothing Rage
			[34797] = "Enraged", -- Icehowl
		},
		-- [[ Icecrown Citadel ]] --
		[69076] = { -- Bone Storm
			[36612] = "Bone Storm applied", -- Lord Marrowgar
		},
		[70952] = { -- Invocation of Blood (Prince Valanar)
			[38008] = "Valanar Empowered", -- Blood Orb Controller
			[37970] = "Valanar Empowered", -- Príncipe Valanar (UltimoWow)
		},
		[70981] = { -- Invocation of Blood (Prince Keleseth)
			[38008] = "Keleseth Empowered", -- Blood Orb Controller
			[37972] = "Keleseth Empowered", -- Príncipe Keleseth (UltimoWow)
		},
		[70982] = { -- Invocation of Blood (Prince Taldaram)
			[38008] = "Taldaram Empowered", -- Blood Orb Controller
			[37973] = "Taldaram Empowered", -- Príncipe Taldaram (UltimoWow)
		},
	},
	["SPELL_AURA_APPLIED_DOSE"] = {
	},
	["SPELL_AURA_REMOVED"] = {
		-- [[ Icecrown Citadel ]] --
		[69076] = { -- Bone Storm
			[36612] = "Bone Storm removed", -- Lord Marrowgar
		},
		--[[
		[70842] = { -- Mana Barrier
			[36855] = "Stage 2", -- Lady Deathwhisper
		},
		[71615] = { -- Tear Gas Removal (normal)
			[36678] = function() -- Professor Putricide
				local t = GetTime()
				if t - (dataTbl[1] or 0) > 5 then -- only trigger for the first Tear Gas Removal in this time window
					dataTbl[1] = t
					dataTbl[2] = (dataTbl[2] or 1) + 1
					return "Stage ".. dataTbl[2]
				end
			end,
		},
--]]
	},
	["SPELL_CAST_START"] = {
		-- [[ Trial of the Crusader ]] --
		[66683] = { -- Massive Crash (10N)
			[34797] = "Massive Crash start", -- Icehowl
		},
		[67660] = { -- Massive Crash (25N)
			[34797] = "Massive Crash start", -- Icehowl
		},
		[67661] = { -- Massive Crash (10H)
			[34797] = "Massive Crash start", -- Icehowl
		},
		[67662] = { -- Massive Crash (25H)
			[34797] = "Massive Crash start", -- Icehowl
		},
		-- [[ Icecrown Citadel ]] --
		[72852] = { -- Create Concoction (25H)
			[36678] = "Intermission 1", -- Professor Putricide
		},
		[72850] = { -- Create Concoction (25N)
			[36678] = "Intermission 1", -- Professor Putricide
		},
		[72851] = { -- Create Concoction (10H)
			[36678] = "Intermission 1", -- Professor Putricide
		},
		[71621] = { -- Create Concoction (10N)
			[36678] = "Intermission 1", -- Professor Putricide
		},
		[73122] = { -- Guzzle Potions (25H)
			[36678] = "Intermission 2", -- Professor Putricide
		},
		[73120] = { -- Guzzle Potions (25N)
			[36678] = "Intermission 2", -- Professor Putricide
		},
		[73121] = { -- Guzzle Potions (10H)
			[36678] = "Intermission 2", -- Professor Putricide
		},
		[71893] = { -- Guzzle Potions (10N)
			[36678] = "Intermission 2", -- Professor Putricide
		},
	},
	["SPELL_CAST_SUCCESS"] = {
		-- [[ Trial of the Crusader ]] --
		[67865] = { -- Trample
			[34797] = "Trample", -- Icehowl
		},
		-- [[ Icecrown Citadel ]] --
		[73070] = { -- Incite Terror
			[37955] = "Incite Terror", -- Blood-Queen Lana'thel
		},
	},
	["UNIT_DIED"] = {
	}
}