
local Transcriptor = {}

local PLAYER_SPELL_BLOCKLIST
local TIMERS_SPECIAL_EVENTS
local TIMERS_SPECIAL_EVENTS_DATA
local TIMERS_BLOCKLIST

do
	local _, addonTbl = ...
	PLAYER_SPELL_BLOCKLIST = addonTbl.PLAYER_SPELL_BLOCKLIST or {} -- PlayerSpellBlocklist.lua
	TIMERS_SPECIAL_EVENTS = addonTbl.TIMERS_SPECIAL_EVENTS or {} -- TimersSpecialEvents.lua
	TIMERS_SPECIAL_EVENTS_DATA = addonTbl.TIMERS_SPECIAL_EVENTS_DATA or {} -- TimersSpecialEvents.lua
	TIMERS_BLOCKLIST = addonTbl.TIMERS_BLOCKLIST or {} -- TimersBlocklist.lua
end

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local compareSuccess = nil
local compareUnitSuccess = nil
local compareEmotes = nil
local compareYells = nil
local compareStart = nil
local compareUnitStart = nil
local compareSummon = nil
local compareAuraApplied = nil
local compareStartTime = nil
local collectNameplates = nil
local collectPlayerAuras = nil
local hiddenUnitAuraCollector = nil
local playerSpellCollector = nil
local hiddenAuraPermList = {
	[5384] = true, -- Feign Death
	--[209997] = true, -- Play Dead (Hunter Pet)
}
local previousSpecialEvent = nil
local specialEventsSincePullList = {}
local hiddenAuraEngageList = nil
local shouldLogFlags = false
--local inEncounter, blockingRelease, limitingRes = false, false, false
local mineOrPartyOrRaid = 7 -- COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID

local band = bit.band
local tinsert, tsort, twipe, tconcat = table.insert, table.sort, table.wipe, table.concat
local format, find, strsplit, gsub, strmatch = string.format, string.find, strsplit, string.gsub, string.match
local strjoin -- defined later since wow API errors with nil values
local tostring, tostringall, date = tostring, tostringall, date
local type, next, print = type, next, print
local debugprofilestop = debugprofilestop

--local C_Scenario, C_DeathInfo_GetSelfResurrectOptions, Enum = C_Scenario, C_DeathInfo.GetSelfResurrectOptions, Enum
--local IsEncounterInProgress, IsEncounterLimitingResurrections, IsEncounterSuppressingRelease = IsEncounterInProgress, IsEncounterLimitingResurrections, IsEncounterSuppressingRelease
--local IsAltKeyDown, EJ_GetEncounterInfo, C_EncounterJournal_GetSectionInfo, C_Map_GetMapInfo = IsAltKeyDown, EJ_GetEncounterInfo, C_EncounterJournal.GetSectionInfo, C_Map.GetMapInfo
local CopyTable = CopyTable
local IsAltKeyDown = IsAltKeyDown
local UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo = UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo
local UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification = UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification
local UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth, UnitHealthMax = UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth, UnitHealthMax
local UnitLevel, UnitCreatureType = UnitLevel, UnitCreatureType
local GetInstanceInfo, GetCurrentMapAreaID = GetInstanceInfo, GetCurrentMapAreaID
local GetZoneText, GetRealZoneText, GetSubZoneText, GetSpellInfo = GetZoneText, GetRealZoneText, GetSubZoneText, GetSpellInfo
--local GetBestMapForUnit = C_Map.GetBestMapForUnit

local C_NamePlate = C_NamePlate -- https://github.com/FrostAtom/awesome_wotlk

-- GLOBALS: TranscriptDB BigWigsLoader DBM CLOSE SlashCmdList SLASH_TRANSCRIPTOR1 SLASH_TRANSCRIPTOR2 SLASH_TRANSCRIPTOR3 EasyMenu CloseDropDownMenus
-- GLOBALS: GetMapID GetBossID GetSectionID

do
	local origPrint = print
	function print(msg, ...)
		return origPrint(format("|cFF33FF99Transcriptor|r: %s", tostring(msg)), tostringall(...))
	end

	local origUnitName = UnitName
	function UnitName(name)
		return origUnitName(name) or "??"
	end
end

local function MobId(guid, extra)
	if not guid then return 1 end
	local strId = tonumber(guid:sub(8, 12), 16) or 1
	if extra then
		local uniq = tonumber(guid:sub(13), 16) or 1 -- spawnCounter
		return strId.."-"..uniq
	else
		return strId
	end
end

local function MobType(guid)
	if not guid then return "guid nil" end
	local unitType = band(guid:sub(1, 5), 0x00F)
	if unitType == 0 then -- or 0x000
		return "Player"
	elseif unitType == 3 then -- or 0x003
		return "NPC"
	elseif unitType == 4 then -- or 0x004
		return "Pet"
	elseif unitType == 5 then -- or 0x005
		return "Vehicle"
	else
		return "Unknown"
	end
end

local function InsertSpecialEvent(name)
	if type(name) == "function" then
		name = name()
	end
	if not name then return end
	local t = debugprofilestop()
	previousSpecialEvent = {t, name}
	tinsert(specialEventsSincePullList, previousSpecialEvent)
	if compareSuccess then
		for _,tbl in next, compareSuccess do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareStart then
		for _,tbl in next, compareStart do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareSummon then
		for _,tbl in next, compareSummon do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareAuraApplied then
		for _,tbl in next, compareAuraApplied do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareUnitSuccess then
		for _,tbl in next, compareUnitSuccess do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareUnitStart then
		for _,tbl in next, compareUnitStart do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareEmotes then
		for _,tbl in next, compareEmotes do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareYells then
		for _,tbl in next, compareYells do
			for _, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
end
Transcriptor.InsertSpecialEvent = InsertSpecialEvent -- Adding to the addon API, to enable access from 3rd party addons (like DBM) that already handle scheduling functions*
-- *AceTimer was not yielding the desired results with scheduling function inside TimersSpecialEvents.lua, without rewriting the existing implementation

--------------------------------------------------------------------------------
-- Utility
--

--[[function GetMapArtID(name)
	name = name:lower()
	for i=1,100000 do
		local fetchedTbl = C_Map.GetMapInfo(i)
		if fetchedTbl and fetchedTbl.name then
			local lowerFetchedName = fetchedTbl.name:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedTbl.name..": "..i)
			end
		end
	end
end
function GetInstanceID(name)
	name = name:lower()
	for i=1,100000 do
		local fetchedName = GetRealZoneText(i)
		local lowerFetchedName = fetchedName:lower()
		if find(lowerFetchedName, name, nil, true) then
			print(fetchedName..": "..i)
		end
	end
end
function GetBossID(name)
	name = name:lower()
	for i=1,100000 do
		local fetchedName = EJ_GetEncounterInfo(i)
		if fetchedName then
			local lowerFetchedName = fetchedName:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedName..": "..i)
			end
		end
	end
end
function GetSectionID(name)
	name = name:lower()
	for i=1,100000 do
		local tbl = C_EncounterJournal_GetSectionInfo(i)
		if tbl then
			local fetchedName = tbl.title
			local lowerFetchedName = fetchedName:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedName..": "..i)
			end
		end
	end
end]]

--------------------------------------------------------------------------------
-- Difficulty
--

--[[local difficultyTbl = {
	["party"] = {
		[1] = "5Normal",
		[2] = "5Heroic",
	},
	["raid"] = {
		[1] = "10Normal",
		[2] = "25Normal",
		[3] = "10Heroic",
		[4] = "25Heroic",
	},
	["none"] = {
		[1] = NONE
	}
	[7] = "25LFR",
	[8] = "5Challenge",
	[14] = "Normal",
	[15] = "Heroic",
	[16] = "Mythic",
	[17] = "LFR",
	[18] = "40Event",
	[19] = "5Event",
	[23] = "5Mythic",
	[24] = "5Timewalking",
	[33] = "RaidTimewalking",
}]]

-- Copied from DBM backport
local function GetCurrentInstanceDifficulty()
	local instanceName, instanceType, difficulty, difficultyName, maxPlayers, dynamicDifficulty, isDynamicInstance = GetInstanceInfo()
	if instanceType == "raid" then
		if isDynamicInstance then -- Dynamic raids (ICC, RS)
			if difficulty == 1 then -- 10 players
				return instanceName, instanceType, difficulty, dynamicDifficulty == 0 and "10 Normal" or dynamicDifficulty == 1 and "10 Heroic" or "unknown"
			elseif difficulty == 2 then -- 25 players
				return instanceName, instanceType, difficulty, dynamicDifficulty == 0 and "25 Normal" or dynamicDifficulty == 1 and "25 Heroic" or "unknown"
			-- On Warmane, it was confirmed by Midna that difficulty returning only 1 or 2 is their intended behaviour: https://www.warmane.com/bugtracker/report/91065
			-- code below (difficulty 3 and 4 in dynamic instances) prevents GetCurrentInstanceDifficulty() from breaking on servers that correctly assign difficulty 1-4 in dynamic instances.
			elseif difficulty == 3 then -- 10 heroic, dynamic
				return instanceName, instanceType, difficulty, "10 Heroic"
			elseif difficulty == 4 then -- 25 heroic, dynamic
				return instanceName, instanceType, difficulty, "25 Heroic"
			end
		else -- Non-dynamic raids
			if difficulty == 1 then
				-- check for Timewalking instance (workaround using GetRaidDifficulty since on Warmane all the usual APIs fail and return "normal" difficulty)
				local raidDifficulty = GetRaidDifficulty()
				if raidDifficulty ~= difficulty and (raidDifficulty == 2 or raidDifficulty == 4) then -- extra checks due to lack of tests and no access to a timewalking server
					return instanceName, instanceType, raidDifficulty, "Timewalking"
				else
					return instanceName, instanceType, difficulty, maxPlayers and maxPlayers.." Normal" or "10 Normal"
				end
			elseif difficulty == 2 then
				return instanceName, instanceType, difficulty, "25 Normal"
			elseif difficulty == 3 then
				return instanceName, instanceType, difficulty, "10 Heroic"
			elseif difficulty == 4 then
				return instanceName, instanceType, difficulty, "25 Heroic"
			end
		end
	elseif instanceType == "party" then -- 5 man Dungeons
		if difficulty == 1 then
			return instanceName, instanceType, difficulty, "5 Normal"
		elseif difficulty == 2 then
			-- check for Mythic instance (workaround using GetDungeonDifficulty since on Warmane all the usual APIs fail and return "heroic" difficulty)
			local dungeonDifficulty = GetDungeonDifficulty()
			if dungeonDifficulty == 3 then
				return instanceName, instanceType, dungeonDifficulty, "Mythic"
			else
				return instanceName, instanceType, difficulty, "5 Heroic"
			end
		end
	else
		return instanceName, instanceType, difficulty, NONE
	end
end

--------------------------------------------------------------------------------
-- Spell blocklist parser: /getspells
--

do
	--[[local function onHyperlinkLeave()
		GameTooltip:Hide()
	end]]
	-- Create UI spell display, copied from BasicChatMods
	local frame, editBox = {}, {}
	for i = 1, 2 do
		frame[i] = CreateFrame("Frame", nil, UIParent)
		frame[i]:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 1, right = 1, top = 1, bottom = 1}}
		)
		frame[i]:SetBackdropColor(0,0,0,1)
		frame[i]:SetWidth(650)
		frame[i]:SetHeight(650)
		frame[i]:Hide()
		frame[i]:SetFrameStrata("DIALOG")

		local scrollArea = CreateFrame("ScrollFrame", "TranscriptorDevScrollArea"..i, frame[i], "UIPanelScrollFrameTemplate")
		scrollArea:SetPoint("TOPLEFT", frame[i], "TOPLEFT", 8, -5)
		scrollArea:SetPoint("BOTTOMRIGHT", frame[i], "BOTTOMRIGHT", -30, 5)

		editBox[i] = CreateFrame("EditBox", nil, frame[i])
		editBox[i]:SetMultiLine(true)
		editBox[i]:SetMaxLetters(0)
		editBox[i]:EnableMouse(true)
		editBox[i]:SetAutoFocus(false)
		editBox[i]:SetFontObject(ChatFontNormal)
		editBox[i]:SetWidth(620)
		editBox[i]:SetHeight(450)
		editBox[i]:SetScript("OnEscapePressed", function(f) f:GetParent():GetParent():Hide() f:SetText("") end)
		--[[if i == 1 then
			editBox[i]:SetScript("OnHyperlinkLeave", onHyperlinkLeave)
			editBox[i]:SetScript("OnHyperlinkEnter", function(_, link)
				if link and find(link, "spell", nil, true) then
					local spellId = strmatch(link, "(%d+)")
					if spellId then
						GameTooltip:SetOwner(frame[i], "ANCHOR_LEFT", 0, -500)
						GameTooltip:SetSpellByID(spellId)
					end
				end
			end)
			editBox[i]:SetHyperlinksEnabled(true)
		end]]

		scrollArea:SetScrollChild(editBox[i])

		local close = CreateFrame("Button", nil, frame[i], "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", frame[i], "TOPRIGHT", 0, 25)
	end

	local function GetLogSpells(slashCommandText)
		if InCombatLockdown() or UnitAffectingCombat("player") or IsFalling() then return end
		if slashCommandText == "logflags" then TranscriptIgnore.logFlags = true print("Player flags will be added to all future logs.") return end

		local total, totalSorted = {}, {}
		local auraTbl, castTbl, summonTbl, extraAttacksTbl, healTbl, energizeTbl, spellDmgTbl = {}, {}, {}, {}, {}, {}, {}
		local aurasSorted, castsSorted, summonSorted, extraAttacksSorted, healSorted, energizeSorted, spellDmgSorted = {}, {}, {}, {}, {}, {}, {}
		local playerCastList = {}
		local ignoreList = {
			[43681] = true, -- Inactive (PvP)
			--[94028] = true, -- Inactive (PvP)
			[66186] = true, -- Napalm (IoC PvP)
			[66195] = true, -- Napalm (IoC PvP)
			[66268] = true, -- Place Seaforium Bomb (IoC PvP)
			[66271] = true, -- Carrying Seaforium (IoC PvP)
			[66456] = true, -- Glaive Throw (IoC PvP)
			[66518] = true, -- Airship Cannon (IoC PvP)
			[66541] = true, -- Incendiary Rocket (IoC PvP)
			[66542] = true, -- Incendiary Rocket (IoC PvP)
			[66657] = true, -- Parachute (IoC PvP)
			[66674] = true, -- Place Huge Seaforium Bomb (IoC PvP)
			[67195] = true, -- Blade Salvo (IoC PvP)
			[67200] = true, -- Blade Salvo (IoC PvP)
			[67440] = true, -- Hurl Boulder (IoC PvP)
			[67441] = true, -- Ram (IoC PvP)
			[67452] = true, -- Rocket Blast (IoC PvP)
			[67461] = true, -- Fire Cannon (IoC PvP)
			[67796] = true, -- Ram (IoC PvP)
			[67797] = true, -- Steam Rush (IoC PvP)
			[68077] = true, -- Repair Cannon (IoC PvP)
			[68298] = true, -- Parachute (IoC PvP)
			[68377] = true, -- Carrying Huge Seaforium (IoC PvP)
			--[[[270620] = true, -- Psionic Blast (Zek'voz/Uldir || Mind Controlled player)
			[272407] = true, -- Oblivion Sphere (Mythrax/Uldir || Orb spawning on player)
			[263372] = true, -- Power Matrix (G'huun/Uldir || Holding the orb)
			[263436] = true, -- Imperfect Physiology (G'huun/Uldir || After the orb)
			[263373] = true, -- Deposit Power Matrix (G'huun/Uldir)
			[263416] = true, -- Throw Power Matrix (G'huun/Uldir)
			[269455] = true, -- Collect Power Matrix (G'huun/Uldir)]]
		}
		local npcIgnoreList = {
			--[[[154297] = true, -- Ankoan Bladesman
			[154304] = true, -- Waveblade Shaman
			[150202] = true, -- Waveblade Hunter]]
		}
--[[	Retail (names replaces with Playername):
			"<73.02 01:22:55> [CLEU] SPELL_AURA_APPLIED#Creature-0-4251-1007-22315-58757-0003304C10#Scholomance Acolyte#Player-1402-0A88D169#Playername-Turalyon#111594#Shatter Soul#DEBUFF#nil"
		WotLK (names replaces with Playername):
			"<336.50 20:27:21> [CLEU] SPELL_AURA_APPLIED#0xF150008F4600050E#Professor Putricide#0x06000000004551AF#Playername#72672#Mutated Plague#DEBUFF#nil#"
			"<335.85 20:27:21> [CLEU] SPELL_CAST_SUCCESS#0xF150008F4600050E#Professor Putricide#0x0000000000000000#nil#70341#Slime Puddle#nil#nil#"
			"<338.76 20:27:24> [CLEU] SPELL_SUMMON#0xF150008F4600050E#Professor Putricide#0xF13000933A000897#Growing Ooze Puddle#70342#Slime Puddle#nil#nil#"
		GUID structure is different in 3.3.5a, so the pattern was changed slightly from retail, but the functionality remains the same
		Requires shouldLogFlags enabled for the pattern to work!]]
		local events = { --event#sourceOrDestFlags#sourceGUID#sourceName#destGUID or empty#destName or 'nil'#spellId#spellName
			"SPELL_AURA_[AR][^#]+#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+", -- SPELL_AURA_[AR] to filter _BROKEN
			"SPELL_CAST_[^#]+#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+",
			"SPELL_SUMMON#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+",
			"SPELL_EXTRA_ATTACKS#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+",
			"_HEAL#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+", -- SPELL_HEAL/SPELL_PERIODIC_HEAL
			"_ENERGIZE#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+", -- SPELL_ENERGIZE/SPELL_PERIODIC_ENERGIZE
			"_[DM][AI][MS][AS][GE][ED]#(%d+)#([^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#[^#]+", -- SPELL_DAMAGE/SPELL_MISSED/SPELL_PERIODIC_DAMAGE/SPELL_PERIODIC_MISSED
		}
		local tables = {
			auraTbl,
			castTbl,
			summonTbl,
			extraAttacksTbl,
			healTbl,
			energizeTbl,
			spellDmgTbl,
		}
		local sortedTables = {
			aurasSorted,
			castsSorted,
			summonSorted,
			extraAttacksSorted,
			healSorted,
			energizeSorted,
			spellDmgSorted,
		}
		for _, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" then
				if logTbl.total then
					for i=1, #logTbl.total do
						local text = logTbl.total[i]

						for j = 1, #events do
							local flagsText, srcGUID, srcName, destGUID, destName, idText = strmatch(text, events[j])
							local spellId = tonumber(idText)
							local flags = tonumber(flagsText)
							local tbl = tables[j]
							local sortedTbl = sortedTables[j]
							if spellId and flags and band(flags, mineOrPartyOrRaid) ~= 0 and not ignoreList[spellId] and not PLAYER_SPELL_BLOCKLIST[spellId] then -- Check total to avoid duplicates
								if not total[spellId] or destGUID ~= "" then -- Attempt to replace START (no dest) with SUCCESS (sometimes has a dest)
									local srcGUIDType = MobType(srcGUID)
									local npcId = MobId(srcGUID)
									local npcIdStr = tostring(npcId)
									if not npcIgnoreList[npcId] then
										local destGUIDType = MobType(destGUID)
										local destNpcIdStr = tostring(MobId(destGUID))
										if find(destGUIDType, "^P[le][at]") then -- Only players/pets, don't remove "-" from NPC names
											destName = gsub(destName, "%-.+", "*") -- Replace server name with *
										end
										if find(srcGUIDType, "^P[le][at]") then-- Only players/pets, don't remove "-" from NPCs names
											srcName = gsub(srcName, "%-.+", "*") -- Replace server name with *
										end
										srcName = gsub(srcName, "%(.+", "") -- Remove health/mana
										if find(srcGUIDType, "^P[le][at]") and find(destGUIDType, "^P[le][at]") then
											tbl[spellId] = "|cFF81BEF7".. srcName .."(".. srcGUIDType ..") >> ".. destName .."(".. destGUIDType ..")|r"
										else
											if srcGUIDType == "Creature" then srcGUIDType = srcGUIDType .."[".. npcIdStr .."]" end
											if destGUIDType == "Creature" then destGUIDType = destGUIDType .."[".. destNpcIdStr .."]" end
											if find(srcGUIDType, "^P[le][at]") and find(destGUIDType, "Creature", nil, true) then
												tbl[spellId] = "|cFF3ADF00".. srcName .."(".. srcGUIDType ..") >> ".. destName .."(".. destGUIDType ..")|r"
											else
												tbl[spellId] = "|cFF964B00".. srcName .."(".. srcGUIDType ..") >> ".. destName .."(".. destGUIDType ..")|r"
											end
										end
										if not total[spellId] then
											total[spellId] = true
											sortedTbl[#sortedTbl+1] = spellId
										end
									end
								end
							end
						end
					end
				end
				if logTbl.TIMERS and logTbl.TIMERS.PLAYER_SPELLS then
					for i=1, #logTbl.TIMERS.PLAYER_SPELLS do
						local text = logTbl.TIMERS.PLAYER_SPELLS[i]
						local spellId, _, _, player = strsplit("#", text)
						local id = tonumber(spellId)
						if id and not PLAYER_SPELL_BLOCKLIST[id] and not playerCastList[id] and not total[id] then
							playerCastList[id] = player
							total[id] = true
						end
					end
				end
			end
		end

		tsort(aurasSorted)
		local text = "-- SPELL_AURA_[APPLIED/REMOVED/REFRESH]\n"
		for i = 1, #aurasSorted do
			local id = aurasSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, auraTbl[id])
		end

		tsort(castsSorted)
		text = text.. "\n-- SPELL_CAST_[START/SUCCESS]\n"
		for i = 1, #castsSorted do
			local id = castsSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, castTbl[id])
		end

		tsort(summonSorted)
		text = text.. "\n-- SPELL_SUMMON\n"
		for i = 1, #summonSorted do
			local id = summonSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, summonTbl[id])
		end

		tsort(extraAttacksSorted)
		text = text.. "\n-- SPELL_EXTRA_ATTACKS\n"
		for i = 1, #extraAttacksSorted do
			local id = extraAttacksSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, extraAttacksTbl[id])
		end
		tsort(healSorted)
		text = text.. "\n-- SPELL_[HEAL/PERIODIC_HEAL]\n"
		for i = 1, #healSorted do
			local id = healSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, healTbl[id])
		end

		tsort(energizeSorted)
		text = text.. "\n-- SPELL_[ENERGIZE/PERIODIC_ENERGIZE]\n"
		for i = 1, #energizeSorted do
			local id = energizeSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, energizeTbl[id])
		end

		tsort(spellDmgSorted)
		text = text.. "\n-- SPELL_[DAMAGE/PERIODIC_DAMAGE/MISSED]\n"
		for i = 1, #spellDmgSorted do
			local id = spellDmgSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, spellDmgTbl[id])
		end

		text = text.. "\n-- PLAYER_CASTS\n"
		for k, v in next, playerCastList do
			local name = GetSpellInfo(k)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, k, k, name, v)
		end

		-- Display newly found spells for analysis
		if not TranscriptIgnore.logFlags then
			editBox[1]:SetText("For this feature to work, player flags must be added to the logs.\nYou can enable additional logging by typing:\n/getspells logflags")
		else
			if not text:find("%d%d%d") then
				editBox[1]:SetText("Nothing was found.\nYou might be looking at logs that didn't have player flags recorded.")
			else
				editBox[1]:SetText(text)
			end
		end
		frame[1]:ClearAllPoints()
		frame[1]:SetPoint("RIGHT", UIParent, "CENTER")
		frame[1]:Show()

		for k in next, PLAYER_SPELL_BLOCKLIST do
			if GetSpellInfo(k) then -- Filter out removed spells when a new patch hits
				total[k] = true
			end
		end
		for k in next, total do
			totalSorted[#totalSorted+1] = k
		end
		tsort(totalSorted)
		local exportText = "local addonTbl\ndo\n\tlocal _\n\t_, addonTbl = ...\nend\n\n"
		exportText = exportText .."-- Block specific player spells from appearing in the logs.\n"
		exportText = exportText .."-- This list is generated in game and there is not much point filling it in manually.\naddonTbl.PLAYER_SPELL_BLOCKLIST = {\n"

		for i = 1, #totalSorted do
			local id = totalSorted[i]
			local name = GetSpellInfo(id)
			exportText = format("%s\t[%d] = true, -- %s\n", exportText, id, name)
		end
		exportText = exportText .."}\n"
		-- Display full blacklist for copying into Transcriptor
		editBox[2]:SetText(exportText)
		frame[2]:ClearAllPoints()
		frame[2]:SetPoint("LEFT", UIParent, "CENTER")
		frame[2]:Show()
	end

	SlashCmdList.GETSPELLS = GetLogSpells
	SLASH_GETSPELLS1 = "/getspells"
end

--------------------------------------------------------------------------------
-- Localization
--

local L = {}
L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."
L["You are already logging an encounter."] = "You are already logging an encounter."
L["Beginning Transcript: "] = "Beginning Transcript: "
L["You are not logging an encounter."] = "You are not logging an encounter."
L["Ending Transcript: "] = "Ending Transcript: "
L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."
L["All transcripts cleared."] = "All transcripts cleared."
L["You can't clear your transcripts while logging an encounter."] = "You can't clear your transcripts while logging an encounter."
L["|cff696969Idle|r"] = "|cff696969Idle|r"
L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fClick|r to start or stop transcribing.\n|cffeda55fRight-Click|r to configure events.\n|cffeda55fAlt-Middle Click|r to clear all stored transcripts."
L["|cffFF0000Recording|r"] = "|cffFF0000Recording|r"
L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"

do
	local locale = GetLocale()
	if locale == "deDE" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Um die besten Logs zu bekommen, solltest du Transcriptor zwischen Wipes oder Bosskills stoppen bzw. starten."
		L["You are already logging an encounter."] = "Du zeichnest bereits einen Begegnung auf."
		L["Beginning Transcript: "] = "Beginne Aufzeichnung: "
		L["You are not logging an encounter."] = "Du zeichnest keine Begegnung auf."
		L["Ending Transcript: "] = "Beende Aufzeichnung: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Aufzeichnungen werden gespeichert nach WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua sobald du reloggst oder das Interface neu lädst."
		L["All transcripts cleared."] = "Alle Aufzeichnungen gelöscht."
		L["You can't clear your transcripts while logging an encounter."] = "Du kannst deine Aufzeichnungen nicht löschen, während du eine Begegnung aufnimmst."
		L["|cff696969Idle|r"] = "|cff696969Leerlauf|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fKlicken|r, um eine Aufzeichnung zu starten oder zu stoppen.\n|cffeda55fRechts-Klicken|r, um Events zu konfigurieren.\n|cffeda55fAlt-Mittel-Klicken|r, um alle Aufzeichnungen zu löschen."
		L["|cffFF0000Recording|r"] = "|cffFF0000Aufzeichnung|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	elseif locale == "zhTW" then
		L["You are already logging an encounter."] = "你已經準備記錄戰鬥"
		L["Beginning Transcript: "] = "開始記錄於: "
		L["You are not logging an encounter."] = "你不處於記錄狀態"
		L["Ending Transcript: "] = "結束記錄於: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "記錄儲存於 WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua"
		L["You are not logging an encounter."] = "你沒有記錄此次戰鬥"
		L["All transcripts cleared."] = "所有記錄已清除"
		L["You can't clear your transcripts while logging an encounter."] = "正在記錄中，你不能清除。"
		L["|cffFF0000Recording|r: "] = "|cffFF0000記錄中|r: "
		L["|cff696969Idle|r"] = "|cff696969閒置|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f點擊|r開始/停止記錄戰鬥"
		L["|cffFF0000Recording|r"] = "|cffFF0000記錄中|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	elseif locale == "zhCN" then
		L["You are already logging an encounter."] = "你已经准备记录战斗"
		L["Beginning Transcript: "] = "开始记录于: "
		L["You are not logging an encounter."] = "你不处于记录状态"
		L["Ending Transcript: "] = "结束记录于："
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "记录保存于WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua中,你可以上传于Cwowaddon.com论坛,提供最新的BOSS数据."
		L["You are not logging an encounter."] = "你没有记录此次战斗"
		L["Added Note: "] = "添加书签于: "
		L["All transcripts cleared."] = "所有记录已清除"
		L["You can't clear your transcripts while logging an encounter."] = "正在记录中,你不能清除."
		L["|cffFF0000Recording|r: "] = "|cffFF0000记录中|r: "
		L["|cff696969Idle|r"] = "|cff696969空闲|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f点击|r开始/停止记录战斗."
		L["|cffFF0000Recording|r"] = "|cffFF0000记录中|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	elseif locale == "koKR" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "최상의 기록을 얻으려면 전멸이나 우두머리 처치 후에 Transcriptor를 중지하고 시작하는 걸 기억하세요."
		L["You are already logging an encounter."] = "이미 우두머리 전투를 기록 중입니다."
		L["Beginning Transcript: "] = "기록 시작: "
		L["You are not logging an encounter."] = "우두머리 전투를 기록하고 있지 않습니다."
		L["Ending Transcript: "] = "기록 종료: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "재기록하거나 사용자 인터페이스를 다시 불러오면 WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua에 기록이 저장됩니다."
		L["All transcripts cleared."] = "모든 기록이 초기화되었습니다."
		L["You can't clear your transcripts while logging an encounter."] = "우두머리 전투를 기록 중일 때는 기록을 초기화 할 수 없습니다."
		L["|cff696969Idle|r"] = "|cff696969대기|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f클릭|r - 기록을 시작하거나 중지합니다.\n|cffeda55f오른쪽-클릭|r - 이벤트를 구성합니다.\n|cffeda55fAlt-가운데 클릭|r - 저장된 모든 기록을 초기화합니다."
		L["|cffFF0000Recording|r"] = "|cffFF0000기록 중|r"
		L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - 비활성된 이벤트"
	elseif locale == "ruRU" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Чтобы получить лучшие записи боя, не забудьте остановить и запустить Transcriptor между вайпом или убийством босса."
		L["You are already logging an encounter."] = "Вы уже записываете бой."
		L["Beginning Transcript: "] = "Начало записи: "
		L["You are not logging an encounter."] = "Вы не записываете бой."
		L["Ending Transcript: "] = "Окончание записи: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Записи боя будут записаны в WoW\\WTF\\Account\\<название>\\SavedVariables\\Transcriptor.lua после того как вы перезайдете или перезагрузите пользовательский интерфейс."
		L["All transcripts cleared."] = "Все записи очищены."
		L["You can't clear your transcripts while logging an encounter."] = "Вы не можете очистить ваши записи пока идет запись боя."
		L["|cff696969Idle|r"] = "|cff696969Ожидание|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fЛКМ|r - запустить или остановить запись.\n|cffeda55fПКМ|r - настройка событий.\n|cffeda55fAlt-СКМ|r - очистить все сохраненные записи."
		L["|cffFF0000Recording|r"] = "|cffFF0000Запись|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	end
end

--------------------------------------------------------------------------------
-- Events
--

local eventFrame = CreateFrame("Frame")
eventFrame:Hide()
local sh = {}

-- The builtin strjoin doesn't handle nils ..
function strjoin(delimiter, ...)
	local ret = nil
	for i = 1, select("#", ...) do
		ret = (ret or "") .. tostring((select(i, ...))) .. (delimiter or "#") -- # is necessary for the CLEU pattern matching, and only a handful of spells in the database with this character, so risk of matching is negligible. Using semicolon : by contrast is more common in the spell names
	end
	return ret
end

function sh.UPDATE_WORLD_STATES()
	local ret = nil
	for i = 1, GetNumWorldStateUI() do
		local m = strjoin(":", GetWorldStateUIInfo(i))
		if m and m:trim() ~= "0:" then
			ret = (ret or "") .. "|" .. m
		end
	end
	return ret
end
sh.WORLD_STATE_UI_TIMER_UPDATE = sh.UPDATE_WORLD_STATES

do
	local auraEvents = {
		["SPELL_AURA_APPLIED"] = true,
		["SPELL_AURA_APPLIED_DOSE"] = true,
		["SPELL_AURA_REFRESH"] = true,
		["SPELL_AURA_REMOVED"] = true,
		["SPELL_AURA_REMOVED_DOSE"] = true,
	}
	local badPlayerFilteredEvents = {
		["SPELL_CAST_SUCCESS"] = true,
		["SPELL_AURA_APPLIED"] = true,
		["SPELL_AURA_APPLIED_DOSE"] = true,
		["SPELL_AURA_REFRESH"] = true,
		["SPELL_AURA_REMOVED"] = true,
		["SPELL_AURA_REMOVED_DOSE"] = true,
		["SPELL_CAST_START"] = true,
		["SPELL_SUMMON"] = true,
		["SPELL_EXTRA_ATTACKS"] = true,
		--"<87.10 17:55:03> [CLEU] SPELL_AURA_BROKEN_SPELL#Creature-0-3771-1676-28425-118022-000004A6B5#Infernal Chaosbringer#Player-XYZ#XYZ#115191#Stealth#242906#Immolation Aura", -- [148]
		--"<498.56 22:02:38> [CLEU] SPELL_AURA_BROKEN_SPELL#Creature-0-3895-1676-10786-106551-00008631CC-TSGuardian#Hati#Creature-0-3895-1676-10786-120697-000086306F#Worshiper of Elune#206961#Tremble Before Me#118459#Beast Cleave", -- [8039]
		--["SPELL_AURA_BROKEN_SPELL"] = true,
		["SPELL_HEAL"] = true,
		["SPELL_PERIODIC_HEAL"] = true,
		["SPELL_ENERGIZE"] = true,
		["SPELL_PERIODIC_ENERGIZE"] = true,
		["SPELL_DAMAGE"] = true,
		["SPELL_MISSED"] = true,
		["SPELL_PERIODIC_DAMAGE"] = true,
		["SPELL_PERIODIC_MISSED"] = true,
}
	local badPlayerEvents = {
		["SWING_DAMAGE"] = true,
		["SWING_MISSED"] = true,
		["RANGE_DAMAGE"] = true,
		["RANGE_MISSED"] = true,
		["DAMAGE_SPLIT"] = true,
	}
	local badEvents = {
--		["SPELL_ABSORBED"] = true, -- doesn't exist on 3.3.5a, arg12 of _MISSED
		["SPELL_CAST_FAILED"] = true,
	}
	local badNPCs = { -- These are NPCs summoned by your group but are incorrectly not marked as mineOrPartyOrRaid, so we manually filter
		[3527] = true, -- Healing Stream Totem, casts Healing Stream Totem (52042) on friendlies
--		[5334] = true, -- Windfury Totem, casts Windfury Totem (327942) on friendlies
		[27829] = true, -- Ebon Gargoyle, casts Gargoyle Strike (51963) on hostiles
		[27893] = true, -- Rune Weapon, casts Blood Plague (55078) on hostiles
--		[29264] = true, -- Spirit Wolf, casts Earthen Weapon (392375) on friendlies
--		[61245] = true, -- Capacitor Totem, casts Static Charge (118905) on hostiles
--		[198236] = true, -- Divine Image, casts Blessed Light (196813) on friendlies
	}
	local guardian = 8192 -- COMBATLOG_OBJECT_TYPE_GUARDIAN
	local dmgCache, dmgPrdcCache = {}, {}
	--local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
	-- Note some things we are trying to avoid filtering:
	-- BRF/Kagraz - Player damage with no source "SPELL_DAMAGE##nil#Player-GUID#PLAYER#154938#Molten Torrent#"
	-- HFC/Socrethar - Player cast on friendly vehicle "SPELL_CAST_SUCCESS#Player-GUID#PLAYER#Vehicle-0-3151-1448-8853-90296-00001D943C#Soulbound Construct#190466#Incomplete Binding"
	-- HFC/Zakuun - Player boss debuff cast on self "SPELL_AURA_APPLIED#Player-GUID#PLAYER#Player-GUID#PLAYER#189030#Befouled#DEBUFF#"
	-- ToS/Sisters - Boss pet marked as guardian "SPELL_CAST_SUCCESS#Creature-0-3895-1676-10786-119205-0000063360#Moontalon##nil#236697#Deathly Screech"
	-- Neltharus/Sargha - Player picks up an item from gold pile that makes you cast a debuff on yourself, SPELL_PERIODIC_DAMAGE#Player-GUID#PLAYER#Player-GUID#PLAYER#391762#Curse of the Dragon Hoard
	function sh.COMBAT_LOG_EVENT_UNFILTERED(timeStamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, extraSpellId, amount,...)
		if auraEvents[event] and not hiddenAuraPermList[spellId] then
			hiddenAuraPermList[spellId] = true
		end

		local npcId = MobId(sourceGUID)

		if badEvents[event] or
		   (event == "UNIT_DIED" and band(destFlags, mineOrPartyOrRaid) ~= 0 and band(destFlags, guardian) == guardian) or -- Filter guardian deaths only, player deaths can explain debuff removal
		   (sourceName and badPlayerEvents[event] and band(sourceFlags, mineOrPartyOrRaid) ~= 0) or
		   (sourceName and badPlayerFilteredEvents[event] and PLAYER_SPELL_BLOCKLIST[spellId] and band(sourceFlags, mineOrPartyOrRaid) ~= 0) or
		   (spellId == 22568 and event == "SPELL_DRAIN" and band(sourceFlags, mineOrPartyOrRaid) ~= 0) -- Feral Druid casting Ferocious Bite
		then
			return
		else
			--if (sourceName and badPlayerFilteredEvents[event] and PLAYER_SPELL_BLOCKLIST[spellId] and band(sourceFlags, mineOrPartyOrRaid) == 0) then
			--	print("Transcriptor:", sourceName..":"..npcId, "used spell", spellName..":"..spellId, "in event", event, "but isn't in our group.")
			--end

			if event == "SPELL_CAST_SUCCESS" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareSuccess then compareSuccess = {} end
				if not compareSuccess[spellId] then compareSuccess[spellId] = {} end
				local npcIdString = MobId(sourceGUID, true)
				if not compareSuccess[spellId][npcIdString] then
					if previousSpecialEvent then
						local specialEventCache = CopyTable(specialEventsSincePullList)
						compareSuccess[spellId][npcIdString] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
					else
						compareSuccess[spellId][npcIdString] = {compareStartTime}
					end
				end
				compareSuccess[spellId][npcIdString][#compareSuccess[spellId][npcIdString]+1] = debugprofilestop()
			end
			if event == "SPELL_CAST_START" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareStart then compareStart = {} end
				if not compareStart[spellId] then compareStart[spellId] = {} end
				local npcIdString = MobId(sourceGUID, true)
				if not compareStart[spellId][npcIdString] then
					if previousSpecialEvent then
						local specialEventCache = CopyTable(specialEventsSincePullList)
						compareStart[spellId][npcIdString] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
					else
						compareStart[spellId][npcIdString] = {compareStartTime}
					end
				end
				compareStart[spellId][npcIdString][#compareStart[spellId][npcIdString]+1] = debugprofilestop()
			end
			if event == "SPELL_SUMMON" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareSummon then compareSummon = {} end
				if not compareSummon[spellId] then compareSummon[spellId] = {} end
				local npcIdString = MobId(sourceGUID, true)
				if not compareSummon[spellId][npcIdString] then
					if previousSpecialEvent then
						local specialEventCache = CopyTable(specialEventsSincePullList)
						compareSummon[spellId][npcIdString] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
					else
						compareSummon[spellId][npcIdString] = {compareStartTime}
					end
				end
				compareSummon[spellId][npcIdString][#compareSummon[spellId][npcIdString]+1] = debugprofilestop()
			end
			if (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_APPLIED_DOSE") and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareAuraApplied then compareAuraApplied = {} end
				if not compareAuraApplied[spellId] then compareAuraApplied[spellId] = {} end
				local npcIdString = MobId(sourceGUID, true)
				if not compareAuraApplied[spellId][npcIdString] then
					if previousSpecialEvent then
						local specialEventCache = CopyTable(specialEventsSincePullList)
						compareAuraApplied[spellId][npcIdString] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
					else
						compareAuraApplied[spellId][npcIdString] = {compareStartTime}
					end
				end
				compareAuraApplied[spellId][npcIdString][#compareAuraApplied[spellId][npcIdString]+1] = debugprofilestop()
			end

			if sourceName and badPlayerFilteredEvents[event] and band(sourceFlags, mineOrPartyOrRaid) ~= 0 then
				if not collectPlayerAuras then collectPlayerAuras = {} end
				if not collectPlayerAuras[spellId] then collectPlayerAuras[spellId] = {} end
				if not collectPlayerAuras[spellId][event] then collectPlayerAuras[spellId][event] = true end
			end

			if event == "UNIT_DIED" then
				local name = TIMERS_SPECIAL_EVENTS.UNIT_DIED[npcId]
				if name then
					InsertSpecialEvent(name)
				end
			elseif TIMERS_SPECIAL_EVENTS[event] and TIMERS_SPECIAL_EVENTS[event][spellId] then
				local name = TIMERS_SPECIAL_EVENTS[event][spellId][npcId]
				if name then
					InsertSpecialEvent(name)
				end
			end

			if event == "SPELL_DAMAGE" or event == "SPELL_MISSED" then
				if dmgPrdcCache.spellId then
					if dmgPrdcCache.count == 1 then
						if shouldLogFlags and dmgCache.sourceName ~= "nil" then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceFlags, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					end
					dmgPrdcCache.spellId = nil
				end

				if spellId == dmgCache.spellId then
					if timeStamp - dmgCache.timeStamp > 0.2 then
						if dmgCache.count == 1 then
							if shouldLogFlags and dmgCache.sourceName ~= "nil" then
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceFlags, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
							else
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
							end
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
						end
						dmgCache.spellId = spellId
						dmgCache.sourceGUID = sourceGUID
						dmgCache.sourceName = sourceName or "nil"
						dmgCache.sourceFlags = sourceFlags
						dmgCache.spellName = spellName
						dmgCache.timeStop = (debugprofilestop() / 1000) - logStartTime
						dmgCache.time = date("%H:%M:%S")
						dmgCache.timeStamp = timeStamp
						dmgCache.count = 1
						dmgCache.event = event
						dmgCache.destGUID = destGUID
						dmgCache.destName = destName
					else
						dmgCache.count = dmgCache.count + 1
					end
				else
					if dmgCache.spellId then
						if dmgCache.count == 1 then
							if shouldLogFlags and dmgCache.sourceName ~= "nil" then
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceFlags, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
							else
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
							end
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
						end
					end
					dmgCache.spellId = spellId
					dmgCache.sourceGUID = sourceGUID
					dmgCache.sourceName = sourceName or "nil"
					dmgCache.sourceFlags = sourceFlags
					dmgCache.spellName = spellName
					dmgCache.timeStop = (debugprofilestop() / 1000) - logStartTime
					dmgCache.time = date("%H:%M:%S")
					dmgCache.timeStamp = timeStamp
					dmgCache.count = 1
					dmgCache.event = event
					dmgCache.destGUID = destGUID
					dmgCache.destName = destName
				end
			elseif event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_PERIODIC_MISSED" then
				if dmgCache.spellId then
					if dmgCache.count == 1 then
						if shouldLogFlags and dmgCache.sourceName ~= "nil" then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceFlags, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						end
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
					end
					dmgCache.spellId = nil
				end

				if spellId == dmgPrdcCache.spellId then
					if timeStamp - dmgPrdcCache.timeStamp > 0.2 then
						if dmgPrdcCache.count == 1 then
							if shouldLogFlags and dmgPrdcCache.sourceName ~= "nil" then
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceFlags, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
							else
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
							end
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
						dmgPrdcCache.spellId = spellId
						dmgPrdcCache.sourceGUID = sourceGUID
						dmgPrdcCache.sourceName = sourceName or "nil"
						dmgPrdcCache.sourceFlags = sourceFlags
						dmgPrdcCache.spellName = spellName
						dmgPrdcCache.timeStop = (debugprofilestop() / 1000) - logStartTime
						dmgPrdcCache.time = date("%H:%M:%S")
						dmgPrdcCache.timeStamp = timeStamp
						dmgPrdcCache.count = 1
						dmgPrdcCache.event = event
						dmgPrdcCache.destGUID = destGUID
						dmgPrdcCache.destName = destName
					else
						dmgPrdcCache.count = dmgPrdcCache.count + 1
					end
				else
					if dmgPrdcCache.spellId then
						if dmgPrdcCache.count == 1 then
							if shouldLogFlags and dmgPrdcCache.sourceName ~= "nil" then
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceFlags, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
							else
								currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
							end
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
					end
					dmgPrdcCache.spellId = spellId
					dmgPrdcCache.sourceGUID = sourceGUID
					dmgPrdcCache.sourceName = sourceName or "nil"
					dmgPrdcCache.sourceFlags = sourceFlags
					dmgPrdcCache.spellName = spellName
					dmgPrdcCache.timeStop = (debugprofilestop() / 1000) - logStartTime
					dmgPrdcCache.time = date("%H:%M:%S")
					dmgPrdcCache.timeStamp = timeStamp
					dmgPrdcCache.count = 1
					dmgPrdcCache.event = event
					dmgPrdcCache.destGUID = destGUID
					dmgPrdcCache.destName = destName
				end
			else
				if dmgCache.spellId then
					if dmgCache.count == 1 then
						if shouldLogFlags and dmgCache.sourceName ~= "nil" then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceFlags, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						end
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
					end
					dmgCache.spellId = nil
				elseif dmgPrdcCache.spellId then
					if dmgPrdcCache.count == 1 then
						if shouldLogFlags and dmgPrdcCache.sourceName ~= "nil" then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceFlags, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					end
					dmgPrdcCache.spellId = nil
				end

				if shouldLogFlags and sourceName and badPlayerFilteredEvents[event] then
					return strjoin("#", tostringall(event, sourceFlags, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraSpellId, amount))
				else
					return strjoin("#", tostringall(event, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraSpellId, amount))
				end
			end
		end
	end
end

function sh.PLAYER_REGEN_DISABLED()
	return "+Entering combat!"
end
function sh.PLAYER_REGEN_ENABLED()
	return "-Leaving combat!"
end

do
	local UnitIsUnit = UnitIsUnit
	local wantedUnits
	if C_NamePlate then
		wantedUnits = {
			target = true, focus = true,
			nameplate1 = true, nameplate2 = true, nameplate3 = true, nameplate4 = true, nameplate5 = true, nameplate6 = true, nameplate7 = true, nameplate8 = true, nameplate9 = true, nameplate10 = true,
			nameplate11 = true, nameplate12 = true, nameplate13 = true, nameplate14 = true, nameplate15 = true, nameplate16 = true, nameplate17 = true, nameplate18 = true, nameplate19 = true, nameplate20 = true,
			nameplate21 = true, nameplate22 = true, nameplate23 = true, nameplate24 = true, nameplate25 = true, nameplate26 = true, nameplate27 = true, nameplate28 = true, nameplate29 = true, nameplate30 = true,
			nameplate31 = true, nameplate32 = true, nameplate33 = true, nameplate34 = true, nameplate35 = true, nameplate36 = true, nameplate37 = true, nameplate38 = true, nameplate39 = true, nameplate40 = true,
		}
	else
		wantedUnits = {
		target = true, focus = true,
		-- nameplate1 = true, nameplate2 = true, nameplate3 = true, nameplate4 = true, nameplate5 = true, nameplate6 = true, nameplate7 = true, nameplate8 = true, nameplate9 = true, nameplate10 = true,
		-- nameplate11 = true, nameplate12 = true, nameplate13 = true, nameplate14 = true, nameplate15 = true, nameplate16 = true, nameplate17 = true, nameplate18 = true, nameplate19 = true, nameplate20 = true,
		-- nameplate21 = true, nameplate22 = true, nameplate23 = true, nameplate24 = true, nameplate25 = true, nameplate26 = true, nameplate27 = true, nameplate28 = true, nameplate29 = true, nameplate30 = true,
		-- nameplate31 = true, nameplate32 = true, nameplate33 = true, nameplate34 = true, nameplate35 = true, nameplate36 = true, nameplate37 = true, nameplate38 = true, nameplate39 = true, nameplate40 = true,
		}
	end
	local bossUnits = {
		boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
		arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
	}
	local raidList = {
		raid1 = true, raid2 = true, raid3 = true, raid4 = true, raid5 = true, raid6 = true, raid7 = true, raid8 = true, raid9 = true, raid10 = true,
		raid11 = true, raid12 = true, raid13 = true, raid14 = true, raid15 = true, raid16 = true, raid17 = true, raid18 = true, raid19 = true, raid20 = true,
		raid21 = true, raid22 = true, raid23 = true, raid24 = true, raid25 = true, raid26 = true, raid27 = true, raid28 = true, raid29 = true, raid30 = true,
		raid31 = true, raid32 = true, raid33 = true, raid34 = true, raid35 = true, raid36 = true, raid37 = true, raid38 = true, raid39 = true, raid40 = true
	}
	local function safeUnit(unit)
		if bossUnits[unit] then -- Accept any boss unit
			return true
		elseif wantedUnits[unit] and not UnitIsUnit("player", unit) and not UnitInRaid(unit) and not UnitInParty(unit) then
			for k in next, bossUnits do
				if UnitIsUnit(unit, k) then -- Reject if the unit is also a boss unit
					return false
				end
			end
			return true
		end
	end

	function sh.UNIT_SPELLCAST_STOP(unit, spellName, ...)
		if safeUnit(unit) then
			local maxHP = UnitHealthMax(unit)
			local maxPower = UnitPowerMax(unit)
			local hp = maxHP == 0 and maxHP or (UnitHealth(unit) / maxHP * 100)
			local power = maxPower == 0 and maxPower or (UnitPower(unit) / maxPower * 100)
			return format("%s(%.1f%%-%.1f%%){Target:%s} -%s- [[%s]]", UnitName(unit), hp, power, UnitName(unit.."target"), spellName, strjoin(":", tostringall(unit, spellName, ...)))
		end
	end
	sh.UNIT_SPELLCAST_CHANNEL_STOP = sh.UNIT_SPELLCAST_STOP

	function sh.UNIT_SPELLCAST_INTERRUPTED(unit, spellName, ...)
		if safeUnit(unit) then
			if TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_INTERRUPTED[spellName] then
				local name = TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_INTERRUPTED[spellName][MobId(UnitGUID(unit))]
				if name then
					InsertSpecialEvent(name)
				end
			end

			local maxHP = UnitHealthMax(unit)
			local maxPower = UnitPowerMax(unit)
			local hp = maxHP == 0 and maxHP or (UnitHealth(unit) / maxHP * 100)
			local power = maxPower == 0 and maxPower or (UnitPower(unit) / maxPower * 100)
			return format("%s(%.1f%%-%.1f%%){Target:%s} -%s- [[%s]]", UnitName(unit), hp, power, UnitName(unit.."target"), spellName, strjoin(":", tostringall(unit, spellName, ...)))
		end
	end

	--local prevCast = nil
	function sh.UNIT_SPELLCAST_SUCCEEDED(unit, spellName, ...)
		if safeUnit(unit) then
			--if castId ~= prevCast then
			--	prevCast = castId
				if not compareUnitSuccess then compareUnitSuccess = {} end
				if not compareUnitSuccess[spellName] then compareUnitSuccess[spellName] = {} end
				local npcId = MobId(UnitGUID(unit), true)
				if not compareUnitSuccess[spellName][npcId] then
					if previousSpecialEvent then
						local specialEventCache = CopyTable(specialEventsSincePullList)
						compareUnitSuccess[spellName][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
					else
						compareUnitSuccess[spellName][npcId] = {compareStartTime}
					end
				end
				compareUnitSuccess[spellName][npcId][#compareUnitSuccess[spellName][npcId]+1] = debugprofilestop()

				if TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_SUCCEEDED[spellName] then
					local npcIdBasic = MobId((UnitGUID(unit)))
					local name = TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_SUCCEEDED[spellName][npcIdBasic]
					if name then
						InsertSpecialEvent(name)
					end
				end
			--end

			local maxHP = UnitHealthMax(unit)
			local maxPower = UnitPowerMax(unit)
			local hp = maxHP == 0 and maxHP or (UnitHealth(unit) / maxHP * 100)
			local power = maxPower == 0 and maxPower or (UnitPower(unit) / maxPower * 100)
			return format("%s(%.1f%%-%.1f%%){Target:%s} -%s- [[%s]]", UnitName(unit), hp, power, UnitName(unit.."target"), spellName, strjoin(":", tostringall(unit, spellName, ...)))
		--elseif raidList[unit] and not PLAYER_SPELL_BLOCKLIST[spellId] then
		--	if not playerSpellCollector[spellId] then
		--		playerSpellCollector[spellId] = strjoin("#", tostringall(spellId, GetSpellInfo(spellId), unit, UnitName(unit)))
		--	end
		--	return format("PLAYER_SPELL{%s} -%s- [[%s]]", UnitName(unit), GetSpellInfo(spellId), strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end
	function sh.UNIT_SPELLCAST_START(unit, spellName, ...)
		if safeUnit(unit) then
			if not compareUnitStart then compareUnitStart = {} end
			if not compareUnitStart[spellName] then compareUnitStart[spellName] = {} end
			local npcId = MobId(UnitGUID(unit), true)
			if not compareUnitStart[spellName][npcId] then
				if previousSpecialEvent then
					local specialEventCache = CopyTable(specialEventsSincePullList)
					compareUnitStart[spellName][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
				else
					compareUnitStart[spellName][npcId] = {compareStartTime}
				end
			end
			compareUnitStart[spellName][npcId][#compareUnitStart[spellName][npcId]+1] = debugprofilestop()

--			if TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_START[spellName] then
--				local npcIdBasic = MobId((UnitGUID(unit)))
--				local name = TIMERS_SPECIAL_EVENTS.UNIT_SPELLCAST_START[spellName][npcIdBasic]
--				if name then
--					InsertSpecialEvent(name)
--				end
--			end

			local _, _, _, _, startTime, endTime = UnitCastingInfo(unit)
			local time = ((endTime or 0) - (startTime or 0)) / 1000
			local maxHP = UnitHealthMax(unit)
			local maxPower = UnitPowerMax(unit)
			local hp = maxHP == 0 and maxHP or (UnitHealth(unit) / maxHP * 100)
			local power = maxPower == 0 and maxPower or (UnitPower(unit) / maxPower * 100)
			return format("%s(%.1f%%-%.1f%%){Target:%s} -%s- %ss [[%s]]", UnitName(unit), hp, power, UnitName(unit.."target"), spellName, time, strjoin(":", tostringall(unit, spellName, ...)))
		end
	end
	function sh.UNIT_SPELLCAST_CHANNEL_START(unit, spellName, ...)
		if safeUnit(unit) then
			local _, _, _, _, startTime, endTime = UnitChannelInfo(unit)
			local time = ((endTime or 0) - (startTime or 0)) / 1000

			local maxHP = UnitHealthMax(unit)
			local maxPower = UnitPowerMax(unit)
			local hp = maxHP == 0 and maxHP or (UnitHealth(unit) / maxHP * 100)
			local power = maxPower == 0 and maxPower or (UnitPower(unit) / maxPower * 100)
			return format("%s(%.1f%%-%.1f%%){Target:%s} -%s- %ss [[%s]]", UnitName(unit), hp, power, UnitName(unit.."target"), spellName, time, strjoin(":", tostringall(unit, spellName, ...)))
		end
	end

	function sh.UNIT_TARGET(unit)
		if safeUnit(unit) then
			return format("-%s:%s- [CanAttack:%s#Exists:%s#IsVisible:%s#ID:%s#GUID:%s#Classification:%s#Health:%s] - Target: %s#TargetOfTarget: %s", tostringall(unit, UnitName(unit), UnitCanAttack("player", unit), UnitExists(unit), UnitIsVisible(unit), MobId(UnitGUID(unit)), UnitGUID(unit), UnitClassification(unit), UnitHealth(unit), UnitName(unit.."target"), UnitName(unit.."targettarget")))
		end
	end
end

function sh.PLAYER_TARGET_CHANGED()
	local guid = UnitGUID("target")
	if guid and not UnitInRaid("target") and not UnitInParty("target") then
		local level = UnitLevel("target") or "nil"
		local reaction = "Hostile"
		if UnitIsFriend("target", "player") then reaction = "Friendly" end
		local classification = UnitClassification("target") or "nil"
		local creatureType = UnitCreatureType("target") or "nil"
		local typeclass = classification == "normal" and creatureType or (classification.." "..creatureType)
		local name = UnitName("target")
		return (format("%s %s (%s) - %s # %s", tostring(level), tostring(reaction), tostring(typeclass), tostring(name), tostring(guid)))
	end
end

function sh.INSTANCE_ENCOUNTER_ENGAGE_UNIT(...)
	return strjoin("#", tostringall("Fake Args:",
		"boss1", UnitCanAttack("player", "boss1"), UnitExists("boss1"), UnitIsVisible("boss1"), UnitName("boss1"), MobId(UnitGUID("boss1")), UnitGUID("boss1"), UnitClassification("boss1"), UnitHealth("boss1"),
		"boss2", UnitCanAttack("player", "boss2"), UnitExists("boss2"), UnitIsVisible("boss2"), UnitName("boss2"), MobId(UnitGUID("boss2")), UnitGUID("boss2"), UnitClassification("boss2"), UnitHealth("boss2"),
		"boss3", UnitCanAttack("player", "boss3"), UnitExists("boss3"), UnitIsVisible("boss3"), UnitName("boss3"), MobId(UnitGUID("boss3")), UnitGUID("boss3"), UnitClassification("boss3"), UnitHealth("boss3"),
		"boss4", UnitCanAttack("player", "boss4"), UnitExists("boss4"), UnitIsVisible("boss4"), UnitName("boss4"), MobId(UnitGUID("boss4")), UnitGUID("boss4"), UnitClassification("boss4"), UnitHealth("boss4"),
		"boss5", UnitCanAttack("player", "boss5"), UnitExists("boss5"), UnitIsVisible("boss5"), UnitName("boss5"), MobId(UnitGUID("boss5")), UnitGUID("boss5"), UnitClassification("boss5"), UnitHealth("boss5"),
		"Real Args:", ...)
	)
end

--[[function sh.UNIT_TARGETABLE_CHANGED(unit)
	return format("-%s- [CanAttack:%s#Exists:%s#IsVisible:%s#Name:%s#GUID:%s#Classification:%s#Health:%s]", tostringall(unit, UnitCanAttack("player", unit), UnitExists(unit), UnitIsVisible(unit), UnitName(unit), UnitGUID(unit), UnitClassification(unit), (UnitHealth(unit))))
end]]

do
	local allowedPowerUnits = {
		boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
		arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
		arenapet1 = true, arenapet2 = true, arenapet3 = true, arenapet4 = true, arenapet5 = true
	}
	--[[function sh.UNIT_POWER_UPDATE(unit, typeName)
		if not allowedPowerUnits[unit] then return end
		local powerType = format("TYPE:%s/%d", typeName, UnitPowerType(unit))
		local mainPower = format("MAIN:%d/%d", UnitPower(unit), UnitPowerMax(unit))
		local altPower = format("ALT:%d/%d", UnitPower(unit, 10), UnitPowerMax(unit, 10))
		return strjoin("#", unit, UnitName(unit), powerType, mainPower, altPower)
	end]]
	function sh.UNIT_ENERGY(unit)
		if not allowedPowerUnits[unit] then return end
		local powerTypeIndex, typeName = UnitPowerType(unit)
		local powerType = format("TYPE:%s/%d", typeName, powerTypeIndex)
		local mainPower = format("MAIN:%d/%d", UnitPower(unit), UnitPowerMax(unit))
		return strjoin("#", unit, UnitName(unit), powerType, mainPower)
	end
	sh.UNIT_FOCUS			= sh.UNIT_ENERGY
	sh.UNIT_HAPPINESS		= sh.UNIT_ENERGY
	sh.UNIT_MANA			= sh.UNIT_ENERGY
	sh.UNIT_RAGE			= sh.UNIT_ENERGY
	sh.UNIT_RUNIC_POWER		= sh.UNIT_ENERGY
	sh.UNIT_MAXENERGY		= sh.UNIT_ENERGY
	sh.UNIT_MAXFOCUS		= sh.UNIT_ENERGY
	sh.UNIT_MAXHAPPINESS	= sh.UNIT_ENERGY
	sh.UNIT_MAXMANA			= sh.UNIT_ENERGY
	sh.UNIT_MAXRAGE			= sh.UNIT_ENERGY
	sh.UNIT_MAXRUNIC_POWER	= sh.UNIT_ENERGY
end

--[[function sh.SCENARIO_UPDATE(newStep)
	--Proving Grounds
	local ret = ""
	if C_Scenario.GetInfo() == "Proving Grounds" then
		local diffID, currWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo()
		ret = "currentMedal:"..diffID.." currWave: "..currWave.." maxWave: "..maxWave.." duration: "..duration
	end

	local ret2 = "#newStep#" .. tostring(newStep)
	ret2 = ret2 .. "#Info#" .. strjoin("#", tostringall(C_Scenario.GetInfo()))
	ret2 = ret2 .. "#StepInfo#" .. strjoin("#", tostringall(C_Scenario.GetStepInfo()))
	if C_Scenario.GetBonusStepInfo then
		ret2 = ret2 .. "#BonusStepInfo#" .. strjoin("#", tostringall(C_Scenario.GetBonusStepInfo()))
	end

	local ret3 = ""
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	for i = 1, numCriteria do
		ret3 = ret3 .. "#CriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetCriteriaInfo(i)))
	end

	local ret4 = ""
	if C_Scenario.GetBonusStepInfo then
		local _, _, numBonusCriteria, _ = C_Scenario.GetBonusStepInfo()
		for i = 1, numBonusCriteria do
			ret4 = ret4 .. "#BonusCriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetBonusCriteriaInfo(i)))
		end
	end

	return ret .. ret2 .. ret3 .. ret4
end

function sh.SCENARIO_CRITERIA_UPDATE(criteriaID)
	local ret = "criteriaID#" .. tostring(criteriaID)
	ret = ret .. "#Info#" .. strjoin("#", tostringall(C_Scenario.GetInfo()))
	ret = ret .. "#StepInfo#" .. strjoin("#", tostringall(C_Scenario.GetStepInfo()))
	if C_Scenario.GetBonusStepInfo then
		ret = ret .. "#BonusStepInfo#" .. strjoin("#", tostringall(C_Scenario.GetBonusStepInfo()))
	end

	local ret2 = ""
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	for i = 1, numCriteria do
		ret2 = ret2 .. "#CriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetCriteriaInfo(i)))
	end

	local ret3 = ""
	if C_Scenario.GetBonusStepInfo then
		local _, _, numBonusCriteria, _ = C_Scenario.GetBonusStepInfo()
		for i = 1, numBonusCriteria do
			ret3 = ret3 .. "#BonusCriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetBonusCriteriaInfo(i)))
		end
	end

	return ret .. ret2 .. ret3
end]]

function sh.ZONE_CHANGED(...)
	return strjoin("#", GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or "?", ...)
end
sh.ZONE_CHANGED_INDOORS = sh.ZONE_CHANGED
sh.ZONE_CHANGED_NEW_AREA = sh.ZONE_CHANGED

function sh.PLAYER_DIFFICULTY_CHANGED()
	local instanceName, instanceType, diff, diffText = GetCurrentInstanceDifficulty()
	return strjoin("#", instanceName or "?", instanceType or "?", diff or "?", diffText or "?")
end

function sh.CINEMATIC_START(...)
	local id = GetCurrentMapAreaID()
	return strjoin("#", "uiMapID:", id, "Real Args:", tostringall(...))
end

function sh.CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == "Transcriptor" then
		return strjoin("#", "RAID_BOSS_WHISPER_SYNC", msg, sender)
	elseif DBM and prefix:sub(1, 5) == "DBMv4" then
		return strjoin("#", "DBM_SYNC", prefix, msg, sender, channel)
	end
end

--[[function sh.ENCOUNTER_START(...)
	compareStartTime = debugprofilestop()
	twipe(TIMERS_SPECIAL_EVENTS_DATA)
	return strjoin("#", ...)
end]]

function sh.CHAT_MSG_RAID_BOSS_EMOTE(msg, npcName, ...)
	local id = strmatch(msg, "|Hspell:([^|]+)|h")
	if msg then
		local spellId = id and tonumber(id) or msg -- aggregate emotes by its spellId (only seen it in one WotLK private server, so also aggregate by msg)
		if spellId then
			if not compareEmotes then compareEmotes = {} end
			if not compareEmotes[spellId] then compareEmotes[spellId] = {} end
			if not compareEmotes[spellId][npcName] then
				if previousSpecialEvent then
					local specialEventCache = CopyTable(specialEventsSincePullList)
					compareEmotes[spellId][npcName] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
				else
					compareEmotes[spellId][npcName] = {compareStartTime}
				end
			end
			compareEmotes[spellId][npcName][#compareEmotes[spellId][npcName]+1] = debugprofilestop()
		end
	end
	return strjoin("#", msg, npcName, tostringall(...))
end

function sh.CHAT_MSG_MONSTER_YELL(msg, npcName, ...)
	local id = strmatch(msg, "|Hspell:([^|]+)|h")
	if msg then
		local spellId = id and tonumber(id) or msg -- aggregate emotes by its spellId (only seen it in one WotLK private server, so also aggregate by msg)
		if spellId then
			if not compareYells then compareYells = {} end
			if not compareYells[spellId] then compareYells[spellId] = {} end
			if not compareYells[spellId][npcName] then
				if previousSpecialEvent then
					local specialEventCache = CopyTable(specialEventsSincePullList)
					compareYells[spellId][npcName] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2], specialEventCache}}
				else
					compareYells[spellId][npcName] = {compareStartTime}
				end
			end
			compareYells[spellId][npcName][#compareYells[spellId][npcName]+1] = debugprofilestop()
		end
	end
	return strjoin("#", msg, npcName, tostringall(...))
end

do
	local UnitAura = UnitAura
	local unitAuraCache = {}
	function sh.UNIT_AURA(unit)
		twipe(unitAuraCache)
		for i = 1, 100 do
			local name, _, _, count, dispelType, duration, _, caster, _, _, spellId = UnitAura(unit, i, "HARMFUL")
			if not spellId then
				break
			else
				if TranscriptOptions.logAllEvents then
					tinsert(unitAuraCache, strjoin("#", tostringall("Debuff "..i, spellId, name, count, dispelType, duration, caster)))
				end
				if not hiddenAuraEngageList[spellId] and not hiddenUnitAuraCollector[spellId] and not PLAYER_SPELL_BLOCKLIST[spellId] then
					if UnitIsVisible(unit) then
						--[[if bossDebuff then
							hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("BOSS_DEBUFF", spellId, name, duration, unit, UnitName(unit)))
						else]]
							hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall(spellId, name, duration, unit, UnitName(unit)))
						--end
					else -- If it's not visible it may not show up in CLEU, use this as an indicator of a false positive
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("UNIT_NOT_VISIBLE", spellId, name, duration, unit, UnitName(unit)))
					end
				end
			end
		end
		for i = 1, 100 do
			local name, _, _, count, dispelType, duration, _, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
			if not spellId then
				break
			else
				if TranscriptOptions.logAllEvents then
					tinsert(unitAuraCache, strjoin("#", tostringall("Buff "..i, spellId, name, count, dispelType, duration, caster)))
				end
				if not hiddenAuraEngageList[spellId] and not hiddenUnitAuraCollector[spellId] and not PLAYER_SPELL_BLOCKLIST[spellId] then
					if UnitIsVisible(unit) then
						--[[if bossDebuff then
							hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("BOSS_BUFF", spellId, name, duration, unit, UnitName(unit)))
						else]]
							hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall(spellId, name, duration, unit, UnitName(unit)))
						--end
					else -- If it's not visible it may not show up in CLEU, use this as an indicator of a false positive
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("UNIT_NOT_VISIBLE", spellId, name, duration, unit, UnitName(unit)))
					end
				end
			end
		end
		if TranscriptOptions.logAllEvents then
			return strjoin("#", unit, UnitName(unit), tconcat(unitAuraCache, ", "))
		end
	end
end

if C_NamePlate then
	function sh.NAME_PLATE_UNIT_ADDED(unit)
		local guid = UnitGUID(unit)
		if not collectNameplates[guid] then
			collectNameplates[guid] = true
			local name = UnitName(unit)
			return strjoin("#", name, guid)
		end
	end
end

local wowEvents = {
	-- Raids
	"CHAT_MSG_ADDON",
	"CHAT_MSG_RAID_WARNING",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"CHAT_MSG_MONSTER_EMOTE",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_MONSTER_WHISPER",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_RAID_BOSS_WHISPER",
	"RAID_BOSS_EMOTE",
	"RAID_BOSS_WHISPER",
	"PLAYER_TARGET_CHANGED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
--	"UNIT_POWER_UPDATE",
	"UNIT_ENERGY",
	"UNIT_FOCUS",
	"UNIT_HAPPINESS",
	"UNIT_MANA",
	"UNIT_RAGE",
	"UNIT_RUNIC_POWER",
	"UNIT_MAXENERGY",
	"UNIT_MAXFOCUS",
	"UNIT_MAXHAPPINESS",
	"UNIT_MAXMANA",
	"UNIT_MAXRAGE",
	"UNIT_MAXRUNIC_POWER",
--	"UPDATE_UI_WIDGET",
	"UNIT_AURA",
	"UNIT_TARGET",
	"INSTANCE_ENCOUNTER_ENGAGE_UNIT",
--	"UNIT_TARGETABLE_CHANGED",
--	"ENCOUNTER_START",
--	"ENCOUNTER_END",
--	"BOSS_KILL",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
--	"NAME_PLATE_UNIT_ADDED",
	"PLAYER_DIFFICULTY_CHANGED",
	-- Scenarios
--	"SCENARIO_UPDATE",
--	"SCENARIO_CRITERIA_UPDATE",
	-- Movies
	"PLAY_MOVIE",
	"CINEMATIC_START",
	-- Battlegrounds
--	"START_TIMER",
	"CHAT_MSG_BG_SYSTEM_HORDE",
	"CHAT_MSG_BG_SYSTEM_ALLIANCE",
	"CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"ARENA_OPPONENT_UPDATE",
	-- World
	"UPDATE_WORLD_STATES",
	"WORLD_STATE_UI_TIMER_UPDATE",
}

local eventCategories = {
	PLAYER_REGEN_DISABLED = "COMBAT",
	PLAYER_REGEN_ENABLED = "COMBAT",
--	ENCOUNTER_START = "COMBAT",
--	ENCOUNTER_END = "COMBAT",
--	BOSS_KILL = "COMBAT",
	INSTANCE_ENCOUNTER_ENGAGE_UNIT = "COMBAT",
--	UNIT_TARGETABLE_CHANGED = "COMBAT",
	CHAT_MSG_MONSTER_EMOTE = "MONSTER",
	CHAT_MSG_MONSTER_SAY = "MONSTER",
	CHAT_MSG_MONSTER_WHISPER = "MONSTER",
	CHAT_MSG_MONSTER_YELL = "MONSTER",
	CHAT_MSG_RAID_BOSS_EMOTE = "MONSTER",
	CHAT_MSG_RAID_BOSS_WHISPER = "MONSTER",
	RAID_BOSS_EMOTE = "MONSTER",
	RAID_BOSS_WHISPER = "MONSTER",
	UNIT_SPELLCAST_START = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_STOP = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_INTERRUPTED = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_CHANNEL_START = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_CHANNEL_STOP = "UNIT_SPELLCAST",
	UNIT_TARGET = "COMBAT",
	UNIT_ENERGY = "UNIT_POWER_UPDATE",
	UNIT_FOCUS = "UNIT_POWER_UPDATE",
	UNIT_HAPPINESS = "UNIT_POWER_UPDATE",
	UNIT_MANA = "UNIT_POWER_UPDATE",
	UNIT_RAGE = "UNIT_POWER_UPDATE",
	UNIT_RUNIC_POWER = "UNIT_POWER_UPDATE",
	UNIT_MAXENERGY = "UNIT_POWER_UPDATE",
	UNIT_MAXFOCUS = "UNIT_POWER_UPDATE",
	UNIT_MAXHAPPINESS = "UNIT_POWER_UPDATE",
	UNIT_MAXMANA = "UNIT_POWER_UPDATE",
	UNIT_MAXRAGE = "UNIT_POWER_UPDATE",
	UNIT_MAXRUNIC_POWER	= "UNIT_POWER_UPDATE",
	ZONE_CHANGED = "ZONE_CHANGED",
	ZONE_CHANGED_INDOORS = "ZONE_CHANGED",
	ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED",
	PLAYER_DIFFICULTY_CHANGED = "COMBAT",
--	SCENARIO_UPDATE = "SCENARIO",
--	SCENARIO_CRITERIA_UPDATE = "SCENARIO",
	PLAY_MOVIE = "MOVIE",
	CINEMATIC_START = "MOVIE",
--	START_TIMER = "PVP",
	CHAT_MSG_BG_SYSTEM_HORDE = "PVP",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "PVP",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "PVP",
	ARENA_OPPONENT_UPDATE = "PVP",
	BigWigs_Message = "BigWigs",
	BigWigs_StartBar = "BigWigs",
	BigWigs_SetStage = "BigWigs",
	BigWigs_PauseBar = "BigWigs",
	BigWigs_ResumeBar = "BigWigs",
	BigWigs_SetRaidIcon = "BigWigs",
	BigWigs_RemoveRaidIcon = "BigWigs",
	BigWigs_VictorySound = "BigWigs",
	BigWigs_BossComm = "BigWigs",
	BigWigs_StopBars = "BigWigs",
	BigWigs_ShowAltPower = "BigWigs",
	BigWigs_HideAltPower = "BigWigs",
	BigWigs_ShowProximity = "BigWigs",
	BigWigs_HideProximity = "BigWigs",
	BigWigs_ShowInfoBox = "BigWigs",
	BigWigs_HideInfoBox = "BigWigs",
	BigWigs_SetInfoBoxLine = "BigWigs",
	BigWigs_SetInfoBoxTitle = "BigWigs",
	BigWigs_SetInfoBoxBar = "BigWigs",
	BigWigs_EnableHostileNameplates = "BigWigs",
	BigWigs_DisableHostileNameplates = "BigWigs",
	BigWigs_AddNameplateIcon = "BigWigs",
	BigWigs_RemoveNameplateIcon = "BigWigs",
	BigWigs_StartNameplateTimer = "BigWigs",
	BigWigs_StopNameplateTimer = "BigWigs",
	DBM_Announce = "DBM",
	DBM_Debug = "DBM",
	DBM_TimerPause = "DBM",
	DBM_TimerResume = "DBM",
	DBM_TimerStart = "DBM",
	DBM_TimerStop = "DBM",
	DBM_TimerUpdate = "DBM",
	DBM_SetStage = "COMBAT",
	DBM_Pull = "COMBAT",
	DBM_Kill = "COMBAT",
	DBM_Wipe = "COMBAT",
	PLAYER_TARGET_CHANGED = "NONE",
	CHAT_MSG_ADDON = "NONE",
	CHAT_MSG_RAID_WARNING = "NONE",
--	NAME_PLATE_UNIT_ADDED = "NONE",
	UPDATE_WORLD_STATES = "WORLD_STATE",
	WORLD_STATE_UI_TIMER_UPDATE = "WORLD_STATE",
}
if C_NamePlate then
	tinsert(wowEvents, "NAME_PLATE_UNIT_ADDED")
	eventCategories.NAME_PLATE_UNIT_ADDED = "NONE"
end
Transcriptor.EventCategories = eventCategories

local bwEvents = {
	"BigWigs_Message",
	"BigWigs_StartBar",
	"BigWigs_SetStage",
	"BigWigs_PauseBar",
	"BigWigs_ResumeBar",
	"BigWigs_SetRaidIcon",
	"BigWigs_RemoveRaidIcon",
	"BigWigs_VictorySound",
	"BigWigs_BossComm",
	"BigWigs_StopBars",
	"BigWigs_ShowAltPower",
	"BigWigs_HideAltPower",
	"BigWigs_ShowProximity",
	"BigWigs_HideProximity",
	"BigWigs_ShowInfoBox",
	"BigWigs_HideInfoBox",
	"BigWigs_SetInfoBoxLine",
	"BigWigs_SetInfoBoxTitle",
	"BigWigs_SetInfoBoxBar",
	"BigWigs_EnableHostileNameplates",
	"BigWigs_DisableHostileNameplates",
	"BigWigs_AddNameplateIcon",
	"BigWigs_RemoveNameplateIcon",
	"BigWigs_StartNameplateTimer",
	"BigWigs_StopNameplateTimer",
}
local dbmEvents = {
	"DBM_Announce",
	"DBM_Debug",
	"DBM_TimerPause",
	"DBM_TimerResume",
	"DBM_TimerStart",
	"DBM_TimerStop",
	"DBM_TimerUpdate",
	"DBM_SetStage",
	"DBM_Pull",
	"DBM_Kill",
	"DBM_Wipe",
}

local function eventHandler(_, event, ...)
	if TranscriptIgnore[event] then return end
	local line
	if sh[event] then
		line = sh[event](...)
	else
		line = strjoin("#", tostringall(...))
	end
	if not line then return end
	local stop = debugprofilestop() / 1000
	local t = stop - logStartTime
	local time = date("%H:%M:%S")
	-- We only have CLEU in the total log, it's way too much information to log twice.
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s", t, time, line)
	else
		-- Use DBM StartCombat callback to emulate ENCOUNTER_START
		if event == "DBM_Pull" then
			local mod, delay, synced, startHp = ...
			compareStartTime = debugprofilestop() - (delay * 1000)
			twipe(TIMERS_SPECIAL_EVENTS_DATA)
			line = strjoin("#", tostringall(mod and mod.id or UNKNOWN, delay, synced, startHp))
		elseif event == "DBM_SetStage" then
			local _, modId, phase, totality = ...
			InsertSpecialEvent("Stage "..phase)
			line = strjoin("#", tostringall(modId, phase, totality))
		-- Use DBM EndCombat callbacks to emulate BOSS_KILL & ENCOUNTER_END
		elseif event == "DBM_Kill" then
			local mod = ...
			previousSpecialEvent = nil -- prevent Stage from spreading if log was not stopped between pulls
			twipe(specialEventsSincePullList)
			line = strjoin("#", tostringall(mod and mod.id or UNKNOWN))
		elseif event == "DBM_Wipe" then
			local mod = ...
			previousSpecialEvent = nil -- prevent Stage from spreading if log was not stopped between pulls
			twipe(specialEventsSincePullList)
			line = strjoin("#", tostringall(mod and mod.id or UNKNOWN))
		end

		local text = format("<%.2f %s> [%s] %s", t, time, event, line)
		currentLog.total[#currentLog.total+1] = text
		local cat = eventCategories[event] or event
		if cat ~= "NONE" then
			if type(currentLog[cat]) ~= "table" then currentLog[cat] = {} end
			tinsert(currentLog[cat], text)
		else
			if event == "CHAT_MSG_ADDON" then
				local prefix = ...
				if prefix:sub(1, 5) == "DBMv4" then
					cat = "DBM"
					if type(currentLog[cat]) ~= "table" then currentLog[cat] = {} end
					tinsert(currentLog[cat], text)
				end
			end
		end
	end
end
eventFrame:SetScript("OnEvent", eventHandler)
--[[eventFrame:SetScript("OnUpdate", function()
	if not inEncounter and IsEncounterInProgress() then
		inEncounter = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterInProgress()] true", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterInProgress()] true", t, time))
	elseif inEncounter and not IsEncounterInProgress() then
		inEncounter = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterInProgress()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterInProgress()] false", t, time))
	end
	if not blockingRelease and IsEncounterSuppressingRelease() then
		blockingRelease = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterSuppressingRelease()] true", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterSuppressingRelease()] true", t, time))
	elseif blockingRelease and not IsEncounterSuppressingRelease() then
		blockingRelease = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterSuppressingRelease()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterSuppressingRelease()] false", t, time))
	end
	if not limitingRes and IsEncounterLimitingResurrections() then
		limitingRes = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		local tbl = C_DeathInfo_GetSelfResurrectOptions()
		if tbl and tbl[1] then
			currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] true {%s}", t, time, tbl[1].name)
			if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
			tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] true {%s}", t, time, tbl[1].name))
		else
			currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] true", t, time)
			if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
			tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] true", t, time))
		end
	elseif limitingRes and not IsEncounterLimitingResurrections() then
		limitingRes = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] false", t, time))
	end
end)]]

--------------------------------------------------------------------------------
-- Addon
--

local menu = {}
local popupFrame = CreateFrame("Frame", "TranscriptorMenu", eventFrame, "UIDropDownMenuTemplate")
local function openMenu(frame)
	EasyMenu(menu, popupFrame, frame, 20, 4, "MENU")
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Transcriptor", {
	type = "data source",
	text = L["|cff696969Idle|r"],
	icon = "Interface\\AddOns\\Transcriptor\\icon_off",
	OnTooltipShow = function(tt)
		if logging then
			tt:AddLine(logName, 1, 1, 1, 1)
		else
			tt:AddLine(L["|cff696969Idle|r"], 1, 1, 1, 1)
		end
		tt:AddLine(" ")
		tt:AddLine(L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."], 0.2, 1, 0.2, 1)
	end,
	OnClick = function(self, button)
		if button == "LeftButton" then
			if not logging then
				Transcriptor:StartLog()
			else
				Transcriptor:StopLog()
			end
		elseif button == "RightButton" then
			openMenu(self)
		elseif button == "MiddleButton" and IsAltKeyDown() then
			Transcriptor:ClearAll()
		end
	end,
})

Transcriptor.events = {}
local function insertMenuItems(tbl)
	for _, v in next, tbl do
		tinsert(menu, {
			text = v,
			func = function() TranscriptIgnore[v] = not TranscriptIgnore[v] end,
			checked = function() return TranscriptIgnore[v] end,
			isNotRadio = true,
			keepShownOnClick = 1,
		})
		tinsert(Transcriptor.events, v)
	end
end

local init = CreateFrame("Frame")
init:SetScript("OnEvent", function(self, event)
	if type(TranscriptDB) ~= "table" then TranscriptDB = {} end
	if type(TranscriptIgnore) ~= "table" then TranscriptIgnore = {} end
	if type(TranscriptOptions) ~= "table" then TranscriptOptions = {} end

	tinsert(menu, { text = L["|cFFFFD200Transcriptor|r - Disabled Events"], fontObject = "GameTooltipHeader", notCheckable = 1 })
	insertMenuItems(wowEvents)
	if BigWigsLoader then insertMenuItems(bwEvents) end
	if DBM then insertMenuItems(dbmEvents) end
	tinsert(menu, { text = CLOSE, func = function() CloseDropDownMenus() end, notCheckable = 1 })

	--C_ChatInfo.RegisterAddonMessagePrefix("Transcriptor")
	SlashCmdList["TRANSCRIPTOR"] = function(input)
		if type(input) == "string" and input:lower() == "clear" then
			Transcriptor:ClearAll()
		else
			if not logging then
				Transcriptor:StartLog()
			else
				Transcriptor:StopLog()
			end
		end
	end
	SLASH_TRANSCRIPTOR1 = "/transcriptor"
	SLASH_TRANSCRIPTOR2 = "/transcript"
	SLASH_TRANSCRIPTOR3 = "/ts"

	-- Addon Minimap Icon snippet
	local DBI = LibStub("LibDBIcon-1.0", true)
	TranscriptOptions.minimap = TranscriptOptions.minimap or {hide = false, minimapPos = 180}
	if DBI and not DBI:IsRegistered("Transcriptor") then
		DBI:Register("Transcriptor", ldb, TranscriptOptions.minimap)
	end
	-- End Minimap Icon snippet

	TranscriptOptions.logAllEvents = TranscriptOptions.logAllEvents or false -- custom, only for debugging. HEAVY MEMORY USAGE!

	self:UnregisterEvent(event)
	self:RegisterEvent("PLAYER_LOGOUT")
	self:SetScript("OnEvent", function()
		if Transcriptor:IsLogging() then
			Transcriptor:StopLog()
		end
	end)
end)
init:RegisterEvent("PLAYER_LOGIN")

--------------------------------------------------------------------------------
-- Logging
--

local function BWEventHandler(event, module, ...)
	if type(module) == "table" then
		if module.baseName == "BigWigs_CommonAuras" then return end
		eventHandler(eventFrame, event, module and module.moduleName, ...)
	else
		eventHandler(eventFrame, event, module, ...)
	end
end

local function DBMEventHandler(...)
	eventHandler(eventFrame, ...)
end

do
	-- Ripped from BigWigs
	local raidList = {
		"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
		"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
		"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
		"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40"
	}
	local partyList = {"player", "party1", "party2", "party3", "party4"}
	local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers

	local function IsInRaid()
		return GetNumRaidMembers() > 0
	end

	local function GetNumGroupMembers()
		return IsInRaid() and GetNumRaidMembers() or GetNumPartyMembers()
	end

	function Transcriptor:IterateGroup()
		local num = GetNumGroupMembers() or 0
		local i = 0
		local size = num > 0 and num+1 or 2
		local function iter(t)
			i = i + 1
			if i < size then
				return t[i]
			end
		end
		return iter, IsInRaid() and raidList or partyList
	end
end

do
	local transcriptorVersion = GetAddOnMetadata("Transcriptor", "Version")
	local dbmRevision = DBM and format("%s (%s)", DBM.DisplayVersion, (DBM.ShowRealDate and DBM:ShowRealDate(DBM.Revision) or DBM.Revision)) or "No DBM"
	local wowVersion, buildRevision = GetBuildInfo() -- Note that both returns here are strings, not numbers.
	local realmName = GetRealmName()
	local playerName = UnitName("player")
	local playerClass = select(2, UnitClass("player"))
	local playerRace = select(2, UnitRace("player"))
	local logNameFormat = "[%s]@[%s] - Zone:%d = %s/%s, Difficulty:%d (%s), Type:%s, " .. format("Transcriptor: %s, DBM: %s, Version: %s.%s - Player: %s (%s, %s) | Server: %s", transcriptorVersion, dbmRevision, wowVersion, buildRevision, playerName, playerClass, playerRace, realmName)
	function Transcriptor:StartLog(silent)
		if logging then
			print(L["You are already logging an encounter."])
		else
			ldb.text = L["|cffFF0000Recording|r"]
			ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_on"
			shouldLogFlags = TranscriptIgnore.logFlags and true or false
			twipe(TIMERS_SPECIAL_EVENTS_DATA)

			hiddenAuraEngageList = {}
			--[[do
				local UnitAura, UnitPosition = UnitAura, UnitPosition
				local myInstance = GetCurrentMapAreaID()
				for unit in Transcriptor:IterateGroup() do
					local _, _, _, tarInstanceId = UnitPosition(unit)
					if tarInstanceId == myInstance then
						for i = 1, 100 do
							local _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
							if not spellId then
								break
							elseif not hiddenAuraEngageList[spellId] then
								hiddenAuraEngageList[spellId] = true
							end
						end
						for i = 1, 100 do
							local _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")
							if not spellId then
								break
							elseif not hiddenAuraEngageList[spellId] then
								hiddenAuraEngageList[spellId] = true
							end
						end
					end
				end
			end]]

			collectNameplates = {}
			hiddenUnitAuraCollector = {}
			playerSpellCollector = {}
			previousSpecialEvent = nil
			twipe(specialEventsSincePullList)
			compareStartTime = debugprofilestop()
			logStartTime = compareStartTime / 1000
			local instanceName, instanceType, diff, diffText = GetCurrentInstanceDifficulty()
			local instanceId = GetCurrentMapAreaID()
			local subZoneName = GetSubZoneText()
			logName = format(logNameFormat, date("%Y-%m-%d"), date("%H:%M:%S"), instanceId or 0, instanceName, subZoneName, diff, diffText, instanceType)

			if type(TranscriptDB[logName]) ~= "table" then TranscriptDB[logName] = {} end
			if type(TranscriptIgnore) ~= "table" then TranscriptIgnore = {} end
			currentLog = TranscriptDB[logName]

			if type(currentLog.total) ~= "table" then currentLog.total = {} end
			--Register Events to be Tracked
			eventFrame:Show()
			if TranscriptOptions.logAllEvents then
				eventFrame:RegisterAllEvents()
			else
				for i = 1, #wowEvents do
					local event = wowEvents[i]
					if not TranscriptIgnore[event] then
						eventFrame:RegisterEvent(event)
					end
				end
			end
			if BigWigsLoader then
				for i = 1, #bwEvents do
					local event = bwEvents[i]
					if not TranscriptIgnore[event] then
						BigWigsLoader.RegisterMessage(eventFrame, event, BWEventHandler)
					end
				end
			end
			if DBM then
				for i = 1, #dbmEvents do
					local event = dbmEvents[i]
					if not TranscriptIgnore[event] then
						DBM:RegisterCallback(event, DBMEventHandler)
					end
				end
			end
			logging = 1

			--Notify Log Start
			if not silent then
				print(L["Beginning Transcript: "]..logName)
				print(L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."])
			end
			return logName
		end
	end
end

function Transcriptor:Clear(log)
	if logging then
		print(L["You can't clear your transcripts while logging an encounter."])
	elseif TranscriptDB[log] then
		TranscriptDB[log] = nil
	end
end
function Transcriptor:Get(log) return TranscriptDB[log] end
function Transcriptor:GetAll() return TranscriptDB end
function Transcriptor:GetCurrentLogName() return logging and logName end
function Transcriptor:AddCustomEvent(event, separateCategory, ...)
	if logging and not TranscriptIgnore[event] then
		local line = strjoin("#", tostringall(...))
		if not line then return end
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		local text = format("<%.2f %s> [%s] %s", t, time, event, line)
		currentLog.total[#currentLog.total+1] = text
		if separateCategory then
			if type(currentLog[separateCategory]) ~= "table" then currentLog[separateCategory] = {} end
			tinsert(currentLog[separateCategory], text)
		end
	end
end
function Transcriptor:IsLogging() return logging end
function Transcriptor:StopLog(silent)
	if not logging then
		print(L["You are not logging an encounter."])
	else
		ldb.text = L["|cff696969Idle|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_off"

		--Clear Events
		eventFrame:Hide()
		if TranscriptOptions.logAllEvents then
			eventFrame:UnregisterAllEvents()
		else
			for i = 1, #wowEvents do
				local event = wowEvents[i]
				if not TranscriptIgnore[event] then
					eventFrame:UnregisterEvent(event)
				end
			end
		end
		if BigWigsLoader then
			BigWigsLoader.SendMessage(eventFrame, "BigWigs_OnPluginDisable", eventFrame)
		end
		if DBM and DBM.UnregisterCallback then
			for i = 1, #dbmEvents do
				local event = dbmEvents[i]
				DBM:UnregisterCallback(event, DBMEventHandler)
			end
		end
		--Notify Stop
		if not silent then
			print(L["Ending Transcript: "]..logName)
			print(L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."])
		end

		if compareSuccess or compareStart or compareSummon or compareAuraApplied or compareUnitSuccess or compareUnitStart or compareEmotes or compareYells then
			currentLog.TIMERS = {}
			if compareSuccess then
				currentLog.TIMERS.SPELL_CAST_SUCCESS = {}
				for spellId,tbl in next, compareSuccess do
					for npcPartialGUID, list in next, tbl do
						local npcId = strsplit("-", npcPartialGUID)
						if not TIMERS_BLOCKLIST[spellId] or (#TIMERS_BLOCKLIST[spellId] > 0 and not TIMERS_BLOCKLIST[spellId][tonumber(npcId)]) then -- Block either by spellId if no npcId is defined, or by spellId + npcId
							local n = format("%s-%d-npc:%s", GetSpellInfo(spellId), spellId, npcPartialGUID)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.2f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.SPELL_CAST_SUCCESS[#currentLog.TIMERS.SPELL_CAST_SUCCESS+1] = str
						end
					end
				end
				tsort(currentLog.TIMERS.SPELL_CAST_SUCCESS)
			end
			if compareStart then
				currentLog.TIMERS.SPELL_CAST_START = {}
				for spellId,tbl in next, compareStart do
					for npcPartialGUID, list in next, tbl do
						local npcId = strsplit("-", npcPartialGUID)
						if not TIMERS_BLOCKLIST[spellId] or (#TIMERS_BLOCKLIST[spellId] > 0 and not TIMERS_BLOCKLIST[spellId][tonumber(npcId)]) then -- Block either by spellId if no npcId is defined, or by spellId + npcId
							local n = format("%s-%d-npc:%s", GetSpellInfo(spellId), spellId, npcPartialGUID)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.2f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.SPELL_CAST_START[#currentLog.TIMERS.SPELL_CAST_START+1] = str
						end
					end
				end
				tsort(currentLog.TIMERS.SPELL_CAST_START)
			end
			if compareSummon then
				currentLog.TIMERS.SPELL_SUMMON = {}
				for spellId,tbl in next, compareSummon do
					for npcPartialGUID, list in next, tbl do
						local npcId = strsplit("-", npcPartialGUID)
						if not TIMERS_BLOCKLIST[spellId] or (#TIMERS_BLOCKLIST[spellId] > 0 and not TIMERS_BLOCKLIST[spellId][tonumber(npcId)]) then -- Block either by spellId if no npcId is defined, or by spellId + npcId
							local n = format("%s-%d-npc:%s", GetSpellInfo(spellId), spellId, npcPartialGUID)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.2f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.SPELL_SUMMON[#currentLog.TIMERS.SPELL_SUMMON+1] = str
						end
					end
				end
				tsort(currentLog.TIMERS.SPELL_SUMMON)
			end
			if compareAuraApplied then
				currentLog.TIMERS.SPELL_AURA_APPLIED = {}
				for spellId,tbl in next, compareAuraApplied do
					for npcPartialGUID, list in next, tbl do
						local npcId = strsplit("-", npcPartialGUID)
						if not TIMERS_BLOCKLIST[spellId] or (#TIMERS_BLOCKLIST[spellId] > 0 and not TIMERS_BLOCKLIST[spellId][tonumber(npcId)]) then -- Block either by spellId if no npcId is defined, or by spellId + npcId
							local n = format("%s-%d-npc:%s", GetSpellInfo(spellId), spellId, npcPartialGUID)
							local str
							local zeroCounter = 1
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											local shorten = format("%.2f", t/1000)
											if shorten == "0.00" then
												local typeNext = type(list[i+1])
												if typeNext == "number" then
													local nextT = list[i+1] - list[i]
													local nextShorten = format("%.2f", nextT/1000)
													if nextShorten == "0.00" then
														zeroCounter = zeroCounter + 1
													else
														str = format("%s[+%d]", str, zeroCounter)
														zeroCounter = 1
													end
												else
													str = format("%s[+%d]", str, zeroCounter)
													zeroCounter = 1
												end
											else
												str = format("%s, %.2f", str, t/1000)
											end
										end
									end
								end
							end
							currentLog.TIMERS.SPELL_AURA_APPLIED[#currentLog.TIMERS.SPELL_AURA_APPLIED+1] = str
						end
					end
				end
				tsort(currentLog.TIMERS.SPELL_AURA_APPLIED)
			end
			if compareUnitSuccess then
				currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED = {}
				for spellName,tbl in next, compareUnitSuccess do -- spellID not supported on 3.3.5a, TIMERS_BLOCKLIST not implemented
					for npcId, list in next, tbl do
--						if not compareSuccess or not compareSuccess[spellName] or not compareSuccess[spellName][npcId] then
							local n = format("%s-npc:%s", spellName, npcId)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.2f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED[#currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED+1] = str
--						end
					end
				end
				tsort(currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED)
			end
			if compareUnitStart then
				currentLog.TIMERS.UNIT_SPELLCAST_START = {}
				for spellName,tbl in next, compareUnitStart do -- spellID not supported on 3.3.5a, TIMERS_BLOCKLIST not implemented
					for npcId, list in next, tbl do
--						if not compareStart or not compareStart[id] or not compareStart[id][npcId] then
							local n = format("%s-npc:%s", spellName, npcId)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										local cachedEventList = list[1][4]
										if type(cachedEventList) == "table" then
											local cachedEventString = {}
											local cachedSpellTimeDiffString = {}

											for eventIndex, eventInfo in ipairs(cachedEventList) do
												local eventTime = eventInfo[1]
												local eventName = eventInfo[2]
												local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

												tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
											end

											for j = #cachedEventList, 1, -1 do
												local eventTime = cachedEventList[j][1]
												local spellSincePreviousTime = (list[i] - eventTime)/1000

												tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
											end

											local eventString = tconcat(cachedEventString, ", ")
											local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

											str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
										else
											str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
										end
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.2f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.2f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.2f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.UNIT_SPELLCAST_START[#currentLog.TIMERS.UNIT_SPELLCAST_START+1] = str
--						end
					end
				end
				tsort(currentLog.TIMERS.UNIT_SPELLCAST_START)
			end
			if compareEmotes then
				currentLog.TIMERS.EMOTES = {}
				for id,tbl in next, compareEmotes do
					for npcName, list in next, tbl do
						local msgID = id and GetSpellInfo(id) or "?" -- WotLK emotes generally don't have a spellID, parsing msg as well
						local n = format("%s-%s-npc:%s", msgID, id, npcName)
						local str
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									local cachedEventList = list[1][4]
									if type(cachedEventList) == "table" then
										local cachedEventString = {}
										local cachedSpellTimeDiffString = {}

										for eventIndex, eventInfo in ipairs(cachedEventList) do
											local eventTime = eventInfo[1]
											local eventName = eventInfo[2]
											local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

											tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
										end

										for j = #cachedEventList, 1, -1 do
											local eventTime = cachedEventList[j][1]
											local spellSincePreviousTime = (list[i] - eventTime)/1000

											tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
										end

										local eventString = tconcat(cachedEventString, ", ")
										local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

										str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
									else
										str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
									end
							else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.2f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.2f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.2f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										str = format("%s, %.2f", str, t/1000)
									end
								end
							end
						end
						currentLog.TIMERS.EMOTES[#currentLog.TIMERS.EMOTES+1] = str
					end
				end
				tsort(currentLog.TIMERS.EMOTES)
			end
			if compareYells then
				currentLog.TIMERS.YELLS = {}
				for id,tbl in next, compareYells do
					for npcName, list in next, tbl do
						local msgID = id and GetSpellInfo(id) or "?" -- WotLK emotes generally don't have a spellID, parsing msg as well
						local n = format("%s-%s-npc:%s", msgID, id, npcName)
						local str
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									local cachedEventList = list[1][4]
									if type(cachedEventList) == "table" then
										local cachedEventString = {}
										local cachedSpellTimeDiffString = {}

										for eventIndex, eventInfo in ipairs(cachedEventList) do
											local eventTime = eventInfo[1]
											local eventName = eventInfo[2]
											local sincePreviousTime = eventIndex == 1 and (eventTime - list[1][1])/1000 or (eventTime - cachedEventList[eventIndex-1][1])/1000 -- since pull timer if first event or since previous

											tinsert(cachedEventString, format("%s/%.2f", eventName, sincePreviousTime))
										end

										for j = #cachedEventList, 1, -1 do
											local eventTime = cachedEventList[j][1]
											local spellSincePreviousTime = (list[i] - eventTime)/1000

											tinsert(cachedSpellTimeDiffString, format("%.2f", spellSincePreviousTime))
										end

										local eventString = tconcat(cachedEventString, ", ")
										local timeDiffString = tconcat(cachedSpellTimeDiffString, "/")

										str = format("%s = pull:%.2f/[%s] %s", n, sincePull/1000, eventString, timeDiffString) -- pull:100.00/[Stage 1/10.00, Stage 1.5/10.78, Intermission 1/9.44, Stage 2/15.64] 54.14/69.77/79.22/89.14
									else
										str = format("%s = pull:%.2f/%s/%.2f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000) -- pull:125.69/Stage 2/26.85
									end
							else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.2f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.2f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.2f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.2f/%.2f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.2f/%.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.2f/%.2f/%.2f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.2f/%.2f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										str = format("%s, %.2f", str, t/1000)
									end
								end
							end
						end
						currentLog.TIMERS.YELLS[#currentLog.TIMERS.YELLS+1] = str
					end
				end
				tsort(currentLog.TIMERS.YELLS)
			end
		end
		if collectPlayerAuras then
			if not currentLog.TIMERS then currentLog.TIMERS = {} end
			currentLog.TIMERS.PLAYER_AURAS = {}
			for spellId,tbl in next, collectPlayerAuras do
				local n = format("%d-%s", spellId, (GetSpellInfo(spellId)))
				currentLog.TIMERS.PLAYER_AURAS[n] = {}
				for event in next, tbl do
					currentLog.TIMERS.PLAYER_AURAS[n][#currentLog.TIMERS.PLAYER_AURAS[n]+1] = event
				end
			end
		end
		for spellId, str in next, hiddenUnitAuraCollector do
			if not hiddenAuraPermList[spellId] then
				if not currentLog.TIMERS then currentLog.TIMERS = {} end
				if not currentLog.TIMERS.HIDDEN_AURAS then currentLog.TIMERS.HIDDEN_AURAS = {} end
				currentLog.TIMERS.HIDDEN_AURAS[#currentLog.TIMERS.HIDDEN_AURAS+1] = str
			end
		end
		for _, str in next, playerSpellCollector do
			if not currentLog.TIMERS then currentLog.TIMERS = {} end
			if not currentLog.TIMERS.PLAYER_SPELLS then currentLog.TIMERS.PLAYER_SPELLS = {} end
			currentLog.TIMERS.PLAYER_SPELLS[#currentLog.TIMERS.PLAYER_SPELLS+1] = str
		end

		--Clear Log Path
		currentLog = nil
		logging = nil
		compareSuccess = nil
		compareUnitSuccess = nil
		compareEmotes = nil
		compareYells = nil
		compareStart = nil
		compareUnitStart = nil
		compareSummon = nil
		compareAuraApplied = nil
		compareStartTime = nil
		collectPlayerAuras = nil
		logStartTime = nil
		collectNameplates = nil
		hiddenUnitAuraCollector = nil
		playerSpellCollector = nil

		return logName
	end
end

function Transcriptor:ClearAll()
	if not logging then
		TranscriptDB = {}
		print(L["All transcripts cleared."])
	else
		print(L["You can't clear your transcripts while logging an encounter."])
	end
end

_G.Transcriptor = Transcriptor