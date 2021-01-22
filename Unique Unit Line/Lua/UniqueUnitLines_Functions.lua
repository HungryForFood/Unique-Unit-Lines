-- UniqueUnitLines_Functions
-- Author: HungryForFood
-- DateCreated: 3/22/2020 2:58:07 PM
print("UniqueUnitLines_Functions.lua has loaded.")
--=======================================================================================================================
-- INCLUDES
--=======================================================================================================================
include("UniqueUnitLines_Utilities.lua")
--=======================================================================================================================
-- GLOBALS
--=======================================================================================================================
------------------------------------------------------------------------------------------------------------------------
local g_TableInsert = table.insert
-- exceptions for promotions which may be too overpowered early on
local g_tDisallowedPromotionsToGive = {} -- to use, just add to this table, eg: {"Promotion A", "Promotion B", etc}
if g_bRequireTech == true then
	g_TableInsert(g_tDisallowedPromotionsToGive, "PROMOTION_RECON_BANDEIRANTES") -- the Bandeirantes yields are just far too much for early game
end
--=======================================================================================================================
-- GAMES DEFINES
--=======================================================================================================================
------------------------------------------------------------------------------------------------------------------------
local iMaxMajorCivs = GameDefines["MAX_MAJOR_CIVS"]
local iCivilizationBarbarian = GameInfoTypes["CIVILIZATION_BARBARIAN"]
local iCivilizationMinor = GameInfoTypes["CIVILIZATION_MINOR"]
--=======================================================================================================================
-- CACHED TABLES
--=======================================================================================================================
-------------------------------------------------------------------------------------------------------------------------
local g_tPromotionsToAdd = {}
local g_tPromotionsToRemove = {}
--=======================================================================================================================
-- CORE FUNCTIONS
--=======================================================================================================================
-------------------------------------------------------------------------------------------------------------------------
-- LOADING INTO GAME
-------------------------------------------------------------------------------------------------------------------------
function UniqueUnitLines_SequenceGameInitComplete()
	for iPlayer = 0, iMaxMajorCivs - 1 do
		local tPromotionsToAdd = {}
		local tPromotionsToRemove = {}
		local pPlayer = Players[iPlayer]
		if pPlayer:IsEverAlive() then
			local iCivilization = pPlayer:GetCivilizationType()
			
			if iCivilization ~= iCivilizationBarbarian and iCivilization ~= iCivilizationMinor then
				local tUniqueUnitLinesPromotions = {} -- promotions to add to the unit line
				local tDefaultUnitLinePromotions = {} -- promotions to remove from the unit line
				-- find this civ's unique unit and its equivalent default unit
				for tUniqueUnit in DB.Query("SELECT uc.DefaultUnit, uco.UnitType, u.CombatClass, u.IsMounted FROM Civilization_UnitClassOverrides uco, Civilizations c, UnitClasses uc, Units u WHERE c.ID = " .. iCivilization .. " AND uco.CivilizationType = c.Type AND uc.Type = uco.UnitClassType AND u.Type = uc.DefaultUnit;") do 	
					local sUniqueUnit = tUniqueUnit.UnitType
					local sDefaultUnit = tUniqueUnit.DefaultUnit
					local sCombatClass = tUniqueUnit.CombatClass
					local bMounted = false
					if tUniqueUnit.IsMounted > 0 then
						bMounted = true
					end

					local sUnitLine = Unit_GetUnitLine(sCombatClass, bMounted)
					
					if sUnitLine ~= nil then
						-- cache the unique unit promotions
						if tUniqueUnitLinesPromotions[sUnitLine] == nil then
							tUniqueUnitLinesPromotions[sUnitLine] = {}
						end
						
						---- prerequisite tech, not doing this in the first query as we want the unique unit's tech rather than the default unit's tech
						local sPrereqTech = nil
						local iPrereqTech = nil
						if g_bRequireTech == true then
							for tUniqueUnitTech in DB.Query("SELECT PrereqTech FROM Units WHERE Type = \"" .. sUniqueUnit .. "\";") do
								sPrereqTech = tUniqueUnitTech.PrereqTech
							end
							if sPrereqTech ~= nil and sPrereqTech ~= "" then
								iPrereqTech = GameInfoTypes[sPrereqTech]
							end
						end
						
						---- disallowed promotions
						local sDisallowedPromotions = ""
						for i, sPromotion in ipairs(g_tDisallowedPromotionsToGive) do
							if sDisallowedPromotions ~= "" then
								sDisallowedPromotions = sDisallowedPromotions .. ", " .. sPromotion
							else
								sDisallowedPromotions = sDisallowedPromotions .. sPromotion
							end
						end
						
						local sQuery = "SELECT p.ID FROM Unit_FreePromotions fp, UnitPromotions p WHERE fp.UnitType = \"".. sUniqueUnit .."\" AND fp.PromotionType NOT IN(SELECT PromotionType FROM Unit_FreePromotions WHERE UnitType = \"".. sDefaultUnit .."\") AND p.LostWithUpgrade = 0 AND p.Type = fp.PromotionType"
						if sDisallowedPromotions ~= "" then
							sQuery = sQuery .. " AND p.Type NOT IN(\"".. sDisallowedPromotions .."\")"
						end
						sQuery = sQuery .. ";"
						
						for tUniquePromotion in DB.Query(sQuery) do
							g_TableInsert(tUniqueUnitLinesPromotions[sUnitLine], {tUniquePromotion.ID, iPrereqTech})
						end
						
						
						-- cache the default unit promotions
						if tDefaultUnitLinePromotions[sUnitLine] == nil then
							tDefaultUnitLinePromotions[sUnitLine] = {}
						end
						
						sQuery = "SELECT p.ID FROM Unit_FreePromotions fp, UnitPromotions p WHERE UnitType = \"".. sDefaultUnit .."\" AND PromotionType NOT IN(SELECT PromotionType FROM Unit_FreePromotions WHERE UnitType = \"".. sUniqueUnit .."\") AND p.Type = fp.PromotionType;"
						for tDefaultPromotion in DB.Query(sQuery) do
							g_TableInsert(tDefaultUnitLinePromotions[sUnitLine], {tDefaultPromotion.ID, iPrereqTech})
						end
					end
				end
				
				g_tPromotionsToAdd[iPlayer] = tUniqueUnitLinesPromotions
				g_tPromotionsToRemove[iPlayer] = tDefaultUnitLinePromotions
			end
			
			-- grant the promotions to the starting units, only do this for turn 0
			if Game.GetElapsedGameTurns() == 0 then
				for pUnit in pPlayer:Units() do
					local iUnit = pUnit:GetID()
					Unit_DoUniqueUnitLinePromotions(iPlayer, iUnit, g_tPromotionsToAdd[iPlayer], g_tPromotionsToRemove[iPlayer])
				end
			end
		end
	end
end
Events.SequenceGameInitComplete.Add(UniqueUnitLines_SequenceGameInitComplete)
-------------------------------------------------------------------------------------------------------------------------
-- UNIT CREATED
-------------------------------------------------------------------------------------------------------------------------
function UniqueUnitLines_UnitCreated(iPlayer, iUnit, iUnitType, iPlotX, iPlotY)
	Unit_DoUniqueUnitLinePromotions(iPlayer, iUnit, g_tPromotionsToAdd[iPlayer], g_tPromotionsToRemove[iPlayer])
end
GameEvents.UnitCreated.Add(UniqueUnitLines_UnitCreated) -- note that the UnitCreated hook does not work with unit upgrading as the CvUnit::convert() function is called after unit init, replacing all the promotion changes we have done
-------------------------------------------------------------------------------------------------------------------------
-- UNIT UPGRADED
-------------------------------------------------------------------------------------------------------------------------
function UniqueUnitLines_UnitConverted(iOldPlayer, iNewPlayer, iOldUnit, iNewUnit, bIsUpgrade)
	Unit_DoUniqueUnitLinePromotions(iNewPlayer, iNewUnit, g_tPromotionsToAdd[iNewPlayer], g_tPromotionsToRemove[iNewPlayer])
end
GameEvents.UnitConverted.Add(UniqueUnitLines_UnitConverted) -- this covers everything that the UnitCreated hook doesn't, eg upgrades and barbarian captures
-------------------------------------------------------------------------------------------------------------------------
-- TECHNOLOGY RESEARCHED
-------------------------------------------------------------------------------------------------------------------------
function UniqueUnitLines_TeamTechResearched(iTeam, iTech, iChange)
	if iChange > 0 then
		for iPlayer = 0, iMaxMajorCivs - 1 do
			local pPlayer = Players[iPlayer]
			if pPlayer:IsEverAlive() and pPlayer:GetTeam() == iTeam then
				for pUnit in pPlayer:Units() do
					local iUnit = pUnit:GetID()
					Unit_DoUniqueUnitLinePromotions(iPlayer, iUnit, g_tPromotionsToAdd[iPlayer], g_tPromotionsToRemove[iPlayer])
				end
			end
		end
	end
end
GameEvents.TeamTechResearched.Add(UniqueUnitLines_TeamTechResearched) -- when researchiug the unique unit's technology
--==========================================================================================================================
--==========================================================================================================================